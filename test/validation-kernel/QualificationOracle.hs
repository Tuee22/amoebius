{-# LANGUAGE OverloadedStrings #-}

module QualificationOracle
  ( runQualificationOracle
  ) where

-- Component diagnostic only. This module is not independent human review,
-- harness qualification, phase validation, or promotion evidence.

import Amoebius.Validation.Gate
import Amoebius.Validation.Types
import Control.Monad (unless)
import Data.List (find)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text

runQualificationOracle :: IO ()
runQualificationOracle =
  finishDiagnostics "QualificationOracle" (structuralProblems <> behaviorProblems <> failClosedProblems)
 where
  cleanRuns = fmap cleanRun requiredCases
  cleanReportCheck = checkQualificationReport qualificationBaseline cleanRuns

  structuralProblems =
    concat
      [ expectEqual "independently enumerated sabotage inventory" (fmap caseSabotage requiredCases) allSabotages
      , concatMap checkPublicName requiredCases
      , expectEqual
          "report checker names consistency rather than qualification"
          "phase-00-qualification-report-consistency"
          (checkName cleanReportCheck)
      , expectEqual
          "report checker disclaims execution and provenance"
          (Just "caller-supplied report consistency only; execution and provenance unverified")
          (observationValueFor "qualification-report-scope" cleanReportCheck)
      , expectEqual "clean qualification report finding inventory" [] (checkFindings cleanReportCheck)
      , expectEqual
          "clean qualification case count observation"
          (Just (Text.pack (show (length requiredCases))))
          (observationValueFor "qualification-case-count" cleanReportCheck)
      , expectEqual
          "clean qualification required count observation"
          (Just (Text.pack (show (length requiredCases))))
          (observationValueFor "qualification-required-count" cleanReportCheck)
      , concatMap (checkCleanObservation cleanReportCheck) requiredCases
      , expectFindingCode
          "malformed baseline harness digest fails closed"
          "QUALIFICATION-HARNESS-DIGEST"
          (checkQualificationReport (qualificationBaseline {qualificationHarnessDigest = "not-a-digest"}) cleanRuns)
      , expectFindingCode
          "empty baseline subject inventory fails closed"
          "QUALIFICATION-SUBJECTS-EMPTY"
          (checkQualificationReport (qualificationBaseline {qualificationSubjects = Map.empty}) cleanRuns)
      , expectFindingCode
          "non-production baseline subject fails closed"
          "QUALIFICATION-SUBJECT-INVALID"
          ( checkQualificationReport
              (qualificationBaseline {qualificationSubjects = Map.singleton ".build/generated-subject.hs" cleanSubjectDigest})
              cleanRuns
          )
      , expectFindingCode
          "malformed baseline subject digest fails closed"
          "QUALIFICATION-SUBJECT-DIGEST"
          ( checkQualificationReport
              (qualificationBaseline {qualificationSubjects = Map.singleton cleanSubject "not-a-digest"})
              cleanRuns
          )
      , expectFindingCode
          "empty baseline control inventory fails closed"
          "QUALIFICATION-CONTROLS-EMPTY"
          (checkQualificationReport (qualificationBaseline {qualificationControlNames = Set.empty}) cleanRuns)
      , expectFindingCode
          "control-bearing baseline control name fails closed"
          "QUALIFICATION-CONTROL-INVALID"
          (checkQualificationReport (qualificationBaseline {qualificationControlNames = Set.singleton "bad\ncontrol"}) cleanRuns)
      ]

  behaviorProblems =
    concat
      [ expectSingleQualificationFinding
          "missing sabotage fails closed"
          "QUALIFICATION-MISSING"
          (Text.unpack (caseName constantSuccessCase))
          (checkQualificationReport qualificationBaseline (drop 1 cleanRuns))
      , expectSingleQualificationFinding
          "duplicate sabotage fails closed"
          "QUALIFICATION-DUPLICATE"
          (Text.unpack (caseName constantSuccessCase))
          (checkQualificationReport qualificationBaseline (cleanRun constantSuccessCase : cleanRuns))
      , expectFindingCode
          "wrong harness digest fails closed"
          "QUALIFICATION-HARNESS-MISMATCH"
          ( checkQualificationReport
              qualificationBaseline
              (changeRun ConstantSuccess (\run -> run {sabotageHarnessDigest = alternateDigest}) cleanRuns)
          )
      , expectFindingCode
          "unchanged digest fails closed"
          "QUALIFICATION-NO-CHANGE"
          ( checkQualificationReport
              qualificationBaseline
              ( changeRun
                  ConstantSuccess
                  (\run -> run {sabotageWitness = (sabotageWitness run) {mutationAfterDigest = mutationBeforeDigest (sabotageWitness run)}})
                  cleanRuns
              )
          )
      , expectFindingCode
          "empty mutation operator fails closed"
          "QUALIFICATION-NO-CHANGE"
          ( checkQualificationReport
              qualificationBaseline
              ( changeRun
                  NoOpSubject
                  (\run -> run {sabotageWitness = (sabotageWitness run) {mutationOperator = ""}})
                  cleanRuns
              )
          )
      , expectFindingCode
          "empty mutation locus fails closed"
          "QUALIFICATION-SUBJECT-UNKNOWN"
          ( checkQualificationReport
              qualificationBaseline
              ( changeRun
                  WrongOutput
                  ( \run ->
                      run
                        { sabotageWitness = (sabotageWitness run) {mutationChangedSubject = ""}
                        , sabotageResult = refusalResult (sabotage run) "" (caseFindingCode (caseFor (sabotage run)))
                        }
                  )
                  cleanRuns
              )
          )
      , expectFindingCode
          "wrong refusal code fails closed"
          "QUALIFICATION-WRONG-REFUSAL"
          ( checkQualificationReport
              qualificationBaseline
              ( changeRun
                  EmptyDiscovery
                  (\run -> run {sabotageResult = refusalResult (sabotage run) cleanSubject "SABOTAGE-UNRELATED"})
                  cleanRuns
              )
          )
      , expectFindingCode
          "accepted sabotage fails closed"
          "QUALIFICATION-WRONG-REFUSAL"
          ( checkQualificationReport
              qualificationBaseline
              (changeRun MissingSubject (\run -> run {sabotageResult = (sabotageResult run) {checkFindings = []}}) cleanRuns)
          )
      , expectFindingCode
          "ambiguous multiple refusals fail closed"
          "QUALIFICATION-WRONG-REFUSAL"
          ( checkQualificationReport
              qualificationBaseline
              ( changeRun
                  MissingOracle
                  ( \run ->
                      run
                        { sabotageResult =
                            (sabotageResult run)
                              { checkFindings =
                                  checkFindings (sabotageResult run)
                                    <> [finding "SABOTAGE-UNRELATED" cleanSubject "second refusal"]
                              }
                        }
                  )
                  cleanRuns
              )
          )
      , expectFindingCode
          "missing raw refusal observation fails closed"
          "QUALIFICATION-OBSERVATION-EMPTY"
          ( checkQualificationReport
              qualificationBaseline
              ( changeRun
                  SkippedMutant
                  (\run -> run {sabotageResult = (sabotageResult run) {checkObservations = []}})
                  cleanRuns
              )
          )
      , expectFindingCode
          "synthetic empty raw refusal observation fails closed"
          "QUALIFICATION-OBSERVATION-EMPTY"
          ( checkQualificationReport
              qualificationBaseline
              ( changeRun
                  SkippedMutant
                  (\run -> run {sabotageResult = (sabotageResult run) {checkObservations = [observation "" "claimed"]}})
                  cleanRuns
              )
          )
      , expectFindingCode
          "wrong sabotage result name fails closed"
          "QUALIFICATION-RESULT-NAME"
          ( checkQualificationReport
              qualificationBaseline
              ( changeRun
                  EmptyDiscovery
                  (\run -> run {sabotageResult = (sabotageResult run) {checkName = "qualification-sabotage.wrong-output"}})
                  cleanRuns
              )
          )
      , expectFindingCode
          "red unaffected control fails closed"
          "QUALIFICATION-CONTROL-RED"
          ( checkQualificationReport
              qualificationBaseline
              (changeRun WrongLocus (\run -> run {sabotageUnaffectedControls = redControls}) cleanRuns)
          )
      , expectFindingCode
          "missing unaffected control fails closed"
          "QUALIFICATION-CONTROL-SET"
          ( checkQualificationReport
              qualificationBaseline
              (changeRun StaleEvidence (\run -> run {sabotageUnaffectedControls = [documentationControl]}) cleanRuns)
          )
      , expectFindingCode
          "duplicate unaffected control fails closed"
          "QUALIFICATION-CONTROL-DUPLICATE"
          ( checkQualificationReport
              qualificationBaseline
              (changeRun SelfObserver (\run -> run {sabotageUnaffectedControls = greenControls <> [documentationControl]}) cleanRuns)
          )
      , expectFindingCode
          "unobserved unaffected control fails closed"
          "QUALIFICATION-CONTROL-OBSERVATION-EMPTY"
          ( checkQualificationReport
              qualificationBaseline
              (changeRun AuthorityBypass (\run -> run {sabotageUnaffectedControls = unobservedControls}) cleanRuns)
          )
      ]

  failClosedProblems =
    concat
      [ expectFindingCode
          "expected code at the wrong locus must fail closed"
          "QUALIFICATION-WRONG-REFUSAL"
          ( checkQualificationReport
              qualificationBaseline
              ( changeRun
                  WrongLocus
                  ( \run ->
                      run
                        { sabotageResult =
                            refusalResult
                              (sabotage run)
                              "src/validation-kernel/Amoebius/Validation/Types.hs"
                              (caseFindingCode (caseFor (sabotage run)))
                        }
                  )
                  cleanRuns
              )
          )
      , expectFindingCodes
          "unsubstantiated digest strings and an unregistered locus must fail closed"
          ["QUALIFICATION-NO-CHANGE", "QUALIFICATION-SUBJECT-UNKNOWN"]
          ( checkQualificationReport
              qualificationBaseline
              ( changeRun
                  StaleEvidence
                  ( \run ->
                      run
                        { sabotageWitness =
                            (sabotageWitness run)
                              { mutationOperator = "claimed-without-applied-change"
                              , mutationBeforeDigest = "not-a-sha256-before"
                              , mutationAfterDigest = "not-a-sha256-after"
                              , mutationChangedSubject = "src/validation-kernel/Amoebius/Validation/DoesNotExist.hs"
                              }
                        , sabotageResult =
                            refusalResult
                              (sabotage run)
                              "src/validation-kernel/Amoebius/Validation/DoesNotExist.hs"
                              (caseFindingCode (caseFor (sabotage run)))
                        }
                  )
                  cleanRuns
              )
          )
      , expectFindingCode
          "valid but wrong before digest must not bind the baseline subject"
          "QUALIFICATION-BASELINE-MISMATCH"
          ( checkQualificationReport
              qualificationBaseline
              ( changeRun
                  ResidueSmuggling
                  (\run -> run {sabotageWitness = (sabotageWitness run) {mutationBeforeDigest = alternateDigest}})
                  cleanRuns
              )
          )
      ]

data RequiredCase = RequiredCase
  { caseSabotage :: Sabotage
  , caseName :: Text
  , caseFindingCode :: Text
  }

requiredCases :: [RequiredCase]
requiredCases =
  [ constantSuccessCase
  , RequiredCase NoOpSubject "no-op-subject" "SABOTAGE-NO-OP-SUBJECT"
  , RequiredCase WrongOutput "wrong-output" "SABOTAGE-WRONG-OUTPUT"
  , RequiredCase EmptyDiscovery "empty-discovery" "SABOTAGE-EMPTY-DISCOVERY"
  , RequiredCase MissingSubject "missing-subject" "SABOTAGE-MISSING-SUBJECT"
  , RequiredCase MissingOracle "missing-oracle" "SABOTAGE-MISSING-ORACLE"
  , RequiredCase SkippedMutant "skipped-or-no-op-mutant" "SABOTAGE-SKIPPED-MUTANT"
  , RequiredCase WrongLocus "wrong-locus" "SABOTAGE-WRONG-LOCUS"
  , RequiredCase StaleEvidence "stale-evidence" "SABOTAGE-STALE-EVIDENCE"
  , RequiredCase SelfObserver "self-observer" "SABOTAGE-SELF-OBSERVER"
  , RequiredCase AuthorityBypass "authority-bypass" "SABOTAGE-AUTHORITY-BYPASS"
  , RequiredCase ResidueSmuggling "residue-or-smuggled-input" "SABOTAGE-RESIDUE"
  ]

constantSuccessCase :: RequiredCase
constantSuccessCase = RequiredCase ConstantSuccess "constant-success" "SABOTAGE-CONSTANT-SUCCESS"

qualificationBaseline :: QualificationBaseline
qualificationBaseline =
  QualificationBaseline
    { qualificationHarnessDigest = fixedHarnessDigest
    , qualificationSubjects = Map.singleton cleanSubject cleanSubjectDigest
    , qualificationControlNames = Set.fromList (fmap checkName greenControls)
    }

fixedHarnessDigest :: Text
fixedHarnessDigest = digestText 'c'

cleanSubject :: FilePath
cleanSubject = "src/validation-kernel/Amoebius/Validation/Gate.hs"

cleanSubjectDigest :: Text
cleanSubjectDigest = digestText 'a'

changedSubjectDigest :: Text
changedSubjectDigest = digestText 'b'

alternateDigest :: Text
alternateDigest = digestText 'd'

greenControls :: [CheckResult]
greenControls = [documentationControl, sourceClosureControl]

documentationControl :: CheckResult
documentationControl =
  CheckResult
    { checkName = "control.documentation-corpus"
    , checkObservations = [observation "control-document-count" "37"]
    , checkFindings = []
    }

sourceClosureControl :: CheckResult
sourceClosureControl =
  CheckResult
    { checkName = "control.source-closure"
    , checkObservations = [observation "control-source-count" "211"]
    , checkFindings = []
    }

redControls :: [CheckResult]
redControls =
  [ documentationControl
      { checkFindings = [finding "CONTROL-RED" cleanSubject "synthetic unaffected control reddened"]
      }
  , sourceClosureControl
  ]

unobservedControls :: [CheckResult]
unobservedControls = [documentationControl {checkObservations = []}, sourceClosureControl]

caseFor :: Sabotage -> RequiredCase
caseFor item = case item of
  ConstantSuccess -> RequiredCase ConstantSuccess "constant-success" "SABOTAGE-CONSTANT-SUCCESS"
  NoOpSubject -> RequiredCase NoOpSubject "no-op-subject" "SABOTAGE-NO-OP-SUBJECT"
  WrongOutput -> RequiredCase WrongOutput "wrong-output" "SABOTAGE-WRONG-OUTPUT"
  EmptyDiscovery -> RequiredCase EmptyDiscovery "empty-discovery" "SABOTAGE-EMPTY-DISCOVERY"
  MissingSubject -> RequiredCase MissingSubject "missing-subject" "SABOTAGE-MISSING-SUBJECT"
  MissingOracle -> RequiredCase MissingOracle "missing-oracle" "SABOTAGE-MISSING-ORACLE"
  SkippedMutant -> RequiredCase SkippedMutant "skipped-or-no-op-mutant" "SABOTAGE-SKIPPED-MUTANT"
  WrongLocus -> RequiredCase WrongLocus "wrong-locus" "SABOTAGE-WRONG-LOCUS"
  StaleEvidence -> RequiredCase StaleEvidence "stale-evidence" "SABOTAGE-STALE-EVIDENCE"
  SelfObserver -> RequiredCase SelfObserver "self-observer" "SABOTAGE-SELF-OBSERVER"
  AuthorityBypass -> RequiredCase AuthorityBypass "authority-bypass" "SABOTAGE-AUTHORITY-BYPASS"
  ResidueSmuggling -> RequiredCase ResidueSmuggling "residue-or-smuggled-input" "SABOTAGE-RESIDUE"

cleanRun :: RequiredCase -> SabotageRun
cleanRun required =
  SabotageRun
    { sabotage = caseSabotage required
    , sabotageHarnessDigest = fixedHarnessDigest
    , sabotageWitness =
        MutationWitness
          { mutationOperator = "replace-production-branch-" <> caseName required
          , mutationBeforeDigest = cleanSubjectDigest
          , mutationAfterDigest = changedSubjectDigest
          , mutationChangedSubject = cleanSubject
          }
    , sabotageResult = refusalResult (caseSabotage required) cleanSubject (caseFindingCode required)
    , sabotageUnaffectedControls = greenControls
    }

refusalResult :: Sabotage -> FilePath -> Text -> CheckResult
refusalResult item subject code =
  CheckResult
    { checkName = "qualification-sabotage." <> caseName (caseFor item)
    , checkObservations = [observation "observed-locus" (Text.pack subject)]
    , checkFindings = [finding code subject "independently expected refusal"]
    }

changeRun :: Sabotage -> (SabotageRun -> SabotageRun) -> [SabotageRun] -> [SabotageRun]
changeRun target change = fmap (\run -> if sabotage run == target then change run else run)

checkPublicName :: RequiredCase -> [String]
checkPublicName required =
  expectEqual
    ("public name for " <> show (caseSabotage required))
    (caseName required)
    (sabotageName (caseSabotage required))

checkCleanObservation :: CheckResult -> RequiredCase -> [String]
checkCleanObservation result required =
  expectEqual
    ("clean refusal observation for " <> Text.unpack (caseName required))
    (Just (caseFindingCode required))
    (observationValueFor ("qualification." <> caseName required) result)

observationValueFor :: Text -> CheckResult -> Maybe Text
observationValueFor key result = observationValue <$> find ((== key) . observationKey) (checkObservations result)

expectSingleQualificationFinding :: String -> Text -> FilePath -> CheckResult -> [String]
expectSingleQualificationFinding label code subject result =
  expectEqual label [(code, subject)] (fmap (\item -> (findingCode item, findingSubject item)) (checkFindings result))

expectFindingCode :: String -> Text -> CheckResult -> [String]
expectFindingCode label code result
  | code `elem` fmap findingCode (checkFindings result) = []
  | otherwise = [label <> ": expected finding " <> Text.unpack code <> ", observed " <> show (checkFindings result)]

expectFindingCodes :: String -> [Text] -> CheckResult -> [String]
expectFindingCodes label codes result =
  concatMap (\code -> expectFindingCode (label <> " [" <> Text.unpack code <> "]") code result) codes

expectEqual :: (Eq value, Show value) => String -> value -> value -> [String]
expectEqual label expected actual
  | actual == expected = []
  | otherwise = [label <> ": expected " <> show expected <> ", observed " <> show actual]

digestText :: Char -> Text
digestText character = Text.replicate 64 (Text.singleton character)

finishDiagnostics :: String -> [String] -> IO ()
finishDiagnostics name problems =
  unless (null problems) (fail (name <> " component diagnostic failures:\n  " <> Text.unpack (Text.intercalate "\n  " (fmap Text.pack problems))))
