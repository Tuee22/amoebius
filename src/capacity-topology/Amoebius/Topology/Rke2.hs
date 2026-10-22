{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

-- | Server cardinality is the payload's shape. A quorum cannot be paired with
-- a different server list, and there is no zero- or two-server constructor.
module Amoebius.Topology.Rke2 (Rke2Quorum (..), rke2Servers, rke2ServerHosts) where

import Control.DeepSeq (NFData)
import Data.List.NonEmpty (NonEmpty (..))
import Data.List.NonEmpty qualified as NonEmpty
import GHC.Generics (Generic)

data Rke2Quorum host
  = Single host
  | Three host host host
  | Five host host host host host
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

rke2Servers :: Rke2Quorum host -> [host]
rke2Servers = NonEmpty.toList . rke2ServerHosts

rke2ServerHosts :: Rke2Quorum host -> NonEmpty host
rke2ServerHosts quorum = case quorum of
  Single first -> first :| []
  Three first second third -> first :| [second, third]
  Five first second third fourth fifth -> first :| [second, third, fourth, fifth]
