{-# LANGUAGE OverloadedStrings #-}

module ObjectStoreSpec (verifyObjectStore) where

import Amoebius.Capacity.ObjectStore
import Amoebius.Capacity.Storage
import Amoebius.Capacity.StorageGeometry (GeometryWitness (..), MinioPolicy (..))
import Control.Monad (unless)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Numeric.Natural (Natural)
import System.Exit (die)

verifyObjectStore :: IO ()
verifyObjectStore = do
  let first = identity "a"
      second = identity "b"
      resident = Map.fromList [(first, 1), (second, 1)]
      base = demand "writer" resident
      sources = [RegistrySource base]
      expected = Set.singleton "writer"
  peak <- right (foldObjectStoreSources expected sources)
  require "exact physical identities retained" (objectStoreResidents peak == resident)
  geometry <- right (objectStoreMinioGeometry policy peak)
  require "individual objects each retain stripe padding"
    (Map.lookup "stripe-data-parity" (geometryComponents geometry) == Just 32768)
  require "every single-drive failure is retained"
    (Set.fromList (geometryFailureScenarios geometry) == Set.fromList [[], [0], [1], [2], [3]])
  require "every possible healing target gets its full incoming shard"
    (Map.lookup "healing" (geometryComponents geometry) == Just 65536)
  twoSets <- right (objectStoreMinioGeometry (policy {minioErasureSets = 2}) peak)
  require "multiple sets cannot average away per-drive demand"
    (geometryPhysicalBytes twoSets >= 2 * geometryPhysicalBytes geometry)
  require "cross-set Cartesian failure subsets are complete"
    (length (geometryFailureScenarios twoSets) == 25
      && [0, 7] `elem` geometryFailureScenarios twoSets && [3, 4] `elem` geometryFailureScenarios twoSets)

  let alias = base {objectSourceId = "alias"}
      both = Set.fromList ["writer", "alias"]
  shared <- right (foldObjectStoreSources both [RegistrySource base, RegistrySource alias])
  require "same physical resident debits once" (objectStoreLogicalBytes shared == 2)
  let conflicting = alias {objectSourceResidents = Map.singleton first 2}
  require "conflicting exact identities reject"
    (foldObjectStoreSources both [RegistrySource base, RegistrySource conflicting] == Left (ObjectByteConflict first 1 2))
  let foreignScope = base {objectSourceResidents = Map.singleton (first {physicalBucket = "other"}) 1}
  require "foreign bucket fails source-scope admission"
    (provisionObjectSource (RegistrySource foreignScope) == Left (ObjectOutsideSourceScope (first {physicalBucket = "other"})))
  let otherBucket = foreignScope {objectSourceId = "other-bucket", objectSourceScope = SourceScope "root-minio" "platform" "other"}
  separate <- right (foldObjectStoreSources (Set.fromList ["writer", "other-bucket"]) [RegistrySource base, RegistrySource otherBucket])
  require "same key in another bucket is another physical object" (objectStoreLogicalBytes separate == 3)
  require "undeclared producer rejects" (foldObjectStoreSources Set.empty sources == Left (SourceSetMismatch Set.empty expected))
  require "duplicate producer rejects" (foldObjectStoreSources expected (sources <> sources) == Left (DuplicateSourceId "writer"))

  let pending = ObjectPopulation "future" 2 3 0
      concurrent = ObjectPopulation "upload" 2 4 0
      lag = ObjectPopulation "old-versions" 3 5 30
      orphan = ObjectPopulation "failed-write-window" 2 7 60
      expanded = base {objectSourceFuture = [pending], objectSourceConcurrent = [concurrent],
                       objectSourceDeletionLag = [lag], objectSourceFailedOrphans = [orphan]}
  structural <- right (foldObjectStoreSources expected [RegistrySource expanded])
  require "all four structural populations stay charged" (objectStoreLogicalBytes structural == 45)
  require "future object count remains finite" (objectStoreLogicalObjectCount structural == 11)
  require "population shape survives the logical fold" (length (objectStorePopulations structural) == 4)
  require "failed history needs a finite retention window"
    (case provisionObjectSource (RegistrySource (expanded {objectSourceFailedOrphans = [orphan {populationWindowSeconds = 0}]})) of
      Left (InvalidObjectSource _) -> True
      _ -> False)

  let small = base {objectSourceBudget = FixedBackingBudget (BudgetId "budget") (BackingId "minio") 2}
      other = small {objectSourceId = "alias", objectSourceResidents = Map.singleton (identity "c") 1}
  _ <- right (provisionObjectSource (RegistrySource small))
  _ <- right (provisionObjectSource (RegistrySource other))
  require "shared budget must fit its complete union"
    (foldObjectStoreSources both [RegistrySource small, RegistrySource other] == Left (SourceStorageFailure (StorageOverBacking (BackingId "minio") 3 2)))
  require "a budget cannot resolve to another owner"
    (case foldObjectStoreSources both [RegistrySource base, RegistrySource (alias {objectSourceOwner = "foreign"})] of
      Left (BudgetOwnerConflict (BudgetId "budget") _ _) -> True
      _ -> False)

  let constructors = [ApplicationSource, ContentSource, RegistrySource]
      arm name = ObjectSourceDemand name name (SourceScope "s" "t" name)
        (ProviderObjectQuota (BudgetId name) "s" 39 6)
        (Map.singleton (PhysicalObjectId "s" "t" name "resident") 2)
        [ObjectPopulation "future" 1 3 0] [ObjectPopulation "concurrent" 1 5 0]
        [ObjectPopulation "lag" 1 7 30] [ObjectPopulation "failed" 2 11 60]
      variants = [constructor (arm name) | (constructor, name) <- zip constructors ["app", "content", "registry"]]
      names = Set.fromList (fmap (objectSourceId . sourceDemand) variants)
  require "only the three unstructured arms accept generic populations"
    (Set.fromList (fmap sourceKind variants) == Set.fromList [ApplicationObjects,ContentObjects,RegistryObjects])
  six <- right (foldObjectStoreSources names variants)
  require "generic arms retain every population" (objectStoreLogicalBytes six == 117 && objectStoreLogicalObjectCount six == 18)
  let admissions = objectStoreWriterAdmissions six
  require "every producer retains its bound writer policy" (Map.keysSet admissions == names)
  mapM_ (\(name, admission) -> do
    let fresh = PhysicalObjectId "s" "t" name "new"
        selected = Just (FutureObjects, "future")
        initial = emptyObjectWriterState admission
        attempt = reserveObjectWrite admission name
        denied result = case result of Left _ -> True; Right _ -> False
    require "writer admission is bound to its source and scope"
      (writerAdmissionSource admission == name && writerAdmissionScope admission == SourceScope "s" "t" name)
    require "foreign writer refuses before reservation" (denied (reserveObjectWrite admission "foreign" initial fresh selected 3))
    require "over-size writer refuses before reservation" (denied (attempt initial fresh selected 4))
    require "foreign bucket refuses before reservation" (denied (attempt initial (fresh {physicalBucket = "foreign"}) selected 3))
    (active, firstReservation) <- right (attempt initial fresh selected 3)
    require "second simultaneous write exceeds declared concurrency" (denied (attempt active (fresh {physicalFullKey = "another"}) selected 3))
    committed <- right (finishObjectWrite active firstReservation True)
    require "second identity exceeds the future object quota" (denied (attempt committed (fresh {physicalFullKey = "another"}) selected 3))
    failedOnce <- right (finishObjectWrite active firstReservation False)
    (retrying, retryReservation) <- right (attempt failedOnce fresh selected 3)
    failedTwice <- right (finishObjectWrite retrying retryReservation False)
    require "failed horizon cannot be reclaimed by a new attempt" (denied (attempt failedTwice fresh selected 3))) (Map.toList admissions)
  mapM_ (\constructor -> do
    let original = arm "short"
    require "every arm rejects a one-byte-short quota" (case provisionObjectSource
      (constructor (original {objectSourceBudget = ProviderObjectQuota (BudgetId "short") "s" 38 6})) of
        Left (SourceStorageFailure _) -> True; _ -> False)
    require "every arm rejects a one-object-short quota" (case provisionObjectSource
      (constructor (original {objectSourceBudget = ProviderObjectQuota (BudgetId "short") "s" 39 5})) of
        Left (SourceStorageFailure _) -> True; _ -> False)) constructors
  pure ()
 where
  require label condition = unless condition (die label)
  right = either (die . show) pure

identity :: Text -> PhysicalObjectId
identity = PhysicalObjectId "root-minio" "platform" "bucket"

demand :: Text -> Map.Map PhysicalObjectId Natural -> ObjectSourceDemand
demand name residents = ObjectSourceDemand name "owner" (SourceScope "root-minio" "platform" "bucket")
  (FixedBackingBudget (BudgetId "budget") (BackingId "minio") 1024) residents [] [] [] []

policy :: MinioPolicy
policy = MinioPolicy 1 2 2 4096 1024 8192 1 1 1 8192
