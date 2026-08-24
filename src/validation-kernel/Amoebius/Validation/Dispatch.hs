-- | Refusal-only external dispatch facade.
--
-- The executable entry point is retained for the public CLI, but it cannot
-- produce candidate evidence.  Snapshot constructors, acquisition functions,
-- component composition, and readiness projections remain package-hidden.
module Amoebius.Validation.Dispatch
  ( dispatchDiagnostic
  , runValidateCommand
  ) where

import Amoebius.Validation.Dispatch.Internal
  ( dispatchDiagnostic
  , runValidateCommand
  )
