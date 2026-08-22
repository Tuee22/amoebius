{-# LANGUAGE OverloadedStrings #-}

module LegacyOracle
  ( runLegacyOracle
  ) where

-- Component diagnostics only. These independently stated examples are not
-- human review, harness qualification, phase validation, or promotion evidence.

import Amoebius.Validation.Legacy
import Amoebius.Validation.SourceClosure
import Amoebius.Validation.Types (CheckResult (..), Finding (..), Observation (..))
import Control.Monad (unless)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteString8
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text

runLegacyOracle :: IO ()
runLegacyOracle =
  finishDiagnostics
    "LegacyOracle"
    ( cleanRegisterProblems
        <> registerRefusalProblems
        <> sourceIdMappingProblems
        <> sourceJoinProblems
        <> dueRowProblems
    )

cleanRegisterProblems :: [String]
cleanRegisterProblems =
  case parseActiveRegister (registerBytes [legacyRowText "LTD-SRC-001" 47]) of
    Left problems -> ["clean active register was refused: " <> show problems]
    Right register ->
      case Map.lookup (LegacyId "LTD-SRC-001") (activeRegisterRows register) of
        Nothing -> ["clean active register omitted LTD-SRC-001"]
        Just row ->
          concat
            [ expectEqual "canonical register path" canonicalPath (activeRegisterPath register)
            , expectEqual "clean row id" (LegacyId "LTD-SRC-001") (legacyRowId row)
            , expectEqual "clean row observation" "LTD-SRC-001 remains present" (legacyObservation row)
            , expectEqual "clean row owner" 47 (legacyOwnerPhase row)
            , expectEqual "clean row replacement" "replace LTD-SRC-001 with Haskell" (legacyReplacement row)
            , expectEqual "clean row predicate" "`close LTD-SRC-001`" (legacyClosurePredicate row)
            ]

registerRefusalProblems :: [String]
registerRefusalProblems =
  concat
    [ expectEqual
        "empty active register"
        (Left [RegisterHasNoActiveRows canonicalPath])
        (parseActiveRegister "# no active rows\n")
    , expectEqual
        "non-UTF8 active register"
        (Left [RegisterNotUtf8 canonicalPath])
        (parseActiveRegister (ByteString.pack [255]))
    , expectProblem
        "duplicate legacy id"
        (== DuplicateLegacyId "LTD-SRC-001")
        (parseActiveRegister (registerBytes [legacyRowText "LTD-SRC-001" 47, legacyRowText "LTD-SRC-001" 47]))
    , expectProblem
        "invalid legacy id"
        (== InvalidLegacyId 3 "`LTD-src-001`")
        (parseActiveRegister (registerBytes [legacyRowText "LTD-src-001" 47]))
    , expectProblem
        "missing exact owner marker"
        (== MissingLegacyOwner 3 "Phase 47 replace")
        (parseActiveRegister (registerBytes [customRow "`LTD-SRC-001`" "present" "Phase 47 replace" "`close`"] ))
    , expectProblem
        "malformed owner"
        (== InvalidLegacyOwner 3 "**Phase x.** replace")
        (parseActiveRegister (registerBytes [customRow "`LTD-SRC-001`" "present" "**Phase x.** replace" "`close`"] ))
    , expectProblem
        "missing replacement"
        (== MissingLegacyReplacement 3 "**Phase 47.**")
        (parseActiveRegister (registerBytes [customRow "`LTD-SRC-001`" "present" "**Phase 47.**" "`close`"] ))
    , expectProblem
        "missing executable predicate"
        (== MissingExecutablePredicate 3 "LTD-SRC-001")
        (parseActiveRegister (registerBytes [customRow "`LTD-SRC-001`" "present" "**Phase 47.** replace" "plain prose"] ))
    , expectProblem
        "empty observation"
        (== MalformedRegisterRow 3 "current observation is empty")
        (parseActiveRegister (registerBytes [customRow "`LTD-SRC-001`" "" "**Phase 47.** replace" "`close`"] ))
    , expectProblem
        "historical narrative in active row"
        (== HistoricalNarrativeInActiveRow 3 "LTD-SRC-001")
        (parseActiveRegister (registerBytes [customRow "`LTD-SRC-001`" "status: done" "**Phase 47.** replace" "`close`"] ))
    , expectProblem
        "canonical owner mismatch"
        (== LegacyOwnerMismatch "LTD-SRC-001" 47 46)
        (parseActiveRegister (registerBytes [legacyRowText "LTD-SRC-001" 46]))
    , expectProblem
        "unsupported legacy identifier"
        (== UnsupportedLegacyId "LTD-OTHER-001")
        (parseActiveRegister (registerBytes [legacyRowText "LTD-OTHER-001" 1]))
    , expectProblem
        "unknown source debt identifier"
        (== UnknownSourceDebtId "LTD-SRC-999")
        (parseActiveRegister (registerBytes [legacyRowText "LTD-SRC-999" 1]))
    , expectEqual
        "canonical active register missing from snapshot"
        (Left [ActiveRegisterMissing canonicalPath])
        (activeRegisterFromSnapshot (snapshot []))
    , expectProblem
        "deleting a canonical row cannot erase its blocker"
        (== MissingCanonicalLegacyRow "LTD-SRC-000")
        (activeRegisterFromSnapshot (snapshot [registerEntry [legacyRowText "LTD-SRC-001" 47]]))
    , expectProblem
        "duplicate canonical active register paths"
        (== MultipleActiveRegisters canonicalPath 2)
        (activeRegisterFromSnapshot (snapshot [registerEntry [legacyRowText "LTD-SRC-001" 47], registerEntry [legacyRowText "LTD-SRC-001" 47]]))
    , expectProblem
        "same active-register basename elsewhere"
        (== AdditionalActiveRegisterTracked "other/legacy_tracking_for_deletion.md")
        ( activeRegisterFromSnapshot
            ( snapshot
                [ registerEntry [legacyRowText "LTD-SRC-001" 47]
                , tracked "other/legacy_tracking_for_deletion.md" "# second register\n"
                ]
            )
        )
    , expectProblem
        "archive register is structurally forbidden"
        (== ArchiveRegisterTracked "DEVELOPMENT_PLAN/legacy_tracking_for_deletion_archive.md")
        ( activeRegisterFromSnapshot
            ( snapshot
                [ registerEntry [legacyRowText "LTD-SRC-001" 47]
                , tracked "DEVELOPMENT_PLAN/legacy_tracking_for_deletion_archive.md" "# archive\n"
                ]
            )
        )
    , expectFindingAt
        "archive snapshot pins register finding locus"
        "LEGACY-REGISTER"
        canonicalPath
        ( legacyCheck
            0
            ( snapshot
                [ registerEntry [legacyRowText "LTD-SRC-001" 47]
                , tracked "DEVELOPMENT_PLAN/legacy_tracking_for_deletion_archive.md" "# archive\n"
                ]
            )
        )
    ]

sourceIdMappingProblems :: [String]
sourceIdMappingProblems =
  concat
    [ expectEqual ("source id mapping " <> Text.unpack identifier) (Just debt) (parseSourceDebtId (LegacyId identifier))
    | (identifier, debt, _) <- sourceDebtCases
    ]
    <> expectEqual "framework row is not a classifier debt id" Nothing (parseSourceDebtId (LegacyId "LTD-SRC-000"))
    <> expectEqual "unknown source id is not mapped" Nothing (parseSourceDebtId (LegacyId "LTD-SRC-999"))

sourceJoinProblems :: [String]
sourceJoinProblems =
  case parseActiveRegister (registerBytes [legacyRowText "LTD-SRC-001" 47]) of
    Left problems -> ["source join register setup failed: " <> show problems]
    Right register ->
      let closure = classifySnapshot (snapshot [tracked "tools/legacy.py" "print('legacy')\n"])
          later = qualifySourceClosure 0 register closure
          laterValues =
            [ observationValue item
            | item <- checkObservations later
            , observationKey item == "legacy.later-owned-source-ids"
            ]
          cleanEndToEnd = legacyCheck 0 (snapshot [registerEntry [legacyRowText "LTD-SRC-001" 47], tracked "tools/legacy.py" "print('legacy')\n"])
       in concat
            [ expectFindingAt "synthetic source inventory cannot become candidate evidence" "LEGACY-SOURCE-INVENTORY" canonicalPath later
            , expectEqual "later-owner observation" ["LTD-SRC-001@47"] laterValues
            , expectEqual "laterOwnedSourceIds is typed and exact" (Set.singleton SourceTools) (laterOwnedSourceIds 0 register closure)
            , expectFindingAt "end-to-end register subset cannot erase canonical rows" "LEGACY-REGISTER" canonicalPath cleanEndToEnd
            , missingSourceRowProblems
            , staleSourceRowProblems
            , expectFindingAt "negative candidate phase" "LEGACY-PHASE" canonicalPath (qualifySourceClosure (-1) register closure)
            ]

missingSourceRowProblems :: [String]
missingSourceRowProblems =
  case parseActiveRegister (registerBytes [legacyRowText "LTD-VAL-005" 49]) of
    Left problems -> ["missing-row setup failed: " <> show problems]
    Right register ->
      expectFindingAt
        "observed debt without active source row"
        "LEGACY-SOURCE-ROW-MISSING"
        canonicalPath
        (qualifySourceClosure 0 register (classifySnapshot (snapshot [tracked "tools/legacy.py" "legacy\n"])))

staleSourceRowProblems :: [String]
staleSourceRowProblems =
  case parseActiveRegister (registerBytes [legacyRowText "LTD-SRC-001" 47]) of
    Left problems -> ["stale-row setup failed: " <> show problems]
    Right register ->
      expectFindingAt
        "active source row without observed debt"
        "LEGACY-SOURCE-ROW-STALE"
        canonicalPath
        (qualifySourceClosure 0 register (classifySnapshot (snapshot [])))

dueRowProblems :: [String]
dueRowProblems = concatMap checkDue canonicalOwnerCases
 where
  checkDue (identifier, owner, maybeEntry, expectedCode) =
    case parseActiveRegister (registerBytes [legacyRowText identifier owner]) of
      Left problems -> ["due-row setup for " <> Text.unpack identifier <> " failed: " <> show problems]
      Right register ->
        let closure = classifySnapshot (snapshot (maybe [] pure maybeEntry))
         in expectFindingAt
              ("row due at candidate " <> Text.unpack identifier)
              expectedCode
              canonicalPath
              (qualifySourceClosure owner register closure)

canonicalOwnerCases :: [(Text, Int, Maybe TrackedEntry, Text)]
canonicalOwnerCases =
  [ ("LTD-SRC-000", 0, Nothing, "LEGACY-PHASE0-OWNED")
  ]
    <> [ (identifier, owner, Just entry, "LEGACY-SOURCE-OWNER-DUE")
       | (identifier, _, (owner, entry)) <- sourceDebtCases
       ]
    <> [ (identifier, owner, Nothing, "LEGACY-ACTIVE-ROW-DUE")
       | (identifier, owner) <- nonSourceOwners
       ]

sourceDebtCases :: [(Text, SourceDebtId, (Int, TrackedEntry))]
sourceDebtCases =
  [ ("LTD-SRC-001", SourceTools, (47, tracked "tools/legacy.py" "legacy\n"))
  , ("LTD-SRC-002", SourceDhall, (25, tracked "schema/legacy.dhall" "{}\n"))
  , ("LTD-SRC-003", SourceProto, (26, tracked "proto/legacy.proto" "syntax = \"proto3\";\n"))
  , ("LTD-SRC-004", SourceUi, (46, tracked "ui/legacy.js" "legacy\n"))
  , ("LTD-SRC-005", SourcePulumi, (47, tracked "pulumi/legacy.py" "legacy\n"))
  , ("LTD-SRC-006", SourceTest, (47, tracked "test/legacy.py" "legacy\n"))
  , ("LTD-SRC-007", SourceProbe, (1, tracked "probe/legacy.py" "legacy\n"))
  , ("LTD-SRC-008", SourcePb, (0, tracked "pb/pb/admin.py" "adminclient\n"))
  , ("LTD-SRC-009", SourceVendor, (1, tracked "vendor/pkg/Legacy.hs" "module Legacy where\n"))
  ]

nonSourceOwners :: [(Text, Int)]
nonSourceOwners =
  [ ("LTD-META-001", 2)
  , ("LTD-VAL-001", 0)
  , ("LTD-VAL-002", 0)
  , ("LTD-VAL-003", 0)
  , ("LTD-VAL-004", 0)
  , ("LTD-VAL-005", 49)
  , ("LTD-VAL-006", 47)
  , ("LTD-DOC-001", 27)
  , ("LTD-NAME-001", 2)
  , ("LTD-HOST-001", 51)
  , ("LTD-HOST-002", 51)
  , ("LTD-IMG-001", 56)
  , ("LTD-RUN-001", 55)
  , ("LTD-SEED-001", 91)
  , ("LTD-SEED-002", 93)
  ]

registerEntry :: [Text] -> TrackedEntry
registerEntry rows = tracked canonicalPath (registerBytes rows)

registerBytes :: [Text] -> ByteString
registerBytes rows =
  ByteString8.pack
    ( Text.unpack
        ( "| ID | Current observation | Owner/replacement | Executable closure predicate |\n"
            <> "|---|---|---|---|\n"
            <> Text.unlines rows
        )
    )

legacyRowText :: Text -> Int -> Text
legacyRowText identifier owner =
  customRow
    ("`" <> identifier <> "`")
    (identifier <> " remains present")
    ("**Phase " <> Text.pack (show owner) <> ".** replace " <> identifier <> " with Haskell")
    ("`close " <> identifier <> "`")

customRow :: Text -> Text -> Text -> Text -> Text
customRow identifier observation owner predicate =
  "| " <> identifier <> " | " <> observation <> " | " <> owner <> " | " <> predicate <> " |"

snapshot :: [TrackedEntry] -> SourceSnapshot
snapshot entries =
  SourceSnapshot
    { snapshotRoot = "/immutable/oracle"
    , snapshotIdentity = Text.replicate 64 "e"
    , snapshotEntries = entries
    }

tracked :: FilePath -> ByteString -> TrackedEntry
tracked path bytes =
  TrackedEntry
    { trackedIndex = IndexEntry path RegularFile (Text.replicate 40 "f")
    , trackedBytes = bytes
    }

expectProblem :: (Show success, Show problem) => String -> (problem -> Bool) -> Either [problem] success -> [String]
expectProblem label predicate result = case result of
  Left problems | any predicate problems -> []
  Left problems -> [label <> ": expected problem was absent from " <> show problems]
  Right accepted -> [label <> ": malformed input was accepted as " <> show accepted]

expectFindingAt :: String -> Text -> FilePath -> CheckResult -> [String]
expectFindingAt label code subject result =
  [ label <> ": expected " <> Text.unpack code <> " at " <> subject <> ", observed " <> show (checkFindings result)
  | not (any (\item -> findingCode item == code && findingSubject item == subject) (checkFindings result))
  ]

expectEqual :: (Eq value, Show value) => String -> value -> value -> [String]
expectEqual label expected actual
  | expected == actual = []
  | otherwise = [label <> ": expected " <> show expected <> ", observed " <> show actual]

finishDiagnostics :: String -> [String] -> IO ()
finishDiagnostics name problems =
  unless
    (null problems)
    (fail (name <> " component diagnostic failures:\n  " <> Text.unpack (Text.intercalate "\n  " (map Text.pack problems))))

canonicalPath :: FilePath
canonicalPath = "DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md"
