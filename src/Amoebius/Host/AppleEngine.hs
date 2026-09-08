{-# LANGUAGE CPP #-}

-- | The pure, typed Apple engine bring-up contract.
--
-- Live interpretation belongs to the Phase-53 supervisor.  This module makes
-- the decisions that must precede effects independently checkable: the
-- operator-owned floor, workload-sensitive provider, checked frame carve,
-- lifecycle, unchanged lifted Linux plan, and native arm64 admission.
module Amoebius.Host.AppleEngine
  ( ApplePrerequisite (..)
  , AppleFloorObservation (..)
  , AppleFloorError (..)
  , AppleWorkload (..)
  , AppleProvider (..)
  , FrameLifecycle (..)
  , FrameSupply (..)
  , FrameDemand (..)
  , AppleEngineError (..)
  , AppleEngineAction (..)
  , applePrerequisites
  , prerequisiteRemedy
  , admitAppleFloor
  , providerFor
  , providerBrewTool
  , lifecycleFor
  , admitFrameDemand
  , colimaStartArgv
  , colimaStatusArgv
  , colimaStopArgv
  , dockerArchitectureArgv
  , liftLinuxSteps
  , colimaSshArgv
  , admitNativeArm64
  , planAppleEngine
  ) where

import Amoebius.Host.Ensure (AbsExe, InstallStep, absExePath)
import Amoebius.Host.Frame (Frame (LimaGuest))
import Amoebius.Host.Lift (LiftContext (InFrame), liftPlan)
import Amoebius.Host.HostTool (HostTool)
import Amoebius.Host.Substrate (Substrate (..))
import Amoebius.Substrate.Brew (BrewTool)
import Amoebius.Substrate.Brew qualified as Brew
import Data.List (isPrefixOf)
import Data.Word (Word64)

data ApplePrerequisite
  = AppleSiliconMac
  | HomebrewRoot
  | XcodeCommandLineTools
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data AppleFloorObservation = AppleFloorObservation
  { appleOs :: String
  , appleArchitecture :: String
  , appleBrewPath :: Maybe FilePath
  , appleXcodePath :: Maybe FilePath
  }
  deriving stock (Eq, Ord, Show)

data AppleFloorError
  = AppleFloorMissing ApplePrerequisite String
  | AppleFloorPathNotAbsolute ApplePrerequisite FilePath
  deriving stock (Eq, Ord, Show)

data AppleWorkload
  = ContainerImageBuild
  | EphemeralContainerRun
  | PersistentContainerRuntime
  | DistributionGuest
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data AppleProvider = ColimaProvider | LimaProvider
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data FrameLifecycle = EphemeralFrame | PersistentFrame
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data FrameSupply = FrameSupply
  { suppliedCpuCores :: Word64
  , suppliedMemoryBytes :: Word64
  , suppliedDiskBytes :: Word64
  }
  deriving stock (Eq, Ord, Show)

data FrameDemand = FrameDemand
  { demandedCpuCores :: Word64
  , demandedMemoryBytes :: Word64
  , demandedDiskBytes :: Word64
  }
  deriving stock (Eq, Ord, Show)

data AppleEngineError
  = AppleHostRequired
  | FrameCpuOvercommit Word64 Word64
  | FrameMemoryOvercommit Word64 Word64
  | FrameDiskOvercommit Word64 Word64
  | FrameDemandEmpty
  | NativeArm64Mismatch String String String
  | EmulationForbidden
  | InvalidColimaLiftEnvelope [String]
  deriving stock (Eq, Ord, Show)

data AppleEngineAction
  = VerifyAppleFloor
  | ProbeProvider AppleProvider
  | EnsureProvider AppleProvider
  | StartFrame FrameDemand FrameLifecycle
  | ProbeContainerEndpoint
  | ExecuteLiftedLinuxStep [String]
  | BuildNativeArm64Image
  | RunNativeArm64Image
  | StopFrame
  deriving stock (Eq, Ord, Show)

applePrerequisites :: [ApplePrerequisite]
applePrerequisites = [minBound .. maxBound]

prerequisiteRemedy :: ApplePrerequisite -> String
prerequisiteRemedy prerequisite = case prerequisite of
  AppleSiliconMac -> "run phase 53 on physical Apple Silicon macOS"
  HomebrewRoot -> "install Homebrew from https://brew.sh and expose /opt/homebrew/bin/brew"
  XcodeCommandLineTools -> "run xcode-select --install"

admitAppleFloor :: AppleFloorObservation -> Either AppleFloorError ()
admitAppleFloor observed
  | appleOs observed /= "darwin" || appleArchitecture observed /= "arm64" = missing AppleSiliconMac
#ifdef APPLE_ENGINE_INSTALLS_FLOOR_MUTANT
  | appleBrewPath observed == Nothing = Right ()
#else
  | appleBrewPath observed == Nothing = missing HomebrewRoot
#endif
  | Just path <- appleBrewPath observed, not (absolute path) = Left (AppleFloorPathNotAbsolute HomebrewRoot path)
  | appleXcodePath observed == Nothing = missing XcodeCommandLineTools
  | Just path <- appleXcodePath observed, not (absolute path) = Left (AppleFloorPathNotAbsolute XcodeCommandLineTools path)
  | otherwise = Right ()
 where
  missing prerequisite = Left (AppleFloorMissing prerequisite (prerequisiteRemedy prerequisite))

providerFor :: Substrate -> AppleWorkload -> Either AppleEngineError AppleProvider
providerFor substrate workload
  | substrate /= Apple = Left AppleHostRequired
  | otherwise = Right (select workload)
 where
  select candidate = case candidate of
#ifdef APPLE_ENGINE_WRONG_PROVIDER_MUTANT
    ContainerImageBuild -> LimaProvider
#else
    ContainerImageBuild -> ColimaProvider
#endif
    EphemeralContainerRun -> ColimaProvider
    PersistentContainerRuntime -> ColimaProvider
    DistributionGuest -> LimaProvider

providerBrewTool :: AppleProvider -> BrewTool
providerBrewTool provider = case provider of
  ColimaProvider -> Brew.Colima
  LimaProvider -> Brew.Lima

lifecycleFor :: AppleWorkload -> FrameLifecycle
lifecycleFor workload = case workload of
  ContainerImageBuild -> EphemeralFrame
#ifdef APPLE_ENGINE_LEAKS_EPHEMERAL_MUTANT
  EphemeralContainerRun -> PersistentFrame
#else
  EphemeralContainerRun -> EphemeralFrame
#endif
  PersistentContainerRuntime -> PersistentFrame
  DistributionGuest -> PersistentFrame

admitFrameDemand :: FrameSupply -> FrameDemand -> Either AppleEngineError FrameDemand
admitFrameDemand supplied demanded
  | any (== 0) [demandedCpuCores demanded, demandedMemoryBytes demanded, demandedDiskBytes demanded] = Left FrameDemandEmpty
#ifdef APPLE_ENGINE_DEFAULT_FRAME_MUTANT
  | otherwise = Right (FrameDemand 2 (2 * gib) (20 * gib))
#else
  | demandedCpuCores demanded > suppliedCpuCores supplied = Left (FrameCpuOvercommit (demandedCpuCores demanded) (suppliedCpuCores supplied))
  | demandedMemoryBytes demanded > suppliedMemoryBytes supplied = Left (FrameMemoryOvercommit (demandedMemoryBytes demanded) (suppliedMemoryBytes supplied))
  | demandedDiskBytes demanded > suppliedDiskBytes supplied = Left (FrameDiskOvercommit (demandedDiskBytes demanded) (suppliedDiskBytes supplied))
  | otherwise = Right demanded
#endif

colimaStartArgv :: AbsExe -> String -> FrameDemand -> [String]
colimaStartArgv executable profile demanded =
  [ absExePath executable, "start", "--profile", profile
  , "--cpus", show (demandedCpuCores demanded)
  , "--memory", show (demandedMemoryBytes demanded `div` gib)
  , "--disk", show (demandedDiskBytes demanded `div` gib)
  , "--arch", "aarch64", "--runtime", "docker"
  , "--activate=false", "--binfmt=false", "--template=false", "--save-config=false"
  , "--kubernetes=false", "--ssh-agent=false", "--ssh-config=false"
  , "--mount", "none"
  ]

colimaStatusArgv :: AbsExe -> String -> [String]
colimaStatusArgv executable profile = [absExePath executable, "status", "--profile", profile, "--json"]

colimaStopArgv :: AbsExe -> String -> [String]
colimaStopArgv executable profile =
  [absExePath executable, "delete", "--force", "--data", "--profile", profile]

dockerArchitectureArgv :: AbsExe -> String -> [String]
dockerArchitectureArgv executable context =
  [absExePath executable, "--context", context, "version", "--format", "{{.Server.Arch}}"]

liftLinuxSteps
  :: AbsExe
  -> (HostTool -> Maybe String)
  -> [InstallStep]
  -> Either String [[String]]
liftLinuxSteps entry versions steps =
#ifdef APPLE_ENGINE_REAUTHORS_LIFT_MUTANT
  Right [["/usr/bin/apt-get", "install", "-y", "docker.io"]]
#else
  either (Left . show) Right (liftPlan (InFrame LimaGuest entry) (const Nothing) versions steps)
#endif

-- | Bind the generic Phase-51 frame prefix to Colima's concrete SSH protocol.
-- The nested tail is preserved byte-for-byte; only the provider-owned envelope is
-- introduced here.
colimaSshArgv :: AbsExe -> String -> [String] -> Either AppleEngineError [String]
colimaSshArgv executable profile lifted = case lifted of
  entry : "--" : nested@(_ : _)
    | entry == absExePath executable ->
        Right (entry : "ssh" : "--profile" : profile : "--" : nested)
  _ -> Left (InvalidColimaLiftEnvelope lifted)

admitNativeArm64 :: String -> String -> String -> Bool -> Either AppleEngineError ()
#ifdef APPLE_ENGINE_ALLOWS_EMULATION_MUTANT
admitNativeArm64 _ _ _ _ = Right ()
#else
admitNativeArm64 host frame engine emulated
  | emulated = Left EmulationForbidden
  | host == "arm64" && frame `elem` ["arm64", "aarch64"] && engine `elem` ["arm64", "aarch64"] = Right ()
  | otherwise = Left (NativeArm64Mismatch host frame engine)
#endif

planAppleEngine
  :: FrameSupply
  -> FrameDemand
  -> AppleWorkload
  -> [[String]]
  -> Either AppleEngineError [AppleEngineAction]
planAppleEngine supplied demanded workload lifted = do
  admitted <- admitFrameDemand supplied demanded
  provider <- providerFor Apple workload
  let lifecycle = lifecycleFor workload
      endpoint = [ProbeContainerEndpoint | provider == ColimaProvider]
      image = if workload == ContainerImageBuild then [BuildNativeArm64Image, RunNativeArm64Image] else []
      teardown = [StopFrame | lifecycle == EphemeralFrame]
  pure ([VerifyAppleFloor, ProbeProvider provider, EnsureProvider provider, StartFrame admitted lifecycle]
    <> endpoint <> map ExecuteLiftedLinuxStep lifted <> image <> teardown)

absolute :: FilePath -> Bool
absolute path = "/" `isPrefixOf` path

gib :: Word64
gib = 1024 * 1024 * 1024
