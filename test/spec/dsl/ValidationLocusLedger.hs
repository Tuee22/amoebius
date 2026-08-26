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
  , layer :: Text
  , locus :: Text
  , owner :: Text
  , family :: Text
  }
  deriving stock (Eq, Ord, Show)

runValidationLocusLedger :: Set CoverageKey -> IO (Int, Int, Int)
runValidationLocusLedger corpusCoverage = do
  registry <- loadRegistry
  compileCoverage <- loadCompileCoverage
  predecessorCoverage <- loadPredecessorCoverage
  let allCoverage = corpusCoverage <> compileCoverage <> predecessorCoverage
      reached = filter isReached registry
      expected = Set.fromList [(entry row, subcase row, locus row) | row <- reached]
      missing = expected Set.\\ allCoverage
      unexpected = allCoverage Set.\\ expected
  assert (Set.null missing) ("reached registry rows have no rejecting fixture: " <> show (Set.toList missing))
  assert (Set.null unexpected) ("fixture coverage diverges from reached registry rows: " <> show (Set.toList unexpected))
  validateDeferred registry
  emitLedger registry
  pure (length reached, length registry - length reached, Set.size predecessorCoverage)

loadRegistry :: IO [RegistryRow]
loadRegistry = do
  rows <- rowsOf "dhall/examples/locus_registry.tsv"
  traverse parseRow rows
 where
  parseRow columns = case columns of
    [entryValue, subcaseValue, layerValue, locusValue, ownerValue, familyValue] ->
      pure (RegistryRow entryValue subcaseValue layerValue locusValue ownerValue familyValue)
    _ -> failTest "malformed locus_registry.tsv row"

loadCompileCoverage :: IO (Set CoverageKey)
loadCompileCoverage = do
  rows <- rowsOf "test/oracle/illegal_state_corpus/compile_fail.tsv"
  pure (Set.fromList (concatMap keys rows))
 where
  keys columns = case columns of
    [_caseName, entries, _legal, _illegal, _expected] ->
      [ (entryValue, subcaseValue, "gadt-decode")
      | binding <- Text.splitOn "," entries
      , let pair = Text.splitOn ":" binding
      , [entryValue, subcaseValue] <- [pair]
      ]
    _ -> []

loadPredecessorCoverage :: IO (Set CoverageKey)
loadPredecessorCoverage = do
  rows <- rowsOf "test/oracle/illegal_state_corpus/predecessor_coverage.tsv"
  phase8 <- rowsOf "test/oracle/scoped_identity/validation_locus.tsv"
  phase9 <- rowsOf "test/oracle/capacity_topology/compile_fail.tsv"
  Set.fromList <$> traverse (parseRow phase8 phase9) rows
 where
  parseRow phase8 phase9 columns = case columns of
    [entryValue, subcaseValue, locusValue, ownerValue, sourceValue, evidenceValue] -> do
      assert (locusValue == "gadt-decode") ("predecessor row has the wrong locus: " <> show columns)
      case (ownerValue, sourceValue) of
        ("Phase-8", "phase8-locus") ->
          assert
            (any (\row -> case row of
                [entryName, _className, _locusName, status] -> entryName == evidenceValue && status == "tested"
                _ -> False) phase8)
            ("Phase-8 predecessor evidence is absent: " <> Text.unpack evidenceValue)
        ("Phase-9", "phase9-compile") ->
          assert
            (any (\row -> case row of
                caseName : _ -> caseName == evidenceValue
                _ -> False) phase9)
            ("Phase-9 predecessor evidence is absent: " <> Text.unpack evidenceValue)
        _ -> failTest ("unknown predecessor evidence source: " <> show columns)
      pure (entryValue, subcaseValue, locusValue)
    _ -> failTest "malformed predecessor_coverage.tsv row"

-- The last phase whose rows this suite can discharge: the illegal-state corpus completes
-- the Gate-1/Gate-2 rejection set, so a row owned at or before it is reached here and a
-- later one is deferred to its owner. This threshold read 6 while the registry said
-- Phase-27, so twenty-six rows the corpus already rejected were read as deferred and the
-- coverage comparison diverged from its own registry.
corpusPhase :: Int
corpusPhase = 27

isReached :: RegistryRow -> Bool
isReached row =
  ownerNumber (owner row) <= corpusPhase && locus row `elem` ["dhall-typecheck", "gadt-decode"]

ownerNumber :: Text -> Int
ownerNumber ownerValue = case reads (Text.unpack (Text.drop (Text.length "Phase-") ownerValue)) of
  [(number, "")] -> number
  _ -> 999

-- The phase each remaining validation locus belongs to. Every one of these was a
-- pre-amendment ordinal: the ordering re-baseline renumbered the phases and updated the
-- registry's `owner_phase` column, but not the thresholds that read it, so the two
-- disagreed about which phase owns a locus while both looked internally consistent.
firstFoldPhase, renderPhase, astCheckPhase :: Int
firstFoldPhase = 9   -- the resource index, the earliest phase a provision row may be owned by
renderPhase = 33     -- pure renderAll and the rendered-artifact oracles
astCheckPhase = 34   -- the chain/Step kernel and the Gate-3 AST checker

validateDeferred :: [RegistryRow] -> IO ()
validateDeferred rows = do
  forEach [row | row <- rows, locus row == "rendered-artifact-oracle"] $ \row ->
    assert
      (ownerNumber (owner row) >= renderPhase)
      ("rendered row is owned before Phase " <> show renderPhase <> ": " <> show row)
  forEach [row | row <- rows, locus row == "extension-astcheck"] $ \row ->
    assert
      (ownerNumber (owner row) == astCheckPhase)
      ("Gate-3 row is not owned by Phase " <> show astCheckPhase <> ": " <> show row)
  forEach [row | row <- rows, locus row == "provision-seal"] $ \row ->
    assert
      (ownerNumber (owner row) >= firstFoldPhase)
      ("provision row is owned before the folds: " <> show row)
 where
  forEach = flip mapM_

emitLedger :: [RegistryRow] -> IO ()
emitLedger rows = do
  createDirectoryIfMissing True ".build/dsl/illegal-state-corpus"
  Text.writeFile ".build/dsl/illegal-state-corpus/validation-locus-ledger.tsv" $ Text.unlines
    ( "# Register-1 only; Tier-2/model-runtime correspondence UNVERIFIED"
        : "entry\tsubcase\tforeclosure_layer\tvalidation_locus\towner_phase\tcase_family\tdisposition"
        : fmap render (sort rows)
    )
 where
  render row = Text.intercalate "\t"
    [ entry row
    , subcase row
    , layer row
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
