{-# LANGUAGE OverloadedStrings #-}

module GadtDecodeOracle
  ( OracleCase (..)
  , expectedCases
  , expectedProtocolRows
  ) where

import Data.Text (Text)
import Data.Text qualified as Text

data OracleCase = OracleCase
  { oracleName :: Text
  , oracleSource :: Text
  , oracleExpected :: Either Text Text
  }
  deriving stock (Eq, Show)

expectedCases :: [OracleCase]
expectedCases =
  [ positive "deployment" "Cluster" "Deployment" "Pod" "Vault"
  , positive "statefulset" "App" "StatefulSet" "Pod" "TransitKey"
  , positive "daemonset" "Deployment" "DaemonSet" "Pod" "Prompt"
  , positive "job" "Cluster" "Job" "Pod" "Vault"
  , positive "host-process" "Cluster" "HostProcess" "Host" "TransitKey"
  , negative "unknown-surface" (world "Unknown" "Deployment" "Pod" "Vault" "tenant-a" "tenant-a" 1 "exec") "UnknownSurface"
  , negative "unknown-controller" (world "Cluster" "Unknown" "Pod" "Vault" "tenant-a" "tenant-a" 1 "exec") "UnknownController"
  , negative "unknown-resource" (world "Cluster" "Deployment" "Gpu" "Vault" "tenant-a" "tenant-a" 1 "exec") "UnknownResourceArm"
  , negative "empty-id" (world "Cluster" "Deployment" "Pod" "Vault" "tenant-a" "tenant-a" 1 "") "EmptyExecutionId"
  , negative "zero-revision" (world "Cluster" "Deployment" "Pod" "Vault" "tenant-a" "tenant-a" 0 "exec") "ZeroRevision"
  , negative "tenant-mismatch" (world "Cluster" "Deployment" "Pod" "Vault" "tenant-a" "tenant-b" 1 "exec") "TenantMismatch"
  , negative "plaintext-secret" (world "Cluster" "Deployment" "Pod" "PlainText" "tenant-a" "tenant-a" 1 "exec") "PlaintextSecret"
  , negative "deployment-host-arm" (world "Cluster" "Deployment" "Host" "Vault" "tenant-a" "tenant-a" 1 "exec") "ResourceArmMismatch"
  , negative "host-pod-arm" (world "Cluster" "HostProcess" "Pod" "Vault" "tenant-a" "tenant-a" 1 "exec") "ResourceArmMismatch"
  , negative "forbidden-env" "env:AMOEBIUS_SECRET" "ForbiddenImport"
  , negative "forbidden-remote" "https://example.invalid/world.dhall" "ForbiddenImport"
  , negative "malformed" "{ this is not Dhall" "DhallFailure"
  ]
 where
  positive name surface controller arm secret = OracleCase name (world surface controller arm secret "tenant-a" "tenant-a" 1 ("exec-" <> name)) (Right controller)
  negative name source failure = OracleCase name source (Left failure)

world :: Text -> Text -> Text -> Text -> Text -> Text -> Integer -> Text -> Text
world surface controller arm secret tenant owner revision executionId =
  "{ surface = \"" <> surface <> "\", tenant = \"" <> tenant <> "\", owner = \"" <> owner
    <> "\", executionId = \"" <> executionId <> "\", revision = " <> number revision
    <> ", controller = \"" <> controller <> "\", resourceArm = \"" <> arm
    <> "\", secretKind = \"" <> secret <> "\", secretValue = \"secret-ref\" }"
 where
  number value = if value < 0 then "+" <> fromString (show value) else fromString (show value)
  fromString = Text.pack

expectedProtocolRows :: [(Text, [(Text, Integer)])]
expectedProtocolRows =
  [ ("MessageIdData", [("ledgerId", 1), ("entryId", 2), ("partition", 3)])
  , ("MessageMetadata", [("producer_name", 1), ("sequence_id", 2), ("publish_time", 3)])
  , ("CommandConnect", [("client_version", 1), ("protocol_version", 4)])
  ]
