{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Ui.Offline.Types
  ( BlobClass (..)
  , Continuity (..)
  , OfflineSource (..)
  , Operation (..)
  , PortId (..)
  , Projection (..)
  , QueueContract (..)
  , QueuedPort (..)
  , operationPort
  ) where

import Data.Text (Text)
import Dhall qualified
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data Operation
  = InfernixStart
  | JitmlTrainingStart
  | WorkflowProgress
  | MlSignal
  | WorkflowCancel
  | ModelInvocation
  deriving stock (Bounded, Enum, Eq, Ord, Show, Generic)
  deriving anyclass (Dhall.FromDhall)

newtype PortId = PortId Text
  deriving stock (Eq, Ord, Show)

newtype Projection = Projection
  { projectionId :: Text
  }
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (Dhall.FromDhall)

newtype BlobClass = BlobClass
  { blobClassId :: Text
  }
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (Dhall.FromDhall)

data QueueContract = QueueContract
  { maxCount :: Natural
  , maxBytes :: Natural
  , maxAgeSeconds :: Natural
  , localValidation :: Text
  , idempotency :: Text
  , conflict :: Text
  , ordering :: Text
  , dependency :: Text
  , authoritativeValidation :: Text
  }
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (Dhall.FromDhall)

data QueuedPort = QueuedPort
  { operation :: Operation
  , contract :: QueueContract
  }
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (Dhall.FromDhall)

data OfflineSource = OfflineSource
  { projections :: [Projection]
  , queuedPorts :: [QueuedPort]
  , localBlobs :: [BlobClass]
  , offlineView :: Text
  }
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (Dhall.FromDhall)

data Continuity = OnlineOnly | Offline OfflineSource
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (Dhall.FromDhall)

operationPort :: Operation -> PortId
operationPort selected = PortId $ case selected of
  InfernixStart -> "infernix-start"
  JitmlTrainingStart -> "jitml-training-start"
  WorkflowProgress -> "workflow-progress"
  MlSignal -> "ml-signal"
  WorkflowCancel -> "workflow-cancel"
  ModelInvocation -> "model-invocation"
