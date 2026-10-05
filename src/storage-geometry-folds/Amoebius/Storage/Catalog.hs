{-# LANGUAGE DataKinds #-}

-- | The catalogue of volume sizes: the explicit, hard-capped bytes each capability's
-- provider gives every StatefulSet member. A size is authored here, once, never defaulted.
module Amoebius.Storage.Catalog
  ( volumeBytesFor
  ) where

import Amoebius.Vocabulary (CapabilityArm (..), Quantity (..), Unit (..))

-- | The explicit, hard-capped size of the volume each member of a capability's provider
-- owns, in bytes. A capability whose provider is a Deployment owns none.
volumeBytesFor :: CapabilityArm -> Maybe (Quantity 'DurableUnit)
volumeBytesFor arm = case arm of
  ObjectStore -> Just (Quantity 10737418240)
  SecretStore -> Just (Quantity 1073741824)
  MessageBus -> Just (Quantity 21474836480)
  Sql -> Just (Quantity 8589934592)
  Identity -> Just (Quantity 2147483648)
  Observability -> Just (Quantity 21474836480)
  Registry -> Just (Quantity 21474836480)
  Edge -> Nothing
  InferenceEngine -> Nothing
