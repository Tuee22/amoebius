module Main (main) where

import Amoebius.Validation.Legacy (acceptedLegacyIdEncodings)

main :: IO ()
main = acceptedLegacyIdEncodings `seq` pure ()
