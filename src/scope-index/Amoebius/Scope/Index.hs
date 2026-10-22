-- | Compatibility vocabulary and eliminators. Scope introduction lives only
-- at the attested boundary; the old text-based mint is absent.
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

import Amoebius.Scope.Attested
