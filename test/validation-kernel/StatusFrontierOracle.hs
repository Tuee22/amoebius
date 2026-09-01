{-# LANGUAGE OverloadedStrings #-}

module StatusFrontierOracle (
    runStatusFrontierOracle,
) where

-- Component diagnostic only. This oracle does not apply a status projection,
-- validate a phase, or create status evidence.

import Amoebius.Validation.PhaseContract (phaseContractDiagnostic)
import Amoebius.Validation.StatusFrontier
import Amoebius.Validation.Types (CheckResult (checkFindings), Finding (findingCode))
import Control.Monad (unless)
import Data.Text (Text)
import Data.Text qualified as Text
import PhaseContractOracle (phaseContractValidCorpus)

runStatusFrontierOracle :: IO ()
runStatusFrontierOracle =
    finishDiagnostics
        "StatusFrontierOracle"
        (openAtZeroProblems <> midFrontierProblems <> postPassProblems <> allDoneProblems <> invalidFrontierProblems <> refusalProblems)

openAtZeroProblems :: [String]
openAtZeroProblems =
    concat
        [ expectEqual
            "OpenAt 0 phase projection"
            [ActiveNotValidated, BlockedNotValidated, BlockedNotValidated]
            (phaseStatuses openAtZero [0, 1, phaseUpper])
        , expectEqual
            "OpenAt 0 sprint projection"
            [ActiveNotValidated, BlockedNotValidated, BlockedNotValidated]
            (sprintStatuses openAtZero [(0, 1), (0, 2), (1, 1)])
        ]
  where
    openAtZero = initialFrontier

midFrontierProblems :: [String]
midFrontierProblems =
    concat
        [ expectEqual
            "mid-frontier phase projection"
            [Done, ActiveNotValidated, BlockedNotValidated]
            (phaseStatuses midFrontier [46, 47, 48])
        , expectEqual
            "mid-frontier sprint projection"
            [Done, ActiveNotValidated, BlockedNotValidated, BlockedNotValidated]
            (sprintStatuses midFrontier [(46, 1), (47, 1), (47, 2), (48, 1)])
        ]
  where
    midFrontier = requiredFrontier 47

postPassProblems :: [String]
postPassProblems =
    concat
        [ expectEqual
            "passing OpenAt 0 advances exactly to OpenAt 1"
            (Just (requiredFrontier 1))
            (frontierAfterPass initialFrontier 0)
        , expectEqual
            "passing a mid-frontier advances exactly once"
            (requiredFrontier 48)
            afterMidPass
        , expectEqual
            "post-pass phase projection closes the passed phase and activates its successor"
            [Done, ActiveNotValidated, BlockedNotValidated]
            (phaseStatuses afterMidPass [47, 48, 49])
        , expectEqual
            "post-pass sprint projection closes the passed phase and opens only the successor's first sprint"
            [Done, ActiveNotValidated, BlockedNotValidated, BlockedNotValidated]
            (sprintStatuses afterMidPass [(47, 1), (48, 1), (48, 2), (49, 1)])
        ]
  where
    afterMidPass = requiredAdvance (requiredFrontier 47) 47

allDoneProblems :: [String]
allDoneProblems =
    concat
        [ expectEqual
            "the terminal AllDone frontier closes the complete phase domain"
            [Done, Done, Done]
            (phaseStatuses allDone [0, 47, phaseUpper])
        , expectEqual
            "the terminal AllDone frontier closes every sampled sprint"
            [Done, Done, Done]
            (sprintStatuses allDone [(0, 1), (47, 2), (phaseUpper, 1)])
        , expectEqual "AllDone tracker rendering" "✅ Done" (renderTrackerStatus terminalStatus)
        , expectEqual "AllDone phase rendering" "✅ Done." (renderPhaseStatusLine terminalStatus)
        , expectEqual "AllDone sprint rendering" "Done" (renderSprintStatus terminalStatus)
        , expectEqual "AllDone marker rendering" "✅" (renderStatusMarker terminalStatus)
        ]
  where
    allDone = requiredAdvance (requiredFrontier phaseUpper) phaseUpper
    terminalStatus = phaseStatusAt allDone phaseUpper

invalidFrontierProblems :: [String]
invalidFrontierProblems =
    concat
        [ expectEqual "negative frontier is unrepresentable" Nothing (frontierForGate (-1))
        , expectEqual "past-domain frontier is unrepresentable" Nothing (frontierForGate (phaseUpper + 1))
        , expectEqual "a pass cannot advance a different active phase" Nothing (frontierAfterPass initialFrontier 1)
        , expectEqual "AllDone cannot advance again" Nothing (frontierAfterPass (requiredAdvance (requiredFrontier phaseUpper) phaseUpper) phaseUpper)
        ]

refusalProblems :: [String]
refusalProblems =
    expectAbsentFindingCodes
        "the canonical OpenAt 0 corpus has no status inconsistency"
        inconsistentStatusCodes
        cleanDiagnostic
        <> expectFindingCodes
            "contradictory phase, sprint, and tracker statuses are refused"
            inconsistentStatusCodes
            inconsistentDiagnostic
  where
    cleanDiagnostic = phaseContractDiagnostic phaseContractValidCorpus
    inconsistentDiagnostic = phaseContractDiagnostic inconsistentStatusCorpus

inconsistentStatusCorpus :: [(FilePath, Text)]
inconsistentStatusCorpus =
    replaceIn
        trackerPath
        "| 🔄 Active — NOT VALIDATED |"
        "| ✅ Done |"
        ( replaceIn
            phaseZeroPath
            "**Status**: Active — NOT VALIDATED"
            "**Status**: Done"
            ( replaceIn
                phaseZeroPath
                "🔄 Active — NOT VALIDATED."
                "✅ Done."
                phaseContractValidCorpus
            )
        )

inconsistentStatusCodes :: [Text]
inconsistentStatusCodes =
    [ "PLAN-PHASE-STATUS"
    , "PLAN-SPRINT-STATUS"
    , "PLAN-TRACKER-STATUS"
    ]

phaseStatuses :: StatusFrontier -> [Int] -> [PlanStatus]
phaseStatuses frontier = fmap (phaseStatusAt frontier)

sprintStatuses :: StatusFrontier -> [(Int, Int)] -> [PlanStatus]
sprintStatuses frontier = fmap (uncurry (sprintStatusAt frontier))

requiredFrontier :: Int -> StatusFrontier
requiredFrontier ordinal = case frontierForGate ordinal of
    Just frontier -> frontier
    Nothing -> initialFrontier

requiredAdvance :: StatusFrontier -> Int -> StatusFrontier
requiredAdvance frontier phase = case frontierAfterPass frontier phase of
    Just advanced -> advanced
    Nothing -> frontier

replaceIn :: FilePath -> Text -> Text -> [(FilePath, Text)] -> [(FilePath, Text)]
replaceIn target before after = fmap replaceOne
  where
    replaceOne item@(path, contents)
        | path == target = (path, Text.replace before after contents)
        | otherwise = item

expectFindingCodes :: String -> [Text] -> CheckResult -> [String]
expectFindingCodes label expected result =
    [ label <> ": expected finding " <> Text.unpack code <> ", observed " <> show observed
    | code <- expected
    , code `notElem` observed
    ]
  where
    observed = fmap findingCode (checkFindings result)

expectAbsentFindingCodes :: String -> [Text] -> CheckResult -> [String]
expectAbsentFindingCodes label forbidden result =
    [ label <> ": unexpected finding " <> Text.unpack code
    | code <- forbidden
    , code `elem` observed
    ]
  where
    observed = fmap findingCode (checkFindings result)

expectEqual :: (Eq value, Show value) => String -> value -> value -> [String]
expectEqual label expected actual
    | actual == expected = []
    | otherwise = [label <> ": expected " <> show expected <> ", observed " <> show actual]

finishDiagnostics :: String -> [String] -> IO ()
finishDiagnostics name problems =
    unless
        (null problems)
        (fail (name <> " component diagnostic failures:\n  " <> Text.unpack (Text.intercalate "\n  " (fmap Text.pack problems))))

phaseUpper :: Int
phaseUpper = 95

phaseZeroPath :: FilePath
phaseZeroPath = "DEVELOPMENT_PLAN/phase_00_synthetic_capability.md"

trackerPath :: FilePath
trackerPath = "DEVELOPMENT_PLAN/README.md"
