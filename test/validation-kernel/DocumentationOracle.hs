{-# LANGUAGE OverloadedStrings #-}

module DocumentationOracle
  ( runDocumentationOracle
  ) where

-- Component diagnostics only.  This oracle does not perform human review,
-- qualify the documentation harness, validate a phase, or promote status.

import Amoebius.Validation.Documentation (checkDocumentStructure, checkDocuments)
import Amoebius.Validation.Types (CheckResult (..), Finding (..))
import Control.Monad (unless)
import Data.Text (Text)
import qualified Data.Text as Text

runDocumentationOracle :: IO ()
runDocumentationOracle =
  finishDiagnostics
    "DocumentationOracle"
    ( concat
        [ expectClean "minimal governed documentation corpus" linkedCorpus
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
