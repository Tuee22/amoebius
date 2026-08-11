module Amoebius.Host.Ensure
  ( AbsExe
  , AbsExeError (..)
  , InstallStep (..)
  , HostConfig
  , EnsureError (..)
  , ToolResult (..)
  , mkAbsExe
  , absExePath
  , installPlan
  , renderInstallStep
  , initialHostConfig
  , lookupTool
  , installAndVerify
  , runTool
  , runToolWithStdin
  , mutantBareNamePath
  ) where

import Amoebius.Host.HostTool
import Amoebius.Host.Substrate
import Data.ByteString.Lazy (ByteString)
import Data.ByteString.Lazy qualified as ByteString
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Char (isAlpha)
import System.Directory (doesFileExist, executable, getHomeDirectory, getPermissions)
import System.Exit (ExitCode)
import System.FilePath (isAbsolute, (</>))
import System.Process.Typed (byteStringInput, proc, readProcess, setStdin)

newtype AbsExe = AbsExe {absExePath :: FilePath}
  deriving stock (Eq, Ord, Show)

data AbsExeError = NonAbsolutePath
  deriving stock (Eq, Ord, Show)

data InstallStep = InstallStep
  { installTool :: HostTool
  , installMechanism :: String
  }
  deriving stock (Eq, Ord, Show)

data HostConfig = HostConfig
  { hostSubstrate :: Substrate
  , hostTools :: Map HostTool AbsExe
  }
  deriving stock (Eq, Show)

data EnsureError
  = MissingToolAfterInstall HostTool
  | InstallFailed HostTool String
  deriving stock (Eq, Show)

data ToolResult = ToolResult
  { toolExitCode :: ExitCode
  , toolStdout :: ByteString
  , toolStderr :: ByteString
  }
  deriving stock (Eq, Show)

mkAbsExe :: FilePath -> Either AbsExeError AbsExe
mkAbsExe path
  | portableAbsolute path = Right (AbsExe path)
  | otherwise = Left NonAbsolutePath

portableAbsolute :: FilePath -> Bool
portableAbsolute path = isAbsolute path || windowsAbsolute path

windowsAbsolute :: FilePath -> Bool
windowsAbsolute (drive : ':' : slash : _) = isAlpha drive && slash `elem` ['/', '\\']
windowsAbsolute _ = False

installPlan :: Substrate -> [InstallStep]
installPlan substrate = case substrate of
  LinuxCpu -> linuxPlan
  LinuxCuda -> linuxPlan
  Apple ->
    [ step PackageManagerRoot "require:/opt/homebrew/bin/brew"
    , step Ghcup "brew-install:ghcup"
    , step Cabal "ghcup-install:3.16.1.0"
    , step Kubectl "brew-install:kubernetes-cli"
    , step Kind "brew-install:kind"
    ]
  Windows ->
    [ step PackageManagerRoot "require:C:/Program Files/WindowsApps/winget.exe"
    , step Ghcup "winget-install:ghcup"
    , step Cabal "ghcup-install:3.16.1.0"
    , step Kubectl "winget-install:Kubernetes.kubectl"
    , step Kind "winget-install:Kubernetes.kind"
    ]
 where
  linuxPlan =
    [ step PackageManagerRoot "require:/usr/bin/apt-get"
    , step Ghcup "python-download:ghcup"
    , step Cabal "ghcup-install:3.16.1.0"
    , step Kubectl "apt-install:kubectl"
    , step Kind "python-download:v0.32.0"
    ]
  step = InstallStep

renderInstallStep :: Substrate -> Int -> InstallStep -> String
renderInstallStep substrate ordinal installStep =
  renderSubstrate substrate <> "\t" <> show ordinal <> "\t"
    <> renderHostTool (installTool installStep) <> "\t" <> installMechanism installStep

initialHostConfig :: Substrate -> IO HostConfig
initialHostConfig substrate = do
  entries <- traverse probe [minBound .. maxBound]
  pure (HostConfig substrate (Map.fromList [entry | Just entry <- entries]))
 where
  probe tool = do
    resolved <- resolveTool substrate tool
    pure (fmap (\absolute -> (tool, absolute)) resolved)

lookupTool :: HostTool -> HostConfig -> Maybe AbsExe
lookupTool tool = Map.lookup tool . hostTools

-- | Probe first. If absent, execute the independently-selected install steps,
-- re-probing after every step and failing unless the requested tool resolves.
-- The installer is injected so tests can prove transition behaviour without
-- mutating the host; production callers keep all process creation in this module.
installAndVerify
  :: (InstallStep -> IO (Either EnsureError ()))
  -> HostConfig
  -> HostTool
  -> IO (Either EnsureError HostConfig)
installAndVerify installer config requested = case lookupTool requested config of
  Just _ -> pure (Right config)
  Nothing -> drive (installPlan (hostSubstrate config)) config
 where
  drive [] _ = pure (Left (MissingToolAfterInstall requested))
  drive (next : remaining) current = do
    outcome <- installer next
    case outcome of
      Left failure -> pure (Left failure)
      Right () -> do
        observed <- initialHostConfig (hostSubstrate current)
        case lookupTool requested observed of
          Just _ -> pure (Right observed)
          Nothing -> drive remaining observed

resolveTool :: Substrate -> HostTool -> IO (Maybe AbsExe)
resolveTool substrate tool = do
  home <- getHomeDirectory
  firstExecutable (candidates home substrate tool)

candidates :: FilePath -> Substrate -> HostTool -> [FilePath]
candidates home substrate tool = case (substrate, tool) of
  (LinuxCpu, PackageManagerRoot) -> ["/usr/bin/apt-get"]
  (LinuxCuda, PackageManagerRoot) -> ["/usr/bin/apt-get"]
  (LinuxCpu, Ghcup) -> [home </> ".ghcup/bin/ghcup", "/usr/local/bin/ghcup", "/usr/bin/ghcup"]
  (LinuxCuda, Ghcup) -> [home </> ".ghcup/bin/ghcup", "/usr/local/bin/ghcup", "/usr/bin/ghcup"]
  (LinuxCpu, Cabal) -> [home </> ".ghcup/bin/cabal", home </> ".ghcup/bin/cabal-3.16.1.0", "/usr/bin/cabal"]
  (LinuxCuda, Cabal) -> [home </> ".ghcup/bin/cabal", home </> ".ghcup/bin/cabal-3.16.1.0", "/usr/bin/cabal"]
  (LinuxCpu, Kubectl) -> [home </> ".local/bin/kubectl", "/usr/local/bin/kubectl", "/usr/bin/kubectl"]
  (LinuxCuda, Kubectl) -> [home </> ".local/bin/kubectl", "/usr/local/bin/kubectl", "/usr/bin/kubectl"]
  (LinuxCpu, Kind) -> ["/usr/local/bin/kind", home </> ".local/bin/kind"]
  (LinuxCuda, Kind) -> ["/usr/local/bin/kind", home </> ".local/bin/kind"]
  (Apple, PackageManagerRoot) -> ["/opt/homebrew/bin/brew"]
  (Apple, Ghcup) -> [home </> ".ghcup/bin/ghcup", "/opt/homebrew/bin/ghcup"]
  (Apple, Cabal) -> [home </> ".ghcup/bin/cabal", home </> ".ghcup/bin/cabal-3.16.1.0"]
  (Apple, Kubectl) -> ["/opt/homebrew/bin/kubectl"]
  (Apple, Kind) -> ["/opt/homebrew/bin/kind"]
  (Windows, PackageManagerRoot) -> ["C:/Program Files/WindowsApps/winget.exe"]
  (Windows, Ghcup) -> [home </> ".ghcup/bin/ghcup.exe"]
  (Windows, Cabal) -> [home </> ".ghcup/bin/cabal.exe"]
  (Windows, Kubectl) -> [home </> "bin/kubectl.exe"]
  (Windows, Kind) -> [home </> "bin/kind.exe"]

firstExecutable :: [FilePath] -> IO (Maybe AbsExe)
firstExecutable [] = pure Nothing
firstExecutable (candidate : rest) = do
  exists <- doesFileExist candidate
  runnable <- if exists then executable <$> getPermissions candidate else pure False
  if runnable then either (const (firstExecutable rest)) (pure . Just) (mkAbsExe candidate)
    else firstExecutable rest

runTool :: AbsExe -> [String] -> IO ToolResult
runTool executablePath arguments = runToolWithStdin executablePath arguments ByteString.empty

runToolWithStdin :: AbsExe -> [String] -> ByteString -> IO ToolResult
runToolWithStdin executablePath arguments stdinBytes = do
  (exitCode, stdoutBytes, stderrBytes) <-
    readProcess (setStdin (byteStringInput stdinBytes) (proc (absExePath executablePath) arguments))
  pure (ToolResult exitCode stdoutBytes stderrBytes)

-- | M2 artifact. It is deliberately only observable as a raw path and can
-- never reach 'runTool', whose argument constructor is opaque.
mutantBareNamePath :: FilePath
mutantBareNamePath = "kind"
