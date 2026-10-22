{-# LANGUAGE OverloadedStrings #-}

-- Observations of the actual four factories and their compiled source seals.
module SpineExtensionRegistry (extensionRegistrySection) where

import Amoebius.Extension.AstCheck (AstViolation (..), checkedSourceFiles)
import Amoebius.Extension.Capability (DeclaredCapability (..), coreCapabilities, declaredCapabilityName)
import Amoebius.Extension.SourceClosure
import Amoebius.Extension.Calculi qualified as Calculi
import Amoebius.Extension.Linked (linkRefusalTag)
import Amoebius.Dsl.Examples.Extensions.SourceInputs (sourceTreeInputs, mergeInputs)
import Amoebius.Extension.Linked (extensionOrder, linkedExtensions, linkedExtensionSet)
import Amoebius.Extension.Spec
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString qualified as ByteString
import Data.IORef (newIORef, modifyIORef', readIORef)
import Data.List (nub, sort, isPrefixOf, intercalate)
import Data.List.NonEmpty qualified as NonEmpty
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import Data.Text.IO qualified as Text
import Amoebius.Vocabulary (extensionIdText, mkExtensionId)
import Control.Monad (forM_, forM)
import Numeric (showHex)
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, removePathForcibly)
import System.FilePath ((</>), takeDirectory, makeRelative, normalise, splitDirectories)

extensionRegistrySection :: FilePath -> IO ()
extensionRegistrySection directory = do
  createDirectoryIfMissing True directory
  specifications <- either (fail . show) pure (sequence linkedExtensions)
  links <- either (fail . show) pure linkedExtensionSet
  Text.writeFile (directory </> "registry.tsv") (Text.unlines
    [Text.intercalate "\t" [extensionIdText (extId specification), capabilities (extProvides specification), capabilities (extRequires specification)]
    | specification <- specifications])
  Text.writeFile (directory </> "order.tsv") (Text.unlines (map extensionIdText (extensionOrder links)))
  Text.writeFile (directory </> "core.tsv") (Text.unlines (map declaredCapabilityName coreCapabilities))
  Text.writeFile (directory </> "monitoring.tsv") (Text.unlines
    [extensionIdText (extId specification) <> "\t" <> Text.pack (show (NonEmpty.length (extMonitoring specification))) | specification <- specifications])
  Text.writeFile (directory </> "seals.tsv") (Text.unlines
    [Text.intercalate "\t" [extensionIdText (extId specification), Text.pack path, hex (SHA256.hash (Encoding.encodeUtf8 body))]
    | specification <- specifications, (path, body) <- NonEmpty.toList (checkedSourceFiles (extSourceSeal specification))])
  let make identifier provides requires = mkExtensionSpec identifier () provides requires () (const ([] :: [()])) [] (() NonEmpty.:| []) () ()
      tag = either (Text.pack . extensionSpecRefusalName) (const "accepted")
  Text.writeFile (directory </> "spec-controls.tsv") (Text.unlines
    ["unique-provides-requires\t" <> tag (make () [JitBuild] [Coordination]),
     "duplicate-provides\t" <> tag (make () [JitBuild, JitBuild] [Coordination]),
     "duplicate-requires\t" <> tag (make () [JitBuild] [Coordination, Coordination])])
  graphRows <- forM mergeInputs $ \(name, inputs) -> do
    values <- forM inputs $ \(identifier, provides, requires) -> do
      identity <- maybe (fail "invalid graph input identity") pure (mkExtensionId identifier)
      either (fail . show) pure (make identity provides requires)
    pure (name <> "\t" <> either linkRefusalTag (const "accepted") (Calculi.mergeExtensions values))
  Text.writeFile (directory </> "merge-controls.tsv") (Text.unlines graphRows)
  sources <- case specifications of
    first : _ -> pure (NonEmpty.toList (checkedSourceFiles (extSourceSeal first)))
    [] -> fail "empty actual extension catalog"
  sourceRows <- forM (sourceTreeInputs sources) $ \(name, files, links) -> do
    let root = directory </> "source-inputs" </> Text.unpack name
        tree = root </> contributionRoot
    present <- doesDirectoryExist root
    if present then removePathForcibly root else pure ()
    createDirectoryIfMissing True tree
    forM_ files $ \(path, source) -> do
      createDirectoryIfMissing True (takeDirectory (tree </> path))
      Text.writeFile (tree </> path) source
    (filesystem, events) <- suppliedFilesystem tree files links
    observed <- readContributionClosureWith filesystem root
    let refusal problem = case problem of
          ContributionRejected violations -> "ContributionRejected:" <> Text.intercalate ","
            [Text.pack (show (violationReason value)) <> ":" <> violationNode value | value <- NonEmpty.toList violations]
          _ -> contributionRefusalTag problem
        outcome = either refusal (\seal -> "accepted:" <> Text.pack (show (NonEmpty.length (checkedSourceFiles seal))))
    native <- if null links then outcome <$> readContributionClosure root else pure "supplied-link"
    trace <- events
    pure (name <> "\t" <> outcome observed, name <> "\t" <> native, name <> "\t" <> Text.pack (show trace))
  Text.writeFile (directory </> "source-controls.tsv") (Text.unlines [row | (row, _, _) <- sourceRows])
  Text.writeFile (directory </> "source-native.tsv") (Text.unlines [row | (_, row, _) <- sourceRows])
  Text.writeFile (directory </> "source-boundary.tsv") (Text.unlines [row | (_, _, row) <- sourceRows])
 where
  capabilities = Text.intercalate "," . map declaredCapabilityName
  hex = Text.pack . concatMap (\byte -> let value = showHex byte "" in if length value == 1 then '0' : value else value) . ByteString.unpack

-- The tree and links are corpus inputs, not expected outcomes. Every operation
-- is recorded for the product-free oracle; no OS link creation is involved.
suppliedFilesystem :: FilePath -> [(FilePath, Text.Text)] -> [(FilePath, FilePath)]
  -> IO (ContributionFilesystem, IO [(Text.Text, FilePath)])
suppliedFilesystem tree files links = do
  history <- newIORef []
  let parts = filter (/= ".") . splitDirectories . normalise
      relative path = intercalate "/" (parts (makeRelative tree path))
      entries = map (parts . fst) files <> map (parts . fst) links
      directories = [] : nub [take size path | path <- entries, size <- [1 .. length path - 1]]
      record :: Text.Text -> FilePath -> value -> IO value
      record kind path value = modifyIORef' history (<> [(kind, relative path)]) >> pure value
      bytes path = do
        modifyIORef' history (<> [("bytes", relative path)])
        maybe (ioError (userError "supplied source file absent")) (pure . Encoding.encodeUtf8) (lookup (relative path) files)
      filesystem = ContributionFilesystem
        (\path -> record "directory" path (parts (relative path) `elem` directories))
        (\path -> record "link" path (relative path `elem` map fst links))
        (\path -> let prefix = parts (relative path) in record "children" path
          (sort (nub [entry !! length prefix | entry <- entries, prefix `isPrefixOf` entry, length entry > length prefix])))
        bytes
  pure (filesystem, readIORef history)
