{-# LANGUAGE OverloadedStrings #-}

-- | Independently authored Phase-23 expectations. This module deliberately
-- imports no production security-law evaluator, identity, scope, store, or key
-- type.
module ExtensionSecurityLawsOracle
  ( operationCases
  , namespaceCases
  , revocationCases
  , expectedVerdicts
  , mutationProperties
  , expectedFixtureSignature
  , oracleContentAddress
  ) where

import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Builder qualified as Builder
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import Numeric (showHex)
import Numeric.Natural (Natural)

operationCases :: [(Text, Text, Text, Natural)]
operationCases =
  [ (operation, target, result operation target, mutation operation target)
  | operation <- ["Read", "Update", "Delete", "Replay", "CacheLookup"]
  , target <- ["own-record", "foreign-record", "absent-record"]
  ]
 where
  result operation target
    | target /= "own-record" = "deny:resource-unavailable"
    | operation == "Read" = "allow:own-value"
    | operation == "Update" = "allow:updated"
    | operation == "Delete" = "allow:deleted"
    | operation == "Replay" = "allow:replayed:own-value"
    | otherwise = "allow:cached:own-value"
  mutation operation target
    | target == "own-record" && operation `elem` ["Update", "Delete"] = 1
    | otherwise = 0

namespaceCases :: [(Text, Text, Text, Text, Text, Text, Text)]
namespaceCases =
  [ ("RowKey", "ab", "c", "d", "a", "bc", "d")
  , ("ObjectPrefix", "tenant-a", "subject", "object", "tenant", "a-subject", "object")
  , ("TopicName", "xy", "z", "topic", "x", "yz", "topic")
  , ("CacheKey", "cache-left", "owner", "entry", "cache", "left-owner", "entry")
  , ("ReplayKey", "replay-left", "owner", "command", "replay", "left-owner", "command")
  ]

revocationCases :: [(Text, Text, Text, Bool)]
revocationCases =
  [ ("socket-cache", "edge", "membership-epoch", True)
  , ("offline-partition", "bound", "300", True)
  ]

expectedVerdicts :: [(Text, [Text])]
expectedVerdicts =
  [ ("lawful", pass)
  , ("s1-tampered-accepted", failure 0 "FAIL:TamperedIdentityWasAccepted")
  , ("s2-caller-scope", failure 1 "FAIL:SkolemBarrierMissing")
  , ("s3-unscoped-arm", failure 2 "FAIL:UnscopedOperationArmExported")
  , ("s4-distinguishable", failure 3 "FAIL:RefusalBytesDiffer")
  , ("s5-key-collapse", failure 4 "FAIL:NamespaceCollision")
  , ("s6-policy-omitted", failure 5 "FAIL:RevocationPolicyMissing")
  ]
 where
  pass = replicate 6 "PASS"
  failure index value = take index pass <> [value] <> drop (index + 1) pass

mutationProperties :: [(Text, Text, Text)]
mutationProperties =
  [ ("ignore-s1", "S1", "AttestedIdentityOnly")
  , ("ignore-s2", "S2", "SkolemScopeOnly")
  , ("ignore-s3", "S3", "RefusalByDefault")
  , ("ignore-s4", "S4", "IndistinguishableRefusal")
  , ("ignore-s5", "S5", "InjectiveNamespace")
  , ("ignore-s6", "S6", "RevocationBound")
  ]

expectedFixtureSignature :: Text -> Text -> Text
expectedFixtureSignature tenant subject =
  digest (frame (map Encoding.encodeUtf8 ["security-law-fixture-key", tenant, subject]))

oracleContentAddress :: [Text] -> Text
oracleContentAddress = digest . Encoding.encodeUtf8 . Text.intercalate "\NUL"

frame :: [ByteString] -> ByteString
frame = LazyByteString.toStrict . Builder.toLazyByteString . foldMap framed
 where
  framed bytes = Builder.word64BE (fromIntegral (ByteString.length bytes)) <> Builder.byteString bytes

digest :: ByteString -> Text
digest = Text.pack . concatMap hexByte . ByteString.unpack . SHA256.hash

hexByte :: (Integral byte, Show byte) => byte -> String
hexByte byte = case showHex byte "" of
  [single] -> ['0', single]
  digits -> digits
