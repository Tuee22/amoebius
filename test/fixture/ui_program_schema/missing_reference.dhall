let T = ../../../dhall/amoebius/ui/Types.dhall
in  { caseName = "missing_reference", tenantMode = T.TenantMode.SingleTenant
    , continuity = T.UiOffline.Continuity.OnlineOnly
    , modules = [ { moduleId = "app.main", nodes =
      [ { nodeId = "home", nodeKind = T.NodeKind.Route, valueType = T.ValueType.View
        , edges = [ "missing" ], events = [] : List Text, branches = [] : List Text
        , maxItems = Some 1, public = True, portType = None T.ValueType } ] } ]
    , externalLinks = [] : List T.ExternalLinkRequirement
    }
