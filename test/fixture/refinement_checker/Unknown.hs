module Unknown where

{-@ amoebius-refinement
model: Counter
invariant: MissingInvariant
function: unknownMapping
arguments: x
pre: x >= 0
post: result >= 0
@-}

unknownMapping :: Integer -> Integer
unknownMapping x = x
