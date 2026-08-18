{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Tenancy.ProviderProjection
  ( Provider (..)
  , providerText
  , RawTenantGraph (..)
  , RawTenant (..)
  , CheckedTenantGraph
  , ProjectionError (..)
  , renderProjectionError
  , decodeCheckedTenantGraph
  , TenantPolicyDerivation
  , ProjectionAction (..)
  , deriveTenantPolicy
  , derivationActions
  , actionQualifiedKey
  ) where

import Data.Aeson (FromJSON)
import Data.List (find)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)

data Provider
  = Keycloak
  | Vault
  | Pulsar
  | Minio
  | KubernetesApi
  | Postgres
  deriving stock (Bounded, Enum, Eq, Ord, Show)

providerText :: Provider -> Text
providerText = Text.pack . show

data RawTenant = RawTenant
  { outerTenantId :: Text
  , tenantId :: Text
  , subjects :: [Text]
  , roles :: [Text]
  }
  deriving stock (Eq, Generic, Show)

instance FromJSON RawTenant

data RawTenantGraph = RawTenantGraph
  { schema :: Text
  , appId :: Text
  , tenants :: [RawTenant]
  , providerNativeGrants :: [Text]
  }
  deriving stock (Eq, Generic, Show)

instance FromJSON RawTenantGraph

newtype CheckedTenantGraph = CheckedTenantGraph RawTenantGraph
  deriving stock (Eq, Show)

data ProjectionError
  = SchemaMismatch Text
  | AppIdInvalid
  | RepresentativeTenantCardinality Int
  | HandAuthoredProviderGrant Text
  | TenantReferenceMismatch Text Text
  | SubjectIssuerMissing Text
  | DerivedReadRoleMissing Text
  | ProviderArmIncomplete Provider
  | TenantKeyCollapse Text
  deriving stock (Eq, Show)

renderProjectionError :: ProjectionError -> Text
renderProjectionError = \case
  SchemaMismatch observed -> "schema-mismatch:" <> observed
  AppIdInvalid -> "app-id-invalid"
  RepresentativeTenantCardinality count -> "representative-tenant-cardinality:" <> Text.pack (show count)
  HandAuthoredProviderGrant grant -> "hand-authored-provider-grant:" <> grant
  TenantReferenceMismatch outer inner -> "tenant-reference-mismatch:" <> outer <> ":" <> inner
  SubjectIssuerMissing subject -> "issuer-qualified-subject-required:" <> subject
  DerivedReadRoleMissing tenant -> "derived-read-role-missing:" <> tenant
  ProviderArmIncomplete provider -> "provider-arm-incomplete:" <> providerText provider
  TenantKeyCollapse key -> "tenant-key-collapse:" <> key

decodeCheckedTenantGraph :: RawTenantGraph -> Either ProjectionError CheckedTenantGraph
decodeCheckedTenantGraph raw
  | schema raw /= "amoebius.phase34.tenant-graph.v1" = Left (SchemaMismatch (schema raw))
  | Text.null (appId raw) = Left AppIdInvalid
  | length (tenants raw) /= 2 = Left (RepresentativeTenantCardinality (length (tenants raw)))
  | grant : _ <- providerNativeGrants raw = Left (HandAuthoredProviderGrant grant)
  | Just tenant <- find (\value -> outerTenantId value /= tenantId value) (tenants raw) =
      Left (TenantReferenceMismatch (outerTenantId tenant) (tenantId tenant))
  | Just subject <- find (not . Text.isInfixOf "/") (concatMap subjects (tenants raw)) =
      Left (SubjectIssuerMissing subject)
  | Just tenant <- find (not . elem "read" . roles) (tenants raw) =
      Left (DerivedReadRoleMissing (tenantId tenant))
  | otherwise = Right (CheckedTenantGraph raw)

data ProjectionAction = ProjectionAction
  { actionProvider :: Provider
  , actionAppId :: Text
  , actionTenantId :: Text
  , actionLocalId :: Text
  , actionObjectType :: Text
  , actionParent :: Text
  , actionPermissionClass :: Text
  }
  deriving stock (Eq, Ord, Show)

newtype TenantPolicyDerivation = TenantPolicyDerivation [ProjectionAction]
  deriving stock (Eq, Show)

derivationActions :: TenantPolicyDerivation -> [ProjectionAction]
derivationActions (TenantPolicyDerivation actions) = actions

actionQualifiedKey :: ProjectionAction -> Text
#ifdef APP_TENANCY_COLLAPSE_TENANT_KEY_MUTANT
actionQualifiedKey action = actionLocalId action
#else
actionQualifiedKey action =
  Text.intercalate "/" [actionAppId action, actionTenantId action, providerText (actionProvider action), actionLocalId action]
#endif

deriveTenantPolicy :: CheckedTenantGraph -> Either ProjectionError TenantPolicyDerivation
deriveTenantPolicy (CheckedTenantGraph raw) = do
  let derived = concatMap (tenantActions (appId raw)) (tenants raw)
#ifdef APP_TENANCY_DROP_PROVIDER_ARM_MUTANT
      actions = filter ((/= Pulsar) . actionProvider) derived
#else
      actions = derived
#endif
  validateComplete actions
  validateKeys actions
  pure (TenantPolicyDerivation actions)

validateComplete :: [ProjectionAction] -> Either ProjectionError ()
validateComplete actions =
  case find (\provider -> all ((/= provider) . actionProvider) actions) [minBound .. maxBound] of
    Just missing -> Left (ProviderArmIncomplete missing)
    Nothing -> Right ()

validateKeys :: [ProjectionAction] -> Either ProjectionError ()
validateKeys actions =
  case find ((> 1) . snd) (Map.toAscList counts) of
    Just (key, _) -> Left (TenantKeyCollapse key)
    Nothing -> Right ()
 where
  counts = Map.fromListWith (+) [(actionQualifiedKey action, 1 :: Int) | action <- actions]

tenantActions :: Text -> RawTenant -> [ProjectionAction]
tenantActions app tenant =
  [ action Keycloak "realm-read-role" "RealmRole" ("amoebius/" <> tid) "read"
  , action Keycloak "subject-membership" "GroupRoleMapping" ("amoebius/" <> tid) "member+owner"
  , action Vault "secret-prefix" "AclPolicy" ("secret/data/amoebius/phase34/" <> app <> "/" <> tid <> "/*") "read+list"
  , action Pulsar "message-namespace" "NamespacePolicy" (tid <> "/" <> app) "produce+consume"
  , action Minio "object-bucket" "BucketPolicy" (app <> "-" <> tid) "read+write"
  , action KubernetesApi "kubernetes-namespace" "Namespace" (app <> "-" <> tid) "manage"
  , action KubernetesApi "east-west-policy" "NetworkPolicy" (app <> "-" <> tid <> "/default-deny") "same-tenant"
  , action Postgres "sql-role" "Role" (app <> "_" <> tid) "connect"
  , action Postgres "sql-schema" "Schema" (app <> "_" <> tid) "usage+create"
  ]
 where
  tid = tenantId tenant
  action provider localId objectType parent permission =
    ProjectionAction provider app tid localId objectType parent permission
