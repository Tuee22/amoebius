module Amoebius.Multicluster.DnsRepoint
  ( DnsTarget (..)
  , DnsObservation (..)
  , repointDns
  , dnsConverged
  ) where

data DnsTarget = SourceDns | TargetDns
  deriving stock (Eq, Ord, Show)

data DnsObservation = DnsObservation
  { authoritativeTarget :: DnsTarget
  , observedTarget :: DnsTarget
  , ttlSeconds :: Int
  }
  deriving stock (Eq, Show)

repointDns :: DnsTarget -> Int -> DnsObservation
repointDns target ttl = DnsObservation target target ttl

dnsConverged :: DnsObservation -> Bool
dnsConverged observation =
  authoritativeTarget observation == observedTarget observation
    && ttlSeconds observation > 0
