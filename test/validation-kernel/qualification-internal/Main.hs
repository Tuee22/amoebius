module Main (main) where

import Control.Monad (unless)
import QualificationInternalOracle (qualificationInternalOracleProblems)

main :: IO ()
main =
    unless
        (null qualificationInternalOracleProblems)
        (fail (unlines ("QualificationInternalOracle failures:" : map ("  " <>) qualificationInternalOracleProblems)))
