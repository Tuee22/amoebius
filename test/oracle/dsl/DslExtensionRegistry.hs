{-# LANGUAGE OverloadedStrings #-}

-- Literal catalog expectations and independent hashes of the actual source
-- files. The linked product does not supply an expected digest or verdict.
module DslExtensionRegistry (extensionRegistryRows, extensionRegistryRowsWithHelper) where

import Control.Exception (IOException, try)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString qualified as ByteString
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import DslExtensionContract
import Numeric (showHex)
import System.FilePath ((</>))
import Text.Read qualified as Read

extensionRegistryRows :: FilePath -> FilePath -> IO [(Text, Bool, Text)]
extensionRegistryRows = registryRows contributionModules

-- Counterfactual input adds a pure, initially unreferenced helper. A cached
-- four-file seal must fail this independent five-file expectation.
extensionRegistryRowsWithHelper :: FilePath -> FilePath -> IO [(Text, Bool, Text)]
extensionRegistryRowsWithHelper = registryRows (sort (contributionModules <> ["Amoebius.Extension.Contributed.GuardProbe"]))

registryRows :: [Text] -> FilePath -> FilePath -> IO [(Text, Bool, Text)]
registryRows modules root directory = do
  registry <- readMaybe (directory </> "registry.tsv")
  order <- readMaybe (directory </> "order.tsv")
  core <- readMaybe (directory </> "core.tsv")
  counts <- readMaybe (directory </> "monitoring.tsv")
  seals <- readMaybe (directory </> "seals.tsv")
  specControls <- readMaybe (directory </> "spec-controls.tsv")
  mergeControls <- readMaybe (directory </> "merge-controls.tsv")
  treeControls <- readMaybe (directory </> "source-controls.tsv")
  nativeControls <- readMaybe (directory </> "source-native.tsv")
  boundary <- readMaybe (directory </> "source-boundary.tsv")
  sourceRows <- mapM source modules
  let rows = maybe [] Text.lines
      expectedRegistry = [Text.intercalate "\t" [identifier, Text.intercalate "," provided, Text.intercalate "," required]
        | (identifier, provided, required) <- extensionGraph]
      expectedSeals = [Text.intercalate "\t" [identifier, path, digest]
        | identifier <- linkedIds, Just (path, digest) <- sourceRows]
      traces = [(name, Read.readMaybe (Text.unpack body) :: Maybe [(Text, FilePath)])
        | line <- rows boundary, [name, body] <- [Text.splitOn "\t" line]]
      linkTrace = case [trace | ("source-symlink", Just trace) <- traces] of
        [trace] -> trace
        _ -> []
      linkedPath = "Amoebius/Extension/Contributed/GuardProbe.hs"
  pure
    [ ("registry.actual-spec-fields", rows registry == expectedRegistry, maybe "missing registry" id registry)
    , ("registry.dependency-order", rows order == extensionDependencyOrder, maybe "missing order" id order)
    , ("registry.core-inventory", rows core == coreCapabilityNames, maybe "missing core" id core)
    , ("registry.nonempty-monitoring", rows counts == [identifier <> "\t" <> Text.pack (show count) | (identifier, count) <- monitoringCounts], maybe "missing monitoring" id counts)
    , ("registry.source-seals", all (/= Nothing) sourceRows && rows seals == expectedSeals, maybe "missing seals" id seals)
    , ("registry.spec-controls", rows specControls == controlRows specRuntimeControls, maybe "missing controls" id specControls)
    , ("registry.merge-controls", rows mergeControls == controlRows mergeRuntimeControls, maybe "missing controls" id mergeControls)
    , ("registry.source-controls", rows treeControls == controlRows sourceTreeControls, maybe "missing controls" id treeControls)
    , ("registry.source-native-controls", rows nativeControls == controlRows
        [(name, if name == "source-symlink" then "supplied-link" else result) | (name, result) <- sourceTreeControls],
        maybe "missing native controls" id nativeControls)
    , ("registry.source-boundary-discovery", sort (map fst traces) == sort (map fst sourceTreeControls)
        && length traces == length (rows boundary) && all ((/= Nothing) . snd) traces, maybe "missing boundary observations" id boundary)
    , ("registry.source-link-observation", length [() | ("link", path) <- linkTrace, path == linkedPath] == 1
        && all (\(kind, path) -> kind /= "bytes" && (path /= linkedPath || kind == "link")) linkTrace,
        Text.pack (show linkTrace))
    ]
 where
  controlRows = map (\(name, result) -> name <> "\t" <> result)
  source name = do
    let path = Text.unpack (Text.replace "." "/" name <> ".hs")
    content <- try (ByteString.readFile (root </> "src/extension-contributions" </> path)) :: IO (Either IOException ByteString.ByteString)
    pure (either (const Nothing) (\bytes -> Just (Text.pack path, hex (SHA256.hash bytes))) content)
  hex = Text.pack . concatMap (\byte -> let value = showHex byte "" in if length value == 1 then '0' : value else value) . ByteString.unpack
  readMaybe path = either (const Nothing) Just <$> (try (Text.readFile path) :: IO (Either IOException Text))
