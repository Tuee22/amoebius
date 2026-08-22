module Main (main) where

-- Component diagnostics only. A successful process is not independent human
-- review, harness qualification, phase validation, or promotion evidence.

import ApprovalOracle (runApprovalOracle)
import DocumentationOracle (runDocumentationOracle)
import DispatchOracle (runDispatchOracle)
import EvidenceOracle (runEvidenceOracle)
import LegacyOracle (runLegacyOracle)
import PhaseContractOracle (runPhaseContractOracle)
import QualificationOracle (runQualificationOracle)
import SourceClosureOracle (runSourceClosureOracle)

main :: IO ()
main = do
  putStrLn "Running validation-kernel component diagnostics; this cannot qualify or promote a phase."
  runApprovalOracle
  runDocumentationOracle
  runDispatchOracle
  runEvidenceOracle
  runSourceClosureOracle
  runLegacyOracle
  runPhaseContractOracle
  runQualificationOracle
  putStrLn "Component diagnostics completed; no validation or human-review claim is implied."
