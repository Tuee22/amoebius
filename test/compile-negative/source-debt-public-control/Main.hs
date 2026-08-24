module Main (main) where

import Amoebius.Validation.SourceDebtBaseline (sourceDebtBaselineCheck)

main :: IO ()
main = sourceDebtBaselineCheck [] `seq` pure ()
