{-# LANGUAGE OverloadedStrings #-}

module RenderGoldenOracle
  ( RenderMutantOracle (..)
  , expectedSemanticProjection
  , expectedCalculusProjection
  , expectedLocusEntries
  , expectedRenderMutants
  ) where

import Data.Text (Text)

data RenderMutantOracle = RenderMutantOracle
  { renderMutantName :: Text
  , renderMutantFlag :: Text
  , renderMutantLocus :: Text
  , renderMutantExpectedFailure :: Text
  }
  deriving stock (Eq, Show)

-- Independently frozen semantic meanings for every capability/shape pair.
-- The oracle imports neither production nor fixture modules.
expectedSemanticProjection :: [(Text, [Text])]
expectedSemanticProjection =
  [
    ("objectstore_singlenode", ["7", "global/bootstrap-addon-cutover,global/capacity-scheduler,global/managed-capacity-admission,global/namespace,objectstore/assets/config,objectstore/assets/member-0,objectstore/assets/service", "ConfigMapKind:2,DeploymentKind:1,NamespaceKind:1,ServiceKind:1,StatefulSetKind:1,ValidatingWebhookConfigurationKind:1", "AfterBootstrapAddonCutover:3,AfterManagedCapacityReady:1,BootstrapSchedulerStage:1,Immediate:2", "CreateBeforeDelete:1,ServerSideApply:6", "DeploymentWorkload:1,StatefulSetWorkload:1", "0", "0", "0"])
  , ("objectstore_distributed", ["11", "global/bootstrap-addon-cutover,global/capacity-scheduler,global/managed-capacity-admission,global/namespace,objectstore/assets/config,objectstore/assets/discovery,objectstore/assets/member-0,objectstore/assets/member-1,objectstore/assets/member-2,objectstore/assets/quorum-policy,objectstore/assets/service", "ConfigMapKind:2,DeploymentKind:1,NamespaceKind:1,NetworkPolicyKind:2,ServiceKind:1,StatefulSetKind:3,ValidatingWebhookConfigurationKind:1", "AfterBootstrapAddonCutover:5,AfterManagedCapacityReady:3,BootstrapSchedulerStage:1,Immediate:2", "CreateBeforeDelete:1,ServerSideApply:10", "DeploymentWorkload:1,StatefulSetWorkload:3", "2", "0", "0"])
  , ("secretstore_singlenode", ["7", "global/bootstrap-addon-cutover,global/capacity-scheduler,global/managed-capacity-admission,global/namespace,secretstore/secrets/config,secretstore/secrets/member-0,secretstore/secrets/service", "ConfigMapKind:2,DeploymentKind:1,NamespaceKind:1,ServiceKind:1,StatefulSetKind:1,ValidatingWebhookConfigurationKind:1", "AfterBootstrapAddonCutover:3,AfterManagedCapacityReady:1,BootstrapSchedulerStage:1,Immediate:2", "CreateBeforeDelete:1,ServerSideApply:6", "DeploymentWorkload:1,StatefulSetWorkload:1", "0", "0", "0"])
  , ("secretstore_distributed", ["11", "global/bootstrap-addon-cutover,global/capacity-scheduler,global/managed-capacity-admission,global/namespace,secretstore/secrets/config,secretstore/secrets/discovery,secretstore/secrets/member-0,secretstore/secrets/member-1,secretstore/secrets/member-2,secretstore/secrets/quorum-policy,secretstore/secrets/service", "ConfigMapKind:2,DeploymentKind:1,NamespaceKind:1,NetworkPolicyKind:2,ServiceKind:1,StatefulSetKind:3,ValidatingWebhookConfigurationKind:1", "AfterBootstrapAddonCutover:5,AfterManagedCapacityReady:3,BootstrapSchedulerStage:1,Immediate:2", "CreateBeforeDelete:1,ServerSideApply:10", "DeploymentWorkload:1,StatefulSetWorkload:3", "2", "0", "0"])
  , ("messagebus_singlenode", ["7", "global/bootstrap-addon-cutover,global/capacity-scheduler,global/managed-capacity-admission,global/namespace,messagebus/events/config,messagebus/events/member-0,messagebus/events/service", "ConfigMapKind:2,DeploymentKind:1,NamespaceKind:1,ServiceKind:1,StatefulSetKind:1,ValidatingWebhookConfigurationKind:1", "AfterBootstrapAddonCutover:3,AfterManagedCapacityReady:1,BootstrapSchedulerStage:1,Immediate:2", "CreateBeforeDelete:1,ServerSideApply:6", "DeploymentWorkload:1,StatefulSetWorkload:1", "0", "0", "0"])
  , ("messagebus_distributed", ["11", "global/bootstrap-addon-cutover,global/capacity-scheduler,global/managed-capacity-admission,global/namespace,messagebus/events/config,messagebus/events/discovery,messagebus/events/member-0,messagebus/events/member-1,messagebus/events/member-2,messagebus/events/quorum-policy,messagebus/events/service", "ConfigMapKind:2,DeploymentKind:1,NamespaceKind:1,NetworkPolicyKind:2,ServiceKind:1,StatefulSetKind:3,ValidatingWebhookConfigurationKind:1", "AfterBootstrapAddonCutover:5,AfterManagedCapacityReady:3,BootstrapSchedulerStage:1,Immediate:2", "CreateBeforeDelete:1,ServerSideApply:10", "DeploymentWorkload:1,StatefulSetWorkload:3", "2", "0", "0"])
  , ("sql_singlenode", ["8", "global/bootstrap-addon-cutover,global/capacity-scheduler,global/managed-capacity-admission,global/namespace,sql/database/config,sql/database/member-0,sql/database/schema-bootstrap,sql/database/service", "ConfigMapKind:2,DeploymentKind:1,JobKind:1,NamespaceKind:1,ServiceKind:1,StatefulSetKind:1,ValidatingWebhookConfigurationKind:1", "AfterBootstrapAddonCutover:4,AfterManagedCapacityReady:1,BootstrapSchedulerStage:1,Immediate:2", "CreateBeforeDelete:1,ReplaceOnChange:1,ServerSideApply:6", "DeploymentWorkload:1,JobWorkload:1,StatefulSetWorkload:1", "0", "0", "0"])
  , ("sql_distributed", ["12", "global/bootstrap-addon-cutover,global/capacity-scheduler,global/managed-capacity-admission,global/namespace,sql/database/config,sql/database/discovery,sql/database/member-0,sql/database/member-1,sql/database/member-2,sql/database/quorum-policy,sql/database/schema-bootstrap,sql/database/service", "ConfigMapKind:2,DeploymentKind:1,JobKind:1,NamespaceKind:1,NetworkPolicyKind:2,ServiceKind:1,StatefulSetKind:3,ValidatingWebhookConfigurationKind:1", "AfterBootstrapAddonCutover:6,AfterManagedCapacityReady:3,BootstrapSchedulerStage:1,Immediate:2", "CreateBeforeDelete:1,ReplaceOnChange:1,ServerSideApply:10", "DeploymentWorkload:1,JobWorkload:1,StatefulSetWorkload:3", "2", "0", "0"])
  , ("identity_singlenode", ["7", "global/bootstrap-addon-cutover,global/capacity-scheduler,global/managed-capacity-admission,global/namespace,identity/accounts/config,identity/accounts/member-0,identity/accounts/service", "ConfigMapKind:2,DeploymentKind:1,NamespaceKind:1,ServiceKind:1,StatefulSetKind:1,ValidatingWebhookConfigurationKind:1", "AfterBootstrapAddonCutover:3,AfterManagedCapacityReady:1,BootstrapSchedulerStage:1,Immediate:2", "CreateBeforeDelete:1,ServerSideApply:6", "DeploymentWorkload:1,StatefulSetWorkload:1", "0", "0", "0"])
  , ("identity_distributed", ["11", "global/bootstrap-addon-cutover,global/capacity-scheduler,global/managed-capacity-admission,global/namespace,identity/accounts/config,identity/accounts/discovery,identity/accounts/member-0,identity/accounts/member-1,identity/accounts/member-2,identity/accounts/quorum-policy,identity/accounts/service", "ConfigMapKind:2,DeploymentKind:1,NamespaceKind:1,NetworkPolicyKind:2,ServiceKind:1,StatefulSetKind:3,ValidatingWebhookConfigurationKind:1", "AfterBootstrapAddonCutover:5,AfterManagedCapacityReady:3,BootstrapSchedulerStage:1,Immediate:2", "CreateBeforeDelete:1,ServerSideApply:10", "DeploymentWorkload:1,StatefulSetWorkload:3", "2", "0", "0"])
  , ("observability_singlenode", ["7", "global/bootstrap-addon-cutover,global/capacity-scheduler,global/managed-capacity-admission,global/namespace,observability/telemetry/config,observability/telemetry/member-0,observability/telemetry/service", "ConfigMapKind:2,DeploymentKind:1,NamespaceKind:1,ServiceKind:1,StatefulSetKind:1,ValidatingWebhookConfigurationKind:1", "AfterBootstrapAddonCutover:3,AfterManagedCapacityReady:1,BootstrapSchedulerStage:1,Immediate:2", "CreateBeforeDelete:1,ServerSideApply:6", "DeploymentWorkload:1,StatefulSetWorkload:1", "0", "0", "0"])
  , ("observability_distributed", ["11", "global/bootstrap-addon-cutover,global/capacity-scheduler,global/managed-capacity-admission,global/namespace,observability/telemetry/config,observability/telemetry/discovery,observability/telemetry/member-0,observability/telemetry/member-1,observability/telemetry/member-2,observability/telemetry/quorum-policy,observability/telemetry/service", "ConfigMapKind:2,DeploymentKind:1,NamespaceKind:1,NetworkPolicyKind:2,ServiceKind:1,StatefulSetKind:3,ValidatingWebhookConfigurationKind:1", "AfterBootstrapAddonCutover:5,AfterManagedCapacityReady:3,BootstrapSchedulerStage:1,Immediate:2", "CreateBeforeDelete:1,ServerSideApply:10", "DeploymentWorkload:1,StatefulSetWorkload:3", "2", "0", "0"])
  , ("registry_singlenode", ["7", "global/bootstrap-addon-cutover,global/capacity-scheduler,global/managed-capacity-admission,global/namespace,registry/images/config,registry/images/member-0,registry/images/service", "ConfigMapKind:2,DeploymentKind:1,NamespaceKind:1,ServiceKind:1,StatefulSetKind:1,ValidatingWebhookConfigurationKind:1", "AfterBootstrapAddonCutover:3,AfterManagedCapacityReady:1,BootstrapSchedulerStage:1,Immediate:2", "CreateBeforeDelete:1,ServerSideApply:6", "DeploymentWorkload:1,StatefulSetWorkload:1", "0", "0", "0"])
  , ("registry_distributed", ["11", "global/bootstrap-addon-cutover,global/capacity-scheduler,global/managed-capacity-admission,global/namespace,registry/images/config,registry/images/discovery,registry/images/member-0,registry/images/member-1,registry/images/member-2,registry/images/quorum-policy,registry/images/service", "ConfigMapKind:2,DeploymentKind:1,NamespaceKind:1,NetworkPolicyKind:2,ServiceKind:1,StatefulSetKind:3,ValidatingWebhookConfigurationKind:1", "AfterBootstrapAddonCutover:5,AfterManagedCapacityReady:3,BootstrapSchedulerStage:1,Immediate:2", "CreateBeforeDelete:1,ServerSideApply:10", "DeploymentWorkload:1,StatefulSetWorkload:3", "2", "0", "0"])
  , ("edge_singlenode", ["7", "edge/public-edge/config,edge/public-edge/member-0,edge/public-edge/service,global/bootstrap-addon-cutover,global/capacity-scheduler,global/managed-capacity-admission,global/namespace", "ConfigMapKind:2,DeploymentKind:2,NamespaceKind:1,ServiceKind:1,ValidatingWebhookConfigurationKind:1", "AfterBootstrapAddonCutover:3,AfterManagedCapacityReady:1,BootstrapSchedulerStage:1,Immediate:2", "CreateBeforeDelete:1,ServerSideApply:6", "DeploymentWorkload:2", "0", "1", "0"])
  , ("edge_distributed", ["11", "edge/public-edge/config,edge/public-edge/discovery,edge/public-edge/member-0,edge/public-edge/member-1,edge/public-edge/member-2,edge/public-edge/quorum-policy,edge/public-edge/service,global/bootstrap-addon-cutover,global/capacity-scheduler,global/managed-capacity-admission,global/namespace", "ConfigMapKind:2,DeploymentKind:4,NamespaceKind:1,NetworkPolicyKind:2,ServiceKind:1,ValidatingWebhookConfigurationKind:1", "AfterBootstrapAddonCutover:5,AfterManagedCapacityReady:3,BootstrapSchedulerStage:1,Immediate:2", "CreateBeforeDelete:1,ServerSideApply:10", "DeploymentWorkload:4", "2", "1", "0"])
  , ("inferenceengine_singlenode", ["7", "global/bootstrap-addon-cutover,global/capacity-scheduler,global/managed-capacity-admission,global/namespace,inferenceengine/inference/config,inferenceengine/inference/member-0,inferenceengine/inference/service", "ConfigMapKind:2,DaemonSetKind:1,DeploymentKind:1,NamespaceKind:1,ServiceKind:1,ValidatingWebhookConfigurationKind:1", "AfterBootstrapAddonCutover:3,AfterManagedCapacityReady:1,BootstrapSchedulerStage:1,Immediate:2", "CreateBeforeDelete:1,ServerSideApply:6", "DaemonSetWorkload:1,DeploymentWorkload:1", "0", "0", "1"])
  , ("inferenceengine_distributed", ["11", "global/bootstrap-addon-cutover,global/capacity-scheduler,global/managed-capacity-admission,global/namespace,inferenceengine/inference/config,inferenceengine/inference/discovery,inferenceengine/inference/member-0,inferenceengine/inference/member-1,inferenceengine/inference/member-2,inferenceengine/inference/quorum-policy,inferenceengine/inference/service", "ConfigMapKind:2,DaemonSetKind:3,DeploymentKind:1,NamespaceKind:1,NetworkPolicyKind:2,ServiceKind:1,ValidatingWebhookConfigurationKind:1", "AfterBootstrapAddonCutover:5,AfterManagedCapacityReady:3,BootstrapSchedulerStage:1,Immediate:2", "CreateBeforeDelete:1,ServerSideApply:10", "DaemonSetWorkload:3,DeploymentWorkload:1", "2", "0", "3"])
  ]

expectedCalculusProjection :: [(Text, Text)]
expectedCalculusProjection =
  [ ("calculus-kinds", "artifact,budget,lift,workflow,evidence")
  , ("component-names", "semantic-deployments,rendered-objects,safety-predicates,renderer-property,mutant-evidence")
  , ("projection-counts", "18,164,3,1,12")
  , ("resource-vector", "5,198,0,0")
  ]

expectedLocusEntries :: [Text]
expectedLocusEntries = [ "objectstore_singlenode"
  , "objectstore_distributed"
  , "secretstore_singlenode"
  , "secretstore_distributed"
  , "messagebus_singlenode"
  , "messagebus_distributed"
  , "sql_singlenode"
  , "sql_distributed"
  , "identity_singlenode"
  , "identity_distributed"
  , "observability_singlenode"
  , "observability_distributed"
  , "registry_singlenode"
  , "registry_distributed"
  , "edge_singlenode"
  , "edge_distributed"
  , "inferenceengine_singlenode"
  , "inferenceengine_distributed"
  , "unsafe_workload"
  , "backdoor_ingress"
  , "underived_network_policy"
  , "mutant_resource_projection"
  , "mutant_ephemeral_rootfs"
  , "mutant_unbounded_scratch"
  , "mutant_memory_volume_lifecycle"
  , "mutant_image_platform"
  , "mutant_durable_size"
  , "mutant_accelerator_projection"
  , "mutant_controller_projection"
  , "mutant_monitoring_projection"
  , "mutant_unhardened_pod"
  , "mutant_wild_ingress"
  , "mutant_undeclared_allow_edge"
  ]

expectedRenderMutants :: [RenderMutantOracle]
expectedRenderMutants =
  [
    RenderMutantOracle "mutant_resource_projection" "render-resource-projection-mutant" "podFor" "resource-projection"
  , RenderMutantOracle "mutant_ephemeral_rootfs" "render-ephemeral-rootfs-mutant" "podFor" "security-context"
  , RenderMutantOracle "mutant_unbounded_scratch" "render-unbounded-scratch-mutant" "podFor" "bounded-volumes"
  , RenderMutantOracle "mutant_memory_volume_lifecycle" "render-memory-volume-lifecycle-mutant" "podFor" "resource-projection"
  , RenderMutantOracle "mutant_image_platform" "render-image-platform-mutant" "podFor" "image-digest"
  , RenderMutantOracle "mutant_durable_size" "render-durable-size-mutant" "metadataFor" "source-annotation"
  , RenderMutantOracle "mutant_accelerator_projection" "render-accelerator-projection-mutant" "podFor" "accelerator-claim"
  , RenderMutantOracle "mutant_controller_projection" "render-controller-projection-mutant" "specFor" "controller-kind"
  , RenderMutantOracle "mutant_monitoring_projection" "render-monitoring-projection-mutant" "podFor" "resource-projection"
  , RenderMutantOracle "mutant_unhardened_pod" "render-unhardened-pod-mutant" "podFor" "security-context"
  , RenderMutantOracle "mutant_wild_ingress" "render-wild-ingress-mutant" "serviceExposure" "service-exposure"
  , RenderMutantOracle "mutant_undeclared_allow_edge" "render-undeclared-allow-edge-mutant" "dependencyEdge" "network-policy-edge-set"
  ]
