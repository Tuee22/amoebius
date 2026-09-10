{-# LANGUAGE OverloadedStrings #-}

{- | Package-hidden gate authority. Only the protected generation-1 supervisor
can produce this value; public GatePass records and candidate consistency
checks remain diagnostic claims only.
-}
module Amoebius.Validation.GatePass.Internal (
    VerifiedGatePass,
    candidateBindingFindings,
    issueProtectedGatePass,
    verifiedPassEvidenceDigest,
    verifiedPassPhase,
    verifiedPassProjectionDigest,
    verifiedPassProjectionPostimageDigest,
    verifiedPassSourceDigest,
    recheckVerifiedGatePassPublication,
    verifyPublishedGatePass,
) where

import Amoebius.Validation.CertificationReset.Internal (certificationAdmissionRefusal)
import Data.List.NonEmpty qualified as NonEmpty
import Control.Exception (IOException, try)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString qualified as ByteString
import Amoebius.Validation.Evidence.Internal (
    AcquiredCandidateEvidence,
    CandidateCapture,
    GateRowEvidence,
    PublishedCandidateEvidence,
    acquiredCandidateCapture,
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
    , verifiedPublicationValue :: VerifiedPublication
    }
    deriving (Eq, Show)

data VerifiedPublication
    = CandidatePublication PublishedCandidateEvidence
    | ProtectedPublication FilePath Text
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
verifyPublishedGatePass _ = pure (Left (NonEmpty.toList certificationAdmissionRefusal))

-- | Construct the in-process write token only after the UID-zero supervisor
-- has authenticated the protected candidate publication and qualified the
-- current generation/accepted-seed custody boundary.
issueProtectedGatePass
    :: Int -> Text -> Text -> Text -> Text -> FilePath -> Either [Finding] VerifiedGatePass
issueProtectedGatePass phase source evidence projection postimage path
    | Policy.mkPhaseOrdinal phase == Nothing = Left [gateFinding "GATE-PASS-PHASE" "the protected candidate phase is outside the compiled policy domain"]
    | not (all sha256Text [source, evidence, projection, postimage]) = Left [gateFinding "GATE-PASS-IDENTITY" "a protected candidate binding is not a lowercase SHA-256"]
    | not (isAbsolute path) = Left [gateFinding "GATE-PASS-PUBLICATION" "the protected candidate path is not absolute"]
    | otherwise =
        Right
            VerifiedGatePass
                { verifiedPhaseValue = formatOrdinal phase
                , verifiedSourceDigestValue = source
                , verifiedEvidenceDigestValue = evidence
                , verifiedProjectionDigestValue = projection
                , verifiedProjectionPostimageDigestValue = postimage
                , verifiedPublicationValue = ProtectedPublication path evidence
                }

-- | Local consistency diagnostics confer no receipt or status authority.
-- The old success-producing function is absent: only a future protected,
-- qualified issuer can restore production of VerifiedGatePass.
candidateBindingFindings :: AcquiredCandidateEvidence -> [Finding]
candidateBindingFindings evidence = verificationFindings
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
                    "the executable path is not absolute or argv is not the exact phase command"
               | not (isAbsolute (captureExecutablePath captured))
                    || captureArgv captured /= ["validate", "phase", formatOrdinal phase]
                    || any unsafeText (captureArgv captured)
               ]
            <> [ gateFinding "GATE-PASS-EXECUTION-CONTEXT" (label <> " is absent or malformed")
               | (label, value) <- contextFields captured
               , maybe True unsafeText value
               ]

recheckVerifiedGatePassPublication :: VerifiedGatePass -> IO (Either [Finding] ())
recheckVerifiedGatePassPublication verified = case verifiedPublicationValue verified of
    CandidatePublication _ -> pure (Left (NonEmpty.toList certificationAdmissionRefusal))
    ProtectedPublication path expected -> do
        attempted <- try (ByteString.readFile path) :: IO (Either IOException ByteString.ByteString)
        pure $ case attempted of
            Left problem -> Left [gateFinding "GATE-PASS-PUBLICATION" (Text.pack (show problem))]
            Right bytes
                | sha256Bytes bytes == expected -> Right ()
                | otherwise -> Left [gateFinding "GATE-PASS-PUBLICATION-DIGEST" "the protected candidate publication no longer matches its admitted digest"]

sha256Bytes :: ByteString.ByteString -> Text
sha256Bytes = Text.pack . concatMap byteHex . ByteString.unpack . SHA256.hash
 where
    byteHex byte =
        let digits = "0123456789abcdef"
            value = fromIntegral byte
         in [digits !! (value `div` 16), digits !! (value `mod` 16)]

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
