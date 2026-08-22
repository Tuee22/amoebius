let T = ../../../dhall/amoebius/ui/Types.dhall
in  { caseName = "unbounded_collection", tenantMode = T.TenantMode.SingleTenant
    , continuity = T.UiOffline.Continuity.OnlineOnly
    , modules = [ { moduleId = "app.main", nodes =
      [ { nodeId = "items", nodeKind = T.NodeKind.Collection, valueType = T.ValueType.Text
        , edges = [] : List Text, events = [] : List Text, branches = [] : List Text
        , maxItems = None Natural, public = True, portType = None T.ValueType } ] } ]
    , externalLinks = [] : List T.ExternalLinkRequirement
    }
