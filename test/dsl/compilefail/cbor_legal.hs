{-# LANGUAGE GHC2024 #-}

module Fixture where

import Amoebius.Dsl.Foreclosure
import Data.Text qualified as Text

payload = mkMessagePayload CborPayloadToken (Text.pack "event")
produced = produceTypedCbor payload
