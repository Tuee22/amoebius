let T = ../../../dhall/amoebius/ui/Types.dhall
in  { caseName = "duplicate_external_link_requirement", tenantMode = T.TenantMode.SingleTenant
    , modules = [] : List T.UiModule
    , externalLinks = [ { name = "docs" }, { name = "docs" } ]
    }
