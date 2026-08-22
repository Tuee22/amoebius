{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.PhaseContract
  ( checkPhaseAndTracker
  , checkPhaseContractStructure
  , checkPhaseContracts
  ) where

import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding
  , finding
  , observation
  )
import Data.Char (isAlphaNum, isDigit, isSpace)
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
        , observation "unresolved-marker-cell-count" (showText unresolvedMarkerCount)
        , observation "missing-marker-cell-count" (showText missingMarkerCount)
        , observation "refusal-marker-cell-count" (showText refusalMarkerCount)
        ]
    , checkFindings =
        phaseDomainFindings
          <> concatMap checkPhaseStructure (Map.elems phases)
          <> concatMap (checkDependency phases) (Map.elems phases)
          <> concatMap checkGate (Map.elems phases)
          <> concatMap checkSprintStatuses (Map.elems phases)
          <> trackerFindings
          <> checkTrackerJoin phases trackerRows
          <> checkPhaseFortyNine phases trackerRows
          <> checkPrehardwareBoundary phases
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
  expectedNumbers = Set.fromList [0 .. 95]
  actualNumbers = Map.keysSet phases
  missingNumbers = Set.toAscList (expectedNumbers Set.\\ actualNumbers)
  extraNumbers = Set.toAscList (actualNumbers Set.\\ expectedNumbers)
  phaseDomainFindings =
    duplicatePhaseFindings
      <> [finding "PLAN-PHASE-MISSING" "DEVELOPMENT_PLAN/" ("missing Phase " <> showText number) | number <- missingNumbers]
      <> [finding "PLAN-PHASE-EXTRA" (phasePath phase) "phase ordinal lies outside the closed 0..95 domain" | number <- extraNumbers, Just phase <- [Map.lookup number phases]]
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
  expectedStatus = if number == 0 then "🔄 Active — NOT VALIDATED." else "⏸️ Blocked — NOT VALIDATED."
  statusFindings =
    [ finding
        "PLAN-PHASE-STATUS"
        path
        ("Phase Status must be exactly '" <> expectedStatus <> "'")
    | statuses /= [expectedStatus]
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
      | phaseNumber phase == 0 ->
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
        expectedPath = phasePath <$> Map.lookup (number - 1) phases
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
            ("Depends on must contain only one link, to immediate Phase " <> showText (number - 1))
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
    <> semanticRowFindings
 where
  path = phasePath phase
  number = phaseNumber phase
  rows = phaseGateRows phase
  keys = map fst rows
  rowMap = Map.fromList rows
  commandText = "pb validate phase " <> formatPhase number
  expectedCommand = "`" <> commandText <> "`"
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
          ("Command row must name exactly one canonical " <> expectedCommand <> " and no Python/tool runner")
      | validationCommandSpans value /= [(1, commandText)]
          || countOccurrences expectedCommand value /= 1
          || "python" `Text.isInfixOf` Text.toCaseFold value
          || "tools/" `Text.isInfixOf` Text.toCaseFold value
      ]
    Nothing -> []
  summaryCommandFindings = case Map.findWithDefault [] "Gate" (phaseFields phase) of
    [value] ->
      [ finding
          "PLAN-GATE-SUMMARY-COMMAND"
          path
          ("Gate summary must name exactly one canonical " <> expectedCommand <> " and remain NOT VALIDATED")
      | validationCommandSpans value /= [(1, commandText)]
          || countOccurrences expectedCommand value /= 1
          || not ("NOT VALIDATED" `Text.isInfixOf` value)
      ]
    _ -> []
  semanticRowFindings =
    requireRow "Residue" "UNVERIFIED" "Residue must explicitly retain UNVERIFIED layers"
      <> requireRow "Human authority" "human-only" "Human authority must be human-only"
      <> predecessorRow
  requireRow key token detail = case Map.lookup key rowMap of
    Just value -> [finding "PLAN-GATE-SEMANTICS" path detail | not (token `Text.isInfixOf` value)]
    Nothing -> []
  predecessorRow = case Map.lookup "Predecessor" rowMap of
    Just value
      | number == 0 -> [finding "PLAN-GATE-PREDECESSOR" path "Phase-0 Predecessor row must name genesis" | not ("genesis" `Text.isInfixOf` Text.toCaseFold value)]
      | otherwise ->
          [ finding
              "PLAN-GATE-PREDECESSOR"
              path
              ("Predecessor row must name immediate Phase " <> showText (number - 1))
          | not (phaseReference (number - 1) value)
          ]
    Nothing -> []

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

phaseReference :: Int -> Text -> Bool
phaseReference number value =
  any (`boundedTokenIn` value) ["Phase " <> formatPhase number, "phase " <> formatPhase number]

boundedTokenIn :: Text -> Text -> Bool
boundedTokenIn token source = any matchesAt [0 .. Text.length source]
 where
  matchesAt offset =
    let (before, suffix) = Text.splitAt offset source
        after = Text.drop (Text.length token) suffix
        leftBoundary = case Text.unsnoc before of
          Nothing -> True
          Just (_, character) -> not (isAlphaNum character)
        rightBoundary = case Text.uncons after of
          Nothing -> True
          Just (character, _) -> not (isDigit character)
     in token `Text.isPrefixOf` suffix && leftBoundary && rightBoundary

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

checkSprintStatuses :: PhaseDocument -> [Finding]
checkSprintStatuses phase = concatMap checkSection sprintSections
 where
  sprintSections =
    [ (heading, takeWhile (not . isH2 . snd) (drop (index + 1) (phaseLines phase)))
    | index <- [0 .. length (phaseLines phase) - 1]
    , Just (_, heading) <- [atMay (phaseLines phase) index]
    , "## Sprint " `Text.isPrefixOf` Text.stripStart heading
    ]
  checkSection (heading, body) =
    let statuses =
          [ Text.strip value
          | (_, line) <- body
          , Just value <- [Text.stripPrefix "**Status**:" line]
          ]
        expectedPrefix = "## Sprint " <> showText (phaseNumber phase) <> "."
     in [ finding
            "PLAN-SPRINT-IDENTITY"
            (phasePath phase)
            ("sprint heading belongs to another phase: " <> Text.strip heading)
        | not (expectedPrefix `Text.isPrefixOf` Text.strip heading)
        ]
          <> [ finding
                 "PLAN-SPRINT-STATUS"
                 (phasePath phase)
                 (Text.strip heading <> " must contain exactly one non-Done status carrying NOT VALIDATED")
             | case statuses of
                 [status] ->
                   not ("NOT VALIDATED" `Text.isInfixOf` status)
                     || "Done" `Text.isInfixOf` status
                     || "✅" `Text.isInfixOf` status
                 _ -> True
             ]

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
  expected = Set.fromList [0 .. 95]
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
    let expectedStatus = if trackerNumber row == 0 then "🔄 Active — NOT VALIDATED" else "⏸️ Blocked — NOT VALIDATED"
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

checkPhaseFortyNine :: Map Int PhaseDocument -> [TrackerRow] -> [Finding]
checkPhaseFortyNine phases trackerRows =
  case Map.lookup 49 phases of
    Nothing -> []
    Just phase ->
      claimFindings phase
        <> subjectFindings phase
        <> fieldFindings phase
        <> trackerNameFindings
 where
  claimFindings phase =
    case gateValue "Claim" phase of
      Just claim ->
        [ finding
            "PLAN-PHASE49-SPINE"
            (phasePath phase)
            "Phase 49 Claim must contain the complete ordered decode-to-fake-apply semantic spine"
        | not (containsInOrder phaseFortyNineStages (Text.toCaseFold claim))
        ]
      Nothing -> []
  subjectFindings phase =
    case gateValue "Subject" phase of
      Just subject ->
        [ finding
            "PLAN-PHASE49-SUBJECT"
            (phasePath phase)
            ("Phase 49 Subject omits production spine module " <> moduleName)
        | moduleName <- phaseFortyNineModules
        , not (moduleName `Text.isInfixOf` subject)
        ]
      Nothing -> []
  fieldFindings phase =
    concat
      [ exactField phase "Substrate" "none"
      , exactField phase "Lane" "none"
      , exactField phase "Register" "2"
      ]
  trackerNameFindings =
    [ finding
        "PLAN-PHASE49-TRACKER"
        trackerPath
        "Phase 49 tracker row must identify the no-hardware DSL promotion barrier"
    | row <- trackerRows
    , trackerNumber row == 49
    , not ("No-hardware DSL promotion barrier" `Text.isInfixOf` trackerTitle row)
    ]

phaseFortyNineStages :: [Text]
phaseFortyNineStages =
  [ "decode"
  , "legality"
  , "bind/expand"
  , "plan/resolve"
  , "provision"
  , "renderall"
  , "plan"
  , "dry-run"
  , "fake-apply"
  ]

phaseFortyNineModules :: [Text]
phaseFortyNineModules =
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

checkPrehardwareBoundary :: Map Int PhaseDocument -> [Finding]
checkPrehardwareBoundary phases =
  concatMap checkNoHardware [phase | (number, phase) <- Map.toAscList phases, number <= 51]
    <> phase52Findings
 where
  checkNoHardware phase =
    exactField phase "Substrate" "none"
      <> exactField phase "Lane" "none"
      <> [ finding
             "PLAN-PREHARDWARE-REGISTER"
             (phasePath phase)
             "Phases 0-51 may use only no-register, Register 1, or Register 2 before hardware begins"
         | fieldToken "Register" phase `notElem` [Just "—", Just "1", Just "2"]
         ]
  phase52Findings = case Map.lookup 52 phases of
    Nothing -> []
    Just phase ->
      [ finding
          "PLAN-HARDWARE-CUT"
          (phasePath phase)
          "Phase 52 must be the first hardware-bearing contract and use Register 3"
      | fieldToken "Substrate" phase == Just "none" || fieldToken "Register" phase /= Just "3"
      ]

exactField :: PhaseDocument -> Text -> Text -> [Finding]
exactField phase name wanted =
  [ finding
      "PLAN-PREHARDWARE-FIELD"
      (phasePath phase)
      (name <> " must begin with the canonical value '" <> wanted <> "'")
  | fieldToken name phase /= Just wanted
  ]

fieldToken :: Text -> PhaseDocument -> Maybe Text
fieldToken name phase = case Map.findWithDefault [] name (phaseFields phase) of
  [value] -> Just (firstToken value)
  _ -> Nothing

gateValue :: Text -> PhaseDocument -> Maybe Text
gateValue key phase = case [value | (rowKey, value) <- phaseGateRows phase, rowKey == key] of
  [value] -> Just value
  _ -> Nothing

firstToken :: Text -> Text
firstToken =
  Text.toCaseFold
    . Text.takeWhile (\character -> not (isSpace character) && character `notElem` ['`', '.', ';', ','])
    . Text.dropWhile (\character -> isSpace character || character == '`')

containsInOrder :: [Text] -> Text -> Bool
containsInOrder [] _ = True
containsInOrder (wanted : rest) source =
  let (_, match) = Text.breakOn wanted source
   in not (Text.null match)
        && containsInOrder rest (Text.drop (Text.length wanted) match)

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
