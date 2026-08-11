{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Pulumi.Backend.EncryptedMinio
  ( PulumiCheckpointDemand (..)
  , ProvisionedCheckpoint
  , CheckpointError (..)
  , provisionCheckpoint
  , checkpointPeakBytes
  , checkpointObjectIdentities
  , admitCheckpointWrite
  ) where

import Data.Text (Text)

data PulumiCheckpointDemand = PulumiCheckpointDemand
  { checkpointStackId :: Text
  , checkpointRevisionBytes :: Integer
  , checkpointRetainedRevisions :: Integer
  , checkpointOrphanBytes :: Integer
  }
  deriving stock (Eq, Show)

data ProvisionedCheckpoint = ProvisionedCheckpoint
  { checkpointPeakBytes :: Integer
  , checkpointObjectIdentities :: [Text]
  }
  deriving stock (Eq, Show)

data CheckpointError
  = InvalidCheckpointDemand
  | CheckpointStorageShort
  | DirectCheckpointWriteDenied
  deriving stock (Eq, Show)

provisionCheckpoint
  :: Integer
  -> PulumiCheckpointDemand
  -> Either CheckpointError ProvisionedCheckpoint
provisionCheckpoint available demand
  | any (< 0)
      [ checkpointRevisionBytes demand
      , checkpointRetainedRevisions demand
      , checkpointOrphanBytes demand
      ] = Left InvalidCheckpointDemand
  | available < peak = Left CheckpointStorageShort
  | otherwise = Right ProvisionedCheckpoint
      { checkpointPeakBytes = peak
      , checkpointObjectIdentities =
          [ checkpointStackId demand <> "/current"
          , checkpointStackId demand <> "/previous"
          , checkpointStackId demand <> "/orphan"
          ]
      }
 where
  peak = checkpointRevisionBytes demand * checkpointRetainedRevisions demand + checkpointOrphanBytes demand

admitCheckpointWrite :: Bool -> Either CheckpointError ()
admitCheckpointWrite throughGateway
  | throughGateway = Right ()
  | otherwise = Left DirectCheckpointWriteDenied
