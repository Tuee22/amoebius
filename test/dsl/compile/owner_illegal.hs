{-# LANGUAGE OverloadedStrings #-}

-- Negative twin of owner_legal.hs: only the owner index differs.
module OwnerIllegal where

import Amoebius.Dsl.Ref

data VolumeResource

volume :: Owned OwnerPrimary VolumeResource
volume = mkOwned OwnerPrimaryToken "trivial-volume"

attached :: OwnedAttachment OwnerSecondary VolumeResource
attached = attachOwned OwnerSecondaryToken volume
