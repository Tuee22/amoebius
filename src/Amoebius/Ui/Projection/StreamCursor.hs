{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

module Amoebius.Ui.Projection.StreamCursor
  ( StreamCursor (..)
  , ProgramEpoch (..)
  , ScopeEpoch (..)
  , CursorError (..)
  , CursorStep (..)
  , advanceCursor
  ) where

import Codec.Serialise (Serialise)
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

newtype StreamCursor = StreamCursor {unStreamCursor :: Natural}
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (Serialise)

newtype ProgramEpoch = ProgramEpoch {unProgramEpoch :: Natural}
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (Serialise)

newtype ScopeEpoch = ScopeEpoch {unScopeEpoch :: Natural}
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (Serialise)

data CursorError
  = FirstCursorNotZero StreamCursor
  | CursorGap StreamCursor StreamCursor
  | CursorRegressed StreamCursor StreamCursor
  | ProgramEpochRegressed ProgramEpoch ProgramEpoch
  | ScopeEpochRegressed ScopeEpoch ScopeEpoch
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Serialise)

data CursorStep = CursorAdvanced | CursorRedelivery
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Serialise)

advanceCursor
  :: Maybe (StreamCursor, ProgramEpoch, ScopeEpoch)
  -> StreamCursor
  -> ProgramEpoch
  -> ScopeEpoch
  -> Either CursorError CursorStep
advanceCursor Nothing cursor _ _
  | cursor == StreamCursor 0 = Right CursorAdvanced
  | otherwise = Left (FirstCursorNotZero cursor)
advanceCursor (Just (previous, previousProgram, previousScope)) cursor program scope
  | program < previousProgram = Left (ProgramEpochRegressed previousProgram program)
  | scope < previousScope = Left (ScopeEpochRegressed previousScope scope)
  | cursor < previous = Left (CursorRegressed previous cursor)
  | cursor == previous = Right CursorRedelivery
  | cursor == next previous = Right CursorAdvanced
  | otherwise = Left (CursorGap previous cursor)
 where
  next (StreamCursor value) = StreamCursor (value + 1)
