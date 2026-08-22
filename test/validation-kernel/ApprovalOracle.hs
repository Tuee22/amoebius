{-# LANGUAGE OverloadedStrings #-}

module ApprovalOracle
  ( runApprovalOracle
  ) where

-- Component diagnostic only. This module is not independent human review,
-- harness qualification, phase validation, or promotion evidence.

import Amoebius.Validation.Approval
import Control.Monad (unless)
import Crypto.Error (CryptoFailable (CryptoFailed, CryptoPassed))
import Crypto.PubKey.Ed25519 qualified as Ed25519
import Data.ByteArray qualified as ByteArray
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Set qualified as Set
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding

runApprovalOracle :: IO ()
runApprovalOracle = do
  signingKey <- secretKeyFromSeed "primary synthetic signing key" (ByteString.pack [0 .. 31])
  otherKey <- secretKeyFromSeed "alternate synthetic signing key" (ByteString.pack [32 .. 63])
  let publicKey = Ed25519.toPublic signingKey
      otherPublicKey = Ed25519.toPublic otherKey
      priorSource = digestText '0'
      candidate =
        CandidateBinding
          { candidatePhase = "00"
          , candidateSourceDigest = digestText '1'
          , candidateContractDigest = digestText '2'
          , candidateHarnessDigest = digestText '3'
          , candidateEvidenceDigest = digestText '4'
          , candidatePredecessorDigest = "genesis"
          , candidateApprovalNonce = "challenge-00-0001"
          , candidatePriorSourceDigests = Set.fromList [priorSource, digestText '5']
          }
      trustRoot =
        TrustRoot
          { trustRootId = "synthetic-human-root"
          , trustRootPublicKey = publicKeyBytes publicKey
          , trustRootEstablishedBefore = priorSource
          }
      unsignedApproval =
        Approval
          { approvalAuthority = "human"
          , approvalTrustRootId = trustRootId trustRoot
          , approvalPhase = candidatePhase candidate
          , approvalSourceDigest = candidateSourceDigest candidate
          , approvalContractDigest = candidateContractDigest candidate
          , approvalHarnessDigest = candidateHarnessDigest candidate
          , approvalEvidenceDigest = candidateEvidenceDigest candidate
          , approvalPredecessorDigest = candidatePredecessorDigest candidate
          , approvalNonce = candidateApprovalNonce candidate
          , approvalIssuedAt = "2026-08-22T12:00:00Z"
          , approvalSignature = ByteString.empty
          }
      approval = signExpectedPayload signingKey publicKey unsignedApproval
      check label expected actual = expectEqual label expected actual
      verify = verifyApproval trustRoot candidate Set.empty
      problems =
        concat
          [ check "independently stated approval payload" (expectedPayload approval) (approvalPayload approval)
          , check
              "a valid self-generated signature is not externally anchored human approval"
              (Left ApprovalExternalAnchorUnavailable)
              (verify approval)
          , check
              "automation is not human authority"
              (Left ApprovalAuthorityNotHuman)
              (verify (approval {approvalAuthority = "automation"}))
          , check
              "wrong trust-root identity"
              (Left ApprovalTrustRootMismatch)
              (verify (approval {approvalTrustRootId = "other-root"}))
          , check
              "wrong valid Ed25519 public key"
              (Left ApprovalSignatureInvalid)
              ( verifyApproval
                  (trustRoot {trustRootPublicKey = publicKeyBytes otherPublicKey})
                  candidate
                  Set.empty
                  approval
              )
          , check
              "malformed Ed25519 public key"
              (Left ApprovalPublicKeyInvalid)
              ( verifyApproval
                  (trustRoot {trustRootPublicKey = ByteString.singleton 0})
                  candidate
                  Set.empty
                  approval
              )
          , check
              "phase binding"
              (Left ApprovalPhaseMismatch)
              (verifyApproval trustRoot (candidate {candidatePhase = "01"}) Set.empty approval)
          , check
              "source binding"
              (Left ApprovalSourceMismatch)
              (verifyApproval trustRoot (candidate {candidateSourceDigest = digestText '6'}) Set.empty approval)
          , check
              "contract binding"
              (Left ApprovalContractMismatch)
              (verifyApproval trustRoot (candidate {candidateContractDigest = digestText '7'}) Set.empty approval)
          , check
              "harness binding"
              (Left ApprovalHarnessMismatch)
              (verifyApproval trustRoot (candidate {candidateHarnessDigest = digestText '8'}) Set.empty approval)
          , check
              "evidence binding"
              (Left ApprovalEvidenceMismatch)
              (verifyApproval trustRoot (candidate {candidateEvidenceDigest = digestText '9'}) Set.empty approval)
          , check
              "predecessor binding"
              (Left ApprovalPredecessorMismatch)
              (verifyApproval trustRoot (candidate {candidatePredecessorDigest = digestText 'a'}) Set.empty approval)
          , check
              "missing nonce"
              (Left ApprovalNonceMissing)
              (verify (approval {approvalNonce = ""}))
          , check
              "wrong live nonce"
              (Left ApprovalNonceMismatch)
              (verify (approval {approvalNonce = "challenge-00-other"}))
          , check
              "replayed nonce"
              (Left ApprovalReplay)
              (verifyApproval trustRoot candidate (Set.singleton (approvalNonce approval)) approval)
          , check
              "missing issue time"
              (Left ApprovalIssuedAtMissing)
              (verify (approval {approvalIssuedAt = ""}))
          , check
              "missing prior-source provenance"
              (Left ApprovalTrustRootNotPrior)
              (verifyApproval trustRoot (candidate {candidatePriorSourceDigests = Set.empty}) Set.empty approval)
          , check
              "unknown prior-source provenance"
              (Left ApprovalTrustRootNotPrior)
              ( verifyApproval
                  (trustRoot {trustRootEstablishedBefore = digestText 'b'})
                  candidate
                  Set.empty
                  approval
              )
          , check
              "empty trust-root provenance"
              (Left ApprovalBindingMalformed)
              (verifyApproval (trustRoot {trustRootEstablishedBefore = ""}) candidate Set.empty approval)
          , check
              "trust root established by candidate source"
              (Left ApprovalTrustRootNotPrior)
              ( verifyApproval
                  (trustRoot {trustRootEstablishedBefore = candidateSourceDigest candidate})
                  (candidate {candidatePriorSourceDigests = Set.insert (candidateSourceDigest candidate) (candidatePriorSourceDigests candidate)})
                  Set.empty
                  approval
              )
          , check
              "malformed signature"
              (Left ApprovalSignatureInvalid)
              (verify (approval {approvalSignature = ByteString.singleton 0}))
          , check
              "one-digit phase is not a canonical signed binding"
              (Left ApprovalBindingMalformed)
              (verifyApproval trustRoot (candidate {candidatePhase = "0"}) Set.empty approval)
          , check
              "out-of-domain phase is not a canonical signed binding"
              (Left ApprovalBindingMalformed)
              (verifyApproval trustRoot (candidate {candidatePhase = "96"}) Set.empty approval)
          , check
              "uppercase source digest is not canonical"
              (Left ApprovalBindingMalformed)
              (verifyApproval trustRoot (candidate {candidateSourceDigest = Text.replicate 64 "A"}) Set.empty approval)
          , check
              "short contract digest is not canonical"
              (Left ApprovalBindingMalformed)
              (verifyApproval trustRoot (candidate {candidateContractDigest = "abc"}) Set.empty approval)
          , check
              "non-digest predecessor is not canonical"
              (Left ApprovalBindingMalformed)
              (verifyApproval trustRoot (candidate {candidatePredecessorDigest = "phase-previous"}) Set.empty approval)
          , check
              "empty candidate nonce is not canonical"
              (Left ApprovalBindingMalformed)
              (verifyApproval trustRoot (candidate {candidateApprovalNonce = ""}) Set.empty approval)
          , check
              "malformed prior-source provenance is not canonical"
              (Left ApprovalBindingMalformed)
              ( verifyApproval
                  trustRoot
                  (candidate {candidatePriorSourceDigests = Set.insert "not-a-digest" (candidatePriorSourceDigests candidate)})
                  Set.empty
                  approval
              )
          , check
              "newline injection is not a canonical signed binding"
              (Left ApprovalBindingMalformed)
              (verify (approval {approvalAuthority = "human\nphase=99"}))
          , check
              "NUL injection is not a canonical signed binding"
              (Left ApprovalBindingMalformed)
              (verify (approval {approvalIssuedAt = "2026-08-22\0ignored"}))
          ]
  finishDiagnostics "ApprovalOracle" problems

expectedPayload :: Approval -> ByteString
expectedPayload approval =
  TextEncoding.encodeUtf8
    ( "amoebius-human-approval-v1\n"
        <> "authority=" <> approvalAuthority approval <> "\n"
        <> "trust-root=" <> approvalTrustRootId approval <> "\n"
        <> "phase=" <> approvalPhase approval <> "\n"
        <> "source=" <> approvalSourceDigest approval <> "\n"
        <> "contract=" <> approvalContractDigest approval <> "\n"
        <> "harness=" <> approvalHarnessDigest approval <> "\n"
        <> "evidence=" <> approvalEvidenceDigest approval <> "\n"
        <> "predecessor=" <> approvalPredecessorDigest approval <> "\n"
        <> "nonce=" <> approvalNonce approval <> "\n"
        <> "issued-at=" <> approvalIssuedAt approval <> "\n"
    )

signExpectedPayload :: Ed25519.SecretKey -> Ed25519.PublicKey -> Approval -> Approval
signExpectedPayload secretKey publicKey approval =
  approval
    { approvalSignature = signatureBytes (Ed25519.sign secretKey publicKey (expectedPayload approval))
    }

secretKeyFromSeed :: String -> ByteString -> IO Ed25519.SecretKey
secretKeyFromSeed label seed =
  case Ed25519.secretKey seed of
    CryptoPassed key -> pure key
    CryptoFailed problem -> fail (label <> " could not be constructed: " <> show problem)

publicKeyBytes :: Ed25519.PublicKey -> ByteString
publicKeyBytes = ByteArray.convert

signatureBytes :: Ed25519.Signature -> ByteString
signatureBytes = ByteArray.convert

digestText :: Char -> Text.Text
digestText character = Text.replicate 64 (Text.singleton character)

expectEqual :: (Eq value, Show value) => String -> value -> value -> [String]
expectEqual label expected actual
  | actual == expected = []
  | otherwise = [label <> ": expected " <> show expected <> ", observed " <> show actual]

finishDiagnostics :: String -> [String] -> IO ()
finishDiagnostics name problems =
  unless (null problems) (fail (name <> " component diagnostic failures:\n  " <> Text.unpack (Text.intercalate "\n  " (fmap Text.pack problems))))
