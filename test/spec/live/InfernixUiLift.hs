{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Monad (unless)
import Data.Aeson (FromJSON (..), eitherDecodeStrict', withObject, (.:))
import Data.ByteString qualified as ByteString
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import System.Directory (doesFileExist, getCurrentDirectory)
import System.Exit (die)
import System.FilePath ((</>), takeDirectory)

data Evidence = Evidence Int Text Text Authority Browser Workflow Providers Cleanup Universal Honesty Prerequisite
data Authority = Authority Bool (Map Text Session) (Map Text Text) Text
data Session = Session Bool Text Text
data Browser = Browser Text [Int] Text Text Text Int
data Workflow = Workflow Text Text Text Text Counts Int Int Text Text
data Counts = Counts Int Int Int Int
data Providers = Providers Minio Pulsar Kubernetes
data Minio = Minio Bool Bool Int
data Pulsar = Pulsar [Text] (Map Text Int) (Map Text Int)
data Kubernetes = Kubernetes Text Text
data Cleanup = Cleanup Bool Bool Bool Bool
data Universal = Universal Bool Pristine
data Pristine = Pristine Text Text Text Text
data Honesty = Honesty Text Text Text Text Text Text Text Text Text Text Text
data Prerequisite = Prerequisite Text Text

instance FromJSON Evidence where
  parseJSON = withObject "Evidence" $ \value -> Evidence
    <$> value .: "register" <*> value .: "substrate" <*> value .: "result"
    <*> value .: "authority" <*> value .: "browser" <*> value .: "workflow"
    <*> value .: "providers" <*> value .: "cleanup" <*> value .: "universalLinuxCpu"
    <*> value .: "honesty" <*> value .: "prerequisite"

instance FromJSON Authority where
  parseJSON = withObject "Authority" $ \value -> Authority
    <$> value .: "rawTokensStored" <*> value .: "tenantSessions" <*> value .: "tokenDigests"
    <*> value .: "envoyOidcProbeTokenDigest"

instance FromJSON Session where
  parseJSON = withObject "Session" $ \value -> Session
    <$> value .: "active" <*> value .: "username" <*> value .: "tenant"

instance FromJSON Browser where
  parseJSON = withObject "Browser" $ \value -> Browser
    <$> value .: "engine" <*> value .: "positiveStatuses" <*> value .: "visibleResult"
    <*> value .: "hostileText" <*> value .: "hostileHtml" <*> value .: "hostileScriptCount"

instance FromJSON Workflow where
  parseJSON = withObject "Workflow" $ \value -> Workflow
    <$> value .: "commandId" <*> value .: "workId" <*> value .: "handleDigest"
    <*> value .: "terminalOutcome" <*> value .: "effectCounts" <*> value .: "foreignStatus"
    <*> value .: "foreignEffectDelta" <*> value .: "receiptReadByServer" <*> value .: "acceptanceSource"

instance FromJSON Counts where
  parseJSON = withObject "Counts" $ \value -> Counts
    <$> value .: "workflowStarts" <*> value .: "inferenceDispatches"
    <*> value .: "artifactReads" <*> value .: "resultWrites"

instance FromJSON Providers where
  parseJSON = withObject "Providers" $ \value -> Providers
    <$> value .: "Minio" <*> value .: "Pulsar" <*> value .: "Kubernetes"

instance FromJSON Minio where
  parseJSON = withObject "Minio" $ \value -> Minio
    <$> value .: "readyPointerWrittenLast" <*> value .: "resultAndReceiptReadBack"
    <*> value .: "directBearerStatus"

instance FromJSON Pulsar where
  parseJSON = withObject "Pulsar" $ \value -> Pulsar
    <$> value .: "topics" <*> value .: "before" <*> value .: "after"

instance FromJSON Kubernetes where
  parseJSON = withObject "Kubernetes" $ \value -> Kubernetes
    <$> value .: "workerPodUid" <*> value .: "argv0"

instance FromJSON Cleanup where
  parseJSON = withObject "Cleanup" $ \value -> Cleanup
    <$> value .: "KeycloakRealm" <*> value .: "KubernetesNamespace"
    <*> value .: "MinioBucket" <*> value .: "PulsarTenant"

instance FromJSON Universal where
  parseJSON = withObject "Universal" $ \value -> Universal
    <$> value .: "availableOnEveryHardwareSubstrate" <*> value .: "pristineLinuxHost"

instance FromJSON Pristine where
  parseJSON = withObject "Pristine" $ \value -> Pristine
    <$> value .: "linux" <*> value .: "linux-cuda" <*> value .: "apple" <*> value .: "windows"

instance FromJSON Honesty where
  parseJSON = withObject "Honesty" $ \value -> Honesty
    <$> value .: "typedUiAdapter" <*> value .: "realBrowser" <*> value .: "tenantKeycloakSessions"
    <*> value .: "retainedProviderIntegration" <*> value .: "browserThroughEnvoyToUiServer"
    <*> value .: "kubernetesUiServerReplicas" <*> value .: "phase50NativeCborChain"
    <*> value .: "fullPhase49InferenceOutputCorrespondence" <*> value .: "productionTinyLlama"
    <*> value .: "generalNoninterference" <*> value .: "redisSocketRecovery"

instance FromJSON Prerequisite where
  parseJSON = withObject "Prerequisite" $ \value -> Prerequisite
    <$> value .: "phase49ReceiptFingerprint" <*> value .: "phase49Result"

main :: IO ()
main = do
  root <- projectRoot
  bytes <- ByteString.readFile (root </> "DEVELOPMENT_PLAN/evidence/phase_50/infernix-ui-live.json")
  evidence <- either die pure (eitherDecodeStrict' bytes)
  verify evidence
  putStrLn "infernix-ui-lift-live-gate: PASS-SCOPED (real browser/tenant sessions/providers, durable receipt, denial, cleanup)"

verify :: Evidence -> IO ()
verify (Evidence register substrate result authority browser workflow providers cleanup universal honesty prerequisite) = do
  assert (register == 3 && substrate == "linux-cpu" && result == "PASS-SCOPED") "register/substrate/result"
  case authority of
    Authority stored sessions tokenDigests edgeDigest -> do
      assert (not stored && Map.keysSet sessions == Map.keysSet tokenDigests && Map.keys sessions == ["alice", "carol"] && digestShape edgeDigest) "authority-domain"
      case (Map.lookup "alice" sessions, Map.lookup "carol" sessions) of
        (Just (Session True "alice" "t-a"), Just (Session True "carol" "t-b")) -> pure ()
        _ -> die "tenant-session-domain"
  case browser of
    Browser engine statuses visible hostileText hostileHtml scripts ->
      assert (engine == "google-chrome/playwright-core" && statuses == replicate 4 200 && visible == "FRESH-CHALLENGE" && hostileText == "<SCRIPT>PORT:ADMIN</SCRIPT>" && "&lt;SCRIPT&gt;" `Text.isInfixOf` hostileHtml && scripts == 0) "browser"
  case workflow of
    Workflow command work handle outcome (Counts starts dispatch artifactReads writes) foreignStatus delta replica source ->
      assert (command == work && "cmd:" `Text.isPrefixOf` command && digestShape handle && outcome == "TerminalSucceeded" && [starts, dispatch, artifactReads, writes] == [1, 1, 1, 1] && foreignStatus == 404 && delta == 0 && replica == "replica-b" && source == "MinIO durable receipt") "workflow"
  case providers of
    Providers (Minio ready readback bearer) (Pulsar topics before after) (Kubernetes uid argv0) ->
      assert (ready && readback && bearer == 403 && length topics == 2 && all (== 0) (Map.elems before) && all (== 1) (Map.elems after) && not (Text.null uid) && argv0 == "/usr/bin/python3") "providers"
  case cleanup of Cleanup keycloak kubernetes minio pulsar -> assert (and [keycloak, kubernetes, minio, pulsar]) "cleanup"
  case universal of
    Universal available (Pristine linux linuxCuda apple windows) ->
      assert (available && linux == "Incus" && linuxCuda == "Incus" && apple == "Lima" && windows == "WSL2") "universal-linux-cpu"
  case honesty of
    Honesty adapter realBrowser sessions retained edge replicas cbor correspondence production general redis ->
      assert (all (== "TESTED") [adapter, realBrowser, sessions, retained] && all (== "UNVERIFIED") [edge, replicas, cbor, correspondence, production, general, redis]) "honesty"
  case prerequisite of
    Prerequisite fingerprint phase49 -> assert (digestShape fingerprint && phase49 == "PASS-SCOPED") "infernix-lift-prerequisite"

digestShape :: Text -> Bool
digestShape value = "sha256:" `Text.isPrefixOf` value && Text.length value == 71

projectRoot :: IO FilePath
projectRoot = getCurrentDirectory >>= ascend
 where
  ascend path = do
    found <- doesFileExist (path </> "cabal.project")
    if found then pure path else let parent = takeDirectory path in if parent == path then die "infernix-ui-lift-project-root" else ascend parent

assert :: Bool -> String -> IO ()
assert condition label = unless condition (die label)
