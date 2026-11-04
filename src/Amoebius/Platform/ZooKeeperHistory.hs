{-# LANGUAGE OverloadedStrings #-}

-- | Pure cumulative history admission. A caller must durably persist the
-- resulting state before permitting an append/application/file creation.
-- This module alone supplies neither JVM interception nor import provenance.
module Amoebius.Platform.ZooKeeperHistory
  ( HistoryPolicy, historyPolicy, historyUniqueLimit, historyPolicyValue
  , HistoryState, emptyHistoryState, historyStateValue, decodeHistoryState
  , HistoryMutation (..), HistoryGeneration (..)
  , reserveHistoryMutation, admitHistoryApplication, reserveHistoryAppend, reserveHistoryGeneration
  , HistoryCommand, historyCommandFromValue, applyHistoryCommand, historyStateSummary
  , historyStateEncodingBounds
  ) where

import Control.Monad (unless)
import Data.Aeson
import Data.Aeson.Types (Parser, parseEither)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)

data HistoryPolicy = HistoryPolicy (Set Natural) Natural Natural Natural Natural Natural
  deriving stock (Eq, Show)
data HistoryMutation = HistoryMutation
  { historyZxid :: Natural, historyCanonicalSha256 :: Text, historyCanonicalBytes :: Natural }
  deriving stock (Eq, Show)
data HistoryGeneration = HistoryLog | HistorySnapshot
  deriving stock (Eq, Ord, Show)
data HistoryState = HistoryState HistoryPolicy (Map Natural HistoryMutation) (Map Natural Natural)
  (Map Natural (Set Text)) (Map Natural (Set Text))
  deriving stock (Eq, Show)

historyPolicy :: [Natural] -> Natural -> Natural -> Natural -> Natural -> Natural -> Either Text HistoryPolicy
historyPolicy members snapshot bootstrap physical logs snapshots = do
  unless (not (null members) && length members == Set.size (Set.fromList members)
    && snapshot > bootstrap && all (>0) [physical,logs,snapshots]) (Left "zookeeper-history-policy-invalid")
  pure (HistoryPolicy (Set.fromList members) snapshot bootstrap physical logs snapshots)

historyUniqueLimit :: HistoryPolicy -> Natural
historyUniqueLimit (HistoryPolicy _ snapshot bootstrap _ _ _) = (snapshot-bootstrap) `div` 3

historyPolicyValue :: HistoryPolicy -> Value
historyPolicyValue policy@(HistoryPolicy members snapshot bootstrap physical logs snapshots) = object
  ["members" .= Set.toAscList members,"snapshotBytes" .= snapshot,"bootstrapBytes" .= bootstrap,
   "growthFactor" .= (3 :: Natural),"uniqueFramedBytes" .= historyUniqueLimit policy,
   "physicalBytesPerMember" .= physical,"logGenerationsPerMember" .= logs,"snapshotGenerationsPerMember" .= snapshots]

emptyHistoryState :: HistoryPolicy -> HistoryState
emptyHistoryState policy = HistoryState policy Map.empty Map.empty Map.empty Map.empty

ensureHistoryPolicy :: HistoryPolicy -> HistoryState -> Either Text ()
ensureHistoryPolicy policy (HistoryState retained _ _ _ _) = unless (retained == policy)
  (Left "zookeeper-history-state-policy-mismatch")

-- Canonical bytes are the immutable original header+transaction, excluding
-- the optional12-byte TxnDigest. A modern framed upper bound always pays it.
-- Multi children share the outer zxid and may be mutated by DataTree; callers
-- retain the original checked bytes/token, rather than reserializing them.
reserveHistoryMutation :: HistoryPolicy -> HistoryState -> Natural -> HistoryMutation -> Either Text HistoryState
reserveHistoryMutation policy@(HistoryPolicy members _ _ _ _ _) state@(HistoryState _ records physical logs snapshots) member mutation = do
  ensureHistoryPolicy policy state
  unless (member `Set.member` members) (Left "zookeeper-history-unknown-member")
  unless (historyZxid mutation > 0 && historyZxid mutation <= 9223372036854775807
    && historyCanonicalBytes mutation >= 36 && validHash (historyCanonicalSha256 mutation))
    (Left "zookeeper-history-record-invalid")
  case Map.lookup (historyZxid mutation) records of
    Just prior -> unless (prior == mutation) (Left "zookeeper-history-canonical-conflict")
    Nothing -> pure ()
  let next = Map.insert (historyZxid mutation) mutation records
  unless (sum (fmap ((25+) . historyCanonicalBytes) (Map.elems next)) <= historyUniqueLimit policy)
    (Left "zookeeper-history-global-byte-limit")
  pure (HistoryState policy next physical logs snapshots)

admitHistoryApplication :: HistoryPolicy -> HistoryState -> Natural -> HistoryMutation -> Either Text HistoryState
admitHistoryApplication policy@(HistoryPolicy members _ _ _ _ _) state@(HistoryState _ records _ _ _) member mutation = do
  ensureHistoryPolicy policy state
  unless (member `Set.member` members) (Left "zookeeper-history-unknown-member")
  case Map.lookup (historyZxid mutation) records of
    Nothing -> Left "zookeeper-history-missing-reservation"
    Just original -> unless (original == mutation) (Left "zookeeper-history-canonical-conflict")
  pure state

-- Every attempt consumes physical debt, including retries of the same zxid.
-- Canonical equality never refunds physical writes or failed reservations.
reserveHistoryAppend :: HistoryPolicy -> HistoryState -> Natural -> HistoryMutation -> Natural -> Either Text HistoryState
reserveHistoryAppend policy@(HistoryPolicy _ _ _ maximumPhysical _ _) original member mutation wireBytes = do
  next <- admitHistoryApplication policy original member mutation
  unless (wireBytes `elem` [historyCanonicalBytes mutation+13,historyCanonicalBytes mutation+25])
    (Left "zookeeper-history-wire-length-invalid")
  let HistoryState _ records physical logs snapshots = next
      charged = Map.findWithDefault 0 member physical + wireBytes
  unless (charged <= maximumPhysical) (Left "zookeeper-history-physical-byte-limit")
  pure (HistoryState policy records (Map.insert member charged physical) logs snapshots)

reserveHistoryGeneration :: HistoryPolicy -> HistoryState -> Natural -> HistoryGeneration -> Text -> Either Text HistoryState
reserveHistoryGeneration policy@(HistoryPolicy members _ _ _ logLimit snapshotLimit) state@(HistoryState _ records physical logs snapshots) member kind name = do
  ensureHistoryPolicy policy state
  unless (member `Set.member` members) (Left "zookeeper-history-unknown-member")
  let (prefix,old,limit) = case kind of
        HistoryLog -> ("log.",logs,logLimit)
        HistorySnapshot -> ("snapshot.",snapshots,snapshotLimit)
  unless (validName prefix name) (Left "zookeeper-history-unsupported-generation-name")
  let names = Set.insert name (Map.findWithDefault Set.empty member old)
  unless (fromIntegral (Set.size names) <= limit) (Left (case kind of
    HistoryLog -> "zookeeper-history-log-generation-limit"; HistorySnapshot -> "zookeeper-history-snapshot-generation-limit"))
  let next = Map.insert member names old
  pure $ case kind of
    HistoryLog -> HistoryState policy records physical next snapshots
    HistorySnapshot -> HistoryState policy records physical logs next

historyStateValue :: HistoryPolicy -> HistoryState -> Either Text Value
historyStateValue policy state@(HistoryState _ records physical logs snapshots) = do
  ensureHistoryPolicy policy state
  pure $ object
    ["schema" .= ("amoebius.zookeeper-history-state.v1" :: Text),"policy" .= historyPolicyValue policy,
   "records" .= [object ["zxid" .= historyZxid row,"canonicalSha256" .= historyCanonicalSha256 row,
     "canonicalBytes" .= historyCanonicalBytes row] | row <- Map.elems records],
   "physical" .= [object ["member" .= member,"bytes" .= bytes] | (member,bytes) <- Map.toList physical],
   "logs" .= generations logs,"snapshots" .= generations snapshots]
 where
  generations rows = [object ["member" .= member,"names" .= Set.toAscList names] | (member,names) <- Map.toList rows]

decodeHistoryState :: HistoryPolicy -> Value -> Either Text HistoryState
decodeHistoryState policy@(HistoryPolicy members _ _ maximumPhysical _ _) value =
  either (Left . Text.pack) Right (parseEither parseState value)
 where
  parseState = withObject "durable cumulative history state" $ \root -> do
    schema <- root .: "schema"; savedPolicy <- root .: "policy"
    unless (schema == ("amoebius.zookeeper-history-state.v1" :: Text) && savedPolicy == historyPolicyValue policy)
      (fail "zookeeper-history-state-policy-mismatch")
    rows <- root .: "records" >>= traverse (withObject "canonical record" $ \row ->
      HistoryMutation <$> row .: "zxid" <*> row .: "canonicalSha256" <*> row .: "canonicalBytes")
    let records = Map.fromList [(historyZxid row,row) | row <- rows]
    unless (Map.size records == length rows) (fail "zookeeper-history-state-record-duplicate")
    checked <- foldMParser (\state row -> fromEither (reserveHistoryMutation policy state (Set.findMin members) row)) (emptyHistoryState policy) rows
    physicalRows <- root .: "physical" >>= traverse (withObject "physical debit" $ \row ->
      (,) <$> row .: "member" <*> row .: "bytes")
    let physical = Map.fromList physicalRows
    unless (Map.size physical == length physicalRows && Map.keysSet physical `Set.isSubsetOf` members
      && all (<=maximumPhysical) (Map.elems physical)) (fail "zookeeper-history-state-physical-invalid")
    withLogs <- root .: "logs" >>= restoreGenerations HistoryLog checked
    withSnapshots <- root .: "snapshots" >>= restoreGenerations HistorySnapshot withLogs
    let HistoryState _ _ _ logs snapshots = withSnapshots
    pure (HistoryState policy records physical logs snapshots)
  restoreGenerations kind state rows = do
    generationRows <- traverse (withObject "generation member" $ \row -> (,) <$> row .: "member" <*> row .: "names") (rows :: [Value])
    unless (length generationRows == Set.size (Set.fromList (fmap fst generationRows))) (fail "zookeeper-history-state-member-duplicate")
    unless (all ((`Set.member` members) . fst) generationRows) (fail "zookeeper-history-unknown-member")
    foldMParser (\current (member,names) -> do
      unless (length names == Set.size (Set.fromList names)) (fail "zookeeper-history-state-generation-duplicate")
      foldMParser (\next name -> fromEither (reserveHistoryGeneration policy next member kind name)) current names) state generationRows
  fromEither :: Either Text a -> Parser a
  fromEither = either (fail . Text.unpack) pure

foldMParser :: (a -> b -> Parser a) -> a -> [b] -> Parser a
foldMParser _ initial [] = pure initial
foldMParser step initial (value:rest) = step initial value >>= \next -> foldMParser step next rest

data HistoryCommand = ReserveMutation Natural HistoryMutation | ApplyMutation Natural HistoryMutation
  | AppendMutation Natural HistoryMutation Natural | OpenGeneration Natural HistoryGeneration Text
  deriving stock (Eq, Show)

historyCommandFromValue :: Value -> Either Text HistoryCommand
historyCommandFromValue = either (Left . Text.pack) Right . parseEither (withObject "history command" $ \row -> do
  operation <- row .: "operation" :: Parser Text
  member <- row .: "member"
  let mutation = row .: "mutation" >>= withObject "immutable original canonical body" (\body ->
        HistoryMutation <$> body .: "zxid" <*> body .: "canonicalSha256" <*> body .: "canonicalBytes")
  case operation of
    "reserve" -> ReserveMutation member <$> mutation
    "apply" -> ApplyMutation member <$> mutation
    "append_attempt" -> do
      original <- mutation
      digest <- row .:? "digest" :: Parser (Maybe Text)
      case digest of
        Nothing -> pure (AppendMutation member original (historyCanonicalBytes original+13))
        Just value -> do
          unless (Text.length value == 24 && "00000002" `Text.isPrefixOf` value
            && Text.all (`elem` ("0123456789abcdef" :: String)) value)
            (fail "zookeeper-history-unsupported-digest-profile")
          pure (AppendMutation member original (historyCanonicalBytes original+25))
    "open_generation" -> do
      name <- row .: "name"
      kind <- if "log." `Text.isPrefixOf` name then pure HistoryLog else
        if "snapshot." `Text.isPrefixOf` name then pure HistorySnapshot else fail "zookeeper-history-unsupported-generation-name"
      pure (OpenGeneration member kind name)
    "direct_mutation" -> fail "zookeeper-history-unsupported-direct-mutation"
    "refund" -> fail "zookeeper-history-no-refund"
    "reset" -> fail "zookeeper-history-no-reset"
    _ -> fail "zookeeper-history-operation-unsupported")

applyHistoryCommand :: HistoryPolicy -> HistoryState -> HistoryCommand -> Either Text HistoryState
applyHistoryCommand policy state command = case command of
  ReserveMutation member mutation -> reserveHistoryMutation policy state member mutation
  ApplyMutation member mutation -> admitHistoryApplication policy state member mutation
  AppendMutation member mutation bytes -> reserveHistoryAppend policy state member mutation bytes
  OpenGeneration member kind name -> reserveHistoryGeneration policy state member kind name

historyStateSummary :: HistoryPolicy -> HistoryState -> Either Text Value
historyStateSummary policy@(HistoryPolicy members _ _ _ _ _) state@(HistoryState _ records physical logs snapshots) = do
  ensureHistoryPolicy policy state
  pure $ object
    ["globalUniqueFramedBytes" .= sum (fmap ((25+) . historyCanonicalBytes) (Map.elems records)),
   "recordCount" .= Map.size records,
   "members" .= Map.fromList [(Text.pack (show member), object
     ["physicalFramedBytes" .= Map.findWithDefault 0 member physical,
      "logs" .= Set.toAscList (Map.findWithDefault Set.empty member logs),
      "snapshots" .= Set.toAscList (Map.findWithDefault Set.empty member snapshots)]) | member <- Set.toAscList members]]

-- | Conservative compact-JSON extent from the schema and admitted policy,
-- without constructing a maximal state or measuring an observed serialization.
-- Every retained record costs at least36canonical+25modern framing bytes.
-- All identities/keys are ASCII, all numeric operands are nonnegative integers.
historyStateEncodingBounds :: HistoryPolicy -> Map Text Natural
historyStateEncodingBounds policy@(HistoryPolicy members snapshot bootstrap physical logs snapshots) = Map.fromList
  [("maximumDistinctRecords",recordCount),("maximumCanonicalBytesDigits",canonicalDigits),
   ("maximumZxidDigits",19),("maximumRecordJsonBytes",recordBytes),
   ("maximumRecordSeparatingCommas",predecessor recordCount),
   ("maximumFixedStateJsonBytesWithEmptyRecordArray",fixedBytes),
   ("maximumRawPayloadBytes",payloadBytes),("maximumEnvelopeBytes",71),
   ("maximumTotalStateBytes",71+payloadBytes)]
 where
  unique = historyUniqueLimit policy
  recordCount = unique `div` 61
  canonicalDigits = digits (max 36 (unique - min unique 25))
  recordBytes = jsonObject [("zxid",19),("canonicalSha256",66),("canonicalBytes",canonicalDigits)]
  memberSizes = fmap digits (Set.toAscList members)
  policyBytes = jsonObject [("members",jsonArray memberSizes),("snapshotBytes",digits snapshot),
    ("bootstrapBytes",digits bootstrap),("growthFactor",1),("uniqueFramedBytes",digits unique),
    ("physicalBytesPerMember",digits physical),("logGenerationsPerMember",digits logs),
    ("snapshotGenerationsPerMember",digits snapshots)]
  physicalBytes = jsonArray [jsonObject [("member",member),("bytes",digits physical)] | member <- memberSizes]
  generationBytes count prefix = jsonArray
    [jsonObject [("member",member),("names",repeated count (jsonString prefix+16))] | member <- memberSizes]
  common = [("schema",jsonString "amoebius.zookeeper-history-state.v1"),("policy",policyBytes),
    ("physical",physicalBytes),("logs",generationBytes logs "log."),
    ("snapshots",generationBytes snapshots "snapshot.")]
  fixedBytes = jsonObject (("records",2):common)
  payloadBytes = jsonObject (("records",repeated recordCount recordBytes):common)
  digits = fromIntegral . length . show
  predecessor count = count-min count 1
  jsonString text = 2+fromIntegral (Text.length text)
  jsonObject fields = 2+sum [jsonString key+1+size | (key,size) <- fields]+predecessor (fromIntegral (length fields))
  jsonArray sizes = 2+sum sizes+predecessor (fromIntegral (length sizes))
  repeated count size = 2+count*size+predecessor count

validHash :: Text -> Bool
validHash value = Text.length value == 64 && Text.all (`elem` ("0123456789abcdef" :: String)) value
validName :: Text -> Text -> Bool
validName prefix name = case Text.stripPrefix prefix name of
  Just value -> not (Text.null value) && Text.length value <= 16
    && (Text.length value == 1 || not ("0" `Text.isPrefixOf` value))
    && Text.all (`elem` ("0123456789abcdef" :: String)) value
  Nothing -> False
