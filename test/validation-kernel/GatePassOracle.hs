{-# LANGUAGE OverloadedStrings #-}

module GatePassOracle
  ( runGatePassOracle
  ) where

import Amoebius.Validation.GatePass
import Control.Monad (unless)
import Data.Set qualified as Set
import Data.Text qualified as Text

runGatePassOracle :: IO ()
runGatePassOracle = do
  let candidate =
        CandidateBinding
          { candidatePhase = "00"
          , candidateSourceDigest = digestText '1'
          , candidateContractDigest = digestText '2'
          , candidateHarnessDigest = digestText '3'
          , candidateEvidenceDigest = digestText '4'
          , candidatePredecessorDigest = "genesis"
          , candidateProjectionDigest = digestText '5'
          , candidateStatusFields = requiredStatusFields
          }
      passing =
        GatePass
          { passPhase = candidatePhase candidate
          , passSourceDigest = candidateSourceDigest candidate
          , passContractDigest = candidateContractDigest candidate
          , passHarnessDigest = candidateHarnessDigest candidate
          , passEvidenceDigest = candidateEvidenceDigest candidate
          , passPredecessorDigest = candidatePredecessorDigest candidate
          , passProjectionDigest = candidateProjectionDigest candidate
          , passStatusFields = candidateStatusFields candidate
          , passRows = requiredGateRows
          , passQualificationSucceeded = True
          , passCleanRunSucceeded = True
          , passSourceUnchanged = True
          }
      check label expected actual = expectEqual label expected actual
      verify = verifyGatePass candidate
      problems =
        concat
          [ check "a complete qualified passing test is sufficient" (Right ()) (verify passing)
          , check "phase binding" (Left GatePassPhaseMismatch) (verify (passing {passPhase = "01"}))
          , check "source binding" (Left GatePassSourceMismatch) (verify (passing {passSourceDigest = digestText '6'}))
          , check "contract binding" (Left GatePassContractMismatch) (verify (passing {passContractDigest = digestText '7'}))
          , check "harness binding" (Left GatePassHarnessMismatch) (verify (passing {passHarnessDigest = digestText '8'}))
          , check "evidence binding" (Left GatePassEvidenceMismatch) (verify (passing {passEvidenceDigest = digestText '9'}))
          , check "predecessor binding" (Left GatePassPredecessorMismatch) (verify (passing {passPredecessorDigest = digestText 'a'}))
          , check "status projection binding" (Left GatePassProjectionMismatch) (verify (passing {passProjectionDigest = digestText 'b'}))
          , check
              "status fields cannot widen"
              (Left GatePassStatusFieldsMismatch)
              (verify (passing {passStatusFields = Set.insert "documentation" requiredStatusFields}))
          , check
              "candidate status fields must be exact"
              (Left GatePassStatusFieldsMismatch)
              (verifyGatePass (candidate {candidateStatusFields = Set.singleton "phase-status"}) passing)
          , check
              "every required row must pass"
              (Left GatePassRowsIncomplete)
              (verify (passing {passRows = Set.delete "Observer" requiredGateRows}))
          , check
              "unexpected rows are not a complete exact gate"
              (Left GatePassRowsIncomplete)
              (verify (passing {passRows = Set.insert "Self report" requiredGateRows}))
          , check
              "qualification must pass"
              (Left GatePassQualificationFailed)
              (verify (passing {passQualificationSucceeded = False}))
          , check
              "clean run must pass"
              (Left GatePassCleanRunFailed)
              (verify (passing {passCleanRunSucceeded = False}))
          , check
              "source must remain unchanged"
              (Left GatePassSourceChanged)
              (verify (passing {passSourceUnchanged = False}))
          , check
              "one-digit phase is not canonical"
              (Left GatePassBindingMalformed)
              (verifyGatePass (candidate {candidatePhase = "0"}) passing)
          , check
              "out-of-domain phase is not canonical"
              (Left GatePassBindingMalformed)
              (verifyGatePass (candidate {candidatePhase = "96"}) passing)
          , check
              "uppercase source digest is not canonical"
              (Left GatePassBindingMalformed)
              (verifyGatePass (candidate {candidateSourceDigest = Text.replicate 64 "A"}) passing)
          , check
              "short contract digest is not canonical"
              (Left GatePassBindingMalformed)
              (verifyGatePass (candidate {candidateContractDigest = "abc"}) passing)
          , check
              "non-digest predecessor is not canonical"
              (Left GatePassBindingMalformed)
              (verifyGatePass (candidate {candidatePredecessorDigest = "phase-previous"}) passing)
          , check
              "newline injection is not canonical"
              (Left GatePassBindingMalformed)
              (verify (passing {passPhase = "00\n01"}))
          ]
  finishDiagnostics "GatePassOracle" problems

digestText :: Char -> Text.Text
digestText character = Text.replicate 64 (Text.singleton character)

expectEqual :: (Eq value, Show value) => String -> value -> value -> [String]
expectEqual label expected actual
  | actual == expected = []
  | otherwise = [label <> ": expected " <> show expected <> ", observed " <> show actual]

finishDiagnostics :: String -> [String] -> IO ()
finishDiagnostics name problems =
  unless (null problems) (fail (name <> " component diagnostic failures:\n  " <> Text.unpack (Text.intercalate "\n  " (fmap Text.pack problems))))
