{-# LANGUAGE OverloadedStrings #-}

{- | Independently authored Phase-38 expectations. This module deliberately
imports no production or shared case module.
-}
module AuthorizationOracle (
    registryOracle,
    decisionOracle,
    parityOracle,
    epochOracle,
    calculusOracle,
    mutantOracle,
    validationLoci,
) where

import Data.Text (Text)

registryOracle :: [[Text]]
registryOracle =
    [ ["read-data", "ReadData", "read", "visible", "true"]
    , ["mutate-data", "MutateData", "write", "visible", "true"]
    , ["start-workflow", "StartWorkflow", "invoke", "hidden", "true"]
    , ["observe-workflow", "ObserveWorkflow", "read", "visible", "true"]
    , ["end-session", "EndSession", "invoke", "visible", "false"]
    ]

decisionOracle :: [(Text, Bool)]
decisionOracle =
    [ ("read-own", True)
    , ("hidden-invocable", True)
    , ("default-deny", False)
    , ("wrong-scope", False)
    , ("wrong-permission", False)
    , ("stale", False)
    ]

parityOracle :: [(Text, Text)]
parityOracle =
    [ ("missing-action", "MissingAction")
    , ("extra-action", "UnexpectedAction")
    , ("duplicate-action", "DuplicateAction")
    , ("permission-swap", "ProjectionMismatch")
    ]

epochOracle :: [(Text, Text)]
epochOracle =
    [ ("policy", "StalePolicyEpoch")
    , ("membership", "StaleMembershipEpoch")
    , ("grant", "StaleGrantEpoch")
    , ("scope", "StaleScopeEpoch")
    ]

calculusOracle :: [[Text]]
calculusOracle =
    [ ["calculus-kinds", "artifact,budget,lift,workflow,evidence"]
    , ["component-names", "action-registry,authorization-decisions,parity-and-epoch-refusals,generated-coverage-workflow,mutant-evidence"]
    , ["projection-counts", "5,6,8,9,2"]
    , ["resource-vector", "5,30,0,0"]
    ]

mutantOracle :: [(Text, Text, Text, Text)]
mutantOracle =
    [ ("default-allow", "ui-authorization-default-allow-mutant", "Authorization.authorize", "default-deny production decision: expected False, got True")
    , ("visibility-is-authorization", "ui-authorization-visibility-mutant", "Authorization.authorize", "hidden-invocable production decision: expected True, got False")
    ]

validationLoci :: [(Text, Text)]
validationLoci =
    [(name, "registry") | name <- ["read-data", "mutate-data", "start-workflow", "observe-workflow", "end-session"]]
        <> [(name, "decision") | (name, _) <- decisionOracle]
        <> [(name, "parity") | (name, _) <- parityOracle]
        <> [(name, "epoch") | (name, _) <- epochOracle]
        <> [(name, "generated-class") | name <- ["absent-policy", "wrong-scope", "wrong-permission", "stale-epoch", "read-data", "mutate-data", "start-workflow", "observe-workflow", "end-session"]]
        <> [(name, "mutant") | (name, _, _, _) <- mutantOracle]
