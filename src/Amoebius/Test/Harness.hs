module Amoebius.Test.Harness
  ( HarnessActor (..)
  , DeleteError (..)
  , authorizeBackingDelete
  ) where

import Amoebius.Test.Topology (Allocation (..))

data HarnessActor = EverydayActor | ElevatedTestHarness
  deriving stock (Eq, Show)

data DeleteError = ElevatedHarnessRequired | TestOwnedBackingRequired
  deriving stock (Eq, Show)

authorizeBackingDelete :: HarnessActor -> Allocation -> Either DeleteError ()
authorizeBackingDelete EverydayActor _ = Left ElevatedHarnessRequired
authorizeBackingDelete ElevatedTestHarness allocation
  | allocationTestOwned allocation = Right ()
  | otherwise = Left TestOwnedBackingRequired
