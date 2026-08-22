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
import Control.Monad (forM, unless)
import Data.ByteString qualified as ByteString
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text
import System.Directory (createDirectoryIfMissing, getCurrentDirectory)
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.FilePath ((</>))

import ConformanceGateMutants
import LawFixtures (infernixDeclaration, jitmlDeclaration)

data InventoryRow = InventoryRow Text Text Text
  deriving stock (Eq, Ord, Show)

data CoverageRow = CoverageRow Text Text Text Text
  deriving stock (Eq, Ord, Show)

main :: IO ()
main = do
  root <- getCurrentDirectory
  arguments <- getArgs
  expectedInventory <- loadInventory root
  expectedCoverage <- loadCoverage root
  tenant <- either (die . show) pure (trustedTenant "conformance-tenant")
  subject <- either (die . show) pure (trustedSubject tenant "conformance-subject")
  membership <- either (die . show) pure (activeMembership tenant subject)
  action <- either (die . show) pure $ withRequestScope tenant subject membership $ \scope ->
    runFixture root arguments expectedInventory expectedCoverage scope
  action

runFixture :: FilePath -> [String] -> [InventoryRow] -> [CoverageRow] -> RequestScope scope -> IO ()
runFixture root arguments expectedInventory expectedCoverage scope = do
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
  case arguments of
    [] -> do
      writeEvidence root plan verdict inventory coverage files
      putStrLn "extension-conformance-gate-spec: PASS (19 cases, 24 coverage cells, 1 sealed admission, 3 exact mutants)"
    ["--mutant=law-instance-omitted"] -> redOnMismatch plan modified observations "law-instance-omitted" "GeneratedInventoryComplete"
    ["--mutant=suite-digest-ignored"] -> case ignoreObservedSuite plan modified observations of
      Right _ -> mutantRed "suite-digest-ignored" "SuiteDigestBinding"
      Left problem -> die ("digest-ignore mutant stayed safe: " <> show problem)
    ["--mutant=unsealed-extension-admitted"] ->
      if admitWithoutVerdict declaration [] == [gatePlanDeclarationDigest plan]
        then mutantRed "unsealed-extension-admitted" "VerdictRequiredForAdmission"
        else die "unsealed-admission mutant did not add the declaration"
    _ -> die ("unknown arguments: " <> show arguments)

redOnMismatch :: GatePlan scope -> [GeneratedFile] -> [ObservedCase] -> String -> String -> IO ()
redOnMismatch plan files observations mutant propertyName = case runGeneratedGate plan files observations of
  Left GeneratedSuiteMismatch {} -> mutantRed mutant propertyName
  result -> die ("omission mutant reached wrong result: " <> showResult result)

failFirst :: [ObservedCase] -> [ObservedCase]
failFirst observations = case observations of
  [] -> []
  first : rest -> first {observedCaseResult = CaseFailed "seeded-case-failure"} : rest

inventoryRow :: GateCase -> InventoryRow
inventoryRow entry = InventoryRow (suiteKindTag (gateCaseSuite entry)) (gateCaseLaw entry) (gateCaseAxis entry)

coverageRow :: CoverageCell -> CoverageRow
coverageRow cell = case coverageStatus cell of
  CoverageRequired -> CoverageRow (coverageLaw cell) (coverageAxis cell) "required" "-"
  CoverageNotApplicable reason -> CoverageRow (coverageLaw cell) (coverageAxis cell) "not-applicable" reason

loadInventory :: FilePath -> IO [InventoryRow]
loadInventory root = do
  rows <- rowsOf (root </> "test/oracle/extension_conformance/suite_inventory.tsv")
  case rows of
    header : body -> do
      assertEqual "inventory header" ["suite", "law", "axis"] header
      forM body $ \row -> case row of
        [suite, law, axis] -> pure (InventoryRow suite law axis)
        _ -> die ("invalid inventory row: " <> show row)
    [] -> die "empty inventory oracle"

loadCoverage :: FilePath -> IO [CoverageRow]
loadCoverage root = do
  rows <- rowsOf (root </> "test/oracle/extension_conformance/coverage_grid.tsv")
  case rows of
    header : body -> do
      assertEqual "coverage header" ["law", "axis", "status", "reason"] header
      forM body $ \row -> case row of
        [law, axis, status, reason] -> pure (CoverageRow law axis status reason)
        _ -> die ("invalid coverage row: " <> show row)
    [] -> die "empty coverage oracle"

writeEvidence
  :: FilePath
  -> GatePlan scope
  -> ConformanceVerdict scope
  -> [InventoryRow]
  -> [CoverageRow]
  -> [GeneratedFile]
  -> IO ()
writeEvidence root plan verdict inventory coverage files = do
  let output = root </> ".build/dsl/extension-conformance-gate"
      metrics =
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

rowsOf :: FilePath -> IO [[Text]]
rowsOf path = map (Text.splitOn "\t") . filter (not . Text.null) . Text.lines . Text.pack <$> readFile path

showResult :: Either GateRunError (ConformanceVerdict scope) -> String
showResult result = case result of
  Left problem -> show problem
  Right verdict -> "Right verdict:" <> Text.unpack (verdictDigest verdict)

showAdmission :: Either AdmissionError (LinkSet scope) -> String
showAdmission result = case result of
  Left problem -> show problem
  Right linkSet -> "Right link-set:" <> show (linkSetMembers linkSet)

mutantRed :: String -> String -> IO ()
mutantRed mutant propertyName = do
  putStrLn ("extension-conformance-mutant: RED " <> mutant <> " " <> propertyName)
  exitFailure

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual = unless (expected == actual) (die (label <> ": expected " <> show expected <> ", got " <> show actual))

die :: String -> IO value
die message = putStrLn ("FAIL: " <> message) >> exitFailure
