module Amoebius.Validation.Documentation
  ( documentationInventoryDiagnostic
  , documentationPolicyOwnerDiagnostic
  , documentationStructureDiagnostic
  , documentationWorktreeDiagnostic
  ) where

import Amoebius.Validation.Documentation.Internal
  ( checkCorpusDiagnostic
  , checkDocumentStructure
  , checkInventoryDiagnostic
  , checkPolicyOwnerDiagnostic
  )
import Amoebius.Validation.Types (CheckResult)
import Data.Text (Text)

-- Public diagnostic facades deliberately expose only refusal-bearing
-- CheckResults. Candidate consumers import the package-hidden implementation
-- after authenticated snapshot capture.
documentationStructureDiagnostic :: [(FilePath, Text)] -> CheckResult
documentationStructureDiagnostic = checkDocumentStructure

documentationInventoryDiagnostic :: [(FilePath, Text)] -> CheckResult
documentationInventoryDiagnostic = checkInventoryDiagnostic

documentationPolicyOwnerDiagnostic :: [(FilePath, Text)] -> CheckResult
documentationPolicyOwnerDiagnostic = checkPolicyOwnerDiagnostic

documentationWorktreeDiagnostic :: FilePath -> IO CheckResult
documentationWorktreeDiagnostic = checkCorpusDiagnostic
