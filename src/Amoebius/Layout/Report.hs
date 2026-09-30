{-# LANGUAGE OverloadedStrings #-}

-- | Shipped path-classification report. The default inventory is acquired
-- directly from Git. A caller may provide a run-local path inventory when
-- challenging a copied tree; every path in either inventory is classified.
module Amoebius.Layout.Report (runLayoutReport) where

import Amoebius.Layout.Classify
import Amoebius.Layout.PackageMap (emptyPackageCatalog, loadPackageCatalog, packageMapReport)
import Amoebius.Layout.PbGrammar
import Amoebius.Layout.SourceGraph (sourceGraphWithPackageCatalog)
import Control.Exception (IOException, try)
import Control.Monad (filterM)
import Data.Bits ((.&.))
import Data.ByteString qualified as ByteString
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Text.IO qualified as TextIO
import System.Directory (createDirectoryIfMissing, doesFileExist)
import System.Exit (ExitCode (..), exitWith)
import System.FilePath (takeDirectory, (</>))
import System.IO (hPutStrLn, stderr)
import System.Process (readProcessWithExitCode)
import System.Posix.Files (FileStatus, fileMode, getSymbolicLinkStatus, isRegularFile)

data Options = Options
  { optionRoot :: FilePath
  , optionPathsFile :: Maybe FilePath
  , optionOutput :: Maybe FilePath
  }

runLayoutReport :: [String] -> IO ()
runLayoutReport arguments = case parseOptions (Options "." Nothing Nothing) arguments of
  Left problem -> hPutStrLn stderr problem >> exitWith (ExitFailure 2)
  Right options -> do
    acquired <- acquirePaths options
    case acquired of
      Left problem -> hPutStrLn stderr problem >> exitWith (ExitFailure 2)
      Right paths -> do
        let (classified, pathFindings) = classifyPaths paths
        absent <- mapM (missingPath (optionRoot options)) paths
        shapeFindings <- concat <$> mapM (inspectShape (optionRoot options)) paths
        bootstrap <- checkBootstrap (optionRoot options)
        packageBytes <- try (ByteString.readFile (optionRoot options </> "amoebius.cabal")) :: IO (Either IOException ByteString.ByteString)
        probeBytes <- try (ByteString.readFile (optionRoot options </> "probe/probe.cabal")) :: IO (Either IOException ByteString.ByteString)
        ignoreFindings <- concat <$> mapM (inspectIgnore (optionRoot options)) [".gitignore", ".dockerignore"]
        let (packageFindings, packageRows, componentMap, dependencyMap, packageMap, forwardOwned) = case (packageBytes, probeBytes) of
              (Left _, _) -> ([LayoutFinding "PackageDescriptionUnreadable" "amoebius.cabal"], [], mempty, mempty, mempty, mempty)
              (_, Left _) -> ([LayoutFinding "PackageDescriptionUnreadable" "probe/probe.cabal"], [], mempty, mempty, mempty, mempty)
              (Right mainPackage, Right probePackage) -> packageMapReport mainPackage probePackage paths
        catalogResult <- if null packageFindings then loadPackageCatalog packageMap
          else pure (Right (emptyPackageCatalog, []))
        let (catalogFindings, catalogRows, catalog) = case catalogResult of
              Left problem -> ([problem], [], emptyPackageCatalog)
              Right (loaded, rows) -> ([], rows, loaded)
        (graphFindings, graphRows) <- sourceGraphWithPackageCatalog
          (optionRoot options) paths componentMap dependencyMap catalog forwardOwned
        let rows =
              [Text.intercalate "\t" ["path", Text.pack path, renderPathClass pathClass] | (path, pathClass) <- classified]
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
        if null pathFindings && null shapeFindings && null ignoreFindings && null packageFindings && null catalogFindings && null graphFindings && all (== Nothing) absent && either (const False) (const True) bootstrap
          then pure ()
          else exitWith (ExitFailure 1)

parseOptions :: Options -> [String] -> Either String Options
parseOptions options arguments = case arguments of
  [] -> Right options
  "--root" : value : rest -> parseOptions options {optionRoot = value} rest
  "--paths-file" : value : rest -> parseOptions options {optionPathsFile = Just value} rest
  "--output" : value : rest -> parseOptions options {optionOutput = Just value} rest
  _ -> Left "layout-report: expected [--root DIR] [--paths-file FILE] [--output FILE]"

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

checkBootstrap :: FilePath -> IO (Either BootstrapRefusal [Text])
checkBootstrap root = do
  bytes <- try (ByteString.readFile (root </> "pb/__main__.py")) :: IO (Either IOException ByteString.ByteString)
  pure (either (const (Left BootstrapMissing)) bootstrapGraphRows bytes)

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
      bytes <- if isRegularFile observed
        then try (ByteString.readFile (root </> path)) :: IO (Either IOException ByteString.ByteString)
        else pure (Right ByteString.empty)
      pure
        ( [LayoutFinding "TrackedPathNotRegular" path | not (isRegularFile observed)]
            <> [LayoutFinding "TrackedPathExecutable" path | fileMode observed .&. 0o111 /= 0]
            <> [LayoutFinding "TrackedPathUnreadable" path | Left _ <- [bytes]]
            <> [LayoutFinding "TrackedShebang" path | Right content <- [bytes], ByteString.take 2 content == "#!"]
            <> [LayoutFinding "TrackedSourceNonUtf8" path | Right content <- [bytes], ".hs" `Text.isSuffixOf` Text.pack path,
                Left _ <- [TextEncoding.decodeUtf8' content]]
            <> [finding | Right content <- [bytes], Right source <- [TextEncoding.decodeUtf8' content],
                finding <- checkRuntimeText path source]
        )
