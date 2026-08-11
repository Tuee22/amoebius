{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

module Amoebius.Execution.JobTerminal
  ( JobOutcome (..)
  , TerminalJobObservation (..)
  , JobTerminalAction (..)
  , JobTerminalError (..)
  , planJobTerminal
  ) where

import Control.DeepSeq (NFData)
import Data.Text (Text)
import GHC.Generics (Generic)

data JobOutcome = JobSucceeded | JobFailedBackoffExhausted
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data TerminalJobObservation = TerminalJobObservation
  { terminalJobUid :: Text
  , terminalJobOutcome :: JobOutcome
  , terminalJobDigest :: Text
  , terminalJobRevision :: Text
  , terminalGatewayAvailable :: Bool
  , terminalCompletionReadback :: Maybe (JobOutcome, Text, Text)
  , terminalCleanupDeadlineReached :: Bool
  , terminalReleaseComplete :: Bool
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data JobTerminalAction
  = RetainTerminalAwaitingGateway Text
  | PersistJobCompletion JobOutcome Text Text
  | CleanupPersistedTerminal Text
  | CompletedTerminalNoOp Text
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data JobTerminalError = CompletionReadbackMismatch | CleanupDeadlineNotReached | TerminalReleaseIncomplete
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

planJobTerminal :: TerminalJobObservation -> Either JobTerminalError JobTerminalAction
planJobTerminal observed
  | not (terminalGatewayAvailable observed) = Right (RetainTerminalAwaitingGateway (terminalJobUid observed))
  | otherwise = case terminalCompletionReadback observed of
      Nothing -> Right (PersistJobCompletion (terminalJobOutcome observed) (terminalJobDigest observed) (terminalJobRevision observed))
      Just readback
        | readback /= (terminalJobOutcome observed, terminalJobDigest observed, terminalJobRevision observed) -> Left CompletionReadbackMismatch
        | not (terminalCleanupDeadlineReached observed) -> Right (CompletedTerminalNoOp (terminalJobUid observed))
        | not (terminalReleaseComplete observed) -> Left TerminalReleaseIncomplete
        | otherwise -> Right (CleanupPersistedTerminal (terminalJobUid observed))
