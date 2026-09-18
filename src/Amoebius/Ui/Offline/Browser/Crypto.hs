

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
sealRecord (Secret secret) plaintext = Ciphertext (show encoded)
  where
    encoded = zipWith xor (map ord plaintext) (cycle (map ord secret))

openRecord :: Secret -> Ciphertext -> Maybe String
openRecord (Secret secret) (Ciphertext encoded) = do
  (values, rest) <- listToMaybe (reads encoded)
  if null rest
    then Just (zipWith decode values (cycle (map ord secret)))
    else Nothing
  where
    decode value key = chr (value `xor` key)
    listToMaybe [] = Nothing
    listToMaybe (value : _) = Just value

rawCiphertext :: Ciphertext -> String
rawCiphertext (Ciphertext value) = value
