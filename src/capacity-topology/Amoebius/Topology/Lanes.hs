{-# LANGUAGE OverloadedStrings #-}

-- | Labels are a projection of a detected host, never an authored lane list.
module Amoebius.Topology.Lanes (laneLabels, laneLabel) where

import Amoebius.Vocabulary (Detected, Lane (..), architectureName, lanesOf)
import Data.Text (Text)
import Data.Text qualified as Text

laneLabels :: Detected -> [Text]
laneLabels = map laneLabel . lanesOf

laneLabel :: Lane -> Text
laneLabel lane = case lane of
  LinuxCpuAt architecture -> Text.intercalate "/" ["linux-cpu", Text.pack (architectureName architecture)]
  LinuxCudaAt architecture -> Text.intercalate "/" ["linux-cuda", Text.pack (architectureName architecture)]
  AppleMetalOnHost -> "apple-metal"
