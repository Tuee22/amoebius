{-# LANGUAGE OverloadedStrings #-}
-- Independent original-policy bytes, complete discovery and exact refusals.
module IgnoreContextOracle (ignoreContextChecks, ignoreContextExampleChecks, runIgnoreContextOracle) where

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

type Observation = (Text, Text, Text, [FilePath], [(FilePath, Text)], [Text])

runIgnoreContextOracle :: FilePath -> IO ()
runIgnoreContextOracle directory = do
  rows <- ignoreContextChecks directory
  mapM_ (\(name, green, detail) -> TextIO.putStrLn (Text.intercalate "\t" [name, if green then "green" else "red", detail])) rows
  unless (all (\(_, green, _) -> green) rows) exitFailure

ignoreContextChecks :: FilePath -> IO [(Text, Bool, Text)]
ignoreContextChecks directory = do
  root <- getCurrentDirectory
  original <- try (walk root []) :: IO (Either IOException [FilePath])
  originalBytes <- try (mapM (\path -> (path,) <$> TextIO.readFile (root </> path)) policies) :: IO (Either IOException [(FilePath, Text)])
  baseline <- readValue (directory <> "/ignore-context-baseline.data") :: IO (Maybe [FilePath])
  observations <- readValue (directory <> "/ignore-context.data") :: IO (Maybe [Observation])
  controls <- readValue (directory <> "/ignore-context-controls.data") :: IO (Maybe [(Text, [(FilePath, Text)], [Text])])
  cleanup <- readValue (directory <> "/ignore-context-cleanup.data") :: IO (Maybe Bool)
  present <- doesPathExist (directory <> "/ignore-context-tree")
  let paths = maybe [] id baseline
      rows = maybe [] id observations
      originals = either (const []) id originalBytes
      complete = not (null paths) && paths == sort (nub paths)
        && either (const False) ((== paths) . sort) original
        && map fst originals == policies
        && all (`elem` paths) (policies <> ["src/Amoebius/Layout/Classify.hs", "test/layout/IgnoreContextCases.hs", "test/oracle/layout/IgnoreContextOracle.hs"])
      keys = [(name, variant, role) | (name, variant, _, _, _) <- examples, role <- ["positive", "negative"]]
      selected name role = [(variant, found, bytes, findings) | (key, variant, control, found, bytes, findings) <- rows, key == name, control == role]
      expected name role = [(variant, paths, [(path, bytes <> if path == target && role == "negative" then suffix else "") | (path,bytes) <- originals],
          [code <> "\t" <> Text.pack target <> ":" <> Text.strip suffix | role == "negative"])
        | (key, variant, target, suffix, code) <- examples, key == name]
      expectedControls = [(name, [(path, if path == target then transform bytes else bytes) | (path,bytes) <- originals], findings)
        | (name,target,transform,findings) <- controlCases]
      inventoryDelta = either (const Nothing) (\found -> Just (length found,
        sort (filter (`notElem` paths) found), filter (`notElem` found) paths)) original
      check name green detail = ("ignore-context." <> name, green, detail)
  pure (check "discovery" (complete && sort [(a,b,c) | (a,b,c,_,_,_) <- rows] == sort keys)
      (Text.pack (show (length paths, inventoryDelta, [(a,b,c) | (a,b,c,_,_,_) <- rows])))
    : [check (name <> "." <> role) (complete && sort (selected name role) == sort (expected name role))
        (Text.pack (show [(variant, length found, findings) | (variant,found,_,findings) <- selected name role]))
        | name <- ["retired-generated-root", "undeclared-state-root"], role <- ["positive", "negative"]]
    <> [check "control.inventory" (complete && controls == Just expectedControls) (Text.pack (show (fmap (map (\(name,_,findings) -> (name,findings))) controls))),
        check "control.cleanup" (cleanup == Just True && not present) (Text.pack (show (cleanup,present)))])

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
        unless (not linked) (fail "IgnoreContextInventorySymlink")
        if directory then walk root next else do
          regular <- doesFileExist (root </> path)
          unless regular (fail "IgnoreContextInventoryNode")
          pure [path])

ignoreContextExampleChecks :: [Text] -> [(Text, Bool, Text)]
ignoreContextExampleChecks report =
  [("ignore-context.product-examples", sort observed == sort expected, Text.pack (show observed))]
 where
  observed = [fields | row <- report, "ignore-context-example" : fields <- [Text.splitOn "\t" row]]
  expected = [[name,variant,Text.pack path] | (name,variant,path,_,_) <- examples]

readValue :: Read a => FilePath -> IO (Maybe a)
readValue path = do
  content <- try (TextIO.readFile path) :: IO (Either IOException Text)
  pure (either (const Nothing) (readMaybe . Text.unpack) content)

policies :: [FilePath]
policies = [".gitignore", ".dockerignore"]

examples :: [(Text, Text, FilePath, Text, Text)]
examples = [("retired-generated-root", Text.pack path <> ":" <> root, path, root <> "\n", "RetiredIgnoreRoot")
  | path <- policies, root <- ["ui/", "dhall/", "proto/", "pulumi/", "tools/", "test/golden/"]]
  <> [("undeclared-state-root", Text.pack path <> ":" <> patternText, path, patternText <> "\n", "UnexpectedIgnorePattern")
      | (path,patterns) <- [(".gitignore", ["/src/.generated/", "/scratch/"]), (".dockerignore", ["src/.generated", "scratch"])], patternText <- patterns]

controlCases :: [(Text, FilePath, Text -> Text, [Text])]
controlCases =
  [("missing-state:" <> Text.pack path, path, omit patternText,
      ["MissingIgnoreRoot\t" <> Text.pack path <> ":" <> patternText, "MissingIgnorePattern\t" <> Text.pack path <> ":" <> patternText])
    | (path,patternText) <- [(".gitignore", "/.build/"), (".dockerignore", ".build")]]
  <> [("missing-spill:" <> Text.pack path, path, omit patternText, ["MissingIgnorePattern\t" <> Text.pack path <> ":" <> patternText])
      | (path,patternText) <- [(".gitignore", "*.o"), (".dockerignore", "**/*.o")]]
  <> [("hidden-archive", ".gitignore", (<> "validation-records/\n"), ["IgnoredValidationArchive\t.gitignore"])]
  <> [("comments:" <> Text.pack path, path, (<> "\n# tools/ is a comment\n\n"), []) | path <- policies]
 where omit patternText = Text.unlines . filter ((/= patternText) . Text.strip) . Text.lines
