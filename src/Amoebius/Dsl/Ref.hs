{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE RoleAnnotations #-}

module Amoebius.Dsl.Ref
  ( Ref
  , refText
  , TenantToken (..)
  , TenantPair
  , sameTenant
  , mkRef
  , Owned
  , ownedText
  , OwnerToken (..)
  , OwnedAttachment
  , attachOwned
  , mkOwned
  , TenantAlpha
  , TenantBeta
  , OwnerPrimary
  , OwnerSecondary
  ) where

import Control.DeepSeq (NFData)
import Data.Text (Text)
import GHC.Generics (Generic)

data TenantAlpha
data TenantBeta
data OwnerPrimary
data OwnerSecondary

newtype Ref tenant resource = Ref Text
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

type role Ref nominal representational

refText :: Ref tenant resource -> Text
refText (Ref value) = value

data TenantToken tenant where
  TenantAlphaToken :: TenantToken TenantAlpha
  TenantBetaToken :: TenantToken TenantBeta

data TenantPair tenant = TenantPair
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

mkRef :: TenantToken tenant -> Text -> Ref tenant resource
mkRef _ = Ref

sameTenant :: Ref tenant left -> Ref tenant right -> TenantPair tenant
sameTenant _ _ = TenantPair

newtype Owned owner resource = Owned Text
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

type role Owned nominal representational

ownedText :: Owned owner resource -> Text
ownedText (Owned value) = value

data OwnerToken owner where
  OwnerPrimaryToken :: OwnerToken OwnerPrimary
  OwnerSecondaryToken :: OwnerToken OwnerSecondary

data OwnedAttachment owner resource = OwnedAttachment Text
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

mkOwned :: OwnerToken owner -> Text -> Owned owner resource
mkOwned _ = Owned

attachOwned :: OwnerToken owner -> Owned owner resource -> OwnedAttachment owner resource
attachOwned _ resource = OwnedAttachment (ownedText resource)
