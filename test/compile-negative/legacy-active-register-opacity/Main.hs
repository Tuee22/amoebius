module Main (main) where

import Amoebius.Validation.Legacy (ActiveRegister)

privateSymbol :: Maybe ActiveRegister
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
