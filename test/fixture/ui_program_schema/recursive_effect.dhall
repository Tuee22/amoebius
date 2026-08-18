let T = ../../../dhall/amoebius/ui/Types.dhall
let Node = T.UiNode
in  { caseName = "recursive_effect"
    , tenantMode = T.TenantMode.SingleTenant
    , modules =
      [ { moduleId = "app.effect"
        , nodes =
          [ { nodeId = "loop", nodeKind = T.NodeKind.Event, valueType = T.ValueType.Boolean
            , edges = [ "loop" ], events = [] : List Text, branches = [] : List Text
            , maxItems = Some 1, public = True, portType = None T.ValueType } : Node
          ]
        }
      ]
    , externalLinks = [] : List T.ExternalLinkRequirement
    }
