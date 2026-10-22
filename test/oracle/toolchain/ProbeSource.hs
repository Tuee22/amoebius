{-# LANGUAGE OverloadedStrings #-}
-- Independent probe-source inventory, generated-byte and observation expectations.
module ProbeSource (probeSourceChecks) where

import Control.Exception (IOException, try)
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (doesPathExist)
import System.FilePath (takeExtension)
import Text.Read (readMaybe)

type Observation = (Text, Text, Text, [FilePath], [(Text, Text)], [Text], Text)

probeSourceChecks :: FilePath -> IO [(Text, Bool, Text)]
probeSourceChecks directory = do
  observations <- readValue (directory <> "/probe-source.data") :: IO (Maybe [Observation])
  controls <- readValue (directory <> "/probe-source-controls.data") :: IO (Maybe [(Text, [Text])])
  cleanup <- readValue (directory <> "/probe-source-cleanup.data") :: IO (Maybe Bool)
  present <- doesPathExist (directory <> "/probe-source-tree")
  let rows = maybe [] id observations
      expectedKeys = [(name, variant, role) | (name, variant, _, _, _) <- examples, role <- ["positive", "negative"]]
      observedKeys = [(name, variant, role) | (name, variant, role, _, _, _, _) <- rows]
      baseline = case [paths | (_, _, "positive", paths, _, _, _) <- rows] of paths : _ -> paths; _ -> []
      validPaths paths = all (`elem` paths) requiredPaths && length paths == length (unique paths)
        && all (\path -> takeExtension path == ".hs" || path == "probe/probe.cabal") paths
      selected name role = [(variant, paths, results, findings, bytes) | (key, variant, control, paths, results, findings, bytes) <- rows, key == name, control == role]
      judge name role = sort (selected name role) == sort
        [(variant, sort (baseline <> [path | role == "negative", not (null path)]),
          [entry | entry@(resultKey, _) <- expectedResults, role == "positive" || resultKey /= omitted],
          [if null path then "ProbeCaseMissing:" <> omitted else "ForeignProbeInput:" <> Text.pack path | role == "negative"],
          if role == "negative" then bytes else "")
        | (key, variant, path, bytes, omitted) <- examples, key == name]
      normalized = [(name, variant, role, sort paths, results, findings, bytes) | (name, variant, role, paths, results, findings, bytes) <- rows]
      check name green detail = ("probe-source." <> name, green, detail)
      expectedControls = ("empty", ["ProbeSourceMissing:" <> Text.pack path | path <- requiredPaths])
        : [(Text.pack path, ["ProbeSourceMissing:" <> Text.pack path]) | path <- requiredPaths]
        <> [("duplicate-case", ["ProbeCaseDuplicate:decode.positive"]), ("unexpected-case", ["ProbeCaseUnexpected:unknown"])]
  pure (check "discovery" (sort observedKeys == sort expectedKeys && validPaths baseline && rows == normalized)
      (Text.pack (show observedKeys))
    : [check (name <> "." <> role) (not (null rows) && judge name role) (Text.pack (show (selected name role)))
       | name <- ["foreign-probe-script", "foreign-probe-fixture", "probe-case-omitted"], role <- ["positive", "negative"]]
    <> [check "control.inventory" (controls == Just expectedControls) (Text.pack (show controls))
       ,check "control.cleanup" (cleanup == Just True && not present) (Text.pack (show (cleanup, present)))])
 where unique = foldr (\value seen -> if value `elem` seen then seen else value : seen) []

readValue :: Read a => FilePath -> IO (Maybe a)
readValue path = do
  contents <- try (TextIO.readFile path) :: IO (Either IOException Text)
  pure (either (const Nothing) (readMaybe . Text.unpack) contents)

requiredPaths :: [FilePath]
requiredPaths = ["src/Amoebius/Toolchain/Probe.hs", "src/probe/ExtensionAdmission.hs",
  "probe/probe.cabal", "probe/app/Decode.hs", "probe/app/Sim.hs", "probe/app/ProbeDeps.hs"]

expectedResults :: [(Text, Text)]
expectedResults = [("decode.positive", "decoded amoebius/3/True"), ("decode.mistyped", "refused type-error"),
  ("sim.clean", "b:2"), ("sim.perturbed", "a:1"), ("codegen.link-token", "0a08616d6f65626975731003"),
  ("bridge.files", "Amoebius/Toolchain/Probe.purs")]

examples :: [(Text, Text, FilePath, Text, Text)]
examples = [("foreign-probe-script", "shell", "probe/run.sh", "exit 0\n", "")
  ,("foreign-probe-script", "python", "probe/check.py", "print(True)\n", "")
  ,("foreign-probe-script", "extensionless", "src/probe/check", "#!/bin/sh\nexit 0\n", "")
  ,("foreign-probe-fixture", "json", "probe/case.json", "{\"expected\":true}\n", "")
  ,("foreign-probe-fixture", "yaml", "probe/case.yaml", "expected: true\n", "")
  ,("foreign-probe-fixture", "tsv", "probe/expected.tsv", "case\taccepted\n", "")
  ,("foreign-probe-fixture", "dhall", "probe/case.dhall", "{ probeName = \"amoebius\", probeReplicas = 3, probeEnabled = True }\n", "")
  ,("foreign-probe-fixture", "proto", "probe/probe.proto", "syntax = \"proto3\";\npackage amoebius.probe;\nmessage ProbeMessage {\n  string name = 1;\n  uint32 replicas = 2;\n}\n", "")
  ,("foreign-probe-fixture", "purescript", "src/probe/Contract.purs", "module Contract where\n", "")]
  <> [("probe-case-omitted", name, "", "", name) | name <- ["decode.positive", "decode.mistyped", "sim.clean", "sim.perturbed", "codegen.link-token", "bridge.files"]]
