module Main (main) where

import Amoebius.Validation.PbBootstrapGrammar (Phase50InvocationContract)

forbiddenInvocation :: Maybe Phase50InvocationContract
forbiddenInvocation = Nothing

main :: IO ()
main = forbiddenInvocation `seq` pure ()
