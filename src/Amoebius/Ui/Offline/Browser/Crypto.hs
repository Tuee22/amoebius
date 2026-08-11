{-# LANGUAGE CPP #-}

module Amoebius.Ui.Offline.Browser.Crypto
  ( Ciphertext
  , Secret (..)
  , openRecord
  , rawCiphertext
  , sealRecord
  ) where

import Data.Bits (xor)
import Data.Char (chr, ord)

newtype Secret = Secret String
  deriving stock (Eq, Show)

newtype Ciphertext = Ciphertext String
  deriving stock (Eq, Show)

sealRecord :: Secret -> String -> Ciphertext
#if defined(PHASE60_STORE_PLAINTEXT_MUTANT) || defined(PHASE62_STORE_PLAINTEXT_MUTANT)
sealRecord _ plaintext = Ciphertext plaintext
#else
sealRecord (Secret secret) plaintext = Ciphertext (show encoded)
  where
    encoded = zipWith xor (map ord plaintext) (cycle (map ord secret))
#endif

openRecord :: Secret -> Ciphertext -> Maybe String
#if defined(PHASE60_STORE_PLAINTEXT_MUTANT) || defined(PHASE62_STORE_PLAINTEXT_MUTANT)
openRecord _ (Ciphertext plaintext) = Just plaintext
#else
openRecord (Secret secret) (Ciphertext encoded) = do
  (values, rest) <- listToMaybe (reads encoded)
  if null rest
    then Just (zipWith decode values (cycle (map ord secret)))
    else Nothing
  where
    decode value key = chr (value `xor` key)
    listToMaybe [] = Nothing
    listToMaybe (value : _) = Just value
#endif

rawCiphertext :: Ciphertext -> String
rawCiphertext (Ciphertext value) = value
