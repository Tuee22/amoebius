{-# LANGUAGE OverloadedStrings #-}

{- | Neutral carrier for acquired phase-contract evidence.

The carrier lives below both the phase-contract evaluator and Legacy so the
two modules do not form an import cycle.  Only the package-hidden evaluator
calls 'sealAcquiredPhaseContractEvidence'; public diagnostic document lists
cannot obtain the opaque value.
-}
module Amoebius.Validation.PhaseContract.Evidence.Internal (
    AcquiredPhaseContractEvidence,
    acquiredPhaseContractEvidenceCheck,
    acquiredPhaseContractEvidenceSnapshot,
    sealAcquiredPhaseContractEvidence,
) where

import Amoebius.Validation.Types (CheckResult)
import Data.Text (Text)

data AcquiredPhaseContractEvidence
    = AcquiredPhaseContractEvidence Text CheckResult
    deriving (Eq, Show)

sealAcquiredPhaseContractEvidence :: Text -> CheckResult -> AcquiredPhaseContractEvidence
sealAcquiredPhaseContractEvidence = AcquiredPhaseContractEvidence

acquiredPhaseContractEvidenceCheck :: AcquiredPhaseContractEvidence -> CheckResult
acquiredPhaseContractEvidenceCheck (AcquiredPhaseContractEvidence _ result) = result

acquiredPhaseContractEvidenceSnapshot :: AcquiredPhaseContractEvidence -> Text
acquiredPhaseContractEvidenceSnapshot (AcquiredPhaseContractEvidence identity _) = identity
