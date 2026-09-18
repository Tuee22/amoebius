{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

-- | The outstanding-obligation set, at the type level.
--
-- 'workflow_calculus_doctrine.md' section 3 states the mechanism: provision returns a
-- handle /and/ a teardown obligation, the obligation has no discard rule, and a workflow
-- ending while it still holds one is rejected at compile time. This module is the part of
-- that which is arithmetic — what it means to add an obligation, to remove one, and for
-- two parallel branches to owe nothing in common.
--
-- The set is a type-level list of resource names. A name rather than a structure, because
-- the whole point is that the /identity/ of what is owed travels in the type: two
-- obligations for different resources are different types, and discharging one does not
-- discharge the other.
--
-- 'Remove' is where "no way to drop it" becomes a compiler message. Removing an obligation
-- the workflow does not hold has no reduction, and rather than leaving a stuck family for
-- a reader to decode, the empty case is a 'TypeError' that names the resource. The
-- committed compile-fail fixture asserts that message rather than merely asserting that
-- something failed.
module Amoebius.Calculus.Workflow.Obligation
  ( Remove
  , Append
  , Disjoint
  , NotElem
  ) where

import Data.Kind (Constraint)
import GHC.TypeError (ErrorMessage (..), TypeError)
import GHC.TypeLits (Symbol)

-- | Discharge one obligation. A workflow that does not hold it does not typecheck, and the
-- message says which one it was asked to discharge.
type family Remove (r :: Symbol) (rs :: [Symbol]) :: [Symbol] where
  Remove r '[] =
    TypeError
      ( 'Text "the workflow holds no teardown obligation for "
          ':<>: 'ShowType r
          ':$$: 'Text "so there is nothing here to discharge or transfer"
      )
  Remove r (r ': rest) = rest
  Remove r (s ': rest) = s ': Remove r rest

-- | The obligations of two workflows run one after the other.
type family Append (as :: [Symbol]) (bs :: [Symbol]) :: [Symbol] where
  Append '[] bs = bs
  Append (a ': as) bs = a ': Append as bs

-- | Two parallel branches owe nothing in common.
--
-- Section 2 admits parallel composition "over disjoint resources", and this is that
-- condition. Without it two branches could each provision the same resource and each
-- discharge it once, and the ledger would balance while the resource was created twice
-- and released twice — a workflow that is wrong in a way no count would notice.
type family Disjoint (as :: [Symbol]) (bs :: [Symbol]) :: Constraint where
  Disjoint '[] _bs = ()
  Disjoint (a ': as) bs = (NotElem a bs, Disjoint as bs)

-- | One resource is not among another branch's.
type family NotElem (a :: Symbol) (bs :: [Symbol]) :: Constraint where
  NotElem _a '[] = ()
  NotElem a (a ': _bs) =
    TypeError
      ( 'Text "two parallel branches both provision "
          ':<>: 'ShowType a
          ':$$: 'Text "and section 2 admits parallel composition only over disjoint resources"
      )
  NotElem a (_b ': bs) = NotElem a bs
