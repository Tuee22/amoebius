{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

module Amoebius.Execution.Normalize
  ( ExecutionCommitment (..)
  , NormalizationError (..)
  , normalizeExecutionCommitments
  ) where

import Amoebius.Execution.Observe
import Control.DeepSeq (NFData)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data ExecutionCommitment = ExecutionCommitment
  { commitmentCpuMillis :: Natural
  , commitmentMemoryBytes :: Natural
  , commitmentEphemeralBytes :: Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data NormalizationError
  = CommitmentIdentityMissing ObservedExecutionIdentity
  | CommitmentIdentityUnexpected ObservedExecutionIdentity
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

normalizeExecutionCommitments
  :: Map ObservedExecutionIdentity ObservedExecution
  -> Map ObservedExecutionIdentity ExecutionCommitment
  -> Either NormalizationError ExecutionCommitment
normalizeExecutionCommitments observed commitments = do
  mapM_ requireCommitment (Map.keys observed)
  mapM_ requireObservation (Map.keys commitments)
  pure (foldl add zero (Map.elems commitments))
 where
  requireCommitment identity
    | Map.member identity commitments = Right ()
    | otherwise = Left (CommitmentIdentityMissing identity)
  requireObservation identity
    | Map.member identity observed = Right ()
    | otherwise = Left (CommitmentIdentityUnexpected identity)
  zero = ExecutionCommitment 0 0 0
  add left right =
    ExecutionCommitment
      (commitmentCpuMillis left + commitmentCpuMillis right)
      (commitmentMemoryBytes left + commitmentMemoryBytes right)
      (commitmentEphemeralBytes left + commitmentEphemeralBytes right)
