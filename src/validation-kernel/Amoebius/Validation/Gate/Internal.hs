{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

{- | Package-hidden qualification authority.

The public qualification-report checker accepts caller-constructed diagnostic
records, so none of its values occur in this module's authority graph.  A real
qualification supervisor must eventually be the sole producer of a
'QualificationAttempt'.  The attempt fixes one execution identity and one
observation for every member of the closed sabotage corpus.  Only a verified
attempt may eventually produce a 'QualifiedValidationProtocol'.

No such supervisor is implemented today.  Consequently this module exports no
constructor or smart constructor for an attempt, any of its identity values,
or a qualified protocol.  Its two current production entry points return the
same explicit refusal.  Keeping the detailed types now prevents later work
from filling the qualification evidence slot with the public report
diagnostic or a caller-supplied digest.
-}
module Amoebius.Validation.Gate.Internal (
    QualificationAttempt,
    QualificationProblem,
    QualifiedValidationProtocol,
    QualificationSourceSnapshotIdentity,
    QualificationExecutableIdentity,
    QualificationHarnessIdentity,
    QualificationOracleIdentity,
    QualificationCompilerAuthority,
    QualificationToolchainAuthority,
    QualificationRunIdentity,
    QualificationSubjectIdentity,
    QualificationTranscriptObservation,
    QualificationCleanControlObservation,
    QualificationCleanSubjectObservation,
    QualificationTeardownObservation,
    QualificationCaseIdentity,
    QualificationCaseRunIdentity,
    QualificationChangedSubjectWitness,
    QualificationChangedExecutableWitness,
    QualificationAssignedLocus,
    QualificationUnaffectedControlObservation,
    QualificationCaseObservation,
    allQualificationCaseIdentities,
    acquireQualificationAttempt,
    acquireQualifiedValidationProtocol,
    currentQualificationAttempt,
    currentQualifiedValidationProtocol,
    bindQualifiedValidationProtocolToCandidate,
    qualificationProblemCode,
    qualificationProblemSubject,
    qualificationProblemDetail,
    qualificationProblemSnapshotIdentity,
    qualificationCaseName,
    qualificationCaseExpectedFindingCode,
    qualificationAttemptRunIdentity,
    qualificationAttemptCleanSubject,
    qualificationAttemptCases,
    qualificationAttemptTeardown,
    qualificationRunSnapshotIdentity,
    qualificationRunExecutableIdentity,
    qualificationRunHarnessIdentity,
    qualificationRunOracleIdentity,
    qualificationRunCompilerAuthority,
    qualificationRunToolchainAuthority,
    qualificationRunExecutionIdentity,
    qualificationCleanSubjectRunIdentity,
    qualificationCleanSubjectIdentities,
    qualificationCleanSubjectControls,
    qualificationCleanSubjectResult,
    qualificationCleanSubjectTranscript,
    qualificationTeardownRunIdentity,
    qualificationTeardownResidueCount,
    qualificationTeardownResult,
    qualificationTeardownTranscript,
    qualificationCaseObservationRunIdentity,
    qualificationCaseObservationChangedSubject,
    qualificationCaseObservationChangedExecutable,
    qualificationCaseObservationAssignedLocus,
    qualificationCaseObservationUnaffectedControls,
    qualificationCaseObservationRefusal,
    qualificationCaseRunParent,
    qualificationCaseRunCase,
    qualificationCaseRunExecutable,
    qualificationProtocolAttempt,
    qualificationProtocolDigest
#if defined(VALIDATION_QUALIFICATION_INTERNAL_TEST_HOOKS)
    , qualificationInternalTestBinderResults
    , qualificationInternalTestVerifierResults
    , qualificationInternalTestBoundaryResults
    , qualificationInternalTestCaseContractRows
    , qualificationInternalTestCaseRows
#endif
) where

import Amoebius.Validation.CompilerSourceGraph.Internal (CompilerSourceAttempt)
import Amoebius.Validation.SourceClosure.Internal (
    AcquiredSourceSnapshot,
    SourceSnapshot (snapshotIdentity),
    acquiredSourceSnapshot,
 )
import Amoebius.Validation.Types (
    CheckResult (..),
    Finding (..),
    Observation (..),
    checkPassed,
    observation,
 )
#if defined(VALIDATION_QUALIFICATION_INTERNAL_TEST_HOOKS)
import Amoebius.Validation.Types (finding)
#endif
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Char (intToDigit, isSpace, ord)
import Data.List (group, sort)
import Data.List.NonEmpty (NonEmpty (..))
import Data.List.NonEmpty qualified as NonEmpty
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import System.FilePath (isAbsolute, splitDirectories, takeExtension)

-- The identities below are intentionally nominal rather than interchangeable
-- Text fields.  Their constructors stay in the future acquisition supervisor,
-- not in diagnostic callers or gate consumers.
newtype QualificationSourceSnapshotIdentity = QualificationSourceSnapshotIdentity Text
    deriving (Eq, Ord, Show)

data QualificationExecutableIdentity = QualificationExecutableIdentity FilePath Text
    deriving (Eq, Ord, Show)

newtype QualificationHarnessIdentity = QualificationHarnessIdentity Text
    deriving (Eq, Ord, Show)

newtype QualificationOracleIdentity = QualificationOracleIdentity Text
    deriving (Eq, Ord, Show)

-- | Authenticated compiler identity plus the supervised compiler-run identity.
data QualificationCompilerAuthority = QualificationCompilerAuthority Text Text
    deriving (Eq, Ord, Show)

-- | Authenticated toolchain-input identity plus its independent attestation.
data QualificationToolchainAuthority = QualificationToolchainAuthority Text Text
    deriving (Eq, Ord, Show)

-- | The exact common identity shared by the clean run and every sabotage run.
data QualificationRunIdentity
    = QualificationRunIdentity
        QualificationSourceSnapshotIdentity
        QualificationExecutableIdentity
        QualificationHarnessIdentity
        QualificationOracleIdentity
        QualificationCompilerAuthority
        QualificationToolchainAuthority
        Text
    deriving (Eq, Ord, Show)

-- | One production subject as it existed in the clean full-subject run.
-- The clean inventory is the authority for every sabotage preimage; a
-- changed-subject witness whose preimage is absent or different cannot be
-- joined into the attempt.
data QualificationSubjectIdentity
    = QualificationSubjectIdentity FilePath Text
    deriving (Eq, Ord, Show)

-- | Bounded process output retained by byte count and content identity.  The
-- supervisor owns the actual bytes; the verifier admits only a finite shape
-- and a lowercase SHA-256 transcript identity.
data QualificationTranscriptObservation
    = QualificationTranscriptObservation Int Text
    deriving (Eq, Ord, Show)

-- | One independently registered control as observed by the clean run.  The
-- exact sorted name inventory becomes the required inventory for every
-- sabotage invocation; a case cannot nominate its own convenient controls.
data QualificationCleanControlObservation
    = QualificationCleanControlObservation
        QualificationRunIdentity
        Text
        (NonEmpty Observation)
        [Finding]
        QualificationTranscriptObservation
    deriving (Eq, Show)

-- | The separate clean invocation over the complete unmodified subject.
-- Its subject inventory binds every mutation preimage to bytes that the same
-- qualification run restored and then observed in the final clean invocation.
data QualificationCleanSubjectObservation
    = QualificationCleanSubjectObservation
        QualificationRunIdentity
        (NonEmpty QualificationSubjectIdentity)
        (NonEmpty QualificationCleanControlObservation)
        CheckResult
        QualificationTranscriptObservation
    deriving (Eq, Show)

-- | The terminal teardown observation.  The integer is the independently
-- enumerated residue count; a verifier admits only the exact zero result and
-- a green, bounded teardown check from the same execution.
data QualificationTeardownObservation
    = QualificationTeardownObservation
        QualificationRunIdentity
        Int
        CheckResult
        QualificationTranscriptObservation
    deriving (Eq, Show)

-- | Closed, package-hidden case identities.  Constructor opacity prevents a
-- caller from substituting a display name for a case identity.
data QualificationCaseIdentity
    = QualificationConstantSuccess
    | QualificationNoOpSubject
    | QualificationWrongOutput
    | QualificationEmptyDiscovery
    | QualificationMissingSubject
    | QualificationMissingOracle
    | QualificationSkippedMutant
    | QualificationWrongLocus
    | QualificationStaleEvidence
    | QualificationSelfObserver
    | QualificationAuthorityBypass
    | QualificationResidueLeakage
    | QualificationGeneratedOrLegacyInputSmuggling
    | QualificationProductionSelectorOmission
    | QualificationOracleSelectorOmission
    | QualificationBuildSelectorOmission
    | QualificationChangedSubjectUnassignedRowRed
    deriving (Bounded, Enum, Eq, Ord, Show)

allQualificationCaseIdentities :: [QualificationCaseIdentity]
allQualificationCaseIdentities = [minBound .. maxBound]

qualificationCaseName :: QualificationCaseIdentity -> Text
qualificationCaseName identity = case identity of
    QualificationConstantSuccess -> "constant-success"
    QualificationNoOpSubject -> "no-op-subject"
    QualificationWrongOutput -> "wrong-output"
    QualificationEmptyDiscovery -> "empty-discovery"
    QualificationMissingSubject -> "missing-subject"
    QualificationMissingOracle -> "missing-oracle"
    QualificationSkippedMutant -> "skipped-or-no-op-mutant"
    QualificationWrongLocus -> "wrong-locus"
    QualificationStaleEvidence -> "stale-evidence"
    QualificationSelfObserver -> "self-observer"
    QualificationAuthorityBypass -> "authority-bypass"
    QualificationResidueLeakage -> "residue-or-teardown-leakage"
    QualificationGeneratedOrLegacyInputSmuggling -> "generated-or-legacy-input-smuggling"
    QualificationProductionSelectorOmission -> "production-selector-omission"
    QualificationOracleSelectorOmission -> "oracle-selector-omission"
    QualificationBuildSelectorOmission -> "build-selector-omission"
    QualificationChangedSubjectUnassignedRowRed -> "changed-subject-unassigned-row-red"

qualificationCaseExpectedFindingCode :: QualificationCaseIdentity -> Text
qualificationCaseExpectedFindingCode identity = case identity of
    QualificationConstantSuccess -> "SABOTAGE-CONSTANT-SUCCESS"
    QualificationNoOpSubject -> "SABOTAGE-NO-OP-SUBJECT"
    QualificationWrongOutput -> "SABOTAGE-WRONG-OUTPUT"
    QualificationEmptyDiscovery -> "SABOTAGE-EMPTY-DISCOVERY"
    QualificationMissingSubject -> "SABOTAGE-MISSING-SUBJECT"
    QualificationMissingOracle -> "SABOTAGE-MISSING-ORACLE"
    QualificationSkippedMutant -> "SABOTAGE-SKIPPED-MUTANT"
    QualificationWrongLocus -> "SABOTAGE-WRONG-LOCUS"
    QualificationStaleEvidence -> "SABOTAGE-STALE-EVIDENCE"
    QualificationSelfObserver -> "SABOTAGE-SELF-OBSERVER"
    QualificationAuthorityBypass -> "SABOTAGE-AUTHORITY-BYPASS"
    QualificationResidueLeakage -> "SABOTAGE-RESIDUE"
    QualificationGeneratedOrLegacyInputSmuggling -> "SABOTAGE-SMUGGLED-INPUT"
    QualificationProductionSelectorOmission -> "SABOTAGE-PRODUCTION-SELECTOR-OMISSION"
    QualificationOracleSelectorOmission -> "SABOTAGE-ORACLE-SELECTOR-OMISSION"
    QualificationBuildSelectorOmission -> "SABOTAGE-BUILD-SELECTOR-OMISSION"
    QualificationChangedSubjectUnassignedRowRed -> "SABOTAGE-UNASSIGNED-ROW-RED"

-- This registry is deliberately independent of the subject's produced row.
-- A sabotage that reddens a plausible but different row is not a kill.
qualificationCaseExpectedGateRow :: QualificationCaseIdentity -> Text
qualificationCaseExpectedGateRow identity = case identity of
    QualificationConstantSuccess -> "Pass criterion"
    QualificationNoOpSubject -> "Subject"
    QualificationWrongOutput -> "Oracle"
    QualificationEmptyDiscovery -> "Discovery"
    QualificationMissingSubject -> "Subject"
    QualificationMissingOracle -> "Oracle"
    QualificationSkippedMutant -> "Mutants"
    QualificationWrongLocus -> "Mutants"
    QualificationStaleEvidence -> "Freshness"
    QualificationSelfObserver -> "Observer"
    QualificationAuthorityBypass -> "Authority/bypass"
    QualificationResidueLeakage -> "Residue"
    QualificationGeneratedOrLegacyInputSmuggling -> "Cleanroom"
    QualificationProductionSelectorOmission -> "Mutants"
    QualificationOracleSelectorOmission -> "Mutants"
    QualificationBuildSelectorOmission -> "Mutants"
    QualificationChangedSubjectUnassignedRowRed -> "Mutants"

-- The changed production locus is a contract input, not a value nominated by
-- the execution attempt.  These paths are deliberately independent of the
-- witness records below; a future supervisor must apply the matching typed
-- operator to the acquired bytes at this exact locus before it can construct
-- an attempt.
qualificationCaseExpectedSubject :: QualificationCaseIdentity -> FilePath
qualificationCaseExpectedSubject identity = case identity of
    QualificationConstantSuccess -> "src/validation-kernel/Amoebius/Validation/GatePass/Internal.hs"
    QualificationNoOpSubject -> "src/validation-kernel/Amoebius/Validation/PhaseZeroRun/Internal.hs"
    QualificationWrongOutput -> "src/validation-kernel/Amoebius/Validation/Documentation/Internal.hs"
    QualificationEmptyDiscovery -> "src/validation-kernel/Amoebius/Validation/SourceClosure/Internal.hs"
    QualificationMissingSubject -> "src/validation-kernel/Amoebius/Validation/CompilerSubjectRegistry/Internal.hs"
    QualificationMissingOracle -> "src/validation-kernel/Amoebius/Validation/PhaseContract/Internal.hs"
    QualificationSkippedMutant -> "src/validation-kernel/Amoebius/Validation/MutationCoverage.hs"
    QualificationWrongLocus -> "src/validation-kernel/Amoebius/Validation/Gate/Internal.hs"
    QualificationStaleEvidence -> "src/validation-kernel/Amoebius/Validation/Evidence/Internal.hs"
    QualificationSelfObserver -> "src/validation-kernel/Amoebius/Validation/Evidence.hs"
    QualificationAuthorityBypass -> "src/validation-kernel/Amoebius/Validation/PolicyContract/Internal.hs"
    QualificationResidueLeakage -> "src/validation-kernel/Amoebius/Validation/StatusProjection/Internal.hs"
    QualificationGeneratedOrLegacyInputSmuggling -> "src/validation-kernel/Amoebius/Validation/SourceConsumerGraph/Internal.hs"
    QualificationProductionSelectorOmission -> "src/validation-kernel/Amoebius/Validation/CompilerSourceGraph/Internal.hs"
    QualificationOracleSelectorOmission -> "src/validation-kernel/Amoebius/Validation/PhaseSemanticContract.hs"
    QualificationBuildSelectorOmission -> "src/validation-kernel/Amoebius/Validation/CompilerBuildInfo/Internal.hs"
    QualificationChangedSubjectUnassignedRowRed -> "src/validation-kernel/Amoebius/Validation/Dispatch/Internal.hs"

qualificationCaseExpectedOperator :: QualificationCaseIdentity -> Text
qualificationCaseExpectedOperator identity =
    "qualification-" <> qualificationCaseName identity <> "-mutation"

qualificationCaseExpectedDetail :: QualificationCaseIdentity -> Text
qualificationCaseExpectedDetail identity =
    "the qualified harness rejected " <> qualificationCaseName identity <> " at its independently assigned locus"

-- These are the exact unrelated Phase-0 seams which must stay green in both
-- the clean run and every sabotage run.  The attempt cannot nominate a
-- smaller or different control set and compare it back to itself.
qualificationRequiredControlNames :: [Text]
qualificationRequiredControlNames =
    [ "capability-graph"
    , "compiler-source-graph"
    , "documentation"
    , "evidence"
    , "gate-pass"
    , "legacy"
    , "mutation-coverage"
    , "pb-bootstrap-grammar"
    , "phase-contract"
    , "phase-runner"
    , "phase-semantic-contract"
    , "policy-contract"
    , "source-closure"
    , "source-consumer-graph"
    , "source-debt-baseline"
    , "status-projection"
    ]

-- | A case identity is inseparable from the run identity in which it was
-- executed.  A result copied from another run therefore has a different type
-- value even if all rendered diagnostic text is identical.
data QualificationCaseRunIdentity
    = QualificationCaseRunIdentity
        QualificationRunIdentity
        QualificationCaseIdentity
        QualificationExecutableIdentity
    deriving (Eq, Ord, Show)

-- | Evidence that the supervisor changed one registered production subject.
-- The two digests bind the preimage and postimage; the final digest identifies
-- the applied mutation operator rather than a caller-provided operator name.
data QualificationChangedSubjectWitness
    = QualificationChangedSubjectWitness FilePath Text Text Text
    deriving (Eq, Ord, Show)

-- | The mutated source must be compiled into a genuinely different observed
-- executable before the sabotage result can count.  The clean preimage is
-- joined to the run executable; the postimage names the exact supervised
-- executable path and a different lowercase SHA-256 byte identity.
data QualificationChangedExecutableWitness
    = QualificationChangedExecutableWitness
        QualificationExecutableIdentity
        QualificationExecutableIdentity
    deriving (Eq, Ord, Show)

-- | The independently assigned refusal code, subject, and gate-row locus.
data QualificationAssignedLocus
    = QualificationAssignedLocus Text FilePath Text
    deriving (Eq, Ord, Show)

-- | Raw observations and findings for one same-run control, together with the
-- digest of the observed control transcript.
data QualificationUnaffectedControlObservation
    = QualificationUnaffectedControlObservation
        QualificationCaseRunIdentity
        Text
        (NonEmpty Observation)
        [Finding]
        QualificationTranscriptObservation
    deriving (Eq, Show)

-- | One executed sabotage case.  Its result cannot be separated from its
-- changed-subject witness, assigned locus, or non-empty control inventory.
data QualificationCaseObservation
    = QualificationCaseObservation
        QualificationCaseRunIdentity
        QualificationChangedSubjectWitness
        QualificationChangedExecutableWitness
        QualificationAssignedLocus
        (NonEmpty QualificationUnaffectedControlObservation)
        QualificationTranscriptObservation
        CheckResult
    deriving (Eq, Show)

-- | A statically complete corpus: each of the seventeen constructors has one
-- dedicated slot, so an attempt cannot represent a shorter caller-selected
-- list.  The future verifier must additionally check the identities inside
-- each slot before minting authority.
data QualificationCaseCorpus
    = QualificationCaseCorpus
        QualificationCaseObservation
        QualificationCaseObservation
        QualificationCaseObservation
        QualificationCaseObservation
        QualificationCaseObservation
        QualificationCaseObservation
        QualificationCaseObservation
        QualificationCaseObservation
        QualificationCaseObservation
        QualificationCaseObservation
        QualificationCaseObservation
        QualificationCaseObservation
        QualificationCaseObservation
        QualificationCaseObservation
        QualificationCaseObservation
        QualificationCaseObservation
        QualificationCaseObservation
    deriving (Eq, Show)

data QualificationAttempt
    = QualificationAttempt
        QualificationRunIdentity
        QualificationCaseCorpus
        QualificationCleanSubjectObservation
        QualificationTeardownObservation
    deriving (Eq, Show)

-- | Authority for a validation protocol qualified by an execution-derived
-- attempt.  The second value is the digest of the canonical qualification
-- transcript.  Only the private verifier constructs this value; the current
-- production acquisition path still has no successful supervisor branch.
data QualifiedValidationProtocol
    = QualifiedValidationProtocol QualificationAttempt Text
    deriving (Eq, Show)

data QualificationProblem
    = QualificationSupervisorNotExecuted Text
    | QualificationRunIdentityInvalid Text Text
    | QualificationCleanSubjectInvalid Text Text
    | QualificationCaseInvalid Text Text Text
    | QualificationTeardownInvalid Text Text
    | QualificationAttemptShapeInvalid Text Text
    | QualificationCandidateSnapshotMismatch Text
    | QualificationCandidateExecutableMismatch Text
    | QualificationProtocolDigestMalformed Text
    | QualificationProtocolDigestMismatch Text
    deriving (Eq, Ord, Show)

qualificationProblemCode :: QualificationProblem -> Text
qualificationProblemCode problem = case problem of
    QualificationSupervisorNotExecuted _ -> "QUALIFICATION-NOT-EXECUTED"
    QualificationRunIdentityInvalid _ _ -> "QUALIFICATION-RUN-IDENTITY-INVALID"
    QualificationCleanSubjectInvalid _ _ -> "QUALIFICATION-CLEAN-SUBJECT-INVALID"
    QualificationCaseInvalid _ _ _ -> "QUALIFICATION-CASE-INVALID"
    QualificationTeardownInvalid _ _ -> "QUALIFICATION-TEARDOWN-INVALID"
    QualificationAttemptShapeInvalid _ _ -> "QUALIFICATION-ATTEMPT-SHAPE-INVALID"
    QualificationCandidateSnapshotMismatch _ -> "QUALIFICATION-CANDIDATE-SNAPSHOT-MISMATCH"
    QualificationCandidateExecutableMismatch _ -> "QUALIFICATION-CANDIDATE-EXECUTABLE-MISMATCH"
    QualificationProtocolDigestMalformed _ -> "QUALIFICATION-PROTOCOL-DIGEST-MALFORMED"
    QualificationProtocolDigestMismatch _ -> "QUALIFICATION-PROTOCOL-DIGEST-MISMATCH"

qualificationProblemSubject :: QualificationProblem -> FilePath
qualificationProblemSubject problem = case problem of
    QualificationSupervisorNotExecuted _ -> "Amoebius.Validation.Gate.Internal"
    QualificationRunIdentityInvalid _ _ -> "<qualification-run-identity>"
    QualificationCleanSubjectInvalid _ _ -> "<qualification-clean-full-subject>"
    QualificationCaseInvalid _ name _ -> Text.unpack name
    QualificationTeardownInvalid _ _ -> "<qualification-teardown>"
    QualificationAttemptShapeInvalid _ _ -> "<qualification-attempt>"
    QualificationCandidateSnapshotMismatch _ -> "<qualification-candidate-source>"
    QualificationCandidateExecutableMismatch _ -> "<qualification-candidate-executable>"
    QualificationProtocolDigestMalformed _ -> "<qualified-validation-protocol>"
    QualificationProtocolDigestMismatch _ -> "<qualified-validation-protocol>"

qualificationProblemDetail :: QualificationProblem -> Text
qualificationProblemDetail problem = case problem of
    QualificationSupervisorNotExecuted _ ->
        "no qualification supervisor executed the exact clean run and closed seventeen-case sabotage corpus"
    QualificationRunIdentityInvalid _ detail -> detail
    QualificationCleanSubjectInvalid _ detail -> detail
    QualificationCaseInvalid _ name detail ->
        "qualification sabotage " <> name <> " is invalid: " <> detail
    QualificationTeardownInvalid _ detail -> detail
    QualificationAttemptShapeInvalid _ detail -> detail
    QualificationCandidateSnapshotMismatch _ ->
        "the qualified protocol and candidate name different opening source snapshots"
    QualificationCandidateExecutableMismatch _ ->
        "the qualified protocol and candidate name different executable paths or byte identities"
    QualificationProtocolDigestMalformed _ ->
        "the qualified protocol digest is not a lowercase SHA-256 identity"
    QualificationProtocolDigestMismatch _ ->
        "the qualified protocol digest does not equal the recomputed canonical transcript identity"

qualificationProblemSnapshotIdentity :: QualificationProblem -> Text
qualificationProblemSnapshotIdentity problem = case problem of
    QualificationSupervisorNotExecuted identity -> identity
    QualificationRunIdentityInvalid identity _ -> identity
    QualificationCleanSubjectInvalid identity _ -> identity
    QualificationCaseInvalid identity _ _ -> identity
    QualificationTeardownInvalid identity _ -> identity
    QualificationAttemptShapeInvalid identity _ -> identity
    QualificationCandidateSnapshotMismatch identity -> identity
    QualificationCandidateExecutableMismatch identity -> identity
    QualificationProtocolDigestMalformed identity -> identity
    QualificationProtocolDigestMismatch identity -> identity

-- These ceilings apply before a supervisor observation may enter the
-- authority graph.  They bound both list cardinality and UTF-8 payload shape;
-- a digest is not permission to retain or traverse an unbounded transcript.
maximumQualificationSubjects, maximumQualificationControls, maximumQualificationObservations, maximumQualificationFindings :: Int
maximumQualificationSubjects = 17
maximumQualificationControls = 16
maximumQualificationObservations = 512
maximumQualificationFindings = 1

maximumQualificationNameBytes, maximumQualificationPathBytes, maximumQualificationValueBytes, maximumQualificationDetailBytes :: Int
maximumQualificationNameBytes = 256
maximumQualificationPathBytes = 1024
maximumQualificationValueBytes = 4096
maximumQualificationDetailBytes = 16384

maximumQualificationTranscriptBytes :: Int
maximumQualificationTranscriptBytes = 1024 * 1024

maximumQualificationCanonicalBytes :: Int
maximumQualificationCanonicalBytes = 1024 * 1024

-- | The sole protocol-minting rule.  It is intentionally private: production
-- can reach it only through the opaque supervisor attempt returned below.
verifyQualificationAttempt :: QualificationAttempt -> Either QualificationProblem QualifiedValidationProtocol
verifyQualificationAttempt attempt@(QualificationAttempt runIdentity corpus clean teardown) =
    case qualificationAttemptStructuralProblem attempt of
        Just problem -> Left (QualificationAttemptShapeInvalid snapshot problem)
        Nothing -> case qualificationRunIdentityProblems runIdentity of
            problem : _ -> Left (QualificationRunIdentityInvalid snapshot problem)
            [] -> case qualificationCleanSubjectProblems runIdentity bindings clean of
                problem : _ -> Left (QualificationCleanSubjectInvalid snapshot problem)
                [] -> case firstQualificationCaseProblem runIdentity clean bindings of
                    Just (caseIdentity, problem) ->
                        Left (QualificationCaseInvalid snapshot (qualificationCaseName caseIdentity) problem)
                    Nothing -> case qualificationTeardownProblems runIdentity teardown of
                        problem : _ -> Left (QualificationTeardownInvalid snapshot problem)
                        []
                            | not (canonicalQualificationPayloadWithin maximumQualificationCanonicalBytes attempt) ->
                                Left
                                    ( QualificationAttemptShapeInvalid
                                        snapshot
                                        "canonical qualification transcript exceeds its fixed aggregate byte bound"
                                    )
                            | otherwise ->
                                Right (QualifiedValidationProtocol attempt (canonicalQualificationDigest attempt))
  where
    bindings = qualificationCaseCorpusBindings corpus
    snapshot = qualificationRunSnapshotText runIdentity

-- The cardinality preflight runs before any semantic fold.  Its total bounds
-- make the product of nested per-case lists finite: later UTF-8 checks can
-- never be forced to traverse billions of otherwise individually admissible
-- observations before the aggregate transcript ceiling is considered.
qualificationAttemptStructuralProblem :: QualificationAttempt -> Maybe Text
qualificationAttemptStructuralProblem attemptValue@(QualificationAttempt _ corpus clean teardown)
    | not (boundedList maximumQualificationSubjects subjectValues) =
        Just "clean subject inventory exceeds its fixed cardinality bound"
    | not (boundedList maximumQualificationControls cleanControls)
        || any (not . boundedList maximumQualificationControls) caseControls =
        Just "a clean or sabotage control inventory exceeds its fixed cardinality bound"
    | any (not . boundedList maximumQualificationObservations) observationGroups =
        Just "an observation inventory exceeds its fixed cardinality bound"
    | any (not . boundedList maximumQualificationFindings) findingGroups =
        Just "a finding inventory exceeds its exact semantic cardinality bound"
    | hasDuplicates changedPostimages =
        Just "two sabotage cases retain the same changed-subject postimage identity"
    | hasDuplicates changedOperators =
        Just "two sabotage cases retain the same mutation-operator identity"
    | hasDuplicates changedExecutablePaths =
        Just "two sabotage cases retain the same changed-executable path"
    | hasDuplicates changedExecutableDigests =
        Just "two sabotage cases retain the same changed-executable byte identity"
    | not (qualificationRawPayloadWithin maximumQualificationCanonicalBytes attemptValue) =
        Just "the qualification attempt exceeds its streaming aggregate payload bound"
    | otherwise = Nothing
  where
    bindings = qualificationCaseCorpusBindings corpus
    subjectValues = case clean of
        QualificationCleanSubjectObservation _ subjects _ _ _ -> NonEmpty.toList subjects
    cleanControls = case clean of
        QualificationCleanSubjectObservation _ _ controls _ _ -> NonEmpty.toList controls
    caseControls = map (caseObservationControls . snd) bindings
    observationGroups =
        [checkObservations (qualificationCleanSubjectResult clean)]
            <> map cleanControlObservations cleanControls
            <> concatMap caseObservationObservationGroups (map snd bindings)
            <> [checkObservations (qualificationTeardownResult teardown)]
    findingGroups =
        [checkFindings (qualificationCleanSubjectResult clean)]
            <> map cleanControlFindings cleanControls
            <> concatMap caseObservationFindingGroups (map snd bindings)
            <> [checkFindings (qualificationTeardownResult teardown)]
    changedPostimages =
        map
            (qualificationChangedSubjectAfter . qualificationCaseObservationChangedSubject . snd)
            bindings
    changedOperators =
        map
            (qualificationChangedSubjectOperator . qualificationCaseObservationChangedSubject . snd)
            bindings
    changedExecutables =
        map
            (qualificationChangedExecutableAfter . qualificationCaseObservationChangedExecutable . snd)
            bindings
    changedExecutablePaths = map qualificationExecutableIdentityPath changedExecutables
    changedExecutableDigests = map qualificationExecutableIdentityDigest changedExecutables

cleanControlObservations :: QualificationCleanControlObservation -> [Observation]
cleanControlObservations (QualificationCleanControlObservation _ _ observations _ _) = NonEmpty.toList observations

cleanControlFindings :: QualificationCleanControlObservation -> [Finding]
cleanControlFindings (QualificationCleanControlObservation _ _ _ findings _) = findings

caseObservationControls :: QualificationCaseObservation -> [QualificationUnaffectedControlObservation]
caseObservationControls (QualificationCaseObservation _ _ _ _ controls _ _) = NonEmpty.toList controls

caseObservationObservationGroups :: QualificationCaseObservation -> [[Observation]]
caseObservationObservationGroups observationValue =
    checkObservations (qualificationCaseObservationRefusal observationValue)
        : map caseControlObservations (caseObservationControls observationValue)

caseObservationFindingGroups :: QualificationCaseObservation -> [[Finding]]
caseObservationFindingGroups observationValue =
    checkFindings (qualificationCaseObservationRefusal observationValue)
        : map caseControlFindings (caseObservationControls observationValue)

caseControlObservations :: QualificationUnaffectedControlObservation -> [Observation]
caseControlObservations (QualificationUnaffectedControlObservation _ _ observations _ _) = NonEmpty.toList observations

caseControlFindings :: QualificationUnaffectedControlObservation -> [Finding]
caseControlFindings (QualificationUnaffectedControlObservation _ _ _ findings _) = findings

data QualificationPayloadChunk
    = QualificationPayloadText Text
    | QualificationPayloadPath FilePath

qualificationRawPayloadWithin :: Int -> QualificationAttempt -> Bool
qualificationRawPayloadWithin maximumBytes = consumeChunks maximumBytes . qualificationRawPayloadChunks
  where
    consumeChunks _ [] = True
    consumeChunks remaining (chunk : rest) = case consumeChunk remaining chunk of
        Nothing -> False
        Just next -> consumeChunks next rest

consumeChunk :: Int -> QualificationPayloadChunk -> Maybe Int
consumeChunk remaining chunk = case chunk of
    QualificationPayloadText value -> consumeText remaining value
    QualificationPayloadPath value -> consumeString remaining value

consumeText :: Int -> Text -> Maybe Int
consumeText remaining value = case Text.uncons value of
    Nothing -> Just remaining
    Just (character, rest) -> consumeCharacter remaining character >>= (\next -> consumeText next rest)

consumeString :: Int -> String -> Maybe Int
consumeString remaining value = case value of
    [] -> Just remaining
    character : rest -> consumeCharacter remaining character >>= (\next -> consumeString next rest)

consumeCharacter :: Int -> Char -> Maybe Int
consumeCharacter remaining character
    | width > remaining = Nothing
    | otherwise = Just (remaining - width)
  where
    width = utf8CharacterWidth character

qualificationRawPayloadChunks :: QualificationAttempt -> [QualificationPayloadChunk]
qualificationRawPayloadChunks (QualificationAttempt runIdentity corpus clean teardown) =
    qualificationRunChunks runIdentity
        <> concatMap qualificationCaseChunks (qualificationCaseCorpusBindings corpus)
        <> qualificationCleanChunks clean
        <> qualificationTeardownChunks teardown

qualificationRunChunks :: QualificationRunIdentity -> [QualificationPayloadChunk]
qualificationRunChunks
    ( QualificationRunIdentity
        (QualificationSourceSnapshotIdentity snapshot)
        (QualificationExecutableIdentity executable executableDigest)
        (QualificationHarnessIdentity harness)
        (QualificationOracleIdentity oracle)
        (QualificationCompilerAuthority compiler compilerRun)
        (QualificationToolchainAuthority toolchain toolchainAttestation)
        execution
      ) =
        [ QualificationPayloadText snapshot
        , QualificationPayloadPath executable
        , QualificationPayloadText executableDigest
        , QualificationPayloadText harness
        , QualificationPayloadText oracle
        , QualificationPayloadText compiler
        , QualificationPayloadText compilerRun
        , QualificationPayloadText toolchain
        , QualificationPayloadText toolchainAttestation
        , QualificationPayloadText execution
        ]

qualificationCleanChunks :: QualificationCleanSubjectObservation -> [QualificationPayloadChunk]
qualificationCleanChunks (QualificationCleanSubjectObservation runIdentity subjects controls result transcript) =
    qualificationRunChunks runIdentity
        <> concatMap subjectChunks (NonEmpty.toList subjects)
        <> concatMap cleanControlChunks (NonEmpty.toList controls)
        <> qualificationCheckResultChunks result
        <> qualificationTranscriptChunks transcript
  where
    subjectChunks (QualificationSubjectIdentity path digest) =
        [QualificationPayloadPath path, QualificationPayloadText digest]
    cleanControlChunks (QualificationCleanControlObservation controlRun name observations findings controlTranscript) =
        qualificationRunChunks controlRun
            <> [QualificationPayloadText name]
            <> concatMap qualificationObservationChunks (NonEmpty.toList observations)
            <> concatMap qualificationFindingChunks findings
            <> qualificationTranscriptChunks controlTranscript

qualificationCaseChunks :: (QualificationCaseIdentity, QualificationCaseObservation) -> [QualificationPayloadChunk]
qualificationCaseChunks (caseIdentity, QualificationCaseObservation caseRun changed changedExecutable assigned controls transcript result) =
    [QualificationPayloadText (qualificationCaseName caseIdentity)]
        <> qualificationCaseRunChunks caseRun
        <> qualificationChangedSubjectChunks changed
        <> qualificationChangedExecutableChunks changedExecutable
        <> qualificationAssignedChunks assigned
        <> concatMap qualificationControlChunks (NonEmpty.toList controls)
        <> qualificationTranscriptChunks transcript
        <> qualificationCheckResultChunks result

qualificationCaseRunChunks :: QualificationCaseRunIdentity -> [QualificationPayloadChunk]
qualificationCaseRunChunks (QualificationCaseRunIdentity runIdentity caseIdentity executable) =
    qualificationRunChunks runIdentity
        <> [QualificationPayloadText (qualificationCaseName caseIdentity)]
        <> qualificationExecutableChunks executable

qualificationChangedSubjectChunks :: QualificationChangedSubjectWitness -> [QualificationPayloadChunk]
qualificationChangedSubjectChunks (QualificationChangedSubjectWitness path before after operator) =
    [ QualificationPayloadPath path
    , QualificationPayloadText before
    , QualificationPayloadText after
    , QualificationPayloadText operator
    ]

qualificationChangedExecutableChunks :: QualificationChangedExecutableWitness -> [QualificationPayloadChunk]
qualificationChangedExecutableChunks (QualificationChangedExecutableWitness before after) =
    qualificationExecutableChunks before <> qualificationExecutableChunks after

qualificationExecutableChunks :: QualificationExecutableIdentity -> [QualificationPayloadChunk]
qualificationExecutableChunks (QualificationExecutableIdentity path digest) =
    [QualificationPayloadPath path, QualificationPayloadText digest]

qualificationAssignedChunks :: QualificationAssignedLocus -> [QualificationPayloadChunk]
qualificationAssignedChunks (QualificationAssignedLocus code subject row) =
    [QualificationPayloadText code, QualificationPayloadPath subject, QualificationPayloadText row]

qualificationControlChunks :: QualificationUnaffectedControlObservation -> [QualificationPayloadChunk]
qualificationControlChunks (QualificationUnaffectedControlObservation caseRun name observations findings transcript) =
    qualificationCaseRunChunks caseRun
        <> [QualificationPayloadText name]
        <> concatMap qualificationObservationChunks (NonEmpty.toList observations)
        <> concatMap qualificationFindingChunks findings
        <> qualificationTranscriptChunks transcript

qualificationTeardownChunks :: QualificationTeardownObservation -> [QualificationPayloadChunk]
qualificationTeardownChunks (QualificationTeardownObservation runIdentity _ result transcript) =
    qualificationRunChunks runIdentity
        <> qualificationCheckResultChunks result
        <> qualificationTranscriptChunks transcript

qualificationCheckResultChunks :: CheckResult -> [QualificationPayloadChunk]
qualificationCheckResultChunks result =
    QualificationPayloadText (checkName result)
        : concatMap qualificationObservationChunks (checkObservations result)
        <> concatMap qualificationFindingChunks (checkFindings result)

qualificationObservationChunks :: Observation -> [QualificationPayloadChunk]
qualificationObservationChunks item =
    [QualificationPayloadText (observationKey item), QualificationPayloadText (observationValue item)]

qualificationFindingChunks :: Finding -> [QualificationPayloadChunk]
qualificationFindingChunks item =
    [ QualificationPayloadText (findingCode item)
    , QualificationPayloadPath (findingSubject item)
    , QualificationPayloadText (findingDetail item)
    ]

qualificationTranscriptChunks :: QualificationTranscriptObservation -> [QualificationPayloadChunk]
qualificationTranscriptChunks (QualificationTranscriptObservation _ digest) = [QualificationPayloadText digest]

firstQualificationCaseProblem ::
    QualificationRunIdentity ->
    QualificationCleanSubjectObservation ->
    [(QualificationCaseIdentity, QualificationCaseObservation)] ->
    Maybe (QualificationCaseIdentity, Text)
firstQualificationCaseProblem runIdentity clean = go
  where
    go [] = Nothing
    go ((caseIdentity, caseObservation) : remaining) =
        case qualificationCaseProblems runIdentity clean caseIdentity caseObservation of
            problem : _ -> Just (caseIdentity, problem)
            [] -> go remaining

qualificationRunIdentityProblems :: QualificationRunIdentity -> [Text]
qualificationRunIdentityProblems
    ( QualificationRunIdentity
        (QualificationSourceSnapshotIdentity snapshot)
        (QualificationExecutableIdentity executable executableDigest)
        (QualificationHarnessIdentity harness)
        (QualificationOracleIdentity oracle)
        (QualificationCompilerAuthority compiler compilerRun)
        (QualificationToolchainAuthority toolchain toolchainAttestation)
        execution
      ) =
        ["source snapshot identity is not lowercase SHA-256" | not (sha256Text snapshot)]
            <> ["qualified executable path is not absolute, safe, and bounded" | not (isAbsolute executable) || not (boundedSafeText maximumQualificationPathBytes (Text.pack executable))]
            <> digestProblems
                [ ("qualified executable", executableDigest)
                , ("harness", harness)
                , ("independent oracle", oracle)
                , ("authenticated compiler", compiler)
                , ("supervised compiler run", compilerRun)
                , ("authenticated toolchain input", toolchain)
                , ("independent toolchain attestation", toolchainAttestation)
                , ("qualification execution", execution)
                ]

qualificationCleanSubjectProblems ::
    QualificationRunIdentity ->
    [(QualificationCaseIdentity, QualificationCaseObservation)] ->
    QualificationCleanSubjectObservation ->
    [Text]
qualificationCleanSubjectProblems expectedRun bindings (QualificationCleanSubjectObservation observedRun subjects controls result transcript) =
    ["clean full-subject observation names a different qualification run" | observedRun /= expectedRun]
        <> boundedSubjectProblems subjectValues
        <> ["clean subject inventory is not in canonical path order" | subjectPaths /= sort subjectPaths]
        <> ["clean subject inventory repeats a production subject" | hasDuplicates subjectPaths]
        <> ["clean subject inventory is not the exact independently registered qualification-target inventory" | subjectPaths /= expectedSubjectPaths]
        <> cleanControlProblems
        <> checkResultShapeProblems result
        <> ["clean full-subject check has the wrong exact name" | checkName result /= "qualification-clean-full-subject"]
        <> ["clean full-subject check is not green" | not (checkPassed result)]
        <> ["clean full-subject check does not retain the exact independent observation" | checkObservations result /= [observation "qualification-clean-result" "green:\x1f642"]]
        <> transcriptProblems "clean full-subject" transcript
  where
    subjectValues = NonEmpty.toList subjects
    subjectPaths = map qualificationSubjectPath subjectValues
    expectedSubjectPaths = uniqueSorted (map (qualificationCaseExpectedSubject . fst) bindings)
    controlValues = NonEmpty.toList controls
    controlNames = map qualificationCleanControlName controlValues
    cleanControlProblems
        | not (boundedList maximumQualificationControls controlValues) =
            ["clean unaffected-control inventory exceeds its fixed cardinality bound"]
        | otherwise =
            ["clean unaffected-control inventory is not in canonical name order" | controlNames /= sort controlNames]
                <> ["clean unaffected-control inventory repeats a control name" | hasDuplicates controlNames]
                <> ["clean unaffected-control inventory does not equal the closed qualification contract" | controlNames /= qualificationRequiredControlNames]
                <> concatMap (qualificationCleanControlProblems expectedRun) controlValues

boundedSubjectProblems :: [QualificationSubjectIdentity] -> [Text]
boundedSubjectProblems subjects
    | not (boundedList maximumQualificationSubjects subjects) =
        ["clean subject inventory exceeds its fixed cardinality bound"]
    | otherwise = concatMap subjectProblems subjects
  where
    subjectProblems (QualificationSubjectIdentity path digest) =
        ["clean subject path is not an authored, bounded production Haskell path" | not (qualificationProductionPath path)]
            <> ["clean subject identity is not lowercase SHA-256" | not (sha256Text digest)]

qualificationCleanControlProblems :: QualificationRunIdentity -> QualificationCleanControlObservation -> [Text]
qualificationCleanControlProblems expectedRun (QualificationCleanControlObservation observedRun name observations findings transcript) =
    ["clean unaffected control is not bound to the qualification run" | observedRun /= expectedRun]
        <> ["clean unaffected control name is empty, unsafe, or over-limit" | not (boundedSafeText maximumQualificationNameBytes name)]
        <> observationShapeProblems (NonEmpty.toList observations)
        <> findingShapeProblems findings
        <> ["clean unaffected control does not retain its exact named observation" | NonEmpty.toList observations /= [observation "qualification-control-result" name]]
        <> ["clean unaffected control is red" | not (null findings)]
        <> transcriptProblems "clean unaffected control" transcript

qualificationCaseProblems ::
    QualificationRunIdentity ->
    QualificationCleanSubjectObservation ->
    QualificationCaseIdentity ->
    QualificationCaseObservation ->
    [Text]
qualificationCaseProblems expectedRun clean expectedCase (QualificationCaseObservation observedCaseRun changed changedExecutable assigned controls transcript result) =
    caseRunProblems
        <> changedSubjectProblems
        <> changedExecutableProblems
        <> assignedLocusProblems
        <> controlProblems
        <> transcriptProblems "sabotage" transcript
        <> refusalProblems
  where
    expectedCaseRun = QualificationCaseRunIdentity expectedRun expectedCase (qualificationChangedExecutableAfter changedExecutable)
    expectedCode = qualificationCaseExpectedFindingCode expectedCase
    expectedRow = qualificationCaseExpectedGateRow expectedCase
    changedPath = qualificationChangedSubjectPath changed
    changedBefore = qualificationChangedSubjectBefore changed
    expectedExecutable = qualificationRunExecutableIdentity expectedRun
    caseRunProblems =
        ["case slot embeds a different run or case identity" | observedCaseRun /= expectedCaseRun]
    changedSubjectProblems =
        ["changed subject is not the exact independently registered production locus" | changedPath /= qualificationCaseExpectedSubject expectedCase]
            <> ["changed subject is not an authored, bounded production Haskell path" | not (qualificationProductionPath changedPath)]
            <> ["changed-subject preimage is not lowercase SHA-256" | not (sha256Text changedBefore)]
            <> ["changed-subject postimage is not lowercase SHA-256" | not (sha256Text (qualificationChangedSubjectAfter changed))]
            <> ["changed-subject preimage and postimage are identical" | changedBefore == qualificationChangedSubjectAfter changed]
            <> ["mutation operator is not the exact independently registered operator" | qualificationChangedSubjectOperator changed /= qualificationCaseExpectedOperator expectedCase]
            <> ["changed-subject preimage does not equal the clean full-subject identity" | lookupCleanSubjectIdentity changedPath clean /= Just changedBefore]
    changedExecutableProblems =
        ["changed-executable preimage is not the clean run executable" | qualificationChangedExecutableBefore changedExecutable /= expectedExecutable]
            <> ["changed-executable postimage path is not absolute, safe, and bounded" | not (qualificationExecutableIdentityPathValid (qualificationChangedExecutableAfter changedExecutable))]
            <> ["changed-executable postimage identity is not lowercase SHA-256" | not (sha256Text (qualificationExecutableIdentityDigest (qualificationChangedExecutableAfter changedExecutable)))]
            <> ["changed-executable preimage and postimage byte identities are equal" | qualificationExecutableIdentityDigest (qualificationChangedExecutableBefore changedExecutable) == qualificationExecutableIdentityDigest (qualificationChangedExecutableAfter changedExecutable)]
    assignedLocusProblems =
        ["assigned refusal code is not the exact independently registered code" | qualificationAssignedCode assigned /= expectedCode]
            <> ["assigned refusal subject is not the changed production subject" | qualificationAssignedSubject assigned /= changedPath]
            <> ["assigned gate-row locus is not the exact independently registered locus" | qualificationAssignedGateRow assigned /= expectedRow]
    controlValues = NonEmpty.toList controls
    controlNames = map qualificationControlName controlValues
    controlProblems
        | not (boundedList maximumQualificationControls controlValues) =
            ["unaffected-control inventory exceeds its fixed cardinality bound"]
        | otherwise =
            ["unaffected-control inventory is not in canonical name order" | controlNames /= sort controlNames]
                <> ["unaffected-control inventory repeats a control name" | hasDuplicates controlNames]
                <> ["unaffected-control inventory does not exactly equal the closed qualification contract" | controlNames /= qualificationRequiredControlNames]
                <> ["unaffected-control inventory does not exactly equal the clean control inventory" | controlNames /= qualificationCleanControlNames clean]
                <> concatMap (qualificationControlProblems expectedCaseRun) controlValues
    refusalProblems =
        checkResultShapeProblems result
            <> ["sabotage result has the wrong exact name" | checkName result /= "qualification-sabotage." <> qualificationCaseName expectedCase]
            <> ["sabotage result does not contain the exact independently registered observation" | checkObservations result /= [observation "qualification-refusal-locus" expectedRow]]
            <> case checkFindings result of
                [item]
                    | findingCode item == expectedCode
                        && findingSubject item == changedPath
                        && boundedSafeText maximumQualificationDetailBytes (findingDetail item)
                        && findingDetail item == qualificationCaseExpectedDetail expectedCase -> []
                _ -> ["sabotage result is not the exact one-finding refusal at the changed subject"]

qualificationControlProblems :: QualificationCaseRunIdentity -> QualificationUnaffectedControlObservation -> [Text]
qualificationControlProblems expectedCaseRun (QualificationUnaffectedControlObservation observedCaseRun name observations findings transcript) =
    ["unaffected control is not bound to the same sabotage run" | observedCaseRun /= expectedCaseRun]
        <> ["unaffected control name is empty, unsafe, or over-limit" | not (boundedSafeText maximumQualificationNameBytes name)]
        <> observationShapeProblems (NonEmpty.toList observations)
        <> findingShapeProblems findings
        <> ["unaffected control does not retain its exact named observation" | NonEmpty.toList observations /= [observation "qualification-control-result" name]]
        <> ["unaffected control is red" | not (null findings)]
        <> transcriptProblems "unaffected control" transcript

qualificationTeardownProblems :: QualificationRunIdentity -> QualificationTeardownObservation -> [Text]
qualificationTeardownProblems expectedRun (QualificationTeardownObservation observedRun residueCount result transcript) =
    ["teardown observation names a different qualification run" | observedRun /= expectedRun]
        <> ["teardown did not independently observe exactly zero residue" | residueCount /= 0]
        <> checkResultShapeProblems result
        <> ["teardown check has the wrong exact name" | checkName result /= "qualification-teardown-zero-residue"]
        <> ["teardown check is not green" | not (checkPassed result)]
        <> ["teardown check does not contain only the exact zero-residue observation" | checkObservations result /= [observation "qualification-residue-count" "0"]]
        <> transcriptProblems "teardown" transcript

transcriptProblems :: Text -> QualificationTranscriptObservation -> [Text]
transcriptProblems label (QualificationTranscriptObservation byteCount digest) =
    [label <> " transcript byte count is negative or exceeds its fixed bound" | byteCount < 0 || byteCount > maximumQualificationTranscriptBytes]
        <> [label <> " transcript identity is not lowercase SHA-256" | not (sha256Text digest)]

checkResultShapeProblems :: CheckResult -> [Text]
checkResultShapeProblems result =
    ["check-result name is empty, unsafe, or over-limit" | not (boundedSafeText maximumQualificationNameBytes (checkName result))]
        <> observationShapeProblems (checkObservations result)
        <> findingShapeProblems (checkFindings result)

observationShapeProblems :: [Observation] -> [Text]
observationShapeProblems observations
    | not (boundedList maximumQualificationObservations observations) =
        ["raw observation inventory exceeds its fixed cardinality bound"]
    | otherwise =
        [ "raw observation contains an empty, unsafe, or over-limit key/value"
        | item <- observations
        , not (boundedSafeText maximumQualificationNameBytes (observationKey item))
            || not (boundedSafeText maximumQualificationValueBytes (observationValue item))
        ]

findingShapeProblems :: [Finding] -> [Text]
findingShapeProblems findings
    | not (boundedList maximumQualificationFindings findings) =
        ["finding inventory exceeds its fixed cardinality bound"]
    | otherwise = []

digestProblems :: [(Text, Text)] -> [Text]
digestProblems values =
    [label <> " identity is not lowercase SHA-256" | (label, value) <- values, not (sha256Text value)]

boundedList :: Int -> [value] -> Bool
boundedList maximumValue values = case drop maximumValue values of
    [] -> True
    _ : _ -> False

boundedSafeText :: Int -> Text -> Bool
boundedSafeText maximumBytes value =
    utf8TextWithin maximumBytes value
        && not (Text.null value)
        && Text.any (not . isSpace) value
        && not (Text.any (`elem` ['\t', '\r', '\n', '\0']) value)

utf8TextWithin :: Int -> Text -> Bool
utf8TextWithin maximumBytes = go maximumBytes
  where
    go remaining value = case Text.uncons value of
        Nothing -> True
        Just (character, rest) ->
            let width = utf8CharacterWidth character
             in width <= remaining && go (remaining - width) rest

utf8CharacterWidth :: Char -> Int
utf8CharacterWidth character
    | codePoint <= 0x7f = 1
    | codePoint <= 0x7ff = 2
    | codePoint <= 0xffff = 3
    | otherwise = 4
  where
    codePoint = ord character

qualificationProductionPath :: FilePath -> Bool
qualificationProductionPath path =
    not (isAbsolute path)
        && '\\' `notElem` path
        && boundedSafeText maximumQualificationPathBytes (Text.pack path)
        && takeExtension path == ".hs"
        && case splitDirectories path of
            root : rest -> root `elem` ["src", "app"] && not (null rest) && all validPart rest
            [] -> False
  where
    validPart part = not (null part) && part /= "." && part /= ".."

hasDuplicates :: Ord value => [value] -> Bool
hasDuplicates = any repeated . group . sort
  where
    repeated (_ : _ : _) = True
    repeated _ = False

uniqueSorted :: Ord value => [value] -> [value]
uniqueSorted = foldr retain [] . sort
  where
    retain value [] = [value]
    retain value retained@(first : _)
        | value == first = retained
        | otherwise = value : retained

qualificationRunSnapshotText :: QualificationRunIdentity -> Text
qualificationRunSnapshotText (QualificationRunIdentity (QualificationSourceSnapshotIdentity value) _ _ _ _ _ _) = value

qualificationSubjectPath :: QualificationSubjectIdentity -> FilePath
qualificationSubjectPath (QualificationSubjectIdentity path _) = path

lookupCleanSubjectIdentity :: FilePath -> QualificationCleanSubjectObservation -> Maybe Text
lookupCleanSubjectIdentity expectedPath (QualificationCleanSubjectObservation _ subjects _ _ _) =
    case [digest | QualificationSubjectIdentity path digest <- NonEmpty.toList subjects, path == expectedPath] of
        [digest] -> Just digest
        _ -> Nothing

qualificationChangedSubjectPath :: QualificationChangedSubjectWitness -> FilePath
qualificationChangedSubjectPath (QualificationChangedSubjectWitness path _ _ _) = path

qualificationChangedSubjectBefore :: QualificationChangedSubjectWitness -> Text
qualificationChangedSubjectBefore (QualificationChangedSubjectWitness _ before _ _) = before

qualificationChangedSubjectAfter :: QualificationChangedSubjectWitness -> Text
qualificationChangedSubjectAfter (QualificationChangedSubjectWitness _ _ after _) = after

qualificationChangedSubjectOperator :: QualificationChangedSubjectWitness -> Text
qualificationChangedSubjectOperator (QualificationChangedSubjectWitness _ _ _ operator) = operator

qualificationChangedExecutableBefore :: QualificationChangedExecutableWitness -> QualificationExecutableIdentity
qualificationChangedExecutableBefore (QualificationChangedExecutableWitness before _) = before

qualificationChangedExecutableAfter :: QualificationChangedExecutableWitness -> QualificationExecutableIdentity
qualificationChangedExecutableAfter (QualificationChangedExecutableWitness _ after) = after

qualificationExecutableIdentityPathValid :: QualificationExecutableIdentity -> Bool
qualificationExecutableIdentityPathValid (QualificationExecutableIdentity path _) =
    isAbsolute path && boundedSafeText maximumQualificationPathBytes (Text.pack path)

qualificationExecutableIdentityPath :: QualificationExecutableIdentity -> FilePath
qualificationExecutableIdentityPath (QualificationExecutableIdentity path _) = path

qualificationExecutableIdentityDigest :: QualificationExecutableIdentity -> Text
qualificationExecutableIdentityDigest (QualificationExecutableIdentity _ digest) = digest

qualificationAssignedCode :: QualificationAssignedLocus -> Text
qualificationAssignedCode (QualificationAssignedLocus code _ _) = code

qualificationAssignedSubject :: QualificationAssignedLocus -> FilePath
qualificationAssignedSubject (QualificationAssignedLocus _ subject _) = subject

qualificationAssignedGateRow :: QualificationAssignedLocus -> Text
qualificationAssignedGateRow (QualificationAssignedLocus _ _ row) = row

qualificationControlName :: QualificationUnaffectedControlObservation -> Text
qualificationControlName (QualificationUnaffectedControlObservation _ name _ _ _) = name

qualificationCleanControlName :: QualificationCleanControlObservation -> Text
qualificationCleanControlName (QualificationCleanControlObservation _ name _ _ _) = name

qualificationCleanControlNames :: QualificationCleanSubjectObservation -> [Text]
qualificationCleanControlNames (QualificationCleanSubjectObservation _ _ controls _ _) =
    map qualificationCleanControlName (NonEmpty.toList controls)

canonicalQualificationDigest :: QualificationAttempt -> Text
canonicalQualificationDigest = hexText . SHA256.hash . canonicalQualificationBytes

canonicalQualificationPayloadWithin :: Int -> QualificationAttempt -> Bool
canonicalQualificationPayloadWithin maximumBytes = canonicalFieldsPayloadWithin maximumBytes . canonicalQualificationFields

canonicalFieldsPayloadWithin :: Int -> [ByteString] -> Bool
canonicalFieldsPayloadWithin maximumBytes = go 0 maximumBytes
  where
    go fieldCount remaining fields = case fields of
        [] -> encodedNaturalLength fieldCount <= remaining
        field : rest ->
            let fieldBytes = ByteString.length field
                framedBytes = encodedNaturalLength fieldBytes + fieldBytes
             in framedBytes <= remaining && go (fieldCount + 1) (remaining - framedBytes) rest

encodedNaturalLength :: Int -> Int
encodedNaturalLength value = length (show value) + 1

canonicalQualificationBytes :: QualificationAttempt -> ByteString
canonicalQualificationBytes = encodeFields . canonicalQualificationFields

canonicalQualificationFields :: QualificationAttempt -> [ByteString]
canonicalQualificationFields (QualificationAttempt runIdentity corpus clean teardown) =
    [encodeText "amoebius-qualified-validation-protocol-v1"]
        <> qualificationRunIdentityFields runIdentity
        <> [encodeText "sabotage-corpus", encodeInt (length bindings)]
        <> concatMap qualificationCaseBindingFields bindings
        <> qualificationCleanSubjectFields clean
        <> qualificationTeardownFields teardown
  where
    bindings = qualificationCaseCorpusBindings corpus

qualificationRunIdentityFields :: QualificationRunIdentity -> [ByteString]
qualificationRunIdentityFields
    ( QualificationRunIdentity
        (QualificationSourceSnapshotIdentity snapshot)
        (QualificationExecutableIdentity executable executableDigest)
        (QualificationHarnessIdentity harness)
        (QualificationOracleIdentity oracle)
        (QualificationCompilerAuthority compiler compilerRun)
        (QualificationToolchainAuthority toolchain toolchainAttestation)
        execution
      ) =
        map
            encodeText
            [ "run-identity"
            , snapshot
            , Text.pack executable
            , executableDigest
            , harness
            , oracle
            , compiler
            , compilerRun
            , toolchain
            , toolchainAttestation
            , execution
            ]

qualificationCleanSubjectFields :: QualificationCleanSubjectObservation -> [ByteString]
qualificationCleanSubjectFields (QualificationCleanSubjectObservation runIdentity subjects controls result transcript) =
    [encodeText "clean-full-subject"]
        <> qualificationRunIdentityFields runIdentity
        <> [encodeInt (length subjectValues)]
        <> concatMap qualificationSubjectFields subjectValues
        <> [encodeInt (length controlValues)]
        <> concatMap qualificationCleanControlFields controlValues
        <> qualificationCheckResultFields result
        <> qualificationTranscriptFields transcript
  where
    subjectValues = NonEmpty.toList subjects
    controlValues = NonEmpty.toList controls

qualificationCleanControlFields :: QualificationCleanControlObservation -> [ByteString]
qualificationCleanControlFields (QualificationCleanControlObservation runIdentity name observations findings transcript) =
    [encodeText "clean-unaffected-control"]
        <> qualificationRunIdentityFields runIdentity
        <> [encodeText name, encodeInt (length observationValues)]
        <> concatMap qualificationObservationFields observationValues
        <> [encodeInt (length findings)]
        <> concatMap qualificationFindingFields findings
        <> qualificationTranscriptFields transcript
  where
    observationValues = NonEmpty.toList observations

qualificationSubjectFields :: QualificationSubjectIdentity -> [ByteString]
qualificationSubjectFields (QualificationSubjectIdentity path digest) =
    map encodeText ["subject", Text.pack path, digest]

qualificationCaseBindingFields :: (QualificationCaseIdentity, QualificationCaseObservation) -> [ByteString]
qualificationCaseBindingFields (caseIdentity, QualificationCaseObservation caseRun changed changedExecutable assigned controls transcript result) =
    map encodeText ["sabotage-case", qualificationCaseName caseIdentity]
        <> qualificationCaseRunIdentityFields caseRun
        <> qualificationChangedSubjectFields changed
        <> qualificationChangedExecutableFields changedExecutable
        <> qualificationAssignedLocusFields assigned
        <> [encodeInt (length controlValues)]
        <> concatMap qualificationControlFields controlValues
        <> qualificationTranscriptFields transcript
        <> qualificationCheckResultFields result
  where
    controlValues = NonEmpty.toList controls

qualificationCaseRunIdentityFields :: QualificationCaseRunIdentity -> [ByteString]
qualificationCaseRunIdentityFields (QualificationCaseRunIdentity runIdentity caseIdentity executable) =
    [encodeText "case-run"]
        <> qualificationRunIdentityFields runIdentity
        <> [encodeText (qualificationCaseName caseIdentity)]
        <> qualificationExecutableIdentityFields executable

qualificationChangedSubjectFields :: QualificationChangedSubjectWitness -> [ByteString]
qualificationChangedSubjectFields (QualificationChangedSubjectWitness path before after operator) =
    map encodeText ["changed-subject", Text.pack path, before, after, operator]

qualificationChangedExecutableFields :: QualificationChangedExecutableWitness -> [ByteString]
qualificationChangedExecutableFields (QualificationChangedExecutableWitness before after) =
    [encodeText "changed-executable"]
        <> qualificationExecutableIdentityFields before
        <> qualificationExecutableIdentityFields after

qualificationExecutableIdentityFields :: QualificationExecutableIdentity -> [ByteString]
qualificationExecutableIdentityFields (QualificationExecutableIdentity path digest) =
    map encodeText ["executable", Text.pack path, digest]

qualificationAssignedLocusFields :: QualificationAssignedLocus -> [ByteString]
qualificationAssignedLocusFields (QualificationAssignedLocus code subject row) =
    map encodeText ["assigned-locus", code, Text.pack subject, row]

qualificationControlFields :: QualificationUnaffectedControlObservation -> [ByteString]
qualificationControlFields (QualificationUnaffectedControlObservation caseRun name observations findings transcript) =
    [encodeText "unaffected-control"]
        <> qualificationCaseRunIdentityFields caseRun
        <> [encodeText name, encodeInt (length observationValues)]
        <> concatMap qualificationObservationFields observationValues
        <> [encodeInt (length findings)]
        <> concatMap qualificationFindingFields findings
        <> qualificationTranscriptFields transcript
  where
    observationValues = NonEmpty.toList observations

qualificationTeardownFields :: QualificationTeardownObservation -> [ByteString]
qualificationTeardownFields (QualificationTeardownObservation runIdentity residueCount result transcript) =
    [encodeText "teardown-zero-residue"]
        <> qualificationRunIdentityFields runIdentity
        <> [encodeInt residueCount]
        <> qualificationCheckResultFields result
        <> qualificationTranscriptFields transcript

qualificationCheckResultFields :: CheckResult -> [ByteString]
qualificationCheckResultFields result =
    map encodeText ["check-result", checkName result]
        <> [encodeInt (length (checkObservations result))]
        <> concatMap qualificationObservationFields (checkObservations result)
        <> [encodeInt (length (checkFindings result))]
        <> concatMap qualificationFindingFields (checkFindings result)

qualificationObservationFields :: Observation -> [ByteString]
qualificationObservationFields item =
    map encodeText ["observation", observationKey item, observationValue item]

qualificationFindingFields :: Finding -> [ByteString]
qualificationFindingFields item =
    map encodeText ["finding", findingCode item, Text.pack (findingSubject item), findingDetail item]

qualificationTranscriptFields :: QualificationTranscriptObservation -> [ByteString]
qualificationTranscriptFields (QualificationTranscriptObservation byteCount digest) =
    [encodeText "transcript", encodeInt byteCount, encodeText digest]

-- A field-count prefix plus a byte-length prefix for every field makes the
-- encoding injective without relying on a delimiter that a raw observation
-- might contain.
encodeFields :: [ByteString] -> ByteString
encodeFields fields = encodeNatural (length fields) <> ByteString.concat (map encodeField fields)

encodeField :: ByteString -> ByteString
encodeField bytes = encodeNatural (ByteString.length bytes) <> bytes

encodeNatural :: Int -> ByteString
encodeNatural value = TextEncoding.encodeUtf8 (Text.pack (show value) <> ":")

encodeText :: Text -> ByteString
encodeText = TextEncoding.encodeUtf8

encodeInt :: Int -> ByteString
encodeInt = TextEncoding.encodeUtf8 . Text.pack . show

hexText :: ByteString -> Text
hexText = Text.pack . concatMap byteHex . ByteString.unpack
  where
    byteHex byte = [intToDigit (fromIntegral byte `div` 16), intToDigit (fromIntegral byte `mod` 16)]

#if defined(VALIDATION_QUALIFICATION_INTERNAL_TEST_HOOKS)
-- These hooks exist only in the focused direct-source component.  They expose
-- rendered verifier outcomes, never an attempt constructor or a protocol
-- value, and therefore cannot mint authority in the packaged library.
qualificationInternalTestVerifierResults :: [(Text, Either (Text, FilePath, Text) Text)]
qualificationInternalTestVerifierResults =
    [ ("valid", projectTestAttempt validTestAttempt)
    , ("canonical-repeat", projectTestAttempt validTestAttempt)
    ,
      ( "canonical-field-change"
      , projectTestAttempt
            (testAttemptWithCleanChange (mapTestCleanTranscript (QualificationTranscriptObservation 31 (testDigest '9'))))
      )
    ]
        <> [ ("run." <> label, projectTestAttempt (testAttemptForRun changedRun))
           | (label, changedRun) <- testInvalidRuns
           ]

        <> [ ("slot-identity." <> qualificationCaseName caseIdentity, projectTestAttempt (testAttemptWithCaseChange caseIdentity mapTestCaseSlotIdentity))
           | caseIdentity <- allQualificationCaseIdentities
           ]
        <> [ ("assigned-code." <> qualificationCaseName caseIdentity, projectTestAttempt (testAttemptWithCaseChange caseIdentity mapTestCaseAssignedCode))
           | caseIdentity <- allQualificationCaseIdentities
           ]
        <> [ ("assigned-locus." <> qualificationCaseName caseIdentity, projectTestAttempt (testAttemptWithCaseChange caseIdentity mapTestCaseAssignedLocus))
           | caseIdentity <- allQualificationCaseIdentities
           ]
        <> [ ("assigned-subject." <> qualificationCaseName caseIdentity, projectTestAttempt (testAttemptWithCaseChange caseIdentity mapTestCaseAssignedSubject))
           | caseIdentity <- allQualificationCaseIdentities
           ]
        <> [ ("operator." <> qualificationCaseName caseIdentity, projectTestAttempt (testAttemptWithCaseChange caseIdentity mapTestCaseOperator))
           | caseIdentity <- allQualificationCaseIdentities
           ]
        <> [ ("join.clean-run", projectTestAttempt (testAttemptWithCleanChange (mapTestCleanRun alternateTestRun)))
           , ("join.case-run", projectTestAttempt (testAttemptWithCaseChange QualificationConstantSuccess (mapTestCaseRun alternateTestRun)))
           , ("join.case-run-changed-executable", projectTestAttempt (testAttemptWithCaseChange QualificationConstantSuccess (mapTestCaseRunExecutable (QualificationExecutableIdentity "/tmp/other-mutant" (testDigest '3')))))
           , ("join.control-run", projectTestAttempt (testAttemptWithCaseChange QualificationConstantSuccess (mapTestCaseControlRun alternateTestRun)))
           , ("join.teardown-run", projectTestAttempt (testAttemptWithTeardownChange (mapTestTeardownRun alternateTestRun)))
           , ("clean.red", projectTestAttempt (testAttemptWithCleanChange mapTestCleanRed))
           , ("changed-subject.preimage", projectTestAttempt (testAttemptWithCaseChange QualificationConstantSuccess mapTestCasePreimage))
           , ("changed-subject.no-change", projectTestAttempt (testAttemptWithCaseChange QualificationConstantSuccess mapTestCaseNoSourceChange))
           , ("changed-executable.preimage", projectTestAttempt (testAttemptWithCaseChange QualificationConstantSuccess mapTestCaseExecutablePreimage))
           , ("changed-executable.no-change", projectTestAttempt (testAttemptWithCaseChange QualificationConstantSuccess mapTestCaseNoExecutableChange))
           , ("controls.inventory", projectTestAttempt (testAttemptWithCaseChange QualificationConstantSuccess mapTestCaseControlInventory))
           , ("controls.red", projectTestAttempt (testAttemptWithCaseChange QualificationConstantSuccess mapTestCaseControlRed))
           , ("teardown.residue", projectTestAttempt (testAttemptWithTeardownChange mapTestTeardownResidue))
           , ("teardown.red", projectTestAttempt (testAttemptWithTeardownChange mapTestTeardownRed))
           , ("bound.subjects.exact", projectTestAttempt exactSubjectBoundAttempt)
           , ("bound.subjects.plus-one", projectTestAttempt subjectBoundExceededAttempt)
           , ("bound.controls.exact", projectTestAttempt (testAttemptForControls 16))
           , ("bound.controls.plus-one", projectTestAttempt (testAttemptForControls 17))
           , ("bound.observations.plus-one", projectTestAttempt (testAttemptForCleanObservations 513))
           , ("bound.findings.exact", projectTestAttempt validTestAttempt)
           , ("bound.findings.plus-one", projectTestAttempt (testAttemptWithCaseChange QualificationConstantSuccess mapTestCaseExtraFinding))
           , ("bound.transcript-bytes.exact", projectTestAttempt (testAttemptWithCleanChange (mapTestCleanTranscript (QualificationTranscriptObservation 1048576 (testDigest '8')))))
           , ("bound.transcript-bytes.plus-one", projectTestAttempt (testAttemptWithCleanChange (mapTestCleanTranscript (QualificationTranscriptObservation 1048577 (testDigest '8')))))
           ]

qualificationInternalTestBinderResults :: [(Text, Either (Text, FilePath, Text) Text)]
qualificationInternalTestBinderResults =
    [ ("valid", projectBinding testProtocol testSnapshot testExecutablePath (Just testExecutableDigest))
    , ("snapshot", projectBinding testProtocol (testDigest 'f') testExecutablePath (Just testExecutableDigest))
    , ("executable-path", projectBinding testProtocol testSnapshot "/tmp/wrong-qualification-executable" (Just testExecutableDigest))
    , ("executable-digest-missing", projectBinding testProtocol testSnapshot testExecutablePath Nothing)
    , ("executable-digest-wrong", projectBinding testProtocol testSnapshot testExecutablePath (Just (testDigest 'f')))
    , ("protocol-digest-malformed", projectBinding malformedProtocol testSnapshot testExecutablePath (Just testExecutableDigest))
    , ("protocol-digest-mismatch", projectBinding mismatchedProtocol testSnapshot testExecutablePath (Just testExecutableDigest))
    ]
  where
    testProtocol = case verifyQualificationAttempt validTestAttempt of
        Left problem -> error ("qualification internal binder fixture could not mint its valid protocol: " <> show problem)
        Right protocol -> protocol
    malformedProtocol = QualifiedValidationProtocol validTestAttempt "not-a-digest"
    mismatchedProtocol = QualifiedValidationProtocol validTestAttempt (testDigest 'f')
    testSnapshot = testDigest 'a'
    testExecutablePath = "/tmp/amoebius-phase-zero"
    testExecutableDigest = testDigest 'b'
    projectBinding protocol snapshot path digest =
        case bindQualifiedValidationProtocolToCandidate snapshot path digest protocol of
            Left problem -> Left (qualificationProblemCode problem, qualificationProblemSubject problem, qualificationProblemDetail problem)
            Right identity -> Right identity

qualificationInternalTestBoundaryResults :: [(Text, Bool)]
qualificationInternalTestBoundaryResults =
    [ ("subjects.exact", boundedList 17 ([1 .. 17] :: [Int]))
    , ("subjects.plus-one", not (boundedList 17 ([1 .. 18] :: [Int])))
    , ("controls.exact", boundedList 16 ([1 .. 16] :: [Int]))
    , ("controls.plus-one", not (boundedList 16 ([1 .. 17] :: [Int])))
    , ("observations.exact", boundedList 512 ([1 .. 512] :: [Int]))
    , ("observations.plus-one", not (boundedList 512 ([1 .. 513] :: [Int])))
    , ("findings.exact", boundedList 1 ([1] :: [Int]))
    , ("findings.plus-one", not (boundedList 1 ([1, 2] :: [Int])))
    , ("name-bytes.exact", boundedSafeText 256 (Text.replicate 256 "n"))
    , ("name-bytes.plus-one", not (boundedSafeText 256 (Text.replicate 257 "n")))
    , ("path-bytes.exact", boundedSafeText 1024 (Text.replicate 1024 "p"))
    , ("path-bytes.plus-one", not (boundedSafeText 1024 (Text.replicate 1025 "p")))
    , ("value-bytes.exact", boundedSafeText 4096 (Text.replicate 4096 "v"))
    , ("value-bytes.plus-one", not (boundedSafeText 4096 (Text.replicate 4097 "v")))
    , ("detail-bytes.exact", boundedSafeText 16384 (Text.replicate 16384 "d"))
    , ("detail-bytes.plus-one", not (boundedSafeText 16384 (Text.replicate 16385 "d")))
    , ("transcript-bytes.exact", 1048576 <= maximumQualificationTranscriptBytes)
    , ("transcript-bytes.plus-one", not (1048577 <= maximumQualificationTranscriptBytes))
    , ("utf8.exact", utf8TextWithin 4096 (Text.replicate 1024 "\x1f642"))
    , ("utf8.plus-one", not (utf8TextWithin 4096 (Text.replicate 1024 "\x1f642" <> "a")))
    , ("canonical.exact", canonicalFieldsPayloadWithin 1048576 [ByteString.replicate exactCanonicalFieldBytes 0])
    , ("canonical.plus-one", not (canonicalFieldsPayloadWithin 1048576 [ByteString.replicate (exactCanonicalFieldBytes + 1) 0]))
    ]
  where
    -- At this ceiling the one-field payload has a two-byte outer count prefix
    -- and an eight-byte seven-digit field-length prefix.
    exactCanonicalFieldBytes = 1048566

qualificationInternalTestCaseRows :: [(Text, Text)]
qualificationInternalTestCaseRows =
    [ (qualificationCaseName caseIdentity, qualificationCaseExpectedGateRow caseIdentity)
    | caseIdentity <- allQualificationCaseIdentities
    ]

qualificationInternalTestCaseContractRows :: [(Text, FilePath, Text, Text, Text)]
qualificationInternalTestCaseContractRows =
    [ ( qualificationCaseName caseIdentity
      , qualificationCaseExpectedSubject caseIdentity
      , qualificationCaseExpectedOperator caseIdentity
      , qualificationCaseExpectedFindingCode caseIdentity
      , qualificationCaseExpectedGateRow caseIdentity
      )
    | caseIdentity <- allQualificationCaseIdentities
    ]

projectTestAttempt :: QualificationAttempt -> Either (Text, FilePath, Text) Text
projectTestAttempt attempt = case verifyQualificationAttempt attempt of
    Left problem -> Left (qualificationProblemCode problem, qualificationProblemSubject problem, qualificationProblemDetail problem)
    Right protocol -> Right (qualificationProtocolDigest protocol)

validTestAttempt :: QualificationAttempt
validTestAttempt =
    makeTestAttempt
        testRun
        qualificationCaseExpectedSubject
        qualificationRequiredControlNames
        id
        (\_ value -> value)
        id

testAttemptForRun :: QualificationRunIdentity -> QualificationAttempt
testAttemptForRun runIdentity =
    makeTestAttempt runIdentity qualificationCaseExpectedSubject qualificationRequiredControlNames id (\_ value -> value) id

testAttemptWithCleanChange :: (QualificationCleanSubjectObservation -> QualificationCleanSubjectObservation) -> QualificationAttempt
testAttemptWithCleanChange cleanChange =
    makeTestAttempt testRun qualificationCaseExpectedSubject qualificationRequiredControlNames cleanChange (\_ value -> value) id

testAttemptWithCaseChange :: QualificationCaseIdentity -> (QualificationCaseObservation -> QualificationCaseObservation) -> QualificationAttempt
testAttemptWithCaseChange target change =
    makeTestAttempt testRun qualificationCaseExpectedSubject qualificationRequiredControlNames id applyChange id
  where
    applyChange caseIdentity value
        | caseIdentity == target = change value
        | otherwise = value

testAttemptWithTeardownChange :: (QualificationTeardownObservation -> QualificationTeardownObservation) -> QualificationAttempt
testAttemptWithTeardownChange teardownChange =
    makeTestAttempt testRun qualificationCaseExpectedSubject qualificationRequiredControlNames id (\_ value -> value) teardownChange

makeTestAttempt ::
    QualificationRunIdentity ->
    (QualificationCaseIdentity -> FilePath) ->
    [Text] ->
    (QualificationCleanSubjectObservation -> QualificationCleanSubjectObservation) ->
    (QualificationCaseIdentity -> QualificationCaseObservation -> QualificationCaseObservation) ->
    (QualificationTeardownObservation -> QualificationTeardownObservation) ->
    QualificationAttempt
makeTestAttempt runIdentity subjectFor controlNames cleanChange caseChange teardownChange =
    QualificationAttempt runIdentity corpus clean teardown
  where
    corpus = testCaseCorpus (\caseIdentity -> caseChange caseIdentity (testCaseObservation runIdentity subjectFor controlNames caseIdentity))
    subjects =
        testNonEmpty
            [ QualificationSubjectIdentity path testSubjectBefore
            | path <- uniqueSorted (map subjectFor allQualificationCaseIdentities)
            ]
    clean = cleanChange (testCleanObservation runIdentity subjects controlNames)
    teardown = teardownChange (testTeardownObservation runIdentity)

testCaseCorpus :: (QualificationCaseIdentity -> QualificationCaseObservation) -> QualificationCaseCorpus
testCaseCorpus make =
    QualificationCaseCorpus
        (make QualificationConstantSuccess)
        (make QualificationNoOpSubject)
        (make QualificationWrongOutput)
        (make QualificationEmptyDiscovery)
        (make QualificationMissingSubject)
        (make QualificationMissingOracle)
        (make QualificationSkippedMutant)
        (make QualificationWrongLocus)
        (make QualificationStaleEvidence)
        (make QualificationSelfObserver)
        (make QualificationAuthorityBypass)
        (make QualificationResidueLeakage)
        (make QualificationGeneratedOrLegacyInputSmuggling)
        (make QualificationProductionSelectorOmission)
        (make QualificationOracleSelectorOmission)
        (make QualificationBuildSelectorOmission)
        (make QualificationChangedSubjectUnassignedRowRed)

testCleanObservation :: QualificationRunIdentity -> NonEmpty QualificationSubjectIdentity -> [Text] -> QualificationCleanSubjectObservation
testCleanObservation runIdentity subjects controlNames =
    QualificationCleanSubjectObservation
        runIdentity
        subjects
        (testNonEmpty (map (testCleanControl runIdentity) controlNames))
        CheckResult
            { checkName = "qualification-clean-full-subject"
            , checkObservations = [observation "qualification-clean-result" "green:\x1f642"]
            , checkFindings = []
            }
        (QualificationTranscriptObservation 30 (testDigest '8'))

testCleanControl :: QualificationRunIdentity -> Text -> QualificationCleanControlObservation
testCleanControl runIdentity name =
    QualificationCleanControlObservation
        runIdentity
        name
        (observation "qualification-control-result" name :| [])
        []
        (QualificationTranscriptObservation 20 (testDigest '7'))

testCaseObservation :: QualificationRunIdentity -> (QualificationCaseIdentity -> FilePath) -> [Text] -> QualificationCaseIdentity -> QualificationCaseObservation
testCaseObservation runIdentity subjectFor controlNames caseIdentity =
    QualificationCaseObservation
        caseRun
        ( QualificationChangedSubjectWitness
            subject
            testSubjectBefore
            (testCaseDigest 'e' caseIdentity)
            (qualificationCaseExpectedOperator caseIdentity)
        )
        ( QualificationChangedExecutableWitness
            (qualificationRunExecutableIdentity runIdentity)
            mutatedExecutable
        )
        (QualificationAssignedLocus expectedCode subject expectedRow)
        (testNonEmpty (map (testCaseControl caseRun) controlNames))
        (QualificationTranscriptObservation 40 (testDigest '6'))
        CheckResult
            { checkName = "qualification-sabotage." <> qualificationCaseName caseIdentity
            , checkObservations = [observation "qualification-refusal-locus" expectedRow]
            , checkFindings = [finding expectedCode subject (qualificationCaseExpectedDetail caseIdentity)]
            }
  where
    mutatedExecutable =
        QualificationExecutableIdentity
            ("/tmp/amoebius-qualification-" <> Text.unpack (qualificationCaseName caseIdentity))
            (testCaseDigest '0' caseIdentity)
    caseRun = QualificationCaseRunIdentity runIdentity caseIdentity mutatedExecutable
    subject = subjectFor caseIdentity
    expectedCode = qualificationCaseExpectedFindingCode caseIdentity
    expectedRow = qualificationCaseExpectedGateRow caseIdentity

testCaseControl :: QualificationCaseRunIdentity -> Text -> QualificationUnaffectedControlObservation
testCaseControl caseRun name =
    QualificationUnaffectedControlObservation
        caseRun
        name
        (observation "qualification-control-result" name :| [])
        []
        (QualificationTranscriptObservation 20 (testDigest '7'))

testTeardownObservation :: QualificationRunIdentity -> QualificationTeardownObservation
testTeardownObservation runIdentity =
    QualificationTeardownObservation
        runIdentity
        0
        CheckResult
            { checkName = "qualification-teardown-zero-residue"
            , checkObservations = [observation "qualification-residue-count" "0"]
            , checkFindings = []
            }
        (QualificationTranscriptObservation 10 (testDigest '5'))

testRun :: QualificationRunIdentity
testRun =
    QualificationRunIdentity
        (QualificationSourceSnapshotIdentity (testDigest 'a'))
        (QualificationExecutableIdentity "/tmp/amoebius-phase-zero" (testDigest 'b'))
        (QualificationHarnessIdentity (testDigest 'c'))
        (QualificationOracleIdentity (testDigest 'd'))
        (QualificationCompilerAuthority (testDigest 'e') (testDigest 'f'))
        (QualificationToolchainAuthority (testDigest '0') (testDigest '1'))
        (testDigest '2')

alternateTestRun :: QualificationRunIdentity
alternateTestRun = mapTestRunExecution (testDigest '3') testRun

testInvalidRuns :: [(Text, QualificationRunIdentity)]
testInvalidRuns =
    [ ("snapshot", mapTestRunSnapshot "invalid" testRun)
    , ("executable-path", mapTestRunExecutable (QualificationExecutableIdentity "relative" (testDigest 'b')) testRun)
    , ("executable-digest", mapTestRunExecutable (QualificationExecutableIdentity "/tmp/amoebius-phase-zero" "invalid") testRun)
    , ("harness", mapTestRunHarness "invalid" testRun)
    , ("oracle", mapTestRunOracle "invalid" testRun)
    , ("compiler", mapTestRunCompiler (QualificationCompilerAuthority "invalid" (testDigest 'f')) testRun)
    , ("compiler-run", mapTestRunCompiler (QualificationCompilerAuthority (testDigest 'e') "invalid") testRun)
    , ("toolchain", mapTestRunToolchain (QualificationToolchainAuthority "invalid" (testDigest '1')) testRun)
    , ("toolchain-attestation", mapTestRunToolchain (QualificationToolchainAuthority (testDigest '0') "invalid") testRun)
    , ("execution", mapTestRunExecution "invalid" testRun)
    ]

mapTestRunSnapshot :: Text -> QualificationRunIdentity -> QualificationRunIdentity
mapTestRunSnapshot value (QualificationRunIdentity _ executable harness oracle compiler toolchain execution) =
    QualificationRunIdentity (QualificationSourceSnapshotIdentity value) executable harness oracle compiler toolchain execution

mapTestRunExecutable :: QualificationExecutableIdentity -> QualificationRunIdentity -> QualificationRunIdentity
mapTestRunExecutable value (QualificationRunIdentity snapshot _ harness oracle compiler toolchain execution) =
    QualificationRunIdentity snapshot value harness oracle compiler toolchain execution

mapTestRunHarness :: Text -> QualificationRunIdentity -> QualificationRunIdentity
mapTestRunHarness value (QualificationRunIdentity snapshot executable _ oracle compiler toolchain execution) =
    QualificationRunIdentity snapshot executable (QualificationHarnessIdentity value) oracle compiler toolchain execution

mapTestRunOracle :: Text -> QualificationRunIdentity -> QualificationRunIdentity
mapTestRunOracle value (QualificationRunIdentity snapshot executable harness _ compiler toolchain execution) =
    QualificationRunIdentity snapshot executable harness (QualificationOracleIdentity value) compiler toolchain execution

mapTestRunCompiler :: QualificationCompilerAuthority -> QualificationRunIdentity -> QualificationRunIdentity
mapTestRunCompiler value (QualificationRunIdentity snapshot executable harness oracle _ toolchain execution) =
    QualificationRunIdentity snapshot executable harness oracle value toolchain execution

mapTestRunToolchain :: QualificationToolchainAuthority -> QualificationRunIdentity -> QualificationRunIdentity
mapTestRunToolchain value (QualificationRunIdentity snapshot executable harness oracle compiler _ execution) =
    QualificationRunIdentity snapshot executable harness oracle compiler value execution

mapTestRunExecution :: Text -> QualificationRunIdentity -> QualificationRunIdentity
mapTestRunExecution value (QualificationRunIdentity snapshot executable harness oracle compiler toolchain _) =
    QualificationRunIdentity snapshot executable harness oracle compiler toolchain value

mapTestCleanRun :: QualificationRunIdentity -> QualificationCleanSubjectObservation -> QualificationCleanSubjectObservation
mapTestCleanRun value (QualificationCleanSubjectObservation _ subjects controls result transcript) =
    QualificationCleanSubjectObservation value subjects controls result transcript

mapTestCleanTranscript :: QualificationTranscriptObservation -> QualificationCleanSubjectObservation -> QualificationCleanSubjectObservation
mapTestCleanTranscript value (QualificationCleanSubjectObservation runIdentity subjects controls result _) =
    QualificationCleanSubjectObservation runIdentity subjects controls result value

mapTestCleanRed :: QualificationCleanSubjectObservation -> QualificationCleanSubjectObservation
mapTestCleanRed (QualificationCleanSubjectObservation runIdentity subjects controls result transcript) =
    QualificationCleanSubjectObservation
        runIdentity
        subjects
        controls
        (result {checkFindings = [finding "CLEAN-RED" testSubject "clean subject unexpectedly refused"]})
        transcript

mapTestCaseSlotIdentity :: QualificationCaseObservation -> QualificationCaseObservation
mapTestCaseSlotIdentity (QualificationCaseObservation (QualificationCaseRunIdentity runIdentity caseIdentity executable) changed changedExecutable assigned controls transcript result) =
    QualificationCaseObservation
        (QualificationCaseRunIdentity runIdentity (nextQualificationCase caseIdentity) executable)
        changed
        changedExecutable
        assigned
        controls
        transcript
        result

mapTestCaseAssignedCode :: QualificationCaseObservation -> QualificationCaseObservation
mapTestCaseAssignedCode (QualificationCaseObservation caseRun changed changedExecutable (QualificationAssignedLocus _ subject row) controls transcript result) =
    QualificationCaseObservation caseRun changed changedExecutable (QualificationAssignedLocus "SABOTAGE-WRONG-CODE" subject row) controls transcript result

mapTestCaseAssignedLocus :: QualificationCaseObservation -> QualificationCaseObservation
mapTestCaseAssignedLocus (QualificationCaseObservation caseRun changed changedExecutable (QualificationAssignedLocus code subject _) controls transcript result) =
    QualificationCaseObservation caseRun changed changedExecutable (QualificationAssignedLocus code subject "Claim") controls transcript result

mapTestCaseAssignedSubject :: QualificationCaseObservation -> QualificationCaseObservation
mapTestCaseAssignedSubject (QualificationCaseObservation caseRun changed changedExecutable (QualificationAssignedLocus code _ row) controls transcript result) =
    QualificationCaseObservation caseRun changed changedExecutable (QualificationAssignedLocus code "src/WrongSubject.hs" row) controls transcript result

mapTestCaseOperator :: QualificationCaseObservation -> QualificationCaseObservation
mapTestCaseOperator (QualificationCaseObservation caseRun (QualificationChangedSubjectWitness path before after _) changedExecutable assigned controls transcript result) =
    QualificationCaseObservation
        caseRun
        (QualificationChangedSubjectWitness path before after "wrong-qualification-operator")
        changedExecutable
        assigned
        controls
        transcript
        result

mapTestCaseRun :: QualificationRunIdentity -> QualificationCaseObservation -> QualificationCaseObservation
mapTestCaseRun runIdentity (QualificationCaseObservation (QualificationCaseRunIdentity _ caseIdentity executable) changed changedExecutable assigned controls transcript result) =
    QualificationCaseObservation (QualificationCaseRunIdentity runIdentity caseIdentity executable) changed changedExecutable assigned controls transcript result

mapTestCaseRunExecutable :: QualificationExecutableIdentity -> QualificationCaseObservation -> QualificationCaseObservation
mapTestCaseRunExecutable executable (QualificationCaseObservation (QualificationCaseRunIdentity runIdentity caseIdentity _) changed changedExecutable assigned controls transcript result) =
    QualificationCaseObservation (QualificationCaseRunIdentity runIdentity caseIdentity executable) changed changedExecutable assigned controls transcript result

mapTestCaseControlRun :: QualificationRunIdentity -> QualificationCaseObservation -> QualificationCaseObservation
mapTestCaseControlRun runIdentity (QualificationCaseObservation caseRun changed changedExecutable assigned controls transcript result) =
    QualificationCaseObservation caseRun changed changedExecutable assigned changedControls transcript result
  where
    changedControls = fmap changeControl controls
    changeControl (QualificationUnaffectedControlObservation (QualificationCaseRunIdentity _ caseIdentity executable) name observations findings controlTranscript) =
        QualificationUnaffectedControlObservation (QualificationCaseRunIdentity runIdentity caseIdentity executable) name observations findings controlTranscript

mapTestCasePreimage :: QualificationCaseObservation -> QualificationCaseObservation
mapTestCasePreimage (QualificationCaseObservation caseRun (QualificationChangedSubjectWitness path _ after operator) changedExecutable assigned controls transcript result) =
    QualificationCaseObservation caseRun (QualificationChangedSubjectWitness path (testDigest '3') after operator) changedExecutable assigned controls transcript result

mapTestCaseNoSourceChange :: QualificationCaseObservation -> QualificationCaseObservation
mapTestCaseNoSourceChange (QualificationCaseObservation caseRun (QualificationChangedSubjectWitness path before _ operator) changedExecutable assigned controls transcript result) =
    QualificationCaseObservation caseRun (QualificationChangedSubjectWitness path before before operator) changedExecutable assigned controls transcript result

mapTestCaseExecutablePreimage :: QualificationCaseObservation -> QualificationCaseObservation
mapTestCaseExecutablePreimage (QualificationCaseObservation caseRun changed (QualificationChangedExecutableWitness _ after) assigned controls transcript result) =
    QualificationCaseObservation caseRun changed (QualificationChangedExecutableWitness (QualificationExecutableIdentity "/tmp/wrong-clean-executable" (testDigest '3')) after) assigned controls transcript result

mapTestCaseNoExecutableChange :: QualificationCaseObservation -> QualificationCaseObservation
mapTestCaseNoExecutableChange (QualificationCaseObservation (QualificationCaseRunIdentity runIdentity caseIdentity _) changed (QualificationChangedExecutableWitness before _) assigned controls transcript result) =
    QualificationCaseObservation changedCaseRun changed (QualificationChangedExecutableWitness before before) assigned changedControls transcript result
  where
    changedCaseRun = QualificationCaseRunIdentity runIdentity caseIdentity before
    changedControls = fmap (mapTestControlCaseRun changedCaseRun) controls

mapTestCaseControlInventory :: QualificationCaseObservation -> QualificationCaseObservation
mapTestCaseControlInventory (QualificationCaseObservation caseRun changed changedExecutable assigned controls transcript result) =
    QualificationCaseObservation caseRun changed changedExecutable assigned (fmap rename controls) transcript result
  where
    rename (QualificationUnaffectedControlObservation controlRun _ observations findings controlTranscript) =
        QualificationUnaffectedControlObservation controlRun "control-not-in-clean-run" observations findings controlTranscript

mapTestCaseControlRed :: QualificationCaseObservation -> QualificationCaseObservation
mapTestCaseControlRed (QualificationCaseObservation caseRun changed changedExecutable assigned controls transcript result) =
    QualificationCaseObservation caseRun changed changedExecutable assigned (fmap redden controls) transcript result
  where
    redden (QualificationUnaffectedControlObservation controlRun name observations _ controlTranscript) =
        QualificationUnaffectedControlObservation controlRun name observations [finding "CONTROL-RED" testSubject "unaffected control reddened"] controlTranscript

mapTestCaseExtraFinding :: QualificationCaseObservation -> QualificationCaseObservation
mapTestCaseExtraFinding (QualificationCaseObservation caseRun changed changedExecutable assigned controls transcript result) =
    QualificationCaseObservation
        caseRun
        changed
        changedExecutable
        assigned
        controls
        transcript
        (result {checkFindings = checkFindings result <> [finding "EXTRA" testSubject "extra refusal"]})

mapTestControlCaseRun :: QualificationCaseRunIdentity -> QualificationUnaffectedControlObservation -> QualificationUnaffectedControlObservation
mapTestControlCaseRun caseRun (QualificationUnaffectedControlObservation _ name observations findings transcript) =
    QualificationUnaffectedControlObservation caseRun name observations findings transcript

mapTestTeardownRun :: QualificationRunIdentity -> QualificationTeardownObservation -> QualificationTeardownObservation
mapTestTeardownRun value (QualificationTeardownObservation _ residue result transcript) =
    QualificationTeardownObservation value residue result transcript

mapTestTeardownResidue :: QualificationTeardownObservation -> QualificationTeardownObservation
mapTestTeardownResidue (QualificationTeardownObservation runIdentity _ result transcript) =
    QualificationTeardownObservation runIdentity 1 result transcript

mapTestTeardownRed :: QualificationTeardownObservation -> QualificationTeardownObservation
mapTestTeardownRed (QualificationTeardownObservation runIdentity residue result transcript) =
    QualificationTeardownObservation
        runIdentity
        residue
        (result {checkFindings = [finding "TEARDOWN-RED" "<qualification-teardown>" "teardown unexpectedly refused"]})
        transcript

nextQualificationCase :: QualificationCaseIdentity -> QualificationCaseIdentity
nextQualificationCase value
    | value == maxBound = minBound
    | otherwise = succ value

exactSubjectBoundAttempt :: QualificationAttempt
exactSubjectBoundAttempt = validTestAttempt

subjectBoundExceededAttempt :: QualificationAttempt
subjectBoundExceededAttempt = mapTestAttemptClean addSubject exactSubjectBoundAttempt
  where
    addSubject (QualificationCleanSubjectObservation runIdentity subjects controls result transcript) =
        QualificationCleanSubjectObservation
            runIdentity
            (testNonEmpty (NonEmpty.toList subjects <> [QualificationSubjectIdentity "src/qualification/Case999.hs" testSubjectBefore]))
            controls
            result
            transcript

testAttemptForControls :: Int -> QualificationAttempt
testAttemptForControls count =
    makeTestAttempt testRun qualificationCaseExpectedSubject controlNames id (\_ value -> value) id
  where
    controlNames =
        take count qualificationRequiredControlNames
            <> [testControlName ordinal | ordinal <- [length qualificationRequiredControlNames + 1 .. count]]

testAttemptForCleanObservations :: Int -> QualificationAttempt
testAttemptForCleanObservations count =
    testAttemptWithCleanChange (mapTestCleanResultObservations observations)
  where
    observations = [observation ("clean-observation-" <> testOrdinal ordinal) "green" | ordinal <- [1 .. count]]

mapTestAttemptClean :: (QualificationCleanSubjectObservation -> QualificationCleanSubjectObservation) -> QualificationAttempt -> QualificationAttempt
mapTestAttemptClean change (QualificationAttempt runIdentity corpus clean teardown) =
    QualificationAttempt runIdentity corpus (change clean) teardown

mapTestCleanResultObservations :: [Observation] -> QualificationCleanSubjectObservation -> QualificationCleanSubjectObservation
mapTestCleanResultObservations observations (QualificationCleanSubjectObservation runIdentity subjects controls result transcript) =
    QualificationCleanSubjectObservation runIdentity subjects controls (result {checkObservations = observations}) transcript

testOrdinal :: Int -> Text
testOrdinal ordinal = Text.pack (replicate (3 - length rendered) '0' <> rendered)
  where
    rendered = show ordinal

testSubject :: FilePath
testSubject = "src/validation-kernel/Amoebius/Validation/Gate.hs"

testSubjectBefore :: Text
testSubjectBefore = testDigest '4'

testDigest :: Char -> Text
testDigest character = Text.replicate 64 (Text.singleton character)

testCaseDigest :: Char -> QualificationCaseIdentity -> Text
testCaseDigest prefix caseIdentity =
    Text.replicate 62 (Text.singleton prefix)
        <> Text.pack [intToDigit (ordinal `div` 16), intToDigit (ordinal `mod` 16)]
  where
    ordinal = fromEnum caseIdentity + 1

testControlName :: Int -> Text
testControlName ordinal = "control-" <> Text.pack (replicate (3 - length rendered) '0' <> rendered)
  where
    rendered = show ordinal

testNonEmpty :: [value] -> NonEmpty value
testNonEmpty values = case values of
    first : rest -> first :| rest
    [] -> error "qualification internal fixture unexpectedly built an empty closed inventory"
#endif

-- | Production acquisition is bound to the exact opaque source/compiler
-- attempt held by Dispatch.  The current implementation has no supervisor and
-- therefore has no success branch; unlike the unbound diagnostic constants
-- below, this refusal still records which candidate snapshot was attempted.
acquireQualificationAttempt ::
    AcquiredSourceSnapshot ->
    CompilerSourceAttempt ->
    IO (Either QualificationProblem QualificationAttempt)
acquireQualificationAttempt acquired _compilerAttempt =
    pure (Left (QualificationSupervisorNotExecuted identity))
  where
    identity = snapshotIdentity (acquiredSourceSnapshot acquired)

acquireQualifiedValidationProtocol ::
    AcquiredSourceSnapshot ->
    CompilerSourceAttempt ->
    IO (Either QualificationProblem QualifiedValidationProtocol)
acquireQualifiedValidationProtocol acquired compilerAttempt = do
    attempt <- acquireQualificationAttempt acquired compilerAttempt
    pure $ case attempt of
        Left problem -> Left problem
        Right observedAttempt -> verifyQualificationAttempt observedAttempt

-- | Current production acquisition boundary.  The public diagnostic report
-- does not occur in this signature and therefore cannot be converted into an
-- attempt.
currentQualificationAttempt :: Either QualificationProblem QualificationAttempt
currentQualificationAttempt = Left (QualificationSupervisorNotExecuted "<unbound-diagnostic>")

-- | Current production authority boundary.  The verifier is present, but
-- until a supervisor executes no production path can submit an attempt to it.
currentQualifiedValidationProtocol :: Either QualificationProblem QualifiedValidationProtocol
currentQualifiedValidationProtocol = Left (QualificationSupervisorNotExecuted "<unbound-diagnostic>")

-- | Join a received protocol to the independently observed candidate source
-- and executable before its digest can populate a green Qualification row.
-- Protocol opacity alone is insufficient: authority from another run must not
-- be replayable into this candidate.
bindQualifiedValidationProtocolToCandidate ::
    Text ->
    FilePath ->
    Maybe Text ->
    QualifiedValidationProtocol ->
    Either QualificationProblem Text
bindQualifiedValidationProtocolToCandidate expectedSnapshot expectedPath expectedDigest protocol
    | actualSnapshot /= expectedSnapshot =
        Left (QualificationCandidateSnapshotMismatch expectedSnapshot)
    | Just actualDigest /= expectedDigest || actualPath /= expectedPath =
        Left (QualificationCandidateExecutableMismatch expectedSnapshot)
    | not (sha256Text digest) =
        Left (QualificationProtocolDigestMalformed expectedSnapshot)
    | digest /= canonicalQualificationDigest (qualificationProtocolAttempt protocol) =
        Left (QualificationProtocolDigestMismatch expectedSnapshot)
    | otherwise = Right digest
  where
    digest = qualificationProtocolDigest protocol
    identity = qualificationAttemptRunIdentity (qualificationProtocolAttempt protocol)
    actualSnapshot = case qualificationRunSnapshotIdentity identity of
        QualificationSourceSnapshotIdentity value -> value
    (actualPath, actualDigest) = case qualificationRunExecutableIdentity identity of
        QualificationExecutableIdentity path value -> (path, value)

sha256Text :: Text -> Bool
sha256Text value =
    Text.length value == 64
        && Text.all (\character -> (character >= '0' && character <= '9') || (character >= 'a' && character <= 'f')) value

qualificationAttemptRunIdentity :: QualificationAttempt -> QualificationRunIdentity
qualificationAttemptRunIdentity (QualificationAttempt identity _ _ _) = identity

qualificationAttemptCleanSubject :: QualificationAttempt -> QualificationCleanSubjectObservation
qualificationAttemptCleanSubject (QualificationAttempt _ _ clean _) = clean

qualificationAttemptCases :: QualificationAttempt -> [(QualificationCaseIdentity, QualificationCaseObservation)]
qualificationAttemptCases (QualificationAttempt _ corpus _ _) = qualificationCaseCorpusBindings corpus

qualificationAttemptTeardown :: QualificationAttempt -> QualificationTeardownObservation
qualificationAttemptTeardown (QualificationAttempt _ _ _ teardown) = teardown

qualificationCaseCorpusBindings :: QualificationCaseCorpus -> [(QualificationCaseIdentity, QualificationCaseObservation)]
qualificationCaseCorpusBindings
    ( QualificationCaseCorpus
        constantSuccess
        noOpSubject
        wrongOutput
        emptyDiscovery
        missingSubject
        missingOracle
        skippedMutant
        wrongLocus
        staleEvidence
        selfObserver
        authorityBypass
        residueLeakage
        inputSmuggling
        productionSelectorOmission
        oracleSelectorOmission
        buildSelectorOmission
        unassignedRowRed
      ) =
        [ (QualificationConstantSuccess, constantSuccess)
        , (QualificationNoOpSubject, noOpSubject)
        , (QualificationWrongOutput, wrongOutput)
        , (QualificationEmptyDiscovery, emptyDiscovery)
        , (QualificationMissingSubject, missingSubject)
        , (QualificationMissingOracle, missingOracle)
        , (QualificationSkippedMutant, skippedMutant)
        , (QualificationWrongLocus, wrongLocus)
        , (QualificationStaleEvidence, staleEvidence)
        , (QualificationSelfObserver, selfObserver)
        , (QualificationAuthorityBypass, authorityBypass)
        , (QualificationResidueLeakage, residueLeakage)
        , (QualificationGeneratedOrLegacyInputSmuggling, inputSmuggling)
        , (QualificationProductionSelectorOmission, productionSelectorOmission)
        , (QualificationOracleSelectorOmission, oracleSelectorOmission)
        , (QualificationBuildSelectorOmission, buildSelectorOmission)
        , (QualificationChangedSubjectUnassignedRowRed, unassignedRowRed)
        ]

qualificationRunSnapshotIdentity :: QualificationRunIdentity -> QualificationSourceSnapshotIdentity
qualificationRunSnapshotIdentity (QualificationRunIdentity value _ _ _ _ _ _) = value

qualificationRunExecutableIdentity :: QualificationRunIdentity -> QualificationExecutableIdentity
qualificationRunExecutableIdentity (QualificationRunIdentity _ value _ _ _ _ _) = value

qualificationRunHarnessIdentity :: QualificationRunIdentity -> QualificationHarnessIdentity
qualificationRunHarnessIdentity (QualificationRunIdentity _ _ value _ _ _ _) = value

qualificationRunOracleIdentity :: QualificationRunIdentity -> QualificationOracleIdentity
qualificationRunOracleIdentity (QualificationRunIdentity _ _ _ value _ _ _) = value

qualificationRunCompilerAuthority :: QualificationRunIdentity -> QualificationCompilerAuthority
qualificationRunCompilerAuthority (QualificationRunIdentity _ _ _ _ value _ _) = value

qualificationRunToolchainAuthority :: QualificationRunIdentity -> QualificationToolchainAuthority
qualificationRunToolchainAuthority (QualificationRunIdentity _ _ _ _ _ value _) = value

qualificationRunExecutionIdentity :: QualificationRunIdentity -> Text
qualificationRunExecutionIdentity (QualificationRunIdentity _ _ _ _ _ _ value) = value

qualificationCleanSubjectRunIdentity :: QualificationCleanSubjectObservation -> QualificationRunIdentity
qualificationCleanSubjectRunIdentity (QualificationCleanSubjectObservation value _ _ _ _) = value

qualificationCleanSubjectIdentities :: QualificationCleanSubjectObservation -> NonEmpty QualificationSubjectIdentity
qualificationCleanSubjectIdentities (QualificationCleanSubjectObservation _ value _ _ _) = value

qualificationCleanSubjectControls :: QualificationCleanSubjectObservation -> NonEmpty QualificationCleanControlObservation
qualificationCleanSubjectControls (QualificationCleanSubjectObservation _ _ value _ _) = value

qualificationCleanSubjectResult :: QualificationCleanSubjectObservation -> CheckResult
qualificationCleanSubjectResult (QualificationCleanSubjectObservation _ _ _ value _) = value

qualificationCleanSubjectTranscript :: QualificationCleanSubjectObservation -> QualificationTranscriptObservation
qualificationCleanSubjectTranscript (QualificationCleanSubjectObservation _ _ _ _ value) = value

qualificationTeardownRunIdentity :: QualificationTeardownObservation -> QualificationRunIdentity
qualificationTeardownRunIdentity (QualificationTeardownObservation value _ _ _) = value

qualificationTeardownResidueCount :: QualificationTeardownObservation -> Int
qualificationTeardownResidueCount (QualificationTeardownObservation _ value _ _) = value

qualificationTeardownResult :: QualificationTeardownObservation -> CheckResult
qualificationTeardownResult (QualificationTeardownObservation _ _ value _) = value

qualificationTeardownTranscript :: QualificationTeardownObservation -> QualificationTranscriptObservation
qualificationTeardownTranscript (QualificationTeardownObservation _ _ _ value) = value

qualificationCaseObservationRunIdentity :: QualificationCaseObservation -> QualificationCaseRunIdentity
qualificationCaseObservationRunIdentity (QualificationCaseObservation value _ _ _ _ _ _) = value

qualificationCaseObservationChangedSubject :: QualificationCaseObservation -> QualificationChangedSubjectWitness
qualificationCaseObservationChangedSubject (QualificationCaseObservation _ value _ _ _ _ _) = value

qualificationCaseObservationChangedExecutable :: QualificationCaseObservation -> QualificationChangedExecutableWitness
qualificationCaseObservationChangedExecutable (QualificationCaseObservation _ _ value _ _ _ _) = value

qualificationCaseObservationAssignedLocus :: QualificationCaseObservation -> QualificationAssignedLocus
qualificationCaseObservationAssignedLocus (QualificationCaseObservation _ _ _ value _ _ _) = value

qualificationCaseObservationUnaffectedControls :: QualificationCaseObservation -> NonEmpty QualificationUnaffectedControlObservation
qualificationCaseObservationUnaffectedControls (QualificationCaseObservation _ _ _ _ value _ _) = value

qualificationCaseObservationRefusal :: QualificationCaseObservation -> CheckResult
qualificationCaseObservationRefusal (QualificationCaseObservation _ _ _ _ _ _ value) = value

qualificationCaseRunParent :: QualificationCaseRunIdentity -> QualificationRunIdentity
qualificationCaseRunParent (QualificationCaseRunIdentity value _ _) = value

qualificationCaseRunCase :: QualificationCaseRunIdentity -> QualificationCaseIdentity
qualificationCaseRunCase (QualificationCaseRunIdentity _ value _) = value

qualificationCaseRunExecutable :: QualificationCaseRunIdentity -> QualificationExecutableIdentity
qualificationCaseRunExecutable (QualificationCaseRunIdentity _ _ value) = value

qualificationProtocolAttempt :: QualifiedValidationProtocol -> QualificationAttempt
qualificationProtocolAttempt (QualifiedValidationProtocol value _) = value

qualificationProtocolDigest :: QualifiedValidationProtocol -> Text
qualificationProtocolDigest (QualifiedValidationProtocol _ value) = value
