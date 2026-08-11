{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Infernix.UiAdapter
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
import Infernix.Adapter.Engine (tinyLlamaCpuCatalog)
import Infernix.Adapter.Secrets (tenantA)
import Infernix.Adapter.Store (commitReadyPointer, stageArtifact)
import Numeric (showHex)
import System.Directory (doesFileExist, getCurrentDirectory)
import System.Exit (die)
import System.FilePath ((</>), takeDirectory)

main :: IO ()
main = do
  root <- projectRoot
  validatePhase0 root
  contextA <- trustedContext "alice" "tenant-a"
  contextBob <- trustedContext "bob" "tenant-a"
  contextB <- trustedContext "carol" "tenant-b"
  staged <- either (die . show) pure (stageArtifact tenantA tinyLlamaCpuCatalog modelFixture)
  ready <- either (die . show) pure (commitReadyPointer True staged)
  request <- either (die . show) pure (requestId "phase50-request-001")
  let scope = ScopeEpoch 7
      input = "fresh-challenge"
      ownClaim = ClientArtifactClaim "tenant-a" "alice"
      bobClaim = ClientArtifactClaim "tenant-a" "bob"
      forgedOwnClaim = ClientArtifactClaim "tenant-a" "alice"
  (started, state1) <- either (die . show) pure
    (startWorkflow "infernix-ui" contextA scope request input ready emptyUiAdapterState)
  assertEqual "workflow effect" (UiEffectCounts 1 0 0 0) (uiEffectCounts state1)
  assert (startCommandId started == startWorkId started) "command/work identity"
  assert ("cmd:" `Text.isPrefixOf` startCommandId started) "server-derived command identity"
  assert (not (requestIdText request `Text.isInfixOf` startCommandId started)) "raw request id escaped authority"

  (resent, stateResent) <- either (die . show) pure
    (startWorkflow "infernix-ui" contextA scope request input ready state1)
  assertEqual "exact resend outcome" started resent
  assertEqual "exact resend effects" (uiEffectCounts state1) (uiEffectCounts stateResent)
  assertLeft "changed-input conflict" UiIdempotencyConflict
    (startWorkflow "infernix-ui" contextA scope request "changed" ready state1)

  (interaction, state2) <- either (die . show) pure
    (invokeReadyArtifact contextA ownClaim scope (startReadyArtifact started) input state1)
  assertEqual "reference model result" "FRESH-CHALLENGE" (interactionPublicResult interaction)
  assertEqual "interaction effects" (UiEffectCounts 1 1 1 1) (uiEffectCounts state2)
  assert (interactionCommandId interaction == interactionWorkId interaction) "terminal work identity"
  assertWith "mut-50-drop-command-id-from-terminal" $
    receiptCommandId (durableReceiptKey (interactionReceipt interaction)) == startCommandId started
  assertEqual "terminal outcome" TerminalSucceeded (durableOutcome (interactionReceipt interaction))
  assertEqual "receipt work id" (startWorkId started)
    (workflowWorkId (durableWorkflowIdentity (interactionReceipt interaction)))
  assertEqual "receipt handle" (startWorkflowHandle started)
    (workflowHandle (durableWorkflowIdentity (interactionReceipt interaction)))

  (_repeatInteraction, stateRepeat) <- either (die . show) pure
    (invokeReadyArtifact contextA ownClaim scope (startReadyArtifact started) input state2)
  assertEqual "exact invoke resend effects" (uiEffectCounts state2) (uiEffectCounts stateRepeat)
  assertLeft "invoke changed-input conflict" UiIdempotencyConflict
    (invokeReadyArtifact contextA ownClaim scope (startReadyArtifact started) "changed" state2)
  assertLeft "same tenant foreign owner" ArtifactUnavailable
    (invokeReadyArtifact contextBob bobClaim scope (startReadyArtifact started) input state1)
  assertWith "mut-50-trust-client-artifact-scope" $ case
    invokeReadyArtifact contextB forgedOwnClaim scope (startReadyArtifact started) input state1 of
      Left ArtifactUnavailable -> True
      _ -> False
  assertLeft "stale scope" ReloadRequired
    (invokeReadyArtifact contextA ownClaim (ScopeEpoch 6) (startReadyArtifact started) input state1)

  let owner = readyArtifactOwner (startReadyArtifact started)
  receipt <- maybe (die "uninvolved receipt query failed") pure
    (lookupDurableReceipt owner (startCommandId started) state2)
  assertEqual "queried receipt" (interactionReceipt interaction) receipt
  assertEqual "hostile result escaped"
    "&lt;SCRIPT&gt;PORT:ADMIN&lt;/SCRIPT&gt;" (escapePresentation "<SCRIPT>PORT:ADMIN</SCRIPT>")
  assert (not ("<SCRIPT>" `Text.isInfixOf` escapePresentation "<SCRIPT>PORT:ADMIN</SCRIPT>"))
    "hostile result reached a raw sink"
  putStrLn "infernix-ui-lift-contract: PASS (opaque handle, scoped start/invoke, durable identity, idempotency, escaped output)"

validatePhase0 :: FilePath -> IO ()
validatePhase0 root = do
  manifest <- Text.lines <$> TextIO.readFile (root </> "test/phase0_oracle_manifest.tsv")
  let rows = filter (Text.isPrefixOf "50\t") manifest
  assertEqual "phase50 phase0 cardinality" 8 (length rows)
  assertEqual "phase50 oracle cardinality" 6 (length (filter (Text.isInfixOf "\toracle\t") rows))
  assertEqual "phase50 mutant cardinality" 2 (length (filter (Text.isInfixOf "\tmutant\t") rows))
  contract <- TextIO.readFile (root </> "test/fixtures/phase_50/public_contract.golden")
  forM_
    [ "OpaqueHandle", "No provider coordinate", "No provider coordinate, model path, cache path, credential, or raw URL is public."
    ] $ \needle -> assert (needle `Text.isInfixOf` contract) ("public contract drift: " <> Text.unpack needle)
  program <- TextIO.readFile (root </> "dhall/ui/infernix.dhall")
  forM_ ["WorkflowStart", "WorkflowProgress", "ServerHandle", "infernix.workflow"] $ \needle ->
    assert (needle `Text.isInfixOf` program) ("ui program surface absent: " <> Text.unpack needle)
  scope <- TextIO.readFile (root </> "test/fixtures/phase_50/scope_matrix.tsv")
  forM_ ["own\t", "same-tenant-foreign", "foreign-tenant", "stale-scope"] $ \needle ->
    assert (needle `Text.isInfixOf` scope) ("scope matrix row absent: " <> Text.unpack needle)

trustedContext :: Text -> Text -> IO ServerRequestContext
trustedContext subject tenant = do
  key <- either (die . show) pure (signingKey signingSecret)
  let claims = Text.intercalate "|" [subject, tenant, "write", "active", "7", "session-nonce"]
      token = claims <> "." <> hmac signingSecret claims
  credential <- either (die . show) pure (verifyCredential key token)
  pure (serverRequestContext credential)

signingSecret :: Text
signingSecret = "phase50-contract-signing-key-000000000000000000000000000000"

hmac :: Text -> Text -> Text
hmac key value = hex (SHA256.hmac (TextEncoding.encodeUtf8 key) (TextEncoding.encodeUtf8 value))

hex :: ByteString -> Text
hex = Text.pack . concatMap render . ByteString.unpack
 where
  render byte = case showHex byte "" of
    [digit] -> ['0', digit]
    digits -> digits

modelFixture :: ByteString
modelFixture = "phase49-tiny-decoder-v1|vocab=amoebius,deterministic,artifact,ready|weights=3,1,4,1,5,9"

assertLeft :: (Eq error, Show error, Show value) => String -> error -> Either error value -> IO ()
assertLeft label expected value = case value of
  Left actual -> assertEqual label expected actual
  Right actual -> die (label <> ": expected Left, got " <> show actual)

assertWith :: String -> Bool -> IO ()
assertWith label condition = assert condition label

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
    if found
      then pure path
      else
        let parent = takeDirectory path
         in if parent == path then die "phase50-project-root-absent" else ascend parent
