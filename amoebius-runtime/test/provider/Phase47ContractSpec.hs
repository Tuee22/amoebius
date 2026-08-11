{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Cluster.NodeProvisioner
import Amoebius.Pulumi.NodeGroup
import Control.Monad (unless)
import System.Exit (die)

main :: IO ()
main = do
  signalContract
  refusalContract
  identityContract
  joinContract
  putStrLn "provider-dynamic-node-contract: PASS (signals, quota, slots, identity, join)"

signalContract :: IO ()
signalContract = do
  assertEq "inactive-no-op" (Right (NodeNoOp 1)) (planNodeSet nodeClass observed quota demand (WorkflowCompletion False) 1 Present)
  assertEq "mut-47.1-ignore-signal" (Right (AddNode 2)) (planNodeSet nodeClass observed quota demand (WorkflowCompletion True) 1 Present)
  assertEq "load-signal" (Right (AddNode 2)) (planNodeSet nodeClass observed quota demand (Load True) 1 Present)
  assertEq "scale-down" (Right (RemoveNode 1)) (planNodeSet nodeClass observed quota demand (Load False) 2 Present)
  assertEq "mut-47.1-unreachable-as-gone" (Left RefuseOnUnreachable) (planNodeSet nodeClass observed quota demand (Load False) 2 Unreachable)

refusalContract :: IO ()
refusalContract = do
  let overQuota = nodeClass {nodeClassMaximumCount = 3}
      rejected = planNodeSet overQuota observed quota demand (Load True) 1 Present
  assertEq "provider-instance-quota" (Left ProviderInstanceQuotaExceeded) rejected
  assertEq "mut-47.1-apply-over-quota" False (cloudMutationPermitted rejected)
  assertEq "missing-cuda" (Left (MissingCapability Cuda)) (planNodeSet nodeClass observed quota demand {demandCapability = Cuda} (Load True) 1 Present)
  assertEq "pod-slot-one-short" (Left NoPodSlotCover) (planNodeSet nodeClass observed quota demand {demandPods = 30} (Load True) 1 Present)
  let oneClaim = demand {demandCsiClaims = ["data/one"]}
      noLiveAttach = observed {observedCsiAttachSlots = 0}
  assertEq "mut-47.1-ignore-live-csinode" (Left NoCsiAttachSlotCover) (planNodeSet nodeClass noLiveAttach quota oneClaim (Load True) 1 Present)
  let twoClaims = demand {demandCsiClaims = ["migration/old", "migration/replacement"]}
      oneLiveAttach = observed {observedCsiAttachSlots = 1}
      classTwo = nodeClass {nodeClassCsiAttachSlots = 2}
  assertEq "mut-47.1-dedup-distinct-pvcs" (Left NoCsiAttachSlotCover) (planNodeSet classTwo oneLiveAttach quota twoClaims (Load True) 1 Present)
  assertEq "root-byte-quota" (Left ProviderRootEbsBytesExceeded) (planNodeSet nodeClass observed quota {quotaRootEbsBytes = 42949672959} demand (Load True) 1 Present)
  assertEq "root-count-quota" (Left ProviderRootEbsCountExceeded) (planNodeSet nodeClass observed quota {quotaRootEbsCount = 1} demand (Load True) 1 Present)

identityContract :: IO ()
identityContract = do
  let first = providerPhysicalIdentity "account-fp" "amoebius-p47" "cpu-balanced" 0 "root/ephemeral-ebs"
      second = providerPhysicalIdentity "account-fp" "amoebius-p47" "cpu-balanced" 1 "root/ephemeral-ebs"
  assertEq "mut-47.1-template-id-as-physical" "account-fp/amoebius-p47/cpu-balanced/0/root/ephemeral-ebs" first
  assert "mut-47.1-template-id-as-physical" (first /= second)

joinContract :: IO ()
joinContract = do
  action <- expectRight "node-action" (validateNodeGroupAction request)
  node <- expectRight "node-materialization" (materializeManagedNode action receipt join)
  assertEq "managed-instance" "i-phase47-1" (managedNodeInstanceId node)
  assertEq "managed-node-uid" "node-uid-phase47-1" (managedNodeUid node)
  assertEq "stale-generation" (Left NodeSchedulerGenerationStale) (materializeManagedNode action receipt join {joinSchedulerGeneration = "stale"})
  assertEq "missing-taint" (Left NodeJoinNotQuarantined) (materializeManagedNode action receipt join {joinManagedCapacityTaint = False})
  assertEq "foreign-pod" (Left ForeignPodBeforeAdmission) (materializeManagedNode action receipt join {joinForeignPods = 1})

nodeClass :: ProviderNodeClass
nodeClass = ProviderNodeClass "cpu-balanced" 2 1800 7516192768 21474836480 29 29 25 21474836480 False 1 2

observed :: ObservedNodeLimits
observed = ObservedNodeLimits 29 29 25

quota :: ProviderQuota
quota = ProviderQuota 2 4 42949672960 2

demand :: NodeDemand
demand = NodeDemand 1000 1073741824 2147483648 2 ["data/sts0/pv_0", "scratch/job0/pv_0"] Cpu

request :: NodeGroupRequest
request = NodeGroupRequest "snapshot-fp" "cpu-balanced" 1 "scheduler-generation-47"

receipt :: NodeGroupReceipt
receipt = NodeGroupReceipt "snapshot-fp" "cpu-balanced" 1 "i-phase47-1"

join :: NodeJoinReadback
join = NodeJoinReadback "i-phase47-1" "node-uid-phase47-1" True True True True "scheduler-generation-47" True True 0

expectRight :: Show problem => String -> Either problem value -> IO value
expectRight _ (Right value) = pure value
expectRight label (Left problem) = die (label <> ": expected Right, got Left " <> show problem)

assertEq :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEq label expected actual = unless (expected == actual) (die (label <> ": expected " <> show expected <> ", got " <> show actual))

assert :: String -> Bool -> IO ()
assert label condition = unless condition (die (label <> ": assertion failed"))
