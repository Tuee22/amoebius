module Main (main) where

-- The implementation module exists for package-internal composition only.  An
-- external client must be rejected before any of its declarations are usable.

import Amoebius.Validation.CompilerBuildInfo.Internal
  ( compilerBuildInfoDiagnostic )

main :: IO ()
main = compilerBuildInfoDiagnostic `seq` pure ()
