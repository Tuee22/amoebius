{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

module Amoebius.Ui.Projection.ReceiptFold
  ( WorkflowIdentity (..)
  , ReceiptOutcome (..)
  , ReceiptEventKind (..)
  , ReceiptEvent (..)
  , DurableReceipt (..)
  , ReceiptFoldError (..)
  , foldReceipt
  ) where

import Amoebius.Ui.Projection.OwnerKey
import Amoebius.Ui.Projection.StreamCursor
import Codec.Serialise (Serialise)
import Data.Text (Text)
import GHC.Generics (Generic)

data WorkflowIdentity = WorkflowIdentity
  { workflowWorkId :: Text
  , workflowHandle :: Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Serialise)

data ReceiptOutcome
  = Accepted
  | TerminalSucceeded
  | TerminalFailedBackoffExhausted
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Serialise)

data ReceiptEventKind
  = EffectAccepted
  | ProgressObserved
  | EffectTerminal ReceiptOutcome
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Serialise)

data ReceiptEvent = ReceiptEvent
  { eventReceiptKey :: ReceiptKey
  , eventInputDigest :: Text
  , eventWorkflowIdentity :: WorkflowIdentity
  , eventEffectOwner :: Bool
  , eventReceiptKind :: ReceiptEventKind
  , eventReceiptCursor :: StreamCursor
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Serialise)

data DurableReceipt = DurableReceipt
  { durableReceiptKey :: ReceiptKey
  , durableInputDigest :: Text
  , durableWorkflowIdentity :: WorkflowIdentity
  , durableOutcome :: ReceiptOutcome
  , durableCursor :: StreamCursor
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Serialise)

data ReceiptFoldError = IdempotencyConflict ReceiptKey Text Text
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Serialise)

foldReceipt
  :: Maybe DurableReceipt
  -> ReceiptEvent
  -> Either ReceiptFoldError (Maybe DurableReceipt)
foldReceipt current event = case current of
  Just receipt
    | durableInputDigest receipt /= eventInputDigest event ->
        Left (IdempotencyConflict (eventReceiptKey event) (durableInputDigest receipt) (eventInputDigest event))
  _
    | not (eventEffectOwner event) -> Right current
    | otherwise -> case eventReceiptKind event of
        ProgressObserved -> Right current
        EffectAccepted -> Right (Just (materialize Accepted))
        EffectTerminal outcome -> Right (Just (materialize outcome))
 where
  materialize outcome = DurableReceipt
    { durableReceiptKey = eventReceiptKey event
    , durableInputDigest = eventInputDigest event
    , durableWorkflowIdentity = eventWorkflowIdentity event
    , durableOutcome = outcome
    , durableCursor = eventReceiptCursor event
    }
