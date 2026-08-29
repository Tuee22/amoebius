{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.Gate
  ( DiagnosticMutationWitness (..)
  , DiagnosticQualificationBaseline (..)
  , Sabotage (..)
  , DiagnosticSabotageRun (..)
  , allSabotages
  , checkQualificationReportDiagnostic
  , sabotageName
  ) where

import Amoebius.Validation.PolicyContract.Internal qualified as Policy
import Amoebius.Validation.Types
import Data.List (group, sort)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import System.FilePath (isAbsolute, splitDirectories, takeExtension)

data Sabotage
  = ConstantSuccess
  | NoOpSubject
  | WrongOutput
  | EmptyDiscovery
  | MissingSubject
  | MissingOracle
  | SkippedMutant
  | WrongLocus
  | StaleEvidence
  | SelfObserver
  | AuthorityBypass
  | ResidueSmuggling
  deriving (Bounded, Enum, Eq, Ord, Show)

data DiagnosticMutationWitness = DiagnosticMutationWitness
  { mutationOperator :: Text
  , mutationBeforeDigest :: Text
  , mutationAfterDigest :: Text
  , mutationChangedSubject :: FilePath
  }
  deriving (Eq, Ord, Show)

data DiagnosticQualificationBaseline = DiagnosticQualificationBaseline
  { qualificationHarnessDigest :: Text
  , qualificationSubjects :: Map.Map FilePath Text
  , qualificationControlNames :: Set Text
  }
  deriving (Eq, Show)

data DiagnosticSabotageRun = DiagnosticSabotageRun
  { sabotage :: Sabotage
  , sabotageHarnessDigest :: Text
  , sabotageWitness :: DiagnosticMutationWitness
  , sabotageResult :: CheckResult
  , sabotageUnaffectedControls :: [CheckResult]
  }
  deriving (Eq, Show)

allSabotages :: [Sabotage]
allSabotages = [minBound .. maxBound]

sabotageName :: Sabotage -> Text
sabotageName item = case item of
  ConstantSuccess -> "constant-success"
  NoOpSubject -> "no-op-subject"
  WrongOutput -> "wrong-output"
  EmptyDiscovery -> "empty-discovery"
  MissingSubject -> "missing-subject"
  MissingOracle -> "missing-oracle"
  SkippedMutant -> "skipped-or-no-op-mutant"
  WrongLocus -> "wrong-locus"
  StaleEvidence -> "stale-evidence"
  SelfObserver -> "self-observer"
  AuthorityBypass -> "authority-bypass"
  ResidueSmuggling -> "residue-or-smuggled-input"

-- | Check the internal consistency of a caller-supplied qualification report.
--
-- This pure function does not execute a sabotage, read or hash a production
-- subject, bind the runner that produced a report, observe resource ownership, or supply
-- an independent observer.  Consequently, a passing result means only that
-- the supplied report is structurally self-consistent.  It cannot retire the
-- dispatcher's @QUALIFICATION-NOT-EXECUTED@ readiness blocker and must never
-- be presented as harness qualification or phase-validation evidence.
checkQualificationReportDiagnostic
  :: DiagnosticQualificationBaseline
  -> [DiagnosticSabotageRun]
  -> CheckResult
checkQualificationReportDiagnostic baseline runs =
  CheckResult
    { checkName = "phase-00-qualification-report-consistency"
    , checkObservations =
        [ observation
            "qualification-report-scope"
            "caller-supplied report consistency only; execution and provenance unverified"
        , observation "qualification-case-count" (Text.pack (show (length runs)))
        , observation "qualification-required-count" (Text.pack (show (length allSabotages)))
        ]
          <> fmap runObservation runs
    , checkFindings =
        qualificationDiagnosticOnlyFindings
          <> baselineFindings
          <> inventoryFindings
          <> concatMap (checkRun baseline) runs
    }
 where
  byCase = Map.fromListWith (<>) [(sabotage run, [run]) | run <- runs]
  baselineFindings =
    [ finding "QUALIFICATION-HARNESS-DIGEST" "validation-kernel" "baseline harness digest is not a lowercase SHA-256 value"
    | not (sha256Text (qualificationHarnessDigest baseline))
    ]
      <> [ finding "QUALIFICATION-SUBJECTS-EMPTY" "production-subjects" "qualification baseline contains no production subject"
         | Map.null (qualificationSubjects baseline)
         ]
      <> [ finding
             "QUALIFICATION-SUBJECT-INVALID"
             subject
             ("baseline subject must be an authored production " <> Text.pack canonicalHaskellSuffix <> " path")
         | subject <- Map.keys (qualificationSubjects baseline)
         , not (productionHaskellPath subject)
         ]
      <> [ finding "QUALIFICATION-SUBJECT-DIGEST" subject "baseline subject digest is not a lowercase SHA-256 value"
         | (subject, digest) <- Map.toAscList (qualificationSubjects baseline)
         , not (sha256Text digest)
         ]
      <> [ finding "QUALIFICATION-CONTROLS-EMPTY" "unaffected-controls" "qualification baseline contains no independently named unaffected control"
         | Set.null (qualificationControlNames baseline)
         ]
      <> [ finding "QUALIFICATION-CONTROL-INVALID" "unaffected-controls" "qualification baseline contains an empty or control-bearing unaffected-control name"
         | controlName <- Set.toAscList (qualificationControlNames baseline)
         , not (safeReportText controlName)
         ]
  inventoryFindings =
    [ finding "QUALIFICATION-MISSING" (Text.unpack (sabotageName required)) "required sabotage report is absent"
    | required <- allSabotages
    , Map.notMember required byCase
    ]
      <> [ finding "QUALIFICATION-DUPLICATE" (Text.unpack (sabotageName repeated)) "report contains the sabotage more than once"
         | repeated <- duplicates (fmap sabotage runs)
         ]
      <> [ finding "QUALIFICATION-UNEXPECTED" (Text.unpack (sabotageName supplied)) "undeclared sabotage supplied"
         | supplied <- Map.keys byCase
         , supplied `notElem` allSabotages
         ]

qualificationDiagnosticOnlyFindings :: [Finding]
#if defined(VALIDATION_QUALIFICATION_DIAGNOSTIC_BYPASS_MUTANT)
qualificationDiagnosticOnlyFindings = []
#else
qualificationDiagnosticOnlyFindings =
  [ finding
      "QUALIFICATION-REPORT-DIAGNOSTIC-ONLY"
      "Amoebius.Validation.Gate.checkQualificationReportDiagnostic"
      "caller-constructed baselines, mutation witnesses, refusals, and controls cannot establish execution-derived harness qualification"
  ]
#endif

runObservation :: DiagnosticSabotageRun -> Observation
runObservation run =
  observation
    ("qualification." <> sabotageName (sabotage run))
    ( if null (checkFindings (sabotageResult run))
        then "subject-accepted"
        else Text.intercalate "," (fmap findingCode (checkFindings (sabotageResult run)))
    )

checkRun :: DiagnosticQualificationBaseline -> DiagnosticSabotageRun -> [Finding]
checkRun baseline run =
  harness <> changed <> subjectBinding <> rawObservation <> resultName <> exactRefusal <> controls
 where
  name = sabotageName (sabotage run)
  witness = sabotageWitness run
  subject = mutationChangedSubject witness
  harness =
    [ finding "QUALIFICATION-HARNESS-MISMATCH" subject (name <> " report does not bind the fixed harness digest")
    | sabotageHarnessDigest run /= qualificationHarnessDigest baseline
        || not (sha256Text (sabotageHarnessDigest run))
    ]
  changed =
    [ finding "QUALIFICATION-NO-CHANGE" subject (name <> " lacks a valid changed-subject SHA-256 witness")
    | mutationBeforeDigest witness == mutationAfterDigest witness
        || not (sha256Text (mutationBeforeDigest witness))
        || not (sha256Text (mutationAfterDigest witness))
        || Text.null (Text.strip (mutationOperator witness))
        || not (safeReportText (mutationOperator witness))
    ]
  subjectBinding = case Map.lookup subject (qualificationSubjects baseline) of
    Nothing -> [finding "QUALIFICATION-SUBJECT-UNKNOWN" subject (name <> " changed no registered production subject")]
    Just baselineDigest ->
      [ finding "QUALIFICATION-BASELINE-MISMATCH" subject (name <> " before-digest does not bind the registered production subject")
      | mutationBeforeDigest witness /= baselineDigest
      ]
  rawObservation =
    [ finding "QUALIFICATION-OBSERVATION-EMPTY" subject (name <> " report contains no well-formed raw refusal observation")
    | null (checkObservations (sabotageResult run))
        || any (not . wellFormedObservation) (checkObservations (sabotageResult run))
    ]
  resultName =
    [ finding "QUALIFICATION-RESULT-NAME" subject (name <> " report carries the wrong sabotage-result name")
    | checkName (sabotageResult run) /= "qualification-sabotage." <> name
    ]
  expected = expectedFindingCode (sabotage run)
  observedFindings = checkFindings (sabotageResult run)
  observed = fmap findingCode observedFindings
  exactRefusal = case observedFindings of
    [item]
      | findingCode item == expected
          && findingSubject item == subject
          && safeReportText (findingDetail item) -> []
    _ ->
      [ finding
          "QUALIFICATION-WRONG-REFUSAL"
          subject
          (name <> " expected exactly " <> expected <> " at the changed subject but observed " <> Text.intercalate "," observed)
      ]
  suppliedControls = sabotageUnaffectedControls run
  suppliedControlNames = fmap checkName suppliedControls
  controlNameSet = Set.fromList suppliedControlNames
  controls =
    [ finding "QUALIFICATION-CONTROL-DUPLICATE" subject (name <> " repeated an unaffected control")
    | not (null (duplicates suppliedControlNames))
    ]
      <> [ finding "QUALIFICATION-CONTROL-SET" subject (name <> " report does not contain the exact unaffected-control set")
         | controlNameSet /= qualificationControlNames baseline
         ]
      <> [ finding "QUALIFICATION-CONTROL-RED" subject (name <> " reddened unaffected control " <> checkName control)
         | control <- suppliedControls
         , not (checkPassed control)
         ]
      <> [ finding "QUALIFICATION-CONTROL-OBSERVATION-EMPTY" subject (name <> " supplied no well-formed raw observation for control " <> checkName control)
         | control <- suppliedControls
         , null (checkObservations control) || any (not . wellFormedObservation) (checkObservations control)
         ]

expectedFindingCode :: Sabotage -> Text
expectedFindingCode item = case item of
  ConstantSuccess -> "SABOTAGE-CONSTANT-SUCCESS"
  NoOpSubject -> "SABOTAGE-NO-OP-SUBJECT"
  WrongOutput -> "SABOTAGE-WRONG-OUTPUT"
  EmptyDiscovery -> "SABOTAGE-EMPTY-DISCOVERY"
  MissingSubject -> "SABOTAGE-MISSING-SUBJECT"
  MissingOracle -> "SABOTAGE-MISSING-ORACLE"
  SkippedMutant -> "SABOTAGE-SKIPPED-MUTANT"
  WrongLocus -> "SABOTAGE-WRONG-LOCUS"
  StaleEvidence -> "SABOTAGE-STALE-EVIDENCE"
  SelfObserver -> "SABOTAGE-SELF-OBSERVER"
  AuthorityBypass -> "SABOTAGE-AUTHORITY-BYPASS"
  ResidueSmuggling -> "SABOTAGE-RESIDUE"

duplicates :: Ord a => [a] -> [a]
duplicates = foldr repeated [] . group . sort
 where
  repeated (value : _ : _) rest = value : rest
  repeated _ rest = rest

sha256Text :: Text -> Bool
sha256Text value =
  Text.length value == 64
    && Text.all
      (\character -> (character >= '0' && character <= '9') || (character >= 'a' && character <= 'f'))
      value

safeReportText :: Text -> Bool
safeReportText value =
  not (Text.null (Text.strip value))
    && not (Text.any (`elem` ['\t', '\r', '\n', '\0']) value)

wellFormedObservation :: Observation -> Bool
wellFormedObservation item =
  safeReportText (observationKey item) && safeReportText (observationValue item)

productionHaskellPath :: FilePath -> Bool
productionHaskellPath path =
  not (isAbsolute path)
    && takeExtension path == canonicalHaskellSuffix
    && case splitDirectories path of
      root : rest -> root `elem` ["src", "app"] && not (null rest) && all validPart rest
      [] -> False
 where
  validPart part = not (null part) && part /= "." && part /= ".."

canonicalHaskellSuffix :: FilePath
canonicalHaskellSuffix =
  Policy.behavioralSourceSuffix
    (Policy.sourceBehavioralLanguage (Policy.sourceContract Policy.canonicalPolicyContract))
