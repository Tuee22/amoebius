module Main (main) where

import Amoebius.Validation.Dispatch (runValidateCommand)

main :: IO ()
main = runValidateCommand `seq` pure ()
