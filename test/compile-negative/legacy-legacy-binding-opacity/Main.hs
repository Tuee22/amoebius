module Main (main) where

import Amoebius.Validation.Legacy qualified as Public

privateBinding :: Maybe Public.LegacyBinding
privateBinding = Nothing

main :: IO ()
main = privateBinding `seq` pure ()
