-- | Refusal-only public PolicyContract diagnostic.
--
-- The policy model, canonical values, serializers, digest helpers, and
-- candidate-capable checks are package-hidden in PolicyContract.Internal.
module Amoebius.Validation.PolicyContract
  ( policyContractDiagnostic
  ) where

import Amoebius.Validation.PolicyContract.Internal (policyContractDiagnostic)
