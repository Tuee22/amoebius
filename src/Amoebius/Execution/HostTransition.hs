{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

module Amoebius.Execution.HostTransition
  ( HostStartAuthorization (..)
  , HostTransitionError (..)
  , authorizeHostStart
  ) where

import Amoebius.Execution.AcceleratorRelease
import Control.DeepSeq (NFData)
import Data.Text (Text)
import GHC.Generics (Generic)

data HostStartAuthorization
  = NoPrior Text
  | OrdinaryAfterExit Text AcceleratorRelease
  | CudaAfterDeviceRelease Text AcceleratorRelease
  | MetalAfterDrain Text AcceleratorRelease
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data HostTransitionError = HostSnapshotChanged | HostReleaseInvalid ReleaseError | HostReleaseKindMismatch
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

authorizeHostStart :: Text -> Text -> HostStartAuthorization -> Either HostTransitionError ()
authorizeHostStart expected observed authorization = do
  if expected == observed then Right () else Left HostSnapshotChanged
  case authorization of
    NoPrior _ -> Right ()
    OrdinaryAfterExit _ release@OrdinaryRelease {} -> releaseValid release
    CudaAfterDeviceRelease _ release@CudaRelease {} -> releaseValid release
    MetalAfterDrain _ release@MetalRelease {} -> releaseValid release
    _ -> Left HostReleaseKindMismatch
 where
  releaseValid = either (Left . HostReleaseInvalid) Right . validateAcceleratorRelease
