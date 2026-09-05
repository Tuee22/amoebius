{-# LANGUAGE OverloadedStrings #-}

-- | Independent Phase-24 inventory. No production gate/generator type is imported.
module ExtensionConformanceGateOracle
  ( suiteInventory
  , coverageGrid
  , expectedVerdictCases
  ) where

import Data.Text (Text)
import Data.Text qualified as Text

suiteInventory :: [(Text, Text, Text)]
suiteInventory =
  [ ("property", "L1", "inference-workflow")
  , ("property", "L2", "infernix-image")
  , ("property", "L3", "inference-budget")
  , ("property", "L4", "inference-workflow")
  , ("property", "L5", "inference-evidence")
  ]
  <> [("composition", "C" <> number, "jitml") | number <- map (Text.pack . show) [1 :: Int .. 7]]
  <> [("compile-fail", "compile", "inference-evidence")]
  <> [("security", "S" <> number, "security-boundary") | number <- map (Text.pack . show) [1 :: Int .. 6]]

coverageGrid :: [(Text, Text, Text, Text)]
coverageGrid =
  [(law, axis, "required", "-") | (_, law, axis) <- suiteInventory, law /= "compile"]
  <> [("P" <> Text.pack (show number), "transaction-vocabulary", "not-applicable", "transaction-vocabulary-not-declared") | number <- [1 :: Int .. 6]]

expectedVerdictCases :: [(Text, Text)]
expectedVerdictCases =
  [ ("canonical", "sealed-and-admitted")
  , ("modified-suite", "GeneratedSuiteMismatch")
  , ("failed-case", "CasesFailed")
  , ("wrong-declaration", "PlanDeclarationMismatch")
  , ("changed-core", "VerdictDidNotVerify")
  ]
