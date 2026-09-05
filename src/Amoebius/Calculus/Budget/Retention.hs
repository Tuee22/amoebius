{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | The retention grant: space held indefinitely, and the reaper that returns it.
--
-- 'jit_budget_doctrine.md' section 5 draws the ephemeral/retained line at the budget seam
-- rather than at the artifact's. An ephemeral artifact holds its space against a region
-- whose exit returns it, so its only budget question is whether the region's ceiling
-- admits its peak. A retained one holds space against /this/ grant with no exit, so its
-- question is different in kind: not \"does this fit\" but \"what returns it\".
--
-- The answer is a field. 'RetentionGrant' has no constructor that omits a 'Reaper', so
-- the prose the corpus used to carry — /deleted once no longer needed/ — is a value taken
-- at promotion by the person who knows, rather than a sentence discovered later by
-- whoever is paged. The committed compile-fail pair is what holds that: the legal fixture
-- names a reaper, and its twin, which differs in nothing else, has no type.
module Amoebius.Calculus.Budget.Retention
  ( Reaper (..)
  , reaperTag
  , RetentionGrant
  , retentionBytes
  , retentionReaper
  , retentionLocation
  , retentionPurpose
  , retain
  ) where

import Amoebius.Calculus.Budget.Admission (Refusal (CeilingExceeded, PerItemBoundExceeded))
import Amoebius.Calculus.Budget.Grant
  ( Bytes
  , Grant
  , Location
  , Purpose
  , allowanceCeiling
  , allowancePerItem
  , grantAllowance
  , grantLocation
  , grantPurpose
  )
import Data.Text (Text)
import Data.Word (Word32)

-- | The condition under which retained space comes back. Three arms, and no fourth that
-- declines to state one: an eviction policy, a generation bound, or the lifetime of
-- something that depends on the artifact.
data Reaper
  = EvictionPolicy Text
  | GenerationBound Word32
  | DependentLifetime Text
  deriving stock (Eq, Ord, Show)

reaperTag :: Reaper -> Text
reaperTag = \case
  EvictionPolicy _ -> "eviction-policy"
  GenerationBound _ -> "generation-bound"
  DependentLifetime _ -> "dependent-lifetime"

-- | Space held past a region, and what returns it. The constructor is not exported, so
-- 'retain' is the only introduction rule and it takes the reaper.
data RetentionGrant = RetentionGrant
  { retentionBytes :: Bytes
  , retentionLocation :: Location
  , retentionPurpose :: Purpose
  , retentionReaper :: Reaper
  }
  deriving stock (Eq, Ord, Show)

-- | Promote space to retained under a stated reaper.
--
-- The reaper is the last argument on purpose. A caller that forgets it does not get a
-- retention grant with a hole in it; it gets a function, and the compile-fail twin is
-- exactly that program.
#ifdef BUDGET_CALCULUS_RETENTION_OMITS_REAPER_MUTANT
retain :: Grant -> Bytes -> Either Refusal RetentionGrant
retain grant wanted = retainWith grant wanted (DependentLifetime "unstated")
#else
retain :: Grant -> Bytes -> Reaper -> Either Refusal RetentionGrant
retain grant wanted reaper
  = retainWith grant wanted reaper
#endif

retainWith :: Grant -> Bytes -> Reaper -> Either Refusal RetentionGrant
retainWith grant wanted reaper
  | wanted > allowancePerItem bound = Left (PerItemBoundExceeded (allowancePerItem bound) wanted)
  | wanted > allowanceCeiling bound = Left (CeilingExceeded (allowanceCeiling bound) wanted)
  | otherwise = Right held
  where
    bound = grantAllowance grant
    held =
      RetentionGrant
        { retentionBytes = wanted
        , retentionLocation = grantLocation grant
        , retentionPurpose = grantPurpose grant
        , retentionReaper = reaper
        }
