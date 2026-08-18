-- mut-48-rng-workerid-mixed: make stream seed depend on worker assignment.
module RngWorkerIdMixed where

derive :: Int -> Int -> Int -> Int
derive master stream worker = master + stream + worker
