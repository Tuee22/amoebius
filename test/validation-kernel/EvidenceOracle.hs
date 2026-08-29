{-# LANGUAGE OverloadedStrings #-}

module EvidenceOracle
  ( runEvidenceOracle
  ) where

-- Component diagnostic only. This module proves that the current unintegrated
-- seam refuses caller-invented candidate material; it does not perform
-- capture, qualification, a complete gate, or phase validation.

import Amoebius.Validation.Evidence
import Amoebius.Validation.Types
import Control.Monad (unless)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text

runEvidenceOracle :: IO ()
runEvidenceOracle =
  finishDiagnostics
    "EvidenceOracle"
    ( concat
        [ expectRefusalCode
            "synthetic green rows and digest-shaped strings never construct a candidate"
            "EVIDENCE-CAPTURE-UNINTEGRATED"
            (candidateFromChecks baseProvenance baseResidue baseChecks)
        , expectRefusalCode
            "a red row remains visible beside the capture refusal"
            "TEST-BLOCKER"
            ( candidateFromChecks
                baseProvenance
                baseResidue
                [documentationCheck, sourceCheck {checkFindings = [finding "TEST-BLOCKER" "subject" "red"]}]
            )
        , expectRefusalCode
            "empty discovery remains an explicit shape refusal"
            "EVIDENCE-ROWS-EMPTY"
            (candidateFromChecks baseProvenance baseResidue [])
        , expectRefusalCode
            "missing residue remains an explicit refusal"
            "EVIDENCE-RESIDUE-MISSING"
            (candidateFromChecks baseProvenance [] baseChecks)
        , expectRefusalCode
            "duplicate raw observation keys remain an explicit refusal"
            "EVIDENCE-OBSERVATION-DUPLICATE"
            ( candidateFromChecks
                baseProvenance
                baseResidue
                [ CheckResult
                    "documentation-corpus"
                    [observation "duplicate" "one", observation "duplicate" "two"]
                    []
                , sourceCheck
                ]
            )
        ]
    )

baseProvenance :: CandidateProvenance
baseProvenance =
  CandidateProvenance
    { provenanceSourceDigest = digestText '1'
    , provenanceContractDigest = digestText '2'
    , provenanceSubjectDigest = digestText '3'
    , provenanceOracleDigest = digestText '4'
    , provenanceHarnessDigest = digestText '5'
    , provenanceObserverDigest = digestText '6'
    , provenanceQualificationDigest = digestText '7'
    , provenancePredecessorDigest = "genesis"
    , provenanceExpectedRows = Set.fromList ["documentation-corpus", "source-closure"]
    }

baseResidue :: [Text]
baseResidue = ["UNVERIFIED: integrated execution and documentation correspondence gate"]

baseChecks :: [CheckResult]
baseChecks = [documentationCheck, sourceCheck]

documentationCheck :: CheckResult
documentationCheck = CheckResult "documentation-corpus" [observation "document-count" "synthetic"] []

sourceCheck :: CheckResult
sourceCheck = CheckResult "source-closure" [observation "path-count" "synthetic"] []

digestText :: Char -> Text
digestText character = Text.replicate 64 (Text.singleton character)

expectRefusalCode :: String -> Text -> Either [Finding] CandidateEvidence -> [String]
expectRefusalCode label code result =
  case result of
    Left findings
      | any ((== code) . findingCode) findings -> []
      | otherwise -> [label <> ": expected " <> Text.unpack code <> ", observed " <> show findings]
    Right _ -> [label <> ": caller-invented evidence was accepted"]

finishDiagnostics :: String -> [String] -> IO ()
finishDiagnostics name problems =
  unless
    (null problems)
    (fail (name <> " component diagnostic failures:\n  " <> Text.unpack (Text.intercalate "\n  " (map Text.pack problems))))
