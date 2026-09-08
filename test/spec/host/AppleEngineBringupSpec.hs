{-# LANGUAGE CPP #-}

module Main (main) where

import Amoebius.Host.AppleEngine
import Amoebius.Host.Ensure
import Amoebius.Host.HostTool
import Amoebius.Host.Reconciler (installPlan)
import Amoebius.Host.Substrate (Substrate (..))
import Amoebius.Substrate.Brew (BrewTool (DockerClient), planBrewEnsure)
import AppleEngineBringupOracle
import Control.Monad (unless)
import Data.Word (Word64)
import System.Exit (die)

gib :: Word64
gib = 1024 * 1024 * 1024

main :: IO ()
main = do
  colima <- either (die . show) pure (mkAbsExe "/opt/homebrew/bin/colima")
  docker <- either (die . show) pure (mkAbsExe "/opt/homebrew/bin/docker")
  let greenFloor = AppleFloorObservation "darwin" "arm64" (Just "/opt/homebrew/bin/brew") (Just "/Library/Developer/CommandLineTools")
      workloads = [minBound .. maxBound]
      providers = map (show . providerFor Apple) workloads
      lifecycles = map (show . lifecycleFor) workloads
      brewEnsurePlans =
        [ show (planBrewEnsure "/opt/homebrew/bin/brew" Nothing (providerBrewTool ColimaProvider))
        , show (planBrewEnsure "/opt/homebrew/bin/brew" Nothing (providerBrewTool LimaProvider))
        , show (planBrewEnsure "/opt/homebrew/bin/brew" Nothing DockerClient)
        ]
      supply = FrameSupply 8 (16 * gib) (100 * gib)
      demand = FrameDemand 4 (8 * gib) (40 * gib)
      linuxStep = InstallStep DiskObserver (PerformedBy DiskObserver) [Literal "-kP", Literal "/"]
      liftedPlan = liftLinuxSteps colima requirementVersion (installPlan LinuxCpu)
      colimaLiftedPlan = liftedPlan >>= traverse (either (Left . show) Right . colimaSshArgv colima "amoebius-phase53-oracle")
      liftedStep = liftLinuxSteps colima requirementVersion [linuxStep]
      colimaLiftedStep = liftedStep >>= \rows -> case rows of
        [row] -> either (Left . show) Right (colimaSshArgv colima "amoebius-phase53-oracle" row)
        _ -> Left "unexpected lifted-row count"
      planned = planAppleEngine supply demand ContainerImageBuild (either (const []) id liftedPlan)
      problems = [label | (label, ok) <-
        [ ("floor-positive", admitAppleFloor greenFloor == Right ())
        , ("floor-platform-negative", admitAppleFloor greenFloor {appleOs = "linux"} == Left (AppleFloorMissing AppleSiliconMac "run phase 53 on physical Apple Silicon macOS"))
        , ("floor-homebrew-negative", admitAppleFloor greenFloor {appleBrewPath = Nothing} == Left (AppleFloorMissing HomebrewRoot "install Homebrew from https://brew.sh and expose /opt/homebrew/bin/brew"))
        , ("floor-xcode-negative", admitAppleFloor greenFloor {appleXcodePath = Nothing} == Left (AppleFloorMissing XcodeCommandLineTools "run xcode-select --install"))
        , ("prerequisite-domain", applePrerequisites == [AppleSiliconMac, HomebrewRoot, XcodeCommandLineTools])
        , ("provider-table", providers == expectedProviders)
        , ("provider-shared-brew-ensure", brewEnsurePlans == expectedBrewEnsurePlans)
        , ("provider-non-apple", providerFor LinuxCpu ContainerImageBuild == Left AppleHostRequired)
        , ("bare-executable-negative", mkAbsExe "colima" == Left NonAbsolutePath)
        , ("bare-brew-negative", planBrewEnsure "brew" Nothing (providerBrewTool ColimaProvider) == Left "brew-path-must-be-absolute")
        , ("relative-provider-negative", planBrewEnsure "/opt/homebrew/bin/brew" (Just "bin/colima") (providerBrewTool ColimaProvider) == Left "resolved-tool-path-must-be-absolute")
        , ("lifecycle-table", lifecycles == expectedLifecycles)
        , ("frame-fit", admitFrameDemand supply demand == Right demand)
        , ("cpu-negative", admitFrameDemand supply {suppliedCpuCores = 3} demand == Left (FrameCpuOvercommit 4 3))
        , ("memory-negative", admitFrameDemand supply {suppliedMemoryBytes = 8 * gib - 1} demand == Left (FrameMemoryOvercommit (8 * gib) (8 * gib - 1)))
        , ("disk-negative", admitFrameDemand supply {suppliedDiskBytes = 40 * gib - 1} demand == Left (FrameDiskOvercommit (40 * gib) (40 * gib - 1)))
        , ("colima-carve-argv", colimaStartArgv colima "amoebius-phase53-oracle" demand == expectedColimaStart)
        , ("colima-owned-data-teardown", colimaStopArgv colima "amoebius-phase53-oracle" == expectedColimaStop)
        , ("docker-context-argv", dockerArchitectureArgv docker "colima-amoebius-phase53-oracle" == expectedDockerArchitecture)
        , ("complete-lifted-linux-plan", liftedPlan == Right expectedLiftedPlan)
        , ("complete-colima-lift-envelope", colimaLiftedPlan == Right expectedColimaLiftedPlan)
        , ("live-challenge-step-shape", liftedStep == Right expectedLiftedStep)
        , ("live-challenge-colima-envelope", colimaLiftedStep == Right expectedColimaLiftedStep)
        , ("colima-lift-envelope-negative", case colimaSshArgv colima "amoebius-phase53-oracle" ["colima", "--", "df"] of Left (InvalidColimaLiftEnvelope _) -> True; _ -> False)
        , ("native-arm64", admitNativeArm64 "arm64" "aarch64" "arm64" False == Right ())
        , ("architecture-negative", admitNativeArm64 "arm64" "amd64" "amd64" False == Left (NativeArm64Mismatch "arm64" "amd64" "amd64"))
        , ("emulation-negative", admitNativeArm64 "arm64" "arm64" "arm64" True == Left EmulationForbidden)
        , ("complete-plan-actions", case planned of
              Right actions -> length [() | ExecuteLiftedLinuxStep _ <- actions] == length expectedLiftedPlan
              Left _ -> False)
        , ("ephemeral-teardown", case planned of Right actions -> last actions == StopFrame; Left _ -> False)
        ], not ok]
  unless (null problems) $ case lookup mutantToken expectedMutantFailures of
    Just expected | problems == expected -> die mutantToken
    _ -> die ("apple-engine-bringup-spec: RED unassigned differences=" <> show problems)
  unless (mutantToken == "apple-engine-bringup-spec: RED unexpected")
    (die "apple-engine-bringup-spec: RED selected mutant survived")
  putStrLn "apple-engine-bringup-spec: PASS (3 floor negatives, 3 brew ensure rows, 3 path negatives, 4 provider rows, 4 lifecycle rows, 3 fit negatives, complete unchanged lift, native arm64, ephemeral teardown)"

mutantToken :: String
#if defined(APPLE_ENGINE_INSTALLS_FLOOR_MUTANT)
mutantToken = "apple-engine-bringup-mutant: RED installs-floor homebrew-refusal"
#elif defined(APPLE_ENGINE_WRONG_PROVIDER_MUTANT)
mutantToken = "apple-engine-bringup-mutant: RED wrong-provider image-build-selection"
#elif defined(APPLE_ENGINE_LEAKS_EPHEMERAL_MUTANT)
mutantToken = "apple-engine-bringup-mutant: RED leaks-ephemeral lifecycle"
#elif defined(APPLE_ENGINE_DEFAULT_FRAME_MUTANT)
mutantToken = "apple-engine-bringup-mutant: RED default-frame checked-carve"
#elif defined(APPLE_ENGINE_REAUTHORS_LIFT_MUTANT)
mutantToken = "apple-engine-bringup-mutant: RED reauthors-lift unchanged-linux-step"
#elif defined(APPLE_ENGINE_ALLOWS_EMULATION_MUTANT)
mutantToken = "apple-engine-bringup-mutant: RED allows-emulation native-arm64"
#else
mutantToken = "apple-engine-bringup-spec: RED unexpected"
#endif
