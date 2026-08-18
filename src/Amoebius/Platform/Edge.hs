{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Platform.Edge
  ( BrowserSurface (..)
  , EdgeDemand (..)
  , ProvisionedEdge
  , provisionEdge
  , provisionedRoutes
  , renderEdge
  , RecreateWitness (..)
  , validateRecreateWitness
  ) where

import Amoebius.Platform.Types
import Data.List (nub)
import Data.Text (Text)
import Data.Text qualified as Text

data BrowserSurface
  = GrafanaSurface
  | KeycloakAdminSurface
  | VaultUiSurface
  | MinioConsoleSurface
  | PlatformApiSurface
  | AuthenticatedWebSocketSurface
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data EdgeDemand = EdgeDemand
  { edgeImage :: Text
  , edgeRoutes :: [BrowserSurface]
  , edgeWildOwner :: Text
  , edgeOidcGuard :: Bool
  , edgeExactOrigin :: Bool
  , edgeSingleUseNonce :: Bool
  , edgeExactSubprotocol :: Bool
  , edgeDirectBackendPublished :: Bool
  , edgeControllerResources :: ResourceEnvelope
  , edgeDataPlaneResources :: ResourceEnvelope
  }
  deriving stock (Eq, Show)

data ProvisionedEdge = ProvisionedEdge
  { provisionedDemand :: EdgeDemand
  , provisionedRoutes :: [BrowserSurface]
  }
  deriving stock (Eq, Show)

provisionEdge :: EdgeDemand -> Either Text ProvisionedEdge
provisionEdge demand = do
  _ <- traverse validateResourceEnvelope [edgeControllerResources demand, edgeDataPlaneResources demand]
  let routes = edgeRoutes demand
  if null routes || length routes /= length (nub routes) || routes /= [minBound .. maxBound]
    then Left "edge-route-inventory-not-exact"
    else if edgeWildOwner demand /= "Keycloak"
      then Left "wild-ingress-owner-must-be-keycloak"
      else if not (effectiveOidc demand)
        then Left "oidc-guard-required"
        else if not (effectiveOrigin demand)
          then Left "websocket-exact-origin-required"
          else if not (effectiveNonce demand)
            then Left "websocket-single-use-nonce-required"
            else if not (edgeExactSubprotocol demand)
              then Left "websocket-exact-subprotocol-required"
              else if effectiveDirect demand
                then Left "direct-websocket-backend-forbidden"
                else if isPublic (edgeImage demand)
                  then Left "public-edge-image-forbidden"
                  else Right (ProvisionedEdge demand routes)
 where
#ifdef KEYCLOAK_INGRESS_DROP_OIDC_MUTANT
  effectiveOidc _ = False
#else
  effectiveOidc = edgeOidcGuard
#endif
#ifdef KEYCLOAK_INGRESS_DROP_ORIGIN_MUTANT
  effectiveOrigin _ = False
#else
  effectiveOrigin = edgeExactOrigin
#endif
#ifdef KEYCLOAK_INGRESS_NONCE_REPLAY_MUTANT
  effectiveNonce _ = False
#else
  effectiveNonce = edgeSingleUseNonce
#endif
#ifdef KEYCLOAK_INGRESS_DIRECT_BACKEND_MUTANT
  effectiveDirect _ = True
#else
  effectiveDirect = edgeDirectBackendPublished
#endif
  isPublic image = any (`Text.isPrefixOf` image) ["docker.io/", "quay.io/", "ghcr.io/"]

renderEdge :: ProvisionedEdge -> [PlatformObject]
renderEdge provision =
  [ object "Deployment" "envoy-gateway" 1 ["/usr/bin/envoy-gateway"] (edgeControllerResources demand)
  , object "Deployment" "envoy" 2 ["/usr/bin/envoy", "-c", "/etc/envoy/envoy.yaml"] (edgeDataPlaneResources demand)
  , PlatformObject "Gateway" "edge-system" "keycloak-edge" 1 "" [] Nothing Nothing Nothing
  , PlatformObject "HTTPRoute" "edge-system" "keycloak-owned-routes" 1 "" [] Nothing Nothing Nothing
  ]
 where
  demand = provisionedDemand provision
  object kind name replicas arguments resources =
    PlatformObject kind "edge-system" name replicas (edgeImage demand) arguments (Just resources) Nothing Nothing

data RecreateWitness = RecreateWitness
  { recreateOldClusterIdentity :: Text
  , recreateNewClusterIdentity :: Text
  , recreateMarkerByteIdentical :: Bool
  }
  deriving stock (Eq, Show)

validateRecreateWitness :: RecreateWitness -> Either Text RecreateWitness
validateRecreateWitness witness
  | effectiveNew witness == recreateOldClusterIdentity witness = Left "cluster-recreate-identity-unchanged"
  | not (recreateMarkerByteIdentical witness) = Left "cluster-recreate-marker-drift"
  | otherwise = Right witness
 where
#ifdef KEYCLOAK_INGRESS_DELETE_NOOP_MUTANT
  effectiveNew = recreateOldClusterIdentity
#else
  effectiveNew = recreateNewClusterIdentity
#endif
