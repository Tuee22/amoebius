{-# LANGUAGE OverloadedStrings #-}

-- | The legal twin, differing only in whether a reaper is named.
--
-- 'retain' takes the reaper last, so this program and its twin are the same program with
-- one argument supplied. That the supplied one typechecks and the omitted one does not is
-- the whole of 'jit_budget_doctrine.md' section 5's rule: a retention grant with no
-- reaper has no constructor, so what returns the space is decided at promotion by the
-- person who knows rather than discovered later by whoever is paged.
module BudgetCalculusRetentionNamesItsReaper where

import Amoebius.Calculus.Budget.Admission (Refusal)
import Amoebius.Calculus.Budget.Grant (Bytes (..), Grant)
import Amoebius.Calculus.Budget.Retention (Reaper (EvictionPolicy), RetentionGrant, retain)

-- The accepted program: the reaper is named, so the retention grant exists.
held :: Grant -> Either Refusal RetentionGrant
held grant = retain grant (Bytes 4) (EvictionPolicy "least-recently-used")
