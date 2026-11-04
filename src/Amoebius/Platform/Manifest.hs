{-# LANGUAGE OverloadedStrings #-}

-- | Complete backbone API objects. The constructor is private: image identity,
-- storage claims and every executor have passed their respective provisions.
module Amoebius.Platform.Manifest
  ( BackboneStage (..), BackboneRuntime (..), ProvisionedBackboneManifest
  , provisionBackboneManifest
  ) where

import Amoebius.Capacity.RenderSource (K8sObjectIdentity (..), ReconcileMode (ServerSideApply), RenderActivation (Immediate))
import Amoebius.Manifest.K8sObject
import Amoebius.Manifest.RenderAll (RenderProvisioned (renderAll))
import Amoebius.Platform.Provision
import Amoebius.Platform.S3Admission (GatewayPolicy, gatewayPolicyFromStorage)
import Amoebius.Platform.StoragePlan
import Amoebius.Platform.Registry (RegistryBackend (RegistryMinio), registryStorageConfiguration)
import Amoebius.Platform.Pulsar (PulsarBackboneDemand (..))
import Amoebius.Capacity.StorageGeometry (PulsarDemand (..), BookKeeperPolicy (..))
import Amoebius.Capacity.ZooKeeper (zkPreallocationKiB)
import Control.Monad (unless)
import Data.Aeson (Value (..), toJSON, encode)
import Data.ByteString.Lazy qualified as Lazy
import Data.Text.Encoding qualified as Text
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KM
import Data.List (sortOn)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as T

-- Stages describe readiness and the verified migration transition, rather than
-- accepting arbitrary caller-supplied Kubernetes objects or command fragments.
data BackboneStage = MetalLBStage | MinioStage | ApplicationGatewayStage | RegistrySourceStage | RegistryTargetStage | RegistryRetiredStage
  | ZooKeeperStage | PulsarMetadataStage | BookKeeperStage | PulsarBrokerStage
  deriving stock (Eq, Show)
data BackboneRuntime = BackboneRuntime
  { runtimeImage :: Text, runtimeNode :: Text, runtimeAddressPool :: Text }
  deriving stock (Eq, Show)
data ProvisionedBackboneManifest = ProvisionedBackboneManifest
  ProvisionedBackboneStorage ProvisionedBackboneServices BackboneRuntime BackboneStage GatewayPolicy ProvisionedZkMembers
  deriving stock (Eq, Show)

provisionBackboneManifest :: ProvisionedBackboneStorage -> ProvisionedBackboneServices
  -> BackboneRuntime -> BackboneStage -> Either Text ProvisionedBackboneManifest
provisionBackboneManifest storage services runtime stage = do
  bindObjectProducerWriters (backboneObjectProducers services) (backboneWriterAdmissions storage)
  gatewayPolicy <- gatewayPolicyFromStorage (backboneStorageProjection storage)
  metadataMembers <- backboneZooKeeperMemberDemand storage services >>= provisionZkMembers
  unless (("@" <> backboneRegistryIndexDigest storage) `T.isSuffixOf` runtimeImage runtime)
    (Left "backbone-manifest-image-provenance-mismatch")
  unless (all (not . T.null) [runtimeNode runtime, runtimeAddressPool runtime])
    (Left "backbone-manifest-runtime-identity-empty")
  mapM_ (\identity -> unless (backboneService services identity /= Nothing)
    (Left ("backbone-manifest-unprovisioned-service:" <> identity)))
    ["metallb-system/controller", "metallb-system/speaker", "platform-system/minio",
     "platform-system/registry-source", "platform-system/registry", "pulsar-system/zookeeper",
     "platform-system/object-gateway",
     "pulsar-system/bookkeeper", "pulsar-system/broker", "pulsar-system/pulsar-metadata", "pulsar-system/pulsar-tool"]
  pure (ProvisionedBackboneManifest storage services runtime stage gatewayPolicy metadataMembers)

instance RenderProvisioned ProvisionedBackboneManifest where
  renderAll = sortOn objectIdentity . objects

objects :: ProvisionedBackboneManifest -> [K8sObject]
objects (ProvisionedBackboneManifest storage services runtime stage _ metadataMembers) = case stage of
  MetalLBStage -> metallb
  MinioStage -> minio
  ApplicationGatewayStage -> gateway
  RegistrySourceStage -> registry True 1
  RegistryTargetStage -> registry False 1
  RegistryRetiredStage -> filter ((== DeploymentKind) . objectKind) (registry True 0)
  ZooKeeperStage -> zookeeper
  PulsarMetadataStage -> [metadataJob]
  BookKeeperStage -> bookkeeper
  PulsarBrokerStage -> brokers
 where
  platform = "platform-system"; pulsar = "pulsar-system"; metal = "metallb-system"
  image = runtimeImage runtime
  pulsarProfile = backbonePulsarProfile storage
  metadataOrdinals = fmap fromIntegral (zkMemberOrdinals metadataMembers) :: [Int]
  metadataRaw ordinal = maybe (error "private ZooKeeper member claim absent") id (zkMemberRawClaim metadataMembers (fromIntegral ordinal))
  bookkeeperPolicy = pulsarBookKeeperPolicy (pulsarStorage pulsarProfile)
  inventory = backboneVolumeInventory storage
  raw name = maybe (error "private backbone inventory incomplete") id (Map.lookup name inventory)
  service namespace name = maybe (error "private backbone service missing") id (backboneService services (namespace <> "/" <> name))
  native api kind namespace name fields = K8sObject
    (K8sObjectIdentity ((if kind == CustomResourceKind then case lookup "kind" fields of
      Just (String apiKind) -> apiKind; _ -> kindName kind else kindName kind) <> "/" <> namespace <> "/" <> name)) (T.unpack api) kind
    (ObjectMetadata name (if T.null namespace then Nothing else Just namespace)
      (Map.singleton "app.kubernetes.io/managed-by" "amoebius") Map.empty)
    (ExtensionSpec (Map.fromList fields)) Immediate ServerSideApply
  kindName = T.dropEnd 4 . T.pack . show
  v1 = native "v1"
  ns name = v1 NamespaceKind "" name []
  sa namespace = v1 ServiceAccountKind namespace "platform-backbone" []
  cm namespace name key contents = v1 ConfigMapKind namespace name [("data", o [(key, s contents)])]
  svc namespace name fields = v1 ServiceKind namespace name [("spec", o fields)]
  headless name app ports = svc pulsar name
    [("clusterIP", s "None"), ("publishNotReadyAddresses", b True), ("selector", labels app), ("ports", a ports)]
  port name number = o [("name", s name), ("port", n number)]
  cport name number = o [("name", s name), ("containerPort", n number)]
  labels app = o [("app", s app)]
  mount name path ro = o ([ ("name", s name), ("mountPath", s path)] <> [("readOnly", b True) | ro])
  host name path kind = o [("name", s name), ("hostPath", o [("path", s path), ("type", s kind)])]
  config name = o [("name", s "config"), ("configMap", o [("name", s name)])]
  env name value = o [("name", s name), ("value", s value)]
  probe field value delay count = o [(field, value), ("initialDelaySeconds", n delay), ("periodSeconds", n 2), ("failureThreshold", n count)]
  tcp number delay count = probe "tcpSocket" (o [("port", n number)]) delay count
  http path number = probe "httpGet" (o [("path", s path), ("port", n number)]) 0 90
  -- A single app executor per role; profile bytes own resources, writable
  -- scratch, root immutability, logs and the rollout admission calculation.
  pod namespace role containerFields podFields secretProfile =
    let provision = service namespace role
        scratch = platformServiceScratchBytes provision
        runtimeFields = [("name", s role), ("image", s image), ("imagePullPolicy", s "Never"),
          ("resources", if namespace == pulsar && role == "zookeeper" then zkMemberK8sResources metadataMembers else platformServiceK8sResources provision),
          ("securityContext", o ([("readOnlyRootFilesystem", b True), ("allowPrivilegeEscalation", b False),
            ("capabilities", o ([("drop", ts ["ALL"])] <> [("add", ts ["NET_RAW"]) | role == "speaker"]))]
            <> (if role == "speaker" then [("runAsUser", n 0), ("runAsGroup", n 0)] else [])))]
        extraEnv = if role == "minio" then
          [env "MINIO_API_REQUESTS_MAX" (showT (minioMaximumRequests standardMinioExecutionProfile)),
           env "GOMEMLIMIT" (showT (minioManagedHeapBytes standardMinioExecutionProfile) <> "B")] else []
        jvm = namespace == pulsar
        loggingEnv = [[env "PULSAR_LOG_CONF" "/phase30-logging/log4j2.yaml",
          env "PULSAR_GC_LOG" "-Xlog:gc*,safepoint:stdout:time,uptime,tags"] | jvm]
        suppliedEnv = case lookup "env" containerFields of Just (Array values) -> foldr (:) [] values; _ -> []
        suppliedMounts = case lookup "volumeMounts" containerFields of Just (Array values) -> foldr (:) [] values; _ -> []
        suppliedVolumes = case lookup "volumes" podFields of Just (Array values) -> foldr (:) [] values; _ -> []
        usesVault = not (null secretProfile) || role == "object-gateway"
        wrapper = [[("command", ts ["/amoebius-runtime/amoebius", "platform-service-exec"]), ("args", ts [profile])] | profile <- secretProfile]
        wrappedFields = if null secretProfile then containerFields else filter ((`notElem` ["command", "args"]) . fst) containerFields <> concat wrapper
        container = o (filter ((`notElem` ["env", "volumeMounts"]) . fst) wrappedFields <> runtimeFields
          <> [("env", a (suppliedEnv <> extraEnv <> concat loggingEnv)), ("volumeMounts", a (suppliedMounts <> [mount "scratch" "/tmp" False]
            <> [mount "pulsar-logging" "/phase30-logging" True | jvm]
            <> [mount "binary" "/amoebius-runtime/amoebius" True | usesVault]))])
     in o (filter ((/= "volumes") . fst) podFields <> [("containers", a [container]),
        ("volumes", a (suppliedVolumes <> [o [("name", s "scratch"), ("emptyDir", o [("sizeLimit", s (showT scratch))])]]
          <> [host "binary" "/amoebius-test/bin/amoebius" "File" | usesVault]
          <> [o [("name", s "pulsar-logging"), ("configMap", o [("name", s "pulsar-log-config")])] | jvm]))]
        <> [("serviceAccountName", s (case secretProfile of ["minio"] -> "minio-server"; ["registry"] -> "registry-writer"; ["pulsar-broker"] -> "pulsar-offload-writer"; _ -> "platform-backbone")) | usesVault])
  workload kind namespace name app replicas extra containerFields podFields profile =
    native (if kind == JobKind then "batch/v1" else "apps/v1") kind namespace name [("spec", o
      ([("replicas", n replicas) | kind `elem` [DeploymentKind, StatefulSetKind]]
        <> [("selector", o [("matchLabels", labels app)]) | kind /= JobKind]
        <> [(if kind == DeploymentKind then "strategy" else "updateStrategy", o [("type", s (if kind == DeploymentKind then "Recreate" else "OnDelete"))]) | kind /= JobKind]
        <> extra <> [("template", o [("metadata", o [("labels", labels app)]),
          ("spec", pod namespace name containerFields podFields profile)])]))]
  claim name bytes = o [("metadata", o [("name", s name)]), ("spec", o
    [("accessModes", ts ["ReadWriteOnce"]), ("storageClassName", s "amoebius-retained"),
      ("resources", o [("requests", o [("storage", s (showT bytes))])])])]
  pv namespace component ordinal claimName backing = v1 PersistentVolumeKind ""
    (namespace <> "." <> component <> "-" <> claimName <> ".pv-" <> showT ordinal) [("spec", o
      [("capacity", o [("storage", s (showT (if namespace == pulsar && component == "zookeeper" then metadataRaw ordinal else raw backing)))]), ("accessModes", ts ["ReadWriteOnce"]),
       ("storageClassName", s "amoebius-retained"), ("persistentVolumeReclaimPolicy", s "Retain"), ("volumeMode", s "Filesystem"),
       ("claimRef", o [("namespace", s namespace), ("name", s (claimName <> "-" <> component <> "-" <> showT ordinal))]),
       ("hostPath", o [("path", s ("/amoebius-retained/" <> backing)), ("type", s "Directory")]),
       ("nodeAffinity", o [("required", o [("nodeSelectorTerms", a [o [("matchExpressions", a [o
         [("key", s "kubernetes.io/hostname"), ("operator", s "In"), ("values", ts [runtimeNode runtime])]])]])])])])]
  replacement namespace component backing =
    [pv namespace component (0 :: Int) "replacement" backing,
     v1 PersistentVolumeClaimKind namespace ("replacement-" <> component <> "-0") [("spec", o
       [("accessModes", ts ["ReadWriteOnce"]), ("storageClassName", s "amoebius-retained"),
        ("volumeName", s (namespace <> "." <> component <> "-replacement.pv-0")),
        ("resources", o [("requests", o [("storage", s (showT (raw backing)))])])])]]
  crd (plural, singular, kind, versions) = native "apiextensions.k8s.io/v1" CustomResourceDefinitionKind "" (plural <> ".metallb.io") [("spec", o
    [("group", s "metallb.io"), ("scope", s "Namespaced"), ("names", o [("plural", s plural), ("singular", s singular), ("kind", s kind)]),
     ("versions", a [o [("name", s version), ("served", b True), ("storage", b (version == last versions)),
       ("schema", o [("openAPIV3Schema", o [("type", s "object"), ("x-kubernetes-preserve-unknown-fields", b True)])]),
       ("subresources", o [("status", o [])])] | version <- versions])])]
  custom name kind fields = native "metallb.io/v1beta1" CustomResourceKind metal name [("kind", s kind), ("spec", o fields)]
  metallb = [ns metal] <> fmap crd
    [("ipaddresspools", "ipaddresspool", "IPAddressPool", ["v1beta1"]),
     ("l2advertisements", "l2advertisement", "L2Advertisement", ["v1beta1"]),
     ("bgpadvertisements", "bgpadvertisement", "BGPAdvertisement", ["v1beta1"]),
     ("bfdprofiles", "bfdprofile", "BFDProfile", ["v1beta1"]),
     ("communities", "community", "Community", ["v1beta1"]),
     ("bgppeers", "bgppeer", "BGPPeer", ["v1beta1", "v1beta2"]),
     ("servicel2statuses", "servicel2status", "ServiceL2Status", ["v1beta1"]),
     ("servicebgpstatuses", "servicebgpstatus", "ServiceBGPStatus", ["v1beta1"])]
    <> [v1 ServiceAccountKind metal account [] | account <- ["controller", "speaker"]]
    <> [native "rbac.authorization.k8s.io/v1" ClusterRoleKind "" "phase30-metallb"
      [("rules", a [o [("apiGroups", ts ["*"]), ("resources", ts ["*"]), ("verbs", ts ["get", "list", "watch", "create", "update", "patch", "delete"])]])]]
    <> [native "rbac.authorization.k8s.io/v1" ClusterRoleBindingKind "" ("phase30-metallb-" <> account)
      [("roleRef", o [("apiGroup", s "rbac.authorization.k8s.io"), ("kind", s "ClusterRole"), ("name", s "phase30-metallb")]),
       ("subjects", a [o [("kind", s "ServiceAccount"), ("name", s account), ("namespace", s metal)]])] | account <- ["controller", "speaker"]]
    <> [workload DeploymentKind metal "controller" "metallb-controller" 1 []
      [("command", ts ["/usr/bin/metallb-controller"]), ("args", ts ["-webhook-mode=disabled", "-namespace=metallb-system", "-deployment=controller", "-ml-secret-name=memberlist"]),
       ("ports", a [cport "metrics" 7472])] [("serviceAccountName", s "controller")] [],
      workload DaemonSetKind metal "speaker" "metallb-speaker" 1 []
      [("command", ts ["/usr/bin/metallb-speaker"]), ("args", ts ["-namespace=metallb-system", "-ml-secret-key-path=/etc/ml", "-ml-labels=app=metallb-speaker", "-node-name=$(NODE_NAME)", "-pod-name=$(POD_NAME)"]),
       ("env", a [o [("name", s name), ("valueFrom", o [("fieldRef", o [("fieldPath", s field)])])] | (name, field) <- [("NODE_NAME", "spec.nodeName"), ("POD_NAME", "metadata.name")]]),
       ("volumeMounts", a [mount "memberlist" "/etc/ml" True])]
      [("serviceAccountName", s "speaker"), ("hostNetwork", b True), ("volumes", a [o [("name", s "memberlist"), ("secret", o [("secretName", s "memberlist")])]])] [],
      custom "phase30" "IPAddressPool" [("addresses", ts [runtimeAddressPool runtime])],
      custom "phase30" "L2Advertisement" [("ipAddressPools", ts ["phase30"])]]
  minio = [ns platform, sa platform, v1 ServiceAccountKind platform "minio-server" [],
    native "storage.k8s.io/v1" StorageClassKind "" "amoebius-retained"
      [("provisioner", s "kubernetes.io/no-provisioner"), ("reclaimPolicy", s "Retain"), ("volumeBindingMode", s "WaitForFirstConsumer")]]
    <> [pv platform "minio" (0 :: Int) ("data" <> showT i) ("phase30-minio-" <> showT i) | i <- [0..3 :: Int]]
    <> replacement platform "minio-replacement" "phase30-minio-replacement-0"
    <> [svc platform "minio-backend" [("selector", labels "minio"), ("ports", a [port "s3" 9000])],
      workload StatefulSetKind platform "minio" "minio" 1
        [("serviceName", s "minio-backend"), ("volumeClaimTemplates", a [claim ("data" <> showT i) (raw ("phase30-minio-" <> showT i)) | i <- [0..3 :: Int]])]
        [("ports", a [cport "s3" 9000]), ("readinessProbe", http "/minio/health/ready" 9000),
         ("volumeMounts", a [mount ("data" <> showT i) ("/data" <> showT i) False | i <- [0..3 :: Int]])]
        [("securityContext", o [("runAsUser", n 0), ("runAsGroup", n 0)])] ["minio"]]
  gateway = [v1 ServiceAccountKind platform "phase30-object-writer" [],
    cm platform "object-gateway-config" "storage.json" (Text.decodeUtf8 (Lazy.toStrict (encode (backboneStorageProjection storage)))),
    pv platform "object-gateway" (0 :: Int) "state" "phase30-gateway-state",
    svc platform "minio" [("type", s "LoadBalancer"), ("selector", labels "object-gateway"), ("ports", a [port "s3" 9000])],
    svc platform "object-gateway" [("selector", labels "object-gateway"), ("ports", a [port "http" 8081])],
    workload StatefulSetKind platform "object-gateway" "object-gateway" 1
      [("serviceName", s "object-gateway"), ("volumeClaimTemplates", a [claim "state" (raw "phase30-gateway-state")])]
      [("command", ts ["/amoebius-runtime/amoebius", "object-gateway"]),
       ("ports", a [cport "http" 8081, cport "s3" 9000]), ("readinessProbe", http "/ready" 8081),
       ("volumeMounts", a [mount "config" "/phase30-gateway" True, mount "state" "/gateway-state" False])]
      [("securityContext", o [("runAsUser", n 0), ("runAsGroup", n 0)]), ("volumes", a [config "object-gateway-config"])] []]
  registry filesystem replicas =
    let name = if filesystem then "registry-source" else "registry"
        configName = name <> "-config"
        storageConfig = if filesystem then "  filesystem:\n    rootdirectory: /var/lib/registry\n  maintenance:\n    readonly:\n      enabled: true\n"
          else T.drop (T.length "storage:\n") (T.replace "    v4auth: true\n" "    forcepathstyle: true\n    v4auth: true\n"
            (registryStorageConfiguration (RegistryMinio "http://minio.platform-system.svc:9000" "registry")))
     in [v1 ServiceAccountKind platform "registry-writer" [], cm platform configName "config.yml" ("version: 0.1\nlog:\n  level: info\nhttp:\n  addr: 0.0.0.0:5000\nstorage:\n" <> storageConfig),
       workload DeploymentKind platform name name replicas []
        [("command", ts ["/usr/bin/docker-registry"]), ("args", ts ["serve", "/etc/distribution/config.yml"]),
         ("ports", a [cport "registry" 5000]), ("readinessProbe", http "/v2/" 5000),
         ("volumeMounts", a ([mount "config" "/etc/distribution" True] <> [mount "source" "/var/lib/registry" True | filesystem]))]
        [("securityContext", o [("runAsUser", n 0), ("runAsGroup", n 0)]),
         ("volumes", a ([config configName] <> [host "source" "/amoebius-retained/phase30-registry-source" "Directory" | filesystem]))]
        ["registry" | not filesystem],
       svc platform "registry" [("selector", labels name), ("ports", a [port "registry" 5000])]]
  zookeeperConfig = T.unlines (["tickTime=2000", "initLimit=10", "syncLimit=5", "dataDir=/pulsar/data/zookeeper", "clientPort=2181",
    "maxClientCnxns=100", "admin.enableServer=false", "4lw.commands.whitelist=ruok,mntr,conf", "autopurge.snapRetainCount=3", "autopurge.purgeInterval=1", "forceSync=yes",
    "metricsProvider.className=org.apache.zookeeper.metrics.prometheus.PrometheusMetricsProvider", "metricsProvider.httpPort=8000"] <>
    ["server." <> showT (i+1) <> "=zookeeper-" <> showT i <> ".zookeeper.pulsar-system.svc.cluster.local:2888:3888" | i <- metadataOrdinals])
  loggingConfiguration = T.unlines ["Configuration:", "  status: ERROR", "  name: amoebius-pulsar",
    "  Appenders:", "    Console:", "      name: Console", "      target: SYSTEM_OUT", "      PatternLayout:",
    "        Pattern: '%d{ISO8601} [%t] %-5level %logger{36} - %msg%n'", "  Loggers:",
    "    Root:", "      level: info", "      AppenderRef:", "        ref: Console"]
  zookeeper = [ns pulsar, sa pulsar, cm pulsar "zookeeper-config" "zookeeper.conf" zookeeperConfig,
    cm pulsar "pulsar-log-config" "log4j2.yaml" loggingConfiguration,
    headless "zookeeper" "pulsar-zookeeper" [port "client" 2181, port "quorum" 2888, port "leader-election" 3888]]
    <> [pv pulsar "zookeeper" i "data" ("phase30-zookeeper-" <> showT i) | i <- metadataOrdinals]
    <> [workload StatefulSetKind pulsar "zookeeper" "pulsar-zookeeper" (length metadataOrdinals)
      [("serviceName", s "zookeeper"), ("podManagementPolicy", s "Parallel"), ("volumeClaimTemplates", a [claim "data" (metadataRaw (0 :: Int))])]
      [("command", ts ["/bin/bash", "-ec"]), ("args", ts ["ordinal=${HOSTNAME##*-}; printf '%s\\n' \"$((ordinal + 1))\" > /pulsar/data/zookeeper/myid; exec /pulsar/bin/pulsar zookeeper"]),
       ("env", a [env "PULSAR_ZK_CONF" "/phase30-config/zookeeper.conf", env "PULSAR_EXTRA_OPTS" ("-Dzookeeper.preAllocSize=" <> showT zkPreallocationKiB), env "PULSAR_MEM" "-Xms32m -Xmx96m -XX:MaxDirectMemorySize=32m", env "PULSAR_LOG_DIR" "/tmp"]),
       ("ports", a [cport "client" 2181, cport "quorum" 2888, cport "election" 3888]), ("readinessProbe", tcp 2181 2 90),
       ("volumeMounts", a [mount "config" "/phase30-config" True, mount "data" "/pulsar/data/zookeeper" False])]
      [("securityContext", o [("runAsUser", n 0), ("runAsGroup", n 0)]), ("volumes", a [config "zookeeper-config"])] []]
  metadataJob = workload JobKind pulsar "pulsar-metadata" "pulsar-metadata" 1
    [("backoffLimit", n 0), ("completions", n 1), ("parallelism", n 1),
     ("ttlSecondsAfterFinished", n 3600), ("activeDeadlineSeconds", n 300)]
    [("command", ts ["/pulsar/bin/pulsar"]), ("args", ts ["initialize-cluster-metadata", "--cluster", "phase30", "--zookeeper", "zookeeper:2181",
      "--configuration-store", "zookeeper:2181", "--web-service-url", "http://broker.pulsar-system.svc.cluster.local:8080", "--broker-service-url", "pulsar://broker.pulsar-system.svc.cluster.local:6650"]),
     ("env", a [env "PULSAR_MEM" "-Xms32m -Xmx96m -XX:MaxDirectMemorySize=32m", env "PULSAR_LOG_DIR" "/tmp"])] [("restartPolicy", s "Never")] []
  bookkeeperConfig = T.unlines ["bookiePort=3181", "allowLoopback=true", "metadataServiceUri=zk+hierarchical://zookeeper.pulsar-system.svc.cluster.local:2181/ledgers",
    "journalDirectories=/pulsar/data/bookkeeper/journal", "ledgerDirectories=/pulsar/data/bookkeeper/ledgers", "indexDirectories=/pulsar/data/bookkeeper/index", "useHostNameAsBookieID=true",
    "minUsableSizeForIndexFileCreation=1048576", "diskUsageThreshold=0.99", "diskUsageWarnThreshold=0.95", "journalMaxSizeMB=16", "journalPreAllocSizeMB=16", "ledgerStorageClass=org.apache.bookkeeper.bookie.SortedLedgerStorage",
    "pageSize=8192", "entryLogPerLedgerEnabled=false", "minorCompactionInterval=0", "majorCompactionInterval=0",
    "entryLogSizeLimit=16777216", "gcWaitTime=1000"]
  bookkeeper = [cm pulsar "bookkeeper-config" "bookkeeper.conf" bookkeeperConfig, headless "bookkeeper" "pulsar-bookie" [port "bookie" 3181, port "metrics" 8000]]
    <> replacement pulsar "bookkeeper-replacement" "phase30-bookkeeper-replacement-0"
    <> [pv pulsar "bookkeeper" i "data" ("phase30-bookkeeper-" <> showT i) | i <- [0..2 :: Int]]
    <> [workload StatefulSetKind pulsar "bookkeeper" "pulsar-bookie" 3
      [("serviceName", s "bookkeeper"), ("podManagementPolicy", s "Parallel"), ("volumeClaimTemplates", a [claim "data" (raw "phase30-bookkeeper-0")])]
      [("command", ts ["/bin/bash", "-ec"]), ("args", ts ["cp /phase30-config/bookkeeper.conf /tmp/bookkeeper.conf; printf 'advertisedAddress=%s.bookkeeper.pulsar-system.svc.cluster.local\\n' \"$HOSTNAME\" >> /tmp/bookkeeper.conf; exec /pulsar/bin/pulsar bookie"]),
       ("env", a [env "PULSAR_BOOKKEEPER_CONF" "/tmp/bookkeeper.conf", env "BOOKIE_MEM" "-Xms64m -Xmx128m -XX:MaxDirectMemorySize=64m", env "PULSAR_LOG_DIR" "/tmp"]),
       ("ports", a [cport "bookie" 3181, cport "metrics" 8000]), ("readinessProbe", tcp 3181 3 120),
       ("volumeMounts", a [mount "config" "/phase30-config" True, mount "data" "/pulsar/data/bookkeeper" False])]
      [("securityContext", o [("runAsUser", n 0), ("runAsGroup", n 0)]), ("volumes", a [config "bookkeeper-config"])] []]
  brokerConfig = T.unlines ["metadataStoreUrl=zk:zookeeper.pulsar-system.svc.cluster.local:2181", "configurationMetadataStoreUrl=zk:zookeeper.pulsar-system.svc.cluster.local:2181", "clusterName=phase30",
    "brokerServicePort=6650", "webServicePort=8080", "defaultNumberOfNamespaceBundles=1", "strictBookieAffinityEnabled=false",
    "managedLedgerDefaultEnsembleSize=" <> showT (bookKeeperEnsembleSize bookkeeperPolicy),
    "managedLedgerDefaultWriteQuorum=" <> showT (bookKeeperWriteQuorum bookkeeperPolicy),
    "managedLedgerDefaultAckQuorum=" <> showT (bookKeeperAckQuorum bookkeeperPolicy),
    "managedLedgerMaxEntriesPerLedger=5", "managedLedgerMinLedgerRolloverTimeMinutes=0", "managedLedgerMaxLedgerRolloverTimeMinutes=1", "brokerDeduplicationEnabled=true", "brokerDeduplicationEntriesInterval=1", "allowAutoTopicCreation=false",
    "managedLedgerOffloadDriver=aws-s3", "offloadersDirectory=/pulsar/offloaders", "s3ManagedLedgerOffloadRegion=us-east-1", "s3ManagedLedgerOffloadBucket=pulsar-offload",
    "s3ManagedLedgerOffloadServiceEndpoint=http://minio.platform-system.svc.cluster.local:9000", "s3ManagedLedgerOffloadMaxBlockSizeInBytes=5242880", "s3ManagedLedgerOffloadReadBufferSizeInBytes=1048576",
    "managedLedgerOffloadAutoTriggerSizeThresholdBytes=" <> maybe "-1" showT (pulsarSizeTriggerBytes pulsarProfile),
    "managedLedgerOffloadDeletionLagMs=0", "functionsWorkerEnabled=false", "brokerDeleteInactiveTopicsEnabled=false"]
  brokers = [v1 ServiceAccountKind pulsar "pulsar-offload-writer" [], cm pulsar "broker-config" "broker.conf" brokerConfig,
    headless "broker-headless" "pulsar-broker" [port "pulsar" 6650, port "http" 8080],
    svc pulsar "broker" [("selector", labels "pulsar-broker"), ("ports", a [port "pulsar" 6650, port "http" 8080])],
    workload StatefulSetKind pulsar "broker" "pulsar-broker" 2 [("serviceName", s "broker-headless"), ("podManagementPolicy", s "Parallel")]
      [("env", a [env "PULSAR_BROKER_CONF" "/tmp/broker.conf", env "PULSAR_MEM" "-Xms128m -Xmx256m -XX:MaxDirectMemorySize=128m", env "PULSAR_LOG_DIR" "/tmp"]),
       ("ports", a [cport "pulsar" 6650, cport "http" 8080]), ("readinessProbe", http "/admin/v2/clusters" 8080), ("volumeMounts", a [mount "config" "/phase30-config" True])]
      [("securityContext", o [("runAsUser", n 0), ("runAsGroup", n 0)]), ("volumes", a [config "broker-config"])] ["pulsar-broker"],
    workload DeploymentKind pulsar "pulsar-tool" "pulsar-tool" 1 []
      [("command", ts ["/bin/bash", "-ec"]), ("args", ts ["exec /usr/bin/tail -f /dev/null"]),
       ("env", a [env "PULSAR_MEM" "-Xms16m -Xmx64m -XX:MaxDirectMemorySize=32m", env "PULSAR_LOG_DIR" "/tmp"])] [] []]

o :: [(Text, Value)] -> Value
o = Object . KM.fromList . fmap (\(key, value) -> (Key.fromText key, value))
s :: Text -> Value
s = String
b :: Bool -> Value
b = Bool
n :: Int -> Value
n = toJSON
a :: [Value] -> Value
a = toJSON
ts :: [Text] -> Value
ts = toJSON
showT :: Show value => value -> Text
showT = T.pack . show
