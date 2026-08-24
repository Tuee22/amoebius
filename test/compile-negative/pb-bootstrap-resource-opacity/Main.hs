module Main (main) where

import Amoebius.Validation.PbBootstrapGrammar (PbResourceMetrics)

forbiddenMetrics :: Maybe PbResourceMetrics
forbiddenMetrics = Nothing

main :: IO ()
main = forbiddenMetrics `seq` pure ()
