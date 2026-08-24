module Main (main) where

-- This external client must not compile.  The elaborated-plan module exposes
-- only an always-refusing CheckResult checker; its raw parser and refusal value
-- must remain private so they cannot become a detachable semantic input.

import Amoebius.Validation.CompilerElaboratedPlan
  ( parseCompilerElaboratedPlanDiagnostic
  )

main :: IO ()
main = parseCompilerElaboratedPlanDiagnostic mempty `seq` pure ()
