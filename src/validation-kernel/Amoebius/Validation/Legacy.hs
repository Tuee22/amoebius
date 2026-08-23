{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.Legacy
  ( ActiveRegister
  , BindingSlot (..)
  , LegacyAnalyzer (..)
  , LegacyBinding (..)
  , LegacyClosureRule (..)
  , LegacyDisposition (..)
  , LegacyId (..)
  , LegacyObservationRule (..)
  , LegacyObservedState (..)
  , LegacyReintroductionCase (..)
  , RegisterProblem (..)
  , activeRegisterFromSnapshot
  , activeRegisterPath
  , allLegacyIds
  , applyLegacyObservedState
  , evaluateLegacyBinding
  , laterOwnedSourceIds
  , legacyBinding
  , legacyCheck
  , legacyIdAnalyzer
  , legacyIdClosureRule
  , legacyIdDisposition
  , legacyIdObservationRule
  , legacyIdOwner
  , legacyIdReintroductionCases
  , parseActiveRegister
  , parseLegacyId
  , parseSourceDebtId
  , qualifySourceClosure
  , renderLegacyId
  , renderRegisterProblem
  , sourceBaseline
  , sourceDebtLegacyId
  ) where

import Amoebius.Validation.PolicyContract qualified as Policy
import Amoebius.Validation.SourceClosure
  ( IndexEntry (..)
  , SourceClosure
  , SourceDebtId (..)
  , SourceSnapshot (..)
  , TrackedEntry (..)
  , classifySnapshot
  , registeredSourceIds
  , renderSourceDebtId
  , sourceClosureCheck
  , sourceDebtFingerprint
  , sourceDebtPathCount
  )
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding
  , checkFindings
  , checkObservations
  , finding
  , observation
  )
import Data.ByteString (ByteString)
import Data.List (nub, sortOn)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import System.FilePath (takeFileName)

-- | The permanent executable identity universe. Retiring a debt changes its
-- disposition; it never removes the constructor or its reintroduction case.
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
  deriving (Bounded, Enum, Eq, Ord, Show)

data LegacyDisposition
  = LegacyActive
  | LegacyRetired
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | A key names the owner-domain observer which must supply raw evidence. A
-- key is not evidence that the observer exists or that its closure is true.
data LegacyAnalyzer
  = AnalyzeCompleteSourceGrammar
  | AnalyzeSourceFamily SourceDebtId
  | AnalyzeRetiredIgnoreRules
  | AnalyzeValidationProtocol
  | AnalyzePhaseContracts
  | AnalyzeStatusEvidence
  | AnalyzeHumanPromotion
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
  deriving (Eq, Ord, Show)

data LegacyObservationRule
  = ObserveCompleteSourceSnapshot
  | ObserveExactSourceFamily SourceDebtId
  | ObserveParsedIgnoreGrammars
  | ObserveValidationAuthorityGraph
  | ObserveTypedPhaseContractCustody
  | ObserveStatusEvidenceProjection
  | ObservePromotionTrustRoot
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
  deriving (Eq, Ord, Show)

data LegacyClosureRule
  = CloseCompleteSourceGrammar
  | CloseSourceFamily SourceDebtId
  | CloseRetiredIgnoreRules
  | CloseValidationProtocol
  | ClosePhaseContracts
  | CloseStatusEvidence
  | CloseHumanPromotion
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
  deriving (Eq, Ord, Show)

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
  | RejectNonHaskellValidationAuthority
  | RejectUnboundPhaseContract
  | RejectForgedStatusEvidence
  | RejectAutomatedPromotion
  | RejectHardwareBeforeDslPromotion
  | RejectAmbientOrStaleRunInput
  | RejectBehavioralMarkdownConsumer
  | RejectRuntimePhaseOrdinal
  | RejectBypassedHostEnsure
  | RejectAmbientHostPath
  | RejectCrossArchitectureImagePlan
  | RejectSecondExecutableIdentity
  | RejectInfernixSeedDependency
  | RejectJitMlSeedDependency
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
  | LegacyObserverUnavailable LegacyAnalyzer
  | LegacyObservationRefused Text
  deriving (Eq, Ord, Show)

data ActiveRegister = ActiveRegister
  { activeRegisterPath :: FilePath
  }
  deriving (Eq, Show)

data RegisterProblem
  = ActiveRegisterMissing FilePath
  | MultipleActiveRegisters FilePath Int
  | AdditionalActiveRegisterTracked FilePath
  | ArchiveRegisterTracked FilePath
  | RegisterNotUtf8 FilePath
  deriving (Eq, Ord, Show)

canonicalRegisterPath :: FilePath
canonicalRegisterPath = Policy.canonicalActiveRegisterPath Policy.canonicalPolicyContract

archiveRegisterName :: FilePath
archiveRegisterName =
  takeFileName (Policy.canonicalForbiddenArchivePath Policy.canonicalPolicyContract)

policyOrdering :: Policy.OrderingContract
policyOrdering = Policy.orderingContract Policy.canonicalPolicyContract

dslBarrierPhase :: Int
dslBarrierPhase =
  Policy.phaseOrdinalNumber (Policy.phaseRoleOrdinal policyOrdering Policy.HardwareFreeDslBarrier)

-- | The canonical universe is literal and closed. The conditional omission is
-- reachable only in the named changed-production build.
allLegacyIds :: [LegacyId]
allLegacyIds =
#ifdef VALIDATION_LEGACY_DROP_ID_MUTANT
  filter (/= LtdSeed002) canonicalLegacyUniverse
#else
  canonicalLegacyUniverse
#endif

canonicalLegacyUniverse :: [LegacyId]
canonicalLegacyUniverse = [minBound .. maxBound]

renderLegacyId :: LegacyId -> Text
renderLegacyId LtdSrc000 = "LTD-SRC-000"
renderLegacyId LtdSrc001 = "LTD-SRC-001"
renderLegacyId LtdSrc002 = "LTD-SRC-002"
renderLegacyId LtdSrc003 = "LTD-SRC-003"
renderLegacyId LtdSrc004 = "LTD-SRC-004"
renderLegacyId LtdSrc005 = "LTD-SRC-005"
renderLegacyId LtdSrc006 = "LTD-SRC-006"
renderLegacyId LtdSrc007 = "LTD-SRC-007"
renderLegacyId LtdSrc008 = "LTD-SRC-008"
renderLegacyId LtdSrc009 = "LTD-SRC-009"
renderLegacyId LtdMeta001 = "LTD-META-001"
renderLegacyId LtdVal001 = "LTD-VAL-001"
renderLegacyId LtdVal002 = "LTD-VAL-002"
renderLegacyId LtdVal003 = "LTD-VAL-003"
renderLegacyId LtdVal004 = "LTD-VAL-004"
renderLegacyId LtdVal005 = "LTD-VAL-005"
renderLegacyId LtdVal006 = "LTD-VAL-006"
renderLegacyId LtdDoc001 = "LTD-DOC-001"
renderLegacyId LtdName001 = "LTD-NAME-001"
renderLegacyId LtdHost001 = "LTD-HOST-001"
renderLegacyId LtdHost002 = "LTD-HOST-002"
renderLegacyId LtdImg001 = "LTD-IMG-001"
renderLegacyId LtdRun001 = "LTD-RUN-001"
renderLegacyId LtdSeed001 = "LTD-SEED-001"
#ifdef VALIDATION_LEGACY_DUPLICATE_RENDER_MUTANT
renderLegacyId LtdSeed002 = "LTD-SEED-001"
#else
renderLegacyId LtdSeed002 = "LTD-SEED-002"
#endif

parseLegacyId :: Text -> Maybe LegacyId
parseLegacyId "LTD-SRC-000" = Just LtdSrc000
parseLegacyId "LTD-SRC-001" = Just LtdSrc001
parseLegacyId "LTD-SRC-002" = Just LtdSrc002
parseLegacyId "LTD-SRC-003" = Just LtdSrc003
parseLegacyId "LTD-SRC-004" = Just LtdSrc004
parseLegacyId "LTD-SRC-005" = Just LtdSrc005
parseLegacyId "LTD-SRC-006" = Just LtdSrc006
parseLegacyId "LTD-SRC-007" = Just LtdSrc007
parseLegacyId "LTD-SRC-008" = Just LtdSrc008
parseLegacyId "LTD-SRC-009" = Just LtdSrc009
parseLegacyId "LTD-META-001" = Just LtdMeta001
parseLegacyId "LTD-VAL-001" = Just LtdVal001
parseLegacyId "LTD-VAL-002" = Just LtdVal002
parseLegacyId "LTD-VAL-003" = Just LtdVal003
parseLegacyId "LTD-VAL-004" = Just LtdVal004
parseLegacyId "LTD-VAL-005" = Just LtdVal005
parseLegacyId "LTD-VAL-006" = Just LtdVal006
parseLegacyId "LTD-DOC-001" = Just LtdDoc001
parseLegacyId "LTD-NAME-001" = Just LtdName001
parseLegacyId "LTD-HOST-001" = Just LtdHost001
parseLegacyId "LTD-HOST-002" = Just LtdHost002
parseLegacyId "LTD-IMG-001" = Just LtdImg001
parseLegacyId "LTD-RUN-001" = Just LtdRun001
parseLegacyId "LTD-SEED-001" = Just LtdSeed001
parseLegacyId "LTD-SEED-002" = Just LtdSeed002
parseLegacyId _ = Nothing

legacyIdOwner :: LegacyId -> Policy.PhaseOrdinal
legacyIdOwner LtdSrc000 = phaseOrdinal 0
legacyIdOwner LtdSrc001 = phaseOrdinal 47
legacyIdOwner LtdSrc002 = phaseOrdinal 25
legacyIdOwner LtdSrc003 = phaseOrdinal 26
legacyIdOwner LtdSrc004 = phaseOrdinal 46
legacyIdOwner LtdSrc005 = phaseOrdinal 47
legacyIdOwner LtdSrc006 = phaseOrdinal 47
legacyIdOwner LtdSrc007 = phaseOrdinal 1
legacyIdOwner LtdSrc008 = phaseOrdinal 0
legacyIdOwner LtdSrc009 = phaseOrdinal 1
legacyIdOwner LtdMeta001 = phaseOrdinal 2
legacyIdOwner LtdVal001 = phaseOrdinal 0
legacyIdOwner LtdVal002 = phaseOrdinal 0
legacyIdOwner LtdVal003 = phaseOrdinal 0
legacyIdOwner LtdVal004 = phaseOrdinal 0
legacyIdOwner LtdVal005 = phaseOrdinal 49
legacyIdOwner LtdVal006 = phaseOrdinal 47
legacyIdOwner LtdDoc001 = phaseOrdinal 27
legacyIdOwner LtdName001 = phaseOrdinal 2
legacyIdOwner LtdHost001 = phaseOrdinal 51
legacyIdOwner LtdHost002 = phaseOrdinal 51
legacyIdOwner LtdImg001 = phaseOrdinal 56
#ifdef VALIDATION_LEGACY_WRONG_OWNER_MUTANT
legacyIdOwner LtdRun001 = phaseOrdinal 54
#else
legacyIdOwner LtdRun001 = phaseOrdinal 55
#endif
legacyIdOwner LtdSeed001 = phaseOrdinal 91
legacyIdOwner LtdSeed002 = phaseOrdinal 93

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

legacyIdAnalyzer :: LegacyId -> LegacyAnalyzer
legacyIdAnalyzer LtdSrc000 = AnalyzeCompleteSourceGrammar
legacyIdAnalyzer LtdSrc001 = AnalyzeSourceFamily SourceTools
legacyIdAnalyzer LtdSrc002 = AnalyzeSourceFamily SourceDhall
legacyIdAnalyzer LtdSrc003 = AnalyzeSourceFamily SourceProto
legacyIdAnalyzer LtdSrc004 = AnalyzeSourceFamily SourceUi
legacyIdAnalyzer LtdSrc005 = AnalyzeSourceFamily SourcePulumi
legacyIdAnalyzer LtdSrc006 = AnalyzeSourceFamily SourceTest
legacyIdAnalyzer LtdSrc007 = AnalyzeSourceFamily SourceProbe
legacyIdAnalyzer LtdSrc008 = AnalyzeSourceFamily SourcePb
legacyIdAnalyzer LtdSrc009 = AnalyzeSourceFamily SourceVendor
legacyIdAnalyzer LtdMeta001 = AnalyzeRetiredIgnoreRules
legacyIdAnalyzer LtdVal001 = AnalyzeValidationProtocol
legacyIdAnalyzer LtdVal002 = AnalyzePhaseContracts
legacyIdAnalyzer LtdVal003 = AnalyzeStatusEvidence
legacyIdAnalyzer LtdVal004 = AnalyzeHumanPromotion
legacyIdAnalyzer LtdVal005 = AnalyzeHardwareFreeDsl
legacyIdAnalyzer LtdVal006 = AnalyzeRunInputClosure
legacyIdAnalyzer LtdDoc001 = AnalyzeBehavioralDocumentConsumers
legacyIdAnalyzer LtdName001 = AnalyzePhaseOrdinalNames
legacyIdAnalyzer LtdHost001 = AnalyzeHostEnsure
legacyIdAnalyzer LtdHost002 = AnalyzeAmbientHostPaths
legacyIdAnalyzer LtdImg001 = AnalyzeNaturalArchitectureImages
legacyIdAnalyzer LtdRun001 = AnalyzeExecutableIdentity
legacyIdAnalyzer LtdSeed001 = AnalyzeInfernixSeedDependency
legacyIdAnalyzer LtdSeed002 = AnalyzeJitMlSeedDependency

legacyIdObservationRule :: LegacyId -> LegacyObservationRule
legacyIdObservationRule LtdSrc000 = ObserveCompleteSourceSnapshot
legacyIdObservationRule LtdSrc001 = ObserveExactSourceFamily SourceTools
legacyIdObservationRule LtdSrc002 = ObserveExactSourceFamily SourceDhall
legacyIdObservationRule LtdSrc003 = ObserveExactSourceFamily SourceProto
legacyIdObservationRule LtdSrc004 = ObserveExactSourceFamily SourceUi
legacyIdObservationRule LtdSrc005 = ObserveExactSourceFamily SourcePulumi
legacyIdObservationRule LtdSrc006 = ObserveExactSourceFamily SourceTest
legacyIdObservationRule LtdSrc007 = ObserveExactSourceFamily SourceProbe
legacyIdObservationRule LtdSrc008 = ObserveExactSourceFamily SourcePb
legacyIdObservationRule LtdSrc009 = ObserveExactSourceFamily SourceVendor
legacyIdObservationRule LtdMeta001 = ObserveParsedIgnoreGrammars
legacyIdObservationRule LtdVal001 = ObserveValidationAuthorityGraph
legacyIdObservationRule LtdVal002 = ObserveTypedPhaseContractCustody
legacyIdObservationRule LtdVal003 = ObserveStatusEvidenceProjection
legacyIdObservationRule LtdVal004 = ObservePromotionTrustRoot
legacyIdObservationRule LtdVal005 = ObserveHardwareFreeDslTrace
legacyIdObservationRule LtdVal006 = ObserveRunInputProvenance
legacyIdObservationRule LtdDoc001 = ObserveDocumentConsumerGraph
legacyIdObservationRule LtdName001 = ObserveRuntimeIdentityGraph
legacyIdObservationRule LtdHost001 = ObserveHostEnsureCallGraph
legacyIdObservationRule LtdHost002 = ObserveHostPathEffectGraph
legacyIdObservationRule LtdImg001 = ObserveImagePlanAndBinfmt
legacyIdObservationRule LtdRun001 = ObserveCabalExecutableGraph
legacyIdObservationRule LtdSeed001 = ObserveInfernixDependencyGraph
legacyIdObservationRule LtdSeed002 = ObserveJitMlDependencyGraph

legacyIdClosureRule :: LegacyId -> LegacyClosureRule
legacyIdClosureRule LtdSrc000 = CloseCompleteSourceGrammar
legacyIdClosureRule LtdSrc001 = CloseSourceFamily SourceTools
legacyIdClosureRule LtdSrc002 = CloseSourceFamily SourceDhall
legacyIdClosureRule LtdSrc003 = CloseSourceFamily SourceProto
legacyIdClosureRule LtdSrc004 = CloseSourceFamily SourceUi
legacyIdClosureRule LtdSrc005 = CloseSourceFamily SourcePulumi
legacyIdClosureRule LtdSrc006 = CloseSourceFamily SourceTest
legacyIdClosureRule LtdSrc007 = CloseSourceFamily SourceProbe
legacyIdClosureRule LtdSrc008 = CloseSourceFamily SourcePb
legacyIdClosureRule LtdSrc009 = CloseSourceFamily SourceVendor
legacyIdClosureRule LtdMeta001 = CloseRetiredIgnoreRules
legacyIdClosureRule LtdVal001 = CloseValidationProtocol
legacyIdClosureRule LtdVal002 = ClosePhaseContracts
legacyIdClosureRule LtdVal003 = CloseStatusEvidence
legacyIdClosureRule LtdVal004 = CloseHumanPromotion
legacyIdClosureRule LtdVal005 = CloseHardwareFreeDsl
legacyIdClosureRule LtdVal006 = CloseRunInputClosure
legacyIdClosureRule LtdDoc001 = CloseBehavioralDocumentConsumers
legacyIdClosureRule LtdName001 = ClosePhaseOrdinalNames
legacyIdClosureRule LtdHost001 = CloseHostEnsure
legacyIdClosureRule LtdHost002 = CloseAmbientHostPaths
legacyIdClosureRule LtdImg001 = CloseNaturalArchitectureImages
legacyIdClosureRule LtdRun001 = CloseExecutableIdentity
legacyIdClosureRule LtdSeed001 = CloseInfernixSeedDependency
legacyIdClosureRule LtdSeed002 = CloseJitMlSeedDependency

legacyIdReintroductionCases :: LegacyId -> NonEmpty LegacyReintroductionCase
legacyIdReintroductionCases LtdSrc000 = RejectDisguisedOrConcealedSource :| []
legacyIdReintroductionCases LtdSrc001 = RejectTrackedToolsSource :| []
legacyIdReintroductionCases LtdSrc002 = RejectTrackedDhallOrTsv :| []
legacyIdReintroductionCases LtdSrc003 = RejectTrackedProto :| []
legacyIdReintroductionCases LtdSrc004 = RejectTrackedUiSource :| []
legacyIdReintroductionCases LtdSrc005 = RejectTrackedPulumiSource :| []
legacyIdReintroductionCases LtdSrc006 = RejectTrackedBehavioralTestInput :| []
legacyIdReintroductionCases LtdSrc007 = RejectTrackedProbeDebt :| []
legacyIdReintroductionCases LtdSrc008 = RejectWidenedPbBehavior :| []
legacyIdReintroductionCases LtdSrc009 = RejectTopLevelVendorDebt :| []
legacyIdReintroductionCases LtdMeta001 = RejectRetiredIgnoreRule :| []
legacyIdReintroductionCases LtdVal001 = RejectNonHaskellValidationAuthority :| []
legacyIdReintroductionCases LtdVal002 = RejectUnboundPhaseContract :| []
legacyIdReintroductionCases LtdVal003 = RejectForgedStatusEvidence :| []
legacyIdReintroductionCases LtdVal004 = RejectAutomatedPromotion :| []
legacyIdReintroductionCases LtdVal005 = RejectHardwareBeforeDslPromotion :| []
legacyIdReintroductionCases LtdVal006 = RejectAmbientOrStaleRunInput :| []
legacyIdReintroductionCases LtdDoc001 = RejectBehavioralMarkdownConsumer :| []
legacyIdReintroductionCases LtdName001 = RejectRuntimePhaseOrdinal :| []
legacyIdReintroductionCases LtdHost001 = RejectBypassedHostEnsure :| []
legacyIdReintroductionCases LtdHost002 = RejectAmbientHostPath :| []
legacyIdReintroductionCases LtdImg001 = RejectCrossArchitectureImagePlan :| []
legacyIdReintroductionCases LtdRun001 = RejectSecondExecutableIdentity :| []
legacyIdReintroductionCases LtdSeed001 = RejectInfernixSeedDependency :| []
legacyIdReintroductionCases LtdSeed002 = RejectJitMlSeedDependency :| []

legacyBinding :: LegacyId -> LegacyBinding
legacyBinding identifier =
  LegacyBinding
    { legacyBindingId = identifier
    , legacyBindingDisposition = legacyIdDisposition identifier
    , legacyBindingOwner = ownerSlot identifier
    , legacyBindingAnalyzer = analyzerSlot identifier
    , legacyBindingObservation = observationSlot identifier
    , legacyBindingClosure = closureSlot identifier
    , legacyBindingReintroduction = reintroductionSlot identifier
    }

ownerSlot :: LegacyId -> BindingSlot Policy.PhaseOrdinal
ownerSlot identifier =
#ifdef VALIDATION_LEGACY_MISSING_OWNER_MUTANT
  if identifier == LtdVal001 then BindingMissing else BindingPresent (legacyIdOwner identifier)
#else
  BindingPresent (legacyIdOwner identifier)
#endif

analyzerSlot :: LegacyId -> BindingSlot LegacyAnalyzer
analyzerSlot identifier =
#ifdef VALIDATION_LEGACY_DISPATCH_REDIRECT_MUTANT
  if identifier == LtdHost001 then BindingPresent AnalyzeAmbientHostPaths else BindingPresent (legacyIdAnalyzer identifier)
#else
  BindingPresent (legacyIdAnalyzer identifier)
#endif

observationSlot :: LegacyId -> BindingSlot LegacyObservationRule
observationSlot identifier =
#ifdef VALIDATION_LEGACY_MISSING_OBSERVATION_MUTANT
  if identifier == LtdMeta001 then BindingMissing else BindingPresent (legacyIdObservationRule identifier)
#else
  BindingPresent (legacyIdObservationRule identifier)
#endif

closureSlot :: LegacyId -> BindingSlot LegacyClosureRule
closureSlot identifier =
#ifdef VALIDATION_LEGACY_MISSING_CLOSURE_MUTANT
  if identifier == LtdVal002 then BindingMissing else BindingPresent (legacyIdClosureRule identifier)
#else
  BindingPresent (legacyIdClosureRule identifier)
#endif

reintroductionSlot :: LegacyId -> BindingSlot (NonEmpty LegacyReintroductionCase)
reintroductionSlot identifier =
#ifdef VALIDATION_LEGACY_MISSING_REINTRODUCTION_MUTANT
  if identifier == LtdSeed002 then BindingMissing else BindingPresent (legacyIdReintroductionCases identifier)
#else
  BindingPresent (legacyIdReintroductionCases identifier)
#endif

sourceDebtLegacyId :: SourceDebtId -> LegacyId
sourceDebtLegacyId SourceTools = LtdSrc001
sourceDebtLegacyId SourceDhall = LtdSrc002
sourceDebtLegacyId SourceProto = LtdSrc003
sourceDebtLegacyId SourceUi = LtdSrc004
sourceDebtLegacyId SourcePulumi = LtdSrc005
sourceDebtLegacyId SourceTest = LtdSrc006
sourceDebtLegacyId SourceProbe = LtdSrc007
sourceDebtLegacyId SourcePb = LtdSrc008
sourceDebtLegacyId SourceVendor = LtdSrc009

parseSourceDebtId :: LegacyId -> Maybe SourceDebtId
parseSourceDebtId LtdSrc000 = Nothing
parseSourceDebtId LtdSrc001 = Just SourceTools
parseSourceDebtId LtdSrc002 = Just SourceDhall
parseSourceDebtId LtdSrc003 = Just SourceProto
parseSourceDebtId LtdSrc004 = Just SourceUi
parseSourceDebtId LtdSrc005 = Just SourcePulumi
parseSourceDebtId LtdSrc006 = Just SourceTest
parseSourceDebtId LtdSrc007 = Just SourceProbe
parseSourceDebtId LtdSrc008 = Just SourcePb
parseSourceDebtId LtdSrc009 = Just SourceVendor
parseSourceDebtId LtdMeta001 = Nothing
parseSourceDebtId LtdVal001 = Nothing
parseSourceDebtId LtdVal002 = Nothing
parseSourceDebtId LtdVal003 = Nothing
parseSourceDebtId LtdVal004 = Nothing
parseSourceDebtId LtdVal005 = Nothing
parseSourceDebtId LtdVal006 = Nothing
parseSourceDebtId LtdDoc001 = Nothing
parseSourceDebtId LtdName001 = Nothing
parseSourceDebtId LtdHost001 = Nothing
parseSourceDebtId LtdHost002 = Nothing
parseSourceDebtId LtdImg001 = Nothing
parseSourceDebtId LtdRun001 = Nothing
parseSourceDebtId LtdSeed001 = Nothing
parseSourceDebtId LtdSeed002 = Nothing

-- | Frozen 2026-08-22 active-family baselines. The independent oracle restates
-- these literals. Zero means a reviewed Active -> Retired transition is due;
-- a different non-zero fingerprint is an unaccounted source mutation.
sourceBaseline :: SourceDebtId -> (Int, Text)
sourceBaseline SourceTools = (237, "b756b203049bb59e62bd9795b5a36e37840e8599b28b01c2bf3aa8c41cf3e534")
sourceBaseline SourceDhall = (279, "633e2198ba565cab862fad019fc9de2e7cbe784d7c781468e911322b4d0bed31")
sourceBaseline SourceProto = (1, "ad6293590c8d79e1fe385497bd891d2d7351a46f8f34907e12cef4b46eafca1e")
sourceBaseline SourceUi = (16, "d5c12f81a7f91385b460824539aabd94c0c3e1885ef8ddf2ec9190ee12d5d05d")
sourceBaseline SourcePulumi = (1, "b5e5b10785f0d371b3cfa9ff4d9e5dd25360677c3c5d8415475ba61c50855982")
sourceBaseline SourceTest = (890, "1080ced8d4adc45eb3368cd61e4bdb84a68ddd4b2c24179c6975f085672c3899")
sourceBaseline SourceProbe = (7, "233dfc3539480eacc10e4e5c284d69893c31c93975fc7945670424751d961800")
sourceBaseline SourcePb = (15, "116e1cb2adf61ebd20ea70c3f384f5b1bbe6916aec04239c13224e3cd1ddfa3c")
sourceBaseline SourceVendor = (28, "fe32b81f2231b370fe28959f49661861f4644d774b1058cca827818a04439acd")

laterOwnedSourceIds :: Int -> SourceClosure -> Set SourceDebtId
laterOwnedSourceIds candidatePhase closure =
  Set.fromList
    [ identifier
    | identifier <- Set.toAscList (registeredSourceIds closure)
    , let legacyIdentifier = sourceDebtLegacyId identifier
    , legacyIdDisposition legacyIdentifier == LegacyActive
    , Policy.phaseOrdinalNumber (legacyIdOwner legacyIdentifier) > candidatePhase
    , case observeSourceFamily identifier closure of
        LegacyObservedOpen _ _ -> True
        LegacyObservedZero -> False
        LegacyObserverUnavailable _ -> False
        LegacyObservationRefused _ -> False
    ]

-- | Evaluate the canonical binding against available production observations.
-- Source-family classification exists today. Every other owner-domain
-- capability is explicit and unavailable until its owning sprint integrates
-- typed raw observations; no Boolean or prose can substitute for it.
evaluateLegacyBinding :: Int -> SourceClosure -> LegacyBinding -> CheckResult
evaluateLegacyBinding candidatePhase closure binding =
  applyLegacyObservedState candidatePhase binding (observeBinding closure binding)

applyLegacyObservedState :: Int -> LegacyBinding -> LegacyObservedState -> CheckResult
applyLegacyObservedState candidatePhase binding state =
  CheckResult
    { checkName = "legacy-binding"
    , checkObservations =
        [ observation
            ("legacy.binding." <> renderLegacyId identifier)
            (renderObservedState state)
        ]
    , checkFindings = missingFindings <> semanticFindings
    }
 where
  identifier = legacyBindingId binding
  subject = legacySubject identifier
  missingFindings = bindingIntegrityFindings binding
  ownerNumber = Policy.phaseOrdinalNumber <$> slotValue (legacyBindingOwner binding)
  due = maybe True (<= candidatePhase) ownerNumber
  semanticFindings
    | not (null missingFindings) = []
    | otherwise = case (legacyBindingDisposition binding, state) of
        (LegacyActive, LegacyObservedZero) ->
          [ finding
              "LEGACY-ACTIVE-TRANSITION-UNRECORDED"
              subject
              (renderLegacyId identifier <> " is Active but its observer reports zero; a reviewed Haskell retirement transition is required")
          ]
        (LegacyActive, LegacyObservedOpen count digest)
          | due ->
              [ finding
                  "LEGACY-OWNER-DUE"
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
        (LegacyActive, LegacyObserverUnavailable analyzer)
          | due ->
              [ finding
                  "LEGACY-ANALYZER-UNAVAILABLE"
                  subject
                  ( renderLegacyId identifier
                      <> " requires "
                      <> showText analyzer
                      <> " at owner Phase "
                      <> renderOwner ownerNumber
                      <> "; no typed raw observation was supplied"
                  )
              ]
          | otherwise -> []
        (LegacyActive, LegacyObservationRefused detail) ->
          [finding "LEGACY-OBSERVATION-REFUSED" subject (renderLegacyId identifier <> ": " <> detail)]
        (LegacyRetired, LegacyObservedZero) -> []
        (LegacyRetired, LegacyObservedOpen count digest) ->
          [ finding
              "LEGACY-REINTRODUCED"
              subject
              (renderLegacyId identifier <> " was retired but reappeared; count=" <> showText count <> " digest=" <> digest)
          ]
        (LegacyRetired, LegacyObserverUnavailable analyzer) ->
          [ finding
              "LEGACY-ANALYZER-UNAVAILABLE"
              subject
              (renderLegacyId identifier <> " is Retired but its retained guard " <> showText analyzer <> " is unavailable")
          ]
        (LegacyRetired, LegacyObservationRefused detail) ->
          [finding "LEGACY-OBSERVATION-REFUSED" subject (renderLegacyId identifier <> ": " <> detail)]

qualifySourceClosure :: Int -> SourceClosure -> CheckResult
qualifySourceClosure candidatePhase closure =
  CheckResult
    { checkName = "legacy-source-closure"
    , checkObservations =
        checkObservations sourceCheck
          <> [ observation "legacy.haskell-owner-bindings" renderOwnerBindings
             , observation "legacy.binding-contracts" renderBindingContracts
             , observation "legacy.candidate-phase" (showText candidatePhase)
             , observation "legacy.later-owned-source-ids" renderLaterOwned
             , observation "legacy.dsl-barrier-phase" (showText dslBarrierPhase)
             ]
          <> concatMap checkObservations evaluated
    , checkFindings =
        checkFindings sourceCheck
          <> invalidPhaseFindings
          <> universeIntegrityFindings
          <> concatMap checkFindings evaluated
          <> dslBarrierFindings
    }
 where
  sourceCheck = sourceClosureCheck closure
  evaluated = [evaluateLegacyBinding candidatePhase closure (legacyBinding identifier) | identifier <- allLegacyIds]
  invalidPhaseFindings =
    [finding "LEGACY-PHASE" legacySemanticSubject "candidate phase must be non-negative" | candidatePhase < 0]
  openAtBarrier =
    [ identifier
    | identifier <- sourceLegacyIds
    , observeBinding closure (legacyBinding identifier) /= LegacyObservedZero
    ]
  dslBarrierFindings = case Policy.dslBarrierSourceClosure policyOrdering of
    Policy.AllLtdSrcQueriesZeroBeforePhase49 ->
      [ finding
          "LEGACY-DSL-BARRIER-SOURCE-OPEN"
          legacySemanticSubject
          ( "Phase "
              <> showText dslBarrierPhase
              <> " cannot open until every LTD-SRC query is zero; open-or-unavailable="
              <> Text.intercalate "," (map renderLegacyId openAtBarrier)
          )
      | candidatePhase >= dslBarrierPhase
      , not (null openAtBarrier)
      ]
  renderLaterOwned =
    Text.intercalate
      ","
      [ renderSourceDebtId identifier
          <> "@"
          <> showText (Policy.phaseOrdinalNumber (legacyIdOwner (sourceDebtLegacyId identifier)))
      | identifier <- Set.toAscList (laterOwnedSourceIds candidatePhase closure)
      ]

observeBinding :: SourceClosure -> LegacyBinding -> LegacyObservedState
observeBinding closure binding =
  case legacyBindingAnalyzer binding of
    BindingMissing -> LegacyObservationRefused "required-analyzer binding is missing"
    BindingPresent AnalyzeCompleteSourceGrammar -> LegacyObserverUnavailable AnalyzeCompleteSourceGrammar
    BindingPresent (AnalyzeSourceFamily identifier) -> observeSourceFamily identifier closure
    BindingPresent analyzer -> LegacyObserverUnavailable analyzer

observeSourceFamily :: SourceDebtId -> SourceClosure -> LegacyObservedState
observeSourceFamily identifier closure
  | observedCount == 0 = LegacyObservedZero
  | observedCount == expectedCount && observedDigest == expectedDigest =
      LegacyObservedOpen observedCount observedDigest
  | otherwise =
      LegacyObservationRefused
        ( renderSourceDebtId identifier
            <> " differs from its frozen Haskell baseline: expected count="
            <> showText expectedCount
            <> " digest="
            <> expectedDigest
            <> ", observed count="
            <> showText observedCount
            <> " digest="
            <> observedDigest
        )
 where
  (expectedCount, expectedDigest) = sourceBaseline identifier
  observedCount = sourceDebtPathCount identifier closure
  observedDigest = sourceDebtFingerprint identifier closure

universeIntegrityFindings :: [Finding]
universeIntegrityFindings =
  universeFindings
    <> renderFindings
    <> bindingIdFindings
    <> sourceBijectionFindings
    <> sourceEncodingFindings
 where
  universeFindings =
    [ finding
        "LEGACY-ID-INVENTORY"
        legacySemanticSubject
        "allLegacyIds must contain every LegacyId constructor exactly once and in constructor order"
    | allLegacyIds /= canonicalLegacyUniverse
    ]
  rendered = map renderLegacyId canonicalLegacyUniverse
  renderFindings =
    [ finding
        "LEGACY-ID-ENCODING"
        legacySemanticSubject
        "every LegacyId must have one unique stable text encoding"
    | length rendered /= length (nub rendered)
    ]
  bindingIdFindings =
    [ finding
        "LEGACY-BINDING-ID-MISMATCH"
        (legacySubject identifier)
        "legacyBinding returned a record for a different LegacyId"
    | identifier <- canonicalLegacyUniverse
    , legacyBindingId (legacyBinding identifier) /= identifier
    ]
  mappedSources = [identifier | legacyIdentifier <- canonicalLegacyUniverse, Just identifier <- [parseSourceDebtId legacyIdentifier]]
  sourceBijectionFindings =
    [ finding
        "LEGACY-SOURCE-BIJECTION"
        legacySemanticSubject
        "the nine SourceDebtId constructors must map bijectively to LTD-SRC-001 through LTD-SRC-009"
    | sortOn id mappedSources /= [minBound .. maxBound]
        || length mappedSources /= length (nub mappedSources)
    ]
  sourceEncodingFindings =
    [ finding
        "LEGACY-SOURCE-ENCODING"
        (legacySubject legacyIdentifier)
        ( "SourceClosure rendered "
            <> renderSourceDebtId sourceIdentifier
            <> " but the owning LegacyId renders "
            <> renderLegacyId legacyIdentifier
        )
    | sourceIdentifier <- [minBound .. maxBound]
    , let legacyIdentifier = sourceDebtLegacyId sourceIdentifier
    , renderSourceDebtId sourceIdentifier /= renderLegacyId legacyIdentifier
    ]

bindingIntegrityFindings :: LegacyBinding -> [Finding]
bindingIntegrityFindings binding =
  ownerFindings <> analyzerFindings <> observationFindings <> closureFindings <> reintroductionFindings
 where
  identifier = legacyBindingId binding
  subject = legacySubject identifier
  ownerFindings = case legacyBindingOwner binding of
    BindingMissing -> [finding "LEGACY-OWNER-BINDING-MISSING" subject "typed owner binding is missing"]
    BindingPresent actual
      | actual /= legacyIdOwner identifier ->
          [finding "LEGACY-OWNER-BINDING-MISMATCH" subject "typed owner binding does not match the exhaustive owner dispatch"]
      | otherwise -> []
  analyzerFindings = case legacyBindingAnalyzer binding of
    BindingMissing -> [finding "LEGACY-ANALYZER-BINDING-MISSING" subject "typed required-analyzer binding is missing"]
    BindingPresent actual
      | actual /= legacyIdAnalyzer identifier ->
          [finding "LEGACY-ANALYZER-BINDING-MISMATCH" subject "required-analyzer dispatch was redirected"]
      | otherwise -> []
  observationFindings = case legacyBindingObservation binding of
    BindingMissing -> [finding "LEGACY-OBSERVATION-BINDING-MISSING" subject "typed observation-rule binding is missing"]
    BindingPresent actual
      | actual /= legacyIdObservationRule identifier ->
          [finding "LEGACY-OBSERVATION-BINDING-MISMATCH" subject "typed observation-rule binding was redirected"]
      | otherwise -> []
  closureFindings = case legacyBindingClosure binding of
    BindingMissing -> [finding "LEGACY-CLOSURE-BINDING-MISSING" subject "typed closure-rule binding is missing"]
    BindingPresent actual
      | actual /= legacyIdClosureRule identifier ->
          [finding "LEGACY-CLOSURE-BINDING-MISMATCH" subject "typed closure-rule binding was redirected"]
      | otherwise -> []
  reintroductionFindings = case legacyBindingReintroduction binding of
    BindingMissing -> [finding "LEGACY-REINTRODUCTION-BINDING-MISSING" subject "typed reintroduction-case binding is missing"]
    BindingPresent actual
      | actual /= legacyIdReintroductionCases identifier ->
          [finding "LEGACY-REINTRODUCTION-BINDING-MISMATCH" subject "typed reintroduction-case binding was redirected"]
      | otherwise -> []

-- | Locate one reader register and verify only UTF-8 bytes. Row text, count,
-- IDs, owners, and predicate-looking prose are deliberately unavailable to
-- executable legacy semantics.
activeRegisterFromSnapshot :: SourceSnapshot -> Either [RegisterProblem] ActiveRegister
activeRegisterFromSnapshot snapshot =
  case canonicalEntries of
    [] -> Left (nameProblems <> archiveProblems <> [ActiveRegisterMissing canonicalRegisterPath])
    [entry] ->
      case parseActiveRegister (trackedBytes entry) of
        Left problems -> Left (nameProblems <> archiveProblems <> problems)
        Right register ->
          let problems = nameProblems <> archiveProblems
           in if null problems then Right register else Left problems
    duplicateEntries -> Left (nameProblems <> archiveProblems <> [MultipleActiveRegisters canonicalRegisterPath (length duplicateEntries)])
 where
  entries = snapshotEntries snapshot
  pathOf = indexPath . trackedIndex
  canonicalEntries = filter ((== canonicalRegisterPath) . pathOf) entries
  nameProblems =
    [ AdditionalActiveRegisterTracked (pathOf entry)
    | entry <- entries
    , takeFileName (pathOf entry) == takeFileName canonicalRegisterPath
    , pathOf entry /= canonicalRegisterPath
    ]
  archiveProblems =
    [ ArchiveRegisterTracked (pathOf entry)
    | entry <- entries
    , takeFileName (pathOf entry) == archiveRegisterName
    ]

parseActiveRegister :: ByteString -> Either [RegisterProblem] ActiveRegister
parseActiveRegister bytes =
  case TextEncoding.decodeUtf8' bytes of
    Left _ -> Left [RegisterNotUtf8 canonicalRegisterPath]
    Right _ -> Right (ActiveRegister canonicalRegisterPath)

legacyCheck :: Int -> SourceSnapshot -> CheckResult
legacyCheck candidatePhase snapshot =
  CheckResult
    { checkName = checkName semanticCheck
    , checkObservations = checkObservations semanticCheck
    , checkFindings = checkFindings semanticCheck <> structuralFindings
    }
 where
  semanticCheck = qualifySourceClosure candidatePhase (classifySnapshot snapshot)
  structuralFindings = case activeRegisterFromSnapshot snapshot of
    Left problems -> map registerFinding problems
    Right _ -> []

renderRegisterProblem :: RegisterProblem -> Text
renderRegisterProblem problem = case problem of
  ActiveRegisterMissing path -> "active legacy register is missing: " <> Text.pack path
  MultipleActiveRegisters path count ->
    "active legacy register occurs " <> showText count <> " times: " <> Text.pack path
  AdditionalActiveRegisterTracked path -> "additional active legacy register is tracked: " <> Text.pack path
  ArchiveRegisterTracked path -> "archive legacy register is tracked: " <> Text.pack path
  RegisterNotUtf8 path -> "active legacy register is not UTF-8: " <> Text.pack path

registerFinding :: RegisterProblem -> Finding
registerFinding problem = finding "LEGACY-REGISTER" canonicalRegisterPath (renderRegisterProblem problem)

sourceLegacyIds :: [LegacyId]
sourceLegacyIds = [LtdSrc000, LtdSrc001, LtdSrc002, LtdSrc003, LtdSrc004, LtdSrc005, LtdSrc006, LtdSrc007, LtdSrc008, LtdSrc009]

renderOwnerBindings :: Text
renderOwnerBindings =
  Text.intercalate
    ","
    [ renderLegacyId identifier <> "@" <> showText (Policy.phaseOrdinalNumber (legacyIdOwner identifier))
    | identifier <- sortOn renderLegacyId canonicalLegacyUniverse
    ]

renderBindingContracts :: Text
renderBindingContracts =
  Text.intercalate
    ","
    [ renderLegacyId identifier
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
    | identifier <- canonicalLegacyUniverse
    ]

renderObservedState :: LegacyObservedState -> Text
renderObservedState LegacyObservedZero = "zero"
renderObservedState (LegacyObservedOpen count digest) = "open:" <> showText count <> ":" <> digest
renderObservedState (LegacyObserverUnavailable analyzer) = "unavailable:" <> showText analyzer
renderObservedState (LegacyObservationRefused detail) = "refused:" <> detail

slotValue :: BindingSlot value -> Maybe value
slotValue BindingMissing = Nothing
slotValue (BindingPresent value) = Just value

renderOwner :: Maybe Int -> Text
renderOwner Nothing = "<missing>"
renderOwner (Just owner) = showText owner

phaseOrdinal :: Int -> Policy.PhaseOrdinal
phaseOrdinal value = case Policy.mkPhaseOrdinal value of
  Just ordinal -> ordinal
  Nothing -> error "Amoebius.Validation.Legacy: invalid static phase ordinal"

legacySubject :: LegacyId -> FilePath
legacySubject identifier = "Amoebius.Validation.Legacy/" <> Text.unpack (renderLegacyId identifier)

legacySemanticSubject :: FilePath
legacySemanticSubject = "Amoebius.Validation.Legacy"

showText :: Show value => value -> Text
showText = Text.pack . show
