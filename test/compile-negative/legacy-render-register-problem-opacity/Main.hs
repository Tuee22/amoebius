module Main (main) where

import Amoebius.Validation.Legacy (renderRegisterProblem)

main :: IO ()
main = renderRegisterProblem `seq` pure ()
