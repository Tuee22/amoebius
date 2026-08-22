module Main where

import Prelude

import Amoebius.Ui.Components (headingFor, statusFor)
import Amoebius.Ui.Interpreter (Transition, transition)
import Amoebius.Ui.Offline.Runtime (installOfflineRuntime, offlineCapabilities)
import Effect (Effect)

foreign import install
  :: (String -> String -> String -> Transition)
  -> (String -> String)
  -> (String -> String -> String)
  -> Effect Unit

main :: Effect Unit
main = do
  installOfflineRuntime offlineCapabilities
  install transition headingFor statusFor
