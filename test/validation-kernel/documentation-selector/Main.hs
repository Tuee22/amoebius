module Main (main) where

import DocumentationOracle
  ( documentationSelectorMatrixRows
  , documentationSelectorNames
  , runDocumentationOracle
  , runDocumentationSelectorOracle
  , runDocumentationUnaffectedControl
  )
import SelectorCli (SelectorSuite (..), runSelectorCli, selectorSuite)

main :: IO ()
main =
  runSelectorCli
    (selectorSuite "DocumentationOracle" runDocumentationOracle runDocumentationSelectorOracle)
      { suiteSelectorNames = documentationSelectorNames
      , suiteRunUnaffected = Just runDocumentationUnaffectedControl
      , suiteAssignments =
          [ (selector, impacts, control)
          | (selector, _requirement, impacts, control) <- documentationSelectorMatrixRows
          ]
      }
