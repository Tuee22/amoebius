{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Platform.ObjectGatewayPolicy
  ( ApplicationGatewayPolicy, standardApplicationGateway
  , applicationGatewayBucket, applicationGatewayKey, applicationGatewayObjectBytes
  , applicationGatewayFailedHorizonSeconds
  ) where

import Data.Text (Text)
import Numeric.Natural (Natural)

-- One exact object, one inflight overwrite and one failed generation. A new
-- application arm must provide another private policy and reserve its union.
data ApplicationGatewayPolicy = ApplicationGatewayPolicy Text Text Natural Natural
  deriving stock (Eq, Show)

standardApplicationGateway :: ApplicationGatewayPolicy
standardApplicationGateway = ApplicationGatewayPolicy "phase30-canary" "admitted-canary" 4096 3600

applicationGatewayBucket :: ApplicationGatewayPolicy -> Text
applicationGatewayBucket (ApplicationGatewayPolicy bucket _ _ _) = bucket
applicationGatewayKey :: ApplicationGatewayPolicy -> Text
applicationGatewayKey (ApplicationGatewayPolicy _ key _ _) = key
applicationGatewayObjectBytes :: ApplicationGatewayPolicy -> Natural
applicationGatewayObjectBytes (ApplicationGatewayPolicy _ _ bytes _) = bytes
applicationGatewayFailedHorizonSeconds :: ApplicationGatewayPolicy -> Natural
applicationGatewayFailedHorizonSeconds (ApplicationGatewayPolicy _ _ _ seconds) = seconds
