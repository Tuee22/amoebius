module Main (main) where

-- Component diagnostics only. A successful process is not independent human
-- review, harness qualification, phase validation, or promotion evidence.

import ApprovalOracle (runApprovalOracle)
import Control.Exception (SomeException, displayException, try)
import Control.Monad (forM)
import DocumentationOracle (runDocumentationOracle)
import DispatchOracle (runDispatchOracle)
import EvidenceOracle (runEvidenceOracle)
import LegacyOracle (runLegacyOracle)
import PhaseContractOracle (runPhaseContractOracle)
import PolicyContractOracle (runPolicyContractOracle)
import QualificationOracle (runQualificationOracle)
import SourceClosureOracle (runSourceClosureOracle)

main :: IO ()
main = do
  putStrLn "Running validation-kernel component diagnostics; this cannot qualify or promote a phase."
  outcomes <- forM componentOracles runComponentOracle
  case [failure | Just failure <- outcomes] of
    [] ->
      putStrLn "Component diagnostics completed; no validation or human-review claim is implied."
    failures ->
      fail
        ( unlines
            ( "Component diagnostics reported failures after every named oracle executed; no validation or human-review claim is implied."
                : concatMap renderFailure failures
            )
        )

componentOracles :: [(String, IO ())]
componentOracles =
  [ ("ApprovalOracle", runApprovalOracle)
  , ("DispatchOracle", runDispatchOracle)
  , ("EvidenceOracle", runEvidenceOracle)
  , ("SourceClosureOracle", runSourceClosureOracle)
  , ("LegacyOracle", runLegacyOracle)
  , ("PhaseContractOracle", runPhaseContractOracle)
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
      putStrLn ("COMPONENT-ORACLE\t" <> name <> "\tNO-FINDINGS")
      pure Nothing

renderFailure :: (String, String) -> [String]
renderFailure (name, detail) =
  ("  " <> name <> ":") : map ("    " <>) (lines detail)
