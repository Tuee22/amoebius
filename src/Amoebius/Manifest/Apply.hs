{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Manifest.Apply
  ( SsaPatch (..)
  , ApplyError (..)
  , prepareScopedSsa
  ) where

import Amoebius.Manifest.Actions
import Control.DeepSeq (NFData)
import Data.Map.Strict (Map)
import Data.Text (Text)
import GHC.Generics (Generic)

data SsaPatch = SsaPatch
  { ssaFieldManager :: Text
  , ssaOwnedFields :: Map Text Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ApplyError
  = ActionCannotUseGenericSsa ActionKind
  | EmptyOwnedFieldSet
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

prepareScopedSsa
  :: ValidatedExecutionTransitionAction
  -> Map Text Text
  -> Either ApplyError SsaPatch
prepareScopedSsa action fields
  | not (actionCanUseGenericSsa action) = Left (ActionCannotUseGenericSsa (actionKind action))
  | null fields = Left EmptyOwnedFieldSet
  | otherwise = Right (SsaPatch "amoebius" fields)
