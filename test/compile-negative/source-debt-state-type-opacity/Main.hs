module Main (main) where

import Amoebius.Validation.SourceDebtBaseline (SourceDebtState)

forbiddenState :: Maybe SourceDebtState
forbiddenState = Nothing

main :: IO ()
main = forbiddenState `seq` pure ()
