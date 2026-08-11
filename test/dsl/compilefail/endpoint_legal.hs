{-# LANGUAGE GHC2024 #-}

module Fixture where

import Amoebius.Dsl.Foreclosure
import Data.Text qualified as Text

endpoint = mkEndpoint WildIngressToken (Text.pack "edge")
wild :: Endpoint 'WildIngress
wild = endpoint
