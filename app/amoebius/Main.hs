module Main (main) where

import Amoebius.Cli.Formal (runFormalCommand)
import Amoebius.Cluster.Bootstrap (runBootstrap)
import Amoebius.Entry.ServeUi (runServeUi)
import Amoebius.Entry.ControlPlane (runControlPlaneDaemon)
import Amoebius.Exec.Boundary (mkBoundaryTools, runBoundaryCorpus)
import Amoebius.Image.Resolver (runResolverCommand)
import Amoebius.Host.LinuxEngine (runLinuxEngineGuestPass)
import Amoebius.Image.Build (runAdmittedBuildxOci, runBakeInventory, runRenderBakeDockerfile)
import Amoebius.Toolchain.Report (runToolchainReport)
import Amoebius.Vault.Client (runVaultPromptWriteCommand, runVaultReadCommand, runVaultTransitCommand)
import Amoebius.Vault.Seal (openUnlockMaterial, sealUnlockMaterialIO)
import Data.ByteString.Base64 qualified as Base64
import Data.ByteString.Char8 qualified as StrictByteString
import Data.ByteString.Lazy qualified as ByteString
import System.Directory (doesFileExist, findExecutable)
import System.Environment (getArgs, getExecutablePath)
import System.Exit (ExitCode (..), exitWith)
import System.FilePath (takeDirectory, (</>))
import System.IO (hPutStrLn, stderr)
import System.Posix.Process (executeFile)
import Text.Read (readMaybe)

main :: IO ()
main = getArgs >>= dispatch

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
    ["--version"] -> putStrLn "amoebius 0.1.0.0"
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

-- | The product binary owns no verdict. @amoebius validate …@ replaces this
-- process with the verifier executable beside it (or on PATH), forwarding every
-- argument unchanged, so the bootstrap's public spelling and its pin are
-- untouched (gate_runner_doctrine.md section 6).
delegateValidate :: [String] -> IO ()
delegateValidate options = do
  self <- getExecutablePath
  let sibling = takeDirectory self </> "amoebius-validate"
  siblingExists <- doesFileExist sibling
  resolved <- if siblingExists then pure (Just sibling) else findExecutable "amoebius-validate"
  case resolved of
    Just verifier -> executeFile verifier False options Nothing
    Nothing -> do
      hPutStrLn stderr "amoebius validate: the verifier executable amoebius-validate is neither beside amoebius nor on PATH"
      exitWith (ExitFailure 2)
