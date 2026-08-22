{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedStrings #-}

-- | A closed, request-scoped relational vocabulary.
--
-- The constructors of 'Transaction' and every SQL declaration type are private.  A
-- caller can select only one of the exported domain transactions, and each smart
-- constructor requires the generative 'RequestScope' that also indexes its result.
-- Schema, policy, and statement text are projections of the same private row terms.
module Amoebius.Transaction.Vocabulary
  ( RowKind (..)
  , ColumnKind (..)
  , Operation (..)
  , RowProjection (..)
  , PredicateProjection (..)
  , TransactionProjection (..)
  , rowProjections
  , Transaction
  , Document
  , Job
  , Release
  , Inserted
  , Updated
  , DocumentId (..)
  , DocumentBody (..)
  , JobId (..)
  , JobStatus (..)
  , ReleaseId (..)
  , ContentDigest (..)
  , insertDocument
  , readDocument
  , listSubjectJobs
  , advanceJobStatus
  , recordRelease
  , transactionProjection
  , SchemaGeneration (..)
  , GenerationError (..)
  , GenerationTransition
  , GenerationProjection (..)
  , transitionGeneration
  , generationProjection
  , sqlBundleText
  ) where

import Amoebius.Scope.Index (RequestScope, Scoped)
import Data.Text (Text)
import Data.Text qualified as Text

data RowKind
  = DocumentRow
  | JobRow
  | ReleaseRow
  deriving stock (Eq, Ord, Show, Enum, Bounded)

data ColumnKind = TextColumn
  deriving stock (Eq, Ord, Show)

data Operation
  = InsertOperation
  | SelectOneOperation
  | SelectManyOperation
  | UpdateOperation
  deriving stock (Eq, Ord, Show)

data RowProjection = RowProjection
  { projectedRow :: RowKind
  , projectedTable :: Text
  , projectedColumns :: [(Text, ColumnKind, Bool)]
  , projectedPrimaryKey :: [Text]
  , projectedForeignKey :: (Text, Text, Text)
  , projectedPolicyColumn :: Text
  , projectedPolicyParameter :: Text
  }
  deriving stock (Eq, Show)

data PredicateProjection = PredicateProjection
  { predicateColumn :: Text
  , predicateParameter :: Text
  , predicateRequired :: Bool
  }
  deriving stock (Eq, Show)

data TransactionProjection = TransactionProjection
  { projectedTransaction :: Text
  , projectedOperation :: Operation
  , projectedTransactionTable :: Text
  , projectedPredicate :: PredicateProjection
  , projectedResultShape :: Text
  }
  deriving stock (Eq, Show)

data Column = Column Text ColumnKind

data ScopePredicate = ScopeEquals Column Text

data RowDeclaration = RowDeclaration
  { rowKind :: RowKind
  , rowTable :: Text
  , rowColumns :: [Column]
  , rowPrimaryKey :: [Column]
  , rowScopeColumn :: Column
  }

data TransactionDeclaration = TransactionDeclaration
  { declarationName :: Text
  , declarationOperation :: Operation
  , declarationRow :: RowDeclaration
  , declarationResult :: Text
  , declarationExtraPredicate :: Maybe (Column, Text)
  , declarationWriteColumns :: [Column]
  }

documentDeclaration :: RowDeclaration
documentDeclaration =
  RowDeclaration
    { rowKind = DocumentRow
    , rowTable = "documents"
    , rowColumns = [tenantColumn, Column "document_id" TextColumn, Column "body" TextColumn]
    , rowPrimaryKey = [tenantColumn, Column "document_id" TextColumn]
    , rowScopeColumn = tenantColumn
    }

jobDeclaration :: RowDeclaration
jobDeclaration =
  RowDeclaration
    { rowKind = JobRow
    , rowTable = "jobs"
    , rowColumns = [tenantColumn, Column "subject_id" TextColumn, Column "job_id" TextColumn, Column "status" TextColumn]
    , rowPrimaryKey = [tenantColumn, Column "job_id" TextColumn]
    , rowScopeColumn = tenantColumn
    }

releaseDeclaration :: RowDeclaration
releaseDeclaration =
  RowDeclaration
    { rowKind = ReleaseRow
    , rowTable = "releases"
    , rowColumns = [tenantColumn, Column "release_id" TextColumn, Column "content_digest" TextColumn]
    , rowPrimaryKey = [tenantColumn, Column "release_id" TextColumn]
    , rowScopeColumn = tenantColumn
    }

tenantColumn :: Column
tenantColumn = Column "tenant_id" TextColumn

everyRowDeclaration :: [RowDeclaration]
everyRowDeclaration = [documentDeclaration, jobDeclaration, releaseDeclaration]

rowProjections :: [RowProjection]
rowProjections = map projectRow everyRowDeclaration

projectRow :: RowDeclaration -> RowProjection
projectRow declaration =
  RowProjection
    { projectedRow = rowKind declaration
    , projectedTable = rowTable declaration
    , projectedColumns = [(columnName column, columnKind column, True) | column <- rowColumns declaration]
    , projectedPrimaryKey = map columnName (rowPrimaryKey declaration)
    , projectedForeignKey = (columnName (rowScopeColumn declaration), "amoebius_scope", "tenant_id")
    , projectedPolicyColumn = predicateColumn predicate
    , projectedPolicyParameter = predicateParameter predicate
    }
 where
  predicate = projectPredicate (scopePredicate declaration)

data Document
data Job
data Release
data Inserted
data Updated

newtype DocumentId = DocumentId Text deriving stock (Eq, Show)
newtype DocumentBody = DocumentBody Text deriving stock (Eq, Show)
newtype JobId = JobId Text deriving stock (Eq, Show)
newtype JobStatus = JobStatus Text deriving stock (Eq, Show)
newtype ReleaseId = ReleaseId Text deriving stock (Eq, Show)
newtype ContentDigest = ContentDigest Text deriving stock (Eq, Show)

data Transaction scope result where
  InsertDocument
    :: RequestScope scope
    -> DocumentId
    -> DocumentBody
    -> Transaction scope (Scoped scope Inserted)
  ReadDocument
    :: RequestScope scope
    -> DocumentId
    -> Transaction scope (Scoped scope (Maybe Document))
  ListSubjectJobs
    :: RequestScope scope
    -> Transaction scope (Scoped scope [Job])
  AdvanceJobStatus
    :: RequestScope scope
    -> JobId
    -> JobStatus
    -> Transaction scope (Scoped scope Updated)
  RecordRelease
    :: RequestScope scope
    -> ReleaseId
    -> ContentDigest
    -> Transaction scope (Scoped scope Inserted)

insertDocument
  :: RequestScope scope
  -> DocumentId
  -> DocumentBody
  -> Transaction scope (Scoped scope Inserted)
insertDocument = InsertDocument

readDocument
  :: RequestScope scope
  -> DocumentId
  -> Transaction scope (Scoped scope (Maybe Document))
readDocument = ReadDocument

listSubjectJobs :: RequestScope scope -> Transaction scope (Scoped scope [Job])
listSubjectJobs = ListSubjectJobs

advanceJobStatus
  :: RequestScope scope
  -> JobId
  -> JobStatus
  -> Transaction scope (Scoped scope Updated)
advanceJobStatus = AdvanceJobStatus

recordRelease
  :: RequestScope scope
  -> ReleaseId
  -> ContentDigest
  -> Transaction scope (Scoped scope Inserted)
recordRelease = RecordRelease

transactionProjection :: Transaction scope result -> TransactionProjection
transactionProjection transaction = projectTransaction (transactionDeclaration transaction)

transactionDeclaration :: Transaction scope result -> TransactionDeclaration
transactionDeclaration transaction = case transaction of
  InsertDocument _ _ _ ->
    declaration "insert-document" InsertOperation documentDeclaration "scoped-inserted" Nothing (rowColumns documentDeclaration)
  ReadDocument _ _ ->
    declaration "read-document" SelectOneOperation documentDeclaration "scoped-maybe-document" (Just (Column "document_id" TextColumn, "document_id")) []
  ListSubjectJobs _ ->
    declaration "list-subject-jobs" SelectManyOperation jobDeclaration "scoped-job-list" Nothing []
  AdvanceJobStatus _ _ _ ->
    declaration "advance-job-status" UpdateOperation jobDeclaration "scoped-updated" (Just (Column "job_id" TextColumn, "job_id")) [Column "status" TextColumn]
  RecordRelease _ _ _ ->
    declaration "record-release" InsertOperation releaseDeclaration "scoped-inserted" Nothing (rowColumns releaseDeclaration)
 where
  declaration name operation row result extra writes =
    TransactionDeclaration name operation row result extra writes

projectTransaction :: TransactionDeclaration -> TransactionProjection
projectTransaction declaration =
  TransactionProjection
    { projectedTransaction = declarationName declaration
    , projectedOperation = declarationOperation declaration
    , projectedTransactionTable = rowTable (declarationRow declaration)
    , projectedPredicate = projectPredicate (scopePredicate (declarationRow declaration))
    , projectedResultShape = declarationResult declaration
    }

scopePredicate :: RowDeclaration -> ScopePredicate
scopePredicate declaration = ScopeEquals (rowScopeColumn declaration) "scope_tenant"

projectPredicate :: ScopePredicate -> PredicateProjection
projectPredicate (ScopeEquals column parameter) =
  PredicateProjection (columnName column) parameter True

data SchemaGeneration
  = Generation1
  | Generation2
  | Generation3
  deriving stock (Eq, Ord, Show, Enum, Bounded)

data GenerationError
  = GenerationCurrent SchemaGeneration
  | GenerationRegression SchemaGeneration SchemaGeneration
  | GenerationSkipped SchemaGeneration SchemaGeneration
  deriving stock (Eq, Show)

data GenerationTransition = GenerationTransition
  { transitionFrom :: SchemaGeneration
  , transitionTo :: SchemaGeneration
  , transitionRetained :: [RowKind]
  , transitionAdded :: RowKind
  }
  deriving stock (Eq, Show)

data GenerationProjection = GenerationProjection
  { projectedGenerationFrom :: SchemaGeneration
  , projectedGenerationTo :: SchemaGeneration
  , projectedRetainedRows :: [RowKind]
  , projectedAddedRow :: RowKind
  , projectedClauseKind :: Text
  }
  deriving stock (Eq, Show)

transitionGeneration
  :: SchemaGeneration
  -> SchemaGeneration
  -> Either GenerationError GenerationTransition
transitionGeneration from to
  | from == to = Left (GenerationCurrent from)
  | to < from = Left (GenerationRegression from to)
  | from == Generation1 && to == Generation2 = Right (GenerationTransition from to [DocumentRow] JobRow)
  | from == Generation2 && to == Generation3 = Right (GenerationTransition from to [DocumentRow, JobRow] ReleaseRow)
  | otherwise = Left (GenerationSkipped from to)

generationProjection :: GenerationTransition -> GenerationProjection
generationProjection transition =
  GenerationProjection
    { projectedGenerationFrom = transitionFrom transition
    , projectedGenerationTo = transitionTo transition
    , projectedRetainedRows = transitionRetained transition
    , projectedAddedRow = transitionAdded transition
    , projectedClauseKind = "create-table"
    }

sqlBundleText :: Text
sqlBundleText =
  Text.unlines $
    ["-- GENERATED by amoebius transaction vocabulary. Do not edit by hand."]
      <> concatMap renderRow everyRowDeclaration
      <> concatMap renderStatement everyTransactionDeclaration
      <> concatMap renderTransition everyTransition
 where
  everyTransition =
    [ GenerationTransition Generation1 Generation2 [DocumentRow] JobRow
    , GenerationTransition Generation2 Generation3 [DocumentRow, JobRow] ReleaseRow
    ]

everyTransactionDeclaration :: [TransactionDeclaration]
everyTransactionDeclaration =
  [ TransactionDeclaration "insert-document" InsertOperation documentDeclaration "scoped-inserted" Nothing (rowColumns documentDeclaration)
  , TransactionDeclaration "read-document" SelectOneOperation documentDeclaration "scoped-maybe-document" (Just (Column "document_id" TextColumn, "document_id")) []
  , TransactionDeclaration "list-subject-jobs" SelectManyOperation jobDeclaration "scoped-job-list" Nothing []
  , TransactionDeclaration "advance-job-status" UpdateOperation jobDeclaration "scoped-updated" (Just (Column "job_id" TextColumn, "job_id")) [Column "status" TextColumn]
  , TransactionDeclaration "record-release" InsertOperation releaseDeclaration "scoped-inserted" Nothing (rowColumns releaseDeclaration)
  ]

renderRow :: RowDeclaration -> [Text]
renderRow declaration =
  [ renderCreateTableDeclaration declaration
  , "ALTER TABLE " <> rowTable declaration <> " ENABLE ROW LEVEL SECURITY;"
  , "CREATE POLICY " <> rowTable declaration <> "_tenant_scope ON " <> rowTable declaration
      <> " USING (" <> renderScopePredicate declaration <> ") WITH CHECK (" <> renderScopePredicate declaration <> ");"
  ]

renderColumn :: Column -> Text
renderColumn column = columnName column <> " " <> renderColumnKind (columnKind column) <> " NOT NULL"

renderColumnKind :: ColumnKind -> Text
renderColumnKind kind = case kind of
  TextColumn -> "TEXT"

renderStatement :: TransactionDeclaration -> [Text]
renderStatement declaration =
  ["-- transaction " <> declarationName declaration, statement <> ";"]
 where
  table = rowTable (declarationRow declaration)
  scope = renderScopePredicate (declarationRow declaration)
  extra = maybe "" (\(column, parameter) -> " AND " <> columnName column <> " = $" <> parameter) (declarationExtraPredicate declaration)
  columns = declarationWriteColumns declaration
  statement = case declarationOperation declaration of
    InsertOperation ->
      "INSERT INTO " <> table <> " (" <> Text.intercalate ", " (map columnName columns) <> ") VALUES ("
        <> Text.intercalate ", " (map (("$" <>) . parameterName) columns) <> ")"
    SelectOneOperation -> "SELECT * FROM " <> table <> " WHERE " <> scope <> extra
    SelectManyOperation -> "SELECT * FROM " <> table <> " WHERE " <> scope
    UpdateOperation ->
      "UPDATE " <> table <> " SET "
        <> Text.intercalate ", " [columnName column <> " = $" <> parameterName column | column <- columns]
        <> " WHERE " <> scope <> extra

renderScopePredicate :: RowDeclaration -> Text
renderScopePredicate declaration = case scopePredicate declaration of
  ScopeEquals column parameter ->
    columnName column <> " = current_setting('amoebius." <> parameter <> "', true)"

renderTransition :: GenerationTransition -> [Text]
renderTransition transition =
  [ "-- generation " <> generationTag (transitionFrom transition) <> " to " <> generationTag (transitionTo transition)
  , renderCreateTable (transitionAdded transition)
  ]

renderCreateTable :: RowKind -> Text
renderCreateTable = renderCreateTableDeclaration . rowDeclarationFor

renderCreateTableDeclaration :: RowDeclaration -> Text
renderCreateTableDeclaration declaration =
  "CREATE TABLE " <> rowTable declaration <> " ("
    <> Text.intercalate ", " (map renderColumn (rowColumns declaration))
    <> ", PRIMARY KEY (" <> Text.intercalate ", " (map columnName (rowPrimaryKey declaration)) <> ")"
    <> ", FOREIGN KEY (" <> columnName (rowScopeColumn declaration) <> ") REFERENCES amoebius_scope(tenant_id));"

rowDeclarationFor :: RowKind -> RowDeclaration
rowDeclarationFor kind = case kind of
  DocumentRow -> documentDeclaration
  JobRow -> jobDeclaration
  ReleaseRow -> releaseDeclaration

columnName :: Column -> Text
columnName (Column name _) = name

columnKind :: Column -> ColumnKind
columnKind (Column _ kind) = kind

parameterName :: Column -> Text
parameterName column
  | columnName column == "tenant_id" = "scope_tenant"
  | otherwise = columnName column

generationTag :: SchemaGeneration -> Text
generationTag generation = case generation of
  Generation1 -> "1"
  Generation2 -> "2"
  Generation3 -> "3"
