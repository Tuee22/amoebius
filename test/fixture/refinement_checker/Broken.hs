module Broken where

{-@ amoebius-refinement
model: Counter
invariant: NonNegative
function: brokenDecrement
arguments: x
pre: x >= 0
post: result >= 0
@-}

brokenDecrement :: Integer -> Integer
brokenDecrement x = x - 1
