{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Dsl.Error
  ( DecodeError (..)
  , decodeErrorTag
  ) where

import Control.DeepSeq (NFData)
import Data.Text (Text)
import GHC.Generics (Generic)

-- | Stable Gate-2 failure classes.  The constructors are deliberately
-- distinct: callers and the negative corpus must not collapse refinement
-- failures into a generic parse error.
data DecodeError
  = SchemaMismatch Text
  | OutOfDomainArm Text
  | UnspellableCombination Text
  | ForbiddenImport Text
  | MalformedPayload Text
  | DhallFailure Text
  | StrictnessFailure Text
  | UnbuiltProviderArm Text
  | UnboundCapability Text
  | CyclicExtension Text
  | ShadowingExtension Text
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

decodeErrorTag :: DecodeError -> Text
decodeErrorTag decodeError = case decodeError of
  SchemaMismatch _ -> "SchemaMismatch"
  OutOfDomainArm _ -> "OutOfDomainArm"
  UnspellableCombination _ -> "UnspellableCombination"
  ForbiddenImport _ -> "ForbiddenImport"
  MalformedPayload _ -> "MalformedPayload"
  DhallFailure _ -> "DhallFailure"
  StrictnessFailure _ -> "StrictnessFailure"
  UnbuiltProviderArm _ -> "UnbuiltProviderArm"
  UnboundCapability _ -> "UnboundCapability"
  CyclicExtension _ -> "CyclicExtension"
  ShadowingExtension _ -> "ShadowingExtension"
