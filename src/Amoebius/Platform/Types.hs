{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Platform.Types
  ( ResourceEnvelope (..)
  , validateResourceEnvelope
  , PlatformObject (..)
  ) where

import Control.DeepSeq (NFData)
import Data.Aeson (FromJSON, ToJSON)
import Data.Text (Text)
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data ResourceEnvelope = ResourceEnvelope
  { requestCpuMillis :: Natural
  , limitCpuMillis :: Natural
  , requestMemoryBytes :: Natural
  , limitMemoryBytes :: Natural
  , requestEphemeralBytes :: Natural
  , limitEphemeralBytes :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (FromJSON, NFData, ToJSON)

validateResourceEnvelope :: ResourceEnvelope -> Either Text ResourceEnvelope
validateResourceEnvelope envelope
  | requestCpuMillis envelope == 0 || requestCpuMillis envelope > limitCpuMillis envelope = Left "invalid-cpu-envelope"
  | requestMemoryBytes envelope == 0 || requestMemoryBytes envelope > limitMemoryBytes envelope = Left "invalid-memory-envelope"
  | requestEphemeralBytes envelope > limitEphemeralBytes envelope = Left "invalid-ephemeral-envelope"
  | otherwise = Right envelope

data PlatformObject = PlatformObject
  { objectKind :: Text
  , objectNamespace :: Text
  , objectName :: Text
  , objectReplicas :: Natural
  , objectImage :: Text
  , objectArguments :: [Text]
  , objectResources :: Maybe ResourceEnvelope
  , objectCache :: Maybe Natural
  , objectAccelerator :: Maybe Text
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (FromJSON, NFData, ToJSON)
