{-# LANGUAGE OverloadedStrings #-}
-- Independent runtime-name, source-inventory and Cabal-component expectations.
module RuntimeIdentityOracle (runtimeIdentityChecks, runtimeIdentityExampleChecks, runRuntimeIdentityOracle) where

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

runRuntimeIdentityOracle :: FilePath -> IO ()
runRuntimeIdentityOracle directory = do
  rows <- runtimeIdentityChecks directory
  mapM_ (\(name, green, detail) -> TextIO.putStrLn (Text.intercalate "\t" [name, if green then "green" else "red", detail])) rows
  unless (all (\(_, green, _) -> green) rows) exitFailure

runtimeIdentityChecks :: FilePath -> IO [(Text, Bool, Text)]
runtimeIdentityChecks directory = do
  original <- try (getCurrentDirectory >>= \root -> walk root []) :: IO (Either IOException [FilePath])
  baseline <- readValue (directory <> "/runtime-identity-baseline.data") :: IO (Maybe [FilePath])
  observations <- readValue (directory <> "/runtime-identity.data") :: IO (Maybe [Observation])
  controls <- readValue (directory <> "/runtime-identity-controls.data") :: IO (Maybe [(Text, [Text])])
  cleanup <- readValue (directory <> "/runtime-identity-cleanup.data") :: IO (Maybe Bool)
  present <- doesPathExist (directory <> "/runtime-identity-tree")
  let paths = maybe [] id baseline
      rows = maybe [] id observations
      complete = not (null paths) && paths == sort (nub paths)
        && either (const False) ((== paths) . sort) original
        && all (`elem` paths) ["amoebius.cabal", "probe/probe.cabal", "src/Amoebius/Layout/Classify.hs",
          "src/Amoebius/Layout/PackageMap.hs", "test/layout/RuntimeIdentityCases.hs", "test/oracle/layout/RuntimeIdentityOracle.hs"]
      keys = [(name, variant, role) | (name, variant, _, _, _, _) <- examples, role <- ["positive", "negative"]]
      selected name role = [(variant, found, findings, bytes) | (key, variant, control, found, findings, bytes) <- rows, key == name, control == role]
      expected name role = [(variant, sort (paths <> [path | role == "negative", kind == "source"]),
          [finding | role == "negative"], if role == "negative" then bytes else "")
        | (key, variant, kind, path, bytes, finding) <- examples, key == name]
      inventoryDelta = either (const Nothing) (\found -> Just (length found,
        sort (filter (`notElem` paths) found), filter (`notElem` found) paths)) original
      expectedControls = [("validation-source", []), ("validation-component", []),
        ("malformed-package", ["PackageDescriptionUnparsable\tamoebius.cabal"]), ("block-comments", [])]
      check name green detail = ("runtime-identity." <> name, green, detail)
  pure (check "discovery" (complete && sort [(a,b,c) | (a,b,c,_,_,_) <- rows] == sort keys)
      (Text.pack (show (length paths, inventoryDelta, [(a,b,c) | (a,b,c,_,_,_) <- rows])))
    : [check (name <> "." <> role) (not (null paths) && sort (selected name role) == sort (expected name role))
        (Text.pack (show [(variant, length found, findings, bytes) | (variant, found, findings, bytes) <- selected name role]))
        | name <- ["stale-ordinal", "copied-ordinal", "phase-named-runtime"], role <- ["positive", "negative"]]
    <> [check "control.inventory" (controls == Just expectedControls) (Text.pack (show controls)),
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
        unless (not linked) (fail "RuntimeIdentityInventorySymlink")
        if directory then walk root next else do
          regular <- doesFileExist (root </> path)
          unless regular (fail "RuntimeIdentityInventoryNode")
          pure [path])

runtimeIdentityExampleChecks :: [Text] -> [(Text, Bool, Text)]
runtimeIdentityExampleChecks report =
  [("runtime-identity.product-examples", sort observed == sort expected, Text.pack (show observed))]
 where
  observed = [fields | row <- report, "runtime-identity-example" : fields <- [Text.splitOn "\t" row]]
  expected = [[name, variant, kind, Text.pack path] | (name, variant, kind, path, _, _) <- examples]

readValue :: Read a => FilePath -> IO (Maybe a)
readValue path = do
  contents <- try (TextIO.readFile path) :: IO (Either IOException Text)
  pure (either (const Nothing) (readMaybe . Text.unpack) contents)

examples :: [(Text, Text, Text, FilePath, Text, Text)]
examples =
  [("stale-ordinal", variant, "source", "src/Amoebius/IdentityInput.hs",
      "module IdentityInput where\ndiagnosticName = \"" <> label <> "\"\n",
      "OrdinalRuntimeIdentity\tsrc/Amoebius/IdentityInput.hs:2")
     | (variant, label) <- [("plain", "phase42"), ("mixed-case", "pHaSe42"), ("hyphen", "phase-42"), ("underscore", "phase_42"), ("quoted-comment-marker", "{- phase42 -}")]]
  <> [("copied-ordinal", variant, "source", path, "module IdentityInput where\nidentity = \"runtime\"\n",
        "OrdinalRuntimeIdentity\t" <> Text.pack path)
      | (variant, path) <- [("plain", "src/Amoebius/Phase42Copy.hs"),
          ("hyphen", "src/Amoebius/phase-42/Copy.hs"), ("underscore", "app/phase_42/Main.hs")]]
  <> [("phase-named-runtime", variant, "package", "amoebius.cabal", header <> stanza,
        "OrdinalRuntimeIdentity\tamoebius.cabal:" <> component)
      | (variant, component, stanza) <-
        [("executable", "executable:phase42-runtime", "executable phase42-runtime\n  main-is: Main.hs\n  hs-source-dirs: app/amoebius\n  default-language: Haskell2010\n")
        ,("library", "library:phase42-library", "library phase42-library\n  exposed-modules: Example\n  hs-source-dirs: src\n  default-language: Haskell2010\n")
        ,("empty-library", "library:phase42-empty", "library phase42-empty\n  hs-source-dirs: src\n  buildable: False\n")
        ,("foreign-library", "foreign-library:phase42-foreign", "foreign-library phase42-foreign\n  type: native-shared\n  hs-source-dirs: src\n  buildable: False\n")
        ,("benchmark", "benchmark:phase42-benchmark", "benchmark phase42-benchmark\n  type: exitcode-stdio-1.0\n  main-is: Main.hs\n  hs-source-dirs: app/amoebius\n  default-language: Haskell2010\n")
        ,("conditional", "executable:phase42-conditional", "executable phase42-conditional\n  main-is: Main.hs\n  default-language: Haskell2010\n  if os(windows)\n    hs-source-dirs: test/oracle\n  else\n    hs-source-dirs: app/amoebius\n")]]
  <> [("phase-named-runtime", "disguised-validation-root", "package", "amoebius.cabal",
      header <> "library phase42-disguised\n  hs-source-dirs: test/../src\n  buildable: False\n",
      "OrdinalRuntimeIdentity\tamoebius.cabal:library:phase42-disguised")]
 where header = "cabal-version: 3.0\nname: runtime-input\nversion: 0.1.0.0\n"
