{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.CompilerComponentPlan
  ( compilerComponentPlanDiagnostic
  ) where

import Amoebius.Validation.CompilerComponentPlan.Internal
  ( rawCompilerComponentPlanDiagnostic
  )
import Amoebius.Validation.Types (CheckResult)
import Data.ByteString (ByteString)
import Data.Text (Text)

-- | Diagnose raw immutable inventory bytes without exposing a plan, parser,
-- assignment, constructor, projection, detachable observation, or success
-- branch.  The diagnostic always retains source-binding, Cabal-elaboration,
-- compiler-execution, and diagnostic-only residue.
compilerComponentPlanDiagnostic
  :: Text
  -> [(FilePath, Text, Text, ByteString)]
  -> CheckResult
compilerComponentPlanDiagnostic = rawCompilerComponentPlanDiagnostic
