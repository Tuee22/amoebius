{-# LANGUAGE OverloadedStrings #-}

-- | Pinned ZooKeeper3.9.3 CHECKED/plain serialization and finite retained
-- generations. These witnesses do not grant repair/start authority or infer
-- an actual producer inventory from a synthetic tree.
module Amoebius.Capacity.ZooKeeper
  ( ZkAcl (..), ZkNodeKind (..), ZkNode (..), ZkSession (..), ZkWatchKind (..), ZkWatch (..)
  , ZkSnapshotFeatures (..), ZkTree, ZkError (..)
  , provisionZkTree, juteEncodedBytes, juteStringWireBytes
  , zkNodeWireBytes, zkAclWireBytes
  , zkSnapshotComponents, zkSnapshotBytes, zkWatchSetBytes
  , ZkTransaction (..), zkTransactionBodyBytes, zkTransactionRecordBytes, zkHistoryBytes
  , ZkGenerationPolicy (..), ProvisionedZkGenerations, provisionZkGenerations
  , zkGenerationCases, zkGenerationSlotPeaks, zkGenerationSteadyBytes, zkGenerationIncomingBytes
  , ZkCapacityBounds (..), ProvisionedZkBounds, provisionZkBounds, zkBoundAxes
  , provisionZkRawClaims
  , zkPreallocationKiB, zkPaddedLogBytes
  ) where

import Control.Monad (unless)
import Amoebius.Capacity.Storage
import Amoebius.Capacity.StorageGeometry
  ( DeclaredVolumeDemand (..), StatefulSetClaimSlot (..), VolumeGeometry (..)
  , UniformClaimWitness, provisionVolume, uniformStatefulSetClaims )
import Data.Char (ord)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)

data ZkAcl = ZkAcl {zkAclPermissions :: Natural, zkAclScheme :: Text, zkAclIdentity :: Text}
  deriving stock (Eq, Show)

data ZkNodeKind = PersistentNode | ContainerNode | SessionEphemeralNode
  deriving stock (Eq, Show)

-- Empty path is the unique serialized root. ACL id -1 is the uncached open
-- arm. Container owner is a reserved wire sentinel, not a client session.
data ZkNode = ZkNode {zkNodePath :: Text, zkNodePayloadBytes :: Natural,
  zkNodeAclId :: Integer, zkNodeSessionOwner :: Integer, zkNodeKind :: ZkNodeKind}
  deriving stock (Eq, Show)
data ZkSession = ZkSession {zkSessionId :: Integer, zkSessionTimeout :: Natural}
  deriving stock (Eq, Show)
data ZkWatchKind = DataWatch | ExistsWatch | ChildrenWatch | PersistentWatch | PersistentRecursiveWatch
  deriving stock (Eq, Ord, Show)
data ZkWatch = ZkWatch {zkWatchSession :: Integer, zkWatchPath :: Text, zkWatchKind :: ZkWatchKind}
  deriving stock (Eq, Ord, Show)
data ZkSnapshotFeatures = ZkSnapshotFeatures {zkSnapshotDigest :: Bool, zkSnapshotLastZxid :: Bool}
  deriving stock (Eq, Show)
data ZkTree = ZkTree (Map Text ZkNode) (Map Integer ZkSession) (Map Integer [ZkAcl]) [ZkWatch]
  deriving stock (Eq, Show)
newtype ZkError = InvalidZkDemand Text
  deriving stock (Eq, Show)

-- Leave one filesystem block for the flushed16-byte log header and padding
-- trigger; the allocated file remains within its unchanged16MiB extent.
zkPreallocationKiB :: Natural
zkPreallocationKiB = 16380

zkPaddedLogBytes :: Natural -> Natural -> Natural -> Natural
zkPaddedLogBytes position current quantum
  | quantum > 0 && position+4096 >= current =
      if position > current then ((position+quantum) `div` quantum)*quantum else current+quantum
  | otherwise = current

-- Jute encodes each Java UTF16 code unit, including both surrogate units of
-- a supplementary code point. This is deliberately not UTF8 byte length.
juteEncodedBytes :: Text -> Natural
juteEncodedBytes = sum . fmap size . Text.unpack
 where
  size character | ord character < 128 = 1
                 | ord character < 2048 = 2
                 | ord character < 65536 = 3
                 | otherwise = 6

juteStringWireBytes :: Maybe Text -> Natural
juteStringWireBytes = (4 +) . maybe 0 juteEncodedBytes

provisionZkTree :: [ZkNode] -> [ZkSession] -> [(Integer,[ZkAcl])] -> [ZkWatch]
  -> Either ZkError ZkTree
provisionZkTree nodes sessions cache watches = do
  let nodeMap = Map.fromList [(zkNodePath node,node) | node <- nodes]
      sessionMap = Map.fromList [(zkSessionId session,session) | session <- sessions]
      cacheMap = Map.fromList cache
  ensure (length nodes == Map.size nodeMap && length sessions == Map.size sessionMap
    && length cache == Map.size cacheMap && length watches == Set.size (Set.fromList watches)) "duplicate tree/session/ACL/watch identity"
  ensure (Map.member "" nodeMap) "missing unique serialized root"
  mapM_ (\session -> ensure (zkSessionId session `notElem` [0,containerOwner] && signed64 (zkSessionId session)
    && zkSessionTimeout session > 0 && zkSessionTimeout session <= 2147483647) "invalid session") sessions
  mapM_ (\(identity,acls) -> do
    ensure (identity >= 0 && signed64 identity && not (null acls)) "invalid cached ACL identity/list"
    mapM_ validateAcl acls) cache
  mapM_ (\node -> do
    validateSerializedPath (zkNodePath node)
    ensure (zkNodePayloadBytes node <= 2147483647) "node buffer length exceeds Jute int32"
    ensure (zkNodeAclId node == -1 || Map.member (zkNodeAclId node) cacheMap) "missing node ACL"
    case zkNodeKind node of
      PersistentNode -> ensure (zkNodeSessionOwner node == 0) "persistent node owner must be zero"
      ContainerNode -> ensure (zkNodeSessionOwner node == containerOwner) "invalid container owner sentinel"
      SessionEphemeralNode -> ensure (zkNodeSessionOwner node `notElem` [0,containerOwner]
        && Map.member (zkNodeSessionOwner node) sessionMap) "missing ephemeral owner"
    ensure (zkNodePath node /= "" || zkNodeKind node == PersistentNode) "nonpersistent root"
    unless (zkNodePath node == "") $ do
      let parent = parentPath (zkNodePath node)
      ensure (Map.member parent nodeMap) "missing node parent"
      ensure (maybe False ((/=SessionEphemeralNode) . zkNodeKind) (Map.lookup parent nodeMap)) "ephemeral parent cannot have children") nodes
  mapM_ (\watch -> do
    validatePath (zkWatchPath watch)
    ensure (Map.member (zkWatchSession watch) sessionMap) "missing watch session owner"
    -- Exists/persistent watches can observe a legal path before creation.
    ensure (zkWatchKind watch `notElem` [DataWatch,ChildrenWatch] || Map.member (nodeKey (zkWatchPath watch)) nodeMap) "missing watched data/children node") watches
  pure (ZkTree nodeMap sessionMap cacheMap watches)

zkSnapshotComponents :: ZkSnapshotFeatures -> ZkTree -> Map Text Natural
zkSnapshotComponents features (ZkTree nodes sessions cache _) = Map.fromList
  [("file-header",16),("sessions",4+12*fromIntegral (Map.size sessions)),
   ("acl-cache",4+sum [12+sum (fmap aclBytes acls) | acls <- Map.elems cache]),
   ("node-rows",sum (fmap zkNodeWireBytes (Map.elems nodes))),
   ("tree-end",5),("base-seal",13),
   ("digest-and-seal",if zkSnapshotDigest features then 33 else 0),
   ("last-zxid-and-seal",if zkSnapshotLastZxid features then 21 else 0)]

zkSnapshotBytes :: ZkSnapshotFeatures -> ZkTree -> Natural
zkSnapshotBytes features = sum . Map.elems . zkSnapshotComponents features

zkWatchSetBytes :: Bool -> Integer -> ZkTree -> Either ZkError Natural
zkWatchSetBytes modern owner (ZkTree _ sessions _ watches) = do
  ensure (Map.member owner sessions) "unknown watch-set session"
  let selected = filter ((==owner) . zkWatchSession) watches
  ensure (modern || all ((`notElem` [PersistentWatch,PersistentRecursiveWatch]) . zkWatchKind) selected) "persistent watch requires SetWatches2"
  pure (8+(if modern then 20 else 12)+sum [juteStringWireBytes (Just (zkWatchPath watch)) | watch <- selected])

data ZkTransaction = ZkCreate Text Natural [ZkAcl] Bool | ZkCreateContainer Text Natural [ZkAcl]
  | ZkSetData Text Natural | ZkDelete Text | ZkDeleteContainer Text
  | ZkCreateSession | ZkCloseSessionWithPaths [Text] | ZkSetAcl Text [ZkAcl] | ZkCheckVersion Text
  | ZkErrorTransaction Integer | ZkMulti [ZkTransaction]
  deriving stock (Eq, Show)

zkTransactionBodyBytes :: ZkTransaction -> Either ZkError Natural
zkTransactionBodyBytes transaction = case transaction of
  ZkCreate path bytes acls _ -> do
    validatePath path; ensure (bytes <= 2147483647) "transaction buffer length exceeds Jute int32"; mapM_ validateAcl acls
    pure (17+juteEncodedBytes path+bytes+sum (fmap aclBytes acls))
  ZkCreateContainer path bytes acls -> do
    validatePath path; ensure (bytes <= 2147483647) "transaction buffer length exceeds Jute int32"; mapM_ validateAcl acls
    pure (16+juteEncodedBytes path+bytes+sum (fmap aclBytes acls))
  ZkSetData path bytes -> do
    validatePath path; ensure (bytes <= 2147483647) "transaction buffer length exceeds Jute int32"
    pure (12+juteEncodedBytes path+bytes)
  ZkDelete path -> validatePath path >> pure (4+juteEncodedBytes path)
  ZkDeleteContainer path -> validatePath path >> pure (4+juteEncodedBytes path)
  ZkCreateSession -> pure 4
  ZkCloseSessionWithPaths paths -> do
    mapM_ validatePath paths
    ensure (length paths == Set.size (Set.fromList paths)) "duplicate close-session path"
    pure (4+sum (fmap (juteStringWireBytes . Just) paths))
  ZkSetAcl path acls -> do
    validatePath path; mapM_ validateAcl acls
    pure (12+juteEncodedBytes path+sum (fmap aclBytes acls))
  ZkCheckVersion path -> validatePath path >> pure (8+juteEncodedBytes path)
  ZkErrorTransaction code -> ensure (code >= -2147483648 && code <= 2147483647) "invalid error int32" >> pure 4
  ZkMulti children -> do
    ensure (not (null children) && all legalChild children) "empty/nested/session multi transaction"
    sizes <- traverse zkTransactionBodyBytes children
    pure (4+sum [8+bytes | bytes <- sizes])
 where
  legalChild child = case child of
    ZkCreate {} -> True; ZkSetData {} -> True; ZkDelete {} -> True; ZkCheckVersion {} -> True; ZkErrorTransaction {} -> True
    _ -> False

zkTransactionRecordBytes :: Bool -> ZkTransaction -> Either ZkError Natural
zkTransactionRecordBytes digest transaction = do
  body <- zkTransactionBodyBytes transaction
  let payload = 32+body+if digest then 12 else 0
  ensure (payload <= 2147483647) "transaction record length exceeds Jute int32"
  pure (13+payload)

zkHistoryBytes :: Bool -> Natural -> [(Natural,ZkTransaction)] -> Either ZkError Natural
zkHistoryBytes digest generations history = do
  ensure (generations > 0 && all ((>0) . fst) history) "invalid history generation/count"
  bytes <- traverse (\(count,transaction) -> (count*) <$> zkTransactionRecordBytes digest transaction) history
  pure (16*generations+sum bytes)

data ZkGenerationPolicy = ZkGenerationPolicy
  { zkMembers :: [Natural], zkMaximumUnavailable :: Natural
  , zkNormalLogGenerations :: Natural, zkIncomingLogGenerations :: Natural, zkMaximumLogExtent :: Natural
  , zkNormalSnapshotGenerations :: Natural, zkIncomingSnapshotGenerations :: Natural, zkMaximumSnapshotExtent :: Natural
  , zkOtherPathsAllowance :: Natural }
  deriving stock (Eq, Show)
data ProvisionedZkGenerations = ProvisionedZkGenerations ZkGenerationPolicy
  [([Natural],Map Natural Natural)] (Map Natural Natural) Natural Natural
  deriving stock (Eq, Show)

provisionZkGenerations :: ZkGenerationPolicy -> Either ZkError ProvisionedZkGenerations
provisionZkGenerations policy = do
  let members = zkMembers policy
  ensure (length members >= 3 && odd (length members) && length members == Set.size (Set.fromList members)
    && zkMaximumUnavailable policy > 0 && zkMaximumUnavailable policy <= fromIntegral (length members - (length members `div` 2+1))) "invalid ensemble/fault family"
  ensure (all (>0) [zkNormalLogGenerations policy,zkIncomingLogGenerations policy,zkMaximumLogExtent policy,
    zkNormalSnapshotGenerations policy,zkIncomingSnapshotGenerations policy,zkMaximumSnapshotExtent policy,zkOtherPathsAllowance policy]) "zero generation/extent bound"
  let steady = zkNormalLogGenerations policy*zkMaximumLogExtent policy
        +zkNormalSnapshotGenerations policy*zkMaximumSnapshotExtent policy+zkOtherPathsAllowance policy
      incoming = zkIncomingLogGenerations policy*zkMaximumLogExtent policy
        +zkIncomingSnapshotGenerations policy*zkMaximumSnapshotExtent policy
      cases = [(failed,Map.fromList [(member,steady+if member `elem` failed then incoming else 0) | member <- members])
        | failed <- concatMap (`choose` members) [0..zkMaximumUnavailable policy]]
      peaks = Map.unionsWith max (fmap snd cases)
  pure (ProvisionedZkGenerations policy cases peaks steady incoming)

zkGenerationCases :: ProvisionedZkGenerations -> [([Natural],Map Natural Natural)]
zkGenerationCases (ProvisionedZkGenerations _ cases _ _ _) = cases
zkGenerationSlotPeaks :: ProvisionedZkGenerations -> Map Natural Natural
zkGenerationSlotPeaks (ProvisionedZkGenerations _ _ peaks _ _) = peaks
zkGenerationSteadyBytes :: ProvisionedZkGenerations -> Natural
zkGenerationSteadyBytes (ProvisionedZkGenerations _ _ _ steady _) = steady
zkGenerationIncomingBytes :: ProvisionedZkGenerations -> Natural
zkGenerationIncomingBytes (ProvisionedZkGenerations _ _ _ _ incoming) = incoming

-- | Binding compares subject-derived dimensions with independently offered
-- limits. Tree/current-state and full-history producer completeness remain
-- inputs to establish separately; these comparisons cannot infer a replay.
data ZkCapacityBounds = ZkCapacityBounds
  { zkSnapshotCapacity :: Natural, zkHistoryCapacity :: Natural, zkRecordCapacity :: Natural
  , zkSessionCapacity :: Natural, zkWatchCapacity :: Natural, zkMemberUsableCapacity :: Natural }
  deriving stock (Eq, Show)
data ProvisionedZkBounds = ProvisionedZkBounds ZkCapacityBounds ZkTree ZkSnapshotFeatures Bool Natural
  [(Natural,ZkTransaction)] ProvisionedZkGenerations (Map Text Natural)
  deriving stock (Eq, Show)

provisionZkBounds :: ZkCapacityBounds -> ZkSnapshotFeatures -> ZkTree -> Bool -> Natural
  -> [(Natural,ZkTransaction)] -> ProvisionedZkGenerations -> Either ZkError ProvisionedZkBounds
provisionZkBounds offered features tree@(ZkTree _ sessions _ watches) digest logStarts history generations@(ProvisionedZkGenerations policy _ peaks _ _) = do
  ensure (logStarts <= zkNormalLogGenerations policy) "steady history cannot spend incoming log generations"
  serialized <- zkHistoryBytes digest logStarts history
  records <- traverse (zkTransactionRecordBytes digest . snd) history
  let largest = maximum (0:records)
      snapshot = zkSnapshotBytes features tree
      axes = Map.fromList [("snapshot_bytes",snapshot),("serialized_history_bytes",serialized),
        ("transaction_record_bytes",largest),("session_count",fromIntegral (Map.size sessions)),
        ("watch_count",fromIntegral (length watches)),("member_usable_bytes",maximum (0:Map.elems peaks))]
      available = Map.fromList [("snapshot_bytes",zkSnapshotCapacity offered),("serialized_history_bytes",zkHistoryCapacity offered),
        ("transaction_record_bytes",zkRecordCapacity offered),("session_count",zkSessionCapacity offered),
        ("watch_count",zkWatchCapacity offered),("member_usable_bytes",zkMemberUsableCapacity offered)]
  ensure (snapshot <= zkMaximumSnapshotExtent policy) "snapshot exceeds retained generation extent"
  -- A whole finite history plus its largest next record remains below the
  -- preallocation threshold even if concentrated into a single generation.
  ensure (serialized+largest+4096 < zkMaximumLogExtent policy) "history can cross the pinned preallocation extent"
  mapM_ (\(axis,required) -> ensure (required <= Map.findWithDefault 0 axis available) ("capacity-short:"<>axis)) (Map.toList axes)
  pure (ProvisionedZkBounds offered tree features digest logStarts history generations axes)

zkBoundAxes :: ProvisionedZkBounds -> Map Text Natural
zkBoundAxes (ProvisionedZkBounds _ _ _ _ _ _ _ axes) = axes

provisionZkRawClaims :: ProvisionedZkGenerations -> StorageBacking -> FilesystemPresentation
  -> Either ZkError UniformClaimWitness
provisionZkRawClaims generations backing presentation = do
  let demands = [DeclaredVolumeDemand ("zookeeper-"<>Text.pack (show member))
        (StatefulSetClaimSlot "zookeeper" "data" member) backing bytes (DirectGeometry 1) presentation
        | (member,bytes) <- Map.toList (zkGenerationSlotPeaks generations)]
  either (Left . InvalidZkDemand . Text.pack . show) Right (traverse provisionVolume demands >>= uniformStatefulSetClaims)

aclBytes :: ZkAcl -> Natural
aclBytes acl = 12+juteEncodedBytes (zkAclScheme acl)+juteEncodedBytes (zkAclIdentity acl)
zkAclWireBytes :: ZkAcl -> Natural
zkAclWireBytes = aclBytes
zkNodeWireBytes :: ZkNode -> Natural
zkNodeWireBytes node = 76+juteEncodedBytes (zkNodePath node)+zkNodePayloadBytes node
validateAcl :: ZkAcl -> Either ZkError ()
validateAcl acl = ensure (zkAclPermissions acl <= 31 && not (Text.null (zkAclScheme acl))) "invalid ACL"
validatePath :: Text -> Either ZkError ()
validatePath path = ensure (path == "/" || Text.isPrefixOf "/" path && not (Text.isSuffixOf "/" path)
  && all (\part -> part /= "" && part /= "." && part /= "..") (Text.splitOn "/" (Text.drop 1 path))
  && Text.all (\character -> ord character >= 32 && ord character < 127) path) "invalid ASCII path profile"
validateSerializedPath :: Text -> Either ZkError ()
validateSerializedPath path = if path == "" then Right () else
  validatePath path >> ensure (path /= "/") "serialized root must use its unique empty alias"
nodeKey :: Text -> Text
nodeKey path = if path == "/" then "" else path
parentPath :: Text -> Text
parentPath = Text.dropEnd 1 . Text.dropWhileEnd (/='/')
signed64 :: Integer -> Bool
signed64 value = value >= -9223372036854775808 && value <= 9223372036854775807
containerOwner :: Integer
containerOwner = -9223372036854775808
ensure :: Bool -> Text -> Either ZkError ()
ensure condition message = unless condition (Left (InvalidZkDemand message))
choose :: Natural -> [value] -> [[value]]
choose 0 _ = [[]]
choose _ [] = []
choose count (first:rest) = fmap (first:) (choose (count-1) rest) <> choose count rest
