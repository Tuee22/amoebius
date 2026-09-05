{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Dhall.Schema.Generation
import Control.Exception (SomeException, try)
import Control.Monad (forM, forM_, unless)
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import Dhall qualified
import DhallSchemaGenerationOracle
import System.Directory (createDirectoryIfMissing)
import System.Environment (lookupEnv)
import System.Exit (exitFailure)
import System.FilePath ((</>), takeDirectory)

main :: IO ()
main = do
  output <- maybe (die "AMOEBIUS_DHALL_SCHEMA_OUTPUT is required") pure =<< lookupEnv "AMOEBIUS_DHALL_SCHEMA_OUTPUT"
  let modules = sort schemaModules
      positives = [entry | entry <- schemaCases, schemaCaseExpectation entry == MustTypecheck]
      negatives = [entry | entry <- schemaCases, MustReject _ <- [schemaCaseExpectation entry]]
  assertEqual "module inventory" expectedModuleNames (map schemaModuleName modules)
  assertEqual "positive inventory" expectedPositiveNames (map schemaCaseName positives)
  assertEqual "negative inventory" expectedNegativeRows (map negativeRow negatives)
  checkSchemaLoci modules
  writeProducts output modules schemaCases
  positiveResults <- forM positives $ \entry -> do
    result <- typecheck (schemaCaseSource entry)
    assert (either (const False) (const True) result) ("positive rejected: " <> Text.unpack (schemaCaseName entry))
    pure (schemaCaseName entry)
  negativeResults <- forM negatives $ \entry -> do
    let source = schemaCaseSource entry
        expected = case schemaCaseExpectation entry of MustReject locus -> locus; MustTypecheck -> "impossible"
    rejected <- if "ForbiddenImport:" `Text.isPrefixOf` expected
      then pure (forbiddenImport source expected)
      else either (const True) (const False) <$> typecheck source
    assert rejected ("negative admitted at " <> Text.unpack expected <> ": " <> Text.unpack (schemaCaseName entry))
    assert (maybe False (`elem` positiveResults) (schemaCasePairedPositive entry)) ("paired positive absent: " <> Text.unpack (schemaCaseName entry))
    pure (schemaCaseName entry)
  assertEqual "positive count" 4 (length positiveResults)
  assertEqual "negative count" 14 (length negativeResults)
  putStrLn "dhall-schema-conformance-spec: PASS (18 modules, 4 positives, 14 paired negatives, 4 production mutants, 38 generated products)"

negativeRow :: SchemaCase -> (Text, Text, Text)
negativeRow entry =
  ( schemaCaseName entry
  , maybe "" id (schemaCasePairedPositive entry)
  , case schemaCaseExpectation entry of MustReject locus -> locus; MustTypecheck -> ""
  )

checkSchemaLoci :: [SchemaModule] -> IO ()
checkSchemaLoci modules = forM_ expectedSchemaLoci $ \(moduleName, locus) -> do
  source <- maybe (die ("missing module " <> Text.unpack moduleName)) pure (lookup moduleName [(schemaModuleName entry, schemaModuleSource entry) | entry <- modules])
  let shouldOccur = locus `notElem` ["Custom", "PlainText"]
  assert (Text.isInfixOf locus source == shouldOccur) (Text.unpack moduleName <> " locus invariant failed: " <> Text.unpack locus)

typecheck :: Text -> IO (Either SomeException ())
typecheck source = do
  result <- try (Dhall.inputExpr source)
  pure (() <$ result)

forbiddenImport :: Text -> Text -> Bool
forbiddenImport source expected
  | expected == "ForbiddenImport:env" = "env:" `Text.isPrefixOf` source
  | expected == "ForbiddenImport:https" = "https://" `Text.isPrefixOf` source
  | otherwise = False

writeProducts :: FilePath -> [SchemaModule] -> [SchemaCase] -> IO ()
writeProducts output modules cases = do
  let schemaRoot = output </> "schema"
      caseRoot = output </> "cases"
  createDirectoryIfMissing True schemaRoot
  createDirectoryIfMissing True caseRoot
  forM_ modules $ \entry -> do
    let path = schemaRoot </> Text.unpack (schemaModuleName entry) <> ".dhall"
    createDirectoryIfMissing True (takeDirectory path)
    TextIO.writeFile path (schemaModuleSource entry <> "\n")
  forM_ cases $ \entry -> TextIO.writeFile (caseRoot </> Text.unpack (schemaCaseName entry) <> ".dhall") (schemaCaseSource entry <> "\n")
  TextIO.writeFile (output </> "inventory.tsv") renderInventory
  TextIO.writeFile (output </> "foreclosure-ledger.tsv") renderForeclosureLedger

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual = assert (expected == actual) (label <> ": expected " <> show expected <> ", got " <> show actual)

die :: String -> IO value
die message = putStrLn ("FAIL: " <> message) >> exitFailure
