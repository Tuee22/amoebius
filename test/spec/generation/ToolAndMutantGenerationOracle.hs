{-# LANGUAGE OverloadedStrings #-}

module ToolAndMutantGenerationOracle
  ( OracleArtifact (..)
  , expectedArtifacts
  , expectedClassCounts
  , expectedRefusals
  ) where

import Data.ByteString (ByteString)
import Data.Text (Text)

data OracleArtifact = OracleArtifact
  { oracleIdentity :: Text
  , oracleClass :: Text
  , oracleLogicalPath :: FilePath
  , oracleBytes :: ByteString
  }
  deriving stock (Eq, Show)

expectedArtifacts :: [OracleArtifact]
expectedArtifacts =
  [ row "tool.validate-phase" "checking-tool" "validate-phase"
      "#!/bin/sh\nset -eu\n: \"${AMOEBIUS_SOURCE_BOUND_BINARY:?}\"\nexec \"$AMOEBIUS_SOURCE_BOUND_BINARY\" validate phase \"$@\"\n"
  , row "tool.check-documentation" "checking-tool" "check-documentation"
      "#!/bin/sh\nset -eu\n: \"${AMOEBIUS_SOURCE_BOUND_BINARY:?}\"\nexec \"$AMOEBIUS_SOURCE_BOUND_BINARY\" validate phase 00\n"
  , row "tool.check-source-closure" "checking-tool" "check-source-closure"
      "#!/bin/sh\nset -eu\n: \"${AMOEBIUS_SOURCE_BOUND_BINARY:?}\"\nexec \"$AMOEBIUS_SOURCE_BOUND_BINARY\" validate phase 02\n"
  , row "case.source-closure-positive" "serialized-test-case" "source-closure/positive.json"
      "{\"case\":\"haskell-source\",\"path\":\"src/Example.hs\",\"expected\":\"accepted\"}\n"
  , row "case.source-closure-negative" "serialized-test-case" "source-closure/non-haskell-source.json"
      "{\"case\":\"foreign-source\",\"path\":\"tools/example.py\",\"expected\":\"rejected\",\"reason\":\"tracked-behavioral-source-must-be-haskell\"}\n"
  , row "mutant.missing-rule" "mutation-body" "checking-corpus/missing-rule.patch"
      "operator=drop-declaration\nlocus=supportCorpus.tools\nexpected=artifact-set-mismatch\n"
  , row "mutant.drop-operator" "mutation-body" "checking-corpus/drop-operator.patch"
      "operator=drop-mutation\nlocus=supportCorpus.mutations\nexpected=mutation-set-mismatch\n"
  , row "mutant.tracked-output" "mutation-body" "checking-corpus/tracked-output.patch"
      "operator=select-authored-tree\nlocus=outputPolicy\nexpected=output-policy-refused\n"
  , row "pulumi.child-cluster" "pulumi-program" "child-cluster/Pulumi.yaml"
      "name: amoebius-child-cluster\nruntime: yaml\ndescription: Generated provider program metadata; Haskell owns the declaration.\n"
  ]
 where
  row = OracleArtifact

expectedClassCounts :: [(Text, Int)]
expectedClassCounts =
  [ ("checking-tool", 3)
  , ("serialized-test-case", 2)
  , ("mutation-body", 3)
  , ("pulumi-program", 1)
  ]

expectedRefusals :: [(Text, Text)]
expectedRefusals =
  [ ("relative-project", "ProjectRootMustBeAbsolute")
  , ("authored-output", "OutputRootMustBeBuildRoot")
  , ("path-run-identity", "InvalidRunIdentity")
  ]
