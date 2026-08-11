module Amoebius.Ui.Realtime.RedisCoordination
  ( CoordinationResult (..)
  , coordinate
  ) where

import Amoebius.Ui.Realtime.Receipt
import Amoebius.Ui.Realtime.Route

data CoordinationResult = CoordinationResult Route Receipt
  deriving stock (Eq, Show)

coordinate :: ReplicaId -> ReplicaId -> ReceiptSources -> CommandId -> Maybe CoordinationResult
coordinate owner origin sources command = CoordinationResult
  <$> routeAcrossReplicas owner origin
  <*> authoritativeReceipt sources command
