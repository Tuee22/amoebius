let T = ../../../dhall/amoebius/ui/Types.dhall
in  { caseName = "raw_external_link_url", tenantMode = T.TenantMode.SingleTenant
    , modules = [] : List T.UiModule
    , externalLinks = [ { name = "docs", rawUrl = "https://caller.invalid" } ]
    }
