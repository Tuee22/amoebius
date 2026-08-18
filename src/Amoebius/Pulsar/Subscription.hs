module Amoebius.Pulsar.Subscription
  ( SubscriptionType (..)
  , subscriptionTypes
  ) where

data SubscriptionType = Exclusive | Failover | Shared | KeyShared
  deriving stock (Bounded, Enum, Eq, Ord, Show)

subscriptionTypes :: [SubscriptionType]
subscriptionTypes = [minBound .. maxBound]
