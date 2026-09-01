{-# LANGUAGE OverloadedStrings #-}

module EvidenceGatePassInternalOracle (
    runEvidenceGatePassInternalOracle,
) where

import Amoebius.Validation.CompilerSourceGraph.Internal (acquireCompilerSourceGraph)
import Amoebius.Validation.Evidence.Internal (
    AcquiredCandidateEvidence,
    GateRow (..),
    acquiredCandidateBytes,
    acquiredCandidateLegacyClosureCheck,
    acquiredCandidatePassCriterionCheck,
    acquiredCandidateQualificationCheck,
    acquiredCandidateRows,
    acquiredCandidateSourceClosing,
    acquiredCandidateSourceOpening,
    acquiredCandidateSubjectCheck,
    captureDispatchCandidateEvidence,
    captureFinalizedDispatchCandidateEvidence,
    capturedRow,
    gateRowEvidencePassed,
    publishedCandidatePath,
    recheckPublishedCandidateEvidence,
    writeAcquiredCandidateEvidence,
 )
import Amoebius.Validation.Gate.Internal qualified as Gate
import Amoebius.Validation.GatePass.Internal (verifyPublishedGatePass)
import Amoebius.Validation.PhaseZeroRun.Internal (
    acquiredPhaseZeroRunCheck,
    assembleAcquiredPhaseZeroRun,
 )
import Amoebius.Validation.SourceClosure.Internal (
    IndexEntry (..),
    IndexMode (RegularFile),
    SnapshotProblem (EmptyIndex),
    SourceSnapshot (..),
    TrackedEntry (..),
    sourceClosureInternalTestAcquire,
 )
import Amoebius.Validation.SourceDebtBaseline.Internal (analyzeAcquiredSourceDebt)
import Amoebius.Validation.Types (
    CheckResult (..),
    Finding (..),
    observation,
 )
import Control.Monad (unless)
import Data.ByteString qualified as ByteString
import Data.Text qualified as Text
import System.Directory (renameFile)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)

runEvidenceGatePassInternalOracle :: IO ()
runEvidenceGatePassInternalOracle =
    withSystemTempDirectory "amoebius-published-gate-evidence" $ \root -> do
        let evidence =
                captureDispatchCandidateEvidence
                    0
                    digest
                    digest
                    (Just digest)
                    (Just digest)
                    (root </> "source-bound-validator")
                    (Just digest)
                    ["validate", "phase", "00"]
                    (CheckResult "phase-00" [observation "subject" "observed"] [])
        firstPublication <- writeAcquiredCandidateEvidence root evidence
        firstReadback <- recheckPublishedCandidateEvidence firstPublication
        verification <- verifyPublishedGatePass firstPublication
        secondPublication <- writeAcquiredCandidateEvidence root evidence
        exactBytes <- ByteString.readFile (publishedCandidatePath firstPublication)
        ByteString.writeFile (publishedCandidatePath firstPublication) "tampered"
        tamperedReadback <- recheckPublishedCandidateEvidence firstPublication
        ByteString.writeFile (publishedCandidatePath firstPublication) exactBytes
        restoredReadback <- recheckPublishedCandidateEvidence firstPublication
        let replacementPath = publishedCandidatePath firstPublication <> ".replacement"
        ByteString.writeFile replacementPath exactBytes
        renameFile replacementPath (publishedCandidatePath firstPublication)
        replacementReadback <- recheckPublishedCandidateEvidence firstPublication
        let wrongArgvEvidence =
                captureDispatchCandidateEvidence
                    0
                    digest
                    digest
                    (Just digest)
                    (Just digest)
                    (root </> "source-bound-validator")
                    (Just digest)
                    ["phase", "00"]
                    (CheckResult "phase-00" [observation "subject" "observed"] [])
        wrongArgvPublication <- writeAcquiredCandidateEvidence root wrongArgvEvidence
        wrongArgvVerification <- verifyPublishedGatePass wrongArgvPublication
        let acquireFixture identity =
                sourceClosureInternalTestAcquire
                    SourceSnapshot
                        { snapshotRoot = root
                        , snapshotIdentity = identity
                        , snapshotEntries =
                            [ TrackedEntry
                                { trackedIndex =
                                    IndexEntry
                                        { indexPath = "DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md"
                                        , indexMode = RegularFile
                                        , indexObjectId = Text.replicate 40 "0"
                                        }
                                , trackedBytes = "# Active legacy register\n"
                                }
                            ]
                        }
            acquired = acquireFixture digest
        compilerAttempt <- acquireCompilerSourceGraph acquired
        let debtEvidence = analyzeAcquiredSourceDebt acquired
            phaseZeroRun =
                assembleAcquiredPhaseZeroRun
                    acquired
                    compilerAttempt
                    Gate.currentQualifiedValidationProtocol
                    debtEvidence
            finalizedEvidence =
                captureFinalizedDispatchCandidateEvidence
                    phaseZeroRun
                    (Right acquired)
                    (Just digest)
                    (Just digest)
                    (root </> "source-bound-validator")
                    (Just digest)
                    ["validate", "phase", "00"]
            baseLegacyCheck = acquiredCandidateLegacyClosureCheck evidence
            finalizedLegacyCheck = acquiredCandidateLegacyClosureCheck finalizedEvidence
            finalizedPassCheck = acquiredCandidatePassCriterionCheck finalizedEvidence
            finalizedQualificationCheck = acquiredCandidateQualificationCheck finalizedEvidence
            finalizedSubjectCheck = acquiredCandidateSubjectCheck finalizedEvidence
            changedClosingDigest = Text.replicate 64 "b"
            changedClosingEvidence =
                captureFinalizedDispatchCandidateEvidence
                    phaseZeroRun
                    (Right (acquireFixture changedClosingDigest))
                    (Just digest)
                    (Just digest)
                    (root </> "source-bound-validator")
                    (Just digest)
                    ["validate", "phase", "00"]
            unavailableClosingEvidence =
                captureFinalizedDispatchCandidateEvidence
                    phaseZeroRun
                    (Left [EmptyIndex])
                    (Just digest)
                    (Just digest)
                    (root </> "source-bound-validator")
                    (Just digest)
                    ["validate", "phase", "00"]
        finalizedPublication <- writeAcquiredCandidateEvidence root finalizedEvidence
        finalizedVerification <- verifyPublishedGatePass finalizedPublication
        finishDiagnostics
            "EvidenceGatePassInternalOracle"
            ( expectEqual
                "durable publication re-acquires the exact in-memory candidate"
                (Right evidence)
                firstReadback
                <> expectEqual
                    "idempotent publication resolves to the same content address"
                    (publishedCandidatePath firstPublication)
                    (publishedCandidatePath secondPublication)
                <> expectEqual
                    "the published file contains the exact canonical candidate bytes"
                    (acquiredCandidateBytes evidence)
                    exactBytes
                <> expectFindingCode
                    "a published but deliberately incomplete dispatcher candidate cannot mint a pass"
                    "GATE-PASS-ROW-NOT-GREEN"
                    verification
                <> expectFindingCode
                    "verification re-acquisition rejects publication bytes changed after the receipt"
                    "GATE-PASS-PUBLICATION"
                    tamperedReadback
                <> expectEqual
                    "restoring exact bytes in the original inode re-establishes the durable publication"
                    (Right evidence)
                    restoredReadback
                <> expectFindingCode
                    "an exact-byte replacement inode cannot impersonate the durably published object"
                    "GATE-PASS-PUBLICATION"
                    replacementReadback
                <> expectFindingCode
                    "a wrapper that omitted the public validate argv cannot impersonate the exact command"
                    "GATE-PASS-ROW-NOT-GREEN"
                    wrongArgvVerification
                <> expectFindingCode
                    "the verifier independently rejects the wrapper's observed argv"
                    "GATE-PASS-COMMAND"
                    wrongArgvVerification
                <> expectCheckFindingCode
                    "the incomplete capture API cannot manufacture legacy-closure authority"
                    "GATE-LEGACY-CLOSURE-UNVERIFIED"
                    baseLegacyCheck
                <> expectRowPassed
                    "the finalized Subject is recomputed from the opaque acquired Phase-0 run"
                    SubjectRow
                    False
                    finalizedEvidence
                <> expectEqual
                    "the finalized Subject retains the exact recomputed acquired-run findings"
                    (checkFindings (acquiredPhaseZeroRunCheck phaseZeroRun))
                    (checkFindings finalizedSubjectCheck)
                <> expectEqual
                    "the finalized opening identity is derived from the acquired run rather than a caller argument"
                    digest
                    (acquiredCandidateSourceOpening finalizedEvidence)
                <> expectEqual
                    "the finalized closing identity is derived from the freshly reacquired snapshot value"
                    changedClosingDigest
                    (acquiredCandidateSourceClosing changedClosingEvidence)
                <> expectEqual
                    "a failed closing acquisition cannot supply a digest-shaped freshness value"
                    ""
                    (acquiredCandidateSourceClosing unavailableClosingEvidence)
                <> expectRowPassed
                    "the still-open legacy inventory refuses its own row"
                    LegacyClosureRow
                    False
                    finalizedEvidence
                <> expectRowPassed
                    "qualification refusal is retained in its own finalized gate row"
                    QualificationRow
                    False
                    finalizedEvidence
                <> expectCheckFindingCode
                    "the finalized candidate consumes the package-hidden qualification authority"
                    "QUALIFICATION-NOT-EXECUTED"
                    finalizedQualificationCheck
                <> expectRowPassed
                    "pass criterion is derived after and refuses with legacy closure"
                    PassCriterionRow
                    False
                    finalizedEvidence
                <> expectCheckFindingCode
                    "the derived pass criterion reports the refusing prerequisite"
                    "GATE-PASS-CRITERION-REFUSED"
                    finalizedPassCheck
                <> expectFindingContains
                    "pass criterion is derived after and names the sealed legacy row"
                    "GATE-PASS-CRITERION-REFUSED"
                    "<gate-finalization>"
                    ["Legacy closure"]
                    finalizedPassCheck
                <> expectFindingContains
                    "LTD-VAL-004 observes the exact non-circular prerequisite inventory"
                    "LEGACY-OBSERVATION-REFUSED"
                    "Amoebius.Validation.Legacy/LTD-VAL-004"
                    gateCompletionPremiseFragments
                    finalizedLegacyCheck
                <> expectFindingDetailEqual
                    "LTD-VAL-004 retains the exact prerequisite order and every status"
                    "LEGACY-OBSERVATION-REFUSED"
                    "Amoebius.Validation.Legacy/LTD-VAL-004"
                    expectedGateCompletionDetail
                    finalizedLegacyCheck
                <> expectFindingExcludes
                    "LTD-VAL-004 no longer reports an unimplemented owner analyzer"
                    "LEGACY-OBSERVATION-REFUSED"
                    "Amoebius.Validation.Legacy/LTD-VAL-004"
                    "the closed owner-domain analyzer has not been implemented"
                    finalizedLegacyCheck
                <> expectFindingContains
                    "a static owner-domain zero cannot bypass its executed reintroduction negative"
                    "LEGACY-OBSERVATION-REFUSED"
                    "Amoebius.Validation.Legacy/LTD-SRC-008"
                    ["no executed reintroduction witness"]
                    finalizedLegacyCheck
                <> expectFindingContains
                    "still-unimplemented owner analyzers remain fail-closed"
                    "LEGACY-OBSERVATION-REFUSED"
                    "Amoebius.Validation.Legacy/LTD-VAL-001"
                    ["the closed owner-domain analyzer has not been implemented"]
                    finalizedLegacyCheck
                <> expectFindingCode
                    "a finalized current candidate with open prerequisites still cannot mint a pass"
                    "GATE-PASS-ROW-NOT-GREEN"
                    finalizedVerification
            )
  where
    digest = Text.replicate 64 "a"

gateCompletionPremiseFragments :: [Text.Text]
gateCompletionPremiseFragments =
    [ "Claim=unverified"
    , "Subject=refused"
    , "Command=unverified"
    , "Oracle=unverified"
    , "Positive controls=unverified"
    , "Paired negatives=unverified"
    , "Mutants=unverified"
    , "Discovery=unverified"
    , "Challenge=unverified"
    , "Observer=unverified"
    , "Authority/bypass=unverified"
    , "Freshness=unverified"
    , "Qualification=refused"
    , "Cleanroom=unverified"
    , "Predecessor=passed"
    , "Residue=unverified"
    ]

expectedGateCompletionDetail :: Text.Text
expectedGateCompletionDetail =
    "LTD-VAL-004: gate-completion prerequisites are not all execution-derived green: "
        <> Text.intercalate "," gateCompletionPremiseFragments

expectFindingCode :: String -> Text.Text -> Either [Finding] value -> [String]
expectFindingCode label code result = case result of
    Left findings
        | any ((== code) . findingCode) findings -> []
        | otherwise -> [label <> ": expected " <> Text.unpack code <> ", observed " <> show findings]
    Right _ -> [label <> ": unexpectedly succeeded"]

expectCheckFindingCode :: String -> Text.Text -> CheckResult -> [String]
expectCheckFindingCode label code result
    | any ((== code) . findingCode) (checkFindings result) = []
    | otherwise = [label <> ": expected " <> Text.unpack code <> ", observed " <> show (checkFindings result)]

expectRowPassed :: String -> GateRow -> Bool -> AcquiredCandidateEvidence -> [String]
expectRowPassed label row expected evidence =
    case [ gateRowEvidencePassed candidate
         | candidate <- acquiredCandidateRows evidence
         , capturedRow candidate == row
         ] of
        [actual]
            | actual == expected -> []
            | otherwise -> [label <> ": expected=" <> show expected <> "; observed=" <> show actual]
        observed -> [label <> ": expected one row, observed=" <> show (length observed)]

expectFindingContains :: String -> Text.Text -> FilePath -> [Text.Text] -> CheckResult -> [String]
expectFindingContains label code subject fragments result =
    case matchingFindings code subject result of
        [item]
            | all (`Text.isInfixOf` findingDetail item) fragments -> []
            | otherwise -> [label <> ": detail did not contain every expected fragment; observed=" <> Text.unpack (findingDetail item)]
        observed -> [label <> ": expected one matching finding, observed=" <> show observed]

expectFindingExcludes :: String -> Text.Text -> FilePath -> Text.Text -> CheckResult -> [String]
expectFindingExcludes label code subject fragment result =
    case matchingFindings code subject result of
        [item]
            | not (fragment `Text.isInfixOf` findingDetail item) -> []
            | otherwise -> [label <> ": forbidden fragment remained in detail=" <> Text.unpack (findingDetail item)]
        observed -> [label <> ": expected one matching finding, observed=" <> show observed]

expectFindingDetailEqual :: String -> Text.Text -> FilePath -> Text.Text -> CheckResult -> [String]
expectFindingDetailEqual label code subject expected result =
    case matchingFindings code subject result of
        [item]
            | findingDetail item == expected -> []
            | otherwise -> [label <> ": expected=" <> Text.unpack expected <> "; observed=" <> Text.unpack (findingDetail item)]
        observed -> [label <> ": expected one matching finding, observed=" <> show observed]

matchingFindings :: Text.Text -> FilePath -> CheckResult -> [Finding]
matchingFindings code subject result =
    [ item
    | item <- checkFindings result
    , findingCode item == code
    , findingSubject item == subject
    ]

expectEqual :: (Eq value, Show value) => String -> value -> value -> [String]
expectEqual label expected actual
    | expected == actual = []
    | otherwise = [label <> ": expected=" <> show expected <> "; observed=" <> show actual]

finishDiagnostics :: String -> [String] -> IO ()
finishDiagnostics name diagnostics =
    unless
        (null diagnostics)
        (fail (name <> " failures:\n  " <> Text.unpack (Text.intercalate "\n  " (map Text.pack diagnostics))))
