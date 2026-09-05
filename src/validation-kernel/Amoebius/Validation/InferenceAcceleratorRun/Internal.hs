{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.InferenceAcceleratorRun.Internal
  ( AcquiredInferenceAcceleratorRun
  , acquireInferenceAcceleratorRefreshRun
  , acquireInferenceAcceleratorRun
  , acquiredInferenceAcceleratorRunCheck
  , foldAcquiredInferenceAcceleratorRun
  ) where

import Amoebius.Validation.BootstrapTrust.Internal
  ( GenesisTrust
  , genesisTrustCheck
  , genesisTrustCompilerExecutable
  , genesisTrustToolchainIdentity
  )
import Amoebius.Validation.PhaseContract.Internal
  ( AcquiredPhaseContractEvidence
  , acquirePhaseContractEvidenceFor
  , acquireRecordedPhaseContractEvidence
  , acquiredPhaseContractEvidenceCheck
  )
import Amoebius.Validation.SourceClosure.Internal
  ( AcquiredSourceSnapshot
  , IndexEntry (indexPath)
  , SourceSnapshot (snapshotEntries, snapshotIdentity)
  , TrackedEntry (trackedIndex)
  , acquiredSourceSnapshot
  )
import Amoebius.Validation.Types (CheckResult (..), finding, mergeChecks, observation)
import Control.Exception (IOException, try)
import Control.Monad (filterM, forM_)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Char (intToDigit)
import Data.List (isInfixOf, isPrefixOf, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import System.Directory
  ( copyFile
  , createDirectory
  , createDirectoryIfMissing
  , doesDirectoryExist
  , doesFileExist
  , getHomeDirectory
  , listDirectory
  , removeFile
  )
import System.Environment (getEnvironment)
import System.Exit (ExitCode (..))
import System.FilePath (isAbsolute, makeRelative, normalise, (</>))
import System.IO (hClose, openBinaryTempFile)
import System.Process (CreateProcess (cwd, env), proc, readCreateProcessWithExitCode)

data Receipt = Receipt Text FilePath [String] ExitCode Text Text deriving (Eq, Show)
data Mutant = Mutant Text Text Text Receipt deriving (Eq, Show)
data Matrix = Matrix [Mutant] Receipt

data AcquiredInferenceAcceleratorRun = AcquiredInferenceAcceleratorRun
  AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
  Text Text Text Text Text Text Text Text CheckResult

acquiredInferenceAcceleratorRunCheck :: AcquiredInferenceAcceleratorRun -> CheckResult
acquiredInferenceAcceleratorRunCheck (AcquiredInferenceAcceleratorRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredInferenceAcceleratorRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredInferenceAcceleratorRun
  -> value
foldAcquiredInferenceAcceleratorRun consume (AcquiredInferenceAcceleratorRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireInferenceAcceleratorRun, acquireInferenceAcceleratorRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredInferenceAcceleratorRun
acquireInferenceAcceleratorRun = acquire False
acquireInferenceAcceleratorRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredInferenceAcceleratorRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  home <- getHomeDirectory
  let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
      compiler = genesisTrustCompilerExecutable trust
      store = home </> ".cabal/store"
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 32 acquired
  cache <- prepareSourceRepositoryCache root runRoot
  cabalVersion <- runProcess root "cabal-version" cabal ["--numeric-version"]
  matrix <- executeMatrix root runRoot cabal compiler store
  discipline <- sourceDisciplineCheck root
  legacy <- legacyCheck root
  let toolchain = toolchainCheck cabal compiler store cabalVersion matrix
      oracle = oracleCheck (cleanReceipt matrix)
      positives = positiveCheck (cleanReceipt matrix)
      negatives = negativeCheck (cleanReceipt matrix)
      mutants = mutantCheck matrix
      discovery = discoveryCheck acquired
      authority = authorityCheck root runRoot cabal compiler store (cabalVersion : matrixReceipts matrix)
      observer = observerCheck (cabalVersion : matrixReceipts matrix)
      freshness = freshnessCheck root runRoot (cleanReceipt matrix)
      cleanroom = mergeChecks "inference-accelerator-cleanroom" [cache, freshness, legacy]
      qualification = mergeChecks "inference-accelerator-qualification"
        [toolchain, oracle, positives, negatives, mutants, discovery, discipline, legacy, cleanroom]
      prerequisite = mergeChecks "inference-accelerator-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, qualification, authority, observer]
      rows = phaseRows prerequisite toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy
      result = mergeChecks "inference-accelerator" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "inference-accelerator-subject" [checkDigest discipline, receiptDigest (cleanReceipt matrix)]
      oracleId = ids "inference-accelerator-oracle" [checkDigest oracle, checkDigest negatives]
      harnessId = ids "inference-accelerator-harness" (map receiptDigest (cabalVersion : matrixReceipts matrix))
      observerId = ids "inference-accelerator-observer" [checkDigest observer]
      qualificationId = ids "inference-accelerator-qualification" [checkDigest qualification]
      acquiredRunId = ids "inference-accelerator-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "inference-accelerator-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest cabalVersion]
      cleanup = "run-root-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0;live-effects=0"
  pure (AcquiredInferenceAcceleratorRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

executeMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> IO Matrix
executeMatrix root runRoot cabal compiler store = do
  mutants <- mapM runMutant mutantSpecifications
  clean <- runSpec "clean" Nothing
  pure (Matrix mutants clean)
 where
  runMutant (name, flagName, locus, expected) = Mutant name locus expected <$> runSpec name (Just flagName)
  runSpec name selected =
    runProcess root name cabal
      ([ "--builddir=" <> runRoot </> "dist"
       , "--store-dir=" <> store
       , "--with-compiler=" <> compiler
       , "--jobs=1"
       , "test"
       , "capability-spec"
       , "--offline"
       , "--test-show-details=direct"
       ] <> maybe [] (pure . ("-f" <>)) selected)

mutantSpecifications :: [(Text, String, Text, Text)]
mutantSpecifications =
  [ mutant "drop-accelerator-work-item" "drop-work-item" "checkedDemand" "SourceWorkloadMismatch"
  , mutant "accept-accelerator-domain-mismatch" "accept-domain-mismatch" "checkedDemand" "illegal engine case accepted: illegal_accelerator_policy_domain_mismatch"
  , mutant "select-favorable-accelerator-epoch" "select-favorable-epoch" "checkedDemand" "wrong engine provision tag"
  , mutant "drop-accelerator-overlap-debit" "drop-overlap-debit" "epochFor" "AcceleratorDomainMismatch"
  , mutant "skip-accelerator-shard-validation" "skip-shard-validation" "validateWorkload" "wrong engine provision tag"
  ]
 where
  mutant name flagStem locus expected = (name, "inference-accelerator-" <> flagStem <> "-mutant", locus, expected)

cleanReceipt :: Matrix -> Receipt
cleanReceipt (Matrix _ clean) = clean

matrixReceipts :: Matrix -> [Receipt]
matrixReceipts (Matrix mutants clean) = [receipt | Mutant _ _ _ receipt <- mutants] <> [clean]

toolchainCheck :: FilePath -> FilePath -> FilePath -> Receipt -> Matrix -> CheckResult
toolchainCheck cabal compiler store version matrix = CheckResult "inference-accelerator-toolchain"
  [observation "inference-accelerator.cabal" (receiptSummary version), observation "inference-accelerator.compiler" (Text.pack compiler)]
  ([finding "INFERENCE-ACCELERATOR-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed" |
      not (isAbsolute cabal) || receiptExit version /= ExitSuccess || Text.strip (receiptStdout version) /= "3.16.1.0"]
   <> [finding "INFERENCE-ACCELERATOR-COMPILER" (Text.unpack name) "the row did not use the exact compiler/store, offline mode, and --jobs=1" |
      receipt@(Receipt name executable args _ _ _) <- matrixReceipts matrix,
      executable /= cabal || not (isAbsolute compiler) || not (isAbsolute store) ||
      ("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args ||
      "--jobs=1" `notElem` args || "--offline" `notElem` args || Text.null (receiptDigest receipt)])

oracleCheck :: Receipt -> CheckResult
oracleCheck clean = CheckResult "inference-accelerator-independent-oracle"
  [observation "inference-accelerator.oracle" (receiptSummary clean), observation "inference-accelerator.oracle-independence" "EngineAcceleratorOracle imports no production or fixture module"]
  [finding "INFERENCE-ACCELERATOR-ORACLE" oracleSource "the independent Haskell oracle did not report its exact acceptance token" |
    receiptExit clean /= ExitSuccess || notContains acceptance (receiptOutput clean)]
 where
  acceptance = "capability-spec: PASS (3 inference positives, 4 offering quotients, 12 family/lane cells, 1 Gate-1, 8 provision negatives, 5 mutants, 1 covered property)"

positiveCheck :: Receipt -> CheckResult
positiveCheck clean = CheckResult "inference-accelerator-positive-controls"
  [observation "inference-accelerator.positives" "three inference fixtures, four offering quotients, and twelve family/lane cells passed"]
  [finding "INFERENCE-ACCELERATOR-POSITIVE" specSource "the clean positive corpus did not pass" |
    receiptExit clean /= ExitSuccess || notContains "engine-accelerator-properties: TESTED sampled (8 provision branches, each >=9%)" (receiptOutput clean)]

negativeCheck :: Receipt -> CheckResult
negativeCheck clean = CheckResult "inference-accelerator-paired-negatives"
  [observation "inference-accelerator.negatives" "one Gate-1 foreclosure and eight minimally different provision failures passed"]
  [finding "INFERENCE-ACCELERATOR-NEGATIVE" specSource "the paired-negative corpus did not execute" |
    receiptExit clean /= ExitSuccess ||
      notContains "engine-accelerator-invariants: PASS (1 opaque accelerator, 17 locus rows)" (receiptOutput clean) ||
      notContains "engine-accelerator-calculus: PASS (5 kinds, 34 projected units)" (receiptOutput clean)]

mutantCheck :: Matrix -> CheckResult
mutantCheck (Matrix mutants _) = CheckResult "inference-accelerator-mutants"
  [observation ("inference-accelerator.mutant." <> name) (receiptSummary receipt) | Mutant name _ _ receipt <- mutants]
  [finding "INFERENCE-ACCELERATOR-MUTANT" (Text.unpack name) ("the changed production subject did not turn red at " <> locus) |
    Mutant name locus expected receipt <- mutants,
    receiptExit receipt /= ExitFailure 1 || notContains expected (receiptOutput receipt)]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
  production <- Text.concat <$> mapM (fmap Text.pack . readFile . (root </>)) productionSources
  oracle <- Text.pack <$> readFile (root </> oracleSource)
  pure (CheckResult "inference-accelerator-source-discipline"
    [observation "inference-accelerator.production-module-count" "1", observation "inference-accelerator.effect-boundary" "pure inference-accelerator provisioning and run-local Cabal children only; no host, network, service, cluster, or hardware effects"]
    ([finding "INFERENCE-ACCELERATOR-SOURCE-SHAPE" "<inference-accelerator-production>" ("missing production element: " <> token) |
       token <- ["data EngineLane", "data EngineFamily", "offeringLane", "familyAvailable", "provisionEngineOwner", "checkedDemand", "mutateEngineWorkloads", "mutateEngineEpochs", "mutateEpochRows"], notContains token production]
     <> [finding "INFERENCE-ACCELERATOR-ORACLE-SHAPE" oracleSource ("missing oracle element: " <> token) |
       token <- ["expectedOfferings", "expectedFamilies", "expectedCoexistence", "expectedNegatives", "expectedMutants", "expectedCalculusProjection", "expectedLocusEntries"], notContains token oracle]
     <> [finding "INFERENCE-ACCELERATOR-ORACLE-INDEPENDENCE" oracleSource "independent oracle imports a production or fixture module" |
       any (`Text.isInfixOf` oracle) ["import Amoebius", "import EngineAcceleratorFixtures", "import EngineAcceleratorGate"]]))

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired = CheckResult "inference-accelerator-discovery"
  [observation "inference-accelerator.discovery.count" (Text.pack (show (length observed)))]
  [finding "INFERENCE-ACCELERATOR-DISCOVERY" "<phase-32-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
 where
  observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler store receipts = CheckResult "inference-accelerator-authority"
  [observation "inference-accelerator.authority" "no pb/network/host/hardware/live service; exact Cabal/compiler; serial synchronous children"]
  ([finding "INFERENCE-ACCELERATOR-RUN-ROOT" runRoot "run root escaped .build/runs/phase-32/work" | not (pathBelow (root </> ".build/runs/phase-32/work") runRoot)]
   <> [finding "INFERENCE-ACCELERATOR-AUTHORITY" (Text.unpack name) "a process executable or argv exceeded Phase-32 authority" |
      Receipt name executable args _ _ _ <- receipts,
      executable /= cabal || (name /= "cabal-version" && (("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) || any forbiddenArg args])
 where
  forbiddenArg value = any (`isInfixOf` value) ["pb", "docker", "podman", "kubectl", "kind", "ssh", "http://", "https://"]

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts = CheckResult "inference-accelerator-observer"
  (map (observation "inference-accelerator.observer.process" . receiptSummary) receipts)
  [finding "INFERENCE-ACCELERATOR-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest" |
    receipt@(Receipt name executable _ _ _ _) <- receipts, not (isAbsolute executable) || Text.null (receiptDigest receipt)]

freshnessCheck :: FilePath -> FilePath -> Receipt -> CheckResult
freshnessCheck root runRoot clean = CheckResult "inference-accelerator-freshness"
  [observation "inference-accelerator.fresh-build-root" (Text.pack (makeRelative root runRoot))]
  [finding "INFERENCE-ACCELERATOR-FRESHNESS" runRoot "the clean candidate did not execute in the unique acquired run root" |
    receiptExit clean /= ExitSuccess || not (pathBelow (root </> ".build/runs/phase-32/work") runRoot)]

legacyCheck :: FilePath -> IO CheckResult
legacyCheck root = do
  files <- filterM (doesFileExist . (root </>)) retiredSources
  pure (CheckResult "inference-accelerator-legacy-closure"
    [observation "inference-accelerator.legacy.retired-count" (Text.pack (show (length retiredSources))), observation "inference-accelerator.legacy.semantic-inputs" "HaskellOnly"]
    [finding "PROVISION-SEAL-LEGACY" path "retired Python/serialized/test-local-mutant authority remains" | path <- files])

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy =
  [ named "phase-32-claim" [pre]
  , named "phase-32-subject" [toolchain, positives]
  , named "phase-32-command" [toolchain, authority]
  , named "phase-32-oracle" [oracle]
  , named "phase-32-positive-controls" [positives]
  , named "phase-32-paired-negatives" [negatives]
  , named "phase-32-mutants" [mutants]
  , named "phase-32-discovery" [discovery]
  , named "phase-32-challenge" [mutants]
  , named "phase-32-observer" [observer]
  , named "phase-32-authority-bypass" [authority]
  , named "phase-32-freshness" [freshness]
  , named "phase-32-qualification" [qualification]
  , named "phase-32-cleanroom" [cleanroom]
  , named "phase-32-legacy-closure" [legacy]
  , CheckResult "phase-32-predecessor" [observation "phase-32.predecessor" "deferred to durable receipt verifier"] []
  , CheckResult "phase-32-residue" [observation "phase-32.residue" "rendering, effects, runtime fidelity, live engine observation, host, service, cluster, and hardware remain later-owned"] []
  , named "phase-32-pass-criterion" [pre]
  ]
 where
  named = mergeChecks

prepareSourceRepositoryCache :: FilePath -> FilePath -> IO CheckResult
prepareSourceRepositoryCache root runRoot = do
  let source = root </> ".build/dist-newstyle/phase-00-baseline/src"
      target = runRoot </> "dist/src"
  present <- doesDirectoryExist source
  if present then copyTree source target else pure ()
  copied <- if present then sort <$> listDirectory target else pure []
  pure (CheckResult "inference-accelerator-source-repository-cache"
    [observation "inference-accelerator.cache.entries" (Text.pack (show copied))]
    [finding "PROVISION-SEAL-CACHE" (makeRelative root source) "authenticated network-independent source-repository cache is absent or incomplete" |
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
  let parent = root </> ".build/runs/phase-32/work"
  createDirectoryIfMissing True parent
  (leaf, handle) <- openBinaryTempFile parent "candidate-"
  hClose handle
  removeFile leaf
  createDirectory leaf
  pure leaf

runProcess :: FilePath -> Text -> FilePath -> [String] -> IO Receipt
runProcess working name executable args = do
  inherited <- getEnvironment
  let environment = filter (not . forbiddenEnvironment . fst) inherited
  attempt <- try (readCreateProcessWithExitCode ((proc executable args) {cwd = Just working, env = Just environment}) "") :: IO (Either IOException (ExitCode, String, String))
  pure $ either (\problem -> Receipt name executable args (ExitFailure 127) "" (Text.pack (show problem))) (\(status, out, err) -> Receipt name executable args status (Text.pack out) (Text.pack err)) attempt

forbiddenEnvironment :: String -> Bool
forbiddenEnvironment name = name `elem` ["KUBECONFIG", "VAULT_ADDR", "VAULT_TOKEN", "GOOGLE_APPLICATION_CREDENTIALS"] || any (`isPrefixOf` name) ["AWS_", "AZURE_", "VAULT_", "KUBE_"]

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

productionSources, expectedSources, retiredSources :: [FilePath]
productionSources =
  [ "src/provision-seal/Amoebius/Capability/Engine.hs"
  ]
expectedSources = sort (productionSources <> [bindFixtureSource, fixtureSource, gateSource, oracleSource, propsSource, provisionFixtureSource, specSource])
retiredSources =
  [ "tools/inference_accelerator_gate.py"
  , "test/oracle/inference_accelerator_surfaces.tsv"
  , "test/oracle/inference_accelerator/calculus_projection.tsv"
  , "test/oracle/inference_accelerator/coexistence.tsv"
  , "test/oracle/inference_accelerator/family_lane.tsv"
  , "test/oracle/inference_accelerator/offering_lane.tsv"
  , "test/oracle/inference_accelerator/provision_cases.tsv"
  , "test/oracle/inference_accelerator/validation_locus.tsv"
  , "test/spec/capability/EngineAcceleratorMutants.hs"
  , "test/mutant/inference_accelerator/mutant_accept_accelerator_domain_mismatch/mutant.txt"
  , "test/mutant/inference_accelerator/mutant_drop_accelerator_overlap_debit/mutant.txt"
  , "test/mutant/inference_accelerator/mutant_drop_accelerator_work_item/mutant.txt"
  , "test/mutant/inference_accelerator/mutant_select_favorable_accelerator_epoch/mutant.txt"
  , "test/mutant/inference_accelerator/mutant_skip_accelerator_shard_validation/mutant.txt"
  ]

bindFixtureSource, fixtureSource, gateSource, oracleSource, propsSource, provisionFixtureSource, specSource :: FilePath
bindFixtureSource = "test/spec/capability/BindFixtures.hs"
fixtureSource = "test/spec/capability/EngineAcceleratorFixtures.hs"
gateSource = "test/spec/capability/EngineAcceleratorGate.hs"
oracleSource = "test/spec/capability/EngineAcceleratorOracle.hs"
propsSource = "test/spec/capability/EngineAcceleratorProps.hs"
provisionFixtureSource = "test/spec/capability/ProvisionFixtures.hs"
specSource = "test/spec/capability/EngineAcceleratorSpec.hs"
