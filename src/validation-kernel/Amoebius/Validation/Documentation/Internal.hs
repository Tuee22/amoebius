{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.Documentation.Internal
  ( checkCorpus
  , checkCorpusDiagnostic
  , checkDocumentStructure
  , checkInventoryDiagnostic
  , checkDocuments
  , checkPolicyOwnerDiagnostic
  , checkPolicyOwnerReferences
  , forwardDeferredDeclarations
  , githubAnchor
  ) where

import Amoebius.Validation.PhaseContract.Internal (checkPhaseContracts)
import Amoebius.Validation.PolicyContract.Internal qualified as Policy
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding (..)
  , Observation (..)
  , finding
  , mergeChecks
  , observation
  )
import Control.Exception (IOException, try)
#if !defined(mingw32_HOST_OS)
import Control.Exception (bracket)
#endif
import Control.Monad (foldM, forM)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString qualified as ByteString
import Data.Char (intToDigit, isAlphaNum, isDigit, isSpace, isUpper, toLower)
import Data.List (sort)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (listToMaybe, mapMaybe)
import Data.IORef (IORef, atomicModifyIORef', newIORef, readIORef)
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Text.IO qualified as TextIO
import System.Directory
  ( doesDirectoryExist
  , doesFileExist
  , getFileSize
  , pathIsSymbolicLink
  )
import System.FilePath.Posix
  ( (</>)
  , normalise
  , takeDirectory
  , takeExtension
  , takeFileName
  )
#if !defined(mingw32_HOST_OS)
import System.Posix.Directory (closeDirStream, openDirStream, readDirStream)
#else
import System.Directory (listDirectory)
#endif

data Document = Document
  { documentPath :: FilePath
  , documentText :: Text
  , documentVisibleLines :: [(Int, Text)]
  , documentMarkdownBlocks :: [(Int, Text)]
  , documentAnchors :: Set Text
  , documentLinks :: [LocalLink]
  }
  deriving (Eq, Show)

data LocalLink = LocalLink
  { linkLine :: Int
  , linkTarget :: Text
  }
  deriving (Eq, Ord, Show)

data MarkdownLine = MarkdownLine
  { markdownLineTargets :: [Text]
  , markdownLineProblems :: [Text]
  }
  deriving (Eq, Show)

data Fence = Fence Char Int
  deriving (Eq, Show)

data MarkdownBlockKind
  = ParagraphBlock
  | ListItemBlock
  | BlockquoteBlock
  | AtomicBlock
  deriving (Eq, Show)

data ProseBudgetMeasurement = ProseBudgetMeasurement
  { proseBudgetPath :: FilePath
  , proseBudgetLine :: Int
  , proseBudgetSentenceWords :: [Int]
  }
  deriving (Eq, Ord, Show)

data Metadata = Metadata
  { metadataStatus :: Maybe Text
  , metadataSupersedes :: Maybe Text
  , metadataReferencedBy :: Maybe Text
  , metadataGeneratedSections :: Maybe Text
  }
  deriving (Eq, Show)

data DiscoveryBudget = DiscoveryBudget
  { discoveryDirectoryEntries :: Int
  , discoveryMarkdownFiles :: Int
  , discoveryMarkdownBytes :: Integer
  }
  deriving (Eq, Show)

-- | Worktree diagnostic only. Candidate evaluation must call 'checkDocuments'
-- with the immutable blob corpus obtained by source-closure discovery; this
-- convenience function reads mutable filesystem bytes and therefore cannot
-- establish candidate provenance.
checkCorpus :: FilePath -> IO CheckResult
checkCorpus root = do
  (documents, discoveryFindings, discoveryBudget) <- discoverDocuments root
  let discovery =
        CheckResult
          { checkName = "documentation-discovery"
          , checkObservations =
              [ observation "supplied-document-count" (showText (length documents))
              , observation "governed-document-count" (showText (length (filter (isGovernedPath . fst) documents)))
              , observation "documentation-discovery.directory-entry-count" (showText (discoveryDirectoryEntries discoveryBudget))
              , observation "documentation-discovery.markdown-file-count" (showText (discoveryMarkdownFiles discoveryBudget))
              , observation "documentation-discovery.markdown-byte-count" (showText (discoveryMarkdownBytes discoveryBudget))
              ]
          , checkFindings = discoveryFindings
          }
  pure
    ( mergeChecks
        "documentation-corpus"
        [ retainDocumentationDiscoveryCheck discovery
        , retainDocumentationDocumentCheck (checkDocuments documents)
        , retainDocumentationPhaseContractCheck (checkPhaseContracts documents)
        ]
    )

retainDocumentationDiscoveryCheck :: CheckResult -> CheckResult
#ifdef VALIDATION_DOCUMENT_CORPUS_DISCOVERY_COMPOSITION_MUTANT
retainDocumentationDiscoveryCheck result = result {checkObservations = [], checkFindings = []}
#else
retainDocumentationDiscoveryCheck = id
#endif

retainDocumentationDocumentCheck :: CheckResult -> CheckResult
#ifdef VALIDATION_DOCUMENT_CORPUS_DOCUMENT_COMPOSITION_MUTANT
retainDocumentationDocumentCheck result = result {checkObservations = [], checkFindings = []}
#else
retainDocumentationDocumentCheck = id
#endif

retainDocumentationPhaseContractCheck :: CheckResult -> CheckResult
#ifdef VALIDATION_DOCUMENT_CORPUS_PHASE_CONTRACT_COMPOSITION_MUTANT
retainDocumentationPhaseContractCheck result = result {checkObservations = [], checkFindings = []}
#else
retainDocumentationPhaseContractCheck = id
#endif

-- | Mutable-worktree convenience for public diagnostics. The hidden
-- dispatcher never calls this route: it supplies exact local snapshot bytes
-- directly to 'checkDocuments'. The public route retains a permanent refusal
-- even when its mutable observation happens to match the authored manifest.
checkCorpusDiagnostic :: FilePath -> IO CheckResult
checkCorpusDiagnostic root = do
  result <- checkCorpus root
  pure (prependRequiredFindingsAndBound documentationCorpusDiagnosticRefusal result)

documentationCorpusDiagnosticRefusal :: [Finding]
#ifdef VALIDATION_DOCUMENT_CORPUS_DIAGNOSTIC_BYPASS_MUTANT
documentationCorpusDiagnosticRefusal = []
#else
documentationCorpusDiagnosticRefusal =
  [ finding
      "DOC-CORPUS-DIAGNOSTIC-ONLY"
      "Amoebius.Validation.Documentation.documentationWorktreeDiagnostic"
      "mutable worktree discovery has no exact source binding, gate-evidence, qualification, observer, or gate-pass result"
  ]
#endif

-- | Production documentation check. Paths are repository-relative; order is
-- immaterial, but the complete governed path manifest is frozen in Haskell.
checkDocuments :: [(FilePath, Text)] -> CheckResult
checkDocuments = checkDocumentsWithInventory True

-- | Structural seam for small independently-authored parser corpora. It never
-- establishes production discovery completeness and must not be wired to the
-- dispatcher or candidate evidence. Caller-authored bytes therefore always
-- retain an exact permanent refusal, including when every structural predicate
-- accepts them.
checkDocumentStructure :: [(FilePath, Text)] -> CheckResult
checkDocumentStructure supplied =
  prependRequiredFindingsAndBound
    documentationStructureDiagnosticRefusal
    (checkDocumentsWithInventoryUnbounded False supplied)

-- | Canonical-inventory parser diagnostic for the component oracle. Candidate
-- consumers use the hidden 'checkDocuments' route only after source
-- capture; callers of this wrapper can never obtain an authority-bearing
-- success branch.
checkInventoryDiagnostic :: [(FilePath, Text)] -> CheckResult
checkInventoryDiagnostic supplied =
  prependRequiredFindingsAndBound
    documentationInventoryDiagnosticRefusal
    (checkDocumentsWithInventoryUnbounded True supplied)

documentationInventoryDiagnosticRefusal :: [Finding]
#ifdef VALIDATION_DOCUMENT_INVENTORY_DIAGNOSTIC_BYPASS_MUTANT
documentationInventoryDiagnosticRefusal = []
#else
documentationInventoryDiagnosticRefusal =
  [ finding
      "DOC-INVENTORY-DIAGNOSTIC-ONLY"
      "Amoebius.Validation.Documentation.documentationInventoryDiagnostic"
      "caller-supplied inventory bytes have no exact source binding, gate-evidence, qualification, observer, or gate-pass result"
  ]
#endif

documentationStructureDiagnosticRefusal :: [Finding]
#ifdef VALIDATION_DOCUMENT_STRUCTURE_DIAGNOSTIC_BYPASS_MUTANT
documentationStructureDiagnosticRefusal = []
#else
documentationStructureDiagnosticRefusal =
  [ finding
      "DOC-STRUCTURE-DIAGNOSTIC-ONLY"
      "Amoebius.Validation.Documentation.documentationStructureDiagnostic"
      "caller-authored Markdown has no capture, semantic, gate-evidence, observer, or gate-pass result"
  ]
#endif

checkDocumentsWithInventory :: Bool -> [(FilePath, Text)] -> CheckResult
checkDocumentsWithInventory enforceCanonicalInventory supplied =
  boundDocumentationResult
    (checkDocumentsWithInventoryUnbounded enforceCanonicalInventory supplied)

checkDocumentsWithInventoryUnbounded :: Bool -> [(FilePath, Text)] -> CheckResult
checkDocumentsWithInventoryUnbounded enforceCanonicalInventory supplied =
  case retainDocumentationInputEnvelopeFindings (documentationInputEnvelopeFindings supplied) of
    [] -> checkDocumentsWithinEnvelope enforceCanonicalInventory supplied
    envelopeFindings ->
      CheckResult
        { checkName = "documentation"
        , checkObservations =
            [ observation "documentation-input-envelope" "refused-before-parse"
            , observation "documentation-input-entry-limit" (showText documentationInputEntryLimit)
            , observation "documentation-input-path-character-limit" (showText documentationInputPathCharacterLimit)
            , observation "documentation-input-document-character-limit" (showText documentationInputDocumentCharacterLimit)
            , observation "documentation-input-total-character-limit" (showText documentationInputTotalCharacterLimit)
            ]
        , checkFindings = envelopeFindings
        }

retainDocumentationInputEnvelopeFindings :: [Finding] -> [Finding]
#ifdef VALIDATION_DOCUMENT_INPUT_ENVELOPE_ROUTE_BYPASS_MUTANT
retainDocumentationInputEnvelopeFindings findings = length findings `seq` []
#else
retainDocumentationInputEnvelopeFindings = id
#endif

checkDocumentsWithinEnvelope :: Bool -> [(FilePath, Text)] -> CheckResult
checkDocumentsWithinEnvelope enforceCanonicalInventory supplied =
  CheckResult
    { checkName = "documentation"
    , checkObservations =
        [ observation "document-count" (showText (Map.size documents))
        , observation "governed-count" (showText (length governed))
        , observation "local-link-count" (showText (sum (map (length . documentLinks) governed)))
        , observation "archive-alias-count" (showText archiveCount)
        , observation "governed-path-manifest-sha256" governedPathDigest
        ]
          <> proseBudgetObservations governed
    , checkFindings =
        retainDocumentationDuplicateFindings duplicateFindings
          <> retainDocumentationEmptyDiscoveryFindings emptyDiscoveryFindings
          <> retainDocumentationRequiredCorpusFindings requiredCorpusFindings
          <> retainDocumentationInventoryFindings inventoryFindings
          <> retainDocumentationHeaderFindings
            (concatMap checkHeader (filter ((/= "CLAUDE.md") . documentPath) governed))
          <> retainDocumentationClaudeFindings (checkClaudeImport documents)
          <> retainDocumentationMarkdownFindings (concatMap checkMarkdownSyntax governed)
          <> retiredArtifactCorpusFindings governed
          <> retainDocumentationLinkFindings (concatMap (checkLinks documents) governed)
          <> retainDocumentationBacklinkFindings (checkReferencedBy documents governed)
          <> retainDocumentationArchiveFindings (checkArchivePolicy documents governed archiveCount)
          <> retainDocumentationOwnerFindings
            [ item
            | enforceCanonicalInventory
            , item <- policyOwnerFindings canonicalRawPolicyOwners documents
            ]
          <> retainDocumentationCitationFindings (checkRulebookCitations documents governed)
          <> retainDocumentationForwardDeferredFindings (checkForwardDeferred governed)
    }
 where
  normalized = [(normalizePath path, contents) | (path, contents) <- supplied]
  grouped = Map.fromListWith (<>) [(path, [contents]) | (path, contents) <- normalized]
  duplicateFindings =
    [ finding "DOC-DUPLICATE" path "document path occurs more than once in the supplied corpus"
    | (path, copies) <- Map.toAscList grouped
    , documentationDuplicatePathForbidden copies
    ]
  documents = Map.mapMaybeWithKey (\path copies -> makeDocumentFor path <$> listToMaybe copies) grouped
  governed = filter (isGovernedPath . documentPath) (Map.elems documents)
  emptyDiscoveryFindings =
    [ finding "DOC-DISCOVERY-EMPTY" "documents/" "no governed Markdown documents were supplied"
    | documentationGovernedDiscoveryEmpty governed
    ]
  requiredCorpusFindings =
    [ finding "DOC-DISCOVERY-MISSING" path "required governed root document is absent from the supplied corpus"
    | path <- requiredGovernedRootDocuments
    , not (Map.member path documents)
    ]
      <> [ finding "DOC-DISCOVERY-MISSING" prefix "required governed documentation subtree is absent from the supplied corpus"
         | prefix <- requiredGovernedSubtrees
         , not (any (pathPrefixOf prefix) (Map.keys documents))
         ]
  governedPaths = sort (map documentPath governed)
  governedPathDigest = hex (SHA256.hash (TextEncoding.encodeUtf8 (Text.unlines (map Text.pack governedPaths))))
  inventoryFindings =
    [ finding
        "DOC-INVENTORY-COUNT"
        "documents/"
        ( "governed path count is beneath the authored floor, so discovery cannot have been complete: floor="
            <> showText minimumGovernedPathCount
            <> ", observed="
            <> showText (length governedPaths)
        )
    | enforceCanonicalInventory
    , documentationInventoryCountMismatch (length governedPaths)
    ]

-- The governed-path digest is retained as an observation, never as a finding.
-- Pinning the exact set made every legitimate documentation change a gate
-- refusal while proving nothing the count floor, the duplicate-path rule, the
-- required-root rules, and the backlink join do not already prove.  It is a
-- change tripwire, which @LTD-VAL-006@ already records is not an independent
-- expectation.
  -- The eliminated filename is a structural alias, not a semantic policy
  -- phrase. Cross-cutting policy prose is deliberately not interpreted here:
  -- executable choices belong to PolicyContract and prose correspondence is
  -- an external documentation-correspondence obligation.
  archiveCount = sum (map archiveAliasCount governed)

documentationDuplicatePathForbidden :: [value] -> Bool
#ifdef VALIDATION_DOCUMENT_DUPLICATE_PATH_BYPASS_MUTANT
documentationDuplicatePathForbidden copies = length copies /= 1 `seq` False
#else
documentationDuplicatePathForbidden copies = length copies /= 1
#endif

documentationGovernedDiscoveryEmpty :: [Document] -> Bool
#ifdef VALIDATION_DOCUMENT_EMPTY_DISCOVERY_BYPASS_MUTANT
documentationGovernedDiscoveryEmpty governed = null governed `seq` False
#else
documentationGovernedDiscoveryEmpty = null
#endif

requiredGovernedRootDocuments :: [FilePath]
requiredGovernedRootDocuments =
  concat
    [
#ifdef VALIDATION_DOCUMENT_REQUIRED_README_OMISSION_MUTANT
      []
#else
      ["README.md"]
#endif
    ,
#ifdef VALIDATION_DOCUMENT_REQUIRED_AGENTS_OMISSION_MUTANT
      []
#else
      ["AGENTS.md"]
#endif
    ,
#ifdef VALIDATION_DOCUMENT_REQUIRED_CLAUDE_OMISSION_MUTANT
      []
#else
      ["CLAUDE.md"]
#endif
    ]

-- A root-level incident report is not a required governance document.  The
-- previous required entry named a file that has since been removed, so the
-- documentation gate refused for the absence of a transient artefact rather
-- than for any governance defect.  Root-level Markdown that exists is still
-- discovered and still carries the structural contract; it is simply not
-- required to exist by name.

requiredGovernedSubtrees :: [FilePath]
requiredGovernedSubtrees =
  concat
    [
#ifdef VALIDATION_DOCUMENT_REQUIRED_DOCUMENTS_OMISSION_MUTANT
      []
#else
      ["documents"]
#endif
    ,
#ifdef VALIDATION_DOCUMENT_REQUIRED_PLAN_OMISSION_MUTANT
      []
#else
      ["DEVELOPMENT_PLAN"]
#endif
    ]

documentationInventoryCountMismatch :: Int -> Bool
#ifdef VALIDATION_DOCUMENT_INVENTORY_COUNT_BYPASS_MUTANT
documentationInventoryCountMismatch observed = observed < minimumGovernedPathCount `seq` False
#else
documentationInventoryCountMismatch observed = observed < minimumGovernedPathCount
#endif

retainDocumentationDuplicateFindings :: [Finding] -> [Finding]
#ifdef VALIDATION_DOCUMENT_DUPLICATE_ROUTE_OMISSION_MUTANT
retainDocumentationDuplicateFindings findings = length findings `seq` []
#else
retainDocumentationDuplicateFindings = id
#endif

retainDocumentationEmptyDiscoveryFindings :: [Finding] -> [Finding]
#ifdef VALIDATION_DOCUMENT_EMPTY_DISCOVERY_ROUTE_OMISSION_MUTANT
retainDocumentationEmptyDiscoveryFindings findings = length findings `seq` []
#else
retainDocumentationEmptyDiscoveryFindings = id
#endif

retainDocumentationRequiredCorpusFindings :: [Finding] -> [Finding]
#ifdef VALIDATION_DOCUMENT_REQUIRED_CORPUS_ROUTE_OMISSION_MUTANT
retainDocumentationRequiredCorpusFindings findings = length findings `seq` []
#else
retainDocumentationRequiredCorpusFindings = id
#endif

retainDocumentationInventoryFindings :: [Finding] -> [Finding]
#ifdef VALIDATION_DOCUMENT_INVENTORY_ROUTE_OMISSION_MUTANT
retainDocumentationInventoryFindings findings = length findings `seq` []
#else
retainDocumentationInventoryFindings = id
#endif

retainDocumentationHeaderFindings :: [Finding] -> [Finding]
#ifdef VALIDATION_DOCUMENT_HEADER_ROUTE_OMISSION_MUTANT
retainDocumentationHeaderFindings findings = length findings `seq` []
#else
retainDocumentationHeaderFindings = id
#endif

retainDocumentationClaudeFindings :: [Finding] -> [Finding]
#ifdef VALIDATION_DOCUMENT_CLAUDE_ROUTE_OMISSION_MUTANT
retainDocumentationClaudeFindings findings = length findings `seq` []
#else
retainDocumentationClaudeFindings = id
#endif

retainDocumentationMarkdownFindings :: [Finding] -> [Finding]
#ifdef VALIDATION_DOCUMENT_MARKDOWN_ROUTE_OMISSION_MUTANT
retainDocumentationMarkdownFindings findings = length findings `seq` []
#else
retainDocumentationMarkdownFindings = id
#endif

retainDocumentationLinkFindings :: [Finding] -> [Finding]
#ifdef VALIDATION_DOCUMENT_LINK_ROUTE_OMISSION_MUTANT
retainDocumentationLinkFindings findings = length findings `seq` []
#else
retainDocumentationLinkFindings = id
#endif

retainDocumentationBacklinkFindings :: [Finding] -> [Finding]
#ifdef VALIDATION_DOCUMENT_BACKLINK_ROUTE_OMISSION_MUTANT
retainDocumentationBacklinkFindings findings = length findings `seq` []
#else
retainDocumentationBacklinkFindings = id
#endif

retainDocumentationArchiveFindings :: [Finding] -> [Finding]
#ifdef VALIDATION_DOCUMENT_ARCHIVE_ROUTE_OMISSION_MUTANT
retainDocumentationArchiveFindings findings = length findings `seq` []
#else
retainDocumentationArchiveFindings = id
#endif

retainDocumentationOwnerFindings :: [Finding] -> [Finding]
#ifdef VALIDATION_DOCUMENT_OWNER_ROUTE_OMISSION_MUTANT
retainDocumentationOwnerFindings findings = length findings `seq` []
#else
retainDocumentationOwnerFindings = id
#endif

-- Keep every cardinality and size decision in front of normalization, maps,
-- sorting, hashing, Markdown parsing, and result construction.  The supplied
-- values are already resident Haskell values, but an oversized caller value
-- must not amplify work inside this diagnostic seam.
documentationInputEnvelopeFindings :: [(FilePath, Text)] -> [Finding]
documentationInputEnvelopeFindings supplied
  | documentationEntryCountExceeded supplied =
      [ finding
          "DOC-INPUT-ENTRY-LIMIT"
          "documents/"
          ("supplied documentation entry count exceeds " <> showText documentationInputEntryLimit)
      ]
  | not (null pathFindings) = pathFindings
  | not (null documentFindings) = documentFindings
  | documentationTotalCharactersExceeded supplied =
      [ finding
          "DOC-INPUT-TOTAL-LIMIT"
          "documents/"
          ("supplied documentation character total exceeds " <> showText documentationInputTotalCharacterLimit)
      ]
  | otherwise = []
 where
  pathFindings =
    [ finding
        "DOC-INPUT-PATH-LIMIT"
        "supplied-path"
        ( "entry "
            <> showText ordinal
            <> " path exceeds "
            <> showText documentationInputPathCharacterLimit
            <> " characters"
        )
    | (ordinal, (path, _)) <- zip [(1 :: Int) ..] supplied
    , documentationPathCharactersExceeded path
    ]
  documentFindings =
    [ finding
        "DOC-INPUT-DOCUMENT-LIMIT"
        (normalizePath path)
        ("document exceeds " <> showText documentationInputDocumentCharacterLimit <> " characters")
    | (path, contents) <- supplied
    , documentationDocumentCharactersExceeded contents
    ]

documentationEntryCountExceeded :: [(FilePath, Text)] -> Bool
#ifdef VALIDATION_DOCUMENT_INPUT_ENTRY_LIMIT_BYPASS_MUTANT
documentationEntryCountExceeded _ = False
#else
documentationEntryCountExceeded = hasMoreThan documentationInputEntryLimit
#endif

documentationPathCharactersExceeded :: FilePath -> Bool
#ifdef VALIDATION_DOCUMENT_INPUT_PATH_LIMIT_BYPASS_MUTANT
documentationPathCharactersExceeded _ = False
#else
documentationPathCharactersExceeded = hasMoreThan documentationInputPathCharacterLimit
#endif

documentationDocumentCharactersExceeded :: Text -> Bool
#ifdef VALIDATION_DOCUMENT_INPUT_DOCUMENT_LIMIT_BYPASS_MUTANT
documentationDocumentCharactersExceeded _ = False
#else
documentationDocumentCharactersExceeded contents = Text.length contents > documentationInputDocumentCharacterLimit
#endif

documentationTotalCharactersExceeded :: [(FilePath, Text)] -> Bool
#ifdef VALIDATION_DOCUMENT_INPUT_TOTAL_LIMIT_BYPASS_MUTANT
documentationTotalCharactersExceeded _ = False
#else
documentationTotalCharactersExceeded = go 0
 where
  go _ [] = False
  go accumulated ((_, contents) : rest)
    | Text.length contents > documentationInputTotalCharacterLimit - accumulated = True
    | otherwise = go (accumulated + Text.length contents) rest
#endif

hasMoreThan :: Int -> [a] -> Bool
hasMoreThan limit = not . null . drop limit

documentationInputEntryLimit :: Int
documentationInputEntryLimit = 256

documentationInputPathCharacterLimit :: Int
documentationInputPathCharacterLimit = 4096

documentationInputDocumentCharacterLimit :: Int
documentationInputDocumentCharacterLimit = 1048576

documentationInputTotalCharacterLimit :: Int
documentationInputTotalCharacterLimit = 8388608

-- Bound the rendered diagnostic carrier separately from its input. A parser
-- can turn a bounded Markdown corpus into many findings and observations; no
-- caller may force an unbounded result merely by maximizing line or link
-- density inside the admitted input envelope.
boundDocumentationResult :: CheckResult -> CheckResult
boundDocumentationResult result =
  case documentationOutputEnvelopeProblem result of
    Nothing -> result
    Just problem ->
      CheckResult
        { checkName = "documentation-output-refusal"
        , checkObservations =
            [ observation "documentation-output-envelope" "refused-before-render"
            , observation "documentation-output-finding-limit" (showText documentationOutputFindingLimit)
            , observation "documentation-output-observation-limit" (showText documentationOutputObservationLimit)
            , observation "documentation-output-field-character-limit" (showText documentationOutputFieldCharacterLimit)
            , observation "documentation-output-total-character-limit" (showText documentationOutputTotalCharacterLimit)
            ]
        , checkFindings =
            [ finding
                "DOC-OUTPUT-LIMIT"
                "documentation-result"
                problem
            ]
              <> take documentationOutputMandatoryFindingLimit
                (filter mandatoryDocumentationFinding (checkFindings result))
        }

-- Refusal-only facades add their permanent authority marker before applying
-- the final carrier bound. Otherwise an exact-boundary inner result could be
-- enlarged by the wrapper after the envelope had already been checked.
prependRequiredFindingsAndBound :: [Finding] -> CheckResult -> CheckResult
#ifdef VALIDATION_DOCUMENT_REQUIRED_FINDINGS_AFTER_BOUND_MUTANT
prependRequiredFindingsAndBound required result =
  let bounded = boundDocumentationResult result
   in bounded {checkFindings = required <> checkFindings bounded}
#else
prependRequiredFindingsAndBound required result =
  boundDocumentationResult
    result
      { checkFindings = required <> checkFindings result
      }
#endif

mandatoryDocumentationFinding :: Finding -> Bool
mandatoryDocumentationFinding item =
  or
    [ retainCorpusDiagnosticFinding item
    , retainInventoryDiagnosticFinding item
    , retainStructureDiagnosticFinding item
    , retainDiscoveryFinding item
    ]

retainCorpusDiagnosticFinding :: Finding -> Bool
#ifdef VALIDATION_DOCUMENT_OUTPUT_CORPUS_REFUSAL_RETENTION_MUTANT
retainCorpusDiagnosticFinding item = findingCode item == "DOC-CORPUS-DIAGNOSTIC-ONLY" `seq` False
#else
retainCorpusDiagnosticFinding item = findingCode item == "DOC-CORPUS-DIAGNOSTIC-ONLY"
#endif

retainInventoryDiagnosticFinding :: Finding -> Bool
#ifdef VALIDATION_DOCUMENT_OUTPUT_INVENTORY_REFUSAL_RETENTION_MUTANT
retainInventoryDiagnosticFinding item = findingCode item == "DOC-INVENTORY-DIAGNOSTIC-ONLY" `seq` False
#else
retainInventoryDiagnosticFinding item = findingCode item == "DOC-INVENTORY-DIAGNOSTIC-ONLY"
#endif

retainStructureDiagnosticFinding :: Finding -> Bool
#ifdef VALIDATION_DOCUMENT_OUTPUT_STRUCTURE_REFUSAL_RETENTION_MUTANT
retainStructureDiagnosticFinding item = findingCode item == "DOC-STRUCTURE-DIAGNOSTIC-ONLY" `seq` False
#else
retainStructureDiagnosticFinding item = findingCode item == "DOC-STRUCTURE-DIAGNOSTIC-ONLY"
#endif

retainDiscoveryFinding :: Finding -> Bool
#ifdef VALIDATION_DOCUMENT_OUTPUT_DISCOVERY_REFUSAL_RETENTION_MUTANT
retainDiscoveryFinding item = "DOC-DISCOVERY-" `Text.isPrefixOf` findingCode item `seq` False
#else
retainDiscoveryFinding item = "DOC-DISCOVERY-" `Text.isPrefixOf` findingCode item
#endif

documentationOutputEnvelopeProblem :: CheckResult -> Maybe Text
documentationOutputEnvelopeProblem result
  | documentationOutputFindingsExceeded (checkFindings result) =
      Just ("finding count exceeds " <> showText documentationOutputFindingLimit)
  | documentationOutputObservationsExceeded (checkObservations result) =
      Just ("observation count exceeds " <> showText documentationOutputObservationLimit)
  | any documentationOutputFieldExceeded fields =
      Just ("one result field exceeds " <> showText documentationOutputFieldCharacterLimit <> " characters")
  | documentationOutputTotalExceeded fields =
      Just ("result fields exceed " <> showText documentationOutputTotalCharacterLimit <> " characters in aggregate")
  | otherwise = Nothing
 where
  fields =
    checkName result
      : concatMap observationFields (checkObservations result)
        <> concatMap findingFields (checkFindings result)
  observationFields item = [observationKey item, observationValue item]
  findingFields item = [findingCode item, Text.pack (findingSubject item), findingDetail item]

documentationOutputFindingsExceeded :: [Finding] -> Bool
#ifdef VALIDATION_DOCUMENT_OUTPUT_FINDING_LIMIT_BYPASS_MUTANT
documentationOutputFindingsExceeded _ = False
#else
documentationOutputFindingsExceeded = hasMoreThan documentationOutputFindingLimit
#endif

documentationOutputObservationsExceeded :: [Observation] -> Bool
#ifdef VALIDATION_DOCUMENT_OUTPUT_OBSERVATION_LIMIT_BYPASS_MUTANT
documentationOutputObservationsExceeded _ = False
#else
documentationOutputObservationsExceeded = hasMoreThan documentationOutputObservationLimit
#endif

documentationOutputFieldExceeded :: Text -> Bool
#ifdef VALIDATION_DOCUMENT_OUTPUT_FIELD_LIMIT_BYPASS_MUTANT
documentationOutputFieldExceeded _ = False
#else
documentationOutputFieldExceeded field = Text.length field > documentationOutputFieldCharacterLimit
#endif

documentationOutputTotalExceeded :: [Text] -> Bool
#ifdef VALIDATION_DOCUMENT_OUTPUT_TOTAL_LIMIT_BYPASS_MUTANT
documentationOutputTotalExceeded _ = False
#else
documentationOutputTotalExceeded = go 0
 where
  go _ [] = False
  go accumulated (field : rest)
    | Text.length field > documentationOutputTotalCharacterLimit - accumulated = True
    | otherwise = go (accumulated + Text.length field) rest
#endif

documentationOutputFindingLimit :: Int
documentationOutputFindingLimit = 4096

documentationOutputObservationLimit :: Int
documentationOutputObservationLimit = 4096

documentationOutputFieldCharacterLimit :: Int
documentationOutputFieldCharacterLimit = 8192

documentationOutputTotalCharacterLimit :: Int
documentationOutputTotalCharacterLimit = 2097152

documentationOutputMandatoryFindingLimit :: Int
#ifdef VALIDATION_DOCUMENT_OUTPUT_MANDATORY_FINDING_LIMIT_BYPASS_MUTANT
documentationOutputMandatoryFindingLimit = 65
#else
documentationOutputMandatoryFindingLimit = 64
#endif

retiredArtifactCorpusFindings :: [Document] -> [Finding]
#ifdef VALIDATION_DOCUMENT_RETIRED_ARTIFACT_MUTANT
retiredArtifactCorpusFindings documents =
  length (concatMap checkRetiredTrackedArtifactSyntax documents) `seq` []
#else
retiredArtifactCorpusFindings = concatMap checkRetiredTrackedArtifactSyntax
#endif

-- | Reject the old repository-path spelling that made serialized fixtures,
-- goldens, or materialized mutants look like tracked test inputs.  This is a
-- syntax check only: it does not infer a source role or validation meaning
-- from prose.  A authored Haskell test path remains admissible; generated
-- transports must instead name their lazy generated-tree destination.
checkRetiredTrackedArtifactSyntax :: Document -> [Finding]
checkRetiredTrackedArtifactSyntax document =
  pathFindings <> wrappedPathFindings <> phraseFindings
 where
  rawLines = zip [(1 :: Int) ..] (Text.lines (documentText document))
  pathOffendersByLine =
    Map.fromListWith
      Set.union
      [ (lineNumber, Set.fromList offenders)
      | linesToScan <- retiredLineProjections rawLines (commentElidedLines (documentText document))
      , (lineNumber, line) <- linesToScan
      , let offenders = retiredTrackedArtifactPathTokens line
      , not (null offenders)
      ]
  pathFindings =
    [ finding
        "DOC-RETIRED-TRACKED-ARTIFACT"
        (documentPath document)
        ( "line "
            <> showText lineNumber
            <> " uses a retired tracked-artifact path: "
            <> Text.intercalate ", " (Set.toAscList offenders)
        )
    | (lineNumber, offenders) <- Map.toAscList pathOffendersByLine
    ]
  linePathOffenders = Set.unions (Map.elems pathOffendersByLine)
  wrappedPathOffenders =
    Set.fromList
      ( concatMap
          retiredTrackedArtifactPathTokens
          ( retiredWrappedPathProjections
              (joinPhysicalLines (documentText document))
              (joinPhysicalLines (commentElidedText (documentText document)))
          )
      )
      Set.\\ linePathOffenders
  wrappedPathFindings =
    [ finding
        "DOC-RETIRED-TRACKED-ARTIFACT"
        (documentPath document)
        ( "physical line wrapping or a multiline HTML comment conceals a retired tracked-artifact path: "
            <> Text.intercalate ", " (Set.toAscList wrappedPathOffenders)
        )
    | not (Set.null wrappedPathOffenders)
    ]
  -- Scan both the literal bytes and a comment-elided projection. Literal
  -- scanning prevents a fence or comment from hiding a violation; comment
  -- elision prevents comments from splitting or padding a prohibited phrase.
  phraseOffenders =
    Set.toAscList
      ( Set.fromList
          ( concatMap
              retiredCommitPhrases
              ( retiredPhraseProjections
                  (documentText document)
                  (commentElidedText (documentText document))
              )
          )
      )
  phraseFindings =
    [ finding
        "DOC-RETIRED-TRACKED-ARTIFACT"
        (documentPath document)
        ( "document uses retired tracked-artifact wording: "
            <> Text.intercalate ", " phraseOffenders
        )
    | not (null phraseOffenders)
    ]

retiredLineProjections
  :: [(Int, Text)]
  -> [(Int, Text)]
  -> [[(Int, Text)]]
retiredLineProjections raw commentElided =
  concat
    [
#ifdef VALIDATION_DOCUMENT_RETIRED_RAW_LINE_ROUTE_OMISSION_MUTANT
      length raw `seq` []
#else
      [raw]
#endif
    ,
#ifdef VALIDATION_DOCUMENT_RETIRED_COMMENT_LINE_ROUTE_OMISSION_MUTANT
      length commentElided `seq` []
#else
      [commentElided]
#endif
    ]

retiredWrappedPathProjections :: Text -> Text -> [Text]
retiredWrappedPathProjections raw commentElided =
  concat
    [
#ifdef VALIDATION_DOCUMENT_RETIRED_WRAPPED_RAW_ROUTE_OMISSION_MUTANT
      Text.length raw `seq` []
#else
      [raw]
#endif
    ,
#ifdef VALIDATION_DOCUMENT_RETIRED_WRAPPED_COMMENT_ROUTE_OMISSION_MUTANT
      Text.length commentElided `seq` []
#else
      [commentElided]
#endif
    ]

retiredPhraseProjections :: Text -> Text -> [Text]
retiredPhraseProjections raw commentElided =
  concat
    [
#ifdef VALIDATION_DOCUMENT_RETIRED_PHRASE_RAW_ROUTE_OMISSION_MUTANT
      Text.length raw `seq` []
#else
      [raw]
#endif
    ,
#ifdef VALIDATION_DOCUMENT_RETIRED_PHRASE_COMMENT_ROUTE_OMISSION_MUTANT
      Text.length commentElided `seq` []
#else
      [commentElided]
#endif
    ]

retiredTrackedArtifactPathTokens :: Text -> [Text]
retiredTrackedArtifactPathTokens line =
  Set.toAscList
    ( Set.fromList
        (concatMap (`pathOccurrences` line) retiredTrackedArtifactRoots)
    )

-- These are obsolete repository-source locations, not forbidden words.  An
-- exact @.hs@ path is allowed because it is Haskell source; a directory,
-- wildcard, serialized file, script, or foreign-language path is refused.
retiredTrackedArtifactRoots :: [Text]
retiredTrackedArtifactRoots =
  concat
    [
#ifdef VALIDATION_DOCUMENT_RETIRED_FIXTURE_ROOT_OMISSION_MUTANT
      []
#else
      ["test/fixture/"]
#endif
    ,
#ifdef VALIDATION_DOCUMENT_RETIRED_FIXTURES_ROOT_OMISSION_MUTANT
      []
#else
      ["test/fixtures/"]
#endif
    ,
#ifdef VALIDATION_DOCUMENT_RETIRED_GOLDEN_ROOT_OMISSION_MUTANT
      []
#else
      ["test/golden/"]
#endif
    ,
#ifdef VALIDATION_DOCUMENT_RETIRED_GOLDENS_ROOT_OMISSION_MUTANT
      []
#else
      ["test/goldens/"]
#endif
    ,
#ifdef VALIDATION_DOCUMENT_RETIRED_MUTANT_ROOT_OMISSION_MUTANT
      []
#else
      ["test/mutant/"]
#endif
    ,
#ifdef VALIDATION_DOCUMENT_RETIRED_MUTANTS_ROOT_OMISSION_MUTANT
      []
#else
      ["test/mutants/"]
#endif
    ,
#ifdef VALIDATION_DOCUMENT_RETIRED_NEGATIVE_ROOT_OMISSION_MUTANT
      []
#else
      ["test/negative/"]
#endif
    ,
#ifdef VALIDATION_DOCUMENT_RETIRED_ORACLE_ROOT_OMISSION_MUTANT
      []
#else
      ["test/oracle/"]
#endif
    ,
#ifdef VALIDATION_DOCUMENT_RETIRED_ORACLES_ROOT_OMISSION_MUTANT
      []
#else
      ["test/oracles/"]
#endif
    ]

pathOccurrences :: Text -> Text -> [Text]
pathOccurrences root source =
  [ occurrence
  | token <- Text.split (not . retiredPathCharacter) source
  , occurrence <- occurrencesFromRoot root token
  , not (isExactHaskellPath root occurrence)
  ]
 where
  retiredPathCharacter character =
    isAlphaNum character
      || character `elem` ['/', '.', '_', '-', '*', '?', '{', '}', '~', '$']

-- Return each token suffix beginning at the retired root.  Matching the root
-- case-insensitively closes spelling-only bypasses while retaining the exact
-- original bytes for the lower-case @.hs@ and wildcard checks below.
occurrencesFromRoot :: Text -> Text -> [Text]
occurrencesFromRoot root = go
 where
  go token =
    let (matchingRoot, matchingToken) = retiredRootMatchPair root token
        (before, matchingAndAfter) = Text.breakOn matchingRoot matchingToken
     in if Text.null matchingAndAfter
          then []
          else
            let offset = Text.length before
                occurrence = Text.drop offset token
                remaining = Text.drop (offset + Text.length root) token
             in occurrence : go remaining

retiredRootMatchPair :: Text -> Text -> (Text, Text)
#ifdef VALIDATION_DOCUMENT_RETIRED_ROOT_CASE_FOLD_OMISSION_MUTANT
retiredRootMatchPair root token = (root, token)
#else
retiredRootMatchPair root token = (Text.map toLower root, Text.map toLower token)
#endif

-- The retired artifact-family roots admit only one concrete Haskell source
-- path.  A suffix-shaped glob, variable, home expansion, empty segment, or
-- traversal is not an exact file path even when its final bytes are @.hs@.
isExactHaskellPath :: Text -> Text -> Bool
isExactHaskellPath root occurrence =
  Text.all exactPathCharacter relative
    && all validSegment segments
    && validHaskellBasename (last segments)
 where
  relative = Text.drop (Text.length root) occurrence
  segments = Text.splitOn "/" relative
  exactPathCharacter character = exactPathAlphaNumeric character || character `elem` exactPathPunctuation
  validSegment segment =
    exactPathSegmentNonempty segment
      && exactPathSegmentNotCurrent segment
      && exactPathSegmentNotParent segment
  validHaskellBasename basename =
    exactHaskellSuffix basename
      && exactHaskellStemNonempty basename

exactPathAlphaNumeric :: Char -> Bool
#ifdef VALIDATION_DOCUMENT_RETIRED_EXACT_PATH_ALPHANUMERIC_OMISSION_MUTANT
exactPathAlphaNumeric character = isAlphaNum character `seq` False
#else
exactPathAlphaNumeric = isAlphaNum
#endif

exactPathPunctuation :: [Char]
exactPathPunctuation =
  concat
    [
#ifdef VALIDATION_DOCUMENT_RETIRED_EXACT_PATH_SLASH_OMISSION_MUTANT
      []
#else
      ['/']
#endif
    ,
#ifdef VALIDATION_DOCUMENT_RETIRED_EXACT_PATH_DOT_OMISSION_MUTANT
      []
#else
      ['.']
#endif
    ,
#ifdef VALIDATION_DOCUMENT_RETIRED_EXACT_PATH_UNDERSCORE_OMISSION_MUTANT
      []
#else
      ['_']
#endif
    ,
#ifdef VALIDATION_DOCUMENT_RETIRED_EXACT_PATH_HYPHEN_OMISSION_MUTANT
      []
#else
      ['-']
#endif
    ]

exactPathSegmentNonempty :: Text -> Bool
#ifdef VALIDATION_DOCUMENT_RETIRED_EXACT_PATH_EMPTY_SEGMENT_BYPASS_MUTANT
exactPathSegmentNonempty segment = Text.null segment `seq` True
#else
exactPathSegmentNonempty = not . Text.null
#endif

exactPathSegmentNotCurrent :: Text -> Bool
#ifdef VALIDATION_DOCUMENT_RETIRED_EXACT_PATH_CURRENT_SEGMENT_BYPASS_MUTANT
exactPathSegmentNotCurrent segment = segment == "." `seq` True
#else
exactPathSegmentNotCurrent segment = segment /= "."
#endif

exactPathSegmentNotParent :: Text -> Bool
#ifdef VALIDATION_DOCUMENT_RETIRED_EXACT_PATH_PARENT_SEGMENT_BYPASS_MUTANT
exactPathSegmentNotParent segment = segment == ".." `seq` True
#else
exactPathSegmentNotParent segment = segment /= ".."
#endif

exactHaskellSuffix :: Text -> Bool
#ifdef VALIDATION_DOCUMENT_RETIRED_EXACT_PATH_SUFFIX_BYPASS_MUTANT
exactHaskellSuffix basename = ".hs" `Text.isSuffixOf` basename `seq` True
#else
exactHaskellSuffix = Text.isSuffixOf ".hs"
#endif

exactHaskellStemNonempty :: Text -> Bool
#ifdef VALIDATION_DOCUMENT_RETIRED_EXACT_PATH_EMPTY_STEM_BYPASS_MUTANT
exactHaskellStemNonempty basename = Text.null (Text.dropEnd 3 basename) `seq` True
#else
exactHaskellStemNonempty = not . Text.null . Text.dropEnd 3
#endif

joinPhysicalLines :: Text -> Text
joinPhysicalLines = Text.concat . map Text.strip . Text.lines

-- These phrases asserted a version-controlled transport without necessarily
-- naming a path.  State-machine uses such as "transaction committed" do not
-- match.  The corpus should name authored Haskell mutation/oracle source and
-- its separately generated transport instead.
retiredCommitPhrases :: Text -> [Text]
retiredCommitPhrases source = concatMap scanClause (retiredPhraseClauses (Text.toCaseFold source))
 where
  scanClause clause =
    [ prefix <> " … " <> artifact
    | prefix <- retiredCommitPrefixes wordsInClause
    , artifact <- retiredCommitArtifactWords
    , artifact `elem` wordsInClause
    ]
   where
    wordsInClause = normalizedWords clause

retiredCommitPrefixes :: [Text] -> [Text]
retiredCommitPrefixes wordsInClause =
  concat
    [
#ifdef VALIDATION_DOCUMENT_RETIRED_COMMITTED_PREFIX_OMISSION_MUTANT
      "committed" `elem` wordsInClause `seq` []
#else
      ["committed" | "committed" `elem` wordsInClause]
#endif
    ,
#ifdef VALIDATION_DOCUMENT_RETIRED_CHECKED_IN_PREFIX_OMISSION_MUTANT
      anyAdjacent "checked" "in" wordsInClause `seq` []
#else
      ["checked-in" | anyAdjacent "checked" "in" wordsInClause]
#endif
    ]

retiredCommitArtifactWords :: [Text]
retiredCommitArtifactWords =
  concat
    [
#ifdef VALIDATION_DOCUMENT_RETIRED_MUTANT_WORD_OMISSION_MUTANT
      []
#else
      ["mutant"]
#endif
    ,
#ifdef VALIDATION_DOCUMENT_RETIRED_MUTANTS_WORD_OMISSION_MUTANT
      []
#else
      ["mutants"]
#endif
    ,
#ifdef VALIDATION_DOCUMENT_RETIRED_ORACLE_WORD_OMISSION_MUTANT
      []
#else
      ["oracle"]
#endif
    ,
#ifdef VALIDATION_DOCUMENT_RETIRED_ORACLES_WORD_OMISSION_MUTANT
      []
#else
      ["oracles"]
#endif
    ,
#ifdef VALIDATION_DOCUMENT_RETIRED_GOLDEN_WORD_OMISSION_MUTANT
      []
#else
      ["golden"]
#endif
    ,
#ifdef VALIDATION_DOCUMENT_RETIRED_GOLDENS_WORD_OMISSION_MUTANT
      []
#else
      ["goldens"]
#endif
    ,
#ifdef VALIDATION_DOCUMENT_RETIRED_FIXTURE_WORD_OMISSION_MUTANT
      []
#else
      ["fixture"]
#endif
    ,
#ifdef VALIDATION_DOCUMENT_RETIRED_FIXTURES_WORD_OMISSION_MUTANT
      []
#else
      ["fixtures"]
#endif
    ]

anyAdjacent :: Text -> Text -> [Text] -> Bool
anyAdjacent first second wordsInClause =
  any (== [first, second]) (windowsOfTwo wordsInClause)

windowsOfTwo :: [value] -> [[value]]
windowsOfTwo (first : second : rest) = [first, second] : windowsOfTwo (second : rest)
windowsOfTwo _ = []

retiredPhraseClauses :: Text -> [Text]
retiredPhraseClauses = Text.split retiredPhraseDelimiter

retiredPhraseDelimiter :: Char -> Bool
retiredPhraseDelimiter character =
  or
    [
#ifdef VALIDATION_DOCUMENT_RETIRED_PERIOD_CLAUSE_BOUNDARY_OMISSION_MUTANT
      character == '.' `seq` False
#else
      character == '.'
#endif
    ,
#ifdef VALIDATION_DOCUMENT_RETIRED_EXCLAMATION_CLAUSE_BOUNDARY_OMISSION_MUTANT
      character == '!' `seq` False
#else
      character == '!'
#endif
    ,
#ifdef VALIDATION_DOCUMENT_RETIRED_QUESTION_CLAUSE_BOUNDARY_OMISSION_MUTANT
      character == '?' `seq` False
#else
      character == '?'
#endif
    ,
#ifdef VALIDATION_DOCUMENT_RETIRED_SEMICOLON_CLAUSE_BOUNDARY_OMISSION_MUTANT
      character == ';' `seq` False
#else
      character == ';'
#endif
    ]

commentElidedText :: Text -> Text
commentElidedText = Text.unlines . map snd . commentElidedLines

commentElidedLines :: Text -> [(Int, Text)]
commentElidedLines contents = reverse rendered
 where
  (_, rendered) = foldl' step (False, []) (zip [1 ..] (Text.lines contents))
  step (inComment, kept) (lineNumber, line) =
    let (withoutComment, nextComment) = stripHtmlCommentsFromLine inComment line
     in (nextComment, (lineNumber, withoutComment) : kept)

normalizedWords :: Text -> [Text]
normalizedWords = Text.words . Text.map normalize
 where
  normalize character
    | isAlphaNum character = character
    | otherwise = ' '

-- | Structural owner-map seam. It verifies only exact paths, anchors, and
-- headings. The documentation gate, never this parser, checks semantic prose correspondence.
checkPolicyOwnerReferences :: [(FilePath, Text)] -> CheckResult
checkPolicyOwnerReferences =
  checkPolicyOwnerReferencesFor canonicalRawPolicyOwners

-- | Publicly callable owner-heading diagnostic. The closed owner contract is
-- production-owned; callers supply only Markdown bytes and always receive the
-- permanent refusal below in addition to any structural findings.
checkPolicyOwnerDiagnostic :: [(FilePath, Text)] -> CheckResult
checkPolicyOwnerDiagnostic supplied =
  case documentationInputEnvelopeFindings supplied of
    [] ->
      prependRequiredFindingsAndBound
        documentationPolicyOwnerDiagnosticRefusal
        (checkPolicyOwnerReferences supplied)
    envelopeFindings ->
      prependRequiredFindingsAndBound
        documentationPolicyOwnerDiagnosticRefusal
        CheckResult
          { checkName = "policy-owner-structure"
          , checkObservations = [observation "documentation-input-envelope" "refused-before-parse"]
          , checkFindings = envelopeFindings
          }

documentationPolicyOwnerDiagnosticRefusal :: [Finding]
#ifdef VALIDATION_DOCUMENT_POLICY_OWNER_DIAGNOSTIC_BYPASS_MUTANT
documentationPolicyOwnerDiagnosticRefusal = []
#else
documentationPolicyOwnerDiagnosticRefusal =
  [ finding
      "DOC-POLICY-OWNER-DIAGNOSTIC-ONLY"
      "Amoebius.Validation.Documentation.documentationPolicyOwnerDiagnostic"
      "caller-supplied owner documents have no exact source binding, gate-evidence, qualification, observer, or gate-pass result"
  ]
#endif

-- | Explicit standard-value seam for an independently stated structural
-- oracle.  Each tuple is owner identity, path, anchor, and exact heading.
-- Production callers use 'checkPolicyOwnerReferences'; supplying owner rows
-- here cannot change the canonical corpus check or expose the policy model.
checkPolicyOwnerReferencesFor
  :: [(Text, FilePath, Text, Text)]
  -> [(FilePath, Text)]
  -> CheckResult
checkPolicyOwnerReferencesFor owners supplied =
  CheckResult
    { checkName = "policy-owner-structure"
    , checkObservations = [observation "policy.owner-document-count" (showText (Map.size documents))]
    , checkFindings = policyOwnerFindings owners documents
    }
 where
  documents =
    Map.fromList
      [ (normalized, makeDocumentFor normalized contents)
      | (path, contents) <- supplied
      , let normalized = normalizePath path
      ]

canonicalRawPolicyOwners :: [(Text, FilePath, Text, Text)]
canonicalRawPolicyOwners =
  [ (showText identifier, Policy.policyOwnerPath reference, Policy.policyOwnerAnchor reference, Policy.policyOwnerSection reference)
  | identifier <- ([minBound .. maxBound] :: [Policy.PolicyId])
  , Just reference <- [Policy.policyOwnerReference Policy.canonicalPolicyContract identifier]
  ]

policyOwnerFindings :: [(Text, FilePath, Text, Text)] -> Map FilePath Document -> [Finding]
policyOwnerFindings owners documents = concatMap checkOwner owners
 where
  checkOwner (identifier, path, anchor, section) =
    case Map.lookup (normalizePath path) documents of
      Nothing ->
        [ finding
            "DOC-POLICY-OWNER-PATH"
            path
            ("the owner document for " <> identifier <> " is absent")
        ]
      Just document ->
        [ finding
            "DOC-POLICY-OWNER-ANCHOR"
            path
            ( "the owner for "
                <> identifier
                <> " must be exact heading '"
                <> section
                <> "' at #"
                <> anchor
            )
        | (anchor, section) `notElem` headingAnchorPairs (documentVisibleLines document)
        ]

-- | The floor beneath which the governed corpus cannot have been discovered
-- correctly.
--
-- This was an exact count of the live corpus, which made every ordinary
-- documentation change redden the documentation-suite gate — and, because
-- @Dispatch.checkAcquiredPhaseChain@ re-derives gate 0 inside every later
-- phase's gate, reopened a closed Phase 0 for work it does not own.  An exact
-- count is also a committed enumeration, which
-- @testing_doctrine.md §9@ forecloses: a surface must not be removable from the
-- required set by editing a checked-in list.
--
-- A floor keeps the property the count was actually there to protect —
-- discovery silently collapsing — while tolerating a corpus that grows.
minimumGovernedPathCount :: Int
#ifdef VALIDATION_DOCUMENT_INVENTORY_BASELINE_MUTANT
minimumGovernedPathCount = 0
#else
minimumGovernedPathCount = 150
#endif

hex :: ByteString.ByteString -> Text
hex = Text.pack . concatMap byteHex . ByteString.unpack
 where
  byteHex value =
    [ intToDigit (fromIntegral value `div` 16)
    , intToDigit (fromIntegral value `mod` 16)
    ]

makeDocument :: Text -> FilePath -> Document
makeDocument contents path =
  Document
    { documentPath = path
    , documentText = contents
    , documentVisibleLines = visible
    , documentMarkdownBlocks = markdownBlocks visible
    , documentAnchors = anchorsFor visible
    , documentLinks = concatMap linksForBlock (markdownBlocks visible)
    }
 where
  visible = outsideFences contents

makeDocumentFor :: FilePath -> Text -> Document
makeDocumentFor path contents = makeDocument contents path

discoverDocuments :: FilePath -> IO ([(FilePath, Text)], [Finding], DiscoveryBudget)
discoverDocuments root = do
  budget <- newIORef (DiscoveryBudget 0 0 0)
  roots <- forM rootDocuments (readIfPresent budget root)
  documentsRoot <- walkMarkdown budget root "documents" 0
  planRoot <- walkMarkdown budget root "DEVELOPMENT_PLAN" 0
  auxiliary <- walkAuxiliaryMarkdown budget root rootDocuments
  let entries = roots <> documentsRoot <> planRoot <> auxiliary
      documents = [(path, contents) | Right (path, contents) <- entries]
      problems = [problem | Left problem <- entries]
      requiredRoots = ["README.md", "documents", "DEVELOPMENT_PLAN"]
  missing <- fmap concat . forM requiredRoots $ \relative -> do
    admitted <- pathAdmittedWithoutFollowing root relative
    pure
      [ finding "DOC-DISCOVERY-MISSING" relative "required governed documentation root is absent"
      | not admitted
      ]
  finalBudget <- readIORef budget
  pure (documents, problems <> missing, finalBudget)
 where
  rootDocuments = ["README.md", "AGENTS.md", "CLAUDE.md"]

-- Worktree diagnostics need non-governed Markdown as graph input even though
-- only the canonical roots receive header checks.  In particular, vendor
-- provenance documents can be legitimate inbound-link sources.  Generated
-- and VCS-private trees are excluded from this mutable diagnostic discovery.
walkAuxiliaryMarkdown :: IORef DiscoveryBudget -> FilePath -> [FilePath] -> IO [Either Finding (FilePath, Text)]
walkAuxiliaryMarkdown budget root canonicalRoots = do
  listed <- boundedDirectoryEntries budget "." root
  case listed of
    Left problem -> pure [Left problem]
    Right names -> fmap concat . forM names $ \name ->
      if name `elem` excluded || name `elem` canonicalRoots
        then pure []
        else do
          preflight <- discoveryPathPreflight root name
          case preflight of
            Left problem -> pure [Left problem]
            Right () -> do
              directory <- doesDirectoryExist (root </> name)
              if directory
                then walkMarkdown budget root name 0
                else
                  if takeExtension name == ".md"
                    then pure <$> readDocument budget root name
                    else pure []
 where
  excluded = [canonicalGeneratedRoot, ".git", "dist-newstyle", "documents", "DEVELOPMENT_PLAN"]

readIfPresent :: IORef DiscoveryBudget -> FilePath -> FilePath -> IO (Either Finding (FilePath, Text))
readIfPresent budget root relative = do
  preflight <- discoveryPathPreflight root relative
  case preflight of
    Left problem -> pure (Left problem)
    Right () -> do
      present <- doesFileExist (root </> relative)
      if present
        then readDocument budget root relative
        else
          pure
            ( Left
                ( finding
                    "DOC-DISCOVERY-MISSING"
                    relative
                    "expected repository-root Markdown document is absent"
                )
            )

walkMarkdown :: IORef DiscoveryBudget -> FilePath -> FilePath -> Int -> IO [Either Finding (FilePath, Text)]
walkMarkdown budget root relative depth
  | discoveryDepthExceeded depth =
      pure
        [ Left
            ( finding
                "DOC-DISCOVERY-DEPTH-LIMIT"
                relative
                ("documentation traversal depth exceeds " <> showText documentationDiscoveryDepthLimit)
            )
        ]
  | discoveryPathCharactersExceeded relative =
      pure [Left (discoveryPathLimitFinding relative)]
  | otherwise = do
      preflight <- discoveryPathPreflight root relative
      case preflight of
        Left problem -> pure [Left problem]
        Right () -> do
          present <- doesDirectoryExist (root </> relative)
          if not present
            then pure []
            else do
              listed <- boundedDirectoryEntries budget relative (root </> relative)
              case listed of
                Left problem -> pure [Left problem]
                Right names -> fmap concat . forM names $ \name -> do
                  let child = normalizePath (relative </> name)
                  if discoveryPathCharactersExceeded child
                    then pure [Left (discoveryPathLimitFinding child)]
                    else do
                      childPreflight <- discoveryPathPreflight root child
                      case childPreflight of
                        Left problem -> pure [Left problem]
                        Right () -> do
                          directory <- doesDirectoryExist (root </> child)
                          if directory
                            then walkMarkdown budget root child (depth + 1)
                            else
                              if takeExtension name == ".md"
                                then pure <$> readDocument budget root child
                                else pure []

readDocument :: IORef DiscoveryBudget -> FilePath -> FilePath -> IO (Either Finding (FilePath, Text))
readDocument budget root relative = do
  preflight <- discoveryPathPreflight root relative
  case preflight of
    Left problem -> pure (Left problem)
    Right () -> do
      regular <- doesFileExist absolute
      if not regular
        then
          pure
            ( Left
                ( finding
                    "DOC-DISCOVERY-FILE-TYPE"
                    relative
                    "Markdown discovery admits only a regular file"
                )
            )
        else do
          measured <- try (getFileSize absolute) :: IO (Either IOException Integer)
          case measured of
            Left problem -> pure (Left (discoveryReadFinding relative "cannot measure Markdown bytes" problem))
            Right byteCount
              | discoveryFileBytesExceeded byteCount ->
                  pure
                    ( Left
                        ( finding
                            "DOC-DISCOVERY-FILE-BYTE-LIMIT"
                            relative
                            ("Markdown file exceeds " <> showText documentationDiscoveryFileByteLimit <> " bytes before read")
                        )
                    )
              | otherwise -> do
                  fileReserved <- reserveDiscoveryFile budget
                  if not fileReserved
                    then
                      pure
                        ( Left
                            ( finding
                                "DOC-DISCOVERY-FILE-LIMIT"
                                "documents/"
                                ("Markdown discovery exceeds " <> showText documentationDiscoveryFileLimit <> " files")
                            )
                        )
                    else do
                      bytesReserved <- reserveDiscoveryBytes budget byteCount
                      if not bytesReserved
                        then
                          pure
                            ( Left
                                ( finding
                                    "DOC-DISCOVERY-TOTAL-BYTE-LIMIT"
                                    "documents/"
                                    ("Markdown discovery exceeds " <> showText documentationDiscoveryTotalByteLimit <> " bytes before read")
                                )
                            )
                        else do
                          result <- try (TextIO.readFile absolute) :: IO (Either IOException Text)
                          case result of
                            Left problem -> pure (Left (discoveryReadFinding relative "cannot read Markdown bytes" problem))
                            Right contents -> do
                              remeasured <- try (getFileSize absolute) :: IO (Either IOException Integer)
                              pure $ case remeasured of
                                Left problem -> Left (discoveryReadFinding relative "cannot remeasure Markdown bytes" problem)
                                Right finalByteCount
                                  | finalByteCount /= byteCount ->
                                      Left
                                        ( finding
                                            "DOC-DISCOVERY-FILE-CHANGED"
                                            relative
                                            "Markdown byte size changed between pre-read measurement and completed read"
                                        )
                                  | otherwise -> Right (normalizePath relative, contents)
 where
  absolute = root </> relative

boundedDirectoryEntries :: IORef DiscoveryBudget -> FilePath -> FilePath -> IO (Either Finding [FilePath])
boundedDirectoryEntries budget relative absolute = do
  result <- try readBounded :: IO (Either IOException (Either Finding [FilePath]))
  pure $ case result of
    Left problem -> Left (discoveryReadFinding relative "cannot enumerate documentation directory" problem)
    Right value -> value
 where
#if defined(mingw32_HOST_OS)
  readBounded = do
    names <- listDirectory absolute
    consume 0 [] (sort names)
  consume _ accepted [] = pure (Right (reverse accepted))
  consume localCount accepted (name : rest) =
    admitDirectoryEntry localCount accepted name (consume (localCount + 1) (name : accepted) rest)
#else
  readBounded = bracket (openDirStream absolute) closeDirStream (consume 0 [])
  consume localCount accepted stream = do
    name <- readDirStream stream
    if null name
      then pure (Right (sort (reverse accepted)))
      else
        if name `elem` [".", ".."]
          then consume localCount accepted stream
          else admitDirectoryEntry localCount accepted name (consume (localCount + 1) (name : accepted) stream)
#endif
  admitDirectoryEntry localCount _ _ _
    | discoveryDirectoryEntriesExceeded localCount =
        pure
          ( Left
              ( finding
                  "DOC-DISCOVERY-DIRECTORY-ENTRY-LIMIT"
                  relative
                  ("directory contains more than " <> showText documentationDiscoveryDirectoryEntryLimit <> " entries")
              )
          )
  admitDirectoryEntry _ _ _ continuation = do
    reserved <- reserveDiscoveryDirectoryEntry budget
    if reserved
      then continuation
      else
        pure
          ( Left
              ( finding
                  "DOC-DISCOVERY-TOTAL-ENTRY-LIMIT"
                  "documents/"
                  ("documentation traversal exceeds " <> showText documentationDiscoveryTotalEntryLimit <> " directory entries")
              )
          )

discoveryPathPreflight :: FilePath -> FilePath -> IO (Either Finding ())
discoveryPathPreflight root relative
  | discoveryPathCharactersExceeded relative = pure (Left (discoveryPathLimitFinding relative))
  | otherwise = do
      inspected <- try (pathIsSymbolicLink (root </> relative)) :: IO (Either IOException Bool)
      pure $ case inspected of
        Left problem -> Left (discoveryReadFinding relative "cannot inspect path without following links" problem)
        Right isLink
          | discoverySymlinkForbidden isLink ->
              Left
                ( finding
                    "DOC-DISCOVERY-SYMLINK"
                    relative
                    "documentation discovery does not follow symbolic links"
                )
          | otherwise -> Right ()

pathAdmittedWithoutFollowing :: FilePath -> FilePath -> IO Bool
pathAdmittedWithoutFollowing root relative = do
  preflight <- discoveryPathPreflight root relative
  case preflight of
    Left _ -> pure False
    Right () -> do
      filePresent <- doesFileExist (root </> relative)
      directoryPresent <- doesDirectoryExist (root </> relative)
      pure (filePresent || directoryPresent)

discoveryReadFinding :: FilePath -> Text -> IOException -> Finding
discoveryReadFinding relative context problem =
  finding
    "DOC-DISCOVERY-READ"
    relative
    (context <> ": " <> Text.pack (show problem))

discoveryPathLimitFinding :: FilePath -> Finding
discoveryPathLimitFinding relative =
  finding
    "DOC-DISCOVERY-PATH-LIMIT"
    "discovered-path"
    ( "discovered relative path exceeds "
        <> showText documentationDiscoveryPathCharacterLimit
        <> " characters; prefix="
        <> Text.pack (take 80 relative)
    )

reserveDiscoveryDirectoryEntry :: IORef DiscoveryBudget -> IO Bool
reserveDiscoveryDirectoryEntry budget =
  atomicModifyIORef' budget $ \current ->
    if discoveryTotalDirectoryEntriesExceeded (discoveryDirectoryEntries current)
      then (current, False)
      else
        ( current {discoveryDirectoryEntries = discoveryDirectoryEntries current + 1}
        , True
        )

reserveDiscoveryFile :: IORef DiscoveryBudget -> IO Bool
reserveDiscoveryFile budget =
  atomicModifyIORef' budget $ \current ->
    if discoveryFilesExceeded (discoveryMarkdownFiles current)
      then (current, False)
      else
        ( current {discoveryMarkdownFiles = discoveryMarkdownFiles current + 1}
        , True
        )

reserveDiscoveryBytes :: IORef DiscoveryBudget -> Integer -> IO Bool
reserveDiscoveryBytes budget additional =
  atomicModifyIORef' budget $ \current ->
    if discoveryTotalBytesExceeded (discoveryMarkdownBytes current) additional
      then (current, False)
      else
        ( current {discoveryMarkdownBytes = discoveryMarkdownBytes current + additional}
        , True
        )

discoveryDirectoryEntriesExceeded :: Int -> Bool
#ifdef VALIDATION_DOCUMENT_DISCOVERY_DIRECTORY_ENTRY_LIMIT_BYPASS_MUTANT
discoveryDirectoryEntriesExceeded _ = False
#else
discoveryDirectoryEntriesExceeded admitted = admitted >= documentationDiscoveryDirectoryEntryLimit
#endif

discoveryTotalDirectoryEntriesExceeded :: Int -> Bool
#ifdef VALIDATION_DOCUMENT_DISCOVERY_TOTAL_ENTRY_LIMIT_BYPASS_MUTANT
discoveryTotalDirectoryEntriesExceeded _ = False
#else
discoveryTotalDirectoryEntriesExceeded admitted = admitted >= documentationDiscoveryTotalEntryLimit
#endif

discoveryDepthExceeded :: Int -> Bool
#ifdef VALIDATION_DOCUMENT_DISCOVERY_DEPTH_LIMIT_BYPASS_MUTANT
discoveryDepthExceeded _ = False
#else
discoveryDepthExceeded depth = depth > documentationDiscoveryDepthLimit
#endif

discoveryPathCharactersExceeded :: FilePath -> Bool
#ifdef VALIDATION_DOCUMENT_DISCOVERY_PATH_LIMIT_BYPASS_MUTANT
discoveryPathCharactersExceeded _ = False
#else
discoveryPathCharactersExceeded = hasMoreThan documentationDiscoveryPathCharacterLimit
#endif

discoverySymlinkForbidden :: Bool -> Bool
#ifdef VALIDATION_DOCUMENT_DISCOVERY_SYMLINK_BYPASS_MUTANT
discoverySymlinkForbidden _ = False
#else
discoverySymlinkForbidden = id
#endif

discoveryFilesExceeded :: Int -> Bool
#ifdef VALIDATION_DOCUMENT_DISCOVERY_FILE_LIMIT_BYPASS_MUTANT
discoveryFilesExceeded _ = False
#else
discoveryFilesExceeded admitted = admitted >= documentationDiscoveryFileLimit
#endif

discoveryFileBytesExceeded :: Integer -> Bool
#ifdef VALIDATION_DOCUMENT_DISCOVERY_FILE_BYTE_LIMIT_BYPASS_MUTANT
discoveryFileBytesExceeded _ = False
#else
discoveryFileBytesExceeded byteCount = byteCount > documentationDiscoveryFileByteLimit
#endif

discoveryTotalBytesExceeded :: Integer -> Integer -> Bool
#ifdef VALIDATION_DOCUMENT_DISCOVERY_TOTAL_BYTE_LIMIT_BYPASS_MUTANT
discoveryTotalBytesExceeded _ _ = False
#else
discoveryTotalBytesExceeded admitted additional =
  additional > documentationDiscoveryTotalByteLimit - admitted
#endif

documentationDiscoveryDirectoryEntryLimit :: Int
documentationDiscoveryDirectoryEntryLimit = 1024

documentationDiscoveryTotalEntryLimit :: Int
documentationDiscoveryTotalEntryLimit = 4096

documentationDiscoveryDepthLimit :: Int
documentationDiscoveryDepthLimit = 64

documentationDiscoveryPathCharacterLimit :: Int
documentationDiscoveryPathCharacterLimit = 512

documentationDiscoveryFileLimit :: Int
documentationDiscoveryFileLimit = 256

documentationDiscoveryFileByteLimit :: Integer
documentationDiscoveryFileByteLimit = 4194304

documentationDiscoveryTotalByteLimit :: Integer
documentationDiscoveryTotalByteLimit = 16777216

isGovernedPath :: FilePath -> Bool
isGovernedPath path =
  governedReadmePath path
    || governedAgentsPath path
    || governedClaudePath path
    || governedDocumentsPath path
    || governedDevelopmentPlanPath path

governedReadmePath :: FilePath -> Bool
#ifdef VALIDATION_DOCUMENT_GOVERNED_README_OMISSION_MUTANT
governedReadmePath path = path == "README.md" `seq` False
#else
governedReadmePath path = path == "README.md"
#endif

governedAgentsPath :: FilePath -> Bool
#ifdef VALIDATION_DOCUMENT_GOVERNED_AGENTS_OMISSION_MUTANT
governedAgentsPath path = path == "AGENTS.md" `seq` False
#else
governedAgentsPath path = path == "AGENTS.md"
#endif

governedClaudePath :: FilePath -> Bool
#ifdef VALIDATION_DOCUMENT_GOVERNED_CLAUDE_OMISSION_MUTANT
governedClaudePath path = path == "CLAUDE.md" `seq` False
#else
governedClaudePath path = path == "CLAUDE.md"
#endif

governedDocumentsPath :: FilePath -> Bool
#ifdef VALIDATION_DOCUMENT_GOVERNED_DOCUMENTS_OMISSION_MUTANT
governedDocumentsPath path = pathPrefixOf "documents" path `seq` False
#else
governedDocumentsPath = pathPrefixOf "documents"
#endif

governedDevelopmentPlanPath :: FilePath -> Bool
#ifdef VALIDATION_DOCUMENT_GOVERNED_PLAN_OMISSION_MUTANT
governedDevelopmentPlanPath path = pathPrefixOf "DEVELOPMENT_PLAN" path `seq` False
#else
governedDevelopmentPlanPath = pathPrefixOf "DEVELOPMENT_PLAN"
#endif

pathPrefixOf :: FilePath -> FilePath -> Bool
pathPrefixOf prefix candidate =
  candidate == prefix || Text.pack (prefix <> "/") `Text.isPrefixOf` Text.pack candidate

normalizePath :: FilePath -> FilePath
normalizePath = dropDocumentationDotPrefix . normalise . map normalizePathSeparator

dropDocumentationDotPrefix :: FilePath -> FilePath
#ifdef VALIDATION_DOCUMENT_NORMALIZE_DOT_PREFIX_OMISSION_MUTANT
dropDocumentationDotPrefix path = path
#else
dropDocumentationDotPrefix ('.' : '/' : rest) = dropDocumentationDotPrefix rest
dropDocumentationDotPrefix path = path
#endif

normalizePathSeparator :: Char -> Char
#ifdef VALIDATION_DOCUMENT_NORMALIZE_BACKSLASH_OMISSION_MUTANT
normalizePathSeparator character = character
#else
normalizePathSeparator '\\' = '/'
normalizePathSeparator character = character
#endif

outsideFences :: Text -> [(Int, Text)]
outsideFences contents = reverse visible
 where
  (_, _, visible) = foldl' step (Nothing, False, []) (zip [1 ..] (Text.lines contents))
  step (Just fence, inComment, kept) (_, line) =
    if closesFence fence line
      then (Nothing, inComment, kept)
      else (Just fence, inComment, kept)
  step (Nothing, inComment, kept) (lineNumber, line) =
    let (rendered, nextComment) = stripHtmlCommentsFromLine inComment line
     in case opensFence rendered of
          Just marker -> (Just marker, False, kept)
          Nothing -> (Nothing, nextComment, (lineNumber, rendered) : kept)

-- HTML comments are not rendered Markdown. This stateful pass preserves line
-- numbers while preventing commented-out metadata, links, anchors, or policy
-- tokens from satisfying a structural obligation.
stripHtmlCommentsFromLine :: Bool -> Text -> (Text, Bool)
stripHtmlCommentsFromLine inComment source
  | inComment =
      let (_, closing) = Text.breakOn "-->" source
       in if Text.null closing
            then ("", True)
            else stripHtmlCommentsFromLine False (Text.drop 3 closing)
  | otherwise =
      let (before, opening) = Text.breakOn "<!--" source
       in if Text.null opening
            then (source, False)
            else
              let (after, stillOpen) = stripHtmlCommentsFromLine True (Text.drop 4 opening)
               in (before <> after, stillOpen)

opensFence :: Text -> Maybe Fence
opensFence line = do
  candidate <- fenceCandidate line
  let Fence marker _ = candidate
      tailText = Text.dropWhile (== marker) (dropFenceIndent line)
  if marker == '`' && "`" `Text.isInfixOf` tailText
    then Nothing
    else Just candidate

closesFence :: Fence -> Text -> Bool
closesFence (Fence wanted minimumWidth) line =
  case fenceCandidate line of
    Just (Fence observed width) ->
      observed == wanted
        && width >= minimumWidth
        && Text.null (Text.strip (Text.dropWhile (== observed) (dropFenceIndent line)))
    Nothing -> False

fenceCandidate :: Text -> Maybe Fence
fenceCandidate line
  | indentation > 3 = Nothing
  | otherwise = case Text.uncons candidate of
      Just (marker, _)
        | marker `elem` ['`', '~']
        , let width = Text.length (Text.takeWhile (== marker) candidate)
        , width >= 3 -> Just (Fence marker width)
      _ -> Nothing
 where
  indentation = Text.length (Text.takeWhile (== ' ') line)
  candidate = dropFenceIndent line

dropFenceIndent :: Text -> Text
dropFenceIndent = Text.dropWhile (== ' ')

-- Inline code and link labels may cross a soft line break. Parse a paragraph
-- or one list item as a unit so physical wrapping cannot fabricate an
-- unmatched backtick or orphan @](@ finding. Block boundaries remain hard:
-- an ATX heading, thematic break, table row, distinct list item, blockquote
-- transition, blank line, or removed-fence line-number gap cannot lend a
-- closing delimiter to another syntactic block.
markdownBlocks :: [(Int, Text)] -> [(Int, Text)]
markdownBlocks = go
 where
  go [] = []
  go ((lineNumber, line) : rest)
    | Text.null (Text.strip line) = go rest
    | otherwise =
        let kind = markdownBlockKind line
            (continuation, remaining) = consume kind lineNumber rest
            blockLines = line : map snd continuation
         in (lineNumber, Text.intercalate "\n" blockLines) : go remaining
  consume _ _ [] = ([], [])
  consume kind previous remaining@((lineNumber, line) : rest)
    | continuesBlock kind lineNumber line =
        let (continued, after) = consume kind lineNumber rest
         in ((lineNumber, line) : continued, after)
    | otherwise = ([], remaining)
   where
    continuesBlock AtomicBlock _ _ = False
    continuesBlock ParagraphBlock next candidate =
      next == previous + 1 && markdownBlockKind candidate == ParagraphBlock
    continuesBlock ListItemBlock next candidate =
      next == previous + 1 && markdownBlockKind candidate == ParagraphBlock
    continuesBlock BlockquoteBlock next candidate =
      next == previous + 1 && markdownBlockKind candidate == BlockquoteBlock

markdownBlockKind :: Text -> MarkdownBlockKind
markdownBlockKind line
  | atxHeading line || thematicBreak line || tableRow line = AtomicBlock
  | listItem line = ListItemBlock
  | ">" `Text.isPrefixOf` Text.stripStart line = BlockquoteBlock
  | otherwise = ParagraphBlock

sentenceTargetWords :: Int
sentenceTargetWords = 45

sentenceSevereWords :: Int
sentenceSevereWords = 90

paragraphSentenceTarget :: Int
paragraphSentenceTarget = 6

-- | Section 13 remains an advisory ratchet while the governed corpus is over
-- the target.  Reporting is nevertheless complete: every over-target sentence
-- and paragraph is named, along with aggregate counts and the maximum.  The
-- candidate therefore cannot turn the current backlog into a green claim by
-- omitting the measurement or by hard-wrapping a sentence.
proseBudgetObservations :: [Document] -> [Observation]
proseBudgetObservations documents =
  [ observation "prose-budget.sentence-target-words" (showText sentenceTargetWords)
  , observation "prose-budget.sentence-over-target-count" (showText (length overTarget))
  , observation "prose-budget.sentence-over-severe-count" (showText (length overSevere))
  , observation "prose-budget.sentence-maximum-words" (showText maximumWords)
  , observation "prose-budget.paragraph-target-sentences" (showText paragraphSentenceTarget)
  , observation "prose-budget.paragraph-over-target-count" (showText (length overParagraphs))
  ]
    <> map sentenceDetailObservation overTarget
    <> map paragraphDetailObservation overParagraphs
 where
#ifdef VALIDATION_DOCUMENT_SENTENCE_MEASUREMENT_OMISSION_MUTANT
  measurements = length (concatMap measureDocumentProse documents) `seq` []
#else
  measurements = concatMap measureDocumentProse documents
#endif
  sentences =
    [ (measurement, ordinal, count)
    | measurement <- measurements
    , (ordinal, count) <- zip [(1 :: Int) ..] (proseBudgetSentenceWords measurement)
    ]
  overTarget = filter (\(_, _, count) -> count > sentenceTargetWords) sentences
  overSevere = filter (\(_, _, count) -> count > sentenceSevereWords) sentences
  maximumWords = maximum (0 : [count | (_, _, count) <- sentences])
  overParagraphs =
    [ measurement
    | measurement <- measurements
    , length (proseBudgetSentenceWords measurement) > paragraphSentenceTarget
    ]
  sentenceDetailObservation (measurement, ordinal, count) =
    observation
      "prose-budget.sentence-over-target"
      ( Text.pack (proseBudgetPath measurement)
          <> ":"
          <> showText (proseBudgetLine measurement)
          <> ":sentence-"
          <> showText ordinal
          <> ":"
          <> showText count
      )
  paragraphDetailObservation measurement =
    observation
      "prose-budget.paragraph-over-target"
      ( Text.pack (proseBudgetPath measurement)
          <> ":"
          <> showText (proseBudgetLine measurement)
          <> ":"
          <> showText (length (proseBudgetSentenceWords measurement))
      )

measureDocumentProse :: Document -> [ProseBudgetMeasurement]
measureDocumentProse document =
  mapMaybe measure (documentMarkdownBlocks document)
 where
  measure (lineNumber, block) = do
    firstLine <- listToMaybe (Text.lines block)
    if markdownBlockKind firstLine == AtomicBlock || metadataProseBlock firstLine
      then Nothing
      else
        let counts = sentenceCountsForBlock block
         in if null counts
              then Nothing
              else
                Just
                  ProseBudgetMeasurement
                    { proseBudgetPath = documentPath document
                    , proseBudgetLine = lineNumber
                    , proseBudgetSentenceWords = counts
                    }

sentenceCountsForBlock :: Text -> [Int]
#ifdef VALIDATION_DOCUMENT_SENTENCE_LINE_SPLIT_MUTANT
sentenceCountsForBlock =
  filter (> 0)
    . concatMap (map sentenceWordCount . splitProseSentences . normalizeProseBlock)
    . Text.lines
#else
sentenceCountsForBlock =
  filter (> 0)
    . map sentenceWordCount
    . splitProseSentences
    . normalizeProseBlock
#endif

metadataProseBlock :: Text -> Bool
metadataProseBlock line =
  any
    (`Text.isPrefixOf` Text.stripStart line)
    [ "**Status**:"
    , "**Supersedes**:"
    , "**Referenced by**:"
    , "**Generated sections**:"
    , "**Substrate**:"
    , "**Register**:"
    ]

normalizeProseBlock :: Text -> Text
normalizeProseBlock =
  stripLinkDestinations
    . stripInlineCode
    . Text.unwords
    . map stripBlockPrefix
    . Text.lines
 where
  stripBlockPrefix line =
    stripListPrefix (Text.dropWhile (\character -> character == '>' || isSpace character) line)
  stripListPrefix line = case Text.uncons line of
    Just (marker, rest)
      | marker `elem` ['-', '*', '+']
      , " " `Text.isPrefixOf` rest -> Text.drop 1 rest
    _ ->
      let (digits, suffix) = Text.span (\character -> character >= '0' && character <= '9') line
       in if not (Text.null digits) && any (`Text.isPrefixOf` suffix) [". ", ") "]
            then Text.drop 2 suffix
            else line

-- Inline code is not prose and link destinations are transport syntax. Link
-- labels remain measurable prose. These small scanners intentionally avoid a
-- foreign Markdown parser or a line-oriented proxy.
stripInlineCode :: Text -> Text
stripInlineCode = Text.pack . go False . Text.unpack
 where
  go _ [] = []
  go inCode ('`' : rest) = ' ' : go (not inCode) rest
  go True (_ : rest) = go True rest
  go False (character : rest) = character : go False rest

stripLinkDestinations :: Text -> Text
stripLinkDestinations source =
  let (before, marker) = Text.breakOn "](" source
   in if Text.null marker
        then before
        else
          let afterOpen = Text.drop 2 marker
              (_, closing) = Text.breakOn ")" afterOpen
           in if Text.null closing
                then source
                else before <> "] " <> stripLinkDestinations (Text.drop 1 closing)

splitProseSentences :: Text -> [Text]
splitProseSentences = reverse . finish . foldl' step ([], "") . Text.unpack
 where
  step (sentences, current) character
    | character `elem` ['.', '!', '?'] =
        (sentences, Text.snoc current character)
    | isSpace character && terminalSentence current && not (abbreviationTail current) =
        (Text.strip current : sentences, "")
    | otherwise = (sentences, Text.snoc current character)
  finish (sentences, current)
    | Text.null (Text.strip current) = sentences
    | otherwise = Text.strip current : sentences

terminalSentence :: Text -> Bool
terminalSentence value = case Text.unsnoc (Text.stripEnd value) of
  Just (_, character) -> character `elem` ['.', '!', '?']
  Nothing -> False

abbreviationTail :: Text -> Bool
abbreviationTail value =
  normalized `elem` fixedAbbreviations || initialism normalized
 where
  token = Text.takeWhileEnd (not . isSpace) (Text.toLower (Text.stripEnd value))
  normalized = Text.dropWhile (\character -> character `elem` ['(', '[', '{']) token
  fixedAbbreviations =
    [ "e.g."
    , "i.e."
    , "etc."
    , "vs."
    , "mr."
    , "mrs."
    , "ms."
    , "dr."
    , "no."
    ]
  initialism tokenValue =
    let pieces = filter (not . Text.null) (Text.splitOn "." tokenValue)
     in Text.count "." tokenValue >= 2
          && all (\piece -> Text.length piece == 1 && Text.all isAlphaNum piece) pieces

sentenceWordCount :: Text -> Int
sentenceWordCount =
  length
    . Text.words
    . Text.map
      (\character -> if wordCharacter character then character else ' ')
 where
  wordCharacter character =
    isAlphaNum character || character `elem` ['_', '\'', '-']

atxHeading :: Text -> Bool
atxHeading line =
  indentation <= 3
    && case Text.uncons remainder of
      Just ('#', _) ->
        let (marks, afterMarks) = Text.span (== '#') remainder
         in Text.length marks <= 6 && " " `Text.isPrefixOf` afterMarks
      _ -> False
 where
  indentation = Text.length (Text.takeWhile (== ' ') line)
  remainder = Text.drop indentation line

thematicBreak :: Text -> Bool
thematicBreak line =
  any (\marker -> Text.length compact >= 3 && Text.all (== marker) compact) ['-', '*', '_']
 where
  compact = Text.filter (/= ' ') (Text.strip line)

tableRow :: Text -> Bool
tableRow line =
  let indentation = Text.length (Text.takeWhile (== ' ') line)
      stripped = Text.strip line
   in indentation == 0
        && "|" `Text.isPrefixOf` stripped
        && "|" `Text.isSuffixOf` stripped

listItem :: Text -> Bool
listItem line =
  any (`Text.isPrefixOf` stripped) ["- ", "* ", "+ "] || ordered stripped
 where
  stripped = Text.stripStart line
  ordered value =
    let (digits, suffix) = Text.span (\character -> character >= '0' && character <= '9') value
     in not (Text.null digits)
          && any (`Text.isPrefixOf` suffix) [". ", ") "]

linksForBlock :: (Int, Text) -> [LocalLink]
linksForBlock (lineNumber, block) =
  [ LocalLink lineNumber target
  | target <- markdownLineTargets (parseMarkdownLine block)
  , not (isExternal target)
  ]

parseMarkdownLine :: Text -> MarkdownLine
parseMarkdownLine source =
  MarkdownLine
    { markdownLineTargets = targets
    , markdownLineProblems = codeProblems <> referenceProblems <> htmlProblems <> anchorProblems <> linkProblems
    }
 where
  (withoutCode, codeProblems) = maskCodeSpans source
  (targets, linkProblems) = inlineTargets withoutCode
  folded = Text.toCaseFold withoutCode
  referenceProblems =
    [ "reference-style Markdown links are unsupported; use an inline destination so the local graph is closed"
    | containsUnescaped "][" withoutCode || isReferenceDefinition withoutCode
    ]
  htmlProblems =
    [ "raw-HTML local links are unsupported; use an inline Markdown destination"
    | "<a" `Text.isInfixOf` folded
        && "href" `Text.isInfixOf` folded
        && ".md" `Text.isInfixOf` folded
    ]
  (_, anchorProblems) = parseAnchorTags withoutCode

inlineTargets :: Text -> ([Text], [Text])
inlineTargets = go
 where
  go source =
    let (before, marker) = Text.breakOn "](" source
     in if Text.null marker
          then ([], [])
          else
            let afterMarker = Text.drop 2 marker
             in if escapedAtEnd before
                  then go afterMarker
                  else
                    if openBracketDepth before == 0
                      then
                        let (laterTargets, laterProblems) = go afterMarker
                         in (laterTargets, "orphan ]( is not a structurally valid Markdown link" : laterProblems)
                      else case takeBalancedDestination afterMarker of
                        Nothing -> ([], ["inline Markdown link has no balanced closing parenthesis"])
                        Just (rawTarget, rest) ->
                          let (laterTargets, laterProblems) = go rest
                           in case markdownDestination rawTarget of
                                Left problem -> (laterTargets, problem : laterProblems)
                                Right target -> (target : laterTargets, laterProblems)

markdownDestination :: Text -> Either Text Text
markdownDestination raw
  | Text.null stripped = Left "inline Markdown link has an empty destination"
  | "<" `Text.isPrefixOf` stripped =
      let (target, closing) = Text.breakOn ">" (Text.drop 1 stripped)
          trailing = Text.strip (Text.drop 1 closing)
       in if Text.null closing
            then Left "angle-bracket Markdown destination has no closing >"
            else
              if Text.null target
                then Left "angle-bracket Markdown destination is empty"
                else
                  if Text.null trailing || validLinkTitle trailing
                    then Right target
                    else Left "unexpected text follows an angle-bracket Markdown destination"
  | otherwise =
      let (target, trailing) = Text.break isSpace stripped
       in if Text.null target
            then Left "inline Markdown link has an empty destination"
            else
              if Text.null (Text.strip trailing) || validLinkTitle (Text.strip trailing)
                then Right target
                else Left "unexpected text follows a Markdown destination"
 where
  stripped = Text.strip raw

validLinkTitle :: Text -> Bool
validLinkTitle value =
  case Text.uncons value of
    Just ('\'', rest) -> closesWith '\'' rest
    Just ('"', rest) -> closesWith '"' rest
    Just ('(', rest) -> closesWith ')' rest
    _ -> False
 where
  closesWith wanted rest = case Text.unsnoc rest of
    Just (_, observed) -> observed == wanted
    Nothing -> False

takeBalancedDestination :: Text -> Maybe (Text, Text)
takeBalancedDestination = go (1 :: Int) False Nothing False [] . Text.unpack
 where
  go _ _ _ _ _ [] = Nothing
  go depth escaped quoted angle reversed (character : rest)
    | escaped = go depth False quoted angle (character : reversed) rest
    | character == '\\' = go depth True quoted angle (character : reversed) rest
    | angle = go depth False quoted (character /= '>') (character : reversed) rest
    | character == '<' = go depth False quoted True (character : reversed) rest
    | Just closing <- quoted =
        go depth False (if character == closing then Nothing else quoted) False (character : reversed) rest
    | character `elem` ['\'', '"'] && titlePrefix reversed =
        go depth False (Just character) False (character : reversed) rest
    | character == '(' = go (depth + 1) False Nothing False (character : reversed) rest
    | character == ')' =
        if depth == 1
          then Just (Text.pack (reverse reversed), Text.pack rest)
          else go (depth - 1) False Nothing False (character : reversed) rest
    | otherwise = go depth False Nothing False (character : reversed) rest
  titlePrefix reversed = case reversed of
    previous : _ -> isSpace previous
    [] -> False

openBracketDepth :: Text -> Int
openBracketDepth = go 0 False . Text.unpack
 where
  go depth _ [] = depth
  go depth True (_ : rest) = go depth False rest
  go depth False ('\\' : rest) = go depth True rest
  go depth False ('[' : rest) = go (depth + 1) False rest
  go depth False (']' : rest) = go (max 0 (depth - 1)) False rest
  go depth False (_ : rest) = go depth False rest

escapedAtEnd :: Text -> Bool
escapedAtEnd = odd . length . takeWhile (== '\\') . reverse . Text.unpack

containsUnescaped :: Text -> Text -> Bool
containsUnescaped wanted = go . Text.unpack
 where
  needle = Text.unpack wanted
  go [] = False
  go ('\\' : _ : rest) = go rest
  go source@(_ : rest) = prefixOf needle source || go rest
  prefixOf [] _ = True
  prefixOf _ [] = False
  prefixOf (left : leftRest) (right : rightRest) = left == right && prefixOf leftRest rightRest

isReferenceDefinition :: Text -> Bool
isReferenceDefinition line =
  case Text.uncons (Text.stripStart line) of
    Just ('[', rest) ->
      let (label, marker) = Text.breakOn "]:" rest
       in not (Text.null label) && not (Text.null marker)
    _ -> False

maskCodeSpans :: Text -> (Text, [Text])
maskCodeSpans source =
  let (masked, openRun) = go Nothing (Text.unpack source)
   in ( Text.pack masked
      , ["inline code span has no matching closing backtick run" | openRun /= Nothing]
      )
 where
  go open [] = ([], open)
  go Nothing sourceChars@('`' : _) =
    let (ticks, rest) = span (== '`') sourceChars
        (masked, open) = go (Just (length ticks)) rest
     in (replicate (length ticks) ' ' <> masked, open)
  go Nothing (character : rest) =
    let (masked, open) = go Nothing rest
     in (character : masked, open)
  go (Just wanted) sourceChars@('`' : _) =
    let (ticks, rest) = span (== '`') sourceChars
        nextOpen = if length ticks == wanted then Nothing else Just wanted
        (masked, open) = go nextOpen rest
     in (replicate (length ticks) ' ' <> masked, open)
  go open@(Just _) (_ : rest) =
    let (masked, finalOpen) = go open rest
     in (' ' : masked, finalOpen)

isExternal :: Text -> Bool
isExternal target =
  any (`Text.isPrefixOf` Text.toCaseFold target)
    [ "http://"
    , "https://"
    , "mailto:"
    , "app://"
    ]

anchorsFor :: [(Int, Text)] -> Set Text
anchorsFor visible = Set.fromList (map fst (headingAnchorPairs visible) <> explicitAnchors)
 where
  explicitAnchors = concatMap (anchorTags . snd) visible

headingAnchorPairs :: [(Int, Text)] -> [(Text, Text)]
headingAnchorPairs visible = pairs
 where
  (_, pairs) = foldl' addHeading (Map.empty :: Map Text Int, []) (mapMaybe headingText visible)
  addHeading (seen, anchors) heading =
    let base = githubAnchor heading
        duplicate = Map.findWithDefault 0 base seen
        anchor = if duplicate == 0 then base else base <> "-" <> showText duplicate
     in (Map.insert base (duplicate + 1) seen, anchors <> [(anchor, heading)])

headingText :: (Int, Text) -> Maybe Text
headingText (_, line) =
  let indentation = Text.length (Text.takeWhile (== ' ') line)
      stripped = Text.stripEnd (if indentation <= 3 then Text.drop indentation line else line)
      (marks, remainder) = Text.span (== '#') stripped
   in if indentation <= 3
        && not (Text.null marks)
        && Text.length marks <= 6
        && " " `Text.isPrefixOf` remainder
        then Just (stripClosingHeadingMarks (Text.strip (Text.drop 1 remainder)))
        else Nothing

stripClosingHeadingMarks :: Text -> Text
stripClosingHeadingMarks heading =
  let withoutMarks = Text.dropWhileEnd (== '#') heading
   in if Text.length withoutMarks < Text.length heading && Text.isSuffixOf " " withoutMarks
        then Text.stripEnd withoutMarks
        else heading

-- | GitHub heading slugging as fixed by documentation_standards.md section 4.
-- | These two checks deliberately carry no @#ifdef@ bypass guard yet.
--
-- The convention elsewhere in this module is a guarded retain function per
-- check, but no suite drives the @VALIDATION_DOCUMENT_*@ family: 155 guarded
-- symbols exist here and a handful are reachable, which is most of the
-- @MUTANT-UNWIRED@ gap 'Amoebius.Validation.MutationCoverage' refuses. Adding
-- two more undriven flags would raise the declared corpus while observing
-- nothing, which is exactly what
-- @development_plan_gate_integrity.md@ section M.3 now forbids: "A declared
-- locus no suite can execute is not coverage."
--
-- So the obligation is a driven document selector family, not two more flags.
-- When that family exists these two checks take guards with it.
retainDocumentationCitationFindings :: [Finding] -> [Finding]
retainDocumentationCitationFindings = id

retainDocumentationForwardDeferredFindings :: [Finding] -> [Finding]
retainDocumentationForwardDeferredFindings = id

-- | The three rulebook files whose lettered sections and @M.n@ subsections a
-- @\167@ citation may name.
rulebookDocuments :: [FilePath]
rulebookDocuments =
  [ "DEVELOPMENT_PLAN/development_plan_standards.md"
  , "DEVELOPMENT_PLAN/development_plan_phase_model.md"
  , "DEVELOPMENT_PLAN/development_plan_gate_integrity.md"
  ]

-- | One citation occurrence: the raw token and the line it sits on.
data Citation = Citation
  { citationLine :: Int
  , citationToken :: Text
  }
  deriving (Eq, Ord, Show)

-- | Citations are read from raw bytes, fences and comments included: a reader
-- follows @\167M.8@ wherever it appears, and a checker that skipped fenced text
-- would miss exactly the copies a decoy would use.
documentCitations :: Document -> [Citation]
documentCitations document =
  [ Citation lineNumber token
  | (lineNumber, lineText) <- zip [1 ..] (Text.lines (documentText document))
  , token <- citationTokens lineText
  ]

citationTokens :: Text -> [Text]
citationTokens lineText = case Text.breakOn "\167" lineText of
  (_, rest)
    | Text.null rest -> []
    | otherwise ->
        let body = Text.drop 1 rest
            taken = Text.dropWhileEnd (== '.') (Text.takeWhile (\c -> isAlphaNum c || c == '.') body)
         in [taken | not (Text.null taken)] <> citationTokens body

-- | Sections the rulebook actually defines: lettered @## X.@ headings and
-- numbered @### M.n@ subsections.
rulebookSections :: Map FilePath Document -> (Set Text, Set Text)
rulebookSections documents = (letters, numbered)
 where
  headings =
    [ Text.strip stripped
    | path <- rulebookDocuments
    , Just document <- [Map.lookup path documents]
    , lineText <- Text.lines (documentText document)
    , Just stripped <- [Text.stripPrefix "## " lineText, Text.stripPrefix "### " lineText]
    ]
  letters =
    Set.fromList
      [ Text.take 1 heading
      | heading <- headings
      , Text.length heading >= 2
      , isUpper (Text.head heading)
      , Text.index heading 1 == '.'
      ]
  numbered =
    Set.fromList
      [ Text.takeWhile (\c -> isAlphaNum c || c == '.') heading
      | heading <- headings
      , Text.length heading >= 3
      , isUpper (Text.head heading)
      , Text.index heading 1 == '.'
      , isDigit (Text.index heading 2)
      ]

-- | A citation to a rulebook section that does not exist is worse than no
-- citation: it delegates the rule to a blank, and the reader who follows it
-- finds nothing and falls back to whatever the citing sentence was trying to
-- forbid. Structural link checking cannot see these, because a citation is
-- plain text rather than a Markdown link.
checkRulebookCitations :: Map FilePath Document -> [Document] -> [Finding]
checkRulebookCitations documents governed =
  [ finding
      "DOC-RULEBOOK-SECTION-MISSING"
      (documentPath document)
      ( "line "
          <> showText (citationLine citation)
          <> " cites rulebook section \167"
          <> citationToken citation
          <> ", which no rulebook document defines"
      )
  | document <- governed
  , citation <- documentCitations document
  , unresolved (citationToken citation)
  ]
 where
  (letters, numbered) = rulebookSections documents
  unresolved token
    -- A numbered subsection such as M.8 must have its own heading.
    | Text.length token >= 3
    , isUpper (Text.head token)
    , Text.index token 1 == '.'
    , isDigit (Text.index token 2) =
        not (Set.member token numbered)
    -- A bare letter such as L must have a lettered section. S1 is a security
    -- law rather than a rulebook section, so a letter followed by a digit with
    -- no separating dot is not a citation of this kind.
    | Text.length token == 1
    , isUpper (Text.head token) =
        not (Set.member token letters)
    | otherwise = False

-- | The ordinal a phase document path carries, if it is a phase document.
phaseDocumentOrdinal :: FilePath -> Maybe Int
phaseDocumentOrdinal path = case Text.stripPrefix "DEVELOPMENT_PLAN/phase_" (Text.pack path) of
  Nothing -> Nothing
  Just rest ->
    let digits = Text.takeWhile isDigit rest
     in if Text.null digits then Nothing else Just (read (Text.unpack digits))

-- | The @Forward-deferred:@ field body of a phase document, if present.
forwardDeferredField :: Document -> Maybe (Int, Text)
forwardDeferredField document =
  listToMaybe
    [ (lineNumber, Text.strip body)
    | (lineNumber, lineText) <- zip [1 ..] (Text.lines (documentText document))
    , Just body <- [Text.stripPrefix "**Forward-deferred:** " lineText]
    ]

-- | Every phase document a @Forward-deferred:@ field names, as an exact
-- @(consumer ordinal, provider ordinal)@ pair. This is the input the capability
-- relation reconciles against, so a reach is accounted for in the document that
-- has it rather than in a checker-side allowlist.
forwardDeferredDeclarations :: [(FilePath, Text)] -> [(Int, Int)]
forwardDeferredDeclarations supplied =
  [ (consumerOrdinal, providerOrdinal)
  | (path, contents) <- supplied
  , Just consumerOrdinal <- [phaseDocumentOrdinal (normalizePath path)]
  , lineText <- Text.lines contents
  , Just body <- [Text.stripPrefix "**Forward-deferred:** " lineText]
  , providerOrdinal <- referencedPhaseOrdinals body
  ]

-- | The phase ordinals a field body links to, read from its Markdown link
-- targets rather than from its prose.
referencedPhaseOrdinals :: Text -> [Int]
referencedPhaseOrdinals body = go body
 where
  go remaining = case Text.breakOn "](phase_" remaining of
    (_, rest)
      | Text.null rest -> []
      | otherwise ->
          let after = Text.drop (Text.length "](phase_") rest
              digits = Text.takeWhile isDigit after
           in [read (Text.unpack digits) | not (Text.null digits)] <> go after

-- | The field is present exactly when a reach is declared, sits between
-- @Depends on:@ and @Gate:@, and names at least one later phase.
checkForwardDeferred :: [Document] -> [Finding]
checkForwardDeferred governed = concatMap check (filter notRulebook governed)
 where
  -- The rulebook states the field's template, so its occurrence there is the
  -- schema rather than a declaration.
  notRulebook document = documentPath document `notElem` rulebookDocuments
  check document = case (phaseDocumentOrdinal (documentPath document), forwardDeferredField document) of
    (Nothing, Just _) ->
      [ finding
          "DOC-FORWARD-DEFERRED-UNEXPECTED"
          (documentPath document)
          "only a phase document may carry a Forward-deferred field"
      ]
    (Just consumerOrdinal, Just (lineNumber, body)) ->
      placementFindings document lineNumber
        <> targetFindings document consumerOrdinal body
    _ -> []

  placementFindings document lineNumber =
    [ finding
        "DOC-FORWARD-DEFERRED-MISPLACED"
        (documentPath document)
        "the Forward-deferred field must sit between the Depends on and Gate fields"
    | not (between (fieldLine document "**Depends on:**") lineNumber (fieldLine document "**Gate:**"))
    ]

  between (Just before) here (Just after) = before < here && here < after
  between _ _ _ = False

  fieldLine document prefix =
    listToMaybe
      [ lineNumber
      | (lineNumber, lineText) <- zip [1 ..] (Text.lines (documentText document))
      , prefix `Text.isPrefixOf` lineText
      ]

  targetFindings document consumerOrdinal body =
    case referencedPhaseOrdinals body of
      [] ->
        [ finding
            "DOC-FORWARD-DEFERRED-UNOWNED"
            (documentPath document)
            "a Forward-deferred field must link the phase document that owns the reach"
        ]
      targets ->
        [ finding
            "DOC-FORWARD-DEFERRED-NOT-LATER"
            (documentPath document)
            ( "a Forward-deferred field names phase "
                <> showText target
                <> ", which is not later than this phase; an earlier dependency is not a forward reach"
            )
        | target <- targets
        , target <= consumerOrdinal
        ]


githubAnchor :: Text -> Text
githubAnchor = Text.map spaceToDash . Text.filter admitted . Text.toLower . stripHeadingMarkup . Text.strip
 where
  admitted character = isAlphaNum character || character `elem` [' ', '-', '_']
  spaceToDash ' ' = '-'
  spaceToDash character = character

stripHeadingMarkup :: Text -> Text
stripHeadingMarkup = stripHeadingLinks . Text.filter (`notElem` ['`', '*', '~'])

stripHeadingLinks :: Text -> Text
stripHeadingLinks source =
  case Text.breakOn "](" source of
    (before, marker)
      | Text.null marker -> source
      | escapedAtEnd before || openBracketDepth before == 0 ->
          before <> "](" <> stripHeadingLinks (Text.drop 2 marker)
      | otherwise ->
          case takeBalancedDestination (Text.drop 2 marker) of
            Nothing -> source
            Just (_, suffix) ->
              let labelStart = lastIndexOf '[' before
                  label = maybe before (\index -> Text.drop (index + 1) before) labelStart
                  prefix = maybe "" (\index -> Text.take index before) labelStart
               in prefix <> label <> stripHeadingLinks suffix

lastIndexOf :: Char -> Text -> Maybe Int
lastIndexOf wanted = listToMaybe . reverse . map fst . filter ((== wanted) . snd) . zip [0 ..] . Text.unpack

anchorTags :: Text -> [Text]
anchorTags = fst . parseAnchorTags

parseAnchorTags :: Text -> ([Text], [Text])
parseAnchorTags = go
 where
  go source =
    let folded = Text.toCaseFold source
        (before, marker) = Text.breakOn "<a" folded
     in if Text.null marker
          then ([], [])
          else
            let offset = Text.length before
                originalMarker = Text.drop offset source
             in case Text.uncons (Text.drop 2 originalMarker) of
                  Just (next, _) | not (isSpace next || next == '>') -> go (Text.drop 2 originalMarker)
                  _ ->
                    let (tag, closing) = Text.breakOn ">" originalMarker
                     in if Text.null closing
                          then ([], ["raw HTML anchor tag has no closing >"])
                          else
                            let remaining = Text.drop 1 closing
                                (laterAnchors, laterProblems) = go remaining
                             in case idAttribute tag of
                                  Left problem -> (laterAnchors, problem : laterProblems)
                                  Right Nothing -> (laterAnchors, laterProblems)
                                  Right (Just value)
                                    | Text.null value -> (laterAnchors, "raw HTML anchor has an empty id" : laterProblems)
                                    | otherwise -> (value : laterAnchors, laterProblems)

idAttribute :: Text -> Either Text (Maybe Text)
idAttribute tag = seek True (Text.unpack (Text.drop 2 tag))
 where
  seek _ [] = Right Nothing
  seek boundary (first : second : rest)
    | boundary
        && toLower first == 'i'
        && toLower second == 'd'
        && case rest of
          [] -> True
          next : _ -> isSpace next || next == '=' = parseValue rest
  seek _ (character : rest) = seek (isSpace character) rest
  parseValue afterName =
    case dropWhile isSpace afterName of
      '=' : afterEquals ->
        case dropWhile isSpace afterEquals of
          quote : value
            | quote `elem` ['\'', '"'] ->
                let (attributeValue, closing) = break (== quote) value
                 in if null closing
                      then Left "raw HTML anchor id has no closing quote"
                      else Right (Just (Text.pack attributeValue))
          _ -> Left "raw HTML anchor id must use a quoted value"
      _ -> Left "raw HTML anchor id must be followed by ="

checkMarkdownSyntax :: Document -> [Finding]
checkMarkdownSyntax document =
  [ finding
      "DOC-MARKDOWN-SYNTAX"
      (documentPath document)
      ("line " <> showText lineNumber <> ": " <> problem)
  | (lineNumber, block) <- documentMarkdownBlocks document
  , problem <- markdownLineProblems (parseMarkdownLine block)
  ]

checkHeader :: Document -> [Finding]
checkHeader document =
  documentationHeaderFindingBlocks
    (documentationHeaderTitleBlock titleFindings)
    (documentationHeaderPurposeBlock purposeFindings)
    (documentationHeaderReadThisBlock readThisFindings)
    (documentationHeaderDetailsBlock detailsFindings)
    (documentationHeaderFieldBlock fieldFindings)
 where
  path = documentPath document
  visible = documentVisibleLines document
  headerVisible = filter ((<= documentationHeaderVisibleLimit) . fst) visible
  orientationVisible = documentationHeaderOrientationLines headerVisible
  metadataLines = headerMetadataLines document
  nonBlank = [(lineNumber, line) | (lineNumber, line) <- visible, documentationHeaderNonBlank line]
  titleOccurrences =
    [ (lineNumber, line)
    | (lineNumber, line) <- nonBlank
    , documentationHeaderTitlePrefix `Text.isPrefixOf` line
    ]
  titleFindings =
    [documentationHeaderTitleFinding path | not titleOkay]
  titleOkay =
    documentationHeaderTitleCardinality titleOccurrences
      && documentationHeaderTitleFirstNonBlank nonBlank titleOccurrences
  purposeOccurrences = prefixedLines documentationHeaderPurposePrefix orientationVisible
  readThisOccurrences = prefixedLines documentationHeaderReadThisPrefix orientationVisible
  purposeFindings =
    [documentationHeaderPurposeFinding path | not (documentationHeaderPurposeOkay purposeOccurrences)]
  readThisFindings =
    [documentationHeaderReadThisFinding path | not (documentationHeaderReadThisOkay readThisOccurrences)]
  detailsLines = exactLines documentationHeaderDetailsTag headerVisible
  summaryLines = exactLines documentationHeaderSummaryTag headerVisible
  closeLines = exactLines documentationHeaderCloseTag headerVisible
  detailsFindings =
    documentationHeaderDetailsFindingOrder
      [ documentationHeaderDetailsFinding path
      | not
          ( documentationHeaderDetailsCardinality detailsLines
              && documentationHeaderDetailsLimit detailsLines
              && documentationHeaderSummaryCardinality summaryLines
              && documentationHeaderSummaryLimit summaryLines
              && documentationHeaderCloseCardinality closeLines
              && documentationHeaderCloseLimit closeLines
          )
      ]
      [ documentationHeaderOrderFinding path
      | not orientationOkay
      ]
      [ documentationHeaderMetadataBlockFinding path
      | not metadataBlockOkay
      ]
  orientationOkay = case (titleOccurrences, purposeOccurrences, readThisOccurrences, detailsLines, summaryLines) of
    ([(titleLine, _)], [(purposeLine, _)], [(readLine, _)], [detailsLine], [summaryLine]) ->
      documentationHeaderTitlePurposeOrder titleLine purposeLine
        && documentationHeaderPurposeReadThisOrder purposeLine readLine
        && documentationHeaderReadThisDetailsOrder readLine detailsLine
        && documentationHeaderDetailsSummaryOrder detailsLine summaryLine
        && documentationHeaderLeadExists readLine detailsLine visible
    _ -> False
  metadataBlockOkay =
    case
        ( summaryLines
        , fieldLines "Status" metadataLines
        , fieldLines "Supersedes" metadataLines
        , fieldLines "Referenced by" metadataLines
        , fieldLines "Generated sections" metadataLines
        , closeLines
        ) of
      ( [summaryLine]
        , [(statusLine, _)]
        , [(supersedesLine, _)]
        , [(referencedByLine, _)]
        , [(generatedLine, _)]
        , [closeLine]
        ) ->
          documentationHeaderMetadataSummaryStatusOrder summaryLine statusLine
            && documentationHeaderMetadataStatusSupersedesOrder statusLine supersedesLine
            && documentationHeaderMetadataSupersedesReferencedOrder supersedesLine referencedByLine
            && documentationHeaderMetadataReferencedGeneratedOrder referencedByLine generatedLine
            && documentationHeaderMetadataGeneratedCloseOrder generatedLine closeLine
            && documentationHeaderMetadataCloseLimit closeLine
      _ -> False
  metadata = metadataFor document
  fieldFindings =
    documentationHeaderFieldFindingOrder
      (fieldCardinalityFindings document)
      (enumFinding path "Status" metadataStatus documentationStatusValues metadata)
      (requiredValueFinding path "Supersedes" metadataSupersedes metadata)
      (requiredValueFinding path "Referenced by" metadataReferencedBy metadata)
      (generatedFinding path metadata)

documentationHeaderTitleFinding :: FilePath -> Finding
documentationHeaderTitleFinding path =
  finding
    "DOC-HEADER-TITLE"
    path
    "document must contain exactly one H1 title at its first non-blank line"

documentationHeaderPurposeFinding :: FilePath -> Finding
documentationHeaderPurposeFinding path =
  finding
    "DOC-HEADER-PURPOSE"
    path
    "Purpose must occur exactly once, within the first forty lines, with a non-empty value"

documentationHeaderReadThisFinding :: FilePath -> Finding
documentationHeaderReadThisFinding path =
  finding
    "DOC-HEADER-READ-THIS-IF"
    path
    "Read this if must occur exactly once, within the first forty lines, with a non-empty value"

documentationHeaderDetailsFinding :: FilePath -> Finding
documentationHeaderDetailsFinding path =
  finding
    "DOC-HEADER-DETAILS"
    path
    "link-graph metadata details/summary/closing tags must occur exactly once in the first forty lines"

documentationHeaderOrderFinding :: FilePath -> Finding
documentationHeaderOrderFinding path =
  finding
    "DOC-HEADER-ORDER"
    path
    "title, Purpose, Read-this-if, lead prose, and link-graph metadata must occur in that order"

documentationHeaderMetadataBlockFinding :: FilePath -> Finding
documentationHeaderMetadataBlockFinding path =
  finding
    "DOC-HEADER-METADATA-BLOCK"
    path
    "the four metadata fields must occur in canonical order between the metadata summary and closing tag"

documentationHeaderFindingBlocks :: [Finding] -> [Finding] -> [Finding] -> [Finding] -> [Finding] -> [Finding]
#ifdef VALIDATION_DOCUMENT_HEADER_BLOCK_ORDER_MUTANT
documentationHeaderFindingBlocks title purpose readThis details fields =
  fields <> details <> readThis <> purpose <> title
#else
documentationHeaderFindingBlocks title purpose readThis details fields =
  title <> purpose <> readThis <> details <> fields
#endif

documentationHeaderTitleBlock :: [Finding] -> [Finding]
#ifdef VALIDATION_DOCUMENT_HEADER_TITLE_BLOCK_DROP_MUTANT
documentationHeaderTitleBlock findings = length findings `seq` []
#else
documentationHeaderTitleBlock = id
#endif

documentationHeaderPurposeBlock :: [Finding] -> [Finding]
#ifdef VALIDATION_DOCUMENT_HEADER_PURPOSE_BLOCK_DROP_MUTANT
documentationHeaderPurposeBlock findings = length findings `seq` []
#else
documentationHeaderPurposeBlock = id
#endif

documentationHeaderReadThisBlock :: [Finding] -> [Finding]
#ifdef VALIDATION_DOCUMENT_HEADER_READ_THIS_BLOCK_DROP_MUTANT
documentationHeaderReadThisBlock findings = length findings `seq` []
#else
documentationHeaderReadThisBlock = id
#endif

documentationHeaderDetailsBlock :: [Finding] -> [Finding]
#ifdef VALIDATION_DOCUMENT_HEADER_DETAILS_BLOCK_DROP_MUTANT
documentationHeaderDetailsBlock findings = length findings `seq` []
#else
documentationHeaderDetailsBlock = id
#endif

documentationHeaderFieldBlock :: [Finding] -> [Finding]
#ifdef VALIDATION_DOCUMENT_HEADER_FIELD_BLOCK_DROP_MUTANT
documentationHeaderFieldBlock findings = length findings `seq` []
#else
documentationHeaderFieldBlock = id
#endif

documentationHeaderVisibleLimit :: Int
#ifdef VALIDATION_DOCUMENT_HEADER_VISIBLE_LIMIT_THRESHOLD_MUTANT
documentationHeaderVisibleLimit = 39
#else
documentationHeaderVisibleLimit = 40
#endif

documentationHeaderOrientationLines :: [(Int, Text)] -> [(Int, Text)]
documentationHeaderOrientationLines headerVisible =
#ifdef VALIDATION_DOCUMENT_HEADER_ORIENTATION_DETAILS_ROUTE_MUTANT
  length (exactLines documentationHeaderDetailsTag headerVisible) `seq` headerVisible
#else
  case exactLines documentationHeaderDetailsTag headerVisible of
    [detailsLine] -> filter (documentationHeaderBeforeDetails detailsLine) headerVisible
    _ -> headerVisible
#endif

documentationHeaderBeforeDetails :: Int -> (Int, Text) -> Bool
#ifdef VALIDATION_DOCUMENT_HEADER_ORIENTATION_BEFORE_DETAILS_FILTER_MUTANT
documentationHeaderBeforeDetails detailsLine (lineNumber, _) = lineNumber > detailsLine
#else
documentationHeaderBeforeDetails detailsLine (lineNumber, _) = lineNumber < detailsLine
#endif

documentationHeaderNonBlank :: Text -> Bool
#ifdef VALIDATION_DOCUMENT_HEADER_NONBLANK_PREDICATE_MUTANT
documentationHeaderNonBlank line = Text.null (documentationHeaderNonBlankStrip line)
#else
documentationHeaderNonBlank line = not (Text.null (documentationHeaderNonBlankStrip line))
#endif

documentationHeaderNonBlankStrip :: Text -> Text
#ifdef VALIDATION_DOCUMENT_HEADER_NONBLANK_STRIP_MUTANT
documentationHeaderNonBlankStrip = id
#else
documentationHeaderNonBlankStrip = Text.strip
#endif

documentationHeaderTitlePrefix :: Text
#ifdef VALIDATION_DOCUMENT_HEADER_TITLE_PREFIX_MUTANT
documentationHeaderTitlePrefix = "## "
#else
documentationHeaderTitlePrefix = "# "
#endif

documentationHeaderTitleCardinality :: [(Int, Text)] -> Bool
#ifdef VALIDATION_DOCUMENT_HEADER_TITLE_CARDINALITY_MUTANT
documentationHeaderTitleCardinality occurrences = length occurrences `seq` True
#else
documentationHeaderTitleCardinality occurrences = case occurrences of
  [_] -> True
  _ -> False
#endif

documentationHeaderTitleFirstNonBlank :: [(Int, Text)] -> [(Int, Text)] -> Bool
#ifdef VALIDATION_DOCUMENT_HEADER_TITLE_FIRST_NONBLANK_MUTANT
documentationHeaderTitleFirstNonBlank nonBlank occurrences = length nonBlank `seq` length occurrences `seq` True
#else
documentationHeaderTitleFirstNonBlank nonBlank occurrences = case (nonBlank, occurrences) of
  ((firstLine, _) : _, [(titleLine, _)]) -> firstLine == titleLine
  _ -> False
#endif

documentationHeaderPurposePrefix :: Text
#ifdef VALIDATION_DOCUMENT_HEADER_PURPOSE_PREFIX_MUTANT
documentationHeaderPurposePrefix = "> **Purpose mutated**:"
#else
documentationHeaderPurposePrefix = "> **Purpose**:"
#endif

documentationHeaderReadThisPrefix :: Text
#ifdef VALIDATION_DOCUMENT_HEADER_READ_THIS_PREFIX_MUTANT
documentationHeaderReadThisPrefix = "> **Read mutated if**:"
#else
documentationHeaderReadThisPrefix = "> **Read this if**:"
#endif

documentationHeaderPurposeOkay :: [(Int, Text)] -> Bool
documentationHeaderPurposeOkay occurrences =
  documentationHeaderPurposeCardinality occurrences
    && documentationHeaderPurposeLimit occurrences
    && documentationHeaderPurposeValue occurrences

documentationHeaderPurposeCardinality :: [(Int, Text)] -> Bool
#ifdef VALIDATION_DOCUMENT_HEADER_PURPOSE_CARDINALITY_MUTANT
documentationHeaderPurposeCardinality occurrences = length occurrences `seq` True
#else
documentationHeaderPurposeCardinality occurrences = case occurrences of
  [_] -> True
  _ -> False
#endif

documentationHeaderPurposeLimit :: [(Int, Text)] -> Bool
#ifdef VALIDATION_DOCUMENT_HEADER_PURPOSE_LIMIT_MUTANT
documentationHeaderPurposeLimit occurrences = case occurrences of
  [(lineNumber, _)] -> lineNumber <= 39
  _ -> True
#else
documentationHeaderPurposeLimit occurrences = case occurrences of
  [(lineNumber, _)] -> lineNumber <= 40
  _ -> True
#endif

documentationHeaderPurposeValue :: [(Int, Text)] -> Bool
#ifdef VALIDATION_DOCUMENT_HEADER_PURPOSE_VALUE_MUTANT
documentationHeaderPurposeValue occurrences = length occurrences `seq` True
#else
documentationHeaderPurposeValue occurrences = case occurrences of
  [(_, value)] -> not (Text.null value)
  _ -> True
#endif

documentationHeaderReadThisOkay :: [(Int, Text)] -> Bool
documentationHeaderReadThisOkay occurrences =
  documentationHeaderReadThisCardinality occurrences
    && documentationHeaderReadThisLimit occurrences
    && documentationHeaderReadThisValue occurrences

documentationHeaderReadThisCardinality :: [(Int, Text)] -> Bool
#ifdef VALIDATION_DOCUMENT_HEADER_READ_THIS_CARDINALITY_MUTANT
documentationHeaderReadThisCardinality occurrences = length occurrences `seq` True
#else
documentationHeaderReadThisCardinality occurrences = case occurrences of
  [_] -> True
  _ -> False
#endif

documentationHeaderReadThisLimit :: [(Int, Text)] -> Bool
#ifdef VALIDATION_DOCUMENT_HEADER_READ_THIS_LIMIT_MUTANT
documentationHeaderReadThisLimit occurrences = case occurrences of
  [(lineNumber, _)] -> lineNumber <= 39
  _ -> True
#else
documentationHeaderReadThisLimit occurrences = case occurrences of
  [(lineNumber, _)] -> lineNumber <= 40
  _ -> True
#endif

documentationHeaderReadThisValue :: [(Int, Text)] -> Bool
#ifdef VALIDATION_DOCUMENT_HEADER_READ_THIS_VALUE_MUTANT
documentationHeaderReadThisValue occurrences = length occurrences `seq` True
#else
documentationHeaderReadThisValue occurrences = case occurrences of
  [(_, value)] -> not (Text.null value)
  _ -> True
#endif

documentationHeaderDetailsTag :: Text
#ifdef VALIDATION_DOCUMENT_HEADER_DETAILS_TAG_MUTANT
documentationHeaderDetailsTag = "<details-mutated>"
#else
documentationHeaderDetailsTag = "<details>"
#endif

documentationHeaderSummaryTag :: Text
#ifdef VALIDATION_DOCUMENT_HEADER_SUMMARY_TAG_MUTANT
documentationHeaderSummaryTag = "<summary>Mutated metadata</summary>"
#else
documentationHeaderSummaryTag = "<summary>Link-graph metadata</summary>"
#endif

documentationHeaderCloseTag :: Text
#ifdef VALIDATION_DOCUMENT_HEADER_CLOSE_TAG_MUTANT
documentationHeaderCloseTag = "</details-mutated>"
#else
documentationHeaderCloseTag = "</details>"
#endif

documentationHeaderDetailsCardinality :: [Int] -> Bool
#ifdef VALIDATION_DOCUMENT_HEADER_DETAILS_CARDINALITY_MUTANT
documentationHeaderDetailsCardinality values = length values `seq` True
#else
documentationHeaderDetailsCardinality values = case values of
  [_] -> True
  _ -> False
#endif

documentationHeaderSummaryCardinality :: [Int] -> Bool
#ifdef VALIDATION_DOCUMENT_HEADER_SUMMARY_CARDINALITY_MUTANT
documentationHeaderSummaryCardinality values = length values `seq` True
#else
documentationHeaderSummaryCardinality values = case values of
  [_] -> True
  _ -> False
#endif

documentationHeaderCloseCardinality :: [Int] -> Bool
#ifdef VALIDATION_DOCUMENT_HEADER_CLOSE_CARDINALITY_MUTANT
documentationHeaderCloseCardinality values = length values `seq` True
#else
documentationHeaderCloseCardinality values = case values of
  [_] -> True
  _ -> False
#endif

documentationHeaderDetailsLimit :: [Int] -> Bool
#ifdef VALIDATION_DOCUMENT_HEADER_DETAILS_LIMIT_MUTANT
documentationHeaderDetailsLimit values = case values of
  [lineNumber] -> lineNumber <= 39
  _ -> True
#else
documentationHeaderDetailsLimit values = case values of
  [lineNumber] -> lineNumber <= 40
  _ -> True
#endif

documentationHeaderSummaryLimit :: [Int] -> Bool
#ifdef VALIDATION_DOCUMENT_HEADER_SUMMARY_LIMIT_MUTANT
documentationHeaderSummaryLimit values = case values of
  [lineNumber] -> lineNumber <= 39
  _ -> True
#else
documentationHeaderSummaryLimit values = case values of
  [lineNumber] -> lineNumber <= 40
  _ -> True
#endif

documentationHeaderCloseLimit :: [Int] -> Bool
#ifdef VALIDATION_DOCUMENT_HEADER_CLOSE_LIMIT_MUTANT
documentationHeaderCloseLimit values = case values of
  [lineNumber] -> lineNumber <= 39
  _ -> True
#else
documentationHeaderCloseLimit values = case values of
  [lineNumber] -> lineNumber <= 40
  _ -> True
#endif

documentationHeaderTitlePurposeOrder :: Int -> Int -> Bool
#ifdef VALIDATION_DOCUMENT_HEADER_ORIENTATION_TITLE_PURPOSE_MUTANT
documentationHeaderTitlePurposeOrder titleLine purposeLine = titleLine < purposeLine `seq` True
#else
documentationHeaderTitlePurposeOrder titleLine purposeLine = titleLine < purposeLine
#endif

documentationHeaderPurposeReadThisOrder :: Int -> Int -> Bool
#ifdef VALIDATION_DOCUMENT_HEADER_ORIENTATION_PURPOSE_READ_THIS_MUTANT
documentationHeaderPurposeReadThisOrder purposeLine readLine = purposeLine <= readLine `seq` True
#else
documentationHeaderPurposeReadThisOrder purposeLine readLine = purposeLine <= readLine
#endif

documentationHeaderReadThisDetailsOrder :: Int -> Int -> Bool
#ifdef VALIDATION_DOCUMENT_HEADER_ORIENTATION_READ_THIS_DETAILS_MUTANT
documentationHeaderReadThisDetailsOrder readLine detailsLine = readLine < detailsLine `seq` True
#else
documentationHeaderReadThisDetailsOrder readLine detailsLine = readLine < detailsLine
#endif

documentationHeaderDetailsSummaryOrder :: Int -> Int -> Bool
#ifdef VALIDATION_DOCUMENT_HEADER_ORIENTATION_DETAILS_SUMMARY_MUTANT
documentationHeaderDetailsSummaryOrder detailsLine summaryLine = detailsLine < summaryLine `seq` True
#else
documentationHeaderDetailsSummaryOrder detailsLine summaryLine = detailsLine < summaryLine
#endif

documentationHeaderLeadExists :: Int -> Int -> [(Int, Text)] -> Bool
#ifdef VALIDATION_DOCUMENT_HEADER_ORIENTATION_LEAD_EXISTENCE_MUTANT
documentationHeaderLeadExists readLine detailsLine visible =
  any (documentationHeaderLeadLine readLine detailsLine) visible `seq` True
#else
documentationHeaderLeadExists readLine detailsLine =
  any (documentationHeaderLeadLine readLine detailsLine)
#endif

documentationHeaderLeadLine :: Int -> Int -> (Int, Text) -> Bool
documentationHeaderLeadLine readLine detailsLine (lineNumber, line) =
  documentationHeaderLeadAfterReadThis readLine lineNumber
    && documentationHeaderLeadBeforeDetails detailsLine lineNumber
    && documentationHeaderLeadNonBlank line
    && documentationHeaderLeadNonQuote line

documentationHeaderLeadAfterReadThis :: Int -> Int -> Bool
#ifdef VALIDATION_DOCUMENT_HEADER_LEAD_AFTER_READ_THIS_MUTANT
documentationHeaderLeadAfterReadThis readLine lineNumber = lineNumber > readLine `seq` True
#else
documentationHeaderLeadAfterReadThis readLine lineNumber = lineNumber > readLine
#endif

documentationHeaderLeadBeforeDetails :: Int -> Int -> Bool
#ifdef VALIDATION_DOCUMENT_HEADER_LEAD_BEFORE_DETAILS_MUTANT
documentationHeaderLeadBeforeDetails detailsLine lineNumber = lineNumber < detailsLine `seq` True
#else
documentationHeaderLeadBeforeDetails detailsLine lineNumber = lineNumber < detailsLine
#endif

documentationHeaderLeadNonBlank :: Text -> Bool
#ifdef VALIDATION_DOCUMENT_HEADER_LEAD_NONBLANK_MUTANT
documentationHeaderLeadNonBlank line = Text.null (Text.strip line) `seq` True
#else
documentationHeaderLeadNonBlank line = not (Text.null (Text.strip line))
#endif

documentationHeaderLeadNonQuote :: Text -> Bool
#ifdef VALIDATION_DOCUMENT_HEADER_LEAD_NONQUOTE_MUTANT
documentationHeaderLeadNonQuote line = ">" `Text.isPrefixOf` Text.stripStart line `seq` True
#else
documentationHeaderLeadNonQuote line = not (">" `Text.isPrefixOf` Text.stripStart line)
#endif

documentationHeaderMetadataSummaryStatusOrder :: Int -> Int -> Bool
#ifdef VALIDATION_DOCUMENT_HEADER_METADATA_SUMMARY_STATUS_ORDER_MUTANT
documentationHeaderMetadataSummaryStatusOrder summaryLine statusLine = summaryLine < statusLine `seq` True
#else
documentationHeaderMetadataSummaryStatusOrder summaryLine statusLine = summaryLine < statusLine
#endif

documentationHeaderMetadataStatusSupersedesOrder :: Int -> Int -> Bool
#ifdef VALIDATION_DOCUMENT_HEADER_METADATA_STATUS_SUPERSEDES_ORDER_MUTANT
documentationHeaderMetadataStatusSupersedesOrder statusLine supersedesLine = statusLine < supersedesLine `seq` True
#else
documentationHeaderMetadataStatusSupersedesOrder statusLine supersedesLine = statusLine < supersedesLine
#endif

documentationHeaderMetadataSupersedesReferencedOrder :: Int -> Int -> Bool
#ifdef VALIDATION_DOCUMENT_HEADER_METADATA_SUPERSEDES_REFERENCED_ORDER_MUTANT
documentationHeaderMetadataSupersedesReferencedOrder supersedesLine referencedLine = supersedesLine < referencedLine `seq` True
#else
documentationHeaderMetadataSupersedesReferencedOrder supersedesLine referencedLine = supersedesLine < referencedLine
#endif

documentationHeaderMetadataReferencedGeneratedOrder :: Int -> Int -> Bool
#ifdef VALIDATION_DOCUMENT_HEADER_METADATA_REFERENCED_GENERATED_ORDER_MUTANT
documentationHeaderMetadataReferencedGeneratedOrder referencedLine generatedLine = referencedLine < generatedLine `seq` True
#else
documentationHeaderMetadataReferencedGeneratedOrder referencedLine generatedLine = referencedLine < generatedLine
#endif

documentationHeaderMetadataGeneratedCloseOrder :: Int -> Int -> Bool
#ifdef VALIDATION_DOCUMENT_HEADER_METADATA_GENERATED_CLOSE_ORDER_MUTANT
documentationHeaderMetadataGeneratedCloseOrder generatedLine closeLine = generatedLine < closeLine `seq` True
#else
documentationHeaderMetadataGeneratedCloseOrder generatedLine closeLine = generatedLine < closeLine
#endif

documentationHeaderMetadataCloseLimit :: Int -> Bool
#ifdef VALIDATION_DOCUMENT_HEADER_METADATA_CLOSE_LIMIT_MUTANT
documentationHeaderMetadataCloseLimit closeLine = closeLine <= 39
#else
documentationHeaderMetadataCloseLimit closeLine = closeLine <= 40
#endif

documentationHeaderDetailsFindingOrder :: [Finding] -> [Finding] -> [Finding] -> [Finding]
#ifdef VALIDATION_DOCUMENT_HEADER_DETAILS_FINDING_ORDER_MUTANT
documentationHeaderDetailsFindingOrder details orderFinding metadata = metadata <> orderFinding <> details
#else
documentationHeaderDetailsFindingOrder details orderFinding metadata = details <> orderFinding <> metadata
#endif

documentationHeaderFieldFindingOrder :: [Finding] -> [Finding] -> [Finding] -> [Finding] -> [Finding] -> [Finding]
#ifdef VALIDATION_DOCUMENT_HEADER_FIELD_FINDING_ORDER_MUTANT
documentationHeaderFieldFindingOrder cardinality status supersedes referenced generated =
  generated <> referenced <> supersedes <> status <> cardinality
#else
documentationHeaderFieldFindingOrder cardinality status supersedes referenced generated =
  cardinality <> status <> supersedes <> referenced <> generated
#endif

documentationStatusValues :: [Text]
documentationStatusValues = documentationStatusValueOrder $
  concat
    [
#ifdef VALIDATION_DOCUMENT_METADATA_STATUS_AUTHORITATIVE_DROP_MUTANT
      []
#else
      ["Authoritative source"]
#endif
    ,
#ifdef VALIDATION_DOCUMENT_METADATA_STATUS_REFERENCE_DROP_MUTANT
      []
#else
      ["Reference only"]
#endif
    ,
#ifdef VALIDATION_DOCUMENT_METADATA_STATUS_DEPRECATED_DROP_MUTANT
      []
#else
      ["Deprecated"]
#endif
    ]

documentationStatusValueOrder :: [Text] -> [Text]
#ifdef VALIDATION_DOCUMENT_METADATA_STATUS_LEGAL_ORDER_MUTANT
documentationStatusValueOrder = reverse
#else
documentationStatusValueOrder = id
#endif

metadataFor :: Document -> Metadata
metadataFor document =
  Metadata
    { metadataStatus = oneValue "Status"
    , metadataSupersedes = oneValue "Supersedes"
    , metadataReferencedBy = oneValue "Referenced by"
    , metadataGeneratedSections = oneValue "Generated sections"
    }
 where
  oneValue name = case fieldLines name (headerMetadataLines document) of
    [(_, value)] -> Just value
    _ -> Nothing

-- Only fields inside the canonical, first-forty-lines metadata details block
-- are header metadata.  Body-level fields such as a sprint's **Status** are
-- document content and must not change header cardinality.
headerMetadataLines :: Document -> [(Int, Text)]
headerMetadataLines document =
  case
      ( exactLines "<summary>Link-graph metadata</summary>" visible
      , exactLines "</details>" visible
      ) of
    ([summaryLine], [closeLine])
      | summaryLine < closeLine && closeLine <= 40 ->
          filter (\(lineNumber, _) -> lineNumber > summaryLine && lineNumber < closeLine) visible
    _ -> []
 where
  visible = filter ((<= 40) . fst) (documentVisibleLines document)

fieldCardinalityFindings :: Document -> [Finding]
fieldCardinalityFindings document =
  [ finding
      "DOC-METADATA-CARDINALITY"
      (documentPath document)
      (name <> " must occur exactly once at column zero inside the first-forty-lines metadata block")
  | name <- metadataFields
  , case fieldLines name (headerMetadataLines document) of
      [_] -> False
      _ -> True
  ]
 where
  metadataFields = ["Status", "Supersedes", "Referenced by", "Generated sections"]

enumFinding :: FilePath -> Text -> (Metadata -> Maybe Text) -> [Text] -> Metadata -> [Finding]
enumFinding path name accessor legal metadata =
  [ finding
      "DOC-METADATA-VALUE"
      path
      (name <> " is not in the closed metadata vocabulary: " <> value)
  | Just value <- [accessor metadata]
  , value `notElem` legal
  ]

requiredValueFinding :: FilePath -> Text -> (Metadata -> Maybe Text) -> Metadata -> [Finding]
requiredValueFinding path name accessor metadata =
  [ finding "DOC-METADATA-VALUE" path (name <> " must not be empty")
  | Just value <- [accessor metadata]
  , Text.null (Text.strip value)
  ]

generatedFinding :: FilePath -> Metadata -> [Finding]
generatedFinding path metadata =
  [ finding "DOC-METADATA-GENERATED" path "Generated sections must be exactly 'none'"
  | Just value <- [metadataGeneratedSections metadata]
  , value /= "none"
  ]

prefixedLines :: Text -> [(Int, Text)] -> [(Int, Text)]
prefixedLines prefix = mapMaybe extract
 where
  extract (lineNumber, line)
    | prefix `Text.isPrefixOf` line = Just (lineNumber, Text.strip (Text.drop (Text.length prefix) line))
    | otherwise = Nothing

exactLines :: Text -> [(Int, Text)] -> [Int]
exactLines wanted =
  map fst . filter ((== wanted) . Text.strip . snd)

fieldLines :: Text -> [(Int, Text)] -> [(Int, Text)]
fieldLines name = prefixedLines ("**" <> name <> "**:")

checkLinks :: Map FilePath Document -> Document -> [Finding]
checkLinks documents document = concatMap checkOne (documentLinks document)
 where
  checkOne link
    | "#" `Text.isPrefixOf` linkTarget link =
        checkFragment document (Text.drop 1 (linkTarget link)) link
    | otherwise =
        let (pathPart, fragmentWithMarker) = Text.breakOn "#" (linkTarget link)
            fragment = Text.drop 1 fragmentWithMarker
         in if not (".md" `Text.isSuffixOf` Text.toCaseFold pathPart)
              then []
              else
                case resolveDocumentPath (documentPath document) pathPart of
                  Nothing -> [linkFinding "DOC-LINK-TARGET" link ("link escapes repository root: " <> linkTarget link)]
                  Just resolved -> case Map.lookup resolved documents of
                    Nothing -> [linkFinding "DOC-LINK-TARGET" link ("Markdown target does not exist: " <> linkTarget link)]
                    Just targetDocument
                      | Text.null fragmentWithMarker -> []
                      | otherwise -> checkFragment targetDocument fragment link
  checkFragment targetDocument fragment link
    | Text.null fragment = [linkFinding "DOC-LINK-FRAGMENT" link "empty Markdown fragment is not a section target"]
    | fragment `Set.member` documentAnchors targetDocument = []
    | otherwise =
        [ linkFinding
            "DOC-LINK-FRAGMENT"
            link
            ( "fragment #"
                <> fragment
                <> " does not resolve in "
                <> Text.pack (documentPath targetDocument)
            )
        ]
  linkFinding code link detail =
    finding code (documentPath document) ("line " <> showText (linkLine link) <> ": " <> detail)

-- FilePath.normalise intentionally preserves internal parent components, so
-- it cannot resolve a documentation graph: @documents/../README.md@ would not
-- equal the canonical @README.md@ key.  Collapse parents lexically while
-- refusing an absolute target or any walk above the repository root.
resolveDocumentPath :: FilePath -> Text -> Maybe FilePath
resolveDocumentPath source rawTarget
  | "/" `Text.isPrefixOf` target = Nothing
  | otherwise = do
      components <- foldM step [] (baseComponents <> targetComponents)
      pure (Text.unpack (Text.intercalate "/" (reverse components)))
 where
  target = Text.pack (map slash (Text.unpack rawTarget))
  baseComponents = pathComponents (Text.pack (normalizePath (takeDirectory source)))
  targetComponents = pathComponents target
  pathComponents = filter (not . Text.null) . Text.splitOn "/"
  step stack component
    | component == "." = Just stack
    | component == ".." = case stack of
        [] -> Nothing
        _ : rest -> Just rest
    | otherwise = Just (component : stack)
  slash '\\' = '/'
  slash character = character

checkReferencedBy :: Map FilePath Document -> [Document] -> [Finding]
checkReferencedBy documents governed = concatMap compareDocument governed
 where
  -- Header conformance is governed-path-only, but inbound links may originate
  -- in any supplied Markdown document (for example, a vendor provenance
  -- record).  Omitting those sources fabricates stale-backlink findings.
  inbound = foldl' recordLinks importInbound (Map.elems documents)
  importInbound =
    case Map.lookup "CLAUDE.md" documents of
      Just document
        | Text.strip (documentText document) == "@AGENTS.md" ->
            Map.singleton "AGENTS.md" (Set.singleton "CLAUDE.md")
      _ -> Map.empty
  recordLinks graph source = foldl' (recordLink source) graph (documentLinks source)
  recordLink source graph link =
    case resolvedMarkdownTarget source link of
      Just target
        | target /= documentPath source
            && Map.member target documents
            && isGovernedPath target ->
            Map.insertWith Set.union target (Set.singleton (documentPath source)) graph
      _ -> graph
  compareDocument document =
    case metadataReferencedBy (metadataFor document) of
      Nothing -> []
      Just raw ->
        let entries = referencedByEntries raw
            declared = Set.fromList entries
            actual = Map.findWithDefault Set.empty (documentPath document) inbound
            duplicateEntries = length entries /= Set.size declared
         in [ finding "DOC-BACKLINK-DUPLICATE" (documentPath document) "Referenced by contains a duplicate path"
            | duplicateEntries
            ]
              <> [ finding
                     "DOC-BACKLINK-MISSING"
                     (documentPath document)
                     (Text.pack source <> " links here but is absent from Referenced by")
                 | source <- Set.toAscList (actual Set.\\ declared)
                 ]
              <> [ finding
                     "DOC-BACKLINK-STALE"
                     (documentPath document)
                     (Text.pack source <> " is declared in Referenced by but contains no inbound link")
                 | source <- Set.toAscList (declared Set.\\ actual)
                 ]

resolvedMarkdownTarget :: Document -> LocalLink -> Maybe FilePath
resolvedMarkdownTarget source link
  | "#" `Text.isPrefixOf` target = Just (documentPath source)
  | not (".md" `Text.isSuffixOf` Text.toCaseFold pathPart) = Nothing
  | otherwise = resolveDocumentPath (documentPath source) pathPart
 where
  target = linkTarget link
  (pathPart, _) = Text.breakOn "#" target

referencedByEntries :: Text -> [FilePath]
referencedByEntries raw
  | Text.toCaseFold (Text.strip raw) `elem` ["n/a", "none"] = []
  | otherwise =
      [ normalizePath (Text.unpack (Text.strip entry))
      | entry <- Text.splitOn "," raw
      , not (Text.null (Text.strip entry))
      ]

checkClaudeImport :: Map FilePath Document -> [Finding]
checkClaudeImport documents =
  case Map.lookup "CLAUDE.md" documents of
    Nothing -> []
    Just document ->
      [ finding
          "DOC-CLAUDE-IMPORT"
          "CLAUDE.md"
          "CLAUDE.md must contain only the canonical @AGENTS.md import"
      | documentText document /= "@AGENTS.md\n"
      ]

checkArchivePolicy :: Map FilePath Document -> [Document] -> Int -> [Finding]
checkArchivePolicy documents governed aliasCount =
  [ finding
      "DOC-ARCHIVE-REFERENCE"
      (documentPath document)
      "the eliminated legacy archive filename remains in active Markdown"
  | document <- governed
  , archiveAliasCount document > 0
  ]
    <> [ finding
           "DOC-LEGACY-REGISTER"
           canonicalLegacyRegister
           "the corpus must contain exactly one canonical active legacy register"
       | Map.member canonicalLegacyRegister documents == False
           || length legacyRegisterPaths /= 1
       ]
    <> [ finding
           "DOC-ARCHIVE-REFERENCE"
           canonicalLegacyRegister
           ("archive alias count must be zero; observed " <> showText aliasCount)
       | aliasCount /= 0
       ]
 where
  legacyRegisterPaths =
    [ path
    | path <- Map.keys documents
    , "legacy_tracking_for_deletion" `Text.isInfixOf` Text.pack (takeFileName path)
    ]

archiveAlias :: Text
archiveAlias =
  Text.pack
    (takeFileName (Policy.canonicalForbiddenArchivePath Policy.canonicalPolicyContract))

canonicalLegacyRegister :: FilePath
canonicalLegacyRegister =
  Policy.canonicalActiveRegisterPath Policy.canonicalPolicyContract

archiveAliasCount :: Document -> Int
archiveAliasCount document =
  maximum
    [ countFolded archiveAlias (documentText document)
    , countFolded archiveAlias (commentElidedText (documentText document))
    ]

canonicalGeneratedRoot :: FilePath
canonicalGeneratedRoot =
  Policy.generationRootPath
    (Policy.generationRoot (Policy.generationContract Policy.canonicalPolicyContract))

countFolded :: Text -> Text -> Int
countFolded needle = countOccurrences (Text.toCaseFold needle) . Text.toCaseFold

countOccurrences :: Text -> Text -> Int
countOccurrences needle source
  | Text.null needle = 0
  | otherwise = go source
 where
  go remaining =
    let (_, match) = Text.breakOn needle remaining
     in if Text.null match
          then 0
          else 1 + go (Text.drop (Text.length needle) match)

showText :: Show value => value -> Text
showText = Text.pack . show
