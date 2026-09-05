{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.ProvisionSealRun.Internal
  ( AcquiredProvisionSealRun
  , acquireProvisionSealRefreshRun
  , acquireProvisionSealRun
  , acquiredProvisionSealRunCheck
  , foldAcquiredProvisionSealRun
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

data AcquiredProvisionSealRun = AcquiredProvisionSealRun
  AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
  Text Text Text Text Text Text Text Text CheckResult

acquiredProvisionSealRunCheck :: AcquiredProvisionSealRun -> CheckResult
acquiredProvisionSealRunCheck (AcquiredProvisionSealRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredProvisionSealRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredProvisionSealRun
  -> value
foldAcquiredProvisionSealRun consume (AcquiredProvisionSealRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireProvisionSealRun, acquireProvisionSealRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredProvisionSealRun
acquireProvisionSealRun = acquire False
acquireProvisionSealRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredProvisionSealRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  home <- getHomeDirectory
  let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
      compiler = genesisTrustCompilerExecutable trust
      store = home </> ".cabal/store"
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 31 acquired
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
      cleanroom = mergeChecks "provision-seal-cleanroom" [cache, freshness, legacy]
      qualification = mergeChecks "provision-seal-qualification"
        [toolchain, oracle, positives, negatives, mutants, discovery, discipline, legacy, cleanroom]
      prerequisite = mergeChecks "provision-seal-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, qualification, authority, observer]
      rows = phaseRows prerequisite toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy
      result = mergeChecks "provision-seal" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "provision-seal-subject" [checkDigest discipline, receiptDigest (cleanReceipt matrix)]
      oracleId = ids "provision-seal-oracle" [checkDigest oracle, checkDigest negatives]
      harnessId = ids "provision-seal-harness" (map receiptDigest (cabalVersion : matrixReceipts matrix))
      observerId = ids "provision-seal-observer" [checkDigest observer]
      qualificationId = ids "provision-seal-qualification" [checkDigest qualification]
      acquiredRunId = ids "provision-seal-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "provision-seal-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest cabalVersion]
      cleanup = "run-root-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0;live-effects=0"
  pure (AcquiredProvisionSealRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

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
       , "provision-seal-spec"
       , "--offline"
       , "--test-show-details=direct"
       ] <> maybe [] (pure . ("-f" <>)) selected)

mutantSpecifications :: [(Text, String, Text, Text)]
mutantSpecifications =
  [ mutant "accept-plan-replay" "validateInfrastructurePlan" "expected provision failure: InfrastructurePlanReplay"
  , mutant "accept-missing-readback" "enactInfrastructurePlan" "expected provision failure: PromisedIdentityNotObserved"
  , mutant "drop-execution-replica" "provision" "desired execution expansion differs from the controller oracle"
  , mutant "drop-runtime-row" "provisionRuntime" "RuntimeStorageProvisionFailure"
  ]
 where
  mutant name locus expected = (name, "provision-seal-" <> Text.unpack name <> "-mutant", locus, expected)

cleanReceipt :: Matrix -> Receipt
cleanReceipt (Matrix _ clean) = clean

matrixReceipts :: Matrix -> [Receipt]
matrixReceipts (Matrix mutants clean) = [receipt | Mutant _ _ _ receipt <- mutants] <> [clean]

toolchainCheck :: FilePath -> FilePath -> FilePath -> Receipt -> Matrix -> CheckResult
toolchainCheck cabal compiler store version matrix = CheckResult "provision-seal-toolchain"
  [observation "provision-seal.cabal" (receiptSummary version), observation "provision-seal.compiler" (Text.pack compiler)]
  ([finding "PROVISION-SEAL-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed" |
      not (isAbsolute cabal) || receiptExit version /= ExitSuccess || Text.strip (receiptStdout version) /= "3.16.1.0"]
   <> [finding "PROVISION-SEAL-COMPILER" (Text.unpack name) "the row did not use the exact compiler/store, offline mode, and --jobs=1" |
      receipt@(Receipt name executable args _ _ _) <- matrixReceipts matrix,
      executable /= cabal || not (isAbsolute compiler) || not (isAbsolute store) ||
      ("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args ||
      "--jobs=1" `notElem` args || "--offline" `notElem` args || Text.null (receiptDigest receipt)])

oracleCheck :: Receipt -> CheckResult
oracleCheck clean = CheckResult "provision-seal-independent-oracle"
  [observation "provision-seal.oracle" (receiptSummary clean), observation "provision-seal.oracle-independence" "ProvisionSealOracle imports no production or fixture module"]
  [finding "PROVISION-SEAL-ORACLE" oracleSource "the independent Haskell oracle did not report its exact acceptance token" |
    receiptExit clean /= ExitSuccess || notContains acceptance (receiptOutput clean)]
 where
  acceptance = "provision-seal-spec: PASS (18 inherited positives, 2 planner paths, 10 specific negatives, 4 activation stages, 4 mutants, 2 covered properties)"

positiveCheck :: Receipt -> CheckResult
positiveCheck clean = CheckResult "provision-seal-positive-controls"
  [observation "provision-seal.positives" "eighteen inherited capability fixtures and both infrastructure-planner paths passed"]
  [finding "PROVISION-SEAL-POSITIVE" specSource "the clean positive corpus did not pass" | receiptExit clean /= ExitSuccess]

negativeCheck :: Receipt -> CheckResult
negativeCheck clean = CheckResult "provision-seal-paired-negatives"
  [observation "provision-seal.negatives" "ten minimally different provision failures and four activation stages passed"]
  [finding "PROVISION-SEAL-NEGATIVE" specSource "the paired-negative corpus did not execute" |
    receiptExit clean /= ExitSuccess || notContains "10 specific negatives" (receiptOutput clean) ||
      notContains "provision-seal-invariants: PASS (1 creation batch, 1 plan replay, 1 action replay, 3 receipt classifications, 2 promised-identity rejections, 34 locus rows)" (receiptOutput clean) ||
      notContains "provision-seal-calculus: PASS (5 kinds, 36 projected units)" (receiptOutput clean)]

mutantCheck :: Matrix -> CheckResult
mutantCheck (Matrix mutants _) = CheckResult "provision-seal-mutants"
  [observation ("provision-seal.mutant." <> name) (receiptSummary receipt) | Mutant name _ _ receipt <- mutants]
  [finding "PROVISION-SEAL-MUTANT" (Text.unpack name) ("the changed production subject did not turn red at " <> locus) |
    Mutant name locus expected receipt <- mutants,
    receiptExit receipt /= ExitFailure 1 || notContains expected (receiptOutput receipt)]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
  production <- Text.concat <$> mapM (fmap Text.pack . readFile . (root </>)) productionSources
  oracle <- Text.pack <$> readFile (root </> oracleSource)
  pure (CheckResult "provision-seal-source-discipline"
    [observation "provision-seal.production-module-count" "4", observation "provision-seal.effect-boundary" "pure provision sealing and run-local Cabal children only; no host, network, service, cluster, or hardware effects"]
    ([finding "PROVISION-SEAL-SOURCE-SHAPE" "<provision-seal-production>" ("missing production element: " <> token) |
       token <- ["planInfrastructure ::", "validateInfrastructurePlan", "enactInfrastructurePlan", "provision ::", "ProvisionedSpec", "provisionRenderSources", "mutateExecutionCandidate", "provisionRuntime"], notContains token production]
     <> [finding "PROVISION-SEAL-ORACLE-SHAPE" oracleSource ("missing oracle element: " <> token) |
       token <- ["expectedNegatives", "expectedActivations", "expectedMutants", "expectedCalculusProjection", "expectedLocusEntries"], notContains token oracle]
     <> [finding "PROVISION-SEAL-ORACLE-INDEPENDENCE" oracleSource "independent oracle imports a production or fixture module" |
       any (`Text.isInfixOf` oracle) ["import Amoebius", "import ProvisionFixtures", "import ProvisionSealGate"]]))

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired = CheckResult "provision-seal-discovery"
  [observation "provision-seal.discovery.count" (Text.pack (show (length observed)))]
  [finding "PROVISION-SEAL-DISCOVERY" "<phase-31-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
 where
  observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler store receipts = CheckResult "provision-seal-authority"
  [observation "provision-seal.authority" "no pb/network/host/hardware/live service; exact Cabal/compiler; serial synchronous children"]
  ([finding "PROVISION-SEAL-RUN-ROOT" runRoot "run root escaped .build/runs/phase-31/work" | not (pathBelow (root </> ".build/runs/phase-31/work") runRoot)]
   <> [finding "PROVISION-SEAL-AUTHORITY" (Text.unpack name) "a process executable or argv exceeded Phase-31 authority" |
      Receipt name executable args _ _ _ <- receipts,
      executable /= cabal || (name /= "cabal-version" && (("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) || any forbiddenArg args])
 where
  forbiddenArg value = any (`isInfixOf` value) ["pb", "docker", "podman", "kubectl", "kind", "ssh", "http://", "https://"]

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts = CheckResult "provision-seal-observer"
  (map (observation "provision-seal.observer.process" . receiptSummary) receipts)
  [finding "PROVISION-SEAL-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest" |
    receipt@(Receipt name executable _ _ _ _) <- receipts, not (isAbsolute executable) || Text.null (receiptDigest receipt)]

freshnessCheck :: FilePath -> FilePath -> Receipt -> CheckResult
freshnessCheck root runRoot clean = CheckResult "provision-seal-freshness"
  [observation "provision-seal.fresh-build-root" (Text.pack (makeRelative root runRoot))]
  [finding "PROVISION-SEAL-FRESHNESS" runRoot "the clean candidate did not execute in the unique acquired run root" |
    receiptExit clean /= ExitSuccess || not (pathBelow (root </> ".build/runs/phase-31/work") runRoot)]

legacyCheck :: FilePath -> IO CheckResult
legacyCheck root = do
  files <- filterM (doesFileExist . (root </>)) retiredSources
  pure (CheckResult "provision-seal-legacy-closure"
    [observation "provision-seal.legacy.retired-count" (Text.pack (show (length retiredSources))), observation "provision-seal.legacy.semantic-inputs" "HaskellOnly"]
    [finding "PROVISION-SEAL-LEGACY" path "retired Python/serialized/test-local-mutant authority remains" | path <- files])

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy =
  [ named "phase-31-claim" [pre]
  , named "phase-31-subject" [toolchain, positives]
  , named "phase-31-command" [toolchain, authority]
  , named "phase-31-oracle" [oracle]
  , named "phase-31-positive-controls" [positives]
  , named "phase-31-paired-negatives" [negatives]
  , named "phase-31-mutants" [mutants]
  , named "phase-31-discovery" [discovery]
  , named "phase-31-challenge" [mutants]
  , named "phase-31-observer" [observer]
  , named "phase-31-authority-bypass" [authority]
  , named "phase-31-freshness" [freshness]
  , named "phase-31-qualification" [qualification]
  , named "phase-31-cleanroom" [cleanroom]
  , named "phase-31-legacy-closure" [legacy]
  , CheckResult "phase-31-predecessor" [observation "phase-31.predecessor" "deferred to durable receipt verifier"] []
  , CheckResult "phase-31-residue" [observation "phase-31.residue" "availability relation, rendering, effects, runtime fidelity, live services, cluster, and hardware remain later-owned"] []
  , named "phase-31-pass-criterion" [pre]
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
  pure (CheckResult "provision-seal-source-repository-cache"
    [observation "provision-seal.cache.entries" (Text.pack (show copied))]
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
  let parent = root </> ".build/runs/phase-31/work"
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
  [ "src/provision-seal/Amoebius/Capacity/Provision.hs"
  , "src/provision-seal/Amoebius/Capacity/RenderSource.hs"
  , "src/provision-seal/Amoebius/Capability/Engine.hs"
  , "src/provision-seal/Amoebius/Capability/Provisioned.hs"
  ]
expectedSources = sort (productionSources <> [bindFixtureSource, fixtureSource, gateSource, oracleSource, propsSource, runtimePropsSource, specSource])
retiredSources =
  [ "tools/provision_seal_gate.py"
  , "test/oracle/provision_seal_surfaces.tsv"
  , "test/oracle/provision_seal/activation.tsv"
  , "test/oracle/provision_seal/calculus_projection.tsv"
  , "test/oracle/provision_seal/planner_cases.tsv"
  , "test/oracle/provision_seal/provision_cases.tsv"
  , "test/oracle/provision_seal/validation_locus.tsv"
  , "test/spec/capability/ProvisionMutants.hs"
  , "test/mutant/provision_seal/mutant_double_debit_controller_child/mutant.txt"
  , "test/mutant/provision_seal/mutant_drop_execution_replica/mutant.txt"
  , "test/mutant/provision_seal/mutant_drop_largest_kubelet_metadata/mutant.txt"
  , "test/mutant/provision_seal/mutant_drop_surge/mutant.txt"
  , "test/mutant/provision_seal/mutant_fixed_prometheus/mutant.txt"
  , "test/mutant/provision_seal/mutant_missing_metadata_model/mutant.txt"
  , "test/mutant/provision_seal/mutant_old_revision/mutant.txt"
  , "test/mutant/provision_seal/mutant_provisioned_in_bound/mutant.txt"
  , "test/mutant/provision_seal/mutant_unchecked_prior/mutant.txt"
  , "test/mutant/provision_seal/mutant_wrong_revision_join/mutant.txt"
  ]

bindFixtureSource, fixtureSource, gateSource, oracleSource, propsSource, runtimePropsSource, specSource :: FilePath
bindFixtureSource = "test/spec/capability/BindFixtures.hs"
fixtureSource = "test/spec/capability/ProvisionFixtures.hs"
gateSource = "test/spec/capability/ProvisionSealGate.hs"
oracleSource = "test/spec/capability/ProvisionSealOracle.hs"
propsSource = "test/spec/capability/ProvisionProps.hs"
runtimePropsSource = "test/spec/capability/RuntimeStorageBindingProps.hs"
specSource = "test/spec/capability/ProvisionSealSpec.hs"
