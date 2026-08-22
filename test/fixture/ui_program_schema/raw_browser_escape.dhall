let T = ../../../dhall/amoebius/ui/Types.dhall
in  { caseName = "raw_browser_escape", tenantMode = T.TenantMode.SingleTenant
    , continuity = T.UiOffline.Continuity.OnlineOnly
    , modules = [] : List T.UiModule
    , externalLinks = [] : List T.ExternalLinkRequirement
    , rawJs = "window.fetch('/escape')"
    }
