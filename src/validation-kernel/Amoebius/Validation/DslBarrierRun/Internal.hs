{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.DslBarrierRun.Internal
  ( AcquiredDslBarrierRun
  , acquireDslBarrierRefreshRun
  , acquireDslBarrierRun
  , acquiredDslBarrierRunCheck
  , foldAcquiredDslBarrierRun
  ) where

import Amoebius.Validation.BootstrapTrust.Internal
  ( GenesisTrust, genesisTrustCheck, genesisTrustCompilerExecutable, genesisTrustToolchainIdentity )
import Amoebius.Validation.PhaseContract.Internal
  ( AcquiredPhaseContractEvidence, acquirePhaseContractEvidenceFor
  , acquireRecordedPhaseContractEvidence, acquiredPhaseContractEvidenceCheck )
import Amoebius.Validation.SourceClosure.Internal
  ( AcquiredSourceSnapshot, IndexEntry (indexPath), SourceSnapshot (snapshotEntries, snapshotIdentity)
  , TrackedEntry (trackedBytes, trackedIndex), acquiredSourceSnapshot )
import Amoebius.Validation.Types (CheckResult (..), finding, mergeChecks, observation)
import Control.Exception (IOException, try)
import Control.Monad (forM, forM_)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Char (intToDigit)
import Data.List (find, isInfixOf, isPrefixOf, isSuffixOf, nub, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Text.IO qualified as TextIO
import System.Directory
  ( copyFile, createDirectory, createDirectoryIfMissing, doesDirectoryExist
  , doesFileExist, getHomeDirectory, listDirectory, removeFile )
import System.Environment (getEnvironment)
import System.Exit (ExitCode (..))
import System.FilePath (isAbsolute, makeRelative, normalise, takeDirectory, takeFileName, (</>))
import System.IO (hClose, openBinaryTempFile)
import System.Process (CreateProcess (cwd, env), proc, readCreateProcessWithExitCode)

data Receipt = Receipt Text FilePath [String] ExitCode Text Text deriving (Eq, Show)
data Mutant = Mutant Text String Receipt deriving (Eq, Show)
data SelectorAttempt = SelectorAttempt Text FilePath Text Text Text Receipt Receipt Text deriving (Eq, Show)
data SelectorSuiteRun = SelectorSuiteRun Text Receipt Receipt Receipt Receipt Text [SelectorAttempt] deriving (Eq, Show)
data SelectorMatrix = SelectorMatrix Receipt Receipt [SelectorSuiteRun] deriving (Eq, Show)
data Matrix = Matrix [Receipt] [Mutant] Receipt Receipt Receipt Receipt [Receipt] SelectorMatrix

data SelectorSuiteSpec = SelectorSuiteSpec
  { selectorComponent :: String
  , selectorMainPath :: FilePath
  }

data SourceModule = SourceModule
  { sourceModulePath :: FilePath
  , sourceModuleName :: Text
  , sourceModuleImports :: [Text]
  , sourceModuleBytes :: ByteString
  }

data QualificationEnvironment = QualificationEnvironment
  { qualificationCompiler :: FilePath
  , qualificationPackageDb :: FilePath
  , qualificationStorePackageDb :: FilePath
  , qualificationBuildPackageDb :: FilePath
  , qualificationPackageIds :: [String]
  , qualificationSetupReceipts :: (Receipt, Receipt)
  }

data AcquiredDslBarrierRun
  = AcquiredDslBarrierRun
      AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
      Text Text Text Text Text Text Text Text CheckResult

acquiredDslBarrierRunCheck :: AcquiredDslBarrierRun -> CheckResult
acquiredDslBarrierRunCheck (AcquiredDslBarrierRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredDslBarrierRun ::
  (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult] ->
   Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value) ->
  AcquiredDslBarrierRun -> value
foldAcquiredDslBarrierRun consume (AcquiredDslBarrierRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireDslBarrierRun, acquireDslBarrierRefreshRun ::
  FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredDslBarrierRun
acquireDslBarrierRun = acquire False
acquireDslBarrierRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredDslBarrierRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  home <- getHomeDirectory
  let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
      compiler = genesisTrustCompilerExecutable trust
      store = home </> ".cabal/store"
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 49 acquired
  cache <- prepareSourceRepositoryCache root runRoot
  cabalVersion <- runProcess root "cabal-version" cabal ["--numeric-version"]
  matrix <- executeMatrix root runRoot cabal compiler store (acquiredSourceSnapshot acquired)
  discipline <- sourceDisciplineCheck root acquired
  let toolchain = toolchainCheck cabal compiler store cabalVersion matrix
      oracle = oracleCheck matrix
      positives = positiveCheck matrix
      negatives = negativeCheck matrix
      mutants = mutantCheck matrix
      discovery = discoveryCheck discipline matrix
      authority = authorityCheck root runRoot cabal compiler store (cabalVersion : matrixReceipts matrix)
      observer = observerCheck matrix
      freshness = freshnessCheck root runRoot matrix
      qualification = qualificationCheck root runRoot store matrix
      cleanroomWithoutLegacy = mergeChecks "dsl-barrier-cleanroom-boundaries" [cache, discipline, authority]
      legacy = legacyCheck acquired contract matrix toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroomWithoutLegacy
      cleanroom = mergeChecks "dsl-barrier-cleanroom" [cleanroomWithoutLegacy, legacy]
      prerequisite = mergeChecks "dsl-barrier-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, toolchain, oracle, positives,
         negatives, mutants, discovery, authority, observer, freshness, qualification, cleanroom]
      rows = phaseRows prerequisite toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy
      result = mergeChecks "dsl-barrier" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "dsl-barrier-subject" [checkDigest positives, checkDigest discipline]
      oracleId = ids "dsl-barrier-oracle" [checkDigest oracle, checkDigest negatives]
      harnessId = ids "dsl-barrier-harness" (selectorMatrixDigest (matrixSelectorMatrix matrix) : map receiptDigest (cabalVersion : matrixReceipts matrix))
      observerId = ids "dsl-barrier-observer" [checkDigest observer]
      qualificationId = ids "dsl-barrier-qualification" [checkDigest qualification]
      acquiredRunId = ids "dsl-barrier-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "dsl-barrier-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest cabalVersion]
      cleanup = "run-root-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-child-residue=0;live-effects=0"
  pure (AcquiredDslBarrierRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

executeMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> SourceSnapshot -> IO Matrix
executeMatrix root runRoot cabal compiler store snapshot = do
  spine <- forM spineComponents $ \component ->
    runTest ("spine-" <> Text.pack component) [component] []
  mutants <- mapM runMutant mutantSpecifications
  cleanFirst <- runTest "clean-first" ["self-referential-gates-spec"] ["--test-options=--challenge phase-49-first-challenge"]
  cleanSecond <- runTest "clean-second" ["self-referential-gates-spec"] ["--test-options=--challenge phase-49-second-challenge"]
  legal <- runCompile "compile-legal" legalSource
  illegal <- runCompile "compile-teardown-leak" illegalSource
  qualification <- forM qualificationComponents $ \component ->
    runTest ("qualification-" <> Text.pack component) [component] ["--test-options=--all"]
  selectorMatrix <- executeSelectorMatrix root runRoot compiler store snapshot qualification
  pure (Matrix spine mutants cleanFirst cleanSecond legal illegal qualification selectorMatrix)
 where
  common =
    [ "--builddir=" <> (runRoot </> "dist"), "--store-dir=" <> store
    , "--with-compiler=" <> compiler, "--jobs=1", "--offline" ]
  flags selected = [if Just flagName == selected then "-f" <> flagName else "-f-" <> flagName | (_, flagName) <- mutantSpecifications]
  runTest prefix components options =
    runProcessWithEnvironment root (componentEnvironment components) (prefix <> ":" <> Text.pack (unwords components)) cabal
      (common <> ["test"] <> components <> ["--offline", "--test-show-details=direct"] <> options <> flags Nothing)
  componentEnvironment ["gadt-decode-spec"] =
    [("AMOEBIUS_GADT_DECODE_OUTPUT", runRoot </> "generated/gadt-decode")]
  componentEnvironment _ = []
  runMutant (name, flagName) = Mutant name flagName <$> runProcess root ("mutant-" <> name) cabal
    (common <> ["test", "self-referential-gates-spec", "--offline", "--test-show-details=direct",
      "--test-options=--challenge phase-49-mutant-" <> Text.unpack name] <> flags (Just flagName))
  runCompile name fixture = runProcess root name cabal
    (common <> flags Nothing <>
      ["exec", "--", compiler, "-fno-code", "-fforce-recomp", "-XGHC2024",
       "-isrc/self-referential-gates", "-isrc/workflow-calculus", "-package", "text", fixture])

spineComponents :: [String]
spineComponents = ["gadt-decode-spec", "capability-bind-spec", "provision-seal-spec", "render-golden", "chain-spec"]

qualificationComponents :: [String]
qualificationComponents =
  [ "validation-phase-contract-component", "validation-phase-contract-internal-component"
  , "validation-policy-contract-selector-component", "validation-legacy-selector-component"
  , "validation-source-closure-selector-component", "validation-source-consumer-selector-component"
  , "validation-documentation-selector-component", "validation-dispatch-selector-component"
  , "validation-compiler-buildinfo-selector-component", "validation-compiler-elaborated-plan-selector-component"
  , "validation-compiler-source-graph-selector-component", "validation-source-debt-selector-component"
  , "validation-phase-semantic-selector-component", "validation-qualification-selector-component"
  , "validation-documentation-internal-selector-component", "validation-source-consumer-internal-selector-component"
  ]

selectorSuiteSpecifications :: [SelectorSuiteSpec]
selectorSuiteSpecifications =
  [ SelectorSuiteSpec "validation-phase-contract-component" "test/validation-kernel/phase-contract/Main.hs"
  , SelectorSuiteSpec "validation-phase-contract-internal-component" "test/validation-kernel/phase-contract-internal/Main.hs"
  , SelectorSuiteSpec "validation-policy-contract-selector-component" "test/validation-kernel/policy-contract-selector/Main.hs"
  , SelectorSuiteSpec "validation-legacy-selector-component" "test/validation-kernel/legacy-selector/Main.hs"
  , SelectorSuiteSpec "validation-source-closure-selector-component" "test/validation-kernel/source-closure-selector/Main.hs"
  , SelectorSuiteSpec "validation-source-consumer-selector-component" "test/validation-kernel/source-consumer-selector/Main.hs"
  , SelectorSuiteSpec "validation-documentation-selector-component" "test/validation-kernel/documentation-selector/Main.hs"
  , SelectorSuiteSpec "validation-dispatch-selector-component" "test/validation-kernel/dispatch-selector/Main.hs"
  , SelectorSuiteSpec "validation-compiler-buildinfo-selector-component" "test/validation-kernel/compiler-buildinfo-selector/Main.hs"
  , SelectorSuiteSpec "validation-compiler-elaborated-plan-selector-component" "test/validation-kernel/compiler-elaborated-plan-selector/Main.hs"
  , SelectorSuiteSpec "validation-compiler-source-graph-selector-component" "test/validation-kernel/compiler-source-graph-selector/Main.hs"
  , SelectorSuiteSpec "validation-source-debt-selector-component" "test/validation-kernel/source-debt-selector/Main.hs"
  , SelectorSuiteSpec "validation-phase-semantic-selector-component" "test/validation-kernel/phase-semantic-selector/Main.hs"
  , SelectorSuiteSpec "validation-qualification-selector-component" "test/validation-kernel/qualification-selector/Main.hs"
  , SelectorSuiteSpec "validation-documentation-internal-selector-component" "test/validation-kernel/documentation-internal-selector/Main.hs"
  , SelectorSuiteSpec "validation-source-consumer-internal-selector-component" "test/validation-kernel/source-consumer-internal-selector/Main.hs"
  ]

executeSelectorMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> SourceSnapshot -> [Receipt] -> IO SelectorMatrix
executeSelectorMatrix root runRoot compiler store snapshot cleanReceipts = do
  environment <- prepareQualificationEnvironment root runRoot compiler store
  let (recacheReceipt, registerReceipt) = qualificationSetupReceipts environment
  suites <-
    if any ((/= ExitSuccess) . receiptExit) [recacheReceipt, registerReceipt]
      then pure []
      else executeSelectorSuites root runRoot snapshot environment [] (zip selectorSuiteSpecifications cleanReceipts)
  pure (SelectorMatrix recacheReceipt registerReceipt suites)

executeSelectorSuites :: FilePath -> FilePath -> SourceSnapshot -> QualificationEnvironment -> [SelectorSuiteRun] -> [(SelectorSuiteSpec, Receipt)] -> IO [SelectorSuiteRun]
executeSelectorSuites root runRoot snapshot environment completed remaining = case remaining of
  [] -> pure (reverse completed)
  (specification, cleanReceipt) : rest -> do
    suite <- executeSelectorSuite root runRoot snapshot environment specification cleanReceipt
    if selectorSuitePassed suite
      then executeSelectorSuites root runRoot snapshot environment (suite : completed) rest
      else pure (reverse (suite : completed))

prepareQualificationEnvironment :: FilePath -> FilePath -> FilePath -> FilePath -> IO QualificationEnvironment
prepareQualificationEnvironment root runRoot compiler store = do
  buildDbs <- listDirectory (runRoot </> "dist/packagedb")
  let buildDb = runRoot </> "dist/packagedb" </> case sort buildDbs of
        entry : _ -> entry
        [] -> "missing-package-db"
  configurationPaths <- findFilesWithSuffix buildDb "validation-kernel.conf"
  let configurationPath = case sort configurationPaths of
        entry : _ -> entry
        [] -> buildDb </> "missing-validation-kernel.conf"
      exposedDb = runRoot </> "qualification/package-db"
      exposedConfiguration = runRoot </> "qualification/validation-kernel.conf"
      compilerVersion = takeFileName (takeDirectory (takeDirectory compiler))
      ghcPkg = takeDirectory compiler </> "ghc-pkg-" <> compilerVersion
  storeEntries <- listDirectory store
  let storeDb = store </> case sort (filter (("ghc-" <> compilerVersion <> "-") `isPrefixOf`) storeEntries) of
        entry : _ -> entry </> "package.db"
        [] -> "missing-store-package-db"
  createDirectoryIfMissing True exposedDb
  configuration <- TextIO.readFile configurationPath
  let qualificationConfiguration = exposeHiddenModules configuration
  TextIO.writeFile exposedConfiguration qualificationConfiguration
  recacheReceipt <- runProcess root "selector-package-db-recache" ghcPkg ["--package-db=" <> exposedDb, "recache"]
  registerReceipt <- runProcess root "selector-package-db-register" ghcPkg
    [ "--package-db=" <> storeDb, "--package-db=" <> exposedDb
    , "register", exposedConfiguration, "--force" ]
  pure QualificationEnvironment
    { qualificationCompiler = compiler
    , qualificationPackageDb = exposedDb
    , qualificationStorePackageDb = storeDb
    , qualificationBuildPackageDb = buildDb
    , qualificationPackageIds = nub (configurationPackageIds qualificationConfiguration)
    , qualificationSetupReceipts = (recacheReceipt, registerReceipt)
    }

exposeHiddenModules :: Text -> Text
exposeHiddenModules input =
  case Text.breakOn "hidden-modules:\n" input of
    (before, hiddenWithRest)
      | Text.null hiddenWithRest -> input
      | otherwise ->
          let hiddenAndRest = Text.drop (Text.length "hidden-modules:\n") hiddenWithRest
              (hidden, rest) = Text.breakOn "\n\nimport-dirs:" hiddenAndRest
           in before <> hidden <> "\nhidden-modules:\n" <> rest

configurationPackageIds :: Text -> [String]
configurationPackageIds configuration =
  maybe [] (pure . Text.unpack) (fieldValue "id:" configuration)
    <> map Text.unpack (Text.words dependsBody)
 where
  afterDepends = snd (Text.breakOn "depends:\n" configuration)
  dependsAndRest = Text.drop (Text.length "depends:\n") afterDepends
  dependsBody = fst (Text.breakOn "\n\n" dependsAndRest)

fieldValue :: Text -> Text -> Maybe Text
fieldValue prefix input =
  Text.strip . Text.drop (Text.length prefix) <$> find (prefix `Text.isPrefixOf`) (Text.lines input)

executeSelectorSuite :: FilePath -> FilePath -> SourceSnapshot -> QualificationEnvironment -> SelectorSuiteSpec -> Receipt -> IO SelectorSuiteRun
executeSelectorSuite root runRoot snapshot environment specification cleanReceipt = do
  executables <- findFilesNamed (runRoot </> "dist/build") (selectorComponent specification)
  let cleanExecutable = case filter (isInfixOf ("/t/" <> selectorComponent specification <> "/")) executables of
        entry : _ -> entry
        [] -> runRoot </> "missing" </> selectorComponent specification
  listReceipt <- runProcess root ("selector-list:" <> Text.pack (selectorComponent specification)) cleanExecutable ["--list"]
  assignmentsReceipt <- runProcess root ("selector-assignments:" <> Text.pack (selectorComponent specification)) cleanExecutable ["--assignments"]
  let selectors = nonemptyLines (receiptStdout listReceipt)
      assignments = [name | line <- nonemptyLines (receiptStdout assignmentsReceipt), name : _ <- [Text.splitOn "\t" line]]
      productionModules = sourceModulesUnder "src/validation-kernel/" snapshot
      testModules = sourceModulesUnder "test/validation-kernel/" snapshot
      targets = nub [path | selector <- selectors, path <- selectorSourcePaths productionModules selector]
      requiredHomeModules = selectorRequiredHomeModules specification
      requiredHomePaths = [sourceModulePath entry | entry <- productionModules, sourceModuleName entry `elem` requiredHomeModules]
      parentFacadePaths =
        [ facade
        | target <- targets
        , takeFileName target == "Internal.hs"
        , let facade = takeDirectory target <> ".hs"
        , any ((== facade) . sourceModulePath) productionModules
        ]
      graphRoutes
        | selectorComponent specification == "validation-phase-contract-internal-component" = targets
        | otherwise = selectorRoutePaths productionModules testModules (selectorMainPath specification) targets
      routes = nub (graphRoutes <> parentFacadePaths <> requiredHomePaths)
      suiteRoot = runRoot </> "qualification" </> selectorComponent specification
      overlay = suiteRoot </> "overlay"
      objects = suiteRoot </> "objects"
      executable = suiteRoot </> "selector-subject"
  createDirectoryIfMissing True objects
  mapM_ (writeSourceModule overlay) [entry | entry <- productionModules, sourceModulePath entry `elem` routes]
  cleanCompile <- compileSelectorExecutable root environment specification overlay objects executable
  cleanRun <- if receiptExit cleanCompile == ExitSuccess
    then runProcess root ("selector-clean:" <> Text.pack (selectorComponent specification)) executable ["--all"]
    else pure (failedReceipt "selector-clean-not-built" executable ["--all"])
  let cleanTranscriptPath = suiteRoot </> "transcripts/000000-clean.log"
  createDirectoryIfMissing True (takeDirectory cleanTranscriptPath)
  TextIO.writeFile cleanTranscriptPath (renderReceipt cleanCompile <> "\n" <> renderReceipt cleanRun)
  cleanDigest <- executableDigest executable
  attempts <-
    if receiptExit listReceipt /= ExitSuccess
        || receiptExit assignmentsReceipt /= ExitSuccess
        || selectors /= assignments
        || length selectors /= length (nub selectors)
        || receiptExit cleanCompile /= ExitSuccess
        || receiptExit cleanRun /= ExitSuccess
        || Text.null cleanDigest
      then pure []
      else executeSelectorAttempts root productionModules environment specification suiteRoot overlay objects executable cleanDigest [] (zip [1 :: Int ..] selectors)
  let inventoryDigest = digestTexts (Text.pack (selectorComponent specification) : selectors <> assignments <> [receiptDigest cleanReceipt])
  -- Force the inventory join before returning so a malformed assignment
  -- cannot be skipped merely because a later compiler row fails.
  inventoryDigest `seq`
    pure (SelectorSuiteRun (Text.pack (selectorComponent specification)) listReceipt assignmentsReceipt cleanCompile cleanRun cleanDigest attempts)

executeSelectorAttempts :: FilePath -> [SourceModule] -> QualificationEnvironment -> SelectorSuiteSpec -> FilePath -> FilePath -> FilePath -> FilePath -> Text -> [SelectorAttempt] -> [(Int, Text)] -> IO [SelectorAttempt]
executeSelectorAttempts root productionModules environment specification suiteRoot overlay objects executable cleanDigest completed remaining = case remaining of
  [] -> pure (reverse completed)
  (ordinal, selector) : rest -> do
    let matching = selectorSourcePaths productionModules selector
        targetPath = case matching of
          [entry] -> entry
          [] -> "<missing-selector-source>"
          entries -> "<ambiguous-selector-source:" <> show (length entries) <> ">"
        targetModule = find ((== targetPath) . sourceModulePath) productionModules
        beforeBytes = maybe ByteString.empty sourceModuleBytes targetModule
        afterBytes = TextEncoding.encodeUtf8 ("{-# OPTIONS_GHC -D" <> selector <> " #-}\n") <> beforeBytes
        overlayPath = case matching of
          [path] -> overlay </> makeRelative "src/validation-kernel" path
          _ -> suiteRoot </> "invalid-selector-source.hs"
    createDirectoryIfMissing True (takeDirectory overlayPath)
    ByteString.writeFile overlayPath afterBytes
    executablePresent <- doesFileExist executable
    if executablePresent then removeFile executable else pure ()
    compileReceipt <- compileSelectorExecutable root environment specification overlay objects executable
    changedDigest <- executableDigest executable
    runReceipt <- if receiptExit compileReceipt == ExitSuccess
      then runProcess root ("selector-mutant:" <> selector) executable ["--qualify", Text.unpack selector]
      else pure (failedReceipt ("selector-mutant-not-built:" <> selector) executable ["--qualify", Text.unpack selector])
    ByteString.writeFile overlayPath beforeBytes
    restoredBytes <- ByteString.readFile overlayPath
    let beforeDigest = sha256 beforeBytes
        afterDigest = sha256 afterBytes
        restoredDigest = sha256 restoredBytes
        transcriptPath = suiteRoot </> "transcripts" </> padOrdinal ordinal <> ".log"
    createDirectoryIfMissing True (takeDirectory transcriptPath)
    TextIO.writeFile transcriptPath (renderReceipt compileReceipt <> "\n" <> renderReceipt runReceipt)
    let attempt = SelectorAttempt selector targetPath beforeDigest afterDigest changedDigest compileReceipt runReceipt restoredDigest
    if selectorAttemptPassed cleanDigest attempt
      then executeSelectorAttempts root productionModules environment specification suiteRoot overlay objects executable cleanDigest (attempt : completed) rest
      else pure (reverse (attempt : completed))

selectorSuitePassed :: SelectorSuiteRun -> Bool
selectorSuitePassed (SelectorSuiteRun _ listReceipt assignmentsReceipt cleanCompile cleanRun cleanDigest attempts) =
  receiptExit listReceipt == ExitSuccess
    && receiptExit assignmentsReceipt == ExitSuccess
    && receiptExit cleanCompile == ExitSuccess
    && receiptExit cleanRun == ExitSuccess
    && not (Text.null cleanDigest)
    && listed == assigned
    && listed == executed
    && not (null listed)
    && length listed == length (nub listed)
    && all (selectorAttemptPassed cleanDigest) attempts
 where
  listed = nonemptyLines (receiptStdout listReceipt)
  assigned = [selector | line <- nonemptyLines (receiptStdout assignmentsReceipt), selector : _ <- [Text.splitOn "\t" line]]
  executed = [selector | SelectorAttempt selector _ _ _ _ _ _ _ <- attempts]

selectorAttemptPassed :: Text -> SelectorAttempt -> Bool
selectorAttemptPassed cleanDigest (SelectorAttempt selector target before after changedBinary compileReceipt runReceipt restored) =
  "src/validation-kernel/" `isPrefixOf` target
    && not (Text.null before)
    && before /= after
    && restored == before
    && receiptExit compileReceipt == ExitSuccess
    && validSelectorCompilerReceipt compileReceipt
    && not (Text.null changedBinary)
    && changedBinary /= cleanDigest
    && receiptExit runReceipt == ExitSuccess
    && notContains ("selector-qualification: PASS: " <> selector) (receiptOutput runReceipt) == False

compileSelectorExecutable :: FilePath -> QualificationEnvironment -> SelectorSuiteSpec -> FilePath -> FilePath -> FilePath -> IO Receipt
compileSelectorExecutable root environment specification overlay objects executable = do
  homeSources <- sort <$> findFilesWithSuffix overlay ".hs"
  runProcess root ("selector-compile:" <> Text.pack (selectorComponent specification)) (qualificationCompiler environment)
    ( [ "--make", "-O0", "-fforce-recomp", "-XGHC2024"
      , "-clear-package-db", "-global-package-db"
      , "-package-db", qualificationStorePackageDb environment
      , "-package-db", qualificationBuildPackageDb environment
      , "-package-db", qualificationPackageDb environment
      , "-hide-all-packages"
      ]
      <> concatMap (\identifier -> ["-package-id", identifier]) (qualificationPackageIds environment)
      <> [ "-package", "memory", "-package", "temporary"
         , "-i" <> overlay, "-itest/validation-kernel"
         , "-outputdir", objects, "-o", executable
         ]
      <> homeSources
      <> [selectorMainPath specification]
      <> selectorCppOptions specification
    )

selectorCppOptions :: SelectorSuiteSpec -> [String]
selectorCppOptions specification
  | selectorComponent specification == "validation-phase-contract-internal-component" =
      ["-DVALIDATION_PHASE_CONTRACT_INTERNAL_SELECTOR_QUALIFICATION"]
  | selectorComponent specification == "validation-legacy-selector-component" =
      ["-DVALIDATION_LEGACY_INTERNAL_SELECTOR_QUALIFICATION"]
  | otherwise = []

selectorRequiredHomeModules :: SelectorSuiteSpec -> [Text]
selectorRequiredHomeModules _ = []

sourceModulesUnder :: FilePath -> SourceSnapshot -> [SourceModule]
sourceModulesUnder prefix snapshot =
  [ SourceModule path name (moduleImports contents) bytes
  | entry <- snapshotEntries snapshot
  , let path = indexPath (trackedIndex entry)
  , prefix `isPrefixOf` path
  , ".hs" `isSuffixOf` path
  , let bytes = trackedBytes entry
  , Right contents <- [TextEncoding.decodeUtf8' bytes]
  , Just name <- [moduleName contents]
  ]

moduleName :: Text -> Maybe Text
moduleName contents =
  case [Text.takeWhile moduleCharacter (Text.drop (Text.length "module ") stripped) | line <- Text.lines contents, let stripped = Text.strip line, "module " `Text.isPrefixOf` stripped] of
    entry : _ | not (Text.null entry) -> Just entry
    _ -> Nothing
 where moduleCharacter character = character /= ' ' && character /= '(' && character /= '\t'

moduleImports :: Text -> [Text]
moduleImports contents = nub
  [ token
  | line <- Text.lines contents
  , let stripped = Text.strip line
  , "import " `Text.isPrefixOf` stripped
  , token <- case Text.words stripped of
      "import" : "qualified" : name : _ -> [name]
      "import" : name : _ -> [name]
      _ -> []
  ]

selectorSourcePaths :: [SourceModule] -> Text -> [FilePath]
selectorSourcePaths modules selector =
  [sourceModulePath entry | entry <- modules, selector `Text.isInfixOf` TextEncoding.decodeUtf8 (sourceModuleBytes entry)]

selectorRoutePaths :: [SourceModule] -> [SourceModule] -> FilePath -> [FilePath] -> [FilePath]
selectorRoutePaths productionModules testModules mainPath targets = nub (concatMap route targets)
 where
  testRoots = productionImportsFromTestClosure testModules mainPath
  targetName path = sourceModuleName <$> find ((== path) . sourceModulePath) productionModules
  route path = case targetName path of
    Nothing -> [path]
    Just name -> case firstRoute testRoots name of
      Just names -> [sourceModulePath entry | candidate <- names, entry <- productionModules, sourceModuleName entry == candidate]
      Nothing -> [path]
  firstRoute roots target = case [path | rootName <- roots, Just path <- [moduleRoute productionModules [] rootName target]] of
    path : _ -> Just path
    [] -> Nothing

productionImportsFromTestClosure :: [SourceModule] -> FilePath -> [Text]
productionImportsFromTestClosure testModules mainPath = nub (walk [] starts)
 where
  starts = [sourceModuleName entry | entry <- testModules, sourceModulePath entry == mainPath]
  walk seen names = case names of
    [] -> []
    name : rest
      | name `elem` seen -> walk seen rest
      | otherwise -> case find ((== name) . sourceModuleName) testModules of
          Nothing -> walk (name : seen) rest
          Just entry ->
            let imports = sourceModuleImports entry
                local = [candidate | candidate <- imports, any ((== candidate) . sourceModuleName) testModules]
                production = [candidate | candidate <- imports, "Amoebius." `Text.isPrefixOf` candidate]
             in production <> walk (name : seen) (local <> rest)

moduleRoute :: [SourceModule] -> [Text] -> Text -> Text -> Maybe [Text]
moduleRoute modules seen current target
  | current == target = Just [current]
  | current `elem` seen = Nothing
  | otherwise = case find ((== current) . sourceModuleName) modules of
      Nothing -> Nothing
      Just entry -> case [current : route | imported <- sourceModuleImports entry, Just route <- [moduleRoute modules (current : seen) imported target]] of
        route : _ -> Just route
        [] -> Nothing

writeSourceModule :: FilePath -> SourceModule -> IO ()
writeSourceModule overlay entry = do
  let path = overlay </> makeRelative "src/validation-kernel" (sourceModulePath entry)
  createDirectoryIfMissing True (takeDirectory path)
  ByteString.writeFile path (sourceModuleBytes entry)

findFilesNamed :: FilePath -> FilePath -> IO [FilePath]
findFilesNamed root name = findFilesMatching root ((== name) . takeFileName)

findFilesWithSuffix :: FilePath -> String -> IO [FilePath]
findFilesWithSuffix root suffix = findFilesMatching root (suffix `isSuffixOf`)

findFilesMatching :: FilePath -> (FilePath -> Bool) -> IO [FilePath]
findFilesMatching root predicate = do
  present <- doesDirectoryExist root
  if not present then pure [] else do
    entries <- listDirectory root
    fmap concat . forM entries $ \entry -> do
      let path = root </> entry
      directory <- doesDirectoryExist path
      if directory then findFilesMatching path predicate else pure [path | predicate path]

nonemptyLines :: Text -> [Text]
nonemptyLines = filter (not . Text.null) . map Text.strip . Text.lines

executableDigest :: FilePath -> IO Text
executableDigest path = do
  present <- doesFileExist path
  if present then sha256 <$> ByteString.readFile path else pure ""

failedReceipt :: Text -> FilePath -> [String] -> Receipt
failedReceipt name executable args = Receipt name executable args (ExitFailure 127) "" "prerequisite compiler row failed"

renderReceipt :: Receipt -> Text
renderReceipt (Receipt name executable args status out err) =
  Text.unlines ["name=" <> name, "executable=" <> Text.pack executable, "argv=" <> Text.pack (show args), "exit=" <> Text.pack (show status), "stdout:", out, "stderr:", err]

padOrdinal :: Int -> String
padOrdinal ordinal = replicate (6 - length rendered) '0' <> rendered
 where rendered = show ordinal

mutantSpecifications :: [(Text, String)]
mutantSpecifications =
  [ ("decoder-widening", "dsl-barrier-decoder-widening-mutant")
  , ("legality-drop", "dsl-barrier-legality-drop-mutant")
  , ("bind-arm-swap", "dsl-barrier-bind-arm-swap-mutant")
  , ("demand-omission", "dsl-barrier-demand-omission-mutant")
  , ("provision-identity-collapse", "dsl-barrier-provision-identity-collapse-mutant")
  , ("render-omission", "dsl-barrier-render-omission-mutant")
  , ("plan-reorder", "dsl-barrier-plan-reorder-mutant")
  , ("dry-run-execution", "dsl-barrier-dry-run-execution-mutant")
  , ("fake-call-bypass", "dsl-barrier-fake-call-bypass-mutant")
  , ("workflow-observation-skip", "self-referential-gates-drop-observe-mutant")
  , ("teardown-leak", "self-referential-gates-leak-resource-mutant")
  , ("skip-mutant", "self-referential-gates-skip-mutant-mutant")
  ]

matrixReceipts :: Matrix -> [Receipt]
matrixReceipts (Matrix spine mutants first second legal illegal qualification _) =
  spine <> [receipt | Mutant _ _ receipt <- mutants] <> [first, second, legal, illegal] <> qualification

matrixSelectorMatrix :: Matrix -> SelectorMatrix
matrixSelectorMatrix (Matrix _ _ _ _ _ _ _ selectors) = selectors

toolchainCheck :: FilePath -> FilePath -> FilePath -> Receipt -> Matrix -> CheckResult
toolchainCheck cabal compiler store version matrix = CheckResult "dsl-barrier-toolchain"
  [observation "dsl-barrier.cabal" (receiptSummary version), observation "dsl-barrier.compiler" (Text.pack compiler)]
  ([finding "DSL-BARRIER-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed" |
      not (isAbsolute cabal) || receiptExit version /= ExitSuccess || Text.strip (receiptStdout version) /= "3.16.1.0"] <>
   [finding "DSL-BARRIER-COMPILER" (Text.unpack name) "the row did not use the exact compiler/store, offline mode, and --jobs=1" |
      receipt@(Receipt name executable args _ _ _) <- matrixReceipts matrix,
      executable /= cabal || not (isAbsolute compiler) || not (isAbsolute store) ||
      ("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args ||
      "--jobs=1" `notElem` args || "--offline" `notElem` args || Text.null (receiptDigest receipt)])

oracleCheck :: Matrix -> CheckResult
oracleCheck (Matrix _ _ first second _ _ _ _) = CheckResult "dsl-barrier-independent-oracle"
  [observation "dsl-barrier.oracle.first" (receiptSummary first), observation "dsl-barrier.oracle.second" (receiptSummary second)]
  [finding "DSL-BARRIER-ORACLE" oracleSource "the independent nine-stage/twelve-negative oracle did not pass twice" |
    any (\receipt -> receiptExit receipt /= ExitSuccess || notContains oracleAcceptance (receiptOutput receipt)) [first, second]]

positiveCheck :: Matrix -> CheckResult
positiveCheck (Matrix spine _ first second _ _ _ _) = CheckResult "dsl-barrier-positive-controls"
  [observation "dsl-barrier.spine.count" (Text.pack (show (length spine)))]
  ([finding "DSL-BARRIER-SPINE" (Text.unpack (receiptName receipt)) "a real DSL-spine component did not pass" | receipt <- spine, receiptExit receipt /= ExitSuccess] <>
   [finding "DSL-BARRIER-SELF-REFERENCE" specSource "the clean external fake/self-referential control did not pass twice" |
      any ((/= ExitSuccess) . receiptExit) [first, second]])

negativeCheck :: Matrix -> CheckResult
negativeCheck (Matrix _ _ first _ legal illegal _ _) = CheckResult "dsl-barrier-paired-negatives"
  [observation "dsl-barrier.runtime-negatives" (receiptSummary first), observation "dsl-barrier.compile-positive" (receiptSummary legal), observation "dsl-barrier.compile-negative" (receiptSummary illegal)]
  ([finding "DSL-BARRIER-RUNTIME-NEGATIVES" specSource "the twelve exact paired negatives did not pass" |
      receiptExit first /= ExitSuccess || notContains oracleAcceptance (receiptOutput first)] <>
   [finding "DSL-BARRIER-COMPILE-POSITIVE" legalSource "the balanced workflow witness did not compile" | receiptExit legal /= ExitSuccess] <>
   [finding "DSL-BARRIER-COMPILE-NEGATIVE" illegalSource "the teardown-pending workflow witness compiled or failed elsewhere" |
      receiptExit illegal /= ExitFailure 1 || any (`notContains` receiptOutput illegal)
        ["Couldn't match type", "phase-gate-process", "Expected:", "Actual:"]])

mutantCheck :: Matrix -> CheckResult
mutantCheck (Matrix _ mutants _ _ _ _ _ _) = CheckResult "dsl-barrier-mutants"
  [observation ("dsl-barrier.mutant." <> name) (receiptSummary receipt) | Mutant name _ receipt <- mutants]
  [finding "DSL-BARRIER-MUTANT" (Text.unpack name) "the changed Phase-49 production subject did not turn its assigned row red" |
    Mutant name _ receipt <- mutants, receiptExit receipt /= ExitFailure 1 || notContains "self-referential-gates-mutant: RED" (receiptOutput receipt)]

sourceDisciplineCheck :: FilePath -> AcquiredSourceSnapshot -> IO CheckResult
sourceDisciplineCheck root acquired = do
  production <- Text.pack <$> readFile (root </> productionSource)
  oracle <- Text.pack <$> readFile (root </> oracleSource)
  let observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]
  pure (CheckResult "dsl-barrier-source-discipline"
    [observation "dsl-barrier.source-count" (Text.pack (show (length observed))), observation "dsl-barrier.stage-count" "9"]
    ([finding "DSL-BARRIER-DISCOVERY" "<phase-49-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources] <>
     [finding "DSL-BARRIER-SOURCE-SHAPE" productionSource ("missing production element: " <> token) |
       token <- ["data BarrierStage", "FakeBoundaryObservation", "validateDslBarrier", "DSL_BARRIER_FAKE_CALL_BYPASS_MUTANT"], notContains token production] <>
     [finding "DSL-BARRIER-ORACLE-INDEPENDENCE" oracleSource "independent oracle imports production" | "import Amoebius" `Text.isInfixOf` oracle]))

discoveryCheck :: CheckResult -> Matrix -> CheckResult
discoveryCheck discipline (Matrix spine mutants _ _ _ _ qualification selectors) = mergeChecks "dsl-barrier-discovery"
  [ discipline
  , CheckResult "dsl-barrier-runtime-inventory"
      [ observation "dsl-barrier.runtime.spine-count" (Text.pack (show (length spine)))
      , observation "dsl-barrier.runtime.mutant-count" (Text.pack (show (length mutants)))
      , observation "dsl-barrier.runtime.qualification-suite-count" (Text.pack (show (length qualification))) ]
      ([finding "DSL-BARRIER-STAGE-INVENTORY" "<dsl-spine>" "the exact five owning stage suites were not executed" | length spine /= 5] <>
       [finding "DSL-BARRIER-MUTANT-INVENTORY" "<dsl-barrier-mutants>" "the exact twelve Phase-49 mutants were not executed" | length mutants /= 12] <>
       [finding "DSL-BARRIER-QUALIFICATION-INVENTORY" "<validation-selector-suites>" "the exact sixteen cumulative selector suites were not executed" | length qualification /= 16])
  , selectorDiscoveryCheck selectors
  ]

selectorDiscoveryCheck :: SelectorMatrix -> CheckResult
selectorDiscoveryCheck matrix@(SelectorMatrix _ _ suites) = CheckResult "dsl-barrier-selector-discovery"
  ( [ observation "dsl-barrier.selector.suite-count" (Text.pack (show (length suites)))
    , observation "dsl-barrier.selector.count" (Text.pack (show (length allSelectors)))
    , observation "dsl-barrier.selector.inventory-sha256" (selectorMatrixDigest matrix)
    ]
    <> [observation ("dsl-barrier.selector.suite." <> name) (Text.pack (show (length attempts))) |
          SelectorSuiteRun name _ _ _ _ _ attempts <- suites]
  )
  ( [finding "DSL-BARRIER-SELECTOR-SUITE-INVENTORY" "<selector-suite-registry>"
       ("expected=" <> Text.pack (show expectedSelectorSuiteCounts) <> "; actual=" <> Text.pack (show actualCounts)) |
       map suiteNameAndCount suites /= expectedSelectorSuiteCounts]
    <> [finding "DSL-BARRIER-SELECTOR-CARDINALITY" "<selector-registry>" "the cumulative hardware-free selector inventory must contain exactly 4444 unique selectors" |
         length allSelectors /= 4444 || length (nub allSelectors) /= 4444]
    <> concatMap suiteProblems suites
  )
 where
  allSelectors = [selector | SelectorSuiteRun _ _ _ _ _ _ attempts <- suites, SelectorAttempt selector _ _ _ _ _ _ _ <- attempts]
  actualCounts = map suiteNameAndCount suites
  suiteNameAndCount (SelectorSuiteRun name _ _ _ _ _ attempts) = (name, length attempts)
  suiteProblems (SelectorSuiteRun name listReceipt assignmentsReceipt _ _ _ attempts) =
    [finding "DSL-BARRIER-SELECTOR-LIST" (Text.unpack name) "the clean suite did not expose a successful non-empty selector inventory" |
      receiptExit listReceipt /= ExitSuccess || null listed] <>
    [finding "DSL-BARRIER-SELECTOR-ASSIGNMENTS" (Text.unpack name) "selector names and independently authored assignment names differ, are duplicated, or contain a malformed row" |
      receiptExit assignmentsReceipt /= ExitSuccess || listed /= assigned || length assigned /= length (nub assigned) || any ((/= 3) . length . Text.splitOn "\t") assignmentLines] <>
    [finding "DSL-BARRIER-SELECTOR-EXECUTION-INVENTORY" (Text.unpack name) "the executed selector inventory differs from the reconciled clean inventory" |
      listed /= executed] <>
    [finding "DSL-BARRIER-SELECTOR-SOURCE-MAPPING" (Text.unpack name) ("selector=" <> selector <> "; source=" <> Text.pack path) |
      SelectorAttempt selector path _ _ _ _ _ _ <- attempts, not ("src/validation-kernel/" `isPrefixOf` path)]
   where
    listed = nonemptyLines (receiptStdout listReceipt)
    assignmentLines = nonemptyLines (receiptStdout assignmentsReceipt)
    assigned = [selector | line <- assignmentLines, selector : _ <- [Text.splitOn "\t" line]]
    executed = [selector | SelectorAttempt selector _ _ _ _ _ _ _ <- attempts]

expectedSelectorSuiteCounts :: [(Text, Int)]
expectedSelectorSuiteCounts =
  [ ("validation-phase-contract-component", 134)
  , ("validation-phase-contract-internal-component", 8)
  , ("validation-policy-contract-selector-component", 194)
  , ("validation-legacy-selector-component", 1317)
  , ("validation-source-closure-selector-component", 415)
  , ("validation-source-consumer-selector-component", 476)
  , ("validation-documentation-selector-component", 64)
  , ("validation-dispatch-selector-component", 26)
  , ("validation-compiler-buildinfo-selector-component", 614)
  , ("validation-compiler-elaborated-plan-selector-component", 342)
  , ("validation-compiler-source-graph-selector-component", 275)
  , ("validation-source-debt-selector-component", 162)
  , ("validation-phase-semantic-selector-component", 36)
  , ("validation-qualification-selector-component", 1)
  , ("validation-documentation-internal-selector-component", 88)
  , ("validation-source-consumer-internal-selector-component", 292)
  ]

selectorQualificationCheck :: SelectorMatrix -> CheckResult
selectorQualificationCheck matrix@(SelectorMatrix recacheReceipt registerReceipt suites) = CheckResult "dsl-barrier-selector-qualification"
  [ observation "dsl-barrier.selector.qualified-count" (Text.pack (show (length attempts)))
  , observation "dsl-barrier.selector.transcript-sha256" (selectorMatrixDigest matrix)
  ]
  ( [finding "DSL-BARRIER-SELECTOR-PACKAGE-DB" "<qualification-package-db>" "the run-local exposed-module package view was not prepared from the clean exact build" |
       any ((/= ExitSuccess) . receiptExit) [recacheReceipt, registerReceipt]]
    <> [finding "DSL-BARRIER-SELECTOR-CLEAN" (Text.unpack name) "the direct clean overlay did not compile and pass before isolated selector mutation" |
         SelectorSuiteRun name _ _ cleanCompile cleanRun cleanDigest _ <- suites,
         receiptExit cleanCompile /= ExitSuccess || receiptExit cleanRun /= ExitSuccess || Text.null cleanDigest]
    <> concatMap attemptProblems attempts
  )
 where
  attempts = [(name, cleanDigest, attempt) | SelectorSuiteRun name _ _ _ _ cleanDigest suiteAttempts <- suites, attempt <- suiteAttempts]
  attemptProblems (suite, cleanDigest, SelectorAttempt selector target before after changedBinary compileReceipt runReceipt restored) =
    [finding "DSL-BARRIER-SELECTOR-SOURCE-WITNESS" target ("selector=" <> selector <> "; the applied source change or restoration witness is invalid") |
      Text.null before || before == after || restored /= before] <>
    [finding "DSL-BARRIER-SELECTOR-COMPILE" target ("selector=" <> selector <> "; isolated changed production did not compile through the exact serial compiler") |
      receiptExit compileReceipt /= ExitSuccess || not (validSelectorCompilerReceipt compileReceipt)] <>
    [finding "DSL-BARRIER-SELECTOR-EXECUTABLE-WITNESS" target ("selector=" <> selector <> "; changed executable identity equals the clean executable or is absent") |
      Text.null changedBinary || changedBinary == cleanDigest] <>
    [finding "DSL-BARRIER-SELECTOR-LOCUS" (Text.unpack suite) ("selector=" <> selector <> "; assigned exact locus or unaffected control did not pass") |
      receiptExit runReceipt /= ExitSuccess || notContains ("selector-qualification: PASS: " <> selector) (receiptOutput runReceipt)]

validSelectorCompilerReceipt :: Receipt -> Bool
validSelectorCompilerReceipt (Receipt _ executable args _ _ _) =
  isAbsolute executable
    && "ghc-9.12.4" `isPrefixOf` takeFileName executable
    && "-fforce-recomp" `elem` args
    && "-hide-all-packages" `elem` args
    && not (any (\argument -> argument == "-j" || "-j" `isPrefixOf` argument) args)

selectorMatrixDigest :: SelectorMatrix -> Text
selectorMatrixDigest (SelectorMatrix recacheReceipt registerReceipt suites) = digestTexts
  ( [receiptDigest recacheReceipt, receiptDigest registerReceipt]
    <> concatMap suitePayload suites
  )
 where
  suitePayload (SelectorSuiteRun name listReceipt assignmentsReceipt cleanCompile cleanRun cleanDigest attempts) =
    [name, receiptDigest listReceipt, receiptDigest assignmentsReceipt, receiptDigest cleanCompile, receiptDigest cleanRun, cleanDigest]
      <> concatMap attemptPayload attempts
  attemptPayload (SelectorAttempt selector target before after changedBinary compileReceipt runReceipt restored) =
    [selector, Text.pack target, before, after, changedBinary, receiptDigest compileReceipt, receiptDigest runReceipt, restored]

qualificationCheck :: FilePath -> FilePath -> FilePath -> Matrix -> CheckResult
qualificationCheck root runRoot store (Matrix _ _ _ _ _ _ receipts selectors) = mergeChecks "dsl-barrier-universal-qualification"
  [ CheckResult "dsl-barrier-clean-selector-corpus"
      [observation "dsl-barrier.qualification.suite" (receiptSummary receipt) | receipt <- receipts]
      [finding "DSL-BARRIER-QUALIFICATION" (Text.unpack (receiptName receipt)) "a cumulative selector/oracle suite did not pass its complete clean corpus" |
        receipt <- receipts, receiptExit receipt /= ExitSuccess]
  , qualificationSabotageCheck receipts
  , selectorQualificationCheck selectors
  , selectorAuthorityCheck root runRoot store selectors
  ]

qualificationSabotageCheck :: [Receipt] -> CheckResult
qualificationSabotageCheck receipts = CheckResult "dsl-barrier-qualification-sabotage-corpus"
  [ observation "dsl-barrier.qualification.sabotage-count" (Text.pack (show (length observed)))
  , observation "dsl-barrier.qualification.sabotage-sha256" (digestTexts observed)
  ]
  [ finding "DSL-BARRIER-QUALIFICATION-SABOTAGE" "validation-qualification-selector-component"
      ("the exact independently authored seventeen-case sabotage observations differ: expected=" <> Text.pack (show expectedQualificationSabotages) <> "; observed=" <> Text.pack (show observed))
  | observed /= expectedQualificationSabotages
  ]
 where
  qualificationReceipts = [receipt | receipt <- receipts, "validation-qualification-selector-component" `Text.isInfixOf` receiptName receipt]
  observed = case qualificationReceipts of
    [receipt] | receiptExit receipt == ExitSuccess ->
      [line | line <- nonemptyLines (receiptStdout receipt), "qualification-sabotage-observation\t" `Text.isPrefixOf` line]
    _ -> []

expectedQualificationSabotages :: [Text]
expectedQualificationSabotages =
  [ "qualification-sabotage-observation\tconstant-success\tSABOTAGE-CONSTANT-SUCCESS"
  , "qualification-sabotage-observation\tno-op-subject\tSABOTAGE-NO-OP-SUBJECT"
  , "qualification-sabotage-observation\twrong-output\tSABOTAGE-WRONG-OUTPUT"
  , "qualification-sabotage-observation\tempty-discovery\tSABOTAGE-EMPTY-DISCOVERY"
  , "qualification-sabotage-observation\tmissing-subject\tSABOTAGE-MISSING-SUBJECT"
  , "qualification-sabotage-observation\tmissing-oracle\tSABOTAGE-MISSING-ORACLE"
  , "qualification-sabotage-observation\tskipped-or-no-op-mutant\tSABOTAGE-SKIPPED-MUTANT"
  , "qualification-sabotage-observation\twrong-locus\tSABOTAGE-WRONG-LOCUS"
  , "qualification-sabotage-observation\tstale-evidence\tSABOTAGE-STALE-EVIDENCE"
  , "qualification-sabotage-observation\tself-observer\tSABOTAGE-SELF-OBSERVER"
  , "qualification-sabotage-observation\tauthority-bypass\tSABOTAGE-AUTHORITY-BYPASS"
  , "qualification-sabotage-observation\tresidue-or-teardown-leakage\tSABOTAGE-RESIDUE"
  , "qualification-sabotage-observation\tgenerated-or-legacy-input-smuggling\tSABOTAGE-SMUGGLED-INPUT"
  , "qualification-sabotage-observation\tproduction-selector-omission\tSABOTAGE-PRODUCTION-SELECTOR-OMISSION"
  , "qualification-sabotage-observation\toracle-selector-omission\tSABOTAGE-ORACLE-SELECTOR-OMISSION"
  , "qualification-sabotage-observation\tbuild-selector-omission\tSABOTAGE-BUILD-SELECTOR-OMISSION"
  , "qualification-sabotage-observation\tchanged-subject-unassigned-row-red\tSABOTAGE-UNASSIGNED-ROW-RED"
  ]

selectorAuthorityCheck :: FilePath -> FilePath -> FilePath -> SelectorMatrix -> CheckResult
selectorAuthorityCheck root runRoot store matrix = CheckResult "dsl-barrier-selector-authority"
  [ observation "dsl-barrier.selector.authority-receipt-count" (Text.pack (show (length receipts)))
  , observation "dsl-barrier.selector.authority" "absolute compiler, package tool, and run-local Haskell subject paths only"
  ]
  [ finding "DSL-BARRIER-SELECTOR-AUTHORITY" (Text.unpack name) "a selector process escaped the exact compiler/package-tool/run-local subject authority"
  | Receipt name executable args _ _ _ <- receipts
  , not (isAbsolute executable)
      || not (admittedExecutable name executable)
      || any forbiddenArg args
  ]
 where
  receipts = selectorMatrixReceipts matrix
  admittedExecutable name executable
    | "selector-compile:" `Text.isPrefixOf` name = "ghc-9.12.4" `isPrefixOf` takeFileName executable
    | "selector-package-db-" `Text.isPrefixOf` name = "ghc-pkg-9.12.4" `isPrefixOf` takeFileName executable
    | otherwise = pathBelow runRoot executable
  forbiddenArg value =
    any (`isInfixOf` value) ["/pb", "docker", "podman", "kubectl", "kind", "ssh", "http://", "https://"]
      || value == "-j"
      || "-j" `isPrefixOf` value
      || (isAbsolute value && not (pathBelow root value) && not (pathBelow store value))

selectorMatrixReceipts :: SelectorMatrix -> [Receipt]
selectorMatrixReceipts (SelectorMatrix recacheReceipt registerReceipt suites) =
  [recacheReceipt, registerReceipt] <> concatMap suiteReceipts suites
 where
  suiteReceipts (SelectorSuiteRun _ listReceipt assignmentsReceipt cleanCompile cleanRun _ attempts) =
    [listReceipt, assignmentsReceipt, cleanCompile, cleanRun]
      <> concatMap attemptReceipts attempts
  attemptReceipts (SelectorAttempt _ _ _ _ _ compileReceipt runReceipt _) = [compileReceipt, runReceipt]

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler store receipts = CheckResult "dsl-barrier-authority"
  [observation "dsl-barrier.authority" "direct source-bound Haskell; serial offline compiler children; one run-local fake child; no pb/live/host/container/provider/hardware authority"]
  ([finding "DSL-BARRIER-RUN-ROOT" runRoot "run root escaped .build/runs/phase-49/work" | not (pathBelow (root </> ".build/runs/phase-49/work") runRoot)] <>
   [finding "DSL-BARRIER-AUTHORITY" (Text.unpack name) "a process executable or argv exceeded Phase-49 authority" |
     Receipt name executable args _ _ _ <- receipts, executable /= cabal ||
     (name /= "cabal-version" && (("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) || any forbiddenArg args])
 where
  forbiddenArg value = any (`isInfixOf` value) ["/pb", "docker", "podman", "kubectl", "kind", "ssh", "http://", "https://"]

observerCheck :: Matrix -> CheckResult
observerCheck matrix@(Matrix _ _ first second _ _ _ selectors) = CheckResult "dsl-barrier-observer"
  (map (observation "dsl-barrier.observer.process" . receiptSummary) (matrixReceipts matrix))
  ([finding "DSL-BARRIER-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest" |
      receipt@(Receipt name executable _ _ _ _) <- matrixReceipts matrix, not (isAbsolute executable) || Text.null (receiptDigest receipt)] <>
   [finding "DSL-BARRIER-EXTERNAL-FAKE" specSource "the separately executing fake child was not externally observed and torn down twice" |
      any (\receipt -> notContains selfAcceptance (receiptOutput receipt)) [first, second]] <>
   [finding "DSL-BARRIER-SELECTOR-OBSERVER" "<universal-selector-matrix>" "the selector compiler/process matrix lacks a complete digest-bound observation" |
      Text.null (selectorMatrixDigest selectors)])

freshnessCheck :: FilePath -> FilePath -> Matrix -> CheckResult
freshnessCheck root runRoot (Matrix _ _ first second _ _ _ _) = CheckResult "dsl-barrier-freshness"
  [observation "dsl-barrier.fresh-build-root" (Text.pack (makeRelative root runRoot)), observation "dsl-barrier.challenge-count" "2"]
  [finding "DSL-BARRIER-FRESHNESS" runRoot "two distinct post-start challenges did not pass in the unique run root" |
    not (pathBelow (root </> ".build/runs/phase-49/work") runRoot) || receiptExit first /= ExitSuccess || receiptExit second /= ExitSuccess || receiptDigest first == receiptDigest second]

legacyCheck :: AcquiredSourceSnapshot -> AcquiredPhaseContractEvidence -> Matrix -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult
legacyCheck acquired contract matrix toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom = CheckResult "dsl-barrier-legacy-closure"
  ( [ observation "dsl-barrier.legacy.owner-through" "49"
    , observation "dsl-barrier.legacy.validation-ids" "LTD-VAL-001..LTD-VAL-006"
    ]
    <> [ observation ("dsl-barrier.legacy." <> identifier)
           (if analyzerPassed checks && sabotage `elem` observedSabotages then "zero; reintroduction-observed" else "open")
       | (identifier, checks, sabotage) <- analyzers
       ]
  )
  ( [finding "DSL-BARRIER-LEGACY" path "a Phase-49 legacy Python/TSV gate or serialized behavioral input remains tracked" |
      entry <- snapshotEntries (acquiredSourceSnapshot acquired),
      let path = indexPath (trackedIndex entry),
      path `elem` ["tools/self_referential_gates_gate.py", "test/fixture/self_referential_gates/stage_matrix.tsv"]]
    <> [finding "DSL-BARRIER-LEGACY-ANALYZER" (Text.unpack identifier) ("the compiled analyzer remains open: " <> Text.intercalate "," [checkName check | check <- checks, not (null (checkFindings check))]) |
         (identifier, checks, _) <- analyzers, not (analyzerPassed checks)]
    <> [finding "DSL-BARRIER-LEGACY-REINTRODUCTION" (Text.unpack identifier) ("the independent reintroduction observation is absent: " <> sabotage) |
         (identifier, _, sabotage) <- analyzers, sabotage `notElem` observedSabotages]
    <> [finding "DSL-BARRIER-LEGACY-QUALIFICATION" "<phase-49-validation-owners>" "validation-owner closure requires every acquired Phase-49 matrix receipt" |
         any (\receipt -> receiptExit receipt `notElem` [ExitSuccess, ExitFailure 1]) (matrixReceipts matrix)]
  )
 where
  contractCheck = acquiredPhaseContractEvidenceCheck contract
  qualificationSabotages = qualificationSabotageCheck [receipt | receipt <- matrixReceipts matrix, "qualification-" `Text.isPrefixOf` receiptName receipt]
  observedSabotages = [line | line <- expectedQualificationSabotages, null (checkFindings qualificationSabotages)]
  analyzerPassed = all (null . checkFindings)
  allNonCircular = [toolchain, oracle, positives, negatives, mutants, discovery, authority, observer, freshness, qualification, cleanroom]
  analyzers =
    [ ("LTD-VAL-001", [qualification], expectedQualificationSabotages !! 12)
    , ("LTD-VAL-002", [contractCheck, discovery], expectedQualificationSabotages !! 5)
    , ("LTD-VAL-003", [freshness, observer], expectedQualificationSabotages !! 8)
    , ("LTD-VAL-004", allNonCircular, expectedQualificationSabotages !! 0)
    , ("LTD-VAL-005", [oracle, positives, negatives, mutants, authority], expectedQualificationSabotages !! 10)
    , ("LTD-VAL-006", [freshness, cleanroom], expectedQualificationSabotages !! 12)
    ]

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy =
  [ named "phase-49-claim" [pre], named "phase-49-subject" [toolchain, positives]
  , named "phase-49-command" [toolchain, authority], named "phase-49-oracle" [oracle]
  , named "phase-49-positive-controls" [positives], named "phase-49-paired-negatives" [negatives]
  , named "phase-49-mutants" [mutants, qualification], named "phase-49-discovery" [discovery]
  , named "phase-49-challenge" [freshness], named "phase-49-observer" [observer]
  , named "phase-49-authority-bypass" [authority], named "phase-49-freshness" [freshness]
  , named "phase-49-qualification" [qualification], named "phase-49-cleanroom" [cleanroom]
  , named "phase-49-legacy-closure" [legacy]
  , CheckResult "phase-49-predecessor" [observation "phase-49.predecessor" "deferred to durable receipt verifier"] []
  , CheckResult "phase-49-residue" [observation "phase-49.residue" "pb handoff, host, tool/provider fidelity, images, registries, clusters, accelerators, security authorities, and live hardware remain Phase-50+-owned"] []
  , named "phase-49-pass-criterion" [pre] ]
 where named = mergeChecks

prepareSourceRepositoryCache :: FilePath -> FilePath -> IO CheckResult
prepareSourceRepositoryCache root runRoot = do
  let source = root </> ".build/dist-newstyle/phase-00-baseline/src"; target = runRoot </> "dist/src"
  present <- doesDirectoryExist source
  if present then copyTree source target else pure ()
  copied <- if present then sort <$> listDirectory target else pure []
  pure (CheckResult "dsl-barrier-source-repository-cache" [observation "dsl-barrier.cache.entries" (Text.pack (show copied))]
    [finding "DSL-BARRIER-CACHE" (makeRelative root source) "authenticated network-independent source-repository cache is absent or incomplete" |
      not present || length copied /= 6 || not (all (completeSourcePackage copied) ["infernix-", "jitML-"])])

copyTree :: FilePath -> FilePath -> IO ()
copyTree source target = do
  createDirectoryIfMissing True target
  entries <- listDirectory source
  forM_ entries $ \entry -> do
    let from = source </> entry; to = target </> entry
    directory <- doesDirectoryExist from
    if directory then copyTree from to else copyFile from to

completeSourcePackage :: [FilePath] -> String -> Bool
completeSourcePackage entries prefix = length matching == 3 && length (filter (isInfixOf ".cache") matching) == 1 && length (filter (isInfixOf ".tar.gz") matching) == 1 && length [entry | entry <- matching, not ('.' `elem` entry)] == 1
 where matching = filter (prefix `isPrefixOf`) entries

freshRunRoot :: FilePath -> IO FilePath
freshRunRoot root = do
  let parent = root </> ".build/runs/phase-49/work"
  createDirectoryIfMissing True parent
  (leaf, handle) <- openBinaryTempFile parent "candidate-"
  hClose handle
  removeFile leaf
  createDirectory leaf
  pure leaf

runProcess :: FilePath -> Text -> FilePath -> [String] -> IO Receipt
runProcess working = runProcessWithEnvironment working []

runProcessWithEnvironment :: FilePath -> [(String, String)] -> Text -> FilePath -> [String] -> IO Receipt
runProcessWithEnvironment working additions name executable args = do
  inherited <- getEnvironment
  let environment = additions <> filter (\(key, _) -> not (forbiddenEnvironment key) && key `notElem` map fst additions) inherited
  attempt <- try (readCreateProcessWithExitCode ((proc executable args){cwd = Just working, env = Just environment}) "") :: IO (Either IOException (ExitCode, String, String))
  pure $ either (\problem -> Receipt name executable args (ExitFailure 127) "" (Text.pack (show problem))) (\(status, out, err) -> Receipt name executable args status (Text.pack out) (Text.pack err)) attempt

forbiddenEnvironment :: String -> Bool
forbiddenEnvironment name = name `elem` ["KUBECONFIG", "VAULT_ADDR", "VAULT_TOKEN", "GOOGLE_APPLICATION_CREDENTIALS"] || any (`isPrefixOf` name) ["AWS_", "AZURE_", "VAULT_", "KUBE_"]

receiptName :: Receipt -> Text
receiptName (Receipt name _ _ _ _ _) = name
receiptExit :: Receipt -> ExitCode
receiptExit (Receipt _ _ _ status _ _) = status
receiptStdout :: Receipt -> Text
receiptStdout (Receipt _ _ _ _ out _) = out
receiptOutput :: Receipt -> Text
receiptOutput (Receipt _ _ _ _ out err) = out <> "\n" <> err
receiptDigest :: Receipt -> Text
receiptDigest (Receipt name executable args status out err) = digestTexts [name, Text.pack executable, Text.pack (show args), Text.pack (show status), out, err]
receiptSummary :: Receipt -> Text
receiptSummary receipt@(Receipt name executable args status _ err) = name <> "|" <> Text.pack executable <> "|argv=" <> Text.pack (show args) <> "|exit=" <> Text.pack (show status) <> "|sha256=" <> receiptDigest receipt <> if status == ExitSuccess || status == ExitFailure 1 then "" else "|stderr=" <> Text.replace "\n" "\\n" (Text.take 512 err)
checkDigest :: CheckResult -> Text
checkDigest result = digestTexts [checkName result, Text.pack (show (checkObservations result)), Text.pack (show (checkFindings result))]
digestTexts :: [Text] -> Text
digestTexts = sha256 . TextEncoding.encodeUtf8 . Text.intercalate "\NUL"
sha256 :: ByteString -> Text
sha256 = Text.pack . concatMap (\byte -> [intToDigit (fromIntegral byte `div` 16), intToDigit (fromIntegral byte `mod` 16)]) . ByteString.unpack . SHA256.hash
pathBelow :: FilePath -> FilePath -> Bool
pathBelow parent child = let relative = normalise (makeRelative parent child) in relative /= ".." && not ("../" `isPrefixOf` relative) && not (isAbsolute relative)
notContains :: Text -> Text -> Bool
notContains needle haystack = not (needle `Text.isInfixOf` haystack)

oracleAcceptance, selfAcceptance :: Text
oracleAcceptance = "dsl-barrier-oracle: PASS (9 stages, 12 paired negatives, 12 changed-production mutants)"
selfAcceptance = "self-referential-gates-spec: PASS (9 stages, 5 workflow arms, external fake observation, teardown balanced)"

productionSource, oracleSource, specSource, legalSource, illegalSource :: FilePath
productionSource = "src/dsl-barrier/Amoebius/Validation/DslBarrier.hs"
oracleSource = "test/spec/workflow/DslBarrierOracle.hs"
specSource = "test/spec/workflow/SelfReferentialGatesSpec.hs"
legalSource = "test/negative/self_referential_gates/legal_gate.hs"
illegalSource = "test/negative/self_referential_gates/leaked_gate.hs"

expectedSources :: [FilePath]
expectedSources = sort [productionSource, "src/self-referential-gates/Amoebius/Gate/SelfReferential.hs", oracleSource, specSource, legalSource, illegalSource]
