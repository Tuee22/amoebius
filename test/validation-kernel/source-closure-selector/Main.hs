module Main (main) where

import SelectorCli (SelectorSuite (..), runSelectorCli, selectorSuite)
import SourceClosureOracle
  ( runSourceClosureOracle
  , runSourceClosureSelectorControlOracle
  , runSourceClosureSelectorOracle
  , sourceClosureSelectorIntents
  , sourceClosureSelectorNames
  )

main :: IO ()
main =
  runSelectorCli
    (selectorSuite "SourceClosureOracle" runSourceClosureOracle runSourceClosureSelectorOracle)
      { suiteSelectorNames = sourceClosureSelectorNames
      , suiteRunControl = Just runSourceClosureSelectorControlOracle
      , suiteAssignments =
          [ (selector, [exactCase], "selector registry integrity")
          | (selector, exactCase) <- sourceClosureSelectorIntents
          ]
      }
