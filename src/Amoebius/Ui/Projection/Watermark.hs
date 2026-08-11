{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

module Amoebius.Ui.Projection.Watermark
  ( Watermark (..)
  , ResumeDecision (..)
  , resumeFrom
  ) where

import Amoebius.Ui.Projection.StreamCursor
import Codec.Serialise (Serialise)
import GHC.Generics (Generic)

data Watermark = Watermark
  { watermarkCursor :: StreamCursor
  , watermarkProgramEpoch :: ProgramEpoch
  , watermarkScopeEpoch :: ScopeEpoch
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Serialise)

data ResumeDecision
  = ResumeCaughtUp
  | ResumeReplayAfter StreamCursor
  | ResumeEpochRejected
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Serialise)

resumeFrom :: Watermark -> StreamCursor -> ProgramEpoch -> ScopeEpoch -> ResumeDecision
resumeFrom watermark cursor program scope
  | program /= watermarkProgramEpoch watermark = ResumeEpochRejected
  | scope /= watermarkScopeEpoch watermark = ResumeEpochRejected
  | cursor >= watermarkCursor watermark = ResumeCaughtUp
  | otherwise = ResumeReplayAfter cursor
