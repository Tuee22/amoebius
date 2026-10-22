{-# LANGUAGE OverloadedStrings #-}

-- Codec inputs only. The independent oracle states the fields and refusals;
-- these values carry no verdict or validator policy.
module Amoebius.Dsl.Examples.Extensions.CodecInputs (codecInputs) where

import Amoebius.Capability.Types (CapabilityProvider (CanonicalProvider), ServiceShape (SingleNode))
import Amoebius.Dsl.Encode (rawOf)
import Amoebius.Dsl.Examples.Spine (baselineRoot)
import Amoebius.Dsl.Raw qualified as Raw
import Amoebius.Dsl.Spec
import Amoebius.Extension.Config qualified as Config
import Amoebius.Vocabulary
  ( CapabilityArm (InferenceEngine), EngineRuntime (..), InferenceFamily (..), mkExtensionId )
import Data.Bifunctor (first)
import Data.List.NonEmpty qualified as NonEmpty
import Data.Text (Text)
import Data.Text qualified as Text

codecInputs :: Either Text [(Text, Raw.RawRoot)]
codecInputs = do
  base <- checked baselineRoot
  requests <- sequence
    [ request "jit-build" (Config.cacheParameters 4096 1024 3)
    , request "coordination" (Config.coordinationParameters "events")
    , request "infernix" (Config.inferenceParameters 8192)
    , request "jitml" (Config.trainingParameters "training-data") ]
  configured <- checked
    (mkRootWithExtensions (NonEmpty.toList (rootClusters base)) (rootApps base) (rootDeployments base) requests)
  engines <- traverse (engineInput base)
    [(family, runtime) | family <- [minBound .. maxBound], runtime <- [minBound .. maxBound]]
  let raw = rawOf configured
      replaceFirst parameters = raw {Raw.rootExtensions = Raw.RawExtensionRequest "jit-build" parameters : drop 1 (Raw.rootExtensions raw)}
  pure (("all-configurations", raw) : engines <>
    [("zero-cache-budget", replaceFirst (cache 0 1 1)),
     ("zero-first-miss-concurrency", replaceFirst (cache 4096 1024 0)),
     ("temporary-above-budget", replaceFirst (cache 4096 4097 1)),
     ("cache-bounds-overflow", replaceFirst (cache (2 ^ (64 :: Int)) 1 1)),
     ("reference-url", raw {Raw.rootExtensions = [Raw.RawExtensionRequest "coordination" (Raw.CoordinationParameters "https://invalid.example")]}),
     ("duplicate-request", raw {Raw.rootExtensions = Raw.rootExtensions raw <> take 1 (Raw.rootExtensions raw)})])
 where
  cache budget temporary concurrency = Raw.BuildCacheParameters (Raw.RawCacheParameters budget temporary concurrency)
  request name parameters = do
    identifier <- maybe (Left "invalid codec input identity") Right (mkExtensionId name)
    values <- first (Text.pack . show) parameters
    pure (Config.extensionRequest identifier values)

engineInput :: RootInForceSpec -> (InferenceFamily, EngineRuntime) -> Either Text (Text, Raw.RawRoot)
engineInput base (family, runtime) = do
  (app, deployment) <- case (rootApps base, rootDeployments base) of
    ([one], [two]) -> Right (one, two)
    _ -> Left "codec base requires one application and deployment"
  name <- checked (mkNeedName "engine")
  need <- checked (mkNeedSpec InferenceEngine name)
  configuredApp <- checked (mkAppSpec (appName app) [need] (appWorkload app))
  configuredDeployment <- checked (mkDeploymentRules (appName app)
    [mkInferenceBindingSpec name CanonicalProvider SingleNode runtime family] (deploymentDistribution deployment))
  root <- checked (mkRootInForceSpec (NonEmpty.toList (rootClusters base)) [configuredApp] [configuredDeployment])
  Right (Text.pack (show family) <> "-" <> runtimeName runtime, rawOf root)
 where runtimeName value = case value of AppleMetal -> "AppleMetal"; Cuda -> "Cuda"; CpuRuntime -> "LinuxCpu"

checked :: Either SpecError value -> Either Text value
checked = first (Text.pack . show)
