{-# LANGUAGE OverloadedStrings #-}

module PlacementSpec (verifyPlacement) where

import Amoebius.Capacity.Placement
import Amoebius.Capacity.ObjectStore (populationForWindow, ObjectPopulation (..))
import Amoebius.Capacity.Storage
import Amoebius.Capacity.StorageGeometry
import Control.Monad (unless)
import Data.Aeson
import Data.Aeson.Types (Parser, parseEither)
import Data.ByteString.Lazy qualified as Lazy
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)
import System.Exit (die)

-- Independently authored literal corpus: the expectation review authorized by
-- the user. No native projection or observed Phase 30 maximum is an operand.
verifyPlacement :: IO ()
verifyPlacement = do
  value <- Lazy.readFile "test/oracle/platform_backbone_capacity.json" >>= right . eitherDecode
  actions <- right (parseEither corpus value)
  sequence_ actions
  ownership <- Lazy.readFile "test/oracle/platform_backbone_uniform_templates.json" >>= right . eitherDecode
  ownershipActions <- right (parseEither ownershipCorpus ownership)
  sequence_ ownershipActions
 where
  right :: Show problem => Either problem value -> IO value
  right = either (die . show) pure

corpus :: Value -> Parser [IO ()]
corpus = withObject "independent capacity corpus" $ \value -> do
  model <- value .: "minio_model"
  minioCases <- value .: "minio_cases" >>= traverse (minioCase model)
  bookieCases <- value .: "bookkeeper_cases" >>= traverse bookieCase
  boundaries <- value .: "boundaries" >>= traverse boundary
  horizons <- value .: "horizon_boundaries" >>= traverse horizonCase
  pure (minioCases <> bookieCases <> boundaries <> horizons)

ownershipCorpus :: Value -> Parser [IO ()]
ownershipCorpus = withObject "uniform template ownership" $ \root -> do
  cases <- root .: "cases" >>= traverse ownershipCase
  negatives <- root .: "required_rejections" >>= traverse ownershipCase
  pure (cases <> negatives)

ownershipCase :: Value -> Parser (IO ())
ownershipCase = withObject "uniform ownership case" $ \row -> do
  name <- row .: "id"
  inputs <- row .: "slots" :: Parser [Value]
  slots <- traverse (\(index, value) -> withObject "uniform slot" (\slot -> do
    let number key fallback = slot .:? key >>= maybe (row .:? key .!= fallback) pure
        text key fallback = slot .:? key >>= maybe (row .:? key .!= fallback) pure
    volumeName <- slot .:? "name" .!= Text.pack (show (index :: Int))
    stateful <- slot .: "statefulset"
    claim <- slot .: "template"
    ordinal <- slot .: "ordinal"
    usable <- slot .: "required_usable_bytes"
    owner <- text "backing" ""
    capacity <- number "backing_capacity_bytes" 0
    minimumRaw <- number "minimum_raw_bytes" 0
    quantum <- number "quantum_bytes" 1
    present <- text "presentation" "Block"
    filesystem <- text "filesystem_model" "ext4-v1"
    overhead <- number "overhead_basis_points" 0
    pure (DeclaredVolumeDemand volumeName (StatefulSetClaimSlot stateful claim ordinal)
      (StorageBacking (BackingId owner) capacity (BackingAllocationPolicy minimumRaw quantum)) usable
      (DirectGeometry 1) (if present == "Block" then BlockPresentation else FilesystemPresentation filesystem overhead))) value) (zip [0..] inputs)
  expected <- row .: "expected"
  debits <- row .:? "expected_per_backing_debit" :: Parser (Maybe (Map.Map Text Natural))
  expectedTemplates <- row .:? "expected_template_raw_bytes" :: Parser (Maybe Value)
  pure $ do
    volumes <- either (die . show) pure (traverse provisionVolume slots)
    let result = uniformStatefulSetClaims volumes
    check name (either (const "reject") (const "accept") result == (expected :: Text))
    case (result, debits) of
      (Right witness, Just expectedDebits) -> do
        check name (uniformClaimBytesByBacking witness == Map.mapKeys BackingId expectedDebits)
        check name (uniformBackingBySlot witness == Map.fromList [(provisionedClaim volume, provisionedBacking volume) | volume <- volumes])
        case expectedTemplates of
          Just (Object values) -> do
            decoded <- either die pure (parseEither parseJSON (Object values) :: Either String (Map.Map Text Natural))
            check name (Map.fromList [(stateful <> "/" <> claim, bytes) | ((stateful, claim), bytes) <- Map.toList (uniformMemberBytesByTemplate witness)] == decoded)
          _ -> pure ()
      (Left (StorageOverBacking owner required _), Just expectedDebits) -> check name (Map.lookup (unBackingId owner) expectedDebits == Just required)
      _ -> pure ()

minioCase :: Object -> Value -> Parser (IO ())
minioCase model = withObject "MinIO case" $ \row -> do
  name <- row .: "id"
  sets <- row .: "sets"
  overrides <- row .:? "overrides" .!= mempty
  let field key = case parseEither (\_ -> overrides .: key) Null of
        Right result -> pure result
        Left _ -> model .: key
  policy <- MinioPolicy sets <$> field "data_shards" <*> field "parity_shards"
    <*> field "shard_block_bytes" <*> field "metadata_bytes_per_object_per_drive"
    <*> field "incoming_healing_workspace_bytes_per_target" <*> field "faults_per_set"
    <*> field "concurrent_write_sets" <*> field "failed_write_sets" <*> field "maximum_write_extent_bytes"
  entries <- row .: "objects" >>= traverse parseEntry
  expected <- row .: "expected"
  logical <- expected .: "logical_bytes"
  count <- expected .: "object_count" :: Parser Int
  payload <- expected .: "payload"
  metadata <- expected .: "metadata"
  healing <- expected .: "healing"
  writes <- expected .: "write_peak"
  total <- expected .: "total"
  slots <- expected .: "per_drive"
  failures <- expected .: "failure_count" :: Parser Int
  requiredFailures <- row .:? "required_failure_members" .!= []
  uniformDebit <- row .:? "uniform_template_debit_if_all_eight_share_one_template"
  staticMetadata <- model .: "static_metadata_bytes_per_drive"
  pure $ do
    let placement = Map.unionWith (<>) (Map.fromListWith (<>) [(set, [(identity, bytes, 1)]) | (set, identity, bytes) <- entries])
          (Map.fromList [(set, []) | set <- [0 .. sets - 1]])
    result <- either (die . show) pure (provisionMinioPlacement policy placement)
    let geometry = minioPlacementGeometry result
        singleFaultFamily = [[],[0],[1],[2],[3]]
        faultFamily = if sets == 2
          then [left <> right | left <- singleFaultFamily, right <- [[],[4],[5],[6],[7]]]
          else if minioFaultBoundPerSet policy == 2
            then singleFaultFamily <> [[0,1],[0,2],[0,3],[1,2],[1,3],[2,3]]
            else singleFaultFamily
    check name (minioObjectPlacement result == placement)
    check name (staticMetadata == minioMetadataBytesPerDrive policy)
    check name (geometryLogicalBytes geometry == logical && length entries == count)
    check ("native MinIO per-object physical geometry: " <> name) (geometryComponents geometry == Map.fromList
      [("stripe-data-parity", payload), ("metadata", metadata), ("healing", healing), ("concurrent-orphan", writes)])
    check name (geometryPhysicalBytes geometry == total && fmap slotPeakBytes (Map.elems (minioSlots result)) == slots)
    check ("native MinIO required fault family: " <> name) (length (geometryFailureScenarios geometry) == failures
      && all (`elem` geometryFailureScenarios geometry) requiredFailures)
    check name (Set.fromList (geometryFailureScenarios geometry) == Set.fromList faultFamily)
    case uniformDebit of
      Nothing -> pure ()
      Just required -> do
        let backing = StorageBacking (BackingId "uniform-corpus") required (BackingAllocationPolicy 0 1)
            demands = [DeclaredVolumeDemand (Text.pack (show ordinal)) (StatefulSetClaimSlot "minio" "data" ordinal)
              backing (slotPeakBytes slot) (DirectGeometry 1) BlockPresentation | (ordinal, slot) <- Map.toList (minioSlots result)]
        volumes <- either (die . show) pure (traverse provisionVolume demands)
        witness <- either (die . show) pure (uniformStatefulSetClaims volumes)
        check ("native uniform maximum-slot debit: " <> name) (Map.lookup (BackingId "uniform-corpus") (uniformClaimBytesByBacking witness) == Just required)
 where
  parseEntry = withArray "placed object" $ \values -> case toList values of
    [set, identity, bytes] -> (,,) <$> parseJSON set <*> parseJSON identity <*> parseJSON bytes
    _ -> fail "placed object must contain set, identity and bytes"

bookieCase :: Value -> Parser (IO ())
bookieCase = withObject "BookKeeper case" $ \row -> do
  name <- row .: "id"
  write <- row .: "write_quorum"
  ack <- row .: "ack_quorum"
  entries <- row .: "segments" >>= traverse (withObject "ledger segment" (\segment ->
    (,) <$> segment .: "bytes" <*> segment .: "replicas"))
  expected <- row .: "expected"
  steady <- expected .: "steady_per_bookie"
  peak <- expected .: "peak_per_bookie"
  failures <- expected .: "failure_subsets"
  pure $ do
    result <- either (die . show) pure (provisionBookKeeperPlacement (BookKeeperPolicy 3 write ack 2 1)
      [LedgerSegment (Text.pack (show ordinal)) bytes replicas | (ordinal, (bytes, replicas)) <- zip [0 :: Int ..] entries])
    check name (fmap slotSteadyBytes (Map.elems (bookKeeperSlots result)) == steady)
    check name (fmap slotPeakBytes (Map.elems (bookKeeperSlots result)) == peak)
    check name (Set.fromList (fmap fst (bookKeeperRecoveryCases result)) == Set.fromList failures)

boundary :: Value -> Parser (IO ())
boundary = withObject "capacity boundary" $ \row -> do
  name <- row .: "id"
  required <- row .: "required"
  available <- row .: "available"
  expected <- row .: "expected"
  slots <- row .:? "usable_slots"
  presentation <- row .:? "filesystem_overhead_basis_points" .!= 0
  minimumRaw <- row .:? "minimum_raw" .!= 0
  quantum <- row .:? "quantum" .!= 1
  expectedPresented <- row .:? "expected_presented" .!= []
  expectedRounded <- row .:? "expected_rounded" .!= []
  pure $ do
    case slots of
      Nothing -> pure ()
      Just usable -> do
        let backing = StorageBacking (BackingId "corpus") available (BackingAllocationPolicy minimumRaw quantum)
            demands = [DeclaredVolumeDemand (Text.pack (show ordinal))
              (StatefulSetClaimSlot "corpus" "data" ordinal) backing bytes (DirectGeometry 1)
              (FilesystemPresentation "corpus" presentation) | (ordinal, bytes) <- zip [0 ..] usable]
            result = traverse provisionVolume demands >>= uniformStatefulSetClaims
        case traverse provisionVolume demands of
          Left _ -> pure ()
          Right provisions -> check name (fmap provisionedBytes provisions == expectedRounded)
        check name (either (const "reject") (const "accept") result == (expected :: Text))
        case result of
          Left _ -> pure ()
          Right witness -> check name (Map.lookup (BackingId "corpus") (uniformClaimBytesByBacking witness) == Just required)
        check name (fmap (presentBytes (FilesystemPresentation "corpus" presentation)) usable == expectedPresented)
    case slots of
      Just _ -> pure ()
      Nothing -> do
        -- These denials compose the subject's independently checked slot
        -- geometry with fitBacking, rather than supplying expected demand.
        actual <- if "minio" `Text.isInfixOf` name || "erasure" `Text.isInfixOf` name
          then do
            placement <- either (die . show) pure (provisionMinioPlacement (MinioPolicy 1 2 2 4096 1024 8192 1 1 1 8192)
              (Map.singleton 0 [("a", 1, 1), ("b", 1, 1)]))
            pure (maximum (fmap slotPeakBytes (Map.elems (minioSlots placement))))
          else do
            placement <- either (die . show) pure (provisionBookKeeperPlacement (BookKeeperPolicy 3 2 2 2 1)
              [LedgerSegment "a" 3 [0,1], LedgerSegment "b" 5 [1,2], LedgerSegment "c" 7 [2,0]])
            pure (maximum (fmap slotPeakBytes (Map.elems (bookKeeperSlots placement))))
        check name (actual == required)
        let result = fitBacking (StorageBacking (BackingId "corpus") available (BackingAllocationPolicy 0 1)) actual
        check name (either (const "reject") (const "accept") result == (expected :: Text))

horizonCase :: Value -> Parser (IO ())
horizonCase = withObject "rate/horizon boundary" $ \row -> do
  name <- row .: "id"
  horizon <- row .: "horizon_seconds"
  window <- row .: "window_seconds"
  rate <- row .: "failures_per_window"
  extent <- row .: "maximum_bytes"
  count <- row .: "expected_object_count"
  bytes <- row .: "expected_bytes"
  pure $ do
    population <- either (die . show) pure (populationForWindow name rate extent window horizon)
    check name (populationCount population == count && populationMaximumBytes population * populationCount population == bytes)

check :: Text -> Bool -> IO ()
check name condition = unless condition (die ("independent capacity case failed: " <> Text.unpack name))

toList :: Foldable container => container value -> [value]
toList = foldr (:) []
