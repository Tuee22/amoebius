let T = ../../../dhall/amoebius/ui/Types.dhall
in  { caseName = "raw_browser_escape", tenantMode = T.TenantMode.SingleTenant
    , modules = [] : List T.UiModule
    , externalLinks = [] : List T.ExternalLinkRequirement
    , rawJs = "window.fetch('/escape')"
    }
