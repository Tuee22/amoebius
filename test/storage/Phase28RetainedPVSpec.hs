{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Capacity.Storage
import Amoebius.Capacity.StorageGeometry hiding (provisionStorageMigration)
import Amoebius.Storage.HostVolume
import Amoebius.Storage.RetainedPV
import Amoebius.Storage.RetainedScaling
import Amoebius.Storage.ScalingAction
import Data.Map.Strict qualified as Map
import System.Exit (die)

main :: IO ()
main = do
  verifyIdentityAndUniformity
  verifyPerBackingAndDedupe
  verifyHostObservation
  verifyRebind
  verifyMigration
  verifyScalingAuthority
  putStrLn "phase28-retained-pv-spec: PASS (identity, uniform backing debit, host image, rebind, migration, scaling authority)"

verifyIdentityAndUniformity :: IO ()
verifyIdentityAndUniformity = do
  assertEqual "logical identity" "retained-witness/pg-witness/pv_0" (retainedLogicalIdentity "retained-witness" "pg-witness" 0)
  assertEqual "RFC-1123 name" "retained-witness.pg-witness.pv-0" (retainedMetadataName "retained-witness" "pg-witness" 0)
  plan <- requireRight (planRetainedInventory (Map.singleton ownerA 64) [] [slot ownerA 64 0 17, slot ownerA 64 1 25])
  assertEqual "uniform max rounded x members" (Map.singleton ownerA 64) (uniformDebitByBacking plan)
  assertEqual "uniform rendered capacities" [32, 32] (fmap retainedPvCapacityBytes (Map.elems (uniformRetainedPvs plan)))
  let insufficient = planRetainedInventory (Map.singleton ownerA 56) [] [slot ownerA 64 0 17, slot ownerA 64 1 25]
  case insufficient of
    Left problem | retainedInventoryErrorReason problem == "durable-demand-exceeds-backing" -> pure ()
    verdict -> die ("uniform_claim_skew_over_backing: " <> show verdict)

verifyPerBackingAndDedupe :: IO ()
verifyPerBackingAndDedupe = do
  let rows = [slot ownerA 56 0 25, slot ownerA 56 1 17, slot ownerB 100 2 25]
      observed = Map.fromList [(ownerA, 56), (ownerB, 100)]
  case planRetainedInventory observed [] rows of
    Left (DurableDemandExceedsBacking owner required available) -> do
      assertEqual "short backing identity" ownerA owner
      assertEqual "uniform short required" 64 required
      assertEqual "uniform short available" 56 available
    verdict -> die ("per-backing debit collapsed: " <> show verdict)
  let one = slot ownerA 64 0 17
  deduped <- requireRight (planRetainedInventory (Map.singleton ownerA 64) [one] [one])
  assertEqual "unchanged identity counted once" 1 (Map.size (uniformRetainedPvs deduped))

verifyHostObservation :: IO ()
verifyHostObservation = do
  plan <- requireRight (planRetainedInventory (Map.singleton ownerA 64) [] [slot ownerA 64 0 17])
  pv <- onlyPv plan
  let exact = HostVolumeObservation FixedRawFilesystemImage (retainedPvCapacityBytes pv) (retainedPvRequiredUsableBytes pv) "ext4"
  assertEqual "fixed image exact" (Right ()) (validateHostVolume pv exact)
  assertEqual "raw host directory" (Left RawHostDirectoryForbidden) (validateHostVolume pv exact {observedHostVolumeKind = RawHostDirectory})
  assertEqual
    "raw one byte under"
    (Left (RawCapacityBelowWitness (retainedPvCapacityBytes pv) (retainedPvCapacityBytes pv - 1)))
    (validateHostVolume pv exact {observedRawBytes = retainedPvCapacityBytes pv - 1})
  assertEqual "filesystem mismatch" (Left (ObservedFilesystemTypeMismatch "ext4" "xfs")) (validateHostVolume pv exact {observedFilesystemType = "xfs"})

verifyRebind :: IO ()
verifyRebind = do
  let stale = RetainedClaimRef "retained-witness" "pgdata-pg-witness-0" (Just "old-uid") (Just "7")
      clean = sanitizeClaimRefForRebind stale
  assertEqual "claim namespace stable" "retained-witness" (retainedClaimNamespace clean)
  assertEqual "claim name stable" "pgdata-pg-witness-0" (retainedClaimName clean)
  assertEqual "claim UID cleared" Nothing (retainedClaimUid clean)
  assertEqual "claim resourceVersion cleared" Nothing (retainedClaimResourceVersion clean)
  plan <- requireRight (planRetainedInventory (Map.singleton ownerA 64) [] [slot ownerA 64 0 17])
  pv <- onlyPv plan
  assertEqual "Retain policy" "Retain" (retainedPvReclaimPolicy pv)

verifyMigration :: IO ()
verifyMigration = do
  let envelope = MigrationEnvelope 64 32 16 112 True "sha256:nonce"
  provisioned <- requireRight (provisionStorageMigration envelope)
  assertEqual "migration high-water" 112 (provisionedMigrationHighWater provisioned)
  assertEqual
    "old+new+workspace one short"
    (Left (OldNewWorkspaceExceedsBacking 112 111))
    (provisionStorageMigration envelope {migrationBackingBytes = 111})
  assertEqual "copy envelope short" (Left CopyJobEnvelopeExceedsHeadroom) (provisionStorageMigration envelope {migrationCopyEnvelopeFits = False})
  assertEqual
    "byte verification mismatch"
    (Left (ByteVerificationMismatch "sha256:nonce" "sha256:corrupt"))
    (completeStorageMigration provisioned "sha256:corrupt" True)
  assertEqual "cleanup observation required" (Left OldExtentDeletionNotObserved) (completeStorageMigration provisioned "sha256:nonce" False)
  assertEqual
    "migration completion order"
    (Right [CopyJobRan, IndependentByteVerifyPassed, ClaimCutOver, ReclaimEligible, NewVolumeNonceReadBack, OldExtentDeletionObserved, OldExtentRetired])
    (completeStorageMigration provisioned "sha256:nonce" True)

verifyScalingAuthority :: IO ()
verifyScalingAuthority = do
  allocate <- mintStorageScalingAction CreateRetainedCapacity "fresh"
  assertEqual "stale retained action" (Left StaleOrConsumedStorageScalingAction) =<< enactRetainedScaling "stale" allocate
  assertEqual "fresh retained action" (Right AllocateRetainedExtent) =<< enactRetainedScaling "fresh" allocate
  assertEqual "retained token reuse" (Left StaleOrConsumedStorageScalingAction) =<< enactRetainedScaling "fresh" allocate
  provider <- mintStorageScalingAction CreateProviderCapacity "fresh"
  assertEqual "provider capability absent" (Left ProviderCapacityUnavailable) =<< enactRetainedScaling "fresh" provider

slot :: BackingId -> Integer -> Integer -> Integer -> DeclaredRetainedVolume
slot owner available ordinal logical =
  let allocation = BackingAllocationPolicy 0 8
      presentation = FilesystemPresentation "ext4" 1000
      claim = StatefulSetClaimSlot "stateful" "data" (fromInteger ordinal)
      demand = DeclaredVolumeDemand
        { volumeDemandId = "volume-" <> retainedPvcName claim
        , volumeClaim = claim
        , volumeBacking = StorageBacking owner (fromInteger available) allocation
        , volumeLogicalBytes = fromInteger logical
        , volumeGeometry = DirectGeometry 1
        , volumePresentation = presentation
        }
   in DeclaredRetainedVolume "namespace" demand (NodeLocal "node") presentation allocation

ownerA, ownerB :: BackingId
ownerA = BackingId "durable-a"
ownerB = BackingId "durable-b"

onlyPv :: UniformClaimPlan -> IO RetainedPV
onlyPv plan = case Map.elems (uniformRetainedPvs plan) of
  [value] -> pure value
  values -> die ("expected one PV, got " <> show (length values))

requireRight :: Show problem => Either problem value -> IO value
requireRight = either (die . show) pure

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual
  | expected == actual = pure ()
  | otherwise = die (label <> ": expected " <> show expected <> ", got " <> show actual)
