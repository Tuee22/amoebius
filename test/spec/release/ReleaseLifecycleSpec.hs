{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Release.Environment
import Amoebius.Release.EvidenceWitness
import Amoebius.Release.Ledger
import Amoebius.Release.Promote
import Amoebius.Release.PromotionGate
import Amoebius.Release.ReleaseHash
import Amoebius.Release.RolloutPlan
import Amoebius.Release.SchemaMigration
import Control.Exception (finally)
import Control.Monad (foldM, forM_, unless)
import Data.Aeson (FromJSON (parseJSON), ToJSON, eitherDecodeFileStrict', encode, withObject, (.:))
import Data.Aeson qualified as Aeson
import Data.ByteString.Lazy qualified as Lazy
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Text.IO qualified as TextIO
import GHC.Generics (Generic)
import System.Directory (doesFileExist, getCurrentDirectory)
import System.Environment (lookupEnv)
import System.Exit (die)
import System.FilePath ((</>), takeDirectory)
import System.Process (callProcess, readProcess)

data Fixture = Fixture
  { fixtureDeploymentDhall :: Text
  , fixtureImageDigests :: [Text]
  , fixtureSubstrateFingerprint :: Text
  }
  deriving stock (Generic, Show)

instance FromJSON Fixture where
  parseJSON = withObject "Fixture" $ \value -> Fixture
    <$> value .: "resolvedDeploymentDhall"
    <*> value .: "imageDigests"
    <*> value .: "substrateFingerprint"

data LiveSetup = LiveSetup
  { challenge :: Text
  , stateFile :: FilePath
  }
  deriving stock (Generic, Show)

instance FromJSON LiveSetup

data LiveResult = LiveResult
  { resultChallenge :: Text
  , resultReleaseHash :: Text
  , resultRefusals :: [Text]
  , resultRolloutPhases :: [Text]
  , resultStructuralProvision :: Bool
  , resultFailureRetainedBytes :: Integer
  , resultTypedHaskell :: Bool
  }
  deriving stock (Generic, Show)

instance ToJSON LiveResult

main :: IO ()
main = do
  root <- projectRoot
  baseline <- loadFixture (root </> "test/golden/release_fixture.json")
  perturbed <- loadFixture (root </> "test/golden/release_fixture_perturbed.json")
  hash <- checkReleaseHashAndLedger root baseline perturbed
  checkPromotionCas root
  refusals <- checkEvidenceGate root
  phases <- checkRollout root
  demand <- checkMigrationProvision
  pureOnly <- lookupEnv "RELEASE_LIFECYCLE_PURE_ONLY"
  reuse <- lookupEnv "RELEASE_LIFECYCLE_REUSE_FRESH_LIVE"
  case (pureOnly, reuse) of
    (Just "1", _) -> pure ()
    (_, Just "1") -> validateEvidence root
    _ -> runLive root hash refusals phases demand
  putStrLn "release-lifecycle-live: PASS (immutable release, ETag-CAS promotion, evidence gate, ordered live rollout, structural migration)"

loadFixture :: FilePath -> IO Fixture
loadFixture path = eitherDecodeFileStrict' path >>= either die pure

sourceFrom :: Fixture -> ReleaseSource
sourceFrom fixture = ReleaseSource
  { Amoebius.Release.ReleaseHash.resolvedDeploymentDhall = fixtureDeploymentDhall fixture
  , releaseImageDigests = fixtureImageDigests fixture
  , releaseSubstrateFingerprint = fixtureSubstrateFingerprint fixture
  }

checkReleaseHashAndLedger :: FilePath -> Fixture -> Fixture -> IO ReleaseHash
checkReleaseHashAndLedger root baseline perturbed = do
  golden <- Text.strip <$> TextIO.readFile (root </> "test/golden/release_hash.txt")
  let source = sourceFrom baseline
      baselineHash = deriveReleaseHash source
      perturbedHash = deriveReleaseHash (sourceFrom perturbed)
      substrateDistinct = deriveReleaseHash
        (source {releaseSubstrateFingerprint = "windows|x86_64|wsl2"})
  assertWith "release-lifecycle-hash-omits-substrate:" (releaseHashText baselineHash == golden)
  assertWith "release-lifecycle-perturbed-release-collision:" (baselineHash /= perturbedHash)
  assertWith "release-lifecycle-hash-omits-substrate:" (baselineHash /= substrateDistinct)
  let release = releaseFromSource "deployment/dhall/golden" source
  (ledger1, inserted) <- either (die . show) pure (writeRelease release emptyReleaseLedger)
  assertEqual "release-lifecycle-ledger-insert" LedgerInserted inserted
  (ledger2, deduplicated) <- either (die . show) pure (writeRelease release ledger1)
  assertEqual "release-lifecycle-ledger-deduplicate" LedgerDeduplicated deduplicated
  assertEqual "release-lifecycle-ledger-cardinality" 1 (Map.size (ledgerEntries ledger2))
  let edited = release {releaseDeploymentDhallRef = "deployment/dhall/edited"}
  case writeRelease edited ledger2 of
    Left (ImmutableReleaseConflict conflictHash) -> assertEqual "release-lifecycle-immutable-conflict-hash" baselineHash conflictHash
    _ -> die "release-lifecycle-immutable-release-edit-admitted"
  pure baselineHash

checkPromotionCas :: FilePath -> IO ()
checkPromotionCas root = do
  let previous = deriveReleaseHash (ReleaseSource "previous" [] "linux-cpu|x86_64|cgroup-v2")
      target = deriveReleaseHash (ReleaseSource "verified" [] "linux-cpu|x86_64|cgroup-v2")
      initial = pointerStoreFromHeads [(Prod, PointerHead previous (ETag 0))]
      (afterDev, devResult) = promote Dev Nothing target initial
      (afterStaging, stagingResult) = promote Staging Nothing target afterDev
      (winner, prodResult) = promote Prod (Just (ETag 0)) target afterStaging
      (afterLoser, loserResult) = promote Prod (Just (ETag 0)) previous winner
  assertEqual "release-lifecycle-dev-pointer" (PointerWritten (PointerHead target (ETag 1))) devResult
  assertEqual "release-lifecycle-staging-pointer" (PointerWritten (PointerHead target (ETag 1))) stagingResult
  assertEqual "release-lifecycle-prod-pointer" (PointerWritten (PointerHead target (ETag 1))) prodResult
  assertWith "release-lifecycle-blind-put:" (case loserResult of PointerConflict (Just (PointerHead headHash (ETag 1))) -> headHash == target; _ -> False)
  assertEqual "release-lifecycle-cas-loser-zero-effect" winner afterLoser
  assertEqual "release-lifecycle-app-bytes-invariant"
    (Just target, Just target)
    (pointerRelease <$> Map.lookup Staging (pointerHeads winner), pointerRelease <$> Map.lookup Prod (pointerHeads winner))
  golden <- TextIO.readFile (root </> "test/golden/promote_history.txt")
  let transcript = Text.unlines
        [ "step\tenvironment\tprecondition\tresult\thead"
        , "1\tDev\tabsent\tPointerWritten\trelease_verified@etag-1"
        , "2\tStaging\tabsent\tPointerWritten\trelease_verified@etag-1"
        , "3\tProd\trelease_previous@etag-0\tPointerWritten\trelease_verified@etag-1"
        , "race-loser\tProd\trelease_previous@etag-0\tPointerConflict\trelease_verified@etag-1"
        ]
  assertEqual "release-lifecycle-promote-history-oracle" golden transcript

checkEvidenceGate :: FilePath -> IO [Text]
checkEvidenceGate root = do
  let verified = evidenceLedger [(Decision, Tested), (Protocol, Tested), (Runtime, Tested)]
      runtimeMissing = evidenceLedger [(Decision, Tested), (Protocol, Tested), (Runtime, Unverified)]
      protocolMissing = evidenceLedger [(Decision, Tested), (Protocol, Unverified), (Runtime, Unverified)]
  assertEqual "release-lifecycle-evidence-strength-map" [Decision, Protocol, Runtime] (map requiredEvidence [Dev, Staging, Prod])
  assertEqual "release-lifecycle-runtime-witness-absent" Nothing (witnessFor Runtime runtimeMissing)
  assertWith "release-lifecycle-gate-admits-unverified:" $ case preparePromotion Prod runtimeMissing of
    Left PromotionRefusedRuntimeEvidenceMissing -> True
    _ -> False
  assertWith "release-lifecycle-protocol-specific-refusal" $ case preparePromotion Staging protocolMissing of
    Left PromotionRefusedProtocolEvidenceMissing -> True
    _ -> False
  assertWith "release-lifecycle-verified-prod-advance" $
    case preparePromotion Prod verified of Right advance -> advanceEnvironment advance == Prod; Left _ -> False
  mapping <- TextIO.readFile (root </> "test/golden/evidence_strength.txt")
  assertEqual "release-lifecycle-evidence-strength-oracle" (Text.unlines
    [ "environment\trequired_layer\trequired_strength"
    , "Dev\tDecision\ttested"
    , "Staging\tProtocol\ttested"
    , "Prod\tRuntime\ttested"
    ]) mapping
  pure ["PromotionRefused:RuntimeEvidenceMissing", "PromotionRefused:ProtocolEvidenceMissing"]

checkRollout :: FilePath -> IO [Text]
checkRollout root = do
  let expected = [BaseApply, SchemaMigration, Finalize]
  assertWith "release-lifecycle-rollout-reorders-retire:" (rolloutPlan == expected)
  assertWith "release-lifecycle-phase-gate-selfreport:" $
    case applyPhase BaseApply (SelfReportedDone BaseApply) emptyRolloutState of
      Left (PhaseReadinessNotExternallyObserved BaseApply) -> True
      _ -> False
  final <- foldM (\state phase -> either (die . show) pure (applyPhase phase (LiveObjectReady phase) state)) emptyRolloutState expected
  assertEqual "release-lifecycle-rollout-complete" expected (appliedPhases final)
  case applyPhase Finalize (LiveObjectReady Finalize) emptyRolloutState of
    Left (PhaseOutOfOrder BaseApply Finalize) -> pure ()
    _ -> die "release-lifecycle-rollout-out-of-order-admitted"
  golden <- TextIO.readFile (root </> "test/golden/rollout_order.txt")
  assertEqual "release-lifecycle-rollout-order-oracle" (Text.unlines
    [ "ordinal\tphase\tobserved_condition"
    , "0\tbase-apply\tdeployment/release-lifecycle-base:Available"
    , "1\tschema-migration\tjob/release-lifecycle-migrate:Complete+sql-copy:verified"
    , "2\tfinalize\tdeployment/release-lifecycle-final:Available+old-schema:retired"
    ]) golden
  pure ["base-apply", "schema-migration", "finalize"]

checkMigrationProvision :: IO SchemaMigrationDemand
checkMigrationProvision = do
  let demand = SchemaMigrationDemand 10 20 30 40 50 60 70 80 90 1
      exact = SchemaMigrationSupply 10 20 30 40 50 60 70 80 90 450
      oneShortRows =
        [ ("old-schema", exact {suppliedOldSchemaBytes = 9})
        , ("new-schema", exact {suppliedNewSchemaBytes = 19})
        , ("row-data", exact {suppliedRowDataBytes = 29})
        , ("copy-wal", exact {suppliedCopyWalBytes = 39})
        , ("verification-wal", exact {suppliedVerificationWalBytes = 49})
        , ("workspace", exact {suppliedWorkspaceBytes = 59})
        , ("executor", exact {suppliedExecutorBytes = 69})
        , ("old-workload", exact {suppliedOldWorkloadBytes = 79})
        , ("new-workload", exact {suppliedNewWorkloadBytes = 89})
        ]
  assertEqual "release-lifecycle-structural-exact-fit" (Right ()) (provisionSchemaMigration demand exact)
  forM_ oneShortRows $ \(label, supply) ->
    assertWith (if label == "verification-wal" then "release-lifecycle-drop-verification-wal:" else "release-lifecycle-structural-one-short:" <> label) $
      case provisionSchemaMigration demand supply of Left problems -> any (hasLabel label) problems; Right () -> False
  assertWith "release-lifecycle-scalar-migration-peak:" $
    case provisionSchemaMigration demand exact {suppliedTotalBytes = 449} of Left problems -> any (hasLabel "total") problems; Right () -> False
  assertWith "release-lifecycle-drop-old-schema-on-failure:" (failureRetainedBytes demand == 210)
  stages <- foldM (\current next -> either (die . show) pure (advanceMigration current next)) MigrationAbsent
    [NewSchemaCreated, CopyVerified, OldSchemaRetired]
  assertEqual "release-lifecycle-migration-final-stage" OldSchemaRetired stages
  case advanceMigration NewSchemaCreated OldSchemaRetired of
    Left (MigrationStageOutOfOrder NewSchemaCreated OldSchemaRetired) -> pure ()
    _ -> die "release-lifecycle-migration-retire-before-verification"
  pure demand
 where
  hasLabel label (MigrationProvisionShort actual _ _) = actual == label

runLive :: FilePath -> ReleaseHash -> [Text] -> [Text] -> SchemaMigrationDemand -> IO ()
runLive root hash refusals phases demand = do
  let helper = root </> "tools/release_lifecycle_live.py"
  raw <- readProcess "python3" [helper, "setup"] ""
  setup <- either die pure (decodeSetup raw)
  let resultPath = "/tmp/amoebius-release-lifecycle-result-" <> Text.unpack (challenge setup) <> ".json"
      cleanup = callProcess "python3" [helper, "cleanup", "--state", stateFile setup]
      result = LiveResult
        { resultChallenge = challenge setup
        , resultReleaseHash = releaseHashText hash
        , resultRefusals = refusals
        , resultRolloutPhases = phases
        , resultStructuralProvision = True
        , resultFailureRetainedBytes = failureRetainedBytes demand
        , resultTypedHaskell = True
        }
  (do
      Lazy.writeFile resultPath (encode result)
      callProcess "python3" [helper, "finish", "--state", stateFile setup, "--result", resultPath]
    ) `finally` cleanup
  validateEvidence root

decodeSetup :: String -> Either String LiveSetup
decodeSetup raw = case lines raw of
  [] -> Left "release-lifecycle-live-setup-empty"
  rows -> Aeson.eitherDecodeStrict' (TextEncoding.encodeUtf8 (Text.pack (last rows)))

validateEvidence :: FilePath -> IO ()
validateEvidence root = do
  let path = root </> "DEVELOPMENT_PLAN/evidence/phase_39/release-lifecycle-live.json"
  exists <- doesFileExist path
  unless exists (die "release-lifecycle-live-evidence-absent")
  raw <- TextIO.readFile path
  forM_ ["\"sealed\": true", "\"register\": 3", "\"substrate\": \"linux-cpu\"", "\"allHardwareSubstrates\": true", "\"Incus\"", "\"Lima\"", "\"WSL2\""] $ \needle ->
    unless (needle `Text.isInfixOf` raw) (die ("release-lifecycle-live-evidence-field:" <> Text.unpack needle))

assertWith :: String -> Bool -> IO ()
assertWith label condition = unless condition (die label)

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual = unless (expected == actual) (die (label <> ":expected=" <> show expected <> ":actual=" <> show actual))

projectRoot :: IO FilePath
projectRoot = getCurrentDirectory >>= search
 where
  search directory = do
    found <- doesFileExist (directory </> "cabal.project")
    if found then pure directory else do
      let parent = takeDirectory directory
      if parent == directory then die "release-lifecycle-project-root-not-found" else search parent
