module Amoebius.HostComms.Loopback
  ( LoopbackTarget (..)
  , loopbackTarget
  ) where

import Amoebius.HostComms.NodePort
import Data.Text (Text)
import Data.Word (Word16)

data LoopbackTarget = LoopbackTarget HostService Text Word16
  deriving stock (Eq, Show)

loopbackTarget :: ProvisionedHostComms -> HostService -> Word16 -> Maybe LoopbackTarget
loopbackTarget provisioned service port
  | service `elem` provisionedServices provisioned = Just (LoopbackTarget service (provisionedBindAddress provisioned) port)
  | otherwise = Nothing
