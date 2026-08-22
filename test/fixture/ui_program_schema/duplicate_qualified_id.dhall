let T = ../../../dhall/amoebius/ui/Types.dhall
let node = { nodeId = "home", nodeKind = T.NodeKind.Route, valueType = T.ValueType.View
           , edges = [] : List Text, events = [] : List Text, branches = [] : List Text
           , maxItems = Some 1, public = True, portType = None T.ValueType }
in  { caseName = "duplicate_qualified_id", tenantMode = T.TenantMode.SingleTenant
    , continuity = T.UiOffline.Continuity.OnlineOnly
    , modules = [ { moduleId = "app.main", nodes = [ node, node ] } ]
    , externalLinks = [] : List T.ExternalLinkRequirement
    }
