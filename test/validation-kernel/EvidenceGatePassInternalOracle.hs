{-# LANGUAGE OverloadedStrings #-}

module EvidenceGatePassInternalOracle (
    runEvidenceGatePassInternalOracle,
) where

import Amoebius.Validation.BootstrapQualification.Internal
  ( bootstrapQualificationInternalTestProtocol
  )
import Amoebius.Validation.BootstrapTrust.Internal
  ( GenesisTrust
  , genesisTrustInternalTestAcquire
  , genesisTrustInternalTestExpectedInputs
  )
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
import Amoebius.Validation.GatePass.Internal (verifyPublishedGatePass)
import Amoebius.Validation.Legacy.Internal
  ( LegacyId (LtdBoot001)
  , LegacyObservedState (..)
  , legacyBootstrapDueInternalTestCheck
  , legacyBootstrapPrerequisiteInternalTestObservation
  )
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
    Observation (..),
    observation,
 )
import Control.Monad (unless)
import Data.ByteString qualified as ByteString
import Data.Text qualified as Text
import System.Directory (renameFile)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)

runEvidenceGatePassInternalOracle :: IO ()
runEvidenceGatePassInternalOracle = case (genesisTrustFixture, mismatchedCompilerTrustFixture) of
    (Left findings, _) ->
        finishDiagnostics
            "EvidenceGatePassInternalOracle"
            ["the exact internal GenesisTrust fixture refused: " <> show findings]
    (_, Left findings) ->
        finishDiagnostics
            "EvidenceGatePassInternalOracle"
            ["the mismatched-compiler GenesisTrust fixture refused before the intended binding check: " <> show findings]
    (Right trust, Right mismatchedCompilerTrust) ->
        runWithGenesisTrust trust mismatchedCompilerTrust

runWithGenesisTrust :: GenesisTrust -> GenesisTrust -> IO ()
runWithGenesisTrust trust mismatchedCompilerTrust =
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
                    (CheckResult "phase-00" [observation "subject" "raw\tcolumns"] [])
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
        let newlineObservationEvidence =
                captureDispatchCandidateEvidence
                    0
                    digest
                    digest
                    (Just digest)
                    (Just digest)
                    (root </> "source-bound-validator")
                    (Just digest)
                    ["validate", "phase", "00"]
                    (CheckResult "phase-00" [observation "subject" "two\nrecords"] [])
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
        let debtEvidence = analyzeAcquiredSourceDebt acquired
            qualification = bootstrapQualificationInternalTestProtocol digest
            phaseZeroRun =
                assembleAcquiredPhaseZeroRun
                    acquired
                    trust
                    qualification
                    debtEvidence
            mismatchedCompilerRun =
                assembleAcquiredPhaseZeroRun
                    acquired
                    mismatchedCompilerTrust
                    qualification
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
            baseQualificationCheck = acquiredCandidateQualificationCheck evidence
            forcedDueLegacyCheck = legacyBootstrapDueInternalTestCheck LtdBoot001
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
            mismatchedCompilerEvidence =
                captureFinalizedDispatchCandidateEvidence
                    mismatchedCompilerRun
                    (Right acquired)
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
                <> expectRowPassed
                    "a tab-framed raw Subject value remains one well-formed observation record"
                    SubjectRow
                    True
                    evidence
                <> expectRowPassed
                    "a newline-bearing Subject value cannot inject a second observation record"
                    SubjectRow
                    False
                    newlineObservationEvidence
                <> expectCheckFindingCode
                    "the incomplete capture API cannot manufacture legacy-closure authority"
                    "GATE-LEGACY-CLOSURE-UNVERIFIED"
                    baseLegacyCheck
                <> expectCheckFindingCode
                    "the incomplete capture API cannot manufacture finite qualification authority"
                    "GATE-QUALIFICATION-UNVERIFIED"
                    baseQualificationCheck
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
                    "the same acquired closing snapshot passes freshness"
                    FreshnessRow
                    True
                    finalizedEvidence
                <> expectRowPassed
                    "a different closing snapshot refuses freshness"
                    FreshnessRow
                    False
                    changedClosingEvidence
                <> expectRowPassed
                    "an unavailable closing snapshot refuses freshness"
                    FreshnessRow
                    False
                    unavailableClosingEvidence
                <> expectRowPassed
                    "the refusing Subject keeps bootstrap legacy closure red"
                    LegacyClosureRow
                    False
                    finalizedEvidence
                <> expectRowPassed
                    "the sealed finite bootstrap qualification passes its finalized row"
                    QualificationRow
                    True
                    finalizedEvidence
                <> expectRowPassed
                    "a qualification receipt from a different compiler path refuses"
                    QualificationRow
                    False
                    mismatchedCompilerEvidence
                <> expectEqual
                    "the finalized candidate projects the sealed qualification transcript exactly"
                    ( CheckResult
                        "gate-qualification"
                        [observation "qualification.protocol.sha256" expectedQualificationDigest]
                        []
                    )
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
                <> expectFindingDetailEqual
                    "the derived pass criterion preserves the exact refusing-row order"
                    "GATE-PASS-CRITERION-REFUSED"
                    "<gate-finalization>"
                    "one or more prerequisite rows refused: Subject,Legacy closure"
                    finalizedPassCheck
                <> expectCheckFindingCode
                    "bootstrap legacy closure refuses when a non-circular prerequisite is red"
                    "LEGACY-BOOTSTRAP-PREREQUISITES"
                    finalizedLegacyCheck
                <> expectFindingDetailEqual
                    "bootstrap legacy closure retains the exact prerequisite order and every status"
                    "LEGACY-BOOTSTRAP-PREREQUISITES"
                    "Amoebius.Validation.Legacy"
                    expectedBootstrapPremiseDetail
                    finalizedLegacyCheck
                <> expectObservation
                    "the bootstrap prerequisite observation reports its refusal instead of a pass"
                    "legacy.bootstrap.prerequisites"
                    ("refused:" <> expectedBootstrapPremiseDetail)
                    finalizedLegacyCheck
                <> expectEqual
                    "the bootstrap prerequisite projection distinguishes zero, open, and refused states"
                    [ observation "legacy.bootstrap.prerequisites" "zero"
                    , observation "legacy.bootstrap.prerequisites" "open:2:open-digest"
                    , observation "legacy.bootstrap.prerequisites" "refused:refusal-detail"
                    ]
                    [ legacyBootstrapPrerequisiteInternalTestObservation LegacyObservedZero
                    , legacyBootstrapPrerequisiteInternalTestObservation (LegacyObservedOpen 2 "open-digest")
                    , legacyBootstrapPrerequisiteInternalTestObservation (LegacyObservationRefused "refusal-detail")
                    ]
                <> expectObservation
                    "the finite bootstrap has no Phase-0-owned legacy debt"
                    "legacy.bootstrap.due-count"
                    "0"
                    finalizedLegacyCheck
                <> expectNoFindingCode
                    "the finite bootstrap does not execute later owner-domain analyzers"
                    "LEGACY-OBSERVATION-REFUSED"
                    finalizedLegacyCheck
                <> expectNoFindingCode
                    "later-owned legacy debt is not reported as due at Phase 0"
                    "LEGACY-BOOTSTRAP-DUE"
                    finalizedLegacyCheck
                <> expectEqual
                    "a Phase-0-owned active ID increments the due count and refuses with the exact finding"
                    ( CheckResult
                        "legacy-bootstrap-due-internal-test"
                        [observation "legacy.bootstrap.due-count" "1"]
                        [ Finding
                            "LEGACY-BOOTSTRAP-DUE"
                            "Amoebius.Validation.Legacy/LTD-BOOT-001"
                            "LTD-BOOT-001 is still assigned to Phase 0 instead of its falsifiable capability owner"
                        ]
                    )
                    forcedDueLegacyCheck
                <> expectFindingCode
                    "a finalized current candidate with open prerequisites still cannot mint a pass"
                    "GATE-PASS-ROW-NOT-GREEN"
                    finalizedVerification
            )
  where
    digest = Text.replicate 64 "a"

genesisTrustFixture :: Either [Finding] GenesisTrust
genesisTrustFixture =
    genesisTrustInternalTestAcquire
        "9.12.4"
        "/genesis/bin/ghc"
        "/genesis/lib/ghc-9.12.4"
        "linux"
        "x86_64"
        genesisTrustInternalTestExpectedInputs

mismatchedCompilerTrustFixture :: Either [Finding] GenesisTrust
mismatchedCompilerTrustFixture =
    genesisTrustInternalTestAcquire
        "9.12.4"
        "/different-genesis/bin/ghc"
        "/genesis/lib/ghc-9.12.4"
        "linux"
        "x86_64"
        genesisTrustInternalTestExpectedInputs

expectedQualificationDigest :: Text.Text
expectedQualificationDigest = "54e6289e14c7b0e7ad9acc2dfc4c1e3d027d0eef7f5c4c3fe7c292761d0e06a6"

bootstrapPremiseFragments :: [Text.Text]
bootstrapPremiseFragments =
    [ "Claim=passed"
    , "Subject=refused"
    , "Command=passed"
    , "Oracle=passed"
    , "Positive controls=passed"
    , "Paired negatives=passed"
    , "Mutants=passed"
    , "Discovery=passed"
    , "Challenge=passed"
    , "Observer=passed"
    , "Authority/bypass=passed"
    , "Freshness=passed"
    , "Qualification=passed"
    , "Cleanroom=passed"
    , "Predecessor=passed"
    , "Residue=passed"
    ]

expectedBootstrapPremiseDetail :: Text.Text
expectedBootstrapPremiseDetail =
    "gate-completion prerequisites are not all execution-derived green: "
        <> Text.intercalate "," bootstrapPremiseFragments

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

expectNoFindingCode :: String -> Text.Text -> CheckResult -> [String]
expectNoFindingCode label code result
    | any ((== code) . findingCode) (checkFindings result) =
        [label <> ": unexpectedly observed " <> Text.unpack code <> " in " <> show (checkFindings result)]
    | otherwise = []

expectObservation :: String -> Text.Text -> Text.Text -> CheckResult -> [String]
expectObservation label key expected result =
    case [observationValue item | item <- checkObservations result, observationKey item == key] of
        [actual]
            | actual == expected -> []
            | otherwise -> [label <> ": expected=" <> Text.unpack expected <> "; observed=" <> Text.unpack actual]
        observed -> [label <> ": expected one observation, observed=" <> show observed]

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
