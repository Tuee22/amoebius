let T = ../../../dhall/amoebius/ui/Types.dhall

in  { caseName = "composed_workflow_ui"
    , tenantMode = T.TenantMode.SingleTenant
    , modules =
      [ { moduleId = "app.workflow"
        , nodes =
          [ { nodeId = "start"
            , nodeKind = T.NodeKind.Port
            , valueType = T.ValueType.WorkflowStart
            , edges = [ "progress" ]
            , events = [ "start", "cancel" ]
            , branches = [ "start", "cancel" ]
            , maxItems = Some 3
            , public = True
            , portType = Some T.ValueType.WorkflowStart
            }
          , { nodeId = "progress"
            , nodeKind = T.NodeKind.Collection
            , valueType = T.ValueType.WorkflowProgress
            , edges = [] : List Text
            , events = [] : List Text
            , branches = [] : List Text
            , maxItems = Some 3
            , public = True
            , portType = None T.ValueType
            }
          ]
        }
      ]
    , externalLinks = [ { name = "docs" } ]
    }
