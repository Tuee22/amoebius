{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.CompilerBuildInfo
  ( compilerBuildInfoDiagnostic
  ) where

-- The package-visible surface is deliberately limited to this refusal-only
-- diagnostic.  Parsing, typed observations, problem constructors, projection,
-- and refusal elimination remain in the package-hidden implementation module.

import Amoebius.Validation.CompilerBuildInfo.Internal qualified as Internal
import Amoebius.Validation.Types (CheckResult)
import Data.ByteString (ByteString)
import Data.Text (Text)

compilerBuildInfoDiagnostic
  :: Text
  -> Text
  -> FilePath
  -> [(Text, Text, Text)]
  -> ByteString
  -> CheckResult
compilerBuildInfoDiagnostic = Internal.compilerBuildInfoDiagnostic
