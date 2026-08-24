module Main (main) where

import Amoebius.Validation.CompilerBuildInfo
  ( DiagnosticCompilerBuildInfoExpectedCompiler )

forbiddenExpectedCompiler :: Maybe DiagnosticCompilerBuildInfoExpectedCompiler
forbiddenExpectedCompiler = Nothing

main :: IO ()
main = forbiddenExpectedCompiler `seq` pure ()
