{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Pulsar.Cbor (DecodeError, decodeCborBytes)
import Control.Monad (unless)
import Data.ByteString qualified as ByteString
import Data.Text (Text)
import Data.Text qualified
import Data.Text.Encoding qualified as TextEncoding
import Infernix.Adapter.Core
import Infernix.Adapter.Engine
import Infernix.Adapter.Pulsar
import Infernix.Adapter.Secrets
import Infernix.Adapter.Store
import System.Exit (die)

main :: IO ()
main = do
  fixtureContract
  artifactContract
  budgetContract
  transportContract
  workflowContract
  putStrLn "infernix-core-artifact-lift-contract: PASS (scope, readiness, identity, deterministic CPU, budget, idempotency)"

fixtureContract :: IO ()
fixtureContract = do
  requestBytes <- ByteString.readFile "../test/fixture/infernix_lift/request.cbor"
  goldenBytes <- ByteString.readFile "../test/fixture/infernix_lift/sibling_golden.cbor"
  requestText <- either (die . show) pure (decodeCborBytes requestBytes :: Either DecodeError Text)
  goldenText <- either (die . show) pure (decodeCborBytes goldenBytes :: Either DecodeError Text)
  assert (requestText == "infernix-lift-request-v1|tenant=tenant-a|command=phase0-command-49|seed=1|input=content-addressing\n") "phase0-request-cbor"
  assert (goldenText == "8d5690c448187e549b5d0eda0957d35e0a982f4660673665fefc6c897b92ba49\n") "phase0-golden-cbor"

artifactContract :: IO ()
artifactContract = do
  staged <- either (die . show) pure stage
  assertLeft ArtifactNotReady (commitReadyPointer False staged) "mut-49-mint-ready-before-pointer-commit"
  ready <- either (die . show) pure (commitReadyPointer True staged)
  assert (readyArtifactScope ready == tenantA) "ready-scope"
  assert (readyArtifactCatalog ready == tinyLlamaCpuCatalog) "ready-catalog"
  assert (readyArtifactBlobDigest ready == "88dd6c952aba749884eb842494177646d0f77be0ae2d6998f5c69fe3d22551fa") "ready-blob-digest"
  assert ("infernix/tenant-a/pointers/catalog/tinyllama" `prefixOf` readyArtifactPointerKey ready) "ready-pointer-last"
  assertLeft ArtifactUnavailable (authorizeReadyArtifact (leastPrivilegeCredential tenantB) ready) "mut-49-drop-artifact-scope"
  assertLeft ArtifactNotReady (rejectForgedWireReference tenantA tinyLlamaCpuCatalog (readyArtifactBlobDigest ready)) "forged-wire-not-ready"
 where
  prefixOf prefix value = prefix == Data.Text.take (Data.Text.length prefix) value

budgetContract :: IO ()
budgetContract = do
  let good = minimumCpuInferenceWorkBudget
      short = good {cpuMemoryMiB = cpuMemoryMiB good - 1}
  assert (admitCpuInferenceWorkBudget good == Right good) "cpu-budget-positive"
  assertLeft CpuInferenceMemoryUnderReserved (admitCpuInferenceWorkBudget short) "cpu-budget-one-short"

transportContract :: IO ()
transportContract = do
  let command = InferenceCommand "tenant-a" (CommandId "phase0-command-49") (WorkId "phase0-command-49") (Nonce "phase0-nonce-49") "explain content addressing"
      event = eventForCommand command
  decodedCommand <- either (die . show) pure (decodeCborBytes (commandCbor command) :: Either DecodeError InferenceCommand)
  decodedEvent <- either (die . show) pure (decodeCborBytes (eventCbor event) :: Either DecodeError InferenceEvent)
  assert (decodedCommand == command && decodedEvent == event) "native-cbor-roundtrip"
  assert (eventCommandId event == commandId command && eventWorkId event == commandWorkId command && eventNonce event == commandNonce command) "mut-49-regenerate-command-id"

workflowContract :: IO ()
workflowContract = do
  staged <- either (die . show) pure stage
  ready <- either (die . show) pure (commitReadyPointer True staged)
  goldenBytes <- ByteString.readFile "../test/fixture/infernix_lift/sibling_golden.cbor"
  goldenText <- either (die . show) pure (decodeCborBytes goldenBytes :: Either DecodeError Text)
  let credentialA = leastPrivilegeCredential tenantA
      firstRequest = request ready "command-a" "run-a" "explain content addressing"
      secondRequest = request ready "command-b" "run-b" "explain content addressing"
  (first, afterFirst) <- either (die . show) pure (runWorkflow credentialA firstRequest emptyAdapterState)
  (second, _) <- either (die . show) pure (runWorkflow credentialA secondRequest emptyAdapterState)
  assert (outcomeOutput first == outcomeOutput second && outcomeOutput first == TextEncoding.encodeUtf8 goldenText) "mut-49-use-wallclock-seed"
  assert (outcomeExperimentHash first == outcomeExperimentHash second && outcomeRunId first /= outcomeRunId second) "two-cold-runs-one-experiment"
  assert (engineFirstMiss (outcomeEngine first) && engineSecondHit (outcomeEngine first) && engineResidentCount (outcomeEngine first) == 1) "engine-cache-reuse"
  (resent, afterResend) <- either (die . show) pure (runWorkflow credentialA firstRequest afterFirst)
  assert (resent == first && adapterEffectCounts afterResend == adapterEffectCounts afterFirst) "exact-resend-zero-effect"
  let conflict = firstRequest {workflowInput = "explain storage addressing"}
  assertLeft IdempotencyConflict (runWorkflow credentialA conflict afterFirst) "changed-input-idempotency-conflict"
  assertLeft (WorkflowArtifactError ArtifactUnavailable) (runWorkflow (leastPrivilegeCredential tenantB) firstRequest emptyAdapterState) "foreign-scope-zero-dispatch"
 where
  request ready command run input =
    WorkflowRequest
      { workflowCommandId = CommandId command
      , workflowWorkId = WorkId command
      , workflowRunId = RunId run
      , workflowNonce = Nonce "phase0-nonce-49"
      , workflowInput = input
      , workflowSeed = 1
      , workflowExperimentHash = "sha256:infernix-lift-linux-cpu-experiment"
      , workflowArtifact = ready
      , workflowBudget = minimumCpuInferenceWorkBudget
      }

stage :: Either ArtifactError StagedArtifact
stage = stageArtifact tenantA tinyLlamaCpuCatalog pinnedCpuModelBytes

assertLeft :: (Eq error, Show error, Show value) => error -> Either error value -> String -> IO ()
assertLeft expected actual label = case actual of
  Left observed -> assert (observed == expected) label
  Right value -> die (label <> ": unexpectedly accepted " <> show value)

assert :: Bool -> String -> IO ()
assert condition label = unless condition (die label)
