{-# LANGUAGE OverloadedStrings #-}

module ZooKeeperHistorySpec (verifyZooKeeperHistory) where

import Amoebius.Platform.ZooKeeperHistory
import Amoebius.Platform.S3Signing (sha256Hex)
import Control.Monad (foldM, unless)
import Data.Aeson
import Data.Aeson.Types (Parser, parseEither)
import Data.ByteString qualified as BS
import Data.ByteString.Builder qualified as Builder
import Data.ByteString.Lazy qualified as Lazy
import Data.Int (Int32, Int64)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import Numeric (readHex)
import Numeric.Natural (Natural)
import System.Exit (die)

verifyZooKeeperHistory :: IO ()
verifyZooKeeperHistory = do
  value <- Lazy.readFile "test/oracle/platform_backbone_zookeeper_history.json" >>= right . eitherDecode
  (policy,records,digests,cases) <- right $ parseEither (withObject "independent history transition corpus" $ \root -> do
    p <- root .: "policy"
    policy <- withObject "policy operands" (\row -> do
      members <- row .: "members"; snapshot <- row .: "snapshotExtentMaximum"; bootstrap <- row .: "bootstrapAllowance"
      physical <- row .: "perMemberLifetimePhysicalMaximumFramedBytes"
      logs <- row .: "lifetimeDistinctLogNamesPerMember"; snaps <- row .: "lifetimeDistinctSnapshotNamesPerMember"
      admitted <- either (fail . Text.unpack) pure (historyPolicy members snapshot bootstrap physical logs snaps)
      expected <- row .: "globalUniqueMaximumFramedBytes"
      unless (historyUniqueLimit admitted == expected) (fail "independent unique-byte limit mismatch")
      pure admitted) p
    records <- (root .: "records" :: Parser (Map.Map Text Value)) >>= traverse materialize
    (,,,) policy records <$> root .: "digests" <*> (root .: "cases" :: Parser [Value])) value
  mapM_ (verify policy records digests) cases
  verifyPolicyAmendment records
 where
  verify policy records digests row = do
    (name,actions,expected) <- right $ parseEither (withObject "transition sequence" $ \fields ->
      (,,) <$> fields .: "id" <*> (fields .: "actions" :: Parser [Value]) <*> fields .: "expectedFinal") row
    final <- foldM (step name policy records digests) (emptyHistoryState policy) actions
    summary <- right (historyStateSummary policy final)
    check name (summary == expected)
    encoded <- right (historyStateValue policy final)
    restored <- right (decodeHistoryState policy encoded)
    check name (restored == final)
  step name policy records digests state row = do
    (operation,member,count,expected,reason) <- right $ parseEither (withObject "literal transition" $ \fields ->
      (,,,,) <$> fields .: "operation" <*> fields .: "member" <*> fields .:? "repeat" .!= 1
        <*> fields .:? "expect" .!= ("allow" :: Text) <*> fields .:? "reason") row
    if operation == ("restart_roundtrip" :: Text)
      then right (historyStateValue policy state >>= decodeHistoryState policy)
      else do
        command <- right $ parseEither (withObject "literal command inputs" $ \fields -> do
          recordName <- fields .:? "record"
          body <- case recordName of
            Nothing -> pure Null
            Just key -> do
              original <- maybe (fail "unknown literal record") pure (Map.lookup key records)
              bytes <- fields .:? "canonicalBytesOverride" .!= historyCanonicalBytes original
              pure (object ["zxid" .= historyZxid original,"canonicalSha256" .= historyCanonicalSha256 original,"canonicalBytes" .= bytes])
          digestName <- fields .:? "digest"
          digest <- case digestName of
            Nothing -> pure Null
            Just key -> maybe (fail "unknown literal digest") (pure . String) (Map.lookup key (digests :: Map.Map Text Text))
          generation <- fields .:? "name"
          pure (object ["operation" .= operation,"member" .= (member :: Natural),"mutation" .= body,
            "digest" .= digest,"name" .= (generation :: Maybe Text)])) row
        foldM (\current _ -> do
          let result = historyCommandFromValue command >>= applyHistoryCommand policy current
          case result of
            Left problem -> do
              check name (expected == "deny" && maybe False (`Text.isInfixOf` problem) reason)
              pure current
            Right next -> check name (expected == "allow") >> pure next) state [1..count :: Int]

verifyPolicyAmendment :: Map.Map Text HistoryMutation -> IO ()
verifyPolicyAmendment records = do
  bytes <- Lazy.readFile "test/oracle/platform_backbone_zookeeper_history.json"
  amendment <- Lazy.readFile "test/oracle/platform_backbone_zookeeper_history_policy.json" >>= right . eitherDecode
  (digest,policies,cases,positive,negative) <- right $ parseEither (withObject "independent policy-binding amendment" $ \root ->
    (,,,,) <$> root .: "baseCorpusSha256" <*> (root .: "policies" >>= traverse parsePolicy)
      <*> (root .: "cross_policy_cases" :: Parser [Value]) <*> root .: "restart_positive"
      <*> (root .: "restart_rejection_cases" :: Parser [Value])) amendment
  check "amendment-original-corpus" (sha256Hex (Lazy.toStrict bytes) == Encoding.encodeUtf8 digest)
  let lookupPolicy name = maybe (die "unknown literal policy") pure (Map.lookup name (policies :: Map.Map Text HistoryPolicy))
      lookupRecord name = maybe (die "unknown literal record") pure (Map.lookup name records)
  mapM_ (\row -> do
    (name,originName,targetName,seeds,member,operation,recordName,expected,decodeName,generation,unique) <- right $ parseEither
      (withObject "policy cross-over" $ \fields -> do
        operation <- fields .: "operation" :: Parser Text
        target <- if operation == "serialize-then-decode" then fields .: "serializePolicy" else fields .: "underPolicy"
        (,,,,,,,,,,) <$> fields .: "id" <*> fields .: "originPolicy" <*> pure target <*> fields .: "seedReservations"
          <*> (fields .:? "member" .!= 0) <*> pure operation <*> fields .:? "mutation" <*> fields .: "expectedAdmission"
          <*> (fields .:? "decodePolicy" .!= target) <*> fields .:? "name" <*> fields .:? "expectedGlobalUniqueFramedBytesUnchanged") row
    origin <- lookupPolicy originName; target <- lookupPolicy targetName
    decoding <- lookupPolicy decodeName
    mutations <- traverse lookupRecord (seeds :: [Text])
    seeded <- right (foldM (\state mutation -> reserveHistoryMutation origin state 0 mutation) (emptyHistoryState origin) mutations)
    case unique of
      Nothing -> pure ()
      Just total -> do
        summary <- right (historyStateSummary origin seeded)
        actual <- right (parseEither (withObject "state summary" (.: "globalUniqueFramedBytes")) summary)
        check name (actual == (total :: Natural))
    mutation <- maybe (pure Nothing) (fmap Just . lookupRecord) recordName
    let result = case (operation :: Text,mutation) of
          ("reserve",Just record) -> reserveHistoryMutation target seeded member record
          ("apply",Just record) -> admitHistoryApplication target seeded member record
          ("append_attempt",Just record) -> reserveHistoryAppend target seeded member record (historyCanonicalBytes record+25)
          ("open_generation",_) -> maybe (Left "literal generation name missing")
            (reserveHistoryGeneration target seeded member HistoryLog) generation
          ("serialize-then-decode",_) -> historyStateValue target seeded >>= decodeHistoryState decoding
          _ -> Left "invalid literal cross-policy operation"
    case result of
      Left problem -> check name (expected == ("deny" :: Text) && "state-policy-mismatch" `Text.isInfixOf` problem)
      Right _ -> check name (expected == "allow")) cases
  native <- lookupPolicy "native"
  valid <- right $ parseEither (withObject "restart positive" (.: "serializedState")) positive
  restored <- right (decodeHistoryState native valid)
  serialized <- right (historyStateValue native restored)
  check "restart-positive-roundtrip" (serialized == valid)
  mapM_ (\row -> do
    (name,saved) <- right $ parseEither (withObject "malformed restart" $ \fields -> (,) <$> fields .: "id" <*> fields .: "serializedState") row
    case decodeHistoryState native saved of Left _ -> pure (); Right _ -> die ("malformed history state admitted: " <> Text.unpack name)) negative

parsePolicy :: Value -> Parser HistoryPolicy
parsePolicy = withObject "retained policy operands" $ \row -> do
  policy <- historyPolicy <$> row .: "members" <*> row .: "snapshotBytes" <*> row .: "bootstrapBytes"
    <*> row .: "physicalBytesPerMember" <*> row .: "logGenerationsPerMember" <*> row .: "snapshotGenerationsPerMember"
  admitted <- either (fail . Text.unpack) pure policy
  unless (historyPolicyValue admitted == Object row) (fail "literal complete policy differs")
  pure admitted

materialize :: Value -> Parser HistoryMutation
materialize = withObject "independent original canonical transaction" $ \row -> do
  input <- row .: "input"
  (zxid,bytes) <- withObject "canonical wire operands" (\fields -> do
    (owner,cxid,zxid,time,kind) <- fields .: "header" >>= withObject "TxnHeader" (\header -> (,,,,)
      <$> header .: "clientId" <*> header .: "cxid" <*> header .: "zxid" <*> header .: "time" <*> header .: "type")
    body <- fields .: "operation" >>= withObject "Txn body" (\operation -> do
      tag <- operation .: "kind" :: Parser Text
      case tag of
        "CreateSession" -> Builder.int32BE <$> operation .: "timeout"
        "SetData" -> do
          path <- operation .: "path"
          unless (Text.all (< '\128') path) (fail "literal identity outside selected ASCII wire profile")
          let pathBytes = Encoding.encodeUtf8 path
          payload <- operation .: "data" >>= withObject "literal payload" (\payload -> BS.replicate <$> payload .: "count" <*> payload .: "repeatByte")
          version <- operation .: "version"
          pure (Builder.int32BE (fromIntegral (BS.length pathBytes)) <> Builder.byteString pathBytes
            <> Builder.int32BE (fromIntegral (BS.length payload)) <> Builder.byteString payload <> Builder.int32BE version)
        _ -> fail "unsupported literal transaction")
    let header = Builder.int64BE (owner :: Int64) <> Builder.int32BE (cxid :: Int32) <> Builder.int64BE zxid
          <> Builder.int64BE (time :: Int64) <> Builder.int32BE (kind :: Int32)
    unless ((zxid :: Int64) > 0) (fail "literal zxid must be positive")
    pure (fromIntegral zxid,Lazy.toStrict (Builder.toLazyByteString (header<>body)))) input
  size <- row .: "canonicalBytes"; digest <- row .: "canonicalSha256"; framed <- row .: "maximumModernFramedBytes"
  unless (BS.length bytes == size && sha256Hex bytes == Encoding.encodeUtf8 digest && framed == size+25)
    (fail "literal canonical wire/hash/size mismatch")
  literal <- row .:? "canonicalHex"
  case literal of
    Nothing -> pure ()
    Just hex -> do decoded <- decodeHex hex; unless (decoded == bytes) (fail "literal canonical hex differs")
  pure (HistoryMutation zxid digest (fromIntegral size))

decodeHex :: Text -> Parser BS.ByteString
decodeHex text = BS.pack <$> go (Text.unpack text)
 where
  go [] = pure []
  go (first:second:rest) = case readHex [first,second] of [(byte,"")] -> (byte:) <$> go rest; _ -> fail "invalid literal hex"
  go _ = fail "odd literal hex"
check :: Text -> Bool -> IO ()
check name condition = unless condition (die ("independent history transition: " <> Text.unpack name))
right :: Show problem => Either problem value -> IO value
right = either (die . show) pure
