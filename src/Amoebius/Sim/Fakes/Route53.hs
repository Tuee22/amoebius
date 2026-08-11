module Amoebius.Sim.Fakes.Route53
  ( Route53State
  , emptyRoute53
  , seedDns
  , writeDns
  , readDns
  , advanceDns
  , supportsCAS
  ) where

import Amoebius.Sim.Env (DnsName, DnsValue)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map

data Pending = Pending Int DnsValue
  deriving stock (Eq, Show)

data Route53State = Route53State
  { visible :: Map DnsName DnsValue
  , pending :: Map DnsName Pending
  , propagationDelay :: Int
  }
  deriving stock (Eq, Show)

emptyRoute53 :: Int -> Route53State
emptyRoute53 delayTicks = Route53State Map.empty Map.empty delayTicks

seedDns :: DnsName -> DnsValue -> Route53State -> Route53State
seedDns name value state = state {visible = Map.insert name value (visible state)}

writeDns :: DnsName -> DnsValue -> Route53State -> Route53State
writeDns name value state
  | propagationDelay state <= 0 = state {visible = Map.insert name value (visible state)}
  | otherwise = state {pending = Map.insert name (Pending (propagationDelay state) value) (pending state)}

readDns :: DnsName -> Route53State -> Maybe DnsValue
readDns name = Map.lookup name . visible

advanceDns :: Int -> Route53State -> Route53State
advanceDns ticks state =
  let step (ready, waiting) name (Pending remaining value)
        | remaining <= ticks = (Map.insert name value ready, waiting)
        | otherwise = (ready, Map.insert name (Pending (remaining - ticks) value) waiting)
      (newVisible, newPending) = Map.foldlWithKey' step (visible state, Map.empty) (pending state)
   in state {visible = newVisible, pending = newPending}

supportsCAS :: Bool
supportsCAS = False
