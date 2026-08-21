{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | The grant: the authority a byte needs in order to exist.
--
-- 'jit_budget_doctrine.md' section 2 gives the grant three load-bearing properties, and
-- each is carried by a different mechanism here, because only one of the three is a type
-- property at all.
--
-- * /Scarce/ is carried by 'issue' returning a reduced 'Pool' beside the grant. Scarcity
--   is a property of one issuer over one pool, and the doctrine says so: two issuers over
--   one pool double-count, and nothing in a type stops a second issuer from existing.
--   What this module offers is that a single issuer's arithmetic is total and
--   subtractive, so the last gigabyte cannot be handed out twice /by it/.
-- * /Specific/ is carried by the location and the purpose travelling inside the grant and
--   being compared at admission, so a build-cache grant cannot be spent on a checkpoint.
-- * /Unforgeable/ is carried by the module boundary: 'Grant' and 'Allowance' are exported
--   without their constructors, so the only introduction rules are 'issue' and
--   'allowance'. That is a claim about this export list, and the committed compile-fail
--   pair is what holds it — a fixture that writes the constructor out has no type.
--
-- There is no unbounded arm. 'Allowance' is one constructor over a ceiling, a concurrency
-- bound, and a per-item bound, so section 3's rule that a ceiling is meaningless stated
-- alone is a shape rather than a warning: none of the three can be given without the
-- other two.
module Amoebius.Calculus.Budget.Grant
  ( -- * Quantities
    Bytes (..)
  , Slots (..)
  , addBytes
  , subtractBytes
  , addSlots
  , subtractSlots
    -- * What a grant is specific to
  , Location (..)
  , Purpose (..)
  , everyPurpose
  , purposeTag
    -- * The paired bound
  , Allowance
  , allowance
  , allowanceCeiling
  , allowanceConcurrency
  , allowancePerItem
    -- * The grant
  , Grant
  , grantLocation
  , grantPurpose
  , grantAllowance
    -- * The pool it is issued from
  , Pool
  , pool
  , poolLocation
  , poolFreeBytes
  , poolFreeSlots
  , IssueRefusal (..)
  , issue
  ) where

import Data.Text (Text)
import Data.Word (Word32, Word64)

-- | A quantity of storage. 'Word64' rather than 'Integer' because a byte count that can
-- be negative is a state this calculus has no meaning for, and the two operations below
-- are saturating rather than wrapping for the same reason.
newtype Bytes = Bytes Word64
  deriving stock (Eq, Ord, Show)

-- | A count of simultaneous materializations: section 3's second half of the pair.
newtype Slots = Slots Word32
  deriving stock (Eq, Ord, Show)

-- | Saturating addition. A sum that wrapped would report a ceiling as satisfied by a
-- demand that overran it, which is the one arithmetic slip this calculus cannot afford.
addBytes :: Bytes -> Bytes -> Bytes
addBytes (Bytes left) (Bytes right)
  | right > maxBound - left = Bytes maxBound
  | otherwise = Bytes (left + right)

-- | Saturating subtraction, clamped at zero.
subtractBytes :: Bytes -> Bytes -> Bytes
subtractBytes (Bytes left) (Bytes right)
  | right >= left = Bytes 0
  | otherwise = Bytes (left - right)

addSlots :: Slots -> Slots -> Slots
addSlots (Slots left) (Slots right)
  | right > maxBound - left = Slots maxBound
  | otherwise = Slots (left + right)

subtractSlots :: Slots -> Slots -> Slots
subtractSlots (Slots left) (Slots right)
  | right >= left = Slots 0
  | otherwise = Slots (left - right)

-- | Where the bytes would live. It is part of the grant, so a grant cannot be spent
-- somewhere else by accident.
newtype Location = Location Text
  deriving stock (Eq, Ord, Show)

-- | What the bytes are for. The set is closed: a new purpose is a change to this module,
-- never a string a caller invents, because a purpose that can be spelled freely is a
-- purpose a grant can be laundered into.
data Purpose
  = BuildCache
  | ArtifactStore
  | ModelCheckpoint
  | WorkingDirectory
  deriving stock (Eq, Ord, Show, Enum, Bounded)

everyPurpose :: [Purpose]
everyPurpose = [minBound .. maxBound]

purposeTag :: Purpose -> Text
purposeTag = \case
  BuildCache -> "build-cache"
  ArtifactStore -> "artifact-store"
  ModelCheckpoint -> "model-checkpoint"
  WorkingDirectory -> "working-directory"

-- | A ceiling, the concurrency it is shared across, and the per-item bound — one value.
--
-- The constructor is not exported. 'allowance' is the only introduction rule and it takes
-- all three, which is the mechanical form of section 3: there is no way to raise one
-- without restating the others, and no way to state a ceiling alone.
data Allowance = Allowance
  { allowanceCeiling :: Bytes
  , allowanceConcurrency :: Slots
  , allowancePerItem :: Bytes
  }
  deriving stock (Eq, Ord, Show)

-- | Build the paired bound. The per-item bound is clamped to the ceiling rather than
-- refused: an item bound above the ceiling is not a second policy, it is the ceiling.
allowance :: Bytes -> Slots -> Bytes -> Allowance
allowance ceilingBytes concurrency perItem =
  Allowance
    { allowanceCeiling = ceilingBytes
    , allowanceConcurrency = concurrency
    , allowancePerItem = min perItem ceilingBytes
    }

-- | The authority itself. No constructor is exported, so 'issue' is the only way to hold
-- one: there is no default, no unbounded arm, and nothing to switch the discipline off
-- with.
data Grant = Grant
  { grantLocation :: Location
  , grantPurpose :: Purpose
  , grantAllowance :: Allowance
  }
  deriving stock (Eq, Ord, Show)

-- | The finite pool a grant is issued from — one issuer over one location.
data Pool = Pool
  { poolLocation :: Location
  , poolFreeBytes :: Bytes
  , poolFreeSlots :: Slots
  }
  deriving stock (Eq, Ord, Show)

-- | Open a pool over a substrate's declared capacity.
pool :: Location -> Bytes -> Slots -> Pool
pool = Pool

-- | Why an issue was refused. Each arm names what was asked and what was free, so a
-- refusal is diagnosable without re-deriving the arithmetic.
data IssueRefusal
  = PoolBytesExhausted Bytes Bytes
  | PoolSlotsExhausted Slots Slots
  deriving stock (Eq, Show)

-- | Issue a grant, reducing the pool by exactly what the grant carries.
--
-- The reduced pool is returned rather than mutated, so \"two holders both believe they
-- have the last gigabyte\" is unrepresentable for one issuer: the second call sees the
-- first call's subtraction, or it does not happen.
issue :: Pool -> Purpose -> Allowance -> Either IssueRefusal (Grant, Pool)
issue source purpose wanted = case (bytesFit, slotsFit) of
  (False, _) -> shortfall (PoolBytesExhausted (allowanceCeiling wanted) (poolFreeBytes source))
  (_, False) -> shortfall (PoolSlotsExhausted (allowanceConcurrency wanted) (poolFreeSlots source))
  (True, True) -> Right (granted, reduced)
  where
    bytesFit = allowanceCeiling wanted <= poolFreeBytes source
    slotsFit = allowanceConcurrency wanted <= poolFreeSlots source
    granted =
      Grant
        { grantLocation = poolLocation source
        , grantPurpose = purpose
        , grantAllowance = wanted
        }
    reduced =
      source
        { poolFreeBytes = subtractBytes (poolFreeBytes source) (allowanceCeiling wanted)
        , poolFreeSlots = subtractSlots (poolFreeSlots source) (allowanceConcurrency wanted)
        }
    shortfall :: IssueRefusal -> Either IssueRefusal (Grant, Pool)
#ifdef BUDGET_CALCULUS_GRANT_DEFAULTS_UNBOUNDED_MUTANT
    shortfall _ = Right (granted, source {poolFreeBytes = Bytes 0, poolFreeSlots = Slots 0})
#else
    shortfall = Left
#endif
