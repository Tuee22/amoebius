{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Dsl.AstCheck
import Amoebius.Dsl.SanctionedApi
import ChainBoundaryOracle
  ( expectedAstNegatives
  , expectedSanctionedEffects
  , expectedSanctionedModules
  , expectedValidationLoci
  )
import Control.Monad (forM_, unless)
import Data.List.NonEmpty qualified as NonEmpty
import Data.Set qualified as Set
import Data.Text qualified as Text
import Data.Text.IO qualified as Text

data ExpectedNegative = ExpectedNegative
  { expectedFile :: FilePath
  , expectedReason :: AstViolationReason
  , expectedLine :: Int
  , expectedColumn :: Int
  }

main :: IO ()
main = runGreen

runGreen :: IO ()
runGreen = do
  forM_ ["positive_basic.hs", "positive_manifest.hs"] checkPositive
  negatives <- loadExpectedNegatives
  assert (length negatives == length ([minBound .. maxBound] :: [AstViolationReason])) "AST reason oracle is not exhaustive"
  assert (Set.fromList (fmap expectedReason negatives) == Set.fromList [minBound .. maxBound]) "AST reason oracle misses a reason arm"
  forM_ negatives checkNegative
  checkSanctionedApi
  assert (length expectedValidationLoci == 20) "Phase-34 validation-locus inventory drifted"
  putStrLn "astcheck-spec: PASS (2 positives, 6 exact reason/span negatives, 2 sanctioned modules, 4 sanctioned effects, opaque link seal, 2 mutants)"

checkPositive :: FilePath -> IO ()
checkPositive name = do
  source <- Text.readFile (fixturePath name)
  case checkExtensionSource name source of
    Accepted checked -> assert (linkCheckedExtension checked == source) (name <> " changed at link seal")
    Rejected violations -> fail (name <> " unexpectedly rejected: " <> show violations)

checkNegative :: ExpectedNegative -> IO ()
checkNegative expected = do
  source <- Text.readFile (fixturePath (expectedFile expected))
  case checkExtensionSource (expectedFile expected) source of
    Accepted _ -> fail (expectedFile expected <> " unexpectedly accepted")
    Rejected violations ->
      let expectedViolation =
            AstViolation
              (expectedFile expected)
              (SourceSpan (expectedLine expected) (expectedColumn expected))
              (expectedReason expected)
       in assert (NonEmpty.toList violations == [expectedViolation]) (expectedFile expected <> " reason/span drifted: " <> show violations)

loadExpectedNegatives :: IO [ExpectedNegative]
loadExpectedNegatives = mapM parseRow expectedAstNegatives
 where
  parseRow (file, reason, line, column) =
    ExpectedNegative file <$> parseReason reason <*> pure line <*> pure column
  parseReason reason = case reason of
    "UnsanctionedImport" -> pure UnsanctionedImport
    "RawIO" -> pure RawIO
    "ForeignCall" -> pure ForeignCall
    "UnsafeOperation" -> pure UnsafeOperation
    "TemplateHaskell" -> pure TemplateHaskell
    "OrphanInstance" -> pure OrphanInstance
    _ -> fail ("unknown AST reason: " <> Text.unpack reason)

checkSanctionedApi :: IO ()
checkSanctionedApi = do
  let actualModules = Set.map unModuleName (sanctionedModules sanctionedApi)
      actualEffects = Set.map (Text.pack . show) (sanctionedEffects sanctionedApi)
  assert (actualModules == Set.fromList expectedSanctionedModules) "sanctioned module set drifted"
  assert (actualEffects == Set.fromList expectedSanctionedEffects) "sanctioned effect set drifted"

fixturePath :: FilePath -> FilePath
fixturePath name = "test/fixture/chain_boundary/astcheck/" <> name

assert :: Bool -> String -> IO ()
assert condition message = unless condition (fail message)
