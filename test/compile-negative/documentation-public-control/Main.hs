module Main (main) where

import Amoebius.Validation.Documentation
  ( documentationInventoryDiagnostic
  , documentationPolicyOwnerDiagnostic
  , documentationStructureDiagnostic
  , documentationWorktreeDiagnostic
  )

main :: IO ()
main = do
  documentationInventoryDiagnostic [] `seq` pure ()
  documentationPolicyOwnerDiagnostic [] `seq` pure ()
  documentationStructureDiagnostic [] `seq` pure ()
  documentationWorktreeDiagnostic `seq` pure ()
