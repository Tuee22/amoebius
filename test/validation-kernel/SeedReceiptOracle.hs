{-# LANGUAGE OverloadedStrings #-}

module SeedReceiptOracle
  ( main
  , runSeedReceiptOracle
  ) where

-- Component cryptographic regression only. These deliberately public test keys
-- are not issuer credentials. A matching signature must still report that key
-- admission and OS custody are unverified; no case supplies phase authority or
-- qualifies the seven-case seed-custody corpus.
--
-- Wire bytes, offsets, contexts, expected results, and signing are independently
-- authored here. No production encoder, signer, generation renderer, or expected
-- result helper is used. The shared cryptographic primitive is checked against
-- the fixed RFC 8032 section 7.1 test vectors before receipt cases execute.

import Amoebius.Validation.SeedReceipt
  ( SeedReceiptExpectation (..)
  , seedReceiptDiagnostic
  )
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding (..)
  , Observation (..)
  )
import Control.Monad (forM_, unless)
import Crypto.Error (CryptoFailable (..))
import Crypto.Hash (Digest, SHA512, hash)
import Crypto.PubKey.Ed25519 qualified as Ed25519
import Data.Bits ((.&.), (.|.), xor)
import Data.ByteArray (convert)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Text (Text)
import Data.Word (Word8)

main :: IO ()
main = runSeedReceiptOracle

runSeedReceiptOracle :: IO ()
runSeedReceiptOracle = do
  checkRfcVector "RFC 8032 test 1" secretOne publicOne "" signatureOne
  checkRfcVector "RFC 8032 test 2" secretTwo publicTwo "\x72" signatureTwo

  expectEqual "independent signed payload length" 187 (ByteString.length canonicalPayload)
  expectEqual "independent complete receipt length" 251 (ByteString.length canonicalReceipt)
  expectAuthentic "clean independent receipt" publicOne canonicalReceipt
  expectResult "matching receipt retains the custody refusal" expectedMatch expectation canonicalReceipt

  forM_ authenticatedContextCases $ \(label, offset, value, code, detail) -> do
    let wire = signPayload secretOne (replaceByte offset value canonicalPayload)
    expectAuthentic label publicOne wire
    expectResult label (expectedRefusal code detail) expectation wire

  -- A validly signed old-generation receipt must fail at generation, rather
  -- than merely reaching a generic invalid-signature branch.
  let oldGenerationPayload = replaceBytes 27 (ByteString.replicate 32 0) canonicalPayload
      oldGenerationReceipt = signPayload secretOne oldGenerationPayload
  expectAuthentic "genuinely signed old generation" publicOne oldGenerationReceipt
  expectResult
    "genuinely signed old generation"
    (expectedRefusal "GENERATION" "The authenticated receipt belongs to a different certification generation.")
    expectation
    oldGenerationReceipt

  -- Unauthenticated context changes must not acquire semantic attribution.
  forM_ [27, 59, 91, 123, 155] $ \offset -> do
    let wire = replaceByte offset 255 canonicalReceipt
        label = "unsigned context alteration at byte " <> show offset
    expectUnauthentic label publicOne wire
    expectResult label signatureRefusal expectation wire

  let wrongKeyReceipt = signPayload secretTwo canonicalPayload
  expectAuthentic "wrong issuer's genuine signature" publicTwo wrongKeyReceipt
  expectUnauthentic "wrong issuer against expected key" publicOne wrongKeyReceipt
  expectResult "receipt signed by another key" signatureRefusal expectation wrongKeyReceipt
  expectResult
    "substituted expected public key"
    signatureRefusal
    (expectation {expectedSeedReceiptPublicKey = publicTwo})
    canonicalReceipt

  forM_ inadmissiblePoints $ \(label, point) -> do
    expectEqual (label <> ": independent point width") 32 (ByteString.length point)
    let altered = expectation {expectedSeedReceiptPublicKey = point}
    expectResult (label <> " public key") keyRefusal altered canonicalReceipt
    expectResult (label <> " public key before wire decoding") keyRefusal altered ByteString.empty
    expectResult
      (label <> " signature point")
      signatureRefusal
      expectation
      (replaceBytes 187 point canonicalReceipt)

  -- With A and R both the identity, S=0 satisfies the native verification
  -- equation for every message without a signing secret. Exact matching copies
  -- do not repair this forgery; the supplied key must be rejected first.
  let identityForgery = canonicalPayload <> identityPoint <> ByteString.replicate 32 0
      identityContext = expectation {expectedSeedReceiptPublicKey = identityPoint}
  expectResult "identity-key forgery" keyRefusal identityContext identityForgery
  expectResult
    "matching copy of identity-key forgery"
    keyRefusal
    identityContext
    (ByteString.copy identityForgery)

  -- The RFC signing equation with a deliberately chosen zero nonce yields an
  -- authentic equation under the ordinary RFC public key, with R=identity.
  -- This isolates the receipt profile's explicit nonidentity-R restriction;
  -- a random damaged R would already fail the native signature equation.
  expectAuthentic "independent identity-R signature equation" publicOne identityRReceipt
  expectResult "identity R is outside the receipt profile" signatureRefusal expectation identityRReceipt

  let originalScalar = littleEndianInteger (ByteString.drop 219 canonicalReceipt)
      malleableReceipt = replaceBytes 219 (littleEndian32 (originalScalar + subgroupOrder)) canonicalReceipt
  expectEqual "independent signer produced S below L" True (originalScalar < subgroupOrder)
  expectEqual
    "S plus L preserves the signed payload and R"
    (ByteString.take 219 canonicalReceipt)
    (ByteString.take 219 malleableReceipt)
  expectEqual
    "S plus L remains below the native top-bit rejection threshold"
    True
    (originalScalar + subgroupOrder < 2 ^ (253 :: Int))
  expectResult "canonical signature scalar plus L" signatureRefusal expectation malleableReceipt
  forM_ [("S equals L", subgroupOrder), ("S equals L plus one", subgroupOrder + 1)] $
    \(label, scalar) ->
      expectResult label signatureRefusal expectation (replaceBytes 219 (littleEndian32 scalar) canonicalReceipt)

  let forgedReceipt = canonicalPayload <> ByteString.replicate 64 0
      matchingCopy = ByteString.copy forgedReceipt
  expectEqual "the forged receipt has an exact matching copy" forgedReceipt matchingCopy
  expectUnauthentic "forged matching-copy receipt" publicOne forgedReceipt
  expectResult "forged receipt" signatureRefusal expectation forgedReceipt
  expectResult "matching copy cannot authenticate the forgery" signatureRefusal expectation matchingCopy

  let changedSignature = flipByte 187 canonicalReceipt
      noncanonicalScalar = replaceByte 250 255 canonicalReceipt
      unsignedOldGeneration = oldGenerationPayload <> ByteString.drop 187 canonicalReceipt
  forM_
    [ ("altered signature bytes", changedSignature)
    , ("noncanonical signature scalar", noncanonicalScalar)
    , ("unauthenticated old generation refuses authentication first", unsignedOldGeneration)
    ] $ \(label, wire) -> do
      expectUnauthentic label publicOne wire
      expectResult label signatureRefusal expectation wire

  -- Expected context is an independent input. Valid signatures do not permit
  -- substitution of the accepted seed, source, session, or transcript.
  forM_ expectedContextCases $ \(label, altered, code, detail) ->
    expectResult label (expectedRefusal code detail) altered canonicalReceipt

  forM_ [0, 1, 250, 252, 502] $ \size -> do
    let wire = ByteString.take size (canonicalReceipt <> canonicalReceipt)
    expectResult ("noncanonical receipt length " <> show size) encodingRefusal expectation wire

  forM_ [("wrong domain", 0, 65), ("domain terminator changed to LF", 24, 10)] $
    \(label, offset, value) -> do
      let wire = signPayload secretOne (replaceByte offset value canonicalPayload)
      expectAuthentic label publicOne wire
      expectResult label encodingRefusal expectation wire

  -- Each field is checked at both neighboring widths and at empty. Empty wire
  -- additionally makes the declared context-before-encoding priority explicit.
  forM_ [0, 31, 33] $ \size ->
    forM_ (invalidExpectedContexts size) $ \(label, altered) -> do
      let caseLabel = label <> " expected width " <> show size
      expectResult caseLabel expectedContextRefusal altered canonicalReceipt
      expectResult (caseLabel <> " before wire decoding") expectedContextRefusal altered ByteString.empty

  -- Complete exact findings and observations are compared in every case, so
  -- missing custody residue, additional findings, or a wrong refusal locus fail.
  expectResult "unchanged control after all negative cases" expectedMatch expectation canonicalReceipt

expectation :: SeedReceiptExpectation
expectation =
  SeedReceiptExpectation
    { expectedSeedReceiptPublicKey = publicOne
    , expectedSeedReceiptGeneration = ByteString.replicate 32 1
    , expectedSeedReceiptAcceptedSeed = ByteString.replicate 32 2
    , expectedSeedReceiptSource = ByteString.replicate 32 3
    , expectedSeedReceiptSession = ByteString.replicate 32 4
    , expectedSeedReceiptTranscriptDigest = ByteString.replicate 32 5
    }

-- Fixed independently encoded message, not a serialization of 'expectation'.
canonicalPayload :: ByteString
canonicalPayload =
  ByteString.concat
    [ "amoebius.seed-receipt.v1\0"
    , ByteString.pack [1, 0]
    , ByteString.replicate 32 1
    , ByteString.replicate 32 2
    , ByteString.replicate 32 3
    , ByteString.replicate 32 4
    , ByteString.replicate 32 5
    ]

canonicalReceipt :: ByteString
canonicalReceipt = signPayload secretOne canonicalPayload

-- Fixed compressed points from the edwards25519 equation. The mixed-order
-- point is B+(0,-1)=(-x_B,-y_B): y_B=4/5, x_B is even, so its encoding is
-- 95 followed by 31 bytes of 99. It has order 2L, not merely small order.
-- The y=2 encoding is off-curve because (y^2-1)/(d*y^2+1) is nonsquare.
inadmissiblePoints :: [(String, ByteString)]
inadmissiblePoints =
  [ ("identity", identityPoint)
  , ("order-two point", decodeHex "ecffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f")
  , ("order-four point with sign zero", ByteString.replicate 32 0)
  , ("order-four point with sign one", decodeHex "0000000000000000000000000000000000000000000000000000000000000080")
  , ("mixed-order point", decodeHex "9599999999999999999999999999999999999999999999999999999999999999")
  , ("off-curve point", decodeHex "0200000000000000000000000000000000000000000000000000000000000000")
  , ("noncanonical y equals p", decodeHex "edffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f")
  , ("noncanonical y equals p plus one", decodeHex "eeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f")
  , ("identity with a negative-zero sign", decodeHex "0100000000000000000000000000000000000000000000000000000000000080")
  , ("order-two point with a negative-zero sign", decodeHex "ecffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")
  ]

identityPoint :: ByteString
identityPoint = decodeHex "0100000000000000000000000000000000000000000000000000000000000000"

-- These mathematical expectations use neither the production point validator
-- nor its scalar representation. RFC 8032 sections 5.1.5 and 5.1.6 supply the
-- clamping and signing equation; the chosen nonce is deliberately zero here.
identityRReceipt :: ByteString
identityRReceipt =
  let expanded = sha512 secretOne
      lowClamped = replaceByte 0 (ByteString.index expanded 0 .&. 248) (ByteString.take 32 expanded)
      clamped = replaceByte 31 ((ByteString.index expanded 31 .&. 63) .|. 64) lowClamped
      secretScalar = littleEndianInteger clamped
      challenge = littleEndianInteger (sha512 (identityPoint <> publicOne <> canonicalPayload)) `mod` subgroupOrder
      signatureScalar = (challenge * secretScalar) `mod` subgroupOrder
   in canonicalPayload <> identityPoint <> littleEndian32 signatureScalar

subgroupOrder :: Integer
subgroupOrder = 2 ^ (252 :: Int) + 27742317777372353535851937790883648493

littleEndianInteger :: ByteString -> Integer
littleEndianInteger = ByteString.foldr (\byte rest -> fromIntegral byte + 256 * rest) 0

littleEndian32 :: Integer -> ByteString
littleEndian32 value
  | value < 0 || value >= 2 ^ (256 :: Int) =
      error "SeedReceiptOracle: independent scalar does not fit 32 bytes"
  | otherwise = ByteString.pack (take 32 (digits value))
  where
    digits remaining = fromIntegral (remaining `mod` 256) : digits (remaining `div` 256)

sha512 :: ByteString -> ByteString
sha512 bytes = convert (hash bytes :: Digest SHA512)

authenticatedContextCases :: [(String, Int, Word8, Text, Text)]
authenticatedContextCases =
  [ ("authenticated wrong purpose", 25, 2, "PURPOSE", "The authenticated receipt is not a seed control acknowledgement.")
  , ("authenticated wrong phase", 26, 1, "PHASE", "The authenticated receipt is not bound to Phase 0.")
  , ("authenticated wrong generation", 27, 9, "GENERATION", "The authenticated receipt belongs to a different certification generation.")
  , ("authenticated wrong accepted seed", 59, 9, "SEED", "The authenticated receipt names a different accepted seed.")
  , ("authenticated wrong source", 91, 9, "SOURCE", "The authenticated receipt names a different source snapshot.")
  , ("authenticated wrong session", 123, 9, "SESSION", "The authenticated receipt names a different session.")
  , ("authenticated wrong custody transcript", 155, 9, "TRANSCRIPT", "The authenticated receipt names a different custody transcript.")
  ]

expectedContextCases :: [(String, SeedReceiptExpectation, Text, Text)]
expectedContextCases =
  [ ("different expected generation", expectation {expectedSeedReceiptGeneration = other}, "GENERATION", "The authenticated receipt belongs to a different certification generation.")
  , ("different expected seed", expectation {expectedSeedReceiptAcceptedSeed = other}, "SEED", "The authenticated receipt names a different accepted seed.")
  , ("different expected source", expectation {expectedSeedReceiptSource = other}, "SOURCE", "The authenticated receipt names a different source snapshot.")
  , ("different expected session", expectation {expectedSeedReceiptSession = other}, "SESSION", "The authenticated receipt names a different session.")
  , ("different expected transcript", expectation {expectedSeedReceiptTranscriptDigest = other}, "TRANSCRIPT", "The authenticated receipt names a different custody transcript.")
  ]
  where
    other = ByteString.replicate 32 9

invalidExpectedContexts :: Int -> [(String, SeedReceiptExpectation)]
invalidExpectedContexts size =
  [ ("public key", expectation {expectedSeedReceiptPublicKey = bytes})
  , ("generation", expectation {expectedSeedReceiptGeneration = bytes})
  , ("accepted seed", expectation {expectedSeedReceiptAcceptedSeed = bytes})
  , ("source", expectation {expectedSeedReceiptSource = bytes})
  , ("session", expectation {expectedSeedReceiptSession = bytes})
  , ("transcript", expectation {expectedSeedReceiptTranscriptDigest = bytes})
  ]
  where
    bytes = ByteString.replicate size 1

expectedMatch :: CheckResult
expectedMatch = expectedResult "matched" []

expectedRefusal :: Text -> Text -> CheckResult
expectedRefusal code detail =
  expectedResult "refused" [Finding ("SEED-RECEIPT-" <> code) "<seed-receipt>" detail]

expectedResult :: Text -> [Finding] -> CheckResult
expectedResult authentication problems =
  CheckResult
    { checkName = "seed-receipt-cryptography"
    , checkObservations =
        [ Observation "seed-receipt.authentication" authentication
        , Observation "seed-receipt.evidence-claim" "seed-control-acknowledgement-cryptography-only"
        ]
    , checkFindings =
        problems
          <> [ Finding
                 "SEED-RECEIPT-CUSTODY-UNVERIFIED"
                 "<seed-receipt>"
                 "The supplied public key and expected context are not acquired authority. Trusted-key admission, protected OS custody, issuer qualification, and phase-pass authority remain unimplemented."
             ]
    }

signatureRefusal, encodingRefusal, expectedContextRefusal, keyRefusal :: CheckResult
signatureRefusal =
  expectedRefusal "SIGNATURE" "The signature does not authenticate this payload under the supplied public key."
encodingRefusal =
  expectedRefusal "ENCODING" "The receipt must use the exact bounded seed-control acknowledgement encoding."
expectedContextRefusal =
  expectedRefusal "EXPECTED-CONTEXT" "Expected public key and context identifiers must each contain exactly 32 bytes."
keyRefusal =
  expectedRefusal "KEY" "The supplied public key is not a canonical nonidentity Ed25519 point of prime order."

expectResult :: String -> CheckResult -> SeedReceiptExpectation -> ByteString -> IO ()
expectResult label expected context wire =
  expectEqual label expected (seedReceiptDiagnostic context wire)

expectEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
expectEqual label expected observed =
  unless (observed == expected) $
    fail
      ( unlines
          [ "SeedReceiptOracle: " <> label
          , "Expected: " <> show expected
          , "Observed: " <> show observed
          ]
      )

signPayload :: ByteString -> ByteString -> ByteString
signPayload seed payload =
  let secret = requireCrypto "independent signing seed" (Ed25519.secretKey seed)
      public = Ed25519.toPublic secret
      signatureBytes = convert (Ed25519.sign secret public payload) :: ByteString
   in payload <> signatureBytes

expectAuthentic :: String -> ByteString -> ByteString -> IO ()
expectAuthentic label public wire =
  expectEqual (label <> ": independent signature control") True (independentAuthenticity public wire)

expectUnauthentic :: String -> ByteString -> ByteString -> IO ()
expectUnauthentic label public wire =
  expectEqual (label <> ": independently invalid signature") False (independentAuthenticity public wire)

independentAuthenticity :: ByteString -> ByteString -> Bool
independentAuthenticity public wire =
  let key = requireCrypto "independent verification key" (Ed25519.publicKey public)
      signature = requireCrypto "independent receipt signature" (Ed25519.signature (ByteString.drop 187 wire))
   in Ed25519.verify key (ByteString.take 187 wire) signature

checkRfcVector :: String -> ByteString -> ByteString -> ByteString -> ByteString -> IO ()
checkRfcVector label seed public message expectedSignature = do
  let key = requireCrypto label (Ed25519.secretKey seed)
      actualPublic = convert (Ed25519.toPublic key) :: ByteString
      actualSignature = convert (Ed25519.sign key (Ed25519.toPublic key) message) :: ByteString
      publicKey = requireCrypto label (Ed25519.publicKey public)
      signature = requireCrypto label (Ed25519.signature expectedSignature)
  expectEqual (label <> ": derived public key") public actualPublic
  expectEqual (label <> ": exact signature") expectedSignature actualSignature
  expectEqual (label <> ": fixed-vector verification") True (Ed25519.verify publicKey message signature)
  expectEqual (label <> ": changed message rejection") False (Ed25519.verify publicKey (message <> "\0") signature)

requireCrypto :: String -> CryptoFailable value -> value
requireCrypto _ (CryptoPassed value) = value
requireCrypto label (CryptoFailed problem) =
  error ("SeedReceiptOracle: invalid independent fixture " <> label <> ": " <> show problem)

replaceByte :: Int -> Word8 -> ByteString -> ByteString
replaceByte offset value = replaceBytes offset (ByteString.singleton value)

replaceBytes :: Int -> ByteString -> ByteString -> ByteString
replaceBytes offset replacement bytes
  | offset < 0 || offset + ByteString.length replacement > ByteString.length bytes =
      error "SeedReceiptOracle: independent mutation offset is outside its fixture"
  | otherwise =
      ByteString.take offset bytes
        <> replacement
        <> ByteString.drop (offset + ByteString.length replacement) bytes

flipByte :: Int -> ByteString -> ByteString
flipByte offset bytes
  | offset < 0 || offset >= ByteString.length bytes =
      error "SeedReceiptOracle: independent signature mutation offset is outside its fixture"
  | otherwise = replaceByte offset (ByteString.index bytes offset `xor` 1) bytes

-- Published, deliberately non-secret RFC 8032 section 7.1 fixtures:
-- https://www.rfc-editor.org/rfc/rfc8032.html#section-7.1
secretOne, publicOne, signatureOne, secretTwo, publicTwo, signatureTwo :: ByteString
secretOne = decodeHex "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60"
publicOne = decodeHex "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
signatureOne =
  decodeHex
    "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b"
secretTwo = decodeHex "4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb"
publicTwo = decodeHex "3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c"
signatureTwo =
  decodeHex
    "92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00"

decodeHex :: String -> ByteString
decodeHex = ByteString.pack . pairs
  where
    pairs [] = []
    pairs (high : low : rest) = (nibble high * 16 + nibble low) : pairs rest
    pairs [_] = error "SeedReceiptOracle: odd-length independent hexadecimal fixture"
    nibble digit
      | digit >= '0' && digit <= '9' = fromIntegral (fromEnum digit - fromEnum '0')
      | digit >= 'a' && digit <= 'f' = fromIntegral (fromEnum digit - fromEnum 'a' + 10)
      | otherwise = error "SeedReceiptOracle: malformed independent hexadecimal fixture"
