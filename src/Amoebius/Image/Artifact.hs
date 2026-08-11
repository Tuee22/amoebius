{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Image.Artifact
  ( ImagePlatform (..)
  , ImageLayer (..)
  , ImagePlatformArtifact (..)
  , ImageArtifact (..)
  , ArtifactBounds (..)
  , RegistryObjectKind (..)
  , RegistryStoredArtifact (..)
  , ArtifactError (..)
  , validateImageArtifact
  , registryStoredArtifacts
  , renderArtifactError
  ) where

import Control.DeepSeq (NFData)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data ImagePlatform = LinuxAmd64 | LinuxArm64
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ImageLayer = ImageLayer
  { layerDigest :: Text
  , layerCompressedBytes :: Natural
  , layerChainId :: Text
  , layerUnpackedBytes :: Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ImagePlatformArtifact = ImagePlatformArtifact
  { artifactPlatform :: ImagePlatform
  , artifactChildDigest :: Text
  , artifactChildManifestBytes :: Natural
  , artifactConfigDigest :: Text
  , artifactConfigBytes :: Natural
  , artifactLayers :: [ImageLayer]
  , artifactPeakImportWorkspace :: Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ImageArtifact = ImageArtifact
  { imageIdentity :: Text
  , imageIndexDigest :: Text
  , imageIndexBytes :: Natural
  , imagePlatforms :: [ImagePlatformArtifact]
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ArtifactBounds = ArtifactBounds
  { boundIndexBytes :: Natural
  , boundChildManifestBytes :: Natural
  , boundConfigBytes :: Natural
  , boundCompressedLayerBytes :: Natural
  , boundUnpackedLayerBytes :: Natural
  , boundImportWorkspaceBytes :: Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data RegistryObjectKind
  = RegistryLayer
  | RegistryConfig ImagePlatform
  | RegistryChildManifest ImagePlatform
  | RegistryIndex
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data RegistryStoredArtifact = RegistryStoredArtifact
  { registryObjectDigest :: Text
  , registryObjectKind :: RegistryObjectKind
  , registryObjectStoredBytes :: Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ArtifactError
  = ArtifactIdentityEmpty
  | ArtifactPlatformSetMismatch
  | ArtifactLayerSetEmpty ImagePlatform
  | ArtifactDigestInvalid Text
  | ArtifactStoredBytesZero Text
  | ArtifactIndexExceeded Natural Natural
  | ArtifactChildManifestExceeded ImagePlatform Natural Natural
  | ArtifactConfigExceeded ImagePlatform Natural Natural
  | ArtifactCompressedLayerExceeded Text Natural Natural
  | ArtifactUnpackedLayerExceeded Text Natural Natural
  | ArtifactImportWorkspaceExceeded ImagePlatform Natural Natural
  | ArtifactDigestSizeConflict Text Natural Natural
  | ArtifactDigestKindConflict Text RegistryObjectKind RegistryObjectKind
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

validateImageArtifact :: ArtifactBounds -> ImageArtifact -> Either ArtifactError ()
validateImageArtifact bounds artifact = do
  if Text.null (imageIdentity artifact) then Left ArtifactIdentityEmpty else Right ()
  validateDigest (imageIndexDigest artifact)
  nonzero (imageIndexDigest artifact) (imageIndexBytes artifact)
  within ArtifactIndexExceeded (imageIndexBytes artifact) (boundIndexBytes bounds)
  if Set.fromList (fmap artifactPlatform (imagePlatforms artifact)) == Set.fromList [LinuxAmd64, LinuxArm64]
    then Right ()
    else Left ArtifactPlatformSetMismatch
  mapM_ validatePlatform (imagePlatforms artifact)
  _ <- registryStoredArtifacts artifact
  Right ()
 where
  validatePlatform platform = do
    let platformName = artifactPlatform platform
    if null (artifactLayers platform) then Left (ArtifactLayerSetEmpty platformName) else Right ()
    validateDigest (artifactChildDigest platform)
    validateDigest (artifactConfigDigest platform)
    nonzero (artifactChildDigest platform) (artifactChildManifestBytes platform)
    nonzero (artifactConfigDigest platform) (artifactConfigBytes platform)
    within (ArtifactChildManifestExceeded platformName) (artifactChildManifestBytes platform) (boundChildManifestBytes bounds)
    within (ArtifactConfigExceeded platformName) (artifactConfigBytes platform) (boundConfigBytes bounds)
    within (ArtifactImportWorkspaceExceeded platformName) (artifactPeakImportWorkspace platform) (boundImportWorkspaceBytes bounds)
    mapM_ validateLayer (artifactLayers platform)
  validateLayer layer = do
    validateDigest (layerDigest layer)
    validateDigest (layerChainId layer)
    nonzero (layerDigest layer) (layerCompressedBytes layer)
    nonzero (layerChainId layer) (layerUnpackedBytes layer)
    within (ArtifactCompressedLayerExceeded (layerDigest layer)) (layerCompressedBytes layer) (boundCompressedLayerBytes bounds)
    within (ArtifactUnpackedLayerExceeded (layerDigest layer)) (layerUnpackedBytes layer) (boundUnpackedLayerBytes bounds)

registryStoredArtifacts :: ImageArtifact -> Either ArtifactError (Map Text RegistryStoredArtifact)
registryStoredArtifacts artifact = foldl insertObject (Right Map.empty) objects
 where
  objects =
    RegistryStoredArtifact (imageIndexDigest artifact) RegistryIndex (imageIndexBytes artifact)
      : concatMap platformObjects (imagePlatforms artifact)
  platformObjects platform =
    RegistryStoredArtifact (artifactChildDigest platform) (RegistryChildManifest (artifactPlatform platform)) (artifactChildManifestBytes platform)
      : RegistryStoredArtifact (artifactConfigDigest platform) (RegistryConfig (artifactPlatform platform)) (artifactConfigBytes platform)
      : [RegistryStoredArtifact (layerDigest layer) RegistryLayer (layerCompressedBytes layer) | layer <- artifactLayers platform]
  insertObject failure@(Left _) _ = failure
  insertObject (Right accumulated) object = case Map.lookup (registryObjectDigest object) accumulated of
    Nothing -> Right (Map.insert (registryObjectDigest object) object accumulated)
    Just resident
      | registryObjectStoredBytes resident /= registryObjectStoredBytes object ->
          Left
            ( ArtifactDigestSizeConflict
                (registryObjectDigest object)
                (registryObjectStoredBytes resident)
                (registryObjectStoredBytes object)
            )
      | registryObjectKind resident /= registryObjectKind object ->
          Left
            ( ArtifactDigestKindConflict
                (registryObjectDigest object)
                (registryObjectKind resident)
                (registryObjectKind object)
            )
      | otherwise -> Right accumulated

renderArtifactError :: ArtifactError -> Text
renderArtifactError problem = case problem of
  ArtifactIdentityEmpty -> "ArtifactIdentityEmpty"
  ArtifactPlatformSetMismatch -> "ArtifactPlatformSetMismatch"
  ArtifactLayerSetEmpty _ -> "ArtifactLayerSetEmpty"
  ArtifactDigestInvalid _ -> "ArtifactDigestInvalid"
  ArtifactStoredBytesZero _ -> "ArtifactStoredBytesZero"
  ArtifactIndexExceeded _ _ -> "ArtifactIndexExceeded"
  ArtifactChildManifestExceeded _ _ _ -> "ArtifactChildManifestExceeded"
  ArtifactConfigExceeded _ _ _ -> "ArtifactConfigExceeded"
  ArtifactCompressedLayerExceeded _ _ _ -> "ArtifactCompressedLayerExceeded"
  ArtifactUnpackedLayerExceeded _ _ _ -> "ArtifactUnpackedLayerExceeded"
  ArtifactImportWorkspaceExceeded _ _ _ -> "ArtifactImportWorkspaceExceeded"
  ArtifactDigestSizeConflict _ _ _ -> "ArtifactDigestSizeConflict"
  ArtifactDigestKindConflict _ _ _ -> "ArtifactDigestKindConflict"

validateDigest :: Text -> Either ArtifactError ()
validateDigest digest =
  if Text.length digest == 71
      && "sha256:" `Text.isPrefixOf` digest
      && Text.all (`elem` ("0123456789abcdef" :: String)) (Text.drop 7 digest)
    then Right ()
    else Left (ArtifactDigestInvalid digest)

nonzero :: Text -> Natural -> Either ArtifactError ()
nonzero identity bytes = if bytes > 0 then Right () else Left (ArtifactStoredBytesZero identity)

within
  :: (Natural -> Natural -> ArtifactError)
  -> Natural
  -> Natural
  -> Either ArtifactError ()
within constructor actual bound = if actual <= bound then Right () else Left (constructor actual bound)
