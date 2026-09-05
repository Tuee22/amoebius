{-# LANGUAGE OverloadedStrings #-}

module ExtensionLawsPerExtensionOracle
  ( OracleOperationCase (..)
  , OracleVerdict (..)
  , operationCases
  , expectedVerdicts
  , mutantProperties
  ) where

import Data.Text (Text)

data OracleOperationCase = OracleOperationCase Text Text Text deriving stock (Eq, Ord, Show)
data OracleVerdict = OracleVerdict Text Text [Text] deriving stock (Eq, Ord, Show)

operationCases :: [OracleOperationCase]
operationCases =
  [ OracleOperationCase "infernix" "empty" "infernix:empty"
  , OracleOperationCase "infernix" "known" "infernix:known"
  , OracleOperationCase "infernix" "panic" "infernix:panic"
  , OracleOperationCase "jitml" "empty" "jitml:empty"
  , OracleOperationCase "jitml" "known" "jitml:known"
  , OracleOperationCase "jitml" "panic" "jitml:panic"
  ]

expectedVerdicts :: [OracleVerdict]
expectedVerdicts =
  [ verdict "infernix-lawful" "infernix" ["PASS", "PASS", "PASS", "PASS", "PASS"]
  , verdict "jitml-lawful" "jitml" ["PASS", "PASS", "PASS", "PASS", "PASS"]
  , verdict "l1-partial" "infernix" ["FAIL:OperationEscaped", "PASS", "PASS", "PASS", "PASS"]
  , verdict "l2-ambient-render" "infernix" ["PASS", "FAIL:ArtifactBytesDiffer", "PASS", "PASS", "PASS"]
  , verdict "l3-reaper-omitted" "infernix" ["PASS", "PASS", "FAIL:RetainedOutputHasNoReaper", "PASS", "PASS"]
  , verdict "l4-scope-widened" "infernix" ["PASS", "PASS", "PASS", "FAIL:ScopeWasWidened", "PASS"]
  , verdict "l5-fixture-omitted" "infernix" ["PASS", "PASS", "PASS", "PASS", "FAIL:ClaimHasNoFixture"]
  ]
 where verdict = OracleVerdict

mutantProperties :: [(Text, Text, Text)]
mutantProperties =
  [ ("ignore-operation-escape", "L1", "Totality")
  , ("ignore-artifact-difference", "L2", "Determinism")
  , ("ignore-retention-reaper", "L3", "BudgetHonesty")
  , ("ignore-scope-widening", "L4", "ScopePropagation")
  , ("ignore-missing-fixture", "L5", "EvidenceBinding")
  ]
