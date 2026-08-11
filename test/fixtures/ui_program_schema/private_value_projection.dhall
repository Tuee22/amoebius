let T = ../../../dhall/amoebius/ui/Types.dhall
in  { caseName = "private_value_projection", tenantMode = T.TenantMode.SingleTenant
    , modules = [ { moduleId = "app.main", nodes =
      [ { nodeId = "secret", nodeKind = T.NodeKind.State, valueType = T.ValueType.ServerHandle
        , edges = [] : List Text, events = [] : List Text, branches = [] : List Text
        , maxItems = Some 1, public = True, portType = None T.ValueType } ] } ]
    , externalLinks = [] : List T.ExternalLinkRequirement
    }
