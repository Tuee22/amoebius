-- | The kernel's view of the status frontier.
--
-- The frontier itself lives in the plan-decisions library ('Amoebius.Plan.StatusFrontier');
-- this module re-exports it so every kernel consumer keeps its import while the one
-- status-vector authority moves out of the validator (DL-0009).
module Amoebius.Validation.StatusFrontier
  ( module Amoebius.Plan.StatusFrontier
  ) where

import Amoebius.Plan.StatusFrontier
