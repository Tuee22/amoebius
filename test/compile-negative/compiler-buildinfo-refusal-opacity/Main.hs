module Main (main) where

import Amoebius.Validation.CompilerBuildInfo
  ( DiagnosticCompilerBuildInfoRefusal )

forbiddenRefusal :: Maybe DiagnosticCompilerBuildInfoRefusal
forbiddenRefusal = Nothing

main :: IO ()
main = forbiddenRefusal `seq` pure ()
