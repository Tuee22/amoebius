{-# LANGUAGE OverloadedStrings #-}

module QualificationInternalOracle (
    qualificationInternalOracleProblems,
) where

-- Pure component diagnostic for the package-hidden authority boundary.  It
-- neither executes the qualification corpus nor constitutes qualification.

import Amoebius.Validation.Gate (
    DiagnosticMutationWitness (..),
    DiagnosticQualificationBaseline (..),
    DiagnosticSabotageRun (..),
    Sabotage,
    allSabotages,
    checkQualificationReportDiagnostic,
    sabotageName,
 )
import Amoebius.Validation.Gate.Internal (
    QualificationProblem,
    allQualificationCaseIdentities,
    currentQualificationAttempt,
    currentQualifiedValidationProtocol,
    qualificationCaseExpectedFindingCode,
    qualificationCaseName,
    qualificationInternalTestBinderResults,
    qualificationInternalTestBoundaryResults,
    qualificationInternalTestCaseContractRows,
    qualificationInternalTestCaseRows,
    qualificationInternalTestVerifierResults,
    qualificationProblemCode,
    qualificationProblemDetail,
    qualificationProblemSubject,
 )
import Amoebius.Validation.Types (
    CheckResult (..),
    checkPassed,
    finding,
    findingCode,
    observation,
 )
import Data.List (zipWith4)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text

qualificationInternalOracleProblems :: [String]
qualificationInternalOracleProblems =
    concat
        [ expectEqual "closed internal case names" requiredCaseNames internalCaseNames
        , expectEqual "closed internal refusal codes" requiredFindingCodes internalFindingCodes
        , expectEqual "internal case count" 17 (length allQualificationCaseIdentities)
        , expectEqual "internal case-name uniqueness" 17 (Set.size (Set.fromList internalCaseNames))
        , expectEqual "internal refusal-code uniqueness" 17 (Set.size (Set.fromList internalFindingCodes))
        , expectEqual "public diagnostic and authority inventories agree by name" internalCaseNames (map sabotageName allSabotages)
        , expectEqual
            "a structurally consistent public report remains diagnostic-only"
            ["QUALIFICATION-REPORT-DIAGNOSTIC-ONLY"]
            (map findingCode (checkFindings cleanPublicDiagnostic))
        , expectEqual
            "a structurally consistent public report cannot pass"
            False
            (checkPassed cleanPublicDiagnostic)
        , expectRefusal "attempt acquisition refuses without a supervisor" currentQualificationAttempt
        , expectRefusal "protocol authority refuses without a supervisor" currentQualifiedValidationProtocol
        , verifierFixtureProblems
        , binderFixtureProblems
        , expectEqual "independent exact case-to-row registry" requiredCaseRows qualificationInternalTestCaseRows
        , expectEqual "independent exact qualification contract" requiredCaseContractRows qualificationInternalTestCaseContractRows
        , expectEqual
            "literal primitive boundaries"
            requiredBoundaryResults
            qualificationInternalTestBoundaryResults
        ]
  where
    internalCaseNames = map qualificationCaseName allQualificationCaseIdentities
    internalFindingCodes = map qualificationCaseExpectedFindingCode allQualificationCaseIdentities

requiredCaseNames :: [Text]
requiredCaseNames =
    [ "constant-success"
    , "no-op-subject"
    , "wrong-output"
    , "empty-discovery"
    , "missing-subject"
    , "missing-oracle"
    , "skipped-or-no-op-mutant"
    , "wrong-locus"
    , "stale-evidence"
    , "self-observer"
    , "authority-bypass"
    , "residue-or-teardown-leakage"
    , "generated-or-legacy-input-smuggling"
    , "production-selector-omission"
    , "oracle-selector-omission"
    , "build-selector-omission"
    , "changed-subject-unassigned-row-red"
    ]

requiredFindingCodes :: [Text]
requiredFindingCodes =
    [ "SABOTAGE-CONSTANT-SUCCESS"
    , "SABOTAGE-NO-OP-SUBJECT"
    , "SABOTAGE-WRONG-OUTPUT"
    , "SABOTAGE-EMPTY-DISCOVERY"
    , "SABOTAGE-MISSING-SUBJECT"
    , "SABOTAGE-MISSING-ORACLE"
    , "SABOTAGE-SKIPPED-MUTANT"
    , "SABOTAGE-WRONG-LOCUS"
    , "SABOTAGE-STALE-EVIDENCE"
    , "SABOTAGE-SELF-OBSERVER"
    , "SABOTAGE-AUTHORITY-BYPASS"
    , "SABOTAGE-RESIDUE"
    , "SABOTAGE-SMUGGLED-INPUT"
    , "SABOTAGE-PRODUCTION-SELECTOR-OMISSION"
    , "SABOTAGE-ORACLE-SELECTOR-OMISSION"
    , "SABOTAGE-BUILD-SELECTOR-OMISSION"
    , "SABOTAGE-UNASSIGNED-ROW-RED"
    ]

requiredCaseRows :: [(Text, Text)]
requiredCaseRows =
    [ ("constant-success", "Pass criterion")
    , ("no-op-subject", "Subject")
    , ("wrong-output", "Oracle")
    , ("empty-discovery", "Discovery")
    , ("missing-subject", "Subject")
    , ("missing-oracle", "Oracle")
    , ("skipped-or-no-op-mutant", "Mutants")
    , ("wrong-locus", "Mutants")
    , ("stale-evidence", "Freshness")
    , ("self-observer", "Observer")
    , ("authority-bypass", "Authority/bypass")
    , ("residue-or-teardown-leakage", "Residue")
    , ("generated-or-legacy-input-smuggling", "Cleanroom")
    , ("production-selector-omission", "Mutants")
    , ("oracle-selector-omission", "Mutants")
    , ("build-selector-omission", "Mutants")
    , ("changed-subject-unassigned-row-red", "Mutants")
    ]

requiredCaseContractRows :: [(Text, FilePath, Text, Text, Text)]
requiredCaseContractRows =
    zipWith4
        (\name subject operator (code, row) -> (name, subject, operator, code, row))
        requiredCaseNames
        requiredCaseSubjects
        requiredCaseOperators
        (zip requiredFindingCodes (map snd requiredCaseRows))

requiredCaseSubjects :: [FilePath]
requiredCaseSubjects =
    [ "src/validation-kernel/Amoebius/Validation/GatePass/Internal.hs"
    , "src/validation-kernel/Amoebius/Validation/PhaseZeroRun/Internal.hs"
    , "src/validation-kernel/Amoebius/Validation/Documentation/Internal.hs"
    , "src/validation-kernel/Amoebius/Validation/SourceClosure/Internal.hs"
    , "src/validation-kernel/Amoebius/Validation/CompilerSubjectRegistry/Internal.hs"
    , "src/validation-kernel/Amoebius/Validation/PhaseContract/Internal.hs"
    , "src/validation-kernel/Amoebius/Validation/MutationCoverage.hs"
    , "src/validation-kernel/Amoebius/Validation/Gate/Internal.hs"
    , "src/validation-kernel/Amoebius/Validation/Evidence/Internal.hs"
    , "src/validation-kernel/Amoebius/Validation/Evidence.hs"
    , "src/validation-kernel/Amoebius/Validation/PolicyContract/Internal.hs"
    , "src/validation-kernel/Amoebius/Validation/StatusProjection/Internal.hs"
    , "src/validation-kernel/Amoebius/Validation/SourceConsumerGraph/Internal.hs"
    , "src/validation-kernel/Amoebius/Validation/CompilerSourceGraph/Internal.hs"
    , "src/validation-kernel/Amoebius/Validation/PhaseSemanticContract.hs"
    , "src/validation-kernel/Amoebius/Validation/CompilerBuildInfo/Internal.hs"
    , "src/validation-kernel/Amoebius/Validation/Dispatch/Internal.hs"
    ]

requiredCaseOperators :: [Text]
requiredCaseOperators =
    [ "qualification-" <> name <> "-mutation"
    | name <- requiredCaseNames
    ]

requiredBoundaryResults :: [(Text, Bool)]
requiredBoundaryResults =
    [ ("subjects.exact", True)
    , ("subjects.plus-one", True)
    , ("controls.exact", True)
    , ("controls.plus-one", True)
    , ("observations.exact", True)
    , ("observations.plus-one", True)
    , ("findings.exact", True)
    , ("findings.plus-one", True)
    , ("name-bytes.exact", True)
    , ("name-bytes.plus-one", True)
    , ("path-bytes.exact", True)
    , ("path-bytes.plus-one", True)
    , ("value-bytes.exact", True)
    , ("value-bytes.plus-one", True)
    , ("detail-bytes.exact", True)
    , ("detail-bytes.plus-one", True)
    , ("transcript-bytes.exact", True)
    , ("transcript-bytes.plus-one", True)
    , ("utf8.exact", True)
    , ("utf8.plus-one", True)
    , ("canonical.exact", True)
    , ("canonical.plus-one", True)
    ]

verifierFixtureProblems :: [String]
verifierFixtureProblems =
    concat
        [ expectEqual
            "verifier fixture labels are unique"
            (length qualificationInternalTestVerifierResults)
            (Map.size verifierResults)
        , expectEqual
            "verifier fixture labels are exact"
            (Set.fromList expectedVerifierLabels)
            (Map.keysSet verifierResults)
        , concatMap expectVerifierRight expectedRightVerifierLabels
        , concatMap (uncurry expectVerifierCode) expectedVerifierCodes
        , concatMap expectCaseContractRefusals requiredCaseNames
        , canonicalDigestProblems
        ]
  where
    verifierResults = Map.fromList qualificationInternalTestVerifierResults
    expectVerifierRight label = case Map.lookup label verifierResults of
        Just (Right digest)
            | sha256Text digest -> []
            | otherwise -> [Text.unpack label <> ": verifier minted a malformed digest " <> Text.unpack digest]
        Just (Left (code, subject, detail)) ->
            [ Text.unpack label
                <> ": expected verified protocol, observed "
                <> Text.unpack code
                <> " at "
                <> subject
                <> ": "
                <> Text.unpack detail
            ]
        Nothing -> [Text.unpack label <> ": verifier fixture result is absent"]
    expectVerifierCode label expectedCode = case Map.lookup label verifierResults of
        Just (Left (code, _, _)) -> expectEqual (Text.unpack label <> " refusal code") expectedCode code
        Just (Right digest) -> [Text.unpack label <> ": unexpectedly minted " <> Text.unpack digest]
        Nothing -> [Text.unpack label <> ": verifier fixture result is absent"]
    expectCaseContractRefusals caseName =
        concat
            [ expectExactCaseRefusal
                (prefix <> caseName)
                caseName
                ("qualification sabotage " <> caseName <> " is invalid: " <> detail)
            | (prefix, detail) <- caseContractNegativeDetails
            ]
    expectExactCaseRefusal label caseName expectedDetail = case Map.lookup label verifierResults of
        Just (Left (code, subject, detail)) ->
            expectEqual (Text.unpack label <> " exact code") "QUALIFICATION-CASE-INVALID" code
                <> expectEqual (Text.unpack label <> " exact subject") (Text.unpack caseName) subject
                <> expectEqual (Text.unpack label <> " exact detail") expectedDetail detail
        observed -> [Text.unpack label <> ": expected exact case refusal, observed " <> show observed]
    canonicalDigestProblems = case (Map.lookup "valid" verifierResults, Map.lookup "canonical-repeat" verifierResults, Map.lookup "canonical-field-change" verifierResults) of
        (Just (Right valid), Just (Right repeated), Just (Right changed)) ->
            expectEqual "canonical repeat digest" valid repeated
                <> expectEqual "canonical valid golden" expectedValidQualificationDigest valid
                <> expectEqual "canonical changed-field golden" expectedChangedQualificationDigest changed
                <> ["canonical field contribution did not change the protocol digest" | changed == valid]
        observed -> ["canonical digest fixture branches were not all verified: " <> show observed]

expectedValidQualificationDigest, expectedChangedQualificationDigest :: Text
expectedValidQualificationDigest = "7633e530ac12c632d5713313b77d822c1fe6f0b714a6aadf76ac6f92bb227a97"
expectedChangedQualificationDigest = "81a4d549bd4826683d6915fb554bba805d7587a8426d26ea4777c495d5915d70"

expectedRightVerifierLabels :: [Text]
expectedRightVerifierLabels =
    [ "valid"
    , "canonical-repeat"
    , "canonical-field-change"
    , "bound.subjects.exact"
    , "bound.controls.exact"
    , "bound.findings.exact"
    , "bound.transcript-bytes.exact"
    ]

expectedVerifierCodes :: [(Text, Text)]
expectedVerifierCodes =
    [ ("join.clean-run", "QUALIFICATION-CLEAN-SUBJECT-INVALID")
    , ("join.case-run", "QUALIFICATION-CASE-INVALID")
    , ("join.case-run-changed-executable", "QUALIFICATION-CASE-INVALID")
    , ("join.control-run", "QUALIFICATION-CASE-INVALID")
    , ("join.teardown-run", "QUALIFICATION-TEARDOWN-INVALID")
    , ("clean.red", "QUALIFICATION-CLEAN-SUBJECT-INVALID")
    , ("changed-subject.preimage", "QUALIFICATION-CASE-INVALID")
    , ("changed-subject.no-change", "QUALIFICATION-CASE-INVALID")
    , ("changed-executable.preimage", "QUALIFICATION-CASE-INVALID")
    , ("changed-executable.no-change", "QUALIFICATION-CASE-INVALID")
    , ("controls.inventory", "QUALIFICATION-CASE-INVALID")
    , ("controls.red", "QUALIFICATION-CASE-INVALID")
    , ("teardown.residue", "QUALIFICATION-TEARDOWN-INVALID")
    , ("teardown.red", "QUALIFICATION-TEARDOWN-INVALID")
    , ("bound.subjects.plus-one", "QUALIFICATION-ATTEMPT-SHAPE-INVALID")
    , ("bound.controls.plus-one", "QUALIFICATION-ATTEMPT-SHAPE-INVALID")
    , ("bound.observations.plus-one", "QUALIFICATION-ATTEMPT-SHAPE-INVALID")
    , ("bound.findings.plus-one", "QUALIFICATION-ATTEMPT-SHAPE-INVALID")
    , ("bound.transcript-bytes.plus-one", "QUALIFICATION-CLEAN-SUBJECT-INVALID")
    ]
        <> [("run." <> label, "QUALIFICATION-RUN-IDENTITY-INVALID") | label <- runFixtureLabels]
        <> [ (prefix <> caseName, "QUALIFICATION-CASE-INVALID")
           | prefix <- ["slot-identity.", "assigned-code.", "assigned-locus.", "assigned-subject.", "operator."]
           , caseName <- requiredCaseNames
           ]

expectedVerifierLabels :: [Text]
expectedVerifierLabels = expectedRightVerifierLabels <> map fst expectedVerifierCodes

caseContractNegativeDetails :: [(Text, Text)]
caseContractNegativeDetails =
    [ ("slot-identity.", "case slot embeds a different run or case identity")
    , ("assigned-code.", "assigned refusal code is not the exact independently registered code")
    , ("assigned-locus.", "assigned gate-row locus is not the exact independently registered locus")
    , ("assigned-subject.", "assigned refusal subject is not the changed production subject")
    , ("operator.", "mutation operator is not the exact independently registered operator")
    ]

runFixtureLabels :: [Text]
runFixtureLabels =
    [ "snapshot"
    , "executable-path"
    , "executable-digest"
    , "harness"
    , "oracle"
    , "compiler"
    , "compiler-run"
    , "toolchain"
    , "toolchain-attestation"
    , "execution"
    ]

sha256Text :: Text -> Bool
sha256Text value =
    Text.length value == 64
        && Text.all (\character -> (character >= '0' && character <= '9') || (character >= 'a' && character <= 'f')) value

binderFixtureProblems :: [String]
binderFixtureProblems =
    expectEqual
        "candidate binder labels"
        (map fst expectedBinderResults)
        (map fst qualificationInternalTestBinderResults)
        <> concatMap checkExpected expectedBinderResults
  where
    observed = Map.fromList qualificationInternalTestBinderResults
    verifier = Map.fromList qualificationInternalTestVerifierResults
    checkExpected (label, expected) = case (Map.lookup label observed, expected) of
        (Just (Right digest), Right ()) ->
            [Text.unpack label <> ": binder returned a malformed digest " <> Text.unpack digest | not (sha256Text digest)]
                <> expectEqual
                    (Text.unpack label <> " binder/verifier digest")
                    (Map.lookup "valid" verifier)
                    (Just (Right digest))
        (Just (Left actual), Left expectedProblem) ->
            expectEqual (Text.unpack label <> " binder refusal") expectedProblem actual
        (actual, _) -> [Text.unpack label <> ": unexpected binder result " <> show actual]

expectedBinderResults :: [(Text, Either (Text, FilePath, Text) ())]
expectedBinderResults =
    [ ("valid", Right ())
    ,
        ( "snapshot"
        , Left
            ( "QUALIFICATION-CANDIDATE-SNAPSHOT-MISMATCH"
            , "<qualification-candidate-source>"
            , "the qualified protocol and candidate name different opening source snapshots"
            )
        )
    , ("executable-path", Left executableMismatch)
    , ("executable-digest-missing", Left executableMismatch)
    , ("executable-digest-wrong", Left executableMismatch)
    ,
        ( "protocol-digest-malformed"
        , Left
            ( "QUALIFICATION-PROTOCOL-DIGEST-MALFORMED"
            , "<qualified-validation-protocol>"
            , "the qualified protocol digest is not a lowercase SHA-256 identity"
            )
        )
    ,
        ( "protocol-digest-mismatch"
        , Left
            ( "QUALIFICATION-PROTOCOL-DIGEST-MISMATCH"
            , "<qualified-validation-protocol>"
            , "the qualified protocol digest does not equal the recomputed canonical transcript identity"
            )
        )
    ]
  where
    executableMismatch =
        ( "QUALIFICATION-CANDIDATE-EXECUTABLE-MISMATCH"
        , "<qualification-candidate-executable>"
        , "the qualified protocol and candidate name different executable paths or byte identities"
        )

cleanPublicDiagnostic :: CheckResult
cleanPublicDiagnostic =
    checkQualificationReportDiagnostic baseline (zipWith cleanRun allSabotages requiredFindingCodes)
  where
    baseline =
        DiagnosticQualificationBaseline
            { qualificationHarnessDigest = harnessDigest
            , qualificationSubjects = Map.singleton productionSubject beforeDigest
            , qualificationControlNames = Set.singleton (checkName unaffectedControl)
            }

cleanRun :: Sabotage -> Text -> DiagnosticSabotageRun
cleanRun caseIdentity expectedCode =
    DiagnosticSabotageRun
        { sabotage = caseIdentity
        , sabotageHarnessDigest = harnessDigest
        , sabotageWitness =
            DiagnosticMutationWitness
                { mutationOperator = "independent-public-diagnostic-fixture"
                , mutationBeforeDigest = beforeDigest
                , mutationAfterDigest = afterDigest
                , mutationChangedSubject = productionSubject
                }
        , sabotageResult =
            CheckResult
                { checkName = "qualification-sabotage." <> sabotageName caseIdentity
                , checkObservations = [observation "observed-locus" (Text.pack productionSubject)]
                , checkFindings = [finding expectedCode productionSubject "independently expected refusal"]
                }
        , sabotageUnaffectedControls = [unaffectedControl]
        }

unaffectedControl :: CheckResult
unaffectedControl =
    CheckResult
        { checkName = "control.package-hidden-boundary"
        , checkObservations = [observation "control-observation" "green"]
        , checkFindings = []
        }

productionSubject :: FilePath
productionSubject = "src/validation-kernel/Amoebius/Validation/Gate.hs"

harnessDigest :: Text
harnessDigest = Text.replicate 64 "a"

beforeDigest :: Text
beforeDigest = Text.replicate 64 "b"

afterDigest :: Text
afterDigest = Text.replicate 64 "c"

expectRefusal :: String -> Either QualificationProblem value -> [String]
expectRefusal label result = case result of
    Left problem ->
        concat
            [ expectEqual (label <> " code") "QUALIFICATION-NOT-EXECUTED" (qualificationProblemCode problem)
            , expectEqual (label <> " subject") "Amoebius.Validation.Gate.Internal" (qualificationProblemSubject problem)
            , expectEqual
                (label <> " detail")
                "no qualification supervisor executed the exact clean run and closed seventeen-case sabotage corpus"
                (qualificationProblemDetail problem)
            ]
    Right _ -> [label <> ": unexpectedly minted authority"]

expectEqual :: (Eq value, Show value) => String -> value -> value -> [String]
expectEqual label expected actual
    | expected == actual = []
    | otherwise = [label <> ": expected=" <> show expected <> "; observed=" <> show actual]
