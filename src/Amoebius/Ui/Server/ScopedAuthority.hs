{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Ui.Server.ScopedAuthority
  ( ScopedOperation (..)
  , GrantState (..)
  , ResourceAudience (..)
  , HostileCallerFields (..)
  , ScopedDenial (..)
  , ProviderRequest
  , authorizeProviderRequest
  , providerRequestTenant
  , providerRequestSubject
  , providerRequestResource
  , ProbeDemand (..)
  , ProbeSupply (..)
  , ProbeProvisionError (..)
  , provisionProbe
  ) where

import Amoebius.Ui.Server.RequestContext
import Data.Text (Text)

data ScopedOperation
  = Create
  | Read
  | Update
  | Delete
  | Upload
  | Download
  | Produce
  | Consume
  deriving stock (Bounded, Enum, Eq, Ord, Read, Show)

data GrantState = NoGrant | ActiveGrant | RevokedGrant
  deriving stock (Eq, Ord, Read, Show)

data ResourceAudience
  = SubjectAudience Text Text Text
  | TenantAudience Text Text
  deriving stock (Eq, Ord, Show)

data HostileCallerFields = HostileCallerFields
  { callerTenant :: Text
  , callerSubject :: Text
  }
  deriving stock (Eq, Ord, Show)

data ScopedDenial = ScopedDenial
  deriving stock (Eq, Ord, Show)

data ProviderRequest = ProviderRequest
  { providerRequestTenant :: Text
  , providerRequestSubject :: Text
  , providerRequestResource :: Text
  , providerRequestOperation :: ScopedOperation
  }
  deriving stock (Eq, Show)

authorizeProviderRequest
  :: VerifiedCredential
  -> HostileCallerFields
  -> ResourceAudience
  -> GrantState
  -> ScopedOperation
  -> Either ScopedDenial ProviderRequest
authorizeProviderRequest credential hostile audience grant operation =
  hostile `seq`
  let trusted = serverRequestContext credential
#ifdef PHASE36_ACCEPT_BODY_TENANT_MUTANT
      requestTenant = callerTenant hostile
#else
      requestTenant = contextTenant trusted
#endif
      requestSubject = contextSubject trusted
      authorize tenant subject resource =
        Right ProviderRequest
          { providerRequestTenant = tenant
          , providerRequestSubject = subject
          , providerRequestResource = resource
          , providerRequestOperation = operation
          }
   in case audience of
        TenantAudience tenant resource
          | requestTenant == tenant -> authorize tenant requestSubject resource
          | otherwise -> Left ScopedDenial
        SubjectAudience tenant owner resource
          | requestTenant /= tenant -> Left ScopedDenial
#ifdef PHASE36_DROP_USER_PREDICATE_MUTANT
          | otherwise -> authorize tenant requestSubject resource
#else
          | requestSubject == owner -> authorize tenant requestSubject resource
          | grant == ActiveGrant -> authorize tenant requestSubject resource
          | otherwise -> Left ScopedDenial
#endif

data ProbeDemand = ProbeDemand
  { demandPodSlots :: Int
  , demandCpuMillis :: Int
  , demandMemoryBytes :: Integer
  , demandEphemeralBytes :: Integer
  , demandApiObjects :: Int
  , demandEtcdBytes :: Integer
  , demandSqlRows :: Int
  , demandObjectBytes :: Integer
  , demandMessageBytes :: Integer
  , demandObserverSlots :: Int
  }
  deriving stock (Eq, Show)

data ProbeSupply = ProbeSupply
  { supplyPodSlots :: Int
  , supplyCpuMillis :: Int
  , supplyMemoryBytes :: Integer
  , supplyEphemeralBytes :: Integer
  , supplyApiObjects :: Int
  , supplyEtcdBytes :: Integer
  , supplySqlRows :: Int
  , supplyObjectBytes :: Integer
  , supplyMessageBytes :: Integer
  , supplyObserverSlots :: Int
  }
  deriving stock (Eq, Show)

data ProbeProvisionError = ProbeProvisionShort Text Integer Integer
  deriving stock (Eq, Show)

provisionProbe :: ProbeDemand -> ProbeSupply -> Either [ProbeProvisionError] ()
provisionProbe demand supply =
  case concat
    [ short "pod-slots" (toInteger (demandPodSlots demand)) (toInteger (supplyPodSlots supply))
    , short "cpu-millis" (toInteger (demandCpuMillis demand)) (toInteger (supplyCpuMillis supply))
    , short "memory-bytes" (demandMemoryBytes demand) (supplyMemoryBytes supply)
    , short "ephemeral-bytes" (demandEphemeralBytes demand) (supplyEphemeralBytes supply)
    , short "api-objects" (toInteger (demandApiObjects demand)) (toInteger (supplyApiObjects supply))
    , short "etcd-bytes" (demandEtcdBytes demand) (supplyEtcdBytes supply)
    , short "sql-rows" (toInteger (demandSqlRows demand)) (toInteger (supplySqlRows supply))
    , short "object-bytes" (demandObjectBytes demand) (supplyObjectBytes supply)
    , short "message-bytes" (demandMessageBytes demand) (supplyMessageBytes supply)
    , short "observer-slots" (toInteger (demandObserverSlots demand)) (toInteger (supplyObserverSlots supply))
    ] of
      [] -> Right ()
      problems -> Left problems
 where
  short label needed supplied
    | supplied < needed = [ProbeProvisionShort label needed supplied]
    | otherwise = []
