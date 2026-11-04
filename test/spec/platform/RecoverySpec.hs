{-# LANGUAGE OverloadedStrings #-}

module RecoverySpec (verifyRecovery, verifyConditionalEpochs) where

import Amoebius.Capacity.Placement
import Amoebius.Capacity.Recovery
import Amoebius.Capacity.Storage (StorageError (..))
import Amoebius.Capacity.StorageGeometry
import Control.Monad (unless)
import Data.Aeson
import Data.Aeson.Types (Parser, parseEither)
import Data.Aeson.Key qualified as Key
import Data.ByteString.Lazy qualified as Lazy
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)
import System.Exit (die)

verifyRecovery :: IO ()
verifyRecovery = do
  verifyLiteralRecovery
  placement <- right (provisionMinioPlacement (MinioPolicy 1 2 2 4096 1024 8192 1 1 1 8192)
    (Map.singleton 0 [("a", 1, 1), ("b", 1, 1)]))
  pool <- right (provisionMinioRecovery placement (Map.singleton 4 35840))
  check "MinIO spare covers each active-drive fault" (Set.fromList (fmap failedMembers (recoveryCases pool))
    == Set.fromList [[],[0],[1],[2],[3]])
  check "MinIO never aliases a replacement with an active drive"
    (all (all (== 4) . Map.elems . replacementMembers) (recoveryCases pool))
  check "MinIO one-byte-short spare rejects" (provisionMinioRecovery placement (Map.singleton 4 35839)
    == Left (InvalidStorageGeometry "MinIO replacement pool cannot cover the complete fault case"))
  check "MinIO old claim cannot impersonate a replacement" (provisionMinioRecovery placement (Map.singleton 0 35840)
    == Left (InvalidStorageGeometry "MinIO replacement identities must be distinct from active drives"))
  let policy = BookKeeperPolicy 3 2 2 2 1
      segments = [RetainedSegment "a" 3 [0,1,2] [0,1], RetainedSegment "b" 5 [0,1,2] [1,2],
                  RetainedSegment "c" 7 [0,1,2] [2,0]]
  bookies <- right (provisionBookKeeperRecovery policy [0,1,2] [3] segments)
  check "pinned BookKeeper replacement uses a new identity" (all (all (== 3) . Map.elems . replacementMembers) (recoveryCases bookies))
  check "retained sources and incoming replacement stay separate" (Map.elems (recoverySlotPeaks bookies) == [12,10,14,14])
  check "BookKeeper survivor outside the write set is still ineligible" (provisionBookKeeperRecovery policy [0,1,2] [] segments
    == Left (InvalidStorageGeometry "BookKeeper has no eligible replacement outside the current ensemble"))
  check "replacement space cannot recreate data with no surviving copy"
    (provisionBookKeeperRecovery (policy {bookKeeperFaultBound = 2}) [0,1,2] [3,4] segments
      == Left (InvalidStorageGeometry "BookKeeper failed replicas have no surviving source"))
  envelope <- right (bookKeeperHistoryEnvelope (policy {bookKeeperJournalAndIndexBytesPerBookie = 48 * 1048576}) [0,1,2] [3] (4 * 1048576))
  check "history corner envelope retains every allocation and failure case" (length (recoveryCases envelope) == 12)
  check "each bookie has a full-history bound without cluster averaging"
    (Map.elems (recoverySlotPeaks envelope) == replicate 4 (52 * 1048576))
 where
  check label condition = unless condition (die label)
  right = either (die . show) pure

verifyLiteralRecovery :: IO ()
verifyLiteralRecovery = do
  value <- Lazy.readFile "test/oracle/platform_backbone_recovery.json" >>= either die pure . eitherDecode
  checks <- either die pure (parseEither parseCorpus value)
  sequence_ checks

parseCorpus :: Value -> Parser [IO ()]
parseCorpus = withObject "reviewed recovery corpus" $ \root -> do
  minio <- root .: "minio" >>= withObject "MinIO" (\row -> do
    input <- row .: "input"
    expected <- row .: "expected"
    policy <- MinioPolicy <$> input .: "erasure_sets" <*> input .: "data_shards" <*> input .: "parity_shards"
      <*> input .: "shard_block_bytes" <*> input .: "metadata_bytes_per_object_and_static_per_drive"
      <*> input .: "healing_workspace_bytes_per_target" <*> input .: "fault_bound_per_set"
      <*> input .: "concurrent_write_sets" <*> input .: "failed_write_sets" <*> input .: "maximum_write_extent_bytes"
    objects <- input .: "objects" :: Parser [(Natural, Text, Natural)]
    spares <- input .: "spare_usable_bytes"
    cases <- expected .: "cases"
    peaks <- expected .: "recovery_slot_peaks"
    pure $ do
      placement <- right (provisionMinioPlacement policy (Map.fromListWith (<>) [(set, [(identity, bytes, 1)]) | (set, identity, bytes) <- objects]))
      plan <- right (provisionMinioRecovery placement spares)
      check "complete MinIO recovery case maps" (fmap fullCase (recoveryCases plan) == cases)
      check "MinIO spare peaks" (recoverySlotPeaks plan == peaks))
  bookkeeper <- root .: "bookkeeper_exact_segments" >>= withObject "exact BookKeeper" (\row -> do
    input <- row .: "input"
    expected <- row .: "expected"
    policy <- bookiePolicy input
    active <- input .: "active_ids"
    spares <- input .: "spare_ids"
    segments <- input .: "segments" >>= traverse (withObject "segment" (\segment -> RetainedSegment
      <$> segment .: "id" <*> segment .: "bytes" <*> segment .: "ensemble" <*> segment .: "write_set"))
    cases <- expected .: "cases"
    peaks <- expected .: "recovery_slot_peaks"
    pure $ do
      plan <- right (provisionBookKeeperRecovery policy active spares segments)
      check "complete pinned BookKeeper recovery case maps" (fmap coreCase (recoveryCases plan) == cases)
      check "BookKeeper per-slot peaks" (recoverySlotPeaks plan == peaks)
      check "every case retains the exact original segment input" (all ((== segments) . recoverySegments) (recoveryCases plan)))
  envelope <- root .: "bookkeeper_shared_history_envelope" >>= withObject "BookKeeper history envelope" (\row -> do
    input <- row .: "input"
    expected <- row .: "expected"
    policy <- bookiePolicy input
    active <- input .: "active_ids"
    spares <- input .: "spare_ids"
    history <- input .: "shared_history_bytes"
    identity <- input .: "segment_id"
    ensemble <- expected .: "ensemble"
    cases <- expected .: "cases"
    peaks <- expected .: "recovery_slot_peaks"
    pure $ do
      plan <- right (bookKeeperHistoryEnvelope policy active spares history)
      check "all history-layout and failure combinations" (fmap envelopeCase (recoveryCases plan) == cases)
      check "history envelope per-slot maxima" (recoverySlotPeaks plan == peaks)
      check "history envelope retains source extent and ensemble" (all (\value -> case recoverySegments value of
        [segment] -> retainedSegmentId segment == identity && retainedSegmentBytes segment == history && retainedEnsemble segment == ensemble
        _ -> False) (recoveryCases plan)))
  pure [minio, bookkeeper, envelope]
 where
  right = either (die . show) pure
  check label condition = unless condition (die label)
  bookiePolicy input = BookKeeperPolicy <$> input .: "ensemble_size" <*> input .: "write_quorum" <*> input .: "ack_quorum"
    <*> input .: "fixed_reserve_bytes_per_slot" <*> input .: "fault_bound"

coreCase :: RecoveryCase -> Value
coreCase value = object ["failed_members" .= failedMembers value, "replacements" .= replacementMembers value,
  "incoming_bytes" .= incomingBytes value]

fullCase :: RecoveryCase -> Value
fullCase value = object ["failed_members" .= failedMembers value, "replacements" .= replacementMembers value,
  "incoming_bytes" .= incomingBytes value, "segments" .= [object ["id" .= retainedSegmentId segment,
    "bytes" .= retainedSegmentBytes segment, "ensemble" .= retainedEnsemble segment,
    "write_set" .= retainedWriteSet segment] | segment <- recoverySegments value]]

envelopeCase :: RecoveryCase -> Value
envelopeCase value = case recoverySegments value of
  [segment] -> object ["write_set" .= retainedWriteSet segment, "failed_members" .= failedMembers value,
    "replacements" .= replacementMembers value, "incoming_bytes" .= incomingBytes value]
  _ -> Null

verifyConditionalEpochs :: Value -> IO ()
verifyConditionalEpochs projection = do
  oracle <- Lazy.readFile "test/oracle/platform_backbone_recovery.json" >>= either die pure . eitherDecode
  expected <- either die pure $ parseEither (withObject "recovery corpus" (\root -> root .: "conditional_execution")) oracle
  action <- either die pure (parseEither (checkProjection expected) projection)
  action
 where
  checkProjection expected = withObject "service projection" $ \root -> do
    actual <- root .: "bookkeeperReplacementEpochs" :: Parser [Object]
    cases <- expected .: "cases" :: Parser [Object]
    boundary <- expected .: "activation_boundary" :: Parser Value
    permission <- expected .: "start_permission" :: Parser Value
    identities <- expected .: "retained_identity_requirement"
    after <- expected .: "after_exit_peak" >>= vector
    before <- expected .: "before_exit_overlap_peak" >>= vector
    replacementLimits <- expected .: "replacement_limits" >>= vector
    replacementRequests <- expected .: "replacement_requests" >>= vector
    controller <- expected .: "replacement_controller" :: Parser Value
    comparisons <- traverse (\(observation, wanted) -> do
      failed <- wanted .: "failed_ordinal" :: Parser Natural
      survivors <- wanted .: "retained_survivor_ordinals" :: Parser Value
      survivorIds <- identities .: Key.fromText ("failed_" <> Text.pack (show failed)) :: Parser Value
      actualFailed <- observation .: "failedOrdinal"
      actualSurvivors <- observation .: "retainedSurvivorOrdinals"
      actualIds <- observation .: "retainedSurvivorInstanceIds"
      actualBoundary <- observation .: "activationBoundary"
      actualPermission <- observation .: "startPermission"
      actualAfter <- observation .: "afterExitPeak"
      actualBefore <- observation .: "beforeExitOverlapPeak"
      replacement <- observation .: "replacement"
      limits <- replacement .: "effectivePodLimits"
      requests <- replacement .: "effectivePodRequests"
      body <- replacement .: "controller"
      pure (actualFailed == failed && actualSurvivors == survivors && actualIds == survivorIds
        && actualBoundary == boundary && actualPermission == permission && actualAfter == after && actualBefore == before
        && limits == replacementLimits && requests == replacementRequests && body == controller)) (zip actual cases)
    pure (unless (length actual == length cases && and comparisons) (die "reviewed conditional replacement epochs/retained identities"))
  vector row = do
    cpu <- row .: "cpu_millis" :: Parser Natural
    memory <- row .: "memory_mib" :: Parser Natural
    ephemeral <- row .: "ephemeral_mib" :: Parser Natural
    slots <- row .: "pod_slots" :: Parser Natural
    pure (object ["cpuMillis" .= cpu, "memoryBytes" .= (memory * 1048576),
      "ephemeralBytes" .= (ephemeral * 1048576), "podSlots" .= slots])
