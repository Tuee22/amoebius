{-# LANGUAGE OverloadedStrings #-}

module RuntimePolicyBindingSpec (verifyRuntimePolicyBinding) where

import Amoebius.Capacity.ObjectStore
import Amoebius.Capacity.Storage
import Amoebius.Platform.S3Admission
import Control.Monad (foldM, unless)
import Data.Aeson
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KM
import Data.Aeson.Types (Parser, parseEither)
import Data.ByteString.Lazy qualified as Lazy
import Data.Either (isLeft)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)
import System.Exit (die)

verifyRuntimePolicyBinding :: Value -> Map.Map Text ObjectWriterAdmission -> IO ()
verifyRuntimePolicyBinding projection admissions = do
  literal <- Lazy.readFile "test/oracle/platform_backbone_runtime_policy.json" >>= right . eitherDecode
  (funding,paired) <- right $ parseEither (withObject "independent runtime policy cases" $ \root ->
    (,) <$> ((root .: "funding_cases" :: Parser [Value]) >>= traverse fundingCase)
        <*> ((root .: "paired_projection_rejections" :: Parser [Value]) >>= traverse (withObject "paired case" (.: "id")))) literal
  sequence_ funding
  policy <- right (gatewayPolicyFromStorage projection)
  let modelPath = ["objectStorePeak","writerAdmissions","pulsar-offload","model"]
      model = getPath modelPath projection
      mirrored value = edit modelPath (const value) . edit ["objectStorePeak","sourceModels","pulsar-offload"] (const value)
      coalesce = rows $ \values -> case filter (has "kind" "FailedOrphanObjects") values of
        first:_ -> filter (not . has "kind" "FailedOrphanObjects") values
          <> [set "count" (toJSON (1 :: Int)) (set "maximumBytes" (toJSON (2097152 :: Int)) first)]
        [] -> values
      coalesceMerged = rows $ \values -> filter (not . has "source" "pulsar-offload") values
        <> valuesOf (coalesce (toJSON (filter (has "source" "pulsar-offload") values)))
      shrink = rows (fmap (\row -> if has "kind" "FutureObjects" row && (not (hasField "source" row) || has "source" "pulsar-offload" row)
        then set "maximumBytes" (toJSON (1048575 :: Int)) row else row))
      changed name = case name of
        "coalesced-failure-objects" -> edit ["objectStorePeak","writerAdmissions","pulsar-offload","populations"] coalesce
          (edit ["objectStorePeak","populations"] coalesceMerged projection)
        "missing-merged-physical-resident" -> edit ["objectStorePeak","residents"] (rows (drop 1)) projection
        "conflicting-merged-resident-bytes" -> edit ["objectStorePeak","residents"] (rows (\values -> case values of
          first:rest -> addByte first:rest; [] -> [])) projection
        "unsupported-model-mirrored" -> mirrored (String "unsupported") projection
        "changed-future-class-on-both-sides" -> edit ["objectStorePeak","writerAdmissions","pulsar-offload","populations"] shrink
          (edit ["objectStorePeak","populations"] shrink projection)
        "model-populations-disagree" -> mirrored (set "admissionExtentQuantum" (toJSON (524288 :: Int)) model) projection
        _ -> Null
  mapM_ (\name -> if name == "small-registry-maxfuture-private-success" then do
      admission <- maybe (die "small registry writer missing") pure (Map.lookup "registry" admissions)
      let key = "docker/registry/v2/blobs/sha256/11/"<>Text.replicate 64 "1"<>"/data"
      _ <- right (reserveObjectWrite admission "registry" (emptyObjectWriterState admission)
        (PhysicalObjectId "root-minio" "platform" "registry" key) (Just (FutureObjects,"post-cutover-blob")) 65536)
      _ <- right (beginWrite policy emptyGatewayState RegistryWriter ("/registry/"<>key) 65536 ("sha256:"<>Text.replicate 64 "1"))
      pure ()
    else do
      let modified = changed name
      check name (modified /= Null && modified /= projection && isLeft (gatewayPolicyFromStorage modified))) paired
  amendment <- Lazy.readFile "test/oracle/platform_backbone_runtime_policy_amendment.json" >>= right . eitherDecode
  (base,positive,cases) <- right $ parseEither (withObject "independent binding amendment" $ \root ->
    (,,) <$> root .: "base_fixture" <*> root .: "positive_control" <*> (root .: "cases" :: Parser [Value])) amendment
  let registryRows = valuesOf (getPath ["objectStorePeak","writerAdmissions","registry","populations"] projection)
      appRows = valuesOf (getPath ["objectStorePeak","writerAdmissions","application-canary","populations"] projection)
  right $ parseEither (withObject "base inputs" $ \root -> do
    quota <- root .: "application_quota"
    unless (quota == getPath ["objectStorePeak","writerAdmissions","application-canary","quota"] projection)
      (fail "amendment base quota differs")
    references <- traverse (root .:) ["registry_failed_base","registry_failed_excess"]
    app <- root .: "application_populations"
    appReferences <- traverse (app .:) ["future","concurrent","failed"]
    unless (all (\reference -> length (filter (matches reference) registryRows) == 1) references
      && all (\reference -> length (filter (matches reference) appRows) == 1) appReferences)
      (fail "amendment base populations differ")) base
  (key,proof,bytes,selection,path) <- right $ parseEither (withObject "fresh positive control" $ \row -> do
    selected <- row .: "private_selection"
    kind <- selected .: "kind" :: Parser Text
    unless (kind == "FutureObjects") (fail "wrong literal selection")
    (,,,,) <$> row .: "fresh_key" <*> row .: "digest" <*> row .: "maximumBytes"
      <*> selected .: "name" <*> row .: "public_path") positive
  registryAdmission <- maybe (die "registry admission missing") pure (Map.lookup "registry" admissions)
  _ <- right (reserveObjectWrite registryAdmission "registry" (emptyObjectWriterState registryAdmission)
    (PhysicalObjectId "root-minio" "platform" "registry" key) (Just (FutureObjects,selection)) bytes)
  _ <- right (beginWrite policy emptyGatewayState RegistryWriter path bytes proof)
  mapM_ (\row -> do
    (name,edits,expected) <- right $ parseEither (withObject "paired amendment" $ \value ->
      (,,) <$> value .: "id" <*> (value .: "edits" :: Parser [Value]) <*> value .: "expected") row
    modified <- right (foldM applyEdit projection edits)
    check name (expected == ("reject" :: Text) && modified /= projection && isLeft (gatewayPolicyFromStorage modified))) cases

fundingCase :: Value -> Parser (IO ())
fundingCase = withObject "literal object-slot funding" $ \row -> do
  name <- row .: "id"
  claims <- row .: "claims_bytes" :: Parser [Natural]
  slots <- row .: "declared_slots" >>= traverse (withObject "slot" $ \slot -> (,) <$> slot .: "count" <*> slot .: "maximumBytes")
  expected <- row .: "expected_slot_fit"
  groupInput <- row .:? "authorized_group_input"
  grouped <- traverse (withObject "approved registry slice grouping" $ \group -> do
    base <- ObjectPopulation <$> group .: "base_name" <*> group .: "base_count" <*> group .: "base_bytes" <*> pure 3600
    excess <- ObjectPopulation <$> group .: "excess_name" <*> group .: "excess_count" <*> group .: "excess_bytes" <*> pure 3600
    pure [base,excess]) groupInput
  pure $ do
    let populations' = [ObjectPopulation ("slot-"<>Text.pack (show i)) n b 3600 | (i,(n,b)) <- zip [0 :: Int ..] slots]
        source = ApplicationSource (ObjectSourceDemand "test" "test" (SourceScope "s" "t" "b")
          (ProviderObjectQuota (BudgetId "test") "s" (1024*1048576) 1000000) Map.empty
          [ObjectPopulation "claims" (fromIntegral (length claims)) (maximum claims) 0] populations' [] populations')
    peak <- right (foldObjectStoreSources (Set.singleton "test") [source])
    admission <- maybe (die "literal writer missing") pure (Map.lookup "test" (objectStoreWriterAdmissions peak))
    let attempt state (i,bytes) = fst <$> reserveObjectWrite admission "test" state
          (PhysicalObjectId "s" "t" "b" (Text.pack (show i))) (Just (FutureObjects,"claims")) bytes
        result = foldM attempt (emptyObjectWriterState admission) (zip [0 :: Int ..] claims)
    check name (either (const False) (const True) result == expected)
    case grouped of
      Nothing -> pure ()
      Just original -> do
        actual <- right (registryPopulationSlots FailedOrphanObjects original)
        check "approved named grouping keeps funded count/whole extent" (fmap (\p -> (populationCount p,populationMaximumBytes p)) actual == slots)

edit :: [Text] -> (Value -> Value) -> Value -> Value
edit [] change value = change value
edit (key:rest) change (Object fields) = Object $ case KM.lookup (Key.fromText key) fields of
  Nothing -> fields
  Just value -> KM.insert (Key.fromText key) (edit rest change value) fields
edit _ _ value = value
set :: Text -> Value -> Value -> Value
set key value (Object fields) = Object (KM.insert (Key.fromText key) value fields)
set _ _ value = value
getPath :: [Text] -> Value -> Value
getPath [] value = value
getPath (key:rest) (Object fields) = maybe Null (getPath rest) (KM.lookup (Key.fromText key) fields)
getPath _ _ = Null
has :: Text -> Text -> Value -> Bool
has key value row = getPath [key] row == String value
hasField :: Text -> Value -> Bool
hasField key (Object fields) = KM.member (Key.fromText key) fields
hasField _ _ = False
valuesOf :: Value -> [Value]
valuesOf (Array values) = foldr (:) [] values
valuesOf _ = []
rows :: ([Value] -> [Value]) -> Value -> Value
rows change value@(Array _) = toJSON (change (valuesOf value))
rows _ value = value
addByte :: Value -> Value
addByte value = case parseEither (withObject "resident bytes" (.: "bytes")) value :: Either String Natural of
  Right bytes -> set "bytes" (toJSON (bytes+1)) value
  Left _ -> value
matches :: Value -> Value -> Bool
matches (Object selected) (Object candidate) = all (\(key,value) -> KM.lookup key candidate == Just value) (KM.toList selected)
matches _ _ = False
applyEdit :: Value -> Value -> Either String Value
applyEdit current = parseEither (withObject "literal isolated edit" $ \row -> do
  operation <- row .: "operation" :: Parser Text
  let existing path = let value = getPath path current in if value == Null then fail "edit path absent" else pure value
  result <- case operation of
    "set_value" -> do
      path <- row .: "path"; value <- row .: "value"; _ <- existing path
      pure (edit path (const value) current)
    "copy_value" -> do
      from <- row .: "from_path"; target <- row .: "to_path"
      value <- existing from; _ <- existing target
      pure (edit target (const value) current)
    "copy_value_to_map_entry" -> do
      from <- row .: "from_path"; target <- row .: "map_path"; key <- row .: "key"
      value <- existing from; old <- existing target
      case old of
        Object fields | not (KM.member (Key.fromText key) fields) -> pure (edit target (set key value) current)
        _ -> fail "copy target is not an owned new map key"
    "replace_population_fields" -> do
      local <- row .: "local_path"; merged <- row .: "merged_path"
      localSelector <- row .: "local_selector"; mergedSelector <- row .: "merged_selector"
      fields <- row .: "fields"
      left <- existing local; right' <- existing merged
      unless (length (filter (matches localSelector) (valuesOf left)) == 1
        && length (filter (matches mergedSelector) (valuesOf right')) == 1)
        (fail "population edit must match exactly once on each side")
      let change selector = rows (fmap (\value -> if matches selector value then
            foldl (\updated (key,field) -> set (Key.toText key) field updated) value (KM.toList fields) else value))
      pure (edit local (change localSelector) (edit merged (change mergedSelector) current))
    _ -> fail "unsupported literal edit operation"
  unless (result /= current) (fail "literal edit made no change")
  pure result)
check :: Text -> Bool -> IO ()
check name condition = unless condition (die ("runtime policy case: "<>Text.unpack name))
right :: Show problem => Either problem value -> IO value
right = either (die . show) pure
