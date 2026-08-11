module Amoebius.Ui.Interpreter
  ( Transition
  , transition
  ) where

import Prelude

type Transition =
  { visibleState :: String
  , effect :: String
  , cancelled :: Boolean
  , route :: String
  , focus :: String
  }

transition :: String -> String -> String -> Transition
transition current event input = case event of
  "edit" -> outcome "editing" "-" false "home" "input"
  "submit" ->
    if input == ""
      then outcome current "-" false "home" "error-summary"
      else outcome "pending" "POST /ui/action/submit" false "workflow" "new-route-h1"
  "cancel" -> outcome "cancelled" "POST /ui/action/cancel" true "workflow" "new-route-h1"
  "open-docs" -> outcome current "NAVIGATE docs" false "home" "docs-link"
  "choose" -> outcome "ready" "POST /ui/scope" false "home" "new-route-h1"
  "start" -> outcome "Workflow running" "POST /ui/action/start" false "workflow" "new-route-h1"
  "observe" -> outcome "Artifact ready" "POST /ui/action/observe" false "workflow" "new-route-h1"
  "use-artifact" -> outcome "Result pending" "POST /ui/action/use-artifact" false "workflow" "new-route-h1"
  _ -> outcome "unknown-event" "-" false "home" "error-summary"
  where
  outcome visibleState effect cancelled route focus =
    { visibleState, effect, cancelled, route, focus }
