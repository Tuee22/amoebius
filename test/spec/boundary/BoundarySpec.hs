{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import ChainBoundaryOracle (expectedBoundaryArgv, expectedBoundaryManifest)
import Control.Monad (forM_, unless)
import Data.ByteString qualified as Strict
import Data.ByteString.Char8 qualified as Char8
import Data.ByteString.Lazy qualified as ByteString
import Data.List (isInfixOf, isSuffixOf)
import System.Directory
  ( copyFile
  , createDirectoryIfMissing
  , doesFileExist
  , getPermissions
  , makeAbsolute
  , setOwnerExecutable
  , setPermissions
  )
import System.Environment (getArgs, getEnvironment, getExecutablePath, getProgName, lookupEnv, setEnv, unsetEnv)
import System.Exit (ExitCode (..), exitWith)
import System.FilePath ((</>))
import System.IO.Temp (withTempDirectory)
import System.Process (CreateProcess (env), proc, readCreateProcessWithExitCode)

toolNames :: [String]
toolNames = ["kubectl", "docker", "helm", "pulumi"]

main :: IO ()
main = do
  program <- getProgName
  if program `elem` toolNames then runFake program else runBoundarySpec

runBoundarySpec :: IO ()
runBoundarySpec = do
  let temporaryRoot = ".build/tmp/chain-boundary"
  createDirectoryIfMissing True temporaryRoot
  withTempDirectory temporaryRoot "boundary-" $ \runDirectory -> do
    runBoundary runDirectory
    putStrLn "boundary-invariants: PASS (1 exact byte relay, 1 hostile PATH canary)"
    putStrLn "boundary-spec: PASS (4 real-binary invocations, 3 invoked tools, 1 zero-invocation helm control, exact argv and bytes, absolute paths, 3 mutants)"

runBoundary :: FilePath -> IO ()
runBoundary runDirectory = do
  binary <- requireEnvironment "AMOEBIUS_BIN"
  self <- getExecutablePath
  fakeDirectory <- makeAbsolute (runDirectory </> "fakes")
  decoyDirectory <- makeAbsolute (runDirectory </> "decoys")
  let transcriptDirectory = runDirectory </> "transcripts"
      sabotageMarker = runDirectory </> "path-sabotage"
      manifest = runDirectory </> "apply-input.json"
  materializeHaskellFakes self fakeDirectory
  materializeHaskellFakes self decoyDirectory
  createDirectoryIfMissing True transcriptDirectory
  ByteString.writeFile manifest expectedBoundaryManifest
  inherited <- getEnvironment
  let hostileEnvironment =
        ("PATH", decoyDirectory)
          : ("AMOEBIUS_TRANSCRIPT_DIR", transcriptDirectory)
          : ("AMOEBIUS_FAKE_ROLE", "real")
          : ("AMOEBIUS_DECOY_MARKER", sabotageMarker)
          : filter ((`notElem` ["PATH", "AMOEBIUS_TRANSCRIPT_DIR", "AMOEBIUS_FAKE_ROLE", "AMOEBIUS_DECOY_MARKER"]) . fst) inherited
      fake tool = fakeDirectory </> tool
      command =
        (proc binary ["dev", "boundary-fixture", fake "kubectl", fake "docker", fake "helm", fake "pulumi", manifest])
          {env = Just hostileEnvironment}
  (exitCode, _, stderrText) <- readCreateProcessWithExitCode command ""
  sabotagedDuringSubject <- doesFileExist sabotageMarker
  assert (not sabotagedDuringSubject) "hostile-path"
  assert (exitCode == ExitSuccess) ("real binary failed against fakes: " <> stderrText)
  argvMatches <- and <$> mapM (checkArgv transcriptDirectory fake) expectedBoundaryArgv
  assert argvMatches "argv-transcript"
  manifestBytes <- ByteString.readFile manifest
  appliedBytes <- ByteString.readFile (transcriptDirectory </> "kubectl.1.stdin")
  assert (appliedBytes == manifestBytes) "applied-bytes"
  emptyDocker1 <- ByteString.null <$> ByteString.readFile (transcriptDirectory </> "docker.1.stdin")
  emptyDocker2 <- ByteString.null <$> ByteString.readFile (transcriptDirectory </> "docker.2.stdin")
  emptyPulumi <- ByteString.null <$> ByteString.readFile (transcriptDirectory </> "pulumi.1.stdin")
  assert (emptyDocker1 && emptyDocker2 && emptyPulumi) "unexpected-stdin"
  kubectlPresent <- doesFileExist (transcriptDirectory </> "kubectl.count")
  dockerPresent <- doesFileExist (transcriptDirectory </> "docker.count")
  pulumiPresent <- doesFileExist (transcriptDirectory </> "pulumi.count")
  helmPresent <- doesFileExist (transcriptDirectory </> "helm.count")
  assert (kubectlPresent && dockerPresent && pulumiPresent && not helmPresent) "tool-invocation-cardinality"
  sabotagePresent <- doesFileExist sabotageMarker
  pathCanary <- runPathCanary decoyDirectory sabotageMarker hostileEnvironment
  assert (not sabotagePresent && pathCanary) "hostile-path"

checkArgv :: FilePath -> (String -> FilePath) -> (FilePath, [String]) -> IO Bool
checkArgv transcriptDirectory fake (actualName, expected) = do
  actual <- lines <$> readFile (transcriptDirectory </> actualName)
  case actual of
    [] -> pure False
    invokedPath : arguments -> do
      let tool = takeWhile (/= '.') actualName
      pure (invokedPath == fake tool && arguments == expected && ("/" <> tool) `isSuffixOf` invokedPath)

runPathCanary :: FilePath -> FilePath -> [(String, String)] -> IO Bool
runPathCanary decoyDirectory sabotageMarker hostileEnvironment = do
  originalPath <- lookupEnv "PATH"
  setEnv "PATH" decoyDirectory
  let decoyEnvironment = ("AMOEBIUS_FAKE_ROLE", "decoy") : filter ((/= "AMOEBIUS_FAKE_ROLE") . fst) hostileEnvironment
      command = (proc "kubectl" ["version"]) {env = Just decoyEnvironment}
  _ <- readCreateProcessWithExitCode command ""
  maybe (unsetEnv "PATH") (setEnv "PATH") originalPath
  doesFileExist sabotageMarker

materializeHaskellFakes :: FilePath -> FilePath -> IO ()
materializeHaskellFakes source directory = do
  createDirectoryIfMissing True directory
  forM_ toolNames $ \tool -> do
    let destination = directory </> tool
    copyFile source destination
    permissions <- getPermissions destination
    setPermissions destination (setOwnerExecutable True permissions)

runFake :: String -> IO ()
runFake tool = do
  role <- requireEnvironment "AMOEBIUS_FAKE_ROLE"
  executable <- getExecutablePath
  if role == "decoy" || "/decoys/" `isInfixOf` executable
    then do
      marker <- requireEnvironment "AMOEBIUS_DECOY_MARKER"
      writeFile marker "sabotage\n"
      exitWith (ExitFailure 91)
    else do
      transcriptDirectory <- requireEnvironment "AMOEBIUS_TRANSCRIPT_DIR"
      createDirectoryIfMissing True transcriptDirectory
      let counterPath = transcriptDirectory </> tool <> ".count"
      prior <- ifM (doesFileExist counterPath) (read . Char8.unpack <$> Strict.readFile counterPath) 0
      let count = prior + (1 :: Int)
          base = transcriptDirectory </> tool <> "." <> show count
      writeFile counterPath (show count <> "\n")
      arguments <- getArgs
      writeFile (base <> ".argv") (unlines (executable : arguments))
      stdinBytes <- Strict.getContents
      Strict.writeFile (base <> ".stdin") stdinBytes
      putStrLn (if tool == "helm" then "fake-tool: unexpected helm invocation" else "fake-tool: ok")

ifM :: Monad m => m Bool -> m a -> a -> m a
ifM condition yes no = condition >>= \result -> if result then yes else pure no

requireEnvironment :: String -> IO String
requireEnvironment name = lookupEnv name >>= maybe (fail (name <> " is required")) pure

assert :: Bool -> String -> IO ()
assert condition message = unless condition (fail message)
