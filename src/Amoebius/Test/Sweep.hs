{-# LANGUAGE CPP #-}

module Amoebius.Test.Sweep
  ( Inventory (..)
  , InventoryEntry (..)
  , InventoryDiff (..)
  , diffInventory
  , inventoryClean
  ) where

import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)

data InventoryEntry = InventoryEntry
  { inventoryKind :: Text
  , inventoryIdentity :: Text
  , inventoryTestOwned :: Bool
  }
  deriving stock (Eq, Ord, Show)

newtype Inventory = Inventory (Set InventoryEntry)
  deriving stock (Eq, Show)

newtype InventoryDiff = InventoryDiff (Set InventoryEntry)
  deriving stock (Eq, Show)

diffInventory :: Inventory -> Inventory -> InventoryDiff
diffInventory (Inventory before) (Inventory after) = InventoryDiff
#ifdef TEST_TOPOLOGY_DSL_TAG_QUERY_MUTANT
  (Set.filter inventoryTestOwned after `Set.difference` before)
#else
  (after `Set.difference` before)
#endif

inventoryClean :: InventoryDiff -> Bool
inventoryClean (InventoryDiff leaked) = Set.null leaked
