{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Kernel.Descent
  ( Plan (..)
  , PlanEntry (..)
  , nextFrameAfter
  , foldLift
  ) where

import Amoebius.Capacity.RenderSource (K8sObjectIdentity (K8sObjectIdentity))
import Amoebius.Kernel.Step
import Amoebius.Manifest.K8sObject (K8sObject (objectIdentity))
import Control.DeepSeq (NFData)
import Data.Aeson (FromJSON, ToJSON)
import Data.List (find, sort)
import Data.Text (Text)
import GHC.Generics (Generic)

data PlanEntry = PlanEntry
  { planEntryLabel :: Text
  , planEntryFrame :: Frame
  , planEntryKind :: StepKind
  , planEntryObjectIdentities :: [Text]
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (FromJSON, NFData, ToJSON)

newtype Plan = Plan {planEntries :: [PlanEntry]}
  deriving stock (Eq, Generic, Show)
  deriving anyclass (FromJSON, NFData, ToJSON)

nextFrameAfter :: Frame -> [Step cfg] -> Maybe Frame
nextFrameAfter frame steps = find (> frame) (sort (fmap stepFrame steps))

foldLift :: ignored -> [Step cfg] -> Plan
foldLift _ = Plan . fmap toEntry
 where
  toEntry step =
    PlanEntry
      { planEntryLabel = stepLabel step
      , planEntryFrame = projectedFrame step
      , planEntryKind = stepKind step
      , planEntryObjectIdentities = fmap objectIdentityText (stepObjects step)
      }
  objectIdentityText object = case objectIdentity object of
    K8sObjectIdentity identity -> identity
  projectedFrame step =
#ifdef CHAIN_DESCENT_INFRAME_MUTANT
    if stepLabel step == "global/managed-capacity-admission"
      then AfterBootstrapAddonCutoverFrame
      else stepFrame step
#else
    stepFrame step
#endif
