module Main where

import Prelude

import Amoebius.Ui.Components (headingFor, statusFor)
import Amoebius.Ui.Interpreter (Transition, transition)
import Effect (Effect)

foreign import install
  :: (String -> String -> String -> Transition)
  -> (String -> String)
  -> (String -> String -> String)
  -> Effect Unit

main :: Effect Unit
main = install transition headingFor statusFor
