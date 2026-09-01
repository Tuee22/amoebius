module Main (main) where

import SelectorCli (SelectorSuite (..), runSelectorCli, selectorSuite)
import SourceConsumerGraphOracle
  ( runSourceConsumerGraphOracle
  , runSourceConsumerGraphSelectorControlOracle
  , runSourceConsumerGraphSelectorOracle
  , sourceConsumerGraphSelectorIntents
  , sourceConsumerGraphSelectorNames
  )

main :: IO ()
main =
  runSelectorCli
    (selectorSuite "SourceConsumerGraphOracle" runSourceConsumerGraphOracle runSourceConsumerGraphSelectorOracle)
      { suiteSelectorNames = sourceConsumerGraphSelectorNames
      , suiteRunControl = Just (const runSourceConsumerGraphSelectorControlOracle)
      , suiteAssignments =
          [ (selector, [exactCase], "public refusal remains unaffected")
          | (selector, exactCase) <- sourceConsumerGraphSelectorIntents
          ]
      }
