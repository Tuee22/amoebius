{-# LANGUAGE OverloadedStrings #-}

-- | Refusal-only raw diagnostic for the tracked-source closure seam.
--
-- No snapshot, acquisition token, classifier value, parser, projection, bound,
-- or candidate-capable check crosses this facade.  The claimed identity and
-- inventory are caller input; the implementation independently bounds and
-- recomputes them and always retains custody and complete-discovery residue.
module Amoebius.Validation.SourceClosure
  ( sourceClosureDiagnostic
  ) where

import Amoebius.Validation.SourceClosure.Internal
  ( rawSourceClosureDiagnostic
  )
import Amoebius.Validation.Types (CheckResult)
import Data.ByteString (ByteString)
import Data.Text (Text)

-- | Diagnose a claimed source-snapshot identity and raw canonical inventory.
-- Each tuple is @(POSIX path, Git mode, Git object identity, exact blob bytes)@.
-- An internally coherent result is still permanently refusing.
sourceClosureDiagnostic
  :: Text
  -> [(FilePath, Text, Text, ByteString)]
  -> CheckResult
sourceClosureDiagnostic = rawSourceClosureDiagnostic
