{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Capacity.Phase29Mutation
  ( phase29MutationTargets
  ) where

import Data.Text (Text)

-- Compile-time production mutation selector.  Each Cabal flag changes the
-- production fold library, while the independently compiled oracle fixes the
-- exact fixture that must observe the changed result.
phase29MutationTargets :: Text -> Bool
phase29MutationTargets _ = False
