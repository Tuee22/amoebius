{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Capacity.PulumiExecution
import Amoebius.Capacity.ServiceStorage
import Amoebius.Capacity.Storage
import Amoebius.Platform.BringUp
import Amoebius.Platform.Observability
import Amoebius.Platform.Postgres
import Amoebius.Platform.Redis
import Amoebius.Platform.Services
import Amoebius.Platform.Types
import Control.Monad (unless)
import Data.Aeson (encode)
import Data.ByteString.Lazy.Char8 qualified as Lazy
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import Numeric.Natural (Natural)
import System.Environment (getArgs)
import System.Exit (die)

main :: IO ()
main = do
  arguments <- getArgs
  postgres <- requireRight (provisionPostgresService postgresDemand)
  observability <- requireRight (provisionObservability observabilityDemand)
  redis <- requireRight (provisionRedis redisDemand)
  let rendered = renderPlatformServices postgres observability redis
  case arguments of
    ["--render-plan"] -> Lazy.putStr (encode rendered)
    [] -> verifyAll postgres observability redis rendered
    _ -> die "usage: platform-services-2-services-spec [--render-plan]"

verifyAll :: ProvisionedPostgresService -> ProvisionedObservability -> ProvisionedRedis -> [PlatformObject] -> IO ()
verifyAll postgres observability redis rendered = do
  patroniOracle <- TextIO.readFile "test/fixture/platform_services_2/patroni-sync-config.golden"
  assertEqual "Patroni configuration oracle" patroniOracle (patroniConfigurationText (provisionedPatroniConfiguration postgres))
  assertEqual "Grafana is exact database consumer" "Grafana" (postgresConsumer (provisionedPostgresDemand postgres))
  assertEqual "Patroni HA topology" 3 (postgresMemberReplicas (provisionedPostgresDemand postgres))
  assertEqual "Patroni storage includes data WAL checkpoint failover recovery" 54525952 (serviceStoragePeakBytes (provisionedPostgresStorage postgres))
  assertEqual "Prometheus derived storage boundary" 67108864 (provisionedPrometheusRequiredUsableBytes observability)
  assertBool "Prometheus presentation rounds above usable" (provisionedPrometheusRawBytes observability > provisionedPrometheusRequiredUsableBytes observability)
  assertBool "Prometheus one-byte-under raw rejects" (isLeft (provisionObservability observabilityDemand {observabilityBacking = prometheusBacking {backingCapacityBytes = provisionedPrometheusRawBytes observability - 1}}))
  assertEqual "Redis primary plus replicas" 3 (redisDataReplicas (provisionedRedisDemand redis))
  assertEqual "Redis Sentinel voters" 3 (redisSentinelReplicas (provisionedRedisDemand redis))
  assertBool "Redis is ephemeral" (not (redisPersistenceRequested (provisionedRedisDemand redis)))
  dagOracle <- TextIO.readFile "test/fixture/platform_services_2/dag-edges.golden"
  assertEqual "declared DAG equals independent oracle" dagOracle (renderEdges declaredDependencies)
  _ <- requireRightString (deriveReadinessLevels declaredDependencies)
  let droppedEdge = Map.adjust (Set.delete PerconaOperator) GrafanaPostgres oracleDependencies
  assertBool "edge mutation changes declared graph" (droppedEdge /= oracleDependencies && PerconaOperator `Set.notMember` (droppedEdge Map.! GrafanaPostgres))
  assertEqual "cycle rejected" (Left "readiness-cycle") (deriveReadinessLevels (Map.adjust (Set.insert Grafana) PerconaOperator oracleDependencies))
  assertEqual "representative render set" 11 (length rendered)
  assertBool "complete resource envelopes" (all exactEnvelope rendered)
  assertBool "cache and accelerator absent" (all ((== Nothing) . objectCache) rendered && all ((== Nothing) . objectAccelerator) rendered)
  assertBool "private baked image only" (all (\row -> objectImage row == privateImage) rendered)
  putStrLn "platform-services-2-services-spec: PASS (Patroni strict sync, derived monitoring/Redis bounds, independent readiness DAG, 11 Haskell projections)"

renderEdges :: Map.Map Service (Set.Set Service) -> Text
renderEdges graph = Text.unlines
  [ Text.pack (show service) <> "|" <> Text.intercalate "," (fmap (Text.pack . show) (Set.toAscList dependencies))
  | (service, dependencies) <- Map.toAscList graph
  ]

privateImage :: Text
privateImage = "registry.amoebius.invalid:5000/amoebius/base@sha256:224ce702545f17825dd18eb7108c9a72ea914e1b5ae01218ad955ab624cd94d4"

envelope :: Natural -> Natural -> Natural -> Natural -> ResourceEnvelope
envelope memoryRequest memoryLimit ephemeralRequest ephemeralLimit =
  ResourceEnvelope 25 250 memoryRequest memoryLimit ephemeralRequest ephemeralLimit

smallEnvelope, mediumEnvelope, largeEnvelope :: ResourceEnvelope
smallEnvelope = envelope 33554432 134217728 16777216 67108864
mediumEnvelope = envelope 67108864 268435456 16777216 134217728
largeEnvelope = envelope 134217728 536870912 33554432 268435456

postgresDemand :: PostgresServiceDemand
postgresDemand =
  PostgresServiceDemand
    privateImage
    "Grafana"
    3
    (PatroniConfiguration True True 1048576)
    ( PatroniSqlDemand
        "grafana"
        33554432
        8388608
        4194304
        4194304
        4194304
        (StorageBacking (BackingId "grafana-postgres") 805306368 (BackingAllocationPolicy 67108864 67108864))
    )
    smallEnvelope
    smallEnvelope
    largeEnvelope
    smallEnvelope
    mediumEnvelope

prometheusBacking :: StorageBacking
prometheusBacking = StorageBacking (BackingId "prometheus") 134217728 (BackingAllocationPolicy 67108864 67108864)

monitoringBudget :: MonitoringWorkBudget
monitoringBudget = MonitoringWorkBudget 8 16 256 512 4 64 4096 10 1024 33554432 33554432 67108864

observabilityDemand :: ObservabilityDemand
observabilityDemand =
  ObservabilityDemand
    privateImage
    monitoringBudget
    (QueryWorkBudget 4 64 4096 3600 30)
    15
    3600
    (FilesystemPresentation "ext4-v1" 500)
    prometheusBacking
    largeEnvelope
    smallEnvelope
    mediumEnvelope

redisDemand :: RedisDemand
redisDemand =
  RedisDemand
    privateImage
    3
    3
    67108864
    128
    8388608
    120
    "vault:secret/phase31/redis-tls"
    False
    False
    smallEnvelope
    smallEnvelope

exactEnvelope :: PlatformObject -> Bool
exactEnvelope object = case objectResources object of
  Nothing -> objectKind object == "PerconaPGCluster"
  Just resource ->
    requestCpuMillis resource == 25
      && limitCpuMillis resource == 250
      && requestMemoryBytes resource > 0
      && limitMemoryBytes resource >= requestMemoryBytes resource
      && limitEphemeralBytes resource >= requestEphemeralBytes resource

isLeft :: Either left right -> Bool
isLeft value = case value of
  Left _ -> True
  Right _ -> False

requireRight :: Show problem => Either problem value -> IO value
requireRight = either (die . show) pure

requireRightString :: Either String value -> IO value
requireRightString = either die pure

assertBool :: String -> Bool -> IO ()
assertBool label condition = unless condition (die label)

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual = unless (expected == actual) (die (label <> ": expected " <> show expected <> ", got " <> show actual))
