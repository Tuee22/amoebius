{-# LANGUAGE OverloadedStrings #-}
-- | Toolchain gate: shipped stage modules, generated mutants, and a version-request challenge.
module Amoebius.Validation.GateSpec.Toolchain
  ( toolchainCases, toolchainSpecInput ) where
import Amoebius.Validation.GateSpec
toolchainSubjects :: [ProductionModule]
toolchainSubjects =
  [ ProductionModule "Amoebius.Toolchain.Versions"
  , ProductionModule "Amoebius.Toolchain.Acquire"
  , ProductionModule "Amoebius.Toolchain.Probe"
  , ProductionModule "Amoebius.Toolchain.Resolve"
  , ProductionModule "Amoebius.Toolchain.Provenance"
  , ProductionModule "Amoebius.Toolchain.Report"
  ]
toolchainCases :: [ExactCase]
toolchainCases =
  [ PositiveControl "version-compatible-native-tools" "GHCup and GHC version reports" "accepted without an OS, architecture, archive, signature, or executable digest requirement"
  , PositiveControl "second-observation" "same compatible versions" "agree"
  , PositiveControl "version-boundaries" "separately authored version grid" "exact admitted and refused boundaries"
  , PositiveControl "probe-decode" "positive.dhall" "decoded amoebius/3/True"
  , PositiveControl "probe-sim" "clean schedule" "b:2"
  , PositiveControl "probe-codegen" "probe.proto" "Proto/Probe.hs,Proto/Probe_Fields.hs"
  , PositiveControl "probe-bridge" "ProbeContract" "Amoebius/Toolchain/Probe.purs"
  , PositiveControl "probe-plan" "empty inventory" "four ensure steps"
  , PositiveControl "provenance-acquired" "supernova-0.0.3" "tree digest equal"
  , PairedNegative "MissingTool" "absent compiler" "ToolMissing" "versions"
  , PairedNegative "MalformedVersion" "malformed GHCup output" "ToolVersionMalformed" "versions"
  , PairedNegative "UnsupportedGhcupVersion" "GHCup 0.1.50.1" "ToolVersionMismatch" "versions"
  , PairedNegative "UnsupportedVersion" "GHC 9.10.1" "ToolVersionMismatch" "versions"
  , PairedNegative "FailedVersionCommand" "nonzero version command" "ToolCommandFailed" "versions"
  , PairedNegative "MistypedDecode" "mistyped.dhall" "type-error" "probe"
  , PairedNegative "PerturbedSchedule" "perturbed schedule" "a:1" "probe"
  , PairedNegative "MissingDependency" "absent package" "MissingDependency" "resolve"
  , PairedNegative "TrackedResolutionOutput" "cabal.project.freeze" "TrackedResolutionOutput" "resolve"
  , PairedNegative "TrackedProbeInput" "probe.dhall" "TrackedProbeInput" "resolve"
  , PairedNegative "MutableIdentity" "git branch" "MutableIdentity" "provenance"
  , PairedNegative "TopLevelVendor" "vendor/" "TopLevelVendor" "provenance"
  , PairedNegative "UpstreamDigestMismatch" "altered tree digest" "DigestMismatch" "provenance"
  , PairedNegative "AbsentTool" "absent-tool" "AbsentTool" "plan"
  , PairedNegative "OutOfRangeVersion" "ghc 9.10.1" "OutOfRangeVersion" "plan"
  , PairedNegative "NoPlatformAsset" "unsupported-unknown" "NoPlatformAsset" "plan"
  ]
toolchainSpecInput :: GateSpecInput
toolchainSpecInput =
  GateSpecInput
    { inputCapability = "toolchain_spike"
    , inputClaim =
        "The shipped toolchain-report accepts native GHCup and GHC by their declared version requirements, with no toolchain digest pin, signature, archive, operating-system, architecture, or device prerequisite. Two observations agree on versions; the independent oracle judges version boundaries, actual missing/malformed/failed tools, retained decoder/simulator/codegen/provenance probes, and pure planning from supplied platform fixtures. The runner plants a nonce and requests an unsupported compiler version, which the shipped binary reports as refused. Builds remain serial. Compiler correctness and publisher identity remain assumptions."
    , inputSubjects = toolchainSubjects, inputSuite = CabalTarget "toolchain-suite", inputOracle = OracleExecutable "oracle-toolchain"
    , inputCases = toolchainCases
    , inputMutants = defaultMutantPolicy toolchainSubjects
    , inputBinaryFact =
        Just
          BinaryFact
            { factCommand = ["toolchain-report", "--request", "{input}", "--output", "{run}/toolchain-report.tsv", "--probe-root", "{run}/probe"]
            , factInput = "toolchain-request.tsv"
            , factPerturbation = Staged [["toolchain-report", "--write-request", "{input}"]] [] [SentinelToNonce "0b5e17e11a0c0ffee0de1e9a7e5ba5ed", Rewrite "ghc.requested-version\t9.12.4" "ghc.requested-version\t9.10.1"]
            , factOutputs = ["{run}/toolchain-report.tsv"]
            }
    , inputSpineFact = Nothing, inputSubstrate = HardwareFree, inputSeed = Nothing }
