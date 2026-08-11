-- mut-48-determinism-const-output: drop seed and input effects.
module DeterminismConstOutput where

seededOutput :: a -> b -> String
seededOutput _ _ = "constant"
