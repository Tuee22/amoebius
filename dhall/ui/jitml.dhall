let T = ../amoebius/ui/Types.dhall

in  { caseName = "jitml-ui"
    , tenantMode = T.TenantMode.MultiTenant
    , continuity =
        T.UiOffline.Continuity.Offline
          { projections = [ { projectionId = "workflow-progress" } ]
          , queuedPorts =
            [ { operation = T.UiOffline.Operation.JitmlTrainingStart
              , contract =
                { maxCount = 4
                , maxBytes = 131072
                , maxAgeSeconds = 43200
                , localValidation = "advisory"
                , idempotency = "command-id"
                , conflict = "reject"
                , ordering = "preserve"
                , dependency = "dataset-blob"
                , authoritativeValidation = "current-authority"
                }
              }
            ]
          , localBlobs = [ { blobClassId = "dataset" } ]
          , offlineView = "jitml.workflow.home"
          }
    , modules =
      [ { moduleId = "jitml.workflow"
        , nodes =
          [ { nodeId = "home"
            , nodeKind = T.NodeKind.Route
            , valueType = T.ValueType.View
            , edges = [ "train" ]
            , events = [ "train" ]
            , branches = [ "train" ]
            , maxItems = Some 1
            , public = True
            , portType = None T.ValueType
            }
          , { nodeId = "train"
            , nodeKind = T.NodeKind.Port
            , valueType = T.ValueType.WorkflowStart
            , edges = [ "progress" ]
            , events = [ "train" ]
            , branches = [ "train" ]
            , maxItems = Some 1
            , public = True
            , portType = Some T.ValueType.WorkflowStart
            }
          , { nodeId = "progress"
            , nodeKind = T.NodeKind.Collection
            , valueType = T.ValueType.WorkflowProgress
            , edges = [ "ready" ]
            , events = [] : List Text
            , branches = [] : List Text
            , maxItems = Some 200
            , public = True
            , portType = None T.ValueType
            }
          , { nodeId = "ready"
            , nodeKind = T.NodeKind.State
            , valueType = T.ValueType.ServerHandle
            , edges = [ "invoke" ]
            , events = [ "invoke" ]
            , branches = [ "invoke" ]
            , maxItems = Some 1
            , public = True
            , portType = None T.ValueType
            }
          , { nodeId = "invoke"
            , nodeKind = T.NodeKind.Port
            , valueType = T.ValueType.ServerHandle
            , edges = [ "result" ]
            , events = [ "invoke" ]
            , branches = [ "invoke" ]
            , maxItems = Some 1
            , public = True
            , portType = Some T.ValueType.ServerHandle
            }
          , { nodeId = "result"
            , nodeKind = T.NodeKind.State
            , valueType = T.ValueType.Text
            , edges = [] : List Text
            , events = [] : List Text
            , branches = [] : List Text
            , maxItems = Some 1
            , public = True
            , portType = None T.ValueType
            }
          ]
        }
      ]
    , externalLinks = [] : List T.ExternalLinkRequirement
    }
