module Amoebius.Cli
  ( dryRun
  ) where

import Amoebius.Kernel.Chain (PlanConfig, chain)
import Amoebius.Kernel.Plan (renderChainPlan)
import Data.ByteString.Lazy (ByteString)

dryRun :: PlanConfig -> ByteString
dryRun = renderChainPlan . chain
