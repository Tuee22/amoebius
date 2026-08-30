module Main (main) where

import PhaseContractInternalOracle
  ( phaseContractInternalExactCaseNames
  , phaseContractInternalSelectorMatrixRows
  , phaseContractInternalSelectorNames
  , runPhaseContractInternalExactCase
  , runPhaseContractInternalOracle
  , runPhaseContractInternalSelectorOracle
  , runPhaseContractInternalUnaffectedControl
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
      "PhaseContractInternalOracle"
      runPhaseContractInternalOracle
      runPhaseContractInternalSelectorOracle)
      { suiteSelectorNames = phaseContractInternalSelectorNames
      , suiteExactCaseNames = phaseContractInternalExactCaseNames
      , suiteRunExactCase = Just runPhaseContractInternalExactCase
      , suiteRunUnaffected = Just runPhaseContractInternalUnaffectedControl
      , suiteAssignments = phaseContractInternalSelectorMatrixRows
      }
