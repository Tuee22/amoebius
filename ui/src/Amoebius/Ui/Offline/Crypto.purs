module Amoebius.Ui.Offline.Crypto where

newtype Ciphertext = Ciphertext String

data UnlockState
  = Locked
  | Unlocked Ciphertext

-- Implemented by the trusted WebCrypto interpreter; authored programs never receive this constructor.
foreign import encryptRecord :: String -> String -> Ciphertext
foreign import decryptRecord :: String -> Ciphertext -> String
