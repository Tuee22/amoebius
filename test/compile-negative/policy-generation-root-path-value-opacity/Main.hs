module Main (main) where

import Amoebius.Validation.PolicyContract (generationRootPath)

main :: IO ()
main = generationRootPath `seq` pure ()
