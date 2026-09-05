module UiPlanCompilerCases (
    projectionRows,
    authorizationRows,
    compilerPortRows,
    compilerBindingRows,
    compilerLinkRows,
    expectedArtifactRows,
    calculusRows,
) where

projectionRows :: [[String]]
projectionRows =
    [ ["home.text", "view:text", "-", "home", "-", "-", "-"]
    , ["form.submit", "event:submit", "action:mutate", "home", "MutationV1", "mutation", "data-write"]
    , ["workflow.start", "event:start", "action:start", "workflow", "WorkflowStartV1", "workflow", "workflow-start"]
    , ["docs.link", "navigation:docs", "-", "home", "ExternalLinkV1", "-", "-"]
    ]

authorizationRows :: [[String]]
authorizationRows =
    [ ["read-data", "ReadData", "read", "visible", "true"]
    , ["mutate-data", "MutateData", "write", "visible", "true"]
    , ["start-workflow", "StartWorkflow", "invoke", "hidden", "true"]
    , ["observe-workflow", "ObserveWorkflow", "read", "visible", "true"]
    , ["end-session", "EndSession", "invoke", "visible", "false"]
    ]

compilerPortRows :: [[String]]
compilerPortRows =
    [ ["mutate", "MutationV1", "MutationReceiptV1", "MutateData"]
    , ["start", "WorkflowStartV1", "WorkflowReceiptV1", "StartWorkflow"]
    ]

compilerBindingRows :: [[String]]
compilerBindingRows =
    [ ["mutate", "data-write", "SqlWrite", "owner", "required", "mutation"]
    , ["start", "workflow-start", "Workflow", "owner", "required", "workflow"]
    ]

compilerLinkRows :: [[String]]
compilerLinkRows = [["docs", "https://docs.example.invalid/amoebius"]]

expectedArtifactRows :: [(FilePath, String)]
expectedArtifactRows =
    [ ("client_plan.golden.json", "{\"abi\":\"ui-client-v1\",\"events\":[\"submit\",\"start\"],\"links\":[\"docs\"],\"routes\":[\"home\",\"workflow\"]}")
    , ("ui_server_plan.golden.json", "{\"abi\":\"ui-server-v1\",\"actions\":{\"mutate\":\"data-write\",\"start\":\"workflow-start\"},\"private\":true}")
    , ("public_contracts.golden.json", "{\"mutate\":{\"request\":\"MutationV1\",\"response\":\"MutationReceiptV1\"},\"start\":{\"request\":\"WorkflowStartV1\",\"response\":\"WorkflowReceiptV1\"}}")
    , ("content_manifest.golden.json", "{\"client-plan\":\"sha256:44f0053c3dfc34f2471e8b9de2a959a51becda1d64e0f1f8b607a229067d0559\",\"contracts\":\"sha256:8b4c51162bd700b9ccf1c05eedd4d11c3da84b108373cdc10b44a736f559760e\",\"server-plan\":\"sha256:5b8b65cc9d49fbfa3b724e3e5811406ee5e68ffc41411352a5fcf3b3c9d914c2\"}")
    ]

calculusRows :: [[String]]
calculusRows =
    [ ["calculus-kinds", "artifact,budget,lift,workflow,evidence"]
    , ["component-names", "canonical-plan-artifacts,finite-runtime-demand,projection-digest-and-refusal-checks,deterministic-plan-workflow,mutant-evidence"]
    , ["projection-counts", "4,6,14,2,6"]
    , ["resource-vector", "5,32,0,0"]
    ]
