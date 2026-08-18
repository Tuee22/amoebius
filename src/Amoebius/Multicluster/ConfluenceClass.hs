{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Multicluster.ConfluenceClass
  ( CrossingInvariant (..)
  , ConfluenceClass (..)
  , WiringError (..)
  , invariantName
  , crossingInvariants
  , classifyInvariant
  , activeActiveAllowed
  , admitActiveActive
  ) where

import Data.Text (Text)

data CrossingInvariant
  = ContentAddressedBlob
  | WorkIdEventFold
  | RelationalWorkRow
  | GatewayAuthority
  | LatestPointer
  | ClusterVpnIpAllocation
  | Unclassified Text
  deriving stock (Eq, Ord, Show)

data ConfluenceClass = Confluent | NonConfluent
  deriving stock (Eq, Ord, Show)

data WiringError = ActiveActiveRequiresConfluence Text
  deriving stock (Eq, Show)

crossingInvariants :: [CrossingInvariant]
crossingInvariants =
  [ ContentAddressedBlob
  , WorkIdEventFold
  , RelationalWorkRow
  , GatewayAuthority
  , LatestPointer
  , ClusterVpnIpAllocation
  ]

invariantName :: CrossingInvariant -> Text
invariantName invariant = case invariant of
  ContentAddressedBlob -> "content-addressed-blob"
  WorkIdEventFold -> "work-id-event-fold"
  RelationalWorkRow -> "relational-work-row"
  GatewayAuthority -> "gateway-authority"
  LatestPointer -> "latest-pointer"
  ClusterVpnIpAllocation -> "cluster-vpn-ip-allocation"
  Unclassified name -> name

classifyInvariant :: CrossingInvariant -> ConfluenceClass
classifyInvariant invariant = case invariant of
  ContentAddressedBlob -> Confluent
  WorkIdEventFold -> Confluent
  RelationalWorkRow -> Confluent
  GatewayAuthority -> NonConfluent
  LatestPointer -> NonConfluent
  ClusterVpnIpAllocation -> NonConfluent
#ifdef MULTICLUSTER_SPAWN_GEOREPL_CLASSIFIER_DEFAULT_CONFLUENT_MUTANT
  Unclassified _ -> Confluent
#else
  Unclassified _ -> NonConfluent
#endif

activeActiveAllowed :: CrossingInvariant -> Bool
activeActiveAllowed = (== Confluent) . classifyInvariant

admitActiveActive :: CrossingInvariant -> Either WiringError ()
admitActiveActive invariant
  | activeActiveAllowed invariant = Right ()
  | otherwise = Left (ActiveActiveRequiresConfluence (invariantName invariant))
