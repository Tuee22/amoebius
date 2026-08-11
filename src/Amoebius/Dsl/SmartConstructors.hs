{-# LANGUAGE CPP #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Dsl.SmartConstructors
  ( mkDeploymentUnit
  , mkStatefulSetUnit
  , mkDaemonSetUnit
  , mkJobUnit
  , mkHostProcessUnit
  , mkPositiveReplicated
  , mkComputeHeadroom
  ) where

import Amoebius.Dsl.Error (DecodeError (..))
import Amoebius.Dsl.Types
  ( Cardinality (..)
  , ControllerKind (DaemonSetK, DeploymentK, HostProcessK, JobK, StatefulSetK)
  , DeploymentProgress (..)
  , ExecutionIdentity
  , ExecutionUnit (DaemonSetUnit, DeploymentUnit, HostProcessUnit, JobUnit, StatefulSetUnit)
  , ResourceArm (HostResource, PodResource)
  , ResourceEnvelope (..)
  )
import Numeric.Natural (Natural)

mkPositiveReplicated :: Natural -> Either DecodeError Cardinality
mkPositiveReplicated count
  | count == 0 = Left (OutOfDomainArm "execution.controller.cardinality.desiredReplicas")
  | otherwise = Right (Replicated count)

mkComputeHeadroom :: [(Natural, Natural, Natural)] -> Either DecodeError [Natural]
#ifdef PHASE6_MUTANT
mkComputeHeadroom triples = Right [requests + padding | (requests, _limits, padding) <- triples]
#else
mkComputeHeadroom triples
  | all (\(_, _, padding) -> padding == 0) triples =
      Left (UnspellableCombination "execution.resource.headroom.PositiveHeadroomAxisWitness")
  | otherwise = traverse checked triples
 where
  checked (requests, limits, padding)
    | requests + padding <= limits = Right (requests + padding)
    | otherwise = Left (UnspellableCombination "execution.resource.headroom.requests+pad>limits")
#endif

mkDeploymentUnit :: ExecutionIdentity -> Cardinality -> DeploymentProgress -> ResourceEnvelope -> Either DecodeError (ExecutionUnit 'DeploymentK)
mkDeploymentUnit identity cardinality progress resources = case (progress, resourceArm resources) of
  (RollingProgress 0 0, _) -> Left (UnspellableCombination "execution.controller.rollout.rollingProgress")
  (_, PodResource) -> Right (DeploymentUnit identity cardinality progress resources)
  _ -> Left (UnspellableCombination "execution.controller.Deployment.resource.Host")

mkStatefulSetUnit :: ExecutionIdentity -> Cardinality -> ResourceEnvelope -> Either DecodeError (ExecutionUnit 'StatefulSetK)
mkStatefulSetUnit identity cardinality resources = case (cardinality, resourceArm resources) of
  (Replicated count, PodResource)
    | count > 0 -> Right (StatefulSetUnit identity cardinality resources)
  (Once, _) -> Left (UnspellableCombination "execution.controller.StatefulSet.cardinality.Once")
  (_, HostResource) -> Left (UnspellableCombination "execution.controller.StatefulSet.resource.Host")
  _ -> Left (OutOfDomainArm "execution.controller.StatefulSet.cardinality.desiredReplicas")

mkDaemonSetUnit :: ExecutionIdentity -> ResourceEnvelope -> Either DecodeError (ExecutionUnit 'DaemonSetK)
mkDaemonSetUnit identity resources = case resourceArm resources of
  PodResource -> Right (DaemonSetUnit identity resources)
  HostResource -> Left (UnspellableCombination "execution.controller.DaemonSet.resource.Host")

mkJobUnit :: ExecutionIdentity -> Natural -> Natural -> Natural -> ResourceEnvelope -> Either DecodeError (ExecutionUnit 'JobK)
mkJobUnit identity completions parallelism retentionSeconds resources
  | completions == 0 = Left (OutOfDomainArm "execution.controller.Job.completions")
  | parallelism == 0 = Left (OutOfDomainArm "execution.controller.Job.parallelism")
  | retentionSeconds == 0 = Left (OutOfDomainArm "execution.controller.Job.terminalRetention.horizon")
  | resourceArm resources == HostResource = Left (UnspellableCombination "execution.controller.Job.resource.Host")
  | otherwise = Right (JobUnit identity completions parallelism resources)

mkHostProcessUnit :: ExecutionIdentity -> Cardinality -> ResourceEnvelope -> Either DecodeError (ExecutionUnit 'HostProcessK)
mkHostProcessUnit identity cardinality resources = case resourceArm resources of
  HostResource -> Right (HostProcessUnit identity cardinality resources)
  PodResource -> Left (UnspellableCombination "execution.controller.HostProcess.resource.Pod")
