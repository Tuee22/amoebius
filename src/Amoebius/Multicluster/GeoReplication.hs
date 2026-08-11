{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Multicluster.GeoReplication
  ( ReplicatedStage (..)
  , ReplicatedRecord (..)
  , FoldedWorkflow
  , GeoReplicationError (..)
  , representativeBatch
  , duplicateReorderedBatch
  , foldReplicated
  , foldedWorkId
  , foldedOrderedStages
  , foldedBlobKeys
  , foldedDigest
  ) where

import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Char (intToDigit)
import Data.List (sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text
import Data.Word (Word8)

data ReplicatedStage = Command | Event Int | Result
  deriving stock (Eq, Ord, Show)

data ReplicatedRecord = ReplicatedRecord
  { replicatedWorkId :: Text
  , replicatedStage :: ReplicatedStage
  , replicatedPayload :: ByteString
  }
  deriving stock (Eq, Show)

data FoldedWorkflow = FoldedWorkflow
  { foldedWorkId :: Text
  , foldedOrderedStages :: [Text]
  , foldedBlobKeys :: [Text]
  , foldedDigest :: Text
  }
  deriving stock (Eq, Show)

data GeoReplicationError
  = EmptyReplicationBatch
  | MixedWorkIds
  | ConflictingDuplicate ReplicatedStage
  | IncompleteWorkflow [Text]
  deriving stock (Eq, Show)

representativeBatch :: [ReplicatedRecord]
representativeBatch =
  [ record Command "phase42-command"
  , record (Event 1) "transform:alpha"
  , record (Event 2) "transform:beta"
  , record Result "phase42-result:alpha+beta"
  ]
 where
  record stage payload = ReplicatedRecord "work-42-canary" stage payload

duplicateReorderedBatch :: [ReplicatedRecord]
duplicateReorderedBatch =
  [ representativeBatch !! 3
  , representativeBatch !! 1
  , representativeBatch !! 0
  , representativeBatch !! 2
  , representativeBatch !! 1
  , representativeBatch !! 3
  , representativeBatch !! 0
  ]

foldReplicated :: [ReplicatedRecord] -> Either GeoReplicationError FoldedWorkflow
foldReplicated [] = Left EmptyReplicationBatch
foldReplicated records@(first : _)
  | any ((/= replicatedWorkId first) . replicatedWorkId) records = Left MixedWorkIds
  | otherwise = do
      unique <- foldUnique Map.empty records
      let ordered = sortOn (stageRank . fst) (Map.toList unique)
          stageNames = map (stageName . fst) ordered
          required = ["command", "event-1", "event-2", "result"]
      if stageNames /= required
        then Left (IncompleteWorkflow stageNames)
        else
          let canonical = Text.unlines [stage <> "=" <> Text.decodeUtf8 payload | (stageValue, payload) <- ordered, let stage = stageName stageValue]
           in Right FoldedWorkflow
                { foldedWorkId = replicatedWorkId first
                , foldedOrderedStages = stageNames
                , foldedBlobKeys = map (contentKey . snd) ordered
                , foldedDigest = contentKey (Text.encodeUtf8 canonical)
                }

foldUnique
  :: Map ReplicatedStage ByteString
  -> [ReplicatedRecord]
  -> Either GeoReplicationError (Map ReplicatedStage ByteString)
foldUnique accumulated [] = Right accumulated
foldUnique accumulated (record : rest) = case Map.lookup (replicatedStage record) accumulated of
  Nothing -> foldUnique (Map.insert (replicatedStage record) (replicatedPayload record) accumulated) rest
  Just existing
    | existing == replicatedPayload record -> foldUnique accumulated rest
    | otherwise -> Left (ConflictingDuplicate (replicatedStage record))

stageRank :: ReplicatedStage -> Int
stageRank stage = case stage of
  Command -> 0
  Event index -> index
  Result -> maxBound

stageName :: ReplicatedStage -> Text
stageName stage = case stage of
  Command -> "command"
  Event index -> "event-" <> Text.pack (show index)
  Result -> "result"

contentKey :: ByteString -> Text
contentKey bytes = "sha256:" <> Text.pack (concatMap hexByte (ByteString.unpack (SHA256.hash bytes)))

hexByte :: Word8 -> String
hexByte byte = [intToDigit (fromIntegral byte `div` 16), intToDigit (fromIntegral byte `mod` 16)]
