{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Selected-platform OCI import demand routed through the node's declared
-- kubelet/containerd filesystem layout.
module Amoebius.Image.NodeLoad
  ( RegistryPullPolicy (..)
  , NodeLoadPlan (..)
  , ObservedNodeLoadInventory (..)
  , ProvisionedNodeLoad
  , provisionedNodeLoadFingerprint
  , provisionedNodeLoadImageIdentity
  , provisionedNodeLoadPlatform
  , provisionedNodeLoadImageDemand
  , provisionedNodeLoadStorage
  , NodeLoadError (..)
  , provisionNodeLoad
  , renderNodeLoadError
  ) where

import Amoebius.Capacity.NodeLocalStorage
  ( ImageArtifactRequirement (..)
  , ImageMetadataCatalog (..)
  , KubeletFilesystemLayout
  , NodeImageStorageDemand (..)
  , NodeLocalStorageError
  , NodeStorageComponent
  , ProvisionedNodeImageStorageDemand (..)
  , ProvisionedNodeLocalStorage
  , fitLayoutComponents
  , provisionNodeImageStorage
  , validateFilesystemLayoutObservation
  )
import Amoebius.Image.Artifact
  ( ImageArtifact (..)
  , ImageLayer (..)
  , ImagePlatform (..)
  , ImagePlatformArtifact (..)
  )
import Control.DeepSeq (NFData)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Text (Text)
import GHC.Generics (Generic)

data RegistryPullPolicy = PullNever | PullIfNotPresent | PullAlways
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data NodeLoadPlan = NodeLoadPlan
  { nodeLoadArtifact :: ImageArtifact
  , nodeLoadPlatform :: ImagePlatform
  , nodeLoadDeclaredLayout :: KubeletFilesystemLayout
  , nodeLoadStorageModel :: Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ObservedNodeLoadInventory = ObservedNodeLoadInventory
  { observedNodeLoadFingerprint :: Text
  , observedNodeLoadLayout :: KubeletFilesystemLayout
  , observedNodeLoadComponents :: [NodeStorageComponent]
  , observedNodeLoadResidentImages :: Set Text
  , observedNodeLoadStorageModels :: Set Text
  , observedNodeLoadPullPolicy :: RegistryPullPolicy
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ProvisionedNodeLoad = ProvisionedNodeLoad
  { provisionedNodeLoadFingerprint :: Text
  , provisionedNodeLoadImageIdentity :: Text
  , provisionedNodeLoadPlatform :: ImagePlatform
  , provisionedNodeLoadImageDemand :: ProvisionedNodeImageStorageDemand
  , provisionedNodeLoadStorage :: ProvisionedNodeLocalStorage
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data NodeLoadError
  = NodeLoadPlatformMissing ImagePlatform
  | NodeLoadPlatformDuplicate ImagePlatform
  | NodeLoadPullPolicyMismatch RegistryPullPolicy RegistryPullPolicy
  | NodeLoadStorageError NodeLocalStorageError
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

provisionNodeLoad
  :: NodeLoadPlan
  -> ObservedNodeLoadInventory
  -> Either NodeLoadError ProvisionedNodeLoad
provisionNodeLoad plan observed = do
  if observedNodeLoadPullPolicy observed == PullNever
    then Right ()
    else Left (NodeLoadPullPolicyMismatch PullNever (observedNodeLoadPullPolicy observed))
  either (Left . NodeLoadStorageError) Right
    (validateFilesystemLayoutObservation (nodeLoadDeclaredLayout plan) (observedNodeLoadLayout observed))
  platform <- selectPlatform (nodeLoadPlatform plan) (imagePlatforms (nodeLoadArtifact plan))
  let artifact = nodeLoadArtifact plan
      requirement = toRequirement artifact platform
      catalog = toCatalog artifact platform (observedNodeLoadStorageModels observed)
      demand =
        NodeImageStorageDemand
          { nodeImageStorageModel = nodeLoadStorageModel plan
          , nodeImageArtifacts = [requirement]
          , nodeResidentImages = observedNodeLoadResidentImages observed
          , nodePullConcurrency = 1
          , nodePullWorkspaceBytes = Map.singleton (imageIdentity artifact) (artifactPeakImportWorkspace platform)
          }
  imageDemand <- either (Left . NodeLoadStorageError) Right (provisionNodeImageStorage catalog demand)
  storage <-
    either (Left . NodeLoadStorageError) Right
      (fitLayoutComponents (observedNodeLoadLayout observed) (observedNodeLoadComponents observed <> provisionedImageComponents imageDemand))
  pure
    ProvisionedNodeLoad
      { provisionedNodeLoadFingerprint = observedNodeLoadFingerprint observed
      , provisionedNodeLoadImageIdentity = imageIdentity artifact
      , provisionedNodeLoadPlatform = artifactPlatform platform
      , provisionedNodeLoadImageDemand = imageDemand
      , provisionedNodeLoadStorage = storage
      }

renderNodeLoadError :: NodeLoadError -> Text
renderNodeLoadError problem = case problem of
  NodeLoadPlatformMissing _ -> "NodeLoadPlatformMissing"
  NodeLoadPlatformDuplicate _ -> "NodeLoadPlatformDuplicate"
  NodeLoadPullPolicyMismatch _ _ -> "NodeLoadPullPolicyMismatch"
  NodeLoadStorageError _ -> "NodeLoadStorageError"

selectPlatform
  :: ImagePlatform
  -> [ImagePlatformArtifact]
  -> Either NodeLoadError ImagePlatformArtifact
selectPlatform selected platforms = case filter ((== selected) . artifactPlatform) platforms of
  [] -> Left (NodeLoadPlatformMissing selected)
  [platform] -> Right platform
  _ -> Left (NodeLoadPlatformDuplicate selected)

toRequirement :: ImageArtifact -> ImagePlatformArtifact -> ImageArtifactRequirement
toRequirement artifact platform =
  ImageArtifactRequirement
    { imageArtifactId = imageIdentity artifact
    , imageTargetPlatform = platformText (artifactPlatform platform)
    , imageIndexDigest = Amoebius.Image.Artifact.imageIndexDigest artifact
    , imageManifestDigest = artifactChildDigest platform
    , imageConfigDigest = artifactConfigDigest platform
    , imageLayerDigests = fmap layerDigest (artifactLayers platform)
    , imageSnapshotChains = fmap layerChainId (artifactLayers platform)
    }

toCatalog :: ImageArtifact -> ImagePlatformArtifact -> Set Text -> ImageMetadataCatalog
toCatalog artifact platform models =
  ImageMetadataCatalog
    { imageStoredObjects =
        Map.fromList
          ( (Amoebius.Image.Artifact.imageIndexDigest artifact, imageIndexBytes artifact)
              : (artifactChildDigest platform, artifactChildManifestBytes platform)
              : (artifactConfigDigest platform, artifactConfigBytes platform)
              : [(layerDigest layer, layerCompressedBytes layer) | layer <- artifactLayers platform]
          )
    , imagePlatformManifests =
        Map.singleton
          (Amoebius.Image.Artifact.imageIndexDigest artifact, platformText (artifactPlatform platform))
          (artifactChildDigest platform)
    , imageManifestConfigs = Map.singleton (artifactChildDigest platform) (artifactConfigDigest platform)
    , imageManifestLayers = Map.singleton (artifactChildDigest platform) (fmap layerDigest (artifactLayers platform))
    , imageSnapshotBytes = Map.fromList [(layerChainId layer, layerUnpackedBytes layer) | layer <- artifactLayers platform]
    , imageStorageModels = models
    }

platformText :: ImagePlatform -> Text
platformText platform = case platform of
  LinuxAmd64 -> "linux/amd64"
  LinuxArm64 -> "linux/arm64"
