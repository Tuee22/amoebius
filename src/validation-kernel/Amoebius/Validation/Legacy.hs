{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Bounded refusal-only external Legacy facade.
--
-- Candidate-capable snapshot, acquired-evidence, analyzer, lifecycle, and
-- register types/functions are package-hidden in Legacy.Internal.
module Amoebius.Validation.Legacy
  ( legacyDiagnostic
  ) where

import Amoebius.Validation.Legacy.Internal qualified as Internal
import Amoebius.Validation.Types (CheckResult (..), Finding, Observation, finding, observation)
import Crypto.Hash qualified as Crypto
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteString8
import Data.Char (ord)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding

type RawLegacyBinding = (Text, Text, Text, Text, Text, Text, [Text])
type RawLegacyJoin = (Text, Text)

maximumLegacyPhaseBytes, maximumLegacyBindings, maximumLegacyJoins :: Int
#if defined(VALIDATION_LEGACY_BOUND_PHASE_BYTES_MUTANT)
maximumLegacyPhaseBytes = 1
#else
maximumLegacyPhaseBytes = 2
#endif
#if defined(VALIDATION_LEGACY_BOUND_BINDINGS_MUTANT)
maximumLegacyBindings = 24
#else
maximumLegacyBindings = 25
#endif
#if defined(VALIDATION_LEGACY_BOUND_JOINS_MUTANT)
maximumLegacyJoins = 8
#else
maximumLegacyJoins = 9
#endif

maximumLegacyIdBytes, maximumLegacyDispositionBytes, maximumLegacyOwnerBytes :: Int
#if defined(VALIDATION_LEGACY_BOUND_ID_BYTES_MUTANT)
maximumLegacyIdBytes = 11
#else
maximumLegacyIdBytes = 12
#endif
#if defined(VALIDATION_LEGACY_BOUND_DISPOSITION_BYTES_MUTANT)
maximumLegacyDispositionBytes = 7
#else
maximumLegacyDispositionBytes = 8
#endif
#if defined(VALIDATION_LEGACY_BOUND_OWNER_BYTES_MUTANT)
maximumLegacyOwnerBytes = 1
#else
maximumLegacyOwnerBytes = 2
#endif

maximumLegacyAnalyzerBytes, maximumLegacyObservationBytes, maximumLegacyClosureBytes :: Int
#if defined(VALIDATION_LEGACY_BOUND_ANALYZER_BYTES_MUTANT)
maximumLegacyAnalyzerBytes = 63
#else
maximumLegacyAnalyzerBytes = 64
#endif
#if defined(VALIDATION_LEGACY_BOUND_OBSERVATION_BYTES_MUTANT)
maximumLegacyObservationBytes = 63
#else
maximumLegacyObservationBytes = 64
#endif
#if defined(VALIDATION_LEGACY_BOUND_CLOSURE_BYTES_MUTANT)
maximumLegacyClosureBytes = 63
#else
maximumLegacyClosureBytes = 64
#endif

maximumLegacyReintroductionValues, maximumLegacyReintroductionBytes :: Int
#if defined(VALIDATION_LEGACY_BOUND_REINTRODUCTION_VALUES_MUTANT)
maximumLegacyReintroductionValues = 3
#else
maximumLegacyReintroductionValues = 4
#endif
#if defined(VALIDATION_LEGACY_BOUND_REINTRODUCTION_BYTES_MUTANT)
maximumLegacyReintroductionBytes = 63
#else
maximumLegacyReintroductionBytes = 64
#endif

maximumLegacyJoinSourceBytes, maximumLegacyJoinTargetBytes, maximumLegacyAggregateBytes :: Int
#if defined(VALIDATION_LEGACY_BOUND_JOIN_SOURCE_BYTES_MUTANT)
maximumLegacyJoinSourceBytes = 31
#else
maximumLegacyJoinSourceBytes = 32
#endif
#if defined(VALIDATION_LEGACY_BOUND_JOIN_TARGET_BYTES_MUTANT)
maximumLegacyJoinTargetBytes = 11
#else
maximumLegacyJoinTargetBytes = 12
#endif
#if defined(VALIDATION_LEGACY_BOUND_AGGREGATE_BYTES_MUTANT)
maximumLegacyAggregateBytes = 2714
#else
maximumLegacyAggregateBytes = 2715
#endif

data LegacyPrefix value
  = LegacyPrefixWithin [value]
  | LegacyPrefixExceeded Int [value]

data LegacyRawProblem
  = LegacyPhaseByteLimit Int Int
  | LegacyBindingLimit Int Int
  | LegacyJoinLimit Int Int
  | LegacyIdByteLimit Int Int Int
  | LegacyDispositionByteLimit Int Int Int
  | LegacyOwnerByteLimit Int Int Int
  | LegacyAnalyzerByteLimit Int Int Int
  | LegacyObservationByteLimit Int Int Int
  | LegacyClosureByteLimit Int Int Int
  | LegacyReintroductionCountLimit Int Int Int
  | LegacyReintroductionByteLimit Int Int Int Int
  | LegacyJoinSourceByteLimit Int Int Int
  | LegacyJoinTargetByteLimit Int Int Int
  | LegacyAggregateByteLimit Int Int
  | LegacyResourceGuardUnavailable Text
  | LegacyPhaseWidth
  | LegacyPhaseAlphabet
  | LegacyPhaseRange
  | LegacyBindingCardinality Int Int
  | LegacyBindingDuplicate Text
  | LegacyBindingUnknown Text
  | LegacyBindingOrder [Text]
  | LegacyBindingFieldMismatch Int Text Text Text
  | LegacyJoinCardinality Int Int
  | LegacyJoinDuplicate Text
  | LegacyJoinUnknown Text
  | LegacyJoinOrder [Text]
  | LegacyJoinTargetMismatch Int Text Text Text
  deriving (Eq, Show)

data LegacyAnalysis = LegacyAnalysis
  { legacyCommitmentKind :: Text
  , legacyCommitmentDigest :: Text
  , legacySafePhase :: Text
  , legacySafeBindingCount :: Text
  , legacySafeJoinCount :: Text
  , legacyProblems :: [LegacyRawProblem]
  }

-- | Check a caller-declared Legacy binding wire.  The tuple fields are,
-- in order: stable ID, disposition, two-digit owner, analyzer, observation
-- rule, closure rule, and reintroduction-case identifiers.  The final pairs
-- claim the source-debt identifier to Legacy-ID join.
--
-- This pure function always refuses candidate authority.  It performs no Git,
-- filesystem, process, pb, network, hardware, or container action.
legacyDiagnostic
  :: Text
  -> [(Text, Text, Text, Text, Text, Text, [Text])]
  -> [(Text, Text)]
  -> CheckResult
legacyDiagnostic candidatePhase claimedBindings claimedJoins =
  CheckResult
    { checkName = legacyResultName
    , checkObservations =
        legacyObservationOrder
          (legacyResultObservationBlocks analysis selectedBindings selectedJoins)
    , checkFindings =
        legacyFindingOrder
          (legacyResultFindingBlocks analysis selectedBindings selectedJoins)
    }
 where
  analysis =
    analyzeLegacyInput
      (legacyAnalysisPhaseRoute candidatePhase)
      (legacyAnalysisBindingRoute claimedBindings)
      (legacyAnalysisJoinRoute claimedJoins)
  selectedBindings = filter canonicalBindingSelected canonicalLegacyBindings
  selectedJoins = filter canonicalJoinSelected canonicalLegacyJoins

legacyResultObservationBlocks
  :: LegacyAnalysis -> [CanonicalLegacyBinding] -> [CanonicalLegacyJoin] -> [Observation]
#if defined(VALIDATION_LEGACY_RESULT_OBSERVATION_BLOCK_ORDER_MUTANT)
legacyResultObservationBlocks analysis selectedBindings selectedJoins =
  legacyInternalProjectionBlock
    <> legacyFixedObservationBlock analysis selectedBindings selectedJoins
    <> legacyBindingObservationBlock selectedBindings
    <> legacyJoinObservationBlock selectedJoins
#else
legacyResultObservationBlocks analysis selectedBindings selectedJoins =
  legacyFixedObservationBlock analysis selectedBindings selectedJoins
    <> legacyInternalProjectionBlock
    <> legacyBindingObservationBlock selectedBindings
    <> legacyJoinObservationBlock selectedJoins
#endif

legacyResultFindingBlocks
  :: LegacyAnalysis -> [CanonicalLegacyBinding] -> [CanonicalLegacyJoin] -> [Finding]
#if defined(VALIDATION_LEGACY_RESULT_FINDING_BLOCK_ORDER_MUTANT)
legacyResultFindingBlocks analysis selectedBindings selectedJoins =
  legacyProblemFindingBlock analysis
    <> legacyMandatoryFindings analysis
    <> legacyBindingExecutionFindingBlock analysis selectedBindings
    <> legacyJoinExecutionFindingBlock analysis selectedJoins
    <> legacyPhaseRouteFindings analysis
#else
legacyResultFindingBlocks analysis selectedBindings selectedJoins =
  legacyMandatoryFindings analysis
    <> legacyProblemFindingBlock analysis
    <> legacyBindingExecutionFindingBlock analysis selectedBindings
    <> legacyJoinExecutionFindingBlock analysis selectedJoins
    <> legacyPhaseRouteFindings analysis
#endif

legacyAnalysisPhaseRoute :: Text -> Text
#if defined(VALIDATION_LEGACY_ANALYSIS_PHASE_ROUTE_MUTANT)
legacyAnalysisPhaseRoute value = Text.length value `seq` "01"
#else
legacyAnalysisPhaseRoute = id
#endif

legacyAnalysisBindingRoute :: [RawLegacyBinding] -> [RawLegacyBinding]
#if defined(VALIDATION_LEGACY_ANALYSIS_BINDING_ROUTE_MUTANT)
legacyAnalysisBindingRoute values = case values of
  [] -> []
  _ : rest -> rest
#else
legacyAnalysisBindingRoute = id
#endif

legacyAnalysisJoinRoute :: [RawLegacyJoin] -> [RawLegacyJoin]
#if defined(VALIDATION_LEGACY_ANALYSIS_JOIN_ROUTE_MUTANT)
legacyAnalysisJoinRoute values = case values of
  [] -> []
  _ : rest -> rest
#else
legacyAnalysisJoinRoute = id
#endif

legacyFixedObservationBlock :: LegacyAnalysis -> [CanonicalLegacyBinding] -> [CanonicalLegacyJoin] -> [Observation]
#if defined(VALIDATION_LEGACY_RESULT_FIXED_OBSERVATION_BLOCK_DROP_MUTANT)
legacyFixedObservationBlock analysis bindings joins =
  length (legacyFixedObservations analysis bindings joins) `seq` []
#else
legacyFixedObservationBlock = legacyFixedObservations
#endif

legacyInternalProjectionBlock :: [Observation]
#if defined(VALIDATION_LEGACY_RESULT_INTERNAL_PROJECTION_DROP_MUTANT)
legacyInternalProjectionBlock = []
#else
legacyInternalProjectionBlock = Internal.legacyInternalDiagnosticProjection
#endif

legacyBindingObservationBlock :: [CanonicalLegacyBinding] -> [Observation]
#if defined(VALIDATION_LEGACY_RESULT_BINDING_OBSERVATION_BLOCK_COMPOSITION_MUTANT)
legacyBindingObservationBlock values =
  length
    [ legacyBindingObservation ordinal binding
    | (ordinal, binding) <- legacyBindingObservationRows values
    , canonicalBindingObservationRetained binding
    ] `seq` []
#else
legacyBindingObservationBlock values =
  [ legacyBindingObservation ordinal binding
  | (ordinal, binding) <- legacyBindingObservationRows values
  , canonicalBindingObservationRetained binding
  ]
#endif

legacyBindingObservationRows :: [CanonicalLegacyBinding] -> [(Int, CanonicalLegacyBinding)]
#if defined(VALIDATION_LEGACY_RESULT_BINDING_OBSERVATION_ORDER_MUTANT)
legacyBindingObservationRows = reverse . zip [(1 :: Int) ..]
#else
legacyBindingObservationRows = zip [(1 :: Int) ..]
#endif

legacyJoinObservationBlock :: [CanonicalLegacyJoin] -> [Observation]
#if defined(VALIDATION_LEGACY_RESULT_JOIN_OBSERVATION_BLOCK_COMPOSITION_MUTANT)
legacyJoinObservationBlock values =
  length
    [ legacyJoinObservation ordinal item
    | (ordinal, item) <- legacyJoinObservationRows values
    , canonicalJoinObservationRetained item
    ] `seq` []
#else
legacyJoinObservationBlock values =
  [ legacyJoinObservation ordinal item
  | (ordinal, item) <- legacyJoinObservationRows values
  , canonicalJoinObservationRetained item
  ]
#endif

legacyJoinObservationRows :: [CanonicalLegacyJoin] -> [(Int, CanonicalLegacyJoin)]
#if defined(VALIDATION_LEGACY_RESULT_JOIN_OBSERVATION_ORDER_MUTANT)
legacyJoinObservationRows = reverse . zip [(1 :: Int) ..]
#else
legacyJoinObservationRows = zip [(1 :: Int) ..]
#endif

legacyProblemFindingBlock :: LegacyAnalysis -> [Finding]
#if defined(VALIDATION_LEGACY_RESULT_PROBLEM_FINDING_BLOCK_DROP_MUTANT)
legacyProblemFindingBlock analysis =
  length (map (legacyRawProblemFinding analysis) (legacyProblems analysis)) `seq` []
#else
legacyProblemFindingBlock analysis = map (legacyRawProblemFinding analysis) (legacyProblems analysis)
#endif

legacyBindingExecutionFindingBlock :: LegacyAnalysis -> [CanonicalLegacyBinding] -> [Finding]
#if defined(VALIDATION_LEGACY_RESULT_BINDING_EXECUTION_BLOCK_COMPOSITION_MUTANT)
legacyBindingExecutionFindingBlock analysis values =
  length
    [ legacyBindingExecutionFinding analysis binding
    | binding <- legacyBindingExecutionRows values
    , canonicalBindingExecutionFindingRetained binding
    ] `seq` []
#else
legacyBindingExecutionFindingBlock analysis values =
  [ legacyBindingExecutionFinding analysis binding
  | binding <- legacyBindingExecutionRows values
  , canonicalBindingExecutionFindingRetained binding
  ]
#endif

legacyBindingExecutionRows :: [CanonicalLegacyBinding] -> [CanonicalLegacyBinding]
#if defined(VALIDATION_LEGACY_RESULT_BINDING_EXECUTION_ORDER_MUTANT)
legacyBindingExecutionRows = reverse
#else
legacyBindingExecutionRows = id
#endif

legacyJoinExecutionFindingBlock :: LegacyAnalysis -> [CanonicalLegacyJoin] -> [Finding]
#if defined(VALIDATION_LEGACY_RESULT_JOIN_EXECUTION_BLOCK_COMPOSITION_MUTANT)
legacyJoinExecutionFindingBlock analysis values =
  length
    [ legacyJoinExecutionFinding analysis item
    | item <- legacyJoinExecutionRows values
    , canonicalJoinExecutionFindingRetained item
    ] `seq` []
#else
legacyJoinExecutionFindingBlock analysis values =
  [ legacyJoinExecutionFinding analysis item
  | item <- legacyJoinExecutionRows values
  , canonicalJoinExecutionFindingRetained item
  ]
#endif

legacyJoinExecutionRows :: [CanonicalLegacyJoin] -> [CanonicalLegacyJoin]
#if defined(VALIDATION_LEGACY_RESULT_JOIN_EXECUTION_ORDER_MUTANT)
legacyJoinExecutionRows = reverse
#else
legacyJoinExecutionRows = id
#endif

legacyBindingObservation :: Int -> CanonicalLegacyBinding -> Observation
#if defined(VALIDATION_LEGACY_BINDING_OBSERVATION_COMPOSITION_MUTANT)
legacyBindingObservation ordinal binding =
  observation (legacyBindingObservationValue binding) (legacyBindingObservationKey ordinal)
#else
legacyBindingObservation ordinal binding =
  observation (legacyBindingObservationKey ordinal) (legacyBindingObservationValue binding)
#endif

legacyBindingObservationKey :: Int -> Text
#if defined(VALIDATION_LEGACY_BINDING_OBSERVATION_KEY_MUTANT)
legacyBindingObservationKey ordinal = "legacy.mutated." <> Text.pack (show ordinal)
#else
legacyBindingObservationKey ordinal = "legacy.binding." <> Text.pack (show ordinal)
#endif

legacyBindingObservationValue :: CanonicalLegacyBinding -> Text
#if defined(VALIDATION_LEGACY_BINDING_OBSERVATION_VALUE_MUTANT)
legacyBindingObservationValue binding =
  Text.length (renderCanonicalBinding binding) `seq` "mutated"
#else
legacyBindingObservationValue = renderCanonicalBinding
#endif

legacyJoinObservation :: Int -> CanonicalLegacyJoin -> Observation
#if defined(VALIDATION_LEGACY_JOIN_OBSERVATION_COMPOSITION_MUTANT)
legacyJoinObservation ordinal item =
  observation (legacyJoinObservationValue item) (legacyJoinObservationKey ordinal)
#else
legacyJoinObservation ordinal item =
  observation (legacyJoinObservationKey ordinal) (legacyJoinObservationValue item)
#endif

legacyJoinObservationKey :: Int -> Text
#if defined(VALIDATION_LEGACY_JOIN_OBSERVATION_KEY_MUTANT)
legacyJoinObservationKey ordinal = "legacy.mutated." <> Text.pack (show ordinal)
#else
legacyJoinObservationKey ordinal = "legacy.join." <> Text.pack (show ordinal)
#endif

legacyJoinObservationValue :: CanonicalLegacyJoin -> Text
#if defined(VALIDATION_LEGACY_JOIN_OBSERVATION_VALUE_ORDER_MUTANT)
legacyJoinObservationValue item =
  legacyJoinObservationTarget item <> legacyJoinObservationSeparator <> legacyJoinObservationSource item
#else
legacyJoinObservationValue item =
  legacyJoinObservationSource item <> legacyJoinObservationSeparator <> legacyJoinObservationTarget item
#endif

legacyJoinObservationSource :: CanonicalLegacyJoin -> Text
#if defined(VALIDATION_LEGACY_JOIN_OBSERVATION_SOURCE_MUTANT)
legacyJoinObservationSource _ = "mutated"
#else
legacyJoinObservationSource = canonicalJoinSource
#endif

legacyJoinObservationSeparator :: Text
#if defined(VALIDATION_LEGACY_JOIN_OBSERVATION_SEPARATOR_MUTANT)
legacyJoinObservationSeparator = "=>"
#else
legacyJoinObservationSeparator = "->"
#endif

legacyJoinObservationTarget :: CanonicalLegacyJoin -> Text
#if defined(VALIDATION_LEGACY_JOIN_OBSERVATION_TARGET_MUTANT)
legacyJoinObservationTarget _ = "mutated"
#else
legacyJoinObservationTarget = canonicalJoinTarget
#endif

legacyResultName :: Text
#if defined(VALIDATION_LEGACY_RESULT_NAME_MUTANT)
legacyResultName = "legacy-diagnostic-mutated"
#else
legacyResultName = "legacy-diagnostic"
#endif

legacyObservationOrder :: [Observation] -> [Observation]
#if defined(VALIDATION_LEGACY_OBSERVATION_ORDER_MUTANT)
legacyObservationOrder values = case values of
  first : second : rest -> second : first : rest
  _ -> values
#else
legacyObservationOrder = id
#endif

legacyFindingOrder :: [Finding] -> [Finding]
#if defined(VALIDATION_LEGACY_FINDING_ORDER_MUTANT)
legacyFindingOrder values = case values of
  first : second : rest -> second : first : rest
  _ -> values
#else
legacyFindingOrder = id
#endif

legacyFixedObservations :: LegacyAnalysis -> [CanonicalLegacyBinding] -> [CanonicalLegacyJoin] -> [Observation]
#if defined(VALIDATION_LEGACY_FIXED_OBSERVATION_COMPONENT_ORDER_MUTANT)
legacyFixedObservations analysis selectedBindings selectedJoins =
  legacyCommitmentDigestObservation analysis
    <> legacyCommitmentKindObservation analysis
    <> legacyPhaseObservation analysis
    <> legacyBindingCountObservation analysis
    <> legacyJoinCountObservation analysis
    <> legacySelectedBindingCountObservation selectedBindings
    <> legacySelectedJoinCountObservation selectedJoins
    <> legacyStatusObservation
#else
legacyFixedObservations analysis selectedBindings selectedJoins =
  legacyCommitmentKindObservation analysis
    <> legacyCommitmentDigestObservation analysis
    <> legacyPhaseObservation analysis
    <> legacyBindingCountObservation analysis
    <> legacyJoinCountObservation analysis
    <> legacySelectedBindingCountObservation selectedBindings
    <> legacySelectedJoinCountObservation selectedJoins
    <> legacyStatusObservation
#endif

legacyCommitmentKindObservation :: LegacyAnalysis -> [Observation]
#if defined(VALIDATION_LEGACY_OBSERVATION_COMMITMENT_KIND_DROP_MUTANT)
legacyCommitmentKindObservation analysis =
  legacyCommitmentKindKey `seq` legacyCommitmentKindValue analysis `seq` []
#else
legacyCommitmentKindObservation analysis = [observation legacyCommitmentKindKey (legacyCommitmentKindValue analysis)]
#endif

legacyCommitmentKindKey :: Text
#if defined(VALIDATION_LEGACY_OBSERVATION_COMMITMENT_KIND_KEY_MUTANT)
legacyCommitmentKindKey = "legacy.mutated"
#else
legacyCommitmentKindKey = "legacy.input-commitment.kind"
#endif

legacyCommitmentKindValue :: LegacyAnalysis -> Text
#if defined(VALIDATION_LEGACY_OBSERVATION_COMMITMENT_KIND_VALUE_MUTANT)
legacyCommitmentKindValue _ = "mutated"
#else
legacyCommitmentKindValue = legacyCommitmentKind
#endif

legacyCommitmentDigestObservation :: LegacyAnalysis -> [Observation]
#if defined(VALIDATION_LEGACY_OBSERVATION_COMMITMENT_DIGEST_DROP_MUTANT)
legacyCommitmentDigestObservation analysis =
  legacyCommitmentDigestKey `seq` legacyCommitmentDigestValue analysis `seq` []
#else
legacyCommitmentDigestObservation analysis = [observation legacyCommitmentDigestKey (legacyCommitmentDigestValue analysis)]
#endif

legacyCommitmentDigestKey :: Text
#if defined(VALIDATION_LEGACY_OBSERVATION_COMMITMENT_DIGEST_KEY_MUTANT)
legacyCommitmentDigestKey = "legacy.mutated"
#else
legacyCommitmentDigestKey = "legacy.input-commitment.sha256"
#endif

legacyCommitmentDigestValue :: LegacyAnalysis -> Text
#if defined(VALIDATION_LEGACY_OBSERVATION_COMMITMENT_DIGEST_VALUE_MUTANT)
legacyCommitmentDigestValue _ = "mutated"
#else
legacyCommitmentDigestValue = legacyCommitmentDigest
#endif

legacyPhaseObservation :: LegacyAnalysis -> [Observation]
#if defined(VALIDATION_LEGACY_OBSERVATION_PHASE_DROP_MUTANT)
legacyPhaseObservation analysis =
  legacyPhaseKey `seq` legacyPhaseValue analysis `seq` []
#else
legacyPhaseObservation analysis = [observation legacyPhaseKey (legacyPhaseValue analysis)]
#endif

legacyPhaseKey :: Text
#if defined(VALIDATION_LEGACY_OBSERVATION_PHASE_KEY_MUTANT)
legacyPhaseKey = "legacy.mutated"
#else
legacyPhaseKey = "legacy.input.candidate-phase"
#endif

legacyPhaseValue :: LegacyAnalysis -> Text
#if defined(VALIDATION_LEGACY_OBSERVATION_PHASE_VALUE_MUTANT)
legacyPhaseValue _ = "mutated"
#else
legacyPhaseValue = legacySafePhase
#endif

legacyBindingCountObservation :: LegacyAnalysis -> [Observation]
#if defined(VALIDATION_LEGACY_OBSERVATION_BINDING_COUNT_DROP_MUTANT)
legacyBindingCountObservation analysis =
  legacyBindingCountKey `seq` legacyBindingCountValue analysis `seq` []
#else
legacyBindingCountObservation analysis = [observation legacyBindingCountKey (legacyBindingCountValue analysis)]
#endif

legacyBindingCountKey :: Text
#if defined(VALIDATION_LEGACY_OBSERVATION_BINDING_COUNT_KEY_MUTANT)
legacyBindingCountKey = "legacy.mutated"
#else
legacyBindingCountKey = "legacy.input.binding-count"
#endif

legacyBindingCountValue :: LegacyAnalysis -> Text
#if defined(VALIDATION_LEGACY_OBSERVATION_BINDING_COUNT_VALUE_MUTANT)
legacyBindingCountValue analysis =
  Text.length (legacySafeBindingCount analysis) `seq` "mutated"
#else
legacyBindingCountValue = legacySafeBindingCount
#endif

legacyJoinCountObservation :: LegacyAnalysis -> [Observation]
#if defined(VALIDATION_LEGACY_OBSERVATION_JOIN_COUNT_DROP_MUTANT)
legacyJoinCountObservation analysis =
  legacyJoinCountKey `seq` legacyJoinCountValue analysis `seq` []
#else
legacyJoinCountObservation analysis = [observation legacyJoinCountKey (legacyJoinCountValue analysis)]
#endif

legacyJoinCountKey :: Text
#if defined(VALIDATION_LEGACY_OBSERVATION_JOIN_COUNT_KEY_MUTANT)
legacyJoinCountKey = "legacy.mutated"
#else
legacyJoinCountKey = "legacy.input.join-count"
#endif

legacyJoinCountValue :: LegacyAnalysis -> Text
#if defined(VALIDATION_LEGACY_OBSERVATION_JOIN_COUNT_VALUE_MUTANT)
legacyJoinCountValue analysis =
  Text.length (legacySafeJoinCount analysis) `seq` "mutated"
#else
legacyJoinCountValue = legacySafeJoinCount
#endif

legacySelectedBindingCountObservation :: [CanonicalLegacyBinding] -> [Observation]
#if defined(VALIDATION_LEGACY_OBSERVATION_SELECTED_BINDING_COUNT_DROP_MUTANT)
legacySelectedBindingCountObservation values =
  legacySelectedBindingCountKey `seq` legacySelectedBindingCountValue values `seq` []
#else
legacySelectedBindingCountObservation values = [observation legacySelectedBindingCountKey (legacySelectedBindingCountValue values)]
#endif

legacySelectedBindingCountKey :: Text
#if defined(VALIDATION_LEGACY_OBSERVATION_SELECTED_BINDING_COUNT_KEY_MUTANT)
legacySelectedBindingCountKey = "legacy.mutated"
#else
legacySelectedBindingCountKey = "legacy.derived.selected-binding-count"
#endif

legacySelectedBindingCountValue :: [CanonicalLegacyBinding] -> Text
#if defined(VALIDATION_LEGACY_OBSERVATION_SELECTED_BINDING_COUNT_VALUE_MUTANT)
legacySelectedBindingCountValue _ = "mutated"
#else
legacySelectedBindingCountValue = Text.pack . show . length
#endif

legacySelectedJoinCountObservation :: [CanonicalLegacyJoin] -> [Observation]
#if defined(VALIDATION_LEGACY_OBSERVATION_SELECTED_JOIN_COUNT_DROP_MUTANT)
legacySelectedJoinCountObservation values =
  legacySelectedJoinCountKey `seq` legacySelectedJoinCountValue values `seq` []
#else
legacySelectedJoinCountObservation values = [observation legacySelectedJoinCountKey (legacySelectedJoinCountValue values)]
#endif

legacySelectedJoinCountKey :: Text
#if defined(VALIDATION_LEGACY_OBSERVATION_SELECTED_JOIN_COUNT_KEY_MUTANT)
legacySelectedJoinCountKey = "legacy.mutated"
#else
legacySelectedJoinCountKey = "legacy.derived.selected-join-count"
#endif

legacySelectedJoinCountValue :: [CanonicalLegacyJoin] -> Text
#if defined(VALIDATION_LEGACY_OBSERVATION_SELECTED_JOIN_COUNT_VALUE_MUTANT)
legacySelectedJoinCountValue _ = "mutated"
#else
legacySelectedJoinCountValue = Text.pack . show . length
#endif

legacyStatusObservation :: [Observation]
#if defined(VALIDATION_LEGACY_OBSERVATION_STATUS_DROP_MUTANT)
legacyStatusObservation = legacyStatusKey `seq` legacyStatusValue `seq` []
#else
legacyStatusObservation = [observation legacyStatusKey legacyStatusValue]
#endif

legacyStatusKey :: Text
#if defined(VALIDATION_LEGACY_OBSERVATION_STATUS_KEY_MUTANT)
legacyStatusKey = "legacy.mutated"
#else
legacyStatusKey = "legacy.diagnostic-status"
#endif

legacyStatusValue :: Text
#if defined(VALIDATION_LEGACY_OBSERVATION_STATUS_VALUE_MUTANT)
legacyStatusValue = "mutated"
#else
legacyStatusValue = "refused"
#endif

analyzeLegacyInput :: Text -> [RawLegacyBinding] -> [RawLegacyJoin] -> LegacyAnalysis
analyzeLegacyInput phase bindings joins =
  case legacyPhasePreflight phase of
    LegacyPrefixExceeded observed _ ->
      legacyResourceFailure phase bindings joins "<over-limit>" "unavailable" "unavailable"
        (guardedLegacyResourceProblem "phase-byte-limit" (legacyPhaseByteLimitExceeded observed) (LegacyPhaseByteLimit maximumLegacyPhaseBytes observed))
    LegacyPrefixWithin _ ->
      case legacyBindingCountPreflight bindings of
        LegacyPrefixExceeded observed _ ->
          legacyResourceFailure phase bindings joins phase (Text.pack (show observed) <> "+") "unavailable"
            (guardedLegacyResourceProblem "binding-limit" (legacyBindingLimitExceeded observed) (LegacyBindingLimit maximumLegacyBindings observed))
        LegacyPrefixWithin boundedBindings ->
          case legacyJoinCountPreflight joins of
            LegacyPrefixExceeded observed _ ->
              legacyResourceFailure phase boundedBindings joins phase (Text.pack (show (length boundedBindings))) (Text.pack (show observed) <> "+")
                (guardedLegacyResourceProblem "join-limit" (legacyJoinLimitExceeded observed) (LegacyJoinLimit maximumLegacyJoins observed))
            LegacyPrefixWithin boundedJoins ->
              case legacyAnalysisResourceProblemRoute
                     (firstLegacyResourceProblem boundedBindings boundedJoins) of
                Just problem ->
                  legacyResourceFailure phase boundedBindings boundedJoins phase
                    (Text.pack (show (length boundedBindings)))
                    (Text.pack (show (length boundedJoins)))
                    problem
                Nothing ->
                  legacyCompleteAnalysis phase boundedBindings boundedJoins

legacyPhasePreflight :: Text -> LegacyPrefix Char
#if defined(VALIDATION_LEGACY_ANALYSIS_PHASE_PREFLIGHT_ROUTE_MUTANT)
legacyPhasePreflight value = case boundedLegacyText maximumLegacyPhaseBytes value of
  LegacyPrefixExceeded _ bounded -> LegacyPrefixWithin bounded
  result -> result
#else
legacyPhasePreflight = boundedLegacyText maximumLegacyPhaseBytes
#endif

legacyBindingCountPreflight :: [RawLegacyBinding] -> LegacyPrefix RawLegacyBinding
#if defined(VALIDATION_LEGACY_ANALYSIS_BINDING_PREFLIGHT_ROUTE_MUTANT)
legacyBindingCountPreflight values = case boundedLegacyPrefix maximumLegacyBindings values of
  LegacyPrefixExceeded _ bounded -> LegacyPrefixWithin bounded
  result -> result
#else
legacyBindingCountPreflight = boundedLegacyPrefix maximumLegacyBindings
#endif

legacyJoinCountPreflight :: [RawLegacyJoin] -> LegacyPrefix RawLegacyJoin
#if defined(VALIDATION_LEGACY_ANALYSIS_JOIN_PREFLIGHT_ROUTE_MUTANT)
legacyJoinCountPreflight values = case boundedLegacyPrefix maximumLegacyJoins values of
  LegacyPrefixExceeded _ bounded -> LegacyPrefixWithin bounded
  result -> result
#else
legacyJoinCountPreflight = boundedLegacyPrefix maximumLegacyJoins
#endif

legacyAnalysisResourceProblemRoute :: Maybe LegacyRawProblem -> Maybe LegacyRawProblem
#if defined(VALIDATION_LEGACY_ANALYSIS_RESOURCE_PROBLEM_ROUTE_MUTANT)
legacyAnalysisResourceProblemRoute selected = case selected of
  Nothing -> Nothing
  Just problem -> problem `seq` Nothing
#else
legacyAnalysisResourceProblemRoute = id
#endif

legacyCompleteAnalysis :: Text -> [RawLegacyBinding] -> [RawLegacyJoin] -> LegacyAnalysis
#if defined(VALIDATION_LEGACY_COMPLETE_ANALYSIS_FIELD_ORDER_MUTANT)
legacyCompleteAnalysis phase bindings joins =
  LegacyAnalysis
    legacyCompleteCommitmentKind
    (legacyCompleteCommitmentDigest phase bindings joins)
    (legacyCompleteBindingCount bindings)
    (legacyCompleteSafePhase phase)
    (legacyCompleteJoinCount joins)
    (legacyCompleteProblems phase bindings joins)
#else
legacyCompleteAnalysis phase bindings joins =
  LegacyAnalysis
    legacyCompleteCommitmentKind
    (legacyCompleteCommitmentDigest phase bindings joins)
    (legacyCompleteSafePhase phase)
    (legacyCompleteBindingCount bindings)
    (legacyCompleteJoinCount joins)
    (legacyCompleteProblems phase bindings joins)
#endif

legacyCompleteCommitmentKind :: Text
#if defined(VALIDATION_LEGACY_ANALYSIS_COMPLETE_KIND_MUTANT)
legacyCompleteCommitmentKind = "mutated"
#else
legacyCompleteCommitmentKind = "complete-input"
#endif

legacyCompleteCommitmentDigest :: Text -> [RawLegacyBinding] -> [RawLegacyJoin] -> Text
#if defined(VALIDATION_LEGACY_ANALYSIS_COMPLETE_DIGEST_MUTANT)
legacyCompleteCommitmentDigest phase bindings joins =
  Text.length (legacyCompleteDigest phase bindings joins) `seq` "mutated"
#else
legacyCompleteCommitmentDigest = legacyCompleteDigest
#endif

legacyCompleteSafePhase :: Text -> Text
#if defined(VALIDATION_LEGACY_ANALYSIS_COMPLETE_PHASE_MUTANT)
legacyCompleteSafePhase _ = "mutated"
#else
legacyCompleteSafePhase = id
#endif

legacyCompleteBindingCount :: [RawLegacyBinding] -> Text
#if defined(VALIDATION_LEGACY_ANALYSIS_COMPLETE_BINDING_COUNT_MUTANT)
legacyCompleteBindingCount _ = "mutated"
#else
legacyCompleteBindingCount = Text.pack . show . length
#endif

legacyCompleteJoinCount :: [RawLegacyJoin] -> Text
#if defined(VALIDATION_LEGACY_ANALYSIS_COMPLETE_JOIN_COUNT_MUTANT)
legacyCompleteJoinCount _ = "mutated"
#else
legacyCompleteJoinCount = Text.pack . show . length
#endif

legacyCompleteProblems :: Text -> [RawLegacyBinding] -> [RawLegacyJoin] -> [LegacyRawProblem]
#if defined(VALIDATION_LEGACY_ANALYSIS_COMPLETE_PROBLEM_DROP_MUTANT)
legacyCompleteProblems phase bindings joins =
  legacyGrammarProblem phase bindings joins `seq` []
#else
legacyCompleteProblems phase bindings joins = maybe [] pure (legacyGrammarProblem phase bindings joins)
#endif

legacyResourceFailure
  :: Text -> [RawLegacyBinding] -> [RawLegacyJoin] -> Text -> Text -> Text
  -> LegacyRawProblem -> LegacyAnalysis
legacyResourceFailure phase bindings joins safePhase bindingCount joinCount problem =
#if defined(VALIDATION_LEGACY_RESOURCE_ANALYSIS_FIELD_ORDER_MUTANT)
  LegacyAnalysis
    legacyResourceCommitmentKind
    (legacyResourceCommitmentDigest phase bindings joins problem)
    (legacyResourceBindingCount bindingCount)
    (legacyResourceSafePhase safePhase)
    (legacyResourceJoinCount joinCount)
    (legacyResourceProblems problem)
#else
  LegacyAnalysis
    legacyResourceCommitmentKind
    (legacyResourceCommitmentDigest phase bindings joins problem)
    (legacyResourceSafePhase safePhase)
    (legacyResourceBindingCount bindingCount)
    (legacyResourceJoinCount joinCount)
    (legacyResourceProblems problem)
#endif

legacyResourceCommitmentKind :: Text
#if defined(VALIDATION_LEGACY_ANALYSIS_RESOURCE_KIND_MUTANT)
legacyResourceCommitmentKind = "mutated"
#else
legacyResourceCommitmentKind = "bounded-preflight-refusal"
#endif

legacyResourceCommitmentDigest :: Text -> [RawLegacyBinding] -> [RawLegacyJoin] -> LegacyRawProblem -> Text
#if defined(VALIDATION_LEGACY_ANALYSIS_RESOURCE_DIGEST_MUTANT)
legacyResourceCommitmentDigest phase bindings joins problem =
  Text.length (legacyBoundedDigest phase bindings joins problem) `seq` "mutated"
#else
legacyResourceCommitmentDigest = legacyBoundedDigest
#endif

legacyResourceSafePhase :: Text -> Text
#if defined(VALIDATION_LEGACY_ANALYSIS_RESOURCE_PHASE_MUTANT)
legacyResourceSafePhase _ = "mutated"
#else
legacyResourceSafePhase = id
#endif

legacyResourceBindingCount :: Text -> Text
#if defined(VALIDATION_LEGACY_ANALYSIS_RESOURCE_BINDING_COUNT_MUTANT)
legacyResourceBindingCount _ = "mutated"
#else
legacyResourceBindingCount = id
#endif

legacyResourceJoinCount :: Text -> Text
#if defined(VALIDATION_LEGACY_ANALYSIS_RESOURCE_JOIN_COUNT_MUTANT)
legacyResourceJoinCount _ = "mutated"
#else
legacyResourceJoinCount = id
#endif

legacyResourceProblems :: LegacyRawProblem -> [LegacyRawProblem]
#if defined(VALIDATION_LEGACY_ANALYSIS_RESOURCE_PROBLEM_DROP_MUTANT)
legacyResourceProblems problem = problem `seq` []
#else
legacyResourceProblems = pure
#endif

firstLegacyResourceProblem :: [RawLegacyBinding] -> [RawLegacyJoin] -> Maybe LegacyRawProblem
firstLegacyResourceProblem bindings joins =
  firstPresent
    ( legacyResourceProblemOrder
        (legacyBindingResourceClassRoute
          (concat
            [ bindingResourceProblems ordinal row
            | (ordinal, row) <- legacyBindingResourceRows bindings
            ]))
        (legacyJoinResourceClassRoute
          (concat
            [ joinResourceProblems ordinal item
            | (ordinal, item) <- legacyJoinResourceRows joins
            ]))
        (legacyAggregateResourceClassRoute
          [ if aggregate > maximumLegacyAggregateBytes
                 then Just
                   (guardedLegacyResourceProblem "aggregate-byte-limit" (legacyAggregateByteLimitExceeded aggregate) (LegacyAggregateByteLimit maximumLegacyAggregateBytes aggregate))
                 else Nothing
          ])
    )
 where
  aggregate = legacyAggregateBytes bindings joins

legacyBindingResourceClassRoute :: [Maybe LegacyRawProblem] -> [Maybe LegacyRawProblem]
#if defined(VALIDATION_LEGACY_RESOURCE_BINDING_CLASS_DROP_MUTANT)
legacyBindingResourceClassRoute values = length values `seq` []
#else
legacyBindingResourceClassRoute = id
#endif

legacyJoinResourceClassRoute :: [Maybe LegacyRawProblem] -> [Maybe LegacyRawProblem]
#if defined(VALIDATION_LEGACY_RESOURCE_JOIN_CLASS_DROP_MUTANT)
legacyJoinResourceClassRoute values = length values `seq` []
#else
legacyJoinResourceClassRoute = id
#endif

legacyAggregateResourceClassRoute :: [Maybe LegacyRawProblem] -> [Maybe LegacyRawProblem]
#if defined(VALIDATION_LEGACY_RESOURCE_AGGREGATE_CLASS_DROP_MUTANT)
legacyAggregateResourceClassRoute values = length values `seq` []
#else
legacyAggregateResourceClassRoute = id
#endif

legacyBindingResourceRows :: [RawLegacyBinding] -> [(Int, RawLegacyBinding)]
#if defined(VALIDATION_LEGACY_RESOURCE_BINDING_ROW_ORDER_MUTANT)
legacyBindingResourceRows = reverse . zip [(1 :: Int) ..]
#else
legacyBindingResourceRows = zip [(1 :: Int) ..]
#endif

legacyJoinResourceRows :: [RawLegacyJoin] -> [(Int, RawLegacyJoin)]
#if defined(VALIDATION_LEGACY_RESOURCE_JOIN_ROW_ORDER_MUTANT)
legacyJoinResourceRows = reverse . zip [(1 :: Int) ..]
#else
legacyJoinResourceRows = zip [(1 :: Int) ..]
#endif

legacyResourceProblemOrder
  :: [Maybe LegacyRawProblem] -> [Maybe LegacyRawProblem] -> [Maybe LegacyRawProblem]
  -> [Maybe LegacyRawProblem]
#if defined(VALIDATION_LEGACY_RESOURCE_CLASS_ORDER_MUTANT)
legacyResourceProblemOrder bindingProblems joinProblems aggregateProblems =
  joinProblems <> bindingProblems <> aggregateProblems
#else
legacyResourceProblemOrder bindingProblems joinProblems aggregateProblems =
  bindingProblems <> joinProblems <> aggregateProblems
#endif

bindingResourceProblems :: Int -> RawLegacyBinding -> [Maybe LegacyRawProblem]
bindingResourceProblems ordinal (identifier, disposition, owner, analyzer, observed, closed, reintroduced) =
  legacyBindingResourceFieldOrder
  [ textLimit maximumLegacyIdBytes identifier
      (\maximumValue actual -> LegacyIdByteLimit ordinal maximumValue actual)
      legacyIdByteLimitExceeded
      "id-byte-limit"
  , textLimit maximumLegacyDispositionBytes disposition
      (\maximumValue actual -> LegacyDispositionByteLimit ordinal maximumValue actual)
      legacyDispositionByteLimitExceeded
      "disposition-byte-limit"
  , textLimit maximumLegacyOwnerBytes owner
      (\maximumValue actual -> LegacyOwnerByteLimit ordinal maximumValue actual)
      legacyOwnerByteLimitExceeded
      "owner-byte-limit"
  , textLimit maximumLegacyAnalyzerBytes analyzer
      (\maximumValue actual -> LegacyAnalyzerByteLimit ordinal maximumValue actual)
      legacyAnalyzerByteLimitExceeded
      "analyzer-byte-limit"
  , textLimit maximumLegacyObservationBytes observed
      (\maximumValue actual -> LegacyObservationByteLimit ordinal maximumValue actual)
      legacyObservationByteLimitExceeded
      "observation-byte-limit"
  , textLimit maximumLegacyClosureBytes closed
      (\maximumValue actual -> LegacyClosureByteLimit ordinal maximumValue actual)
      legacyClosureByteLimitExceeded
      "closure-byte-limit"
  , case boundedLegacyPrefix maximumLegacyReintroductionValues reintroduced of
      LegacyPrefixExceeded actual _ ->
        Just
          (guardedLegacyResourceProblem "reintroduction-count-limit"
            (legacyReintroductionCountLimitExceeded actual)
            (LegacyReintroductionCountLimit ordinal maximumLegacyReintroductionValues actual))
      LegacyPrefixWithin _ -> Nothing
  ]
    <> case boundedLegacyPrefix maximumLegacyReintroductionValues reintroduced of
      LegacyPrefixExceeded _ _ -> []
      LegacyPrefixWithin bounded ->
        [ textLimit maximumLegacyReintroductionBytes value
            (\maximumValue actual -> LegacyReintroductionByteLimit ordinal reintroductionOrdinal maximumValue actual)
            legacyReintroductionByteLimitExceeded
            "reintroduction-byte-limit"
        | (reintroductionOrdinal, value) <- zip [(1 :: Int) ..] bounded
        ]

legacyBindingResourceFieldOrder :: [Maybe LegacyRawProblem] -> [Maybe LegacyRawProblem]
#if defined(VALIDATION_LEGACY_RESOURCE_BINDING_FIELD_ORDER_MUTANT)
legacyBindingResourceFieldOrder values = case values of
  first : second : rest -> second : first : rest
  _ -> values
#else
legacyBindingResourceFieldOrder = id
#endif

joinResourceProblems :: Int -> RawLegacyJoin -> [Maybe LegacyRawProblem]
joinResourceProblems ordinal (source, target) =
  legacyJoinResourceFieldOrder
  [ textLimit maximumLegacyJoinSourceBytes source
      (\maximumValue actual -> LegacyJoinSourceByteLimit ordinal maximumValue actual)
      legacyJoinSourceByteLimitExceeded
      "join-source-byte-limit"
  , textLimit maximumLegacyJoinTargetBytes target
      (\maximumValue actual -> LegacyJoinTargetByteLimit ordinal maximumValue actual)
      legacyJoinTargetByteLimitExceeded
      "join-target-byte-limit"
  ]

legacyJoinResourceFieldOrder :: [Maybe LegacyRawProblem] -> [Maybe LegacyRawProblem]
#if defined(VALIDATION_LEGACY_RESOURCE_JOIN_FIELD_ORDER_MUTANT)
legacyJoinResourceFieldOrder values = reverse values
#else
legacyJoinResourceFieldOrder = id
#endif

textLimit
  :: Int -> Text -> (Int -> Int -> LegacyRawProblem) -> (Int -> Bool) -> Text
  -> Maybe LegacyRawProblem
#if defined(VALIDATION_LEGACY_TEXT_LIMIT_ROUTE_MUTANT)
textLimit maximumValue value makeProblem predicate label =
  case boundedLegacyText maximumValue value of
    LegacyPrefixWithin _ -> Nothing
    LegacyPrefixExceeded actual _ ->
      makeProblem maximumValue actual `seq`
        predicate actual `seq` label `seq` Nothing
#else
textLimit maximumValue value makeProblem predicate label =
  case boundedLegacyText maximumValue value of
    LegacyPrefixWithin _ -> Nothing
    LegacyPrefixExceeded actual _ ->
      Just (guardedLegacyResourceProblem label (predicate actual) (makeProblem maximumValue actual))
#endif

guardedLegacyResourceProblem :: Text -> Bool -> LegacyRawProblem -> LegacyRawProblem
#if defined(VALIDATION_LEGACY_RESOURCE_GUARD_ROUTE_MUTANT)
guardedLegacyResourceProblem label predicate specific =
  predicate `seq` specific `seq` LegacyResourceGuardUnavailable label
#else
guardedLegacyResourceProblem label predicate specific
  | predicate = specific
  | otherwise = LegacyResourceGuardUnavailable label
#endif

legacyGrammarProblem :: Text -> [RawLegacyBinding] -> [RawLegacyJoin] -> Maybe LegacyRawProblem
legacyGrammarProblem phase bindings joins =
  firstPresent
    (legacyGrammarProblemOrder
    (legacyPhaseGrammarClassRoute
      [ if legacyPhaseWidthValid phase then Nothing else Just LegacyPhaseWidth
      , if legacyPhaseAlphabetValid phase then Nothing else Just LegacyPhaseAlphabet
      , if legacyPhaseRangeValid phase then Nothing else Just LegacyPhaseRange
      ])
    (legacyBindingGrammarClassRoute (bindingGrammarProblem bindings))
    (legacyJoinGrammarClassRoute (joinGrammarProblem joins)))

legacyPhaseGrammarClassRoute :: [Maybe LegacyRawProblem] -> [Maybe LegacyRawProblem]
#if defined(VALIDATION_LEGACY_GRAMMAR_PHASE_CLASS_DROP_MUTANT)
legacyPhaseGrammarClassRoute values = length values `seq` []
#else
legacyPhaseGrammarClassRoute = id
#endif

legacyBindingGrammarClassRoute :: Maybe LegacyRawProblem -> Maybe LegacyRawProblem
#if defined(VALIDATION_LEGACY_GRAMMAR_BINDING_CLASS_DROP_MUTANT)
legacyBindingGrammarClassRoute selected = selected `seq` Nothing
#else
legacyBindingGrammarClassRoute = id
#endif

legacyJoinGrammarClassRoute :: Maybe LegacyRawProblem -> Maybe LegacyRawProblem
#if defined(VALIDATION_LEGACY_GRAMMAR_JOIN_CLASS_DROP_MUTANT)
legacyJoinGrammarClassRoute selected = selected `seq` Nothing
#else
legacyJoinGrammarClassRoute = id
#endif

legacyGrammarProblemOrder
  :: [Maybe LegacyRawProblem] -> Maybe LegacyRawProblem -> Maybe LegacyRawProblem
  -> [Maybe LegacyRawProblem]
#if defined(VALIDATION_LEGACY_GRAMMAR_CLASS_ORDER_MUTANT)
legacyGrammarProblemOrder phaseProblems bindingProblem joinProblem =
  [bindingProblem, joinProblem] <> legacyPhaseGrammarOrder phaseProblems
#else
legacyGrammarProblemOrder phaseProblems bindingProblem joinProblem =
  legacyPhaseGrammarOrder phaseProblems <> [bindingProblem, joinProblem]
#endif

legacyPhaseGrammarOrder :: [Maybe LegacyRawProblem] -> [Maybe LegacyRawProblem]
#if defined(VALIDATION_LEGACY_GRAMMAR_PHASE_ORDER_MUTANT)
legacyPhaseGrammarOrder = reverse
#else
legacyPhaseGrammarOrder = id
#endif

bindingGrammarProblem :: [RawLegacyBinding] -> Maybe LegacyRawProblem
bindingGrammarProblem bindings = firstPresent (legacyBindingGrammarProblemOrder problems)
 where
  rawIds = map rawBindingId bindings
  expectedIds = map canonicalBindingId canonicalLegacyBindings
  problems =
    [ if legacyBindingCardinalityValid bindings
        then Nothing
        else Just (LegacyBindingCardinality maximumLegacyBindings (length bindings))
    , LegacyBindingDuplicate <$> firstDuplicate legacyBindingDuplicateRejected (legacyBindingDuplicateSearchOrder rawIds)
    , LegacyBindingUnknown <$> firstUnknown legacyBindingUnknownRejected expectedIds (legacyBindingUnknownSearchOrder rawIds)
    , if legacyBindingOrderValid rawIds then Nothing else Just (LegacyBindingOrder rawIds)
    , firstPresent
        [ bindingFieldProblem ordinal expected actual
        | (ordinal, (expected, actual)) <- legacyBindingGrammarRows canonicalLegacyBindings bindings
        ]
    ]

legacyBindingGrammarProblemOrder :: [Maybe LegacyRawProblem] -> [Maybe LegacyRawProblem]
#if defined(VALIDATION_LEGACY_GRAMMAR_BINDING_PROBLEM_ORDER_MUTANT)
legacyBindingGrammarProblemOrder = reverse
#else
legacyBindingGrammarProblemOrder = id
#endif

legacyBindingDuplicateSearchOrder, legacyBindingUnknownSearchOrder :: [Text] -> [Text]
#if defined(VALIDATION_LEGACY_GRAMMAR_BINDING_DUPLICATE_SEARCH_ORDER_MUTANT)
legacyBindingDuplicateSearchOrder = reverse
#else
legacyBindingDuplicateSearchOrder = id
#endif
#if defined(VALIDATION_LEGACY_GRAMMAR_BINDING_UNKNOWN_SEARCH_ORDER_MUTANT)
legacyBindingUnknownSearchOrder = reverse
#else
legacyBindingUnknownSearchOrder = id
#endif

legacyBindingGrammarRows
  :: [CanonicalLegacyBinding] -> [RawLegacyBinding]
  -> [(Int, (CanonicalLegacyBinding, RawLegacyBinding))]
#if defined(VALIDATION_LEGACY_GRAMMAR_BINDING_ROW_ORDER_MUTANT)
legacyBindingGrammarRows expected actual = reverse (zip [(1 :: Int) ..] (zip expected actual))
#else
legacyBindingGrammarRows expected actual = zip [(1 :: Int) ..] (zip expected actual)
#endif

bindingFieldProblem :: Int -> CanonicalLegacyBinding -> RawLegacyBinding -> Maybe LegacyRawProblem
bindingFieldProblem ordinal expected (_, disposition, owner, analyzer, observed, closed, reintroduced) =
  firstPresent
    (legacyBindingGrammarFieldOrder
    [ mismatch "disposition" legacyDispositionMatches (canonicalBindingDisposition expected) disposition
    , mismatch "owner" legacyOwnerMatches (canonicalBindingOwner expected) owner
    , mismatch "analyzer" legacyAnalyzerMatches (canonicalBindingAnalyzer expected) analyzer
    , mismatch "observation" legacyObservationMatches (canonicalBindingObservation expected) observed
    , mismatch "closure" legacyClosureMatches (canonicalBindingClosure expected) closed
    , if legacyReintroductionMatches (canonicalBindingReintroduction expected) reintroduced
        then Nothing
        else Just
          (LegacyBindingFieldMismatch ordinal "reintroduction"
            (Text.pack (show (canonicalBindingReintroduction expected)))
            (Text.pack (show reintroduced)))
    ])
 where
  mismatch field predicate expectedValue actualValue
    | predicate expectedValue actualValue = Nothing
    | otherwise = Just (LegacyBindingFieldMismatch ordinal field expectedValue actualValue)

legacyBindingGrammarFieldOrder :: [Maybe LegacyRawProblem] -> [Maybe LegacyRawProblem]
#if defined(VALIDATION_LEGACY_GRAMMAR_BINDING_FIELD_ORDER_MUTANT)
legacyBindingGrammarFieldOrder values = reverse values
#else
legacyBindingGrammarFieldOrder = id
#endif

joinGrammarProblem :: [RawLegacyJoin] -> Maybe LegacyRawProblem
joinGrammarProblem joins = firstPresent (legacyJoinGrammarProblemOrder problems)
 where
  rawSources = map fst joins
  expectedSources = map canonicalJoinSource canonicalLegacyJoins
  problems =
    [ if legacyJoinCardinalityValid joins
        then Nothing
        else Just (LegacyJoinCardinality maximumLegacyJoins (length joins))
    , LegacyJoinDuplicate <$> firstDuplicate legacyJoinDuplicateRejected (legacyJoinDuplicateSearchOrder rawSources)
    , LegacyJoinUnknown <$> firstUnknown legacyJoinUnknownRejected expectedSources (legacyJoinUnknownSearchOrder rawSources)
    , if legacyJoinOrderValid rawSources then Nothing else Just (LegacyJoinOrder rawSources)
    , firstPresent
        [ if legacyJoinTargetMatches (canonicalJoinTarget expected) actualTarget
            then Nothing
            else Just
              (LegacyJoinTargetMismatch ordinal (canonicalJoinSource expected) (canonicalJoinTarget expected) actualTarget)
        | (ordinal, (expected, (_, actualTarget))) <- legacyJoinGrammarRows canonicalLegacyJoins joins
        ]
    ]

legacyJoinGrammarProblemOrder :: [Maybe LegacyRawProblem] -> [Maybe LegacyRawProblem]
#if defined(VALIDATION_LEGACY_GRAMMAR_JOIN_PROBLEM_ORDER_MUTANT)
legacyJoinGrammarProblemOrder = reverse
#else
legacyJoinGrammarProblemOrder = id
#endif

legacyJoinDuplicateSearchOrder, legacyJoinUnknownSearchOrder :: [Text] -> [Text]
#if defined(VALIDATION_LEGACY_GRAMMAR_JOIN_DUPLICATE_SEARCH_ORDER_MUTANT)
legacyJoinDuplicateSearchOrder = reverse
#else
legacyJoinDuplicateSearchOrder = id
#endif
#if defined(VALIDATION_LEGACY_GRAMMAR_JOIN_UNKNOWN_SEARCH_ORDER_MUTANT)
legacyJoinUnknownSearchOrder = reverse
#else
legacyJoinUnknownSearchOrder = id
#endif

legacyJoinGrammarRows
  :: [CanonicalLegacyJoin] -> [RawLegacyJoin]
  -> [(Int, (CanonicalLegacyJoin, RawLegacyJoin))]
#if defined(VALIDATION_LEGACY_GRAMMAR_JOIN_ROW_ORDER_MUTANT)
legacyJoinGrammarRows expected actual = reverse (zip [(1 :: Int) ..] (zip expected actual))
#else
legacyJoinGrammarRows expected actual = zip [(1 :: Int) ..] (zip expected actual)
#endif

rawBindingId :: RawLegacyBinding -> Text
#if defined(VALIDATION_LEGACY_RAW_BINDING_ID_PROJECTION_MUTANT)
rawBindingId _ = "mutated"
#else
rawBindingId (identifier, _, _, _, _, _, _) = identifier
#endif

firstPresent :: [Maybe value] -> Maybe value
#if defined(VALIDATION_LEGACY_FIRST_PRESENT_RETENTION_MUTANT)
firstPresent = go Nothing
 where
  go selected values = case values of
    [] -> selected
    Nothing : rest -> go selected rest
    Just value : rest -> go (Just value) rest
#else
firstPresent values = case values of
  [] -> Nothing
  Nothing : rest -> firstPresent rest
  Just value : _ -> Just value
#endif

firstDuplicate :: (Text -> [Text] -> Bool) -> [Text] -> Maybe Text
firstDuplicate predicate = go []
 where
  go seen values = case values of
    [] -> Nothing
    value : rest
      | predicate value seen -> Just value
      | otherwise -> go (value : seen) rest

firstUnknown :: ([Text] -> Text -> Bool) -> [Text] -> [Text] -> Maybe Text
firstUnknown predicate expected values = case filter (predicate expected) values of
  [] -> Nothing
  value : _ -> Just value

legacyMandatoryFindings :: LegacyAnalysis -> [Finding]
#if defined(VALIDATION_LEGACY_MANDATORY_FINDING_ORDER_MUTANT)
legacyMandatoryFindings analysis =
  legacySourceCustodyFindings analysis
    <> legacyDiagnosticOnlyFindings analysis
    <> legacyAnalyzerEvidenceFindings analysis
    <> legacyReintroductionExecutionFindings analysis
    <> legacyQualificationFindings analysis
    <> legacyHumanReviewFindings analysis
#else
legacyMandatoryFindings analysis =
  legacyDiagnosticOnlyFindings analysis
    <> legacySourceCustodyFindings analysis
    <> legacyAnalyzerEvidenceFindings analysis
    <> legacyReintroductionExecutionFindings analysis
    <> legacyQualificationFindings analysis
    <> legacyHumanReviewFindings analysis
#endif

legacyDiagnosticOnlyFindings :: LegacyAnalysis -> [Finding]
#if defined(VALIDATION_LEGACY_RAW_DIAGNOSTIC_ONLY_DROP_MUTANT)
legacyDiagnosticOnlyFindings _ = []
#else
legacyDiagnosticOnlyFindings analysis = [legacyMandatoryFinding analysis LegacyMandatoryDiagnosticOnly]
#endif

legacySourceCustodyFindings :: LegacyAnalysis -> [Finding]
#if defined(VALIDATION_LEGACY_RAW_SOURCE_CUSTODY_DROP_MUTANT)
legacySourceCustodyFindings _ = []
#else
legacySourceCustodyFindings analysis = [legacyMandatoryFinding analysis LegacyMandatorySourceCustody]
#endif

legacyAnalyzerEvidenceFindings :: LegacyAnalysis -> [Finding]
#if defined(VALIDATION_LEGACY_RAW_ANALYZER_EVIDENCE_DROP_MUTANT)
legacyAnalyzerEvidenceFindings _ = []
#else
legacyAnalyzerEvidenceFindings analysis = [legacyMandatoryFinding analysis LegacyMandatoryAnalyzerEvidence]
#endif

legacyReintroductionExecutionFindings :: LegacyAnalysis -> [Finding]
#if defined(VALIDATION_LEGACY_RAW_REINTRODUCTION_EXECUTION_DROP_MUTANT)
legacyReintroductionExecutionFindings _ = []
#else
legacyReintroductionExecutionFindings analysis = [legacyMandatoryFinding analysis LegacyMandatoryReintroductionExecution]
#endif

legacyQualificationFindings :: LegacyAnalysis -> [Finding]
#if defined(VALIDATION_LEGACY_RAW_QUALIFICATION_DROP_MUTANT)
legacyQualificationFindings _ = []
#else
legacyQualificationFindings analysis = [legacyMandatoryFinding analysis LegacyMandatoryQualification]
#endif

legacyHumanReviewFindings :: LegacyAnalysis -> [Finding]
#if defined(VALIDATION_LEGACY_RAW_HUMAN_REVIEW_DROP_MUTANT)
legacyHumanReviewFindings _ = []
#else
legacyHumanReviewFindings analysis = [legacyMandatoryFinding analysis LegacyMandatoryHumanReview]
#endif

data LegacyMandatoryKind
  = LegacyMandatoryDiagnosticOnly
  | LegacyMandatorySourceCustody
  | LegacyMandatoryAnalyzerEvidence
  | LegacyMandatoryReintroductionExecution
  | LegacyMandatoryQualification
  | LegacyMandatoryHumanReview

legacyMandatoryFinding :: LegacyAnalysis -> LegacyMandatoryKind -> Finding
#if defined(VALIDATION_LEGACY_MANDATORY_FINDING_COMPOSITION_MUTANT)
legacyMandatoryFinding analysis kind =
  finding
    (legacyMandatoryDetail kind <> legacyCommitmentDetail analysis)
    (legacyMandatorySubject kind)
    (legacyMandatoryCode kind)
#else
legacyMandatoryFinding analysis kind =
  finding
    (legacyMandatoryCode kind)
    (legacyMandatorySubject kind)
    (legacyMandatoryDetail kind <> legacyCommitmentDetail analysis)
#endif

legacyMandatoryCode :: LegacyMandatoryKind -> Text
legacyMandatoryCode kind = case kind of
  LegacyMandatoryDiagnosticOnly ->
#if defined(VALIDATION_LEGACY_MANDATORY_DIAGNOSTIC_ONLY_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-DIAGNOSTIC-ONLY"
#endif
  LegacyMandatorySourceCustody ->
#if defined(VALIDATION_LEGACY_MANDATORY_SOURCE_CUSTODY_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-SOURCE-CUSTODY-UNAVAILABLE"
#endif
  LegacyMandatoryAnalyzerEvidence ->
#if defined(VALIDATION_LEGACY_MANDATORY_ANALYZER_EVIDENCE_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-ANALYZER-EVIDENCE-UNAVAILABLE"
#endif
  LegacyMandatoryReintroductionExecution ->
#if defined(VALIDATION_LEGACY_MANDATORY_REINTRODUCTION_EXECUTION_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-REINTRODUCTION-EXECUTION-UNAVAILABLE"
#endif
  LegacyMandatoryQualification ->
#if defined(VALIDATION_LEGACY_MANDATORY_QUALIFICATION_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-QUALIFICATION-UNAVAILABLE"
#endif
  LegacyMandatoryHumanReview ->
#if defined(VALIDATION_LEGACY_MANDATORY_HUMAN_REVIEW_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-HUMAN-REVIEW-UNAVAILABLE"
#endif

legacyMandatorySubject :: LegacyMandatoryKind -> FilePath
legacyMandatorySubject kind = case kind of
  LegacyMandatoryDiagnosticOnly ->
#if defined(VALIDATION_LEGACY_MANDATORY_DIAGNOSTIC_ONLY_SUBJECT_MUTANT)
    "<mutated>"
#else
    "Amoebius.Validation.Legacy.legacyDiagnostic"
#endif
  LegacyMandatorySourceCustody ->
#if defined(VALIDATION_LEGACY_MANDATORY_SOURCE_CUSTODY_SUBJECT_MUTANT)
    "<mutated>"
#else
    "<caller-supplied-legacy-input>"
#endif
  LegacyMandatoryAnalyzerEvidence ->
#if defined(VALIDATION_LEGACY_MANDATORY_ANALYZER_EVIDENCE_SUBJECT_MUTANT)
    "<mutated>"
#else
    "Amoebius.Validation.Legacy.Internal"
#endif
  LegacyMandatoryReintroductionExecution ->
#if defined(VALIDATION_LEGACY_MANDATORY_REINTRODUCTION_EXECUTION_SUBJECT_MUTANT)
    "<mutated>"
#else
    "legacy-reintroduction-corpus"
#endif
  LegacyMandatoryQualification ->
#if defined(VALIDATION_LEGACY_MANDATORY_QUALIFICATION_SUBJECT_MUTANT)
    "<mutated>"
#else
    "legacy-changed-subject-matrix"
#endif
  LegacyMandatoryHumanReview ->
#if defined(VALIDATION_LEGACY_MANDATORY_HUMAN_REVIEW_SUBJECT_MUTANT)
    "<mutated>"
#else
    "DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md"
#endif

legacyMandatoryDetail :: LegacyMandatoryKind -> Text
legacyMandatoryDetail kind = case kind of
  LegacyMandatoryDiagnosticOnly ->
#if defined(VALIDATION_LEGACY_MANDATORY_DIAGNOSTIC_ONLY_DETAIL_MUTANT)
    "mutated"
#else
    "caller-declared legacy wire cannot mint candidate evidence"
#endif
  LegacyMandatorySourceCustody ->
#if defined(VALIDATION_LEGACY_MANDATORY_SOURCE_CUSTODY_DETAIL_MUTANT)
    "mutated"
#else
    "no authenticated atomic source acquisition is attached"
#endif
  LegacyMandatoryAnalyzerEvidence ->
#if defined(VALIDATION_LEGACY_MANDATORY_ANALYZER_EVIDENCE_DETAIL_MUTANT)
    "mutated"
#else
    "package-hidden owner analyzers have not produced snapshot-bound observations"
#endif
  LegacyMandatoryReintroductionExecution ->
#if defined(VALIDATION_LEGACY_MANDATORY_REINTRODUCTION_EXECUTION_DETAIL_MUTANT)
    "mutated"
#else
    "declared case identities do not establish execution of the owning negative corpus"
#endif
  LegacyMandatoryQualification ->
#if defined(VALIDATION_LEGACY_MANDATORY_QUALIFICATION_DETAIL_MUTANT)
    "mutated"
#else
    "the fixed changed-production corpus has not executed against this exact subject"
#endif
  LegacyMandatoryHumanReview ->
#if defined(VALIDATION_LEGACY_MANDATORY_HUMAN_REVIEW_DETAIL_MUTANT)
    "mutated"
#else
    "reader-facing prose correspondence has not received independent human review"
#endif

legacyPhaseRouteFindings :: LegacyAnalysis -> [Finding]
legacyPhaseRouteFindings analysis
  | legacyPhaseProblemsClear analysis =
      if legacyPhaseIsGenesis analysis
        then []
        else if legacyLaterPhaseBlocked
          then [legacyPhaseBlockedFinding analysis]
          else []
  | otherwise = []

legacyPhaseProblemsClear :: LegacyAnalysis -> Bool
#if defined(VALIDATION_LEGACY_PHASE_PROBLEM_GATE_MUTANT)
legacyPhaseProblemsClear _ = False
#else
legacyPhaseProblemsClear = null . legacyProblems
#endif

legacyPhaseIsGenesis :: LegacyAnalysis -> Bool
#if defined(VALIDATION_LEGACY_PHASE_GENESIS_ROUTE_MUTANT)
legacyPhaseIsGenesis _ = False
#else
legacyPhaseIsGenesis analysis = legacySafePhase analysis == "00"
#endif

legacyPhaseBlockedFinding :: LegacyAnalysis -> Finding
#if defined(VALIDATION_LEGACY_PHASE_BLOCKED_FINDING_COMPOSITION_MUTANT)
legacyPhaseBlockedFinding analysis =
  finding
    (legacyPhaseBlockedDetail <> legacyCommitmentDetail analysis)
    (legacyPhaseBlockedSubject analysis)
    legacyPhaseBlockedCode
#else
legacyPhaseBlockedFinding analysis =
  finding
    legacyPhaseBlockedCode
    (legacyPhaseBlockedSubject analysis)
    (legacyPhaseBlockedDetail <> legacyCommitmentDetail analysis)
#endif

legacyPhaseBlockedCode :: Text
#if defined(VALIDATION_LEGACY_PHASE_BLOCKED_CODE_MUTANT)
legacyPhaseBlockedCode = "LEGACY-MUTATED"
#else
legacyPhaseBlockedCode = "LEGACY-PHASE-BLOCKED"
#endif

legacyPhaseBlockedSubject :: LegacyAnalysis -> FilePath
#if defined(VALIDATION_LEGACY_PHASE_BLOCKED_SUBJECT_MUTANT)
legacyPhaseBlockedSubject _ = "<mutated>"
#else
legacyPhaseBlockedSubject analysis = "phase-" <> Text.unpack (legacySafePhase analysis)
#endif

legacyPhaseBlockedDetail :: Text
#if defined(VALIDATION_LEGACY_PHASE_BLOCKED_DETAIL_MUTANT)
legacyPhaseBlockedDetail = "mutated"
#else
legacyPhaseBlockedDetail = "every later phase requires its predecessor's external human approval"
#endif

legacyLaterPhaseBlocked :: Bool
#if defined(VALIDATION_LEGACY_RAW_LATER_PHASE_BLOCK_BYPASS_MUTANT)
legacyLaterPhaseBlocked = False
#else
legacyLaterPhaseBlocked = True
#endif

legacyBindingExecutionFinding :: LegacyAnalysis -> CanonicalLegacyBinding -> Finding
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_FINDING_COMPOSITION_MUTANT)
legacyBindingExecutionFinding analysis binding =
  finding
    (legacyBindingExecutionDetail binding <> legacyCommitmentDetail analysis)
    (legacyBindingExecutionSubject binding)
    legacyBindingExecutionCode
#else
legacyBindingExecutionFinding analysis binding =
  finding
    legacyBindingExecutionCode
    (legacyBindingExecutionSubject binding)
    (legacyBindingExecutionDetail binding <> legacyCommitmentDetail analysis)
#endif

legacyBindingExecutionCode :: Text
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_CODE_MUTANT)
legacyBindingExecutionCode = "LEGACY-MUTATED"
#else
legacyBindingExecutionCode = "LEGACY-BINDING-EXECUTION-UNAVAILABLE"
#endif

legacyBindingExecutionSubject :: CanonicalLegacyBinding -> FilePath
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_SUBJECT_MUTANT)
legacyBindingExecutionSubject _ = "<mutated>"
#else
legacyBindingExecutionSubject = Text.unpack . canonicalBindingId
#endif

legacyBindingExecutionDetail :: CanonicalLegacyBinding -> Text
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_DETAIL_ORDER_MUTANT)
legacyBindingExecutionDetail binding =
  legacyBindingExecutionPrefix
    <> legacyBindingExecutionAnalyzer binding
    <> legacyBindingExecutionAnalyzerLabel
    <> legacyBindingExecutionOwner binding
    <> legacyBindingExecutionObservationLabel
    <> legacyBindingExecutionObservation binding
    <> legacyBindingExecutionClosureLabel
    <> legacyBindingExecutionClosure binding
#else
legacyBindingExecutionDetail binding =
  legacyBindingExecutionPrefix
    <> legacyBindingExecutionOwner binding
    <> legacyBindingExecutionAnalyzerLabel
    <> legacyBindingExecutionAnalyzer binding
    <> legacyBindingExecutionObservationLabel
    <> legacyBindingExecutionObservation binding
    <> legacyBindingExecutionClosureLabel
    <> legacyBindingExecutionClosure binding
#endif

legacyBindingExecutionPrefix :: Text
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_PREFIX_MUTANT)
legacyBindingExecutionPrefix = "mutated owner="
#else
legacyBindingExecutionPrefix = "the package-hidden analyzer has not produced snapshot-bound evidence for owner="
#endif

legacyBindingExecutionOwner :: CanonicalLegacyBinding -> Text
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_OWNER_MUTANT)
legacyBindingExecutionOwner _ = "mutated"
#else
legacyBindingExecutionOwner = canonicalBindingOwner
#endif

legacyBindingExecutionAnalyzerLabel :: Text
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_ANALYZER_LABEL_MUTANT)
legacyBindingExecutionAnalyzerLabel = "; mutated="
#else
legacyBindingExecutionAnalyzerLabel = "; analyzer="
#endif

legacyBindingExecutionAnalyzer :: CanonicalLegacyBinding -> Text
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_ANALYZER_MUTANT)
legacyBindingExecutionAnalyzer _ = "mutated"
#else
legacyBindingExecutionAnalyzer = canonicalBindingAnalyzer
#endif

legacyBindingExecutionObservationLabel :: Text
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_OBSERVATION_LABEL_MUTANT)
legacyBindingExecutionObservationLabel = "; mutated="
#else
legacyBindingExecutionObservationLabel = "; observation="
#endif

legacyBindingExecutionObservation :: CanonicalLegacyBinding -> Text
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_OBSERVATION_MUTANT)
legacyBindingExecutionObservation _ = "mutated"
#else
legacyBindingExecutionObservation = canonicalBindingObservation
#endif

legacyBindingExecutionClosureLabel :: Text
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_CLOSURE_LABEL_MUTANT)
legacyBindingExecutionClosureLabel = "; mutated="
#else
legacyBindingExecutionClosureLabel = "; closure="
#endif

legacyBindingExecutionClosure :: CanonicalLegacyBinding -> Text
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_CLOSURE_MUTANT)
legacyBindingExecutionClosure _ = "mutated"
#else
legacyBindingExecutionClosure = canonicalBindingClosure
#endif

legacyJoinExecutionFinding :: LegacyAnalysis -> CanonicalLegacyJoin -> Finding
#if defined(VALIDATION_LEGACY_JOIN_EXECUTION_FINDING_COMPOSITION_MUTANT)
legacyJoinExecutionFinding analysis item =
  finding
    (legacyJoinExecutionDetail item <> legacyCommitmentDetail analysis)
    (legacyJoinExecutionSubject item)
    legacyJoinExecutionCode
#else
legacyJoinExecutionFinding analysis item =
  finding
    legacyJoinExecutionCode
    (legacyJoinExecutionSubject item)
    (legacyJoinExecutionDetail item <> legacyCommitmentDetail analysis)
#endif

legacyJoinExecutionCode :: Text
#if defined(VALIDATION_LEGACY_JOIN_EXECUTION_CODE_MUTANT)
legacyJoinExecutionCode = "LEGACY-MUTATED"
#else
legacyJoinExecutionCode = "LEGACY-SOURCE-JOIN-UNAVAILABLE"
#endif

legacyJoinExecutionSubject :: CanonicalLegacyJoin -> FilePath
#if defined(VALIDATION_LEGACY_JOIN_EXECUTION_SUBJECT_MUTANT)
legacyJoinExecutionSubject _ = "<mutated>"
#else
legacyJoinExecutionSubject = Text.unpack . canonicalJoinSource
#endif

legacyJoinExecutionDetail :: CanonicalLegacyJoin -> Text
#if defined(VALIDATION_LEGACY_JOIN_EXECUTION_DETAIL_ORDER_MUTANT)
legacyJoinExecutionDetail item =
  legacyJoinExecutionSuffix
    <> legacyJoinExecutionTarget item
    <> legacyJoinExecutionPrefix
#else
legacyJoinExecutionDetail item =
  legacyJoinExecutionPrefix
    <> legacyJoinExecutionTarget item
    <> legacyJoinExecutionSuffix
#endif

legacyJoinExecutionPrefix :: Text
#if defined(VALIDATION_LEGACY_JOIN_EXECUTION_PREFIX_MUTANT)
legacyJoinExecutionPrefix = "mutated "
#else
legacyJoinExecutionPrefix = "the package-hidden source-debt evidence join to "
#endif

legacyJoinExecutionTarget :: CanonicalLegacyJoin -> Text
#if defined(VALIDATION_LEGACY_JOIN_EXECUTION_TARGET_MUTANT)
legacyJoinExecutionTarget _ = "mutated"
#else
legacyJoinExecutionTarget = canonicalJoinTarget
#endif

legacyJoinExecutionSuffix :: Text
#if defined(VALIDATION_LEGACY_JOIN_EXECUTION_SUFFIX_MUTANT)
legacyJoinExecutionSuffix = " mutated"
#else
legacyJoinExecutionSuffix = " has not executed"
#endif

legacyRawProblemFinding :: LegacyAnalysis -> LegacyRawProblem -> Finding
legacyRawProblemFinding analysis problem = case problem of
  LegacyPhaseByteLimit maximumValue actual -> resource LegacyFindingPhaseByte "<candidate-phase>" maximumValue actual
  LegacyBindingLimit maximumValue actual -> resource LegacyFindingBindingLimit "<bindings>" maximumValue actual
  LegacyJoinLimit maximumValue actual -> resource LegacyFindingJoinLimit "<joins>" maximumValue actual
  LegacyIdByteLimit ordinal maximumValue actual -> resource LegacyFindingIdByte (bindingSubject ordinal) maximumValue actual
  LegacyDispositionByteLimit ordinal maximumValue actual -> resource LegacyFindingDispositionByte (bindingSubject ordinal) maximumValue actual
  LegacyOwnerByteLimit ordinal maximumValue actual -> resource LegacyFindingOwnerByte (bindingSubject ordinal) maximumValue actual
  LegacyAnalyzerByteLimit ordinal maximumValue actual -> resource LegacyFindingAnalyzerByte (bindingSubject ordinal) maximumValue actual
  LegacyObservationByteLimit ordinal maximumValue actual -> resource LegacyFindingObservationByte (bindingSubject ordinal) maximumValue actual
  LegacyClosureByteLimit ordinal maximumValue actual -> resource LegacyFindingClosureByte (bindingSubject ordinal) maximumValue actual
  LegacyReintroductionCountLimit ordinal maximumValue actual -> resource LegacyFindingReintroductionCount (bindingSubject ordinal) maximumValue actual
  LegacyReintroductionByteLimit ordinal reintroductionOrdinal maximumValue actual ->
    resource LegacyFindingReintroductionByte (bindingSubject ordinal <> "-reintroduction-" <> show reintroductionOrdinal) maximumValue actual
  LegacyJoinSourceByteLimit ordinal maximumValue actual -> resource LegacyFindingJoinSourceByte (joinSubject ordinal) maximumValue actual
  LegacyJoinTargetByteLimit ordinal maximumValue actual -> resource LegacyFindingJoinTargetByte (joinSubject ordinal) maximumValue actual
  LegacyAggregateByteLimit maximumValue actual -> resource LegacyFindingAggregateByte "<legacy-input>" maximumValue actual
  LegacyResourceGuardUnavailable label ->
    finding "LEGACY-RESOURCE-GUARD-UNAVAILABLE" "<legacy-input>"
      ("the changed subject suppressed the bound-specific predicate; the outer preflight envelope still refused before traversal; guard=" <> label <> legacyCommitmentDetail analysis)
  LegacyPhaseWidth -> grammar LegacyFindingPhaseWidth "<candidate-phase>" "expected exactly two ASCII decimal characters"
  LegacyPhaseAlphabet -> grammar LegacyFindingPhaseAlphabet "<candidate-phase>" "expected ASCII decimal characters only"
  LegacyPhaseRange -> grammar LegacyFindingPhaseRange "<candidate-phase>" "expected a phase in the closed range 00 through 95"
  LegacyBindingCardinality expected actual -> grammar LegacyFindingBindingCardinality "<bindings>"
    ("expected=" <> Text.pack (show expected) <> "; observed=" <> Text.pack (show actual))
  LegacyBindingDuplicate identifier -> grammar LegacyFindingBindingDuplicate (Text.unpack identifier) "stable ID occurs more than once"
  LegacyBindingUnknown identifier -> grammar LegacyFindingBindingUnknown (Text.unpack identifier) "stable ID is outside the closed binding universe"
  LegacyBindingOrder identifiers -> grammar LegacyFindingBindingOrder "<bindings>" ("observed=" <> Text.pack (show identifiers))
  LegacyBindingFieldMismatch ordinal field expected actual ->
    grammar LegacyFindingBindingField (bindingSubject ordinal)
      ("field=" <> field <> "; expected=" <> expected <> "; observed=" <> actual)
  LegacyJoinCardinality expected actual -> grammar LegacyFindingJoinCardinality "<joins>"
    ("expected=" <> Text.pack (show expected) <> "; observed=" <> Text.pack (show actual))
  LegacyJoinDuplicate source -> grammar LegacyFindingJoinDuplicate (Text.unpack source) "source family occurs more than once"
  LegacyJoinUnknown source -> grammar LegacyFindingJoinUnknown (Text.unpack source) "source family is outside the closed source-debt universe"
  LegacyJoinOrder sources -> grammar LegacyFindingJoinOrder "<joins>" ("observed=" <> Text.pack (show sources))
  LegacyJoinTargetMismatch ordinal source expected actual ->
    grammar LegacyFindingJoinTarget (joinSubject ordinal)
      ("source=" <> source <> "; expected=" <> expected <> "; observed=" <> actual)
 where
  resource kind subject maximumValue actual =
    render kind subject
      ( legacyResourceMaximumLabel <> Text.pack (show maximumValue)
          <> legacyResourceObservedLabel <> Text.pack (show actual)
      )
  grammar = render
#if defined(VALIDATION_LEGACY_RAW_PROBLEM_FINDING_COMPOSITION_MUTANT)
  render kind subject detail =
    finding
      (legacyProblemDetail kind detail <> legacyCommitmentDetail analysis)
      (legacyProblemSubject kind subject)
      (legacyProblemCode kind)
#else
  render kind subject detail =
    finding
      (legacyProblemCode kind)
      (legacyProblemSubject kind subject)
      (legacyProblemDetail kind detail <> legacyCommitmentDetail analysis)
#endif

legacyResourceMaximumLabel :: Text
#if defined(VALIDATION_LEGACY_RESOURCE_MAXIMUM_LABEL_MUTANT)
legacyResourceMaximumLabel = "mutated="
#else
legacyResourceMaximumLabel = "maximum="
#endif

legacyResourceObservedLabel :: Text
#if defined(VALIDATION_LEGACY_RESOURCE_OBSERVED_LABEL_MUTANT)
legacyResourceObservedLabel = "; mutated="
#else
legacyResourceObservedLabel = "; observed-at-least="
#endif

data LegacyProblemKind
  = LegacyFindingPhaseByte
  | LegacyFindingBindingLimit
  | LegacyFindingJoinLimit
  | LegacyFindingIdByte
  | LegacyFindingDispositionByte
  | LegacyFindingOwnerByte
  | LegacyFindingAnalyzerByte
  | LegacyFindingObservationByte
  | LegacyFindingClosureByte
  | LegacyFindingReintroductionCount
  | LegacyFindingReintroductionByte
  | LegacyFindingJoinSourceByte
  | LegacyFindingJoinTargetByte
  | LegacyFindingAggregateByte
  | LegacyFindingPhaseWidth
  | LegacyFindingPhaseAlphabet
  | LegacyFindingPhaseRange
  | LegacyFindingBindingCardinality
  | LegacyFindingBindingDuplicate
  | LegacyFindingBindingUnknown
  | LegacyFindingBindingOrder
  | LegacyFindingBindingField
  | LegacyFindingJoinCardinality
  | LegacyFindingJoinDuplicate
  | LegacyFindingJoinUnknown
  | LegacyFindingJoinOrder
  | LegacyFindingJoinTarget
  deriving (Eq, Show)

legacyProblemCode :: LegacyProblemKind -> Text
legacyProblemCode kind = case kind of
  LegacyFindingPhaseByte ->
#if defined(VALIDATION_LEGACY_PROBLEM_PHASE_BYTE_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-PHASE-BYTE-LIMIT"
#endif
  LegacyFindingBindingLimit ->
#if defined(VALIDATION_LEGACY_PROBLEM_BINDING_LIMIT_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-BINDING-LIMIT"
#endif
  LegacyFindingJoinLimit ->
#if defined(VALIDATION_LEGACY_PROBLEM_JOIN_LIMIT_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-JOIN-LIMIT"
#endif
  LegacyFindingIdByte ->
#if defined(VALIDATION_LEGACY_PROBLEM_ID_BYTE_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-ID-BYTE-LIMIT"
#endif
  LegacyFindingDispositionByte ->
#if defined(VALIDATION_LEGACY_PROBLEM_DISPOSITION_BYTE_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-DISPOSITION-BYTE-LIMIT"
#endif
  LegacyFindingOwnerByte ->
#if defined(VALIDATION_LEGACY_PROBLEM_OWNER_BYTE_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-OWNER-BYTE-LIMIT"
#endif
  LegacyFindingAnalyzerByte ->
#if defined(VALIDATION_LEGACY_PROBLEM_ANALYZER_BYTE_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-ANALYZER-BYTE-LIMIT"
#endif
  LegacyFindingObservationByte ->
#if defined(VALIDATION_LEGACY_PROBLEM_OBSERVATION_BYTE_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-OBSERVATION-BYTE-LIMIT"
#endif
  LegacyFindingClosureByte ->
#if defined(VALIDATION_LEGACY_PROBLEM_CLOSURE_BYTE_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-CLOSURE-BYTE-LIMIT"
#endif
  LegacyFindingReintroductionCount ->
#if defined(VALIDATION_LEGACY_PROBLEM_REINTRODUCTION_COUNT_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-REINTRODUCTION-COUNT-LIMIT"
#endif
  LegacyFindingReintroductionByte ->
#if defined(VALIDATION_LEGACY_PROBLEM_REINTRODUCTION_BYTE_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-REINTRODUCTION-BYTE-LIMIT"
#endif
  LegacyFindingJoinSourceByte ->
#if defined(VALIDATION_LEGACY_PROBLEM_JOIN_SOURCE_BYTE_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-JOIN-SOURCE-BYTE-LIMIT"
#endif
  LegacyFindingJoinTargetByte ->
#if defined(VALIDATION_LEGACY_PROBLEM_JOIN_TARGET_BYTE_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-JOIN-TARGET-BYTE-LIMIT"
#endif
  LegacyFindingAggregateByte ->
#if defined(VALIDATION_LEGACY_PROBLEM_AGGREGATE_BYTE_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-AGGREGATE-BYTE-LIMIT"
#endif
  LegacyFindingPhaseWidth ->
#if defined(VALIDATION_LEGACY_PROBLEM_PHASE_WIDTH_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-PHASE-WIDTH"
#endif
  LegacyFindingPhaseAlphabet ->
#if defined(VALIDATION_LEGACY_PROBLEM_PHASE_ALPHABET_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-PHASE-ALPHABET"
#endif
  LegacyFindingPhaseRange ->
#if defined(VALIDATION_LEGACY_PROBLEM_PHASE_RANGE_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-PHASE-RANGE"
#endif
  LegacyFindingBindingCardinality ->
#if defined(VALIDATION_LEGACY_PROBLEM_BINDING_CARDINALITY_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-BINDING-CARDINALITY"
#endif
  LegacyFindingBindingDuplicate ->
#if defined(VALIDATION_LEGACY_PROBLEM_BINDING_DUPLICATE_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-BINDING-DUPLICATE"
#endif
  LegacyFindingBindingUnknown ->
#if defined(VALIDATION_LEGACY_PROBLEM_BINDING_UNKNOWN_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-BINDING-UNKNOWN"
#endif
  LegacyFindingBindingOrder ->
#if defined(VALIDATION_LEGACY_PROBLEM_BINDING_ORDER_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-BINDING-ORDER"
#endif
  LegacyFindingBindingField ->
#if defined(VALIDATION_LEGACY_PROBLEM_BINDING_FIELD_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-BINDING-FIELD"
#endif
  LegacyFindingJoinCardinality ->
#if defined(VALIDATION_LEGACY_PROBLEM_JOIN_CARDINALITY_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-JOIN-CARDINALITY"
#endif
  LegacyFindingJoinDuplicate ->
#if defined(VALIDATION_LEGACY_PROBLEM_JOIN_DUPLICATE_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-JOIN-DUPLICATE"
#endif
  LegacyFindingJoinUnknown ->
#if defined(VALIDATION_LEGACY_PROBLEM_JOIN_UNKNOWN_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-JOIN-UNKNOWN"
#endif
  LegacyFindingJoinOrder ->
#if defined(VALIDATION_LEGACY_PROBLEM_JOIN_ORDER_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-JOIN-ORDER"
#endif
  LegacyFindingJoinTarget ->
#if defined(VALIDATION_LEGACY_PROBLEM_JOIN_TARGET_CODE_MUTANT)
    "LEGACY-MUTATED"
#else
    "LEGACY-JOIN-TARGET"
#endif

legacyProblemSubject :: LegacyProblemKind -> FilePath -> FilePath
legacyProblemSubject kind subject = case kind of
  LegacyFindingPhaseByte ->
#if defined(VALIDATION_LEGACY_PROBLEM_PHASE_BYTE_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  LegacyFindingBindingLimit ->
#if defined(VALIDATION_LEGACY_PROBLEM_BINDING_LIMIT_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  LegacyFindingJoinLimit ->
#if defined(VALIDATION_LEGACY_PROBLEM_JOIN_LIMIT_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  LegacyFindingIdByte ->
#if defined(VALIDATION_LEGACY_PROBLEM_ID_BYTE_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  LegacyFindingDispositionByte ->
#if defined(VALIDATION_LEGACY_PROBLEM_DISPOSITION_BYTE_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  LegacyFindingOwnerByte ->
#if defined(VALIDATION_LEGACY_PROBLEM_OWNER_BYTE_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  LegacyFindingAnalyzerByte ->
#if defined(VALIDATION_LEGACY_PROBLEM_ANALYZER_BYTE_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  LegacyFindingObservationByte ->
#if defined(VALIDATION_LEGACY_PROBLEM_OBSERVATION_BYTE_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  LegacyFindingClosureByte ->
#if defined(VALIDATION_LEGACY_PROBLEM_CLOSURE_BYTE_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  LegacyFindingReintroductionCount ->
#if defined(VALIDATION_LEGACY_PROBLEM_REINTRODUCTION_COUNT_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  LegacyFindingReintroductionByte ->
#if defined(VALIDATION_LEGACY_PROBLEM_REINTRODUCTION_BYTE_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  LegacyFindingJoinSourceByte ->
#if defined(VALIDATION_LEGACY_PROBLEM_JOIN_SOURCE_BYTE_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  LegacyFindingJoinTargetByte ->
#if defined(VALIDATION_LEGACY_PROBLEM_JOIN_TARGET_BYTE_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  LegacyFindingAggregateByte ->
#if defined(VALIDATION_LEGACY_PROBLEM_AGGREGATE_BYTE_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  LegacyFindingPhaseWidth ->
#if defined(VALIDATION_LEGACY_PROBLEM_PHASE_WIDTH_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  LegacyFindingPhaseAlphabet ->
#if defined(VALIDATION_LEGACY_PROBLEM_PHASE_ALPHABET_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  LegacyFindingPhaseRange ->
#if defined(VALIDATION_LEGACY_PROBLEM_PHASE_RANGE_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  LegacyFindingBindingCardinality ->
#if defined(VALIDATION_LEGACY_PROBLEM_BINDING_CARDINALITY_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  LegacyFindingBindingDuplicate ->
#if defined(VALIDATION_LEGACY_PROBLEM_BINDING_DUPLICATE_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  LegacyFindingBindingUnknown ->
#if defined(VALIDATION_LEGACY_PROBLEM_BINDING_UNKNOWN_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  LegacyFindingBindingOrder ->
#if defined(VALIDATION_LEGACY_PROBLEM_BINDING_ORDER_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  LegacyFindingBindingField ->
#if defined(VALIDATION_LEGACY_PROBLEM_BINDING_FIELD_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  LegacyFindingJoinCardinality ->
#if defined(VALIDATION_LEGACY_PROBLEM_JOIN_CARDINALITY_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  LegacyFindingJoinDuplicate ->
#if defined(VALIDATION_LEGACY_PROBLEM_JOIN_DUPLICATE_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  LegacyFindingJoinUnknown ->
#if defined(VALIDATION_LEGACY_PROBLEM_JOIN_UNKNOWN_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  LegacyFindingJoinOrder ->
#if defined(VALIDATION_LEGACY_PROBLEM_JOIN_ORDER_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif
  LegacyFindingJoinTarget ->
#if defined(VALIDATION_LEGACY_PROBLEM_JOIN_TARGET_SUBJECT_MUTANT)
    "<mutated>"
#else
    subject
#endif

legacyProblemDetail :: LegacyProblemKind -> Text -> Text
legacyProblemDetail kind detail = case kind of
  LegacyFindingPhaseByte ->
#if defined(VALIDATION_LEGACY_PROBLEM_PHASE_BYTE_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  LegacyFindingBindingLimit ->
#if defined(VALIDATION_LEGACY_PROBLEM_BINDING_LIMIT_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  LegacyFindingJoinLimit ->
#if defined(VALIDATION_LEGACY_PROBLEM_JOIN_LIMIT_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  LegacyFindingIdByte ->
#if defined(VALIDATION_LEGACY_PROBLEM_ID_BYTE_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  LegacyFindingDispositionByte ->
#if defined(VALIDATION_LEGACY_PROBLEM_DISPOSITION_BYTE_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  LegacyFindingOwnerByte ->
#if defined(VALIDATION_LEGACY_PROBLEM_OWNER_BYTE_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  LegacyFindingAnalyzerByte ->
#if defined(VALIDATION_LEGACY_PROBLEM_ANALYZER_BYTE_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  LegacyFindingObservationByte ->
#if defined(VALIDATION_LEGACY_PROBLEM_OBSERVATION_BYTE_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  LegacyFindingClosureByte ->
#if defined(VALIDATION_LEGACY_PROBLEM_CLOSURE_BYTE_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  LegacyFindingReintroductionCount ->
#if defined(VALIDATION_LEGACY_PROBLEM_REINTRODUCTION_COUNT_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  LegacyFindingReintroductionByte ->
#if defined(VALIDATION_LEGACY_PROBLEM_REINTRODUCTION_BYTE_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  LegacyFindingJoinSourceByte ->
#if defined(VALIDATION_LEGACY_PROBLEM_JOIN_SOURCE_BYTE_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  LegacyFindingJoinTargetByte ->
#if defined(VALIDATION_LEGACY_PROBLEM_JOIN_TARGET_BYTE_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  LegacyFindingAggregateByte ->
#if defined(VALIDATION_LEGACY_PROBLEM_AGGREGATE_BYTE_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  LegacyFindingPhaseWidth ->
#if defined(VALIDATION_LEGACY_PROBLEM_PHASE_WIDTH_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  LegacyFindingPhaseAlphabet ->
#if defined(VALIDATION_LEGACY_PROBLEM_PHASE_ALPHABET_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  LegacyFindingPhaseRange ->
#if defined(VALIDATION_LEGACY_PROBLEM_PHASE_RANGE_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  LegacyFindingBindingCardinality ->
#if defined(VALIDATION_LEGACY_PROBLEM_BINDING_CARDINALITY_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  LegacyFindingBindingDuplicate ->
#if defined(VALIDATION_LEGACY_PROBLEM_BINDING_DUPLICATE_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  LegacyFindingBindingUnknown ->
#if defined(VALIDATION_LEGACY_PROBLEM_BINDING_UNKNOWN_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  LegacyFindingBindingOrder ->
#if defined(VALIDATION_LEGACY_PROBLEM_BINDING_ORDER_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  LegacyFindingBindingField ->
#if defined(VALIDATION_LEGACY_PROBLEM_BINDING_FIELD_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  LegacyFindingJoinCardinality ->
#if defined(VALIDATION_LEGACY_PROBLEM_JOIN_CARDINALITY_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  LegacyFindingJoinDuplicate ->
#if defined(VALIDATION_LEGACY_PROBLEM_JOIN_DUPLICATE_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  LegacyFindingJoinUnknown ->
#if defined(VALIDATION_LEGACY_PROBLEM_JOIN_UNKNOWN_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  LegacyFindingJoinOrder ->
#if defined(VALIDATION_LEGACY_PROBLEM_JOIN_ORDER_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif
  LegacyFindingJoinTarget ->
#if defined(VALIDATION_LEGACY_PROBLEM_JOIN_TARGET_DETAIL_MUTANT)
    detail <> "-mutated"
#else
    detail
#endif

bindingSubject :: Int -> FilePath
#if defined(VALIDATION_LEGACY_BINDING_SUBJECT_COMPOSITION_MUTANT)
bindingSubject ordinal = legacySubjectSuffix <> show ordinal <> legacyBindingSubjectPrefix
#else
bindingSubject ordinal = legacyBindingSubjectPrefix <> show ordinal <> legacySubjectSuffix
#endif

joinSubject :: Int -> FilePath
#if defined(VALIDATION_LEGACY_JOIN_SUBJECT_COMPOSITION_MUTANT)
joinSubject ordinal = legacySubjectSuffix <> show ordinal <> legacyJoinSubjectPrefix
#else
joinSubject ordinal = legacyJoinSubjectPrefix <> show ordinal <> legacySubjectSuffix
#endif

legacyBindingSubjectPrefix :: FilePath
#if defined(VALIDATION_LEGACY_BINDING_SUBJECT_PREFIX_MUTANT)
legacyBindingSubjectPrefix = "<mutated-"
#else
legacyBindingSubjectPrefix = "<binding-"
#endif

legacyJoinSubjectPrefix :: FilePath
#if defined(VALIDATION_LEGACY_JOIN_SUBJECT_PREFIX_MUTANT)
legacyJoinSubjectPrefix = "<mutated-"
#else
legacyJoinSubjectPrefix = "<join-"
#endif

legacySubjectSuffix :: FilePath
#if defined(VALIDATION_LEGACY_SUBJECT_SUFFIX_MUTANT)
legacySubjectSuffix = "]"
#else
legacySubjectSuffix = ">"
#endif

legacyCommitmentDetail :: LegacyAnalysis -> Text
#if defined(VALIDATION_LEGACY_COMMITMENT_DETAIL_ORDER_MUTANT)
legacyCommitmentDetail analysis =
  legacyCommitmentDigestLabel analysis <> legacyCommitmentDigestDetail analysis
    <> legacyCommitmentKindLabel <> legacyCommitmentKindDetail analysis
#else
legacyCommitmentDetail analysis =
  legacyCommitmentKindLabel <> legacyCommitmentKindDetail analysis
    <> legacyCommitmentDigestLabel analysis <> legacyCommitmentDigestDetail analysis
#endif

legacyCommitmentKindLabel :: Text
#if defined(VALIDATION_LEGACY_COMMITMENT_KIND_LABEL_MUTANT)
legacyCommitmentKindLabel = "; mutated="
#else
legacyCommitmentKindLabel = "; input-commitment-kind="
#endif

legacyCommitmentKindDetail :: LegacyAnalysis -> Text
#if defined(VALIDATION_LEGACY_COMMITMENT_KIND_VALUE_MUTANT)
legacyCommitmentKindDetail _ = "mutated"
#else
legacyCommitmentKindDetail = legacyCommitmentKind
#endif

legacyCommitmentDigestLabel :: LegacyAnalysis -> Text
#if defined(VALIDATION_LEGACY_COMMITMENT_DIGEST_LABEL_ROUTE_MUTANT)
legacyCommitmentDigestLabel analysis
  | legacyCommitmentKind analysis == "complete-input" = legacyBoundedCommitmentDigestLabel
  | otherwise = legacyCompleteCommitmentDigestLabel
#else
legacyCommitmentDigestLabel analysis
  | legacyCommitmentKind analysis == "complete-input" = legacyCompleteCommitmentDigestLabel
  | otherwise = legacyBoundedCommitmentDigestLabel
#endif

legacyCompleteCommitmentDigestLabel :: Text
#if defined(VALIDATION_LEGACY_COMMITMENT_DIGEST_LABEL_MUTANT)
legacyCompleteCommitmentDigestLabel = "; mutated="
#else
legacyCompleteCommitmentDigestLabel = "; input-sha256="
#endif

legacyBoundedCommitmentDigestLabel :: Text
#if defined(VALIDATION_LEGACY_BOUNDED_COMMITMENT_DIGEST_LABEL_MUTANT)
legacyBoundedCommitmentDigestLabel = "; mutated="
#else
legacyBoundedCommitmentDigestLabel = "; bounded-prefix-sha256="
#endif

legacyCommitmentDigestDetail :: LegacyAnalysis -> Text
#if defined(VALIDATION_LEGACY_COMMITMENT_DIGEST_VALUE_MUTANT)
legacyCommitmentDigestDetail _ = "mutated"
#else
legacyCommitmentDigestDetail = legacyCommitmentDigest
#endif

legacyAggregateBytes :: [RawLegacyBinding] -> [RawLegacyJoin] -> Int
legacyAggregateBytes bindings joins =
  sum
    [ legacyAggregateBindingId identifier
        + legacyAggregateBindingDisposition disposition
        + legacyAggregateBindingOwner owner
        + legacyAggregateBindingAnalyzer analyzer
        + legacyAggregateBindingObservation observed
        + legacyAggregateBindingClosure closed
        + legacyAggregateBindingReintroduction reintroduced
    | (identifier, disposition, owner, analyzer, observed, closed, reintroduced) <- bindings
    ]
    + sum [legacyAggregateJoinSource source + legacyAggregateJoinTarget target | (source, target) <- joins]

legacyAggregateBindingId, legacyAggregateBindingDisposition, legacyAggregateBindingOwner :: Text -> Int
#if defined(VALIDATION_LEGACY_AGGREGATE_BINDING_ID_DROP_MUTANT)
legacyAggregateBindingId _ = 0
#else
legacyAggregateBindingId = legacyTextBytes
#endif
#if defined(VALIDATION_LEGACY_AGGREGATE_BINDING_DISPOSITION_DROP_MUTANT)
legacyAggregateBindingDisposition _ = 0
#else
legacyAggregateBindingDisposition = legacyTextBytes
#endif
#if defined(VALIDATION_LEGACY_AGGREGATE_BINDING_OWNER_DROP_MUTANT)
legacyAggregateBindingOwner _ = 0
#else
legacyAggregateBindingOwner = legacyTextBytes
#endif

legacyAggregateBindingAnalyzer, legacyAggregateBindingObservation, legacyAggregateBindingClosure :: Text -> Int
#if defined(VALIDATION_LEGACY_AGGREGATE_BINDING_ANALYZER_DROP_MUTANT)
legacyAggregateBindingAnalyzer _ = 0
#else
legacyAggregateBindingAnalyzer = legacyTextBytes
#endif
#if defined(VALIDATION_LEGACY_AGGREGATE_BINDING_OBSERVATION_DROP_MUTANT)
legacyAggregateBindingObservation _ = 0
#else
legacyAggregateBindingObservation = legacyTextBytes
#endif
#if defined(VALIDATION_LEGACY_AGGREGATE_BINDING_CLOSURE_DROP_MUTANT)
legacyAggregateBindingClosure _ = 0
#else
legacyAggregateBindingClosure = legacyTextBytes
#endif

legacyAggregateBindingReintroduction :: [Text] -> Int
#if defined(VALIDATION_LEGACY_AGGREGATE_BINDING_REINTRODUCTION_DROP_MUTANT)
legacyAggregateBindingReintroduction _ = 0
#else
legacyAggregateBindingReintroduction = sum . map legacyTextBytes
#endif

legacyAggregateJoinSource, legacyAggregateJoinTarget :: Text -> Int
#if defined(VALIDATION_LEGACY_AGGREGATE_JOIN_SOURCE_DROP_MUTANT)
legacyAggregateJoinSource _ = 0
#else
legacyAggregateJoinSource = legacyTextBytes
#endif
#if defined(VALIDATION_LEGACY_AGGREGATE_JOIN_TARGET_DROP_MUTANT)
legacyAggregateJoinTarget _ = 0
#else
legacyAggregateJoinTarget = legacyTextBytes
#endif

legacyCompleteDigest :: Text -> [RawLegacyBinding] -> [RawLegacyJoin] -> Text
legacyCompleteDigest phase bindings joins =
  legacySha256
    (ByteString.concat (legacyCompleteDigestComponents phase bindings joins))

legacyCompleteDigestComponents :: Text -> [RawLegacyBinding] -> [RawLegacyJoin] -> [ByteString]
#if defined(VALIDATION_LEGACY_COMPLETE_DIGEST_COMPONENT_ORDER_MUTANT)
legacyCompleteDigestComponents phase bindings joins =
  legacyDigestDomain
    <> legacyDigestPhase phase
    <> legacyDigestJoinCount joins
    <> concatMap legacyDigestBinding (legacyDigestBindingOrder bindings)
    <> legacyDigestBindingCount bindings
    <> concatMap legacyDigestJoin (legacyDigestJoinOrder joins)
#else
legacyCompleteDigestComponents phase bindings joins =
  legacyDigestDomain
    <> legacyDigestPhase phase
    <> legacyDigestBindingCount bindings
    <> concatMap legacyDigestBinding (legacyDigestBindingOrder bindings)
    <> legacyDigestJoinCount joins
    <> concatMap legacyDigestJoin (legacyDigestJoinOrder joins)
#endif

legacyDigestDomain :: [ByteString]
#if defined(VALIDATION_LEGACY_DIGEST_DOMAIN_MUTANT)
legacyDigestDomain = ["amoebius-legacy-input-v0\0"]
#else
legacyDigestDomain = ["amoebius-legacy-input-v1\0"]
#endif

legacyDigestPhase :: Text -> [ByteString]
#if defined(VALIDATION_LEGACY_DIGEST_PHASE_DROP_MUTANT)
legacyDigestPhase _ = []
#else
legacyDigestPhase value = [legacyLengthText value]
#endif

legacyDigestBindingCount :: [RawLegacyBinding] -> [ByteString]
#if defined(VALIDATION_LEGACY_DIGEST_BINDING_COUNT_DROP_MUTANT)
legacyDigestBindingCount _ = []
#else
legacyDigestBindingCount values = [legacyLengthText (Text.pack (show (length values)))]
#endif

legacyDigestBindingOrder :: [RawLegacyBinding] -> [RawLegacyBinding]
#if defined(VALIDATION_LEGACY_DIGEST_BINDING_ORDER_MUTANT)
legacyDigestBindingOrder = reverse
#else
legacyDigestBindingOrder = id
#endif

legacyDigestBinding :: RawLegacyBinding -> [ByteString]
#if defined(VALIDATION_LEGACY_DIGEST_BINDING_COMPONENT_ORDER_MUTANT)
legacyDigestBinding (identifier, disposition, owner, analyzer, observed, closed, reintroduced) =
  digestBindingDisposition disposition
    <> digestBindingId identifier
    <> digestBindingOwner owner
    <> digestBindingAnalyzer analyzer
    <> digestBindingObservation observed
    <> digestBindingClosure closed
    <> digestBindingReintroduction reintroduced
#else
legacyDigestBinding (identifier, disposition, owner, analyzer, observed, closed, reintroduced) =
  digestBindingId identifier
    <> digestBindingDisposition disposition
    <> digestBindingOwner owner
    <> digestBindingAnalyzer analyzer
    <> digestBindingObservation observed
    <> digestBindingClosure closed
    <> digestBindingReintroduction reintroduced
#endif

digestBindingId :: Text -> [ByteString]
#if defined(VALIDATION_LEGACY_DIGEST_BINDING_ID_DROP_MUTANT)
digestBindingId _ = []
#else
digestBindingId value = [legacyLengthText value]
#endif

digestBindingDisposition :: Text -> [ByteString]
#if defined(VALIDATION_LEGACY_DIGEST_BINDING_DISPOSITION_DROP_MUTANT)
digestBindingDisposition _ = []
#else
digestBindingDisposition value = [legacyLengthText value]
#endif

digestBindingOwner :: Text -> [ByteString]
#if defined(VALIDATION_LEGACY_DIGEST_BINDING_OWNER_DROP_MUTANT)
digestBindingOwner _ = []
#else
digestBindingOwner value = [legacyLengthText value]
#endif

digestBindingAnalyzer :: Text -> [ByteString]
#if defined(VALIDATION_LEGACY_DIGEST_BINDING_ANALYZER_DROP_MUTANT)
digestBindingAnalyzer _ = []
#else
digestBindingAnalyzer value = [legacyLengthText value]
#endif

digestBindingObservation :: Text -> [ByteString]
#if defined(VALIDATION_LEGACY_DIGEST_BINDING_OBSERVATION_DROP_MUTANT)
digestBindingObservation _ = []
#else
digestBindingObservation value = [legacyLengthText value]
#endif

digestBindingClosure :: Text -> [ByteString]
#if defined(VALIDATION_LEGACY_DIGEST_BINDING_CLOSURE_DROP_MUTANT)
digestBindingClosure _ = []
#else
digestBindingClosure value = [legacyLengthText value]
#endif

digestBindingReintroduction :: [Text] -> [ByteString]
#if defined(VALIDATION_LEGACY_DIGEST_BINDING_REINTRODUCTION_DROP_MUTANT)
digestBindingReintroduction _ = []
#else
digestBindingReintroduction values =
  legacyLengthText (Text.pack (show (length values))) : map legacyLengthText values
#endif

legacyDigestJoinCount :: [RawLegacyJoin] -> [ByteString]
#if defined(VALIDATION_LEGACY_DIGEST_JOIN_COUNT_DROP_MUTANT)
legacyDigestJoinCount _ = []
#else
legacyDigestJoinCount values = [legacyLengthText (Text.pack (show (length values)))]
#endif

legacyDigestJoinOrder :: [RawLegacyJoin] -> [RawLegacyJoin]
#if defined(VALIDATION_LEGACY_DIGEST_JOIN_ORDER_MUTANT)
legacyDigestJoinOrder = reverse
#else
legacyDigestJoinOrder = id
#endif

legacyDigestJoin :: RawLegacyJoin -> [ByteString]
#if defined(VALIDATION_LEGACY_DIGEST_JOIN_COMPONENT_ORDER_MUTANT)
legacyDigestJoin (source, target) = digestJoinTarget target <> digestJoinSource source
#else
legacyDigestJoin (source, target) = digestJoinSource source <> digestJoinTarget target
#endif

digestJoinSource :: Text -> [ByteString]
#if defined(VALIDATION_LEGACY_DIGEST_JOIN_SOURCE_DROP_MUTANT)
digestJoinSource _ = []
#else
digestJoinSource value = [legacyLengthText value]
#endif

digestJoinTarget :: Text -> [ByteString]
#if defined(VALIDATION_LEGACY_DIGEST_JOIN_TARGET_DROP_MUTANT)
digestJoinTarget _ = []
#else
digestJoinTarget value = [legacyLengthText value]
#endif

legacyBoundedDigest :: Text -> [RawLegacyBinding] -> [RawLegacyJoin] -> LegacyRawProblem -> Text
legacyBoundedDigest phase bindings joins problem =
  legacySha256
    ( ByteString.concat
        ( legacyBoundedDigestComponents
            phase problem bindingState boundedBindings joinState boundedJoins
        )
    )
 where
  (bindingState, boundedBindings) = boundedLegacyState maximumLegacyBindings bindings
  (joinState, boundedJoins) = boundedLegacyState maximumLegacyJoins joins

legacyBoundedDigestComponents
  :: Text -> LegacyRawProblem -> Text -> [RawLegacyBinding] -> Text -> [RawLegacyJoin]
  -> [ByteString]
#if defined(VALIDATION_LEGACY_BOUNDED_DIGEST_COMPONENT_ORDER_MUTANT)
legacyBoundedDigestComponents phase problem bindingState bindings joinState joins =
  legacyBoundedDigestDomain
    <> legacyBoundedDigestPhase phase
    <> legacyBoundedDigestJoinState joinState
    <> concatMap boundedLegacyBindingCommitment (legacyBoundedDigestBindingOrder bindings)
    <> legacyBoundedDigestBindingState bindingState
    <> concatMap boundedLegacyJoinCommitment (legacyBoundedDigestJoinOrder joins)
    <> legacyBoundedDigestProblemTag problem
#else
legacyBoundedDigestComponents phase problem bindingState bindings joinState joins =
  legacyBoundedDigestDomain
    <> legacyBoundedDigestPhase phase
    <> legacyBoundedDigestBindingState bindingState
    <> concatMap boundedLegacyBindingCommitment (legacyBoundedDigestBindingOrder bindings)
    <> legacyBoundedDigestJoinState joinState
    <> concatMap boundedLegacyJoinCommitment (legacyBoundedDigestJoinOrder joins)
    <> legacyBoundedDigestProblemTag problem
#endif

legacyBoundedDigestDomain :: [ByteString]
#if defined(VALIDATION_LEGACY_BOUNDED_DIGEST_DOMAIN_MUTANT)
legacyBoundedDigestDomain = ["amoebius-legacy-bounded-refusal-v0\0"]
#else
legacyBoundedDigestDomain = ["amoebius-legacy-bounded-refusal-v1\0"]
#endif

legacyBoundedDigestPhase :: Text -> [ByteString]
#if defined(VALIDATION_LEGACY_BOUNDED_DIGEST_PHASE_DROP_MUTANT)
legacyBoundedDigestPhase _ = []
#else
legacyBoundedDigestPhase value = [boundedLegacyTextCommitment maximumLegacyPhaseBytes value]
#endif

legacyBoundedDigestBindingState :: Text -> [ByteString]
#if defined(VALIDATION_LEGACY_BOUNDED_DIGEST_BINDING_STATE_DROP_MUTANT)
legacyBoundedDigestBindingState _ = []
#else
legacyBoundedDigestBindingState value = [legacyLengthText value]
#endif

legacyBoundedDigestBindingOrder :: [RawLegacyBinding] -> [RawLegacyBinding]
#if defined(VALIDATION_LEGACY_BOUNDED_DIGEST_BINDING_ORDER_MUTANT)
legacyBoundedDigestBindingOrder = reverse
#else
legacyBoundedDigestBindingOrder = id
#endif

legacyBoundedDigestJoinState :: Text -> [ByteString]
#if defined(VALIDATION_LEGACY_BOUNDED_DIGEST_JOIN_STATE_DROP_MUTANT)
legacyBoundedDigestJoinState _ = []
#else
legacyBoundedDigestJoinState value = [legacyLengthText value]
#endif

legacyBoundedDigestJoinOrder :: [RawLegacyJoin] -> [RawLegacyJoin]
#if defined(VALIDATION_LEGACY_BOUNDED_DIGEST_JOIN_ORDER_MUTANT)
legacyBoundedDigestJoinOrder = reverse
#else
legacyBoundedDigestJoinOrder = id
#endif

legacyBoundedDigestProblemTag :: LegacyRawProblem -> [ByteString]
#if defined(VALIDATION_LEGACY_BOUNDED_DIGEST_PROBLEM_TAG_DROP_MUTANT)
legacyBoundedDigestProblemTag value =
  Text.length (legacyRawProblemTag value) `seq` []
#else
legacyBoundedDigestProblemTag value = [legacyLengthText (legacyRawProblemTag value)]
#endif

boundedLegacyState :: Int -> [value] -> (Text, [value])
boundedLegacyState limit values = case boundedLegacyPrefix limit values of
  LegacyPrefixWithin bounded -> (legacyBoundedStateWithin bounded, bounded)
  LegacyPrefixExceeded observed bounded -> (legacyBoundedStateExceeded observed, bounded)

legacyBoundedStateWithin :: [value] -> Text
#if defined(VALIDATION_LEGACY_BOUNDED_STATE_WITHIN_MUTANT)
legacyBoundedStateWithin values = "mutated:" <> Text.pack (show (length values))
#else
legacyBoundedStateWithin values = "within:" <> Text.pack (show (length values))
#endif

legacyBoundedStateExceeded :: Int -> Text
#if defined(VALIDATION_LEGACY_BOUNDED_STATE_EXCEEDED_MUTANT)
legacyBoundedStateExceeded observed = "mutated:" <> Text.pack (show observed)
#else
legacyBoundedStateExceeded observed = "exceeded-at-least:" <> Text.pack (show observed)
#endif

boundedLegacyBindingCommitment :: RawLegacyBinding -> [ByteString]
#if defined(VALIDATION_LEGACY_BOUNDED_BINDING_COMPONENT_ORDER_MUTANT)
boundedLegacyBindingCommitment (identifier, disposition, owner, analyzer, observed, closed, reintroduced) =
  boundedLegacyBindingDisposition disposition
    <> boundedLegacyBindingId identifier
    <> boundedLegacyBindingOwner owner
    <> boundedLegacyBindingAnalyzer analyzer
    <> boundedLegacyBindingObservation observed
    <> boundedLegacyBindingClosure closed
    <> boundedLegacyBindingReintroductionState reintroductionState
    <> concatMap boundedLegacyBindingReintroductionValue boundedReintroductions
 where
  (reintroductionState, boundedReintroductions) = boundedLegacyState maximumLegacyReintroductionValues reintroduced
#else
boundedLegacyBindingCommitment (identifier, disposition, owner, analyzer, observed, closed, reintroduced) =
  boundedLegacyBindingId identifier
    <> boundedLegacyBindingDisposition disposition
    <> boundedLegacyBindingOwner owner
    <> boundedLegacyBindingAnalyzer analyzer
    <> boundedLegacyBindingObservation observed
    <> boundedLegacyBindingClosure closed
    <> boundedLegacyBindingReintroductionState reintroductionState
    <> concatMap boundedLegacyBindingReintroductionValue boundedReintroductions
 where
  (reintroductionState, boundedReintroductions) = boundedLegacyState maximumLegacyReintroductionValues reintroduced
#endif

boundedLegacyBindingId, boundedLegacyBindingDisposition, boundedLegacyBindingOwner :: Text -> [ByteString]
#if defined(VALIDATION_LEGACY_BOUNDED_DIGEST_BINDING_ID_DROP_MUTANT)
boundedLegacyBindingId _ = []
#else
boundedLegacyBindingId value = [boundedLegacyTextCommitment maximumLegacyIdBytes value]
#endif
#if defined(VALIDATION_LEGACY_BOUNDED_DIGEST_BINDING_DISPOSITION_DROP_MUTANT)
boundedLegacyBindingDisposition _ = []
#else
boundedLegacyBindingDisposition value = [boundedLegacyTextCommitment maximumLegacyDispositionBytes value]
#endif
#if defined(VALIDATION_LEGACY_BOUNDED_DIGEST_BINDING_OWNER_DROP_MUTANT)
boundedLegacyBindingOwner _ = []
#else
boundedLegacyBindingOwner value = [boundedLegacyTextCommitment maximumLegacyOwnerBytes value]
#endif

boundedLegacyBindingAnalyzer, boundedLegacyBindingObservation, boundedLegacyBindingClosure :: Text -> [ByteString]
#if defined(VALIDATION_LEGACY_BOUNDED_DIGEST_BINDING_ANALYZER_DROP_MUTANT)
boundedLegacyBindingAnalyzer _ = []
#else
boundedLegacyBindingAnalyzer value = [boundedLegacyTextCommitment maximumLegacyAnalyzerBytes value]
#endif
#if defined(VALIDATION_LEGACY_BOUNDED_DIGEST_BINDING_OBSERVATION_DROP_MUTANT)
boundedLegacyBindingObservation _ = []
#else
boundedLegacyBindingObservation value = [boundedLegacyTextCommitment maximumLegacyObservationBytes value]
#endif
#if defined(VALIDATION_LEGACY_BOUNDED_DIGEST_BINDING_CLOSURE_DROP_MUTANT)
boundedLegacyBindingClosure _ = []
#else
boundedLegacyBindingClosure value = [boundedLegacyTextCommitment maximumLegacyClosureBytes value]
#endif

boundedLegacyBindingReintroductionState :: Text -> [ByteString]
#if defined(VALIDATION_LEGACY_BOUNDED_DIGEST_REINTRODUCTION_STATE_DROP_MUTANT)
boundedLegacyBindingReintroductionState _ = []
#else
boundedLegacyBindingReintroductionState value = [legacyLengthText value]
#endif

boundedLegacyBindingReintroductionValue :: Text -> [ByteString]
#if defined(VALIDATION_LEGACY_BOUNDED_DIGEST_REINTRODUCTION_VALUE_DROP_MUTANT)
boundedLegacyBindingReintroductionValue _ = []
#else
boundedLegacyBindingReintroductionValue value = [boundedLegacyTextCommitment maximumLegacyReintroductionBytes value]
#endif

boundedLegacyJoinCommitment :: RawLegacyJoin -> [ByteString]
#if defined(VALIDATION_LEGACY_BOUNDED_JOIN_COMPONENT_ORDER_MUTANT)
boundedLegacyJoinCommitment (source, target) =
  boundedLegacyJoinTarget target <> boundedLegacyJoinSource source
#else
boundedLegacyJoinCommitment (source, target) =
  boundedLegacyJoinSource source <> boundedLegacyJoinTarget target
#endif

boundedLegacyJoinSource, boundedLegacyJoinTarget :: Text -> [ByteString]
#if defined(VALIDATION_LEGACY_BOUNDED_DIGEST_JOIN_SOURCE_DROP_MUTANT)
boundedLegacyJoinSource _ = []
#else
boundedLegacyJoinSource value = [boundedLegacyTextCommitment maximumLegacyJoinSourceBytes value]
#endif
#if defined(VALIDATION_LEGACY_BOUNDED_DIGEST_JOIN_TARGET_DROP_MUTANT)
boundedLegacyJoinTarget _ = []
#else
boundedLegacyJoinTarget value = [boundedLegacyTextCommitment maximumLegacyJoinTargetBytes value]
#endif

boundedLegacyTextCommitment :: Int -> Text -> ByteString
boundedLegacyTextCommitment limit value =
  case boundedLegacyText limit value of
    LegacyPrefixWithin characters -> legacyLengthText (legacyBoundedWithinLabel <> legacyBoundedRetainedText characters)
    LegacyPrefixExceeded observed characters ->
      legacyLengthText
#if defined(VALIDATION_LEGACY_BOUNDED_TEXT_COMPONENT_ORDER_MUTANT)
        ( legacyBoundedRetainedText characters
            <> legacyBoundedExceededSeparator
            <> legacyBoundedObservedValue observed
            <> legacyBoundedExceededLabel
        )
#else
        ( legacyBoundedExceededLabel
            <> legacyBoundedObservedValue observed
            <> legacyBoundedExceededSeparator
            <> legacyBoundedRetainedText characters
        )
#endif

legacyBoundedWithinLabel :: Text
#if defined(VALIDATION_LEGACY_BOUNDED_TEXT_WITHIN_LABEL_MUTANT)
legacyBoundedWithinLabel = "mutated:"
#else
legacyBoundedWithinLabel = "within:"
#endif

legacyBoundedExceededLabel :: Text
#if defined(VALIDATION_LEGACY_BOUNDED_TEXT_EXCEEDED_LABEL_MUTANT)
legacyBoundedExceededLabel = "mutated:"
#else
legacyBoundedExceededLabel = "exceeded-at-least:"
#endif

legacyBoundedObservedValue :: Int -> Text
#if defined(VALIDATION_LEGACY_BOUNDED_TEXT_OBSERVED_MUTANT)
legacyBoundedObservedValue value = Text.pack (show (value + 1))
#else
legacyBoundedObservedValue = Text.pack . show
#endif

legacyBoundedExceededSeparator :: Text
#if defined(VALIDATION_LEGACY_BOUNDED_TEXT_SEPARATOR_MUTANT)
legacyBoundedExceededSeparator = "|"
#else
legacyBoundedExceededSeparator = ":"
#endif

legacyBoundedRetainedText :: [Char] -> Text
#if defined(VALIDATION_LEGACY_BOUNDED_TEXT_RETAINED_DROP_MUTANT)
legacyBoundedRetainedText _ = ""
#else
legacyBoundedRetainedText = Text.pack
#endif

legacyRawProblemTag :: LegacyRawProblem -> Text
legacyRawProblemTag problem = case problem of
  LegacyPhaseByteLimit maximumValue actual -> numeric legacyTagPhaseByte [maximumValue, actual]
  LegacyBindingLimit maximumValue actual -> numeric legacyTagBindingLimit [maximumValue, actual]
  LegacyJoinLimit maximumValue actual -> numeric legacyTagJoinLimit [maximumValue, actual]
  LegacyIdByteLimit ordinal maximumValue actual -> numeric legacyTagIdByte [ordinal, maximumValue, actual]
  LegacyDispositionByteLimit ordinal maximumValue actual -> numeric legacyTagDispositionByte [ordinal, maximumValue, actual]
  LegacyOwnerByteLimit ordinal maximumValue actual -> numeric legacyTagOwnerByte [ordinal, maximumValue, actual]
  LegacyAnalyzerByteLimit ordinal maximumValue actual -> numeric legacyTagAnalyzerByte [ordinal, maximumValue, actual]
  LegacyObservationByteLimit ordinal maximumValue actual -> numeric legacyTagObservationByte [ordinal, maximumValue, actual]
  LegacyClosureByteLimit ordinal maximumValue actual -> numeric legacyTagClosureByte [ordinal, maximumValue, actual]
  LegacyReintroductionCountLimit ordinal maximumValue actual -> numeric legacyTagReintroductionCount [ordinal, maximumValue, actual]
  LegacyReintroductionByteLimit ordinal item maximumValue actual -> numeric legacyTagReintroductionByte [ordinal, item, maximumValue, actual]
  LegacyJoinSourceByteLimit ordinal maximumValue actual -> numeric legacyTagJoinSourceByte [ordinal, maximumValue, actual]
  LegacyJoinTargetByteLimit ordinal maximumValue actual -> numeric legacyTagJoinTargetByte [ordinal, maximumValue, actual]
  LegacyAggregateByteLimit maximumValue actual -> numeric legacyTagAggregateByte [maximumValue, actual]
  LegacyResourceGuardUnavailable label -> legacyTagResourceGuard <> label
  _ -> legacyTagNonResource
 where
  numeric label values = label <> ":" <> Text.intercalate ":" (map (Text.pack . show) values)

legacyTagPhaseByte, legacyTagBindingLimit, legacyTagJoinLimit, legacyTagIdByte :: Text
#if defined(VALIDATION_LEGACY_PROBLEM_TAG_PHASE_BYTE_MUTANT)
legacyTagPhaseByte = "mutated"
#else
legacyTagPhaseByte = "phase-byte-limit"
#endif
#if defined(VALIDATION_LEGACY_PROBLEM_TAG_BINDING_LIMIT_MUTANT)
legacyTagBindingLimit = "mutated"
#else
legacyTagBindingLimit = "binding-limit"
#endif
#if defined(VALIDATION_LEGACY_PROBLEM_TAG_JOIN_LIMIT_MUTANT)
legacyTagJoinLimit = "mutated"
#else
legacyTagJoinLimit = "join-limit"
#endif
#if defined(VALIDATION_LEGACY_PROBLEM_TAG_ID_BYTE_MUTANT)
legacyTagIdByte = "mutated"
#else
legacyTagIdByte = "id-byte-limit"
#endif

legacyTagDispositionByte, legacyTagOwnerByte, legacyTagAnalyzerByte, legacyTagObservationByte :: Text
#if defined(VALIDATION_LEGACY_PROBLEM_TAG_DISPOSITION_BYTE_MUTANT)
legacyTagDispositionByte = "mutated"
#else
legacyTagDispositionByte = "disposition-byte-limit"
#endif
#if defined(VALIDATION_LEGACY_PROBLEM_TAG_OWNER_BYTE_MUTANT)
legacyTagOwnerByte = "mutated"
#else
legacyTagOwnerByte = "owner-byte-limit"
#endif
#if defined(VALIDATION_LEGACY_PROBLEM_TAG_ANALYZER_BYTE_MUTANT)
legacyTagAnalyzerByte = "mutated"
#else
legacyTagAnalyzerByte = "analyzer-byte-limit"
#endif
#if defined(VALIDATION_LEGACY_PROBLEM_TAG_OBSERVATION_BYTE_MUTANT)
legacyTagObservationByte = "mutated"
#else
legacyTagObservationByte = "observation-byte-limit"
#endif

legacyTagClosureByte, legacyTagReintroductionCount, legacyTagReintroductionByte :: Text
#if defined(VALIDATION_LEGACY_PROBLEM_TAG_CLOSURE_BYTE_MUTANT)
legacyTagClosureByte = "mutated"
#else
legacyTagClosureByte = "closure-byte-limit"
#endif
#if defined(VALIDATION_LEGACY_PROBLEM_TAG_REINTRODUCTION_COUNT_MUTANT)
legacyTagReintroductionCount = "mutated"
#else
legacyTagReintroductionCount = "reintroduction-count-limit"
#endif
#if defined(VALIDATION_LEGACY_PROBLEM_TAG_REINTRODUCTION_BYTE_MUTANT)
legacyTagReintroductionByte = "mutated"
#else
legacyTagReintroductionByte = "reintroduction-byte-limit"
#endif

legacyTagJoinSourceByte, legacyTagJoinTargetByte, legacyTagAggregateByte :: Text
#if defined(VALIDATION_LEGACY_PROBLEM_TAG_JOIN_SOURCE_BYTE_MUTANT)
legacyTagJoinSourceByte = "mutated"
#else
legacyTagJoinSourceByte = "join-source-byte-limit"
#endif
#if defined(VALIDATION_LEGACY_PROBLEM_TAG_JOIN_TARGET_BYTE_MUTANT)
legacyTagJoinTargetByte = "mutated"
#else
legacyTagJoinTargetByte = "join-target-byte-limit"
#endif
#if defined(VALIDATION_LEGACY_PROBLEM_TAG_AGGREGATE_BYTE_MUTANT)
legacyTagAggregateByte = "mutated"
#else
legacyTagAggregateByte = "aggregate-byte-limit"
#endif

legacyTagResourceGuard, legacyTagNonResource :: Text
legacyTagResourceGuard = "resource-guard-unavailable:"
legacyTagNonResource = "bounded-non-resource-preflight"

legacyLengthText :: Text -> ByteString
legacyLengthText value =
  let bytes = TextEncoding.encodeUtf8 value
#if defined(VALIDATION_LEGACY_LENGTH_FRAME_COMPONENT_ORDER_MUTANT)
   in bytes <> legacyLengthPrefix bytes
#else
   in legacyLengthPrefix bytes <> bytes
#endif

legacyLengthPrefix :: ByteString -> ByteString
#if defined(VALIDATION_LEGACY_LENGTH_FRAME_MUTANT)
legacyLengthPrefix bytes = ByteString8.pack (show (ByteString.length bytes)) <> "|"
#else
legacyLengthPrefix bytes = ByteString8.pack (show (ByteString.length bytes)) <> ":"
#endif

legacySha256 :: ByteString -> Text
#if defined(VALIDATION_LEGACY_SHA256_ALGORITHM_MUTANT)
legacySha256 bytes = Text.pack . show . Crypto.hashWith Crypto.SHA256 $ bytes <> "mutated"
#else
legacySha256 = Text.pack . show . Crypto.hashWith Crypto.SHA256
#endif

boundedLegacyPrefix :: Int -> [value] -> LegacyPrefix value
boundedLegacyPrefix limit = go 0 []
 where
 go count reversed values = case values of
    [] -> LegacyPrefixWithin (legacyRetainedListPrefix reversed)
    value : rest
#if defined(VALIDATION_LEGACY_PREFIX_THRESHOLD_MUTANT)
      | count > limit -> LegacyPrefixExceeded (limit + 1) (legacyRetainedListPrefix reversed)
#else
      | count == limit -> LegacyPrefixExceeded (limit + 1) (legacyRetainedListPrefix reversed)
#endif
      | otherwise -> go (count + 1) (value : reversed) rest

legacyRetainedListPrefix :: [value] -> [value]
#if defined(VALIDATION_LEGACY_PREFIX_RETENTION_ORDER_MUTANT)
legacyRetainedListPrefix = id
#else
legacyRetainedListPrefix = reverse
#endif

boundedLegacyText :: Int -> Text -> LegacyPrefix Char
boundedLegacyText limit = go 0 [] . Text.unpack
 where
  go count reversed characters = case characters of
    [] -> LegacyPrefixWithin (legacyRetainedTextPrefix reversed)
    character : rest ->
      let next = count + legacyUtf8CharacterBytes character
       in if
#if defined(VALIDATION_LEGACY_TEXT_PREFIX_THRESHOLD_MUTANT)
            next >= limit
#else
            next > limit
#endif
            then LegacyPrefixExceeded next (legacyRetainedTextPrefix reversed)
            else go next (character : reversed) rest

legacyRetainedTextPrefix :: [Char] -> [Char]
#if defined(VALIDATION_LEGACY_TEXT_PREFIX_RETENTION_ORDER_MUTANT)
legacyRetainedTextPrefix = id
#else
legacyRetainedTextPrefix = reverse
#endif

legacyUtf8CharacterBytes :: Char -> Int
legacyUtf8CharacterBytes character
  | code <= 0x7f = legacyUtf8WidthOne
  | code <= 0x7ff = legacyUtf8WidthTwo
  | code <= 0xffff = legacyUtf8WidthThree
  | otherwise = legacyUtf8WidthFour
 where
  code = ord character

legacyUtf8WidthOne, legacyUtf8WidthTwo, legacyUtf8WidthThree, legacyUtf8WidthFour :: Int
#if defined(VALIDATION_LEGACY_UTF8_WIDTH_ONE_MUTANT)
legacyUtf8WidthOne = 2
#else
legacyUtf8WidthOne = 1
#endif
#if defined(VALIDATION_LEGACY_UTF8_WIDTH_TWO_MUTANT)
legacyUtf8WidthTwo = 1
#else
legacyUtf8WidthTwo = 2
#endif
#if defined(VALIDATION_LEGACY_UTF8_WIDTH_THREE_MUTANT)
legacyUtf8WidthThree = 1
#else
legacyUtf8WidthThree = 3
#endif
#if defined(VALIDATION_LEGACY_UTF8_WIDTH_FOUR_MUTANT)
legacyUtf8WidthFour = 1
#else
legacyUtf8WidthFour = 4
#endif

legacyTextBytes :: Text -> Int
#if defined(VALIDATION_LEGACY_AGGREGATE_TEXT_BYTE_MEASUREMENT_MUTANT)
legacyTextBytes value = ByteString.length (TextEncoding.encodeUtf8 value) + 1
#else
legacyTextBytes = ByteString.length . TextEncoding.encodeUtf8
#endif

renderCanonicalBinding :: CanonicalLegacyBinding -> Text
renderCanonicalBinding binding =
  Text.intercalate legacyBindingFieldSeparator
#if defined(VALIDATION_LEGACY_BINDING_RENDER_COMPONENT_ORDER_MUTANT)
    [ legacyRenderedBindingDisposition binding
    , legacyRenderedBindingId binding
    , legacyRenderedBindingOwner binding
    , legacyRenderedBindingAnalyzer binding
    , legacyRenderedBindingObservation binding
    , legacyRenderedBindingClosure binding
    , Text.intercalate legacyBindingReintroductionSeparator (legacyRenderedBindingReintroduction binding)
    ]
#else
    [ legacyRenderedBindingId binding
    , legacyRenderedBindingDisposition binding
    , legacyRenderedBindingOwner binding
    , legacyRenderedBindingAnalyzer binding
    , legacyRenderedBindingObservation binding
    , legacyRenderedBindingClosure binding
    , Text.intercalate legacyBindingReintroductionSeparator (legacyRenderedBindingReintroduction binding)
    ]
#endif

legacyBindingFieldSeparator :: Text
#if defined(VALIDATION_LEGACY_BINDING_RENDER_FIELD_SEPARATOR_MUTANT)
legacyBindingFieldSeparator = ":"
#else
legacyBindingFieldSeparator = "|"
#endif

legacyBindingReintroductionSeparator :: Text
legacyBindingReintroductionSeparator = ","

legacyRenderedBindingId :: CanonicalLegacyBinding -> Text
#if defined(VALIDATION_LEGACY_BINDING_RENDER_ID_MUTANT)
legacyRenderedBindingId _ = "mutated"
#else
legacyRenderedBindingId = canonicalBindingId
#endif

legacyRenderedBindingDisposition :: CanonicalLegacyBinding -> Text
#if defined(VALIDATION_LEGACY_BINDING_RENDER_DISPOSITION_MUTANT)
legacyRenderedBindingDisposition _ = "mutated"
#else
legacyRenderedBindingDisposition = canonicalBindingDisposition
#endif

legacyRenderedBindingOwner :: CanonicalLegacyBinding -> Text
#if defined(VALIDATION_LEGACY_BINDING_RENDER_OWNER_MUTANT)
legacyRenderedBindingOwner _ = "mutated"
#else
legacyRenderedBindingOwner = canonicalBindingOwner
#endif

legacyRenderedBindingAnalyzer :: CanonicalLegacyBinding -> Text
#if defined(VALIDATION_LEGACY_BINDING_RENDER_ANALYZER_MUTANT)
legacyRenderedBindingAnalyzer _ = "mutated"
#else
legacyRenderedBindingAnalyzer = canonicalBindingAnalyzer
#endif

legacyRenderedBindingObservation :: CanonicalLegacyBinding -> Text
#if defined(VALIDATION_LEGACY_BINDING_RENDER_OBSERVATION_MUTANT)
legacyRenderedBindingObservation _ = "mutated"
#else
legacyRenderedBindingObservation = canonicalBindingObservation
#endif

legacyRenderedBindingClosure :: CanonicalLegacyBinding -> Text
#if defined(VALIDATION_LEGACY_BINDING_RENDER_CLOSURE_MUTANT)
legacyRenderedBindingClosure _ = "mutated"
#else
legacyRenderedBindingClosure = canonicalBindingClosure
#endif

legacyRenderedBindingReintroduction :: CanonicalLegacyBinding -> [Text]
#if defined(VALIDATION_LEGACY_BINDING_RENDER_REINTRODUCTION_MUTANT)
legacyRenderedBindingReintroduction _ = ["mutated"]
#else
legacyRenderedBindingReintroduction = canonicalBindingReintroduction
#endif

legacyPhaseWidthValid, legacyPhaseAlphabetValid, legacyPhaseRangeValid :: Text -> Bool
#if defined(VALIDATION_LEGACY_RAW_PHASE_WIDTH_BYPASS_MUTANT)
legacyPhaseWidthValid _ = True
#else
legacyPhaseWidthValid value = Text.length value == 2
#endif
#if defined(VALIDATION_LEGACY_RAW_PHASE_ALPHABET_BYPASS_MUTANT)
legacyPhaseAlphabetValid = Text.any legacyPhaseCharacterValid
#else
legacyPhaseAlphabetValid = Text.all legacyPhaseCharacterValid
#endif
#if defined(VALIDATION_LEGACY_RAW_PHASE_RANGE_BYPASS_MUTANT)
legacyPhaseRangeValid _ = True
#else
legacyPhaseRangeValid value = value <= "95"
#endif

legacyPhaseCharacterValid :: Char -> Bool
#if defined(VALIDATION_LEGACY_RAW_PHASE_CHARACTER_COMPOSITION_MUTANT)
legacyPhaseCharacterValid character =
  legacyPhaseCharacterLowerBoundValid character
    || legacyPhaseCharacterUpperBoundValid character
#else
legacyPhaseCharacterValid character =
  legacyPhaseCharacterLowerBoundValid character
    && legacyPhaseCharacterUpperBoundValid character
#endif

legacyPhaseCharacterLowerBoundValid :: Char -> Bool
#if defined(VALIDATION_LEGACY_RAW_PHASE_ALPHABET_LOWER_BYPASS_MUTANT)
legacyPhaseCharacterLowerBoundValid _ = True
#else
legacyPhaseCharacterLowerBoundValid character = character >= '0'
#endif

legacyPhaseCharacterUpperBoundValid :: Char -> Bool
#if defined(VALIDATION_LEGACY_RAW_PHASE_ALPHABET_UPPER_BYPASS_MUTANT)
legacyPhaseCharacterUpperBoundValid _ = True
#else
legacyPhaseCharacterUpperBoundValid character = character <= '9'
#endif

legacyBindingCardinalityValid :: [RawLegacyBinding] -> Bool
#if defined(VALIDATION_LEGACY_RAW_BINDING_CARDINALITY_BYPASS_MUTANT)
legacyBindingCardinalityValid _ = True
#else
legacyBindingCardinalityValid values = length values == maximumLegacyBindings
#endif

legacyBindingOrderValid :: [Text] -> Bool
#if defined(VALIDATION_LEGACY_RAW_BINDING_ORDER_BYPASS_MUTANT)
legacyBindingOrderValid _ = True
#else
legacyBindingOrderValid values = values == map canonicalBindingId canonicalLegacyBindings
#endif

legacyJoinCardinalityValid :: [RawLegacyJoin] -> Bool
#if defined(VALIDATION_LEGACY_RAW_JOIN_CARDINALITY_BYPASS_MUTANT)
legacyJoinCardinalityValid _ = True
#else
legacyJoinCardinalityValid values = length values == maximumLegacyJoins
#endif

legacyJoinOrderValid :: [Text] -> Bool
#if defined(VALIDATION_LEGACY_RAW_JOIN_ORDER_BYPASS_MUTANT)
legacyJoinOrderValid _ = True
#else
legacyJoinOrderValid values = values == map canonicalJoinSource canonicalLegacyJoins
#endif

legacyBindingDuplicateRejected :: Text -> [Text] -> Bool
#if defined(VALIDATION_LEGACY_RAW_BINDING_DUPLICATE_BYPASS_MUTANT)
legacyBindingDuplicateRejected _ _ = False
#else
legacyBindingDuplicateRejected value seen = elem value seen
#endif

legacyBindingUnknownRejected :: [Text] -> Text -> Bool
#if defined(VALIDATION_LEGACY_RAW_BINDING_UNKNOWN_BYPASS_MUTANT)
legacyBindingUnknownRejected _ _ = False
#else
legacyBindingUnknownRejected expected value = notElem value expected
#endif

legacyJoinDuplicateRejected :: Text -> [Text] -> Bool
#if defined(VALIDATION_LEGACY_RAW_JOIN_DUPLICATE_BYPASS_MUTANT)
legacyJoinDuplicateRejected _ _ = False
#else
legacyJoinDuplicateRejected value seen = elem value seen
#endif

legacyJoinUnknownRejected :: [Text] -> Text -> Bool
#if defined(VALIDATION_LEGACY_RAW_JOIN_UNKNOWN_BYPASS_MUTANT)
legacyJoinUnknownRejected _ _ = False
#else
legacyJoinUnknownRejected expected value = notElem value expected
#endif

legacyDispositionMatches, legacyOwnerMatches, legacyAnalyzerMatches, legacyObservationMatches, legacyClosureMatches :: Text -> Text -> Bool
#if defined(VALIDATION_LEGACY_RAW_DISPOSITION_MATCH_BYPASS_MUTANT)
legacyDispositionMatches _ _ = True
#else
legacyDispositionMatches = (==)
#endif
#if defined(VALIDATION_LEGACY_RAW_OWNER_MATCH_BYPASS_MUTANT)
legacyOwnerMatches _ _ = True
#else
legacyOwnerMatches = (==)
#endif
#if defined(VALIDATION_LEGACY_RAW_ANALYZER_MATCH_BYPASS_MUTANT)
legacyAnalyzerMatches _ _ = True
#else
legacyAnalyzerMatches = (==)
#endif
#if defined(VALIDATION_LEGACY_RAW_OBSERVATION_MATCH_BYPASS_MUTANT)
legacyObservationMatches _ _ = True
#else
legacyObservationMatches = (==)
#endif
#if defined(VALIDATION_LEGACY_RAW_CLOSURE_MATCH_BYPASS_MUTANT)
legacyClosureMatches _ _ = True
#else
legacyClosureMatches = (==)
#endif

legacyReintroductionMatches :: [Text] -> [Text] -> Bool
#if defined(VALIDATION_LEGACY_RAW_REINTRODUCTION_MATCH_BYPASS_MUTANT)
legacyReintroductionMatches _ _ = True
#else
legacyReintroductionMatches = (==)
#endif

legacyJoinTargetMatches :: Text -> Text -> Bool
#if defined(VALIDATION_LEGACY_RAW_JOIN_TARGET_MATCH_BYPASS_MUTANT)
legacyJoinTargetMatches _ _ = True
#else
legacyJoinTargetMatches = (==)
#endif

legacyPhaseByteLimitExceeded, legacyBindingLimitExceeded, legacyJoinLimitExceeded :: Int -> Bool
#if defined(VALIDATION_LEGACY_RAW_PHASE_BYTE_LIMIT_BYPASS_MUTANT)
legacyPhaseByteLimitExceeded _ = False
#else
legacyPhaseByteLimitExceeded actual = actual > maximumLegacyPhaseBytes
#endif
#if defined(VALIDATION_LEGACY_RAW_BINDING_LIMIT_BYPASS_MUTANT)
legacyBindingLimitExceeded _ = False
#else
legacyBindingLimitExceeded actual = actual > maximumLegacyBindings
#endif
#if defined(VALIDATION_LEGACY_RAW_JOIN_LIMIT_BYPASS_MUTANT)
legacyJoinLimitExceeded _ = False
#else
legacyJoinLimitExceeded actual = actual > maximumLegacyJoins
#endif

legacyIdByteLimitExceeded, legacyDispositionByteLimitExceeded, legacyOwnerByteLimitExceeded :: Int -> Bool
#if defined(VALIDATION_LEGACY_RAW_ID_BYTE_LIMIT_BYPASS_MUTANT)
legacyIdByteLimitExceeded _ = False
#else
legacyIdByteLimitExceeded actual = actual > maximumLegacyIdBytes
#endif
#if defined(VALIDATION_LEGACY_RAW_DISPOSITION_BYTE_LIMIT_BYPASS_MUTANT)
legacyDispositionByteLimitExceeded _ = False
#else
legacyDispositionByteLimitExceeded actual = actual > maximumLegacyDispositionBytes
#endif
#if defined(VALIDATION_LEGACY_RAW_OWNER_BYTE_LIMIT_BYPASS_MUTANT)
legacyOwnerByteLimitExceeded _ = False
#else
legacyOwnerByteLimitExceeded actual = actual > maximumLegacyOwnerBytes
#endif

legacyAnalyzerByteLimitExceeded, legacyObservationByteLimitExceeded, legacyClosureByteLimitExceeded :: Int -> Bool
#if defined(VALIDATION_LEGACY_RAW_ANALYZER_BYTE_LIMIT_BYPASS_MUTANT)
legacyAnalyzerByteLimitExceeded _ = False
#else
legacyAnalyzerByteLimitExceeded actual = actual > maximumLegacyAnalyzerBytes
#endif
#if defined(VALIDATION_LEGACY_RAW_OBSERVATION_BYTE_LIMIT_BYPASS_MUTANT)
legacyObservationByteLimitExceeded _ = False
#else
legacyObservationByteLimitExceeded actual = actual > maximumLegacyObservationBytes
#endif
#if defined(VALIDATION_LEGACY_RAW_CLOSURE_BYTE_LIMIT_BYPASS_MUTANT)
legacyClosureByteLimitExceeded _ = False
#else
legacyClosureByteLimitExceeded actual = actual > maximumLegacyClosureBytes
#endif

legacyReintroductionCountLimitExceeded, legacyReintroductionByteLimitExceeded :: Int -> Bool
#if defined(VALIDATION_LEGACY_RAW_REINTRODUCTION_COUNT_LIMIT_BYPASS_MUTANT)
legacyReintroductionCountLimitExceeded _ = False
#else
legacyReintroductionCountLimitExceeded actual = actual > maximumLegacyReintroductionValues
#endif
#if defined(VALIDATION_LEGACY_RAW_REINTRODUCTION_BYTE_LIMIT_BYPASS_MUTANT)
legacyReintroductionByteLimitExceeded _ = False
#else
legacyReintroductionByteLimitExceeded actual = actual > maximumLegacyReintroductionBytes
#endif

legacyJoinSourceByteLimitExceeded, legacyJoinTargetByteLimitExceeded, legacyAggregateByteLimitExceeded :: Int -> Bool
#if defined(VALIDATION_LEGACY_RAW_JOIN_SOURCE_BYTE_LIMIT_BYPASS_MUTANT)
legacyJoinSourceByteLimitExceeded _ = False
#else
legacyJoinSourceByteLimitExceeded actual = actual > maximumLegacyJoinSourceBytes
#endif
#if defined(VALIDATION_LEGACY_RAW_JOIN_TARGET_BYTE_LIMIT_BYPASS_MUTANT)
legacyJoinTargetByteLimitExceeded _ = False
#else
legacyJoinTargetByteLimitExceeded actual = actual > maximumLegacyJoinTargetBytes
#endif
#if defined(VALIDATION_LEGACY_RAW_AGGREGATE_BYTE_LIMIT_BYPASS_MUTANT)
legacyAggregateByteLimitExceeded _ = False
#else
legacyAggregateByteLimitExceeded actual = actual > maximumLegacyAggregateBytes
#endif

data LegacyBindingKey
  = KeyLtdSrc000
  | KeyLtdSrc001
  | KeyLtdSrc002
  | KeyLtdSrc003
  | KeyLtdSrc004
  | KeyLtdSrc005
  | KeyLtdSrc006
  | KeyLtdSrc007
  | KeyLtdSrc008
  | KeyLtdSrc009
  | KeyLtdMeta001
  | KeyLtdVal001
  | KeyLtdVal002
  | KeyLtdVal003
  | KeyLtdVal004
  | KeyLtdVal005
  | KeyLtdVal006
  | KeyLtdDoc001
  | KeyLtdName001
  | KeyLtdHost001
  | KeyLtdHost002
  | KeyLtdImg001
  | KeyLtdRun001
  | KeyLtdSeed001
  | KeyLtdSeed002
  deriving (Eq, Ord, Show)

data CanonicalLegacyBinding = CanonicalLegacyBinding
  { canonicalBindingKey :: LegacyBindingKey
  , canonicalBindingId :: Text
  , canonicalBindingDisposition :: Text
  , canonicalBindingOwner :: Text
  , canonicalBindingAnalyzer :: Text
  , canonicalBindingObservation :: Text
  , canonicalBindingClosure :: Text
  , canonicalBindingReintroduction :: [Text]
  }
  deriving (Eq, Show)

canonicalLegacyBindings :: [CanonicalLegacyBinding]
#if defined(VALIDATION_LEGACY_CANONICAL_BINDING_LIST_COMPOSITION_MUTANT)
canonicalLegacyBindings =
  drop 1 (zipWith canonicalBindingFromRaw canonicalBindingKeys Internal.legacyRawDiagnosticBindings)
#else
canonicalLegacyBindings =
  zipWith canonicalBindingFromRaw canonicalBindingKeys Internal.legacyRawDiagnosticBindings
#endif

canonicalBindingKeys :: [LegacyBindingKey]
canonicalBindingKeys = canonicalBindingKeysInOrder

canonicalBindingKeysInOrder :: [LegacyBindingKey]
canonicalBindingKeysInOrder =
  [ KeyLtdSrc000, KeyLtdSrc001, KeyLtdSrc002, KeyLtdSrc003, KeyLtdSrc004
  , KeyLtdSrc005, KeyLtdSrc006, KeyLtdSrc007, KeyLtdSrc008, KeyLtdSrc009
  , KeyLtdMeta001, KeyLtdVal001, KeyLtdVal002, KeyLtdVal003, KeyLtdVal004
  , KeyLtdVal005, KeyLtdVal006, KeyLtdDoc001, KeyLtdName001, KeyLtdHost001
  , KeyLtdHost002, KeyLtdImg001, KeyLtdRun001, KeyLtdSeed001, KeyLtdSeed002
  ]

canonicalBindingFromRaw :: LegacyBindingKey -> RawLegacyBinding -> CanonicalLegacyBinding
#if defined(VALIDATION_LEGACY_CANONICAL_BINDING_COMPOSITION_MUTANT)
canonicalBindingFromRaw key (identifier, disposition, owner, analyzer, observed, closed, reintroduced) =
  CanonicalLegacyBinding key disposition identifier owner analyzer observed closed reintroduced
#else
canonicalBindingFromRaw key (identifier, disposition, owner, analyzer, observed, closed, reintroduced) =
  CanonicalLegacyBinding key identifier disposition owner analyzer observed closed reintroduced
#endif

canonicalBindingSelected :: CanonicalLegacyBinding -> Bool
canonicalBindingSelected binding = case canonicalBindingKey binding of
  KeyLtdSrc000 ->
#if defined(VALIDATION_LEGACY_SELECT_LTD_SRC000_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdSrc001 ->
#if defined(VALIDATION_LEGACY_SELECT_LTD_SRC001_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdSrc002 ->
#if defined(VALIDATION_LEGACY_SELECT_LTD_SRC002_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdSrc003 ->
#if defined(VALIDATION_LEGACY_SELECT_LTD_SRC003_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdSrc004 ->
#if defined(VALIDATION_LEGACY_SELECT_LTD_SRC004_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdSrc005 ->
#if defined(VALIDATION_LEGACY_SELECT_LTD_SRC005_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdSrc006 ->
#if defined(VALIDATION_LEGACY_SELECT_LTD_SRC006_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdSrc007 ->
#if defined(VALIDATION_LEGACY_SELECT_LTD_SRC007_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdSrc008 ->
#if defined(VALIDATION_LEGACY_SELECT_LTD_SRC008_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdSrc009 ->
#if defined(VALIDATION_LEGACY_SELECT_LTD_SRC009_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdMeta001 ->
#if defined(VALIDATION_LEGACY_SELECT_LTD_META001_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdVal001 ->
#if defined(VALIDATION_LEGACY_SELECT_LTD_VAL001_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdVal002 ->
#if defined(VALIDATION_LEGACY_SELECT_LTD_VAL002_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdVal003 ->
#if defined(VALIDATION_LEGACY_SELECT_LTD_VAL003_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdVal004 ->
#if defined(VALIDATION_LEGACY_SELECT_LTD_VAL004_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdVal005 ->
#if defined(VALIDATION_LEGACY_SELECT_LTD_VAL005_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdVal006 ->
#if defined(VALIDATION_LEGACY_SELECT_LTD_VAL006_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdDoc001 ->
#if defined(VALIDATION_LEGACY_SELECT_LTD_DOC001_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdName001 ->
#if defined(VALIDATION_LEGACY_SELECT_LTD_NAME001_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdHost001 ->
#if defined(VALIDATION_LEGACY_SELECT_LTD_HOST001_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdHost002 ->
#if defined(VALIDATION_LEGACY_SELECT_LTD_HOST002_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdImg001 ->
#if defined(VALIDATION_LEGACY_SELECT_LTD_IMG001_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdRun001 ->
#if defined(VALIDATION_LEGACY_SELECT_LTD_RUN001_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdSeed001 ->
#if defined(VALIDATION_LEGACY_SELECT_LTD_SEED001_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdSeed002 ->
#if defined(VALIDATION_LEGACY_SELECT_LTD_SEED002_DROP_MUTANT)
    False
#else
    True
#endif


canonicalBindingObservationRetained :: CanonicalLegacyBinding -> Bool
canonicalBindingObservationRetained binding = case canonicalBindingKey binding of
  KeyLtdSrc000 ->
#if defined(VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_SRC000_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdSrc001 ->
#if defined(VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_SRC001_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdSrc002 ->
#if defined(VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_SRC002_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdSrc003 ->
#if defined(VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_SRC003_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdSrc004 ->
#if defined(VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_SRC004_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdSrc005 ->
#if defined(VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_SRC005_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdSrc006 ->
#if defined(VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_SRC006_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdSrc007 ->
#if defined(VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_SRC007_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdSrc008 ->
#if defined(VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_SRC008_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdSrc009 ->
#if defined(VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_SRC009_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdMeta001 ->
#if defined(VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_META001_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdVal001 ->
#if defined(VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_VAL001_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdVal002 ->
#if defined(VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_VAL002_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdVal003 ->
#if defined(VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_VAL003_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdVal004 ->
#if defined(VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_VAL004_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdVal005 ->
#if defined(VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_VAL005_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdVal006 ->
#if defined(VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_VAL006_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdDoc001 ->
#if defined(VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_DOC001_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdName001 ->
#if defined(VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_NAME001_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdHost001 ->
#if defined(VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_HOST001_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdHost002 ->
#if defined(VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_HOST002_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdImg001 ->
#if defined(VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_IMG001_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdRun001 ->
#if defined(VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_RUN001_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdSeed001 ->
#if defined(VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_SEED001_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdSeed002 ->
#if defined(VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_SEED002_DROP_MUTANT)
    False
#else
    True
#endif

canonicalBindingExecutionFindingRetained :: CanonicalLegacyBinding -> Bool
canonicalBindingExecutionFindingRetained binding = case canonicalBindingKey binding of
  KeyLtdSrc000 ->
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_LTD_SRC000_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdSrc001 ->
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_LTD_SRC001_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdSrc002 ->
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_LTD_SRC002_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdSrc003 ->
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_LTD_SRC003_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdSrc004 ->
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_LTD_SRC004_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdSrc005 ->
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_LTD_SRC005_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdSrc006 ->
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_LTD_SRC006_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdSrc007 ->
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_LTD_SRC007_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdSrc008 ->
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_LTD_SRC008_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdSrc009 ->
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_LTD_SRC009_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdMeta001 ->
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_LTD_META001_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdVal001 ->
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_LTD_VAL001_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdVal002 ->
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_LTD_VAL002_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdVal003 ->
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_LTD_VAL003_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdVal004 ->
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_LTD_VAL004_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdVal005 ->
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_LTD_VAL005_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdVal006 ->
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_LTD_VAL006_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdDoc001 ->
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_LTD_DOC001_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdName001 ->
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_LTD_NAME001_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdHost001 ->
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_LTD_HOST001_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdHost002 ->
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_LTD_HOST002_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdImg001 ->
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_LTD_IMG001_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdRun001 ->
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_LTD_RUN001_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdSeed001 ->
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_LTD_SEED001_DROP_MUTANT)
    False
#else
    True
#endif
  KeyLtdSeed002 ->
#if defined(VALIDATION_LEGACY_BINDING_EXECUTION_LTD_SEED002_DROP_MUTANT)
    False
#else
    True
#endif


data LegacyJoinKey
  = JoinSourceTools
  | JoinSourceDhall
  | JoinSourceProto
  | JoinSourceUi
  | JoinSourcePulumi
  | JoinSourceTest
  | JoinSourceProbe
  | JoinSourcePb
  | JoinSourceVendor
  deriving (Eq, Ord, Show)

data CanonicalLegacyJoin = CanonicalLegacyJoin
  { canonicalJoinKey :: LegacyJoinKey
  , canonicalJoinSource :: Text
  , canonicalJoinTarget :: Text
  }
  deriving (Eq, Show)

canonicalLegacyJoins :: [CanonicalLegacyJoin]
#if defined(VALIDATION_LEGACY_CANONICAL_JOIN_LIST_COMPOSITION_MUTANT)
canonicalLegacyJoins =
  drop 1 (zipWith canonicalJoinFromRaw canonicalJoinKeys Internal.legacyRawDiagnosticJoins)
#else
canonicalLegacyJoins =
  zipWith canonicalJoinFromRaw canonicalJoinKeys Internal.legacyRawDiagnosticJoins
#endif

canonicalJoinKeys :: [LegacyJoinKey]
canonicalJoinKeys = canonicalJoinKeysInOrder

canonicalJoinKeysInOrder :: [LegacyJoinKey]
canonicalJoinKeysInOrder =
  [ JoinSourceTools, JoinSourceDhall, JoinSourceProto, JoinSourceUi, JoinSourcePulumi
  , JoinSourceTest, JoinSourceProbe, JoinSourcePb, JoinSourceVendor
  ]

canonicalJoinFromRaw :: LegacyJoinKey -> RawLegacyJoin -> CanonicalLegacyJoin
#if defined(VALIDATION_LEGACY_CANONICAL_JOIN_COMPOSITION_MUTANT)
canonicalJoinFromRaw key (source, target) = CanonicalLegacyJoin key target source
#else
canonicalJoinFromRaw key (source, target) = CanonicalLegacyJoin key source target
#endif

canonicalJoinSelected :: CanonicalLegacyJoin -> Bool
canonicalJoinSelected item = case canonicalJoinKey item of
  JoinSourceTools ->
#if defined(VALIDATION_LEGACY_SELECT_JOIN_SOURCE_TOOLS_DROP_MUTANT)
    False
#else
    True
#endif
  JoinSourceDhall ->
#if defined(VALIDATION_LEGACY_SELECT_JOIN_SOURCE_DHALL_DROP_MUTANT)
    False
#else
    True
#endif
  JoinSourceProto ->
#if defined(VALIDATION_LEGACY_SELECT_JOIN_SOURCE_PROTO_DROP_MUTANT)
    False
#else
    True
#endif
  JoinSourceUi ->
#if defined(VALIDATION_LEGACY_SELECT_JOIN_SOURCE_UI_DROP_MUTANT)
    False
#else
    True
#endif
  JoinSourcePulumi ->
#if defined(VALIDATION_LEGACY_SELECT_JOIN_SOURCE_PULUMI_DROP_MUTANT)
    False
#else
    True
#endif
  JoinSourceTest ->
#if defined(VALIDATION_LEGACY_SELECT_JOIN_SOURCE_TEST_DROP_MUTANT)
    False
#else
    True
#endif
  JoinSourceProbe ->
#if defined(VALIDATION_LEGACY_SELECT_JOIN_SOURCE_PROBE_DROP_MUTANT)
    False
#else
    True
#endif
  JoinSourcePb ->
#if defined(VALIDATION_LEGACY_SELECT_JOIN_SOURCE_PB_DROP_MUTANT)
    False
#else
    True
#endif
  JoinSourceVendor ->
#if defined(VALIDATION_LEGACY_SELECT_JOIN_SOURCE_VENDOR_DROP_MUTANT)
    False
#else
    True
#endif

canonicalJoinObservationRetained :: CanonicalLegacyJoin -> Bool
canonicalJoinObservationRetained item = case canonicalJoinKey item of
  JoinSourceTools ->
#if defined(VALIDATION_LEGACY_JOIN_OBSERVATION_SOURCE_TOOLS_DROP_MUTANT)
    False
#else
    True
#endif
  JoinSourceDhall ->
#if defined(VALIDATION_LEGACY_JOIN_OBSERVATION_SOURCE_DHALL_DROP_MUTANT)
    False
#else
    True
#endif
  JoinSourceProto ->
#if defined(VALIDATION_LEGACY_JOIN_OBSERVATION_SOURCE_PROTO_DROP_MUTANT)
    False
#else
    True
#endif
  JoinSourceUi ->
#if defined(VALIDATION_LEGACY_JOIN_OBSERVATION_SOURCE_UI_DROP_MUTANT)
    False
#else
    True
#endif
  JoinSourcePulumi ->
#if defined(VALIDATION_LEGACY_JOIN_OBSERVATION_SOURCE_PULUMI_DROP_MUTANT)
    False
#else
    True
#endif
  JoinSourceTest ->
#if defined(VALIDATION_LEGACY_JOIN_OBSERVATION_SOURCE_TEST_DROP_MUTANT)
    False
#else
    True
#endif
  JoinSourceProbe ->
#if defined(VALIDATION_LEGACY_JOIN_OBSERVATION_SOURCE_PROBE_DROP_MUTANT)
    False
#else
    True
#endif
  JoinSourcePb ->
#if defined(VALIDATION_LEGACY_JOIN_OBSERVATION_SOURCE_PB_DROP_MUTANT)
    False
#else
    True
#endif
  JoinSourceVendor ->
#if defined(VALIDATION_LEGACY_JOIN_OBSERVATION_SOURCE_VENDOR_DROP_MUTANT)
    False
#else
    True
#endif

canonicalJoinExecutionFindingRetained :: CanonicalLegacyJoin -> Bool
canonicalJoinExecutionFindingRetained item = case canonicalJoinKey item of
  JoinSourceTools ->
#if defined(VALIDATION_LEGACY_JOIN_EXECUTION_SOURCE_TOOLS_DROP_MUTANT)
    False
#else
    True
#endif
  JoinSourceDhall ->
#if defined(VALIDATION_LEGACY_JOIN_EXECUTION_SOURCE_DHALL_DROP_MUTANT)
    False
#else
    True
#endif
  JoinSourceProto ->
#if defined(VALIDATION_LEGACY_JOIN_EXECUTION_SOURCE_PROTO_DROP_MUTANT)
    False
#else
    True
#endif
  JoinSourceUi ->
#if defined(VALIDATION_LEGACY_JOIN_EXECUTION_SOURCE_UI_DROP_MUTANT)
    False
#else
    True
#endif
  JoinSourcePulumi ->
#if defined(VALIDATION_LEGACY_JOIN_EXECUTION_SOURCE_PULUMI_DROP_MUTANT)
    False
#else
    True
#endif
  JoinSourceTest ->
#if defined(VALIDATION_LEGACY_JOIN_EXECUTION_SOURCE_TEST_DROP_MUTANT)
    False
#else
    True
#endif
  JoinSourceProbe ->
#if defined(VALIDATION_LEGACY_JOIN_EXECUTION_SOURCE_PROBE_DROP_MUTANT)
    False
#else
    True
#endif
  JoinSourcePb ->
#if defined(VALIDATION_LEGACY_JOIN_EXECUTION_SOURCE_PB_DROP_MUTANT)
    False
#else
    True
#endif
  JoinSourceVendor ->
#if defined(VALIDATION_LEGACY_JOIN_EXECUTION_SOURCE_VENDOR_DROP_MUTANT)
    False
#else
    True
#endif
