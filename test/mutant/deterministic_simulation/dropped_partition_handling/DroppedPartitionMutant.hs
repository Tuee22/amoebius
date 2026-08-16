{-# LANGUAGE OverloadedStrings #-}

module DroppedPartitionMutant
  ( droppedPartitionReconcile
  ) where

import Amoebius.Sim.Env
import Control.Monad.Class.MonadAsync (MonadAsync, async, wait)

-- Intentionally wrong: an empty read during a partition is treated as an
-- authoritative absence and the stale object is applied without awaiting heal.
droppedPartitionReconcile :: MonadAsync m => Env m -> m InvariantOutcome
droppedPartitionReconcile env = do
  publisher <- async (envPublish env (Topic "amoebius.commands") "activate:object-store")
  _ <- wait publisher
  messages <- envConsume env (Topic "amoebius.commands")
  if null messages
    then do
      _ <- envApplyObject env (ObjectName "service") (ResourceVersion 0) "stale"
      pure (Violated "NoActOnStaleRead")
    else pure Upheld
