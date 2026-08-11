let T = ../../../dhall/amoebius/ui/Types.dhall

in  { caseName = "minimal_single_tenant"
    , tenantMode = T.TenantMode.SingleTenant
    , modules =
      [ { moduleId = "app.main"
        , nodes =
          [ { nodeId = "home"
            , nodeKind = T.NodeKind.Route
            , valueType = T.ValueType.View
            , edges = [ "submit" ]
            , events = [ "submit" ]
            , branches = [ "submit" ]
            , maxItems = Some 1
            , public = True
            , portType = None T.ValueType
            }
          , { nodeId = "submit"
            , nodeKind = T.NodeKind.Event
            , valueType = T.ValueType.Boolean
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
    , externalLinks = [ { name = "docs" } ]
    }
