{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Monad (forM_, unless)
import Data.ByteString qualified as Strict
import Data.ByteString.Char8 qualified as Char8
import Data.ByteString.Lazy qualified as ByteString
import Data.List (isSuffixOf)
import System.Directory
  ( doesFileExist
  , createDirectoryIfMissing
  , getCurrentDirectory
  , getPermissions
  , makeAbsolute
  , setOwnerExecutable
  , setPermissions
  )
import System.Environment (getArgs, getEnvironment, lookupEnv, setEnv, unsetEnv)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO.Temp (withTempDirectory)
import System.Process (CreateProcess (env), proc, readCreateProcessWithExitCode)

main :: IO ()
main = do
  arguments <- getArgs
  let temporaryRoot = ".build/tmp/chain-boundary"
  createDirectoryIfMissing True temporaryRoot
  withTempDirectory temporaryRoot "boundary-" $ \runDirectory -> do
    outcome <- runBoundary runDirectory
    case arguments of
      ["--mutant=mB1_argv"] -> reject "mB1_argv" (boundaryArgvCaught outcome)
      ["--mutant=mB2_byte"] -> reject "mB2_byte" (boundaryBytesCaught outcome)
      ["--mutant=mB3_path_resolve"] -> reject "mB3_path_resolve" (boundaryPathCaught outcome)
      _ -> do
        assert (boundaryGreen outcome) "boundary transcript or byte oracle drifted"
        putStrLn "boundary-invariants: PASS (1 exact byte relay, 1 hostile PATH canary)"
        putStrLn "boundary-spec: PASS (4 real-binary invocations, 3 invoked tools, 1 zero-invocation helm control, exact argv and bytes, absolute paths, 3 mutants)"

data BoundaryOutcome = BoundaryOutcome
  { boundaryGreen :: Bool
  , boundaryArgvCaught :: Bool
  , boundaryBytesCaught :: Bool
  , boundaryPathCaught :: Bool
  }

runBoundary :: FilePath -> IO BoundaryOutcome
runBoundary runDirectory = do
  binary <- requireEnvironment "AMOEBIUS_BIN"
  root <- getCurrentDirectory
  fakeDirectory <- makeAbsolute "test/harness/chain_boundary/fakes"
  let decoyDirectory = runDirectory </> "decoys"
      transcriptDirectory = runDirectory </> "transcripts"
      sabotageMarker = runDirectory </> "path-sabotage"
  createFakeDirectory decoyDirectory sabotageMarker
  createDirectoryIfMissing True transcriptDirectory
  inherited <- getEnvironment
  let hostileEnvironment =
        ("PATH", decoyDirectory)
          : ("AMOEBIUS_TRANSCRIPT_DIR", transcriptDirectory)
          : filter ((`notElem` ["PATH", "AMOEBIUS_TRANSCRIPT_DIR"]) . fst) inherited
      fake tool = fakeDirectory </> tool
      manifest = root </> "test/fixture/chain_boundary/boundary/apply_input.json"
      command =
        (proc binary ["dev", "boundary-fixture", fake "kubectl", fake "docker", fake "helm", fake "pulumi", manifest])
          { env = Just hostileEnvironment
          }
  (exitCode, _, stderrText) <- readCreateProcessWithExitCode command ""
  assert (exitCode == ExitSuccess) ("real binary failed against fakes: " <> stderrText)
  argvMatches <- and <$> mapM (checkArgv transcriptDirectory fake) expectedTranscripts
  actualKubectlArguments <- drop 1 . lines <$> readFile (transcriptDirectory </> "kubectl.1.argv")
  expectedKubectlArguments <- lines <$> readFile "test/golden/chain_boundary/argv/kubectl.1.argv.golden"
  manifestBytes <- ByteString.readFile manifest
  appliedBytes <- ByteString.readFile (transcriptDirectory </> "kubectl.1.stdin")
  emptyDocker1 <- ByteString.null <$> ByteString.readFile (transcriptDirectory </> "docker.1.stdin")
  emptyDocker2 <- ByteString.null <$> ByteString.readFile (transcriptDirectory </> "docker.2.stdin")
  emptyPulumi <- ByteString.null <$> ByteString.readFile (transcriptDirectory </> "pulumi.1.stdin")
  kubectlPresent <- doesFileExist (transcriptDirectory </> "kubectl.count")
  dockerPresent <- doesFileExist (transcriptDirectory </> "docker.count")
  pulumiPresent <- doesFileExist (transcriptDirectory </> "pulumi.count")
  helmPresent <- doesFileExist (transcriptDirectory </> "helm.count")
  sabotagePresent <- doesFileExist sabotageMarker
  pathCanary <- runPathCanary decoyDirectory sabotageMarker hostileEnvironment
  let green =
        argvMatches
          && appliedBytes == manifestBytes
          && emptyDocker1
          && emptyDocker2
          && emptyPulumi
          && kubectlPresent
          && dockerPresent
          && pulumiPresent
          && not helmPresent
          && not sabotagePresent
          && pathCanary
  pure
    BoundaryOutcome
      { boundaryGreen = green
      , boundaryArgvCaught =
          argvMatches
            && actualKubectlArguments == expectedKubectlArguments
            && actualKubectlArguments /= dropLast expectedKubectlArguments
      , boundaryBytesCaught = appliedBytes == manifestBytes && appliedBytes /= flipFirstByte manifestBytes
      , boundaryPathCaught = not sabotagePresent && pathCanary
      }

expectedTranscripts :: [(FilePath, FilePath)]
expectedTranscripts =
  [ ("kubectl.1.argv", "test/golden/chain_boundary/argv/kubectl.1.argv.golden")
  , ("docker.1.argv", "test/golden/chain_boundary/argv/docker.1.argv.golden")
  , ("docker.2.argv", "test/golden/chain_boundary/argv/docker.2.argv.golden")
  , ("pulumi.1.argv", "test/golden/chain_boundary/argv/pulumi.1.argv.golden")
  ]

checkArgv :: FilePath -> (String -> FilePath) -> (FilePath, FilePath) -> IO Bool
checkArgv transcriptDirectory fake (actualName, goldenPath) = do
  actual <- lines <$> readFile (transcriptDirectory </> actualName)
  expected <- lines <$> readFile goldenPath
  case actual of
    [] -> pure False
    invokedPath : arguments -> do
      let tool = takeWhile (/= '.') actualName
      pure (invokedPath == fake tool && arguments == expected && ("/" <> tool) `isSuffixOf` invokedPath)

flipFirstByte :: ByteString.ByteString -> ByteString.ByteString
flipFirstByte bytes = case ByteString.uncons bytes of
  Nothing -> "x"
  Just (first, remaining) -> ByteString.cons (first + 1) remaining

dropLast :: [a] -> [a]
dropLast values = case reverse values of
  [] -> []
  _ : remaining -> reverse remaining

runPathCanary :: FilePath -> FilePath -> [(String, String)] -> IO Bool
runPathCanary decoyDirectory sabotageMarker hostileEnvironment = do
  originalPath <- lookupEnv "PATH"
  setEnv "PATH" decoyDirectory
  let command = (proc "kubectl" ["version"]) {env = Just hostileEnvironment}
  _ <- readCreateProcessWithExitCode command ""
  maybe (unsetEnv "PATH") (setEnv "PATH") originalPath
  observed <- doesFileExist sabotageMarker
  pure observed

createFakeDirectory :: FilePath -> FilePath -> IO ()
createFakeDirectory directory sabotageMarker = do
  createDirectoryIfMissing True directory
  forM_ ["kubectl", "docker", "helm", "pulumi"] $ \tool -> do
    let path = directory </> tool
    Strict.writeFile path ("#!/bin/sh\nprintf '%s\\n' sabotage > '" <> Char8.pack sabotageMarker <> "'\nexit 91\n")
    permissions <- getPermissions path
    setPermissions path (setOwnerExecutable True permissions)

requireEnvironment :: String -> IO String
requireEnvironment name = lookupEnv name >>= maybe (fail (name <> " is required")) pure

reject :: String -> Bool -> IO ()
reject name caught =
  if caught
    then putStrLn ("chain-boundary-boundary-mutant: RED " <> name) >> fail ("chain boundary mutant rejected: " <> name)
    else putStrLn ("chain-boundary-boundary-mutant: SURVIVED " <> name)

assert :: Bool -> String -> IO ()
assert condition message = unless condition (fail message)
