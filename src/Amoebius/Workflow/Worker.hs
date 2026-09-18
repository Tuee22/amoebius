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
  [StoreArtifact, EmitWorkflowEvent, AcknowledgeCommand]

coordinationSurfaces :: [Text]
coordinationSurfaces =
  []

workflowComponents :: [(Text, ByteString)]
workflowComponents =
  [ ("alpha", "content-store-workflow-alpha")
  , ("zeta", "content-store-workflow-zeta")
  ]
