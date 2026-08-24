module Main (main) where

import Amoebius.Validation.PbBootstrapGrammar (PbTrackedFile)

forbiddenInventory :: Maybe PbTrackedFile
forbiddenInventory = Nothing

main :: IO ()
main = forbiddenInventory `seq` pure ()
