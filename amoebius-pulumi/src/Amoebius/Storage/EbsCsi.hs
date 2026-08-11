{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Static-only consumption of provider-created EBS identities.
module Amoebius.Storage.EbsCsi
  ( CsiInstall (..)
  , CsiBinary (..)
  , StaticPvDemand (..)
  , StaticPvSpec (..)
  , EbsCsiError (..)
  , staticOnlyInstall
  , bakedCsiInventory
  , renderStaticPv
  , requiredAttachmentSlots
  ) where

import Amoebius.Pulumi.Ebs (MaterializedProviderVolume, materializedRequest, materializedVolumeId)
import Amoebius.Pulumi.Ebs qualified as Ebs
import Data.List (nub)
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)

data CsiBinary = CsiBinary
  { csiBinaryName :: Text
  , csiBinaryPath :: FilePath
  , csiBinaryVersion :: Text
  , csiBinaryArchitectures :: [Text]
  }
  deriving stock (Eq, Show)

data CsiInstall = CsiInstall
  { installDriver :: Text
  , installStorageClassProvisioner :: Text
  , installExternalProvisionerContainers :: Natural
  , installUsesHelm :: Bool
  , installUsesPublicImage :: Bool
  }
  deriving stock (Eq, Show)

data StaticPvDemand = StaticPvDemand
  { staticPvName :: Text
  , staticPvStorageClass :: Text
  , staticPvMountedClaims :: [Text]
  , staticPvDeclaredAttachLimit :: Natural
  , staticPvObservedAttachLimit :: Natural
  }
  deriving stock (Eq, Show)

data StaticPvSpec = StaticPvSpec
  { pvName :: Text
  , pvStorageClass :: Text
  , pvCapacityBytes :: Natural
  , pvReclaimPolicy :: Text
  , pvCsiDriver :: Text
  , pvVolumeHandle :: Text
  , pvZoneKey :: Text
  , pvZone :: Text
  }
  deriving stock (Eq, Show)

data EbsCsiError
  = StaticPvIdentityEmpty
  | ExternalProvisionerForbidden
  | DynamicStorageClassForbidden
  | AttachSlotsInsufficient Natural Natural
  deriving stock (Eq, Show)

staticOnlyInstall :: CsiInstall
staticOnlyInstall =
  CsiInstall
    { installDriver = "ebs.csi.aws.com"
    , installStorageClassProvisioner = storageClass
    , installExternalProvisionerContainers = provisioners
    , installUsesHelm = False
    , installUsesPublicImage = False
    }
 where
#ifdef PHASE46_DYNAMIC_PROVISIONER_MUTANT
  storageClass = "ebs.csi.aws.com"
  provisioners = 1
#else
  storageClass = "kubernetes.io/no-provisioner"
  provisioners = 0
#endif

bakedCsiInventory :: [CsiBinary]
bakedCsiInventory =
  [ CsiBinary "aws-ebs-csi-controller" "/usr/local/libexec/amoebius/aws-ebs-csi-driver" "v1.48.0" architectures
  , CsiBinary "aws-ebs-csi-node" "/usr/local/libexec/amoebius/aws-ebs-csi-driver" "v1.48.0" architectures
  , CsiBinary "csi-attacher" "/usr/local/libexec/amoebius/csi-attacher" "v4.9.0" architectures
  , CsiBinary "csi-node-driver-registrar" "/usr/local/libexec/amoebius/csi-node-driver-registrar" "v2.14.0" architectures
  , CsiBinary "csi-liveness-probe" "/usr/local/libexec/amoebius/livenessprobe" "v2.16.0" architectures
  ]
 where
  architectures = ["amd64", "arm64"]

renderStaticPv
  :: MaterializedProviderVolume
  -> StaticPvDemand
  -> Either EbsCsiError StaticPvSpec
renderStaticPv volume demand
  | any Text.null [staticPvName demand, staticPvStorageClass demand] = Left StaticPvIdentityEmpty
  | installExternalProvisionerContainers staticOnlyInstall /= 0 = Left ExternalProvisionerForbidden
  | installStorageClassProvisioner staticOnlyInstall /= "kubernetes.io/no-provisioner" = Left DynamicStorageClassForbidden
  | required > limit = Left (AttachSlotsInsufficient required limit)
  | otherwise =
      Right
        StaticPvSpec
          { pvName = staticPvName demand
          , pvStorageClass = staticPvStorageClass demand
          , pvCapacityBytes = Ebs.requestProvisionedBytes request
          , pvReclaimPolicy = "Retain"
          , pvCsiDriver = installDriver staticOnlyInstall
          , pvVolumeHandle = materializedVolumeId volume
          , pvZoneKey = "topology.ebs.csi.aws.com/zone"
          , pvZone = Ebs.requestZone request
          }
 where
  request = materializedRequest volume
  required = requiredAttachmentSlots (staticPvMountedClaims demand)
  limit = min (staticPvDeclaredAttachLimit demand) (staticPvObservedAttachLimit demand)

requiredAttachmentSlots :: [Text] -> Natural
requiredAttachmentSlots = fromIntegral . length . nub
