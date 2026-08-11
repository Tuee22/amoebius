{-# LANGUAGE GADTs #-}

module Amoebius.Ui.Security.Scope
  ( Tenant
  , Subject
  , Membership
  , Owner
  , Grant
  , RequestContext
  , ScopeWitness
  , SubjectScope
  , TenantScope
  , ScopedHandle
  , SomeScopedHandle
  , ScopedUiProgram
  , ResourceId
  , ScopeError (..)
  , trustedTenant
  , trustedSubject
  , activeMembership
  , trustedRequestContext
  , subjectOwner
  , tenantOwner
  , grantOwner
  , activeGrant
  , revokedGrant
  , absentGrant
  , trustedResourceId
  , resolveOwned
  , scopeCheckedProgram
  , scopedProgramCase
  , tenantText
  , subjectText
  , subjectTenant
  , handleTenant
  , handleSubject
  ) where

import Amoebius.Ui.Check (CheckedUiProgram, checkedCaseName)
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

data RequestContext = RequestContext Tenant Subject Membership
  deriving stock (Eq, Ord, Show)

data SubjectScope
data TenantScope

data ScopeWitness scope where
  SubjectScopeWitness :: Tenant -> Subject -> ScopeWitness SubjectScope
  TenantScopeWitness :: Tenant -> ScopeWitness TenantScope

newtype ResourceId = ResourceId Text
  deriving stock (Eq, Ord, Show)

data ScopedHandle scope = ScopedHandle (ScopeWitness scope) ResourceId

data SomeScopedHandle where
  SomeSubjectHandle :: ScopedHandle SubjectScope -> SomeScopedHandle
  SomeTenantHandle :: ScopedHandle TenantScope -> SomeScopedHandle

data ScopedUiProgram = ScopedUiProgram CheckedUiProgram RequestContext

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

trustedRequestContext :: Tenant -> Subject -> Membership -> Either ScopeError RequestContext
trustedRequestContext tenant subject membership@(Membership membershipTenant membershipSubject)
  | tenant /= membershipTenant = Left MembershipMismatch
  | subject /= membershipSubject = Left MembershipMismatch
  | otherwise = Right (RequestContext tenant subject membership)

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

resolveOwned :: RequestContext -> Owner -> ResourceId -> Either ScopeError SomeScopedHandle
resolveOwned (RequestContext requestTenant requestSubject _) owner resource = case owner of
  OwnedBySubject ownerTenant ownerSubject
    | requestTenant /= ownerTenant -> Left TenantMismatch
    | requestSubject /= ownerSubject -> Left OwnerMismatch
    | otherwise -> Right (SomeSubjectHandle (ScopedHandle (SubjectScopeWitness ownerTenant ownerSubject) resource))
  OwnedByTenant ownerTenant
    | requestTenant /= ownerTenant -> Left TenantMismatch
    | otherwise -> Right (SomeTenantHandle (ScopedHandle (TenantScopeWitness ownerTenant) resource))
  OwnedByGrant ownerTenant ownerSubject grant
    | requestTenant /= ownerTenant -> Left TenantMismatch
    | grant == GrantIsAbsent -> Left GrantAbsent
    | grant == GrantIsRevoked -> Left GrantRevoked
    | otherwise -> Right (SomeSubjectHandle (ScopedHandle (SubjectScopeWitness ownerTenant ownerSubject) resource))

scopeCheckedProgram :: CheckedUiProgram -> RequestContext -> ScopedUiProgram
scopeCheckedProgram = ScopedUiProgram

scopedProgramCase :: ScopedUiProgram -> Text
scopedProgramCase (ScopedUiProgram checked _) = checkedCaseName checked

tenantText :: Tenant -> Text
tenantText (Tenant value) = value

subjectText :: Subject -> Text
subjectText (Subject _ value) = value

subjectTenant :: Subject -> Tenant
subjectTenant (Subject tenant _) = tenant

handleTenant :: SomeScopedHandle -> Tenant
handleTenant handle = case handle of
  SomeSubjectHandle (ScopedHandle (SubjectScopeWitness tenant _) _) -> tenant
  SomeTenantHandle (ScopedHandle (TenantScopeWitness tenant) _) -> tenant

handleSubject :: SomeScopedHandle -> Maybe Subject
handleSubject handle = case handle of
  SomeSubjectHandle (ScopedHandle (SubjectScopeWitness _ subject) _) -> Just subject
  SomeTenantHandle _ -> Nothing

validIdentifier :: Text -> Bool
validIdentifier value =
  not (Text.null value)
    && Text.all (\character -> isAlphaNum character || character `elem` ['-', '_', '.', ':']) value
