module Main (main) where

-- Component diagnostics only. A successful process is not independent reviewer
-- review, harness qualification, phase validation, or promotion evidence.

import ApprovalOracle (runApprovalOracle)
import Control.Exception (SomeException, displayException, try)
import Control.Monad (forM)
import CompilerBuildInfoOracle (runCompilerBuildInfoOracle)
import CompilerComponentPlanOracle (runCompilerComponentPlanOracle)
import CompilerElaboratedPlanOracle (runCompilerElaboratedPlanOracle)
import CompilerSourceGraphOracle (runCompilerSourceGraphOracle)
import DocumentationOracle (runDocumentationOracle)
import DispatchOracle (runDispatchOracle)
import EvidenceOracle (runEvidenceOracle)
import LegacyOracle (runLegacyOracle)
import PhaseContractOracle (runPhaseContractOracle)
import PhaseSemanticContractOracle (runPhaseSemanticContractOracle)
import PbBootstrapGrammarOracle (runPbBootstrapGrammarOracle)
import PolicyContractOracle (runPolicyContractOracle)
import QualificationOracle (runQualificationOracle)
import SourceAcquisitionOracle (runSourceAcquisitionOracle)
import SourceClosureOracle (runSourceClosureOracle)
import SourceConsumerGraphOracle (runSourceConsumerGraphOracle)
import SourceDebtBaselineOracle (runSourceDebtBaselineOracle)

main :: IO ()
main = do
  putStrLn "Running validation-kernel component diagnostics; this cannot qualify or promote a phase."
  outcomes <- forM componentOracles runComponentOracle
  case [failure | Just failure <- outcomes] of
    [] ->
      putStrLn "Component diagnostics completed; no validation or reviewer-inspection claim is implied."
    failures ->
      fail
        ( unlines
            ( "Component diagnostics reported failures after every named oracle executed; no validation or reviewer-inspection claim is implied."
                : concatMap renderFailure failures
            )
        )

componentOracles :: [(String, IO ())]
componentOracles =
  [ ("ApprovalOracle", runApprovalOracle)
  , ("DispatchOracle", runDispatchOracle)
  , ("EvidenceOracle", runEvidenceOracle)
  , ("SourceAcquisitionOracle", runSourceAcquisitionOracle)
  , ("SourceClosureOracle", runSourceClosureOracle)
  , ("PbBootstrapGrammarOracle", runPbBootstrapGrammarOracle)
  , ("SourceDebtBaselineOracle", runSourceDebtBaselineOracle)
  , ("SourceConsumerGraphOracle", runSourceConsumerGraphOracle)
  , ("CompilerBuildInfoOracle", runCompilerBuildInfoOracle)
  , ("CompilerComponentPlanOracle", runCompilerComponentPlanOracle)
  , ("CompilerElaboratedPlanOracle", runCompilerElaboratedPlanOracle)
  , ("CompilerSourceGraphOracle", runCompilerSourceGraphOracle)
  , ("LegacyOracle", runLegacyOracle)
  , ("PhaseContractOracle", runPhaseContractOracle)
  , ("PhaseSemanticContractOracle", runPhaseSemanticContractOracle)
  , ("PolicyContractOracle", runPolicyContractOracle)
  , ("DocumentationOracle", runDocumentationOracle)
  , ("QualificationOracle", runQualificationOracle)
  ]

runComponentOracle :: (String, IO ()) -> IO (Maybe (String, String))
runComponentOracle (name, action) = do
  result <- try action :: IO (Either SomeException ())
  case result of
    Left problem -> do
      putStrLn ("COMPONENT-ORACLE\t" <> name <> "\tFINDINGS")
      pure (Just (name, displayException problem))
    Right () -> do
      putStrLn ("COMPONENT-ORACLE\t" <> name <> "\tDIAGNOSTIC-EXPECTATIONS-MET")
      pure Nothing

renderFailure :: (String, String) -> [String]
renderFailure (name, detail) =
  ("  " <> name <> ":") : map ("    " <>) (lines detail)
