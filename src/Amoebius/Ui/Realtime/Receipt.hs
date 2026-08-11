{-# LANGUAGE CPP #-}

module Amoebius.Ui.Realtime.Receipt
  ( CommandId (..)
  , Receipt (..)
  , ReceiptSources (..)
  , authoritativeReceipt
  ) where

import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map

newtype CommandId = CommandId String
  deriving stock (Eq, Ord, Show)

newtype Receipt = Receipt String
  deriving stock (Eq, Show)

data ReceiptSources = ReceiptSources
  { redisAcks :: Map CommandId Receipt
  , durableReceipts :: Map CommandId Receipt
  }
  deriving stock (Eq, Show)

authoritativeReceipt :: ReceiptSources -> CommandId -> Maybe Receipt
#ifdef PHASE55_REDIS_RECEIPT_AUTHORITY_MUTANT
authoritativeReceipt sources command = Map.lookup command (redisAcks sources)
#else
authoritativeReceipt sources command = Map.lookup command (durableReceipts sources)
#endif
