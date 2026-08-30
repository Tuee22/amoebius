module Main (main) where

import PbBootstrapGrammarOracle
  ( pbBootstrapGrammarExactCaseNames
  , pbBootstrapGrammarSelectorMatrixRows
  , pbBootstrapGrammarSelectorNames
  , runPbBootstrapGrammarExactCase
  , runPbBootstrapGrammarOracle
  , runPbBootstrapGrammarSelectorControlOracle
  , runPbBootstrapGrammarSelectorOracle
  )
import SelectorCli
  ( SelectorSuite (..)
  , runSelectorCli
  , selectorSuite
  )

main :: IO ()
main =
  runSelectorCli
    (selectorSuite
      "PbBootstrapGrammarOracle"
      runPbBootstrapGrammarOracle
      runPbBootstrapGrammarSelectorOracle)
      { suiteSelectorNames = pbBootstrapGrammarSelectorNames
      , suiteExactCaseNames = pbBootstrapGrammarExactCaseNames
      , suiteRunExactCase = Just runPbBootstrapGrammarExactCase
      , suiteRunControl = Just runPbBootstrapGrammarSelectorControlOracle
      , suiteAssignments = pbBootstrapGrammarSelectorMatrixRows
      }
