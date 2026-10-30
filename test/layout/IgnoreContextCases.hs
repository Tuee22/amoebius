{-# LANGUAGE OverloadedStrings #-}
-- Actual policy edits in a fresh copy; no expected verdicts or pass authority.
module IgnoreContextCases (runIgnoreContextCases) where

import Amoebius.Layout.Classify
import SourcePathCases (sourcePathInventory)
import Control.Exception (finally)
import Control.Monad (forM, forM_, when)
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
      attempted <- if negative then applyEdit tree (AppendIgnoreLines path suffix) else pure (Right (pure ()))
      observed <- case attempted of
        Left refusal -> pure (Left refusal)
        Right restore -> (do
          discovered <- sourcePathInventory tree
          (bytes,findings) <- observePolicies tree
          pure (Right (discovered,bytes,findings))) `finally` restore
      let row = (name,variant,role,observed)
      TextIO.writeFile (file "-current.data") (Text.pack (show row))
      pure row)
    controls <- forM ignoreContextControls $ \(name,edit) -> do
      attempted <- applyEdit tree edit
      observed <- case attempted of
        Left refusal -> pure (Left refusal)
        Right restore -> (Right <$> observePolicies tree) `finally` restore
      let row = (name,observed)
      TextIO.writeFile (file "-current-control.data") (Text.pack (show row))
      pure row
    pure (rows,controls)) `finally` removePathForcibly tree
  removed <- not <$> doesPathExist tree
  TextIO.writeFile (file ".data") (Text.pack (show rows))
  TextIO.writeFile (file "-controls.data") (Text.pack (show controls))
  TextIO.writeFile (file "-cleanup.data") (Text.pack (show removed))

applyEdit :: FilePath -> IgnoreContextEdit -> IO (Either Text (IO ()))
applyEdit tree edit = do
  let (path, change) = case edit of
        OmitIgnorePattern target patternText -> (target, Text.unlines . filter ((/= patternText) . Text.strip) . Text.lines)
        AppendIgnoreLines target suffix -> (target, (<> suffix))
  if path `notElem` [".gitignore", ".dockerignore"]
    then pure (Left ("IgnoreContextEditEscape:" <> Text.pack path))
    else do
      before <- TextIO.readFile (tree </> path)
      TextIO.writeFile (tree </> path) (change before)
      pure (Right (TextIO.writeFile (tree </> path) before))

observePolicies :: FilePath -> IO ([(FilePath, Text)], [Text])
observePolicies tree = do
  bytes <- forM [".gitignore", ".dockerignore"] (\path -> (path,) <$> TextIO.readFile (tree </> path))
  pure (bytes, [renderFinding finding | (path,body) <- bytes, finding <- checkIgnorePolicy path body])
