{-# LANGUAGE OverloadedStrings #-}
-- | Capture every child executable, argv, cwd, environment policy, exit and output,
-- then bind its digest to the current challenge (gate_runner_doctrine.md section 3).
module Amoebius.Validation.Runner.Observer
  ( ObservedRun (..), chainDigest, observe, observeNativeCabal, buildProductBinary, observedDigest, renderObserved, sha256Hex
  , sha256Bytes, renderTsv ) where
import Control.Exception (IOException, try)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString qualified as ByteString
import Data.Char (intToDigit)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import System.Environment (lookupEnv)
import System.Directory (findExecutable, doesFileExist)
import System.Exit (ExitCode (..))
import System.Process (CreateProcess (cwd, env), proc, readCreateProcessWithExitCode)
data ObservedRun = ObservedRun
  { runExecutable :: FilePath, runArgv :: [String], runCwd :: FilePath
  , runEnvironmentPolicy :: Text, runExit :: ExitCode, runStdout :: Text, runStderr :: Text
  , runSpawnFailure :: Maybe Text } deriving (Eq, Show)
-- | Run one process to completion under a minimal inherited environment (PATH,
-- HOME, and the Cabal/GHC locations only) and capture everything it printed.
observe :: FilePath -> FilePath -> [String] -> IO ObservedRun
observe workingDirectory executable arguments = do
  environment <- minimalEnvironment
  attempt <- try (readCreateProcessWithExitCode ((proc executable arguments) {cwd = Just workingDirectory, env = Just environment}) "")
  pure $ case attempt of
    Left problem ->
      ObservedRun executable arguments workingDirectory policy (ExitFailure 127) "" "" (Just (Text.pack (show (problem :: IOException))))
    Right (exit, out, err) ->
      ObservedRun executable arguments workingDirectory policy exit (Text.pack out) (Text.pack err) Nothing
 where
  policy = "inherit:PATH,HOME,CABAL_DIR,GHCUP_INSTALL_BASE_PREFIX,XDG_CACHE_HOME,LANG"
minimalEnvironment :: IO [(String, String)]
minimalEnvironment = do
  pairs <- mapM (\name -> fmap (fmap (\value -> (name, value))) (lookupEnv name)) ["PATH", "HOME", "CABAL_DIR", "GHCUP_INSTALL_BASE_PREFIX", "XDG_CACHE_HOME", "LANG"]
  pure ([pair | Just pair <- pairs] <> [("LC_ALL", "C.UTF-8")])
observeNativeCabal :: FilePath -> FilePath -> Maybe FilePath -> [String] -> IO ObservedRun
observeNativeCabal root cabal compiler arguments = do
  ghc <- maybe (maybe "ghc" id <$> findExecutable "ghc") pure compiler
  observe root cabal (["run", "-v0", "--jobs=1", "--builddir=.build/source-admission-bootstrap", "--with-compiler=" <> ghc,
    "exe:extension-source-admission", "--", "--cabal", ghc, cabal] <> arguments)
buildProductBinary :: FilePath -> FilePath -> Maybe FilePath -> IO ([ObservedRun], Either Text FilePath)
buildProductBinary root cabal compiler = do
  built <- observeNativeCabal root cabal compiler ["build", "-v0", "--builddir=.build/dist-native", "exe:amoebius"]
  if runExit built /= ExitSuccess then pure ([built], Left ("exe:amoebius did not build: " <> Text.take 400 (runStderr built))) else do
    located <- observeNativeCabal root cabal compiler ["list-bin", "--builddir=.build/dist-native", "exe:amoebius"]
    let path = Text.unpack (Text.strip (runStdout located))
    present <- doesFileExist path
    pure ([built, located], if runExit located == ExitSuccess && present then Right path else Left ("exe:amoebius not located: " <> Text.take 200 (runStderr located)))
observedDigest :: ObservedRun -> Text
observedDigest = sha256Hex . Text.pack . show . observedFields
-- | Chain the previous digest with this observation.
chainDigest :: Text -> ObservedRun -> Text
chainDigest previous run = sha256Hex (previous <> "\n" <> observedDigest run)
renderObserved :: Text -> ObservedRun -> [(Text, Text)]
renderObserved prefix run = [(prefix <> "." <> key, value) | (key, value) <- observedFields run] <> [(prefix <> ".digest", observedDigest run)]
observedFields :: ObservedRun -> [(Text, Text)]
observedFields run =
  [ ("executable", Text.pack (runExecutable run)), ("argv", Text.pack (show (runArgv run)))
  , ("cwd", Text.pack (runCwd run)), ("environment-policy", runEnvironmentPolicy run)
  , ("exit", Text.pack (show (runExit run))), ("stdout-sha256", sha256Hex (runStdout run))
  , ("stderr-sha256", sha256Hex (runStderr run)), ("stdout-bytes", Text.pack (show (ByteString.length (TextEncoding.encodeUtf8 (runStdout run)))))
  ] <> maybe [] (\failure -> [("spawn-failure", failure)]) (runSpawnFailure run)
sha256Hex :: Text -> Text
sha256Hex = sha256Bytes . TextEncoding.encodeUtf8
sha256Bytes :: ByteString.ByteString -> Text
sha256Bytes = hex . SHA256.hash
renderTsv :: [[Text]] -> Text
renderTsv = Text.unlines . map (Text.intercalate "\t")
hex :: ByteString.ByteString -> Text
hex = Text.pack . concatMap byteHex . ByteString.unpack
 where
  byteHex value = [intToDigit (fromIntegral value `div` 16), intToDigit (fromIntegral value `mod` 16)]
