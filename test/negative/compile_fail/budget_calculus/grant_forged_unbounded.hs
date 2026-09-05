{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | The illegal half of the issuer pair: a grant written down rather than issued, and an
-- unbounded one at that.
--
-- This is the value section 2 says must not be spellable — the default nobody notices,
-- which switches the discipline off wherever it is held. It is unspellable because
-- 'Amoebius.Calculus.Budget.Grant' exports the two types and neither constructor, so what
-- 'Grant' names here is a type where a term belongs and the compiler says exactly that:
-- an illegal term-level use of a type constructor. The claim is about the module boundary
-- and so is the diagnostic, which is why the gate requires that phrase rather than merely
-- requiring the program to fail.
module BudgetCalculusGrantForgedUnbounded where

-- The import list names the two types and not their constructors, because the two
-- constructors are not there to be named: that is the property under test, and asking for
-- them here would report it as an import error instead of as the program having no type.
import Amoebius.Calculus.Budget.Grant
  (
#ifdef BUDGET_CALCULUS_GRANT_CONSTRUCTORS_EXPOSED_MUTANT
    Allowance (..)
#else
    Allowance
#endif
  , Bytes (..)
#ifdef BUDGET_CALCULUS_GRANT_CONSTRUCTORS_EXPOSED_MUTANT
  , Grant (..)
#else
  , Grant
#endif
  , Location (..)
  , Purpose (BuildCache)
  , Slots (..)
  )

-- The rejected program: no issuer, no pool, no ceiling that means anything.
forged :: Grant
forged =
  Grant
    (Location "cache-a")
    BuildCache
    (Allowance (Bytes maxBound) (Slots maxBound) (Bytes maxBound))
