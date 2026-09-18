{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Vault.Seal
  ( EnvelopeParameters (..)
  , pinnedEnvelopeParameters
  , sealUnlockMaterial
  , openUnlockMaterial
  , sealUnlockMaterialIO
  ) where

import Crypto.Cipher.ChaChaPoly1305 qualified as ChaCha
import Crypto.Error (CryptoFailable (..))
import Crypto.KDF.Argon2 qualified as Argon2
import Crypto.Random (getRandomBytes)
import Data.ByteArray (constEq, convert)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Builder qualified as Builder
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Word (Word32, Word8)

data EnvelopeParameters = EnvelopeParameters
  { envelopeMemoryKiB :: Word32
  , envelopeIterations :: Word32
  , envelopeParallelism :: Word32
  }
  deriving stock (Eq, Show)

pinnedEnvelopeParameters :: EnvelopeParameters
pinnedEnvelopeParameters = EnvelopeParameters 32768 3 1

magic :: ByteString
magic = "AMOEBIUS-VAULT-UNLOCK\0"

sealUnlockMaterialIO :: ByteString -> ByteString -> IO (Either String ByteString)
sealUnlockMaterialIO password plaintext = do
  salt <- getRandomBytes 16
  nonce <- getRandomBytes 12
  pure (sealUnlockMaterial password salt nonce plaintext)

sealUnlockMaterial :: ByteString -> ByteString -> ByteString -> ByteString -> Either String ByteString
sealUnlockMaterial password salt nonceBytes plaintext
  | ByteString.length salt /= 16 = Left "invalid-salt-length"
  | ByteString.length nonceBytes /= 12 = Left "invalid-nonce-length"
  | otherwise = do
      key <- deriveKey pinnedEnvelopeParameters password salt
      nonce <- cryptoEither "invalid-nonce" (ChaCha.nonce12 nonceBytes)
      initial <- cryptoEither "invalid-key" (ChaCha.initialize key nonce)
      let header = encodeHeader pinnedEnvelopeParameters salt nonceBytes
          ready = ChaCha.finalizeAAD (ChaCha.appendAAD header initial)
          (ciphertext, encryptedState) = ChaCha.encrypt plaintext ready
          tag = convert (ChaCha.finalize encryptedState) :: ByteString
      pure (header <> word32be (fromIntegral (ByteString.length ciphertext)) <> ciphertext <> tag)

openUnlockMaterial :: ByteString -> ByteString -> Either String ByteString
openUnlockMaterial password envelope = do
  (parameters, salt, nonceBytes, ciphertext, suppliedTag, header) <- parseEnvelope envelope
  key <- deriveKey parameters password salt
  nonce <- cryptoEither "invalid-nonce" (ChaCha.nonce12 nonceBytes)
  initial <- cryptoEither "invalid-key" (ChaCha.initialize key nonce)
  let ready = ChaCha.finalizeAAD (ChaCha.appendAAD header initial)
      (plaintext, decryptedState) = ChaCha.decrypt ciphertext ready
      expectedTag = convert (ChaCha.finalize decryptedState) :: ByteString
  if expectedTag `constEq` suppliedTag
    then Right plaintext
    else Left "envelope-authentication-failed"

deriveKey :: EnvelopeParameters -> ByteString -> ByteString -> Either String ByteString
deriveKey parameters password salt =
  cryptoEither
    "argon2id-failed"
    ( Argon2.hash
        Argon2.Options
          { Argon2.iterations = envelopeIterations parameters
          , Argon2.memory = envelopeMemoryKiB parameters
          , Argon2.parallelism = envelopeParallelism parameters
          , Argon2.variant = Argon2.Argon2id
          , Argon2.version = Argon2.Version13
          }
        password
        salt
        32
    )

encodeHeader :: EnvelopeParameters -> ByteString -> ByteString -> ByteString
encodeHeader parameters salt nonceBytes =
  LazyByteString.toStrict . Builder.toLazyByteString $
    Builder.byteString magic
      <> Builder.word8 1
      <> Builder.word32BE (envelopeMemoryKiB parameters)
      <> Builder.word32BE (envelopeIterations parameters)
      <> Builder.word32BE (envelopeParallelism parameters)
      <> Builder.byteString salt
      <> Builder.byteString nonceBytes

word32be :: Word32 -> ByteString
word32be = LazyByteString.toStrict . Builder.toLazyByteString . Builder.word32BE

parseEnvelope
  :: ByteString
  -> Either String (EnvelopeParameters, ByteString, ByteString, ByteString, ByteString, ByteString)
parseEnvelope envelope = do
  let magicLength = ByteString.length magic
      fixedLength = magicLength + 1 + 12 + 16 + 12
  if ByteString.take magicLength envelope /= magic
    then Left "invalid-envelope-magic"
    else pure ()
  if ByteString.length envelope < fixedLength + 4 + 16
    then Left "truncated-envelope"
    else pure ()
  let version = ByteString.index envelope magicLength
  if version /= (1 :: Word8)
    then Left "unsupported-envelope-version"
    else pure ()
  memoryCost <- decodeWord32 (ByteString.take 4 (ByteString.drop (magicLength + 1) envelope))
  timeCost <- decodeWord32 (ByteString.take 4 (ByteString.drop (magicLength + 5) envelope))
  lanes <- decodeWord32 (ByteString.take 4 (ByteString.drop (magicLength + 9) envelope))
  let parameters = EnvelopeParameters memoryCost timeCost lanes
  if parameters /= pinnedEnvelopeParameters
    then Left "unpinned-envelope-parameters"
    else pure ()
  let saltOffset = magicLength + 13
      salt = ByteString.take 16 (ByteString.drop saltOffset envelope)
      nonceOffset = saltOffset + 16
      nonceBytes = ByteString.take 12 (ByteString.drop nonceOffset envelope)
      headerLength = nonceOffset + 12
      header = ByteString.take headerLength envelope
  ciphertextLength <- decodeWord32 (ByteString.take 4 (ByteString.drop headerLength envelope))
  let ciphertextOffset = headerLength + 4
      ciphertext = ByteString.take (fromIntegral ciphertextLength) (ByteString.drop ciphertextOffset envelope)
      suppliedTag = ByteString.take 16 (ByteString.drop (ciphertextOffset + fromIntegral ciphertextLength) envelope)
      expectedLength = ciphertextOffset + fromIntegral ciphertextLength + 16
  if ByteString.length envelope /= expectedLength || ByteString.length suppliedTag /= 16
    then Left "invalid-envelope-length"
    else Right (parameters, salt, nonceBytes, ciphertext, suppliedTag, header)

decodeWord32 :: ByteString -> Either String Word32
decodeWord32 bytes
  | ByteString.length bytes /= 4 = Left "truncated-word32"
  | otherwise =
      Right
        ( fromIntegral (ByteString.index bytes 0) * 16777216
            + fromIntegral (ByteString.index bytes 1) * 65536
            + fromIntegral (ByteString.index bytes 2) * 256
            + fromIntegral (ByteString.index bytes 3)
        )

cryptoEither :: String -> CryptoFailable value -> Either String value
cryptoEither message result = case result of
  CryptoPassed value -> Right value
  CryptoFailed _ -> Left message

