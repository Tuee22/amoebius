{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

module Amoebius.Kernel.Step
  ( Frame (..)
  , StepKind (..)
  , Step
  , mkCountingStep
  , stepLabel
  , stepFrame
  , stepKind
  , stepObjects
  , stepRun
  ) where

import Amoebius.Manifest.K8sObject (K8sObject)
import Control.DeepSeq (NFData (rnf))
import Data.Aeson (FromJSON, ToJSON)
import Data.IORef (IORef, modifyIORef')
import Data.Text (Text)
import GHC.Generics (Generic)

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
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Show)
  deriving anyclass (FromJSON, NFData, ToJSON)

data Step cfg = Step
  { internalStepLabel :: Text
  , internalStepFrame :: Frame
  , internalStepKind :: StepKind
  , internalStepObjects :: [K8sObject]
  , internalStepRun :: cfg -> IO ()
  }

instance NFData (Step cfg) where
  rnf step =
    rnf (internalStepLabel step)
      `seq` rnf (internalStepFrame step)
      `seq` rnf (internalStepKind step)
      `seq` rnf (internalStepObjects step)

mkCountingStep
  :: IORef Int
  -> Text
  -> Frame
  -> StepKind
  -> [K8sObject]
  -> (cfg -> IO ())
  -> Step cfg
mkCountingStep counter label frame kind objects action =
  Step
    { internalStepLabel = label
    , internalStepFrame = frame
    , internalStepKind = kind
    , internalStepObjects = objects
    , internalStepRun = \cfg -> modifyIORef' counter (+ 1) >> action cfg
    }

stepLabel :: Step cfg -> Text
stepLabel = internalStepLabel

stepFrame :: Step cfg -> Frame
stepFrame = internalStepFrame

stepKind :: Step cfg -> StepKind
stepKind = internalStepKind

stepObjects :: Step cfg -> [K8sObject]
stepObjects = internalStepObjects

stepRun :: Step cfg -> cfg -> IO ()
stepRun = internalStepRun
