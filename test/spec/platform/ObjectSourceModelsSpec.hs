{-# LANGUAGE OverloadedStrings #-}

module ObjectSourceModelsSpec (verifyObjectSourceModels) where

import Amoebius.Capacity.ObjectSourceModels
import Amoebius.Capacity.ObjectStore
import Amoebius.Capacity.Storage
import Control.Monad (unless)
import Data.Aeson
import Data.Aeson.Types (Parser, parseEither)
import Data.ByteString.Lazy qualified as Lazy
import Data.ByteString qualified as ByteString
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Numeric.Natural (Natural)
import System.Exit (die)

verifyObjectSourceModels :: IO ()
verifyObjectSourceModels = do
  value <- Lazy.readFile "test/oracle/platform_backbone_source_models.json" >>= right . eitherDecode
  actions <- right (parseEither corpus value)
  sequence_ actions
  unionValue <- Lazy.readFile "test/oracle/platform_backbone_source_inventory.json" >>= right . eitherDecode
  right (parseEither sourceInventory unionValue) >>= id
  profile <- Lazy.readFile "test/oracle/platform_backbone_offload_profile.json" >>= right . eitherDecode
  right (parseEither nativeOffloadRawProfile profile) >>= id

-- The native projection is compared with this same independent input in
-- PlatformBackboneSpec. Use quantum1 here so rounding to1MiB cannot hide
-- an incorrect data/index/protobuf calculation.
nativeOffloadRawProfile :: Value -> Parser (IO ())
nativeOffloadRawProfile = withObject "independent native raw offload profile" $ \root -> do
  c <- root .: "source_context"
  scope <- c .: "scope"
  sourceContext <- ObjectSourceContext <$> c .: "source" <*> c .: "owner"
    <*> (SourceScope <$> scope .: "store" <*> scope .: "tenant" <*> scope .: "bucket")
    <*> (ProviderObjectQuota <$> (BudgetId <$> c .: "budget") <*> scope .: "store"
      <*> c .: "provider_quota_bytes" <*> c .: "provider_quota_objects")
  input <- root .: "expected_model_input_projection"
  model <- input .: "model" >>= either (fail . show) pure . decodeObjectEncodingModel
  let parseLedger = withObject "ledger bound" $ \row -> do
        ensembles <- row .: "ensembles" >>= traverse (withObject "ensemble" $ \ensemble ->
          (,) <$> ensemble .: "firstEntry" <*> ensemble .: "members")
        PulsarLedgerModel <$> row .: "payloadBytes" <*> row .: "entryCount" <*> row .: "maximumBlockBytes"
          <*> row .: "ensembleSize" <*> row .: "writeQuorum" <*> row .: "ackQuorum"
          <*> row .: "maximumCreationTime" <*> pure (Map.fromList ensembles) <*> row .: "customMetadata"
  future <- input .: "futureLedger" >>= parseLedger
  retained <- (input .: "retainedLedgers" :: Parser (Map.Map Text Value)) >>= traverse parseLedger
  failure <- input .: "failure"
  demand <- PulsarObjectDemand model <$> input .: "topic" <*> pure retained <*> pure future
    <*> input .: "maximumSegmentsPerWindow" <*> input .: "windowSeconds" <*> input .: "retentionHorizonSeconds"
    <*> input .: "deletionLagSeconds" <*> input .: "concurrentSegments"
    <*> (FailedWriteWindow <$> failure .: "setsPerWindow" <*> failure .: "windowSeconds" <*> failure .: "horizonSeconds")
    <*> input .: "admissionExtentQuantum"
  raw <- root .: "expected_raw_wire_bounds"
  dataBytes <- raw .: "data_object_bytes"
  indexBytes <- raw .: "index_object_bytes"
  metadataBytes <- raw .: "total_metadata_bytes"
  pure $ do
    decoded <- right (decodePulsarObjectDemandProjection (Object input))
    check "original Pulsar input decoder retains every literal operand" (decoded == demand)
    derived <- right (derivePulsarObjects sourceContext demand {offloadAdmissionExtentQuantum = 1})
    let topic = offloadModelTopic demand
    check "native unrounded offload data/index framing"
      (derivedStoredExtents derived == Map.fromList [(topic<>"/data",dataBytes),(topic<>"/index",indexBytes)]
        && indexBytes == 52 + metadataBytes)

sourceInventory :: Value -> Parser (IO ())
sourceInventory = withObject "independent six-arm structured source union" $ \root -> do
  rawInput <- root .: "raw_source_common_input"
  rawRows <- root .: "raw_sources" >>= traverse (withObject "raw source" $ \row -> do
    name <- row .: "source_id"
    kind <- row .: "kind"
    constructor <- case (kind :: Text) of
      "ApplicationObjects" -> pure ApplicationSource
      "ContentObjects" -> pure ContentSource
      "RegistryObjects" -> pure RegistrySource
      _ -> fail "structured arm cannot use a raw constructor"
    resident <- rawInput .: "resident"
    residentKey <- resident .: "full_key"
    residentBytes <- resident .: "bytes"
    future <- rawInput .: "future" >>= parsePopulation
    concurrent <- rawInput .: "concurrent" >>= parsePopulation
    lag <- rawInput .: "deletion_lag" >>= parsePopulation
    failed <- rawInput .: "failed_orphan" >>= parsePopulation
    quotaBytes <- rawInput .: "provider_quota_bytes"
    quotaObjects <- rawInput .: "provider_quota_objects"
    let make budget = do
          let source = constructor (ObjectSourceDemand name name (SourceScope "s" "t" name) budget
                (Map.singleton (PhysicalObjectId "s" "t" name residentKey) residentBytes)
                [future] [concurrent] [lag] [failed])
          _ <- provisionObjectSource source
          pure source
    pure (name, kind, quotaBytes, quotaObjects, make))
  checkpointRow <- root .: "checkpoint_source"
  checkpointName <- checkpointRow .: "source_id"
  checkpointKind <- checkpointRow .: "kind"
  checkpointBytes <- checkpointRow .: "provider_quota_bytes"
  checkpointObjects <- checkpointRow .: "provider_quota_objects"
  checkpointBase <- parseCheckpoint (Object checkpointRow)
  checkpointVersions <- checkpointRow .: "retained_revisions"
  checkpointFailure <- parseFailure checkpointRow
  checkpointModel <- checkpointRow .: "model" >>= either (fail . show) pure . decodeObjectEncodingModel
  let checkpoint = checkpointBase {checkpointModelRetainedRevisions = checkpointVersions,
        checkpointModelFailure = checkpointFailure, checkpointEncodingModel = checkpointModel}
  controlRow <- root .: "control_source"
  controlName <- controlRow .: "source_id"
  controlKind <- controlRow .: "kind"
  controlBytes <- controlRow .: "provider_quota_bytes"
  controlObjects <- controlRow .: "provider_quota_objects"
  records <- controlRow .: "entries" >>= traverse (withObject "control input" $ \record -> do
    name <- record .: "identity"
    kind <- record .: "kind" >>= either (fail . show) pure . decodeControlRecordKind
    bytes <- record .: "maximum_canonical_bytes"
    pure (name, ControlRecordDemand kind bytes))
  entries <- either (fail . show) pure (uniqueObjectModelEntries records)
  controlVersions <- controlRow .: "retained_versions"
  controlFailure <- parseFailure controlRow
  controlModel <- controlRow .: "model" >>= either (fail . show) pure . decodeObjectEncodingModel
  let control = ControlObjectDemand controlModel entries controlVersions controlFailure
  pulsarRow <- root .: "pulsar_source"
  pulsarName <- pulsarRow .: "source_id"
  pulsarKind <- pulsarRow .: "kind"
  pulsarBytes <- pulsarRow .: "provider_quota_bytes"
  pulsarObjects <- pulsarRow .: "provider_quota_objects"
  ledgerRow <- pulsarRow .: "future_ledger"
  history <- ledgerRow .: "ensemble_history" >>= traverse (withObject "ensemble input" $ \ensemble ->
    (,) <$> ensemble .: "first_entry_id" <*> ensemble .: "members")
  custom <- ledgerRow .: "custom_metadata" :: Parser [Value]
  unless (null custom) (fail "the independent union selects empty synthetic custom metadata")
  ledger <- PulsarLedgerModel <$> ledgerRow .: "payload_bytes" <*> ledgerRow .: "entry_count"
    <*> ledgerRow .: "maximum_block_bytes" <*> ledgerRow .: "ensemble_size" <*> ledgerRow .: "write_quorum"
    <*> ledgerRow .: "ack_quorum" <*> ledgerRow .: "maximum_creation_time" <*> pure (Map.fromList history) <*> pure Map.empty
  old <- pulsarRow .: "retained_ledgers" :: Parser [Value]
  unless (null old) (fail "the independent union selects no retained ledger")
  pulsarModel <- pulsarRow .: "model" >>= either (fail . show) pure . decodeObjectEncodingModel
  pulsar <- PulsarObjectDemand pulsarModel <$> pulsarRow .: "topic" <*> pure Map.empty <*> pure ledger
    <*> pulsarRow .: "maximum_segments_per_window" <*> pulsarRow .: "offload_window_seconds"
    <*> pulsarRow .: "retention_horizon_seconds" <*> pulsarRow .: "deletion_lag_seconds"
    <*> pulsarRow .: "maximum_concurrent_segments" <*> parseFailure pulsarRow <*> pulsarRow .: "admission_extent_quantum"
  expected <- root .: "expected_union"
  expectedKinds <- expected .: "kind_by_source_id"
  totalBytes <- expected .: "logical_bytes"
  totalCount <- expected .: "object_count"
  budgetCount <- expected .: "budget_witness_count"
  admissionCount <- expected .: "writer_admission_count"
  modelNames <- expected .: "structured_original_input_sources"
  axes <- traverse (\(name, kind) -> do
    axis <- expected .: name
    (kind,,) <$> axis .: "logical_bytes" <*> axis .: "object_count")
    [("future",FutureObjects),("concurrent",ConcurrentObjects),("deletion_lag",DeletionLagObjects),("failed_orphan",FailedOrphanObjects)]
  let sourceContext name suppliedBudget = ObjectSourceContext name name (SourceScope "s" "t" name) suppliedBudget
      typed name derive = \suppliedBudget -> derivedObjectSource <$> derive (sourceContext name suppliedBudget)
      rows = rawRows <>
        [(checkpointName,checkpointKind,checkpointBytes,checkpointObjects,typed checkpointName (\ctx -> deriveCheckpointObjects ctx checkpoint)),
         (controlName,controlKind,controlBytes,controlObjects,typed controlName (\ctx -> deriveControlObjects ctx control)),
         (pulsarName,pulsarKind,pulsarBytes,pulsarObjects,typed pulsarName (\ctx -> derivePulsarObjects ctx pulsar))]
      budget name bytes count = ProviderObjectQuota (BudgetId name) "s" bytes count
      expectedInputs = Map.fromList [(checkpointName,CheckpointModelInput checkpoint),
        (controlName,ControlModelInput control),(pulsarName,PulsarModelInput pulsar)]
  pure $ do
    sources <- traverse (\(name,_,bytes,count,make) -> right (make (budget name bytes count))) rows
    let names = Set.fromList [name | (name,_,_,_,_) <- rows]
    peak <- right (foldObjectStoreSources names sources)
    check "complete six-arm kind/domain join" (Map.fromList [(objectSourceId (sourceDemand source),Text.pack (show (sourceKind source))) | source <- sources] == expectedKinds)
    check "independent six-arm logical peak" (objectStoreLogicalBytes peak == totalBytes && objectStoreLogicalObjectCount peak == totalCount)
    check "six resolved budgets and private admissions" (length (objectStoreBudgetWitnesses peak) == budgetCount && Map.size (objectStoreWriterAdmissions peak) == admissionCount)
    check "structured original inputs survive the merged provision" (Map.keysSet (objectStoreModelInputs peak) == Set.fromList modelNames)
    check "merged provision retains the exact parsed structured demands" (objectStoreModelInputs peak == expectedInputs)
    mapM_ (\source -> do
      let name = objectSourceId (sourceDemand source)
          admission = objectStoreWriterAdmissions peak Map.! name
      check "private writer retains exact source model and scope" (writerAdmissionModel admission == sourceModelInput source
        && sourceModelInput source == Map.lookup name expectedInputs
        && writerAdmissionScope admission == objectSourceScope (sourceDemand source))
      population <- case objectSourceFuture (sourceDemand source) of
        first : _ -> pure first
        _ -> die "the six-arm corpus requires nonempty future classes"
      let state = emptyObjectWriterState admission
          identity = PhysicalObjectId "s" "t" name "candidate"
          selected = Just (FutureObjects,populationName population)
          bytes = populationMaximumBytes population
      (reserved, permission) <- right (reserveObjectWrite admission name state identity selected bytes)
      _ <- right (finishObjectWrite reserved permission True)
      check "all six real writer policies refuse oversized writes" (rejected (reserveObjectWrite admission name state identity selected (bytes+1)))
      check "all six real writer policies refuse foreign identities" (rejected (reserveObjectWrite admission "foreign" state identity selected bytes))
      check "all six real writer policies refuse foreign buckets" (rejected (reserveObjectWrite admission name state (identity {physicalBucket = "foreign"}) selected bytes))) sources
    mapM_ (\(kind,bytes,count) -> do
      let populations' = [population | (_,k,population) <- objectStorePopulations peak,k == kind]
      check "complete temporal byte and count axis" (sum [populationCount p * populationMaximumBytes p | p <- populations'] == bytes
        && sum (fmap populationCount populations') == count)) axes
    mapM_ (\(name,_,bytes,count,make) -> do
      check "every real derived source refuses one byte short" (rejected (make (budget name (bytes-1) count)))
      check "every real derived source refuses one object short" (rejected (make (budget name bytes (count-1))))) rows
 where
  parsePopulation = withObject "population input" $ \row -> ObjectPopulation <$> row .: "name"
    <*> row .: "count" <*> row .: "maximum_bytes" <*> row .: "horizon_seconds"

corpus :: Value -> Parser [IO ()]
corpus = withObject "independent object source model corpus" $ \root -> do
  checkpoint <- root .: "checkpoint_model"
  checkpointCases <- checkpoint .: "cases"
  checkpoints <- traverse checkpointCase checkpointCases
  base <- case checkpointCases of
    first : _ -> parseCheckpoint first
    _ -> fail "empty checkpoint corpus"
  horizonCases <- checkpoint .: "revision_horizon_cases" >>= traverse (checkpointHorizon base)
  checkpointQuotas <- checkpoint .: "quota_boundaries" >>= traverse (quotaCase (\context' -> deriveCheckpointObjects context' base))
  control <- root .: "control_model"
  controlRows <- control .: "entries" >>= traverse (withObject "control record" $ \entry -> do
    identity <- entry .: "identity"
    kindName <- entry .: "kind"
    kind <- either (fail . show) pure (decodeControlRecordKind kindName)
    bytes <- entry .: "maximum_canonical_bytes"
    expected <- entry .: "expected_stored_bytes"
    pure (identity, ControlRecordDemand kind bytes, expected))
  retained <- control .: "retained_versions"
  failure <- parseFailure control
  totalBytes <- control .: "expected_total_logical_bytes"
  totalCount <- control .: "expected_total_object_count"
  let controlDemand = ControlObjectDemand ControlTransitV1 (Map.fromList [(name, entry) | (name, entry, _) <- controlRows]) retained failure
  controlQuotas <- control .: "quota_boundaries" >>= traverse (quotaCase (\context' -> deriveControlObjects context' controlDemand))
  pulsar <- root .: "pulsar_nonstreaming_v1"
  pulsarCases <- pulsar .: "cases"
  pulsarActions <- traverse pulsarCase pulsarCases
  population <- pulsar .: "explicit_retained_population_case"
  populationAction <- pulsarPopulation population
  let controlAction = do
        derived <- right (deriveControlObjects generous controlDemand)
        check "control exact closed record extents" (derivedStoredExtents derived == Map.fromList
          [(name <> ":" <> Text.pack (show (controlRecordKind entry)), expected) | (name, entry, expected) <- controlRows])
        check "control retains original kind and canonical input" (derivedModelInput derived == ControlModelInput controlDemand)
        verifyPeak "control old/new and failed generations" derived totalBytes totalCount
      negatives = do
        check "unknown encoding model rejects" (rejected (decodeObjectEncodingModel "checkpoint-json-dek-transit-v2"))
        check "unknown control kind rejects" (rejected (decodeControlRecordKind "OtherBytes"))
        check "duplicate raw field domain rejects" (rejected (uniqueObjectModelEntries [("a",1 :: Int),("a",2)]))
        check "empty checkpoint entry set rejects" (rejected (deriveCheckpointObjects generous base {checkpointModelEntries = Map.empty}))
        check "empty checkpoint field set rejects" (rejected (deriveCheckpointObjects generous base {checkpointModelEntries = Map.singleton "r" Map.empty}))
        check "zero canonical field rejects" (rejected (deriveCheckpointObjects generous base
          {checkpointModelEntries = Map.singleton "r" (Map.singleton "a" (CanonicalField 0 PlainField))}))
        check "zero revisions rejects" (rejected (deriveCheckpointObjects generous base {checkpointModelRetainedRevisions = 0}))
        check "wrong arm encoding rejects" (rejected (deriveCheckpointObjects generous base {checkpointEncodingModel = ControlTransitV1}))
        mapM_ (\bad -> check "zero failure operand rejects" (rejected (deriveCheckpointObjects generous base {checkpointModelFailure = bad})))
          [FailedWriteWindow 0 30 61, FailedWriteWindow 1 0 61, FailedWriteWindow 1 30 0]
        check "empty control record domain rejects" (rejected (deriveControlObjects generous controlDemand {controlModelEntries = Map.empty}))
  pure (checkpoints <> horizonCases <> checkpointQuotas <> [controlAction] <> controlQuotas <> pulsarActions <> [populationAction, negatives])

parseCheckpoint :: Value -> Parser CheckpointObjectDemand
parseCheckpoint = withObject "checkpoint" $ \row -> do
  stack <- row .: "stack"
  entries <- row .: "entries" >>= traverse (traverse (withObject "canonical field" $ \field -> do
    bytes <- field .: "maximum_canonical_bytes"
    secrecy <- field .: "secrecy" >>= \name -> case (name :: Text) of
      "Plain" -> pure PlainField
      "Secret" -> pure SecretField
      _ -> fail "unknown field secrecy"
    pure (CanonicalField bytes secrecy)))
  pure (CheckpointObjectDemand CheckpointJsonDekTransitV1 stack entries 2 (FailedWriteWindow 1 30 61))

checkpointCase :: Value -> Parser (IO ())
checkpointCase value = withObject "checkpoint case" (\row -> do
  name <- row .: "id"
  demand <- parseCheckpoint value
  plaintext <- row .: "expected_plaintext_bytes"
  stored <- row .: "expected_stored_bytes"
  pure $ do
    derived <- right (deriveCheckpointObjects generous demand)
    check name (Map.elems (derivedPlaintextExtents derived) == [plaintext] && Map.elems (derivedStoredExtents derived) == [stored])
    check "exact state field and secrecy domain retained" (derivedModelInput derived == CheckpointModelInput demand)) value

checkpointHorizon :: CheckpointObjectDemand -> Value -> Parser (IO ())
checkpointHorizon base = withObject "checkpoint horizon" $ \row -> do
  name <- row .: "id"
  retained <- row .: "retained_revisions"
  failure <- parseFailure row
  bytes <- row .: "logical_bytes"
  count <- row .: "object_count"
  failed <- row .: "failed_generations"
  pure $ do
    derived <- right (deriveCheckpointObjects generous base {checkpointModelRetainedRevisions = retained, checkpointModelFailure = failure})
    verifyPeak name derived bytes count
    check name (sum (fmap populationCount (objectSourceFailedOrphans (sourceDemand (derivedObjectSource derived)))) == failed)

quotaCase :: (ObjectSourceContext -> Either ObjectStoreProvisionError DerivedObjectSource) -> Value -> Parser (IO ())
quotaCase derive = withObject "object quota boundary" $ \row -> do
  name <- row .: "id"
  bytes <- row .: "bytes"
  count <- row .: "objects"
  expected <- row .: "expected"
  pure (check name (either (const "reject") (const "accept") (derive (context bytes count)) == (expected :: Text)))

pulsarCase :: Value -> Parser (IO ())
pulsarCase = withObject "Pulsar framing case" $ \row -> do
  name <- row .: "id"
  entries <- row .: "entry_body_bytes"
  block <- row .: "maximum_block_bytes"
  custom <- row .:? "custom_metadata" .!= [] >>= traverse (withObject "custom metadata" $ \field -> do
    key <- field .: "key"
    value <- field .: "value_utf8" :: Parser Text
    pure (key, fromIntegral (ByteString.length (TextEncoding.encodeUtf8 value))))
  ensembles <- row .:? "ensemble_history" >>= traverse (traverse (withObject "ensemble" $ \ensemble ->
    (,) <$> ensemble .: "first_entry_id" <*> ensemble .: "members"))
  dataBytes <- row .: "data_bytes"
  indexBytes <- row .: "index_bytes"
  metadata <- row .: "metadata_bytes"
  expected <- row .: "expected_current_gateway_admission"
  let ledger = (smallLedger (sum entries) (fromIntegral (length (entries :: [Natural]))))
        {ledgerMaximumBlockBytes = block, ledgerCustomMetadata = Map.fromList custom,
         ledgerEnsembleHistory = maybe (ledgerEnsembleHistory (smallLedger 1 1)) Map.fromList ensembles}
  pure $ if (expected :: Text) == "reject"
    then check name (rejected (derivePulsarObjects generous (pulsarDemand ledger)))
    else do
      derived <- right (derivePulsarObjects generous (pulsarDemand ledger))
      check name (derivedStoredExtents derived == Map.fromList [("topic/data",dataBytes),("topic/index",indexBytes)]
        && indexBytes == 52 + metadata)

pulsarPopulation :: Value -> Parser (IO ())
pulsarPopulation = withObject "retained/rate offload population" $ \row -> do
  keys <- row .: "retained_data_keys"
  rate <- row .: "maximum_segments_per_offload_window"
  window <- row .: "offload_window_seconds"
  horizon <- row .: "retention_horizon_seconds"
  lag <- row .: "deletion_lag_seconds"
  concurrent <- row .: "maximum_concurrent_offloads"
  failureRate <- row .: "maximum_failed_sets_per_window"
  failureWindow <- row .: "failure_window_seconds"
  orphanHorizon <- row .: "orphan_horizon_seconds"
  count <- row .: "expected_total_object_count"
  bytes <- row .: "expected_total_logical_bytes"
  futureCount <- row .: "expected_future_ledgers"
  lagCount <- row .: "expected_deletion_lag_ledgers"
  failedCount <- row .: "expected_failed_ledgers"
  rounded <- row .: "rounded_alternative"
  quantum <- rounded .: "admission_extent_quantum"
  roundedBytes <- rounded .: "expected_total_logical_bytes"
  let ledger = smallLedger 8 2
      demand = (pulsarDemand ledger) {offloadRetainedLedgers = Map.fromList [(key,ledger) | key <- keys],
        offloadMaximumSegmentsPerWindow = rate, offloadWindowSeconds = window, offloadRetentionHorizonSeconds = horizon,
        offloadDeletionLagSeconds = lag, offloadConcurrentSegments = concurrent,
        offloadModelFailure = FailedWriteWindow failureRate failureWindow orphanHorizon}
  pure $ do
    derived <- right (derivePulsarObjects generous demand)
    verifyPeak "retained plus rate/lag/failure object pairs" derived bytes count
    let source = sourceDemand (derivedObjectSource derived)
    check "retained exact data and index identities" (Map.size (objectSourceResidents source) == 2 * length keys)
    check "each temporal population derives both objects" (all (== futureCount) (fmap populationCount (objectSourceFuture source))
      && all (== lagCount) (fmap populationCount (objectSourceDeletionLag source))
      && all (== failedCount) (fmap populationCount (objectSourceFailedOrphans source)))
    roundedDerived <- right (derivePulsarObjects generous demand {offloadAdmissionExtentQuantum = quantum})
    verifyPeak "rounded future quota preserves unrounded resident extents" roundedDerived roundedBytes count
    check "quota rounding preserves exact old objects" (objectSourceResidents (sourceDemand (derivedObjectSource roundedDerived)) == objectSourceResidents source)
    check "no-progress entry rejects" (rejected (derivePulsarObjects generous demand {offloadFutureLedger = ledger {ledgerMaximumBlockBytes = 128}}))

smallLedger :: Natural -> Natural -> PulsarLedgerModel
smallLedger payload entries = PulsarLedgerModel payload entries 5242880 3 2 2 0
  (Map.singleton 0 ["b0:3181","b1:3181","b2:3181"]) Map.empty

pulsarDemand :: PulsarLedgerModel -> PulsarObjectDemand
pulsarDemand ledger = PulsarObjectDemand PulsarSingleBlockV1 "topic" Map.empty ledger 1 30 30 0 1 (FailedWriteWindow 1 30 30) 1

parseFailure :: Object -> Parser FailedWriteWindow
parseFailure row = FailedWriteWindow <$> row .: "failed_sets_per_window" <*> row .: "failure_window_seconds" <*> row .: "orphan_horizon_seconds"

context :: Natural -> Natural -> ObjectSourceContext
context bytes count = ObjectSourceContext "writer" "owner" (SourceScope "store" "tenant" "bucket")
  (ProviderObjectQuota (BudgetId "budget") "store" bytes count)

generous :: ObjectSourceContext
generous = context 1073741824 1048576

verifyPeak :: Text -> DerivedObjectSource -> Natural -> Natural -> IO ()
verifyPeak name derived bytes count = do
  peak <- right (foldObjectStoreSources (Set.singleton "writer") [derivedObjectSource derived])
  check name (objectStoreLogicalBytes peak == bytes && objectStoreLogicalObjectCount peak == count)

check :: Text -> Bool -> IO ()
check name condition = unless condition (die ("independent object source model: " <> Text.unpack name))

rejected :: Either problem value -> Bool
rejected = either (const True) (const False)

right :: Show problem => Either problem value -> IO value
right = either (die . show) pure
