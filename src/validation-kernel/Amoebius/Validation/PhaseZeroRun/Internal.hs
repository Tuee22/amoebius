{-# LANGUAGE OverloadedStrings #-}

{- | Package-hidden acquisition of the Phase-0 production subject.

The constructor is not exported.  A caller can supply only the opaque
products acquired by their owning boundaries; this module recomputes the
complete Phase-0 runner subject and binds it to those same products.  Evidence
finalization consumes the resulting value through 'foldAcquiredPhaseZeroRun',
so it cannot pair honest acquisition products with a caller-authored
'CheckResult'.
-}
module Amoebius.Validation.PhaseZeroRun.Internal (
    AcquiredPhaseZeroRun,
    acquiredPhaseZeroRunCheck,
    assembleAcquiredPhaseZeroRun,
    foldAcquiredPhaseZeroRun,
    phaseZeroQualificationAuthorityCheck,
    phaseZeroReadinessBlockers,
    phaseZeroSnapshotDocuments,
    phaseZeroUnavailablePhaseContractCheck,
) where

import Amoebius.Validation.CapabilityGraph (capabilityGraphDiagnosticWith)
import Amoebius.Validation.CompilerSourceGraph.Internal (
    CompilerSourceAttempt,
    compilerSourceAttemptCheck,
 )
import Amoebius.Validation.Documentation.Internal (
    checkDocuments,
    forwardDeferredDeclarations,
 )
import Amoebius.Validation.Gate.Internal qualified as Gate
import Amoebius.Validation.MutationCoverage (
    mutationCoverageCheck,
    mutationPolicyCheck,
 )
import Amoebius.Validation.PhaseContract.Internal (
    AcquiredPhaseContractEvidence,
    acquirePhaseContractEvidence,
    acquiredPhaseContractEvidenceCheck,
 )
import Amoebius.Validation.PhaseRunner.Internal (
    PhaseRunner (DocumentationSuiteRunner),
    phaseRunnerRegistryCheck,
    selectPhaseRunner,
 )
import Amoebius.Validation.PolicyContract.Internal qualified as Policy
import Amoebius.Validation.SourceClosure.Internal (
    AcquiredSourceSnapshot,
    IndexEntry (indexPath),
    SourceSnapshot (snapshotEntries),
    TrackedEntry (trackedBytes, trackedIndex),
    acquiredSourceSnapshot,
    sourceClosureCheckAcquired,
 )
import Amoebius.Validation.SourceDebtBaseline.Internal (
    SourceDebtEvidence,
    sourceDebtEvidenceCheck,
 )
import Amoebius.Validation.Types (
    CheckResult (..),
    Finding,
    checkPassed,
    finding,
    mergeChecks,
    observation,
 )
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import System.FilePath (takeExtension)

data AcquiredPhaseZeroRun
    = AcquiredPhaseZeroRun
        AcquiredSourceSnapshot
        CompilerSourceAttempt
        (Either Gate.QualificationProblem Gate.QualifiedValidationProtocol)
        SourceDebtEvidence
        AcquiredPhaseContractEvidence
        CheckResult

assembleAcquiredPhaseZeroRun ::
    AcquiredSourceSnapshot ->
    CompilerSourceAttempt ->
    Either Gate.QualificationProblem Gate.QualifiedValidationProtocol ->
    SourceDebtEvidence ->
    AcquiredPhaseZeroRun
assembleAcquiredPhaseZeroRun acquired compilerAttempt qualificationAuthority debtEvidence =
    let contractEvidence = acquirePhaseContractEvidence acquired
     in AcquiredPhaseZeroRun
            acquired
            compilerAttempt
            qualificationAuthority
            debtEvidence
            contractEvidence
            (runPhaseZeroSubject acquired compilerAttempt qualificationAuthority debtEvidence contractEvidence)

acquiredPhaseZeroRunCheck :: AcquiredPhaseZeroRun -> CheckResult
acquiredPhaseZeroRunCheck (AcquiredPhaseZeroRun _ _ _ _ _ result) = result

foldAcquiredPhaseZeroRun ::
    ( AcquiredSourceSnapshot ->
      CompilerSourceAttempt ->
      Either Gate.QualificationProblem Gate.QualifiedValidationProtocol ->
      SourceDebtEvidence ->
      AcquiredPhaseContractEvidence ->
      CheckResult ->
      value
    ) ->
    AcquiredPhaseZeroRun ->
    value
foldAcquiredPhaseZeroRun consume (AcquiredPhaseZeroRun acquired compilerAttempt qualificationAuthority debtEvidence contractEvidence result) =
    consume acquired compilerAttempt qualificationAuthority debtEvidence contractEvidence result

runPhaseZeroSubject ::
    AcquiredSourceSnapshot ->
    CompilerSourceAttempt ->
    Either Gate.QualificationProblem Gate.QualifiedValidationProtocol ->
    SourceDebtEvidence ->
    AcquiredPhaseContractEvidence ->
    CheckResult
runPhaseZeroSubject acquired compilerAttempt qualificationAuthority debtEvidence contractEvidence =
    case selectPhaseRunner phaseZeroOrdinal of
        Right DocumentationSuiteRunner ->
            mergeChecks
                "phase-00"
                [ phaseRunnerRegistryCheck
                , checkAcquiredPhaseZeroSnapshotCore acquired compilerAttempt qualificationAuthority debtEvidence contractEvidence
                ]
        Left problem ->
            CheckResult
                { checkName = "phase-00"
                , checkObservations =
                    [ observation "phase.ordinal" "00"
                    , observation "phase.runner" "absent or ambiguous"
                    ]
                , checkFindings = [problem]
                }

checkAcquiredPhaseZeroSnapshotCore ::
    AcquiredSourceSnapshot ->
    CompilerSourceAttempt ->
    Either Gate.QualificationProblem Gate.QualifiedValidationProtocol ->
    SourceDebtEvidence ->
    AcquiredPhaseContractEvidence ->
    CheckResult
checkAcquiredPhaseZeroSnapshotCore acquired compilerAttempt qualificationAuthority debtEvidence contractEvidence =
    case phaseZeroSnapshotDocuments snapshot of
        Left decodeFindings ->
            mergeChecks
                "phase-00"
                ( acquiredSourceChecks
                    <> [ Policy.checkPolicyContract Policy.canonicalPolicyContract
                       , CheckResult "documentation-snapshot" [] decodeFindings
                       , acquiredPhaseContractEvidenceCheck contractEvidence
                       , capabilityGraphDiagnosticWith []
                       , mutationCoverageCheck
                       , mutationPolicyCheck []
                       , phaseZeroReadinessBlockers
                       ]
                )
        Right documents ->
            let phaseContractResult = acquiredPhaseContractEvidenceCheck contractEvidence
                readiness =
                    unobservedPhaseReadiness
                        { readinessPhaseContractSemantics =
                            observedWhenPassed
                                "captured Markdown correspondence and compiled Phase-0 semantic contract are exact"
                                phaseContractResult
                        }
             in mergeChecks
                    "phase-00"
                    ( acquiredSourceChecks
                        <> [ Policy.checkPolicyContract Policy.canonicalPolicyContract
                           , checkDocuments documents
                           , phaseContractResult
                           , capabilityGraphDiagnosticWith (forwardDeferredDeclarations documents)
                           , mutationCoverageCheck
                           , mutationPolicyCheck documents
                           , phaseReadinessCheck readiness
                           ]
                    )
  where
    snapshot = acquiredSourceSnapshot acquired
    acquiredSourceChecks =
        [ sourceClosureCheckAcquired acquired
        , sourceDebtEvidenceCheck acquired debtEvidence
        , compilerSourceAttemptCheck compilerAttempt
        , acquiredCompilerDispatchQualificationResidue
        , phaseZeroQualificationAuthorityCheck qualificationAuthority
        ]

acquiredCompilerDispatchQualificationResidue :: CheckResult
acquiredCompilerDispatchQualificationResidue =
    CheckResult
        { checkName = "acquired-compiler-dispatch-qualification"
        , checkObservations =
            [ observation
                "compiler-dispatch.local-source"
                "captured; changed-subject qualification remains open"
            ]
        , checkFindings =
            [ finding
                "ACQUIRED-COMPILER-DISPATCH-UNQUALIFIED"
                "Amoebius.Validation.Dispatch"
                "the acquired compiler-dispatch branch has not passed its changed-subject qualification matrix"
            ]
        }

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

data PhaseReadiness = PhaseReadiness
    { readinessPolicyContract :: Maybe Text
    , readinessPbGrammar :: Maybe Text
    , readinessPhaseContractSemantics :: Maybe Text
    , readinessOracleIndependence :: Maybe Text
    , readinessCleanroomObserver :: Maybe Text
    }
    deriving (Eq, Show)

unobservedPhaseReadiness :: PhaseReadiness
unobservedPhaseReadiness =
    PhaseReadiness
        { readinessPolicyContract = Nothing
        , readinessPbGrammar = Nothing
        , readinessPhaseContractSemantics = Nothing
        , readinessOracleIndependence = Nothing
        , readinessCleanroomObserver = Nothing
        }

data ReadinessRow = ReadinessRow
    { readinessKey :: Text
    , readinessAbsentDetail :: Text
    , readinessCode :: Text
    , readinessSubject :: FilePath
    , readinessRefusal :: Text
    , readinessEvidence :: PhaseReadiness -> Maybe Text
    }

readinessRows :: [ReadinessRow]
readinessRows =
    [ ReadinessRow
        "readiness.policy-contract"
        "typed contract is integrated; changed-subject qualification and documentation correspondence check are absent"
        "POLICY-CONTRACT-UNQUALIFIED"
        "Amoebius.Validation.PolicyContract"
        "the typed cross-cutting contract is integrated, but its Registry-provider, owner-map, and pb-transport changed-subject mutants have not been qualified and the documentation correspondence gate has not passed"
        readinessPolicyContract
    , ReadinessRow
        "readiness.pb-source-grammar"
        "the static source-bound grammar is integrated; changed-subject qualification and the separately authored oracle are absent"
        "PB-GRAMMAR-UNQUALIFIED"
        "Amoebius.Validation.PbBootstrapGrammar"
        "the versioned static AST/import/resolved-call/control-flow/potential-effect analyzer is integrated, but its changed-subject qualification and separately authored oracle remain open; Phase 50 alone owns external runtime handoff observation"
        readinessPbGrammar
    , ReadinessRow
        "readiness.phase-contract-semantics"
        "the closed typed registry, structural joins, and phase-scoped gap rule are integrated; the phase-under-validation slots are not yet bound"
        "PHASE-CONTRACT-SEMANTIC-GAPS"
        "Amoebius.Validation.PhaseContract"
        "the closed typed 96-phase registry and structural joins are integrated, but the slots owned by the phase under validation are still ContractGap"
        readinessPhaseContractSemantics
    , ReadinessRow
        "readiness.oracle-independence"
        "complete gate result absent"
        "ORACLE-INDEPENDENCE-MISSING"
        "phase-00-oracles"
        "component diagnostics are not a complete qualified gate"
        readinessOracleIndependence
    , ReadinessRow
        "readiness.cleanroom-residue"
        "external observer absent"
        "CLEANROOM-OBSERVER-MISSING"
        "phase-00-cleanroom"
        "fresh-run input closure and external residue have no implemented independent observer"
        readinessCleanroomObserver
    ]

phaseReadinessCheck :: PhaseReadiness -> CheckResult
phaseReadinessCheck readiness =
    CheckResult
        { checkName = "phase-00-readiness"
        , checkObservations =
            [ observation
                (readinessKey row)
                (maybe (readinessAbsentDetail row) ("observed=" <>) (readinessEvidence row readiness))
            | row <- readinessRows
            ]
                <> [observation "readiness.local-source-capture" "opening and closing exact local snapshots are integrated"]
        , checkFindings =
            [ finding (readinessCode row) (readinessSubject row) (readinessRefusal row)
            | row <- readinessRows
            , readinessEvidence row readiness == Nothing
            ]
        }

phaseZeroQualificationAuthorityCheck ::
    Either Gate.QualificationProblem Gate.QualifiedValidationProtocol ->
    CheckResult
phaseZeroQualificationAuthorityCheck authority =
    case authority of
        Left problem ->
            CheckResult
                { checkName = "phase-00-harness-qualification"
                , checkObservations =
                    [ observation
                        "readiness.harness-qualification"
                        "refused by the package-hidden qualification authority"
                    ]
                , checkFindings =
                    [ finding
                        (Gate.qualificationProblemCode problem)
                        (Gate.qualificationProblemSubject problem)
                        (Gate.qualificationProblemDetail problem)
                    ]
                }
        Right protocol ->
            CheckResult
                { checkName = "phase-00-harness-qualification"
                , checkObservations =
                    [ observation
                        "readiness.harness-qualification"
                        ("qualified-protocol=" <> Gate.qualificationProtocolDigest protocol)
                    ]
                , checkFindings = []
                }

observedWhenPassed :: Text -> CheckResult -> Maybe Text
observedWhenPassed detail result
    | checkPassed result = Just detail
    | otherwise = Nothing

phaseZeroReadinessBlockers :: CheckResult
phaseZeroReadinessBlockers = phaseReadinessCheck unobservedPhaseReadiness

phaseZeroSnapshotDocuments :: SourceSnapshot -> Either [Finding] [(FilePath, Text)]
phaseZeroSnapshotDocuments snapshot =
    if null problems then Right documents else Left problems
  where
    markdownEntries =
        [ entry
        | entry <- snapshotEntries snapshot
        , takeExtension (indexPath (trackedIndex entry)) == ".md"
        ]
    decoded = fmap decodeEntry markdownEntries
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
