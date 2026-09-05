{-# LANGUAGE CPP #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE StandaloneDeriving #-}

module Amoebius.Dsl.GadtDecode
  ( Surface (..)
  , ExecutionKind (..)
  , ResourceArm (..)
  , SecretRef (..)
  , Execution (..)
  , SomeExecution (..)
  , DecodedWorld (..)
  , DecodeFailure (..)
  , ProtocolField (..)
  , ProtocolMessage (..)
  , protocolDeclarations
  , renderProtocol
  , decodeWorld
  , decodeWorldFile
  ) where

import Control.Exception (SomeException, displayException, try)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import Dhall qualified
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data Surface = Cluster | App | Deployment
  deriving stock (Eq, Ord, Show)

data ExecutionKind = DeploymentK | StatefulSetK | DaemonSetK | JobK | HostProcessK

data ResourceArm = PodResource | HostResource
  deriving stock (Eq, Ord, Show)

data SecretRef = Vault Text | TransitKey Text | Prompt
  deriving stock (Eq, Ord, Show)

data Execution (kind :: ExecutionKind) where
  DeploymentExecution :: Text -> Natural -> ResourceArm -> Execution 'DeploymentK
  StatefulSetExecution :: Text -> Natural -> ResourceArm -> Execution 'StatefulSetK
  DaemonSetExecution :: Text -> Natural -> ResourceArm -> Execution 'DaemonSetK
  JobExecution :: Text -> Natural -> ResourceArm -> Execution 'JobK
  HostProcessExecution :: Text -> Natural -> ResourceArm -> Execution 'HostProcessK

deriving stock instance Eq (Execution kind)
deriving stock instance Show (Execution kind)

data SomeExecution where
  SomeExecution :: Execution kind -> SomeExecution

deriving stock instance Show SomeExecution

data DecodedWorld = DecodedWorld
  { decodedSurface :: Surface
  , decodedTenant :: Text
  , decodedOwner :: Text
  , decodedSecret :: SecretRef
  , decodedExecution :: SomeExecution
  }

instance Show DecodedWorld where
  show value =
    "DecodedWorld " <> show (decodedSurface value, decodedTenant value, decodedOwner value, decodedSecret value, decodedExecution value)

data DecodeFailure
  = ForbiddenImport Text
  | DhallFailure Text
  | UnknownSurface Text
  | UnknownController Text
  | UnknownResourceArm Text
  | EmptyExecutionId
  | ZeroRevision
  | TenantMismatch Text Text
  | PlaintextSecret
  | UnknownSecretRef Text
  | ResourceArmMismatch Text ResourceArm
  deriving stock (Eq, Show)

data RawWorld = RawWorld
  { surface :: Text
  , tenant :: Text
  , owner :: Text
  , executionId :: Text
  , revision :: Natural
  , controller :: Text
  , resourceArm :: Text
  , secretKind :: Text
  , secretValue :: Text
  }
  deriving stock (Generic, Show)
  deriving anyclass (Dhall.FromDhall)

data ProtocolField = ProtocolField
  { protocolFieldName :: Text
  , protocolFieldNumber :: Natural
  }
  deriving stock (Eq, Ord, Show)

data ProtocolMessage = ProtocolMessage
  { protocolMessageName :: Text
  , protocolMessageFields :: [ProtocolField]
  }
  deriving stock (Eq, Ord, Show)

protocolDeclarations :: [ProtocolMessage]
protocolDeclarations =
  [ ProtocolMessage "MessageIdData"
      [ ProtocolField "ledgerId" 1
      , ProtocolField "entryId" 2
      , ProtocolField "partition" 3
      ]
  , ProtocolMessage "MessageMetadata"
      [ ProtocolField "producer_name" 1
#ifdef GADT_DECODE_PROTOCOL_FIELD_MUTANT
      , ProtocolField "sequence_id" 3
#else
      , ProtocolField "sequence_id" 2
#endif
      , ProtocolField "publish_time" 3
      ]
  , ProtocolMessage "CommandConnect"
      [ ProtocolField "client_version" 1
      , ProtocolField "protocol_version" 4
      ]
  ]

renderProtocol :: Text
renderProtocol =
  Text.unlines
    ( ["syntax = \"proto2\";", "package amoebius.pulsar.proto;", ""]
        <> concatMap renderMessage protocolDeclarations
    )
 where
  renderMessage message =
    ["message " <> protocolMessageName message <> " {"]
      <> ["  optional bytes " <> protocolFieldName field <> " = " <> Text.pack (show (protocolFieldNumber field)) <> ";" | field <- protocolMessageFields message]
      <> ["}", ""]

decodeWorldFile :: FilePath -> IO (Either DecodeFailure DecodedWorld)
decodeWorldFile path = do
  attempt <- try (TextIO.readFile path) :: IO (Either SomeException Text)
  case attempt of
    Left problem -> pure (Left (DhallFailure (Text.pack (displayException problem))))
    Right source -> decodeWorld source

decodeWorld :: Text -> IO (Either DecodeFailure DecodedWorld)
decodeWorld source
  | "env:" `Text.isInfixOf` source = pure (Left (ForbiddenImport "env"))
  | "http://" `Text.isInfixOf` source || "https://" `Text.isInfixOf` source = pure (Left (ForbiddenImport "remote"))
  | otherwise = do
      attempt <- try (Dhall.input Dhall.auto source) :: IO (Either SomeException RawWorld)
      pure $ case attempt of
        Left problem -> Left (DhallFailure (Text.pack (displayException problem)))
        Right raw -> refine raw

refine :: RawWorld -> Either DecodeFailure DecodedWorld
refine raw = do
  surfaceValue <- case surface raw of
    "Cluster" -> Right Cluster
    "App" -> Right App
    "Deployment" -> Right Deployment
    other -> Left (UnknownSurface other)
  arm <- case resourceArm raw of
    "Pod" -> Right PodResource
    "Host" -> Right HostResource
    other -> Left (UnknownResourceArm other)
  if Text.null (Text.strip (executionId raw)) then Left EmptyExecutionId else Right ()
#ifndef GADT_DECODE_ZERO_REVISION_MUTANT
  if revision raw == 0 then Left ZeroRevision else Right ()
#endif
#ifndef GADT_DECODE_TENANT_MISMATCH_MUTANT
  if tenant raw /= owner raw then Left (TenantMismatch (tenant raw) (owner raw)) else Right ()
#endif
  secret <- case secretKind raw of
    "Vault" -> Right (Vault (secretValue raw))
    "TransitKey" -> Right (TransitKey (secretValue raw))
    "Prompt" -> Right Prompt
    "PlainText" -> Left PlaintextSecret
    other -> Left (UnknownSecretRef other)
  execution <- refineExecution raw arm
  Right (DecodedWorld surfaceValue (tenant raw) (owner raw) secret execution)

refineExecution :: RawWorld -> ResourceArm -> Either DecodeFailure SomeExecution
refineExecution raw arm = case controller raw of
  "Deployment" -> podOnly "Deployment" (SomeExecution (DeploymentExecution identity version arm))
  "StatefulSet" -> podOnly "StatefulSet" (SomeExecution (StatefulSetExecution identity version arm))
  "DaemonSet" -> podOnly "DaemonSet" (SomeExecution (DaemonSetExecution identity version arm))
  "Job" -> podOnly "Job" (SomeExecution (JobExecution identity version arm))
  "HostProcess" -> hostOnly (SomeExecution (HostProcessExecution identity version arm))
  other -> Left (UnknownController other)
 where
  identity = executionId raw
  version = revision raw
#ifdef GADT_DECODE_RESOURCE_ARM_MUTANT
  podOnly _ value = Right value
#else
  podOnly label value
    | arm == PodResource = Right value
    | otherwise = Left (ResourceArmMismatch label arm)
#endif
  hostOnly value
    | arm == HostResource = Right value
    | otherwise = Left (ResourceArmMismatch "HostProcess" arm)
