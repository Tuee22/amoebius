{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Workflow.Resources
  ( ExecutionKind (..)
  , ExecutionSource (..)
  , WorkflowRuntimeDemand (..)
  , ProvisionedWorkflowRuntime
  , ProvisionError (..)
  , phase37RuntimeDemand
  , workflowProvisionTerms
  , provisionWorkflowRuntime
  , provisionedTerms
  , provisionedSources
  ) where

import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Numeric.Natural (Natural)

data ExecutionKind = DeploymentUnit | JobUnit
  deriving stock (Eq, Ord, Show)

data ExecutionSource = ExecutionSource
  { sourceIdentity :: Text
  , sourceKind :: ExecutionKind
  , sourceCpuMillis :: Natural
  , sourceMemoryBytes :: Natural
  , sourceEphemeralBytes :: Natural
  , sourceImageBytes :: Natural
  , sourceLogBytes :: Natural
  , sourceProjectedBytes :: Natural
  , sourcePulsarBufferBytes :: Natural
  , sourceArtifactWorkspaceBytes :: Natural
  , sourcePodSlots :: Natural
  }
  deriving stock (Eq, Show)

data WorkflowRuntimeDemand = WorkflowRuntimeDemand
  { runtimeSources :: [ExecutionSource]
  , runtimeFailoverOverlapBytes :: Natural
  , runtimeApiObjectCount :: Natural
  , runtimeEtcdLogicalBytes :: Natural
  , runtimeAcceleratorCount :: Natural
  }
  deriving stock (Eq, Show)

data ProvisionedWorkflowRuntime = ProvisionedWorkflowRuntime
  { provisionedTerms :: Map Text Natural
  , provisionedSources :: [ExecutionSource]
  }
  deriving stock (Eq, Show)

data ProvisionError
  = ProvisionDeficit Text Natural Natural
  | RuntimeIdentityDomainMismatch [Text]
  | RuntimeAcceleratorForbidden Natural
  deriving stock (Eq, Show)

phase37RuntimeDemand :: WorkflowRuntimeDemand
phase37RuntimeDemand = WorkflowRuntimeDemand sources (64 * mib) 28 (512 * 1024) 0
  where
    mib = 1024 * 1024
    deployment name cpu memory ephemeral image logs projected pulsar workspace =
      ExecutionSource name DeploymentUnit cpu (memory * mib) (ephemeral * mib) (image * mib) (logs * mib) projected (pulsar * mib) (workspace * mib) 1
    job name cpu memory ephemeral image logs projected workspace =
      ExecutionSource name JobUnit cpu (memory * mib) (ephemeral * mib) (image * mib) (logs * mib) projected 0 (workspace * mib) 1
    sources =
      [ deployment "orchestrator" 250 128 96 64 8 32768 8 16
      , deployment "worker-a" 500 256 192 64 16 32768 16 64
      , deployment "worker-b" 500 256 192 64 16 32768 16 64
      , deployment "worker-c" 500 256 192 64 16 32768 16 64
      , deployment "content-gateway" 250 128 128 64 8 32768 0 32
      , job "completion-collector" 250 128 128 64 8 32768 32
      ]

workflowProvisionTerms :: WorkflowRuntimeDemand -> Map Text Natural
workflowProvisionTerms demand = Map.fromList
  [ ("cpu-millis", sum (map sourceCpuMillis sources))
  , ("memory-bytes", sum (map sourceMemoryBytes sources))
  , ("ephemeral-bytes", sum (map sourceEphemeralBytes sources))
  , ("image-bytes", sum (map sourceImageBytes sources))
  , ("log-bytes", sum (map sourceLogBytes sources))
  , ("projected-file-bytes", sum (map sourceProjectedBytes sources))
  , ("pulsar-buffer-bytes", sum (map sourcePulsarBufferBytes sources))
  , ("artifact-workspace-bytes", sum (map sourceArtifactWorkspaceBytes sources))
  , ("pod-slots", sum (map sourcePodSlots sources))
  , ("deployment-units", fromIntegral (length (filter ((== DeploymentUnit) . sourceKind) sources)))
  , ("job-units", fromIntegral (length (filter ((== JobUnit) . sourceKind) sources)))
  , ("worker-standbys", 2)
  , ("failover-overlap-bytes", runtimeFailoverOverlapBytes demand)
  , ("api-objects", runtimeApiObjectCount demand)
  , ("etcd-logical-bytes", runtimeEtcdLogicalBytes demand)
  , ("runtime-metadata-identities", fromIntegral (length sources))
  , ("container-volume-mount-identities", fromIntegral (length sources * 3))
  , ("network-attachment-identities", fromIntegral (length sources))
  ]
  where
    sources = runtimeSources demand

provisionWorkflowRuntime :: WorkflowRuntimeDemand -> Map Text Natural -> Either [ProvisionError] ProvisionedWorkflowRuntime
provisionWorkflowRuntime demand supply
  | runtimeAcceleratorCount demand /= 0 = Left [RuntimeAcceleratorForbidden (runtimeAcceleratorCount demand)]
  | identities /= expectedIdentities = Left [RuntimeIdentityDomainMismatch identities]
  | not (null deficits) = Left deficits
  | otherwise = Right (ProvisionedWorkflowRuntime required (runtimeSources demand))
  where
    identities = map sourceIdentity (runtimeSources demand)
    expectedIdentities = ["orchestrator", "worker-a", "worker-b", "worker-c", "content-gateway", "completion-collector"]
    required = workflowProvisionTerms demand
    deficits =
      [ ProvisionDeficit term requiredValue (Map.findWithDefault 0 term supply)
      | (term, requiredValue) <- Map.toList required
      , Map.findWithDefault 0 term supply < requiredValue
      ]
