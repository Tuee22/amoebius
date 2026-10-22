{-# LANGUAGE OverloadedStrings #-}
-- | Independent version-admission boundaries, authored without product imports.
module VersionExpectations (versionCases) where
import Data.Text (Text)
versionCases :: [(Text, Text, Text)]
versionCases =
  [ ("ghcup", "0.1.50.1", "ToolVersionMismatch")
  , ("ghcup", "0.1.50.2", "accepted")
  , ("ghcup", "The GHCup Haskell installer, version 0.2.6.2", "accepted")
  , ("ghcup", "0.3.0", "ToolVersionMismatch")
  , ("ghc", "9.12.3", "ToolVersionMismatch")
  , ("ghc", "9.12.4", "accepted")
  , ("ghc", "9.12.5", "ToolVersionMismatch")
  , ("ghc", "9.13.0", "ToolVersionMismatch")
  , ("ghc", "9.12.invalid", "ToolVersionMalformed")
  , ("ghcup", "", "ToolVersionMalformed")
  , ("ghc", "9.12.4 9.10.1", "ToolVersionMalformed")
  , ("ghc", "9.12.4.1", "ToolVersionMismatch")
  , ("ghcup", "0.2", "accepted")
  , ("ghcup", "0.3", "ToolVersionMismatch")
  , ("ghc", "v9.12.4", "accepted")
  , ("ghc", "18446744073709551625.12.4", "ToolVersionMismatch")
  ]
