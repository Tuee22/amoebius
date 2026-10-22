{-# LANGUAGE OverloadedStrings #-}
-- Raw observations of the shipped test-source classifier over acquired trees.
module TestSourceCases (runTestSourceCases) where

import Amoebius.Layout.Classify
import SourcePathCases (sourcePathInventory)
import Control.Exception (finally)
import Control.Monad (forM, forM_, when)
import Data.List (sort)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (copyFile, createDirectory, createDirectoryIfMissing, doesPathExist,
  getCurrentDirectory, makeAbsolute, removePathForcibly)
import System.FilePath (takeDirectory, (</>))

runTestSourceCases :: FilePath -> IO ()
runTestSourceCases output = do
  directory <- makeAbsolute output
  createDirectoryIfMissing True directory
  root <- getCurrentDirectory
  paths <- sort . testSourcePaths <$> sourcePathInventory root
  let tree = directory </> "test-source-tree"
  present <- doesPathExist tree
  when present (fail "TestSourceFixtureRootNotFresh")
  createDirectory tree
  rows <- (do
    forM_ paths $ \path -> do
      createDirectoryIfMissing True (takeDirectory (tree </> path))
      copyFile (root </> path) (tree </> path)
    baseline <- sourcePathInventory tree
    TextIO.writeFile (directory </> "test-source-baseline.data") (Text.pack (show baseline))
    concat <$> forM testSourceExamples (\(name, variant, foreignPath, foreignBytes) ->
      forM [False, True] $ \negative -> do
        let role = if negative then "negative" else "positive" :: Text.Text
            (path, bytes) = if negative then (foreignPath, foreignBytes) else
              ("test/source-control/Input.hs", "module Input where\ninput :: Bool\ninput = True\n")
        createDirectoryIfMissing True (takeDirectory (tree </> path))
        when (path `elem` baseline) (fail "TestSourceControlCollidesWithAuthoredInput")
        TextIO.writeFile (tree </> path) bytes
        discovered <- sourcePathInventory tree
        observedBytes <- TextIO.readFile (tree </> path)
        let classes = [(candidate, renderPathClass value) | candidate <- discovered, Right value <- [classifyPath candidate]]
            findings = map renderFinding (testSourceFindings discovered)
            row = (name, variant, role, discovered, classes, findings, observedBytes)
        TextIO.writeFile (directory </> "test-source-current.data") (Text.pack (show row))
        removePathForcibly (tree </> path)
        pure row)) `finally` removePathForcibly tree
  let controls = [("empty" :: Text.Text, map renderFinding (testSourceFindings [])),
        ("duplicate", map renderFinding (testSourceFindings (paths <> ["test/layout/Main.hs"])))]
  removed <- not <$> doesPathExist tree
  TextIO.writeFile (directory </> "test-source.data") (Text.pack (show rows))
  TextIO.writeFile (directory </> "test-source-controls.data") (Text.pack (show controls))
  TextIO.writeFile (directory </> "test-source-cleanup.data") (Text.pack (show removed))
