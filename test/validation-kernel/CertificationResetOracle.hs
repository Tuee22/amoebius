{-# LANGUAGE OverloadedStrings #-}

module CertificationResetOracle
  ( main
  , runCertificationResetOracle
  ) where

-- Component safety regression only. An oracle success means that reset
-- admission still refuses; it is neither a phase pass nor seed-custody
-- qualification. The production diagnostic has no argument or IO input.
-- Expected generation and refusal bytes below are independent literals, never
-- obtained from the production generation renderer, environment, or clock.

import Amoebius.Validation.CertificationReset (certificationResetDiagnostic)
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding (..)
  , Observation (..)
  )
import Control.Monad (unless)

main :: IO ()
main = runCertificationResetOracle

runCertificationResetOracle :: IO ()
runCertificationResetOracle =
  unless (certificationResetDiagnostic == expectedRefusal) $
    fail
      ( unlines
          [ "CertificationResetOracle: the closed reset-admission refusal changed."
          , "Expected: " <> show expectedRefusal
          , "Observed: " <> show certificationResetDiagnostic
          ]
      )

-- Exact equality requires the sole refusal and exactly these observations.
-- Empty findings, additional outcomes, a changed generation, and an issuer
-- success claim all fail this regression. The standalone main can also be run
-- in fresh environments without deriving a different expectation from them.
expectedRefusal :: CheckResult
expectedRefusal =
  CheckResult
    { checkName = "certification-reset"
    , checkObservations =
        [ Observation "certification.generation" "amoebius-certification-generation-1"
        , Observation "certification.issuer-status" "UNAVAILABLE AT THIS ENTRY POINT"
        ]
    , checkFindings =
        [ Finding
            "CERTIFICATION-ISSUER-UNQUALIFIED"
            "<certification-issuer>"
            "The unprotected certification entry point has no issuer authority. Only the root-owned generation-1 supervisor can qualify the accepted baseline and authenticated receipt custody; legacy candidates and receipts cannot authorize validation, status changes, or live effects."
        ]
    }
