{-# LANGUAGE OverloadedStrings #-}

-- | Canonical authenticated receipt for one protected numbered-phase pass.
-- The issuer is supplied only by the UID-zero certification supervisor.  A
-- verified receipt is still not predecessor authority until its protected
-- store, accepted baseline, candidate bytes, and projected source postimage
-- have been independently reacquired by the accepted verifier.
module Amoebius.Validation.PhasePassReceipt.Internal
  ( VerifiedPhasePassReceipt
  , certificationGenerationDigest
  , foldVerifiedPhasePassReceipt
  , issuePhasePassReceipt
  , verifyPhasePassReceipt
  ) where

import Amoebius.Validation.Types (Finding, finding)
import Control.Monad (unless)
import Crypto.Error (CryptoFailable (..))
import Crypto.Hash.SHA256 qualified as SHA256
import Crypto.PubKey.Ed25519 qualified as Ed25519
import Data.ByteArray (convert)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Text (Text)
import Data.Text.Encoding qualified as TextEncoding

data VerifiedPhasePassReceipt = VerifiedPhasePassReceipt
  { receiptPhase :: Int
  , receiptGeneration :: ByteString
  , receiptAcceptedBaseline :: ByteString
  , receiptSourcePreimage :: ByteString
  , receiptSourcePostimage :: ByteString
  , receiptCandidateEvidence :: ByteString
  , receiptProjection :: ByteString
  , receiptCompatibilityClosure :: ByteString
  , receiptPredecessor :: ByteString
  , receiptSession :: ByteString
  , receiptStdout :: ByteString
  , receiptStderr :: ByteString
  }

foldVerifiedPhasePassReceipt
  :: (Int -> ByteString -> ByteString -> ByteString -> ByteString -> ByteString -> ByteString -> ByteString -> ByteString -> ByteString -> ByteString -> ByteString -> value)
  -> VerifiedPhasePassReceipt
  -> value
foldVerifiedPhasePassReceipt consume receipt =
  consume
    (receiptPhase receipt)
    (receiptGeneration receipt)
    (receiptAcceptedBaseline receipt)
    (receiptSourcePreimage receipt)
    (receiptSourcePostimage receipt)
    (receiptCandidateEvidence receipt)
    (receiptProjection receipt)
    (receiptCompatibilityClosure receipt)
    (receiptPredecessor receipt)
    (receiptSession receipt)
    (receiptStdout receipt)
    (receiptStderr receipt)

certificationGenerationDigest :: ByteString
certificationGenerationDigest = SHA256.hash (TextEncoding.encodeUtf8 "amoebius-certification-generation-1")

issuePhasePassReceipt
  :: ByteString
  -> Int
  -> ByteString
  -> ByteString
  -> ByteString
  -> ByteString
  -> ByteString
  -> ByteString
  -> ByteString
  -> ByteString
  -> ByteString
  -> ByteString
  -> Either Finding ByteString
issuePhasePassReceipt privateSeed phase accepted sourcePreimage sourcePostimage candidate projection compatibility predecessor session stdoutDigest stderrDigest = do
  unless (phase >= 0 && phase <= 95) (Left (receiptFinding "PHASE-RECEIPT-PHASE" "The receipt phase is outside the closed numbered domain."))
  unless (all ((== identifierBytes) . ByteString.length) fields) (Left (receiptFinding "PHASE-RECEIPT-FIELD-WIDTH" "Every receipt identity must contain exactly 32 bytes."))
  secret <- case Ed25519.secretKey privateSeed of
    CryptoFailed _ -> Left (receiptFinding "PHASE-RECEIPT-PRIVATE-KEY" "The protected Ed25519 private seed is invalid.")
    CryptoPassed value -> Right value
  let public = Ed25519.toPublic secret
      payload = ByteString.concat (receiptDomain : ByteString.singleton 0x02 : word16be phase : fields)
  pure (payload <> convert (Ed25519.sign secret public payload))
 where
  fields =
    [ certificationGenerationDigest
    , accepted
    , sourcePreimage
    , sourcePostimage
    , candidate
    , projection
    , compatibility
    , predecessor
    , session
    , stdoutDigest
    , stderrDigest
    ]

verifyPhasePassReceipt :: ByteString -> ByteString -> Either Finding VerifiedPhasePassReceipt
verifyPhasePassReceipt publicBytes encoded = do
  unless (ByteString.length publicBytes == identifierBytes) (Left (receiptFinding "PHASE-RECEIPT-PUBLIC-KEY" "The protected public key is not exactly 32 bytes."))
  public <- case Ed25519.publicKey publicBytes of
    CryptoFailed _ -> Left (receiptFinding "PHASE-RECEIPT-PUBLIC-KEY" "The protected Ed25519 public key is invalid.")
    CryptoPassed value -> Right value
  unless (ByteString.length encoded == receiptBytes && ByteString.take domainBytes encoded == receiptDomain) (Left (receiptFinding "PHASE-RECEIPT-ENCODING" "The phase-pass receipt does not use the exact canonical encoding."))
  unless (ByteString.index encoded domainBytes == 0x02) (Left (receiptFinding "PHASE-RECEIPT-PURPOSE" "The authenticated receipt is not a numbered-phase pass."))
  signature <- case Ed25519.signature (ByteString.drop signedBytes encoded) of
    CryptoFailed _ -> Left (receiptFinding "PHASE-RECEIPT-SIGNATURE" "The phase-pass receipt signature is invalid.")
    CryptoPassed value -> Right value
  unless (Ed25519.verify public (ByteString.take signedBytes encoded) signature) (Left (receiptFinding "PHASE-RECEIPT-SIGNATURE" "The phase-pass receipt signature is invalid."))
  let phase = word16At (domainBytes + 1) encoded
      fields = [identifierAt (fieldsOffset + index * identifierBytes) encoded | index <- [0 .. 10]]
  unless (phase >= 0 && phase <= 95) (Left (receiptFinding "PHASE-RECEIPT-PHASE" "The authenticated receipt phase is outside the closed numbered domain."))
  case fields of
    [generation, accepted, sourcePreimage, sourcePostimage, candidate, projection, compatibility, predecessor, session, stdoutDigest, stderrDigest] ->
      Right
        VerifiedPhasePassReceipt
          { receiptPhase = phase
          , receiptGeneration = generation
          , receiptAcceptedBaseline = accepted
          , receiptSourcePreimage = sourcePreimage
          , receiptSourcePostimage = sourcePostimage
          , receiptCandidateEvidence = candidate
          , receiptProjection = projection
          , receiptCompatibilityClosure = compatibility
          , receiptPredecessor = predecessor
          , receiptSession = session
          , receiptStdout = stdoutDigest
          , receiptStderr = stderrDigest
          }
    _ -> Left (receiptFinding "PHASE-RECEIPT-ENCODING" "The phase-pass receipt field inventory is incomplete.")

receiptFinding :: Text -> Text -> Finding
receiptFinding code = finding code "<phase-pass-receipt>"

receiptDomain :: ByteString
receiptDomain = "amoebius.phase-pass-receipt.v1\0"

identifierBytes, signatureBytes, domainBytes, fieldsOffset, signedBytes, receiptBytes :: Int
identifierBytes = 32
signatureBytes = 64
domainBytes = ByteString.length receiptDomain
fieldsOffset = domainBytes + 3
signedBytes = fieldsOffset + 11 * identifierBytes
receiptBytes = signedBytes + signatureBytes

identifierAt :: Int -> ByteString -> ByteString
identifierAt offset = ByteString.take identifierBytes . ByteString.drop offset

word16be :: Int -> ByteString
word16be value = ByteString.pack [fromIntegral (value `div` 256), fromIntegral value]

word16At :: Int -> ByteString -> Int
word16At offset bytes = fromIntegral (ByteString.index bytes offset) * 256 + fromIntegral (ByteString.index bytes (offset + 1))
