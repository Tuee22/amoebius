{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE OverloadedRecordDot #-}

-- | Materialize observations of the shipped recipe API for the independent
-- oracle. This module supplies inputs and records results, never a verdict.
module SpineRecipeControls (recipeControls) where

import Amoebius.Image.Bake (bakeCatalog, imageRecipeArtifacts, renderLaneDockerfile)
import Amoebius.Image.Recipe (ImageRecipe, imageRecipe, recipeRefusalTag, recipeStages)
import Amoebius.Image.BakeInventory qualified as Inventory
import Amoebius.Image.BaseChannel qualified as Base
import Amoebius.Image.BuildArgv qualified as Argv
import Amoebius.Image.RenderDockerfile qualified as Docker
import Amoebius.Exec.Tool qualified as Tool
import Amoebius.Vocabulary
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (createDirectoryIfMissing)
import System.FilePath (takeDirectory, (</>))

recipeControls :: FilePath -> IO ()
recipeControls suite = do
  let directory = suite </> "substrates" </> "recipe-controls"
      detected = linuxCpuDetected Amd64
      baseline = imageRecipe "controls" KindEngine (detected :| [])
      one name lane = [name, either recipeRefusalTag (either recipeRefusalTag (const "rendered") . (`renderLaneDockerfile` lane)) baseline]
      owner = ["empty-owner", either recipeRefusalTag (const "accepted") (imageRecipe "" KindEngine (detected :| []))]
  createDirectoryIfMissing True directory
  TextIO.writeFile (directory </> "controls.tsv") (Text.unlines (map (Text.intercalate "\t")
    [one "required-cpu" (LinuxCpuAt Amd64), one "unrequired-cuda" (LinuxCudaAt Amd64), one "unrequired-arm64" (LinuxCpuAt Arm64), one "host-metal" AppleMetalOnHost, owner]))
  mapM_ (sample directory) [("cpu-amd64", LinuxCpu, Amd64), ("cpu-arm64", LinuxCpu, Arm64), ("cuda-amd64", LinuxCuda, Amd64), ("cuda-arm64", LinuxCuda, Arm64)]
  boundaryControls directory

boundaryControls :: FilePath -> IO ()
boundaryControls directory = do
  let digest character = "sha256:" <> Text.replicate 64 character
      channels =
        [("tagged", "ubuntu:24.04"), ("cuda", "nvidia/cuda:12.8.2-devel-ubuntu24.04")
        , ("registry-port", "localhost:5000/library/ubuntu:24.04"), ("empty", ""), ("untagged", "ubuntu")
        , ("port-only", "localhost:5000/ubuntu"), ("digest", "ubuntu@" <> digest "a")
        , ("digest-algorithm", digest "a"), ("space", "ubuntu:bad tag"), ("quote", "ubuntu:bad\"tag"), ("backslash", "ubuntu:bad\\tag")]
      badBase = "ubuntu@" <> digest "a"
  kind <- either (fail . show) pure (imageRecipe "controls" KindEngine (linuxCpuDetected Amd64 :| []))
  let badCatalog = (bakeCatalog kind) {Inventory.baseImage = badBase}
      catalogRefusal = case Docker.renderDockerfile badCatalog of
        Left (Inventory.CatalogBaseChannelInvalid value) -> ["catalog-digest", "CatalogBaseChannelInvalid", value]
        Left problem -> ["catalog-digest", Text.pack (show problem)]
        Right _ -> ["catalog-digest", "emitted"]
  table "channels.tsv" ([[name, either (Text.pack . show) Base.renderBaseChannel (Base.mkBaseChannel input)] | (name, input) <- channels] <> [catalogRefusal])
  engine <- either (fail . show) pure (Tool.mkToolPath (directory </> "engine"))
  let invocation flavor observed requested = do
        channel <- Base.mkBaseChannel (if flavor == Argv.Cpu then "ubuntu:24.04" else "nvidia/cuda:12.8.2-devel-ubuntu24.04")
        pure ([Text.pack (Argv.renderImageFlavor flavor), Text.pack (Argv.renderPlatform observed), Text.pack (Argv.renderPlatform requested)] <>
          case Argv.buildImageInvocation engine channel observed requested flavor "recipe.Dockerfile" "context" of
            Left (Argv.BuildArchitectureMismatch actualObserved actualRequested) -> ["refused", "BuildArchitectureMismatch", Text.pack (Argv.renderPlatform actualObserved), Text.pack (Argv.renderPlatform actualRequested)]
            Right arguments -> "emitted" : map Text.pack arguments)
  argv <- either (fail . show) pure (sequence [invocation flavor observed requested | flavor <- [Argv.Cpu, Argv.Cuda], observed <- [Inventory.Amd64, Inventory.Arm64], requested <- [Inventory.Amd64, Inventory.Arm64]])
  table "build-invocations.tsv" argv
  rke2 <- either (fail . show) pure (imageRecipe "controls" Rke2Engine (linuxCpuDetected Amd64 :| []))
  table "resources.tsv" (resourceRows "kind" kind <> resourceRows "rke2" rke2)
  channel <- either (fail . show) pure (Base.mkBaseChannel "ubuntu:24.04")
  positive <- mapM (resolution directory kind channel)
    [("a", digest "a", Base.CanonicalRegistry), ("b", digest "b", Base.MirrorAfterRateLimit)]
  let refused name value = [name, either (Text.pack . show) (const "accepted") (Base.mkBaseResolution channel value Base.CanonicalRegistry)]
  table "resolutions.tsv" (positive <> [refused "short" "sha256:a", refused "uppercase" (digest "A")])
 where
  table name rows = TextIO.writeFile (directory </> name) (Text.unlines (map (Text.intercalate "\t") rows))

resourceRows :: Text -> ImageRecipe -> [[Text]]
resourceRows scope recipe =
  [scope, "catalog", number catalog.architectureConcurrency, number catalog.stageConcurrency, number catalog.scratchCapacityBytes, number catalog.cacheCapacityBytes]
    : [[scope, "stage", stage.name, number stage.cpuReservationMillis, number stage.cpuCeilingMillis, number stage.memoryReservationBytes, number stage.memoryCeilingBytes, number stage.intermediateBytes, number stage.cacheWriteBytes] | stage <- recipeStages recipe]
 where
  catalog = bakeCatalog recipe
  number :: Show value => value -> Text
  number = Text.pack . show

resolution :: FilePath -> ImageRecipe -> Base.BaseChannel -> (Text, Text, Base.ResolutionSource) -> IO [Text]
resolution directory recipe channel (name, digest, source) = do
  resolved <- either (fail . show) pure (Base.mkBaseResolution channel digest source)
  let catalog = (bakeCatalog recipe) {Inventory.baseImage = Base.renderBaseChannel (Base.resolvedChannel resolved)}
  rendered <- either (fail . show) pure (Docker.renderDockerfile catalog)
  TextIO.writeFile (directory </> ("resolution-" <> Text.unpack name <> ".Dockerfile")) rendered.dockerfileText
  pure [name, Base.renderBaseChannel (Base.resolvedChannel resolved), Base.resolvedDigest resolved, Text.pack (show (Base.resolvedVia resolved))]

sample :: FilePath -> (Text, Substrate, Architecture) -> IO ()
sample directory (name, substrate, architecture) = case mkDetected substrate architecture of
  Left refusal -> TextIO.writeFile (directory </> "failed") (Text.pack (show refusal))
  Right detected -> case imageRecipe name KindEngine (detected :| []) >>= imageRecipeArtifacts of
    Left refusal -> TextIO.writeFile (directory </> "failed") (recipeRefusalTag refusal)
    Right files -> mapM_ (writeArtifact (directory </> Text.unpack name)) files

writeArtifact :: FilePath -> (FilePath, Text) -> IO ()
writeArtifact directory (path, contents) = do
  let target = directory </> path
  createDirectoryIfMissing True (takeDirectory target)
  TextIO.writeFile target contents
