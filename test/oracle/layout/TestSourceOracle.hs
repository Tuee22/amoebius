{-# LANGUAGE OverloadedStrings #-}
-- Independent test-source inventory, byte and refusal expectations.
module TestSourceOracle (testSourceChecks, testSourceExampleChecks, runTestSourceOracle) where

import Control.Exception (IOException, try)
import Control.Monad (forM, unless)
import Data.List (nub, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (doesDirectoryExist, doesFileExist, doesPathExist, getCurrentDirectory, listDirectory, pathIsSymbolicLink)
import System.Exit (exitFailure)
import System.FilePath (takeExtension, (</>))
import Text.Read (readMaybe)

type Observation = (Text, Text, Text, [FilePath], [(FilePath, Text)], [Text], Text)

runTestSourceOracle :: FilePath -> IO ()
runTestSourceOracle directory = do
  checks <- testSourceChecks directory
  mapM_ (\(name, green, detail) -> TextIO.putStrLn (Text.intercalate "\t" [name, if green then "green" else "red", detail])) checks
  unless (all (\(_, green, _) -> green) checks) exitFailure

testSourceChecks :: FilePath -> IO [(Text, Bool, Text)]
testSourceChecks directory = do
  sourcePaths <- try (getCurrentDirectory >>= \root -> walk root "test") :: IO (Either IOException [FilePath])
  baseline <- readValue (directory <> "/test-source-baseline.data") :: IO (Maybe [FilePath])
  observations <- readValue (directory <> "/test-source.data") :: IO (Maybe [Observation])
  controls <- readValue (directory <> "/test-source-controls.data") :: IO (Maybe [(Text, [Text])])
  cleanup <- readValue (directory <> "/test-source-cleanup.data") :: IO (Maybe Bool)
  present <- doesPathExist (directory <> "/test-source-tree")
  let paths = maybe [] id baseline
      rows = maybe [] id observations
      validPaths = not (null paths) && paths == sort (nub paths)
        && all (\path -> "test/" `Text.isPrefixOf` Text.pack path && takeExtension path == ".hs") paths
        && all (`elem` paths) ["test/layout/Main.hs", "test/layout/TestSourceCases.hs",
             "test/oracle/layout/Main.hs", "test/oracle/layout/TestSourceOracle.hs"]
      completePaths = either (const False) ((== paths) . sort) sourcePaths
      inventoryDelta = either (const Nothing) (\found -> Just (length found,
        sort (filter (`notElem` paths) found), filter (`notElem` found) paths)) sourcePaths
      selected name role = [(variant, found, classes, findings, bytes) | (key, variant, control, found, classes, findings, bytes) <- rows, key == name, control == role]
      expected name role = [(variant, sort (paths <> [path]),
          [(candidate, "haskell-source") | candidate <- sort (paths <> [path]), role == "positive" || candidate /= path],
          ["NonHaskellTestInput\t" <> Text.pack path | role == "negative"], bytes)
        | (key, variant, foreignPath, foreignBytes) <- examples, key == name,
          let (path, bytes) = if role == "negative" then (foreignPath, foreignBytes) else (controlPath, controlBytes)]
      keys = [(name, variant, role) | (name, variant, _, _) <- examples, role <- ["positive", "negative"]]
      duplicate = "test/layout/Main.hs"
      expectedControls = [("empty", ["TestSourceInventoryEmpty\ttest"]),
        ("duplicate", ["DuplicateTrackedPath\t" <> Text.pack duplicate])]
      check name green detail = ("test-source." <> name, green, detail)
  pure (check "discovery" (validPaths && completePaths && sort [(a,b,c) | (a,b,c,_,_,_,_) <- rows] == sort keys)
      (Text.pack (show (length paths, inventoryDelta, [(a,b,c) | (a,b,c,_,_,_,_) <- rows])))
    : [check (name <> "." <> role) (validPaths && sort (selected name role) == sort (expected name role))
          (Text.pack (show (selected name role))) | name <- names, role <- ["positive", "negative"]]
    <> [check "control.inventory" (controls == Just expectedControls) (Text.pack (show controls)),
        check "control.cleanup" (cleanup == Just True && not present) (Text.pack (show (cleanup,present)))])

-- Enumerate the original tree independently, before trusting a subject inventory.
-- No production walker, filename exclusion, or caller-reported count is consulted.
walk :: FilePath -> FilePath -> IO [FilePath]
walk root relative = do
  entries <- sort <$> listDirectory (root </> relative)
  concat <$> forM entries (\name -> do
    let path = relative <> "/" <> name
    linked <- pathIsSymbolicLink (root </> path)
    unless (not linked) (fail "TestSourceInventorySymlink")
    directory <- doesDirectoryExist (root </> path)
    if directory then walk root path else do
      regular <- doesFileExist (root </> path)
      unless regular (fail "TestSourceInventoryNode")
      pure [path])

testSourceExampleChecks :: [Text] -> [(Text, Bool, Text)]
testSourceExampleChecks report =
  [("test-source.product-examples", sort observed == sort expected, Text.pack (show observed))]
 where
  observed = [fields | row <- report, "test-source-example" : fields <- [Text.splitOn "\t" row]]
  expected = [[name, variant, Text.pack path] | (name, variant, path, _) <- examples]

readValue :: Read a => FilePath -> IO (Maybe a)
readValue path = do
  contents <- try (TextIO.readFile path) :: IO (Either IOException Text)
  pure (either (const Nothing) (readMaybe . Text.unpack) contents)

controlPath :: FilePath
controlPath = "test/source-control/Input.hs"
controlBytes :: Text
controlBytes = "module Input where\ninput :: Bool\ninput = True\n"

names :: [Text]
names = ["tracked-test-script", "tracked-test-table", "tracked-expected-output", "tracked-patch", "tracked-mutant-body"]

examples :: [(Text, Text, FilePath, Text)]
examples =
  [("tracked-test-script", "python", "test/source-control/check.py", "print(True)\n")
  ,("tracked-test-script", "shell", "test/source-control/check.sh", "exit 0\n")
  ,("tracked-test-script", "extensionless", "test/source-control/check", "#!/bin/sh\nexit 0\n")
  ,("tracked-test-table", "json", "test/source-control/cases.json", "{\"expected\":true}\n")
  ,("tracked-test-table", "yaml", "test/source-control/cases.yaml", "expected: true\n")
  ,("tracked-test-table", "tsv", "test/source-control/cases.tsv", "case\texpected\ninput\tTrue\n")
  ,("tracked-expected-output", "golden", "test/golden/output.expected", "accepted\n")
  ,("tracked-expected-output", "output", "test/source-control/output.out", "accepted\n")
  ,("tracked-expected-output", "markdown", "test/source-control/output.md", "expected: accepted\n")
  ,("tracked-patch", "patch", "test/source-control/change.patch", "--- a/Input.hs\n+++ b/Input.hs\n@@ -1 +1 @@\n-old\n+new\n")
  ,("tracked-patch", "diff", "test/source-control/change.diff", "--- a/Input.hs\n+++ b/Input.hs\n@@ -1 +1 @@\n-old\n+new\n")
  ,("tracked-mutant-body", "python", "test/variants/altered.py", "accepted = False\n")
  ,("tracked-mutant-body", "disabled-haskell", "test/variants/altered.hs.disabled", "module Altered where\naccepted = False\n")
  ,("tracked-mutant-body", "extensionless", "test/variants/altered", "accepted = False\n")]
