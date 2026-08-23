{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.PhaseContract
  ( checkPhaseAndTracker
  , checkPhaseContractStructure
  , checkPhaseContracts
  ) where

import Amoebius.Validation.PolicyContract qualified as Policy
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding
  , finding
  , observation
  )
import Data.Char (isDigit, isSpace)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (listToMaybe, mapMaybe)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import System.FilePath.Posix ((</>), normalise, takeDirectory, takeFileName)
import Text.Read (readMaybe)

data PhaseDocument = PhaseDocument
  { phaseNumber :: Int
  , phasePath :: FilePath
  , phaseRawLines :: [Text]
  , phaseLines :: [(Int, Text)]
  , phaseTitle :: Maybe Text
  , phaseFields :: Map Text [Text]
  , phaseGateRows :: [(Text, Text)]
  }
  deriving (Eq, Show)

data TrackerRow = TrackerRow
  { trackerNumber :: Int
  , trackerTitle :: Text
  , trackerSubstrate :: Text
  , trackerLane :: Text
  , trackerRegister :: Text
  , trackerStatus :: Text
  , trackerContract :: Text
  }
  deriving (Eq, Show)

data Fence = Fence Char Int
  deriving (Eq, Show)

-- | Pure phase/tracker check. The supplied paths are repository-relative and
-- the caller controls every byte, which lets independent oracle tests construct
-- minimal positive and paired-negative corpora without filesystem effects.
checkPhaseContracts :: [(FilePath, Text)] -> CheckResult
checkPhaseContracts = checkPhaseContractsWithSemanticBarrier True

-- | Structural parser seam for small oracle corpora. A clean result here is
-- not a phase-contract candidate because it omits the canonical semantic
-- subject/oracle/reviewer/legacy/resource joins.
checkPhaseContractStructure :: [(FilePath, Text)] -> CheckResult
checkPhaseContractStructure = checkPhaseContractsWithSemanticBarrier False

checkPhaseContractsWithSemanticBarrier :: Bool -> [(FilePath, Text)] -> CheckResult
checkPhaseContractsWithSemanticBarrier requireSemanticAudit supplied =
  CheckResult
    { checkName = "phase-contracts"
    , checkObservations =
        [ observation "phase-document-count" (showText (Map.size phases))
        , observation "tracker-row-count" (showText (length trackerRows))
        , observation "gate-row-count" (showText (sum (map (length . phaseGateRows) (Map.elems phases))))
        , observation "sprint-section-count" (showText (sum (map (length . sprintSectionsFor) (Map.elems phases))))
        , observation "unresolved-marker-cell-count" (showText unresolvedMarkerCount)
        , observation "missing-marker-cell-count" (showText missingMarkerCount)
        , observation "refusal-marker-cell-count" (showText refusalMarkerCount)
        ]
    , checkFindings =
        phaseDomainFindings
          <> concatMap checkPhaseStructure (Map.elems phases)
          <> concatMap (checkDependency phases) (Map.elems phases)
          <> concatMap checkGate (Map.elems phases)
          <> concatMap (checkSprintStatuses requireSemanticAudit) (Map.elems phases)
          <> trackerFindings
          <> checkTrackerJoin phases trackerRows
          <> [ finding
                 "PLAN-SEMANTIC-AUDIT-UNIMPLEMENTED"
                 "DEVELOPMENT_PLAN/"
                 "the Haskell subject/oracle/reviewer/mutant/legacy/resource ownership joins are not implemented"
             | requireSemanticAudit
             ]
    }
 where
  normalized = [(normalizePath path, contents) | (path, contents) <- supplied]
  parsed = mapMaybe (uncurry parsePhaseDocument) normalized
  grouped = Map.fromListWith (<>) [(phaseNumber phase, [phase]) | phase <- parsed]
  phases = Map.mapMaybe (listToMaybe . sortOnPath) grouped
  duplicatePhaseFindings =
    [ finding
        "PLAN-PHASE-DUPLICATE"
        (phasePath first)
        ("phase ordinal occurs in more than one contract path: " <> renderPaths candidates)
    | candidates@(first : _) <- Map.elems grouped
    , length candidates /= 1
    ]
  expectedNumbers = Set.fromList [phaseDomainLowerNumber .. phaseDomainUpperNumber]
  actualNumbers = Map.keysSet phases
  missingNumbers = Set.toAscList (expectedNumbers Set.\\ actualNumbers)
  extraNumbers = Set.toAscList (actualNumbers Set.\\ expectedNumbers)
  phaseDomainFindings =
    duplicatePhaseFindings
      <> [finding "PLAN-PHASE-MISSING" "DEVELOPMENT_PLAN/" ("missing Phase " <> showText number) | number <- missingNumbers]
      <> [finding "PLAN-PHASE-EXTRA" (phasePath phase) ("phase ordinal lies outside the closed " <> phaseDomainLabel <> " domain") | number <- extraNumbers, Just phase <- [Map.lookup number phases]]
      <> [finding "PLAN-PHASE-DISCOVERY" "DEVELOPMENT_PLAN/" "no numbered phase contracts were supplied" | Map.null phases]
  trackerCandidates = [contents | (path, contents) <- normalized, path == trackerPath]
  trackerRows = case trackerCandidates of
    [contents] -> parseTrackerRows contents
    _ -> []
  trackerFindings =
    [ finding
        "PLAN-TRACKER-CARDINALITY"
        trackerPath
        "the supplied corpus must contain exactly one development-plan tracker"
    | length trackerCandidates /= 1
    ]
      <> checkTrackerShape trackerRows
  gateCellValues = [value | phase <- Map.elems phases, (_, value) <- phaseGateRows phase]
  unresolvedMarkerCount = length (filter containsUnresolvedMarker gateCellValues)
  missingMarkerCount = length (filter containsMissingMarker gateCellValues)
  refusalMarkerCount = length (filter containsRefusalMarker gateCellValues)

-- | Explicit name for callers that treat the tracker join as one pure seam.
checkPhaseAndTracker :: [(FilePath, Text)] -> CheckResult
checkPhaseAndTracker = checkPhaseContracts

parsePhaseDocument :: FilePath -> Text -> Maybe PhaseDocument
parsePhaseDocument path contents = do
  number <- phaseNumberFromPath path
  let visible = outsideFences contents
      fields = Map.fromListWith (<>) [(name, [value]) | name <- summaryFieldNames, value <- fieldParagraphs name visible]
  pure
    PhaseDocument
      { phaseNumber = number
      , phasePath = path
      , phaseRawLines = Text.lines contents
      , phaseLines = visible
      , phaseTitle = parsePhaseTitle number visible
      , phaseFields = fields
      , phaseGateRows = parseGateRows (sectionBodies "## Gate integrity" visible)
      }

phaseNumberFromPath :: FilePath -> Maybe Int
phaseNumberFromPath path
  | takeDirectory path /= "DEVELOPMENT_PLAN" = Nothing
  | otherwise = do
      remainder <- Text.stripPrefix "phase_" (Text.pack (takeFileName path))
      let (digits, suffix) = Text.splitAt 2 remainder
      if Text.length digits == 2
          && Text.all isDigit digits
          && "_" `Text.isPrefixOf` suffix
          && ".md" `Text.isSuffixOf` suffix
        then readMaybe (Text.unpack digits)
        else Nothing

parsePhaseTitle :: Int -> [(Int, Text)] -> Maybe Text
parsePhaseTitle number visible =
  case
      [ Text.strip title
      | (_, line) <- visible
      , Just title <- [Text.stripPrefix ("# Phase " <> showText number <> ":") (Text.strip line)]
      , not (Text.null (Text.strip title))
      ] of
    [title] -> Just title
    _ -> Nothing

summaryFieldNames :: [Text]
summaryFieldNames = ["Phase scope", "Substrate", "Lane", "Register", "Depends on", "Gate"]

fieldParagraphs :: Text -> [(Int, Text)] -> [Text]
fieldParagraphs name visible = mapMaybe atIndex [0 .. length visible - 1]
 where
  prefix = "**" <> name <> ":**"
  atIndex index = do
    (_, line) <- atMay visible index
    rest <- Text.stripPrefix prefix line
    let following = takeContinuation (drop (index + 1) visible)
        value = Text.unwords (Text.strip rest : map (Text.strip . snd) following)
    pure (Text.strip value)
  takeContinuation =
    takeWhile
      ( \(_, line) ->
          not (Text.null (Text.strip line))
            && not ("**" `Text.isPrefixOf` Text.stripStart line)
            && not ("## " `Text.isPrefixOf` Text.stripStart line)
      )

sectionBodies :: Text -> [(Int, Text)] -> [[(Int, Text)]]
sectionBodies heading visible = mapMaybe bodyAt [0 .. length visible - 1]
 where
  bodyAt index = do
    (_, line) <- atMay visible index
    if Text.strip line == heading
      then Just (takeWhile (not . isH2 . snd) (drop (index + 1) visible))
      else Nothing

isH2 :: Text -> Bool
isH2 line = "## " `Text.isPrefixOf` Text.stripStart line

parseGateRows :: [[(Int, Text)]] -> [(Text, Text)]
parseGateRows = concatMap (mapMaybe (parseGateRow . snd))

parseGateRow :: Text -> Maybe (Text, Text)
parseGateRow line =
  case tableCells line of
    keyCell : valueCells
      | not (null valueCells) ->
          let key = stripBackticks keyCell
              value = Text.strip (Text.intercalate "|" valueCells)
           in if Text.null key || key == "Key" || Text.all (`elem` ['-', ':']) key
                then Nothing
                else Just (key, value)
    _ -> Nothing

tableCells :: Text -> [Text]
tableCells line
  | not ("|" `Text.isPrefixOf` stripped) = []
  | otherwise =
      let cells = Text.splitOn "|" stripped
          withoutLeading = case cells of
            "" : rest -> rest
            rest -> rest
          withoutTrailing = case reverse withoutLeading of
            "" : rest -> reverse rest
            _ -> withoutLeading
       in map Text.strip withoutTrailing
 where
  stripped = Text.strip line

stripBackticks :: Text -> Text
stripBackticks value =
  case Text.stripPrefix "`" stripped >>= Text.stripSuffix "`" of
    Just unquoted -> unquoted
    Nothing -> stripped
 where
  stripped = Text.strip value

checkPhaseStructure :: PhaseDocument -> [Finding]
checkPhaseStructure phase =
  titleFindings
    <> statusFindings
    <> summaryFindings
    <> gateHeadingFindings
 where
  path = phasePath phase
  number = phaseNumber phase
  titleFindings =
    [ finding "PLAN-PHASE-TITLE" path ("expected exactly one '# Phase " <> showText number <> ": <title>' heading")
    | phaseTitle phase == Nothing
    ]
  statuses = statusLines phase
  expectedStatus = Policy.resetPhaseStatusText (policyResetStatus number) <> "."
  statusBodies = sectionBodies "## Phase Status" (phaseLines phase)
  currentStatusClaims =
    [ Text.strip line
    | body <- statusBodies
    , (_, line) <- body
    , isBareCurrentStatusClaim line
    ]
  additionalStatusFields =
    [ Text.strip line
    | body <- statusBodies
    , (_, line) <- body
    , "**Status**:" `Text.isPrefixOf` Text.stripStart line
    ]
  rawExpectedStatusCount = length (filter (== expectedStatus) (phaseRawLines phase))
  statusFindings =
    [ finding
        "PLAN-PHASE-STATUS"
        path
        ("Phase Status must contain exactly one raw canonical current-status line '" <> expectedStatus <> "' and no second bare current-status claim")
    | statuses /= [expectedStatus]
        || currentStatusClaims /= [expectedStatus]
        || not (null additionalStatusFields)
        || rawExpectedStatusCount /= 1
    ]
  summaryFindings = concatMap checkSummaryField summaryFieldNames
  checkSummaryField name =
    case Map.findWithDefault [] name (phaseFields phase) of
      [value]
        | not (Text.null value) -> []
      _ ->
        [ finding
            "PLAN-SUMMARY-FIELD"
            path
            (name <> " must occur exactly once as a non-empty Phase Summary field")
        ]
  gateHeadings = sectionBodies "## Gate integrity" (phaseLines phase)
  gateHeadingFindings =
    [ finding "PLAN-GATE-SECTION" path "exactly one Gate integrity section is required"
    | length gateHeadings /= 1
    ]

statusLines :: PhaseDocument -> [Text]
statusLines phase =
  [ Text.strip line
  | body <- sectionBodies "## Phase Status" (phaseLines phase)
  , (_, line) <- take 1 [(lineNumber, candidate) | (lineNumber, candidate) <- body, not (Text.null (Text.strip candidate))]
  ]

checkDependency :: Map Int PhaseDocument -> PhaseDocument -> [Finding]
checkDependency phases phase =
  case Map.findWithDefault [] "Depends on" (phaseFields phase) of
    [dependency]
      | phaseNumber phase == phaseDomainLowerNumber ->
          [ finding "PLAN-DEPENDENCY" (phasePath phase) "Phase 0 must depend on genesis only"
          | Text.toCaseFold (Text.strip dependency) /= "genesis"
          ]
      | otherwise -> checkNumbered dependency
    _ -> []
 where
  number = phaseNumber phase
  checkNumbered dependency =
    let (targets, linkProblems) = markdownTargets dependency
        resolved = map (resolveFrom (phasePath phase)) targets
        predecessor = policyPredecessorNumber number
        expectedPath = phasePath <$> Map.lookup predecessor phases
        forward =
          [ targetNumber
          | target <- resolved
          , Just targetNumber <- [phaseNumberFromPath target]
          , targetNumber >= number
          ]
     in [ finding
            "PLAN-DEPENDENCY-LINK"
            (phasePath phase)
            ("Depends on is not one structurally valid inline Markdown link: " <> problem)
        | problem <- linkProblems
        ]
          <> [ finding
            "PLAN-DEPENDENCY-PREDECESSOR"
            (phasePath phase)
            ("Depends on must contain only one link, to immediate Phase " <> showText predecessor)
        | maybe True (\path -> resolved /= [path]) expectedPath
        ]
          <> [ finding
                 "PLAN-DEPENDENCY-FORWARD"
                 (phasePath phase)
                 ("Depends on contains a same-or-forward phase edge to Phase " <> showText targetNumber)
             | targetNumber <- forward
             ]

checkGate :: PhaseDocument -> [Finding]
checkGate phase =
  shapeFindings
    <> emptyFindings
    <> unresolvedFindings
    <> commandFindings
    <> summaryCommandFindings
 where
  path = phasePath phase
  number = phaseNumber phase
  rows = phaseGateRows phase
  keys = map fst rows
  rowMap = Map.fromList rows
  commandText = "pb validate phase " <> formatPhase number
  expectedCommand = "`" <> commandText <> "`"
  expectedSummaryValue = expectedCommand <> "; see [Gate integrity](#gate-integrity). NOT VALIDATED."
  expectedSummaryLine = "**Gate:** " <> expectedSummaryValue
  shapeFindings =
    [ finding
        "PLAN-GATE-SHAPE"
        path
        ( "Gate table keys must be the exact ordered eighteen-row contract; observed "
            <> Text.intercalate ", " keys
        )
    | keys /= gateKeys
    ]
  emptyFindings =
    [ finding "PLAN-GATE-EMPTY" path (key <> " has an empty gate-contract cell")
    | (key, value) <- rows
    , Text.null (Text.strip value)
    ]
  unresolvedFindings =
    [ finding
        "PLAN-GATE-UNRESOLVED"
        path
        (key <> " contains a fail-closed UNRESOLVED/MISSING marker")
    | (key, value) <- rows
    , containsRefusalMarker value
    ]
  commandFindings = case Map.lookup "Command" rowMap of
    Just value ->
      [ finding
          "PLAN-GATE-COMMAND"
          path
          ("Command row must name exactly one canonical " <> expectedCommand)
      | validationCommandSpans value /= [(1, commandText)]
          || countOccurrences expectedCommand value /= 1
      ]
    Nothing -> []
  summaryCommandFindings = case Map.findWithDefault [] "Gate" (phaseFields phase) of
    [value] ->
      [ finding
          "PLAN-GATE-SUMMARY-COMMAND"
          path
          ("Gate summary must be the exact one-line reset form '" <> expectedSummaryLine <> "'")
      | value /= expectedSummaryValue
          || validationCommandSpans value /= [(1, commandText)]
          || countOccurrences expectedCommand value /= 1
          || length (filter (== expectedSummaryLine) (phaseRawLines phase)) /= 1
      ]
    _ -> []

inlineCodeSpans :: Text -> [(Int, Text)]
inlineCodeSpans = go . Text.unpack
 where
  go [] = []
  go source@('`' : _) =
    let (opening, rest) = span (== '`') source
        width = length opening
     in case close width [] rest of
          Nothing -> []
          Just (contents, remaining) -> (width, Text.pack (reverse contents)) : go remaining
  go (_ : rest) = go rest
  close _ _ [] = Nothing
  close width reversed source@('`' : _) =
    let (candidate, rest) = span (== '`') source
     in if length candidate == width
          then Just (reversed, rest)
          else close width (reverse candidate <> reversed) rest
  close width reversed (character : rest) = close width (character : reversed) rest

validationCommandSpans :: Text -> [(Int, Text)]
validationCommandSpans =
  filter (Text.isPrefixOf "pb validate" . Text.toCaseFold . snd) . inlineCodeSpans

containsRefusalMarker :: Text -> Bool
containsRefusalMarker value = containsUnresolvedMarker value || containsMissingMarker value

containsUnresolvedMarker :: Text -> Bool
containsUnresolvedMarker = Text.isInfixOf "UNRESOLVED"

containsMissingMarker :: Text -> Bool
containsMissingMarker value =
  "`MISSING`" `Text.isInfixOf` value
    || "MISSING —" `Text.isInfixOf` value
    || "MISSING:" `Text.isInfixOf` value

gateKeys :: [Text]
gateKeys =
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
  , "Human authority"
  ]

checkSprintStatuses :: Bool -> PhaseDocument -> [Finding]
checkSprintStatuses enforceCanonicalInventory phase =
  inventoryFindings <> concatMap checkSection sprintSections
 where
  sprintSections = sprintSectionsFor phase
  parsedOrdinals = map (parseSprintOrdinal (phaseNumber phase) . fst) sprintSections
  expectedOrdinals = [1 .. Map.findWithDefault 0 (phaseNumber phase) canonicalSprintCounts]
  inventoryFindings =
    [ finding
        "PLAN-SPRINT-INVENTORY"
        (phasePath phase)
        ( "sprint identities must be the reviewed contiguous inventory "
            <> showText expectedOrdinals
            <> "; observed "
            <> showText parsedOrdinals
        )
    | enforceCanonicalInventory && parsedOrdinals /= map Just expectedOrdinals
    ]
  checkSection (heading, body) =
    let ordinal = parseSprintOrdinal (phaseNumber phase) heading
        statusEntries =
          [ (lineNumber, Text.strip value)
          | (lineNumber, line) <- body
          , Just value <- [Text.stripPrefix "**Status**:" line]
          ]
        statuses = map snd statusEntries
        expectedStatus = expectedSprintStatus (phaseNumber phase) <$> ordinal
        bareStatusClaims = [Text.strip line | (_, line) <- body, isBareCurrentStatusClaim line]
        rawStatusIsCanonical = case expectedStatus of
          Nothing -> False
          Just expected ->
            case statusEntries of
              [(lineNumber, _)] -> atMay (phaseRawLines phase) (lineNumber - 1) == Just ("**Status**: " <> expected)
              _ -> False
     in [ finding
            "PLAN-SPRINT-IDENTITY"
            (phasePath phase)
            ("sprint heading has no exact current-phase ordinal: " <> Text.strip heading)
        | ordinal == Nothing
        ]
          <> [ finding
                 "PLAN-SPRINT-STATUS"
                 (phasePath phase)
                 ( Text.strip heading
                     <> " must contain exactly the reviewed reset status "
                     <> maybe "for a valid sprint ordinal" ("'" <>) ((<> "'") <$> expectedStatus)
                 )
             | case expectedStatus of
                 Just expected -> statuses /= [expected] || not rawStatusIsCanonical || not (null bareStatusClaims)
                 Nothing -> True
             ]

isBareCurrentStatusClaim :: Text -> Bool
isBareCurrentStatusClaim line =
  normalizedWord `elem` ["active", "blocked", "done", "validated", "complete", "completed"]
    && (Text.null remainder || Text.head remainder `elem` ['.', ':', '-', '–', '—'])
 where
  withoutIcon = stripStatusIcon (Text.strip line)
  (word, rest) = Text.span (not . isSpace) withoutIcon
  normalizedWord = Text.toCaseFold (Text.dropWhileEnd (`elem` ['.', ':']) word)
  remainder = Text.stripStart rest

stripStatusIcon :: Text -> Text
stripStatusIcon value =
  case
      [ Text.stripStart rest
      | icon <- ["✅", "⏸️", "🔄", "❌", "🟢", "🔴"]
      , Just rest <- [Text.stripPrefix icon value]
      ] of
    stripped : _ -> stripped
    [] -> value

sprintSectionsFor :: PhaseDocument -> [(Text, [(Int, Text)])]
sprintSectionsFor phase =
    [ (heading, takeWhile (not . isH2 . snd) (drop (index + 1) (phaseLines phase)))
    | index <- [0 .. length (phaseLines phase) - 1]
    , Just (_, heading) <- [atMay (phaseLines phase) index]
    , "## Sprint " `Text.isPrefixOf` Text.stripStart heading
    ]

parseSprintOrdinal :: Int -> Text -> Maybe Int
parseSprintOrdinal owner heading = do
  remainder <- Text.stripPrefix ("## Sprint " <> showText owner <> ".") (Text.strip heading)
  let (digits, suffix) = Text.span isDigit remainder
  ordinal <- readMaybe (Text.unpack digits)
  if ordinal > 0 && ":" `Text.isPrefixOf` suffix
    then Just ordinal
    else Nothing

expectedSprintStatus :: Int -> Int -> Text
expectedSprintStatus phaseNumberValue sprintNumber
  | phaseNumberValue == 0 && sprintNumber == 1 = "Active — NOT VALIDATED"
  | otherwise = "Blocked — NOT VALIDATED"

canonicalSprintCounts :: Map Int Int
canonicalSprintCounts =
  Map.fromList
    ( [ (0, 8)
      , (1, 8)
      , (2, 6)
      ]
        <> [(phase, 1) | phase <- [3 .. 10]]
        <> [(phase, 2) | phase <- [11 .. 15]]
        <> [(phase, 3) | phase <- [16 .. 19]]
        <> [(phase, 1) | phase <- [20 .. 24]]
        <> [ (25, 4)
           , (26, 5)
           , (27, 4)
           , (28, 4)
           , (29, 5)
           , (30, 3)
           , (31, 4)
           , (32, 2)
           , (33, 3)
           , (34, 9)
           , (35, 4)
           , (36, 4)
           , (37, 3)
           , (38, 3)
           , (39, 3)
           , (40, 3)
           , (41, 3)
           ]
        <> [(phase, 1) | phase <- [42 .. 47]]
        <> [ (48, 5)
           , (49, 4)
           , (50, 4)
           , (51, 5)
           , (52, 5)
           , (53, 5)
           , (54, 5)
           , (55, 4)
           , (56, 4)
           , (57, 3)
           , (58, 5)
           , (59, 5)
           , (60, 3)
           , (61, 4)
           , (62, 3)
           , (63, 4)
           , (64, 4)
           , (65, 4)
           , (66, 1)
           , (67, 5)
           , (68, 1)
           , (69, 4)
           , (70, 1)
           , (71, 4)
           , (72, 1)
           , (73, 3)
           , (74, 2)
           , (75, 4)
           , (76, 1)
           , (77, 4)
           , (78, 5)
           , (79, 2)
           , (80, 8)
           ]
        <> [(phase, 1) | phase <- [81 .. 88]]
        <> [(89, 5)]
        <> [(phase, 1) | phase <- [90 .. 95]]
    )

parseTrackerRows :: Text -> [TrackerRow]
parseTrackerRows contents = mapMaybe parse (map snd (outsideFences contents))
 where
  parse line = case tableCells line of
    number : title : substrate : lane : register : status : contract : _
      | Text.all isDigit number
      , Just parsedNumber <- readMaybe (Text.unpack number) ->
          Just
            TrackerRow
              { trackerNumber = parsedNumber
              , trackerTitle = title
              , trackerSubstrate = substrate
              , trackerLane = lane
              , trackerRegister = register
              , trackerStatus = status
              , trackerContract = contract
              }
    _ -> Nothing

checkTrackerShape :: [TrackerRow] -> [Finding]
checkTrackerShape rows =
  duplicateFindings
    <> missingFindings
    <> extraFindings
    <> statusFindings
 where
  grouped = Map.fromListWith (+) [(trackerNumber row, 1 :: Int) | row <- rows]
  actual = Map.keysSet grouped
  expected = Set.fromList [phaseDomainLowerNumber .. phaseDomainUpperNumber]
  duplicateFindings =
    [ finding "PLAN-TRACKER-DUPLICATE" trackerPath ("tracker repeats Phase " <> showText number)
    | (number, count) <- Map.toAscList grouped
    , count /= 1
    ]
  missingFindings =
    [ finding "PLAN-TRACKER-MISSING" trackerPath ("tracker omits Phase " <> showText number)
    | number <- Set.toAscList (expected Set.\\ actual)
    ]
  extraFindings =
    [ finding "PLAN-TRACKER-EXTRA" trackerPath ("tracker includes out-of-domain Phase " <> showText number)
    | number <- Set.toAscList (actual Set.\\ expected)
    ]
  statusFindings = concatMap checkStatus rows
  checkStatus row =
    let expectedStatus = Policy.resetPhaseStatusText (policyResetStatus (trackerNumber row))
     in [ finding
            "PLAN-TRACKER-STATUS"
            trackerPath
            ("Phase " <> showText (trackerNumber row) <> " tracker status must equal '" <> expectedStatus <> "'")
        | Text.strip (trackerStatus row) /= expectedStatus
        ]
          <> [ finding
                 "PLAN-TRACKER-STATUS"
                 trackerPath
                 ("Phase " <> showText (trackerNumber row) <> " tracker status carries a forbidden Done marker")
             | "Done" `Text.isInfixOf` trackerStatus row || "✅" `Text.isInfixOf` trackerStatus row
             ]

checkTrackerJoin :: Map Int PhaseDocument -> [TrackerRow] -> [Finding]
checkTrackerJoin phases rows = concatMap checkRow rows
 where
  checkRow row = case Map.lookup (trackerNumber row) phases of
    Nothing -> []
    Just phase ->
      titleFinding phase row
        <> contractFinding phase row
        <> projectionFinding phase row "Substrate" trackerSubstrate
        <> projectionFinding phase row "Lane" trackerLane
        <> projectionFinding phase row "Register" trackerRegister
  titleFinding phase row =
    [ finding
        "PLAN-TRACKER-TITLE"
        trackerPath
        ("Phase " <> showText (trackerNumber row) <> " tracker name differs from its H1 title")
    | phaseTitle phase /= Just (trackerTitle row)
    ]
  contractFinding phase row =
    let (targets, linkProblems) = markdownTargets (trackerContract row)
        resolved = map (resolveFrom trackerPath) targets
     in [ finding
            "PLAN-TRACKER-CONTRACT"
            trackerPath
            ("Phase " <> showText (trackerNumber row) <> " must contain one structurally valid link to " <> Text.pack (phasePath phase))
        | not (null linkProblems) || resolved /= [phasePath phase]
        ]
  projectionFinding phase row field accessor =
    case Map.findWithDefault [] field (phaseFields phase) of
      [value] ->
        [ finding
            "PLAN-TRACKER-PROJECTION"
            trackerPath
            ( "Phase "
                <> showText (trackerNumber row)
                <> " "
                <> field
                <> " differs between tracker and contract"
            )
        | firstToken value /= firstToken (accessor row)
        ]
      _ -> []

firstToken :: Text -> Text
firstToken =
  Text.toCaseFold
    . Text.takeWhile (\character -> not (isSpace character) && character `notElem` ['`', '.', ';', ','])
    . Text.dropWhile (\character -> isSpace character || character == '`')

markdownTargets :: Text -> ([Text], [Text])
markdownTargets = go
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
                         in (laterTargets, "orphan ](" : laterProblems)
                      else case takeBalancedDestination afterMarker of
                        Nothing -> ([], ["unbalanced link destination"])
                        Just (rawTarget, remaining) ->
                          let target = Text.takeWhile (not . isSpace) (Text.strip rawTarget)
                              (laterTargets, laterProblems) = go remaining
                           in if Text.null target
                                then (laterTargets, "empty link destination" : laterProblems)
                                else (target : laterTargets, laterProblems)

takeBalancedDestination :: Text -> Maybe (Text, Text)
takeBalancedDestination = go (1 :: Int) False [] . Text.unpack
 where
  go _ _ _ [] = Nothing
  go depth escaped reversed (character : rest)
    | escaped = go depth False (character : reversed) rest
    | character == '\\' = go depth True (character : reversed) rest
    | character == '(' = go (depth + 1) False (character : reversed) rest
    | character == ')' =
        if depth == 1
          then Just (Text.pack (reverse reversed), Text.pack rest)
          else go (depth - 1) False (character : reversed) rest
    | otherwise = go depth False (character : reversed) rest

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

resolveFrom :: FilePath -> Text -> FilePath
resolveFrom source target =
  normalizePath (takeDirectory source </> Text.unpack pathPart)
 where
  (pathPart, _) = Text.breakOn "#" target

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

normalizePath :: FilePath -> FilePath
normalizePath = dropDot . normalise . map slash
 where
  slash '\\' = '/'
  slash character = character
  dropDot ('.' : '/' : rest) = dropDot rest
  dropDot path = path

sortOnPath :: [PhaseDocument] -> [PhaseDocument]
sortOnPath = sortByPath
 where
  sortByPath [] = []
  sortByPath (first : rest) =
    sortByPath [value | value <- rest, phasePath value <= phasePath first]
      <> [first]
      <> sortByPath [value | value <- rest, phasePath value > phasePath first]

renderPaths :: [PhaseDocument] -> Text
renderPaths = Text.intercalate ", " . map (Text.pack . phasePath) . sortOnPath

formatPhase :: Int -> Text
formatPhase number
  | number < 10 = "0" <> showText number
  | otherwise = showText number

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

atMay :: [value] -> Int -> Maybe value
atMay values index
  | index < 0 = Nothing
  | otherwise = case drop index values of
      value : _ -> Just value
      [] -> Nothing

showText :: Show value => value -> Text
showText = Text.pack . show

trackerPath :: FilePath
trackerPath = "DEVELOPMENT_PLAN/README.md"

policyOrdering :: Policy.OrderingContract
policyOrdering = Policy.orderingContract Policy.canonicalPolicyContract

policyStatusReset :: Policy.StatusResetContract
policyStatusReset = Policy.statusResetContract Policy.canonicalPolicyContract

policyResetStatus :: Int -> Policy.ResetPhaseStatus
policyResetStatus number
  | number == phaseDomainLowerNumber = Policy.phaseZeroResetStatus policyStatusReset
  | otherwise = Policy.laterPhaseResetStatus policyStatusReset

phaseDomainLowerNumber :: Int
phaseDomainLowerNumber = Policy.phaseOrdinalNumber (Policy.phaseDomainLower policyOrdering)

phaseDomainUpperNumber :: Int
phaseDomainUpperNumber = Policy.phaseOrdinalNumber (Policy.phaseDomainUpper policyOrdering)

phaseDomainLabel :: Text
phaseDomainLabel = showText phaseDomainLowerNumber <> ".." <> showText phaseDomainUpperNumber

policyPredecessorNumber :: Int -> Int
policyPredecessorNumber number = case Policy.predecessorRule policyOrdering of
  Policy.ImmediateNumericPredecessor -> number - 1
