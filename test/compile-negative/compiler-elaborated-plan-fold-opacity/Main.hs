module Main (main) where

-- This client names exactly one forbidden symbol.  A general result-producing
-- fold would let a caller erase permanent refusal findings.
import Amoebius.Validation.CompilerElaboratedPlan
  ( foldDiagnosticCompilerElaboratedPlanRefusal
  )

main :: IO ()
main = foldDiagnosticCompilerElaboratedPlanRefusal `seq` pure ()
