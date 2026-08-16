{-# LANGUAGE OverloadedStrings #-}

module ExecutionAcceleratorFixtures
  ( Phase9Fixture (..)
  , phase9Fixtures
  , phase9PositiveRows
  , phase9ComposedWitnessRows
  , acceleratorOffering
  , acceleratorDemand
  , baseEtcdLogical
  , baseEtcdModel
  , imageCatalog
  , imageDemand
  , metadataModel
  , runPhase9DeterministicChecks
  ) where

import Amoebius.Capacity.Accelerator
  ( AcceleratorCoexistenceEpoch (..)
  , AcceleratorDemand (..)
  , AcceleratorDevice (..)
  , AcceleratorError (..)
  , AcceleratorFamily (..)
  , AcceleratorOffering (..)
  , AcceleratorResidencyDemand (..)
  , InterconnectRequirement (..)
  , ResidencyPlacement (..)
  , VramShardAssignment (..)
  , provisionAccelerator
  , validateExclusiveAcceleratorOwners
  )
import Amoebius.Capacity.Composed (ComposedPlacementInput (..), ComposedPlacementWitness, placeFullResourceVector)
import Amoebius.Capacity.Etcd
  ( EtcdError (..)
  , EtcdLogicalDemand (..)
  , EtcdStorageModel (..)
  , provisionEtcdDemand
  )
import Amoebius.Capacity.Execution
  ( BoundExecutionInventory (..)
  , BoundExecutionUnit (..)
  , ControllerBody (..)
  , DeploymentRollout
  , ExecutionError (..)
  , ExecutionTransitionSource (..)
  , PriorExecutionProvision (..)
  , ProvisionedExecutionEpochs (..)
  , StatefulSetRollout (..)
  , DaemonSetRollout (..)
  , mkRollingUpdate
  , provisionExecutionEpochs
  , recreateRollout
  )
import Amoebius.Capacity.NodeLocalStorage
  ( ContainerRuntimeModel (..)
  , DiskExtentKind (..)
  , ImageArtifactRequirement (..)
  , ImageMetadataCatalog (..)
  , KubeletFilesystemLayout (..)
  , LocalBacking (..)
  , NamedDiskCarve (..)
  , NodeLocalStorageError (..)
  , NodeStorageComponent (..)
  , NodeStorageRole (..)
  , NodeImageStorageDemand (..)
  , ProvisionedNodeImageStorageDemand (..)
  , PhysicalDiskPartition (..)
  , VmDiskCarve (..)
  , fitLayoutComponents
  , provisionNodeImageStorage
  , provisionPhysicalDiskPartition
  , validateFilesystemLayoutObservation
  )
import Amoebius.Capacity.HostReservation
  ( HostReservation (..)
  , HostReservationPartition (..)
  , mkHostReservation
  , releaseHostReservation
  )
import Amoebius.Capacity.ProviderRoot
  ( NodeRootQuota (..)
  , PerInstanceDiskDemand (..)
  , ProviderRootError (..)
  , ProviderRootPolicy (..)
  , ProviderUsableDiskCarveTemplate (..)
  , ProvisionedPerInstanceDiskTemplate (..)
  , provisionPerInstanceDiskTemplate
  )
import Amoebius.Capacity.RuntimeStorage
  ( KubeletRuntimeMetadataDemand (..)
  , KubeletRuntimeMetadataModel (..)
  , PodRuntimeMetadataSource (..)
  , RuntimeAccountingId (..)
  , RuntimeAccountingScope (..)
  , RuntimeStorageError (..)
  , provisionNodeRuntimeStorageAccounting
  )
import Amoebius.Capacity.Scheduler
  ( CandidateReservation (..)
  , CompleteResourceReservation (..)
  , ContentExtent (..)
  , ReservationLedgerRow (..)
  , ReservationState (..)
  , SchedulerError (..)
  , SchedulerSnapshot (..)
  , SchedulerSupply (..)
  , mkCompleteReservation
  , beginBinding
  , confirmBound
  , ledgerOnlyAbsentRecovery
  , provisionSchedulingGuard
  )
import Amoebius.Capacity.PulumiExecution
  ( BuildExecutionEnvelope (..)
  , BuildStageDemand (..)
  , EngineProcessDemand (..)
  , EngineSystemReserve (..)
  , MonitoringWorkBudget (..)
  , PulumiExecutionDemand (..)
  , provisionBuildExecution
  , provisionEngineSystemReserve
  , provisionMonitoringWork
  , provisionPulumiExecution
  )
import Amoebius.Capacity.Storage
  ( BackingAllocationPolicy (..)
  , BackingId (..)
  , FilesystemPresentation (..)
  , StorageBacking (..)
  , fitBacking
  )
import Amoebius.Capacity.Types
  ( Axis (..)
  , ResourceEnvelope
  , Workload (..)
  , mkResourceEnvelope
  , zeroResources
  )
import CapacityTopologyFixtures (positiveCases, resources)
import Control.Monad (unless)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)

data Phase9Fixture = Phase9Fixture
  { phase9Variant :: Text
  , phase9Family :: Text
  , phase9Operation :: Text
  , phase9Expected :: Text
  , phase9Twin :: Text
  , phase9Catalog :: Text
  , phase9Negative :: Either Text ()
  , phase9Positive :: Either Text ()
  }

phase9Fixtures :: [Phase9Fixture]
phase9Fixtures =
  [ fixture "execution-replica-peak" "illegal_hard_ceiling_overcommit" "execution" "Overcommit:CpuAxis" (executionResult 3 deploymentOne) (executionResult 4 deploymentOne)
  , fixture "execution-rollout-surge" "illegal_hard_ceiling_overcommit" "execution" "Overcommit:CpuAxis" (executionResult 5 deploymentRolling) (executionResult 6 deploymentRolling)
  , fixture "execution-prior-old-revision" "illegal_hard_ceiling_overcommit" "execution-update" "Overcommit:CpuAxis" (executionUpdateResult 3) (executionUpdateResult 4)
  , fixture "scheduler-aggregate-root" "illegal_hard_ceiling_overcommit" "scheduler" "SchedulerCapacityExceeded:CpuAxis" (schedulerCapacityResult 3) (schedulerCapacityResult 4)
  , fixture "scheduler-snapshot-cas" "illegal_hard_ceiling_overcommit" "scheduler" "SchedulerSnapshotChanged" (schedulerSnapshotResult "stale") (schedulerSnapshotResult "fresh")
  , fixture "scheduler-projection" "illegal_hard_ceiling_overcommit" "scheduler" "ReservationProjectionMismatch" (schedulerProjectionResult True) (schedulerProjectionResult False)
  , fixture "runtime-nodefs" "illegal_node_local_storage_over_backing" "runtime-metadata" "NodeLocalStorageOverBacking:nodefs" (runtimeLayoutResult 4 62) (runtimeLayoutResult 5 62)
  , fixture "runtime-imagefs" "illegal_node_local_storage_over_backing" "runtime-metadata" "NodeLocalStorageOverBacking:runtime" (runtimeLayoutResult 5 61) (runtimeLayoutResult 5 62)
  , fixture "runtime-model" "illegal_node_local_storage_over_backing" "runtime-metadata" "RuntimeMetadataModelMissing:v1" (runtimeModelResult Map.empty) (runtimeModelResult (Map.singleton "v1" metadataModel))
  , fixture "runtime-scope-domain" "illegal_node_local_storage_over_backing" "runtime-metadata" "RuntimeAccountingDomainMismatch" (runtimeScopeResult (Set.singleton "planned:other")) (runtimeScopeResult (Set.singleton "planned:slot-0"))
  , fixture "node-image-workspace" "illegal_node_local_storage_over_backing" "image-peak" "NodeLocalStorageOverBacking:unified" (unifiedImageResult 59) (unifiedImageResult 60)
  , fixture "partition-parent" "illegal_disk_backing_alias_double_spend" "physical-partition" "PhysicalDiskOvercommit:disk" (partitionResult 49 basePartition) (partitionResult 50 basePartition)
  , fixture "partition-carve-alias" "illegal_disk_backing_alias_double_spend" "physical-partition" "DiskBackingAlias:raw" (partitionResult 100 aliasPartition) (partitionResult 50 basePartition)
  , fixture "partition-unit-mismatch" "illegal_disk_backing_alias_double_spend" "physical-partition" "DiskExtentUnitMismatch:raw" (partitionResult 100 mismatchedPartition) (partitionResult 50 basePartition)
  , fixture "filesystem-layout-alias" "illegal_filesystem_layout_alias" "layout" "FilesystemLayoutMismatch" (layoutAliasResult True) (layoutAliasResult False)
  , fixture "filesystem-layout-swapped" "illegal_filesystem_layout_swapped" "layout-observation" "FilesystemLayoutMismatch" swappedLayoutResult matchingLayoutResult
  , fixture "image-content-join" "illegal_image_content_join_missing" "image-metadata" "ImageMetadataMissing:sha-index" (imageCatalogResult (imageCatalog {imageStoredObjects = Map.delete "sha-index" (imageStoredObjects imageCatalog)})) (imageCatalogResult imageCatalog)
  , fixture "image-manifest-join" "illegal_image_content_join_missing" "image-metadata" "ImageMetadataMissing:artifact:platform-manifest" (imageCatalogResult (imageCatalog {imagePlatformManifests = Map.empty})) (imageCatalogResult imageCatalog)
  , fixture "image-snapshot-join" "illegal_image_snapshot_join_missing" "image-metadata" "ImageMetadataMissing:snap-a" (imageCatalogResult (imageCatalog {imageSnapshotBytes = Map.empty})) (imageCatalogResult imageCatalog)
  , fixture "image-storage-model" "illegal_image_storage_model_missing" "image-metadata" "ImageMetadataMissing:model-v1" (imageCatalogResult (imageCatalog {imageStorageModels = Set.empty})) (imageCatalogResult imageCatalog)
  , fixture "split-image-containerd-v1" "illegal_split_image_unsupported" "layout" "SplitImageUnsupported" splitImageUnsupported splitImageSupported
  , fixture "instance-store-root" "illegal_provider_instance_store_root_underprovisioned" "provider-root" "ProviderInstanceStoreRootUnderprovisioned" (providerInstanceResult 49) (providerInstanceResult 50)
  , fixture "root-ebs-bytes-quota" "illegal_provider_node_root_ebs_over_quota" "provider-root" "ProviderNodeRootQuotaExceeded" (providerEbsResult 63 1) (providerEbsResult 64 1)
  , fixture "root-ebs-volume-quota" "illegal_provider_node_root_ebs_over_quota" "provider-root" "ProviderNodeRootQuotaExceeded" (providerEbsResult 64 0) (providerEbsResult 64 1)
  , fixture "etcd-transition-physical" "illegal_control_plane_storage_transition_overrun" "etcd" "EngineStorageOvercommit:etcd" (etcdResult 134) (etcdResult 135)
  , fixture "cuda-family-absent" "illegal_cuda_on_cpu_target" "accelerator" "AcceleratorFamilyAbsent:CudaFamily" cudaFamilyAbsent acceleratorFit
  , fixture "cuda-device-count" "illegal_accelerator_count_shortage" "accelerator" "AcceleratorDeviceCountShortage" acceleratorCountShort acceleratorFit
  , fixture "cuda-unsharded-fragmentation" "illegal_accelerator_vram_fragmentation" "accelerator" "AcceleratorResidencyFit" acceleratorFragmented acceleratorFit
  , fixture "cuda-shard-byte-sum" "illegal_accelerator_vram_fragmentation" "accelerator" "AcceleratorShardInvalid" acceleratorBadShard acceleratorShardedFit
  , fixture "cuda-vram-reserve" "illegal_accelerator_vram_reserve_boundary" "accelerator" "AcceleratorNetAllocatableViolation" acceleratorReserveBroken acceleratorFit
  , fixture "metal-profile" "illegal_apple_metal_profile_mismatch" "accelerator" "AcceleratorProfileMismatch" metalProfileMismatch metalProfileFit
  , fixture "accelerator-shared-owner" "illegal_shared_accelerator_double_owner" "accelerator-owner" "AcceleratorSharedDevice:cuda-a" sharedOwnerResult distinctOwnerResult
  ]

phase9PositiveRows :: [(Text, Either Text ())]
phase9PositiveRows = fmap (\(name, outcome) -> (name, resultText outcome)) phase9ComposedWitnessRows

phase9ComposedWitnessRows :: [(Text, Either Text ComposedPlacementWitness)]
phase9ComposedWitnessRows =
  [ ("legal_multisubstrate_cluster", composedPositive "legal_multisubstrate_cluster" 1)
  , ("legal_managed_eks", composedPositive "legal_managed_eks" 2)
  ]

runPhase9DeterministicChecks :: IO ()
runPhase9DeterministicChecks = do
  let controllerUnits =
        [ BoundExecutionUnit "stateful" 1 baseEnvelope (StatefulSetBody 2 StatefulSetNativeSerial)
        , BoundExecutionUnit "daemon" 1 baseEnvelope (DaemonSetBody ["node-a", "node-b"] (DaemonSetSurge 1))
        , BoundExecutionUnit "job" 1 baseEnvelope (JobBody 3 2 1 1)
        , BoundExecutionUnit "host" 1 baseEnvelope (HostProcessBody ["host-a", "host-b"] "observed-disappearance")
        ]
  assertCheck (plainRight (resultExecution (provisionExecutionEpochs Map.empty (resources 100 100 100 100) (BoundExecutionInventory FirstDeployment controllerUnits)))) "non-Deployment controller expansion rejected"
  assertCheck (isLeftExecution (mkRollingUpdate 0 0)) "zero-progress Deployment policy was admitted"
  let snapshot =
        SchedulerSnapshot
          "fresh"
          1
          (SchedulerSupply (resources 4 10 10 10) (Map.singleton "csi" 2) (Set.singleton "cuda-a"))
          []
          []
          []
          []
  case provisionSchedulingGuard "fresh" snapshot (CandidateReservation baseReservation) of
    Left problem -> fail ("scheduler guard rejected deterministic transition check: " <> show problem)
    Right guard -> do
      let reservedRow = ReservationLedgerRow baseReservation Reserved False
      binding <- case beginBinding guard reservedRow of
        Left problem -> fail ("Reserved→BindingInFlight rejected: " <> show problem)
        Right value -> pure value
      assertCheck (ledgerReservationState binding == BindingInFlight) "BindingInFlight transition lost its state"
      assertCheck (reservationReserved (ledgerOnlyAbsentRecovery binding) == reservationReserved baseReservation) "absent BindingInFlight row received release credit"
      bound <- case confirmBound guard binding of
        Left problem -> fail ("BindingInFlight→Bound rejected: " <> show problem)
        Right value -> pure value
      assertCheck (ledgerReservationState bound == Bound && ledgerPodPresent bound) "Bound confirmation did not retain observed presence"
  let partition = HostReservationPartition (resources 1 1 1 1) 10 5 3
      host = mkHostReservation "worker" partition partition
      retained = HostReservationPartition zeroResources 10 5 3
  case releaseHostReservation host retained of
    Left problem -> fail ("host retained release rejected: " <> show problem)
    Right released -> assertCheck (hostReservationTotal released == retained) "host release failed to retain physical artifacts"
  image <- case provisionNodeImageStorage imageCatalog imageDemand of
    Left problem -> fail ("image setup rejected: " <> show problem)
    Right value -> pure value
  let observedDemand = metadataDemand {runtimeAccountingId = ObservedPodUid "uid-1" "reservation-1"}
      observedScope = ObservedInventoryScope "snapshot" (Set.singleton "observed:uid-1")
  assertCheck (plainRight (provisionNodeRuntimeStorageAccounting (Map.singleton "v1" metadataModel) observedScope (Unified (LocalBacking "root" 1000)) [observedDemand] image)) "observed Pod UID runtime accounting rejected"
  let replicatedDemand =
        AcceleratorDemand
          "cluster"
          CudaFamily
          "a10"
          (Set.fromList ["cuda-a", "cuda-b"])
          2
          (Set.singleton "model")
          (Set.singleton "serving")
          [AcceleratorCoexistenceEpoch "replicated" [AcceleratorResidencyDemand "weights" "model" "serving" 5 ReplicatedPerDevice FullyConnectedPeerAccess]]
  assertCheck (plainRight (provisionAccelerator acceleratorOffering replicatedDemand)) "replicated/interconnected residency rejected"
  let build = BuildExecutionEnvelope [BuildStageDemand "compile" (resources 2 3 0 0) 4 5, BuildStageDemand "link" (resources 3 2 0 0) 6 4] 2 2 10 30
      engine = EngineSystemReserve "control-plane" [EngineProcessDemand "kubelet" (resources 1 2 0 0), EngineProcessDemand "rke2" (resources 2 1 0 0)] 10 10
      monitoring = MonitoringWorkBudget 1 2 3 4 2 5 6 1 2 10 5 15
      pulumi = PulumiExecutionDemand (resources 1 1 1 0) [resources 1 1 0 0] 2 10
  assertCheck (plainRight (provisionBuildExecution build)) "build execution derivation rejected"
  assertCheck (plainRight (provisionEngineSystemReserve engine)) "engine reserve derivation rejected"
  assertCheck (plainRight (provisionMonitoringWork monitoring)) "monitoring work derivation rejected"
  assertCheck (plainRight (provisionPulumiExecution pulumi)) "Pulumi executor derivation rejected"
  root0 <- rootFor 0
  root1 <- rootFor 1
  assertCheck (provisionedPerInstanceIdentity root0 /= provisionedPerInstanceIdentity root1) "provider cover slots reused a concrete root identity"
 where
  rootFor slot = case provisionPerInstanceDiskTemplate "cluster" "class" slot providerDemand (InstanceStore 50 BlockPresentation (BackingAllocationPolicy 0 1)) of
    Left problem -> fail ("provider identity check rejected: " <> show problem)
    Right value -> pure value
  assertCheck condition message = unless condition (fail message)

fixture :: Text -> Text -> Text -> Text -> Either Text () -> Either Text () -> Phase9Fixture
fixture variant family operation expected negative positive =
  Phase9Fixture variant family operation expected ("legal_" <> variant) (catalogFor family) negative positive

catalogFor :: Text -> Text
catalogFor family
  | family `elem` ["illegal_cuda_on_cpu_target", "illegal_accelerator_count_shortage", "illegal_shared_accelerator_double_owner"] = "3.28:accelerator-owner"
  | "accelerator" `textIn` family || "metal" `textIn` family || "cuda" `textIn` family = "3.30:accelerator-memory-fit"
  | otherwise = "3.17:capacity-accounting"

deploymentOne, deploymentRolling :: BoundExecutionUnit
deploymentOne = BoundExecutionUnit "api" 1 baseEnvelope (DeploymentBody 2 recreateRollout)
deploymentRolling = BoundExecutionUnit "api" 1 baseEnvelope (DeploymentBody 2 rollingOne)

rollingOne :: DeploymentRollout
rollingOne = case mkRollingUpdate 1 0 of
  Left _ -> recreateRollout
  Right value -> value

executionResult :: Natural -> BoundExecutionUnit -> Either Text ()
executionResult cpu unit = resultExecution (provisionExecutionEpochs Map.empty (resources cpu 20 20 10) (BoundExecutionInventory FirstDeployment [unit]))

executionUpdateResult :: Natural -> Either Text ()
executionUpdateResult cpu = do
  let priorUnit = deploymentOne {executionBody = DeploymentBody 1 recreateRollout}
  prior <- firstExecution (provisionExecutionEpochs Map.empty (resources 10 20 20 10) (BoundExecutionInventory FirstDeployment [priorUnit]))
  let provision = PriorExecutionProvision "prior" (provisionedDesiredSteady prior)
      desired = priorUnit {executionRevision = 2}
  resultExecution (provisionExecutionEpochs (Map.singleton "prior" provision) (resources cpu 20 20 10) (BoundExecutionInventory (UpdateFrom "prior") [desired]))

schedulerCapacityResult :: Natural -> Either Text ()
schedulerCapacityResult cpu = schedulerResult cpu "fresh" baseReservation

schedulerSnapshotResult :: Text -> Either Text ()
schedulerSnapshotResult fingerprint = schedulerResult 4 fingerprint baseReservation

schedulerProjectionResult :: Bool -> Either Text ()
schedulerProjectionResult broken = schedulerResult 4 "fresh" candidate
 where
  candidate = if broken then baseReservation {reservationReserved = resources 3 1 1 1} else baseReservation

schedulerResult :: Natural -> Text -> CompleteResourceReservation -> Either Text ()
schedulerResult cpu expected candidate = resultScheduler (provisionSchedulingGuard expected snapshot (CandidateReservation candidate))
 where
  snapshot =
    SchedulerSnapshot
      "fresh"
      1
      (SchedulerSupply (resources cpu 10 10 10) (Map.singleton "csi" 2) (Set.singleton "cuda-a"))
      []
      []
      []
      [ReservationLedgerRow baseReservation Bound True]

baseReservation :: CompleteResourceReservation
baseReservation = case mkCompleteReservation "pod" baseEnvelope Set.empty [ContentExtent "node" "image" 10] Set.empty of
  Left _ -> CompleteResourceReservation "pod" (resources 2 1 1 1) zeroResources (resources 2 1 1 1) Set.empty [] Set.empty
  Right value -> value

runtimeLayoutResult :: Natural -> Natural -> Either Text ()
runtimeLayoutResult nodeBytes runtimeBytes = runtimeResult (Map.singleton "v1" metadataModel) (PlannedEpochScope "epoch" (Set.singleton "planned:slot-0")) (SplitRuntime (LocalBacking "nodefs" nodeBytes) (LocalBacking "runtime" runtimeBytes))

runtimeModelResult :: Map Text KubeletRuntimeMetadataModel -> Either Text ()
runtimeModelResult models = runtimeResult models (PlannedEpochScope "epoch" (Set.singleton "planned:slot-0")) (SplitRuntime (LocalBacking "nodefs" 5) (LocalBacking "runtime" 62))

runtimeScopeResult :: Set.Set Text -> Either Text ()
runtimeScopeResult domain = runtimeResult (Map.singleton "v1" metadataModel) (PlannedEpochScope "epoch" domain) (SplitRuntime (LocalBacking "nodefs" 5) (LocalBacking "runtime" 62))

runtimeResult :: Map Text KubeletRuntimeMetadataModel -> RuntimeAccountingScope -> KubeletFilesystemLayout -> Either Text ()
runtimeResult models scope layout = do
  image <- firstNodeLocal (provisionNodeImageStorage imageCatalog imageDemand)
  resultRuntime (provisionNodeRuntimeStorageAccounting models scope layout [metadataDemand] image)

unifiedImageResult :: Natural -> Either Text ()
unifiedImageResult bytes = do
  image <- firstNodeLocal (provisionNodeImageStorage imageCatalog imageDemand)
  resultNodeLocal (fitLayoutComponents (Unified (LocalBacking "unified" bytes)) (provisionedImageComponents image))

basePartition :: PhysicalDiskPartition
basePartition = PhysicalDiskPartition "disk" 50 10 [baseVm] [rawCarve]

aliasPartition :: PhysicalDiskPartition
aliasPartition = PhysicalDiskPartition "disk" 100 10 [baseVm] [rawCarve, rawCarve]

mismatchedPartition :: PhysicalDiskPartition
mismatchedPartition = PhysicalDiskPartition "disk" 100 10 [] [rawCarve {namedDiskCarveKind = VmGuestUsableExtent "vm"}]

baseVm :: VmDiskCarve
baseVm = VmDiskCarve "vm" 10 BlockPresentation (BackingAllocationPolicy 0 1) [guestCarve]

guestCarve :: NamedDiskCarve
guestCarve = NamedDiskCarve "guest" (VmGuestUsableExtent "vm") 10 BlockPresentation (BackingAllocationPolicy 0 1)

rawCarve :: NamedDiskCarve
rawCarve = NamedDiskCarve "raw" PhysicalRawExtent 20 BlockPresentation (BackingAllocationPolicy 0 1)

partitionResult :: Natural -> PhysicalDiskPartition -> Either Text ()
partitionResult capacity partition = resultNodeLocal (provisionPhysicalDiskPartition partition {physicalDiskAllocatableRawBytes = capacity})

layoutAliasResult :: Bool -> Either Text ()
layoutAliasResult aliased = resultNodeLocal (fitLayoutComponents layout [NodeStorageComponent "component" KubeletNodefs 1])
 where
  runtimeId = if aliased then "nodefs" else "runtime"
  layout = SplitRuntime (LocalBacking "nodefs" 1) (LocalBacking runtimeId 1)

swappedLayoutResult, matchingLayoutResult :: Either Text ()
swappedLayoutResult = resultNodeLocal (validateFilesystemLayoutObservation declared observed)
matchingLayoutResult = resultNodeLocal (validateFilesystemLayoutObservation declared declared)

declared, observed :: KubeletFilesystemLayout
declared = SplitRuntime (LocalBacking "nodefs" 10) (LocalBacking "runtime" 10)
observed = SplitRuntime (LocalBacking "runtime" 10) (LocalBacking "nodefs" 10)

imageCatalogResult :: ImageMetadataCatalog -> Either Text ()
imageCatalogResult catalog = resultNodeLocal (provisionNodeImageStorage catalog imageDemand)

splitImageUnsupported, splitImageSupported :: Either Text ()
splitImageUnsupported = resultNodeLocal (fitLayoutComponents (SplitImage ContainerdV1 (LocalBacking "nodefs" 10) (LocalBacking "image" 10)) [])
splitImageSupported = resultNodeLocal (fitLayoutComponents (SplitImage ContainerdV2 (LocalBacking "nodefs" 10) (LocalBacking "image" 10)) [])

providerDemand :: PerInstanceDiskDemand
providerDemand = PerInstanceDiskDemand 20 [ProviderUsableDiskCarveTemplate "kubelet" 30]

providerInstanceResult :: Natural -> Either Text ()
providerInstanceResult bytes = resultProvider (provisionPerInstanceDiskTemplate "cluster" "class" 0 providerDemand (InstanceStore bytes BlockPresentation (BackingAllocationPolicy 0 1)))

providerEbsResult :: Natural -> Natural -> Either Text ()
providerEbsResult bytes volumes = resultProvider (provisionPerInstanceDiskTemplate "cluster" "class" 0 providerDemand (EphemeralRootEbs "gp3" (FilesystemPresentation "ext4-v1" 1000) (BackingAllocationPolicy 0 64) (NodeRootQuota bytes volumes)))

baseEtcdLogical :: EtcdLogicalDemand
baseEtcdLogical = EtcdLogicalDemand 20 10 10 5 5 10 60

baseEtcdModel :: EtcdStorageModel
baseEtcdModel = EtcdStorageModel 10 2 5 5 1 10 5 10 10 1 5 135

etcdResult :: Natural -> Either Text ()
etcdResult capacity = resultEtcd (provisionEtcdDemand baseEtcdLogical baseEtcdModel {etcdSystemCarveBytes = capacity})

acceleratorOffering :: AcceleratorOffering
acceleratorOffering = AcceleratorOffering (Map.fromList [(acceleratorDeviceId cudaA, cudaA), (acceleratorDeviceId cudaB, cudaB)])

cudaA, cudaB :: AcceleratorDevice
cudaA = AcceleratorDevice "cuda-a" CudaFamily "a10" 24 4 20 (Set.singleton "cuda-b") (Set.singleton "cuda-b")
cudaB = AcceleratorDevice "cuda-b" CudaFamily "a10" 24 4 20 (Set.singleton "cuda-a") (Set.singleton "cuda-a")

acceleratorDemand :: Natural -> Set.Set Text -> ResidencyPlacement -> Natural -> AcceleratorDemand
acceleratorDemand count devices placement bytes =
  AcceleratorDemand
    "cluster"
    CudaFamily
    "a10"
    devices
    count
    (Set.singleton "model")
    (Set.singleton "serving")
    [AcceleratorCoexistenceEpoch "serve" [AcceleratorResidencyDemand "weights" "model" "serving" bytes placement NoPeerRequirement]]

acceleratorFit, acceleratorCountShort, acceleratorFragmented, acceleratorBadShard, acceleratorShardedFit, acceleratorReserveBroken :: Either Text ()
acceleratorFit = resultAccelerator (provisionAccelerator acceleratorOffering (acceleratorDemand 1 (Set.singleton "cuda-a") Unsharded 20))
acceleratorCountShort = resultAccelerator (provisionAccelerator acceleratorOffering (acceleratorDemand 2 (Set.singleton "cuda-a") Unsharded 20))
acceleratorFragmented = resultAccelerator (provisionAccelerator acceleratorOffering (acceleratorDemand 2 (Set.fromList ["cuda-a", "cuda-b"]) Unsharded 21))
acceleratorBadShard = resultAccelerator (provisionAccelerator acceleratorOffering (acceleratorDemand 2 (Set.fromList ["cuda-a", "cuda-b"]) (Sharded [VramShardAssignment "a" "cuda-a" 9, VramShardAssignment "b" "cuda-b" 10]) 20))
acceleratorShardedFit = resultAccelerator (provisionAccelerator acceleratorOffering (acceleratorDemand 2 (Set.fromList ["cuda-a", "cuda-b"]) (Sharded [VramShardAssignment "a" "cuda-a" 10, VramShardAssignment "b" "cuda-b" 10]) 20))
acceleratorReserveBroken = resultAccelerator (provisionAccelerator (AcceleratorOffering (Map.singleton "cuda-a" cudaA {acceleratorDriverRuntimeReserveBytes = 5})) (acceleratorDemand 1 (Set.singleton "cuda-a") Unsharded 20))

cudaFamilyAbsent :: Either Text ()
cudaFamilyAbsent = resultAccelerator (provisionAccelerator (AcceleratorOffering (Map.singleton "cuda-a" cudaA {acceleratorDeviceFamily = AppleMetalFamily})) (acceleratorDemand 1 (Set.singleton "cuda-a") Unsharded 1))

metalDevice :: AcceleratorDevice
metalDevice = AcceleratorDevice "metal" AppleMetalFamily "m3-max" 64 4 60 Set.empty Set.empty

metalDemand :: Text -> AcceleratorDemand
metalDemand profile =
  AcceleratorDemand "metal-host" AppleMetalFamily profile (Set.singleton "metal") 1 (Set.singleton "model") (Set.singleton "serving") [AcceleratorCoexistenceEpoch "serve" [AcceleratorResidencyDemand "weights" "model" "serving" 20 Unsharded NoPeerRequirement]]

metalProfileMismatch, metalProfileFit :: Either Text ()
metalProfileMismatch = resultAccelerator (provisionAccelerator (AcceleratorOffering (Map.singleton "metal" metalDevice)) (metalDemand "m2-ultra"))
metalProfileFit = resultAccelerator (provisionAccelerator (AcceleratorOffering (Map.singleton "metal" metalDevice)) (metalDemand "m3-max"))

sharedOwnerResult, distinctOwnerResult :: Either Text ()
sharedOwnerResult = resultAccelerator (validateExclusiveAcceleratorOwners [("cluster-a", Set.singleton "cuda-a"), ("cluster-b", Set.singleton "cuda-a")])
distinctOwnerResult = resultAccelerator (validateExclusiveAcceleratorOwners [("cluster-a", Set.singleton "cuda-a"), ("cluster-b", Set.singleton "cuda-b")])

imageCatalog :: ImageMetadataCatalog
imageCatalog =
  ImageMetadataCatalog
    (Map.fromList [("sha-index", 10), ("sha-manifest", 10), ("sha-config", 10), ("sha-layer", 10)])
    (Map.singleton ("sha-index", "linux-amd64") "sha-manifest")
    (Map.singleton "sha-manifest" "sha-config")
    (Map.singleton "sha-manifest" ["sha-layer"])
    (Map.singleton "snap-a" 10)
    (Set.singleton "model-v1")

imageDemand :: NodeImageStorageDemand
imageDemand =
  NodeImageStorageDemand
    "model-v1"
    [ImageArtifactRequirement "artifact" "linux-amd64" "sha-index" "sha-manifest" "sha-config" ["sha-layer"] ["snap-a"]]
    Set.empty
    1
    (Map.singleton "artifact" 10)

metadataModel :: KubeletRuntimeMetadataModel
metadataModel = KubeletRuntimeMetadataModel 1 1 1 1 1 1 1

metadataDemand :: KubeletRuntimeMetadataDemand
metadataDemand = KubeletRuntimeMetadataDemand (PlannedExecutionSlotId "slot-0") "v1" source
 where
  source = PodRuntimeMetadataSource (Set.singleton "container") (Set.singleton "volume") (Set.singleton ("container", "volume")) (Set.singleton "network")

composedPositive :: Text -> Natural -> Either Text ComposedPlacementWitness
composedPositive name roots = do
  (topology, workloads, _) <- findPositive name positiveCases
  envelope <- case workloads of
    [] -> Left "positive workload inventory is empty"
    workload : _ -> Right (workloadEnvelope workload)
  execution <- firstExecution (provisionExecutionEpochs Map.empty (resources 100 100 100 100) (BoundExecutionInventory FirstDeployment [BoundExecutionUnit "positive" 1 envelope (DeploymentBody (fromIntegral (length workloads)) recreateRollout)]))
  image <- firstNodeLocal (provisionNodeImageStorage imageCatalog imageDemand)
  runtime <- firstRuntime (provisionNodeRuntimeStorageAccounting (Map.singleton "v1" metadataModel) (PlannedEpochScope "epoch" (Set.singleton "planned:slot-0")) (Unified (LocalBacking "node-root" 1000)) [metadataDemand] image)
  storage <- firstStorage (fitBacking (StorageBacking (BackingId "durable") 100 (BackingAllocationPolicy 0 1)) 50)
  accelerator <- firstAccelerator (provisionAccelerator acceleratorOffering NoAcceleratorDemand)
  rootWitnesses <- mapM provisionRoot (naturalOrdinals roots)
  firstComposed (placeFullResourceVector (ComposedPlacementInput topology workloads execution [runtime] [storage] [accelerator] rootWitnesses))
 where
  provisionRoot slot = firstProvider (provisionPerInstanceDiskTemplate "cluster" "class" slot providerDemand (InstanceStore 50 BlockPresentation (BackingAllocationPolicy 0 1)))

findPositive :: Text -> [(Text, Either Text value)] -> Either Text value
findPositive name rows = case rows of
  [] -> Left ("missing positive: " <> name)
  (candidate, outcome) : rest
    | candidate == name -> outcome
    | otherwise -> findPositive name rest

baseEnvelope :: ResourceEnvelope
baseEnvelope = case mkResourceEnvelope (resources 2 1 1 1) (resources 2 1 1 1) zeroResources of
  Left _ -> case mkResourceEnvelope zeroResources zeroResources zeroResources of
    Left _ -> baseEnvelope
    Right value -> value
  Right value -> value

naturalOrdinals :: Natural -> [Natural]
naturalOrdinals amount = go 0 amount
 where
  go next remaining
    | remaining == 0 = []
    | otherwise = next : go (next + 1) (remaining - 1)

textIn :: Text -> Text -> Bool
textIn = Text.isInfixOf

resultExecution :: Either ExecutionError value -> Either Text ()
resultExecution = resultBy executionTag

firstExecution :: Either ExecutionError value -> Either Text value
firstExecution = firstBy executionTag

resultScheduler :: Either SchedulerError value -> Either Text ()
resultScheduler = resultBy schedulerTag

resultNodeLocal :: Either NodeLocalStorageError value -> Either Text ()
resultNodeLocal = resultBy nodeLocalTag

firstNodeLocal :: Either NodeLocalStorageError value -> Either Text value
firstNodeLocal = firstBy nodeLocalTag

resultRuntime :: Either RuntimeStorageError value -> Either Text ()
resultRuntime = resultBy runtimeTag

firstRuntime :: Either RuntimeStorageError value -> Either Text value
firstRuntime = firstBy runtimeTag

resultProvider :: Either ProviderRootError value -> Either Text ()
resultProvider = resultBy providerTag

firstProvider :: Either ProviderRootError value -> Either Text value
firstProvider = firstBy providerTag

resultEtcd :: Either EtcdError value -> Either Text ()
resultEtcd = resultBy etcdTag

resultAccelerator :: Either AcceleratorError value -> Either Text ()
resultAccelerator = resultBy acceleratorTag

firstAccelerator :: Either AcceleratorError value -> Either Text value
firstAccelerator = firstBy acceleratorTag

firstStorage :: Show problem => Either problem value -> Either Text value
firstStorage outcome = case outcome of
  Left problem -> Left ("storage:" <> textShow problem)
  Right value -> Right value

firstComposed :: Show problem => Either problem value -> Either Text value
firstComposed outcome = case outcome of
  Left problem -> Left ("composed:" <> textShow problem)
  Right value -> Right value

resultText :: Either Text value -> Either Text ()
resultText outcome = case outcome of
  Left problem -> Left problem
  Right _ -> Right ()

resultBy :: (problem -> Text) -> Either problem value -> Either Text ()
resultBy tag outcome = case outcome of
  Left problem -> Left (tag problem)
  Right _ -> Right ()

firstBy :: (problem -> Text) -> Either problem value -> Either Text value
firstBy tag outcome = case outcome of
  Left problem -> Left (tag problem)
  Right value -> Right value

executionTag :: ExecutionError -> Text
executionTag problem = case problem of
  InvalidExecutionPolicy _ -> "InvalidExecutionPolicy"
  DuplicateExecutionUnit _ -> "DuplicateExecutionUnit"
  PriorExecutionMissing _ -> "PriorExecutionMissing"
  PriorExecutionReferenceMismatch {} -> "PriorExecutionReferenceMismatch"
  ExecutionIdentityMismatch _ -> "ExecutionIdentityMismatch"
  ExecutionOvercommit _ axis _ _ -> "Overcommit:" <> axisTag axis

schedulerTag :: SchedulerError -> Text
schedulerTag problem = case problem of
  ReservationProjectionMismatch _ -> "ReservationProjectionMismatch"
  SchedulerSnapshotChanged {} -> "SchedulerSnapshotChanged"
  SchedulerCapacityExceeded axis _ _ -> "SchedulerCapacityExceeded:" <> axisTag axis
  SchedulerCsiExceeded {} -> "SchedulerCsiExceeded"
  SchedulerContentConflict {} -> "SchedulerContentConflict"
  SchedulerDeviceConflict _ -> "SchedulerDeviceConflict"
  SchedulerDeviceMissing _ -> "SchedulerDeviceMissing"
  SchedulerStateTransitionInvalid {} -> "SchedulerStateTransitionInvalid"

nodeLocalTag :: NodeLocalStorageError -> Text
nodeLocalTag problem = case problem of
  FilesystemLayoutMismatch _ -> "FilesystemLayoutMismatch"
  ImageMetadataMissing identity -> "ImageMetadataMissing:" <> identity
  ImageMetadataConflict identity -> "ImageMetadataConflict:" <> identity
  SplitImageUnsupported _ -> "SplitImageUnsupported"
  NodeLocalStorageOverBacking identity _ _ -> "NodeLocalStorageOverBacking:" <> identity
  NodeStorageComponentDuplicate identity -> "NodeStorageComponentDuplicate:" <> identity
  DiskBackingAlias identity -> "DiskBackingAlias:" <> identity
  DiskExtentUnitMismatch identity _ -> "DiskExtentUnitMismatch:" <> identity
  VmGuestStorageOvercommit identity _ _ -> "VmGuestStorageOvercommit:" <> identity
  PhysicalDiskOvercommit identity _ _ -> "PhysicalDiskOvercommit:" <> identity

runtimeTag :: RuntimeStorageError -> Text
runtimeTag problem = case problem of
  RuntimeMetadataModelMissing model -> "RuntimeMetadataModelMissing:" <> model
  RuntimeMetadataSourceInvalid _ -> "RuntimeMetadataSourceInvalid"
  RuntimeAccountingDomainMismatch {} -> "RuntimeAccountingDomainMismatch"
  RuntimeAccountingScopeMismatch {} -> "RuntimeAccountingScopeMismatch"
  RuntimeComponentOwnershipMismatch _ -> "RuntimeComponentOwnershipMismatch"
  RuntimeNodeLocalError nested -> nodeLocalTag nested

providerTag :: ProviderRootError -> Text
providerTag problem = case problem of
  ProviderRootCarveAlias _ -> "ProviderRootCarveAlias"
  ProviderInstanceStoreRootUnderprovisioned {} -> "ProviderInstanceStoreRootUnderprovisioned"
  ProviderNodeRootQuotaExceeded {} -> "ProviderNodeRootQuotaExceeded"
  ProviderRootIdentityInvalid _ -> "ProviderRootIdentityInvalid"

etcdTag :: EtcdError -> Text
etcdTag problem = case problem of
  EtcdLogicalQuotaExceeded {} -> "EtcdLogicalQuotaExceeded"
  EngineStorageOvercommit owner _ _ -> "EngineStorageOvercommit:" <> owner

acceleratorTag :: AcceleratorError -> Text
acceleratorTag problem = case problem of
  AcceleratorFamilyAbsent family -> "AcceleratorFamilyAbsent:" <> textShow family
  AcceleratorDeviceCountShortage {} -> "AcceleratorDeviceCountShortage"
  AcceleratorResidencyFit {} -> "AcceleratorResidencyFit"
  AcceleratorNetAllocatableViolation {} -> "AcceleratorNetAllocatableViolation"
  AcceleratorProfileMismatch {} -> "AcceleratorProfileMismatch"
  AcceleratorSharedDevice device _ _ -> "AcceleratorSharedDevice:" <> device
  AcceleratorDomainMismatch {} -> "AcceleratorDomainMismatch"
  AcceleratorShardInvalid {} -> "AcceleratorShardInvalid"
  AcceleratorInterconnectMissing {} -> "AcceleratorInterconnectMissing"
  AcceleratorDeviceMissing _ -> "AcceleratorDeviceMissing"

axisTag :: Axis -> Text
axisTag axis = case axis of
  CpuAxis -> "CpuAxis"
  MemoryAxis -> "MemoryAxis"
  EphemeralStorageAxis -> "EphemeralStorageAxis"
  PodSlotsAxis -> "PodSlotsAxis"
  CsiAttachmentsAxis _ -> "CsiAttachmentsAxis"
  InstanceCountAxis -> "InstanceCountAxis"
  VcpuQuotaAxis -> "VcpuQuotaAxis"
  ClassMaximumAxis _ -> "ClassMaximumAxis"

textShow :: Show value => value -> Text
textShow = Text.pack . show

plainRight :: Either problem value -> Bool
plainRight outcome = case outcome of
  Left _ -> False
  Right _ -> True

isLeftExecution :: Either ExecutionError value -> Bool
isLeftExecution outcome = case outcome of
  Left _ -> True
  Right _ -> False
