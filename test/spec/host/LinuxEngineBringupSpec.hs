

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
      architectureRows =
        [ ((show requested, show guest, show engine), admitNativeBuild requested guest engine == Right ())
        | requested <- [minBound .. maxBound] :: [NativeArchitecture]
        , guest <- [minBound .. maxBound] :: [NativeArchitecture]
        , engine <- [minBound .. maxBound] :: [NativeArchitecture]
        ]
      noElevation = not (any ("sudo" `isInfixOf`) daemonProbeArgv)
      unelevatedClient =
        dockerClientArgv ["build"] == expectedDockerBuildClient
          && take 4 (unelevatedArgv daemonProbeArgv) == expectedUnelevatedPrefix
          && guestDockerUser == "ubuntu"
      problems =
        [label | (label, passed) <-
          [ ("first-pass-ledger", first == expectedFirstPass)
          , ("second-pass-ledger", second == expectedSecondPass)
          , ("pristine-positive", pristineAccepted)
          , ("dirty-paired-negatives", dirtyRefused)
          , ("native-positive", nativeAccepted)
          , ("architecture-negative", mismatchRefused)
          , ("architecture-table", architectureRows == architectureCases)
          , ("unelevated-probe", noElevation && daemonProbeArgv == expectedDaemonProbe)
          , ("future-session", futureSessionArgv "amoebius" == expectedFutureSession)
          , ("unelevated-client", unelevatedClient)
          , ("image-reference", imageReference == expectedImageReference)
          ], not passed]
  unless (null problems) (die (mutantToken <> "; differences=" <> show problems))
  putStrLn "linux-engine-bringup-spec: PASS (4 pristine surfaces, 5 mutations, 2 ledgers, 4 dirty negatives, 1 architecture negative, 8 architecture triples, 2 unelevated probes, 1 unelevated client, 1 image reference)"

mutantToken :: String
mutantToken = "linux-engine-bringup-spec: RED unexpected"
