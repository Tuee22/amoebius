module Main (main) where

-- Paired positive control: the one public refusal-only front door must compile
-- and remain callable from the same library boundary.
import Amoebius.Validation.CompilerElaboratedPlan
  ( checkCompilerElaboratedPlanDiagnostic
  )

main :: IO ()
main = checkCompilerElaboratedPlanDiagnostic mempty `seq` pure ()
