module Main (main) where

import Amoebius.Validation.SourceDebtBaseline (foldAcquiredSourceDebtState)

main :: IO ()
main = foldAcquiredSourceDebtState `seq` pure ()
