{-# LANGUAGE OverloadedStrings #-}

-- | Independently authored requirements for the spec-derived image recipe.
-- These literals precede the recipe implementation. No product type,
-- constructor, encoder, version constant, or renderer is imported here.
module DslRecipe (recipeRows, recipeControlRows, expectedStepRows) where

import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text
import DslParse
import System.Directory (doesDirectoryExist, listDirectory, makeAbsolute)
import System.FilePath ((</>))

-- name, acquisition arm, installed path, version probe, argv, binary kind
baseSteps :: [[Text]]
baseSteps =
  [ ["redis-server", "AptPackage", "/usr/bin/redis-server", "7.0.15", "--version", "Elf"]
  , ["redis-cli", "AptPackage", "/usr/bin/redis-cli", "7.0.15", "--version", "Elf"]
  , ["postgres", "AptPackage", "/usr/lib/postgresql/16/bin/postgres", "16.14", "--version", "Elf"]
  , ["patroni", "AptPackage", "/usr/bin/patroni", "3.2.2", "--version", "Launcher"]
  , ["temurin", "AptPackage", "/usr/bin/java", "21.0.11", "--version", "Elf"]
  , ["g++", "AptPackage", "/usr/bin/g++", "13.3.0", "--version", "Elf"]
  , ["minio", "OfficialArtifact", "/usr/bin/minio", "RELEASE.2025-07-23T15-54-02Z", "--version", "Elf"]
  , ["vault", "OfficialArtifact", "/usr/bin/vault", "1.20.2", "--version", "Elf"]
  , ["prometheus", "OfficialArtifact", "/usr/bin/prometheus", "3.5.0", "--version", "Elf"]
  , ["alertmanager", "OfficialArtifact", "/usr/bin/alertmanager", "0.28.1", "--version", "Elf"]
  , ["thanos", "OfficialArtifact", "/usr/bin/thanos", "0.39.2", "--version", "Elf"]
  , ["envoy", "OfficialArtifact", "/usr/bin/envoy", "1.35.1", "--version", "Elf"]
  , ["grafana", "OfficialArtifact", "/usr/share/grafana", "12.1.1", "--version", "Elf"]
  , ["keycloak", "OfficialArtifact", "/opt/keycloak", "26.3.2", "--version", "Launcher"]
  , ["pulsar", "OfficialArtifact", "/pulsar", "4.0.6", "version", "Launcher"]
  , ["amoebius-jit-build-resolver", "BuildProduct", "/usr/bin/amoebius", "0.1.0.0", "jit-build-resolver --version", "Elf"]
  , ["envoy-gateway", "BuildProduct", "/usr/bin/envoy-gateway", "1.4.2", "version", "Elf"]
  , ["metallb-controller", "BuildProduct", "/usr/bin/metallb-controller", "0.15.2", "-h", "Elf"]
  , ["metallb-speaker", "BuildProduct", "/usr/bin/metallb-speaker", "0.15.2", "-h", "Elf"]
  , ["percona-postgresql-operator", "BuildProduct", "/usr/bin/percona-postgresql-operator", "2.6.0", "--version", "Elf"]
  , ["pgadmin", "BuildProduct", "/pgadmin4", "9.6", "-c import sys; sys.path.insert(0, '/pgadmin4'); import config; print(config.APP_VERSION)", "Launcher"]
  ]

recipeControlRows :: FilePath -> IO [Row]
recipeControlRows suite = do
  let directory = suite </> "substrates" </> "recipe-controls"
  controls <- readTable (directory </> "controls.tsv")
  let wanted = [["required-cpu", "rendered"], ["unrequired-cuda", "UnrequiredLaneStep"], ["unrequired-arm64", "UnrequiredLaneStep"], ["host-metal", "UnrequiredLaneStep"], ["empty-owner", "InvalidRecipeOwner"]]
      cpu architecture = ("linux-cpu/" <> architecture, "amoebius-base-cpu-" <> architecture, "ubuntu:24.04")
      cuda architecture = ("linux-cuda/" <> architecture, "amoebius-base-cuda-" <> architecture, "nvidia/cuda:12.8.2-devel-ubuntu24.04")
      samples = [("cpu-amd64", [cpu "amd64"]), ("cpu-arm64", [cpu "arm64"]), ("cuda-amd64", [cpu "amd64", cuda "amd64"]), ("cuda-arm64", [cpu "arm64", cuda "arm64"])]
  projections <- concat <$> mapM (\(sample, lanes) -> recipeRows (directory </> Text.unpack sample) ("controls." <> sample) sample False lanes) samples
  boundaries <- recipeBoundaryRows directory
  pure (expectEqual "recipe.controls.refusals" wanted controls : projections <> boundaries)

-- Literal requirements for public APIs, including fields omitted by the
-- human-readable step projection. No product declarations enter this oracle.
recipeBoundaryRows :: FilePath -> IO [Row]
recipeBoundaryRows directory = do
  channels <- readTable (directory </> "channels.tsv")
  invocations <- readTable (directory </> "build-invocations.tsv")
  budgets <- readTable (directory </> "resources.tsv")
  resolutions <- readTable (directory </> "resolutions.tsv")
  first <- readText (directory </> "resolution-a.Dockerfile")
  second <- readText (directory </> "resolution-b.Dockerfile")
  engine <- makeAbsolute (directory </> "engine")
  let channelCases =
        [ ["tagged", "ubuntu:24.04"]
        , ["cuda", "nvidia/cuda:12.8.2-devel-ubuntu24.04"]
        , ["registry-port", "localhost:5000/library/ubuntu:24.04"]
        , ["empty", "BaseChannelEmpty"], ["untagged", "BaseChannelMissingTag"]
        , ["port-only", "BaseChannelMissingTag"]
        , ["digest", "BaseChannelContainsDigest"], ["digest-algorithm", "BaseChannelContainsDigest"]
        , ["space", "BaseChannelInvalidCharacter"], ["quote", "BaseChannelInvalidCharacter"]
        , ["backslash", "BaseChannelInvalidCharacter"]
        , ["catalog-digest", "CatalogBaseChannelInvalid", "ubuntu@sha256:" <> Text.replicate 64 "a"]
        ]
      parent "cpu" = "ubuntu:24.04"
      parent _ = "nvidia/cuda:12.8.2-devel-ubuntu24.04"
      invocation flavor observed requested = [flavor, observed, requested] <>
        if observed /= requested then ["refused", "BuildArchitectureMismatch", observed, requested]
        else ["emitted", Text.pack engine, "build", "--file", "recipe.Dockerfile", "--tag", "amoebius-base-" <> flavor <> "-" <> requested, "--build-arg", "BASE_IMAGE=" <> parent flavor, "--build-arg", "TARGETARCH=" <> requested, "context"]
      argv = [invocation flavor observed requested | flavor <- ["cpu", "cuda"], observed <- ["amd64", "arm64"], requested <- ["amd64", "arm64"]]
      baseBudgets =
        [ ["stage", "platform-services", "750", "1500", "805306368", "1610612736", "2147483648", "1073741824"]
        , ["stage", "service-bundles", "1000", "2000", "1073741824", "2147483648", "4294967296", "1073741824"]
        , ["stage", "amoebius-runtime", "750", "1500", "1073741824", "1610612736", "4294967296", "2147483648"]
        ]
      resourceRows scope = map (scope :)
        ([ ["catalog", "1", "1", "34359738368", "21474836480"] ] <> baseBudgets <>
          [["stage", "rke2-node", "250", "500", "268435456", "536870912", "536870912", "134217728"] | scope == "rke2"])
      digest character = "sha256:" <> Text.replicate 64 character
      resolutionRows =
        [ ["a", "ubuntu:24.04", digest "a", "CanonicalRegistry"]
        , ["b", "ubuntu:24.04", digest "b", "MirrorAfterRateLimit"]
        , ["short", "BaseResolutionDigestInvalid \"sha256:a\""]
        , ["uppercase", "BaseResolutionDigestInvalid \"" <> digest "A" <> "\""]
        ]
      exact line = maybe False ((== 1) . length . filter (== line) . Text.lines) first
  pure
    [ expectEqual "recipe.base-channels" channelCases channels
    , expectEqual "recipe.build-invocations" argv invocations
    , expectEqual "recipe.resource-bytes" (resourceRows "kind" <> resourceRows "rke2") budgets
    , expectEqual "recipe.base-resolutions" resolutionRows resolutions
    , check "recipe.resolution-independent-bytes" (first /= Nothing && first == second && exact "ARG BASE_IMAGE" && exact "FROM ${BASE_IMAGE} AS amoebius-base") "resolutions changed recipe bytes or the base argument is not singular"
    ]

expectedStepRows :: Bool -> [[Text]]
expectedStepRows rke2 = zipWith (\index fields -> ["step", Text.pack (show index)] <> fields) [1 :: Int ..] steps
 where
  steps = baseSteps <> [["rke2", "OfficialArtifact", "/usr/local/bin/rke2", "v1.34.1+rke2r1", "--version", "Elf"] | rke2]

-- | Judge actual step data, the independently projected bake catalog, and
-- the generated Dockerfiles for the exact required lane set.
recipeRows :: FilePath -> Text -> Text -> Bool -> [(Text, Text, Text)] -> IO [Row]
recipeRows directory label owner rke2 lanes = do
  recipe <- readTable (directory </> "image-recipe.tsv")
  catalog <- readTable (directory </> "bake-catalog.tsv")
  arguments <- readTable (directory </> "image-build-arguments.tsv")
  let engine = if rke2 then "Rke2Engine" else "KindEngine"
      laneRows = [["lane", lane, tag, parent] | (lane, tag, parent) <- lanes]
      wantedRecipe = [["recipe", owner, engine]] <> laneRows <> expectedStepRows rke2
      wantedCatalog = [["catalog", owner], ["concurrency", "1", "1"]] <> laneRows <> expectedStepRows rke2
      wantedArguments =
        [ [owner, lane, "build", "--file", "images/" <> Text.replace "linux-" "" (Text.replace "/" "-" lane) <> ".Dockerfile", "--tag", tag, "--build-arg", "BASE_IMAGE=" <> parent, "--build-arg", "TARGETARCH=" <> architecture, "."]
        | (lane, tag, parent) <- lanes, let architecture = if "/arm64" `Text.isSuffixOf` lane then "arm64" else "amd64"]
  docker <- concat <$> mapM (dockerRows directory label rke2) lanes
  present <- doesDirectoryExist (directory </> "images")
  actualFiles <- if present then map Text.pack <$> listDirectory (directory </> "images") else pure []
  let files = [Text.replace "linux-" "" (Text.replace "/" "-" lane) <> ".Dockerfile" | (lane, _, _) <- lanes]
  pure ([expectEqual ("recipe." <> label <> ".steps") wantedRecipe recipe, expectEqual ("bake." <> label <> ".catalog") wantedCatalog catalog, expectEqual ("build-argv." <> label <> ".arguments") wantedArguments arguments, check ("bake." <> label <> ".files") (sort actualFiles == sort files) "missing, duplicate, or unrequired lane recipe"] <> docker)

dockerRows :: FilePath -> Text -> Bool -> (Text, Text, Text) -> IO [Row]
dockerRows directory label rke2 (lane, tag, parent) = do
  let file = Text.replace "linux-" "" (Text.replace "/" "-" lane) <> ".Dockerfile"
      architecture = if "/arm64" `Text.isSuffixOf` lane then "arm64" else "amd64"
      named = "bake." <> label <> "." <> Text.replace "/" "-" lane
  bytes <- readText (directory </> "images" </> Text.unpack file)
  let linesOfFile = maybe [] Text.lines bytes
      exact line = length (filter (== line) linesOfFile) == 1
      text = maybe "" id bytes
      built = [("amoebius-jit-build-resolver", "/usr/bin/amoebius"), ("envoy-gateway", "/usr/bin/envoy-gateway"), ("metallb-controller", "/usr/bin/metallb-controller"), ("metallb-speaker", "/usr/bin/metallb-speaker"), ("percona-postgresql-operator", "/usr/bin/percona-postgresql-operator"), ("pgadmin", "/pgadmin4")]
      rke2Url = "https://github.com/rancher/rke2/releases/download/v1.34.1%2Brke2r1/"
  pure
    [ check (named <> ".target") (exact ("# target: " <> tag) && exact ("ARG BASE_IMAGE=" <> parent) && exact ("ARG TARGETARCH=" <> architecture) && exact "FROM ${BASE_IMAGE} AS amoebius-base") "tag, base, or architecture differs"
    , check (named <> ".built") (all (\(name, target) -> exact ("COPY --link out/${TARGETARCH}/" <> name <> " " <> target)) built) "a source-built binary is missing or duplicated"
    , check (named <> ".rke2") (if rke2 then all (`Text.isInfixOf` text) [rke2Url <> "rke2.linux-amd64.tar.gz", rke2Url <> "rke2.linux-arm64.tar.gz", rke2Url <> "sha256sum-amd64.txt", rke2Url <> "sha256sum-arm64.txt", "\"*/rke2\" > /usr/local/bin/rke2"] else not (rke2Url `Text.isInfixOf` text)) "rke2 step differs from the engine requirement"
    , check (named <> ".registry-excluded") (not (any (`Text.isInfixOf` text) ["docker-registry=", "/usr/bin/docker-registry"])) "the Registry provider was baked into the base"
    , check (named <> ".host-payload-excluded") (not (any (`Text.isInfixOf` text) ["nvcc", "Metal.framework", "libamoebius-metal", "llama.cpp"])) "host-only or resolve-on-miss payload was baked"
    ]
