let T = ../amoebius/ui/Types.dhall

in  { caseName = "infernix-ui"
    , tenantMode = T.TenantMode.SingleTenant
    , modules =
      [ { moduleId = "infernix.workflow"
        , nodes =
          [ { nodeId = "home"
            , nodeKind = T.NodeKind.Route
            , valueType = T.ValueType.View
            , edges = [ "start" ]
            , events = [ "start" ]
            , branches = [ "start" ]
            , maxItems = Some 1
            , public = True
            , portType = None T.ValueType
            }
          , { nodeId = "start"
            , nodeKind = T.NodeKind.Port
            , valueType = T.ValueType.WorkflowStart
            , edges = [ "progress" ]
            , events = [ "start" ]
            , branches = [ "start" ]
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
            , maxItems = Some 16
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
