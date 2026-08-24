module Amoebius.Validation.SourceDebtBaseline
  ( sourceDebtBaselineCheck
  ) where

-- The exposed facade accepts only standard values and is intentionally
-- diagnostic-only. Candidate evidence, production source types, baseline
-- declarations, observations, problems, bounds, and lifecycle folds live in
-- the package-hidden Internal module used only by Dispatch and Legacy.

import Amoebius.Validation.SourceDebtBaseline.Internal qualified as Internal
import Amoebius.Validation.Types (CheckResult)
import Data.ByteString (ByteString)
import Data.Text (Text)

sourceDebtBaselineCheck
  :: [(FilePath, Text, Text, ByteString)]
  -> CheckResult
sourceDebtBaselineCheck = Internal.sourceDebtRawDiagnosticCheck
