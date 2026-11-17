-- | Observe the native client's actual frame producer and consumer.
module NativeWire (main) where

import Amoebius.Pulsar.Diagnostics (connectWireObservation)
import Data.Text.IO qualified as Text
import System.Exit (die)

main :: IO ()
main = either (die . show) Text.putStr connectWireObservation
