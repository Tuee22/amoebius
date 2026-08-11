{-# LANGUAGE CPP #-}

module Amoebius.Platform.BringUp
  ( Service (..)
  , BringUpEvent (..)
  , declaredDependencies
  , oracleDependencies
  , deriveReadinessLevels
  , runBringUp
  ) where

import Control.Concurrent.Class.MonadSTM
  ( MonadSTM
  , atomically
  , newEmptyTMVar
  , putTMVar
  , readTMVar
  )
import Control.Monad.Class.MonadAsync (MonadAsync, async, wait)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set

data Service
  = MetalLB
  | MinIO
  | Vault
  | Registry
  | ZooKeeper
  | BookKeeper
  | Pulsar
  | PerconaOperator
  | GrafanaPostgres
  | PgAdmin
  | Redis
  | Sentinel
  | Prometheus
  | Grafana
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data BringUpEvent = ServiceStarted Service | ServiceReady Service
  deriving stock (Eq, Ord, Show)

oracleDependencies :: Map Service (Set Service)
oracleDependencies =
  Map.fromList
    [ (MetalLB, Set.empty)
    , (MinIO, Set.singleton MetalLB)
    , (Vault, Set.empty)
    , (Registry, Set.singleton MinIO)
    , (ZooKeeper, Set.singleton Vault)
    , (BookKeeper, Set.fromList [Vault, ZooKeeper])
    , (Pulsar, Set.fromList [Vault, MinIO, ZooKeeper, BookKeeper])
    , (PerconaOperator, Set.empty)
    , (GrafanaPostgres, Set.fromList [Vault, PerconaOperator])
    , (PgAdmin, Set.fromList [Vault, GrafanaPostgres])
    , (Redis, Set.singleton Vault)
    , (Sentinel, Set.fromList [Vault, Redis])
    , (Prometheus, Set.fromList [MinIO, Pulsar])
    , (Grafana, Set.fromList [GrafanaPostgres, Prometheus])
    ]

declaredDependencies :: Map Service (Set Service)
declaredDependencies = mutate oracleDependencies
 where
#ifdef PHASE31_DAG_DROP_EDGE_MUTANT
  mutate = Map.adjust (Set.delete PerconaOperator) GrafanaPostgres
#elif defined(PHASE31_DAG_INJECT_CYCLE_MUTANT)
  mutate = Map.adjust (Set.insert Grafana) PerconaOperator
#else
  mutate = id
#endif

deriveReadinessLevels :: Map Service (Set Service) -> Either String [[Service]]
deriveReadinessLevels graph
  | Map.keysSet graph /= Set.fromList [minBound .. maxBound] = Left "readiness-service-set-incomplete"
  | not (all (`Set.isSubsetOf` Map.keysSet graph) (Map.elems graph)) = Left "readiness-edge-target-unknown"
  | otherwise = go Set.empty graph []
 where
  go ready remaining levels
    | Map.null remaining = Right (reverse levels)
    | null available = Left "readiness-cycle"
    | otherwise =
        let selected = Set.fromList available
         in go (ready <> selected) (foldr Map.delete remaining available) (available : levels)
   where
    available = [service | (service, dependencies) <- Map.toAscList remaining, dependencies `Set.isSubsetOf` ready]

runBringUp :: (MonadAsync m, MonadSTM m) => (Service -> m Bool) -> Map Service (Set Service) -> m (Either String [BringUpEvent])
runBringUp observe graph = case deriveReadinessLevels graph of
  Left problem -> pure (Left problem)
  Right _ -> do
    signals <- traverse (const (atomically newEmptyTMVar)) graph
    workers <- traverse (async . runOne signals) (Map.keys graph)
    outcomes <- traverse wait workers
    case [service | (service, ready, _) <- outcomes, not ready] of
      failed : _ -> pure (Left ("readiness-failed:" <> show failed))
      [] -> pure (Right (concatMap (\(_, _, events) -> events) outcomes))
 where
  runOne signals service = do
    dependencyStates <- atomically (traverse (readTMVar . (signals Map.!)) (Set.toAscList (graph Map.! service)))
    if not (and dependencyStates)
      then atomically (putTMVar (signals Map.! service) False) >> pure (service, False, [])
      else do
        ready <- observe service
        atomically (putTMVar (signals Map.! service) ready)
        pure
          ( service
          , ready
          , [ServiceStarted service] <> [ServiceReady service | ready]
          )
