{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Fabric.Keys
import Amoebius.Fabric.WgReconcile
import Amoebius.Fabric.WgRender
import Amoebius.Vault.Client
import Amoebius.Vault.Error (VaultError (..))
import Control.Monad (forM_, unless, when)
import Data.Aeson (Value (..), eitherDecodeFileStrict')
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.ByteString as ByteString
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import System.Environment (lookupEnv)
import System.Exit (die)
import System.FilePath ((</>))

main :: IO ()
main = do
  let root = "."
  verifyCustody root
  inventory <- either (die . Text.unpack) pure representativeInventory
  rendered <- case renderFabric inventory of
    Left GatewayEndpointMissing -> die "phase41-hub-no-endpoint: gateway-role Endpoint missing from spoke config"
    Left failure -> die ("render:" <> show failure)
    Right value -> pure value
  golden <- TextIO.readFile (root </> "test/fixtures/phase41/expected-peer-config.golden")
  require (renderPeerConfig rendered == golden) "phase41-hub-no-endpoint: rendered peer config differs from independent golden"
  verifyNegativeCorpus root inventory
  verifyKeys
  provisioned <- either (die . ("provision:" <>) . show) pure (provisionFabricDemand inventory representativeDemand)
  expectedDemand <- decodeValue (root </> "test/fixtures/phase41/expected-fabric-demand.json")
  require (provisionedDemandJson provisioned == expectedDemand) "fabric demand differs from independent oracle"
  verifyCapacity provisioned
  verifyReconcile rendered provisioned
  pureOnly <- (== Just "1") <$> lookupEnv "PHASE41_PURE_ONLY"
  unless pureOnly (verifyLiveEvidence root)
  putStrLn "phase41-wireguard-live-gate: PASS (Vault-by-name keys, exact render/demand, one-shot admission, kernel observers)"

verifyCustody :: FilePath -> IO ()
verifyCustody root = do
  manifest <- TextIO.readFile (root </> "test/oracle/preimplementation_artifacts.tsv")
  let phaseRows = filter (Text.isPrefixOf "41\t") (Text.lines manifest)
  require (length phaseRows == 9) "phase41 Phase-0 custody must contain five oracles and four mutants"
  forM_
    [ "dhall/examples/wireguard_fabric.dhall"
    , "test/fixtures/phase41/expected-peer-config.golden"
    , "test/fixtures/phase41/expected-fabric-demand.json"
    , "test/fixtures/phase41/reachability-expected.json"
    , "test/fixtures/phase41/negative-expected-tags.tsv"
    , "test/fixtures/phase41/mutants/missing-peer-key.patch"
    , "test/fixtures/phase41/mutants/hub-no-endpoint.patch"
    , "test/fixtures/phase41/mutants/drop-resource-envelope.patch"
    , "test/fixtures/phase41/mutants/early-listener-replacement.patch"
    ] $ \path -> require (Text.pack path `Text.isInfixOf` manifest) ("uncustodied Phase41 artifact: " <> path)

verifyNegativeCorpus :: FilePath -> FabricInventory -> IO ()
verifyNegativeCorpus root inventory = do
  tags <- TextIO.readFile (root </> "test/fixtures/phase41/negative-expected-tags.tsv")
  positive <- TextIO.readFile (root </> "dhall/examples/wireguard_fabric.dhall")
  inline <- TextIO.readFile (root </> "dhall/examples/illegal_wg_inline_key.dhall")
  require (rejectInlineKeyLiteral positive == Right ()) "positive SecretRef fixture was rejected"
  require (tagOf (rejectInlineKeyLiteral inline) == "gate1-inline-key-literal") "inline-key negative wrong reason"
  let peers = fabricPeers inventory
      overlapping = inventory {fabricPeers = case peers of
        first : second : rest -> first : second {peerVpnIp = peerVpnIp first} : rest
        _ -> peers}
  require (tagOf (renderFabric overlapping) == "decode-vpn-ip-overlap") "overlap negative wrong reason"
  require (tagOf (validateAllowedCidr (fabricCidr inventory) "10.88.0.0/16") == "decode-allowed-ips-outside-fabric") "out-of-CIDR negative wrong reason"
  forM_ ["gate1-inline-key-literal", "decode-vpn-ip-overlap", "decode-allowed-ips-outside-fabric"] $ \tag ->
    require (tag `Text.isInfixOf` tags) ("negative oracle missing tag: " <> Text.unpack tag)
 where
  tagOf result = either fabricErrorTag (const "unexpected-success") result

verifyKeys :: IO ()
verifyKeys = do
  refs <- either (die . Text.unpack) pure (peerKeyRef "secret" "amoebius/wireguard/test" "private" "public")
  let identity = KubernetesIdentity "fabric-system" "amoebius-singleton" "amoebius-wireguard"
      good = VaultTransport
        { authenticateKubernetes = \_ _ -> pure (Right (VaultToken "fresh-token"))
        , readKvField = \_ _ _ _ -> pure (Right "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")
        , decryptTransit = \_ _ _ -> pure (Left VaultDecryptDenied)
        }
      missing = good {readKvField = \_ _ _ _ -> pure (Left VaultSecretMissing)}
  resolved <- resolvePeerKeyPair good identity "fresh-jwt" refs
  require (either (const False) (\pair -> ByteString.length (privateKeyBytes pair) == 44 && ByteString.length (publicKeyBytes pair) == 44) resolved) "valid Curve25519 SecretRefs did not resolve"
  absent <- resolvePeerKeyPair missing identity "fresh-jwt" refs
  require (absent == Left VaultSecretMissing) "phase41-missing-peer-key: absent SecretRef did not fail closed"

verifyCapacity :: ProvisionedFabricDemand -> IO ()
verifyCapacity provisioned = do
  let exact = FabricCapacity 25 100 8388608 33554432 1245184 65536 1
  token <- either (die . show) pure (validateSnapshot "snapshot-A" exact provisioned)
  require (authorizeEnactment "snapshot-A" Nothing == Left MissingEnactmentToken) "phase41-drop-resource-envelope: missing token authorized"
  require (authorizeEnactment "snapshot-A" (Just (Fresh token)) == Right Consumed) "fresh enactment token rejected"
  require (authorizeEnactment "snapshot-B" (Just (Fresh token)) == Left SnapshotChanged) "stale snapshot authorized"
  require (authorizeEnactment "snapshot-A" (Just Consumed) == Left EnactmentAlreadyConsumed) "consumed token reused"
  let shortages =
        [ (exact {capacityCpuReservationMilli = 24}, CpuReservationShort)
        , (exact {capacityCpuCeilingMilli = 99}, CpuCeilingShort)
        , (exact {capacityMemoryReservationBytes = 8388607}, MemoryReservationShort)
        , (exact {capacityMemoryCeilingBytes = 33554431}, MemoryCeilingShort)
        , (exact {capacityNodeFsBytes = 1245183}, NodeFsShort)
        , (exact {capacityQueueBytes = 65535}, QueueShort)
        , (exact {capacityHostProcessSlots = 0}, HostProcessSlotShort)
        ]
  forM_ shortages $ \(capacity, expected) ->
    require (case validateSnapshot "snapshot-A" capacity provisioned of Left actual -> actual == expected; Right _ -> False) ("one-unit shortage wrong result: " <> show expected)

verifyReconcile :: [RenderedNode] -> ProvisionedFabricDemand -> IO ()
verifyReconcile rendered _ = do
  let absent = KernelObservation False [] False False
      converged = KernelObservation True ["gateway-root", "spoke-alpha"] True True
  require (not (null (reconcileActions rendered absent))) "first reconcile unexpectedly empty"
  require (null (reconcileActions rendered converged)) "second reconcile was not a no-op"
  require (replacementActions True == [ObserveOldListenerExit]) "phase41-early-listener-replacement: replacement overlapped old listener"
  require (replacementActions False == [StartReplacementListener]) "replacement did not start after observed exit"

verifyLiveEvidence :: FilePath -> IO ()
verifyLiveEvidence root = do
  evidence <- decodeValue (root </> "DEVELOPMENT_PLAN/evidence/phase_41/wireguard-live.json")
  require (lookupPath ["schema"] evidence == Just (String "amoebius.phase41.wireguard-live.v1")) "live evidence schema mismatch"
  require (lookupPath ["register"] evidence == Just (Number 3)) "live evidence register mismatch"
  require (lookupPath ["substrate"] evidence == Just (String "linux-cpu")) "live evidence substrate mismatch"
  forM_
    [ ["vault", "secretRefsOnly"]
    , ["vault", "freshKeysResolved"]
    , ["kernel", "icmpReachable"]
    , ["kernel", "tcpReachable"]
    , ["kernel", "wgShowMatched"]
    , ["underlay", "wireguardUdpObserved"]
    , ["underlay", "cleartextCanaryAbsent"]
    , ["resourceReadback", "withinProvision"]
    , ["cleanup", "exact"]
    , ["universalLinuxCpu", "availableOnEveryHardwareSubstrate"]
    ] $ \path -> require (lookupPath path evidence == Just (Bool True)) ("live evidence false/missing: " <> show path)
  require (lookupPath ["reconcile", "secondPassMutations"] evidence == Just (Number 0)) "live second reconcile mutated"
  require (lookupPath ["universalLinuxCpu", "pristineLinuxHost", "linux"] evidence == Just (String "Incus")) "pristine Linux mapping drifted"
  require (lookupPath ["universalLinuxCpu", "pristineLinuxHost", "linux-cuda"] evidence == Just (String "Incus")) "pristine Linux-CUDA mapping drifted"
  require (lookupPath ["universalLinuxCpu", "pristineLinuxHost", "apple"] evidence == Just (String "Lima")) "pristine Apple mapping drifted"
  require (lookupPath ["universalLinuxCpu", "pristineLinuxHost", "windows"] evidence == Just (String "WSL2")) "pristine Windows mapping drifted"
  forM_ ["brokerGeoReplication", "gatewayHubRepoint", "stretchedControlPlanePeer"] $ \surface ->
    require (lookupPath ["deferred", surface] evidence == Just (String "UNVERIFIED")) ("deferred surface was overclaimed: " <> Text.unpack surface)

decodeValue :: FilePath -> IO Value
decodeValue path = eitherDecodeFileStrict' path >>= either (die . ((path <> ": ") <>)) pure

lookupPath :: [Text] -> Value -> Maybe Value
lookupPath [] value = Just value
lookupPath (segment : rest) (Object fields) = KeyMap.lookup (Key.fromText segment) fields >>= lookupPath rest
lookupPath _ _ = Nothing

require :: Bool -> String -> IO ()
require condition message = when (not condition) (die message)
