{-# LANGUAGE OverloadedStrings #-}

module SourceDebtBaselineInternalOracle
  ( runSourceDebtBaselineInternalExactCaseOracle
  , runSourceDebtBaselineInternalOracle
  , runSourceDebtBaselineInternalSelectorImpactOracle
  , runSourceDebtBaselineInternalSelectorIsolationOracle
  , runSourceDebtBaselineInternalSelectorOracle
  , sourceDebtBaselineInternalExactCaseLabels
  , sourceDebtBaselineInternalSelectorNames
  ) where

-- Direct-source component oracle for the package-hidden acquired evidence,
-- lifecycle fold, and private serializers. The two test-only hooks are absent
-- from every packaged library build.

import Amoebius.Validation.SourceClosure.Internal
  ( AcquiredSourceSnapshot
  , IndexEntry (..)
  , IndexMode (..)
  , SourceDebtId (..)
  , SourceSnapshot (..)
  , TrackedEntry (..)
  , sourceClosureInternalTestAcquire
  )
import Amoebius.Validation.SourceDebtBaseline.Internal
  ( SourceDebtEvidence
  , analyzeAcquiredSourceDebt
  , foldAcquiredSourceDebtState
  , sourceDebtEvidenceCheck
  , sourceDebtInternalTestIntegrityFindings
  , sourceDebtInternalTestProblemFindings
  , sourceDebtInternalTestStateResults
  )
import Amoebius.Validation.Types (CheckResult (..), Finding (..), Observation (..))
import Control.Monad (unless)
import Data.ByteString qualified as ByteString
import Data.List (group, sort)
import Data.Text (Text)
import Data.Text qualified as Text

runSourceDebtBaselineInternalOracle :: IO ()
runSourceDebtBaselineInternalOracle =
  finishDiagnostics
    "SourceDebtBaselineInternalOracle"
    (intentProblems <> impactProblems <> concatMap snd exactCaseProblems)

runSourceDebtBaselineInternalExactCaseOracle :: String -> IO ()
runSourceDebtBaselineInternalExactCaseOracle label =
  finishDiagnostics
    "SourceDebtBaselineInternalOracle exact case"
    ( intentProblems
        <> impactProblems
        <> case [problems | (candidate, problems) <- exactCaseProblems, candidate == label] of
          [problems] -> problems
          matches -> ["exact case is not exactly resolvable: " <> label <> "; count=" <> show (length matches)]
    )

runSourceDebtBaselineInternalSelectorOracle :: String -> IO ()
runSourceDebtBaselineInternalSelectorOracle selector =
  finishDiagnostics
    "SourceDebtBaselineInternalOracle selector"
    ( intentProblems
        <> impactProblems
        <> case [target | (candidate, target) <- mutationIntent, candidate == selector] of
          [target] -> case [problems | (label, problems) <- exactCaseProblems, label == target] of
            [problems] -> problems
            matches -> ["selector target is not exactly resolvable: " <> selector <> "; count=" <> show (length matches)]
          matches -> ["selector intent is not exactly resolvable: " <> selector <> "; count=" <> show (length matches)]
    )

runSourceDebtBaselineInternalSelectorImpactOracle :: String -> IO ()
runSourceDebtBaselineInternalSelectorImpactOracle selector =
  finishDiagnostics
    "SourceDebtBaselineInternalOracle selector impact"
    ( intentProblems
        <> impactProblems
        <> case [labels | (candidate, labels) <- mutationImpact, candidate == selector] of
          [expectedLabels] ->
            [ "registered impacted internal case stayed green: " <> selector <> " -> " <> label
            | label <- expectedLabels
            , label `notElem` observedImpactedLabels
            ]
          matches -> ["internal impact signature is not exact: " <> selector <> "; count=" <> show (length matches)]
    )

runSourceDebtBaselineInternalSelectorIsolationOracle :: String -> IO ()
runSourceDebtBaselineInternalSelectorIsolationOracle selector =
  finishDiagnostics
    "SourceDebtBaselineInternalOracle selector isolation"
    ( intentProblems
        <> impactProblems
        <> case [labels | (candidate, labels) <- mutationImpact, candidate == selector] of
          [expectedLabels] ->
            [ "registered unaffected internal case reddened: " <> selector <> " -> " <> label
            | label <- observedImpactedLabels
            , label `notElem` expectedLabels
            ]
          matches -> ["internal isolation signature is not exact: " <> selector <> "; count=" <> show (length matches)]
    )

observedImpactedLabels :: [String]
observedImpactedLabels = [label | (label, problems) <- exactCaseProblems, not (null problems)]

sourceDebtBaselineInternalSelectorNames :: [String]
sourceDebtBaselineInternalSelectorNames = map fst mutationIntent

sourceDebtBaselineInternalExactCaseLabels :: [String]
sourceDebtBaselineInternalExactCaseLabels = map fst exactCaseProblems

exactCaseProblems :: [(String, [String])]
exactCaseProblems =
  [ ("acquired evidence and snapshot binding are exact", expectNoProblems "acquired evidence and snapshot binding are exact" evidenceProblems)
  , ("acquired traversal refusal is exact", expectExact "acquired traversal refusal is exact" acquiredTraversalLimitExpected (acquiredCheck acquiredTraversalExceededEntries))
  , ("acquired path resource refusal is exact", expectExact "acquired path resource refusal is exact" (acquiredPathLimitExpected, "refused:path-utf8 limit exceeded: maximum=1024, observed-at-least=1025") (acquiredResourceObservation [acquiredPathExceededEntry]))
  , ("acquired object resource refusal is exact", expectExact "acquired object resource refusal is exact" (acquiredObjectLimitExpected, "refused:object-id limit exceeded: maximum=64, observed-at-least=65") (acquiredResourceObservation [acquiredObjectExceededEntry]))
  , ("acquired blob resource refusal is exact", expectExact "acquired blob resource refusal is exact" (acquiredBlobLimitExpected, "refused:blob limit exceeded: maximum=16777216, observed-at-least=16777217") (acquiredResourceObservation [acquiredBlobExceededEntry]))
  , ("acquired aggregate resource refusal is exact", expectExact "acquired aggregate resource refusal is exact" (acquiredAggregateLimitExpected, "refused:aggregate-blob limit exceeded: maximum=33554432, observed-at-least=33554433") (acquiredResourceObservation acquiredAggregateExceededEntries))
  , ("private problem serializers are exact", expectExact "private problem serializers are exact" expectedProblemFindings sourceDebtInternalTestProblemFindings)
  , ("state-integrity serializers are exact", expectExact "state-integrity serializers are exact" expectedIntegrityFindings sourceDebtInternalTestIntegrityFindings)
  , ("private lifecycle construction and fold are exact", expectExact "private lifecycle construction and fold are exact" expectedStateResults sourceDebtInternalTestStateResults)
  ]

evidenceProblems :: [String]
evidenceProblems =
  expectExact "same-snapshot evidence result" expectedEmptyAcquired (sourceDebtEvidenceCheck acquiredA evidenceA)
    <> expectExact "cross-snapshot evidence result" expectedMismatchedEvidence (sourceDebtEvidenceCheck acquiredB evidenceA)
    <> concatMap exactClosedFold expectedEmptyAcquiredFolds
    <> expectExact
      "cross-snapshot lifecycle fold"
      "refused:source-debt evidence snapshot mismatch: expected=snapshot-b, actual=snapshot-a"
      (renderFold acquiredB evidenceA SourcePb)
 where
  evidenceA = analyzeAcquiredSourceDebt acquiredA
  exactClosedFold (identifier, expected) =
    expectExact
      ("closed lifecycle fold " <> show identifier)
      expected
      (renderFold acquiredA evidenceA identifier)

expectedEmptyAcquiredFolds :: [(SourceDebtId, Text)]
expectedEmptyAcquiredFolds =
  [ (SourceTools, "refused:missing acquired source-debt observation for LTD-SRC-001")
  , (SourceDhall, "refused:missing acquired source-debt observation for LTD-SRC-002")
  , (SourceProto, "refused:missing acquired source-debt observation for LTD-SRC-003")
  , (SourceUi, "refused:missing acquired source-debt observation for LTD-SRC-004")
  , (SourcePulumi, "refused:missing acquired source-debt observation for LTD-SRC-005")
  , (SourceTest, "refused:missing acquired source-debt observation for LTD-SRC-006")
  , (SourceProbe, "refused:missing acquired source-debt observation for LTD-SRC-007")
  , (SourcePb, "zero")
  , (SourceVendor, "refused:missing acquired source-debt observation for LTD-SRC-009")
  ]

renderFold :: AcquiredSourceSnapshot -> SourceDebtEvidence -> SourceDebtId -> Text
renderFold acquired evidence identifier =
  foldAcquiredSourceDebtState
    acquired
    evidence
    identifier
    ("refused:" <>)
    "zero"
    (\count fingerprint -> "open:" <> showText count <> ":" <> fingerprint)

acquiredA, acquiredB :: AcquiredSourceSnapshot
acquiredA = sourceClosureInternalTestAcquire (SourceSnapshot "/immutable/a" "snapshot-a" [])
acquiredB = sourceClosureInternalTestAcquire (SourceSnapshot "/immutable/b" "snapshot-b" [])

expectedEmptyAcquired :: CheckResult
expectedEmptyAcquired =
  CheckResult
    { checkName = "source-debt-baseline"
    , checkObservations =
        [ Observation "source-debt.expected-family-count" "8"
        , Observation "source-debt.actual-family-count" "0"
        ]
    , checkFindings =
        [ Finding
            "SOURCE-DEBT-FAMILY-SET-MISMATCH"
            "source-debt-baseline"
            "expected=LTD-SRC-001,LTD-SRC-002,LTD-SRC-003,LTD-SRC-004,LTD-SRC-005,LTD-SRC-006,LTD-SRC-007,LTD-SRC-009, actual="
        ]
    }

expectedMismatchedEvidence :: CheckResult
expectedMismatchedEvidence =
  expectedEmptyAcquired
    { checkFindings =
        checkFindings expectedEmptyAcquired
          <> [ Finding
                 "SOURCE-DEBT-EVIDENCE-SNAPSHOT-MISMATCH"
                 "source-debt-baseline"
                 "expected=snapshot-b, actual=snapshot-a"
             ]
    }

acquiredCheck :: [TrackedEntry] -> CheckResult
acquiredCheck entries =
  let acquired = sourceClosureInternalTestAcquire (SourceSnapshot "/immutable/resource" "resource-snapshot" entries)
   in sourceDebtEvidenceCheck acquired (analyzeAcquiredSourceDebt acquired)

acquiredResourceObservation :: [TrackedEntry] -> (CheckResult, Text)
acquiredResourceObservation entries =
  let acquired = sourceClosureInternalTestAcquire (SourceSnapshot "/immutable/resource" "resource-snapshot" entries)
      evidence = analyzeAcquiredSourceDebt acquired
   in (sourceDebtEvidenceCheck acquired evidence, renderFold acquired evidence SourceTools)

acquiredTraversalExceededEntries :: [TrackedEntry]
acquiredTraversalExceededEntries =
  [ trackedEntry ("documents/traversal-" <> show index <> ".md") validObjectId ""
  | index <- [1 :: Int .. 16385]
  ]

acquiredPathExceededEntry, acquiredObjectExceededEntry, acquiredBlobExceededEntry :: TrackedEntry
acquiredPathExceededEntry = trackedEntry ("tools/" <> replicate 508 '\233' <> ".py") validObjectId "path\n"
acquiredObjectExceededEntry = trackedEntry "tools/object-exceeded.py" (Text.replicate 65 "a") "object\n"
acquiredBlobExceededEntry = trackedEntry "tools/blob-exceeded.py" validObjectId (ByteString.replicate 16777217 120)

acquiredAggregateExceededEntries :: [TrackedEntry]
acquiredAggregateExceededEntries =
  [ trackedEntry "tools/aggregate-a.py" validObjectId (ByteString.replicate 16777216 120)
  , trackedEntry "tools/aggregate-b.py" validObjectId (ByteString.replicate 16777216 121)
  , trackedEntry "tools/aggregate-c.py" validObjectId "z"
  ]

validObjectId :: Text
validObjectId = Text.replicate 40 "a"

trackedEntry :: FilePath -> Text -> ByteString.ByteString -> TrackedEntry
trackedEntry path objectId bytes =
  TrackedEntry
    { trackedIndex = IndexEntry path RegularFile objectId
    , trackedBytes = bytes
    }

acquiredTraversalLimitExpected, acquiredPathLimitExpected, acquiredObjectLimitExpected, acquiredBlobLimitExpected, acquiredAggregateLimitExpected :: CheckResult
acquiredTraversalLimitExpected =
  CheckResult
    { checkName = "source-debt-baseline"
    , checkObservations =
        [ Observation "source-debt.traversal-limit.maximum" "16384"
        , Observation "source-debt.traversal-limit.observed-at-least" "16385"
        ]
    , checkFindings =
        [ Finding
            "SOURCE-DEBT-TRAVERSAL-LIMIT"
            "source-debt-baseline"
            "maximum=16384, observed-at-least=16385"
        ]
    }
acquiredPathLimitExpected = acquiredResourceLimitExpected "path-utf8" "SOURCE-DEBT-PATH-UTF8-LIMIT" "1024" "1025"
acquiredObjectLimitExpected = acquiredResourceLimitExpected "object-id" "SOURCE-DEBT-OBJECT-ID-LIMIT" "64" "65"
acquiredBlobLimitExpected = acquiredResourceLimitExpected "blob" "SOURCE-DEBT-BLOB-LIMIT" "16777216" "16777217"
acquiredAggregateLimitExpected = acquiredResourceLimitExpected "aggregate-blob" "SOURCE-DEBT-AGGREGATE-BLOB-LIMIT" "33554432" "33554433"

acquiredResourceLimitExpected :: Text -> Text -> Text -> Text -> CheckResult
acquiredResourceLimitExpected dimension code maximumValue observedAtLeast =
  CheckResult
    { checkName = "source-debt-baseline"
    , checkObservations =
        [ Observation ("source-debt." <> dimension <> "-limit.maximum") maximumValue
        , Observation ("source-debt." <> dimension <> "-limit.observed-at-least") observedAtLeast
        ]
    , checkFindings =
        [ Finding
            code
            "source-debt-baseline"
            ("maximum=" <> maximumValue <> ", observed-at-least=" <> observedAtLeast)
        ]
    }

expectedProblemFindings :: [Finding]
expectedProblemFindings =
  [ Finding "SOURCE-DEBT-BASELINE-FAMILY-SET-MISMATCH" "source-debt-baseline" "expected=LTD-SRC-001, actual=LTD-SRC-002"
  , Finding "SOURCE-DEBT-FAMILY-SET-MISMATCH" "source-debt-baseline" "expected=LTD-SRC-003, actual=LTD-SRC-004"
  , Finding "SOURCE-DEBT-PB-NOT-ZERO" "LTD-SRC-008" "expected absent/zero, actual count=1, fingerprint=pb-fingerprint"
  , Finding "SOURCE-DEBT-COUNT-MISMATCH" "LTD-SRC-005" "expected=2, actual=3"
  , Finding "SOURCE-DEBT-FINGERPRINT-MISMATCH" "LTD-SRC-006" "expected=expected-fingerprint, actual=actual-fingerprint"
  , Finding "SOURCE-DEBT-PATH-INVENTORY-MISMATCH" "LTD-SRC-009" "expected=expected-path, actual=actual-path"
  ]

expectedIntegrityFindings :: [Finding]
expectedIntegrityFindings =
  [ Finding
      "SOURCE-DEBT-STATE-INVENTORY-MISMATCH"
      "source-debt-baseline"
      "expected=LTD-SRC-001,LTD-SRC-002,LTD-SRC-003,LTD-SRC-004,LTD-SRC-005,LTD-SRC-006,LTD-SRC-007,LTD-SRC-008,LTD-SRC-009, actual=LTD-SRC-001,LTD-SRC-002,LTD-SRC-003,LTD-SRC-004,LTD-SRC-005,LTD-SRC-006,LTD-SRC-007,LTD-SRC-008"
  , Finding
      "SOURCE-DEBT-STATE-ZERO-UNAUTHORIZED"
      "LTD-SRC-001"
      "only the acquired Phase-0-owned pb family may have a zero source-debt lifecycle state"
  ]

expectedStateResults :: [Text]
expectedStateResults =
  [ "open:3:open-fingerprint"
  , "zero"
  , "refused:refused-detail"
  , "zero"
  , "refused:bounded pb source debt is not zero"
  , "refused:missing acquired source-debt observation for LTD-SRC-001"
  , "open:237:669f28af21b8b592018a0d5a4c789aa8b6f561f60a2b772caf1aef35b7199b5f"
  , "refused:source-debt baseline mismatch for LTD-SRC-001"
  , "refused:source-debt baseline mismatch for LTD-SRC-001"
  , "refused:source-debt baseline mismatch for LTD-SRC-001"
  , "refused:source-debt analysis exceeded a closed result bound"
  , "refused:source-debt analysis exceeded a closed result bound"
  ]

mutationIntent :: [(String, String)]
mutationIntent =
  [ ("VALIDATION_SOURCE_DEBT_EVIDENCE_MATCH_PREDICATE_MUTANT", evidenceCase)
  , ("VALIDATION_SOURCE_DEBT_EVIDENCE_MISMATCH_CODE_MUTANT", evidenceCase)
  , ("VALIDATION_SOURCE_DEBT_EVIDENCE_MISMATCH_COMPOSITION_MUTANT", evidenceCase)
  , ("VALIDATION_SOURCE_DEBT_EVIDENCE_MISMATCH_DETAIL_MUTANT", evidenceCase)
  , ("VALIDATION_SOURCE_DEBT_EVIDENCE_MISMATCH_SUBJECT_MUTANT", evidenceCase)
  , ("VALIDATION_SOURCE_DEBT_EVIDENCE_RESULT_ASSEMBLY_MUTANT", evidenceCase)
  , ("VALIDATION_SOURCE_DEBT_EVIDENCE_STATE_ASSEMBLY_MUTANT", evidenceCase)
  , ("VALIDATION_SOURCE_DEBT_STATE_FOLD_SNAPSHOT_PREDICATE_MUTANT", evidenceCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_FAMILY_FINDING_CODE_MUTANT", problemCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_FAMILY_FINDING_DETAIL_MUTANT", problemCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_FAMILY_FINDING_SUBJECT_MUTANT", problemCase)
  , ("VALIDATION_SOURCE_DEBT_COUNT_FINDING_CODE_MUTANT", problemCase)
  , ("VALIDATION_SOURCE_DEBT_COUNT_FINDING_DETAIL_MUTANT", problemCase)
  , ("VALIDATION_SOURCE_DEBT_COUNT_FINDING_SUBJECT_MUTANT", problemCase)
  , ("VALIDATION_SOURCE_DEBT_FAMILY_FINDING_CODE_MUTANT", problemCase)
  , ("VALIDATION_SOURCE_DEBT_FAMILY_FINDING_DETAIL_MUTANT", problemCase)
  , ("VALIDATION_SOURCE_DEBT_FAMILY_FINDING_SUBJECT_MUTANT", problemCase)
  , ("VALIDATION_SOURCE_DEBT_FINGERPRINT_FINDING_CODE_MUTANT", problemCase)
  , ("VALIDATION_SOURCE_DEBT_FINGERPRINT_FINDING_DETAIL_MUTANT", problemCase)
  , ("VALIDATION_SOURCE_DEBT_FINGERPRINT_FINDING_SUBJECT_MUTANT", problemCase)
  , ("VALIDATION_SOURCE_DEBT_PATH_FINDING_CODE_MUTANT", problemCase)
  , ("VALIDATION_SOURCE_DEBT_PATH_FINDING_DETAIL_MUTANT", problemCase)
  , ("VALIDATION_SOURCE_DEBT_PATH_FINDING_SUBJECT_MUTANT", problemCase)
  , ("VALIDATION_SOURCE_DEBT_PB_FINDING_CODE_MUTANT", problemCase)
  , ("VALIDATION_SOURCE_DEBT_PB_FINDING_DETAIL_MUTANT", problemCase)
  , ("VALIDATION_SOURCE_DEBT_PB_FINDING_SUBJECT_MUTANT", problemCase)
  , ("VALIDATION_SOURCE_DEBT_STATE_INVENTORY_CODE_MUTANT", integrityCase)
  , ("VALIDATION_SOURCE_DEBT_STATE_INVENTORY_DETAIL_MUTANT", integrityCase)
  , ("VALIDATION_SOURCE_DEBT_STATE_INVENTORY_SUBJECT_MUTANT", integrityCase)
  , ("VALIDATION_SOURCE_DEBT_STATE_ZERO_CODE_MUTANT", integrityCase)
  , ("VALIDATION_SOURCE_DEBT_STATE_ZERO_DETAIL_MUTANT", integrityCase)
  , ("VALIDATION_SOURCE_DEBT_STATE_ZERO_SUBJECT_MUTANT", integrityCase)
  , ("VALIDATION_SOURCE_DEBT_STATE_BASELINE_ID_PROJECTION_MUTANT", stateCase)
  , ("VALIDATION_SOURCE_DEBT_STATE_FOLD_OPEN_COUNT_MUTANT", stateCase)
  , ("VALIDATION_SOURCE_DEBT_STATE_FOLD_OPEN_FINGERPRINT_MUTANT", stateCase)
  , ("VALIDATION_SOURCE_DEBT_STATE_FOLD_OPEN_ROUTE_MUTANT", stateCase)
  , ("VALIDATION_SOURCE_DEBT_STATE_FOLD_REFUSED_DETAIL_MUTANT", stateCase)
  , ("VALIDATION_SOURCE_DEBT_STATE_FOLD_REFUSED_ROUTE_MUTANT", stateCase)
  , ("VALIDATION_SOURCE_DEBT_STATE_FOLD_ZERO_ROUTE_MUTANT", stateCase)
  , ("VALIDATION_SOURCE_DEBT_STATE_INVENTORY_ID_PROJECTION_MUTANT", evidenceCase)
  , ("VALIDATION_SOURCE_DEBT_STATE_MISMATCH_DETAIL_MUTANT", stateCase)
  , ("VALIDATION_SOURCE_DEBT_STATE_MISSING_OBSERVATION_DETAIL_MUTANT", stateCase)
  , ("VALIDATION_SOURCE_DEBT_STATE_OBSERVATION_ID_PROJECTION_MUTANT", stateCase)
  , ("VALIDATION_SOURCE_DEBT_STATE_OPEN_COUNT_PROJECTION_MUTANT", stateCase)
  , ("VALIDATION_SOURCE_DEBT_STATE_OPEN_FINGERPRINT_PROJECTION_MUTANT", stateCase)
  , ("VALIDATION_SOURCE_DEBT_STATE_PB_REFUSED_DETAIL_MUTANT", stateCase)
  , ("VALIDATION_SOURCE_DEBT_PREPARED_AGGREGATE_RESOURCE_PREDICATE_MUTANT", aggregateResourceCase)
  , ("VALIDATION_SOURCE_DEBT_PREPARED_AGGREGATE_RESOURCE_TRANSITION_MUTANT", aggregateResourceCase)
  , ("VALIDATION_SOURCE_DEBT_PREPARED_BLOB_RESOURCE_PREDICATE_MUTANT", blobResourceCase)
  , ("VALIDATION_SOURCE_DEBT_PREPARED_BLOB_RESOURCE_PROJECTION_MUTANT", blobResourceCase)
  , ("VALIDATION_SOURCE_DEBT_PREPARED_OBJECT_ID_RESOURCE_PREDICATE_MUTANT", objectResourceCase)
  , ("VALIDATION_SOURCE_DEBT_PREPARED_OBJECT_ID_RESOURCE_PROJECTION_MUTANT", objectResourceCase)
  , ("VALIDATION_SOURCE_DEBT_PREPARED_PATH_RESOURCE_PREDICATE_MUTANT", pathResourceCase)
  , ("VALIDATION_SOURCE_DEBT_PREPARED_PATH_RESOURCE_PROJECTION_MUTANT", pathResourceCase)
  , ("VALIDATION_SOURCE_DEBT_ANALYSIS_RESOURCE_RESULT_ROUTE_MUTANT", pathResourceCase)
  , ("VALIDATION_SOURCE_DEBT_ANALYSIS_TRAVERSAL_RESULT_ROUTE_MUTANT", traversalCase)
  , ("VALIDATION_SOURCE_DEBT_REFUSED_STATE_DETAIL_PROJECTION_MUTANT", pathResourceCase)
  , ("VALIDATION_SOURCE_DEBT_REFUSED_STATE_ID_PROJECTION_MUTANT", pathResourceCase)
  , ("VALIDATION_SOURCE_DEBT_STATE_COUNT_MATCH_COMPOSITION_MUTANT", stateCase)
  , ("VALIDATION_SOURCE_DEBT_STATE_FINGERPRINT_MATCH_COMPOSITION_MUTANT", stateCase)
  , ("VALIDATION_SOURCE_DEBT_STATE_INTEGRITY_ORDER_MUTANT", integrityCase)
  , ("VALIDATION_SOURCE_DEBT_STATE_PATH_MATCH_COMPOSITION_MUTANT", stateCase)
  , ("VALIDATION_SOURCE_DEBT_ALL_ID_TOOLS_OMISSION_MUTANT", evidenceCase)
  , ("VALIDATION_SOURCE_DEBT_ALL_ID_DHALL_OMISSION_MUTANT", evidenceCase)
  , ("VALIDATION_SOURCE_DEBT_ALL_ID_PROTO_OMISSION_MUTANT", evidenceCase)
  , ("VALIDATION_SOURCE_DEBT_ALL_ID_UI_OMISSION_MUTANT", evidenceCase)
  , ("VALIDATION_SOURCE_DEBT_ALL_ID_PULUMI_OMISSION_MUTANT", evidenceCase)
  , ("VALIDATION_SOURCE_DEBT_ALL_ID_TEST_OMISSION_MUTANT", evidenceCase)
  , ("VALIDATION_SOURCE_DEBT_ALL_ID_PROBE_OMISSION_MUTANT", evidenceCase)
  , ("VALIDATION_SOURCE_DEBT_ALL_ID_PB_OMISSION_MUTANT", evidenceCase)
  , ("VALIDATION_SOURCE_DEBT_ALL_ID_VENDOR_OMISSION_MUTANT", evidenceCase)
  , ("VALIDATION_SOURCE_DEBT_STATE_OBSERVATION_BOUND_PREDICATE_MUTANT", stateCase)
  , ("VALIDATION_SOURCE_DEBT_STATE_PROBLEM_BOUND_PREDICATE_MUTANT", stateCase)
  ]
 where
  evidenceCase = "acquired evidence and snapshot binding are exact"
  problemCase = "private problem serializers are exact"
  integrityCase = "state-integrity serializers are exact"
  stateCase = "private lifecycle construction and fold are exact"
  pathResourceCase = "acquired path resource refusal is exact"
  objectResourceCase = "acquired object resource refusal is exact"
  blobResourceCase = "acquired blob resource refusal is exact"
  aggregateResourceCase = "acquired aggregate resource refusal is exact"
  traversalCase = "acquired traversal refusal is exact"

intentProblems :: [String]
intentProblems =
  ["expected 73 internal mutation-intent rows, observed " <> show (length mutationIntent)
  | length mutationIntent /= 73]
    <> ["duplicate internal mutation-intent selector " <> selector
       | selector : _ : _ <- group (sort (map fst mutationIntent))]
    <> ["internal mutation-intent target is not exact: " <> selector <> " -> " <> target
       | (selector, target) <- mutationIntent
       , length (filter (== target) sourceDebtBaselineInternalExactCaseLabels) /= 1]

mutationImpact :: [(String, [String])]
mutationImpact =
  [ ("VALIDATION_SOURCE_DEBT_EVIDENCE_MATCH_PREDICATE_MUTANT", ["acquired evidence and snapshot binding are exact", "acquired traversal refusal is exact", "acquired path resource refusal is exact", "acquired object resource refusal is exact", "acquired blob resource refusal is exact", "acquired aggregate resource refusal is exact"])
  , ("VALIDATION_SOURCE_DEBT_EVIDENCE_MISMATCH_CODE_MUTANT", ["acquired evidence and snapshot binding are exact"])
  , ("VALIDATION_SOURCE_DEBT_EVIDENCE_MISMATCH_COMPOSITION_MUTANT", ["acquired evidence and snapshot binding are exact"])
  , ("VALIDATION_SOURCE_DEBT_EVIDENCE_MISMATCH_DETAIL_MUTANT", ["acquired evidence and snapshot binding are exact"])
  , ("VALIDATION_SOURCE_DEBT_EVIDENCE_MISMATCH_SUBJECT_MUTANT", ["acquired evidence and snapshot binding are exact"])
  , ("VALIDATION_SOURCE_DEBT_EVIDENCE_RESULT_ASSEMBLY_MUTANT", ["acquired evidence and snapshot binding are exact", "acquired traversal refusal is exact", "acquired path resource refusal is exact", "acquired object resource refusal is exact", "acquired blob resource refusal is exact", "acquired aggregate resource refusal is exact"])
  , ("VALIDATION_SOURCE_DEBT_EVIDENCE_STATE_ASSEMBLY_MUTANT", ["acquired evidence and snapshot binding are exact", "acquired path resource refusal is exact", "acquired object resource refusal is exact", "acquired blob resource refusal is exact", "acquired aggregate resource refusal is exact"])
  , ("VALIDATION_SOURCE_DEBT_STATE_FOLD_SNAPSHOT_PREDICATE_MUTANT", ["acquired evidence and snapshot binding are exact", "acquired path resource refusal is exact", "acquired object resource refusal is exact", "acquired blob resource refusal is exact", "acquired aggregate resource refusal is exact"])
  , ("VALIDATION_SOURCE_DEBT_BASELINE_FAMILY_FINDING_CODE_MUTANT", ["private problem serializers are exact"])
  , ("VALIDATION_SOURCE_DEBT_BASELINE_FAMILY_FINDING_DETAIL_MUTANT", ["private problem serializers are exact"])
  , ("VALIDATION_SOURCE_DEBT_BASELINE_FAMILY_FINDING_SUBJECT_MUTANT", ["private problem serializers are exact"])
  , ("VALIDATION_SOURCE_DEBT_COUNT_FINDING_CODE_MUTANT", ["private problem serializers are exact"])
  , ("VALIDATION_SOURCE_DEBT_COUNT_FINDING_DETAIL_MUTANT", ["private problem serializers are exact"])
  , ("VALIDATION_SOURCE_DEBT_COUNT_FINDING_SUBJECT_MUTANT", ["private problem serializers are exact"])
  , ("VALIDATION_SOURCE_DEBT_FAMILY_FINDING_CODE_MUTANT", ["acquired evidence and snapshot binding are exact", "private problem serializers are exact"])
  , ("VALIDATION_SOURCE_DEBT_FAMILY_FINDING_DETAIL_MUTANT", ["acquired evidence and snapshot binding are exact", "private problem serializers are exact"])
  , ("VALIDATION_SOURCE_DEBT_FAMILY_FINDING_SUBJECT_MUTANT", ["acquired evidence and snapshot binding are exact", "private problem serializers are exact"])
  , ("VALIDATION_SOURCE_DEBT_FINGERPRINT_FINDING_CODE_MUTANT", ["private problem serializers are exact"])
  , ("VALIDATION_SOURCE_DEBT_FINGERPRINT_FINDING_DETAIL_MUTANT", ["private problem serializers are exact"])
  , ("VALIDATION_SOURCE_DEBT_FINGERPRINT_FINDING_SUBJECT_MUTANT", ["private problem serializers are exact"])
  , ("VALIDATION_SOURCE_DEBT_PATH_FINDING_CODE_MUTANT", ["private problem serializers are exact"])
  , ("VALIDATION_SOURCE_DEBT_PATH_FINDING_DETAIL_MUTANT", ["private problem serializers are exact"])
  , ("VALIDATION_SOURCE_DEBT_PATH_FINDING_SUBJECT_MUTANT", ["private problem serializers are exact"])
  , ("VALIDATION_SOURCE_DEBT_PB_FINDING_CODE_MUTANT", ["private problem serializers are exact"])
  , ("VALIDATION_SOURCE_DEBT_PB_FINDING_DETAIL_MUTANT", ["private problem serializers are exact"])
  , ("VALIDATION_SOURCE_DEBT_PB_FINDING_SUBJECT_MUTANT", ["private problem serializers are exact"])
  , ("VALIDATION_SOURCE_DEBT_STATE_INVENTORY_CODE_MUTANT", ["state-integrity serializers are exact"])
  , ("VALIDATION_SOURCE_DEBT_STATE_INVENTORY_DETAIL_MUTANT", ["state-integrity serializers are exact"])
  , ("VALIDATION_SOURCE_DEBT_STATE_INVENTORY_SUBJECT_MUTANT", ["state-integrity serializers are exact"])
  , ("VALIDATION_SOURCE_DEBT_STATE_ZERO_CODE_MUTANT", ["state-integrity serializers are exact"])
  , ("VALIDATION_SOURCE_DEBT_STATE_ZERO_DETAIL_MUTANT", ["state-integrity serializers are exact"])
  , ("VALIDATION_SOURCE_DEBT_STATE_ZERO_SUBJECT_MUTANT", ["state-integrity serializers are exact"])
  , ("VALIDATION_SOURCE_DEBT_STATE_BASELINE_ID_PROJECTION_MUTANT", ["acquired evidence and snapshot binding are exact", "private lifecycle construction and fold are exact"])
  , ("VALIDATION_SOURCE_DEBT_STATE_FOLD_OPEN_COUNT_MUTANT", ["private lifecycle construction and fold are exact"])
  , ("VALIDATION_SOURCE_DEBT_STATE_FOLD_OPEN_FINGERPRINT_MUTANT", ["private lifecycle construction and fold are exact"])
  , ("VALIDATION_SOURCE_DEBT_STATE_FOLD_OPEN_ROUTE_MUTANT", ["private lifecycle construction and fold are exact"])
  , ("VALIDATION_SOURCE_DEBT_STATE_FOLD_REFUSED_DETAIL_MUTANT", ["acquired evidence and snapshot binding are exact", "acquired path resource refusal is exact", "acquired object resource refusal is exact", "acquired blob resource refusal is exact", "acquired aggregate resource refusal is exact", "private lifecycle construction and fold are exact"])
  , ("VALIDATION_SOURCE_DEBT_STATE_FOLD_REFUSED_ROUTE_MUTANT", ["acquired evidence and snapshot binding are exact", "acquired path resource refusal is exact", "acquired object resource refusal is exact", "acquired blob resource refusal is exact", "acquired aggregate resource refusal is exact", "private lifecycle construction and fold are exact"])
  , ("VALIDATION_SOURCE_DEBT_STATE_FOLD_ZERO_ROUTE_MUTANT", ["acquired evidence and snapshot binding are exact", "private lifecycle construction and fold are exact"])
  , ("VALIDATION_SOURCE_DEBT_STATE_INVENTORY_ID_PROJECTION_MUTANT", ["acquired evidence and snapshot binding are exact"])
  , ("VALIDATION_SOURCE_DEBT_STATE_MISMATCH_DETAIL_MUTANT", ["private lifecycle construction and fold are exact"])
  , ("VALIDATION_SOURCE_DEBT_STATE_MISSING_OBSERVATION_DETAIL_MUTANT", ["acquired evidence and snapshot binding are exact", "private lifecycle construction and fold are exact"])
  , ("VALIDATION_SOURCE_DEBT_STATE_OBSERVATION_ID_PROJECTION_MUTANT", ["private lifecycle construction and fold are exact"])
  , ("VALIDATION_SOURCE_DEBT_STATE_OPEN_COUNT_PROJECTION_MUTANT", ["private lifecycle construction and fold are exact"])
  , ("VALIDATION_SOURCE_DEBT_STATE_OPEN_FINGERPRINT_PROJECTION_MUTANT", ["private lifecycle construction and fold are exact"])
  , ("VALIDATION_SOURCE_DEBT_STATE_PB_REFUSED_DETAIL_MUTANT", ["private lifecycle construction and fold are exact"])
  , ("VALIDATION_SOURCE_DEBT_PREPARED_AGGREGATE_RESOURCE_PREDICATE_MUTANT", ["acquired aggregate resource refusal is exact"])
  , ("VALIDATION_SOURCE_DEBT_PREPARED_AGGREGATE_RESOURCE_TRANSITION_MUTANT", ["acquired aggregate resource refusal is exact"])
  , ("VALIDATION_SOURCE_DEBT_PREPARED_BLOB_RESOURCE_PREDICATE_MUTANT", ["acquired blob resource refusal is exact"])
  , ("VALIDATION_SOURCE_DEBT_PREPARED_BLOB_RESOURCE_PROJECTION_MUTANT", ["acquired blob resource refusal is exact", "acquired aggregate resource refusal is exact"])
  , ("VALIDATION_SOURCE_DEBT_PREPARED_OBJECT_ID_RESOURCE_PREDICATE_MUTANT", ["acquired object resource refusal is exact"])
  , ("VALIDATION_SOURCE_DEBT_PREPARED_OBJECT_ID_RESOURCE_PROJECTION_MUTANT", ["acquired object resource refusal is exact"])
  , ("VALIDATION_SOURCE_DEBT_PREPARED_PATH_RESOURCE_PREDICATE_MUTANT", ["acquired path resource refusal is exact"])
  , ("VALIDATION_SOURCE_DEBT_PREPARED_PATH_RESOURCE_PROJECTION_MUTANT", ["acquired path resource refusal is exact"])
  , ("VALIDATION_SOURCE_DEBT_ANALYSIS_RESOURCE_RESULT_ROUTE_MUTANT", ["acquired path resource refusal is exact", "acquired object resource refusal is exact", "acquired blob resource refusal is exact", "acquired aggregate resource refusal is exact"])
  , ("VALIDATION_SOURCE_DEBT_ANALYSIS_TRAVERSAL_RESULT_ROUTE_MUTANT", ["acquired traversal refusal is exact"])
  , ("VALIDATION_SOURCE_DEBT_REFUSED_STATE_DETAIL_PROJECTION_MUTANT", ["acquired path resource refusal is exact", "acquired object resource refusal is exact", "acquired blob resource refusal is exact", "acquired aggregate resource refusal is exact", "private lifecycle construction and fold are exact"])
  , ("VALIDATION_SOURCE_DEBT_REFUSED_STATE_ID_PROJECTION_MUTANT", ["acquired path resource refusal is exact", "acquired object resource refusal is exact", "acquired blob resource refusal is exact", "acquired aggregate resource refusal is exact"])
  , ("VALIDATION_SOURCE_DEBT_STATE_COUNT_MATCH_COMPOSITION_MUTANT", ["private lifecycle construction and fold are exact"])
  , ("VALIDATION_SOURCE_DEBT_STATE_FINGERPRINT_MATCH_COMPOSITION_MUTANT", ["private lifecycle construction and fold are exact"])
  , ("VALIDATION_SOURCE_DEBT_STATE_INTEGRITY_ORDER_MUTANT", ["state-integrity serializers are exact"])
  , ("VALIDATION_SOURCE_DEBT_STATE_PATH_MATCH_COMPOSITION_MUTANT", ["private lifecycle construction and fold are exact"])
  , ("VALIDATION_SOURCE_DEBT_ALL_ID_TOOLS_OMISSION_MUTANT", ["acquired evidence and snapshot binding are exact", "acquired path resource refusal is exact", "acquired object resource refusal is exact", "acquired blob resource refusal is exact", "acquired aggregate resource refusal is exact", "state-integrity serializers are exact"])
  , ("VALIDATION_SOURCE_DEBT_ALL_ID_DHALL_OMISSION_MUTANT", allLaterIdOmissionImpact)
  , ("VALIDATION_SOURCE_DEBT_ALL_ID_PROTO_OMISSION_MUTANT", allLaterIdOmissionImpact)
  , ("VALIDATION_SOURCE_DEBT_ALL_ID_UI_OMISSION_MUTANT", allLaterIdOmissionImpact)
  , ("VALIDATION_SOURCE_DEBT_ALL_ID_PULUMI_OMISSION_MUTANT", allLaterIdOmissionImpact)
  , ("VALIDATION_SOURCE_DEBT_ALL_ID_TEST_OMISSION_MUTANT", allLaterIdOmissionImpact)
  , ("VALIDATION_SOURCE_DEBT_ALL_ID_PROBE_OMISSION_MUTANT", allLaterIdOmissionImpact)
  , ("VALIDATION_SOURCE_DEBT_ALL_ID_PB_OMISSION_MUTANT", ["acquired evidence and snapshot binding are exact", "state-integrity serializers are exact", "private lifecycle construction and fold are exact"])
  , ("VALIDATION_SOURCE_DEBT_ALL_ID_VENDOR_OMISSION_MUTANT", allLaterIdOmissionImpact)
  , ("VALIDATION_SOURCE_DEBT_STATE_OBSERVATION_BOUND_PREDICATE_MUTANT", ["private lifecycle construction and fold are exact"])
  , ("VALIDATION_SOURCE_DEBT_STATE_PROBLEM_BOUND_PREDICATE_MUTANT", ["private lifecycle construction and fold are exact"])
  ]
 where
  allLaterIdOmissionImpact =
    [ "acquired evidence and snapshot binding are exact"
    , "state-integrity serializers are exact"
    ]

impactProblems :: [String]
impactProblems =
  ["expected 73 internal mutation-impact rows, observed " <> show (length mutationImpact)
  | length mutationImpact /= 73]
    <> ["duplicate internal mutation-impact selector " <> selector
       | selector : _ : _ <- group (sort (map fst mutationImpact))]
    <> ["internal mutation-impact selector is absent from intent registry: " <> selector
       | (selector, _) <- mutationImpact
       , selector `notElem` sourceDebtBaselineInternalSelectorNames]
    <> ["internal mutation-impact registry is missing intent selector: " <> selector
       | selector <- sourceDebtBaselineInternalSelectorNames
       , selector `notElem` map fst mutationImpact]
    <> ["internal mutation-impact signature is empty: " <> selector
       | (selector, labels) <- mutationImpact
       , null labels]
    <> ["internal mutation-impact label is not exact: " <> selector <> " -> " <> label
       | (selector, labels) <- mutationImpact
       , label <- labels
       , label `notElem` sourceDebtBaselineInternalExactCaseLabels]

showText :: Show value => value -> Text
showText = Text.pack . show

expectExact :: (Eq value, Show value) => String -> value -> value -> [String]
expectExact label expected actual
  | expected == actual = []
  | otherwise = [label <> ": expected " <> show expected <> ", got " <> show actual]

expectNoProblems :: String -> [String] -> [String]
expectNoProblems _ [] = []
expectNoProblems label problems = [label <> ": expected no problems, got " <> show problems]

finishDiagnostics :: String -> [String] -> IO ()
finishDiagnostics name problems =
  unless (null problems) (ioError (userError (unlines ((name <> " failed:") : map ("- " <>) problems))))
