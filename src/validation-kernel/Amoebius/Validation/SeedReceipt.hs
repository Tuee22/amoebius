-- | Public cryptographic diagnostic for a Phase-0 seed control acknowledgement.
--
-- The caller supplies both the key and the expected context. A matching
-- signature establishes only that conditional cryptographic check. Every
-- result retains an explicit custody-unverified finding; this interface
-- cannot admit a baseline, issue a receipt, or authorize a phase pass.
-- This closed acknowledgement protocol requires canonical signature scalars
-- and canonical nonidentity prime-order public-key and signature R points.
module Amoebius.Validation.SeedReceipt
  ( SeedReceiptExpectation (..)
  , seedReceiptDiagnostic
  ) where

import Amoebius.Validation.SeedReceipt.Internal
  ( SeedReceiptExpectation (..)
  , seedReceiptDiagnostic
  )
