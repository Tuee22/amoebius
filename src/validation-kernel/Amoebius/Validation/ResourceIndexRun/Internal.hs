{-# LANGUAGE OverloadedStrings #-}

-- | Package-hidden, hardware-free Phase-9 authority. Every compiler child is
-- synchronous; the runner uses neither @pb@ nor network/hardware effects.
module Amoebius.Validation.ResourceIndexRun.Internal
  ( AcquiredResourceIndexRun
  , acquireResourceIndexRun
  , acquireResourceIndexRefreshRun
  , acquiredResourceIndexRunCheck
  , foldAcquiredResourceIndexRun
  ) where

import Amoebius.Validation.BootstrapTrust.Internal
  ( GenesisTrust, genesisTrustCheck, genesisTrustCompilerExecutable, genesisTrustToolchainIdentity )
import Amoebius.Validation.PhaseContract.Internal
  ( AcquiredPhaseContractEvidence, acquirePhaseContractEvidenceFor
  , acquireRecordedPhaseContractEvidence, acquiredPhaseContractEvidenceCheck )
import Amoebius.Validation.SourceClosure.Internal
  ( AcquiredSourceSnapshot, IndexEntry (indexPath), SourceSnapshot (snapshotEntries, snapshotIdentity)
  , TrackedEntry (trackedIndex), acquiredSourceSnapshot )
import Amoebius.Validation.Types (CheckResult (..), finding, mergeChecks, observation)
import Control.Exception (IOException, try)
import Control.Monad (filterM)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Char (intToDigit)
import Data.List (isInfixOf, isPrefixOf, isSuffixOf, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import System.Directory
  ( createDirectory, createDirectoryIfMissing, doesDirectoryExist, getHomeDirectory
  , listDirectory, removeFile )
import System.Exit (ExitCode (..))
import System.FilePath (isAbsolute, makeRelative, normalise, (</>))
import System.IO (hClose, openBinaryTempFile)
import System.Process (CreateProcess (cwd), proc, readCreateProcessWithExitCode)

data Receipt = Receipt Text FilePath [String] ExitCode Text Text deriving (Eq, Show)
data Pair = Pair Text Receipt Receipt deriving (Eq, Show)
data Mutant = Mutant Text Text Receipt Receipt deriving (Eq, Show)
data Matrix = Matrix
  { cleanBuild :: Receipt
  , cleanRun :: Receipt
  , mutantRows :: [Mutant]
  , compilePairs :: [Pair]
  }

data AcquiredResourceIndexRun = AcquiredResourceIndexRun
  AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
  Text Text Text Text Text Text Text Text CheckResult

acquiredResourceIndexRunCheck :: AcquiredResourceIndexRun -> CheckResult
acquiredResourceIndexRunCheck (AcquiredResourceIndexRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredResourceIndexRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredResourceIndexRun -> value
foldAcquiredResourceIndexRun consume (AcquiredResourceIndexRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireResourceIndexRun, acquireResourceIndexRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredResourceIndexRun
acquireResourceIndexRun = acquire False
acquireResourceIndexRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredResourceIndexRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  databases <- discoverPackageDatabases
  let databaseCheck = CheckResult "resource-index-package-database"
        [observation "resource-index.package-db" (Text.pack path) | path <- databases]
        [finding "RESOURCE-INDEX-PACKAGE-DB" "<cabal-store>" "exactly one GHC-9.12.4 package database is required" | length databases /= 1]
  matrix <- case databases of
    [database] -> executeMatrix root runRoot database (genesisTrustCompilerExecutable trust)
    _ -> pure unavailableMatrix
  discipline <- sourceDisciplineCheck root
  let receipts = matrixReceipts matrix
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 9 acquired
      compiler = compilerCheck matrix
      oracle = oracleCheck (cleanRun matrix)
      positive = positiveCheck matrix
      negatives = negativeCheck matrix
      mutants = mutantCheck matrix
      discovery = discoveryCheck acquired
      authority = authorityCheck root runRoot (genesisTrustCompilerExecutable trust) receipts discipline
      observer = observerCheck receipts
      freshness = CheckResult "resource-index-freshness" [observation "resource-index.fresh-build-root" (Text.pack (makeRelative root runRoot))] []
      cleanroom = CheckResult "resource-index-cleanroom" [observation "resource-index.run-root" (Text.pack (makeRelative root runRoot))]
        [finding "RESOURCE-INDEX-CLEANROOM" runRoot "generated products escaped the phase run root" | not (pathBelow (root </> ".build/runs/phase-09/work") runRoot)]
      qualification = mergeChecks "resource-index-qualification" [compiler, oracle, positive, negatives, mutants, discipline]
      prerequisite = mergeChecks "resource-index-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, databaseCheck, compiler, oracle, positive, negatives, mutants, discovery, authority, observer, freshness, cleanroom, discipline]
      rows = phaseRows prerequisite compiler oracle positive negatives mutants discovery authority observer freshness qualification cleanroom
      result = mergeChecks "resource-index" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "resource-index-subject" [checkDigest compiler, checkDigest discipline]
      oracleId = ids "resource-index-oracle" [receiptDigest (cleanRun matrix)]
      harnessId = ids "resource-index-harness" (map receiptDigest receipts)
      observerId = ids "resource-index-observer" [checkDigest observer]
      qualificationId = ids "resource-index-qualification" [checkDigest qualification]
      acquiredRunId = ids "resource-index-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "resource-index-toolchain" [genesisTrustToolchainIdentity trust]
      cleanup = "generated-products-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0"
  pure (AcquiredResourceIndexRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

executeMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> IO Matrix
executeMatrix root runRoot database compiler = do
  cb <- compileProgram root runRoot database compiler "clean" Nothing
  cr <- runBuilt root runRoot "clean" "clean-oracle" cb
  mutants <- mapM (runMutant root runRoot database compiler) mutantSpecifications
  pairs <- mapM (compilePair root runRoot database compiler) pairSpecifications
  pure (Matrix cb cr mutants pairs)

runMutant :: FilePath -> FilePath -> FilePath -> FilePath -> (Text, String) -> IO Mutant
runMutant root runRoot database compiler (name, selector) = do
  let variant = "mutant-" <> Text.unpack name
  build <- compileProgram root runRoot database compiler variant (Just selector)
  run <- runBuilt root runRoot variant (name <> "-oracle") build
  pure (Mutant name (Text.pack selector) build run)

compileProgram :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> Maybe String -> IO Receipt
compileProgram root runRoot database compiler variant selector = do
  let objects = runRoot </> variant </> "objects"
      binary = runRoot </> variant </> "resource-index-oracle"
  createDirectoryIfMissing True objects
  runProcess root (Text.pack variant <> "-compiler") compiler
    (common database objects selector <> ["-package", "QuickCheck", "-o", binary, oracleSource])

compilePair :: FilePath -> FilePath -> FilePath -> FilePath -> PairSpecification -> IO Pair
compilePair root runRoot database compiler (PairSpecification name legal illegal _ _) = do
  legalReceipt <- compileFixture root runRoot database compiler (name <> "-legal") legal
  illegalReceipt <- compileFixture root runRoot database compiler (name <> "-illegal") illegal
  pure (Pair name legalReceipt illegalReceipt)

compileFixture :: FilePath -> FilePath -> FilePath -> FilePath -> Text -> FilePath -> IO Receipt
compileFixture root runRoot database compiler name source = do
  let objects = runRoot </> Text.unpack name </> "objects"
  createDirectoryIfMissing True objects
  runProcess root (name <> "-compiler") compiler (common database objects Nothing <> ["-fno-code", source])

common :: FilePath -> FilePath -> Maybe String -> [String]
common database objects selector =
  ["-XGHC2024", "-O0", "-fforce-recomp", "-Wincomplete-patterns", "-Werror=incomplete-patterns"
  , "-clear-package-db", "-global-package-db", "-package-db", database
  , "-isrc/capacity-topology", "-itest/spec/dsl", "-package", "text", "-package", "containers", "-package", "deepseq"
  , "-odir", objects, "-hidir", objects, "-stubdir", objects]
  <> maybe [] (pure . ("-D" <>)) selector

runBuilt :: FilePath -> FilePath -> FilePath -> Text -> Receipt -> IO Receipt
runBuilt root runRoot variant name build
  | receiptExit build == ExitSuccess = runProcess root name (runRoot </> variant </> "resource-index-oracle") []
  | otherwise = pure (unavailable name)

data PairSpecification = PairSpecification Text FilePath FilePath Text Text

pairSpecifications :: [PairSpecification]
pairSpecifications =
  [ pair "bare-apple-host" "bare_apple" "Couldn't match type" "Apple"
  , pair "bare-windows-host" "bare_windows" "Couldn't match type" "Windows"
  , pair "even-server-quorum" "quorum" "Couldn't match expected type" "OddQuorumToken"
  , pair "single-topology-place" "single_topology" "Couldn't match type" "Topology"
  , pair "control-plane-reach" "control_plane_reach" "Couldn't match expected type" "ReachToken"
  , pair "host-worker-reach" "host_worker_reach" "Couldn't match type" "HostWorker"
  , pair "site-indexed-quorum" "site_quorum" "Couldn't match type" "SiteB"
  ]
 where
  pair name stem reason locus = PairSpecification name (base stem <> "_legal.hs") (base stem <> "_illegal.hs") reason locus
  base stem = "test/spec/dsl/capacity_topology_compile_fail/" <> stem

mutantSpecifications :: [(Text, String)]
mutantSpecifications =
  [ ("fits-drop-memory", "CAPACITY_FITS_DROP_MEMORY_MUTANT")
  , ("carve-skip-subtraction", "CAPACITY_CARVE_SKIP_SUBTRACTION_MUTANT")
  , ("fixed-place-admit-overcommit", "CAPACITY_FIXED_ADMIT_OVERCOMMIT_MUTANT")
  , ("elastic-place-unconditional-right", "CAPACITY_ELASTIC_UNCONDITIONAL_RIGHT_MUTANT")
  , ("compatibility-admit-all", "CAPACITY_COMPATIBILITY_ADMIT_ALL_MUTANT")
  , ("rke2-allow-duplicate-host", "CAPACITY_RKE2_DUPLICATE_HOST_MUTANT")
  , ("pod-drop-ephemeral", "CAPACITY_POD_DROP_EPHEMERAL_MUTANT")
  , ("cpu-policy-ignore", "CAPACITY_CPU_POLICY_IGNORE_MUTANT")
  , ("elastic-ignore-class-max", "CAPACITY_ELASTIC_IGNORE_CLASS_MAX_MUTANT")
  , ("elastic-drop-per-node", "CAPACITY_ELASTIC_DROP_PER_NODE_MUTANT")
  , ("taint-ignore", "CAPACITY_TAINT_IGNORE_MUTANT")
  , ("memory-backed-drop", "CAPACITY_MEMORY_BACKED_DROP_MUTANT")
  , ("tmpfs-persistence-drop", "CAPACITY_TMPFS_PERSISTENCE_DROP_MUTANT")
  , ("headroom-pad-drop", "CAPACITY_HEADROOM_PAD_DROP_MUTANT")
  , ("validator-drop-cpu", "CAPACITY_VALIDATOR_DROP_CPU_MUTANT")
  , ("validator-drop-memory", "CAPACITY_VALIDATOR_DROP_MEMORY_MUTANT")
  , ("validator-drop-ephemeral", "CAPACITY_VALIDATOR_DROP_EPHEMERAL_MUTANT")
  , ("validator-drop-slots", "CAPACITY_VALIDATOR_DROP_SLOTS_MUTANT")
  , ("validator-drop-csi-dedup", "CAPACITY_VALIDATOR_DROP_CSI_MUTANT")
  ]

compilerCheck :: Matrix -> CheckResult
compilerCheck matrix = CheckResult "resource-index-compiler" (map (observation "resource-index.compiler" . receiptSummary) required)
  [finding "RESOURCE-INDEX-COMPILER" (Text.unpack name) "a clean, mutant, or legal control did not compile" | Receipt name _ _ status _ _ <- required, status /= ExitSuccess]
 where required = cleanBuild matrix : [build | Mutant _ _ build _ <- mutantRows matrix] <> [legal | Pair _ legal _ <- compilePairs matrix]

oracleCheck :: Receipt -> CheckResult
oracleCheck receipt = CheckResult "resource-index-independent-oracle" [observation "resource-index.oracle" (receiptSummary receipt)]
  [finding "RESOURCE-INDEX-ORACLE" oracleSource "the authored Haskell oracle did not report its exact clean inventory" | receiptExit receipt /= ExitSuccess || not (passLine `Text.isInfixOf` receiptStdout receipt)]
 where passLine = "PASS (15 fold negatives, 15 twins, 2 positives, 9 compatibility pairs, 8 current/3 deferred loci, 4 properties)"

positiveCheck :: Matrix -> CheckResult
positiveCheck matrix = CheckResult "resource-index-positive-controls" [observation "resource-index.positive" "clean-oracle,seven-legal-compile-controls"]
  [finding "RESOURCE-INDEX-POSITIVE" "<clean-controls>" "the clean oracle or a legal compile twin failed" | receiptExit (cleanRun matrix) /= ExitSuccess || any ((/= ExitSuccess) . receiptExit) [legal | Pair _ legal _ <- compilePairs matrix]]

negativeCheck :: Matrix -> CheckResult
negativeCheck matrix = CheckResult "resource-index-paired-negatives"
  [observation ("resource-index.negative." <> name) (receiptSummary illegal) | Pair name _ illegal <- compilePairs matrix]
  [finding "RESOURCE-INDEX-NEGATIVE" (Text.unpack name) "an illegal twin did not fail at its pinned reason and locus" | (PairSpecification expectedName _ _ reason locus, Pair name _ illegal) <- zip pairSpecifications (compilePairs matrix), name /= expectedName || not (failedWith illegal reason && failedWith illegal locus)]

mutantCheck :: Matrix -> CheckResult
mutantCheck matrix = CheckResult "resource-index-mutants"
  [observation ("resource-index.mutant." <> name) (selector <> "|" <> receiptSummary run) | Mutant name selector _ run <- mutantRows matrix]
  [finding "RESOURCE-INDEX-MUTANT" (Text.unpack name) "the changed production subject did not compile and turn red under the clean oracle" | Mutant name _ build run <- mutantRows matrix, receiptExit build /= ExitSuccess || receiptExit run == ExitSuccess]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
  sources <- mapM (readFile . (root </>)) productionSources
  let combined = Text.pack (concat sources)
      forbidden = ["System.IO", "Network.Socket", "unsafePerformIO", "undefined"]
      required = ["ResourceVector", "fits", "carve", "place", "KindEngine", "Rke2Engine", "ManagedEksEngine"]
  pure (CheckResult "resource-index-source-discipline"
    [observation "resource-index.effect-boundary" "pure-only", observation "resource-index.closed-model-elements" (Text.pack (show (length required)))]
    ([finding "RESOURCE-INDEX-SOURCE-DISCIPLINE" "src/capacity-topology/" ("forbidden token: " <> token) | token <- forbidden, token `Text.isInfixOf` combined]
      <> [finding "RESOURCE-INDEX-MODEL-SHAPE" "src/capacity-topology/" ("missing model element: " <> token) | token <- required, not (token `Text.isInfixOf` combined)]))

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired = CheckResult "resource-index-discovery" [observation "resource-index.discovery.count" (Text.pack (show (length observed)))]
  [finding "RESOURCE-INDEX-DISCOVERY" "<resource-index-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
 where
  observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), inScope path]
  inScope path = ".hs" `isSuffixOf` path && any (`isPrefixOf` path) sourcePrefixes

authorityCheck :: FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult -> CheckResult
authorityCheck root runRoot compiler receipts discipline = CheckResult "resource-index-authority"
  [observation "resource-index.compiler-serialization" "one synchronous GHC child at a time; no -j; no pb; pure source boundary"]
  ([finding "RESOURCE-INDEX-RUN-ROOT" runRoot "run root escaped .build/runs/phase-09/work" | not (pathBelow (root </> ".build/runs/phase-09/work") runRoot)]
    <> [finding "RESOURCE-INDEX-AUTHORITY" (Text.unpack name) "compiler executable or argv violated direct serial authority" | Receipt name executable args _ _ _ <- receipts, "-compiler" `Text.isSuffixOf` name, executable /= compiler || any (isInfixOf "-j") args || any (isInfixOf "pb") args]
    <> checkFindings discipline)

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts = CheckResult "resource-index-observer" (map (observation "resource-index.observer.process" . receiptSummary) receipts)
  [finding "RESOURCE-INDEX-OBSERVER" (Text.unpack name) "a process receipt lacks an absolute executable or digest" | receipt@(Receipt name executable _ _ _ _) <- receipts, executable /= "<unavailable>" && (not (isAbsolute executable) || Text.null (receiptDigest receipt))]

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre compiler oracle positive negatives mutants discovery authority observer freshness qualification cleanroom =
  [named "phase-09-claim" [pre], named "phase-09-subject" [compiler, positive], named "phase-09-command" [compiler, authority]
  ,named "phase-09-oracle" [oracle], named "phase-09-positive-controls" [positive], named "phase-09-paired-negatives" [negatives]
  ,named "phase-09-mutants" [mutants], named "phase-09-discovery" [discovery], named "phase-09-challenge" [mutants]
  ,named "phase-09-observer" [observer], named "phase-09-authority-bypass" [authority], named "phase-09-freshness" [freshness]
  ,named "phase-09-qualification" [qualification], named "phase-09-cleanroom" [cleanroom], named "phase-09-legacy-closure" [pre]
  ,CheckResult "phase-09-predecessor" [observation "phase-09.predecessor" "deferred to durable receipt verifier"] []
  ,CheckResult "phase-09-residue" [observation "phase-09.residue" "composition, decode, binding, rendering, effects, runtimes, hardware, and cleanup remain later-owned"] []
  ,named "phase-09-pass-criterion" [pre]]
 where named = mergeChecks

failedWith :: Receipt -> Text -> Bool
failedWith receipt needle = receiptExit receipt == ExitFailure 1 && needle `Text.isInfixOf` receiptStderr receipt

discoverPackageDatabases :: IO [FilePath]
discoverPackageDatabases = do
  home <- getHomeDirectory
  let store = home </> ".cabal/store"
  present <- doesDirectoryExist store
  if not present then pure [] else do
    names <- listDirectory store
    filterM doesDirectoryExist [store </> name </> "package.db" | name <- names, "ghc-9.12.4-" `isInfixOf` name]

freshRunRoot :: FilePath -> IO FilePath
freshRunRoot root = do
  let parent = root </> ".build/runs/phase-09/work"
  createDirectoryIfMissing True parent
  (leaf, handle) <- openBinaryTempFile parent "candidate-"
  hClose handle
  removeFile leaf
  createDirectory leaf
  pure leaf

runProcess :: FilePath -> Text -> FilePath -> [String] -> IO Receipt
runProcess working name executable args = do
  attempt <- try (readCreateProcessWithExitCode ((proc executable args) {cwd = Just working}) "") :: IO (Either IOException (ExitCode, String, String))
  pure $ either (\problem -> Receipt name executable args (ExitFailure 127) "" (Text.pack (show problem))) (\(status, out, err) -> Receipt name executable args status (Text.pack out) (Text.pack err)) attempt

receiptExit :: Receipt -> ExitCode
receiptExit (Receipt _ _ _ status _ _) = status
receiptStdout, receiptStderr :: Receipt -> Text
receiptStdout (Receipt _ _ _ _ out _) = out
receiptStderr (Receipt _ _ _ _ _ err) = err
receiptDigest :: Receipt -> Text
receiptDigest (Receipt name executable args status out err) = digestTexts [name, Text.pack executable, Text.pack (show args), Text.pack (show status), out, err]
receiptSummary :: Receipt -> Text
receiptSummary receipt@(Receipt name executable args status _ err) = name <> "|" <> Text.pack executable <> "|argv=" <> Text.pack (show args) <> "|exit=" <> Text.pack (show status) <> "|sha256=" <> receiptDigest receipt <> failure
 where failure = if status == ExitSuccess then "" else "|stderr=" <> Text.replace "\n" "\\n" (Text.take 512 err)
checkDigest :: CheckResult -> Text
checkDigest result = digestTexts [checkName result, Text.pack (show (checkObservations result)), Text.pack (show (checkFindings result))]
digestTexts :: [Text] -> Text
digestTexts = sha256 . TextEncoding.encodeUtf8 . Text.intercalate "\NUL"
sha256 :: ByteString -> Text
sha256 = Text.pack . concatMap hex . ByteString.unpack . SHA256.hash where hex byte = [intToDigit (fromIntegral byte `div` 16), intToDigit (fromIntegral byte `mod` 16)]
pathBelow :: FilePath -> FilePath -> Bool
pathBelow parent child = let relative = normalise (makeRelative parent child) in relative /= ".." && not ("../" `isPrefixOf` relative) && not (isAbsolute relative)
unavailable :: Text -> Receipt
unavailable name = Receipt name "<unavailable>" [] (ExitFailure 127) "" "package database or compiler construction unavailable"
unavailableMatrix :: Matrix
unavailableMatrix = Matrix (u "clean-compiler") (u "clean-oracle") [Mutant name (Text.pack selector) (u (name <> "-compiler")) (u (name <> "-oracle")) | (name, selector) <- mutantSpecifications] [Pair name (u (name <> "-legal-compiler")) (u (name <> "-illegal-compiler")) | PairSpecification name _ _ _ _ <- pairSpecifications] where u = unavailable
matrixReceipts :: Matrix -> [Receipt]
matrixReceipts matrix = [cleanBuild matrix, cleanRun matrix] <> concat [[build, run] | Mutant _ _ build run <- mutantRows matrix] <> concat [[legal, illegal] | Pair _ legal illegal <- compilePairs matrix]

productionSources :: [FilePath]
productionSources =
  [ "src/capacity-topology/Amoebius/Capacity/Types.hs"
  , "src/capacity-topology/Amoebius/Capacity/Fold.hs"
  , "src/capacity-topology/Amoebius/Dsl/Topology.hs"
  ]
sourcePrefixes :: [FilePath]
sourcePrefixes = ["src/capacity-topology/", "test/spec/dsl/CapacityTopology", "test/spec/dsl/capacity_topology_compile_fail/"]
expectedSources :: [FilePath]
expectedSources = sort (productionSources <> [oracleSource, "test/spec/dsl/CapacityTopologyGate.hs", "test/spec/dsl/CapacityTopologyFixtures.hs", "test/spec/dsl/CapacityTopologyProps.hs"] <> concat [[legal, illegal] | PairSpecification _ legal illegal _ _ <- pairSpecifications])
oracleSource :: FilePath
oracleSource = "test/spec/dsl/CapacityTopologySpec.hs"
