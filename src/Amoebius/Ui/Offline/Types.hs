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

data Operation
  = InfernixStart
  | JitmlTrainingStart
  | WorkflowProgress
  | MlSignal
  | WorkflowCancel
  | ModelInvocation
  deriving stock (Eq, Ord, Show, Enum, Bounded)

newtype PortId = PortId String
  deriving stock (Eq, Ord, Show)

newtype Projection = Projection String
  deriving stock (Eq, Ord, Show)

newtype BlobClass = BlobClass String
  deriving stock (Eq, Ord, Show)

data QueueContract = QueueContract
  { maxCount :: Int
  , maxBytes :: Int
  , maxAgeSeconds :: Int
  , idempotencyRule :: String
  , conflictRule :: String
  , orderRule :: String
  , dependencyRule :: String
  , authoritativeValidation :: String
  }
  deriving stock (Eq, Show)

data QueuedPort = QueuedPort Operation QueueContract
  deriving stock (Eq, Show)

data OfflineSource = OfflineSource
  { cachedProjections :: [Projection]
  , queuedPorts :: [QueuedPort]
  , localBlobClasses :: [BlobClass]
  }
  deriving stock (Eq, Show)

data Continuity = OnlineOnly | Offline OfflineSource
  deriving stock (Eq, Show)

operationPort :: Operation -> PortId
operationPort operation = PortId $ case operation of
  InfernixStart -> "infernix-start"
  JitmlTrainingStart -> "jitml-training-start"
  WorkflowProgress -> "workflow-progress"
  MlSignal -> "ml-signal"
  WorkflowCancel -> "workflow-cancel"
  ModelInvocation -> "model-invocation"
