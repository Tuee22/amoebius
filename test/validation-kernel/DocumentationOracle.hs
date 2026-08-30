{-# LANGUAGE OverloadedStrings #-}

module DocumentationOracle
  ( documentationSelectorAssignments
  , documentationSelectorMatrixRows
  , documentationSelectorNames
  , runDocumentationOracle
  , runDocumentationOutputOracle
  , runDocumentationResourceOracle
  , runDocumentationSelectorOracle
  , runDocumentationUnaffectedControl
  ) where

-- Component diagnostics only.  This oracle does not perform documentation correspondence check,
-- qualify the documentation harness, validate a phase, or set Done status.

import Amoebius.Validation.Documentation
  ( documentationInventoryDiagnostic
  , documentationPolicyOwnerDiagnostic
  , documentationStructureDiagnostic
  , documentationWorktreeDiagnostic
  )
import Amoebius.Validation.Types (CheckResult (..), Finding (..), Observation (..))
import Control.Exception (bracket)
import Control.Monad (filterM, forM_, unless)
import Crypto.Hash (Digest, SHA256, hash)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteString8
import Data.List (sort)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Text.IO qualified as TextIO
import DocumentationRetiredOracle qualified as Retired
import System.Directory
  ( createDirectoryIfMissing
  , createDirectoryLink
  , doesDirectoryExist
  , doesFileExist
  , getCurrentDirectory
  , removePathForcibly
  )
import System.Environment (getExecutablePath)
import System.FilePath ((</>), takeDirectory)

runDocumentationOracle :: IO ()
runDocumentationOracle = do
  productionCorpus <- productionCorpusProblems
  worktreeResources <- worktreeResourceProblems
  finishDiagnostics
    "DocumentationOracle"
    ( documentationSelectorIntegrityProblems
        <> policyOwnerOracleContractProblems
        <> productionCorpus
        <> worktreeResources
        <> manifestComparatorProblems
        <> proseBudgetProblems
        <> resourceEnvelopeProblems
        <> outputEnvelopeProblems
        <> concat
        [ expectClean "minimal governed documentation corpus" linkedCorpus
        , expectOnlyPolicyDiagnostic
            "independently stated policy owner structure"
            (documentationPolicyOwnerDiagnostic policyOwnerCorpus)
        , expectFindingInResult
            "policy owner heading and anchor are joined"
            "DOC-POLICY-OWNER-ANCHOR"
            registryOwnerPath
            ( documentationPolicyOwnerDiagnostic
                (replaceIn registryOwnerPath "## 3. Canonical providers; extension is capability-specific" "## 3. Wrong registry owner" policyOwnerCorpus)
            )
        , expectFindingInResult
            "registry placement has its own exact owner heading"
            "DOC-POLICY-OWNER-ANCHOR"
            registryPlacementOwnerPath
            ( documentationPolicyOwnerDiagnostic
                (replaceIn registryPlacementOwnerPath registryPlacementOwnerHeading "## 2. Wrong registry placement owner" policyOwnerCorpus)
            )
        , expectClean "minimal governed corpus without local links" unlinkedCorpus
        , expectClean "body Status field is not header metadata" bodyStatusCorpus
        , expectClean "parent traversal and multiline Markdown resolve inside the repository" parentTraversalCorpus
        , expectClean "non-governed Markdown contributes inbound backlink edges" auxiliaryInboundCorpus
        , expectFinding
            "governed root Purpose header"
            "DOC-HEADER-PURPOSE"
            "AGENTS.md"
            (replaceIn "AGENTS.md" "> **Purpose**: Agent policy." "> **Purpose**:" linkedCorpus)
        , expectFinding
            "duplicate Purpose inside orientation header"
            "DOC-HEADER-PURPOSE"
            "AGENTS.md"
            ( replaceIn
                "AGENTS.md"
                "This lead paragraph fixes the orientation shape without borrowing production prose."
                "This lead paragraph fixes the orientation shape without borrowing production prose.\n> **Purpose**: Duplicate header value."
                linkedCorpus
            )
        , expectFinding
            "canonical CLAUDE import exception"
            "DOC-CLAUDE-IMPORT"
            "CLAUDE.md"
            (replaceDocument "CLAUDE.md" "@AGENTS.md\nextra\n" linkedCorpus)
        , expectFinding
            "a DEVELOPMENT_PLAN evidence document cannot escape governance"
            "DOC-HEADER-PURPOSE"
            "DEVELOPMENT_PLAN/evidence/forged.md"
            (unlinkedCorpus <> [("DEVELOPMENT_PLAN/evidence/forged.md", "# Forged evidence\n")])
        , expectFinding
            "a DEVELOPMENT_PLAN ledger document cannot escape governance"
            "DOC-HEADER-PURPOSE"
            "DEVELOPMENT_PLAN/ledgers/forged.md"
            (unlinkedCorpus <> [("DEVELOPMENT_PLAN/ledgers/forged.md", "# Forged ledger\n")])
        , expectFinding
            "missing local Markdown target"
            "DOC-LINK-TARGET"
            "README.md"
            (appendTo "README.md" "\n[Missing policy](documents/missing.md)\n" unlinkedCorpus)
        , expectFinding
            "local Markdown target may not escape repository root"
            "DOC-LINK-TARGET"
            parentDocumentPath
            escapingTraversalCorpus
        , expectFinding
            "separate heading and table blocks cannot lend closing backticks"
            "DOC-MARKDOWN-SYNTAX"
            "AGENTS.md"
            blockBorrowingCorpus
        , expectFinding
            "missing local heading anchor"
            "DOC-LINK-FRAGMENT"
            "README.md"
            (replaceIn "README.md" "#target-section" "#absent-section" linkedCorpus)
        , expectFinding
            "missing declared backlink"
            "DOC-BACKLINK-MISSING"
            policyPath
            (replaceIn policyPath "**Referenced by**: README.md" "**Referenced by**: none" linkedCorpus)
        , expectFinding
            "visible eliminated archive alias"
            "DOC-ARCHIVE-REFERENCE"
            "AGENTS.md"
            (appendTo "AGENTS.md" "\nlegacy_tracking_for_deletion_archive.md\n" linkedCorpus)
        , expectFinding
            "a fenced block cannot retain the eliminated archive alias"
            "DOC-ARCHIVE-REFERENCE"
            "AGENTS.md"
            (appendTo "AGENTS.md" "\n```text\nlegacy_tracking_for_deletion_archive.md\n```\n" linkedCorpus)
        , expectFinding
            "an HTML comment cannot split the eliminated archive alias"
            "DOC-ARCHIVE-REFERENCE"
            "AGENTS.md"
            (appendTo "AGENTS.md" "\nlegacy_tracking_for_deletion_<!-- conceal -->archive.md\n" linkedCorpus)
        , expectFinding
            "serialized fixture path syntax is retired"
            "DOC-RETIRED-TRACKED-ARTIFACT"
            "AGENTS.md"
            (appendTo "AGENTS.md" "\nThe oracle reads `test/fixture/example.json`.\n" linkedCorpus)
        , expectFinding
            "an HTML comment cannot split serialized fixture path syntax"
            "DOC-RETIRED-TRACKED-ARTIFACT"
            "AGENTS.md"
            (appendTo "AGENTS.md" "\nThe oracle reads `test/fi<!-- conceal -->xture/example.json`.\n" linkedCorpus)
        , expectFinding
            "only the exact lowercase .hs suffix is admitted"
            "DOC-RETIRED-TRACKED-ARTIFACT"
            "AGENTS.md"
            (appendTo "AGENTS.md" "\nThe oracle reads `test/oracle/ExampleOracle.HS`.\n" linkedCorpus)
        , expectFinding
            "directory-only mutant path syntax is retired"
            "DOC-RETIRED-TRACKED-ARTIFACT"
            "AGENTS.md"
            (appendTo "AGENTS.md" "\nThe mutants live under `test/mutant/example/`.\n" linkedCorpus)
        , expectFinding
            "a wildcard cannot masquerade as an exact Haskell path"
            "DOC-RETIRED-TRACKED-ARTIFACT"
            "AGENTS.md"
            (appendTo "AGENTS.md" "\nThe sources are `test/fixtures/*.hs`.\n" linkedCorpus)
        , expectFinding
            "a variable cannot masquerade as an exact Haskell path"
            "DOC-RETIRED-TRACKED-ARTIFACT"
            "AGENTS.md"
            (appendTo "AGENTS.md" "\nThe source is `test/oracles/$ORACLE.hs`.\n" linkedCorpus)
        , expectFinding
            "physical line wrapping cannot split a retired artifact root"
            "DOC-RETIRED-TRACKED-ARTIFACT"
            "AGENTS.md"
            (appendTo "AGENTS.md" "\nThe oracle reads `test/fixtu\nre/example.json`.\n" linkedCorpus)
        , expectFinding
            "a multiline HTML comment cannot split a retired artifact root"
            "DOC-RETIRED-TRACKED-ARTIFACT"
            "AGENTS.md"
            (appendTo "AGENTS.md" "\nThe oracle reads `test/fi<!-- conceal\nthis split -->xture/example.json`.\n" linkedCorpus)
        , expectFinding
            "a fenced command cannot conceal retired artifact syntax"
            "DOC-RETIRED-TRACKED-ARTIFACT"
            "AGENTS.md"
            (appendTo "AGENTS.md" "\n```text\ntest/golden/example.json\n```\n" linkedCorpus)
        , expectFinding
            "ambiguous committed-mutant wording is retired"
            "DOC-RETIRED-TRACKED-ARTIFACT"
            "AGENTS.md"
            (appendTo "AGENTS.md" "\nThe committed seeded mutant changes the subject.\n" linkedCorpus)
        , expectFinding
            "line wrapping cannot conceal ambiguous committed-mutant wording"
            "DOC-RETIRED-TRACKED-ARTIFACT"
            "AGENTS.md"
            (appendTo "AGENTS.md" "\nThe committed seeded\nmutant changes the subject.\n" linkedCorpus)
        , expectFinding
            "an HTML comment cannot pad ambiguous committed-fixture wording"
            "DOC-RETIRED-TRACKED-ARTIFACT"
            "AGENTS.md"
            (appendTo "AGENTS.md" "\nThe committed <!-- one two three four five six seven eight nine ten --> Python fixture changes the subject.\n" linkedCorpus)
        , expectFinding
            "a nearby Haskell decoy cannot authorize a committed Python fixture"
            "DOC-RETIRED-TRACKED-ARTIFACT"
            "AGENTS.md"
            (appendTo "AGENTS.md" "\nThe committed Haskell-adjacent Python fixture changes the subject.\n" linkedCorpus)
        , expectFinding
            "committed wording is retired even for a Haskell fixture"
            "DOC-RETIRED-TRACKED-ARTIFACT"
            "AGENTS.md"
            (appendTo "AGENTS.md" "\nThe committed Haskell fixture changes the subject.\n" linkedCorpus)
        , expectClean
            "an exact Haskell mutant path remains admissible"
            (appendTo "AGENTS.md" "\nThe authored mutation source is `test/mutant/ExampleMutant.hs`.\n" unlinkedCorpus)
        , expectClean
            "a policy keyword decoy is structurally inert"
            (appendTo "AGENTS.md" "\nA prose decoy mentions Harbor but has no executable authority.\n" unlinkedCorpus)
        , expectFindingInResult
            "production check rejects a synthetic partial path inventory"
            "DOC-INVENTORY-COUNT"
            "documents/"
            (documentationInventoryDiagnostic linkedCorpus)
        , expectFindingInResult
            "empty governed discovery"
            "DOC-DISCOVERY-EMPTY"
            "documents/"
            (documentationStructureDiagnostic [])
        , expectFindingInResult
            "ungoverned decoy cannot satisfy discovery"
            "DOC-DISCOVERY-EMPTY"
            "documents/"
            (documentationStructureDiagnostic [("scratch/README.md", governedDocument "Decoy" "Decoy purpose." "none" "## Notes\n\nDecoy only.")])
        ]
    )

runDocumentationResourceOracle :: IO ()
runDocumentationResourceOracle =
  worktreeResourceProblems >>= finishDiagnostics "DocumentationOracle worktree resources"

runDocumentationOutputOracle :: IO ()
runDocumentationOutputOracle =
  finishDiagnostics "DocumentationOracle output resources" outputEnvelopeProblems

documentationSelectorMatrixRows :: [(String, String, [String], String)]
documentationSelectorMatrixRows =
  [ ( "VALIDATION_DOCUMENT_INPUT_DOCUMENT_LIMIT_BYPASS_MUTANT"
    , "per-document character limit plus one"
    , ["VALIDATION_DOCUMENT_INPUT_DOCUMENT_LIMIT_BYPASS_MUTANT"]
    , "per-document exact-limit control"
    )
  , ( "VALIDATION_DOCUMENT_INPUT_ENTRY_LIMIT_BYPASS_MUTANT"
    , "entry-count limit plus one"
    , ["VALIDATION_DOCUMENT_INPUT_ENTRY_LIMIT_BYPASS_MUTANT"]
    , "entry-count exact-limit control"
    )
  , ( "VALIDATION_DOCUMENT_INPUT_PATH_LIMIT_BYPASS_MUTANT"
    , "path-character limit plus one"
    , ["VALIDATION_DOCUMENT_INPUT_PATH_LIMIT_BYPASS_MUTANT"]
    , "path-character exact-limit control"
    )
  , ( "VALIDATION_DOCUMENT_INPUT_TOTAL_LIMIT_BYPASS_MUTANT"
    , "total-character limit plus one"
    , ["VALIDATION_DOCUMENT_INPUT_TOTAL_LIMIT_BYPASS_MUTANT"]
    , "total-character exact-limit control"
    )
  , ( "VALIDATION_DOCUMENT_INVENTORY_BASELINE_MUTANT"
    , "production governed-path inventory baseline"
    , ["VALIDATION_DOCUMENT_INVENTORY_BASELINE_MUTANT"]
    , "inventory-free structural control"
    )
  , ( "VALIDATION_DOCUMENT_RETIRED_ARTIFACT_MUTANT"
    , "retired tracked-artifact syntax"
    , ["VALIDATION_DOCUMENT_RETIRED_ARTIFACT_MUTANT"]
    , "exact Haskell path control"
    )
  , ( "VALIDATION_DOCUMENT_SENTENCE_LINE_SPLIT_MUTANT"
    , "wrapped sentence measurement"
    , ["VALIDATION_DOCUMENT_SENTENCE_LINE_SPLIT_MUTANT"]
    , "one-line sentence control"
    )
  , ( "VALIDATION_DOCUMENT_SENTENCE_MEASUREMENT_OMISSION_MUTANT"
    , "one-line sentence measurement"
    , [ "VALIDATION_DOCUMENT_SENTENCE_MEASUREMENT_OMISSION_MUTANT"
      , "VALIDATION_DOCUMENT_SENTENCE_LINE_SPLIT_MUTANT"
      ]
    , "table exemption control"
    )
  , ( "VALIDATION_DOCUMENT_STRUCTURE_DIAGNOSTIC_BYPASS_MUTANT"
    , "caller-authored structure permanent refusal"
    , [ "VALIDATION_DOCUMENT_STRUCTURE_DIAGNOSTIC_BYPASS_MUTANT"
      , "VALIDATION_DOCUMENT_OUTPUT_FINDING_LIMIT_BYPASS_MUTANT"
      , "VALIDATION_DOCUMENT_OUTPUT_OBSERVATION_LIMIT_BYPASS_MUTANT"
      , "VALIDATION_DOCUMENT_OUTPUT_FIELD_LIMIT_BYPASS_MUTANT"
      , "VALIDATION_DOCUMENT_OUTPUT_TOTAL_LIMIT_BYPASS_MUTANT"
      ]
    , "policy-owner structural control"
    )
  , ( "VALIDATION_DOCUMENT_CORPUS_DIAGNOSTIC_BYPASS_MUTANT"
    , "mutable-worktree permanent refusal"
    , ["VALIDATION_DOCUMENT_CORPUS_DIAGNOSTIC_BYPASS_MUTANT"]
    , "structure-only facade control"
    )
  , ( "VALIDATION_DOCUMENT_INVENTORY_DIAGNOSTIC_BYPASS_MUTANT"
    , "caller-authored inventory permanent refusal"
    , ["VALIDATION_DOCUMENT_INVENTORY_DIAGNOSTIC_BYPASS_MUTANT"]
    , "structure-only facade control"
    )
  , ( "VALIDATION_DOCUMENT_POLICY_OWNER_DIAGNOSTIC_BYPASS_MUTANT"
    , "caller-authored policy-owner permanent refusal"
    , ["VALIDATION_DOCUMENT_POLICY_OWNER_DIAGNOSTIC_BYPASS_MUTANT"]
    , "structure-only facade control"
    )
  , ( "VALIDATION_DOCUMENT_DISCOVERY_DIRECTORY_ENTRY_LIMIT_BYPASS_MUTANT"
    , "per-directory streaming entry limit plus one"
    , ["VALIDATION_DOCUMENT_DISCOVERY_DIRECTORY_ENTRY_LIMIT_BYPASS_MUTANT"]
    , "per-directory streaming entry exact limit"
    )
  , ( "VALIDATION_DOCUMENT_DISCOVERY_TOTAL_ENTRY_LIMIT_BYPASS_MUTANT"
    , "aggregate streaming entry limit plus one"
    , ["VALIDATION_DOCUMENT_DISCOVERY_TOTAL_ENTRY_LIMIT_BYPASS_MUTANT"]
    , "aggregate streaming entry exact limit"
    )
  , ( "VALIDATION_DOCUMENT_DISCOVERY_DEPTH_LIMIT_BYPASS_MUTANT"
    , "recursive discovery depth limit plus one"
    , ["VALIDATION_DOCUMENT_DISCOVERY_DEPTH_LIMIT_BYPASS_MUTANT"]
    , "recursive discovery depth exact limit"
    )
  , ( "VALIDATION_DOCUMENT_DISCOVERY_PATH_LIMIT_BYPASS_MUTANT"
    , "discovered relative-path limit plus one"
    , ["VALIDATION_DOCUMENT_DISCOVERY_PATH_LIMIT_BYPASS_MUTANT"]
    , "discovered relative-path exact limit"
    )
  , ( "VALIDATION_DOCUMENT_DISCOVERY_SYMLINK_BYPASS_MUTANT"
    , "symbolic-link no-follow attack"
    , ["VALIDATION_DOCUMENT_DISCOVERY_SYMLINK_BYPASS_MUTANT"]
    , "real-directory no-follow control"
    )
  , ( "VALIDATION_DOCUMENT_DISCOVERY_FILE_LIMIT_BYPASS_MUTANT"
    , "Markdown file-count limit plus one"
    , ["VALIDATION_DOCUMENT_DISCOVERY_FILE_LIMIT_BYPASS_MUTANT"]
    , "Markdown file-count exact limit"
    )
  , ( "VALIDATION_DOCUMENT_DISCOVERY_FILE_BYTE_LIMIT_BYPASS_MUTANT"
    , "Markdown per-file byte limit plus one"
    , ["VALIDATION_DOCUMENT_DISCOVERY_FILE_BYTE_LIMIT_BYPASS_MUTANT"]
    , "Markdown per-file byte exact limit"
    )
  , ( "VALIDATION_DOCUMENT_DISCOVERY_TOTAL_BYTE_LIMIT_BYPASS_MUTANT"
    , "Markdown aggregate byte limit plus one"
    , ["VALIDATION_DOCUMENT_DISCOVERY_TOTAL_BYTE_LIMIT_BYPASS_MUTANT"]
    , "Markdown aggregate byte exact limit"
    )
  , ( "VALIDATION_DOCUMENT_OUTPUT_FINDING_LIMIT_BYPASS_MUTANT"
    , "output finding limit plus one"
    , ["VALIDATION_DOCUMENT_OUTPUT_FINDING_LIMIT_BYPASS_MUTANT"]
    , "output finding exact limit"
    )
  , ( "VALIDATION_DOCUMENT_OUTPUT_OBSERVATION_LIMIT_BYPASS_MUTANT"
    , "output observation limit plus one"
    , ["VALIDATION_DOCUMENT_OUTPUT_OBSERVATION_LIMIT_BYPASS_MUTANT"]
    , "output observation exact limit"
    )
  , ( "VALIDATION_DOCUMENT_OUTPUT_FIELD_LIMIT_BYPASS_MUTANT"
    , "output field-character limit plus one"
    , ["VALIDATION_DOCUMENT_OUTPUT_FIELD_LIMIT_BYPASS_MUTANT"]
    , "output field-character exact limit"
    )
  , ( "VALIDATION_DOCUMENT_OUTPUT_TOTAL_LIMIT_BYPASS_MUTANT"
    , "output aggregate-character limit plus one"
    , ["VALIDATION_DOCUMENT_OUTPUT_TOTAL_LIMIT_BYPASS_MUTANT"]
    , "output aggregate-character exact limit"
    )
  ]
    <> Retired.documentationRetiredSelectorMatrixRows

documentationSelectorNames :: [String]
documentationSelectorNames =
  [selector | (selector, _, _, _) <- documentationSelectorMatrixRows]

documentationSelectorAssignments :: [(String, String)]
documentationSelectorAssignments =
  [(selector, target) | (selector, target, _, _) <- documentationSelectorMatrixRows]

runDocumentationSelectorOracle :: String -> IO ()
runDocumentationSelectorOracle selector = do
  problems <- documentationTargetProblems selector
  finishDiagnostics
    "DocumentationOracle selector"
    (documentationSelectorIntegrityProblems <> problems)

runDocumentationUnaffectedControl :: String -> IO ()
runDocumentationUnaffectedControl selector = do
  problems <- documentationControlProblems selector
  finishDiagnostics
    "DocumentationOracle unaffected control"
    (documentationSelectorIntegrityProblems <> problems)

documentationTargetProblems :: String -> IO [String]
documentationTargetProblems selector = case Retired.documentationRetiredTargetProblems selector of
  Just problems -> pure problems
  Nothing -> establishedDocumentationTargetProblems selector

establishedDocumentationTargetProblems :: String -> IO [String]
establishedDocumentationTargetProblems selector =
  case [target | (candidate, target, _, _) <- documentationSelectorMatrixRows, candidate == selector] of
    ["per-document character limit plus one"] ->
      pure
        ( expectFindingInResult
            "per-document limit target"
            "DOC-INPUT-DOCUMENT-LIMIT"
            "scratch/boundary.md"
            (documentationStructureDiagnostic [("scratch/boundary.md", Text.replicate 1048577 "x")])
        )
    ["entry-count limit plus one"] ->
      pure
        ( expectFindingInResult
            "entry-count limit target"
            "DOC-INPUT-ENTRY-LIMIT"
            "documents/"
            (documentationStructureDiagnostic (replicate 257 ("scratch/repeated.md", "")))
        )
    ["path-character limit plus one"] ->
      pure
        ( expectFindingInResult
            "path-character limit target"
            "DOC-INPUT-PATH-LIMIT"
            "supplied-path"
            (documentationStructureDiagnostic [(replicate 4094 'p' <> ".md", "")])
        )
    ["total-character limit plus one"] ->
      pure
        ( expectFindingInResult
            "total-character limit target"
            "DOC-INPUT-TOTAL-LIMIT"
            "documents/"
            (documentationStructureDiagnostic (documentationTotalBoundaryCorpus True))
        )
    ["production governed-path inventory baseline"] ->
      pure
        ( expectExactFinding
            "production governed-path inventory baseline target"
            ( Finding
                "DOC-INVENTORY-COUNT"
                "documents/"
                "governed path count differs from the authored Haskell baseline: expected=195, observed=6"
            )
            (documentationInventoryDiagnostic linkedCorpus)
        )
    ["retired tracked-artifact syntax"] ->
      pure
        ( expectFinding
            "retired tracked-artifact target"
            "DOC-RETIRED-TRACKED-ARTIFACT"
            "AGENTS.md"
            (appendTo "AGENTS.md" "\nThe retained fixture is `test/fixtures/example.json`.\n" unlinkedCorpus)
        )
    ["wrapped sentence measurement"] ->
      pure
        ( expectObservation
            "wrapped sentence target"
            "prose-budget.sentence-over-target-count"
            "1"
            (documentationStructureDiagnostic [(sentenceBudgetPath, sentenceFirstHalf <> "\n" <> sentenceSecondHalf <> "\n")])
        )
    ["one-line sentence measurement"] ->
      pure
        ( expectObservation
            "one-line sentence target"
            "prose-budget.sentence-over-target-count"
            "1"
            (documentationStructureDiagnostic [(sentenceBudgetPath, sentenceLong <> "\n")])
        )
    ["caller-authored structure permanent refusal"] ->
      pure (expectClean "structure permanent-refusal target" unlinkedCorpus)
    ["mutable-worktree permanent refusal"] ->
      withDocumentationFixture "selector-corpus-diagnostic" $ \root -> do
        initializeDocumentationFixture root
        result <- documentationWorktreeDiagnostic root
        pure
          ( expectFindingInResult
              "mutable-worktree permanent-refusal target"
              "DOC-CORPUS-DIAGNOSTIC-ONLY"
              "Amoebius.Validation.Documentation.documentationWorktreeDiagnostic"
              result
          )
    ["caller-authored inventory permanent refusal"] ->
      pure
        ( expectFindingInResult
            "inventory permanent-refusal target"
            "DOC-INVENTORY-DIAGNOSTIC-ONLY"
            "Amoebius.Validation.Documentation.documentationInventoryDiagnostic"
            (documentationInventoryDiagnostic linkedCorpus)
        )
    ["caller-authored policy-owner permanent refusal"] ->
      pure
        ( expectFindingInResult
            "policy-owner permanent-refusal target"
            "DOC-POLICY-OWNER-DIAGNOSTIC-ONLY"
            "Amoebius.Validation.Documentation.documentationPolicyOwnerDiagnostic"
            (documentationPolicyOwnerDiagnostic policyOwnerCorpus)
        )
    ["per-directory streaming entry limit plus one"] -> directoryEntryBoundaryProblems True
    ["aggregate streaming entry limit plus one"] -> totalEntryBoundaryProblems True
    ["recursive discovery depth limit plus one"] -> depthBoundaryProblems True
    ["discovered relative-path limit plus one"] -> discoveredPathBoundaryProblems True
    ["symbolic-link no-follow attack"] -> symlinkBoundaryProblems True
    ["Markdown file-count limit plus one"] -> fileCountBoundaryProblems True
    ["Markdown per-file byte limit plus one"] -> fileByteBoundaryProblems True
    ["Markdown aggregate byte limit plus one"] -> totalByteBoundaryProblems True
    ["output finding limit plus one"] ->
      pure
        ( expectExactOutputRefusal
            "output finding selector target"
            "finding count exceeds 4096"
            (documentationStructureDiagnostic (outputFindingBoundaryCorpus True))
        )
    ["output observation limit plus one"] ->
      pure
        ( expectExactOutputRefusal
            "output observation selector target"
            "observation count exceeds 4096"
            (documentationStructureDiagnostic (outputObservationBoundaryCorpus True))
        )
    ["output field-character limit plus one"] ->
      pure
        ( expectExactOutputRefusal
            "output field selector target"
            "one result field exceeds 8192 characters"
            (documentationStructureDiagnostic (outputFieldBoundaryCorpus True))
        )
    ["output aggregate-character limit plus one"] ->
      pure
        ( expectExactOutputRefusal
            "output aggregate selector target"
            "result fields exceed 2097152 characters in aggregate"
            (documentationStructureDiagnostic (outputTotalBoundaryCorpus True))
        )
    targets ->
      pure
        [ "selector target is not exactly resolvable: selector="
            <> selector
            <> "; exact-case-count="
            <> show (length targets)
        ]

documentationControlProblems :: String -> IO [String]
documentationControlProblems selector = case Retired.documentationRetiredControlProblems selector of
  Just problems -> pure problems
  Nothing -> establishedDocumentationControlProblems selector

establishedDocumentationControlProblems :: String -> IO [String]
establishedDocumentationControlProblems selector =
  case [control | (candidate, _, _, control) <- documentationSelectorMatrixRows, candidate == selector] of
    ["per-document exact-limit control"] ->
      pure
        ( expectNoFindingCode
            "per-document exact-limit control"
            "DOC-INPUT-DOCUMENT-LIMIT"
            (documentationStructureDiagnostic [("scratch/boundary.md", Text.replicate 1048576 "x")])
        )
    ["entry-count exact-limit control"] ->
      pure
        ( expectNoFindingCode
            "entry-count exact-limit control"
            "DOC-INPUT-ENTRY-LIMIT"
            (documentationStructureDiagnostic (replicate 256 ("scratch/repeated.md", "")))
        )
    ["path-character exact-limit control"] ->
      pure
        ( expectNoFindingCode
            "path-character exact-limit control"
            "DOC-INPUT-PATH-LIMIT"
            (documentationStructureDiagnostic [(replicate 4093 'p' <> ".md", "")])
        )
    ["total-character exact-limit control"] ->
      pure
        ( expectNoFindingCode
            "total-character exact-limit control"
            "DOC-INPUT-TOTAL-LIMIT"
            (documentationStructureDiagnostic (documentationTotalBoundaryCorpus False))
        )
    ["inventory-free structural control"] -> pure (expectClean "inventory-free structural control" unlinkedCorpus)
    ["exact Haskell path control"] ->
      pure
        ( expectClean
            "exact Haskell path control"
            (appendTo "AGENTS.md" "\nThe authored mutation source is `test/mutant/ExampleMutant.hs`.\n" unlinkedCorpus)
        )
    ["one-line sentence control"] ->
      pure
        ( expectObservation
            "one-line sentence control"
            "prose-budget.sentence-over-target-count"
            "1"
            (documentationStructureDiagnostic [(sentenceBudgetPath, sentenceLong <> "\n")])
        )
    ["table exemption control"] ->
      pure
        ( expectObservation
            "table exemption control"
            "prose-budget.sentence-over-target-count"
            "0"
            (documentationStructureDiagnostic [(sentenceBudgetPath, "| " <> sentenceLong <> " |\n")])
        )
    ["policy-owner structural control"] ->
      pure
        ( expectOnlyPolicyDiagnostic
            "policy-owner structural control"
            (documentationPolicyOwnerDiagnostic policyOwnerCorpus)
        )
    ["structure-only facade control"] -> pure (expectClean "structure-only facade control" unlinkedCorpus)
    ["per-directory streaming entry exact limit"] -> directoryEntryBoundaryProblems False
    ["aggregate streaming entry exact limit"] -> totalEntryBoundaryProblems False
    ["recursive discovery depth exact limit"] -> depthBoundaryProblems False
    ["discovered relative-path exact limit"] -> discoveredPathBoundaryProblems False
    ["real-directory no-follow control"] -> symlinkBoundaryProblems False
    ["Markdown file-count exact limit"] -> fileCountBoundaryProblems False
    ["Markdown per-file byte exact limit"] -> fileByteBoundaryProblems False
    ["Markdown aggregate byte exact limit"] -> totalByteBoundaryProblems False
    ["output finding exact limit"] ->
      pure
        ( expectNoFindingCode
            "output finding selector control"
            "DOC-OUTPUT-LIMIT"
            (documentationStructureDiagnostic (outputFindingBoundaryCorpus False))
            <> expectFindingCount
              "output finding selector control cardinality"
              4096
              (documentationStructureDiagnostic (outputFindingBoundaryCorpus False))
        )
    ["output observation exact limit"] ->
      pure
        ( expectNoFindingCode
            "output observation selector control"
            "DOC-OUTPUT-LIMIT"
            (documentationStructureDiagnostic (outputObservationBoundaryCorpus False))
            <> expectObservationCount
              "output observation selector control cardinality"
              4096
              (documentationStructureDiagnostic (outputObservationBoundaryCorpus False))
        )
    ["output field-character exact limit"] ->
      pure
        ( expectNoFindingCode
            "output field selector control"
            "DOC-OUTPUT-LIMIT"
            (documentationStructureDiagnostic (outputFieldBoundaryCorpus False))
        )
    ["output aggregate-character exact limit"] ->
      let result = documentationStructureDiagnostic (outputTotalBoundaryCorpus False)
       in pure
            ( expectNoFindingCode
                "output aggregate selector control"
                "DOC-OUTPUT-LIMIT"
                result
                <> expectObservationCount
                  "output aggregate selector control observation cardinality"
                  11
                  result
                <> expectFindingCodeCount
                  "output aggregate selector control changed-subject cardinality"
                  "DOC-LINK-TARGET"
                  1
                  result
                <> expectFindingCount
                  "output aggregate selector control finding cardinality"
                  2502
                  result
                <> expectResultFieldCharacterCount
                  "output aggregate selector control cardinality"
                  2097152
                  result
            )
    controls ->
      pure
        [ "selector control is not exactly resolvable: selector="
            <> selector
            <> "; exact-control-count="
            <> show (length controls)
        ]

documentationSelectorIntegrityProblems :: [String]
documentationSelectorIntegrityProblems =
  [ "documentation selector registry cardinality changed: expected=64; actual="
      <> show (length documentationSelectorMatrixRows)
  | length documentationSelectorMatrixRows /= 64
  ]
    <> [ "documentation selector registry contains duplicate selector identities"
       | Set.size (Set.fromList documentationSelectorNames) /= length documentationSelectorNames
       ]
    <> [ "documentation selector registry contains an empty assignment"
       | any (\(selector, target, _, control) -> any null [selector, target, control]) documentationSelectorMatrixRows
       ]
    <> [ "documentation selector impact registry contains an empty or duplicate impact set for " <> selector
       | (selector, _, impacts, _) <- documentationSelectorMatrixRows
       , null impacts || Set.size (Set.fromList impacts) /= length impacts
       ]
    <> [ "documentation selector impact registry omits its primary selector " <> selector
       | (selector, _, impacts, _) <- documentationSelectorMatrixRows
       , selector `notElem` impacts
       ]
    <> [ "documentation selector impact registry names an unknown exact case " <> impact
       | (_, _, impacts, _) <- documentationSelectorMatrixRows
       , impact <- impacts
       , impact `notElem` documentationSelectorNames
       ]

documentationTotalBoundaryCorpus :: Bool -> [(FilePath, Text)]
documentationTotalBoundaryCorpus over =
  [ ( "scratch/total-" <> show index <> ".md"
    , Text.replicate (524288 + if over && index == (16 :: Int) then 1 else 0) "x"
    )
  | index <- [1 .. 16]
  ]

sentenceBudgetPath :: FilePath
sentenceBudgetPath = "documents/sentence-budget.md"

sentenceFirstHalf :: Text
sentenceFirstHalf =
  "one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty twenty-one twenty-two twenty-three twenty-four twenty-five"

sentenceSecondHalf :: Text
sentenceSecondHalf =
  "twenty-six twenty-seven twenty-eight twenty-nine thirty thirty-one thirty-two thirty-three thirty-four thirty-five thirty-six thirty-seven thirty-eight thirty-nine forty forty-one forty-two forty-three forty-four forty-five forty-six forty-seven forty-eight forty-nine fifty."

sentenceLong :: Text
sentenceLong = sentenceFirstHalf <> " " <> sentenceSecondHalf

-- Worktree component diagnostic only. These values are intentionally stated
-- independently of Documentation's production baseline. The exact live
-- finding manifest is closed: every known Phase-0 reset-residue class is
-- retained, but an omitted, added, relocated, or textually changed finding
-- makes this oracle red. Reading the mutable worktree still does not
-- authenticate a snapshot, qualify this oracle, validate a phase, perform
-- prose-correspondence check, or set Done status.
productionCorpusProblems :: IO [String]
productionCorpusProblems = do
  current <- getCurrentDirectory
  roots <- filterM isRepositoryRoot (ancestors current)
  case roots of
    [] -> pure ["production documentation corpus: no ancestor contains amoebius.cabal"]
    root : _ -> do
      result <- documentationWorktreeDiagnostic root
      pure
        ( expectObservation
            "independent production governed-document count"
            "governed-count"
            expectedProductionGovernedCount
            result
            <> expectObservation
              "independent production governed-path digest"
              "governed-path-manifest-sha256"
              expectedProductionGovernedPathDigest
              result
            <> expectObservation
              "independent production paragraph-spanning over-target count"
              "prose-budget.sentence-over-target-count"
              "1604"
              result
            <> expectObservation
              "independent production severe-sentence count"
              "prose-budget.sentence-over-severe-count"
              "128"
              result
            <> expectObservation
              "independent production maximum sentence words"
              "prose-budget.sentence-maximum-words"
              "667"
              result
            <> expectObservation
              "independent production over-target paragraph count"
              "prose-budget.paragraph-over-target-count"
              "656"
              result
            <> findingManifestProblems
              expectedProductionFindingCounts
              expectedProductionFindingManifestSha256
              (checkFindings result)
        )
 where
  isRepositoryRoot candidate = doesFileExist (candidate </> "amoebius.cabal")

ancestors :: FilePath -> [FilePath]
ancestors path = path : if parent == path then [] else ancestors parent
 where
  parent = takeDirectory path

expectedProductionGovernedCount :: Text
expectedProductionGovernedCount = "195"

expectedProductionGovernedPathDigest :: Text
expectedProductionGovernedPathDigest = "51c38807d39526404f678c6a89ccaf6210ff91d7b17d4cde7989f1bc2a9e55f2"

-- These are open residue, not accepted validation evidence. The exact count
-- vector prevents an unrecognized code from replacing a declared class; the
-- digest additionally binds every sorted code, subject, and detail byte.
expectedProductionFindingCounts :: [(Text, Int)]
expectedProductionFindingCounts =
  [ ("DOC-CORPUS-DIAGNOSTIC-ONLY", 1)
  , ("PLAN-GATE-UNRESOLVED", 1728)
  , ("PLAN-RESOURCE-CONTRACT-GAP", 385)
  , ("PLAN-RESOURCE-DIAGNOSTIC-ONLY", 1)
  , ("PLAN-RESOURCE-JOIN-DIAGNOSTIC-ONLY", 1)
  , ("PLAN-SEMANTIC-CONTRACT-GAP", 18)
  , ("PLAN-SEMANTIC-JOIN-DIAGNOSTIC-ONLY", 1)
  , ("PLAN-SEMANTIC-MARKDOWN-DIAGNOSTIC-ONLY", 1)
  ]

expectedProductionFindingManifestSha256 :: Text
expectedProductionFindingManifestSha256 = "9431c940540f3f81c51aa74f2dd9b23ccf39e277e43ef6820e0f11712b522b34"

findingManifestProblems :: [(Text, Int)] -> Text -> [Finding] -> [String]
findingManifestProblems expectedCounts expectedDigest findings =
  [ "production finding code counts differ from the closed live-residue manifest: expected "
      <> show expectedCounts
      <> ", observed "
      <> show actualCounts
  | actualCounts /= expectedCounts
  ]
    <> [ "production finding code/subject/detail manifest digest differs from the closed live-residue manifest: expected "
           <> Text.unpack expectedDigest
           <> ", observed "
           <> Text.unpack actualDigest
       | actualDigest /= expectedDigest
       ]
 where
  actualCounts =
    Map.toAscList
      (Map.fromListWith (+) [(findingCode item, 1 :: Int) | item <- findings])
  actualDigest = findingManifestDigest findings

findingManifestDigest :: [Finding] -> Text
findingManifestDigest findings =
  Text.pack
    ( show
        ( hash
            (ByteString.concat (map encodeFinding (sort findings)))
            :: Digest SHA256
        )
    )
 where
  encodeFinding item =
    ByteString.concat
      [ encodeField (findingCode item)
      , encodeField (Text.pack (findingSubject item))
      , encodeField (findingDetail item)
      ]
  encodeField value =
    let bytes = TextEncoding.encodeUtf8 value
     in ByteString8.pack (show (ByteString.length bytes)) <> ":" <> bytes

manifestComparatorProblems :: [String]
manifestComparatorProblems =
  expectComparatorClean
    <> expectComparatorRed "omission" (drop 1 comparatorCorpus)
    <> expectComparatorRed "addition" (comparatorCorpus <> [Finding "RESIDUE-B" "b.md" "extra"])
    <> expectComparatorRed "unrecognized PLAN-SPRINT-STATUS" (comparatorCorpus <> [Finding "PLAN-SPRINT-STATUS" "phase.md" "wrong status"])
    <> expectComparatorRed "code substitution" [Finding "RESIDUE-C" "a.md" "one", comparatorSecond]
    <> expectComparatorRed "subject relocation" [Finding "RESIDUE-A" "moved.md" "one", comparatorSecond]
    <> expectComparatorRed "detail substitution" [Finding "RESIDUE-A" "a.md" "changed", comparatorSecond]
 where
  expectedCounts = [("RESIDUE-A", 1), ("RESIDUE-B", 1)]
  expectedDigest = findingManifestDigest comparatorCorpus
  expectComparatorClean =
    [ "closed finding-manifest comparator rejected its exact positive control: " <> show problems
    | let problems = findingManifestProblems expectedCounts expectedDigest comparatorCorpus
    , not (null problems)
    ]
  expectComparatorRed label mutated =
    [ "closed finding-manifest comparator admitted " <> label
    | null (findingManifestProblems expectedCounts expectedDigest mutated)
    ]

comparatorCorpus :: [Finding]
comparatorCorpus =
  [ Finding "RESIDUE-A" "a.md" "one"
  , comparatorSecond
  ]

comparatorSecond :: Finding
comparatorSecond = Finding "RESIDUE-B" "b.md" "two"

proseBudgetProblems :: [String]
proseBudgetProblems =
  concat
    [ budgetExpectations "one physical line" oneLineResult
    , budgetExpectations "one hard-wrapped paragraph" wrappedResult
    , expectObservation "table cells are mechanically exempt" overTargetKey "0" tableResult
    , expectObservation "fenced source is not prose" overTargetKey "0" fencedResult
    , expectObservation "seven-sentence paragraph is reported" paragraphOverTargetKey "1" paragraphResult
    , expectObservation
        "paragraph report names its independent locus and count"
        "prose-budget.paragraph-over-target"
        "documents/sentence-budget.md:1:7"
        paragraphResult
    ]
 where
  budgetExpectations label result =
    expectObservation (label <> " crosses the 45-word target once") overTargetKey "1" result
      <> expectObservation (label <> " stays below the severe threshold") "prose-budget.sentence-over-severe-count" "0" result
      <> expectObservation (label <> " reports the exact maximum") "prose-budget.sentence-maximum-words" "50" result
      <> expectObservation
        (label <> " reports the exact sentence locus")
        "prose-budget.sentence-over-target"
        "documents/sentence-budget.md:1:sentence-1:50"
        result
  oneLineResult = documentationStructureDiagnostic [(budgetPath, longSentence <> "\n")]
  wrappedResult = documentationStructureDiagnostic [(budgetPath, firstHalf <> "\n" <> secondHalf <> "\n")]
  tableResult = documentationStructureDiagnostic [(budgetPath, "| " <> longSentence <> " |\n")]
  fencedResult = documentationStructureDiagnostic [(budgetPath, "```text\n" <> longSentence <> "\n```\n")]
  paragraphResult = documentationStructureDiagnostic [(budgetPath, "One. Two. Three. Four. Five. Six. Seven.\n")]
  budgetPath = "documents/sentence-budget.md"
  overTargetKey = "prose-budget.sentence-over-target-count"
  paragraphOverTargetKey = "prose-budget.paragraph-over-target-count"
  firstHalf =
    "one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty twenty-one twenty-two twenty-three twenty-four twenty-five"
  secondHalf =
    "twenty-six twenty-seven twenty-eight twenty-nine thirty thirty-one thirty-two thirty-three thirty-four thirty-five thirty-six thirty-seven thirty-eight thirty-nine forty forty-one forty-two forty-three forty-four forty-five forty-six forty-seven forty-eight forty-nine fifty."
  longSentence = firstHalf <> " " <> secondHalf

resourceEnvelopeProblems :: [String]
resourceEnvelopeProblems =
  concat
    [ expectNoFindingCode
        "exact entry-count boundary remains inside the parser envelope"
        "DOC-INPUT-ENTRY-LIMIT"
        entryBoundaryResult
    , expectFindingInResult
        "entry-count boundary plus one refuses before parsing"
        "DOC-INPUT-ENTRY-LIMIT"
        "documents/"
        entryOverResult
    , expectNoFindingCode
        "exact path-character boundary remains inside the parser envelope"
        "DOC-INPUT-PATH-LIMIT"
        pathBoundaryResult
    , expectFindingInResult
        "path-character boundary plus one refuses before parsing"
        "DOC-INPUT-PATH-LIMIT"
        "supplied-path"
        pathOverResult
    , expectNoFindingCode
        "exact per-document character boundary remains inside the parser envelope"
        "DOC-INPUT-DOCUMENT-LIMIT"
        documentBoundaryResult
    , expectFindingInResult
        "per-document character boundary plus one refuses before parsing"
        "DOC-INPUT-DOCUMENT-LIMIT"
        "scratch/boundary.md"
        documentOverResult
    , expectNoFindingCode
        "exact total-character boundary remains inside the parser envelope"
        "DOC-INPUT-TOTAL-LIMIT"
        totalBoundaryResult
    , expectFindingInResult
        "total-character boundary plus one refuses before parsing"
        "DOC-INPUT-TOTAL-LIMIT"
        "documents/"
        totalOverResult
    , expectObservation
        "resource refusal is explicitly pre-parse"
        "documentation-input-envelope"
        "refused-before-parse"
        totalOverResult
    ]
 where
  entryBoundaryResult = documentationStructureDiagnostic (replicate 256 ("scratch/repeated.md", ""))
  entryOverResult = documentationStructureDiagnostic (replicate 257 ("scratch/repeated.md", ""))
  pathBoundaryResult = documentationStructureDiagnostic [(replicate 4093 'p' <> ".md", "")]
  pathOverResult = documentationStructureDiagnostic [(replicate 4094 'p' <> ".md", "")]
  documentBoundaryResult = documentationStructureDiagnostic [("scratch/boundary.md", Text.replicate 1048576 "x")]
  documentOverResult = documentationStructureDiagnostic [("scratch/boundary.md", Text.replicate 1048577 "x")]
  totalBoundaryResult = documentationStructureDiagnostic (totalCorpus False)
  totalOverResult = documentationStructureDiagnostic (totalCorpus True)
  totalCorpus over =
    [ ( "scratch/total-" <> show index <> ".md"
      , Text.replicate (524288 + if over && index == (16 :: Int) then 1 else 0) "x"
      )
    | index <- [1 .. 16]
    ]

-- The final public diagnostic carrier includes its permanent refusal. These
-- four independent corpora therefore state exact final-result boundaries,
-- not merely the size of the hidden parser result before facade composition.
-- Every first-over case must collapse to the exact bounded refusal while
-- preserving the permanent structure-only marker.
outputEnvelopeProblems :: [String]
outputEnvelopeProblems =
  concat
    [ expectNoFindingCode
        "exact output finding boundary remains renderable"
        "DOC-OUTPUT-LIMIT"
        findingBoundaryResult
    , expectFindingCodeCount
        "exact output finding boundary has 4,095 changed-subject findings"
        "DOC-LINK-TARGET"
        4095
        findingBoundaryResult
    , expectFindingCount
        "exact output finding boundary includes the permanent refusal"
        4096
        findingBoundaryResult
    , expectExactOutputRefusal
        "output finding boundary plus one"
        "finding count exceeds 4096"
        findingOverResult
    , expectNoFindingCode
        "exact output observation boundary remains renderable"
        "DOC-OUTPUT-LIMIT"
        observationBoundaryResult
    , expectObservationCount
        "exact output observation boundary"
        4096
        observationBoundaryResult
    , expectObservationKeyCount
        "exact output observation boundary has 4,084 sentence loci"
        "prose-budget.sentence-over-target"
        4084
        observationBoundaryResult
    , expectExactFindings
        "exact output observation boundary retains only the permanent refusal"
        [structureDiagnosticRefusal]
        observationBoundaryResult
    , expectExactOutputRefusal
        "output observation boundary plus one"
        "observation count exceeds 4096"
        observationOverResult
    , expectNoFindingCode
        "exact output field boundary remains renderable"
        "DOC-OUTPUT-LIMIT"
        fieldBoundaryResult
    , expectExactFindings
        "exact output field boundary"
        [ structureDiagnosticRefusal
        , Finding
            "DOC-LINK-TARGET"
            "README.md"
            (outputFieldDetailPrefix <> outputFieldTarget False)
        ]
        fieldBoundaryResult
    , expectExactOutputRefusal
        "output field boundary plus one"
        "one result field exceeds 8192 characters"
        fieldOverResult
    , expectNoFindingCode
        "exact output aggregate boundary remains renderable"
        "DOC-OUTPUT-LIMIT"
        totalBoundaryResult
    , expectObservationCount
        "exact output aggregate boundary stays below the observation ceiling"
        11
        totalBoundaryResult
    , expectFindingCodeCount
        "exact output aggregate boundary has one changed-subject finding"
        "DOC-LINK-TARGET"
        1
        totalBoundaryResult
    , expectFindingCount
        "exact output aggregate boundary remains below the finding ceiling"
        2502
        totalBoundaryResult
    , expectResultFieldCharacterCount
        "exact output aggregate boundary"
        2097152
        totalBoundaryResult
    , expectExactOutputRefusal
        "output aggregate boundary plus one"
        "result fields exceed 2097152 characters in aggregate"
        totalOverResult
    ]
 where
  findingBoundaryResult = documentationStructureDiagnostic (outputFindingBoundaryCorpus False)
  findingOverResult = documentationStructureDiagnostic (outputFindingBoundaryCorpus True)
  observationBoundaryResult = documentationStructureDiagnostic (outputObservationBoundaryCorpus False)
  observationOverResult = documentationStructureDiagnostic (outputObservationBoundaryCorpus True)
  fieldBoundaryResult = documentationStructureDiagnostic (outputFieldBoundaryCorpus False)
  fieldOverResult = documentationStructureDiagnostic (outputFieldBoundaryCorpus True)
  totalBoundaryResult = documentationStructureDiagnostic (outputTotalBoundaryCorpus False)
  totalOverResult = documentationStructureDiagnostic (outputTotalBoundaryCorpus True)

outputFindingBoundaryCorpus :: Bool -> [(FilePath, Text)]
outputFindingBoundaryCorpus over =
  appendTo
    "README.md"
    ( "\n"
        <> Text.intercalate
          "\n\n"
          [ "[missing-"
              <> Text.pack (show ordinal)
              <> "](missing-"
              <> Text.pack (show ordinal)
              <> ".md)"
          | ordinal <- [(1 :: Int) .. 4095 + (if over then 1 else 0)]
          ]
        <> "\n"
    )
    unlinkedCorpus

outputObservationBoundaryCorpus :: Bool -> [(FilePath, Text)]
outputObservationBoundaryCorpus over =
  appendTo
    "README.md"
    ( "\n"
        <> Text.intercalate "\n\n" (replicate (4084 + (if over then 1 else 0)) outputBoundarySentence)
        <> "\n"
    )
    unlinkedCorpus

outputFieldBoundaryCorpus :: Bool -> [(FilePath, Text)]
outputFieldBoundaryCorpus over =
  appendTo
    "README.md"
    ("\n[missing](" <> outputFieldTarget over <> ")\n")
    unlinkedCorpus

outputFieldDetailPrefix :: Text
outputFieldDetailPrefix = "line 19: Markdown target does not exist: "

outputFieldTarget :: Bool -> Text
outputFieldTarget over =
  Text.replicate (targetLength - Text.length extension) "x" <> extension
 where
  targetLength = 8192 + (if over then 1 else 0) - Text.length outputFieldDetailPrefix
  extension = ".md"

-- Add 250 empty governed documents. Each independently contributes exactly
-- ten header findings: title, Purpose, Read-this-if, details presence, header
-- order, metadata-block order, and four metadata-field cardinalities. With
-- one missing-link finding and the permanent refusal, the final count is
-- 2,502. Only the missing-link target changes in the first-over case, and it
-- appears in exactly one finding detail, so that attack adds one character.
outputTotalBoundaryCorpus :: Bool -> [(FilePath, Text)]
outputTotalBoundaryCorpus over =
  appendTo
    "README.md"
    ( "\n[x]("
        <> Text.pack (fixedLengthOutputTarget (outputTotalSpecialTargetLength + (if over then 1 else 0)) 1)
        <> ")\n"
    )
    ( unlinkedCorpus
        <> [ (fixedLengthOutputDocumentPath outputTotalCommonPathLength ordinal, "")
           | ordinal <- [(1 :: Int) .. 250]
           ]
    )

fixedLengthOutputDocumentPath :: Int -> Int -> FilePath
fixedLengthOutputDocumentPath wantedLength ordinal =
  prefix <> replicate padding 'p' <> suffix
 where
  prefix = "documents/output-total-"
  suffix = "-" <> show ordinal <> ".md"
  padding = wantedLength - length prefix - length suffix

fixedLengthOutputTarget :: Int -> Int -> FilePath
fixedLengthOutputTarget wantedLength ordinal =
  prefix <> replicate padding 'x' <> suffix
 where
  prefix = "missing-total-"
  suffix = "-" <> show ordinal <> ".md"
  padding = wantedLength - length prefix - length suffix

outputTotalCommonPathLength :: Int
outputTotalCommonPathLength = 726

outputTotalSpecialTargetLength :: Int
outputTotalSpecialTargetLength = 986

outputBoundarySentence :: Text
outputBoundarySentence = Text.unwords (replicate 45 "x" <> ["x."])

structureDiagnosticRefusal :: Finding
structureDiagnosticRefusal =
  Finding
    "DOC-STRUCTURE-DIAGNOSTIC-ONLY"
    "Amoebius.Validation.Documentation.documentationStructureDiagnostic"
    "caller-authored Markdown has no capture, semantic, gate-evidence, observer, or gate-pass result"

expectedOutputRefusal :: Text -> CheckResult
expectedOutputRefusal problem =
  CheckResult
    { checkName = "documentation-output-refusal"
    , checkObservations =
        [ Observation "documentation-output-envelope" "refused-before-render"
        , Observation "documentation-output-finding-limit" "4096"
        , Observation "documentation-output-observation-limit" "4096"
        , Observation "documentation-output-field-character-limit" "8192"
        , Observation "documentation-output-total-character-limit" "2097152"
        ]
    , checkFindings =
        [ Finding "DOC-OUTPUT-LIMIT" "documentation-result" problem
        , structureDiagnosticRefusal
        ]
    }

expectExactOutputRefusal :: String -> Text -> CheckResult -> [String]
expectExactOutputRefusal label problem result =
  [ label
      <> ": expected exact bounded refusal "
      <> outputRefusalSummary expected
      <> ", observed "
      <> outputRefusalSummary result
  | result /= expected
  ]
 where
  expected = expectedOutputRefusal problem

outputRefusalSummary :: CheckResult -> String
outputRefusalSummary result =
  show
    ( checkName result
    , length (checkObservations result)
    , Map.toAscList (Map.fromListWith (+) [(findingCode item, 1 :: Int) | item <- checkFindings result])
    , [findingDetail item | item <- checkFindings result, findingCode item == "DOC-OUTPUT-LIMIT"]
    , resultFieldCharacterCount result
    )

expectFindingCount :: String -> Int -> CheckResult -> [String]
expectFindingCount label expected result =
  [label <> ": expected finding count " <> show expected <> ", observed " <> show actual | actual /= expected]
 where
  actual = length (checkFindings result)

expectFindingCodeCount :: String -> Text -> Int -> CheckResult -> [String]
expectFindingCodeCount label code expected result =
  [label <> ": expected code count " <> show expected <> ", observed " <> show actual | actual /= expected]
 where
  actual = length (filter ((== code) . findingCode) (checkFindings result))

expectObservationCount :: String -> Int -> CheckResult -> [String]
expectObservationCount label expected result =
  [label <> ": expected observation count " <> show expected <> ", observed " <> show actual | actual /= expected]
 where
  actual = length (checkObservations result)

expectObservationKeyCount :: String -> Text -> Int -> CheckResult -> [String]
expectObservationKeyCount label key expected result =
  [label <> ": expected key count " <> show expected <> ", observed " <> show actual | actual /= expected]
 where
  actual = length (filter ((== key) . observationKey) (checkObservations result))

expectExactFindings :: String -> [Finding] -> CheckResult -> [String]
expectExactFindings label expected result =
  [label <> ": expected findings " <> show expected <> ", observed " <> show (checkFindings result)
  | checkFindings result /= expected
  ]

expectResultFieldCharacterCount :: String -> Int -> CheckResult -> [String]
expectResultFieldCharacterCount label expected result =
  [ label <> ": expected aggregate field characters " <> show expected <> ", observed " <> show actual
  | actual /= expected
  ]
 where
  actual = resultFieldCharacterCount result

resultFieldCharacterCount :: CheckResult -> Int
resultFieldCharacterCount result =
  sum
    ( Text.length (checkName result)
        : concatMap observationFieldLengths (checkObservations result)
          <> concatMap findingFieldLengths (checkFindings result)
    )
 where
  observationFieldLengths item =
    [Text.length (observationKey item), Text.length (observationValue item)]
  findingFieldLengths item =
    [ Text.length (findingCode item)
    , length (findingSubject item)
    , Text.length (findingDetail item)
    ]

-- Mutable-worktree traversal remains diagnostic-only. These fixtures are
-- generated lazily beside the running ignored executable and state every
-- literal production boundary independently. Each exact-limit corpus is
-- paired with the first over-limit corpus and checked at its specific code and
-- subject; unrelated structural findings are deliberately not interpreted as
-- authority.
worktreeResourceProblems :: IO [String]
worktreeResourceProblems = fmap concat . sequence $
  [ directoryEntryBoundaryProblems False
  , directoryEntryBoundaryProblems True
  , totalEntryBoundaryProblems False
  , totalEntryBoundaryProblems True
  , depthBoundaryProblems False
  , depthBoundaryProblems True
  , discoveredPathBoundaryProblems False
  , discoveredPathBoundaryProblems True
  , symlinkBoundaryProblems False
  , symlinkBoundaryProblems True
  , fileCountBoundaryProblems False
  , fileCountBoundaryProblems True
  , fileByteBoundaryProblems False
  , fileByteBoundaryProblems True
  , totalByteBoundaryProblems False
  , totalByteBoundaryProblems True
  ]

directoryEntryBoundaryProblems :: Bool -> IO [String]
directoryEntryBoundaryProblems over =
  withDocumentationFixture ("directory-entries-" <> boundaryLabel over) $ \root -> do
    initializeDocumentationFixture root
    forM_ [1 .. 1024 + if over then 1 else 0] $ \ordinal ->
      writeEmpty (root </> "documents" </> numberedName "entry" ordinal ".txt")
    result <- documentationWorktreeDiagnostic root
    pure
      ( boundaryExpectation
          over
          "per-directory streaming entry boundary"
          "DOC-DISCOVERY-DIRECTORY-ENTRY-LIMIT"
          "documents"
          result
      )

totalEntryBoundaryProblems :: Bool -> IO [String]
totalEntryBoundaryProblems over =
  withDocumentationFixture ("total-entries-" <> boundaryLabel over) $ \root -> do
    initializeDocumentationFixture root
    forM_ [1 .. (4 :: Int)] $ \directoryOrdinal -> do
      let directory = root </> "documents" </> numberedName "bucket" directoryOrdinal ""
      createDirectoryIfMissing True directory
      forM_ [1 .. (1020 :: Int)] $ \entryOrdinal ->
        writeEmpty (directory </> numberedName "entry" entryOrdinal ".txt")
    forM_ [1 .. 7 + if over then 1 else 0] $ \ordinal ->
      writeEmpty (root </> "DEVELOPMENT_PLAN" </> numberedName "entry" ordinal ".txt")
    result <- documentationWorktreeDiagnostic root
    pure
      ( boundaryExpectation
          over
          "aggregate streaming directory-entry boundary"
          "DOC-DISCOVERY-TOTAL-ENTRY-LIMIT"
          "documents/"
          result
          <> expectObservation
            "aggregate streaming directory-entry budget saturates exactly"
            "documentation-discovery.directory-entry-count"
            "4096"
            result
      )

depthBoundaryProblems :: Bool -> IO [String]
depthBoundaryProblems over =
  withDocumentationFixture ("depth-" <> boundaryLabel over) $ \root -> do
    initializeDocumentationFixture root
    let depth = 64 + if over then 1 else 0
        relative = foldl (</>) "documents" (replicate depth "d")
    createDirectoryIfMissing True (root </> relative)
    result <- documentationWorktreeDiagnostic root
    pure
      ( boundaryExpectation
          over
          "recursive directory-depth boundary"
          "DOC-DISCOVERY-DEPTH-LIMIT"
          relative
          result
      )

discoveredPathBoundaryProblems :: Bool -> IO [String]
discoveredPathBoundaryProblems over =
  withDocumentationFixture ("path-" <> boundaryLabel over) $ \root -> do
    initializeDocumentationFixture root
    let first = replicate 250 'a'
        second = replicate (251 + if over then 1 else 0) 'b'
        relative = "documents" </> first </> second
    createDirectoryIfMissing True (root </> relative)
    result <- documentationWorktreeDiagnostic root
    pure
      ( boundaryExpectation
          over
          "discovered relative-path boundary"
          "DOC-DISCOVERY-PATH-LIMIT"
          "discovered-path"
          result
      )

symlinkBoundaryProblems :: Bool -> IO [String]
symlinkBoundaryProblems useLink =
  withDocumentationFixture ("symlink-" <> if useLink then "attack" else "control") $ \root -> do
    initializeDocumentationFixture root
    let target = root </> "target-directory"
        admitted = root </> "documents" </> "linked-directory"
    createDirectoryIfMissing True target
    if useLink
      then createDirectoryLink target admitted
      else createDirectoryIfMissing True admitted
    result <- documentationWorktreeDiagnostic root
    pure
      ( boundaryExpectation
          useLink
          "no-follow symbolic-link boundary"
          "DOC-DISCOVERY-SYMLINK"
          ("documents" </> "linked-directory")
          result
      )

fileCountBoundaryProblems :: Bool -> IO [String]
fileCountBoundaryProblems over =
  withDocumentationFixture ("file-count-" <> boundaryLabel over) $ \root -> do
    initializeDocumentationFixture root
    -- The three required root Markdown files are admitted first, leaving 253
    -- places at the literal 256-file boundary.
    forM_ [1 .. 253 + if over then 1 else 0] $ \ordinal ->
      writeEmpty (root </> "documents" </> numberedName "document" ordinal ".md")
    result <- documentationWorktreeDiagnostic root
    pure
      ( boundaryExpectation
          over
          "pre-read Markdown file-count boundary"
          "DOC-DISCOVERY-FILE-LIMIT"
          "documents/"
          result
      )

fileByteBoundaryProblems :: Bool -> IO [String]
fileByteBoundaryProblems over =
  withDocumentationFixture ("file-bytes-" <> boundaryLabel over) $ \root -> do
    initializeDocumentationFixture root
    TextIO.writeFile
      (root </> "documents" </> "boundary.md")
      (Text.replicate (4194304 + if over then 1 else 0) "x")
    result <- documentationWorktreeDiagnostic root
    pure
      ( boundaryExpectation
          over
          "pre-read per-file byte boundary"
          "DOC-DISCOVERY-FILE-BYTE-LIMIT"
          ("documents" </> "boundary.md")
          result
      )

totalByteBoundaryProblems :: Bool -> IO [String]
totalByteBoundaryProblems over =
  withDocumentationFixture ("total-bytes-" <> boundaryLabel over) $ \root -> do
    initializeDocumentationFixture root
    forM_ [1 .. (4 :: Int)] $ \ordinal ->
      TextIO.writeFile
        (root </> "documents" </> numberedName "boundary" ordinal ".md")
        (Text.replicate 4194304 "x")
    if over
      then TextIO.writeFile (root </> "documents" </> "boundary-5.md") "x"
      else pure ()
    result <- documentationWorktreeDiagnostic root
    pure
      ( boundaryExpectation
          over
          "pre-read aggregate byte boundary"
          "DOC-DISCOVERY-TOTAL-BYTE-LIMIT"
          "documents/"
          result
      )

withDocumentationFixture :: String -> (FilePath -> IO [String]) -> IO [String]
withDocumentationFixture label action = do
  executable <- getExecutablePath
  let root = takeDirectory executable </> "io-fixtures" </> label
  bracket (prepare root) cleanup action
 where
  prepare root = do
    exists <- doesDirectoryExist root
    if exists then removePathForcibly root else pure ()
    createDirectoryIfMissing True root
    pure root
  cleanup root = do
    exists <- doesDirectoryExist root
    if exists then removePathForcibly root else pure ()

initializeDocumentationFixture :: FilePath -> IO ()
initializeDocumentationFixture root = do
  createDirectoryIfMissing True (root </> "documents")
  createDirectoryIfMissing True (root </> "DEVELOPMENT_PLAN")
  writeEmpty (root </> "README.md")
  writeEmpty (root </> "AGENTS.md")
  writeEmpty (root </> "CLAUDE.md")

writeEmpty :: FilePath -> IO ()
writeEmpty path = TextIO.writeFile path ""

numberedName :: String -> Int -> String -> String
numberedName prefix ordinal suffix = prefix <> "-" <> show ordinal <> suffix

boundaryLabel :: Bool -> String
boundaryLabel over = if over then "plus-one" else "exact"

boundaryExpectation :: Bool -> String -> Text -> FilePath -> CheckResult -> [String]
boundaryExpectation over label code subject result =
  if over
    then expectFindingInResult (label <> " plus one") code subject result
    else expectNoFindingCode (label <> " exact limit") code result

expectObservation :: String -> Text -> Text -> CheckResult -> [String]
expectObservation label key expected result =
  [ label <> ": expected exactly [" <> show expected <> "], observed " <> show observed
  | observed /= [expected]
  ]
 where
  observed =
    [ observationValue item
    | item <- checkObservations result
    , observationKey item == key
    ]

linkedCorpus :: [(FilePath, Text)]
linkedCorpus = documentationCorpus True

unlinkedCorpus :: [(FilePath, Text)]
unlinkedCorpus = documentationCorpus False

bodyStatusCorpus :: [(FilePath, Text)]
bodyStatusCorpus =
  appendTo
    "AGENTS.md"
    "\n## Sprint-shaped body content\n\n**Status**: Blocked — NOT VALIDATED\n\n> **Purpose**: This is a body example, not header metadata.\n"
    unlinkedCorpus

parentTraversalCorpus :: [(FilePath, Text)]
parentTraversalCorpus =
  replaceIn
    canonicalRegisterPath
    "**Referenced by**: none"
    ("**Referenced by**: " <> Text.pack parentDocumentPath)
    ( unlinkedCorpus
        <> [ ( parentDocumentPath
             , governedDocument
                 "Nested Documentation Client"
                 "Exercise repository-relative Markdown resolution."
                 "none"
                 ( Text.unlines
                     [ "## Wrapped Constructs"
                     , ""
                     , "The code span is physically wrapped but remains one `alpha +"
                     , "beta` expression. The [legacy"
                     , "register](../../DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md#active-register) is canonical."
                     ]
                 )
             )
           ]
    )

escapingTraversalCorpus :: [(FilePath, Text)]
escapingTraversalCorpus =
  unlinkedCorpus
    <> [ ( parentDocumentPath
         , governedDocument
             "Escaping Documentation Client"
             "Exercise repository-boundary refusal."
             "none"
             "## Escape Attempt\n\n[Outside](../../../outside.md) must be refused."
         )
       ]

parentDocumentPath :: FilePath
parentDocumentPath = "documents/engineering/nested_client.md"

auxiliaryInboundCorpus :: [(FilePath, Text)]
auxiliaryInboundCorpus =
  replaceIn
    policyPath
    "**Referenced by**: none"
    "**Referenced by**: vendor/dual/PROVENANCE.md"
    ( unlinkedCorpus
        <> [ ( "vendor/dual/PROVENANCE.md"
             , "# Non-governed provenance\n\n[Target policy](../../documents/policy.md#target-section)\n"
             )
           ]
    )

blockBorrowingCorpus :: [(FilePath, Text)]
blockBorrowingCorpus =
  appendTo
    "AGENTS.md"
    "\n## Broken `heading\nA later paragraph closes` nothing.\n\n| `broken table cell |\n| closer` |\n"
    unlinkedCorpus

documentationCorpus :: Bool -> [(FilePath, Text)]
documentationCorpus includeLink =
  [ ( "README.md"
    , governedDocument
        "Amoebius"
        "Repository orientation."
        "none"
        ( if includeLink
            then "## Orientation\n\nRead the [target policy](documents/policy.md#target-section)."
            else "## Orientation\n\nThis is the repository orientation."
        )
    )
  , ("AGENTS.md", governedDocument "Agent Instructions" "Agent policy." "CLAUDE.md" "## Rules\n\nAgent rules live here.")
  , ("CLAUDE.md", "@AGENTS.md\n")
  , ( policyPath
    , governedDocument
        "Target Policy"
        "Define one linked target."
        (if includeLink then "README.md" else "none")
        "## Target Section\n\nThis heading is the independently chosen link target."
    )
  , ( registryOwnerPath
    , governedDocument
        "Service Capability Doctrine"
        "Own the fixed registry selection."
        "none"
        "## Registry Selection\n\nHarbor is prohibited. Distribution registry:2 is the fixed provider."
    )
  , ( canonicalRegisterPath
    , governedDocument
        "Legacy Tracking for Deletion"
        "Record active obligations only."
        "none"
        "## Active Register\n\nThe synthetic register has one canonical active locus."
    )
  ]

policyPath :: FilePath
policyPath = "documents/policy.md"

registryOwnerPath :: FilePath
registryOwnerPath = "documents/engineering/service_capability_doctrine.md"

registryPlacementOwnerPath :: FilePath
registryPlacementOwnerPath = "documents/engineering/image_build_doctrine.md"

registryPlacementOwnerHeading :: Text
registryPlacementOwnerHeading =
  "## 2. The single distribution rule: bake the binaries, build the amoebius image, pull only in-cluster"

policyOwnerCorpus :: [(FilePath, Text)]
policyOwnerCorpus =
  [ ownerDocument "documents/engineering/repository_layout_doctrine.md" "## 1. Classification rule"
  , ownerDocument "documents/engineering/substrate_doctrine.md" "## 6. The pre-binary handoff contract"
  , ownerDocument "documents/engineering/generated_artifacts_doctrine.md" "## 3. The rule"
  , ownerDocument registryOwnerPath "## 3. Canonical providers; extension is capability-specific"
  , ownerDocument registryPlacementOwnerPath registryPlacementOwnerHeading
  , ownerDocument canonicalRegisterPath "## 1. Register contract"
  , ownerDocument "DEVELOPMENT_PLAN/phase_00_documentation_suite.md" "## Phase Status"
  , ownerDocument
      "DEVELOPMENT_PLAN/development_plan_phase_model.md"
      "## E. One canonical phase model\n\n## L. One-substrate discipline"
  , ownerDocument
      "DEVELOPMENT_PLAN/development_plan_gate_integrity.md"
      "### M.6 Candidate evidence and gate pass"
  ]

ownerDocument :: FilePath -> Text -> (FilePath, Text)
ownerDocument path headings = (path, "# Owner fixture\n\n" <> headings <> "\n")

oracleOwnerContract :: [(Text, FilePath, Text, Text)]
oracleOwnerContract =
  [ owner "TrackedSourceBoundary" "documents/engineering/repository_layout_doctrine.md" "1-classification-rule" "1. Classification rule"
  , owner "PbBootstrapBoundary" "documents/engineering/substrate_doctrine.md" "6-the-pre-binary-handoff-contract" "6. The pre-binary handoff contract"
  , owner "LazyBuildGeneration" "documents/engineering/generated_artifacts_doctrine.md" "3-the-rule" "3. The rule"
  , owner "ClusterRegistryProvider" registryOwnerPath "3-canonical-providers-extension-is-capability-specific" "3. Canonical providers; extension is capability-specific"
  , owner "ClusterRegistryPlacement" registryPlacementOwnerPath "2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster" "2. The single distribution rule: bake the binaries, build the amoebius image, pull only in-cluster"
  , owner "ActiveLegacyRegister" canonicalRegisterPath "1-register-contract" "1. Register contract"
  , owner "ValidationStatusReset" "DEVELOPMENT_PLAN/phase_00_documentation_suite.md" "phase-status" "Phase Status"
  , owner "NumericPhaseOrder" "DEVELOPMENT_PLAN/development_plan_phase_model.md" "e-one-canonical-phase-model" "E. One canonical phase model"
  , owner "DslBarrierSourceClosurePolicy" "DEVELOPMENT_PLAN/development_plan_phase_model.md" "e-one-canonical-phase-model" "E. One canonical phase model"
  , owner "PrehardwareGateBarrier" "DEVELOPMENT_PLAN/development_plan_phase_model.md" "l-one-substrate-discipline" "L. One-substrate discipline"
  , owner "GatePassPolicy" "DEVELOPMENT_PLAN/development_plan_gate_integrity.md" "m6-candidate-evidence-and-gate-pass" "M.6 Candidate evidence and gate pass"
  ]
 where
  owner identifier path anchor section =
    (identifier, path, anchor, section)

policyOwnerOracleContractProblems :: [String]
policyOwnerOracleContractProblems =
  [ "independent policy-owner contract cardinality changed: expected=11; actual="
      <> show (length oracleOwnerContract)
  | length oracleOwnerContract /= 11
  ]
    <> [ "independent policy-owner contract contains duplicate identities"
       | Set.size (Set.fromList [identifier | (identifier, _, _, _) <- oracleOwnerContract])
           /= length oracleOwnerContract
       ]
    <> [ "independent policy-owner contract contains an empty field"
       | any (\(identifier, path, anchor, section) -> any null [Text.unpack identifier, path, Text.unpack anchor, Text.unpack section]) oracleOwnerContract
       ]

canonicalRegisterPath :: FilePath
canonicalRegisterPath = "DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md"

governedDocument :: Text -> Text -> Text -> Text -> Text
governedDocument title purpose referencedBy body =
  Text.unlines
    [ "# " <> title
    , "> **Purpose**: " <> purpose
    , "> **Read this if**: You need this synthetic component-diagnostic document."
    , ""
    , "This lead paragraph fixes the orientation shape without borrowing production prose."
    , ""
    , "<details>"
    , "<summary>Link-graph metadata</summary>"
    , ""
    , "**Status**: Authoritative source"
    , "**Supersedes**: N/A"
    , "**Referenced by**: " <> referencedBy
    , "**Generated sections**: none"
    , ""
    , "</details>"
    , ""
    , body
    ]

replaceIn :: FilePath -> Text -> Text -> [(FilePath, Text)] -> [(FilePath, Text)]
replaceIn wanted old new =
  map
    ( \entry@(path, contents) ->
        if path == wanted
          then (path, Text.replace old new contents)
          else entry
    )

appendTo :: FilePath -> Text -> [(FilePath, Text)] -> [(FilePath, Text)]
appendTo wanted suffix =
  map
    ( \entry@(path, contents) ->
        if path == wanted
          then (path, contents <> suffix)
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

expectClean :: String -> [(FilePath, Text)] -> [String]
expectClean label corpus =
  case checkFindings (documentationStructureDiagnostic corpus) of
    [item]
      | findingCode item == "DOC-STRUCTURE-DIAGNOSTIC-ONLY"
          && findingSubject item == "Amoebius.Validation.Documentation.documentationStructureDiagnostic"
          && findingDetail item == "caller-authored Markdown has no capture, semantic, gate-evidence, observer, or gate-pass result" -> []
    findings -> [label <> ": unexpected findings " <> show findings]

expectOnlyPolicyDiagnostic :: String -> CheckResult -> [String]
expectOnlyPolicyDiagnostic label result =
  [ label <> ": expected only the permanent policy-owner diagnostic refusal, observed " <> show findings
  | findings
      /= [ Finding
             "DOC-POLICY-OWNER-DIAGNOSTIC-ONLY"
             "Amoebius.Validation.Documentation.documentationPolicyOwnerDiagnostic"
             "caller-supplied owner documents have no exact source binding, gate-evidence, qualification, observer, or gate-pass result"
         ]
  ]
 where
  findings = checkFindings result

expectFinding :: String -> Text -> FilePath -> [(FilePath, Text)] -> [String]
expectFinding label code locus = expectFindingInResult label code locus . documentationStructureDiagnostic

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

expectExactFinding :: String -> Finding -> CheckResult -> [String]
expectExactFinding label expected result =
  [ label
      <> ": expected exact finding "
      <> show expected
      <> ", observed matching-code findings "
      <> show observed
  | observed /= [expected]
  ]
 where
  observed = filter ((== findingCode expected) . findingCode) (checkFindings result)

expectNoFindingCode :: String -> Text -> CheckResult -> [String]
expectNoFindingCode label code result =
  [label <> ": unexpectedly observed " <> Text.unpack code <> " in " <> show (checkFindings result)
  | any ((== code) . findingCode) (checkFindings result)
  ]

finishDiagnostics :: String -> [String] -> IO ()
finishDiagnostics name problems =
  unless
    (null problems)
    (fail (name <> " component diagnostic failures:\n  " <> Text.unpack (Text.intercalate "\n  " (map Text.pack problems))))
