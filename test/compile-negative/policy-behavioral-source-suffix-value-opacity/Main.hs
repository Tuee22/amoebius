module Main (main) where

import Amoebius.Validation.PolicyContract (behavioralSourceSuffix)

main :: IO ()
main = behavioralSourceSuffix `seq` pure ()
