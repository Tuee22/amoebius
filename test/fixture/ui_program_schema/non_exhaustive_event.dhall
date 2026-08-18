let T = ../../../dhall/amoebius/ui/Types.dhall
in  { caseName = "non_exhaustive_event", tenantMode = T.TenantMode.SingleTenant
    , modules = [ { moduleId = "app.main", nodes =
      [ { nodeId = "route", nodeKind = T.NodeKind.Route, valueType = T.ValueType.View
        , edges = [] : List Text, events = [ "Ready", "Cancelled" ], branches = [ "Ready" ]
        , maxItems = Some 1, public = True, portType = None T.ValueType } ] } ]
    , externalLinks = [] : List T.ExternalLinkRequirement
    }
