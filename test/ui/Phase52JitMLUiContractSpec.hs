{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.JitML.CudaArtifactLift
import Amoebius.JitML.UiAdapter
import Amoebius.Ui.Projection.OwnerKey
import Amoebius.Ui.Projection.ReceiptFold
import Amoebius.Ui.Projection.StreamCursor
import Amoebius.Ui.Server.RequestContext
import Control.Monad (forM_, unless)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Text.IO qualified as TextIO
import Numeric (showHex)
import System.Directory (doesFileExist, getCurrentDirectory)
import System.Exit (die)
import System.FilePath ((</>), takeDirectory)

main :: IO ()
main = do
  root <- projectRoot
  validatePhase0 root
  contextAlice <- trustedContext "alice" "t-a"
  contextBob <- trustedContext "bob" "t-a"
  contextAliceForeign <- trustedContext "alice" "t-b"
  contextCarol <- trustedContext "carol" "t-b"
  request <- either (die . show) pure (requestId "phase52-request-001")
  let scope = ScopeEpoch 9
      input = "bounded-linear"
  (started, state1) <- either (die . show) pure
    (startTraining "jitml-ui" contextAlice scope request input emptyUiAdapterState)
  assertEqual "training-start effect" (UiEffectCounts 1 0 0 0) (uiEffectCounts state1)
  assertEqual "command/work identity" (startCommandId started) (startWorkId started)
  assert ("cmd:" `Text.isPrefixOf` startCommandId started) "server-derived command identity"

  (resent, resentState) <- either (die . show) pure
    (startTraining "jitml-ui" contextAlice scope request input state1)
  assertEqual "exact start resend" started resent
  assertEqual "exact start resend effects" (uiEffectCounts state1) (uiEffectCounts resentState)
  assertLeft "changed training conflict" UiIdempotencyConflict
    (startTraining "jitml-ui" contextAlice scope request "changed" state1)

  artifact <- buildCommittedArtifact started input
  ready <- either (die . show) pure
    (adoptCheckpoint contextAlice scope started (CheckpointCommitted artifact))
  assertWith "mut-52-mint-ready-from-checkpoint-path" $ case
    adoptCheckpoint contextAlice scope started (CheckpointInFlight "/private/checkpoint") of
      Left ArtifactNotReady -> True
      _ -> False
  assertLeft "failed checkpoint" ArtifactNotReady
    (adoptCheckpoint contextAlice scope started (CheckpointFailed "trainer-failed"))
  assertWith "mut-52-ignore-artifact-owner" $ case
    adoptCheckpoint contextBob scope started (CheckpointCommitted artifact) of
      Left ArtifactUnavailable -> True
      _ -> False
  assertWith "mut-52-ignore-artifact-scope" $ case
    adoptCheckpoint contextAliceForeign scope started (CheckpointCommitted artifact) of
      Left ArtifactUnavailable -> True
      _ -> False
  assertLeft "stale scope" ReloadRequired
    (adoptCheckpoint contextAlice (ScopeEpoch 8) started (CheckpointCommitted artifact))

  (interaction, state2) <- either (die . show) pure
    (invokeReadyModel contextAlice scope ready input state1)
  assertEqual "independent result" "stable-reference-vector" (interactionPublicResult interaction)
  assertEqual "interaction effects" (UiEffectCounts 1 1 1 1) (uiEffectCounts state2)
  assertEqual "terminal command" (startCommandId started) (interactionCommandId interaction)
  assertEqual "terminal work" (startWorkId started) (interactionWorkId interaction)
  assertEqual "terminal receipt outcome" TerminalSucceeded (durableOutcome (interactionReceipt interaction))
  assertEqual "receipt command" (startCommandId started)
    (receiptCommandId (durableReceiptKey (interactionReceipt interaction)))
  assertEqual "receipt work" (startWorkId started)
    (workflowWorkId (durableWorkflowIdentity (interactionReceipt interaction)))

  (_again, repeatState) <- either (die . show) pure
    (invokeReadyModel contextAlice scope ready input state2)
  assertEqual "exact invoke resend effects" (uiEffectCounts state2) (uiEffectCounts repeatState)
  assertLeft "invoke changed input" UiIdempotencyConflict
    (invokeReadyModel contextAlice scope ready "changed" state2)
  assertLeft "same-tenant non-owner invoke" ArtifactUnavailable
    (invokeReadyModel contextBob scope ready input state1)
  assertLeft "foreign-tenant invoke" ArtifactUnavailable
    (invokeReadyModel contextCarol scope ready input state1)

  let route0 = pinSocket "ui-A" emptyRealtimeRouteState
      route1 = originateReceipt "ui-B" (interactionReceipt interaction) route0
  assertWith "mut-52-local-only-websocket-route" (pendingReceipt route1 == Just (interactionReceipt interaction))
  let route2 = flushRedisAndDropSocket route1
  (repaired, route3) <- case reconnectAndRepair "ui-current" route2 of
    Left problem -> die ("mut-52-redis-as-receipt: " <> show problem)
    Right value -> pure value
  assertEqual "repaired receipt" (interactionReceipt interaction) repaired
  assertEqual "repaired once" 1 (deliveredReceiptCount route3)
  (_repeatRepair, route4) <- either (die . show) pure (reconnectAndRepair "ui-current" route3)
  assertEqual "repair resend once" 1 (deliveredReceiptCount route4)

  let durable = lookupDurableReceipt (readyModelOwner ready) (readyModelCommandId ready) state2
  assertEqual "durable lookup" (Just (interactionReceipt interaction)) durable
  assertEqual "authority output escaped" "&lt;SCRIPT&gt;PORT:ADMIN&lt;/SCRIPT&gt;"
    (escapePresentation "<SCRIPT>PORT:ADMIN</SCRIPT>")
  putStrLn "jitml-ui-lift-contract: PASS (ready-only handle, owner/scope denial, durable cross-pod repair, idempotency)"

buildCommittedArtifact :: TrainingUiStart -> Text -> IO CommittedJitMLArtifact
buildCommittedArtifact started input = do
  let request = ScopedTrainingRequest
        { trainingTenant = ownerTenantId (startOwner started)
        , trainingApp = ownerAppId (startOwner started)
        , trainingCommandId = TrainingCommandId (startCommandId started)
        , trainingTarget = CudaTarget
        , trainingOptimizerSteps = 200
        , trainingParameterCount = 10000000
        , trainingRequiredVramBytes = 40000000
        , trainingBatch = TextEncoding.encodeUtf8 input
        , trainingChallenge = "phase52-contract"
        }
      capacity = CudaCapacity "GPU-phase52" "sm_52" 1 4294967296 536870912 3758096384 3000000000
  fst <$> either (die . show) pure
    (runCommittedTraining request capacity "GPU-phase52" "checkpoint-bytes" (PointerRevision "etag-phase52") emptyJitMLLiftState)

validatePhase0 :: FilePath -> IO ()
validatePhase0 root = do
  manifest <- Text.lines <$> TextIO.readFile (root </> "test/oracle/preimplementation_artifacts.tsv")
  let rows = filter (Text.isPrefixOf "52\t") manifest
  assertEqual "phase52 Phase-0 cardinality" 11 (length rows)
  assertEqual "phase52 oracle cardinality" 6 (length (filter (Text.isInfixOf "\toracle\t") rows))
  assertEqual "phase52 mutant cardinality" 5 (length (filter (Text.isInfixOf "\tmutant\t") rows))
  matrix <- TextIO.readFile (root </> "test/fixtures/phase_52/readiness_owner_scope_matrix.tsv")
  forM_ ["ready-own", "inflight-own", "failed-own", "same-tenant-nonowner", "foreign-tenant"] $ \needle ->
    assert (needle `Text.isInfixOf` matrix) ("matrix row absent: " <> Text.unpack needle)
  contract <- TextIO.readFile (root </> "test/fixtures/phase_52/public_contract.golden")
  forM_ ["OpaqueHandle", "Checkpoint paths", "remain private"] $ \needle ->
    assert (needle `Text.isInfixOf` contract) ("public contract drift: " <> Text.unpack needle)

trustedContext :: Text -> Text -> IO ServerRequestContext
trustedContext subject tenant = do
  key <- either (die . show) pure (signingKey signingSecret)
  let claims = Text.intercalate "|" [subject, tenant, "write", "active", "9", "session-nonce"]
      token = claims <> "." <> hmac signingSecret claims
  credential <- either (die . show) pure (verifyCredential key token)
  pure (serverRequestContext credential)

signingSecret :: Text
signingSecret = "phase52-contract-signing-key-000000000000000000000000000000"

hmac :: Text -> Text -> Text
hmac key value = hex (SHA256.hmac (TextEncoding.encodeUtf8 key) (TextEncoding.encodeUtf8 value))

hex :: ByteString -> Text
hex = Text.pack . concatMap render . ByteString.unpack
 where
  render byte = case showHex byte "" of
    [digit] -> ['0', digit]
    digits -> digits

assertLeft :: (Eq error, Show error, Show value) => String -> error -> Either error value -> IO ()
assertLeft label expected value = case value of
  Left actual -> assertEqual label expected actual
  Right actual -> die (label <> ": expected Left, got " <> show actual)

assertWith :: String -> Bool -> IO ()
assertWith = flip assert

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual =
  unless (expected == actual) (die (label <> ": expected " <> show expected <> ", got " <> show actual))

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

projectRoot :: IO FilePath
projectRoot = getCurrentDirectory >>= ascend
 where
  ascend path = do
    found <- doesFileExist (path </> "cabal.project")
    if found then pure path else
      let parent = takeDirectory path
       in if parent == path then die "phase52-project-root-absent" else ascend parent
