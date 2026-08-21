{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Materialize, consume, reap — the region an artifact's existence /is/.
--
-- 'jit_artifact_doctrine.md' section 5 makes an artifact's existence a region rather than
-- a fact about the filesystem. Reaping is not a cleanup step somebody schedules; it is
-- what region exit means, so an artifact with no retention decision cannot survive its
-- region. Section 6 adds the one difference between the two dispositions: a retained
-- artifact must name a 'Reaper', and one promoted without a reaper has no constructor.
--
-- The escape argument is the skolem one. A 'Handle' carries the region's phantom @s@ and
-- 'runRegion' quantifies it, so the result type cannot mention it and a handle cannot
-- leave. There is no operation from an 'Address' to content outside the region, which is
-- what makes \"referenced after its region ends\" a type error rather than a convention.
module Amoebius.Calculus.Artifact.Region
  ( Region
  , Handle
  , handleAddress
  , Reaper (..)
  , Disposition (..)
  , RegionOutcome (..)
  , RetainedArtifact (..)
  , materialize
  , consume
  , promote
  , runRegion
  ) where

import Amoebius.Calculus.Artifact.Address (Address, addressHex, addressOf)
import Amoebius.Calculus.Artifact.Recipe (Declaration, Recipe, Rendered (Rendered), render, renderedBytes)
import Amoebius.Calculus.Artifact.Target (ArtifactKind)
import Data.ByteString (ByteString)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Word (Word32)

-- | The condition under which a retained artifact stops being needed. It is a value, not
-- a comment, and the type offers no arm that declines to name one.
data Reaper
  = EvictionPolicy Text
  | GenerationBound Word32
  | DependentLifetime Text
  deriving stock (Eq, Ord, Show)

-- | The two dispositions. 'Retained' carries its reaper, so \"retained with no reaper\"
-- is unspellable rather than rejected.
data Disposition
  = Ephemeral
  | Retained Reaper
  deriving stock (Eq, Ord, Show)

-- | A handle to a materialized artifact. The @s@ is the region's skolem; nothing that
-- mentions it can leave 'runRegion'.
data Handle s (k :: ArtifactKind) = Handle
  { handleAddress :: Address k
  , handleKey :: Text
  }
  deriving stock (Eq, Show)

data Entry = Entry
  { entryBytes :: ByteString
  , entryDisposition :: Disposition
  }

data RegionState = RegionState
  { stateEntries :: Map Text Entry
  , stateOrder :: [Text]
  }

-- | A pure region. It is a state fold rather than an effect, because the whole calculus
-- is stated over values: an artifact is bytes and a name, and a region is the scope in
-- which those two are related.
newtype Region s a = Region (RegionState -> (a, RegionState))

instance Functor (Region s) where
  fmap f (Region step) = Region (\state -> case step state of (value, next) -> (f value, next))

instance Applicative (Region s) where
  pure value = Region (\state -> (value, state))
  Region left <*> Region right =
    Region
      ( \state -> case left state of
          (f, afterLeft) -> case right afterLeft of
            (value, afterRight) -> (f value, afterRight)
      )

instance Monad (Region s) where
  Region step >>= f =
    Region
      ( \state -> case step state of
          (value, next) -> case f value of Region continue -> continue next
      )

-- | Produce the bytes and place them at their address, yielding a handle. It is
-- idempotent: materializing an address that already exists is a hit, and the calculus
-- does not distinguish the two for the consumer.
materialize :: Declaration d => Recipe k d -> d -> Region s (Handle s k)
materialize recipe declaration =
  Region
    ( \state ->
        let rendered = render recipe declaration
            address = addressOf recipe declaration rendered
            key = addressHex address
            handle = Handle {handleAddress = address, handleKey = key}
         in if Map.member key (stateEntries state)
              then (handle, state)
              else
                ( handle
                , state
                    { stateEntries =
                        Map.insert key (Entry (renderedBytes rendered) Ephemeral) (stateEntries state)
                    , stateOrder = stateOrder state <> [key]
                    }
                )
    )

-- | Take the content through the handle. There is no address-to-content operation
-- outside a region, so this is the only way in. The index is restored from the handle,
-- which is sound because the target tag is one of the four things the address folds: two
-- kinds cannot share an address without a hash collision.
consume :: Handle s k -> Region s (Maybe (Rendered k))
consume handle =
  Region
    ( \state ->
        ( fmap (Rendered . entryBytes) (Map.lookup (handleKey handle) (stateEntries state))
        , state
        )
    )

-- | Promote to retained under a stated reaper. Promotion is explicit and one-way: this
-- module exports no demotion, because an artifact something else already depends on
-- cannot be made ephemeral by a later decision.
promote :: Reaper -> Handle s k -> Region s ()
promote reaper handle =
  Region
    ( \state ->
        ( ()
        , state
            { stateEntries =
                Map.adjust
                  (\entry -> entry {entryDisposition = Retained reaper})
                  (handleKey handle)
                  (stateEntries state)
            }
        )
    )

-- | An artifact that outlived its region, with the reaper that admitted it.
data RetainedArtifact = RetainedArtifact
  { retainedAddress :: Text
  , retainedReaper :: Reaper
  }
  deriving stock (Eq, Show)

-- | What a region leaves behind: the value it computed, the addresses reaped at exit, and
-- the artifacts promoted out of it.
data RegionOutcome a = RegionOutcome
  { regionValue :: a
  , regionReaped :: [Text]
  , regionRetained :: [RetainedArtifact]
  }
  deriving stock (Eq, Show)

#ifdef ARTIFACT_CALCULUS_HANDLE_ESCAPES_REGION_MUTANT
-- | The seeded escape. Dropping the rank-2 quantifier lets @a@ mention @s@, so a handle
-- leaves the region and the committed compile-fail fixture starts compiling.
runRegion :: Region s a -> RegionOutcome a
#else
-- | Run a region and reap it. The rank-2 quantifier is the escape argument: @a@ cannot
-- mention @s@, so no handle survives the call.
runRegion :: (forall s. Region s a) -> RegionOutcome a
#endif
runRegion program =
  case program of
    Region step -> case step (RegionState Map.empty []) of
      (value, final) ->
        RegionOutcome
          { regionValue = value
          , regionReaped = [key | key <- stateOrder final, isEphemeral key final]
          , regionRetained = concat [retainedAt key final | key <- stateOrder final]
          }
  where
    isEphemeral key state = case Map.lookup key (stateEntries state) of
      Just entry -> entryDisposition entry == Ephemeral
      Nothing -> False
    retainedAt key state = case Map.lookup key (stateEntries state) of
      Just entry -> case entryDisposition entry of
        Retained reaper -> [RetainedArtifact key reaper]
        Ephemeral -> []
      Nothing -> []
