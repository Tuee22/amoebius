{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Host.Frame
import Amoebius.Host.Substrate
import Amoebius.HostComms.Illegal
import Amoebius.HostComms.Loopback
import Amoebius.HostComms.NodePort
import Amoebius.HostWorker.AppleMetalBuild
import Amoebius.HostWorker.Auth
import Amoebius.HostWorker.Capacity
import Amoebius.HostWorker.Lifecycle
import Amoebius.HostWorker.MetalBridge
import Amoebius.HostWorker.Peer
import Amoebius.HostWorker.ReferenceKernel
import Amoebius.HostWorker.Supervise
import Amoebius.Substrate.Brew (BrewEnsurePlan (..), closedSpawnEnvironment, planBrewEnsure)
import Amoebius.Substrate.Brew qualified as Brew
import Amoebius.Substrate.Lima
import Control.Exception (SomeException, throwIO, try)
import Control.Monad (forM_, unless)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Char (digitToInt)
import Data.IORef
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text qualified as Text
import Data.Word (Word64)
import System.Directory (doesFileExist, getCurrentDirectory, setCurrentDirectory)
import System.Exit (die)
import System.FilePath ((</>), takeDirectory)
import Text.Read (readMaybe)

gib :: Word64
gib = 1024 * 1024 * 1024

main :: IO ()
main = do
  projectRoot >>= setCurrentDirectory
  verifyPhase0
  verifyUniversalCpu
  verifyDiskAndCapacity
  verifyHostComms
  verifyReferenceAndBridge
  verifyBuild
  verifyLifecycle
  verifySupervisor
  verifyPeerAndAuth
  putStrLn "apple-metal-host-daemon-apple-host-contract: PASS (20 custody rows; disk/capacity fold; loopback-only peer; numerical challenge; build/lifecycle/supervisor/auth; universal linux-cpu and Incus/Lima/WSL2 routing)"

verifyPhase0 :: IO ()
verifyPhase0 = do
  rows <- lines <$> readFile "test/oracle/preimplementation_artifacts.tsv"
  let phaseRows = filter (Text.isInfixOf "phase_53" . Text.pack) rows
  assertEqual "Phase-0 row cardinality" 20 (length phaseRows)
  forM_ phaseRows $ \row -> case splitTabs row of
    (_phase : _kind : path : _) -> ByteString.readFile path >> pure ()
    _ -> die "malformed Phase-54 custody row"

verifyUniversalCpu :: IO ()
verifyUniversalCpu = forM_
  [ (LinuxCpu, Incus, NativeLinux)
  , (LinuxCuda, Incus, NativeLinux)
  , (Apple, Lima, LimaGuest)
  , (Windows, Wsl2, Wsl2Guest)
  ] $ \(substrate, provider, frame) -> do
    -- The retired `supportsLinuxCpu` returned True for every input, so it stated
    -- nothing its own type did not already state. The claim it was standing in for
    -- is that every substrate *reaches* a Linux frame, which `frameFor` answers.
    assertEqual "linux frame" frame (frameFor substrate)
    assertEqual "pristine Linux provider" provider (pristineLinuxProvider substrate)

verifyDiskAndCapacity :: IO ()
verifyDiskAndCapacity = do
  disk <- either (die . show) pure (provisionVmDisk rawDisk)
  assertEqual "VM identity unchanged" "amoebius-phase53" (provisionedVmDiskId disk)
  assertEqual "guest usable" (32 * gib) (requiredUsableBytes disk)
  assertEqual "raw provisioned" (40 * gib) (provisionedBytes disk)
  assertEqual "Lima argv"
    ["/opt/homebrew/bin/limactl", "create", "--name=amoebius-phase53", "--cpus=4", "--memory=8589934592", "--disk=42949672960"]
    (renderLimaCreateArgv "/opt/homebrew/bin/limactl" "amoebius-phase53" 4 (8 * gib) disk)
  plan <- either (die . show) pure (provisionAppleHost supply demand)
  assertEqual "Metal coexistence peak" (8 * gib) (provisionedMetalEpochPeak plan)
  assertEqual "host memory debit" (19 * gib) (provisionedHostMemoryDebit plan)
  assertEqual "host disk debit" (120 * gib) (provisionedHostDiskDebit plan)
  assertLeft "memory one short" HostMemoryShort (provisionAppleHost supply {supplyUnifiedMemoryBytes = 19 * gib - 1} demand)
  assertLeft "disk one short" HostDiskShort (provisionAppleHost supply {supplyDiskBytes = 120 * gib - 1} demand)
  assertLeft "cpu one short" HostCpuShort (provisionAppleHost supply {supplyCpuCores = 5} demand)
  let wrongKeys = (demandMetalOwner demand) {metalWorkloadBytes = Map.delete "jit" (metalWorkloadBytes (demandMetalOwner demand))}
  assertLeft "work item domain" MetalKeyDomainMismatch (provisionAppleHost supply demand {demandMetalOwner = wrongKeys})
  validateBoundaryOracle

rawDisk :: VmDiskCarve
rawDisk = VmDiskCarve
  { vmDiskId = "amoebius-phase53"
  , vmDiskPresentation = Filesystem "ext4"
  , vmDiskAllocation = BackingAllocationPolicy (40 * gib) (4 * gib) 500 (2 * gib)
  , vmGuestSystemUsableBytes = 8 * gib
  , vmKubeletUniqueCarves = Map.fromList [("ociContent", 12 * gib), ("snapshots", 8 * gib), ("workspace", 4 * gib)]
  }

supply :: AppleHostSupply
supply = AppleHostSupply Apple "arm64" 12 (24 * gib) (256 * gib) "apple-family-8"

demand :: AppleHostDemand
demand = AppleHostDemand 4 (8 * gib) (2 * gib) 2 (1 * gib) rawDisk (64 * gib) (16 * gib) metalDemand

metalDemand :: MetalOwnerDemand
metalDemand = MetalOwnerDemand
  "apple-family-8"
  (Map.fromList [("inference", 3 * gib), ("jit", 2 * gib), ("library", 1 * gib)])
  (Map.fromList [("inference", 3 * gib), ("jit", 2 * gib), ("library", 1 * gib)])
  (Map.fromList [("inference", 1), ("jit", 1), ("library", 1)])
  (Map.fromList [("inference", 1), ("jit", 1), ("library", 1)])
  [["library", "inference"], ["library", "jit"]]

validateBoundaryOracle :: IO ()
validateBoundaryOracle = do
  rows <- lines <$> readFile "test/golden/apple_metal_host_daemon/vm_disk_boundaries.csv"
  assertEqual "disk boundary rows" 4 (length rows)
  let oneMore = rawDisk
        { vmDiskAllocation = BackingAllocationPolicy 0 (4 * gib) 500 (2 * gib)
        , vmGuestSystemUsableBytes = vmGuestSystemUsableBytes rawDisk + 1
        }
  witness <- either (die . show) pure (provisionVmDisk oneMore)
  assertEqual "one byte crosses quantum" (36 * gib) (provisionedBytes witness)

verifyHostComms :: IO ()
verifyHostComms = do
  comms <- either (die . show) pure (provisionHostComms greenComms)
  assertEqual "exact services" (Set.fromList [ContentMutationGateway, Pulsar]) (provisionedServices comms)
  assert (loopbackTarget comms Pulsar 30080 /= Nothing) "Pulsar loopback target absent"
  assertLeft "LoadBalancer" NodePortRequired (provisionHostComms greenComms {hostServiceType = "LoadBalancer"})
  assertLeft "Envoy" EnvoyRouteForbidden (provisionHostComms greenComms {hostEnvoyRoute = True})
  assertLeft "wild listener" LoopbackRequired (provisionHostComms greenComms {hostBindAddress = "0.0.0.0"})
  assertLeft "daemon ingress" DaemonWildIngressForbidden (provisionHostComms greenComms {hostDaemonWildIngress = True})
  assertLeft "raw MinIO" RawMinioMutationEndpointForbidden (provisionHostComms greenComms {hostRawMinioNodePort = True})
  assertEqual "illegal tag inventory" 4 (length illegalHostCommsTags)

greenComms :: HostCommsSpec
greenComms = HostCommsSpec renderServiceType "127.0.0.1" False False False (Set.fromList [ContentMutationGateway, Pulsar])

verifyReferenceAndBridge :: IO ()
verifyReferenceAndBridge = do
  inputA <- parseFloats "test/golden/apple_metal_host_daemon/job_A.input"
  inputB <- parseFloats "test/golden/apple_metal_host_daemon/job_B.input"
  expectedA <- readExpected "test/golden/apple_metal_host_daemon/job_A.expected"
  expectedB <- readExpected "test/golden/apple_metal_host_daemon/job_B.expected"
  assertEqual "job A" expectedA (referenceKernel inputA)
  assertEqual "job B" expectedB (referenceKernel inputB)
  assert (expectedA /= expectedB) "constant result escaped"
  let challenge = [13.25, -2.75, 0.125, 4096.5]
  assertEqual "run-time challenge" (encodeFloat32Le [27.5, -4.5, 1.25, 8194]) (referenceKernel challenge)
  dispatch <- either (die . show) pure (dispatchMetal (AppleMetalDevice "MTLLibrary:phase53") inputA)
  assertEqual "bridge output" expectedA (dispatchBytes dispatch)
  assert (not (dispatchFastMath dispatch)) "fast math enabled"
  assertLeft "physical Metal honest on this host model" MetalUnavailable (dispatchMetal UnsupportedAppleMetalOnHost inputA)

verifyBuild :: IO ()
verifyBuild = do
  let envelope = BuildEnvelope 2 gib gib gib "BuildScratch" "MetalCache" 1
  plan <- either (die . show) pure (planAppleMetalBuild "/usr/bin/clang" "bridge.m" "bridge.dylib" envelope)
  assertEqual "absolute clang" "/usr/bin/clang" (head (buildArgv plan))
  assert (Map.null (buildEnvironment plan)) "build environment was not closed"
  assert (not (buildUsesVm plan || buildUsesSwiftPm plan || buildUnlocksKeychain plan)) "forbidden Apple build surface"
  assertLeft "bare clang" AbsoluteClangRequired (planAppleMetalBuild "clang" "bridge.m" "bridge.dylib" envelope)
  assertEqual "brew present" (Right (AlreadyPresent "/opt/homebrew/bin/limactl")) (planBrewEnsure "/opt/homebrew/bin/brew" (Just "/opt/homebrew/bin/limactl") Brew.Lima)
  assert (Map.null closedSpawnEnvironment) "tool environment was not closed"

verifyLifecycle :: IO ()
verifyLifecycle = do
  trace <- newIORef ([] :: [LifecycleStep])
  let mark step = modifyIORef' trace (<> [step])
      actions = WorkerActions
        (mark Load) (mark Prereq) (mark Acquire >> pure ()) (const (mark Ready))
        (const (mark Serve >> throwIO (userError "serve failed"))) (const (mark Drain)) (mark Exit)
  result <- try (runWorkerLifecycle actions) :: IO (Either SomeException ())
  assert (isLeft result) "Serve exception disappeared"
  assertEqual "drain on exception" [Load, Prereq, Acquire, Ready, Serve, Drain, Exit] =<< readIORef trace
  prereqTrace <- newIORef ([] :: [LifecycleStep])
  let prereqFail = WorkerActions
        (append prereqTrace Load) (append prereqTrace Prereq >> throwIO (userError "missing Metal bridge"))
        (append prereqTrace Acquire >> pure ()) (const (append prereqTrace Ready))
        (const (append prereqTrace Serve)) (const (append prereqTrace Drain)) (append prereqTrace Exit)
  _ <- try (runWorkerLifecycle prereqFail) :: IO (Either SomeException ())
  assertEqual "prerequisite pre-Serve" [Load, Prereq] =<< readIORef prereqTrace
 where
  append ref step = modifyIORef' ref (<> [step])
  isLeft (Left _) = True
  isLeft (Right _) = False

verifySupervisor :: IO ()
verifySupervisor = do
  let policy = SupervisorPolicy 100 2 1000 gib gib gib
      fit = SupervisorSample 1000 gib gib gib
      bad = SupervisorSample 1001 gib gib gib
  _ <- either (die . show) pure (validateSupervisor FiniteReactive policy)
  assertLeft "hard quota honesty" UnsupportedEnforcement (validateSupervisor InstantaneousHardQuota policy)
  assertEqual "finite breach" (TerminateAtSample 4) (evaluateSamples policy [bad, fit, bad, bad])

verifyPeerAndAuth :: IO ()
verifyPeerAndAuth = do
  comms <- either (die . show) pure (provisionHostComms greenComms)
  auth <- either (die . show) pure (resolveWorkerAuth
    (Map.fromList [("vault/pulsar", "p-token"), ("vault/gateway", "g-token")])
    (WorkerSecretNames "vault/pulsar" "vault/gateway" Nothing))
  assert (not (authUsesEnvironment auth || authHasRawMinioMutationCredential auth)) "auth boundary"
  peer <- either (die . show) pure (provisionPeer comms auth (PeerSpec 30080 30081 True False False False False))
  let rendered = renderGeneratedGateDhall peer
  assert ("127.0.0.1" `Text.isInfixOf` rendered && "native-tcp" `Text.isInfixOf` rendered) "generated peer gate"
  assertLeft "raw credential" RawMinioMutationCredentialForbidden
    (resolveWorkerAuth Map.empty (WorkerSecretNames "p" "g" (Just "minio-root")))

parseFloats :: FilePath -> IO [Float]
parseFloats path = do
  values <- words <$> readFile path
  traverse (maybe (die "invalid float fixture") pure . readMaybe) values

readExpected :: FilePath -> IO ByteString
readExpected path = do
  source <- filter (/= '\n') <$> readFile path
  if odd (length source) then die "odd hex fixture" else pure (ByteString.pack (pairs source))
 where
  pairs [] = []
  pairs (high : low : rest) = fromIntegral (digitToInt high * 16 + digitToInt low) : pairs rest
  pairs _ = error "unreachable"

splitTabs :: String -> [String]
splitTabs source = case break (== '\t') source of
  (field, []) -> [field]
  (field, _ : rest) -> field : splitTabs rest

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual = unless (expected == actual) (die (label <> ": expected " <> show expected <> ", got " <> show actual))

assertLeft :: (Eq err, Show err, Show value) => String -> err -> Either err value -> IO ()
assertLeft label expected actual = case actual of
  Left observed -> assertEqual label expected observed
  Right value -> die (label <> ": expected Left, got " <> show value)

projectRoot :: IO FilePath
projectRoot = getCurrentDirectory >>= ascend
 where
  ascend path = do
    present <- doesFileExist (path </> "cabal.project")
    if present then pure path else
      let parent = takeDirectory path
       in if parent == path then die "apple-metal-host-daemon-project-root-absent" else ascend parent
