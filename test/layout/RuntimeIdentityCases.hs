{-# LANGUAGE OverloadedStrings #-}
-- Observations from the shipped path/text and parsed-Cabal identity checks.
module RuntimeIdentityCases (runRuntimeIdentityCases) where

import Amoebius.Layout.Classify
import Amoebius.Layout.PackageMap (runtimeComponentFindings)
import SourcePathCases (sourcePathInventory)
import Control.Exception (finally)
import Control.Monad (forM, forM_, unless, when)
import Data.ByteString qualified as Bytes
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (copyFile, createDirectory, createDirectoryIfMissing, doesPathExist,
  getCurrentDirectory, makeAbsolute, removePathForcibly)
import System.FilePath (isAbsolute, splitDirectories, takeDirectory, takeExtension, (</>))
import System.FilePath.Windows qualified as Windows

runRuntimeIdentityCases :: FilePath -> IO ()
runRuntimeIdentityCases output = do
  directory <- makeAbsolute output
  createDirectoryIfMissing True directory
  root <- getCurrentDirectory
  paths <- sourcePathInventory root
  let file suffix = directory </> ("runtime-identity" <> suffix)
      tree = file "-tree"
  present <- doesPathExist tree
  when present (fail "RuntimeIdentityTreeNotFresh")
  createDirectory tree
  (rows, controls) <- (do
    forM_ paths $ \path -> do
      createDirectoryIfMissing True (takeDirectory (tree </> path))
      copyFile (root </> path) (tree </> path)
    baseline <- sourcePathInventory tree
    TextIO.writeFile (file "-baseline.data") (Text.pack (show baseline))
    rows <- concat <$> forM runtimeIdentityExamples (\(name, variant, input) ->
      forM [False, True] $ \negative -> do
        let role = if negative then "negative" else "positive" :: Text
        restore <- if negative then applyInput tree baseline input else pure (pure ())
        observed <- (do
          discovered <- sourcePathInventory tree
          findings <- observeIdentity tree discovered
          bytes <- if negative then TextIO.readFile (tree </> inputPath input) else pure ""
          let row = (name, variant, role, discovered, findings, bytes)
          TextIO.writeFile (file "-current.data") (Text.pack (show row))
          pure row) `finally` restore
        pure observed)
    controls <- forM runtimeIdentityControls $ \(name, input) -> do
      restore <- applyInput tree baseline input
      (do
        discovered <- sourcePathInventory tree
        findings <- observeIdentity tree discovered
        TextIO.writeFile (file "-current-control.data") (Text.pack (show (name, findings)))
        pure (name, findings)) `finally` restore
    pure (rows, controls)) `finally` removePathForcibly tree
  removed <- not <$> doesPathExist tree
  TextIO.writeFile (file ".data") (Text.pack (show rows))
  TextIO.writeFile (file "-controls.data") (Text.pack (show controls))
  TextIO.writeFile (file "-cleanup.data") (Text.pack (show removed))

inputPath :: RuntimeIdentityInput -> FilePath
inputPath input = case input of RuntimeIdentitySource path _ -> path; RuntimeIdentityPackage path _ -> path

applyInput :: FilePath -> [FilePath] -> RuntimeIdentityInput -> IO (IO ())
applyInput tree baseline input = do
  let path = inputPath input
      bytes = case input of RuntimeIdentitySource _ value -> value; RuntimeIdentityPackage _ value -> value
  unless (not (null path) && not (isAbsolute path) && not (Windows.hasDrive path)
    && '\\' `notElem` path && '\0' `notElem` path
    && all (`notElem` [".", ".."]) (splitDirectories path)) (fail "RuntimeIdentityInputEscape")
  restore <- case input of
    RuntimeIdentitySource {} -> do
      when (path `elem` baseline) (fail "RuntimeIdentitySourceCollision")
      pure (removePathForcibly (tree </> path))
    RuntimeIdentityPackage {} -> do
      unless (path `elem` baseline) (fail "RuntimeIdentityPackageMissing")
      before <- Bytes.readFile (tree </> path)
      pure (Bytes.writeFile (tree </> path) before)
  createDirectoryIfMissing True (takeDirectory (tree </> path))
  TextIO.writeFile (tree </> path) bytes
  pure restore

observeIdentity :: FilePath -> [FilePath] -> IO [Text]
observeIdentity tree paths = do
  source <- concat <$> forM [path | path <- paths, takeExtension path == ".hs"] (\path -> do
    body <- TextIO.readFile (tree </> path)
    pure ([finding | Left finding <- [classifyPath path], findingCode finding == "OrdinalRuntimeIdentity"] <> checkRuntimeText path body))
  packages <- concat <$> forM [path | path <- paths, path `elem` ["amoebius.cabal", "probe/probe.cabal"]]
    (\path -> runtimeComponentFindings path <$> Bytes.readFile (tree </> path))
  pure (map renderFinding (source <> packages))
