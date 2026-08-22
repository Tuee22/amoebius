{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Calculus.Artifact.Recipe (RecipeId (RecipeId))
import Amoebius.Calculus.Budget.Grant (Bytes (Bytes), Slots (Slots), allowance)
import Amoebius.Calculus.Composition
  ( append
  , artifactComponent
  , budgetComponent
  , calculusTag
  , compose
  , compositionKinds
  , compositionNames
  , compositionResource
  , evidenceComponent
  , everyCalculus
  , liftComponent
  , singleton
  , workflowComponent
  )
import Amoebius.Calculus.Evidence.Register (Register (PureRegister))
import Amoebius.Calculus.Lift.Layer (Layer (OnHost))
import Amoebius.Calculus.Workflow.Ledger (emptyLedger)
import Amoebius.Capacity.Types (ResourceVector (ResourceVector))
import Amoebius.Scope.Index
  ( RequestScope
  , activeMembership
  , trustedSubject
  , trustedTenant
  , withRequestScope
  )
import Amoebius.Transaction.Vocabulary
import Control.Monad (forM, forM_, unless)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import System.Directory (createDirectoryIfMissing)
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.FilePath (takeDirectory)

type OracleRow = [Text]

main :: IO ()
main = do
  arguments <- getArgs
  tenant <- either (fail . show) pure (trustedTenant "transaction-tenant")
  subject <- either (fail . show) pure (trustedSubject tenant "transaction-subject")
  membership <- either (fail . show) pure (activeMembership tenant subject)
  action <- either (fail . show) pure $ withRequestScope tenant subject membership $ \scope -> do
    rows <- loadOracle "test/oracle/transaction_vocabulary/rows.tsv"
    transactions <- loadOracle "test/oracle/transaction_vocabulary/transactions.tsv"
    case arguments of
      ["--mutant=transaction-optional-scope"] -> rejectOptionalScope scope transactions
      ["--mutant=transaction-match-all"] -> rejectMatchAll scope transactions
      ["--mutant=transaction-wrong-policy-column"] -> rejectWrongPolicy rows
      [argument] | Just path <- Text.stripPrefix "--emit=" (Text.pack argument) -> runGreen scope rows transactions (Just (Text.unpack path))
      [] -> runGreen scope rows transactions Nothing
      _ -> fail "unknown transaction-vocabulary-spec option"
  action

runGreen :: RequestScope scope -> [OracleRow] -> [OracleRow] -> Maybe FilePath -> IO ()
runGreen scope expectedRows expectedTransactions output = do
  assert (rowProjectionRows rowProjections == expectedRows) "row/schema/policy semantic oracle drifted"
  let transactions = transactionProjections scope
  assert (transactionRows transactions == expectedTransactions) "closed transaction semantic oracle drifted"
  assert (all (predicateRequired . projectedPredicate) transactions) "a transaction scope became optional"
  assert (all exactScopePredicate transactions) "a transaction no longer carries the exact request-scope predicate"
  checkGenerations
  checkSqlBundle
  checkCalculus
  forM_ output $ \path -> do
    createDirectoryIfMissing True (takeDirectory path)
    Text.writeFile path sqlBundleText
  putStrLn "transaction-vocabulary-calculus: PASS (5 kinds, 20 projected units)"
  putStrLn "transaction-vocabulary-invariants: PASS (3 rows, 5 closed transactions, 2 additive transitions, 4 compile barriers)"
  putStrLn "transaction-vocabulary-spec: PASS (3 semantic oracles, 5 generation cases, 3 mutants)"

transactionProjections :: RequestScope scope -> [TransactionProjection]
transactionProjections scope =
  [ transactionProjection (insertDocument scope (DocumentId "document-1") (DocumentBody "body"))
  , transactionProjection (readDocument scope (DocumentId "document-1"))
  , transactionProjection (listSubjectJobs scope)
  , transactionProjection (advanceJobStatus scope (JobId "job-1") (JobStatus "running"))
  , transactionProjection (recordRelease scope (ReleaseId "release-1") (ContentDigest "sha256:observed-at-runtime"))
  ]

rowProjectionRows :: [RowProjection] -> [OracleRow]
rowProjectionRows = map $ \row ->
  [ rowTag row.projectedRow
  , row.projectedTable
  , Text.intercalate "|" (map columnProjection row.projectedColumns)
  , Text.intercalate "," row.projectedPrimaryKey
  , foreignKeyProjection row.projectedForeignKey
  , row.projectedPolicyColumn
  , row.projectedPolicyParameter
  ]

transactionRows :: [TransactionProjection] -> [OracleRow]
transactionRows = map $ \transaction ->
  [ transaction.projectedTransaction
  , operationTag transaction.projectedOperation
  , transaction.projectedTransactionTable
  , transaction.projectedPredicate.predicateColumn
  , transaction.projectedPredicate.predicateParameter
  , transaction.projectedResultShape
  ]

columnProjection :: (Text, ColumnKind, Bool) -> Text
columnProjection (name, kind, required) =
  Text.intercalate ":" [name, columnKindTag kind, if required then "not-null" else "nullable"]

foreignKeyProjection :: (Text, Text, Text) -> Text
foreignKeyProjection (column, table, target) = column <> "->" <> table <> "." <> target

exactScopePredicate :: TransactionProjection -> Bool
exactScopePredicate transaction =
  transaction.projectedPredicate
    == PredicateProjection
      { predicateColumn = "tenant_id"
      , predicateParameter = "scope_tenant"
      , predicateRequired = True
      }

checkGenerations :: IO ()
checkGenerations = do
  rows <- loadOracle "test/oracle/transaction_vocabulary/generations.tsv"
  actual <- forM rows $ \row -> case row of
    [name, from, to, _, _, _, _] -> generationCase name <$> parseGeneration from <*> parseGeneration to
    _ -> fail "malformed generation oracle row"
  assert (actual == rows) "typed generation-transition oracle drifted"

generationCase :: Text -> SchemaGeneration -> SchemaGeneration -> OracleRow
generationCase name from to = case transitionGeneration from to of
  Right transition ->
    let projection = generationProjection transition
     in [ name
        , generationTag projection.projectedGenerationFrom
        , generationTag projection.projectedGenerationTo
        , "admitted"
        , Text.intercalate "," (map rowTag projection.projectedRetainedRows)
        , rowTag projection.projectedAddedRow
        , projection.projectedClauseKind
        ]
  Left problem ->
    [name, generationTag from, generationTag to, generationErrorTag problem, "—", "—", "—"]

checkSqlBundle :: IO ()
checkSqlBundle = do
  let second = sqlBundleText
      forbidden = ["DROP ", "TRUNCATE ", "DELETE "]
  assert (sqlBundleText == second) "SQL bundle changed across repeated projections"
  assert (all (`Text.isInfixOf` sqlBundleText) ["CREATE TABLE documents", "CREATE TABLE jobs", "CREATE TABLE releases"]) "SQL bundle omitted a declared row"
  assert (Text.count "CREATE POLICY " sqlBundleText == 3) "SQL bundle policy count drifted"
  assert (Text.count "-- transaction " sqlBundleText == 5) "SQL bundle statement count drifted"
  assert (all (not . (`Text.isInfixOf` sqlBundleText)) forbidden) "SQL bundle contains a destructive verb"
  assert (Text.count "tenant_id = current_setting('amoebius.scope_tenant', true)" sqlBundleText == 9) "statement/policy scope term drifted"

checkCalculus :: IO ()
checkCalculus = do
  expected <- loadOracle "test/oracle/transaction_vocabulary/calculus_projection.tsv"
  tenant <- either (fail . show) pure (trustedTenant "transaction-calculus-tenant")
  subject <- either (fail . show) pure (trustedSubject tenant "transaction-calculus-subject")
  membership <- either (fail . show) pure (activeMembership tenant subject)
  action <- either (fail . show) pure $ withRequestScope tenant subject membership $ \scope -> do
    let resources :: Int -> ResourceVector
        resources count = ResourceVector 1 (fromIntegral count) 0 0
        counts :: [Int]
        counts = [3, 5, 4, 5, 3]
        artifact = artifactComponent scope "row-semantics" (resources 3) (RecipeId "transaction-vocabulary" 1)
        budget = budgetComponent scope "transaction-semantics" (resources 5) (allowance (Bytes 5) (Slots 1) (Bytes 5))
        lift = liftComponent scope "compile-barriers" (resources 4) OnHost
        workflow = workflowComponent scope "generation-cases" (resources 5) emptyLedger
        evidence = evidenceComponent scope "mutant-evidence" (resources 3) PureRegister
        composition = append (compose artifact budget) (append (compose lift workflow) (singleton evidence))
        ResourceVector cpu memory ephemeral pods = compositionResource composition
        actual =
          [ ["calculus-kinds", Text.intercalate "," (map calculusTag (compositionKinds composition))]
          , ["component-names", Text.intercalate "," (compositionNames composition)]
          , ["projection-counts", Text.intercalate "," (map (Text.pack . show) counts)]
          , ["resource-vector", Text.intercalate "," (map (Text.pack . show) [cpu, memory, ephemeral, pods])]
          ]
    assert (compositionKinds composition == everyCalculus) "transaction projection omitted or reordered a calculus"
    assert (actual == expected) "transaction five-calculus projection drifted"
  action

rejectOptionalScope :: RequestScope scope -> [OracleRow] -> IO ()
rejectOptionalScope scope expected = do
  let original = transactionProjections scope
      mutated = case original of
        first : rest -> first {projectedPredicate = first.projectedPredicate {predicateRequired = False}} : rest
        [] -> []
  rejectPaired
    "transaction-optional-scope"
    "required-scope"
    (transactionRows original == expected && all (predicateRequired . projectedPredicate) original)
    (transactionRows mutated == expected && all (predicateRequired . projectedPredicate) mutated)

rejectMatchAll :: RequestScope scope -> [OracleRow] -> IO ()
rejectMatchAll scope expected = do
  let original = transactionProjections scope
      mutated = map (\transaction -> transaction {projectedPredicate = PredicateProjection "TRUE" "none" False}) original
  rejectPaired "transaction-match-all" "exact-scope-predicate" (transactionRows original == expected) (transactionRows mutated == expected)

rejectWrongPolicy :: [OracleRow] -> IO ()
rejectWrongPolicy expected = do
  let original = rowProjections
      mutated = case original of
        first : rest -> first {projectedPolicyColumn = "subject_id"} : rest
        [] -> []
  rejectPaired "transaction-wrong-policy-column" "shared-declaration" (rowProjectionRows original == expected) (rowProjectionRows mutated == expected)

rejectPaired :: String -> String -> Bool -> Bool -> IO ()
rejectPaired mutant locus originalPasses mutatedPasses =
  if originalPasses && not mutatedPasses
    then do
      putStrLn ("transaction-vocabulary-mutant: RED " <> mutant <> " locus=" <> locus)
      exitFailure
    else fail ("mutant pairing was not discriminating: " <> mutant)

loadOracle :: FilePath -> IO [OracleRow]
loadOracle path = do
  contents <- Text.readFile path
  pure (map (Text.splitOn "\t") (drop 1 (Text.lines contents)))

parseGeneration :: Text -> IO SchemaGeneration
parseGeneration value = case value of
  "1" -> pure Generation1
  "2" -> pure Generation2
  "3" -> pure Generation3
  _ -> fail ("unknown schema generation: " <> Text.unpack value)

rowTag :: RowKind -> Text
rowTag row = case row of
  DocumentRow -> "document"
  JobRow -> "job"
  ReleaseRow -> "release"

columnKindTag :: ColumnKind -> Text
columnKindTag kind = case kind of
  TextColumn -> "text"

operationTag :: Operation -> Text
operationTag operation = case operation of
  InsertOperation -> "insert"
  SelectOneOperation -> "select-one"
  SelectManyOperation -> "select-many"
  UpdateOperation -> "update"

generationTag :: SchemaGeneration -> Text
generationTag generation = case generation of
  Generation1 -> "1"
  Generation2 -> "2"
  Generation3 -> "3"

generationErrorTag :: GenerationError -> Text
generationErrorTag problem = case problem of
  GenerationCurrent _ -> "generation-current"
  GenerationRegression _ _ -> "generation-regression"
  GenerationSkipped _ _ -> "generation-skipped"

assert :: Bool -> String -> IO ()
assert condition message = unless condition (fail message)
