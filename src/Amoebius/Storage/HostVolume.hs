{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Storage.HostVolume
  ( HostVolumeKind (..)
  , HostVolumeObservation (..)
  , HostVolumeError (..)
  , validateHostVolume
  ) where

import Amoebius.Capacity.Storage (FilesystemPresentation (..))
import Amoebius.Storage.RetainedPV
import Control.DeepSeq (NFData)
import Data.Text (Text)
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data HostVolumeKind = FixedRawFilesystemImage | RawHostDirectory
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data HostVolumeObservation = HostVolumeObservation
  { observedHostVolumeKind :: HostVolumeKind
  , observedRawBytes :: Natural
  , observedUsableBytes :: Natural
  , observedFilesystemType :: Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data HostVolumeError
  = RawHostDirectoryForbidden
  | RawCapacityBelowWitness Natural Natural
  | UsableCapacityBelowRequirement Natural Natural
  | ObservedFilesystemTypeMismatch Text Text
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

validateHostVolume :: RetainedPV -> HostVolumeObservation -> Either HostVolumeError ()
validateHostVolume planned observed
#ifndef PHASE28_RAW_HOST_DIRECTORY_MUTANT
  | observedHostVolumeKind observed /= FixedRawFilesystemImage = Left RawHostDirectoryForbidden
#endif
  | observedRawBytes observed /= retainedPvCapacityBytes planned = Left (RawCapacityBelowWitness (retainedPvCapacityBytes planned) (observedRawBytes observed))
  | observedUsableBytes observed < retainedPvRequiredUsableBytes planned = Left (UsableCapacityBelowRequirement (retainedPvRequiredUsableBytes planned) (observedUsableBytes observed))
  | expectedFilesystem planned /= observedFilesystemType observed = Left (ObservedFilesystemTypeMismatch (expectedFilesystem planned) (observedFilesystemType observed))
  | otherwise = Right ()

expectedFilesystem :: RetainedPV -> Text
expectedFilesystem planned = case retainedPvPresentation planned of
  BlockPresentation -> "block"
  FilesystemPresentation model _ -> model
