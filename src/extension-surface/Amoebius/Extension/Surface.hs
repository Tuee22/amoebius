{-# LANGUAGE OverloadedStrings #-}

-- | The bounded pure construction surface contributed modules may import.
-- Requests configure data; the trusted binder supplies attestation, targets
-- and witness-rendered objects before an extension can contribute its steps.
module Amoebius.Extension.Surface
  ( ProductSpec, ProductLinkSet, SurfaceRefusal (..), surfaceRefusalTag, mkContribution
  , ConfigSchema (..), DeclaredCapability (..), CapabilityArm (..), NonEmpty (..)
  , MonitorFactory, sloMonitoring, tensorBoardMonitoring, buildMonitoring
  , ExtensionInput, prepareExtensionInput, extensionSteps, extensionRuntime
  , requiredLane, checkContributedChain
  ) where

import Amoebius.Extension.Calculi (DeclarationBuilder, declarationBuilder)
import Amoebius.Extension.Capability (DeclaredCapability (..))
import Amoebius.Extension.Config
import Amoebius.Extension.Graph (LinkSet)
import Amoebius.Extension.Monitoring qualified as Monitoring
import Amoebius.Extension.Spec
import Amoebius.Kernel.Step (Step, StepRefusal, chain, validateChain)
import Amoebius.Manifest.K8sObject (K8sObject (objectMetadata), ObjectMetadata (metadataLabels))
import Amoebius.Scope.Attested (RequestScope, scopeLabel)
import Amoebius.Vocabulary
  ( Architecture, CapabilityArm (..), EngineRuntime (..), ExtensionId, Lane (..), mkExtensionId )
import Data.List.NonEmpty (NonEmpty (..))
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text

-- Initial contributions register no app-specific UI handler. The UI owner
-- supplies the checked handler/port algebra; there is no arbitrary IO slot.
data TrustedUiHandler

newtype MonitorFactory = MonitorFactory
  (ExtensionParameters -> Either SurfaceRefusal Monitoring.MonitoringBuilder)

type ProductSpec seal = ExtensionSpec ExtensionId ConfigSchema DeclaredCapability
  (ExtensionInput -> Architecture -> Lane) ExtensionInput Step TrustedUiHandler
  MonitorFactory DeclarationBuilder seal

type ProductLinkSet seal = LinkSet ConfigSchema (ExtensionInput -> Architecture -> Lane)
  ExtensionInput Step TrustedUiHandler MonitorFactory DeclarationBuilder seal

data SurfaceRefusal
  = InvalidExtensionId
  | ExtensionSpecRefused ExtensionSpecRefusal
  | ExtensionConfigurationMismatch
  | UnattestedScope
  | ExtensionStepRefused StepRefusal
  | ExtensionChainMismatch
  | ExtensionMonitoringRefused Monitoring.MonitoringRefusal
  deriving (Eq, Show)

surfaceRefusalTag :: SurfaceRefusal -> Text
surfaceRefusalTag refusal = case refusal of
  InvalidExtensionId -> "InvalidExtensionId"
  ExtensionSpecRefused problem -> Text.pack (extensionSpecRefusalName problem)
  ExtensionConfigurationMismatch -> "ExtensionConfigurationMismatch"
  UnattestedScope -> "UnattestedScope"
  ExtensionStepRefused _ -> "ExtensionStepRefused"
  ExtensionChainMismatch -> "ExtensionChainMismatch"
  ExtensionMonitoringRefused problem -> Monitoring.monitoringRefusalTag problem

mkContribution
  :: Text -> ConfigSchema -> [DeclaredCapability] -> [DeclaredCapability]
  -> NonEmpty MonitorFactory -> seal -> Either SurfaceRefusal (ProductSpec seal)
mkContribution name schema provides requires monitoring seal = do
  identifier <- maybe (Left InvalidExtensionId) Right (mkExtensionId name)
  either (Left . ExtensionSpecRefused) Right $ mkExtensionSpec identifier schema provides requires
    (requiredLane schema) extensionSteps [] monitoring (declarationBuilder identifier schema) seal

sloMonitoring :: Text -> Either SurfaceRefusal MonitorFactory
sloMonitoring name = do
  metric <- monitorResult (Monitoring.metricName name)
  builder <- monitorResult (Monitoring.defaultSloBuilder metric)
  Right (MonitorFactory (const (Right builder)))

tensorBoardMonitoring :: MonitorFactory
tensorBoardMonitoring = MonitorFactory $ \parameters -> case configurationReference parameters of
  Nothing -> Left ExtensionConfigurationMismatch
  Just reference -> monitorResult (Monitoring.tensorBoardBuilder reference)

buildMonitoring :: MonitorFactory -> ExtensionParameters -> Either SurfaceRefusal Monitoring.MonitoringBuilder
buildMonitoring (MonitorFactory build) = build

monitorResult :: Either Monitoring.MonitoringRefusal value -> Either SurfaceRefusal value
monitorResult = either (Left . ExtensionMonitoringRefused) Right

-- The constructor is private. Both the source inventory's scope label and
-- its step chain are checked before these objects reach contributed code.
data ExtensionInput = ExtensionInput !ExtensionParameters !EngineRuntime ![Step]

prepareExtensionInput
  :: RequestScope scope -> ProductSpec seal -> ExtensionParameters -> EngineRuntime
  -> [K8sObject] -> Either SurfaceRefusal ExtensionInput
prepareExtensionInput scope specification parameters runtime objects
  | scope `seq` parameterSchema parameters /= extConfig specification = Left ExtensionConfigurationMismatch
  | any ((/= Just (scopeLabel scope)) . Map.lookup "amoebius.io/scope" . metadataLabels . objectMetadata) objects = Left UnattestedScope
  | otherwise = do
      steps <- either (Left . ExtensionStepRefused) Right (chain objects)
      Right (ExtensionInput parameters runtime steps)

extensionSteps :: ExtensionInput -> [Step]
extensionSteps (ExtensionInput _ _ steps) = steps

extensionRuntime :: ExtensionInput -> EngineRuntime
extensionRuntime (ExtensionInput _ runtime _) = runtime

requiredLane :: ConfigSchema -> ExtensionInput -> Architecture -> Lane
requiredLane schema input architecture = case schema of
  InferenceConfig -> engineLane
  TrainingConfig -> engineLane
  BuildCacheConfig -> LinuxCpuAt architecture
  CoordinationConfig -> LinuxCpuAt architecture
 where
  engineLane = case extensionRuntime input of
    CpuRuntime -> LinuxCpuAt architecture
    Cuda -> LinuxCudaAt architecture
    AppleMetal -> AppleMetalOnHost

checkContributedChain :: ExtensionInput -> [Step] -> Either SurfaceRefusal [Step]
checkContributedChain input contributed = do
  either (Left . ExtensionStepRefused) Right (validateChain contributed)
  if contributed == extensionSteps input then Right contributed else Left ExtensionChainMismatch
