{-# LANGUAGE OverloadedStrings #-}

-- Positive decode anchor: dhall/examples/trivial_app.dhall
module OwnerLegal where

import Amoebius.Dsl.Ref

data VolumeResource

volume :: Owned OwnerPrimary VolumeResource
volume = mkOwned OwnerPrimaryToken "trivial-volume"

attached :: OwnedAttachment OwnerPrimary VolumeResource
attached = attachOwned OwnerPrimaryToken volume
