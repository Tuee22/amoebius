module Increment where

{-@ amoebius-refinement
model: Counter
invariant: NonNegative
function: increment
arguments: x
pre: x >= 0
post: result >= 0
@-}

increment :: Integer -> Integer
increment x = x + 1
