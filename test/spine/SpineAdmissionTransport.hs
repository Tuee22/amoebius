{-# LANGUAGE OverloadedStrings #-}

-- Native compiler boundaries, always serial. This producer records observations;
-- the separate oracle owns all expectations and verdicts.
module SpineAdmissionTransport (admissionTransportSection, admissionTransportFromBuild) where

import Amoebius.Dsl.Examples.Extensions.SourceInputs
  ( transportPureProbe, transportUnsafeProbe, transportPluginProbe
  , transportOptionPrefix, transportTrustedEffect )
import Control.Monad (forM, forM_)
import Data.List (sort)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import System.Directory
  ( copyFile, createDirectoryIfMissing, doesDirectoryExist, doesFileExist
  , listDirectory, makeAbsolute, getCurrentDirectory )
import System.Exit (ExitCode (..))
import System.FilePath ((</>), takeDirectory, isAbsolute)
import System.Process (CreateProcess (cwd), proc, readCreateProcessWithExitCode)
import Text.Read (readMaybe)

-- The guarded build supplies explicit native executable paths. Its cache is
-- tool input only: neither the control registry nor a verdict comes from it.
-- Missing input refuses this section; the generic runner must establish the
-- transport before it builds and invokes a suite.
admissionTransportFromBuild :: FilePath -> IO ()
admissionTransportFromBuild output = do
  root <- getCurrentDirectory
  contents <- readFile (root </> ".build/source-admission/admitted-source.snapshot")
  case readMaybe contents :: Maybe (FilePath, FilePath, [(FilePath, Text.Text)]) of
    Just (compiler, driver, _) | isAbsolute compiler && isAbsolute driver ->
      admissionTransportSection root compiler driver output
    _ -> fail "guarded native build transport inputs are absent or malformed"

admissionTransportSection :: FilePath -> FilePath -> FilePath -> FilePath -> IO ()
admissionTransportSection root compiler driver output = do
  absoluteOutput <- makeAbsolute output
  sourceFiles <- discover (root </> contributions)
  createDirectoryIfMissing True absoluteOutput
  rows <- forM names $ \name -> do
    let directory = absoluteOutput </> name
        probe = contributions </> "Amoebius/Extension/Contributed/GuardProbe.hs"
        wrapper = directory </> ".build/guarded-ghc"
        flags file = ["--make", "-j1", "-fno-code", "-XGHC2024", "-hide-all-packages",
          "-package", "base", "-package", "template-haskell", "-outputdir", ".build/compile", file]
    forM_ sourceFiles $ \path -> do
      createDirectoryIfMissing True (takeDirectory (directory </> contributions </> path))
      copyFile (root </> contributions </> path) (directory </> contributions </> path)
    createDirectoryIfMissing True (directory </> ".build")
    prepared <- run directory driver ["--write-compiler-wrapper", compiler, wrapper]
    writeObservation directory "prepare" prepared
    let writeProbe body = writeFile (directory </> probe) body
    command <- case name of
      "complete-peer-closure" -> pure (wrapper, ["--numeric-version"])
      "incremental-existing-unsafe-source" -> do
        let jit = directory </> contributions </> "Amoebius/Extension/Contributed/JitBuild.hs"
        body <- readFile jit
        length body `seq` writeFile jit (Text.unpack transportOptionPrefix <> body)
        writeProbe pureProbe
        pure (wrapper, flags probe)
      "incremental-new-unsafe-source" -> writeProbe unsafeProbe >> pure (wrapper, flags probe)
      "precompile-plugin-option" -> do
        writeProbe (Text.unpack transportPluginProbe)
        pure (wrapper, flags probe)
      "trusted-effect-control" -> do
        let fixture = ".build/TrustedEffect.hs"
        writeFile (directory </> fixture) trustedEffect
        pure (compiler, flags fixture)
      _ -> writeProbe pureProbe >> pure (wrapper, flags probe)
    observed <- case prepared of
      (ExitSuccess, _, _) -> uncurry (run directory) command
      failure -> pure failure
    writeObservation directory "" observed
    effect <- doesFileExist (directory </> ".build/effect.marker")
    pure (Text.intercalate "\t" [Text.pack name, Text.pack (show (exitNumber observed)), Text.pack (show effect)])
  Text.writeFile (absoluteOutput </> "transport.tsv") (Text.unlines rows)
 where
  names = ["complete-peer-closure", "pure-helper-closure", "incremental-existing-unsafe-source",
           "incremental-new-unsafe-source", "precompile-plugin-option", "trusted-effect-control"]
  contributions = "src/extension-contributions"
  discover directory = do
    names' <- sort <$> listDirectory directory
    concat <$> forM names' (\name -> do
      folder <- doesDirectoryExist (directory </> name)
      if folder then map (name </>) <$> discover (directory </> name) else pure [name])
  run directory command arguments = readCreateProcessWithExitCode ((proc command arguments) {cwd = Just directory}) ""
  exitNumber (code, _, _) = case code of ExitSuccess -> 0 :: Int; ExitFailure number -> number
  writeObservation directory prefix (code, out, err) = do
    writeFile (directory </> (prefix <> "stdout")) out
    writeFile (directory </> (prefix <> "stderr")) err
    writeFile (directory </> (prefix <> "exit")) (show code <> "\n")
  pureProbe = Text.unpack transportPureProbe
  unsafeProbe = Text.unpack transportUnsafeProbe
  trustedEffect = Text.unpack transportTrustedEffect
