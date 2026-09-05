module GatewayMigrationOracle
  ( expectedConstants
  , expectedActions
  , expectedInvariants
  , expectedProperties
  , expectedRendererFacts
  , expectedCalculusFacts
  , expectedInvariantMutants
  , expectedCutoffCases
  , expectedCutoffMutants
  ) where

import Amoebius.Multicluster.StructuralFit (FitClause (..), MigrationEdge (..))
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map

-- This module is the separately authored Phase-17 semantic oracle.  It contains
-- values, not parsers: the production model cannot obtain an expectation from a
-- rendered TLA/CFG product or from a documentation file.
expectedConstants :: [(String, String)]
expectedConstants =
  [ ("Clusters", "{\"source\",\"target\"}")
  , ("MaxOffset", "2")
  , ("MaxDataLoss", "1")
  , ("MinTTL", "1")
  , ("MaxTTL", "60")
  , ("MaxFreshness", "1")
  ]

expectedActions :: [String]
expectedActions =
  [ "ClientWrite", "ReplicationTick", "ActiveCrash", "ColdSeed"
  , "StartPlanned", "StandUpReplica", "Quiesce", "StandbyCrash"
  , "VerifyCaughtUp", "PromotePlanned", "RepointPlannedDns", "Unfreeze"
  , "DrainMonitor", "DecommissionSource", "StandDown", "PromoteSurvivor"
  , "RepointFailoverDns", "BoundedRebind", "Heal", "MergeConverge"
  ]

expectedInvariants :: [String]
expectedInvariants =
  [ "UniqueGatewayOwner"
  , "SessionAlwaysRebindable"
  , "PlannedIsLossless"
  , "NoWriteAfterStaleFailover"
  , "NoTakeWithoutProvenFreshness"
  ]

expectedProperties :: [String]
expectedProperties =
  [ "MergeConverges"
  , "SessionEventuallyRebinds"
  , "PlannedMigrationTerminates"
  ]

expectedRendererFacts :: Map String String
expectedRendererFacts = Map.fromList
  [ ("module", "GatewayMigration")
  , ("extensions", "Integers, FiniteSets, TLC")
  , ("constants", "Clusters, MaxOffset, MaxDataLoss, MinTTL, MaxTTL, MaxFreshness")
  , ("variables", "branch, phase, sourceOwns, targetOwns, sourceUp, targetUp, dns, committed, sourceLog, targetLog, liveSession, rebindable, quiesced, caughtUp, freshnessWitness, coldSeeded, rebound, drainComplete, healed, divergence")
  , ("initial-assignments", "branch,phase,sourceOwns,targetOwns,sourceUp,targetUp,dns,committed,sourceLog,targetLog,liveSession,rebindable,quiesced,caughtUp,freshnessWitness,coldSeeded,rebound,drainComplete,healed,divergence")
  , ("actions", comma expectedActions)
  , ("weak-fairness", comma expectedActions)
  , ("invariants", comma expectedInvariants)
  , ("properties", comma expectedProperties)
  , ("constraint", "StateBound")
  , ("specification", "Spec")
  , ("check-deadlock", "FALSE")
  ]

expectedCalculusFacts :: Map String String
expectedCalculusFacts = Map.fromList
  [ ("calculus-kinds", "artifact,budget,lift,workflow,evidence")
  , ("component-count", "5")
  , ("cpu", "15")
  , ("memory", "150")
  , ("ephemeral", "1500")
  , ("pods", "15")
  , ("formal-distinct-state-count", "1")
  , ("formal-safety", "green")
  ]

expectedInvariantMutants :: [(String, String)]
expectedInvariantMutants =
  [ ("dual-owner-promote", "UniqueGatewayOwner")
  , ("drop-last-endpoint", "SessionAlwaysRebindable")
  , ("verify-while-offsets-lag", "PlannedIsLossless")
  , ("over-budget-divergence", "NoWriteAfterStaleFailover")
  , ("take-without-witness", "NoTakeWithoutProvenFreshness")
  ]

expectedCutoffCases :: [(String, Bool, Maybe FitClause, [MigrationEdge])]
expectedCutoffCases =
  [ ("valid-single", True, Nothing, [edge "a" "b" "a.example" 1 30 1 2])
  , ("valid-independent-pair", True, Nothing,
      [edge "a" "b" "a.example" 1 30 1 2, edge "c" "d" "b.example" 1 30 1 2])
  , ("multi-active", False, Just Pairwise,
      [edge "a" "b" "a.example" 1 30 1 2, edge "a" "c" "b.example" 1 30 1 2])
  , ("cycle", False, Just Acyclic,
      [edge "a" "b" "a.example" 1 30 1 2, edge "b" "a" "b.example" 1 30 1 2])
  , ("shared-dns", False, Just GraphIndependent,
      [edge "a" "b" "a.example" 1 30 1 2, edge "c" "d" "a.example" 1 30 1 2])
  , ("cluster-reuse", False, Just ResourceIndependent,
      [edge "a" "b" "a.example" 1 30 1 2, edge "b" "c" "b.example" 1 30 1 2])
  , ("over-budget", False, Just BudgetWithinCap, [edge "a" "b" "a.example" 2 30 1 2])
  , ("ttl-low", False, Just TtlInRegime, [edge "a" "b" "a.example" 1 0 1 2])
  , ("ttl-high", False, Just TtlInRegime, [edge "a" "b" "a.example" 1 61 1 2])
  , ("freshness-high", False, Just FreshnessInRegime, [edge "a" "b" "a.example" 1 30 2 2])
  , ("offset-high", False, Just OffsetDomainWithinConstants, [edge "a" "b" "a.example" 1 30 1 3])
  ]
  where edge = MigrationEdge

expectedCutoffMutants :: [(String, FitClause)]
expectedCutoffMutants =
  [ ("drop-pairwise", Pairwise)
  , ("drop-graph-independence", GraphIndependent)
  , ("drop-resource-independence", ResourceIndependent)
  , ("drop-acyclic", Acyclic)
  , ("drop-budget", BudgetWithinCap)
  , ("drop-ttl", TtlInRegime)
  , ("drop-freshness", FreshnessInRegime)
  , ("drop-offset-domain", OffsetDomainWithinConstants)
  ]

comma :: [String] -> String
comma [] = ""
comma (value : values) = value <> concatMap (',' :) values
