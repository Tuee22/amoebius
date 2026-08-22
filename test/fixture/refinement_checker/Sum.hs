module Sum where

{-@ amoebius-refinement
model: Pair
invariant: NonNegativeSum
function: sumNonNegative
arguments: x, y
pre: (x >= 0) && (y >= 0)
post: result >= 0
@-}

sumNonNegative :: Integer -> Integer -> Integer
sumNonNegative x y = x + y
