{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

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
  | MissingLocalValidation
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
  | localValidation contract == "" = Left MissingLocalValidation
  | idempotency contract == "" = Left MissingIdempotency
  | conflict contract == "" = Left MissingConflictRule
  | ordering contract == "" = Left MissingOrderRule
  | dependency contract == "" = Left MissingDependencyRule
  | authoritativeValidation contract == "" = Left MissingAuthorityValidation
  | otherwise = Right queued
