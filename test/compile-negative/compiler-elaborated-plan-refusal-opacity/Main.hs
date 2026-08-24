module Main (main) where

-- This client names exactly one forbidden symbol.  The diagnostic refusal
-- carrier must remain private so observations cannot be detached from its
-- mandatory residue.
import Amoebius.Validation.CompilerElaboratedPlan
  ( DiagnosticCompilerElaboratedPlanRefusal
  )

forbidden :: Maybe DiagnosticCompilerElaboratedPlanRefusal
forbidden = Nothing

main :: IO ()
main = forbidden `seq` pure ()
