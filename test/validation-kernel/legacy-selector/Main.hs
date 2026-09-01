module Main (main) where

import LegacyOracle
  ( legacySelectorAssignments
  , legacySelectorNames
  , runLegacyOracle
  , runLegacySelectorOracle
  , runLegacyUnaffectedControl
  )
import SelectorCli (SelectorSuite (..), runSelectorCli, selectorSuite)

main :: IO ()
main =
  runSelectorCli
    (selectorSuite "LegacyOracle" runLegacyOracle runLegacySelectorOracle)
      { suiteSelectorNames = legacySelectorNames
      , suiteRunUnaffected = Just (const runLegacyUnaffectedControl)
      , suiteAssignments =
          [ (selector, [exactCase], "canonical unaffected control")
          | (selector, exactCase) <- legacySelectorAssignments
          ]
      }
