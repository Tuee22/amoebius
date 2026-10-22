{-# LANGUAGE OverloadedStrings #-}
-- Shared raw path-query apparatus; no expected findings or pass authority.
module SourcePathCases (runSourcePathCases, sourcePathInventory) where

import Amoebius.Layout.Classify (classifyPaths, renderFinding)
import Control.Exception (finally)
import Control.Monad (forM, forM_, unless, when)
import Data.List (intercalate, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (copyFile, createDirectory, createDirectoryIfMissing, doesDirectoryExist,
  doesFileExist, doesPathExist, getCurrentDirectory, listDirectory, makeAbsolute, pathIsSymbolicLink, removePathForcibly)
import System.FilePath (isAbsolute, splitDirectories, takeDirectory, (</>))
import System.FilePath.Windows qualified as Windows

-- Canonical slash-separated input paths match the shipped Git transport on every
-- native platform. Historical records have their own custody, outside source.
sourcePathInventory :: FilePath -> IO [FilePath]
sourcePathInventory root = sort <$> walk ""
 where
  walk relative = do
    entries <- sort <$> listDirectory (root </> relative)
    concat <$> forM entries (\name -> do
      let path = if null relative then name else relative <> "/" <> name
      directory <- doesDirectoryExist (root </> path)
      if null relative && (name == ".git" || directory && name `elem` [".build", ".data", ".test_data", "dist-newstyle", "validation-records"])
        then pure [] else do
          linked <- pathIsSymbolicLink (root </> path)
          unless (not linked) (fail "SourcePathInventorySymlink")
          if directory then walk path else do
            regular <- doesFileExist (root </> path)
            unless regular (fail "SourcePathInventoryNode")
            pure [path])

runSourcePathCases :: Text -> [(Text, Text, FilePath, Text)] -> FilePath -> IO ()
runSourcePathCases stem examples output = do
  directory <- makeAbsolute output
  createDirectoryIfMissing True directory
  root <- getCurrentDirectory
  paths <- sourcePathInventory root
  let file suffix = directory </> Text.unpack (stem <> suffix)
      tree = file "-tree"
  present <- doesPathExist tree
  when present (fail "SourcePathFixtureRootNotFresh")
  createDirectory tree
  rows <- (do
    forM_ paths $ \path -> do
      createDirectoryIfMissing True (takeDirectory (tree </> path))
      copyFile (root </> path) (tree </> path)
    baseline <- sourcePathInventory tree
    TextIO.writeFile (file "-baseline.data") (Text.pack (show baseline))
    concat <$> forM examples (\(name, variant, path, bytes) -> forM [False, True] $ \negative -> do
      unless (not (null path) && not (isAbsolute path) && not (Windows.hasDrive path)
        && '\\' `notElem` path && '\0' `notElem` path
        && all (`notElem` [".", ".."]) (splitDirectories path)
        && path == intercalate "/" (splitDirectories path)) (fail "SourcePathCaseEscape")
      when (path `elem` baseline) (fail "SourcePathControlCollidesWithAuthoredInput")
      when negative $ do
        createDirectoryIfMissing True (takeDirectory (tree </> path))
        TextIO.writeFile (tree </> path) bytes
      discovered <- sourcePathInventory tree
      observedBytes <- if negative then TextIO.readFile (tree </> path) else pure ""
      let role = if negative then "negative" else "positive" :: Text
          findings = map renderFinding (snd (classifyPaths discovered))
          row = (name, variant, role, discovered, findings, observedBytes)
      TextIO.writeFile (file "-current.data") (Text.pack (show row))
      when negative (removePathForcibly (tree </> path))
      pure row)) `finally` removePathForcibly tree
  let controls = [("empty" :: Text, map renderFinding (snd (classifyPaths []))),
        ("duplicate", map renderFinding (snd (classifyPaths (paths <> ["amoebius.cabal"]))))]
  removed <- not <$> doesPathExist tree
  TextIO.writeFile (file ".data") (Text.pack (show rows))
  TextIO.writeFile (file "-controls.data") (Text.pack (show controls))
  TextIO.writeFile (file "-cleanup.data") (Text.pack (show removed))
