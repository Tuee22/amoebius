

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
  | contains members subject tenant = Right (TenantChoiceHandle subject tenant)
  | otherwise = Left NotCurrentMember

selectChoice :: Membership -> Maybe TenantSession -> SubjectId -> TenantChoiceHandle -> Either TenantSessionError TenantSession
selectChoice members previous authenticated (TenantChoiceHandle owner tenant)
  | authenticated /= owner = Left HandleSubjectMismatch
  | not (contains members authenticated tenant) = Left NotCurrentMember
  | otherwise = Right TenantSession
      { sessionSubject = authenticated
      , sessionTenant = tenant
      , sessionEpoch = nextEpoch previous
      , sessionStateCleared = True
      , sessionOldHandlesValid = False
      }

scopedLookupKey :: TenantSession -> String -> (String, String, String)
scopedLookupKey session coordinate =
  (tenantValue (sessionTenant session), subjectValue (sessionSubject session), coordinate)

realtimeRouteKey :: TenantSession -> (String, String, Int)
realtimeRouteKey session =
  (tenantValue (sessionTenant session), subjectValue (sessionSubject session), epochValue (sessionEpoch session))

contains :: Membership -> SubjectId -> TenantId -> Bool
contains (Membership values) subject tenant = Set.member (subject, tenant) values
nextEpoch Nothing = ScopeEpoch 1
nextEpoch (Just prior) = ScopeEpoch (epochValue (sessionEpoch prior) + 1)
tenantValue (TenantId value) = value
subjectValue (SubjectId value) = value
epochValue (ScopeEpoch value) = value
