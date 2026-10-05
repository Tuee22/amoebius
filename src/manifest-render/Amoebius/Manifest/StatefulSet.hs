{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

-- | StatefulSet rendering. A persistent volume claim is born only from a StatefulSet's
-- claim template, so the claim a StatefulSet owns is made here and nowhere else: the body
-- of a claim is a type whose constructor no other module can reach.
module Amoebius.Manifest.StatefulSet
  ( renderStatefulSet
  ) where

import Amoebius.Capacity.RenderSource (K8sObjectIdentity (K8sObjectIdentity))
import Amoebius.Manifest.K8sObject
import Amoebius.Manifest.Types.Internal (ClaimBody (..))
import Amoebius.Storage.Witness
  ( VolumeRefusal (..)
  , VolumeWitness
  , mkVolumeWitness
  , storageClassName
  , volumeClaimName
  , volumePvName
  , volumeSize
  )
import Amoebius.Vocabulary (Quantity, Unit (..), quantityValue)
import Data.Text (Text)

-- | A rendered StatefulSet with the claim of its one ordinal: the StatefulSet itself, then
-- the claim named from its identity, sized by the witness, and pre-bound to the volume its
-- identity names. A StatefulSet outside a namespace owns no claim, so it is refused.
renderStatefulSet :: K8sObject -> Quantity 'DurableUnit -> Either VolumeRefusal [K8sObject]
renderStatefulSet statefulSet size = do
  namespace <- maybe (Left (NotAnIdentityLabel "")) Right (metadataNamespace (objectMetadata statefulSet))
  volume <- mkVolumeWitness namespace (metadataName (objectMetadata statefulSet)) 0 size
  pure [statefulSet, claimFor statefulSet volume]

claimFor :: K8sObject -> VolumeWitness -> K8sObject
claimFor statefulSet volume =
  statefulSet
    { objectIdentity = K8sObjectIdentity (identityText (objectIdentity statefulSet) <> "/pvc")
    , objectApiVersion = "v1"
    , objectKind = PersistentVolumeClaimKind
    , objectMetadata = (objectMetadata statefulSet) {metadataName = volumeClaimName volume}
    , objectSpec = ClaimSpec (ClaimBody storageClassName (quantityValue (volumeSize volume)) (volumePvName volume) (metadataName (objectMetadata statefulSet)))
    }
 where
  identityText :: K8sObjectIdentity -> Text
  identityText (K8sObjectIdentity text) = text
