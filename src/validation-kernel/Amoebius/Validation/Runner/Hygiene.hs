{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PackageImports #-}
-- | Tree-derived kernel shape and vocabulary checks (AGENTS.md "Kernel Budget").
module Amoebius.Validation.Runner.Hygiene
  ( HygieneReport (..), CapturedSource, captureSource, capturedSourceDigest, capturedSourceFiles, capturedSourceBytes
  , capturedSourceRuns, parseSourceInventory, docCheckRoot, hygieneGreen, hygieneProblems, hygieneRow, kernelBudget
  , kernelRoots, isRunModule, phaseLiteral, haskellFilesUnder, materializeSource, verifySourceCopy
  , rewriteCapturedSource, runRootWithinFrame, renderHygiene, vocabularyTypes, TreePurpose (..), TreeNode (..), classifyTreeNode, walkFilesUnder, walkFilesUnderWith, sourceAttempt, readSourceBytes, readSourceText ) where
import Amoebius.Plan.ValidationRecordPath (isValidationRecordPath)
import "amoebius" Amoebius.Validation.BootstrapPredicate (bootstrapInputPathAllowed)
import Amoebius.Validation.GateSpec (showText)
import Amoebius.Validation.Runner.Observer (ObservedRun, observe, runExit, runStdout, sha256Bytes, sha256Hex)
import Control.Exception (IOException, bracket, catch, try)
import Control.Monad (forM, forM_, unless)
import Data.ByteString qualified as Bytes
import Data.Char (isDigit)
import Data.List (intercalate, isSuffixOf, nub, sort)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.IORef (newIORef, atomicModifyIORef')
import Data.Streaming.Filesystem (FileType (..), closeDirStream, getFileType, openDirStream, readDirStream)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import System.Directory (canonicalizePath, createDirectory, createDirectoryIfMissing, doesPathExist, executable, findExecutable, getPermissions, makeAbsolute, pathIsSymbolicLink, setPermissions)
import System.Exit (ExitCode (..))
import System.IO (IOMode (ReadMode), withBinaryFile, hFileSize, hIsEOF)
import System.IO.Error (ioeGetErrorString, isDoesNotExistError)
import System.Timeout (timeout)
import System.FilePath (equalFilePath, isAbsolute, makeRelative, normalise, splitDirectories, takeBaseName, takeDirectory, takeFileName, (</>))
import System.FilePath.Windows qualified as Windows
kernelBudget :: Int
kernelBudget = 14000
-- | Runner, custody and gate-specification roots covered by the kernel budget.
kernelRoots :: [FilePath]
kernelRoots = ["src/validation-kernel", "src/gate-spec"]
docCheckRoot :: FilePath
docCheckRoot = "src/doc-check"
-- Private source custody; rewrites retain bytes and grant no qualification verdict.
runRootWithinFrame :: FilePath -> FilePath -> IO Bool
runRootWithinFrame root path = (\base absolute physical -> equalFilePath absolute physical && bootstrapInputPathAllowed (intercalate "/" (splitDirectories (makeRelative base absolute)))) <$> canonicalizePath root <*> makeAbsolute path <*> canonicalizePath path
data CapturedSource = CapturedSource Text [(FilePath, Maybe (Bool, Bytes.ByteString))] [ObservedRun]
capturedSourceDigest :: CapturedSource -> Text
capturedSourceDigest (CapturedSource digest _ _) = digest
capturedSourceFiles :: CapturedSource -> [FilePath]
capturedSourceFiles (CapturedSource _ entries _) = map fst entries
capturedSourceBytes :: CapturedSource -> FilePath -> Maybe Bytes.ByteString
capturedSourceBytes (CapturedSource _ entries _) file = lookup file entries >>= fmap snd
capturedSourceRuns :: CapturedSource -> [ObservedRun]
capturedSourceRuns (CapturedSource _ _ runs) = runs
sourceSnapshot :: [(FilePath, Maybe (Bool, Bytes.ByteString))] -> [ObservedRun] -> CapturedSource
sourceSnapshot entries runs = CapturedSource (sha256Hex (Text.pack (show [(file, fmap (\(mode, bytes) -> (mode, sha256Bytes bytes)) value) | (file, value) <- entries]))) entries runs
rewriteCapturedSource :: CapturedSource -> FilePath -> Bytes.ByteString -> Either Text CapturedSource
rewriteCapturedSource (CapturedSource _ entries runs) path bytes = case lookup path entries of
  Just (Just (mode, before)) | before /= bytes -> Right (sourceSnapshot [(file, if file == path then Just (mode, bytes) else value) | (file, value) <- entries] runs)
  Just (Just _) -> Left "SourceRewriteUnchanged"
  _ -> Left "SourceRewriteMissing"
parseSourceInventory :: Text -> Either Text [FilePath]
parseSourceInventory output
  | Text.null output = Left "SourceInventoryEmpty"
  | not ("\0" `Text.isSuffixOf` output) = Left "SourceInventoryMalformed"
  | any (\p -> null p || isAbsolute p || Windows.hasDrive p || not (Windows.isValid p) || '\\' `elem` p || any (`elem` [".", "..", "/"]) (splitDirectories p)) files = Left "SourceInventoryPath"
  | length files /= length (nub files) = Left "SourceInventoryDuplicate"
  | otherwise = Right (sort files)
 where files = map Text.unpack (init (Text.splitOn "\0" output))
captureSource :: FilePath -> IO (Either Text CapturedSource)
captureSource root = maybe (Left "SourceCaptureTimeout") id <$> timeout 60000000 (sourceAttempt acquire)
 where
  acquire = do
    absolute <- canonicalizePath root
    executablePath <- findExecutable "git" >>= maybe (fail "SourceGitUnavailable") pure
    let git args = do
          run <- observe absolute executablePath (["-c", "safe.directory=" <> absolute] <> args)
          unless (runExit run == ExitSuccess) (fail "SourceGitUnavailable")
          pure run
    topRun <- git ["rev-parse", "--show-toplevel"]
    let top = runStdout topRun
    unless (length (Text.lines top) == 1 && not (Text.null (Text.strip top))) (fail "SourceRootMismatch")
    observedRoot <- canonicalizePath (Text.unpack (Text.strip top))
    unless (equalFilePath observedRoot absolute) (fail "SourceRootMismatch")
    pathsRun <- git ["ls-files", "-z", "--cached", "--others", "--exclude-per-directory=.gitignore"]
    paths <- either (fail . Text.unpack) pure (parseSourceInventory (runStdout pathsRun))
    removedRun <- git ["ls-files", "-z", "--deleted"]
    let removed = runStdout removedRun
    deleted <- if Text.null removed then pure [] else either (fail . Text.unpack) pure (parseSourceInventory removed)
    unless (all (`elem` paths) deleted) (fail "SourceInventoryMismatch")
    entries <- forM (filter (not . isValidationRecordPath) paths) $ \file -> do
      value <- readSourceInput absolute file (file `elem` deleted)
      pure (file, value)
    unless (not (null entries)) (fail "SourceInventoryEmpty")
    pure (sourceSnapshot entries [topRun, pathsRun, removedRun])
readSourceInput :: FilePath -> FilePath -> Bool -> IO (Maybe (Bool, Bytes.ByteString))
readSourceInput root file deleted = do
  attempted <- try $ do
    let path = normalise (root </> file)
    link <- pathIsSymbolicLink path
    resolved <- canonicalizePath path
    unless (not link && equalFilePath resolved path) (fail "SourceSymlink")
    mode <- executable <$> getPermissions path
    bytes <- readSourceBytes path
    pure (mode, bytes)
  case attempted of
    Right value -> pure (Just value)
    Left problem | isDoesNotExistError problem && deleted -> pure Nothing
                 | otherwise -> fail ("SourceInputUnavailable:" <> file <> ":" <> ioeGetErrorString problem)
-- Copies are written only from retained bytes; no live source path is reopened.
materializeSource :: CapturedSource -> FilePath -> IO (Either Text FilePath)
materializeSource (CapturedSource _ entries _) destination = sourceAttempt $ do
  root <- makeAbsolute destination
  parent <- canonicalizePath (takeDirectory root)
  unless (equalFilePath parent (takeDirectory root)) (fail "SourceCopyParentSymlink")
  exists <- doesPathExist root
  unless (not exists) (fail "SourceCopyNotFresh")
  createDirectoryIfMissing True parent
  createDirectory root
  forM_ [(file, value) | (file, Just value) <- entries] $ \(file, (mode, bytes)) -> do
    let path = root </> file
    createDirectoryIfMissing True (takeDirectory path)
    Bytes.writeFile path bytes
    permissions <- getPermissions path
    setPermissions path permissions {executable = mode}
  pure root
-- Generated state is allowed; every captured input, including .build, remains checked.
verifySourceCopy :: CapturedSource -> FilePath -> IO (Either Text ())
verifySourceCopy (CapturedSource _ entries _) root = sourceAttempt $ do
  names <- walkFilesUnder root VerifyCopy ""
  unless (sort names == sort [file | (file, Just _) <- entries, take 1 (splitDirectories file) /= [".build"]]) (fail "SourceCopyInventoryChanged")
  forM_ entries $ \(file, expected) -> do
    actual <- readSourceInput root file (expected == Nothing)
    unless (actual == expected) (fail ("SourceCopyInputChanged:" <> file))
sourceAttempt :: IO value -> IO (Either Text value)
sourceAttempt operation = (Right <$> operation) `catch` (\problem -> pure (Left (Text.pack (ioeGetErrorString (problem :: IOException)))))
readSourceBytes :: FilePath -> IO Bytes.ByteString
readSourceBytes path = do
  ((,) <$> getFileType path <*> pathIsSymbolicLink path) >>= \(kind, linked) -> unless (classifyTreeNode linked True kind == TreeFile) (fail "SourceNotRegular")
  withBinaryFile path ReadMode $ \stream -> do
    bytes <- hFileSize stream >>= Bytes.hGet stream . fromInteger . min (16 * 1024 * 1024 + 1) . (+ 1)
    hIsEOF stream >>= \ended -> if Bytes.length bytes > 16 * 1024 * 1024 then fail "SourceByteLimit" else if not ended then fail "SourceReadChanged" else pure bytes
readSourceText :: FilePath -> IO Text
readSourceText path = readSourceBytes path >>= either (const (fail "SourceTextUtf8")) pure . TextEncoding.decodeUtf8'
-- | The vocabulary axes that must have exactly one definition anywhere under src/.
vocabularyTypes :: [Text]
vocabularyTypes = ["Substrate", "Architecture", "Detected", "Lane", "ComputeEngine", "EngineRuntime", "InferenceFamily", "CapabilityArm", "ExtensionId", "Quantity", "ResourceVector", "Register"]
data HygieneReport = HygieneReport
  { hygieneKernelLines :: Int, hygieneKernelCap :: Int, hygieneDocCheckLines :: Int, hygieneDocCheckCap :: Int
  , hygieneConditionalCompilation :: [(FilePath, Int)], hygieneRunModules :: [FilePath]
  , hygienePhaseLiterals :: [(FilePath, Int, Text)], hygienePhaseTables :: [FilePath]
  , hygieneDuplicateVocabulary :: [(Text, [FilePath])], hygieneProductDuplicateVocabulary :: [(Text, [FilePath])]
  } deriving (Eq, Show)
-- | Compute hygiene at the smaller of the fixed and last accepted kernel budgets.
hygieneRow :: FilePath -> Maybe Int -> Int -> IO HygieneReport
hygieneRow root lastAccepted docCheckCap = do
  let readSources roots = concat <$> mapM (\directory -> haskellFilesUnder root directory >>= mapM
        (\file -> (,) file . Text.lines <$> readSourceText (root </> file))) roots
      lineCount = sum . map (length . snd)
      duplicates sources = [(name, sort files) | (name, files) <- Map.toList (Map.fromListWith (<>)
        [(name, [file]) | (file, lines') <- sources, line <- lines', Just name <- [definedType line], name `elem` vocabularyTypes]), length files > 1]
  kernel <- readSources kernelRoots
  docs <- readSources [docCheckRoot]
  productSources <- readSources ["src"]
  let numbered = [(file, number, line) | (file, lines') <- kernel, (number, line) <- zip [1 ..] lines']
  pure HygieneReport
    { hygieneKernelLines = lineCount kernel, hygieneKernelCap = maybe kernelBudget (min kernelBudget) lastAccepted
    , hygieneDocCheckLines = lineCount docs, hygieneDocCheckCap = docCheckCap
    , hygieneConditionalCompilation = [(file, number) | (file, number, line) <- numbered, "#" `Text.isPrefixOf` line]
    , hygieneRunModules = [file | (file, _) <- kernel, isRunModule file]
    , hygienePhaseLiterals = [(file, number, Text.strip line) | (file, number, line) <- numbered, phaseLiteral line]
    , hygienePhaseTables = [file | (file, lines') <- kernel, any phaseTableDefinition lines']
    , hygieneDuplicateVocabulary = duplicates kernel, hygieneProductDuplicateVocabulary = duplicates productSources }
-- | A path segment ending in @Run@; the generic @Runner@ is excluded.
isRunModule :: FilePath -> Bool
isRunModule file = any (\base -> "Run" `isSuffixOf` base && base /= "Run")
  (map takeBaseName (splitDirectories file))
-- | A phase ordinal spelled into kernel source: @phase-NN@, @PhaseNN@, @phase NN@.
phaseLiteral :: Text -> Bool
phaseLiteral line =
  any (\needle -> any (digitAfter needle) (Text.breakOnAll needle line)) ["phase-", "Phase-", "phase_", "Phase ", "phase "]
 where
  digitAfter needle (_, rest) =
    let after = Text.drop (Text.length needle) rest
     in not (Text.null after) && isDigit (Text.head after) && not ("--" `Text.isPrefixOf` Text.stripStart line)
phaseTableDefinition :: Text -> Bool
phaseTableDefinition line =
  any (`Text.isPrefixOf` line) ["canonicalPhaseIdentities ::", "phaseMetadata ::", "canonicalPhaseRegistry ::", "canonicalPhasePaths ::"]
definedType :: Text -> Maybe Text
definedType line =
  case Text.words line of
    ("data" : name : _) -> Just (Text.takeWhile (/= '(') name)
    ("newtype" : name : _) -> Just name
    _ -> Nothing
hygieneProblems :: HygieneReport -> [Text]
hygieneProblems report =
  [ name <> "OverBudget: " <> showText count <> " lines against a cap of " <> showText cap
  | (name, count, cap) <- [("Kernel", hygieneKernelLines report, hygieneKernelCap report), ("DocCheck", hygieneDocCheckLines report, hygieneDocCheckCap report)]
  , count > cap
  ]
    <> ["ConditionalCompilation: " <> showText (length (hygieneConditionalCompilation report)) <> " lines" | not (null (hygieneConditionalCompilation report))]
    <> ["RunModules: " <> Text.intercalate "," (map Text.pack (take 5 (hygieneRunModules report))) | not (null (hygieneRunModules report))]
    <> ["PhaseLiterals: " <> showText (length (hygienePhaseLiterals report)) | not (null (hygienePhaseLiterals report))]
    <> ["PhaseTables: " <> Text.intercalate "," (map Text.pack (hygienePhaseTables report)) | length (hygienePhaseTables report) > 1]
    <> ["DuplicateVocabulary: " <> Text.intercalate "," (map fst (hygieneProductDuplicateVocabulary report)) | not (null (hygieneProductDuplicateVocabulary report))]
hygieneGreen :: HygieneReport -> Bool
hygieneGreen = null . hygieneProblems
renderHygiene :: HygieneReport -> [(Text, Text)]
renderHygiene report =
  [ ("hygiene.kernel-lines", showText (hygieneKernelLines report))
  , ("hygiene.kernel-cap", showText (hygieneKernelCap report))
  , ("hygiene.doc-check-lines", showText (hygieneDocCheckLines report))
  , ("hygiene.doc-check-cap", showText (hygieneDocCheckCap report))
  , ("hygiene.conditional-compilation-lines", showText (length (hygieneConditionalCompilation report)))
  , ("hygiene.run-modules", showText (length (hygieneRunModules report)))
  , ("hygiene.phase-literals", showText (length (hygienePhaseLiterals report)))
  , ("hygiene.phase-tables", showText (length (hygienePhaseTables report)))
  , ("hygiene.duplicate-vocabulary", showText (length (hygieneDuplicateVocabulary report)))
  , ("hygiene.product-duplicate-vocabulary", Text.intercalate "," (map fst (hygieneProductDuplicateVocabulary report)))
  , ("hygiene.verdict", if hygieneGreen report then "green" else Text.intercalate "; " (hygieneProblems report))
  ]
haskellFilesUnder :: FilePath -> FilePath -> IO [FilePath]
haskellFilesUnder root relative = filter (".hs" `isSuffixOf`) <$> walkFilesUnder root ScanSources relative
data TreePurpose = ScanSources | VerifyCopy | AuditArchive deriving (Eq, Show)
data TreeNode = TreeFile | TreeDirectory | TreeMissing | TreeUnsafe deriving (Eq, Show)
classifyTreeNode :: Bool -> Bool -> FileType -> TreeNode
classifyTreeNode linked contained kind = if linked || not contained then TreeUnsafe else case kind of FTFile -> TreeFile; FTDirectory -> TreeDirectory; _ -> TreeUnsafe
walkFilesUnder :: FilePath -> TreePurpose -> FilePath -> IO [FilePath]
walkFilesUnder root purpose relative = do
  absolute <- canonicalizePath root
  let inspect path = (do
        let file = absolute </> path
        resolved <- canonicalizePath file
        linked <- pathIsSymbolicLink file
        kind <- getFileType file
        pure (classifyTreeNode linked (equalFilePath resolved file) kind))
        `catch` (\problem -> if isDoesNotExistError problem then pure TreeMissing else ioError problem)
  walkFilesUnderWith inspect (\path action -> bracket (openDirStream (absolute </> path)) closeDirStream (action . readDirStream)) purpose relative
walkFilesUnderWith :: (FilePath -> IO TreeNode) -> (forall a. FilePath -> (IO (Maybe FilePath) -> IO a) -> IO a) -> TreePurpose -> FilePath -> IO [FilePath]
walkFilesUnderWith inspect entries purpose relative = do
  unless (null relative || parseSourceInventory (Text.pack relative <> "\0") == Right [relative]) (fail "SourceTreePath")
  budget <- newIORef (100000 :: Int)
  let walk depth path = do
        unless (depth <= 128) (fail ("SourceTreeDepth:" <> path))
        kind <- inspect path
        case kind of
          TreeMissing | purpose == ScanSources && path == relative -> pure []
          TreeDirectory | purpose == VerifyCopy && path == ".build" -> pure []
                        | otherwise -> entries path $ \next -> let
              consume seen = next >>= \entry -> case entry of
                Nothing -> if purpose == AuditArchive && Set.null seen && path /= relative then fail ("SourceTreeEmpty:" <> path) else pure []
                Just name -> do
                  remaining <- atomicModifyIORef' budget (\n -> (n - 1, n))
                  unless (remaining > 0) (fail "SourceTreeEntries")
                  unless (Set.notMember name seen && takeFileName name == name && parseSourceInventory (Text.pack name <> "\0") == Right [name]) (fail "SourceTreeEntry")
                  found <- walk (depth + 1) (if null path then name else path <> "/" <> name)
                  (found <>) <$> consume (Set.insert name seen)
              in consume Set.empty
          TreeFile | path /= relative && (purpose /= VerifyCopy || path /= ".build") -> pure [path]
          _ -> fail ("SourceTreeUnsafe:" <> path)
  sort <$> walk (length (splitDirectories relative)) relative
