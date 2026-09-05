module EffectBindingCases (
    portsRows,
    handlerRows,
    capabilityRows,
    expectedBindingRows,
    externalLinkRows,
    expectedExternalLinkRows,
    bindErrorRows,
    calculusRows,
) where

portsRows, handlerRows, capabilityRows, expectedBindingRows, externalLinkRows, expectedExternalLinkRows, bindErrorRows, calculusRows :: [[String]]
portsRows =
    [ ["read", "ReadQuery", "ReadResult", "owner", "ReadData"]
    , ["mutate", "Mutation", "MutationReceipt", "owner", "MutateData"]
    , ["start", "WorkflowStart", "WorkflowReceipt", "owner", "StartWorkflow"]
    , ["observe", "WorkflowCursor", "WorkflowEvent", "owner", "ObserveWorkflow"]
    , ["subscribe", "Subscription", "StreamEvent", "owner", "Subscribe"]
    , ["upload", "BoundedBlob", "ReadyBlob", "owner", "UploadBounded"]
    , ["artifact", "ReadyArtifactHandle", "ArtifactResult", "owner", "UseReadyArtifact"]
    ]
handlerRows =
    [ ["data-read", "ReadQuery", "ReadResult", "owner", "none", "read"]
    , ["data-write", "Mutation", "MutationReceipt", "owner", "required", "mutation"]
    , ["workflow-start", "WorkflowStart", "WorkflowReceipt", "owner", "required", "workflow"]
    , ["workflow-observe", "WorkflowCursor", "WorkflowEvent", "owner", "none", "workflow"]
    , ["stream-subscribe", "Subscription", "StreamEvent", "owner", "none", "stream"]
    , ["blob-upload", "BoundedBlob", "ReadyBlob", "owner", "required", "blob"]
    , ["artifact-use", "ReadyArtifactHandle", "ArtifactResult", "owner", "required", "artifact"]
    ]
capabilityRows =
    [ ["data-read", "SqlRead"]
    , ["data-write", "SqlWrite"]
    , ["workflow-start", "Workflow"]
    , ["workflow-observe", "Workflow"]
    , ["stream-subscribe", "PulsarSubscription"]
    , ["blob-upload", "ContentStore"]
    , ["artifact-use", "InferenceEngine"]
    ]
expectedBindingRows =
    [ ["read", "data-read", "SqlRead", "owner", "none", "read"]
    , ["mutate", "data-write", "SqlWrite", "owner", "required", "mutation"]
    , ["start", "workflow-start", "Workflow", "owner", "required", "workflow"]
    , ["observe", "workflow-observe", "Workflow", "owner", "none", "workflow"]
    , ["subscribe", "stream-subscribe", "PulsarSubscription", "owner", "none", "stream"]
    , ["upload", "blob-upload", "ContentStore", "owner", "required", "blob"]
    , ["artifact", "artifact-use", "InferenceEngine", "owner", "required", "artifact"]
    ]
externalLinkRows = [["docs", "https://docs.example.invalid/amoebius"], ["support", "https://support.example.invalid/help"]]
expectedExternalLinkRows =
    [ ["docs", "https://docs.example.invalid/amoebius", "_blank", "noopener noreferrer"]
    , ["support", "https://support.example.invalid/help", "_blank", "noopener noreferrer"]
    ]
bindErrorRows =
    [ ["missing-handler", "MissingHandler"]
    , ["duplicate-handler", "DuplicateHandler"]
    , ["codec-mismatch", "ContractMismatch"]
    , ["missing-capability", "MissingCapability"]
    , ["scope-mismatch", "ScopeMismatch"]
    , ["unsafe-retry", "IdempotencyRequired"]
    , ["raw-topic", "ProviderCoordinateForbidden"]
    , ["link-as-url", "ExternalLinkNotAnEffect"]
    ]
calculusRows =
    [ ["calculus-kinds", "artifact,budget,lift,workflow,evidence"]
    , ["component-names", "port-bindings,external-link-bindings,binding-refusals,generated-coverage-workflow,mutant-evidence"]
    , ["projection-counts", "7,2,19,13,7"]
    , ["resource-vector", "5,48,0,0"]
    ]
