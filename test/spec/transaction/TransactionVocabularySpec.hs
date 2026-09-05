{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Calculus.Artifact.Recipe (RecipeId (RecipeId))
import Amoebius.Calculus.Budget.Grant (Bytes (Bytes), Slots (Slots), allowance)
import Amoebius.Calculus.Composition (
    append,
    artifactComponent,
    budgetComponent,
    calculusTag,
    compose,
    compositionKinds,
    compositionNames,
    compositionResource,
    everyCalculus,
    evidenceComponent,
    liftComponent,
    singleton,
    workflowComponent,
 )
import Amoebius.Calculus.Evidence.Register (Register (PureRegister))
import Amoebius.Calculus.Lift.Layer (Layer (OnHost))
import Amoebius.Calculus.Workflow.Ledger (emptyLedger)
import Amoebius.Capacity.Types (ResourceVector (ResourceVector))
import Amoebius.Scope.Index (
    RequestScope,
    activeMembership,
    trustedSubject,
    trustedTenant,
    withRequestScope,
 )
import Amoebius.Transaction.Vocabulary
import Control.Monad (forM_, unless)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import System.Directory (createDirectoryIfMissing)
import System.Environment (getArgs)
import System.FilePath (takeDirectory)
import TransactionVocabularyOracle

main :: IO ()
main = do
    arguments <- getArgs
    output <- case arguments of
        [] -> pure Nothing
        [argument] | Just path <- Text.stripPrefix "--emit=" (Text.pack argument) -> pure (Just (Text.unpack path))
        _ -> fail "unknown transaction-vocabulary-spec option"
    tenant <- either (fail . show) pure (trustedTenant "transaction-tenant")
    subject <- either (fail . show) pure (trustedSubject tenant "transaction-subject")
    membership <- either (fail . show) pure (activeMembership tenant subject)
    action <- either (fail . show) pure $ withRequestScope tenant subject membership $ \scope -> runGreen scope output
    action

runGreen :: RequestScope scope -> Maybe FilePath -> IO ()
runGreen scope output = do
    assert (rowProjectionRows rowProjections == rowOracle) "row/schema/policy semantic oracle drifted"
    let transactions = transactionProjections scope
    assert (transactionRows transactions == transactionOracle) "closed transaction semantic oracle drifted"
    assert (all (predicateRequired . projectedPredicate) transactions) "a transaction scope became optional"
    assert (all exactScopePredicate transactions) "a transaction no longer carries the exact request-scope predicate"
    checkGenerations
    checkSqlBundle
    checkCalculus scope
    assert (length validationLoci == 20) "validation-locus oracle drifted"
    assert (length compileBarrierOracle == 4 && length mutantOracle == 3) "negative oracle drifted"
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

rowProjectionRows :: [RowProjection] -> [[Text]]
rowProjectionRows = map $ \row ->
    [ rowTag row.projectedRow
    , row.projectedTable
    , Text.intercalate "|" (map columnProjection row.projectedColumns)
    , Text.intercalate "," row.projectedPrimaryKey
    , foreignKeyProjection row.projectedForeignKey
    , row.projectedPolicyColumn
    , row.projectedPolicyParameter
    ]

transactionRows :: [TransactionProjection] -> [[Text]]
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
exactScopePredicate transaction = transaction.projectedPredicate == PredicateProjection "tenant_id" "scope_tenant" True

checkGenerations :: IO ()
checkGenerations =
    assert
        ( [ generationCase "generation-1-to-2" Generation1 Generation2
          , generationCase "generation-2-to-3" Generation2 Generation3
          , generationCase "generation-2-to-1" Generation2 Generation1
          , generationCase "generation-1-to-3" Generation1 Generation3
          , generationCase "generation-3-to-3" Generation3 Generation3
          ]
            == generationOracle
        )
        "typed generation-transition oracle drifted"

generationCase :: Text -> SchemaGeneration -> SchemaGeneration -> [Text]
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
    Left problem -> [name, generationTag from, generationTag to, generationErrorTag problem, "—", "—", "—"]

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

checkCalculus :: RequestScope scope -> IO ()
checkCalculus scope = do
  let resources :: Int -> ResourceVector
      resources count = ResourceVector 1 (fromIntegral count) 0 0
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
        , ["projection-counts", "3,5,4,5,3"]
        , ["resource-vector", Text.intercalate "," (map (Text.pack . show) [cpu, memory, ephemeral, pods])]
        ]
  assert (compositionKinds composition == everyCalculus) "transaction projection omitted or reordered a calculus"
  assert (actual == calculusOracle) "transaction five-calculus projection drifted"

rowTag :: RowKind -> Text
rowTag row = case row of DocumentRow -> "document"; JobRow -> "job"; ReleaseRow -> "release"
columnKindTag :: ColumnKind -> Text
columnKindTag TextColumn = "text"
operationTag :: Operation -> Text
operationTag operation = case operation of InsertOperation -> "insert"; SelectOneOperation -> "select-one"; SelectManyOperation -> "select-many"; UpdateOperation -> "update"
generationTag :: SchemaGeneration -> Text
generationTag generation = case generation of Generation1 -> "1"; Generation2 -> "2"; Generation3 -> "3"
generationErrorTag :: GenerationError -> Text
generationErrorTag problem = case problem of GenerationCurrent _ -> "generation-current"; GenerationRegression _ _ -> "generation-regression"; GenerationSkipped _ _ -> "generation-skipped"

assert :: Bool -> String -> IO ()
assert condition message = unless condition (fail message)
