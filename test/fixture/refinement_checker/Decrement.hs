module Decrement where

{-@ amoebius-refinement
model: Counter
invariant: NonNegative
function: decrement
arguments: x
pre: x >= 1
post: result >= 0
@-}

decrement :: Integer -> Integer
decrement x = x - 1
