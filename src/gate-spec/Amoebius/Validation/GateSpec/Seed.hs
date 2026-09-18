{-# LANGUAGE OverloadedStrings #-}

-- | The Phase-0 gate specification: the finite seed (gate integrity section M.4).
-- Its subjects are the validator's own seed vocabulary, which is why the seed
-- role alone may name a validator module; its qualification is the three-case
-- predicate matrix and the custody probes rather than generated mutants; and it
-- carries no binary fact because no product binary exists yet.
module Amoebius.Validation.GateSpec.Seed
  ( custodyProbes
  , phaseZeroSpecInput
  , predicateCases
  ) where

import Amoebius.Validation.GateSpec

-- | The three bypass cases the driver must refuse, plus the clean case.
predicateCases :: [ExactCase]
predicateCases =
  [ PositiveControl "clean-predicate" "Amoebius.Validation.BootstrapPredicate" "silent ExitSuccess"
  , PairedNegative "digest-equality-bypass" "bootstrapDigestMatches" "digest-equality-bypass" "predicate"
  , PairedNegative "snapshot-freshness-bypass" "bootstrapSnapshotMatches" "snapshot-freshness-bypass" "predicate"
  , PairedNegative "bootstrap-path-bypass" "bootstrapInputPathAllowed" "bootstrap-path-bypass" "predicate"
  ]

-- | The custody probes the runner suite states from literals.
custodyProbes :: [ExactCase]
custodyProbes =
  [ PositiveControl "store-seed-roundtrip" "SeedRecord" "equal"
  , PositiveControl "store-receipt-roundtrip" "Receipt" "equal"
  , PairedNegative "store-tampered-receipt" "receipt payload" "signature does not verify" "custody"
  , PairedNegative "tripwire-agent-shell" "CLAUDECODE,AI_AGENT" "ISSUER-AGENT-SESSION" "custody"
  , PairedNegative "preflight-status-surface-dirty" "surface digest" "StatusSurfaceDirty" "preflight"
  , PairedNegative "preflight-verifier-diverged" "verifier digest" "KERNEL-VERIFIER-DIVERGED" "preflight"
  , PairedNegative "preflight-generation-absent" "seed" "GENERATION-ABSENT" "preflight"
  ]

phaseZeroSpecInput :: GateSpecInput
phaseZeroSpecInput =
  GateSpecInput
    { inputCapability = "documentation_suite"
    , inputClaim =
        "For one snapshot, the standalone documentation checker reports zero findings on the governed corpus and the named finding on each rendered negative; the three bootstrap predicate mutants are judged by the independent driver; the custody probes pass; the hygiene row is green at the recorded cap; the generation-2 seed is content-addressed and human-issued."
    , inputSubjects =
        [ ProductionModule "Amoebius.Validation.BootstrapPredicate"
        , ProductionModule "Amoebius.Doc.Check"
        , ProductionModule "Amoebius.Validation.Runner"
        , ProductionModule "Amoebius.Validation.Custody"
        ]
    , inputSuite = CabalTarget "plan-decisions-suite"
    , inputOracle = OracleExecutable "oracle-doc"
    , inputCases = predicateCases <> custodyProbes
    , inputMutants = MutantPolicy {stageModules = [], perModule = 8, perGateCap = 40, killRatio = 3 / 5}
    , inputBinaryFact = Nothing
    , inputSpineFact = Nothing
    , inputSubstrate = HardwareFree
    , inputSeed =
        Just
          SeedSpec
            { seedPredicateCases = ["clean-predicate", "digest-equality-bypass", "snapshot-freshness-bypass", "bootstrap-path-bypass"]
            , seedCustodyProbes = map caseName custodyProbes
            }
    }
