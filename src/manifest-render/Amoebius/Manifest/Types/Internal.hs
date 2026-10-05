{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

-- | The body of a persistent volume claim. The constructor is visible to this package only
-- and is imported by the StatefulSet renderer alone, so a claim exists only as the
-- product of a StatefulSet's render.
module Amoebius.Manifest.Types.Internal
  ( ClaimBody (..)
  ) where

import Control.DeepSeq (NFData)
import Data.Aeson (FromJSON, ToJSON)
import Data.Text (Text)
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data ClaimBody = ClaimBody
  { claimStorageClass :: Text
  , claimBytes :: Natural
  , claimVolumeName :: Text
  , claimOwner :: Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (FromJSON, NFData, ToJSON)
