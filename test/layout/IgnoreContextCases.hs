{-# LANGUAGE OverloadedStrings #-}
-- Actual policy edits in a fresh copy; no expected verdicts or pass authority.
module IgnoreContextCases (runIgnoreContextCases) where

import Amoebius.Layout.Classify
import SourcePathCases (sourcePathInventory)
import Control.Exception (finally)
import Control.Monad (forM, forM_, unless, when)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (copyFile, createDirectory, createDirectoryIfMissing, doesPathExist,
  getCurrentDirectory, makeAbsolute, removePathForcibly)
import System.FilePath (takeDirectory, (</>))

runIgnoreContextCases :: FilePath -> IO ()
runIgnoreContextCases output = do
  directory <- makeAbsolute output
  createDirectoryIfMissing True directory
  root <- getCurrentDirectory
  paths <- sourcePathInventory root
  let file suffix = directory </> ("ignore-context" <> suffix)
      tree = file "-tree"
  present <- doesPathExist tree
  when present (fail "IgnoreContextTreeNotFresh")
  createDirectory tree
  (rows, controls) <- (do
    forM_ paths $ \path -> do
      createDirectoryIfMissing True (takeDirectory (tree </> path))
      copyFile (root </> path) (tree </> path)
    baseline <- sourcePathInventory tree
    TextIO.writeFile (file "-baseline.data") (Text.pack (show baseline))
    rows <- concat <$> forM ignoreContextExamples (\(name,variant,path,suffix) -> forM [False,True] $ \negative -> do
      let role = if negative then "negative" else "positive" :: Text
      restore <- if negative then applyEdit tree (AppendIgnoreLines path suffix) else pure (pure ())
      (do
        discovered <- sourcePathInventory tree
        (bytes,findings) <- observePolicies tree
        let row = (name,variant,role,discovered,bytes,findings)
        TextIO.writeFile (file "-current.data") (Text.pack (show row))
        pure row) `finally` restore)
    controls <- forM ignoreContextControls $ \(name,edit) -> do
      restore <- applyEdit tree edit
      (do
        (bytes,findings) <- observePolicies tree
        TextIO.writeFile (file "-current-control.data") (Text.pack (show (name,bytes,findings)))
        pure (name,bytes,findings)) `finally` restore
    pure (rows,controls)) `finally` removePathForcibly tree
  removed <- not <$> doesPathExist tree
  TextIO.writeFile (file ".data") (Text.pack (show rows))
  TextIO.writeFile (file "-controls.data") (Text.pack (show controls))
  TextIO.writeFile (file "-cleanup.data") (Text.pack (show removed))

applyEdit :: FilePath -> IgnoreContextEdit -> IO (IO ())
applyEdit tree edit = do
  let (path, change) = case edit of
        OmitIgnorePattern target patternText -> (target, Text.unlines . filter ((/= patternText) . Text.strip) . Text.lines)
        AppendIgnoreLines target suffix -> (target, (<> suffix))
  unless (path `elem` [".gitignore", ".dockerignore"]) (fail "IgnoreContextEditEscape")
  before <- TextIO.readFile (tree </> path)
  TextIO.writeFile (tree </> path) (change before)
  pure (TextIO.writeFile (tree </> path) before)

observePolicies :: FilePath -> IO ([(FilePath, Text)], [Text])
observePolicies tree = do
  bytes <- forM [".gitignore", ".dockerignore"] (\path -> (path,) <$> TextIO.readFile (tree </> path))
  pure (bytes, [renderFinding finding | (path,body) <- bytes, finding <- checkIgnorePolicy path body])
