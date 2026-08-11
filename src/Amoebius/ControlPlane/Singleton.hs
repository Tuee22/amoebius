{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Pure control-plane singleton and durable-state provision contracts.
module Amoebius.ControlPlane.Singleton
  ( DeploymentRolloutPolicy (..)
  , SingletonManifest (..)
  , SingletonError (..)
  , ControlPlaneStateKind (..)
  , ControlPlaneStateDemand (..)
  , ProvisionedControlPlaneState
  , provisionControlPlaneState
  , validateSingletonManifest
  , DaemonPhase (..)
  , daemonSpine
  , singletonReady
  , singletonFieldManager
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

data SingletonManifest = SingletonManifest
  { singletonKind :: Text
  , singletonReplicas :: Natural
  , singletonRolloutPolicy :: DeploymentRolloutPolicy
  , singletonPersistentVolumeClaims :: [Text]
  , singletonStandbyReplicas :: Natural
  , singletonHasElectionController :: Bool
  , singletonImage :: Text
  , singletonResources :: ResourceEnvelope
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

data SingletonError
  = SingletonMustBeDeployment
  | SingletonReplicaCardinalityInvalid
  | SingletonRolloutMustBeRecreate
  | SingletonMustBeStateless
  | SingletonStandbyForbidden
  | SingletonElectionForbidden
  | SingletonImageUnpinned
  | SingletonResourceEnvelopeInvalid Text
  | ControlPlaneStateBudgetMissing
  | ControlPlaneStateKindsIncomplete
  | ControlPlaneStateBoundInvalid Text
  | ControlPlaneStateAdmissionMissing
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

validateSingletonManifest :: SingletonManifest -> Either SingletonError SingletonManifest
validateSingletonManifest manifest
  | singletonKind manifest /= "Deployment" = Left SingletonMustBeDeployment
  | singletonReplicas manifest /= 1 = Left SingletonReplicaCardinalityInvalid
  | singletonRolloutPolicy manifest /= Recreate = Left SingletonRolloutMustBeRecreate
  | not (null (singletonPersistentVolumeClaims manifest)) = Left SingletonMustBeStateless
  | singletonStandbyReplicas manifest /= 0 = Left SingletonStandbyForbidden
  | singletonHasElectionController manifest = Left SingletonElectionForbidden
  | not ("@sha256:" `Text.isInfixOf` singletonImage manifest) = Left SingletonImageUnpinned
  | otherwise = case validateResourceEnvelope (singletonResources manifest) of
      Left problem -> Left (SingletonResourceEnvelopeInvalid problem)
      Right _ -> Right manifest

provisionControlPlaneState :: ControlPlaneStateDemand -> Either SingletonError ProvisionedControlPlaneState
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

singletonReady :: DaemonPhase -> Bool
singletonReady phase = case phase of
  Serving _ -> True
  _ -> False

singletonFieldManager :: Text
#ifdef PHASE33_EFFECT_SWAP_MUTANT
singletonFieldManager = "phase33-harness"
#else
singletonFieldManager = "amoebius-phase33-singleton"
#endif
