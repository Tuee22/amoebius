{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Store.ControlPlaneState
  ( JobOutcome (..)
  , JobCompletion (..)
  , CompletionObservation (..)
  , TerminalDecision (..)
  , TerminalError (..)
  , canonicalJobCompletion
  , jobCompletionDigest
  , decideTerminalCleanup
  ) where

import Amoebius.Store.ContentAddress
import Codec.CBOR.Encoding (encodeListLen, encodeString)
import Codec.CBOR.Write (toStrictByteString)
import Data.ByteString (ByteString)
import Data.Text (Text)

data JobOutcome = JobSucceeded | JobFailedBackoffExhausted
  deriving stock (Eq, Ord, Show)

data JobCompletion = JobCompletion
  { completionExecutionIdentity :: Text
  , completionOutcome :: JobOutcome
  , completionRevision :: Text
  }
  deriving stock (Eq, Show)

data CompletionObservation = CompletionObservation
  { observedTerminalUid :: Text
  , observedTerminalStatus :: Bool
  , observedGatewayAcknowledged :: Bool
  , observedCompletionReadback :: Maybe JobCompletion
  , observedCleanupDeadlineReached :: Bool
  , observedSchedulerReleased :: Bool
  }
  deriving stock (Eq, Show)

data TerminalDecision
  = RetainTerminal Text
  | PersistCompletion JobCompletion
  | DeleteVerifiedTerminal Text
  | CompletedJobNoOp Text
  deriving stock (Eq, Show)

data TerminalError = CompletionReadbackMismatch | SchedulerReleaseIncomplete
  deriving stock (Eq, Show)

canonicalJobCompletion :: JobCompletion -> ByteString
canonicalJobCompletion completion = toStrictByteString $
  encodeListLen 4
    <> encodeString "amoebius.job-completion.v1"
    <> encodeString (completionExecutionIdentity completion)
    <> encodeString (renderOutcome (completionOutcome completion))
    <> encodeString (completionRevision completion)
  where
    renderOutcome JobSucceeded = "Succeeded"
    renderOutcome JobFailedBackoffExhausted = "FailedBackoffExhausted"

jobCompletionDigest :: JobCompletion -> ContentDigest
jobCompletionDigest = contentDigest . canonicalJobCompletion

decideTerminalCleanup :: JobCompletion -> CompletionObservation -> Either TerminalError TerminalDecision
decideTerminalCleanup expected observation
  | not (observedGatewayAcknowledged observation) = Right (PersistCompletion expected)
  | otherwise = case observedCompletionReadback observation of
      Nothing -> Right (RetainTerminal (observedTerminalUid observation))
      Just actual
        | actual /= expected -> Left CompletionReadbackMismatch
        | not (observedCleanupDeadlineReached observation) -> Right (CompletedJobNoOp (observedTerminalUid observation))
        | not (observedSchedulerReleased observation) -> Left SchedulerReleaseIncomplete
        | otherwise -> Right (DeleteVerifiedTerminal (observedTerminalUid observation))
