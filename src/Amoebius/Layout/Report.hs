{-# LANGUAGE OverloadedStrings #-}

-- | Shipped path-classification report. The default inventory is acquired
-- directly from Git. A caller may provide a run-local path inventory when
-- challenging a copied tree; every path in either inventory is classified.
module Amoebius.Layout.Report
  ( runLayoutReport, SourceSnapshot, captureLayoutSnapshot, compareLayoutSnapshots
  , SourceGraphEdit (..), sourceGraphExamples, sourceGraphExamplePath, sourceGraphExampleSource ) where

import Amoebius.Layout.Classify
import Amoebius.Layout.PackageMap (emptyPackageCatalog, loadPackageCatalog, packageMapReport)
import Amoebius.Layout.PbGrammar
import Amoebius.Layout.SourceGraph (sourceGraphWithPackageCatalog)
import Control.Exception (IOException, try)
import Control.Monad (filterM)
import Control.Monad (forM)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.Bits ((.&.))
import Data.ByteString qualified as ByteString
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Text.IO qualified as TextIO
import Data.List (group, sort)
import Numeric (showHex)
import Text.Read (readMaybe)
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, doesFileExist, listDirectory, pathIsSymbolicLink)
import System.Exit (ExitCode (..), exitWith)
import System.FilePath (takeDirectory, (</>))
import System.IO (hPutStrLn, stderr)
import System.Process (readProcessWithExitCode)
import System.PosixCompat.Files (FileStatus, fileMode, getSymbolicLinkStatus, isRegularFile)

data Options = Options
  { optionRoot :: FilePath
  , optionPathsFile :: Maybe FilePath
  , optionOutput :: Maybe FilePath
  , optionGraph :: Bool
  , optionSnapshotFile :: Maybe FilePath
  }

runLayoutReport :: [String] -> IO ()
runLayoutReport arguments = case parseOptions (Options "." Nothing Nothing True Nothing) arguments of
  Left problem -> hPutStrLn stderr problem >> exitWith (ExitFailure 2)
  Right options -> do
    acquired <- acquirePaths options
    case acquired of
      Left problem -> hPutStrLn stderr problem >> exitWith (ExitFailure 2)
      Right paths -> do
        snapshot <- captureLayoutSnapshot (optionRoot options)
        reference <- case optionSnapshotFile options of
          Nothing -> pure Nothing
          Just file -> do
            bytes <- TextIO.readFile file
            case readMaybe (Text.unpack bytes) of
              Nothing -> hPutStrLn stderr "layout-report: malformed source snapshot" >> exitWith (ExitFailure 2)
              Just value -> pure (Just value)
        let snapshotFindings = maybe [] (`compareLayoutSnapshots` snapshot) reference
        let (classified, pathFindings) = classifyPaths paths
        absent <- mapM (missingPath (optionRoot options)) paths
        shapeFindings <- concat <$> mapM (inspectShape (optionRoot options)) paths
        bootstrap <- checkBootstrap (optionRoot options) [path | (path,kind,_,_) <- snapshot,kind == "regular"]
        packageBytes <- try (ByteString.readFile (optionRoot options </> "amoebius.cabal")) :: IO (Either IOException ByteString.ByteString)
        probeBytes <- try (ByteString.readFile (optionRoot options </> "probe/probe.cabal")) :: IO (Either IOException ByteString.ByteString)
        ignoreFindings <- concat <$> mapM (inspectIgnore (optionRoot options)) [".gitignore", ".dockerignore"]
        let (packageFindings, packageRows, componentMap, dependencyMap, packageMap, forwardOwned) = case (packageBytes, probeBytes) of
              (Left _, _) -> ([LayoutFinding "PackageDescriptionUnreadable" "amoebius.cabal"], [], mempty, mempty, mempty, mempty)
              (_, Left _) -> ([LayoutFinding "PackageDescriptionUnreadable" "probe/probe.cabal"], [], mempty, mempty, mempty, mempty)
              (Right mainPackage, Right probePackage) -> packageMapReport mainPackage probePackage paths
        catalogResult <- if null packageFindings && optionGraph options then loadPackageCatalog packageMap
          else pure (Right (emptyPackageCatalog, []))
        let (catalogFindings, catalogRows, catalog) = case catalogResult of
              Left problem -> ([problem], [], emptyPackageCatalog)
              Right (loaded, rows) -> ([], rows, loaded)
        -- The graph is the report's costliest stage. A caller that judges only the
        -- classification may skip it; the report then says so and states no stage.
        (graphFindings, graphRows) <- if optionGraph options
          then sourceGraphWithPackageCatalog
            (optionRoot options) paths componentMap dependencyMap catalog forwardOwned
          else pure ([], ["graph-stage\tnot-computed"])
        let rows =
              [Text.intercalate "\t" ["path", Text.pack path, renderPathClass pathClass] | (path, pathClass) <- classified]
                <> [Text.intercalate "\t" ["source-snapshot", Text.pack path, kind, Text.pack (show mode), digest] | (path,kind,mode,digest) <- snapshot]
                <> [Text.intercalate "\t" ["source-graph-example", name, Text.pack sourceGraphExamplePath] | (name,_) <- sourceGraphExamples]
                <> [Text.intercalate "\t" ["bootstrap-source-example", name, "pb/__main__.py"] | (name,_) <- bootstrapSourceExamples]
                <> ["finding\t" <> renderFinding finding | finding <- snapshotFindings]
                <> [Text.intercalate "\t" ["test-source-example", name, variant, Text.pack path] | (name, variant, path, _) <- testSourceExamples]
                <> [Text.intercalate "\t" ["tool-source-example", name, variant, Text.pack path] | (name, variant, path, _) <- toolSourceExamples]
                <> [Text.intercalate "\t" ["pulumi-source-example", name, variant, Text.pack path] | (name, variant, path, _) <- pulumiSourceExamples]
                <> [Text.intercalate "\t" ["runtime-identity-example", name, variant, kind, Text.pack path]
                    | (name, variant, input) <- runtimeIdentityExamples,
                      let (kind, path) = case input of RuntimeIdentitySource file _ -> ("source", file); RuntimeIdentityPackage file _ -> ("package", file)]
                <> [Text.intercalate "\t" ["ignore-context-example", name, variant, Text.pack path] | (name,variant,path,_) <- ignoreContextExamples]
                <> ["finding\t" <> renderFinding finding | finding <- pathFindings]
                <> ["finding\tTrackedPathMissing\t" <> Text.pack path | Just path <- absent]
                <> ["finding\t" <> renderFinding finding | finding <- shapeFindings]
                <> ["finding\t" <> renderFinding finding | finding <- ignoreFindings]
                <> ["finding\t" <> renderFinding finding | finding <- packageFindings]
                <> packageRows
                <> ["finding\t" <> renderFinding finding | finding <- catalogFindings]
                <> catalogRows
                <> ["finding\t" <> renderFinding finding | finding <- graphFindings]
                <> graphRows
                <> either (const []) id bootstrap
                <> either (\problem -> ["finding\t" <> renderBootstrapRefusal problem <> "\tpb/__main__.py"]) (const []) bootstrap
            rendered = Text.unlines rows
        case optionOutput options of
          Nothing -> TextIO.putStr rendered
          Just destination -> do
            createDirectoryIfMissing True (takeDirectory destination)
            TextIO.writeFile destination rendered
        if null snapshotFindings && null pathFindings && null shapeFindings && null ignoreFindings && null packageFindings && null catalogFindings && null graphFindings && all (== Nothing) absent && either (const False) (const True) bootstrap
          then pure ()
          else exitWith (ExitFailure 1)

parseOptions :: Options -> [String] -> Either String Options
parseOptions options arguments = case arguments of
  [] -> Right options
  "--root" : value : rest -> parseOptions options {optionRoot = value} rest
  "--paths-file" : value : rest -> parseOptions options {optionPathsFile = Just value} rest
  "--output" : value : rest -> parseOptions options {optionOutput = Just value} rest
  "--no-graph" : rest -> parseOptions options {optionGraph = False} rest
  "--snapshot-file" : value : rest -> parseOptions options {optionSnapshotFile = Just value} rest
  _ -> Left "layout-report: expected [--root DIR] [--paths-file FILE] [--output FILE] [--no-graph] [--snapshot-file FILE]"

-- The reference is supplied independently by the caller. Acquiring a second
-- observation from the candidate cannot establish its original source identity.
-- Hashes here bind source bytes; they impose no native-toolchain byte pin.
type SourceSnapshot = [(FilePath, Text, Integer, Text)]

captureLayoutSnapshot :: FilePath -> IO SourceSnapshot
captureLayoutSnapshot root = sort <$> walk ""
 where
  walk relative = do
    names <- sort <$> listDirectory (root </> relative)
    concat <$> forM names (\name -> do
      let path = if null relative then name else relative <> "/" <> name
          absolute = root </> path
      linked <- pathIsSymbolicLink absolute
      directory <- doesDirectoryExist absolute
      if null relative && (name == ".git" || directory && not linked && name `elem` [".build", ".data", ".test_data", "dist-newstyle", "validation-records"])
        then pure [] else if directory && not linked then walk path else do
          status <- getSymbolicLinkStatus absolute
          let regular = not linked && isRegularFile status
              kind = if regular then "regular" else if linked then "symlink" else "special"
          bytes <- if regular then ByteString.readFile absolute else pure ByteString.empty
          let digest = Text.pack (concatMap (\byte -> let value = showHex byte "" in if length value == 1 then '0' : value else value) (ByteString.unpack (SHA256.hash bytes)))
          pure [(path,kind,toInteger (fileMode status .&. 0o7777),digest)])

compareLayoutSnapshots :: SourceSnapshot -> SourceSnapshot -> [LayoutFinding]
compareLayoutSnapshots expected actual =
  [LayoutFinding "SourceSnapshotReferenceEmpty" "source" | null expected]
  <> [LayoutFinding "SourceSnapshotObservedEmpty" "source" | null actual]
  <> [LayoutFinding "SourceSnapshotDuplicate" path | paths <- [map pathOf expected,map pathOf actual], path : _ : _ <- group (sort paths)]
  <> [LayoutFinding "SourceSnapshotPathMissing" path | entry <- expected, let path = pathOf entry, path `notElem` map pathOf actual]
  <> [LayoutFinding "SourceSnapshotPathUnexpected" path | entry <- actual, let path = pathOf entry, path `notElem` map pathOf expected]
  <> concat [ [LayoutFinding "SourceSnapshotKindChanged" path | kind /= foundKind]
      <> [LayoutFinding "SourceSnapshotModeChanged" path | mode /= foundMode]
      <> [LayoutFinding "SourceSnapshotBytesChanged" path | digest /= foundDigest]
    | (path,kind,mode,digest) <- expected, (found,foundKind,foundMode,foundDigest) <- actual, path == found]
 where pathOf (path,_,_,_) = path

data SourceGraphEdit = OmitSourcePath | ChangeSourceMode | AppendSourceBytes Text | ReplaceSourceBytes Text deriving (Eq, Show)

sourceGraphExamplePath :: FilePath
sourceGraphExamplePath = "test/SnapshotControl.hs"

sourceGraphExampleSource :: Text
sourceGraphExampleSource = "{-# LANGUAGE NoImplicitPrelude #-}\nmodule SnapshotControl where\nvalue = ()\n"

sourceGraphExamples :: [(Text, SourceGraphEdit)]
sourceGraphExamples =
  [("path-omitted", OmitSourcePath), ("mode-changed", ChangeSourceMode)
  ,("bytes-changed", AppendSourceBytes "\n-- changed source bytes\n")
  ,("foreign-behavior-disguised", ReplaceSourceBytes "print('foreign behavior')\n")
  ,("effect-unattributed", ReplaceSourceBytes "{-# LANGUAGE NoImplicitPrelude #-}\nmodule SnapshotControl where\nimport Missing.Effect (effect)\nvalue = effect ()\n")]

acquirePaths :: Options -> IO (Either String [FilePath])
acquirePaths options = case optionPathsFile options of
  Just file -> do
    content <- try (TextIO.readFile file) :: IO (Either IOException Text)
    pure (either (Left . show) (Right . map Text.unpack . Text.lines) content)
  Nothing -> do
    (exit, output, errors) <- readProcessWithExitCode "git" ["-C", optionRoot options, "ls-files", "-z", "--cached", "--others", "--exclude-standard"] ""
    case exit of
      ExitSuccess -> Right <$> filterM (doesFileExist . (optionRoot options </>)) (filter (not . null) (splitOnNul output))
      _ -> pure (Left ("layout-report: git inventory failed: " <> errors))

splitOnNul :: String -> [String]
splitOnNul value = case break (== '\0') value of
  (part, []) -> [part]
  (part, _ : rest) -> part : splitOnNul rest

missingPath :: FilePath -> FilePath -> IO (Maybe FilePath)
missingPath root path = do
  present <- doesFileExist (root </> path)
  pure (if present then Nothing else Just path)

checkBootstrap :: FilePath -> [FilePath] -> IO (Either BootstrapRefusal [Text])
checkBootstrap root paths = do
  files <- try (mapM (\path -> (path,) <$> ByteString.readFile (root </> path)) paths) :: IO (Either IOException [(FilePath,ByteString.ByteString)])
  pure (either (const (Left (BootstrapInventoryRefusal "source unreadable"))) bootstrapSourceRows files)

inspectIgnore :: FilePath -> FilePath -> IO [LayoutFinding]
inspectIgnore root path = do
  contents <- try (TextIO.readFile (root </> path)) :: IO (Either IOException Text)
  pure $ either (const [LayoutFinding "IgnoreFileMissing" path]) (checkIgnorePolicy path) contents

inspectShape :: FilePath -> FilePath -> IO [LayoutFinding]
inspectShape root path = do
  status <- try (getSymbolicLinkStatus (root </> path)) :: IO (Either IOException FileStatus)
  case status of
    Left _ -> pure [] -- The absent-path finding is emitted separately.
    Right observed -> do
      linked <- pathIsSymbolicLink (root </> path)
      let regular = not linked && isRegularFile observed
      bytes <- if regular
        then try (ByteString.readFile (root </> path)) :: IO (Either IOException ByteString.ByteString)
        else pure (Right ByteString.empty)
      pure
        ( [LayoutFinding "TrackedPathNotRegular" path | not regular]
            <> [LayoutFinding "TrackedPathExecutable" path | fileMode observed .&. 0o111 /= 0]
            <> [LayoutFinding "TrackedPathUnreadable" path | Left _ <- [bytes]]
            <> [LayoutFinding "TrackedShebang" path | Right content <- [bytes], ByteString.take 2 content == "#!"]
            <> [LayoutFinding "TrackedSourceNonUtf8" path | Right content <- [bytes], ".hs" `Text.isSuffixOf` Text.pack path,
                Left _ <- [TextEncoding.decodeUtf8' content]]
            <> [finding | Right content <- [bytes], Right source <- [TextEncoding.decodeUtf8' content],
                finding <- checkRuntimeText path source]
        )
