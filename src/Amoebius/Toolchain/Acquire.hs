{-# LANGUAGE OverloadedStrings #-}
-- | Select native tools and check their versions. No platform or byte pin is
-- admitted here; digests in child observations are optional historical metadata.
module Amoebius.Toolchain.Acquire
  ( Acquisition (..), AcquisitionRefusal (..), ChildRecord (..), ToolchainPaths (..)
  , defaultToolchainPaths, acquire, acquireTwice, selectToolchain, agreement
  , renderAcquisition, renderChild, renderRefusal, hexEncode, sha256Bytes
  , sha256File, spawnChild, writeAcquisitionReceipt, removeAcquisition
  ) where
import Amoebius.Toolchain.Versions
import Control.Exception (IOException, try)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Char (intToDigit)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (createDirectoryIfMissing, doesFileExist, doesPathExist, findExecutable, getHomeDirectory, makeAbsolute)
import System.Exit (ExitCode (..))
import System.FilePath (isAbsolute, (</>))
import System.Process (CreateProcess (cwd), proc, readCreateProcessWithExitCode)

data ToolchainPaths = ToolchainPaths {pathGhcup :: Maybe FilePath, pathGhc :: Maybe FilePath, pathCabal :: Maybe FilePath} deriving (Eq, Show)
defaultToolchainPaths :: ToolchainPaths
defaultToolchainPaths = ToolchainPaths Nothing Nothing Nothing
data AcquisitionRefusal = ToolMissing FilePath | ToolCommandFailed Text | VersionRefused VersionRefusal | RootNotAbsent FilePath | AcquisitionsDisagree Text Text Text deriving (Eq, Show)
renderRefusal :: AcquisitionRefusal -> Text
renderRefusal refusal = case refusal of
  ToolMissing tool -> "ToolMissing: " <> Text.pack tool
  ToolCommandFailed tool -> "ToolCommandFailed: " <> tool
  VersionRefused value -> renderVersionRefusal value
  RootNotAbsent path -> "RootNotAbsent: " <> Text.pack path
  AcquisitionsDisagree field a b -> "AcquisitionsDisagree: " <> field <> " " <> a <> " /= " <> b
data ChildRecord = ChildRecord {childTool :: Text, childExecutable :: FilePath, childDigest :: Text, childArgv :: [Text], childExit :: Int} deriving (Eq, Show)
renderChild :: ChildRecord -> Text
renderChild child = Text.intercalate " " [childTool child, Text.pack (childExecutable child), childDigest child, "exit=" <> Text.pack (show (childExit child))]
data Acquisition = Acquisition
  { acquisitionRoot :: FilePath, acquisitionGhcup :: FilePath
  , acquisitionCompiler :: FilePath, acquisitionPackageTool :: FilePath
  , acquisitionGhcupVersion :: Text, acquisitionCompilerVersion :: Text
  , acquisitionPackageToolVersion :: Text, acquisitionChildren :: [ChildRecord]
  } deriving (Eq, Show)
hexEncode :: ByteString -> Text
hexEncode = Text.pack . concatMap (\byte -> [intToDigit (fromIntegral byte `div` 16), intToDigit (fromIntegral byte `mod` 16)]) . ByteString.unpack
sha256Bytes :: ByteString -> Text
sha256Bytes = hexEncode . SHA256.hash
sha256File :: FilePath -> IO Text
sha256File path = hexEncode . SHA256.hashlazy <$> LazyByteString.readFile path
-- | Resolve a tool, capture exit/streams, and optionally record its bytes. A
-- digest cannot admit or reject a tool; only version observations do that.
spawnChild :: FilePath -> String -> [String] -> IO (ChildRecord, String, String)
spawnChild workingDirectory tool arguments = do
  resolved <- if isAbsolute tool then pure (Just tool) else findExecutable tool
  case resolved of
    Nothing -> pure (ChildRecord (Text.pack tool) "" "" (map Text.pack arguments) 127, "", "executable not found: " <> tool)
    Just executable -> do
      digest <- try (sha256File executable) :: IO (Either IOException Text)
      outcome <- try (readCreateProcessWithExitCode ((proc executable arguments) {cwd = Just workingDirectory}) "") :: IO (Either IOException (ExitCode, String, String))
      let (exit, out, err) = either (\problem -> (ExitFailure 127, "", show problem)) id outcome
          code = case exit of ExitSuccess -> 0; ExitFailure n -> n
      pure (ChildRecord (Text.pack tool) executable (either (const "unrecorded") id digest) (map Text.pack arguments) code, out, err)
resolveTool :: Maybe FilePath -> String -> IO (Maybe FilePath)
resolveTool selected name = case selected of
  Just path -> do
    absolute <- makeAbsolute path
    present <- doesFileExist absolute
    pure (if present then Just absolute else Nothing)
  Nothing -> do
    found <- findExecutable name
    case found of
      Just path -> Just <$> makeAbsolute path
      Nothing -> do
        home <- getHomeDirectory
        let path = home </> ".ghcup" </> "bin" </> name
        present <- doesFileExist path
        pure (if present then Just path else Nothing)
selectToolchain :: FilePath -> ToolchainPaths -> IO (Either [AcquisitionRefusal] Acquisition)
selectToolchain root paths = do
  selected <- sequence [resolveTool (pathGhcup paths) "ghcup", resolveTool (pathGhc paths) "ghc", resolveTool (pathCabal paths) "cabal"]
  case selected of
    [Just ghcup, Just ghc, Just cabal] -> do
      cupObservation@(cupChild, cup, _) <- spawnChild root ghcup ["--version"]
      compilerObservation@(ghcChild, compiler, _) <- spawnChild root ghc ["--numeric-version"]
      packageObservation@(cabalChild, package, _) <- spawnChild root cabal ["--numeric-version"]
      let observations = [cupObservation, compilerObservation, packageObservation]
          failures = [ToolCommandFailed (childTool child) | (child, _, _) <- take 2 observations, childExit child /= 0]
          checks = [checkVersion ghcupRequirement (Text.pack cup), checkVersion ghcRequirement (Text.pack compiler)]
          problems = failures <> [VersionRefused value | Left value <- checks]
          numeric source = maybe "" (Text.intercalate "." . map (Text.pack . show)) (versionNumbers (Text.pack source))
      pure (if null problems then Right (Acquisition root ghcup ghc cabal (numeric cup) (numeric compiler) (Text.strip (Text.pack package)) [cupChild, ghcChild, cabalChild]) else Left problems)
    _ -> pure (Left [ToolMissing tool | (tool, Nothing) <- zip ["ghcup", "ghc", "cabal"] selected])
acquire :: ToolchainPaths -> FilePath -> IO (Either [AcquisitionRefusal] Acquisition)
acquire paths root = do
  present <- doesPathExist root
  if present then pure (Left [RootNotAbsent root]) else do
    createDirectoryIfMissing True root
    selectToolchain root paths
acquireTwice :: ToolchainPaths -> FilePath -> FilePath -> IO (Either [AcquisitionRefusal] (Acquisition, Acquisition))
acquireTwice paths a b = do
  first <- acquire paths a
  case first of
    Left problems -> pure (Left problems)
    Right one -> do
      second <- acquire paths b
      pure $ case second of
        Left problems -> Left problems
        Right two -> case agreement one two of [] -> Right (one, two); problems -> Left problems
agreement :: Acquisition -> Acquisition -> [AcquisitionRefusal]
agreement a b = [AcquisitionsDisagree field (get a) (get b) | (field, get) <- [("ghcup.version", acquisitionGhcupVersion), ("compiler.version", acquisitionCompilerVersion)], get a /= get b]
renderAcquisition :: Acquisition -> [(Text, Text)]
renderAcquisition value = [("ghcup.version", acquisitionGhcupVersion value), ("compiler.version", acquisitionCompilerVersion value), ("package-tool.version", acquisitionPackageToolVersion value), ("ghcup.executable", Text.pack (acquisitionGhcup value)), ("compiler.executable", Text.pack (acquisitionCompiler value)), ("package-tool.executable", Text.pack (acquisitionPackageTool value))]
writeAcquisitionReceipt :: Acquisition -> IO FilePath
writeAcquisitionReceipt value = do
  let path = acquisitionRoot value </> "toolchain-observations.tsv"
  TextIO.writeFile path (Text.unlines [key <> "\t" <> observed | (key, observed) <- renderAcquisition value])
  pure path
removeAcquisition :: Acquisition -> IO ()
removeAcquisition _ = pure ()
