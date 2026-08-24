module Main (main) where

import Amoebius.Validation.CompilerBuildInfo
  ( DiagnosticCompilerBuildInfoComponentIdentity )

forbiddenComponentIdentity :: Maybe DiagnosticCompilerBuildInfoComponentIdentity
forbiddenComponentIdentity = Nothing

main :: IO ()
main = forbiddenComponentIdentity `seq` pure ()
