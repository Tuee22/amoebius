{-# LANGUAGE OverloadedStrings #-}

module ZooKeeperSpec (verifyZooKeeper) where

import Amoebius.Capacity.ZooKeeper
import Amoebius.Capacity.Storage
import Amoebius.Capacity.StorageGeometry (uniformClaimBytesByBacking)
import Control.Monad (unless)
import Data.Aeson
import Data.Aeson.Types (Parser, parseEither)
import Data.ByteString.Lazy qualified as Lazy
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)
import System.Exit (die)

verifyZooKeeper :: IO ()
verifyZooKeeper = do
  value <- Lazy.readFile "test/oracle/platform_backbone_zookeeper.json" >>= right . eitherDecode
  right (parseEither corpus value) >>= id
  amendment <- Lazy.readFile "test/oracle/platform_backbone_zookeeper_transactions.json" >>= right . eitherDecode
  right (parseEither transactionAmendment amendment) >>= id
  containerAmendment <- Lazy.readFile "test/oracle/platform_backbone_zookeeper_containers.json" >>= right . eitherDecode
  right (parseEither containers containerAmendment) >>= id
  padding <- Lazy.readFile "test/oracle/platform_backbone_zookeeper_padding.json" >>= right . eitherDecode
  right (parseEither filePadding padding) >>= id

filePadding :: Value -> Parser (IO ())
filePadding = withObject "independent FilePadding3.9.3" $ \root -> do
  profile <- root .: "profile"
  (property,quantum,initial,trigger,maximumExtent) <- withObject "selected preallocation" (\row -> (,,,,)
    <$> row .: "jvmProperty" <*> row .: "quantumBytes" <*> row .: "firstPaddedFileBytes"
    <*> row .: "padTriggerPosition" <*> row .: "maximumLogExtentBytes") profile
  cases <- (root .: "cases" :: Parser [Value]) >>= traverse (withObject "literal padding input" $ \row -> (,,,,,)
    <$> row .: "id" <*> row .: "position" <*> row .: "currentSize" <*> row .: "quantumBytes"
    <*> row .: "expectedFileSize" <*> row .: "expectedWithin16MiBCap")
  pure $ do
    let checkPadding name condition = unless condition (die ("independent FilePadding case: " <> Text.unpack name))
    checkPadding "runtime-property" (property == "-Dzookeeper.preAllocSize=" <> Text.pack (show zkPreallocationKiB))
    checkPadding "runtime-quantum" (quantum == zkPreallocationKiB*1024)
    checkPadding "initial-extent-and-trigger" (zkPaddedLogBytes 16 16 quantum == initial && initial-4096 == trigger)
    mapM_ (\(name,position,current,chunk,expected,within) -> do
      let actual = zkPaddedLogBytes position current chunk
      checkPadding name (actual == expected && (actual <= maximumExtent) == within)) cases

corpus :: Value -> Parser (IO ())
corpus = withObject "independent ZooKeeper3.9.3 encodings" $ \root -> do
  strings <- (root .: "jute_string_cases" :: Parser [Value]) >>= traverse (withObject "Jute string" $ \row ->
    (,,) <$> row .: "value" <*> row .: "encoded_bytes" <*> row .: "wire_bytes")
  nodes <- root .: "node_cases" >>= traverse (withObject "node" $ \row -> do
    name <- row .: "id"
    node <- parseNode (Object row)
    expected <- row .: "expected_wire_bytes"
    pure (name,node,expected))
  acls <- root .: "acl_cases" >>= traverse (withObject "ACL" $ \row -> do
    name <- row .: "id"
    acl <- ZkAcl <$> row .: "perms" <*> row .: "scheme" <*> row .: "identity"
    expected <- row .: "expected_wire_bytes"
    pure (name,acl,expected))
  let nodeMap = Map.fromList [(name,node) | (name,node,_) <- nodes]
      aclMap = Map.fromList [(name,acl) | (name,acl,_) <- acls]
      lookupInput domain key = maybe (fail ("unknown literal input "<>Text.unpack key)) pure (Map.lookup key domain)
  trees <- (root .: "tree_fixtures" :: Parser (Map.Map Text Value)) >>= traverse (withObject "tree inputs" $ \row -> do
    nodeIds <- row .: "nodes"
    ns <- traverse (lookupInput nodeMap) nodeIds
    ss <- row .: "sessions" >>= traverse (withObject "session" $ \session -> ZkSession <$> session .: "id" <*> session .: "timeout")
    cs <- row .: "acl_cache" >>= traverse (withObject "cached ACL" $ \cached -> do
      identity <- cached .: "id"
      names <- cached .: "acls"
      values <- traverse (lookupInput aclMap) names
      pure (identity,values))
    pure (ns,ss,cs))
  snapshots <- (root .: "snapshot_cases" :: Parser [Value]) >>= traverse (withObject "snapshot" $ \row -> do
    name <- row .: "id"
    tree <- row .: "tree"
    features <- ZkSnapshotFeatures <$> row .: "digest" <*> row .: "last_processed_zxid"
    expected <- row .: "expected_bytes"
    pure (name,tree,features,expected))
  components <- root .: "snapshot_component_expectations" :: Parser (Map.Map Text (Map.Map Text Natural))
  common <- root .: "transaction_common"
  path <- common .: "path"
  payload <- common .: "data_bytes"
  ephemeral <- common .: "ephemeral"
  aclNames <- common .: "acls"
  transactionAcls <- traverse (lookupInput aclMap) aclNames
  closePaths <- common .: "closed_session_paths"
  transactionRows <- root .: "transaction_cases" :: Parser [Value]
  namedRows <- traverse (withObject "named transaction" $ \row -> (,) <$> row .: "id" <*> pure (Object row)) transactionRows
  let rowMap = Map.fromList namedRows
      defaults = (path,payload,transactionAcls,ephemeral,closePaths)
  unless (Map.size rowMap == length namedRows) (fail "duplicate literal transaction identity")
  transactions <- traverse (withObject "transaction" $ \row -> do
    name <- row .: "id"
    operation <- parseTransaction defaults rowMap [] (String name)
    (,,,,) name operation <$> row .: "expected_body_bytes" <*> row .: "expected_without_digest" <*> row .: "expected_with_digest") transactionRows
  let txMap = Map.fromList [(name,operation) | (name,operation,_,_,_) <- transactions]
  historyRow <- root .: "history_case"
  historyIds <- historyRow .: "transaction_ids"
  historyOperations <- traverse (lookupInput txMap) historyIds
  historyCounts <- historyRow .: "counts"
  historyDigest <- historyRow .: "digest"
  historyStarts <- historyRow .: "log_generations"
  historyBytes <- historyRow .: "expected_serialized_history_bytes"
  let history = zip historyCounts historyOperations
  watchRow <- root .: "watch_cases"
  watchInputs <- watchRow .: "watches" >>= traverse (withObject "watch" $ \row -> do
    owner <- row .: "session"
    target <- row .: "path"
    kind <- row .: "type" >>= \name -> case (name :: Text) of
      "Data" -> pure DataWatch; "Children" -> pure ChildrenWatch; "Exists" -> pure ExistsWatch
      _ -> fail "unknown literal watch type"
    pure (ZkWatch owner target kind))
  watchLegacy <- watchRow .: "expected_set_watches_bytes"
  watchModern <- watchRow .: "expected_set_watches2_bytes"
  generation <- root .: "finite_generation_policy"
  policy <- ZkGenerationPolicy <$> generation .: "members" <*> generation .: "maximum_unavailable_members"
    <*> generation .: "normal_log_generations" <*> generation .: "incoming_log_generations" <*> generation .: "maximum_log_extent_bytes"
    <*> generation .: "normal_snapshot_generations" <*> generation .: "incoming_snapshot_generations" <*> generation .: "maximum_snapshot_extent_bytes"
    <*> generation .: "other_paths_allowance_bytes"
  cases <- generation .: "expected_case_slot_bytes" >>= traverse (withObject "fault case" $ \row ->
    (,) <$> row .: "failed_members" <*> row .: "slot_bytes")
  steady <- generation .: "expected_steady_bytes_per_member"
  incoming <- generation .: "expected_incoming_bytes_per_recovering_member"
  peak <- generation .: "expected_peak_bytes_per_member"
  rawMinimum <- generation .: "selected_raw_minimum_bytes"
  rawQuantum <- generation .: "selected_raw_quantum_bytes"
  rawDebit <- generation .: "expected_three_member_raw_debit_bytes"
  boundaries <- (root .: "one_unit_boundaries" :: Parser [Value]) >>= traverse (withObject "bound" $ \row ->
    (,,) <$> row .: "axis" <*> row .: "available" <*> row .: "expected")
  pure $ do
    mapM_ (\(value,encoded,wire) -> check "Jute UTF16-unit string framing"
      (maybe 0 juteEncodedBytes value == encoded && juteStringWireBytes value == wire)) strings
    mapM_ (\(_,node,expected) -> check "exact node framing" (zkNodeWireBytes node == expected)) nodes
    mapM_ (\(_,acl,expected) -> check "exact cached ACL entry" (zkAclWireBytes acl == expected)) acls
    subjectTrees <- traverse (\(ns,ss,cs) -> right (provisionZkTree ns ss cs [])) trees
    mapM_ (\(name,tree,features,expected) -> check name (maybe False ((==expected) . zkSnapshotBytes features) (Map.lookup tree subjectTrees))) snapshots
    mapM_ (\(name,expected) -> do
      tree' <- maybe (die "unknown snapshot component tree") pure (Map.lookup name subjectTrees)
      let actual = zkSnapshotComponents (ZkSnapshotFeatures True True) tree'
          names = [("header","file-header"),("session_table","sessions"),("acl_cache","acl-cache"),
            ("node_rows","node-rows"),("tree_end","tree-end"),("base_seal","base-seal"),
            ("digest_and_seal","digest-and-seal"),("last_zxid_and_seal","last-zxid-and-seal")]
          projected = Map.fromList ([(target,Map.findWithDefault 0 source actual) | (target,source) <- names]
            <> [("base_total",zkSnapshotBytes (ZkSnapshotFeatures False False) tree')])
      check "snapshot literal components" (projected == expected)) (Map.toList components)
    mapM_ (\(name,operation,body,without,with) -> do
      actualBody <- right (zkTransactionBodyBytes operation)
      actualWithout <- right (zkTransactionRecordBytes False operation)
      actualWith <- right (zkTransactionRecordBytes True operation)
      check name (actualBody == body && actualWithout == without && actualWith == with)) transactions
    actualHistory <- right (zkHistoryBytes historyDigest historyStarts history)
    check "complete serialized transaction history" (actualHistory == historyBytes && length historyCounts == length historyOperations)
    (ns,ss,cs) <- maybe (die "missing root_child_session literal") pure (Map.lookup "root_child_session" trees)
    tree <- right (provisionZkTree ns ss cs watchInputs)
    legacy <- right (zkWatchSetBytes False 1 tree)
    modern <- right (zkWatchSetBytes True 1 tree)
    check "watch vectors retain session/path/type identities" (legacy == watchLegacy && modern == watchModern)
    plan <- right (provisionZkGenerations policy)
    check "complete per-member recovery family and bytes" (zkGenerationCases plan == cases
      && zkGenerationSteadyBytes plan == steady && zkGenerationIncomingBytes plan == incoming
      && all (==peak) (Map.elems (zkGenerationSlotPeaks plan)))
    let generous = ZkCapacityBounds 1048576 1048576 1048576 32 4096 peak
        setBound axis available = case axis of
          "snapshot_bytes" -> generous {zkSnapshotCapacity = available}
          "serialized_history_bytes" -> generous {zkHistoryCapacity = available}
          "transaction_record_bytes" -> generous {zkRecordCapacity = available}
          "session_count" -> generous {zkSessionCapacity = available}
          "watch_count" -> generous {zkWatchCapacity = available}
          "member_usable_bytes" -> generous {zkMemberUsableCapacity = available}
          _ -> generous
        raw capacity = provisionZkRawClaims plan (StorageBacking (BackingId "zookeeper") capacity
          (BackingAllocationPolicy rawMinimum rawQuantum)) (FilesystemPresentation "ext4-v1" 500)
    mapM_ (\(axis,available,expected) -> if axis == "named_backing_bytes"
      then check axis (outcome (raw available) == expected)
      else check axis (outcome (provisionZkBounds (setBound axis available) (ZkSnapshotFeatures False False) tree historyDigest historyStarts history plan) == expected)) boundaries
    rawClaims <- right (raw rawDebit)
    check "uniform rounded claims debit only the named metadata backing" (uniformClaimBytesByBacking rawClaims == Map.singleton (BackingId "zookeeper") rawDebit)
    let bad label result = check label (outcome result == "reject")
    bad "duplicate path rejects" (provisionZkTree (ns<>take 1 ns) ss cs [])
    bad "duplicate session rejects" (provisionZkTree ns (ss<>ss) cs [])
    bad "duplicate ACL-cache identity rejects" (provisionZkTree ns ss (cs<>cs) [])
    bad "missing ephemeral owner rejects" (provisionZkTree ns [] cs [])
    bad "missing ACL reference rejects" (provisionZkTree ns ss [] [])
    bad "duplicate watch rejects" (provisionZkTree ns ss cs (watchInputs<>watchInputs))
    bad "missing watch owner rejects" (provisionZkTree ns ss cs [ZkWatch 2 "/a" DataWatch])
    bad "missing root rejects" (provisionZkTree (filter ((/="") . zkNodePath) ns) ss cs [])
    bad "missing parent rejects" (provisionZkTree [ZkNode "" 0 (-1) 0 PersistentNode,ZkNode "/a/b" 0 (-1) 0 PersistentNode] [] [] [])
    bad "nonASCII path profile rejects" (provisionZkTree [ZkNode "" 0 (-1) 0 PersistentNode,ZkNode "/π" 0 (-1) 0 PersistentNode] [] [] [])
    bad "steady cannot spend incoming logs" (provisionZkBounds generous (ZkSnapshotFeatures False False) tree historyDigest 4 history plan)
    check "unknown transaction reference rejects" (outcome (parseEither (parseTransaction defaults rowMap []) (String "absent")) == "reject")
    let cyclic = Map.singleton "cycle" (object ["operation" .= ("Multi" :: Text),"children" .= [String "cycle"]])
    check "cyclic transaction reference rejects" (outcome (parseEither (parseTransaction defaults cyclic []) (String "cycle")) == "reject")

type TransactionDefaults = (Text,Natural,[ZkAcl],Bool,[Text])

-- Resolve each literal child, including persisted Error arms, rather than
-- substituting a hard-coded successful multi transaction.
parseTransaction :: TransactionDefaults -> Map.Map Text Value -> [Text] -> Value -> Parser ZkTransaction
parseTransaction defaults rows seen (String name) = do
  unless (name `notElem` seen) (fail "cyclic literal transaction reference")
  value <- maybe (fail "unknown literal transaction reference") pure (Map.lookup name rows)
  parseTransaction defaults rows (name:seen) value
parseTransaction defaults@(defaultPath,defaultBytes,acls,ephemeral,closePaths) rows seen value =
  withObject "closed transaction operation" (\row -> do
    path <- row .:? "path" .!= defaultPath
    bytes <- row .:? "data_bytes" .!= defaultBytes
    operation <- row .: "operation" :: Parser Text
    case operation of
      "Create" -> pure (ZkCreate path bytes acls ephemeral)
      "CreateContainer" -> pure (ZkCreateContainer path bytes acls)
      "SetData" -> pure (ZkSetData path bytes)
      "Delete" -> pure (ZkDelete path)
      "DeleteContainer" -> pure (ZkDeleteContainer path)
      "CreateSession" -> pure ZkCreateSession
      "CloseSessionWithPaths" -> ZkCloseSessionWithPaths <$> row .:? "paths" .!= closePaths
      "SetACL" -> pure (ZkSetAcl path acls)
      "CheckVersion" -> pure (ZkCheckVersion path)
      "Error" -> ZkErrorTransaction <$> row .: "code"
      "Multi" -> ZkMulti <$> (row .: "children" >>= traverse (parseTransaction defaults rows seen))
      _ -> fail "unknown closed transaction operation") value

transactionAmendment :: Value -> Parser (IO ())
transactionAmendment = withObject "independent transaction/root amendment" $ \root -> do
  let defaults = ("/a",3,[ZkAcl 31 "world" "anyone"],False,[])
      operation = parseTransaction defaults Map.empty []
  cases <- (root .: "transaction_cases" :: Parser [Value]) >>= traverse (withObject "transaction expectation" $ \row -> do
    tx <- operation (Object row)
    (,,,,) <$> row .: "id" <*> pure tx <*> row .: "expected_body_bytes"
      <*> row .: "expected_without_digest" <*> row .: "expected_with_digest")
  watch <- root .: "root_watch_case"
  nodes <- watch .: "nodes" >>= traverse parseNode
  sessions <- watch .: "sessions" >>= traverse (withObject "root session" $ \row -> ZkSession <$> row .: "id" <*> row .: "timeout")
  watches <- watch .: "watches" >>= traverse (withObject "root watch" $ \row -> do
    kind <- row .: "type" :: Parser Text
    unless (kind == "Children") (fail "unsupported amendment watch type")
    ZkWatch <$> row .: "session" <*> row .: "path" <*> pure ChildrenWatch)
  legacy <- watch .: "expected_set_watches_bytes"
  modern <- watch .: "expected_set_watches2_bytes"
  snapshot <- watch .: "expected_base_snapshot_bytes"
  rejections <- root .: "format_rejections" :: Parser [Value]
  rejected <- traverse (withObject "format rejection" $ \row -> do
    name <- row .: "id" :: Parser Text
    action <- case name of
      "empty-watch-path" -> do
        owner <- row .: "session"; path <- row .: "path"
        pure (outcome (provisionZkTree nodes sessions [] [ZkWatch owner path ChildrenWatch]))
      "snapshot-slash-alias-is-not-a-second-root" ->
        pure (outcome (provisionZkTree (nodes<>[ZkNode "/" 0 (-1) 0 PersistentNode]) sessions [] []))
      "node-buffer-length-overflow" -> do
        bytes <- row .: "data_bytes"
        pure (outcome (provisionZkTree [ZkNode "" bytes (-1) 0 PersistentNode] [] [] []))
      _ -> do
        tx <- operation (Object row)
        digest <- row .:? "digest" .!= False
        pure (outcome (zkTransactionRecordBytes digest tx))
    expected <- row .: "expected"
    pure (name,action,expected)) rejections
  pure $ do
    mapM_ (\(name,tx,body,without,with) -> do
      b <- right (zkTransactionBodyBytes tx)
      w <- right (zkTransactionRecordBytes False tx)
      d <- right (zkTransactionRecordBytes True tx)
      check name (b == body && w == without && d == with)) cases
    tree <- right (provisionZkTree nodes sessions [] watches)
    l <- right (zkWatchSetBytes False 1 tree)
    m <- right (zkWatchSetBytes True 1 tree)
    check "API slash root retains its actual wire bytes" (l == legacy && m == modern
      && zkSnapshotBytes (ZkSnapshotFeatures False False) tree == snapshot)
    mapM_ (\(name,actual,expected) -> check name (actual == expected)) rejected
    check "unknown operation rejects" (outcome (parseEither operation (object ["operation" .= ("Unknown" :: Text)])) == "reject")

parseNode :: Value -> Parser ZkNode
parseNode = withObject "node with explicit owner kind" $ \row -> do
  owner <- row .: "ephemeral_owner"
  -- The original corpus predates container support and has only persistent
  -- and session-ephemeral rows. New kinds require their explicit literal tag.
  name <- row .:? "kind" .!= (if owner == (0 :: Integer) then "Persistent" else "SessionEphemeral" :: Text)
  kind <- case name of
    "Persistent" -> pure PersistentNode
    "Container" -> pure ContainerNode
    "SessionEphemeral" -> pure SessionEphemeralNode
    _ -> fail "unsupported ZooKeeper node kind"
  ZkNode <$> row .: "serialized_path" <*> row .: "data_bytes" <*> row .: "acl_id" <*> pure owner <*> pure kind

containers :: Value -> Parser (IO ())
containers = withObject "independent container amendment" $ \root -> do
  rows <- root .: "node_cases" :: Parser [Value]
  nodes <- traverse (withObject "named container node" $ \row ->
    (,,) <$> row .: "id" <*> parseNode (Object row) <*> row .: "expected_wire_bytes") rows
  let nodeMap = Map.fromList [(name,node) | (name,node,_) <- nodes]
  acl <- root .: "acl"
  aclId <- acl .: "id"
  entries <- acl .: "entries" >>= traverse (withObject "container ACL" $ \row ->
    ZkAcl <$> row .: "perms" <*> row .: "scheme" <*> row .: "identity")
  aclBytes <- acl .: "expected_entry_bytes"
  cacheBytes <- acl .: "expected_cache_bytes"
  snapshots <- (root .: "snapshot_cases" :: Parser [Value]) >>= traverse (withObject "container tree" $ \row -> do
    names <- row .: "nodes"
    ns <- traverse (\name -> maybe (fail "unknown container node") pure (Map.lookup name nodeMap)) names
    ss <- row .: "sessions" >>= traverse (withObject "container child session" $ \session ->
      ZkSession <$> session .: "id" <*> session .: "timeout")
    (,,,,) <$> row .: "id" <*> pure ns <*> pure ss <*> row .: "expected_base_bytes" <*> row .: "expected_digest_and_last_zxid_bytes")
  let defaults = ("/a",0,entries,False,[])
      operation = parseTransaction defaults Map.empty []
  transactions <- (root .: "transaction_cases" :: Parser [Value]) >>= traverse (withObject "container transaction" $ \row ->
    (,,,,) <$> row .: "id" <*> operation (Object row) <*> row .: "expected_body_bytes"
      <*> row .: "expected_without_digest" <*> row .: "expected_with_digest")
  rejectionNames <- root .: "rejections" >>= traverse (withObject "container rejection" (.: "id")) :: Parser [Text]
  pure $ do
    mapM_ (\(name,node,expected) -> check name (zkNodeWireBytes node == expected)) nodes
    check "container ACL literal" (sum (fmap zkAclWireBytes entries) == aclBytes)
    mapM_ (\(name,ns,ss,base,modern) -> do
      tree <- right (provisionZkTree ns ss [(aclId,entries)] [])
      check name (zkSnapshotBytes (ZkSnapshotFeatures False False) tree == base
        && zkSnapshotBytes (ZkSnapshotFeatures True True) tree == modern
        && Map.lookup "acl-cache" (zkSnapshotComponents (ZkSnapshotFeatures False False) tree) == Just cacheBytes)) snapshots
    mapM_ (\(name,tx,body,without,with) -> do
      b <- right (zkTransactionBodyBytes tx); w <- right (zkTransactionRecordBytes False tx); d <- right (zkTransactionRecordBytes True tx)
      check name (b == body && w == without && d == with)) transactions
    rootNode <- maybe (die "missing literal root") pure (Map.lookup "root" nodeMap)
    container <- maybe (die "missing literal container") pure (Map.lookup "container-parent" nodeMap)
    child <- maybe (die "missing literal child") pure (Map.lookup "persistent-child" nodeMap)
    let reject name = case name of
          "container-masquerades-as-session" -> outcome (provisionZkTree [rootNode,container {zkNodeSessionOwner=7}] [ZkSession 7 30000] [(aclId,entries)] [])
          "session-masquerades-as-container" -> outcome (provisionZkTree [rootNode,container {zkNodeKind=SessionEphemeralNode}] [] [(aclId,entries)] [])
          "normal-ephemeral-has-child" -> outcome (provisionZkTree [rootNode,container {zkNodeKind=SessionEphemeralNode,zkNodeSessionOwner=7},child] [ZkSession 7 30000] [(aclId,entries)] [])
          "negative-root-owner-is-not-acl" -> outcome (provisionZkTree [rootNode {zkNodeSessionOwner=(-1)}] [] [] [])
          "container-root-is-not-standard-root" -> outcome (provisionZkTree [rootNode {zkNodeKind=ContainerNode,zkNodeSessionOwner=zkNodeSessionOwner container}] [] [] [])
          "ttl-not-enabled-in-selected-profile" -> outcome (parseEither parseNode (object ["serialized_path" .= ("/ttl" :: Text),"data_bytes" .= (0 :: Int),"acl_id" .= (-1 :: Int),"ephemeral_owner" .= (1 :: Int),"kind" .= ("TTL" :: Text)]))
          _ -> "unknown rejection"
    mapM_ (\name -> check name (reject name == "reject")) rejectionNames

check :: Text -> Bool -> IO ()
check label condition = unless condition (die ("independent ZooKeeper case: "<>Text.unpack label))
outcome :: Either problem value -> Text
outcome = either (const "reject") (const "accept")
right :: Show problem => Either problem value -> IO value
right = either (die . show) pure
