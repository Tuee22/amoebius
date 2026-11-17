{-# LANGUAGE OverloadedStrings #-}
-- Raw observations of the shipped snapshot comparator and source graph.
module SourceGraphCases (runSourceGraphCases, observeSnapshot) where

import Amoebius.Layout.Classify (renderFinding)
import Amoebius.Layout.Report
import Amoebius.Layout.PackageMap (packageMapReport, loadPackageCatalog)
import Amoebius.Layout.SourceGraph (sourceGraph, sourceGraphWithPackageCatalog)
import SourcePathCases (sourcePathInventory)
import Control.Exception (SomeAsyncException, SomeException, displayException, evaluate,
  finally, fromException, throwIO, try)
import Control.Monad (forM, forM_, unless, when)
import Data.Bits (xor)
import Data.ByteString qualified as Bytes
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (copyFile, createDirectory, createDirectoryIfMissing, doesPathExist,
  getCurrentDirectory, makeAbsolute, removePathForcibly)
import System.FilePath (takeDirectory, (</>))

runSourceGraphCases :: FilePath -> IO ()
runSourceGraphCases output = do
  directory <- makeAbsolute output
  createDirectoryIfMissing True directory
  root <- getCurrentDirectory
  paths <- sourcePathInventory root
  original <- observeSnapshot root
  let file suffix = directory </> ("source-graph" <> suffix)
      tree = file "-tree"
      target = tree </> sourceGraphExamplePath
  present <- doesPathExist tree
  when present (fail "SourceGraphTreeNotFresh")
  createDirectory tree
  rows <- (do
    forM_ paths $ \path -> do
      createDirectoryIfMissing True (takeDirectory (tree </> path))
      copyFile (root </> path) (tree </> path)
    baseline <- observeSnapshot tree
    TextIO.writeFile (file "-baseline.data") (Text.pack (show (original,baseline)))
    mainPackage <- Bytes.readFile (tree </> "amoebius.cabal")
    probePackage <- Bytes.readFile (tree </> "probe/probe.cabal")
    let (packageFindings,_,components,dependencies,packages,forward) = packageMapReport mainPackage probePackage paths
    -- Compiler-rejected negative calls need the native build's package inputs.
    -- Both source inventories above still bind the copied bytes to this root.
    let relevant row = any (`Text.isPrefixOf` row) ["graph-stage\t","graph-file\t","graph-import-unresolved\t","graph-import-standalone-unresolved\t","graph-call-site-opaque\t","graph-unscanned\t","graph-unscanned-declaration\t"]
    whole <- observeWhole "catalogue-exception" $ do
      acquired <- loadPackageCatalog packages
      case acquired of
        Left finding -> pure (Left ("catalogue-refused",renderFinding finding))
        Right (catalog,_) -> observeWhole "query-exception" $ do
          (findings,graphRows) <- sourceGraphWithPackageCatalog root paths components dependencies catalog forward
          pure (Right (map renderFinding (packageFindings <> findings),filter relevant graphRows))
    TextIO.writeFile (file "-whole.data") (Text.pack (show whole))
    unless (sourceGraphExamplePath `notElem` paths) (fail "SourceGraphControlCollision")
    let restore = copyFile (root </> "test/layout/SourceGraphCases.hs") target >> TextIO.writeFile target sourceGraphExampleSource
    restore
    reference <- observeSnapshot tree
    concat <$> forM sourceGraphExamples (\(name,edit) -> forM [False,True] $ \negative -> (do
      restore
      when negative $ case edit of
        OmitSourcePath -> removePathForcibly target
        ChangeSourceMode -> pure () -- The reference-mode boundary is challenged below.
        AppendSourceBytes suffix -> TextIO.appendFile target suffix
        ReplaceSourceBytes bytes -> TextIO.writeFile target bytes
      observed <- observeSnapshot tree
      let expected = case edit of
            ReplaceSourceBytes _ | negative -> observed
            ChangeSourceMode | negative -> [(path,kind,if path == sourceGraphExamplePath then mode `xor` 0o100 else mode,digest) | (path,kind,mode,digest) <- reference]
            _ -> reference
      (graphFindings,rows) <- case edit of
        ReplaceSourceBytes _ -> sourceGraph tree [sourceGraphExamplePath]
          (Map.singleton sourceGraphExamplePath ["test:source-graph"]) Map.empty
        _ -> pure ([],[])
      let role = if negative then "negative" else "positive" :: Text
          row = (name,role,expected,observed,map renderFinding (compareLayoutSnapshots expected observed),map renderFinding graphFindings,rows)
      TextIO.writeFile (file "-current.data") (Text.pack (show row))
      pure row) `finally` restore)) `finally` removePathForcibly tree
  let (locus,kind,mode,digest) = case original of entry : _ -> entry; [] -> ("source","regular",0,"")
      controls = [("empty-reference" :: Text,map renderFinding (compareLayoutSnapshots [] original))
        ,("empty-observation",map renderFinding (compareLayoutSnapshots original []))
        ,("duplicate",map renderFinding (compareLayoutSnapshots original (original <> take 1 original)))
        ,("kind",map renderFinding (compareLayoutSnapshots [(locus,kind,mode,digest)] [(locus,"symlink",mode,digest)]))]
  removed <- not <$> doesPathExist tree
  TextIO.writeFile (file ".data") (Text.pack (show rows))
  TextIO.writeFile (file "-controls.data") (Text.pack (show controls))
  TextIO.writeFile (file "-cleanup.data") (Text.pack (show removed))

-- Keep a failed product snapshot visible while allowing the independent oracle
-- to judge the remaining fixed inventory. The marker cannot be a source entry.
observeSnapshot :: FilePath -> IO SourceSnapshot
observeSnapshot root = do
  attempted <- try (do
    snapshot <- captureLayoutSnapshot root
    _ <- evaluate (length (show snapshot))
    pure snapshot) :: IO (Either SomeException SourceSnapshot)
  case attempted of
    Right snapshot -> pure snapshot
    Left problem -> case fromException problem :: Maybe SomeAsyncException of
      Just _ -> throwIO problem
      Nothing -> pure [("<snapshot-exception>", "exception", 0, Text.pack (displayException problem))]

-- A subject refusal must remain an observation, so the remaining independent
-- contracts can still be judged. Force its complete payload within the same
-- boundary; asynchronous interruption is never a completed observation.
observeWhole :: Text -> IO (Either (Text,Text) ([Text],[Text]))
  -> IO (Either (Text,Text) ([Text],[Text]))
observeWhole stage action = do
  attempted <- try (do
    observed <- action
    _ <- evaluate (Text.length (Text.pack (show observed)))
    pure observed) :: IO (Either SomeException (Either (Text,Text) ([Text],[Text])))
  case attempted of
    Right observed -> pure observed
    Left problem -> case fromException problem :: Maybe SomeAsyncException of
      Just _ -> throwIO problem
      Nothing -> pure (Left (stage,Text.pack (displayException problem)))
