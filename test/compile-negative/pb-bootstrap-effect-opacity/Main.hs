module Main (main) where

import Amoebius.Validation.PbBootstrapGrammar (PotentialEffect)

forbiddenEffect :: Maybe PotentialEffect
forbiddenEffect = Nothing

main :: IO ()
main = forbiddenEffect `seq` pure ()
