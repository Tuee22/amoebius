{-# LANGUAGE OverloadedStrings #-}
-- Whole-source static bootstrap observations; Python is never executed.
module BootstrapSourceCases (runBootstrapSourceCases) where

import Amoebius.Layout.PbGrammar
import Amoebius.Layout.Report (captureLayoutSnapshot)
import SourcePathCases (sourcePathInventory)
import Control.Exception (finally)
import Control.Monad (forM, forM_, unless, when)
import Data.ByteString qualified as Bytes
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import Data.Text.IO qualified as TextIO
import System.Directory (copyFile, createDirectory, createDirectoryIfMissing, doesPathExist,
  getCurrentDirectory, makeAbsolute, removePathForcibly)
import System.FilePath (takeDirectory, (</>))

runBootstrapSourceCases :: FilePath -> IO ()
runBootstrapSourceCases output = do
  directory <- makeAbsolute output
  createDirectoryIfMissing True directory
  root <- getCurrentDirectory
  paths <- sourcePathInventory root
  original <- captureLayoutSnapshot root
  originalBytes <- Bytes.readFile (root </> target)
  originalText <- either (fail . show) pure (Encoding.decodeUtf8' originalBytes)
  unless (Text.count argv originalText == 1) (fail "BootstrapSourceArgvLocus")
  let file suffix = directory </> ("bootstrap-source" <> suffix)
      tree = file "-tree"
      restore = copyFile (root </> target) (tree </> target)
      readInputs = sourcePathInventory tree >>= mapM (\path -> (path,) <$> Bytes.readFile (tree </> path))
      verdict = either (Left . renderBootstrapRefusal) Right . bootstrapSourceRows
  present <- doesPathExist tree
  when present (fail "BootstrapSourceTreeNotFresh")
  unless (target `elem` paths && extra `notElem` paths) (fail "BootstrapSourceControlCollision")
  createDirectory tree
  (rows,controls) <- (do
    forM_ paths $ \path -> do
      createDirectoryIfMissing True (takeDirectory (tree </> path))
      copyFile (root </> path) (tree </> path)
    baseline <- captureLayoutSnapshot tree
    TextIO.writeFile (file "-baseline.data") (Text.pack (show (original,baseline)))
    rows <- concat <$> forM bootstrapSourceExamples (\(name,edit) -> forM [False,True] $ \negative -> (do
      restore
      when negative $ Bytes.writeFile (tree </> target) (Encoding.encodeUtf8 (case edit of
        AppendBootstrapBytes suffix -> originalText <> suffix
        RewriteBootstrapArguments -> Text.replace argv "    bootstrap(adapter, [])" originalText))
      inputs <- readInputs
      snapshot <- captureLayoutSnapshot tree
      body <- Bytes.readFile (tree </> target) >>= either (fail . show) pure . Encoding.decodeUtf8'
      let role = if negative then "negative" else "positive" :: Text
          row = (name,role,snapshot,body,verdict inputs)
      TextIO.writeFile (file "-current.data") (Text.pack (show row))
      pure row) `finally` restore)
    let observe name inputs body = do
          snapshot <- captureLayoutSnapshot tree
          pure (name :: Text,snapshot,map fst inputs,body :: Text,verdict inputs)
    missing <- (do
      removePathForcibly (tree </> target)
      inputs <- readInputs
      observe "missing" inputs "") `finally` restore
    added <- (do
      copyFile (root </> "test/layout/BootstrapSourceCases.hs") (tree </> extra)
      Bytes.writeFile (tree </> extra) (Encoding.encodeUtf8 "module Extra where\n")
      inputs <- readInputs
      observe "extra" inputs originalText) `finally` removePathForcibly (tree </> extra)
    inputs <- readInputs
    duplicate <- observe "duplicate" (inputs <> take 1 inputs) originalText
    empty <- observe "empty" [] originalText
    pure (rows,[missing,added,duplicate,empty])) `finally` removePathForcibly tree
  removed <- not <$> doesPathExist tree
  TextIO.writeFile (file ".data") (Text.pack (show rows))
  TextIO.writeFile (file "-controls.data") (Text.pack (show controls))
  TextIO.writeFile (file "-cleanup.data") (Text.pack (show removed))
 where
  target = "pb/__main__.py"
  extra = "pb/extra.hs"
  argv = "    bootstrap(adapter, sys.argv[1:])"
