{-# LANGUAGE OverloadedStrings #-}

-- | Bounded Ed25519 verification of a seed control acknowledgement.
--
-- This is a cryptographic component, not an accepted verifier or receipt
-- issuer. Supplied expectations have no acquired trust. Trusted-key
-- admission, protected OS custody, issuer qualification, freshness of the
-- session, and correspondence with an actually observed custody transcript
-- remain unimplemented. A signature cannot establish those facts by itself.
-- No constructor or result from this module carries gate or issuer authority.
--
-- The single canonical wire format contains exactly 251 bytes:
--
-- * bytes 0..24: ASCII @amoebius.seed-receipt.v1@ followed by NUL;
-- * byte 25: purpose 0x01, a seed control acknowledgement;
-- * byte 26: phase 0x00;
-- * bytes 27..58: certification-generation identifier;
-- * bytes 59..90: accepted-seed identifier;
-- * bytes 91..122: source-snapshot identifier;
-- * bytes 123..154: session identifier;
-- * bytes 155..186: custody-transcript digest;
-- * bytes 187..250: Ed25519 signature over the preceding 187 bytes.
--
-- The identifiers are raw 32-byte values, not hexadecimal text. This fixed
-- framing admits no alternate field order, extra fields, trailing bytes, or
-- alternate text encoding. The purpose distinguishes a control acknowledgement
-- from a phase-pass receipt. Verification authenticates the payload before
-- interpreting its purpose, phase, generation, or other contextual claims.
-- Public keys and signature R points must decode and re-encode canonically,
-- be nonidentity, and belong to the prime-order subgroup. Signature scalars
-- must be canonical values strictly below the subgroup order. This closed
-- acknowledgement protocol rejects identity R, including the rare case in
-- which a general Ed25519 signer could legitimately produce that point.
--
-- No signing, key generation, input acquisition, filesystem access, environment
-- selection, serialization, or certification-reset override is provided here.
-- Matching copies of a forged receipt cannot supply a valid signature under
-- the independently supplied expected key. A matching signature still leaves
-- the public diagnostic refused because key custody has not been acquired.
module Amoebius.Validation.SeedReceipt.Internal
  ( SeedReceiptExpectation (..)
  , seedReceiptDiagnostic
  , verifySeedReceiptCryptography
  ) where

import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding
  , finding
  , observation
  )
import Crypto.Error (CryptoFailable (..))
import Crypto.ECC.Edwards25519 qualified as Edwards25519
import Crypto.PubKey.Ed25519 qualified as Ed25519
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Text (Text)

-- | Caller-authored comparison inputs only. Each field must have exactly
-- 32 bytes. The generation identifier must eventually be bound to the closed
-- certification generation by accepted-seed admission; supplying bytes here
-- neither performs that admission nor changes the current reset refusal.
data SeedReceiptExpectation = SeedReceiptExpectation
  { expectedSeedReceiptPublicKey :: ByteString
  , expectedSeedReceiptGeneration :: ByteString
  , expectedSeedReceiptAcceptedSeed :: ByteString
  , expectedSeedReceiptSource :: ByteString
  , expectedSeedReceiptSession :: ByteString
  , expectedSeedReceiptTranscriptDigest :: ByteString
  }
  deriving (Eq, Show)

-- | Always retains 'custodyUnverified'. The matched/refused observation refers
-- only to signature verification and equality with caller-supplied context.
-- It is not an execution-derived seed-custody receipt or a validation pass.
seedReceiptDiagnostic :: SeedReceiptExpectation -> ByteString -> CheckResult
seedReceiptDiagnostic expected encoded =
  let result = checkReceiptCryptography expected encoded
   in CheckResult
        { checkName = "seed-receipt-cryptography"
        , checkObservations =
            [ observation
                "seed-receipt.authentication"
                (case result of Left _ -> "refused"; Right () -> "matched")
            , observation
                "seed-receipt.evidence-claim"
                "seed-control-acknowledgement-cryptography-only"
            ]
        , checkFindings =
            (case result of Left problem -> [problem]; Right () -> [])
              <> [custodyUnverified]
        }

-- The unit result is private local arithmetic/cryptographic agreement, not
-- an authority token. Exactly one first failure is retained, followed by the
-- unavoidable custody limitation in the public diagnostic.
checkReceiptCryptography :: SeedReceiptExpectation -> ByteString -> Either Finding ()
checkReceiptCryptography expected encoded = do
  require
    (all ((== identifierBytes) . ByteString.length) (expectationFields expected))
    "SEED-RECEIPT-EXPECTED-CONTEXT"
    "Expected public key and context identifiers must each contain exactly 32 bytes."
  let encodedPublicKey = expectedSeedReceiptPublicKey expected
  publicKey <-
    case (canonicalPrimeOrderPoint encodedPublicKey, Ed25519.publicKey encodedPublicKey) of
      (True, CryptoPassed key) -> Right key
      _ -> Left keyFinding
  require
    ( ByteString.length encoded == receiptBytes
        && ByteString.take domainBytes encoded == receiptDomain
    )
    "SEED-RECEIPT-ENCODING"
    "The receipt must use the exact bounded seed-control acknowledgement encoding."
  let encodedSignature = ByteString.drop signedPayloadBytes encoded
  require
    ( canonicalPrimeOrderPoint (ByteString.take identifierBytes encodedSignature)
        && canonicalScalar (ByteString.drop identifierBytes encodedSignature)
    )
    "SEED-RECEIPT-SIGNATURE"
    "The signature does not authenticate this payload under the supplied public key."
  signature <-
    case Ed25519.signature encodedSignature of
      CryptoPassed value -> Right value
      CryptoFailed _ -> Left signatureFinding
  require
    (Ed25519.verify publicKey (ByteString.take signedPayloadBytes encoded) signature)
    "SEED-RECEIPT-SIGNATURE"
    "The signature does not authenticate this payload under the supplied public key."
  require
    (ByteString.index encoded purposeOffset == 0x01)
    "SEED-RECEIPT-PURPOSE"
    "The authenticated receipt is not a seed control acknowledgement."
  require
    (ByteString.index encoded phaseOffset == 0x00)
    "SEED-RECEIPT-PHASE"
    "The authenticated receipt is not bound to Phase 0."
  require
    (identifierAt generationOffset encoded == expectedSeedReceiptGeneration expected)
    "SEED-RECEIPT-GENERATION"
    "The authenticated receipt belongs to a different certification generation."
  require
    (identifierAt acceptedSeedOffset encoded == expectedSeedReceiptAcceptedSeed expected)
    "SEED-RECEIPT-SEED"
    "The authenticated receipt names a different accepted seed."
  require
    (identifierAt sourceOffset encoded == expectedSeedReceiptSource expected)
    "SEED-RECEIPT-SOURCE"
    "The authenticated receipt names a different source snapshot."
  require
    (identifierAt sessionOffset encoded == expectedSeedReceiptSession expected)
    "SEED-RECEIPT-SESSION"
    "The authenticated receipt names a different session."
  require
    (identifierAt transcriptOffset encoded == expectedSeedReceiptTranscriptDigest expected)
    "SEED-RECEIPT-TRANSCRIPT"
    "The authenticated receipt names a different custody transcript."

-- | Package-hidden cryptographic predicate for the OS-qualified supervisor.
-- Caller-supplied expectations remain non-authoritative unless the caller has
-- separately acquired the protected accepted seed and custody boundary.
verifySeedReceiptCryptography :: SeedReceiptExpectation -> ByteString -> Either Finding ()
verifySeedReceiptCryptography = checkReceiptCryptography

-- crypton 1.0.6's Ed25519 publicKey constructor checks only byte length.
-- Its Edwards25519 decoder supplies curve validation; the canonical encoder
-- catches alternate compressed encodings. pointHasPrimeOrder also accepts
-- the identity, so that point must be excluded explicitly. The subgroup
-- check, rather than a blacklist of selected weak encodings, rejects all
-- remaining points outside the prime-order subgroup.
canonicalPrimeOrderPoint :: ByteString -> Bool
canonicalPrimeOrderPoint encoded
  | ByteString.length encoded /= identifierBytes = False
  | otherwise =
      case Edwards25519.pointDecode encoded of
        CryptoFailed _ -> False
        CryptoPassed point ->
          (Edwards25519.pointEncode point :: ByteString) == encoded
            && encoded /= identityPointEncoding
            && Edwards25519.pointHasPrimeOrder point

identityPointEncoding :: ByteString
identityPointEncoding = ByteString.cons 1 (ByteString.replicate 31 0)

-- scalarDecodeLong reduces modulo the subgroup order, and scalarEncode
-- returns its canonical 32-byte representative. Requiring the exact
-- roundtrip therefore admits precisely 0 <= S < L, rather than the wider
-- values accepted by the pinned Ed25519 verification primitive.
canonicalScalar :: ByteString -> Bool
canonicalScalar encoded
  | ByteString.length encoded /= identifierBytes = False
  | otherwise =
      case Edwards25519.scalarDecodeLong encoded of
        CryptoFailed _ -> False
        CryptoPassed scalar ->
          (Edwards25519.scalarEncode scalar :: ByteString) == encoded

expectationFields :: SeedReceiptExpectation -> [ByteString]
expectationFields expected =
  [ expectedSeedReceiptPublicKey expected
  , expectedSeedReceiptGeneration expected
  , expectedSeedReceiptAcceptedSeed expected
  , expectedSeedReceiptSource expected
  , expectedSeedReceiptSession expected
  , expectedSeedReceiptTranscriptDigest expected
  ]

require :: Bool -> Text -> Text -> Either Finding ()
require True _ _ = Right ()
require False code detail = Left (receiptFinding code detail)

receiptFinding :: Text -> Text -> Finding
receiptFinding code = finding code "<seed-receipt>"

keyFinding :: Finding
keyFinding =
  receiptFinding
    "SEED-RECEIPT-KEY"
    "The supplied public key is not a canonical nonidentity Ed25519 point of prime order."

signatureFinding :: Finding
signatureFinding =
  receiptFinding
    "SEED-RECEIPT-SIGNATURE"
    "The signature does not authenticate this payload under the supplied public key."

custodyUnverified :: Finding
custodyUnverified =
  receiptFinding
    "SEED-RECEIPT-CUSTODY-UNVERIFIED"
    "The supplied public key and expected context are not acquired authority. Trusted-key admission, protected OS custody, issuer qualification, and phase-pass authority remain unimplemented."

receiptDomain :: ByteString
receiptDomain = "amoebius.seed-receipt.v1\0"

identifierBytes, signatureBytes, domainBytes :: Int
identifierBytes = 32
signatureBytes = 64
domainBytes = ByteString.length receiptDomain

purposeOffset, phaseOffset, generationOffset, acceptedSeedOffset :: Int
purposeOffset = domainBytes
phaseOffset = purposeOffset + 1
generationOffset = phaseOffset + 1
acceptedSeedOffset = generationOffset + identifierBytes

sourceOffset, sessionOffset, transcriptOffset :: Int
sourceOffset = acceptedSeedOffset + identifierBytes
sessionOffset = sourceOffset + identifierBytes
transcriptOffset = sessionOffset + identifierBytes

signedPayloadBytes, receiptBytes :: Int
signedPayloadBytes = transcriptOffset + identifierBytes
receiptBytes = signedPayloadBytes + signatureBytes

identifierAt :: Int -> ByteString -> ByteString
identifierAt offset = ByteString.take identifierBytes . ByteString.drop offset
