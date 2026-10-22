-- | The node inventory owns taints; the placement fold checks them against
-- the workload's derived tolerations before consuming any capacity.
module Amoebius.Placement.Taints (tolerates) where

import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)

tolerates :: Set Text -> Set Text -> Bool
tolerates taints tolerations = Set.difference taints tolerations == Set.empty
