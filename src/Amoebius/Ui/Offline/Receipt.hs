

module Amoebius.Ui.Offline.Receipt
  ( CommandId (..)
  , DurableReceipts
  , Receipt (..)
  , Scope (..)
  , WorkId (..)
  , durableLookup
  , emptyDurableReceipts
  , idempotencyKey
  , infernixWorkId
  , recordEffect
  , recoverOutcome
  ) where

import Amoebius.Ui.Offline.Outcome
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map

newtype CommandId = CommandId String
  deriving stock (Eq, Ord, Show)

newtype WorkId = WorkId String
  deriving stock (Eq, Ord, Show)

data Scope = Scope
  { tenantId :: String
  , ownerId :: String
  , programId :: String
  , scopeEpoch :: Int
  }
  deriving stock (Eq, Ord, Show)

data Receipt = Receipt
  { receiptCommand :: CommandId
  , receiptWork :: Maybe WorkId
  , receiptPayload :: String
  }
  deriving stock (Eq, Show)

newtype DurableReceipts = DurableReceipts (Map String Receipt)
  deriving stock (Eq, Show)

emptyDurableReceipts :: DurableReceipts
emptyDurableReceipts = DurableReceipts Map.empty

idempotencyKey :: Scope -> CommandId -> String
idempotencyKey scope (CommandId command) =
  tenantId scope <> "|" <> ownerId scope <> "|" <> programId scope <> "|" <> show (scopeEpoch scope) <> "|" <> command

recordEffect :: Scope -> Receipt -> DurableReceipts -> (DurableReceipts, Receipt, Bool)
recordEffect scope receipt (DurableReceipts receipts) =
  case Map.lookup key receipts of
    Just existing -> (DurableReceipts receipts, existing, False)
    Nothing -> (DurableReceipts (Map.insert key receipt receipts), receipt, True)
  where
    key = idempotencyKey scope (receiptCommand receipt)

durableLookup :: Scope -> CommandId -> DurableReceipts -> Maybe Receipt
durableLookup scope command (DurableReceipts receipts) =
  Map.lookup (idempotencyKey scope command) receipts

recoverOutcome :: Scope -> CommandId -> Maybe Receipt -> DurableReceipts -> ReplayOutcome Receipt
recoverOutcome scope command _ durable = maybe Pending Accepted (durableLookup scope command durable)

infernixWorkId :: CommandId -> WorkId
infernixWorkId (CommandId command) = WorkId command
