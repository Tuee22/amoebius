{-# LANGUAGE CPP #-}

module Amoebius.Ui.Server.TenantSession
  ( TenantId (..)
  , SubjectId (..)
  , ScopeEpoch (..)
  , Membership
  , TenantChoiceHandle
  , TenantSession (..)
  , TenantSessionError (..)
  , membership
  , issueChoice
  , selectChoice
  , scopedLookupKey
  , realtimeRouteKey
  ) where

import Data.Set (Set)
import Data.Set qualified as Set

newtype TenantId = TenantId String deriving stock (Eq, Ord, Show)
newtype SubjectId = SubjectId String deriving stock (Eq, Ord, Show)
newtype ScopeEpoch = ScopeEpoch Int deriving stock (Eq, Ord, Show)
newtype Membership = Membership (Set (SubjectId, TenantId)) deriving stock (Eq, Show)
data TenantChoiceHandle = TenantChoiceHandle SubjectId TenantId deriving stock (Eq, Show)
data TenantSession = TenantSession
  { sessionSubject :: SubjectId
  , sessionTenant :: TenantId
  , sessionEpoch :: ScopeEpoch
  , sessionStateCleared :: Bool
  , sessionOldHandlesValid :: Bool
  }
  deriving stock (Eq, Show)
data TenantSessionError = NotCurrentMember | HandleSubjectMismatch | StaleScopeEpoch
  deriving stock (Eq, Show)

membership :: [(SubjectId, TenantId)] -> Membership
membership = Membership . Set.fromList

issueChoice :: Membership -> SubjectId -> TenantId -> Either TenantSessionError TenantChoiceHandle
issueChoice members subject tenant
#ifdef PHASE56_ACCEPT_UNLISTED_CHOICE_MUTANT
  = Right (TenantChoiceHandle subject tenant)
#else
  | contains members subject tenant = Right (TenantChoiceHandle subject tenant)
  | otherwise = Left NotCurrentMember
#endif

selectChoice :: Membership -> Maybe TenantSession -> SubjectId -> TenantChoiceHandle -> Either TenantSessionError TenantSession
selectChoice members previous authenticated (TenantChoiceHandle owner tenant)
  | authenticated /= owner = Left HandleSubjectMismatch
#ifndef PHASE56_ACCEPT_UNLISTED_CHOICE_MUTANT
  | not (contains members authenticated tenant) = Left NotCurrentMember
#endif
  | otherwise = Right TenantSession
      { sessionSubject = authenticated
      , sessionTenant = tenant
      , sessionEpoch = nextEpoch previous
      , sessionStateCleared = True
      , sessionOldHandlesValid = False
      }

scopedLookupKey :: TenantSession -> String -> (String, String, String)
scopedLookupKey session coordinate =
#ifdef PHASE56_DROP_TENANT_KEY_MUTANT
  ("", subjectValue (sessionSubject session), coordinate)
#elif defined(PHASE56_DROP_USER_KEY_MUTANT)
  (tenantValue (sessionTenant session), "", coordinate)
#else
  (tenantValue (sessionTenant session), subjectValue (sessionSubject session), coordinate)
#endif

realtimeRouteKey :: TenantSession -> (String, String, Int)
realtimeRouteKey session =
#ifdef PHASE56_DROP_SCOPE_EPOCH_MUTANT
  (tenantValue (sessionTenant session), subjectValue (sessionSubject session), 0)
#else
  (tenantValue (sessionTenant session), subjectValue (sessionSubject session), epochValue (sessionEpoch session))
#endif

contains :: Membership -> SubjectId -> TenantId -> Bool
contains (Membership values) subject tenant = Set.member (subject, tenant) values
nextEpoch Nothing = ScopeEpoch 1
nextEpoch (Just prior) = ScopeEpoch (epochValue (sessionEpoch prior) + 1)
tenantValue (TenantId value) = value
subjectValue (SubjectId value) = value
epochValue (ScopeEpoch value) = value
