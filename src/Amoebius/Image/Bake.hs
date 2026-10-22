{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Project the closed recipe into the actual catalog and Dockerfiles. This
-- module renders bytes only; it never discovers a host or runs an image.
module Amoebius.Image.Bake
  ( bakeCatalog, bakeCatalogForLane, renderBakeCatalog
  , renderLaneDockerfile, renderBakeFiles, imageRecipeArtifacts
  ) where

import Amoebius.Image.BakeInventory
import Amoebius.Image.Recipe
import Amoebius.Image.RenderDockerfile (Dockerfile (..), renderDockerfile)
import Amoebius.Image.BaseChannel (mkBaseChannel)
import Amoebius.Image.BuildArgv qualified as Argv
import Amoebius.Topology.Lanes (laneLabel)
import Amoebius.Vocabulary qualified as V
import Data.Bifunctor (first)
import Data.Text (Text)
import Data.Text qualified as Text

bakeCatalog :: ImageRecipe -> BakeCatalog
bakeCatalog recipe = BakeCatalog
  { architectureConcurrency = 1, stageConcurrency = 1
  , scratchBacking = "base-image-registry-build-scratch", scratchCapacityBytes = 34359738368
  , cacheBacking = "base-image-registry-build-cache", cacheCapacityBytes = 21474836480
  , baseImage = "ubuntu:24.04", acquisitionTools = recipeAcquisitionTools
  , runtimeEnvironment = recipeRuntimeEnvironment, stages = recipeStages recipe
  , forbiddenPayloads = recipeForbiddenPayloads
  }

bakeCatalogForLane :: ImageRecipe -> V.Lane -> Either RecipeRefusal BakeCatalog
bakeCatalogForLane recipe lane = do
  requireLane recipe lane
  let catalog = (bakeCatalog recipe) {baseImage = laneParent lane}
  first RecipeCatalogRefused (validateBakeCatalog catalog)
  pure catalog

renderBakeCatalog :: ImageRecipe -> Text
renderBakeCatalog recipe = Text.unlines (map (Text.intercalate "\t")
  ([["catalog", recipeOwner recipe], ["concurrency", Text.pack (show catalog.architectureConcurrency), Text.pack (show catalog.stageConcurrency)]]
    <> renderLaneRows recipe <> renderStepRows (catalogSteps catalog)))
 where
  catalog = bakeCatalog recipe

renderLaneDockerfile :: ImageRecipe -> V.Lane -> Either RecipeRefusal Text
renderLaneDockerfile recipe lane = do
  catalog <- bakeCatalogForLane recipe lane
  rendered <- first RecipeCatalogRefused (renderDockerfile catalog)
  case Text.lines rendered.dockerfileText of
    [] -> Left RecipeRenderEmpty
    syntax : rest -> pure (Text.unlines (syntax : ["# specification: " <> recipeOwner recipe, "# target: " <> laneTag lane] <> map defaults rest))
 where
  architecture = case lane of
    V.LinuxCpuAt value -> value
    V.LinuxCudaAt value -> value
    V.AppleMetalOnHost -> V.Arm64
  defaults line
    | line == "ARG BASE_IMAGE" = "ARG BASE_IMAGE=" <> laneParent lane
    | line == "ARG TARGETARCH" = "ARG TARGETARCH=" <> Text.pack (V.architectureName architecture)
    | otherwise = line

renderBakeFiles :: ImageRecipe -> Either RecipeRefusal [(FilePath, Text)]
renderBakeFiles recipe = traverse one (recipeLanes recipe)
 where
  one lane = (,) ("images/" <> Text.unpack (Text.drop (Text.length "amoebius-base-") (laneTag lane)) <> ".Dockerfile") <$> renderLaneDockerfile recipe lane

imageRecipeArtifacts :: ImageRecipe -> Either RecipeRefusal [(FilePath, Text)]
imageRecipeArtifacts recipe = do
  files <- renderBakeFiles recipe
  arguments <- traverse plan (recipeLanes recipe)
  pure ([("image-recipe.tsv", renderRecipe recipe), ("bake-catalog.tsv", renderBakeCatalog recipe), ("image-build-arguments.tsv", Text.unlines (map (Text.intercalate "\t") arguments))] <> files)
 where
  plan lane = do
    requireLane recipe lane
    channel <- either (const (Left (RecipeCatalogRefused (CatalogBaseChannelInvalid (laneParent lane))))) Right (mkBaseChannel (laneParent lane))
    let (flavor, architecture) = case lane of
          V.LinuxCpuAt value -> (Argv.Cpu, platform value)
          V.LinuxCudaAt value -> (Argv.Cuda, platform value)
          V.AppleMetalOnHost -> (Argv.Cpu, Arm64)
        dockerfile = "images/" <> Text.unpack (Text.drop (Text.length "amoebius-base-") (laneTag lane)) <> ".Dockerfile"
    arguments <- either (const (Left (UnrequiredLaneStep lane))) Right (Argv.buildImageArguments channel architecture architecture flavor dockerfile ".")
    pure (recipeOwner recipe : laneLabel lane : map Text.pack arguments)
  platform architecture = case architecture of V.Amd64 -> Amd64; V.Arm64 -> Arm64
