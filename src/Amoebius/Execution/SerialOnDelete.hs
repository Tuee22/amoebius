{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

module Amoebius.Execution.SerialOnDelete
  ( SerialStage (..)
  , SerialObservation (..)
  , SerialAction (..)
  , SerialError (..)
  , planSerialAction
  ) where

import Control.DeepSeq (NFData)
import Data.Text (Text)
import GHC.Generics (Generic)

data SerialStage = DeletePredecessor | ObserveRelease | ObserveReplacement | SerialComplete
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data SerialObservation = SerialObservation
  { serialObservedFingerprint :: Text
  , serialExpectedFingerprint :: Text
  , serialSlot :: Text
  , serialPredecessorUid :: Maybe Text
  , serialPredecessorAbsent :: Bool
  , serialReplacementUid :: Maybe Text
  , serialReplacementBound :: Bool
  , serialReplacementReady :: Bool
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data SerialAction
  = DeleteOnePredecessor Text Text
  | ResumeController Text
  | AdvanceAfterReplacement Text Text
  | SerialNoOp
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data SerialError
  = SerialSnapshotChanged
  | SerialPredecessorNotObserved
  | SerialPredecessorStillPresent
  | SerialReplacementNotDistinct
  | SerialReplacementNotBoundReady
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

planSerialAction :: SerialStage -> SerialObservation -> Either SerialError SerialAction
planSerialAction stage observed = do
  if serialObservedFingerprint observed == serialExpectedFingerprint observed
    then Right ()
    else Left SerialSnapshotChanged
  case stage of
    DeletePredecessor -> case serialPredecessorUid observed of
      Just uid -> Right (DeleteOnePredecessor (serialSlot observed) uid)
      Nothing -> Left SerialPredecessorNotObserved
    ObserveRelease ->
      if serialPredecessorAbsent observed
        then Right (ResumeController (serialSlot observed))
        else Left SerialPredecessorStillPresent
    ObserveReplacement -> case (serialPredecessorUid observed, serialReplacementUid observed) of
      (Just old, Just new)
        | old == new -> Left SerialReplacementNotDistinct
        | not (serialReplacementBound observed && serialReplacementReady observed) -> Left SerialReplacementNotBoundReady
        | otherwise -> Right (AdvanceAfterReplacement (serialSlot observed) new)
      _ -> Left SerialReplacementNotBoundReady
    SerialComplete -> Right SerialNoOp
