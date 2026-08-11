{-# LANGUAGE CPP #-}

module Amoebius.Pulumi.Engine
  ( PulumiExecutorDemand (..)
  , PulumiExecutionDemand
  , ExecutionDemandError (..)
  , ExecutionSupply (..)
  , ProvisionedPulumiExecutionDemand
  , boundedExecutionDemand
  , provisionExecutionDemand
  , executionCpuMilli
  , executionMemoryBytes
  , executionPodEphemeralBytes
  , executionPluginCacheBytes
  , executionWorkspaceBytes
  , executionLiveSet
  , SingletonContext
  , EngineError (..)
  , admitSingletonContext
  , EngineInvocation
  , preparePulumiUp
  , invocationArgv
  , invocationEnvironment
  , invocationPluginPath
  ) where

data PulumiExecutorDemand = PulumiExecutorDemand
  { executorCpuMilli :: Integer
  , executorMemoryBytes :: Integer
  , executorPodEphemeralBytes :: Integer
  , executorPluginCacheBytes :: Integer
  , executorWorkspaceBytes :: Integer
  }
  deriving stock (Eq, Show)

data PulumiExecutionDemand = PulumiExecutionDemand
  { executionCpuMilli :: Integer
  , executionMemoryBytes :: Integer
  , executionPodEphemeralBytes :: Integer
  , executionPluginCacheBytes :: Integer
  , executionWorkspaceBytes :: Integer
  , executionLiveSet :: Int
  }
  deriving stock (Eq, Show)

data ExecutionDemandError
  = EmptyExecutorGraph
  | InvalidParallelCeiling
  | NegativeExecutorDemand
  | ExecutorCpuShort
  | ExecutorMemoryShort
  | ExecutorPodEphemeralShort
  | PluginCacheShort
  | WorkspaceShort
  deriving stock (Eq, Show)

data ExecutionSupply = ExecutionSupply
  { supplyCpuMilli :: Integer
  , supplyMemoryBytes :: Integer
  , supplyPodEphemeralBytes :: Integer
  , supplyPluginCacheBytes :: Integer
  , supplyWorkspaceBytes :: Integer
  }
  deriving stock (Eq, Show)

-- The constructor is deliberately private.  Continuations that can enact a
-- provider operation accept this seal, never an unprovisioned demand.
newtype ProvisionedPulumiExecutionDemand = ProvisionedPulumiExecutionDemand PulumiExecutionDemand
  deriving stock (Eq, Show)

boundedExecutionDemand
  :: Int
  -> [PulumiExecutorDemand]
  -> Either ExecutionDemandError PulumiExecutionDemand
boundedExecutionDemand parallelLimit executors
  | null executors = Left EmptyExecutorGraph
  | parallelLimit <= 0 = Left InvalidParallelCeiling
  | any invalid executors = Left NegativeExecutorDemand
  | otherwise =
#ifdef PHASE44_DROP_PARALLEL_EXECUTOR_MUTANT
      aggregate (take 1 executors)
#else
      aggregate (take parallelLimit executors)
#endif
 where
  aggregate live =
    Right PulumiExecutionDemand
      { executionCpuMilli = sum (map executorCpuMilli live)
      , executionMemoryBytes = sum (map executorMemoryBytes live)
      , executionPodEphemeralBytes = sum (map executorPodEphemeralBytes live)
      , executionPluginCacheBytes = sum (map executorPluginCacheBytes live)
      , executionWorkspaceBytes = sum (map executorWorkspaceBytes live)
      , executionLiveSet = length live
      }
  invalid demand =
    any (< 0)
      [ executorCpuMilli demand
      , executorMemoryBytes demand
      , executorPodEphemeralBytes demand
      , executorPluginCacheBytes demand
      , executorWorkspaceBytes demand
      ]

provisionExecutionDemand
  :: ExecutionSupply
  -> PulumiExecutionDemand
  -> Either ExecutionDemandError ProvisionedPulumiExecutionDemand
provisionExecutionDemand supply demand
  | supplyCpuMilli supply < executionCpuMilli demand = Left ExecutorCpuShort
  | supplyMemoryBytes supply < executionMemoryBytes demand = Left ExecutorMemoryShort
  | supplyPodEphemeralBytes supply < executionPodEphemeralBytes demand = Left ExecutorPodEphemeralShort
  | supplyPluginCacheBytes supply < executionPluginCacheBytes demand = Left PluginCacheShort
  | supplyWorkspaceBytes supply < executionWorkspaceBytes demand = Left WorkspaceShort
  | otherwise = Right (ProvisionedPulumiExecutionDemand demand)

newtype SingletonContext = SingletonContext String
  deriving stock (Eq, Show)

data EngineError
  = NoSingletonContext
  | SingletonReplicaCountNotOne
  | PulumiPathNotAbsolute
  | PluginPathNotAbsolute
  | EmptyStackName
  deriving stock (Eq, Show)

admitSingletonContext :: String -> Int -> Either EngineError SingletonContext
admitSingletonContext serviceAccount replicas
  | null serviceAccount = Left NoSingletonContext
  | replicas /= 1 = Left SingletonReplicaCountNotOne
  | otherwise = Right (SingletonContext serviceAccount)

data EngineInvocation = EngineInvocation
  { invocationArgv :: [String]
  , invocationEnvironment :: [(String, String)]
  , invocationPluginPath :: FilePath
  }
  deriving stock (Eq, Show)

preparePulumiUp
  :: SingletonContext
  -> FilePath
  -> FilePath
  -> String
  -> Either EngineError EngineInvocation
preparePulumiUp _ pulumiPath pluginPath stack
  | not (absolute pulumiPath) = Left PulumiPathNotAbsolute
  | not (absolute pluginPath) = Left PluginPathNotAbsolute
  | null stack = Left EmptyStackName
  | otherwise =
      Right EngineInvocation
        { invocationArgv = [pulumiPath, "up", "--yes", "--non-interactive", "--stack", stack]
#ifdef PHASE44_LEAK_PATH_MUTANT
        , invocationEnvironment = [("PATH", "/usr/local/bin:/usr/bin:/bin")]
#else
        , invocationEnvironment = []
#endif
        , invocationPluginPath = pluginPath
        }
 where
  absolute ('/' : _) = True
  absolute _ = False
