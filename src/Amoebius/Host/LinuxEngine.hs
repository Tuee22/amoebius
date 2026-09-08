{-# LANGUAGE CPP #-}

-- | The typed Linux engine bring-up plan.  Live interpreters may execute these
-- actions only after a pristine observation has been admitted; the second pass
-- is derived from a fresh observation rather than from the first pass's ledger.
module Amoebius.Host.LinuxEngine
  ( NativeArchitecture (..)
  , LinuxEngineSurface (..)
  , LinuxEngineObservation (..)
  , LinuxEngineMutation (..)
  , LedgerAction (..)
  , LinuxEngineError (..)
  , pristineObservation
  , admitPristineGuest
  , planLinuxEnginePass
  , admitNativeBuild
  , daemonProbeArgv
  , futureSessionArgv
  , runLinuxEngineGuestPass
  ) where

import Amoebius.Host.Ensure (ToolResult (..), mkAbsExe, runTool)
import Control.Monad (unless, when)
import Data.ByteString.Lazy.Char8 qualified as ByteString
import Data.List (isInfixOf)
import System.Directory (copyFile, createDirectoryIfMissing)
import System.Environment (getExecutablePath)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))

data NativeArchitecture = Amd64 | Arm64
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data LinuxEngineSurface
  = EnginePackage
  | DockerGroup
  | DaemonSocket
  | NativeImage
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data LinuxEngineObservation = LinuxEngineObservation
  { enginePackagePresent :: Bool
  , dockerGroupMember :: Bool
  , daemonReachable :: Bool
  , nativeImagePresent :: Bool
  }
  deriving stock (Eq, Ord, Show)

data LinuxEngineMutation
  = InstallEngine
  | PersistDockerGroupMembership
  | StartDockerDaemon
  | RefreshCurrentCredentials
  | BuildNativeImage
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data LedgerAction
  = Probe LinuxEngineSurface
  | Mutate LinuxEngineMutation
  deriving stock (Eq, Ord, Show)

data LinuxEngineError
  = GuestNotPristine LinuxEngineSurface
  | ArchitectureMismatch NativeArchitecture NativeArchitecture NativeArchitecture
  deriving stock (Eq, Ord, Show)

pristineObservation :: LinuxEngineObservation
pristineObservation = LinuxEngineObservation False False False False

admitPristineGuest :: LinuxEngineObservation -> Either LinuxEngineError ()
admitPristineGuest observed = case [surface | surface <- [minBound .. maxBound], surfacePresent surface observed] of
  [] -> Right ()
  surface : _ -> Left (GuestNotPristine surface)

planLinuxEnginePass :: LinuxEngineObservation -> [LedgerAction]
#if defined(LINUX_ENGINE_CONVERGE_WITHOUT_PROBE_MUTANT)
planLinuxEnginePass observed
  | observed == convergedObservation = []
  | otherwise = ordinaryPlan observed
#else
planLinuxEnginePass = ordinaryPlan
#endif

ordinaryPlan :: LinuxEngineObservation -> [LedgerAction]
ordinaryPlan observed = probes <> mutations
 where
  probes = map Probe [minBound .. maxBound]
  mutations =
    [Mutate InstallEngine | not (enginePackagePresent observed)]
#if defined(LINUX_ENGINE_EPHEMERAL_MEMBERSHIP_MUTANT)
      <> []
#else
      <> [Mutate PersistDockerGroupMembership | not (dockerGroupMember observed)]
#endif
      <> [Mutate StartDockerDaemon | not (daemonReachable observed)]
#if defined(LINUX_ENGINE_UNREFRESHED_CREDENTIALS_MUTANT)
      <> []
#else
      <> [Mutate RefreshCurrentCredentials | not (dockerGroupMember observed) || not (daemonReachable observed)]
#endif
      <> [Mutate BuildNativeImage | not (nativeImagePresent observed)]

admitNativeBuild
  :: NativeArchitecture
  -> NativeArchitecture
  -> NativeArchitecture
  -> Either LinuxEngineError ()
#if defined(LINUX_ENGINE_PLATFORM_OVERRIDE_MUTANT)
admitNativeBuild _ _ _ = Right ()
#else
admitNativeBuild requested guest engine
  | requested == guest && guest == engine = Right ()
  | otherwise = Left (ArchitectureMismatch requested guest engine)
#endif

daemonProbeArgv :: [String]
#if defined(LINUX_ENGINE_ELEVATED_RETRY_MUTANT)
daemonProbeArgv = ["/usr/bin/sudo", "-n", "/usr/bin/docker", "info", "--format", "{{.ServerVersion}}"]
#else
daemonProbeArgv = ["/usr/bin/docker", "info", "--format", "{{.ServerVersion}}"]
#endif

futureSessionArgv :: String -> [String]
futureSessionArgv user = ["/usr/bin/su", "-", user, "-c", unwords daemonProbeArgv]

surfacePresent :: LinuxEngineSurface -> LinuxEngineObservation -> Bool
surfacePresent surface observed = case surface of
  EnginePackage -> enginePackagePresent observed
  DockerGroup -> dockerGroupMember observed
  DaemonSocket -> daemonReachable observed
  NativeImage -> nativeImagePresent observed

convergedObservation :: LinuxEngineObservation
convergedObservation = LinuxEngineObservation True True True True

-- | Interpret one pass inside the disposable Linux guest.  Every executable is
-- absolute and every mutation comes from 'planLinuxEnginePass'; the outer live
-- runner owns guest creation and unconditional deletion.
runLinuxEngineGuestPass :: Int -> FilePath -> IO ()
runLinuxEngineGuestPass pass outputRoot = do
  unless (pass == 1 || pass == 2) (fail "linux-engine-pass-must-be-one-or-two")
  createDirectoryIfMissing True outputRoot
  before <- observeLinuxEngine
  when (pass == 1) (either (fail . show) pure (admitPristineGuest before))
  let actions = planLinuxEnginePass before
  mapM_ enact actions
  after <- observeLinuxEngine
  unless (after == convergedObservation) (fail ("linux-engine-postcondition:" <> show after))
  writeFile (outputRoot </> ("pass-" <> show pass <> "-ledger.tsv")) (unlines (map renderAction actions))
  writeFile (outputRoot </> ("pass-" <> show pass <> "-surfaces.tsv")) (renderSurfaces after)
  writeFile (outputRoot </> ("pass-" <> show pass <> "-version.txt")) =<< containerVersion
 where
  enact action = case action of
    Probe _ -> pure ()
    Mutate mutation -> enactMutation outputRoot mutation

observeLinuxEngine :: IO LinuxEngineObservation
observeLinuxEngine = do
  package <- succeeds "/usr/bin/dpkg-query" ["-W", "-f=${Status}", "docker.io"]
  group <- runAbsolute "/usr/bin/getent" ["group", "docker"]
  daemon <- if package
    then succeeds "/usr/bin/setpriv" ["--reuid=ubuntu", "--regid=ubuntu", "--init-groups", "/usr/bin/docker", "info", "--format", "{{.ServerVersion}}"]
    else pure False
  image <- if package
    then succeeds "/usr/bin/docker" ["image", "inspect", imageReference]
    else pure False
  pure LinuxEngineObservation
    { enginePackagePresent = package
    , dockerGroupMember = toolSucceeded group && ":ubuntu" `isInfixOf` ByteString.unpack (toolStdout group)
    , daemonReachable = daemon
    , nativeImagePresent = image
    }

enactMutation :: FilePath -> LinuxEngineMutation -> IO ()
enactMutation outputRoot mutation = case mutation of
  InstallEngine -> do
    requireSuccess "apt-update" =<< runAbsolute "/usr/bin/apt-get" ["update"]
    requireSuccess "apt-install-docker" =<< runAbsolute "/usr/bin/env" ["DEBIAN_FRONTEND=noninteractive", "/usr/bin/apt-get", "install", "-y", "docker.io"]
  PersistDockerGroupMembership ->
    requireSuccess "persist-docker-membership" =<< runAbsolute "/usr/sbin/usermod" ["-aG", "docker", "ubuntu"]
  StartDockerDaemon ->
    requireSuccess "start-docker" =<< runAbsolute "/usr/bin/systemctl" ["enable", "--now", "docker.service"]
  RefreshCurrentCredentials -> do
    requireSuccess "current-process-credentials" =<< runAbsolute "/usr/bin/setpriv" ["--reuid=ubuntu", "--regid=ubuntu", "--init-groups", "/usr/bin/docker", "info", "--format", "{{.ServerVersion}}"]
    requireSuccess "future-session-credentials" =<< runAbsolute "/usr/bin/su" ["-", "ubuntu", "-c", unwords daemonProbeArgv]
  BuildNativeImage -> buildNativeImage outputRoot

buildNativeImage :: FilePath -> IO ()
buildNativeImage outputRoot = do
  requested <- pure Amd64
  guest <- architectureFrom =<< stdoutOf "/usr/bin/uname" ["-m"]
  engine <- architectureFrom =<< stdoutOf "/usr/bin/docker" ["version", "--format", "{{.Server.Arch}}"]
  either (fail . show) pure (admitNativeBuild requested guest engine)
  executable <- getExecutablePath
  let context = outputRoot </> "image-context"
      imageBinary = context </> "amoebius"
      dockerfile = context </> "Dockerfile"
  createDirectoryIfMissing True context
  copyFile executable imageBinary
  writeFile dockerfile (unlines
    [ "FROM ubuntu:24.04"
    , "COPY amoebius /usr/bin/amoebius"
    , "USER 65532:65532"
    , "ENTRYPOINT [\"/usr/bin/amoebius\"]"
    ])
  requireSuccess "native-image-build" =<< runAbsolute "/usr/bin/docker"
    ["build", "--file", dockerfile, "--tag", imageReference, context]

containerVersion :: IO String
containerVersion = do
  result <- runAbsolute "/usr/bin/setpriv"
    ["--reuid=ubuntu", "--regid=ubuntu", "--init-groups", "/usr/bin/docker", "run", "--rm", imageReference, "--version"]
  requireSuccess "container-version" result
  pure (ByteString.unpack (toolStdout result))

architectureFrom :: String -> IO NativeArchitecture
architectureFrom raw = case takeWhile (/= '\n') raw of
  "x86_64" -> pure Amd64
  "amd64" -> pure Amd64
  "aarch64" -> pure Arm64
  "arm64" -> pure Arm64
  value -> fail ("linux-engine-architecture-unknown:" <> value)

stdoutOf :: FilePath -> [String] -> IO String
stdoutOf executable arguments = do
  result <- runAbsolute executable arguments
  requireSuccess executable result
  pure (ByteString.unpack (toolStdout result))

succeeds :: FilePath -> [String] -> IO Bool
succeeds executable arguments = toolSucceeded <$> runAbsolute executable arguments

runAbsolute :: FilePath -> [String] -> IO ToolResult
runAbsolute executable arguments = case mkAbsExe executable of
  Left problem -> fail ("linux-engine-non-absolute-executable:" <> show problem)
  Right path -> runTool path arguments

toolSucceeded :: ToolResult -> Bool
toolSucceeded result = toolExitCode result == ExitSuccess

requireSuccess :: String -> ToolResult -> IO ()
requireSuccess label result = unless (toolSucceeded result)
  (fail (label <> ":" <> show (toolExitCode result) <> ":" <> ByteString.unpack (toolStderr result)))

renderAction :: LedgerAction -> String
renderAction action = case action of
  Probe surface -> "probe\t" <> show surface
  Mutate mutation -> "mutation\t" <> show mutation

renderSurfaces :: LinuxEngineObservation -> String
renderSurfaces observed = unlines
  [ "EnginePackage\t" <> present (enginePackagePresent observed)
  , "DockerGroup\t" <> present (dockerGroupMember observed)
  , "DaemonSocket\t" <> present (daemonReachable observed)
  , "NativeImage\t" <> present (nativeImagePresent observed)
  ]
 where present True = "present"; present False = "absent"

imageReference :: String
imageReference = "amoebius-phase52-cpu-amd64:local"
