module Amoebius.Ui.Offline.Crypto where

newtype Ciphertext = Ciphertext String

data UnlockState
  = Locked
  | Unlocked Ciphertext
