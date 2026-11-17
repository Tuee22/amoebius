module Main (main) where

import Amoebius.Cli.Formal (runFormalCommand)
import Amoebius.Build.Serial (BuildObservation (..), spawnCabal)
import Amoebius.Cli.Delegate (delegateValidate)
import Amoebius.Cluster.Bootstrap (runBootstrap)
import Amoebius.Dsl.Commands (runApply, runCompile, runRenderExamples, runAstcheck)
import Amoebius.Entry.ServeUi (runServeUi)
import Amoebius.Entry.ControlPlane (runControlPlaneDaemon)
import Amoebius.Exec.Boundary (mkBoundaryTools, runBoundaryCorpus)
import Amoebius.Image.Resolver (runResolverCommand)
import Amoebius.Layout.Report (runLayoutReport)
import Amoebius.Pulsar.Compat.Diagnostics (forkWireObservation)
import Amoebius.Pulsar.Compat.RoundTrip (wireRoundTripObservations)
import Amoebius.Pulsar.Diagnostics (connectWireObservation)
import Amoebius.Pulsar.Wire.Generate (WireGeneration (..), generateWireBindings, materializeForkProject, materializeNativeProject)
import Amoebius.Host.LinuxEngine (runLinuxEngineGuestPass)
import Amoebius.Image.Build (runAdmittedBuildxOci, runBakeInventory, runRenderBakeDockerfile)
import Amoebius.Kernel.Interpret (runFakeKubectl)
import Amoebius.Toolchain.Report (runToolchainReport)
import Amoebius.Toolchain.Acquire (ChildRecord (childExit))
import Amoebius.Toolchain.Provenance (UpstreamIdentity (upstreamVersion), forkModules, forkUpstream)
import Amoebius.Toolchain.SourceOwnership (protoSourceAttribution, protoSourceExamples)
import Amoebius.Vault.Client (runVaultPromptWriteCommand, runVaultReadCommand, runVaultTransitCommand)
import Amoebius.Vault.Seal (openUnlockMaterial, sealUnlockMaterialIO)
import Control.Monad (forM_, unless)
import Data.ByteString.Base64 qualified as Base64
import Data.ByteString.Char8 qualified as StrictByteString
import Data.ByteString.Lazy qualified as ByteString
import Data.Char (isAlphaNum, isAscii)
import Data.List (dropWhileEnd)
import Data.Text (Text)
import Data.Text.IO qualified as Text
import System.Directory (canonicalizePath, createDirectoryIfMissing, doesFileExist, exeExtension, makeAbsolute)
import System.Environment (getArgs, getProgName)
import System.Exit (ExitCode (..), die)
import System.FilePath (isAbsolute, makeRelative, splitDirectories, takeDirectory, (</>))
import System.Process (proc, readCreateProcessWithExitCode)
import Text.Read (readMaybe)

-- | The program image is also the fake @kubectl@ the fake executor spawns: invoked under
-- that name it records the call it receives and does nothing else.
main :: IO ()
main = do
  name <- getProgName
  if name `elem` ["kubectl", "kubectl" <> exeExtension] then runFakeKubectl else getArgs >>= dispatch

dispatch :: [String] -> IO ()
dispatch arguments =
  case arguments of
    "bootstrap" : options -> runBootstrap options
    "control-plane" : options -> runControlPlaneDaemon options
    "serve-ui" : options -> runServeUi options
    "jit-build-resolver" : options -> runResolverCommand options
    "render-bake-dockerfile" : options -> runRenderBakeDockerfile options
    "bake-inventory" : options -> runBakeInventory options
    "admitted-buildx-oci" : options -> runAdmittedBuildxOci options
    "vault-read" : options -> runVaultReadCommand options
    "vault-transit-decrypt" : options -> runVaultTransitCommand options
    "vault-prompt-write" : options -> runVaultPromptWriteCommand options
    "validate" : options -> delegateValidate options
    "toolchain-report" : options -> runToolchainReport options
    "layout-report" : options -> runLayoutReport options
    "render-examples" : options -> runRenderExamples options
    "compile" : options -> runCompile options
    "astcheck" : options -> runAstcheck options
    "apply" : options -> runApply options
    ["--version"] -> putStrLn "amoebius 0.1.0.0"
    ["dev", "observe-pulsar-wire", "native"] -> either (die . show) Text.putStr connectWireObservation
    ["dev", "observe-pulsar-wire", "fork"] -> Text.putStr forkWireObservation
    ["dev", "observe-pulsar-wire", "roundtrip"] -> Text.putStr wireRoundTripObservations
    ["dev", "observe-pulsar-source-ownership"] -> mapM_ print (protoSourceAttribution protoSourceExamples)
    ["dev", "observe-pulsar-wire", "native", "--output", path] -> either (die . show) (writeWireObservation path) connectWireObservation
    ["dev", "observe-pulsar-wire", "fork", "--output", path] -> writeWireObservation path forkWireObservation
    ["dev", "observe-pulsar-wire", "roundtrip", "--output", path] -> writeWireObservation path wireRoundTripObservations
    ["dev", "generate-pulsar-bindings", runName, protoc, plugin]
      | not (null runName) && all validRunName runName -> do
          result <- generateWireBindings protoc plugin (".build" </> "proto" </> runName)
          either (die . show) (mapM_ putStrLn . (\generated -> wireSchemaPath generated : wireGeneratedFiles generated)) result
    "dev" : "generate-pulsar-bindings" : _ -> die "usage: amoebius dev generate-pulsar-bindings RUN-NAME PROTOC PLUGIN (RUN-NAME uses letters, digits, '-' or '_')"
    ["dev", "generate-pulsar-fork", runName, protoc, plugin]
      | not (null runName) && all validRunName runName -> do
          generation <- generateWireBindings protoc plugin (".build" </> "proto" </> runName) >>= either (die . show) pure
          materializeForkProject "." (upstreamVersion forkUpstream) forkModules generation >>= either (die . show) putStrLn
    "dev" : "generate-pulsar-fork" : _ -> die "usage: amoebius dev generate-pulsar-fork RUN-NAME PROTOC PLUGIN (RUN-NAME uses letters, digits, '-' or '_')"
    ["dev", "build-pulsar-fork", runName, protoc, plugin, cabal, ghc]
      | not (null runName) && all validRunName runName -> do
          generation <- generateWireBindings protoc plugin (".build" </> "proto" </> runName) >>= either (die . show) pure
          project <- materializeForkProject "." (upstreamVersion forkUpstream) forkModules generation >>= either (die . show) pure
          cabalPath <- makeAbsolute cabal
          compilerPath <- makeAbsolute ghc
          buildWireObserver project cabalPath compilerPath "exe:amoebius-fork-wire-observer" "compat-build" "fork-wire.tsv"
          putStrLn project
    "dev" : "build-pulsar-fork" : _ -> die "usage: amoebius dev build-pulsar-fork RUN-NAME PROTOC PLUGIN CABAL GHC (RUN-NAME uses letters, digits, '-' or '_')"
    ["dev", "build-pulsar-clients", runName, protoc, plugin, cabal, ghc]
      | not (null runName) && all validRunName runName -> do
          generation <- generateWireBindings protoc plugin (".build" </> "proto" </> runName) >>= either (die . show) pure
          native <- materializeNativeProject "." generation >>= either (die . show) pure
          fork <- materializeForkProject "." (upstreamVersion forkUpstream) forkModules generation >>= either (die . show) pure
          cabalPath <- makeAbsolute cabal
          compilerPath <- makeAbsolute ghc
          forM_ [(native, "exe:amoebius-native-wire-observer", "native-build", "native-wire.tsv"), (fork, "exe:amoebius-fork-wire-observer", "compat-build", "fork-wire.tsv")] $ \(project, target, buildName, outputName) -> do
            buildWireObserver project cabalPath compilerPath target buildName outputName
            putStrLn project
    "dev" : "build-pulsar-clients" : _ -> die "usage: amoebius dev build-pulsar-clients RUN-NAME PROTOC PLUGIN CABAL GHC (RUN-NAME uses letters, digits, '-' or '_')"
    ["dev", "linux-engine-guest-pass", passText, outputRoot]
      | Just pass <- readMaybe passText -> runLinuxEngineGuestPass pass outputRoot
    ["vault-seal-unlock"] -> runSealUnlock
    ["vault-open-unlock"] -> runOpenUnlock
    ["dev", "boundary-fixture", kubectl, docker, helm, pulumi, manifestPath] -> do
      tools <- either (fail . show) pure (mkBoundaryTools kubectl docker helm pulumi)
      manifestBytes <- ByteString.readFile manifestPath
      _ <- runBoundaryCorpus tools manifestBytes
      putStrLn "boundary-fixture: PASS"
    _ -> runFormalCommand arguments

validRunName :: Char -> Bool
validRunName character = isAscii character && (isAlphaNum character || character `elem` ("-_" :: String))

writeWireObservation :: FilePath -> Text -> IO ()
writeWireObservation path contents = createDirectoryIfMissing True (takeDirectory path) >> Text.writeFile path contents >> Text.putStr contents

-- Build and run the observer that links the staged client. Cabal supplies its
-- actual executable path, which must remain inside this run's build directory.
buildWireObserver :: FilePath -> FilePath -> FilePath -> String -> FilePath -> FilePath -> IO ()
buildWireObserver project cabal compiler target buildName outputName = do
  let owner = takeDirectory project
      buildDirectory = owner </> buildName
  (built, _, buildError) <- spawnCabal project cabal compiler ["build", target, "--builddir=" <> buildDirectory]
  unless (childExit (buildEffectiveChild built) == 0) (die (target <> " build failed: " <> buildError))
  (located, output, locateError) <- spawnCabal project cabal compiler ["list-bin", "-v0", target, "--builddir=" <> buildDirectory]
  unless (childExit (buildEffectiveChild located) == 0) (die (target <> " location failed: " <> locateError))
  let candidate = dropWhileEnd (`elem` ['\n', '\r']) output
  unless (isAbsolute candidate && '\n' `notElem` candidate && '\r' `notElem` candidate) (die (target <> " returned an invalid executable path"))
  physicalOwner <- canonicalizePath owner
  root <- canonicalizePath buildDirectory
  executable <- canonicalizePath candidate
  present <- doesFileExist executable
  let relativeRoot = makeRelative physicalOwner root
      relative = makeRelative root executable
  unless (relativeRoot == buildName && present && not (isAbsolute relative) && ".." `notElem` splitDirectories relative) (die (target <> " executable is outside its build directory"))
  (exit, observed, err) <- readCreateProcessWithExitCode (proc executable []) ""
  case exit of
    ExitSuccess -> writeFile (owner </> outputName) observed
    ExitFailure code -> die (target <> " observation failed (" <> show code <> "): " <> err)

runSealUnlock :: IO ()
runSealUnlock = do
  input <- StrictByteString.getContents
  let (password, plaintextWithNewline) = StrictByteString.break (== '\n') input
      plaintext = StrictByteString.drop 1 plaintextWithNewline
  result <- sealUnlockMaterialIO password plaintext
  either fail (StrictByteString.putStrLn . Base64.encode) result

runOpenUnlock :: IO ()
runOpenUnlock = do
  input <- StrictByteString.getContents
  let (password, envelopeWithNewline) = StrictByteString.break (== '\n') input
      encoded = StrictByteString.strip (StrictByteString.drop 1 envelopeWithNewline)
  envelope <- either fail pure (Base64.decode encoded)
  either fail StrictByteString.putStr (openUnlockMaterial password envelope)
