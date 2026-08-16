{-# LANGUAGE OverloadedStrings #-}

module FaultContracts
  ( checkFaultContracts
  ) where

import Amoebius.Sim.Env
import qualified Amoebius.Sim.Fakes.ApiServer as Api
import qualified Amoebius.Sim.Fakes.Clock as Clock
import qualified Amoebius.Sim.Fakes.MinIO as MinIO
import qualified Amoebius.Sim.Fakes.Pulsar as Pulsar
import qualified Amoebius.Sim.Fakes.Route53 as Route53
import qualified Amoebius.Sim.Fakes.Vault as Vault
import Control.Monad (unless)

checkFaultContracts :: IO ()
checkFaultContracts = do
  checkMinIO
  checkApiServer
  checkRoute53
  checkVault
  checkPulsar
  checkClock

checkMinIO :: IO ()
checkMinIO = do
  let key = BlobKey "intent"
      (stored, state) = MinIO.putBlob IfNoneMatch key "v1" MinIO.emptyMinIO
      (conflict, _) = MinIO.putBlob IfNoneMatch key "v2" state
      (unconditional, _) = MinIO.putBlob Unconditional key "v2" state
  assertEqual "MinIO initial put" BlobStored stored
  assertEqual "MinIO If-None-Match conflict" BlobPreconditionFailed412 conflict
  assertEqual "MinIO knob-disabled overwrite" BlobStored unconditional

checkApiServer :: IO ()
checkApiServer = do
  let quiet = Api.emptyApiServer (Api.ApiFaults False (ResourceVersion 0))
      (applied, state) = Api.applyObject object (ResourceVersion 0) "v1" quiet
      (conflict, _) = Api.applyObject object (ResourceVersion 0) "v2" state
      watchGapState = Api.emptyApiServer (Api.ApiFaults False (ResourceVersion 3))
      (crashed, crashCleared) = Api.applyObject object (ResourceVersion 0) "v1"
        (Api.emptyApiServer (Api.ApiFaults True (ResourceVersion 0)))
      (afterCrash, _) = Api.applyObject object (ResourceVersion 0) "v1" crashCleared
  assertEqual "apiserver initial apply" (ObjectApplied (ResourceVersion 1)) applied
  assertEqual "apiserver resourceVersion conflict" (ResourceVersionConflict (ResourceVersion 1)) conflict
  assertEqual "apiserver watch gap" (WatchGap (ResourceVersion 3))
    (Api.watchObjects (ResourceVersion 1) watchGapState)
  assertEqual "apiserver knob-disabled watch" (WatchObjects [])
    (Api.watchObjects (ResourceVersion 0) quiet)
  assertEqual "apiserver crash knob" ApplyCrashed crashed
  assertEqual "apiserver crash disabled after one call" (ObjectApplied (ResourceVersion 1)) afterCrash
  where
    object = ObjectName "service"

checkRoute53 :: IO ()
checkRoute53 = do
  let name = DnsName "service.example"
      old = DnsValue "old"
      new = DnsValue "new"
      delayed = Route53.seedDns name old (Route53.emptyRoute53 5)
      pending = Route53.writeDns name new delayed
      settled = Route53.advanceDns 5 pending
      immediate = Route53.writeDns name new (Route53.seedDns name old (Route53.emptyRoute53 0))
  assertEqual "route53 stale during propagation" (Just old) (Route53.readDns name pending)
  assertEqual "route53 propagated value" (Just new) (Route53.readDns name settled)
  assertEqual "route53 delay knob disabled" (Just new) (Route53.readDns name immediate)
  assertEqual "route53 has no CAS" False Route53.supportsCAS

checkVault :: IO ()
checkVault = do
  let operation = VaultWrite (VaultPath "secret") "value"
      (sealedResult, _) = Vault.runVaultOp operation (Vault.emptyVault True)
      (openResult, _) = Vault.runVaultOp operation (Vault.emptyVault False)
  assertEqual "Vault sealed rejection" VaultRejectedSealed sealedResult
  assertEqual "Vault seal knob disabled" (VaultValue (Just "value")) openResult

checkPulsar :: IO ()
checkPulsar = do
  let partitioned = Pulsar.emptyPulsar (Pulsar.PulsarFaults True False True)
      (_, _, queued) = Pulsar.publish "one" partitioned
      (blocked, _, stillQueued) = Pulsar.consume queued
      (delivered, dropped, _) = Pulsar.consume (Pulsar.heal stillQueued)
      ordered0 = Pulsar.emptyPulsar (Pulsar.PulsarFaults False False False)
      (_, _, ordered1) = Pulsar.publish "one" ordered0
      (_, _, ordered2) = Pulsar.publish "two" ordered1
      (ordered, orderedDrops, _) = Pulsar.consume ordered2
      reordered0 = Pulsar.emptyPulsar (Pulsar.PulsarFaults False True False)
      (_, _, reordered1) = Pulsar.publish "one" reordered0
      (_, _, reordered2) = Pulsar.publish "two" reordered1
      (reordered, _, _) = Pulsar.consume reordered2
  assertEqual "Pulsar partition blocks delivery" [] blocked
  assertEqual "Pulsar heal redelivers once after dedup" [MessageId 1] (map messageId delivered)
  assertEqual "Pulsar duplicate observable" [MessageId 1] dropped
  assertEqual "Pulsar reorder knob disabled" [MessageId 1, MessageId 2] (map messageId ordered)
  assertEqual "Pulsar duplicate knob disabled" [] orderedDrops
  assertEqual "Pulsar reorder knob" [MessageId 2, MessageId 1] (map messageId reordered)

checkClock :: IO ()
checkClock = do
  let delayed = Clock.advanceClock 17 Clock.emptyClock
      unchanged = Clock.advanceClock 0 Clock.emptyClock
  assertEqual "clock delay knob" 17 (Clock.elapsedMicros delayed)
  assertEqual "clock delay disabled" 0 (Clock.elapsedMicros unchanged)

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual =
  unless (expected == actual) (fail (label <> ": expected " <> show expected <> ", got " <> show actual))
