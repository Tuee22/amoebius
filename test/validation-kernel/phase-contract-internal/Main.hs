{-# LANGUAGE CPP #-}

module Main (main) where

#if !defined(VALIDATION_PHASE_CONTRACT_INTERNAL_SELECTOR_QUALIFICATION)
import EvidenceGatePassInternalOracle (runEvidenceGatePassInternalOracle)
#endif
import PhaseContractInternalOracle (
    phaseContractInternalExactCaseNames,
    phaseContractInternalSelectorMatrixRows,
    phaseContractInternalSelectorNames,
    runPhaseContractInternalExactCase,
    runPhaseContractInternalOracle,
    runPhaseContractInternalSelectorOracle,
    runPhaseContractInternalUnaffectedControl,
 )
#if !defined(VALIDATION_PHASE_CONTRACT_INTERNAL_SELECTOR_QUALIFICATION)
import PhaseRunnerInternalOracle (runPhaseRunnerInternalOracle)
#endif
import SelectorCli (
    SelectorSuite (..),
    runSelectorCli,
    selectorSuite,
 )
#if !defined(VALIDATION_PHASE_CONTRACT_INTERNAL_SELECTOR_QUALIFICATION)
import StatusProjectionInternalOracle (runStatusProjectionInternalOracle)
import ToolchainAcquisitionOracle (runToolchainAcquisitionOracle)
#endif

main :: IO ()
main =
    runSelectorCli
        ( selectorSuite
            "PhaseContractInternalOracle"
#if defined(VALIDATION_PHASE_CONTRACT_INTERNAL_SELECTOR_QUALIFICATION)
            runPhaseContractInternalOracle
#else
            (runEvidenceGatePassInternalOracle >> runPhaseRunnerInternalOracle >> runStatusProjectionInternalOracle >> runToolchainAcquisitionOracle >> runPhaseContractInternalOracle)
#endif
            runPhaseContractInternalSelectorOracle
        )
            { suiteSelectorNames = phaseContractInternalSelectorNames
            , suiteExactCaseNames = phaseContractInternalExactCaseNames
            , suiteRunExactCase = Just runPhaseContractInternalExactCase
            , suiteRunUnaffected = Just runPhaseContractInternalUnaffectedControl
            , suiteAssignments = phaseContractInternalSelectorMatrixRows
            }
