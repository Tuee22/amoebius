{-# LANGUAGE CPP #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE RankNTypes #-}

module Amoebius.Scope.Index
  ( Tenant
  , Subject
  , Membership
  , Owner
  , Grant
  , RequestScope
  , Scoped
  , ScopedHandle
  , SomeScopedHandle
  , HandleKind (..)
  , ResourceId
  , ScopeError (..)
  , trustedTenant
  , trustedSubject
  , activeMembership
  , withRequestScope
  , subjectOwner
  , tenantOwner
  , grantOwner
  , activeGrant
  , revokedGrant
  , absentGrant
  , trustedResourceId
  , scoped
  , mapScoped
  , pairScoped
  , scopedValue
  , resolveOwned
  , handleKind
  , tenantText
  , subjectText
  , subjectTenant
  , scopeTenant
  , scopeSubject
  ) where

import Data.Char (isAlphaNum)
import Data.Text (Text)
import qualified Data.Text as Text

newtype Tenant = Tenant Text
  deriving stock (Eq, Ord, Show)

data Subject = Subject Tenant Text
  deriving stock (Eq, Ord, Show)

data Membership = Membership Tenant Subject
  deriving stock (Eq, Ord, Show)

data Grant = GrantIsActive | GrantIsRevoked | GrantIsAbsent
  deriving stock (Eq, Ord, Show)

data Owner
  = OwnedBySubject Tenant Subject
  | OwnedByTenant Tenant
  | OwnedByGrant Tenant Subject Grant
  deriving stock (Eq, Ord, Show)

-- The constructor is private. The only eliminator introduces a fresh, locally
-- quantified scope variable, so a value indexed by one request cannot be retagged as
-- another request's value or escape the continuation that minted it.
data RequestScope scope = RequestScope Tenant Subject Membership

newtype Scoped scope value = Scoped value

data SubjectHandle
data TenantHandle

data ScopedHandle scope kind = ScopedHandle ResourceId

data SomeScopedHandle scope where
  SomeSubjectHandle :: ScopedHandle scope SubjectHandle -> SomeScopedHandle scope
  SomeTenantHandle :: ScopedHandle scope TenantHandle -> SomeScopedHandle scope

data HandleKind = SubjectHandleKind | TenantHandleKind
  deriving stock (Eq, Ord, Show)

newtype ResourceId = ResourceId Text
  deriving stock (Eq, Ord, Show)

data ScopeError
  = InvalidTenant Text
  | InvalidSubject Text
  | InvalidResourceId Text
  | MembershipMismatch
  | TenantMismatch
  | OwnerMismatch
  | GrantAbsent
  | GrantRevoked
  deriving stock (Eq, Ord, Show)

trustedTenant :: Text -> Either ScopeError Tenant
trustedTenant value
  | validIdentifier value = Right (Tenant value)
  | otherwise = Left (InvalidTenant value)

trustedSubject :: Tenant -> Text -> Either ScopeError Subject
trustedSubject tenant value
  | validIdentifier value = Right (Subject tenant value)
  | otherwise = Left (InvalidSubject value)

activeMembership :: Tenant -> Subject -> Either ScopeError Membership
activeMembership tenant subject
  | tenant == subjectTenant subject = Right (Membership tenant subject)
  | otherwise = Left MembershipMismatch

withRequestScope
  :: Tenant
  -> Subject
  -> Membership
  -> (forall scope. RequestScope scope -> result)
  -> Either ScopeError result
withRequestScope tenant subject membership@(Membership membershipTenant membershipSubject) continuation
  | tenant /= membershipTenant = Left MembershipMismatch
  | subject /= membershipSubject = Left MembershipMismatch
  | otherwise = Right (continuation (RequestScope tenant subject membership))

subjectOwner :: Tenant -> Subject -> Owner
subjectOwner = OwnedBySubject

tenantOwner :: Tenant -> Owner
tenantOwner = OwnedByTenant

grantOwner :: Tenant -> Subject -> Grant -> Owner
grantOwner = OwnedByGrant

activeGrant :: Grant
activeGrant = GrantIsActive

revokedGrant :: Grant
revokedGrant = GrantIsRevoked

absentGrant :: Grant
absentGrant = GrantIsAbsent

trustedResourceId :: Text -> Either ScopeError ResourceId
trustedResourceId value
  | validIdentifier value = Right (ResourceId value)
  | otherwise = Left (InvalidResourceId value)

scoped :: RequestScope scope -> value -> Scoped scope value
scoped _ = Scoped

mapScoped :: (left -> right) -> Scoped scope left -> Scoped scope right
mapScoped transform (Scoped value) = Scoped (transform value)

pairScoped :: Scoped scope left -> Scoped scope right -> Scoped scope (left, right)
pairScoped (Scoped left) (Scoped right) = Scoped (left, right)

scopedValue :: Scoped scope value -> value
scopedValue (Scoped value) = value

resolveOwned
  :: RequestScope scope
  -> Owner
  -> ResourceId
  -> Either ScopeError (SomeScopedHandle scope)
resolveOwned (RequestScope requestTenant requestSubject _) owner resource = case owner of
#ifdef SCOPE_INDEX_DROP_OWNER_EQUALITY_MUTANT
  OwnedBySubject _ _ -> Right (SomeSubjectHandle (ScopedHandle resource))
#else
  OwnedBySubject ownerTenant ownerSubject
    | requestTenant /= ownerTenant -> Left TenantMismatch
    | requestSubject /= ownerSubject -> Left OwnerMismatch
    | otherwise -> Right (SomeSubjectHandle (ScopedHandle resource))
#endif
  OwnedByTenant ownerTenant
    | requestTenant /= ownerTenant -> Left TenantMismatch
    | otherwise -> Right (SomeTenantHandle (ScopedHandle resource))
  OwnedByGrant ownerTenant ownerSubject grant
    | requestTenant /= ownerTenant -> Left TenantMismatch
    | requestSubject == ownerSubject -> Left OwnerMismatch
    | grant == GrantIsAbsent -> Left GrantAbsent
    | grant == GrantIsRevoked -> Left GrantRevoked
    | otherwise -> Right (SomeSubjectHandle (ScopedHandle resource))

handleKind :: SomeScopedHandle scope -> HandleKind
handleKind handle = case handle of
  SomeSubjectHandle _ -> SubjectHandleKind
  SomeTenantHandle _ -> TenantHandleKind

tenantText :: Tenant -> Text
tenantText (Tenant value) = value

subjectText :: Subject -> Text
subjectText (Subject _ value) = value

subjectTenant :: Subject -> Tenant
subjectTenant (Subject tenant _) = tenant

scopeTenant :: RequestScope scope -> Tenant
scopeTenant (RequestScope tenant _ _) = tenant

scopeSubject :: RequestScope scope -> Subject
scopeSubject (RequestScope _ subject _) = subject

validIdentifier :: Text -> Bool
validIdentifier value =
  not (Text.null value)
    && Text.length value <= 128
    && Text.all (\character -> isAlphaNum character || character `elem` ("-_." :: String)) value
