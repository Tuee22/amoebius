{-# LANGUAGE OverloadedStrings #-}
-- | The sole capability-keyed gate registry; absent specifications refuse.
module Amoebius.Validation.GateSpec.Registry
  ( registeredCapabilities
  , specInputFor
  ) where
import Amoebius.Validation.GateSpec
import Amoebius.Validation.GateSpec.Seed (phaseZeroSpecInput)
import Amoebius.Validation.GateSpec.Toolchain (toolchainSpecInput)
import Data.Text (Text)
registeredCapabilities :: [Text]
registeredCapabilities = map fst registry
specInputFor :: Text -> Maybe GateSpecInput
specInputFor capability = lookup capability registry
registry :: [(Text, GateSpecInput)]
registry = [("documentation_suite", phaseZeroSpecInput), ("toolchain_spike", toolchainSpecInput), ("repository_layout_conformance", layoutSpecInput)]

layoutSubjects :: [ProductionModule]
layoutSubjects = map ProductionModule ["Amoebius.Layout.Classify", "Amoebius.Layout.PackageMap", "Amoebius.Layout.PbGrammar", "Amoebius.Layout.Report", "Amoebius.Layout.SourceGraph"]
layoutSpecInput :: GateSpecInput
layoutSpecInput = GateSpecInput
  { inputCapability = "repository_layout_conformance"
  , inputClaim = "The shipped layout-report classifies every present source path, enforces the six admitted metadata paths and bounded bootstrap bytes, and resolves the compiler-backed whole-source graph; the independent oracle judges planted foreign inputs and typed legacy ownership. Archive custody remains verifier-owned."
  , inputSubjects = layoutSubjects
  , inputSuite = CabalTarget "layout-suite"
  , inputOracle = OracleExecutable "oracle-layout"
  , inputCases =
      [PositiveControl "case:positive.bootstrap" "pb/__main__.py" "admitted", PositiveControl "case:six-metadata-files" "six metadata paths" "six classes", PositiveControl "case:positive.archive" "accepted bundle path" "historical-evidence", PositiveControl "case:graph-qualified" "whole source inventory" "resolved"]
      <> [PairedNegative "case:negative.python" "src/example.py" "NonHaskellSource" "classify", PairedNegative "case:negative.dhall" "dhall/example.dhall" "ForeignSourceOwed" "classify", PairedNegative "case:negative.pulumi" "pulumi/Pulumi.yaml" "TrackedPulumiProgram" "classify", PairedNegative "case:negative.test-table" "test/layout/expected.tsv" "NonHaskellTestInput" "classify", PairedNegative "case:negative.ignore-root" "ui/output" "RetiredIgnoreRoot" "classify", PairedNegative "case:negative.ordinal" "src/Amoebius/Phase42Runtime.hs" "OrdinalRuntimeIdentity" "classify", PairedNegative "case:graph.ambiguous-import" "ambiguous import fixture" "AmbiguousSourceImport" "graph", PairedNegative "case:graph.module-path-mismatch" "misdeclared module fixture" "ModuleDeclarationPathMismatch" "graph"]
  , inputMutants = defaultMutantPolicy layoutSubjects
  , inputBinaryFact = Just BinaryFact {factCommand = ["layout-report", "--root", "{tree}", "--paths-file", "{input}", "--output", "{run}/layout-report.tsv"], factInput = "paths.txt", factPerturbation = PlantForeignPaths [("src/Challenge{nonce}.py", "NonHaskellSource"), ("dhall/Challenge{nonce}.dhall", "ForeignSourceOwed"), ("pulumi/Pulumi{nonce}.yaml", "TrackedPulumiProgram")], factOutputs = ["{run}/layout-report.tsv"]}
  , inputSpineFact = Nothing
  , inputSubstrate = HardwareFree
  , inputSeed = Nothing
  }
