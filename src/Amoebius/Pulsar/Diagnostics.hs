{-# LANGUAGE OverloadedStrings #-}

-- | Pure observations of the native client's protocol encoder and decoder.
module Amoebius.Pulsar.Diagnostics (connectWireObservation) where

import Amoebius.Pulsar.Frame (FrameError, FrameSummary (..), connectFrameGolden, decodeFrameSummary)
import Data.ByteString qualified as ByteString
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric (showHex)

-- | Emit the actual connect frame and its decoded summary, without network I/O.
connectWireObservation :: Either FrameError Text
connectWireObservation = do
  bytes <- connectFrameGolden
  summary <- decodeFrameSummary bytes
  pure $ Text.unlines
    [ "connect\t" <> Text.pack (concatMap hex (ByteString.unpack bytes))
    , Text.intercalate "\t" ["decoded", Text.pack (summaryCommandType summary), Text.pack (show (summaryHasMetadata summary)), Text.pack (show (summaryPayloadBytes summary))]
    ]
 where
  hex byte = case showHex byte "" of [digit] -> ['0', digit]; digits -> digits
