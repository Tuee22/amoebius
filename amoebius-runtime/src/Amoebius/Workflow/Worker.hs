{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Workflow.Worker
  ( WorkerStep (..)
  , workerCriticalSteps
  , coordinationSurfaces
  , workflowComponents
  ) where

import Data.ByteString (ByteString)
import Data.Text (Text)

data WorkerStep = StoreArtifact | EmitWorkflowEvent | AcknowledgeCommand
  deriving stock (Eq, Ord, Show)

workerCriticalSteps :: [WorkerStep]
workerCriticalSteps =
#ifdef PHASE37_ACK_BEFORE_STORE_WRITE_MUTANT
  [AcknowledgeCommand, StoreArtifact, EmitWorkflowEvent]
#else
  [StoreArtifact, EmitWorkflowEvent, AcknowledgeCommand]
#endif

coordinationSurfaces :: [Text]
coordinationSurfaces =
#ifdef PHASE37_LEASE_ELECTION_MUTANT
  ["coordination.k8s.io/Lease"]
#else
  []
#endif

workflowComponents :: [(Text, ByteString)]
workflowComponents =
  [ ("alpha", "phase37-alpha")
  , ("zeta", "phase37-zeta")
  ]
