let UiOffline = ../UiOffline.dhall

let TenantMode = < SingleTenant | MultiTenant >

let NodeKind = < Route | State | Event | Port | Collection | Branch | ExternalLink >

let ValueType =
      < Text
      | Natural
      | Boolean
      | View
      | TenantChoice
      | WorkflowStart
      | WorkflowProgress
      | ServerHandle
      >

let UiNode =
      { nodeId : Text
      , nodeKind : NodeKind
      , valueType : ValueType
      , edges : List Text
      , events : List Text
      , branches : List Text
      , maxItems : Optional Natural
      , public : Bool
      , portType : Optional ValueType
      }

let UiModule = { moduleId : Text, nodes : List UiNode }

let ExternalLinkRequirement = { name : Text }

let UiSource =
      { caseName : Text
      , tenantMode : TenantMode
      , continuity : UiOffline.Continuity
      , modules : List UiModule
      , externalLinks : List ExternalLinkRequirement
      }

in  { UiOffline
    , TenantMode
    , NodeKind
    , ValueType
    , UiNode
    , UiModule
    , ExternalLinkRequirement
    , UiSource
    }
