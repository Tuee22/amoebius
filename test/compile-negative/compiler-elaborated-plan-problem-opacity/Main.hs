module Main (main) where

-- This client names exactly one forbidden symbol.  Private problem values may
-- be observed only through the always-refusing public CheckResult wire.
import Amoebius.Validation.CompilerElaboratedPlan
  ( CompilerElaboratedPlanProblem
  )

forbidden :: Maybe CompilerElaboratedPlanProblem
forbidden = Nothing

main :: IO ()
main = forbidden `seq` pure ()
