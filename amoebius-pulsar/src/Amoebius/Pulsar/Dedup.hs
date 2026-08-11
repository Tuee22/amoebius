{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Pulsar.Dedup
  ( WorkId (..)
  , SequenceError (..)
  , sequenceFromMessage
  , requestScopedIdentity
  , DedupState
  , emptyDedupState
  , applyOnce
  , appliedWorkIds
  ) where

import Data.Bits ((.&.), (.|.), shiftL, xor)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text.Encoding qualified as Text
import Data.Word (Word64, Word8)

newtype WorkId = WorkId Text
  deriving stock (Eq, Ord, Show)

data SequenceError = LedgerOrEntryExceeds32Bits
  deriving stock (Eq, Show)

sequenceFromMessage :: Word64 -> Word64 -> Either SequenceError Word64
sequenceFromMessage ledger entry
  | ledger > 0xffffffff || entry > 0xffffffff = Left LedgerOrEntryExceeds32Bits
  | otherwise = Right ((ledger `shiftL` 32) .|. entry)

requestScopedIdentity :: Text -> (Text, Word64)
requestScopedIdentity requestId = ("amoebius-request-" <> requestId, fnv1a64 (Text.encodeUtf8 requestId))

newtype DedupState = DedupState (Set WorkId)
  deriving stock (Eq, Show)

emptyDedupState :: DedupState
emptyDedupState = DedupState Set.empty

applyOnce :: WorkId -> DedupState -> (Bool, DedupState)
applyOnce work state@(DedupState applied)
  | work `Set.member` applied = (False, state)
  | otherwise = (True, DedupState (Set.insert work applied))

appliedWorkIds :: DedupState -> Set WorkId
appliedWorkIds (DedupState applied) = applied

fnv1a64 :: ByteString -> Word64
fnv1a64 = foldl step 14695981039346656037 . ByteString.unpack
  where
    step :: Word64 -> Word8 -> Word64
    step hash byte = ((hash `xor` fromIntegral byte) * 1099511628211) .&. maxBound
