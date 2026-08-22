let T = ../../../dhall/amoebius/ui/Types.dhall
in  { caseName = "raw_external_link_url", tenantMode = T.TenantMode.SingleTenant
    , continuity = T.UiOffline.Continuity.OnlineOnly
    , modules = [] : List T.UiModule
    , externalLinks = [ { name = "docs", rawUrl = "https://caller.invalid" } ]
    }
