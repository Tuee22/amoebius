{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | The storage witness: one volume per StatefulSet ordinal, with an explicit size, the one
-- inert storage class, and names that are pure functions of identity. A 'VolumeWitness'
-- exists only as the result of 'mkVolumeWitness', which refuses a size of zero and an
-- identity whose parts could make two witnesses name one volume.
module Amoebius.Storage.Witness
  ( VolumeWitness
  , VolumeRefusal (..)
  , mkVolumeWitness
  , volumeNamespace
  , volumeStatefulSet
  , volumeOrdinal
  , volumeSize
  , volumeClaimName
  , volumePvName
  , storageClassName
  , claimTemplateName
  , volumeRefusalTag
  ) where

import Amoebius.Vocabulary (Quantity (..), Unit (..), isLabel)
import Control.DeepSeq (NFData)
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

-- | A volume a StatefulSet's claim template will bind. The constructor is private.
data VolumeWitness = VolumeWitness
  { volumeNamespace :: Text
  , volumeStatefulSet :: Text
  , volumeOrdinal :: Natural
  , volumeSize :: Quantity 'DurableUnit
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data VolumeRefusal
  = EmptyVolume Text
  | NotAnIdentityLabel Text
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

volumeRefusalTag :: VolumeRefusal -> Text
volumeRefusalTag refusal = case refusal of
  EmptyVolume _ -> "EmptyVolume"
  NotAnIdentityLabel _ -> "NotAnIdentityLabel"

-- | The one storage class every cluster has: inert, retaining, bound on first use.
storageClassName :: Text
storageClassName = "amoebius-retained"

-- | The name of the claim a StatefulSet's template declares.
claimTemplateName :: Text
claimTemplateName = "data"

-- | A namespace and a StatefulSet name are DNS labels, so neither can contain the dot the
-- persistent volume name joins them on; a size of zero would be a default in disguise.
mkVolumeWitness :: Text -> Text -> Natural -> Quantity 'DurableUnit -> Either VolumeRefusal VolumeWitness
mkVolumeWitness namespace statefulSet ordinal size
  | not (isLabel namespace) = Left (NotAnIdentityLabel namespace)
  | not (isLabel statefulSet) = Left (NotAnIdentityLabel statefulSet)
  | size == 0 = Left (EmptyVolume (namespace <> "/" <> statefulSet))
  | otherwise = Right (VolumeWitness namespace statefulSet ordinal size)

-- | The claim a StatefulSet's ordinal owns: @<claim>-<statefulset>-<ordinal>@.
volumeClaimName :: VolumeWitness -> Text
volumeClaimName volume = Text.intercalate "-" [claimTemplateName, volumeStatefulSet volume, Text.pack (show (volumeOrdinal volume))]

-- | The persistent volume the claim is pre-bound to: @<namespace>.<statefulset>.pv-<ordinal>@.
volumePvName :: VolumeWitness -> Text
volumePvName volume = Text.intercalate "." [volumeNamespace volume, volumeStatefulSet volume, "pv-" <> Text.pack (show (volumeOrdinal volume))]
