module Main (main) where

import Control.Concurrent.Class.MonadSTM.Strict
import Control.Monad (void)
import Control.Monad.Class.MonadFork (forkIO)
import Control.Monad.IOSim
  ( IOSim
  , ScheduleControl (ControlDefault)
  , controlSimTrace
  , traceResult
  )
import System.Environment (getArgs)
import System.Exit (die)

schedule :: Bool -> IOSim s Int
schedule perturbed = do
  total <- newTVarIO (0 :: Int)
  firstDone <- newEmptyTMVarIO
  secondDone <- newEmptyTMVarIO
  void . forkIO $ atomically $ modifyTVar total (+ 1) >> putTMVar firstDone ()
  void . forkIO $ atomically $ do
    if perturbed then pure () else modifyTVar total (+ 2)
    putTMVar secondDone ()
  atomically $ takeTMVar firstDone >> takeTMVar secondDone >> readTVar total

main :: IO ()
main = do
  arguments <- getArgs
  perturbed <- case arguments of
    [] -> pure False
    ["--perturbed"] -> pure True
    _ -> die "usage: sim [--perturbed]"
  case traceResult True (controlSimTrace Nothing ControlDefault (schedule perturbed)) of
    Left failure -> die (show failure)
    Right terminal -> putStrLn ("schedule=two-writer-fair;terminal=" <> show terminal)
