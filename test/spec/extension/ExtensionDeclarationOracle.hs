{-# LANGUAGE OverloadedStrings #-}

module ExtensionDeclarationOracle
  ( OracleRow (..)
  , declarationCases
  , oracleDeclarationDigest
  ) where

import Amoebius.Capacity.Types (ResourceVector (..))
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Builder qualified as Builder
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import Numeric (showHex)

-- | Independently authored semantic projection.  This module deliberately does
-- not import the production extension declaration or composition modules.
data OracleRow = OracleRow
  { oracleExtension :: Text
  , oracleCalculus :: Text
  , oracleComponent :: Text
  , oracleResource :: ResourceVector
  , oracleDescriptor :: Text
  , oracleIdentityFields :: [Text]
  }
  deriving stock (Eq, Ord, Show)

declarationCases :: [(Text, [OracleRow])]
declarationCases =
  [ ("infernix",
      [ row "infernix" "artifact" "infernix-image" 2 1024 20 1
          "RecipeId {recipeName = \"infernix-image\", recipeRevision = 3}" ["recipe", "infernix-image", "3"]
      , row "infernix" "budget" "inference-budget" 1 512 5 1
          "Allowance {allowanceCeiling = Bytes 4096, allowanceConcurrency = Slots 2, allowancePerItem = Bytes 2048}" ["allowance", "4096", "2", "2048"]
      , row "infernix" "lift" "inference-layer" 0 0 0 0 "InContainer" ["layer", "in-container"]
      , row "infernix" "workflow" "inference-workflow" 1 256 1 1
          "Ledger {ledgerArms = [], ledgerProvisioned = [], ledgerReleased = []}" ["ledger", "arms", "0", "provisioned", "0", "released", "0"]
      , row "infernix" "evidence" "inference-evidence" 0 0 0 0 "SimulationRegister" ["register", "simulation"]
      ])
  , ("jitml",
      [ row "jitml" "artifact" "jitml-model" 4 2048 40 1
          "RecipeId {recipeName = \"jitml-model\", recipeRevision = 5}" ["recipe", "jitml-model", "5"]
      , row "jitml" "budget" "training-budget" 2 1024 10 1
          "Allowance {allowanceCeiling = Bytes 8192, allowanceConcurrency = Slots 3, allowancePerItem = Bytes 4096}" ["allowance", "8192", "3", "4096"]
      , row "jitml" "lift" "training-layer" 0 0 0 0 "InFrame" ["layer", "in-frame"]
      , row "jitml" "workflow" "training-workflow" 1 512 2 1
          "Ledger {ledgerArms = [], ledgerProvisioned = [], ledgerReleased = []}" ["ledger", "arms", "0", "provisioned", "0", "released", "0"]
      , row "jitml" "evidence" "training-evidence" 0 0 0 0 "BoundaryRegister" ["register", "boundary"]
      ])
  ]
 where
  row extension calculus component cpu memory ephemeral pods descriptor identity =
    OracleRow extension calculus component (ResourceVector cpu memory ephemeral pods) descriptor identity

-- | Independent SHA-256 implementation of the declaration's documented
-- versioned, length-framed semantic identity.
oracleDeclarationDigest :: Text -> [OracleRow] -> Text
oracleDeclarationDigest name rows =
  Text.pack (concatMap hexByte (ByteString.unpack (SHA256.hash canonicalBytes)))
 where
  canonicalBytes = frame ("amoebius-extension-declaration-v1" : Encoding.encodeUtf8 name : concatMap fields rows)
  fields oracleRow =
    [ Encoding.encodeUtf8 (oracleCalculus oracleRow)
    , Encoding.encodeUtf8 (oracleComponent oracleRow)
    , decimalBytes (resourceCpu resources)
    , decimalBytes (resourceMemory resources)
    , decimalBytes (resourceEphemeralStorage resources)
    , decimalBytes (resourcePodSlots resources)
    ] <> fmap Encoding.encodeUtf8 (oracleIdentityFields oracleRow)
   where resources = oracleResource oracleRow

frame :: [ByteString] -> ByteString
frame = LazyByteString.toStrict . Builder.toLazyByteString . foldMap framed
 where framed bytes = Builder.word64BE (fromIntegral (ByteString.length bytes)) <> Builder.byteString bytes

decimalBytes :: Show number => number -> ByteString
decimalBytes = Encoding.encodeUtf8 . Text.pack . show

hexByte :: (Integral byte, Show byte) => byte -> String
hexByte byte = case showHex byte "" of
  [single] -> ['0', single]
  digits -> digits
