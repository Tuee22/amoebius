{-# LANGUAGE OverloadedStrings #-}
-- | Select native tools and check their versions. No platform or byte pin is
-- admitted here; digests in child observations are optional historical metadata.
module Amoebius.Toolchain.Acquire
  ( Acquisition (..), AcquisitionRefusal (..), ChildRecord (..), ToolchainPaths (..)
  , defaultToolchainPaths, acquire, acquireTwice, selectToolchain, agreement
  , resolveTool, judgeToolchainSelection
  , renderAcquisition, renderChild, renderRefusal, hexEncode, sha256Bytes
  , sha256File, spawnChild, writeAcquisitionReceipt, removeAcquisition, nativeCabalConfig
  , NativeCabalConfigAttempt, NativeConfigSelection (..), NativeConfigOrigin (..)
  , NativeConfigStep (..), NativeConfigReturn (..), NativeConfigObservation (..)
  , NativeConfigAttemptView (..), acquireNativeCabalConfigAttempt
  , projectNativeCabalConfigAttempt, actualNativeCabalConfigResult
  , projectNativeCabalConfigCompatibility
  ) where
import Amoebius.Toolchain.Versions
import Amoebius.Internal.Process.EmptyInput (tryReadEmptyInput)
import Control.Exception (IOException, evaluate, throwIO, try)
import Control.Monad (unless)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Char (intToDigit)
import Data.IORef (modifyIORef', newIORef, readIORef)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (XdgDirectory (XdgConfig), canonicalizePath, createDirectoryIfMissing, doesDirectoryExist, doesFileExist, doesPathExist, findExecutable, getAppUserDataDirectory, getCurrentDirectory, getHomeDirectory, getXdgDirectory, makeAbsolute)
import System.Environment (lookupEnv)
import System.Exit (ExitCode (..))
import System.FilePath (isAbsolute, makeRelative, normalise, splitDirectories, (</>))
import System.IO (Handle, IOMode (ReadMode), hClose, openTempFile, withBinaryFile)

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
sha256File path = withBinaryFile path ReadMode $ \handle -> do
  bytes <- LazyByteString.hGetContents handle
  evaluate (hexEncode (SHA256.hashlazy bytes))
-- | Select Cabal's native configuration without allowing its default-config
-- creation side effect. The directory rules match Cabal 3.16's Config module.
-- A missing implicit configuration uses an empty, exclusively created file in
-- the supplied observation owner; Cabal still derives defaults from the native
-- environment. An explicit missing CABAL_CONFIG is an error, never a fallback.
nativeCabalConfig :: FilePath -> IO (Either Text FilePath)
nativeCabalConfig owner = projectNativeCabalConfigCompatibility <$> acquireNativeCabalConfigAttempt owner

-- The constructor and mutable recorder remain private. A view is descriptive
-- data; only this fixed producer can return an actual selection attempt.
data NativeCabalConfigAttempt = NativeCabalConfigAttempt NativeConfigAttemptView (Maybe Handle)
data NativeConfigSelection = ExplicitConfigSelection | CabalDirectoryConfigSelection
  | LegacyConfigSelection | XdgConfigSelection deriving (Eq, Show)
data NativeConfigOrigin = ExistingSelectedConfig | FreshImplicitConfig deriving (Eq, Show)
data NativeConfigStep = ConfigCurrentDirectory | ConfigCanonicalFrame FilePath
  | ConfigCanonicalBuild FilePath | ConfigCanonicalOwner FilePath
  | ConfigOwnerDirectory FilePath | ConfigOwnerPolicy FilePath FilePath FilePath Bool
  | ConfigLookupExplicit | ConfigLookupCabalDirectory | ConfigLegacyDirectory
  | ConfigLegacyDirectoryPresent FilePath | ConfigXdgPath | ConfigXdgFilePresent FilePath
  | ConfigSelectedFilePresent FilePath | ConfigSelectedAbsolute FilePath
  | ConfigExplicitMissing FilePath | ConfigFreshOpen FilePath String | ConfigFreshClose FilePath
  deriving (Eq, Show)
data NativeConfigReturn = ConfigPathReturn FilePath | ConfigBoolReturn Bool
  | ConfigLookupReturn (Maybe String) | ConfigFreshOpenReturn FilePath | ConfigUnitReturn
  deriving (Eq, Show)
data NativeConfigObservation = NativeConfigObservation
  { configObservationStep :: NativeConfigStep
  , configObservationReturn :: Maybe (Either IOException NativeConfigReturn) } deriving Show
data NativeConfigAttemptView = NativeConfigAttemptView
  { configAttemptOwnerInput :: FilePath
  , configAttemptObservations :: [NativeConfigObservation]
  , configAttemptSelection :: Maybe NativeConfigSelection
  , configAttemptSelectedOperand :: Maybe FilePath
  , configAttemptOrigin :: Maybe NativeConfigOrigin
  , configAttemptResult :: Either IOException FilePath } deriving Show
projectNativeCabalConfigAttempt :: NativeCabalConfigAttempt -> NativeConfigAttemptView
projectNativeCabalConfigAttempt (NativeCabalConfigAttempt view _) = view
actualNativeCabalConfigResult :: NativeCabalConfigAttempt -> Either IOException FilePath
actualNativeCabalConfigResult = configAttemptResult . projectNativeCabalConfigAttempt
projectNativeCabalConfigCompatibility :: NativeCabalConfigAttempt -> Either Text FilePath
projectNativeCabalConfigCompatibility = either (Left . Text.pack . show) Right . actualNativeCabalConfigResult

acquireNativeCabalConfigAttempt :: FilePath -> IO NativeCabalConfigAttempt
acquireNativeCabalConfigAttempt owner = do
  observations <- newIORef []
  selection <- newIORef Nothing
  operand <- newIORef Nothing
  origin <- newIORef Nothing
  openHandle <- newIORef Nothing
  let record :: NativeConfigStep -> (a -> NativeConfigReturn) -> IO a -> IO a
      record step project action = do
        modifyIORef' observations (NativeConfigObservation step Nothing :)
        result <- try action
        modifyIORef' observations $ \entries -> case entries of
          NativeConfigObservation started _ : earlier ->
            NativeConfigObservation started (Just (fmap project result)) : earlier
          [] -> []
        either throwIO pure result
      selectBranch branch path = do
        modifyIORef' selection (const (Just branch))
        modifyIORef' operand (const (Just path))
        pure path
      completed completedOrigin path = do
        modifyIORef' origin (const (Just completedOrigin))
        pure path
      select = do
        current <- record ConfigCurrentDirectory ConfigPathReturn getCurrentDirectory
        frame <- record (ConfigCanonicalFrame current) ConfigPathReturn (canonicalizePath current)
        build <- record (ConfigCanonicalBuild (frame </> ".build")) ConfigPathReturn (canonicalizePath (frame </> ".build"))
        owned <- record (ConfigCanonicalOwner owner) ConfigPathReturn (canonicalizePath owner)
        ready <- record (ConfigOwnerDirectory owned) ConfigBoolReturn (doesDirectoryExist owned)
        let relative = makeRelative build owned
        record (ConfigOwnerPolicy frame build owned ready) (const ConfigUnitReturn) $
          unless (ready && build == normalise (frame </> ".build") && relative /= "."
            && not (isAbsolute relative) && ".." `notElem` splitDirectories relative)
            (fail "NativeCabalConfigOwnerOutsideBuild")
        explicit <- record ConfigLookupExplicit ConfigLookupReturn (lookupEnv "CABAL_CONFIG")
        selected <- case explicit of
          Just path -> selectBranch ExplicitConfigSelection path
          Nothing -> do
            singleRoot <- record ConfigLookupCabalDirectory ConfigLookupReturn (lookupEnv "CABAL_DIR")
            case singleRoot of
              Just directory -> selectBranch CabalDirectoryConfigSelection (directory </> "config")
              Nothing -> do
                legacy <- record ConfigLegacyDirectory ConfigPathReturn (getAppUserDataDirectory "cabal")
                legacyPresent <- record (ConfigLegacyDirectoryPresent legacy) ConfigBoolReturn (doesDirectoryExist legacy)
                xdg <- record ConfigXdgPath ConfigPathReturn (getXdgDirectory XdgConfig ("cabal" </> "config"))
                xdgPresent <- record (ConfigXdgFilePresent xdg) ConfigBoolReturn (doesFileExist xdg)
                if legacyPresent && not xdgPresent
                  then selectBranch LegacyConfigSelection (legacy </> "config")
                  else selectBranch XdgConfigSelection xdg
        present <- record (ConfigSelectedFilePresent selected) ConfigBoolReturn (doesFileExist selected)
        if present then do
          path <- record (ConfigSelectedAbsolute selected) ConfigPathReturn (makeAbsolute selected)
          completed ExistingSelectedConfig path
        else case explicit of
          Just _ -> record (ConfigExplicitMissing selected) ConfigPathReturn (fail ("NativeCabalConfigAbsent: " <> selected))
          Nothing -> do
            (path, handle) <- record (ConfigFreshOpen owned "native-cabal-config-") (ConfigFreshOpenReturn . fst) (openTempFile owned "native-cabal-config-")
            modifyIORef' openHandle (const (Just handle))
            record (ConfigFreshClose path) (const ConfigUnitReturn) (hClose handle)
            modifyIORef' openHandle (const Nothing)
            completed FreshImplicitConfig path
  result <- try select
  view <- NativeConfigAttemptView owner . reverse <$> readIORef observations
    <*> readIORef selection <*> readIORef operand <*> readIORef origin <*> pure result
  NativeCabalConfigAttempt view <$> readIORef openHandle
-- | Resolve a tool, capture exit/streams, and optionally record its bytes. A
-- digest cannot admit or reject a tool; only version observations do that.
spawnChild :: FilePath -> String -> [String] -> IO (ChildRecord, String, String)
spawnChild workingDirectory tool arguments = do
  resolved <- if isAbsolute tool then pure (Just tool) else findExecutable tool
  case resolved of
    Nothing -> pure (ChildRecord (Text.pack tool) "" "" (map Text.pack arguments) 127, "", "executable not found: " <> tool)
    Just executable -> do
      digest <- try (sha256File executable) :: IO (Either IOException Text)
      outcome <- tryReadEmptyInput workingDirectory executable arguments Nothing
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
      cupObservation@(_, _, _) <- spawnChild root ghcup ["--version"]
      compilerObservation@(_, _, _) <- spawnChild root ghc ["--numeric-version"]
      packageObservation@(_, _, _) <- spawnChild root cabal ["--numeric-version"]
      pure (judgeToolchainSelection root (ghcup, ghc, cabal) (cupObservation, compilerObservation, packageObservation))
    _ -> pure (Left [ToolMissing tool | (tool, Nothing) <- zip ["ghcup", "ghc", "cabal"] selected])
-- | Share the existing product version judgment without acquiring any tools.
judgeToolchainSelection :: FilePath -> (FilePath, FilePath, FilePath)
  -> ((ChildRecord, String, String), (ChildRecord, String, String), (ChildRecord, String, String))
  -> Either [AcquisitionRefusal] Acquisition
judgeToolchainSelection root (ghcup, ghc, cabal) (cupObservation, compilerObservation, packageObservation) =
  let (cupChild, cup, _) = cupObservation
      (ghcChild, compiler, _) = compilerObservation
      (cabalChild, package, _) = packageObservation
      observations = [cupObservation, compilerObservation, packageObservation]
      failures = [ToolCommandFailed (childTool child) | (child, _, _) <- take 2 observations, childExit child /= 0]
      checks = [checkVersion ghcupRequirement (Text.pack cup), checkVersion ghcRequirement (Text.pack compiler)]
      problems = failures <> [VersionRefused value | Left value <- checks]
      numeric source = maybe "" (Text.intercalate "." . map (Text.pack . show)) (versionNumbers (Text.pack source))
   in if null problems then Right (Acquisition root ghcup ghc cabal (numeric cup) (numeric compiler) (Text.strip (Text.pack package)) [cupChild, ghcChild, cabalChild]) else Left problems
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
