module ReferenceClientPlan
  ( referenceTraces
  ) where

import Data.List (sortOn)

referenceTraces :: [[String]] -> Either String [[String]]
referenceTraces interactions = traverse interpret (sortOn rowKey interactions)
  where
    interpret row = case row of
      [caseName, _plan, step, event, _input, _expectedState, _expectedEffect] -> case event of
        "edit" -> Right [caseName, step, "editing", "-", "false", "home"]
        "submit" -> Right [caseName, step, "pending", "submit", "false", "workflow"]
        "cancel" -> Right [caseName, step, "cancelled", "cancel", "true", "workflow"]
        "open-docs" -> Right [caseName, step, "home", "navigate:docs", "false", "home"]
        "choose" -> Right [caseName, step, "ready", "scope", "false", "home"]
        _ -> Left ("unknown reference event: " <> event)
      _ -> Left ("invalid interaction row: " <> show row)

    rowKey row = case row of
      caseName : _plan : step : _ -> (caseName, step)
      _ -> ("", "")
