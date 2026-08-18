{-# LANGUAGE CPP #-}

module Amoebius.Ui.Offline.Decode
  ( DecodeError (..)
  , decodeQueueContract
  , queueableOperation
  ) where

import Amoebius.Ui.Offline.Types

data DecodeError
  = MissingCountBound
  | MissingByteBound
  | MissingAgeBound
  | MissingIdempotency
  | MissingConflictRule
  | MissingOrderRule
  | MissingDependencyRule
  | MissingAuthorityValidation
  | OnlineOnlyOperation Operation
  deriving stock (Eq, Show)

queueableOperation :: Operation -> Bool
queueableOperation InfernixStart = True
queueableOperation JitmlTrainingStart = True
#ifdef OFFLINE_LANGUAGE_PLAN_QUEUE_MODEL_INVOCATION_MUTANT
queueableOperation ModelInvocation = True
#endif
queueableOperation _ = False

decodeQueueContract :: QueuedPort -> Either DecodeError QueuedPort
decodeQueueContract queued@(QueuedPort operation contract)
  | not (queueableOperation operation) = Left (OnlineOnlyOperation operation)
  | maxCount contract <= 0 = Left MissingCountBound
  | maxBytes contract <= 0 = Left MissingByteBound
#ifndef OFFLINE_LANGUAGE_PLAN_DROP_QUEUE_BOUND_MUTANT
  | maxAgeSeconds contract <= 0 = Left MissingAgeBound
#endif
  | null (idempotencyRule contract) = Left MissingIdempotency
  | null (conflictRule contract) = Left MissingConflictRule
  | null (orderRule contract) = Left MissingOrderRule
  | null (dependencyRule contract) = Left MissingDependencyRule
  | null (authoritativeValidation contract) = Left MissingAuthorityValidation
  | otherwise = Right queued
