let T = ../../../dhall/amoebius/ui/Types.dhall
in  { caseName = "port_type_mismatch", tenantMode = T.TenantMode.SingleTenant
    , continuity = T.UiOffline.Continuity.OnlineOnly
    , modules = [ { moduleId = "app.main", nodes =
      [ { nodeId = "port", nodeKind = T.NodeKind.Port, valueType = T.ValueType.Text
        , edges = [] : List Text, events = [] : List Text, branches = [] : List Text
        , maxItems = Some 1, public = True, portType = Some T.ValueType.Natural } ] } ]
    , externalLinks = [] : List T.ExternalLinkRequirement
    }
