{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

-- | A closed recipe derived from the detected lane set and compute engine.
-- Binary acquisition declarations live here; the bake catalog is a projection.
module Amoebius.Image.Recipe
  ( ImageRecipe, RecipeRefusal (..), recipeRefusalTag
  , imageRecipe, canonicalRecipe, recipeOwner, recipeEngine, recipeLanes
  , recipeStages, recipeSteps, recipeAcquisitionTools, recipeRuntimeEnvironment
  , recipeForbiddenPayloads, requireLane, laneTag, laneParent, renderRecipe
  , renderStepRows, renderLaneRows
  ) where

import Amoebius.Image.BakeInventory
import Amoebius.Topology.Lanes (laneLabel)
import Amoebius.Vocabulary qualified as V
import Data.List.NonEmpty (NonEmpty (..))
import Data.List.NonEmpty qualified as NonEmpty
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text

data ImageRecipe = ImageRecipe Text V.ComputeEngine (NonEmpty V.Lane) (NonEmpty BakeStage)
  deriving stock (Eq, Show)

data RecipeRefusal
  = InvalidRecipeOwner Text
  | NoImageLanes
  | UnrequiredLaneStep V.Lane
  | RecipeCatalogRefused CatalogError
  | RecipeRenderEmpty
  deriving stock (Eq, Show)

recipeRefusalTag :: RecipeRefusal -> Text
recipeRefusalTag refusal = case refusal of
  InvalidRecipeOwner _ -> "InvalidRecipeOwner"
  NoImageLanes -> "NoImageLanes"
  UnrequiredLaneStep _ -> "UnrequiredLaneStep"
  RecipeCatalogRefused _ -> "RecipeCatalogRefused"
  RecipeRenderEmpty -> "RecipeRenderEmpty"

imageRecipe :: Text -> V.ComputeEngine -> NonEmpty V.Detected -> Either RecipeRefusal ImageRecipe
imageRecipe owner engine detected
  | not (V.isLabel owner) = Left (InvalidRecipeOwner owner)
  | otherwise = case Set.toAscList required of
      [] -> Left NoImageLanes
      first : rest -> Right (makeRecipe owner engine (first :| rest))
 where
  required = Set.fromList [lane | host <- NonEmpty.toList detected, lane <- V.lanesOf host, lane /= V.AppleMetalOnHost]

-- | Compatibility for the ordinary catalog command. It renders declarations
-- for both CPU architectures and performs no discovery, build, or execution.
canonicalRecipe :: ImageRecipe
canonicalRecipe = makeRecipe "canonical" V.KindEngine (V.LinuxCpuAt V.Amd64 :| [V.LinuxCpuAt V.Arm64])

makeRecipe :: Text -> V.ComputeEngine -> NonEmpty V.Lane -> ImageRecipe
makeRecipe owner engine lanes = ImageRecipe owner engine lanes stages
 where
  first :| rest = baseStages
  stages = first :| (rest <> [rke2Stage | engine == V.Rke2Engine])

recipeOwner :: ImageRecipe -> Text
recipeOwner (ImageRecipe owner _ _ _) = owner
recipeEngine :: ImageRecipe -> V.ComputeEngine
recipeEngine (ImageRecipe _ engine _ _) = engine
recipeLanes :: ImageRecipe -> [V.Lane]
recipeLanes (ImageRecipe _ _ lanes _) = NonEmpty.toList lanes
recipeStages :: ImageRecipe -> [BakeStage]
recipeStages (ImageRecipe _ _ _ stages) = NonEmpty.toList stages
recipeSteps :: ImageRecipe -> [BakeStep]
recipeSteps recipe = concat [stage.content.head : stage.content.tail | stage <- recipeStages recipe]

requireLane :: ImageRecipe -> V.Lane -> Either RecipeRefusal ()
requireLane recipe lane
  | lane `elem` recipeLanes recipe = Right ()
  | otherwise = Left (UnrequiredLaneStep lane)

laneTag :: V.Lane -> Text
laneTag lane = case lane of
  V.LinuxCpuAt architecture -> "amoebius-base-cpu-" <> Text.pack (V.architectureName architecture)
  V.LinuxCudaAt architecture -> "amoebius-base-cuda-" <> Text.pack (V.architectureName architecture)
  V.AppleMetalOnHost -> "apple-metal-host-only"

laneParent :: V.Lane -> Text
laneParent lane = case lane of
  V.LinuxCpuAt _ -> "ubuntu:24.04"
  V.LinuxCudaAt _ -> "nvidia/cuda:12.8.2-devel-ubuntu24.04"
  V.AppleMetalOnHost -> "host-only"

renderLaneRows :: ImageRecipe -> [[Text]]
renderLaneRows recipe = [["lane", laneLabel lane, laneTag lane, laneParent lane] | lane <- recipeLanes recipe]

renderStepRows :: [BakeStep] -> [[Text]]
renderStepRows steps = zipWith row [1 :: Int ..] steps
 where
  row index step = ["step", Text.pack (show index), stepName step, stepRung step] <> case step of
    AptPackage value -> fields value.targetPath value.expectedVersion value.arguments value.kind
    OfficialArtifact value -> fields value.targetPath value.expectedVersion value.arguments value.kind
    BuildProduct value -> fields value.targetPath value.expectedVersion value.arguments value.kind
    CopyOci value -> fields value.targetPath value.expectedVersion value.arguments value.kind
  fields destination version arguments kind = [destination, version, Text.intercalate " " arguments, Text.pack (show kind)]

renderRecipe :: ImageRecipe -> Text
renderRecipe recipe = Text.unlines (map (Text.intercalate "\t")
  ([["recipe", recipeOwner recipe, Text.pack (show (recipeEngine recipe))] ] <> renderLaneRows recipe <> renderStepRows (recipeSteps recipe)))

rke2Stage :: BakeStage
rke2Stage = BakeStage
  { name = "rke2-node", dependencies = [], platforms = [Amd64, Arm64]
  , cpuReservationMillis = 250, cpuCeilingMillis = 500
  , memoryReservationBytes = 268435456, memoryCeilingBytes = 536870912
  , intermediateBytes = 536870912, cacheWriteBytes = 134217728
  , content = NonEmptyBakeSteps (OfficialArtifact rke2Binary) []
  }

rke2Binary :: PublishedArtifact
rke2Binary = PublishedArtifact
  { name = "rke2", publisher = "github.com/rancher/rke2", releaseVersion = "v1.34.1+rke2r1"
  , assets = [asset Amd64 "amd64", asset Arm64 "arm64"]
  , checksumAlgorithm = Sha256, checksumShape = DigestNamed, archiveFormat = TarGz
  , archiveMember = "rke2", targetPath = "/usr/local/bin/rke2", payloads = []
  , arguments = ["--version"], expectedVersion = "v1.34.1+rke2r1", kind = Elf
  }
 where
  asset platform architecture = ArtifactAsset platform (release <> "rke2.linux-" <> architecture <> ".tar.gz") (release <> "sha256sum-" <> architecture <> ".txt")
  release = "https://github.com/rancher/rke2/releases/download/v1.34.1%2Brke2r1/"

baseStages :: NonEmpty BakeStage
baseStages = platformServices :| [serviceBundles, amoebiusRuntime]

platformServices :: BakeStage
platformServices = BakeStage
  { name = "platform-services"
  , dependencies = []
  , platforms = [Amd64, Arm64]
  , cpuReservationMillis = 750
  , cpuCeilingMillis = 1500
  , memoryReservationBytes = 805306368
  , memoryCeilingBytes = 1610612736
  , intermediateBytes = 2147483648
  , cacheWriteBytes = 1073741824
  , content = NonEmptyBakeSteps { head = AptPackage (AptPackaged{name = "redis-server", package = "redis-server", packageVersion = "5:7.0.15-1ubuntu0.24.04.4", archiveSuite = "noble-updates/universe", targetPath = "/usr/bin/redis-server", arguments = ["--version"], expectedVersion = "7.0.15", kind = Elf}), tail = [AptPackage (AptPackaged{name = "redis-cli", package = "redis-tools", packageVersion = "5:7.0.15-1ubuntu0.24.04.4", archiveSuite = "noble-updates/universe", targetPath = "/usr/bin/redis-cli", arguments = ["--version"], expectedVersion = "7.0.15", kind = Elf}), AptPackage (AptPackaged{name = "postgres", package = "postgresql-16", packageVersion = "16.14-0ubuntu0.24.04.1", archiveSuite = "noble-updates/main", targetPath = "/usr/lib/postgresql/16/bin/postgres", arguments = ["--version"], expectedVersion = "16.14", kind = Elf}), AptPackage (AptPackaged{name = "patroni", package = "patroni", packageVersion = "3.2.2-2", archiveSuite = "noble/universe", targetPath = "/usr/bin/patroni", arguments = ["--version"], expectedVersion = "3.2.2", kind = Launcher}), AptPackage (AptPackaged{name = "temurin", package = "openjdk-21-jre-headless", packageVersion = "21.0.11+10-1~24.04.2", archiveSuite = "noble-updates/main", targetPath = "/usr/bin/java", arguments = ["--version"], expectedVersion = "21.0.11", kind = Elf}), AptPackage (AptPackaged{name = "g++", package = "g++", packageVersion = "4:13.2.0-7ubuntu1", archiveSuite = "noble/main", targetPath = "/usr/bin/g++", arguments = ["--version"], expectedVersion = "13.3.0", kind = Elf})] }
  }

serviceBundles :: BakeStage
serviceBundles = BakeStage
  { name = "service-bundles"
  , dependencies = []
  , platforms = [Amd64, Arm64]
  , cpuReservationMillis = 1000
  , cpuCeilingMillis = 2000
  , memoryReservationBytes = 1073741824
  , memoryCeilingBytes = 2147483648
  , intermediateBytes = 4294967296
  , cacheWriteBytes = 1073741824
  , content = NonEmptyBakeSteps{head = OfficialArtifact (PublishedArtifact{name = "minio", publisher = "dl.min.io", releaseVersion = "RELEASE.2025-07-23T15-54-02Z", assets = [ArtifactAsset{platform = Amd64, assetUrl = "https://dl.min.io/server/minio/release/linux-amd64/archive/minio.RELEASE.2025-07-23T15-54-02Z", checksumManifest = "https://dl.min.io/server/minio/release/linux-amd64/archive/minio.RELEASE.2025-07-23T15-54-02Z.sha256sum"}, ArtifactAsset{platform = Arm64, assetUrl = "https://dl.min.io/server/minio/release/linux-arm64/archive/minio.RELEASE.2025-07-23T15-54-02Z", checksumManifest = "https://dl.min.io/server/minio/release/linux-arm64/archive/minio.RELEASE.2025-07-23T15-54-02Z.sha256sum"}], checksumAlgorithm = Sha256, checksumShape = DigestNamed, archiveFormat = Bare, archiveMember = "", targetPath = "/usr/bin/minio", payloads = [], arguments = ["--version"], expectedVersion = "RELEASE.2025-07-23T15-54-02Z", kind = Elf}), tail = [OfficialArtifact (PublishedArtifact{name = "vault", publisher = "releases.hashicorp.com", releaseVersion = "1.20.2", assets = [ArtifactAsset{platform = Amd64, assetUrl = "https://releases.hashicorp.com/vault/1.20.2/vault_1.20.2_linux_amd64.zip", checksumManifest = "https://releases.hashicorp.com/vault/1.20.2/vault_1.20.2_SHA256SUMS"}, ArtifactAsset{platform = Arm64, assetUrl = "https://releases.hashicorp.com/vault/1.20.2/vault_1.20.2_linux_arm64.zip", checksumManifest = "https://releases.hashicorp.com/vault/1.20.2/vault_1.20.2_SHA256SUMS"}], checksumAlgorithm = Sha256, checksumShape = DigestNamed, archiveFormat = Zip, archiveMember = "vault", targetPath = "/usr/bin/vault", payloads = [], arguments = ["--version"], expectedVersion = "1.20.2", kind = Elf}), OfficialArtifact (PublishedArtifact{name = "prometheus", publisher = "github.com/prometheus/prometheus", releaseVersion = "3.5.0", assets = [ArtifactAsset{platform = Amd64, assetUrl = "https://github.com/prometheus/prometheus/releases/download/v3.5.0/prometheus-3.5.0.linux-amd64.tar.gz", checksumManifest = "https://github.com/prometheus/prometheus/releases/download/v3.5.0/sha256sums.txt"}, ArtifactAsset{platform = Arm64, assetUrl = "https://github.com/prometheus/prometheus/releases/download/v3.5.0/prometheus-3.5.0.linux-arm64.tar.gz", checksumManifest = "https://github.com/prometheus/prometheus/releases/download/v3.5.0/sha256sums.txt"}], checksumAlgorithm = Sha256, checksumShape = DigestNamed, archiveFormat = TarGz, archiveMember = "prometheus", targetPath = "/usr/bin/prometheus", payloads = [], arguments = ["--version"], expectedVersion = "3.5.0", kind = Elf}), OfficialArtifact (PublishedArtifact{name = "alertmanager", publisher = "github.com/prometheus/alertmanager", releaseVersion = "0.28.1", assets = [ArtifactAsset{platform = Amd64, assetUrl = "https://github.com/prometheus/alertmanager/releases/download/v0.28.1/alertmanager-0.28.1.linux-amd64.tar.gz", checksumManifest = "https://github.com/prometheus/alertmanager/releases/download/v0.28.1/sha256sums.txt"}, ArtifactAsset{platform = Arm64, assetUrl = "https://github.com/prometheus/alertmanager/releases/download/v0.28.1/alertmanager-0.28.1.linux-arm64.tar.gz", checksumManifest = "https://github.com/prometheus/alertmanager/releases/download/v0.28.1/sha256sums.txt"}], checksumAlgorithm = Sha256, checksumShape = DigestNamed, archiveFormat = TarGz, archiveMember = "alertmanager", targetPath = "/usr/bin/alertmanager", payloads = [], arguments = ["--version"], expectedVersion = "0.28.1", kind = Elf}), OfficialArtifact (PublishedArtifact{name = "thanos", publisher = "github.com/thanos-io/thanos", releaseVersion = "0.39.2", assets = [ArtifactAsset{platform = Amd64, assetUrl = "https://github.com/thanos-io/thanos/releases/download/v0.39.2/thanos-0.39.2.linux-amd64.tar.gz", checksumManifest = "https://github.com/thanos-io/thanos/releases/download/v0.39.2/sha256sums.txt"}, ArtifactAsset{platform = Arm64, assetUrl = "https://github.com/thanos-io/thanos/releases/download/v0.39.2/thanos-0.39.2.linux-arm64.tar.gz", checksumManifest = "https://github.com/thanos-io/thanos/releases/download/v0.39.2/sha256sums.txt"}], checksumAlgorithm = Sha256, checksumShape = DigestNamed, archiveFormat = TarGz, archiveMember = "thanos", targetPath = "/usr/bin/thanos", payloads = [], arguments = ["--version"], expectedVersion = "0.39.2", kind = Elf}), OfficialArtifact (PublishedArtifact{name = "envoy", publisher = "github.com/envoyproxy/envoy", releaseVersion = "1.35.1", assets = [ArtifactAsset{platform = Amd64, assetUrl = "https://github.com/envoyproxy/envoy/releases/download/v1.35.1/envoy-1.35.1-linux-x86_64", checksumManifest = "https://github.com/envoyproxy/envoy/releases/download/v1.35.1/checksums.txt.asc"}, ArtifactAsset{platform = Arm64, assetUrl = "https://github.com/envoyproxy/envoy/releases/download/v1.35.1/envoy-1.35.1-linux-aarch_64", checksumManifest = "https://github.com/envoyproxy/envoy/releases/download/v1.35.1/checksums.txt.asc"}], checksumAlgorithm = Sha256, checksumShape = DigestNamed, archiveFormat = Bare, archiveMember = "", targetPath = "/usr/bin/envoy", payloads = [], arguments = ["--version"], expectedVersion = "1.35.1", kind = Elf}), OfficialArtifact (PublishedArtifact{name = "grafana", publisher = "dl.grafana.com", releaseVersion = "12.1.1", assets = [ArtifactAsset{platform = Amd64, assetUrl = "https://dl.grafana.com/oss/release/grafana-12.1.1.linux-amd64.tar.gz", checksumManifest = "https://dl.grafana.com/oss/release/grafana-12.1.1.linux-amd64.tar.gz.sha256"}, ArtifactAsset{platform = Arm64, assetUrl = "https://dl.grafana.com/oss/release/grafana-12.1.1.linux-arm64.tar.gz", checksumManifest = "https://dl.grafana.com/oss/release/grafana-12.1.1.linux-arm64.tar.gz.sha256"}], checksumAlgorithm = Sha256, checksumShape = DigestOnly, archiveFormat = TarGz, archiveMember = "", targetPath = "/usr/share/grafana", payloads = [], arguments = ["--version"], expectedVersion = "12.1.1", kind = Elf}), OfficialArtifact (PublishedArtifact{name = "keycloak", publisher = "github.com/keycloak/keycloak", releaseVersion = "26.3.2", assets = [ArtifactAsset{platform = Amd64, assetUrl = "https://github.com/keycloak/keycloak/releases/download/26.3.2/keycloak-26.3.2.tar.gz", checksumManifest = "https://github.com/keycloak/keycloak/releases/download/26.3.2/keycloak-26.3.2.tar.gz.sha1"}, ArtifactAsset{platform = Arm64, assetUrl = "https://github.com/keycloak/keycloak/releases/download/26.3.2/keycloak-26.3.2.tar.gz", checksumManifest = "https://github.com/keycloak/keycloak/releases/download/26.3.2/keycloak-26.3.2.tar.gz.sha1"}], checksumAlgorithm = Sha1, checksumShape = DigestOnly, archiveFormat = TarGz, archiveMember = "", targetPath = "/opt/keycloak", payloads = [], arguments = ["--version"], expectedVersion = "26.3.2", kind = Launcher}), OfficialArtifact (PublishedArtifact{name = "pulsar", publisher = "archive.apache.org", releaseVersion = "4.0.6", assets = [ArtifactAsset{platform = Amd64, assetUrl = "https://archive.apache.org/dist/pulsar/pulsar-4.0.6/apache-pulsar-4.0.6-bin.tar.gz", checksumManifest = "https://downloads.apache.org/pulsar/pulsar-4.0.6/apache-pulsar-4.0.6-bin.tar.gz.sha512"}, ArtifactAsset{platform = Arm64, assetUrl = "https://archive.apache.org/dist/pulsar/pulsar-4.0.6/apache-pulsar-4.0.6-bin.tar.gz", checksumManifest = "https://downloads.apache.org/pulsar/pulsar-4.0.6/apache-pulsar-4.0.6-bin.tar.gz.sha512"}], checksumAlgorithm = Sha512, checksumShape = DigestNamed, archiveFormat = TarGz, archiveMember = "", targetPath = "/pulsar", payloads = [PublishedPayload{name = "pulsar-offloaders", assets = [ArtifactAsset{platform = Amd64, assetUrl = "https://archive.apache.org/dist/pulsar/pulsar-4.0.6/apache-pulsar-offloaders-4.0.6-bin.tar.gz", checksumManifest = "https://archive.apache.org/dist/pulsar/pulsar-4.0.6/apache-pulsar-offloaders-4.0.6-bin.tar.gz.sha512"}, ArtifactAsset{platform = Arm64, assetUrl = "https://archive.apache.org/dist/pulsar/pulsar-4.0.6/apache-pulsar-offloaders-4.0.6-bin.tar.gz", checksumManifest = "https://archive.apache.org/dist/pulsar/pulsar-4.0.6/apache-pulsar-offloaders-4.0.6-bin.tar.gz.sha512"}], checksumAlgorithm = Sha512, checksumShape = DigestNamed, archiveFormat = TarGz, archiveMember = "", targetPath = "/pulsar"}], arguments = ["version"], expectedVersion = "4.0.6", kind = Launcher})]}
  }

amoebiusRuntime :: BakeStage
amoebiusRuntime = BakeStage
  { name = "amoebius-runtime"
  , dependencies = ["platform-services", "service-bundles"]
  , platforms = [Amd64, Arm64]
  , cpuReservationMillis = 750
  , cpuCeilingMillis = 1500
  , memoryReservationBytes = 1073741824
  , memoryCeilingBytes = 1610612736
  , intermediateBytes = 4294967296
  , cacheWriteBytes = 2147483648
  , content = NonEmptyBakeSteps{head = BuildProduct (BuiltProduct{name = "amoebius-jit-build-resolver", source = AmoebiusSource (AmoebiusBinary{cabalTarget = "exe:amoebius"}), targetPath = "/usr/bin/amoebius", arguments = ["jit-build-resolver", "--version"], expectedVersion = "0.1.0.0", kind = Elf}), tail = [BuildProduct (BuiltProduct{name = "envoy-gateway", source = GoModule (GoBuild{repository = "https://github.com/envoyproxy/gateway", reference = "v1.4.2", packagePath = "./cmd/envoy-gateway", versionSymbol = "github.com/envoyproxy/gateway/internal/cmd/version.envoyGatewayVersion", versionValue = "v1.4.2", requiresCgo = False}), targetPath = "/usr/bin/envoy-gateway", arguments = ["version"], expectedVersion = "1.4.2", kind = Elf}), BuildProduct (BuiltProduct{name = "metallb-controller", source = GoModule (GoBuild{repository = "https://github.com/metallb/metallb", reference = "v0.15.2", packagePath = "./controller", versionSymbol = "", versionValue = "", requiresCgo = False}), targetPath = "/usr/bin/metallb-controller", arguments = ["-h"], expectedVersion = "0.15.2", kind = Elf}), BuildProduct (BuiltProduct{name = "metallb-speaker", source = GoModule (GoBuild{repository = "https://github.com/metallb/metallb", reference = "v0.15.2", packagePath = "./speaker", versionSymbol = "", versionValue = "", requiresCgo = False}), targetPath = "/usr/bin/metallb-speaker", arguments = ["-h"], expectedVersion = "0.15.2", kind = Elf}), BuildProduct (BuiltProduct{name = "percona-postgresql-operator", source = GoModule (GoBuild{repository = "https://github.com/percona/percona-postgresql-operator", reference = "v2.6.0", packagePath = "./cmd/postgres-operator", versionSymbol = "", versionValue = "", requiresCgo = True}), targetPath = "/usr/bin/percona-postgresql-operator", arguments = ["--version"], expectedVersion = "2.6.0", kind = Elf}), BuildProduct (BuiltProduct{name = "pgadmin", source = PythonPackage (PythonDistribution{distribution = "pgadmin4", distributionVersion = "9.6", interpreterVersion = "3.12"}), targetPath = "/pgadmin4", arguments = ["-c", "import sys; sys.path.insert(0, '/pgadmin4'); import config; print(config.APP_VERSION)"], expectedVersion = "9.6", kind = Launcher})]}
  }

recipeAcquisitionTools :: [AcquisitionTool]
recipeAcquisitionTools = [AcquisitionTool{package = "ca-certificates", packageVersion = "20260601~24.04.1", archiveSuite = "noble-updates/main"}, AcquisitionTool{package = "curl", packageVersion = "8.5.0-2ubuntu10.11", archiveSuite = "noble-updates/main"}, AcquisitionTool{package = "unzip", packageVersion = "6.0-28ubuntu4.1", archiveSuite = "noble-updates/main"}]

recipeRuntimeEnvironment :: [RuntimeEnvironment]
recipeRuntimeEnvironment = [RuntimeEnvironment{name = "JAVA_HOME", value = "/usr/lib/jvm/java-21-openjdk-${TARGETARCH}"}, RuntimeEnvironment{name = "PATH", value = "/usr/lib/jvm/java-21-openjdk-${TARGETARCH}/bin:/usr/lib/postgresql/16/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"}, RuntimeEnvironment{name = "PULSAR_LOG_DIR", value = "/tmp"}]

recipeForbiddenPayloads :: [Text]
recipeForbiddenPayloads = ["llama.cpp", "whisper.cpp", "onnxruntime", "audiveris", "infernix-adapter", "jitml-adapter"]
