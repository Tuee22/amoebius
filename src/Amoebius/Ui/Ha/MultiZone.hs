{-# LANGUAGE CPP #-}

module Amoebius.Ui.Ha.MultiZone
  ( AdmissionError (..)
  , Authority (..)
  , Component (..)
  , Continuity (..)
  , DurableState (..)
  , Fault (..)
  , HaTopology
  , Operation (..)
  , Zone (..)
  , admitTopology
  , authorizeAfterFault
  , canonicalTopology
  , components
  , continuityDuring
  , hardSpread
  , plannedFault
  , repairAfterCoordinationLoss
  , replicasFor
  ) where

import Data.List (nub)

data Zone = ZoneA | ZoneB | ZoneC
  deriving stock (Eq, Ord, Show)

data Component = UiServer | UiProjector | Redis | Keycloak
  deriving stock (Eq, Ord, Show, Enum, Bounded)

data HaTopology = HaTopology
  { placements :: [(Component, [Zone])]
  , minimumAvailable :: Int
  , stickySessionRequired :: Bool
  , redisIsReceiptAuthority :: Bool
  }
  deriving stock (Eq, Show)

data AdmissionError
  = TooFewReplicas Component
  | MissingHardSpread Component
  | MissingDisruptionBudget
  | StickySessionDependency
  | RedisReceiptAuthority
  deriving stock (Eq, Show)

data Fault = WholeZone Zone | OneNode Zone
  deriving stock (Eq, Show)

data Operation = Read | IdempotentMutation | WorkflowStart | Subscription
  deriving stock (Eq, Show, Enum, Bounded)

data Continuity = FullMatrixAvailable | FaultUnderScoped | DependencyUnavailable Component
  deriving stock (Eq, Show)

data Authority = Authority
  { cookieEmptyLogin :: Bool
  , currentMembership :: Bool
  , currentScopeEpoch :: Bool
  }
  deriving stock (Eq, Show)

data DurableState = DurableState
  { durableCursor :: Int
  , durableReceipt :: String
  }
  deriving stock (Eq, Show)

components :: [Component]
components = [minBound .. maxBound]

canonicalTopology :: HaTopology
canonicalTopology =
  HaTopology
    { placements =
        [ (UiServer, uiServers)
        , (UiProjector, uiProjectors)
        , (Redis, redisMembers)
        , (Keycloak, keycloakMembers)
        ]
    , minimumAvailable = pdbMinimum
    , stickySessionRequired = stickyRequired
    , redisIsReceiptAuthority = redisReceiptAuthority
    }
  where
#ifdef PHASE58_REPLICAS_ONE_MUTANT
    uiServers = [ZoneA]
#else
    uiServers = [ZoneA, ZoneB, ZoneC]
#endif
#ifdef PHASE58_DROP_TOPOLOGY_SPREAD_MUTANT
    uiProjectors = [ZoneA, ZoneA, ZoneC]
#else
    uiProjectors = [ZoneA, ZoneB, ZoneC]
#endif
#ifdef PHASE58_REDIS_ONE_NODE_MUTANT
    redisMembers = [ZoneA]
#else
    redisMembers = [ZoneA, ZoneB, ZoneC]
#endif
#ifdef PHASE58_DROP_KEYCLOAK_ZONE_SPREAD_MUTANT
    keycloakMembers = [ZoneA, ZoneA, ZoneC]
#else
    keycloakMembers = [ZoneA, ZoneB, ZoneC]
#endif
#ifdef PHASE58_DROP_PDB_MUTANT
    pdbMinimum = 0
#else
    pdbMinimum = 2
#endif
#ifdef PHASE58_STICKY_SESSION_REQUIRED_MUTANT
    stickyRequired = True
#else
    stickyRequired = False
#endif
#ifdef PHASE58_REDIS_PERSISTENT_RECEIPT_MUTANT
    redisReceiptAuthority = True
#else
    redisReceiptAuthority = False
#endif

replicasFor :: Component -> HaTopology -> [Zone]
replicasFor component topology = maybe [] id (lookup component (placements topology))

hardSpread :: Component -> HaTopology -> Bool
hardSpread component topology =
  let zones = replicasFor component topology
   in length zones >= 3 && length (nub zones) >= 3

admitTopology :: HaTopology -> Either AdmissionError HaTopology
admitTopology topology =
  case [component | component <- components, length (replicasFor component topology) < 3] of
    component : _ -> Left (TooFewReplicas component)
    [] -> case [component | component <- components, not (hardSpread component topology)] of
      component : _ -> Left (MissingHardSpread component)
      []
        | minimumAvailable topology < 2 -> Left MissingDisruptionBudget
        | stickySessionRequired topology -> Left StickySessionDependency
        | redisIsReceiptAuthority topology -> Left RedisReceiptAuthority
        | otherwise -> Right topology

plannedFault :: Fault
#ifdef PHASE58_FAULT_ONE_NODE_ONLY_MUTANT
plannedFault = OneNode ZoneB
#else
plannedFault = WholeZone ZoneB
#endif

continuityDuring :: HaTopology -> Fault -> Continuity
continuityDuring topology fault = case fault of
  OneNode _ -> FaultUnderScoped
  WholeZone zone ->
    case admitTopology topology of
      Left _ -> DependencyUnavailable UiServer
      Right _ ->
        case [component | component <- components, length (filter (/= zone) (replicasFor component topology)) < 2] of
          component : _ -> DependencyUnavailable component
          [] -> FullMatrixAvailable

authorizeAfterFault :: Authority -> Bool
authorizeAfterFault authority =
  cookieEmptyLogin authority && currentMembership authority && currentScopeEpoch authority

repairAfterCoordinationLoss :: DurableState -> Maybe DurableState
#ifdef PHASE58_SKIP_CURSOR_REPAIR_MUTANT
repairAfterCoordinationLoss _ = Nothing
#else
repairAfterCoordinationLoss durable = Just durable
#endif
