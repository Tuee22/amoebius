module Amoebius.Validation.CompilerElaboratedPlan
  ( checkCompilerElaboratedPlanDiagnostic
  ) where

-- The implementation remains a hidden package module.  This facade is the
-- complete public authority boundary: callers can obtain only an always-
-- refusing CheckResult and cannot import parser state, limits, observations,
-- problems, folds, constructors, or projections.
import Amoebius.Validation.CompilerElaboratedPlan.Internal
  ( checkCompilerElaboratedPlanDiagnostic
  )
