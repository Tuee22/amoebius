module Main (main) where

import Amoebius.Validation.PolicyContract (PromotionContract)

privateSymbol :: Maybe PromotionContract
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
