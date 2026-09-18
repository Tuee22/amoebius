module Main (main) where

import Amoebius.Ui.Check (CheckedUiProgram)

illegal :: CheckedUiProgram
illegal = CheckedUiProgram

main :: IO ()
main = illegal `seq` pure ()
