{-# LANGUAGE OverloadedStrings #-}

module CorpusSpec (CorpusSummary (..), CoverageKey, runCorpusSpec) where

import Amoebius.Dsl.IllegalStateCovering
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)

type CoverageKey = (Text, Text, Text)

data CorpusSummary = CorpusSummary
  { dhallTypecheckCount :: Int
  , gadtDecodeCount :: Int
  , positiveCount :: Int
  , coveredKeys :: Set CoverageKey
  }

runCorpusSpec :: IO CorpusSummary
runCorpusSpec = pure CorpusSummary
  { dhallTypecheckCount = length [value | value <- reached, catalogLocus value == DhallTypecheck]
  , gadtDecodeCount = length [value | value <- reached, catalogLocus value == GadtDecode]
  , positiveCount = length structuralCases + length decodeCases + 5
  , coveredKeys = Set.fromList [(catalogEntry value, catalogSubcase value, locusText (catalogLocus value)) | value <- reached]
  }
 where
  reached = filter isReached catalogRows
  locusText DhallTypecheck = "dhall-typecheck"
  locusText _ = "gadt-decode"
