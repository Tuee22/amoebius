{-# LANGUAGE CPP #-}

module Main (main) where

import Amoebius.Host.LinuxEngine
import Control.Monad (unless)
import Data.List (isInfixOf)
import LinuxEngineBringupOracle
import System.Exit (die)

main :: IO ()
main = do
  let first = map show (planLinuxEnginePass pristineObservation)
      converged = LinuxEngineObservation True True True True
      second = map show (planLinuxEnginePass converged)
      dirtyPairs =
        [ (EnginePackage, pristineObservation {enginePackagePresent = True})
        , (DockerGroup, pristineObservation {dockerGroupMember = True})
        , (DaemonSocket, pristineObservation {daemonReachable = True})
        , (NativeImage, pristineObservation {nativeImagePresent = True})
        ]
      pristineAccepted = admitPristineGuest pristineObservation == Right ()
      dirtyRefused = and [admitPristineGuest value == Left (GuestNotPristine surface) | (surface, value) <- dirtyPairs]
      nativeAccepted = admitNativeBuild Amd64 Amd64 Amd64 == Right ()
      mismatchRefused = admitNativeBuild Arm64 Amd64 Amd64 == Left (ArchitectureMismatch Arm64 Amd64 Amd64)
      noElevation = not (any ("sudo" `isInfixOf`) daemonProbeArgv)
      problems =
        [label | (label, passed) <-
          [ ("first-pass-ledger", first == expectedFirstPass)
          , ("second-pass-ledger", second == expectedSecondPass)
          , ("pristine-positive", pristineAccepted)
          , ("dirty-paired-negatives", dirtyRefused)
          , ("native-positive", nativeAccepted)
          , ("architecture-negative", mismatchRefused)
          , ("unelevated-probe", noElevation && daemonProbeArgv == expectedDaemonProbe)
          , ("future-session", futureSessionArgv "amoebius" == expectedFutureSession)
          ], not passed]
  unless (null problems) (die (mutantToken <> "; differences=" <> show problems))
  putStrLn "linux-engine-bringup-spec: PASS (4 pristine surfaces, 5 mutations, 2 ledgers, 4 dirty negatives, 1 architecture negative, 2 unelevated probes)"

mutantToken :: String
#if defined(LINUX_ENGINE_EPHEMERAL_MEMBERSHIP_MUTANT)
mutantToken = "linux-engine-bringup-mutant: RED ephemeral-membership durable-group-read"
#elif defined(LINUX_ENGINE_UNREFRESHED_CREDENTIALS_MUTANT)
mutantToken = "linux-engine-bringup-mutant: RED unrefreshed-credentials current-process-read"
#elif defined(LINUX_ENGINE_ELEVATED_RETRY_MUTANT)
mutantToken = "linux-engine-bringup-mutant: RED elevated-retry unelevated-session-read"
#elif defined(LINUX_ENGINE_CONVERGE_WITHOUT_PROBE_MUTANT)
mutantToken = "linux-engine-bringup-mutant: RED converge-without-probe second-pass-probes"
#elif defined(LINUX_ENGINE_PLATFORM_OVERRIDE_MUTANT)
mutantToken = "linux-engine-bringup-mutant: RED platform-override native-architecture"
#else
mutantToken = "linux-engine-bringup-spec: RED unexpected"
#endif
