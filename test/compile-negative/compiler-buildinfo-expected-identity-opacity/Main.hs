module Main (main) where

import Amoebius.Validation.CompilerBuildInfo
  ( DiagnosticCompilerBuildInfoExpectedIdentity )

forbiddenExpectedIdentity :: Maybe DiagnosticCompilerBuildInfoExpectedIdentity
forbiddenExpectedIdentity = Nothing

main :: IO ()
main = forbiddenExpectedIdentity `seq` pure ()
