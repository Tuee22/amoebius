module Amoebius.Sim.Fakes.Pulsar
  ( PulsarFaults (..)
  , PulsarState
  , emptyPulsar
  , publish
  , consume
  , heal
  ) where

import Amoebius.Sim.Env (Message (..), MessageId (..))
import Data.List (nubBy)
import Data.Text (Text)

data PulsarFaults = PulsarFaults
  { pulsarPartitioned :: Bool
  , pulsarReorder :: Bool
  , pulsarDuplicate :: Bool
  }
  deriving stock (Eq, Show)

data PulsarState = PulsarState
  { nextId :: Int
  , queued :: [Message]
  , faults :: PulsarFaults
  }
  deriving stock (Eq, Show)

emptyPulsar :: PulsarFaults -> PulsarState
emptyPulsar = PulsarState 1 []

publish :: Text -> PulsarState -> (Message, Bool, PulsarState)
publish payload state =
  let message = Message (MessageId (nextId state)) payload
      state' = state {nextId = nextId state + 1, queued = queued state <> [message]}
   in (message, pulsarPartitioned (faults state), state')

consume :: PulsarState -> ([Message], [MessageId], PulsarState)
consume state
  | pulsarPartitioned (faults state) = ([], [], state)
  | otherwise =
      let ordered = if pulsarReorder (faults state) then reverse (queued state) else queued state
          wire = if pulsarDuplicate (faults state) then concatMap (\message -> [message, message]) ordered else ordered
          delivered = nubBy (\left right -> messageId left == messageId right) wire
          dropped = duplicateIds wire
       in (delivered, dropped, state {queued = []})

heal :: PulsarState -> PulsarState
heal state = state {faults = (faults state) {pulsarPartitioned = False}}

duplicateIds :: [Message] -> [MessageId]
duplicateIds = go []
  where
    go _ [] = []
    go seen (message : rest)
      | messageId message `elem` seen = messageId message : go seen rest
      | otherwise = go (messageId message : seen) rest
