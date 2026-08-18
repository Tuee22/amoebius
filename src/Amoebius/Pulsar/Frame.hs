module Amoebius.Pulsar.Frame
  ( FrameError (..)
  , FrameSummary (..)
  , frameMaxSize
  , connectFrameGolden
  , decodeFrameSummary
  ) where

import Amoebius.Pulsar.Internal.Frame (FrameError (..), decodeWireFrame, encodeSimple, frameMaxSize)
import Amoebius.Pulsar.Internal.Protocol (commandConnect)
import Amoebius.Pulsar.Internal.Types (WireFrame (..))
import Proto.PulsarApi_Fields qualified as F
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Lens.Family ((^.))

data FrameSummary = FrameSummary
  { summaryCommandType :: String
  , summaryHasMetadata :: Bool
  , summaryPayloadBytes :: Int
  }
  deriving stock (Eq, Show)

connectFrameGolden :: Either FrameError ByteString
connectFrameGolden = encodeSimple commandConnect

decodeFrameSummary :: ByteString -> Either FrameError FrameSummary
decodeFrameSummary bytes = do
  frame <- decodeWireFrame bytes
  pure
    FrameSummary
      { summaryCommandType = show (wireCommand frame ^. F.type')
      , summaryHasMetadata = maybe False (const True) (wireMetadata frame)
      , summaryPayloadBytes = maybe 0 ByteString.length (wirePayload frame)
      }
