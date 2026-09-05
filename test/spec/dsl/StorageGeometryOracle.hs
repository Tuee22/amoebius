{-# LANGUAGE OverloadedStrings #-}

module StorageGeometryOracle
  ( OracleRow (..)
  , MutantSpec (..)
  , expectedCalculusProjection
  , expectedRows
  , mutantSpecs
  ) where

import Data.Text (Text)
import Data.Text qualified as Text

-- This oracle deliberately imports no production storage module and no
-- fixture module.  Its values are an independently authored closed
-- expectation for the Phase-28 subject.
data OracleRow = OracleRow
  { oracleVariant :: Text
  , oracleFamily :: Text
  , oracleOperation :: Text
  , oracleExpected :: Text
  , oracleTwin :: Text
  , oracleCatalog :: Text
  }
  deriving stock (Eq, Show)

data MutantSpec = MutantSpec
  { mutantName :: Text
  , mutantFlag :: String
  , mutantVariant :: Text
  , mutantLocus :: Text
  }
  deriving stock (Eq, Show)

expectedRows :: [OracleRow]
expectedRows =
  [ row "direct-backing" "illegal_store_over_backing" "fit" "StorageOverBacking:direct" "3.19:logical-physical-fit"
  , row "bookkeeper-recovery" "illegal_hot_tier_over_bookie" "bookkeeper" "StorageOverBacking:bookkeeper" "3.19:logical-physical-fit"
  , row "minio-parity-healing-orphan" "illegal_store_over_backing" "minio" "StorageOverBacking:minio" "3.19:logical-physical-fit"
  , row "complete-failure-scenarios" "illegal_store_over_backing" "failure-scenarios" "FailureScenarioProductMismatch" "3.19:logical-physical-fit"
  , row "filesystem-overhead-rounding" "illegal_store_over_backing" "presentation" "StorageOverBacking:filesystem" "3.19:logical-physical-fit"
  , row "backing-allocation-rounding" "illegal_store_over_backing" "allocation" "StorageOverBacking:allocation" "3.19:logical-physical-fit"
  , row "uniform-claim-per-backing" "illegal_store_over_backing" "uniform-claims" "StorageOverBacking:uniform" "3.19:logical-physical-fit"
  , row "registry-upload-partials" "illegal_store_over_backing" "registry" "StorageOverBacking:registry" "3.19:logical-physical-fit"
  , row "zookeeper-recovery" "illegal_store_over_backing" "zookeeper" "StorageOverBacking:zookeeper" "3.19:logical-physical-fit"
  , row "patroni-wal-failover" "illegal_store_over_backing" "patroni" "StorageOverBacking:patroni" "3.19:logical-physical-fit"
  , row "vault-raft-audit" "illegal_store_over_backing" "vault" "StorageOverBacking:vault" "3.19:logical-physical-fit"
  , row "storage-migration-highwater" "illegal_store_over_backing" "storage-migration" "StorageOverBacking:migration" "3.19:logical-physical-fit"
  , row "schema-migration-highwater" "illegal_store_over_backing" "schema-migration" "StorageOverBacking:migration" "3.19:logical-physical-fit"
  , row "registry-backend-migration" "illegal_store_over_backing" "registry-migration" "StorageOverBacking:migration" "3.19:logical-physical-fit"
  , row "object-producer-inventory" "illegal_store_over_backing" "object-inventory" "ObjectProducerInventoryMismatch" "3.19:logical-physical-fit"
  , row "object-identity-conflict" "illegal_store_over_backing" "object-conflict" "ObjectIdentityConflict:shared" "3.19:logical-physical-fit"
  , row "object-count-quota" "illegal_store_over_backing" "object-count" "ObjectCountOverQuota:provider" "3.19:logical-physical-fit"
  , row "backup-medium-fit" "illegal_store_over_backing" "backup" "StorageOverBacking:backup" "3.53:backup-medium-fit"
  , row "disjoint-capacity-pool" "illegal_store_over_backing" "pool-ownership" "DisjointCapacityPoolViolation:shared-pool" "3.60:disjoint-capacity-pool"
  , row "restore-target-fit" "illegal_store_over_backing" "restore" "StorageOverBacking:restore" "3.67:restore-target-fit"
  , row "pulsar-durable-total" "illegal_topic_time_only_offload" "pulsar-durable" "PulsarDurableCeilingUnbounded:events" "3.19:logical-physical-fit"
  , row "pulsar-hot-tier-ceiling" "illegal_hot_tier_over_bookie" "pulsar-hot" "StorageOverBacking:bookie" "3.19:logical-physical-fit"
  , row "native-cache-pool" "illegal_cache_over_local_pool" "cache-native" "StorageOverBacking:cache" "3.60:disjoint-capacity-pool"
  , row "incluster-cache-budget" "illegal_incluster_cache_bound_mismatch" "cache-incluster" "CacheBudgetNestingViolation:models" "3.19:logical-physical-fit"
  , row "incluster-cache-emptydir" "illegal_incluster_cache_bound_mismatch" "cache-incluster" "CacheBudgetNestingViolation:models" "3.19:logical-physical-fit"
  , row "instance-store-root" "illegal_store_over_backing" "node-root" "StorageOverBacking:root" "3.60:disjoint-capacity-pool"
  , row "root-ebs-quota" "illegal_store_over_backing" "node-root" "StorageOverBacking:nodeRootStorage" "3.60:disjoint-capacity-pool"
  , row "control-plane-transition" "illegal_store_over_backing" "control-plane" "StorageOverBacking:control-plane" "3.19:logical-physical-fit"
  , row "scaling-fingerprint" "illegal_store_over_backing" "storage-scaling" "ScalingSnapshotMismatch:expected:stale" "3.19:logical-physical-fit"
  , row "scaling-shrink-highwater" "illegal_store_over_backing" "storage-scaling" "ScalingEnvelopeViolation" "3.19:logical-physical-fit"
  ]
 where
  row variant family operation expected catalog =
    OracleRow variant family operation expected ("legal_" <> variant) catalog

mutantSpecs :: [MutantSpec]
mutantSpecs =
  [ mutant "allocation-drop-quantum" "backing-allocation-rounding" "backing allocation rounding"
  , mutant "backing-accept-over" "direct-backing" "single-owner backing comparison"
  , mutant "backup-drop-retention" "backup-medium-fit" "retained backup generations"
  , mutant "bookkeeper-drop-quorum" "bookkeeper-recovery" "BookKeeper write-quorum bytes"
  , mutant "bookkeeper-drop-recovery" "bookkeeper-recovery" "BookKeeper failure recovery"
  , mutant "control-plane-drop-transition" "control-plane-transition" "etcd transition high-water"
  , mutant "filesystem-drop-overhead" "filesystem-overhead-rounding" "filesystem presentation"
  , mutant "incluster-cache-drop-nesting" "incluster-cache-budget" "cache budget nesting"
  , mutant "migration-drop-old" "storage-migration-highwater" "migration old-plus-new high-water"
  , mutant "minio-drop-healing" "minio-parity-healing-orphan" "MinIO healing workspace"
  , mutant "minio-drop-orphan" "minio-parity-healing-orphan" "failed-write orphan horizon"
  , mutant "minio-drop-parity" "minio-parity-healing-orphan" "MinIO parity bytes"
  , mutant "native-cache-double-spend" "native-cache-pool" "named cache backing"
  , mutant "object-accept-conflict" "object-identity-conflict" "physical identity and size conflict"
  , mutant "object-drop-count" "object-count-quota" "object-count geometry"
  , mutant "object-drop-producer-arm" "object-producer-inventory" "six-arm inventory equality"
  , mutant "patroni-drop-wal" "patroni-wal-failover" "Patroni WAL and failover peak"
  , mutant "pool-allow-alias" "disjoint-capacity-pool" "disjoint capacity ownership"
  , mutant "provider-root-debit-durable" "root-ebs-quota" "nodeRootStorage quota"
  , mutant "provider-root-under-size" "instance-store-root" "instance-store root"
  , mutant "pulsar-drop-durable" "pulsar-durable-total" "durable-total ceiling"
  , mutant "pulsar-drop-hot" "pulsar-hot-tier-ceiling" "physical hot-tier ceiling"
  , mutant "registry-drop-partials" "registry-upload-partials" "registry failed partials"
  , mutant "registry-migration-drop-workspace" "registry-backend-migration" "registry migration workspace"
  , mutant "restore-drop-workspace" "restore-target-fit" "restore target workspace"
  , mutant "scaling-drop-highwater" "scaling-shrink-highwater" "shrink migration witness"
  , mutant "scaling-ignore-fingerprint" "scaling-fingerprint" "observed snapshot fingerprint"
  , mutant "schema-drop-wal" "schema-migration-highwater" "schema migration WAL"
  , mutant "uniform-use-aggregate" "uniform-claim-per-backing" "per-backing uniform claim"
  , mutant "vault-drop-audit" "vault-raft-audit" "Vault audit rotation"
  , mutant "zookeeper-drop-recovery" "zookeeper-recovery" "ZooKeeper recovery overlap"
  ]
 where
  mutant name variant locus = MutantSpec name ("storage-geometry-" <> Text.unpack name <> "-mutant") variant locus

expectedCalculusProjection :: [(Text, Text)]
expectedCalculusProjection =
  [ ("calculus-kinds", "artifact,budget,lift,workflow,evidence")
  , ("component-names", "storage-negatives,storage-twins,positive-specs,envelope-properties,mutant-evidence")
  , ("projection-counts", "30,30,2,6,31")
  , ("resource-vector", "5,99,0,0")
  ]
