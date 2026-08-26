{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Host.Frame
import Amoebius.Host.Substrate
import Amoebius.Host.Ensure
import Amoebius.Host.Reconciler
import Amoebius.Host.HostTool
import Amoebius.Host.Context
import Amoebius.Cluster.Kind
import Amoebius.Cluster.Inventory
import Amoebius.Capacity.Etcd
import Control.Monad (forM_, unless)
import Data.List (intercalate, tails)
import Data.Map.Strict qualified as Map
import Text.Read (readMaybe)
import System.Exit (die)

data Row = Row OsName RawArch Gpu String

main :: IO ()
main = do
  rows <- readRows "test/fixture/bootstrap_coordinator/substrate_decision.tsv"
  unless (length rows == 18) (die "Phase-24 substrate oracle must have 18 cells")
  forM_ rows $ \(Row os arch gpu expected) ->
    assertEqual (show (os, arch, gpu)) expected (renderClassification (classify os arch gpu))
  let mutantFailures =
        [ ()
        | Row os arch gpu expected <- rows
        , renderClassification (classifyMutantDropGpuPromotion os arch gpu) /= expected
        ]
  unless (length mutantFailures == 2) (die "M1 must be caught by exactly the two Linux+GPU cells")
  verifyUniversalLinuxCpu
  verifyHostTools
  verifyEngineAdmission
  verifyReconciler
  verifyInventoryCrossCheck
  verifyEtcdTransitionModel
  observed <- detect
  putStrLn ("phase24-host-detect: " <> renderClassification observed)
  putStrLn "bootstrap-coordinator-host-spec: PASS (18 decisions, 4 universal linux-cpu routes, 20 install rows, 9 AbsExe rows, 4 admissions, 4 reconciles, 8 inventory axes, etcd transition geometry, model mutation checks; live mutation rows are sealed by tools/bootstrap_coordinator_gate.py)"

verifyUniversalLinuxCpu :: IO ()
verifyUniversalLinuxCpu = do
  let expected =
        [ (LinuxCpu, "incus")
        , (LinuxCuda, "incus")
        , (Apple, "lima")
        , (Windows, "wsl2")
        ]
  forM_ expected $ \(substrate, provider) -> do
    -- `supportsLinuxCpu` returned True for every input and so stated nothing. The
    -- lane claim it stood in for is that every substrate reaches a Linux frame.
    unless (frameFor substrate `elem` [minBound .. maxBound])
      (die (renderSubstrate substrate <> " reaches no Linux frame"))
    assertEqual
      (renderSubstrate substrate <> " pristine Linux provider")
      provider
      (renderPristineLinuxProvider (pristineLinuxProvider substrate))

verifyHostTools :: IO ()
verifyHostTools = do
  let tools = [minBound .. maxBound] :: [HostTool]
  assertEqual "closed HostTool enum"
    ["package-manager-root", "ghcup", "cabal", "kubectl", "kind"]
    (map renderHostTool tools)
  planOracle <- readFile "test/fixture/bootstrap_coordinator/install_plans.tsv"
  let actualPlans =
        [ renderInstallStep substrate ordinal installStep
        | substrate <- [minBound .. maxBound]
        , (ordinal, installStep) <- zip [1 ..] (installPlan substrate)
        ]
  assertEqual "install plans" (drop 1 (lines planOracle)) actualPlans
  absOracle <- readFile "test/fixture/bootstrap_coordinator/abs_exe_cases.tsv"
  let cases = map splitTabs (drop 1 (lines absOracle))
  forM_ cases $ \fields -> case fields of
    [path, expected] -> assertEqual ("AbsExe " <> show path) expected (absOutcome path)
    _ -> die "malformed AbsExe oracle"
  let generated = take 100 (cycle ["kind", "bin/kubectl", "/usr/bin/kubectl", "C:/bin/kind.exe"])
      rejected = length [() | Left NonAbsolutePath <- map mkAbsExe generated]
      accepted = length generated - rejected
  unless (rejected >= 20 && accepted >= 20) (die "AbsExe generator did not cover both branches by 20%")
  unless (mutantBareNamePath == "kind") (die "M2 artifact disappeared")

absOutcome :: FilePath -> String
absOutcome path = case mkAbsExe path of
  Left NonAbsolutePath -> "left:non-absolute-path"
  Right _ -> "right"

verifyEngineAdmission :: IO ()
verifyEngineAdmission = do
  rows <- lines <$> readFile "test/fixture/bootstrap_coordinator/engine_admission.tsv"
  unless (length rows == 5) (die "engine admission oracle must retain four cases")
  forM_ (drop 1 rows) $ \source -> case splitTabs source of
    [label, cpu, memory, disk, availableCpu, availableMemory, availableDisk, expected] -> do
      let demand = KindEngineDemand (number cpu) (number memory) (number disk)
          observed = HostObservation (number availableCpu) (number availableMemory) (number availableDisk) "stable"
      outcome <- admitKindCreate demand observed
      assertEqual label expected (either (("left:" <>) . renderHostAdmissionError) (const "right") outcome)
      case outcome of
        Right token -> do
          first <- consumeKindCreate token observed
          assertEqual "single-use first consume" (Right ()) first
          second <- consumeKindCreate token observed
          assertEqual "single-use second consume" (Left KindCreateTokenAlreadyConsumed) second
        Left _ -> pure ()
    _ -> die "malformed engine admission row"
 where
  number value = maybe (error "invalid numeric oracle") id (readMaybe value)

verifyReconciler :: IO ()
verifyReconciler = do
  rows <- lines <$> readFile "test/fixture/bootstrap_coordinator/divergent_starts.tsv"
  unless (length rows == 5) (die "divergent-start oracle must retain four cases")
  forM_ (drop 1 rows) $ \source -> case splitTabs source of
    [label, exists, state, nodeEnvelope, kubeletEnvelope, addonEnvelopes, kubeconfig, ready, expected, creates] -> do
      let observed = ClusterObservation (boolean exists) (if state == "absent" then Nothing else Just state) (boolean nodeEnvelope) (boolean kubeletEnvelope) (boolean addonEnvelopes) (boolean kubeconfig) (boolean ready)
          actions = planActions observed
      assertEqual label expected (intercalate "," (map renderAction actions))
      assertEqual (label <> " kind-create") creates (show (length [() | CreateCluster <- actions]))
      if label `elem` ["stopped-node", "missing-kubeconfig"]
        then unless (null (mutantOneShot observed)) (die "M3 one-shot mutant unexpectedly repaired divergence")
        else pure ()
    _ -> die "malformed divergent-start row"
  forM_ ["quota-backend-bytes", "max-wals", "event-ttl", "serializeImagePulls: true"] $ \pin ->
    unless (containsText pin renderKindConfig) (die ("kind config projection absent: " <> pin))
  forM_ ["unified/kubelet", "unified/containerd"] $ \path ->
    unless (containsText path renderKindConfig) (die ("unified hard-backing mount absent: " <> path))
  splitConfig <- either (die . show) pure (renderKindConfigFor KindSplitRuntime)
  assertEqual "single kubeadmConfigPatches key" 1 (countOccurrences "kubeadmConfigPatches:" splitConfig)
  forM_ ["nodefs/kubelet", "imagefs/containerd"] $ \path ->
    unless (containsText path splitConfig) (die ("split-runtime mount absent: " <> path))
  assertEqual "SplitImage rejected"
    (Left (UnsupportedEnforcement KindSplitImage))
    (renderKindConfigFor KindSplitImage)
  let nodefs = LayoutIdentity "node-device" "node-quota" 4096
      imagefs = LayoutIdentity "image-device" "image-quota" 8192
      aliased = LayoutIdentity "node-device" "other-quota" 8192
      swapped = LayoutIdentity "image-device" "image-quota" 4096
  assertEqual "Unified identity"
    (Right ())
    (validateLayoutIdentities KindUnified nodefs nodefs nodefs)
  assertEqual "SplitRuntime identity"
    (Right ())
    (validateLayoutIdentities KindSplitRuntime nodefs imagefs imagefs)
  unless (isLeft (validateLayoutIdentities KindSplitRuntime nodefs aliased aliased))
    (die "M6 aliased-root mutant stayed green")
  unless (isLeft (validateLayoutIdentities KindSplitRuntime nodefs imagefs swapped))
    (die "M6 swapped-snapshot-root mutant stayed green")
 where
  boolean "true" = True
  boolean _ = False
  mutantOneShot observed = if clusterRegistered observed then [] else [CreateCluster]
  renderAction action = case action of
    CreateCluster -> "create-cluster"
    StartNode -> "start-node"
    EnsureNodeEnvelope -> "ensure-node-envelope"
    EnsureKubeletEnvelope -> "ensure-kubelet-envelope"
    EnsureAddonEnvelopes -> "ensure-addon-envelopes"
    ExportKubeconfig -> "export-kubeconfig"
    WaitReady -> "wait-ready"
  isLeft result = case result of
    Left _ -> True
    Right _ -> False

verifyInventoryCrossCheck :: IO ()
verifyInventoryCrossCheck = do
  let inventory = ObservedInventory
        { inventoryNodeName = "node"
        , inventoryNodeUid = "uid"
        , inventoryCpuMillis = 8000
        , inventoryMemoryBytes = 16 * 1024 * 1024 * 1024
        , inventoryEphemeralBytes = 64 * 1024 * 1024 * 1024
        , inventoryPodSlots = 110
        , inventoryCurrentPods = 8
        , inventoryPodCidr = "10.244.0.0/24"
        , inventoryRemainingCniSlots = 102
        , inventoryCsiAttachmentLimits = mempty
        , inventoryCurrentUniquePvcs = 0
        , inventoryFilesystemLayout = "Unified"
        , inventoryNodefsIdentity = "/dev/root ext4 rw"
        , inventoryContainerdRoots = "root=/var/lib/containerd"
        , inventoryImagePullPolicy = "Serial"
        , inventoryResidentImages = []
        , inventoryResidentContentDigests = []
        , inventoryResidentSnapshots = []
        , inventoryAddonPods = []
        , inventoryPodCommitments = []
        , inventoryMappedFileEntries = []
        , inventoryMappedFileCurrentBytes = 0
        , inventoryMappedFileTransitionBytes = 0
        , inventoryMappedFileMounts = []
        , inventoryNodefsCommittedBytes = 0
        , inventoryBackingIdentities = []
        , inventoryHostRuntime = "29.1.3 overlayfs /var/lib/docker"
        , inventoryHostRuntimeImages = []
        , inventoryHostRuntimeContainers = []
        , inventoryHostRuntimeStorage = []
        , inventoryCsiCurrentAttachments = mempty
        , inventoryDurableBackingPools = []
        , inventoryNativeHostCachePools = []
        , inventoryAcceleratorOffering = "none"
        }
      fitting = defaultDeclaredTarget
      failures =
        [ fitting {declaredCpuMillis = 8001}
        , fitting {declaredMemoryBytes = inventoryMemoryBytes inventory + 1}
        , fitting {declaredEphemeralBytes = inventoryEphemeralBytes inventory + 1}
        , fitting {declaredPodSlots = 103}
        , fitting {declaredCsiAttachments = Map.singleton "csi.example" 1}
        , fitting {declaredAcceleratorOffering = "cuda"}
        , fitting {declaredFilesystemLayout = "SplitRuntime"}
        , fitting {declaredImagePullPolicy = "BoundedParallel:2"}
        ]
  assertEqual "fitting inventory" (Right ()) (validateDeclaredTarget fitting inventory)
  assertEqual "inventory negative axes" 8 (length [() | Left _ <- map (`validateDeclaredTarget` inventory) failures])

verifyEtcdTransitionModel :: IO ()
verifyEtcdTransitionModel = do
  let logical = EtcdLogicalDemand 10 11 12 13 14 15 100
      model = EtcdStorageModel
        { etcdWalSegmentBytes = 20
        , etcdMaxWalFiles = 2
        , etcdWalOvershootBytes = 3
        , etcdPreallocatedNextWalBytes = 20
        , etcdRetainedSnapshots = 2
        , etcdSnapshotBytes = 10
        , etcdSnapshotSaveTemporaryBytes = 10
        , etcdDefragOldBytes = 30
        , etcdDefragNewBytes = 31
        , etcdMaxBackups = 2
        , etcdMaxLogBytesPerFile = 5
        , etcdSystemCarveBytes = 269
        }
      expectedPeak = 269
      steadyOnlyMutantPeak = 100 + (20 * 2) + (2 * 10) + (2 * 5)
  provisioned <- either (die . show) pure (provisionEtcdDemand logical model)
  assertEqual "version-pinned etcd transition peak" expectedPeak (provisionedEtcdPhysicalPeakBytes provisioned)
  unless (steadyOnlyMutantPeak < expectedPeak) (die "M5 steady-state-only mutant stayed green")
  assertEqual "etcd transition one-byte-under"
    (Left (EngineStorageOvercommit "etcd" expectedPeak (expectedPeak - 1)))
    (provisionEtcdDemand logical model {etcdSystemCarveBytes = expectedPeak - 1})
  assertEqual "etcd logical one-byte-under"
    (Left (EtcdLogicalQuotaExceeded 75 74))
    (provisionEtcdDemand logical {etcdBackendQuotaBytes = 74} model)

containsText :: String -> String -> Bool
containsText needle haystack = any (starts needle) (tails haystack)
 where
  starts [] _ = True
  starts _ [] = False
  starts (left : moreLeft) (right : moreRight) = left == right && starts moreLeft moreRight

countOccurrences :: String -> String -> Int
countOccurrences needle = length . filter (starts needle) . tails
 where
  starts [] _ = True
  starts _ [] = False
  starts (left : moreLeft) (right : moreRight) = left == right && starts moreLeft moreRight


readRows :: FilePath -> IO [Row]
readRows path = do
  contents <- readFile path
  traverse parseRow (drop 1 (lines contents))

parseRow :: String -> IO Row
parseRow source = case splitTabs source of
  [os, arch, gpu, expected] ->
    pure (Row (OsName os) (RawArch arch) (if gpu == "present" then GpuPresent else GpuAbsent) expected)
  fields -> die ("malformed substrate oracle row: " <> intercalate "|" fields)

splitTabs :: String -> [String]
splitTabs [] = [""]
splitTabs value = case break (== '\t') value of
  (field, []) -> [field]
  (field, _ : rest) -> field : splitTabs rest

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual =
  unless (expected == actual) (die (label <> ": expected " <> show expected <> ", got " <> show actual))
