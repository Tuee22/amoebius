module Main (main) where

-- Paired positive control: the sole refusal-only public front door must remain
-- importable from an external package client while every detachable parser,
-- expectation, manifest, and verifier value remains private.
import Amoebius.Validation.SourceAcquisition
  ( sourceAcquisitionDiagnostic
  )

main :: IO ()
main = sourceAcquisitionDiagnostic `seq` pure ()
