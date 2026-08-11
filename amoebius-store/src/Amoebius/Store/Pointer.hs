{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Store.Pointer
  ( PointerName (..)
  , PointerHead
  , pointerHead
  , pointerHeadBytes
  , PointerDecision (..)
  , AdvancePredicate (..)
  , decideAdvance
  , pointerKey
  ) where

import Amoebius.Store.ContentAddress
import Data.ByteString (ByteString)
import Data.Text (Text)

newtype PointerName = PointerName Text
  deriving stock (Eq, Ord, Show)

newtype PointerHead = PointerHead ContentDigest
  deriving stock (Eq, Ord, Show)

pointerHead :: ContentDigest -> PointerHead
pointerHead = PointerHead

pointerHeadBytes :: PointerHead -> ByteString
pointerHeadBytes (PointerHead digest) = digestBytes digest

data AdvancePredicate = SameOrLexicographicallyGreater
  deriving stock (Eq, Show)

data PointerDecision
  = PointerWrite PointerHead
  | PointerAlreadyCommitted PointerHead
  | PointerAdvanceRejected PointerHead PointerHead
  deriving stock (Eq, Show)

decideAdvance :: AdvancePredicate -> Maybe PointerHead -> PointerHead -> PointerDecision
decideAdvance SameOrLexicographicallyGreater current candidate = case current of
  Nothing -> PointerWrite candidate
  Just existing
    | existing == candidate -> PointerAlreadyCommitted existing
    | candidate > existing -> PointerWrite candidate
    | otherwise -> PointerAdvanceRejected existing candidate

pointerKey :: Text -> PointerName -> Text
pointerKey namespace (PointerName name) = namespace <> "/pointers/" <> name
