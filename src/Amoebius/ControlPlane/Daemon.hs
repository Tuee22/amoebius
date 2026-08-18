{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Pure control-plane daemon and durable-state provision contracts.
module Amoebius.ControlPlane.Daemon
  ( DeploymentRolloutPolicy (..)
  , ControlPlaneDaemonManifest (..)
  , ControlPlaneDaemonError (..)
  , ControlPlaneStateKind (..)
  , ControlPlaneStateDemand (..)
  , ProvisionedControlPlaneState
  , provisionControlPlaneState
  , validateControlPlaneDaemonManifest
  , DaemonPhase (..)
  , daemonSpine
  , controlPlaneReady
  , controlPlaneFieldManager
  ) where

import Amoebius.Platform.Types (ResourceEnvelope, validateResourceEnvelope)
import Control.DeepSeq (NFData)
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data DeploymentRolloutPolicy = Recreate | RollingUpdate
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ControlPlaneDaemonManifest = ControlPlaneDaemonManifest
  { controlPlaneKind :: Text
  , controlPlaneReplicas :: Natural
  , controlPlaneRolloutPolicy :: DeploymentRolloutPolicy
  , controlPlanePersistentVolumeClaims :: [Text]
  , controlPlaneStandbyReplicas :: Natural
  , controlPlaneHasElectionController :: Bool
  , controlPlaneImage :: Text
  , controlPlaneResources :: ResourceEnvelope
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ControlPlaneStateKind
  = InForceSpecSnapshot
  | ManagedResourceRegistry
  | ReconcileJournal
  | ValidationLedger
  | JobCompletion
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ControlPlaneStateDemand = ControlPlaneStateDemand
  { stateStorageBudgetId :: Text
  , stateKinds :: Set ControlPlaneStateKind
  , stateMaximumCanonicalBytes :: Natural
  , stateRetainedVersions :: Natural
  , stateMaximumConcurrentWrites :: Natural
  , stateMaximumFailedWriteSets :: Natural
  , stateOrphanGcHorizonSeconds :: Natural
  , stateHasMutationAdmissionGateway :: Bool
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

newtype ProvisionedControlPlaneState = ProvisionedControlPlaneState ControlPlaneStateDemand
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ControlPlaneDaemonError
  = ControlPlaneMustBeDeployment
  | ControlPlaneReplicaCardinalityInvalid
  | ControlPlaneRolloutMustBeRecreate
  | ControlPlaneMustBeStateless
  | ControlPlaneStandbyForbidden
  | ControlPlaneElectionForbidden
  | ControlPlaneImageUnpinned
  | ControlPlaneResourceEnvelopeInvalid Text
  | ControlPlaneStateBudgetMissing
  | ControlPlaneStateKindsIncomplete
  | ControlPlaneStateBoundInvalid Text
  | ControlPlaneStateAdmissionMissing
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

validateControlPlaneDaemonManifest :: ControlPlaneDaemonManifest -> Either ControlPlaneDaemonError ControlPlaneDaemonManifest
validateControlPlaneDaemonManifest manifest
  | controlPlaneKind manifest /= "Deployment" = Left ControlPlaneMustBeDeployment
  | controlPlaneReplicas manifest /= 1 = Left ControlPlaneReplicaCardinalityInvalid
  | controlPlaneRolloutPolicy manifest /= Recreate = Left ControlPlaneRolloutMustBeRecreate
  | not (null (controlPlanePersistentVolumeClaims manifest)) = Left ControlPlaneMustBeStateless
  | controlPlaneStandbyReplicas manifest /= 0 = Left ControlPlaneStandbyForbidden
  | controlPlaneHasElectionController manifest = Left ControlPlaneElectionForbidden
  | not ("@sha256:" `Text.isInfixOf` controlPlaneImage manifest) = Left ControlPlaneImageUnpinned
  | otherwise = case validateResourceEnvelope (controlPlaneResources manifest) of
      Left problem -> Left (ControlPlaneResourceEnvelopeInvalid problem)
      Right _ -> Right manifest

provisionControlPlaneState :: ControlPlaneStateDemand -> Either ControlPlaneDaemonError ProvisionedControlPlaneState
provisionControlPlaneState demand
  | Text.null (stateStorageBudgetId demand) = Left ControlPlaneStateBudgetMissing
  | stateKinds demand /= Set.fromList [minBound .. maxBound] = Left ControlPlaneStateKindsIncomplete
  | stateMaximumCanonicalBytes demand == 0 = Left (ControlPlaneStateBoundInvalid "maximum-canonical-bytes")
  | stateRetainedVersions demand == 0 = Left (ControlPlaneStateBoundInvalid "retained-versions")
  | stateMaximumConcurrentWrites demand == 0 = Left (ControlPlaneStateBoundInvalid "concurrent-writes")
  | stateMaximumFailedWriteSets demand == 0 = Left (ControlPlaneStateBoundInvalid "failed-write-sets")
  | stateOrphanGcHorizonSeconds demand == 0 = Left (ControlPlaneStateBoundInvalid "orphan-gc-horizon")
  | not (stateHasMutationAdmissionGateway demand) = Left ControlPlaneStateAdmissionMissing
  | otherwise = Right (ProvisionedControlPlaneState demand)

data DaemonPhase
  = Loaded
  | PrerequisitesReady
  | LeaseAcquired Text
  | Serving Text
  | Draining Text
  | Exited
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

daemonSpine :: Text -> [DaemonPhase]
daemonSpine podUid =
  [Loaded, PrerequisitesReady, LeaseAcquired podUid, Serving podUid, Draining podUid, Exited]

controlPlaneReady :: DaemonPhase -> Bool
controlPlaneReady phase = case phase of
  Serving _ -> True
  _ -> False

controlPlaneFieldManager :: Text
#ifdef LIVE_DSL_DEPLOY_EFFECT_SWAP_MUTANT
controlPlaneFieldManager = "live-dsl-deploy-harness"
#else
controlPlaneFieldManager = "amoebius-live-dsl-deploy"
#endif
