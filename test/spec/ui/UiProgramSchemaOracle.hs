{-# LANGUAGE OverloadedStrings #-}

{- | Independently authored Phase-37 expectations. This module deliberately
imports no production or shared fixture module.
-}
module UiProgramSchemaOracle (
    caseOracle,
    programOracle,
    graphOracle,
    calculusOracle,
    compileBarrierOracle,
    mutantOracle,
    validationLoci,
) where

import Data.Text (Text)

caseOracle :: [(Text, Either (Text, Text) ())]
caseOracle =
    [ accepted "minimal_single_tenant"
    , accepted "minimal_multi_tenant"
    , accepted "composed_workflow_ui"
    , rejected "raw_browser_escape" "RawBrowserEscape" "ui.source:1"
    , rejected "recursive_effect" "RecursiveEffect" "ui.effect:1"
    , rejected "unbounded_collection" "UnboundedCollection" "ui.collection:1"
    , rejected "duplicate_qualified_id" "DuplicateQualifiedId" "ui.module:1"
    , rejected "missing_reference" "MissingReference" "ui.graph:1"
    , rejected "raw_external_link_url" "RawExternalLinkUrl" "ui.link:1"
    , rejected "duplicate_external_link_requirement" "DuplicateExternalLinkRequirement" "ui.link:2"
    , rejected "port_type_mismatch" "PortTypeMismatch" "ui.port:1"
    , rejected "non_exhaustive_event" "NonExhaustiveEvent" "ui.event:1"
    , rejected "private_value_projection" "PrivateValueProjection" "ui.projection:1"
    ]
  where
    accepted name = (name, Right ())
    rejected name tag spanText = (name, Left (tag, spanText))

programOracle :: [[Text]]
programOracle =
    [ ["minimal_single_tenant", "single-tenant", "app.main", "app.main.home,app.main.submit", "docs"]
    , ["minimal_multi_tenant", "multi-tenant", "app.main", "app.main.home,app.main.tenant", "docs"]
    , ["composed_workflow_ui", "single-tenant", "app.workflow", "app.workflow.progress,app.workflow.start", "docs"]
    ]

graphOracle :: [[Text]]
graphOracle =
    [ ["minimal_single_tenant", "app.main.home", "Route", "View", "app.main.submit", "submit"]
    , ["minimal_multi_tenant", "app.main.tenant", "Route", "TenantChoice", "app.main.home", "choose-tenant"]
    , ["composed_workflow_ui", "app.workflow.start", "Port", "WorkflowStart", "app.workflow.progress", "cancel,start"]
    ]

calculusOracle :: [[Text]]
calculusOracle =
    [ ["calculus-kinds", "artifact,budget,lift,workflow,evidence"]
    , ["component-names", "program-semantics,diagnostic-budget,generated-rejection-classes,graph-check-workflow,mutant-evidence"]
    , ["projection-counts", "3,10,8,3,6"]
    , ["resource-vector", "5,30,0,0"]
    ]

compileBarrierOracle :: [(Text, Text, Text)]
compileBarrierOracle =
    [ ("checked-ui-legal", "test/negative/compile_fail/ui_program_schema/checked_ui_legal.hs", "")
  , ("checked-ui-illegal", "test/negative/compile_fail/ui_program_schema/checked_ui_illegal.hs", "Illegal term-level use of the type constructor")
    ]

mutantOracle :: [(Text, Text, Text, Text)]
mutantOracle =
    [ mutant "add-raw-js-arm" "ui-program-schema-add-raw-js-arm-mutant" "Source.decodeUiSourceText" "raw_browser_escape outcome drifted: accepted"
    , mutant "add-raw-url-arm" "ui-program-schema-add-raw-url-arm-mutant" "Source.decodeUiSourceText" "raw_external_link_url outcome drifted: accepted"
    , mutant "drop-bound-check" "ui-program-schema-drop-bound-check-mutant" "Check.checkBounds" "unbounded_collection outcome drifted: accepted"
    , mutant "first-id-wins" "ui-program-schema-first-id-wins-mutant" "Check.buildNodeTable" "duplicate_qualified_id outcome drifted: accepted"
    , mutant "skip-exhaustiveness" "ui-program-schema-skip-exhaustiveness-mutant" "Check.checkEvents" "non_exhaustive_event outcome drifted: accepted"
    , mutant "swap-port-contract" "ui-program-schema-swap-port-contract-mutant" "Check.checkPorts" "port_type_mismatch outcome drifted: accepted"
    ]
  where
    mutant name flagName locus expected = (name, flagName, locus, expected)

validationLoci :: [(Text, Text)]
validationLoci =
    [(name, "positive") | name <- ["minimal_single_tenant", "minimal_multi_tenant", "composed_workflow_ui"]]
        <> [(name, "negative") | name <- ["raw_browser_escape", "recursive_effect", "unbounded_collection", "duplicate_qualified_id", "missing_reference", "raw_external_link_url", "duplicate_external_link_requirement", "port_type_mismatch", "non_exhaustive_event", "private_value_projection"]]
        <> [(name, "graph") | name <- ["minimal_single_tenant", "minimal_multi_tenant", "composed_workflow_ui"]]
        <> [(name, "generated-class") | name <- ["duplicate", "missing", "cyclic", "ill-typed", "over-bound", "non-exhaustive", "private", "duplicate-link"]]
        <> [(name, "mutant") | (name, _, _, _) <- mutantOracle]
