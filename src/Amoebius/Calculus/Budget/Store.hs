{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | The store a reservation is spent into, and the staging rule that keeps a refusal from
-- becoming a partial artifact.
--
-- 'jit_budget_doctrine.md' section 4 states the rule in one sentence: an artifact is
-- written to a staging location and moved into its address only once its rendering has
-- completed. The reason it is stated at all is that section 7 admits one refusal that
-- cannot happen at admission — a recipe that exceeds its /own/ declared worst case is
-- discovered mid-write — and without the staging rule that refusal would leave bytes at
-- an address a consumer can name, which is the single state content addressing cannot
-- tolerate ('jit_artifact_doctrine.md' section 4).
--
-- 'materializeUnder' therefore returns the store on both paths rather than only on
-- success. That is deliberate and it is what makes the claim checkable: a signature
-- returning no store on the refusal path would make \"the store is unchanged\" true by
-- construction, and a property true by construction cannot be broken by a seeded mutant,
-- which means nothing would be holding it.
--
-- What is placed arrives as a 'Placement' — an address and the content it names — rather
-- than as a recipe and a declaration. The budget calculus does not depend on the artifact
-- calculus: a grant authorises bytes, and how those bytes got their name is the other
-- calculus's question. The two meet at the point of use, which is where the Phase-4 suite
-- builds each placement out of a Phase-3 rendering and its address.
module Amoebius.Calculus.Budget.Store
  ( Placement
  , placement
  , placementAddress
  , placementContent
  , Store
  , emptyStore
  , storeCommitted
  , storeStaging
  , storeImage
  , storeImageHex
  , materializeUnder
  ) where

import Amoebius.Calculus.Budget.Admission
  ( Refusal (DeclarationExceeded)
  , Reservation
  , reservationBytes
  )
import Amoebius.Calculus.Budget.Grant (Bytes (..))
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Builder qualified as Builder
import Data.ByteString.Lazy qualified as Lazy
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import Numeric (showHex)

-- | An address and the content it names. Both come from the caller, because deriving the
-- one from the other is the artifact calculus's job and doing it again here would be a
-- second rendering of the same fold.
data Placement = Placement
  { placementAddress :: Text
  , placementContent :: ByteString
  }
  deriving stock (Eq, Ord, Show)

placement :: Text -> ByteString -> Placement
placement = Placement

-- | Committed content, keyed by address, beside whatever is mid-flight.
--
-- Staging is part of the store rather than beside it, because \"the store is byte
-- identical\" has to mean the whole of it: a refusal that left staging garbage behind
-- would still be a refusal that cost something, and section 5 says the abandoned bytes
-- are reaped as ordinary ephemeral garbage rather than left for someone to notice.
data Store = Store
  { storeCommitted :: Map Text ByteString
  , storeStaging :: Map Text ByteString
  }
  deriving stock (Eq, Ord, Show)

emptyStore :: Store
emptyStore = Store {storeCommitted = Map.empty, storeStaging = Map.empty}

-- | The store's canonical bytes: every committed entry then every staged one, each
-- length-prefixed so no concatenation is ambiguous, in address order.
--
-- This is what \"byte-identical to its prior state\" is checked over. Comparing two stores
-- with 'Eq' settles the same question in process; the image exists so the claim can also
-- be settled /between/ processes, which is where a defect that leaves residue cannot hide
-- behind an assertion that agrees with itself.
storeImage :: Store -> ByteString
storeImage store =
  frame (entries "committed" (storeCommitted store) <> entries "staging" (storeStaging store))
  where
    entries label table =
      Encoding.encodeUtf8 label
        : concat [[Encoding.encodeUtf8 key, value] | (key, value) <- Map.toAscList table]

storeImageHex :: Store -> Text
storeImageHex = Text.pack . concatMap byteHex . ByteString.unpack . storeImage
  where
    byteHex byte = case showHex byte "" of
      [single] -> ['0', single]
      digits -> digits

-- | Place content under a reservation, staging first and committing only on completion.
--
-- The reservation is the authority: 'admit' returned it, so the space and the slot are
-- already held. What remains to decide here is the one thing admission could not — whether
-- the content is as large as its holder declared — and the answer on the refusing side is
-- a store that is exactly the store that came in.
materializeUnder
  :: Reservation
  -> Placement
  -> Store
  -> (Either Refusal Text, Store)
materializeUnder reservation wanted store
  | overrun = (Left (DeclarationExceeded declared actual), reaped)
  | otherwise = (Right key, committed)
  where
    key = placementAddress wanted
    content = placementContent wanted
    declared = reservationBytes reservation
    actual = Bytes (fromIntegral (ByteString.length content))
    overrun = actual > declared
    staged = store {storeStaging = Map.insert key content (storeStaging store)}
    committed =
      Store
        { storeCommitted = Map.insert key content (storeCommitted store)
        , storeStaging = Map.delete key (storeStaging staged)
        }
#ifdef BUDGET_CALCULUS_ADMIT_AFTER_PARTIAL_WRITE_MUTANT
    -- The seeded inversion. The content reaches its address before the declaration is
    -- checked, so the refusal arrives after the write instead of before it and the store
    -- keeps a partial artifact at an address a consumer can name.
    reaped = committed
#else
    reaped = store
#endif

-- | Length-prefixed framing, so the concatenation is unambiguous.
frame :: [ByteString] -> ByteString
frame =
  Lazy.toStrict . Builder.toLazyByteString . foldMap piece
  where
    piece value =
      Builder.word64BE (fromIntegral (ByteString.length value)) <> Builder.byteString value
