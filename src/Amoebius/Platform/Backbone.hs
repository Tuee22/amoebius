{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Platform.Backbone
  ( BackboneService (..)
  , BackboneState (..)
  , initialBackboneState
  , observeReady
  , mayStart
  , renderBackbone
  , sameHaShape
  ) where

import Amoebius.Platform.LoadBalancer
import Amoebius.Platform.Minio
import Amoebius.Platform.Pulsar
import Amoebius.Platform.Types
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set

data BackboneService = MetalLB | MinIO | Registry | ZooKeeper | BookKeeper | Pulsar | Vault
  deriving stock (Bounded, Enum, Eq, Ord, Show)

newtype BackboneState = BackboneState {readyServices :: Set BackboneService}
  deriving stock (Eq, Show)

initialBackboneState :: BackboneState
initialBackboneState = BackboneState Set.empty

dependencies :: Map BackboneService (Set BackboneService)
dependencies =
  Map.fromList
    [ (MetalLB, Set.empty)
    , (MinIO, Set.singleton MetalLB)
    , (Registry, Set.singleton MinIO)
    , (ZooKeeper, Set.singleton Vault)
    , (BookKeeper, Set.fromList [Vault, ZooKeeper])
    , (Pulsar, Set.fromList [Vault, MinIO, ZooKeeper, BookKeeper])
    , (Vault, Set.empty)
    ]

mayStart :: BackboneState -> BackboneService -> Bool
mayStart state service = Map.findWithDefault Set.empty service dependencies `Set.isSubsetOf` readyServices state

observeReady :: BackboneState -> BackboneService -> Either String BackboneState
observeReady state service
  | mayStart state service = Right state {readyServices = Set.insert service (readyServices state)}
  | otherwise = Left ("dependency-not-ready:" <> show service)

renderBackbone :: LoadBalancerPlan -> ProvisionedMinio -> ProvisionedPulsarBackbone -> [PlatformObject]
renderBackbone loadBalancer minio pulsar = renderLoadBalancer loadBalancer <> renderMinio minio <> renderPulsar pulsar

sameHaShape :: [PlatformObject] -> [PlatformObject] -> Bool
sameHaShape left right = fmap normalize left == fmap normalize right
 where
  normalize object = object {objectReplicas = 0}
