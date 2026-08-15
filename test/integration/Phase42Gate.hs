{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Dsl.ChildInForceSpec
import Amoebius.Multicluster.ChildUnseal
import Amoebius.Multicluster.ConfluenceClass
import Amoebius.Multicluster.GeoReplication
import Amoebius.Multicluster.SecretInjection
import Amoebius.Multicluster.Spawn
import Amoebius.Pulumi.Backend.EncryptedMinio
import Amoebius.Vault.SecretRef (vaultSecretRef)
import Amoebius.Vault.TransitChildKey
import Control.Monad (forM_, unless, when)
import Data.Aeson (Value (..), eitherDecodeFileStrict', eitherDecodeStrict', object, (.=))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString.Char8 qualified as ByteString
import Data.Either (isLeft, isRight)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import Data.Vector qualified as Vector
import System.Environment (lookupEnv)
import System.Exit (die)
import System.Process (readProcess)

main :: IO ()
main = do
  verifyCustody
  verifyProjection
  verifyConfluence
  verifyIdempotence
  verifyForestAdmission
  verifyUnsealTransitAndInjection
  verifyCheckpoint
  pureOnly <- (== Just "1") <$> lookupEnv "PHASE42_PURE_ONLY"
  unless pureOnly verifyLiveEvidence
  putStrLn "multicluster-spawn-live: PASS (subtree projection, bounded spawn, per-child custody, confluent sibling workflow)"

verifyCustody :: IO ()
verifyCustody = do
  manifest <- TextIO.readFile "test/oracle/preimplementation_artifacts.tsv"
  let rows = filter (Text.isPrefixOf "42\t") (Text.lines manifest)
  require (length rows == 15) "phase42 Phase-0 custody must contain twelve oracles and three mutants"
  require (length (filter (Text.isInfixOf "\toracle\t") rows) == 12) "phase42 oracle custody cardinality"
  require (length (filter (Text.isInfixOf "\tmutant\t") rows) == 3) "phase42 mutant custody cardinality"

verifyProjection :: IO ()
verifyProjection = do
  let forest = parentForest "root" "root-only"
        [ subtree "child-a" "alpha-only" [subtree "grandchild-a1" "alpha-grandchild-only" []]
        , subtree "child-b" "beta-only" []
        ]
  child <- either (die . show) pure (projectSubtree ["child-a"] forest)
  require
    ( childClusterId child == "child-a"
        && childOwnPayload child == "alpha-only"
        && childPath child == ["root", "child-a"]
        && childVisibleClusters child == ["child-a", "grandchild-a1"]
    )
    "phase42-project-identity: child projection exposed sibling or ancestor state"
  grandchild <- either (die . show) pure (projectSubtree ["child-a", "grandchild-a1"] forest)
  require (childVisibleClusters grandchild == ["grandchild-a1"]) "grandchild projection did not compose"
  require (isLeft (projectSubtree ["child-z"] forest)) "missing child path projected"

verifyConfluence :: IO ()
verifyConfluence = do
  oracleBytes <- ByteString.pack <$> readProcess "/home/matthewnowak/.local/bin/dhall-to-json"
    ["--file", "test/inject/confluence/expected_classes.dhall"] ""
  oracle <- either (die . ("classification oracle: " <>)) pure (eitherDecodeStrict' oracleBytes)
  let actual = toClassificationJson crossingInvariants
  require (actual == oracle) "confluence classification differs from independent table"
  require
    (isLeft (admitActiveActive (Unclassified "new-mutable-invariant")))
    "phase42-classifier-default-confluent: unclassified invariant admitted active-active"
  require (isLeft (admitActiveActive GatewayAuthority)) "gateway authority admitted active-active"
  require (isRight (admitActiveActive ContentAddressedBlob)) "content-addressed blob refused active-active"

toClassificationJson :: [CrossingInvariant] -> Value
toClassificationJson invariants =
  toJSONList
    [ object
        [ "activeActiveAllowed" .= activeActiveAllowed invariant
        , "class" .= className (classifyInvariant invariant)
        , "invariant" .= invariantName invariant
        ]
    | invariant <- invariants
    ]
 where
  className classValue = case classValue of
    Confluent -> ("Confluent" :: Text)
    NonConfluent -> "NonConfluent"
  toJSONList = Array . Vector.fromList

verifyIdempotence :: IO ()
verifyIdempotence = do
  ordered <- either (die . show) pure (foldReplicated representativeBatch)
  replayed <- either (die . show) pure (foldReplicated duplicateReorderedBatch)
  require (ordered == replayed) "duplicate/reordered batch changed fold"
  oracle <- decodeValue "test/fixtures/phase42/idempotent-write.golden.json"
  require (foldJson ordered == oracle) "replicated fold differs from idempotent-write golden"

foldJson :: FoldedWorkflow -> Value
foldJson folded = object
  [ "blobKeys" .= foldedBlobKeys folded
  , "foldDigest" .= foldedDigest folded
  , "orderedStages" .= foldedOrderedStages folded
  , "uniqueRecords" .= length (foldedOrderedStages folded)
  , "workId" .= foldedWorkId folded
  ]

verifyForestAdmission :: IO ()
verifyForestAdmission = do
  let demand = representativeForestDemand
      exact = capacityFromDemand demand
  oracle <- decodeValue "test/fixtures/phase42/expected-forest-demand.json"
  require
    (forestDemandJson demand == oracle)
    "phase42-drop-parallel-executor: bounded-parallel demand differs from independent oracle"
  validated <- either (die . show) pure (validateForestSpawn "snapshot-A" exact demand)
  let shortages =
        [ (exact {capacityCpuMilli = capacityCpuMilli exact - 1}, ForestCpuShort)
        , (exact {capacityMemoryBytes = capacityMemoryBytes exact - 1}, ForestMemoryShort)
        , (exact {capacityVmDiskBytes = capacityVmDiskBytes exact - 1}, ForestVmDiskShort)
        , (exact {capacityPodEphemeralBytes = capacityPodEphemeralBytes exact - 1}, ForestPodEphemeralShort)
        , (exact {capacityPluginCacheBytes = capacityPluginCacheBytes exact - 1}, PulumiPluginCacheShort)
        , (exact {capacityWorkspaceBytes = capacityWorkspaceBytes exact - 1}, PulumiWorkspaceShort)
        , (exact {capacityCheckpointBytes = capacityCheckpointBytes exact - 1}, PulumiCheckpointShort)
        , (exact {capacityExecutorLiveSet = capacityExecutorLiveSet exact - 1}, PulumiExecutorLiveSetShort)
        , (exact {capacityHostProcessSlots = capacityHostProcessSlots exact - 1}, ForestHostProcessSlotsShort)
        ]
  forM_ shortages $ \(capacity, expected) -> case validateForestSpawn "snapshot-A" capacity demand of
    Left actual -> require (actual == expected) ("wrong one-short result: " <> show expected)
    Right _ -> die ("one-short provision passed: " <> show expected)
  require (authorizeSpawn "snapshot-A" Nothing == Left MissingSpawnAuthority) "missing spawn authority passed"
  let fresh = freshSpawnAuthority validated
  require (authorizeSpawn "snapshot-B" (Just fresh) == Left SharedSupplySnapshotChanged) "changed snapshot passed"
  consumed <- either (die . show) pure (authorizeSpawn "snapshot-A" (Just fresh))
  require (authorizeSpawn "snapshot-A" (Just consumed) == Left SpawnAuthorityAlreadyConsumed) "spawn token replay passed"
  require (length (reconcileForest (ChildObservation Set.empty) validated) == 6) "first spawn action domain mismatch"
  require
    (null (reconcileForest (ChildObservation (Set.fromList ["amoebius-p42-a", "amoebius-p42-b"])) validated))
    "converged spawn rerun was not a no-op"

capacityFromDemand :: ForestDemand -> ForestCapacity
capacityFromDemand demand = ForestCapacity
  { capacityCpuMilli = forestCpuMilli demand
  , capacityMemoryBytes = forestMemoryBytes demand
  , capacityVmDiskBytes = forestVmDiskBytes demand
  , capacityPodEphemeralBytes = forestPodEphemeralBytes demand
  , capacityPluginCacheBytes = forestPluginCacheBytes demand
  , capacityWorkspaceBytes = forestWorkspaceBytes demand
  , capacityCheckpointBytes = forestCheckpointBytes demand
  , capacityExecutorLiveSet = forestExecutorLiveSet demand
  , capacityHostProcessSlots = forestHostProcessSlots demand
  }

verifyUnsealTransitAndInjection :: IO ()
verifyUnsealTransitAndInjection = do
  require (permitChildUnseal SelfUnseal ParentSealed True == Right ()) "self-unseal mode refused"
  require (permitChildUnseal ParentHeldUnlock ParentSealed False == Left ParentUnlockUnavailable) "parent-held mode did not brick with sealed parent"
  require (permitChildUnseal ParentHeldUnlock ParentUnsealed False == Right ()) "parent-held mode refused available parent"
  keyA <- either (die . Text.unpack) pure (childTransitKey "child-a")
  keyB <- either (die . Text.unpack) pure (childTransitKey "child-b")
  let plaintext = "{ child = \"child-a\" }"
      ciphertext = encryptChildSubtree keyA plaintext
  require (decryptChildSubtree keyA ciphertext == Right plaintext) "child Transit roundtrip failed"
  require (decryptChildSubtree keyB ciphertext == Left WrongChildTransitKey) "sibling Transit key decrypted subtree"
  reference <- either (die . Text.unpack) pure (vaultSecretRef "secret" "amoebius/children/child-a" "canary")
  injected <- either (die . show) pure (injectSecret reference "parent-injected-bytes" emptyInjectionVault)
  require (resolveInjectedSecret reference injected == Right "parent-injected-bytes") "injected SecretRef did not resolve"

verifyCheckpoint :: IO ()
verifyCheckpoint = do
  let demand = PulumiCheckpointDemand "child-a" 8192 2 8192
  provisioned <- either (die . show) pure (provisionCheckpoint 24576 demand)
  require (checkpointPeakBytes provisioned == 24576) "checkpoint peak mismatch"
  require (length (checkpointObjectIdentities provisioned) == 3) "checkpoint identity domain mismatch"
  require (provisionCheckpoint 24575 demand == Left CheckpointStorageShort) "one-byte-short checkpoint admitted"
  require (admitCheckpointWrite False == Left DirectCheckpointWriteDenied) "direct checkpoint PUT admitted"

verifyLiveEvidence :: IO ()
verifyLiveEvidence = do
  evidence <- decodeValue "DEVELOPMENT_PLAN/evidence/phase_42/multicluster-live.json"
  require (lookupPath ["schema"] evidence == Just (String "amoebius.phase42.multicluster-live.v1")) "phase42 live schema"
  require (lookupPath ["register"] evidence == Just (Number 3)) "phase42 live register"
  require (lookupPath ["substrate"] evidence == Just (String "linux-cpu")) "phase42 live substrate"
  forM_
    [ ["spawn", "pulumiRanInsideParent"]
    , ["spawn", "childrenReady"]
    , ["spawn", "secondPassNoOp"]
    , ["projection", "noSiblingOrAncestorBranch"]
    , ["vault", "bothUnsealModes"]
    , ["vault", "crossChildDecryptDenied"]
    , ["vault", "namedSecretResolved"]
    , ["replication", "nativePulsarRoundtrip"]
    , ["replication", "minioWriteOnceHead"]
    , ["replication", "postgresWorkIdReadback"]
    , ["replication", "duplicateReorderIdentical"]
    , ["cleanup", "exact"]
    , ["universalLinuxCpu", "availableOnEveryHardwareSubstrate"]
    ] $ \path -> require (lookupPath path evidence == Just (Bool True)) ("phase42 live false/missing: " <> show path)
  require (lookupPath ["spawn", "secondPassMutations"] evidence == Just (Number 0)) "phase42 live rerun mutated"
  require (lookupPath ["cleanup", "survivingChildClusters"] evidence == Just (Number 0)) "child cluster leak"
  require (lookupPath ["cleanup", "survivingPulumiStacks"] evidence == Just (Number 0)) "Pulumi stack leak"
  require (lookupPath ["universalLinuxCpu", "pristineLinuxHost", "linux"] evidence == Just (String "Incus")) "Linux pristine mapping"
  require (lookupPath ["universalLinuxCpu", "pristineLinuxHost", "linux-cuda"] evidence == Just (String "Incus")) "Linux-CUDA pristine mapping"
  require (lookupPath ["universalLinuxCpu", "pristineLinuxHost", "apple"] evidence == Just (String "Lima")) "Apple pristine mapping"
  require (lookupPath ["universalLinuxCpu", "pristineLinuxHost", "windows"] evidence == Just (String "WSL2")) "Windows pristine mapping"

decodeValue :: FilePath -> IO Value
decodeValue path = eitherDecodeFileStrict' path >>= either (die . ((path <> ": ") <>)) pure

lookupPath :: [Text] -> Value -> Maybe Value
lookupPath [] value = Just value
lookupPath (segment : rest) (Object fields) = KeyMap.lookup (Key.fromText segment) fields >>= lookupPath rest
lookupPath _ _ = Nothing

require :: Bool -> String -> IO ()
require condition message = when (not condition) (die message)
