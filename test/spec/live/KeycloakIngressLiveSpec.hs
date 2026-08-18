{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Monad (unless)
import Data.Aeson (FromJSON, Result (Error, Success), Value (Object), eitherDecodeFileStrict', fromJSON)
import Data.Aeson.Key (Key)
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Exit (die)

main :: IO ()
main = do
  decoded <- eitherDecodeFileStrict' "DEVELOPMENT_PLAN/evidence/phase_32/keycloak-ingress-live.json"
  evidence <- either die pure decoded
  expectedDigest <- Text.strip <$> TextIO.readFile "test/fixture/keycloak_ingress/expected-base-digest.txt"
  either die pure (verify expectedDigest evidence)
  putStrLn "keycloak-ingress-keycloak-ingress-live-spec: PASS (sole OIDC edge, WebSocket guard, derived policy, exact rebind markers)"

verify :: Text -> Value -> Either String ()
verify expectedDigest evidence = do
  equal ["schema"] ("amoebius.phase32.keycloak-ingress-live.v1" :: Text)
  equal ["register"] (3 :: Int)
  equal ["substrate"] ("linux-cpu" :: Text)
  true ["prerequisites", "phase31ReceiptObserved"]
  equal ["prerequisites", "patroniReplicas"] (3 :: Int)
  equal ["artifactSource", "digest"] expectedDigest
  equal ["artifactSource", "imagePullPolicy"] ("Never" :: Text)
  equal ["artifactSource", "publicPulls"] (0 :: Int)
  equal ["artifactSource", "pullEvents", "publicPullEventCount"] (0 :: Int)
  true ["artifactSource", "allRuntimeImageIdsMatchBaseDigest"]
  true ["artifactSource", "completeResourceFields"]
  equal ["artifactSource", "publicImageReferences"] ([] :: [Text])
  equal ["artifactSource", "ssa", "fieldManager"] ("amoebius" :: Text)
  positive ["artifactSource", "ssa", "observedObjectCount"]
  true ["vaultMaterial", "vaultSourced"]
  false ["vaultMaterial", "literalRecorded"]
  equal ["database", "readyReplicas"] (3 :: Int)
  true ["database", "strictSynchronous"]
  equal ["database", "maximumLagOnFailoverBytes"] (1048576 :: Integer)
  equal ["database", "namespace"] ("keycloak-db" :: Text)
  equal ["database", "backingPatroniCluster"] ("keycloak" :: Text)
  true ["database", "dedicatedPerConsumerCluster"]
  true ["database", "perconaCrObserved"]
  true ["database", "manualChildProjection"]
  true ["keycloak", "ready"]
  true ["keycloak", "wildIngressOwner"]
  equal ["gatewayApi", "apiVersion"] ("gateway.networking.k8s.io/v1" :: Text)
  true ["gatewayApi", "manualDataPlaneProjection"]
  true ["gatewayController", "ready"]
  equal ["loadBalancer", "ip"] ("172.18.255.201" :: Text)
  equal ["loadBalancer", "unauthenticatedStatus"] (401 :: Int)
  equal ["loadBalancer", "soleLoadBalancer"] ("edge-system/envoy" :: Text)
  true ["readinessGating", "loadBalancerAddressWithheld"]
  true ["readinessGating", "keycloakReadinessWithheld"]
  true ["readinessGating", "wildAdmitBlocked"]
  objectSize ["routeInventory", "host"] 5
  objectSize ["routeInventory", "origins", "wan", "statuses"] 5
  objectSize ["routeInventory", "origins", "lan", "statuses"] 5
  objectSize ["routeInventory", "origins", "localhost-browser", "statuses"] 5
  equal ["websocket", "valid", "status"] (101 :: Int)
  true ["websocket", "valid", "challengeMatched"]
  equal ["websocket", "replayedNonce", "status"] (409 :: Int)
  equal ["websocket", "wrongOrigin", "status"] (403 :: Int)
  equal ["websocket", "wrongSubprotocol", "status"] (426 :: Int)
  equal ["websocket", "forbiddenBackendChallenges"] (0 :: Int)
  true ["directBackend", "denied"]
  false ["directBackend", "backendTraceContainsDirectChallenge"]
  true ["backdoorScanner", "seedTurnedScannerRed"]
  true ["backdoorScanner", "restoredGreen"]
  equal ["backdoorScanner", "violationsAfterRemoval"] ([] :: [Text])
  equal ["hostLocalPeer", "endpointType"] ("HostLocalPeer" :: Text)
  equal ["hostLocalPeer", "hostLoopbackStatus"] (200 :: Int)
  true ["hostLocalPeer", "offHostDenied"]
  true ["tlsAndAcme", "eabMaterialPresent"]
  false ["tlsAndAcme", "eabValuesRecorded"]
  equal ["tlsAndAcme", "dhallLiteralScan"] ("clear" :: Text)
  true ["networkPolicy", "defaultDenyApplied"]
  true ["networkPolicy", "setEquality"]
  true ["networkPolicy", "graphVariation", "deniedBefore"]
  true ["networkPolicy", "graphVariation", "allowedAfterGraphAdd"]
  true ["networkPolicy", "graphVariation", "deniedAfterGraphRemove"]
  true ["markersBeforeRegression", "keycloakPatroni", "byteIdentical"]
  true ["markersBeforeRegression", "minio", "byteIdentical"]
  true ["storageRebindRegression", "freshCluster", "allIdentitiesChanged"]
  true ["storageRebindRegression", "markers", "allByteIdentical"]
  true ["universalLinuxCpu", "availableOnEveryHardwareSubstrate"]
  equal ["universalLinuxCpu", "pristineLinuxHost", "linux"] ("Incus" :: Text)
  equal ["universalLinuxCpu", "pristineLinuxHost", "linux-cuda"] ("Incus" :: Text)
  equal ["universalLinuxCpu", "pristineLinuxHost", "apple"] ("Lima" :: Text)
  equal ["universalLinuxCpu", "pristineLinuxHost", "windows"] ("WSL2" :: Text)
 where
  equal :: (Eq value, Show value, FromJSON value) => [Key] -> value -> Either String ()
  equal path expected = do
    actual <- get path evidence
    unless (actual == expected) (Left (showPath path <> ": expected " <> show expected <> ", got " <> show actual))
  true path = equal path True
  false path = equal path False
  positive path = do
    actual <- get path evidence
    unless ((actual :: Int) > 0) (Left (showPath path <> ": not positive"))
  objectSize path expected = do
    actual <- lookupPath path evidence
    case actual of
      Object value -> unless (KeyMap.size value == expected) (Left (showPath path <> ": wrong object size"))
      _ -> Left (showPath path <> ": not an object")

get :: FromJSON value => [Key] -> Value -> Either String value
get path value = do
  selected <- lookupPath path value
  case fromJSON selected of
    Error problem -> Left (showPath path <> ": " <> problem)
    Success decoded -> Right decoded

lookupPath :: [Key] -> Value -> Either String Value
lookupPath [] value = Right value
lookupPath (key : rest) (Object object) =
  maybe (Left (showPath (key : rest) <> ": absent")) (lookupPath rest) (KeyMap.lookup key object)
lookupPath path _ = Left (showPath path <> ": parent is not an object")

showPath :: [Key] -> String
showPath = Text.unpack . Text.intercalate "." . fmap (Text.pack . show)
