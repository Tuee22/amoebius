{-# LANGUAGE OverloadedStrings #-}

-- | Package-hidden composition of the finite Phase-0 bootstrap subject.
--
-- Phase 0 proves this bounded subject only. Compiler-wide source semantics,
-- universal self-reference, reproducible acquisition, and later mutation
-- families remain with their numbered capability owners.
module Amoebius.Validation.PhaseZeroRun.Internal
  ( AcquiredPhaseZeroRun
  , acquiredPhaseZeroRunCheck
  , assembleAcquiredPhaseZeroRun
  , foldAcquiredPhaseZeroRun
  , phaseZeroSnapshotDocuments
  , phaseZeroUnavailablePhaseContractCheck
  ) where

import Amoebius.Validation.BootstrapQualification.Internal
  ( QualifiedBootstrapProtocol
  , bootstrapQualificationCheck
  )
import Amoebius.Validation.BootstrapTrust.Internal
  ( GenesisTrust
  , genesisTrustCheck
  )
import Amoebius.Validation.CapabilityGraph (capabilityGraphDiagnosticWith)
import Amoebius.Validation.Documentation.Internal
  ( checkDocuments
  , forwardDeferredDeclarations
  )
import Amoebius.Validation.MutationCoverage
  ( mutationCoverageCheck
  , mutationPolicyCheck
  )
import Amoebius.Validation.PhaseContract.Internal
  ( AcquiredPhaseContractEvidence
  , acquirePhaseContractEvidence
  , acquiredPhaseContractEvidenceCheck
  )
import Amoebius.Validation.PhaseRunner.Internal
  ( PhaseRunner (DocumentationSuiteRunner)
  , phaseRunnerRegistryCheck
  , selectPhaseRunner
  )
import Amoebius.Validation.PolicyContract.Internal qualified as Policy
import Amoebius.Validation.SourceClosure.Internal
  ( AcquiredSourceSnapshot
  , IndexEntry (indexPath)
  , SourceSnapshot (snapshotEntries)
  , TrackedEntry (trackedBytes, trackedIndex)
  , acquiredSourceSnapshot
  , sourceClosureCheckAcquired
  )
import Amoebius.Validation.SourceDebtBaseline.Internal
  ( SourceDebtEvidence
  , sourceDebtEvidenceCheckForPhaseZero
  )
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding
  , finding
  , mergeChecks
  , observation
  )
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import System.FilePath (takeExtension)

data AcquiredPhaseZeroRun
  = AcquiredPhaseZeroRun
      AcquiredSourceSnapshot
      GenesisTrust
      QualifiedBootstrapProtocol
      SourceDebtEvidence
      AcquiredPhaseContractEvidence
      CheckResult

assembleAcquiredPhaseZeroRun
  :: AcquiredSourceSnapshot
  -> GenesisTrust
  -> QualifiedBootstrapProtocol
  -> SourceDebtEvidence
  -> AcquiredPhaseZeroRun
assembleAcquiredPhaseZeroRun acquired trust qualification debtEvidence =
  let contractEvidence = acquirePhaseContractEvidence acquired
      result = runPhaseZeroSubject acquired trust qualification debtEvidence contractEvidence
   in AcquiredPhaseZeroRun acquired trust qualification debtEvidence contractEvidence result

acquiredPhaseZeroRunCheck :: AcquiredPhaseZeroRun -> CheckResult
acquiredPhaseZeroRunCheck (AcquiredPhaseZeroRun _ _ _ _ _ result) = result

foldAcquiredPhaseZeroRun
  :: ( AcquiredSourceSnapshot
       -> GenesisTrust
       -> QualifiedBootstrapProtocol
       -> SourceDebtEvidence
       -> AcquiredPhaseContractEvidence
       -> CheckResult
       -> value
     )
  -> AcquiredPhaseZeroRun
  -> value
foldAcquiredPhaseZeroRun consume (AcquiredPhaseZeroRun acquired trust qualification debtEvidence contractEvidence result) =
  consume acquired trust qualification debtEvidence contractEvidence result

runPhaseZeroSubject
  :: AcquiredSourceSnapshot
  -> GenesisTrust
  -> QualifiedBootstrapProtocol
  -> SourceDebtEvidence
  -> AcquiredPhaseContractEvidence
  -> CheckResult
runPhaseZeroSubject acquired trust qualification debtEvidence contractEvidence =
  case selectPhaseRunner phaseZeroOrdinal of
    Right DocumentationSuiteRunner ->
      mergeChecks
        "phase-00"
        [ phaseRunnerRegistryCheck
        , checkAcquiredPhaseZeroSnapshotCore acquired trust qualification debtEvidence contractEvidence
        ]
    Right runner ->
      CheckResult
        { checkName = "phase-00"
        , checkObservations =
            [ observation "phase.ordinal" "00"
            , observation "phase.runner" (Text.pack (show runner))
            ]
        , checkFindings =
            [ finding
                "PHASE-RUNNER-CAPABILITY-MISMATCH"
                "phase-00"
                "the finite bootstrap subject was reached by a runner registered for another capability"
            ]
        }
    Left problem ->
      CheckResult
        { checkName = "phase-00"
        , checkObservations =
            [ observation "phase.ordinal" "00"
            , observation "phase.runner" "absent or ambiguous"
            ]
        , checkFindings = [problem]
        }

checkAcquiredPhaseZeroSnapshotCore
  :: AcquiredSourceSnapshot
  -> GenesisTrust
  -> QualifiedBootstrapProtocol
  -> SourceDebtEvidence
  -> AcquiredPhaseContractEvidence
  -> CheckResult
checkAcquiredPhaseZeroSnapshotCore acquired trust qualification debtEvidence contractEvidence =
  case phaseZeroSnapshotDocuments snapshot of
    Left decodeFindings ->
      mergeChecks
        "phase-00"
        (commonChecks <> [CheckResult "documentation-snapshot" [] decodeFindings])
    Right documents ->
      mergeChecks
        "phase-00"
        ( commonChecks
            <> [ checkDocuments documents
               , capabilityGraphDiagnosticWith (forwardDeferredDeclarations documents)
               , mutationPolicyCheck documents
               ]
        )
 where
  snapshot = acquiredSourceSnapshot acquired
  commonChecks =
    [ sourceClosureCheckAcquired acquired
    , sourceDebtEvidenceCheckForPhaseZero acquired debtEvidence
    , genesisTrustCheck trust
    , bootstrapQualificationCheck (Right qualification)
    , Policy.checkPolicyContract Policy.canonicalPolicyContract
    , acquiredPhaseContractEvidenceCheck contractEvidence
    , mutationCoverageCheck
    ]

phaseZeroUnavailablePhaseContractCheck :: [Finding] -> CheckResult
phaseZeroUnavailablePhaseContractCheck decodeFindings =
  CheckResult
    { checkName = "phase-contract-snapshot"
    , checkObservations =
        [ observation
            "phase-contract.snapshot-input"
            "unavailable because the tracked Markdown snapshot did not decode"
        ]
    , checkFindings =
        [ finding
            "PHASE-CONTRACT-SNAPSHOT-UNAVAILABLE"
            "DEVELOPMENT_PLAN/"
            ( "phase-contract analysis did not run because "
                <> Text.pack (show (length decodeFindings))
                <> " tracked Markdown document(s) failed UTF-8 decoding"
            )
        ]
    }

phaseZeroSnapshotDocuments :: SourceSnapshot -> Either [Finding] [(FilePath, Text)]
phaseZeroSnapshotDocuments snapshot =
  if null problems then Right documents else Left problems
 where
  markdownEntries =
    [ entry
    | entry <- snapshotEntries snapshot
    , takeExtension (indexPath (trackedIndex entry)) == ".md"
    ]
  decoded = map decodeEntry markdownEntries
  documents = [document | Right document <- decoded]
  problems = [problem | Left problem <- decoded]
  decodeEntry entry =
    let path = indexPath (trackedIndex entry)
     in case TextEncoding.decodeUtf8' (trackedBytes entry) of
          Left _ ->
            Left
              ( finding
                  "DOC-SNAPSHOT-UTF8"
                  path
                  "tracked Markdown blob is not UTF-8"
              )
          Right contents -> Right (path, contents)

phaseZeroOrdinal :: Int
phaseZeroOrdinal =
  Policy.phaseOrdinalNumber
    (Policy.phaseDomainLower (Policy.orderingContract Policy.canonicalPolicyContract))
