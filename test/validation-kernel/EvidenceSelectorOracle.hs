{-# LANGUAGE OverloadedStrings #-}

-- | The independent oracle for the verdict layer.
--
-- The layer that decides whether a row passed had neither a mutant nor an
-- oracle: nothing in the repository constructed a malformed observation and
-- asked what the verdict did with it. An error there is invisible in both
-- directions -- it can refuse a correct subject, and it can admit an incorrect
-- one -- so this oracle states, independently of production, what each of the
-- three verdict decisions must be.
module EvidenceSelectorOracle
  ( evidenceSelectorNames
  , evidenceSelectorCaseNames
  , evidenceSelectorAssignments
  , runEvidenceSelectorAllOracle
  , runEvidenceSelectorOracle
  , runEvidenceSelectorCase
  , runEvidenceSelectorUnaffectedOracle
  ) where

import Amoebius.Validation.Evidence.Internal
  ( RowOutcome (RowPassed, RowRefused)
  , outcomeName
  , rowOutcomeFromCheck
  )
import Amoebius.Validation.Types (CheckResult (CheckResult), observation)
import Control.Monad (unless)

-- Selector identity, the independently named atomic requirement it removes, and
-- the single exact case assigned to make that changed subject observable.
evidenceSelectorIntents :: [(String, String, String)]
evidenceSelectorIntents =
  [
    ( "VALIDATION_EVIDENCE_ROW_OUTCOME_SKIP_VALID_OBSERVATION_MUTANT"
    , "refuse a passing check whose observation record is malformed"
    , "malformed-observation-refused"
    )
  ,
    ( "VALIDATION_EVIDENCE_ROW_OUTCOME_ADMIT_EMPTY_MUTANT"
    , "refuse a passing check that supplied no observation"
    , "evidence-free-refused"
    )
  ,
    ( "VALIDATION_EVIDENCE_OUTCOME_NAME_ALWAYS_GREEN_MUTANT"
    , "render a row name that agrees with the verdict computed from it"
    , "rendered-name-agrees-with-verdict"
    )
  ]

evidenceSelectorNames :: [String]
evidenceSelectorNames = [selector | (selector, _, _) <- evidenceSelectorIntents]

-- | Each selector's assigned case, and the control that must stay green while
-- that case goes red.
--
-- The control is the rest of this oracle's cases. They are authored
-- independently of one another and decided by the same binary, so a changed
-- subject that reddened all three would be a compile or wiring failure rather
-- than the one semantic change the selector claims to make.
evidenceSelectorAssignments :: [(String, [String], String)]
evidenceSelectorAssignments =
  [ (selector, [assigned], "EvidenceSelectorOracle:remaining-exact-cases")
  | (selector, _, assigned) <- evidenceSelectorIntents
  ]

evidenceSelectorCaseNames :: [String]
evidenceSelectorCaseNames = allCaseNames

-- A value the domain forbids: a record terminator inside an observation value
-- would inject a second record. Emptiness is deliberately not used here -- an
-- empty value is a rendered empty collection, which is a claim rather than a
-- malformed payload.
malformedRow :: RowOutcome
malformedRow = rowOutcomeFromCheck "EVIDENCE-ORACLE" (CheckResult "case" [observation "key" "two\nrecords"] [])

evidenceFreeRow :: RowOutcome
evidenceFreeRow = rowOutcomeFromCheck "EVIDENCE-ORACLE" (CheckResult "case" [] [])

exactCase :: String -> [String]
exactCase name = case name of
  "malformed-observation-refused" ->
    [ "a passing check with a malformed observation must refuse, and must carry a finding naming why"
    | not (refusedWithFinding malformedRow)
    ]
  "evidence-free-refused" ->
    [ "a passing check that supplied no observation must refuse"
    | not (refusedWithFinding evidenceFreeRow)
    ]
  "rendered-name-agrees-with-verdict" ->
    [ "a row holding a malformed observation must not render as green"
    | outcomeName (RowPassed [observation "key" "two\nrecords"]) /= "red"
    ]
  _ -> ["unknown exact case: " <> name]
 where
  refusedWithFinding outcome = case outcome of
    RowRefused _ findings -> not (null findings)
    _ -> False

allCaseNames :: [String]
allCaseNames = [assigned | (_, _, assigned) <- evidenceSelectorIntents]

report :: [String] -> IO ()
report problems =
  unless
    (null problems)
    (fail (unlines ("EvidenceSelectorOracle component diagnostics failed:" : map ("  " <>) problems)))

runEvidenceSelectorAllOracle :: IO ()
runEvidenceSelectorAllOracle = report (concatMap exactCase allCaseNames)

runEvidenceSelectorOracle :: String -> IO ()
runEvidenceSelectorOracle selector = withAssignedCase selector (report . exactCase)

-- | The same binary's remaining cases, which a correctly attributed change
-- leaves green.
runEvidenceSelectorUnaffectedOracle :: String -> IO ()
runEvidenceSelectorUnaffectedOracle selector =
  withAssignedCase selector $ \assigned ->
    report (concatMap exactCase (filter (/= assigned) allCaseNames))

runEvidenceSelectorCase :: String -> IO ()
runEvidenceSelectorCase label
  | label `elem` allCaseNames = report (exactCase label)
  | otherwise = fail ("unknown exact case: " <> label)

withAssignedCase :: String -> (String -> IO ()) -> IO ()
withAssignedCase selector consume =
  case [assigned | (name, _, assigned) <- evidenceSelectorIntents, name == selector] of
    [assigned] -> consume assigned
    _ -> fail ("selector intent is not exactly resolvable: " <> selector)
