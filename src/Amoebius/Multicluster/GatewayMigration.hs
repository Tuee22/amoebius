module Amoebius.Multicluster.GatewayMigration
  ( MigrationTrace (..)
  , MigrationDemand (..)
  , MigrationCapacityError (..)
  , representativeMigrationDemand
  , validateMigrationDemand
  , runModelTrace
  , traceSatisfiesNamedInvariants
  ) where

import Amoebius.Formal.GatewayMigration (gatewayMigrationModel)
import Amoebius.Formal.Interpret (evalExpr, initialState, interpret, valueAsBool)
import Amoebius.Formal.Model (Event (..), Model (..), NamedExpr (..), State, Value (IntValue))
import Data.Map.Strict qualified as Map

data MigrationTrace = MigrationTrace
  { migrationActions :: [String]
  , migrationStates :: [State]
  }
  deriving stock (Eq, Show)

data MigrationDemand = MigrationDemand
  { migrationCpuMilli :: Int
  , migrationMemoryBytes :: Integer
  , migrationPodEphemeralBytes :: Integer
  , migrationCheckpointBytes :: Integer
  , migrationEtcdBytes :: Integer
  , migrationExternalJournalBytes :: Integer
  , migrationNetworkQueueBytes :: Integer
  , migrationApiObjects :: Int
  , migrationPulumiExecutorLiveSet :: Int
  , migrationHostProcessSlots :: Int
  }
  deriving stock (Eq, Show)

data MigrationCapacityError
  = MigrationCpuShort
  | MigrationMemoryShort
  | MigrationPodEphemeralShort
  | MigrationCheckpointShort
  | MigrationEtcdShort
  | MigrationExternalJournalShort
  | MigrationNetworkQueueShort
  | MigrationApiObjectShort
  | MigrationPulumiExecutorShort
  | MigrationHostProcessSlotShort
  deriving stock (Eq, Show)

representativeMigrationDemand :: MigrationDemand
representativeMigrationDemand = MigrationDemand
  { migrationCpuMilli = 3000
  , migrationMemoryBytes = 3221225472
  , migrationPodEphemeralBytes = 536870912
  , migrationCheckpointBytes = 24576
  , migrationEtcdBytes = 65536
  , migrationExternalJournalBytes = 16384
  , migrationNetworkQueueBytes = 262144
  , migrationApiObjects = 24
  , migrationPulumiExecutorLiveSet = 1
  , migrationHostProcessSlots = 8
  }

validateMigrationDemand :: MigrationDemand -> MigrationDemand -> Either MigrationCapacityError ()
validateMigrationDemand supply demand
  | migrationCpuMilli supply < migrationCpuMilli demand = Left MigrationCpuShort
  | migrationMemoryBytes supply < migrationMemoryBytes demand = Left MigrationMemoryShort
  | migrationPodEphemeralBytes supply < migrationPodEphemeralBytes demand = Left MigrationPodEphemeralShort
  | migrationCheckpointBytes supply < migrationCheckpointBytes demand = Left MigrationCheckpointShort
  | migrationEtcdBytes supply < migrationEtcdBytes demand = Left MigrationEtcdShort
  | migrationExternalJournalBytes supply < migrationExternalJournalBytes demand = Left MigrationExternalJournalShort
  | migrationNetworkQueueBytes supply < migrationNetworkQueueBytes demand = Left MigrationNetworkQueueShort
  | migrationApiObjects supply < migrationApiObjects demand = Left MigrationApiObjectShort
  | migrationPulumiExecutorLiveSet supply < migrationPulumiExecutorLiveSet demand = Left MigrationPulumiExecutorShort
  | migrationHostProcessSlots supply < migrationHostProcessSlots demand = Left MigrationHostProcessSlotShort
  | otherwise = Right ()

runModelTrace :: [String] -> Either String MigrationTrace
runModelTrace names = do
  initial <- initialState gatewayMigrationModel
  let start = seedForTrace names initial
  (states, _) <- foldl apply (Right ([start], start)) names
  pure (MigrationTrace names states)
 where
  apply accumulator name = do
    (states, state) <- accumulator
    next <- maybe (Left ("illegal model edge: " <> name)) Right
      (interpret gatewayMigrationModel (Event name []) state)
    pure (states <> [next], next)

  seedForTrace ("StartPlanned" : _) =
    Map.insert "committed" (IntValue 2)
      . Map.insert "sourceLog" (IntValue 2)
      . Map.insert "targetLog" (IntValue 2)
  seedForTrace ("ActiveCrash" : _) =
    Map.insert "committed" (IntValue 2)
      . Map.insert "sourceLog" (IntValue 2)
      . Map.insert "targetLog" (IntValue 1)
  seedForTrace _ = id

traceSatisfiesNamedInvariants :: MigrationTrace -> Either String [(String, Bool)]
traceSatisfiesNamedInvariants trace =
  traverse check (modelInvariants gatewayMigrationModel)
 where
  check named = do
    verdicts <- traverse (evaluate named) (migrationStates trace)
    pure (namedExprName named, and verdicts)
  evaluate named state =
    evalExpr gatewayMigrationModel Map.empty state (namedExprBody named) >>= valueAsBool
