{-# LANGUAGE OverloadedStrings #-}

module StorageGeometryProps
  ( runStorageGeometryProps
  , referenceBookKeeperBytes
  , referenceMinioBytes
  , referencePresentedAllocation
  ) where

import Amoebius.Capacity.ServiceStorage
  ( CacheAsset (..)
  , CachePlacement (..)
  , CachePopulationDemand (..)
  , provisionCacheDemand
  )
import Amoebius.Capacity.Storage
  ( BackingAllocationPolicy (..)
  , BackingId (..)
  , BudgetId (..)
  , FilesystemPresentation (..)
  , StorageBacking (..)
  , StorageBudget (..)
  )
import Amoebius.Capacity.StorageGeometry
  ( BookKeeperPolicy (..)
  , DeclaredVolumeDemand (..)
  , MinioPolicy (..)
  , PulsarDemand (..)
  , StatefulSetClaimSlot (..)
  , VolumeGeometry (..)
  , provisionPulsar
  , provisionVolume
  )
import Amoebius.Capacity.StorageScaling
  ( ObservedStorageScalingSnapshot (..)
  , mkProvisionedStorageScalingEnvelope
  , planStorageScaling
  )
import Control.Monad (unless)
import Numeric.Natural (Natural)
import StorageGeometryFixtures (backing, bookKeeperPolicy, minioPolicy)
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

data EnvelopeCase = EnvelopeCase Natural Bool Natural
  deriving stock (Show)

instance Arbitrary EnvelopeCase where
  arbitrary = EnvelopeCase <$> natural 1 100 <*> arbitrary <*> natural 1 40

data PulsarCase = PulsarCase Natural Bool Bool
  deriving stock (Show)

instance Arbitrary PulsarCase where
  arbitrary = PulsarCase <$> natural 1 100 <*> arbitrary <*> arbitrary

data ScalingCase = ScalingCase Bool Natural
  deriving stock (Show)

instance Arbitrary ScalingCase where
  arbitrary = ScalingCase <$> arbitrary <*> natural 1 80

runStorageGeometryProps :: IO Int
runStorageGeometryProps = do
  results <- sequence
    [ runProperty "prop_bookKeeperEquivalence" propBookKeeperEquivalence
    , runProperty "prop_minioEquivalence" propMinioEquivalence
    , runProperty "prop_presentationRoundingEquivalence" propPresentationRoundingEquivalence
    , runProperty "prop_cacheNestingEquivalence" propCacheNestingEquivalence
    , runProperty "prop_pulsarTwoCeilingEquivalence" propPulsarTwoCeilingEquivalence
    , runProperty "prop_scalingSnapshotEquivalence" propScalingSnapshotEquivalence
    ]
  let failed = [name | (name, result) <- results, not (isSuccess result)]
  unless (null failed) (fail ("storage geometry properties failed: " <> show failed))
  putStrLn "storage-properties: TESTED sampled (6) with >=30% accept/reject coverage"
  pure (length results)

propBookKeeperEquivalence :: EnvelopeCase -> Property
propBookKeeperEquivalence (EnvelopeCase logical shouldFit margin) = checkCoverage
  $ cover 30 shouldFit "in-backing"
  $ cover 30 (not shouldFit) "out-of-backing"
  $ counterexample (show result) (property (isRight result == shouldFit))
 where
  required = referenceBookKeeperBytes bookKeeperPolicy logical
  capacity = chooseCapacity required shouldFit margin
  demand = DeclaredVolumeDemand "bookkeeper-prop" (StatefulSetClaimSlot "bookkeeper" "journal" 0) (backing "bookkeeper-prop" capacity) logical (BookKeeperGeometry bookKeeperPolicy) BlockPresentation
  result = provisionVolume demand

propMinioEquivalence :: EnvelopeCase -> Property
propMinioEquivalence (EnvelopeCase logical shouldFit margin) = checkCoverage
  $ cover 30 shouldFit "in-backing"
  $ cover 30 (not shouldFit) "out-of-backing"
  $ counterexample (show result) (property (isRight result == shouldFit))
 where
  required = referenceMinioBytes minioPolicy logical
  capacity = chooseCapacity required shouldFit margin
  demand = DeclaredVolumeDemand "minio-prop" (StatefulSetClaimSlot "minio" "data" 0) (backing "minio-prop" capacity) logical (MinioGeometry minioPolicy) BlockPresentation
  result = provisionVolume demand

propPresentationRoundingEquivalence :: EnvelopeCase -> Property
propPresentationRoundingEquivalence (EnvelopeCase logical shouldFit margin) = checkCoverage
  $ cover 30 shouldFit "in-backing"
  $ cover 30 (not shouldFit) "out-of-backing"
  $ property (isRight (provisionVolume demand) == shouldFit)
 where
  presentation = FilesystemPresentation "ext4-v1" 1000
  policy = BackingAllocationPolicy 64 64
  required = referencePresentedAllocation presentation policy logical
  capacity = chooseCapacity required shouldFit margin
  owner = StorageBacking (BackingId "presentation-prop") capacity policy
  demand = DeclaredVolumeDemand "presentation-prop" (StatefulSetClaimSlot "presentation" "data" 0) owner logical (DirectGeometry 1) presentation

propCacheNestingEquivalence :: EnvelopeCase -> Property
propCacheNestingEquivalence (EnvelopeCase resident shouldFit margin) = checkCoverage
  $ cover 30 shouldFit "in-backing"
  $ cover 30 (not shouldFit) "out-of-backing"
  $ property (isRight (provisionCacheDemand population placement) == shouldFit)
 where
  temporary = margin
  peak = resident + temporary
  population = CachePopulationDemand "cache-prop" [CacheAsset "asset" "digest" resident temporary] 1
  budget = if shouldFit then peak else predecessor peak
  placement = InClusterCache budget (if shouldFit then budget else peak)

propPulsarTwoCeilingEquivalence :: PulsarCase -> Property
propPulsarTwoCeilingEquivalence (PulsarCase logical shouldFit durableFailure) = checkCoverage
  $ cover 30 shouldFit "both-ceilings-fit"
  $ cover 30 (not shouldFit) "a-ceiling-rejects"
  $ property (isRight (provisionPulsar demand) == shouldFit)
 where
  hotRequired = referenceBookKeeperBytes bookKeeperPolicy logical
  hotCapacity = if shouldFit || durableFailure then hotRequired else predecessor hotRequired
  durable = if shouldFit || not durableFailure then Just logical else Nothing
  demand = PulsarDemand "pulsar-prop" logical durable bookKeeperPolicy (backing "pulsar-prop" hotCapacity) (FixedBackingBudget (BudgetId "durable-prop") (BackingId "durable-prop") logical)

propScalingSnapshotEquivalence :: ScalingCase -> Property
propScalingSnapshotEquivalence (ScalingCase matching desiredDelta) = checkCoverage
  $ cover 30 matching "matching-snapshot"
  $ cover 30 (not matching) "stale-snapshot"
  $ case mkProvisionedStorageScalingEnvelope "fresh" (BackingId "scale-prop") desired 300 400 of
      Left problem -> counterexample (show problem) False
      Right envelope -> property (isRight (planStorageScaling envelope snapshot) == matching)
 where
  current = 100
  desired = current + desiredDelta
  fingerprint = if matching then "fresh" else "stale"
  snapshot = ObservedStorageScalingSnapshot fingerprint current 100 300 0

referenceBookKeeperBytes :: BookKeeperPolicy -> Natural -> Natural
referenceBookKeeperBytes policy logical =
  logical * bookKeeperWriteQuorum policy
    + bookKeeperEnsembleSize policy * bookKeeperJournalAndIndexBytesPerBookie policy
    + logical * bookKeeperFaultBound policy

referenceMinioBytes :: MinioPolicy -> Natural -> Natural
referenceMinioBytes policy logical = resident + metadata + healing + orphanAndInflight
 where
  dataShards = minioDataShards policy
  totalShards = dataShards + minioParityShards policy
  stripes = ceilDiv logical (dataShards * minioShardBlockBytes policy)
  resident = stripes * totalShards * minioShardBlockBytes policy
  metadata = minioErasureSets policy * totalShards * minioMetadataBytesPerDrive policy
  healing =
    minioErasureSets policy * minioFaultBoundPerSet policy * minioHealingWorkspaceBytesPerDrive policy
      + ceilDiv (resident * minioFaultBoundPerSet policy) dataShards
  orphanAndInflight =
    (minioConcurrentWriteSets policy + minioFailedWriteSets policy)
      * minioMaximumWriteSetBytes policy
      * totalShards
      `div` dataShards

referencePresentedAllocation :: FilesystemPresentation -> BackingAllocationPolicy -> Natural -> Natural
referencePresentedAllocation presentation policy logical = roundIndependent policy presented
 where
  presented = case presentation of
    BlockPresentation -> logical
    FilesystemPresentation _ basisPoints -> logical + ceilDiv (logical * basisPoints) 10000

roundIndependent :: BackingAllocationPolicy -> Natural -> Natural
roundIndependent policy bytes =
  let atLeastMinimum = max bytes (allocationMinimumBytes policy)
      quantum = allocationQuantumBytes policy
   in if quantum == 0 then atLeastMinimum else ceilDiv atLeastMinimum quantum * quantum

chooseCapacity :: Natural -> Bool -> Natural -> Natural
chooseCapacity required shouldFit margin
  | shouldFit = required + margin
  | otherwise = required - min required margin

predecessor :: Natural -> Natural
predecessor value = if value == 0 then 0 else value - 1

isRight :: Either a b -> Bool
isRight value = case value of
  Left _ -> False
  Right _ -> True

ceilDiv :: Natural -> Natural -> Natural
ceilDiv numerator denominator =
  if denominator == 0 then 0 else (numerator + denominator - 1) `div` denominator

natural :: Int -> Int -> Gen Natural
natural lower upper = fromIntegral <$> chooseInt (lower, upper)

runProperty :: Testable property => String -> property -> IO (String, Result)
runProperty name value = do
  result <- quickCheckWithResult stdArgs {maxSuccess = 300, chatty = False} value
  pure (name, result)
