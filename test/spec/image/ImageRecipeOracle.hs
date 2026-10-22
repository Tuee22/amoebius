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
    [ (1, "redis-server", "AptPackage")
    , (2, "redis-cli", "AptPackage")
    , (3, "postgres", "AptPackage")
    , (4, "patroni", "AptPackage")
    , (5, "temurin", "AptPackage")
    , (6, "g++", "AptPackage")
    , (7, "minio", "OfficialArtifact")
    , (8, "vault", "OfficialArtifact")
    , (9, "prometheus", "OfficialArtifact")
    , (10, "alertmanager", "OfficialArtifact")
    , (11, "thanos", "OfficialArtifact")
    , (12, "envoy", "OfficialArtifact")
    , (13, "grafana", "OfficialArtifact")
    , (14, "keycloak", "OfficialArtifact")
    , (15, "pulsar", "OfficialArtifact")
    , (16, "amoebius-jit-build-resolver", "BuildProduct")
    , (17, "envoy-gateway", "BuildProduct")
    , (18, "metallb-controller", "BuildProduct")
    , (19, "metallb-speaker", "BuildProduct")
    , (20, "percona-postgresql-operator", "BuildProduct")
    , (21, "pgadmin", "BuildProduct")
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
    , ("projection-counts", "21,44,4,4,3")
    , ("resource-vector", "5,76,0,0")
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
