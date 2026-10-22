{-# LANGUAGE OverloadedStrings #-}
-- Independent whole-source inventory and Pulumi-root refusal expectations.
module PulumiSourceOracle (pulumiSourceChecks, pulumiSourceExampleChecks, runPulumiSourceOracle) where

import Control.Exception (IOException, try)
import Control.Monad (forM, unless)
import Data.List (intercalate, nub, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (doesDirectoryExist, doesFileExist, doesPathExist, getCurrentDirectory, listDirectory, pathIsSymbolicLink)
import System.Exit (exitFailure)
import System.FilePath ((</>))
import Text.Read (readMaybe)

type Observation = (Text, Text, Text, [FilePath], [Text], Text)

runPulumiSourceOracle :: FilePath -> IO ()
runPulumiSourceOracle directory = do
  checks <- pulumiSourceChecks directory
  mapM_ (\(name, green, detail) -> TextIO.putStrLn (Text.intercalate "\t" [name, if green then "green" else "red", detail])) checks
  unless (all (\(_, green, _) -> green) checks) exitFailure

pulumiSourceChecks :: FilePath -> IO [(Text, Bool, Text)]
pulumiSourceChecks directory = do
  original <- try (getCurrentDirectory >>= \root -> walk root []) :: IO (Either IOException [FilePath])
  baseline <- readValue (directory <> "/pulumi-source-baseline.data") :: IO (Maybe [FilePath])
  observations <- readValue (directory <> "/pulumi-source.data") :: IO (Maybe [Observation])
  controls <- readValue (directory <> "/pulumi-source-controls.data") :: IO (Maybe [(Text, [Text])])
  cleanup <- readValue (directory <> "/pulumi-source-cleanup.data") :: IO (Maybe Bool)
  present <- doesPathExist (directory <> "/pulumi-source-tree")
  let paths = maybe [] id baseline
      rows = maybe [] id observations
      complete = not (null paths) && paths == sort (nub paths)
        && either (const False) ((== paths) . sort) original
        && all (`elem` paths) ["amoebius.cabal", "src/Amoebius/Layout/Classify.hs",
             "test/layout/SourcePathCases.hs", "test/oracle/layout/PulumiSourceOracle.hs"]
      keys = [(name, variant, role) | (name, variant, _, _, _) <- examples, role <- ["positive", "negative"]]
      selected name role = [(variant, found, findings, bytes) | (key, variant, control, found, findings, bytes) <- rows, key == name, control == role]
      expected name role = [(variant, sort (paths <> [path | role == "negative"]),
          [code <> "\t" <> Text.pack path | role == "negative"], if role == "negative" then bytes else "")
        | (key, variant, path, bytes, code) <- examples, key == name]
      inventoryDelta = either (const Nothing) (\found -> Just (length found,
        sort (filter (`notElem` paths) found), filter (`notElem` found) paths)) original
      expectedControls = [("empty", "TestSourceInventoryEmpty\ttest" :
          ["MissingMetadata\t" <> path | path <- ["amoebius.cabal", "cabal.project", "probe/probe.cabal", ".gitignore", ".dockerignore", "LICENSE"]]),
        ("duplicate", ["DuplicateTrackedPath\tamoebius.cabal"])]
      check name green detail = ("pulumi-source." <> name, green, detail)
  pure (check "discovery" (complete && sort [(a,b,c) | (a,b,c,_,_,_) <- rows] == sort keys)
      (Text.pack (show (length paths, inventoryDelta, [(a,b,c) | (a,b,c,_,_,_) <- rows])))
    : [check (name <> "." <> role) (not (null paths) && sort (selected name role) == sort (expected name role))
        (Text.pack (show [(variant, length found, findings, bytes) | (variant, found, findings, bytes) <- selected name role]))
        | name <- ["tracked-pulumi-yaml", "renamed-pulumi-program"], role <- ["positive", "negative"]]
    <> [check "control.inventory" (controls == Just expectedControls) (Text.pack (show controls)),
        check "control.cleanup" (cleanup == Just True && not present) (Text.pack (show (cleanup,present)))])

-- The protected source snapshot excludes state, Git administration and the
-- separately verified historical archive. Every other root is enumerated.
walk :: FilePath -> [FilePath] -> IO [FilePath]
walk root pieces = do
  entries <- sort <$> listDirectory (root </> intercalate "/" pieces)
  concat <$> forM entries (\name -> do
      let next = pieces <> [name]
          path = intercalate "/" next
      directory <- doesDirectoryExist (root </> path)
      if null pieces && (name == ".git" || directory && name `elem` [".build", ".data", ".test_data", "dist-newstyle", "validation-records"])
        then pure [] else do
          linked <- pathIsSymbolicLink (root </> path)
          unless (not linked) (fail "PulumiSourceInventorySymlink")
          if directory then walk root next else do
            regular <- doesFileExist (root </> path)
            unless regular (fail "PulumiSourceInventoryNode")
            pure [path])

pulumiSourceExampleChecks :: [Text] -> [(Text, Bool, Text)]
pulumiSourceExampleChecks report =
  [("pulumi-source.product-examples", sort observed == sort expected, Text.pack (show observed))]
 where
  observed = [fields | row <- report, "pulumi-source-example" : fields <- [Text.splitOn "\t" row]]
  expected = [[name, variant, Text.pack path] | (name, variant, path, _, _) <- examples]

readValue :: Read a => FilePath -> IO (Maybe a)
readValue path = do
  contents <- try (TextIO.readFile path) :: IO (Either IOException Text)
  pure (either (const Nothing) (readMaybe . Text.unpack) contents)

examples :: [(Text, Text, FilePath, Text, Text)]
examples =
  [("tracked-pulumi-yaml", "original-root", "pulumi/Pulumi.yaml", "resources: {}\n", "TrackedPulumiProgram")
  ,("renamed-pulumi-program", "yaml", "infrastructure/Pulumi.yaml", "resources: {}\n", "UnclassifiedTrackedPath")
  ,("renamed-pulumi-program", "typescript", "infrastructure/index.ts", "export const accepted = true;\n", "UnclassifiedTrackedPath")
  ,("renamed-pulumi-program", "python", "infrastructure/__main__.py", "accepted = True\n", "TrackedPythonOutsidePb")]
