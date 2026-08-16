{-# LANGUAGE GHC2024 #-}

module Fixture where

import Amoebius.Dsl.Ref
import Data.Text qualified as Text

left = mkRef TenantAlphaToken (Text.pack "left")
right = mkRef TenantAlphaToken (Text.pack "right")
pair = sameTenant left right
