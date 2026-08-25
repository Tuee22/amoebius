{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Calculus.Artifact.Recipe (RecipeId (RecipeId))
import Amoebius.Calculus.Budget.Grant (Bytes (Bytes), Slots (Slots), allowance)
import Amoebius.Calculus.Composition
  ( artifactComponent
  , budgetComponent
  , evidenceComponent
  , liftComponent
  , workflowComponent
  )
import Amoebius.Calculus.Evidence.Register (Register (PureRegister))
import Amoebius.Calculus.Lift.Layer (Layer (OnHost))
import Amoebius.Calculus.Workflow.Ledger (emptyLedger)
import Amoebius.Capacity.Types (ResourceVector (ResourceVector))
import Amoebius.Extension.Conformance.Gate
import Amoebius.Extension.Declaration
  ( DeclarationError
  , ExtensionDeclaration
  , declareExtension
  )
import Amoebius.Scope.Index
  ( RequestScope
  , activeMembership
  , trustedSubject
  , trustedTenant
  , withRequestScope
  )
import Control.Monad (forM, unless)
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text
import System.Directory (createDirectoryIfMissing, getCurrentDirectory)
import System.Environment (getArgs, lookupEnv)
import System.Exit (exitFailure)
import System.FilePath ((</>))

data ProjectionRow = ProjectionRow Text Text Text Text
  deriving stock (Eq, Ord, Show)

main :: IO ()
main = do
  arguments <- getArgs
  configuredRoot <- lookupEnv "AMOEBIUS_SOURCE_ROOT"
  root <- case arguments of
    [rootArgument] -> pure rootArgument
    [] -> maybe getCurrentDirectory pure configuredRoot
    _ -> die "expected at most one source-root argument"
  metrics <- metricRows (root </> ".build/dhall/dhall-typecheck/phase-results.tsv")
  assertEqual "Dhall acceptance token" (Just "spec-composition-proven") (lookup "acceptance-token" metrics)
  assertEqual "GADT residue" (Just "UNVERIFIED") (lookup "gadt-decode-residue" metrics)
  assertEqual "runtime residue" (Just "UNVERIFIED") (lookup "runtime" metrics)
  expected <- loadProjection root
  version <- maybe (die "empty core version") pure (coreVersion "extension-laws-v1")
  tenant <- either (die . show) pure (trustedTenant "dhall-schema-tenant")
  subject <- either (die . show) pure (trustedSubject tenant "dhall-schema-subject")
  membership <- either (die . show) pure (activeMembership tenant subject)
  action <- either (die . show) pure $ withRequestScope tenant subject membership $ \scope -> do
    declaration <- either (die . show) pure (dhallSchemaDeclaration scope)
    let plan = deriveGatePlan version declaration [declaration]
        actual = fmap projectionRow (gatePlanCases plan)
        unresolved = [ObservedCase (gateCaseId entry) (CaseFailed "not-observed-at-dhall-typecheck") | entry <- gatePlanCases plan]
    assertEqual "authored Phase-25 projection" (sort expected) (sort actual)
    assertEqual "nineteen generated obligations" 19 (length actual)
    case runGeneratedGate plan (generatedFiles plan) unresolved of
      Left (CasesFailed failures) -> assertEqual "all obligations remain unresolved" 19 (length failures)
      Left problem -> die ("projection failed at wrong boundary: " <> show problem)
      Right verdict -> die ("Dhall-only evidence minted verdict " <> Text.unpack (verdictDigest verdict))
    writeProjection root actual
    putStrLn "dhall-schema-conformance-spec: PASS (19 generated obligations, verdict UNVERIFIED)"
  action

dhallSchemaDeclaration :: RequestScope scope -> Either DeclarationError (ExtensionDeclaration scope)
dhallSchemaDeclaration scope =
  declareExtension
    "dhall-schema"
    (artifactComponent scope "dhall-schema-files" (ResourceVector 1 256 1 1) (RecipeId "dhall-schema" 19))
    (budgetComponent scope "dhall-validation-budget" (ResourceVector 1 256 1 1) (allowance (Bytes 1048576) (Slots 1) (Bytes 1048576)))
    (liftComponent scope "authoring-layer" (ResourceVector 0 0 0 0) OnHost)
    (workflowComponent scope "dhall-typecheck-workflow" (ResourceVector 1 256 1 1) emptyLedger)
    (evidenceComponent scope "dhall-schema-evidence" (ResourceVector 0 0 0 0) PureRegister)

projectionRow :: GateCase -> ProjectionRow
projectionRow entry = ProjectionRow (suiteKindTag (gateCaseSuite entry)) (gateCaseLaw entry) (gateCaseAxis entry) "UNVERIFIED"

loadProjection :: FilePath -> IO [ProjectionRow]
loadProjection root = do
  rows <- rowsOf (root </> "test/oracle/dhall_typecheck_schema/conformance_projection.tsv")
  case rows of
    header : body -> do
      assertEqual "projection header" ["suite", "law", "axis", "status"] header
      forM body $ \row -> case row of
        [suite, law, axis, status] -> pure (ProjectionRow suite law axis status)
        _ -> die ("invalid projection row: " <> show row)
    [] -> die "empty conformance projection"

writeProjection :: FilePath -> [ProjectionRow] -> IO ()
writeProjection root rows = do
  let output = root </> ".build/dhall/dhall-typecheck"
  createDirectoryIfMissing True output
  writeFile (output </> "conformance-projection.tsv")
    ("suite\tlaw\taxis\tstatus\n" <> concatMap line (sort rows))
 where
  line (ProjectionRow suite law axis status) =
    Text.unpack suite <> "\t" <> Text.unpack law <> "\t" <> Text.unpack axis <> "\t" <> Text.unpack status <> "\n"

metricRows :: FilePath -> IO [(Text, Text)]
metricRows path = do
  rows <- rowsOf path
  case rows of
    ["metric", heading] : body
      | heading `elem` ["result", "value"] -> forM body $ \row ->
          case row of
            [key, value] -> pure (key, value)
            _ -> die ("invalid metric row: " <> show row)
    _ -> die ("invalid or missing Dhall phase results at " <> path <> ": " <> show (take 2 rows))

rowsOf :: FilePath -> IO [[Text]]
rowsOf path = map (Text.splitOn "\t") . filter (not . Text.null) . Text.lines . Text.pack <$> readFile path

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual = unless (expected == actual) (die (label <> ": expected " <> show expected <> ", got " <> show actual))

die :: String -> IO value
die message = putStrLn ("FAIL: " <> message) >> exitFailure
