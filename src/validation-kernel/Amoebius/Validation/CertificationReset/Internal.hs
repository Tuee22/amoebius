{-# LANGUAGE OverloadedStrings #-}

-- | Mandatory refusal while the replacement certification issuer is absent.
--
-- This module implements only the interim stop required by the reset. It
-- does not implement accepted-baseline admission, protected OS custody,
-- authenticated issuance, dependency compatibility, or the seven-case
-- seed-custody qualification. It cannot establish a Phase-0 gate pass.
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
  = IssuerNotYetQualified

currentCertificationGeneration :: CertificationGeneration
currentCertificationGeneration = InitialAuditResetGeneration

currentCertificationIssuerStatus :: CertificationIssuerStatus
currentCertificationIssuerStatus = IssuerNotYetQualified

renderCertificationGeneration :: CertificationGeneration -> Text
renderCertificationGeneration InitialAuditResetGeneration =
  "amoebius-certification-generation-1"

renderCertificationIssuerStatus :: CertificationIssuerStatus -> Text
renderCertificationIssuerStatus IssuerNotYetQualified = "NOT YET QUALIFIED"

-- | An unavoidable refusal, not a report from which callers can extract
-- admission. The type cannot represent an empty finding inventory.
certificationAdmissionRefusal :: NonEmpty Finding
certificationAdmissionRefusal =
  case currentCertificationIssuerStatus of
    IssuerNotYetQualified ->
      finding
        "CERTIFICATION-ISSUER-UNQUALIFIED"
        "<certification-issuer>"
        "The current certification generation has no qualified protected issuer; accepted-baseline admission and authenticated receipt custody are not implemented. Legacy candidates and receipts cannot authorize validation, status changes, or live effects."
        :| []

-- | Always refused. The observations describe the required generation and
-- the absence of its issuer; they do not assert that custody was observed.
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
