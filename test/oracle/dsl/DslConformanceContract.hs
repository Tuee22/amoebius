{-# LANGUAGE OverloadedStrings #-}

-- Independent finite conformance contract, authored before the product model.
-- Compiler barriers are observed by native client pairs in the parent gate;
-- a pure model cannot turn that premise into authenticated execution.
module DslConformanceContract
  ( perExtensionLaws, compositionLaws, securityLaws, modeledPremises
  , fourMemberInventory, twoMemberInventory, modelControls, lawFaults, nativeScopeRoles
  , suiteFileNames, finiteCoreVersion, declaredBudgets
  ) where

import Data.Text (Text)

perExtensionLaws, compositionLaws, securityLaws, modeledPremises :: [Text]
perExtensionLaws = ["L1", "L2", "L3", "L4", "L5"]
compositionLaws = ["C1", "C2", "C3", "C4", "C5", "C6", "C7"]
securityLaws = ["S1", "S2", "S3", "S4", "S5", "S6"]
modeledPremises = ["compiler-correctness", "native-scope-client-pairs-required", "observer-authentication-unverified", "sha256-collision-resistance"]

-- member count, cases per member, coverage cells per member, generated files.
fourMemberInventory, twoMemberInventory :: (Int, Int, Int, Int)
fourMemberInventory = (4, 33, 38, 6)
twoMemberInventory = (2, 19, 24, 6)

modelControls :: [(Text, Text)]
modelControls =
  [ ("legal", "accepted")
  , ("missing-law", "MissingLawObservation")
  , ("duplicate-law", "DuplicateLawObservation")
  , ("failed-law", "ModeledLawFailed")
  , ("missing-compiler-premise", "NativeCompilerBoundaryRequired")
  , ("missing-generated-file", "GeneratedSuiteMismatch")
  , ("missing-case", "CaseInventoryMismatch")
  , ("duplicate-case", "CaseInventoryMismatch")
  , ("failed-case", "CasesFailed")
  , ("wrong-declaration", "PlanDeclarationMismatch")
  , ("wrong-core", "VerdictDidNotVerify")
  , ("duplicate-admission", "ExtensionAlreadyAdmitted")
  , ("missing-refusal-probe", "RefusalProbeCoverageMismatch")
  , ("missing-namespace-probe", "NamespaceProbeCoverageMismatch")
  , ("missing-authority-probe", "AuthorityProbeCoverageMismatch")
  ]

-- Each variant alters an actual law observation. Some clauses intentionally
-- overlap: an escaped part changes both closure and non-interference, and a
-- widened composite flow also violates the composite's L4 clause.
lawFaults :: [(Text, [Text])]
lawFaults =
  [("L1", ["L1"]), ("L2", ["L2"]), ("L3", ["L3"]), ("L4", ["L4"]), ("L5", ["L5"]),
   ("C1", ["C1", "C4"]), ("C2", ["C2"]), ("C3", ["C3"]), ("C4", ["C4"]),
   ("C5", ["C5"]), ("C6", ["C1", "C4", "C6"]), ("C7", ["C7"]),
   ("S1", ["S1"]), ("S2", ["S2"]), ("S3", ["S3"]),
   ("S4", ["S4"]), ("S5", ["S5"]), ("S6", ["S6"])]

nativeScopeRoles :: [Text]
nativeScopeRoles = ["gate-plan", "conformance-verdict", "guarded-link-set", "modeled-link-set",
  "request-scope", "scoped-value", "scoped-handle", "flow-label", "flow-witness", "declaration",
  "monitor-access", "workflow-monitor", "monitor-store-reference", "monitoring-surface"]

suiteFileNames :: [FilePath]
suiteFileNames = ["compile-fail-suite.tsv", "composition-suite.tsv", "coverage-grid.tsv",
  "property-suite.tsv", "security-suite.tsv", "transaction-suite.tsv"]

finiteCoreVersion :: Text
finiteCoreVersion = "amoebius-finite-conformance-v1"

-- Actual supplied configuration, rather than an oracle-producer projection.
declaredBudgets :: [(Text, [Text])]
declaredBudgets = [("coordination", ["0", "0", "0"]), ("jit-build", ["4096", "3", "1024"]),
  ("infernix", ["8192", "0", "8192"]), ("jitml", ["0", "0", "0"])]
