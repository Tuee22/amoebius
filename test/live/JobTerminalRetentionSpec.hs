{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Data.Aeson (FromJSON (parseJSON), eitherDecodeFileStrict', withObject, (.:))
import Data.Text (Text)
import qualified Data.Text as Text
import System.Exit (die)

newtype Evidence = Evidence Job
data Job = Job Text Bool Int

instance FromJSON Evidence where
  parseJSON = withObject "Phase26Evidence" $ \value -> Evidence <$> value .: "job"

instance FromJSON Job where
  parseJSON = withObject "Job" $ \value ->
    Job <$> value .: "terminalPodUid" <*> value .: "retained" <*> value .: "completionObjects"

main :: IO ()
main = do
  decoded <- eitherDecodeFileStrict' "DEVELOPMENT_PLAN/evidence/phase_26/live-reconcile.json"
  case decoded of
    Left problem -> die problem
    Right (Evidence (Job uid retained completionObjects))
      | not (Text.null uid) && retained && completionObjects == 0 -> pure ()
      | otherwise -> die "terminal Job was not retained without a completion gateway object"
  putStrLn "job-terminal-retention: PASS (terminal Pod retained; completion gateway absent)"
