module Main (main) where

import Amoebius.Validation.Dispatch (discoverRepositoryRoot)

main :: IO ()
main = discoverRepositoryRoot `seq` pure ()
