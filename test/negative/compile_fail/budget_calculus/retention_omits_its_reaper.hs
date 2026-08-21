{-# LANGUAGE OverloadedStrings #-}

-- | The illegal half of the retention pair: space held past a region with nothing stated
-- to return it.
--
-- Omitting the reaper does not produce a retention grant with a hole in it; it produces a
-- function still waiting for a 'Reaper', and the annotation this module gives it is the
-- one thing that cannot be. The rejection therefore names 'Reaper' — which is the reason
-- the fixture exists to assert, rather than merely that something failed.
module BudgetCalculusRetentionOmitsItsReaper where

import Amoebius.Calculus.Budget.Admission (Refusal)
import Amoebius.Calculus.Budget.Grant (Bytes (..), Grant)
import Amoebius.Calculus.Budget.Retention (RetentionGrant, retain)

-- The rejected program: no reaper, so nothing states what returns the space.
held :: Grant -> Either Refusal RetentionGrant
held grant = retain grant (Bytes 4)
