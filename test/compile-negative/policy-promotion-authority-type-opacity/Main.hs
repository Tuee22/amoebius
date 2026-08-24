module Main (main) where

import Amoebius.Validation.PolicyContract (PromotionAuthority)

privateSymbol :: Maybe PromotionAuthority
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
