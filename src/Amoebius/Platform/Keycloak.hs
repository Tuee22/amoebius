{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Platform.Keycloak
  ( KeycloakDemand (..)
  , ProvisionedKeycloak
  , provisionKeycloak
  , renderKeycloak
  ) where

import Amoebius.Platform.Types
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)

data KeycloakDemand = KeycloakDemand
  { keycloakImage :: Text
  , keycloakReplicas :: Natural
  , keycloakDatabaseConsumer :: Text
  , keycloakPatroniReplicas :: Natural
  , keycloakSynchronousMode :: Bool
  , keycloakSynchronousModeStrict :: Bool
  , keycloakMaximumLagBytes :: Natural
  , keycloakDatabaseRawBytes :: Natural
  , keycloakResources :: ResourceEnvelope
  , keycloakDatabaseResources :: ResourceEnvelope
  }
  deriving stock (Eq, Show)

newtype ProvisionedKeycloak = ProvisionedKeycloak KeycloakDemand
  deriving stock (Eq, Show)

provisionKeycloak :: KeycloakDemand -> Either Text ProvisionedKeycloak
provisionKeycloak demand = do
  _ <- traverse validateResourceEnvelope [keycloakResources demand, keycloakDatabaseResources demand]
  if keycloakDatabaseConsumer demand /= "Keycloak"
    then Left "keycloak-database-consumer-mismatch"
    else if keycloakReplicas demand == 0
      then Left "keycloak-replica-required"
      else if keycloakPatroniReplicas demand < 3
        then Left "keycloak-patroni-ha-required"
        else if not (keycloakSynchronousMode demand && keycloakSynchronousModeStrict demand)
          then Left "keycloak-patroni-strict-sync-required"
          else if keycloakMaximumLagBytes demand == 0
            then Left "keycloak-patroni-lag-bound-required"
            else if keycloakDatabaseRawBytes demand < 268435456 * keycloakPatroniReplicas demand
              then Left "keycloak-database-backing-too-small"
              else if any (`Text.isPrefixOf` keycloakImage demand) ["docker.io/", "quay.io/", "ghcr.io/"]
                then Left "public-keycloak-image-forbidden"
                else Right (ProvisionedKeycloak demand)

renderKeycloak :: ProvisionedKeycloak -> [PlatformObject]
renderKeycloak (ProvisionedKeycloak demand) =
  [ object "PerconaPGCluster" "keycloak" (keycloakPatroniReplicas demand) [] Nothing
  , object "StatefulSet" "keycloak-postgres" (keycloakPatroniReplicas demand)
      ["/bin/bash", "-ec", "exec /usr/local/bin/patroni /etc/patroni/patroni.yml"] (Just (keycloakDatabaseResources demand))
  , object "Deployment" "keycloak" (keycloakReplicas demand)
      ["/opt/keycloak/bin/kc.sh", "start", "--import-realm"] (Just (keycloakResources demand))
  ]
 where
  object kind name replicas arguments resources =
    PlatformObject kind "edge-system" name replicas (keycloakImage demand) arguments resources Nothing Nothing
