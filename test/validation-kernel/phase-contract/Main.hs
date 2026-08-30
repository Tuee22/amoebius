module Main (main) where

import PhaseContractOracle
  ( phaseContractExactCaseNames
  , phaseContractSelectorMatrixRows
  , phaseContractSelectorNames
  , runPhaseContractExactCase
  , runPhaseContractOracle
  , runPhaseContractSelectorOracle
  , runPhaseContractUnaffectedControl
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
      "PhaseContractOracle"
      runPhaseContractOracle
      runPhaseContractSelectorOracle)
      { suiteSelectorNames = phaseContractSelectorNames
      , suiteExactCaseNames = phaseContractExactCaseNames
      , suiteRunExactCase = Just runPhaseContractExactCase
      , suiteRunUnaffected = Just runPhaseContractUnaffectedControl
      , suiteAssignments = phaseContractSelectorMatrixRows
      }
