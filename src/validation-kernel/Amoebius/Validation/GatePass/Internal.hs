{-# LANGUAGE OverloadedStrings #-}

{- | Package-hidden authority produced only after the complete gate binding has
been checked.  The public 'GatePass' records are diagnostic claims; they do
not carry write authority.  Keeping this constructor hidden gives the
status projector a token that cannot be manufactured by an external caller.
-}
module Amoebius.Validation.GatePass.Internal (
    VerifiedGatePass,
    verifiedPassEvidenceDigest,
    verifiedPassPhase,
    verifiedPassProjectionDigest,
    verifiedPassProjectionPostimageDigest,
    verifiedPassSourceDigest,
    recheckVerifiedGatePassPublication,
    verifyPublishedGatePass,
) where

import Amoebius.Validation.Evidence.Internal (
    AcquiredCandidateEvidence,
    CandidateCapture,
    GateRowEvidence,
    PublishedCandidateEvidence,
    acquiredCandidateCapture,
    acquiredCandidateDigest,
    allGateRows,
    captureArchitecture,
    captureArgv,
    captureCleanupObservation,
    captureContractDigest,
    captureExecutableDigest,
    captureExecutablePath,
    captureHarnessDigest,
    captureLane,
    captureObserverDigest,
    captureOracleDigest,
    capturePhase,
    capturePredecessor,
    captureProjectionDigest,
    captureProjectionPostimageDigest,
    captureQualificationDigest,
    captureResidue,
    captureRows,
    captureRunIdentity,
    captureSourceClosing,
    captureSourceOpening,
    captureSubjectDigest,
    captureSubstrate,
    captureToolchainIdentity,
    capturedRow,
    gateRowEvidencePassed,
    predecessorEvidenceMatchesPhase,
    recheckPublishedCandidateEvidence,
    renderGateRow,
 )
import Amoebius.Validation.GatePass (requiredGateRows)
import Amoebius.Validation.PolicyContract.Internal qualified as Policy
import Amoebius.Validation.Types (Finding, finding)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import System.FilePath (isAbsolute)

data VerifiedGatePass = VerifiedGatePass
    { verifiedPhaseValue :: Text
    , verifiedSourceDigestValue :: Text
    , verifiedEvidenceDigestValue :: Text
    , verifiedProjectionDigestValue :: Text
    , verifiedProjectionPostimageDigestValue :: Text
    , verifiedPublicationValue :: PublishedCandidateEvidence
    }
    deriving (Eq, Show)

verifiedPassPhase :: VerifiedGatePass -> Text
verifiedPassPhase = verifiedPhaseValue

verifiedPassSourceDigest :: VerifiedGatePass -> Text
verifiedPassSourceDigest = verifiedSourceDigestValue

verifiedPassEvidenceDigest :: VerifiedGatePass -> Text
verifiedPassEvidenceDigest = verifiedEvidenceDigestValue

verifiedPassProjectionDigest :: VerifiedGatePass -> Text
verifiedPassProjectionDigest = verifiedProjectionDigestValue

verifiedPassProjectionPostimageDigest :: VerifiedGatePass -> Text
verifiedPassProjectionPostimageDigest = verifiedProjectionPostimageDigestValue

verifyPublishedGatePass ::
    PublishedCandidateEvidence ->
    IO (Either [Finding] VerifiedGatePass)
verifyPublishedGatePass published = do
    reacquired <- recheckPublishedCandidateEvidence published
    pure (reacquired >>= verifyAcquiredGatePass published)

verifyAcquiredGatePass ::
    PublishedCandidateEvidence ->
    AcquiredCandidateEvidence ->
    Either [Finding] VerifiedGatePass
verifyAcquiredGatePass published evidence =
    case verificationFindings of
        [] -> case (captureProjectionDigest captured, captureProjectionPostimageDigest captured) of
            (Just projectionDigest, Just postimageDigest) ->
                Right
                    VerifiedGatePass
                        { verifiedPhaseValue = formatOrdinal (capturePhase captured)
                        , verifiedSourceDigestValue = captureSourceOpening captured
                        , verifiedEvidenceDigestValue = acquiredCandidateDigest evidence
                        , verifiedProjectionDigestValue = projectionDigest
                        , verifiedProjectionPostimageDigestValue = postimageDigest
                        , verifiedPublicationValue = published
                        }
            _ -> Left [gateFinding "GATE-PASS-PROJECTION" "status projection or postimage digest is absent"]
        problems -> Left problems
  where
    captured = acquiredCandidateCapture evidence
    phase = capturePhase captured
    rows = captureRows captured
    rowNames = Set.fromList (map (renderGateRow . capturedRow) rows)
    verificationFindings =
        [gateFinding "GATE-PASS-PHASE" "candidate phase is outside the compiled policy domain" | Policy.mkPhaseOrdinal phase == Nothing]
            <> [gateFinding "GATE-PASS-SOURCE" "opening and closing source snapshot digests are not the same lowercase SHA-256" | not (sha256Text (captureSourceOpening captured)) || captureSourceOpening captured /= captureSourceClosing captured]
            <> [gateFinding "GATE-PASS-ROWS" "candidate rows are not the exact closed gate-row inventory" | map capturedRow rows /= allGateRows || rowNames /= requiredGateRows]
            <> [ gateFinding
                    "GATE-PASS-ROW-NOT-GREEN"
                    ("gate row is not execution-derived green: " <> renderGateRow (capturedRow row))
               | row <- rows
               , not (passedRow row)
               ]
            <> [gateFinding "GATE-PASS-RESIDUE" "candidate retains explicit unverified residue" | not (null (captureResidue captured))]
            <> [ gateFinding
                    "GATE-PASS-PREDECESSOR"
                    ( if phase == 0
                        then "Phase 00 requires the typed genesis predecessor"
                        else "a non-genesis phase requires its immediate predecessor's evidence digest"
                    )
               | not (predecessorEvidenceMatchesPhase phase (capturePredecessor captured))
               ]
            <> [ gateFinding "GATE-PASS-IDENTITY" (label <> " is absent or is not a lowercase SHA-256")
               | (label, value) <- digestFields captured
               , maybe True (not . sha256Text) value
               ]
            <> [ gateFinding
                    "GATE-PASS-COMMAND"
                    "the executable path is not absolute or argv is not the exact source-bound phase command"
               | not (isAbsolute (captureExecutablePath captured))
                    || captureArgv captured /= ["validate", "phase", formatOrdinal phase]
                    || any unsafeText (captureArgv captured)
               ]
            <> [ gateFinding "GATE-PASS-EXECUTION-CONTEXT" (label <> " is absent or malformed")
               | (label, value) <- contextFields captured
               , maybe True unsafeText value
               ]

recheckVerifiedGatePassPublication :: VerifiedGatePass -> IO (Either [Finding] ())
recheckVerifiedGatePassPublication verified = do
    reacquired <- recheckPublishedCandidateEvidence (verifiedPublicationValue verified)
    pure $ case reacquired of
        Left problems -> Left problems
        Right evidence
            | acquiredCandidateDigest evidence == verifiedPassEvidenceDigest verified -> Right ()
            | otherwise -> Left [gateFinding "GATE-PASS-PUBLICATION-DIGEST" "the re-acquired publication no longer binds the verified evidence digest"]

passedRow :: GateRowEvidence -> Bool
passedRow = gateRowEvidencePassed

digestFields :: CandidateCapture -> [(Text, Maybe Text)]
digestFields captured =
    [ ("contractDigest", captureContractDigest captured)
    , ("subjectDigest", captureSubjectDigest captured)
    , ("oracleDigest", captureOracleDigest captured)
    , ("harnessDigest", captureHarnessDigest captured)
    , ("observerDigest", captureObserverDigest captured)
    , ("qualificationDigest", captureQualificationDigest captured)
    , ("projectionDigest", captureProjectionDigest captured)
    , ("projectionPostimageDigest", captureProjectionPostimageDigest captured)
    , ("executableDigest", captureExecutableDigest captured)
    ]

contextFields :: CandidateCapture -> [(Text, Maybe Text)]
contextFields captured =
    [ ("toolchainIdentity", captureToolchainIdentity captured)
    , ("substrate", captureSubstrate captured)
    , ("lane", captureLane captured)
    , ("architecture", captureArchitecture captured)
    , ("runIdentity", captureRunIdentity captured)
    , ("cleanupObservation", captureCleanupObservation captured)
    ]

gateFinding :: Text -> Text -> Finding
gateFinding code = finding code "<acquired-gate-evidence>"

unsafeText :: Text -> Bool
unsafeText value = Text.null (Text.strip value) || Text.any (`elem` ['\t', '\r', '\n', '\0']) value

sha256Text :: Text -> Bool
sha256Text value =
    Text.length value == 64
        && Text.all (\character -> (character >= '0' && character <= '9') || (character >= 'a' && character <= 'f')) value

formatOrdinal :: Int -> Text
formatOrdinal phase
    | phase >= 0 && phase < 10 = "0" <> Text.pack (show phase)
    | otherwise = Text.pack (show phase)
