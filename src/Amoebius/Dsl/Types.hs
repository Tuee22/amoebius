{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE StandaloneDeriving #-}

module Amoebius.Dsl.Types
  ( Surface (..)
  , StructuralNode (..)
  , ClusterIR (..)
  , ControllerKind (..)
  , ExecutionIdentity (..)
  , Cardinality (..)
  , DeploymentProgress (..)
  , ResourceArm (..)
  , ResourceEnvelope (..)
  , ExecutionUnit (..)
  , SomeExecutionUnit (..)
  , executionResourceNodes
  , SpecState (..)
  , StateWitness (..)
  , LegalTransition (..)
  , advanceState
  ) where

import Control.DeepSeq (NFData (..))
import Data.Text (Text)
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data Surface = ClusterSurface | AppSurface | DeploymentSurface
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

-- | Lossless, normalized representation of a Dhall value.  There is one row
-- for every record, list, union arm and scalar in the normalized expression;
-- paths are never inferred again downstream.
data StructuralNode = StructuralNode
  { nodePath :: [Text]
  , nodeKind :: Text
  , nodeValue :: Text
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ControllerKind = DeploymentK | StatefulSetK | DaemonSetK | JobK | HostProcessK

data ExecutionIdentity = ExecutionIdentity
  { executionId :: Text
  , executionRevision :: Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data Cardinality = Once | Replicated Natural | PerNode
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data DeploymentProgress = Recreate | RollingProgress Natural Natural
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ResourceArm = PodResource | HostResource
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ResourceEnvelope = ResourceEnvelope
  { resourceArm :: ResourceArm
  , resourceNodes :: [StructuralNode]
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

-- | Controller policy and cardinality are indexed by controller kind.  The
-- public constructors contain only kind-valid combinations.
data ExecutionUnit (kind :: ControllerKind) where
  DeploymentUnit :: ExecutionIdentity -> Cardinality -> DeploymentProgress -> ResourceEnvelope -> ExecutionUnit 'DeploymentK
  StatefulSetUnit :: ExecutionIdentity -> Cardinality -> ResourceEnvelope -> ExecutionUnit 'StatefulSetK
  DaemonSetUnit :: ExecutionIdentity -> ResourceEnvelope -> ExecutionUnit 'DaemonSetK
  JobUnit :: ExecutionIdentity -> Natural -> Natural -> ResourceEnvelope -> ExecutionUnit 'JobK
  HostProcessUnit :: ExecutionIdentity -> Cardinality -> ResourceEnvelope -> ExecutionUnit 'HostProcessK

deriving stock instance Eq (ExecutionUnit kind)
deriving stock instance Show (ExecutionUnit kind)

instance NFData (ExecutionUnit kind) where
  rnf executionUnit = case executionUnit of
    DeploymentUnit identity cardinality progress resources -> rnf identity `seq` rnf cardinality `seq` rnf progress `seq` rnf resources
    StatefulSetUnit identity cardinality resources -> rnf identity `seq` rnf cardinality `seq` rnf resources
    DaemonSetUnit identity resources -> rnf identity `seq` rnf resources
    JobUnit identity completions parallelism resources -> rnf identity `seq` rnf completions `seq` rnf parallelism `seq` rnf resources
    HostProcessUnit identity cardinality resources -> rnf identity `seq` rnf cardinality `seq` rnf resources

data SomeExecutionUnit where
  SomeExecutionUnit :: ExecutionUnit kind -> SomeExecutionUnit

deriving stock instance Show SomeExecutionUnit

instance NFData SomeExecutionUnit where
  rnf (SomeExecutionUnit executionUnit) = rnf executionUnit

executionResourceNodes :: SomeExecutionUnit -> [StructuralNode]
executionResourceNodes (SomeExecutionUnit executionUnit) = case executionUnit of
  DeploymentUnit _ _ _ envelope -> resourceNodes envelope
  StatefulSetUnit _ _ envelope -> resourceNodes envelope
  DaemonSetUnit _ envelope -> resourceNodes envelope
  JobUnit _ _ _ envelope -> resourceNodes envelope
  HostProcessUnit _ _ envelope -> resourceNodes envelope

-- | The complete structural tree is the preservation boundary.  Refined
-- execution values add indexed invariants without discarding unprovisioned
-- resource/capacity operands.  No Provisioned value can inhabit this type.
data ClusterIR = ClusterIR
  { clusterSurface :: Surface
  , clusterSemanticHash :: Text
  , clusterCanonicalDhall :: Text
  , clusterNodes :: [StructuralNode]
  , clusterExecutions :: [SomeExecutionUnit]
  }
  deriving stock (Generic, Show)
  deriving anyclass (NFData)

data SpecState = Authored | Bound | Provisioned

data StateWitness (state :: SpecState) where
  AuthoredWitness :: StateWitness 'Authored
  BoundWitness :: StateWitness 'Bound
  ProvisionedWitness :: StateWitness 'Provisioned

data LegalTransition (from :: SpecState) (to :: SpecState) where
  BindTransition :: LegalTransition 'Authored 'Bound
  ProvisionTransition :: LegalTransition 'Bound 'Provisioned

advanceState :: LegalTransition from to -> StateWitness from -> StateWitness to
advanceState transition witness = case (transition, witness) of
  (BindTransition, AuthoredWitness) -> BoundWitness
  (ProvisionTransition, BoundWitness) -> ProvisionedWitness
