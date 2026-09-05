module Main (main) where

import Amoebius.Ui.Check (CheckedUiProgram, checkedCaseName)
import Data.Text (Text)

observe :: CheckedUiProgram -> Text
observe = checkedCaseName

main :: IO ()
main = pure ()
