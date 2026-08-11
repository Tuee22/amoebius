{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Platform.LoadBalancer
  ( LoadBalancerPlan (..)
  , provisionLoadBalancer
  , renderLoadBalancer
  ) where

import Amoebius.Platform.Types
import Data.Text (Text)

data LoadBalancerPlan = LoadBalancerPlan
  { loadBalancerAddress :: Text
  , loadBalancerImage :: Text
  , controllerResources :: ResourceEnvelope
  , speakerResources :: ResourceEnvelope
  }
  deriving stock (Eq, Show)

provisionLoadBalancer :: LoadBalancerPlan -> Either Text LoadBalancerPlan
provisionLoadBalancer plan
  | loadBalancerAddress plan == "" = Left "load-balancer-address-empty"
  | otherwise = do
      _ <- validateResourceEnvelope (controllerResources plan)
      _ <- validateResourceEnvelope (speakerResources plan)
      Right plan

renderLoadBalancer :: LoadBalancerPlan -> [PlatformObject]
renderLoadBalancer plan =
  [ PlatformObject "Deployment" "metallb-system" "controller" 1 (loadBalancerImage plan)
      [ "/usr/bin/metallb-controller", "-webhook-mode=disabled", "-namespace=metallb-system"
      , "-deployment=controller", "-ml-secret-name=memberlist"
      ] (Just (controllerResources plan)) Nothing Nothing
  , PlatformObject "DaemonSet" "metallb-system" "speaker" 1 (loadBalancerImage plan)
      [ "/usr/bin/metallb-speaker", "-namespace=metallb-system", "-ml-secret-key-path=/etc/ml"
      , "-ml-labels=app=metallb-speaker", "-node-name=$(NODE_NAME)", "-pod-name=$(POD_NAME)"
      ] (Just (speakerResources plan)) Nothing Nothing
  , PlatformObject "Service" "platform-system" "minio" 1 "" [loadBalancerAddress plan] Nothing Nothing Nothing
  ]
