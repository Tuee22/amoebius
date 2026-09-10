{-# LANGUAGE OverloadedStrings #-}

-- | Mandatory refusal at certification entry points lacking protected custody.
--
-- This module is the deliberately non-authoritative public diagnostic seam.
-- The qualified generation-1 supervisor is separate and package-hidden; no
-- value exposed here can borrow its accepted-baseline or receipt authority.
--
-- The closed generation identifies which certification regime is required;
-- it is not an acquired authority token. Neither generation nor issuer status
-- is selected from Markdown, dates, arguments, environment, or local files.
-- There is no qualified status, admission constructor, override, or success
-- path. Previously issued candidates and receipts cannot change this result.
--
-- Authority entry points must consume the nonempty refusal before running a
-- phase, verifying a gate pass, admitting a predecessor, or issuing a receipt.
-- Replacing this boundary requires the real protected issuer and its finite
-- qualification; changing the diagnostic text cannot supply that authority.
module Amoebius.Validation.CertificationReset.Internal
  ( certificationAdmissionRefusal
  , certificationResetDiagnostic
  ) where

import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding
  , finding
  , observation
  )
import Data.List.NonEmpty (NonEmpty (..))
import Data.List.NonEmpty qualified as NonEmpty
import Data.Text (Text)

data CertificationGeneration
  = InitialAuditResetGeneration

data CertificationIssuerStatus
  = IssuerUnavailableAtThisEntryPoint

currentCertificationGeneration :: CertificationGeneration
currentCertificationGeneration = InitialAuditResetGeneration

currentCertificationIssuerStatus :: CertificationIssuerStatus
currentCertificationIssuerStatus = IssuerUnavailableAtThisEntryPoint

renderCertificationGeneration :: CertificationGeneration -> Text
renderCertificationGeneration InitialAuditResetGeneration =
  "amoebius-certification-generation-1"

renderCertificationIssuerStatus :: CertificationIssuerStatus -> Text
renderCertificationIssuerStatus IssuerUnavailableAtThisEntryPoint = "UNAVAILABLE AT THIS ENTRY POINT"

-- | An unavoidable refusal, not a report from which callers can extract
-- admission. The type cannot represent an empty finding inventory.
certificationAdmissionRefusal :: NonEmpty Finding
certificationAdmissionRefusal =
  case currentCertificationIssuerStatus of
    IssuerUnavailableAtThisEntryPoint ->
      finding
        "CERTIFICATION-ISSUER-UNQUALIFIED"
        "<certification-issuer>"
        "The unprotected certification entry point has no issuer authority. Only the root-owned generation-1 supervisor can qualify the accepted baseline and authenticated receipt custody; legacy candidates and receipts cannot authorize validation, status changes, or live effects."
        :| []

-- | Always refused. The observations describe the required generation and
-- the absence of authority at this entry point; they do not assert custody.
certificationResetDiagnostic :: CheckResult
certificationResetDiagnostic =
  CheckResult
    { checkName = "certification-reset"
    , checkObservations =
        [ observation
            "certification.generation"
            (renderCertificationGeneration currentCertificationGeneration)
        , observation
            "certification.issuer-status"
            (renderCertificationIssuerStatus currentCertificationIssuerStatus)
        ]
    , checkFindings = NonEmpty.toList certificationAdmissionRefusal
    }
