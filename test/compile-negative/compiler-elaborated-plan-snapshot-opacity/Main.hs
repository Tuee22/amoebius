module Main (main) where

-- This client names exactly one forbidden symbol.  A decoded plan snapshot is
-- diagnostic state, never a public semantic input.
import Amoebius.Validation.CompilerElaboratedPlan
  ( DiagnosticCompilerElaboratedPlanSnapshot
  )

forbidden :: Maybe DiagnosticCompilerElaboratedPlanSnapshot
forbidden = Nothing

main :: IO ()
main = forbidden `seq` pure ()
