module EffectBindingReference
  ( referenceBindings
  , referenceExternalLinks
  ) where

import Data.List (sort)

referenceBindings :: [[String]] -> [[String]] -> [[String]] -> Either String [[String]]
referenceBindings ports handlers capabilities = sort <$> traverse bind ports
  where
    bind port = case port of
      [portName, request, response, scope, _effect] -> do
        handler <- unique "handler" ((== request) . field 1) handlers
        case handler of
          [handlerName, _handlerRequest, handlerResponse, handlerScope, idempotency, audit]
            | handlerResponse /= response -> Left ("response mismatch for " <> portName)
            | handlerScope /= scope -> Left ("scope mismatch for " <> portName)
            | otherwise -> do
                capability <- unique "capability" ((== handlerName) . field 0) capabilities
                case capability of
                  [_capabilityHandler, capabilityName] ->
                    Right [portName, handlerName, capabilityName, scope, idempotency, audit]
                  _ -> Left ("invalid capability row: " <> show capability)
          _ -> Left ("invalid handler row: " <> show handler)
      _ -> Left ("invalid port row: " <> show port)

referenceExternalLinks :: [[String]] -> [[String]] -> Either String [[String]]
referenceExternalLinks requirements catalog = sort <$> traverse resolve requirements
  where
    resolve requirement = case requirement of
      [name, _url, target, rel] -> do
        entry <- unique "external link" ((== name) . field 0) catalog
        case entry of
          [_entryName, url] -> Right [name, url, target, rel]
          _ -> Left ("invalid external-link row: " <> show entry)
      _ -> Left ("invalid expected external-link row: " <> show requirement)

unique :: String -> (value -> Bool) -> [value] -> Either String value
unique label predicate values = case filter predicate values of
  [value] -> Right value
  matches -> Left (label <> " relation expected one match, got " <> show (length matches))

field :: Int -> [String] -> String
field index values = case drop index values of
  value : _ -> value
  [] -> ""
