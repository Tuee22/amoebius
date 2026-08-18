module Main (main) where

import Amoebius.Cli.Formal (runFormalCommand)
import Amoebius.Cluster.Bootstrap (runBootstrap)
import Amoebius.Entry.ServeUi (runServeUi)
import Amoebius.Entry.ControlPlane (runControlPlaneDaemon)
import Amoebius.Exec.Boundary (mkBoundaryTools, runBoundaryCorpus)
import Amoebius.Image.Resolver (runResolverCommand)
import Amoebius.Image.Build (runAdmittedBuildxOci, runBakeInventory, runRenderBakeDockerfile)
import Amoebius.Vault.Client (runVaultPromptWriteCommand, runVaultReadCommand, runVaultTransitCommand)
import Amoebius.Vault.Seal (openUnlockMaterial, sealUnlockMaterialIO)
import Data.ByteString.Base64 qualified as Base64
import Data.ByteString.Char8 qualified as StrictByteString
import Data.ByteString.Lazy qualified as ByteString
import System.Environment (getArgs)

main :: IO ()
main = do
  arguments <- getArgs
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
    ["vault-seal-unlock"] -> runSealUnlock
    ["vault-open-unlock"] -> runOpenUnlock
    ["dev", "boundary-fixture", kubectl, docker, helm, pulumi, manifestPath] -> do
      tools <- either (fail . show) pure (mkBoundaryTools kubectl docker helm pulumi)
      manifestBytes <- ByteString.readFile manifestPath
      _ <- runBoundaryCorpus tools manifestBytes
      putStrLn "boundary-fixture: PASS"
    _ -> runFormalCommand arguments

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
