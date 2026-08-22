let T = ../../../dhall/amoebius/ui/Types.dhall

in  { caseName = "minimal_multi_tenant"
    , tenantMode = T.TenantMode.MultiTenant
    , continuity = T.UiOffline.Continuity.OnlineOnly
    , modules =
      [ { moduleId = "app.main"
        , nodes =
          [ { nodeId = "tenant"
            , nodeKind = T.NodeKind.Route
            , valueType = T.ValueType.TenantChoice
            , edges = [ "home" ]
            , events = [ "choose-tenant" ]
            , branches = [ "choose-tenant" ]
            , maxItems = Some 2
            , public = True
            , portType = None T.ValueType
            }
          , { nodeId = "home"
            , nodeKind = T.NodeKind.State
            , valueType = T.ValueType.View
            , edges = [] : List Text
            , events = [] : List Text
            , branches = [] : List Text
            , maxItems = Some 2
            , public = True
            , portType = None T.ValueType
            }
          ]
        }
      ]
    , externalLinks = [ { name = "docs" } ]
    }
