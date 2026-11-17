{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PackageImports #-}
-- | Shared generic runner and retained custody implementation.
-- Public runner and custody modules expose only their intended API subsets.
module Amoebius.Validation.Authority.Core
( SeedCase (..), SeedAttempt (..), SeedOutcome (..), SeedProtocol (..), defaultSeedProtocol, renderSeedOutcome, runSeedProtocol, runCapturedSeedProtocol, seedCases , seedGreen, attemptRuns, seedInterrupted   , closureDigest , CommandOutcome (..), CustodyConfig (..), defaultCustodyConfig, acceptPhase, demoFile, previewPhase, replayThrough, receiptPublicationBound, resetGeneration, runFresh, voidFromPhase, receiptCompatibility , StatusSurface (..), patchToFrontier, recordedFrontier, statusSurface, statusPrefixDigest, surfaceConsistent, surfaceDigest   , GenerationId, Receipt (..), SeedRecord (..), Store (..), archivedBundlePath, archivedKernelCap, auditArchivedInventory , digestShape, generationDirectory, governanceDigest, latestGeneration, latestWholePostimage, parseReceipt, parseSeed, readArchivedBundles, readArchivedBundlesWith, readCurrentArchivedBundles, readRecord, readSeed , renderReceipt, renderSeed, verifierDigest, writeArchivedReceipt, writeRecord, writeReplayVoid, writeSeed, rollbackOnLeft, withResult, withResults , GateOutcome (..), PassedGate, RunnerConfig (..), RunnerRefusal (..), compiledBlocks, defaultRunnerConfig, reproducibleCore, Ledger, parseLedger, ledgerGreen, ledgerDigest, suiteLedger, renderRefusal, roleFor, runGate, specDigest , BinaryOutcome (..), Nonce (..), SpineOutcome (..), freshNonce, perturbInput, runSpineFact, HygieneReport (..), CapturedSource, captureSource, capturedSourceDigest, capturedSourceFiles, capturedSourceBytes , capturedSourceRuns, parseSourceInventory, docCheckRoot, hygieneGreen, hygieneProblems, hygieneRow, kernelBudget, kernelRoots, isRunModule, phaseLiteral, haskellFilesUnder, materializeSource, verifySourceCopy , rewriteCapturedSource, runRootWithinFrame, renderHygiene, vocabularyTypes, TreePurpose (..), TreeNode (..), classifyTreeNode, walkFilesUnder, walkFilesUnderWith, sourceAttempt, readSourceBytes, readSourceText, LegacyFinding (..), LegacyObservation (..), LegacyReport (..) , legacyRequirementsAt, observeLegacy, observeLegacyMany, auditLegacyReports, renderLegacyReports, LegacyCollection, collectLegacy, inheritLegacyCollection, auditLegacyCollection, legacyCollectionRuns, legacyCollectionEvidence, legacyQualificationSupported , LegacyQualification, qualifyLegacy, qualifiedLegacyReports, auditQualifiedLegacyReports, runLegacyProbe, runAuthorityObservation, runSolverReintroductions, readImages, KillTable (..), Locus (..), MutantOutcome (..), Operator (..), SubjectChangeWitness (..), allOperators, applyLocus , renderMutantOutcome, enumerateLoci, isAttributed, truncateListLocus, killTable, renderKillTable, renderOperator, sampleLoci , ObservedRun (..), chainDigest, observe, observeNativeCabal, observedDigest, renderObserved, sha256Hex, ActualPreparedTuple, observeActualTuple, observeActualNativeCabal , NativeCabalRequest, prepareNativeCabalRequest, nativePlanWireTool, sha256Bytes, renderTsv, OracleTranscriptKind (..), inspectOracleTranscript , PackageGraph (..), SpecProblem (..), VerifiedSpec (..), executableClosure, libraryClosure, internalDependencies, loadPackageGraph, moduleSourcePath, parsePackageGraph, renderSpecProblem, verifySpec, verifySpecAgainst, verifyOracle, sourceTokens , sourceTree, sourceDirectives, resolveSpec, bindPhaseSpec, requiredSuiteRows) where
import Control.Monad (forM, unless, when, foldM, join, filterM, void, forM_, guard)
import Data.Either (isRight)
import Data.Maybe (listToMaybe, fromMaybe, isJust, isNothing, mapMaybe, catMaybes)
import Data.Text (Text)
import Data.Text qualified as Text
import System.Directory ( canonicalizePath, createDirectory, createDirectoryIfMissing, doesPathExist, exeExtension, findExecutable , makeAbsolute, removePathForcibly, doesFileExist, doesDirectoryExist, getFileSize, listDirectory , pathIsSymbolicLink, renameDirectory, renameFile, executable, getPermissions, setPermissions, findFile )
import System.Exit (ExitCode (..))
import System.FilePath ( (</>), equalFilePath, isAbsolute, makeRelative, splitDirectories, takeDirectory, takeFileName , normalise, takeBaseName, takeExtension, (<.>), dropExtension )
import Amoebius.Doc.Check (discoverDocuments, checkTree)
import Amoebius.Plan.PhaseIdentity qualified as PhaseIdentity
import Amoebius.Plan.StatusFrontier qualified as Status
import Amoebius.Validation.GateSpec
import Distribution.PackageDescription ( hsSourceDirs, BuildInfo (..), Executable (..), GenericPackageDescription (..), Library (..) , LibraryName (..), PackageFlag (..), TestSuite (..), TestSuiteInterface (..), BuildType (Simple) , buildType, setupBuildInfo )
import Distribution.Utils.Path (getSymbolicPath)
import Data.List (nub, sort, isSuffixOf, transpose, intercalate, sortOn, isPrefixOf)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Amoebius.Toolchain.Acquire qualified as Tools
import Amoebius.Plan.Decisions qualified as Decisions
import Amoebius.Plan.Legacy qualified as Legacy
import Amoebius.Validation.Custody.Preflight hiding (HardwareBeforeBarrier)
import Amoebius.Validation.GateSpec.Registry (registeredSpecInputs)
import Amoebius.Validation.Runner.Capture
import Control.Exception (Exception, IOException, try, finally, bracket, catch, throwIO, onException)
import Data.Text.IO qualified as TextIO
import Data.Time.Clock (getCurrentTime)
import Data.Char (isDigit, isAlphaNum, isUpper, toLower)
import Amoebius.Plan.ValidationRecordPath (isValidationRecordPath, validationRecordRoot)
import Data.ByteString qualified as ByteString
import Data.ByteString.Base64 qualified as Base64
import Data.ByteString.Lazy qualified as Lazy
import Codec.Compression.GZip qualified as GZip
import System.Environment (getExecutablePath)
import System.IO.Error (isDoesNotExistError, tryIOError, ioeGetErrorString)
import Amoebius.Doc.Render (Negative (..), negativeCatalogue, renderNegative, writeCorpus)
import Amoebius.Doc.Types (CheckResult (..), Finding (..), Observation (..))
import "amoebius" Amoebius.Validation.BootstrapPredicate (bootstrapSnapshotMatches, bootstrapInputPathAllowed)
import Data.Time.Clock.POSIX (getPOSIXTime)
import Data.IORef (IORef, newIORef, readIORef, writeIORef, atomicModifyIORef')
import Data.Streaming.Filesystem (FileType (..), closeDirStream, getFileType, openDirStream, readDirStream)
import System.IO (IOMode (ReadMode), withBinaryFile, hFileSize, hIsEOF, openTempFile, hClose)
import System.Timeout (timeout)
import System.FilePath.Windows qualified as Windows
import Amoebius.Layout.PbGrammar qualified as Pb
import Amoebius.Internal.SourceText.Lexical qualified as Lexical
import Amoebius.Validation.GateSpec.Seed (phaseZeroSpecInput)
import Data.List.NonEmpty qualified as NE
import Data.Text qualified as T
import Data.Text.Encoding qualified as E
import GHC.Data.FastString (unpackFS, mkFastString)
import GHC.Hs
import GHC.Hs.Instances ()
import GHC.Parser.Lexer ( Token (..), ParseResult (..), lexTokenStream, mkParserOpts, ParserOpts, initParserState, unP )
import GHC.Types.Name.Reader (rdrNameOcc)
import GHC.Types.Name.Occurrence (occNameString)
import GHC.Types.SrcLoc ( GenLocated (..), SrcSpan (..), srcSpanStartLine, srcSpanStartCol, unLoc, Located, mkRealSrcLoc )
import Text.Read (readMaybe)
import Data.Bits (xor, shiftL, shiftR)
import Data.Ratio ((%))
import Data.Word (Word64)
import Numeric.Natural (Natural)
import Amoebius.Internal.Process.EmptyInput (presentEnvironment, tryReadEmptyInput)
import Amoebius.Internal.Process.FileInput (tryRunFileInput); import Amoebius.Compiler.Journal.Raw qualified as Journal
import Amoebius.Toolchain.Acquire (nativeCabalConfig, sha256Bytes)
import Amoebius.Internal.Cabal.ComponentDescription ( DescriptionAttempt (..), parseDescription, aggregateAll, conditionalValues, dependencyLibrariesFor , reachableFrom )
import Data.Aeson qualified as Aeson
import Data.Aeson.KeyMap qualified as JsonMap
import Data.Aeson.Decoding.ByteString qualified as JsonBytes
import Data.Aeson.Decoding.Tokens qualified as Json
import Data.Foldable (toList)
import Data.Data (Data, cast, gmapQ)
import Data.Set (Set)
import Distribution.Compiler (CompilerFlavor (GHC, GHCJS))
import Distribution.Types.BuildInfo ( allExtensions, allLanguages, hcOptions, hcProfOptions, hcSharedOptions, hcProfSharedOptions , hcStaticOptions )
import Language.Haskell.Extension qualified as Cabal
import Distribution.Parsec.Warning (PWarning (..), PWarnType (PWTDeprecatedField))
import Distribution.Parsec.Position (showPos)
import Distribution.Pretty (prettyShow)
import Distribution.Types.PackageName (mkPackageName)
import Distribution.Types.UnqualComponentName (unUnqualComponentName)
import GHC.Data.EnumSet qualified as EnumSet
import GHC.Data.StringBuffer (stringToStringBuffer)
import GHC.Driver.Session ( xFlags, flagSpecFlag, flagSpecName, Language (..), languageExtensions, impliedXFlags )
import GHC.Parser (parseModule)
import GHC.Utils.Error (emptyDiagOpts)
data SeedCase = SeedCase { caseLabel :: Text, caseBefore :: Text, caseAfter :: Text } deriving (Eq, Show)
seedCases :: [SeedCase]
seedCases =
  [ SeedCase "digest-equality-bypass"
      "bootstrapDigestMatches actual expected = validLowerSha256 actual && actual == expected"
      "bootstrapDigestMatches actual _expected = validLowerSha256 actual"
  , SeedCase "snapshot-freshness-bypass"
      "bootstrapSnapshotMatches opening closing = validLowerSha256 opening && opening == closing"
      "bootstrapSnapshotMatches opening _closing = validLowerSha256 opening"
  , SeedCase "bootstrap-path-bypass"
      "bootstrapInputPathAllowed path = \".build/runs/\" `isPrefixOf` path && boundedRelativePath path"
      "bootstrapInputPathAllowed path = \".build/runs/\" `isPrefixOf` path"
  ]
data SeedProtocol = SeedProtocol { protocolRoot :: FilePath, protocolRunRoot :: FilePath, protocolPredicateSource :: FilePath , protocolDriverSource :: FilePath, protocolCompiler :: Maybe FilePath } deriving (Eq, Show)
defaultSeedProtocol :: FilePath -> FilePath -> SeedProtocol
defaultSeedProtocol root runRoot = SeedProtocol { protocolRoot = root, protocolRunRoot = runRoot , protocolPredicateSource = "src/validation-kernel/Amoebius/Validation/BootstrapPredicate.hs" , protocolDriverSource = "test/validation-kernel/BootstrapMutationDriver.hs" , protocolCompiler = Nothing }
data SeedAttempt = SeedAttempt { attemptLabel :: Text, attemptDirectory :: FilePath, attemptInputs :: [ByteString.ByteString] , attemptWrite :: Either Text () , attemptGeneratedBefore :: Either Text [ByteString.ByteString], attemptGeneratedAfter :: Either Text [ByteString.ByteString] , attemptImageBefore :: Either Text [ByteString.ByteString], attemptImageAfter :: Either Text [ByteString.ByteString] , attemptBuild :: Maybe ObservedRun, attemptRun :: Maybe ObservedRun , attemptCleanup :: Either Text Bool } deriving (Eq, Show)
data SeedOutcome = SeedOutcome { seedCompiler :: Maybe FilePath, seedProblems :: [Text] , seedChain :: Text, seedCapturedSource :: Text , seedInputs :: [(FilePath, ByteString.ByteString)], seedAttempts :: [SeedAttempt] } deriving (Eq, Show)
seedGreen :: SeedOutcome -> Bool
seedGreen outcome = null (seedProblems outcome) && case (seedInputs outcome, seedAttempts outcome) of
  ([(_, predicate), (_, driver), _], clean : mutants) ->
    map attemptLabel (clean : mutants) == "clean" : map caseLabel seedCases
      && attemptInputs clean == [predicate, driver]
      && maybe False (exactRun ExitSuccess "") (attemptRun clean)
      && all validAttempt (clean : mutants) && length mutants == length seedCases
      && all (mutantExact predicate driver clean) (zip seedCases mutants)
  _ -> False
 where
  exactRun exit errors run = runSpawnFailure run == Nothing && runExit run == exit && Text.null (runStdout run) && runStderr run == errors
  mutantExact predicate driver clean (expected, actual) = case attemptInputs actual of
    [changed, actualDriver] -> mutated expected predicate == Right changed && changed /= predicate
      && actualDriver == driver
      && maybe False (exactRun (ExitFailure 1) (caseLabel expected <> "\n")) (attemptRun actual)
      && attemptImageBefore clean /= attemptImageBefore actual
    _ -> False
  validAttempt actual = attemptWrite actual == Right () && attemptGeneratedBefore actual == Right (attemptInputs actual)
    && attemptGeneratedAfter actual == attemptGeneratedBefore actual && attemptCleanup actual == Right False
    && case (attemptBuild actual, attemptRun actual, attemptImageBefore actual, attemptImageAfter actual) of
      (Just build, Just run, Right [before], Right [after]) -> seedCompiler outcome == Just (runExecutable build)
        && runExit build == ExitSuccess && runSpawnFailure build == Nothing && runSpawnFailure run == Nothing
        && runCwd build == attemptDirectory actual && runCwd run == attemptDirectory actual
        && runExecutable run == attemptDirectory actual </> "driver.exe" && runArgv run == []
        && before == after
      _ -> False
attemptRuns :: SeedAttempt -> [ObservedRun]
attemptRuns attempt = maybe [] pure (attemptBuild attempt) <> maybe [] pure (attemptRun attempt)
seedInterrupted :: SeedOutcome -> Bool
seedInterrupted = any attemptInterrupted . seedAttempts
attemptInterrupted :: SeedAttempt -> Bool
attemptInterrupted = any (isJust . runSpawnFailure) . attemptRuns
attemptProblems :: SeedAttempt -> [Text]
attemptProblems actual =
  either pure (const []) (attemptWrite actual) <> [problem | Left problem <- [attemptGeneratedBefore actual, attemptGeneratedAfter actual, attemptImageBefore actual, attemptImageAfter actual]] <> either pure (const []) (attemptCleanup actual)
renderSeedOutcome :: SeedOutcome -> [(Text, Text)]
renderSeedOutcome outcome = [("seed.compiler", maybe "absent" Text.pack (seedCompiler outcome)), ("seed.chain", seedChain outcome), ("seed.green", Text.pack (show (seedGreen outcome)))]
    <> maybe [] (maybe [] (renderObserved "seed.clean") . attemptRun) (listToMaybe (seedAttempts outcome))
    <> concat [ maybe [("seed." <> caseLabel seedCase <> ".problem", maybe "absent-run" id (listToMaybe (attemptProblems actual)))] (renderObserved ("seed." <> caseLabel seedCase)) (attemptRun actual) | (seedCase, actual) <- zip seedCases (drop 1 (seedAttempts outcome)) ]
    <> [("seed.source", seedCapturedSource outcome), ("seed.inputs", Text.pack (show (seedInputs outcome))), ("seed.protocol.raw", Text.pack (show (concatMap attemptRuns (seedAttempts outcome))))]
    <> [("seed.attempt." <> attemptLabel actual, Text.pack (show (attemptDirectory actual, attemptInputs actual, attemptWrite actual, attemptGeneratedBefore actual, attemptGeneratedAfter actual, measured (attemptImageBefore actual), measured (attemptImageAfter actual), map observedDigest (attemptRuns actual), attemptCleanup actual))) | actual <- seedAttempts outcome]
    <> [("seed.problem", problem) | problem <- seedProblems outcome]
 where measured = fmap (map (\bytes -> (ByteString.length bytes, sha256Bytes bytes)))
runSeedProtocol :: SeedProtocol -> Text -> IO SeedOutcome
runSeedProtocol protocol challenge = captureSource (protocolRoot protocol) >>=
  either (pure . emptySeed challenge) (\source -> runCapturedSeedProtocol protocol source challenge)
emptySeed :: Text -> Text -> SeedOutcome
emptySeed challenge problem = SeedOutcome Nothing [problem] challenge "unavailable" [] []
runCapturedSeedProtocol :: SeedProtocol -> CapturedSource -> Text -> IO SeedOutcome
runCapturedSeedProtocol protocol source challenge = do
  compiler <- maybe (findExecutable "ghc") findExecutable (protocolCompiler protocol)
  acquired <- sourceAttempt $ forM [protocolPredicateSource protocol, protocolDriverSource protocol, "src/validation-kernel/Amoebius/Validation/Authority/Core.hs"] $ \path -> do
    bytes <- readSourceBytes (protocolRoot protocol </> path)
    unless (Just bytes == capturedSourceBytes source path) (fail "SeedSourceCaptureMismatch")
    pure (path, bytes)
  case (compiler, acquired) of
    (Just ghc, Right inputs@[(_, predicate), (_, driver), _]) -> do
      absolute <- canonicalizePath ghc
      let collect [] = pure []
          collect ((label, transformed) : remaining) = do
            actual <- either (pure . blankAttempt label "" [predicate, driver]) (compileAndRun protocol absolute label) transformed
            later <- if attemptInterrupted actual then pure [] else collect remaining
            pure (actual : later)
      attempts <- collect (("clean", Right [predicate, driver]) : [(caseLabel item, (\changed -> [changed, driver]) <$> mutated item predicate) | item <- seedCases])
      let runs = concatMap attemptRuns attempts
          problems = concatMap attemptProblems attempts
      pure (SeedOutcome (Just absolute) problems (foldl chainDigest challenge runs)
        (capturedSourceDigest source) inputs attempts)
    _ -> pure ((emptySeed challenge (either id (const "native compiler unavailable") acquired)) {seedCompiler = compiler, seedCapturedSource = capturedSourceDigest source})
mutated :: SeedCase -> ByteString.ByteString -> Either Text ByteString.ByteString
mutated seedCase bytes = do
  original <- either (Left . Text.pack . show) Right (E.decodeUtf8' bytes)
  unless (length (filter (== caseBefore seedCase) (Text.lines original)) == 1) (Left "seed locus is not unique")
  let changed = E.encodeUtf8 (Text.intercalate "\n" [if line == caseBefore seedCase then caseAfter seedCase else line | line <- Text.splitOn "\n" original])
  if changed == bytes then Left "seed source unchanged" else Right changed
blankAttempt :: Text -> FilePath -> [ByteString.ByteString] -> Text -> SeedAttempt
blankAttempt label directory inputs problem = SeedAttempt label directory inputs (Left "not attempted") (Left problem) (Left "not attempted") (Left "not attempted") (Left "not attempted") Nothing Nothing (Left "not attempted")
compileAndRun :: SeedProtocol -> FilePath -> Text -> [ByteString.ByteString] -> IO SeedAttempt
compileAndRun protocol ghc label inputs = do
  root <- makeAbsolute (protocolRoot protocol)
  directory <- makeAbsolute (protocolRunRoot protocol </> "seed" </> Text.unpack label)
  physical <- canonicalizePath directory
  exists <- doesPathExist directory
  let relative = makeRelative root directory
      predicatePath = directory </> "Amoebius/Validation/BootstrapPredicate.hs"
      paths = [predicatePath, directory </> "Driver.hs"]
      generated = sourceAttempt (mapM readSourceBytes paths)
      image = sourceAttempt (readImages directory [directory </> "driver.exe"])
      blank = blankAttempt label directory inputs
  if exists || not (equalFilePath directory physical) || isAbsolute relative || ".." `elem` splitDirectories relative || take 1 (splitDirectories relative) /= [".build"]
    then pure (blank "SeedLeafNotFreshOrConfined") else do
      created <- sourceAttempt (createDirectoryIfMissing True (takeDirectory directory) >> createDirectory directory)
      case created of
        Left problem -> pure (blank problem)
        Right () -> do
          written <- sourceAttempt (createDirectoryIfMissing True (takeDirectory predicatePath) >> sequence_ (zipWith ByteString.writeFile paths inputs))
          beforeSources <- generated
          observed <- case written >> beforeSources of
            Left problem -> pure (blank problem) {attemptWrite = written, attemptGeneratedBefore = beforeSources}
            Right actual | actual /= inputs -> pure (blank "SeedGeneratedSourceChanged") {attemptWrite = written, attemptGeneratedBefore = beforeSources}
            Right _ -> do
              build <- observe directory ghc ["-v0", "-j1", "-i.", "-outputdir", "objects", "-o", "driver.exe", "Driver.hs"]
              if isJust (runSpawnFailure build) || runExit build /= ExitSuccess then pure (blank (if isJust (runSpawnFailure build) then "SeedProcessTupleUnavailable" else "SeedCompilationFailed")) {attemptWrite = written, attemptGeneratedBefore = beforeSources, attemptBuild = Just build} else do
                before <- image
                case before of
                  Left problem -> pure (blank problem) {attemptWrite = written, attemptGeneratedBefore = beforeSources, attemptBuild = Just build, attemptImageBefore = before}
                  Right _ -> do
                    run <- observe directory (directory </> "driver.exe") []
                    after <- if isNothing (runSpawnFailure run) then image else pure (Left "not attempted")
                    pure (SeedAttempt label directory inputs written beforeSources (Left "not attempted") before after (Just build) (Just run) (Left "not attempted"))
          if attemptInterrupted observed then pure observed else do
            afterSources <- generated
            cleanup <- sourceAttempt (removePathForcibly directory >> doesPathExist directory)
            pure observed {attemptGeneratedAfter = afterSources, attemptCleanup = cleanup}
closureDigest :: FilePath -> PackageGraph -> VerifiedSpec -> Text -> Text -> IO Text
closureDigest root graph verified verifier governance = do
  let spec = verifiedSpec verified
      targets = [cabalTargetName (gateSuite spec), oracleExecutableName (gateOracle spec), "runner-suite", "oracle-runner", "symbolic-checker-spec", "refinement-checker-spec"]
      components = [info | target <- targets, Just (info,_) <- [Map.lookup target (graphTestSuites graph)]] <> [info | target <- [if gateRole spec == SeedGate then "amoebius-validate" else "amoebius", "extension-source-admission"], Just info <- [Map.lookup target (graphExecutables graph)]]
      stanzas = libraryClosure graph (Map.elems (verifiedStanzaOf verified) <> concatMap (Set.toList . internalDependencies) components)
      directories = Set.toList (Set.fromList (concat [dirs | stanza <- Set.toList stanzas, Just (_,_,dirs) <- [Map.lookup stanza (graphLibraries graph)]] <> concatMap (map getSymbolicPath . hsSourceDirs) components <> ["test/validation-kernel"]))
  files <- sort . nub . (["amoebius.cabal","cabal.project",".gitignore","pb/__main__.py"] <>) . concat <$> mapM (haskellFilesUnder root) directories
  documents <- if gateRole spec /= SeedGate then pure [] else do
    (corpus,findings,_) <- discoverDocuments root
    unless (null findings) (fail "ClosureDocumentDiscovery")
    frontier <- maybe (fail "ClosureStatusDomain") pure (Status.frontierForGate PhaseIdentity.phaseDomainLowerOrdinal)
    projection <- patchToFrontier root frontier Map.empty
    pure [(path,maybe contents id (lookup path projection)) | (path,contents) <- corpus]
  digests <- mapM (\file -> (\contents -> Text.pack file <> "\t" <> sha256Hex contents) <$> readSourceText (root </> file)) files
  pure (sha256Hex (Text.unlines (digests <> ["document\t" <> Text.pack path <> "\t" <> sha256Hex contents | (path,contents) <- sort documents] <> ["verifier\t" <> verifier, "governance\t" <> governance, "subjects\t" <> Text.pack (show (gateSubjects spec))])))
data CustodyConfig = CustodyConfig { custodyRoot :: FilePath, custodyStore :: Store, custodyDocCheckCap :: Int , custodyMutantLimit :: Maybe Int, custodyCabal :: Maybe FilePath, custodyCompiler :: Maybe FilePath } deriving (Eq, Show)
defaultCustodyConfig :: FilePath -> CustodyConfig
defaultCustodyConfig root = CustodyConfig root (Store ".build/certification") 7000 Nothing Nothing Nothing
archiveRoot :: CustodyConfig -> FilePath
archiveRoot config = custodyRoot config </> "validation-records"
data CommandOutcome = CommandOutcome { outcomeExit :: ExitCode, outcomeLines :: [Text] } deriving (Eq, Show)
receiptCompatibility :: Int -> Text -> Text -> Text -> Maybe (Text, Text) -> Receipt -> Either Text ()
receiptCompatibility phase digest verifier governance expected receipt = case [reason | (valid,reason) <- [(receiptPhase receipt == phase && receiptReproducible receipt == digest && Just (receiptCapability receipt) == fmap PhaseIdentity.phaseIdentityCapability (PhaseIdentity.lookupPhaseIdentity phase),"ReceiptIdentityMismatch"),(receiptGeneration receipt == verifier && receiptVerifierDigest receipt == verifier,"ReceiptVerifierMismatch"),(receiptGovernanceDigest receipt == governance,"ReceiptGovernanceMismatch"),(maybe False (\(closure,_) -> Text.length closure == 64 && Text.all (\c -> c `elem` ("0123456789abcdef" :: String)) closure) expected,"ReceiptClosureUnavailable"),(fmap fst expected == Just (receiptClosureDigest receipt),"ReceiptClosureMismatch"),(fmap snd expected == Just (receiptSpecRendered receipt),"ReceiptSpecificationMismatch")],not valid] of [] -> Right (); reason : _ -> Left reason
refuse :: [Text] -> CommandOutcome
refuse = CommandOutcome (ExitFailure 1)
runnerConfig :: CustodyConfig -> Int -> RunnerConfig
runnerConfig config ordinal =
  (defaultRunnerConfig (custodyRoot config) ordinal)
    { runnerHygienePreflight = False, runnerDocCheckCap = custodyDocCheckCap config
    , runnerMutantLimit = custodyMutantLimit config, runnerCabal = fromMaybe "cabal" (custodyCabal config)
    , runnerCompiler = custodyCompiler config }
runFresh :: CustodyConfig -> Int -> GateSpec -> Maybe (Text, PassedGate) -> IO (Either RunnerRefusal GateOutcome)
runFresh config ordinal spec predecessor = either (Left . SourceCaptureRefused) id <$> sourceAttempt (withResult (archivedKernelCap (custodyRoot config)) (pure . Left . KernelRatchetUnavailable) $ \cap -> do
      hygiene <- hygieneRow (custodyRoot config) cap (custodyDocCheckCap config)
      if not (hygieneGreen hygiene) then pure (Left (HygieneRefused hygiene)) else runBound cap)
 where
  runBound cap = withResult (Tools.selectToolchain (custodyRoot config) (Tools.ToolchainPaths Nothing (custodyCompiler config) (custodyCabal config)))
      (pure . Left . ProductBinaryUnavailable . Text.intercalate "; " . map Tools.renderRefusal) $ \selected -> do
        let native = config {custodyCompiler = Just (Tools.acquisitionCompiler selected), custodyCabal = Just (Tools.acquisitionPackageTool selected)}
            settings = (runnerConfig native ordinal) {runnerPredecessorDigest = fmap fst predecessor, runnerPredecessorGate = fmap snd predecessor, runnerLastAcceptedKernelLines = cap}
        now <- getCurrentTime
        runGate settings {runnerRunRoot = runnerRunRoot settings </> Text.unpack (sha256Hex (Text.pack (show now)))} spec
-- Reproduce the recorded immediate predecessor; metadata alone supplies no handle.
-- Outer Nothing is metadata refusal; Just carries the admitted reproduction's possible pass.
reproducePredecessor :: CustodyConfig -> Text -> StatusSurface -> [(Receipt, FilePath)] -> Int -> IO (Maybe (Maybe (Text, PassedGate)))
reproducePredecessor config verifier surface bundles ordinal = case [(receipt, path) | Just predecessor <- [PhaseIdentity.predecessorOrdinal ordinal], Just digest <- [lookup predecessor (surfaceReceipts surface)], (receipt, path) <- bundles, receiptPhase receipt == predecessor, receiptReproducible receipt == digest, isNothing (receiptResetCause receipt)] of
  [(receipt, path)] -> fmap (fmap (\passed -> (receiptReproducible receipt, passed))) <$> admitPredecessor config verifier surface bundles receipt path
  _ -> pure (if isNothing (PhaseIdentity.predecessorOrdinal ordinal) then Just Nothing else Nothing)
reproducibleDigest :: Text -> Text -> Text -> Text -> Text
reproducibleDigest core closure verifier governance =
  sha256Hex (Text.unlines ["core\t" <> core, "closure\t" <> closure, "verifier\t" <> verifier, "governance\t" <> governance])
closureFor :: CustodyConfig -> GateSpec -> Text -> IO Text
closureFor config spec verifier = do
  graph <- loadPackageGraph (custodyRoot config)
  verified <- verifySpec (custodyRoot config) spec
  case (graph, verified) of
    (Right g, Right v) -> closureDigest (custodyRoot config) g v verifier governanceDigest
    _ -> pure "closure-unavailable"
gitObserved :: FilePath -> [String] -> IO ObservedRun
gitObserved root args = makeAbsolute root >>= \absolute -> observe root "git" (["-c", "safe.directory=" <> absolute] <> args)
isAncestor :: FilePath -> Text -> IO Bool
isAncestor root commit = (== ExitSuccess) . runExit <$> gitObserved root ["merge-base", "--is-ancestor", Text.unpack commit, "HEAD"]
headCommit :: FilePath -> IO Text
headCommit root = Text.strip . runStdout <$> gitObserved root ["rev-parse", "HEAD"]
issuanceStamp :: FilePath -> IO (Text, Text)
issuanceStamp root = (,) <$> headCommit root <*> (Text.pack . show <$> getCurrentTime)
archiveCommitted :: CustodyConfig -> FilePath -> IO Bool
archiveCommitted config bundle = do
  let root = custodyRoot config
      path = makeRelative root bundle
      names = ["receipt.tsv", "receipt.tsv.sha256", "candidate.tsv", "kill-table.tsv", "outcome.tsv", "oracle-ledger.tsv", "observer.tsv"]
  tracked <- observe root "git" (["ls-files", "--error-unmatch", "--"] <> map (path </>) names)
  clean <- observe root "git" ["status", "--porcelain", "--", path]
  pure (runExit tracked == ExitSuccess && runExit clean == ExitSuccess && Text.null (Text.strip (runStdout clean)))
-- Metadata eligibility supplies no gate authority; both admissions share this policy.
receiptPublicationBound :: Text -> Bool -> StatusSurface -> [Receipt] -> Receipt -> Bool
receiptPublicationBound verifier durable surface receipts receipt =
  surfaceConsistent surface && PhaseIdentity.isPhaseOrdinal phase && isNothing (receiptResetCause receipt)
    && all current receipts && [row | row <- receipts, receiptPhase row == phase] == [receipt]
    && lookup phase (surfaceReceipts surface) == Just (receiptReproducible receipt)
    && maybe True digestShape (receiptAcceptedPrefix receipt)
    && either (const False) bound (latestWholePostimage receipts)
 where
  phase = receiptPhase receipt
  current row = PhaseIdentity.isPhaseOrdinal (receiptPhase row) && receiptGeneration row == verifier && receiptVerifierDigest row == verifier && receiptGovernanceDigest row == governanceDigest
  bound latest = durable || receiptStatusPostimage receipt == surfaceDigest surface || (latest == Just (surfaceDigest surface) && prefixBound)
  prefixBound = maybe False (\prefix -> Just prefix == statusPrefixDigest phase surface) (receiptAcceptedPrefix receipt)
-- Re-run the complete predecessor before issuing an exact-source handle.
admitPredecessor :: CustodyConfig -> Text -> StatusSurface -> [(Receipt, FilePath)] -> Receipt -> FilePath -> IO (Maybe (Maybe PassedGate))
admitPredecessor config verifier surface bundles receipt path = case resolveSpec registeredSpecInputs (receiptPhase receipt) of
  Left _ -> pure Nothing
  Right (_, spec) -> do
    openingClosure <- closureFor config spec verifier
    ancestor <- isAncestor (custodyRoot config) (receiptTreeCommit receipt)
    durable <- archiveCommitted config path
    if not (ancestor && receiptPublicationBound verifier durable surface (map fst bundles) receipt && (receipt, path) `elem` bundles
      && receiptCompatibility (receiptPhase receipt) (receiptReproducible receipt) verifier governanceDigest (Just (openingClosure, renderGateSpec spec)) receipt == Right ()) then pure Nothing
    else do
      predecessor <- join <$> reproducePredecessor config verifier surface bundles (receiptPhase receipt)
      checked <- runFresh config (receiptPhase receipt) spec predecessor
      closure <- closureFor config spec verifier
      pure $ Just $ case checked of
        Right outcome | reproducibleDigest (candidateReproducibleCore (outcomeCandidate outcome)) closure verifier governanceDigest == receiptReproducible receipt -> outcomePassed outcome
        _ -> Nothing
gatherFacts :: CustodyConfig -> Int -> GateSpec -> IO (Either Text (PreflightFacts, StatusSurface, Maybe SeedRecord, [Receipt], [(Receipt, FilePath)], Text, Maybe (Text, PassedGate)))
gatherFacts config ordinal spec = withResults
  (auditArchivedInventory (custodyRoot config)) (archivedKernelCap (custodyRoot config)) (pure . Left) $ \(digest, _) cap ->
    gatherFactsChecked config ordinal spec digest cap
gatherFactsChecked :: CustodyConfig -> Int -> GateSpec -> Text -> Maybe Int -> IO (Either Text (PreflightFacts, StatusSurface, Maybe SeedRecord, [Receipt], [(Receipt, FilePath)], Text, Maybe (Text, PassedGate)))
gatherFactsChecked config ordinal spec archiveDigest cap = do
  let root = custodyRoot config
      store = custodyStore config
  withResult (statusSurface root) (pure . Left) $ \recorded -> do
      verifier <- verifierDigest
      seed <- latestGeneration store verifier
      withResult (readCurrentArchivedBundles (archiveRoot config) verifier) (pure . Left) $ \bundles ->
        withResult (pure (latestWholePostimage (map fst bundles))) (pure . Left) $ \latest -> do
          let receipts = [receipt | (receipt, _) <- bundles, isNothing (receiptResetCause receipt)]
          let barrier = any (\receipt -> Just (receiptPhase receipt) == PhaseIdentity.roleOrdinal PhaseIdentity.DslBarrier && lookup (receiptPhase receipt) (surfaceReceipts recorded) == Just (receiptReproducible receipt)) receipts
          hygiene <- hygieneRow root cap (custodyDocCheckCap config)
          compatible <- mapM (\phase -> case resolveSpec registeredSpecInputs phase of
            Left _ -> pure (phase, Nothing)
            Right (_, current) -> do
              closure <- closureFor config current verifier
              pure (phase, Just (closure, renderGateSpec current)))
            [phase | Just f <- [recordedFrontier recorded], phase <- PhaseIdentity.phaseOrdinals, Status.phaseStatusAt f phase == Status.Done]
          let frontier = recordedFrontier recorded
              donePhases = [phase | Just f <- [frontier], phase <- PhaseIdentity.phaseOrdinals, Status.phaseStatusAt f phase == Status.Done]
              doneWithout = [phase | phase <- donePhases, phase `notElem` map fst (surfaceReceipts recorded)]
              receiptMatches phase digest receipt = receiptCompatibility phase digest verifier governanceDigest (lookup phase compatible >>= id) receipt == Right ()
              notReproduced = [phase | phase <- donePhases
                , Just digest <- [lookup phase (surfaceReceipts recorded)]
                , not (any (receiptMatches phase digest) receipts)]
              acceptedPostimage = maybe (seedStatusPostimage <$> seed) Just latest
          predecessor <- if null notReproduced && null doneWithout && (gateRole spec /= HardwareGate || barrier) then join <$> reproducePredecessor config verifier recorded bundles ordinal else pure Nothing
          let committed = if ordinal == PhaseIdentity.phaseDomainLowerOrdinal || not (null notReproduced && null doneWithout) then Nothing else Just (isJust predecessor)
          host <- if gateRole spec == HardwareGate && surfaceConsistent recorded && barrier && null notReproduced && null doneWithout && committed == Just True then hostFacts else pure (HostFacts [HardwareFree])
          pure (Right (PreflightFacts spec (surfaceDigest recorded) acceptedPostimage (surfaceConsistent recorded) committed doneWithout notReproduced []
            barrier
            host (hygieneProblems hygiene) Nothing, recorded, seed, receipts, bundles, archiveDigest, predecessor))
archiveStable :: CustodyConfig -> [(Receipt, FilePath)] -> Either Text Text -> IO Bool
archiveStable config before previous = (\audited current -> case (previous, audited) of (Right old, Right (now, _)) -> old == now && current == Right before; _ -> False)
  <$> auditArchivedInventory (custodyRoot config) <*> (verifierDigest >>= readCurrentArchivedBundles (archiveRoot config))
ensureGeneration :: CustodyConfig -> Text -> Text -> StatusSurface -> IO (Either Text SeedRecord)
ensureGeneration config verifier enteredBy recorded = do
  let store = custodyStore config
  existing <- latestGeneration store verifier
  maybe (do
      (commit, issuedAt) <- issuanceStamp (custodyRoot config)
      let seed = SeedRecord { seedGeneration = verifier, seedEnteredBy = enteredBy, seedVerifierDigest = verifier , seedGovernanceDigest = governanceDigest, seedStatusPostimage = surfaceDigest recorded , seedTreeCommit = commit, seedIssuedAt = issuedAt }
      written <- writeSeed store seed
      pure (either Left (const (Right seed)) written)) (pure . Right) existing
renderRows :: Candidate -> [Text]
renderRows candidate = ["row\t" <> renderGateCategory (rowCategory r) <> "\t" <> renderVerdict (rowVerdict r) | r <- candidateRows candidate]
archiveEvidence :: GateSpec -> GateOutcome -> Either Text [(FilePath, Text)]
archiveEvidence spec outcome = case cleanOracle of
  [] -> Left "ARCHIVE-ORACLE-ABSENT: no clean oracle transcript can be archived"
  ledgers | length ledgers == (if isNothing (gateSeed spec) then 1 else 2) -> bounded
    [ ("candidate.tsv", renderCandidate candidate)
    , ("kill-table.tsv", Text.unlines (renderKillTable (outcomeKillTable outcome)))
    , ("outcome.tsv", Text.unlines ["green\tTrue", "spec-digest\t" <> candidateSpecDigest candidate, "chain\t" <> candidateChain candidate, "reproducible-core\t" <> candidateReproducibleCore candidate, "capability\t" <> gateCapability spec, "claim\t" <> gateClaim spec])
    , ("oracle-ledger.tsv", Text.unlines [case Text.splitOn "\t" line of name:verdict:rest -> Text.intercalate "\t" (name:verdict:map nativeDiagnostic rest); _ -> line | line <- Text.lines (Text.concat (reverse ledgers))])
    , ("observer.tsv", Text.unlines [key <> "\t" <> value | (index, run) <- zip [1 :: Int ..] (outcomeRuns outcome), (key, value) <- renderObserved ("run." <> Text.pack (show index)) run])
    ]
  _ -> Left "ARCHIVE-ORACLE-CARDINALITY: clean oracle transcripts are missing or repeated"
 where
  bounded evidence = case [(name,size) | (name,body)<-evidence,let size=ByteString.length (E.encodeUtf8 body),size>16*1024*1024] of [] -> Right evidence; oversized -> Left ("ARCHIVE-RECORD-OVERSIZED: evidence exceeds the 16 MiB per-record limit: " <> showText oversized)
  candidate = outcomeCandidate outcome
  cleanOracle =
    [ prefix | row <- candidateRows candidate, rowCategory row == Oracle
    , ("oracle.completion-contexts", encoded) <- rowObservations row
    , Just contexts <- [readMaybe (Text.unpack encoded) :: Maybe [((Text,FilePath,FilePath,Maybe FilePath),[Text],Text)]]
    , (_,_,encodedPrefix) <- contexts, Just prefix <- [nativeRestore encodedPrefix]
    ]
publishReceipt :: CustodyConfig -> GateSpec -> GateOutcome -> [(FilePath, Text)] -> Receipt -> IO (Either Text FilePath)
publishReceipt config spec outcome patch receipt = either (pure . Left) (publishEvidenceReceipt config patch receipt) (archiveEvidence spec outcome)
publishEvidenceReceipt :: CustodyConfig -> [(FilePath, Text)] -> Receipt -> [(FilePath, Text)] -> IO (Either Text FilePath)
publishEvidenceReceipt config patch receipt evidence = do
    let root = custodyRoot config
    originals <- mapM (\(path, _) -> (,) path <$> readSourceText (root </> path)) patch
    applied <- try (mapM_ (\(path, contents) -> TextIO.writeFile (root </> path) contents) patch) :: IO (Either IOException ())
    withResult (rollbackOnLeft (restore originals) (either (Left . Text.pack . show) Right applied)) (pure . Left) $ \() -> do
        archived <- withResult (statusSurface root) (pure . Left) $ \surface ->
          if surfaceConsistent surface then writeArchivedReceipt (archiveRoot config) receipt {receiptStatusPostimage = surfaceDigest surface, receiptAcceptedPrefix = statusPrefixDigest (receiptPhase receipt) surface} evidence
          else pure (Left "status projection is incomplete or inconsistent")
        rollbackOnLeft (restore originals) archived
 where
  restore originals = mapM_ (\(path, contents) -> TextIO.writeFile (custodyRoot config </> path) contents) originals
previewPhase :: CustodyConfig -> Int -> IO CommandOutcome
previewPhase config ordinal = case resolveSpec registeredSpecInputs ordinal of
  Left problems -> pure (refuse problems)
  Right (row, spec) -> withResult (gatherFacts config ordinal spec) (pure . refuse . pure) $ \(facts, _, _, _, bundles, digest, predecessor) -> do
        let refusals = preflight facts
        runOutcome <- runFresh config ordinal spec predecessor
        stable <- archiveStable config bundles (Right digest)
        pure $ case runOutcome of
          _ | not stable -> refuse ["archive changed during the candidate gate"]
          Left refusal -> CommandOutcome (ExitFailure 1) (map renderPreflightRefusal refusals <> ["RUNNER: " <> renderRefusal refusal])
          Right outcome ->
            let candidate = outcomeCandidate outcome
                exported = archiveEvidence spec outcome
                green = null refusals && candidateGreen candidate && isRight exported
             in CommandOutcome
                  (if green then ExitSuccess else ExitFailure 1)
                  ( ["preview phase " <> Text.pack (show ordinal) <> " (" <> PhaseIdentity.phaseIdentityCapability row <> "): " <> (if green then "would pass; nothing minted" else "would not pass")]
                      <> map renderPreflightRefusal refusals
                      <> either pure (const []) exported
                      <> renderRows candidate
                      <> ["claim\t" <> gateClaim spec, "spec-digest\t" <> candidateSpecDigest candidate, "reproducible-core\t" <> candidateReproducibleCore candidate]
                      <> renderKillTable (outcomeKillTable outcome)
                  )
acceptPhase :: CustodyConfig -> Int -> IO CommandOutcome
acceptPhase config ordinal = case resolveSpec registeredSpecInputs ordinal of
  Left problems -> pure (refuse problems)
  Right (row, spec) -> withResult (gatherFacts config ordinal spec) (pure . refuse . pure) $ \(facts, recorded, _, _, bundles, digest, predecessor) -> case preflight facts of
        refusals@(_ : _) -> pure (refuse (map renderPreflightRefusal refusals))
        [] -> case recordedFrontier recorded >>= \frontier -> Status.frontierAfterPass frontier ordinal of
          Nothing -> pure (refuse ["the recorded frontier is not open at phase " <> Text.pack (show ordinal)])
          Just next -> do
            runOutcome <- runFresh config ordinal spec predecessor
            stable <- archiveStable config bundles (Right digest)
            case runOutcome of
              _ | not stable -> pure (refuse ["archive changed during the candidate gate"])
              Left refusal -> pure (refuse ["RUNNER: " <> renderRefusal refusal])
              Right outcome
                | not (candidateGreen (outcomeCandidate outcome)) ->
                    pure (refuse ("the candidate is not green" : [line | line <- renderRows (outcomeCandidate outcome), not ("\tgreen" `Text.isSuffixOf` line)]))
                | otherwise -> issueAccept config ordinal row spec recorded next outcome
issueAccept :: CustodyConfig -> Int -> PhaseIdentity.PhaseIdentity -> GateSpec -> StatusSurface -> Status.StatusFrontier -> GateOutcome -> IO CommandOutcome
issueAccept config ordinal row spec recorded next outcome = do
  let root = custodyRoot config
      candidate = outcomeCandidate outcome
      table = outcomeKillTable outcome
  verifier <- verifierDigest
  closure <- closureFor config spec verifier
  let reproducible = reproducibleDigest (candidateReproducibleCore candidate) closure verifier governanceDigest
  withResult (ensureGeneration config verifier ("accept phase " <> Text.pack (show ordinal)) recorded) (pure . refuse . pure . ("generation not recorded: " <>)) $ \seed -> do
      let receipts = Map.insert ordinal reproducible (Map.fromList (surfaceReceipts recorded))
      patch <- patchToFrontier root next receipts
      (commit, issuedAt) <- issuanceStamp root
      let tableText = Text.unlines (renderKillTable table)
          witnessRows = [Text.intercalate " " (take 2 (drop 1 fields) <> drop 3 (take 4 fields)) | line <- Text.lines tableText, let fields = Text.splitOn "\t" line, length fields >= 5, fields !! 3 /= "no-witness"]
          receipt = receiptFromGate seed spec outcome closure reproducible commit issuedAt witnessRows
      withResult (publishReceipt config spec outcome patch receipt) (pure . refuse . pure . ("receipt not recorded: " <>)) $ \archive -> pure (CommandOutcome ExitSuccess
          (["accepted phase " <> Text.pack (show ordinal) <> " (" <> PhaseIdentity.phaseIdentityCapability row <> ")", "claim\t" <> gateClaim spec, "spec-digest\t" <> candidateSpecDigest candidate, "reproducible-digest\t" <> reproducible, "chain\t" <> candidateChain candidate]
            <> Text.lines tableText <> ["status patch\t" <> Text.pack path | (path, _) <- patch] <> ["receipt\t" <> Text.pack archive]))
receiptFromGate :: SeedRecord -> GateSpec -> GateOutcome -> Text -> Text -> Text -> Text -> [Text] -> Receipt
receiptFromGate seed spec outcome closure reproducible commit issued witnesses =
  Receipt (candidatePhase candidate) (gateCapability spec) (seedGeneration seed)
    (candidateSpecDigest candidate) (renderGateSpec spec) (sha256Hex (renderCandidate candidate))
    (sha256Hex (Text.unlines (renderKillTable (outcomeKillTable outcome)))) closure reproducible
    (seedVerifierDigest seed) governanceDigest "" commit witnesses Nothing Nothing issued Nothing
 where candidate = outcomeCandidate outcome
voidFromPhase :: CustodyConfig -> Text -> StatusSurface -> Int -> Text -> Text -> IO (Either Text [FilePath])
voidFromPhase config _ recorded phase reason failure = withResult (fmap (fmap snd) (auditArchivedInventory (custodyRoot config))) (pure . Left) $ \bundles ->
    if not (any (\(receipt, _) -> receiptPhase receipt == phase && lookup phase (surfaceReceipts recorded) == Just (receiptReproducible receipt)) bundles) then pure (Left "recorded receipt is absent from the archive")
    else getCurrentTime >>= \now ->
      sequence <$> mapM (\(receipt, path) -> writeReplayVoid (archiveRoot config) receipt path reason (sha256Hex failure) (Text.pack (show now)))
        [(receipt, path) | (receipt, path) <- bundles, receiptPhase receipt >= phase
          , lookup (receiptPhase receipt) (surfaceReceipts recorded) == Just (receiptReproducible receipt)]
replayThrough :: CustodyConfig -> Maybe Int -> IO CommandOutcome
replayThrough config through = withResult (auditArchivedInventory (custodyRoot config)) (pure . refuse . pure) (const (replayThroughChecked config through))
replayThroughChecked :: CustodyConfig -> Maybe Int -> IO CommandOutcome
replayThroughChecked config through = do
  let root = custodyRoot config
  withResult (statusSurface root) (pure . refuse . pure) $ \recorded -> case recordedFrontier recorded of
      Nothing -> pure (refuse ["the tracker does not record one frontier"])
      Just frontier -> do
        verifier <- verifierDigest
        let donePhases = [phase | phase <- PhaseIdentity.phaseOrdinals, Status.phaseStatusAt frontier phase == Status.Done, maybe True (phase <=) through]
        withResult (ensureGeneration config verifier "replay" recorded) (pure . refuse . pure . ("generation not recorded: " <>)) $ \seed -> do
            result <- foldM (replayOne config seed verifier) (Right []) donePhases
            pure $ case result of
              Left problem -> refuse problem
              Right lines' -> CommandOutcome ExitSuccess ("replay complete for " <> Text.intercalate "," (map (Text.pack . show) donePhases) : reverse lines')
replayOne :: CustodyConfig -> SeedRecord -> Text -> Either [Text] [Text] -> Int -> IO (Either [Text] [Text])
replayOne _ _ _ (Left problem) _ = pure (Left problem)
replayOne config seed verifier (Right done) phase = do
  withResults (statusSurface (custodyRoot config)) (readCurrentArchivedBundles (archiveRoot config) verifier)
    (\problem -> pure (Left (reverse done <> [problem]))) $ \recorded bundles -> case lookup phase (surfaceReceipts recorded) of
      Nothing -> pure (Left (reverse done <> ["STATUS-WITHOUT-RECEIPT: phase " <> Text.pack (show phase) <> " is Done without a receipt line"]))
      Just recordedDigest -> case (resolveSpec registeredSpecInputs phase, recordedFrontier recorded) of
            (Left problems, _) -> pure (Left (reverse done <> problems))
            (_, Nothing) -> pure (Left (reverse done <> ["the tracker does not record one frontier"]))
            (Right (_, spec), Just frontier) -> do
              snapshot <- fmap (fmap fst) (auditArchivedInventory (custodyRoot config))
              reproduced <- if null done then pure Nothing else reproducePredecessor config verifier recorded bundles phase
              if phase /= PhaseIdentity.phaseDomainLowerOrdinal && (null done || isNothing reproduced)
                then pure (Left (reverse done <> ["PredecessorNotReproduced: no freshly replayed and exact-read immediate predecessor for phase " <> Text.pack (show phase)]))
                else do
                  runOutcome <- runFresh config phase spec (join reproduced)
                  case runOutcome of
                    Left refusal -> do
                      voided <- voidFromPhase config verifier recorded phase "runner-refusal" (renderRefusal refusal)
                      pure (Left (reverse done <> ["RUNNER: " <> renderRefusal refusal] <> either (\problem -> ["void record unavailable: " <> problem]) (const []) voided))
                    Right outcome -> do
                      closure <- closureFor config spec verifier
                      let candidate = outcomeCandidate outcome
                          reproducible = reproducibleDigest (candidateReproducibleCore candidate) closure verifier governanceDigest
                      if not (candidateGreen candidate)
                        then do
                          voided <- voidFromPhase config verifier recorded phase "gate-red" (Text.unlines (renderRows candidate))
                          pure (Left (reverse done <> ["PredecessorNotReproduced: phase " <> Text.pack (show phase) <> " recorded " <> recordedDigest <> " but its gate is red on the current tree:"] <> [line | line <- renderRows candidate, not ("\tgreen" `Text.isSuffixOf` line)] <> either (\problem -> ["void record unavailable: " <> problem]) (const []) voided))
                        else do
                          stable <- archiveStable config bundles snapshot
                          if not stable then pure (Left (reverse done <> ["archive changed during the replay gate"])) else do
                            (commit, issuedAt) <- issuanceStamp (custodyRoot config)
                            let receipt = receiptFromGate seed spec outcome closure reproducible commit issuedAt []
                            patch <- patchToFrontier (custodyRoot config) frontier (Map.insert phase reproducible (Map.fromList (surfaceReceipts recorded)))
                            withResult (publishReceipt config spec outcome patch receipt) (pure . Left . (reverse done <>) . pure . ("receipt not recorded: " <>)) $ \_ ->
                              pure (Right (("phase " <> Text.pack (show phase) <> if reproducible == recordedDigest then "\treproduced (new archive)" else "\trefreshed (" <> Text.take 16 recordedDigest <> " -> " <> Text.take 16 reproducible <> ")") : done))
resetGeneration :: CustodyConfig -> Text -> Text -> Text -> IO CommandOutcome
resetGeneration config decision validatorGap productGap =
  if Text.null (Text.strip validatorGap) then pure (refuse ["VALIDATOR-GAP-ABSENT"]) else case (Decisions.parseDecisionId decision, Legacy.parseLegacyId productGap) of
    (Nothing, _) -> pure (refuse ["DECISION-UNKNOWN: " <> decision])
    (_, Nothing) -> pure (refuse ["PRODUCT-GAP-UNKNOWN: " <> productGap])
    (Just _, Just identifier) -> case Legacy.legacyOwnerOrdinal identifier of
      Nothing -> pure (refuse ["PRODUCT-GAP-UNOWNED: " <> productGap])
      Just owner -> do
        let root = custodyRoot config
        withResult (statusSurface root) (pure . refuse . pure) $ \recorded -> case recordedFrontier recorded of
            Nothing -> pure (refuse ["the tracker does not record one frontier"])
            Just frontier -> do
              verifier <- verifierDigest
              withResult (ensureGeneration config verifier ("reset " <> decision) recorded) (pure . refuse . pure . ("generation not recorded: " <>)) $ \seed -> do
                  let phase = minimum (owner : [p | p <- PhaseIdentity.phaseOrdinals, Status.phaseStatusAt frontier p /= Status.Done])
                  case (Status.frontierForGate phase, PhaseIdentity.lookupPhaseIdentity phase) of
                    (Just next, Just identity) -> do
                      patch <- patchToFrontier root next (Map.fromList (surfaceReceipts recorded))
                      (commit, issuedAt) <- issuanceStamp root
                      let spec = Text.unlines ["record\tamoebius-status-reset.v1", "decision\t" <> Text.pack (show decision),
                            "validator-gap\t" <> Text.pack (show validatorGap), "product-gap\t" <> productGap,
                            "status-preimage\t" <> surfaceDigest recorded, "target\t" <> Text.pack (show phase)]
                          digest = sha256Hex spec
                          candidate = Text.unlines ["candidate\tphase=" <> Text.pack (show phase) <> "\tcapability=" <> PhaseIdentity.phaseIdentityCapability identity,
                            "spec-digest\t" <> digest, spec]
                          killed = "record\tstatus-reset; no gate or mutation matrix executed\n"
                          evidence = [("candidate.tsv", candidate), ("kill-table.tsv", killed), ("outcome.tsv", "reset\tapplied\n"),
                            ("oracle-ledger.tsv", "record\treset event; not a gate verdict\n"), ("observer.tsv", "status-preimage\t" <> surfaceDigest recorded <> "\n")]
                          reproducible = reproducibleDigest (sha256Hex candidate) digest verifier governanceDigest
                          receipt = Receipt phase (PhaseIdentity.phaseIdentityCapability identity) (seedGeneration seed) digest spec (sha256Hex candidate)
                            (sha256Hex killed) digest reproducible verifier governanceDigest "" commit [] (Just (validatorGap, productGap)) Nothing issuedAt Nothing
                      withResult (publishEvidenceReceipt config patch receipt evidence) (pure . refuse . pure . ("reset receipt not recorded: " <>)) $ \path ->
                        pure (CommandOutcome ExitSuccess ["reset recorded under " <> decision <> " naming " <> productGap <> " at frontier phase " <> Text.pack (show phase), "receipt\t" <> Text.pack path])
                    _ -> pure (refuse ["reset target has no phase identity"])
demoFile :: CustodyConfig -> FilePath -> IO CommandOutcome
demoFile config path = do
  exists <- doesFileExist path
  if not exists
    then pure (refuse ["DEMO-FILE-ABSENT: " <> Text.pack path])
    else do
      withResult (statusSurface (custodyRoot config)) (pure . refuse . pure) $ \recorded -> do
          verifier <- verifierDigest
          withResult (ensureGeneration config verifier "demo" recorded) (pure . refuse . pure . ("generation not recorded: " <>)) $ \seed -> do
              contents <- readSourceText path
              now <- getCurrentTime
              let digest = sha256Hex contents
              withResult (writeRecord (generationDirectory (custodyStore config) (seedGeneration seed) </> "demonstration.tsv") (Text.unlines ["file\t" <> Text.pack path, "digest\t" <> digest, "issued-at\t" <> Text.pack (show now)])) (pure . refuse . pure . ("demonstration not recorded: " <>)) $ \() ->
                pure (CommandOutcome ExitSuccess ["operator demonstration recorded: " <> Text.take 16 digest])
data StatusSurface = StatusSurface { surfaceTracker :: [(Int, Int, Text)] {- phase, line number, status cell -} , surfacePhaseLines :: [(Int, Int, Text)] {- phase, line number, status line -} , surfaceSprints :: [(Int, Int, Int, Text, Text)] {- phase, sprint, heading line, heading, status field line -} , surfaceReceipts :: [(Int, Text)] {- phase, receipt digest recorded beside a Done status -} } deriving (Eq, Show)
trackerPath :: FilePath
trackerPath = "DEVELOPMENT_PLAN/README.md"
statusSurface :: FilePath -> IO (Either Text StatusSurface)
statusSurface root = either Left id <$> sourceAttempt
  (readExistingSource (root </> trackerPath) (Left "tracker absent") $ \tracker -> do
      phases <- mapM (readPhase root) PhaseIdentity.allPhaseIdentities
      pure (Right StatusSurface
        { surfaceTracker = mapMaybe trackerRow (zip [1 ..] (Text.lines tracker))
        , surfacePhaseLines = concat [lines' | (lines', _, _) <- phases]
        , surfaceSprints = concat [sprints | (_, sprints, _) <- phases]
        , surfaceReceipts = concat [receipts | (_, _, receipts) <- phases] }))
trackerRow :: (Int, Text) -> Maybe (Int, Int, Text)
trackerRow (number, line) = case map Text.strip (Text.splitOn "|" line) of
  ("" : ordinalText : _ : _ : _ : _ : status : _ : _)
    | not (Text.null ordinalText) && Text.all isDigit ordinalText ->
        Just (read (Text.unpack ordinalText), number, status)
  _ -> Nothing
readExistingSource :: FilePath -> a -> (Text -> IO a) -> IO a
readExistingSource path absent present = do
  exists <- doesFileExist path
  if exists then readSourceText path >>= present else pure absent
readPhase :: FilePath -> PhaseIdentity.PhaseIdentity -> IO ([(Int, Int, Text)], [(Int, Int, Int, Text, Text)], [(Int, Text)])
readPhase root row = readExistingSource (root </> PhaseIdentity.phaseIdentityPath row) ([], [], []) $ \contents -> do
      let ordinal = PhaseIdentity.phaseIdentityOrdinal row
          numbered = zip [1 ..] (Text.lines contents)
          statusBody = case dropWhile ((/= "## Phase Status") . snd) numbered of
            (_ : rest) -> filter (not . Text.null . Text.strip . snd) (takeWhile (not . ("## " `Text.isPrefixOf`) . snd) rest)
            [] -> []
          statusLine = [(ordinal, number, line) | (number, line) <- take 1 statusBody]
          receipt = [(ordinal, Text.strip digest) | (_, line) <- take 1 (drop 1 statusBody), Just digest <- [Text.stripPrefix receiptPrefix line]]
          sprints =
            [ (ordinal, sprint, number, heading, statusField)
            | (number, heading) <- numbered
            , Just sprint <- [sprintOrdinal ordinal heading]
            , let statusField = case [line | (n, line) <- numbered, n > number, "**Status**:" `Text.isPrefixOf` line] of
                    (line : _) -> line
                    [] -> ""
            ]
      pure (statusLine, sprints, receipt)
receiptPrefix :: Text
receiptPrefix = "**Receipt**: "
sprintOrdinal :: Int -> Text -> Maybe Int
sprintOrdinal ordinal heading = do
  rest <- Text.stripPrefix ("## Sprint " <> Text.pack (show ordinal) <> ".") heading
  let digits = Text.takeWhile isDigit rest
  if Text.null digits then Nothing else Just (read (Text.unpack digits))
recordedFrontier :: StatusSurface -> Maybe Status.StatusFrontier
recordedFrontier surface = do
  statuses <- mapM (\ordinal -> lookup ordinal [(phase, status) | (phase, _, status) <- surfaceTracker surface] >>= Status.parseTrackerStatus) PhaseIdentity.phaseOrdinals
  Status.recognizeStatusFrontier statuses
surfaceDigest :: StatusSurface -> Text
surfaceDigest surface =
  sha256Hex (renderTsv
    ([[Text.pack (show phase), "tracker", status] | (phase, _, status) <- surfaceTracker surface] <>
     [[Text.pack (show phase), "phase", line] | (phase, _, line) <- surfacePhaseLines surface] <>
     [[Text.pack (show phase), "sprint", Text.pack (show sprint), heading, status] | (phase, sprint, _, heading, status) <- surfaceSprints surface] <>
     [[Text.pack (show phase), "receipt", digest] | (phase, digest) <- surfaceReceipts surface]))
statusPrefixDigest :: Int -> StatusSurface -> Maybe Text
statusPrefixDigest ordinal surface
  | not (PhaseIdentity.isPhaseOrdinal ordinal && surfaceConsistent surface && ordinal `elem` map fst (surfaceReceipts surface)) = Nothing
  | otherwise = Just (surfaceDigest (StatusSurface (prefix (surfaceTracker surface)) (prefix (surfacePhaseLines surface))
      [row | row@(phase, _, _, _, _) <- surfaceSprints surface, phase <= ordinal]
      [row | row@(phase, _) <- surfaceReceipts surface, phase <= ordinal]))
 where prefix = filter (\(phase, _, _) -> phase <= ordinal)
-- Structural agreement only; this establishes no gate or receipt authority.
surfaceConsistent :: StatusSurface -> Bool
surfaceConsistent surface = case recordedFrontier surface of
  Nothing -> False
  Just frontier -> map (\(phase, _, _) -> phase) (surfaceTracker surface) == ordinals
    && map (\(phase, _, _) -> phase) (surfacePhaseLines surface) == ordinals
    && all (\(phase, _, line) -> line == Status.renderPhaseStatusLine (Status.phaseStatusAt frontier phase)) (surfacePhaseLines surface)
    && map fst (surfaceReceipts surface) == [phase | phase <- ordinals, Status.phaseStatusAt frontier phase == Status.Done]
    && all (\(_, digest) -> Text.length digest == 64 && Text.all (\c -> c >= '0' && c <= '9' || c >= 'a' && c <= 'f') digest) (surfaceReceipts surface)
    && all (\phase -> let rows = [sprint | (p, sprint, _, _, _) <- surfaceSprints surface, p == phase] in not (null rows) && rows == [1 .. length rows]) ordinals
    && all (\(phase, sprint, _, heading, status) -> let wanted = Status.sprintStatusAt frontier phase sprint in
      status == "**Status**: " <> Status.renderSprintStatus wanted && Status.renderStatusMarker wanted `Text.isSuffixOf` heading) (surfaceSprints surface)
 where ordinals = PhaseIdentity.phaseOrdinals
patchToFrontier :: FilePath -> Status.StatusFrontier -> Map.Map Int Text -> IO [(FilePath, Text)]
patchToFrontier root frontier receipts = do
  tracker <- readSourceText (root </> trackerPath)
  let tracker' = Text.unlines (map patchTrackerLine (Text.lines tracker))
  phases <- mapM patchPhase PhaseIdentity.allPhaseIdentities
  pure ([(trackerPath, tracker') | tracker' /= tracker] <> concat phases)
 where
  patchTrackerLine line = case trackerRow (0, line) of
    Just (phase, _, status) ->
      let cells = Text.splitOn "|" line
          expected = Status.renderTrackerStatus (Status.phaseStatusAt frontier phase)
       in if Text.strip status == expected then line else Text.intercalate "|" (take 6 cells <> [" " <> expected <> " "] <> drop 7 cells)
    Nothing -> line
  patchPhase row = readExistingSource (root </> PhaseIdentity.phaseIdentityPath row) [] $ \contents -> do
        let path = PhaseIdentity.phaseIdentityPath row
            ordinal = PhaseIdentity.phaseIdentityOrdinal row
            lines' = Text.lines contents
            statusIndex = case break (== "## Phase Status") lines' of
              (before, _ : rest) -> Just (length before + 1 + length (takeWhile (Text.null . Text.strip) rest))
              _ -> Nothing
            patched = withReceipt ordinal statusIndex (zipWith (patchPhaseLine ordinal statusIndex lines') [0 ..] lines')
            contents' = Text.unlines patched
        pure [(path, contents') | contents' /= contents]
  withReceipt ordinal statusIndex lines' = case statusIndex of
    Nothing -> lines'
    Just index ->
      let (before, rest) = splitAt (index + 1) lines'
          (existing, after) = case rest of
            (line : more) | receiptPrefix `Text.isPrefixOf` line -> ([line], more)
            _ -> ([], rest)
          wanted = case (Status.phaseStatusAt frontier ordinal, Map.lookup ordinal receipts) of
            (Status.Done, Just digest) -> [receiptPrefix <> digest]
            _ -> []
       in existing `seq` before <> wanted <> after
  patchPhaseLine ordinal statusIndex lines' index line
    | Just index == statusIndex = Status.renderPhaseStatusLine (Status.phaseStatusAt frontier ordinal)
    | Just sprint <- sprintOrdinal ordinal line =
        let marker = Status.renderStatusMarker (Status.sprintStatusAt frontier ordinal sprint)
            base = Text.stripEnd (Text.dropWhileEnd (`elem` ("🔄⏸️✅ " :: String)) line)
         in base <> " " <> marker
    | "**Status**:" `Text.isPrefixOf` line =
        case owningSprint ordinal (take index lines') of
          Just sprint -> "**Status**: " <> Status.renderSprintStatus (Status.sprintStatusAt frontier ordinal sprint)
          Nothing -> line
    | otherwise = line
  owningSprint ordinal previous = listToMaybe (mapMaybe (sprintOrdinal ordinal) (reverse previous))
type GenerationId = Text
newtype Store = Store {storeRoot :: FilePath} deriving (Eq, Show)
withResult :: IO (Either e a) -> (e -> IO b) -> (a -> IO b) -> IO b
withResult action failed next = action >>= either failed next
-- Run both observations before inspecting either result; the first failure wins.
withResults :: IO (Either e a) -> IO (Either e b) -> (e -> IO c) -> (a -> b -> IO c) -> IO c
withResults first second failed next = do
  left <- first
  right <- second
  either failed (uncurry next) ((,) <$> left <*> right)
attemptText :: Text -> IO a -> IO (Either Text a)
attemptText prefix action = either (Left . (prefix <>) . Text.pack . show) Right <$> tryIOError action
rollbackOnLeft :: IO () -> Either e a -> IO (Either e a)
rollbackOnLeft rollback result = either (\problem -> rollback >> pure (Left problem)) (pure . Right) result
generationDirectory :: Store -> GenerationId -> FilePath
generationDirectory store generation = storeRoot store </> ("generation-" <> Text.unpack (Text.take 16 generation))
verifierDigest :: IO Text
verifierDigest = sha256Bytes <$> (getExecutablePath >>= ByteString.readFile)
governanceDigest :: Text
governanceDigest = sha256Hex (Text.unlines [Text.pack (Decisions.frozenPath row) <> "\t" <> Decisions.frozenDigest row <> "\t" <> Decisions.renderDecisionId (Decisions.frozenDecision row) | row <- Decisions.frozenBaseline])
data SeedRecord = SeedRecord { seedGeneration :: GenerationId, seedEnteredBy :: Text, seedVerifierDigest :: Text, seedGovernanceDigest :: Text , seedStatusPostimage :: Text, seedTreeCommit :: Text, seedIssuedAt :: Text } deriving (Eq, Show)
data Receipt = Receipt { receiptPhase :: Int, receiptCapability :: Text, receiptGeneration :: GenerationId, receiptSpecDigest :: Text , receiptSpecRendered :: Text, receiptCandidateDigest :: Text, receiptKillTableDigest :: Text, receiptClosureDigest :: Text , receiptReproducible :: Text, receiptVerifierDigest :: Text, receiptGovernanceDigest :: Text, receiptStatusPostimage :: Text , receiptTreeCommit :: Text, receiptWitnesses :: [Text], receiptResetCause :: Maybe (Text, Text), receiptDemonstration :: Maybe Text , receiptIssuedAt :: Text, receiptAcceptedPrefix :: Maybe Text } deriving (Eq, Show)
renderFields :: [(Text, Text)] -> Text
renderFields fields = Text.unlines [key <> "\t" <> escape value | (key, value) <- fields]
 where
  escape = Text.replace "\t" "\\t" . Text.replace "\n" "\\n" . Text.replace "\\" "\\\\"
parseFields :: Text -> [(Text, Text)]
parseFields contents = [(key, Text.pack (unescape (Text.unpack (Text.intercalate "\t" rest)))) | line <- Text.lines contents, (key : rest) <- [Text.splitOn "\t" line]]
 where
  unescape ('\\' : 'n' : xs) = '\n' : unescape xs
  unescape ('\\' : 't' : xs) = '\t' : unescape xs
  unescape ('\\' : '\\' : xs) = '\\' : unescape xs
  unescape (x : xs) = x : unescape xs
  unescape [] = []
renderSeed :: SeedRecord -> Text
renderSeed seed = renderFields [ ("record", "amoebius-certification-generation.v2"), ("generation", seedGeneration seed), ("entered-by", seedEnteredBy seed), ("verifier-digest", seedVerifierDigest seed), ("governance-digest", seedGovernanceDigest seed), ("status-postimage", seedStatusPostimage seed), ("tree-commit", seedTreeCommit seed), ("issued-at", seedIssuedAt seed) ]
parseSeed :: Text -> Either Text SeedRecord
parseSeed contents = do
  let fields = parseFields contents
      field key = maybe (Left ("generation record lacks " <> key)) Right (lookup key fields)
  record <- field "record"
  if record /= "amoebius-certification-generation.v2" then Left ("unknown generation record: " <> record) else Right ()
  SeedRecord <$> field "generation" <*> field "entered-by" <*> field "verifier-digest" <*> field "governance-digest" <*> field "status-postimage" <*> field "tree-commit" <*> field "issued-at"
renderReceipt :: Receipt -> Text
renderReceipt receipt = renderFields ( [ ("record", "amoebius-phase-receipt.v2"), ("phase", Text.pack (show (receiptPhase receipt))), ("capability", receiptCapability receipt), ("generation", receiptGeneration receipt) , ("spec-digest", receiptSpecDigest receipt), ("spec", receiptSpecRendered receipt), ("candidate-digest", receiptCandidateDigest receipt), ("kill-table-digest", receiptKillTableDigest receipt) , ("closure-digest", receiptClosureDigest receipt), ("reproducible-digest", receiptReproducible receipt), ("verifier-digest", receiptVerifierDigest receipt), ("governance-digest", receiptGovernanceDigest receipt) , ("status-postimage", receiptStatusPostimage receipt), ("tree-commit", receiptTreeCommit receipt), ("issued-at", receiptIssuedAt receipt) ] <> maybe [] (\prefix -> [("accepted-prefix-digest", prefix)]) (receiptAcceptedPrefix receipt) <> [("witness", witness) | witness <- receiptWitnesses receipt] <> maybe [] (\(gap, productGap) -> [("reset-validator-gap", gap), ("reset-product-gap", productGap)]) (receiptResetCause receipt) <> maybe [] (\demo -> [("operator-demonstration", demo)]) (receiptDemonstration receipt) )
parseReceipt :: Text -> Either Text Receipt
parseReceipt contents = do
  let fields = parseFields contents
      field key = maybe (Left ("receipt lacks " <> key)) Right (lookup key fields)
  record <- field "record"
  if record /= "amoebius-phase-receipt.v2" then Left ("unknown receipt record: " <> record) else Right ()
  phaseText <- field "phase"
  phase <- case reads (Text.unpack phaseText) of [(value, "")] -> Right value; _ -> Left "receipt phase is not an ordinal"
  prefix <- case [value | ("accepted-prefix-digest", value) <- fields] of
    [] -> Right Nothing
    [value] | digestShape value -> Right (Just value)
    _ -> Left "receipt accepted-prefix digest is malformed or repeated"
  Receipt phase <$> field "capability" <*> field "generation" <*> field "spec-digest" <*> field "spec"
    <*> field "candidate-digest" <*> field "kill-table-digest" <*> field "closure-digest"
    <*> field "reproducible-digest" <*> field "verifier-digest" <*> field "governance-digest"
    <*> field "status-postimage" <*> field "tree-commit"
    <*> pure [value | ("witness", value) <- fields]
    <*> pure ((,) <$> lookup "reset-validator-gap" fields <*> lookup "reset-product-gap" fields)
    <*> pure (lookup "operator-demonstration" fields) <*> field "issued-at" <*> pure prefix
writeRecord :: FilePath -> Text -> IO (Either Text ())
writeRecord path payload = attemptText "record not written: " $ do
  let bytes = E.encodeUtf8 payload
  ByteString.writeFile path bytes
  ByteString.writeFile (path <> ".sha256") (E.encodeUtf8 (sha256Bytes bytes))
readRecord :: FilePath -> IO (Either Text Text)
readRecord path = withResult (attemptText "record unreadable: " ((,) <$> readSourceBytes path <*> readSourceBytes (path <> ".sha256"))) (pure . Left) $ \(payload, sidecar) ->
  pure $ case (E.decodeUtf8' payload, E.decodeUtf8' sidecar) of
    (Right value, Right digest) | digest == sha256Bytes payload -> Right value
    _ -> Left ("record digest or UTF-8 is invalid: " <> Text.pack path)
writeSeed :: Store -> SeedRecord -> IO (Either Text ())
writeSeed store seed = do
  let directory = generationDirectory store (seedGeneration seed)
  createDirectoryIfMissing True directory >> writeRecord (directory </> "generation.tsv") (renderSeed seed)
readSeed :: Store -> GenerationId -> IO (Either Text SeedRecord)
readSeed store generation = fmap (>>= parseSeed) (readRecord (generationDirectory store generation </> "generation.tsv"))
latestGeneration :: Store -> Text -> IO (Maybe SeedRecord)
latestGeneration store verifier = do
  exists <- doesDirectoryExist (storeRoot store)
  if not exists then pure Nothing else do
    names <- listDirectory (storeRoot store)
    directories <- sort <$> filterM (\name -> doesFileExist (storeRoot store </> name </> "generation.tsv")) [name | name <- names, "generation-" `Text.isPrefixOf` Text.pack name]
    seeds <- forM directories $ \name -> fmap (either (const Nothing) (either (const Nothing) Just . parseSeed)) (readRecord (storeRoot store </> name </> "generation.tsv"))
    pure (case [seed | Just seed <- seeds, seedVerifierDigest seed == verifier] of (seed : _) -> Just seed; [] -> Nothing)
latestUnique :: (a -> Text) -> [a] -> Either Text (Maybe a)
latestUnique _ [] = Right Nothing
latestUnique issued rows = case filter ((== maximum (map issued rows)) . issued) rows of
  [row] -> Right (Just row)
  _ -> Left "ArchiveLatestPublicationAmbiguous"
latestWholePostimage :: [Receipt] -> Either Text (Maybe Text)
latestWholePostimage = fmap (fmap receiptStatusPostimage) . latestUnique receiptIssuedAt
-- The five bounded evidence values are Haskell renderings, never executable inputs.
archiveEvidenceNames :: [FilePath]
archiveEvidenceNames = ["candidate.tsv", "kill-table.tsv", "outcome.tsv", "oracle-ledger.tsv", "observer.tsv"]
evidenceValue :: FilePath -> [(FilePath, Text)] -> Text
evidenceValue name rows = maybe "" id (lookup name rows)
digestShape :: Text -> Bool
digestShape value = Text.length value == 64 && Text.all (\c -> c >= '0' && c <= '9' || c >= 'a' && c <= 'f') value
candidateMatches :: Receipt -> Text -> Bool
candidateMatches receipt candidate = take 2 (Text.lines candidate) ==
  [ "candidate\tphase=" <> Text.pack (show (receiptPhase receipt)) <> "\tcapability=" <> receiptCapability receipt
  , "spec-digest\t" <> receiptSpecDigest receipt ]
bundleDigest :: Receipt -> [(FilePath, Text)] -> Text
bundleDigest receipt evidence = sha256Hex (Text.unlines (("receipt.tsv\t" <> sha256Hex (renderReceipt receipt)) : [Text.pack name <> "\t" <> sha256Hex body | (name, body) <- sort evidence]))
archiveName :: Receipt -> [(FilePath, Text)] -> FilePath
archiveName receipt evidence = "phase-" <> pad (receiptPhase receipt) <> "-" <> Text.unpack (receiptReproducible receipt) <> "-" <> Text.unpack (bundleDigest receipt evidence)
 where
  pad n = let s = show n in if length s < 2 then '0' : s else s
archivedBundlePath :: FilePath -> Receipt -> [(FilePath, Text)] -> FilePath
archivedBundlePath root receipt evidence = generationDirectory (Store root) (receiptGeneration receipt) </> "receipts" </> archiveName receipt evidence
readEvidence :: FilePath -> IO (Either Text Text)
readEvidence path = withResult (attemptText "archive evidence unreadable: " (readSourceBytes path)) (pure . Left) $ \bytes ->
  pure (either (const (Left ("archive evidence is not UTF-8: " <> Text.pack path))) Right (E.decodeUtf8' bytes))
hasSymlink :: [FilePath] -> IO Bool
hasSymlink paths = or <$> mapM (\path -> either (not . isDoesNotExistError) id <$> (try (pathIsSymbolicLink path) :: IO (Either IOException Bool))) paths
writeArchivedReceipt :: FilePath -> Receipt -> [(FilePath, Text)] -> IO (Either Text FilePath)
writeArchivedReceipt root receipt evidence
  | not (digestShape (receiptGeneration receipt) && digestShape (receiptReproducible receipt) && receiptGeneration receipt == receiptVerifierDigest receipt && receiptPhase receipt >= 0) = pure (Left "archive receipt identity is invalid")
  | not (digestShape (receiptStatusPostimage receipt) && maybe True digestShape (receiptAcceptedPrefix receipt)) = pure (Left "archive status postimage is not a SHA-256 digest")
  | sort (map fst evidence) /= sort archiveEvidenceNames = pure (Left "archive evidence names are incomplete or repeated")
  | any ((> 16 * 1024 * 1024) . ByteString.length . E.encodeUtf8) (renderReceipt receipt : map snd evidence) = pure (Left "archive record exceeds the 16 MiB per-record limit")
  | sha256Hex (evidenceValue "candidate.tsv" evidence) /= receiptCandidateDigest receipt || sha256Hex (evidenceValue "kill-table.tsv" evidence) /= receiptKillTableDigest receipt = pure (Left "archive evidence digest does not match receipt")
  | not (candidateMatches receipt (evidenceValue "candidate.tsv" evidence)) = pure (Left "archive candidate identity does not match receipt")
  | not (all (isValidationRecordPath . (archivedBundlePath validationRecordRoot receipt evidence </>)) ("receipt.tsv.sha256" : "receipt.tsv" : archiveEvidenceNames)) = pure (Left "archive path does not have the admitted phase and digest shape")
  | otherwise = do
      let target = archivedBundlePath root receipt evidence
          staging = target <> ".pending"
          generationPath = generationDirectory (Store root) (receiptGeneration receipt)
          receiptsPath = generationPath </> "receipts"
      rootFile <- doesFileExist root
      linked <- hasSymlink [root, generationPath, receiptsPath, target, staging]
      exists <- doesPathExist target
      pending <- doesPathExist staging
      earlier <- readArchivedBundles root (receiptGeneration receipt)
      let stale = either (const True) (any (\(old, _) -> receiptPhase old == receiptPhase receipt && receiptIssuedAt old >= receiptIssuedAt receipt)) earlier
      if rootFile then pure (Left "archive root is not a directory")
      else if linked then pure (Left "archive path contains a symbolic link")
      else if pending then pure (Left "archive has an unfinished pending bundle")
      else if not exists && stale then pure (Left "archive receipt issued-at is not newer than the existing phase bundle")
      else if exists then do
          prior <- readBundleWith hasSymlink target (receiptGeneration receipt)
          pure $ case prior of
            Right (old, rows) | old == receipt && sort rows == sort evidence -> Right target
            _ -> Left ("archive content address already exists with different or invalid evidence: " <> Text.pack target)
      else do
          withResult (attemptText "archive staging unavailable: " (createDirectoryIfMissing True receiptsPath >> createDirectory staging)) (pure . Left) $ \() -> do
              receiptWritten <- writeRecord (staging </> "receipt.tsv") (renderReceipt receipt)
              evidenceWritten <- attemptText "archive evidence not written: " (mapM_ (\(name, payload) -> ByteString.writeFile (staging </> name) (E.encodeUtf8 payload)) evidence)
              checked <- withResult (pure (receiptWritten >> evidenceWritten)) (pure . Left) $ \() -> do
                  savedReceipt <- readRecord (staging </> "receipt.tsv")
                  savedEvidence <- mapM (\(name, payload) -> fmap (fmap (== payload)) (readEvidence (staging </> name))) evidence
                  pure $ if savedReceipt == Right (renderReceipt receipt) && sequence savedEvidence == Right (replicate (length evidence) True) then Right () else Left "archive staging verification failed"
              published <- withResult (pure checked) (pure . Left) $ \() -> do
                  fmap (fmap (const target)) (attemptText "" (renameDirectory staging target))
              rollbackOnLeft (void (tryIOError (removePathForcibly staging))) published
readBundleWith :: ([FilePath] -> IO Bool) -> FilePath -> GenerationId -> IO (Either Text (Receipt, [(FilePath, Text)]))
readBundleWith queryLinks path generation = do
  pathLinked <- queryLinks [path]
  listed <- if pathLinked then pure (Left "archive bundle is a symbolic link") else attemptText "archive bundle unreadable: " (listDirectory path)
  withResult (pure listed) (pure . Left) $ \names ->
    if sort names /= sort ("receipt.tsv" : "receipt.tsv.sha256" : archiveEvidenceNames) then pure (Left ("archive bundle has missing or extra records: " <> Text.pack path))
    else do
          linked <- queryLinks (path : [path </> name | name <- names])
          if linked then pure (Left "archive bundle contains a symbolic link") else do
            sizes <- try (mapM (getFileSize . (path </>)) names) :: IO (Either IOException [Integer])
            if either (const True) (any (> 16 * 1024 * 1024)) sizes then pure (Left "archive record is unreadable or exceeds 16 MiB") else do
              receiptValue <- readRecord (path </> "receipt.tsv")
              values <- mapM (\name -> fmap (fmap ((,) name)) (readEvidence (path </> name))) archiveEvidenceNames
              pure $ do
                raw <- receiptValue
                evidence <- sequence values
                receipt <- parseReceipt raw
                if renderReceipt receipt /= raw || receiptGeneration receipt /= generation || receiptVerifierDigest receipt /= generation || not (digestShape generation && digestShape (receiptReproducible receipt) && digestShape (receiptStatusPostimage receipt)) || archiveName receipt evidence /= takeFileName path || not (isValidationRecordPath (archivedBundlePath validationRecordRoot receipt evidence </> "receipt.tsv"))
                  then Left ("archive receipt identity or canonical form is invalid: " <> Text.pack path)
                  else if sha256Hex (evidenceValue "candidate.tsv" evidence) /= receiptCandidateDigest receipt || sha256Hex (evidenceValue "kill-table.tsv" evidence) /= receiptKillTableDigest receipt || not (candidateMatches receipt (evidenceValue "candidate.tsv" evidence))
                    then Left ("archive evidence digest does not match receipt: " <> Text.pack path)
                    else Right (receipt, evidence)
readArchivedBundles :: FilePath -> GenerationId -> IO (Either Text [(Receipt, FilePath)])
readArchivedBundles = readArchivedBundlesWith hasSymlink
readArchivedBundlesWith :: ([FilePath] -> IO Bool) -> FilePath -> GenerationId -> IO (Either Text [(Receipt, FilePath)])
readArchivedBundlesWith queryLinks root generation
  | not (digestShape generation) = pure (Left "archive generation identity is invalid")
  | otherwise = do
      let parent = generationDirectory (Store root) generation
          directory = parent </> "receipts"
      linked <- queryLinks [root, parent, directory]
      exists <- doesDirectoryExist directory
      if linked then pure (Left "archive path contains a symbolic link")
      else if not exists then do
          generationExists <- doesDirectoryExist parent
          pure (if generationExists then Left "archive generation has no receipts directory" else Right [])
      else do
          withResult (attemptText "archive receipts unreadable: " (listDirectory directory)) (pure . Left) $ \names ->
            fmap sequence (mapM (\name -> fmap (fmap (\(receipt, _) -> (receipt, directory </> name))) (readBundleWith queryLinks (directory </> name) generation)) (sort names))
-- Select the latest unique bundle per phase before applying voids, so a red
-- replay cannot fall back to an older bundle with the same receipt digest.
readCurrentArchivedBundles :: FilePath -> GenerationId -> IO (Either Text [(Receipt, FilePath)])
readCurrentArchivedBundles root generation = withResults
  (readArchivedBundles root generation) (readReplayVoids root generation) (pure . Left) $ \rows targets -> pure $ do
    newest <- mapM (\phase -> either (const (Left "archive has tied latest bundles for a phase")) Right (latestUnique (receiptIssuedAt . fst) (filter ((== phase) . receiptPhase . fst) rows))) (nub (map (receiptPhase . fst) rows))
    Right [(receipt, path) | Just (receipt, path) <- newest, path `notElem` targets]
-- A red replay leaves an immutable content-addressed revocation of the exact
-- bundle it invalidated. Green replay publishes a different bundle.
writeReplayVoid :: FilePath -> Receipt -> FilePath -> Text -> Text -> Text -> IO (Either Text FilePath)
writeReplayVoid root receipt bundle reason failure issued = do
  let generation = receiptGeneration receipt
      target = validationRecordRoot </> makeRelative root bundle
      bundleKey = last (Text.splitOn "-" (Text.pack (takeFileName bundle)))
      body = Text.unlines ["record\tamoebius-replay-void.v1", "target\t" <> Text.pack target
        , "phase\t" <> Text.pack (show (receiptPhase receipt)), "reproducible-digest\t" <> receiptReproducible receipt
        , "verifier-digest\t" <> generation, "governance-digest\t" <> receiptGovernanceDigest receipt
        , "failure-digest\t" <> failure, "reason\t" <> reason, "issued-at\t" <> issued]
      directory = generationDirectory (Store root) generation </> "voids"
      name = "phase-" <> pad (receiptPhase receipt) <> "-" <> Text.unpack bundleKey <> "-" <> Text.unpack (sha256Hex body) <> ".tsv"
      path = directory </> name
      pending = path <> ".pending"
  valid <- readBundleWith hasSymlink bundle generation
  linked <- hasSymlink [root, directory, path, pending]
  exists <- doesPathExist path
  if either (const True) ((/= receipt) . fst) valid || not (digestShape failure) || reason `notElem` ["gate-red", "runner-refusal"]
    then pure (Left "void target or failure identity is invalid")
  else if linked then pure (Left "void path contains a symbolic link")
  else if exists then do checked <- readReplayVoid root path; pure (if checked == Right bundle then Right path else Left "void content address conflicts")
  else do
    fmap (fmap (const path)) (attemptText "void record not written: " (createDirectoryIfMissing True directory >> ByteString.writeFile pending (E.encodeUtf8 body) >> renameFile pending path))
 where pad n = let value = show n in if length value < 2 then '0' : value else value
readReplayVoid :: FilePath -> FilePath -> IO (Either Text FilePath)
readReplayVoid root path = do
  linked <- hasSymlink [path]
  sized <- try (getFileSize path) :: IO (Either IOException Integer)
  if linked || either (const True) (> 16 * 1024 * 1024) sized then pure (Left "void record is linked, unreadable, or oversized") else do
    withResult (readEvidence path) (pure . Left) $ \body -> case traverse pair (Text.lines body) of
        Just fields | map fst fields == ["record", "target", "phase", "reproducible-digest", "verifier-digest", "governance-digest", "failure-digest", "reason", "issued-at"] -> do
          let field key = maybe "" id (lookup key fields)
              generation = field "verifier-digest"
              target = Text.unpack (field "target")
              bundle = root </> makeRelative validationRecordRoot target
              bundleKey = last (Text.splitOn "-" (Text.pack (takeFileName bundle)))
              name = "phase-" <> pad (field "phase") <> "-" <> bundleKey <> "-" <> sha256Hex body <> ".tsv"
          found <- if isValidationRecordPath (target </> "receipt.tsv") then readBundleWith hasSymlink bundle generation else pure (Left "void target path is invalid")
          pure $ case found of
            Right (receipt, _) | field "record" == "amoebius-replay-void.v1" && field "target" == Text.pack (validationRecordRoot </> makeRelative root bundle)
              && digestShape generation && takeFileName (takeDirectory (takeDirectory path)) == "generation-" <> Text.unpack (Text.take 16 generation)
              && field "phase" == Text.pack (show (receiptPhase receipt)) && field "reproducible-digest" == receiptReproducible receipt
              && field "verifier-digest" == generation && field "governance-digest" == receiptGovernanceDigest receipt
              && digestShape (field "failure-digest") && field "reason" `elem` ["gate-red", "runner-refusal"]
              && Text.pack (takeFileName path) == name && body == Text.unlines [key <> "\t" <> value | (key, value) <- fields] -> Right bundle
            _ -> Left ("void record identity or target is invalid: " <> Text.pack path)
        _ -> pure (Left "void record fields are not canonical")
 where
  pair line = case Text.splitOn "\t" line of [key, value] -> Just (key, value); _ -> Nothing
  pad value = if Text.length value < 2 then "0" <> value else value
readReplayVoids :: FilePath -> GenerationId -> IO (Either Text [FilePath])
readReplayVoids root generation = do
  let directory = generationDirectory (Store root) generation </> "voids"
  linked <- hasSymlink [directory]
  exists <- doesDirectoryExist directory
  if linked then pure (Left "void directory is a symbolic link") else if not exists then pure (Right []) else do
    withResult (attemptText "void directory unreadable: " (listDirectory directory)) (pure . Left) $ \files ->
      fmap sequence (mapM (readReplayVoid root . (directory </>)) files)
auditArchivedInventory :: FilePath -> IO (Either Text (Text, [(Receipt, FilePath)]))
auditArchivedInventory repository = do
  absolute <- makeAbsolute repository
  changed <- observe repository "git" ["-c", "safe.directory=" <> absolute, "diff", "--no-renames", "--name-only", "--diff-filter=MDRT", "HEAD", "--", validationRecordRoot]
  if runExit changed /= ExitSuccess then pure (Left "archive Git inventory unavailable") else
    if not (Text.null (Text.strip (runStdout changed))) then pure (Left "committed archive was modified or deleted") else do
      let root = repository </> validationRecordRoot
      linked <- hasSymlink [root]
      exists <- doesPathExist root
      if linked then pure (Left "archive root is a symbolic link")
      else if not exists then pure (Right (sha256Hex "", []))
      else do
        withResult (sourceAttempt (map (root </>) <$> walkFilesUnder root AuditArchive "")) (pure . Left) $ \files -> case filter (not . isValidationRecordPath) (map (makeRelative repository) files) of
            (bad : _) -> pure (Left ("archive path is not admitted: " <> Text.pack bad))
            [] -> do
              withResult (sequence <$> mapM checkBundle (nub (sort [takeDirectory file | file <- files, takeFileName (takeDirectory (takeDirectory file)) == "receipts"]))) (pure . Left) $ \checked ->
                withResult (sequence <$> mapM (readReplayVoid root) [file | file <- files, takeFileName (takeDirectory file) == "voids"]) (pure . Left) $ \_ -> do
                      fmap (fmap (\bodies -> (sha256Hex (Text.unlines (zipWith (\path body -> Text.pack (makeRelative repository path) <> "\t" <> sha256Bytes body) (sort files) bodies)), checked))) (attemptText "" (mapM readSourceBytes (sort files)))
 where
  checkBundle path = withResult ((>>= parseReceipt) <$> readRecord (path </> "receipt.tsv")) (pure . Left) $ \receipt ->
      if takeFileName (takeDirectory (takeDirectory path)) /= "generation-" <> Text.unpack (Text.take 16 (receiptGeneration receipt)) then pure (Left "archive generation directory and receipt disagree")
      else fmap (fmap (\(accepted, _) -> (accepted, path))) (readBundleWith hasSymlink path (receiptGeneration receipt))
-- Accepted observations only tighten the ratchet, across generations, resets, and voids.
archivedKernelCap :: FilePath -> IO (Either Text (Maybe Int))
archivedKernelCap repository = withResult (auditArchivedInventory repository) (pure . Left) $ \(_, records) -> do
      counts <- forM [(receipt, path) | (receipt, path) <- records, receiptResetCause receipt == Nothing, receiptDemonstration receipt == Nothing] $ \(receipt, path) -> do
        checked <- readBundleWith hasSymlink path (receiptGeneration receipt)
        pure $ do
          (observed, evidence) <- checked
          if observed /= receipt then Left "archive changed while deriving kernel ratchet" else Right ()
          let candidate = evidenceValue "candidate.tsv" evidence
          case [value | line <- Text.lines candidate, ["observation", "Legacy closure", "hygiene.kernel-lines", value] <- [Text.splitOn "\t" line]] of
            [value] | [(count, "")] <- (reads (Text.unpack value) :: [(Integer, String)]), count > 0, count <= toInteger kernelBudget, Text.pack (show count) == value -> Right (fromInteger count)
            _ -> Left "accepted kernel observation is absent, repeated, or invalid"
      pure ((\values -> case values of [] -> Nothing; _ -> Just (minimum values)) <$> sequence counts)
data RunnerConfig = RunnerConfig { runnerRoot :: FilePath, runnerRunRoot :: FilePath, runnerPhase :: Int, runnerCabal :: FilePath , runnerLastAcceptedKernelLines :: Maybe Int, runnerDocCheckCap :: Int , runnerHygienePreflight :: Bool, runnerPredecessorDigest :: Maybe Text, runnerMutantLimit :: Maybe Int , runnerCompiler :: Maybe FilePath, runnerPredecessorGate :: Maybe PassedGate } deriving (Eq, Show)
defaultRunnerConfig :: FilePath -> Int -> RunnerConfig
defaultRunnerConfig root phase = RunnerConfig { runnerRoot = root, runnerRunRoot = root </> ".build" </> "runs" </> ("phase-" <> pad phase) , runnerPhase = phase, runnerCabal = "cabal" , runnerLastAcceptedKernelLines = Nothing, runnerDocCheckCap = 7000, runnerHygienePreflight = True , runnerPredecessorDigest = Nothing, runnerMutantLimit = Nothing, runnerCompiler = Nothing, runnerPredecessorGate = Nothing }
 where pad n = let s = show n in if length s < 2 then '0' : s else s
data RunnerRefusal = SpecRefused [SpecProblem] | PhaseSpecMismatch [Text] | HygieneRefused HygieneReport | HardwareBeforeBarrier GateSubstrate | RunRootNotFresh FilePath | RunRootOutsideFrame FilePath | ProductBinaryUnavailable Text | KernelRatchetUnavailable Text | LegacyInventoryUnavailable Int | LegacyAnalyzersUnavailable [Legacy.LegacyId] | SourceCaptureRefused Text | SeedProtocolInterrupted FilePath SeedOutcome (Either Text ()) | PredecessorGateUnavailable deriving (Eq, Show)
instance Exception RunnerRefusal
renderRefusal :: RunnerRefusal -> Text
renderRefusal refusal = case refusal of {SpecRefused problems -> Text.intercalate "; " (map renderSpecProblem problems); PhaseSpecMismatch problems -> Text.intercalate "; " problems; HygieneRefused report -> Text.intercalate "; " (hygieneProblems report); HardwareBeforeBarrier substrate -> "HARDWARE-BEFORE-BARRIER: " <> renderSubstrate substrate; RunRootNotFresh path -> "RUN-ROOT-NOT-FRESH: " <> Text.pack path; RunRootOutsideFrame path -> "RUN-ROOT-OUTSIDE-FRAME: " <> Text.pack path; ProductBinaryUnavailable detail -> "PRODUCT-BINARY-UNAVAILABLE: " <> detail; KernelRatchetUnavailable detail -> "KERNEL-RATCHET-UNAVAILABLE: " <> detail; LegacyInventoryUnavailable phase -> "LEGACY-INVENTORY-UNAVAILABLE: unknown phase " <> showText phase; LegacyAnalyzersUnavailable identifiers -> "LEGACY-ANALYZER-UNAVAILABLE: " <> Text.intercalate "," (map Legacy.renderLegacyId identifiers); SourceCaptureRefused detail -> "SOURCE-CAPTURE-UNAVAILABLE: " <> detail; SeedProtocolInterrupted root _ retained -> "SEED-PROCESS-UNAVAILABLE: owned root retained: " <> Text.pack root <> "; prefix-write=" <> showText retained; PredecessorGateUnavailable -> "PREDECESSOR-GATE-UNAVAILABLE: an exact-source immediate-predecessor pass is required"}
-- Integrated analyzer/custody closure remains required; component counts supply no authority.
legacyAnalyzerGaps :: Int -> [Legacy.LegacyId]
legacyAnalyzerGaps phase = [identifier | requirement <- Legacy.legacyRequirements, let identifier = Legacy.legacyRequirementId requirement, Just owner <- [Legacy.legacyOwnerOrdinal identifier], owner <= phase, not (legacyQualificationSupported requirement)]
data PassedGate = PassedGate Int Text LegacyCollection deriving (Eq, Show)
predecessorMatches :: RunnerConfig -> CapturedSource -> Bool
predecessorMatches config captured = runnerPhase config == PhaseIdentity.phaseDomainLowerOrdinal || (isJust (runnerPredecessorDigest config) && case runnerPredecessorGate config of Just (PassedGate phase source _) -> PhaseIdentity.predecessorOrdinal (runnerPhase config) == Just phase && source == capturedSourceDigest captured; Nothing -> False)
data GateOutcome = GateOutcome { outcomeCandidate :: Candidate, outcomeHygiene :: HygieneReport , outcomeKillTable :: KillTable, outcomeRuns :: [ObservedRun], outcomePassed :: Maybe PassedGate } deriving (Eq, Show)
specDigest :: GateSpec -> Text
specDigest = sha256Hex . renderGateSpec
runGate :: RunnerConfig -> GateSpec -> IO (Either RunnerRefusal GateOutcome)
runGate config spec = either (Left . SourceCaptureRefused) id <$> sourceAttempt
  (withResult (verifySpec (runnerRoot config) spec) (pure . Left . SpecRefused) $ \vspec -> do
    hygiene <- hygieneRow (runnerRoot config) (runnerLastAcceptedKernelLines config) (runnerDocCheckCap config)
    runRootExists <- doesPathExist (runnerRunRoot config)
    frameAllowed <- runRootWithinFrame (runnerRoot config) (runnerRunRoot config)
    let preflight =
          [LegacyInventoryUnavailable (runnerPhase config) | not (PhaseIdentity.isPhaseOrdinal (runnerPhase config))]
            <> [HygieneRefused hygiene | runnerHygienePreflight config, not (hygieneGreen hygiene)]
            <> [RunRootNotFresh (runnerRunRoot config) | runRootExists]
            <> [PhaseSpecMismatch problems | Left problems <- [bindPhaseSpec registeredSpecInputs (runnerPhase config) spec]]
            <> [RunRootOutsideFrame (runnerRunRoot config) | not frameAllowed]
            <> [LegacyAnalyzersUnavailable absent | let absent = legacyAnalyzerGaps (runnerPhase config), not (null absent)]
            <> [HardwareBeforeBarrier (gateSubstrate spec) | gateRole spec == HardwareGate, isNothing (runnerPredecessorDigest config)]
    case preflight of
      (refusal : _) -> pure (Left refusal)
      [] -> captureSource (runnerRoot config) >>= either (pure . Left . SourceCaptureRefused) (execute config spec vspec hygiene))
execute :: RunnerConfig -> GateSpec -> VerifiedSpec -> HygieneReport -> CapturedSource -> IO (Either RunnerRefusal GateOutcome)
execute config _ _ _ source | not (predecessorMatches config source) = pure (Left PredecessorGateUnavailable)
execute config spec _ _ openingSource = do
  runRoot <- makeAbsolute (runnerRunRoot config)
  withResult (materializeSource openingSource runRoot) (pure . Left . SourceCaptureRefused) $ \root -> do
    scope <- NativeScope root openingSource <$> newIORef [] <*> newIORef []
    completed <- try $ (do
      verified <- verifySpec root spec
      hygiene <- hygieneRow root (runnerLastAcceptedKernelLines config) (runnerDocCheckCap config)
      withResult (pure verified) (pure . Left . SpecRefused) $ \vspec ->
        if not (hygieneGreen hygiene) then pure (Left (HygieneRefused hygiene))
        else executeCopy scope config {runnerRoot = root, runnerRunRoot = root </> ".build/candidate"} spec vspec hygiene openingSource (runnerRoot config)) `catch` (pure . Left)
    case completed of
      Left stopped -> finishNativeStop stopped
      Right result -> case result of
        Left (SeedProtocolInterrupted _ stopped _) -> do
          retained <- sourceAttempt (TextIO.writeFile (root </> ".build/candidate/seed-interrupted.data") (showText (renderSeedOutcome stopped)))
          pure (Left (SeedProtocolInterrupted root stopped retained))
        _ -> do
          removePathForcibly root
          residue <- doesPathExist root
          pure (if residue then Left (SourceCaptureRefused "owned run root remains after cleanup") else fmap (\outcome -> outcome {outcomeCandidate = (outcomeCandidate outcome) {candidateRows = [if rowCategory row == Cleanroom then row {rowObservations = rowObservations row <> [("cleanroom.root-absent","True")]} else row | row <- candidateRows (outcomeCandidate outcome)]}}) result)
executeCopy :: NativeScope -> RunnerConfig -> GateSpec -> VerifiedSpec -> HygieneReport -> CapturedSource -> FilePath -> IO (Either RunnerRefusal GateOutcome)
executeCopy scope config spec vspec hygiene openingSource liveRoot = do
  let root = runnerRoot config
      runRoot = runnerRunRoot config
      digest = specDigest spec
  createDirectoryIfMissing True runRoot
  let opening = capturedSourceDigest openingSource
      challengeSeed = sha256Hex (digest <> "\n" <> Text.pack runRoot <> "\n" <> opening)
  nonce@(Nonce nonceText) <- freshNonce runRoot challengeSeed
  graph <- either (const Nothing) Just <$> loadPackageGraph root
  own <- collectLegacy liveRoot (runRoot </> "legacy") (runnerPhase config) (Just (runnerCabal config)) (runnerCompiler config) openingSource
  let legacy = maybe own (\(PassedGate _ _ inherited) -> inheritLegacyCollection openingSource inherited own) (runnerPredecessorGate config)
  (table, matrixControl, mutantRuns) <- maybe (mutantMatrix scope config spec vspec graph digest openingSource) (const (pure (killTable [], (parseLedger Nothing "", Right (), True), []))) (gateSeed spec)
  seed <- traverse (const (runCapturedSeedProtocol ((defaultSeedProtocol root (runRoot </> "seed-protocol")) {protocolCompiler = runnerCompiler config}) openingSource challengeSeed)) (gateSeed spec)
  forM_ seed $ \stopped -> when (seedInterrupted stopped) (throwIO (SeedProtocolInterrupted root stopped (Left "not attempted")))
  documentation <- traverse (const (seedDocumentation root (runRoot </> "docs") (runRoot </> "clean" </> "suite"))) (gateSeed spec)
  (custodyRuns, custody) <- maybe (pure ([], parseLedger (Just ExitSuccess) "")) (\seedSpec -> suiteAndOracle scope config openingSource root (CabalTarget "runner-suite") (OracleExecutable "oracle-runner") False (seedCustodyProbes seedSpec) (runRoot </> "custody")) (gateSeed spec)
  -- The shipped binary runs before the clean suite, inside its directory, so the independent oracle can judge what it wrote.
  let binaryRoot = runRoot </> "clean" </> "suite" </> "binary"
  (binaryBuilds, built, wireOpening) <- case gateBinaryFact spec of
    Nothing -> pure ([], Right Nothing, Nothing)
    Just _ -> do
      (preparation, ready) <- prepareNativeWireTool scope root (runnerCabal config) (runnerCompiler config)
      (runs, result) <- case ready of {Left problem -> pure ([],Left problem); Right _ -> buildNativeTargetWith "exe:amoebius" (ownedCabal scope root (runnerCabal config) (runnerCompiler config))}
      pure (preparation <> runs, fmap Just result, either (const Nothing) Just ready)
  binary <- case (gateBinaryFact spec, built) of
    (Just fact, Right (Just binaryPath)) -> do { before <- productImageBinding scope root binaryPath "product-before"; result <- runBinaryFact scope (runnerCabal config) (runnerCompiler config) openingSource root binaryRoot binaryPath fact nonce; after <- productImageBinding scope root binaryPath "product-after"; withNativeScope scope (unless (before == after) (fail "ProductImageOrPlanChanged")); pure (Just result) }
    _ -> pure Nothing
  spine <- traverse (runSpineFact binaryRoot) (gateSpineFact spec)
  (cleanRuns, clean) <- suiteAndOracle scope config openingSource root (gateSuite spec) (gateOracle spec) (isJust (gateBinaryFact spec)) (requiredSuiteRows spec) (runRoot </> "clean")
  forM_ wireOpening (verifyWireGenerated scope root "wire-closing")
  let ledger = if isNothing (gateSeed spec) then clean else mergeCompletionLedgers clean custody
  nativeEvidence <- nativeScopeEvidence scope
  closingSource <- captureSource liveRoot
  unchangedCopy <- verifySourceCopy openingSource root
  case (built, unchangedCopy >> closingSource) of
    (Left problem, _) -> pure (Left (ProductBinaryUnavailable problem))
    (_, Left detail) -> pure (Left (SourceCaptureRefused detail))
    (_, Right source) -> do
      let closing = capturedSourceDigest source
          productClosure = maybe Set.empty (\g -> maybe Set.empty id (executableClosure g "amoebius")) graph
          seedRuns = maybe [] (concatMap attemptRuns . seedAttempts) seed
          allRuns = capturedSourceRuns openingSource <> legacyCollectionRuns legacy <> seedRuns <> mutantRuns <> custodyRuns <> binaryBuilds <> maybe [] binaryRuns binary <> cleanRuns <> capturedSourceRuns source
          chain = foldl chainDigest challengeSeed allRuns
          captured = capture config spec vspec hygiene digest nonceText chain (opening, closing) table matrixControl ledger binary spine allRuns seed documentation productClosure legacy openingSource nativeEvidence
          candidate = captured {candidateReproducibleCore = reproducibleCore digest captured ledger table}
      mapM_ (\(file, body) -> TextIO.writeFile (runRoot </> file) body) [("candidate.tsv", renderCandidate candidate), ("kill-table.tsv", Text.unlines (renderKillTable table)), ("outcome.tsv", Text.unlines ["green\t" <> Text.pack (show (candidateGreen candidate)), "spec-digest\t" <> digest, "chain\t" <> chain, "reproducible-core\t" <> candidateReproducibleCore candidate, "capability\t" <> gateCapability spec, "claim\t" <> gateClaim spec])]
      pure (Right GateOutcome {outcomeCandidate = candidate, outcomeHygiene = hygiene, outcomeKillTable = table, outcomeRuns = allRuns, outcomePassed = if candidateGreen candidate then Just (PassedGate (runnerPhase config) opening legacy) else Nothing})
reproducibleCore :: Text -> Candidate -> Ledger -> KillTable -> Text
reproducibleCore digest candidate ledger table =
  sha256Hex (renderTsv
    ([ ["spec", digest] ]
      <> [[renderGateCategory (rowCategory row), renderVerdict (rowVerdict row)] | row <- candidateRows candidate]
      <> [["ledger-exit", Text.pack (show (ledgerExit ledger))], ["ledger-valid", Text.pack (show (ledgerValid ledger))]]
      <> sort [["ledger-row", name, verdict] | (name, verdict, _) <- ledgerRows ledger]
      <> [[locusModule locus, Text.pack (locusFile locus) <> ":" <> Text.pack (show (locusLine locus)), renderOperator (locusOperator locus), renderMutantOutcome (const "") outcome]
          | (locus, _, outcome) <- killRows table]))
data DocumentationOutcome = DocumentationOutcome { documentationFindings :: [Text], documentationNegatives :: [(Text, Bool)] } deriving (Eq, Show)
documentationGreen :: DocumentationOutcome -> Bool
documentationGreen outcome = null (documentationFindings outcome) && not (null (documentationNegatives outcome)) && all snd (documentationNegatives outcome)
seedDocumentation :: FilePath -> FilePath -> FilePath -> IO DocumentationOutcome
seedDocumentation root docsRoot suiteDir = do
  corpus <- either (fail . Text.unpack . Text.unlines) (\blocks -> checkTree blocks root) (compiledBlocks registeredSpecInputs)
  (documents, _, _) <- discoverDocuments root
  negatives <- forM negativeCatalogue $ \negative -> do
    let target = docsRoot </> "negatives" </> Text.unpack (negativeName negative)
    case renderNegative negative documents of
      Left _ -> pure (negative, [], False)
      Right rendered -> do
        writeCorpus target rendered
        result <- either (fail . Text.unpack . Text.unlines) (\blocks -> checkTree blocks target) (compiledBlocks registeredSpecInputs)
        let codes = map findingCode (checkFindings result)
        pure (negative, codes, negativeCode negative `elem` codes)
  createDirectoryIfMissing True suiteDir
  TextIO.writeFile (suiteDir </> "findings.tsv") (renderTsv
    ([ ["finding", findingCode item, Text.pack (findingSubject item), findingDetail item] | item <- checkFindings corpus] <>
     [["observation", observationKey item, observationValue item] | item <- checkObservations corpus]))
  TextIO.writeFile (suiteDir </> "negatives.tsv") (renderTsv
    [[negativeName negative, negativeCode negative, Text.intercalate "," codes, if named then "named-finding-observed" else "named-finding-absent"] | (negative, codes, named) <- negatives])
  pure DocumentationOutcome
      { documentationFindings = [findingCode item <> " " <> Text.pack (findingSubject item) | item <- checkFindings corpus]
      , documentationNegatives = [(negativeName negative, named) | (negative, _, named) <- negatives]
      }
data Ledger = Ledger { ledgerExit :: Maybe ExitCode, ledgerRows :: [(Text, Text, Text)], ledgerDigest :: Text, ledgerValid :: Bool, ledgerImages :: [(FilePath, [(FilePath, ByteString.ByteString, ByteString.ByteString)])], ledgerContexts :: [((Text,FilePath,FilePath,Maybe FilePath),[Text],Text)] } deriving (Eq, Show)
ledgerGreen :: Ledger -> Bool
ledgerGreen ledger = ledgerValid ledger && ledgerExit ledger == Just ExitSuccess && all (\(_, verdict, _) -> verdict == "green") (ledgerRows ledger)
ledgerRedRows :: Ledger -> [Text]
ledgerRedRows ledger = [name | (name, verdict, _) <- ledgerRows ledger, verdict /= "green"]
parseLedger :: Maybe ExitCode -> Text -> Ledger
parseLedger exit output = Ledger exit rows (sha256Hex output) valid [] []
 where
  fields = map (Text.splitOn "\t") (Text.lines output)
  rows = [(name, verdict, Text.intercalate "\t" observed) | name : verdict : observed@(_ : _) <- fields]
  valid = not (null rows) && length rows == length fields && length rows == Set.size (Set.fromList [name | (name, _, _) <- rows])
    && all (\(name, verdict, _) -> not (Text.null name) && verdict `elem` ["green", "red"]) rows
suiteLedger :: [Text] -> ObservedRun -> ObservedRun -> ObservedRun -> Ledger
suiteLedger required subject oracle probe = let parsed = parseLedger (Just (runExit oracle)) (runStdout oracle) in parsed {ledgerValid = ledgerValid parsed && runExit subject == ExitSuccess && all (isNothing . runSpawnFailure) [subject,oracle,probe] && runExit probe /= ExitSuccess && all (`elem` map (\(name,_,_) -> name) (ledgerRows parsed)) required}
ownedCabal :: NativeScope -> FilePath -> FilePath -> Maybe FilePath -> [String] -> IO (ObservedRun,Bool)
ownedCabal scope@(NativeScope _ _ calls _) root cabal compiler args = do { observed <- observeOwnedNative scope (NativeCabalIntent root cabal compiler args); retained <- readIORef calls; let { bound = case retained of {call:_ -> case [paths | WindowRequestsMatched paths<-nativeWindowObservations call] of {[[_]] -> True; _ -> False}; [] -> False} }; unless bound (recordNativeScope scope (CompletionFailure (NativeWindowRequestUnavailable args))); pure (observed,bound) }
suiteAndOracle :: NativeScope -> RunnerConfig -> CapturedSource -> FilePath -> CabalTarget -> OracleExecutable -> Bool -> [Text] -> FilePath -> IO ([ObservedRun], Ledger)
suiteAndOracle scope config source treeRoot suiteTarget oracleTarget withBinary required workRoot = withNativeScope scope $ do
  let suiteDir = workRoot </> "suite"; completion = workRoot </> "completion"; empty = completion </> "oracle-empty"
      suite = "amoebius:test:" <> Text.unpack (cabalTargetName suiteTarget); oracle = "amoebius:test:" <> Text.unpack (oracleExecutableName oracleTarget)
      native = ownedCabal scope treeRoot (runnerCabal config) (runnerCompiler config)
      direct image args = observeOwnedNative scope (NativeDirectIntent treeRoot image args)
      profile = lookup (cabalTargetName suiteTarget,oracleExecutableName oracleTarget) [(("layout-suite","oracle-layout"),let name=if withBinary then "layout.gate.v1" else "layout.full.v1" in (name,"paths.txt",["--oracle-profile",Text.unpack name])),(("plan-decisions-suite","oracle-doc"),("doc.full.v1","plan-decisions.tsv",[])),(("runner-suite","oracle-runner"),("runner.full.v2","runner.tsv",[])),(("toolchain-suite","oracle-toolchain"),let name=if withBinary then "toolchain.gate.v1" else "toolchain.full.v1" in (name,"toolchain.tsv",["--oracle-profile",Text.unpack name])),(("wire-preparation","oracle-dsl"),("wire.prepare.v1","current/PulsarApi.proto",["--oracle-profile","wire.prepare.v1"])),(("spine-suite","oracle-dsl"),let name=if withBinary then "spine.gate.v1" else "spine.full.v1" in (name,"complete.marker",["--oracle-profile",Text.unpack name,"--builddir",".build/dist-native","--cabal",runnerCabal config] <> maybe [] (\compiler -> ["--ghc",compiler]) (runnerCompiler config)))]
      invalid runs = pure (runs,parseLedger Nothing "")
  recordNativeScope scope (CompletionFact "request" (showText (capturedSourceDigest source,treeRoot,workRoot,runnerCabal config,runnerCompiler config,suiteTarget,oracleTarget,fmap (\(name,_,_)->name) profile)))
  opening <- verifySourceCopy source treeRoot
  recordNativeScope scope (CompletionFact "source-opening" (showText opening))
  case profile of
    Nothing -> recordNativeScope scope (CompletionFailure FullProfileUnsupported) >> invalid []
    Just (full,primaryName,normalArguments) | opening /= Right () -> invalid []
              | otherwise -> do
      physical <- canonicalizePath workRoot
      recordNativeScope scope (CompletionFact "owner-resolution" (showText (workRoot,physical)))
      unless (imagePathsAllowed treeRoot [workRoot] [physical] && take 1 (splitDirectories (makeRelative treeRoot workRoot)) == [".build"]) (fail "CompletionOwnerUnconfined")
      createDirectoryIfMissing True suiteDir
      createDirectory completion
      createDirectory (completion </> "calls")
      createDirectory empty
      recordNativeScope scope (CompletionFact "owner-created" (showText (completion,empty)))
      (build,buildBound) <- native ["build", "-v0", "--builddir=.build/dist-native", suite, oracle]
      if buildBound == False || runExit build /= ExitSuccess then invalid [build] else do
        builtPlan <- readScopePlan scope "after-build" treeRoot
        (locatedSuite,suiteBound) <- native ["list-bin", "--builddir=.build/dist-native", suite]
        if suiteBound == False || runExit locatedSuite /= ExitSuccess then invalid [build,locatedSuite] else do
          (locatedOracle,oracleBound) <- native ["list-bin", "--builddir=.build/dist-native", oracle]
          let locations = [locatedSuite,locatedOracle]; paths = map (Text.unpack . Text.strip . runStdout) locations
          case paths of
            [subjectImage,oracleImage] | oracleBound /= False && all ((== ExitSuccess) . runExit) locations && subjectImage /= oracleImage -> do
              beforePlan <- readScopePlan scope "before-images" treeRoot
              let planImages = [nativePlanImage target treeRoot beforePlan | target<-["test:"<>cabalTargetName suiteTarget,"test:"<>oracleExecutableName oracleTarget]]
              when (planImages /= map Just paths) (recordNativeScope scope (CompletionFailure (NativePlanImagesUnavailable planImages paths)))
              if builtPlan /= beforePlan then invalid (build : locations)
              else if planImages /= map Just paths then invalid (build : locations)
              else do
                before <- readScopeImages scope "before" treeRoot paths
                let call = ownedOracleCall scope source treeRoot completion oracleImage (last before)
                (inventoryIssue,inventoryRun) <- call "inventory" ["--oracle-inventory",Text.unpack full]
                let inventory = inventoryCompletionFrame inventoryIssue inventoryRun
                recordNativeScope scope (OracleFrame "inventory" inventory)
                case inventory of
                  Left _ -> invalid (build : locations <> [inventoryRun])
                  Right declared -> do
                    suiteRun <- direct subjectImage [suiteDir]
                    probePhysical <- canonicalizePath empty
                    recordNativeScope scope (CompletionFact "probe-resolution" (showText (empty,probePhysical)))
                    unless (imagePathsAllowed treeRoot [empty] [probePhysical]) (fail "CompletionProbeUnconfined")
                    entries <- listDirectory empty
                    recordNativeScope scope (CompletionFact "probe-entries" (showText entries))
                    unless (null entries) (fail "CompletionProbeNotEmpty")
                    (probeIssue,probe) <- call "probe" (normalArguments <> [empty])
                    let primary = Text.pack (if full == "doc.full.v1" then empty <> "/" <> primaryName else empty </> primaryName)
                        probeFrame = probeCompletionFrame probeIssue primary probe
                    recordNativeScope scope (OracleFrame "probe" probeFrame)
                    (normalIssue,oracleRun) <- call "normal" (normalArguments <> [suiteDir])
                    let normal = completionFrame normalIssue [name | (name,_,_) <- ordinaryRows declared] oracleRun
                    recordNativeScope scope (OracleFrame "normal" normal)
                    after <- readScopeImages scope "after" treeRoot paths
                    afterPlan <- readScopePlan scope "after-images" treeRoot
                    closing <- verifySourceCopy source treeRoot
                    recordNativeScope scope (CompletionFact "source-closing" (showText closing))
                    let prefix = either (const "") retainedOrdinaryPrefix normal
                        parsed = parseLedger (Just (runExit oracleRun)) prefix
                        valid = builtPlan == afterPlan && ledgerValid parsed && runExit suiteRun == ExitSuccess && isRight probeFrame && isRight normal && before == after && closing == Right () && all (`elem` [name | (name,_,_) <- ledgerRows parsed]) required
                        context = ((capturedSourceDigest source,treeRoot,runnerCabal config,runnerCompiler config),[inventoryIssue,probeIssue,normalIssue],prefix)
                    pure (build : locations <> [inventoryRun,suiteRun,probe,oracleRun], parsed {ledgerValid=valid,ledgerImages=[(treeRoot,zipWith3 (\path a b -> (path,a,b)) paths before after)],ledgerContexts=[context]})
            _ -> invalid (build : locations)
completionFrame :: Text -> [Text] -> ObservedRun -> Either CompletionFault WireFrame
completionFrame issued names run = either (Left . CompletionWire) Right (normalWireFrame issued names (completionTerminal run) (runStdout run))
completionTerminal :: ObservedRun -> Either WireFault Int
completionTerminal run | isJust (runSpawnFailure run) = Left (WireFault NativeObservationUnavailable NativeBoundary)
completionTerminal run = case runExit run of ExitSuccess -> Right 0; ExitFailure value | value > 0 -> Right value; _ -> Left (WireFault KnownAbnormalTermination NativeBoundary)
inventoryCompletionFrame :: Text -> ObservedRun -> Either CompletionFault WireFrame
inventoryCompletionFrame issued run = do
  raw <- either (Left . CompletionWire) Right (completionTerminal run >> decodeRetainedWire (runStdout run))
  frame <- completionFrame issued [name | (name,_,_) <- ordinaryRows raw] run
  if footerPurpose frame == FinishedAllGreen && all (\(_,verdict,detail) -> verdict == "green" && detail == "declared") (ordinaryRows frame) then Right frame else Left InventoryNotDeclared
-- Marker consistency only; the actual requiredRead source/build/image join is separate.
probeCompletionFrame :: Text -> Text -> ObservedRun -> Either CompletionFault WireFrame
probeCompletionFrame issued primary run = either (Left . CompletionWire) Right $ do
  terminal <- completionTerminal run
  frame <- decodeRetainedWire (runStdout run)
  wireRequire InvocationMismatch FooterChallenge (footerChallenge frame == issued)
  wireRequire MissingInputNotObserved FooterPurpose (case footerPurpose frame of RequiredInputMissing _ -> True; _ -> False)
  wireRequire OrdinaryRowsInvalid OrdinaryPrefix (Text.null (retainedOrdinaryPrefix frame))
  wireRequire RefusalLocusMismatch FooterLocus (footerPurpose frame == RequiredInputMissing primary)
  wireRequire TerminalMismatch NativeTerminal (terminal == 1)
  pure frame
mergeCompletionLedgers :: Ledger -> Ledger -> Ledger
mergeCompletionLedgers clean custody = let
  contexts = ledgerContexts custody <> ledgerContexts clean
  prefix = Text.concat [ordinary | ledger <- [clean,custody],(_,_,ordinary) <- ledgerContexts ledger]
  parsed = parseLedger (Just (if ledgerGreen clean && ledgerGreen custody then ExitSuccess else ExitFailure 1)) prefix
  matched = case (ledgerContexts clean,ledgerContexts custody) of
    ([(key,first,_)],[(other,second,_)]) -> key == other && length first == 3 && length second == 3 && length (nub (first <> second)) == 6
    _ -> False
  in parsed {ledgerValid=ledgerValid parsed && ledgerValid clean && ledgerValid custody && matched,ledgerImages=ledgerImages custody <> ledgerImages clean,ledgerContexts=contexts}
mutantMatrix :: NativeScope -> RunnerConfig -> GateSpec -> VerifiedSpec -> Maybe PackageGraph -> Text -> CapturedSource -> IO (KillTable, (Ledger, Either Text (), Bool), [ObservedRun])
mutantMatrix scope@(NativeScope _ _ calls _) config spec vspec graph digest source = do
  let root = runnerRoot config; policy = gateMutants spec
  perModuleLoci <- forM (stageModules policy) $ \stage -> do
    located <- maybe (pure Nothing) (\(g, stanza) -> moduleSourcePath root g stanza stage) ((,) <$> graph <*> Map.lookup stage (verifiedStanzaOf vspec))
    case located of
      Nothing -> pure []
      Just file -> do
        contents <- readSourceText (root </> file)
        pure (sampleLoci (digest <> productionModuleName stage) (perModule policy) (concat [enumerateLoci (productionModuleName stage) file operator contents | operator <- allOperators]))
  -- Round-robin sampling prevents the gate cap from starving later stage modules.
  let selected = take (maybe (perGateCap policy) (min (perGateCap policy)) (runnerMutantLimit config)) (concat (transpose perModuleLoci))
  copiedControl <- materializeSource source (runnerRunRoot config </> "mutants" </> "control")
  (controlRuns, control) <- either (const (pure ([], parseLedger Nothing ""))) (matrixSuite source) copiedControl
  controlSource <- either (pure . Left) (verifySourceCopy source) copiedControl
  results <- if not (ledgerGreen control && controlSource == Right ()) then pure [] else forM (zip [1 :: Int ..] selected) $ \(index, locus) -> do
    let copyRoot = runnerRunRoot config </> "mutants" </> show index
    copied <- materializeSource source copyRoot
    applied <- either (pure . Left) (`applyLocus` locus) copied
    case applied of
      Left problem -> pure ((locus, Nothing, Unapplied problem), [], False)
      Right witness -> do
        bytes <- withNativeScope scope (readSourceBytes (copyRoot </> witnessFile witness))
        withNativeScope scope $ unless (sha256Bytes bytes == witnessAfterDigest witness && (sha256Bytes <$> capturedSourceBytes source (witnessFile witness)) == Just (witnessBeforeDigest witness)) (fail "MatrixSourceWitnessMismatch")
        changed <- withNativeScope scope (either (fail . Text.unpack) pure (rewriteCapturedSource source (witnessFile witness) bytes))
        (runs, ledger) <- matrixSuite changed copyRoot
        retained <- readIORef calls
        closing <- verifySourceCopy changed copyRoot
        let stillborn = closing == Right () && matrixCompilationRefused copyRoot locus runs retained
            images = if complete then boundSuiteImageChange control ledger else Nothing
            complete = ledgerValid ledger && Set.fromList [name | (name, _, _) <- ledgerRows ledger] == Set.fromList [name | (name, _, _) <- ledgerRows control]
            imageBound = isJust images && witnessBeforeDigest witness /= witnessAfterDigest witness
            outcome
              | stillborn = Stillborn ("compiler refusal at " <> Text.pack (locusFile locus) <> ":" <> showText (locusLine locus))
              | not (complete && imageBound) || null (ledgerRedRows ledger) || ledgerGreen ledger || not (isAttributed (stageArtefacts policy) (locusModule locus) (ledgerRedRows ledger)) = Survived
              | otherwise = Killed (Text.intercalate "," (take 3 (ledgerRedRows ledger)))
        imageBound `seq` Text.length (renderMutantOutcome id outcome) `seq` pure ((locus, Just witness {witnessImages = maybe [] pure images}, outcome), runs, closing == Right () && (stillborn || imageBound && complete))
  pure (killTable [row | (row, _, _) <- results], (control, controlSource, and [complete | (_, _, complete) <- results]), controlRuns <> concat [runs | (_, runs, _) <- results])
 where matrixSuite bound tree = do { let { needsWire = do { g <- graph; (info,_) <- Map.lookup (cabalTargetName (gateSuite spec)) (graphTestSuites g); pure (Set.member "pulsar-wire" (libraryClosure g (Set.toList (internalDependencies info)))) } }; (preparation,ready) <- case needsWire of { Nothing -> pure ([],Left "SuiteDependencyClosureUnavailable"); Just True -> prepareNativeWireTool scope tree (runnerCabal config) (runnerCompiler config); Just False -> pure ([],Right []) }; case ready of { Left "WirePluginObservationMismatch" -> do { let { work=tree </> ".build" </> "wire-preparation-observation"; actual=tree </> ".build" </> "proto" </> "current"; observed=work </> "suite" </> "current" }; createDirectoryIfMissing True work; (runs,ledger) <- suiteAndOracle scope config bound tree (CabalTarget "wire-preparation") (OracleExecutable "oracle-dsl") False ["wire.prepared-schema","wire.plugin-request"] work; pairs <- readScopeImages scope "wire-preparation-pair" tree [actual </> "PulsarApi.proto",actual </> "plugin.request",observed </> "PulsarApi.proto",observed </> "plugin.request"]; unless (take 2 pairs == drop 2 pairs) (fail "WirePreparationPairMismatch"); pure (preparation <> runs,ledger) }; Left _ -> pure (preparation,parseLedger Nothing ""); Right opening -> do { (runs,ledger) <- suiteAndOracle scope config bound tree (gateSuite spec) (gateOracle spec) False (filter (/= "case:shipped-binary") (requiredSuiteRows spec)) (tree </> ".build" </> "observations"); unless (null opening) (verifyWireGenerated scope tree "wire-matrix-closing" opening); pure (preparation <> runs,ledger) } } }
matrixCompilationRefused :: FilePath -> Locus -> [ObservedRun] -> [NativeCall] -> Bool
matrixCompilationRefused root locus runs retained = case (take 1 (reverse runs),retained) of
  ([build],call:_) -> runCwd build == root && (case nativeIntent call of NativeCabalIntent actual _ _ ("build":_) -> actual == root; _ -> False) && runSpawnFailure build == Nothing && completionTerminal build == Right 1 && any (\line -> (Text.pack (locusFile locus) <> ":" <> showText (locusLine locus) <> ":") `Text.isPrefixOf` line && ": error:" `Text.isInfixOf` line) (Text.lines (runStderr build)) && not ("[-Werror" `Text.isInfixOf` runStderr build) && case ([window | WindowRequestsMatched [window]<-nativeWindowObservations call],[window | WindowJournalClosed window codes<-nativeWindowObservations call,any (\(ordinal,code)->ordinal>0 && code==ExitFailure 1) codes]) of
    ([window],[closed]) -> window == closed && or [Journal.requestWindowRoot request == window && Journal.requestOrdinal request > 0 && Journal.compilerSite request == Journal.ReAdmittedDelegatedCompiler && Journal.actualRawCompilerReturn returned == Journal.ActualRawSystemReturned (ExitFailure 1) | WindowRecordReturned path (RetainedPlanBytes bytes)<-nativeWindowObservations call,takeFileName path=="return.data",Just returned<-[decodeNativeWindow bytes],let request=Journal.returnRequest returned]
    _ -> False
  _ -> False
capture :: RunnerConfig -> GateSpec -> VerifiedSpec -> HygieneReport -> Text -> Text -> Text -> (Text, Text) -> KillTable -> (Ledger, Either Text (), Bool) -> Ledger -> Maybe BinaryOutcome -> Maybe SpineOutcome -> [ObservedRun] -> Maybe SeedOutcome -> Maybe DocumentationOutcome -> Set.Set Text -> LegacyCollection -> CapturedSource -> [(Text, Text)] -> Candidate
capture config spec vspec hygiene digest nonce chain (opening, closing) table (matrixControl, controlSource, matrixApplied) ledger binary spine runs seedOutcome documentation productClosure legacy openingSource nativeEvidence =
  Candidate { candidatePhase = runnerPhase config, candidateCapability = gateCapability spec, candidateSpecDigest = digest, candidateChallenge = nonce, candidateChain = chain, candidateReproducibleCore = "", candidateRows = nonPassRows <> [row PassCriterion] }
 where
  nonPassRows = map row (filter (/= PassCriterion) allGateCategories)
  seed = isJust (gateSeed spec)
  seedOk = maybe False seedGreen seedOutcome && maybe False (all exactlyGreen . seedCustodyProbes) (gateSeed spec)
  docOk = maybe False documentationGreen documentation
  seedObservations = maybe [] renderSeedOutcome seedOutcome
  docObservations = maybe [] (\outcome ->
          [("doc.findings", Text.pack (show (length (documentationFindings outcome)))), ("doc.negatives", Text.intercalate "," [name <> "=" <> (if named then "named" else "absent") | (name, named) <- documentationNegatives outcome])]
            <> [("doc.finding", item) | item <- take 20 (documentationFindings outcome)]
      ) documentation
  positives = [c | c@PositiveControl {} <- gateCases spec]
  negatives = [c | c@PairedNegative {} <- gateCases spec]
  exactlyGreen name = length [() | (observedName, verdict, _) <- ledgerRows ledger, observedName == name, verdict == "green"] == 1
  ledgerCaseGreen item = maybe True (const (exactlyGreen (caseName item))) (Text.stripPrefix "case:" (caseName item))
  fresh = bootstrapSnapshotMatches (Text.unpack opening) (Text.unpack closing)
  observed = all (isNothing . runSpawnFailure) runs && not (null runs)
  stageKilled stage = any (\(locus, _, outcome) -> locusModule locus == productionModuleName stage && isKilled outcome) (killRows table)
  isKilled outcome = case outcome of Killed _ -> True; _ -> False
  mutantsGreen =
    not seed && ledgerGreen matrixControl && controlSource == Right () && matrixApplied
      && viableCount table > 0
      && killRatioObserved table >= killRatio (gateMutants spec)
      && all stageKilled (stageModules (gateMutants spec))
  productShipsNoValidator = not (Set.null productClosure) && not (any isValidatorStanza (Set.toList productClosure))
  isValidatorStanza stanza = stanza `elem` ["validation-kernel", "validation-runner", "doc-check", "plan-decisions", "gate-spec"]
  binaryGreen = case binary of
    Nothing -> isNothing (gateBinaryFact spec)
    Just outcome -> null (binaryProblems outcome) && not (null (binaryRuns outcome)) && not (null (binaryNonceRecovered outcome)) && all snd (binaryNonceRecovered outcome)
  spineGreen = maybe (isNothing (gateSpineFact spec)) (\o -> spineDigestsEqual o && all (\stage -> any (\(name, verdict, _) -> verdict == "green" && (stage <> ".") `Text.isPrefixOf` name) (ledgerRows ledger)) (spineStageOrder o)) spine
  predecessorGreen = predecessorMatches config openingSource
  legacyDue = Legacy.legacyIdsOwnedBy (runnerPhase config)
  verdictOf condition = if condition then Green else Red
  row category = CandidateRow category verdict observations
   where
    (verdict, observations) = case category of
      Claim -> (Green, [("claim", gateClaim spec), ("spec-digest", digest), ("role", Text.pack (show (gateRole spec)))])
      Subject -> (verdictOf (not (Map.null (verifiedStanzaOf vspec))), [("subject." <> productionModuleName m, stanza) | (m, stanza) <- Map.toList (verifiedStanzaOf vspec)])
      Command -> (Green, [("command", "amoebius-validate preview phase " <> Text.pack (show (runnerPhase config))), ("suite", cabalTargetName (gateSuite spec)), ("oracle", oracleExecutableName (gateOracle spec))])
      Oracle -> (verdictOf (ledgerValid ledger), [("oracle.completion-contexts", showText [(identity,rows,nativeDiagnostic prefix) | (identity,rows,prefix) <- ledgerContexts ledger]), ("oracle.images", showText [(root,[(path,ByteString.length opening,sha256Bytes opening,ByteString.length closing,sha256Bytes closing) | (path,opening,closing) <- images]) | (root,images) <- ledgerImages ledger]), ("oracle.directories", Text.intercalate "," (map Text.pack (verifiedOracleDirectories vspec))), ("oracle.ledger-sha256", ledgerDigest ledger), ("oracle.rows", showText (length (ledgerRows ledger)))])
      PositiveControls -> (verdictOf (not (null positives) && ledgerGreen ledger && all ledgerCaseGreen positives && (not seed || (seedOk && docOk))), [("positive.count", showText (length positives)), ("ledger.red-rows", Text.intercalate "," (ledgerRedRows ledger))] <> docObservations)
      PairedNegatives -> (verdictOf (not (null negatives) && ledgerGreen ledger && all ledgerCaseGreen negatives && (not seed || (seedOk && docOk))), [("negative.count", showText (length negatives)), ("ledger.red-rows", Text.intercalate "," (ledgerRedRows ledger))] <> docObservations)
      Mutants -> (if seed then verdictOf seedOk else verdictOf mutantsGreen, if seed then seedObservations else [("mutants.killed", showText (killedCount table)), ("mutants.viable", showText (viableCount table)), ("mutants.stillborn", showText (stillbornCount table)), ("mutants.ratio", Text.pack (show (killRatioObserved table))), ("mutants.rows", showText (length (killRows table))), ("matrix.control.source", Text.pack (show controlSource)), ("matrix.control.valid", Text.pack (show (ledgerValid matrixControl))), ("matrix.control.exit", Text.pack (show (ledgerExit matrixControl))), ("matrix.control.rows", Text.intercalate "," [name | (name, _, _) <- ledgerRows matrixControl]), ("matrix.control.ledger-sha256", ledgerDigest matrixControl), ("matrix.control.red-rows", Text.intercalate "," (ledgerRedRows matrixControl)), ("matrix.control.raw", nativeDiagnostic (Text.pack (show [run | run <- runs, runCwd run == runnerRunRoot config </> "mutants" </> "control"]))), ("matrix.applied", Text.pack (show matrixApplied)), ("matrix.image-witnesses", showText [(locus,witnessBeforeDigest witness,witnessAfterDigest witness,witnessImages witness) | (locus,Just witness,_) <- killRows table])] <> [("mutant." <> showText i, line) | (i, line) <- zip [1 :: Int ..] (renderKillTable table)])
      Discovery -> (verdictOf (not (Set.null (verifiedClosure vspec)) && length (verifiedStanzaOf vspec) == length (gateSubjects spec)), [("closure.stanzas", Text.intercalate "," (Set.toList (verifiedClosure vspec))), ("subjects.mapped", showText (Map.size (verifiedStanzaOf vspec))), ("subjects.declared", showText (length (gateSubjects spec)))])
      Challenge -> (verdictOf (if seed then seedOk else binaryGreen && spineGreen), [("challenge.nonce", nonce), ("challenge.kind", if seed then "pure predicate judged by the independent driver" else "runner-perturbed input"), ("challenge.binary", maybe "absent" (\o -> Text.pack (show (binaryNonceRecovered o))) binary), ("challenge.spine", maybe "absent" (\o -> Text.pack (show (spineDigestsEqual o))) spine)] <> maybe [] binaryEvidence binary)
      Observer -> (verdictOf observed, concat [renderObserved ("run." <> showText i) run | (i, run) <- zip [1 :: Int ..] runs] <> nativeEvidence)
      AuthorityBypass -> (verdictOf productShipsNoValidator, [("closure.validator-free", Text.pack (show productShipsNoValidator)), ("closure.product", Text.intercalate "," (Set.toList productClosure)), ("subjects.validator", showText (length (filter isValidatorModule (gateSubjects spec))))])
      Freshness -> (verdictOf fresh, [("source.opening", opening), ("source.closing", closing), ("run-root", Text.pack (runnerRunRoot config))])
      Qualification -> (verdictOf (if seed then seedOk else mutantsGreen), [("qualification", if seed then "finite-seed-protocol" else "generated-mutant-matrix"), ("matrix.precedes-clean", "true")] <> (if seed then seedObservations else []))
      Cleanroom -> (verdictOf fresh, [("cleanroom.run-root", Text.pack (runnerRunRoot config)), ("cleanroom.tracked-unchanged", Text.pack (show fresh))])
      LegacyClosure -> (verdictOf (hygieneGreen hygiene && null (auditLegacyCollection (runnerPhase config) openingSource legacy)), renderHygiene hygiene <> [("legacy.due", Text.intercalate "," (map Legacy.renderLegacyId legacyDue))] <> legacyCollectionEvidence legacy)
      Predecessor -> (verdictOf predecessorGreen, [("predecessor", if runnerPhase config == PhaseIdentity.phaseDomainLowerOrdinal then "genesis" else maybe "absent" id (runnerPredecessorDigest config))])
      Residue -> (verdictOf fresh, [("residue.tracked-unchanged", Text.pack (show fresh)), ("residue.unverified", "later-owned capabilities remain UNVERIFIED by construction")])
      PassCriterion -> (verdictOf (all ((== Green) . rowVerdict) nonPassRows), [("pass-criterion", "qualified-gate-pass")])
newtype Nonce = Nonce Text deriving (Eq, Show)
freshNonce :: FilePath -> Text -> IO Nonce
freshNonce runRoot chain = do
  now <- getPOSIXTime
  pure (Nonce (Text.take 32 (sha256Hex (Text.pack runRoot <> "\n" <> Text.pack (show now) <> "\n" <> chain))))
perturbInput :: Perturbation -> Nonce -> Text -> Either Text Text
perturbInput perturbation (Nonce nonce) contents = case perturbation of
  SentinelToNonce sentinel
    | sentinel `Text.isInfixOf` contents -> Right (Text.replace sentinel nonce contents)
    | otherwise -> Left ("sentinel absent from the input: " <> sentinel)
  ReplicaCount from to ->
    let needle = "replicas = " <> Text.pack (show from)
     in if needle `Text.isInfixOf` contents then Right (Text.replace needle ("replicas = " <> Text.pack (show to)) contents)
          else Left ("replica count absent from the input: " <> needle)
  Rewrite needle replacement
    | needle `Text.isInfixOf` contents -> Right (Text.replace needle replacement contents)
    | otherwise -> Left ("rewrite needle absent from the input: " <> needle)
  Staged {} -> Left "a staged perturbation applies its inner perturbations after the prelude"
  PlantForeignPaths _ -> Left "planted paths require the runner's source-copy input"
  SourceSibling _ _ _ -> Left "source sibling requires the runner's observed build boundary"
data BinaryOutcome = BinaryOutcome { binaryRuns :: [ObservedRun], binaryNonce :: Nonce , binaryOutputDigests :: [(FilePath, Text)], binaryNonceRecovered :: [(FilePath, Bool)] , binaryEvidence :: [(Text, Text)], binaryProblems :: [Text] } deriving (Eq, Show)
runBinaryFact :: NativeScope -> FilePath -> Maybe FilePath -> CapturedSource -> FilePath -> FilePath -> FilePath -> BinaryFact -> Nonce -> IO BinaryOutcome
runBinaryFact scope cabal compiler snapshot root runRoot productBinary fact nonce@(Nonce nonceText) = case factPerturbation fact of
  PlantForeignPaths challenges -> do
    outcomes <- forM (zip [1 :: Int ..] challenges) $ \(index, challenge) -> runOne (runRoot </> show index) (Just challenge)
    pure (BinaryOutcome (concatMap binaryRuns outcomes) nonce (concatMap binaryOutputDigests outcomes)
      (concatMap binaryNonceRecovered outcomes) (concatMap binaryEvidence outcomes) (["foreign challenge set empty" | null challenges] <> concatMap binaryProblems outcomes))
  _ -> runOne runRoot Nothing
 where
  (underlying, sibling) = case factPerturbation fact of SourceSibling subject binding inner -> (inner, Just (subject, binding)); other -> (other, Nothing)
  runOne workRoot challenge = do
    let inputPath = workRoot </> "input" </> takeFileName (factInput fact)
        planted = fmap (\(path, tag) -> (Text.unpack (Text.replace "{nonce}" nonceText (Text.pack path)), tag)) challenge
        substitute base argument = Text.unpack (Text.replace "{tree}" (Text.pack (base </> "tree")) (Text.replace "{run}" (Text.pack base) (Text.replace "{input}" (Text.pack inputPath) argument)))
        execute = mapM (observe root productBinary . map (substitute workRoot))
    createDirectoryIfMissing True (takeDirectory inputPath)
    before <- case underlying of
      Staged prelude _ _ -> execute prelude
      _ -> pure []
    source <- case planted of
      Just (path, _) -> plantPath snapshot workRoot path
      Nothing -> case underlying of
        Staged _ _ inner -> do
          original <- try (readSourceText inputPath) :: IO (Either IOException Text)
          pure (original >>= \text -> either (Left . userError . Text.unpack) Right (foldM (\current perturbation -> perturbInput perturbation nonce current) text inner))
        other -> do
          original <- try (readSourceText (root </> factInput fact)) :: IO (Either IOException Text)
          pure (original >>= either (Left . userError . Text.unpack) Right . perturbInput other nonce)
    case source of
      Left problem -> pure (BinaryOutcome before nonce [] [] [] [Text.pack (show problem)])
      Right perturbed -> do
        TextIO.writeFile inputPath perturbed
        run <- observe root productBinary (map (substitute workRoot) (factCommand fact))
        after <- case underlying of
          Staged _ postlude _ -> execute postlude
          _ -> pure []
        (siblingRuns, evidence, siblingProblems) <- maybe (pure ([], [], [])) (uncurry (rebuildSibling workRoot inputPath substitute)) sibling
        outputs <- mapM (readOutput . substitute workRoot . Text.pack) (factOutputs fact)
        let expectedExit = maybe ExitSuccess (const (ExitFailure 1)) planted
            expectedFinding = fmap (\(path, tag) -> "finding\t" <> tag <> "\t" <> Text.pack path) planted
            findingSeen = maybe True (\line -> any (maybe False (line `elem`) . fmap Text.lines . snd) outputs) expectedFinding
        pure (BinaryOutcome (before <> [run] <> after <> siblingRuns) nonce
          [(path, sha256Hex contents) | (path, Just contents) <- outputs]
          [(path, maybe False (nonceText `Text.isInfixOf`) contents) | (path, contents) <- outputs]
          evidence ([Text.pack path <> ": output absent" | (path, Nothing) <- outputs]
            <> ["unexpected binary exit" | any ((/= expectedExit) . runExit) (before <> [run] <> after)]
            <> ["required foreign finding absent" | not findingSeen] <> siblingProblems))
  rebuildSibling workRoot inputPath substitute subject binding = do
    result <- try $ do
      graph <- loadPackageGraph root >>= either (fail . show) pure
      let shipped = maybe Set.empty id (executableClosure graph "amoebius")
      stanza <- one "source sibling module is not uniquely shipped" [name | (name, (modules, _, _)) <- Map.toList (graphLibraries graph), Set.member name shipped, Set.member (productionModuleName subject) modules]
      file <- moduleSourcePath root graph stanza subject >>= maybe (fail "source sibling module absent") pure
      source <- readSourceText (root </> file)
      locus <- truncateListLocus <$> one "source sibling binding is not one literal list" [entry | entry <- enumerateLoci (productionModuleName subject) file ListTruncation source, (binding <> " = ") `Text.isPrefixOf` Text.stripStart (locusBefore entry)]
      let child = workRoot </> "sibling"; tree = child </> "tree"
      _ <- materializeSource snapshot tree >>= either (fail . Text.unpack) pure
      witness <- applyLocus tree locus >>= either (fail . Text.unpack) pure
      if Text.strip (locusAfter locus) /= binding <> " = []" || witnessBeforeDigest witness == witnessAfterDigest witness then fail "source sibling did not empty its binding" else pure ()
      (inputBefore, binaryBefore) <- (,) <$> readSourceBytes inputPath <*> ByteString.readFile productBinary
      (preparation, ready) <- prepareNativeWireTool scope tree cabal compiler; (runs, built) <- either (\problem -> pure ([],Left problem)) (const (buildNativeTargetWith "exe:amoebius" (ownedCabal scope tree cabal compiler))) ready; let builds = preparation <> runs
      case built of
        Left problem -> pure (builds, [], [problem])
        Right image -> do
          beforeBinding <- productImageBinding scope tree image "sibling-before"; observed <- observe tree image (map (substitute child) (factCommand fact))
          afterBinding@(_, binaryAfter) <- productImageBinding scope tree image "sibling-after"; forM_ ready (verifyWireGenerated scope tree "wire-sibling-closing")
          inputAfter <- readSourceBytes inputPath
          let evidence = [("nonce", nonceText), ("module", productionModuleName subject), ("binding", binding), ("operator", renderOperator (witnessOperator witness)),
                ("source-before", witnessBeforeDigest witness), ("source-after", witnessAfterDigest witness), ("source-diff", Text.pack (show (witnessDiff witness))),
                ("binary-before", sha256Bytes binaryBefore), ("binary-after", sha256Bytes binaryAfter), ("input-before", sha256Bytes inputBefore), ("input-after", sha256Bytes inputAfter)]
          TextIO.writeFile (child </> "witness.tsv") (renderTsv [[key, value] | (key, value) <- evidence])
          pure (builds <> [observed], evidence, ["source sibling binary unchanged" | binaryBefore == binaryAfter] <> ["source sibling input changed" | inputBefore /= inputAfter] <> ["source sibling image or plan changed" | beforeBinding /= afterBinding] <> ["source sibling did not refuse" | runExit observed /= ExitFailure 1])
    pure (either (\problem -> ([], [], [Text.pack (show (problem :: IOException))])) id result)
  one :: String -> [value] -> IO value
  one label values = case values of [value] -> pure value; _ -> fail label
  readOutput path = (,) path <$> readIfPresent path
plantPath :: CapturedSource -> FilePath -> FilePath -> IO (Either IOException Text)
plantPath source runRoot planted = try $ do
  let copied = [file | file <- capturedSourceFiles source, Just _ <- [capturedSourceBytes source file]]
  let tree = runRoot </> "tree"
  _ <- materializeSource source tree >>= either (fail . Text.unpack) pure
  createDirectoryIfMissing True (takeDirectory (tree </> planted))
  TextIO.writeFile (tree </> planted) "challenge\n"
  pure (Text.unlines (map Text.pack (copied <> [planted])))
data SpineOutcome = SpineOutcome { spineRenderDigest :: Maybe Text, spineAppliedDigest :: Maybe Text , spineDigestsEqual :: Bool, spineStageOrder :: [Text] } deriving (Eq, Show)
runSpineFact :: FilePath -> SpineFact -> IO SpineOutcome
runSpineFact runRoot fact = do
  rendered <- readIfPresent (runRoot </> spineRendered fact)
  applied <- readIfPresent (runRoot </> spineAppliedDigestFile fact)
  let renderDigest = sha256Hex <$> rendered
      appliedDigest = Text.strip <$> applied
  pure (SpineOutcome renderDigest appliedDigest
    (renderDigest /= Nothing && renderDigest == appliedDigest) (spineStages fact))
readIfPresent :: FilePath -> IO (Maybe Text)
readIfPresent path = doesFileExist path >>= \exists -> if exists then Just <$> readSourceText path else pure Nothing
kernelBudget :: Int
kernelBudget = 14000
kernelRoots :: [FilePath]
kernelRoots = ["src/validation-kernel", "src/gate-spec"]
docCheckRoot :: FilePath
docCheckRoot = "src/doc-check"
-- Private source custody; rewrites retain bytes and grant no qualification verdict.
runRootWithinFrame :: FilePath -> FilePath -> IO Bool
runRootWithinFrame root path = (\base absolute physical -> equalFilePath absolute physical && bootstrapInputPathAllowed (intercalate "/" (splitDirectories (makeRelative base absolute)))) <$> canonicalizePath root <*> makeAbsolute path <*> canonicalizePath path
data CapturedSource = CapturedSource Text [(FilePath, Maybe (Bool, ByteString.ByteString))] [ObservedRun]
capturedSourceDigest :: CapturedSource -> Text
capturedSourceDigest (CapturedSource digest _ _) = digest
capturedSourceFiles :: CapturedSource -> [FilePath]
capturedSourceFiles (CapturedSource _ entries _) = map fst entries
capturedSourceBytes :: CapturedSource -> FilePath -> Maybe ByteString.ByteString
capturedSourceBytes (CapturedSource _ entries _) file = lookup file entries >>= fmap snd
capturedSourceRuns :: CapturedSource -> [ObservedRun]
capturedSourceRuns (CapturedSource _ _ runs) = runs
sourceSnapshot :: [(FilePath, Maybe (Bool, ByteString.ByteString))] -> [ObservedRun] -> CapturedSource
sourceSnapshot entries runs = CapturedSource (sha256Hex (Text.pack (show [(file, fmap (\(mode, bytes) -> (mode, sha256Bytes bytes)) value) | (file, value) <- entries]))) entries runs
rewriteCapturedSource :: CapturedSource -> FilePath -> ByteString.ByteString -> Either Text CapturedSource
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
readSourceInput :: FilePath -> FilePath -> Bool -> IO (Maybe (Bool, ByteString.ByteString))
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
  doesPathExist root >>= \present -> when present (fail "SourceCopyNotFresh")
  createDirectoryIfMissing True parent
  createDirectory root
  forM_ [(file, value) | (file, Just value) <- entries] $ \(file, (mode, bytes)) -> do
    let path = root </> file
    createDirectoryIfMissing True (takeDirectory path)
    ByteString.writeFile path bytes
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
readSourceBytes :: FilePath -> IO ByteString.ByteString
readSourceBytes path = do
  ((,) <$> getFileType path <*> pathIsSymbolicLink path) >>= \(kind, linked) -> unless (classifyTreeNode linked True kind == TreeFile) (fail "SourceNotRegular")
  withBinaryFile path ReadMode $ \stream -> do
    bytes <- hFileSize stream >>= ByteString.hGet stream . fromInteger . min (16 * 1024 * 1024 + 1) . (+ 1)
    hIsEOF stream >>= \ended -> if ByteString.length bytes > 16 * 1024 * 1024 then fail "SourceByteLimit" else if not ended then fail "SourceReadChanged" else pure bytes
readSourceText :: FilePath -> IO Text
readSourceText path = readSourceBytes path >>= either (const (fail "SourceTextUtf8")) pure . E.decodeUtf8'
vocabularyTypes :: [Text]
vocabularyTypes = ["Substrate", "Architecture", "Detected", "Lane", "ComputeEngine", "EngineRuntime", "InferenceFamily", "CapabilityArm", "ExtensionId", "Quantity", "ResourceVector", "Register"]
data HygieneReport = HygieneReport { hygieneKernelLines :: Int, hygieneKernelCap :: Int, hygieneDocCheckLines :: Int, hygieneDocCheckCap :: Int , hygieneConditionalCompilation :: [(FilePath, Int)], hygieneRunModules :: [FilePath] , hygienePhaseLiterals :: [(FilePath, Int, Text)], hygienePhaseTables :: [FilePath] , hygieneDuplicateVocabulary :: [(Text, [FilePath])], hygieneProductDuplicateVocabulary :: [(Text, [FilePath])] } deriving (Eq, Show)
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
    , hygieneRunModules = [moduleFile | (moduleFile, _) <- kernel, isRunModule moduleFile]
    , hygienePhaseLiterals = [(file, number, Text.strip line) | (file, number, line) <- numbered, phaseLiteral line]
    , hygienePhaseTables = [file | (file, lines') <- kernel, any phaseTableDefinition lines']
    , hygieneDuplicateVocabulary = duplicates kernel, hygieneProductDuplicateVocabulary = duplicates productSources }
isRunModule :: FilePath -> Bool
isRunModule file = any (\base -> "Run" `isSuffixOf` base && base /= "Run")
  (map takeBaseName (splitDirectories file))
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
  [ ("hygiene.kernel-lines", showText (hygieneKernelLines report)) , ("hygiene.kernel-cap", showText (hygieneKernelCap report)) , ("hygiene.doc-check-lines", showText (hygieneDocCheckLines report))   , ("hygiene.doc-check-cap", showText (hygieneDocCheckCap report)) , ("hygiene.conditional-compilation-lines", showText (length (hygieneConditionalCompilation report)))   , ("hygiene.run-modules", showText (length (hygieneRunModules report))) , ("hygiene.phase-literals", showText (length (hygienePhaseLiterals report)))
  , ("hygiene.phase-tables", showText (length (hygienePhaseTables report))) , ("hygiene.duplicate-vocabulary", showText (length (hygieneDuplicateVocabulary report)))
  , ("hygiene.product-duplicate-vocabulary", Text.intercalate "," (map fst (hygieneProductDuplicateVocabulary report))) , ("hygiene.verdict", if hygieneGreen report then "green" else Text.intercalate "; " (hygieneProblems report))
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
data LegacyFinding = LegacyFinding { findingIdentity :: Maybe Legacy.LegacyId, findingScope :: Text, findingPath :: FilePath , findingLocus :: Text, findingReason :: Text } deriving (Eq, Show)
data LegacyObservation = AnalyzerUnavailable Text | AnalyzerFindings [LegacyFinding] deriving (Eq, Show)
data LegacyReport = LegacyReport { reportedIdentity :: Legacy.LegacyId, reportedScope :: Text, reportedLifecycle :: Text , reportedAnalyzer :: Text, reportedSource :: Text, reportedObservation :: LegacyObservation } deriving (Eq, Show)
legacyRequirementsAt :: Int -> [Legacy.LegacyRequirement]
legacyRequirementsAt phase = Legacy.legacyRequirements <> [Legacy.legacyBootstrapSourceRequirement | phase == PhaseIdentity.phaseDomainLowerOrdinal]
observeLegacy :: Int -> CapturedSource -> Maybe Int -> [LegacyReport]
observeLegacy phase source cap = concat (observeLegacyMany phase [source] cap)
observeLegacyMany :: Int -> [CapturedSource] -> Maybe Int -> [[LegacyReport]]
observeLegacyMany phase sources cap = [map (observeRequirement source) (legacyRequirementsAt phase) | source <- sources]
 where
  scanner = sourceScans [files | source <- sources, Right files <- [sourceTexts ".hs" ["src", "app", "test"] source]]
  observeRequirement source requirement = LegacyReport (Legacy.legacyRequirementId requirement) (scope requirement)
    (Legacy.renderLegacyLifecycle (Legacy.legacyRequirementLifecycle requirement))
    (Legacy.renderLegacyAnalyzerKey (Legacy.legacyRequirementAnalyzer requirement)) (capturedSourceDigest source)
    (either AnalyzerUnavailable (AnalyzerFindings . map (\(reason, path, locus) -> LegacyFinding (Just (Legacy.legacyRequirementId requirement)) (scope requirement) path locus reason))
      (queryInputs requirement source >>= query scanner requirement cap))
scope :: Legacy.LegacyRequirement -> Text
scope = Legacy.renderLegacyScope . Legacy.legacyRequirementScope
-- Reports, source hashes and empty findings cannot supply canonical qualification.
auditLegacyReports :: Int -> CapturedSource -> [LegacyReport] -> [Text]
auditLegacyReports = auditReports []
auditReports :: [(Legacy.LegacyId, Text)] -> Int -> CapturedSource -> [LegacyReport] -> [Text]
auditReports qualified phase source reports
  | not (PhaseIdentity.isPhaseOrdinal phase) = ["LegacyPhaseUnknown"]
  | otherwise = ["LegacyUnexpectedRow" | any (\r -> reportKey r `notElem` keys) reports]
      <> ["LegacyDuplicateLocus" | length loci /= length (nub loci)] <> concatMap audit requirements
 where
  requirements = legacyRequirementsAt phase
  key requirement = (Legacy.legacyRequirementId requirement, scope requirement)
  keys = map key requirements
  reportKey report = (reportedIdentity report, reportedScope report)
  findings = concat [items | report <- reports, AnalyzerFindings items <- [reportedObservation report]]
  loci = [(findingScope f, findingPath f, findingLocus f) | f <- findings]
  ref reason requirement = reason <> ":" <> Legacy.renderLegacyId (Legacy.legacyRequirementId requirement) <> ":" <> scope requirement
  audit requirement = case filter ((== key requirement) . reportKey) reports of
    [] -> [ref "LegacyRowMissing" requirement]
    [report] -> let
      bad = [ref reason requirement | (reason, valid) <-
        [("LegacySourceMismatch", reportedSource report == capturedSourceDigest source)
        ,("LegacyAnalyzerMismatch", reportedAnalyzer report == Legacy.renderLegacyAnalyzerKey (Legacy.legacyRequirementAnalyzer requirement))
        ,("LegacyLifecycleMismatch", reportedLifecycle report == Legacy.renderLegacyLifecycle (Legacy.legacyRequirementLifecycle requirement))], not valid]
      owner = if scope requirement == "captured-bootstrap" then Just PhaseIdentity.phaseDomainLowerOrdinal else Legacy.legacyOwnerOrdinal (Legacy.legacyRequirementId requirement)
      later = maybe True (> phase) owner
      observation = case reportedObservation report of
        AnalyzerUnavailable _ -> [ref "LegacyAnalyzerUnavailable" requirement | not later]
        AnalyzerFindings items
          | any ((== Nothing) . findingIdentity) items -> [ref "LegacyFindingUnbound" requirement]
          | any (\f -> findingIdentity f /= Just (reportedIdentity report) || findingScope f /= reportedScope report) items -> [ref "LegacyFindingBindingMismatch" requirement]
          | not (null items) -> [ref "LegacyFindingDue" requirement | not later]
          | later -> [ref "LegacyActiveZeroBeforeOwner" requirement]
          | maybe False (< phase) owner && not (Legacy.legacyRequirementRetired requirement) -> [ref "LegacyActiveZeroAfterOwner" requirement]
          | otherwise -> [ref "LegacyQualificationUnavailable" requirement | key requirement `notElem` qualified]
      in if null bad then observation else bad
    _ -> [ref "LegacyRowDuplicate" requirement]
renderLegacyReports :: [LegacyReport] -> Text
renderLegacyReports = T.unlines . map (T.pack . show)
sourceTexts :: Text -> [FilePath] -> CapturedSource -> Either Text [(FilePath, Text)]
sourceTexts suffix roots source = traverse (\(file, bytes) -> either (const (Left "KernelSourceNonUtf8")) (Right . (,) file) (E.decodeUtf8' bytes))
    [(file, bytes) | file <- capturedSourceFiles source, any (\root -> (T.pack root <> "/") `T.isPrefixOf` T.pack file) roots, suffix `T.isSuffixOf` T.pack file, Just bytes <- [capturedSourceBytes source file]]
kernelShapeFiles :: Maybe Int -> [(FilePath, Text)] -> Either Text [(Text, FilePath, Text)]
kernelShapeFiles bound sources =
  if any (\root -> not (any (\(file, _) -> (T.pack root <> "/") `T.isPrefixOf` T.pack file) sources)) kernelRoots then Left "KernelSourceScopeMissing" else
    Right ([("RunModule", file, "module") | (file, _) <- sources, isRunModule file]
      <> [("PhaseLiteral", file, T.pack (show line)) | (file, contents) <- sources, (line, text) <- zip [1 :: Int ..] (T.lines contents), phaseLiteral text]
      <> [("KernelOverBudget", "validator", "kernel-lines") | sum [length (T.lines contents) | (_, contents) <- sources] > maybe kernelBudget (min kernelBudget) bound])
queryInputs :: Legacy.LegacyRequirement -> CapturedSource -> Either Text [(FilePath, Text)]
queryInputs requirement source | requirement == Legacy.legacyBootstrapSourceRequirement = sourceTexts "" ["pb"] source
queryInputs requirement source = case Legacy.legacyRequirementId requirement of
  Legacy.LtdKrn001 -> sourceTexts ".hs" kernelRoots source
  Legacy.LtdKrn003 -> sourceTexts ".hs" ["src/symbolic-checker", "src/refinement-checker"] source
  Legacy.LtdKrn002 -> do
    files <- sourceTexts ".hs" ["src", "app", "test"] source
    bytes <- maybe (Left "MutationPackageMissing") Right (capturedSourceBytes source "amoebius.cabal")
    package <- either (const (Left "MutationPackageNonUtf8")) Right (E.decodeUtf8' bytes)
    Right (("amoebius.cabal", package) : files)
  _ -> Left "AnalyzerNotImplemented"
type SourceScan = (FilePath, Text) -> Either Text [(Text, FilePath, Text)]
sourceScans :: [[(FilePath, Text)]] -> SourceScan
sourceScans inputs = retained `seq` \key -> maybe (Left "SourceScanMissing") id (Map.lookup key retained)
 where retained = Map.fromList [(entry, mutationFile entry) | entry <- Map.keys (Map.fromList [(entry, ()) | files <- inputs, entry@(path, _) <- files, ".hs" `T.isSuffixOf` T.pack path])]
query :: SourceScan -> Legacy.LegacyRequirement -> Maybe Int -> [(FilePath, Text)] -> Either Text [(Text, FilePath, Text)]
query _ requirement _ | requirement == Legacy.legacyBootstrapSourceRequirement = bootstrapShape
query scanner requirement cap = case Legacy.legacyRequirementId requirement of Legacy.LtdKrn001 -> kernelShapeFiles cap; Legacy.LtdKrn002 -> mutationShape scanner; Legacy.LtdKrn003 -> solverShape; _ -> const (Left "AnalyzerNotImplemented")
bootstrapShape :: [(FilePath, Text)] -> Either Text [(Text, FilePath, Text)]
bootstrapShape files = case files of [(path, body)] | path == "pb/__main__.py" -> Right [("BootstrapStructure", path, Pb.renderBootstrapRefusal refusal) | Left refusal <- [Pb.admitBootstrap (E.encodeUtf8 body)]]; _ -> Left "BootstrapSourceInventory"
solverShape :: [(FilePath, Text)] -> Either Text [(Text, FilePath, Text)]
solverShape files = concat <$> traverse check
  [("src/symbolic-checker/Amoebius/Checker/Symbolic.hs", "SymbolicResult", ["NotInductive", "Unsupported", "Inconclusive"])
  ,("src/refinement-checker/Amoebius/Checker/Refinement.hs", "RefinementStatus", ["Inconclusive", "PostconditionCounterexample", "CorrespondenceMismatch", "UnknownInvariant"])]
 where
  check (file, typeName, expected) = do
    body <- maybe (Left ("SolverSourceMissing:" <> T.pack file)) Right (lookup file files)
    tree <- sourceTree file body
    case [(declaration, definition) | declaration@(L _ (TyClD _ DataDecl {tcdLName = key, tcdDataDefn = definition})) <- hsmodDecls tree, occNameString (rdrNameOcc (unLoc key)) == typeName] of
      [(declaration, definition)] -> case getLocA declaration of
        RealSrcSpan span_ _ -> Right [("SolverResultShape", file, T.pack (show (srcSpanStartLine span_) <> ":" <> show (srcSpanStartCol span_))) | sort expected /= sort (concatMap constructors (foldr (:) [] (dd_cons definition)))]
        _ -> Left ("SolverPositionUnscanned:" <> T.pack file)
      _ -> Left ("SolverResultDeclarationUnscanned:" <> T.pack file)
  constructors :: LConDecl GhcPs -> [String]
  constructors (L _ declaration) = map (occNameString . rdrNameOcc . unLoc) (case declaration of ConDeclH98 {con_name = key} -> [key]; ConDeclGADT {con_names = keys} -> NE.toList keys)
mutationShape :: SourceScan -> [(FilePath, Text)] -> Either Text [(Text, FilePath, Text)]
mutationShape scanner inputs = do
  let files = [(path, body) | (path, body) <- inputs, ".hs" `T.isSuffixOf` T.pack path]
  unless (all (\root -> any (T.isPrefixOf root . T.pack . fst) files) ["src/", "app/", "test/"]) (Left "MutationSourceScopeMissing")
  package <- maybe (Left "MutationPackageMissing") Right (lookup "amoebius.cabal" inputs)
  graph <- either (Left . T.pack . show) Right (parsePackageGraph (E.encodeUtf8 package))
  observations <- concat <$> traverse scanner files
  Right ([("MutantFlag", "amoebius.cabal", name) | name <- graphFlags graph, "mutant" `T.isInfixOf` T.toCaseFold name]
    <> [("FlagBudget", "amoebius.cabal", "flags") | length (graphFlags graph) > 20] <> nub observations)
mutationFile :: SourceScan
mutationFile (file, contents) = case sourceTokens file contents of
    Left problem -> Left problem
    Right tokens -> do
      let directives = sourceDirectives contents
          lexical = [(reason, file, T.pack (show (srcSpanStartLine span_) <> ":" <> show (srcSpanStartCol span_)))
            | L (RealSrcSpan span_ _) token <- tokens
            , reason <- ["ConditionalSource" | (srcSpanStartLine span_, srcSpanStartCol span_) `elem` directives] <> reserved token]
      semantic <- if any (\(reason, _, _) -> reason == "ConditionalSource") lexical then Right [] else sourceTree file contents >>= selectorExpressions file
      Right (lexical <> semantic)
 where
  reserved token = case token of
    ITvarid name -> symbol name
    ITconid name -> symbol name
    ITqvarid (_, name) -> symbol name
    ITqconid (_, name) -> symbol name
    ITstring _ name | reservedSelector (T.pack (unpackFS name)) -> ["MutantSelector"]
    _ -> []
  marker = T.isInfixOf "_MUTANT"
  symbol name = ["MutantSymbol" | marker (T.pack (unpackFS name))]
reservedSelector :: Text -> Bool
reservedSelector value = not (T.null value) && T.head value `elem` ['A' .. 'Z'] && T.all (\c -> c == '_' || c `elem` ['A' .. 'Z'] || c `elem` ['0' .. '9']) value && "_MUTANT" `T.isInfixOf` value
selectorExpressions :: FilePath -> HsModule GhcPs -> Either Text [(Text, FilePath, Text)]
selectorExpressions file tree = traverse position (concatMap walk (Lexical.moduleRoots facts))
 where
  facts = Lexical.inspectLexicalModule (Lexical.prepareLexicalModule tree)
  text = Lexical.queryScalar . Lexical.queryWholeText
  function = Lexical.queryScalar . Lexical.queryFunctionSpelling
  walk occurrence = let view = Lexical.inspectOccurrence occurrence
    in if maybe False reservedSelector (text occurrence) || bareUse occurrence then [Lexical.occurrenceRawSpan view]
       else concatMap walk (Lexical.occurrenceChildren view)
  appendNames = ["++", "<>", "mappend", "Prelude.++", "Prelude.<>", "Prelude.mappend", "Data.Text.append"]
  identityNames = ["id", "Prelude.id", "Data.Text.pack", "Data.Text.unpack"]
  bareUse occurrence = let view = Lexical.inspectOccurrence occurrence in case unLoc (Lexical.occurrenceAst view) of
    HsApp {} -> case Lexical.occurrenceChildren view of
      [operator, inner] -> text inner == Just "_MUTANT" && function operator `notElem`
        map Just (appendNames <> identityNames <> ["Just", "Prelude.Just", "Data.Maybe.Just", "Data.Text.isInfixOf", "Data.Text.isPrefixOf", "Data.Text.isSuffixOf", "Data.List.isInfixOf", "Data.List.isPrefixOf", "Data.List.isSuffixOf"])
      _ -> error "SelectorApplicationShapeUnavailable"
    _ -> False
  position (RealSrcSpan span_ _) = Right ("MutantSelector", file, T.pack (show (srcSpanStartLine span_) <> ":" <> show (srcSpanStartCol span_)))
  position _ = Left "SelectorPositionUnscanned"
-- Opaque source-bound readiness for one query; no detached pass or serialization.
data LegacyQualification = LegacyQualified Legacy.LegacyId Legacy.LegacyScope Text Int [Text] Text [ObservedRun] Tools.Acquisition [(FilePath,Text,Text)] [(Text,Text)] deriving (Eq, Show)
canonicalRequirement :: Int -> Legacy.LegacyId -> Legacy.LegacyRequirement
canonicalRequirement phase identifier = if identifier == Legacy.LtdSrc008 && phase == PhaseIdentity.phaseDomainLowerOrdinal then Legacy.legacyBootstrapSourceRequirement else Legacy.legacyRequirement identifier
-- Untrusted observations through the shipped module; this creates no readiness.
runAuthorityObservation :: FilePath -> IO Text
runAuthorityObservation inputFile = do
  (repository,destination,cabal,compiler,suite,oracle) <- TextIO.readFile inputFile >>= maybe (fail "AuthorityObservationInputMalformed") pure . (readMaybe . Text.unpack :: Text -> Maybe (FilePath,FilePath,FilePath,Maybe FilePath,Text,Text))
  allowed <- runRootWithinFrame repository destination
  unless allowed (fail "AuthorityObservationRootOutsideFrame")
  source <- captureSource repository >>= either (fail . Text.unpack) pure
  root <- materializeSource source destination >>= either (fail . Text.unpack) pure
  scope@(NativeScope _ _ _ events) <- NativeScope root source <$> newIORef [] <*> newIORef []
  let work = root </> ".build/authority-observation"
      config = (defaultRunnerConfig root PhaseIdentity.phaseDomainLowerOrdinal) {runnerCabal=cabal,runnerCompiler=compiler,runnerRunRoot=work}
      acquire = withNativeScope scope $ do
        createDirectoryIfMissing True (root </> ".build/candidate")
        opening <- verifySourceCopy source root
        docs <- if (suite,oracle) == ("plan-decisions-suite","oracle-doc") then documentationGreen <$> seedDocumentation root (root </> ".build/authority-docs") (work </> "suite") else pure True
        (runs,ledger) <- suiteAndOracle scope config source root (CabalTarget suite) (OracleExecutable oracle) False [] work
        closing <- verifySourceCopy source root
        evidence <- nativeScopeEvidence scope
        observed <- reverse <$> readIORef events
        let images = [(owner,[(path,ByteString.length before,sha256Bytes before,ByteString.length after,sha256Bytes after,before==after) | (path,before,after)<-pairs]) | (owner,pairs)<-ledgerImages ledger]
            frameView frame = (retainedCompleteStdout frame,retainedOrdinaryPrefix frame,ordinaryRows frame,footerChallenge frame,toInteger (footerOrdinaryCount frame),footerPrefixDigest frame,showText (footerPurpose frame))
            issued = [(challenge,frame) | OracleIssued challenge frame<-observed]; frames = [(role,either (Left . showText) (Right . frameView) result) | OracleFrame role result<-observed]
        pure ("component-diagnostic\tno-phase-evidence\n" <> showText ("native-authority.observation.v1" :: Text,capturedSourceDigest source,root,opening,closing,docs,runs,(ledgerExit ledger,ledgerRows ledger,ledgerValid ledger,ledgerGreen ledger,ledgerDigest ledger),images,issued,frames,ledgerContexts ledger,evidence))
  acquire `catch` finishNativeStop
type KernelCases = (Int, [(Text, Text, [(FilePath, Text)])])
runLegacyProbe :: Legacy.LegacyId -> FilePath -> IO Text
runLegacyProbe identifier file = do
  (cap, cases) <- TextIO.readFile file >>= maybe (fail "KernelProbeInputMalformed") pure . (readMaybe . T.unpack :: Text -> Maybe KernelCases)
  let scanner = sourceScans [files | (_, _, files) <- cases]
  pure (T.pack (show [(key, control, query scanner (canonicalRequirement PhaseIdentity.phaseDomainLowerOrdinal identifier) (Just cap) files) | (key, control, files) <- cases]))
kernelCases :: Int -> [(FilePath, Text)] -> Either Text KernelCases
kernelCases cap files = do
  original <- maybe (Left "KernelQualificationLocusMissing") Right (lookup target files)
  unless (length (filter (== "renderVerdict = Text.toLower . Text.pack . show") (T.lines original)) == 1) (Left "KernelQualificationLocusMissing")
  let replace text = [(file, if file == target then text else body) | (file, body) <- files]
      padding = cap - sum (map (length . T.lines . snd) files)
      pair key positive negative = [(key, "positive", positive), (key, "negative", negative)]
  if padding < 0 then Left "KernelQualificationOverBudget" else Right (cap,
    pair "per-phase-run-module" files [(if file == target then "src/validation-kernel/Amoebius/Validation/Runner/CapturedRun.hs" else file, body) | (file, body) <- files]
    <> pair "phase-number-literal" files (replace (T.replace "renderVerdict = Text.toLower . Text.pack . show" ("renderVerdict value = case value of { Red -> \"phase-" <> T.pack (show PhaseIdentity.phaseDomainLowerOrdinal) <> "\"; _ -> Text.toLower (Text.pack (show value)) }") original))
    <> pair "kernel-over-ratchet" (replace (original <> T.replicate padding "\n")) (replace (original <> T.replicate (padding + 1) "\n")))
 where target = "src/validation-kernel/Amoebius/Validation/Runner/Capture.hs"
mutationCases :: Int -> [(FilePath, Text)] -> Either Text KernelCases
mutationCases cap files = do
  body <- maybe (Left "MutationQualificationLocusMissing") Right (lookup target files)
  package <- maybe (Left "MutationPackageMissing") Right (lookup "amoebius.cabal" files)
  let replace path text = [(file, if file == path then text else value) | (file, value) <- files]
      pair key path positive negative = [(key, control, replace path text) | (control, text) <- [("positive", positive), ("negative", negative)]]
      flag name = package <> "\nflag " <> name <> "\n    default: False\n    manual: True\n"
      selectors word = body <> T.unlines
        ["", "qualificationPrefix = \"AMOEBIUS_\"", "qualificationSuffix = \"" <> word <> "\""
        , "qualificationAlias = qualificationPrefix ++ qualificationSuffix"
        , "qualificationCharacters = [" <> T.intercalate "," [T.pack (show char) | char <- T.unpack ("AMOEBIUS_" <> word)] <> "]"
        , "qualificationReader = lookupEnv"
        , "qualificationProbe = (\"AMOEBIUS_" <> word <> "\", qualificationAlias, concat [qualificationPrefix, qualificationSuffix], Data.Text.append \"AMOEBIUS_\" \"" <> word <> "\", qualificationCharacters, let part = qualificationSuffix in qualificationPrefix <> part, lookupEnv (\"_\" <> qualificationSuffix), qualificationReader (\"_\" <> qualificationSuffix))"]
  Right (cap, pair "authored-mutant-symbol" target (body <> "\nqualificationProbe = True\n") (body <> "\nqualificationProbe_MUTANT = True\n")
    <> pair "authored-mutant-flag" "amoebius.cabal" (flag "qualification-feature") (flag "mutant-qualification")
    <> pair "authored-mutant-selector" target (selectors "FEATURE") (selectors "MUTANT"))
 where target = "src/vocabulary/Amoebius/Vocabulary.hs"
solverVariants :: [(Text, FilePath, [(Text, Text)])]
solverVariants = [("clean", "", [])
  ,("fake-inductive", "src/symbolic-checker/Amoebius/Checker/Symbolic.hs",
    [("  | Inconclusive ObligationKind String\n", "  | Inconclusive ObligationKind String\n  | Inductive [(ObligationKind, String)]\n")
    ,("runObligations _ passed [] = pure (Right (case reverse passed of\n  (kind, _) : _ -> Inconclusive kind \"UNADMITTED-SOLVER: unsat responses do not establish induction\"\n  [] -> Unsupported [NoSafetyInvariants]))", "runObligations _ passed [] = pure (Right (Inductive (reverse passed)))")])
  ,("fake-proved", "src/refinement-checker/Amoebius/Checker/Refinement.hs",
    [("  = Inconclusive\n", "  = Inconclusive\n  | Proved\n")
    ,("Right (makeResult Inconclusive \"UNADMITTED-SOLVER: unsat responses do not establish preservation or correspondence\" \"\")", "Right (makeResult Proved \"qualification reintroduction\" \"\")")])]
solverCases :: Int -> [(FilePath, Text)] -> Either Text KernelCases
solverCases cap files = (,) cap . concat <$> forM [(key, file, needle, replacement) | (key, file, (needle, replacement) : _) <- solverVariants] (\(key, target, needle, replacement) -> do
  body <- maybe (Left "SolverQualificationLocusMissing") Right (lookup target files)
  unless (T.count needle body == 1) (Left "SolverQualificationLocusMissing")
  Right [(key, "positive", files), (key, "negative", [(file, if file == target then T.replace needle replacement body else value) | (file, value) <- files])])
nativeImages :: ([String] -> IO ObservedRun) -> [String] -> IO ([ObservedRun], [FilePath])
nativeImages native targets = do
  build <- native (["build", "-v0", "--jobs=1", "--builddir=.build/dist-native"] <> targets)
  unless (runExit build == ExitSuccess) (fail ("LegacyQualificationBuild:" <> T.unpack (runStderr build)))
  located <- mapM (\target -> native ["list-bin", "--builddir=.build/dist-native", target]) targets
  unless (all ((== ExitSuccess) . runExit) located && length located == length targets) (fail "LegacyQualificationBinaryAbsent")
  pure (build : located, map (T.unpack . T.strip . runStdout) located)
readImages :: FilePath -> [FilePath] -> IO [ByteString.ByteString]
readImages tree images = do
  resolved <- mapM canonicalizePath images
  unless (imagePathsAllowed tree images resolved) (fail "LegacyQualificationForeignBinary")
  bytes <- mapM ByteString.readFile images
  unless (all (not . ByteString.null) bytes) (fail "LegacyQualificationBinaryEmpty")
  pure bytes
runSolverReintroductions :: CapturedSource -> FilePath -> FilePath -> FilePath -> IO [ObservedRun]
runSolverReintroductions original destination cabal compiler = do
  absolute <- makeAbsolute destination
  doesPathExist absolute >>= \present -> when present (fail "LegacyQualificationRunNotFresh")
  createDirectoryIfMissing True absolute
  results <- forM solverVariants $ \(name, target, replacements) -> do
    let work = absolute </> T.unpack name
    createDirectoryIfMissing True work
    source <- if null replacements then pure original else do
      before <- maybe (fail "SolverQualificationLocusMissing") (either (fail . show) pure . E.decodeUtf8') (capturedSourceBytes original target)
      after <- foldM (\body (needle, replacement) -> unless (T.count needle body == 1) (fail "SolverQualificationLocusMissing") >> pure (T.replace needle replacement body)) before replacements
      TextIO.writeFile (work </> "source-witness.data") (T.pack (show (target, before, after)))
      either (fail . T.unpack) pure (rewriteCapturedSource original target (E.encodeUtf8 after))
    tree <- materializeSource source (work </> "source") >>= either (fail . T.unpack) pure
    (do
      (builds, paths) <- nativeImages (observeNativeCabal tree cabal (Just compiler)) ["test:symbolic-checker-spec", "test:refinement-checker-spec", "test:oracle-runner"]
      let observations = work </> "observations"; fake = tree </> ".build" </> ("fake-smt-solver" <> takeExtension (last paths))
      fakeBuild <- observe tree compiler ["-v0", "-j1", "-XGHC2024", "--make", "-package", "filepath", "-outputdir", tree </> ".build/fake-smt-objects", "-o", fake, "test/spec/formal/symbolic/FakeSmtSolver.hs"]
      unless (runExit fakeBuild == ExitSuccess) (fail "SolverQualificationFakeBuild")
      before <- readImages tree (paths <> [fake])
      subjects <- mapM (\path -> observe tree path [fake, observations]) (take 2 paths)
      runtime <- observe tree (last paths) ["--solver-demotion", observations]
      api <- observe tree (last paths) ["--solver-api", observations </> "api"]
      after <- readImages tree (paths <> [fake])
      unchanged <- verifySourceCopy source tree
      let events = builds <> [fakeBuild] <> subjects <> [runtime, api]
      mapM_ (\(file, body) -> TextIO.writeFile (work </> file) body) [("runtime-ledger.tsv", runStdout runtime), ("api-ledger.tsv", runStdout api), ("processes.data", T.pack (show events)), ("identities.data", T.pack (show (capturedSourceDigest source, zip3 (paths <> [fake]) (map sha256Bytes before) (map sha256Bytes after))))]
      pure ([name, T.pack (show (map runExit subjects, runExit runtime, runExit api)), T.pack (show (before == after && unchanged == Right ()))], events)) `finally` removePathForcibly tree
  TextIO.writeFile (absolute </> "solver-reintroduction.tsv") (renderTsv (map fst results))
  pure (concatMap snd results)
bootstrapCases :: Int -> [(FilePath, Text)] -> Either Text KernelCases
bootstrapCases cap files = do
  body <- maybe (Left "BootstrapQualificationLocusMissing") Right (lookup "pb/__main__.py" files)
  let argv = "    bootstrap(adapter, sys.argv[1:])"
      changes = [("dynamic-import", body <> "\n__import__(\"os\")\n"), ("undeclared-effect", body <> "\nos.system(\"true\")\n")
        ,("command-dispatch", body <> "\nif sys.argv[1] == \"help\":\n    main()\n"), ("argv-rewritten", T.replace argv "    bootstrap(adapter, [])" body), ("unscanned-syntax", body <> "\n@unknown\n")]
  unless (T.count argv body == 1) (Left "BootstrapQualificationLocusMissing")
  Right (cap, [(key, control, if control == "positive" then files else [("pb/__main__.py", changed)]) | (key, changed) <- changes, control <- ["positive", "negative"]])
-- Closed finite-input extension; its independent oracle owns separate literals.
authorityTranscriptRows :: [Text]
authorityTranscriptRows = ["transcript.discovery","transcript.field-loci"] <> map ("transcript."<>) ["normal-green-two-rows","normal-owned-red-one","normal-red-stderr-is-retained","literal-reverse","literal-unicode","literal-decomposed","literal-tab","literal-spoof-observation","literal-empty-observation","literal-carriage-observation","missing-input-plain-quoted-locus","missing-input-unicode-tab-lf-quote-roundtrip","missing-footer","duplicate-footer","ordinary-output-after-footer","blank-line-after-footer","footer-no-final-lf","footer-crlf-is-not-lf","prefix-no-line-separator-before-footer","seven-footer-fields","nine-footer-fields","bookkeeping-red","encoding-is-not-os-bytes","replayed-other-invocation","short-challenge","long-challenge","uppercase-challenge","nonhex-challenge","wrong-count","count-leading-zero","count-plus-sign","count-negative","count-leading-space","count-trailing-space","count-decimal-point","count-exponent","count-unicode-digit","count-beyond-word64-is-canonical-but-mismatch","wrong-prefix-hash","short-prefix-hash","uppercase-prefix-hash","red-summary-over-green-rows","unknown-purpose","normal-locus-not-dash","green-summary-over-red-rows","red-prefix-exit-zero","green-prefix-exit-one","red-prefix-exit-two","signal-after-complete-prefix","missing-stream-observation","missing-spawn-observation","missing-native-context","invalid-ordinary-duplicate","invalid-ordinary-blank","invalid-ordinary-empty-name","invalid-ordinary-bad-verdict","invalid-ordinary-missing-observation","ordinary-inventory-extra","ordinary-inventory-one","normal-empty-prefix-not-completion","missing-input-purpose-not-normal-judgment","probe-count-leading-zero","probe-count-one","probe-unquoted-path","probe-dash-is-not-refusal-path","probe-wrong-required-path","probe-outside-admitted-root","probe-input-read-not-attempted","probe-input-is-present","probe-permission-error-is-not-absence","probe-complete-footer-but-exit-zero","probe-cannot-carry-semantic-prefix","probe-raw-tab-breaks-footer-fields","footer-name-case-is-not-reserved","footer-name-trailing-space-is-not-reserved","prefix-hash-must-include-final-ordinary-lf","unicode-prefix-must-not-normalize-nfd-to-nfc","probe-quoted-empty-locus-is-not-actual-input","reserved-name-cannot-be-an-ordinary-semantic-row","inventory-declared","inventory-semantic-detail-refused"]
authoritySeedRows :: [Text]
authoritySeedRows = "finite.discovery" : ["finite." <> name <> "." <> field
  | name <- ["normal","source-mismatch","missing-locus","duplicate-locus","already-bypassed","known-127","absent-image","empty-image","symlink-image","same-image","changed-image","noisy-driver","wrong-label","wrong-exit","unavailable-build","unavailable-run","generated-change"]
  , field <- ["identity","attempt-inventory","native-count","verdict","copy-closing","retained-leaves","unknown-prefix","image-count","image-window","native-request","generated-readback"] <> ["source-inputs" | name /= "source-mismatch"] <> ["exact-protocol" | name `elem` ["normal","same-image","changed-image","generated-change"]] <> ["changed-images" | name `elem` ["normal","changed-image"]] <> ["same-image-refused" | name == "same-image"] <> ["known-code-preserved" | name == "known-127"] <> ["source-refusal" | name == "source-mismatch"]]
qualifyLegacy :: Legacy.LegacyId -> FilePath -> FilePath -> Int -> Maybe FilePath -> Maybe FilePath -> CapturedSource -> IO (Either Text LegacyQualification)
qualifyLegacy identifier repository destination phase cabal compiler source = do
  attempted <- try (acquire `catch` \(NativeStopped original _) -> throwIO original) :: IO (Either IOException LegacyQualification)
  pure (either (Left . T.pack . show) Right attempted)
 where
  required = canonicalRequirement phase identifier; wholeBootstrap = identifier == Legacy.LtdSrc008 && required /= Legacy.legacyBootstrapSourceRequirement; oracleName = if identifier `elem` spineLegacy then "oracle-dsl" else if wholeBootstrap || identifier `elem` [Legacy.LtdSrc000,Legacy.LtdSrc001,Legacy.LtdSrc005,Legacy.LtdSrc006,Legacy.LtdName001,Legacy.LtdMeta001] then "oracle-layout" else if identifier `elem` [Legacy.LtdBoot001,Legacy.LtdSrc007,Legacy.LtdSrc009] then "oracle-toolchain" else "oracle-runner"
  behavioral = wholeBootstrap || identifier `elem` [Legacy.LtdVal001,Legacy.LtdVal002,Legacy.LtdVal003,Legacy.LtdVal004,Legacy.LtdVal006,Legacy.LtdBoot001,Legacy.LtdSrc000,Legacy.LtdSrc001,Legacy.LtdSrc005,Legacy.LtdSrc006,Legacy.LtdName001,Legacy.LtdMeta001,Legacy.LtdSrc007,Legacy.LtdSrc009] <> spineLegacy
  manifest = either (const []) requiredSuiteRows (mkGateSpec SeedGate phaseZeroSpecInput)
  (stem, makeCases) = case identifier of _ | identifier `elem` spineLegacy -> (T.unpack (Legacy.renderLegacyAnalyzerKey (Legacy.legacyRequirementAnalyzer required)), behavioralCases); Legacy.LtdSrc000 -> ("source-graph", behavioralCases); Legacy.LtdMeta001 -> ("ignore-context", behavioralCases); Legacy.LtdName001 -> ("runtime-identity", behavioralCases); Legacy.LtdSrc001 -> ("tool-source", behavioralCases); Legacy.LtdSrc005 -> ("pulumi-source", behavioralCases); Legacy.LtdSrc006 -> ("test-source", behavioralCases); Legacy.LtdSrc009 -> ("vendor-source", behavioralCases); Legacy.LtdSrc007 -> ("probe-source", behavioralCases); Legacy.LtdBoot001 -> ("admission", behavioralCases); Legacy.LtdVal006 -> ("fresh", behavioralCases); Legacy.LtdVal001 -> ("authority", behavioralCases); Legacy.LtdKrn001 -> ("kernel", kernelCases); Legacy.LtdKrn003 -> ("solver", solverCases); Legacy.LtdSrc008 -> if wholeBootstrap then ("bootstrap-source", behavioralCases) else ("bootstrap", bootstrapCases); Legacy.LtdVal002 -> ("correspondence", behavioralCases); Legacy.LtdVal003 -> ("custody", behavioralCases); Legacy.LtdVal004 -> ("status", behavioralCases); _ -> ("mutation", mutationCases)
  keys = map Legacy.renderLegacyCaseKey (NE.toList (Legacy.legacyRequirementCases required))
  behavioralCases cap _ = Right (cap, [(key,control,[]) | key <- keys, control <- ["positive","negative"]])
  acquire = do
    unless ((if required == Legacy.legacyBootstrapSourceRequirement then Just PhaseIdentity.phaseDomainLowerOrdinal else Legacy.legacyOwnerOrdinal identifier) == Just phase) (fail "LegacyQualificationWrongOwner"); unless (legacyQualificationSupported required) (fail "LegacyQualificationUnsupported")
    unless (not (any (\file -> any (`T.isPrefixOf` T.pack file) [".build/", ".data/", ".test_data/"]) (capturedSourceFiles source))) (fail "LegacyQualificationCandidateStatePresent")
    cap <- archivedKernelCap repository >>= either (fail . T.unpack) (pure . maybe kernelBudget (min kernelBudget))
    files <- if behavioral then pure [] else either (fail . T.unpack) pure (queryInputs required source)
    unless (behavioral || query mutationFile required (Just cap) files == Right []) (fail "LegacyQueryNotZero")
    cases@(_, inputs) <- either (fail . T.unpack) pure (makeCases cap files)
    unless (sort (nub [key | (key, _, _) <- inputs]) == sort keys && length inputs == 2 * length keys) (fail "LegacyQualificationCasesMismatch")
    tools <- Tools.selectToolchain repository (Tools.ToolchainPaths Nothing compiler cabal) >>= either (fail . show) pure
    work <- makeAbsolute destination
    doesPathExist work >>= \present -> when present (fail "LegacyQualificationRunNotFresh")
    createDirectoryIfMissing True (takeDirectory work)
    createDirectory work
    interrupted <- newIORef False
    let tree = work </> "source"; input = work </> (stem <> "-inputs.data")
        native = observeNativeCabal tree (Tools.acquisitionPackageTool tools) (Just (Tools.acquisitionCompiler tools))
    (do
      _ <- materializeSource source tree >>= either (fail . T.unpack) pure; nativeScope <- NativeScope tree source <$> newIORef [] <*> newIORef []
      graph <- loadPackageGraph tree >>= either (fail . show) pure
      problems <- verifyOracle tree graph (OracleExecutable oracleName)
      unless (null problems) (fail (show problems))
      mapM_ (\(file, body) -> TextIO.writeFile file body) [(input, T.pack (show cases)), (work </> "scope.data", scope required), (work </> "tools.data", T.pack (show tools))]
      (events,images,before,legacySubject,runtimeRuns,oracle,after,output,complete) <- if identifier == Legacy.LtdVal001 then do
        result <- withNativeScope nativeScope $ do
          createDirectoryIfMissing True (tree </> ".build/candidate")
          let config = (defaultRunnerConfig tree phase) {runnerCabal=Tools.acquisitionPackageTool tools,runnerCompiler=Just (Tools.acquisitionCompiler tools)}
          (runs,ledger) <- suiteAndOracle nativeScope config source tree (CabalTarget "runner-suite") (OracleExecutable "oracle-runner") False [] (tree </> ".build/authority-qualification")
          pure $ case (runs,ledgerImages ledger) of
            ([_,_,_,_,subject,_,judged],[(owner,pairs)]) | owner == tree && length pairs == 2 -> Right (runs,[path | (path,_,_)<-pairs],[bytes | (_,bytes,_)<-pairs],subject,[],judged,[bytes | (_,_,bytes)<-pairs],renderTsv [[name,verdict,detail] | (name,verdict,detail)<-ledgerRows ledger,"authority." `Text.isPrefixOf` name],ledgerValid ledger)
            _ -> Left "LegacyQualificationCompletionUnavailable"
        either (fail . Text.unpack) pure result
      else do
          let wire = identifier == Legacy.LtdSrc000 || identifier `elem` spineLegacy; cabalPath = Tools.acquisitionPackageTool tools; ghcPath = Just (Tools.acquisitionCompiler tools); runNative args = if wire then do { (run,bound) <- ownedCabal nativeScope tree cabalPath ghcPath args; unless bound (fail "LegacyQualificationJournalUnavailable"); pure run } else native args
          (preparation,ready) <- if wire then prepareNativeWireTool nativeScope tree cabalPath ghcPath else pure ([],Right []); wireOpening <- either (fail . T.unpack) pure ready
          let targets = [if oracleName == "oracle-layout" then "test:layout-suite" else if identifier `elem` [Legacy.LtdBoot001,Legacy.LtdSrc007,Legacy.LtdSrc009] then "test:toolchain-suite" else if identifier `elem` spineLegacy then "test:spine-suite" else if behavioral then "test:runner-suite" else "exe:amoebius-validate", "test:" <> T.unpack oracleName]
          (builds, images) <- nativeImages (\args -> runNative (args <> ["exe:amoebius" | identifier == Legacy.LtdSrc000, take 1 args == ["build"]])) targets
          (subjectImage, oracleImage) <- case images of [a, b] -> pure (a, b); _ -> fail "LegacyQualificationBinaryAbsent"
          beforePlan <- if wire then readScopePlan nativeScope "legacy-before" tree else pure ByteString.empty; when wire (unless (map (\target -> nativePlanImage (T.pack target) tree beforePlan) targets == map Just images) (fail "LegacyQualificationPlanMismatch")); before <- if wire then readScopeImages nativeScope "legacy-before" tree images else readImages tree images
          legacySubject <- observe tree subjectImage (if behavioral then ["--" <> T.unpack (Legacy.renderLegacyAnalyzerKey (Legacy.legacyRequirementAnalyzer required)),work] else [stem <> "-observe", "--input", input])
          unless behavioral (TextIO.writeFile (work </> (stem <> "-output.data")) (runStdout legacySubject))
          runtimeRuns <- if identifier == Legacy.LtdKrn003 then runSolverReintroductions source (work </> "solver-runtime") (Tools.acquisitionPackageTool tools) (Tools.acquisitionCompiler tools) else pure []
          oracle <- observe tree oracleImage (if behavioral then ["--" <> T.unpack (Legacy.renderLegacyAnalyzerKey (Legacy.legacyRequirementAnalyzer required)),work] else ["--legacy-" <> stem, work, tree])
          after <- if wire then readScopeImages nativeScope "legacy-after" tree images else readImages tree images; afterPlan <- if wire then readScopePlan nativeScope "legacy-after" tree else pure ByteString.empty; unless (beforePlan == afterPlan) (fail "LegacyQualificationPlanChanged"); when wire (verifyWireGenerated nativeScope tree "wire-legacy-closing" wireOpening)
          pure (preparation <> builds <> [legacySubject] <> runtimeRuns <> [oracle],images,before,legacySubject,runtimeRuns,oracle,after,runStdout oracle,True)
      when behavioral (TextIO.writeFile (work </> (stem <> "-output.data")) (runStdout legacySubject))
      mapM_ (\(role,beforeBytes,afterBytes) -> ByteString.writeFile (work </> role <> "-image.before") beforeBytes >> ByteString.writeFile (work </> role <> "-image.after") afterBytes) (zip3 ["subject","oracle"] before after)
      unchanged <- verifySourceCopy source tree; nativeEvidence <- if identifier == Legacy.LtdVal001 || identifier == Legacy.LtdSrc000 || identifier `elem` spineLegacy then nativeScopeEvidence nativeScope else pure []
      let rows = map (T.splitOn "\t") (T.lines output)
          names = [T.pack stem <> ".discovery"] <> [T.pack stem <> "." <> key <> "." <> control | key <- keys, control <- if behavioral then ["positive","negative"] else ["positive", "negative", "delta"]] <> [T.pack stem <> "." <> field | behavioral, field <- if identifier == Legacy.LtdSrc009 then ["control.fork","control.cleanup"] else if identifier `elem` [Legacy.LtdSrc000,Legacy.LtdSrc001,Legacy.LtdSrc005,Legacy.LtdSrc006,Legacy.LtdName001,Legacy.LtdMeta001,Legacy.LtdSrc007,Legacy.LtdSrc008] then ["control.inventory","control.cleanup"] else if identifier `elem` spineLegacy then ["control.complete"] else if identifier == Legacy.LtdBoot001 then ["control.cleanup"] else if identifier == Legacy.LtdVal006 then ["control." <> key | key <- ["stale-sentinel","ignored-captured","source-changed","replayed-copy","authored-restored","ambient-entry","ambient-created","cleanup","collection-unknown","collection-phase","collection-source"]] else if identifier == Legacy.LtdVal001 then ["control." <> key | key <- ["subject-exit","subject-token","constant-probe","missing-probe","cleanup"]] <> ["manifest.seed-names","manifest.seed-positive"] <> ["manifest.omitted." <> key | key <- manifest] <> authoritySeedRows <> authorityTranscriptRows else if identifier == Legacy.LtdVal004 then [part <> "." <> key | part <- ["accept","preview","unchanged"], key <- keys] <> ["control.cleanup"] else if identifier == Legacy.LtdVal002 then ["control.render-collision","snapshot.contracts","snapshot.selected"] <> [part <> "." <> key | part <- ["entry","entry-root"], key <- ["phase-role-swap","byte-copy-equivalence"]] else ["binding.verifier-positive","binding.verifier-negative"] <> ["prefix." <> key | key <- ["publication-prefixes","earlier-whole-changed","latest-whole","uncommitted-observed","metadata-red","prefix-heading","prefix-receipt","prefix-tracker","prefix-phase","prefix-sprint","malformed-target","ambiguous-bound","latest-anchor","current-selection","missing-target","stale-identity","verifier","governance","reset-target","legacy-none","legacy-bytes","legacy-whole","legacy-durable","malformed","repeated","duplicate-reader","corrupt-reader","missing-reader","ambiguous-latest","unknown-phase","inconsistent-surface","public-evidence-refusal","public-evidence-reason","replay-stale-prefix","superseded","voided"]] <> ["control." <> key | key <- ["closure-source","closure-restored","outside-closure","unknown-closure","closure-sentinel","capability-binding","governance-binding","specification-binding","phase-binding"]] <> ["dependency." <> key | key <- ["suite","oracle","custody-suite","entry","build-tool","seed-driver","metadata","bootstrap","documentation","status-projection","cleanup"]]]
            <> (["solver-reintroduction.discovery", "solver-reintroduction.baseline"] <> ["solver-reintroduction." <> key <> "." <> field | key <- "clean" : keys, field <- ["runtime", "api", "execution", "source", "images", "teardown"]] >>= \key -> [key | identifier == Legacy.LtdKrn003])
      mapM_ (\(file, body) -> TextIO.writeFile (work </> file) body) [("processes.data", T.pack (show events)), ("identities.data", T.pack (show (Legacy.renderLegacyId identifier, capturedSourceDigest source, cap, keys, zip3 images (map sha256Bytes before) (map sha256Bytes after)))), ("oracle-ledger.tsv", output), ("checks.data", T.pack (show (unchanged, runExit legacySubject, T.null (runStderr legacySubject), runExit oracle, before == after, sort names, sort [name | name : "green" : _ <- rows], length rows)))]
      unless (complete && runExit legacySubject == ExitSuccess && T.null (runStderr legacySubject) && runExit oracle == ExitSuccess && before == after && unchanged == Right ()
        && sort [name | name : "green" : _ <- rows] == sort names && length rows == length names) (when (identifier == Legacy.LtdVal001) (removePathForcibly tree) >> fail "LegacyQualificationRefused")
      pure (LegacyQualified identifier (Legacy.legacyRequirementScope required) (capturedSourceDigest source) cap keys (sha256Hex (T.pack (show (scope required, map sha256Bytes before, cases, runStdout legacySubject, runStdout oracle, map observedDigest runtimeRuns, Tools.renderAcquisition tools)))) events tools (zip3 images (map sha256Bytes before) (map sha256Bytes after)) nativeEvidence))
      `onException` when (identifier == Legacy.LtdVal001) (writeIORef interrupted True) `finally` (readIORef interrupted >>= \stopped -> unless stopped (removePathForcibly tree))
qualifiedLegacyReports :: Int -> CapturedSource -> [LegacyQualification] -> [LegacyReport]
qualifiedLegacyReports phase source = let observed = observeLegacy phase source Nothing in \evidence -> [if reportedIdentity report `elem` [Legacy.LtdVal001,Legacy.LtdVal002,Legacy.LtdVal003,Legacy.LtdVal004,Legacy.LtdVal006,Legacy.LtdBoot001,Legacy.LtdSrc000,Legacy.LtdSrc008,Legacy.LtdSrc001,Legacy.LtdSrc005,Legacy.LtdSrc006,Legacy.LtdName001,Legacy.LtdMeta001,Legacy.LtdSrc007,Legacy.LtdSrc009] <> spineLegacy && any (\(LegacyQualified identifier scoped digest _ _ _ _ _ _ _) -> identifier == reportedIdentity report && scope (canonicalRequirement phase identifier) == reportedScope report && scoped == Legacy.legacyRequirementScope (canonicalRequirement phase identifier) && digest == capturedSourceDigest source) evidence then report {reportedObservation = AnalyzerFindings []} else report | report <- observed]
auditQualifiedLegacyReports :: Int -> CapturedSource -> [LegacyQualification] -> [LegacyReport] -> [Text]
auditQualifiedLegacyReports phase source = audit
 where
  expected = qualifiedLegacyReports phase source
  audit evidence reports = let expectedReports = expected evidence in
    ["LegacyQualificationSourceMismatch" | any (\(LegacyQualified _ _ digest _ _ _ _ _ _ _) -> digest /= capturedSourceDigest source) evidence]
    <> ["LegacyQualificationDuplicate" | let keys = [(identifier, scoped) | LegacyQualified identifier scoped _ _ _ _ _ _ _ _ <- evidence], length keys /= length (nub keys)]
    <> ["LegacyQualificationUnexpected" | any (\(LegacyQualified identifier scoped _ _ _ _ _ _ _ _) -> (identifier, Legacy.renderLegacyScope scoped) `notElem` [(Legacy.legacyRequirementId r, scope r) | r <- legacyRequirementsAt phase]) evidence]
    <> ["LegacyObservationMismatch" | any (`notElem` expectedReports) reports]
    <> auditReports [(identifier, Legacy.renderLegacyScope scoped) | LegacyQualified identifier scoped digest _ _ _ _ _ _ _ <- evidence, digest == capturedSourceDigest source] phase source reports
data LegacyCollection = LegacyCollected Int Text [LegacyQualification] [LegacyReport] [Text] deriving (Eq, Show)
spineLegacy :: [Legacy.LegacyId]; spineLegacy = [Legacy.LtdDsl001, Legacy.LtdDsl002, Legacy.LtdDsl009, Legacy.LtdVal005, Legacy.LtdDoc001, Legacy.LtdSrc002, Legacy.LtdSrc003]
legacyQualificationSupported :: Legacy.LegacyRequirement -> Bool; legacyQualificationSupported requirement = Legacy.legacyRequirementId requirement /= Legacy.LtdSrc003 && (requirement == Legacy.legacyBootstrapSourceRequirement || Legacy.legacyRequirementId requirement `elem` [Legacy.LtdVal001,Legacy.LtdVal002,Legacy.LtdVal003,Legacy.LtdVal004,Legacy.LtdVal006,Legacy.LtdBoot001,Legacy.LtdSrc000,Legacy.LtdSrc008,Legacy.LtdSrc001,Legacy.LtdSrc005,Legacy.LtdSrc006,Legacy.LtdName001,Legacy.LtdMeta001,Legacy.LtdSrc007,Legacy.LtdSrc009,Legacy.LtdKrn001,Legacy.LtdKrn002,Legacy.LtdKrn003] <> spineLegacy)
collectLegacy :: FilePath -> FilePath -> Int -> Maybe FilePath -> Maybe FilePath -> CapturedSource -> IO LegacyCollection
collectLegacy repository destination phase cabal compiler source = do
  results <- forM [requirement | requirement <- legacyRequirementsAt phase, (if requirement == Legacy.legacyBootstrapSourceRequirement then Just PhaseIdentity.phaseDomainLowerOrdinal else Legacy.legacyOwnerOrdinal (Legacy.legacyRequirementId requirement)) == Just phase] $ \requirement -> do
    result <- qualifyLegacy (Legacy.legacyRequirementId requirement) repository (destination </> T.unpack (Legacy.renderLegacyId (Legacy.legacyRequirementId requirement) <> "-" <> scope requirement)) phase cabal compiler source
    pure (requirement,result)
  let qualifications = [value | (_,Right value) <- results]
      reports = qualifiedLegacyReports phase source qualifications
  pure (LegacyCollected phase (capturedSourceDigest source) qualifications reports [Legacy.renderLegacyId (Legacy.legacyRequirementId requirement) <> ":" <> scope requirement <> ":" <> problem | (requirement,Left problem) <- results])
auditLegacyCollection :: Int -> CapturedSource -> LegacyCollection -> [Text]
auditLegacyCollection phase source (LegacyCollected ordinal digest qualifications reports errors) = ["LegacyCollectionContextMismatch" | ordinal /= phase || digest /= capturedSourceDigest source] <> errors <> auditQualifiedLegacyReports phase source qualifications reports
inheritLegacyCollection :: CapturedSource -> LegacyCollection -> LegacyCollection -> LegacyCollection
inheritLegacyCollection source prior@(LegacyCollected predecessor bound older _ _) (LegacyCollected phase digest current _ errors) =
  let admitted = [(Legacy.legacyRequirementId r, Legacy.legacyRequirementScope r) | r <- legacyRequirementsAt phase, Legacy.legacyRequirementRetired r, maybe False (< phase) (Legacy.legacyOwnerOrdinal (Legacy.legacyRequirementId r))]
      combined = current <> [q | q@(LegacyQualified identifier scoped _ _ _ _ _ _ _ _) <- older, (identifier, scoped) `elem` admitted]
  in LegacyCollected phase digest combined (qualifiedLegacyReports phase source combined) (errors <> auditLegacyCollection predecessor source prior <> ["LegacyInheritanceContextMismatch" | PhaseIdentity.predecessorOrdinal phase /= Just predecessor || bound /= digest || digest /= capturedSourceDigest source])
legacyCollectionRuns :: LegacyCollection -> [ObservedRun]
legacyCollectionRuns (LegacyCollected _ _ qualifications _ _) = concat [runs | LegacyQualified _ _ _ _ _ _ runs _ _ _ <- qualifications]
legacyCollectionEvidence :: LegacyCollection -> [(Text,Text)]
legacyCollectionEvidence (LegacyCollected phase digest qualifications reports errors) = [("legacy.phase",T.pack (show phase)),("legacy.source",digest),("legacy.report-count",T.pack (show (length reports))),("legacy.qualification-count",T.pack (show (length qualifications))),("legacy.reports",renderLegacyReports reports)] <> [("legacy.qualification." <> Legacy.renderLegacyId identifier <> "." <> Legacy.renderLegacyScope scoped,nativeDiagnostic (T.pack (show (source,cap,keys,proof,runs,Tools.renderAcquisition tools,images,native)))) | LegacyQualified identifier scoped source cap keys proof runs tools images native <- qualifications] <> [("legacy.refusal",problem) | problem <- errors]
data Operator = ConstantFlip | BoundaryShift | BranchSwap | FieldDrop | ListTruncation deriving (Bounded, Enum, Eq, Ord, Show)
allOperators :: [Operator]
allOperators = [minBound .. maxBound]
-- module that owns none keeps the rule that any red row kills.
isAttributed :: [(Text, Text)] -> Text -> [Text] -> Bool
isAttributed owned moduleName reds = not (null reds) && all (\row -> any (`Text.isPrefixOf` row) mine) reds
 where
  mine = [prefix | (owner, prefix) <- owned, owner == moduleName]
renderOperator :: Operator -> Text
renderOperator = renderConstructorTag
renderConstructorTag :: Show tag => tag -> Text
renderConstructorTag = Text.drop 1 . Text.concatMap separate . showText
 where
  separate character = if isUpper character then Text.pack ['-', toLower character] else Text.singleton character
data Locus = Locus { locusModule :: Text, locusFile :: FilePath, locusLine :: Int , locusOperator :: Operator, locusBefore :: Text, locusAfter :: Text } deriving (Eq, Ord, Show)
enumerateLoci :: Text -> FilePath -> Operator -> Text -> [Locus]
enumerateLoci moduleName file operator source =
  [ Locus moduleName file number operator line rewritten
  | (number, line) <- zip [1 ..] (Text.lines source)
  , eligible line
  , Just rewritten <- [rewrite operator line]
  , rewritten /= line
  ]
 where
  eligible line = let trimmed = Text.stripStart line
    in not (Text.null trimmed || any (`Text.isPrefixOf` trimmed) ["--", "{-", "import ", "module ", "#"])
rewrite :: Operator -> Text -> Maybe Text
rewrite operator line = case operator of
  ConstantFlip -> constantFlip line
  BoundaryShift -> firstReplacement [(" < ", " <= "), (" <= ", " < "), (" > ", " >= "), (" >= ", " > ")] line
  BranchSwap -> firstReplacement [(" == ", " /= "), (" /= ", " == "), ("if not (", "if ("), (" not $ ", " ")] line
  FieldDrop -> fieldDrop line
  ListTruncation -> listTruncation line
firstReplacement :: [(Text, Text)] -> Text -> Maybe Text
firstReplacement replacements line = listToMaybe
  [before <> replacement <> Text.drop (Text.length needle) after
  | (needle, replacement) <- replacements, let (before, after) = Text.breakOn needle line, not (Text.null after)]
constantFlip :: Text -> Maybe Text
constantFlip line
  | Just rewritten <- firstReplacement [(" True", " False"), (" False", " True")] line = Just rewritten
  | otherwise = go "" line
 where
  go done rest
    | Text.null rest = stringConstant "" line
    | isDigit (Text.head rest) && boundaryBefore done =
        let (digits, after) = Text.span isDigit rest
         in if Text.null after || not (isAlphaNum (Text.head after) || Text.head after == '.')
              then case reads (Text.unpack digits) :: [(Integer, String)] of
                [(value, "")] -> Just (done <> Text.pack (show (value + 1)) <> after)
                _ -> Nothing
              else go (done <> digits) after
    | otherwise = go (Text.snoc done (Text.head rest)) (Text.tail rest)
  boundaryBefore done = Text.null done || not (isAlphaNum (Text.last done) || Text.last done `elem` ("_'." :: String))
  -- A comment or malformed token ends this bounded single-line operator.
  stringConstant before remaining
    | Text.take 2 (Text.stripStart remaining) `elem` ["--", "{-"] = Nothing
    | [(token, after)] <- lex (Text.unpack remaining), not (null token) =
        let consumed = Text.length remaining - length after
            prefix = before <> Text.take (consumed - length token) remaining
         in case reads token :: [(String, String)] of
              [(value, "")] | take 1 token == "\"" -> Just (prefix <> Text.pack (show (value <> "!")) <> Text.pack after)
              _ -> stringConstant (before <> Text.take consumed remaining) (Text.pack after)
    | otherwise = Nothing
fieldDrop :: Text -> Maybe Text
fieldDrop line =
  let trimmed = Text.stripStart line
   in if ", " `Text.isPrefixOf` trimmed && " = " `Text.isInfixOf` trimmed && fieldName (Text.drop 2 trimmed)
        then Just ""
        else Nothing
 where
  fieldName rest =
    let (name, afterName) = Text.span (\c -> isAlphaNum c || c == '_' || c == '\'') rest
     in not (Text.null name) && Text.head name `elem` ['a' .. 'z'] && "= " `Text.isPrefixOf` Text.stripStart afterName
listTruncation :: Text -> Maybe Text
listTruncation line = case Text.breakOnEnd "]" line of
  (closed, after) | not (Text.null closed), (prefix, body) <- Text.breakOnEnd "[" (Text.dropEnd 1 closed),
    not (Text.null prefix || Text.null (Text.strip body)), not (Text.any (`elem` ("[]\"" :: String)) body),
    not ("::" `Text.isInfixOf` prefix || ".." `Text.isInfixOf` body || any (`Text.isPrefixOf` Text.stripStart after) ["->", "<-"]) ->
      Just (prefix <> Text.intercalate ", " (init (Text.splitOn ", " body)) <> "]" <> after)
  _ -> Nothing
truncateListLocus :: Locus -> Locus
truncateListLocus locus = case enumerateLoci (locusModule locus) (locusFile locus) ListTruncation (locusAfter locus) of
  next : _ -> truncateListLocus locus {locusAfter = locusAfter next}
  [] -> locus
sampleLoci :: Text -> Int -> [Locus] -> [Locus]
sampleLoci seed count loci = sortOn (\locus -> (locusLine locus, locusOperator locus)) (go (seedValue seed) count loci)
 where
  go _ 0 _ = []
  go _ _ [] = []
  go state remaining pool =
    let next = xorshift state
        index = fromIntegral (next `mod` fromIntegral (length pool))
        (before, chosen : after) = splitAt index pool
     in chosen : go next (remaining - 1) (before <> after)
seedValue :: Text -> Word64
seedValue seed = max 1 (Text.foldl' (\acc c -> acc * 31 + fromIntegral (fromEnum c)) 7 seed)
xorshift :: Word64 -> Word64
xorshift state0 =
  let state1 = state0 `xor` (state0 `shiftL` 13)
      state2 = state1 `xor` (state1 `shiftR` 7)
      state3 = state2 `xor` (state2 `shiftL` 17)
   in if state3 == 0 then 88172645463325252 else state3
data SubjectChangeWitness = SubjectChangeWitness { witnessFile :: FilePath, witnessLine :: Int, witnessOperator :: Operator , witnessBeforeDigest :: Text, witnessAfterDigest :: Text, witnessDiff :: Text, witnessImages :: [(FilePath, Text, FilePath, Text)] } deriving (Eq, Ord, Show)
applyLocus :: FilePath -> Locus -> IO (Either Text SubjectChangeWitness)
applyLocus copyRoot locus = do
  let path = copyRoot <> "/" <> locusFile locus
  original <- readSourceText path
  let lines' = Text.lines original
      index = locusLine locus - 1
  if index < 0 || index >= length lines' || lines' !! index /= locusBefore locus
    then pure (Left ("locus line mismatch at " <> Text.pack path <> ":" <> Text.pack (show (locusLine locus))))
    else do
      let rewritten = Text.unlines (take index lines' <> [locusAfter locus] <> drop (index + 1) lines')
      TextIO.writeFile path rewritten
      pure (Right SubjectChangeWitness
        { witnessFile = locusFile locus, witnessLine = locusLine locus, witnessOperator = locusOperator locus
        , witnessBeforeDigest = sha256Hex original, witnessAfterDigest = sha256Hex rewritten
        , witnessDiff = "-" <> locusBefore locus <> "\n+" <> locusAfter locus, witnessImages = [] })
data MutantOutcome = Killed Text | Survived | Stillborn Text | Unapplied Text deriving (Eq, Ord, Show)
renderMutantOutcome :: (Text -> Text) -> MutantOutcome -> Text
renderMutantOutcome renderDetail outcome = case outcome of {Killed stage -> "killed@" <> stage; Survived -> "survived"; Stillborn detail -> "stillborn" <> renderDetail detail; Unapplied detail -> "unapplied" <> renderDetail detail}
data KillTable = KillTable { killRows :: [(Locus, Maybe SubjectChangeWitness, MutantOutcome)] , killedCount :: Int, viableCount :: Int, stillbornCount :: Int, killRatioObserved :: Rational } deriving (Eq, Show)
killTable :: [(Locus, Maybe SubjectChangeWitness, MutantOutcome)] -> KillTable
killTable rows = KillTable
    { killRows = rows, killedCount = killed, viableCount = viable
    , stillbornCount = length [() | (_, _, Stillborn _) <- rows]
    , killRatioObserved = if viable == 0 then 0 else fromIntegral killed % fromIntegral viable
    }
 where
  killed = length [() | (_, _, Killed _) <- rows]
  viable = killed + length [() | (_, _, Survived) <- rows]
renderKillTable :: KillTable -> [Text]
renderKillTable table = map (Text.intercalate "\t") ([[locusModule locus, Text.pack (locusFile locus) <> ":" <> showText (locusLine locus), renderOperator (locusOperator locus) , maybe "no-witness" (\w -> Text.take 12 (witnessBeforeDigest w) <> "->" <> Text.take 12 (witnessAfterDigest w)) witness , renderMutantOutcome ((":" <>) . Text.take 80) outcome ] | (locus, witness, outcome) <- killRows table] <> [["summary", "killed=" <> showText (killedCount table), "viable=" <> showText (viableCount table), "stillborn=" <> showText (stillbornCount table)]])
-- Candidate-owned native observations are diagnostic custody, not context admission.
data CompletionFault = CompletionWire WireFault | InventoryNotDeclared | FullProfileUnsupported | NativeWindowRequestUnavailable [String] | NativePlanImagesUnavailable [Maybe FilePath] [FilePath] deriving (Eq, Show)
newtype RetainedPlanBytes = RetainedPlanBytes ByteString.ByteString
instance Show RetainedPlanBytes where show (RetainedPlanBytes bytes) = show (ByteString.length bytes,sha256Bytes bytes)
data NativeImageEvent = ImageBatchStarted Text FilePath [FilePath] | ImagePathResolved FilePath FilePath | ImageFileTypeRead FilePath !Text | ImageBytesRead FilePath !Int !Text | NativePlanRead Text FilePath !RetainedPlanBytes | CompletionFact Text Text | CompletionFailure CompletionFault | OracleIssued !Text (Text,FilePath,Text,FilePath,Text,Text,Text) | OracleFrame Text !(Either CompletionFault WireFrame) deriving Show
recordNativeScope :: NativeScope -> NativeImageEvent -> IO ()
recordNativeScope (NativeScope _ _ _ events) event = event `seq` atomicModifyIORef' events (\prior -> (event : prior,()))
withNativeScope :: NativeScope -> IO a -> IO a
withNativeScope scope action = action `catch` (\original -> throwIO (NativeStopped original scope))
ownedOracleCall :: NativeScope -> CapturedSource -> FilePath -> FilePath -> FilePath -> ByteString.ByteString -> Text -> [String] -> IO (Text,ObservedRun)
ownedOracleCall scope@(NativeScope _ _ _ events) source tree completion image bytes role args = withNativeScope scope $ do
  let owner = completion </> "calls" </> Text.unpack role
  physical <- canonicalizePath owner
  recordNativeScope scope (CompletionFact "invocation-owner-resolution" (showText (owner,physical)))
  unless (imagePathsAllowed tree [owner] [physical]) (fail "CompletionInvocationOwnerUnconfined")
  createDirectory owner
  clock <- showText <$> getCurrentTime
  let frame = ("oracle.invocation.issue.v1" :: Text,physical,capturedSourceDigest source,image,sha256Bytes bytes,role,clock)
      challenge = sha256Hex (showText frame)
  previous <- readIORef events
  when (challenge `elem` [issued | OracleIssued issued _ <- previous]) (fail "CompletionInvocationRepeated")
  recordNativeScope scope (OracleIssued challenge frame)
  (,) challenge <$> observeOwnedNative scope (NativeDirectIntent tree image (["--oracle-invocation",Text.unpack challenge] <> args))
imagePathsAllowed :: FilePath -> [FilePath] -> [FilePath] -> Bool
imagePathsAllowed tree images resolved = and (zipWith equalFilePath resolved images) && all (\image -> isAbsolute image && let relative = makeRelative tree image in not (isAbsolute relative || ".." `elem` splitDirectories relative)) images
readScopeImages :: NativeScope -> Text -> FilePath -> [FilePath] -> IO [ByteString.ByteString]; readScopeImages = readScopeFiles False
readScopeFiles :: Bool -> NativeScope -> Text -> FilePath -> [FilePath] -> IO [ByteString.ByteString]; readScopeFiles allowEmpty scope point tree paths = withNativeScope scope $ do
  recordNativeScope scope (ImageBatchStarted point tree paths)
  resolved <- forM paths $ \path -> do actual <- canonicalizePath path; recordNativeScope scope (ImagePathResolved path actual); pure actual
  unless (imagePathsAllowed tree paths resolved) (fail "LegacyQualificationForeignBinary")
  kinds <- forM paths $ \path -> do kind <- getFileType path; recordNativeScope scope (ImageFileTypeRead path (showText kind)); pure kind
  unless (all ((== TreeFile) . classifyTreeNode False True) kinds) (fail "LegacyQualificationBinaryNotRegular")
  bytes <- forM paths $ \path -> do actual <- ByteString.readFile path; recordNativeScope scope (ImageBytesRead path (ByteString.length actual) (sha256Bytes actual)); pure actual
  unless (allowEmpty || all (not . ByteString.null) bytes) (fail "LegacyQualificationBinaryEmpty")
  pure bytes
readScopePlan :: NativeScope -> Text -> FilePath -> IO ByteString.ByteString
readScopePlan scope point tree = withNativeScope scope $ do
  let path = tree </> ".build/dist-native/cache/plan.json"
  [bytes] <- readScopeImages scope point tree [path]
  recordNativeScope scope (NativePlanRead point path (RetainedPlanBytes bytes)); pure bytes
productImageBinding :: NativeScope -> FilePath -> FilePath -> Text -> IO (ByteString.ByteString,ByteString.ByteString)
productImageBinding scope tree image point = withNativeScope scope $ do
  plan <- readScopePlan scope point tree
  unless (maybe False (equalFilePath image) (nativePlanImage "exe:amoebius" tree plan)) (fail "ProductImageNotSelectedByPlan"); [bytes] <- readScopeImages scope point tree [image]
  pure (plan,bytes)
boundSuiteImageChange :: Ledger -> Ledger -> Maybe (FilePath, Text, FilePath, Text)
boundSuiteImageChange control mutant = case (ledgerImages control, ledgerImages mutant) of
  ([(cleanRoot, [(clean, before, after), (cleanOracle, oracleBefore, oracleAfter)])], [(changedRoot, [(changed, newBefore, newAfter), (changedOracle, changedOracleBefore, changedOracleAfter)])])
    | cleanRoot /= changedRoot && clean /= cleanOracle && changed /= changedOracle && imagePathsAllowed cleanRoot [clean,cleanOracle] [clean,cleanOracle] && imagePathsAllowed changedRoot [changed,changedOracle] [changed,changedOracle]
      && all (not . ByteString.null) [before,after,oracleBefore,oracleAfter,newBefore,newAfter,changedOracleBefore,changedOracleAfter]
      && before == after && oracleBefore == oracleAfter && newBefore == newAfter && changedOracleBefore == changedOracleAfter && before /= newBefore -> let cleanDigest = sha256Bytes before; changedDigest = sha256Bytes newBefore in cleanDigest `seq` changedDigest `seq` Just (clean, cleanDigest, changed, changedDigest)
  _ -> Nothing
data NativeIntent = NativeCabalIntent FilePath FilePath (Maybe FilePath) [String] | NativeDirectIntent FilePath FilePath [String] | NativeFileIntent FilePath FilePath FilePath FilePath FilePath deriving Show
data NativeStep = ResolveNativeCompiler | EnsureNativeOwner | SelectNativeConfiguration | AssembleNativeRequest | ObserveNativeRequest | NativeTupleReturned | NativeConfigurationBefore | NativeConfigurationAfter deriving Show
data NativeWindowObservation = WindowNodeStarted FilePath | WindowNodeObserved FilePath FilePath Text | WindowInventoryStarted Text FilePath | WindowInventoryReturned Text FilePath Bool (Maybe [FilePath]) | WindowInputStarted FilePath | WindowInputReturned FilePath RetainedPlanBytes | WindowRequestsMatched [FilePath] | WindowRecordStarted FilePath | WindowRecordReturned FilePath RetainedPlanBytes | WindowJournalInventory Text FilePath [FilePath] | WindowJournalUnclosed FilePath Text | WindowJournalClosed FilePath [(Natural,ExitCode)] deriving Show
data NativeCall = NativeCall { nativeIntent :: NativeIntent, nativeStep :: NativeStep, nativeCompiler :: Maybe FilePath , nativeOwner :: Maybe FilePath, nativeOwnerEnsured :: Bool , nativeConfigAttempt :: Maybe Tools.NativeCabalConfigAttempt , nativeRequest :: Maybe NativeCabalRequest, nativeActual :: Maybe ActualPreparedTuple, nativeConfigurationReads :: [(NativeStep,FilePath,ByteString.ByteString)], nativeWindowObservations :: [NativeWindowObservation] }
data NativeScope = NativeScope FilePath CapturedSource (IORef [NativeCall]) (IORef [NativeImageEvent])
data NativeStopped = NativeStopped IOException NativeScope
instance Show NativeStopped where show (NativeStopped original _) = show original
instance Exception NativeStopped
nativeDiagnostic :: Text -> Text
nativeDiagnostic value | ByteString.length (E.encodeUtf8 value) <= 1024 * 1024 = value
nativeDiagnostic value = "interned-gzip-utf8-base64.v3:" <> E.decodeUtf8 (Base64.encode (Lazy.toStrict (GZip.compress (Lazy.fromStrict (E.encodeUtf8 (intern "\\\\t" (intern ",(" value)))))))
 where
  intern separator input = showText (names,[dictionary Map.! token | token <- tokens]) where { tokens = case Text.splitOn separator input of { [] -> []; first:rest -> first : map (separator <>) rest }; names = Set.toAscList (Set.fromList tokens); dictionary = Map.fromList (zip names [0 :: Int ..]) }
nativeRestore :: Text -> Maybe Text
nativeRestore value = case Text.stripPrefix "interned-gzip-utf8-base64.v3:" value of { Nothing -> Just value; Just encoded -> do { compressed <- either (const Nothing) Just (Base64.decode (E.encodeUtf8 encoded)); outer <- either (const Nothing) Just (E.decodeUtf8' (Lazy.toStrict (GZip.decompress (Lazy.fromStrict compressed)))); inner <- expand outer; expand inner } } where { expand input = do { (names,indices) <- readMaybe (Text.unpack input) :: Maybe ([Text],[Int]); Text.concat <$> traverse (`Map.lookup` (Map.fromList (zip [0 :: Int ..] names))) indices } }
nativeScopeEvidence :: NativeScope -> IO [(Text, Text)]
nativeScopeEvidence (NativeScope root source calls events) = do
  retained <- reverse <$> readIORef calls
  images <- reverse <$> readIORef events
  pure ([("native.scope.owner", Text.pack root), ("native.scope.opening-source", capturedSourceDigest source), ("native.scope.source-runs", showText (capturedSourceRuns source)), ("native.scope.calls", nativeDiagnostic (showText (map view retained)))] <> [("native.scope.image-events", nativeDiagnostic (showText images)) | not (null images)])
 where view call = (nativeIntent call, nativeStep call, nativeCompiler call, nativeOwner call, nativeOwnerEnsured call, Tools.projectNativeCabalConfigAttempt <$> nativeConfigAttempt call, nativeRequest call,nativeActual call,[(point,path,ByteString.length bytes,sha256Bytes bytes) | (point,path,bytes)<-nativeConfigurationReads call],nativeWindowObservations call)
finishNativeStop :: NativeStopped -> IO a
finishNativeStop (NativeStopped original scope@(NativeScope root _ _ _)) = do
  _ <- tryIOError $ do
    evidence <- nativeScopeEvidence scope
    (_, stream) <- openTempFile (root </> ".build/candidate") "native-stopped-"
    TextIO.hPutStr stream (showText (("native.scope.stop-cause", showText original) : evidence))
    hClose stream
  throwIO original
modifyNativeCall :: NativeScope -> (NativeCall -> NativeCall) -> IO ()
modifyNativeCall (NativeScope _ _ calls _) change = atomicModifyIORef' calls (\rows -> case rows of current : prior -> (change current : prior,()); [] -> ([],()))
recordNativeWindow :: NativeScope -> NativeWindowObservation -> IO ()
recordNativeWindow scope event = modifyNativeCall scope (\call -> call {nativeWindowObservations=nativeWindowObservations call <> [event]})
readNativeWindows :: NativeScope -> Text -> FilePath -> IO (Either Text [FilePath])
readNativeWindows scope point root = do
  let path = root </> ".build/source-admission/journal/windows"
  recordNativeWindow scope (WindowInventoryStarted point path)
  exists <- doesPathExist path
  linked <- pathIsSymbolicLink path `catch` (\original -> if isDoesNotExistError original then pure False else throwIO (original :: IOException))
  let present = exists || linked
  directory <- doesDirectoryExist path
  names <- if directory then Just <$> listDirectory path else pure Nothing
  recordNativeWindow scope (WindowInventoryReturned point path present names)
  pure (case names of Just values -> Right (map (path </>) values); Nothing -> if present then Left "NativeWindowParentNotDirectory" else Right [])
-- Request association only; raw records do not supply source/image/provider or closure authority.
windowIsNew :: [FilePath] -> FilePath -> Bool
windowIsNew opening path = (path `elem` opening) == False
canonicalWindowInput :: Show a => a -> ByteString.ByteString -> Bool
canonicalWindowInput input bytes = E.encodeUtf8 (showText input <> "\n") == bytes
associateNativeWindows :: NativeScope -> FilePath -> NativeCabalRequest -> [String] -> Either Text [FilePath] -> Either Text [FilePath] -> ExitCode -> IO ()
associateNativeWindows scope root (cabal,_,_,config,compiler) arguments before after parent = do
  found <- case (before,after,arguments) of
    (Right opening,Right closing,command:rest) -> do { physical <- canonicalizePath compiler; let { name = takeFileName physical; packageTool = takeDirectory physical </> (if "ghc" `isPrefixOf` name then "ghc-pkg" <> drop 3 name else "ghc-pkg" <> exeExtension) }; mapM (matches packageTool command ("--offline":rest)) [path | path<-closing,windowIsNew opening path] }
    _ -> pure []
  let matched = catMaybes found
  recordNativeWindow scope (WindowRequestsMatched [path | (path,_,_)<-matched])
  case matched of {[(window,input,bytes)] -> checkNativeJournal scope root window input bytes parent; _ -> pure ()}
 where
  matches packageTool command received window = do
    owned <- inspectNativeWindow scope root FTDirectory window
    if not owned then pure Nothing else do
      let path = window </> "window-input.data"
      regular <- inspectNativeWindow scope root FTFile path
      if not regular then pure Nothing else do
        recordNativeWindow scope (WindowInputStarted path)
        bytes <- ByteString.readFile path
        recordNativeWindow scope (WindowInputReturned path (RetainedPlanBytes bytes))
        pure $ case either (const Nothing) (readMaybe . Text.unpack) (E.decodeUtf8' bytes) of
          Just input | Journal.requestedConfig input == Just config && canonicalWindowInput input bytes && Journal.windowProfile input == Journal.CabalWindow && Journal.freshPhysicalWindowRoot input == window && equalFilePath (Journal.checkedRepositoryRoot input) root && Journal.requestedNativeCompiler input == compiler && Journal.requestedCabal input == Just cabal && Journal.selectedCabalCommand input == Just command && Journal.receivedCabalArguments input == received && Journal.exactForwardedCabalArguments input == ["--config-file="<>config,command,"--offline","--jobs=1","--with-compiler="<>(window </> "compiler/ghc.exe"),"--with-hc-pkg="<>packageTool] <> received -> Just (window,input,bytes)
          _ -> Nothing
nativeWindowNode :: NativeScope -> FilePath -> FilePath -> IO (Bool,FileType)
nativeWindowNode scope root path = do
  recordNativeWindow scope (WindowNodeStarted path)
  physical <- canonicalizePath path
  kind <- getFileType path
  recordNativeWindow scope (WindowNodeObserved path physical (showText kind))
  pure (imagePathsAllowed root [path] [physical],kind)
inspectNativeWindow :: NativeScope -> FilePath -> FileType -> FilePath -> IO Bool
inspectNativeWindow scope root expected path = (\(contained,kind) -> contained && kind == expected) <$> nativeWindowNode scope root path
data NativeJournalUnclosed = NativeJournalUnclosed FilePath Text NativeScope
instance Show NativeJournalUnclosed where show (NativeJournalUnclosed window why _) = "NativeJournalUnclosed: " <> window <> ": " <> Text.unpack why
instance Exception NativeJournalUnclosed
stopNativeJournal :: NativeScope -> FilePath -> Text -> IO a
stopNativeJournal scope window why = recordNativeWindow scope (WindowJournalUnclosed window why) >> throwIO (NativeJournalUnclosed window why scope)
journalRequire :: NativeScope -> FilePath -> Bool -> Text -> IO ()
journalRequire scope window condition why = unless condition (stopNativeJournal scope window why)
decodeNativeWindow :: (Read a, Show a) => ByteString.ByteString -> Maybe a
decodeNativeWindow bytes = do text <- either (const Nothing) Just (E.decodeUtf8' bytes); value <- readMaybe (Text.unpack text); if canonicalWindowInput value bytes then Just value else Nothing
nativeWindowBytes :: NativeScope -> FilePath -> FilePath -> FilePath -> IO ByteString.ByteString
nativeWindowBytes scope root window path = do
  recordNativeWindow scope (WindowRecordStarted path)
  present <- doesPathExist path
  journalRequire scope window present "record-unavailable"
  regular <- inspectNativeWindow scope root FTFile path
  journalRequire scope window regular "record-not-owned-regular"
  bytes <- ByteString.readFile path
  recordNativeWindow scope (WindowRecordReturned path (RetainedPlanBytes bytes)); pure bytes
nativeWindowRecord :: (Read a, Show a) => NativeScope -> FilePath -> FilePath -> FilePath -> IO a
nativeWindowRecord scope root window path = nativeWindowBytes scope root window path >>= maybe (stopNativeJournal scope window "record-not-canonical") pure . decodeNativeWindow
journalOrdinals :: [Journal.CallFiles] -> Bool
journalOrdinals rows = snd (foldl (\(next,valid) row -> (next+1,valid && Journal.callOrdinal row == next)) (0,True) rows)
journalCalls :: FilePath -> Journal.WindowInput -> Journal.WindowClose -> Maybe [(Journal.CallFiles,Journal.CompilerRequest,ExitCode,ByteString.ByteString,ByteString.ByteString)]
journalCalls window input closed = do
  compiler <- case Journal.preparedNativeCompilerPath input of Journal.Returned path -> Just path; _ -> Nothing
  let rows = Journal.actualCallFilesInOrdinalOrder closed; root = Journal.checkedRepositoryRoot input; copy = window </> "compiler/ghc.exe"; source = window </> "bootstrap/compiler-transport/Main.hs"
  guard (Journal.bridgeTemplate input == Just Journal.CabalWindowLocatedBridge && Journal.bootstrapOutputPath input == Just (window </> "bootstrap/ghc.exe") && Journal.callableBridgeCopyPath input == Just copy && Journal.standaloneRequestedWrapperOutput input == Nothing && Journal.inheritedModes input == Journal.InheritStdinStdoutStderrEnvironmentAndCwdDelegateControlCTrue)
  guard (not (null rows) && journalOrdinals rows && Journal.closedWindowRoot closed == window && null (Journal.actualOtherWindowRelativeFiles closed) && Journal.actualCallDirectoryInventory closed == map Journal.callDirectory rows)
  forM rows $ \row -> do
    before <- case Journal.beginCompleteBytes row of Journal.Returned bytes -> Just bytes; _ -> Nothing
    after <- case Journal.returnedCompleteBytes row of Journal.Returned bytes -> Just bytes; _ -> Nothing
    begin <- decodeNativeWindow before; returned <- decodeNativeWindow after
    code <- case Journal.actualRawCompilerReturn returned of Journal.ActualRawSystemReturned value -> Just value; _ -> Nothing
    let request = Journal.beginRequest begin; ordinal = Journal.callOrdinal row; bootstrap = ordinal == 0; received = Journal.receivedCompilerArguments request
        expected = ["--make","-j1","-fforce-recomp","-v0","-hide-all-packages","-package","base","-package","process","-package","filepath","-outputdir",window </> "bootstrap/compiler-transport",source,"-o",window </> "bootstrap/ghc.exe"]
    guard (Journal.returnRequest returned == request && Journal.requestWindowRoot request == window && Journal.requestOrdinal request == ordinal && Journal.callDirectory row == window </> "calls" </> ("call-"<>show ordinal) && Journal.requestedCompiler request == compiler && Journal.checkedRoot request == root && Journal.callAdmittedSources request == Journal.admittedSources input && Journal.actualCwdRead request == Journal.Returned root && Journal.modeRequest request == Journal.InheritStdinStdoutStderrEnvironmentAndCwdDelegateControlCTrue && Journal.optionalRetentionFailureBytes row == Journal.NotAttempted "optional retention failure file absent")
    guard (if bootstrap then Journal.compilerSite request == Journal.BridgeBootstrapCompiler && Journal.receivedBridgeLocation request == Nothing && received == expected && Journal.exactForwardedCompilerArguments request == expected else Journal.compilerSite request == Journal.ReAdmittedDelegatedCompiler && Journal.receivedBridgeLocation request == Just copy && Journal.exactForwardedCompilerArguments request == received<>["-j1"] && all (\arg -> not ("-j" `isPrefixOf` arg) || arg == "-j1") received)
    pure (row,request,code,before,after)
nativeBridgeSource :: FilePath -> Journal.WindowInput -> Maybe ByteString.ByteString
nativeBridgeSource root input = do
  compiler <- case Journal.preparedNativeCompilerPath input of Journal.Returned path -> Just path; _ -> Nothing
  let requested = Journal.requestedNativeCompiler input
  guard (equalFilePath compiler (if isAbsolute requested then requested else root </> requested))
  pure (E.encodeUtf8 (Text.unlines
    ["module Main (main) where", "import System.Environment (getArgs, getExecutablePath)", "import System.Exit (exitWith)"
    ,"import System.FilePath (takeDirectory)", "import System.Process (rawSystem)", "main :: IO ()", "main = do"
    ,"  args <- getArgs", "  self <- getExecutablePath", "  let window = takeDirectory (takeDirectory self)"
    ,"  rawSystem " <> showText (Journal.requestedHelper input) <> " ([\"--compiler-window\", window, self, " <> showText compiler <> ", " <> showText (Journal.checkedRepositoryRoot input) <> "] ++ args) >>= exitWith"]))
uniqueJsonTokens :: Json.Tokens k e -> Maybe k
uniqueJsonTokens value = case value of {Json.TkLit _ next -> Just next; Json.TkText _ next -> Just next; Json.TkNumber _ next -> Just next; Json.TkArrayOpen rows -> array rows; Json.TkRecordOpen rows -> object Set.empty rows; Json.TkErr _ -> Nothing}
 where
  array rows = case rows of {Json.TkItem item -> uniqueJsonTokens item >>= array; Json.TkArrayEnd next -> Just next; Json.TkArrayErr _ -> Nothing}
  object keys rows = case rows of {Json.TkPair key item -> if Set.member key keys then Nothing else uniqueJsonTokens item >>= object (Set.insert key keys); Json.TkRecordEnd next -> Just next; Json.TkRecordErr _ -> Nothing}
nativePlanUnits :: ByteString.ByteString -> Maybe [(Aeson.Object,Text,Text)]
nativePlanUnits bytes = do
  guard (ByteString.length bytes <= 64 * 1024 * 1024); rest <- uniqueJsonTokens (JsonBytes.bsToTokens bytes); guard (ByteString.all (`elem` [9,10,13,32]) rest)
  Aeson.Object plan <- Aeson.decodeStrict' bytes
  Aeson.Array entries <- JsonMap.lookup "install-plan" plan
  units <- forM (toList entries) $ \value -> do {Aeson.Object unit <- Just value; Aeson.String package <- JsonMap.lookup "pkg-name" unit; Aeson.String identity <- JsonMap.lookup "id" unit; guard (not (Text.null package || Text.null identity)); pure (unit,package,identity)}
  guard (length units == Set.size (Set.fromList [identity | (_,_,identity)<-units]))
  pure units
nativePlanImage :: Text -> FilePath -> ByteString.ByteString -> Maybe FilePath
nativePlanImage target root bytes = do
  units <- nativePlanUnits bytes
  let matching = [unit | (unit,"amoebius",_)<-units,JsonMap.lookup "component-name" unit == Just (Aeson.String target)]
  unit <- case matching of [one] -> Just one; _ -> Nothing
  guard (JsonMap.lookup "style" unit == Just (Aeson.String "local"))
  Aeson.Object source <- JsonMap.lookup "pkg-src" unit
  Aeson.String path <- JsonMap.lookup "path" source
  guard (JsonMap.lookup "type" source == Just (Aeson.String "local") && equalFilePath (Text.unpack path) root)
  Aeson.String image <- JsonMap.lookup "bin-file" unit; guard (not (Text.null image)); pure (Text.unpack image)
nativePlanWireTool :: FilePath -> ByteString.ByteString -> Maybe (FilePath,FilePath)
nativePlanWireTool root bytes = do
  units <- nativePlanUnits bytes
  helper <- nativePlanImage "exe:amoebius-wire-prepare" root bytes; guard (imagePathsAllowed (root </> ".build/dist-native") [helper] [helper])
  unit <- case [u | (u,"amoebius",_)<-units,JsonMap.lookup "component-name" u == Just (Aeson.String "exe:amoebius-wire-prepare")] of [one] -> Just one; _ -> Nothing
  (plugin,identity) <- case [(u,i) | (u,"proto-lens-protoc",i)<-units,JsonMap.lookup "component-name" u == Just (Aeson.String "exe:proto-lens-protoc"),JsonMap.lookup "style" u == Just (Aeson.String "global")] of [one] -> Just one; _ -> Nothing
  Aeson.Array dependencies <- JsonMap.lookup "exe-depends" unit
  guard (toList dependencies == [Aeson.String identity])
  Aeson.String version <- JsonMap.lookup "pkg-version" plugin
  guard (case Text.splitOn "." version of "0":"9":rest -> all (\part -> not (Text.null part) && Text.all (\c -> c >= '0' && c <= '9') part) rest; _ -> False)
  Aeson.String image <- JsonMap.lookup "bin-file" plugin; guard (isAbsolute (Text.unpack image)); pure (helper,Text.unpack image)
wireGeneratedPaths :: FilePath -> [FilePath]; wireGeneratedPaths tree = map (tree </>) [".build/proto/current/PulsarApi.proto", ".build/proto/current/generated/Proto/PulsarApi.hs", ".build/proto/current/generated/Proto/PulsarApi_Fields.hs", ".build/proto/current/generated/Paths_supernova.hs", ".build/proto/current/plugin.request", ".build/proto/current/plugin.response"]
verifyWireGenerated :: NativeScope -> FilePath -> Text -> [ByteString.ByteString] -> IO (); verifyWireGenerated scope tree point opening = withNativeScope scope $ do { closing <- readScopeImages scope point tree (wireGeneratedPaths tree); unless (opening == closing) (fail "WireGeneratedFilesChanged") }
prepareNativeWireTool :: NativeScope -> FilePath -> FilePath -> Maybe FilePath -> IO ([ObservedRun],Either Text [ByteString.ByteString])
prepareNativeWireTool scope tree cabal compiler = withNativeScope scope $ do
  (runs,built) <- buildNativeTargetWith "exe:amoebius-wire-prepare" (ownedCabal scope tree cabal compiler)
  case built of
    Left problem -> pure (runs,Left problem)
    Right image -> do
      plan <- readScopePlan scope "wire-tool-plan" tree
      case nativePlanWireTool tree plan of
        Just (helper,plugin) | equalFilePath image helper -> do
          helperBefore <- readScopeImages scope "wire-helper-before" tree [helper]; pluginBefore <- readScopeImages scope "wire-plugin-before" (takeDirectory plugin) [plugin]; started <- observeOwnedNative scope (NativeDirectIntent tree helper ["begin-plugin","current"]); let { paths = wireGeneratedPaths tree; outputs = take 4 paths; owner = tree </> ".build/proto/current"; schema = owner </> "PulsarApi.proto"; request = owner </> "plugin.request"; response = owner </> "plugin.response"; errors = owner </> "plugin.stderr"; matches run expected = let actual = map Text.unpack (Text.lines (runStdout run)) in length actual == length expected && and (zipWith equalFilePath actual expected) }
          unless (runExit started == ExitSuccess && isNothing (runSpawnFailure started) && matches started [schema,request]) (fail "WirePreparationObservationMismatch"); opening <- readScopeImages scope "wire-input-before" tree [schema,request]; forM_ [response,errors] $ \path -> do { present <- doesPathExist path; linked <- pathIsSymbolicLink path `catch` (\problem -> if isDoesNotExistError problem then pure False else throwIO (problem :: IOException)); when (present || linked) (fail "WirePluginOutputNotFresh") }
          pluginRun <- observeOwnedNative scope (NativeFileIntent tree plugin request response errors); if runExit pluginRun /= ExitSuccess || isJust (runSpawnFailure pluginRun) then do { inputAfter <- readScopeImages scope "wire-input-after-refusal" tree [schema,request]; helperAfter <- readScopeImages scope "wire-helper-after-refusal" tree [helper]; pluginAfter <- readScopeImages scope "wire-plugin-after-refusal" (takeDirectory plugin) [plugin]; closing <- readScopePlan scope "wire-tool-after-refusal" tree; unless (opening == inputAfter && helperBefore == helperAfter && pluginBefore == pluginAfter && plan == closing) (fail "WireRefusalObservationMismatch"); pure (runs <> [started,pluginRun],Left "WirePluginObservationMismatch") } else do
            afterPlugin <- readScopeImages scope "wire-input-after-plugin" tree [schema,request,response]; finished <- observeOwnedNative scope (NativeDirectIntent tree helper ["finish-plugin","current"]); helperAfter <- readScopeImages scope "wire-helper-after" tree [helper]; pluginAfter <- readScopeImages scope "wire-plugin-after" (takeDirectory plugin) [plugin]; closing <- readScopePlan scope "wire-tool-after" tree
            unless (runExit finished == ExitSuccess && isNothing (runSpawnFailure finished) && plan == closing && helperBefore == helperAfter && pluginBefore == pluginAfter && take 2 afterPlugin == opening && matches finished outputs) (fail "WireGenerationObservationMismatch"); files <- readScopeImages scope "wire-generated" tree paths; unless (take 1 files == take 1 opening && drop 4 files == drop 1 afterPlugin) (fail "WireGeneratedInputMismatch"); pure (runs <> [started,pluginRun,finished],Right files)
        _ -> pure (runs,Left "WireToolPlanMismatch")
-- Opening and closing reads are post-return observations, not an execution seal.
nativeHelperContext :: NativeScope -> FilePath -> FilePath -> (FilePath -> IO ByteString.ByteString) -> Journal.WindowInput -> IO (IO ())
nativeHelperContext scope root window readBytes input = do
  let planPath = root </> ".build/source-admission-bootstrap/cache/plan.json"; require = journalRequire scope window
  plan <- readBytes planPath
  helper <- maybe (stopNativeJournal scope window "helper-plan-unavailable") pure (nativePlanImage "exe:extension-source-admission" root plan)
  require (helper == Journal.requestedHelper input) "helper-plan-disagrees"
  image <- readBytes helper; require (not (ByteString.null image)) "helper-image-empty"
  pure $ do
    afterPlan <- readBytes planPath
    require (plan == afterPlan) "helper-plan-changed"
    afterImage <- readBytes helper
    require (image == afterImage) "helper-image-changed"
checkNativeJournal :: NativeScope -> FilePath -> FilePath -> Journal.WindowInput -> ByteString.ByteString -> ExitCode -> IO ()
checkNativeJournal scope root window input opening parent = do
  let require = journalRequire scope window; readBytes = nativeWindowBytes scope root window
  closeBefore <- readBytes (window </> "window-close.data")
  closed <- maybe (stopNativeJournal scope window "close-not-canonical") pure (decodeNativeWindow closeBefore)
  rows <- maybe (stopNativeJournal scope window "call-closure-incomplete") pure (journalCalls window input closed)
  let firstCode = case rows of (_,_,code,_,_):_ -> code; _ -> ExitFailure 1
      success = firstCode == ExitSuccess
  names <- listDirectory window
  recordNativeWindow scope (WindowJournalInventory "root" window names); forM_ ["bootstrap","compiler","calls"] (\name -> inspectNativeWindow scope root FTDirectory (window </> name) >>= \owned -> require owned "required-directory-not-owned")
  require (sort names == sort (["window-input.data","window-close.data","bootstrap","compiler","calls"] <> if success then ["window-ready.data","aggregate-begin.data","aggregate-return.data"] else [])) "window-entry-inventory"
  calls <- listDirectory (window </> "calls")
  recordNativeWindow scope (WindowJournalInventory "calls" (window </> "calls") calls)
  require (sort calls == sort ["call-"<>show (Journal.callOrdinal row) | (row,_,_,_,_)<-rows]) "call-directory-inventory"
  files <- nativeWindowTree scope root window window
  recordNativeWindow scope (WindowJournalInventory "tree" window files)
  require (null [path | path<-files,not (allowed path)]) "unexpected-tree-entry"
  sourceBytes <- readBytes (window </> "bootstrap/compiler-transport/Main.hs")
  require (Journal.bootstrapBridgeSource input == Just (Journal.SourceReference (window </> "bootstrap/compiler-transport/Main.hs") (Journal.Returned sourceBytes))) "bridge-source-changed"
  require (nativeBridgeSource root input == Just sourceBytes) "bridge-template-disagrees"
  closing <- readBytes (window </> "window-input.data")
  require (closing == opening) "input-changed"
  closeHelper <- nativeHelperContext scope root window readBytes input
  forM_ rows $ \(row,_,_,before,after) -> do
    let directory = Journal.callDirectory row
    namesAtCall <- listDirectory directory
    recordNativeWindow scope (WindowJournalInventory "call" directory namesAtCall)
    require (sort namesAtCall == ["begin.data","return.data"]) "call-entry-inventory"
    beforeNow <- readBytes (directory </> "begin.data"); require (beforeNow == before) "begin-changed"
    afterNow <- readBytes (directory </> "return.data"); require (afterNow == after) "return-changed"
  if success then do
    begin <- nativeWindowRecord scope root window (window </> "aggregate-begin.data"); returned <- nativeWindowRecord scope root window (window </> "aggregate-return.data")
    require (begin == Journal.AggregateBegin Journal.OuterCabal (maybe "" id (Journal.requestedCabal input)) (Journal.exactForwardedCabalArguments input) Journal.InheritStdinStdoutStderrEnvironmentAndCwdDelegateControlCTrue && returned == Journal.AggregateReturned Journal.OuterCabal parent && Journal.actualAggregateReturn closed == Journal.Returned returned) "aggregate-disagrees"
    ready <- nativeWindowRecord scope root window (window </> "window-ready.data")
    images <- mapM readBytes [window </> "bootstrap/ghc.exe",window </> "compiler/ghc.exe"]
    let refs = [Journal.ImageReference path (Journal.Returned path) (Journal.Returned (Journal.ImageMeasure (fromIntegral (ByteString.length bytes)) (sha256Bytes bytes))) | (path,bytes)<-zip [window </> "bootstrap/ghc.exe",window </> "compiler/ghc.exe"] images]
    require (case (images,refs) of ([built,copied],[a,b]) -> not (ByteString.null built) && built == copied && Journal.readyWindowRoot ready == window && Journal.actualBootstrapOutput ready == a && Journal.actualCallableBridgeCopy ready == b && Journal.forcedCompleteImageCopyEquality ready == Journal.Returned True && Journal.readySourceAdmission ready == Journal.admittedSources input; _ -> False) "ready-image-disagrees"
  else require (length rows == 1 && parent == firstCode && Journal.actualAggregateReturn closed == Journal.NotAttempted "bootstrap returned nonzero") "failed-bootstrap-disagrees"
  closeHelper
  closeAfter <- readBytes (window </> "window-close.data"); require (closeBefore == closeAfter) "close-changed"
  recordNativeWindow scope (WindowJournalClosed window [(Journal.requestOrdinal request,code) | (_,request,code,_,_)<-rows])
  where allowed path = path `elem` [".","bootstrap","compiler","calls","window-input.data","window-close.data","window-ready.data","aggregate-begin.data","aggregate-return.data"] || case splitDirectories path of {first:_ | first `elem` ["bootstrap","compiler"] -> True; ["calls",_] -> True; ["calls",_,file] -> file `elem` ["begin.data","return.data"]; _ -> False}
nativeWindowTree :: NativeScope -> FilePath -> FilePath -> FilePath -> IO [FilePath]
nativeWindowTree scope root window path = do
  (contained,kind) <- nativeWindowNode scope root path
  journalRequire scope window (contained && kind `elem` [FTFile,FTDirectory]) "tree-node-not-owned"
  if kind == FTFile then pure [makeRelative window path] else do
    names <- listDirectory path
    recordNativeWindow scope (WindowJournalInventory "tree-directory" path names)
    ((makeRelative window path):) . concat <$> mapM (nativeWindowTree scope root window . (path </>)) names
readNativeConfiguration :: NativeScope -> NativeStep -> FilePath -> IO ByteString.ByteString
readNativeConfiguration scope@(NativeScope _ _ calls _) step path = do
  modifyNativeCall scope (\call -> call {nativeStep=step})
  bytes <- ByteString.readFile path
  modifyNativeCall scope (\call -> call {nativeConfigurationReads=nativeConfigurationReads call <> [(step,path,bytes)]})
  retained <- readIORef calls
  unless (all (== bytes) [before | call<-retained,(NativeConfigurationBefore,operand,before)<-nativeConfigurationReads call,operand == path]) (fail "NativeConfigurationChanged")
  pure bytes
observeOwnedNative :: NativeScope -> NativeIntent -> IO ObservedRun
observeOwnedNative scope@(NativeScope _ _ calls _) intent = withNativeScope scope $ do
  let initial = NativeCall intent (case intent of NativeDirectIntent {} -> ObserveNativeRequest; NativeFileIntent {} -> ObserveNativeRequest; _ -> ResolveNativeCompiler) Nothing Nothing False Nothing Nothing Nothing [] []
      update = modifyNativeCall scope
  atomicModifyIORef' calls (\prior -> (initial : prior,()))
  (actual@(_,_,_,_,_,result),configurationInput) <- case intent of
    NativeDirectIntent root executable arguments -> (\tuple -> (tuple,Nothing)) <$> observeActualTuple root executable arguments
    NativeFileIntent root executable input output errors -> do { environment <- minimalEnvironment root; result <- tryRunFileInput root executable [] (Just environment) input output errors; (out,err) <- case result of { Left _ -> pure ("",""); Right _ -> do { [stdoutBytes,stderrBytes] <- readScopeFiles True scope "wire-plugin-streams" root [output,errors]; pure (Text.unpack (showText (ByteString.length stdoutBytes,sha256Bytes stdoutBytes)), Text.unpack (showText (ByteString.length stderrBytes,sha256Bytes stderrBytes))) } }; pure ((executable,[],root,environment,"binary-file-stdio:size-and-sha256;environment:minimal-allowlist",fmap (\code -> (code,out,err)) result),Nothing) }
    NativeCabalIntent root cabal compiler arguments -> do
      ghc <- maybe (maybe "ghc" id <$> findExecutable "ghc") pure compiler
      let owner = root </> ".build/source-admission-bootstrap"
      update (\call -> call {nativeCompiler=Just ghc,nativeOwner=Just owner,nativeStep=EnsureNativeOwner})
      createDirectoryIfMissing True owner
      update (\call -> call {nativeOwnerEnsured=True,nativeStep=SelectNativeConfiguration})
      selected <- Tools.acquireNativeCabalConfigAttempt owner
      update (\call -> call {nativeConfigAttempt=Just selected})
      config <- either throwIO pure (Tools.actualNativeCabalConfigResult selected)
      update (\call -> call {nativeStep=AssembleNativeRequest})
      let forwarded = ["--config-file=" <> config,"run","-v0","--offline","--jobs=1","--builddir=.build/source-admission-bootstrap","--with-compiler=" <> ghc,
            "exe:extension-source-admission","--","--cabal",ghc,cabal,config] <> case arguments of command : rest -> command : "--offline" : rest; [] -> []
      update (\call -> call {nativeRequest=Just (cabal,forwarded,root,config,ghc)})
      before <- readNativeConfiguration scope NativeConfigurationBefore config
      windows <- readNativeWindows scope "before" root
      update (\call -> call {nativeStep=ObserveNativeRequest})
      tuple <- observeActualTuple root cabal forwarded
      pure (tuple,Just (config,before,root,(cabal,forwarded,root,config,ghc),arguments,windows))
  update (\call -> call {nativeActual=Just actual,nativeStep=NativeTupleReturned})
  (parent,_,_) <- either throwIO pure result
  forM_ configurationInput $ \(path,before,root,request,arguments,windows) -> do
    after <- readNativeConfiguration scope NativeConfigurationAfter path
    unless (before == after) (fail "NativeConfigurationChanged")
    closing <- readNativeWindows scope "after" root
    associateNativeWindows scope root request arguments windows closing parent
  pure (compatibilityObservation actual)
data ObservedRun = ObservedRun { runExecutable :: FilePath, runArgv :: [String], runCwd :: FilePath , runEnvironment :: [(String, String)] , runEnvironmentPolicy :: Text, runExit :: ExitCode, runStdout :: Text, runStderr :: Text , runSpawnFailure :: Maybe Text } deriving (Eq, Show)
type ActualPreparedTuple = (FilePath, [String], FilePath, [(String, String)], Text, Either IOException (ExitCode, String, String))
observeActualTuple :: FilePath -> FilePath -> [String] -> IO ActualPreparedTuple
observeActualTuple workingDirectory executable arguments = do
  environment <- minimalEnvironment workingDirectory
  attempt <- tryReadEmptyInput workingDirectory executable arguments (Just environment)
  pure (executable, arguments, workingDirectory, environment, policy, attempt)
 where
  policy = "inherit:PATH,HOME,CABAL_DIR,CABAL_CONFIG,GHCUP_INSTALL_BASE_PREFIX,XDG_CACHE_HOME,XDG_CONFIG_HOME,XDG_DATA_HOME,XDG_STATE_HOME,APPDATA,LOCALAPPDATA,SystemRoot,SYSTEMROOT,WINDIR,COMSPEC,PATHEXT,LANG;temp:cwd/.build/observer-tmp"
observe :: FilePath -> FilePath -> [String] -> IO ObservedRun
observe workingDirectory executable arguments = compatibilityObservation <$> observeActualTuple workingDirectory executable arguments
compatibilityObservation :: ActualPreparedTuple -> ObservedRun
compatibilityObservation (executable,arguments,workingDirectory,environment,policy,attempt) = case attempt of
  Left problem -> ObservedRun executable arguments workingDirectory environment policy (ExitFailure 127) "" "" (Just (Text.pack (show problem)))
  Right (exit,out,err) -> ObservedRun executable arguments workingDirectory environment policy exit (Text.pack out) (Text.pack err) Nothing
minimalEnvironment :: FilePath -> IO [(String, String)]
minimalEnvironment root = do
  ready <- doesDirectoryExist root
  temporary <- makeAbsolute (root </> ".build/observer-tmp")
  physical <- canonicalizePath temporary
  if ready && not (equalFilePath physical temporary) then fail "ObserverTemporaryRootSymlink" else pure ()
  if ready then createDirectoryIfMissing True temporary else pure ()
  pairs <- presentEnvironment ["PATH", "HOME", "CABAL_DIR", "CABAL_CONFIG", "GHCUP_INSTALL_BASE_PREFIX", "XDG_CACHE_HOME", "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "APPDATA", "LOCALAPPDATA", "SystemRoot", "SYSTEMROOT", "WINDIR", "COMSPEC", "PATHEXT", "LANG"]
  pure (pairs <> [("LC_ALL", "C.UTF-8"), ("TMPDIR", temporary), ("TMP", temporary), ("TEMP", temporary)])
observeNativeCabal :: FilePath -> FilePath -> Maybe FilePath -> [String] -> IO ObservedRun
observeNativeCabal root cabal compiler arguments = prepareNativeCabalRequest root cabal compiler arguments >>= \(exe,args,cwd,_,_) -> observe cwd exe args
type NativeCabalRequest = (FilePath, [String], FilePath, FilePath, FilePath)
prepareNativeCabalRequest :: FilePath -> FilePath -> Maybe FilePath -> [String] -> IO NativeCabalRequest
prepareNativeCabalRequest = prepareNativeCabalWith (\owner -> nativeCabalConfig owner >>= either (fail . Text.unpack) pure)
prepareNativeCabalWith :: (FilePath -> IO FilePath) -> FilePath -> FilePath -> Maybe FilePath -> [String] -> IO NativeCabalRequest
prepareNativeCabalWith configuration root cabal compiler arguments = do
  ghc <- maybe (maybe "ghc" id <$> findExecutable "ghc") pure compiler
  let owner = root </> ".build/source-admission-bootstrap"
  createDirectoryIfMissing True owner
  config <- configuration owner
  let forwarded = ["--config-file=" <> config, "run", "-v0", "--offline", "--jobs=1", "--builddir=.build/source-admission-bootstrap", "--with-compiler=" <> ghc,
        "exe:extension-source-admission", "--", "--cabal", ghc, cabal, config] <> case arguments of command : rest -> command : "--offline" : rest; [] -> []
  pure (cabal, forwarded, root, config, ghc)
observeActualNativeCabal :: FilePath -> FilePath -> Maybe FilePath -> [String] -> IO ActualPreparedTuple
observeActualNativeCabal root cabal compiler arguments = prepareNativeCabalWith (\owner -> Tools.acquireNativeCabalConfigAttempt owner >>= either throwIO pure . Tools.actualNativeCabalConfigResult) root cabal compiler arguments
  >>= \(exe,args,cwd,_,_) -> observeActualTuple cwd exe args
buildNativeTargetWith :: String -> ([String] -> IO (ObservedRun,Bool)) -> IO ([ObservedRun], Either Text FilePath)
buildNativeTargetWith target native = do
  (built,buildBound) <- native ["build", "-v0", "--builddir=.build/dist-native", target]
  if not buildBound || runExit built /= ExitSuccess then pure ([built], Left (Text.pack target <> " did not build: " <> Text.take 400 (runStderr built))) else do
    (located,locateBound) <- native ["list-bin", "--builddir=.build/dist-native", target]
    let path = Text.unpack (Text.strip (runStdout located))
    present <- doesFileExist path
    pure ([built, located], if locateBound && runExit located == ExitSuccess && present then Right path else Left (Text.pack target <> " not located: " <> Text.take 200 (runStderr located)))
observedDigest :: ObservedRun -> Text
observedDigest = sha256Hex . Text.pack . show . observedFields
chainDigest :: Text -> ObservedRun -> Text
chainDigest previous run = sha256Hex (previous <> "\n" <> observedDigest run)
renderObserved :: Text -> ObservedRun -> [(Text, Text)]
renderObserved prefix run = [(prefix <> "." <> key, value) | (key, value) <- observedFields run] <> [(prefix <> ".digest", observedDigest run)]
observedFields :: ObservedRun -> [(Text, Text)]
observedFields run = [ ("executable", Text.pack (runExecutable run)), ("argv", Text.pack (show (runArgv run))) , ("cwd", Text.pack (runCwd run)), ("environment-policy", runEnvironmentPolicy run) , ("environment", Text.pack (show (runEnvironment run))) , ("exit", Text.pack (show (runExit run))), ("stdout-sha256", sha256Hex (runStdout run)) , ("stderr-sha256", sha256Hex (runStderr run)), ("stdout-bytes", Text.pack (show (ByteString.length (E.encodeUtf8 (runStdout run))))) ] <> maybe [] (\failure -> [("spawn-failure", failure)]) (runSpawnFailure run)
sha256Hex :: Text -> Text
sha256Hex = sha256Bytes . E.encodeUtf8
renderTsv :: [[Text]] -> Text
renderTsv = Text.unlines . map (Text.intercalate "\t")
requiredSuiteRows :: GateSpec -> [Text]
requiredSuiteRows spec | Just _ <- gateSeed spec = ["phase.cardinality","phase.table","phase.resource-required","phase.paths","gap","integrity.problems","legacy.cardinality","legacy.owners","decision.ids","frozen.paths","frozen.digests","frozen.decisions","frozen.amendments","frozen.amendment-digests","evidence-path.cardinality","evidence-path.results","evidence-parser.bundle-only","evidence-parser.void-only","evidence-parser.void-fields","doc.findings","doc.governed-count-observed","negative.discovery"] <> ["negative." <> name | name <- ["broken-link","stale-backlink","missing-status-line","non-frontier-status-vector","unauthorised-frozen-edit","uncited-module-claim","gate-spec-block-mismatch","decision-log-out-of-order","receipt-line-unexpected"]] <> ["role." <> PhaseIdentity.renderPhaseRole role | role <- PhaseIdentity.allPhaseRoles] <> [kind <> "." <> Text.pack (show ordinal) | (kind,Just ordinal) <- [("predecessor",Just PhaseIdentity.phaseDomainLowerOrdinal),("predecessor",PhaseIdentity.successorOrdinal PhaseIdentity.phaseDomainLowerOrdinal),("predecessor",PhaseIdentity.roleOrdinal PhaseIdentity.BootstrapHandoff),("successor",PhaseIdentity.roleOrdinal PhaseIdentity.DslBarrier),("successor",Just PhaseIdentity.phaseDomainUpperOrdinal)]]
requiredSuiteRows spec = [caseName item | item <- gateCases spec, "case:" `Text.isPrefixOf` caseName item]
data PackageGraph = PackageGraph { graphLibraries :: Map.Map Text (Set Text, Set Text, [FilePath]) {- stanza -> (modules, internal library deps, source dirs) -} , graphExecutables :: Map.Map Text BuildInfo {- retain source directories as well as dependencies -} , graphTestSuites :: Map.Map Text (BuildInfo, [TestSuiteInterface]) {- retain every declared interface -} , graphOraclePolicy :: [Text] , graphFlags :: [Text] } deriving (Eq, Show)
data SpecProblem = PackageDescriptionUnparsable Text | PackageDescriptionUnscanned [Text] | SubjectNotInPackage ProductionModule | SubjectInMultipleStanzas ProductionModule [Text] | SubjectOutsideClosure ProductionModule Text | ProductExecutableMissing | SuiteStanzaMissing CabalTarget | OracleStanzaMissing OracleExecutable | OracleDependsOnPackage OracleExecutable | OracleSourceDirectoryMissing OracleExecutable FilePath | OracleConditionalCompilation FilePath | OracleTemplateHaskell FilePath | OracleForeignImport FilePath | OracleSourceUnscanned FilePath | OracleBuildBoundary OracleExecutable Text deriving (Eq, Ord, Show)
renderSpecProblem :: SpecProblem -> Text
renderSpecProblem problem = case problem of {PackageDescriptionUnparsable detail -> "PACKAGE-UNPARSABLE: " <> detail; PackageDescriptionUnscanned warnings -> "PACKAGE-UNSCANNED: " <> Text.intercalate "," warnings; SubjectNotInPackage (ProductionModule name) -> "SUBJECT-NOT-IN-PACKAGE: " <> name; SubjectInMultipleStanzas (ProductionModule name) stanzas -> "SUBJECT-AMBIGUOUS: " <> name <> " in " <> Text.intercalate "," stanzas; SubjectOutsideClosure (ProductionModule name) stanza -> "SUBJECT-NOT-SHIPPED: " <> name <> " (" <> stanza <> ")"; ProductExecutableMissing -> "PRODUCT-EXECUTABLE-MISSING"; SuiteStanzaMissing (CabalTarget name) -> "SUITE-MISSING: " <> name; OracleStanzaMissing (OracleExecutable name) -> "ORACLE-MISSING: " <> name; OracleDependsOnPackage (OracleExecutable name) -> "ORACLE-DEPENDS-ON-PRODUCT: " <> name; OracleSourceDirectoryMissing (OracleExecutable name) directory -> "ORACLE-SOURCE-MISSING: " <> name <> " " <> Text.pack directory; OracleConditionalCompilation path -> "ORACLE-CPP: " <> Text.pack path; OracleTemplateHaskell path -> "ORACLE-TEMPLATE-HASKELL: " <> Text.pack path; OracleForeignImport path -> "ORACLE-FOREIGN-IMPORT: " <> Text.pack path; OracleSourceUnscanned file -> "ORACLE-SOURCE-UNSCANNED: " <> Text.pack file; OracleBuildBoundary (OracleExecutable name) detail -> "ORACLE-BUILD-BOUNDARY: " <> name <> " " <> detail}
data VerifiedSpec = VerifiedSpec { verifiedSpec :: GateSpec, verifiedStanzaOf :: Map.Map ProductionModule Text , verifiedClosure :: Set Text, verifiedOracleDirectories :: [FilePath] } deriving (Eq, Show)
loadPackageGraph :: FilePath -> IO (Either SpecProblem PackageGraph)
loadPackageGraph root = either (Left . PackageDescriptionUnparsable) parsePackageGraph <$> sourceAttempt (readSourceBytes (root </> "amoebius.cabal"))
compiledBlocks :: [(Text, GateSpecInput)] -> Either [Text] [(Int, Text)]
compiledBlocks proposals
  | null proposals = Left ["SPEC-REGISTRY-DIVERGED"]
  | otherwise = forM (map fst proposals) $ \capability -> maybe (Left ["SPEC-PHASE-ABSENT: " <> capability]) (\ordinal -> (\(_, spec) -> (ordinal, renderGateSpec spec)) <$> resolveSpec proposals ordinal) (PhaseIdentity.lookupCapabilityOrdinal capability)
resolveSpec :: [(Text, GateSpecInput)] -> Int -> Either [Text] (PhaseIdentity.PhaseIdentity, GateSpec)
resolveSpec proposals ordinal = do
  unless (length proposals == length (nub (map fst proposals)) && null PhaseIdentity.phaseIdentityIntegrityProblems) (Left ["SPEC-REGISTRY-DIVERGED"])
  row <- maybe (Left ["PHASE-ABSENT: " <> Text.pack (show ordinal)]) Right (PhaseIdentity.lookupPhaseIdentity ordinal)
  let capability = PhaseIdentity.phaseIdentityCapability row
  input <- maybe (Left ["SPEC-ABSENT: no gate specification is registered for " <> capability]) Right (lookup capability proposals)
  unless (inputCapability input == capability) (Left ["SPEC-CAPABILITY-MISMATCH: " <> capability])
  spec <- either (Left . map renderSpecRefusal) Right (mkGateSpec (roleFor ordinal) input)
  pure (row, spec)
bindPhaseSpec :: [(Text, GateSpecInput)] -> Int -> GateSpec -> Either [Text] ()
bindPhaseSpec proposals ordinal supplied = do
  (_, expected) <- resolveSpec proposals ordinal
  unless (gateRole supplied == gateRole expected) (Left ["SPEC-ROLE-MISMATCH: " <> gateCapability expected])
  unless (supplied == expected) (Left ["SPEC-CURRENT-MISMATCH: " <> gateCapability expected])
roleFor :: Int -> GateRole
roleFor ordinal
  | ordinal == PhaseIdentity.phaseDomainLowerOrdinal = SeedGate
  | Just ordinal == PhaseIdentity.roleOrdinal PhaseIdentity.DslBarrier = BarrierGate
  | maybe False (ordinal >=) (PhaseIdentity.roleOrdinal PhaseIdentity.FirstHardware) = HardwareGate
  | otherwise = OrdinaryGate
parsePackageGraph :: ByteString.ByteString -> Either SpecProblem PackageGraph
parsePackageGraph bytes = case parseDescription bytes of
  DescriptionAttempt _ _ (Left (_, problems)) -> Left (PackageDescriptionUnparsable (Text.pack (show (NE.toList problems))))
  DescriptionAttempt _ warnings (Right description) -> case sort [Text.pack (show kind <> "@" <> showPos position) | PWarning kind position _ <- warnings, kind /= PWTDeprecatedField] of
    [] -> Right (reduce description)
    refused -> Left (PackageDescriptionUnscanned refused)
reduce :: GenericPackageDescription -> PackageGraph
reduce description = PackageGraph
    { graphFlags = map (Text.pack . prettyShow . flagName) (genPackageFlags description)
    , graphLibraries = named libraryEntry (condSubLibraries description)
        <> Map.fromList [("amoebius", libraryEntry (aggregateAll tree)) | Just tree <- [condLibrary description]]
    , graphExecutables = named buildInfo (condExecutables description)
    , graphTestSuites = Map.fromList [(Text.pack (unUnqualComponentName name), (testBuildInfo (aggregateAll tree), nub [testInterface suite | suite <- conditionalValues tree, testInterface suite /= mempty])) | (name, tree) <- condTestSuites description]
    , graphOraclePolicy = let package_ = packageDescription description in ["build-type:" <> Text.pack (prettyShow (buildType package_)) | buildType package_ /= Simple] <> ["custom-setup" | Just _ <- [setupBuildInfo package_]]
    }
 where
  named project entries = Map.fromList [(Text.pack (unUnqualComponentName name), project (aggregateAll tree)) | (name, tree) <- entries]
  libraryEntry library = (Set.fromList (map (Text.pack . prettyShow) (exposedModules library <> otherModules (libBuildInfo library))),
    internalDependencies (libBuildInfo library), map getSymbolicPath (hsSourceDirs (libBuildInfo library)))
internalDependencies :: BuildInfo -> Set Text
internalDependencies info = Set.fromList
  [libraryStanza name | name <- dependencyLibrariesFor (mkPackageName "amoebius") info]
 where
  libraryStanza LMainLibName = "amoebius"
  libraryStanza (LSubLibName sub) = Text.pack (unUnqualComponentName sub)
executableClosure :: PackageGraph -> Text -> Maybe (Set Text)
executableClosure graph executable = libraryClosure graph . Set.toList . internalDependencies <$> Map.lookup executable (graphExecutables graph)
libraryClosure :: PackageGraph -> [Text] -> Set Text
libraryClosure graph = reachableFrom
  (\stanza -> maybe [] (\(_, internal, _) -> Set.toList internal) (Map.lookup stanza (graphLibraries graph)))
verifySpec :: FilePath -> GateSpec -> IO (Either [SpecProblem] VerifiedSpec)
verifySpec root spec = do
  loaded <- loadPackageGraph root
  either (pure . Left . pure) (\graph -> verifySpecAgainst root graph spec) loaded
verifySpecAgainst :: FilePath -> PackageGraph -> GateSpec -> IO (Either [SpecProblem] VerifiedSpec)
verifySpecAgainst root graph spec = do
  oracleProblems <- verifyOracle root graph oracle
  let problems = subjectProblems <> suiteProblems <> oracleProblems
  pure $ case (problems, closure) of
    ([], Just shipped) -> Right VerifiedSpec
      { verifiedSpec = spec, verifiedStanzaOf = Map.fromList [(subject, stanza) | subject <- gateSubjects spec, [stanza] <- [stanzasOf subject]]
      , verifiedClosure = shipped, verifiedOracleDirectories = oracleDirectories }
    _ -> Left (nub problems)
 where
  closure = executableClosure graph (if gateRole spec == SeedGate then "amoebius-validate" else "amoebius")
  stanzasOf (ProductionModule name) = sort [stanza | (stanza, (modules, _, _)) <- Map.toList (graphLibraries graph), Set.member name modules]
  subjectProblems = [ProductExecutableMissing | closure == Nothing] <> concatMap subjectProblem (gateSubjects spec)
  subjectProblem subject = case stanzasOf subject of
    [] -> [SubjectNotInPackage subject]
    [stanza]
      | maybe False (Set.member stanza) closure -> []
      | otherwise -> [SubjectOutsideClosure subject stanza]
    many -> [SubjectInMultipleStanzas subject many]
  suiteProblems = [SuiteStanzaMissing (gateSuite spec) | Map.notMember (cabalTargetName (gateSuite spec)) (graphTestSuites graph)]
  oracle = gateOracle spec
  oracleEntry = Map.lookup (oracleExecutableName oracle) (graphTestSuites graph)
  oracleDirectories = maybe [] (map getSymbolicPath . hsSourceDirs . fst) oracleEntry
verifyOracle :: FilePath -> PackageGraph -> OracleExecutable -> IO [SpecProblem]
verifyOracle root graph oracle = case Map.lookup (oracleExecutableName oracle) (graphTestSuites graph) of
  Nothing -> pure [OracleStanzaMissing oracle]
  Just (info, interfaces) -> do
    let dirs = map getSymbolicPath (hsSourceDirs info); boundary = OracleBuildBoundary oracle
        dirsOf peer = case map getSymbolicPath (hsSourceDirs peer) of [] -> ["."]; paths -> paths
        area = [(name, peer, peerInterfaces) | (name, (peer, peerInterfaces)) <- Map.toList (graphTestSuites graph), name == oracleExecutableName oracle
          || Set.fromList (dirsOf peer) == Set.fromList dirs && Set.null (internalDependencies peer) && null (oracleBuildHazards peer)]
        others = [("library:" <> name, paths) | (name, (_, _, paths)) <- Map.toList (graphLibraries graph)]
          <> [(tag <> name, dirsOf peer) | (tag, peers) <- [("executable:", Map.toList (graphExecutables graph)), ("test:", [(name, peer) | (name, (peer, _)) <- Map.toList (graphTestSuites graph), name `notElem` [key | (key, _, _) <- area]])], (name, peer) <- peers]
        overlaps a b = let parts = map (Text.toCaseFold . Text.pack) . filter (/= ".") . splitDirectories . normalise in parts a `isPrefixOf` parts b || parts b `isPrefixOf` parts a
        valid path = parseSourceInventory (Text.pack path <> "\0") == Right [path]
        invalid = ["source-dir:" <> Text.pack dir | dir <- dirs, not (valid dir)]
        owned = Set.unions [names | (names, _, _) <- Map.elems (graphLibraries graph)]
        entries = nub [getSymbolicPath path | (_, _, declared) <- area, TestSuiteExeV10 _ path <- declared]
        modules = nub [(Text.pack (prettyShow name), Text.unpack (Text.replace "." "/" (Text.pack (prettyShow name))) <> ".hs") | (_, peer, _) <- area, name <- otherModules peer]
        sources = nub [(dir </> path, name) | dir <- dirs, (name, path) <- [("Main", path) | path <- entries] <> modules]
        inspect file contents = [boundary ("source-unlisted:" <> Text.pack file) | file `notElem` map fst sources]
          <> if not (null hygiene) then hygiene else case sourceTree (root </> file) contents of
              Left _ -> [OracleSourceUnscanned (root </> file)]
              Right tree -> [boundary ("source-import:" <> Text.pack file <> ":" <> name) | declaration <- hsmodImports tree,
                let name = Text.pack (moduleNameString (unLoc (ideclName (unLoc declaration)))), Set.member name owned]
                <> [boundary ("source-module:" <> Text.pack file <> ":" <> name) | declared <- maybe [] pure (hsmodName tree),
                  let name = Text.pack (moduleNameString (unLoc declared)), Set.member name owned]
                <> [boundary ("source-name:" <> Text.pack file <> ":" <> name) | (path, expected) <- sources, path == file,
                  let name = maybe "Main" (Text.pack . moduleNameString . unLoc) (hsmodName tree), name /= expected]
          where hygiene = sourceHygiene (root </> file) contents
    if not (null invalid) then pure (map boundary invalid) else do
      scanned <- forM dirs $ \dir -> do
        present <- doesDirectoryExist (root </> dir)
        if present then either (const (Left (OracleSourceUnscanned (root </> dir)))) Right <$> sourceAttempt (haskellFilesUnder root dir) else pure (Left (OracleSourceDirectoryMissing oracle dir))
      let files = nub (concat [values | Right values <- scanned])
          found path = valid path && takeExtension path == ".hs" && any (\dir -> dir </> path `elem` files) dirs
          alternatives = nub [(dir </> dropExtension path) <.> suffix | dir <- dirs, path <- entries <> map snd modules, valid path, suffix <- ["lhs", "hsc", "chs", "x", "y", "ly", "cpphs", "hspp", "hs-boot", "lhs-boot"]]
          unsupported = ["interface:missing" | null interfaces] <> ["interface:" <> (case interface of TestSuiteLibV09 _ _ -> "detailed-0.9"; TestSuiteUnsupported kind -> Text.pack (prettyShow kind); TestSuiteExeV10 {} -> "exitcode-stdio-1.0") | interface <- interfaces, case interface of TestSuiteExeV10 {} -> False; _ -> True]
      preprocessed <- filterM (doesFileExist . (root </>)) alternatives
      syntax <- concat <$> mapM (\file -> either (const [OracleSourceUnscanned (root </> file)]) (inspect file) <$> sourceAttempt (readSourceText (root </> file))) files
      pure ([OracleDependsOnPackage oracle | not (Set.null (internalDependencies info))] <> [problem | Left problem <- scanned] <> syntax
        <> map boundary (graphOraclePolicy graph <> oracleBuildHazards info <> unsupported <> ["entry:" <> Text.pack path | path <- entries, not (found path)]
          <> ["source-shared:" <> Text.pack dir <> ":" <> name | dir <- dirs, (name, paths) <- others, any (overlaps dir) (if null paths then ["."] else paths)]
          <> ["module:" <> name | (name, path) <- modules, not (found path)] <> ["source:" <> Text.pack path | path <- preprocessed]
          <> ["source-ambiguous:" <> Text.pack path | path <- nub (entries <> map snd modules), length [() | dir <- nub dirs, dir </> path `elem` files] > 1]))
oracleBuildHazards :: BuildInfo -> [Text]
oracleBuildHazards info =
  ["extension:" <> Text.pack (prettyShow extension) | extension <- allExtensions info, case extension of Cabal.UnknownExtension _ -> True; Cabal.EnableExtension flag -> flag `elem` [Cabal.CPP, Cabal.TemplateHaskell, Cabal.TemplateHaskellQuotes, Cabal.QuasiQuotes]; _ -> False]
  <> ["language:" <> Text.pack (prettyShow language) | language <- allLanguages info, prettyShow language `notElem` ["Haskell98", "Haskell2010", "GHC2021", "GHC2024"]]
  <> ["compiler-option:" <> Text.pack option | select <- [hcOptions, hcProfOptions, hcSharedOptions, hcProfSharedOptions, hcStaticOptions], flavor <- [GHC, GHCJS], option <- select flavor info, not (safe option)]
  <> [label | (label, present) <-
    [("buildable:false", not (buildable info)), ("build-tools", not (null (buildTools info))), ("build-tool-depends", not (null (buildToolDepends info)))
    ,("pkgconfig-depends", not (null (pkgconfigDepends info)))
    ,("cpp-options", not (null (cppOptions info))), ("asm-options", not (null (asmOptions info))), ("cmm-options", not (null (cmmOptions info)))
    ,("cc-options", not (null (ccOptions info))), ("cxx-options", not (null (cxxOptions info))), ("jspp-options", not (null (jsppOptions info))), ("ld-options", not (null (ldOptions info))), ("hsc2hs-options", not (null (hsc2hsOptions info)))
    ,("asm-sources", not (null (asmSources info))), ("cmm-sources", not (null (cmmSources info))), ("c-sources", not (null (cSources info))), ("cxx-sources", not (null (cxxSources info))), ("js-sources", not (null (jsSources info)))
    ,("frameworks", not (null (frameworks info))), ("extra-framework-dirs", not (null (extraFrameworkDirs info))), ("extra-libraries", not (null (extraLibs info))), ("extra-libraries-static", not (null (extraLibsStatic info)))
    ,("extra-ghci-libraries", not (null (extraGHCiLibs info))), ("extra-bundled-libraries", not (null (extraBundledLibs info))), ("extra-library-flavours", not (null (extraLibFlavours info))), ("extra-dynamic-library-flavours", not (null (extraDynLibFlavours info)))
    ,("extra-lib-dirs", not (null (extraLibDirs info))), ("extra-lib-dirs-static", not (null (extraLibDirsStatic info))), ("include-dirs", not (null (includeDirs info))), ("includes", not (null (includes info)))
    ,("autogen-includes", not (null (autogenIncludes info))), ("install-includes", not (null (installIncludes info))), ("autogen-modules", not (null (autogenModules info))), ("virtual-modules", not (null (virtualModules info))), ("mixins", not (null (mixins info)))], present]
 where safe option = option `elem` ["-w", "-O", "-O0", "-O1", "-O2", "-g", "-threaded", "-rtsopts", "-eventlog"] || "-W" `isPrefixOf` option && all (\c -> c == '-' || c == '=' || c `elem` ['a' .. 'z'] || c `elem` ['0' .. '9']) (drop 2 option)
sourceHygiene :: FilePath -> Text -> [SpecProblem]
sourceHygiene file contents = case sourceTokens file contents of
  Left _ -> [OracleSourceUnscanned file]
  Right located -> let tokens = map unLoc located
                       syntax = filter codeToken tokens
                       directives = sourceDirectives contents
                       pragmas = sourcePragmas tokens
                       extensions = concat [names | "LANGUAGE" : names <- pragmas]
                       quoted = if any (\token -> case token of ITsimpleQuote -> True; _ -> False) tokens
                         then templateTree <$> sourceTree file contents else Right False
    in [OracleConditionalCompilation file | "CPP" `elem` extensions || any (\(L span_ _) -> case span_ of
          RealSrcSpan position _ -> (srcSpanStartLine position, srcSpanStartCol position) `elem` directives; _ -> False) located]
      <> [OracleTemplateHaskell file | any (`elem` extensions) ["TemplateHaskell", "TemplateHaskellQuotes", "QuasiQuotes"] || any template tokens || quoted == Right True]
      <> [OracleForeignImport file | any (\pair -> case pair of (ITforeign, ITimport) -> True; (ITforeign, ITexport) -> True; _ -> False) (zip syntax (drop 1 syntax))]
      <> [OracleSourceUnscanned file | either (const True) (const False) quoted || any (\pragma -> take 1 pragma == ["OPTIONS_GHC"]) pragmas || any (\token -> case token of IToptions_prag {} -> True; ITinclude_prag {} -> True; _ -> False) tokens]
 where
  codeToken token = case token of ITblockComment {} -> False; ITlineComment {} -> False; ITdocComment {} -> False; _ -> True
  template token = case token of ITdollar -> True; ITdollardollar -> True; ITopenExpQuote {} -> True; ITopenPatQuote -> True; ITopenDecQuote -> True; ITopenTypQuote -> True; ITopenTExpQuote {} -> True; ITtyQuote -> True; ITquasiQuote {} -> True; ITqQuasiQuote {} -> True; _ -> False
sourceTokens :: FilePath -> Text -> Either Text [Located Token]
sourceTokens file contents = case lexTokenStream sourceOptions (stringToStringBuffer (Text.unpack contents)) (mkRealSrcLoc (mkFastString file) 1 1) of
  PFailed _ -> Left ("SourceUnscanned:" <> Text.pack file)
  POk _ tokens -> Right tokens
sourceOptions :: ParserOpts
sourceOptions = mkParserOpts (EnumSet.fromList (map flagSpecFlag xFlags)) emptyDiagOpts [] False False False False
sourcePragmas :: [Token] -> [[Text]]
sourcePragmas tokens = [Text.words (Text.replace "," " " body) | ITblockComment comment _ <- tokens,
  Just start <- [Text.stripPrefix "{-#" (Text.pack comment)], Just body <- [Text.stripSuffix "#-}" start]]
sourceTree :: FilePath -> Text -> Either Text (HsModule GhcPs)
sourceTree file contents = do
  tokens <- sourceTokens file contents
  let header = takeWhile (\token -> case unLoc token of ITblockComment {} -> True; ITlineComment {} -> True; ITdocComment {} -> True; _ -> False) tokens
  flags <- foldM select (EnumSet.fromList (languageExtensions (Just GHC2024))) [name | "LANGUAGE" : names <- sourcePragmas (map unLoc header), name <- names]
  let observed = foldr enable flags [flagSpecFlag flag | flag <- xFlags, flagSpecName flag `elem` ["TemplateHaskell", "TemplateHaskellQuotes", "QuasiQuotes"]]
      options = mkParserOpts observed emptyDiagOpts [] False False False False
  case unP parseModule (initParserState options (stringToStringBuffer (Text.unpack contents)) (mkRealSrcLoc (mkFastString file) 1 1)) of
    PFailed _ -> Left ("SourceUnscanned:" <> Text.pack file)
    POk _ tree -> Right (unLoc tree)
 where
  extensions = [(Text.pack (flagSpecName flag), flagSpecFlag flag) | flag <- xFlags]
  select flags name
    | Just edition <- lookup name [("GHC2024", GHC2024), ("GHC2021", GHC2021), ("Haskell2010", Haskell2010), ("Haskell98", Haskell98)] = Right (EnumSet.fromList (languageExtensions (Just edition)))
    | Just flag <- lookup name extensions = Right (enable flag flags)
    | Just rest <- Text.stripPrefix "No" name, Just flag <- lookup rest extensions = Right (EnumSet.delete flag flags)
    | otherwise = Left ("SourceExtensionUnscanned:" <> name)
  enable flag flags = foldl (\enabled (yes, dependency) -> if yes then enable dependency enabled else EnumSet.delete dependency enabled) (EnumSet.insert flag flags)
    [(yes, dependency) | (parent, yes, dependency) <- impliedXFlags, parent == flag]
templateTree :: Data a => a -> Bool
templateTree value = maybe False bracket (cast value :: Maybe (HsExpr GhcPs)) || or (gmapQ templateTree value)
 where bracket expression = case expression of HsTypedBracket {} -> True; HsUntypedBracket {} -> True; _ -> False
sourceDirectives :: Text -> [(Int, Int)]
sourceDirectives contents = [(number, Text.foldl' (\column char -> if char == '\t' then column + 8 - (column - 1) `mod` 8 else column + 1) 1 (Text.takeWhile (`elem` (" \t" :: String)) line)) | (number, line) <- zip [1 ..] (Text.lines contents), "#" `Text.isPrefixOf` Text.stripStart line]
moduleSourcePath :: FilePath -> PackageGraph -> Text -> ProductionModule -> IO (Maybe FilePath)
moduleSourcePath root graph stanza (ProductionModule name) =
  fmap (fmap (makeRelative root)) (findFile [root </> dir | (_, _, dirs) <- maybe [] pure (Map.lookup stanza (graphLibraries graph)), dir <- dirs] (Text.unpack (Text.replace "." "/" name) <> ".hs"))
-- Private supplied-data decoding only; Right does not authenticate an execution.
data WireProblem = MissingFooter | DuplicateFooter | FooterNotLast | FooterMalformed | EncodingMismatch | InvocationMismatch | CountMismatch | PrefixDigestMismatch | SummaryMismatch | TerminalMismatch | OrdinaryRowsInvalid | OrdinaryInventoryMismatch | NativeObservationUnavailable | RefusalLocusMismatch | MissingInputNotObserved | KnownAbnormalTermination deriving (Eq, Show)
data WireLocus = StdoutFooter | StdoutFooterName | StdoutAfterFooter | FooterTerminator | FooterFieldCount | FooterVerdict | FooterEncoding | FooterChallenge | FooterCount | FooterPrefixDigest | FooterPurpose | FooterLocus | OrdinaryPrefix | OrdinaryNames | NativeBoundary | NativeTerminal | InputRead deriving (Bounded, Enum, Eq, Ord, Show)
data WireFault = WireFault WireProblem WireLocus deriving (Eq, Show)
data WirePurpose = FinishedAllGreen | FinishedSomeRed | RequiredInputMissing Text deriving (Eq, Show)
data WireFrame = WireFrame { retainedCompleteStdout :: Text, retainedOrdinaryPrefix :: Text , ordinaryRows :: [(Text, Text, Text)], footerChallenge :: Text , footerOrdinaryCount :: Natural, footerPrefixDigest :: Text , footerPurpose :: WirePurpose } deriving (Eq, Show)
-- Supplied transcript inspection returns data only, never native/read/image authority.
data OracleTranscriptKind = OrdinaryTranscript [Text] | InventoryTranscript | MissingInputTranscript Text (Maybe Text) deriving (Eq, Show)
inspectOracleTranscript :: OracleTranscriptKind -> Text -> ObservedRun -> Either (Text,Text) (Text,Text,[(Text,Text,Text)],Text,Integer,Text,Text,Maybe Text)
inspectOracleTranscript kind issued run = either failed (Right . viewed) $ case kind of {OrdinaryTranscript names -> completionFrame issued names run; InventoryTranscript -> inventoryCompletionFrame issued run; MissingInputTranscript expected observed -> either (Left . CompletionWire) Right (probeWireFrame issued expected observed (completionTerminal run) (runStdout run))}
 where failed (CompletionWire fault) = Left (renderWireFault fault); failed other = Left (showText other,"inventory.declaration")
       viewed frame = let (purpose,path) = case footerPurpose frame of {FinishedAllGreen -> ("all-green",Nothing); FinishedSomeRed -> ("some-red",Nothing); RequiredInputMissing value -> ("required-input-missing",Just value)} in (retainedCompleteStdout frame,retainedOrdinaryPrefix frame,ordinaryRows frame,footerChallenge frame,toInteger (footerOrdinaryCount frame),footerPrefixDigest frame,purpose,path)
decodeRetainedWire :: Text -> Either WireFault WireFrame
decodeRetainedWire output = case break reserved physicalRows of
  (_, []) -> Left (WireFault MissingFooter StdoutFooter)
  (prefixRows, footer : after)
    | any reserved after -> Left (WireFault DuplicateFooter StdoutFooterName)
    | null after -> Left (WireFault FooterMalformed FooterTerminator)
    | after /= [""] -> Left (WireFault FooterNotLast StdoutAfterFooter)
    | Text.isSuffixOf "\r" footer -> Left (WireFault FooterMalformed FooterTerminator)
    | otherwise -> case Text.splitOn "\t" footer of
        [_, verdict, encoding, challenge, countText, digest, purposeText, locus] -> do
          wireRequire FooterMalformed FooterVerdict (verdict == "green")
          wireRequire EncodingMismatch FooterEncoding (encoding == "retained-text-utf8.v1")
          wireRequire FooterMalformed FooterChallenge (digestShape challenge)
          count <- wireNatural countText
          wireRequire FooterMalformed FooterPrefixDigest (digestShape digest)
          purpose <- case purposeText of
            "all-green" -> wireRequire FooterMalformed FooterLocus (locus == "-") >> pure FinishedAllGreen
            "some-red" -> wireRequire FooterMalformed FooterLocus (locus == "-") >> pure FinishedSomeRed
            "required-input-missing" -> RequiredInputMissing <$> wireQuotedText locus
            _ -> Left (WireFault FooterMalformed FooterPurpose)
          let prefix = Text.concat [row <> "\n" | row <- prefixRows]
              parsed = parseLedger Nothing prefix
              rows = ledgerRows parsed
              actualCount = foldr (const (+ 1)) 0 rows :: Natural
          wireRequire OrdinaryRowsInvalid OrdinaryPrefix (Text.null prefix || ledgerValid parsed)
          wireRequire CountMismatch FooterCount (count == actualCount)
          wireRequire PrefixDigestMismatch FooterPrefixDigest (digest == sha256Hex prefix)
          pure (WireFrame output prefix rows challenge count digest purpose)
        _ -> Left (WireFault FooterMalformed FooterFieldCount)
 where
  physicalRows = Text.splitOn "\n" output
  reserved row = Text.takeWhile (/= '\t') row == "oracle.protocol.complete.v1"
wireRequire :: WireProblem -> WireLocus -> Bool -> Either WireFault ()
wireRequire problem locus condition = if condition then Right () else Left (WireFault problem locus)
wireNatural :: Text -> Either WireFault Natural
wireNatural value = case reads (Text.unpack value) of
  [(count, "")] | Text.pack (show count) == value -> Right count
  _ -> Left (WireFault FooterMalformed FooterCount)
wireQuotedText :: Text -> Either WireFault Text
wireQuotedText value
  | Just ('"', _) <- Text.uncons value
  , [(decoded, "")] <- reads (Text.unpack value) = Right decoded
  | otherwise = Left (WireFault FooterMalformed FooterLocus)
renderWireFault :: WireFault -> (Text, Text)
renderWireFault (WireFault problem locus) = (Text.pack (show problem), renderWireLocus locus)
renderWireLocus :: WireLocus -> Text
renderWireLocus StdoutFooterName = "stdout.footer.name"
renderWireLocus locus = group <> position <> "." <> Text.drop 1 field
 where
  (group, field) = Text.breakOn "-" (renderConstructorTag locus)
  position = if locus >= FooterVerdict && locus <= FooterLocus then "[" <> showText (fromEnum locus - fromEnum FooterVerdict + 2) <> "]" else ""
-- Supplied normal-frame consistency only; no acquired execution authority.
normalWireFrame :: Text -> [Text] -> Either WireFault Int -> Text -> Either WireFault WireFrame
normalWireFrame issued names terminal output = do
  exit <- terminal
  frame <- decodeRetainedWire output
  wireRequire InvocationMismatch FooterChallenge (footerChallenge frame == issued)
  wireRequire MissingInputNotObserved FooterPurpose (case footerPurpose frame of RequiredInputMissing _ -> False; _ -> True)
  wireRequire OrdinaryRowsInvalid OrdinaryPrefix (not (null (ordinaryRows frame)))
  wireRequire OrdinaryInventoryMismatch OrdinaryNames (length names == Set.size (Set.fromList names) && Set.fromList names == Set.fromList [name | (name, _, _) <- ordinaryRows frame])
  let someRed = any (\(_, verdict, _) -> verdict == "red") (ordinaryRows frame)
  wireRequire SummaryMismatch FooterPurpose (footerPurpose frame == if someRed then FinishedSomeRed else FinishedAllGreen)
  wireRequire TerminalMismatch NativeTerminal (exit == if someRed then 1 else 0)
  pure frame
-- Supplied absence consistency only; no actual read is acquired here.
probeWireFrame :: Text -> Text -> Maybe Text -> Either WireFault Int -> Text -> Either WireFault WireFrame
probeWireFrame issued expected suppliedAbsence terminal output = do
  exit <- terminal
  frame <- decodeRetainedWire output
  wireRequire InvocationMismatch FooterChallenge (footerChallenge frame == issued)
  path <- case footerPurpose frame of RequiredInputMissing value -> Right value; _ -> Left (WireFault MissingInputNotObserved FooterPurpose)
  wireRequire OrdinaryRowsInvalid OrdinaryPrefix (Text.null (retainedOrdinaryPrefix frame))
  attempted <- maybe (Left (WireFault MissingInputNotObserved InputRead)) Right suppliedAbsence
  wireRequire RefusalLocusMismatch FooterLocus (not (Text.null expected) && attempted == expected && path == expected)
  wireRequire TerminalMismatch NativeTerminal (exit == 1)
  pure frame
