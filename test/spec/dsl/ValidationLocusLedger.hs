{-# LANGUAGE OverloadedStrings #-}

module ValidationLocusLedger (runValidationLocusLedger) where

import Amoebius.Dsl.IllegalStateCovering
import CorpusSpec (CoverageKey)
import Control.Monad (unless)
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (createDirectoryIfMissing)

runValidationLocusLedger :: Set CoverageKey -> IO (Int, Int, Int)
runValidationLocusLedger coverage = do
  let reached = filter isReached catalogRows
      expected = Set.fromList [(catalogEntry value, catalogSubcase value, locusText (catalogLocus value)) | value <- reached]
  unless (coverage == expected) (fail "Haskell corpus coverage diverged from the closed Haskell catalogue")
  createDirectoryIfMissing True ".build/dsl/illegal-state-corpus"
  TextIO.writeFile ".build/dsl/illegal-state-corpus/validation-locus-ledger.tsv" $ Text.unlines
    ("# Register-1 only; Tier-2/model-runtime correspondence UNVERIFIED" : map render catalogRows)
  pure (length reached, length catalogRows - length reached, 10)
 where
  locusText DhallTypecheck = "dhall-typecheck"
  locusText _ = "gadt-decode"
  render value = Text.intercalate "\t" [catalogEntry value, catalogSubcase value, Text.pack (show (catalogLocus value)), disposition value]
