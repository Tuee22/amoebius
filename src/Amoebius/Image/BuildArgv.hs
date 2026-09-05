{-# LANGUAGE CPP #-}

module Amoebius.Image.BuildArgv (
    ImageFlavor (..),
    BuildArgvError (..),
    buildImageInvocation,
    renderImageFlavor,
    renderPlatform,
    renderPublishedTag,
) where

import Amoebius.Exec.Tool (ToolPath, toolPath)
import Amoebius.Image.BakeInventory (Platform (..))
import Amoebius.Image.BaseChannel (BaseChannel, renderBaseChannel)
import Data.Text qualified as Text

data ImageFlavor = Cpu | Cuda
    deriving stock (Bounded, Enum, Eq, Ord, Show)

data BuildArgvError = BuildArchitectureMismatch
    { observedArchitecture :: Platform
    , requestedArchitecture :: Platform
    }
    deriving stock (Eq, Show)

buildImageInvocation ::
    ToolPath ->
    BaseChannel ->
    Platform ->
    Platform ->
    ImageFlavor ->
    FilePath ->
    FilePath ->
    Either BuildArgvError [String]
buildImageInvocation engine channel observed requested flavor dockerfile context
    | observed /= requested = Left (BuildArchitectureMismatch observed requested)
    | otherwise =
        Right $
            [ toolPath engine
            , buildSubcommand
            , "--file"
            , dockerfile
            , "--tag"
            , renderPublishedTag flavor requested
            , "--build-arg"
            , "BASE_IMAGE=" <> Text.unpack (renderBaseChannel channel)
            , "--build-arg"
            , "TARGETARCH=" <> renderPlatform requested
            ]
                <> platformOverride requested
                <> [context]

buildSubcommand :: String
#ifdef IMAGE_RECIPE_BUILDX_SUBCOMMAND_MUTANT
buildSubcommand = "buildx"
#else
buildSubcommand = "build"
#endif

platformOverride :: Platform -> [String]
#ifdef IMAGE_RECIPE_SECOND_PLATFORM_MUTANT
platformOverride platform = ["--platform", "linux/" <> renderPlatform platform]
#else
platformOverride _ = []
#endif

renderImageFlavor :: ImageFlavor -> String
renderImageFlavor flavor = case flavor of
    Cpu -> "cpu"
    Cuda -> "cuda"

renderPlatform :: Platform -> String
renderPlatform platform = case platform of
    Amd64 -> "amd64"
    Arm64 -> "arm64"

renderPublishedTag :: ImageFlavor -> Platform -> String
renderPublishedTag flavor platform =
    "amoebius-base-" <> renderImageFlavor flavor <> "-" <> renderPlatform platform
