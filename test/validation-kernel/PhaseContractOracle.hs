{-# LANGUAGE OverloadedStrings #-}

module PhaseContractOracle
  ( phaseContractExactCaseNames
  , phaseContractValidCorpus
  , phaseContractSelectorMatrixRows
  , phaseContractSelectorNames
  , runPhaseContractExactCase
  , runPhaseContractOracle
  , runPhaseContractSelectorOracle
  , runPhaseContractUnaffectedControl
  ) where

-- Component diagnostics only.  This oracle does not perform reviewer inspection,
-- qualify the phase-contract harness, validate a phase, or promote status.

import Amoebius.Validation.PhaseContract (phaseContractDiagnostic)
import Amoebius.Validation.Types (CheckResult (..), Finding (..), Observation (..))
import Control.Monad (unless)
import Data.Maybe (listToMaybe)
import Data.Text (Text)
import qualified Data.Text as Text

-- This selector registry is an oracle-owned literal. Production CPP is never
-- used to enumerate matrix work. Each row names every exact case the selected
-- production change is allowed to affect and one unrelated product control.
phaseContractSelectorMatrixRows :: [(String, [String], String)]
phaseContractSelectorMatrixRows =
  [ ("VALIDATION_PHASE_CONTRACT_CHECK_NAME_BYPASS_MUTANT", ["check-name"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_COMMENT_OPACITY_BYPASS_MUTANT", ["tracker-comment-opacity"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_COMMENT_SPLICE_BYPASS_MUTANT", ["tracker-comment-splice"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_CONTAINER_PREFIX_BYPASS_MUTANT", ["tracker-container-prefix"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_DEPENDENCY_FORWARD_FINDING_BYPASS_MUTANT", ["dependency-forward"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_DEPENDENCY_GENESIS_FINDING_BYPASS_MUTANT", ["dependency-genesis"], "input-entry-limit")
  , ( "VALIDATION_PHASE_CONTRACT_DEPENDENCY_LINK_FINDING_BYPASS_MUTANT"
    , ["dependency-link-finding", "dependency-link-label", "dependency-link-prose"]
    , "input-entry-limit"
    )
  , ("VALIDATION_PHASE_CONTRACT_DEPENDENCY_LINK_LABEL_BYPASS_MUTANT", ["dependency-link-label"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_DEPENDENCY_LINK_PROSE_BYPASS_MUTANT", ["dependency-link-prose", "dependency-link-label"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_DEPENDENCY_PREDECESSOR_FINDING_BYPASS_MUTANT", ["dependency-predecessor"], "input-entry-limit")
  , ( "VALIDATION_PHASE_CONTRACT_DEPENDENCY_RESULT_COMPOSITION_BYPASS_MUTANT"
    , [ "dependency-result-composition"
      , "dependency-forward"
      , "dependency-genesis"
      , "dependency-link-finding"
      , "dependency-link-label"
      , "dependency-link-prose"
      , "dependency-predecessor"
      ]
    , "input-entry-limit"
    )
  , ("VALIDATION_PHASE_CONTRACT_FENCE_BOUNDARY_BYPASS_MUTANT", ["tracker-fence-boundary"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_FENCE_OPACITY_BYPASS_MUTANT", ["tracker-fence-opacity"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_GATE_COMMAND_COUNT_BYPASS_MUTANT", ["gate-command-count"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_GATE_COMMAND_FINDING_BYPASS_MUTANT", ["gate-command", "gate-command-count", "inline-code-width"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_GATE_DELIMITER_SHAPE_BYPASS_MUTANT", ["gate-delimiter-shape"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_GATE_END_CONTENT_BYPASS_MUTANT", ["gate-end-content"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_GATE_HEADER_WILDCARD_BYPASS_MUTANT", ["gate-header-wildcard"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_GATE_INCOMPLETE_ROWS_FINDING_BYPASS_MUTANT", ["gate-incomplete-rows"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_GATE_IGNORED_ROW_BYPASS_MUTANT", ["gate-ignored-row"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_GATE_KEY_CODE_BYPASS_MUTANT", ["gate-key-code"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_GATE_MISSING_DELIMITER_FINDING_BYPASS_MUTANT", ["gate-missing-delimiter"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_GATE_MISSING_HEADER_FINDING_BYPASS_MUTANT", ["gate-missing-header"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_GATE_OUTSIDE_ROW_BYPASS_MUTANT", ["gate-outside-row", "gate-table-frame"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_GATE_REFUSAL_BYPASS_MUTANT", ["unresolved-gate-cell"], "input-entry-limit")
  , ( "VALIDATION_PHASE_CONTRACT_GATE_RESULT_COMPOSITION_BYPASS_MUTANT"
    , [ "gate-result-composition"
      , "gate-command"
      , "gate-command-count"
      , "gate-delimiter-shape"
      , "gate-end-content"
      , "gate-header-wildcard"
      , "gate-ignored-row"
      , "gate-incomplete-rows"
      , "gate-key-code"
      , "gate-missing-delimiter"
      , "gate-missing-header"
      , "gate-outside-row"
      , "gate-row-arity"
      , "gate-row-empty"
      , "gate-second-header"
      , "gate-shape"
      , "gate-summary-command"
      , "gate-summary-raw-line-count"
      , "gate-summary-value"
      , "gate-table-frame"
      , "gate-unframed-row"
      , "inline-code-width"
      , "table-closing-pipe"
      , "table-opening-pipe"
      , "unresolved-gate-cell"
      ]
    , "input-entry-limit"
    )
  , ("VALIDATION_PHASE_CONTRACT_GATE_ROW_COUNT_OBSERVATION_BYPASS_MUTANT", ["gate-row-count-observation"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_GATE_ROW_ARITY_BYPASS_MUTANT", ["gate-row-arity"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_GATE_ROW_EMPTY_BYPASS_MUTANT", ["gate-row-empty"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_GATE_SECTION_FINDING_BYPASS_MUTANT", ["gate-section"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_GATE_SECOND_HEADER_BYPASS_MUTANT", ["gate-second-header"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_GATE_SHAPE_FINDING_BYPASS_MUTANT", ["gate-shape"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_GATE_SUMMARY_COMMAND_FINDING_BYPASS_MUTANT", ["gate-summary-command", "gate-summary-raw-line-count", "gate-summary-value"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_GATE_SUMMARY_RAW_LINE_COUNT_BYPASS_MUTANT", ["gate-summary-raw-line-count"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_GATE_SUMMARY_VALUE_BYPASS_MUTANT", ["gate-summary-value"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_GATE_UNFRAMED_ROW_BYPASS_MUTANT", ["gate-unframed-row"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_INDENTED_CODE_BYPASS_MUTANT", ["tracker-indented-code", "gate-section"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_INLINE_CODE_WIDTH_BYPASS_MUTANT", ["inline-code-width"], "input-entry-limit")
  , ( "VALIDATION_PHASE_CONTRACT_INPUT_DOCUMENT_LIMIT_BYPASS_MUTANT"
    , ["input-document-limit", "input-document-limit-observation"]
    , "input-total-limit"
    )
  , ( "VALIDATION_PHASE_CONTRACT_INPUT_ENTRY_LIMIT_BYPASS_MUTANT"
    , ["input-entry-limit", "input-envelope-observation", "input-entry-limit-observation"]
    , "input-path-limit"
    )
  , ( "VALIDATION_PHASE_CONTRACT_INPUT_ENVELOPE_FINDING_COMPOSITION_BYPASS_MUTANT"
    , [ "input-envelope-finding-composition"
      , "input-document-limit"
      , "input-entry-limit"
      , "input-path-limit"
      , "input-total-limit"
      ]
    , "phase-status"
    )
  , ( "VALIDATION_PHASE_CONTRACT_INPUT_ENVELOPE_OBSERVATION_BYPASS_MUTANT"
    , ["input-envelope-observation", "input-document-limit", "input-entry-limit", "input-path-limit", "input-total-limit"]
    , "phase-status"
    )
  , ( "VALIDATION_PHASE_CONTRACT_INPUT_ENVELOPE_OBSERVATION_COMPOSITION_BYPASS_MUTANT"
    , [ "input-envelope-observation-composition"
      , "input-document-limit"
      , "input-document-limit-observation"
      , "input-envelope-observation"
      , "input-entry-limit"
      , "input-entry-limit-observation"
      , "input-path-limit"
      , "input-path-limit-observation"
      , "input-total-limit"
      , "input-total-limit-observation"
      ]
    , "phase-status"
    )
  , ("VALIDATION_PHASE_CONTRACT_INPUT_DOCUMENT_LIMIT_OBSERVATION_BYPASS_MUTANT", ["input-document-limit-observation"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_INPUT_ENTRY_LIMIT_OBSERVATION_BYPASS_MUTANT", ["input-entry-limit-observation"], "input-path-limit")
  , ( "VALIDATION_PHASE_CONTRACT_INPUT_PATH_LIMIT_BYPASS_MUTANT"
    , ["input-path-limit", "input-path-limit-observation"]
    , "input-document-limit"
    )
  , ("VALIDATION_PHASE_CONTRACT_INPUT_PATH_LIMIT_OBSERVATION_BYPASS_MUTANT", ["input-path-limit-observation"], "input-document-limit")
  , ( "VALIDATION_PHASE_CONTRACT_INPUT_TOTAL_LIMIT_BYPASS_MUTANT"
    , ["input-total-limit", "input-total-limit-observation"]
    , "input-entry-limit"
    )
  , ("VALIDATION_PHASE_CONTRACT_INPUT_TOTAL_LIMIT_OBSERVATION_BYPASS_MUTANT", ["input-total-limit-observation"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_LINK_TARGET_CHARACTER_BYPASS_MUTANT", ["link-target-character"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_LINK_TARGET_EMPTY_BYPASS_MUTANT", ["link-target-empty"], "input-entry-limit")
  , ( "VALIDATION_PHASE_CONTRACT_LINK_TRAILING_CONTENT_BYPASS_MUTANT"
    , ["link-trailing-content", "dependency-link-prose"]
    , "input-entry-limit"
    )
  , ("VALIDATION_PHASE_CONTRACT_MISSING_MARKER_COUNT_OBSERVATION_BYPASS_MUTANT", ["missing-marker-count-observation"], "input-entry-limit")
  , ( "VALIDATION_PHASE_CONTRACT_OBSERVATION_RESULT_COMPOSITION_BYPASS_MUTANT"
    , [ "observation-result-composition"
      , "gate-row-count-observation"
      , "missing-marker-count-observation"
      , "phase-document-count-observation"
      , "refusal-marker-count-observation"
      , "sprint-section-count-observation"
      , "tracker-row-count-observation"
      , "unresolved-marker-count-observation"
      ]
    , "input-entry-limit"
    )
  , ("VALIDATION_PHASE_CONTRACT_PHASE_DOCUMENT_COUNT_OBSERVATION_BYPASS_MUTANT", ["phase-document-count-observation"], "input-entry-limit")
  , ( "VALIDATION_PHASE_CONTRACT_PHASE_DOMAIN_RESULT_COMPOSITION_BYPASS_MUTANT"
    , [ "phase-domain-result-composition"
      , "phase-discovery"
      , "phase-duplicate"
      , "phase-extra"
      , "phase-missing"
      , "phase-path-digit-width"
      , "phase-path-directory"
      , "phase-path-extension"
      , "phase-path-prefix"
      , "phase-path-separator"
      , "phase-path-slug-character"
      , "phase-path-slug-empty"
      , "phase-path-slug-segment"
      ]
    , "input-entry-limit"
    )
  , ("VALIDATION_PHASE_CONTRACT_PROJECTION_VOCABULARY_BYPASS_MUTANT", ["projection-vocabulary", "projection-result-composition"], "input-entry-limit")
  , ( "VALIDATION_PHASE_CONTRACT_PHASE_DISCOVERY_FINDING_BYPASS_MUTANT"
    , [ "phase-discovery"
      , "phase-path-digit-width"
      , "phase-path-directory"
      , "phase-path-extension"
      , "phase-path-prefix"
      , "phase-path-separator"
      , "phase-path-slug-character"
      , "phase-path-slug-empty"
      , "phase-path-slug-segment"
      ]
    , "input-entry-limit"
    )
  , ("VALIDATION_PHASE_CONTRACT_PHASE_DUPLICATE_FINDING_BYPASS_MUTANT", ["phase-duplicate"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_PHASE_EXTRA_FINDING_BYPASS_MUTANT", ["phase-extra"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_PHASE_MISSING_FINDING_BYPASS_MUTANT", ["phase-missing"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_PHASE_PATH_DIGIT_WIDTH_BYPASS_MUTANT", ["phase-path-digit-width"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_PHASE_PATH_DIRECTORY_BYPASS_MUTANT", ["phase-path-directory"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_PHASE_PATH_EXTENSION_BYPASS_MUTANT", ["phase-path-extension"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_PHASE_PATH_PREFIX_BYPASS_MUTANT", ["phase-path-prefix"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_PHASE_PATH_SEPARATOR_BYPASS_MUTANT", ["phase-path-separator"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_PHASE_PATH_SLUG_CHARACTER_BYPASS_MUTANT", ["phase-path-slug-character"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_PHASE_PATH_SLUG_EMPTY_BYPASS_MUTANT", ["phase-path-slug-empty"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_PHASE_PATH_SLUG_SEGMENT_BYPASS_MUTANT", ["phase-path-slug-segment"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_PHASE_TITLE_CARDINALITY_BYPASS_MUTANT", ["phase-title-cardinality"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_PHASE_TITLE_EMPTY_BYPASS_MUTANT", ["phase-title-empty"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_PHASE_TITLE_FINDING_BYPASS_MUTANT", ["phase-title", "phase-title-cardinality", "phase-title-empty", "phase-title-prefix"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_PHASE_TITLE_PREFIX_BYPASS_MUTANT", ["phase-title-prefix"], "input-entry-limit")
  , ( "VALIDATION_PHASE_CONTRACT_PHASE_STRUCTURE_RESULT_COMPOSITION_BYPASS_MUTANT"
    , [ "phase-structure-result-composition"
      , "gate-section"
      , "phase-section-shape"
      , "phase-status"
      , "phase-title"
      , "phase-title-cardinality"
      , "phase-title-empty"
      , "phase-title-prefix"
      , "summary-containment"
      , "summary-field"
      ]
    , "input-entry-limit"
    )
  , ("VALIDATION_PHASE_CONTRACT_PROJECTION_RESULT_COMPOSITION_BYPASS_MUTANT", ["projection-result-composition", "projection-vocabulary"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_RAW_HTML_BYPASS_MUTANT", ["tracker-raw-html"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_REFUSAL_MARKER_COUNT_OBSERVATION_BYPASS_MUTANT", ["refusal-marker-count-observation"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_SECTION_SHAPE_BYPASS_MUTANT", ["phase-section-shape"], "input-entry-limit")
  , ( "VALIDATION_PHASE_CONTRACT_SPRINT_BLOCKER_BYPASS_MUTANT"
    , ["sprint-blocker", "sprint-blocker-genesis", "sprint-blocker-predecessor", "sprint-blocker-prior-sprint"]
    , "input-entry-limit"
    )
  , ("VALIDATION_PHASE_CONTRACT_SPRINT_BLOCKER_GENESIS_BYPASS_MUTANT", ["sprint-blocker-genesis"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_SPRINT_BLOCKER_PREDECESSOR_BYPASS_MUTANT", ["sprint-blocker-predecessor"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_SPRINT_BLOCKER_PRIOR_SPRINT_BYPASS_MUTANT", ["sprint-blocker-prior-sprint"], "input-entry-limit")
  , ( "VALIDATION_PHASE_CONTRACT_SPRINT_IDENTITY_FINDING_BYPASS_MUTANT"
    , [ "sprint-identity"
      , "sprint-heading-marker"
      , "sprint-heading-ordinal-canonical"
      , "sprint-heading-ordinal-positive"
      , "sprint-heading-separator"
      , "sprint-heading-title-empty"
      ]
    , "input-entry-limit"
    )
  , ("VALIDATION_PHASE_CONTRACT_SPRINT_HEADING_MARKER_BYPASS_MUTANT", ["sprint-heading-marker"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_SPRINT_HEADING_ORDINAL_CANONICAL_BYPASS_MUTANT", ["sprint-heading-ordinal-canonical"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_SPRINT_HEADING_ORDINAL_POSITIVE_BYPASS_MUTANT", ["sprint-heading-ordinal-positive"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_SPRINT_HEADING_SEPARATOR_BYPASS_MUTANT", ["sprint-heading-separator"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_SPRINT_HEADING_TITLE_EMPTY_BYPASS_MUTANT", ["sprint-heading-title-empty"], "input-entry-limit")
  , ( "VALIDATION_PHASE_CONTRACT_SPRINT_RESULT_COMPOSITION_BYPASS_MUTANT"
    , [ "sprint-result-composition"
      , "sprint-blocker"
      , "sprint-blocker-genesis"
      , "sprint-blocker-predecessor"
      , "sprint-blocker-prior-sprint"
      , "sprint-heading-marker"
      , "sprint-heading-ordinal-canonical"
      , "sprint-heading-ordinal-positive"
      , "sprint-heading-separator"
      , "sprint-heading-title-empty"
      , "sprint-identity"
      , "sprint-schema"
      , "sprint-schema-field-nonempty"
      , "sprint-schema-field-order"
      , "sprint-schema-late-field"
      , "sprint-schema-subsection-nonempty"
      , "sprint-schema-subsection-order"
      , "sprint-status"
      ]
    , "input-entry-limit"
    )
  , ( "VALIDATION_PHASE_CONTRACT_SPRINT_SCHEMA_BYPASS_MUTANT"
    , [ "sprint-schema"
      , "sprint-schema-field-nonempty"
      , "sprint-schema-field-order"
      , "sprint-schema-late-field"
      , "sprint-schema-subsection-nonempty"
      , "sprint-schema-subsection-order"
      ]
    , "input-entry-limit"
    )
  , ("VALIDATION_PHASE_CONTRACT_SPRINT_SCHEMA_FIELD_NONEMPTY_BYPASS_MUTANT", ["sprint-schema-field-nonempty"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_SPRINT_SCHEMA_FIELD_ORDER_BYPASS_MUTANT", ["sprint-schema-field-order", "sprint-schema"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_SPRINT_SCHEMA_LATE_FIELD_BYPASS_MUTANT", ["sprint-schema-late-field"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_SPRINT_SCHEMA_SUBSECTION_NONEMPTY_BYPASS_MUTANT", ["sprint-schema-subsection-nonempty"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_SPRINT_SCHEMA_SUBSECTION_ORDER_BYPASS_MUTANT", ["sprint-schema-subsection-order"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_SPRINT_SECTION_COUNT_OBSERVATION_BYPASS_MUTANT", ["sprint-section-count-observation"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_SPRINT_STATUS_BYPASS_MUTANT", ["sprint-status"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_STATUS_BYPASS_MUTANT", ["phase-status"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_STRUCTURE_DIAGNOSTIC_BYPASS_MUTANT", ["structure-diagnostic-refusal"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_SUMMARY_CONTAINMENT_BYPASS_MUTANT", ["summary-containment"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_SUMMARY_FIELD_FINDING_BYPASS_MUTANT", ["summary-field"], "input-entry-limit")
  , ( "VALIDATION_PHASE_CONTRACT_TABLE_FRAME_BYPASS_MUTANT"
    , [ "gate-table-frame"
      , "gate-delimiter-shape"
      , "gate-end-content"
      , "gate-header-wildcard"
      , "gate-ignored-row"
      , "gate-incomplete-rows"
      , "gate-key-code"
      , "gate-missing-delimiter"
      , "gate-missing-header"
      , "gate-outside-row"
      , "gate-row-arity"
      , "gate-row-empty"
      , "gate-second-header"
      , "gate-unframed-row"
      , "table-closing-pipe"
      , "table-opening-pipe"
      ]
    , "input-entry-limit"
    )
  , ("VALIDATION_PHASE_CONTRACT_TABLE_CLOSING_PIPE_BYPASS_MUTANT", ["table-closing-pipe"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_TABLE_OPENING_PIPE_BYPASS_MUTANT", ["table-opening-pipe"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_TRACKER_DELIMITER_BOUNDARY_BYPASS_MUTANT", ["tracker-delimiter-boundary"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_TRACKER_DELIMITER_SHAPE_BYPASS_MUTANT", ["tracker-delimiter-shape", "tracker-frame-finding"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_TRACKER_END_BOUNDARY_BYPASS_MUTANT", ["tracker-end-boundary"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_TRACKER_END_CONTENT_BYPASS_MUTANT", ["tracker-end-content"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_TRACKER_EXTRA_CELL_BYPASS_MUTANT", ["tracker-extra-cell"], "input-entry-limit")
  , ( "VALIDATION_PHASE_CONTRACT_TRACKER_FRAME_FINDING_BYPASS_MUTANT"
    , [ "tracker-frame-finding"
      , "link-target-empty"
      , "link-target-character"
      , "link-trailing-content"
      , "tracker-comment-opacity"
      , "tracker-comment-splice"
      , "tracker-container-prefix"
      , "tracker-delimiter-boundary"
      , "tracker-delimiter-shape"
      , "tracker-end-boundary"
      , "tracker-end-content"
      , "tracker-extra-cell"
      , "tracker-fence-boundary"
      , "tracker-fence-opacity"
      , "tracker-header-wildcard"
      , "tracker-incomplete-rows"
      , "tracker-indented-code"
      , "tracker-link-label"
      , "tracker-link-prose"
      , "tracker-missing-delimiter"
      , "tracker-missing-header"
      , "tracker-order"
      , "tracker-ordinal-canonical"
      , "tracker-outside-row"
      , "tracker-raw-html"
      , "tracker-row-boundary"
      , "tracker-row-empty"
      , "tracker-second-header"
      , "tracker-unframed-rows"
      ]
    , "input-entry-limit"
    )
  , ("VALIDATION_PHASE_CONTRACT_TRACKER_HEADER_WILDCARD_BYPASS_MUTANT", ["tracker-header-wildcard"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_TRACKER_INCOMPLETE_ROWS_FINDING_BYPASS_MUTANT", ["tracker-incomplete-rows"], "input-entry-limit")
  , ( "VALIDATION_PHASE_CONTRACT_TRACKER_JOIN_RESULT_COMPOSITION_BYPASS_MUTANT"
    , [ "tracker-join-result-composition"
      , "tracker-contract-join"
      , "tracker-projection-join"
      , "tracker-projection-prefix"
      , "tracker-title-join"
      ]
    , "input-entry-limit"
    )
  , ("VALIDATION_PHASE_CONTRACT_TRACKER_LINK_LABEL_BYPASS_MUTANT", ["tracker-link-label"], "input-entry-limit")
  , ( "VALIDATION_PHASE_CONTRACT_TRACKER_LINK_PROSE_BYPASS_MUTANT"
    , [ "tracker-link-prose"
      , "link-target-character"
      , "link-trailing-content"
      , "tracker-link-label"
      ]
    , "input-entry-limit"
    )
  , ("VALIDATION_PHASE_CONTRACT_TRACKER_CARDINALITY_FINDING_BYPASS_MUTANT", ["tracker-cardinality"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_TRACKER_CONTRACT_JOIN_FINDING_BYPASS_MUTANT", ["tracker-contract-join"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_TRACKER_MISSING_FINDING_BYPASS_MUTANT", ["tracker-missing"], "input-entry-limit")
  , ( "VALIDATION_PHASE_CONTRACT_TRACKER_MISSING_HEADER_FINDING_BYPASS_MUTANT"
    , [ "tracker-missing-header"
      , "tracker-comment-opacity"
      , "tracker-container-prefix"
      , "tracker-fence-opacity"
      , "tracker-indented-code"
      , "tracker-raw-html"
      ]
    , "input-entry-limit"
    )
  , ("VALIDATION_PHASE_CONTRACT_TRACKER_MISSING_DELIMITER_FINDING_BYPASS_MUTANT", ["tracker-missing-delimiter"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_TRACKER_OUTSIDE_ROW_BYPASS_MUTANT", ["tracker-outside-row"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_TRACKER_ORDER_BYPASS_MUTANT", ["tracker-order"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_TRACKER_ORDINAL_CANONICAL_BYPASS_MUTANT", ["tracker-ordinal-canonical"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_TRACKER_PROJECTION_JOIN_FINDING_BYPASS_MUTANT", ["tracker-projection-join", "tracker-projection-prefix"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_TRACKER_PROJECTION_PREFIX_BYPASS_MUTANT", ["tracker-projection-prefix"], "input-entry-limit")
  , ( "VALIDATION_PHASE_CONTRACT_TRACKER_RESULT_COMPOSITION_BYPASS_MUTANT"
    , [ "tracker-result-composition"
      , "link-target-character"
      , "link-target-empty"
      , "link-trailing-content"
      , "tracker-cardinality"
      , "tracker-comment-opacity"
      , "tracker-comment-splice"
      , "tracker-container-prefix"
      , "tracker-delimiter-boundary"
      , "tracker-delimiter-shape"
      , "tracker-end-boundary"
      , "tracker-end-content"
      , "tracker-extra-cell"
      , "tracker-fence-boundary"
      , "tracker-fence-opacity"
      , "tracker-frame-finding"
      , "tracker-header-wildcard"
      , "tracker-incomplete-rows"
      , "tracker-indented-code"
      , "tracker-link-label"
      , "tracker-link-prose"
      , "tracker-missing"
      , "tracker-missing-delimiter"
      , "tracker-missing-header"
      , "tracker-order"
      , "tracker-ordinal-canonical"
      , "tracker-outside-row"
      , "tracker-raw-html"
      , "tracker-row-boundary"
      , "tracker-row-empty"
      , "tracker-second-header"
      , "tracker-status"
      , "tracker-unframed-rows"
      ]
    , "input-entry-limit"
    )
  , ("VALIDATION_PHASE_CONTRACT_TRACKER_ROW_BOUNDARY_BYPASS_MUTANT", ["tracker-row-boundary", "tracker-fence-boundary"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_TRACKER_ROW_EMPTY_BYPASS_MUTANT", ["tracker-row-empty"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_TRACKER_ROW_COUNT_OBSERVATION_BYPASS_MUTANT", ["tracker-row-count-observation"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_TRACKER_SECOND_HEADER_BYPASS_MUTANT", ["tracker-second-header"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_TRACKER_STATUS_FINDING_BYPASS_MUTANT", ["tracker-status"], "input-entry-limit")
  , ("VALIDATION_PHASE_CONTRACT_TRACKER_TITLE_JOIN_FINDING_BYPASS_MUTANT", ["tracker-title-join"], "input-entry-limit")
  , ( "VALIDATION_PHASE_CONTRACT_TRACKER_UNFRAMED_ROWS_BYPASS_MUTANT"
    , ["tracker-unframed-rows", "tracker-header-wildcard"]
    , "input-entry-limit"
    )
  , ("VALIDATION_PHASE_CONTRACT_UNRESOLVED_MARKER_COUNT_OBSERVATION_BYPASS_MUTANT", ["unresolved-marker-count-observation"], "input-entry-limit")
  ]

phaseContractSelectorNames :: [String]
phaseContractSelectorNames = [selector | (selector, _, _) <- phaseContractSelectorMatrixRows]

phaseContractExactCaseNames :: [String]
phaseContractExactCaseNames =
  [ "check-name"
  , "dependency-result-composition"
  , "dependency-forward"
  , "dependency-genesis"
  , "dependency-link-finding"
  , "dependency-link-label"
  , "dependency-link-prose"
  , "dependency-predecessor"
  , "gate-command"
  , "gate-command-count"
  , "gate-delimiter-shape"
  , "gate-end-content"
  , "gate-header-wildcard"
  , "gate-ignored-row"
  , "gate-incomplete-rows"
  , "gate-key-code"
  , "gate-missing-delimiter"
  , "gate-missing-header"
  , "gate-outside-row"
  , "gate-result-composition"
  , "gate-row-arity"
  , "gate-row-empty"
  , "gate-row-count-observation"
  , "gate-section"
  , "gate-second-header"
  , "gate-shape"
  , "gate-summary-command"
  , "gate-summary-raw-line-count"
  , "gate-summary-value"
  , "gate-table-frame"
  , "gate-unframed-row"
  , "input-document-limit"
  , "input-document-limit-observation"
  , "input-envelope-finding-composition"
  , "input-envelope-observation"
  , "input-envelope-observation-composition"
  , "input-entry-limit"
  , "input-entry-limit-observation"
  , "input-path-limit"
  , "input-path-limit-observation"
  , "input-total-limit"
  , "input-total-limit-observation"
  , "inline-code-width"
  , "link-target-character"
  , "link-target-empty"
  , "link-trailing-content"
  , "missing-marker-count-observation"
  , "observation-result-composition"
  , "phase-document-count-observation"
  , "phase-domain-result-composition"
  , "phase-discovery"
  , "phase-duplicate"
  , "phase-extra"
  , "phase-missing"
  , "phase-path-digit-width"
  , "phase-path-directory"
  , "phase-path-extension"
  , "phase-path-prefix"
  , "phase-path-separator"
  , "phase-path-slug-character"
  , "phase-path-slug-empty"
  , "phase-path-slug-segment"
  , "phase-section-shape"
  , "phase-status"
  , "phase-structure-result-composition"
  , "phase-title"
  , "phase-title-cardinality"
  , "phase-title-empty"
  , "phase-title-prefix"
  , "projection-vocabulary"
  , "projection-result-composition"
  , "refusal-marker-count-observation"
  , "sprint-blocker"
  , "sprint-blocker-genesis"
  , "sprint-blocker-predecessor"
  , "sprint-blocker-prior-sprint"
  , "sprint-heading-marker"
  , "sprint-heading-ordinal-canonical"
  , "sprint-heading-ordinal-positive"
  , "sprint-heading-separator"
  , "sprint-heading-title-empty"
  , "sprint-identity"
  , "sprint-result-composition"
  , "sprint-schema"
  , "sprint-schema-field-nonempty"
  , "sprint-schema-field-order"
  , "sprint-schema-late-field"
  , "sprint-schema-subsection-nonempty"
  , "sprint-schema-subsection-order"
  , "sprint-section-count-observation"
  , "sprint-status"
  , "structure-diagnostic-refusal"
  , "summary-containment"
  , "summary-field"
  , "table-closing-pipe"
  , "table-opening-pipe"
  , "tracker-cardinality"
  , "tracker-comment-opacity"
  , "tracker-comment-splice"
  , "tracker-container-prefix"
  , "tracker-contract-join"
  , "tracker-delimiter-boundary"
  , "tracker-delimiter-shape"
  , "tracker-end-boundary"
  , "tracker-end-content"
  , "tracker-extra-cell"
  , "tracker-fence-boundary"
  , "tracker-fence-opacity"
  , "tracker-frame-finding"
  , "tracker-header-wildcard"
  , "tracker-incomplete-rows"
  , "tracker-indented-code"
  , "tracker-join-result-composition"
  , "tracker-link-label"
  , "tracker-link-prose"
  , "tracker-missing"
  , "tracker-missing-delimiter"
  , "tracker-missing-header"
  , "tracker-outside-row"
  , "tracker-order"
  , "tracker-ordinal-canonical"
  , "tracker-projection-join"
  , "tracker-projection-prefix"
  , "tracker-result-composition"
  , "tracker-raw-html"
  , "tracker-row-boundary"
  , "tracker-row-empty"
  , "tracker-row-count-observation"
  , "tracker-second-header"
  , "tracker-status"
  , "tracker-title-join"
  , "tracker-unframed-rows"
  , "unresolved-gate-cell"
  , "unresolved-marker-count-observation"
  ]

-- Direct-source full-mode diagnostics reuse the same independently literal
-- structural corpus without exposing any production parser constructor.
phaseContractValidCorpus :: [(FilePath, Text)]
phaseContractValidCorpus = validCorpus

phaseContractSelectorIntegrityProblems :: [String]
phaseContractSelectorIntegrityProblems =
  [ "phase-contract selector registry must contain exactly 134 distinct selectors"
  | length phaseContractSelectorNames /= 134 || not (allDistinct phaseContractSelectorNames)
  ]
    <> [ "phase-contract exact-case registry must contain exactly 134 distinct cases"
       | length phaseContractExactCaseNames /= 134 || not (allDistinct phaseContractExactCaseNames)
       ]
    <> [ selector <> ": selector has no assigned exact impact"
       | (selector, impacts, _) <- phaseContractSelectorMatrixRows
       , null impacts
       ]
    <> [ selector <> ": selector names an unknown exact impact " <> exactCase
       | (selector, impacts, _) <- phaseContractSelectorMatrixRows
       , exactCase <- impacts
       , exactCase `notElem` phaseContractExactCaseNames
       ]
    <> [ selector <> ": selector names an unknown product control " <> control
       | (selector, _, control) <- phaseContractSelectorMatrixRows
       , control `notElem` phaseContractExactCaseNames
       ]
    <> [ selector <> ": product control is also a declared impact"
       | (selector, impacts, control) <- phaseContractSelectorMatrixRows
       , control `elem` impacts
       ]
    <> [ exactCase <> ": exact case is not the primary target of exactly one selector"
       | exactCase <- phaseContractExactCaseNames
       , length [() | (_, primary : _, _) <- phaseContractSelectorMatrixRows, primary == exactCase] /= 1
       ]

runPhaseContractExactCase :: String -> IO ()
runPhaseContractExactCase exactCase =
  finishDiagnostics ("PhaseContractOracle exact case " <> exactCase) (phaseContractExactCaseProblems exactCase)

runPhaseContractSelectorOracle :: String -> IO ()
runPhaseContractSelectorOracle selector =
  case [(impacts, control) | (candidate, impacts, control) <- phaseContractSelectorMatrixRows, candidate == selector] of
    [(impacts, _)] ->
      finishDiagnostics
        ("PhaseContractOracle selector " <> selector)
        (concatMap phaseContractExactCaseProblems impacts)
    matches -> fail ("PhaseContractOracle selector lookup is not singular for " <> selector <> ": " <> show matches)

runPhaseContractUnaffectedControl :: String -> IO ()
runPhaseContractUnaffectedControl selector =
  case [control | (candidate, _, control) <- phaseContractSelectorMatrixRows, candidate == selector] of
    [control] ->
      finishDiagnostics
        ("PhaseContractOracle control " <> selector)
        (phaseContractExactCaseProblems control)
    matches -> fail ("PhaseContractOracle control lookup is not singular for " <> selector <> ": " <> show matches)

runPhaseContractOracle :: IO ()
runPhaseContractOracle =
  finishDiagnostics
    "PhaseContractOracle"
    ( concat
        [ oracleUniverseProblems
        , oracleFixtureProblems
        , phaseContractSelectorIntegrityProblems
        , concatMap phaseContractExactCaseProblems phaseContractExactCaseNames
        , phaseContractResourceEnvelopeProblems
        , expectDiagnosticOnly "independently stated 96-phase and tracker corpus" validCorpus
        , expectExactFindingInResult
            "caller-authored structure always carries the permanent diagnostic refusal"
            diagnosticRefusalCode
            planRoot
            diagnosticRefusalMessage
            (phaseContractDiagnostic validCorpus)
        , expectFindingInResult
            "empty phase discovery"
            "PLAN-PHASE-DISCOVERY"
            planRoot
            (phaseContractDiagnostic [])
        , expectFindingInResult
            "phase-shaped decoy outside DEVELOPMENT_PLAN cannot satisfy discovery"
            "PLAN-PHASE-DISCOVERY"
            planRoot
            (phaseContractDiagnostic [("archive/phase_00_decoy.md", phaseDocument 0)])
        , expectFinding
            "closed phase domain omits Phase 95"
            "PLAN-PHASE-MISSING"
            planRoot
            (filter ((/= phasePath 95) . fst) validCorpus)
        , expectFinding
            "closed phase domain rejects Phase 96"
            "PLAN-PHASE-EXTRA"
            (phasePath 96)
            (validCorpus <> [(phasePath 96, phaseDocument 96)])
        , expectFinding
            "tracker domain omits Phase 95"
            "PLAN-TRACKER-MISSING"
            trackerPath
            (replaceDocument trackerPath (trackerDocument [0 .. 94]) validCorpus)
        , expectFinding
            "phase sections reject an order mutation at the changed phase locus"
            "PLAN-PHASE-SECTION-SHAPE"
            (phasePath 7)
            ( replaceIn
                (phasePath 7)
                "## Doctrine adopted\n\nSynthetic doctrine citation.\n\n## Sprints"
                "## Sprints\n\nSynthetic doctrine citation.\n\n## Doctrine adopted"
                validCorpus
            )
        , expectFinding
            "phase sections reject a duplicate mandatory section at the changed phase locus"
            "PLAN-PHASE-SECTION-SHAPE"
            (phasePath 7)
            (replaceIn (phasePath 7) "## Related Documents" "## Documentation Requirements\n\nSynthetic duplicate.\n\n## Related Documents" validCorpus)
        , expectDiagnosticOnly
            "the one optional Resource provision section is admitted only in its documented slot"
            resourceSectionCorpus
        , expectFinding
            "Phase Summary fields cannot move outside their owning section"
            "PLAN-SUMMARY-CONTAINMENT"
            (phasePath 7)
            ( relocateAfter
                (phasePath 7)
                (summaryLine "Substrate" (substrateValue 7))
                "## Related Documents"
                validCorpus
            )
        , expectFinding
            "Phase Summary rejects a seventh caller-authored field"
            "PLAN-SUMMARY-CONTAINMENT"
            (phasePath 7)
            (replaceIn (phasePath 7) (summaryLine "Lane" (laneValue 7)) (summaryLine "Lane" (laneValue 7) <> "\n\n**Unreviewed:** decoy") validCorpus)
        , expectFinding
            "phase status reset"
            "PLAN-PHASE-STATUS"
            (phasePath 10)
            (replaceIn (phasePath 10) blockedStatus activeStatus validCorpus)
        , expectFinding
            "a second bare phase status cannot hide after the reset line"
            "PLAN-PHASE-STATUS"
            (phasePath 10)
            (replaceIn (phasePath 10) blockedStatus (blockedStatus <> "\n\n✅ Done") validCorpus)
        , expectFinding
            "a second phase Status field cannot hide after the reset line"
            "PLAN-PHASE-STATUS"
            (phasePath 10)
            (replaceIn (phasePath 10) blockedStatus (blockedStatus <> "\n\n**Status**: ✅ Done") validCorpus)
        , concat
            [ expectFinding
                ("every independently enumerated current status form is recognized as a second claim: " <> Text.unpack form)
                "PLAN-PHASE-STATUS"
                (phasePath 10)
                (replaceIn (phasePath 10) blockedStatus (blockedStatus <> "\n\n" <> form) validCorpus)
            | form <- expectedCurrentStatusForms
            ]
        , expectFinding
            "tracker status reset"
            "PLAN-TRACKER-STATUS"
            trackerPath
            ( replaceIn
                trackerPath
                (trackerRow 10 blockedTrackerStatus)
                (trackerRow 10 "Done")
                validCorpus
            )
        , expectFinding
            "immediate predecessor dependency"
            "PLAN-DEPENDENCY-PREDECESSOR"
            (phasePath 10)
            ( replaceIn
                (phasePath 10)
                (dependencyValue 10)
                "[Phase 8](phase_08_synthetic_capability.md)"
                validCorpus
            )
        , expectFinding
            "Depends on rejects prose surrounding its one immediate-predecessor link"
            "PLAN-DEPENDENCY-LINK"
            (phasePath 10)
            dependencyLinkProseCorpus
        , expectFinding
            "Depends on retains the exact immediate-predecessor link label"
            "PLAN-DEPENDENCY-LINK"
            (phasePath 10)
            ( replaceIn
                (phasePath 10)
                (dependencyValue 10)
                "[Earlier phase](phase_09_synthetic_capability.md)"
                validCorpus
            )
        , expectFinding
            "Depends on rejects a normalized path alias for the immediate predecessor"
            "PLAN-DEPENDENCY-PREDECESSOR"
            (phasePath 10)
            dependencyPathAliasCorpus
        , expectDiagnosticOnly
            "gate-row prose cannot supply predecessor, residue, or authority semantics"
            gateSemanticProseDecoyCorpus
        , expectFinding
            "tracker title joins its phase H1"
            "PLAN-TRACKER-TITLE"
            trackerPath
            ( replaceIn
                trackerPath
                "| 10 | Synthetic capability 10 |"
                "| 10 | Divergent title |"
                validCorpus
            )
        , expectFinding
            "tracker substrate projection joins its phase summary"
            "PLAN-TRACKER-PROJECTION"
            trackerPath
            ( replaceIn
                trackerPath
                (trackerRow 10 blockedTrackerStatus)
                (trackerRowWith 10 "linux-cpu" "none" "2" blockedTrackerStatus)
                validCorpus
            )
        , expectFinding
            "tracker rows cannot satisfy the contract without the exact table frame"
            "PLAN-TRACKER-TABLE-FRAME"
            trackerPath
            trackerRowsWithoutFrameCorpus
        , expectExactFindingInResult
            "tracker frame refusal retains the exact missing-header diagnostic"
            "PLAN-TRACKER-TABLE-FRAME"
            trackerPath
            "one exact '| Phase | Name | Substrate | Lane | Register | Status | Validation contract |' tracker header is required"
            (phaseContractDiagnostic trackerRowsWithoutFrameCorpus)
        , expectFinding
            "tracker header cells are the exact independent literal"
            "PLAN-TRACKER-TABLE-FRAME"
            trackerPath
            trackerHeaderWildcardCorpus
        , expectFinding
            "tracker delimiter is mandatory and exact"
            "PLAN-TRACKER-TABLE-FRAME"
            trackerPath
            trackerDelimiterShapeCorpus
        , expectFinding
            "tracker rows must remain in canonical ordinal order"
            "PLAN-TRACKER-TABLE-FRAME"
            trackerPath
            reorderedTrackerCorpus
        , expectFinding
            "tracker ordinals reject a leading zero"
            "PLAN-TRACKER-TABLE-FRAME"
            trackerPath
            leadingZeroTrackerCorpus
        , expectFinding
            "tracker rows reject an ignored eighth cell"
            "PLAN-TRACKER-TABLE-FRAME"
            trackerPath
            extraCellTrackerCorpus
        , expectFinding
            "an arity-mutated numeric tracker row cannot hide outside the exact frame"
            "PLAN-TRACKER-TABLE-FRAME"
            trackerPath
            outsideExtraCellTrackerCorpus
        , expectFinding
            "a numeric tracker candidate missing its closing pipe cannot hide outside the exact frame"
            "PLAN-TRACKER-TABLE-FRAME"
            trackerPath
            outsideMalformedTrackerCorpus
        , expectFinding
            "tracker contract links reject surrounding prose"
            "PLAN-TRACKER-TABLE-FRAME"
            trackerPath
            trackerLinkProseCorpus
        , expectFinding
            "tracker contract links reject a normalized path alias"
            "PLAN-TRACKER-CONTRACT"
            trackerPath
            trackerPathAliasCorpus
        , expectFinding
            "tracker projection cells reject an arbitrary suffix"
            "PLAN-TRACKER-PROJECTION"
            trackerPath
            trackerProjectionSuffixCorpus
        , expectFinding
            "a physical blank cannot split and then reassemble the tracker table"
            "PLAN-TRACKER-TABLE-FRAME"
            trackerPath
            trackerBlankSplitCorpus
        , expectFinding
            "a fenced block cannot be deleted to splice tracker rows"
            "PLAN-TRACKER-TABLE-FRAME"
            trackerPath
            trackerFenceSplitCorpus
        , expectFinding
            "an HTML comment cannot be deleted to manufacture a tracker row"
            "PLAN-TRACKER-TABLE-FRAME"
            trackerPath
            trackerCommentPrefixCorpus
        , expectFinding
            "container and blank syntax inside a multiline HTML comment cannot terminate its opacity"
            "PLAN-TRACKER-TABLE-FRAME"
            trackerPath
            trackerMultilineCommentCorpus
        , concat
            [ expectFinding
                ("a CommonMark raw-HTML block cannot supply the tracker table: " <> label)
                "PLAN-TRACKER-TABLE-FRAME"
                trackerPath
                corpus
            | (label, corpus) <- trackerRawHtmlCorpora
            ]
        , expectFinding
            "four-space indented code cannot supply the tracker table"
            "PLAN-TRACKER-TABLE-FRAME"
            trackerPath
            (indentedTrackerCorpus "    ")
        , expectFinding
            "tab-indented code cannot supply the tracker table"
            "PLAN-TRACKER-TABLE-FRAME"
            trackerPath
            (indentedTrackerCorpus "\t")
        , expectFinding
            "Unicode whitespace cannot promote the tracker header to top-level structure"
            "PLAN-TRACKER-TABLE-FRAME"
            trackerPath
            (indentedTrackerCorpus "\160")
        , expectFinding
            "an ordinary list continuation cannot supply the tracker table"
            "PLAN-TRACKER-TABLE-FRAME"
            trackerPath
            listContainedTrackerCorpus
        , expectFinding
            "an ordinary blockquote cannot supply the tracker table"
            "PLAN-TRACKER-TABLE-FRAME"
            trackerPath
            blockquoteContainedTrackerCorpus
        , expectFinding
            "gate table requires the independently fixed literal header"
            "PLAN-GATE-TABLE-FRAME"
            (phasePath 7)
            gateHeaderWildcardCorpus
        , expectExactFindingInResult
            "gate frame refusal retains the exact missing-header diagnostic"
            "PLAN-GATE-TABLE-FRAME"
            (phasePath 7)
            "one exact '| Key | Contract |' gate-table header is required"
            (phaseContractDiagnostic gateHeaderWildcardCorpus)
        , expectFinding
            "gate table requires the independently fixed literal delimiter"
            "PLAN-GATE-TABLE-FRAME"
            (phasePath 7)
            gateDelimiterShapeCorpus
        , expectFinding
            "gate row outside the one framed table is refused"
            "PLAN-GATE-TABLE-FRAME"
            (phasePath 7)
            (replaceIn (phasePath 7) (gateRow "Promotion authority" "Promotion authority requires an authorized reviewer.") (gateRow "Promotion authority" "Promotion authority requires an authorized reviewer." <> "\n\n" <> gateRow "Decoy" "outside") validCorpus)
        , expectFinding
            "an arity-mutated gate row outside the exact frame is refused"
            "PLAN-GATE-TABLE-FRAME"
            (phasePath 7)
            gateThreeCellOutsideCorpus
        , expectFinding
            "a gate candidate missing its closing pipe outside the exact frame is refused"
            "PLAN-GATE-TABLE-FRAME"
            (phasePath 7)
            gateMalformedOutsideCorpus
        , expectFinding
            "a fenced block cannot be deleted between the gate header and delimiter"
            "PLAN-GATE-TABLE-FRAME"
            (phasePath 7)
            gateFenceSpliceCorpus
        , expectFinding
            "an HTML comment cannot be deleted to manufacture the gate delimiter"
            "PLAN-GATE-TABLE-FRAME"
            (phasePath 7)
            gateCommentDelimiterCorpus
        , expectFinding
            "four-space indented code cannot supply the gate delimiter"
            "PLAN-GATE-TABLE-FRAME"
            (phasePath 7)
            gateIndentedDelimiterCorpus
        , expectFinding
            "raw HTML cannot supply a complete gate table"
            "PLAN-GATE-TABLE-FRAME"
            (phasePath 7)
            gateRawHtmlCorpus
        , expectFinding
            "an ordinary list continuation cannot supply a complete gate table"
            "PLAN-GATE-TABLE-FRAME"
            (phasePath 7)
            gateListContainedCorpus
        , expectFinding
            "an ordinary blockquote cannot supply a complete gate table"
            "PLAN-GATE-TABLE-FRAME"
            (phasePath 7)
            gateBlockquoteContainedCorpus
        , expectFinding
            "a second delimiter-like raw row cannot disappear from the gate table"
            "PLAN-GATE-TABLE-FRAME"
            (phasePath 7)
            gateExtraDelimiterCorpus
        , expectFinding
            "a blank-key raw row cannot disappear from the gate table"
            "PLAN-GATE-TABLE-FRAME"
            (phasePath 7)
            gateBlankKeyCorpus
        , expectFinding
            "gate keys retain their canonical Markdown code delimiters"
            "PLAN-GATE-TABLE-FRAME"
            (phasePath 7)
            gateUnbacktickedKeyCorpus
        , expectFinding
            "an indented Gate heading cannot become a top-level section"
            "PLAN-GATE-SECTION"
            (phasePath 7)
            gateIndentedHeadingCorpus
        , expectFinding
            "a list continuation cannot manufacture the current phase status"
            "PLAN-PHASE-STATUS"
            (phasePath 10)
            listContainedStatusCorpus
        , expectFinding
            "a list continuation cannot manufacture a Phase Summary field"
            "PLAN-SUMMARY-FIELD"
            (phasePath 10)
            listContainedSummaryCorpus
        , expectFinding
            "a list continuation cannot manufacture a sprint field"
            "PLAN-SPRINT-SCHEMA"
            (phasePath 10)
            listContainedSprintCorpus
        , expectFinding
            "eighteen-row gate cardinality"
            "PLAN-GATE-SHAPE"
            (phasePath 7)
            (replaceIn (phasePath 7) (gateRow "Challenge" standardChallenge) "" validCorpus)
        , expectFinding
            "eighteen-row gate order"
            "PLAN-GATE-SHAPE"
            (phasePath 7)
            ( replaceIn
                (phasePath 7)
                (gateRow "Subject" standardSubject <> "\n" <> gateRow "Command" (commandValue 7))
                (gateRow "Command" (commandValue 7) <> "\n" <> gateRow "Subject" standardSubject)
                validCorpus
            )
        , expectFinding
            "unresolved gate cell refuses"
            "PLAN-GATE-UNRESOLVED"
            (phasePath 8)
            (replaceIn (phasePath 8) (gateRow "Oracle" standardOracle) (gateRow "Oracle" "UNRESOLVED") validCorpus)
        , expectObservation
            "unresolved and missing markers are counted separately"
            "unresolved-marker-cell-count"
            "1"
            (phaseContractDiagnostic markerCorpus)
        , expectObservation
            "missing markers are not mislabeled unresolved"
            "missing-marker-cell-count"
            "1"
            (phaseContractDiagnostic markerCorpus)
        , expectObservation
            "combined refusal-marker count remains explicit"
            "refusal-marker-cell-count"
            "2"
            (phaseContractDiagnostic markerCorpus)
        , expectFinding
            "exact canonical pb command"
            "PLAN-GATE-COMMAND"
            (phasePath 9)
            ( replaceIn
                (phasePath 9)
                (gateRow "Command" (commandValue 9))
                (gateRow "Command" "`pb validate phase 9`")
                validCorpus
            )
        , expectFinding
            "phase-summary canonical pb command"
            "PLAN-GATE-SUMMARY-COMMAND"
            (phasePath 9)
            ( replaceIn
                (phasePath 9)
                (gateSummaryLine 9)
                "**Gate:** `pb validate phase 9` — NOT VALIDATED."
                validCorpus
            )
        , expectFinding
            "phase-summary dual Validated and NOT VALIDATED status"
            "PLAN-GATE-SUMMARY-COMMAND"
            (phasePath 9)
            (replaceIn (phasePath 9) (gateSummaryLine 9) ("**Gate:** " <> commandValue 9 <> "; see [Gate integrity](#gate-integrity). Validated — NOT VALIDATED.") validCorpus)
        , expectFinding
            "a fenced canonical gate summary cannot mask a contradictory live summary"
            "PLAN-GATE-SUMMARY-COMMAND"
            (phasePath 9)
            ( appendTo
                (phasePath 9)
                ("\n```text\n" <> gateSummaryLine 9 <> "\n```\n")
                (replaceIn (phasePath 9) (gateSummaryLine 9) ("**Gate:** " <> commandValue 9 <> "; see [Gate integrity](#gate-integrity). Validated — NOT VALIDATED.") validCorpus)
            )
        , expectFinding
            "an HTML-comment-spliced reset is not the raw canonical gate summary"
            "PLAN-GATE-SUMMARY-COMMAND"
            (phasePath 9)
            (replaceIn (phasePath 9) (gateSummaryLine 9) (Text.replace "NOT VALIDATED" "NOT<!-- hidden --> VALIDATED" (gateSummaryLine 9)) validCorpus)
        , expectFinding
            "a line-wrapped reset is not the raw canonical gate summary"
            "PLAN-GATE-SUMMARY-COMMAND"
            (phasePath 9)
            (replaceIn (phasePath 9) (gateSummaryLine 9) (Text.replace "NOT VALIDATED" "NOT\nVALIDATED" (gateSummaryLine 9)) validCorpus)
        , expectFinding
            "substrate vocabulary is closed independently in phase and tracker projections"
            "PLAN-PROJECTION-VOCABULARY"
            (phasePath 10)
            ( replaceProjection
                10
                "Substrate"
                (substrateValue 10)
                "invented-substrate"
                validCorpus
            )
        , expectFinding
            "lane vocabulary is closed independently in phase and tracker projections"
            "PLAN-PROJECTION-VOCABULARY"
            (phasePath 10)
            (replaceProjection 10 "Lane" (laneValue 10) "cpu" validCorpus)
        , expectFinding
            "register vocabulary is closed independently in phase and tracker projections"
            "PLAN-PROJECTION-VOCABULARY"
            (phasePath 10)
            (replaceProjection 10 "Register" (registerValue 10) "2.5" validCorpus)
        , concat
            [ expectDiagnosticOnly
                ("every independent substrate universe member remains structurally representable: " <> Text.unpack value)
                (replaceProjection 10 "Substrate" (substrateValue 10) value validCorpus)
            | value <- expectedSubstrates
            ]
        , concat
            [ expectDiagnosticOnly
                ("every independent lane universe member remains structurally representable: " <> Text.unpack value)
                (replaceProjection 10 "Lane" (laneValue 10) value validCorpus)
            | value <- expectedLanes
            ]
        , concat
            [ expectDiagnosticOnly
                ("every independent register universe member remains structurally representable: " <> Text.unpack value)
                (replaceProjection 10 "Register" (registerValue 10) value validCorpus)
            | value <- expectedRegisters
            ]
        , expectDiagnosticOnly
            "the optional Requires field is admitted only at its exact schema position"
            requiresCorpus
        , expectFinding
            "the optional Requires field is refused outside its exact schema position"
            "PLAN-SPRINT-SCHEMA"
            (phasePath 10)
            ( replaceIn
                (phasePath 10)
                (sprintFieldLine "Blocked by" (phaseApprovalBlocker 9) <> "\n" <> sprintFieldLine "Requires" "natural-linux-cpu-amd64-host")
                (sprintFieldLine "Requires" "natural-linux-cpu-amd64-host" <> "\n" <> sprintFieldLine "Blocked by" (phaseApprovalBlocker 9))
                requiresCorpus
            )
        , expectFinding
            "a sprint mandatory field omission is refused at the owning phase"
            "PLAN-SPRINT-SCHEMA"
            (phasePath 10)
            (replaceIn (phasePath 10) (sprintFieldLine "Oracle" syntheticOracle) "" validCorpus)
        , expectFinding
            "a sprint mandatory field reorder is refused at the owning phase"
            "PLAN-SPRINT-SCHEMA"
            (phasePath 10)
            ( replaceIn
                (phasePath 10)
                (sprintFieldLine "Independent Validation" syntheticValidation <> "\n" <> sprintFieldLine "Oracle" syntheticOracle)
                (sprintFieldLine "Oracle" syntheticOracle <> "\n" <> sprintFieldLine "Independent Validation" syntheticValidation)
                validCorpus
            )
        , expectFinding
            "a sprint mandatory field duplicate is refused at the owning phase"
            "PLAN-SPRINT-SCHEMA"
            (phasePath 10)
            (replaceIn (phasePath 10) (sprintFieldLine "Legacy IDs" "none") (sprintFieldLine "Legacy IDs" "none" <> "\n" <> sprintFieldLine "Legacy IDs" "none") validCorpus)
        , expectFinding
            "a sprint mandatory field cannot be empty"
            "PLAN-SPRINT-SCHEMA"
            (phasePath 10)
            (replaceIn (phasePath 10) (sprintFieldLine "Docs to update" syntheticDocs) (sprintFieldLine "Docs to update" "") validCorpus)
        , expectFinding
            "a sprint subsection omission is refused at the owning phase"
            "PLAN-SPRINT-SCHEMA"
            (phasePath 10)
            (replaceIn (phasePath 10) "### Validation\n\nSynthetic validation details.\n\n" "" validCorpus)
        , expectFinding
            "a sprint subsection reorder is refused at the owning phase"
            "PLAN-SPRINT-SCHEMA"
            (phasePath 10)
            ( replaceIn
                (phasePath 10)
                "### Deliverables\n\nSynthetic deliverable.\n\n### Validation\n\nSynthetic validation details."
                "### Validation\n\nSynthetic validation details.\n\n### Deliverables\n\nSynthetic deliverable."
                validCorpus
            )
        , expectFinding
            "a first sprint must bind the immediate predecessor phase"
            "PLAN-SPRINT-BLOCKER"
            (phasePath 10)
            (replaceIn (phasePath 10) (sprintFieldLine "Blocked by" (phaseApprovalBlocker 9)) (sprintFieldLine "Blocked by" (phaseApprovalBlocker 8)) validCorpus)
        , expectFinding
            "a first sprint cannot replace the canonical predecessor link with unlinked prose"
            "PLAN-SPRINT-BLOCKER"
            (phasePath 10)
            (replaceIn (phasePath 10) (sprintFieldLine "Blocked by" (phaseApprovalBlocker 9)) (sprintFieldLine "Blocked by" "Phase 9 reviewer approval") validCorpus)
        , expectFinding
            "the genesis sprint blocker uses the one exact raw reset value"
            "PLAN-SPRINT-BLOCKER"
            (phasePath 0)
            (replaceIn (phasePath 0) (sprintFieldLine "Blocked by" "`genesis`") (sprintFieldLine "Blocked by" "genesis") validCorpus)
        , expectDiagnosticOnly
            "a second sprint with the exact immediate prior edge is admitted diagnostically"
            twoSprintCorpus
        , expectFinding
            "a downstream sprint cannot bind itself instead of its immediate predecessor"
            "PLAN-SPRINT-BLOCKER"
            (phasePath 10)
            (replaceIn (phasePath 10) (sprintFieldLine "Blocked by" "Sprint 10.1") (sprintFieldLine "Blocked by" "Sprint 10.2") twoSprintCorpus)
        , expectFinding
            "a downstream sprint cannot substitute or append a prior-phase sprint edge"
            "PLAN-SPRINT-BLOCKER"
            (phasePath 10)
            (replaceIn (phasePath 10) (sprintFieldLine "Blocked by" "Sprint 10.1") (sprintFieldLine "Blocked by" "Sprint 10.1; Sprint 9.99") twoSprintCorpus)
        , expectFinding
            "a downstream sprint cannot append an earlier phase approval after its immediate sprint edge"
            "PLAN-SPRINT-BLOCKER"
            (phasePath 10)
            (replaceIn (phasePath 10) (sprintFieldLine "Blocked by" "Sprint 10.1") (sprintFieldLine "Blocked by" ("Sprint 10.1; " <> phaseApprovalBlocker 9)) twoSprintCorpus)
        , expectFinding
            "a downstream sprint cannot append candidate or reviewer-inspection prose after its immediate sprint edge"
            "PLAN-SPRINT-BLOCKER"
            (phasePath 10)
            (replaceIn (phasePath 10) (sprintFieldLine "Blocked by" "Sprint 10.1") (sprintFieldLine "Blocked by" "Sprint 10.1 candidate and reviewer sprint inspection") twoSprintCorpus)
        , expectFinding
            "a first sprint cannot append another earlier phase after its immediate predecessor"
            "PLAN-SPRINT-BLOCKER"
            (phasePath 10)
            (replaceIn (phasePath 10) (sprintFieldLine "Blocked by" (phaseApprovalBlocker 9)) (sprintFieldLine "Blocked by" (phaseApprovalBlocker 9 <> "; " <> phaseApprovalBlocker 8)) validCorpus)
        , expectFinding
            "a dual Validated and NOT VALIDATED sprint status is refused"
            "PLAN-SPRINT-STATUS"
            (phasePath 10)
            (replaceIn (phasePath 10) (sprintFieldLine "Status" "Blocked — NOT VALIDATED") (sprintFieldLine "Status" "Validated — NOT VALIDATED") validCorpus)
        , expectFinding
            "an HTML-comment-spliced sprint reset is not the raw canonical field"
            "PLAN-SPRINT-STATUS"
            (phasePath 10)
            (replaceIn (phasePath 10) (sprintFieldLine "Status" "Blocked — NOT VALIDATED") (sprintFieldLine "Status" "Blocked — NOT<!-- hidden --> VALIDATED") validCorpus)
        , expectFinding
            "a lowercase done sprint status is refused"
            "PLAN-SPRINT-STATUS"
            (phasePath 10)
            (replaceIn (phasePath 10) (sprintFieldLine "Status" "Blocked — NOT VALIDATED") (sprintFieldLine "Status" "done — NOT VALIDATED") validCorpus)
        , expectFinding
            "a sprint heading cannot claim another phase"
            "PLAN-SPRINT-IDENTITY"
            (phasePath 10)
            (replaceIn (phasePath 10) "## Sprint 10.1:" "## Sprint 9.1:" validCorpus)
        , expectFinding
            "a sprint heading must carry one of the independently closed five status markers"
            "PLAN-SPRINT-IDENTITY"
            (phasePath 10)
            (replaceIn (phasePath 10) "Synthetic seam ⏸️" "Synthetic seam ❌" validCorpus)
        , expectFinding
            "a known sprint marker cannot contradict its reviewed current Status field"
            "PLAN-SPRINT-STATUS"
            (phasePath 10)
            (replaceIn (phasePath 10) "Synthetic seam ⏸️" "Synthetic seam ✅" validCorpus)
        , expectDiagnosticOnly
            "Phase 49 Claim, Subject, and title prose are semantically inert"
            phaseFortyNineProseDecoyCorpus
        , expectDiagnosticOnly
            "Substrate, Lane, and Register projections cannot supply hardware-ordering semantics"
            phaseProjectionSemanticDecoyCorpus
        ]
    )

validCorpus :: [(FilePath, Text)]
validCorpus =
  [(phasePath number, phaseDocument number) | number <- [0 .. 95]]
    <> [(trackerPath, trackerDocument [0 .. 95])]

dependencyLinkProseCorpus :: [(FilePath, Text)]
dependencyLinkProseCorpus =
  replaceIn
    (phasePath 10)
    (summaryLine "Depends on" (dependencyValue 10))
    (summaryLine "Depends on" (dependencyValue 10 <> " reviewer approval"))
    validCorpus

dependencyPathAliasCorpus :: [(FilePath, Text)]
dependencyPathAliasCorpus =
  replaceIn
    (phasePath 10)
    (summaryLine "Depends on" (dependencyValue 10))
    (summaryLine "Depends on" "[Phase 9](./phase_09_synthetic_capability.md)")
    validCorpus

trackerRowsWithoutFrameCorpus :: [(FilePath, Text)]
trackerRowsWithoutFrameCorpus =
  replaceDocument
    trackerPath
    (Text.unlines [trackerRow number (trackerStatusFor number) | number <- [0 .. 95]])
    validCorpus

trackerHeaderWildcardCorpus :: [(FilePath, Text)]
trackerHeaderWildcardCorpus =
  replaceIn
    trackerPath
    expectedTrackerHeader
    "| Phase | Title | Substrate | Lane | Register | Status | Contract |"
    validCorpus

trackerDelimiterShapeCorpus :: [(FilePath, Text)]
trackerDelimiterShapeCorpus =
  replaceIn
    trackerPath
    expectedTrackerDelimiter
    "|:---|---|---|---|---|---|---:|"
    validCorpus

reorderedTrackerCorpus :: [(FilePath, Text)]
reorderedTrackerCorpus =
  replaceIn
    trackerPath
    (trackerRow 7 blockedTrackerStatus <> "\n" <> trackerRow 8 blockedTrackerStatus)
    (trackerRow 8 blockedTrackerStatus <> "\n" <> trackerRow 7 blockedTrackerStatus)
    validCorpus

leadingZeroTrackerCorpus :: [(FilePath, Text)]
leadingZeroTrackerCorpus =
  replaceIn
    trackerPath
    (trackerRow 7 blockedTrackerStatus)
    (Text.replace "| 7 |" "| 07 |" (trackerRow 7 blockedTrackerStatus))
    validCorpus

extraCellTrackerCorpus :: [(FilePath, Text)]
extraCellTrackerCorpus =
  replaceIn
    trackerPath
    original
    (Text.dropEnd 1 original <> "| decoy |")
    validCorpus
 where
  original = trackerRow 7 blockedTrackerStatus

outsideExtraCellTrackerCorpus :: [(FilePath, Text)]
outsideExtraCellTrackerCorpus =
  replaceIn
    trackerPath
    (trackerRow 95 blockedTrackerStatus)
    (trackerRow 95 blockedTrackerStatus <> "\n\n| 7 | decoy | decoy | decoy | decoy | decoy | [Contract](decoy.md) | extra |")
    validCorpus

outsideMalformedTrackerCorpus :: [(FilePath, Text)]
outsideMalformedTrackerCorpus =
  replaceIn
    trackerPath
    (trackerRow 95 blockedTrackerStatus)
    (trackerRow 95 blockedTrackerStatus <> "\n\n| 7 | title | substrate | lane | register | status | [Contract](decoy.md)")
    validCorpus

trackerLinkProseCorpus :: [(FilePath, Text)]
trackerLinkProseCorpus =
  replaceIn
    trackerPath
    original
    (Text.replace "[Contract](" "prefix [Contract](" (Text.replace ") |" ") suffix |" original))
    validCorpus
 where
  original = trackerRow 7 blockedTrackerStatus

trackerPathAliasCorpus :: [(FilePath, Text)]
trackerPathAliasCorpus =
  replaceIn
    trackerPath
    (trackerRow 7 blockedTrackerStatus)
    (Text.replace "(phase_07" "(./phase_07" (trackerRow 7 blockedTrackerStatus))
    validCorpus

trackerProjectionSuffixCorpus :: [(FilePath, Text)]
trackerProjectionSuffixCorpus =
  replaceIn
    trackerPath
    (trackerRow 10 blockedTrackerStatus)
    (trackerRowWith 10 "none arbitrary-suffix" "none" "2" blockedTrackerStatus)
    validCorpus

trackerBlankSplitCorpus :: [(FilePath, Text)]
trackerBlankSplitCorpus =
  replaceIn trackerPath adjacent (firstRow <> "\n\n" <> secondRow) validCorpus
 where
  firstRow = trackerRow 10 blockedTrackerStatus
  secondRow = trackerRow 11 blockedTrackerStatus
  adjacent = firstRow <> "\n" <> secondRow

trackerFenceSplitCorpus :: [(FilePath, Text)]
trackerFenceSplitCorpus =
  replaceIn
    trackerPath
    adjacent
    (firstRow <> "\n```text\ninert\n```\n" <> secondRow)
    validCorpus
 where
  firstRow = trackerRow 10 blockedTrackerStatus
  secondRow = trackerRow 11 blockedTrackerStatus
  adjacent = firstRow <> "\n" <> secondRow

trackerCommentPrefixCorpus :: [(FilePath, Text)]
trackerCommentPrefixCorpus =
  replaceIn
    trackerPath
    (trackerRow 7 blockedTrackerStatus)
    ("<!-- inert -->" <> trackerRow 7 blockedTrackerStatus)
    validCorpus

trackerMultilineCommentCorpus :: [(FilePath, Text)]
trackerMultilineCommentCorpus =
  replaceDocument
    trackerPath
    ( "# Synthetic Development Plan Tracker\n\n<!--\n- comment-owned marker\n\n"
        <> trackerTable [0 .. 95]
        <> "\n-->\n\n"
    )
    validCorpus

trackerRawHtmlCorpora :: [(String, [(FilePath, Text)])]
trackerRawHtmlCorpora =
  [ ("type-1 script", rawHtmlTrackerCorpus "<script>" "</script>")
  , ("type-3 processing instruction", rawHtmlTrackerCorpus "<?synthetic" "?>")
  , ("type-4 CDATA", rawHtmlTrackerCorpus "<![CDATA[" "]]>")
  , ("type-5 declaration", rawHtmlTrackerCorpus "<!DOCTYPE" ">")
  , ("type-6 block tag", rawHtmlTrackerCorpus "<div>" "</div>")
  , ("type-7 complete custom tag", rawHtmlTrackerCorpus "<synthetic-tag>" "</synthetic-tag>")
  ]

rawHtmlTrackerCorpus :: Text -> Text -> [(FilePath, Text)]
rawHtmlTrackerCorpus opener closer =
  replaceDocument
    trackerPath
    ( "# Synthetic Development Plan Tracker\n\n"
        <> opener
        <> "\n"
        <> trackerTable [0 .. 95]
        <> "\n"
        <> closer
        <> "\n\n"
    )
    validCorpus

indentedTrackerCorpus :: Text -> [(FilePath, Text)]
indentedTrackerCorpus indent =
  replaceDocument
    trackerPath
    ( "# Synthetic Development Plan Tracker\n\n"
        <> Text.unlines [indent <> line | line <- Text.lines (trackerTable [0 .. 95])]
    )
    validCorpus

listContainedTrackerCorpus :: [(FilePath, Text)]
listContainedTrackerCorpus =
  replaceDocument
    trackerPath
    ( "# Synthetic Development Plan Tracker\n\n- tracker container\n"
        <> Text.unlines ["  " <> line | line <- Text.lines (trackerTable [0 .. 95])]
    )
    validCorpus

blockquoteContainedTrackerCorpus :: [(FilePath, Text)]
blockquoteContainedTrackerCorpus =
  replaceDocument
    trackerPath
    ( "# Synthetic Development Plan Tracker\n\n"
        <> Text.unlines ["> " <> line | line <- Text.lines (trackerTable [0 .. 95])]
    )
    validCorpus

trackerTable :: [Int] -> Text
trackerTable numbers =
  Text.unlines
    ( [expectedTrackerHeader, expectedTrackerDelimiter]
        <> [trackerRow number (trackerStatusFor number) | number <- numbers]
    )

trackerStatusFor :: Int -> Text
trackerStatusFor number = if number == 0 then activeTrackerStatus else blockedTrackerStatus

gateFenceSpliceCorpus, gateCommentDelimiterCorpus, gateIndentedDelimiterCorpus :: [(FilePath, Text)]
gateFenceSpliceCorpus =
  replaceIn
    (phasePath 7)
    (expectedGateHeader <> "\n" <> expectedGateDelimiter)
    (expectedGateHeader <> "\n```text\ninert\n```\n" <> expectedGateDelimiter)
    validCorpus
gateCommentDelimiterCorpus =
  replaceIn
    (phasePath 7)
    expectedGateDelimiter
    ("<!-- inert -->" <> expectedGateDelimiter)
    validCorpus
gateIndentedDelimiterCorpus =
  replaceIn (phasePath 7) expectedGateDelimiter ("    " <> expectedGateDelimiter) validCorpus

gateHeaderWildcardCorpus, gateDelimiterShapeCorpus :: [(FilePath, Text)]
gateHeaderWildcardCorpus =
  replaceIn
    (phasePath 7)
    expectedGateHeader
    "| Key | Phase-7 contract |"
    validCorpus
gateDelimiterShapeCorpus =
  replaceIn
    (phasePath 7)
    expectedGateDelimiter
    "|:---|---:|"
    validCorpus

gateRawHtmlCorpus, gateListContainedCorpus, gateBlockquoteContainedCorpus :: [(FilePath, Text)]
gateRawHtmlCorpus =
  replaceIn
    (phasePath 7)
    (gateTable 7)
    ("<script>\n" <> gateTable 7 <> "\n\n</script>")
    validCorpus
gateListContainedCorpus =
  replaceIn
    (phasePath 7)
    (gateTable 7)
    ("- gate container\n" <> Text.intercalate "\n" ["  " <> line | line <- Text.lines (gateTable 7)])
    validCorpus
gateBlockquoteContainedCorpus =
  replaceIn
    (phasePath 7)
    (gateTable 7)
    (Text.intercalate "\n" ["> " <> line | line <- Text.lines (gateTable 7)])
    validCorpus

gateThreeCellOutsideCorpus, gateMalformedOutsideCorpus, gateExtraDelimiterCorpus, gateBlankKeyCorpus, gateUnbacktickedKeyCorpus :: [(FilePath, Text)]
gateThreeCellOutsideCorpus =
  replaceIn
    (phasePath 7)
    (gateRow "Promotion authority" "Promotion authority requires an authorized reviewer.")
    (gateRow "Promotion authority" "Promotion authority requires an authorized reviewer." <> "\n\n| decoy | outside | extra |")
    validCorpus
gateMalformedOutsideCorpus =
  replaceIn
    (phasePath 7)
    (gateRow "Promotion authority" "Promotion authority requires an authorized reviewer.")
    (gateRow "Promotion authority" "Promotion authority requires an authorized reviewer." <> "\n\n| malformed gate candidate")
    validCorpus
gateExtraDelimiterCorpus =
  replaceIn
    (phasePath 7)
    (gateRow "Claim" standardClaim <> "\n" <> gateRow "Subject" standardSubject)
    (gateRow "Claim" standardClaim <> "\n|---|---|\n" <> gateRow "Subject" standardSubject)
    validCorpus
gateBlankKeyCorpus =
  replaceIn
    (phasePath 7)
    (gateRow "Claim" standardClaim <> "\n" <> gateRow "Subject" standardSubject)
    (gateRow "Claim" standardClaim <> "\n| | decoy |\n" <> gateRow "Subject" standardSubject)
    validCorpus
gateUnbacktickedKeyCorpus =
  replaceIn
    (phasePath 7)
    (gateRow "Claim" standardClaim)
    ("| Claim | " <> standardClaim <> " |")
    validCorpus

gateIndentedHeadingCorpus, listContainedStatusCorpus, listContainedSummaryCorpus, listContainedSprintCorpus :: [(FilePath, Text)]
gateIndentedHeadingCorpus =
  replaceIn (phasePath 7) "## Gate integrity" "    ## Gate integrity" validCorpus
listContainedStatusCorpus =
  replaceIn
    (phasePath 10)
    blockedStatus
    ("- status container\n  " <> blockedStatus)
    validCorpus
listContainedSummaryCorpus =
  replaceIn
    (phasePath 10)
    (summaryLine "Substrate" (substrateValue 10))
    ("- summary container\n  " <> summaryLine "Substrate" (substrateValue 10))
    validCorpus
listContainedSprintCorpus =
  replaceIn
    (phasePath 10)
    (sprintFieldLine "Status" "Blocked — NOT VALIDATED")
    ("- sprint container\n  " <> sprintFieldLine "Status" "Blocked — NOT VALIDATED")
    validCorpus

gateTable :: Int -> Text
gateTable number =
  Text.intercalate "\n" ([expectedGateHeader, expectedGateDelimiter] <> gateRows number)

twoSprintCorpus :: [(FilePath, Text)]
twoSprintCorpus =
  insertBefore
    (phasePath 10)
    "## Documentation Requirements"
    (sprintBlock 10 2 "Blocked — NOT VALIDATED" "Sprint 10.1")
    validCorpus

resourceSectionCorpus :: [(FilePath, Text)]
resourceSectionCorpus =
  insertBefore
    (phasePath 10)
    "## Doctrine adopted"
    "## Resource provision — synthetic diagnostic\n\nSynthetic structural inventory only.\n\n"
    validCorpus

requiresCorpus :: [(FilePath, Text)]
requiresCorpus =
  replaceIn
    (phasePath 10)
    (sprintFieldLine "Blocked by" (phaseApprovalBlocker 9))
    ( sprintFieldLine "Blocked by" (phaseApprovalBlocker 9)
        <> "\n"
        <> sprintFieldLine "Requires" "natural-linux-cpu-amd64-host"
    )
    validCorpus

markerCorpus :: [(FilePath, Text)]
markerCorpus =
  replaceIn
    (phasePath 9)
    (gateRow "Oracle" standardOracle)
    (gateRow "Oracle" "`MISSING`")
    ( replaceIn
        (phasePath 8)
        (gateRow "Oracle" standardOracle)
        (gateRow "Oracle" "UNRESOLVED")
        validCorpus
    )

gateSemanticProseDecoyCorpus :: [(FilePath, Text)]
gateSemanticProseDecoyCorpus =
  replaceIn
    (phasePath 10)
    (gateRow "Promotion authority" "Promotion authority requires an authorized reviewer.")
    (gateRow "Promotion authority" "This reader-facing explanation carries no executable policy value.")
    ( replaceIn
        (phasePath 10)
        (gateRow "Residue" "Later layers remain UNVERIFIED.")
        (gateRow "Residue" "This reader-facing explanation carries no executable coverage value.")
        ( replaceIn
            (phasePath 10)
            (gateRow "Predecessor" "Phase 09")
            (gateRow "Predecessor" "This reader-facing explanation carries no executable dependency value.")
            ( replaceIn
                (phasePath 10)
                (gateRow "Command" (commandValue 10))
                (gateRow "Command" (commandValue 10 <> "; Python and tools/ are inert explanatory decoys."))
                validCorpus
            )
        )
    )

phaseFortyNineProseDecoyCorpus :: [(FilePath, Text)]
phaseFortyNineProseDecoyCorpus =
  replaceIn
    trackerPath
    "| 49 | No-hardware DSL promotion barrier |"
    "| 49 | Semantically opaque prose |"
    ( replaceIn
        (phasePath 49)
        "# Phase 49: No-hardware DSL promotion barrier"
        "# Phase 49: Semantically opaque prose"
        ( replaceIn
            (phasePath 49)
            (gateRow "Subject" phaseFortyNineSubject)
            (gateRow "Subject" "Harbor and registry:2 are inert prose decoys, not executable provider values.")
            ( replaceIn
                (phasePath 49)
                (gateRow "Claim" phaseFortyNineClaim)
                (gateRow "Claim" "Module names and fake-apply keywords in this prose carry no executable semantics.")
                validCorpus
            )
        )
    )

phaseProjectionSemanticDecoyCorpus :: [(FilePath, Text)]
phaseProjectionSemanticDecoyCorpus =
  replaceIn
    trackerPath
    (trackerRowWith 52 "linux-cpu" "linux-cpu/amd64" "3" blockedTrackerStatus)
    (trackerRowWith 52 "none" "none" "2" blockedTrackerStatus)
    ( replaceIn
        (phasePath 52)
        "**Substrate:** linux-cpu\n\n**Lane:** linux-cpu/amd64\n\n**Register:** 3"
        "**Substrate:** none\n\n**Lane:** none\n\n**Register:** 2"
        ( replaceIn
            trackerPath
            (trackerRowWith 51 "none" "none" "2" blockedTrackerStatus)
            (trackerRowWith 51 "linux-cpu" "cuda" "3" blockedTrackerStatus)
            ( replaceIn
                (phasePath 51)
                "**Substrate:** none\n\n**Lane:** none\n\n**Register:** 2"
                "**Substrate:** linux-cpu\n\n**Lane:** cuda\n\n**Register:** 3"
                validCorpus
            )
        )
    )

phaseDocument :: Int -> Text
phaseDocument number =
  Text.unlines
    ( [ "# Phase " <> showText number <> ": " <> phaseTitle number
      , ""
      , "## Contents"
      , ""
      , "Synthetic contents."
      , ""
      , "## Phase Status"
      , ""
      , if number == 0 then activeStatus else blockedStatus
      , ""
      , "## Phase Summary"
      , ""
      , "**Phase scope:** One synthetic Haskell target capability."
      , ""
      , "**Substrate:** " <> substrateValue number
      , ""
      , "**Lane:** " <> laneValue number
      , ""
      , "**Register:** " <> registerValue number
      , ""
      , "**Depends on:** " <> dependencyValue number
      , ""
      , gateSummaryLine number
      , ""
      , "## Gate integrity"
      , ""
      , expectedGateHeader
      , expectedGateDelimiter
      ]
        <> gateRows number
        <> [ ""
           , "## Doctrine adopted"
           , ""
           , "Synthetic doctrine citation."
           , ""
           , "## Sprints"
           ]
        <> Text.lines
          ( sprintBlock
              number
              1
              (if number == 0 then "Active — NOT VALIDATED" else "Blocked — NOT VALIDATED")
              (if number == 0 then "`genesis`" else phaseApprovalBlocker (number - 1))
          )
        <> [ "## Documentation Requirements"
           , ""
           , "Synthetic documentation requirement."
           , ""
           , "## Related Documents"
           , ""
           , "Synthetic related document."
           ]
    )

gateRows :: Int -> [Text]
gateRows number =
  zipWith gateRow expectedGateKeys (gateValues number)

gateValues :: Int -> [Text]
gateValues number =
  [ if number == 49 then phaseFortyNineClaim else standardClaim
  , if number == 49 then phaseFortyNineSubject else standardSubject
  , commandValue number
  , standardOracle
  , "A legal control remains green."
  , "A one-defect negative must turn red."
  , "A production-locus mutation must be observed."
  , "The complete supplied corpus is enumerated."
  , standardChallenge
  , "The observer is separate from the subject."
  , "No alternate verdict authority exists."
  , "The candidate binds the supplied source snapshot."
  , "Qualification remains a separate component."
  , "Generated material begins absent."
  , "Active owner-phase rows must reach zero."
  , if number == 0 then "genesis" else "Phase " <> formatPhase (number - 1)
  , "Later layers remain UNVERIFIED."
  , "Promotion authority requires an authorized reviewer."
  ]

expectedGateKeys :: [Text]
expectedGateKeys =
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
  , "Legacy closure"
  , "Predecessor"
  , "Residue"
  , "Promotion authority"
  ]

expectedGateHeader :: Text
expectedGateHeader = "| Key | Contract |"

expectedGateDelimiter :: Text
expectedGateDelimiter = "|---|---|"

gateRow :: Text -> Text -> Text
gateRow key value = "| `" <> key <> "` | " <> value <> " |"

expectedTrackerHeader, expectedTrackerDelimiter :: Text
expectedTrackerHeader =
  "| Phase | Name | Substrate | Lane | Register | Status | Validation contract |"
expectedTrackerDelimiter = "|---|---|---|---|---|---|---|"

standardClaim :: Text
standardClaim = "The Haskell target capability satisfies its frozen claim."

standardSubject :: Text
standardSubject = "Amoebius.Target"

standardOracle :: Text
standardOracle = "An independently authored Haskell expectation decides the claim."

standardChallenge :: Text
standardChallenge = "The paired negative changes exactly one semantic fact."

phaseFortyNineClaim :: Text
phaseFortyNineClaim =
  "The hardware-free Haskell spine is decode → legality → bind/expand → plan/resolve → provision → renderAll → plan → dry-run → fake-apply."

phaseFortyNineSubject :: Text
phaseFortyNineSubject =
  Text.intercalate
    ", "
    [ "Amoebius.Dsl.Decode"
    , "Amoebius.Dsl.Foreclosure"
    , "Amoebius.Capability.Binding"
    , "Amoebius.Capacity.Provision"
    , "Amoebius.Manifest.RenderAll"
    , "Amoebius.Kernel.Chain"
    , "Amoebius.Kernel.Plan"
    , "Amoebius.Exec.Boundary"
    , "Amoebius.Validation.DslBarrier"
    ]

phaseTitle :: Int -> Text
phaseTitle 49 = "No-hardware DSL promotion barrier"
phaseTitle number = "Synthetic capability " <> showText number

phasePath :: Int -> FilePath
phasePath number =
  "DEVELOPMENT_PLAN/phase_"
    <> Text.unpack (formatPhase number)
    <> "_synthetic_capability.md"

phaseApprovalBlocker :: Int -> Text
phaseApprovalBlocker predecessor =
  "[Phase "
    <> showText predecessor
    <> "](phase_"
    <> formatPhase predecessor
    <> "_synthetic_capability.md) reviewer approval"

dependencyValue :: Int -> Text
dependencyValue 0 = "genesis"
dependencyValue number =
  "[Phase "
    <> showText (number - 1)
    <> "](phase_"
    <> formatPhase (number - 1)
    <> "_synthetic_capability.md)"

commandValue :: Int -> Text
commandValue number = "`pb validate phase " <> formatPhase number <> "`"

gateSummaryLine :: Int -> Text
gateSummaryLine number =
  "**Gate:** " <> commandValue number <> "; see [Gate integrity](#gate-integrity). NOT VALIDATED."

sprintBlock :: Int -> Int -> Text -> Text -> Text
sprintBlock phaseNumberValue sprintNumber status blocker =
  Text.unlines
    [ ""
    , "## Sprint "
        <> showText phaseNumberValue
        <> "."
        <> showText sprintNumber
        <> ": Synthetic seam "
        <> if status == "Active — NOT VALIDATED" then "🔄" else "⏸️"
    , ""
    , sprintFieldLine "Status" status
    , sprintFieldLine "Implementation" "src/Synthetic.hs"
    , sprintFieldLine "Blocked by" blocker
    , sprintFieldLine "Independent Validation" syntheticValidation
    , sprintFieldLine "Oracle" syntheticOracle
    , sprintFieldLine "Legacy IDs" "none"
    , sprintFieldLine "Docs to update" syntheticDocs
    , ""
    , "### Objective"
    , ""
    , "Synthetic objective."
    , ""
    , "### Deliverables"
    , ""
    , "Synthetic deliverable."
    , ""
    , "### Validation"
    , ""
    , "Synthetic validation details."
    , ""
    , "### Remaining Work"
    , ""
    , "Synthetic residue."
    , ""
    ]

sprintFieldLine :: Text -> Text -> Text
sprintFieldLine name value = "**" <> name <> "**: " <> value

syntheticValidation :: Text
syntheticValidation = "Independent positive, paired negative, changed-subject mutant, and residue observation."

syntheticOracle :: Text
syntheticOracle = "test/SyntheticOracle.hs, independent literal expectation, authorized reviewer."

syntheticDocs :: Text
syntheticDocs = "documents/engineering/synthetic_doctrine.md"

substrateValue :: Int -> Text
substrateValue number
  | number <= 51 = "none"
  | otherwise = "linux-cpu"

laneValue :: Int -> Text
laneValue number
  | number <= 51 = "none"
  | otherwise = "linux-cpu/amd64"

registerValue :: Int -> Text
registerValue number
  | number <= 51 = "2"
  | otherwise = "3"

activeStatus :: Text
activeStatus = "🔄 Active — NOT VALIDATED."

blockedStatus :: Text
blockedStatus = "⏸️ Blocked — NOT VALIDATED."

activeTrackerStatus :: Text
activeTrackerStatus = "🔄 Active — NOT VALIDATED"

blockedTrackerStatus :: Text
blockedTrackerStatus = "⏸️ Blocked — NOT VALIDATED"

trackerDocument :: [Int] -> Text
trackerDocument numbers =
  Text.unlines
    ( [ "# Synthetic Development Plan Tracker"
      , ""
      , expectedTrackerHeader
      , expectedTrackerDelimiter
      ]
        <> [trackerRow number (if number == 0 then activeTrackerStatus else blockedTrackerStatus) | number <- numbers]
    )

trackerRow :: Int -> Text -> Text
trackerRow number =
  trackerRowWith number (substrateValue number) (laneValue number) (registerValue number)

trackerRowWith :: Int -> Text -> Text -> Text -> Text -> Text
trackerRowWith number substrate lane register status =
  "| "
    <> showText number
    <> " | "
    <> phaseTitle number
    <> " | "
    <> substrate
    <> " | "
    <> lane
    <> " | "
    <> register
    <> " | "
    <> status
    <> " | [Contract](phase_"
    <> formatPhase number
    <> "_synthetic_capability.md) |"

trackerPath :: FilePath
trackerPath = "DEVELOPMENT_PLAN/README.md"

planRoot :: FilePath
planRoot = "DEVELOPMENT_PLAN/"

-- These are literal oracle-owned universes.  They are intentionally not
-- imported from PhaseContract: changing a production universe must redden an
-- independently retained expectation or one of its paired negatives.
expectedPhaseSectionNames :: [Text]
expectedPhaseSectionNames =
  [ "Contents"
  , "Phase Status"
  , "Phase Summary"
  , "Gate integrity"
  , "Resource provision"
  , "Doctrine adopted"
  , "Sprints"
  , "Documentation Requirements"
  , "Related Documents"
  ]

expectedSummaryFieldNames :: [Text]
expectedSummaryFieldNames = ["Phase scope", "Substrate", "Lane", "Register", "Depends on", "Gate"]

expectedSubstrates :: [Text]
expectedSubstrates = ["none", "apple", "linux-cpu", "linux-cuda", "windows"]

expectedLanes :: [Text]
expectedLanes = ["none", "linux-cpu/amd64", "linux-cpu/arm64", "metal", "cuda", "provider"]

expectedRegisters :: [Text]
expectedRegisters = ["—", "1", "2", "3"]

expectedCurrentStatusForms :: [Text]
expectedCurrentStatusForms =
  [ "✅ Done"
  , "🔄 Active — NOT VALIDATED"
  , "📋 Planned — NOT VALIDATED"
  , "⏸️ Blocked — NOT VALIDATED"
  , "🧪 Live-proof pending — NOT VALIDATED"
  ]

expectedSprintFieldNames :: [Text]
expectedSprintFieldNames =
  [ "Status"
  , "Implementation"
  , "Blocked by"
  , "Requires"
  , "Independent Validation"
  , "Oracle"
  , "Legacy IDs"
  , "Docs to update"
  ]

expectedSprintSubsectionNames :: [Text]
expectedSprintSubsectionNames = ["Objective", "Deliverables", "Validation", "Remaining Work"]

phaseContractExactCaseProblems :: String -> [String]
phaseContractExactCaseProblems exactCase =
  case exactCase of
    "check-name" ->
      expectCheckName
        "selector case: exact component check name"
        "phase-contracts"
        (phaseContractDiagnostic validCorpus)
    "dependency-result-composition" ->
      expectAnyFindingCode
        "selector case: dependency findings retain their result route"
        ["PLAN-DEPENDENCY", "PLAN-DEPENDENCY-FORWARD"]
        ( phaseContractDiagnostic
            ( replaceIn
                (phasePath 0)
                "**Depends on:** genesis"
                "**Depends on:** `genesis`"
                (replaceIn (phasePath 10) (dependencyValue 10) "[Phase 9](phase_10_synthetic_capability.md)" validCorpus)
            )
        )
    "dependency-forward" ->
      expectFinding
        "selector case: dependency same-or-forward edge"
        "PLAN-DEPENDENCY-FORWARD"
        (phasePath 10)
        (replaceIn (phasePath 10) (dependencyValue 10) "[Phase 9](phase_10_synthetic_capability.md)" validCorpus)
    "dependency-genesis" ->
      expectFinding
        "selector case: Phase 0 genesis dependency"
        "PLAN-DEPENDENCY"
        (phasePath 0)
        (replaceIn (phasePath 0) "**Depends on:** genesis" "**Depends on:** `genesis`" validCorpus)
    "dependency-link-finding" ->
      expectFinding
        "selector case: malformed dependency link retains its finding"
        "PLAN-DEPENDENCY-LINK"
        (phasePath 10)
        (replaceIn (phasePath 10) (dependencyValue 10) "[Phase 9](phase_09_synthetic_capability.md" validCorpus)
    "dependency-link-label" ->
      expectFinding
        "selector case: dependency link label"
        "PLAN-DEPENDENCY-LINK"
        (phasePath 10)
        (replaceIn (phasePath 10) (dependencyValue 10) "[Earlier phase](phase_09_synthetic_capability.md)" validCorpus)
    "dependency-link-prose" ->
      expectFinding "selector case: dependency link prose" "PLAN-DEPENDENCY-LINK" (phasePath 10) dependencyLinkProseCorpus
    "dependency-predecessor" ->
      expectFinding
        "selector case: dependency immediate predecessor"
        "PLAN-DEPENDENCY-PREDECESSOR"
        (phasePath 10)
        (replaceIn (phasePath 10) (dependencyValue 10) "[Phase 8](phase_08_synthetic_capability.md)" validCorpus)
    "gate-command" ->
      expectFinding
        "selector case: exact canonical gate command"
        "PLAN-GATE-COMMAND"
        (phasePath 9)
        (replaceIn (phasePath 9) (gateRow "Command" (commandValue 9)) (gateRow "Command" "`pb validate phase 9`") validCorpus)
    "gate-command-count" ->
      let expected = commandValue 9
          duplicateInsideOpaqueSpan = expected <> " plus ``opaque " <> expected <> "``"
       in expectFinding
            "selector case: canonical gate command occurs exactly once"
            "PLAN-GATE-COMMAND"
            (phasePath 9)
            (replaceIn (phasePath 9) (gateRow "Command" expected) (gateRow "Command" duplicateInsideOpaqueSpan) validCorpus)
    "gate-delimiter-shape" ->
      expectFinding "selector case: gate delimiter shape" "PLAN-GATE-TABLE-FRAME" (phasePath 7) gateDelimiterShapeCorpus
    "gate-end-content" ->
      expectFinding
        "selector case: nonblank content cannot continue the completed gate table"
        "PLAN-GATE-TABLE-FRAME"
        (phasePath 7)
        ( replaceIn
            (phasePath 7)
            (gateRow "Promotion authority" "Promotion authority requires an authorized reviewer.")
            (gateRow "Promotion authority" "Promotion authority requires an authorized reviewer." <> "\ntrailing gate content")
            validCorpus
        )
    "gate-header-wildcard" ->
      expectFinding "selector case: gate header wildcard" "PLAN-GATE-TABLE-FRAME" (phasePath 7) gateHeaderWildcardCorpus
    "gate-ignored-row" ->
      expectFinding "selector case: ignored gate row" "PLAN-GATE-TABLE-FRAME" (phasePath 7) gateExtraDelimiterCorpus
    "gate-incomplete-rows" ->
      expectFinding
        "selector case: gate section ends before all rows"
        "PLAN-GATE-TABLE-FRAME"
        (phasePath 7)
        ( replaceIn
            (phasePath 7)
            (gateRow "Promotion authority" "Promotion authority requires an authorized reviewer." <> "\n\n## Doctrine adopted")
            "## Doctrine adopted"
            validCorpus
        )
    "gate-key-code" ->
      expectFinding "selector case: gate key code delimiters" "PLAN-GATE-TABLE-FRAME" (phasePath 7) gateUnbacktickedKeyCorpus
    "gate-missing-delimiter" ->
      expectFinding
        "selector case: gate header at section end retains the missing-delimiter finding"
        "PLAN-GATE-TABLE-FRAME"
        (phasePath 7)
        ( replaceIn
            (phasePath 7)
            (gateTable 7 <> "\n\n## Doctrine adopted")
            (expectedGateHeader <> "\n## Doctrine adopted")
            validCorpus
        )
    "gate-missing-header" ->
      expectFinding
        "selector case: gate frame requires its exact header"
        "PLAN-GATE-TABLE-FRAME"
        (phasePath 7)
        (replaceIn (phasePath 7) (gateTable 7) "No gate table." validCorpus)
    "gate-outside-row" ->
      expectFinding
        "selector case: gate row after the completed frame"
        "PLAN-GATE-TABLE-FRAME"
        (phasePath 7)
        ( replaceIn
            (phasePath 7)
            (gateRow "Promotion authority" "Promotion authority requires an authorized reviewer.")
            (gateRow "Promotion authority" "Promotion authority requires an authorized reviewer." <> "\n\n" <> gateRow "Decoy" "outside")
            validCorpus
        )
    "gate-result-composition" ->
      expectAnyFindingCode
        "selector case: Gate findings retain their result route"
        ["PLAN-GATE-TABLE-FRAME", "PLAN-GATE-COMMAND"]
        ( phaseContractDiagnostic
            ( replaceIn
                (phasePath 9)
                (gateRow "Command" (commandValue 9))
                (gateRow "Command" "`pb validate phase 9`")
                (replaceIn (phasePath 7) (gateRow "Challenge" standardChallenge) "" validCorpus)
            )
        )
    "gate-row-arity" ->
      let canonical = gateRow "Challenge" standardChallenge
       in expectFinding
            "selector case: gate row has exactly two cells"
            "PLAN-GATE-TABLE-FRAME"
            (phasePath 7)
            (replaceIn (phasePath 7) canonical (Text.dropEnd 1 canonical <> "| extra |") validCorpus)
    "gate-row-empty" ->
      expectFinding
        "selector case: empty gate contract cell"
        "PLAN-GATE-TABLE-FRAME"
        (phasePath 7)
        (replaceIn (phasePath 7) (gateRow "Challenge" standardChallenge) (gateRow "Challenge" "") validCorpus)
    "gate-row-count-observation" ->
      expectObservation
        "selector case: exact aggregate gate-row observation"
        "gate-row-count"
        "1728"
        (phaseContractDiagnostic validCorpus)
    "gate-section" ->
      expectFinding "selector case: Gate integrity section" "PLAN-GATE-SECTION" (phasePath 7) gateIndentedHeadingCorpus
    "gate-second-header" ->
      expectFinding
        "selector case: second exact gate header"
        "PLAN-GATE-TABLE-FRAME"
        (phasePath 7)
        (replaceIn (phasePath 7) expectedGateHeader (expectedGateHeader <> "\n" <> expectedGateHeader) validCorpus)
    "gate-shape" ->
      expectFinding
        "selector case: gate ordered row shape"
        "PLAN-GATE-SHAPE"
        (phasePath 7)
        (replaceIn (phasePath 7) (gateRow "Challenge" standardChallenge) "" validCorpus)
    "gate-summary-command" ->
      expectFinding
        "selector case: exact phase-summary gate command"
        "PLAN-GATE-SUMMARY-COMMAND"
        (phasePath 9)
        (replaceIn (phasePath 9) (gateSummaryLine 9) "**Gate:** `pb validate phase 9` — NOT VALIDATED." validCorpus)
    "gate-summary-raw-line-count" ->
      let expected = gateSummaryLine 9
       in expectFinding
            "selector case: the exact Gate summary raw line occurs once"
            "PLAN-GATE-SUMMARY-COMMAND"
            (phasePath 9)
            (replaceIn (phasePath 9) "## Related Documents" (expected <> "\n\n## Related Documents") validCorpus)
    "gate-summary-value" ->
      let expected = gateSummaryLine 9
          modified = replaceIn (phasePath 9) expected (expected <> " trailing") validCorpus
       in expectFinding
            "selector case: the parsed Gate summary value is exact"
            "PLAN-GATE-SUMMARY-COMMAND"
            (phasePath 9)
            (replaceIn (phasePath 9) "## Related Documents" (expected <> "\n\n## Related Documents") modified)
    "gate-table-frame" ->
      expectFinding "selector case: gate table frame" "PLAN-GATE-TABLE-FRAME" (phasePath 7) gateThreeCellOutsideCorpus
    "gate-unframed-row" ->
      expectFinding
        "selector case: a gate row cannot precede the exact frame"
        "PLAN-GATE-TABLE-FRAME"
        (phasePath 7)
        (replaceIn (phasePath 7) expectedGateHeader (gateRow "Decoy" "outside" <> "\n" <> expectedGateHeader) validCorpus)
    "input-document-limit" ->
      expectExactFindingInResult
        "selector case: document input limit"
        "PLAN-INPUT-DOCUMENT-LIMIT"
        "scratch/document-boundary.md"
        "document exceeds 524288 characters"
        documentLimitAttackResult
        <> expectObservation
          "selector case: document input stops before parse"
          "phase-contract-input-envelope"
          "refused-before-parse"
          documentLimitAttackResult
    "input-document-limit-observation" ->
      expectObservation
        "selector case: exact document-character ceiling observation"
        "phase-contract-input-document-character-limit"
        "524288"
        documentLimitAttackResult
    "input-envelope-finding-composition" ->
      expectAnyFindingCodeInResults
        "selector case: an envelope refusal finding retains its result route"
        ["PLAN-INPUT-ENTRY-LIMIT", "PLAN-INPUT-PATH-LIMIT", "PLAN-INPUT-DOCUMENT-LIMIT", "PLAN-INPUT-TOTAL-LIMIT"]
        envelopeAttackResults
    "input-envelope-observation" ->
      expectObservation
        "selector case: envelope refusal records pre-parse state"
        "phase-contract-input-envelope"
        "refused-before-parse"
        entryLimitAttackResult
    "input-envelope-observation-composition" ->
      expectAnyObservationKeySequence
        "selector case: an envelope refusal retains the complete observation-key route"
        [ "phase-contract-input-envelope"
        , "phase-contract-input-entry-limit"
        , "phase-contract-input-path-character-limit"
        , "phase-contract-input-document-character-limit"
        , "phase-contract-input-total-character-limit"
        ]
        envelopeAttackResults
    "input-entry-limit" ->
      expectExactFindingInResult
        "selector case: entry input limit"
        "PLAN-INPUT-ENTRY-LIMIT"
        planRoot
        "supplied phase-contract entry count exceeds 256"
        entryLimitAttackResult
        <> expectObservation
          "selector case: entry input stops before parse"
          "phase-contract-input-envelope"
          "refused-before-parse"
          entryLimitAttackResult
    "input-entry-limit-observation" ->
      expectObservation
        "selector case: exact entry ceiling observation"
        "phase-contract-input-entry-limit"
        "256"
        entryLimitAttackResult
    "input-path-limit" ->
      expectExactFindingInResult
        "selector case: path input limit"
        "PLAN-INPUT-PATH-LIMIT"
        "supplied-path"
        "entry 1 path exceeds 4096 characters"
        pathLimitAttackResult
        <> expectObservation
          "selector case: path input stops before parse"
          "phase-contract-input-envelope"
          "refused-before-parse"
          pathLimitAttackResult
    "input-path-limit-observation" ->
      expectObservation
        "selector case: exact path-character ceiling observation"
        "phase-contract-input-path-character-limit"
        "4096"
        pathLimitAttackResult
    "input-total-limit" ->
      expectExactFindingInResult
        "selector case: aggregate input limit"
        "PLAN-INPUT-TOTAL-LIMIT"
        planRoot
        "supplied phase-contract character total exceeds 8388608"
        totalLimitAttackResult
        <> expectObservation
          "selector case: aggregate input stops before parse"
          "phase-contract-input-envelope"
          "refused-before-parse"
          totalLimitAttackResult
    "input-total-limit-observation" ->
      expectObservation
        "selector case: exact aggregate-character ceiling observation"
        "phase-contract-input-total-character-limit"
        "8388608"
        totalLimitAttackResult
    "inline-code-width" ->
      expectFinding
        "selector case: the canonical command uses one-backtick inline code"
        "PLAN-GATE-COMMAND"
        (phasePath 9)
        (replaceIn (phasePath 9) (gateRow "Command" (commandValue 9)) (gateRow "Command" "```pb validate phase 09```") validCorpus)
    "link-target-character" ->
      expectFinding
        "selector case: tracker link destinations use only the closed character grammar"
        "PLAN-TRACKER-TABLE-FRAME"
        trackerPath
        (replaceIn trackerPath "phase_10_synthetic_capability.md)" "phase_10_synthetic_capability.md?)" validCorpus)
    "link-target-empty" ->
      let canonical = trackerRow 10 blockedTrackerStatus
       in expectFinding
            "selector case: closed Markdown link targets are non-empty"
            "PLAN-TRACKER-TABLE-FRAME"
            trackerPath
            (replaceIn trackerPath canonical (Text.replace "(phase_10_synthetic_capability.md)" "()" canonical) validCorpus)
    "link-trailing-content" ->
      let canonical = trackerRow 10 blockedTrackerStatus
       in expectFinding
            "selector case: closed Markdown links reject trailing cell content"
            "PLAN-TRACKER-TABLE-FRAME"
            trackerPath
            ( replaceIn
                trackerPath
                canonical
                (Text.replace "(phase_10_synthetic_capability.md)" "(phase_10_synthetic_capability.md)tail" canonical)
                validCorpus
            )
    "missing-marker-count-observation" ->
      expectObservation
        "selector case: exact missing-marker observation"
        "missing-marker-cell-count"
        "1"
        (phaseContractDiagnostic markerCorpus)
    "observation-result-composition" ->
      expectObservationKeySequence
        "selector case: structural observations retain their complete result route"
        [ "phase-document-count"
        , "tracker-row-count"
        , "gate-row-count"
        , "sprint-section-count"
        , "unresolved-marker-cell-count"
        , "missing-marker-cell-count"
        , "refusal-marker-cell-count"
        ]
        (phaseContractDiagnostic validCorpus)
    "phase-document-count-observation" ->
      expectObservation
        "selector case: exact phase-document observation"
        "phase-document-count"
        "96"
        (phaseContractDiagnostic validCorpus)
    "phase-domain-result-composition" ->
      expectAnyFindingCode
        "selector case: phase-domain findings retain their result route"
        ["PLAN-PHASE-DUPLICATE", "PLAN-PHASE-MISSING"]
        ( phaseContractDiagnostic
            ( filter ((/= phasePath 95) . fst) validCorpus
                <> [("DEVELOPMENT_PLAN/phase_10_duplicate.md", phaseDocument 10)]
            )
        )
    "phase-discovery" ->
      expectFinding "selector case: empty phase discovery" "PLAN-PHASE-DISCOVERY" planRoot []
    "phase-duplicate" ->
      expectFinding
        "selector case: duplicate phase ordinal"
        "PLAN-PHASE-DUPLICATE"
        "DEVELOPMENT_PLAN/phase_10_duplicate.md"
        (validCorpus <> [("DEVELOPMENT_PLAN/phase_10_duplicate.md", phaseDocument 10)])
    "phase-extra" ->
      expectFinding
        "selector case: phase above closed domain"
        "PLAN-PHASE-EXTRA"
        (phasePath 96)
        (validCorpus <> [(phasePath 96, phaseDocument 96)])
    "phase-missing" ->
      expectFinding
        "selector case: missing phase in closed domain"
        "PLAN-PHASE-MISSING"
        planRoot
        (filter ((/= phasePath 95) . fst) validCorpus)
    "phase-path-digit-width" ->
      expectFinding
        "selector case: phase filename requires a two-digit ordinal"
        "PLAN-PHASE-DISCOVERY"
        planRoot
        [("DEVELOPMENT_PLAN/phase_0_decoy.md", phaseDocument 0)]
    "phase-path-directory" ->
      expectFinding
        "selector case: phase-shaped decoy outside governed directory"
        "PLAN-PHASE-DISCOVERY"
        planRoot
        [("archive/phase_00_decoy.md", phaseDocument 0)]
    "phase-path-extension" ->
      expectFinding
        "selector case: phase filename requires the Markdown extension"
        "PLAN-PHASE-DISCOVERY"
        planRoot
        [("DEVELOPMENT_PLAN/phase_00_decoy.txt", phaseDocument 0)]
    "phase-path-prefix" ->
      expectFinding
        "selector case: phase filename requires the exact phase_ prefix"
        "PLAN-PHASE-DISCOVERY"
        planRoot
        [("DEVELOPMENT_PLAN/stage_00_decoy.md", phaseDocument 0)]
    "phase-path-separator" ->
      expectFinding
        "selector case: phase filename requires the ordinal separator"
        "PLAN-PHASE-DISCOVERY"
        planRoot
        [("DEVELOPMENT_PLAN/phase_00decoy.md", phaseDocument 0)]
    "phase-path-slug-character" ->
      expectFinding
        "selector case: phase filename slug uses lowercase snake-case characters"
        "PLAN-PHASE-DISCOVERY"
        planRoot
        [("DEVELOPMENT_PLAN/phase_00_Bad.md", phaseDocument 0)]
    "phase-path-slug-empty" ->
      expectFinding
        "selector case: phase filename slug is non-empty"
        "PLAN-PHASE-DISCOVERY"
        planRoot
        [("DEVELOPMENT_PLAN/phase_00_.md", phaseDocument 0)]
    "phase-path-slug-segment" ->
      expectFinding
        "selector case: phase filename slug has no empty snake-case segment"
        "PLAN-PHASE-DISCOVERY"
        planRoot
        [("DEVELOPMENT_PLAN/phase_00_bad__slug.md", phaseDocument 0)]
    "phase-section-shape" ->
      expectFinding
        "selector case: phase section shape"
        "PLAN-PHASE-SECTION-SHAPE"
        (phasePath 7)
        ( replaceIn
            (phasePath 7)
            "## Doctrine adopted\n\nSynthetic doctrine citation.\n\n## Sprints"
            "## Sprints\n\nSynthetic doctrine citation.\n\n## Doctrine adopted"
            validCorpus
        )
    "phase-status" ->
      expectFinding
        "selector case: phase status"
        "PLAN-PHASE-STATUS"
        (phasePath 10)
        (replaceIn (phasePath 10) blockedStatus activeStatus validCorpus)
    "phase-structure-result-composition" ->
      expectAnyFindingCode
        "selector case: phase-structure findings retain their result route"
        ["PLAN-PHASE-TITLE", "PLAN-PHASE-STATUS"]
        ( phaseContractDiagnostic
            ( replaceIn
                (phasePath 10)
                "# Phase 10: Synthetic capability 10"
                "# Unrelated heading"
                (replaceIn (phasePath 10) blockedStatus activeStatus validCorpus)
            )
        )
    "phase-title" ->
      expectFinding
        "selector case: exact phase H1 title"
        "PLAN-PHASE-TITLE"
        (phasePath 10)
        (replaceIn (phasePath 10) "# Phase 10: Synthetic capability 10" "# Unrelated heading" validCorpus)
    "phase-title-cardinality" ->
      expectFinding
        "selector case: phase H1 title cardinality"
        "PLAN-PHASE-TITLE"
        (phasePath 10)
        ( replaceIn
            (phasePath 10)
            "# Phase 10: Synthetic capability 10"
            "# Phase 10: Synthetic capability 10\n# Phase 10: Synthetic capability 10"
            validCorpus
        )
    "phase-title-empty" ->
      expectFinding
        "selector case: phase H1 title body is non-empty"
        "PLAN-PHASE-TITLE"
        (phasePath 10)
        (replaceIn (phasePath 10) "# Phase 10: Synthetic capability 10" "# Phase 10:" validCorpus)
    "phase-title-prefix" ->
      expectFinding
        "selector case: phase H1 uses the exact Phase prefix"
        "PLAN-PHASE-TITLE"
        (phasePath 10)
        (replaceIn (phasePath 10) "# Phase 10: Synthetic capability 10" "# Stage 10: Synthetic capability 10" validCorpus)
    "projection-vocabulary" ->
      expectFinding
        "selector case: projection vocabulary"
        "PLAN-PROJECTION-VOCABULARY"
        (phasePath 10)
        (replaceProjection 10 "Substrate" (substrateValue 10) "invented-substrate" validCorpus)
    "projection-result-composition" ->
      expectFinding
        "selector case: projection-vocabulary findings retain their result route"
        "PLAN-PROJECTION-VOCABULARY"
        (phasePath 10)
        (replaceProjection 10 "Substrate" (substrateValue 10) "invented-substrate" validCorpus)
    "refusal-marker-count-observation" ->
      expectObservation
        "selector case: exact combined refusal-marker observation"
        "refusal-marker-cell-count"
        "2"
        (phaseContractDiagnostic markerCorpus)
    "sprint-blocker" ->
      expectFinding
        "selector case: sprint blocker"
        "PLAN-SPRINT-BLOCKER"
        (phasePath 10)
        (replaceIn (phasePath 10) (sprintFieldLine "Blocked by" (phaseApprovalBlocker 9)) (sprintFieldLine "Blocked by" (phaseApprovalBlocker 8)) validCorpus)
    "sprint-blocker-genesis" ->
      expectFinding
        "selector case: genesis sprint blocker uses exact inline code"
        "PLAN-SPRINT-BLOCKER"
        (phasePath 0)
        (replaceIn (phasePath 0) (sprintFieldLine "Blocked by" "`genesis`") (sprintFieldLine "Blocked by" "genesis") validCorpus)
    "sprint-blocker-predecessor" ->
      expectFinding
        "selector case: first sprint predecessor blocker rejects appended dependencies"
        "PLAN-SPRINT-BLOCKER"
        (phasePath 10)
        ( replaceIn
            (phasePath 10)
            (sprintFieldLine "Blocked by" (phaseApprovalBlocker 9))
            (sprintFieldLine "Blocked by" (phaseApprovalBlocker 9 <> "; " <> phaseApprovalBlocker 8))
            validCorpus
        )
    "sprint-blocker-prior-sprint" ->
      expectFinding
        "selector case: later sprint blocker is its immediate prior sprint"
        "PLAN-SPRINT-BLOCKER"
        (phasePath 10)
        (replaceIn (phasePath 10) (sprintFieldLine "Blocked by" "Sprint 10.1") (sprintFieldLine "Blocked by" "Sprint 10.2") twoSprintCorpus)
    "sprint-heading-marker" ->
      expectFinding
        "selector case: sprint heading marker belongs to the closed status marker set"
        "PLAN-SPRINT-IDENTITY"
        (phasePath 10)
        (replaceIn (phasePath 10) "## Sprint 10.1: Synthetic seam ⏸️" "## Sprint 10.1: Synthetic seam ❌" validCorpus)
    "sprint-heading-ordinal-canonical" ->
      expectFinding
        "selector case: sprint heading ordinal has canonical unsigned spelling"
        "PLAN-SPRINT-IDENTITY"
        (phasePath 10)
        (replaceIn (phasePath 10) "## Sprint 10.1: Synthetic seam ⏸️" "## Sprint 10.01: Synthetic seam ⏸️" validCorpus)
    "sprint-heading-ordinal-positive" ->
      expectFinding
        "selector case: sprint heading ordinal is positive"
        "PLAN-SPRINT-IDENTITY"
        (phasePath 10)
        (replaceIn (phasePath 10) "## Sprint 10.1: Synthetic seam ⏸️" "## Sprint 10.0: Synthetic seam ⏸️" validCorpus)
    "sprint-heading-separator" ->
      expectFinding
        "selector case: sprint heading colon is followed by one space"
        "PLAN-SPRINT-IDENTITY"
        (phasePath 10)
        (replaceIn (phasePath 10) "## Sprint 10.1: Synthetic seam ⏸️" "## Sprint 10.1:Synthetic seam ⏸️" validCorpus)
    "sprint-heading-title-empty" ->
      expectFinding
        "selector case: sprint heading title is non-empty"
        "PLAN-SPRINT-IDENTITY"
        (phasePath 10)
        (replaceIn (phasePath 10) "## Sprint 10.1: Synthetic seam ⏸️" "## Sprint 10.1:  ⏸️" validCorpus)
    "sprint-identity" ->
      expectFinding
        "selector case: sprint phase identity"
        "PLAN-SPRINT-IDENTITY"
        (phasePath 10)
        (replaceIn (phasePath 10) "## Sprint 10.1:" "## Sprint 9.1:" validCorpus)
    "sprint-result-composition" ->
      expectAnyFindingCode
        "selector case: sprint findings retain their result route"
        ["PLAN-SPRINT-STATUS", "PLAN-SPRINT-BLOCKER"]
        ( phaseContractDiagnostic
            ( replaceIn
                (phasePath 10)
                (sprintFieldLine "Status" "Blocked — NOT VALIDATED")
                (sprintFieldLine "Status" "Validated — NOT VALIDATED")
                ( replaceIn
                    (phasePath 10)
                    (sprintFieldLine "Blocked by" (phaseApprovalBlocker 9))
                    (sprintFieldLine "Blocked by" (phaseApprovalBlocker 8))
                    validCorpus
                )
            )
        )
    "sprint-schema" ->
      expectFinding
        "selector case: sprint schema"
        "PLAN-SPRINT-SCHEMA"
        (phasePath 10)
        (replaceIn (phasePath 10) (sprintFieldLine "Oracle" syntheticOracle) "" validCorpus)
    "sprint-schema-field-nonempty" ->
      expectFinding
        "selector case: sprint schema fields are non-empty"
        "PLAN-SPRINT-SCHEMA"
        (phasePath 10)
        (replaceIn (phasePath 10) (sprintFieldLine "Docs to update" syntheticDocs) (sprintFieldLine "Docs to update" "") validCorpus)
    "sprint-schema-field-order" ->
      expectFinding
        "selector case: sprint schema fields retain exact order"
        "PLAN-SPRINT-SCHEMA"
        (phasePath 10)
        ( replaceIn
            (phasePath 10)
            (sprintFieldLine "Independent Validation" syntheticValidation <> "\n" <> sprintFieldLine "Oracle" syntheticOracle)
            (sprintFieldLine "Oracle" syntheticOracle <> "\n" <> sprintFieldLine "Independent Validation" syntheticValidation)
            validCorpus
        )
    "sprint-schema-late-field" ->
      expectFinding
        "selector case: known sprint fields cannot recur after the first subsection"
        "PLAN-SPRINT-SCHEMA"
        (phasePath 10)
        ( replaceIn
            (phasePath 10)
            "### Objective\n\nSynthetic objective."
            ("### Objective\n\n" <> sprintFieldLine "Oracle" syntheticOracle <> "\n\nSynthetic objective.")
            validCorpus
        )
    "sprint-schema-subsection-nonempty" ->
      expectFinding
        "selector case: sprint schema subsections are non-empty"
        "PLAN-SPRINT-SCHEMA"
        (phasePath 10)
        (replaceIn (phasePath 10) "### Validation\n\nSynthetic validation details." "### Validation" validCorpus)
    "sprint-schema-subsection-order" ->
      expectFinding
        "selector case: sprint schema subsections retain exact order"
        "PLAN-SPRINT-SCHEMA"
        (phasePath 10)
        ( replaceIn
            (phasePath 10)
            "### Deliverables\n\nSynthetic deliverable.\n\n### Validation\n\nSynthetic validation details."
            "### Validation\n\nSynthetic validation details.\n\n### Deliverables\n\nSynthetic deliverable."
            validCorpus
        )
    "sprint-section-count-observation" ->
      expectObservation
        "selector case: exact aggregate sprint-section observation"
        "sprint-section-count"
        "96"
        (phaseContractDiagnostic validCorpus)
    "sprint-status" ->
      expectFinding
        "selector case: sprint status"
        "PLAN-SPRINT-STATUS"
        (phasePath 10)
        (replaceIn (phasePath 10) (sprintFieldLine "Status" "Blocked — NOT VALIDATED") (sprintFieldLine "Status" "Validated — NOT VALIDATED") validCorpus)
    "structure-diagnostic-refusal" ->
      expectExactFindingInResult
        "selector case: permanent structure refusal"
        diagnosticRefusalCode
        planRoot
        diagnosticRefusalMessage
        (phaseContractDiagnostic validCorpus)
    "summary-containment" ->
      expectFinding
        "selector case: summary containment"
        "PLAN-SUMMARY-CONTAINMENT"
        (phasePath 7)
        (relocateAfter (phasePath 7) (summaryLine "Substrate" (substrateValue 7)) "## Related Documents" validCorpus)
    "summary-field" ->
      expectFinding
        "selector case: mandatory Phase Summary field"
        "PLAN-SUMMARY-FIELD"
        (phasePath 10)
        (replaceIn (phasePath 10) (summaryLine "Lane" (laneValue 10) <> "\n\n") "" validCorpus)
    "table-closing-pipe" ->
      let canonical = gateRow "Challenge" standardChallenge
       in expectFinding
            "selector case: exact table rows require a closing pipe"
            "PLAN-GATE-TABLE-FRAME"
            (phasePath 7)
            (replaceIn (phasePath 7) canonical (Text.dropEnd 1 canonical) validCorpus)
    "table-opening-pipe" ->
      let canonical = gateRow "Challenge" standardChallenge
       in expectFinding
            "selector case: exact table rows require an opening pipe"
            "PLAN-GATE-TABLE-FRAME"
            (phasePath 7)
            (replaceIn (phasePath 7) canonical (Text.drop 1 canonical) validCorpus)
    "tracker-cardinality" ->
      expectFinding
        "selector case: one tracker document"
        "PLAN-TRACKER-CARDINALITY"
        trackerPath
        (filter ((/= trackerPath) . fst) validCorpus)
    "tracker-comment-opacity" ->
      expectFinding
        "selector case: an HTML comment cannot supply a complete tracker"
        "PLAN-TRACKER-TABLE-FRAME"
        trackerPath
        (replaceDocument trackerPath ("<!--\n" <> trackerDocument [0 .. 95] <> "\n-->\n") validCorpus)
    "tracker-comment-splice" ->
      expectFinding "selector case: tracker comment splice" "PLAN-TRACKER-TABLE-FRAME" trackerPath trackerCommentPrefixCorpus
    "tracker-container-prefix" ->
      expectFinding "selector case: tracker container prefix" "PLAN-TRACKER-TABLE-FRAME" trackerPath listContainedTrackerCorpus
    "tracker-contract-join" ->
      expectFinding "selector case: tracker contract target join" "PLAN-TRACKER-CONTRACT" trackerPath trackerPathAliasCorpus
    "tracker-delimiter-boundary" ->
      expectFinding
        "selector case: an opaque boundary interrupts the expected tracker delimiter"
        "PLAN-TRACKER-TABLE-FRAME"
        trackerPath
        (replaceIn trackerPath expectedTrackerHeader (expectedTrackerHeader <> "\n> opaque boundary") validCorpus)
    "tracker-delimiter-shape" ->
      expectFinding "selector case: tracker delimiter shape" "PLAN-TRACKER-TABLE-FRAME" trackerPath trackerDelimiterShapeCorpus
    "tracker-end-boundary" ->
      expectFinding
        "selector case: an opaque boundary interrupts the tracker terminator"
        "PLAN-TRACKER-TABLE-FRAME"
        trackerPath
        (replaceIn trackerPath (trackerRow 95 blockedTrackerStatus) (trackerRow 95 blockedTrackerStatus <> "\n> opaque boundary") validCorpus)
    "tracker-end-content" ->
      expectFinding
        "selector case: nonblank content cannot continue the completed tracker table"
        "PLAN-TRACKER-TABLE-FRAME"
        trackerPath
        ( replaceIn
            trackerPath
            (trackerRow 95 blockedTrackerStatus)
            (trackerRow 95 blockedTrackerStatus <> "\ntrailing tracker content")
            validCorpus
        )
    "tracker-extra-cell" ->
      expectFinding "selector case: tracker extra cell" "PLAN-TRACKER-TABLE-FRAME" trackerPath extraCellTrackerCorpus
    "tracker-fence-boundary" ->
      expectFinding "selector case: tracker fence boundary" "PLAN-TRACKER-TABLE-FRAME" trackerPath trackerFenceSplitCorpus
    "tracker-fence-opacity" ->
      expectFinding
        "selector case: a fenced block cannot supply a complete tracker"
        "PLAN-TRACKER-TABLE-FRAME"
        trackerPath
        (replaceDocument trackerPath ("```text\n" <> trackerDocument [0 .. 95] <> "\n```\n") validCorpus)
    "tracker-frame-finding" ->
      expectFinding
        "selector case: tracker frame problems retain their finding projection"
        "PLAN-TRACKER-TABLE-FRAME"
        trackerPath
        trackerDelimiterShapeCorpus
    "tracker-header-wildcard" ->
      expectFinding "selector case: tracker header wildcard" "PLAN-TRACKER-TABLE-FRAME" trackerPath trackerHeaderWildcardCorpus
    "tracker-incomplete-rows" ->
      expectFinding
        "selector case: tracker ends before Phase 95"
        "PLAN-TRACKER-TABLE-FRAME"
        trackerPath
        (replaceDocument trackerPath (trackerDocument [0 .. 94]) validCorpus)
    "tracker-indented-code" ->
      expectFinding "selector case: tracker indented code" "PLAN-TRACKER-TABLE-FRAME" trackerPath (indentedTrackerCorpus "    ")
    "tracker-join-result-composition" ->
      expectAnyFindingCode
        "selector case: tracker-join findings retain their result route"
        ["PLAN-TRACKER-TITLE", "PLAN-TRACKER-CONTRACT"]
        ( phaseContractDiagnostic
            (replaceIn trackerPath "| 10 | Synthetic capability 10 |" "| 10 | Divergent title |" trackerPathAliasCorpus)
        )
    "tracker-link-label" ->
      let canonical = trackerRow 10 blockedTrackerStatus
       in expectFinding
            "selector case: tracker contract links retain the exact Contract label"
            "PLAN-TRACKER-TABLE-FRAME"
            trackerPath
            (replaceIn trackerPath canonical (Text.replace "[Contract]" "[Different]" canonical) validCorpus)
    "tracker-link-prose" ->
      expectFinding "selector case: tracker link prose" "PLAN-TRACKER-TABLE-FRAME" trackerPath trackerLinkProseCorpus
    "tracker-missing" ->
      expectFinding
        "selector case: tracker closed domain omission"
        "PLAN-TRACKER-MISSING"
        trackerPath
        (replaceDocument trackerPath (trackerDocument [0 .. 94]) validCorpus)
    "tracker-missing-delimiter" ->
      expectFinding
        "selector case: tracker header at end of file retains the missing-delimiter finding"
        "PLAN-TRACKER-TABLE-FRAME"
        trackerPath
        (replaceDocument trackerPath (expectedTrackerHeader <> "\n") validCorpus)
    "tracker-missing-header" ->
      expectFinding
        "selector case: tracker frame requires its exact header"
        "PLAN-TRACKER-TABLE-FRAME"
        trackerPath
        (replaceDocument trackerPath "No tracker table.\n" validCorpus)
    "tracker-outside-row" ->
      expectFinding
        "selector case: tracker row after the completed frame"
        "PLAN-TRACKER-TABLE-FRAME"
        trackerPath
        ( replaceIn
            trackerPath
            (trackerRow 95 blockedTrackerStatus)
            (trackerRow 95 blockedTrackerStatus <> "\n\n" <> trackerRow 0 activeTrackerStatus)
            validCorpus
        )
    "tracker-order" ->
      expectFinding "selector case: tracker order" "PLAN-TRACKER-TABLE-FRAME" trackerPath reorderedTrackerCorpus
    "tracker-ordinal-canonical" ->
      expectFinding "selector case: tracker ordinal canonical form" "PLAN-TRACKER-TABLE-FRAME" trackerPath leadingZeroTrackerCorpus
    "tracker-projection-join" ->
      expectFinding
        "selector case: tracker and phase projection join"
        "PLAN-TRACKER-PROJECTION"
        trackerPath
        (replaceIn trackerPath (trackerRow 10 blockedTrackerStatus) (trackerRowWith 10 "linux-cpu" "none" "2" blockedTrackerStatus) validCorpus)
    "tracker-projection-prefix" ->
      expectFinding "selector case: tracker projection prefix" "PLAN-TRACKER-PROJECTION" trackerPath trackerProjectionSuffixCorpus
    "tracker-result-composition" ->
      expectAnyFindingCode
        "selector case: tracker parser and shape findings retain their result route"
        ["PLAN-TRACKER-CARDINALITY", "PLAN-TRACKER-TABLE-FRAME", "PLAN-TRACKER-MISSING"]
        (phaseContractDiagnostic (filter ((/= trackerPath) . fst) validCorpus))
    "tracker-raw-html" ->
      expectFinding "selector case: tracker raw HTML" "PLAN-TRACKER-TABLE-FRAME" trackerPath (rawHtmlTrackerCorpus "<script>" "</script>")
    "tracker-row-boundary" ->
      expectFinding
        "selector case: an opaque boundary interrupts the expected tracker row"
        "PLAN-TRACKER-TABLE-FRAME"
        trackerPath
        (replaceIn trackerPath expectedTrackerDelimiter (expectedTrackerDelimiter <> "\n> opaque boundary") validCorpus)
    "tracker-row-empty" ->
      expectFinding
        "selector case: empty required tracker cell"
        "PLAN-TRACKER-TABLE-FRAME"
        trackerPath
        ( replaceIn
            trackerPath
            (trackerRow 10 blockedTrackerStatus)
            (Text.replace "| Synthetic capability 10 |" "|  |" (trackerRow 10 blockedTrackerStatus))
            validCorpus
        )
    "tracker-row-count-observation" ->
      expectObservation
        "selector case: exact tracker-row observation"
        "tracker-row-count"
        "96"
        (phaseContractDiagnostic validCorpus)
    "tracker-second-header" ->
      expectFinding
        "selector case: second exact tracker header"
        "PLAN-TRACKER-TABLE-FRAME"
        trackerPath
        (replaceIn trackerPath expectedTrackerHeader (expectedTrackerHeader <> "\n" <> expectedTrackerHeader) validCorpus)
    "tracker-status" ->
      expectFinding
        "selector case: tracker status reset"
        "PLAN-TRACKER-STATUS"
        trackerPath
        (replaceIn trackerPath (trackerRow 10 blockedTrackerStatus) (trackerRow 10 "Done") validCorpus)
    "tracker-title-join" ->
      expectFinding
        "selector case: tracker title and phase H1 join"
        "PLAN-TRACKER-TITLE"
        trackerPath
        (replaceIn trackerPath "| 10 | Synthetic capability 10 |" "| 10 | Divergent title |" validCorpus)
    "tracker-unframed-rows" ->
      expectFinding "selector case: unframed tracker rows" "PLAN-TRACKER-TABLE-FRAME" trackerPath trackerRowsWithoutFrameCorpus
    "unresolved-gate-cell" ->
      expectFinding
        "selector case: unresolved gate cell"
        "PLAN-GATE-UNRESOLVED"
        (phasePath 8)
        (replaceIn (phasePath 8) (gateRow "Oracle" standardOracle) (gateRow "Oracle" "UNRESOLVED") validCorpus)
    "unresolved-marker-count-observation" ->
      expectObservation
        "selector case: exact unresolved-marker observation"
        "unresolved-marker-cell-count"
        "1"
        (phaseContractDiagnostic markerCorpus)
    _ -> ["unknown PhaseContract exact case: " <> exactCase]
 where
  entryLimitAttackResult = phaseContractDiagnostic (replicate 257 ("scratch/repeated.md", ""))
  pathLimitAttackResult = phaseContractDiagnostic [(replicate 4094 'p' <> ".md", "")]
  documentLimitAttackResult = phaseContractDiagnostic [("scratch/document-boundary.md", Text.replicate 524289 "x")]
  totalLimitAttackResult =
    phaseContractDiagnostic
      ( [("scratch/total-" <> show ordinal <> ".md", Text.replicate 524288 "x") | ordinal <- [(1 :: Int) .. 16]]
          <> [("scratch/total-17.md", "x")]
      )
  envelopeAttackResults =
    [ entryLimitAttackResult
    , pathLimitAttackResult
    , documentLimitAttackResult
    , totalLimitAttackResult
    ]

oracleUniverseProblems :: [String]
oracleUniverseProblems =
  [ label <> ": independent literal universe has the wrong cardinality or a duplicate"
  | (label, expectedCount, values) <-
      [ ("phase sections", 9, expectedPhaseSectionNames)
      , ("summary fields", 6, expectedSummaryFieldNames)
      , ("substrates", 5, expectedSubstrates)
      , ("lanes", 6, expectedLanes)
      , ("registers", 4, expectedRegisters)
      , ("current statuses", 5, expectedCurrentStatusForms)
      , ("sprint fields", 8, expectedSprintFieldNames)
      , ("sprint subsections", 4, expectedSprintSubsectionNames)
      , ("gate keys", 18, expectedGateKeys)
      ]
  , length values /= expectedCount || not (allDistinct values)
  ]

oracleFixtureProblems :: [String]
oracleFixtureProblems =
  [ "tracker fixture does not carry the independently fixed exact header and delimiter"
  | take 2 (drop 2 (Text.lines (trackerDocument [0 .. 95])))
      /= [expectedTrackerHeader, expectedTrackerDelimiter]
  ]
    <> [ "gate fixture does not retain the independently fixed backticked Claim key"
       | listToMaybe (gateRows 0)
          /= Just "| `Claim` | The Haskell target capability satisfies its frozen claim. |"
       ]
    <> [ "tracker fixture row syntax drifted from the independently fixed seven-cell form"
       | trackerRow 7 blockedTrackerStatus
          /= "| 7 | Synthetic capability 7 | none | none | 2 | ⏸️ Blocked — NOT VALIDATED | [Contract](phase_07_synthetic_capability.md) |"
       ]
    <> mutantFixtureProblems

phaseContractResourceEnvelopeProblems :: [String]
phaseContractResourceEnvelopeProblems =
  concat
    [ expectNoFindingCode
        "the exact phase-contract entry limit remains admissible"
        "PLAN-INPUT-ENTRY-LIMIT"
        (phaseContractDiagnostic entryLimitControl)
    , expectExactFindingInResult
        "the first entry beyond the phase-contract limit refuses before parsing"
        "PLAN-INPUT-ENTRY-LIMIT"
        planRoot
        "supplied phase-contract entry count exceeds 256"
        (phaseContractDiagnostic entryLimitAttack)
    , expectObservation
        "the entry-limit refusal records that parsing did not begin"
        "phase-contract-input-envelope"
        "refused-before-parse"
        (phaseContractDiagnostic entryLimitAttack)
    , expectNoFindingCode
        "the exact phase-contract path-character limit remains admissible"
        "PLAN-INPUT-PATH-LIMIT"
        (phaseContractDiagnostic pathLimitControl)
    , expectExactFindingInResult
        "the first path character beyond the phase-contract limit refuses before parsing"
        "PLAN-INPUT-PATH-LIMIT"
        "supplied-path"
        "entry 1 path exceeds 4096 characters"
        (phaseContractDiagnostic pathLimitAttack)
    , expectObservation
        "the path-limit refusal records that parsing did not begin"
        "phase-contract-input-envelope"
        "refused-before-parse"
        (phaseContractDiagnostic pathLimitAttack)
    , expectNoFindingCode
        "the exact phase-contract document-character limit remains admissible"
        "PLAN-INPUT-DOCUMENT-LIMIT"
        (phaseContractDiagnostic documentLimitControl)
    , expectExactFindingInResult
        "the first document character beyond the phase-contract limit refuses before parsing"
        "PLAN-INPUT-DOCUMENT-LIMIT"
        "scratch/document-boundary.md"
        "document exceeds 524288 characters"
        (phaseContractDiagnostic documentLimitAttack)
    , expectObservation
        "the document-limit refusal records that parsing did not begin"
        "phase-contract-input-envelope"
        "refused-before-parse"
        (phaseContractDiagnostic documentLimitAttack)
    , expectNoFindingCode
        "the exact aggregate phase-contract character limit remains admissible"
        "PLAN-INPUT-TOTAL-LIMIT"
        (phaseContractDiagnostic totalLimitControl)
    , expectExactFindingInResult
        "the first aggregate character beyond the phase-contract limit refuses before parsing"
        "PLAN-INPUT-TOTAL-LIMIT"
        planRoot
        "supplied phase-contract character total exceeds 8388608"
        (phaseContractDiagnostic totalLimitAttack)
    , expectObservation
        "the aggregate-limit refusal records that parsing did not begin"
        "phase-contract-input-envelope"
        "refused-before-parse"
        (phaseContractDiagnostic totalLimitAttack)
    ]
 where
  entryLimitControl = replicate 256 ("scratch/repeated.md", "")
  entryLimitAttack = replicate 257 ("scratch/repeated.md", "")
  pathLimitControl = [(replicate 4093 'p' <> ".md", "")]
  pathLimitAttack = [(replicate 4094 'p' <> ".md", "")]
  documentLimitControl = [("scratch/document-boundary.md", Text.replicate 524288 "x")]
  documentLimitAttack = [("scratch/document-boundary.md", Text.replicate 524289 "x")]
  totalLimitControl =
    [("scratch/total-" <> show ordinal <> ".md", Text.replicate 524288 "x") | ordinal <- [(1 :: Int) .. 16]]
      <> [("scratch/total-17.md", "")]
  totalLimitAttack =
    [("scratch/total-" <> show ordinal <> ".md", Text.replicate 524288 "x") | ordinal <- [(1 :: Int) .. 16]]
      <> [("scratch/total-17.md", "x")]

mutantFixtureProblems :: [String]
mutantFixtureProblems =
  concatMap
    checkFixture
    [ ( "dependency closed-link bypass"
      , phasePath 10
      , dependencyLinkProseCorpus
      , [summaryLine "Depends on" (dependencyValue 10 <> " reviewer approval")]
      , []
      )
    , ( "fence-boundary bypass"
      , trackerPath
      , trackerFenceSplitCorpus
      , [trackerRow 10 blockedTrackerStatus <> "\n```text\ninert\n```\n" <> trackerRow 11 blockedTrackerStatus]
      , []
      )
    , ( "indented-code bypass"
      , trackerPath
      , indentedTrackerCorpus "    "
      , ["    " <> expectedTrackerHeader]
      , []
      )
    , ( "comment-splice bypass"
      , trackerPath
      , trackerCommentPrefixCorpus
      , ["<!-- inert -->" <> trackerRow 7 blockedTrackerStatus]
      , []
      )
    , ( "raw-HTML bypass"
      , trackerPath
      , rawHtmlTrackerCorpus "<script>" "</script>"
      , ["<script>\n" <> expectedTrackerHeader]
      , []
      )
    , ( "container-prefix bypass"
      , trackerPath
      , listContainedTrackerCorpus
      , ["- tracker container\n  " <> expectedTrackerHeader]
      , []
      )
    , ( "unframed tracker-row bypass"
      , trackerPath
      , trackerRowsWithoutFrameCorpus
      , [trackerRow 0 activeTrackerStatus]
      , [expectedTrackerHeader]
      )
    , ( "tracker-header wildcard"
      , trackerPath
      , trackerHeaderWildcardCorpus
      , ["| Phase | Title | Substrate | Lane | Register | Status | Contract |"]
      , [expectedTrackerHeader]
      )
    , ( "tracker-delimiter shape bypass"
      , trackerPath
      , trackerDelimiterShapeCorpus
      , ["|:---|---|---|---|---|---|---:|"]
      , [expectedTrackerDelimiter]
      )
    , ( "tracker extra-cell bypass"
      , trackerPath
      , extraCellTrackerCorpus
      , [Text.dropEnd 1 (trackerRow 7 blockedTrackerStatus) <> "| decoy |"]
      , []
      )
    , ( "tracker order bypass"
      , trackerPath
      , reorderedTrackerCorpus
      , [trackerRow 8 blockedTrackerStatus <> "\n" <> trackerRow 7 blockedTrackerStatus]
      , [trackerRow 7 blockedTrackerStatus <> "\n" <> trackerRow 8 blockedTrackerStatus]
      )
    , ( "tracker ordinal-canonical bypass"
      , trackerPath
      , leadingZeroTrackerCorpus
      , [Text.replace "| 7 |" "| 07 |" (trackerRow 7 blockedTrackerStatus)]
      , [trackerRow 7 blockedTrackerStatus]
      )
    , ( "tracker surrounding-link-prose bypass"
      , trackerPath
      , trackerLinkProseCorpus
      , ["prefix [Contract](phase_07_synthetic_capability.md) suffix"]
      , []
      )
    , ( "tracker projection-prefix bypass"
      , trackerPath
      , trackerProjectionSuffixCorpus
      , [trackerRowWith 10 "none arbitrary-suffix" "none" "2" blockedTrackerStatus]
      , []
      )
    , ( "gate-header wildcard"
      , phasePath 7
      , gateHeaderWildcardCorpus
      , ["| Key | Phase-7 contract |"]
      , [expectedGateHeader]
      )
    , ( "gate-delimiter shape bypass"
      , phasePath 7
      , gateDelimiterShapeCorpus
      , ["|:---|---:|"]
      , [expectedGateDelimiter]
      )
    , ( "gate ignored-row bypass"
      , phasePath 7
      , gateExtraDelimiterCorpus
      , [gateRow "Claim" standardClaim <> "\n|---|---|\n" <> gateRow "Subject" standardSubject]
      , []
      )
    , ( "gate key-code bypass"
      , phasePath 7
      , gateUnbacktickedKeyCorpus
      , ["| Claim | " <> standardClaim <> " |"]
      , [gateRow "Claim" standardClaim]
      )
    ]
 where
  checkFixture (label, expectedPath, corpus, required, forbidden) =
    [ label <> ": fixture changed the governed corpus inventory or ordering"
    | map fst corpus /= map fst validCorpus
    ]
      <> [ label <> ": fixture must change exactly " <> expectedPath <> ", observed " <> show changedPaths
         | changedPaths /= [expectedPath]
         ]
      <> [ label <> ": required attack literal is not unique: " <> show needle
         | needle <- required
         , maybe True ((/= 1) . Text.count needle) mutatedDocument
         ]
      <> [ label <> ": forbidden baseline literal survived: " <> show needle
         | needle <- forbidden
         , maybe False (Text.isInfixOf needle) mutatedDocument
         ]
   where
    changedPaths =
      [ path
      | (path, baseline) <- validCorpus
      , lookup path corpus /= Just baseline
      ]
    mutatedDocument = lookup expectedPath corpus

allDistinct :: Eq value => [value] -> Bool
allDistinct [] = True
allDistinct (value : rest) = value `notElem` rest && allDistinct rest

formatPhase :: Int -> Text
formatPhase number
  | number < 10 = "0" <> showText number
  | otherwise = showText number

showText :: Show value => value -> Text
showText = Text.pack . show

replaceIn :: FilePath -> Text -> Text -> [(FilePath, Text)] -> [(FilePath, Text)]
replaceIn wanted old new =
  map
    ( \entry@(path, contents) ->
        if path == wanted
          then (path, Text.replace old new contents)
          else entry
    )

replaceDocument :: FilePath -> Text -> [(FilePath, Text)] -> [(FilePath, Text)]
replaceDocument wanted replacement =
  map
    ( \entry@(path, _) ->
        if path == wanted
          then (path, replacement)
          else entry
    )

appendTo :: FilePath -> Text -> [(FilePath, Text)] -> [(FilePath, Text)]
appendTo wanted addition =
  map
    ( \entry@(path, contents) ->
        if path == wanted
          then (path, contents <> addition)
          else entry
    )

insertBefore :: FilePath -> Text -> Text -> [(FilePath, Text)] -> [(FilePath, Text)]
insertBefore wanted marker addition = replaceIn wanted marker (addition <> marker)

relocateAfter :: FilePath -> Text -> Text -> [(FilePath, Text)] -> [(FilePath, Text)]
relocateAfter wanted moved marker =
  replaceIn wanted marker (marker <> "\n\n" <> moved)
    . replaceIn wanted moved ""

summaryLine :: Text -> Text -> Text
summaryLine name value = "**" <> name <> ":** " <> value

replaceProjection :: Int -> Text -> Text -> Text -> [(FilePath, Text)] -> [(FilePath, Text)]
replaceProjection number field oldValue newValue corpus =
  replaceIn
    trackerPath
    oldTrackerRow
    newTrackerRow
    (replaceIn (phasePath number) (summaryLine field oldValue) (summaryLine field newValue) corpus)
 where
  status = if number == 0 then activeTrackerStatus else blockedTrackerStatus
  oldTrackerRow = trackerRow number status
  newTrackerRow =
    trackerRowWith
      number
      (if field == "Substrate" then newValue else substrateValue number)
      (if field == "Lane" then newValue else laneValue number)
      (if field == "Register" then newValue else registerValue number)
      status

diagnosticRefusalCode :: Text
diagnosticRefusalCode = "PLAN-STRUCTURE-DIAGNOSTIC-ONLY"

diagnosticRefusalMessage :: Text
diagnosticRefusalMessage =
  "caller-authored structural input has no semantic, acquisition, reviewer-custody, observer, or promotion authority"

expectDiagnosticOnly :: String -> [(FilePath, Text)] -> [String]
expectDiagnosticOnly label corpus =
  case checkFindings (phaseContractDiagnostic corpus) of
    [item]
      | findingCode item == diagnosticRefusalCode
      , findingSubject item == planRoot
      , findingDetail item == diagnosticRefusalMessage -> []
    findings -> [label <> ": expected only the permanent structural diagnostic refusal, observed " <> show findings]

expectFinding :: String -> Text -> FilePath -> [(FilePath, Text)] -> [String]
expectFinding label code locus = expectFindingInResult label code locus . phaseContractDiagnostic

expectFindingInResult :: String -> Text -> FilePath -> CheckResult -> [String]
expectFindingInResult label code locus result
  | any matches (checkFindings result) = []
  | otherwise =
      [ label
          <> ": expected finding "
          <> Text.unpack code
          <> " at "
          <> locus
          <> ", observed "
          <> show (checkFindings result)
      ]
  where
    matches item = findingCode item == code && findingSubject item == locus

expectNoFindingCode :: String -> Text -> CheckResult -> [String]
expectNoFindingCode label code result
  | all ((/= code) . findingCode) (checkFindings result) = []
  | otherwise =
      [ label
          <> ": unexpectedly observed "
          <> Text.unpack code
          <> " in "
          <> show (checkFindings result)
      ]

expectAnyFindingCode :: String -> [Text] -> CheckResult -> [String]
expectAnyFindingCode label codes result
  | any ((`elem` codes) . findingCode) (checkFindings result) = []
  | otherwise =
      [ label
          <> ": expected at least one finding code from "
          <> show codes
          <> ", observed "
          <> show (map findingCode (checkFindings result))
      ]

expectAnyFindingCodeInResults :: String -> [Text] -> [CheckResult] -> [String]
expectAnyFindingCodeInResults label codes results
  | any (null . expectAnyFindingCode label codes) results = []
  | otherwise =
      [ label
          <> ": no result retained any finding code from "
          <> show codes
          <> "; observed "
          <> show (map (map findingCode . checkFindings) results)
      ]

expectObservationKeySequence :: String -> [Text] -> CheckResult -> [String]
expectObservationKeySequence label expected result
  | map observationKey (checkObservations result) == expected = []
  | otherwise =
      [ label
          <> ": expected observation keys "
          <> show expected
          <> ", observed "
          <> show (map observationKey (checkObservations result))
      ]

expectAnyObservationKeySequence :: String -> [Text] -> [CheckResult] -> [String]
expectAnyObservationKeySequence label expected results
  | any (null . expectObservationKeySequence label expected) results = []
  | otherwise =
      [ label
          <> ": no result retained observation keys "
          <> show expected
          <> "; observed "
          <> show (map (map observationKey . checkObservations) results)
      ]

expectExactFindingInResult :: String -> Text -> FilePath -> Text -> CheckResult -> [String]
expectExactFindingInResult label code locus detail result
  | any matches (checkFindings result) = []
  | otherwise =
      [ label
          <> ": expected exact finding "
          <> show (code, locus, detail)
          <> ", observed "
          <> show (checkFindings result)
      ]
 where
  matches item =
    findingCode item == code
      && findingSubject item == locus
      && findingDetail item == detail

expectCheckName :: String -> Text -> CheckResult -> [String]
expectCheckName label expected result
  | checkName result == expected = []
  | otherwise =
      [ label
          <> ": expected check name "
          <> Text.unpack expected
          <> ", observed "
          <> Text.unpack (checkName result)
      ]

expectObservation :: String -> Text -> Text -> CheckResult -> [String]
expectObservation label key expected result =
  case [observationValue item | item <- checkObservations result, observationKey item == key] of
    [actual]
      | actual == expected -> []
    observed -> [label <> ": expected " <> Text.unpack key <> "=" <> Text.unpack expected <> ", observed " <> show observed]

finishDiagnostics :: String -> [String] -> IO ()
finishDiagnostics name problems =
  unless
    (null problems)
    (fail (name <> " component diagnostic failures:\n  " <> Text.unpack (Text.intercalate "\n  " (map Text.pack problems))))
