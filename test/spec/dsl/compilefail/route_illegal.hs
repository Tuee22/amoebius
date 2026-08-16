{-# LANGUAGE GHC2024 #-}

module Fixture where

import Amoebius.Dsl.Foreclosure
import Data.Text qualified as Text

service = mkServiceHandle ServiceAbsentToken (Text.pack "api")
route = routeFromService service
