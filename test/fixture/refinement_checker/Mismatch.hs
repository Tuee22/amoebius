module Mismatch where

{-@ amoebius-refinement
model: Counter
invariant: NonNegative
function: negativeIdentity
arguments: x
pre: x < 0
post: result < 0
@-}

negativeIdentity :: Integer -> Integer
negativeIdentity x = x
