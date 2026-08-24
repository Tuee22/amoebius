-- | Bounded refusal-only external PhaseContract facade.
--
-- Candidate-capable phase/tracker and semantic-join checks are package-hidden
-- in PhaseContract.Internal. Caller-authored Markdown can request only the
-- resource-bounded structural diagnostic, which always carries the permanent
-- diagnostic-only refusal.
module Amoebius.Validation.PhaseContract
  ( phaseContractDiagnostic
  ) where

import Amoebius.Validation.PhaseContract.Internal qualified as Internal
import Amoebius.Validation.Types (CheckResult)
import Data.Text (Text)

phaseContractDiagnostic :: [(FilePath, Text)] -> CheckResult
phaseContractDiagnostic = Internal.checkPhaseContractStructure
