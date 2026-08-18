{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Platform.Observability
  ( QueryWorkBudget (..)
  , ObservabilityDemand (..)
  , ProvisionedObservability (..)
  , provisionObservability
  , renderObservability
  ) where

import Amoebius.Capacity.PulumiExecution
import Amoebius.Capacity.Storage
import Amoebius.Platform.Types
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)

data QueryWorkBudget = QueryWorkBudget
  { queryMaximumConcurrent :: Natural
  , queryMaximumSeries :: Natural
  , queryMaximumSamples :: Natural
  , queryMaximumRangeSeconds :: Natural
  , queryTimeoutSeconds :: Natural
  }
  deriving stock (Eq, Ord, Show)

data ObservabilityDemand = ObservabilityDemand
  { observabilityImage :: Text
  , observabilityMonitoringBudget :: MonitoringWorkBudget
  , observabilityQueryBudget :: QueryWorkBudget
  , observabilityEvaluationIntervalSeconds :: Natural
  , observabilityRetentionSeconds :: Natural
  , observabilityPresentation :: FilesystemPresentation
  , observabilityBacking :: StorageBacking
  , observabilityPrometheusResources :: ResourceEnvelope
  , observabilityQueryProxyResources :: ResourceEnvelope
  , observabilityGrafanaResources :: ResourceEnvelope
  }
  deriving stock (Eq, Show)

data ProvisionedObservability = ProvisionedObservability
  { provisionedObservabilityDemand :: ObservabilityDemand
  , provisionedMonitoringWork :: ProvisionedMonitoringWork
  , provisionedPrometheusRequiredUsableBytes :: Natural
  , provisionedPrometheusRawBytes :: Natural
  }
  deriving stock (Eq, Show)

provisionObservability :: ObservabilityDemand -> Either Text ProvisionedObservability
provisionObservability demand = do
  _ <- traverse validateResourceEnvelope
    [ observabilityPrometheusResources demand
    , observabilityQueryProxyResources demand
    , observabilityGrafanaResources demand
    ]
  validateFiniteQuery (observabilityQueryBudget demand)
  if observabilityEvaluationIntervalSeconds demand == 0 || observabilityRetentionSeconds demand == 0
    then Left "monitoring-interval-and-retention-required"
    else do
      work <- either (Left . Text.pack . show) Right (provisionMonitoringWork (effectiveMonitoringBudget demand))
      let usable = provisionedMonitoringStorageBytes work
          raw = roundAllocation (backingAllocation (observabilityBacking demand)) (presentBytes (observabilityPresentation demand) usable)
      _ <- either (Left . Text.pack . show) Right (fitBacking (observabilityBacking demand) raw)
      Right (ProvisionedObservability demand work usable raw)
 where
#ifdef PLATFORM_SERVICES_2_FIXED_PROMETHEUS_MUTANT
  effectiveMonitoringBudget row = (observabilityMonitoringBudget row) {monitoringTsdbTemporaryBytes = 0}
#else
  effectiveMonitoringBudget = observabilityMonitoringBudget
#endif
  validateFiniteQuery budget
    | any (== 0)
        [ queryMaximumConcurrent budget
        , queryMaximumSeries budget
        , queryMaximumSamples budget
        , queryMaximumRangeSeconds budget
        , queryTimeoutSeconds budget
        ] = Left "query-work-budget-unbounded"
    | otherwise = Right ()

renderObservability :: ProvisionedObservability -> [PlatformObject]
renderObservability provision =
  [ object "StatefulSet" "prometheus" 1
      [ "/usr/bin/prometheus"
      , "--config.file=/etc/prometheus/prometheus.yml"
      , "--storage.tsdb.path=/prometheus"
      , "--storage.tsdb.retention.time=" <> seconds (observabilityRetentionSeconds demand)
      , "--storage.tsdb.retention.size=" <> bytes (provisionedPrometheusRequiredUsableBytes provision)
      , "--query.max-concurrency=" <> natural (queryMaximumConcurrent query)
      , "--query.max-samples=" <> natural (queryMaximumSamples query)
      , "--query.timeout=" <> seconds (queryTimeoutSeconds query)
      ] (observabilityPrometheusResources demand)
  , object "Deployment" "prometheus-query-proxy" 1
      [ "/usr/bin/python3"
      , "/platform-services-2-query-proxy/query_proxy.py"
      , "--max-concurrent=" <> natural (queryMaximumConcurrent query)
      , "--max-series=" <> natural (queryMaximumSeries query)
      , "--max-samples=" <> natural (queryMaximumSamples query)
      , "--max-range-seconds=" <> natural (queryMaximumRangeSeconds query)
      , "--timeout-seconds=" <> natural (queryTimeoutSeconds query)
      ] (observabilityQueryProxyResources demand)
  , object "Deployment" "grafana" 1
      ["/usr/share/grafana/bin/grafana", "server", "--homepath=/usr/share/grafana"] (observabilityGrafanaResources demand)
  ]
 where
  demand = provisionedObservabilityDemand provision
  query = observabilityQueryBudget demand
  object kind name replicas arguments resources =
    PlatformObject kind "observability" name replicas (observabilityImage demand) arguments (Just resources) Nothing Nothing
  natural = Text.pack . show
  seconds value = natural value <> "s"
  bytes value = natural value <> "B"
