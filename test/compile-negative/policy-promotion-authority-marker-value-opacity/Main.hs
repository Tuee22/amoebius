module Main (main) where

import Amoebius.Validation.PolicyContract (promotionAuthorityMarker)

main :: IO ()
main = promotionAuthorityMarker `seq` pure ()
