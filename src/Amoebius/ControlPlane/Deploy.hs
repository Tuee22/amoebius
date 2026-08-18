{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Opaque whole-deployment provision seal consumed by the live reconciler.
module Amoebius.ControlPlane.Deploy
  ( DeploymentEnvelope (..)
  , ObjectProducerArm (..)
  , DeployDemand (..)
  , DeployError (..)
  , ProvisionedDeploy
  , provisionDeploy
  , renderProvisionedDeploy
  ) where

import Amoebius.ControlPlane.Reconcile (ObjectIdentity (..))
import Amoebius.ControlPlane.Daemon (ControlPlaneStateKind)
import Control.DeepSeq (NFData)
import Data.Set (Set)
import Data.Set qualified as Set
import GHC.Generics (Generic)

data DeploymentEnvelope = ControlPlaneDaemonEnvelope | TrivialAppEnvelope | AdmissionGatewayEnvelope
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ObjectProducerArm = AppBucket | Content | Registry | PulsarOffload | PulumiCheckpoint | ControlPlaneState
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data DeployDemand = DeployDemand
  { deployDhallPath :: FilePath
  , deployTargetAuthenticated :: Bool
  , deployCapacityFits :: Bool
  , deployEnvelopes :: Set DeploymentEnvelope
  , deployProducerArms :: Set ObjectProducerArm
  , deployStateKinds :: Set ControlPlaneStateKind
  , deployDesiredObjects :: Set ObjectIdentity
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

newtype ProvisionedDeploy = ProvisionedDeploy (Set ObjectIdentity)
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data DeployError
  = DeployDhallPathMissing
  | DeployTargetUnauthenticated
  | DeployCapacityRefused
  | DeployEnvelopeOmitted
  | DeployProducerArmOmitted
  | DeployControlPlaneStateOmitted
  | DeployDesiredSetEmpty
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

provisionDeploy :: DeployDemand -> Either DeployError ProvisionedDeploy
provisionDeploy demand
  | null (deployDhallPath demand) = Left DeployDhallPathMissing
  | not (deployTargetAuthenticated demand) = Left DeployTargetUnauthenticated
  | not (deployCapacityFits demand) = Left DeployCapacityRefused
  | deployEnvelopes demand /= Set.fromList [minBound .. maxBound] = Left DeployEnvelopeOmitted
  | deployProducerArms demand /= Set.fromList [minBound .. maxBound] = Left DeployProducerArmOmitted
  | Set.size (deployStateKinds demand) /= 5 = Left DeployControlPlaneStateOmitted
  | Set.null (deployDesiredObjects demand) = Left DeployDesiredSetEmpty
  | otherwise = Right (ProvisionedDeploy (deployDesiredObjects demand))

renderProvisionedDeploy :: ProvisionedDeploy -> Set ObjectIdentity
renderProvisionedDeploy (ProvisionedDeploy desired) = desired
