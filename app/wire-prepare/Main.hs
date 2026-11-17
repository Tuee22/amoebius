{-# LANGUAGE OverloadedStrings #-}

-- | Build-time entry point for the source-owned Pulsar declarations.  This
-- executable depends on the declarations, not on the client whose generated
-- bindings it prepares, so a clean build can run it before building the client.
module Main (main) where

import Amoebius.Pulsar.Wire.Generate (WireGeneration (..), WireGenerationError, beginWireBindings, finishWireBindings, generateWireBindings, generateWireBindingsFromPlugin)
import Amoebius.Build.Serial (BuildObservation (..), spawnCabalIn, spawnToolInstall)
import Amoebius.Toolchain.Acquire (ChildRecord (childExit))
import Amoebius.Toolchain.Provenance (UpstreamIdentity (upstreamVersion), forkUpstream)
import Control.Monad (unless)
import Data.Char (isAlphaNum, isAscii, isDigit)
import Data.List (dropWhileEnd)
import Data.Text qualified as Text
import Data.Version (parseVersion, versionBranch)
import Owner (preparationOwner)
import Plan (plannedPlugin)
import System.Directory (canonicalizePath, createDirectory, createDirectoryIfMissing, doesFileExist, doesPathExist, makeAbsolute)
import System.Environment (getArgs)
import System.Exit (die)
import System.Exit (ExitCode (..))
import System.FilePath (isAbsolute, makeRelative, splitDirectories, takeDirectory, (</>))
import System.Process (proc, readCreateProcessWithExitCode)
import Text.ParserCombinators.ReadP (readP_to_S)

main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    ["build", protoc, plugin, cabal, compiler]
      | all isAbsolute [protoc, plugin, cabal, compiler] -> do
          _ <- prepare "current" protoc plugin
          buildProduct cabal compiler
    ["build-plugin", plugin, cabal, compiler]
      | all isAbsolute [plugin, cabal, compiler] -> do
          _ <- preparePlugin "current" plugin
          buildProduct cabal compiler
    ["build-auto", cabal, compiler]
      | all isAbsolute [cabal, compiler] -> do
          alreadyGenerated <- doesPathExist ".build/proto/current"
          unless (not alreadyGenerated) (die "generated binding directory already exists")
          plugin <- buildPlugin cabal compiler
          _ <- preparePlugin "current" plugin
          buildProduct cabal compiler
    ["generate-plugin", runName, plugin]
      | not (null runName), all validRunName runName, isAbsolute plugin -> preparePlugin runName plugin >>= mapM_ putStrLn
    ["generate-planned", runName]
      | not (null runName), all validRunName runName -> plannedPlugin >>= preparePlugin runName >>= mapM_ putStrLn
    ["begin-plugin", runName]
      | not (null runName), all validRunName runName -> do
          owner <- preparationOwner "."
          prepared <- beginWireBindings (owner </> runName) >>= either (die . show) pure
          mapM_ putStrLn [fst prepared, snd prepared]
    ["finish-plugin", runName]
      | not (null runName), all validRunName runName -> do
          owner <- preparationOwner "."
          finishWireBindings (owner </> runName) >>= finishPreparation >>= mapM_ putStrLn
    [runName, protoc, plugin]
      | not (null runName)
      , all validRunName runName
      , isAbsolute protoc
      , isAbsolute plugin -> prepare runName protoc plugin >>= mapM_ putStrLn
    _ -> die "usage: amoebius-wire-prepare RUN-NAME ABSOLUTE-PROTOC ABSOLUTE-PLUGIN | generate-plugin RUN-NAME ABSOLUTE-PLUGIN | generate-planned RUN-NAME | begin-plugin RUN-NAME | finish-plugin RUN-NAME | build ABSOLUTE-PROTOC ABSOLUTE-PLUGIN ABSOLUTE-CABAL ABSOLUTE-GHC | build-plugin ABSOLUTE-PLUGIN ABSOLUTE-CABAL ABSOLUTE-GHC | build-auto ABSOLUTE-CABAL ABSOLUTE-GHC"
 where
  validRunName character = isAscii character && (isAlphaNum character || character `elem` ("-_" :: String))

prepare :: FilePath -> FilePath -> FilePath -> IO [FilePath]
prepare runName protoc plugin = do
  owner <- preparationOwner "."
  generateWireBindings protoc plugin (owner </> runName) >>= finishPreparation

preparePlugin :: FilePath -> FilePath -> IO [FilePath]
preparePlugin runName plugin = do
  owner <- preparationOwner "."
  generateWireBindingsFromPlugin plugin (owner </> runName) >>= finishPreparation

finishPreparation :: Either WireGenerationError WireGeneration -> IO [FilePath]
finishPreparation generated = do
  version <- case [parsed | (parsed, "") <- readP_to_S parseVersion (Text.unpack (upstreamVersion forkUpstream))] of
    [parsed] -> pure parsed
    _ -> die "invalid maintained fork version"
  result <- either (die . show) pure generated
  let identity = takeDirectory (wireSchemaPath result) </> "generated" </> "Paths_supernova.hs"
  writeFile identity ("module Paths_supernova (version) where\nimport Data.Version (Version, makeVersion)\nversion :: Version\nversion = makeVersion " <> show (versionBranch version) <> "\n")
  pure (wireSchemaPath result : wireGeneratedFiles result <> [identity])

buildProduct :: FilePath -> FilePath -> IO ()
buildProduct cabal compiler = do
  let buildDirectory = ".build/dist-native"
      target = "exe:amoebius"
  (built, _, buildError) <- spawnCabalIn "." ".build/wire-build-transport" cabal compiler ["build", target, "--builddir=" <> buildDirectory]
  unless (childExit (buildEffectiveChild built) == 0) (die ("product build failed: " <> buildError))
  (located, output, locateError) <- spawnCabalIn "." ".build/wire-build-transport" cabal compiler ["list-bin", "-v0", target, "--builddir=" <> buildDirectory]
  unless (childExit (buildEffectiveChild located) == 0) (die ("product location failed: " <> locateError))
  let candidate = dropWhileEnd (`elem` ['\n', '\r']) output
  unless (isAbsolute candidate && '\n' `notElem` candidate && '\r' `notElem` candidate) (die "invalid product executable path")
  root <- canonicalizePath "."
  owner <- canonicalizePath buildDirectory
  image <- canonicalizePath candidate
  present <- doesFileExist image
  let relative = makeRelative owner image
  unless (makeRelative root owner == buildDirectory && present && not (isAbsolute relative) && ".." `notElem` splitDirectories relative)
    (die "product executable is outside its build directory")
  putStrLn image

-- Build the Haskell plugin from Cabal's compatible source graph. This does not
-- search PATH or require a previously installed plugin executable.
buildPlugin :: FilePath -> FilePath -> IO FilePath
buildPlugin cabal compiler = do
  (exit, output, err) <- readCreateProcessWithExitCode (proc compiler ["--numeric-version"]) ""
  let version = Text.strip (Text.pack output)
      parts = Text.splitOn "." version
  unless (exit == ExitSuccess && not (null parts) && all (\part -> not (Text.null part) && Text.all isDigit part) parts)
    (die ("compiler version unavailable: " <> err))
  createDirectoryIfMissing True ".build"
  root <- canonicalizePath "."
  buildRoot <- canonicalizePath ".build"
  unless (makeRelative root buildRoot == ".build") (die "build directory escapes source tree")
  owner <- makeAbsolute ".build/proto-tools"
  createDirectory owner
  let package = "proto-lens-protoc"
      arguments = ["install", "--ignore-project", "proto-lens-protoc:proto-lens-protoc"
        , "--constraint=proto-lens-protoc source", "--constraint=proto-lens-protoc >=0.9 && <0.10"]
  installed <- spawnToolInstall owner cabal compiler version package package arguments
  case installed of
    Left problem -> die ("plugin build failed: " <> Text.unpack problem)
    Right (observation, _, detail) -> do
      unless (childExit (buildEffectiveChild observation) == 0) (die ("plugin build failed: " <> detail))
      let plugin = owner </> "proto-lens-protoc"
      physical <- canonicalizePath plugin
      present <- doesFileExist physical
      unless (present && makeRelative owner physical == "proto-lens-protoc") (die "plugin executable is outside its build directory")
      pure physical
