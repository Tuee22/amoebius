{-# LANGUAGE OverloadedStrings #-}
module UiBrowserInterpreterCases (currentPlan, stalePlan, interactions, calculusRows) where
import Amoebius.Ui.Browser.Interpreter

currentPlan, stalePlan :: ClientPlan
currentPlan = ClientPlan "plan-v1" "plan-v1" ["home", "workflow"] [minBound .. maxBound]
stalePlan = currentPlan {planDigest = "plan-v0"}

interactions :: [Interaction]
interactions =
  [ Interaction "single-edit" Edit "fresh-challenge"
  , Interaction "single-submit" Submit ""
  , Interaction "single-cancel" Cancel ""
  , Interaction "named-link" OpenDocs ""
  , Interaction "multi-choose" Choose "opaque-choice"
  ]

calculusRows :: [[String]]
calculusRows =
  [ ["calculus-kinds", "artifact,budget,lift,workflow,evidence"]
  , ["component-names", "browser-bundle-artifacts,closed-browser-budget,browser-boundary-corpus,differential-browser-workflow,mutant-evidence"]
  , ["projection-counts", "9,5,45,4,9"]
  , ["resource-vector", "5,72,0,0"]
  ]
