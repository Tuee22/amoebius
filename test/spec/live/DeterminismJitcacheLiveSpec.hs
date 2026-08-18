{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Monad (unless)
import Data.Aeson (FromJSON (..), eitherDecodeStrict', withObject, (.:))
import Data.ByteString qualified as ByteString
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Vector (Vector)
import Data.Vector qualified as Vector
import System.Exit (die)

data Evidence = Evidence Int Text Fingerprint Determinism Cache Deferred Universal Cleanup
data Fingerprint = Fingerprint Text Text Text Int Int
data Determinism = Determinism Text Text Text (Vector Run) Bool Bool Bool Text Text
data Run = Run Text Text Text Bool Int
data Cache = Cache BuildArm DownloadArm (Vector Client) OwnerManifest ProvisionShape Prune Int Text Text
data BuildArm = BuildArm Text Race Stat Stat Text
data DownloadArm = DownloadArm Text Text Int Int Stat Stat
data Race = Race Bool Int Int
data Stat = Stat Int Text Text Text
  deriving stock (Eq)
data Client = Client Text Text Text Int
data OwnerManifest = OwnerManifest Text Text Text Text Text Int
data ProvisionShape = ProvisionShape Int Int Int Int Bool
data Prune = Prune Int Int Int Bool Bool Bool
data Deferred = Deferred Text Text Text Text
data Universal = Universal Bool Pristine
data Pristine = Pristine Text Text Text Text
data Cleanup = Cleanup Bool Bool Bool (Vector Text)

instance FromJSON Evidence where
  parseJSON = withObject "Evidence" $ \value -> Evidence <$> value .: "register" <*> value .: "substrate" <*> value .: "substrateFingerprint" <*> value .: "determinism" <*> value .: "cache" <*> value .: "deferred" <*> value .: "universalLinuxCpu" <*> value .: "cleanup"

instance FromJSON Fingerprint where
  parseJSON = withObject "Fingerprint" $ \value -> Fingerprint <$> value .: "digest" <*> value .: "secondDigest" <*> value .: "fakeProbeDigest" <*> value .: "probeInputEnvironmentEntries" <*> value .: "pathLookups"

instance FromJSON Determinism where
  parseJSON = withObject "Determinism" $ \value -> Determinism <$> value .: "experimentHash" <*> value .: "flippedMetricHash" <*> value .: "fakeFingerprintHash" <*> value .: "runs" <*> value .: "sameHashByteIdentical" <*> value .: "altSeedDifferent" <*> value .: "altInputDifferent" <*> value .: "comparisonBoundary" <*> value .: "crossSubstrateBitEquality"

instance FromJSON Run where
  parseJSON = withObject "Run" $ \value -> Run <$> value .: "runId" <*> value .: "podUid" <*> value .: "outputKey" <*> value .: "outputInitiallyAbsent" <*> value .: "readOtherRunMounts"

instance FromJSON Cache where
  parseJSON = withObject "Cache" $ \value -> Cache <$> value .: "buildArm" <*> value .: "downloadArm" <*> value .: "clients" <*> value .: "ownerManifest" <*> value .: "provisionedShape" <*> value .: "pinAwarePrune" <*> value .: "publicRegistryEvents" <*> value .: "egressPolicy" <*> value .: "crossNodeReuse"

instance FromJSON BuildArm where
  parseJSON = withObject "BuildArm" $ \value -> BuildArm <$> value .: "ownerUid" <*> value .: "race" <*> value .: "firstMiss" <*> value .: "secondClientHit" <*> value .: "absoluteRecipeArgv0"

instance FromJSON DownloadArm where
  parseJSON = withObject "DownloadArm" $ \value -> DownloadArm <$> value .: "ownerUid" <*> value .: "registryDigest" <*> value .: "registryGetEvents" <*> value .: "secondClientNewRegistryEvents" <*> value .: "firstMiss" <*> value .: "secondClientHit"

instance FromJSON Race where
  parseJSON = withObject "Race" $ \value -> Race <$> value .: "bothObservedMiss" <*> value .: "materializations" <*> value .: "temporaryFiles"

instance FromJSON Stat where
  parseJSON = withObject "Stat" $ \value -> Stat <$> value .: "bytes" <*> value .: "contentAddress" <*> value .: "version" <*> value .: "inode"

instance FromJSON Client where
  parseJSON = withObject "Client" $ \value -> Client <$> value .: "name" <*> value .: "uid" <*> value .: "node" <*> value .: "cacheMounts"

instance FromJSON OwnerManifest where
  parseJSON = withObject "OwnerManifest" $ \value -> OwnerManifest <$> value .: "strategy" <*> value .: "image" <*> value .: "imagePullPolicy" <*> value .: "ephemeralRequest" <*> value .: "emptyDirSizeLimit" <*> value .: "writableHostPaths"

instance FromJSON ProvisionShape where
  parseJSON = withObject "ProvisionShape" $ \value -> ProvisionShape <$> value .: "cacheBudgetUnits" <*> value .: "emptyDirSizeLimitUnits" <*> value .: "ephemeralRequestUnits" <*> value .: "writableAndLogHeadroomUnits" <*> value .: "inequalitiesHold"

instance FromJSON Prune where
  parseJSON = withObject "Prune" $ \value -> Prune <$> value .: "beforeBytes" <*> value .: "afterBytes" <*> value .: "measuredPeakBytes" <*> value .: "pinnedPresent" <*> value .: "unpinnedPresent" <*> value .: "incomingPresent"

instance FromJSON Deferred where
  parseJSON = withObject "Deferred" $ \value -> Deferred <$> value .: "tier2Model" <*> value .: "tier3CudaKernel" <*> value .: "crossSubstrateBitEquality" <*> value .: "crossNodeReuse"

instance FromJSON Universal where
  parseJSON = withObject "Universal" $ \value -> Universal <$> value .: "availableOnEveryHardwareSubstrate" <*> value .: "pristineLinuxHost"

instance FromJSON Pristine where
  parseJSON = withObject "Pristine" $ \value -> Pristine <$> value .: "linux" <*> value .: "linux-cuda" <*> value .: "apple" <*> value .: "windows"

instance FromJSON Cleanup where
  parseJSON = withObject "Cleanup" $ \value -> Cleanup <$> value .: "namespaceAbsent" <*> value .: "minioBucketAbsent" <*> value .: "registryAddedKeysAbsent" <*> value .: "remainingRegistryAddedKeys"

main :: IO ()
main = do
  bytes <- ByteString.readFile "DEVELOPMENT_PLAN/evidence/phase_48/determinism-jitcache-live.json"
  evidence <- either die pure (eitherDecodeStrict' bytes)
  verify evidence
  putStrLn "determinism-jitcache-live: PASS (fresh recompute, first-miss, reuse, pruning, cleanup)"

verify :: Evidence -> IO ()
verify (Evidence register substrate fingerprint determinism cache deferred universal cleanup) = do
  assert (register == 3 && substrate == "linux-cpu") "register/substrate"
  case fingerprint of
    Fingerprint first second fake environmentEntries pathLookups -> assert (first == second && first /= fake && environmentEntries == 0 && pathLookups == 0) "fingerprint"
  case determinism of
    Determinism experiment flipped fake runs same altSeed altInput boundary cross -> do
      assert (experiment /= flipped && experiment /= fake && same && altSeed && altInput) "determinism"
      assert (boundary == "out-of-band MinIO GET by harness; never HTTP 412" && cross == "UNVERIFIED") "determinism-boundary"
      assert (Vector.length runs == 4 && Vector.length (Vector.fromList (unique (Vector.toList (Vector.map runUid runs)))) == 4 && Vector.all validRun runs) "fresh-runs"
  case cache of
    Cache build download clients owner shape prune publicEvents egress crossNode -> do
      verifyBuild build
      verifyDownload download build
      assert (Vector.length clients == 2 && Vector.all validClient clients) "clients"
      case owner of
        OwnerManifest strategy image pullPolicy request sizeLimit hostPaths -> assert (strategy == "Recreate" && "registry.amoebius.invalid:5000/" `prefixOf` image && pullPolicy == "Never" && request == "224Mi" && sizeLimit == "192Mi" && hostPaths == 0) "owner-manifest"
      case shape of
        ProvisionShape budget volume request headroom holds -> assert (budget == 160 && volume == 192 && request == 224 && headroom == 32 && holds && budget <= volume && volume + headroom <= request) "provision-shape"
      case prune of
        Prune before after peak pinned unpinned incoming -> assert (before == 121 && after == 105 && peak <= 160 && pinned && not unpinned && incoming) "pin-aware-prune"
      assert (publicEvents == 0 && egress == "DNS plus in-cluster distribution only" && crossNode == "UNVERIFIED") "egress/cross-node"
  case deferred of
    Deferred tier2 tier3 crossBits crossNode -> assert (all hasUnverified [tier2, tier3, crossBits, crossNode]) "deferred"
  case universal of
    Universal available (Pristine linux linuxCuda apple windows) -> assert (available && linux == "Incus" && linuxCuda == "Incus" && apple == "Lima" && windows == "WSL2") "universal-linux-cpu"
  case cleanup of
    Cleanup namespace minio registry remaining -> assert (namespace && minio && registry && Vector.null remaining) "cleanup"
 where
  runUid (Run _ uid _ _ _) = uid
  validRun (Run _ uid key absent mounts) = uid /= "" && key /= "" && absent && mounts == 0
  validClient (Client _ uid node mounts) = uid /= "" && node /= "" && mounts == 0
  hasUnverified value = "UNVERIFIED" `contains` value
  unique [] = []
  unique (value : rest) = value : unique (filter (/= value) rest)

verifyBuild :: BuildArm -> IO ()
verifyBuild (BuildArm owner (Race both misses temporary) first second argv0) = do
  assert (owner /= "" && both && misses == 1 && temporary == 0 && argv0 == "/usr/bin/sh") "build-race"
  assert (first == second && validStat first) "build-hit"

verifyDownload :: DownloadArm -> BuildArm -> IO ()
verifyDownload (DownloadArm owner digest gets secondGets first second) (BuildArm buildOwner _ _ _ _) = do
  assert (owner /= buildOwner && digest == expectedDigest && gets >= 1 && secondGets == 0) "download-events"
  assert (first == second && validStat first) "download-hit"

validStat :: Stat -> Bool
validStat (Stat bytes digest version inode) = bytes == 41 && digest == expectedDigest && version == "llama.cpp-cpu 0.1.0" && inode /= ""

expectedDigest :: Text
expectedDigest = "sha256:f0f27f013c07a69471b7b4603eb273f6be42e9ba39fe7a242fd1fd090cf28387"

prefixOf :: Text -> Text -> Bool
prefixOf = Text.isPrefixOf

contains :: Text -> Text -> Bool
contains = Text.isInfixOf

assert :: Bool -> String -> IO ()
assert condition label = unless condition (die label)
