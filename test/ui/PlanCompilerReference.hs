{-# LANGUAGE OverloadedStrings #-}

module PlanCompilerReference
  ( referenceDigest
  , referenceProjectionRows
  , referenceAuthoritySource
  ) where

import qualified Crypto.Hash.SHA256 as SHA256
import qualified Data.ByteString as Strict
import Data.ByteString.Lazy (ByteString)
import Data.List (sort)
import Data.Text (Text)
import qualified Data.Text as Text
import Numeric (showHex)

referenceDigest :: ByteString -> Text
referenceDigest bytes = "sha256:" <> Text.pack (concatMap byteHex (Strict.unpack (SHA256.hashlazy bytes)))
  where
    byteHex byte = case showHex byte "" of
      [digit] -> ['0', digit]
      digits -> digits

referenceProjectionRows :: [[String]] -> Either String [[String]]
referenceProjectionRows rows = sort <$> traverse validate rows
  where
    validate row = case row of
      [source, client, server, route, contract, audit, handler]
        | source == "" -> Left "empty source"
        | client == "-" -> Left ("missing client projection: " <> source)
        | route == "-" -> Left ("missing route guard: " <> source)
        | isEvent client && any (== "-") [server, contract, audit, handler] ->
            Left ("incomplete effect projection: " <> source)
        | not (isEvent client) && server /= "-" -> Left ("server-only action: " <> source)
        | otherwise -> Right row
      _ -> Left ("invalid projection row: " <> show row)

    isEvent value = take 6 value == "event:"

referenceAuthoritySource :: [[String]] -> [[String]] -> [[String]] -> [[String]] -> [Text]
referenceAuthoritySource actionRows portRows bindingRows linkRows =
  ["program:minimal_single_tenant"]
    <> map renderAction (sort actionRows)
    <> map renderPort (sort portRows)
    <> map renderLink (sort linkRows)
  where
    renderAction row = case row of
      [action, effect, permission, visibility, idempotent] -> Text.intercalate ":"
        [ "action", Text.pack action, Text.pack effect, permissionName permission
        , visibilityName visibility, Text.pack idempotent
        ]
      _ -> "invalid-action"
    renderPort row = case row of
      [port, request, response, effect] -> case findBinding port bindingRows of
        [_, handler, capability, scope, retry, audit] -> Text.intercalate ":"
          [ "port", Text.pack port, Text.pack handler, Text.pack capability, Text.pack request
          , Text.pack response, "Port" <> Text.pack effect, scopeName scope, retryName retry, auditName audit
          ]
        _ -> "invalid-port-binding"
      _ -> "invalid-port"
    renderLink row = case row of
      [name, url] -> "link:" <> Text.pack name <> ":" <> Text.pack url
      _ -> "invalid-link"

permissionName :: String -> Text
permissionName value = case value of
  "read" -> "ReadPermission"
  "write" -> "WritePermission"
  "invoke" -> "InvokePermission"
  _ -> "InvalidPermission"

visibilityName :: String -> Text
visibilityName value = case value of
  "visible" -> "Visible"
  "hidden" -> "Hidden"
  _ -> "InvalidVisibility"

scopeName :: String -> Text
scopeName value = case value of
  "owner" -> "OwnerScope"
  "tenant" -> "TenantScope"
  "grant" -> "GrantScope"
  _ -> "InvalidScope"

retryName :: String -> Text
retryName value = case value of
  "none" -> "NoRetryContract"
  "required" -> "IdempotentRetry"
  _ -> "InvalidRetry"

auditName :: String -> Text
auditName value = case value of
  "read" -> "ReadAudit"
  "mutation" -> "MutationAudit"
  "workflow" -> "WorkflowAudit"
  "stream" -> "StreamAudit"
  "blob" -> "BlobAudit"
  "artifact" -> "ArtifactAudit"
  _ -> "InvalidAudit"

findBinding :: String -> [[String]] -> [String]
findBinding port rows = case filter ((== port) . firstField) rows of
  row : _ -> row
  [] -> []

firstField :: [String] -> String
firstField values = case values of value : _ -> value; [] -> ""
