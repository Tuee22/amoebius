{-# LANGUAGE OverloadedStrings #-}

-- | Independent literal oracle for the finite Phase-0 custody corpus.
--
-- The supervisor supplies only its raw, line-oriented observations.  This
-- module does not import its case type, labels, result constructors, path
-- policy, signing encoder, or process-control predicates.
module Amoebius.Validation.SeedCustodyOracle.Internal
  ( checkSeedCustodyTranscript
  , acceptedSeedCustodyTranscript
  ) where

import Amoebius.Validation.Types
  ( CheckResult (..)
  , finding
  , observation
  )
import Data.ByteString (ByteString)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding

acceptedSeedCustodyTranscript :: ByteString
acceptedSeedCustodyTranscript =
  TextEncoding.encodeUtf8
    ( Text.unlines
        [ "protected-issuer-success\taccepted"
        , "old-generation-refusal\tSEED-RECEIPT-GENERATION"
        , "forged-receipt-matching-copy-refusal\tSEED-RECEIPT-SIGNATURE"
        , "candidate-baseline-replacement-denial\tpermission-denied"
        , "authority-ancestor-replacement-denial\tpermission-denied"
        , "private-issuer-read-denial\tpermission-denied"
        , "inherited-authority-impersonation-denial\tno-authority-inherited"
        ]
    )

checkSeedCustodyTranscript :: ByteString -> CheckResult
checkSeedCustodyTranscript actual =
  CheckResult
    { checkName = "seed-custody-oracle"
    , checkObservations =
        [ observation "seed-custody.oracle-cases" "7"
        , observation "seed-custody.oracle-comparison" comparison
        ]
    , checkFindings =
        [ finding
            "SEED-CUSTODY-ORACLE-MISMATCH"
            "<seed-custody-transcript>"
            "The observed custody transcript does not equal the independently authored seven-case expectation."
        | actual /= acceptedSeedCustodyTranscript
        ]
    }
 where
  comparison
    | actual == acceptedSeedCustodyTranscript = "exact-match"
    | otherwise = "refused"
