module AuthorizationReference
  ( referenceDecision
  , referenceRegistryRows
  ) where

import Data.List (sort)

referenceDecision :: [String] -> Either String Bool
referenceDecision row = case row of
  [_caseName, action, policy, requested, scope, epoch, _visible, _decision] -> do
    required <- requiredPermission action
    pure
      ( policy == "present"
          && requested == required
          && scope == "own"
          && epoch == "current"
      )
  _ -> Left ("invalid authorization matrix row: " <> show row)

referenceRegistryRows :: [[String]] -> Either String [[String]]
referenceRegistryRows rows = sort <$> traverse checkRow rows
  where
    checkRow row = case row of
      [action, effect, permission, visibility, idempotent]
        | action `elem` ["read-data", "mutate-data", "start-workflow", "observe-workflow", "end-session"]
            && effect `elem` ["ReadData", "MutateData", "StartWorkflow", "ObserveWorkflow", "EndSession"]
            && permission `elem` ["read", "write", "invoke"]
            && visibility `elem` ["visible", "hidden"]
            && idempotent `elem` ["true", "false"] -> Right row
        | otherwise -> Left ("invalid registry vocabulary: " <> show row)
      _ -> Left ("invalid registry row: " <> show row)

requiredPermission :: String -> Either String String
requiredPermission action = case action of
  "read-data" -> Right "read"
  "mutate-data" -> Right "write"
  "start-workflow" -> Right "invoke"
  "observe-workflow" -> Right "read"
  "end-session" -> Right "invoke"
  _ -> Left ("unknown action in independent evaluator: " <> action)
