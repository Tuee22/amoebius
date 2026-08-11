{-# LANGUAGE NamedFieldPuns #-}

module Amoebius.Kernel.Chain
  ( PlanConfig
  , mkPlanConfig
  , planConfigId
  , planConfigProvisionedSpec
  , chain
  , runChainFromFrame
  ) where

import Amoebius.Capacity.Provision (ProvisionedSpec)
import Amoebius.Capacity.RenderSource
  ( K8sObjectIdentity (K8sObjectIdentity)
  , RenderActivation (..)
  )
import Amoebius.Kernel.Step
import Amoebius.Manifest (renderAll)
import Amoebius.Manifest.K8sObject (K8sObject (objectActivation, objectIdentity))
import Control.Monad (forM_)
import Data.IORef (IORef)
import Data.Text (Text)

data PlanConfig = PlanConfig
  { internalPlanConfigId :: Text
  , internalPlanConfigProvisionedSpec :: ProvisionedSpec
  , internalPlanCounter :: IORef Int
  }

mkPlanConfig :: Text -> ProvisionedSpec -> IORef Int -> PlanConfig
mkPlanConfig = PlanConfig

planConfigId :: PlanConfig -> Text
planConfigId = internalPlanConfigId

planConfigProvisionedSpec :: PlanConfig -> ProvisionedSpec
planConfigProvisionedSpec = internalPlanConfigProvisionedSpec

chain :: PlanConfig -> [Step PlanConfig]
chain cfg@PlanConfig {internalPlanCounter} = fmap objectStep (renderAll (planConfigProvisionedSpec cfg))
 where
  objectStep object =
    let K8sObjectIdentity identity = objectIdentity object
     in mkCountingStep
          internalPlanCounter
          identity
          (activationFrame (objectActivation object))
          ApplyObjects
          [object]
          (const (pure ()))

activationFrame :: RenderActivation -> Frame
activationFrame activation = case activation of
  Immediate -> ImmediateFrame
  BootstrapSchedulerStage -> BootstrapSchedulerFrame
  AfterBootstrapAddonCutover -> AfterBootstrapAddonCutoverFrame
  AfterManagedCapacityReady -> AfterManagedCapacityReadyFrame

-- Phase 14 declares and fake-exercises this seam. Phase 33 owns live invocation.
runChainFromFrame :: Frame -> cfg -> [Step cfg] -> IO ()
runChainFromFrame start cfg steps =
  forM_ (filter ((>= start) . stepFrame) steps) $ \step -> stepRun step cfg
