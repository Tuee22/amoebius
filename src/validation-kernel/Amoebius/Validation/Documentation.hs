{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.Documentation
  ( checkCorpus
  , checkDocumentStructure
  , checkDocuments
  , checkPolicyOwnerReferences
  , checkPolicyOwnerReferencesFor
  , githubAnchor
  ) where

import Amoebius.Validation.PhaseContract (checkPhaseContracts)
import Amoebius.Validation.PolicyContract qualified as Policy
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding
  , finding
  , mergeChecks
  , observation
  )
import Control.Exception (IOException, try)
import Control.Monad (foldM, forM)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString qualified as ByteString
import Data.Char (intToDigit, isAlphaNum, isSpace, toLower)
import Data.List (sort)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (listToMaybe, mapMaybe)
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Text.IO qualified as TextIO
import System.Directory (doesDirectoryExist, doesFileExist, listDirectory)
import System.FilePath.Posix
  ( (</>)
  , normalise
  , takeDirectory
  , takeExtension
  , takeFileName
  )

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

data Metadata = Metadata
  { metadataStatus :: Maybe Text
  , metadataSupersedes :: Maybe Text
  , metadataReferencedBy :: Maybe Text
  , metadataGeneratedSections :: Maybe Text
  }
  deriving (Eq, Show)

-- | Worktree diagnostic only. Candidate authority must call 'checkDocuments'
-- with the immutable blob corpus obtained by source-closure discovery; this
-- convenience function reads mutable filesystem bytes and therefore cannot
-- establish candidate provenance.
checkCorpus :: FilePath -> IO CheckResult
checkCorpus root = do
  (documents, discoveryFindings) <- discoverDocuments root
  let discovery =
        CheckResult
          { checkName = "documentation-discovery"
          , checkObservations =
              [ observation "supplied-document-count" (showText (length documents))
              , observation "governed-document-count" (showText (length (filter (isGovernedPath . fst) documents)))
              ]
          , checkFindings = discoveryFindings
          }
  pure
    ( mergeChecks
        "documentation-corpus"
        [ discovery
        , checkDocuments documents
        , checkPhaseContracts documents
        ]
    )

-- | Production documentation check. Paths are repository-relative; order is
-- immaterial, but the complete governed path manifest is frozen in Haskell.
checkDocuments :: [(FilePath, Text)] -> CheckResult
checkDocuments = checkDocumentsWithInventory True

-- | Structural seam for small independently-authored parser corpora. It never
-- establishes production discovery completeness and must not be wired to the
-- dispatcher or candidate evidence.
checkDocumentStructure :: [(FilePath, Text)] -> CheckResult
checkDocumentStructure = checkDocumentsWithInventory False

checkDocumentsWithInventory :: Bool -> [(FilePath, Text)] -> CheckResult
checkDocumentsWithInventory enforceCanonicalInventory supplied =
  CheckResult
    { checkName = "documentation"
    , checkObservations =
        [ observation "document-count" (showText (Map.size documents))
        , observation "governed-count" (showText (length governed))
        , observation "local-link-count" (showText (sum (map (length . documentLinks) governed)))
        , observation "archive-alias-count" (showText archiveCount)
        , observation "governed-path-manifest-sha256" governedPathDigest
        ]
    , checkFindings =
        duplicateFindings
          <> emptyDiscoveryFindings
          <> requiredCorpusFindings
          <> inventoryFindings
          <> concatMap checkHeader (filter ((/= "CLAUDE.md") . documentPath) governed)
          <> checkClaudeImport documents
          <> concatMap checkMarkdownSyntax governed
          <> retiredArtifactCorpusFindings governed
          <> concatMap (checkLinks documents) governed
          <> checkReferencedBy documents governed
          <> checkArchivePolicy documents governed archiveCount
          <> [ item
             | enforceCanonicalInventory
             , item <- policyOwnerFindings Policy.canonicalPolicyContract documents
             ]
    }
 where
  normalized = [(normalizePath path, contents) | (path, contents) <- supplied]
  grouped = Map.fromListWith (<>) [(path, [contents]) | (path, contents) <- normalized]
  duplicateFindings =
    [ finding "DOC-DUPLICATE" path "document path occurs more than once in the supplied corpus"
    | (path, copies) <- Map.toAscList grouped
    , length copies /= 1
    ]
  documents = Map.mapMaybeWithKey (\path copies -> makeDocumentFor path <$> listToMaybe copies) grouped
  governed = filter (isGovernedPath . documentPath) (Map.elems documents)
  emptyDiscoveryFindings =
    [ finding "DOC-DISCOVERY-EMPTY" "documents/" "no governed Markdown documents were supplied"
    | null governed
    ]
  requiredCorpusFindings =
    [ finding "DOC-DISCOVERY-MISSING" path "required governed root document is absent from the supplied corpus"
    | path <- ["README.md", "AGENTS.md", "CLAUDE.md"]
    , not (Map.member path documents)
    ]
      <> [ finding "DOC-DISCOVERY-MISSING" prefix "required governed documentation subtree is absent from the supplied corpus"
         | prefix <- ["documents", "DEVELOPMENT_PLAN"]
         , not (any (pathPrefixOf prefix) (Map.keys documents))
         ]
  governedPaths = sort (map documentPath governed)
  governedPathDigest = hex (SHA256.hash (TextEncoding.encodeUtf8 (Text.unlines (map Text.pack governedPaths))))
  inventoryFindings =
    [ finding
        "DOC-INVENTORY-MISMATCH"
        "documents/"
        ( "governed path inventory differs from the reviewed Haskell baseline: expected count="
            <> showText canonicalGovernedPathCount
            <> " digest="
            <> canonicalGovernedPathDigest
            <> ", observed count="
            <> showText (length governedPaths)
            <> " digest="
            <> governedPathDigest
        )
    | enforceCanonicalInventory
        && (length governedPaths /= canonicalGovernedPathCount || governedPathDigest /= canonicalGovernedPathDigest)
    ]
  -- The eliminated filename is a structural alias, not a semantic policy
  -- phrase. Cross-cutting policy prose is deliberately not interpreted here:
  -- executable choices belong to PolicyContract and prose correspondence is
  -- an external human-review obligation.
  archiveCount = sum (map archiveAliasCount governed)

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
-- from prose.  A reviewed Haskell test path remains admissible; generated
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
      | linesToScan <- [rawLines, commentElidedLines (documentText document)]
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
          [ joinPhysicalLines (documentText document)
          , joinPhysicalLines (commentElidedText (documentText document))
          ]
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
              [documentText document, commentElidedText (documentText document)]
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
  [ "test/fixture/"
  , "test/fixtures/"
  , "test/golden/"
  , "test/goldens/"
  , "test/mutant/"
  , "test/mutants/"
  , "test/negative/"
  , "test/oracle/"
  , "test/oracles/"
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
  foldedRoot = Text.map toLower root
  go token =
    let (before, matchingAndAfter) = Text.breakOn foldedRoot (Text.map toLower token)
     in if Text.null matchingAndAfter
          then []
          else
            let offset = Text.length before
                occurrence = Text.drop offset token
                remaining = Text.drop (offset + Text.length root) token
             in occurrence : go remaining

-- The retired artifact-family roots admit only one concrete Haskell source
-- path.  A suffix-shaped glob, variable, home expansion, empty segment, or
-- traversal is not an exact file path even when its final bytes are @.hs@.
isExactHaskellPath :: Text -> Text -> Bool
isExactHaskellPath root occurrence =
  Text.map toLower root `Text.isPrefixOf` Text.map toLower occurrence
    && Text.all exactPathCharacter relative
    && not (null segments)
    && all validSegment segments
    && maybe False validHaskellBasename (lastMay segments)
 where
  relative = Text.drop (Text.length root) occurrence
  segments = Text.splitOn "/" relative
  exactPathCharacter character = isAlphaNum character || character `elem` ['/', '.', '_', '-']
  validSegment segment = not (Text.null segment) && segment `notElem` [".", ".."]
  validHaskellBasename basename =
    ".hs" `Text.isSuffixOf` basename
      && not (Text.null (Text.dropEnd 3 basename))

lastMay :: [a] -> Maybe a
lastMay [] = Nothing
lastMay values = Just (last values)

joinPhysicalLines :: Text -> Text
joinPhysicalLines = Text.concat . map Text.strip . Text.lines

-- These phrases asserted a version-controlled transport without necessarily
-- naming a path.  State-machine uses such as "transaction committed" do not
-- match.  The corpus should name reviewed Haskell mutation/oracle source and
-- its separately generated transport instead.
retiredCommitPhrases :: Text -> [Text]
retiredCommitPhrases source = concatMap scanClause (retiredPhraseClauses (Text.toCaseFold source))
 where
  scanClause clause =
    [ prefix <> " … " <> artifact
    | prefix <- prefixes wordsInClause
    , artifact <- retiredArtifactWords
    , artifact `elem` wordsInClause
    ]
   where
    wordsInClause = normalizedWords clause

  prefixes wordsInClause =
    ["committed" | "committed" `elem` wordsInClause]
      <> ["checked-in" | anyAdjacent "checked" "in" wordsInClause]

  retiredArtifactWords =
    [ "mutant"
    , "mutants"
    , "oracle"
    , "oracles"
    , "golden"
    , "goldens"
    , "fixture"
    , "fixtures"
    ]

  anyAdjacent first second wordsInClause =
    any (== [first, second]) (windowsOfTwo wordsInClause)

  windowsOfTwo (first : second : rest) = [first, second] : windowsOfTwo (second : rest)
  windowsOfTwo _ = []

retiredPhraseClauses :: Text -> [Text]
retiredPhraseClauses = Text.split (`elem` ['.', '!', '?', ';'])

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
-- headings. A human, never this parser, owns semantic prose correspondence.
checkPolicyOwnerReferences :: [(FilePath, Text)] -> CheckResult
checkPolicyOwnerReferences =
  checkPolicyOwnerReferencesFor Policy.canonicalPolicyContract

-- | Explicit-contract seam for an independently stated structural oracle.
-- Production callers use 'checkPolicyOwnerReferences'; supplying a contract
-- here cannot change the canonical corpus check.
checkPolicyOwnerReferencesFor :: Policy.PolicyContract -> [(FilePath, Text)] -> CheckResult
checkPolicyOwnerReferencesFor contract supplied =
  CheckResult
    { checkName = "policy-owner-structure"
    , checkObservations = [observation "policy.owner-document-count" (showText (Map.size documents))]
    , checkFindings = policyOwnerFindings contract documents
    }
 where
  documents =
    Map.fromList
      [ (normalized, makeDocumentFor normalized contents)
      | (path, contents) <- supplied
      , let normalized = normalizePath path
      ]

policyOwnerFindings :: Policy.PolicyContract -> Map FilePath Document -> [Finding]
policyOwnerFindings contract documents = concatMap checkOwner ([minBound .. maxBound] :: [Policy.PolicyId])
 where
  checkOwner identifier =
    case Policy.policyOwnerReference contract identifier of
      Nothing ->
        [ finding
            "DOC-POLICY-OWNER-MAP"
            "Amoebius.Validation.PolicyContract"
            ("the canonical owner map omits " <> showText identifier)
        ]
      Just reference ->
        case Map.lookup (normalizePath (Policy.policyOwnerPath reference)) documents of
          Nothing ->
            [ finding
                "DOC-POLICY-OWNER-PATH"
                (Policy.policyOwnerPath reference)
                ("the owner document for " <> showText identifier <> " is absent")
            ]
          Just document ->
            [ finding
                "DOC-POLICY-OWNER-ANCHOR"
                (Policy.policyOwnerPath reference)
                ( "the owner for "
                    <> showText identifier
                    <> " must be exact heading '"
                    <> Policy.policyOwnerSection reference
                    <> "' at #"
                    <> Policy.policyOwnerAnchor reference
                )
            | (Policy.policyOwnerAnchor reference, Policy.policyOwnerSection reference)
                `notElem` headingAnchorPairs (documentVisibleLines document)
            ]

canonicalGovernedPathCount :: Int
#ifdef VALIDATION_DOCUMENT_INVENTORY_BASELINE_MUTANT
canonicalGovernedPathCount = 194
#else
canonicalGovernedPathCount = 195
#endif

canonicalGovernedPathDigest :: Text
canonicalGovernedPathDigest = "51c38807d39526404f678c6a89ccaf6210ff91d7b17d4cde7989f1bc2a9e55f2"

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

discoverDocuments :: FilePath -> IO ([(FilePath, Text)], [Finding])
discoverDocuments root = do
  roots <- forM rootDocuments (readIfPresent root)
  documentsRoot <- walkMarkdown root "documents"
  planRoot <- walkMarkdown root "DEVELOPMENT_PLAN"
  auxiliary <- walkAuxiliaryMarkdown root rootDocuments
  let entries = roots <> documentsRoot <> planRoot <> auxiliary
      documents = [(path, contents) | Right (path, contents) <- entries]
      problems = [problem | Left problem <- entries]
      requiredRoots = ["README.md", "documents", "DEVELOPMENT_PLAN"]
  missing <- fmap concat . forM requiredRoots $ \relative -> do
    filePresent <- doesFileExist (root </> relative)
    directoryPresent <- doesDirectoryExist (root </> relative)
    pure
      [ finding "DOC-DISCOVERY-MISSING" relative "required governed documentation root is absent"
      | not (filePresent || directoryPresent)
      ]
  pure (documents, problems <> missing)
 where
  rootDocuments = ["README.md", "AGENTS.md", "CLAUDE.md"]

-- Worktree diagnostics need non-governed Markdown as graph input even though
-- only the canonical roots receive header checks.  In particular, vendor
-- provenance documents can be legitimate inbound-link sources.  Generated
-- and VCS-private trees are excluded from this mutable diagnostic discovery.
walkAuxiliaryMarkdown :: FilePath -> [FilePath] -> IO [Either Finding (FilePath, Text)]
walkAuxiliaryMarkdown root canonicalRoots = do
  listed <- try (listDirectory root) :: IO (Either IOException [FilePath])
  case listed of
    Left problem ->
      pure
        [ Left
            ( finding
                "DOC-DISCOVERY-READ"
                "."
                ("cannot enumerate repository root for auxiliary Markdown: " <> Text.pack (show problem))
            )
        ]
    Right names -> fmap concat . forM (sort names) $ \name ->
      if name `elem` excluded || name `elem` canonicalRoots
        then pure []
        else do
          directory <- doesDirectoryExist (root </> name)
          if directory
            then walkMarkdown root name
            else
              if takeExtension name == ".md"
                then pure <$> readDocument root name
                else pure []
 where
  excluded = [canonicalGeneratedRoot, ".git", "dist-newstyle", "documents", "DEVELOPMENT_PLAN"]

readIfPresent :: FilePath -> FilePath -> IO (Either Finding (FilePath, Text))
readIfPresent root relative = do
  present <- doesFileExist (root </> relative)
  if present
    then readDocument root relative
    else
      pure
        ( Left
            ( finding
                "DOC-DISCOVERY-MISSING"
                relative
                "expected repository-root Markdown document is absent"
            )
        )

walkMarkdown :: FilePath -> FilePath -> IO [Either Finding (FilePath, Text)]
walkMarkdown root relative = do
  present <- doesDirectoryExist (root </> relative)
  if not present
    then pure []
    else do
      listed <- try (listDirectory (root </> relative)) :: IO (Either IOException [FilePath])
      case listed of
        Left problem ->
          pure
            [ Left
                ( finding
                    "DOC-DISCOVERY-READ"
                    relative
                    ("cannot enumerate documentation directory: " <> Text.pack (show problem))
                )
            ]
        Right names -> fmap concat . forM (sort names) $ \name -> do
          let child = normalizePath (relative </> name)
          directory <- doesDirectoryExist (root </> child)
          if directory
            then walkMarkdown root child
            else
              if takeExtension name == ".md"
                then pure <$> readDocument root child
                else pure []

readDocument :: FilePath -> FilePath -> IO (Either Finding (FilePath, Text))
readDocument root relative = do
  result <- try (TextIO.readFile (root </> relative)) :: IO (Either IOException Text)
  pure $ case result of
    Left problem ->
      Left
        ( finding
            "DOC-DISCOVERY-READ"
            relative
            ("cannot read Markdown bytes: " <> Text.pack (show problem))
        )
    Right contents -> Right (normalizePath relative, contents)

isGovernedPath :: FilePath -> Bool
isGovernedPath path =
  path `elem` ["README.md", "AGENTS.md", "CLAUDE.md"]
    || "documents" `pathPrefixOf` path
    || "DEVELOPMENT_PLAN" `pathPrefixOf` path

pathPrefixOf :: FilePath -> FilePath -> Bool
pathPrefixOf prefix candidate =
  candidate == prefix || Text.pack (prefix <> "/") `Text.isPrefixOf` Text.pack candidate

normalizePath :: FilePath -> FilePath
normalizePath = dropDot . normalise . map slash
 where
  slash '\\' = '/'
  slash character = character
  dropDot ('.' : '/' : rest) = dropDot rest
  dropDot path = path

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
  titleFindings
    <> purposeFindings
    <> readThisFindings
    <> detailsFindings
    <> fieldFindings
 where
  path = documentPath document
  visible = documentVisibleLines document
  headerVisible = filter ((<= 40) . fst) visible
  orientationVisible = case exactLines "<details>" headerVisible of
    [detailsLine] -> filter ((< detailsLine) . fst) headerVisible
    _ -> headerVisible
  metadataLines = headerMetadataLines document
  nonBlank = [(lineNumber, Text.stripEnd line) | (lineNumber, line) <- visible, not (Text.null (Text.strip line))]
  titleOccurrences = [(lineNumber, line) | (lineNumber, line) <- nonBlank, "# " `Text.isPrefixOf` line]
  titleFindings =
    [finding "DOC-HEADER-TITLE" path "document must contain exactly one H1 title at its first non-blank line" | not titleOkay]
  titleOkay = case (nonBlank, titleOccurrences) of
    ((firstLine, firstText) : _, [(titleLine, _)]) -> firstLine == titleLine && "# " `Text.isPrefixOf` firstText
    _ -> False
  purposeOccurrences = prefixedLines "> **Purpose**:" orientationVisible
  readThisOccurrences = prefixedLines "> **Read this if**:" orientationVisible
  purposeFindings = exactHeaderLine "DOC-HEADER-PURPOSE" "Purpose" purposeOccurrences
  readThisFindings = exactHeaderLine "DOC-HEADER-READ-THIS-IF" "Read this if" readThisOccurrences
  detailsLines = exactLines "<details>" headerVisible
  summaryLines = exactLines "<summary>Link-graph metadata</summary>" headerVisible
  closeLines = exactLines "</details>" headerVisible
  detailsFindings =
    [ finding "DOC-HEADER-DETAILS" path "link-graph metadata details/summary/closing tags must occur exactly once in the first forty lines"
    | not (oneInHeader detailsLines && oneInHeader summaryLines && oneInHeader closeLines)
    ]
      <> [ finding "DOC-HEADER-ORDER" path "title, Purpose, Read-this-if, lead prose, and link-graph metadata must occur in that order"
         | not orientationOkay
         ]
      <> [ finding "DOC-HEADER-METADATA-BLOCK" path "the four metadata fields must occur in canonical order between the metadata summary and closing tag"
         | not metadataBlockOkay
         ]
  orientationOkay = case (titleOccurrences, purposeOccurrences, readThisOccurrences, detailsLines, summaryLines) of
    ([(titleLine, _)], [(purposeLine, _)], [(readLine, _)], [detailsLine], [summaryLine]) ->
      titleLine < purposeLine
        && purposeLine <= readLine
        && readLine < detailsLine
        && detailsLine < summaryLine
        && any (leadLine readLine detailsLine) visible
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
          summaryLine < statusLine
            && statusLine < supersedesLine
            && supersedesLine < referencedByLine
            && referencedByLine < generatedLine
            && generatedLine < closeLine
            && closeLine <= 40
      _ -> False
  leadLine readLine detailsLine (lineNumber, line) =
    lineNumber > readLine
      && lineNumber < detailsLine
      && not (Text.null (Text.strip line))
      && not (">" `Text.isPrefixOf` Text.stripStart line)
  metadata = metadataFor document
  fieldFindings =
    fieldCardinalityFindings document
      <> enumFinding path "Status" metadataStatus ["Authoritative source", "Reference only", "Deprecated"] metadata
      <> requiredValueFinding path "Supersedes" metadataSupersedes metadata
      <> requiredValueFinding path "Referenced by" metadataReferencedBy metadata
      <> generatedFinding path metadata
  exactHeaderLine code label occurrences =
    [ finding code path (label <> " must occur exactly once, within the first forty lines, with a non-empty value")
    | not
        ( case occurrences of
            [(lineNumber, value)] -> lineNumber > 0 && lineNumber <= 40 && not (Text.null value)
            _ -> False
        )
    ]
  oneInHeader values = case values of
    [lineNumber] -> lineNumber <= 40
    _ -> False

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
