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
queueableOperation _ = False

decodeQueueContract :: QueuedPort -> Either DecodeError QueuedPort
decodeQueueContract queued@(QueuedPort operation contract)
  | not (queueableOperation operation) = Left (OnlineOnlyOperation operation)
  | maxCount contract <= 0 = Left MissingCountBound
  | maxBytes contract <= 0 = Left MissingByteBound
  | maxAgeSeconds contract <= 0 = Left MissingAgeBound
  | localValidation contract == "" = Left MissingLocalValidation
  | idempotency contract == "" = Left MissingIdempotency
  | conflict contract == "" = Left MissingConflictRule
  | ordering contract == "" = Left MissingOrderRule
  | dependency contract == "" = Left MissingDependencyRule
  | authoritativeValidation contract == "" = Left MissingAuthorityValidation
  | otherwise = Right queued
