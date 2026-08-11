module Amoebius.HostWorker.Lifecycle
  ( LifecycleStep (..)
  , WorkerActions (..)
  , runWorkerLifecycle
  ) where

import Control.Exception (finally, onException)

data LifecycleStep = Load | Prereq | Acquire | Ready | Serve | Drain | Exit
  deriving stock (Eq, Ord, Show, Enum, Bounded)

data WorkerActions resource = WorkerActions
  { workerLoad :: IO ()
  , workerPrereq :: IO ()
  , workerAcquire :: IO resource
  , workerReady :: resource -> IO ()
  , workerServe :: resource -> IO ()
  , workerDrain :: resource -> IO ()
  , workerExit :: IO ()
  }

-- | Prerequisites precede acquisition. Once acquired, Drain is guaranteed even
-- when Ready or Serve throws, and Exit is guaranteed after the drain attempt.
runWorkerLifecycle :: WorkerActions resource -> IO ()
runWorkerLifecycle actions = do
  workerLoad actions
  workerPrereq actions
  resource <- workerAcquire actions
  let use = workerReady actions resource >> workerServe actions resource
      release = workerDrain actions resource `finally` workerExit actions
  use `onException` release
  release
