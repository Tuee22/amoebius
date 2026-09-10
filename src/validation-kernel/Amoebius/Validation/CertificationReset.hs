-- | Public diagnostic for the mandatory certification reset refusal.
--
-- This diagnostic cannot admit a candidate or receipt. The protected
-- generation-1 supervisor is a separate OS-qualified path; naming its
-- generation here is not evidence of accepted-baseline or receipt authority.
module Amoebius.Validation.CertificationReset
  ( certificationResetDiagnostic
  ) where

import Amoebius.Validation.CertificationReset.Internal (certificationResetDiagnostic)
