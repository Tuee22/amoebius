module Main (main) where

import DispatchOracle
  ( dispatchSelectorNames
  , runDispatchOracle
  , runDispatchSelectorOracle
  )
import SelectorCli (SelectorSuite (..), runSelectorCli, selectorSuite)

main :: IO ()
main =
  runSelectorCli
    (selectorSuite "DispatchOracle" runDispatchOracle runDispatchSelectorOracle)
      { suiteSelectorNames = dispatchSelectorNames
      }
