module Amoebius.Ui.Realtime.Class
  ( UiRealtimeCoordination (..)
  ) where

import Amoebius.Ui.Realtime.Envelope (UiRealtimeEnvelope)

class Monad operation => UiRealtimeCoordination operation where
  registerConnection :: UiRealtimeEnvelope -> operation ()
  publishRoutingHint :: UiRealtimeEnvelope -> operation ()
