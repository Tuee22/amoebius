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

data Evidence = Evidence Int Text Text Artifact Transport Inference Engine Authorization Denials Resources Frozen Universal Honesty Cleanup
data Artifact = Artifact Text Text Text Bool Bool
data Transport = Transport Bool Bool Bool Text Bool Int Int Bool Bool Bool
data Inference = Inference Text Text (Vector Run) Bool Bool Bool Text
data Run = Run Text Text Text Text Text Text Text Text Bool Text Text
data Engine = Engine (Vector Text) Int Text Int Int
data Authorization = Authorization Bool Int Bool Int Int Int Int Bool
data Denials = Denials Denial Denial Denial Denial
data Denial = Denial Text Int
data Resources = Resources Budget Bool Bool
data Budget = Budget Int Int Int Int Int Int Int Int Int Int (Maybe Text)
data Frozen = Frozen Int Bool
data Universal = Universal Bool Pristine
data Pristine = Pristine Text Text Text Text
data Honesty = Honesty Text Text Text Text Text
data Cleanup = Cleanup Bool Bool Bool Bool Bool Bool

instance FromJSON Evidence where
  parseJSON = withObject "Evidence" $ \value -> Evidence <$> value .: "register" <*> value .: "substrate" <*> value .: "result" <*> value .: "artifact" <*> value .: "transport" <*> value .: "inference" <*> value .: "engineCache" <*> value .: "authorization" <*> value .: "denials" <*> value .: "resources" <*> value .: "frozenSources" <*> value .: "universalLinuxCpu" <*> value .: "honesty" <*> value .: "cleanup"

instance FromJSON Artifact where
  parseJSON = withObject "Artifact" $ \value -> Artifact <$> value .: "catalogIdentity" <*> value .: "scope" <*> value .: "blobDigest" <*> value .: "readyPointerWrittenLast" <*> value .: "precommitPointerAbsent"

instance FromJSON Transport where
  parseJSON = withObject "Transport" $ \value -> Transport <$> value .: "nativeTcp" <*> value .: "cbor" <*> value .: "webSocket" <*> value .: "bundleOwnerPod" <*> value .: "duplicateCommandCollapsed" <*> value .: "brokerIncomingCommandAttempts" <*> value .: "consumerCommandDeliveries" <*> value .: "commandIdPreserved" <*> value .: "workIdEqualsCommandId" <*> value .: "noncePreserved"

instance FromJSON Inference where
  parseJSON = withObject "Inference" $ \value -> Inference <$> value .: "experimentHash" <*> value .: "seed" <*> value .: "runs" <*> value .: "distinctRunIds" <*> value .: "distinctPodUids" <*> value .: "byteIdentical" <*> value .: "fullTinyLlamaWeights"

instance FromJSON Run where
  parseJSON = withObject "Run" $ \value -> Run <$> value .: "commandId" <*> value .: "workId" <*> value .: "nonce" <*> value .: "runId" <*> value .: "experimentHash" <*> value .: "output" <*> value .: "cacheStatus" <*> value .: "modelDigest" <*> value .: "resultKeyInitiallyAbsent" <*> value .: "argv0" <*> value .: "cgroupReadback"

instance FromJSON Engine where
  parseJSON = withObject "Engine" $ \value -> Engine <$> value .: "statuses" <*> value .: "materializations" <*> value .: "engineDigest" <*> value .: "ownerLogs" <*> value .: "publicRegistryEvents"

instance FromJSON Authorization where
  parseJSON = withObject "Authorization" $ \value -> Authorization <$> value .: "vaultSecretRefsOnly" <*> value .: "oneUseTokensIssued" <*> value .: "tenantAChallengeObserved" <*> value .: "tenantBReadTenantAStatus" <*> value .: "vaultAuditDelta" <*> value .: "directMinioStatus" <*> value .: "directPulsarStatus" <*> value .: "credentialProviderAuthority"

instance FromJSON Denials where
  parseJSON = withObject "Denials" $ \value -> Denials <$> value .: "foreignScope" <*> value .: "precommit" <*> value .: "oneShortBudget" <*> value .: "changedInput"

instance FromJSON Denial where
  parseJSON = withObject "Denial" $ \value -> Denial <$> value .: "tag" <*> pure 0

instance FromJSON Resources where
  parseJSON = withObject "Resources" $ \value -> Resources <$> value .: "budget" <*> value .: "workerArgvObserved" <*> value .: "workerCgroupObserved"

instance FromJSON Budget where
  parseJSON = withObject "Budget" $ \value -> Budget <$> value .: "threads" <*> value .: "concurrency" <*> value .: "maxInputTokens" <*> value .: "maxOutputTokens" <*> value .: "retries" <*> value .: "bufferBytes" <*> value .: "cpuMilli" <*> value .: "memoryMiB" <*> value .: "ephemeralMiB" <*> value .: "cacheMiB" <*> value .: "accelerator"

instance FromJSON Frozen where
  parseJSON = withObject "Frozen" $ \value -> Frozen <$> value .: "count" <*> value .: "unchanged"

instance FromJSON Universal where
  parseJSON = withObject "Universal" $ \value -> Universal <$> value .: "availableOnEveryHardwareSubstrate" <*> value .: "pristineLinuxHost"

instance FromJSON Pristine where
  parseJSON = withObject "Pristine" $ \value -> Pristine <$> value .: "linux" <*> value .: "linux-cuda" <*> value .: "apple" <*> value .: "windows"

instance FromJSON Honesty where
  parseJSON = withObject "Honesty" $ \value -> Honesty <$> value .: "linkedHaskellAdapterContract" <*> value .: "retainedServiceIntegration" <*> value .: "productionTinyLlamaInference" <*> value .: "crossSubstrateBitEquality" <*> value .: "generalNoninterference"

instance FromJSON Cleanup where
  parseJSON = withObject "Cleanup" $ \value -> Cleanup <$> value .: "namespaceAbsent" <*> value .: "minioBucketAbsent" <*> value .: "pulsarTenantAbsent" <*> value .: "vaultObjectsAbsent" <*> value .: "onlyRetainedKindCluster" <*> pure True

main :: IO ()
main = do
  bytes <- ByteString.readFile "../DEVELOPMENT_PLAN/evidence/phase_49/infernix-artifact-live.json"
  evidence <- either die pure (eitherDecodeStrict' bytes)
  verify evidence
  putStrLn "infernix-core-artifact-lift-live-gate: PASS-SCOPED (native CBOR, scoped ready artifact, cold recompute, cache reuse, denials, cleanup)"

verify :: Evidence -> IO ()
verify (Evidence register substrate result artifact transport inference engine authorization denials resources frozen universal honesty cleanup) = do
  assert (register == 3 && substrate == "linux-cpu" && result == "PASS-SCOPED") "register/substrate/result"
  case artifact of
    Artifact catalog scope digest readyLast precommitAbsent -> assert ("catalog/tinyllama-1.1b-cpu@sha256:" `Text.isPrefixOf` catalog && scope == "tenant-a" && Text.length digest == 64 && readyLast && precommitAbsent) "artifact"
  case transport of
    Transport native cbor websocket owner collapsed incoming delivered command work nonce -> assert (native && cbor && not websocket && "broker-" `Text.isPrefixOf` owner && collapsed && incoming == 2 && delivered == 1 && command && work && nonce) "transport"
  verifyInference inference
  case engine of
    Engine statuses materializations digest logs public -> assert (statuses == Vector.fromList ["MISS", "HIT"] && materializations == 1 && Text.length digest == 64 && logs == 2 && public == 0) "engine-cache"
  case authorization of
    Authorization secretRefs tokens challenge foreignStatus vaultAudit minio pulsar authority -> assert (secretRefs && tokens == 2 && challenge && foreignStatus == 403 && vaultAudit > 0 && minio == 403 && pulsar `elem` [404, 405, 500] && not authority) "authorization"
  case denials of
    Denials (Denial foreignTag _) (Denial staged _) (Denial budget _) (Denial conflict _) -> assert (foreignTag == "ArtifactUnavailable" && staged == "ArtifactNotReady" && budget == "CpuInferenceMemoryUnderReserved" && conflict == "IdempotencyConflict") "denials"
  case resources of
    Resources (Budget threads concurrency input output retries buffer cpu memory ephemeral cache accelerator) argv cgroup -> assert (threads == 2 && concurrency == 1 && input == 64 && output == 16 && retries == 1 && buffer == 4096 && cpu == 500 && memory == 256 && ephemeral == 64 && cache == 96 && accelerator == Nothing && argv && cgroup) "resources"
  case frozen of
    Frozen count unchanged -> assert (count == 4 && unchanged) "frozen-sources"
  case universal of
    Universal available (Pristine linux linuxCuda apple windows) -> assert (available && linux == "Incus" && linuxCuda == "Incus" && apple == "Lima" && windows == "WSL2") "universal-linux-cpu"
  case honesty of
    Honesty adapter retained production cross general -> assert (adapter == "TESTED" && retained == "TESTED" && all (== "UNVERIFIED") [production, cross, general]) "honesty"
  case cleanup of
    Cleanup namespace minio pulsar vault cluster extra -> assert (and [namespace, minio, pulsar, vault, cluster, extra]) "cleanup"

verifyInference :: Inference -> IO ()
verifyInference (Inference experiment seed runs distinctRuns distinctPods equal fullWeights) = do
  assert ("sha256:" `Text.isPrefixOf` experiment && seed == "0x0000000000000001" && Vector.length runs == 2 && distinctRuns && distinctPods && equal && fullWeights == "UNVERIFIED") "inference-summary"
  case Vector.toList runs of
    [first, second] -> do
      verifyRun experiment first
      verifyRun experiment second
      assert (runOutput first == runOutput second && runCommand first == runCommand second && runNonce first == runNonce second && runUid first /= runUid second) "inference-correspondence"
    _ -> die "run-cardinality"
 where
  runOutput (Run _ _ _ _ _ output _ _ _ _ _) = output
  runCommand (Run command _ _ _ _ _ _ _ _ _ _) = command
  runNonce (Run _ _ nonce _ _ _ _ _ _ _ _) = nonce
  runUid (Run _ _ _ runId _ _ _ _ _ _ _) = runId

verifyRun :: Text -> Run -> IO ()
verifyRun experiment (Run command work nonce runId observedExperiment output cacheStatus modelDigest absent argv0 cgroup) =
  assert (command == work && command /= "" && nonce /= "" && runId /= "" && observedExperiment == experiment && Text.length output == 64 && cacheStatus `elem` ["MISS", "HIT"] && Text.length modelDigest == 64 && absent && argv0 == "/usr/bin/python3" && "cpu=" `Text.isInfixOf` cgroup && "memory=" `Text.isInfixOf` cgroup) "run"

assert :: Bool -> String -> IO ()
assert condition label = unless condition (die label)
