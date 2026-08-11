{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Platform.Postgres
  ( PatroniConfiguration (..)
  , PostgresServiceDemand (..)
  , ProvisionedPostgresService (..)
  , provisionPostgresService
  , patroniConfigurationText
  , renderPostgresService
  ) where

import Amoebius.Capacity.ServiceStorage
import Amoebius.Platform.Types
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)

data PatroniConfiguration = PatroniConfiguration
  { patroniSynchronousMode :: Bool
  , patroniSynchronousModeStrict :: Bool
  , patroniMaximumLagOnFailover :: Natural
  }
  deriving stock (Eq, Ord, Show)

data PostgresServiceDemand = PostgresServiceDemand
  { postgresImage :: Text
  , postgresConsumer :: Text
  , postgresMemberReplicas :: Natural
  , postgresPatroniConfiguration :: PatroniConfiguration
  , postgresStorageDemand :: PatroniSqlDemand
  , postgresOperatorResources :: ResourceEnvelope
  , postgresWebhookResources :: ResourceEnvelope
  , postgresMemberResources :: ResourceEnvelope
  , postgresGatewayResources :: ResourceEnvelope
  , postgresPgAdminResources :: ResourceEnvelope
  }
  deriving stock (Eq, Show)

data ProvisionedPostgresService = ProvisionedPostgresService
  { provisionedPostgresDemand :: PostgresServiceDemand
  , provisionedPostgresStorage :: ProvisionedServiceStorage
  , provisionedPatroniConfiguration :: PatroniConfiguration
  }
  deriving stock (Eq, Show)

provisionPostgresService :: PostgresServiceDemand -> Either Text ProvisionedPostgresService
provisionPostgresService demand = do
  _ <- traverse validateResourceEnvelope
    [ postgresOperatorResources demand
    , postgresWebhookResources demand
    , postgresMemberResources demand
    , postgresGatewayResources demand
    , postgresPgAdminResources demand
    ]
  let configuration = effectiveConfiguration demand
  if postgresConsumer demand /= "Grafana"
    then Left "postgres-consumer-set-must-be-grafana"
    else if postgresMemberReplicas demand < 3
      then Left "patroni-ha-topology-required"
      else if not (patroniSynchronousMode configuration)
        then Left "synchronous_mode-not-on"
        else if not (patroniSynchronousModeStrict configuration)
          then Left "synchronous_mode_strict-not-on"
          else if patroniMaximumLagOnFailover configuration == 0
            then Left "maximum_lag_on_failover-unbounded"
            else do
              storage <- either (Left . Text.pack . show) Right (provisionPatroniSql (postgresStorageDemand demand))
              Right (ProvisionedPostgresService demand storage configuration)
 where
#ifdef PHASE31_PATRONI_ASYNC_DEFAULT_MUTANT
  effectiveConfiguration row = (postgresPatroniConfiguration row) {patroniSynchronousModeStrict = False}
#else
  effectiveConfiguration = postgresPatroniConfiguration
#endif

patroniConfigurationText :: PatroniConfiguration -> Text
patroniConfigurationText configuration =
  Text.unlines
    [ "synchronous_mode: " <> boolValue (patroniSynchronousMode configuration)
    , "synchronous_mode_strict: " <> boolValue (patroniSynchronousModeStrict configuration)
    , "maximum_lag_on_failover: " <> Text.pack (show (patroniMaximumLagOnFailover configuration))
    ]
 where
  boolValue True = "on"
  boolValue False = "off"

renderPostgresService :: ProvisionedPostgresService -> [PlatformObject]
renderPostgresService provision =
  [ object "Deployment" "postgres-operator" "percona-operator" 1
      ["/usr/bin/percona-postgresql-operator"] (Just (postgresOperatorResources demand))
  , object "Deployment" "postgres-operator" "percona-webhook" 1
      ["/bin/bash", "-ec", "exec /usr/bin/percona-postgresql-operator"] (Just (postgresWebhookResources demand))
  , object "PerconaPGCluster" "grafana-db" "grafana" (postgresMemberReplicas demand)
      [patroniConfigurationText (provisionedPatroniConfiguration provision)] Nothing
  , object "StatefulSet" "grafana-db" "grafana-postgres" (postgresMemberReplicas demand)
      ["/bin/bash", "-ec", "exec /usr/local/bin/patroni /etc/patroni/patroni.yml"] (Just (postgresMemberResources demand))
  , object "Deployment" "grafana-db" "grafana-sql-gateway" 1
      ["/bin/bash", "-ec", "/usr/lib/postgresql/17/bin/pg_isready -h grafana-primary -p 5432; exec /usr/bin/tail -f /dev/null"] (Just (postgresGatewayResources demand))
  , object "Deployment" "grafana-db" "grafana-pgadmin" 1
      ["/bin/bash", "-ec", "mkdir -p /tmp/pgadmin; unset LD_LIBRARY_PATH; export PYTHONPATH=/venv/lib/python3.12/site-packages:/pgadmin4; exec /lib/ld-musl-x86_64.so.1 /usr/bin/pgadmin-python3.12 /pgadmin4/pgAdmin4.py"] (Just (postgresPgAdminResources demand))
  ]
 where
  demand = provisionedPostgresDemand provision
  object kind namespace name replicas arguments resources =
    PlatformObject kind namespace name replicas (postgresImage demand) arguments resources Nothing Nothing
