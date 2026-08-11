{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Manifest.NetworkPolicy
import Amoebius.Platform.Edge
import Amoebius.Platform.Keycloak
import Amoebius.Platform.Tls
import Amoebius.Platform.Types
import Control.Monad (unless)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import Numeric.Natural (Natural)
import System.Exit (die)

main :: IO ()
main = do
  edge <- requireRight (provisionEdge edgeDemand)
  keycloak <- requireRight (provisionKeycloak keycloakDemand)
  tls <- requireRight (provisionTls tlsDemand)
  routeOracle <- TextIO.readFile "test/fixtures/phase32/route-inventory.golden"
  assertEqual "route inventory oracle" routeOracle (renderRoutes (provisionedRoutes edge))
  policyOracle <- TextIO.readFile "test/fixtures/phase32/netpol-expected.golden"
  policyEdges <- requireRight (derivePolicyEdges dependencyGraph)
  assertEqual "network policy independent oracle" policyOracle (renderPolicyEdges policyEdges)
  assertBool "graph variation adds exactly one edge"
    (derivePolicyEdges (Map.adjust (Set.insert "minio") "scratch" dependencyGraph)
      == Right (Set.insert (PolicyEdge "scratch" "minio") policyEdges))
  assertBool "graph variation removal denies again"
    (derivePolicyEdges dependencyGraph == Right policyEdges)
  assertEqual "edge render count" 4 (length (renderEdge edge))
  assertEqual "Keycloak render count" 3 (length (renderKeycloak keycloak))
  assertEqual "TLS uses Vault SecretRef" "vault:secret/phase32/edge/eab" (tlsSecretRef tls)
  _ <- requireRight (validateRecreateWitness (RecreateWitness "cluster-old" "cluster-new" True))
  assertLeft "identical cluster identity rejected" "cluster-recreate-identity-unchanged"
    (validateRecreateWitness (RecreateWitness "same" "same" True))
  assertLeft "marker drift rejected" "cluster-recreate-marker-drift"
    (validateRecreateWitness (RecreateWitness "old" "new" False))
  assertLeft "wild owner rejection" "wild-ingress-owner-must-be-keycloak"
    (provisionEdge edgeDemand {edgeWildOwner = "workload"})
  assertLeft "EAB literal rejection" "tls-eab-literal-forbidden"
    (provisionTls tlsDemand {tlsEabLiteralPresent = True})
  putStrLn "phase32-edge-spec: PASS (Keycloak-only OIDC edge, exact routes, derived policies, TLS provenance, recreate witness)"

privateImage :: Text
privateImage = "registry.amoebius.invalid:5000/amoebius/base@sha256:224ce702545f17825dd18eb7108c9a72ea914e1b5ae01218ad955ab624cd94d4"

envelope :: Natural -> Natural -> ResourceEnvelope
envelope memoryRequest memoryLimit = ResourceEnvelope 25 500 memoryRequest memoryLimit 16777216 268435456

edgeDemand :: EdgeDemand
edgeDemand = EdgeDemand privateImage [minBound .. maxBound] "Keycloak" True True True True False
  (envelope 67108864 268435456) (envelope 67108864 268435456)

keycloakDemand :: KeycloakDemand
keycloakDemand = KeycloakDemand privateImage 1 "Keycloak" 3 True True 1048576 805306368
  (envelope 268435456 1073741824) (envelope 134217728 536870912)

tlsDemand :: TlsDemand
tlsDemand = TlsDemand "vault:secret/phase32/edge/eab" False 4 3 16777216 2 (envelope 33554432 134217728)

dependencyGraph :: Map.Map Text (Set.Set Text)
dependencyGraph = Map.fromList
  [ ("envoy", Set.fromList ["grafana", "keycloak", "minio", "platform-api", "vault", "websocket"])
  , ("grafana", Set.fromList ["grafana-postgres", "prometheus-query-proxy"])
  , ("grafana-postgres", Set.empty)
  , ("keycloak", Set.singleton "keycloak-postgres")
  , ("keycloak-postgres", Set.empty)
  , ("minio", Set.empty)
  , ("platform-api", Set.empty)
  , ("prometheus", Set.fromList ["minio", "pulsar"])
  , ("prometheus-query-proxy", Set.empty)
  , ("pulsar", Set.empty)
  , ("redis", Set.empty)
  , ("scratch", Set.empty)
  , ("sentinel", Set.singleton "redis")
  , ("vault", Set.empty)
  , ("websocket", Set.empty)
  ]

renderRoutes :: [BrowserSurface] -> Text
renderRoutes = Text.unlines . fmap renderRoute
 where
  renderRoute surface = case surface of
    GrafanaSurface -> "Grafana|/grafana/"
    KeycloakAdminSurface -> "KeycloakAdmin|/keycloak/"
    VaultUiSurface -> "VaultUi|/vault/"
    MinioConsoleSurface -> "MinioConsole|/minio/"
    PlatformApiSurface -> "PlatformApi|/platform/"
    AuthenticatedWebSocketSurface -> "AuthenticatedWebSocket|/ws"

requireRight :: Show problem => Either problem value -> IO value
requireRight = either (die . show) pure

assertBool :: String -> Bool -> IO ()
assertBool label condition = unless condition (die label)

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual = unless (expected == actual) (die (label <> ": expected " <> show expected <> ", got " <> show actual))

assertLeft :: (Eq problem, Show problem, Show value) => String -> problem -> Either problem value -> IO ()
assertLeft label expected actual = case actual of
  Left problem -> assertEqual label expected problem
  Right value -> die (label <> ": unexpectedly accepted " <> show value)
