{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

module Amoebius.Sim.Env
  ( Env (..)
  , Topic (..)
  , MessageId (..)
  , Message (..)
  , BlobKey (..)
  , PutCondition (..)
  , BlobResult (..)
  , ObjectName (..)
  , ResourceVersion (..)
  , ApplyResult (..)
  , WatchResult (..)
  , DnsName (..)
  , DnsValue (..)
  , DnsResult (..)
  , VaultPath (..)
  , VaultOp (..)
  , VaultResult (..)
  , FaultKnob (..)
  , TraceEvent (..)
  , InvariantOutcome (..)
  ) where

import Data.Aeson (FromJSON, ToJSON)
import Data.Text (Text)
import Data.Time.Clock (UTCTime)
import GHC.Generics (Generic)

newtype Topic = Topic {unTopic :: Text}
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (FromJSON, ToJSON)

newtype MessageId = MessageId {unMessageId :: Int}
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (FromJSON, ToJSON)

data Message = Message
  { messageId :: MessageId
  , messagePayload :: Text
  }
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (FromJSON, ToJSON)

newtype BlobKey = BlobKey {unBlobKey :: Text}
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (FromJSON, ToJSON)

data PutCondition = Unconditional | IfNoneMatch
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (FromJSON, ToJSON)

data BlobResult = BlobStored | BlobPreconditionFailed412
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (FromJSON, ToJSON)

newtype ObjectName = ObjectName {unObjectName :: Text}
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (FromJSON, ToJSON)

newtype ResourceVersion = ResourceVersion {unResourceVersion :: Int}
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (FromJSON, ToJSON)

data ApplyResult
  = ObjectApplied ResourceVersion
  | ResourceVersionConflict ResourceVersion
  | ApplyCrashed
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (FromJSON, ToJSON)

data WatchResult
  = WatchObjects [(ObjectName, ResourceVersion, Text)]
  | WatchGap ResourceVersion
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (FromJSON, ToJSON)

newtype DnsName = DnsName {unDnsName :: Text}
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (FromJSON, ToJSON)

newtype DnsValue = DnsValue {unDnsValue :: Text}
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (FromJSON, ToJSON)

data DnsResult = DnsWritten | DnsHasNoCAS
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (FromJSON, ToJSON)

newtype VaultPath = VaultPath {unVaultPath :: Text}
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (FromJSON, ToJSON)

data VaultOp = VaultRead VaultPath | VaultWrite VaultPath Text
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (FromJSON, ToJSON)

data VaultResult = VaultValue (Maybe Text) | VaultRejectedSealed
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (FromJSON, ToJSON)

data FaultKnob = Delay | Reorder | Duplicate | Partition | Crash
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (FromJSON, ToJSON)

data TraceEvent
  = Published Message
  | PublishPartitioned Message
  | Consumed [MessageId]
  | ConsumePartitioned
  | DuplicateDropped MessageId
  | BlobPut BlobKey BlobResult
  | BlobGot BlobKey (Maybe Text)
  | ObjectApply ObjectName ApplyResult
  | ObjectWatch ResourceVersion WatchResult
  | DnsWrite DnsName DnsValue
  | DnsRead DnsName (Maybe DnsValue)
  | VaultOperation VaultOp VaultResult
  | ClockRead
  | Delayed Int
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (FromJSON, ToJSON)

data InvariantOutcome = Upheld | Violated Text
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (FromJSON, ToJSON)

-- | The complete effect surface used by a reconcile program. The program is
-- polymorphic in @m@; interpreters decide whether these effects are live or
-- modeled.
data Env m = Env
  { envPublish :: Topic -> Text -> m MessageId
  , envConsume :: Topic -> m [Message]
  , envPutBlob :: PutCondition -> BlobKey -> Text -> m BlobResult
  , envGetBlob :: BlobKey -> m (Maybe Text)
  , envApplyObject :: ObjectName -> ResourceVersion -> Text -> m ApplyResult
  , envWatchObjects :: ResourceVersion -> m WatchResult
  , envWriteDns :: DnsName -> DnsValue -> m DnsResult
  , envReadDns :: DnsName -> m (Maybe DnsValue)
  , envVaultOp :: VaultOp -> m VaultResult
  , envNow :: m UTCTime
  , envDelay :: Int -> m ()
  }
