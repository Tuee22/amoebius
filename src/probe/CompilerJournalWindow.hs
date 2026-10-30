{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | Executable-private, unsealed compiler-call bookkeeping. This is neither a
-- native observer nor a source/target/image permission or validation factory.
module CompilerJournalWindow
  ( runRecordedCabal, runRecordedCompiler, runRecordedWindowCompiler
  , writeRecordedCompilerWrapper
  ) where

import Amoebius.Compiler.Journal.Raw
import Amoebius.Extension.AstCheck (CheckedExtensionSource, checkedSourceFiles)
import Control.Exception (IOException, evaluate, throwIO, try)
import Control.Monad (forM, unless, void, when)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as Bytes
import Data.List (foldl', isSuffixOf, sort, sortOn, stripPrefix)
import Data.List.NonEmpty qualified as NonEmpty
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import GHC.IO.Exception qualified as GHC
import Numeric (showHex)
import Numeric.Natural (Natural)
import System.Directory
  ( canonicalizePath, copyPermissions, createDirectory, createDirectoryIfMissing
  , getCurrentDirectory, listDirectory, makeAbsolute, pathIsSymbolicLink
  , removeDirectory, removeFile )
import System.Environment (getExecutablePath)
import System.Exit (ExitCode (..))
import System.FilePath
  ( (</>), equalFilePath, isAbsolute, makeRelative, normalise
  , splitDirectories, takeDirectory, takeFileName )
import System.IO (IOMode (WriteMode), hClose, openTempFile, withBinaryFile)
import System.IO.Error (isDoesNotExistError)
import System.PosixCompat.Files qualified as Files
import System.Process (rawSystem)
import Text.Read (readMaybe)

data PrivatelyAcquiredWindow = PrivatelyAcquiredWindow FilePath FilePath
data PrivatelyHeldStateGate = PrivatelyHeldStateGate FilePath
-- No live resource constructor or DTO is exported; a Read cannot acquire one.
data OwnedCall = OwnedCall PrivatelyAcquiredWindow FilePath CompilerRequest

data FixedFile = FixedFile FilePath Text deriving (Eq, Read, Show)
fixedWindowFiles :: [FixedFile]
fixedWindowFiles =
  [ FixedFile "window-input.data" "WindowInput"
  , FixedFile "window-ready.data" "WindowReady (CabalWindow only)"
  , FixedFile "aggregate-begin.data" "AggregateBegin (CabalWindow only)"
  , FixedFile "aggregate-return.data" "AggregateReturn (CabalWindow only)"
  , FixedFile "window-close.data" "WindowClose" ]
fixedCallFiles :: [FixedFile]
fixedCallFiles =
  [ FixedFile "begin.data" "CompilerCallBegin"
  , FixedFile "return.data" "CompilerCallReturn"
  , FixedFile "retention-failure.data" "RetentionFailure (actual optional failure only)" ]

runRecordedCabal :: CheckedExtensionSource -> FilePath -> FilePath -> FilePath
  -> FilePath -> String -> [String] -> IO ExitCode
runRecordedCabal seal root compiler cabal config command arguments = do
  compilerPath <- makeAbsolute compiler
  helper <- getExecutablePath
  window <- acquireFreshWindow root
  let owner = windowPath window
      directory = owner </> "bootstrap/compiler-transport"
      source = directory </> "Main.hs"
      output = owner </> "bootstrap/ghc.exe"
      copy = owner </> "compiler/ghc.exe"
      effective = ["--config-file=" <> config, command, "--offline", "--jobs=1",
                   "--with-compiler=" <> copy] <> arguments
      admission = checkedProjection seal
      rendered = Encoding.encodeUtf8 (Text.pack (unlines (cabalBridgeLines helper compilerPath root)))
  createOwnedDirectory window (owner </> "bootstrap")
  createOwnedDirectory window directory
  createOwnedDirectory window (owner </> "compiler")
  void (evaluate (Bytes.length rendered))
  writeFreshBytes window source rendered
  actualSource <- readOwnedRegular window source
  equal <- evaluate (actualSource == rendered)
  unless equal (setupRefusal "bridge source readback differs from rendered bytes")
  let input = WindowInput CabalWindow owner root admission compiler (Returned compilerPath)
        helper (Just cabal) (Just config) (Just command) arguments effective
        (Just CabalWindowLocatedBridge) (Just (SourceReference source (Returned actualSource)))
        (Just output) (Just copy) Nothing existingModes
  writeFreshShown window (owner </> "window-input.data") input
  bootstrap <- recordCompiler window BridgeBootstrapCompiler admission compilerPath root Nothing
    (bootstrapArguments True directory source output)
    (bootstrapArguments True directory source output)
  case bootstrap of
    Left original -> do
      bestEffortClose window (NotAttempted "bootstrap threw IOException")
      throwIO original
    Right failure@(ExitFailure _) -> do
      bestEffortClose window (NotAttempted "bootstrap returned nonzero")
      pure failure
    Right ExitSuccess -> do
      (built, builtReference) <- readImage window output
      writeFreshBytes window copy built
      copyPermissions output copy
      (copied, copyReference) <- readImage window copy
      same <- evaluate (built == copied)
      unless same (setupRefusal "callable compiler bridge copy differs from bootstrap image")
      writeFreshShown window (owner </> "window-ready.data")
        (WindowReady owner builtReference copyReference (Returned same) admission)
      writeFreshShown window (owner </> "aggregate-begin.data")
        (AggregateBegin OuterCabal cabal effective existingModes)
      result <- tryIO (rawSystem cabal effective)
      let aggregate = either (AggregateThrewIOException OuterCabal . failureView "rawSystem Cabal")
            (AggregateReturned OuterCabal) result
      void (tryIO (writeFreshShown window (owner </> "aggregate-return.data") aggregate))
      bestEffortClose window (Returned aggregate)
      restoreRaw result

runRecordedCompiler :: CheckedExtensionSource -> FilePath -> FilePath -> [String] -> IO ExitCode
runRecordedCompiler seal compiler root arguments = do
  helper <- getExecutablePath
  window <- acquireFreshWindow root
  let admission = checkedProjection seal
      input = WindowInput StandaloneDelegatedCompilerWindow (windowPath window) root admission
        compiler (NotAttempted "direct compiler uses requested spelling unchanged") helper
        Nothing Nothing Nothing [] [] Nothing Nothing Nothing Nothing Nothing existingModes
  writeFreshShown window (windowPath window </> "window-input.data") input
  result <- recordCompiler window ReAdmittedDelegatedCompiler admission compiler root Nothing
    arguments (arguments <> ["-j1"])
  bestEffortClose window (NotAttempted "standalone profile has no Cabal call")
  restoreRaw result

runRecordedWindowCompiler :: CheckedExtensionSource -> FilePath -> FilePath -> FilePath
  -> FilePath -> [String] -> IO ExitCode
runRecordedWindowCompiler seal requestedWindow bridge compiler root arguments = do
  window <- acquireExistingCabalWindow root requestedWindow bridge compiler
  result <- recordCompiler window ReAdmittedDelegatedCompiler (checkedProjection seal)
    compiler root (Just bridge) arguments (arguments <> ["-j1"])
  restoreRaw result

writeRecordedCompilerWrapper :: FilePath -> FilePath -> IO ExitCode
writeRecordedCompilerWrapper compiler output = do
  -- Preserve the original standalone source/output/encoding/template and flags.
  compilerPath <- makeAbsolute compiler
  helper <- getExecutablePath
  root <- getCurrentDirectory
  wrapper <- makeAbsolute output
  let relative = makeRelative (root </> ".build") wrapper
  when (isAbsolute relative || ".." `elem` splitDirectories relative)
    (fail "compiler transport output must remain beneath .build")
  let directory = takeDirectory wrapper </> "compiler-transport"
      source = directory </> "Main.hs"
  createDirectoryIfMissing True directory
  actualDirectory <- canonicalizePath directory
  buildDirectory <- canonicalizePath (root </> ".build")
  let actualRelative = makeRelative buildDirectory actualDirectory
  when (isAbsolute actualRelative || ".." `elem` splitDirectories actualRelative)
    (fail "compiler transport directory escapes .build")
  writeFile source (unlines (standaloneBridgeLines helper compilerPath root))
  window <- acquireFreshWindow root
  let input = WindowInput StandaloneWrapperBuildWindow (windowPath window) root
        NotPerformedByExistingStandaloneBootstrapEntrypoint compiler (Returned compilerPath)
        helper Nothing Nothing Nothing [] [] (Just ExistingStandaloneFixedPathBridge)
        (Just (SourceReference source (NotAttempted "existing standalone source has no readback")))
        (Just wrapper) Nothing (Just output) existingModes
      args = bootstrapArguments False directory source wrapper
  writeFreshShown window (windowPath window </> "window-input.data") input
  result <- recordCompiler window BridgeBootstrapCompiler
    NotPerformedByExistingStandaloneBootstrapEntrypoint compilerPath root Nothing args args
  bestEffortClose window (NotAttempted "standalone profile has no Cabal call")
  restoreRaw result

existingModes :: ExistingModes
existingModes = InheritStdinStdoutStderrEnvironmentAndCwdDelegateControlCTrue

checkedProjection :: CheckedExtensionSource -> SourceAdmission
checkedProjection = ActualCheckedContributionProjection . NonEmpty.toList . checkedSourceFiles

cabalBridgeLines :: FilePath -> FilePath -> FilePath -> [String]
cabalBridgeLines helper compiler root =
  [ "module Main (main) where"
  , "import System.Environment (getArgs, getExecutablePath)"
  , "import System.Exit (exitWith)"
  , "import System.FilePath (takeDirectory)"
  , "import System.Process (rawSystem)"
  , "main :: IO ()"
  , "main = do"
  , "  args <- getArgs"
  , "  self <- getExecutablePath"
  , "  let window = takeDirectory (takeDirectory self)"
  , "  rawSystem " <> show helper <> " ([\"--compiler-window\", window, self, "
      <> show compiler <> ", " <> show root <> "] ++ args) >>= exitWith" ]

standaloneBridgeLines :: FilePath -> FilePath -> FilePath -> [String]
standaloneBridgeLines helper compiler root =
  [ "module Main (main) where"
  , "import System.Environment (getArgs)"
  , "import System.Exit (exitWith)"
  , "import System.Process (rawSystem)"
  , "main :: IO ()"
  , "main = do"
  , "  args <- getArgs"
  , "  rawSystem " <> show helper <> " (" <> show ["--compiler", compiler, root] <> " ++ args) >>= exitWith" ]

bootstrapArguments :: Bool -> FilePath -> FilePath -> FilePath -> [String]
bootstrapArguments cabalProfile directory source output =
  ["--make", "-j1", "-fforce-recomp", "-v0", "-hide-all-packages", "-package", "base", "-package", "process"]
  <> (if cabalProfile then ["-package", "filepath"] else [])
  <> ["-outputdir", directory, source, "-o", output]

windowPath :: PrivatelyAcquiredWindow -> FilePath
windowPath (PrivatelyAcquiredWindow _ owner) = owner

windowBase :: PrivatelyAcquiredWindow -> FilePath
windowBase (PrivatelyAcquiredWindow base _) = base

acquireFreshWindow :: FilePath -> IO PrivatelyAcquiredWindow
acquireFreshWindow root = do
  physicalRoot <- canonicalizePath root
  guardDirectory physicalRoot
  let containers = [".build", "source-admission", "journal", "windows"]
  directory <- ensureContainers physicalRoot containers
  (ticket, handle) <- openTempFile directory "window-"
  hClose handle
  let owner = ticket <> ".d"
  validateAbsolute owner
  requireMissing owner
  createDirectory owner
  guardDirectory owner
  guardRegular ticket
  removeFile ticket
  let window = PrivatelyAcquiredWindow physicalRoot owner
  createOwnedDirectory window (owner </> "calls")
  pure window

ensureContainers :: FilePath -> [FilePath] -> IO FilePath
ensureContainers current [] = guardDirectory current >> pure current
ensureContainers current (name : remaining) = do
  guardDirectory current
  let next = current </> name
  missing <- entryMissing next
  when missing (createDirectory next)
  guardDirectory next
  ensureContainers next remaining

createOwnedDirectory :: PrivatelyAcquiredWindow -> FilePath -> IO ()
createOwnedDirectory window path = do
  guardOwnedParent window path
  requireMissing path
  createDirectory path
  guardDirectory path

-- Checking an existing physical window acquires only a private bookkeeping
-- handle. Its unsealed contents do not attest actual bridge/native execution.
acquireExistingCabalWindow :: FilePath -> FilePath -> FilePath -> FilePath
  -> IO PrivatelyAcquiredWindow
acquireExistingCabalWindow root owner bridge compiler = do
  physicalRoot <- canonicalizePath root
  guardDirectory physicalRoot
  validateAbsolute owner
  let windows = physicalRoot </> ".build/source-admission/journal/windows"
  guardChain physicalRoot windows
  unless (equalFilePath (takeDirectory owner) windows && ".d" `isSuffixOf` takeFileName owner)
    (setupRefusal "received window is outside the fixed journal parent")
  guardDirectory owner
  let window = PrivatelyAcquiredWindow physicalRoot owner
      expectedBridge = owner </> "compiler/ghc.exe"
      expectedSource = owner </> "bootstrap/compiler-transport/Main.hs"
      expectedOutput = owner </> "bootstrap/ghc.exe"
  validateAbsolute bridge
  unless (equalFilePath bridge expectedBridge)
    (setupRefusal "received bridge is not the fixed compiler/ghc.exe copy")
  input <- readCanonicalOwned window (owner </> "window-input.data") :: IO WindowInput
  helper <- getExecutablePath
  unless (windowProfile input == CabalWindow
      && freshPhysicalWindowRoot input == owner
      && checkedRepositoryRoot input == root
      && preparedNativeCompilerPath input == Returned compiler
      && requestedHelper input == helper
      && bridgeTemplate input == Just CabalWindowLocatedBridge
      && bootstrapOutputPath input == Just expectedOutput
      && callableBridgeCopyPath input == Just expectedBridge
      && standaloneRequestedWrapperOutput input == Nothing
      && inheritedModes input == existingModes)
    (setupRefusal "received window/input controls disagree")
  actualSource <- readOwnedRegular window expectedSource
  unless (bootstrapBridgeSource input == Just (SourceReference expectedSource (Returned actualSource)))
    (setupRefusal "actual bridge source differs from opening source readback")
  ready <- readCanonicalOwned window (owner </> "window-ready.data") :: IO WindowReady
  (outputBytes, outputReference) <- readImage window expectedOutput
  (copyBytes, copyReference) <- readImage window expectedBridge
  same <- evaluate (outputBytes == copyBytes)
  unless (same && readyWindowRoot ready == owner
      && actualBootstrapOutput ready == outputReference
      && actualCallableBridgeCopy ready == copyReference
      && forcedCompleteImageCopyEquality ready == Returned True
      && readySourceAdmission ready == admittedSources input)
    (setupRefusal "actual bridge images differ from completed setup")
  pure window

recordCompiler :: PrivatelyAcquiredWindow -> CompilerSite -> SourceAdmission
  -> FilePath -> FilePath -> Maybe FilePath -> [String] -> [String]
  -> IO (Either IOException ExitCode)
recordCompiler window site admission compiler root bridge received effective = do
  cwd <- attemptIO "getCurrentDirectory before compiler begin" getCurrentDirectory
  call <- reserveCall window site admission compiler root bridge received effective cwd
  -- No gate is held here. Preserve rawSystem and all its inherited modes.
  result <- tryIO (rawSystem compiler effective)
  let terminal = either (ActualRawSystemThrewIOException . failureView "rawSystem compiler")
        ActualRawSystemReturned result
  retained <- tryIO (retainReturn call terminal)
  case retained of
    Right () -> pure ()
    Left logger -> void (tryIO (retainLoggerFailure call
      (RetentionFailure ReturnedRecordWriteOrClose (failureView "compiler return retention" logger))))
  pure result

reserveCall :: PrivatelyAcquiredWindow -> CompilerSite -> SourceAdmission
  -> FilePath -> FilePath -> Maybe FilePath -> [String] -> [String]
  -> Attempt FilePath -> IO OwnedCall
reserveCall window site admission compiler root bridge received effective cwd = do
  gate <- acquireGate window
  reserved <- tryIO $ do
    requireMissing (windowPath window </> "window-close.data")
    numbers <- currentCallNumbers window
    let ordinal :: Natural
        ordinal = foldl' (\count _ -> count + 1) 0 numbers
        directory = windowPath window </> "calls" </> ("call-" <> show ordinal)
        request = CompilerRequest site (windowPath window) ordinal compiler root admission
          bridge received effective cwd existingModes
    createOwnedDirectory window directory
    writeFreshShown window (directory </> "begin.data") (CompilerCallBegin request)
    pure (OwnedCall window directory request)
  finishGate gate reserved

currentCallNumbers :: PrivatelyAcquiredWindow -> IO [Natural]
currentCallNumbers window = do
  let directory = windowPath window </> "calls"
  guardOwnedDirectory window directory
  names <- listDirectory directory
  numbers <- forM names $ \name -> do
    ordinal <- maybe (setupRefusal "noncanonical call directory name") pure (callNumber name)
    guardOwnedDirectory window (directory </> name)
    pure ordinal
  let ordered = sort numbers
  unless (all (uncurry (==)) (zip ordered [0 ..]))
    (setupRefusal "call directory ordinals are not contiguous from zero")
  pure ordered

callNumber :: FilePath -> Maybe Natural
callNumber name = do
  digits <- stripPrefix "call-" name
  value <- readMaybe digits
  if show value == digits then Just value else Nothing

retainReturn :: OwnedCall -> RawCompilerReturn -> IO ()
retainReturn (OwnedCall window directory request) terminal = do
  gate <- acquireGate window
  retained <- tryIO $ do
    begin <- readCanonicalOwned window (directory </> "begin.data") :: IO CompilerCallBegin
    unless (beginRequest begin == request) (setupRefusal "own begin changed before return retention")
    writeFreshShown window (directory </> "return.data") (CompilerCallReturn request terminal)
  finishGate gate retained

retainLoggerFailure :: OwnedCall -> RetentionFailure -> IO ()
retainLoggerFailure (OwnedCall window directory _) failure = do
  gate <- acquireGate window
  retained <- tryIO (writeFreshShown window (directory </> "retention-failure.data") failure)
  finishGate gate retained

acquireGate :: PrivatelyAcquiredWindow -> IO PrivatelyHeldStateGate
acquireGate window = do
  let path = windowPath window </> "state.gate"
  guardOwnedParent window path
  requireMissing path
  createDirectory path
  guardDirectory path
  contents <- listDirectory path
  unless (null contents) (setupRefusal "newly acquired state gate is not empty")
  pure (PrivatelyHeldStateGate path)

releaseGate :: PrivatelyHeldStateGate -> IO ()
releaseGate (PrivatelyHeldStateGate path) = do
  guardDirectory path
  contents <- listDirectory path
  unless (null contents) (setupRefusal "held state gate changed")
  removeDirectory path

finishGate :: PrivatelyHeldStateGate -> Either IOException value -> IO value
finishGate gate performed = case performed of
  Left original -> void (tryIO (releaseGate gate)) >> throwIO original
  Right value -> releaseGate gate >> pure value

bestEffortClose :: PrivatelyAcquiredWindow -> Attempt AggregateReturn -> IO ()
bestEffortClose window aggregate = void (tryIO (closeWindow window aggregate))

closeWindow :: PrivatelyAcquiredWindow -> Attempt AggregateReturn -> IO ()
closeWindow window aggregate = do
  gate <- acquireGate window
  closed <- tryIO $ do
    let owner = windowPath window
        calls = owner </> "calls"
    requireMissing (owner </> "window-close.data")
    guardOwnedDirectory window calls
    actualNames <- listDirectory calls
    let numbered = sortOn fst [(number, name) | name <- actualNames, Just number <- [callNumber name]]
        unnumbered = sort [name | name <- actualNames, callNumber name == Nothing]
        names = map snd numbered <> unnumbered
    records <- forM numbered $ \(number, name) -> do
      let directory = calls </> name
      begin <- attemptIO "read call begin during closing" (readOwnedRegular window (directory </> "begin.data"))
      returned <- attemptIO "read call return during closing" (readOwnedRegular window (directory </> "return.data"))
      let failurePath = directory </> "retention-failure.data"
      missing <- tryIO $ do
        guardOwnedParent window failurePath
        entryMissing failurePath
      failure <- case missing of
        Left original -> pure (ThrewActualIOException (failureView "inspect optional retention failure during closing" original))
        Right True -> pure (NotAttempted "optional retention failure file absent")
        Right False -> attemptIO "read optional retention failure during closing" (readOwnedRegular window failurePath)
      pure (CallFiles number directory begin returned failure)
    entries <- allOwnedEntries window owner
    let other = filter (not . expectedWindowEntry) entries
        result = WindowClose owner aggregate (map (calls </>) names) records other
    writeFreshShown window (owner </> "window-close.data") result
  finishGate gate closed

expectedWindowEntry :: FilePath -> Bool
expectedWindowEntry path
  | path `elem` ["calls", "state.gate", "bootstrap", "compiler"] = True
  | any (\(FixedFile name _) -> path == name) fixedWindowFiles = True
  | startsWithDirectory "bootstrap" path || startsWithDirectory "compiler" path = True
  | otherwise = case splitDirectories path of
      ["calls", name] -> maybe False (const True) (callNumber name)
      ["calls", name, file] -> maybe False (const (file `elem` map fixedName fixedCallFiles)) (callNumber name)
      _ -> False
 where
  fixedName (FixedFile name _) = name

startsWithDirectory :: FilePath -> FilePath -> Bool
startsWithDirectory directory path = case splitDirectories path of
  first : _ : _ -> first == directory
  _ -> False

allOwnedEntries :: PrivatelyAcquiredWindow -> FilePath -> IO [FilePath]
allOwnedEntries window directory = do
  guardOwnedDirectory window directory
  names <- sort <$> listDirectory directory
  fmap concat $ forM names $ \name -> do
    let path = directory </> name
        relative = makeRelative (windowPath window) path
    validateAbsolute path
    linked <- pathIsSymbolicLink path
    status <- Files.getSymbolicLinkStatus path
    unless (not linked && not (Files.isSymbolicLink status)
        && (Files.isDirectory status || Files.isRegularFile status))
      (setupRefusal "closing inventory contains a link or unsupported physical kind")
    if Files.isDirectory status
      then (relative :) <$> allOwnedEntries window path
      else pure [relative]

writeFreshShown :: Show value => PrivatelyAcquiredWindow -> FilePath -> value -> IO ()
writeFreshShown window path value = do
  let bytes = Encoding.encodeUtf8 (Text.pack (show value <> "\n"))
  void (evaluate (Bytes.length bytes))
  writeFreshBytes window path bytes

writeFreshBytes :: PrivatelyAcquiredWindow -> FilePath -> ByteString -> IO ()
writeFreshBytes window path bytes = do
  void (evaluate (Bytes.length bytes))
  guardOwnedParent window path
  requireMissing path
  withBinaryFile path WriteMode (\handle -> Bytes.hPut handle bytes)
  guardRegular path

readOwnedRegular :: PrivatelyAcquiredWindow -> FilePath -> IO ByteString
readOwnedRegular window path = do
  guardOwnedParent window path
  guardRegular path
  bytes <- Bytes.readFile path
  void (evaluate (Bytes.length bytes))
  pure bytes

readCanonicalOwned :: forall value. (Read value, Show value)
  => PrivatelyAcquiredWindow -> FilePath -> IO value
readCanonicalOwned window path = do
  bytes <- readOwnedRegular window path
  text <- either (setupRefusal . ("record is not strict UTF8: " <>) . show) pure (Encoding.decodeUtf8' bytes)
  value <- maybe (setupRefusal "record is not one declared Read value") pure
    (readMaybe (Text.unpack text) :: Maybe value)
  let canonical = Encoding.encodeUtf8 (Text.pack (show value <> "\n"))
  unless (canonical == bytes) (setupRefusal "record does not roundtrip exact Show UTF8 plus one LF")
  pure value

readImage :: PrivatelyAcquiredWindow -> FilePath -> IO (ByteString, ImageReference)
readImage window path = do
  bytes <- readOwnedRegular window path
  resolved <- canonicalizePath path
  pure (bytes, ImageReference path (Returned resolved) (Returned (measureImage bytes)))

measureImage :: ByteString -> ImageMeasure
measureImage bytes = ImageMeasure (fromIntegral (Bytes.length bytes))
  (Text.pack (concatMap hexByte (Bytes.unpack (SHA256.hash bytes))))
 where
  hexByte byte = case showHex byte "" of
    [digit] -> ['0', digit]
    digits -> digits

-- Only journal/bridge paths use these guards. The external requested compiler
-- retains the old raw spelling and native tool admission behavior.
validateAbsolute :: FilePath -> IO ()
validateAbsolute path = unless (isAbsolute path && '\0' `notElem` path
    && Text.unpack (Text.pack path) == path)
  (setupRefusal "journal path is not absolute, NUL-free and lossless")

guardOwnedParent :: PrivatelyAcquiredWindow -> FilePath -> IO ()
guardOwnedParent window path = do
  validateAbsolute path
  let owner = windowPath window
      relative = makeRelative owner path
  unless (not (isAbsolute relative) && ".." `notElem` splitDirectories relative
      && not (equalFilePath owner path))
    (setupRefusal "journal path is outside its acquired window")
  guardChain (windowBase window) owner
  guardChain owner (takeDirectory path)

guardOwnedDirectory :: PrivatelyAcquiredWindow -> FilePath -> IO ()
guardOwnedDirectory window path
  | equalFilePath path (windowPath window) = guardChain (windowBase window) path
  | otherwise = guardOwnedParent window path >> guardDirectory path

guardChain :: FilePath -> FilePath -> IO ()
guardChain base target = do
  validateAbsolute base
  validateAbsolute target
  let relative = makeRelative base target
      pieces = filter (/= ".") (splitDirectories relative)
  unless (not (isAbsolute relative) && ".." `notElem` pieces)
    (setupRefusal "physical directory chain escapes its base")
  guardDirectory base
  walk base pieces
 where
  walk :: FilePath -> [FilePath] -> IO ()
  walk _ [] = pure ()
  walk current (piece : remaining) = do
    let next = current </> piece
    guardDirectory next
    walk next remaining

guardDirectory :: FilePath -> IO ()
guardDirectory path = do
  validateAbsolute path
  linked <- pathIsSymbolicLink path
  status <- Files.getSymbolicLinkStatus path
  unless (not linked && not (Files.isSymbolicLink status) && Files.isDirectory status)
    (setupRefusal "journal parent is not a physical nonlink directory")
  actual <- canonicalizePath path
  unless (equalFilePath actual (normalise path))
    (setupRefusal "journal directory does not retain its physical path")

guardRegular :: FilePath -> IO ()
guardRegular path = do
  validateAbsolute path
  linked <- pathIsSymbolicLink path
  status <- Files.getSymbolicLinkStatus path
  unless (not linked && not (Files.isSymbolicLink status) && Files.isRegularFile status)
    (setupRefusal "journal entry is not a physical nonlink regular file")

entryMissing :: FilePath -> IO Bool
entryMissing path = do
  validateAbsolute path
  link <- tryIO (pathIsSymbolicLink path)
  case link of
    Right _ -> pure False
    Left original
      | isDoesNotExistError original -> do
          status <- tryIO (Files.getSymbolicLinkStatus path)
          case status of
            Left absent | isDoesNotExistError absent -> pure True
            Left failure -> throwIO failure
            Right _ -> pure False
      | otherwise -> throwIO original

requireMissing :: FilePath -> IO ()
requireMissing path = do
  missing <- entryMissing path
  unless missing (setupRefusal "fresh journal name already exists or is a dangling link")

failureView :: String -> IOException -> IOFailureView
failureView operation original = IOFailureView (show original) operation
  (GHC.ioe_location original) (GHC.ioe_filename original) (show (GHC.ioe_type original))
  (toInteger <$> GHC.ioe_errno original)

attemptIO :: String -> IO value -> IO (Attempt value)
attemptIO operation action = either (ThrewActualIOException . failureView operation) Returned <$> tryIO action

tryIO :: IO value -> IO (Either IOException value)
tryIO = try

restoreRaw :: Either IOException ExitCode -> IO ExitCode
restoreRaw = either throwIO pure

setupRefusal :: String -> IO value
setupRefusal reason = fail ("compiler journal setup refused: " <> reason)
