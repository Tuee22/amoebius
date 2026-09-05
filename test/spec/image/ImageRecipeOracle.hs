{-# LANGUAGE OverloadedStrings #-}

{- | Independently authored Phase-35 semantic expectations.  These values state
required recipe meaning; they are not renderer output and are never generated
from the production catalog.
-}
module ImageRecipeOracle (
    argvRows,
    buildCaseRows,
    calculusProjection,
    mutantLoci,
    recipeRows,
    validationLoci,
) where

import Data.Text (Text)
import Data.Text qualified as Text

recipeRows :: [(Int, Text, Text)]
recipeRows =
    [ (1, "distribution", "AptPackage")
    , (2, "redis-server", "AptPackage")
    , (3, "redis-cli", "AptPackage")
    , (4, "postgres", "AptPackage")
    , (5, "patroni", "AptPackage")
    , (6, "temurin", "AptPackage")
    , (7, "g++", "AptPackage")
    , (8, "minio", "OfficialArtifact")
    , (9, "vault", "OfficialArtifact")
    , (10, "prometheus", "OfficialArtifact")
    , (11, "alertmanager", "OfficialArtifact")
    , (12, "thanos", "OfficialArtifact")
    , (13, "envoy", "OfficialArtifact")
    , (14, "grafana", "OfficialArtifact")
    , (15, "keycloak", "OfficialArtifact")
    , (16, "pulsar", "OfficialArtifact")
    , (17, "amoebius-jit-build-resolver", "BuildProduct")
    , (18, "envoy-gateway", "BuildProduct")
    , (19, "metallb-controller", "BuildProduct")
    , (20, "metallb-speaker", "BuildProduct")
    , (21, "percona-postgresql-operator", "BuildProduct")
    , (22, "pgadmin", "BuildProduct")
    ]

buildCaseRows :: [(Text, Text, Text, Text, String)]
buildCaseRows =
    [ ("cpu-amd64", "cpu", "amd64", "amd64", "amoebius-base-cpu-amd64")
    , ("cpu-arm64", "cpu", "arm64", "arm64", "amoebius-base-cpu-arm64")
    , ("cuda-amd64", "cuda", "amd64", "amd64", "amoebius-base-cuda-amd64")
    , ("cuda-arm64", "cuda", "arm64", "arm64", "amoebius-base-cuda-arm64")
    ]

argvRows :: [(Text, Int, String)]
argvRows = concatMap row buildCaseRows
  where
    row (name, _, _, architecture, tag) =
        zipWith
            (\position token -> (name, position, token))
            [1 ..]
            [ "/opt/amoebius/bin/docker"
            , "build"
            , "--file"
            , ".build/image-recipe/Dockerfile"
            , "--tag"
            , tag
            , "--build-arg"
            , "BASE_IMAGE=ubuntu:24.04"
            , "--build-arg"
            , "TARGETARCH=" <> Text.unpack architecture
            , ".build/image-recipe/context"
            ]

calculusProjection :: [(Text, Text)]
calculusProjection =
    [ ("calculus-kinds", "artifact,budget,lift,workflow,evidence")
    , ("component-names", "recipe-step-semantics,build-argv-tokens,renderer-laws,build-cases,mutant-evidence")
    , ("projection-counts", "22,44,4,4,3")
    , ("resource-vector", "5,77,0,0")
    ]

mutantLoci :: [(Text, Text)]
mutantLoci =
    [ ("recipe-buildx-subcommand", "plain-build")
    , ("recipe-second-platform", "single-architecture")
    , ("recipe-authored-base-digest", "digest-free-base")
    ]

validationLoci :: [(Text, Text)]
validationLoci =
    fmap (\(_, name, _) -> (name, "recipe-step-semantics")) recipeRows
        <> fmap (\(name, _, _, _, _) -> (name, "build-argv-oracle")) buildCaseRows
        <> mutantLoci
