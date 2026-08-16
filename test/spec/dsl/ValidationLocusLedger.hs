{-# LANGUAGE OverloadedStrings #-}

module ValidationLocusLedger
  ( runValidationLocusLedger
  ) where

import CorpusSpec (CoverageKey)
import Control.Monad (unless)
import Data.List (sort)
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import System.Directory (createDirectoryIfMissing)

data RegistryRow = RegistryRow
  { entry :: Text
  , subcase :: Text
  , locus :: Text
  , owner :: Text
  , family :: Text
  }
  deriving stock (Eq, Ord, Show)

runValidationLocusLedger :: Set CoverageKey -> IO (Int, Int)
runValidationLocusLedger corpusCoverage = do
  registry <- loadRegistry
  compileCoverage <- loadCompileCoverage
  let allCoverage = corpusCoverage <> compileCoverage
      reached = filter isReached registry
      expected = Set.fromList [(entry row, subcase row, locus row) | row <- reached]
      missing = expected Set.\\ allCoverage
      unexpected = allCoverage Set.\\ expected
  assert (Set.null missing) ("reached registry rows have no rejecting fixture: " <> show (Set.toList missing))
  assert (Set.null unexpected) ("fixture coverage diverges from reached registry rows: " <> show (Set.toList unexpected))
  validateDeferred registry
  emitLedger registry
  pure (length reached, length registry - length reached)

loadRegistry :: IO [RegistryRow]
loadRegistry = do
  rows <- rowsOf "dhall/examples/locus_registry.tsv"
  traverse parseRow rows
 where
  parseRow columns = case columns of
    [entryValue, subcaseValue, locusValue, ownerValue, familyValue] ->
      pure (RegistryRow entryValue subcaseValue locusValue ownerValue familyValue)
    _ -> failTest "malformed locus_registry.tsv row"

loadCompileCoverage :: IO (Set CoverageKey)
loadCompileCoverage = do
  rows <- rowsOf "test/oracle/illegal_state_corpus/compile_fail.tsv"
  pure (Set.fromList (concatMap keys rows))
 where
  keys columns = case columns of
    [_caseName, entries, _legal, _illegal, _expected] ->
      [ (entryValue, subcaseValue, "Gate-2-decoder")
      | binding <- Text.splitOn "," entries
      , let pair = Text.splitOn ":" binding
      , [entryValue, subcaseValue] <- [pair]
      ]
    _ -> []

isReached :: RegistryRow -> Bool
isReached row = ownerNumber (owner row) <= 6 && locus row `elem` ["Gate-1-editor", "Gate-2-decoder"]

ownerNumber :: Text -> Int
ownerNumber ownerValue = case reads (Text.unpack (Text.drop (Text.length "Phase-") ownerValue)) of
  [(number, "")] -> number
  _ -> 999

validateDeferred :: [RegistryRow] -> IO ()
validateDeferred rows = do
  forEach [row | row <- rows, locus row == "rendered-output-golden"] $ \row ->
    assert (ownerNumber (owner row) >= 13) ("rendered row is owned before Phase 13: " <> show row)
  forEach [row | row <- rows, locus row == "Gate-3-astcheck"] $ \row ->
    assert (owner row == "Phase-14") ("Gate-3 row is not owned by Phase 14: " <> show row)
  forEach [row | row <- rows, locus row == "provision-seal"] $ \row ->
    assert (ownerNumber (owner row) >= 7) ("provision row is owned before the folds: " <> show row)
 where
  forEach = flip mapM_

emitLedger :: [RegistryRow] -> IO ()
emitLedger rows = do
  createDirectoryIfMissing True ".build/dsl/illegal-state-corpus"
  Text.writeFile ".build/dsl/illegal-state-corpus/validation-locus-ledger.tsv" $ Text.unlines
    ( "# Register-1 only; Tier-2/model-runtime correspondence UNVERIFIED"
        : "entry\tsubcase\tvalidation_locus\towner_phase\tcase_family\tdisposition"
        : fmap render (sort rows)
    )
 where
  render row = Text.intercalate "\t"
    [ entry row
    , subcase row
    , locus row
    , owner row
    , family row
    , if isReached row then "discharged-here" else "deferred:" <> owner row
    ]

rowsOf :: FilePath -> IO [[Text]]
rowsOf path = do
  contents <- Text.readFile path
  pure [Text.splitOn "\t" line | line <- drop 1 (Text.lines contents), not (Text.null line)]

assert :: Bool -> String -> IO ()
assert condition message = unless condition (failTest message)

failTest :: String -> IO value
failTest message = ioError (userError message)
