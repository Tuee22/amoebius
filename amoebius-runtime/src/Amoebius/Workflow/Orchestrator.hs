{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

module Amoebius.Workflow.Orchestrator
  ( WorkflowCommand (..)
  , WorkflowEvent (..)
  , eventMatchesCommand
  ) where

import Amoebius.Workflow.Runtime (WorkId)
import Codec.Serialise (Serialise)
import Data.ByteString (ByteString)
import Data.Text (Text)
import GHC.Generics (Generic)

data WorkflowCommand = WorkflowCommand
  { commandWorkId :: WorkId
  , commandChallenge :: Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Serialise)

data WorkflowEvent = WorkflowEvent
  { eventWorkId :: WorkId
  , eventManifestSha :: ByteString
  , eventWorkerName :: Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Serialise)

eventMatchesCommand :: WorkflowCommand -> WorkflowEvent -> Bool
eventMatchesCommand command event =
  commandWorkId command == eventWorkId event
    && not (eventManifestSha event == mempty)
