{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Data.Aeson (FromJSON (parseJSON), eitherDecodeFileStrict', withObject, (.:))
import Data.Text (Text)
import qualified Data.Text as Text
import System.Environment (getArgs)
import System.Exit (die)

newtype Evidence = Evidence Job
data Job = Job Text Bool Int

instance FromJSON Evidence where
  parseJSON = withObject "Phase26Evidence" $ \value -> Evidence <$> value .: "job"

instance FromJSON Job where
  parseJSON = withObject "Job" $ \value ->
    Job <$> value .: "terminalPodUid" <*> value .: "retained" <*> value .: "completionObjects"

-- The evidence path is the sole argument, supplied by the gate through
-- `--test-options`. A constant here named a plan-tree directory that no longer exists, and
-- a suite reading a fixed location decides on whatever a previous run left behind.
main :: IO ()
main = do
  arguments <- getArgs
  evidence <- case arguments of
    [path] -> pure path
    _ -> die "usage: <suite> <live-reconcile.json>; the gate supplies this run's bundle path"
  decoded <- eitherDecodeFileStrict' evidence
  case decoded of
    Left problem -> die problem
    Right (Evidence (Job uid retained completionObjects))
      | not (Text.null uid) && retained && completionObjects == 0 -> pure ()
      | otherwise -> die "terminal Job was not retained without a completion gateway object"
  putStrLn "job-terminal-retention: PASS (terminal Pod retained; completion gateway absent)"
