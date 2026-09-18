{-# LANGUAGE OverloadedStrings #-}

-- | The toolchain-spike gate specification: the first product specification.
-- Its subjects are the six toolchain stage modules inside the shipped
-- executable's closure; its qualification is the generated mutant matrix; and
-- its binary fact rewrites the pinned compiler manifest's archive digest to the
-- run's nonce, so the shipped report must carry the nonce and refuse at exactly
-- that archive.
module Amoebius.Validation.GateSpec.Toolchain
  ( toolchainCases
  , toolchainSpecInput
  ) where

import Amoebius.Validation.GateSpec

toolchainSubjects :: [ProductionModule]
toolchainSubjects =
  [ ProductionModule "Amoebius.Toolchain.Pins"
  , ProductionModule "Amoebius.Toolchain.Acquire"
  , ProductionModule "Amoebius.Toolchain.Probe"
  , ProductionModule "Amoebius.Toolchain.Resolve"
  , ProductionModule "Amoebius.Toolchain.Provenance"
  , ProductionModule "Amoebius.Toolchain.Report"
  ]

toolchainCases :: [ExactCase]
toolchainCases =
  [ PositiveControl "pinned-acquisition" "seven pins" "agree"
  , PositiveControl "second-acquisition" "same pins, absent root" "same identities and plan"
  , PositiveControl "publisher-signature" "operator keyring" "good"
  , PositiveControl "probe-decode" "positive.dhall" "decoded amoebius/3/True"
  , PositiveControl "probe-sim" "clean schedule" "b:2"
  , PositiveControl "probe-codegen" "probe.proto" "Proto/Probe.hs,Proto/Probe_Fields.hs"
  , PositiveControl "probe-bridge" "ProbeContract" "Amoebius/Toolchain/Probe.purs"
  , PositiveControl "probe-plan" "empty inventory" "four ensure steps"
  , PositiveControl "provenance-acquired" "supernova-0.0.3" "tree digest equal"
  , PairedNegative "MissingPin" "absent manifest" "PinMissing" "pins"
  , PairedNegative "DigestMismatch" "corrupted manifest" "PinDigestMismatch" "pins"
  , PairedNegative "SignatureMismatch" "corrupted signature" "SignatureRejected" "signatures"
  , PairedNegative "AmbientNetworkRead" "URL source" "AmbientNetworkRefused" "pins"
  , PairedNegative "DisagreeingAcquisition" "altered identity" "AcquisitionsDisagree" "acquire"
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
  , PairedNegative "NoPlatformAsset" "windows-x86_64" "NoPlatformAsset" "plan"
  ]

toolchainSpecInput :: GateSpecInput
toolchainSpecInput =
  GateSpecInput
    { inputCapability = "toolchain_spike"
    , inputClaim =
        "From GenesisTrust and its seven pinned files, two contained acquisitions produce the pinned compiler and package tool and agree on executable identity and elaborated plan; the shipped toolchain-report prints the pins, manifests, signatures, identities, and probe outcomes the oracle restates; the retained probe set builds and executes offline and serially; every negative is refused by name at its locus."
    , inputSubjects = toolchainSubjects
    , inputSuite = CabalTarget "toolchain-suite"
    , inputOracle = OracleExecutable "oracle-toolchain"
    , inputCases = toolchainCases
    , inputMutants = defaultMutantPolicy toolchainSubjects
    , inputBinaryFact =
        Just
          BinaryFact
            { factCommand = ["toolchain-report", "--compiler-manifest", "{input}", "--output", "{run}/toolchain-report.tsv", "--probe-root", "{run}/probe"]
            , factInput = ".build/bootstrap-inputs/ghc-SHA256SUMS"
            , factPerturbation = SentinelToNonce "4da657809c06c1658ae5713911fcb168a32093e239f61fe77be78aba74132cfa"
            , factOutputs = ["{run}/toolchain-report.tsv"]
            }
    , inputSpineFact = Nothing
    , inputSubstrate = HardwareFree
    , inputSeed = Nothing
    }
