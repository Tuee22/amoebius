{-# LANGUAGE OverloadedStrings #-}

module AuthorizationCases (
    ActionRow (..),
    DecisionRow (..),
    EpochRow (..),
    actionRows,
    decisionRows,
    parityRows,
    epochRows,
) where

import Amoebius.Ui.Security.Authorization
import Data.Text (Text)

data ActionRow = ActionRow
    { actionName :: Text
    , actionEffect :: ActionEffect
    , actionPermission :: Permission
    , actionVisibility :: Visibility
    , actionIdempotent :: Bool
    }
    deriving stock (Eq, Show)

data DecisionRow = DecisionRow
    { decisionName :: Text
    , decisionAction :: Text
    , decisionPolicyPresent :: Bool
    , decisionPermission :: Permission
    , decisionOwnScope :: Bool
    , decisionCurrentEpoch :: Bool
    , decisionVisible :: Bool
    , decisionAllowed :: Bool
    }
    deriving stock (Eq, Show)

data EpochRow = EpochRow
    { epochName :: Text
    , epochCurrent :: Int
    , epochPresented :: Int
    , epochError :: Text
    }
    deriving stock (Eq, Show)

actionRows :: [ActionRow]
actionRows =
    [ ActionRow "read-data" ReadData ReadPermission Visible True
    , ActionRow "mutate-data" MutateData WritePermission Visible True
    , ActionRow "start-workflow" StartWorkflow InvokePermission Hidden True
    , ActionRow "observe-workflow" ObserveWorkflow ReadPermission Visible True
    , ActionRow "end-session" EndSession InvokePermission Visible False
    ]

decisionRows :: [DecisionRow]
decisionRows =
    [ DecisionRow "read-own" "read-data" True ReadPermission True True True True
    , DecisionRow "hidden-invocable" "start-workflow" True InvokePermission True True False True
    , DecisionRow "default-deny" "read-data" False ReadPermission True True True False
    , DecisionRow "wrong-scope" "read-data" True ReadPermission False True True False
    , DecisionRow "wrong-permission" "mutate-data" True ReadPermission True True True False
    , DecisionRow "stale" "end-session" True InvokePermission True False True False
    ]

parityRows :: [(Text, Text)]
parityRows =
    [ ("missing-action", "MissingAction")
    , ("extra-action", "UnexpectedAction")
    , ("duplicate-action", "DuplicateAction")
    , ("permission-swap", "ProjectionMismatch")
    ]

epochRows :: [EpochRow]
epochRows =
    [ EpochRow "policy" 4 3 "StalePolicyEpoch"
    , EpochRow "membership" 7 6 "StaleMembershipEpoch"
    , EpochRow "grant" 9 8 "StaleGrantEpoch"
    , EpochRow "scope" 12 11 "StaleScopeEpoch"
    ]
