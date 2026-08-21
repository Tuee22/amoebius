{-# LANGUAGE OverloadedStrings #-}

-- | The legal twin, differing only in where the grant comes from.
--
-- 'jit_budget_doctrine.md' section 2 says the constructor is not exported and only the
-- issuer can call it, and that there is no unbounded constructor and no default. This is
-- what that leaves a caller: ask the pool, and receive the grant together with the pool
-- that has already been reduced by it.
module BudgetCalculusGrantComesFromTheIssuer where

import Amoebius.Calculus.Budget.Grant
  ( Bytes (..)
  , Grant
  , IssueRefusal
  , Pool
  , Purpose (BuildCache)
  , Slots (..)
  , allowance
  , issue
  )

-- The accepted program: the authority is issued, and the pool it came out of is smaller.
authorised :: Pool -> Either IssueRefusal (Grant, Pool)
authorised source = issue source BuildCache (allowance (Bytes 40) (Slots 4) (Bytes 15))
