{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Extension.Conformance.Gate
import Amoebius.Scope.Index
  ( RequestScope
  , activeMembership
  , trustedSubject
  , trustedTenant
  , withRequestScope
  )
import Control.Monad (unless)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteStringChar8
import Data.List (isInfixOf, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import System.Directory (createDirectoryIfMissing)
import System.Environment (lookupEnv)
import System.Exit (exitFailure)
import System.FilePath ((</>))

import ExtensionConformanceGateOracle qualified as Oracle
import LawFixtures (infernixDeclaration, jitmlDeclaration)

data InventoryRow = InventoryRow Text Text Text
  deriving stock (Eq, Ord, Show)

data CoverageRow = CoverageRow Text Text Text Text
  deriving stock (Eq, Ord, Show)

main :: IO ()
main = do
  let expectedInventory = [InventoryRow suite law axis | (suite, law, axis) <- Oracle.suiteInventory]
      expectedCoverage = [CoverageRow law axis status reason | (law, axis, status, reason) <- Oracle.coverageGrid]
  tenant <- either (die . show) pure (trustedTenant "conformance-tenant")
  subject <- either (die . show) pure (trustedSubject tenant "conformance-subject")
  membership <- either (die . show) pure (activeMembership tenant subject)
  action <- either (die . show) pure $ withRequestScope tenant subject membership $ \scope ->
    runFixture expectedInventory expectedCoverage scope
  action

runFixture :: [InventoryRow] -> [CoverageRow] -> RequestScope scope -> IO ()
runFixture expectedInventory expectedCoverage scope = do
  declaration <- either (die . show) pure (infernixDeclaration scope)
  peer <- either (die . show) pure (jitmlDeclaration scope)
  version <- maybe (die "empty core version") pure (coreVersion "extension-laws-v1")
  nextVersion <- maybe (die "empty next core version") pure (coreVersion "extension-laws-v2")
  let plan = deriveGatePlan version declaration [peer]
      inventory = fmap inventoryRow (gatePlanCases plan)
      coverage = fmap coverageRow (gatePlanCoverage plan)
      files = generatedFiles plan
      observations = [ObservedCase (gateCaseId entry) CasePassed | entry <- gatePlanCases plan]
      modified = omitLawFromSuite "L5" files
  assertEqual "authored suite inventory" (sort expectedInventory) (sort inventory)
  assertEqual "authored coverage grid" (sort expectedCoverage) (sort coverage)
  assertEqual "five suite files plus coverage" 6 (length files)
  assertEqual "nineteen executable cases" 19 (length inventory)
  assertEqual "twenty-four law coverage cells" 24 (length coverage)
  assertEqual "six transaction deferrals" 6
    (length [() | CoverageRow law _ "not-applicable" _ <- coverage, "P" `Text.isPrefixOf` law])
  verdict <- either (die . show) pure (runGeneratedGate plan files observations)
  assert (verifyVerdict plan verdict) "canonical verdict did not verify"
  admitted <- either (die . show) pure (admitExtension plan declaration verdict emptyLinkSet)
  assertEqual "one verdict-gated member" 1 (length (linkSetMembers admitted))
  case runGeneratedGate plan modified observations of
    Left GeneratedSuiteMismatch {} -> pure ()
    result -> die ("modified suite reached wrong result: " <> showResult result)
  case runGeneratedGate plan files (failFirst observations) of
    Left CasesFailed {} -> pure ()
    result -> die ("failed case reached wrong result: " <> showResult result)
  case admitExtension plan peer verdict emptyLinkSet of
    Left PlanDeclarationMismatch {} -> pure ()
    result -> die ("wrong declaration reached wrong result: " <> showAdmission result)
  let changedPlan = deriveGatePlan nextVersion declaration [peer]
  assert (not (verifyVerdict changedPlan verdict)) "old verdict verified under changed core version"
  case admitExtension changedPlan declaration verdict emptyLinkSet of
    Left VerdictDidNotVerify -> pure ()
    result -> die ("changed-core admission reached wrong result: " <> showAdmission result)
  assertEqual "independent verdict case inventory" 5 (length Oracle.expectedVerdictCases)
  writeEvidence plan verdict inventory coverage files
  putStrLn "extension-conformance-gate-spec: PASS (19 cases, 24 coverage cells, 1 sealed admission, 3 production mutants, 3 compiler barriers, 10 generated products)"

failFirst :: [ObservedCase] -> [ObservedCase]
failFirst observations = case observations of
  [] -> []
  first : rest -> first {observedCaseResult = CaseFailed "seeded-case-failure"} : rest

omitLawFromSuite :: String -> [GeneratedFile] -> [GeneratedFile]
omitLawFromSuite law = map mutate
 where
  mutate file
    | generatedPath file == "property-suite.tsv" =
        file {generatedBytes = ByteStringChar8.unlines (filter (not . containsLaw) (ByteStringChar8.lines (generatedBytes file)))}
    | otherwise = file
  containsLaw line = ("\t" <> law <> "\t") `isInfixOf` ByteStringChar8.unpack line

inventoryRow :: GateCase -> InventoryRow
inventoryRow entry = InventoryRow (suiteKindTag (gateCaseSuite entry)) (gateCaseLaw entry) (gateCaseAxis entry)

coverageRow :: CoverageCell -> CoverageRow
coverageRow cell = case coverageStatus cell of
  CoverageRequired -> CoverageRow (coverageLaw cell) (coverageAxis cell) "required" "-"
  CoverageNotApplicable reason -> CoverageRow (coverageLaw cell) (coverageAxis cell) "not-applicable" reason

writeEvidence
  :: GatePlan scope
  -> ConformanceVerdict scope
  -> [InventoryRow]
  -> [CoverageRow]
  -> [GeneratedFile]
  -> IO ()
writeEvidence plan verdict inventory coverage files = do
  output <- maybe (die "AMOEBIUS_EXTENSION_CONFORMANCE_OUTPUT is absent") pure =<< lookupEnv "AMOEBIUS_EXTENSION_CONFORMANCE_OUTPUT"
  let metrics =
        [ ("executable-cases", "19/19-derived")
        , ("suite-files", "5/5-plus-coverage")
        , ("property-cases", "5/5-L1-L5")
        , ("composition-cases", "7/7-C1-C7-one-peer")
        , ("compile-cases", "1/1-declared-claim")
        , ("security-cases", "6/6-S1-S6")
        , ("transaction-coverage", "6/6-not-applicable-no-vocabulary")
        , ("coverage-grid", "24/24-authored")
        , ("verdict-seal", "declaration-core-suite-result-bound")
        , ("admission", "1/1-verdict-required")
        , ("mutants", "3/3-red-exactly")
        , ("runtime", "UNVERIFIED")
        ]
  createDirectoryIfMissing True output
  mapM_ (writeGenerated output) files
  writeFile (output </> "phase-results.tsv")
    ("metric\tresult\n" <> concat [key <> "\t" <> value <> "\n" | (key, value) <- metrics])
  writeFile (output </> "inventory.tsv")
    ("suite\tlaw\taxis\n" <> concat [Text.unpack suite <> "\t" <> Text.unpack law <> "\t" <> Text.unpack axis <> "\n" | InventoryRow suite law axis <- inventory])
  writeFile (output </> "coverage-observed.tsv")
    ("law\taxis\tstatus\treason\n" <> concat [line row | row <- coverage])
  writeFile (output </> "verdict.tsv")
    ("declaration_digest\tcore_version\tsuite_digest\tresult\tverdict_digest\n"
      <> Text.unpack (verdictDeclarationDigest verdict) <> "\t"
      <> Text.unpack (coreVersionText (verdictCoreVersion verdict)) <> "\t"
      <> Text.unpack (verdictSuiteDigest verdict) <> "\tpassed\t"
      <> Text.unpack (verdictDigest verdict) <> "\n")
  assertEqual "suite digest reader" (gatePlanSuiteDigest plan) (verdictSuiteDigest verdict)
 where
  line (CoverageRow law axis status reason) =
    Text.unpack law <> "\t" <> Text.unpack axis <> "\t" <> Text.unpack status <> "\t" <> Text.unpack reason <> "\n"

writeGenerated :: FilePath -> GeneratedFile -> IO ()
writeGenerated output file = ByteString.writeFile (output </> Text.unpack (generatedPath file)) (generatedBytes file)

showResult :: Either GateRunError (ConformanceVerdict scope) -> String
showResult result = case result of
  Left problem -> show problem
  Right verdict -> "Right verdict:" <> Text.unpack (verdictDigest verdict)

showAdmission :: Either AdmissionError (LinkSet scope) -> String
showAdmission result = case result of
  Left problem -> show problem
  Right linkSet -> "Right link-set:" <> show (linkSetMembers linkSet)

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual = unless (expected == actual) (die (label <> ": expected " <> show expected <> ", got " <> show actual))

die :: String -> IO value
die message = putStrLn ("FAIL: " <> message) >> exitFailure
