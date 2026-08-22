{-# LANGUAGE OverloadedStrings #-}

module ExecutionAcceleratorProps
  ( runExecutionAcceleratorProps
  , validateComposedWitnessIndependent
  ) where

import Amoebius.Capacity.Accelerator (ResidencyPlacement (..), provisionAccelerator)
import Amoebius.Capacity.Composed (ComposedPlacementWitness (..))
import Amoebius.Capacity.Etcd (EtcdLogicalDemand (..), EtcdStorageModel (..), provisionEtcdDemand)
import Amoebius.Capacity.Execution
  ( BoundExecutionInventory (..)
  , BoundExecutionUnit (..)
  , ControllerBody (..)
  , ExecutionTransitionSource (..)
  , provisionExecutionEpochs
  , recreateRollout
  )
import Amoebius.Capacity.NodeLocalStorage
  ( KubeletFilesystemLayout (..)
  , LocalBacking (..)
  , NodeImageStorageDemand (..)
  , NodeStorageComponent (..)
  , NodeStorageRole (..)
  , ProvisionedNodeImageStorageDemand (..)
  , ProvisionedNodeLocalStorage (..)
  , fitLayoutComponents
  , provisionNodeImageStorage
  )
import Amoebius.Capacity.ProviderRoot
  ( NodeRootQuota (..)
  , PerInstanceDiskDemand (..)
  , ProviderRootPolicy (..)
  , ProviderUsableDiskCarveTemplate (..)
  , ProvisionedPerInstanceDiskTemplate (..)
  , provisionPerInstanceDiskTemplate
  )
import Amoebius.Capacity.RuntimeStorage (ProvisionedNodeRuntimeStorageAccounting (..))
import Amoebius.Capacity.Storage
  ( BackingAllocationPolicy (..)
  , FilesystemPresentation (..)
  , StorageAmount (..)
  , StorageWitness (..)
  )
import Amoebius.Capacity.Types
  ( Placement (..)
  , ResourceEnvelope
  , ResourceVector (..)
  , mkResourceEnvelope
  , zeroResources
  )
import Control.Monad (unless)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import ExecutionAcceleratorFixtures
  ( acceleratorDemand
  , acceleratorOffering
  , baseEtcdLogical
  , baseEtcdModel
  , imageCatalog
  , imageDemand
  , phase29ComposedWitnessRows
  )
import Numeric.Natural (Natural)
import Test.QuickCheck
  ( Arbitrary (arbitrary)
  , Args (chatty, maxSuccess)
  , Gen
  , Property
  , Result
  , Testable
  , checkCoverage
  , chooseInt
  , counterexample
  , cover
  , isSuccess
  , property
  , quickCheckWithResult
  , stdArgs
  )

data FitCase = FitCase Natural Bool Natural
  deriving stock (Show)

instance Arbitrary FitCase where
  arbitrary = FitCase <$> natural 1 40 <*> arbitrary <*> natural 1 20

runExecutionAcceleratorProps :: IO Int
runExecutionAcceleratorProps = do
  results <- sequence
    [ runProperty "prop_executionEpochEquivalence" propExecutionEpochEquivalence
    , runProperty "prop_imagePeakEquivalence" propImagePeakEquivalence
    , runProperty "prop_acceleratorResidencyEquivalence" propAcceleratorResidencyEquivalence
    , runProperty "prop_providerRootEquivalence" propProviderRootEquivalence
    , runProperty "prop_etcdTransitionEquivalence" propEtcdTransitionEquivalence
    , runProperty "prop_layoutGroupingEquivalence" propLayoutGroupingEquivalence
    , runProperty "prop_composedIndependentValidator" propComposedIndependentValidator
    ]
  let failed = [name | (name, result) <- results, not (isSuccess result)]
  unless (null failed) (fail ("Phase-29 properties failed: " <> show failed))
  putStrLn "execution-accelerator-properties: TESTED sampled (7) with >=30% accept/reject coverage on each decision fold"
  pure (length results)

propExecutionEpochEquivalence :: FitCase -> Property
propExecutionEpochEquivalence (FitCase replicas shouldFit margin) = decisionCoverage shouldFit outcome
 where
  required = replicas * 2
  available = capacityFor required shouldFit margin
  unit = BoundExecutionUnit "deployment" 1 baseEnvelope (DeploymentBody replicas recreateRollout)
  outcome = provisionExecutionEpochs Map.empty (ResourceVector available 100 100 100) (BoundExecutionInventory FirstDeployment [unit])

propImagePeakEquivalence :: FitCase -> Property
propImagePeakEquivalence (FitCase workspace shouldFit margin) = decisionCoverage shouldFit outcome
 where
  demand = imageDemand {nodePullWorkspaceBytes = Map.singleton "artifact" workspace}
  required = 50 + workspace
  available = capacityFor required shouldFit margin
  outcome = do
    provisioned <- provisionNodeImageStorage imageCatalog demand
    fitLayoutComponents (Unified (LocalBacking "image" available)) (provisionedImageComponents provisioned)

propAcceleratorResidencyEquivalence :: FitCase -> Property
propAcceleratorResidencyEquivalence (FitCase bytes shouldFit margin) = decisionCoverage shouldFit outcome
 where
  required = if shouldFit then min 20 bytes else 20 + margin
  outcome = provisionAccelerator acceleratorOffering (acceleratorDemand 1 (Set.singleton "cuda-a") Unsharded required)

propProviderRootEquivalence :: FitCase -> Property
propProviderRootEquivalence (FitCase usable shouldFit margin) = decisionCoverage shouldFit outcome
 where
  demand = PerInstanceDiskDemand usable [ProviderUsableDiskCarveTemplate "kubelet" usable]
  requiredUsable = usable * 2
  requiredRaw = roundIndependent (BackingAllocationPolicy 0 64) (presentIndependent (FilesystemPresentation "ext4-v1" 1000) requiredUsable)
  quota = capacityFor requiredRaw shouldFit margin
  outcome = provisionPerInstanceDiskTemplate "cluster" "class" 0 demand (EphemeralRootEbs "gp3" (FilesystemPresentation "ext4-v1" 1000) (BackingAllocationPolicy 0 64) (NodeRootQuota quota 1))

propEtcdTransitionEquivalence :: FitCase -> Property
propEtcdTransitionEquivalence (FitCase desired shouldFit margin) = decisionCoverage shouldFit outcome
 where
  logical = baseEtcdLogical {etcdDesiredObjectBytes = desired, etcdBackendQuotaBytes = desired + 40}
  requiredPhysical = etcdBackendQuotaBytes logical + referenceEtcdPhysicalExtras baseEtcdModel
  model = baseEtcdModel {etcdSystemCarveBytes = capacityFor requiredPhysical shouldFit margin}
  outcome = provisionEtcdDemand logical model

propLayoutGroupingEquivalence :: FitCase -> Property
propLayoutGroupingEquivalence (FitCase bytes shouldFit margin) = decisionCoverage shouldFit outcome
 where
  required = bytes * 2
  available = capacityFor required shouldFit margin
  components =
    [ NodeStorageComponent "pod:nodefs" KubeletNodefs bytes
    , NodeStorageComponent "pod:runtime" CriRuntimeRoot bytes
    ]
  outcome = fitLayoutComponents (Unified (LocalBacking "unified" available)) components

propComposedIndependentValidator :: Property
propComposedIndependentValidator =
  counterexample (show results) (property (all valid results))
 where
  results = fmap snd phase29ComposedWitnessRows
  valid outcome = case outcome of
    Left _ -> False
    Right witness -> validateComposedWitnessIndependent witness

validateComposedWitnessIndependent :: ComposedPlacementWitness -> Bool
validateComposedWitnessIndependent witness =
  vectorWithin (composedRequiredResources witness) (composedExecutionPeakResources witness)
    && fromIntegral (length (placementAssignments (composedBasePlacement witness))) == resourcePodSlots (composedRequiredResources witness)
    && all validatesStorage (composedStorageWitnesses witness)
    && all validatesRoot (composedProviderRootWitnesses witness)
    && all validatesRuntime (composedRuntimeStorageWitnesses witness)
 where
  validatesStorage storage =
    amountBytes (witnessRequired storage) + amountBytes (witnessResidual storage) == amountBytes (witnessAvailable storage)
      && amountObjects (witnessRequired storage) + amountObjects (witnessResidual storage) == amountObjects (witnessAvailable storage)
  validatesRoot root = provisionedPerInstanceRequiredUsableBytes root <= provisionedPerInstanceMountedUsableBytes root
  validatesRuntime runtime =
    let layout = provisionedRuntimeLayout runtime
     in Map.keysSet (provisionedBackingDebits layout) == Map.keysSet (provisionedBackingResiduals layout)

decisionCoverage :: Bool -> Either problem value -> Property
decisionCoverage shouldFit outcome = checkCoverage
  $ cover 30 shouldFit "accepted"
  $ cover 30 (not shouldFit) "rejected"
  $ counterexample (showDecision outcome) (property (isRight outcome == shouldFit))

capacityFor :: Natural -> Bool -> Natural -> Natural
capacityFor required shouldFit margin
  | shouldFit = required + margin
  | otherwise = required - min required (max 1 margin)

referenceEtcdPhysicalExtras :: EtcdStorageModel -> Natural
referenceEtcdPhysicalExtras model =
  etcdWalSegmentBytes model * etcdMaxWalFiles model
    + etcdWalOvershootBytes model
    + etcdPreallocatedNextWalBytes model
    + etcdRetainedSnapshots model * etcdSnapshotBytes model
    + etcdSnapshotSaveTemporaryBytes model
    + etcdDefragOldBytes model
    + etcdDefragNewBytes model
    + (etcdMaxBackups model + 1) * etcdMaxLogBytesPerFile model

presentIndependent :: FilesystemPresentation -> Natural -> Natural
presentIndependent presentation bytes = case presentation of
  BlockPresentation -> bytes
  FilesystemPresentation _ basisPoints -> bytes + ceilDiv (bytes * basisPoints) 10000

roundIndependent :: BackingAllocationPolicy -> Natural -> Natural
roundIndependent policy bytes =
  let atLeastMinimum = max bytes (allocationMinimumBytes policy)
      quantum = allocationQuantumBytes policy
   in if quantum == 0 then atLeastMinimum else ceilDiv atLeastMinimum quantum * quantum

vectorWithin :: ResourceVector -> ResourceVector -> Bool
vectorWithin required available =
  resourceCpu required <= resourceCpu available
    && resourceMemory required <= resourceMemory available
    && resourceEphemeralStorage required <= resourceEphemeralStorage available
    && resourcePodSlots required <= resourcePodSlots available

baseEnvelope :: ResourceEnvelope
baseEnvelope = case mkResourceEnvelope (ResourceVector 2 1 1 1) (ResourceVector 2 1 1 1) zeroResources of
  Left _ -> case mkResourceEnvelope zeroResources zeroResources zeroResources of
    Left _ -> baseEnvelope
    Right value -> value
  Right value -> value

isRight :: Either problem value -> Bool
isRight outcome = case outcome of
  Left _ -> False
  Right _ -> True

showDecision :: Either problem value -> String
showDecision outcome = case outcome of
  Left _ -> "rejected"
  Right _ -> "accepted"

ceilDiv :: Natural -> Natural -> Natural
ceilDiv numerator denominator
  | denominator == 0 = 0
  | otherwise = (numerator + denominator - 1) `div` denominator

natural :: Int -> Int -> Gen Natural
natural lower upper = fromIntegral <$> chooseInt (lower, upper)

runProperty :: Testable property => String -> property -> IO (String, Result)
runProperty name value = do
  result <- quickCheckWithResult stdArgs {maxSuccess = 300, chatty = False} value
  pure (name, result)
