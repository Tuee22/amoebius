{-# LANGUAGE OverloadedStrings #-}

-- | Stage 6 of the runner (gate_runner_doctrine.md section 3): fill the
-- eighteen-row candidate from the run's own observations. No row is
-- caller-supplied; a row without an observation is @unverified@, never green.
module Amoebius.Validation.Runner.Capture
  ( Candidate (..)
  , CandidateRow (..)
  , RowVerdict (..)
  , candidateGreen
  , renderCandidate
  , renderVerdict
  ) where

import Amoebius.Validation.GateSpec (GateCategory (..), allGateCategories, renderGateCategory)
import Data.Text (Text)
import Data.Text qualified as Text

data RowVerdict = Green | Red | Unverified
  deriving (Eq, Ord, Show)

renderVerdict :: RowVerdict -> Text
renderVerdict verdict = case verdict of
  Green -> "green"
  Red -> "red"
  Unverified -> "unverified"

data CandidateRow = CandidateRow
  { rowCategory :: GateCategory
  , rowVerdict :: RowVerdict
  , rowObservations :: [(Text, Text)]
  }
  deriving (Eq, Show)

data Candidate = Candidate
  { candidatePhase :: Int
  , candidateCapability :: Text
  , candidateSpecDigest :: Text
  , candidateChallenge :: Text
  , candidateChain :: Text
  , candidateReproducibleCore :: Text
  , candidateRows :: [CandidateRow]
  }
  deriving (Eq, Show)

-- | Every one of the eighteen rows is present, in order, green, and carries at
-- least one observation.
candidateGreen :: Candidate -> Bool
candidateGreen candidate =
  map rowCategory (candidateRows candidate) == allGateCategories
    && all (\row -> rowVerdict row == Green && not (null (rowObservations row))) (candidateRows candidate)

-- | The tab-separated candidate: a header, then one line per row and one per
-- observation beneath it.
renderCandidate :: Candidate -> Text
renderCandidate candidate =
  Text.unlines
    ( [ "candidate\tphase=" <> Text.pack (show (candidatePhase candidate)) <> "\tcapability=" <> candidateCapability candidate
      , "spec-digest\t" <> candidateSpecDigest candidate
      , "challenge\t" <> candidateChallenge candidate
      , "chain\t" <> candidateChain candidate
      , "reproducible-core\t" <> candidateReproducibleCore candidate
      ]
        <> concat
          [ ("row\t" <> renderGateCategory (rowCategory row) <> "\t" <> renderVerdict (rowVerdict row))
              : [ "observation\t" <> renderGateCategory (rowCategory row) <> "\t" <> key <> "\t" <> Text.replace "\n" " " value
                | (key, value) <- rowObservations row
                ]
          | row <- candidateRows candidate
          ]
    )
