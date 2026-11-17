{-# LANGUAGE OverloadedStrings #-}

-- | The shipped native build transport. Concurrency is fixed here, outside
-- mutable resolution policy: callers supply intent, never a parallelism limit.
module Amoebius.Build.Serial
  ( BuildObservation (..)
  , copyToolExecutable
  , nativeCabalPath
  , serialCabalArguments
  , serialGhcArguments
  , spawnCabal
  , spawnCabalIn
  , spawnToolInstall
  ) where

import Amoebius.Toolchain.Acquire (ChildRecord (..), nativeCabalConfig, sha256File)
import Amoebius.Internal.Process.EmptyInput (presentEnvironment, tryReadEmptyInput)
import Control.Concurrent.MVar (MVar, newMVar, withMVar)
import Control.Exception (IOException, bracket, try)
import Control.Monad (unless)
import Data.Aeson (Value, eitherDecodeStrict', withObject, (.:))
import Data.Aeson.Types (Parser, parseEither)
import Data.ByteString qualified as ByteString
import Data.Char (isDigit)
import Data.List (isPrefixOf, nub)
import Data.Maybe (catMaybes)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Text.IO qualified as TextIO
import System.Directory (canonicalizePath, copyFile, createDirectory, createDirectoryIfMissing, doesDirectoryExist, doesFileExist, doesPathExist, findExecutable, getFileSize, listDirectory, pathIsSymbolicLink, removePathForcibly)
import System.Environment (getEnvironment)
import System.Exit (ExitCode (..))
import System.FilePath (isAbsolute, makeRelative, splitDirectories, takeDirectory, (</>))
import System.IO.Unsafe (unsafePerformIO)

data BuildObservation = BuildObservation
  { buildRequestedArgv :: [Text]
  , buildEffectiveChild :: ChildRecord
  }
  deriving (Eq, Show)

-- The lock has no configuration surface. A transport invocation waits for the
-- preceding compiler-bearing child, including its complete process result.
{-# NOINLINE compilerLock #-}
compilerLock :: MVar ()
compilerLock = unsafePerformIO (newMVar ())

withoutJobs :: [String] -> [String]
withoutJobs arguments = case arguments of
  [] -> []
  (flag : value : rest)
    | flag `elem` ["-j", "--jobs"], not (null value), all isDigit value -> withoutJobs rest
  (flag : rest)
    | flag `elem` ["-j", "--jobs"] || "--jobs=" `isPrefixOf` flag || "-j" `isPrefixOf` flag -> withoutJobs rest
    | otherwise -> flag : withoutJobs rest

serialGhcArguments :: [String] -> [String]
serialGhcArguments arguments = withoutJobs options <> ["-j1"] <> payload
 where (options, payload) = break (== "--") arguments

-- | Cabal's scheduler and every GHC invocation it constructs are serial and
-- network resolution is disabled. Its compiler is the explicit native input,
-- independent of caller argv mutations.
serialCabalArguments :: FilePath -> [String] -> [String]
serialCabalArguments compiler arguments = clean (withoutJobs options)
  <> ["--offline", "--jobs=1", "--with-compiler=" <> compiler, "--ghc-options=-j1"] <> payload
 where
  (options, payload) = break (== "--") arguments
  clean values = case values of
    [] -> []
    (flag : value : rest)
      | flag `elem` ["--offline", "--online"], value `elem` ["True", "False", "true", "false"] -> clean rest
    (flag : _ : rest) | flag `elem` ["--with-compiler", "--with-ghc", "-w"] -> clean rest
    (flag : value : rest) | flag `elem` ["--ghc-options", "--ghc-option"] -> option flag value <> clean rest
    (flag : rest)
      | flag `elem` ["--offline", "--online", "--no-offline"]
          || any (`isPrefixOf` flag) ["--offline=", "--online=", "--no-offline="] -> clean rest
      | any (`isPrefixOf` flag) ["--with-compiler=", "--with-ghc=", "-w"] -> clean rest
      | "--ghc-options=" `isPrefixOf` flag -> option "--ghc-options" (drop (length ("--ghc-options=" :: String)) flag) <> clean rest
      | "--ghc-option=" `isPrefixOf` flag -> option "--ghc-option" (drop (length ("--ghc-option=" :: String)) flag) <> clean rest
      | otherwise -> flag : clean rest
  option flag value = case withoutJobs (words value) of
    [] -> []
    kept -> [flag <> "=" <> unwords kept]

-- | Observe requested and effective arguments separately. Native tool digests
-- are historical observations only; no byte or platform admission occurs here.
spawnCabal :: FilePath -> FilePath -> FilePath -> [String] -> IO (BuildObservation, String, String)
spawnCabal directory = spawnCabalIn directory (directory </> ".build")

-- | Use an explicit observation owner beneath the repository's build tree.
spawnCabalIn :: FilePath -> FilePath -> FilePath -> FilePath -> [String] -> IO (BuildObservation, String, String)
spawnCabalIn directory owner tool compiler requested = withMVar compilerLock $ \() -> do
  let normalized = serialCabalArguments compiler (withoutOptions ["--config-file"] [] requested)
  createDirectoryIfMissing True owner
  selected <- nativeCabalConfig owner
  result@(child, out, err) <- case selected of
    Left problem -> pure (ChildRecord (Text.pack tool) "" "" (map Text.pack normalized) 127, "", "native Cabal configuration refused: " <> Text.unpack problem)
    Right config -> do
      environment <- nativeTemporaryEnvironment owner
      observeChild (Just environment) directory tool ("--config-file=" <> config : normalized)
  let observation = BuildObservation (map Text.pack requested) child
  recordBuild directory observation result
  pure (observation, out, err)

observeChild :: Maybe [(String, String)] -> FilePath -> FilePath -> [String] -> IO (ChildRecord, String, String)
observeChild environment directory tool effective = do
  resolved <- if isAbsolute tool then pure (Just tool) else findExecutable tool
  case resolved of
    Nothing -> pure (ChildRecord (Text.pack tool) "" "" (map Text.pack effective) 127, "", "executable not found: " <> tool)
    Just executable -> do
      digest <- try (sha256File executable) :: IO (Either IOException Text)
      result <- tryReadEmptyInput directory executable effective environment
      let (exit, stdout, stderr) = either (\problem -> (ExitFailure 127, "", show problem)) id result
          code = case exit of ExitSuccess -> 0; ExitFailure value -> value
      pure (ChildRecord (Text.pack tool) executable (either (const "unrecorded") id digest) (map Text.pack effective) code, stdout, stderr)

-- | Native path inputs are queried under an explicit existing configuration,
-- or an empty owned configuration when the implicit default is absent. Cabal
-- can therefore never create a native default configuration as a query effect.
nativeCabalPath :: FilePath -> FilePath -> FilePath -> [String] -> IO (Either Text (ChildRecord, String, String))
nativeCabalPath directory tool owner fields = withMVar compilerLock $ \() -> nativeCabalPathUnlocked directory tool owner fields

nativeCabalPathUnlocked :: FilePath -> FilePath -> FilePath -> [String] -> IO (Either Text (ChildRecord, String, String))
nativeCabalPathUnlocked directory tool owner fields = do
  selected <- nativeCabalConfig owner
  case selected of
    Left problem -> pure (Left problem)
    Right config -> do
      environment <- nativeTemporaryEnvironment owner
      Right <$> observeChild (Just environment) directory tool (["--config-file=" <> config, "path", "--ignore-project", "--output-format=json", "--offline", "--jobs=1", "--remote-repo-cache"]
        <> ["--store-dir" | "--store-dir" `elem` fields])

nativeTemporaryEnvironment :: FilePath -> IO [(String, String)]
nativeTemporaryEnvironment owner = do
  base <- canonicalizePath owner
  temporary <- canonicalizePath (base </> "native-cabal-tmp")
  unless (makeRelative base temporary == "native-cabal-tmp") (fail "native query temporary directory escapes its owner")
  createDirectoryIfMissing True temporary
  inherited <- getEnvironment
  let overrides = [(key, temporary) | key <- ["TMPDIR", "TMP", "TEMP"]]
  writeTable (base </> "native-query-environment.tsv") [(Text.pack key, Text.pack value) | (key, value) <- overrides]
  pure ([pair | pair@(key, _) <- inherited, key `notElem` map fst overrides] <> overrides)

recordBuild :: FilePath -> BuildObservation -> (ChildRecord, String, String) -> IO ()
recordBuild directory observation (child, out, err) = do
  let evidence = directory </> ".build"
  createDirectoryIfMissing True evidence
  TextIO.appendFile (evidence </> "native-build.tsv") (Text.unlines
    ["requested.argv\t" <> Text.pack (show (buildRequestedArgv observation))
    ,"effective.argv\t" <> Text.pack (show (childArgv child))
    ,"effective.executable\t" <> Text.pack (childExecutable child)
    ,"effective.exit\t" <> Text.pack (show (childExit child))
    ,"effective.stdout\t" <> Text.pack (show out)
    ,"effective.stderr\t" <> Text.pack (show err)])

copyToolExecutable :: FilePath -> FilePath -> IO ()
copyToolExecutable source target = withMVar compilerLock $ \() -> do
  copyFile source target
  before <- sha256File source
  after <- sha256File target
  writeTable (takeDirectory target </> ".build" </> "tool-materialization.tsv")
    [("kind", "path-copy"), ("source", Text.pack source), ("source-sha256", before), ("target", Text.pack target), ("target-sha256", after)]

-- | A real offline install with no inherited Cabal configuration or writable
-- native state. The selected repository is copied, used, and removed; installed
-- native packages may be read through one explicit extra database, while Cabal
-- registers newly built packages only in the final, owned store database.
spawnToolInstall :: FilePath -> FilePath -> FilePath -> Text -> Text -> Text -> [String] -> IO (Either Text (BuildObservation, String, String))
spawnToolInstall directory tool compiler compilerVersion package executable requested = withMVar compilerLock $ \() -> do
  let context = directory </> ".build" </> "install-context"
      cacheInput = context </> "cache-input"
      config = context </> "cabal.config"
      locations = [("owner", directory), ("config", config), ("home", context </> "home"), ("tmp", context </> "tmp")
        ,("cabal-dir", context </> "cabal"), ("xdg-cache-home", context </> "xdg-cache"), ("xdg-config-home", context </> "xdg-config")
        ,("xdg-data-home", context </> "xdg-data"), ("xdg-state-home", context </> "xdg-state"), ("store", context </> "store")
        ,("build", context </> "dist"), ("logs", context </> "logs"), ("world", context </> "world"), ("summary", context </> "summary.log")
        ,("native-db-query-build", context </> "query-dist"), ("source-plan", context </> "source-plan.json")
        ,("local-project", context </> "local.project"), ("local-plan", context </> "local-plan.json")
        ,("source-build", context </> "source-dist"), ("source-directory", context </> "source")]
      location key = maybe (error "install context location absent") id (lookup key locations)
  createDirectoryIfMissing True context
  mapM_ (createDirectoryIfMissing True . location) ["home", "tmp", "cabal-dir", "xdg-cache-home", "xdg-config-home", "xdg-data-home", "xdg-state-home", "store", "logs"]
  writeTable (context </> "context.tsv") [(key, Text.pack value) | (key, value) <- locations]
  environment <- installEnvironment location
  writeTable (context </> "environment.tsv") [(Text.pack key, Text.pack value) | (key, value) <- environment]
  TextIO.writeFile config (installConfig location cacheInput)
  attempted <- try (bracket (createDirectory cacheInput) (const (removePathForcibly cacheInput)) $ \() -> do
    query@(queryChild, queryOut, _) <- nativeCabalPathUnlocked directory tool context ["--remote-repo-cache", "--store-dir"] >>= either (fail . Text.unpack) pure
    TextIO.writeFile (context </> "cache-query.data") (Text.pack (show query))
    (nativeCache, nativeStore) <- either fail pure (eitherDecodeStrict' (TextEncoding.encodeUtf8 (Text.pack queryOut)) >>= parseEither
      (withObject "native paths" (\object -> (,) <$> object .: "remote-repo-cache" <*> object .: "store-dir")) :: Either String (FilePath, FilePath))
    unless (childExit queryChild == 0 && isAbsolute nativeCache && isAbsolute nativeStore) (fail "native repository/store query failed")
    cache <- canonicalizePath nativeCache
    repository <- canonicalizePath (cache </> "hackage.haskell.org")
    unless (makeRelative cache repository == "hackage.haskell.org") (fail "native repository escapes the selected cache")
    databaseQuery@(databaseChild, databaseOut, _) <- observeChild (Just environment) directory tool
      ["--config-file=" <> config, "--store-dir=" <> nativeStore, "path", "--ignore-project", "--output-format=json", "--remote-repo-cache", "--compiler-info"
      ,"--with-compiler=" <> compiler, "--builddir=" <> location "native-db-query-build", "--offline", "--jobs=1"]
    TextIO.writeFile (context </> "native-db-query.data") (Text.pack (show databaseQuery))
    (observedCache, nativeCompiler, flavour, identifier, compilerStore) <- either fail pure (eitherDecodeStrict' (TextEncoding.encodeUtf8 (Text.pack databaseOut)) >>= parseEither
      (withObject "native compiler paths" (\object -> object .: "compiler" >>= withObject "compiler" (\entry -> (,,,,) <$> object .: "remote-repo-cache" <*> entry .: "path" <*> entry .: "flavour" <*> entry .: "id" <*> entry .: "store-path"))) :: Either String (FilePath, FilePath, Text, Text, FilePath))
    actualCompiler <- canonicalizePath nativeCompiler
    expectedCompiler <- canonicalizePath compiler
    unless (observedCache == cacheInput) (fail "generated Cabal configuration does not select the owned repository cache")
    unless (childExit databaseChild == 0 && actualCompiler == expectedCompiler && flavour == "ghc" && identifier == "ghc-" <> compilerVersion && isAbsolute compilerStore) (fail "native compiler database metadata disagrees with the admitted compiler")
    let nativeDatabase = compilerStore </> "package.db"
    databasePresent <- doesDirectoryExist nativeDatabase
    physicalStore <- canonicalizePath nativeStore
    physicalDatabase <- canonicalizePath nativeDatabase
    let relativeDatabase = makeRelative physicalStore physicalDatabase
    unless (not (isAbsolute relativeDatabase) && ".." `notElem` splitDirectories relativeDatabase) (fail "native compiler database escapes the selected store")
    copied <- copyRepository repository (cacheInput </> "hackage.haskell.org")
    TextIO.writeFile (context </> "cache-copy.tsv") (Text.unlines [Text.intercalate "\t" [Text.pack path, Text.pack (show bytes), sourceDigest, copiedDigest] | (path, bytes, sourceDigest, copiedDigest) <- copied])
    appendTable (context </> "context.tsv") [("cache.source", Text.pack repository), ("cache.target", Text.pack (cacheInput </> "hackage.haskell.org"))
      ,("cache.files", Text.pack (show (length copied))), ("native-store", Text.pack nativeStore), ("native-db", if databasePresent then Text.pack nativeDatabase else "")]
    let (options, payload) = break (== "--") (serialCabalArguments compiler (withoutInstallPaths requested))
        effective build selection = ["--config-file=" <> config, "--store-dir=" <> location "store"] <> options
          <> selection <> ["--installdir=" <> directory, "--install-method=copy", "--overwrite-policy=always", "--builddir=" <> build
             ,"--build-summary=" <> location "summary", "--build-log=" <> (location "logs" </> "$pkgid.log"), "--remote-build-reporting=none"
             ,"--package-db=clear", "--package-db=global"] <> ["--package-db=" <> nativeDatabase | databasePresent] <> payload
        repositoryArguments = effective (location "source-build") ["--ignore-project", "--dry-run"]
    unless (safeName package && safeName executable) (fail "tool package or executable name is not a safe Cabal selector")
    sourceQuery@(sourceChild, _, _) <- observeChild (Just environment) directory tool repositoryArguments
    TextIO.writeFile (context </> "source-plan-query.data") (Text.pack (show sourceQuery))
    result@(child, out, err) <- if childExit sourceChild /= 0 then pure sourceQuery else do
      sourcePlan <- ByteString.readFile (location "source-build" </> "cache" </> "plan.json")
      ByteString.writeFile (location "source-plan") sourcePlan
      (version, digest) <- either fail pure (selectedRootArchive package sourcePlan)
      let relativeArchive = Text.unpack package </> Text.unpack version </> Text.unpack (package <> "-" <> version <> ".tar.gz")
          cachedArchive = cacheInput </> "hackage.haskell.org" </> relativeArchive
          archive = location "source-directory" </> Text.unpack (package <> "-" <> version <> ".tar.gz")
      actualDigest <- sha256File cachedArchive
      unless (actualDigest == digest && any (\(path, _, before, after) -> path == relativeArchive && before == digest && after == digest) copied)
        (fail "selected tool archive does not match the actual solver source hash and copied repository inventory")
      createDirectory (location "source-directory")
      copyFile cachedArchive archive
      retainedDigest <- sha256File archive
      unless (retainedDigest == digest) (fail "retained tool archive differs from the selected cached source")
      appendTable (context </> "context.tsv") [("source.package", package), ("source.version", version), ("source.sha256", digest)
        ,("source.cached-archive", Text.pack cachedArchive), ("source.archive", Text.pack archive)]
      -- Cabal 3.16 rejects configured repo-tar sources in offline mode even
      -- when fetched. An explicit local project makes the verified archive a
      -- LocalTarballPackage without weakening the transport's offline flag.
      TextIO.writeFile (location "local-project") ("packages: " <> Text.pack (show archive) <> "\n")
      let localSelector = Text.unpack (package <> ":exe:" <> executable)
          localArguments = map (\argument -> if argument == Text.unpack (package <> ":" <> executable) then localSelector else argument)
            (effective (location "build") ["--project-file=" <> location "local-project"])
      localResult <- observeChild (Just environment) directory tool localArguments
      localPlanPresent <- doesFileExist (location "build" </> "cache" </> "plan.json")
      if localPlanPresent then ByteString.readFile (location "build" </> "cache" </> "plan.json") >>= ByteString.writeFile (location "local-plan") else pure ()
      pure localResult
    let observation = BuildObservation (map Text.pack requested) child
    recordBuild directory observation result
    writeTable (directory </> ".build" </> "tool-materialization.tsv") [("kind", "isolated-install"), ("context", Text.pack context)]
    pure (observation, out, err)) :: IO (Either IOException (BuildObservation, String, String))
  removed <- not <$> doesPathExist cacheInput
  appendTable (context </> "context.tsv") [("cache.removed", Text.pack (show removed))]
  pure $ case attempted of
    Left problem -> Left (Text.pack (show problem))
    Right result | removed -> Right result
    Right _ -> Left "owned repository cache remains after tool installation"

-- Every configured component of the requested root must identify the same
-- actual source archive. These values come from Cabal's retained dry-run plan.
selectedRootArchive :: Text -> ByteString.ByteString -> Either String (Text, Text)
selectedRootArchive package bytes = do
  value <- eitherDecodeStrict' bytes
  roots <- parseEither (withObject "tool plan" (\object -> object .: "install-plan" >>= mapM root)) value
  case nub (catMaybes roots) of
    [(version, digest)] | safeVersion version && Text.length digest == 64 && Text.all (`elem` ("0123456789abcdef" :: String)) digest -> Right (version, digest)
    _ -> Left "tool plan does not identify one safe source archive for the requested package"
 where
  root :: Value -> Parser (Maybe (Text, Text))
  root = withObject "tool unit" $ \object -> do
    name <- object .: "pkg-name"
    if name /= package then pure Nothing else do
      kind <- object .: "type"
      unless (kind == ("configured" :: Text)) (fail "requested tool root is not configured from source")
      Just <$> ((,) <$> object .: "pkg-version" <*> object .: "pkg-src-sha256")
  safeVersion value = not (Text.null value) && all (\part -> not (Text.null part) && Text.all (`elem` ("0123456789" :: String)) part) (Text.splitOn "." value)

safeName :: Text -> Bool
safeName value = not (Text.null value) && value `notElem` [".", ".."] && Text.all (`elem` ("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_." :: String)) value

installEnvironment :: (Text -> FilePath) -> IO [(String, String)]
installEnvironment location = do
  inherited <- presentEnvironment ["PATH", "LANG", "SystemRoot", "SYSTEMROOT", "WINDIR", "COMSPEC", "PATHEXT"]
  pure (inherited <> [(key, location value) | (key, value) <- [("HOME", "home"), ("TMPDIR", "tmp"), ("TMP", "tmp"), ("TEMP", "tmp"), ("CABAL_DIR", "cabal-dir")
    ,("XDG_CACHE_HOME", "xdg-cache-home"), ("XDG_CONFIG_HOME", "xdg-config-home"), ("XDG_DATA_HOME", "xdg-data-home"), ("XDG_STATE_HOME", "xdg-state-home")]] <> [("GHC_ENVIRONMENT", "-"), ("LC_ALL", "C.UTF-8")])

installConfig :: (Text -> FilePath) -> FilePath -> Text
installConfig location cacheInput = Text.unlines
  (["repository hackage.haskell.org", "  url: https://hackage.haskell.org/", "  secure: True", "remote-repo-cache: " <> Text.pack cacheInput]
  <> [key <> ": " <> Text.pack (location field) | (key, field) <- [("store-dir", "store"), ("logs-dir", "logs"), ("world-file", "world"), ("build-summary", "summary")]]
  <> ["remote-build-reporting: none", "jobs: 1", "offline: True"])

withoutInstallPaths :: [String] -> [String]
withoutInstallPaths = withoutOptions owned ["--ignore-project"]
 where
  owned = ["--config-file", "--store-dir", "--logs-dir", "--world-file", "--remote-repo-cache", "--builddir", "--build-summary", "--build-log"
    ,"--installdir", "--install-method", "--overwrite-policy", "--project-dir", "--project-file", "--package-db", "--remote-build-reporting"]

withoutOptions :: [String] -> [String] -> [String] -> [String]
withoutOptions valued switches arguments = clean options <> payload
 where
  (options, payload) = break (== "--") arguments
  clean values = case values of
    [] -> []
    (flag : _ : rest) | flag `elem` valued -> clean rest
    (flag : rest) | any (\key -> (key <> "=") `isPrefixOf` flag) valued || flag `elem` switches -> clean rest
    (flag : rest) -> flag : clean rest

copyRepository :: FilePath -> FilePath -> IO [(FilePath, Integer, Text, Text)]
copyRepository source target = walk ""
 where
  walk relative = do
    let origin = source </> relative; destination = target </> relative
    linked <- pathIsSymbolicLink origin
    unless (not linked) (fail "native repository input contains a symbolic link")
    directory <- doesDirectoryExist origin
    if directory then do
      createDirectory destination
      names <- listDirectory origin
      concat <$> mapM (walk . (relative </>)) names
    else do
      regular <- doesFileExist origin
      unless regular (fail "native repository input is not a regular file")
      copyFile origin destination
      bytes <- getFileSize destination
      before <- sha256File origin
      after <- sha256File destination
      unless (before == after) (fail "native repository input changed while copying")
      pure [(relative, bytes, before, after)]

writeTable :: FilePath -> [(Text, Text)] -> IO ()
writeTable path rows = createDirectoryIfMissing True (takeDirectory path) >> TextIO.writeFile path (renderTable rows)
appendTable :: FilePath -> [(Text, Text)] -> IO ()
appendTable path rows = TextIO.appendFile path (renderTable rows)
renderTable :: [(Text, Text)] -> Text
renderTable rows = Text.unlines [key <> "\t" <> value | (key, value) <- rows]
