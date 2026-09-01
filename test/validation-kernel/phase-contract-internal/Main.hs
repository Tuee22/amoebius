module Main (main) where

import EvidenceGatePassInternalOracle (runEvidenceGatePassInternalOracle)
import PhaseContractInternalOracle (
    phaseContractInternalExactCaseNames,
    phaseContractInternalSelectorMatrixRows,
    phaseContractInternalSelectorNames,
    runPhaseContractInternalExactCase,
    runPhaseContractInternalOracle,
    runPhaseContractInternalSelectorOracle,
    runPhaseContractInternalUnaffectedControl,
 )
import PhaseRunnerInternalOracle (runPhaseRunnerInternalOracle)
import SelectorCli (
    SelectorSuite (..),
    runSelectorCli,
    selectorSuite,
 )
import StatusProjectionInternalOracle (runStatusProjectionInternalOracle)

main :: IO ()
main =
    runSelectorCli
        ( selectorSuite
            "PhaseContractInternalOracle"
            (runEvidenceGatePassInternalOracle >> runPhaseRunnerInternalOracle >> runStatusProjectionInternalOracle >> runPhaseContractInternalOracle)
            runPhaseContractInternalSelectorOracle
        )
            { suiteSelectorNames = phaseContractInternalSelectorNames
            , suiteExactCaseNames = phaseContractInternalExactCaseNames
            , suiteRunExactCase = Just runPhaseContractInternalExactCase
            , suiteRunUnaffected = Just runPhaseContractInternalUnaffectedControl
            , suiteAssignments = phaseContractInternalSelectorMatrixRows
            }
