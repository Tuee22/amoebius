module Main (main) where

import Amoebius.Validation.Dispatch (dispatchDiagnostic)

main :: IO ()
main = dispatchDiagnostic mempty [] `seq` pure ()
