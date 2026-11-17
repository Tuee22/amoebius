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
  , PairedNegative "case:simulation.terminal-pair" "completed simulation without a terminal value" "SimulationNoOutput with clean terminal control" "probe"
  , PairedNegative "case:planner.paired-remedies" "missing tool, unsupported version and absent platform asset" "exact actionable remedies with supported controls" "plan"
  , PairedNegative "case:resolution.source-pairs" "tracked freeze, package pin and developer-home metadata" "named source refusals with contained controls" "resolve"
  , PositiveControl "case:build.fixed-serial-arguments" "caller concurrency and compiler options, native configuration pairs, and actual successful and absent-package tool installs" "fixed offline serial native invocation, preserved payload, owned configuration and temporary paths, read-only native inputs, complete cache-copy evidence and cleanup"
  , PositiveControl "case:resolution.first-plan" "first native compatible resolution" "actual plan units, packages and digest agree with independent JSON decoding"
  , PositiveControl "case:resolution.second-plan" "second native compatible resolution" "actual plan units, packages and digest agree with independent JSON decoding"
  , PositiveControl "case:resolution.agreement" "two independently observed native resolutions" "equal complete unit graphs, package sets and digests"
  , PairedNegative "case:resolution.disagreement" "changed observed units, packages and digest" "PlansDisagree at each changed field" "resolve"
  , PairedNegative "case:resolution.dropped-allowance" "removed decoder dependency declaration" "MissingCompatibilityAllowance before effects" "resolve"
  , PairedNegative "case:resolution.outside-root" "resolution output outside the build root" "ResolutionRootOutsideBuild before effects" "resolve"
  , PositiveControl "case:resolution.authored-unchanged" "two actual resolutions" "complete authored source identity unchanged"
  , PositiveControl "case:resolution.generated-ignored" "actual generated resolution files" "every output is beneath the admitted ignored root"
  , PositiveControl "case:upstream.cache-positive" "native package cache archive" "actual local extraction, source digest and complete action projection"
  , PositiveControl "case:upstream.supplied-cache-positive" "explicit cached archive input with outside-root and ancestor-symlink twins" "same source identity without any child process; unsafe destinations refused before effects"
  , PositiveControl "case:upstream.cache-only-query" "native cache discovery" "only the read-only offline package-cache query executes"
  , PairedNegative "case:upstream.digest-negative" "wrong upstream source digest" "DigestMismatch before destination creation" "provenance"
  , PairedNegative "case:upstream.missing-cache-negative" "absent cached upstream archive" "CachedArchiveMissing without fallback or destination creation" "provenance"
  , PairedNegative "case:upstream.absent-identity" "empty release name or version" "AbsentIdentity before acquisition effects" "provenance"
  , PositiveControl "case:report.cli.plan-a" "public acquisition report first plan" "actual JSON units, compatible packages and digest match report"
  , PositiveControl "case:report.cli.plan-b" "public acquisition report second plan" "actual JSON units, compatible packages and digest match report"
  , PositiveControl "case:report.cli.plans-agree" "public acquisition report repeated plans" "observed complete plans agree"
  , PositiveControl "case:report.cli.source" "public report source inspection" "no tracked resolution findings"
  ]
toolchainSpecInput :: GateSpecInput
toolchainSpecInput =
  GateSpecInput
    { inputCapability = "toolchain_spike"
    , inputClaim =
        "The shipped toolchain-report accepts native GHCup and GHC by their declared version requirements, with no toolchain digest pin, signature, archive, operating-system, architecture, or device prerequisite. Two observations agree on versions; the independent oracle judges version boundaries, actual missing/malformed/failed tools, retained decoder/simulator/codegen/provenance probes, and pure planning from supplied platform fixtures. The runner plants a nonce and requests an unsupported compiler version, which the shipped binary reports as refused. Builds remain serial. Compiler correctness and publisher identity remain assumptions."
    , inputSubjects = toolchainSubjects, inputSuite = CabalTarget "toolchain-suite", inputOracle = OracleExecutable "oracle-toolchain"
    , inputCases = toolchainCases
    , inputMutants = (defaultMutantPolicy toolchainSubjects) {stageArtefacts = [(owner,prefix) | (owner,prefixes) <- [("Amoebius.Toolchain.Versions",["version.","versions.","case:planner.paired-remedies","negative.MalformedVersion","negative.UnsupportedVersion","negative.UnsupportedGhcupVersion"]),("Amoebius.Toolchain.Acquire",["admission.","child.","second.","versions.","case:build.fixed-serial-arguments","negative.MissingTool","negative.FailedVersionCommand","negative.MalformedVersion","negative.UnsupportedVersion","negative.UnsupportedGhcupVersion"]),("Amoebius.Toolchain.Probe",["probe.","report.probe.","probe-source.","case:simulation.terminal-pair","negative.TrackedProbeInput","negative.MissingDependency"]),("Amoebius.Toolchain.Resolve",["plan.","report.plan.","report.resolution.","case:resolution.","case:report.cli.plan-","case:planner.paired-remedies","negative.TrackedResolutionOutput","negative.MissingDependency"]),("Amoebius.Toolchain.Provenance",["fork.","upstream.","vendor-source.","report.provenance.","case:upstream.","layout.problems","negative.MutableIdentity","negative.TopLevelVendor","negative.UpstreamDigestMismatch"]),("Amoebius.Toolchain.Report",["report.","case:report.cli.","negative.ReportUnknownArgument"])], prefix <- prefixes]}
    , inputBinaryFact =
        Just
          BinaryFact
            { factCommand = ["toolchain-report", "--request", "{input}", "--output", "{run}/toolchain-report.tsv", "--probe-root", "{run}/probe"]
            , factInput = "toolchain-request.tsv"
            , factPerturbation = Staged [["toolchain-report", "--write-request", "{input}"]] [] [SentinelToNonce "0b5e17e11a0c0ffee0de1e9a7e5ba5ed", Rewrite "ghc.requested-version\t9.12.4" "ghc.requested-version\t9.10.1"]
            , factOutputs = ["{run}/toolchain-report.tsv"]
            }
    , inputSpineFact = Nothing, inputSubstrate = HardwareFree, inputSeed = Nothing }
