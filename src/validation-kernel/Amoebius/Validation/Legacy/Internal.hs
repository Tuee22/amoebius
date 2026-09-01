{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.Legacy.Internal
  ( ActiveRegister
  , GatePrerequisiteObservation
  , GateCompletionPremises
  , LegacyAnalyzer (..)
  , LegacyClosure
  , LegacyClosureRule (..)
  , LegacyDisposition (..)
  , LegacyId (..)
  , LegacyObservation (..)
  , LegacyObservationRule (..)
  , LegacyObservedState (..)
  , LegacyReintroductionCase (..)
  , RegisterProblem (..)
  , activeRegisterFromSnapshot
  , activeRegisterPath
  , acceptedLegacyIdEncodings
  , allLegacyIds
  , assembleGateCompletionPremises
  , gatePrerequisitePassed
  , gatePrerequisiteRefused
  , gatePrerequisiteUnverified
  , legacyCheck
  , legacyCheckAcquired
  , legacyClosureAcquired
  , legacyClosureResult
  , legacyInventoryDiagnostic
  , legacyRawDiagnosticBindings
  , legacyRawDiagnosticJoins
  , legacyInternalDiagnosticProjection
  , evaluateLegacyObservationDiagnostic
  , legacyIdAnalyzer
  , legacyIdClosureRule
  , legacyIdDisposition
  , legacyIdObservationRule
  , legacyIdOwner
  , legacyIdOwnerCapability
  , legacyIdReintroductionCases
  , parseActiveRegister
  , parseLegacyId
  , renderLegacyId
  , renderRegisterProblem
  , sourceDebtLegacyId
  ) where

import Amoebius.Validation.PhaseIdentity qualified as PhaseIdentity
import Amoebius.Validation.PolicyContract.Internal qualified as Policy
import Amoebius.Validation.CompilerSourceGraph.Internal
  ( CompilerSourceAttempt
  , acquiredCompilerSnapshotIdentity
  , compilerSourceAttemptCheck
  , compilerSourceAttemptDiagnostic
  )
import Amoebius.Validation.PhaseContract.Evidence.Internal
  ( AcquiredPhaseContractEvidence
  , acquiredPhaseContractEvidenceCheck
  , acquiredPhaseContractEvidenceSnapshot
  )
import Amoebius.Validation.SourceClosure.Internal
  ( AcquiredSourceSnapshot
  , IndexEntry (..)
  , IndexMode (..)
  , SourceDebtId (..)
  , SourceSnapshot (..)
  , TrackedEntry (..)
  , acquiredSourceSnapshot
  , sourceClosureCheckAcquired
  )
import Amoebius.Validation.SourceDebtBaseline.Internal
  ( SourceDebtEvidence
  , foldAcquiredSourceDebtState
  , sourceDebtEvidenceCheck
  )
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding
  , Observation
  , checkFindings
  , checkObservations
  , finding
  , findingCode
  , findingDetail
  , findingSubject
  , observation
  , observationKey
  , observationValue
  )
import Crypto.Hash qualified as Crypto
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Char (ord)
import Data.List (isPrefixOf, nub, sortOn)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import System.FilePath (takeFileName)

-- | The permanent executable identity universe. A future qualified retirement
-- changes lifecycle state; it never removes the constructor or its
-- reintroduction case. Sprint 0.2 represents only the current Active state.
data LegacyId
  = LtdSrc000
  | LtdSrc001
  | LtdSrc002
  | LtdSrc003
  | LtdSrc004
  | LtdSrc005
  | LtdSrc006
  | LtdSrc007
  | LtdSrc008
  | LtdSrc009
  | LtdMeta001
  | LtdVal001
  | LtdVal002
  | LtdVal003
  | LtdVal004
  | LtdVal005
  | LtdVal006
  | LtdDoc001
  | LtdName001
  | LtdHost001
  | LtdHost002
  | LtdImg001
  | LtdRun001
  | LtdSeed001
  | LtdSeed002
  | LtdBoot001
  deriving (Bounded, Enum, Eq, Ord, Show)

data LegacyDisposition
  = LegacyActive
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | A key names the owner-domain observer which must supply raw evidence. A
-- key is not evidence that the observer exists or that its closure is true.
data LegacyAnalyzer
  = AnalyzeCompleteSourceGrammar
  | AnalyzeSourceTools
  | AnalyzeSourceDhall
  | AnalyzeSourceProto
  | AnalyzeSourceUi
  | AnalyzeSourcePulumi
  | AnalyzeSourceTest
  | AnalyzeSourceProbe
  | AnalyzeSourcePb
  | AnalyzeSourceVendor
  | AnalyzeRetiredIgnoreRules
  | AnalyzeValidationProtocol
  | AnalyzePhaseContracts
  | AnalyzeStatusEvidence
  | AnalyzeGateCompletion
  | AnalyzeHardwareFreeDsl
  | AnalyzeRunInputClosure
  | AnalyzeBehavioralDocumentConsumers
  | AnalyzePhaseOrdinalNames
  | AnalyzeHostEnsure
  | AnalyzeAmbientHostPaths
  | AnalyzeNaturalArchitectureImages
  | AnalyzeExecutableIdentity
  | AnalyzeInfernixSeedDependency
  | AnalyzeJitMlSeedDependency
  | AnalyzeBootstrapToolchain
  deriving (Bounded, Enum, Eq, Ord, Show)

data LegacyObservationRule
  = ObserveCompleteSourceSnapshot
  | ObserveSourceTools
  | ObserveSourceDhall
  | ObserveSourceProto
  | ObserveSourceUi
  | ObserveSourcePulumi
  | ObserveSourceTest
  | ObserveSourceProbe
  | ObserveSourcePb
  | ObserveSourceVendor
  | ObserveParsedIgnoreGrammars
  | ObserveValidationGateGraph
  | ObserveTypedPhaseContractBinding
  | ObserveStatusEvidenceProjection
  | ObserveGateCompletionResult
  | ObserveHardwareFreeDslTrace
  | ObserveRunInputProvenance
  | ObserveDocumentConsumerGraph
  | ObserveRuntimeIdentityGraph
  | ObserveHostEnsureCallGraph
  | ObserveHostPathEffectGraph
  | ObserveImagePlanAndBinfmt
  | ObserveCabalExecutableGraph
  | ObserveInfernixDependencyGraph
  | ObserveJitMlDependencyGraph
  | ObserveBootstrapToolchainProvenance
  deriving (Bounded, Enum, Eq, Ord, Show)

data LegacyClosureRule
  = CloseCompleteSourceGrammar
  | CloseSourceTools
  | CloseSourceDhall
  | CloseSourceProto
  | CloseSourceUi
  | CloseSourcePulumi
  | CloseSourceTest
  | CloseSourceProbe
  | CloseSourcePb
  | CloseSourceVendor
  | CloseRetiredIgnoreRules
  | CloseValidationProtocol
  | ClosePhaseContracts
  | CloseStatusEvidence
  | CloseGateCompletion
  | CloseHardwareFreeDsl
  | CloseRunInputClosure
  | CloseBehavioralDocumentConsumers
  | ClosePhaseOrdinalNames
  | CloseHostEnsure
  | CloseAmbientHostPaths
  | CloseNaturalArchitectureImages
  | CloseExecutableIdentity
  | CloseInfernixSeedDependency
  | CloseJitMlSeedDependency
  | CloseBootstrapToolchain
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | These are stable, typed case identities. The owning analyzer must later
-- implement the named negative; declaring a case here does not execute it.
data LegacyReintroductionCase
  = RejectDisguisedOrConcealedSource
  | RejectTrackedToolsSource
  | RejectTrackedDhallOrTsv
  | RejectTrackedProto
  | RejectTrackedUiSource
  | RejectTrackedPulumiSource
  | RejectTrackedBehavioralTestInput
  | RejectTrackedProbeDebt
  | RejectWidenedPbBehavior
  | RejectTopLevelVendorDebt
  | RejectRetiredIgnoreRule
  | RejectNonHaskellValidationVerdict
  | RejectUnboundPhaseContract
  | RejectForgedStatusEvidence
  | RejectIncompleteGate
  | RejectHardwareBeforeDslGatePass
  | RejectAmbientOrStaleRunInput
  | RejectBehavioralMarkdownConsumer
  | RejectRuntimePhaseOrdinal
  | RejectBypassedHostEnsure
  | RejectAmbientHostPath
  | RejectCrossArchitectureImagePlan
  | RejectSecondExecutableIdentity
  | RejectInfernixSeedDependency
  | RejectJitMlSeedDependency
  | RejectUnverifiedBootstrapToolchain
  deriving (Bounded, Enum, Eq, Ord, Show)

data BindingSlot value
  = BindingMissing
  | BindingPresent value
  deriving (Eq, Ord, Show)

-- | The slots make deliberately malformed changed-production subjects
-- representable. The canonical build fills every slot; integrity diagnostics
-- distinguish a missing owner, analyzer, observation, closure, or negative.
data LegacyBinding = LegacyBinding
  { legacyBindingId :: LegacyId
  , legacyBindingDisposition :: LegacyDisposition
  , legacyBindingOwner :: BindingSlot Policy.PhaseOrdinal
  , legacyBindingAnalyzer :: BindingSlot LegacyAnalyzer
  , legacyBindingObservation :: BindingSlot LegacyObservationRule
  , legacyBindingClosure :: BindingSlot LegacyClosureRule
  , legacyBindingReintroduction :: BindingSlot (NonEmpty LegacyReintroductionCase)
  }
  deriving (Eq, Ord, Show)

data LegacyObservedState
  = LegacyObservedZero
  | LegacyObservedOpen Int Text
  | LegacyObservationRefused Text
  deriving (Eq, Ord, Show)

-- | One outcome captured from a required gate row before legacy closure is
-- evaluated.  The constructor is deliberately private: the evidence
-- finalizer can name an observed row through the three functions below, but
-- neither a public caller nor a @CheckResult@ can manufacture the assembled
-- gate-completion premise.
data GatePrerequisiteObservation = GatePrerequisiteObservation
  { gatePrerequisiteName :: Text
  , gatePrerequisiteOutcome :: GatePrerequisiteOutcome
  }
  deriving (Eq, Ord, Show)

data GatePrerequisiteOutcome
  = GatePrerequisitePassed
  | GatePrerequisiteRefused
  | GatePrerequisiteUnverified
  deriving (Eq, Ord, Show)

-- | The exact non-circular inputs to @LTD-VAL-004@.  @Legacy closure@ is not
-- one of its own premises and @Pass criterion@ is derived only afterwards.
-- The constructor remains package-private and is not exported even from this
-- internal module.
newtype GateCompletionPremises = GateCompletionPremises [GatePrerequisiteObservation]
  deriving (Eq, Ord, Show)

-- | A legacy-closure row can only be obtained by running the acquired legacy
-- inventory against an exact gate-completion premise.  Its constructor is
-- hidden so a caller-supplied @CheckResult@ cannot impersonate the row.
newtype LegacyClosure = LegacyClosure CheckResult
  deriving (Eq, Show)

gatePrerequisitePassed :: Text -> GatePrerequisiteObservation
gatePrerequisitePassed name = GatePrerequisiteObservation name GatePrerequisitePassed

gatePrerequisiteRefused :: Text -> GatePrerequisiteObservation
gatePrerequisiteRefused name = GatePrerequisiteObservation name GatePrerequisiteRefused

gatePrerequisiteUnverified :: Text -> GatePrerequisiteObservation
gatePrerequisiteUnverified name = GatePrerequisiteObservation name GatePrerequisiteUnverified

-- | Seal the observed prerequisite inventory.  Exact order and cardinality
-- are checked again when @LTD-VAL-004@ is evaluated, so a missing, duplicate,
-- reordered, or unexpected row becomes a refusal rather than a smaller gate.
assembleGateCompletionPremises :: [GatePrerequisiteObservation] -> GateCompletionPremises
assembleGateCompletionPremises = GateCompletionPremises

-- | An owner-domain observation carries the analyzer identity that produced
-- it. This value is input, not authority: the evaluator rejects a key that
-- differs from the canonical binding. An Active zero is admissible only at
-- the owning phase, where it is candidate readiness rather than retirement;
-- gate completion must precede the compiled Retired transition used by a
-- later phase.
data LegacyObservation = LegacyObservation
  { legacyObservationAnalyzer :: LegacyAnalyzer
  , legacyObservationState :: LegacyObservedState
  }
  deriving (Eq, Ord, Show)

-- | Candidate evidence is deliberately opaque outside this module.  Its
-- constructor binds an observation (or an explicit unavailable state) to the
-- exact legacy row, canonical analyzer, and immutable source snapshot which
-- the closed dispatcher actually examined.  Diagnostic callers can construct
-- 'LegacyObservation'; they cannot construct or inject this value.
data ClosedLegacyEvidence = ClosedLegacyEvidence
  { closedEvidenceId :: LegacyId
  , closedEvidenceSourceDebtId :: Maybe SourceDebtId
  , closedEvidenceAnalyzer :: LegacyAnalyzer
  , closedEvidenceSnapshot :: Text
  , closedEvidenceObservation :: Maybe LegacyObservation
  , closedEvidenceReintroduction :: Maybe LegacyReintroductionWitness
  }
  deriving (Eq, Ord, Show)

-- | Execution evidence for the immutable negative(s) attached to one legacy
-- row.  Declaring a 'LegacyReintroductionCase' in the binding registry is not
-- evidence that it ran.  The hidden witness binds the exact row, source
-- snapshot, complete canonical case set, and qualifying transcript identity.
-- No producer exists until the qualification supervisor executes those
-- owner-domain negatives, so an owner-phase zero currently remains red.
data LegacyReintroductionWitness = LegacyReintroductionWitness
  { legacyReintroductionWitnessId :: LegacyId
  , legacyReintroductionWitnessSnapshot :: Text
  , legacyReintroductionWitnessCases :: NonEmpty LegacyReintroductionCase
  , legacyReintroductionWitnessTranscript :: Text
  }
  deriving (Eq, Ord, Show)

data ActiveRegister = ActiveRegister
  { activeRegisterPath :: FilePath
  }
  deriving (Eq, Show)

data RegisterProblem
  = RegisterEntryLimit Int Int
  | RegisterPathByteLimit Int Int Int
  | RegisterByteLimit Int Int
  | RegisterResourceGuardUnavailable Text
  | ActiveRegisterMissing FilePath
  | MultipleActiveRegisters FilePath Int
  | AdditionalActiveRegisterTracked FilePath
  | ArchiveRegisterTracked FilePath
  | RegisterNotRegularFile FilePath IndexMode
  | RegisterNotUtf8 FilePath
  deriving (Eq, Ord, Show)

maximumLegacyTrackedEntries, maximumLegacyTrackedPathBytes, maximumLegacyRegisterBytes :: Int
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_ENTRY_LIMIT_LITERAL_MUTANT)
maximumLegacyTrackedEntries = 16383
#else
maximumLegacyTrackedEntries = 16384
#endif
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_PATH_LIMIT_LITERAL_MUTANT)
maximumLegacyTrackedPathBytes = 1023
#else
maximumLegacyTrackedPathBytes = 1024
#endif
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_BYTE_LIMIT_LITERAL_MUTANT)
maximumLegacyRegisterBytes = 1048575
#else
maximumLegacyRegisterBytes = 1048576
#endif

data LegacyBoundedPrefix value
  = LegacyBoundedWithin [value]
  | LegacyBoundedExceeded Int [value]

canonicalRegisterPath :: FilePath
#if defined(VALIDATION_LEGACY_INTERNAL_CANONICAL_REGISTER_PATH_ROUTE_MUTANT)
canonicalRegisterPath =
  Policy.canonicalActiveRegisterPath Policy.canonicalPolicyContract <> ".mutated"
#else
canonicalRegisterPath = Policy.canonicalActiveRegisterPath Policy.canonicalPolicyContract
#endif

archiveRegisterName :: FilePath
#if defined(VALIDATION_LEGACY_INTERNAL_ARCHIVE_REGISTER_NAME_ROUTE_MUTANT)
archiveRegisterName =
  takeFileName (Policy.canonicalForbiddenArchivePath Policy.canonicalPolicyContract) <> ".mutated"
#else
archiveRegisterName =
  takeFileName (Policy.canonicalForbiddenArchivePath Policy.canonicalPolicyContract)
#endif

-- | The canonical universe is literal and closed. The conditional omission is
-- reachable only in the named changed-production build.
allLegacyIds :: [LegacyId]
allLegacyIds =
#if defined(VALIDATION_LEGACY_INTERNAL_ALL_IDS_ROUTE_DROP_MUTANT)
  drop 1 canonicalLegacyUniverse
#elif defined(VALIDATION_LEGACY_INTERNAL_ALL_IDS_ROUTE_ORDER_MUTANT)
  reverse canonicalLegacyUniverse
#else
  canonicalLegacyUniverse
#endif

canonicalLegacyUniverse :: [LegacyId]
#if defined(VALIDATION_LEGACY_INTERNAL_CANONICAL_UNIVERSE_COMPOSITION_MUTANT)
canonicalLegacyUniverse =
  drop 1
    (canonicalLegacyUniverseOrder
      (filter canonicalLegacyIdRetained [minBound .. maxBound]))
#else
canonicalLegacyUniverse =
  canonicalLegacyUniverseOrder
    (filter canonicalLegacyIdRetained [minBound .. maxBound])
#endif

canonicalLegacyUniverseOrder :: [LegacyId] -> [LegacyId]
#if defined(VALIDATION_LEGACY_INTERNAL_UNIVERSE_ORDER_MUTANT)
canonicalLegacyUniverseOrder = reverse
#else
canonicalLegacyUniverseOrder = id
#endif

canonicalLegacyIdRetained :: LegacyId -> Bool
canonicalLegacyIdRetained identifier = case identifier of
  LtdSrc000 ->
#if defined(VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_SRC000_DROP_MUTANT)
    False
#else
    True
#endif
  LtdSrc001 ->
#if defined(VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_SRC001_DROP_MUTANT)
    False
#else
    True
#endif
  LtdSrc002 ->
#if defined(VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_SRC002_DROP_MUTANT)
    False
#else
    True
#endif
  LtdSrc003 ->
#if defined(VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_SRC003_DROP_MUTANT)
    False
#else
    True
#endif
  LtdSrc004 ->
#if defined(VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_SRC004_DROP_MUTANT)
    False
#else
    True
#endif
  LtdSrc005 ->
#if defined(VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_SRC005_DROP_MUTANT)
    False
#else
    True
#endif
  LtdSrc006 ->
#if defined(VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_SRC006_DROP_MUTANT)
    False
#else
    True
#endif
  LtdSrc007 ->
#if defined(VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_SRC007_DROP_MUTANT)
    False
#else
    True
#endif
  LtdSrc008 ->
#if defined(VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_SRC008_DROP_MUTANT)
    False
#else
    True
#endif
  LtdSrc009 ->
#if defined(VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_SRC009_DROP_MUTANT)
    False
#else
    True
#endif
  LtdMeta001 ->
#if defined(VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_META001_DROP_MUTANT)
    False
#else
    True
#endif
  LtdVal001 ->
#if defined(VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_VAL001_DROP_MUTANT)
    False
#else
    True
#endif
  LtdVal002 ->
#if defined(VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_VAL002_DROP_MUTANT)
    False
#else
    True
#endif
  LtdVal003 ->
#if defined(VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_VAL003_DROP_MUTANT)
    False
#else
    True
#endif
  LtdVal004 ->
#if defined(VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_VAL004_DROP_MUTANT)
    False
#else
    True
#endif
  LtdVal005 ->
#if defined(VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_VAL005_DROP_MUTANT)
    False
#else
    True
#endif
  LtdVal006 ->
#if defined(VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_VAL006_DROP_MUTANT)
    False
#else
    True
#endif
  LtdDoc001 ->
#if defined(VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_DOC001_DROP_MUTANT)
    False
#else
    True
#endif
  LtdName001 ->
#if defined(VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_NAME001_DROP_MUTANT)
    False
#else
    True
#endif
  LtdHost001 ->
#if defined(VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_HOST001_DROP_MUTANT)
    False
#else
    True
#endif
  LtdHost002 ->
#if defined(VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_HOST002_DROP_MUTANT)
    False
#else
    True
#endif
  LtdImg001 ->
#if defined(VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_IMG001_DROP_MUTANT)
    False
#else
    True
#endif
  LtdRun001 ->
#if defined(VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_RUN001_DROP_MUTANT)
    False
#else
    True
#endif
  LtdSeed001 ->
#if defined(VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_SEED001_DROP_MUTANT)
    False
#else
    True
#endif
  LtdSeed002 ->
#if defined(VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_SEED002_DROP_MUTANT)
    False
#else
    True
#endif
  LtdBoot001 ->
#if defined(VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_BOOT001_DROP_MUTANT)
    False
#else
    True
#endif

renderLegacyId :: LegacyId -> Text
renderLegacyId LtdSrc000 =
#if defined(VALIDATION_LEGACY_LTD_SRC000_ID_MUTANT)
  "LTD-SRC-00x"
#else
  "LTD-SRC-000"
#endif
renderLegacyId LtdSrc001 =
#if defined(VALIDATION_LEGACY_LTD_SRC001_ID_MUTANT)
  "LTD-SRC-00x"
#else
  "LTD-SRC-001"
#endif
renderLegacyId LtdSrc002 =
#if defined(VALIDATION_LEGACY_LTD_SRC002_ID_MUTANT)
  "LTD-SRC-00x"
#else
  "LTD-SRC-002"
#endif
renderLegacyId LtdSrc003 =
#if defined(VALIDATION_LEGACY_LTD_SRC003_ID_MUTANT)
  "LTD-SRC-00x"
#else
  "LTD-SRC-003"
#endif
renderLegacyId LtdSrc004 =
#if defined(VALIDATION_LEGACY_LTD_SRC004_ID_MUTANT)
  "LTD-SRC-00x"
#else
  "LTD-SRC-004"
#endif
renderLegacyId LtdSrc005 =
#if defined(VALIDATION_LEGACY_LTD_SRC005_ID_MUTANT)
  "LTD-SRC-00x"
#else
  "LTD-SRC-005"
#endif
renderLegacyId LtdSrc006 =
#if defined(VALIDATION_LEGACY_LTD_SRC006_ID_MUTANT)
  "LTD-SRC-00x"
#else
  "LTD-SRC-006"
#endif
renderLegacyId LtdSrc007 =
#if defined(VALIDATION_LEGACY_LTD_SRC007_ID_MUTANT)
  "LTD-SRC-00x"
#else
  "LTD-SRC-007"
#endif
renderLegacyId LtdSrc008 =
#if defined(VALIDATION_LEGACY_LTD_SRC008_ID_MUTANT)
  "LTD-SRC-00x"
#else
  "LTD-SRC-008"
#endif
renderLegacyId LtdSrc009 =
#if defined(VALIDATION_LEGACY_LTD_SRC009_ID_MUTANT)
  "LTD-SRC-00x"
#else
  "LTD-SRC-009"
#endif
renderLegacyId LtdMeta001 =
#if defined(VALIDATION_LEGACY_LTD_META001_ID_MUTANT)
  "LTD-META-00x"
#else
  "LTD-META-001"
#endif
renderLegacyId LtdVal001 =
#if defined(VALIDATION_LEGACY_LTD_VAL001_ID_MUTANT)
  "LTD-VAL-00x"
#else
  "LTD-VAL-001"
#endif
renderLegacyId LtdVal002 =
#if defined(VALIDATION_LEGACY_LTD_VAL002_ID_MUTANT)
  "LTD-VAL-00x"
#else
  "LTD-VAL-002"
#endif
renderLegacyId LtdVal003 =
#if defined(VALIDATION_LEGACY_LTD_VAL003_ID_MUTANT)
  "LTD-VAL-00x"
#else
  "LTD-VAL-003"
#endif
renderLegacyId LtdVal004 =
#if defined(VALIDATION_LEGACY_LTD_VAL004_ID_MUTANT)
  "LTD-VAL-00x"
#else
  "LTD-VAL-004"
#endif
renderLegacyId LtdVal005 =
#if defined(VALIDATION_LEGACY_LTD_VAL005_ID_MUTANT)
  "LTD-VAL-00x"
#else
  "LTD-VAL-005"
#endif
renderLegacyId LtdVal006 =
#if defined(VALIDATION_LEGACY_LTD_VAL006_ID_MUTANT)
  "LTD-VAL-00x"
#else
  "LTD-VAL-006"
#endif
renderLegacyId LtdDoc001 =
#if defined(VALIDATION_LEGACY_LTD_DOC001_ID_MUTANT)
  "LTD-DOC-00x"
#else
  "LTD-DOC-001"
#endif
renderLegacyId LtdName001 =
#if defined(VALIDATION_LEGACY_LTD_NAME001_ID_MUTANT)
  "LTD-NAME-00x"
#else
  "LTD-NAME-001"
#endif
renderLegacyId LtdHost001 =
#if defined(VALIDATION_LEGACY_LTD_HOST001_ID_MUTANT)
  "LTD-HOST-00x"
#else
  "LTD-HOST-001"
#endif
renderLegacyId LtdHost002 =
#if defined(VALIDATION_LEGACY_LTD_HOST002_ID_MUTANT)
  "LTD-HOST-00x"
#else
  "LTD-HOST-002"
#endif
renderLegacyId LtdImg001 =
#if defined(VALIDATION_LEGACY_LTD_IMG001_ID_MUTANT)
  "LTD-IMG-00x"
#else
  "LTD-IMG-001"
#endif
renderLegacyId LtdRun001 =
#if defined(VALIDATION_LEGACY_LTD_RUN001_ID_MUTANT)
  "LTD-RUN-00x"
#else
  "LTD-RUN-001"
#endif
renderLegacyId LtdSeed001 =
#if defined(VALIDATION_LEGACY_LTD_SEED001_ID_MUTANT)
  "LTD-SEED-00x"
#else
  "LTD-SEED-001"
#endif
renderLegacyId LtdSeed002 =
#if defined(VALIDATION_LEGACY_LTD_SEED002_ID_MUTANT)
  "LTD-SEED-00x"
#else
  "LTD-SEED-002"
#endif
renderLegacyId LtdBoot001 =
#if defined(VALIDATION_LEGACY_LTD_BOOT001_ID_MUTANT)
  "LTD-BOOT-00x"
#else
  "LTD-BOOT-001"
#endif

parseLegacyId :: Text -> Maybe LegacyId
parseLegacyId value =
#if defined(VALIDATION_LEGACY_INTERNAL_PARSE_UNKNOWN_ACCEPT_MUTANT)
  if value == "LTD-SRC-00x" then Just LtdSrc000 else Map.lookup value legacyIdDecoder
#elif defined(VALIDATION_LEGACY_INTERNAL_PARSE_CANONICAL_REJECT_MUTANT)
  if value == "LTD-SRC-000" then Nothing else Map.lookup value legacyIdDecoder
#else
  Map.lookup value legacyIdDecoder
#endif

-- | The complete accepted parser-key universe. The parser is a direct lookup
-- in this map, so an independent oracle can pin every accepted spelling rather
-- than infer exactness from a finite rejection sample.
acceptedLegacyIdEncodings :: [Text]
acceptedLegacyIdEncodings =
#if defined(VALIDATION_LEGACY_INTERNAL_ACCEPTED_ENCODINGS_DROP_MUTANT)
  drop 1 (Map.keys legacyIdDecoder)
#elif defined(VALIDATION_LEGACY_INTERNAL_ACCEPTED_ENCODINGS_ORDER_MUTANT)
  reverse (Map.keys legacyIdDecoder)
#else
  Map.keys legacyIdDecoder
#endif

legacyIdDecoder :: Map Text LegacyId
legacyIdDecoder =
#if defined(VALIDATION_LEGACY_INTERNAL_DECODER_ALIAS_MUTANT)
  Map.insert "LTD-SRC-00x" LtdSrc000 canonicalLegacyIdDecoder
#elif defined(VALIDATION_LEGACY_INTERNAL_DECODER_KEY_DROP_MUTANT)
  Map.delete "LTD-SRC-000" canonicalLegacyIdDecoder
#else
  canonicalLegacyIdDecoder
#endif

canonicalLegacyIdDecoder :: Map Text LegacyId
#if defined(VALIDATION_LEGACY_INTERNAL_CANONICAL_DECODER_COMPOSITION_MUTANT)
canonicalLegacyIdDecoder =
  Map.delete (renderLegacyId LtdSrc000)
    (Map.fromList
      [ (renderLegacyId identifier, legacyDecoderTarget identifier)
      | identifier <- canonicalLegacyUniverse
      ])
#else
canonicalLegacyIdDecoder =
  Map.fromList
    [ (renderLegacyId identifier, legacyDecoderTarget identifier)
    | identifier <- canonicalLegacyUniverse
    ]
#endif

legacyDecoderTarget :: LegacyId -> LegacyId
legacyDecoderTarget identifier = case identifier of
  LtdSrc000 ->
#if defined(VALIDATION_LEGACY_INTERNAL_DECODER_LTD_SRC000_TARGET_MUTANT)
    LtdSrc001
#else
    LtdSrc000
#endif
  LtdSrc001 ->
#if defined(VALIDATION_LEGACY_INTERNAL_DECODER_LTD_SRC001_TARGET_MUTANT)
    LtdSrc000
#else
    LtdSrc001
#endif
  LtdSrc002 ->
#if defined(VALIDATION_LEGACY_INTERNAL_DECODER_LTD_SRC002_TARGET_MUTANT)
    LtdSrc000
#else
    LtdSrc002
#endif
  LtdSrc003 ->
#if defined(VALIDATION_LEGACY_INTERNAL_DECODER_LTD_SRC003_TARGET_MUTANT)
    LtdSrc000
#else
    LtdSrc003
#endif
  LtdSrc004 ->
#if defined(VALIDATION_LEGACY_INTERNAL_DECODER_LTD_SRC004_TARGET_MUTANT)
    LtdSrc000
#else
    LtdSrc004
#endif
  LtdSrc005 ->
#if defined(VALIDATION_LEGACY_INTERNAL_DECODER_LTD_SRC005_TARGET_MUTANT)
    LtdSrc000
#else
    LtdSrc005
#endif
  LtdSrc006 ->
#if defined(VALIDATION_LEGACY_INTERNAL_DECODER_LTD_SRC006_TARGET_MUTANT)
    LtdSrc000
#else
    LtdSrc006
#endif
  LtdSrc007 ->
#if defined(VALIDATION_LEGACY_INTERNAL_DECODER_LTD_SRC007_TARGET_MUTANT)
    LtdSrc000
#else
    LtdSrc007
#endif
  LtdSrc008 ->
#if defined(VALIDATION_LEGACY_INTERNAL_DECODER_LTD_SRC008_TARGET_MUTANT)
    LtdSrc000
#else
    LtdSrc008
#endif
  LtdSrc009 ->
#if defined(VALIDATION_LEGACY_INTERNAL_DECODER_LTD_SRC009_TARGET_MUTANT)
    LtdSrc000
#else
    LtdSrc009
#endif
  LtdMeta001 ->
#if defined(VALIDATION_LEGACY_INTERNAL_DECODER_LTD_META001_TARGET_MUTANT)
    LtdSrc000
#else
    LtdMeta001
#endif
  LtdVal001 ->
#if defined(VALIDATION_LEGACY_INTERNAL_DECODER_LTD_VAL001_TARGET_MUTANT)
    LtdSrc000
#else
    LtdVal001
#endif
  LtdVal002 ->
#if defined(VALIDATION_LEGACY_INTERNAL_DECODER_LTD_VAL002_TARGET_MUTANT)
    LtdSrc000
#else
    LtdVal002
#endif
  LtdVal003 ->
#if defined(VALIDATION_LEGACY_INTERNAL_DECODER_LTD_VAL003_TARGET_MUTANT)
    LtdSrc000
#else
    LtdVal003
#endif
  LtdVal004 ->
#if defined(VALIDATION_LEGACY_INTERNAL_DECODER_LTD_VAL004_TARGET_MUTANT)
    LtdSrc000
#else
    LtdVal004
#endif
  LtdVal005 ->
#if defined(VALIDATION_LEGACY_INTERNAL_DECODER_LTD_VAL005_TARGET_MUTANT)
    LtdSrc000
#else
    LtdVal005
#endif
  LtdVal006 ->
#if defined(VALIDATION_LEGACY_INTERNAL_DECODER_LTD_VAL006_TARGET_MUTANT)
    LtdSrc000
#else
    LtdVal006
#endif
  LtdDoc001 ->
#if defined(VALIDATION_LEGACY_INTERNAL_DECODER_LTD_DOC001_TARGET_MUTANT)
    LtdSrc000
#else
    LtdDoc001
#endif
  LtdName001 ->
#if defined(VALIDATION_LEGACY_INTERNAL_DECODER_LTD_NAME001_TARGET_MUTANT)
    LtdSrc000
#else
    LtdName001
#endif
  LtdHost001 ->
#if defined(VALIDATION_LEGACY_INTERNAL_DECODER_LTD_HOST001_TARGET_MUTANT)
    LtdSrc000
#else
    LtdHost001
#endif
  LtdHost002 ->
#if defined(VALIDATION_LEGACY_INTERNAL_DECODER_LTD_HOST002_TARGET_MUTANT)
    LtdSrc000
#else
    LtdHost002
#endif
  LtdImg001 ->
#if defined(VALIDATION_LEGACY_INTERNAL_DECODER_LTD_IMG001_TARGET_MUTANT)
    LtdSrc000
#else
    LtdImg001
#endif
  LtdRun001 ->
#if defined(VALIDATION_LEGACY_INTERNAL_DECODER_LTD_RUN001_TARGET_MUTANT)
    LtdSrc000
#else
    LtdRun001
#endif
  LtdSeed001 ->
#if defined(VALIDATION_LEGACY_INTERNAL_DECODER_LTD_SEED001_TARGET_MUTANT)
    LtdSrc000
#else
    LtdSeed001
#endif
  LtdSeed002 ->
#if defined(VALIDATION_LEGACY_INTERNAL_DECODER_LTD_SEED002_TARGET_MUTANT)
    LtdSrc000
#else
    LtdSeed002
#endif
  LtdBoot001 ->
#if defined(VALIDATION_LEGACY_INTERNAL_DECODER_LTD_BOOT001_TARGET_MUTANT)
    LtdSrc000
#else
    LtdBoot001
#endif

-- | The owner of a legacy binding is the phase /capability/ that must make the
-- replacement true, never an ordinal.
--
-- An ordinal is a coordinate of the plan's present order, so a reorder moves
-- it and every literal that named it goes silently wrong. A capability does not
-- move. 'legacyIdOwner' keeps its type and its values: the ordinal is now a
-- projection, resolved through the phase-identity table.
legacyIdOwner :: LegacyId -> Policy.PhaseOrdinal
legacyIdOwner = ownerCapabilityOrdinal . legacyIdOwnerCapability

-- | An owner capability that no phase provides cannot be resolved. It falls
-- back to the domain lower bound so the function stays total, and
-- 'legacyOwnerCapabilityProblems' reports it, so the unresolved name is visible
-- rather than silently absorbed.
ownerCapabilityOrdinal :: Text -> Policy.PhaseOrdinal
ownerCapabilityOrdinal capability =
  case PhaseIdentity.lookupCapabilityOrdinal capability of
    Just ordinal -> phaseOrdinal ordinal
    Nothing -> Policy.phaseDomainLower (Policy.orderingContract Policy.canonicalPolicyContract)

-- | Every legacy owner capability must be one a phase actually provides.
legacyOwnerCapabilityProblems :: [Text]
legacyOwnerCapabilityProblems =
  [ "legacy owner capability is not provided by any phase: "
      <> renderLegacyId identifier
      <> "="
      <> legacyIdOwnerCapability identifier
  | identifier <- allLegacyIds
  , PhaseIdentity.lookupCapabilityOrdinal (legacyIdOwnerCapability identifier) == Nothing
  ]

legacyIdOwnerCapability :: LegacyId -> Text
legacyIdOwnerCapability LtdSrc000 =
#if defined(VALIDATION_LEGACY_LTD_SRC000_OWNER_MUTANT)
  "toolchain_spike"
#else
  "documentation_suite"
#endif
legacyIdOwnerCapability LtdSrc001 =
#if defined(VALIDATION_LEGACY_LTD_SRC001_OWNER_MUTANT)
  "documentation_suite"
#else
  "tool_and_mutant_generation"
#endif
legacyIdOwnerCapability LtdSrc002 =
#if defined(VALIDATION_LEGACY_LTD_SRC002_OWNER_MUTANT)
  "documentation_suite"
#else
  "dhall_schema_generation"
#endif
legacyIdOwnerCapability LtdSrc003 =
#if defined(VALIDATION_LEGACY_LTD_SRC003_OWNER_MUTANT)
  "documentation_suite"
#else
  "gadt_decode_ir"
#endif
legacyIdOwnerCapability LtdSrc004 =
#if defined(VALIDATION_LEGACY_LTD_SRC004_OWNER_MUTANT)
  "documentation_suite"
#else
  "ui_contract_generation"
#endif
legacyIdOwnerCapability LtdSrc005 =
#if defined(VALIDATION_LEGACY_LTD_SRC005_OWNER_MUTANT)
  "documentation_suite"
#else
  "tool_and_mutant_generation"
#endif
legacyIdOwnerCapability LtdSrc006 =
#if defined(VALIDATION_LEGACY_LTD_SRC006_OWNER_MUTANT)
  "documentation_suite"
#else
  "tool_and_mutant_generation"
#endif
legacyIdOwnerCapability LtdSrc007 =
#if defined(VALIDATION_LEGACY_LTD_SRC007_OWNER_MUTANT)
  "documentation_suite"
#else
  "toolchain_spike"
#endif
legacyIdOwnerCapability LtdSrc008 =
#if defined(VALIDATION_LEGACY_LTD_SRC008_OWNER_MUTANT)
  "toolchain_spike"
#else
  "documentation_suite"
#endif
legacyIdOwnerCapability LtdSrc009 =
#if defined(VALIDATION_LEGACY_LTD_SRC009_OWNER_MUTANT)
  "documentation_suite"
#else
  "toolchain_spike"
#endif
legacyIdOwnerCapability LtdMeta001 =
#if defined(VALIDATION_LEGACY_LTD_META001_OWNER_MUTANT)
  "documentation_suite"
#else
  "repository_layout_conformance"
#endif
legacyIdOwnerCapability LtdVal001 =
#if defined(VALIDATION_LEGACY_LTD_VAL001_OWNER_MUTANT)
  "toolchain_spike"
#else
  "documentation_suite"
#endif
legacyIdOwnerCapability LtdVal002 =
#if defined(VALIDATION_LEGACY_LTD_VAL002_OWNER_MUTANT)
  "toolchain_spike"
#else
  "documentation_suite"
#endif
legacyIdOwnerCapability LtdVal003 =
#if defined(VALIDATION_LEGACY_LTD_VAL003_OWNER_MUTANT)
  "toolchain_spike"
#else
  "documentation_suite"
#endif
legacyIdOwnerCapability LtdVal004 =
#if defined(VALIDATION_LEGACY_LTD_VAL004_OWNER_MUTANT)
  "toolchain_spike"
#else
  "documentation_suite"
#endif
legacyIdOwnerCapability LtdVal005 =
#if defined(VALIDATION_LEGACY_LTD_VAL005_OWNER_MUTANT)
  "documentation_suite"
#else
  "self_referential_gates"
#endif
-- Cleanroom and freshness are properties of the run harness, not of tool
-- generation: every phase's gate inherits both rows, so an owner later than the
-- first phase makes every earlier phase depend on a capability it cannot have.
legacyIdOwnerCapability LtdVal006 =
#if defined(VALIDATION_LEGACY_LTD_VAL006_OWNER_MUTANT)
  "tool_and_mutant_generation"
#else
  "documentation_suite"
#endif
legacyIdOwnerCapability LtdDoc001 =
#if defined(VALIDATION_LEGACY_LTD_DOC001_OWNER_MUTANT)
  "documentation_suite"
#else
  "illegal_state_covering"
#endif
legacyIdOwnerCapability LtdName001 =
#if defined(VALIDATION_LEGACY_LTD_NAME001_OWNER_MUTANT)
  "documentation_suite"
#else
  "repository_layout_conformance"
#endif
legacyIdOwnerCapability LtdHost001 =
#if defined(VALIDATION_LEGACY_LTD_HOST001_OWNER_MUTANT)
  "documentation_suite"
#else
  "host_ensure_kernel"
#endif
legacyIdOwnerCapability LtdHost002 =
#if defined(VALIDATION_LEGACY_LTD_HOST002_OWNER_MUTANT)
  "documentation_suite"
#else
  "host_ensure_kernel"
#endif
legacyIdOwnerCapability LtdImg001 =
#if defined(VALIDATION_LEGACY_LTD_IMG001_OWNER_MUTANT)
  "documentation_suite"
#else
  "base_image_registry"
#endif
legacyIdOwnerCapability LtdRun001 =
#if defined(VALIDATION_LEGACY_LTD_RUN001_OWNER_MUTANT)
  "documentation_suite"
#else
  "bootstrap_coordinator_kind"
#endif
legacyIdOwnerCapability LtdSeed001 =
#if defined(VALIDATION_LEGACY_LTD_SEED001_OWNER_MUTANT)
  "documentation_suite"
#else
  "infernix_rederivation"
#endif
legacyIdOwnerCapability LtdSeed002 =
#if defined(VALIDATION_LEGACY_LTD_SEED002_OWNER_MUTANT)
  "documentation_suite"
#else
  "jitml_rederivation"
#endif
-- The bootstrap belongs to the first phase: the toolchain that builds the
-- ordinal-0 candidate is the one thing that phase cannot verify with itself.
legacyIdOwnerCapability LtdBoot001 =
#if defined(VALIDATION_LEGACY_LTD_BOOT001_OWNER_MUTANT)
  "toolchain_spike"
#else
  "documentation_suite"
#endif

legacyIdDisposition :: LegacyId -> LegacyDisposition
legacyIdDisposition LtdSrc000 = LegacyActive
legacyIdDisposition LtdSrc001 = LegacyActive
legacyIdDisposition LtdSrc002 = LegacyActive
legacyIdDisposition LtdSrc003 = LegacyActive
legacyIdDisposition LtdSrc004 = LegacyActive
legacyIdDisposition LtdSrc005 = LegacyActive
legacyIdDisposition LtdSrc006 = LegacyActive
legacyIdDisposition LtdSrc007 = LegacyActive
legacyIdDisposition LtdSrc008 = LegacyActive
legacyIdDisposition LtdSrc009 = LegacyActive
legacyIdDisposition LtdMeta001 = LegacyActive
legacyIdDisposition LtdVal001 = LegacyActive
legacyIdDisposition LtdVal002 = LegacyActive
legacyIdDisposition LtdVal003 = LegacyActive
legacyIdDisposition LtdVal004 = LegacyActive
legacyIdDisposition LtdVal005 = LegacyActive
legacyIdDisposition LtdVal006 = LegacyActive
legacyIdDisposition LtdDoc001 = LegacyActive
legacyIdDisposition LtdName001 = LegacyActive
legacyIdDisposition LtdHost001 = LegacyActive
legacyIdDisposition LtdHost002 = LegacyActive
legacyIdDisposition LtdImg001 = LegacyActive
legacyIdDisposition LtdRun001 = LegacyActive
legacyIdDisposition LtdSeed001 = LegacyActive
legacyIdDisposition LtdSeed002 = LegacyActive
legacyIdDisposition LtdBoot001 = LegacyActive

legacyIdAnalyzer :: LegacyId -> LegacyAnalyzer
legacyIdAnalyzer LtdSrc000 =
#if defined(VALIDATION_LEGACY_LTD_SRC000_ANALYZER_MUTANT)
  AnalyzeSourceTools
#else
  AnalyzeCompleteSourceGrammar
#endif
legacyIdAnalyzer LtdSrc001 =
#if defined(VALIDATION_LEGACY_LTD_SRC001_ANALYZER_MUTANT)
  AnalyzeCompleteSourceGrammar
#else
  AnalyzeSourceTools
#endif
legacyIdAnalyzer LtdSrc002 =
#if defined(VALIDATION_LEGACY_LTD_SRC002_ANALYZER_MUTANT)
  AnalyzeCompleteSourceGrammar
#else
  AnalyzeSourceDhall
#endif
legacyIdAnalyzer LtdSrc003 =
#if defined(VALIDATION_LEGACY_LTD_SRC003_ANALYZER_MUTANT)
  AnalyzeCompleteSourceGrammar
#else
  AnalyzeSourceProto
#endif
legacyIdAnalyzer LtdSrc004 =
#if defined(VALIDATION_LEGACY_LTD_SRC004_ANALYZER_MUTANT)
  AnalyzeCompleteSourceGrammar
#else
  AnalyzeSourceUi
#endif
legacyIdAnalyzer LtdSrc005 =
#if defined(VALIDATION_LEGACY_LTD_SRC005_ANALYZER_MUTANT)
  AnalyzeCompleteSourceGrammar
#else
  AnalyzeSourcePulumi
#endif
legacyIdAnalyzer LtdSrc006 =
#if defined(VALIDATION_LEGACY_LTD_SRC006_ANALYZER_MUTANT)
  AnalyzeCompleteSourceGrammar
#else
  AnalyzeSourceTest
#endif
legacyIdAnalyzer LtdSrc007 =
#if defined(VALIDATION_LEGACY_LTD_SRC007_ANALYZER_MUTANT)
  AnalyzeCompleteSourceGrammar
#else
  AnalyzeSourceProbe
#endif
legacyIdAnalyzer LtdSrc008 =
#if defined(VALIDATION_LEGACY_LTD_SRC008_ANALYZER_MUTANT)
  AnalyzeCompleteSourceGrammar
#else
  AnalyzeSourcePb
#endif
legacyIdAnalyzer LtdSrc009 =
#if defined(VALIDATION_LEGACY_LTD_SRC009_ANALYZER_MUTANT)
  AnalyzeCompleteSourceGrammar
#else
  AnalyzeSourceVendor
#endif
legacyIdAnalyzer LtdMeta001 =
#if defined(VALIDATION_LEGACY_LTD_META001_ANALYZER_MUTANT)
  AnalyzeCompleteSourceGrammar
#else
  AnalyzeRetiredIgnoreRules
#endif
legacyIdAnalyzer LtdVal001 =
#if defined(VALIDATION_LEGACY_LTD_VAL001_ANALYZER_MUTANT)
  AnalyzeCompleteSourceGrammar
#else
  AnalyzeValidationProtocol
#endif
legacyIdAnalyzer LtdVal002 =
#if defined(VALIDATION_LEGACY_LTD_VAL002_ANALYZER_MUTANT)
  AnalyzeCompleteSourceGrammar
#else
  AnalyzePhaseContracts
#endif
legacyIdAnalyzer LtdVal003 =
#if defined(VALIDATION_LEGACY_LTD_VAL003_ANALYZER_MUTANT)
  AnalyzeCompleteSourceGrammar
#else
  AnalyzeStatusEvidence
#endif
legacyIdAnalyzer LtdVal004 =
#if defined(VALIDATION_LEGACY_LTD_VAL004_ANALYZER_MUTANT)
  AnalyzeCompleteSourceGrammar
#else
  AnalyzeGateCompletion
#endif
legacyIdAnalyzer LtdVal005 =
#if defined(VALIDATION_LEGACY_LTD_VAL005_ANALYZER_MUTANT)
  AnalyzeCompleteSourceGrammar
#else
  AnalyzeHardwareFreeDsl
#endif
legacyIdAnalyzer LtdVal006 =
#if defined(VALIDATION_LEGACY_LTD_VAL006_ANALYZER_MUTANT)
  AnalyzeCompleteSourceGrammar
#else
  AnalyzeRunInputClosure
#endif
legacyIdAnalyzer LtdDoc001 =
#if defined(VALIDATION_LEGACY_LTD_DOC001_ANALYZER_MUTANT)
  AnalyzeCompleteSourceGrammar
#else
  AnalyzeBehavioralDocumentConsumers
#endif
legacyIdAnalyzer LtdName001 =
#if defined(VALIDATION_LEGACY_LTD_NAME001_ANALYZER_MUTANT)
  AnalyzeCompleteSourceGrammar
#else
  AnalyzePhaseOrdinalNames
#endif
legacyIdAnalyzer LtdHost001 =
#if defined(VALIDATION_LEGACY_LTD_HOST001_ANALYZER_MUTANT)
  AnalyzeCompleteSourceGrammar
#else
  AnalyzeHostEnsure
#endif
legacyIdAnalyzer LtdHost002 =
#if defined(VALIDATION_LEGACY_LTD_HOST002_ANALYZER_MUTANT)
  AnalyzeCompleteSourceGrammar
#else
  AnalyzeAmbientHostPaths
#endif
legacyIdAnalyzer LtdImg001 =
#if defined(VALIDATION_LEGACY_LTD_IMG001_ANALYZER_MUTANT)
  AnalyzeCompleteSourceGrammar
#else
  AnalyzeNaturalArchitectureImages
#endif
legacyIdAnalyzer LtdRun001 =
#if defined(VALIDATION_LEGACY_LTD_RUN001_ANALYZER_MUTANT)
  AnalyzeCompleteSourceGrammar
#else
  AnalyzeExecutableIdentity
#endif
legacyIdAnalyzer LtdSeed001 =
#if defined(VALIDATION_LEGACY_LTD_SEED001_ANALYZER_MUTANT)
  AnalyzeCompleteSourceGrammar
#else
  AnalyzeInfernixSeedDependency
#endif
legacyIdAnalyzer LtdSeed002 =
#if defined(VALIDATION_LEGACY_LTD_SEED002_ANALYZER_MUTANT)
  AnalyzeCompleteSourceGrammar
#else
  AnalyzeJitMlSeedDependency
#endif
legacyIdAnalyzer LtdBoot001 =
#if defined(VALIDATION_LEGACY_LTD_BOOT001_ANALYZER_MUTANT)
  AnalyzeCompleteSourceGrammar
#else
  AnalyzeBootstrapToolchain
#endif

legacyIdObservationRule :: LegacyId -> LegacyObservationRule
legacyIdObservationRule LtdSrc000 =
#if defined(VALIDATION_LEGACY_LTD_SRC000_OBSERVATION_MUTANT)
  ObserveSourceTools
#else
  ObserveCompleteSourceSnapshot
#endif
legacyIdObservationRule LtdSrc001 =
#if defined(VALIDATION_LEGACY_LTD_SRC001_OBSERVATION_MUTANT)
  ObserveCompleteSourceSnapshot
#else
  ObserveSourceTools
#endif
legacyIdObservationRule LtdSrc002 =
#if defined(VALIDATION_LEGACY_LTD_SRC002_OBSERVATION_MUTANT)
  ObserveCompleteSourceSnapshot
#else
  ObserveSourceDhall
#endif
legacyIdObservationRule LtdSrc003 =
#if defined(VALIDATION_LEGACY_LTD_SRC003_OBSERVATION_MUTANT)
  ObserveCompleteSourceSnapshot
#else
  ObserveSourceProto
#endif
legacyIdObservationRule LtdSrc004 =
#if defined(VALIDATION_LEGACY_LTD_SRC004_OBSERVATION_MUTANT)
  ObserveCompleteSourceSnapshot
#else
  ObserveSourceUi
#endif
legacyIdObservationRule LtdSrc005 =
#if defined(VALIDATION_LEGACY_LTD_SRC005_OBSERVATION_MUTANT)
  ObserveCompleteSourceSnapshot
#else
  ObserveSourcePulumi
#endif
legacyIdObservationRule LtdSrc006 =
#if defined(VALIDATION_LEGACY_LTD_SRC006_OBSERVATION_MUTANT)
  ObserveCompleteSourceSnapshot
#else
  ObserveSourceTest
#endif
legacyIdObservationRule LtdSrc007 =
#if defined(VALIDATION_LEGACY_LTD_SRC007_OBSERVATION_MUTANT)
  ObserveCompleteSourceSnapshot
#else
  ObserveSourceProbe
#endif
legacyIdObservationRule LtdSrc008 =
#if defined(VALIDATION_LEGACY_LTD_SRC008_OBSERVATION_MUTANT)
  ObserveCompleteSourceSnapshot
#else
  ObserveSourcePb
#endif
legacyIdObservationRule LtdSrc009 =
#if defined(VALIDATION_LEGACY_LTD_SRC009_OBSERVATION_MUTANT)
  ObserveCompleteSourceSnapshot
#else
  ObserveSourceVendor
#endif
legacyIdObservationRule LtdMeta001 =
#if defined(VALIDATION_LEGACY_LTD_META001_OBSERVATION_MUTANT)
  ObserveCompleteSourceSnapshot
#else
  ObserveParsedIgnoreGrammars
#endif
legacyIdObservationRule LtdVal001 =
#if defined(VALIDATION_LEGACY_LTD_VAL001_OBSERVATION_MUTANT)
  ObserveCompleteSourceSnapshot
#else
  ObserveValidationGateGraph
#endif
legacyIdObservationRule LtdVal002 =
#if defined(VALIDATION_LEGACY_LTD_VAL002_OBSERVATION_MUTANT)
  ObserveCompleteSourceSnapshot
#else
  ObserveTypedPhaseContractBinding
#endif
legacyIdObservationRule LtdVal003 =
#if defined(VALIDATION_LEGACY_LTD_VAL003_OBSERVATION_MUTANT)
  ObserveCompleteSourceSnapshot
#else
  ObserveStatusEvidenceProjection
#endif
legacyIdObservationRule LtdVal004 =
#if defined(VALIDATION_LEGACY_LTD_VAL004_OBSERVATION_MUTANT)
  ObserveCompleteSourceSnapshot
#else
  ObserveGateCompletionResult
#endif
legacyIdObservationRule LtdVal005 =
#if defined(VALIDATION_LEGACY_LTD_VAL005_OBSERVATION_MUTANT)
  ObserveCompleteSourceSnapshot
#else
  ObserveHardwareFreeDslTrace
#endif
legacyIdObservationRule LtdVal006 =
#if defined(VALIDATION_LEGACY_LTD_VAL006_OBSERVATION_MUTANT)
  ObserveCompleteSourceSnapshot
#else
  ObserveRunInputProvenance
#endif
legacyIdObservationRule LtdDoc001 =
#if defined(VALIDATION_LEGACY_LTD_DOC001_OBSERVATION_MUTANT)
  ObserveCompleteSourceSnapshot
#else
  ObserveDocumentConsumerGraph
#endif
legacyIdObservationRule LtdName001 =
#if defined(VALIDATION_LEGACY_LTD_NAME001_OBSERVATION_MUTANT)
  ObserveCompleteSourceSnapshot
#else
  ObserveRuntimeIdentityGraph
#endif
legacyIdObservationRule LtdHost001 =
#if defined(VALIDATION_LEGACY_LTD_HOST001_OBSERVATION_MUTANT)
  ObserveCompleteSourceSnapshot
#else
  ObserveHostEnsureCallGraph
#endif
legacyIdObservationRule LtdHost002 =
#if defined(VALIDATION_LEGACY_LTD_HOST002_OBSERVATION_MUTANT)
  ObserveCompleteSourceSnapshot
#else
  ObserveHostPathEffectGraph
#endif
legacyIdObservationRule LtdImg001 =
#if defined(VALIDATION_LEGACY_LTD_IMG001_OBSERVATION_MUTANT)
  ObserveCompleteSourceSnapshot
#else
  ObserveImagePlanAndBinfmt
#endif
legacyIdObservationRule LtdRun001 =
#if defined(VALIDATION_LEGACY_LTD_RUN001_OBSERVATION_MUTANT)
  ObserveCompleteSourceSnapshot
#else
  ObserveCabalExecutableGraph
#endif
legacyIdObservationRule LtdSeed001 =
#if defined(VALIDATION_LEGACY_LTD_SEED001_OBSERVATION_MUTANT)
  ObserveCompleteSourceSnapshot
#else
  ObserveInfernixDependencyGraph
#endif
legacyIdObservationRule LtdSeed002 =
#if defined(VALIDATION_LEGACY_LTD_SEED002_OBSERVATION_MUTANT)
  ObserveCompleteSourceSnapshot
#else
  ObserveJitMlDependencyGraph
#endif
legacyIdObservationRule LtdBoot001 =
#if defined(VALIDATION_LEGACY_LTD_BOOT001_OBSERVATION_MUTANT)
  ObserveCompleteSourceSnapshot
#else
  ObserveBootstrapToolchainProvenance
#endif

legacyIdClosureRule :: LegacyId -> LegacyClosureRule
legacyIdClosureRule LtdSrc000 =
#if defined(VALIDATION_LEGACY_LTD_SRC000_CLOSURE_MUTANT)
  CloseSourceTools
#else
  CloseCompleteSourceGrammar
#endif
legacyIdClosureRule LtdSrc001 =
#if defined(VALIDATION_LEGACY_LTD_SRC001_CLOSURE_MUTANT)
  CloseCompleteSourceGrammar
#else
  CloseSourceTools
#endif
legacyIdClosureRule LtdSrc002 =
#if defined(VALIDATION_LEGACY_LTD_SRC002_CLOSURE_MUTANT)
  CloseCompleteSourceGrammar
#else
  CloseSourceDhall
#endif
legacyIdClosureRule LtdSrc003 =
#if defined(VALIDATION_LEGACY_LTD_SRC003_CLOSURE_MUTANT)
  CloseCompleteSourceGrammar
#else
  CloseSourceProto
#endif
legacyIdClosureRule LtdSrc004 =
#if defined(VALIDATION_LEGACY_LTD_SRC004_CLOSURE_MUTANT)
  CloseCompleteSourceGrammar
#else
  CloseSourceUi
#endif
legacyIdClosureRule LtdSrc005 =
#if defined(VALIDATION_LEGACY_LTD_SRC005_CLOSURE_MUTANT)
  CloseCompleteSourceGrammar
#else
  CloseSourcePulumi
#endif
legacyIdClosureRule LtdSrc006 =
#if defined(VALIDATION_LEGACY_LTD_SRC006_CLOSURE_MUTANT)
  CloseCompleteSourceGrammar
#else
  CloseSourceTest
#endif
legacyIdClosureRule LtdSrc007 =
#if defined(VALIDATION_LEGACY_LTD_SRC007_CLOSURE_MUTANT)
  CloseCompleteSourceGrammar
#else
  CloseSourceProbe
#endif
legacyIdClosureRule LtdSrc008 =
#if defined(VALIDATION_LEGACY_LTD_SRC008_CLOSURE_MUTANT)
  CloseCompleteSourceGrammar
#else
  CloseSourcePb
#endif
legacyIdClosureRule LtdSrc009 =
#if defined(VALIDATION_LEGACY_LTD_SRC009_CLOSURE_MUTANT)
  CloseCompleteSourceGrammar
#else
  CloseSourceVendor
#endif
legacyIdClosureRule LtdMeta001 =
#if defined(VALIDATION_LEGACY_LTD_META001_CLOSURE_MUTANT)
  CloseCompleteSourceGrammar
#else
  CloseRetiredIgnoreRules
#endif
legacyIdClosureRule LtdVal001 =
#if defined(VALIDATION_LEGACY_LTD_VAL001_CLOSURE_MUTANT)
  CloseCompleteSourceGrammar
#else
  CloseValidationProtocol
#endif
legacyIdClosureRule LtdVal002 =
#if defined(VALIDATION_LEGACY_LTD_VAL002_CLOSURE_MUTANT)
  CloseCompleteSourceGrammar
#else
  ClosePhaseContracts
#endif
legacyIdClosureRule LtdVal003 =
#if defined(VALIDATION_LEGACY_LTD_VAL003_CLOSURE_MUTANT)
  CloseCompleteSourceGrammar
#else
  CloseStatusEvidence
#endif
legacyIdClosureRule LtdVal004 =
#if defined(VALIDATION_LEGACY_LTD_VAL004_CLOSURE_MUTANT)
  CloseCompleteSourceGrammar
#else
  CloseGateCompletion
#endif
legacyIdClosureRule LtdVal005 =
#if defined(VALIDATION_LEGACY_LTD_VAL005_CLOSURE_MUTANT)
  CloseCompleteSourceGrammar
#else
  CloseHardwareFreeDsl
#endif
legacyIdClosureRule LtdVal006 =
#if defined(VALIDATION_LEGACY_LTD_VAL006_CLOSURE_MUTANT)
  CloseCompleteSourceGrammar
#else
  CloseRunInputClosure
#endif
legacyIdClosureRule LtdDoc001 =
#if defined(VALIDATION_LEGACY_LTD_DOC001_CLOSURE_MUTANT)
  CloseCompleteSourceGrammar
#else
  CloseBehavioralDocumentConsumers
#endif
legacyIdClosureRule LtdName001 =
#if defined(VALIDATION_LEGACY_LTD_NAME001_CLOSURE_MUTANT)
  CloseCompleteSourceGrammar
#else
  ClosePhaseOrdinalNames
#endif
legacyIdClosureRule LtdHost001 =
#if defined(VALIDATION_LEGACY_LTD_HOST001_CLOSURE_MUTANT)
  CloseCompleteSourceGrammar
#else
  CloseHostEnsure
#endif
legacyIdClosureRule LtdHost002 =
#if defined(VALIDATION_LEGACY_LTD_HOST002_CLOSURE_MUTANT)
  CloseCompleteSourceGrammar
#else
  CloseAmbientHostPaths
#endif
legacyIdClosureRule LtdImg001 =
#if defined(VALIDATION_LEGACY_LTD_IMG001_CLOSURE_MUTANT)
  CloseCompleteSourceGrammar
#else
  CloseNaturalArchitectureImages
#endif
legacyIdClosureRule LtdRun001 =
#if defined(VALIDATION_LEGACY_LTD_RUN001_CLOSURE_MUTANT)
  CloseCompleteSourceGrammar
#else
  CloseExecutableIdentity
#endif
legacyIdClosureRule LtdSeed001 =
#if defined(VALIDATION_LEGACY_LTD_SEED001_CLOSURE_MUTANT)
  CloseCompleteSourceGrammar
#else
  CloseInfernixSeedDependency
#endif
legacyIdClosureRule LtdSeed002 =
#if defined(VALIDATION_LEGACY_LTD_SEED002_CLOSURE_MUTANT)
  CloseCompleteSourceGrammar
#else
  CloseJitMlSeedDependency
#endif
legacyIdClosureRule LtdBoot001 =
#if defined(VALIDATION_LEGACY_LTD_BOOT001_CLOSURE_MUTANT)
  CloseCompleteSourceGrammar
#else
  CloseBootstrapToolchain
#endif

legacyIdReintroductionCases :: LegacyId -> NonEmpty LegacyReintroductionCase
legacyIdReintroductionCases LtdSrc000 =
#if defined(VALIDATION_LEGACY_LTD_SRC000_REINTRODUCTION_MUTANT)
  RejectTrackedToolsSource :| []
#else
  RejectDisguisedOrConcealedSource :| []
#endif
legacyIdReintroductionCases LtdSrc001 =
#if defined(VALIDATION_LEGACY_LTD_SRC001_REINTRODUCTION_MUTANT)
  RejectDisguisedOrConcealedSource :| []
#else
  RejectTrackedToolsSource :| []
#endif
legacyIdReintroductionCases LtdSrc002 =
#if defined(VALIDATION_LEGACY_LTD_SRC002_REINTRODUCTION_MUTANT)
  RejectDisguisedOrConcealedSource :| []
#else
  RejectTrackedDhallOrTsv :| []
#endif
legacyIdReintroductionCases LtdSrc003 =
#if defined(VALIDATION_LEGACY_LTD_SRC003_REINTRODUCTION_MUTANT)
  RejectDisguisedOrConcealedSource :| []
#else
  RejectTrackedProto :| []
#endif
legacyIdReintroductionCases LtdSrc004 =
#if defined(VALIDATION_LEGACY_LTD_SRC004_REINTRODUCTION_MUTANT)
  RejectDisguisedOrConcealedSource :| []
#else
  RejectTrackedUiSource :| []
#endif
legacyIdReintroductionCases LtdSrc005 =
#if defined(VALIDATION_LEGACY_LTD_SRC005_REINTRODUCTION_MUTANT)
  RejectDisguisedOrConcealedSource :| []
#else
  RejectTrackedPulumiSource :| []
#endif
legacyIdReintroductionCases LtdSrc006 =
#if defined(VALIDATION_LEGACY_LTD_SRC006_REINTRODUCTION_MUTANT)
  RejectDisguisedOrConcealedSource :| []
#else
  RejectTrackedBehavioralTestInput :| []
#endif
legacyIdReintroductionCases LtdSrc007 =
#if defined(VALIDATION_LEGACY_LTD_SRC007_REINTRODUCTION_MUTANT)
  RejectDisguisedOrConcealedSource :| []
#else
  RejectTrackedProbeDebt :| []
#endif
legacyIdReintroductionCases LtdSrc008 =
#if defined(VALIDATION_LEGACY_LTD_SRC008_REINTRODUCTION_MUTANT)
  RejectDisguisedOrConcealedSource :| []
#else
  RejectWidenedPbBehavior :| []
#endif
legacyIdReintroductionCases LtdSrc009 =
#if defined(VALIDATION_LEGACY_LTD_SRC009_REINTRODUCTION_MUTANT)
  RejectDisguisedOrConcealedSource :| []
#else
  RejectTopLevelVendorDebt :| []
#endif
legacyIdReintroductionCases LtdMeta001 =
#if defined(VALIDATION_LEGACY_LTD_META001_REINTRODUCTION_MUTANT)
  RejectDisguisedOrConcealedSource :| []
#else
  RejectRetiredIgnoreRule :| []
#endif
legacyIdReintroductionCases LtdVal001 =
#if defined(VALIDATION_LEGACY_LTD_VAL001_REINTRODUCTION_MUTANT)
  RejectDisguisedOrConcealedSource :| []
#else
  RejectNonHaskellValidationVerdict :| []
#endif
legacyIdReintroductionCases LtdVal002 =
#if defined(VALIDATION_LEGACY_LTD_VAL002_REINTRODUCTION_MUTANT)
  RejectDisguisedOrConcealedSource :| []
#else
  RejectUnboundPhaseContract :| []
#endif
legacyIdReintroductionCases LtdVal003 =
#if defined(VALIDATION_LEGACY_LTD_VAL003_REINTRODUCTION_MUTANT)
  RejectDisguisedOrConcealedSource :| []
#else
  RejectForgedStatusEvidence :| []
#endif
legacyIdReintroductionCases LtdVal004 =
#if defined(VALIDATION_LEGACY_LTD_VAL004_REINTRODUCTION_MUTANT)
  RejectDisguisedOrConcealedSource :| []
#else
  RejectIncompleteGate :| []
#endif
legacyIdReintroductionCases LtdVal005 =
#if defined(VALIDATION_LEGACY_LTD_VAL005_REINTRODUCTION_MUTANT)
  RejectDisguisedOrConcealedSource :| []
#else
  RejectHardwareBeforeDslGatePass :| []
#endif
legacyIdReintroductionCases LtdVal006 =
#if defined(VALIDATION_LEGACY_LTD_VAL006_REINTRODUCTION_MUTANT)
  RejectDisguisedOrConcealedSource :| []
#else
  RejectAmbientOrStaleRunInput :| []
#endif
legacyIdReintroductionCases LtdDoc001 =
#if defined(VALIDATION_LEGACY_LTD_DOC001_REINTRODUCTION_MUTANT)
  RejectDisguisedOrConcealedSource :| []
#else
  RejectBehavioralMarkdownConsumer :| []
#endif
legacyIdReintroductionCases LtdName001 =
#if defined(VALIDATION_LEGACY_LTD_NAME001_REINTRODUCTION_MUTANT)
  RejectDisguisedOrConcealedSource :| []
#else
  RejectRuntimePhaseOrdinal :| []
#endif
legacyIdReintroductionCases LtdHost001 =
#if defined(VALIDATION_LEGACY_LTD_HOST001_REINTRODUCTION_MUTANT)
  RejectDisguisedOrConcealedSource :| []
#else
  RejectBypassedHostEnsure :| []
#endif
legacyIdReintroductionCases LtdHost002 =
#if defined(VALIDATION_LEGACY_LTD_HOST002_REINTRODUCTION_MUTANT)
  RejectDisguisedOrConcealedSource :| []
#else
  RejectAmbientHostPath :| []
#endif
legacyIdReintroductionCases LtdImg001 =
#if defined(VALIDATION_LEGACY_LTD_IMG001_REINTRODUCTION_MUTANT)
  RejectDisguisedOrConcealedSource :| []
#else
  RejectCrossArchitectureImagePlan :| []
#endif
legacyIdReintroductionCases LtdRun001 =
#if defined(VALIDATION_LEGACY_LTD_RUN001_REINTRODUCTION_MUTANT)
  RejectDisguisedOrConcealedSource :| []
#else
  RejectSecondExecutableIdentity :| []
#endif
legacyIdReintroductionCases LtdSeed001 =
#if defined(VALIDATION_LEGACY_LTD_SEED001_REINTRODUCTION_MUTANT)
  RejectDisguisedOrConcealedSource :| []
#else
  RejectInfernixSeedDependency :| []
#endif
legacyIdReintroductionCases LtdSeed002 =
#if defined(VALIDATION_LEGACY_LTD_SEED002_REINTRODUCTION_MUTANT)
  RejectDisguisedOrConcealedSource :| []
#else
  RejectJitMlSeedDependency :| []
#endif
legacyIdReintroductionCases LtdBoot001 =
#if defined(VALIDATION_LEGACY_LTD_BOOT001_REINTRODUCTION_MUTANT)
  RejectDisguisedOrConcealedSource :| []
#else
  RejectUnverifiedBootstrapToolchain :| []
#endif

-- | Package-hidden standard-value projection used by the permanently
-- refusing public facade.  It is deliberately derived from the genuine typed
-- mappings above; there is no second behavioral table in the facade.
legacyRawDiagnosticBindings :: [(Text, Text, Text, Text, Text, Text, [Text])]
#if defined(VALIDATION_LEGACY_INTERNAL_RAW_BINDING_LIST_COMPOSITION_MUTANT)
legacyRawDiagnosticBindings =
  drop 1 (legacyRawBindingOrder (map rawBinding canonicalLegacyUniverse))
#else
legacyRawDiagnosticBindings =
  legacyRawBindingOrder (map rawBinding canonicalLegacyUniverse)
#endif
 where
#if defined(VALIDATION_LEGACY_INTERNAL_RAW_BINDING_TUPLE_COMPOSITION_MUTANT)
  rawBinding identifier =
    ( projectRawBindingDisposition identifier
    , projectRawBindingId identifier
    , projectRawBindingOwner identifier
    , projectRawBindingAnalyzer identifier
    , projectRawBindingObservation identifier
    , projectRawBindingClosure identifier
    , projectRawBindingReintroduction identifier
    )
#else
  rawBinding identifier =
    ( projectRawBindingId identifier
    , projectRawBindingDisposition identifier
    , projectRawBindingOwner identifier
    , projectRawBindingAnalyzer identifier
    , projectRawBindingObservation identifier
    , projectRawBindingClosure identifier
    , projectRawBindingReintroduction identifier
    )
#endif

legacyRawBindingOrder
  :: [(Text, Text, Text, Text, Text, Text, [Text])]
  -> [(Text, Text, Text, Text, Text, Text, [Text])]
#if defined(VALIDATION_LEGACY_INTERNAL_RAW_BINDING_ORDER_MUTANT)
legacyRawBindingOrder = reverse
#else
legacyRawBindingOrder = id
#endif

projectRawBindingId :: LegacyId -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_RAW_BINDING_ID_ROUTE_MUTANT)
projectRawBindingId _ = "LTD-MUTATED"
#else
projectRawBindingId = renderLegacyId
#endif

projectRawBindingDisposition :: LegacyId -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_RAW_BINDING_DISPOSITION_ROUTE_MUTANT)
projectRawBindingDisposition identifier =
  Text.length (legacyDispositionText identifier) `seq` "Mutated"
#else
projectRawBindingDisposition = legacyDispositionText
#endif

projectRawBindingOwner :: LegacyId -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_RAW_BINDING_OWNER_ROUTE_MUTANT)
projectRawBindingOwner identifier =
  Text.length (renderTwoDigitOwner (Policy.phaseOrdinalNumber (legacyIdOwner identifier)))
    `seq` "xx"
#else
projectRawBindingOwner identifier = renderTwoDigitOwner (Policy.phaseOrdinalNumber (legacyIdOwner identifier))
#endif

projectRawBindingAnalyzer :: LegacyId -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_RAW_BINDING_ANALYZER_ROUTE_MUTANT)
projectRawBindingAnalyzer identifier =
  Text.length (renderLegacyAnalyzer (legacyIdAnalyzer identifier)) `seq` "mutated"
#else
projectRawBindingAnalyzer = renderLegacyAnalyzer . legacyIdAnalyzer
#endif

projectRawBindingObservation :: LegacyId -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_RAW_BINDING_OBSERVATION_ROUTE_MUTANT)
projectRawBindingObservation identifier =
  Text.length (renderLegacyObservationRule (legacyIdObservationRule identifier))
    `seq` "mutated"
#else
projectRawBindingObservation = renderLegacyObservationRule . legacyIdObservationRule
#endif

projectRawBindingClosure :: LegacyId -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_RAW_BINDING_CLOSURE_ROUTE_MUTANT)
projectRawBindingClosure identifier =
  Text.length (renderLegacyClosureRule (legacyIdClosureRule identifier)) `seq` "mutated"
#else
projectRawBindingClosure = renderLegacyClosureRule . legacyIdClosureRule
#endif

projectRawBindingReintroduction :: LegacyId -> [Text]
#if defined(VALIDATION_LEGACY_INTERNAL_RAW_BINDING_REINTRODUCTION_ROUTE_MUTANT)
projectRawBindingReintroduction identifier =
  length
    ( map renderLegacyReintroductionCase
        (toListNonEmpty (legacyIdReintroductionCases identifier))
    )
    `seq` ["mutated"]
#else
projectRawBindingReintroduction =
  map renderLegacyReintroductionCase
    . toListNonEmpty
    . legacyIdReintroductionCases
#endif

legacyRawDiagnosticJoins :: [(Text, Text)]
#if defined(VALIDATION_LEGACY_INTERNAL_RAW_JOIN_LIST_COMPOSITION_MUTANT)
legacyRawDiagnosticJoins =
  drop 1
    (legacyRawJoinOrder
      [ (projectRawJoinSource sourceId, projectRawJoinTarget sourceId)
      | sourceId <- sourceDebtUniverse
      ])
#else
legacyRawDiagnosticJoins =
  legacyRawJoinOrder
    [ (projectRawJoinSource sourceId, projectRawJoinTarget sourceId)
    | sourceId <- sourceDebtUniverse
    ]
#endif

legacyRawJoinOrder :: [(Text, Text)] -> [(Text, Text)]
#if defined(VALIDATION_LEGACY_INTERNAL_RAW_JOIN_ORDER_MUTANT)
legacyRawJoinOrder = reverse
#else
legacyRawJoinOrder = id
#endif

projectRawJoinSource :: SourceDebtId -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_RAW_JOIN_SOURCE_ROUTE_MUTANT)
projectRawJoinSource _ = "source-mutated"
#else
projectRawJoinSource = renderSourceDebtId
#endif

projectRawJoinTarget :: SourceDebtId -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_RAW_JOIN_TARGET_ROUTE_MUTANT)
projectRawJoinTarget _ = "LTD-MUTATED"
#else
projectRawJoinTarget = renderLegacyId . sourceDebtLegacyId
#endif

renderSourceDebtId :: SourceDebtId -> Text
renderSourceDebtId sourceId = case sourceId of
  SourceTools ->
#if defined(VALIDATION_LEGACY_JOIN_SOURCE_TOOLS_SOURCE_MUTANT)
    "source-toolx"
#else
    "source-tools"
#endif
  SourceDhall ->
#if defined(VALIDATION_LEGACY_JOIN_SOURCE_DHALL_SOURCE_MUTANT)
    "source-dhalx"
#else
    "source-dhall"
#endif
  SourceProto ->
#if defined(VALIDATION_LEGACY_JOIN_SOURCE_PROTO_SOURCE_MUTANT)
    "source-protx"
#else
    "source-proto"
#endif
  SourceUi ->
#if defined(VALIDATION_LEGACY_JOIN_SOURCE_UI_SOURCE_MUTANT)
    "source-ux"
#else
    "source-ui"
#endif
  SourcePulumi ->
#if defined(VALIDATION_LEGACY_JOIN_SOURCE_PULUMI_SOURCE_MUTANT)
    "source-pulumx"
#else
    "source-pulumi"
#endif
  SourceTest ->
#if defined(VALIDATION_LEGACY_JOIN_SOURCE_TEST_SOURCE_MUTANT)
    "source-tesx"
#else
    "source-test"
#endif
  SourceProbe ->
#if defined(VALIDATION_LEGACY_JOIN_SOURCE_PROBE_SOURCE_MUTANT)
    "source-probx"
#else
    "source-probe"
#endif
  SourcePb ->
#if defined(VALIDATION_LEGACY_JOIN_SOURCE_PB_SOURCE_MUTANT)
    "source-px"
#else
    "source-pb"
#endif
  SourceVendor ->
#if defined(VALIDATION_LEGACY_JOIN_SOURCE_VENDOR_SOURCE_MUTANT)
    "source-vendox"
#else
    "source-vendor"
#endif

legacyDispositionText :: LegacyId -> Text
legacyDispositionText identifier
  | legacyDispositionProjectionRetained identifier =
      renderLegacyDisposition (legacyIdDisposition identifier)
  | otherwise = "Activx"

legacyDispositionProjectionRetained :: LegacyId -> Bool
legacyDispositionProjectionRetained identifier = case identifier of
  LtdSrc000 ->
#if defined(VALIDATION_LEGACY_LTD_SRC000_DISPOSITION_MUTANT)
    False
#else
    True
#endif
  LtdSrc001 ->
#if defined(VALIDATION_LEGACY_LTD_SRC001_DISPOSITION_MUTANT)
    False
#else
    True
#endif
  LtdSrc002 ->
#if defined(VALIDATION_LEGACY_LTD_SRC002_DISPOSITION_MUTANT)
    False
#else
    True
#endif
  LtdSrc003 ->
#if defined(VALIDATION_LEGACY_LTD_SRC003_DISPOSITION_MUTANT)
    False
#else
    True
#endif
  LtdSrc004 ->
#if defined(VALIDATION_LEGACY_LTD_SRC004_DISPOSITION_MUTANT)
    False
#else
    True
#endif
  LtdSrc005 ->
#if defined(VALIDATION_LEGACY_LTD_SRC005_DISPOSITION_MUTANT)
    False
#else
    True
#endif
  LtdSrc006 ->
#if defined(VALIDATION_LEGACY_LTD_SRC006_DISPOSITION_MUTANT)
    False
#else
    True
#endif
  LtdSrc007 ->
#if defined(VALIDATION_LEGACY_LTD_SRC007_DISPOSITION_MUTANT)
    False
#else
    True
#endif
  LtdSrc008 ->
#if defined(VALIDATION_LEGACY_LTD_SRC008_DISPOSITION_MUTANT)
    False
#else
    True
#endif
  LtdSrc009 ->
#if defined(VALIDATION_LEGACY_LTD_SRC009_DISPOSITION_MUTANT)
    False
#else
    True
#endif
  LtdMeta001 ->
#if defined(VALIDATION_LEGACY_LTD_META001_DISPOSITION_MUTANT)
    False
#else
    True
#endif
  LtdVal001 ->
#if defined(VALIDATION_LEGACY_LTD_VAL001_DISPOSITION_MUTANT)
    False
#else
    True
#endif
  LtdVal002 ->
#if defined(VALIDATION_LEGACY_LTD_VAL002_DISPOSITION_MUTANT)
    False
#else
    True
#endif
  LtdVal003 ->
#if defined(VALIDATION_LEGACY_LTD_VAL003_DISPOSITION_MUTANT)
    False
#else
    True
#endif
  LtdVal004 ->
#if defined(VALIDATION_LEGACY_LTD_VAL004_DISPOSITION_MUTANT)
    False
#else
    True
#endif
  LtdVal005 ->
#if defined(VALIDATION_LEGACY_LTD_VAL005_DISPOSITION_MUTANT)
    False
#else
    True
#endif
  LtdVal006 ->
#if defined(VALIDATION_LEGACY_LTD_VAL006_DISPOSITION_MUTANT)
    False
#else
    True
#endif
  LtdDoc001 ->
#if defined(VALIDATION_LEGACY_LTD_DOC001_DISPOSITION_MUTANT)
    False
#else
    True
#endif
  LtdName001 ->
#if defined(VALIDATION_LEGACY_LTD_NAME001_DISPOSITION_MUTANT)
    False
#else
    True
#endif
  LtdHost001 ->
#if defined(VALIDATION_LEGACY_LTD_HOST001_DISPOSITION_MUTANT)
    False
#else
    True
#endif
  LtdHost002 ->
#if defined(VALIDATION_LEGACY_LTD_HOST002_DISPOSITION_MUTANT)
    False
#else
    True
#endif
  LtdImg001 ->
#if defined(VALIDATION_LEGACY_LTD_IMG001_DISPOSITION_MUTANT)
    False
#else
    True
#endif
  LtdRun001 ->
#if defined(VALIDATION_LEGACY_LTD_RUN001_DISPOSITION_MUTANT)
    False
#else
    True
#endif
  LtdSeed001 ->
#if defined(VALIDATION_LEGACY_LTD_SEED001_DISPOSITION_MUTANT)
    False
#else
    True
#endif
  LtdSeed002 ->
#if defined(VALIDATION_LEGACY_LTD_SEED002_DISPOSITION_MUTANT)
    False
#else
    True
#endif
  LtdBoot001 ->
#if defined(VALIDATION_LEGACY_LTD_BOOT001_DISPOSITION_MUTANT)
    False
#else
    True
#endif

renderTwoDigitOwner :: Int -> Text
renderTwoDigitOwner owner
  | owner < 10 =
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_OWNER_PREFIX_MUTANT)
      "x" <> showText owner
#else
      "0" <> showText owner
#endif
  | otherwise =
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_OWNER_PLAIN_MUTANT)
      "x" <> showText owner
#else
      showText owner
#endif

renderLegacyDisposition :: LegacyDisposition -> Text
renderLegacyDisposition LegacyActive =
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_DISPOSITION_ACTIVE_MUTANT)
  "Activx"
#else
  "Active"
#endif

renderLegacyAnalyzer :: LegacyAnalyzer -> Text
renderLegacyAnalyzer value = case value of
  AnalyzeCompleteSourceGrammar ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC000_ANALYZER_MUTANT)
    "complete-source-grammarx"
#else
    "complete-source-grammar"
#endif
  AnalyzeSourceTools ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC001_ANALYZER_MUTANT)
    "source-toolsx"
#else
    "source-tools"
#endif
  AnalyzeSourceDhall ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC002_ANALYZER_MUTANT)
    "source-dhallx"
#else
    "source-dhall"
#endif
  AnalyzeSourceProto ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC003_ANALYZER_MUTANT)
    "source-protox"
#else
    "source-proto"
#endif
  AnalyzeSourceUi ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC004_ANALYZER_MUTANT)
    "source-uix"
#else
    "source-ui"
#endif
  AnalyzeSourcePulumi ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC005_ANALYZER_MUTANT)
    "source-pulumix"
#else
    "source-pulumi"
#endif
  AnalyzeSourceTest ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC006_ANALYZER_MUTANT)
    "source-testx"
#else
    "source-test"
#endif
  AnalyzeSourceProbe ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC007_ANALYZER_MUTANT)
    "source-probex"
#else
    "source-probe"
#endif
  AnalyzeSourcePb ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC008_ANALYZER_MUTANT)
    "source-pbx"
#else
    "source-pb"
#endif
  AnalyzeSourceVendor ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC009_ANALYZER_MUTANT)
    "source-vendorx"
#else
    "source-vendor"
#endif
  AnalyzeRetiredIgnoreRules ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_META001_ANALYZER_MUTANT)
    "retired-ignore-rulesx"
#else
    "retired-ignore-rules"
#endif
  AnalyzeValidationProtocol ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL001_ANALYZER_MUTANT)
    "validation-protocolx"
#else
    "validation-protocol"
#endif
  AnalyzePhaseContracts ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL002_ANALYZER_MUTANT)
    "phase-contractsx"
#else
    "phase-contracts"
#endif
  AnalyzeStatusEvidence ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL003_ANALYZER_MUTANT)
    "status-evidencex"
#else
    "status-evidence"
#endif
  AnalyzeGateCompletion ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL004_ANALYZER_MUTANT)
    "gate-completionx"
#else
    "gate-completion"
#endif
  AnalyzeHardwareFreeDsl ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL005_ANALYZER_MUTANT)
    "hardware-free-dslx"
#else
    "hardware-free-dsl"
#endif
  AnalyzeRunInputClosure ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL006_ANALYZER_MUTANT)
    "run-input-closurex"
#else
    "run-input-closure"
#endif
  AnalyzeBehavioralDocumentConsumers ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_DOC001_ANALYZER_MUTANT)
    "behavioral-document-consumersx"
#else
    "behavioral-document-consumers"
#endif
  AnalyzePhaseOrdinalNames ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_NAME001_ANALYZER_MUTANT)
    "phase-ordinal-namesx"
#else
    "phase-ordinal-names"
#endif
  AnalyzeHostEnsure ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_HOST001_ANALYZER_MUTANT)
    "host-ensurex"
#else
    "host-ensure"
#endif
  AnalyzeAmbientHostPaths ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_HOST002_ANALYZER_MUTANT)
    "ambient-host-pathsx"
#else
    "ambient-host-paths"
#endif
  AnalyzeNaturalArchitectureImages ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_IMG001_ANALYZER_MUTANT)
    "natural-architecture-imagesx"
#else
    "natural-architecture-images"
#endif
  AnalyzeExecutableIdentity ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_RUN001_ANALYZER_MUTANT)
    "executable-identityx"
#else
    "executable-identity"
#endif
  AnalyzeInfernixSeedDependency ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SEED001_ANALYZER_MUTANT)
    "infernix-seed-dependencyx"
#else
    "infernix-seed-dependency"
#endif
  AnalyzeJitMlSeedDependency ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SEED002_ANALYZER_MUTANT)
    "jitml-seed-dependencyx"
#else
    "jitml-seed-dependency"
#endif
  AnalyzeBootstrapToolchain ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_BOOT001_ANALYZER_MUTANT)
    "bootstrap-toolchainx"
#else
    "bootstrap-toolchain"
#endif

renderLegacyObservationRule :: LegacyObservationRule -> Text
renderLegacyObservationRule value = case value of
  ObserveCompleteSourceSnapshot ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC000_OBSERVATION_MUTANT)
    "complete-source-snapshotx"
#else
    "complete-source-snapshot"
#endif
  ObserveSourceTools ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC001_OBSERVATION_MUTANT)
    "source-toolsx"
#else
    "source-tools"
#endif
  ObserveSourceDhall ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC002_OBSERVATION_MUTANT)
    "source-dhallx"
#else
    "source-dhall"
#endif
  ObserveSourceProto ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC003_OBSERVATION_MUTANT)
    "source-protox"
#else
    "source-proto"
#endif
  ObserveSourceUi ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC004_OBSERVATION_MUTANT)
    "source-uix"
#else
    "source-ui"
#endif
  ObserveSourcePulumi ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC005_OBSERVATION_MUTANT)
    "source-pulumix"
#else
    "source-pulumi"
#endif
  ObserveSourceTest ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC006_OBSERVATION_MUTANT)
    "source-testx"
#else
    "source-test"
#endif
  ObserveSourceProbe ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC007_OBSERVATION_MUTANT)
    "source-probex"
#else
    "source-probe"
#endif
  ObserveSourcePb ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC008_OBSERVATION_MUTANT)
    "source-pbx"
#else
    "source-pb"
#endif
  ObserveSourceVendor ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC009_OBSERVATION_MUTANT)
    "source-vendorx"
#else
    "source-vendor"
#endif
  ObserveParsedIgnoreGrammars ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_META001_OBSERVATION_MUTANT)
    "parsed-ignore-grammarsx"
#else
    "parsed-ignore-grammars"
#endif
  ObserveValidationGateGraph ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL001_OBSERVATION_MUTANT)
    "validation-gate-graphx"
#else
    "validation-gate-graph"
#endif
  ObserveTypedPhaseContractBinding ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL002_OBSERVATION_MUTANT)
    "typed-phase-contract-bindingx"
#else
    "typed-phase-contract-binding"
#endif
  ObserveStatusEvidenceProjection ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL003_OBSERVATION_MUTANT)
    "status-evidence-projectionx"
#else
    "status-evidence-projection"
#endif
  ObserveGateCompletionResult ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL004_OBSERVATION_MUTANT)
    "gate-completion-resultx"
#else
    "gate-completion-result"
#endif
  ObserveHardwareFreeDslTrace ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL005_OBSERVATION_MUTANT)
    "hardware-free-dsl-tracex"
#else
    "hardware-free-dsl-trace"
#endif
  ObserveRunInputProvenance ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL006_OBSERVATION_MUTANT)
    "run-input-provenancex"
#else
    "run-input-provenance"
#endif
  ObserveDocumentConsumerGraph ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_DOC001_OBSERVATION_MUTANT)
    "document-consumer-graphx"
#else
    "document-consumer-graph"
#endif
  ObserveRuntimeIdentityGraph ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_NAME001_OBSERVATION_MUTANT)
    "runtime-identity-graphx"
#else
    "runtime-identity-graph"
#endif
  ObserveHostEnsureCallGraph ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_HOST001_OBSERVATION_MUTANT)
    "host-ensure-call-graphx"
#else
    "host-ensure-call-graph"
#endif
  ObserveHostPathEffectGraph ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_HOST002_OBSERVATION_MUTANT)
    "host-path-effect-graphx"
#else
    "host-path-effect-graph"
#endif
  ObserveImagePlanAndBinfmt ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_IMG001_OBSERVATION_MUTANT)
    "image-plan-and-binfmtx"
#else
    "image-plan-and-binfmt"
#endif
  ObserveCabalExecutableGraph ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_RUN001_OBSERVATION_MUTANT)
    "cabal-executable-graphx"
#else
    "cabal-executable-graph"
#endif
  ObserveInfernixDependencyGraph ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SEED001_OBSERVATION_MUTANT)
    "infernix-dependency-graphx"
#else
    "infernix-dependency-graph"
#endif
  ObserveJitMlDependencyGraph ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SEED002_OBSERVATION_MUTANT)
    "jitml-dependency-graphx"
#else
    "jitml-dependency-graph"
#endif
  ObserveBootstrapToolchainProvenance ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_BOOT001_OBSERVATION_MUTANT)
    "bootstrap-toolchain-provenancex"
#else
    "bootstrap-toolchain-provenance"
#endif

renderLegacyClosureRule :: LegacyClosureRule -> Text
renderLegacyClosureRule value = case value of
  CloseCompleteSourceGrammar ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC000_CLOSURE_MUTANT)
    "complete-source-grammarx"
#else
    "complete-source-grammar"
#endif
  CloseSourceTools ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC001_CLOSURE_MUTANT)
    "source-toolsx"
#else
    "source-tools"
#endif
  CloseSourceDhall ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC002_CLOSURE_MUTANT)
    "source-dhallx"
#else
    "source-dhall"
#endif
  CloseSourceProto ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC003_CLOSURE_MUTANT)
    "source-protox"
#else
    "source-proto"
#endif
  CloseSourceUi ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC004_CLOSURE_MUTANT)
    "source-uix"
#else
    "source-ui"
#endif
  CloseSourcePulumi ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC005_CLOSURE_MUTANT)
    "source-pulumix"
#else
    "source-pulumi"
#endif
  CloseSourceTest ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC006_CLOSURE_MUTANT)
    "source-testx"
#else
    "source-test"
#endif
  CloseSourceProbe ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC007_CLOSURE_MUTANT)
    "source-probex"
#else
    "source-probe"
#endif
  CloseSourcePb ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC008_CLOSURE_MUTANT)
    "source-pbx"
#else
    "source-pb"
#endif
  CloseSourceVendor ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC009_CLOSURE_MUTANT)
    "source-vendorx"
#else
    "source-vendor"
#endif
  CloseRetiredIgnoreRules ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_META001_CLOSURE_MUTANT)
    "retired-ignore-rulesx"
#else
    "retired-ignore-rules"
#endif
  CloseValidationProtocol ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL001_CLOSURE_MUTANT)
    "validation-protocolx"
#else
    "validation-protocol"
#endif
  ClosePhaseContracts ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL002_CLOSURE_MUTANT)
    "phase-contractsx"
#else
    "phase-contracts"
#endif
  CloseStatusEvidence ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL003_CLOSURE_MUTANT)
    "status-evidencex"
#else
    "status-evidence"
#endif
  CloseGateCompletion ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL004_CLOSURE_MUTANT)
    "gate-completionx"
#else
    "gate-completion"
#endif
  CloseHardwareFreeDsl ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL005_CLOSURE_MUTANT)
    "hardware-free-dslx"
#else
    "hardware-free-dsl"
#endif
  CloseRunInputClosure ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL006_CLOSURE_MUTANT)
    "run-input-closurex"
#else
    "run-input-closure"
#endif
  CloseBehavioralDocumentConsumers ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_DOC001_CLOSURE_MUTANT)
    "behavioral-document-consumersx"
#else
    "behavioral-document-consumers"
#endif
  ClosePhaseOrdinalNames ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_NAME001_CLOSURE_MUTANT)
    "phase-ordinal-namesx"
#else
    "phase-ordinal-names"
#endif
  CloseHostEnsure ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_HOST001_CLOSURE_MUTANT)
    "host-ensurex"
#else
    "host-ensure"
#endif
  CloseAmbientHostPaths ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_HOST002_CLOSURE_MUTANT)
    "ambient-host-pathsx"
#else
    "ambient-host-paths"
#endif
  CloseNaturalArchitectureImages ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_IMG001_CLOSURE_MUTANT)
    "natural-architecture-imagesx"
#else
    "natural-architecture-images"
#endif
  CloseExecutableIdentity ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_RUN001_CLOSURE_MUTANT)
    "executable-identityx"
#else
    "executable-identity"
#endif
  CloseInfernixSeedDependency ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SEED001_CLOSURE_MUTANT)
    "infernix-seed-dependencyx"
#else
    "infernix-seed-dependency"
#endif
  CloseJitMlSeedDependency ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SEED002_CLOSURE_MUTANT)
    "jitml-seed-dependencyx"
#else
    "jitml-seed-dependency"
#endif
  CloseBootstrapToolchain ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_BOOT001_CLOSURE_MUTANT)
    "bootstrap-toolchainx"
#else
    "bootstrap-toolchain"
#endif

renderLegacyReintroductionCase :: LegacyReintroductionCase -> Text
renderLegacyReintroductionCase value = case value of
  RejectDisguisedOrConcealedSource ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC000_REINTRODUCTION_MUTANT)
    "reject-disguised-or-concealed-sourcex"
#else
    "reject-disguised-or-concealed-source"
#endif
  RejectTrackedToolsSource ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC001_REINTRODUCTION_MUTANT)
    "reject-tracked-tools-sourcex"
#else
    "reject-tracked-tools-source"
#endif
  RejectTrackedDhallOrTsv ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC002_REINTRODUCTION_MUTANT)
    "reject-tracked-dhall-or-tsvx"
#else
    "reject-tracked-dhall-or-tsv"
#endif
  RejectTrackedProto ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC003_REINTRODUCTION_MUTANT)
    "reject-tracked-protox"
#else
    "reject-tracked-proto"
#endif
  RejectTrackedUiSource ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC004_REINTRODUCTION_MUTANT)
    "reject-tracked-ui-sourcex"
#else
    "reject-tracked-ui-source"
#endif
  RejectTrackedPulumiSource ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC005_REINTRODUCTION_MUTANT)
    "reject-tracked-pulumi-sourcex"
#else
    "reject-tracked-pulumi-source"
#endif
  RejectTrackedBehavioralTestInput ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC006_REINTRODUCTION_MUTANT)
    "reject-tracked-behavioral-test-inputx"
#else
    "reject-tracked-behavioral-test-input"
#endif
  RejectTrackedProbeDebt ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC007_REINTRODUCTION_MUTANT)
    "reject-tracked-probe-debtx"
#else
    "reject-tracked-probe-debt"
#endif
  RejectWidenedPbBehavior ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC008_REINTRODUCTION_MUTANT)
    "reject-widened-pb-behaviorx"
#else
    "reject-widened-pb-behavior"
#endif
  RejectTopLevelVendorDebt ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC009_REINTRODUCTION_MUTANT)
    "reject-top-level-vendor-debtx"
#else
    "reject-top-level-vendor-debt"
#endif
  RejectRetiredIgnoreRule ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_META001_REINTRODUCTION_MUTANT)
    "reject-retired-ignore-rulex"
#else
    "reject-retired-ignore-rule"
#endif
  RejectNonHaskellValidationVerdict ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL001_REINTRODUCTION_MUTANT)
    "reject-non-haskell-validation-verdictx"
#else
    "reject-non-haskell-validation-verdict"
#endif
  RejectUnboundPhaseContract ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL002_REINTRODUCTION_MUTANT)
    "reject-unbound-phase-contractx"
#else
    "reject-unbound-phase-contract"
#endif
  RejectForgedStatusEvidence ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL003_REINTRODUCTION_MUTANT)
    "reject-forged-status-evidencex"
#else
    "reject-forged-status-evidence"
#endif
  RejectIncompleteGate ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL004_REINTRODUCTION_MUTANT)
    "reject-incomplete-gatex"
#else
    "reject-incomplete-gate"
#endif
  RejectHardwareBeforeDslGatePass ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL005_REINTRODUCTION_MUTANT)
    "reject-hardware-before-dsl-gate-passx"
#else
    "reject-hardware-before-dsl-gate-pass"
#endif
  RejectAmbientOrStaleRunInput ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL006_REINTRODUCTION_MUTANT)
    "reject-ambient-or-stale-run-inputx"
#else
    "reject-ambient-or-stale-run-input"
#endif
  RejectBehavioralMarkdownConsumer ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_DOC001_REINTRODUCTION_MUTANT)
    "reject-behavioral-markdown-consumerx"
#else
    "reject-behavioral-markdown-consumer"
#endif
  RejectRuntimePhaseOrdinal ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_NAME001_REINTRODUCTION_MUTANT)
    "reject-runtime-phase-ordinalx"
#else
    "reject-runtime-phase-ordinal"
#endif
  RejectBypassedHostEnsure ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_HOST001_REINTRODUCTION_MUTANT)
    "reject-bypassed-host-ensurex"
#else
    "reject-bypassed-host-ensure"
#endif
  RejectAmbientHostPath ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_HOST002_REINTRODUCTION_MUTANT)
    "reject-ambient-host-pathx"
#else
    "reject-ambient-host-path"
#endif
  RejectCrossArchitectureImagePlan ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_IMG001_REINTRODUCTION_MUTANT)
    "reject-cross-architecture-image-planx"
#else
    "reject-cross-architecture-image-plan"
#endif
  RejectSecondExecutableIdentity ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_RUN001_REINTRODUCTION_MUTANT)
    "reject-second-executable-identityx"
#else
    "reject-second-executable-identity"
#endif
  RejectInfernixSeedDependency ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SEED001_REINTRODUCTION_MUTANT)
    "reject-infernix-seed-dependencyx"
#else
    "reject-infernix-seed-dependency"
#endif
  RejectJitMlSeedDependency ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SEED002_REINTRODUCTION_MUTANT)
    "reject-jitml-seed-dependencyx"
#else
    "reject-jitml-seed-dependency"
#endif
  RejectUnverifiedBootstrapToolchain ->
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_LTD_BOOT001_REINTRODUCTION_MUTANT)
    "reject-unverified-bootstrap-toolchainx"
#else
    "reject-unverified-bootstrap-toolchain"
#endif

-- | A fixed, pure, standard-value projection of the genuine hidden parser,
-- lifecycle evaluator, source-debt dispatcher, structural register parser,
-- and diagnostic-evidence boundary.  The public facade may retain these
-- observations, but it cannot construct or recover any hidden value from
-- them and its result remains permanently refusing.
legacyInternalDiagnosticProjection :: [Observation]
legacyInternalDiagnosticProjection =
  legacyInternalProjectionOrder
    ( parserProjectionObservation
        <> inverseSourceDebtProjectionObservation
        <> routeUniversesProjectionObservation
        <> lifecycleProjectionObservation
        <> inventoryProjectionObservation
        <> bindingIntegrityProjectionObservation
        <> integrityMappingProjectionObservation
        <> registerProjectionObservation
        <> registerFindingProjectionObservation
        <> rawCheckProjectionObservation
        <> gateMappingProjectionObservation
        <> closedEvidenceIntegrityProjectionObservation
    )

legacyInternalProjectionOrder :: [Observation] -> [Observation]
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTION_ORDER_MUTANT)
legacyInternalProjectionOrder = reverse
#else
legacyInternalProjectionOrder = id
#endif

parserProjectionObservation :: [Observation]
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTION_PARSER_DROP_MUTANT)
parserProjectionObservation =
  parserProjectionKey `seq` Text.length parserProjection `seq` []
#else
parserProjectionObservation = [projectionObservation parserProjectionKey parserProjection]
#endif

parserProjectionKey :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTION_PARSER_KEY_MUTANT)
parserProjectionKey = "legacy.internal.mutated.sha256"
#else
parserProjectionKey = "legacy.internal.parser-wire.sha256"
#endif

inverseSourceDebtProjectionObservation :: [Observation]
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTION_INVERSE_SOURCE_DEBT_DROP_MUTANT)
inverseSourceDebtProjectionObservation =
  inverseSourceDebtProjectionKey `seq` Text.length inverseSourceDebtProjection `seq` []
#else
inverseSourceDebtProjectionObservation = [projectionObservation inverseSourceDebtProjectionKey inverseSourceDebtProjection]
#endif

inverseSourceDebtProjectionKey :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTION_INVERSE_SOURCE_DEBT_KEY_MUTANT)
inverseSourceDebtProjectionKey = "legacy.internal.mutated.sha256"
#else
inverseSourceDebtProjectionKey = "legacy.internal.inverse-source-debt-wire.sha256"
#endif

routeUniversesProjectionObservation :: [Observation]
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTION_ROUTE_UNIVERSES_DROP_MUTANT)
routeUniversesProjectionObservation =
  routeUniversesProjectionKey `seq` Text.length routeUniversesProjection `seq` []
#else
routeUniversesProjectionObservation = [projectionObservation routeUniversesProjectionKey routeUniversesProjection]
#endif

routeUniversesProjectionKey :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTION_ROUTE_UNIVERSES_KEY_MUTANT)
routeUniversesProjectionKey = "legacy.internal.mutated.sha256"
#else
routeUniversesProjectionKey = "legacy.internal.route-universes-wire.sha256"
#endif

lifecycleProjectionObservation :: [Observation]
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTION_LIFECYCLE_DROP_MUTANT)
lifecycleProjectionObservation =
  lifecycleProjectionKey `seq` Text.length lifecycleProjection `seq` []
#else
lifecycleProjectionObservation = [projectionObservation lifecycleProjectionKey lifecycleProjection]
#endif

lifecycleProjectionKey :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTION_LIFECYCLE_KEY_MUTANT)
lifecycleProjectionKey = "legacy.internal.mutated.sha256"
#else
lifecycleProjectionKey = "legacy.internal.lifecycle-wire.sha256"
#endif

inventoryProjectionObservation :: [Observation]
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTION_INVENTORY_DROP_MUTANT)
inventoryProjectionObservation =
  inventoryProjectionKey `seq` Text.length inventoryProjection `seq` []
#else
inventoryProjectionObservation = [projectionObservation inventoryProjectionKey inventoryProjection]
#endif

inventoryProjectionKey :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTION_INVENTORY_KEY_MUTANT)
inventoryProjectionKey = "legacy.internal.mutated.sha256"
#else
inventoryProjectionKey = "legacy.internal.inventory-wire.sha256"
#endif

bindingIntegrityProjectionObservation :: [Observation]
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTION_BINDING_INTEGRITY_DROP_MUTANT)
bindingIntegrityProjectionObservation =
  bindingIntegrityProjectionKey `seq` Text.length bindingIntegrityProjection `seq` []
#else
bindingIntegrityProjectionObservation = [projectionObservation bindingIntegrityProjectionKey bindingIntegrityProjection]
#endif

bindingIntegrityProjectionKey :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTION_BINDING_INTEGRITY_KEY_MUTANT)
bindingIntegrityProjectionKey = "legacy.internal.mutated.sha256"
#else
bindingIntegrityProjectionKey = "legacy.internal.binding-integrity-wire.sha256"
#endif

integrityMappingProjectionObservation :: [Observation]
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTION_INTEGRITY_MAPPING_DROP_MUTANT)
integrityMappingProjectionObservation =
  integrityMappingProjectionKey `seq` Text.length integrityMappingProjection `seq` []
#else
integrityMappingProjectionObservation = [projectionObservation integrityMappingProjectionKey integrityMappingProjection]
#endif

integrityMappingProjectionKey :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTION_INTEGRITY_MAPPING_KEY_MUTANT)
integrityMappingProjectionKey = "legacy.internal.mutated.sha256"
#else
integrityMappingProjectionKey = "legacy.internal.integrity-mapping-wire.sha256"
#endif

registerProjectionObservation :: [Observation]
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTION_REGISTER_DROP_MUTANT)
registerProjectionObservation =
  registerProjectionKey `seq` Text.length registerProjection `seq` []
#else
registerProjectionObservation = [projectionObservation registerProjectionKey registerProjection]
#endif

registerProjectionKey :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTION_REGISTER_KEY_MUTANT)
registerProjectionKey = "legacy.internal.mutated.sha256"
#else
registerProjectionKey = "legacy.internal.register-wire.sha256"
#endif

registerFindingProjectionObservation :: [Observation]
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTION_REGISTER_FINDING_DROP_MUTANT)
registerFindingProjectionObservation =
  registerFindingProjectionKey `seq` Text.length registerFindingProjection `seq` []
#else
registerFindingProjectionObservation = [projectionObservation registerFindingProjectionKey registerFindingProjection]
#endif

registerFindingProjectionKey :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTION_REGISTER_FINDING_KEY_MUTANT)
registerFindingProjectionKey = "legacy.internal.mutated.sha256"
#else
registerFindingProjectionKey = "legacy.internal.register-finding-wire.sha256"
#endif

rawCheckProjectionObservation :: [Observation]
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTION_RAW_CHECK_DROP_MUTANT)
rawCheckProjectionObservation =
  rawCheckProjectionKey `seq` Text.length rawCheckProjection `seq` []
#else
rawCheckProjectionObservation = [projectionObservation rawCheckProjectionKey rawCheckProjection]
#endif

rawCheckProjectionKey :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTION_RAW_CHECK_KEY_MUTANT)
rawCheckProjectionKey = "legacy.internal.mutated.sha256"
#else
rawCheckProjectionKey = "legacy.internal.raw-check-wire.sha256"
#endif

gateMappingProjectionObservation :: [Observation]
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTION_GATE_MAPPING_DROP_MUTANT)
gateMappingProjectionObservation =
  gateMappingProjectionKey `seq` Text.length gateMappingProjection `seq` []
#else
gateMappingProjectionObservation = [projectionObservation gateMappingProjectionKey gateMappingProjection]
#endif

gateMappingProjectionKey :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTION_GATE_MAPPING_KEY_MUTANT)
gateMappingProjectionKey = "legacy.internal.mutated.sha256"
#else
gateMappingProjectionKey = "legacy.internal.gate-mapping-wire.sha256"
#endif

closedEvidenceIntegrityProjectionObservation :: [Observation]
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTION_CLOSED_EVIDENCE_INTEGRITY_DROP_MUTANT)
closedEvidenceIntegrityProjectionObservation =
  closedEvidenceIntegrityProjectionKey `seq` Text.length closedEvidenceIntegrityProjection `seq` []
#else
closedEvidenceIntegrityProjectionObservation = [projectionObservation closedEvidenceIntegrityProjectionKey closedEvidenceIntegrityProjection]
#endif

closedEvidenceIntegrityProjectionKey :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTION_CLOSED_EVIDENCE_INTEGRITY_KEY_MUTANT)
closedEvidenceIntegrityProjectionKey = "legacy.internal.mutated.sha256"
#else
closedEvidenceIntegrityProjectionKey = "legacy.internal.closed-evidence-integrity-wire.sha256"
#endif

projectionObservation :: Text -> Text -> Observation
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTION_OBSERVATION_COMPOSITION_MUTANT)
projectionObservation key value = observation (projectionDigest key value) key
#else
projectionObservation key value = observation key (projectionDigest key value)
#endif

projectionDigest :: Text -> Text -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTION_DIGEST_COMPONENT_ORDER_MUTANT)
projectionDigest key value =
  Text.pack . show . Crypto.hashWith Crypto.SHA256 . ByteString.concat $
    projectionDigestDomain <> projectionDigestValue value <> projectionDigestKey key
#else
projectionDigest key value =
  Text.pack . show . Crypto.hashWith Crypto.SHA256 . ByteString.concat $
    projectionDigestDomain <> projectionDigestKey key <> projectionDigestValue value
#endif

projectionDigestDomain :: [ByteString]
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTION_DIGEST_DOMAIN_MUTANT)
projectionDigestDomain = ["amoebius-legacy-internal-projection-v0\0"]
#else
projectionDigestDomain = ["amoebius-legacy-internal-projection-v1\0"]
#endif

projectionDigestKey :: Text -> [ByteString]
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTION_DIGEST_KEY_DROP_MUTANT)
projectionDigestKey _ = []
#else
projectionDigestKey value = [TextEncoding.encodeUtf8 value, "\0"]
#endif

projectionDigestValue :: Text -> [ByteString]
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTION_DIGEST_VALUE_DROP_MUTANT)
projectionDigestValue _ = []
#else
projectionDigestValue value = [TextEncoding.encodeUtf8 value]
#endif

parserProjection :: Text
parserProjection =
  Text.concat
    [
#if defined(VALIDATION_LEGACY_INTERNAL_PARSER_PROJECTION_COMPONENT_ORDER_MUTANT)
      projectionFrame
          (maybe "rejected" renderLegacyId (parseLegacyId encoding))
        <> projectionFrame encoding
#else
      projectionFrame encoding
        <> projectionFrame
          (maybe "rejected" renderLegacyId (parseLegacyId encoding))
#endif
    | encoding <- parserProjectionEncodings <> ["LTD-SRC-00x"]
    ]

parserProjectionEncodings :: [Text]
#if defined(VALIDATION_LEGACY_INTERNAL_PARSER_PROJECTION_ORDER_MUTANT)
parserProjectionEncodings = reverse acceptedLegacyIdEncodings
#else
parserProjectionEncodings = acceptedLegacyIdEncodings
#endif

inverseSourceDebtProjection :: Text
inverseSourceDebtProjection =
  Text.concat
    [
#if defined(VALIDATION_LEGACY_INTERNAL_INVERSE_SOURCE_DEBT_PROJECTION_COMPONENT_ORDER_MUTANT)
      projectionFrame
          (maybe "none" renderSourceDebtId (legacySourceDebtId identifier))
        <> projectionFrame (renderLegacyId identifier)
#else
      projectionFrame (renderLegacyId identifier)
        <> projectionFrame
          (maybe "none" renderSourceDebtId (legacySourceDebtId identifier))
#endif
    | identifier <- canonicalLegacyUniverse
    ]

routeUniversesProjection :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_ROUTE_UNIVERSES_PROJECTION_ORDER_MUTANT)
routeUniversesProjection =
  projectionFrame
    (Text.intercalate "," (map renderLegacyId nonSourceLegacyUniverse))
    <> projectionFrame
      (Text.intercalate "," (map renderSourceDebtId sourceDebtUniverse))
    <> projectionFrame
      ("invalid-static-phase-fallback="
        <> showText (Policy.phaseOrdinalNumber (phaseOrdinal 96)))
#else
routeUniversesProjection =
  projectionFrame
    (Text.intercalate "," (map renderSourceDebtId sourceDebtUniverse))
    <> projectionFrame
      (Text.intercalate "," (map renderLegacyId nonSourceLegacyUniverse))
    <> projectionFrame
      ("invalid-static-phase-fallback="
        <> showText (Policy.phaseOrdinalNumber (phaseOrdinal 96)))
#endif

lifecycleProjection :: Text
lifecycleProjection = Text.concat (map renderScenario lifecycleProjectionScenarios)
 where
#if defined(VALIDATION_LEGACY_INTERNAL_LIFECYCLE_PROJECTION_COMPONENT_ORDER_MUTANT)
  renderScenario (label, result) = projectionFrame (renderProjectedCheck result) <> projectionFrame label
#else
  renderScenario (label, result) = projectionFrame label <> projectionFrame (renderProjectedCheck result)
#endif

lifecycleProjectionScenarios :: [(Text, CheckResult)]
#if defined(VALIDATION_LEGACY_INTERNAL_LIFECYCLE_PROJECTION_ORDER_MUTANT)
lifecycleProjectionScenarios = reverse lifecycleScenarios
#else
lifecycleProjectionScenarios = lifecycleScenarios
#endif

lifecycleScenarios :: [(Text, CheckResult)]
lifecycleScenarios =
  [ ("before-unavailable", diagnostic 46 Nothing)
  , ("at-unavailable", diagnostic 47 Nothing)
  , ("after-unavailable", diagnostic 48 Nothing)
  , ("before-zero", diagnostic 46 (Just (LegacyObservation AnalyzeSourceTools LegacyObservedZero)))
  , ("at-zero", diagnostic 47 (Just (LegacyObservation AnalyzeSourceTools LegacyObservedZero)))
  , ("after-zero", diagnostic 48 (Just (LegacyObservation AnalyzeSourceTools LegacyObservedZero)))
  , ("before-open", diagnostic 46 (Just (LegacyObservation AnalyzeSourceTools (LegacyObservedOpen 1 validProjectionDigest))))
  , ("at-open", diagnostic 47 (Just (LegacyObservation AnalyzeSourceTools (LegacyObservedOpen 1 validProjectionDigest))))
  , ("refused", diagnostic 47 (Just (LegacyObservation AnalyzeSourceTools (LegacyObservationRefused "owner refused"))))
  , ("analyzer-mismatch", diagnostic 47 (Just (LegacyObservation AnalyzeSourceDhall LegacyObservedZero)))
  , ("open-zero-count", diagnostic 47 (Just (LegacyObservation AnalyzeSourceTools (LegacyObservedOpen 0 validProjectionDigest))))
  , ("open-short-digest", diagnostic 47 (Just (LegacyObservation AnalyzeSourceTools (LegacyObservedOpen 1 "abc"))))
  , ("open-uppercase-digest", diagnostic 47 (Just (LegacyObservation AnalyzeSourceTools (LegacyObservedOpen 1 (Text.replicate 64 "A")))))
  , ("open-mixed-digest", diagnostic 47 (Just (LegacyObservation AnalyzeSourceTools (LegacyObservedOpen 1 (Text.replicate 63 "a" <> "g")))))
  , ("open-digit-lower-digest", diagnostic 47 (Just (LegacyObservation AnalyzeSourceTools (LegacyObservedOpen 1 (Text.replicate 64 "/")))))
  , ("open-digit-upper-digest", diagnostic 47 (Just (LegacyObservation AnalyzeSourceTools (LegacyObservedOpen 1 (Text.replicate 64 ":")))))
  , ("open-alpha-lower-digest", diagnostic 47 (Just (LegacyObservation AnalyzeSourceTools (LegacyObservedOpen 1 (Text.replicate 64 "`")))))
  , ("open-alpha-upper-digest", diagnostic 47 (Just (LegacyObservation AnalyzeSourceTools (LegacyObservedOpen 1 (Text.replicate 64 "g")))))
  , ("refused-empty", diagnostic 47 (Just (LegacyObservation AnalyzeSourceTools (LegacyObservationRefused ""))))
  ]
 where
  diagnostic phase supplied =
    evaluateLegacyObservationDiagnostic (phaseOrdinal phase) LtdSrc001 supplied

validProjectionDigest :: Text
validProjectionDigest = Text.replicate 64 "a"

inventoryProjection :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_INVENTORY_PROJECTION_ORDER_MUTANT)
inventoryProjection =
  projectionFrame "one-zero"
    <> projectionFrame
      ( renderProjectedCheck
          ( legacyInventoryDiagnostic
              (phaseOrdinal 47)
              (Map.singleton LtdSrc001 (LegacyObservation AnalyzeSourceTools LegacyObservedZero))
          )
      )
    <> projectionFrame "empty"
    <> projectionFrame (renderProjectedCheck (legacyInventoryDiagnostic (phaseOrdinal 0) Map.empty))
#else
inventoryProjection =
  projectionFrame "empty"
    <> projectionFrame (renderProjectedCheck (legacyInventoryDiagnostic (phaseOrdinal 0) Map.empty))
    <> projectionFrame "one-zero"
    <> projectionFrame
      ( renderProjectedCheck
          ( legacyInventoryDiagnostic
              (phaseOrdinal 47)
              (Map.singleton LtdSrc001 (LegacyObservation AnalyzeSourceTools LegacyObservedZero))
          )
      )
#endif

bindingIntegrityProjection :: Text
bindingIntegrityProjection =
  Text.concat
    [
#if defined(VALIDATION_LEGACY_INTERNAL_BINDING_INTEGRITY_PROJECTION_COMPONENT_ORDER_MUTANT)
      projectionFrame (renderProjectedCheck (evaluateCanonicalBinding (phaseOrdinal 47) binding Nothing))
        <> projectionFrame label
#else
      projectionFrame label
        <> projectionFrame (renderProjectedCheck (evaluateCanonicalBinding (phaseOrdinal 47) binding Nothing))
#endif
    | (label, binding) <- bindingIntegrityProjectionScenarios
    ]

bindingIntegrityProjectionScenarios :: [(Text, LegacyBinding)]
#if defined(VALIDATION_LEGACY_INTERNAL_BINDING_INTEGRITY_PROJECTION_ORDER_MUTANT)
bindingIntegrityProjectionScenarios = reverse bindingIntegrityScenarios
#else
bindingIntegrityProjectionScenarios = bindingIntegrityScenarios
#endif

bindingIntegrityScenarios :: [(Text, LegacyBinding)]
bindingIntegrityScenarios =
  [ ("owner-missing", canonical {legacyBindingOwner = BindingMissing})
  , ("owner-mismatch", canonical {legacyBindingOwner = BindingPresent (phaseOrdinal 48)})
  , ("analyzer-missing", canonical {legacyBindingAnalyzer = BindingMissing})
  , ("analyzer-mismatch", canonical {legacyBindingAnalyzer = BindingPresent AnalyzeSourceDhall})
  , ("observation-missing", canonical {legacyBindingObservation = BindingMissing})
  , ("observation-mismatch", canonical {legacyBindingObservation = BindingPresent ObserveSourceDhall})
  , ("closure-missing", canonical {legacyBindingClosure = BindingMissing})
  , ("closure-mismatch", canonical {legacyBindingClosure = BindingPresent CloseSourceDhall})
  , ("reintroduction-missing", canonical {legacyBindingReintroduction = BindingMissing})
  , ("reintroduction-mismatch", canonical {legacyBindingReintroduction = BindingPresent (RejectTrackedDhallOrTsv :| [])})
  , ( "all-bindings-missing"
    , canonical
        { legacyBindingOwner = BindingMissing
        , legacyBindingAnalyzer = BindingMissing
        , legacyBindingObservation = BindingMissing
        , legacyBindingClosure = BindingMissing
        , legacyBindingReintroduction = BindingMissing
        }
    )
  ]
 where
  canonical = legacyBinding LtdSrc001

integrityMappingProjection :: Text
integrityMappingProjection = integrityMappingProjectionComposition $
  projectionFrame "all-ids-negative-control"
    <> projectionFrame
      ( if legacyAllIdsInvalid (drop 1 canonicalLegacyUniverse) canonicalLegacyUniverse
          then "refused"
          else "accepted"
      )
    <> projectionFrame "binding-id-negative-control"
    <> projectionFrame
      ( if legacyBindingIdInvalid LtdSrc002 LtdSrc001
          then "refused"
          else "accepted"
      )
    <> projectionFrame "rendering-uniqueness-negative-control"
    <> projectionFrame
      ( if legacyRenderingsInvalid ["duplicate", "duplicate"]
          then "refused"
          else "accepted"
      )
    <> projectionFrame "parser-grammar-negative-control"
    <> projectionFrame
      ( if legacyParserGrammarInvalid Map.empty legacyIdDecoder canonicalLegacyUniverse
          then "refused"
          else "accepted"
      )
    <> projectionFrame "parser-cardinality-negative-control"
    <> projectionFrame
      ( if legacyParserGrammarInvalid
          legacyIdDecoder
          legacyIdDecoder
          (drop 1 canonicalLegacyUniverse)
          then "refused"
          else "accepted"
      )
    <> projectionFrame "closed-universe-negative-control"
    <> projectionFrame
      ( if closedUniverseInvalid
          [AnalyzeCompleteSourceGrammar]
          ([] :: [LegacyAnalyzer])
          then "refused"
          else "accepted"
      )
    <> projectionFrame "closed-universe-duplicate-negative-control"
    <> projectionFrame
      ( if closedUniverseInvalid
          [AnalyzeCompleteSourceGrammar, AnalyzeCompleteSourceGrammar]
          [AnalyzeCompleteSourceGrammar, AnalyzeCompleteSourceGrammar]
          then "refused"
          else "accepted"
      )
    <> projectionFrame "universe-integrity-composition-control"
    <> projectionFrame
      ( renderProjectedCheck
          ( CheckResult
              "legacy-universe-integrity-composition-control"
              []
              ( legacyUniverseIntegrityComposition
                  (legacyUniverseInventoryFindingRoute [finding "UNIVERSE" "universe" "universe"])
                  (legacyUniverseRenderingFindingRoute [finding "RENDERING" "rendering" "rendering"])
                  (legacyUniverseParserFindingRoute [finding "PARSER" "parser" "parser"])
                  (legacyUniverseBindingFindingRoute [finding "BINDING" "binding" "binding"])
                  (legacyUniverseClosedFindingRoute [finding "CLOSED" "closed" "closed"])
              )
          )
      )
    <> projectionFrame "evaluation-finding-composition-control"
    <> projectionFrame
      ( renderProjectedCheck
          ( CheckResult
              "legacy-evaluation-finding-composition-control"
              []
              ( legacyEvaluationFindingComposition
                  [finding "INTEGRITY" "integrity" "integrity"]
                  [finding "SEMANTIC" "semantic" "semantic"]
              )
          )
      )
    <> projectionFrame "inventory-finding-composition-control"
    <> projectionFrame
      ( renderProjectedCheck
          ( CheckResult
              "legacy-inventory-finding-composition-control"
              []
              ( legacyInventoryFindingComposition
                  [finding "INTEGRITY" "integrity" "integrity"]
                  [finding "EVALUATED" "evaluated" "evaluated"]
              )
          )
      )
    <> projectionFrame "candidate-finding-composition-control"
    <> projectionFrame
      ( renderProjectedCheck
          ( CheckResult
              "legacy-candidate-finding-composition-control"
              []
              ( legacyCandidateFindingComposition
                  [finding "UNIVERSE" "universe" "universe"]
                  [finding "EVIDENCE" "evidence" "evidence"]
                  [finding "EVALUATED" "evaluated" "evaluated"]
              )
          )
      )
    <> Text.concat
    [ projectionFrame (findingCode item)
        <> projectionFrame (Text.pack (findingSubject item))
        <> projectionFrame (findingDetail item)
    | item <-
        [ integrityFinding IntegrityIdInventory "LEGACY-ID-INVENTORY" legacySemanticSubject "id inventory"
        , integrityFinding IntegrityIdEncoding "LEGACY-ID-ENCODING" legacySemanticSubject "id encoding"
        , integrityFinding IntegrityParserGrammar "LEGACY-ID-PARSER-GRAMMAR" legacySemanticSubject "parser grammar"
        , integrityFinding IntegrityBindingId "LEGACY-BINDING-ID-MISMATCH" "binding" "binding id"
        , integrityFinding IntegrityAnalyzerInventory "LEGACY-ANALYZER-INVENTORY" legacySemanticSubject "analyzer inventory"
        , integrityFinding IntegrityObservationInventory "LEGACY-OBSERVATION-INVENTORY" legacySemanticSubject "observation inventory"
        , integrityFinding IntegrityClosureInventory "LEGACY-CLOSURE-INVENTORY" legacySemanticSubject "closure inventory"
        , integrityFinding IntegrityReintroductionInventory "LEGACY-REINTRODUCTION-INVENTORY" legacySemanticSubject "reintroduction inventory"
        ]
    ]

integrityMappingProjectionComposition :: Text -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_INTEGRITY_MAPPING_PROJECTION_COMPOSITION_MUTANT)
integrityMappingProjectionComposition = Text.reverse
#else
integrityMappingProjectionComposition = id
#endif

registerProjection :: Text
registerProjection =
  Text.concat
    [
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_PROJECTION_COMPONENT_ORDER_MUTANT)
      projectionFrame (renderRegisterOutcome outcome) <> projectionFrame label
#else
      projectionFrame label <> projectionFrame (renderRegisterOutcome outcome)
#endif
    | (label, outcome) <- registerProjectionScenarios
    ]

registerProjectionScenarios :: [(Text, Either [RegisterProblem] ActiveRegister)]
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_PROJECTION_ORDER_MUTANT)
registerProjectionScenarios = reverse registerScenarios
#else
registerProjectionScenarios = registerScenarios
#endif

registerScenarios :: [(Text, Either [RegisterProblem] ActiveRegister)]
registerScenarios =
  [ ("missing", activeRegisterFromSnapshot (projectionSnapshot []))
  , ("entry-count-maximum", activeRegisterFromSnapshot (projectionSnapshot (replicate 16384 projectionNonRegisterEntry)))
  , ("entry-count-maximum-plus-one", activeRegisterFromSnapshot (projectionSnapshot (replicate 16385 projectionNonRegisterEntry)))
  , ("path-bytes-maximum", activeRegisterFromSnapshot (projectionSnapshot [projectionEntry (replicate 1024 'p') RegularFile "path-max"]))
  , ("path-bytes-maximum-plus-one", activeRegisterFromSnapshot (projectionSnapshot [projectionEntry (replicate 1025 'p') RegularFile "path-over" ]))
  , ("path-two-byte-maximum", activeRegisterFromSnapshot (projectionSnapshot [projectionEntry (replicate 512 '\233') RegularFile "path-two-max"]))
  , ("path-two-byte-maximum-plus-one", activeRegisterFromSnapshot (projectionSnapshot [projectionEntry (replicate 512 '\233' <> "p") RegularFile "path-two-over"]))
  , ("path-three-byte-maximum", activeRegisterFromSnapshot (projectionSnapshot [projectionEntry (replicate 341 '\8364' <> "p") RegularFile "path-three-max"]))
  , ("path-three-byte-maximum-plus-one", activeRegisterFromSnapshot (projectionSnapshot [projectionEntry (replicate 341 '\8364' <> "pp") RegularFile "path-three-over"]))
  , ("path-four-byte-maximum", activeRegisterFromSnapshot (projectionSnapshot [projectionEntry (replicate 256 '\128512') RegularFile "path-four-max"]))
  , ("path-four-byte-maximum-plus-one", activeRegisterFromSnapshot (projectionSnapshot [projectionEntry (replicate 256 '\128512' <> "p") RegularFile "path-four-over"]))
  , ("regular", activeRegisterFromSnapshot (projectionSnapshot [projectionEntry canonicalRegisterPath RegularFile "ok"]))
  , ("register-bytes-maximum", activeRegisterFromSnapshot (projectionSnapshot [projectionByteEntry canonicalRegisterPath RegularFile (ByteString.replicate 1048576 97)]))
  , ("register-bytes-maximum-plus-one", activeRegisterFromSnapshot (projectionSnapshot [projectionByteEntry canonicalRegisterPath RegularFile (ByteString.replicate 1048577 97)]))
  , ("duplicate", activeRegisterFromSnapshot (projectionSnapshot [projectionEntry canonicalRegisterPath RegularFile "a", projectionEntry canonicalRegisterPath RegularFile "b"]))
  , ("alias", activeRegisterFromSnapshot (projectionSnapshot [projectionEntry canonicalRegisterPath RegularFile "ok", projectionEntry ("alias/" <> takeFileName canonicalRegisterPath) RegularFile "alias"]))
  , ( "entry-retention-order"
    , activeRegisterFromSnapshot
        ( projectionSnapshot
            [ projectionEntry ("alias-one/" <> takeFileName canonicalRegisterPath) RegularFile "first"
            , projectionEntry ("alias-two/" <> takeFileName canonicalRegisterPath) RegularFile "second"
            ]
        )
    )
  , ("unrelated-path", activeRegisterFromSnapshot (projectionSnapshot [projectionEntry canonicalRegisterPath RegularFile "ok", projectionEntry "unrelated/path" RegularFile "unrelated"]))
  , ("archive", activeRegisterFromSnapshot (projectionSnapshot [projectionEntry canonicalRegisterPath RegularFile "ok", projectionEntry ("archive/" <> archiveRegisterName) RegularFile "archive"]))
  , ( "problem-order"
    , activeRegisterFromSnapshot
        ( projectionSnapshot
            [ projectionEntry canonicalRegisterPath ExecutableFile "bad-mode"
            , projectionEntry ("alias/" <> takeFileName canonicalRegisterPath) RegularFile "alias"
            , projectionEntry ("archive/" <> archiveRegisterName) RegularFile "archive"
            ]
        )
    )
  , ("executable", activeRegisterFromSnapshot (projectionSnapshot [projectionEntry canonicalRegisterPath ExecutableFile "bad-mode"]))
  , ("symlink", activeRegisterFromSnapshot (projectionSnapshot [projectionEntry canonicalRegisterPath SymbolicLink "bad-mode"]))
  , ("invalid-utf8", activeRegisterFromSnapshot (projectionSnapshot [projectionByteEntry canonicalRegisterPath RegularFile (ByteString.pack [255])]))
  ]

projectionNonRegisterEntry :: TrackedEntry
projectionNonRegisterEntry = projectionEntry "bounded-entry" RegularFile "bounded"

projectionSnapshot :: [TrackedEntry] -> SourceSnapshot
projectionSnapshot entries = SourceSnapshot "/projection" "legacy-projection-snapshot" entries

projectionEntry :: FilePath -> IndexMode -> Text -> TrackedEntry
projectionEntry path mode bytes =
  projectionByteEntry path mode (TextEncoding.encodeUtf8 bytes)

projectionByteEntry :: FilePath -> IndexMode -> ByteString -> TrackedEntry
projectionByteEntry path mode bytes =
  TrackedEntry (IndexEntry path mode "legacy-projection-object") bytes

renderRegisterOutcome :: Either [RegisterProblem] ActiveRegister -> Text
renderRegisterOutcome outcome = case outcome of
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_OUTCOME_ROUTE_MUTANT)
  Left problems -> "accepted" <> Text.concat (map (projectionFrame . renderRegisterProblem) problems)
  Right register -> "refused" <> projectionFrame (Text.pack (activeRegisterPath register))
#else
  Left problems -> "refused" <> Text.concat (map (projectionFrame . renderRegisterProblem) problems)
  Right register -> "accepted" <> projectionFrame (Text.pack (activeRegisterPath register))
#endif

registerFindingProjection :: Text
registerFindingProjection =
  Text.concat
    [ registerFindingProjectionEntry item
    | item <- legacyRegisterMappingOrder legacyRegisterMappingEntries
    ]

legacyRegisterMappingEntries :: [Finding]
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_MAPPING_ENTRY_DROP_MUTANT)
legacyRegisterMappingEntries = drop 1 (map registerFinding registerMappingProblems)
#else
legacyRegisterMappingEntries = map registerFinding registerMappingProblems
#endif

legacyRegisterMappingOrder :: [Finding] -> [Finding]
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_MAPPING_ORDER_MUTANT)
legacyRegisterMappingOrder = reverse
#else
legacyRegisterMappingOrder = id
#endif

registerFindingProjectionEntry :: Finding -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_FINDING_PROJECTION_FIELD_ORDER_MUTANT)
registerFindingProjectionEntry item =
  projectionFrame (findingDetail item)
    <> projectionFrame (Text.pack (findingSubject item))
    <> projectionFrame (findingCode item)
#else
registerFindingProjectionEntry item =
  projectionFrame (findingCode item)
    <> projectionFrame (Text.pack (findingSubject item))
    <> projectionFrame (findingDetail item)
#endif

registerMappingProblems :: [RegisterProblem]
registerMappingProblems =
  [ RegisterEntryLimit 16384 16385
  , RegisterPathByteLimit 1 1024 1025
  , RegisterByteLimit 1048576 1048577
  , RegisterResourceGuardUnavailable "guard"
  , ActiveRegisterMissing "missing"
  , MultipleActiveRegisters "multiple" 2
  , AdditionalActiveRegisterTracked "additional"
  , ArchiveRegisterTracked "archive"
  , RegisterNotRegularFile "mode" ExecutableFile
  , RegisterNotUtf8 "utf8"
  ]

rawCheckProjection :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_RAW_CHECK_PROJECTION_COMPOSITION_MUTANT)
rawCheckProjection =
  Text.reverse
    ( renderProjectedCheck
        ( legacyCheck
            (phaseOrdinal 0)
            (projectionSnapshot [projectionEntry canonicalRegisterPath RegularFile "reader-facing text only"])
        )
    )
#else
rawCheckProjection =
  renderProjectedCheck
    ( legacyCheck
        (phaseOrdinal 0)
        (projectionSnapshot [projectionEntry canonicalRegisterPath RegularFile "reader-facing text only"])
    )
#endif

gateMappingProjection :: Text
gateMappingProjection = gateMappingProjectionComposition $
  projectionFrame (renderObservedState (legacyCompleteObservedState []))
    <> projectionFrame
      ( renderObservedState
          ( legacyCompleteObservedState
              ( legacyCompleteFindingOrder
                  [ finding "PROJECTION-A" "a" "a"
                  , finding "PROJECTION-B" "b" "b"
                  ]
              )
          )
      )
    <> projectionFrame
    (renderProjectedCheck (appendLegacySnapshotDiagnosticRefusal emptyProjectionCheck))
    <> projectionFrame "missing-owner-due-negative-control"
    <> projectionFrame
      ( if legacyObservationDue (phaseOrdinal 0) Nothing
          then "due"
          else "not-due"
      )
    <> projectionFrame "missing-owner-relation-negative-control"
    <> projectionFrame
      ( case compareOwner (phaseOrdinal 0) Nothing of
          OwnerBefore -> "before"
          OwnerAt -> "at"
          OwnerAfter -> "after"
      )
    <> projectionFrame
      ( renderProjectedCheck
          ( emptyProjectionCheck
              { checkFindings =
                  legacyCoreFindings
                    (CheckResult "semantic" [] [finding "SEMANTIC" "semantic" "semantic"])
                    [finding "STRUCTURAL" "structural" "structural"]
              }
          )
      )
    <> projectionFrame
      ( renderProjectedCheck
          ( appendCompilerSnapshotMismatchFinding
              "snapshot-a"
              "snapshot-b"
              emptyProjectionCheck
          )
      )
    <> projectionFrame "compiler-snapshot-finding-composition-control"
    <> projectionFrame
      ( renderProjectedCheck
          ( appendCompilerSnapshotMismatchFinding
              "snapshot-a"
              "snapshot-b"
              ( emptyProjectionCheck
                  { checkFindings = [finding "EXISTING" "existing" "existing"]
                  }
              )
          )
      )
    <> projectionFrame "missing-owner-render-control"
    <> projectionFrame (renderOwner Nothing)
    <> projectionFrame "raw-capture-result-control"
    <> projectionFrame
      (renderProjectedCheck (legacyRawCaptureUnavailable "projection"))
 where
  emptyProjectionCheck = CheckResult "legacy-gate-projection" [] []

gateMappingProjectionComposition :: Text -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_GATE_MAPPING_PROJECTION_COMPOSITION_MUTANT)
gateMappingProjectionComposition = Text.reverse
#else
gateMappingProjectionComposition = id
#endif

closedEvidenceIntegrityProjection :: Text
closedEvidenceIntegrityProjection =
  Text.concat
    [
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_PROJECTION_COMPONENT_ORDER_MUTANT)
      projectionFrame
          ( Text.concat
              [ closedEvidenceProjectionEntry item
              | item <- closedEvidenceIntegrityFindings projectionEvidenceSnapshot registry
              ]
          )
        <> projectionFrame label
#else
      projectionFrame label
        <> projectionFrame
          ( Text.concat
              [ closedEvidenceProjectionEntry item
              | item <- closedEvidenceIntegrityFindings projectionEvidenceSnapshot registry
              ]
          )
#endif
    | (label, registry) <- closedEvidenceIntegrityProjectionScenarios
    ]

closedEvidenceProjectionEntry :: Finding -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_PROJECTION_FIELD_ORDER_MUTANT)
closedEvidenceProjectionEntry item =
  projectionFrame (findingDetail item)
    <> projectionFrame (Text.pack (findingSubject item))
    <> projectionFrame (findingCode item)
#else
closedEvidenceProjectionEntry item =
  projectionFrame (findingCode item)
    <> projectionFrame (Text.pack (findingSubject item))
    <> projectionFrame (findingDetail item)
#endif

closedEvidenceIntegrityProjectionScenarios :: [(Text, Map LegacyId ClosedLegacyEvidence)]
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_PROJECTION_ORDER_MUTANT)
closedEvidenceIntegrityProjectionScenarios = reverse closedEvidenceIntegrityScenarios
#else
closedEvidenceIntegrityProjectionScenarios = closedEvidenceIntegrityScenarios
#endif

closedEvidenceIntegrityScenarios :: [(Text, Map LegacyId ClosedLegacyEvidence)]
closedEvidenceIntegrityScenarios =
  [ ("empty-registry", Map.empty)
  , ("id-mismatch", Map.singleton LtdSrc001 (canonicalEvidence {closedEvidenceId = LtdSrc002}))
  , ("source-debt-mismatch", Map.singleton LtdSrc001 (canonicalEvidence {closedEvidenceSourceDebtId = Just SourceDhall}))
  , ("analyzer-mismatch", Map.singleton LtdSrc001 (canonicalEvidence {closedEvidenceAnalyzer = AnalyzeSourceDhall}))
  , ("snapshot-mismatch", Map.singleton LtdSrc001 (canonicalEvidence {closedEvidenceSnapshot = "different"}))
  , ("observation-mismatch", Map.singleton LtdSrc001 (canonicalEvidence {closedEvidenceObservation = Just (LegacyObservation AnalyzeSourceDhall LegacyObservedZero)}))
  , ( "all-evidence-mismatches"
    , Map.singleton LtdSrc001
        ( canonicalEvidence
            { closedEvidenceId = LtdSrc002
            , closedEvidenceSourceDebtId = Just SourceDhall
            , closedEvidenceAnalyzer = AnalyzeSourceDhall
            , closedEvidenceSnapshot = "different"
            , closedEvidenceObservation = Just (LegacyObservation AnalyzeSourceTools LegacyObservedZero)
            }
        )
    )
  ]
 where
  canonicalEvidence =
    ClosedLegacyEvidence LtdSrc001 (Just SourceTools) AnalyzeSourceTools
      (snapshotIdentity projectionEvidenceSnapshot)
      (Just (LegacyObservation AnalyzeSourceTools LegacyObservedZero))
      Nothing

projectionEvidenceSnapshot :: SourceSnapshot
projectionEvidenceSnapshot = projectionSnapshot []

renderProjectedCheck :: CheckResult -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTED_CHECK_COMPONENT_ORDER_MUTANT)
renderProjectedCheck result =
  projectionFrame (projectedObservationCount result)
    <> projectionFrame (projectedCheckName result)
    <> Text.concat
      [ projectionFrame (projectedObservationKey item) <> projectionFrame (projectedObservationValue item)
      | item <- projectedObservationOrder (checkObservations result)
      ]
    <> projectionFrame (projectedFindingCount result)
    <> Text.concat
      [ projectionFrame (projectedFindingCode item)
          <> projectionFrame (projectedFindingSubject item)
          <> projectionFrame (projectedFindingDetail item)
      | item <- projectedFindingOrder (checkFindings result)
      ]
#else
renderProjectedCheck result =
  projectionFrame (projectedCheckName result)
    <> projectionFrame (projectedObservationCount result)
    <> Text.concat
      [ projectionFrame (projectedObservationKey item) <> projectionFrame (projectedObservationValue item)
      | item <- projectedObservationOrder (checkObservations result)
      ]
    <> projectionFrame (projectedFindingCount result)
    <> Text.concat
      [ projectionFrame (projectedFindingCode item)
          <> projectionFrame (projectedFindingSubject item)
          <> projectionFrame (projectedFindingDetail item)
      | item <- projectedFindingOrder (checkFindings result)
      ]
#endif

projectedCheckName :: CheckResult -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTED_CHECK_NAME_MUTANT)
projectedCheckName _ = "mutated"
#else
projectedCheckName = checkName
#endif

projectedObservationCount :: CheckResult -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTED_OBSERVATION_COUNT_MUTANT)
projectedObservationCount _ = "mutated"
#else
projectedObservationCount = Text.pack . show . length . checkObservations
#endif

projectedObservationOrder :: [Observation] -> [Observation]
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTED_OBSERVATION_ORDER_MUTANT)
projectedObservationOrder = reverse
#else
projectedObservationOrder = id
#endif

projectedObservationKey, projectedObservationValue :: Observation -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTED_OBSERVATION_KEY_MUTANT)
projectedObservationKey item = Text.length (observationKey item) `seq` "mutated"
#else
projectedObservationKey = observationKey
#endif
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTED_OBSERVATION_VALUE_MUTANT)
projectedObservationValue item = Text.length (observationValue item) `seq` "mutated"
#else
projectedObservationValue = observationValue
#endif

projectedFindingCount :: CheckResult -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTED_FINDING_COUNT_MUTANT)
projectedFindingCount _ = "mutated"
#else
projectedFindingCount = Text.pack . show . length . checkFindings
#endif

projectedFindingOrder :: [Finding] -> [Finding]
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTED_FINDING_ORDER_MUTANT)
projectedFindingOrder = reverse
#else
projectedFindingOrder = id
#endif

projectedFindingCode :: Finding -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTED_FINDING_CODE_MUTANT)
projectedFindingCode _ = "mutated"
#else
projectedFindingCode = findingCode
#endif

projectedFindingSubject :: Finding -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTED_FINDING_SUBJECT_MUTANT)
projectedFindingSubject _ = "mutated"
#else
projectedFindingSubject = Text.pack . findingSubject
#endif

projectedFindingDetail :: Finding -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTED_FINDING_DETAIL_MUTANT)
projectedFindingDetail _ = "mutated"
#else
projectedFindingDetail = findingDetail
#endif

projectionFrame :: Text -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTION_FRAME_COMPONENT_ORDER_MUTANT)
projectionFrame value =
  projectionFrameValue value <> projectionFrameSeparator <> projectionFrameLength value
#else
projectionFrame value =
  projectionFrameLength value <> projectionFrameSeparator <> projectionFrameValue value
#endif

projectionFrameLength :: Text -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTION_FRAME_LENGTH_MUTANT)
projectionFrameLength value = Text.pack (show (ByteString.length (TextEncoding.encodeUtf8 value) + 1))
#else
projectionFrameLength value = Text.pack (show (ByteString.length (TextEncoding.encodeUtf8 value)))
#endif

projectionFrameSeparator :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTION_FRAME_SEPARATOR_MUTANT)
projectionFrameSeparator = "|"
#else
projectionFrameSeparator = ":"
#endif

projectionFrameValue :: Text -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_PROJECTION_FRAME_VALUE_DROP_MUTANT)
projectionFrameValue _ = ""
#else
projectionFrameValue = id
#endif

legacyBinding :: LegacyId -> LegacyBinding
legacyBinding identifier =
  LegacyBinding
    { legacyBindingId = legacyBindingIdRoute identifier
    , legacyBindingDisposition = legacyBindingDispositionRoute identifier
    , legacyBindingOwner = legacyBindingOwnerRoute identifier
    , legacyBindingAnalyzer = legacyBindingAnalyzerRoute identifier
    , legacyBindingObservation = legacyBindingObservationRoute identifier
    , legacyBindingClosure = legacyBindingClosureRoute identifier
    , legacyBindingReintroduction = legacyBindingReintroductionRoute identifier
    }

legacyBindingDispositionRoute :: LegacyId -> LegacyDisposition
legacyBindingDispositionRoute = legacyIdDisposition

legacyBindingIdRoute :: LegacyId -> LegacyId
#if defined(VALIDATION_LEGACY_INTERNAL_BINDING_ID_ROUTE_MUTANT)
legacyBindingIdRoute _ = LtdSrc000
#else
legacyBindingIdRoute = id
#endif

legacyBindingOwnerRoute :: LegacyId -> BindingSlot Policy.PhaseOrdinal
#if defined(VALIDATION_LEGACY_INTERNAL_BINDING_OWNER_ROUTE_MUTANT)
legacyBindingOwnerRoute identifier =
  ownerSlot identifier `seq` BindingPresent (phaseOrdinal 95)
#else
legacyBindingOwnerRoute = ownerSlot
#endif

legacyBindingAnalyzerRoute :: LegacyId -> BindingSlot LegacyAnalyzer
#if defined(VALIDATION_LEGACY_INTERNAL_BINDING_ANALYZER_ROUTE_MUTANT)
legacyBindingAnalyzerRoute identifier =
  analyzerSlot identifier `seq` BindingPresent AnalyzeCompleteSourceGrammar
#else
legacyBindingAnalyzerRoute = analyzerSlot
#endif

legacyBindingObservationRoute :: LegacyId -> BindingSlot LegacyObservationRule
#if defined(VALIDATION_LEGACY_INTERNAL_BINDING_OBSERVATION_ROUTE_MUTANT)
legacyBindingObservationRoute identifier =
  observationSlot identifier `seq` BindingPresent ObserveCompleteSourceSnapshot
#else
legacyBindingObservationRoute = observationSlot
#endif

legacyBindingClosureRoute :: LegacyId -> BindingSlot LegacyClosureRule
#if defined(VALIDATION_LEGACY_INTERNAL_BINDING_CLOSURE_ROUTE_MUTANT)
legacyBindingClosureRoute identifier =
  closureSlot identifier `seq` BindingPresent CloseCompleteSourceGrammar
#else
legacyBindingClosureRoute = closureSlot
#endif

legacyBindingReintroductionRoute :: LegacyId -> BindingSlot (NonEmpty LegacyReintroductionCase)
#if defined(VALIDATION_LEGACY_INTERNAL_BINDING_REINTRODUCTION_ROUTE_MUTANT)
legacyBindingReintroductionRoute identifier =
  reintroductionSlot identifier `seq`
    BindingPresent (RejectDisguisedOrConcealedSource :| [])
#else
legacyBindingReintroductionRoute = reintroductionSlot
#endif

ownerSlot :: LegacyId -> BindingSlot Policy.PhaseOrdinal
#if defined(VALIDATION_LEGACY_INTERNAL_OWNER_SLOT_MISSING_MUTANT)
ownerSlot _ = BindingMissing
#else
ownerSlot identifier =
  BindingPresent (legacyIdOwner identifier)
#endif

analyzerSlot :: LegacyId -> BindingSlot LegacyAnalyzer
#if defined(VALIDATION_LEGACY_INTERNAL_ANALYZER_SLOT_MISSING_MUTANT)
analyzerSlot _ = BindingMissing
#else
analyzerSlot identifier =
  BindingPresent (legacyIdAnalyzer identifier)
#endif

observationSlot :: LegacyId -> BindingSlot LegacyObservationRule
#if defined(VALIDATION_LEGACY_INTERNAL_OBSERVATION_SLOT_MISSING_MUTANT)
observationSlot _ = BindingMissing
#else
observationSlot identifier =
  BindingPresent (legacyIdObservationRule identifier)
#endif

closureSlot :: LegacyId -> BindingSlot LegacyClosureRule
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSURE_SLOT_MISSING_MUTANT)
closureSlot _ = BindingMissing
#else
closureSlot identifier =
  BindingPresent (legacyIdClosureRule identifier)
#endif

reintroductionSlot :: LegacyId -> BindingSlot (NonEmpty LegacyReintroductionCase)
#if defined(VALIDATION_LEGACY_INTERNAL_REINTRODUCTION_SLOT_MISSING_MUTANT)
reintroductionSlot _ = BindingMissing
#else
reintroductionSlot identifier =
  BindingPresent (legacyIdReintroductionCases identifier)
#endif

-- | Exercise the lifecycle model with caller-supplied data.  This seam is a
-- component diagnostic only: it always carries an explicit refusal and is
-- never called by 'legacyCheck'.  Candidate evaluation accepts only opaque
-- 'ClosedLegacyEvidence' produced by the closed analyzer dispatcher below.
evaluateLegacyObservationDiagnostic :: Policy.PhaseOrdinal -> LegacyId -> Maybe LegacyObservation -> CheckResult
#if defined(VALIDATION_LEGACY_INTERNAL_EVALUATE_DIAGNOSTIC_REFUSAL_COMPOSITION_MUTANT)
evaluateLegacyObservationDiagnostic candidatePhase identifier supplied =
  appendDiagnosticRefusal (evaluateCanonicalBinding candidatePhase (legacyBinding identifier) supplied)
    { checkFindings = [] }
#else
evaluateLegacyObservationDiagnostic candidatePhase identifier supplied =
  appendDiagnosticRefusal (evaluateCanonicalBinding candidatePhase (legacyBinding identifier) supplied)
#endif

evaluateCanonicalBinding :: Policy.PhaseOrdinal -> LegacyBinding -> Maybe LegacyObservation -> CheckResult
evaluateCanonicalBinding candidatePhase binding supplied =
  CheckResult
    { checkName = legacyBindingResultName
    , checkObservations =
        [ observation
            (legacyBindingObservationKey identifier)
            (legacyBindingObservationValue expectedAnalyzer supplied)
        ]
    , checkFindings = legacyEvaluationFindingComposition integrityFindings semanticFindings
    }
 where
  identifier = legacyBindingId binding
  subject = legacySubject identifier
  expectedAnalyzer = legacyIdAnalyzer identifier
  integrityFindings =
    bindingIntegrityFindings binding
      <> analyzerIdentityFindings
      <> maybe [] (observedStateIntegrityFindings subject identifier . legacyObservationState) supplied
  ownerOrdinal = slotValue (legacyBindingOwner binding)
  ownerNumber = Policy.phaseOrdinalNumber <$> ownerOrdinal
  due = legacyObservationDue candidatePhase ownerOrdinal
  analyzerIdentityFindings = case supplied of
    Just actual
      | legacyAnalyzerIdentityMismatch (legacyObservationAnalyzer actual) expectedAnalyzer ->
          [ lifecycleFinding
              LifecycleAnalyzerMismatch
              subject
              ( renderLegacyId identifier
                  <> " requires "
                  <> showText expectedAnalyzer
                  <> " but the supplied observation names "
                  <> showText (legacyObservationAnalyzer actual)
              )
          ]
    _ -> []
  semanticFindings
    | not (legacyIntegrityClear integrityFindings) = []
    | otherwise = case supplied of
        Nothing -> unavailableFindings
        Just report -> case legacyObservationState report of
          LegacyObservedZero -> case zeroOwnerRelation candidatePhase ownerOrdinal of
            OwnerBefore ->
              [ lifecycleFinding
                  LifecycleActiveFindingMissing
                  subject
                  ( renderLegacyId identifier
                      <> " is Active before owner Phase "
                      <> renderOwner ownerNumber
                      <> " but its observer reports zero; the exact later-owned finding is stale or missing"
                  )
              ]
            OwnerAt -> []
            OwnerAfter ->
              [ lifecycleFinding
                  LifecycleActiveTransitionUnrecorded
                  subject
                  ( renderLegacyId identifier
                      <> " is still Active after owner Phase "
                      <> renderOwner ownerNumber
                      <> "; the owning candidate's zero observation did not receive a compiled post-pass retirement transition"
                  )
              ]
          LegacyObservedOpen count digest
            | due ->
              [ lifecycleFinding
                  LifecycleOwnerDue
                  subject
                  ( renderLegacyId identifier
                      <> " remains open at owner Phase "
                      <> renderOwner ownerNumber
                      <> "; count="
                      <> showText count
                      <> " digest="
                      <> digest
                  )
              ]
            | otherwise -> []
          LegacyObservationRefused detail ->
            [lifecycleFinding LifecycleObservationRefused subject (renderLegacyId identifier <> ": " <> detail)]
  unavailableFindings
    | due =
        [ lifecycleFinding
            LifecycleAnalyzerUnavailable
            subject
            ( renderLegacyId identifier
                <> " requires "
                <> showText expectedAnalyzer
                <> " at owner Phase "
                <> renderOwner ownerNumber
                <> "; no typed raw observation was supplied"
            )
        ]
    | otherwise = []

legacyEvaluationFindingComposition :: [Finding] -> [Finding] -> [Finding]
#if defined(VALIDATION_LEGACY_INTERNAL_EVALUATION_FINDING_ORDER_MUTANT)
legacyEvaluationFindingComposition integrity semantic = semantic <> integrity
#else
legacyEvaluationFindingComposition integrity semantic = integrity <> semantic
#endif

legacyBindingResultName :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_BINDING_RESULT_NAME_MUTANT)
legacyBindingResultName = "legacy-binding-mutated"
#else
legacyBindingResultName = "legacy-binding"
#endif

legacyBindingObservationKey :: LegacyId -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_BINDING_OBSERVATION_KEY_MUTANT)
legacyBindingObservationKey _ = "legacy.binding.mutated"
#else
legacyBindingObservationKey identifier = "legacy.binding." <> renderLegacyId identifier
#endif

legacyBindingObservationValue :: LegacyAnalyzer -> Maybe LegacyObservation -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_BINDING_OBSERVATION_VALUE_MUTANT)
legacyBindingObservationValue expectedAnalyzer supplied =
  Text.length (renderLegacyObservation expectedAnalyzer supplied) `seq` "mutated"
#else
legacyBindingObservationValue = renderLegacyObservation
#endif

legacyAnalyzerIdentityMismatch :: LegacyAnalyzer -> LegacyAnalyzer -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_ANALYZER_IDENTITY_MATCH_BYPASS_MUTANT)
legacyAnalyzerIdentityMismatch _ _ = False
#else
legacyAnalyzerIdentityMismatch actual expected = actual /= expected
#endif

legacyIntegrityClear :: [Finding] -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_INTEGRITY_GATE_BYPASS_MUTANT)
legacyIntegrityClear _ = True
#else
legacyIntegrityClear = null
#endif

legacyObservationDue :: Policy.PhaseOrdinal -> Maybe Policy.PhaseOrdinal -> Bool
legacyObservationDue candidatePhase ownerOrdinal = case ownerOrdinal of
  Nothing ->
#if defined(VALIDATION_LEGACY_INTERNAL_DUE_MISSING_OWNER_BYPASS_MUTANT)
    False
#else
    True
#endif
  Just owner ->
#if defined(VALIDATION_LEGACY_INTERNAL_DUE_COMPARISON_MUTANT)
    owner < candidatePhase
#else
    owner <= candidatePhase
#endif

data LifecycleFindingKind
  = LifecycleAnalyzerMismatch
  | LifecycleActiveFindingMissing
  | LifecycleActiveTransitionUnrecorded
  | LifecycleOwnerDue
  | LifecycleObservationRefused
  | LifecycleAnalyzerUnavailable

lifecycleFinding :: LifecycleFindingKind -> FilePath -> Text -> Finding
#if defined(VALIDATION_LEGACY_INTERNAL_LIFECYCLE_FINDING_COMPOSITION_MUTANT)
lifecycleFinding kind subject detail =
  finding (lifecycleFindingDetail kind detail) (lifecycleFindingSubject kind subject) (lifecycleFindingCode kind)
#else
lifecycleFinding kind subject detail =
  finding (lifecycleFindingCode kind) (lifecycleFindingSubject kind subject) (lifecycleFindingDetail kind detail)
#endif

lifecycleFindingCode :: LifecycleFindingKind -> Text
lifecycleFindingCode kind = case kind of
  LifecycleAnalyzerMismatch ->
#if defined(VALIDATION_LEGACY_INTERNAL_ANALYZER_MISMATCH_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-OBSERVATION-ANALYZER-MISMATCH"
#endif
  LifecycleActiveFindingMissing ->
#if defined(VALIDATION_LEGACY_INTERNAL_ACTIVE_MISSING_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-ACTIVE-FINDING-MISSING"
#endif
  LifecycleActiveTransitionUnrecorded ->
#if defined(VALIDATION_LEGACY_INTERNAL_TRANSITION_UNRECORDED_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-ACTIVE-TRANSITION-UNRECORDED"
#endif
  LifecycleOwnerDue ->
#if defined(VALIDATION_LEGACY_INTERNAL_OWNER_DUE_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-OWNER-DUE"
#endif
  LifecycleObservationRefused ->
#if defined(VALIDATION_LEGACY_INTERNAL_OBSERVATION_REFUSED_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-OBSERVATION-REFUSED"
#endif
  LifecycleAnalyzerUnavailable ->
#if defined(VALIDATION_LEGACY_INTERNAL_ANALYZER_UNAVAILABLE_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-ANALYZER-UNAVAILABLE"
#endif

lifecycleFindingSubject :: LifecycleFindingKind -> FilePath -> FilePath
lifecycleFindingSubject kind subject = case kind of
  LifecycleAnalyzerMismatch ->
#if defined(VALIDATION_LEGACY_INTERNAL_ANALYZER_MISMATCH_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  LifecycleActiveFindingMissing ->
#if defined(VALIDATION_LEGACY_INTERNAL_ACTIVE_MISSING_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  LifecycleActiveTransitionUnrecorded ->
#if defined(VALIDATION_LEGACY_INTERNAL_TRANSITION_UNRECORDED_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  LifecycleOwnerDue ->
#if defined(VALIDATION_LEGACY_INTERNAL_OWNER_DUE_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  LifecycleObservationRefused ->
#if defined(VALIDATION_LEGACY_INTERNAL_OBSERVATION_REFUSED_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  LifecycleAnalyzerUnavailable ->
#if defined(VALIDATION_LEGACY_INTERNAL_ANALYZER_UNAVAILABLE_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif

lifecycleFindingDetail :: LifecycleFindingKind -> Text -> Text
lifecycleFindingDetail kind detail = case kind of
  LifecycleAnalyzerMismatch ->
#if defined(VALIDATION_LEGACY_INTERNAL_ANALYZER_MISMATCH_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  LifecycleActiveFindingMissing ->
#if defined(VALIDATION_LEGACY_INTERNAL_ACTIVE_MISSING_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  LifecycleActiveTransitionUnrecorded ->
#if defined(VALIDATION_LEGACY_INTERNAL_TRANSITION_UNRECORDED_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  LifecycleOwnerDue ->
#if defined(VALIDATION_LEGACY_INTERNAL_OWNER_DUE_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  LifecycleObservationRefused ->
#if defined(VALIDATION_LEGACY_INTERNAL_OBSERVATION_REFUSED_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  LifecycleAnalyzerUnavailable ->
#if defined(VALIDATION_LEGACY_INTERNAL_ANALYZER_UNAVAILABLE_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif

data OwnerRelation
  = OwnerBefore
  | OwnerAt
  | OwnerAfter
  deriving (Eq)

compareOwner :: Policy.PhaseOrdinal -> Maybe Policy.PhaseOrdinal -> OwnerRelation
compareOwner _ Nothing =
#if defined(VALIDATION_LEGACY_INTERNAL_COMPARE_OWNER_MISSING_MUTANT)
  OwnerBefore
#else
  OwnerAfter
#endif
compareOwner candidatePhase (Just ownerPhase) = case compare candidatePhase ownerPhase of
  LT ->
#if defined(VALIDATION_LEGACY_INTERNAL_COMPARE_OWNER_LT_MUTANT)
    OwnerAt
#else
    OwnerBefore
#endif
  EQ ->
#if defined(VALIDATION_LEGACY_INTERNAL_COMPARE_OWNER_EQ_MUTANT)
    OwnerBefore
#else
    OwnerAt
#endif
  GT ->
#if defined(VALIDATION_LEGACY_INTERNAL_COMPARE_OWNER_GT_MUTANT)
    OwnerAt
#else
    OwnerAfter
#endif

zeroOwnerRelation :: Policy.PhaseOrdinal -> Maybe Policy.PhaseOrdinal -> OwnerRelation
#if defined(VALIDATION_LEGACY_INTERNAL_ZERO_OWNER_ROUTE_MUTANT)
zeroOwnerRelation _ _ = OwnerAt
#else
zeroOwnerRelation = compareOwner
#endif

observedStateIntegrityFindings :: FilePath -> LegacyId -> LegacyObservedState -> [Finding]
observedStateIntegrityFindings subject identifier state = case state of
  LegacyObservedZero -> []
  LegacyObservedOpen count digest ->
#if defined(VALIDATION_LEGACY_INTERNAL_OBSERVED_OPEN_ROUTE_MUTANT)
    let findings =
          [ malformedObservationFinding
              subject
              (renderLegacyId identifier <> " open observation requires a positive count and a 64-character lowercase hexadecimal digest")
          | legacyOpenObservationMalformed count digest
          ]
     in length findings `seq` []
#else
    [ malformedObservationFinding
        subject
        (renderLegacyId identifier <> " open observation requires a positive count and a 64-character lowercase hexadecimal digest")
    | legacyOpenObservationMalformed count digest
    ]
#endif
  LegacyObservationRefused detail ->
#if defined(VALIDATION_LEGACY_INTERNAL_OBSERVED_REFUSAL_ROUTE_MUTANT)
    let findings =
          [ malformedObservationFinding subject
              (renderLegacyId identifier <> " refused observation requires non-empty detail")
          | legacyRefusalDetailMissing detail
          ]
     in length findings `seq` []
#else
    [ malformedObservationFinding subject
        (renderLegacyId identifier <> " refused observation requires non-empty detail")
    | legacyRefusalDetailMissing detail
    ]
#endif

legacyOpenCountInvalid :: Int -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_OPEN_COUNT_PREDICATE_BYPASS_MUTANT)
legacyOpenCountInvalid _ = False
#else
legacyOpenCountInvalid count = count <= 0
#endif

legacyRefusalDetailMissing :: Text -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_REFUSAL_DETAIL_PREDICATE_BYPASS_MUTANT)
legacyRefusalDetailMissing _ = False
#else
legacyRefusalDetailMissing = Text.null
#endif

legacyOpenObservationMalformed :: Int -> Text -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_OPEN_OBSERVATION_COMPOSITION_MUTANT)
legacyOpenObservationMalformed count digest =
  legacyOpenCountInvalid count && not (isLowerHexDigest digest)
#else
legacyOpenObservationMalformed count digest =
  legacyOpenCountInvalid count || not (isLowerHexDigest digest)
#endif

isLowerHexDigest :: Text -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_DIGEST_COMPONENT_COMPOSITION_MUTANT)
isLowerHexDigest digest = legacyDigestLengthValid digest || legacyDigestCharactersValid digest
#else
isLowerHexDigest digest = legacyDigestLengthValid digest && legacyDigestCharactersValid digest
#endif

legacyDigestCharactersValid :: Text -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_DIGEST_CHARACTER_QUANTIFIER_MUTANT)
legacyDigestCharactersValid = Text.any legacyLowerHexCharacter
#else
legacyDigestCharactersValid = Text.all legacyLowerHexCharacter
#endif

legacyLowerHexCharacter :: Char -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_HEX_ALTERNATIVE_COMPOSITION_MUTANT)
legacyLowerHexCharacter character =
  legacyLowerHexDigit character && legacyLowerHexAlpha character
#else
legacyLowerHexCharacter character =
  legacyLowerHexDigit character || legacyLowerHexAlpha character
#endif

legacyDigestLengthValid :: Text -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_DIGEST_LENGTH_BYPASS_MUTANT)
legacyDigestLengthValid _ = True
#else
legacyDigestLengthValid digest = Text.length digest == 64
#endif

legacyLowerHexDigit :: Char -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_DIGEST_DIGIT_RANGE_BYPASS_MUTANT)
legacyLowerHexDigit character =
  legacyLowerHexDigitLowerBound character `seq`
    legacyLowerHexDigitUpperBound character `seq` True
#else
legacyLowerHexDigit character =
  legacyLowerHexDigitLowerBound character && legacyLowerHexDigitUpperBound character
#endif

legacyLowerHexAlpha :: Char -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_DIGEST_ALPHA_RANGE_BYPASS_MUTANT)
legacyLowerHexAlpha character =
  legacyLowerHexAlphaLowerBound character `seq`
    legacyLowerHexAlphaUpperBound character `seq` True
#else
legacyLowerHexAlpha character =
  legacyLowerHexAlphaLowerBound character && legacyLowerHexAlphaUpperBound character
#endif

legacyLowerHexDigitLowerBound :: Char -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_DIGIT_LOWER_BOUND_BYPASS_MUTANT)
legacyLowerHexDigitLowerBound _ = True
#else
legacyLowerHexDigitLowerBound character = character >= '0'
#endif

legacyLowerHexDigitUpperBound :: Char -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_DIGIT_UPPER_BOUND_BYPASS_MUTANT)
legacyLowerHexDigitUpperBound _ = True
#else
legacyLowerHexDigitUpperBound character = character <= '9'
#endif

legacyLowerHexAlphaLowerBound :: Char -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_ALPHA_LOWER_BOUND_BYPASS_MUTANT)
legacyLowerHexAlphaLowerBound _ = True
#else
legacyLowerHexAlphaLowerBound character = character >= 'a'
#endif

legacyLowerHexAlphaUpperBound :: Char -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_ALPHA_UPPER_BOUND_BYPASS_MUTANT)
legacyLowerHexAlphaUpperBound _ = True
#else
legacyLowerHexAlphaUpperBound character = character <= 'f'
#endif

malformedObservationFinding :: FilePath -> Text -> Finding
#if defined(VALIDATION_LEGACY_INTERNAL_MALFORMED_OBSERVATION_FINDING_COMPOSITION_MUTANT)
malformedObservationFinding subject detail =
  finding (malformedObservationDetail detail) malformedObservationSubject malformedObservationCode
 where
  malformedObservationSubject = subject
#else
malformedObservationFinding subject detail =
  finding malformedObservationCode malformedObservationSubject (malformedObservationDetail detail)
 where
  malformedObservationSubject =
#if defined(VALIDATION_LEGACY_INTERNAL_MALFORMED_OBSERVATION_SUBJECT_MUTANT)
    subject `seq` "<mutated>"
#else
    subject
#endif
#endif

malformedObservationCode :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_MALFORMED_OBSERVATION_CODE_MUTANT)
malformedObservationCode = "LEGACY-MUTATED"
#else
malformedObservationCode = "LEGACY-OBSERVATION-MALFORMED"
#endif

malformedObservationDetail :: Text -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_MALFORMED_OBSERVATION_DETAIL_MUTANT)
malformedObservationDetail detail = detail <> "-mutated"
#else
malformedObservationDetail = id
#endif

-- | Diagnostic routing surface for exhaustive model/oracle checks.  It is
-- permanently ineligible as candidate evidence because its registry is
-- caller-authored.
legacyInventoryDiagnostic :: Policy.PhaseOrdinal -> Map LegacyId LegacyObservation -> CheckResult
#if defined(VALIDATION_LEGACY_INTERNAL_INVENTORY_DIAGNOSTIC_REFUSAL_COMPOSITION_MUTANT)
legacyInventoryDiagnostic candidatePhase registry =
  let result = legacyInventoryFromObservations candidatePhase registry
   in appendDiagnosticRefusal result `seq` result
#else
legacyInventoryDiagnostic candidatePhase registry =
  appendDiagnosticRefusal (legacyInventoryFromObservations candidatePhase registry)
#endif

legacyInventoryFromObservations :: Policy.PhaseOrdinal -> Map LegacyId LegacyObservation -> CheckResult
legacyInventoryFromObservations candidatePhase registry =
  CheckResult
    { checkName = legacyInventoryResultName
    , checkObservations =
        legacyInventoryObservationComposition
          (legacyInventoryFixedObservations candidatePhase)
          (legacyInventoryEvaluatedObservations evaluated)
    , checkFindings =
        legacyInventoryFindingComposition
          universeIntegrityFindings
          (legacyInventoryEvaluatedFindings evaluated)
    }
 where
  evaluated =
    legacyInventoryEvaluationOrder
      [ evaluateCanonicalBinding candidatePhase (legacyBinding identifier) (lookupObservation identifier registry)
      | identifier <- allLegacyIds
      ]

legacyInventoryObservationComposition :: [Observation] -> [Observation] -> [Observation]
#if defined(VALIDATION_LEGACY_INTERNAL_INVENTORY_OBSERVATION_ORDER_MUTANT)
legacyInventoryObservationComposition fixed evaluated = evaluated <> fixed
#else
legacyInventoryObservationComposition fixed evaluated = fixed <> evaluated
#endif

legacyInventoryFindingComposition :: [Finding] -> [Finding] -> [Finding]
#if defined(VALIDATION_LEGACY_INTERNAL_INVENTORY_FINDING_ORDER_MUTANT)
legacyInventoryFindingComposition integrity evaluated = evaluated <> integrity
#else
legacyInventoryFindingComposition integrity evaluated = integrity <> evaluated
#endif

legacyInventoryResultName :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_INVENTORY_RESULT_NAME_MUTANT)
legacyInventoryResultName = "legacy-inventory-mutated"
#else
legacyInventoryResultName = "legacy-inventory"
#endif

legacyInventoryFixedObservations :: Policy.PhaseOrdinal -> [Observation]
#if defined(VALIDATION_LEGACY_INTERNAL_INVENTORY_FIXED_OBSERVATION_ORDER_MUTANT)
legacyInventoryFixedObservations candidatePhase =
  legacyBindingContractsObservation
    <> legacyOwnerBindingsObservation
    <> legacyCandidatePhaseObservation candidatePhase
#else
legacyInventoryFixedObservations candidatePhase =
  legacyOwnerBindingsObservation
    <> legacyBindingContractsObservation
    <> legacyCandidatePhaseObservation candidatePhase
#endif

legacyOwnerBindingsObservation :: [Observation]
#if defined(VALIDATION_LEGACY_INTERNAL_OWNER_BINDINGS_OBSERVATION_DROP_MUTANT)
legacyOwnerBindingsObservation =
  legacyOwnerBindingsObservationKey `seq` legacyOwnerBindingsObservationValue `seq` []
#else
legacyOwnerBindingsObservation =
  [ observation legacyOwnerBindingsObservationKey legacyOwnerBindingsObservationValue ]
#endif

legacyOwnerBindingsObservationKey :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_OWNER_BINDINGS_OBSERVATION_KEY_MUTANT)
legacyOwnerBindingsObservationKey = "legacy.mutated"
#else
legacyOwnerBindingsObservationKey = "legacy.haskell-owner-bindings"
#endif

legacyOwnerBindingsObservationValue :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_OWNER_BINDINGS_OBSERVATION_VALUE_MUTANT)
legacyOwnerBindingsObservationValue =
  Text.length renderOwnerBindings `seq` "mutated"
#else
legacyOwnerBindingsObservationValue = renderOwnerBindings
#endif

legacyBindingContractsObservation :: [Observation]
#if defined(VALIDATION_LEGACY_INTERNAL_BINDING_CONTRACTS_OBSERVATION_DROP_MUTANT)
legacyBindingContractsObservation =
  legacyBindingContractsObservationKey `seq` legacyBindingContractsObservationValue `seq` []
#else
legacyBindingContractsObservation =
  [ observation legacyBindingContractsObservationKey legacyBindingContractsObservationValue ]
#endif

legacyBindingContractsObservationKey :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_BINDING_CONTRACTS_OBSERVATION_KEY_MUTANT)
legacyBindingContractsObservationKey = "legacy.mutated"
#else
legacyBindingContractsObservationKey = "legacy.binding-contracts"
#endif

legacyBindingContractsObservationValue :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_BINDING_CONTRACTS_OBSERVATION_VALUE_MUTANT)
legacyBindingContractsObservationValue =
  Text.length renderBindingContracts `seq` "mutated"
#else
legacyBindingContractsObservationValue = renderBindingContracts
#endif

legacyCandidatePhaseObservation :: Policy.PhaseOrdinal -> [Observation]
#if defined(VALIDATION_LEGACY_INTERNAL_CANDIDATE_PHASE_OBSERVATION_DROP_MUTANT)
legacyCandidatePhaseObservation candidatePhase =
  legacyCandidatePhaseObservationKey `seq`
    legacyCandidatePhaseObservationValue candidatePhase `seq` []
#else
legacyCandidatePhaseObservation candidatePhase =
  [ observation legacyCandidatePhaseObservationKey
      (legacyCandidatePhaseObservationValue candidatePhase)
  ]
#endif

legacyCandidatePhaseObservationKey :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_CANDIDATE_PHASE_OBSERVATION_KEY_MUTANT)
legacyCandidatePhaseObservationKey = "legacy.mutated"
#else
legacyCandidatePhaseObservationKey = "legacy.candidate-phase"
#endif

legacyCandidatePhaseObservationValue :: Policy.PhaseOrdinal -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_CANDIDATE_PHASE_OBSERVATION_VALUE_MUTANT)
legacyCandidatePhaseObservationValue candidatePhase =
  Text.length (showText (Policy.phaseOrdinalNumber candidatePhase)) `seq` "mutated"
#else
legacyCandidatePhaseObservationValue = showText . Policy.phaseOrdinalNumber
#endif

legacyInventoryEvaluationOrder :: [CheckResult] -> [CheckResult]
#if defined(VALIDATION_LEGACY_INTERNAL_INVENTORY_EVALUATION_ORDER_MUTANT)
legacyInventoryEvaluationOrder = reverse
#else
legacyInventoryEvaluationOrder = id
#endif

legacyInventoryEvaluatedObservations :: [CheckResult] -> [Observation]
#if defined(VALIDATION_LEGACY_INTERNAL_INVENTORY_OBSERVATION_COMPOSITION_DROP_MUTANT)
legacyInventoryEvaluatedObservations results =
  length (concatMap checkObservations results) `seq` []
#else
legacyInventoryEvaluatedObservations = concatMap checkObservations
#endif

legacyInventoryEvaluatedFindings :: [CheckResult] -> [Finding]
#if defined(VALIDATION_LEGACY_INTERNAL_INVENTORY_FINDING_COMPOSITION_DROP_MUTANT)
legacyInventoryEvaluatedFindings results =
  length (concatMap checkFindings results) `seq` []
#else
legacyInventoryEvaluatedFindings = concatMap checkFindings
#endif

appendDiagnosticRefusal :: CheckResult -> CheckResult
appendDiagnosticRefusal result =
  result
    { checkFindings =
#if defined(VALIDATION_LEGACY_INTERNAL_DIAGNOSTIC_REFUSAL_ORDER_MUTANT)
        diagnosticRefusalFindings
          <> checkFindings result
#else
        checkFindings result
          <> diagnosticRefusalFindings
#endif
    }

diagnosticRefusalFindings :: [Finding]
#if defined(VALIDATION_LEGACY_INTERNAL_DIAGNOSTIC_REFUSAL_DROP_MUTANT)
diagnosticRefusalFindings =
  finding diagnosticRefusalCode diagnosticRefusalSubject diagnosticRefusalDetail `seq` []
#else
diagnosticRefusalFindings =
#if defined(VALIDATION_LEGACY_INTERNAL_DIAGNOSTIC_REFUSAL_FINDING_COMPOSITION_MUTANT)
  [ finding diagnosticRefusalDetail diagnosticRefusalSubject diagnosticRefusalCode
  ]
#else
  [ finding diagnosticRefusalCode diagnosticRefusalSubject diagnosticRefusalDetail
  ]
#endif
#endif

diagnosticRefusalCode :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_DIAGNOSTIC_REFUSAL_CODE_MUTANT)
diagnosticRefusalCode = "LEGACY-MUTATED"
#else
diagnosticRefusalCode = "LEGACY-DIAGNOSTIC-NOT-CANDIDATE"
#endif

diagnosticRefusalSubject :: FilePath
#if defined(VALIDATION_LEGACY_INTERNAL_DIAGNOSTIC_REFUSAL_SUBJECT_MUTANT)
diagnosticRefusalSubject = "<mutated>"
#else
diagnosticRefusalSubject = legacySemanticSubject
#endif

diagnosticRefusalDetail :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_DIAGNOSTIC_REFUSAL_DETAIL_MUTANT)
diagnosticRefusalDetail = "mutated"
#else
diagnosticRefusalDetail =
  "caller-supplied legacy observations are diagnostic model inputs, never analyzer evidence"
#endif

lookupObservation :: LegacyId -> Map LegacyId LegacyObservation -> Maybe LegacyObservation
#if defined(VALIDATION_LEGACY_INTERNAL_LOOKUP_OBSERVATION_ROUTE_MUTANT)
lookupObservation _ _ = Nothing
#else
lookupObservation identifier registry =
  Map.lookup identifier registry
#endif

universeIntegrityFindings :: [Finding]
universeIntegrityFindings =
  legacyUniverseIntegrityComposition
    (legacyUniverseInventoryFindingRoute universeFindings)
    (legacyUniverseRenderingFindingRoute renderFindings)
    (legacyUniverseParserFindingRoute parserFindings)
    (legacyUniverseBindingFindingRoute bindingIdFindings)
    (legacyUniverseClosedFindingRoute closedBindingUniverseFindings)
 where
  universeFindings =
    [ integrityFinding
        IntegrityIdInventory
        "LEGACY-ID-INVENTORY"
        legacySemanticSubject
        "allLegacyIds must contain every LegacyId constructor exactly once and in constructor order"
    | legacyAllIdsInvalid allLegacyIds canonicalLegacyUniverse
    ]
  rendered = map renderLegacyId canonicalLegacyUniverse
  renderFindings =
    [ integrityFinding
        IntegrityIdEncoding
        "LEGACY-ID-ENCODING"
        legacySemanticSubject
        "every LegacyId must have one unique stable text encoding"
    | legacyRenderingsInvalid rendered
    ]
  parserFindings =
    [ integrityFinding
        IntegrityParserGrammar
        "LEGACY-ID-PARSER-GRAMMAR"
        legacySemanticSubject
        "the accepted LegacyId parser keys must equal the unique canonical renderings exactly"
    | legacyParserGrammarInvalid legacyIdDecoder canonicalLegacyIdDecoder canonicalLegacyUniverse
    ]
  bindingIdFindings =
    [ integrityFinding
        IntegrityBindingId
        "LEGACY-BINDING-ID-MISMATCH"
        (legacySubject identifier)
        "legacyBinding returned a record for a different LegacyId"
    | identifier <- canonicalLegacyUniverse
    , legacyBindingIdInvalid (legacyBindingId (legacyBinding identifier)) identifier
    ]
  closedBindingUniverseFindings =
    closedUniverseFinding IntegrityAnalyzerInventory
      "LEGACY-ANALYZER-INVENTORY"
      "every LegacyAnalyzer key must be used exactly once"
      ([minBound .. maxBound] :: [LegacyAnalyzer])
      (map legacyIdAnalyzer canonicalLegacyUniverse)
      <> closedUniverseFinding IntegrityObservationInventory
        "LEGACY-OBSERVATION-INVENTORY"
        "every LegacyObservationRule key must be used exactly once"
        ([minBound .. maxBound] :: [LegacyObservationRule])
        (map legacyIdObservationRule canonicalLegacyUniverse)
      <> closedUniverseFinding IntegrityClosureInventory
        "LEGACY-CLOSURE-INVENTORY"
        "every LegacyClosureRule key must be used exactly once"
        ([minBound .. maxBound] :: [LegacyClosureRule])
        (map legacyIdClosureRule canonicalLegacyUniverse)
      <> closedUniverseFinding IntegrityReintroductionInventory
        "LEGACY-REINTRODUCTION-INVENTORY"
        "every LegacyReintroductionCase key must be used exactly once"
        ([minBound .. maxBound] :: [LegacyReintroductionCase])
        (concatMap (toListNonEmpty . legacyIdReintroductionCases) canonicalLegacyUniverse)
      <> [ finding "LEGACY-OWNER-CAPABILITY-UNKNOWN" legacySemanticSubject problem
         | problem <- legacyOwnerCapabilityProblems
         ]

legacyUniverseIntegrityComposition
  :: [Finding] -> [Finding] -> [Finding] -> [Finding] -> [Finding] -> [Finding]
#if defined(VALIDATION_LEGACY_INTERNAL_UNIVERSE_INTEGRITY_FINDING_ORDER_MUTANT)
legacyUniverseIntegrityComposition universe rendered parser bindings closed =
  rendered <> universe <> parser <> bindings <> closed
#else
legacyUniverseIntegrityComposition universe rendered parser bindings closed =
  universe <> rendered <> parser <> bindings <> closed
#endif

legacyUniverseInventoryFindingRoute :: [Finding] -> [Finding]
#if defined(VALIDATION_LEGACY_INTERNAL_UNIVERSE_INVENTORY_FINDING_DROP_MUTANT)
legacyUniverseInventoryFindingRoute values = length values `seq` []
#else
legacyUniverseInventoryFindingRoute = id
#endif

legacyUniverseRenderingFindingRoute :: [Finding] -> [Finding]
#if defined(VALIDATION_LEGACY_INTERNAL_UNIVERSE_RENDERING_FINDING_DROP_MUTANT)
legacyUniverseRenderingFindingRoute values = length values `seq` []
#else
legacyUniverseRenderingFindingRoute = id
#endif

legacyUniverseParserFindingRoute :: [Finding] -> [Finding]
#if defined(VALIDATION_LEGACY_INTERNAL_UNIVERSE_PARSER_FINDING_DROP_MUTANT)
legacyUniverseParserFindingRoute values = length values `seq` []
#else
legacyUniverseParserFindingRoute = id
#endif

legacyUniverseBindingFindingRoute :: [Finding] -> [Finding]
#if defined(VALIDATION_LEGACY_INTERNAL_UNIVERSE_BINDING_FINDING_DROP_MUTANT)
legacyUniverseBindingFindingRoute values = length values `seq` []
#else
legacyUniverseBindingFindingRoute = id
#endif

legacyUniverseClosedFindingRoute :: [Finding] -> [Finding]
#if defined(VALIDATION_LEGACY_INTERNAL_UNIVERSE_CLOSED_FINDING_DROP_MUTANT)
legacyUniverseClosedFindingRoute values = length values `seq` []
#else
legacyUniverseClosedFindingRoute = id
#endif

data IntegrityFindingKind
  = IntegrityIdInventory
  | IntegrityIdEncoding
  | IntegrityParserGrammar
  | IntegrityBindingId
  | IntegrityAnalyzerInventory
  | IntegrityObservationInventory
  | IntegrityClosureInventory
  | IntegrityReintroductionInventory

legacyAllIdsInvalid :: [LegacyId] -> [LegacyId] -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_ALL_IDS_INTEGRITY_BYPASS_MUTANT)
legacyAllIdsInvalid _ _ = False
#else
legacyAllIdsInvalid actual expected = actual /= expected
#endif

legacyRenderingsInvalid :: [Text] -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_RENDERING_UNIQUENESS_BYPASS_MUTANT)
legacyRenderingsInvalid _ = False
#else
legacyRenderingsInvalid rendered = length rendered /= length (nub rendered)
#endif

legacyParserGrammarInvalid :: Map Text LegacyId -> Map Text LegacyId -> [LegacyId] -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_PARSER_GRAMMAR_BYPASS_MUTANT)
legacyParserGrammarInvalid actual expected universe =
  legacyParserMapInvalid actual expected `seq`
    legacyParserCardinalityInvalid expected universe `seq` False
#else
legacyParserGrammarInvalid actual expected universe =
  legacyParserMapInvalid actual expected
    || legacyParserCardinalityInvalid expected universe
#endif

legacyParserMapInvalid :: Map Text LegacyId -> Map Text LegacyId -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_PARSER_MAP_COMPARISON_BYPASS_MUTANT)
legacyParserMapInvalid _ _ = False
#else
legacyParserMapInvalid actual expected = actual /= expected
#endif

legacyParserCardinalityInvalid :: Map Text LegacyId -> [LegacyId] -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_PARSER_CARDINALITY_BYPASS_MUTANT)
legacyParserCardinalityInvalid _ _ = False
#else
legacyParserCardinalityInvalid expected universe = Map.size expected /= length universe
#endif

legacyBindingIdInvalid :: LegacyId -> LegacyId -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_BINDING_ID_INTEGRITY_BYPASS_MUTANT)
legacyBindingIdInvalid _ _ = False
#else
legacyBindingIdInvalid actual expected = actual /= expected
#endif

closedUniverseFinding
  :: (Eq value, Ord value)
  => IntegrityFindingKind -> Text -> Text -> [value] -> [value] -> [Finding]
closedUniverseFinding kind code detail expected actual =
  [ integrityFinding kind code legacySemanticSubject detail
  | closedUniverseInvalid expected actual
  ]

closedUniverseInvalid :: (Eq value, Ord value) => [value] -> [value] -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_UNIVERSE_INTEGRITY_BYPASS_MUTANT)
closedUniverseInvalid expected actual =
  closedUniverseEqualityInvalid expected actual `seq`
    closedUniverseDuplicateInvalid actual `seq` False
#else
closedUniverseInvalid expected actual =
  closedUniverseEqualityInvalid expected actual
    || closedUniverseDuplicateInvalid actual
#endif

closedUniverseEqualityInvalid :: Eq value => [value] -> [value] -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_UNIVERSE_EQUALITY_BYPASS_MUTANT)
closedUniverseEqualityInvalid _ _ = False
#else
closedUniverseEqualityInvalid expected actual = actual /= expected
#endif

closedUniverseDuplicateInvalid :: Ord value => [value] -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_UNIVERSE_DUPLICATE_BYPASS_MUTANT)
closedUniverseDuplicateInvalid _ = False
#else
closedUniverseDuplicateInvalid actual = length actual /= length (nub actual)
#endif

integrityFinding :: IntegrityFindingKind -> Text -> FilePath -> Text -> Finding
#if defined(VALIDATION_LEGACY_INTERNAL_INTEGRITY_FINDING_COMPOSITION_MUTANT)
integrityFinding kind code subject detail =
  finding (integrityFindingDetail kind detail) (integrityFindingSubject kind subject) (integrityFindingCode kind code)
#else
integrityFinding kind code subject detail =
  finding (integrityFindingCode kind code) (integrityFindingSubject kind subject) (integrityFindingDetail kind detail)
#endif

integrityFindingCode :: IntegrityFindingKind -> Text -> Text
integrityFindingCode kind code = case kind of
  IntegrityIdInventory ->
#if defined(VALIDATION_LEGACY_INTERNAL_ID_INVENTORY_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    code
#endif
  IntegrityIdEncoding ->
#if defined(VALIDATION_LEGACY_INTERNAL_ID_ENCODING_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    code
#endif
  IntegrityParserGrammar ->
#if defined(VALIDATION_LEGACY_INTERNAL_PARSER_GRAMMAR_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    code
#endif
  IntegrityBindingId ->
#if defined(VALIDATION_LEGACY_INTERNAL_BINDING_ID_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    code
#endif
  IntegrityAnalyzerInventory ->
#if defined(VALIDATION_LEGACY_INTERNAL_ANALYZER_INVENTORY_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    code
#endif
  IntegrityObservationInventory ->
#if defined(VALIDATION_LEGACY_INTERNAL_OBSERVATION_INVENTORY_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    code
#endif
  IntegrityClosureInventory ->
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSURE_INVENTORY_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    code
#endif
  IntegrityReintroductionInventory ->
#if defined(VALIDATION_LEGACY_INTERNAL_REINTRODUCTION_INVENTORY_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    code
#endif

integrityFindingSubject :: IntegrityFindingKind -> FilePath -> FilePath
integrityFindingSubject kind subject = case kind of
  IntegrityIdInventory ->
#if defined(VALIDATION_LEGACY_INTERNAL_ID_INVENTORY_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  IntegrityIdEncoding ->
#if defined(VALIDATION_LEGACY_INTERNAL_ID_ENCODING_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  IntegrityParserGrammar ->
#if defined(VALIDATION_LEGACY_INTERNAL_PARSER_GRAMMAR_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  IntegrityBindingId ->
#if defined(VALIDATION_LEGACY_INTERNAL_BINDING_ID_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  IntegrityAnalyzerInventory ->
#if defined(VALIDATION_LEGACY_INTERNAL_ANALYZER_INVENTORY_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  IntegrityObservationInventory ->
#if defined(VALIDATION_LEGACY_INTERNAL_OBSERVATION_INVENTORY_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  IntegrityClosureInventory ->
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSURE_INVENTORY_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  IntegrityReintroductionInventory ->
#if defined(VALIDATION_LEGACY_INTERNAL_REINTRODUCTION_INVENTORY_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif

integrityFindingDetail :: IntegrityFindingKind -> Text -> Text
integrityFindingDetail kind detail = case kind of
  IntegrityIdInventory ->
#if defined(VALIDATION_LEGACY_INTERNAL_ID_INVENTORY_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  IntegrityIdEncoding ->
#if defined(VALIDATION_LEGACY_INTERNAL_ID_ENCODING_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  IntegrityParserGrammar ->
#if defined(VALIDATION_LEGACY_INTERNAL_PARSER_GRAMMAR_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  IntegrityBindingId ->
#if defined(VALIDATION_LEGACY_INTERNAL_BINDING_ID_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  IntegrityAnalyzerInventory ->
#if defined(VALIDATION_LEGACY_INTERNAL_ANALYZER_INVENTORY_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  IntegrityObservationInventory ->
#if defined(VALIDATION_LEGACY_INTERNAL_OBSERVATION_INVENTORY_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  IntegrityClosureInventory ->
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSURE_INVENTORY_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  IntegrityReintroductionInventory ->
#if defined(VALIDATION_LEGACY_INTERNAL_REINTRODUCTION_INVENTORY_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif

toListNonEmpty :: NonEmpty value -> [value]
toListNonEmpty (first :| rest) = first : rest

bindingIntegrityFindings :: LegacyBinding -> [Finding]
bindingIntegrityFindings binding =
  legacyBindingIntegrityFindingComposition
    ownerFindings analyzerFindings observationFindings closureFindings reintroductionFindings
 where
  identifier = legacyBindingId binding
  subject = legacySubject identifier
  ownerFindings = case legacyBindingOwner binding of
    BindingMissing -> [bindingFinding BindingOwnerMissing subject "typed owner binding is missing"]
    BindingPresent actual
      | legacyOwnerBindingMismatch actual (legacyIdOwner identifier) ->
          [bindingFinding BindingOwnerMismatch subject "typed owner binding does not match the exhaustive owner dispatch"]
      | otherwise -> []
  analyzerFindings = case legacyBindingAnalyzer binding of
    BindingMissing -> [bindingFinding BindingAnalyzerMissing subject "typed required-analyzer binding is missing"]
    BindingPresent actual
      | legacyAnalyzerBindingMismatch actual (legacyIdAnalyzer identifier) ->
          [bindingFinding BindingAnalyzerMismatch subject "required-analyzer dispatch was redirected"]
      | otherwise -> []
  observationFindings = case legacyBindingObservation binding of
    BindingMissing -> [bindingFinding BindingObservationMissing subject "typed observation-rule binding is missing"]
    BindingPresent actual
      | legacyObservationBindingMismatch actual (legacyIdObservationRule identifier) ->
          [bindingFinding BindingObservationMismatch subject "typed observation-rule binding was redirected"]
      | otherwise -> []
  closureFindings = case legacyBindingClosure binding of
    BindingMissing -> [bindingFinding BindingClosureMissing subject "typed closure-rule binding is missing"]
    BindingPresent actual
      | legacyClosureBindingMismatch actual (legacyIdClosureRule identifier) ->
          [bindingFinding BindingClosureMismatch subject "typed closure-rule binding was redirected"]
      | otherwise -> []
  reintroductionFindings = case legacyBindingReintroduction binding of
    BindingMissing -> [bindingFinding BindingReintroductionMissing subject "typed reintroduction-case binding is missing"]
    BindingPresent actual
      | legacyReintroductionBindingMismatch actual (legacyIdReintroductionCases identifier) ->
          [bindingFinding BindingReintroductionMismatch subject "typed reintroduction-case binding was redirected"]
      | otherwise -> []

legacyBindingIntegrityFindingComposition
  :: [Finding] -> [Finding] -> [Finding] -> [Finding] -> [Finding] -> [Finding]
#if defined(VALIDATION_LEGACY_INTERNAL_BINDING_INTEGRITY_FINDING_ORDER_MUTANT)
legacyBindingIntegrityFindingComposition owner analyzer observed closed reintroduced =
  analyzer <> owner <> observed <> closed <> reintroduced
#else
legacyBindingIntegrityFindingComposition owner analyzer observed closed reintroduced =
  owner <> analyzer <> observed <> closed <> reintroduced
#endif

legacyOwnerBindingMismatch :: Policy.PhaseOrdinal -> Policy.PhaseOrdinal -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_OWNER_BINDING_MATCH_BYPASS_MUTANT)
legacyOwnerBindingMismatch _ _ = False
#else
legacyOwnerBindingMismatch actual expected = actual /= expected
#endif

legacyAnalyzerBindingMismatch :: LegacyAnalyzer -> LegacyAnalyzer -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_ANALYZER_BINDING_MATCH_BYPASS_MUTANT)
legacyAnalyzerBindingMismatch _ _ = False
#else
legacyAnalyzerBindingMismatch actual expected = actual /= expected
#endif

legacyObservationBindingMismatch :: LegacyObservationRule -> LegacyObservationRule -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_OBSERVATION_BINDING_MATCH_BYPASS_MUTANT)
legacyObservationBindingMismatch _ _ = False
#else
legacyObservationBindingMismatch actual expected = actual /= expected
#endif

legacyClosureBindingMismatch :: LegacyClosureRule -> LegacyClosureRule -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSURE_BINDING_MATCH_BYPASS_MUTANT)
legacyClosureBindingMismatch _ _ = False
#else
legacyClosureBindingMismatch actual expected = actual /= expected
#endif

legacyReintroductionBindingMismatch
  :: NonEmpty LegacyReintroductionCase -> NonEmpty LegacyReintroductionCase -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_REINTRODUCTION_BINDING_MATCH_BYPASS_MUTANT)
legacyReintroductionBindingMismatch _ _ = False
#else
legacyReintroductionBindingMismatch actual expected = actual /= expected
#endif

data BindingFindingKind
  = BindingOwnerMissing
  | BindingOwnerMismatch
  | BindingAnalyzerMissing
  | BindingAnalyzerMismatch
  | BindingObservationMissing
  | BindingObservationMismatch
  | BindingClosureMissing
  | BindingClosureMismatch
  | BindingReintroductionMissing
  | BindingReintroductionMismatch

bindingFinding :: BindingFindingKind -> FilePath -> Text -> Finding
#if defined(VALIDATION_LEGACY_INTERNAL_BINDING_FINDING_COMPOSITION_MUTANT)
bindingFinding kind subject detail =
  finding (bindingFindingDetail kind detail) (bindingFindingSubject kind subject) (bindingFindingCode kind)
#else
bindingFinding kind subject detail =
  finding (bindingFindingCode kind) (bindingFindingSubject kind subject) (bindingFindingDetail kind detail)
#endif

bindingFindingCode :: BindingFindingKind -> Text
bindingFindingCode kind = case kind of
  BindingOwnerMissing ->
#if defined(VALIDATION_LEGACY_INTERNAL_OWNER_MISSING_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-OWNER-BINDING-MISSING"
#endif
  BindingOwnerMismatch ->
#if defined(VALIDATION_LEGACY_INTERNAL_OWNER_MISMATCH_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-OWNER-BINDING-MISMATCH"
#endif
  BindingAnalyzerMissing ->
#if defined(VALIDATION_LEGACY_INTERNAL_ANALYZER_MISSING_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-ANALYZER-BINDING-MISSING"
#endif
  BindingAnalyzerMismatch ->
#if defined(VALIDATION_LEGACY_INTERNAL_ANALYZER_BINDING_MISMATCH_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-ANALYZER-BINDING-MISMATCH"
#endif
  BindingObservationMissing ->
#if defined(VALIDATION_LEGACY_INTERNAL_OBSERVATION_MISSING_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-OBSERVATION-BINDING-MISSING"
#endif
  BindingObservationMismatch ->
#if defined(VALIDATION_LEGACY_INTERNAL_OBSERVATION_MISMATCH_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-OBSERVATION-BINDING-MISMATCH"
#endif
  BindingClosureMissing ->
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSURE_MISSING_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-CLOSURE-BINDING-MISSING"
#endif
  BindingClosureMismatch ->
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSURE_MISMATCH_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-CLOSURE-BINDING-MISMATCH"
#endif
  BindingReintroductionMissing ->
#if defined(VALIDATION_LEGACY_INTERNAL_REINTRODUCTION_MISSING_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-REINTRODUCTION-BINDING-MISSING"
#endif
  BindingReintroductionMismatch ->
#if defined(VALIDATION_LEGACY_INTERNAL_REINTRODUCTION_MISMATCH_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-REINTRODUCTION-BINDING-MISMATCH"
#endif

bindingFindingSubject :: BindingFindingKind -> FilePath -> FilePath
bindingFindingSubject kind subject = case kind of
  BindingOwnerMissing ->
#if defined(VALIDATION_LEGACY_INTERNAL_OWNER_MISSING_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  BindingOwnerMismatch ->
#if defined(VALIDATION_LEGACY_INTERNAL_OWNER_MISMATCH_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  BindingAnalyzerMissing ->
#if defined(VALIDATION_LEGACY_INTERNAL_ANALYZER_MISSING_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  BindingAnalyzerMismatch ->
#if defined(VALIDATION_LEGACY_INTERNAL_ANALYZER_BINDING_MISMATCH_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  BindingObservationMissing ->
#if defined(VALIDATION_LEGACY_INTERNAL_OBSERVATION_MISSING_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  BindingObservationMismatch ->
#if defined(VALIDATION_LEGACY_INTERNAL_OBSERVATION_MISMATCH_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  BindingClosureMissing ->
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSURE_MISSING_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  BindingClosureMismatch ->
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSURE_MISMATCH_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  BindingReintroductionMissing ->
#if defined(VALIDATION_LEGACY_INTERNAL_REINTRODUCTION_MISSING_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  BindingReintroductionMismatch ->
#if defined(VALIDATION_LEGACY_INTERNAL_REINTRODUCTION_MISMATCH_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif

bindingFindingDetail :: BindingFindingKind -> Text -> Text
bindingFindingDetail kind detail = case kind of
  BindingOwnerMissing ->
#if defined(VALIDATION_LEGACY_INTERNAL_OWNER_MISSING_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  BindingOwnerMismatch ->
#if defined(VALIDATION_LEGACY_INTERNAL_OWNER_MISMATCH_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  BindingAnalyzerMissing ->
#if defined(VALIDATION_LEGACY_INTERNAL_ANALYZER_MISSING_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  BindingAnalyzerMismatch ->
#if defined(VALIDATION_LEGACY_INTERNAL_ANALYZER_BINDING_MISMATCH_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  BindingObservationMissing ->
#if defined(VALIDATION_LEGACY_INTERNAL_OBSERVATION_MISSING_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  BindingObservationMismatch ->
#if defined(VALIDATION_LEGACY_INTERNAL_OBSERVATION_MISMATCH_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  BindingClosureMissing ->
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSURE_MISSING_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  BindingClosureMismatch ->
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSURE_MISMATCH_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  BindingReintroductionMissing ->
#if defined(VALIDATION_LEGACY_INTERNAL_REINTRODUCTION_MISSING_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  BindingReintroductionMismatch ->
#if defined(VALIDATION_LEGACY_INTERNAL_REINTRODUCTION_MISMATCH_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif

-- | Locate one reader register and verify only UTF-8 bytes. Row text, count,
-- IDs, owners, and predicate-looking prose are deliberately unavailable to
-- executable legacy semantics.
activeRegisterFromSnapshot :: SourceSnapshot -> Either [RegisterProblem] ActiveRegister
activeRegisterFromSnapshot snapshot =
  case legacyRegisterEntryPreflight (snapshotEntries snapshot) of
    LegacyBoundedExceeded observed _ ->
      Left (legacyRegisterEntryLimitProblems observed)
    LegacyBoundedWithin entries ->
      case legacyRegisterPathProblemRoute (firstRegisterPathProblem entries) of
        Just problem -> Left [problem]
        Nothing -> evaluateBoundedEntries entries
 where
  pathOf = indexPath . trackedIndex
  evaluateBoundedEntries entries =
    case canonicalEntries of
      [] -> Left (legacyRegisterMissingProblems aliasProblems archiveProblems)
      [entry] ->
        case indexMode (trackedIndex entry) of
          RegularFile ->
            case parseActiveRegister (trackedBytes entry) of
              Left problems -> Left (legacyRegisterProblemOrder aliasProblems archiveProblems problems)
              Right register -> legacyRegisterAcceptedOutcome aliasProblems archiveProblems register
          mode -> Left (legacyRegisterModeProblems aliasProblems archiveProblems mode)
      duplicateEntries ->
        Left (legacyRegisterDuplicateProblems aliasProblems archiveProblems (length duplicateEntries))
   where
    canonicalEntries = legacyCanonicalRegisterEntries pathOf entries
    aliasProblems =
      [ AdditionalActiveRegisterTracked (pathOf entry)
      | entry <- entries
      , legacyAdditionalRegisterPath (pathOf entry)
      ]
    archiveProblems =
      [ ArchiveRegisterTracked (pathOf entry)
      | entry <- entries
      , legacyArchiveRegisterPath (pathOf entry)
      ]

legacyRegisterEntryPreflight :: [TrackedEntry] -> LegacyBoundedPrefix TrackedEntry
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_ENTRY_PREFLIGHT_ROUTE_MUTANT)
legacyRegisterEntryPreflight entries =
  case legacyBoundedPrefix maximumLegacyTrackedEntries entries of
    LegacyBoundedExceeded _ bounded -> LegacyBoundedWithin bounded
    result -> result
#else
legacyRegisterEntryPreflight = legacyBoundedPrefix maximumLegacyTrackedEntries
#endif

legacyRegisterPathProblemRoute :: Maybe RegisterProblem -> Maybe RegisterProblem
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_PATH_PREFLIGHT_ROUTE_MUTANT)
legacyRegisterPathProblemRoute selected = selected `seq` Nothing
#else
legacyRegisterPathProblemRoute = id
#endif

legacyRegisterEntryLimitProblems :: Int -> [RegisterProblem]
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_ENTRY_LIMIT_RETENTION_MUTANT)
legacyRegisterEntryLimitProblems observed =
  guardedRegisterResourceProblem
    "tracked-entry-limit"
    (legacyRegisterEntryLimitExceeded observed)
    (RegisterEntryLimit maximumLegacyTrackedEntries observed)
    `seq` []
#else
legacyRegisterEntryLimitProblems observed =
  [ guardedRegisterResourceProblem
      "tracked-entry-limit"
      (legacyRegisterEntryLimitExceeded observed)
      (RegisterEntryLimit maximumLegacyTrackedEntries observed)
  ]
#endif

legacyRegisterMissingProblems
  :: [RegisterProblem] -> [RegisterProblem] -> [RegisterProblem]
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_MISSING_ROUTE_MUTANT)
legacyRegisterMissingProblems aliases archives =
  ActiveRegisterMissing canonicalRegisterPath `seq`
    legacyRegisterProblemOrder aliases archives []
#else
legacyRegisterMissingProblems aliases archives =
  legacyRegisterProblemOrder aliases archives [ActiveRegisterMissing canonicalRegisterPath]
#endif

legacyRegisterModeProblems
  :: [RegisterProblem] -> [RegisterProblem] -> IndexMode -> [RegisterProblem]
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_MODE_ROUTE_MUTANT)
legacyRegisterModeProblems aliases archives mode =
  mode `seq` legacyRegisterProblemOrder aliases archives []
#else
legacyRegisterModeProblems aliases archives mode =
  legacyRegisterProblemOrder aliases archives [RegisterNotRegularFile canonicalRegisterPath mode]
#endif

legacyRegisterDuplicateProblems
  :: [RegisterProblem] -> [RegisterProblem] -> Int -> [RegisterProblem]
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_DUPLICATE_ROUTE_MUTANT)
legacyRegisterDuplicateProblems aliases archives count =
  count `seq` legacyRegisterProblemOrder aliases archives []
#else
legacyRegisterDuplicateProblems aliases archives count =
  legacyRegisterProblemOrder aliases archives [MultipleActiveRegisters canonicalRegisterPath count]
#endif

legacyRegisterAcceptedOutcome
  :: [RegisterProblem] -> [RegisterProblem] -> ActiveRegister
  -> Either [RegisterProblem] ActiveRegister
legacyRegisterAcceptedOutcome aliases archives register =
  let problems = legacyRegisterProblemOrder aliases archives []
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_ACCEPTED_ROUTE_MUTANT)
   in legacyRegisterProblemsClear problems `seq` register `seq` Left problems
#else
   in if legacyRegisterProblemsClear problems then Right register else Left problems
#endif

legacyCanonicalRegisterEntries :: (TrackedEntry -> FilePath) -> [TrackedEntry] -> [TrackedEntry]
#if defined(VALIDATION_LEGACY_INTERNAL_CANONICAL_ENTRY_FILTER_BYPASS_MUTANT)
legacyCanonicalRegisterEntries _ _ = []
#elif defined(VALIDATION_LEGACY_INTERNAL_CANONICAL_ENTRY_DUPLICATE_COLLAPSE_MUTANT)
legacyCanonicalRegisterEntries pathOf = take 1 . filter ((== canonicalRegisterPath) . pathOf)
#else
legacyCanonicalRegisterEntries pathOf = filter ((== canonicalRegisterPath) . pathOf)
#endif

legacyAdditionalRegisterPath :: FilePath -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_ALIAS_PATH_BYPASS_MUTANT)
legacyAdditionalRegisterPath path =
  legacyAliasCanonicalExcluded path `seq` legacyAliasBasenameMatches path `seq` False
#else
legacyAdditionalRegisterPath path =
  legacyAliasCanonicalExcluded path && legacyAliasBasenameMatches path
#endif

legacyAliasCanonicalExcluded :: FilePath -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_ALIAS_CANONICAL_EXCLUSION_BYPASS_MUTANT)
legacyAliasCanonicalExcluded _ = True
#else
legacyAliasCanonicalExcluded path = path /= canonicalRegisterPath
#endif

legacyAliasBasenameMatches :: FilePath -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_ALIAS_BASENAME_MATCH_BYPASS_MUTANT)
legacyAliasBasenameMatches _ = True
#else
legacyAliasBasenameMatches path = takeFileName path == takeFileName canonicalRegisterPath
#endif

legacyArchiveRegisterPath :: FilePath -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_ARCHIVE_PATH_BYPASS_MUTANT)
legacyArchiveRegisterPath _ = False
#else
legacyArchiveRegisterPath path = takeFileName path == archiveRegisterName
#endif

legacyRegisterProblemOrder :: [RegisterProblem] -> [RegisterProblem] -> [RegisterProblem] -> [RegisterProblem]
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_PROBLEM_ORDER_MUTANT)
legacyRegisterProblemOrder aliases archives specific = specific <> archives <> aliases
#else
legacyRegisterProblemOrder aliases archives specific = aliases <> archives <> specific
#endif

legacyRegisterProblemsClear :: [RegisterProblem] -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_PROBLEMS_CLEAR_BYPASS_MUTANT)
legacyRegisterProblemsClear _ = True
#else
legacyRegisterProblemsClear = null
#endif

firstRegisterPathProblem :: [TrackedEntry] -> Maybe RegisterProblem
firstRegisterPathProblem entries = go 1 entries
 where
  go _ [] = Nothing
  go ordinal (entry : rest) =
    case legacyBoundedPathBytes maximumLegacyTrackedPathBytes (indexPath (trackedIndex entry)) of
      LegacyBoundedWithin _ -> go (ordinal + 1) rest
      LegacyBoundedExceeded observed _ ->
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_PATH_PROBLEM_RETENTION_MUTANT)
        guardedRegisterResourceProblem
          "tracked-path-byte-limit"
          (legacyRegisterPathLimitExceeded observed)
          (RegisterPathByteLimit ordinal maximumLegacyTrackedPathBytes observed)
          `seq` go (ordinal + 1) rest
#else
        Just
          ( guardedRegisterResourceProblem
              "tracked-path-byte-limit"
              (legacyRegisterPathLimitExceeded observed)
              (RegisterPathByteLimit ordinal maximumLegacyTrackedPathBytes observed)
          )
#endif

parseActiveRegister :: ByteString -> Either [RegisterProblem] ActiveRegister
parseActiveRegister bytes =
  if
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_BYTE_PREFLIGHT_THRESHOLD_MUTANT)
    ByteString.length bytes >= maximumLegacyRegisterBytes
#else
    ByteString.length bytes > maximumLegacyRegisterBytes
#endif
    then
      Left
        [ guardedRegisterResourceProblem
            "register-byte-limit"
            (legacyRegisterByteLimitExceeded (ByteString.length bytes))
            (RegisterByteLimit maximumLegacyRegisterBytes (ByteString.length bytes))
        ]
    else if legacyRegisterUtf8Valid bytes
      then Right (ActiveRegister legacyAcceptedRegisterPath)
      else Left [RegisterNotUtf8 canonicalRegisterPath]

legacyRegisterUtf8Valid :: ByteString -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_UTF8_BYPASS_MUTANT)
legacyRegisterUtf8Valid _ = True
#else
legacyRegisterUtf8Valid bytes = case TextEncoding.decodeUtf8' bytes of
  Left _ -> False
  Right _ -> True
#endif

legacyAcceptedRegisterPath :: FilePath
#if defined(VALIDATION_LEGACY_INTERNAL_ACCEPTED_REGISTER_PATH_MUTANT)
legacyAcceptedRegisterPath = "<mutated>"
#else
legacyAcceptedRegisterPath = canonicalRegisterPath
#endif

legacyBoundedPrefix :: Int -> [value] -> LegacyBoundedPrefix value
legacyBoundedPrefix limit = go 0 []
 where
  go count reversed values = case values of
    [] -> LegacyBoundedWithin (legacyRetainedEntryPrefix reversed)
    value : rest
      | legacyPrefixLimitReached count limit ->
          LegacyBoundedExceeded (legacyPrefixExceededCount limit) (legacyRetainedEntryPrefix reversed)
      | otherwise -> go (count + 1) (value : reversed) rest

legacyRetainedEntryPrefix :: [value] -> [value]
#if defined(VALIDATION_LEGACY_INTERNAL_PREFIX_RETENTION_ORDER_MUTANT)
legacyRetainedEntryPrefix = id
#else
legacyRetainedEntryPrefix = reverse
#endif

legacyPrefixLimitReached :: Int -> Int -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_PREFIX_THRESHOLD_MUTANT)
legacyPrefixLimitReached count limit = count > limit
#else
legacyPrefixLimitReached count limit = count == limit
#endif

legacyPrefixExceededCount :: Int -> Int
#if defined(VALIDATION_LEGACY_INTERNAL_PREFIX_OBSERVED_COUNT_MUTANT)
legacyPrefixExceededCount limit = limit + 2
#else
legacyPrefixExceededCount limit = limit + 1
#endif

legacyBoundedPathBytes :: Int -> FilePath -> LegacyBoundedPrefix Char
legacyBoundedPathBytes limit = go 0 []
 where
  go count reversed characters = case characters of
    [] -> LegacyBoundedWithin (reverse reversed)
    character : rest ->
      let next = count + legacyPathUtf8CharacterBytes character
       in if
#if defined(VALIDATION_LEGACY_INTERNAL_PATH_PREFIX_THRESHOLD_MUTANT)
            next >= limit
#else
            next > limit
#endif
            then LegacyBoundedExceeded next (reverse reversed)
            else go next (character : reversed) rest

legacyPathUtf8CharacterBytes :: Char -> Int
legacyPathUtf8CharacterBytes character
  | code <= 0x7f =
#if defined(VALIDATION_LEGACY_INTERNAL_PATH_UTF8_ASCII_WIDTH_MUTANT)
      2
#else
      1
#endif
  | code <= 0x7ff =
#if defined(VALIDATION_LEGACY_INTERNAL_PATH_UTF8_TWO_WIDTH_MUTANT)
      1
#else
      2
#endif
  | code <= 0xffff =
#if defined(VALIDATION_LEGACY_INTERNAL_PATH_UTF8_THREE_WIDTH_MUTANT)
      2
#else
      3
#endif
  | otherwise =
#if defined(VALIDATION_LEGACY_INTERNAL_PATH_UTF8_FOUR_WIDTH_MUTANT)
      3
#else
      4
#endif
 where
  code = ord character

legacyRegisterEntryLimitExceeded, legacyRegisterPathLimitExceeded, legacyRegisterByteLimitExceeded :: Int -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_ENTRY_LIMIT_BYPASS_MUTANT)
legacyRegisterEntryLimitExceeded _ = False
#else
legacyRegisterEntryLimitExceeded observed = observed > maximumLegacyTrackedEntries
#endif
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_PATH_LIMIT_BYPASS_MUTANT)
legacyRegisterPathLimitExceeded _ = False
#else
legacyRegisterPathLimitExceeded observed = observed > maximumLegacyTrackedPathBytes
#endif
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_BYTE_LIMIT_BYPASS_MUTANT)
legacyRegisterByteLimitExceeded _ = False
#else
legacyRegisterByteLimitExceeded observed = observed > maximumLegacyRegisterBytes
#endif

guardedRegisterResourceProblem :: Text -> Bool -> RegisterProblem -> RegisterProblem
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_GUARD_ROUTE_MUTANT)
guardedRegisterResourceProblem label predicate specific =
  predicate `seq` specific `seq` RegisterResourceGuardUnavailable label
#else
guardedRegisterResourceProblem label predicate specific
  | predicate = specific
  | otherwise = RegisterResourceGuardUnavailable label
#endif

legacyCheck :: Policy.PhaseOrdinal -> SourceSnapshot -> CheckResult
legacyCheck candidatePhase snapshot =
  legacyRawCheckRefusalComposition
    ( legacyCheckCore
        candidatePhase
        snapshot
        Nothing
        Nothing
        rawClosureCheck
        rawDebtCheck
        rawConsumerCheck
    )
 where
  -- A caller-authored snapshot is not the exact local capture.  These
  -- fixed role-labelled refusals are constructed without classifying a blob,
  -- traversing a consumer graph, or invoking a nested source analyzer.  The
  -- only snapshot traversal that remains is the literal structural register
  -- preflight inside legacyCheckCore.
  rawClosureCheck =
#if defined(VALIDATION_LEGACY_INTERNAL_RAW_CLOSURE_ROUTE_MUTANT)
    legacyRawCaptureUnavailable "source-closure" `seq`
      CheckResult "legacy-mutated-closure-route" [] []
#else
    legacyRawCaptureUnavailable "source-closure"
#endif
  rawDebtCheck =
#if defined(VALIDATION_LEGACY_INTERNAL_RAW_DEBT_ROUTE_MUTANT)
    legacyRawCaptureUnavailable "source-debt" `seq`
      CheckResult "legacy-mutated-debt-route" [] []
#else
    legacyRawCaptureUnavailable "source-debt"
#endif
  rawConsumerCheck =
#if defined(VALIDATION_LEGACY_INTERNAL_RAW_CONSUMER_ROUTE_MUTANT)
    legacyRawCaptureUnavailable "source-consumer" `seq`
      CheckResult "legacy-mutated-consumer-route" [] []
#else
    legacyRawCaptureUnavailable "source-consumer"
#endif

legacyRawCheckRefusalComposition :: CheckResult -> CheckResult
#if defined(VALIDATION_LEGACY_INTERNAL_RAW_CHECK_REFUSAL_COMPOSITION_MUTANT)
legacyRawCheckRefusalComposition result =
  appendLegacySnapshotDiagnosticRefusal result `seq` result
#else
legacyRawCheckRefusalComposition = appendLegacySnapshotDiagnosticRefusal
#endif

legacyRawCaptureUnavailable :: Text -> CheckResult
legacyRawCaptureUnavailable role =
  CheckResult
    { checkName = legacyRawCaptureResultName
    , checkObservations = []
    , checkFindings = legacyRawCaptureFindings role
    }

legacyRawCaptureResultName :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_RAW_CAPTURE_RESULT_NAME_MUTANT)
legacyRawCaptureResultName = "legacy-raw-capture-mutated"
#else
legacyRawCaptureResultName = "legacy-raw-capture-unavailable"
#endif

legacyRawCaptureFindings :: Text -> [Finding]
#if defined(VALIDATION_LEGACY_INTERNAL_RAW_CAPTURE_FINDING_DROP_MUTANT)
legacyRawCaptureFindings role =
  legacyRawCaptureFinding role `seq` []
#else
legacyRawCaptureFindings role = [legacyRawCaptureFinding role]
#endif

legacyRawCaptureFinding :: Text -> Finding
#if defined(VALIDATION_LEGACY_INTERNAL_RAW_CAPTURE_FINDING_COMPOSITION_MUTANT)
legacyRawCaptureFinding role =
  finding
    (legacyRawCaptureDetail role)
    (legacyRawCaptureSubject role)
    legacyRawCaptureCode
#else
legacyRawCaptureFinding role =
  finding
    legacyRawCaptureCode
    (legacyRawCaptureSubject role)
    (legacyRawCaptureDetail role)
#endif

legacyRawCaptureCode :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_RAW_CAPTURE_CODE_MUTANT)
legacyRawCaptureCode = "LEGACY-MUTATED"
#else
legacyRawCaptureCode = "LEGACY-RAW-CAPTURE-UNAVAILABLE"
#endif

legacyRawCaptureSubject :: Text -> FilePath
#if defined(VALIDATION_LEGACY_INTERNAL_RAW_CAPTURE_SUBJECT_MUTANT)
legacyRawCaptureSubject _ = "<mutated>"
#else
legacyRawCaptureSubject role =
  "Amoebius.Validation.Legacy.Internal/" <> Text.unpack role
#endif

legacyRawCaptureDetail :: Text -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_RAW_CAPTURE_DETAIL_MUTANT)
legacyRawCaptureDetail _ = "mutated"
#else
legacyRawCaptureDetail role =
  "caller-authored snapshots cannot invoke the captured analyzer route; role=" <> role
#endif

-- | Candidate legacy evaluation over the opaque acquired snapshot and the
-- compiler evidence derived from that same capture.  Neither constructor
-- is caller-accessible.  A mismatched evidence wrapper refuses explicitly.
legacyCheckAcquired
  :: Policy.PhaseOrdinal
  -> AcquiredSourceSnapshot
  -> CompilerSourceAttempt
  -> SourceDebtEvidence
  -> AcquiredPhaseContractEvidence
  -> CheckResult
legacyCheckAcquired candidatePhase acquired compilerAttempt debtEvidence contractEvidence =
  legacyCheckAcquiredWithGateCompletion
    candidatePhase
    acquired
    compilerAttempt
    debtEvidence
    contractEvidence
    Nothing

-- | Finalize the legacy row after the evidence layer has captured every
-- non-circular prerequisite.  The only result capable of populating the
-- candidate's @Legacy closure@ row is this opaque wrapper; the ordinary
-- acquired check above remains useful as a fail-closed component diagnostic
-- but cannot be substituted as row authority.
legacyClosureAcquired
  :: Policy.PhaseOrdinal
  -> AcquiredSourceSnapshot
  -> CompilerSourceAttempt
  -> SourceDebtEvidence
  -> AcquiredPhaseContractEvidence
  -> GateCompletionPremises
  -> LegacyClosure
legacyClosureAcquired candidatePhase acquired compilerAttempt debtEvidence contractEvidence premises =
  LegacyClosure
    ( legacyCheckAcquiredWithGateCompletion
        candidatePhase
        acquired
        compilerAttempt
        debtEvidence
        contractEvidence
        (Just premises)
    )

legacyClosureResult :: LegacyClosure -> CheckResult
legacyClosureResult (LegacyClosure result) = result

legacyCheckAcquiredWithGateCompletion
  :: Policy.PhaseOrdinal
  -> AcquiredSourceSnapshot
  -> CompilerSourceAttempt
  -> SourceDebtEvidence
  -> AcquiredPhaseContractEvidence
  -> Maybe GateCompletionPremises
  -> CheckResult
legacyCheckAcquiredWithGateCompletion candidatePhase acquired compilerAttempt debtEvidence contractEvidence gateCompletion =
  let compilerEvidence = compilerSourceAttemptDiagnostic compilerAttempt
      snapshot = acquiredSourceSnapshot acquired
      result =
        legacyCheckCore
          candidatePhase
          snapshot
          (Just (acquired, debtEvidence, contractEvidence))
          gateCompletion
          (sourceClosureCheckAcquired acquired)
          (sourceDebtEvidenceCheck acquired debtEvidence)
          (compilerSourceAttemptCheck compilerAttempt)
   in appendCompilerSnapshotMismatchFinding
        (acquiredCompilerSnapshotIdentity compilerEvidence)
        (snapshotIdentity snapshot)
        result

appendCompilerSnapshotMismatchFinding :: Text -> Text -> CheckResult -> CheckResult
appendCompilerSnapshotMismatchFinding compilerIdentity sourceIdentity result =
  result
    { checkFindings =
#if defined(VALIDATION_LEGACY_INTERNAL_COMPILER_SNAPSHOT_FINDING_ORDER_MUTANT)
        compilerSnapshotMismatchFindings compilerIdentity sourceIdentity
          <> checkFindings result
#else
        checkFindings result
          <> compilerSnapshotMismatchFindings compilerIdentity sourceIdentity
#endif
    }

compilerSnapshotMismatchFindings :: Text -> Text -> [Finding]
#if defined(VALIDATION_LEGACY_INTERNAL_COMPILER_SNAPSHOT_FINDING_RETENTION_MUTANT)
compilerSnapshotMismatchFindings compilerIdentity sourceIdentity =
  compilerSnapshotIdentityMismatch compilerIdentity sourceIdentity `seq`
    compilerSnapshotMismatchFinding `seq` []
#else
compilerSnapshotMismatchFindings compilerIdentity sourceIdentity =
  [ compilerSnapshotMismatchFinding
  | compilerSnapshotIdentityMismatch compilerIdentity sourceIdentity
  ]
#endif

compilerSnapshotMismatchFinding :: Finding
#if defined(VALIDATION_LEGACY_INTERNAL_COMPILER_SNAPSHOT_FINDING_COMPOSITION_MUTANT)
compilerSnapshotMismatchFinding =
  finding compilerSnapshotMismatchDetail compilerSnapshotMismatchSubject compilerSnapshotMismatchCode
#else
compilerSnapshotMismatchFinding =
  finding compilerSnapshotMismatchCode compilerSnapshotMismatchSubject compilerSnapshotMismatchDetail
#endif

compilerSnapshotIdentityMismatch :: Text -> Text -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_COMPILER_SNAPSHOT_MATCH_BYPASS_MUTANT)
compilerSnapshotIdentityMismatch _ _ = False
#else
compilerSnapshotIdentityMismatch compilerIdentity sourceIdentity = compilerIdentity /= sourceIdentity
#endif

compilerSnapshotMismatchCode :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_COMPILER_SNAPSHOT_CODE_MUTANT)
compilerSnapshotMismatchCode = "LEGACY-MUTATED"
#else
compilerSnapshotMismatchCode = "LEGACY-COMPILER-SNAPSHOT-MISMATCH"
#endif

compilerSnapshotMismatchSubject :: FilePath
#if defined(VALIDATION_LEGACY_INTERNAL_COMPILER_SNAPSHOT_SUBJECT_MUTANT)
compilerSnapshotMismatchSubject = "<mutated>"
#else
compilerSnapshotMismatchSubject = legacySemanticSubject
#endif

compilerSnapshotMismatchDetail :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_COMPILER_SNAPSHOT_DETAIL_MUTANT)
compilerSnapshotMismatchDetail = "mutated"
#else
compilerSnapshotMismatchDetail =
  "the captured compiler evidence is bound to a different source snapshot"
#endif

legacyCheckCore
  :: Policy.PhaseOrdinal
  -> SourceSnapshot
  -> Maybe (AcquiredSourceSnapshot, SourceDebtEvidence, AcquiredPhaseContractEvidence)
  -> Maybe GateCompletionPremises
  -> CheckResult
  -> CheckResult
  -> CheckResult
  -> CheckResult
legacyCheckCore candidatePhase snapshot acquiredDebtEvidence gateCompletion closureCheck debtCheck consumerCheck =
  CheckResult
    { checkName = legacyCoreResultName semanticCheck
    , checkObservations = legacyCoreObservations semanticCheck structuralObservations
    , checkFindings = legacyCoreFindings semanticCheck structuralFindings
    }
 where
  semanticCheck =
    legacyCandidateInventoryCheck
      candidatePhase
      snapshot
      (closedLegacyEvidenceRegistry snapshot acquiredDebtEvidence gateCompletion closureCheck debtCheck consumerCheck)
  (structuralObservations, structuralFindings) = case activeRegisterFromSnapshot snapshot of
    Left problems -> ([], map registerFinding problems)
    Right register ->
      ( legacyStructuralRegisterObservations register snapshot
      , []
      )

legacyStructuralRegisterObservations :: ActiveRegister -> SourceSnapshot -> [Observation]
#if defined(VALIDATION_LEGACY_INTERNAL_STRUCTURAL_OBSERVATION_ORDER_MUTANT)
legacyStructuralRegisterObservations register snapshot =
  legacyRegisterCardinalityObservation
    <> legacyRegisterPathObservation register
    <> legacyRegisterModeObservation
    <> legacyRegisterEncodingObservation
    <> legacyRegisterSnapshotObservation snapshot
#else
legacyStructuralRegisterObservations register snapshot =
  legacyRegisterPathObservation register
    <> legacyRegisterCardinalityObservation
    <> legacyRegisterModeObservation
    <> legacyRegisterEncodingObservation
    <> legacyRegisterSnapshotObservation snapshot
#endif

legacyCoreResultName :: CheckResult -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_CORE_RESULT_NAME_ROUTE_MUTANT)
legacyCoreResultName _ = "legacy-core-mutated"
#else
legacyCoreResultName = checkName
#endif

legacyCoreObservations :: CheckResult -> [Observation] -> [Observation]
#if defined(VALIDATION_LEGACY_INTERNAL_CORE_OBSERVATION_COMPOSITION_MUTANT)
legacyCoreObservations semantic structural = structural <> checkObservations semantic
#else
legacyCoreObservations semantic structural = checkObservations semantic <> structural
#endif

legacyCoreFindings :: CheckResult -> [Finding] -> [Finding]
#if defined(VALIDATION_LEGACY_INTERNAL_CORE_FINDING_COMPOSITION_MUTANT)
legacyCoreFindings semantic structural = structural <> checkFindings semantic
#else
legacyCoreFindings semantic structural = checkFindings semantic <> structural
#endif

legacyRegisterPathObservation :: ActiveRegister -> [Observation]
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_PATH_OBSERVATION_DROP_MUTANT)
legacyRegisterPathObservation register =
  legacyRegisterPathObservationKey `seq`
    legacyRegisterPathObservationValue register `seq` []
#else
legacyRegisterPathObservation register =
  [ observation legacyRegisterPathObservationKey
      (legacyRegisterPathObservationValue register)
  ]
#endif

legacyRegisterPathObservationKey :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_PATH_OBSERVATION_KEY_MUTANT)
legacyRegisterPathObservationKey = "legacy.register.mutated"
#else
legacyRegisterPathObservationKey = "legacy.register.path"
#endif

legacyRegisterPathObservationValue :: ActiveRegister -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_PATH_OBSERVATION_VALUE_MUTANT)
legacyRegisterPathObservationValue _ = "mutated"
#else
legacyRegisterPathObservationValue = Text.pack . activeRegisterPath
#endif

legacyRegisterCardinalityObservation :: [Observation]
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_CARDINALITY_OBSERVATION_DROP_MUTANT)
legacyRegisterCardinalityObservation =
  legacyRegisterCardinalityObservationKey `seq`
    legacyRegisterCardinalityObservationValue `seq` []
#else
legacyRegisterCardinalityObservation =
  [observation legacyRegisterCardinalityObservationKey legacyRegisterCardinalityObservationValue]
#endif

legacyRegisterCardinalityObservationKey, legacyRegisterCardinalityObservationValue :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_CARDINALITY_OBSERVATION_KEY_MUTANT)
legacyRegisterCardinalityObservationKey = "legacy.register.mutated"
#else
legacyRegisterCardinalityObservationKey = "legacy.register.cardinality"
#endif
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_CARDINALITY_OBSERVATION_VALUE_MUTANT)
legacyRegisterCardinalityObservationValue = "mutated"
#else
legacyRegisterCardinalityObservationValue = "1"
#endif

legacyRegisterModeObservation :: [Observation]
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_MODE_OBSERVATION_DROP_MUTANT)
legacyRegisterModeObservation =
  legacyRegisterModeObservationKey `seq` legacyRegisterModeObservationValue `seq` []
#else
legacyRegisterModeObservation =
  [observation legacyRegisterModeObservationKey legacyRegisterModeObservationValue]
#endif

legacyRegisterModeObservationKey, legacyRegisterModeObservationValue :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_MODE_OBSERVATION_KEY_MUTANT)
legacyRegisterModeObservationKey = "legacy.register.mutated"
#else
legacyRegisterModeObservationKey = "legacy.register.index-mode"
#endif
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_MODE_OBSERVATION_VALUE_MUTANT)
legacyRegisterModeObservationValue = "mutated"
#else
legacyRegisterModeObservationValue = "100644"
#endif

legacyRegisterEncodingObservation :: [Observation]
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_ENCODING_OBSERVATION_DROP_MUTANT)
legacyRegisterEncodingObservation =
  legacyRegisterEncodingObservationKey `seq`
    legacyRegisterEncodingObservationValue `seq` []
#else
legacyRegisterEncodingObservation =
  [observation legacyRegisterEncodingObservationKey legacyRegisterEncodingObservationValue]
#endif

legacyRegisterEncodingObservationKey, legacyRegisterEncodingObservationValue :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_ENCODING_OBSERVATION_KEY_MUTANT)
legacyRegisterEncodingObservationKey = "legacy.register.mutated"
#else
legacyRegisterEncodingObservationKey = "legacy.register.encoding"
#endif
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_ENCODING_OBSERVATION_VALUE_MUTANT)
legacyRegisterEncodingObservationValue = "mutated"
#else
legacyRegisterEncodingObservationValue = "UTF-8"
#endif

legacyRegisterSnapshotObservation :: SourceSnapshot -> [Observation]
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_SNAPSHOT_OBSERVATION_DROP_MUTANT)
legacyRegisterSnapshotObservation snapshot =
  legacyRegisterSnapshotObservationKey `seq`
    legacyRegisterSnapshotObservationValue snapshot `seq` []
#else
legacyRegisterSnapshotObservation snapshot =
  [observation legacyRegisterSnapshotObservationKey (legacyRegisterSnapshotObservationValue snapshot)]
#endif

legacyRegisterSnapshotObservationKey :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_SNAPSHOT_OBSERVATION_KEY_MUTANT)
legacyRegisterSnapshotObservationKey = "legacy.register.mutated"
#else
legacyRegisterSnapshotObservationKey = "legacy.register.snapshot"
#endif

legacyRegisterSnapshotObservationValue :: SourceSnapshot -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_SNAPSHOT_OBSERVATION_VALUE_MUTANT)
legacyRegisterSnapshotObservationValue _ = "mutated"
#else
legacyRegisterSnapshotObservationValue = snapshotIdentity
#endif

appendLegacySnapshotDiagnosticRefusal :: CheckResult -> CheckResult
appendLegacySnapshotDiagnosticRefusal result =
  result
    { checkFindings =
#if defined(VALIDATION_LEGACY_INTERNAL_SNAPSHOT_REFUSAL_ORDER_MUTANT)
        snapshotDiagnosticRefusalFindings
          <> checkFindings result
#else
        checkFindings result
          <> snapshotDiagnosticRefusalFindings
#endif
    }

snapshotDiagnosticRefusalFindings :: [Finding]
#if defined(VALIDATION_LEGACY_INTERNAL_SNAPSHOT_REFUSAL_DROP_MUTANT)
snapshotDiagnosticRefusalFindings =
  finding snapshotDiagnosticRefusalCode snapshotDiagnosticRefusalSubject snapshotDiagnosticRefusalDetail
    `seq` []
#else
snapshotDiagnosticRefusalFindings =
#if defined(VALIDATION_LEGACY_INTERNAL_SNAPSHOT_REFUSAL_FINDING_COMPOSITION_MUTANT)
  [ finding snapshotDiagnosticRefusalDetail snapshotDiagnosticRefusalSubject snapshotDiagnosticRefusalCode ]
#else
  [ finding snapshotDiagnosticRefusalCode snapshotDiagnosticRefusalSubject snapshotDiagnosticRefusalDetail ]
#endif
#endif

snapshotDiagnosticRefusalCode :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_SNAPSHOT_REFUSAL_CODE_MUTANT)
snapshotDiagnosticRefusalCode = "LEGACY-MUTATED"
#else
snapshotDiagnosticRefusalCode = "LEGACY-SNAPSHOT-DIAGNOSTIC-ONLY"
#endif

snapshotDiagnosticRefusalSubject :: FilePath
#if defined(VALIDATION_LEGACY_INTERNAL_SNAPSHOT_REFUSAL_SUBJECT_MUTANT)
snapshotDiagnosticRefusalSubject = "<mutated>"
#else
snapshotDiagnosticRefusalSubject = legacySemanticSubject
#endif

snapshotDiagnosticRefusalDetail :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_SNAPSHOT_REFUSAL_DETAIL_MUTANT)
snapshotDiagnosticRefusalDetail = "mutated"
#else
snapshotDiagnosticRefusalDetail =
  "a caller-authored SourceSnapshot and its derived legacy observations cannot be candidate evidence"
#endif

-- | Candidate evaluation is closed over an opaque, snapshot-bound analyzer
-- registry.  Unlike 'legacyInventoryDiagnostic', there is no argument through
-- which a caller can inject an observation or claim that an analyzer ran.
legacyCandidateInventoryCheck :: Policy.PhaseOrdinal -> SourceSnapshot -> Map LegacyId ClosedLegacyEvidence -> CheckResult
legacyCandidateInventoryCheck candidatePhase snapshot registry =
  CheckResult
    { checkName = legacyInventoryResultName
    , checkObservations =
        legacyCandidateObservationComposition
          (legacyInventoryFixedObservations candidatePhase)
          (legacyEvidenceSnapshotObservation snapshot)
          (legacyInventoryEvaluatedObservations evaluated)
    , checkFindings =
        legacyCandidateFindingComposition
          universeIntegrityFindings
          (closedEvidenceIntegrityFindings snapshot registry)
          (legacyInventoryEvaluatedFindings evaluated)
    }
 where
  evaluated =
    legacyInventoryEvaluationOrder
      [ evaluateCanonicalBinding
          candidatePhase
          (legacyBinding identifier)
          (closedEvidenceObservationForCandidate candidatePhase =<< Map.lookup identifier registry)
      | identifier <- canonicalLegacyUniverse
      ]

-- | A zero observation at its owning phase is only candidate-ready after the
-- row's independently executed reintroduction negatives are bound to the
-- same source snapshot.  This closes the former loophole where, notably,
-- @LTD-SRC-008@ could report zero from static @pb@ grammar alone while its
-- required widened-bootstrap negative had never run.
closedEvidenceObservationForCandidate :: Policy.PhaseOrdinal -> ClosedLegacyEvidence -> Maybe LegacyObservation
closedEvidenceObservationForCandidate candidatePhase evidence =
  case closedEvidenceObservation evidence of
    Just observed@(LegacyObservation analyzer LegacyObservedZero)
      | zeroOwnerRelation candidatePhase (Just owner) == OwnerAt ->
          case legacyReintroductionWitnessProblems evidence of
            [] -> Just observed
            problems ->
              Just
                ( LegacyObservation
                    analyzer
                    ( LegacyObservationRefused
                        ( "owner-domain reintroduction evidence is unavailable or invalid: "
                            <> Text.intercalate "; " problems
                        )
                    )
                )
      where
        owner = legacyIdOwner (closedEvidenceId evidence)
    other -> other

legacyReintroductionWitnessProblems :: ClosedLegacyEvidence -> [Text]
legacyReintroductionWitnessProblems evidence =
  case closedEvidenceReintroduction evidence of
    Nothing -> ["no executed reintroduction witness"]
    Just witness ->
      [ "witness names a different legacy row"
      | legacyReintroductionWitnessId witness /= identifier
      ]
        <> [ "witness names a different source snapshot"
           | legacyReintroductionWitnessSnapshot witness /= closedEvidenceSnapshot evidence
           ]
        <> [ "witness case inventory differs from the canonical binding"
           | legacyReintroductionWitnessCases witness /= legacyIdReintroductionCases identifier
           ]
        <> [ "witness transcript identity is not lowercase SHA-256"
           | not (legacySha256Identity (legacyReintroductionWitnessTranscript witness))
           ]
  where
    identifier = closedEvidenceId evidence

legacySha256Identity :: Text -> Bool
legacySha256Identity value =
  Text.length value == 64
    && Text.all
      (\character -> (character >= '0' && character <= '9') || (character >= 'a' && character <= 'f'))
      value

legacyCandidateObservationComposition
  :: [Observation] -> [Observation] -> [Observation] -> [Observation]
#if defined(VALIDATION_LEGACY_INTERNAL_CANDIDATE_OBSERVATION_ORDER_MUTANT)
legacyCandidateObservationComposition fixed evidence evaluated =
  evidence <> fixed <> evaluated
#else
legacyCandidateObservationComposition fixed evidence evaluated =
  fixed <> evidence <> evaluated
#endif

legacyCandidateFindingComposition :: [Finding] -> [Finding] -> [Finding] -> [Finding]
#if defined(VALIDATION_LEGACY_INTERNAL_CANDIDATE_FINDING_ORDER_MUTANT)
legacyCandidateFindingComposition universe evidence evaluated =
  evidence <> universe <> evaluated
#else
legacyCandidateFindingComposition universe evidence evaluated =
  universe <> evidence <> evaluated
#endif

legacyEvidenceSnapshotObservation :: SourceSnapshot -> [Observation]
#if defined(VALIDATION_LEGACY_INTERNAL_EVIDENCE_SNAPSHOT_OBSERVATION_DROP_MUTANT)
legacyEvidenceSnapshotObservation snapshot =
  legacyEvidenceSnapshotObservationKey `seq`
    legacyEvidenceSnapshotObservationValue snapshot `seq` []
#else
legacyEvidenceSnapshotObservation snapshot =
  [ observation legacyEvidenceSnapshotObservationKey
      (legacyEvidenceSnapshotObservationValue snapshot)
  ]
#endif

legacyEvidenceSnapshotObservationKey :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_EVIDENCE_SNAPSHOT_OBSERVATION_KEY_MUTANT)
legacyEvidenceSnapshotObservationKey = "legacy.evidence.mutated"
#else
legacyEvidenceSnapshotObservationKey = "legacy.evidence.snapshot"
#endif

legacyEvidenceSnapshotObservationValue :: SourceSnapshot -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_EVIDENCE_SNAPSHOT_OBSERVATION_VALUE_MUTANT)
legacyEvidenceSnapshotObservationValue _ = "mutated"
#else
legacyEvidenceSnapshotObservationValue = snapshotIdentity
#endif

closedEvidenceIntegrityFindings :: SourceSnapshot -> Map LegacyId ClosedLegacyEvidence -> [Finding]
closedEvidenceIntegrityFindings snapshot registry =
  legacyClosedEvidenceFindingComposition
    keyFindings
    (concatMap entryFindings (Map.toAscList registry))
 where
  expectedKeys = canonicalLegacyUniverse
  actualKeys = Map.keys registry
  keyFindings =
    [ closedEvidenceFinding
        ClosedRegistryInventory
        "LEGACY-ANALYZER-REGISTRY-INVENTORY"
        legacySemanticSubject
        ( "closed analyzer registry keys differ: expected="
            <> showText (map renderLegacyId expectedKeys)
            <> ", actual="
            <> showText (map renderLegacyId actualKeys)
        )
    | closedRegistryKeysMismatch actualKeys expectedKeys
    ]
  entryFindings (identifier, evidence) =
    legacyClosedEvidenceEntryFindingComposition
      [ closedEvidenceFinding
          ClosedEvidenceId
          "LEGACY-ANALYZER-EVIDENCE-ID"
          (legacySubject identifier)
          "closed analyzer evidence is bound to a different legacy row"
      | closedEvidenceIdMismatch (closedEvidenceId evidence) identifier
      ]
      [ closedEvidenceFinding
          ClosedEvidenceSourceDebt
          "LEGACY-ANALYZER-EVIDENCE-SOURCE-DEBT"
          (legacySubject identifier)
          "closed analyzer evidence is bound to the wrong source-debt family"
      | closedEvidenceSourceDebtMismatch (closedEvidenceSourceDebtId evidence) (legacySourceDebtId identifier)
      ]
      [ closedEvidenceFinding
          ClosedEvidenceAnalyzer
          "LEGACY-ANALYZER-EVIDENCE-KEY"
          (legacySubject identifier)
          "closed analyzer evidence is bound to a non-canonical analyzer"
      | closedEvidenceAnalyzerMismatch (closedEvidenceAnalyzer evidence) (legacyIdAnalyzer identifier)
      ]
      [ closedEvidenceFinding
          ClosedEvidenceSnapshot
          "LEGACY-ANALYZER-EVIDENCE-SNAPSHOT"
          (legacySubject identifier)
          "closed analyzer evidence was produced for a different source snapshot"
      | closedEvidenceSnapshotMismatch (closedEvidenceSnapshot evidence) (snapshotIdentity snapshot)
      ]
      (case closedEvidenceObservation evidence of
        Just supplied
          | closedEvidenceObservationMismatch (legacyObservationAnalyzer supplied) (closedEvidenceAnalyzer evidence) ->
              [ closedEvidenceFinding
                  ClosedEvidenceObservation
                  "LEGACY-ANALYZER-EVIDENCE-OBSERVATION"
                  (legacySubject identifier)
                  "closed evidence and its observation name different analyzers"
              ]
        _ -> [])

legacyClosedEvidenceFindingComposition :: [Finding] -> [Finding] -> [Finding]
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_FINDING_ORDER_MUTANT)
legacyClosedEvidenceFindingComposition keys entries = entries <> keys
#else
legacyClosedEvidenceFindingComposition keys entries = keys <> entries
#endif

legacyClosedEvidenceEntryFindingComposition
  :: [Finding] -> [Finding] -> [Finding] -> [Finding] -> [Finding] -> [Finding]
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_ENTRY_ORDER_MUTANT)
legacyClosedEvidenceEntryFindingComposition identifier source analyzer snapshot observed =
  source <> identifier <> analyzer <> snapshot <> observed
#else
legacyClosedEvidenceEntryFindingComposition identifier source analyzer snapshot observed =
  identifier <> source <> analyzer <> snapshot <> observed
#endif

data ClosedEvidenceFindingKind
  = ClosedRegistryInventory
  | ClosedEvidenceId
  | ClosedEvidenceSourceDebt
  | ClosedEvidenceAnalyzer
  | ClosedEvidenceSnapshot
  | ClosedEvidenceObservation

closedRegistryKeysMismatch :: [LegacyId] -> [LegacyId] -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_REGISTRY_KEYS_BYPASS_MUTANT)
closedRegistryKeysMismatch _ _ = False
#else
closedRegistryKeysMismatch actual expected = actual /= expected
#endif

closedEvidenceIdMismatch :: LegacyId -> LegacyId -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_ID_BYPASS_MUTANT)
closedEvidenceIdMismatch _ _ = False
#else
closedEvidenceIdMismatch actual expected = actual /= expected
#endif

closedEvidenceSourceDebtMismatch :: Maybe SourceDebtId -> Maybe SourceDebtId -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_SOURCE_DEBT_BYPASS_MUTANT)
closedEvidenceSourceDebtMismatch _ _ = False
#else
closedEvidenceSourceDebtMismatch actual expected = actual /= expected
#endif

closedEvidenceAnalyzerMismatch :: LegacyAnalyzer -> LegacyAnalyzer -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_ANALYZER_BYPASS_MUTANT)
closedEvidenceAnalyzerMismatch _ _ = False
#else
closedEvidenceAnalyzerMismatch actual expected = actual /= expected
#endif

closedEvidenceSnapshotMismatch :: Text -> Text -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_SNAPSHOT_BYPASS_MUTANT)
closedEvidenceSnapshotMismatch _ _ = False
#else
closedEvidenceSnapshotMismatch actual expected = actual /= expected
#endif

closedEvidenceObservationMismatch :: LegacyAnalyzer -> LegacyAnalyzer -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_OBSERVATION_BYPASS_MUTANT)
closedEvidenceObservationMismatch _ _ = False
#else
closedEvidenceObservationMismatch actual expected = actual /= expected
#endif

closedEvidenceFinding :: ClosedEvidenceFindingKind -> Text -> FilePath -> Text -> Finding
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_FINDING_COMPOSITION_MUTANT)
closedEvidenceFinding kind code subject detail =
  finding
    (closedEvidenceFindingDetail kind detail)
    (closedEvidenceFindingSubject kind subject)
    (closedEvidenceFindingCode kind code)
#else
closedEvidenceFinding kind code subject detail =
  finding (closedEvidenceFindingCode kind code) (closedEvidenceFindingSubject kind subject) (closedEvidenceFindingDetail kind detail)
#endif

closedEvidenceFindingCode :: ClosedEvidenceFindingKind -> Text -> Text
closedEvidenceFindingCode kind code = case kind of
  ClosedRegistryInventory ->
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_REGISTRY_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    code
#endif
  ClosedEvidenceId ->
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_ID_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    code
#endif
  ClosedEvidenceSourceDebt ->
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_SOURCE_DEBT_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    code
#endif
  ClosedEvidenceAnalyzer ->
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_ANALYZER_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    code
#endif
  ClosedEvidenceSnapshot ->
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_SNAPSHOT_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    code
#endif
  ClosedEvidenceObservation ->
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_OBSERVATION_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    code
#endif

closedEvidenceFindingSubject :: ClosedEvidenceFindingKind -> FilePath -> FilePath
closedEvidenceFindingSubject kind subject = case kind of
  ClosedRegistryInventory ->
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_REGISTRY_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  ClosedEvidenceId ->
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_ID_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  ClosedEvidenceSourceDebt ->
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_SOURCE_DEBT_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  ClosedEvidenceAnalyzer ->
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_ANALYZER_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  ClosedEvidenceSnapshot ->
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_SNAPSHOT_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  ClosedEvidenceObservation ->
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_OBSERVATION_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif

closedEvidenceFindingDetail :: ClosedEvidenceFindingKind -> Text -> Text
closedEvidenceFindingDetail kind detail = case kind of
  ClosedRegistryInventory ->
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_REGISTRY_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  ClosedEvidenceId ->
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_ID_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  ClosedEvidenceSourceDebt ->
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_SOURCE_DEBT_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  ClosedEvidenceAnalyzer ->
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_ANALYZER_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  ClosedEvidenceSnapshot ->
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_SNAPSHOT_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  ClosedEvidenceObservation ->
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_OBSERVATION_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif

-- | The sole candidate analyzer dispatcher. Every legacy row has one registry
-- key. Implemented source analyzers execute here; due-but-unimplemented Phase-0
-- analyzers return an explicit refusal, and later-owned analyzers retain a
-- typed unavailable state until their owner implements them.
closedLegacyEvidenceRegistry
  :: SourceSnapshot
  -> Maybe (AcquiredSourceSnapshot, SourceDebtEvidence, AcquiredPhaseContractEvidence)
  -> Maybe GateCompletionPremises
  -> CheckResult
  -> CheckResult
  -> CheckResult
  -> Map LegacyId ClosedLegacyEvidence
closedLegacyEvidenceRegistry snapshot acquiredDebtEvidence gateCompletion closureCheck debtCheck consumerCheck =
  Map.fromList [legacyRegistryPair evidence | evidence <- candidateEntries]
 where
  candidateEntries =
    canonicalEntries
  canonicalEntries =
    legacyCompleteEvidenceEntry snapshot completeState
      <> map (sourceDebtEvidence snapshot) sourceDebtUniverse
      <> map (nonSourceEvidence snapshot acquiredDebtEvidence gateCompletion) nonSourceLegacyUniverse
  completeFindings =
    legacyCompleteFindingOrder
      ( legacyCompleteContributionComposition
          (legacyClosureContribution closureCheck)
          (legacyDebtContribution debtCheck)
          (legacyConsumerContribution consumerCheck)
      )
  completeState = legacyCompleteObservedState completeFindings
  sourceDebtEvidence boundSnapshot sourceId =
    closedEvidence
      boundSnapshot
      (sourceDebtLegacyId sourceId)
      (Just sourceId)
      (Just (sourceState sourceId))
  sourceState sourceId = case acquiredDebtEvidence of
    Nothing ->
      legacyCallerSnapshotSourceState
    Just (acquired, evidence, _) ->
      foldAcquiredSourceDebtState
        acquired
        evidence
        sourceId
        LegacyObservationRefused
        LegacyObservedZero
        LegacyObservedOpen

legacyCompleteContributionComposition
  :: [Finding] -> [Finding] -> [Finding] -> [Finding]
#if defined(VALIDATION_LEGACY_INTERNAL_COMPLETE_CONTRIBUTION_ORDER_MUTANT)
legacyCompleteContributionComposition closure debt consumer = debt <> closure <> consumer
#else
legacyCompleteContributionComposition closure debt consumer = closure <> debt <> consumer
#endif

legacyRegistryPair :: ClosedLegacyEvidence -> (LegacyId, ClosedLegacyEvidence)
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTRY_KEY_ROUTE_MUTANT)
legacyRegistryPair evidence = (LtdSrc000, evidence)
#else
legacyRegistryPair evidence = (closedEvidenceId evidence, evidence)
#endif

legacyCompleteEvidenceEntry :: SourceSnapshot -> LegacyObservedState -> [ClosedLegacyEvidence]
#if defined(VALIDATION_LEGACY_INTERNAL_COMPLETE_EVIDENCE_DROP_MUTANT)
legacyCompleteEvidenceEntry snapshot state =
  closedEvidence snapshot LtdSrc000 Nothing (Just state) `seq` []
#else
legacyCompleteEvidenceEntry snapshot state =
  [closedEvidence snapshot LtdSrc000 Nothing (Just state)]
#endif

legacyClosureContribution, legacyDebtContribution, legacyConsumerContribution :: CheckResult -> [Finding]
#if defined(VALIDATION_LEGACY_INTERNAL_COMPLETE_CLOSURE_CONTRIBUTION_DROP_MUTANT)
legacyClosureContribution result = length (checkFindings result) `seq` []
#else
legacyClosureContribution = checkFindings
#endif
#if defined(VALIDATION_LEGACY_INTERNAL_COMPLETE_DEBT_CONTRIBUTION_DROP_MUTANT)
legacyDebtContribution result = length (checkFindings result) `seq` []
#else
legacyDebtContribution = checkFindings
#endif
#if defined(VALIDATION_LEGACY_INTERNAL_COMPLETE_CONSUMER_CONTRIBUTION_DROP_MUTANT)
legacyConsumerContribution result = length (checkFindings result) `seq` []
#else
legacyConsumerContribution = checkFindings
#endif

legacyCompleteFindingOrder :: [Finding] -> [Finding]
#if defined(VALIDATION_LEGACY_INTERNAL_COMPLETE_FINDING_ORDER_MUTANT)
legacyCompleteFindingOrder = reverse
#else
legacyCompleteFindingOrder = id
#endif

legacyCompleteObservedState :: [Finding] -> LegacyObservedState
legacyCompleteObservedState findings = case findings of
  [] ->
#if defined(VALIDATION_LEGACY_INTERNAL_COMPLETE_ZERO_STATE_MUTANT)
    LegacyObservationRefused "mutated"
#else
    LegacyObservedZero
#endif
  _ ->
#if defined(VALIDATION_LEGACY_INTERNAL_COMPLETE_REFUSAL_STATE_MUTANT)
    Text.length
      ( legacyCompleteRefusalPrefix
          <> Text.intercalate legacyCompleteRefusalSeparator
            (map legacyCompleteFindingProjection findings)
      )
      `seq` LegacyObservedZero
#else
    LegacyObservationRefused
      ( legacyCompleteRefusalPrefix
          <> Text.intercalate legacyCompleteRefusalSeparator
            (map legacyCompleteFindingProjection findings)
      )
#endif

legacyCompleteRefusalPrefix :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_COMPLETE_REFUSAL_PREFIX_MUTANT)
legacyCompleteRefusalPrefix = "mutated: "
#else
legacyCompleteRefusalPrefix = "source closure is incomplete at: "
#endif

legacyCompleteRefusalSeparator :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_COMPLETE_REFUSAL_SEPARATOR_MUTANT)
legacyCompleteRefusalSeparator = "|"
#else
legacyCompleteRefusalSeparator = ","
#endif

legacyCompleteFindingCode :: Text -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_COMPLETE_FINDING_CODE_MUTANT)
legacyCompleteFindingCode _ = "LEGACY-MUTATED"
#else
legacyCompleteFindingCode = id
#endif

legacyCompleteFindingProjection :: Finding -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_COMPLETE_FINDING_PROJECTION_ORDER_MUTANT)
legacyCompleteFindingProjection item =
  legacyCompleteFindingFrame (legacyCompleteFindingDetail item)
    <> legacyCompleteFindingFrame (legacyCompleteFindingSubject item)
    <> legacyCompleteFindingFrame (legacyCompleteFindingCode (findingCode item))
#else
legacyCompleteFindingProjection item =
  legacyCompleteFindingFrame (legacyCompleteFindingCode (findingCode item))
    <> legacyCompleteFindingFrame (legacyCompleteFindingSubject item)
    <> legacyCompleteFindingFrame (legacyCompleteFindingDetail item)
#endif

legacyCompleteFindingSubject :: Finding -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_COMPLETE_FINDING_SUBJECT_MUTANT)
legacyCompleteFindingSubject _ = "mutated"
#else
legacyCompleteFindingSubject = Text.pack . findingSubject
#endif

legacyCompleteFindingDetail :: Finding -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_COMPLETE_FINDING_DETAIL_MUTANT)
legacyCompleteFindingDetail _ = "mutated"
#else
legacyCompleteFindingDetail = findingDetail
#endif

legacyCompleteFindingFrame :: Text -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_COMPLETE_FINDING_FRAME_COMPONENT_ORDER_MUTANT)
legacyCompleteFindingFrame value =
  value
    <> legacyCompleteFindingFrameSeparator
    <> legacyCompleteFindingFrameLength value
#else
legacyCompleteFindingFrame value =
  legacyCompleteFindingFrameLength value
    <> legacyCompleteFindingFrameSeparator
    <> value
#endif

legacyCompleteFindingFrameLength :: Text -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_COMPLETE_FINDING_FRAME_LENGTH_MUTANT)
legacyCompleteFindingFrameLength value =
  Text.pack (show (ByteString.length (TextEncoding.encodeUtf8 value) + 1))
#else
legacyCompleteFindingFrameLength value =
  Text.pack (show (ByteString.length (TextEncoding.encodeUtf8 value)))
#endif

legacyCompleteFindingFrameSeparator :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_COMPLETE_FINDING_FRAME_SEPARATOR_MUTANT)
legacyCompleteFindingFrameSeparator = "|"
#else
legacyCompleteFindingFrameSeparator = ":"
#endif

legacyCallerSnapshotSourceState :: LegacyObservedState
#if defined(VALIDATION_LEGACY_INTERNAL_CALLER_SOURCE_STATE_MUTANT)
legacyCallerSnapshotSourceState = LegacyObservedZero
#else
legacyCallerSnapshotSourceState =
  LegacyObservationRefused
    "caller-authored snapshots cannot supply candidate source-debt lifecycle evidence"
#endif

closedEvidence
  :: SourceSnapshot
  -> LegacyId
  -> Maybe SourceDebtId
  -> Maybe LegacyObservedState
  -> ClosedLegacyEvidence
closedEvidence snapshot identifier sourceDebtId state =
  ClosedLegacyEvidence
    { closedEvidenceId = closedEvidenceIdRoute identifier
    , closedEvidenceSourceDebtId = closedEvidenceSourceDebtRoute sourceDebtId
    , closedEvidenceAnalyzer = closedEvidenceAnalyzerRoute analyzer
    , closedEvidenceSnapshot = closedEvidenceSnapshotRoute snapshot
    , closedEvidenceObservation = closedEvidenceObservationRoute analyzer state
    , closedEvidenceReintroduction = Nothing
    }
 where
  analyzer = legacyIdAnalyzer identifier

closedEvidenceIdRoute :: LegacyId -> LegacyId
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_ID_ROUTE_MUTANT)
closedEvidenceIdRoute _ = LtdSrc000
#else
closedEvidenceIdRoute = id
#endif

closedEvidenceSourceDebtRoute :: Maybe SourceDebtId -> Maybe SourceDebtId
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_SOURCE_DEBT_ROUTE_MUTANT)
closedEvidenceSourceDebtRoute _ = Nothing
#else
closedEvidenceSourceDebtRoute = id
#endif

closedEvidenceAnalyzerRoute :: LegacyAnalyzer -> LegacyAnalyzer
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_ANALYZER_ROUTE_MUTANT)
closedEvidenceAnalyzerRoute _ = AnalyzeCompleteSourceGrammar
#else
closedEvidenceAnalyzerRoute = id
#endif

closedEvidenceSnapshotRoute :: SourceSnapshot -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_SNAPSHOT_ROUTE_MUTANT)
closedEvidenceSnapshotRoute _ = "mutated"
#else
closedEvidenceSnapshotRoute = snapshotIdentity
#endif

closedEvidenceObservationRoute :: LegacyAnalyzer -> Maybe LegacyObservedState -> Maybe LegacyObservation
#if defined(VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_OBSERVATION_ROUTE_MUTANT)
closedEvidenceObservationRoute _ _ = Nothing
#else
closedEvidenceObservationRoute analyzer state = LegacyObservation analyzer <$> state
#endif

-- | Route a non-source binding to its owner-domain analyzer.
--
-- Only the two seed bindings have one today; every other non-source binding
-- still reports the typed unimplemented state. Adding an analyzer here is what
-- retires that state for one binding, so this dispatch is the seam each future
-- owner-domain analyzer joins.
nonSourceEvidence
  :: SourceSnapshot
  -> Maybe (AcquiredSourceSnapshot, SourceDebtEvidence, AcquiredPhaseContractEvidence)
  -> Maybe GateCompletionPremises
  -> LegacyId
  -> ClosedLegacyEvidence
nonSourceEvidence snapshot acquiredDebtEvidence gateCompletion identifier
  | identifier == LtdVal002 =
      case acquiredDebtEvidence of
        Nothing -> unimplementedEvidence snapshot identifier
        Just (acquired, _, contractEvidence) ->
          closedEvidence
            snapshot
            identifier
            Nothing
            (Just (phaseContractObservedState acquired contractEvidence))
  | identifier == LtdVal004 =
      case gateCompletion of
        Nothing -> unimplementedEvidence snapshot identifier
        Just premises ->
          closedEvidence
            snapshot
            identifier
            Nothing
            (Just (gateCompletionObservedState premises))
  | seedLegacyDependencyRoot identifier == Nothing = unimplementedEvidence snapshot identifier
  | otherwise =
      closedEvidence
        snapshot
        identifier
        Nothing
        (Just seedState)
 where
  -- A caller-authored snapshot cannot observe a seed dependency, for the same
  -- reason it cannot observe source debt: it chooses its own bytes, so an
  -- absent @cabal.project@ would read as a closed binding. Only the captured
  -- snapshot reaches the analyzer.
  seedState = case acquiredDebtEvidence of
    Nothing -> legacyCallerSnapshotSourceState
    Just (acquired, _, _) ->
      seedDependencyState (acquiredSourceSnapshot acquired) identifier

phaseContractObservedState :: AcquiredSourceSnapshot -> AcquiredPhaseContractEvidence -> LegacyObservedState
phaseContractObservedState acquired evidence
  | acquiredPhaseContractEvidenceSnapshot evidence /= expectedSnapshot =
      LegacyObservationRefused "phase-contract evidence is bound to a different source snapshot"
  | null problems = LegacyObservedZero
  | otherwise =
      LegacyObservationRefused
        ( "the acquired Phase-0 contract/correspondence check refused: "
            <> Text.intercalate "," (map findingCode problems)
        )
 where
  expectedSnapshot = snapshotIdentity (acquiredSourceSnapshot acquired)
  problems = checkFindings (acquiredPhaseContractEvidenceCheck evidence)

-- | The exact prerequisite universe for @CloseGateCompletion@.  It contains
-- every fixed gate row except the legacy row being decided and the pass
-- criterion which is derived from that decision.  Keeping this inventory in
-- the lifecycle analyzer makes omission or reordering a refusal instead of a
-- smaller definition of "complete".
gateCompletionPrerequisiteNames :: [Text]
gateCompletionPrerequisiteNames =
  [ "Claim"
  , "Subject"
  , "Command"
  , "Oracle"
  , "Positive controls"
  , "Paired negatives"
  , "Mutants"
  , "Discovery"
  , "Challenge"
  , "Observer"
  , "Authority/bypass"
  , "Freshness"
  , "Qualification"
  , "Cleanroom"
  , "Predecessor"
  , "Residue"
  ]

gateCompletionObservedState :: GateCompletionPremises -> LegacyObservedState
gateCompletionObservedState (GateCompletionPremises premises)
  | map gatePrerequisiteName premises /= gateCompletionPrerequisiteNames =
      LegacyObservationRefused
        ( "gate-completion prerequisite inventory mismatch: expected="
            <> showText gateCompletionPrerequisiteNames
            <> ", actual="
            <> showText (map gatePrerequisiteName premises)
        )
  | null blockers = LegacyObservedZero
  | otherwise =
      LegacyObservationRefused
        ( "gate-completion prerequisites are not all execution-derived green: "
            <> Text.intercalate "," (map renderGatePrerequisite premises)
        )
 where
  blockers =
    [ premise
    | premise <- premises
    , gatePrerequisiteOutcome premise /= GatePrerequisitePassed
    ]

renderGatePrerequisite :: GatePrerequisiteObservation -> Text
renderGatePrerequisite premise =
  gatePrerequisiteName premise <> "=" <> case gatePrerequisiteOutcome premise of
    GatePrerequisitePassed -> "passed"
    GatePrerequisiteRefused -> "refused"
    GatePrerequisiteUnverified -> "unverified"

-- | One observed seed-dependency locus.
--
-- A build input that names the seed's upstream repository, or a tracked module
-- beneath the seed's authored namespace root. These are exactly the two
-- conditions the owning phase must reduce to zero, and both are decided from
-- the captured snapshot rather than from prose.
data SeedDependencyLocus
  = SeedProjectFetch FilePath
  | SeedNamespaceModule FilePath
  deriving (Eq, Ord, Show)

-- | The typed closure predicate behind @CloseInfernixSeedDependency@ and
-- @CloseJitMlSeedDependency@.
--
-- Before this, both closure rules were bare constructors: the register
-- explained them to readers and no Haskell predicate decided them. A binding
-- whose closure rule cannot be evaluated can never close, so the rule was
-- unfalsifiable in both directions.
seedDependencies :: SourceSnapshot -> LegacyId -> [SeedDependencyLocus]
seedDependencies snapshot identifier = case seedLegacyDependencyRoot identifier of
  Nothing -> []
  Just (upstreamMarker, namespaceRoot) ->
    [ SeedProjectFetch path
    | (path, bytes) <- trackedProjectInputs
    , seedUpstreamReferenced upstreamMarker bytes
    ]
      <> [ SeedNamespaceModule path
         | path <- trackedSnapshotPaths
         , seedNamespaceMember namespaceRoot path
         ]
 where
  trackedSnapshotPaths = map (indexPath . trackedIndex) (snapshotEntries snapshot)
  trackedProjectInputs =
    [ (indexPath (trackedIndex entry), trackedBytes entry)
    | entry <- snapshotEntries snapshot
    , seedProjectInput (indexPath (trackedIndex entry))
    ]

-- | The closed seed universe: upstream marker and authored namespace root.
seedLegacyDependencyRoot :: LegacyId -> Maybe (ByteString, FilePath)
seedLegacyDependencyRoot identifier = case identifier of
  LtdSeed001 -> Just ("Tuee22/infernix", "src/Infernix")
  LtdSeed002 -> Just ("Tuee22/jitML", "src/JitML")
  _ -> Nothing

-- | Only a project-level build input can introduce an upstream fetch.
seedProjectInput :: FilePath -> Bool
seedProjectInput path = path == "cabal.project"

seedUpstreamReferenced :: ByteString -> ByteString -> Bool
seedUpstreamReferenced marker bytes = marker `ByteString.isInfixOf` bytes

seedNamespaceMember :: FilePath -> FilePath -> Bool
seedNamespaceMember root path =
  root == path || (root <> "/") `isPrefixOf` path

-- | The observed state for a seed binding.
--
-- Zero loci is an Active zero, which the evaluator admits only at the owning
-- phase; a non-zero count is the later-owned debt this repository actually
-- carries today.
seedDependencyState :: SourceSnapshot -> LegacyId -> LegacyObservedState
seedDependencyState snapshot identifier = case seedDependencies snapshot identifier of
  [] -> LegacyObservedZero
  loci -> LegacyObservedOpen (length loci) (seedDependencyDigest loci)

-- | An open observation binds its loci by a domain-separated digest rather
-- than by prose, so the count cannot drift from the set it summarizes.
seedDependencyDigest :: [SeedDependencyLocus] -> Text
seedDependencyDigest loci =
  Text.pack . show . Crypto.hashWith Crypto.SHA256 . ByteString.concat $
    seedDependencyDigestDomain <> map seedDependencyLocusBytes (sortOn id loci)

seedDependencyDigestDomain :: [ByteString]
seedDependencyDigestDomain = ["amoebius-legacy-seed-dependency-v0\0"]

seedDependencyLocusBytes :: SeedDependencyLocus -> ByteString
seedDependencyLocusBytes =
  TextEncoding.encodeUtf8 . (<> "\0") . renderSeedDependencyLocus

renderSeedDependencyLocus :: SeedDependencyLocus -> Text
renderSeedDependencyLocus locus = case locus of
  SeedProjectFetch path -> "upstream-fetch:" <> Text.pack path
  SeedNamespaceModule path -> "namespace-module:" <> Text.pack path

unimplementedEvidence :: SourceSnapshot -> LegacyId -> ClosedLegacyEvidence
unimplementedEvidence snapshot identifier
  | legacyUnimplementedOwnerDue identifier =
      closedEvidence
        snapshot
        identifier
        Nothing
        (Just legacyUnimplementedRefusalState)
  | otherwise = closedEvidence snapshot identifier Nothing legacyUnimplementedLaterState

legacyUnimplementedOwnerDue :: LegacyId -> Bool
#if defined(VALIDATION_LEGACY_INTERNAL_UNIMPLEMENTED_OWNER_PREDICATE_BYPASS_MUTANT)
legacyUnimplementedOwnerDue _ = False
#else
legacyUnimplementedOwnerDue identifier = Policy.phaseOrdinalNumber (legacyIdOwner identifier) == 0
#endif

legacyUnimplementedRefusalState :: LegacyObservedState
#if defined(VALIDATION_LEGACY_INTERNAL_UNIMPLEMENTED_REFUSAL_DETAIL_MUTANT)
legacyUnimplementedRefusalState = LegacyObservationRefused "mutated"
#else
legacyUnimplementedRefusalState =
  LegacyObservationRefused "the closed owner-domain analyzer has not been implemented"
#endif

legacyUnimplementedLaterState :: Maybe LegacyObservedState
#if defined(VALIDATION_LEGACY_INTERNAL_UNIMPLEMENTED_LATER_UNAVAILABLE_MUTANT)
legacyUnimplementedLaterState = Just LegacyObservedZero
#else
legacyUnimplementedLaterState = Nothing
#endif

-- | Total source-debt-to-register join. Exhaustive pattern matching makes a
-- new source family a compile-time obligation instead of a silently omitted
-- list entry.
sourceDebtLegacyId :: SourceDebtId -> LegacyId
sourceDebtLegacyId SourceTools =
#if defined(VALIDATION_LEGACY_JOIN_SOURCE_TOOLS_TARGET_MUTANT)
  LtdSrc000
#else
  LtdSrc001
#endif
sourceDebtLegacyId SourceDhall =
#if defined(VALIDATION_LEGACY_JOIN_SOURCE_DHALL_TARGET_MUTANT)
  LtdSrc000
#else
  LtdSrc002
#endif
sourceDebtLegacyId SourceProto =
#if defined(VALIDATION_LEGACY_JOIN_SOURCE_PROTO_TARGET_MUTANT)
  LtdSrc000
#else
  LtdSrc003
#endif
sourceDebtLegacyId SourceUi =
#if defined(VALIDATION_LEGACY_JOIN_SOURCE_UI_TARGET_MUTANT)
  LtdSrc000
#else
  LtdSrc004
#endif
sourceDebtLegacyId SourcePulumi =
#if defined(VALIDATION_LEGACY_JOIN_SOURCE_PULUMI_TARGET_MUTANT)
  LtdSrc000
#else
  LtdSrc005
#endif
sourceDebtLegacyId SourceTest =
#if defined(VALIDATION_LEGACY_JOIN_SOURCE_TEST_TARGET_MUTANT)
  LtdSrc000
#else
  LtdSrc006
#endif
sourceDebtLegacyId SourceProbe =
#if defined(VALIDATION_LEGACY_JOIN_SOURCE_PROBE_TARGET_MUTANT)
  LtdSrc000
#else
  LtdSrc007
#endif
sourceDebtLegacyId SourcePb =
#if defined(VALIDATION_LEGACY_JOIN_SOURCE_PB_TARGET_MUTANT)
  LtdSrc000
#else
  LtdSrc008
#endif
sourceDebtLegacyId SourceVendor =
#if defined(VALIDATION_LEGACY_JOIN_SOURCE_VENDOR_TARGET_MUTANT)
  LtdSrc000
#else
  LtdSrc009
#endif

-- | Independent inverse correspondence used to verify that the analyzer
-- registry did not merely preserve both closed key universes while attaching
-- an observation to the wrong source-debt family.
legacySourceDebtId :: LegacyId -> Maybe SourceDebtId
legacySourceDebtId LtdSrc001 =
#if defined(VALIDATION_LEGACY_INTERNAL_INVERSE_SOURCE_TOOLS_MUTANT)
  Nothing
#else
  Just SourceTools
#endif
legacySourceDebtId LtdSrc002 =
#if defined(VALIDATION_LEGACY_INTERNAL_INVERSE_SOURCE_DHALL_MUTANT)
  Nothing
#else
  Just SourceDhall
#endif
legacySourceDebtId LtdSrc003 =
#if defined(VALIDATION_LEGACY_INTERNAL_INVERSE_SOURCE_PROTO_MUTANT)
  Nothing
#else
  Just SourceProto
#endif
legacySourceDebtId LtdSrc004 =
#if defined(VALIDATION_LEGACY_INTERNAL_INVERSE_SOURCE_UI_MUTANT)
  Nothing
#else
  Just SourceUi
#endif
legacySourceDebtId LtdSrc005 =
#if defined(VALIDATION_LEGACY_INTERNAL_INVERSE_SOURCE_PULUMI_MUTANT)
  Nothing
#else
  Just SourcePulumi
#endif
legacySourceDebtId LtdSrc006 =
#if defined(VALIDATION_LEGACY_INTERNAL_INVERSE_SOURCE_TEST_MUTANT)
  Nothing
#else
  Just SourceTest
#endif
legacySourceDebtId LtdSrc007 =
#if defined(VALIDATION_LEGACY_INTERNAL_INVERSE_SOURCE_PROBE_MUTANT)
  Nothing
#else
  Just SourceProbe
#endif
legacySourceDebtId LtdSrc008 =
#if defined(VALIDATION_LEGACY_INTERNAL_INVERSE_SOURCE_PB_MUTANT)
  Nothing
#else
  Just SourcePb
#endif
legacySourceDebtId LtdSrc009 =
#if defined(VALIDATION_LEGACY_INTERNAL_INVERSE_SOURCE_VENDOR_MUTANT)
  Nothing
#else
  Just SourceVendor
#endif
legacySourceDebtId _ =
#if defined(VALIDATION_LEGACY_INTERNAL_INVERSE_NON_SOURCE_MUTANT)
  Just SourceTools
#else
  Nothing
#endif

sourceDebtUniverse :: [SourceDebtId]
sourceDebtUniverse =
  sourceDebtUniverseOrder
    (filter sourceDebtRouteRetained
      [ SourceTools
  , SourceDhall
  , SourceProto
  , SourceUi
  , SourcePulumi
  , SourceTest
  , SourceProbe
  , SourcePb
  , SourceVendor
      ])

sourceDebtUniverseOrder :: [SourceDebtId] -> [SourceDebtId]
#if defined(VALIDATION_LEGACY_INTERNAL_SOURCE_DEBT_UNIVERSE_ORDER_MUTANT)
sourceDebtUniverseOrder = reverse
#else
sourceDebtUniverseOrder = id
#endif

sourceDebtRouteRetained :: SourceDebtId -> Bool
sourceDebtRouteRetained sourceId = case sourceId of
  SourceTools ->
#if defined(VALIDATION_LEGACY_INTERNAL_SOURCE_DEBT_TOOLS_DROP_MUTANT)
    False
#else
    True
#endif
  SourceDhall ->
#if defined(VALIDATION_LEGACY_INTERNAL_SOURCE_DEBT_DHALL_DROP_MUTANT)
    False
#else
    True
#endif
  SourceProto ->
#if defined(VALIDATION_LEGACY_INTERNAL_SOURCE_DEBT_PROTO_DROP_MUTANT)
    False
#else
    True
#endif
  SourceUi ->
#if defined(VALIDATION_LEGACY_INTERNAL_SOURCE_DEBT_UI_DROP_MUTANT)
    False
#else
    True
#endif
  SourcePulumi ->
#if defined(VALIDATION_LEGACY_INTERNAL_SOURCE_DEBT_PULUMI_DROP_MUTANT)
    False
#else
    True
#endif
  SourceTest ->
#if defined(VALIDATION_LEGACY_INTERNAL_SOURCE_DEBT_TEST_DROP_MUTANT)
    False
#else
    True
#endif
  SourceProbe ->
#if defined(VALIDATION_LEGACY_INTERNAL_SOURCE_DEBT_PROBE_DROP_MUTANT)
    False
#else
    True
#endif
  SourcePb ->
#if defined(VALIDATION_LEGACY_INTERNAL_SOURCE_DEBT_PB_DROP_MUTANT)
    False
#else
    True
#endif
  SourceVendor ->
#if defined(VALIDATION_LEGACY_INTERNAL_SOURCE_DEBT_VENDOR_DROP_MUTANT)
    False
#else
    True
#endif

nonSourceLegacyUniverse :: [LegacyId]
nonSourceLegacyUniverse =
  nonSourceLegacyUniverseOrder
    (filter nonSourceLegacyRouteRetained
      [ LtdMeta001
  , LtdVal001
  , LtdVal002
  , LtdVal003
  , LtdVal004
  , LtdVal005
  , LtdVal006
  , LtdDoc001
  , LtdName001
  , LtdHost001
  , LtdHost002
  , LtdImg001
  , LtdRun001
  , LtdSeed001
  , LtdSeed002
  , LtdBoot001
      ])

nonSourceLegacyUniverseOrder :: [LegacyId] -> [LegacyId]
#if defined(VALIDATION_LEGACY_INTERNAL_NON_SOURCE_UNIVERSE_ORDER_MUTANT)
nonSourceLegacyUniverseOrder = reverse
#else
nonSourceLegacyUniverseOrder = id
#endif

nonSourceLegacyRouteRetained :: LegacyId -> Bool
nonSourceLegacyRouteRetained identifier = case identifier of
  LtdMeta001 ->
#if defined(VALIDATION_LEGACY_INTERNAL_NON_SOURCE_LTD_META001_DROP_MUTANT)
    False
#else
    True
#endif
  LtdVal001 ->
#if defined(VALIDATION_LEGACY_INTERNAL_NON_SOURCE_LTD_VAL001_DROP_MUTANT)
    False
#else
    True
#endif
  LtdVal002 ->
#if defined(VALIDATION_LEGACY_INTERNAL_NON_SOURCE_LTD_VAL002_DROP_MUTANT)
    False
#else
    True
#endif
  LtdVal003 ->
#if defined(VALIDATION_LEGACY_INTERNAL_NON_SOURCE_LTD_VAL003_DROP_MUTANT)
    False
#else
    True
#endif
  LtdVal004 ->
#if defined(VALIDATION_LEGACY_INTERNAL_NON_SOURCE_LTD_VAL004_DROP_MUTANT)
    False
#else
    True
#endif
  LtdVal005 ->
#if defined(VALIDATION_LEGACY_INTERNAL_NON_SOURCE_LTD_VAL005_DROP_MUTANT)
    False
#else
    True
#endif
  LtdVal006 ->
#if defined(VALIDATION_LEGACY_INTERNAL_NON_SOURCE_LTD_VAL006_DROP_MUTANT)
    False
#else
    True
#endif
  LtdDoc001 ->
#if defined(VALIDATION_LEGACY_INTERNAL_NON_SOURCE_LTD_DOC001_DROP_MUTANT)
    False
#else
    True
#endif
  LtdName001 ->
#if defined(VALIDATION_LEGACY_INTERNAL_NON_SOURCE_LTD_NAME001_DROP_MUTANT)
    False
#else
    True
#endif
  LtdHost001 ->
#if defined(VALIDATION_LEGACY_INTERNAL_NON_SOURCE_LTD_HOST001_DROP_MUTANT)
    False
#else
    True
#endif
  LtdHost002 ->
#if defined(VALIDATION_LEGACY_INTERNAL_NON_SOURCE_LTD_HOST002_DROP_MUTANT)
    False
#else
    True
#endif
  LtdImg001 ->
#if defined(VALIDATION_LEGACY_INTERNAL_NON_SOURCE_LTD_IMG001_DROP_MUTANT)
    False
#else
    True
#endif
  LtdRun001 ->
#if defined(VALIDATION_LEGACY_INTERNAL_NON_SOURCE_LTD_RUN001_DROP_MUTANT)
    False
#else
    True
#endif
  LtdSeed001 ->
#if defined(VALIDATION_LEGACY_INTERNAL_NON_SOURCE_LTD_SEED001_DROP_MUTANT)
    False
#else
    True
#endif
  LtdSeed002 ->
#if defined(VALIDATION_LEGACY_INTERNAL_NON_SOURCE_LTD_SEED002_DROP_MUTANT)
    False
#else
    True
#endif
  LtdBoot001 ->
#if defined(VALIDATION_LEGACY_INTERNAL_NON_SOURCE_LTD_BOOT001_DROP_MUTANT)
    False
#else
    True
#endif
  _ -> False

renderRegisterProblem :: RegisterProblem -> Text
renderRegisterProblem problem = case problem of
  RegisterEntryLimit maximumValue observed ->
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_ENTRY_DETAIL_MUTANT)
    maximumValue `seq` observed `seq` "mutated"
#else
    "tracked entry limit exceeded: maximum=" <> showText maximumValue
      <> "; observed-at-least=" <> showText observed
#endif
  RegisterPathByteLimit ordinal maximumValue observed ->
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_PATH_DETAIL_MUTANT)
    ordinal `seq` maximumValue `seq` observed `seq` "mutated"
#else
    "tracked path byte limit exceeded: ordinal=" <> showText ordinal
      <> "; maximum=" <> showText maximumValue
      <> "; observed-at-least=" <> showText observed
#endif
  RegisterByteLimit maximumValue observed ->
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_BYTE_DETAIL_MUTANT)
    maximumValue `seq` observed `seq` "mutated"
#else
    "active legacy register byte limit exceeded: maximum=" <> showText maximumValue
      <> "; observed=" <> showText observed
#endif
  RegisterResourceGuardUnavailable label ->
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_GUARD_DETAIL_MUTANT)
    label `seq` "mutated"
#else
    "register resource guard unavailable after bounded refusal: " <> label
#endif
  ActiveRegisterMissing path ->
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_MISSING_DETAIL_MUTANT)
    path `seq` "mutated"
#else
    "active legacy register is missing: " <> Text.pack path
#endif
  MultipleActiveRegisters path count ->
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_MULTIPLE_DETAIL_MUTANT)
    path `seq` count `seq` "mutated"
#else
    "active legacy register occurs " <> showText count <> " times: " <> Text.pack path
#endif
  AdditionalActiveRegisterTracked path ->
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_ADDITIONAL_DETAIL_MUTANT)
    path `seq` "mutated"
#else
    "additional active legacy register is tracked: " <> Text.pack path
#endif
  ArchiveRegisterTracked path ->
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_ARCHIVE_DETAIL_MUTANT)
    path `seq` "mutated"
#else
    "archive legacy register is tracked: " <> Text.pack path
#endif
  RegisterNotRegularFile path mode ->
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_MODE_DETAIL_MUTANT)
    path `seq` mode `seq` "mutated"
#else
    "active legacy register must be a non-executable regular file: " <> Text.pack path <> " (index mode " <> showText mode <> ")"
#endif
  RegisterNotUtf8 path ->
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_UTF8_DETAIL_MUTANT)
    path `seq` "mutated"
#else
    "active legacy register is not UTF-8: " <> Text.pack path
#endif

registerFinding :: RegisterProblem -> Finding
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_FINDING_COMPOSITION_MUTANT)
registerFinding problem =
  finding (registerFindingDetail problem) (registerFindingSubject problem) registerFindingCode
#else
registerFinding problem =
  finding registerFindingCode (registerFindingSubject problem) (registerFindingDetail problem)
#endif

registerFindingCode :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_FINDING_CODE_MUTANT)
registerFindingCode = "LEGACY-MUTATED"
#else
registerFindingCode = "LEGACY-REGISTER"
#endif

registerFindingSubject :: RegisterProblem -> FilePath
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_FINDING_SUBJECT_ROUTE_MUTANT)
registerFindingSubject problem = registerProblemSubject problem `seq` "<mutated>"
#else
registerFindingSubject = registerProblemSubject
#endif

registerFindingDetail :: RegisterProblem -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_FINDING_DETAIL_ROUTE_MUTANT)
registerFindingDetail problem = Text.length (renderRegisterProblem problem) `seq` "mutated"
#else
registerFindingDetail = renderRegisterProblem
#endif

registerProblemSubject :: RegisterProblem -> FilePath
registerProblemSubject problem = case problem of
  RegisterEntryLimit _ _ ->
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_ENTRY_SUBJECT_MUTANT)
    "<mutated>"
#else
    "<tracked-entries>"
#endif
  RegisterPathByteLimit ordinal _ _ ->
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_PATH_SUBJECT_MUTANT)
    ordinal `seq` "<mutated>"
#else
    "<tracked-path-" <> show ordinal <> ">"
#endif
  RegisterByteLimit _ _ ->
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_BYTE_SUBJECT_MUTANT)
    "<mutated>"
#else
    canonicalRegisterPath
#endif
  RegisterResourceGuardUnavailable _ ->
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_GUARD_SUBJECT_MUTANT)
    "<mutated>"
#else
    "<legacy-register-input>"
#endif
  ActiveRegisterMissing path ->
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_MISSING_SUBJECT_MUTANT)
    path `seq` "<mutated>"
#else
    path
#endif
  MultipleActiveRegisters path _ ->
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_MULTIPLE_SUBJECT_MUTANT)
    path `seq` "<mutated>"
#else
    path
#endif
  AdditionalActiveRegisterTracked path ->
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_ADDITIONAL_SUBJECT_MUTANT)
    path `seq` "<mutated>"
#else
    path
#endif
  ArchiveRegisterTracked path ->
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_ARCHIVE_SUBJECT_MUTANT)
    path `seq` "<mutated>"
#else
    path
#endif
  RegisterNotRegularFile path _ ->
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_MODE_SUBJECT_MUTANT)
    path `seq` "<mutated>"
#else
    path
#endif
  RegisterNotUtf8 path ->
#if defined(VALIDATION_LEGACY_INTERNAL_REGISTER_UTF8_SUBJECT_MUTANT)
    path `seq` "<mutated>"
#else
    path
#endif

renderOwnerBindings :: Text
renderOwnerBindings =
  Text.intercalate
    legacyOwnerBindingsSeparator
    [ legacyOwnerBindingEntry identifier
    | identifier <- legacyOwnerBindingsOrder canonicalLegacyUniverse
    ]

legacyOwnerBindingsOrder :: [LegacyId] -> [LegacyId]
#if defined(VALIDATION_LEGACY_INTERNAL_OWNER_BINDINGS_RENDER_ORDER_MUTANT)
legacyOwnerBindingsOrder = reverse . sortOn renderLegacyId
#else
legacyOwnerBindingsOrder = sortOn renderLegacyId
#endif

legacyOwnerBindingsSeparator :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_OWNER_BINDINGS_RENDER_SEPARATOR_MUTANT)
legacyOwnerBindingsSeparator = ";"
#else
legacyOwnerBindingsSeparator = ","
#endif

legacyOwnerBindingEntry :: LegacyId -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_OWNER_BINDINGS_RENDER_COMPONENT_ORDER_MUTANT)
legacyOwnerBindingEntry identifier =
  showText (Policy.phaseOrdinalNumber (legacyIdOwner identifier)) <> "@" <> renderLegacyId identifier
#else
legacyOwnerBindingEntry identifier =
  renderLegacyId identifier <> "@" <> showText (Policy.phaseOrdinalNumber (legacyIdOwner identifier))
#endif

renderBindingContracts :: Text
renderBindingContracts =
  Text.intercalate
    legacyBindingContractsSeparator
    [ legacyBindingContractEntry identifier
    | identifier <- legacyBindingContractsOrder canonicalLegacyUniverse
    ]

legacyBindingContractsOrder :: [LegacyId] -> [LegacyId]
#if defined(VALIDATION_LEGACY_INTERNAL_BINDING_CONTRACTS_RENDER_ORDER_MUTANT)
legacyBindingContractsOrder = reverse
#else
legacyBindingContractsOrder = id
#endif

legacyBindingContractsSeparator :: Text
#if defined(VALIDATION_LEGACY_INTERNAL_BINDING_CONTRACTS_RENDER_SEPARATOR_MUTANT)
legacyBindingContractsSeparator = ";"
#else
legacyBindingContractsSeparator = ","
#endif

legacyBindingContractEntry :: LegacyId -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_BINDING_CONTRACTS_RENDER_COMPONENT_ORDER_MUTANT)
legacyBindingContractEntry identifier =
  showText (legacyIdDisposition identifier)
    <> "@"
    <> renderLegacyId identifier
    <> ":"
    <> showText (Policy.phaseOrdinalNumber (legacyIdOwner identifier))
    <> ":"
    <> showText (legacyIdAnalyzer identifier)
    <> ":"
    <> showText (legacyIdObservationRule identifier)
    <> ":"
    <> showText (legacyIdClosureRule identifier)
    <> ":"
    <> showText (legacyIdReintroductionCases identifier)
#else
legacyBindingContractEntry identifier =
  renderLegacyId identifier
        <> "@"
        <> showText (Policy.phaseOrdinalNumber (legacyIdOwner identifier))
        <> ":"
        <> showText (legacyIdDisposition identifier)
        <> ":"
        <> showText (legacyIdAnalyzer identifier)
        <> ":"
        <> showText (legacyIdObservationRule identifier)
        <> ":"
        <> showText (legacyIdClosureRule identifier)
        <> ":"
        <> showText (legacyIdReintroductionCases identifier)
#endif

renderLegacyObservation :: LegacyAnalyzer -> Maybe LegacyObservation -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_OBSERVATION_UNAVAILABLE_ROUTE_MUTANT)
renderLegacyObservation expectedAnalyzer Nothing = showText expectedAnalyzer <> ":unavailable"
#else
renderLegacyObservation expectedAnalyzer Nothing = "unavailable:" <> showText expectedAnalyzer
#endif
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_OBSERVATION_SUPPLIED_ORDER_MUTANT)
renderLegacyObservation _ (Just supplied) =
  renderObservedState (legacyObservationState supplied)
    <> ":analyzer=" <> showText (legacyObservationAnalyzer supplied)
#else
renderLegacyObservation _ (Just supplied) =
  "analyzer=" <> showText (legacyObservationAnalyzer supplied) <> ":" <> renderObservedState (legacyObservationState supplied)
#endif

renderObservedState :: LegacyObservedState -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_STATE_ZERO_MUTANT)
renderObservedState LegacyObservedZero = "zero-mutated"
#else
renderObservedState LegacyObservedZero = "zero"
#endif
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_STATE_OPEN_ORDER_MUTANT)
renderObservedState (LegacyObservedOpen count digest) = digest <> ":" <> showText count <> ":open"
#else
renderObservedState (LegacyObservedOpen count digest) = "open:" <> showText count <> ":" <> digest
#endif
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_STATE_REFUSED_MUTANT)
renderObservedState (LegacyObservationRefused detail) = detail <> ":refused"
#else
renderObservedState (LegacyObservationRefused detail) = "refused:" <> detail
#endif

slotValue :: BindingSlot value -> Maybe value
slotValue BindingMissing = Nothing
#if defined(VALIDATION_LEGACY_INTERNAL_SLOT_PRESENT_ROUTE_MUTANT)
slotValue (BindingPresent value) = value `seq` Nothing
#else
slotValue (BindingPresent value) = Just value
#endif

renderOwner :: Maybe Int -> Text
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_OWNER_MISSING_MUTANT)
renderOwner Nothing = "<missing-mutated>"
#else
renderOwner Nothing = "<missing>"
#endif
#if defined(VALIDATION_LEGACY_INTERNAL_RENDER_OWNER_PRESENT_MUTANT)
renderOwner (Just owner) = owner `seq` "mutated"
#else
renderOwner (Just owner) = showText owner
#endif

phaseOrdinal :: Int -> Policy.PhaseOrdinal
phaseOrdinal value = case Policy.mkPhaseOrdinal value of
  Just ordinal -> ordinal
#if defined(VALIDATION_LEGACY_INTERNAL_PHASE_ORDINAL_FALLBACK_ROUTE_MUTANT)
  Nothing ->
    staticPhaseFallback `seq`
      Policy.phaseDomainUpper (Policy.orderingContract Policy.canonicalPolicyContract)
#else
  Nothing -> staticPhaseFallback
#endif

staticPhaseFallback :: Policy.PhaseOrdinal
#if defined(VALIDATION_LEGACY_INTERNAL_STATIC_PHASE_FALLBACK_MUTANT)
staticPhaseFallback = Policy.phaseDomainUpper (Policy.orderingContract Policy.canonicalPolicyContract)
#else
staticPhaseFallback = Policy.phaseDomainLower (Policy.orderingContract Policy.canonicalPolicyContract)
#endif

legacySubject :: LegacyId -> FilePath
#if defined(VALIDATION_LEGACY_INTERNAL_LEGACY_SUBJECT_COMPOSITION_MUTANT)
legacySubject identifier = Text.unpack (renderLegacyId identifier) <> "/Amoebius.Validation.Legacy"
#else
legacySubject identifier = "Amoebius.Validation.Legacy/" <> Text.unpack (renderLegacyId identifier)
#endif

legacySemanticSubject :: FilePath
#if defined(VALIDATION_LEGACY_INTERNAL_SEMANTIC_SUBJECT_MUTANT)
legacySemanticSubject = "Amoebius.Validation.Legacy.Mutated"
#else
legacySemanticSubject = "Amoebius.Validation.Legacy"
#endif

showText :: Show value => value -> Text
showText = Text.pack . show
