{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Exact physical identities and finite object populations retained until the
-- MinIO geometry boundary. Future/orphan objects never acquire dedup credit.
module Amoebius.Capacity.ObjectStore
  ( PhysicalObjectId (..), SourceScope (..), SourceKind (..)
  , PopulationKind (..), ObjectPopulation (..), ObjectSourceDemand (..)
  , ObjectStoreSource (ApplicationSource, ContentSource, RegistrySource), ObjectStoreProvisionError (..)
  , ProvisionedObjectSource, LogicalObjectStorePeak
  , sourceKind, sourceDemand, provisionObjectSource, foldObjectStoreSources
  , populationForWindow
  , physicalResidentMap, objectStoreSources, objectStoreResidents
  , objectStorePopulations, objectStoreBudgetWitnesses
  , objectStoreLogicalBytes, objectStoreLogicalObjectCount, objectStoreMinioGeometry, objectStoreMinioPlacement
  , ObjectWriterAdmission, ObjectWriterState, ObjectWriteReservation
  , objectStoreWriterAdmissions, writerAdmissionSource, writerAdmissionScope
  , writerAdmissionOwner, writerAdmissionBudget, writerAdmissionKind
  , registryPopulationSlots
  , emptyObjectWriterState, reserveObjectWrite, finishObjectWrite
  , ObjectSourceContext (..), FailedWriteWindow (..)
  , ObjectEncodingModel (..), decodeObjectEncodingModel
  , uniqueObjectModelEntries, decodeControlRecordKind
  , FieldSecrecy (..), CanonicalField (..), CheckpointObjectDemand (..)
  , ControlRecordDemand (..), ControlObjectDemand (..)
  , PulsarLedgerModel (..), PulsarObjectDemand (..), derivePulsarObjects
  , DerivedObjectSource, derivedObjectSource, derivedPlaintextExtents, derivedStoredExtents
  , ObjectModelInput (..), derivedModelInput
  , deriveCheckpointObjects, deriveControlObjects
  , sourceModelInput, objectStoreModelInputs, writerAdmissionModel
  , objectWriterAdmissionProjection, objectModelInputProjection
  , decodePulsarObjectDemandProjection
  ) where

import Amoebius.Capacity.Storage
import Amoebius.Capacity.StorageGeometry (GeometryWitness (..), MinioPolicy (..))
import Amoebius.Capacity.Placement
import Amoebius.ControlPlane.Singleton (ControlPlaneStateKind)
import Data.Aeson (Value (String), encode, object, withObject, (.:), (.=))
import Data.Aeson.Types (Parser, parseEither)
import Data.ByteString.Lazy qualified as Lazy
import Data.ByteString qualified as ByteString
import Data.Text.Encoding qualified as TextEncoding
import Control.Monad (foldM, unless)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)

data PhysicalObjectId = PhysicalObjectId
  { physicalStore :: Text, physicalTenant :: Text, physicalBucket :: Text, physicalFullKey :: Text }
  deriving stock (Eq, Ord, Show)

data SourceScope = SourceScope { scopeStore :: Text, scopeTenant :: Text, scopeBucket :: Text }
  deriving stock (Eq, Ord, Show)

data SourceKind = ApplicationObjects | ContentObjects | RegistryObjects | PulsarOffloadObjects
  | PulumiCheckpointObjects | ControlPlaneStateObjects
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data PopulationKind = FutureObjects | ConcurrentObjects | DeletionLagObjects | FailedOrphanObjects
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data ObjectPopulation = ObjectPopulation
  { populationName :: Text, populationCount :: Natural, populationMaximumBytes :: Natural
  , populationWindowSeconds :: Natural }
  deriving stock (Eq, Ord, Show)

-- | Count each begun rate window in the retained horizon. Changing a horizon
-- recomputes its population instead of merely relabeling a caller's count.
populationForWindow :: Text -> Natural -> Natural -> Natural -> Natural
  -> Either ObjectStoreProvisionError ObjectPopulation
populationForWindow name perWindow maximumBytes window horizon
  | Text.null name || perWindow == 0 || maximumBytes == 0 || window == 0 || horizon == 0 =
      Left (InvalidObjectSource "rate windows and retention horizons must be finite and positive")
  | otherwise = Right (ObjectPopulation name (((horizon + window - 1) `div` window) * perWindow) maximumBytes horizon)

data ObjectSourceDemand = ObjectSourceDemand
  { objectSourceId :: Text, objectSourceOwner :: Text, objectSourceScope :: SourceScope
  , objectSourceBudget :: StorageBudget, objectSourceResidents :: Map PhysicalObjectId Natural
  , objectSourceFuture :: [ObjectPopulation], objectSourceConcurrent :: [ObjectPopulation]
  , objectSourceDeletionLag :: [ObjectPopulation], objectSourceFailedOrphans :: [ObjectPopulation] }
  deriving stock (Eq, Show)

data ObjectStoreSource = ApplicationSource ObjectSourceDemand | ContentSource ObjectSourceDemand
  | RegistrySource ObjectSourceDemand | PulsarOffloadSource ObjectSourceDemand PulsarObjectDemand
  | PulumiCheckpointSource ObjectSourceDemand CheckpointObjectDemand | ControlPlaneStateSource ObjectSourceDemand ControlObjectDemand
  deriving stock (Eq, Show)

data ObjectStoreProvisionError = SourceSetMismatch (Set Text) (Set Text) | DuplicateSourceId Text
  | InvalidObjectSource Text | ObjectOutsideSourceScope PhysicalObjectId
  | ObjectByteConflict PhysicalObjectId Natural Natural
  | BudgetOwnerConflict BudgetId Text Text | BudgetDefinitionConflict BudgetId
  | SourceStorageFailure StorageError
  deriving stock (Eq, Show)

-- The admission witness is derived from the same populations and budget that
-- enter placement. It cannot be replaced by a caller's separate cheaper policy.
data ObjectWriterAdmission = ObjectWriterAdmission SourceKind ObjectSourceDemand (Maybe ObjectModelInput)
  deriving stock (Eq, Show)

data ObjectWriteReservation = ObjectWriteReservation PhysicalObjectId (Maybe (PopulationKind, Text)) Natural
  deriving stock (Eq, Show)

data ObjectWriterState = ObjectWriterState
  (Map PhysicalObjectId (Maybe (PopulationKind, Text), Natural))
  (Map PhysicalObjectId ObjectWriteReservation) [Natural]
  deriving stock (Eq, Show)

data ProvisionedObjectSource = ProvisionedObjectSource SourceKind ObjectSourceDemand StorageWitness ObjectWriterAdmission
  deriving stock (Eq, Show)

data LogicalObjectStorePeak = LogicalObjectStorePeak [ProvisionedObjectSource]
  (Map PhysicalObjectId Natural) [(Text, PopulationKind, ObjectPopulation)] [(BudgetId, StorageWitness)]
  deriving stock (Eq, Show)

sourceKind :: ObjectStoreSource -> SourceKind
sourceKind source = case source of
  ApplicationSource _ -> ApplicationObjects
  ContentSource _ -> ContentObjects
  RegistrySource _ -> RegistryObjects
  PulsarOffloadSource _ _ -> PulsarOffloadObjects
  PulumiCheckpointSource _ _ -> PulumiCheckpointObjects
  ControlPlaneStateSource _ _ -> ControlPlaneStateObjects

sourceDemand :: ObjectStoreSource -> ObjectSourceDemand
sourceDemand source = case source of
  ApplicationSource demand -> demand
  ContentSource demand -> demand
  RegistrySource demand -> demand
  PulsarOffloadSource demand _ -> demand
  PulumiCheckpointSource demand _ -> demand
  ControlPlaneStateSource demand _ -> demand

populations :: ObjectSourceDemand -> [(PopulationKind, ObjectPopulation)]
populations demand = concat
  [ fmap (FutureObjects,) (objectSourceFuture demand), fmap (ConcurrentObjects,) (objectSourceConcurrent demand)
  , fmap (DeletionLagObjects,) (objectSourceDeletionLag demand)
#ifdef PLATFORM_BACKBONE_CONTENT_IMMEDIATE_GC_MUTANT
  , [] ]
#else
  , fmap (FailedOrphanObjects,) (objectSourceFailedOrphans demand) ]
#endif

physicalResidentMap :: [(PhysicalObjectId, Natural)] -> Either ObjectStoreProvisionError (Map PhysicalObjectId Natural)
physicalResidentMap = foldM insert Map.empty
 where
  insert found (identity, bytes) = do
    unless (bytes > 0 && all (not . Text.null)
      [physicalStore identity, physicalTenant identity, physicalBucket identity, physicalFullKey identity])
      (Left (InvalidObjectSource "empty physical identity or zero object extent"))
    case Map.lookup identity found of
      Just existing | existing /= bytes -> Left (ObjectByteConflict identity existing bytes)
      _ -> Right (Map.insert identity bytes found)

provisionObjectSource :: ObjectStoreSource -> Either ObjectStoreProvisionError ProvisionedObjectSource
provisionObjectSource source = do
  let demand = sourceDemand source
      scope = objectSourceScope demand
      pending = populations demand
      names = fmap (\(kind, population) -> (kind, populationName population)) pending
  unless (all (not . Text.null) [objectSourceId demand, objectSourceOwner demand,
    scopeStore scope, scopeTenant scope, scopeBucket scope, unBudgetId (storageBudgetId (objectSourceBudget demand))])
    (Left (InvalidObjectSource "empty source, owner, scope, or budget identity"))
  _ <- physicalResidentMap (Map.toList (objectSourceResidents demand))
  mapM_ (\identity -> unless (SourceScope (physicalStore identity) (physicalTenant identity) (physicalBucket identity) == scope)
    (Left (ObjectOutsideSourceScope identity))) (Map.keys (objectSourceResidents demand))
  unless (length names == Set.size (Set.fromList names)) (Left (InvalidObjectSource "duplicate population identity"))
  mapM_ (\(kind, population) -> unless (not (Text.null (populationName population))
    && populationCount population > 0 && populationMaximumBytes population > 0
    && (kind `notElem` [DeletionLagObjects, FailedOrphanObjects] || populationWindowSeconds population > 0))
    (Left (InvalidObjectSource "population count, extent, or retention window is unbounded"))) pending
  whenRegistry (sourceKind source) $ do
    _ <- registryPopulationSlots ConcurrentObjects (objectSourceConcurrent demand)
    _ <- registryPopulationSlots FailedOrphanObjects (objectSourceFailedOrphans demand)
    pure ()
  witness <- firstStorage (fitStorageBudget (objectSourceBudget demand) (sourceAmount demand))
  pure (ProvisionedObjectSource (sourceKind source) demand witness (ObjectWriterAdmission (sourceKind source) demand (sourceModelInput source)))

whenRegistry :: SourceKind -> Either ObjectStoreProvisionError () -> Either ObjectStoreProvisionError ()
whenRegistry kind action = if kind == RegistryObjects then action else Right ()

-- The native registry model retains original and additional future-write
-- slices as separate physical objects, conservatively keeping their separate
-- metadata charges. Their explicitly named equal-count/equal-horizon slices
-- fund one whole mutation slot; arbitrary byte totals cannot be regrouped.
registryPopulationSlots :: PopulationKind -> [ObjectPopulation]
  -> Either ObjectStoreProvisionError [ObjectPopulation]
registryPopulationSlots kind rows = case labels of
  Nothing -> Right rows
  Just (baseName,excessName) -> case filter ((==excessName) . populationName) rows of
    [] -> Right rows
    [excess] -> case filter ((==baseName) . populationName) rows of
      [base] | populationCount base == populationCount excess
        && populationWindowSeconds base == populationWindowSeconds excess ->
          Right [if populationName row == baseName then row {populationMaximumBytes =
            populationMaximumBytes base+populationMaximumBytes excess} else row
            | row <- rows,populationName row /= excessName]
      _ -> invalid "registry funding slices require matching owner count and horizon"
    _ -> invalid "duplicate registry funding slice"
 where
  labels = case kind of
    ConcurrentObjects -> Just ("registry-upload-workspace","registry-future-write-workspace-excess")
    FailedOrphanObjects -> Just ("registry-failed-upload-window","registry-future-write-failed-excess")
    _ -> Nothing

sourceAmount :: ObjectSourceDemand -> StorageAmount
sourceAmount demand = StorageAmount
  (sum (Map.elems (objectSourceResidents demand)) + sum [populationCount p * populationMaximumBytes p | (_, p) <- populations demand])
  (fromIntegral (Map.size (objectSourceResidents demand)) + sum [populationCount p | (_, p) <- populations demand])

foldObjectStoreSources :: Set Text -> [ObjectStoreSource] -> Either ObjectStoreProvisionError LogicalObjectStorePeak
foldObjectStoreSources expected inputs = do
  let names = fmap (objectSourceId . sourceDemand) inputs
      actual = Set.fromList names
  unless (expected == actual) (Left (SourceSetMismatch expected actual))
  _ <- foldM (\seen name -> if name `Set.member` seen then Left (DuplicateSourceId name) else Right (Set.insert name seen)) Set.empty names
  sources <- traverse provisionObjectSource inputs
  residents <- physicalResidentMap (concatMap (Map.toList . objectSourceResidents . sourceDemand) inputs)
  let grouped = Map.fromListWith (<>) [(storageBudgetId (objectSourceBudget demand), [demand]) | source <- inputs, let demand = sourceDemand source]
  budgets <- traverse checkBudget (Map.toList grouped)
  pure (LogicalObjectStorePeak sources residents
    [(objectSourceId demand, kind, population) | source <- inputs, let demand = sourceDemand source, (kind, population) <- populations demand] budgets)
 where
  checkBudget (identity, []) = Left (InvalidObjectSource ("empty budget group: " <> unBudgetId identity))
  checkBudget (identity, first : rest) = do
    mapM_ (\demand -> unless (objectSourceOwner demand == objectSourceOwner first)
      (Left (BudgetOwnerConflict identity (objectSourceOwner first) (objectSourceOwner demand)))) rest
    mapM_ (\demand -> unless (objectSourceBudget demand == objectSourceBudget first)
      (Left (BudgetDefinitionConflict identity))) rest
    residents <- physicalResidentMap (concatMap (Map.toList . objectSourceResidents) (first : rest))
    let pending = concatMap populations (first : rest)
        amount = StorageAmount (sum (Map.elems residents) + sum [populationCount p * populationMaximumBytes p | (_, p) <- pending])
          (fromIntegral (Map.size residents) + sum [populationCount p | (_, p) <- pending])
    witness <- firstStorage (fitStorageBudget (objectSourceBudget first) amount)
    pure (identity, witness)

objectStoreSources :: LogicalObjectStorePeak -> [ProvisionedObjectSource]
objectStoreSources (LogicalObjectStorePeak sources _ _ _) = sources

objectStoreWriterAdmissions :: LogicalObjectStorePeak -> Map Text ObjectWriterAdmission
objectStoreWriterAdmissions peak = Map.fromList
  [(objectSourceId demand, admission) | ProvisionedObjectSource _ demand _ admission <- objectStoreSources peak]

writerAdmissionSource :: ObjectWriterAdmission -> Text
writerAdmissionSource (ObjectWriterAdmission _ demand _) = objectSourceId demand

writerAdmissionScope :: ObjectWriterAdmission -> SourceScope
writerAdmissionScope (ObjectWriterAdmission _ demand _) = objectSourceScope demand

emptyObjectWriterState :: ObjectWriterAdmission -> ObjectWriterState
emptyObjectWriterState (ObjectWriterAdmission _ demand _) = ObjectWriterState
  (fmap (Nothing,) (objectSourceResidents demand)) Map.empty []

-- | The caller supplies an already authenticated writer identity. A class
-- selects a provisioned population, never an arbitrary caller-authored quota.
-- Successful reservations are the only values accepted by finishObjectWrite.
reserveObjectWrite :: ObjectWriterAdmission -> Text -> ObjectWriterState
  -> PhysicalObjectId -> Maybe (PopulationKind, Text) -> Natural
  -> Either ObjectStoreProvisionError (ObjectWriterState, ObjectWriteReservation)
reserveObjectWrite (ObjectWriterAdmission sourceKind' demand _) authenticated (ObjectWriterState committed pending failures) identity selected bytes = do
  unless (authenticated == objectSourceId demand) (Left (InvalidObjectSource "writer identity mismatch"))
  unless (SourceScope (physicalStore identity) (physicalTenant identity) (physicalBucket identity) == objectSourceScope demand)
    (Left (ObjectOutsideSourceScope identity))
  unless (bytes > 0 && not (Text.null (physicalFullKey identity)) && Map.notMember identity pending)
    (Left (InvalidObjectSource "empty or already active write"))
  maximumBytes <- case selected of
    Nothing -> maybe (Left (InvalidObjectSource "unknown resident write")) Right (Map.lookup identity (objectSourceResidents demand))
    Just (kind, name) -> do
      unless (kind == FutureObjects) (Left (InvalidObjectSource "only future populations admit new committed identities"))
      population <- case [p | (k, p) <- populations demand, k == kind, populationName p == name] of
        [p] -> Right p
        _ -> Left (InvalidObjectSource "unknown writer population")
      let occupied = Map.union (fmap (\(ObjectWriteReservation _ cls extent) -> (cls, extent)) pending) committed
          others = Map.delete identity occupied
      unless (fromIntegral (length [() | (cls, _) <- Map.elems others, cls == selected]) < populationCount population)
        (Left (InvalidObjectSource "writer object count exhausted"))
      pure (populationMaximumBytes population)
  unless (bytes <= maximumBytes) (Left (InvalidObjectSource "writer object extent exceeded"))
  concurrent <- slots ConcurrentObjects (objectSourceConcurrent demand)
  failed <- slots FailedOrphanObjects (objectSourceFailedOrphans demand)
  let activeExtents = maximumBytes : [extent | ObjectWriteReservation _ _ extent <- Map.elems pending]
  unless (fitSlots activeExtents concurrent
    && fitSlots (failures <> activeExtents) failed)
    (Left (InvalidObjectSource "writer concurrency or failed history exhausted"))
  case Map.lookup identity committed of
    Just (previous, _) -> unless (previous == selected) (Left (InvalidObjectSource "writer object class conflict"))
    Nothing -> pure ()
  let reservation = ObjectWriteReservation identity selected maximumBytes
  pure (ObjectWriterState committed (Map.insert identity reservation pending) failures, reservation)
 where
  slots kind values = if sourceKind' == RegistryObjects then registryPopulationSlots kind values else Right values
  -- Threshold dominance is an injective assignment into the finite multiset
  -- of declared extents, without expanding potentially large population counts.
  fitSlots claims availableSlots = all (\extent ->
    fromIntegral (length (filter (>= extent) claims)) <=
      sum [populationCount p | p <- availableSlots, populationMaximumBytes p >= extent]) claims

-- | Failed extents remain charged. No elapsed-time or unobserved GC API can
-- erase them. Runtime adapters persist this state before forwarding mutation.
finishObjectWrite :: ObjectWriterState -> ObjectWriteReservation -> Bool
  -> Either ObjectStoreProvisionError ObjectWriterState
finishObjectWrite (ObjectWriterState committed pending failures) reservation@(ObjectWriteReservation identity selected bytes) success = do
  unless (Map.lookup identity pending == Just reservation) (Left (InvalidObjectSource "writer reservation mismatch"))
  pure (ObjectWriterState (if success then Map.insert identity (selected, bytes) committed else committed)
    (Map.delete identity pending) (if success then failures else bytes : failures))

objectStoreResidents :: LogicalObjectStorePeak -> Map PhysicalObjectId Natural
objectStoreResidents (LogicalObjectStorePeak _ residents _ _) = residents

objectStorePopulations :: LogicalObjectStorePeak -> [(Text, PopulationKind, ObjectPopulation)]
objectStorePopulations (LogicalObjectStorePeak _ _ pending _) = pending

objectStoreBudgetWitnesses :: LogicalObjectStorePeak -> [(BudgetId, StorageWitness)]
objectStoreBudgetWitnesses (LogicalObjectStorePeak _ _ _ witnesses) = witnesses

objectStoreLogicalBytes :: LogicalObjectStorePeak -> Natural
objectStoreLogicalBytes peak = sum (Map.elems (objectStoreResidents peak))
  + sum [populationCount p * populationMaximumBytes p | (_, _, p) <- objectStorePopulations peak]

objectStoreLogicalObjectCount :: LogicalObjectStorePeak -> Natural
objectStoreLogicalObjectCount peak = fromIntegral (Map.size (objectStoreResidents peak))
  + sum [populationCount p | (_, _, p) <- objectStorePopulations peak]

-- | With no runtime placement commitment, every set reserves the whole
-- population. The witness still retains every actual drive; no summed total
-- is divided to recover a claim size.
objectStoreMinioPlacement :: MinioPolicy -> LogicalObjectStorePeak -> Either ObjectStoreProvisionError MinioPlacement
objectStoreMinioPlacement policy peak = firstStorage (provisionMinioPlacement policy placements)
 where
  populationsFor set =
    [(Text.pack (show (set, identity)), bytes, 1) | (identity, bytes) <- Map.toList (objectStoreResidents peak)]
    <> [(Text.pack (show (set, source, kind, populationName population)), populationMaximumBytes population, populationCount population)
       | (source, kind, population) <- objectStorePopulations peak]
  placements = Map.fromList [(set, populationsFor set) | set <- [0 .. minioErasureSets policy - 1]]

objectStoreMinioGeometry :: MinioPolicy -> LogicalObjectStorePeak -> Either ObjectStoreProvisionError GeometryWitness
objectStoreMinioGeometry policy peak = do
  placement <- objectStoreMinioPlacement policy peak
  pure (minioPlacementGeometry placement) {geometryLogicalBytes = objectStoreLogicalBytes peak}

firstStorage :: Either StorageError value -> Either ObjectStoreProvisionError value
firstStorage = either (Left . SourceStorageFailure) Right


data ObjectSourceContext = ObjectSourceContext
  { modelSourceId :: Text, modelSourceOwner :: Text
  , modelSourceScope :: SourceScope, modelSourceBudget :: StorageBudget }
  deriving stock (Eq, Show)

data FailedWriteWindow = FailedWriteWindow
  { failedSetsPerWindow :: Natural, failureWindowSeconds :: Natural, orphanHorizonSeconds :: Natural }
  deriving stock (Eq, Show)

data ObjectEncodingModel = CheckpointJsonDekTransitV1 | ControlTransitV1 | PulsarSingleBlockV1
  deriving stock (Eq, Ord, Show)

decodeObjectEncodingModel :: Text -> Either ObjectStoreProvisionError ObjectEncodingModel
decodeObjectEncodingModel name = case name of
  "checkpoint-json-dek-transit-v1" -> Right CheckpointJsonDekTransitV1
  "control-transit-v1" -> Right ControlTransitV1
  "pulsar-4.0.6-single-block-v1" -> Right PulsarSingleBlockV1
  _ -> invalid "unsupported object encoding, encryption version, or Transit profile"

uniqueObjectModelEntries :: [(Text, value)] -> Either ObjectStoreProvisionError (Map Text value)
uniqueObjectModelEntries entries = do
  mapM_ (validName . fst) entries
  unless (length entries == Map.size result) (invalid "duplicate object model identity")
  pure result
 where result = Map.fromList entries

decodeControlRecordKind :: Text -> Either ObjectStoreProvisionError ControlPlaneStateKind
decodeControlRecordKind name = case [kind | kind <- [minBound .. maxBound], Text.pack (show kind) == name] of
  [kind] -> Right kind
  _ -> invalid "unsupported persistent control record kind"

data FieldSecrecy = PlainField | SecretField
  deriving stock (Eq, Ord, Show)

data CanonicalField = CanonicalField
  { fieldMaximumCanonicalBytes :: Natural, fieldSecrecy :: FieldSecrecy }
  deriving stock (Eq, Show)

-- | Model checkpoint-json-dek-transit-v1: sorted compact UTF-8 JSON, no LF.
-- {"entries":{resource:{path:value or {"secret":value}}},"stack":stack}
-- AES-256-GCM encrypts the whole document with a 32-byte DEK, 12-byte nonce
-- and 16-byte tag. Vault nonconvergent Transit aes256-gcm96 v1 wraps that DEK.
-- Stored JSON: {"ciphertext":base64(ciphertext+tag),"key":wrappedKey,
-- "nonce":base64(nonce)}. This capacity format is distinct from an unbound
-- Pulumi CLI export; a runtime adapter must implement this exact model.
data CheckpointObjectDemand = CheckpointObjectDemand
  { checkpointEncodingModel :: ObjectEncodingModel, checkpointModelStack :: Text
  , checkpointModelEntries :: Map Text (Map Text CanonicalField)
  , checkpointModelRetainedRevisions :: Natural
  , checkpointModelFailure :: FailedWriteWindow }
  deriving stock (Eq, Show)

-- | Model control-transit-v1: each exact record is already bounded in canonical
-- JSON bytes, and stored as a raw nonconvergent Transit v1 ciphertext string.
-- Its physical object key, record kind and encoding bound remain associated.
data ControlRecordDemand = ControlRecordDemand
  { controlRecordKind :: ControlPlaneStateKind, controlRecordMaximumCanonicalBytes :: Natural }
  deriving stock (Eq, Show)

data ControlObjectDemand = ControlObjectDemand
  { controlEncodingModel :: ObjectEncodingModel, controlModelEntries :: Map Text ControlRecordDemand
  , controlModelRetainedVersions :: Natural, controlModelFailure :: FailedWriteWindow }
  deriving stock (Eq, Show)

-- | Exact protobuf field bounds for the pinned non-streaming offloader. Ledger
-- metadata length and lastEntryId follow the same payload/entry operands as
-- the data object. Custom metadata is a closed key-to-byte-bound inventory.
data PulsarLedgerModel = PulsarLedgerModel
  { ledgerPayloadBytes :: Natural, ledgerEntryCount :: Natural
  , ledgerMaximumBlockBytes :: Natural
  , ledgerEnsembleSize :: Natural, ledgerWriteQuorum :: Natural, ledgerAckQuorum :: Natural
  , ledgerMaximumCreationTime :: Natural
  , ledgerEnsembleHistory :: Map Natural [Text]
  , ledgerCustomMetadata :: Map Text Natural }
  deriving stock (Eq, Show)

data PulsarObjectDemand = PulsarObjectDemand
  { offloadEncodingModel :: ObjectEncodingModel, offloadModelTopic :: Text
  , offloadRetainedLedgers :: Map Text PulsarLedgerModel
  , offloadFutureLedger :: PulsarLedgerModel
  , offloadMaximumSegmentsPerWindow :: Natural, offloadWindowSeconds :: Natural
  , offloadRetentionHorizonSeconds :: Natural, offloadDeletionLagSeconds :: Natural
  , offloadConcurrentSegments :: Natural, offloadModelFailure :: FailedWriteWindow
  , offloadAdmissionExtentQuantum :: Natural }
  deriving stock (Eq, Show)

data ObjectModelInput = CheckpointModelInput CheckpointObjectDemand | ControlModelInput ControlObjectDemand
  | PulsarModelInput PulsarObjectDemand
  deriving stock (Eq, Show)

data DerivedObjectSource = DerivedObjectSource
  { derivedObjectSource :: ObjectStoreSource
  , derivedPlaintextExtents :: Map Text Natural
  , derivedStoredExtents :: Map Text Natural
  , derivedModelInput :: ObjectModelInput }
  deriving stock (Eq, Show)

deriveCheckpointObjects :: ObjectSourceContext -> CheckpointObjectDemand
  -> Either ObjectStoreProvisionError DerivedObjectSource
deriveCheckpointObjects context demand = do
  unless (checkpointEncodingModel demand == CheckpointJsonDekTransitV1) (invalid "checkpoint encoding model mismatch")
  validName (checkpointModelStack demand)
  unless (not (Map.null entries)) (invalid "checkpoint entry domain is empty")
  mapM_ (\(identity, fields) -> do
    validName identity
    unless (not (Map.null fields)) (invalid "checkpoint field domain is empty")
    mapM_ (\(path, field) -> validName path >> positive (fieldMaximumCanonicalBytes field)) (Map.toList fields)) (Map.toList entries)
  let entryBytes = fmap (objectBytes . fmap fieldBytes) entries
      plaintext = objectBytes (Map.fromList [("entries", objectBytes entryBytes), ("stack", stringBytes (checkpointModelStack demand))])
      -- JSON framing37 + wrapped DEK89 + nonce16; tag inside ciphertext.
      ciphertext = 142 + base64Bytes (plaintext + 16)
      extents = Map.singleton ("checkpoints/" <> checkpointModelStack demand) ciphertext
  source <- versionedSource context (\source -> PulumiCheckpointSource source demand) extents (checkpointModelRetainedRevisions demand) (checkpointModelFailure demand)
  pure (DerivedObjectSource source (Map.singleton ("checkpoints/" <> checkpointModelStack demand) plaintext) extents (CheckpointModelInput demand))
 where
  entries = checkpointModelEntries demand
  fieldBytes field = fieldMaximumCanonicalBytes field + case fieldSecrecy field of
    PlainField -> 0
    SecretField -> 11

deriveControlObjects :: ObjectSourceContext -> ControlObjectDemand
  -> Either ObjectStoreProvisionError DerivedObjectSource
deriveControlObjects context demand = do
  unless (controlEncodingModel demand == ControlTransitV1) (invalid "control encoding model mismatch")
  unless (not (Map.null (controlModelEntries demand))) (invalid "control record domain is empty")
  mapM_ (\(identity, entry) -> validName identity >> positive (controlRecordMaximumCanonicalBytes entry)) (Map.toList (controlModelEntries demand))
  let plaintext = fmap controlRecordMaximumCanonicalBytes (controlModelEntries demand)
      ciphertext = fmap (\bytes -> 9 + base64Bytes (bytes + 28)) plaintext
      -- Include the closed kind in each population identity. Two kinds with
      -- equal plaintext lengths cannot lose their distinct record identities.
      extents = Map.fromList [(identity <> ":" <> Text.pack (show (controlRecordKind entry)), ciphertext Map.! identity)
        | (identity, entry) <- Map.toList (controlModelEntries demand)]
  source <- versionedSource context (\source -> ControlPlaneStateSource source demand) extents (controlModelRetainedVersions demand) (controlModelFailure demand)
  pure (DerivedObjectSource source plaintext extents (ControlModelInput demand))

derivePulsarObjects :: ObjectSourceContext -> PulsarObjectDemand
  -> Either ObjectStoreProvisionError DerivedObjectSource
derivePulsarObjects context demand = do
  unless (offloadEncodingModel demand == PulsarSingleBlockV1) (invalid "offload encoding model mismatch")
  validName (offloadModelTopic demand)
  mapM_ positive [offloadConcurrentSegments demand, offloadAdmissionExtentQuantum demand]
  (dataBytes, indexBytes) <- ledgerExtents (offloadFutureLedger demand)
  retained <- traverse ledgerExtents (offloadRetainedLedgers demand)
  mapM_ validLedgerKey (Map.keys retained)
  let scope = modelSourceScope context
      objectId key = PhysicalObjectId (scopeStore scope) (scopeTenant scope) (scopeBucket scope) key
      residentExtents = concat [[(key, bytes), (key <> "-index", index)] | (key, (bytes, index)) <- Map.toList retained]
      roundExtent bytes = ((bytes + quantum - 1) `div` quantum) * quantum
      quantum = offloadAdmissionExtentQuantum demand
      futureExtents = Map.fromList [(offloadModelTopic demand <> "/data", roundExtent dataBytes),
        (offloadModelTopic demand <> "/index", roundExtent indexBytes)]
      windowPopulation name bytes horizon = populationForWindow name
        (offloadMaximumSegmentsPerWindow demand) bytes (offloadWindowSeconds demand) horizon
  residents <- physicalResidentMap [(objectId key, bytes) | (key, bytes) <- residentExtents]
  future <- traverse (\(name, bytes) -> windowPopulation name bytes (offloadRetentionHorizonSeconds demand)) (Map.toList futureExtents)
  lag <- if offloadDeletionLagSeconds demand == 0 then pure [] else
    traverse (\(name, bytes) -> windowPopulation name bytes (offloadDeletionLagSeconds demand)) (Map.toList futureExtents)
  let concurrent = [ObjectPopulation name (offloadConcurrentSegments demand) bytes 0 | (name, bytes) <- Map.toList futureExtents]
      failure = offloadModelFailure demand
  failed <- traverse (\(name, bytes) -> populationForWindow name (failedSetsPerWindow failure) bytes
    (failureWindowSeconds failure) (orphanHorizonSeconds failure)) (Map.toList futureExtents)
  let source = PulsarOffloadSource (ObjectSourceDemand (modelSourceId context) (modelSourceOwner context)
        scope (modelSourceBudget context) residents future concurrent lag failed) demand
      plaintext = Map.fromList [(key, ledgerPayloadBytes ledger) | (key, ledger) <- Map.toList (offloadRetainedLedgers demand)]
        <> Map.singleton (offloadModelTopic demand <> "/future-ledger") (ledgerPayloadBytes (offloadFutureLedger demand))
  _ <- provisionObjectSource source
  pure (DerivedObjectSource source plaintext (Map.union (Map.fromList residentExtents) futureExtents) (PulsarModelInput demand))

validLedgerKey :: Text -> Either ObjectStoreProvisionError ()
validLedgerKey key = unless valid (invalid "offload retained key is not a V1 ledger data identity")
 where
  valid = case Text.splitOn "-ledger-" key of
    [uuid, number] -> fmap Text.length (Text.splitOn "-" uuid) == [8,4,4,4,12]
      && Text.all (\character -> character == '-' || character `elem` ("0123456789abcdef" :: String)) uuid
      && not (Text.null number) && Text.all (`elem` ("0123456789" :: String)) number
      && Text.length key <= 128
    _ -> False

ledgerExtents :: PulsarLedgerModel -> Either ObjectStoreProvisionError (Natural, Natural)
ledgerExtents ledger = do
  mapM_ positive [ledgerPayloadBytes ledger, ledgerEntryCount ledger, ledgerMaximumBlockBytes ledger,
    ledgerEnsembleSize ledger, ledgerWriteQuorum ledger, ledgerAckQuorum ledger]
  unless (ledgerAckQuorum ledger <= ledgerWriteQuorum ledger && ledgerWriteQuorum ledger <= ledgerEnsembleSize ledger)
    (invalid "invalid offload ledger quorums")
  unless (not (Map.null (ledgerEnsembleHistory ledger)) && Map.member 0 (ledgerEnsembleHistory ledger))
    (invalid "offload metadata must retain the first ensemble")
  mapM_ (\(first, members) -> do
    unless (first < ledgerEntryCount ledger && fromIntegral (length members) == ledgerEnsembleSize ledger
      && length members == Map.size (Map.fromList [(member, ()) | member <- members]))
      (invalid "invalid offload ensemble domain")
    mapM_ validName members) (Map.toList (ledgerEnsembleHistory ledger))
  mapM_ (validName . fst) (Map.toList (ledgerCustomMetadata ledger))
  let dataBytes = 128 + ledgerPayloadBytes ledger + 12 * ledgerEntryCount ledger
  unless (dataBytes <= ledgerMaximumBlockBytes ledger) (invalid "multi-block offload is outside the single-block model")
  let scalarValues = [ledgerWriteQuorum ledger, ledgerEnsembleSize ledger, ledgerPayloadBytes ledger,
        ledgerEntryCount ledger - 1, 3, 3, ledgerAckQuorum ledger, ledgerMaximumCreationTime ledger]
  unless (all (<= 9223372036854775807) (scalarValues <> Map.keys (ledgerEnsembleHistory ledger)))
    (invalid "offload protobuf signed integer overflow")
  -- All field tags here occupy one byte. CLOSED=3 and CRC32C=3.
  -- OffloadUtils intentionally excludes the password and cToken fields.
  let metadata = sum [1 + varintBytes value | value <- scalarValues]
        + sum [lengthDelimited (sum [lengthDelimited (utf8Bytes member) | member <- members]
            + 1 + varintBytes first) | (first, members) <- Map.toList (ledgerEnsembleHistory ledger)]
        + sum [lengthDelimited (lengthDelimited (utf8Bytes key) + lengthDelimited bytes)
          | (key, bytes) <- Map.toList (ledgerCustomMetadata ledger)]
  pure (dataBytes, 32 + metadata + 20)

lengthDelimited :: Natural -> Natural
lengthDelimited bytes = 1 + varintBytes bytes + bytes

varintBytes :: Natural -> Natural
varintBytes number | number < 128 = 1
                   | otherwise = 1 + varintBytes (number `div` 128)

utf8Bytes :: Text -> Natural
utf8Bytes = fromIntegral . ByteString.length . TextEncoding.encodeUtf8

versionedSource :: ObjectSourceContext -> (ObjectSourceDemand -> ObjectStoreSource)
  -> Map Text Natural -> Natural -> FailedWriteWindow
  -> Either ObjectStoreProvisionError ObjectStoreSource
versionedSource context constructor extents retained failure = do
  positive retained
  let make name count bytes horizon = ObjectPopulation name count bytes horizon
      future = [make name retained bytes 0 | (name, bytes) <- Map.toList extents]
      -- Serial full-write-set overlap: old retained versions remain present
      -- while one complete candidate set and all failed sets are charged.
      concurrent = [make name 1 bytes 0 | (name, bytes) <- Map.toList extents]
  failed <- traverse (\(name, bytes) -> populationForWindow name
    (failedSetsPerWindow failure) bytes (failureWindowSeconds failure) (orphanHorizonSeconds failure)) (Map.toList extents)
  let source = constructor (ObjectSourceDemand (modelSourceId context) (modelSourceOwner context)
        (modelSourceScope context) (modelSourceBudget context) Map.empty future concurrent [] failed)
  _ <- provisionObjectSource source
  pure source

objectBytes :: Map Text Natural -> Natural
objectBytes fields = 2 + (if Map.null fields then 0 else fromIntegral (Map.size fields - 1))
  + sum [stringBytes key + 1 + bytes | (key, bytes) <- Map.toList fields]

stringBytes :: Text -> Natural
stringBytes = fromIntegral . Lazy.length . encode . String

base64Bytes :: Natural -> Natural
base64Bytes bytes = 4 * ((bytes + 2) `div` 3)

positive :: Natural -> Either ObjectStoreProvisionError ()
positive value = unless (value > 0) (invalid "object model bound must be positive")

validName :: Text -> Either ObjectStoreProvisionError ()
validName name = unless (not (Text.null name) && Text.length name <= 512) (invalid "invalid model identity")

invalid :: Text -> Either ObjectStoreProvisionError value
invalid = Left . InvalidObjectSource

sourceModelInput :: ObjectStoreSource -> Maybe ObjectModelInput
sourceModelInput source = case source of
  PulsarOffloadSource _ demand -> Just (PulsarModelInput demand)
  PulumiCheckpointSource _ demand -> Just (CheckpointModelInput demand)
  ControlPlaneStateSource _ demand -> Just (ControlModelInput demand)
  _ -> Nothing

writerAdmissionModel :: ObjectWriterAdmission -> Maybe ObjectModelInput
writerAdmissionModel (ObjectWriterAdmission _ _ input) = input

writerAdmissionOwner :: ObjectWriterAdmission -> Text
writerAdmissionOwner (ObjectWriterAdmission _ demand _) = objectSourceOwner demand
writerAdmissionBudget :: ObjectWriterAdmission -> BudgetId
writerAdmissionBudget (ObjectWriterAdmission _ demand _) = storageBudgetId (objectSourceBudget demand)
writerAdmissionKind :: ObjectWriterAdmission -> SourceKind
writerAdmissionKind (ObjectWriterAdmission kind _ _) = kind

objectStoreModelInputs :: LogicalObjectStorePeak -> Map Text ObjectModelInput
objectStoreModelInputs = Map.mapMaybe writerAdmissionModel . objectStoreWriterAdmissions

objectWriterAdmissionProjection :: ObjectWriterAdmission -> Value
objectWriterAdmissionProjection (ObjectWriterAdmission kind demand model) = object
  [ "source" .= objectSourceId demand, "kind" .= Text.pack (show kind), "owner" .= objectSourceOwner demand
  , "scope" .= object ["store" .= scopeStore scope, "tenant" .= scopeTenant scope, "bucket" .= scopeBucket scope]
  , "budget" .= unBudgetId (storageBudgetId (objectSourceBudget demand))
  , "quota" .= case objectSourceBudget demand of
      ProviderObjectQuota _ provider bytes count -> object ["kind" .= ("ProviderObjectQuota" :: Text),
        "provider" .= provider,"bytes" .= bytes,"objects" .= count]
      FixedBackingBudget _ backing bytes -> object ["kind" .= ("FixedBackingBudget" :: Text),
        "backing" .= unBackingId backing,"bytes" .= bytes]
  , "residentObjects" .= [object ["key" .= physicalFullKey identity, "bytes" .= bytes]
      | (identity, bytes) <- Map.toList (objectSourceResidents demand)]
  , "populations" .= [object ["kind" .= Text.pack (show populationKind), "name" .= populationName p,
      "count" .= populationCount p, "maximumBytes" .= populationMaximumBytes p, "windowSeconds" .= populationWindowSeconds p]
      | (populationKind, p) <- populations demand]
  , "model" .= fmap objectModelInputProjection model ]
 where scope = objectSourceScope demand

-- Decode the retained original model, then require derivePulsarObjects at
-- the admission boundary. A non-null JSON label is not a model witness.
decodePulsarObjectDemandProjection :: Value -> Either ObjectStoreProvisionError PulsarObjectDemand
decodePulsarObjectDemandProjection value = either (const (invalid "invalid Pulsar original model projection")) Right
  (parseEither parseDemand value)
 where
  parseDemand = withObject "Pulsar single-block original input" $ \row -> do
    model <- row .: "model" >>= either (fail . show) pure . decodeObjectEncodingModel
    unless (model == PulsarSingleBlockV1) (fail "wrong structured source model arm")
    retained <- (row .: "retainedLedgers" :: Parser (Map Text Value)) >>= traverse parseLedger
    future <- row .: "futureLedger" >>= parseLedger
    failure <- row .: "failure"
    PulsarObjectDemand model <$> row .: "topic" <*> pure retained <*> pure future
      <*> row .: "maximumSegmentsPerWindow" <*> row .: "windowSeconds" <*> row .: "retentionHorizonSeconds"
      <*> row .: "deletionLagSeconds" <*> row .: "concurrentSegments"
      <*> (FailedWriteWindow <$> failure .: "setsPerWindow" <*> failure .: "windowSeconds" <*> failure .: "horizonSeconds")
      <*> row .: "admissionExtentQuantum"
  parseLedger = withObject "pinned ledger metadata input" $ \row -> do
    ensembles <- row .: "ensembles" >>= traverse (withObject "ensemble" $ \ensemble ->
      (,) <$> ensemble .: "firstEntry" <*> ensemble .: "members")
    unless (Map.size (Map.fromList ensembles) == length ensembles) (fail "duplicate ensemble start")
    PulsarLedgerModel <$> row .: "payloadBytes" <*> row .: "entryCount" <*> row .: "maximumBlockBytes"
      <*> row .: "ensembleSize" <*> row .: "writeQuorum" <*> row .: "ackQuorum"
      <*> row .: "maximumCreationTime" <*> pure (Map.fromList ensembles) <*> row .: "customMetadata"

objectModelInputProjection :: ObjectModelInput -> Value
objectModelInputProjection input = case input of
  CheckpointModelInput demand -> object
    ["model" .= ("checkpoint-json-dek-transit-v1" :: Text), "stack" .= checkpointModelStack demand
    , "entries" .= fmap (fmap (\field -> object ["maxCanonicalBytes" .= fieldMaximumCanonicalBytes field,
        "secrecy" .= Text.pack (show (fieldSecrecy field))])) (checkpointModelEntries demand)
    , "retainedRevisions" .= checkpointModelRetainedRevisions demand, "failure" .= failure (checkpointModelFailure demand)]
  ControlModelInput demand -> object
    ["model" .= ("control-transit-v1" :: Text)
    , "entries" .= fmap (\entry -> object ["kind" .= Text.pack (show (controlRecordKind entry)),
        "maxCanonicalBytes" .= controlRecordMaximumCanonicalBytes entry]) (controlModelEntries demand)
    , "retainedVersions" .= controlModelRetainedVersions demand, "failure" .= failure (controlModelFailure demand)]
  PulsarModelInput demand -> object
    ["model" .= ("pulsar-4.0.6-single-block-v1" :: Text), "topic" .= offloadModelTopic demand
    , "retainedLedgers" .= fmap ledger (offloadRetainedLedgers demand), "futureLedger" .= ledger (offloadFutureLedger demand)
    , "maximumSegmentsPerWindow" .= offloadMaximumSegmentsPerWindow demand, "windowSeconds" .= offloadWindowSeconds demand
    , "retentionHorizonSeconds" .= offloadRetentionHorizonSeconds demand, "deletionLagSeconds" .= offloadDeletionLagSeconds demand
    , "concurrentSegments" .= offloadConcurrentSegments demand, "failure" .= failure (offloadModelFailure demand)
    , "admissionExtentQuantum" .= offloadAdmissionExtentQuantum demand]
 where
  failure budget = object ["setsPerWindow" .= failedSetsPerWindow budget,
    "windowSeconds" .= failureWindowSeconds budget, "horizonSeconds" .= orphanHorizonSeconds budget]
  ledger model = object ["payloadBytes" .= ledgerPayloadBytes model, "entryCount" .= ledgerEntryCount model,
    "maximumBlockBytes" .= ledgerMaximumBlockBytes model, "ensembleSize" .= ledgerEnsembleSize model,
    "writeQuorum" .= ledgerWriteQuorum model, "ackQuorum" .= ledgerAckQuorum model,
    "maximumCreationTime" .= ledgerMaximumCreationTime model,
    "ensembles" .= [object ["firstEntry" .= first, "members" .= members] | (first,members) <- Map.toList (ledgerEnsembleHistory model)],
    "customMetadata" .= ledgerCustomMetadata model]
