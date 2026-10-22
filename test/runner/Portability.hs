{-# LANGUAGE OverloadedStrings #-}
-- | Native observations of the shipped portable transport and bounded reader.
module Portability (portabilityRows, verifierChild, observerRows) where

import Amoebius.Cli.Delegate (verifierFileName)
import Amoebius.Doc.Check (discoverDocuments)
import Amoebius.Doc.Types (Finding (..))
import Amoebius.Validation.Runner.Observer (ObservedRun (..), observedDigest, renderObserved)
import Control.Monad (forM)
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.IO qualified as TIO
import System.Directory
  ( copyFile, createDirectoryIfMissing, doesDirectoryExist, doesFileExist, exeExtension
  , getCurrentDirectory, getPermissions, makeAbsolute, removePathForcibly, setPermissions )
import System.Environment (getExecutablePath, lookupEnv)
import System.Exit (ExitCode (..), die, exitWith)
import System.FilePath ((</>))
import System.IO (hPutStr, stderr)
import System.Process (CreateProcess (cwd, env), proc, readCreateProcessWithExitCode)
import Text.Read (readMaybe)

verifierChild :: [String] -> IO ()
verifierChild args = case args of
  output : status : _ | Just code <- readMaybe status -> do
    executable <- getExecutablePath
    directory <- getCurrentDirectory
    marker <- lookupEnv "AMOEBIUS_TRANSPORT_TEST"
    input <- getContents
    TIO.writeFile output (shown (executable, args, directory, marker, input))
    putStr "child stdout\n"
    hPutStr stderr "child stderr\n"
    exitWith (if code == 0 then ExitSuccess else ExitFailure code)
  _ -> die "malformed transport child input"

portabilityRows :: FilePath -> IO [[Text]]
portabilityRows output = do
  absolute <- makeAbsolute output
  exists <- doesDirectoryExist absolute
  if exists then die "portability output must be fresh" else createDirectoryIfMissing True absolute
  self <- getExecutablePath
  let fallback = absolute </> "search-path"
      copy image = do
        copyFile self image
        permissions <- getPermissions self
        setPermissions image permissions
  createDirectoryIfMissing True fallback
  copy (fallback </> verifierFileName exeExtension)
  delegation <- forM [("sibling", True, 23 :: Int), ("path", False, 0), ("missing", False, 0)] $ \(name, sibling, code) -> do
    let directory = absolute </> name
        primary = directory </> ("parent" <> exeExtension)
        transcript = directory </> "child.data"
        arguments = [transcript, show code, "space in argument", "λ", "", "$(literal)", "--option=value"]
        path = if name == "missing" then "" else fallback
    createDirectoryIfMissing True directory
    copy primary
    if sibling then copy (directory </> verifierFileName exeExtension) else pure ()
    observed <- readCreateProcessWithExitCode
      ((proc primary ("--delegation-parent" : arguments))
        {cwd = Just directory, env = Just [("PATH", path), ("AMOEBIUS_TRANSPORT_TEST", "opaque value λ"), ("LANG", "C.UTF-8"), ("LC_ALL", "C.UTF-8")]}) "opaque stdin\n"
    present <- doesFileExist transcript
    payload <- if present then TIO.readFile transcript else pure "absent"
    pure [["delegate", T.pack name, shown observed], ["child", T.pack name, payload]]
  let root = absolute </> "discovery"
  mapM_ (createDirectoryIfMissing True . (root </>)) ["documents", "DEVELOPMENT_PLAN"]
  TIO.writeFile (root </> "README.md") "# Fixture\n"
  TIO.writeFile (root </> "AGENTS.md") "# Fixture instructions\n"
  TIO.writeFile (root </> "CLAUDE.md") "@AGENTS.md\n"
  mapM_ (\index -> writeFile (root </> "documents" </> (show index <> ".txt")) "") [1 :: Int .. 1024]
  (_, exact, _) <- discoverDocuments root
  writeFile (root </> "documents/1025.txt") ""
  (_, over, _) <- discoverDocuments root
  removePathForcibly root
  removed <- not <$> doesDirectoryExist root
  pure (concat delegation <>
    [["filename", "posix", T.pack (verifierFileName "")], ["filename", "windows", T.pack (verifierFileName ".exe")]
    ,["discovery", "exact", findings exact], ["discovery", "over", findings over], ["discovery", "teardown", shown removed]])
 where findings = shown . sort . map (\item -> (findingCode item, findingSubject item))

observerRows :: [[Text]]
observerRows = [[name, shown (renderObserved "process" observation), observedDigest observation] | (name, observation) <- samples]
 where
  base = ObservedRun "/subject" ["a b", "c"] "/work" "policy:a" ExitSuccess "λ\n" "" Nothing
  samples = [("base", base), ("argv", base {runArgv = ["a", "b c"]})
    ,("policy", base {runEnvironmentPolicy = "policy:b"}), ("spawn", base {runSpawnFailure = Just "failed"})
    ,("executable", base {runExecutable = "/other"}), ("cwd", base {runCwd = "/elsewhere"})
    ,("exit", base {runExit = ExitFailure 23}), ("stdout", base {runStdout = "different"}), ("stderr", base {runStderr = "error"})]

shown :: Show value => value -> Text
shown = T.pack . show
