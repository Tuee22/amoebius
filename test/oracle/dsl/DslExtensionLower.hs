{-# LANGUAGE OverloadedStrings #-}

-- No product imports. Literal application, need, lane and controller values
-- judge observations from the shipped lowerer and the product corpus.
module DslExtensionLower (extensionLowerRows, mixedRuntimeRows) where

import Data.Text qualified as Text
import Data.Aeson (Value (..), eitherDecodeStrict')
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Map.Strict qualified as Map
import Data.Maybe (mapMaybe)
import Data.Text.Encoding qualified as Encoding
import DslExtensionContract (loweringControls, extensionDependencyOrder, mixedInferenceNeeds, linkedIds)
import DslParse
import System.FilePath ((</>))

mixedRuntimeRows :: FilePath -> IO [Row]
mixedRuntimeRows directory = do
  manifest <- readBytes (directory </> "manifest.json")
  let objects = maybe [] (mapMaybe parseObject . splitPayloads) manifest
      identity object = do
        raw <- Map.lookup "amoebius.io/object-identity" (mAnnotations object)
        case eitherDecodeStrict' (Encoding.encodeUtf8 raw) of Right (String value) -> Just value; _ -> Nothing
      plans = [(need, identifier, object) | object <- objects, (need, _) <- mixedInferenceNeeds,
        identifier <- linkedIds, identity object == Just ("extension/" <> need <> "/" <> identifier <> "/plan")]
      engineObjects need = [object | object <- objects, maybe False (Text.isPrefixOf ("inferenceengine/" <> need <> "/")) (identity object)]
      label need = attestedScopeLabel "extension/infernix" "notes-0b5e17e11a0c0ffee0de1e9a7e5ba5ed" need
      scoped need object = Map.lookup "amoebius.io/scope" (mLabels object) == Just (label need)
        && Map.lookup "amoebius.io/scope-need" (mAnnotations object) == Just need
      configuration object = case mSpec object of
        Object spec | Just (String "ConfigurationSpec") <- KeyMap.lookup "tag" spec,
                      Just (Object fields) <- KeyMap.lookup "contents" spec -> Just fields
        _ -> Nothing
      field name object = case configuration object >>= KeyMap.lookup name of Just (String value) -> Just value; _ -> Nothing
      output need identifier = case [object | (owner, name, object) <- plans, owner == need, name == identifier] of
        [object] -> field "output" object
        _ -> Nothing
      consumed need = case ([object | (owner, name, object) <- plans, owner == need, name == "infernix"],
                            [object | (owner, name, object) <- plans, owner == need, name == "jitml"]) of
        ([inference], [training]) -> output need "jit-build" /= Nothing
          && field "jit-build" inference == output need "jit-build"
          && field "jit-build" training == output need "jit-build"
          && field "coordination" training == output need "coordination"
          && field "infernix" training == output need "infernix"
        _ -> False
      runtimeFields need kind = case [object | (owner, name, object) <- plans, owner == need, name == "infernix"] of
        [object] -> field "engine-runtime" object == Just (if kind == "Deployment" then "LinuxCpu" else "Cuda")
          && field "engine-family" object == Just "llama.cpp"
        _ -> False
      providerConsumes need = case [object | object <- engineObjects need, identity object == Just ("inferenceengine/" <> need <> "/config")] of
        [object] -> field "jit-build" object == output need "jit-build" && output need "jit-build" /= Nothing
          && field "infernix-output" object == output need "infernix"
        _ -> False
  pure ([check "extensions.mixed.complete-objects" (length objects == 33 && length plans == 8) "two scopes require eight distinct dependency plans",
         check "extensions.mixed.plan-metadata" (all (\(need, identifier, object) -> mKind object == "ConfigMap"
           && mNamespace object == Just "amoebius-inference"
           && mName object == identifier <> "-" <> Text.take 12 (Text.drop 2 (label need))
           && Map.lookup "app.kubernetes.io/managed-by" (mLabels object) == Just "amoebius"
           && Map.lookup "amoebius.io/epoch" (mLabels object) == Just "generation-1") plans) "plan metadata not bound to actual scope and epoch",
         check "extensions.mixed.cross-scope-outputs" (case map (\(need, _) -> output need "jit-build") mixedInferenceNeeds of
           [Just one, Just two] -> one /= two; _ -> False) "a producer reference crossed scopes"] <>
    concat [[check ("extensions.mixed." <> need <> ".runtime")
              (length (engineObjects need) == 3 && length [() | object <- engineObjects need, mKind object == kind] == 1) "per-need runtime lost",
             check ("extensions.mixed." <> need <> ".scope")
              (all (scoped need) (engineObjects need) && length [() | (owner, _, object) <- plans, owner == need, scoped need object] == 4) "scope omitted or reused",
             check ("extensions.mixed." <> need <> ".consumption") (consumed need) "dependency output not consumed within its own scope",
             check ("extensions.mixed." <> need <> ".runtime-fields") (runtimeFields need kind) "runtime/family missing from producer identity",
             check ("extensions.mixed." <> need <> ".provider-consumption") (providerConsumes need) "actual provider configuration discarded the build output"]
            | (need, kind) <- mixedInferenceNeeds])

extensionLowerRows :: FilePath -> IO [Row]
extensionLowerRows directory = do
  outcomes <- readText (directory </> "outcomes.tsv")
  rows <- concat <$> mapM accepted ["cpu-linked", "cuda-linked"]
  pure (expectEqual "extensions.lower.complete-controls"
    (map (\(name, result) -> name <> "\t" <> result) loweringControls)
    (Text.lines <$> outcomes) : rows)
 where
  accepted name = do
    let output = directory </> Text.unpack name
        nonce = "0b5e17e11a0c0ffee0de1e9a7e5ba5ed"
        app = "notes-" <> nonce
        engine = "engine-" <> nonce
        label field = "extensions.lower." <> name <> "." <> field
    proofs <- readText (output </> "proofs.tsv")
    extensions <- readText (output </> "extensions.tsv")
    lowered <- readText (output </> "lowered.dump")
    let expectedProofs =
          [Text.intercalate "\t" ["core/ObjectStore", app, "assets-" <> nonce],
           Text.intercalate "\t" ["extension/infernix", app, engine],
           Text.intercalate "\t" ["core/MessageBus", app, "events-" <> nonce],
           Text.intercalate "\t" ["core/Registry", app, "images-" <> nonce]]
        field key value = maybe False (elem (key <> "\t" <> value) . Text.lines) lowered
        controller = if name == "cuda-linked" then "DaemonSetBody [\"kind-host-1\"] DaemonSetOnDelete" else "DeploymentBody 1 RecreateRollout"
    pure
      [expectEqual (label "actual-need-proofs") expectedProofs (Text.lines <$> proofs),
       expectEqual (label "dependency-order") extensionDependencyOrder (Text.lines <$> extensions),
       check (label "inference-binding")
        (field ("bound.service." <> engine <> ".arm") "InferenceEngine"
         && field ("bound.service." <> engine <> ".product") "Infernix"
         && field ("bound.service." <> engine <> ".provider") "CanonicalProvider") "actual inference service is missing",
       check (label "runtime-controller")
        (maybe False (Text.isInfixOf ("inferenceengine/" <> engine <> "/member-0:" <> controller)) lowered)
        "runtime did not select its actual eligible controller"]
