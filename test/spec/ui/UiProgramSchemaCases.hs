{-# LANGUAGE OverloadedStrings #-}

module UiProgramSchemaCases (
    CaseSubject (..),
    ExpectedOutcome (..),
    UiCase (..),
    uiCases,
    positiveSources,
    minimalSingleTenant,
) where

import Amoebius.Ui.Offline.Types (Continuity (OnlineOnly))
import Amoebius.Ui.Source
import Data.Text (Text)

data CaseSubject = TypedSource UiSource | ExternalSource Text
    deriving stock (Eq, Show)

data ExpectedOutcome = Accept | Reject Text Text
    deriving stock (Eq, Show)

data UiCase = UiCase
    { uiCaseName :: Text
    , uiCaseSubject :: CaseSubject
    , uiCaseExpected :: ExpectedOutcome
    }
    deriving stock (Eq, Show)

uiCases :: [UiCase]
uiCases =
    [ accepted minimalSingleTenant
    , accepted minimalMultiTenant
    , accepted composedWorkflowUi
    , rejectedExternal "raw_browser_escape" "RawBrowserEscape" "ui.source:1" "let rawJs = \"window.fetch('/escape')\" in { rawJs = rawJs }"
    , rejected "recursive_effect" "RecursiveEffect" "ui.effect:1" (singleNodeSource "recursive_effect" ((plainNode "loop" Event Boolean){edges = ["loop"]}))
    , rejected "unbounded_collection" "UnboundedCollection" "ui.collection:1" (singleNodeSource "unbounded_collection" ((plainNode "items" Collection Text){maxItems = Nothing}))
    , rejected "duplicate_qualified_id" "DuplicateQualifiedId" "ui.module:1" duplicateQualifiedId
    , rejected "missing_reference" "MissingReference" "ui.graph:1" (singleNodeSource "missing_reference" ((plainNode "home" Route View){edges = ["missing"]}))
    , rejectedExternal "raw_external_link_url" "RawExternalLinkUrl" "ui.link:1" "let rawUrl = \"https://caller.invalid\" in { rawUrl = rawUrl }"
    , rejected "duplicate_external_link_requirement" "DuplicateExternalLinkRequirement" "ui.link:2" duplicateExternalLink
    , rejected "port_type_mismatch" "PortTypeMismatch" "ui.port:1" (singleNodeSource "port_type_mismatch" ((plainNode "port" Port Text){portType = Just Natural}))
    , rejected "non_exhaustive_event" "NonExhaustiveEvent" "ui.event:1" (singleNodeSource "non_exhaustive_event" ((plainNode "route" Route View){events = ["Ready", "Cancelled"], branches = ["Ready"]}))
    , rejected "private_value_projection" "PrivateValueProjection" "ui.projection:1" (singleNodeSource "private_value_projection" ((plainNode "secret" State ServerHandle){public = True}))
    ]
  where
    accepted source = UiCase (caseName source) (TypedSource source) Accept
    rejected name tag spanText source = UiCase name (TypedSource source) (Reject tag spanText)
    rejectedExternal name tag spanText source = UiCase name (ExternalSource source) (Reject tag spanText)

positiveSources :: [UiSource]
positiveSources = [minimalSingleTenant, minimalMultiTenant, composedWorkflowUi]

minimalSingleTenant :: UiSource
minimalSingleTenant =
    UiSource
        "minimal_single_tenant"
        SingleTenant
        OnlineOnly
        [ UiModule
            "app.main"
            [ (plainNode "home" Route View){edges = ["submit"], events = ["submit"], branches = ["submit"]}
            , plainNode "submit" Event Boolean
            ]
        ]
        [ExternalLinkRequirement "docs"]

minimalMultiTenant :: UiSource
minimalMultiTenant =
    UiSource
        "minimal_multi_tenant"
        MultiTenant
        OnlineOnly
        [ UiModule
            "app.main"
            [ (plainNode "tenant" Route TenantChoice){edges = ["home"], events = ["choose-tenant"], branches = ["choose-tenant"], maxItems = Just 2}
            , (plainNode "home" State View){maxItems = Just 2}
            ]
        ]
        [ExternalLinkRequirement "docs"]

composedWorkflowUi :: UiSource
composedWorkflowUi =
    UiSource
        "composed_workflow_ui"
        SingleTenant
        OnlineOnly
        [ UiModule
            "app.workflow"
            [ (plainNode "start" Port WorkflowStart){edges = ["progress"], events = ["start", "cancel"], branches = ["start", "cancel"], maxItems = Just 3, portType = Just WorkflowStart}
            , (plainNode "progress" Collection WorkflowProgress){maxItems = Just 3}
            ]
        ]
        [ExternalLinkRequirement "docs"]

plainNode :: Text -> NodeKind -> ValueType -> UiNode
plainNode identifier kind value =
    UiNode
        { nodeId = identifier
        , nodeKind = kind
        , valueType = value
        , edges = []
        , events = []
        , branches = []
        , maxItems = Just 1
        , public = True
        , portType = Nothing
        }

singleNodeSource :: Text -> UiNode -> UiSource
singleNodeSource identifier node = UiSource identifier SingleTenant OnlineOnly [UiModule "app.main" [node]] []

duplicateQualifiedId :: UiSource
duplicateQualifiedId =
    let node = plainNode "home" Route View
     in UiSource "duplicate_qualified_id" SingleTenant OnlineOnly [UiModule "app.main" [node, node]] []

duplicateExternalLink :: UiSource
duplicateExternalLink =
    UiSource
        "duplicate_external_link_requirement"
        SingleTenant
        OnlineOnly
        []
        [ExternalLinkRequirement "docs", ExternalLinkRequirement "docs"]
