{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.Legacy
  ( ActiveRegister
  , LegacyId (..)
  , LegacyRow
  , RegisterProblem (..)
  , activeRegisterPath
  , activeRegisterRows
  , activeRegisterFromSnapshot
  , laterOwnedSourceIds
  , legacyCheck
  , legacyClosurePredicate
  , legacyObservation
  , legacyOwnerPhase
  , legacyReplacement
  , legacyRowId
  , parseActiveRegister
  , parseSourceDebtId
  , qualifySourceClosure
  , renderRegisterProblem
  ) where

import Amoebius.Validation.SourceClosure
  ( IndexEntry (..)
  , SourceClosure
  , SourceDebtId (..)
  , SourceSnapshot (..)
  , TrackedEntry (..)
  , classifySnapshot
  , registeredSourceIds
  , renderSourceDebtId
  , sourceDebtFingerprint
  , sourceDebtPathCount
  , sourceClosureCheck
  )
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding
  , checkFindings
  , checkObservations
  , finding
  , observation
  )
import Data.ByteString (ByteString)
import Data.List (sortOn)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import System.FilePath (takeFileName)

newtype LegacyId = LegacyId
  { unLegacyId :: Text
  }
  deriving (Eq, Ord, Show)

data LegacyRow = LegacyRow
  { legacyRowId :: LegacyId
  , legacyObservation :: Text
  , legacyOwnerPhase :: Int
  , legacyReplacement :: Text
  , legacyClosurePredicate :: Text
  }
  deriving (Eq, Ord, Show)

data ActiveRegister = ActiveRegister
  { activeRegisterPath :: FilePath
  , activeRegisterRows :: Map LegacyId LegacyRow
  }
  deriving (Eq, Show)

data RegisterProblem
  = ActiveRegisterMissing FilePath
  | MultipleActiveRegisters FilePath Int
  | AdditionalActiveRegisterTracked FilePath
  | ArchiveRegisterTracked FilePath
  | RegisterNotUtf8 FilePath
  | RegisterHasNoActiveRows FilePath
  | MalformedRegisterRow Int Text
  | InvalidLegacyId Int Text
  | DuplicateLegacyId Text
  | MissingLegacyOwner Int Text
  | InvalidLegacyOwner Int Text
  | MissingLegacyReplacement Int Text
  | MissingExecutablePredicate Int Text
  | HistoricalNarrativeInActiveRow Int Text
  | UnsupportedLegacyId Text
  | MissingCanonicalLegacyRow Text
  | LegacyOwnerMismatch Text Int Int
  | UnknownSourceDebtId Text
  deriving (Eq, Ord, Show)

canonicalRegisterPath :: FilePath
canonicalRegisterPath = "DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md"

archiveRegisterName :: FilePath
archiveRegisterName = "legacy_tracking_for_deletion_archive.md"

-- | Locate and parse the one register from the supplied Git snapshot.  This
-- never falls back to worktree bytes.  Any archive-named tracked file is a
-- structural error even when the canonical register is otherwise well formed.
activeRegisterFromSnapshot :: SourceSnapshot -> Either [RegisterProblem] ActiveRegister
activeRegisterFromSnapshot snapshot =
  case canonicalEntries of
    [] -> Left (nameProblems <> archiveProblems <> [ActiveRegisterMissing canonicalRegisterPath])
    [entry] ->
      case parseActiveRegister (trackedBytes entry) of
        Left problems -> Left (nameProblems <> archiveProblems <> problems)
        Right register ->
          let problems = nameProblems <> archiveProblems <> inventoryProblems register
           in if null problems then Right register else Left problems
    duplicateEntries -> Left (nameProblems <> archiveProblems <> [MultipleActiveRegisters canonicalRegisterPath (length duplicateEntries)])
  where
    entries = snapshotEntries snapshot
    pathOf = indexPath . trackedIndex
    canonicalEntries = filter ((== canonicalRegisterPath) . pathOf) entries
    nameProblems =
      [ AdditionalActiveRegisterTracked (pathOf entry)
      | entry <- entries
      , takeFileName (pathOf entry) == takeFileName canonicalRegisterPath
      , pathOf entry /= canonicalRegisterPath
      ]
    archiveProblems =
      [ ArchiveRegisterTracked (pathOf entry)
      | entry <- entries
      , takeFileName (pathOf entry) == archiveRegisterName
      ]
    inventoryProblems register =
      [ MissingCanonicalLegacyRow (unLegacyId identifier)
      | identifier <- Set.toAscList (Map.keysSet canonicalLegacyOwners Set.\\ Map.keysSet (activeRegisterRows register))
      ]

-- | Parse the active-only Markdown table.  The parser is intentionally narrow:
-- an LTD row must be one physical four-cell table row with a stable identifier,
-- exact owner marker, non-empty replacement, and a visibly code-shaped
-- reader contract. This parser does not execute that Markdown; the canonical
-- Haskell inventory and gate integration own authority.
parseActiveRegister :: ByteString -> Either [RegisterProblem] ActiveRegister
parseActiveRegister bytes =
  case TextEncoding.decodeUtf8' bytes of
    Left _ -> Left [RegisterNotUtf8 canonicalRegisterPath]
    Right document ->
      let candidates =
            [ (number, line)
            | (number, line) <- zip [1 ..] (Text.lines document)
            , "| `LTD-" `Text.isPrefixOf` Text.strip line
            ]
          parsed = map (uncurry parseLegacyRow) candidates
          rowProblems = concat [rowErrors | Left rowErrors <- parsed]
          rows = [row | Right row <- parsed]
          duplicateProblems =
            [ DuplicateLegacyId (unLegacyId identifier)
            | identifier <- duplicates (map legacyRowId rows)
            ]
          unknownSourceProblems =
            [ UnknownSourceDebtId (unLegacyId (legacyRowId row))
            | row <- rows
            , "LTD-SRC-" `Text.isPrefixOf` unLegacyId (legacyRowId row)
            , unLegacyId (legacyRowId row) /= "LTD-SRC-000"
            , parseSourceDebtId (legacyRowId row) == Nothing
            ]
          supportProblems = concatMap supportedRowProblems rows
          noRows = [RegisterHasNoActiveRows canonicalRegisterPath | null candidates]
          problems = noRows <> rowProblems <> duplicateProblems <> unknownSourceProblems <> supportProblems
       in if null problems
            then
              Right
                ActiveRegister
                  { activeRegisterPath = canonicalRegisterPath
                  , activeRegisterRows = Map.fromList [(legacyRowId row, row) | row <- rows]
                  }
            else Left problems

supportedRowProblems :: LegacyRow -> [RegisterProblem]
supportedRowProblems row =
  case Map.lookup (legacyRowId row) canonicalLegacyOwners of
    Nothing -> [UnsupportedLegacyId (unLegacyId (legacyRowId row))]
    Just expected
      | expected == legacyOwnerPhase row -> []
      | otherwise ->
          [ LegacyOwnerMismatch
              (unLegacyId (legacyRowId row))
              expected
              (legacyOwnerPhase row)
          ]

canonicalLegacyOwners :: Map LegacyId Int
canonicalLegacyOwners =
  Map.fromList
    [ owner "LTD-SRC-000" 0
    , owner "LTD-SRC-001" 47
    , owner "LTD-SRC-002" 25
    , owner "LTD-SRC-003" 26
    , owner "LTD-SRC-004" 46
    , owner "LTD-SRC-005" 47
    , owner "LTD-SRC-006" 47
    , owner "LTD-SRC-007" 1
    , owner "LTD-SRC-008" 0
    , owner "LTD-SRC-009" 1
    , owner "LTD-META-001" 2
    , owner "LTD-VAL-001" 0
    , owner "LTD-VAL-002" 0
    , owner "LTD-VAL-003" 0
    , owner "LTD-VAL-004" 0
    , owner "LTD-VAL-005" 49
    , owner "LTD-VAL-006" 47
    , owner "LTD-DOC-001" 27
    , owner "LTD-NAME-001" 2
    , owner "LTD-HOST-001" 51
    , owner "LTD-HOST-002" 51
    , owner "LTD-IMG-001" 56
    , owner "LTD-RUN-001" 55
    , owner "LTD-SEED-001" 91
    , owner "LTD-SEED-002" 93
    ]
  where
    owner identifier phaseNumber = (LegacyId identifier, phaseNumber)

parseLegacyRow :: Int -> Text -> Either [RegisterProblem] LegacyRow
parseLegacyRow lineNumber line =
  case tableCells line of
    Nothing -> Left [MalformedRegisterRow lineNumber "expected exactly four table cells"]
    Just [idCell, observationCell, ownerCell, predicateCell] ->
      let identifierResult = parseLegacyId lineNumber idCell
          ownerResult = parseOwner lineNumber ownerCell
          observationValue = Text.strip observationCell
          predicateValue = Text.strip predicateCell
          observationProblems =
            [MalformedRegisterRow lineNumber "current observation is empty" | Text.null observationValue]
          predicateProblems =
            [ MissingExecutablePredicate lineNumber (identifierText identifierResult)
            | Text.null predicateValue || not ("`" `Text.isInfixOf` predicateValue)
            ]
          historicalProblems =
            [ HistoricalNarrativeInActiveRow lineNumber (identifierText identifierResult)
            | containsHistoricalStatus (observationValue <> " " <> ownerCell <> " " <> predicateValue)
            ]
          accumulated =
            errors identifierResult
              <> errors ownerResult
              <> observationProblems
              <> predicateProblems
              <> historicalProblems
       in if not (null accumulated)
            then Left accumulated
            else case (identifierResult, ownerResult) of
              (Right identifier, Right (owner, replacement)) ->
                Right
                  LegacyRow
                    { legacyRowId = identifier
                    , legacyObservation = observationValue
                    , legacyOwnerPhase = owner
                    , legacyReplacement = replacement
                    , legacyClosurePredicate = predicateValue
                    }
              _ -> Left [MalformedRegisterRow lineNumber "row parser did not produce its fields"]
    Just _ -> Left [MalformedRegisterRow lineNumber "expected exactly four table cells"]

tableCells :: Text -> Maybe [Text]
tableCells line =
  case Text.splitOn "|" (Text.strip line) of
    leading : idCell : observationCell : ownerCell : predicateCell : [trailing]
      | Text.null (Text.strip leading) && Text.null (Text.strip trailing) ->
          Just (map Text.strip [idCell, observationCell, ownerCell, predicateCell])
    _ -> Nothing

parseLegacyId :: Int -> Text -> Either [RegisterProblem] LegacyId
parseLegacyId lineNumber cell =
  let stripped = Text.strip cell
      value = Text.dropAround (== '`') stripped
   in if stripped == "`" <> value <> "`" && validLegacyId value
        then Right (LegacyId value)
        else Left [InvalidLegacyId lineNumber stripped]

validLegacyId :: Text -> Bool
validLegacyId value =
  case Text.splitOn "-" value of
    ["LTD", domainName, ordinal] ->
      not (Text.null domainName)
        && Text.all (\character -> character >= 'A' && character <= 'Z') domainName
        && Text.length ordinal == 3
        && Text.all (\character -> character >= '0' && character <= '9') ordinal
    _ -> False

parseOwner :: Int -> Text -> Either [RegisterProblem] (Int, Text)
parseOwner lineNumber cell =
  case Text.stripPrefix "**Phase " (Text.strip cell) of
    Nothing -> Left [MissingLegacyOwner lineNumber (Text.strip cell)]
    Just afterPrefix ->
      let (digits, afterDigits) = Text.span (\character -> character >= '0' && character <= '9') afterPrefix
       in case Text.stripPrefix ".**" afterDigits of
            Nothing -> Left [InvalidLegacyOwner lineNumber (Text.strip cell)]
            Just replacementWithSpace ->
              case decimal digits of
                Nothing -> Left [InvalidLegacyOwner lineNumber (Text.strip cell)]
                Just owner
                  | owner < 0 || owner > 95 -> Left [InvalidLegacyOwner lineNumber (Text.strip cell)]
                  | Text.null (Text.strip replacementWithSpace) ->
                      Left [MissingLegacyReplacement lineNumber (Text.strip cell)]
                  | otherwise -> Right (owner, Text.strip replacementWithSpace)

decimal :: Text -> Maybe Int
decimal value
  | Text.null value = Nothing
  | Text.all (\character -> character >= '0' && character <= '9') value =
      case reads (Text.unpack value) of
        [(number, "")] -> Just number
        _ -> Nothing
  | otherwise = Nothing

containsHistoricalStatus :: Text -> Bool
containsHistoricalStatus value =
  any
    (`Text.isInfixOf` Text.toLower value)
    [ "historical completion claim"
    , "status: done"
    , "status: validated"
    , "closed on "
    , "completed on "
    , "archived on "
    ]

parseSourceDebtId :: LegacyId -> Maybe SourceDebtId
parseSourceDebtId (LegacyId value)
  | value == renderSourceDebtId SourceTools = Just SourceTools
  | value == renderSourceDebtId SourceDhall = Just SourceDhall
  | value == renderSourceDebtId SourceProto = Just SourceProto
  | value == renderSourceDebtId SourceUi = Just SourceUi
  | value == renderSourceDebtId SourcePulumi = Just SourcePulumi
  | value == renderSourceDebtId SourceTest = Just SourceTest
  | value == renderSourceDebtId SourceProbe = Just SourceProbe
  | value == renderSourceDebtId SourcePb = Just SourcePb
  | value == renderSourceDebtId SourceVendor = Just SourceVendor
  | otherwise = Nothing

-- | The typed aggregate which a Phase-N caller may carry as observed, explicitly
-- later-owned debt.  Missing rows are deliberately absent here and become
-- findings in 'qualifySourceClosure'; this value is not itself a verdict.
laterOwnedSourceIds :: Int -> ActiveRegister -> SourceClosure -> Set SourceDebtId
laterOwnedSourceIds candidatePhase register closure =
  Set.fromList
    [ identifier
    | identifier <- Set.toAscList matched
    , Just row <- [Map.lookup identifier rows]
    , legacyOwnerPhase row > candidatePhase
    ]
  where
    rows =
      Map.fromList
        [ (identifier, row)
        | row <- Map.elems (activeRegisterRows register)
        , Just identifier <- [parseSourceDebtId (legacyRowId row)]
        ]
    matched = registeredSourceIds closure `Set.intersection` Map.keysSet rows

-- | Join the classifier's observed registered debt to the active register.
-- Matching rows owned strictly after the candidate phase are observations.
-- Missing/stale rows, unregistered paths, the Phase-0 framework row, or a row
-- already due at the candidate phase are findings.
qualifySourceClosure :: Int -> ActiveRegister -> SourceClosure -> CheckResult
qualifySourceClosure candidatePhase register closure =
  CheckResult
    { checkName = "legacy-source-closure"
    , checkObservations =
        checkObservations sourceCheck
          <> [ observation "legacy.active-row-count" (Text.pack (show (Map.size rows)))
             , observation "legacy.candidate-phase" (Text.pack (show candidatePhase))
             , observation "legacy.later-owned-source-ids" (renderLater laterRows)
             ]
    , checkFindings =
        checkFindings sourceCheck
          <> sourceInventoryFindings
          <> invalidPhaseFinding
          <> frameworkFindings
          <> missingFindings
          <> staleFindings
          <> dueFindings
          <> otherDueFindings
    }
  where
    sourceCheck = sourceClosureCheck closure
    sourceInventoryFindings =
      [ finding
          "LEGACY-SOURCE-INVENTORY"
          (activeRegisterPath register)
          ( renderSourceDebtId identifier
              <> " differs from the frozen Haskell baseline: expected count="
              <> Text.pack (show expectedCount)
              <> " digest="
              <> expectedDigest
              <> ", observed count="
              <> Text.pack (show (sourceDebtPathCount identifier closure))
              <> " digest="
              <> sourceDebtFingerprint identifier closure
          )
      | (identifier, (expectedCount, expectedDigest)) <- Map.toAscList canonicalSourceBaselines
      , sourceDebtPathCount identifier closure /= expectedCount
          || sourceDebtFingerprint identifier closure /= expectedDigest
      ]
    rows = activeRegisterRows register
    observed = registeredSourceIds closure
    sourceRows =
      Map.fromList
        [ (identifier, row)
        | row <- Map.elems rows
        , Just identifier <- [parseSourceDebtId (legacyRowId row)]
        ]
    registered = Map.keysSet sourceRows
    missing = Set.toAscList (observed `Set.difference` registered)
    stale = Set.toAscList (registered `Set.difference` observed)
    matched = Set.toAscList (observed `Set.intersection` registered)
    laterRows =
      [ (identifier, row)
      | identifier <- Set.toAscList (laterOwnedSourceIds candidatePhase register closure)
      , Just row <- [Map.lookup identifier sourceRows]
      ]
    dueRows =
      [ (identifier, row)
      | identifier <- matched
      , Just row <- [Map.lookup identifier sourceRows]
      , legacyOwnerPhase row <= candidatePhase
      ]
    otherDueRows =
      [ row
      | row <- Map.elems rows
      , legacyOwnerPhase row <= candidatePhase
      , legacyRowId row /= LegacyId "LTD-SRC-000"
      , parseSourceDebtId (legacyRowId row) == Nothing
      ]
    frameworkRows = Map.lookup (LegacyId "LTD-SRC-000") rows
    invalidPhaseFinding =
      [finding "LEGACY-PHASE" (activeRegisterPath register) "candidate phase must be non-negative" | candidatePhase < 0]
    frameworkFindings = case frameworkRows of
      Nothing -> []
      Just row
        | legacyOwnerPhase row <= candidatePhase ->
            [ finding
                "LEGACY-PHASE0-OWNED"
                (activeRegisterPath register)
                "LTD-SRC-000 remains active and is due at Phase 0"
            ]
        | otherwise -> []
    missingFindings =
      [ finding
          "LEGACY-SOURCE-ROW-MISSING"
          (activeRegisterPath register)
          (renderSourceDebtId identifier <> " is observed but has no active register row")
      | identifier <- missing
      ]
    staleFindings =
      [ finding
          "LEGACY-SOURCE-ROW-STALE"
          (activeRegisterPath register)
          (renderSourceDebtId identifier <> " is active but its classifier set is empty")
      | identifier <- stale
      ]
    dueFindings =
      [ finding
          "LEGACY-SOURCE-OWNER-DUE"
          (activeRegisterPath register)
          ( renderSourceDebtId identifier
              <> " is owned by Phase "
              <> Text.pack (show (legacyOwnerPhase row))
              <> " and remains present"
          )
      | (identifier, row) <- dueRows
      ]
    otherDueFindings =
      [ finding
          "LEGACY-ACTIVE-ROW-DUE"
          (activeRegisterPath register)
          ( unLegacyId (legacyRowId row)
              <> " remains active at its owner, Phase "
              <> Text.pack (show (legacyOwnerPhase row))
          )
      | row <- sortOn legacyRowId otherDueRows
      ]

-- | Frozen inventory of the migration families observed by the 2026-08-22
-- reset. A candidate may remove a family only together with its owner-phase
-- Haskell closure change; adding, renaming, changing mode, or changing bytes
-- cannot hide behind an already-open Markdown row.
canonicalSourceBaselines :: Map SourceDebtId (Int, Text)
canonicalSourceBaselines =
  Map.fromList
    [ baseline SourceTools 237 "b756b203049bb59e62bd9795b5a36e37840e8599b28b01c2bf3aa8c41cf3e534"
    , baseline SourceDhall 279 "633e2198ba565cab862fad019fc9de2e7cbe784d7c781468e911322b4d0bed31"
    , baseline SourceProto 1 "ad6293590c8d79e1fe385497bd891d2d7351a46f8f34907e12cef4b46eafca1e"
    , baseline SourceUi 16 "d5c12f81a7f91385b460824539aabd94c0c3e1885ef8ddf2ec9190ee12d5d05d"
    , baseline SourcePulumi 1 "b5e5b10785f0d371b3cfa9ff4d9e5dd25360677c3c5d8415475ba61c50855982"
    , baseline SourceTest 890 "1080ced8d4adc45eb3368cd61e4bdb84a68ddd4b2c24179c6975f085672c3899"
    , baseline SourceProbe 7 "233dfc3539480eacc10e4e5c284d69893c31c93975fc7945670424751d961800"
    , baseline SourcePb 15 "116e1cb2adf61ebd20ea70c3f384f5b1bbe6916aec04239c13224e3cd1ddfa3c"
    , baseline SourceVendor 28 "fe32b81f2231b370fe28959f49661861f4644d774b1058cca827818a04439acd"
    ]
 where
  baseline identifier count digest = (identifier, (count, digest))

renderLater :: [(SourceDebtId, LegacyRow)] -> Text
renderLater rows =
  Text.intercalate
    ","
    [ renderSourceDebtId identifier <> "@" <> Text.pack (show (legacyOwnerPhase row))
    | (identifier, row) <- sortOn fst rows
    ]

-- | End-to-end pure entry point for an acquired snapshot.  Inline oracle tests
-- can replace any entry or register byte string without a filesystem or Git
-- process and observe the same verdict path used in production.
legacyCheck :: Int -> SourceSnapshot -> CheckResult
legacyCheck candidatePhase snapshot =
  case activeRegisterFromSnapshot snapshot of
    Left problems ->
      let sourceCheck = sourceClosureCheck (classifySnapshot snapshot)
       in CheckResult
            { checkName = "legacy-source-closure"
            , checkObservations = checkObservations sourceCheck
            , checkFindings = checkFindings sourceCheck <> map registerFinding problems
            }
    Right register -> qualifySourceClosure candidatePhase register (classifySnapshot snapshot)

renderRegisterProblem :: RegisterProblem -> Text
renderRegisterProblem problem = case problem of
  ActiveRegisterMissing path -> "active legacy register is missing: " <> Text.pack path
  MultipleActiveRegisters path count ->
    "active legacy register occurs " <> Text.pack (show count) <> " times: " <> Text.pack path
  AdditionalActiveRegisterTracked path -> "additional active legacy register is tracked: " <> Text.pack path
  ArchiveRegisterTracked path -> "archive legacy register is tracked: " <> Text.pack path
  RegisterNotUtf8 path -> "active legacy register is not UTF-8: " <> Text.pack path
  RegisterHasNoActiveRows path -> "active legacy register has no active rows: " <> Text.pack path
  MalformedRegisterRow line detail -> lineDetail line detail
  InvalidLegacyId line identifier -> lineDetail line ("invalid legacy id " <> identifier)
  DuplicateLegacyId identifier -> "duplicate legacy id: " <> identifier
  MissingLegacyOwner line detail -> lineDetail line ("missing exact Phase owner: " <> detail)
  InvalidLegacyOwner line detail -> lineDetail line ("invalid Phase owner: " <> detail)
  MissingLegacyReplacement line detail -> lineDetail line ("missing required replacement: " <> detail)
  MissingExecutablePredicate line identifier ->
    lineDetail line ("missing code-shaped reader contract for required Haskell closure " <> identifier)
  HistoricalNarrativeInActiveRow line identifier ->
    lineDetail line ("historical/status narrative appears in active row " <> identifier)
  UnsupportedLegacyId identifier -> "legacy id has no Haskell check binding: " <> identifier
  MissingCanonicalLegacyRow identifier -> "canonical active legacy row is missing: " <> identifier
  LegacyOwnerMismatch identifier expected actual ->
    identifier
      <> " owner mismatch: expected Phase "
      <> Text.pack (show expected)
      <> ", observed Phase "
      <> Text.pack (show actual)
  UnknownSourceDebtId identifier -> "source debt id has no classifier class: " <> identifier
  where
    lineDetail line detail = "active register line " <> Text.pack (show line) <> ": " <> detail

registerFinding :: RegisterProblem -> Finding
registerFinding problem = finding "LEGACY-REGISTER" canonicalRegisterPath (renderRegisterProblem problem)

identifierText :: Either [RegisterProblem] LegacyId -> Text
identifierText (Right identifier) = unLegacyId identifier
identifierText (Left _) = "<invalid-id>"

errors :: Either [problem] value -> [problem]
errors (Left problems) = problems
errors (Right _) = []

duplicates :: Ord value => [value] -> [value]
duplicates values =
  Map.keys (Map.filter (> (1 :: Int)) (Map.fromListWith (+) [(value, 1 :: Int) | value <- values]))
