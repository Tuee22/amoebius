{-# LANGUAGE OverloadedStrings #-}

-- | The governance checks of the standalone documentation checker
-- (documentation_standards.md sections 1, 6, and 17; decision_log.md section 1):
-- decision-log entry structure, the frozen-doctrine baseline, the three-mood
-- honesty rule, and gate-specification block equality. Every check reads the
-- supplied corpus bytes and the compiled plan-decisions values; none reads the
-- filesystem or a validator module.
module Amoebius.Doc.Governance
  ( checkDecisionLog
  , checkFrozenDoctrine
  , checkGateSpecBlocks
  , checkHonestyCitations
  , decisionLogPath
  , frozenDigest
  , gateSpecBlockOf
  , honestyScope
  , isFrozenPath
  ) where

import Amoebius.Doc.Types (Finding, finding)
import Amoebius.Plan.Decisions qualified as Decisions
import Amoebius.Plan.PhaseIdentity qualified as PhaseIdentity
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString qualified as ByteString
import Data.Char (intToDigit, isDigit)
import Data.List (isPrefixOf, sort)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding

decisionLogPath :: FilePath
decisionLogPath = Decisions.decisionLogPath

-- * Decision log

-- | decision_log.md section 1: one @### DL-NNNN — title@ heading per entry, strictly
-- increasing identifiers that equal the compiled decision set, six one-line fields
-- in a fixed order with an optional @Contradiction@ before @Decision@, at most five
-- affected paths that exist or are marked deleted, and replacement links that
-- resolve to entries.
checkDecisionLog :: [(FilePath, Text)] -> [Finding]
checkDecisionLog corpus = case lookup decisionLogPath corpus of
  Nothing -> [finding "DOC-DECISION-LOG-MISSING" decisionLogPath "the decision log is absent from the corpus"]
  Just contents -> checkEntries corpus (visibleLines contents)

checkEntries :: [(FilePath, Text)] -> [(Int, Text)] -> [Finding]
checkEntries corpus numbered =
  headingFindings <> orderFindings <> identityFindings <> concatMap entryFindings entries
 where
  entryStarts = [(lineNumber, line) | (lineNumber, line) <- numbered, "### " `Text.isPrefixOf` line]
  entries = zipWith entryOf entryStarts (map (Just . fst) (drop 1 entryStarts) <> [Nothing])
  entryOf (lineNumber, heading) next =
    ( lineNumber
    , heading
    , [ (number, line)
      | (number, line) <- numbered
      , number > lineNumber
      , maybe True (number <) next
      , not ("## " `Text.isPrefixOf` line)
      ]
    )
  parsedIds = [(lineNumber, parseEntryHeading heading) | (lineNumber, heading, _) <- entries]
  headingFindings =
    [ finding "DOC-DECISION-LOG-HEADING" (subject lineNumber) "an entry heading must read `### DL-NNNN — <title>`"
    | (lineNumber, Nothing) <- parsedIds
    ]
  identifiers = [identifier | (_, Just identifier) <- parsedIds]
  orderFindings =
    [ finding "DOC-DECISION-LOG-ORDER" decisionLogPath ("entry identifiers must increase strictly: " <> earlier <> " precedes " <> later)
    | (earlier, later) <- zip identifiers (drop 1 identifiers)
    , entryNumber earlier >= entryNumber later
    ]
  expectedIds = map Decisions.renderDecisionId Decisions.allDecisionIds
  identityFindings =
    [ finding
        "DOC-DECISION-LOG-IDS"
        decisionLogPath
        ("the entries must be exactly the compiled decision identifiers; log-only=" <> showList' [i | i <- identifiers, i `notElem` expectedIds] <> " compiled-only=" <> showList' [i | i <- expectedIds, i `notElem` identifiers])
    | sort identifiers /= sort expectedIds
    ]
  entryFindings (lineNumber, _, body) =
    fieldOrderFindings <> emptyFindings <> affectedFindings <> linkFindings
   where
    fields = mapMaybe parseField body
    names = map (\(_, name, _) -> name) fields
    expectedNames = ["Date", "Decision", "Rejected alternatives", "Affected documents", "Replaces", "Replaced by"]
    withoutContradiction = case names of
      ("Date" : "Contradiction" : rest) -> "Date" : rest
      other -> other
    fieldOrderFindings =
      [ finding "DOC-DECISION-LOG-FIELDS" (subject lineNumber) ("entry fields must be Date, [Contradiction], Decision, Rejected alternatives, Affected documents, Replaces, Replaced by in that order; observed " <> showList' names)
      | withoutContradiction /= expectedNames
      ]
    emptyFindings =
      [ finding "DOC-DECISION-LOG-FIELD-EMPTY" (subject number) ("the `" <> name <> "` field must carry a value on its own line")
      | (number, name, value) <- fields
      , Text.null (Text.strip value)
      ]
    affected = [value | (_, "Affected documents", value) <- fields]
    affectedTokens = concatMap backtickedSpans affected
    affectedFindings =
      [ finding "DOC-DECISION-LOG-AFFECTED" (subject lineNumber) ("at most five affected paths are admitted; observed " <> Text.pack (show (length affectedTokens)))
      | length affectedTokens > 5
      ]
        <> [ finding "DOC-DECISION-LOG-AFFECTED-PATH" (subject lineNumber) ("affected path does not exist in the corpus and is not marked (deleted): " <> token)
           | value <- affected
           , token <- backtickedSpans value
           , ".md" `Text.isSuffixOf` token
           , lookup (Text.unpack token) corpus == Nothing
           , not (("`" <> token <> "` (deleted)") `Text.isInfixOf` value)
           ]
    linkFindings =
      [ finding "DOC-DECISION-LOG-LINK" (subject number) ("the `" <> name <> "` field must be N/A or an entry identifier present in the log; observed " <> value)
      | (number, name, value) <- fields
      , name `elem` ["Replaces", "Replaced by"]
      , let trimmed = Text.strip value
      , trimmed /= "N/A"
      , trimmed `notElem` identifiers
      ]
  subject lineNumber = decisionLogPath <> ":" <> show lineNumber

parseEntryHeading :: Text -> Maybe Text
parseEntryHeading heading = case Text.splitOn " — " (Text.drop 4 heading) of
  (identifier : _ : _)
    | Text.length identifier == 7
    , "DL-" `Text.isPrefixOf` identifier
    , Text.all isDigit (Text.drop 3 identifier) ->
        Just identifier
  _ -> Nothing

entryNumber :: Text -> Int
entryNumber identifier = case reads (Text.unpack (Text.drop 3 identifier)) of
  [(value, "")] -> value
  _ -> -1

parseField :: (Int, Text) -> Maybe (Int, Text, Text)
parseField (lineNumber, line) = case Text.stripPrefix "**" line of
  Just rest -> case Text.breakOn "**:" rest of
    (name, remainder)
      | not (Text.null name)
      , Just value <- Text.stripPrefix "**:" remainder ->
          Just (lineNumber, name, value)
    _ -> Nothing
  Nothing -> Nothing

-- * Frozen doctrine

-- | documentation_standards.md section 17: every frozen path has a baseline row, every
-- baseline row names a present path, and the body digest (bytes without the
-- Referenced-by line) equals the recorded one.
checkFrozenDoctrine :: [(FilePath, Text)] -> [Finding]
checkFrozenDoctrine corpus =
  missingFindings <> changedFindings <> unlistedFindings
 where
  documents = Map.fromList corpus
  baseline = Decisions.frozenBaseline
  missingFindings =
    [ finding "DOC-FROZEN-PATH-MISSING" (Decisions.frozenPath row) "a frozen path recorded in the baseline is absent from the corpus"
    | row <- baseline
    , Map.notMember (Decisions.frozenPath row) documents
    ]
  changedFindings =
    [ finding
        "DOC-FROZEN-BODY-CHANGED"
        (Decisions.frozenPath row)
        ( "the body differs from the baseline recorded under "
            <> Decisions.renderDecisionId (Decisions.frozenDecision row)
            <> "; a frozen body changes only with a decision-log entry naming this path in the same change"
        )
    | row <- baseline
    , Just contents <- [Map.lookup (Decisions.frozenPath row) documents]
    , frozenDigest contents /= Decisions.frozenDigest row
    ]
  unlistedFindings =
    [ finding "DOC-FROZEN-UNLISTED" path "a frozen path has no baseline row; creating or freezing a governed document is a decision-log event"
    | path <- Map.keys documents
    , isFrozenPath path
    , path `notElem` Decisions.frozenPaths
    ]

-- | The frozen set: every Markdown path under documents/ except the decision log,
-- AGENTS.md, the three plan rulebooks, and the legacy register.
isFrozenPath :: FilePath -> Bool
isFrozenPath path =
  path /= decisionLogPath
    && ( ("documents/" `isPrefixOf` path && ".md" `Text.isSuffixOf` Text.pack path)
           || path `elem` frozenNamedPaths
       )

frozenNamedPaths :: [FilePath]
frozenNamedPaths =
  [ "AGENTS.md"
  , "DEVELOPMENT_PLAN/development_plan_standards.md"
  , "DEVELOPMENT_PLAN/development_plan_phase_model.md"
  , "DEVELOPMENT_PLAN/development_plan_gate_integrity.md"
  , "DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md"
  ]

-- | SHA-256 of the UTF-8 bytes with every @**Referenced by**:@ line removed, so a
-- backlink reconciliation is never a body change.
frozenDigest :: Text -> Text
frozenDigest contents =
  hex (SHA256.hash (TextEncoding.encodeUtf8 (Text.intercalate "\n" (filter (not . isReferencedBy) (Text.splitOn "\n" contents)))))
 where
  isReferencedBy line = "**Referenced by**:" `Text.isPrefixOf` line

hex :: ByteString.ByteString -> Text
hex = Text.pack . concatMap byteHex . ByteString.unpack
 where
  byteHex value = [intToDigit (fromIntegral value `div` 16), intToDigit (fromIntegral value `mod` 16)]

-- * Honesty

-- | The documents the three-mood rule measures: doctrine, the root guides, and the
-- plan rulebooks and indexes. Phase contracts and the two registers are excluded:
-- a phase contract is specification by construction (its status line says so), and
-- the registers exist to name identifiers.
honestyScope :: FilePath -> Bool
honestyScope path =
  path == "README.md"
    || path == "AGENTS.md"
    || ("documents/" `isPrefixOf` path && path /= decisionLogPath)
    || ("DEVELOPMENT_PLAN/" `isPrefixOf` path && not ("DEVELOPMENT_PLAN/phase_" `isPrefixOf` path) && path /= "DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md")

-- | documentation_standards.md section 6: a non-fenced paragraph that names a
-- Haskell module or a source path is an observed implementation with one receipt
-- citation, a historical result with one decision-log link and no identifier, or
-- specification voice that says what phase owes the machinery.
checkHonestyCitations :: [(FilePath, Text)] -> [Finding]
checkHonestyCitations corpus =
  concat
    [ paragraphFindings path paragraph
    | (path, contents) <- corpus
    , honestyScope path
    , paragraph <- paragraphs (visibleLines contents)
    , namesMachinery (paragraphText paragraph)
    ]
 where
  statuses = Map.fromList [(path, phaseStatusOf contents) | (path, contents) <- corpus, "DEVELOPMENT_PLAN/phase_" `isPrefixOf` path]
  paragraphFindings path paragraph
    | observed =
        [finding "DOC-HONESTY-CITATION" location "an observed-implementation paragraph carries exactly one [GateSpec:<id>] or [example:<name>] citation" | citationCount /= 1]
          <> [ finding "DOC-HONESTY-CITATION-UNBACKED" location ("the cited gate is not a Done phase's specification: " <> cited)
             | citationCount == 1
             , cited <- gateSpecCitations text
             , not (citationBacked cited)
             ]
    | historical =
        [finding "DOC-HONESTY-HISTORICAL" location "a historical paragraph links exactly one decision-log entry" | decisionLinkCount /= 1]
          <> [finding "DOC-HONESTY-HISTORICAL" location "a historical paragraph names no identifier and no digit" | Text.any (== '`') stripped || Text.any isDigit stripped]
          <> [finding "DOC-HONESTY-HISTORICAL" location "a historical paragraph is at most two sentences" | sentenceCount stripped > 2]
    | "owed by" `Text.isInfixOf` Text.toLower text =
        case owedPhases of
          [] -> [finding "DOC-HONESTY-OWED-LINK" location "specification voice links the phase document that owes the machinery"]
          links ->
            [ finding "DOC-HONESTY-OWED-DONE" location ("the owing phase is recorded Done, so the paragraph must become an observed implementation or a historical result: " <> Text.pack link)
            | link <- links
            , Map.lookup link statuses == Just "✅ Done."
            ]
    | otherwise = [finding "DOC-HONESTY-MOOD" location "a paragraph naming a module or source path must open with Observed implementation or Historical result (invalidated), or say which phase it is owed by"]
   where
    text = paragraphText paragraph
    location = path <> ":" <> show (paragraphLine paragraph)
    observed = "Observed implementation" `Text.isPrefixOf` stripMarkers text
    historical = "Historical result (invalidated)" `Text.isPrefixOf` stripMarkers text
    citationCount = length (filter (\t -> "GateSpec:" `Text.isPrefixOf` t || "example:" `Text.isPrefixOf` t) (Text.splitOn "[" text))
    citationBacked capability =
      case [PhaseIdentity.phaseIdentityPath row | row <- PhaseIdentity.allPhaseIdentities, PhaseIdentity.phaseIdentityCapability row == capability] of
        (path : _) -> Map.lookup path statuses == Just "✅ Done."
        [] -> False
    decisionLinkCount = length (filter ("decision_log.md#dl-" `Text.isInfixOf`) (linkTargets text))
    stripped = withoutLinkTargets text
    owedPhases = mapMaybe phaseLinkPath (linkTargets text)
    phaseLinkPath target =
      let file = Text.takeWhileEnd (/= '/') (Text.takeWhile (/= '#') target)
       in if "phase_" `Text.isPrefixOf` file && ".md" `Text.isSuffixOf` file
            then Just ("DEVELOPMENT_PLAN/" <> Text.unpack file)
            else Nothing

-- | The capabilities cited as @[GateSpec:<capability>]@ in a paragraph.
gateSpecCitations :: Text -> [Text]
gateSpecCitations text = [Text.takeWhile (/= ']') rest | piece <- drop 1 (Text.splitOn "[GateSpec:" text), let rest = piece]

phaseStatusOf :: Text -> Text
phaseStatusOf contents =
  case dropWhile (/= "## Phase Status") (Text.lines contents) of
    (_ : rest) -> case filter (not . Text.null . Text.strip) rest of
      (line : _) -> Text.strip line
      [] -> ""
    [] -> ""

-- | Drop list bullets, ordinals, emphasis, and blockquote markers so the mood
-- label is judged at the start of the paragraph's prose.
stripMarkers :: Text -> Text
stripMarkers text =
  let trimmed = Text.dropWhile (`elem` ("*_> -" :: String)) text
      (digits, rest) = Text.span isDigit trimmed
   in if not (Text.null digits) && ". " `Text.isPrefixOf` rest
        then Text.dropWhile (`elem` ("*_> -" :: String)) (Text.drop 2 rest)
        else trimmed

-- | A paragraph names machinery when a backticked span is a module of this
-- repository (@Amoebius.X…@) or a concrete repository source file (a path under
-- src/, app/, test/, or pb/ ending in .hs or .py). Layout globs such as @pb/**@
-- and bare extensions are classification rules, not implementation claims.
namesMachinery :: Text -> Bool
namesMachinery text = any isMachinery (backtickedSpans text)
 where
  isMachinery span' = isModule span' || isSourceFile span'
  isModule span' = case Text.stripPrefix "Amoebius." span' of
    Just rest -> not (Text.null rest) && Text.all (\c -> c /= ' ') rest && Text.head rest `elem` ['A' .. 'Z']
    Nothing -> False
  isSourceFile span' =
    any (`Text.isPrefixOf` span') ["src/", "app/", "test/", "pb/"]
      && (".hs" `Text.isSuffixOf` span' || ".py" `Text.isSuffixOf` span')
      && not (Text.any (`elem` ("*<>{} " :: String)) span')

sentenceCount :: Text -> Int
sentenceCount text = length (filter (not . Text.null . Text.strip) (Text.split (`elem` (".!?" :: String)) text))

linkTargets :: Text -> [Text]
linkTargets text = [Text.takeWhile (/= ')') rest | piece <- drop 1 (Text.splitOn "](" text), let rest = piece]

withoutLinkTargets :: Text -> Text
withoutLinkTargets text = Text.intercalate "" (map dropTarget (zip [0 :: Int ..] (Text.splitOn "](" text)))
 where
  dropTarget (index, piece)
    | index == 0 = piece
    | otherwise = Text.drop 1 (Text.dropWhile (/= ')') piece)

-- * Gate-specification blocks

-- | The fenced @gate-spec@ block of a phase must equal its compiled rendering.
checkGateSpecBlocks :: [(Int, Text)] -> [(FilePath, Text)] -> [Finding]
checkGateSpecBlocks compiled corpus = concatMap compare' compiled
 where
  compare' (ordinal, rendered) = case PhaseIdentity.lookupPhaseIdentity ordinal of
    Nothing -> [finding "DOC-GATE-SPEC-PHASE" "DEVELOPMENT_PLAN/" ("a compiled gate specification names an ordinal outside the phase table: " <> Text.pack (show ordinal))]
    Just row ->
      let path = PhaseIdentity.phaseIdentityPath row
       in case lookup path corpus of
            Nothing -> [finding "DOC-GATE-SPEC-PHASE" path "the phase document of a compiled gate specification is absent"]
            Just contents -> case gateSpecBlockOf contents of
              Nothing -> [finding "DOC-GATE-SPEC-BLOCK" path "the phase document must carry exactly one fenced gate-spec block"]
              Just block ->
                [ finding "DOC-GATE-SPEC-MISMATCH" path "the fenced gate-spec block differs from the compiled specification"
                | Text.strip block /= Text.strip rendered
                ]

-- | The single fenced block whose info string is @gate-spec@, or Nothing when there
-- is none or more than one.
gateSpecBlockOf :: Text -> Maybe Text
gateSpecBlockOf contents = case blocks (Text.lines contents) of
  [block] -> Just (Text.unlines block)
  _ -> Nothing
 where
  blocks remaining = case dropWhile (\line -> Text.strip line /= "```gate-spec") remaining of
    [] -> []
    (_ : rest) ->
      let (body, after) = break (\line -> "```" `Text.isPrefixOf` Text.strip line) rest
       in body : blocks (drop 1 after)

-- * Shared helpers

-- | Numbered lines outside fenced code blocks; fence lines themselves are dropped.
visibleLines :: Text -> [(Int, Text)]
visibleLines contents = go False (zip [1 ..] (Text.lines contents))
 where
  go _ [] = []
  go inside ((number, line) : rest)
    | "```" `Text.isPrefixOf` Text.stripStart line = go (not inside) rest
    | inside = go inside rest
    | otherwise = (number, line) : go inside rest

data Paragraph = Paragraph
  { paragraphLine :: Int
  , paragraphText :: Text
  }

-- | Prose blocks: consecutive non-blank visible lines, split further at list items,
-- and excluding headings, tables, HTML, and one-line metadata fields.
paragraphs :: [(Int, Text)] -> [Paragraph]
paragraphs numbered = concatMap toParagraphs (blocks numbered)
 where
  blocks [] = []
  blocks entries =
    let (blank, rest) = span (Text.null . Text.strip . snd) entries
        (block, remaining) = break (Text.null . Text.strip . snd) rest
     in blank `seq` (if null block then [] else block : blocks remaining)
  toParagraphs block =
    [ Paragraph number (Text.unwords (map (Text.strip . snd) item))
    | item <- splitItems block
    , (number, firstLine) <- take 1 item
    , prose firstLine
    ]
  splitItems [] = []
  splitItems (entry : rest) =
    let (continuation, remaining) = break (isItemStart . snd) rest
     in (entry : continuation) : splitItems remaining
  isItemStart line =
    let trimmed = Text.stripStart line
        (digits, rest) = Text.span isDigit trimmed
     in any (`Text.isPrefixOf` trimmed) ["- ", "* "] || (not (Text.null digits) && ". " `Text.isPrefixOf` rest)
  prose line =
    let trimmed = Text.stripStart line
     in not (Text.null trimmed)
          && not (any (`Text.isPrefixOf` trimmed) ["#", "|", "<", "**Referenced by**", "**Status**", "**Supersedes**", "**Generated sections**"])

backtickedSpans :: Text -> [Text]
backtickedSpans text = [piece | (index, piece) <- zip [0 :: Int ..] (Text.splitOn "`" text), odd index]

showList' :: [Text] -> Text
showList' items = "[" <> Text.intercalate "," items <> "]"

-- Silence the unused-import warning for Map when only qualified uses remain.
_unusedMap :: Map Int Int
_unusedMap = Map.empty
