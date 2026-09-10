{-# LANGUAGE OverloadedStrings #-}

module CertificationAdmissionInternalOracle
  ( main
  , runCertificationAdmissionInternalOracle
  ) where

-- Component regression for the mandatory early refusal only. Passing this
-- oracle does not qualify an issuer, authenticate a receipt, exercise the
-- seven-case OS custody corpus, or complete Phase 0. Expectations are literal
-- and independent of the production reset diagnostic and generation renderer.
--
-- The labelled error values deliberately have no usable contents. Evaluating
-- one before refusing raises an uncaught exception and fails the regression;
-- exceptions are never interpreted as evidence of a successful refusal.

import Amoebius.Validation.BootstrapQualification.Internal (acquireQualifiedBootstrapProtocol)
import Amoebius.Validation.Dispatch.Internal (validatePhase)
import Amoebius.Validation.Evidence.Internal
  ( acquireImmediatePredecessorEvidence
  , installPublishedCandidateEvidenceReceipt
  )
import Amoebius.Validation.GatePass.Internal
  ( verifyPublishedGatePass
  )
import Amoebius.Validation.StatusProjection.Internal (authorizeStatusProjection)
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding (..)
  , Observation (..)
  )
import Control.Monad (forM_, unless)

main :: IO ()
main = runCertificationAdmissionInternalOracle

runCertificationAdmissionInternalOracle :: IO ()
runCertificationAdmissionInternalOracle = do
  -- This independently literal domain includes the unimplemented and live
  -- phase ordinals. Neither a usable Git executable nor a repository exists
  -- at these invalid paths, so reaching their validation cannot satisfy the
  -- expected reset result.
  forM_ [0 .. 95] $ \ordinal -> do
    result <- validatePhase invalidGitPath invalidRepositoryRoot ordinal
    unless (result == expectedResetResult) $
      fail
        ( unlines
            [ "CertificationAdmissionInternalOracle: validatePhase " <> show ordinal
            , "Expected: " <> show expectedResetResult
            , "Observed: " <> show result
            ]
        )

  bootstrapQualification <-
    acquireQualifiedBootstrapProtocol
      (error "CertificationAdmissionInternalOracle: bootstrap root evaluated before reset refusal")
      (error "CertificationAdmissionInternalOracle: genesis trust evaluated before reset refusal")
      (error "CertificationAdmissionInternalOracle: source snapshot evaluated before reset refusal")
  expectRefusal "bootstrap compiler qualification" bootstrapQualification

  predecessorWithoutInputs <-
    acquireImmediatePredecessorEvidence
      (error "CertificationAdmissionInternalOracle: predecessor root evaluated before reset refusal")
      1
      (error "CertificationAdmissionInternalOracle: predecessor source digest evaluated before reset refusal")
  expectRefusal "predecessor admission with unavailable inputs" predecessorWithoutInputs

  predecessorWithInvalidRoot <-
    acquireImmediatePredecessorEvidence invalidRepositoryRoot 1 "not-an-acquired-source-digest"
  expectRefusal "predecessor admission with an invalid root" predecessorWithInvalidRoot

  installation <-
    installPublishedCandidateEvidenceReceipt
      (error "CertificationAdmissionInternalOracle: receipt publication evaluated before reset refusal")
  expectRefusal "receipt installation" installation

  verification <-
    verifyPublishedGatePass
      (error "CertificationAdmissionInternalOracle: candidate publication evaluated before reset refusal")
  expectRefusal "gate-pass verification" verification

  expectRefusal
    "status projection authorization"
    ( authorizeStatusProjection
        (error "CertificationAdmissionInternalOracle: authorization token evaluated before reset refusal")
        (error "CertificationAdmissionInternalOracle: proposed projection evaluated before reset refusal")
    )

-- NUL is forbidden in an OS path. No filesystem probe or temporary directory
-- is needed to manufacture the unavailable repository/tool inputs.
invalidGitPath :: FilePath
invalidGitPath = "/certification-admission-oracle/invalid\0git"

invalidRepositoryRoot :: FilePath
invalidRepositoryRoot = "/certification-admission-oracle/invalid\0repository"

expectRefusal :: String -> Either [Finding] value -> IO ()
expectRefusal label result =
  case result of
    Left findings ->
      unless (findings == [expectedFinding]) $
        fail
          ( unlines
              [ "CertificationAdmissionInternalOracle: " <> label
              , "Expected: " <> show [expectedFinding]
              , "Observed: " <> show findings
              ]
          )
    Right _ ->
      fail ("CertificationAdmissionInternalOracle: " <> label <> " admitted an unqualified authority")

expectedResetResult :: CheckResult
expectedResetResult =
  CheckResult
    { checkName = "certification-reset"
    , checkObservations =
        [ Observation "certification.generation" "amoebius-certification-generation-1"
        , Observation "certification.issuer-status" "UNAVAILABLE AT THIS ENTRY POINT"
        ]
    , checkFindings = [expectedFinding]
    }

expectedFinding :: Finding
expectedFinding =
  Finding
    "CERTIFICATION-ISSUER-UNQUALIFIED"
    "<certification-issuer>"
    "The unprotected certification entry point has no issuer authority. Only the root-owned generation-1 supervisor can qualify the accepted baseline and authenticated receipt custody; legacy candidates and receipts cannot authorize validation, status changes, or live effects."
