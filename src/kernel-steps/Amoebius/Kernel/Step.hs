{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | The closed step algebra. A step is data: a label, the frame it belongs to, the kind of
-- work, and the objects it carries. It holds no function, so nothing runs until the
-- interpreter, the only executor, reads it.
module Amoebius.Kernel.Step
  ( Frame (..)
  , StepKind (..)
  , Step
  , StepRefusal (..)
  , stepRefusalTag
  , mkStep
  , stepLabel
  , stepFrame
  , stepKind
  , stepObjects
  , chain
  , stepsFrom
  , nextFrameAfter
  , validateChain
  , stepPayload
  , manifestBytes
  , Plan (..)
  , PlanEntry (..)
  , planOf
  , renderPlan
  ) where

import Amoebius.Capacity.RenderSource
  ( K8sObjectIdentity (K8sObjectIdentity)
  , RenderActivation (..)
  )
import Amoebius.Manifest.K8sObject (K8sObject (objectActivation, objectIdentity), encodeK8sObjects)
import Control.DeepSeq (NFData)
import Data.Aeson (FromJSON, ToJSON)
import Data.Aeson.Encode.Pretty (Config (confCompare, confIndent), Indent (Spaces), defConfig, encodePretty', keyOrder)
import Data.ByteString (ByteString)
import Data.ByteString.Lazy qualified as Lazy
import Data.List (find, nub, sort, sortOn)
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)

-- | The stage of the readiness chain a step belongs to, in the order the chain runs them.
data Frame
  = ImmediateFrame
  | BootstrapSchedulerFrame
  | AfterBootstrapAddonCutoverFrame
  | AfterManagedCapacityReadyFrame
  | BoundaryFrame
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Show)
  deriving anyclass (FromJSON, NFData, ToJSON)

data StepKind
  = ApplyObjects
  | DockerBuild
  | DockerPush
  | PulumiUp
  | HostProcess
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Show)
  deriving anyclass (FromJSON, NFData, ToJSON)

-- | One unit of work. The constructor is private; 'mkStep' is the only way to build one.
data Step = Step
  { internalStepLabel :: Text
  , internalStepFrame :: Frame
  , internalStepKind :: StepKind
  , internalStepObjects :: [K8sObject]
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data StepRefusal
  = EmptyLabel
  | ApplyWithoutObjects
  | ObjectsOnNonApply
  | NonMonotoneFrames Text
  | DuplicateStepLabel Text
  deriving stock (Eq, Show)

-- | The stable tag of a refusal: the name of its constructor.
stepRefusalTag :: StepRefusal -> Text
stepRefusalTag refusal = case refusal of
  EmptyLabel -> "EmptyLabel"
  ApplyWithoutObjects -> "ApplyWithoutObjects"
  ObjectsOnNonApply -> "ObjectsOnNonApply"
  NonMonotoneFrames _ -> "NonMonotoneFrames"
  DuplicateStepLabel _ -> "DuplicateStepLabel"

-- | A step has a label, an apply step carries objects, and no other kind does.
mkStep :: Text -> Frame -> StepKind -> [K8sObject] -> Either StepRefusal Step
mkStep label frame kind objects
  | Text.null label = Left EmptyLabel
  | kind == ApplyObjects && null objects = Left ApplyWithoutObjects
  | kind /= ApplyObjects && not (null objects) = Left ObjectsOnNonApply
  | otherwise = Right (Step label frame kind objects)

stepLabel :: Step -> Text
stepLabel = internalStepLabel

stepFrame :: Step -> Frame
stepFrame = internalStepFrame

stepKind :: Step -> StepKind
stepKind = internalStepKind

stepObjects :: Step -> [K8sObject]
stepObjects = internalStepObjects

-- | One apply step per object, in the order the readiness chain applies them: by frame,
-- then by identity.
chain :: [K8sObject] -> Either StepRefusal [Step]
chain objects = traverse objectStep (sortOn sortKey objects)
 where
  sortKey object = (activationFrame (objectActivation object), identityText object)
  objectStep object = mkStep (identityText object) (activationFrame (objectActivation object)) ApplyObjects [object]

identityText :: K8sObject -> Text
identityText object = case objectIdentity object of
  K8sObjectIdentity identity -> identity

activationFrame :: RenderActivation -> Frame
activationFrame activation = case activation of
  Immediate -> ImmediateFrame
  BootstrapSchedulerStage -> BootstrapSchedulerFrame
  AfterBootstrapAddonCutover -> AfterBootstrapAddonCutoverFrame
  AfterManagedCapacityReady -> AfterManagedCapacityReadyFrame

-- | The steps at or after a frame, in order.
stepsFrom :: Frame -> [Step] -> [Step]
stepsFrom start = filter ((>= start) . stepFrame)

nextFrameAfter :: Frame -> [Step] -> Maybe Frame
nextFrameAfter frame steps = find (> frame) (sort (map stepFrame steps))

-- | A chain never steps back to an earlier frame and never repeats a label.
validateChain :: [Step] -> Either StepRefusal ()
validateChain steps = do
  case [later | (earlier, later) <- zip steps (drop 1 steps), stepFrame later < stepFrame earlier] of
    later : _ -> Left (NonMonotoneFrames (stepLabel later))
    [] -> Right ()
  case [label | label <- nub labels, length (filter (== label) labels) > 1] of
    label : _ -> Left (DuplicateStepLabel label)
    [] -> Right ()
 where
  labels = map stepLabel steps

-- | The bytes a step hands the executor: the canonical encoding of its objects.
stepPayload :: Step -> ByteString
stepPayload = Lazy.toStrict . encodeK8sObjects . stepObjects

-- | The manifest: the payloads of the apply steps, in order.
manifestBytes :: [Step] -> ByteString
manifestBytes steps = mconcat [stepPayload step | step <- steps, stepKind step == ApplyObjects]

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

-- | The steps as plain entries, each naming the identities it carries.
planOf :: [Step] -> Plan
planOf steps = Plan (map entry steps)
 where
  entry step = PlanEntry (stepLabel step) (stepFrame step) (stepKind step) (map identityText (stepObjects step))

renderPlan :: Plan -> Lazy.ByteString
renderPlan plan = encodePretty' canonicalConfig plan <> "\n"

canonicalConfig :: Config
canonicalConfig = defConfig {confIndent = Spaces 2, confCompare = keyOrder []}
