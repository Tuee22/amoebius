{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Reconcile.Sim
  ( ReconcileSchedule (..)
  , SimulationVerdict (..)
  , SimulationResult (..)
  , SnapshotToken
  , TokenResult (..)
  , SnapshotStore
  , newSnapshotStore
  , readSnapshot
  , mintSnapshotToken
  , applyWithSnapshotToken
  , advanceObservationVersion
  , readStoreTrace
  , simulateReconcile
  ) where

import Amoebius.Reconcile.Core
import Control.Concurrent.Class.MonadSTM
  ( MonadSTM
  , TVar
  , atomically
  , newTVarIO
  , readTVar
  , readTVarIO
  , writeTVar
  )
import Control.Monad.Class.MonadTimer (MonadDelay, threadDelay)
import Data.Aeson (FromJSON, ToJSON)
import Data.List (sortOn)
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data ReconcileSchedule = ReconcileSchedule
  { scheduleName :: Text
  , scheduleSeed :: Int
  , scheduleBound :: Natural
  , scheduleDuplicateDelivery :: Bool
  , scheduleCrashBeforeApply :: Bool
  , scheduleStaleSnapshot :: Bool
  , scheduleDelayMicros :: Int
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (FromJSON, ToJSON)

data SimulationVerdict
  = SimulationConverged
  | SimulationRefused Refusal
  | SimulationExhausted
  deriving stock (Eq, Show)

data SimulationResult = SimulationResult
  { simulationVerdict :: SimulationVerdict
  , simulationFinalInventory :: [Text]
  , simulationAcceptedWrites :: Natural
  , simulationRejectedReuses :: Natural
  , simulationRejectedStale :: Natural
  , simulationTrace :: [Text]
  }
  deriving stock (Eq, Show)

data SnapshotToken = SnapshotToken Natural Natural
  deriving stock (Eq, Ord, Show)

data TokenResult = TokenApplied | TokenRejectedReuse | TokenRejectedStale
  deriving stock (Eq, Ord, Show)

data StoreState = StoreState
  { storeInventory :: ObservedInventory
  , storeVersion :: Natural
  , storeNextNonce :: Natural
  , storeConsumed :: Set SnapshotToken
  , storeAccepted :: Natural
  , storeReuseRejected :: Natural
  , storeStaleRejected :: Natural
  , storeTraceRev :: [Text]
  }

newtype SnapshotStore m = SnapshotStore (TVar m StoreState)

newSnapshotStore :: MonadSTM m => ObservedInventory -> m (SnapshotStore m)
newSnapshotStore inventory = SnapshotStore <$> newTVarIO initial
 where
  initial =
    StoreState
      { storeInventory = inventory
      , storeVersion = 0
      , storeNextNonce = 0
      , storeConsumed = Set.empty
      , storeAccepted = 0
      , storeReuseRejected = 0
      , storeStaleRejected = 0
      , storeTraceRev = []
      }

readSnapshot :: MonadSTM m => SnapshotStore m -> m (Natural, ObservedInventory)
readSnapshot (SnapshotStore variable) = do
  state <- readTVarIO variable
  pure (storeVersion state, storeInventory state)

mintSnapshotToken :: MonadSTM m => SnapshotStore m -> m SnapshotToken
mintSnapshotToken (SnapshotStore variable) = atomically $ do
  state <- readTVar variable
  let token = SnapshotToken (storeVersion state) (storeNextNonce state)
  writeTVar variable state {storeNextNonce = storeNextNonce state + 1}
  pure token

applyWithSnapshotToken
  :: MonadSTM m
  => SnapshotStore m
  -> SnapshotToken
  -> SomeAction
  -> m TokenResult
applyWithSnapshotToken (SnapshotStore variable) token@(SnapshotToken tokenVersion _) action = atomically $ do
  state <- readTVar variable
  if token `Set.member` storeConsumed state
    then do
      writeTVar variable (record "token-rejected:reuse" state {storeReuseRejected = storeReuseRejected state + 1})
      pure TokenRejectedReuse
    else if tokenVersion /= storeVersion state
      then do
        writeTVar variable (record "token-rejected:stale" state {storeStaleRejected = storeStaleRejected state + 1})
        pure TokenRejectedStale
      else do
        let event = "action-applied:" <> renderAction action
            updated =
              state
                { storeInventory = applyActionToInventory action (storeInventory state)
                , storeVersion = storeVersion state + 1
                , storeConsumed = Set.insert token (storeConsumed state)
                , storeAccepted = storeAccepted state + 1
                }
        writeTVar variable (record event updated)
        pure TokenApplied

advanceObservationVersion :: MonadSTM m => SnapshotStore m -> m ()
advanceObservationVersion (SnapshotStore variable) = atomically $ do
  state <- readTVar variable
  writeTVar variable (record "observation-advanced" state {storeVersion = storeVersion state + 1})

readStoreTrace :: MonadSTM m => SnapshotStore m -> m [Text]
readStoreTrace (SnapshotStore variable) = reverse . storeTraceRev <$> readTVarIO variable

simulateReconcile
  :: (MonadSTM m, MonadDelay m)
  => ReconcileSchedule
  -> DesiredIndex
  -> ObservedInventory
  -> m SimulationResult
simulateReconcile schedule desired initial = do
  store <- newSnapshotStore initial
  verdict <- loop store 0 False False
  state <- case store of SnapshotStore variable -> readTVarIO variable
  pure
    SimulationResult
      { simulationVerdict = verdict
      , simulationFinalInventory = inventorySemantic (storeInventory state)
      , simulationAcceptedWrites = storeAccepted state
      , simulationRejectedReuses = storeReuseRejected state
      , simulationRejectedStale = storeStaleRejected state
      , simulationTrace = reverse (storeTraceRev state)
      }
 where
  loop store step crashInjected staleInjected
    | step >= scheduleBound schedule = pure SimulationExhausted
    | otherwise = do
        (_, inventory) <- readSnapshot store
        case planReconcile inventory desired of
          Left refusal -> pure (SimulationRefused refusal)
          Right [] -> pure SimulationConverged
          Right actions -> do
            let action = selectAction step actions
            token <- mintSnapshotToken store
            if scheduleCrashBeforeApply schedule && not crashInjected
              then do
                appendEvent store "crash-before-apply"
                delay
                loop store (step + 1) True staleInjected
              else do
                staleNow <-
                  if scheduleStaleSnapshot schedule && not staleInjected
                    then advanceObservationVersion store >> pure True
                    else pure staleInjected
                result <- applyWithSnapshotToken store token action
                if scheduleDuplicateDelivery schedule && result == TokenApplied
                  then do
                    _ <- applyWithSnapshotToken store token action
                    pure ()
                  else pure ()
                delay
                loop store (step + 1) crashInjected staleNow

  selectAction step actions =
    let ordered = sortOn renderAction actions
        position = (abs (scheduleSeed schedule) + fromIntegral step) `mod` length ordered
     in ordered !! position

  delay
    | scheduleDelayMicros schedule <= 0 = pure ()
    | otherwise = threadDelay (scheduleDelayMicros schedule)

record :: Text -> StoreState -> StoreState
record event state = state {storeTraceRev = event : storeTraceRev state}

appendEvent :: MonadSTM m => SnapshotStore m -> Text -> m ()
appendEvent (SnapshotStore variable) event = atomically $ do
  state <- readTVar variable
  writeTVar variable (record event state)
