{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Ui.Realtime.Envelope
  ( UiRealtimeEnvelope (..)
  , envelopeComplete
  ) where

import Data.Text (Text)
import qualified Data.Text as Text

data UiRealtimeEnvelope = UiRealtimeEnvelope
  { envelopeApplication :: Text
  , envelopeSession :: Text
  , envelopeSubjectEpoch :: Int
  , envelopeScope :: Text
  , envelopeScopeEpoch :: Int
  , envelopeProgram :: Text
  , envelopeAbi :: Text
  , envelopeStream :: Text
  , envelopeCursor :: Int
  }
  deriving stock (Eq, Show)

envelopeComplete :: UiRealtimeEnvelope -> Bool
envelopeComplete envelope =
  all (not . Text.null)
    [ envelopeApplication envelope
    , envelopeSession envelope
    , envelopeScope envelope
    , envelopeProgram envelope
    , envelopeAbi envelope
    , envelopeStream envelope
    ]
    && envelopeSubjectEpoch envelope >= 0
    && envelopeScopeEpoch envelope >= 0
    && envelopeCursor envelope >= 0
