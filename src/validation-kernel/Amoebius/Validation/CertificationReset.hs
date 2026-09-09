-- | Public diagnostic for the mandatory certification reset refusal.
--
-- This diagnostic cannot admit a candidate or receipt. The replacement
-- certification generation has no qualified protected issuer yet; its
-- identity is not evidence of accepted-baseline or receipt authority.
module Amoebius.Validation.CertificationReset
  ( certificationResetDiagnostic
  ) where

import Amoebius.Validation.CertificationReset.Internal (certificationResetDiagnostic)
