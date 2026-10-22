{-# LANGUAGE OverloadedStrings #-}
-- Independent native admission expectations, including both versioned tools.
module Admission (admissionChecks) where

import Control.Exception (IOException, try)
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO

admissionChecks :: FilePath -> IO [(Text, Bool, Text)]
admissionChecks directory = do
  observed <- try (TextIO.readFile (directory <> "/admission.tsv")) :: IO (Either IOException Text)
  let rows = either (const []) (map (Text.splitOn "\t") . Text.lines) observed
      cases = [("missing-tool", "ToolMissing"), ("failed-command", "ToolCommandFailed")
              ,("malformed-version", "ToolVersionMalformed"), ("unsupported-version", "ToolVersionMismatch")]
      expectedKeys = [(name, tool, control) | (name, _) <- cases, tool <- ["ghcup", "ghc"], control <- ["positive", "negative"]]
        <> [("control", "cleanup", "observed")]
      actualKeys = [(name, tool, control) | [name, tool, control, _] <- rows]
      values name control = sort [(tool, value) | [key, tool, role, value] <- rows, key == name, role == control]
      cleanup = [value | ["control", "cleanup", "observed", value] <- rows]
  pure (("admission.discovery", all ((== 4) . length) rows && sort actualKeys == sort expectedKeys, Text.pack (show actualKeys))
    : [("admission." <> name <> "." <> control,
        values name control == sort [("ghcup", expected), ("ghc", expected)], Text.pack (show (values name control)))
      | (name, refused) <- cases, (control, expected) <- [("positive", "accepted"), ("negative", refused)]]
    <> [("admission.control.cleanup", cleanup == ["True"], Text.pack (show cleanup))])
