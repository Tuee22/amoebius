{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Sim.Interp.Sim
  ( FaultSchedule (..)
  , SimHandle (..)
  , activeFaults
  , newSimEnv
  , newIOSimEnv
  ) where

import Amoebius.Sim.Env
import qualified Amoebius.Sim.Fakes.ApiServer as Api
import qualified Amoebius.Sim.Fakes.Clock as Clock
import qualified Amoebius.Sim.Fakes.MinIO as MinIO
import qualified Amoebius.Sim.Fakes.Pulsar as Pulsar
import qualified Amoebius.Sim.Fakes.Route53 as Route53
import qualified Amoebius.Sim.Fakes.Vault as Vault
import Control.Concurrent.Class.MonadSTM
  ( MonadSTM
  , TVar
  , atomically
  , newTVarIO
  , readTVar
  , readTVarIO
  , writeTVar
  )
import Control.Monad.Class.MonadTime (MonadTime, getCurrentTime)
import Control.Monad.Class.MonadTimer (MonadDelay, threadDelay)
import Control.Monad.IOSim (IOSim)
import Data.Aeson (FromJSON, ToJSON)
import Data.Text (Text)
import GHC.Generics (Generic)

data FaultSchedule = FaultSchedule
  { scheduleName :: Text
  , scheduleSeed :: Int
  , schedulePartition :: Bool
  , scheduleRedelivery :: Bool
  , scheduleReorder :: Bool
  , scheduleDuplicate :: Bool
  , scheduleCrash :: Bool
  , scheduleDnsDelay :: Int
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (FromJSON, ToJSON)

activeFaults :: FaultSchedule -> [FaultKnob]
activeFaults schedule =
  concat
    [ [Partition | schedulePartition schedule]
    , [Duplicate | scheduleRedelivery schedule || scheduleDuplicate schedule]
    , [Reorder | scheduleReorder schedule]
    , [Crash | scheduleCrash schedule]
    , [Delay | scheduleDnsDelay schedule > 0]
    ]

data World = World
  { worldPulsar :: Pulsar.PulsarState
  , worldMinIO :: MinIO.MinIOState
  , worldApi :: Api.ApiServerState
  , worldRoute53 :: Route53.Route53State
  , worldVault :: Vault.VaultState
  , worldClock :: Clock.ClockState
  , worldTraceRev :: [TraceEvent]
  }

data SimHandle m = SimHandle
  { simEnv :: Env m
  , simReadTrace :: m [TraceEvent]
  }

newIOSimEnv :: FaultSchedule -> IOSim s (SimHandle (IOSim s))
newIOSimEnv = newSimEnv

newSimEnv :: (MonadSTM m, MonadDelay m, MonadTime m) => FaultSchedule -> m (SimHandle m)
newSimEnv schedule = do
  worldVar <- newTVarIO initialWorld
  pure
    SimHandle
      { simEnv = mkEnv worldVar
      , simReadTrace = reverse . worldTraceRev <$> readTVarIO worldVar
      }
  where
    initialWorld =
      World
        { worldPulsar =
            Pulsar.emptyPulsar
              Pulsar.PulsarFaults
                { Pulsar.pulsarPartitioned = schedulePartition schedule
                , Pulsar.pulsarReorder = scheduleReorder schedule || odd (scheduleSeed schedule)
                , Pulsar.pulsarDuplicate = scheduleRedelivery schedule || scheduleDuplicate schedule
                }
        , worldMinIO = MinIO.emptyMinIO
        , worldApi =
            Api.emptyApiServer
              Api.ApiFaults
                { Api.apiCrashOnce = scheduleCrash schedule
                , Api.apiWatchFloor = ResourceVersion 2
                }
        , worldRoute53 =
            Route53.seedDns (DnsName "service.example") (DnsValue "old")
              (Route53.emptyRoute53 (scheduleDnsDelay schedule))
        , worldVault = Vault.emptyVault False
        , worldClock = Clock.emptyClock
        , worldTraceRev = []
        }

mkEnv :: (MonadSTM m, MonadDelay m, MonadTime m) => TVar m World -> Env m
mkEnv worldVar =
  Env
    { envPublish = \_ payload -> transition worldVar $ \world ->
        let (message, partitioned, pulsar') = Pulsar.publish payload (worldPulsar world)
            event = if partitioned then PublishPartitioned message else Published message
         in (messageId message, [event], world {worldPulsar = pulsar'})
    , envConsume = \_ -> transition worldVar $ \world ->
        let (messages, dropped, pulsar') = Pulsar.consume (worldPulsar world)
            event = if null messages && null dropped then [ConsumePartitioned] else Consumed (map messageId messages) : map DuplicateDropped dropped
         in (messages, event, world {worldPulsar = pulsar'})
    , envPutBlob = \condition key value -> transition worldVar $ \world ->
        let (result, minio') = MinIO.putBlob condition key value (worldMinIO world)
         in (result, [BlobPut key result], world {worldMinIO = minio'})
    , envGetBlob = \key -> transition worldVar $ \world ->
        let result = MinIO.getBlob key (worldMinIO world)
         in (result, [BlobGot key result], world)
    , envApplyObject = \name version body -> transition worldVar $ \world ->
        let (result, api') = Api.applyObject name version body (worldApi world)
         in (result, [ObjectApply name result], world {worldApi = api'})
    , envWatchObjects = \version -> transition worldVar $ \world ->
        let result = Api.watchObjects version (worldApi world)
         in (result, [ObjectWatch version result], world)
    , envWriteDns = \name value -> transition worldVar $ \world ->
        let route53' = Route53.writeDns name value (worldRoute53 world)
         in (DnsWritten, [DnsWrite name value], world {worldRoute53 = route53'})
    , envReadDns = \name -> transition worldVar $ \world ->
        let result = Route53.readDns name (worldRoute53 world)
         in (result, [DnsRead name result], world)
    , envVaultOp = \operation -> transition worldVar $ \world ->
        let (result, vault') = Vault.runVaultOp operation (worldVault world)
         in (result, [VaultOperation operation result], world {worldVault = vault'})
    , envNow = do
        current <- getCurrentTime
        appendTrace worldVar ClockRead
        pure current
    , envDelay = \micros -> do
        threadDelay micros
        atomically $ do
          world <- readTVar worldVar
          let clock' = Clock.advanceClock micros (worldClock world)
              route53' = Route53.advanceDns micros (worldRoute53 world)
              pulsar' = Pulsar.heal (worldPulsar world)
          writeTVar worldVar (addEvents [Delayed micros] world {worldClock = clock', worldRoute53 = route53', worldPulsar = pulsar'})
    }

transition
  :: MonadSTM m
  => TVar m World
  -> (World -> (value, [TraceEvent], World))
  -> m value
transition worldVar step = atomically $ do
  world <- readTVar worldVar
  let (value, events, world') = step world
  writeTVar worldVar (addEvents events world')
  pure value

appendTrace :: MonadSTM m => TVar m World -> TraceEvent -> m ()
appendTrace worldVar event = atomically $ do
  world <- readTVar worldVar
  writeTVar worldVar (addEvents [event] world)

addEvents :: [TraceEvent] -> World -> World
addEvents events world = world {worldTraceRev = reverse events <> worldTraceRev world}
