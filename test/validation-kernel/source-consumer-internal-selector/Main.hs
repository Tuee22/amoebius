module Main (main) where

import SelectorCli (SelectorSuite (..), runSelectorCli, selectorSuite)
import SourceConsumerGraphInternalOracle
  ( runSourceConsumerGraphInternalOracle
  , runSourceConsumerGraphInternalSelectorControlOracle
  , runSourceConsumerGraphInternalSelectorOracle
  , sourceConsumerGraphInternalSelectorIntents
  , sourceConsumerGraphInternalSelectorNames
  )

main :: IO ()
main =
  runSelectorCli
    ( (selectorSuite "validation-source-consumer-internal-selector-component" runSourceConsumerGraphInternalOracle runSourceConsumerGraphInternalSelectorOracle)
        { suiteSelectorNames = sourceConsumerGraphInternalSelectorNames
        , suiteRunControl = Just (const runSourceConsumerGraphInternalSelectorControlOracle)
        , suiteAssignments =
            [ (selector, [exactCase], "source-consumer-internal-unaffected-control")
            | (selector, exactCase) <- sourceConsumerGraphInternalSelectorIntents
            ]
        }
    )
