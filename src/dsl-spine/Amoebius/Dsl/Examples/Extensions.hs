{-# LANGUAGE OverloadedStrings #-}

-- | Cumulative operator inputs. Expected bindings, scopes, refusals and
-- resources belong to the independent oracle, never to this corpus.
module Amoebius.Dsl.Examples.Extensions
  ( Example (..), corpus, exampleNamed, renderExampleFiles
  , extensionRoot, extensionMixedRoot, loweringInputs
  ) where

import Amoebius.Capability.Types (CapabilityProvider (CanonicalProvider), ServiceShape (SingleNode))
import Amoebius.Dsl.Decode (rootSchema)
import Amoebius.Dsl.Encode (encodeRaw, encodeRoot, rawOf)
import Amoebius.Dsl.Examples.Extensions.CodecInputs (codecInputs)
import Amoebius.Dsl.Examples.Extensions.SourceInputs (extensionInputs, conformanceRoleInputs, closedApiInputs, sourceTreeInputs, mergeInputs)
import Amoebius.Dsl.Examples.Spine (Example (..), baselineRoot, helperFiles, sentinel)
import Amoebius.Dsl.Examples.Substrates qualified as Substrates
import Amoebius.Dsl.Raw qualified as Raw
import Amoebius.Dsl.Spec
import Amoebius.Extension.Config qualified as Config
import Amoebius.Substrate.Classify (Reads (..), classify)
import Amoebius.Vocabulary
import Data.Bifunctor (first)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import Data.Text qualified as Text

checked :: Show problem => Either problem value -> Either Text value
checked = first (Text.pack . show)

extensionRoot :: EngineRuntime -> Architecture -> Gpu -> Either Text RootInForceSpec
extensionRoot runtime architecture gpu = do
  base <- checked baselineRoot
  (app, deployment, cluster) <- case (rootApps base, rootDeployments base, rootClusters base) of
    ([one], [two], three :| []) -> Right (one, two, three)
    _ -> Left "extension input requires one application, deployment and cluster"
  detected <- checked (classify (Reads (OsName "linux") (RawArch (if architecture == Amd64 then "x86_64" else "aarch64")) gpu))
  host <- case clusterHosts cluster of
    one :| [] -> Right one {hostDetected = detected, hostResources = HostResources 64 256 2000 110}
    _ -> Left "extension input requires one host"
  replicas <- checked (mkKindReplicas 1)
  configuredCluster <- checked (mkClusterSpec (clusterName cluster) (hostNameText (hostName host)) replicas (host :| []))
  engineName <- checked (mkNeedName ("engine-" <> sentinel))
  registryName <- checked (mkNeedName ("images-" <> sentinel))
  eventsName <- checked (mkNeedName ("events-" <> sentinel))
  extraNeeds <- traverse (\(arm, name) -> checked (mkNeedSpec arm name))
    [(Registry, registryName), (MessageBus, eventsName), (InferenceEngine, engineName)]
  configuredApp <- checked (mkAppSpec (appName app) (toList (appNeeds app) <> extraNeeds) (appWorkload app))
  configuredDeployment <- checked (mkDeploymentRules (appName app)
    (toList (deploymentBindings deployment) <>
      [BindingSpec registryName CanonicalProvider SingleNode,
       BindingSpec eventsName CanonicalProvider SingleNode,
       mkInferenceBindingSpec engineName CanonicalProvider SingleNode runtime LlamaCpp])
    (deploymentDistribution deployment))
  store <- case toList (appNeeds app) of
    need : _ -> Right (needNameText (needName need))
    [] -> Left "extension input requires object-store need"
  requests <- sequence
    [request "jit-build" (Config.cacheParameters 4096 1024 3),
     request "coordination" (Config.coordinationParameters (needNameText eventsName)),
     request "infernix" (Config.inferenceParameters 8192),
     request "jitml" (Config.trainingParameters store)]
  checked (mkRootWithExtensions [configuredCluster] [configuredApp] [configuredDeployment] requests)
 where
  toList (one :| rest) = one : rest
  request name parameters = do
    identifier <- maybe (Left "invalid extension input identity") Right (mkExtensionId name)
    values <- checked parameters
    Right (Config.extensionRequest identifier values)

loweringInputs :: Either Text [(Text, Raw.RawRoot)]
loweringInputs = do
  cpu <- rawOf <$> extensionRoot CpuRuntime Amd64 GpuAbsent
  cuda <- rawOf <$> extensionRoot Cuda Amd64 GpuPresent
  cudaOnCpu <- rawOf <$> extensionRoot Cuda Amd64 GpuAbsent
  let changeBinding change root = root {Raw.rootDeployments =
        [deployment {Raw.bindings = map (\binding -> if Raw.bindingInference binding == Nothing then binding else change binding)
           (Raw.bindings deployment)} | deployment <- Raw.rootDeployments root]}
      requestChange name change root = root {Raw.rootExtensions =
        [if Raw.extensionId request == name then change request else request | request <- Raw.rootExtensions root]}
  Right
    [("cpu-linked", cpu), ("cuda-linked", cuda), ("cuda-on-cpu", cudaOnCpu),
     ("missing-explicit-inference-binding", changeBinding (\binding -> binding {Raw.bindingInference = Nothing}) cpu),
     ("vllm-on-cpu", changeBinding (\binding -> binding {Raw.bindingInference = Just (Raw.RawInferenceBinding Raw.LinuxCpu Raw.Vllm)}) cpu),
     ("missing-peer-configuration", cpu {Raw.rootExtensions = filter ((/= "jit-build") . Raw.extensionId) (Raw.rootExtensions cpu)}),
     ("wrong-peer-schema", requestChange "jit-build" (\request -> request {Raw.extensionParameters = Raw.InferenceParameters 4096}) cpu),
     ("unknown-extension-request", cpu {Raw.rootExtensions = Raw.rootExtensions cpu <> [Raw.RawExtensionRequest "unknown" (Raw.InferenceParameters 4096)]}),
     ("coordination-reference-unbound", requestChange "coordination" (\request -> request {Raw.extensionParameters = Raw.CoordinationParameters "absent"}) cpu),
     ("training-reference-unbound", requestChange "jitml" (\request -> request {Raw.extensionParameters = Raw.TrainingParameters "absent"}) cpu)]

extensionMixedRoot :: Either Text RootInForceSpec
extensionMixedRoot = do
  root <- extensionRoot CpuRuntime Amd64 GpuPresent
  (app, deployment) <- case (rootApps root, rootDeployments root) of
    ([one], [two]) -> Right (one, two)
    _ -> Left "mixed extension input requires one application and deployment"
  name <- checked (mkNeedName ("engine-cuda-" <> sentinel))
  need <- checked (mkNeedSpec InferenceEngine name)
  configuredApp <- checked (mkAppSpec (appName app) (list (appNeeds app) <> [need]) (appWorkload app))
  configuredDeployment <- checked (mkDeploymentRules (appName app)
    (list (deploymentBindings deployment) <> [mkInferenceBindingSpec name CanonicalProvider SingleNode Cuda LlamaCpp])
    (deploymentDistribution deployment))
  checked (mkRootWithExtensions (list (rootClusters root)) [configuredApp] [configuredDeployment] (rootExtensions root))
 where list (one :| rest) = one : rest

rendered :: Either Text RootInForceSpec -> Text
rendered = either (\problem -> "{ invalidExample = " <> Text.pack (show problem) <> " }") encodeRoot

corpus :: [Example]
corpus = Substrates.corpus <>
  [Example "infernix-linked" (rendered (extensionRoot CpuRuntime Amd64 GpuAbsent)),
   Example "attested-scope" (rendered (extensionRoot CpuRuntime Arm64 GpuAbsent)),
   Example "cuda-on-cuda-sibling" (rendered (extensionRoot Cuda Amd64 GpuPresent)),
   Example "cuda-arm64-linked" (rendered (extensionRoot Cuda Arm64 GpuPresent)),
   Example "mixed-inference-runtimes" (rendered extensionMixedRoot),
   Example "cuda-on-cpu" (rendered (extensionRoot Cuda Amd64 GpuAbsent))]

exampleNamed :: Text -> Maybe Example
exampleNamed name = case [example | example <- corpus, exampleName example == name] of
  one : _ -> Just one
  [] -> Nothing

renderExampleFiles :: [(FilePath, Text)]
renderExampleFiles =
  [("examples/" <> Text.unpack (exampleName example) <> ".dhall", exampleText example <> "\n") | example <- corpus]
  <> [("examples/" <> path, contents) | (path, contents) <- helperFiles]
  <> [("schema.dhall", rootSchema <> "\n")]
  <> [("extension-inputs/boundary-inputs.tsv", Text.unlines
      ([name | (name, _, _) <- sourceTreeInputs []] <> [name | (name, _) <- mergeInputs]))]
  <> [("extension-inputs/ast/" <> Text.unpack name <> ".hs", source) | (name, source) <- extensionInputs]
  <> [("extension-inputs/types/" <> Text.unpack name <> suffix <> ".hs", source)
      | (name, legal, illegal) <- conformanceRoleInputs,
        (suffix, source) <- [("-same-index", legal), ("-retag", illegal)]]
  <> [("extension-inputs/closed-api/" <> Text.unpack name <> suffix <> ".hs", source)
      | (name, legal, illegal) <- closedApiInputs,
        (suffix, source) <- [("-legal", legal), ("-illegal", illegal)]]
  <> either (const []) (map (\(name, input) -> ("extension-inputs/codec/" <> Text.unpack name <> ".dhall", encodeRaw input))) codecInputs
