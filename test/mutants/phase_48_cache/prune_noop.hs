-- mut-48-cache-prune-noop: drop the eviction effect.
module PruneNoop where

prune :: IO ()
prune = pure ()
