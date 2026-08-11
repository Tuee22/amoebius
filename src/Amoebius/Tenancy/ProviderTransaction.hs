{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Tenancy.ProviderTransaction
  ( ProvisionBudget (..)
  , TransactionError (..)
  , renderTransactionError
  , ProvisionedTenantPolicyAction
  , provisionTenantPolicy
  , provisionedProjection
  , ValidatedProviderTarget
  , validateProviderTarget
  , renderProvisionedAction
  ) where

import Amoebius.Tenancy.ProviderProjection
import Data.Text (Text)
import Data.Text qualified as Text

data ProvisionBudget = ProvisionBudget
  { providerActionSlots :: Int
  , providerMetadataBytes :: Int
  }
  deriving stock (Eq, Show)

data TransactionError
  = ProviderActionSlotsShort Int Int
  | ProviderMetadataBytesShort Int Int
  | ProviderTargetChallengeInvalid
  | ProviderTargetEpochInvalid
  deriving stock (Eq, Show)

renderTransactionError :: TransactionError -> Text
renderTransactionError = \case
  ProviderActionSlotsShort needed supplied -> "provider-action-slots-short:" <> pair needed supplied
  ProviderMetadataBytesShort needed supplied -> "provider-metadata-bytes-short:" <> pair needed supplied
  ProviderTargetChallengeInvalid -> "provider-target-challenge-invalid"
  ProviderTargetEpochInvalid -> "provider-target-epoch-invalid"
 where
  pair needed supplied = Text.pack (show needed) <> ":" <> Text.pack (show supplied)

newtype ProvisionedTenantPolicyAction = ProvisionedTenantPolicyAction ProjectionAction
  deriving stock (Eq, Show)

provisionedProjection :: ProvisionedTenantPolicyAction -> ProjectionAction
provisionedProjection (ProvisionedTenantPolicyAction action) = action

provisionTenantPolicy :: ProvisionBudget -> TenantPolicyDerivation -> Either TransactionError [ProvisionedTenantPolicyAction]
provisionTenantPolicy budget derivation
  | providerActionSlots budget < neededSlots = Left (ProviderActionSlotsShort neededSlots (providerActionSlots budget))
  | providerMetadataBytes budget < neededBytes = Left (ProviderMetadataBytesShort neededBytes (providerMetadataBytes budget))
  | otherwise = Right (map ProvisionedTenantPolicyAction actions)
 where
  actions = derivationActions derivation
  neededSlots = length actions
  neededBytes = sum (map actionBytes actions)
  actionBytes action =
    sum
      [ Text.length (providerText (actionProvider action))
      , Text.length (actionAppId action)
      , Text.length (actionTenantId action)
      , Text.length (actionLocalId action)
      , Text.length (actionObjectType action)
      , Text.length (actionParent action)
      , Text.length (actionPermissionClass action)
      ]

data ValidatedProviderTarget = ValidatedProviderTarget Text Text
  deriving stock (Eq, Show)

validateProviderTarget :: Text -> Text -> Either TransactionError ValidatedProviderTarget
validateProviderTarget challenge epoch
  | Text.length challenge < 12 = Left ProviderTargetChallengeInvalid
  | Text.null epoch = Left ProviderTargetEpochInvalid
  | otherwise = Right (ValidatedProviderTarget challenge epoch)

renderProvisionedAction :: ValidatedProviderTarget -> ProvisionedTenantPolicyAction -> ProjectionAction
renderProvisionedAction _ = provisionedProjection
