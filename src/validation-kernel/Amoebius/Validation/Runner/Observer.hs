{-# LANGUAGE OverloadedStrings #-}

-- | The process observer (gate_runner_doctrine.md section 3, stage 2). Every
-- subject, suite, oracle, and rebuild the runner starts runs under it: the
-- executable, argv, working directory, environment policy, exit, and complete
-- output are captured, digested, and hash-chained to the run's challenge so a
-- replayed transcript cannot bind a new candidate.
module Amoebius.Validation.Runner.Observer
  ( ObservedRun (..)
  , chainDigest
  , observe
  , observedDigest
  , renderObserved
  , sha256Hex
  ) where

import Control.Exception (IOException, try)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString qualified as ByteString
import Data.Char (intToDigit)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import System.Environment (lookupEnv)
import System.Exit (ExitCode (..))
import System.Process (CreateProcess (cwd, env), proc, readCreateProcessWithExitCode)

data ObservedRun = ObservedRun
  { runExecutable :: FilePath
  , runArgv :: [String]
  , runCwd :: FilePath
  , runEnvironmentPolicy :: Text
  , runExit :: ExitCode
  , runStdout :: Text
  , runStderr :: Text
  , runSpawnFailure :: Maybe Text
  }
  deriving (Eq, Show)

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

observedDigest :: ObservedRun -> Text
observedDigest run =
  sha256Hex
    ( Text.intercalate
        "\n"
        [ Text.pack (runExecutable run)
        , Text.pack (show (runArgv run))
        , Text.pack (runCwd run)
        , Text.pack (show (runExit run))
        , sha256Hex (runStdout run)
        , sha256Hex (runStderr run)
        ]
    )

-- | Chain the previous digest with this observation.
chainDigest :: Text -> ObservedRun -> Text
chainDigest previous run = sha256Hex (previous <> "\n" <> observedDigest run)

renderObserved :: Text -> ObservedRun -> [(Text, Text)]
renderObserved prefix run =
  [ (prefix <> ".executable", Text.pack (runExecutable run))
  , (prefix <> ".argv", Text.pack (unwords (runArgv run)))
  , (prefix <> ".cwd", Text.pack (runCwd run))
  , (prefix <> ".environment-policy", runEnvironmentPolicy run)
  , (prefix <> ".exit", Text.pack (show (runExit run)))
  , (prefix <> ".stdout-sha256", sha256Hex (runStdout run))
  , (prefix <> ".stderr-sha256", sha256Hex (runStderr run))
  , (prefix <> ".stdout-bytes", Text.pack (show (Text.length (runStdout run))))
  , (prefix <> ".digest", observedDigest run)
  ]
    <> maybe [] (\failure -> [(prefix <> ".spawn-failure", failure)]) (runSpawnFailure run)

sha256Hex :: Text -> Text
sha256Hex = hex . SHA256.hash . TextEncoding.encodeUtf8

hex :: ByteString.ByteString -> Text
hex = Text.pack . concatMap byteHex . ByteString.unpack
 where
  byteHex value = [intToDigit (fromIntegral value `div` 16), intToDigit (fromIntegral value `mod` 16)]
