{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Test.Ledger
  ( Honesty (..)
  , CoverageRow (..)
  , RunLedger (..)
  , deriveRunLedger
  ) where

import Amoebius.Test.Topology
import Data.Set qualified as Set
import Data.Text (Text)

data Honesty = Proven | Tested | Assumed | Unverified
  deriving stock (Eq, Ord, Show)

data CoverageRow = CoverageRow Text Honesty
  deriving stock (Eq, Ord, Show)

data RunLedger = RunLedger [CoverageRow]
  deriving stock (Eq, Show)

deriveRunLedger :: ProvisionedTestTopology -> RunLedger
deriveRunLedger provisioned = RunLedger (fmap classify (topologyExpectations topology))
 where
  topology = provisionedTopology provisioned
  faulted = Set.fromList
    [ "StandbyTakesOver"
    | KillWorker _ "test-topology-dsl-failover" <- topologyFaults topology
    ]
  classify expectation
#ifdef TEST_TOPOLOGY_DSL_ALL_TESTED_MUTANT
    = CoverageRow (expectationInvariant expectation) Tested
#else
    | expectationInvariant expectation `Set.member` faulted && expectationWitness expectation /= Nothing =
        CoverageRow (expectationInvariant expectation) Tested
    | otherwise = CoverageRow (expectationInvariant expectation) Unverified
#endif
