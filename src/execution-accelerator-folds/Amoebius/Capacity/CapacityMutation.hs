{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Capacity.CapacityMutation
  ( capacityMutationTargets
  ) where

import Data.Text (Text)

-- Compile-time production mutation selector.  Each Cabal flag changes the
-- production fold library, while the independently compiled oracle fixes the
-- exact fixture that must observe the changed result.
capacityMutationTargets :: Text -> Bool
capacityMutationTargets _ = False
