module Main (main) where

import Amoebius.Validation.PbBootstrapGrammar (ResolvedCall)

forbiddenResolution :: Maybe ResolvedCall
forbiddenResolution = Nothing

main :: IO ()
main = forbiddenResolution `seq` pure ()
