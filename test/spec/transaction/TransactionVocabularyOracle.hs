{-# LANGUAGE OverloadedStrings #-}

{- | Independently authored Phase-36 expectations. This module deliberately
imports no production or shared fixture module.
-}
module TransactionVocabularyOracle (
    rowOracle,
    transactionOracle,
    generationOracle,
    calculusOracle,
    compileBarrierOracle,
    mutantOracle,
    validationLoci,
) where

import Data.Text (Text)

rowOracle :: [[Text]]
rowOracle =
    [ ["document", "documents", "tenant_id:text:not-null|document_id:text:not-null|body:text:not-null", "tenant_id,document_id", "tenant_id->amoebius_scope.tenant_id", "tenant_id", "scope_tenant"]
    , ["job", "jobs", "tenant_id:text:not-null|subject_id:text:not-null|job_id:text:not-null|status:text:not-null", "tenant_id,job_id", "tenant_id->amoebius_scope.tenant_id", "tenant_id", "scope_tenant"]
    , ["release", "releases", "tenant_id:text:not-null|release_id:text:not-null|content_digest:text:not-null", "tenant_id,release_id", "tenant_id->amoebius_scope.tenant_id", "tenant_id", "scope_tenant"]
    ]

transactionOracle :: [[Text]]
transactionOracle =
    [ ["insert-document", "insert", "documents", "tenant_id", "scope_tenant", "scoped-inserted"]
    , ["read-document", "select-one", "documents", "tenant_id", "scope_tenant", "scoped-maybe-document"]
    , ["list-subject-jobs", "select-many", "jobs", "tenant_id", "scope_tenant", "scoped-job-list"]
    , ["advance-job-status", "update", "jobs", "tenant_id", "scope_tenant", "scoped-updated"]
    , ["record-release", "insert", "releases", "tenant_id", "scope_tenant", "scoped-inserted"]
    ]

generationOracle :: [[Text]]
generationOracle =
    [ ["generation-1-to-2", "1", "2", "admitted", "document", "job", "create-table"]
    , ["generation-2-to-3", "2", "3", "admitted", "document,job", "release", "create-table"]
    , ["generation-2-to-1", "2", "1", "generation-regression", "—", "—", "—"]
    , ["generation-1-to-3", "1", "3", "generation-skipped", "—", "—", "—"]
    , ["generation-3-to-3", "3", "3", "generation-current", "—", "—", "—"]
    ]

calculusOracle :: [[Text]]
calculusOracle =
    [ ["calculus-kinds", "artifact,budget,lift,workflow,evidence"]
    , ["component-names", "row-semantics,transaction-semantics,compile-barriers,generation-cases,mutant-evidence"]
    , ["projection-counts", "3,5,4,5,3"]
    , ["resource-vector", "5,20,0,0"]
    ]

compileBarrierOracle :: [(Text, Text, [Text])]
compileBarrierOracle =
    [ ("unscoped-transaction", "transaction-vocabulary-test-unscoped", ["applied to too few arguments", "RequestScope"])
    , ("raw-statement", "transaction-vocabulary-test-raw-query", ["rawStatement", "does not export"])
    , ("predicate-constructor", "transaction-vocabulary-test-predicate", ["Vocabulary.predicate", "does not export"])
    , ("cross-scope-composition", "transaction-vocabulary-test-cross-scope", ["Couldn't match type", "rightScope"])
    ]

mutantOracle :: [(Text, Text, Text, Text)]
mutantOracle =
    [ ("transaction-optional-scope", "transaction-vocabulary-optional-scope-mutant", "Vocabulary.projectPredicate", "a transaction scope became optional")
    , ("transaction-match-all", "transaction-vocabulary-match-all-mutant", "Vocabulary.scopePredicate", "row/schema/policy semantic oracle drifted")
    , ("transaction-wrong-policy-column", "transaction-vocabulary-wrong-policy-column-mutant", "Vocabulary.projectRow", "row/schema/policy semantic oracle drifted")
    ]

validationLoci :: [(Text, Text)]
validationLoci =
    [(name, "row") | name <- ["document", "job", "release"]]
        <> [(name, "transaction") | name <- ["insert-document", "read-document", "list-subject-jobs", "advance-job-status", "record-release"]]
        <> [(name, "generation") | name <- ["generation-1-to-2", "generation-2-to-3", "generation-2-to-1", "generation-1-to-3", "generation-3-to-3"]]
        <> [(name, "compile-barrier") | (name, _, _) <- compileBarrierOracle]
        <> [(name, "mutant") | (name, _, _, _) <- mutantOracle]
