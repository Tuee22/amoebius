module Main (main) where

import Amoebius.Pulumi.Backend.EncryptedMinio
import Amoebius.Pulumi.Engine
import Amoebius.Pulumi.Provider.Eks
import Control.Monad (unless)
import Data.List (isPrefixOf)
import System.Exit (die)

main :: IO ()
main = do
  executionContract
  checkpointContract
  engineContract
  providerContract
  putStrLn "provider-deploy-checkpoint-contract: PASS (pure plan, demand, checkpoint, engine boundary)"

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

expectLeft :: (Eq failure, Show failure) => failure -> Either failure value -> String -> IO ()
expectLeft expected actual marker =
  case actual of
    Left found -> assert (found == expected) marker
    Right _ -> die marker

executionContract :: IO ()
executionContract = do
  let each = PulumiExecutorDemand 250 268435456 134217728 33554432 67108864
  demand <- either (die . show) pure (boundedExecutionDemand 2 [each, each])
  assert (executionLiveSet demand == 2) "mut-44.1-drop-parallel-executor"
  assert (executionCpuMilli demand == 500) "ExecutorCpuPeak"
  assert (executionMemoryBytes demand == 536870912) "ExecutorMemoryPeak"
  assert (executionPodEphemeralBytes demand == 268435456) "ExecutorPodEphemeralPeak"
  assert (executionPluginCacheBytes demand == 67108864) "PluginCachePeak"
  assert (executionWorkspaceBytes demand == 134217728) "WorkspacePeak"
  let exact = ExecutionSupply 500 536870912 268435456 67108864 134217728
  _ <- either (die . show) pure (provisionExecutionDemand exact demand)
  expectLeft ExecutorCpuShort (provisionExecutionDemand exact {supplyCpuMilli = 499} demand) "ExecutorCpuShort"
  expectLeft ExecutorMemoryShort (provisionExecutionDemand exact {supplyMemoryBytes = 536870911} demand) "ExecutorMemoryShort"
  expectLeft ExecutorPodEphemeralShort (provisionExecutionDemand exact {supplyPodEphemeralBytes = 268435455} demand) "ExecutorPodEphemeralShort"
  expectLeft PluginCacheShort (provisionExecutionDemand exact {supplyPluginCacheBytes = 67108863} demand) "PluginCacheShort"
  expectLeft WorkspaceShort (provisionExecutionDemand exact {supplyWorkspaceBytes = 134217727} demand) "WorkspaceShort"

checkpointContract :: IO ()
checkpointContract = do
  let demand = PulumiCheckpointObjectDemand
        { checkpointStack = "amoebius-p44"
        , checkpointStorageBudgetId = "phase44-pulumi-checkpoint"
        , checkpointEntries = [CheckpointEntry "deployment.json" 65536 True]
        , checkpointMaxRetainedRevisions = 2
        , checkpointSerialOverlapObjects = 3
        , checkpointFailedPartialObjects = 1
        , checkpointGcHorizonSeconds = 300
        , checkpointMutationAdmissionExclusive = True
        }
  assert (checkpointObjectPeak demand == 6) "CheckpointObjectPeak"
  assert (checkpointBytePeak demand == 393216) "CheckpointBytePeak"
  _ <- either (die . show) pure (provisionCheckpointDemand 393216 demand)
  expectLeft CheckpointBudgetShort (provisionCheckpointDemand 393215 demand) "CheckpointBudgetShort"
  envelope <- either die pure (acceptTransitEnvelope "p44-checkpoint-canary" "provider-state-plaintext" "vault:v1:opaque-ciphertext")
  assert (envelopeKeySource envelope == VaultTransit) "mut-44.1-static-key"
  assert ("vault:v1:" `isPrefixOf` envelopeCiphertext envelope) "CheckpointEnvelopePrefix"

engineContract :: IO ()
engineContract = do
  context <- either (die . show) pure (admitSingletonContext "phase33-system/amoebius-control-plane" 1)
  expectLeft NoSingletonContext (admitSingletonContext "" 1) "NoSingletonContext"
  invocation <- either (die . show) pure (preparePulumiUp context "/usr/local/bin/pulumi" "/var/lib/amoebius/pulumi/plugins/resource-aws-v7.3.0/pulumi-resource-aws" "amoebius-p44")
  assert (invocationEnvironment invocation == []) "mut-44.1-leak-path"
  assert (invocationArgv invocation == ["/usr/local/bin/pulumi", "up", "--yes", "--non-interactive", "--stack", "amoebius-p44"]) "EngineArgv"
  assert ("/" `isPrefixOf` invocationPluginPath invocation) "PluginAbsolutePath"

providerContract :: IO ()
providerContract = do
  let node = ProviderNodeClass "cpu-base-ca-central-1-v1" "m7i.large" "aws-ec2-2026-08-01" 1800 6442450944 29 29 25 32 NoAccelerator
      sku = ProviderSku "m7i.large" "aws-ec2-2026-08-01" 2 8589934592 29 25 20 1 NoAccelerator
      account = ObservedProviderAccount "sha256:fixture" True True "aws-ec2-2026-08-01" 64 8 20 1 1099511627776 107374182400
      demand = ProviderDemand "amoebius-p44" 1 node sku
  plan <- either (die . show) pure (validateInfrastructurePlan account demand)
  expectLeft ProviderVcpuQuotaShort (validateInfrastructurePlan account {accountVcpuLimit = 9} demand) "ProviderVcpuQuotaShort"
  expectLeft ManagedNodeGroupQuotaShort (validateInfrastructurePlan account {accountNodeGroupLimit = 1} demand) "ManagedNodeGroupQuotaShort"
  expectLeft ProviderEbsQuotaShort (validateInfrastructurePlan account {accountEbsByteLimit = 120000000000} demand) "ProviderEbsQuotaShort"
  context <- either (die . show) pure (acceptProviderReadback plan (ProviderReadback "sha256:fixture" "amoebius-p44" True 1 "m7i.large" NoAccelerator))
  assert (provisionedClusterName context == "amoebius-p44") "ProviderReadback"
