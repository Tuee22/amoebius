{-# LANGUAGE CPP #-}

-- | The ensure algebra: what a step /is/, how a tool is resolved, and the driver.
--
-- The four-step contract of "substrate_doctrine.md" §3 is probe, install if absent,
-- resolve the absolute path from the provider, invoke by it. Three things here are
-- what make that contract hold rather than merely describe it.
--
-- * __An install step is data, not a label.__ It was @installMechanism :: String@,
--   which is exactly the shape that compiles while naming a mechanism no interpreter
--   implements. A step is now the tool that performs it and the argument vector it
--   performs it with.
-- * __A bare command name is unrepresentable as a resolved tool.__ 'AbsExe' has a
--   constructor that is not exported; the only way to build one is 'mkAbsExe', which
--   rejects any non-absolute path. So an invocation target is, by type, absolute.
-- * __The probe is the post-condition.__ The driver re-resolves after every step and
--   verifies with the same predicate it probed with, because a driver that probes one
--   property and verifies another reports a convergence nothing established.
module Amoebius.Host.Ensure
  ( -- * Resolved tools
    AbsExe
  , AbsExeError (..)
  , mkAbsExe
  , absExePath
    -- * Steps as data
  , Argument (..)
  , Performer (..)
  , InstallStep (..)
  , renderArgument
  , stepArgv
    -- * Resolution
  , HostConfig (..)
  , initialHostConfig
  , initialHostConfigAt
  , resolveTool
  , resolveToolAt
  , lookupTool
  , candidates
    -- * The driver
  , EnsureError (..)
  , renderEnsureError
  , installAndVerify
    -- * Invocation
  , ToolResult (..)
  , runTool
  , runToolWithStdin
  ) where

import Amoebius.Host.HostTool
import Amoebius.Host.Substrate
import Data.ByteString.Lazy (ByteString)
import Data.ByteString.Lazy qualified as ByteString
import Data.Char (isAlpha)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import System.Directory (doesFileExist, executable, getHomeDirectory, getPermissions)
import System.Exit (ExitCode)
import System.FilePath (isAbsolute, (</>))
import System.Process.Typed (byteStringInput, proc, readProcess, setStdin)

-- ---------------------------------------------------------------------------
-- resolved tools
-- ---------------------------------------------------------------------------

-- | An executable known to be addressed by absolute path. The constructor is not
-- exported, so this invariant cannot be bypassed.
newtype AbsExe = AbsExe {absExePath :: FilePath}
  deriving stock (Eq, Ord, Show)

data AbsExeError = NonAbsolutePath
  deriving stock (Eq, Ord, Show)

mkAbsExe :: FilePath -> Either AbsExeError AbsExe
mkAbsExe path
  | portableAbsolute path = Right (AbsExe path)
  | otherwise = Left NonAbsolutePath

-- | Absolute on POSIX, or a Windows drive-qualified path. Both substrates are in the
-- catalogue, so a POSIX-only predicate would refuse every legitimate Windows tool.
portableAbsolute :: FilePath -> Bool
portableAbsolute path = isAbsolute path || windowsAbsolute path

windowsAbsolute :: FilePath -> Bool
windowsAbsolute (drive : ':' : slash : _) = isAlpha drive && slash `elem` ['/', '\\']
windowsAbsolute _ = False

-- ---------------------------------------------------------------------------
-- steps as data
-- ---------------------------------------------------------------------------

-- | One argument of an install step.
--
-- A version is 'RequirementVersion' rather than a literal, so the pin has exactly one
-- home — the authored requirements — and a bump touches one file instead of every
-- plan that happened to spell the number.
data Argument
  = Literal String
  | RequirementVersion HostTool
  deriving stock (Eq, Ord, Show)

-- | Who performs a step.
data Performer
  = -- | Nothing performs it: the step asserts a floor member is already present.
    -- The package-manager root is the only such member, because it cannot be
    -- installed through a resolved tool.
    VerifiedOnly
  | PerformedBy HostTool
  deriving stock (Eq, Ord, Show)

-- | A step: what it lays down, what performs it, and with which arguments.
data InstallStep = InstallStep
  { stepProvides :: HostTool
  , stepPerformer :: Performer
  , stepArguments :: [Argument]
  }
  deriving stock (Eq, Ord, Show)

-- | An argument rendered for a plan record. A requirement renders as its placeholder
-- rather than as a number, so a rendered plan is stable across a version bump — which
-- is what lets the plan be compared against an authored oracle at all.
renderArgument :: Argument -> String
renderArgument argument = case argument of
  Literal value -> value
  RequirementVersion tool -> "$(" <> renderHostTool tool <> ")"

-- | The argv a step issues, given a resolution for every requirement it names.
--
-- 'VerifiedOnly' issues none: it is an assertion about the host, not a command.
stepArgv :: (HostTool -> Maybe String) -> InstallStep -> Either EnsureError [String]
stepArgv resolveVersion step = traverse render (stepArguments step)
 where
  render argument = case argument of
    Literal value -> Right value
    RequirementVersion tool -> case resolveVersion tool of
      Just version -> Right version
      Nothing -> Left (UnresolvedRequirement tool)

-- ---------------------------------------------------------------------------
-- resolution
-- ---------------------------------------------------------------------------

data HostConfig = HostConfig
  { hostSubstrate :: Substrate
  , hostTools :: Map HostTool AbsExe
  }
  deriving stock (Eq, Show)

data EnsureError
  = -- | The plan was exhausted and the requested tool still does not resolve.
    MissingToolAfterInstall HostTool
  | InstallFailed HostTool String
  | -- | A step names a requirement the authored manifest does not carry.
    UnresolvedRequirement HostTool
  | -- | A reconciler was driven on a substrate its row excludes.
    NotApplicable String Substrate
  deriving stock (Eq, Show)

renderEnsureError :: EnsureError -> String
renderEnsureError problem = case problem of
  MissingToolAfterInstall tool -> "missing-tool-after-install:" <> renderHostTool tool
  InstallFailed tool detail -> "install-failed:" <> renderHostTool tool <> ":" <> detail
  UnresolvedRequirement tool -> "unresolved-requirement:" <> renderHostTool tool
  NotApplicable name substrate -> "not-applicable:" <> name <> ":" <> renderSubstrate substrate

-- | The one resolver. It is the executable-bit predicate, and it is the only one:
-- two predicates over one tool set answer differently on the same host, which is
-- how a tool came to be simultaneously present and absent.
resolveTool :: Substrate -> HostTool -> IO (Maybe AbsExe)
resolveTool substrate tool = do
  home <- getHomeDirectory
  resolveToolAt home substrate tool

-- | The same resolver, against an explicit home.
--
-- This is what makes the ensure algebra checkable without a host: a committed fake
-- tool directory is handed in as the home, and every candidate below it resolves by
-- absolute path exactly as it would on a machine. It is the /same/ predicate --
-- a second one would answer differently on the same input, which is the defect the
-- retired existence-only helper was.
resolveToolAt :: FilePath -> Substrate -> HostTool -> IO (Maybe AbsExe)
resolveToolAt home substrate tool = firstExecutable (candidates home substrate tool)

initialHostConfig :: Substrate -> IO HostConfig
initialHostConfig substrate = getHomeDirectory >>= \home -> initialHostConfigAt home substrate

initialHostConfigAt :: FilePath -> Substrate -> IO HostConfig
initialHostConfigAt home substrate = do
  entries <- traverse probe [minBound .. maxBound]
  pure (HostConfig substrate (Map.fromList [entry | Just entry <- entries]))
 where
  probe tool = fmap (fmap (tool,)) (resolveToolAt home substrate tool)

lookupTool :: HostTool -> HostConfig -> Maybe AbsExe
lookupTool tool = Map.lookup tool . hostTools

-- | Where each tool lands, by substrate. Total over both arguments and wildcard-free,
-- so a new substrate or a new tool is a compile error here rather than a silent
-- @Nothing@ at run time.
candidates :: FilePath -> Substrate -> HostTool -> [FilePath]
candidates home substrate tool = case substrate of
  LinuxCpu -> linux
  LinuxCuda -> linux
  Apple -> apple
  Windows -> windows
 where
  linux = case tool of
    PackageManagerRoot -> ["/usr/bin/apt-get"]
    Ghcup -> [home </> ".ghcup/bin/ghcup", "/usr/local/bin/ghcup", "/usr/bin/ghcup"]
    Cabal -> [home </> ".ghcup/bin/cabal", "/usr/bin/cabal"]
    Docker -> [home </> ".local/bin/docker", "/usr/bin/docker", "/usr/local/bin/docker"]
    Kubectl -> [home </> ".local/bin/kubectl", "/usr/local/bin/kubectl", "/usr/bin/kubectl"]
    Kind -> [home </> ".local/bin/kind", "/usr/local/bin/kind"]
  apple = case tool of
    PackageManagerRoot -> ["/opt/homebrew/bin/brew"]
    Ghcup -> [home </> ".ghcup/bin/ghcup", "/opt/homebrew/bin/ghcup"]
    Cabal -> [home </> ".ghcup/bin/cabal"]
    Docker -> [home </> ".local/bin/docker", "/opt/homebrew/bin/docker"]
    Kubectl -> [home </> ".local/bin/kubectl", "/opt/homebrew/bin/kubectl"]
    Kind -> [home </> ".local/bin/kind", "/opt/homebrew/bin/kind"]
  windows = case tool of
    PackageManagerRoot -> ["C:/Windows/System32/winget.exe"]
    Ghcup -> [home </> ".ghcup/bin/ghcup.exe"]
    Cabal -> [home </> ".ghcup/bin/cabal.exe"]
    Docker -> [home </> "bin/docker.exe", "C:/Program Files/Docker/Docker/resources/bin/docker.exe"]
    Kubectl -> [home </> "bin/kubectl.exe"]
    Kind -> [home </> "bin/kind.exe"]

firstExecutable :: [FilePath] -> IO (Maybe AbsExe)
firstExecutable [] = pure Nothing
firstExecutable (candidate : rest) = do
  exists <- doesFileExist candidate
  runnable <- if exists then executable <$> getPermissions candidate else pure False
  if runnable
    then either (const (firstExecutable rest)) (pure . Just) (mkAbsExe candidate)
    else firstExecutable rest

-- ---------------------------------------------------------------------------
-- the driver
-- ---------------------------------------------------------------------------

-- | Probe first; if absent, execute the plan, __re-resolving after every step__, and
-- verify with the predicate the probe used.
--
-- The re-resolve is not defensive: a tool a step laid down is absent from the config
-- snapshot that step began with, so without it the next step reads a stale answer and
-- reports a freshly-installed tool missing.
--
-- The installer is injected so a suite can prove transition behaviour without
-- mutating a host; every production caller keeps process creation in this module.
installAndVerify
  :: (Substrate -> IO HostConfig)
  -> (InstallStep -> IO (Either EnsureError ()))
  -> [InstallStep]
  -> HostConfig
  -> HostTool
  -> IO (Either EnsureError HostConfig)
#ifdef HOST_ENSURE_CONVERGED_WITHOUT_PROBING_MUTANT
installAndVerify _reresolve _installer _plan config _requested = pure (Right config)
 where
  _unusedDrive :: ()
  _unusedDrive = ()
#else
installAndVerify reresolve installer plan config requested = case lookupTool requested config of
  Just _ -> pure (Right config)
  Nothing -> drive plan config
 where
  drive [] _ = pure (Left (MissingToolAfterInstall requested))
  drive (next : remaining) current = do
    outcome <- installer next
    case outcome of
      Left failure -> pure (Left failure)
      Right () -> do
#ifdef HOST_ENSURE_STALE_SNAPSHOT_MUTANT
        let observed = current
#else
        observed <- reresolve (hostSubstrate current)
#endif
        case lookupTool requested observed of
          Just _ -> pure (Right observed)
          Nothing -> drive remaining observed
#endif

-- ---------------------------------------------------------------------------
-- invocation
-- ---------------------------------------------------------------------------

data ToolResult = ToolResult
  { toolExitCode :: ExitCode
  , toolStdout :: ByteString
  , toolStderr :: ByteString
  }
  deriving stock (Eq, Show)

runTool :: AbsExe -> [String] -> IO ToolResult
runTool executablePath arguments = runToolWithStdin executablePath arguments ByteString.empty

runToolWithStdin :: AbsExe -> [String] -> ByteString -> IO ToolResult
runToolWithStdin executablePath arguments stdinBytes = do
  (exitCode, stdoutBytes, stderrBytes) <-
    readProcess (setStdin (byteStringInput stdinBytes) (proc (absExePath executablePath) arguments))
  pure (ToolResult exitCode stdoutBytes stderrBytes)
