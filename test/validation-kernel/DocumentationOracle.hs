{-# LANGUAGE OverloadedStrings #-}

module DocumentationOracle
  ( runDocumentationOracle
  ) where

-- Component diagnostics only.  This oracle does not perform human review,
-- qualify the documentation harness, validate a phase, or promote status.

import Amoebius.Validation.Documentation (checkCorpus, checkDocumentStructure, checkDocuments, checkPolicyOwnerReferencesFor)
import Amoebius.Validation.PolicyContract qualified as Policy
import Amoebius.Validation.Types (CheckResult (..), Finding (..), Observation (..))
import Control.Monad (filterM, unless)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import qualified Data.Text as Text
import System.Directory (doesFileExist, getCurrentDirectory)
import System.FilePath ((</>), takeDirectory)

runDocumentationOracle :: IO ()
runDocumentationOracle = do
  productionInventory <- productionInventoryProblems
  finishDiagnostics
    "DocumentationOracle"
    ( productionInventory
        <> concat
        [ expectClean "minimal governed documentation corpus" linkedCorpus
        , expectNoFindings
            "independently stated policy owner structure"
            (checkPolicyOwnerReferencesFor oracleOwnerContract policyOwnerCorpus)
        , expectFindingInResult
            "policy owner heading and anchor are joined"
            "DOC-POLICY-OWNER-ANCHOR"
            registryOwnerPath
            ( checkPolicyOwnerReferencesFor
                oracleOwnerContract
                (replaceIn registryOwnerPath "## 3. Canonical providers; extension is capability-specific" "## 3. Wrong registry owner" policyOwnerCorpus)
            )
        , expectFindingInResult
            "registry placement has its own exact owner heading"
            "DOC-POLICY-OWNER-ANCHOR"
            registryPlacementOwnerPath
            ( checkPolicyOwnerReferencesFor
                oracleOwnerContract
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
            (appendTo "AGENTS.md" "\nThe reviewed mutation source is `test/mutant/ExampleMutant.hs`.\n" unlinkedCorpus)
        , expectClean
            "a policy keyword decoy is structurally inert"
            (appendTo "AGENTS.md" "\nA prose decoy mentions Harbor but has no executable authority.\n" unlinkedCorpus)
        , expectFindingInResult
            "production check rejects a synthetic partial path inventory"
            "DOC-INVENTORY-MISMATCH"
            "documents/"
            (checkDocuments linkedCorpus)
        , expectFindingInResult
            "empty governed discovery"
            "DOC-DISCOVERY-EMPTY"
            "documents/"
            (checkDocumentStructure [])
        , expectFindingInResult
            "ungoverned decoy cannot satisfy discovery"
            "DOC-DISCOVERY-EMPTY"
            "documents/"
            (checkDocumentStructure [("scratch/README.md", governedDocument "Decoy" "Decoy purpose." "none" "## Notes\n\nDecoy only.")])
        ]
    )

-- Worktree component diagnostic only.  These values are intentionally stated
-- independently of Documentation's production baseline.  Reading the current
-- governed corpus does not authenticate a snapshot, qualify this oracle,
-- validate a phase, perform prose-correspondence review, or promote status.
productionInventoryProblems :: IO [String]
productionInventoryProblems = do
  current <- getCurrentDirectory
  roots <- filterM isRepositoryRoot (ancestors current)
  case roots of
    [] -> pure ["production governed inventory: no ancestor contains amoebius.cabal"]
    root : _ -> do
      result <- checkCorpus root
      let inventoryFindings =
            [ item
            | item <- checkFindings result
            , findingCode item == "DOC-INVENTORY-MISMATCH"
            ]
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
            <> [ "production governed inventory baseline rejected the independently observed corpus: "
                   <> show inventoryFindings
               | not (null inventoryFindings)
               ]
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
      "### M.6 Candidate evidence and human promotion"
  ]

ownerDocument :: FilePath -> Text -> (FilePath, Text)
ownerDocument path headings = (path, "# Owner fixture\n\n" <> headings <> "\n")

oracleOwnerContract :: Policy.PolicyContract
oracleOwnerContract =
  Policy.canonicalPolicyContract
    { Policy.contractOwners =
        Map.fromList
          [ owner Policy.TrackedSourceBoundary "documents/engineering/repository_layout_doctrine.md" "1-classification-rule" "1. Classification rule"
          , owner Policy.PbBootstrapBoundary "documents/engineering/substrate_doctrine.md" "6-the-pre-binary-handoff-contract" "6. The pre-binary handoff contract"
          , owner Policy.LazyBuildGeneration "documents/engineering/generated_artifacts_doctrine.md" "3-the-rule" "3. The rule"
          , owner Policy.ClusterRegistryProvider registryOwnerPath "3-canonical-providers-extension-is-capability-specific" "3. Canonical providers; extension is capability-specific"
          , owner Policy.ClusterRegistryPlacement registryPlacementOwnerPath "2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster" "2. The single distribution rule: bake the binaries, build the amoebius image, pull only in-cluster"
          , owner Policy.ActiveLegacyRegister canonicalRegisterPath "1-register-contract" "1. Register contract"
          , owner Policy.ValidationStatusReset "DEVELOPMENT_PLAN/phase_00_documentation_suite.md" "phase-status" "Phase Status"
          , owner Policy.NumericPhaseOrder "DEVELOPMENT_PLAN/development_plan_phase_model.md" "e-one-canonical-phase-model" "E. One canonical phase model"
          , owner Policy.DslBarrierSourceClosurePolicy "DEVELOPMENT_PLAN/development_plan_phase_model.md" "e-one-canonical-phase-model" "E. One canonical phase model"
          , owner Policy.PrehardwarePromotionBarrier "DEVELOPMENT_PLAN/development_plan_phase_model.md" "l-one-substrate-discipline" "L. One-substrate discipline"
          , owner Policy.PromotionAuthorityPolicy "DEVELOPMENT_PLAN/development_plan_gate_integrity.md" "m6-candidate-evidence-and-human-promotion" "M.6 Candidate evidence and human promotion"
          ]
    }
 where
  owner identifier path anchor section =
    (identifier, Policy.PolicyOwnerReference path anchor section)

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
  case checkFindings (checkDocumentStructure corpus) of
    [] -> []
    findings -> [label <> ": unexpected findings " <> show findings]

expectNoFindings :: String -> CheckResult -> [String]
expectNoFindings label result =
  [label <> ": unexpected findings " <> show (checkFindings result) | not (null (checkFindings result))]

expectFinding :: String -> Text -> FilePath -> [(FilePath, Text)] -> [String]
expectFinding label code locus = expectFindingInResult label code locus . checkDocumentStructure

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

finishDiagnostics :: String -> [String] -> IO ()
finishDiagnostics name problems =
  unless
    (null problems)
    (fail (name <> " component diagnostic failures:\n  " <> Text.unpack (Text.intercalate "\n  " (map Text.pack problems))))
