{-# LANGUAGE OverloadedStrings #-}

module ZooKeeperMemberSpec (verifyZooKeeperMembers) where

import Amoebius.Capacity.Execution
import Amoebius.Capacity.Storage
import Amoebius.Capacity.Types
import Amoebius.Capacity.ZooKeeper
import Amoebius.Platform.Provision
import Amoebius.Platform.S3Signing (sha256Hex)
import Control.Monad (foldM, unless)
import Data.Aeson
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KM
import Data.Aeson.Types (Parser, parseEither)
import Data.ByteString.Lazy qualified as Lazy
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Numeric.Natural (Natural)
import System.Exit (die)

verifyZooKeeperMembers :: IO ()
verifyZooKeeperMembers = do
  originalBytes <- Lazy.readFile "test/oracle/platform_backbone_zookeeper_members.json"
  value <- right (eitherDecode originalBytes)
  (variants,cases) <- right (parseEither (withObject "independent metadata member corpus" $ \root ->
    (,) <$> root .: "variants" <*> (root .: "cases" :: Parser [Value])) value)
  amendment <- Lazy.readFile "test/oracle/platform_backbone_zookeeper_members_amendment.json" >>= right . eitherDecode
  (digest,extra,identities) <- right (parseEither (withObject "independent member amendment" $ \root ->
    (,,) <$> root .: "baseCorpusSha256" <*> (root .: "cases" :: Parser [Value])
      <*> (root .: "expectedIdentityRows" :: Parser (Map.Map Text Value))) amendment)
  unless (sha256Hex (Lazy.toStrict originalBytes) == TextEncoding.encodeUtf8 digest) (die "member amendment base corpus mismatch")
  mapM_ (verify variants identities) (cases<>extra)
 where
  verify variants identities row = do
    (name,base,edits,expected,required) <- right $ parseEither (withObject "literal member case" $ \fields ->
      (,,,,) <$> fields .: "id" <*> fields .: "base" <*> (fields .: "edits" :: Parser [Value]) <*> fields .: "expected" <*> fields .:? "required") row
    original <- maybe (die "unknown independent member variant") pure (Map.lookup base (variants :: Map.Map Text Value))
    edited <- right (foldM applyEdit original edits)
    demand <- right (parseEither parseDemand edited)
    case provisionZkMembers demand of
      Left problem -> unless (expected == ("reject" :: Text)) (die (Text.unpack name <> ": " <> Text.unpack problem))
      Right admitted -> do
        unless (expected == "accept" && Just (zkMemberProjection admitted) == required)
          (die ("independent metadata member expectation: " <> Text.unpack name))
        unless (Just (zkMemberIdentityProjection admitted) == Map.lookup base identities)
          (die ("independent metadata identity expectation: " <> Text.unpack name))

parseDemand :: Value -> Parser ZkMemberDemand
parseDemand = withObject "metadata member inputs" $ \root -> do
  controller <- root .: "controller"
  (source,revision,replicas) <- withObject "expanded metadata controller" (\row -> do
    kind <- row .: "kind"; rollout <- row .: "rollout"
    unless (kind == ("StatefulSet" :: Text) && rollout == ("OnDelete" :: Text)) (fail "unsupported fixture controller")
    (,,) <$> row .: "source" <*> row .: "revision" <*> row .: "replicas") controller
  requests <- root .: "perMemberRequests" >>= vector
  limits <- root .: "perMemberLimits" >>= vector
  headroom <- root .: "perMemberHeadroom" >>= vector
  envelope <- either (fail . show) pure (mkResourceEnvelope requests limits headroom)
  executors <- root .: "executors" >>= traverse (withObject "actual executor" $ \row -> do
    ordinal <- row .: "ordinal"
    identity <- row .: "instanceId"; owner <- row .: "source"; rev <- row .: "revision"
    resources <- row .: "resources" >>= vector
    ZkMemberExecutor (MaterializedExecutionInstance identity owner rev ordinal (Text.pack (show (ordinal :: Natural))) resources)
      <$> row .: "podName")
  supplies <- root .: "memberSupplies" >>= traverse (withObject "member supply" $ \row ->
    (,) <$> row .: "ordinal" <*> (row .: "available" >>= vector))
  claims <- root .: "claims" >>= traverse (withObject "actual PVC/backing slot" $ \row ->
    ZkMemberClaim <$> row .: "ordinal" <*> row .: "namespace" <*> row .: "statefulSet" <*> row .: "template"
      <*> row .: "claimId" <*> (BackingId <$> row .: "backingId") <*> row .: "availableUsableBytes" <*> row .: "availableRawBytes")
  backings <- root .: "backings" >>= traverse (withObject "retained leaf" $ \row ->
    ZkMemberBacking <$> (BackingId <$> row .: "id") <*> (BackingId <$> row .: "parent") <*> row .: "availableRawBytes")
  parent <- root .: "parentBacking" >>= withObject "parent pool" (\row ->
    StorageBacking <$> (BackingId <$> row .: "id") <*> row .: "availableRawBytes" <*> pure (BackingAllocationPolicy 1 1))
  members <- root .: "memberOrdinals"
  unavailable <- root .: "maximumUnavailable"
  policy <- root .: "generationPolicy" >>= withObject "retained and incoming generations" (\row ->
    ZkGenerationPolicy members unavailable <$> row .: "normalLogGenerations" <*> row .: "incomingLogGenerations"
      <*> row .: "maximumLogExtent" <*> row .: "normalSnapshotGenerations" <*> row .: "incomingSnapshotGenerations"
      <*> row .: "maximumSnapshotExtent" <*> row .: "otherPathsAllowance")
  (presentation,allocation) <- root .: "presentation" >>= withObject "common filesystem template" (\row ->
    (,) <$> (FilesystemPresentation "ext4-v1" <$> row .: "overheadBasisPoints")
      <*> (BackingAllocationPolicy <$> row .: "allocationMinimumBytes" <*> row .: "allocationQuantumBytes"))
  pure (ZkMemberDemand (BoundExecutionUnit source revision envelope (StatefulSetBody replicas StatefulSetOnDelete))
    executors supplies claims backings parent policy presentation allocation)

vector :: Value -> Parser ResourceVector
vector = withObject "resource axes" $ \row -> ResourceVector
  <$> row .: "cpuMillis" <*> row .: "memoryBytes" <*> row .: "ephemeralBytes" <*> row .: "podSlots"

-- Literal corpus edits preserve arrays until the owning constructor checks
-- duplicates and omissions. Converting them to maps first would lose cases.
applyEdit :: Value -> Value -> Either String Value
applyEdit original = parseEither (withObject "literal member input edit" $ \row -> do
  operation <- row .: "operation" :: Parser Text
  path <- row .: "path"
  replacement <- case operation of
    "set" -> Just <$> row .: "value"
    "remove" -> pure Nothing
    _ -> fail "unsupported member edit"
  either fail pure (alter path replacement original))

alter :: [Value] -> Maybe Value -> Value -> Either String Value
alter (String key:rest) replacement (Object fields) = do
  let k = Key.fromText key
  old <- maybe (Left "member edit object key absent") Right (KM.lookup k fields)
  case rest of
    [] -> pure (Object (maybe (KM.delete k fields) (\value -> KM.insert k value fields) replacement))
    _ -> do next <- alter rest replacement old; pure (Object (KM.insert k next fields))
alter (offset@Number{}:rest) replacement (Array fields) = do
  index <- parseEither parseJSON offset :: Either String Int
  let values = foldr (:) [] fields
  unless (index >= 0 && index < length values) (Left "member edit array index absent")
  changed <- case rest of
    [] -> pure (maybe [] pure replacement)
    _ -> pure <$> alter rest replacement (values !! index)
  pure (toJSON (take index values <> changed <> drop (index+1) values))
alter _ _ _ = Left "invalid member edit path"

right :: Show problem => Either problem value -> IO value
right = either (die . show) pure
