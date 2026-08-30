module Main (main) where

-- Component diagnostics only. A successful process is not a complete qualified
-- gate, phase validation, or status evidence.

import GatePassOracle (runGatePassOracle)
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
import CapabilityGraphOracle (runCapabilityGraphOracle)
import MutationCoverageOracle (runMutationCoverageOracle)
import PlanRevisionOracle (runPlanRevisionOracle)
import PhaseSemanticContractOracle (runPhaseSemanticContractOracle)
import PbBootstrapGrammarOracle (runPbBootstrapGrammarOracle)
import PolicyContractOracle (runPolicyContractOracle)
import QualificationOracle (runQualificationOracle)
import SourceClosureOracle (runSourceClosureOracle)
import SourceConsumerGraphOracle (runSourceConsumerGraphOracle)
import SourceDebtBaselineOracle (runSourceDebtBaselineOracle)

main :: IO ()
main = do
  putStrLn "Running validation-kernel component diagnostics; this cannot make a phase gate pass."
  outcomes <- forM componentOracles runComponentOracle
  case [failure | Just failure <- outcomes] of
    [] ->
      putStrLn "Component diagnostics completed; no validation or documentation-correspondence claim is implied."
    failures ->
      fail
        ( unlines
            ( "Component diagnostics reported failures after every named oracle executed; no validation or documentation-correspondence claim is implied."
                : concatMap renderFailure failures
            )
        )

componentOracles :: [(String, IO ())]
componentOracles =
  [ ("GatePassOracle", runGatePassOracle)
  , ("DispatchOracle", runDispatchOracle)
  , ("EvidenceOracle", runEvidenceOracle)
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
  , ("CapabilityGraphOracle", runCapabilityGraphOracle)
  , ("MutationCoverageOracle", runMutationCoverageOracle)
  , ("PlanRevisionOracle", runPlanRevisionOracle)
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
