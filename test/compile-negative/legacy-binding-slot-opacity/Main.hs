module Main (main) where

import Amoebius.Validation.Legacy qualified as Public

privateBinding :: Maybe (Public.BindingSlot ())
privateBinding = Nothing

main :: IO ()
main = privateBinding `seq` pure ()
