{-# LANGUAGE OverloadedStrings #-}

module LegacyOracle
  ( legacySelectorAssignments
  , legacySelectorNames
  , runLegacyOracle
  , runLegacySelectorOracle
  , runLegacyUnaffectedControl
  ) where

-- Hardware-free component diagnostic only.  Fixtures, the 25-by-7 binding
-- table, the nine source-debt joins, exact ordered CheckResults, and selector
-- intent are oracle-owned literals.  This module imports only the refusal-only
-- public facade and performs no ambient I/O.

import Amoebius.Validation.Legacy (legacyDiagnostic)
import Amoebius.Validation.Types (CheckResult (..), Finding (..), Observation (..))
import Control.Monad (unless)
import Crypto.Hash qualified as Crypto
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteString8
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding

type RawBinding = (Text, Text, Text, Text, Text, Text, [Text])
type RawJoin = (Text, Text)

maximumPhaseBytes, maximumBindings, maximumJoins, maximumIdBytes, maximumDispositionBytes :: Int
maximumPhaseBytes = 2
maximumBindings = 25
maximumJoins = 9
maximumIdBytes = 12
maximumDispositionBytes = 8

maximumOwnerBytes, maximumAnalyzerBytes, maximumObservationBytes, maximumClosureBytes :: Int
maximumOwnerBytes = 2
maximumAnalyzerBytes = 64
maximumObservationBytes = 64
maximumClosureBytes = 64

maximumReintroductionValues, maximumReintroductionBytes, maximumJoinSourceBytes, maximumJoinTargetBytes, maximumAggregateBytes :: Int
maximumReintroductionValues = 4
maximumReintroductionBytes = 64
maximumJoinSourceBytes = 32
maximumJoinTargetBytes = 12
maximumAggregateBytes = 2706

data ExactCase = ExactCase
  { exactLabel :: String
  , exactPhase :: Text
  , exactBindings :: [RawBinding]
  , exactJoins :: [RawJoin]
  , exactExpected :: CheckResult
  }

data LiteralProblem = LiteralProblem
  { problemCode :: Text
  , problemSubject :: FilePath
  , problemDetail :: Text
  }

data LiteralCommitment
  = CompleteCommitment
  | BoundedCommitment Text

legacySelectorIntents :: [(String, String, String)]
legacySelectorIntents =
  [ ("VALIDATION_LEGACY_LTD_SRC000_ID_MUTANT", "LTD-SRC-000 stable ID cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC000_DISPOSITION_MUTANT", "LTD-SRC-000 disposition cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC000_OWNER_MUTANT", "LTD-SRC-000 owner cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC000_ANALYZER_MUTANT", "LTD-SRC-000 analyzer cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC000_OBSERVATION_MUTANT", "LTD-SRC-000 observation cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC000_CLOSURE_MUTANT", "LTD-SRC-000 closure cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC000_REINTRODUCTION_MUTANT", "LTD-SRC-000 reintroduction cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC001_ID_MUTANT", "LTD-SRC-001 stable ID cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC001_DISPOSITION_MUTANT", "LTD-SRC-001 disposition cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC001_OWNER_MUTANT", "LTD-SRC-001 owner cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC001_ANALYZER_MUTANT", "LTD-SRC-001 analyzer cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC001_OBSERVATION_MUTANT", "LTD-SRC-001 observation cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC001_CLOSURE_MUTANT", "LTD-SRC-001 closure cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC001_REINTRODUCTION_MUTANT", "LTD-SRC-001 reintroduction cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC002_ID_MUTANT", "LTD-SRC-002 stable ID cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC002_DISPOSITION_MUTANT", "LTD-SRC-002 disposition cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC002_OWNER_MUTANT", "LTD-SRC-002 owner cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC002_ANALYZER_MUTANT", "LTD-SRC-002 analyzer cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC002_OBSERVATION_MUTANT", "LTD-SRC-002 observation cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC002_CLOSURE_MUTANT", "LTD-SRC-002 closure cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC002_REINTRODUCTION_MUTANT", "LTD-SRC-002 reintroduction cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC003_ID_MUTANT", "LTD-SRC-003 stable ID cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC003_DISPOSITION_MUTANT", "LTD-SRC-003 disposition cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC003_OWNER_MUTANT", "LTD-SRC-003 owner cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC003_ANALYZER_MUTANT", "LTD-SRC-003 analyzer cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC003_OBSERVATION_MUTANT", "LTD-SRC-003 observation cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC003_CLOSURE_MUTANT", "LTD-SRC-003 closure cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC003_REINTRODUCTION_MUTANT", "LTD-SRC-003 reintroduction cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC004_ID_MUTANT", "LTD-SRC-004 stable ID cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC004_DISPOSITION_MUTANT", "LTD-SRC-004 disposition cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC004_OWNER_MUTANT", "LTD-SRC-004 owner cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC004_ANALYZER_MUTANT", "LTD-SRC-004 analyzer cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC004_OBSERVATION_MUTANT", "LTD-SRC-004 observation cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC004_CLOSURE_MUTANT", "LTD-SRC-004 closure cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC004_REINTRODUCTION_MUTANT", "LTD-SRC-004 reintroduction cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC005_ID_MUTANT", "LTD-SRC-005 stable ID cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC005_DISPOSITION_MUTANT", "LTD-SRC-005 disposition cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC005_OWNER_MUTANT", "LTD-SRC-005 owner cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC005_ANALYZER_MUTANT", "LTD-SRC-005 analyzer cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC005_OBSERVATION_MUTANT", "LTD-SRC-005 observation cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC005_CLOSURE_MUTANT", "LTD-SRC-005 closure cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC005_REINTRODUCTION_MUTANT", "LTD-SRC-005 reintroduction cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC006_ID_MUTANT", "LTD-SRC-006 stable ID cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC006_DISPOSITION_MUTANT", "LTD-SRC-006 disposition cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC006_OWNER_MUTANT", "LTD-SRC-006 owner cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC006_ANALYZER_MUTANT", "LTD-SRC-006 analyzer cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC006_OBSERVATION_MUTANT", "LTD-SRC-006 observation cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC006_CLOSURE_MUTANT", "LTD-SRC-006 closure cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC006_REINTRODUCTION_MUTANT", "LTD-SRC-006 reintroduction cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC007_ID_MUTANT", "LTD-SRC-007 stable ID cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC007_DISPOSITION_MUTANT", "LTD-SRC-007 disposition cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC007_OWNER_MUTANT", "LTD-SRC-007 owner cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC007_ANALYZER_MUTANT", "LTD-SRC-007 analyzer cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC007_OBSERVATION_MUTANT", "LTD-SRC-007 observation cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC007_CLOSURE_MUTANT", "LTD-SRC-007 closure cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC007_REINTRODUCTION_MUTANT", "LTD-SRC-007 reintroduction cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC008_ID_MUTANT", "LTD-SRC-008 stable ID cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC008_DISPOSITION_MUTANT", "LTD-SRC-008 disposition cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC008_OWNER_MUTANT", "LTD-SRC-008 owner cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC008_ANALYZER_MUTANT", "LTD-SRC-008 analyzer cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC008_OBSERVATION_MUTANT", "LTD-SRC-008 observation cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC008_CLOSURE_MUTANT", "LTD-SRC-008 closure cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC008_REINTRODUCTION_MUTANT", "LTD-SRC-008 reintroduction cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC009_ID_MUTANT", "LTD-SRC-009 stable ID cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC009_DISPOSITION_MUTANT", "LTD-SRC-009 disposition cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC009_OWNER_MUTANT", "LTD-SRC-009 owner cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC009_ANALYZER_MUTANT", "LTD-SRC-009 analyzer cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC009_OBSERVATION_MUTANT", "LTD-SRC-009 observation cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC009_CLOSURE_MUTANT", "LTD-SRC-009 closure cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SRC009_REINTRODUCTION_MUTANT", "LTD-SRC-009 reintroduction cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_META001_ID_MUTANT", "LTD-META-001 stable ID cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_META001_DISPOSITION_MUTANT", "LTD-META-001 disposition cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_META001_OWNER_MUTANT", "LTD-META-001 owner cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_META001_ANALYZER_MUTANT", "LTD-META-001 analyzer cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_META001_OBSERVATION_MUTANT", "LTD-META-001 observation cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_META001_CLOSURE_MUTANT", "LTD-META-001 closure cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_META001_REINTRODUCTION_MUTANT", "LTD-META-001 reintroduction cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL001_ID_MUTANT", "LTD-VAL-001 stable ID cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL001_DISPOSITION_MUTANT", "LTD-VAL-001 disposition cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL001_OWNER_MUTANT", "LTD-VAL-001 owner cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL001_ANALYZER_MUTANT", "LTD-VAL-001 analyzer cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL001_OBSERVATION_MUTANT", "LTD-VAL-001 observation cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL001_CLOSURE_MUTANT", "LTD-VAL-001 closure cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL001_REINTRODUCTION_MUTANT", "LTD-VAL-001 reintroduction cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL002_ID_MUTANT", "LTD-VAL-002 stable ID cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL002_DISPOSITION_MUTANT", "LTD-VAL-002 disposition cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL002_OWNER_MUTANT", "LTD-VAL-002 owner cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL002_ANALYZER_MUTANT", "LTD-VAL-002 analyzer cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL002_OBSERVATION_MUTANT", "LTD-VAL-002 observation cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL002_CLOSURE_MUTANT", "LTD-VAL-002 closure cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL002_REINTRODUCTION_MUTANT", "LTD-VAL-002 reintroduction cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL003_ID_MUTANT", "LTD-VAL-003 stable ID cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL003_DISPOSITION_MUTANT", "LTD-VAL-003 disposition cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL003_OWNER_MUTANT", "LTD-VAL-003 owner cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL003_ANALYZER_MUTANT", "LTD-VAL-003 analyzer cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL003_OBSERVATION_MUTANT", "LTD-VAL-003 observation cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL003_CLOSURE_MUTANT", "LTD-VAL-003 closure cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL003_REINTRODUCTION_MUTANT", "LTD-VAL-003 reintroduction cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL004_ID_MUTANT", "LTD-VAL-004 stable ID cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL004_DISPOSITION_MUTANT", "LTD-VAL-004 disposition cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL004_OWNER_MUTANT", "LTD-VAL-004 owner cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL004_ANALYZER_MUTANT", "LTD-VAL-004 analyzer cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL004_OBSERVATION_MUTANT", "LTD-VAL-004 observation cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL004_CLOSURE_MUTANT", "LTD-VAL-004 closure cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL004_REINTRODUCTION_MUTANT", "LTD-VAL-004 reintroduction cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL005_ID_MUTANT", "LTD-VAL-005 stable ID cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL005_DISPOSITION_MUTANT", "LTD-VAL-005 disposition cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL005_OWNER_MUTANT", "LTD-VAL-005 owner cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL005_ANALYZER_MUTANT", "LTD-VAL-005 analyzer cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL005_OBSERVATION_MUTANT", "LTD-VAL-005 observation cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL005_CLOSURE_MUTANT", "LTD-VAL-005 closure cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL005_REINTRODUCTION_MUTANT", "LTD-VAL-005 reintroduction cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL006_ID_MUTANT", "LTD-VAL-006 stable ID cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL006_DISPOSITION_MUTANT", "LTD-VAL-006 disposition cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL006_OWNER_MUTANT", "LTD-VAL-006 owner cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL006_ANALYZER_MUTANT", "LTD-VAL-006 analyzer cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL006_OBSERVATION_MUTANT", "LTD-VAL-006 observation cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL006_CLOSURE_MUTANT", "LTD-VAL-006 closure cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_VAL006_REINTRODUCTION_MUTANT", "LTD-VAL-006 reintroduction cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_DOC001_ID_MUTANT", "LTD-DOC-001 stable ID cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_DOC001_DISPOSITION_MUTANT", "LTD-DOC-001 disposition cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_DOC001_OWNER_MUTANT", "LTD-DOC-001 owner cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_DOC001_ANALYZER_MUTANT", "LTD-DOC-001 analyzer cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_DOC001_OBSERVATION_MUTANT", "LTD-DOC-001 observation cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_DOC001_CLOSURE_MUTANT", "LTD-DOC-001 closure cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_DOC001_REINTRODUCTION_MUTANT", "LTD-DOC-001 reintroduction cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_NAME001_ID_MUTANT", "LTD-NAME-001 stable ID cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_NAME001_DISPOSITION_MUTANT", "LTD-NAME-001 disposition cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_NAME001_OWNER_MUTANT", "LTD-NAME-001 owner cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_NAME001_ANALYZER_MUTANT", "LTD-NAME-001 analyzer cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_NAME001_OBSERVATION_MUTANT", "LTD-NAME-001 observation cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_NAME001_CLOSURE_MUTANT", "LTD-NAME-001 closure cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_NAME001_REINTRODUCTION_MUTANT", "LTD-NAME-001 reintroduction cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_HOST001_ID_MUTANT", "LTD-HOST-001 stable ID cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_HOST001_DISPOSITION_MUTANT", "LTD-HOST-001 disposition cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_HOST001_OWNER_MUTANT", "LTD-HOST-001 owner cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_HOST001_ANALYZER_MUTANT", "LTD-HOST-001 analyzer cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_HOST001_OBSERVATION_MUTANT", "LTD-HOST-001 observation cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_HOST001_CLOSURE_MUTANT", "LTD-HOST-001 closure cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_HOST001_REINTRODUCTION_MUTANT", "LTD-HOST-001 reintroduction cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_HOST002_ID_MUTANT", "LTD-HOST-002 stable ID cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_HOST002_DISPOSITION_MUTANT", "LTD-HOST-002 disposition cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_HOST002_OWNER_MUTANT", "LTD-HOST-002 owner cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_HOST002_ANALYZER_MUTANT", "LTD-HOST-002 analyzer cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_HOST002_OBSERVATION_MUTANT", "LTD-HOST-002 observation cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_HOST002_CLOSURE_MUTANT", "LTD-HOST-002 closure cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_HOST002_REINTRODUCTION_MUTANT", "LTD-HOST-002 reintroduction cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_IMG001_ID_MUTANT", "LTD-IMG-001 stable ID cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_IMG001_DISPOSITION_MUTANT", "LTD-IMG-001 disposition cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_IMG001_OWNER_MUTANT", "LTD-IMG-001 owner cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_IMG001_ANALYZER_MUTANT", "LTD-IMG-001 analyzer cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_IMG001_OBSERVATION_MUTANT", "LTD-IMG-001 observation cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_IMG001_CLOSURE_MUTANT", "LTD-IMG-001 closure cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_IMG001_REINTRODUCTION_MUTANT", "LTD-IMG-001 reintroduction cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_RUN001_ID_MUTANT", "LTD-RUN-001 stable ID cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_RUN001_DISPOSITION_MUTANT", "LTD-RUN-001 disposition cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_RUN001_OWNER_MUTANT", "LTD-RUN-001 owner cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_RUN001_ANALYZER_MUTANT", "LTD-RUN-001 analyzer cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_RUN001_OBSERVATION_MUTANT", "LTD-RUN-001 observation cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_RUN001_CLOSURE_MUTANT", "LTD-RUN-001 closure cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_RUN001_REINTRODUCTION_MUTANT", "LTD-RUN-001 reintroduction cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SEED001_ID_MUTANT", "LTD-SEED-001 stable ID cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SEED001_DISPOSITION_MUTANT", "LTD-SEED-001 disposition cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SEED001_OWNER_MUTANT", "LTD-SEED-001 owner cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SEED001_ANALYZER_MUTANT", "LTD-SEED-001 analyzer cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SEED001_OBSERVATION_MUTANT", "LTD-SEED-001 observation cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SEED001_CLOSURE_MUTANT", "LTD-SEED-001 closure cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SEED001_REINTRODUCTION_MUTANT", "LTD-SEED-001 reintroduction cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SEED002_ID_MUTANT", "LTD-SEED-002 stable ID cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SEED002_DISPOSITION_MUTANT", "LTD-SEED-002 disposition cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SEED002_OWNER_MUTANT", "LTD-SEED-002 owner cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SEED002_ANALYZER_MUTANT", "LTD-SEED-002 analyzer cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SEED002_OBSERVATION_MUTANT", "LTD-SEED-002 observation cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SEED002_CLOSURE_MUTANT", "LTD-SEED-002 closure cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_LTD_SEED002_REINTRODUCTION_MUTANT", "LTD-SEED-002 reintroduction cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_SOURCE_TOOLS_SOURCE_MUTANT", "source-tools join source cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_SOURCE_TOOLS_TARGET_MUTANT", "source-tools join target cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_SOURCE_DHALL_SOURCE_MUTANT", "source-dhall join source cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_SOURCE_DHALL_TARGET_MUTANT", "source-dhall join target cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_SOURCE_PROTO_SOURCE_MUTANT", "source-proto join source cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_SOURCE_PROTO_TARGET_MUTANT", "source-proto join target cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_SOURCE_UI_SOURCE_MUTANT", "source-ui join source cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_SOURCE_UI_TARGET_MUTANT", "source-ui join target cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_SOURCE_PULUMI_SOURCE_MUTANT", "source-pulumi join source cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_SOURCE_PULUMI_TARGET_MUTANT", "source-pulumi join target cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_SOURCE_TEST_SOURCE_MUTANT", "source-test join source cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_SOURCE_TEST_TARGET_MUTANT", "source-test join target cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_SOURCE_PROBE_SOURCE_MUTANT", "source-probe join source cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_SOURCE_PROBE_TARGET_MUTANT", "source-probe join target cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_SOURCE_PB_SOURCE_MUTANT", "source-pb join source cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_SOURCE_PB_TARGET_MUTANT", "source-pb join target cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_SOURCE_VENDOR_SOURCE_MUTANT", "source-vendor join source cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_SOURCE_VENDOR_TARGET_MUTANT", "source-vendor join target cell", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SELECT_LTD_SRC000_DROP_MUTANT", "LTD-SRC-000 binding composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SELECT_LTD_SRC001_DROP_MUTANT", "LTD-SRC-001 binding composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SELECT_LTD_SRC002_DROP_MUTANT", "LTD-SRC-002 binding composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SELECT_LTD_SRC003_DROP_MUTANT", "LTD-SRC-003 binding composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SELECT_LTD_SRC004_DROP_MUTANT", "LTD-SRC-004 binding composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SELECT_LTD_SRC005_DROP_MUTANT", "LTD-SRC-005 binding composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SELECT_LTD_SRC006_DROP_MUTANT", "LTD-SRC-006 binding composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SELECT_LTD_SRC007_DROP_MUTANT", "LTD-SRC-007 binding composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SELECT_LTD_SRC008_DROP_MUTANT", "LTD-SRC-008 binding composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SELECT_LTD_SRC009_DROP_MUTANT", "LTD-SRC-009 binding composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SELECT_LTD_META001_DROP_MUTANT", "LTD-META-001 binding composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SELECT_LTD_VAL001_DROP_MUTANT", "LTD-VAL-001 binding composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SELECT_LTD_VAL002_DROP_MUTANT", "LTD-VAL-002 binding composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SELECT_LTD_VAL003_DROP_MUTANT", "LTD-VAL-003 binding composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SELECT_LTD_VAL004_DROP_MUTANT", "LTD-VAL-004 binding composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SELECT_LTD_VAL005_DROP_MUTANT", "LTD-VAL-005 binding composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SELECT_LTD_VAL006_DROP_MUTANT", "LTD-VAL-006 binding composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SELECT_LTD_DOC001_DROP_MUTANT", "LTD-DOC-001 binding composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SELECT_LTD_NAME001_DROP_MUTANT", "LTD-NAME-001 binding composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SELECT_LTD_HOST001_DROP_MUTANT", "LTD-HOST-001 binding composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SELECT_LTD_HOST002_DROP_MUTANT", "LTD-HOST-002 binding composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SELECT_LTD_IMG001_DROP_MUTANT", "LTD-IMG-001 binding composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SELECT_LTD_RUN001_DROP_MUTANT", "LTD-RUN-001 binding composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SELECT_LTD_SEED001_DROP_MUTANT", "LTD-SEED-001 binding composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SELECT_LTD_SEED002_DROP_MUTANT", "LTD-SEED-002 binding composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SELECT_JOIN_SOURCE_TOOLS_DROP_MUTANT", "source-tools join composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SELECT_JOIN_SOURCE_DHALL_DROP_MUTANT", "source-dhall join composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SELECT_JOIN_SOURCE_PROTO_DROP_MUTANT", "source-proto join composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SELECT_JOIN_SOURCE_UI_DROP_MUTANT", "source-ui join composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SELECT_JOIN_SOURCE_PULUMI_DROP_MUTANT", "source-pulumi join composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SELECT_JOIN_SOURCE_TEST_DROP_MUTANT", "source-test join composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SELECT_JOIN_SOURCE_PROBE_DROP_MUTANT", "source-probe join composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SELECT_JOIN_SOURCE_PB_DROP_MUTANT", "source-pb join composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SELECT_JOIN_SOURCE_VENDOR_DROP_MUTANT", "source-vendor join composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_RAW_DIAGNOSTIC_ONLY_DROP_MUTANT", "diagnostic-only residue", "canonical legacy wire")
  , ("VALIDATION_LEGACY_RAW_SOURCE_BINDING_DROP_MUTANT", "source-binding residue", "canonical legacy wire")
  , ("VALIDATION_LEGACY_RAW_ANALYZER_EVIDENCE_DROP_MUTANT", "analyzer-evidence residue", "canonical legacy wire")
  , ("VALIDATION_LEGACY_RAW_REINTRODUCTION_EXECUTION_DROP_MUTANT", "reintroduction-execution residue", "canonical legacy wire")
  , ("VALIDATION_LEGACY_RAW_QUALIFICATION_DROP_MUTANT", "qualification residue", "canonical legacy wire")
  , ("VALIDATION_LEGACY_RAW_DOCUMENTATION_CORRESPONDENCE_DROP_MUTANT", "documentation-correspondence residue", "canonical legacy wire")
  , ("VALIDATION_LEGACY_RAW_LATER_PHASE_BLOCK_BYPASS_MUTANT", "later-phase route", "later phase route")
  , ("VALIDATION_LEGACY_RAW_PHASE_BYTE_LIMIT_BYPASS_MUTANT", "phase byte bound", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_RAW_BINDING_LIMIT_BYPASS_MUTANT", "binding count bound", "binding count maximum plus one")
  , ("VALIDATION_LEGACY_RAW_JOIN_LIMIT_BYPASS_MUTANT", "join count bound", "join count maximum plus one")
  , ("VALIDATION_LEGACY_RAW_ID_BYTE_LIMIT_BYPASS_MUTANT", "stable ID byte bound", "stable ID bytes maximum plus one")
  , ("VALIDATION_LEGACY_RAW_DISPOSITION_BYTE_LIMIT_BYPASS_MUTANT", "disposition byte bound", "disposition bytes maximum plus one")
  , ("VALIDATION_LEGACY_RAW_OWNER_BYTE_LIMIT_BYPASS_MUTANT", "owner byte bound", "owner bytes maximum plus one")
  , ("VALIDATION_LEGACY_RAW_ANALYZER_BYTE_LIMIT_BYPASS_MUTANT", "analyzer byte bound", "analyzer bytes maximum plus one")
  , ("VALIDATION_LEGACY_RAW_OBSERVATION_BYTE_LIMIT_BYPASS_MUTANT", "observation byte bound", "observation bytes maximum plus one")
  , ("VALIDATION_LEGACY_RAW_CLOSURE_BYTE_LIMIT_BYPASS_MUTANT", "closure byte bound", "closure bytes maximum plus one")
  , ("VALIDATION_LEGACY_RAW_REINTRODUCTION_COUNT_LIMIT_BYPASS_MUTANT", "reintroduction count bound", "reintroduction count maximum plus one")
  , ("VALIDATION_LEGACY_RAW_REINTRODUCTION_BYTE_LIMIT_BYPASS_MUTANT", "reintroduction byte bound", "reintroduction bytes maximum plus one")
  , ("VALIDATION_LEGACY_RAW_JOIN_SOURCE_BYTE_LIMIT_BYPASS_MUTANT", "join source byte bound", "join source bytes maximum plus one")
  , ("VALIDATION_LEGACY_RAW_JOIN_TARGET_BYTE_LIMIT_BYPASS_MUTANT", "join target byte bound", "join target bytes maximum plus one")
  , ("VALIDATION_LEGACY_RAW_AGGREGATE_BYTE_LIMIT_BYPASS_MUTANT", "aggregate byte bound", "aggregate bytes maximum plus one")
  , ("VALIDATION_LEGACY_RAW_PHASE_WIDTH_BYPASS_MUTANT", "phase width predicate", "phase width negative")
  , ("VALIDATION_LEGACY_RAW_PHASE_ALPHABET_BYPASS_MUTANT", "Amoebius.Validation.Legacy.legacyPhaseAlphabetValid all-character quantifier", "phase alphabet lower negative")
  , ("VALIDATION_LEGACY_RAW_PHASE_ALPHABET_LOWER_BYPASS_MUTANT", "Amoebius.Validation.Legacy.legacyPhaseCharacterLowerBoundValid lower ASCII decimal bound", "phase alphabet lower negative")
  , ("VALIDATION_LEGACY_RAW_PHASE_ALPHABET_UPPER_BYPASS_MUTANT", "Amoebius.Validation.Legacy.legacyPhaseCharacterUpperBoundValid upper ASCII decimal bound", "phase alphabet negative")
  , ("VALIDATION_LEGACY_RAW_PHASE_CHARACTER_COMPOSITION_MUTANT", "Amoebius.Validation.Legacy.legacyPhaseCharacterValid lower-and-upper ASCII range composition", "phase alphabet negative")
  , ("VALIDATION_LEGACY_RAW_PHASE_RANGE_BYPASS_MUTANT", "phase range predicate", "phase range maximum plus one")
  , ("VALIDATION_LEGACY_RAW_BINDING_CARDINALITY_BYPASS_MUTANT", "binding cardinality predicate", "binding cardinality negative")
  , ("VALIDATION_LEGACY_RAW_BINDING_DUPLICATE_BYPASS_MUTANT", "binding duplicate predicate", "binding duplicate negative")
  , ("VALIDATION_LEGACY_RAW_BINDING_UNKNOWN_BYPASS_MUTANT", "binding universe predicate", "binding unknown negative")
  , ("VALIDATION_LEGACY_RAW_BINDING_ORDER_BYPASS_MUTANT", "binding order predicate", "binding order negative")
  , ("VALIDATION_LEGACY_RAW_DISPOSITION_MATCH_BYPASS_MUTANT", "binding disposition equality predicate", "binding disposition negative")
  , ("VALIDATION_LEGACY_RAW_OWNER_MATCH_BYPASS_MUTANT", "binding owner equality predicate", "binding owner negative")
  , ("VALIDATION_LEGACY_RAW_ANALYZER_MATCH_BYPASS_MUTANT", "binding analyzer equality predicate", "binding analyzer negative")
  , ("VALIDATION_LEGACY_RAW_OBSERVATION_MATCH_BYPASS_MUTANT", "binding observation equality predicate", "binding observation negative")
  , ("VALIDATION_LEGACY_RAW_CLOSURE_MATCH_BYPASS_MUTANT", "binding closure equality predicate", "binding closure negative")
  , ("VALIDATION_LEGACY_RAW_REINTRODUCTION_MATCH_BYPASS_MUTANT", "binding reintroduction equality predicate", "binding reintroduction negative")
  , ("VALIDATION_LEGACY_RAW_JOIN_CARDINALITY_BYPASS_MUTANT", "join cardinality predicate", "join cardinality negative")
  , ("VALIDATION_LEGACY_RAW_JOIN_DUPLICATE_BYPASS_MUTANT", "join duplicate predicate", "join duplicate negative")
  , ("VALIDATION_LEGACY_RAW_JOIN_UNKNOWN_BYPASS_MUTANT", "join universe predicate", "join unknown negative")
  , ("VALIDATION_LEGACY_RAW_JOIN_ORDER_BYPASS_MUTANT", "join order predicate", "join order negative")
  , ("VALIDATION_LEGACY_RAW_JOIN_TARGET_MATCH_BYPASS_MUTANT", "join target equality predicate", "join target negative")
  , ("VALIDATION_LEGACY_DIGEST_DOMAIN_MUTANT", "input digest domain", "canonical legacy wire")
  , ("VALIDATION_LEGACY_DIGEST_PHASE_DROP_MUTANT", "input digest phase contribution", "canonical legacy wire")
  , ("VALIDATION_LEGACY_DIGEST_BINDING_COUNT_DROP_MUTANT", "input digest binding-count contribution", "canonical legacy wire")
  , ("VALIDATION_LEGACY_DIGEST_BINDING_ORDER_MUTANT", "input digest binding order", "canonical legacy wire")
  , ("VALIDATION_LEGACY_DIGEST_BINDING_ID_DROP_MUTANT", "input digest binding ID contribution", "canonical legacy wire")
  , ("VALIDATION_LEGACY_DIGEST_BINDING_DISPOSITION_DROP_MUTANT", "input digest binding disposition contribution", "canonical legacy wire")
  , ("VALIDATION_LEGACY_DIGEST_BINDING_OWNER_DROP_MUTANT", "input digest binding owner contribution", "canonical legacy wire")
  , ("VALIDATION_LEGACY_DIGEST_BINDING_ANALYZER_DROP_MUTANT", "input digest binding analyzer contribution", "canonical legacy wire")
  , ("VALIDATION_LEGACY_DIGEST_BINDING_OBSERVATION_DROP_MUTANT", "input digest binding observation contribution", "canonical legacy wire")
  , ("VALIDATION_LEGACY_DIGEST_BINDING_CLOSURE_DROP_MUTANT", "input digest binding closure contribution", "canonical legacy wire")
  , ("VALIDATION_LEGACY_DIGEST_BINDING_REINTRODUCTION_DROP_MUTANT", "input digest binding reintroduction contribution", "canonical legacy wire")
  , ("VALIDATION_LEGACY_DIGEST_JOIN_COUNT_DROP_MUTANT", "input digest join-count contribution", "canonical legacy wire")
  , ("VALIDATION_LEGACY_DIGEST_JOIN_ORDER_MUTANT", "input digest join order", "canonical legacy wire")
  , ("VALIDATION_LEGACY_DIGEST_JOIN_SOURCE_DROP_MUTANT", "input digest join source contribution", "canonical legacy wire")
  , ("VALIDATION_LEGACY_DIGEST_JOIN_TARGET_DROP_MUTANT", "input digest join target contribution", "canonical legacy wire")
  , ("VALIDATION_LEGACY_RESULT_NAME_MUTANT", "result name mapping", "canonical legacy wire")
  , ("VALIDATION_LEGACY_OBSERVATION_ORDER_MUTANT", "observation carrier order", "canonical legacy wire")
  , ("VALIDATION_LEGACY_FINDING_ORDER_MUTANT", "finding carrier order", "canonical legacy wire")
  , ("VALIDATION_LEGACY_OBSERVATION_COMMITMENT_KIND_DROP_MUTANT", "input commitment-kind observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_OBSERVATION_COMMITMENT_DIGEST_DROP_MUTANT", "input commitment-digest observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_OBSERVATION_PHASE_DROP_MUTANT", "input phase observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_OBSERVATION_BINDING_COUNT_DROP_MUTANT", "input binding-count observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_OBSERVATION_JOIN_COUNT_DROP_MUTANT", "input join-count observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_OBSERVATION_SELECTED_BINDING_COUNT_DROP_MUTANT", "selected binding-count observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_OBSERVATION_SELECTED_JOIN_COUNT_DROP_MUTANT", "selected join-count observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_OBSERVATION_STATUS_DROP_MUTANT", "diagnostic status observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_SRC000_DROP_MUTANT", "LTD-SRC-000 observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_LTD_SRC000_DROP_MUTANT", "LTD-SRC-000 execution-refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_SRC001_DROP_MUTANT", "LTD-SRC-001 observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_LTD_SRC001_DROP_MUTANT", "LTD-SRC-001 execution-refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_SRC002_DROP_MUTANT", "LTD-SRC-002 observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_LTD_SRC002_DROP_MUTANT", "LTD-SRC-002 execution-refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_SRC003_DROP_MUTANT", "LTD-SRC-003 observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_LTD_SRC003_DROP_MUTANT", "LTD-SRC-003 execution-refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_SRC004_DROP_MUTANT", "LTD-SRC-004 observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_LTD_SRC004_DROP_MUTANT", "LTD-SRC-004 execution-refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_SRC005_DROP_MUTANT", "LTD-SRC-005 observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_LTD_SRC005_DROP_MUTANT", "LTD-SRC-005 execution-refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_SRC006_DROP_MUTANT", "LTD-SRC-006 observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_LTD_SRC006_DROP_MUTANT", "LTD-SRC-006 execution-refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_SRC007_DROP_MUTANT", "LTD-SRC-007 observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_LTD_SRC007_DROP_MUTANT", "LTD-SRC-007 execution-refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_SRC008_DROP_MUTANT", "LTD-SRC-008 observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_LTD_SRC008_DROP_MUTANT", "LTD-SRC-008 execution-refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_SRC009_DROP_MUTANT", "LTD-SRC-009 observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_LTD_SRC009_DROP_MUTANT", "LTD-SRC-009 execution-refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_META001_DROP_MUTANT", "LTD-META-001 observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_LTD_META001_DROP_MUTANT", "LTD-META-001 execution-refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_VAL001_DROP_MUTANT", "LTD-VAL-001 observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_LTD_VAL001_DROP_MUTANT", "LTD-VAL-001 execution-refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_VAL002_DROP_MUTANT", "LTD-VAL-002 observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_LTD_VAL002_DROP_MUTANT", "LTD-VAL-002 execution-refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_VAL003_DROP_MUTANT", "LTD-VAL-003 observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_LTD_VAL003_DROP_MUTANT", "LTD-VAL-003 execution-refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_VAL004_DROP_MUTANT", "LTD-VAL-004 observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_LTD_VAL004_DROP_MUTANT", "LTD-VAL-004 execution-refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_VAL005_DROP_MUTANT", "LTD-VAL-005 observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_LTD_VAL005_DROP_MUTANT", "LTD-VAL-005 execution-refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_VAL006_DROP_MUTANT", "LTD-VAL-006 observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_LTD_VAL006_DROP_MUTANT", "LTD-VAL-006 execution-refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_DOC001_DROP_MUTANT", "LTD-DOC-001 observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_LTD_DOC001_DROP_MUTANT", "LTD-DOC-001 execution-refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_NAME001_DROP_MUTANT", "LTD-NAME-001 observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_LTD_NAME001_DROP_MUTANT", "LTD-NAME-001 execution-refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_HOST001_DROP_MUTANT", "LTD-HOST-001 observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_LTD_HOST001_DROP_MUTANT", "LTD-HOST-001 execution-refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_HOST002_DROP_MUTANT", "LTD-HOST-002 observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_LTD_HOST002_DROP_MUTANT", "LTD-HOST-002 execution-refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_IMG001_DROP_MUTANT", "LTD-IMG-001 observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_LTD_IMG001_DROP_MUTANT", "LTD-IMG-001 execution-refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_RUN001_DROP_MUTANT", "LTD-RUN-001 observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_LTD_RUN001_DROP_MUTANT", "LTD-RUN-001 execution-refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_SEED001_DROP_MUTANT", "LTD-SEED-001 observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_LTD_SEED001_DROP_MUTANT", "LTD-SEED-001 execution-refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_OBSERVATION_LTD_SEED002_DROP_MUTANT", "LTD-SEED-002 observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_LTD_SEED002_DROP_MUTANT", "LTD-SEED-002 execution-refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_OBSERVATION_SOURCE_TOOLS_DROP_MUTANT", "source-tools observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_EXECUTION_SOURCE_TOOLS_DROP_MUTANT", "source-tools execution-refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_OBSERVATION_SOURCE_DHALL_DROP_MUTANT", "source-dhall observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_EXECUTION_SOURCE_DHALL_DROP_MUTANT", "source-dhall execution-refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_OBSERVATION_SOURCE_PROTO_DROP_MUTANT", "source-proto observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_EXECUTION_SOURCE_PROTO_DROP_MUTANT", "source-proto execution-refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_OBSERVATION_SOURCE_UI_DROP_MUTANT", "source-ui observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_EXECUTION_SOURCE_UI_DROP_MUTANT", "source-ui execution-refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_OBSERVATION_SOURCE_PULUMI_DROP_MUTANT", "source-pulumi observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_EXECUTION_SOURCE_PULUMI_DROP_MUTANT", "source-pulumi execution-refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_OBSERVATION_SOURCE_TEST_DROP_MUTANT", "source-test observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_EXECUTION_SOURCE_TEST_DROP_MUTANT", "source-test execution-refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_OBSERVATION_SOURCE_PROBE_DROP_MUTANT", "source-probe observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_EXECUTION_SOURCE_PROBE_DROP_MUTANT", "source-probe execution-refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_OBSERVATION_SOURCE_PB_DROP_MUTANT", "source-pb observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_EXECUTION_SOURCE_PB_DROP_MUTANT", "source-pb execution-refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_OBSERVATION_SOURCE_VENDOR_DROP_MUTANT", "source-vendor observation retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_EXECUTION_SOURCE_VENDOR_DROP_MUTANT", "source-vendor execution-refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_PROBLEM_PHASE_BYTE_CODE_MUTANT", "phase byte problem code mapping", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_PHASE_BYTE_SUBJECT_MUTANT", "phase byte problem subject mapping", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_PHASE_BYTE_DETAIL_MUTANT", "phase byte problem detail mapping", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_BINDING_LIMIT_CODE_MUTANT", "binding limit problem code mapping", "binding count maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_BINDING_LIMIT_SUBJECT_MUTANT", "binding limit problem subject mapping", "binding count maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_BINDING_LIMIT_DETAIL_MUTANT", "binding limit problem detail mapping", "binding count maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_JOIN_LIMIT_CODE_MUTANT", "join limit problem code mapping", "join count maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_JOIN_LIMIT_SUBJECT_MUTANT", "join limit problem subject mapping", "join count maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_JOIN_LIMIT_DETAIL_MUTANT", "join limit problem detail mapping", "join count maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_ID_BYTE_CODE_MUTANT", "stable ID byte problem code mapping", "stable ID bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_ID_BYTE_SUBJECT_MUTANT", "stable ID byte problem subject mapping", "stable ID bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_ID_BYTE_DETAIL_MUTANT", "stable ID byte problem detail mapping", "stable ID bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_DISPOSITION_BYTE_CODE_MUTANT", "disposition byte problem code mapping", "disposition bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_DISPOSITION_BYTE_SUBJECT_MUTANT", "disposition byte problem subject mapping", "disposition bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_DISPOSITION_BYTE_DETAIL_MUTANT", "disposition byte problem detail mapping", "disposition bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_OWNER_BYTE_CODE_MUTANT", "owner byte problem code mapping", "owner bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_OWNER_BYTE_SUBJECT_MUTANT", "owner byte problem subject mapping", "owner bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_OWNER_BYTE_DETAIL_MUTANT", "owner byte problem detail mapping", "owner bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_ANALYZER_BYTE_CODE_MUTANT", "analyzer byte problem code mapping", "analyzer bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_ANALYZER_BYTE_SUBJECT_MUTANT", "analyzer byte problem subject mapping", "analyzer bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_ANALYZER_BYTE_DETAIL_MUTANT", "analyzer byte problem detail mapping", "analyzer bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_OBSERVATION_BYTE_CODE_MUTANT", "observation byte problem code mapping", "observation bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_OBSERVATION_BYTE_SUBJECT_MUTANT", "observation byte problem subject mapping", "observation bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_OBSERVATION_BYTE_DETAIL_MUTANT", "observation byte problem detail mapping", "observation bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_CLOSURE_BYTE_CODE_MUTANT", "closure byte problem code mapping", "closure bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_CLOSURE_BYTE_SUBJECT_MUTANT", "closure byte problem subject mapping", "closure bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_CLOSURE_BYTE_DETAIL_MUTANT", "closure byte problem detail mapping", "closure bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_REINTRODUCTION_COUNT_CODE_MUTANT", "reintroduction count problem code mapping", "reintroduction count maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_REINTRODUCTION_COUNT_SUBJECT_MUTANT", "reintroduction count problem subject mapping", "reintroduction count maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_REINTRODUCTION_COUNT_DETAIL_MUTANT", "reintroduction count problem detail mapping", "reintroduction count maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_REINTRODUCTION_BYTE_CODE_MUTANT", "reintroduction byte problem code mapping", "reintroduction bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_REINTRODUCTION_BYTE_SUBJECT_MUTANT", "reintroduction byte problem subject mapping", "reintroduction bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_REINTRODUCTION_BYTE_DETAIL_MUTANT", "reintroduction byte problem detail mapping", "reintroduction bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_JOIN_SOURCE_BYTE_CODE_MUTANT", "join source byte problem code mapping", "join source bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_JOIN_SOURCE_BYTE_SUBJECT_MUTANT", "join source byte problem subject mapping", "join source bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_JOIN_SOURCE_BYTE_DETAIL_MUTANT", "join source byte problem detail mapping", "join source bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_JOIN_TARGET_BYTE_CODE_MUTANT", "join target byte problem code mapping", "join target bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_JOIN_TARGET_BYTE_SUBJECT_MUTANT", "join target byte problem subject mapping", "join target bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_JOIN_TARGET_BYTE_DETAIL_MUTANT", "join target byte problem detail mapping", "join target bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_AGGREGATE_BYTE_CODE_MUTANT", "aggregate byte problem code mapping", "aggregate bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_AGGREGATE_BYTE_SUBJECT_MUTANT", "aggregate byte problem subject mapping", "aggregate bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_AGGREGATE_BYTE_DETAIL_MUTANT", "aggregate byte problem detail mapping", "aggregate bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_PHASE_WIDTH_CODE_MUTANT", "phase width problem code mapping", "phase width negative")
  , ("VALIDATION_LEGACY_PROBLEM_PHASE_WIDTH_SUBJECT_MUTANT", "phase width problem subject mapping", "phase width negative")
  , ("VALIDATION_LEGACY_PROBLEM_PHASE_WIDTH_DETAIL_MUTANT", "phase width problem detail mapping", "phase width negative")
  , ("VALIDATION_LEGACY_PROBLEM_PHASE_ALPHABET_CODE_MUTANT", "phase alphabet problem code mapping", "phase alphabet negative")
  , ("VALIDATION_LEGACY_PROBLEM_PHASE_ALPHABET_SUBJECT_MUTANT", "phase alphabet problem subject mapping", "phase alphabet negative")
  , ("VALIDATION_LEGACY_PROBLEM_PHASE_ALPHABET_DETAIL_MUTANT", "phase alphabet problem detail mapping", "phase alphabet negative")
  , ("VALIDATION_LEGACY_PROBLEM_PHASE_RANGE_CODE_MUTANT", "phase range problem code mapping", "phase range maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_PHASE_RANGE_SUBJECT_MUTANT", "phase range problem subject mapping", "phase range maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_PHASE_RANGE_DETAIL_MUTANT", "phase range problem detail mapping", "phase range maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_BINDING_CARDINALITY_CODE_MUTANT", "binding cardinality problem code mapping", "binding cardinality negative")
  , ("VALIDATION_LEGACY_PROBLEM_BINDING_CARDINALITY_SUBJECT_MUTANT", "binding cardinality problem subject mapping", "binding cardinality negative")
  , ("VALIDATION_LEGACY_PROBLEM_BINDING_CARDINALITY_DETAIL_MUTANT", "binding cardinality problem detail mapping", "binding cardinality negative")
  , ("VALIDATION_LEGACY_PROBLEM_BINDING_DUPLICATE_CODE_MUTANT", "binding duplicate problem code mapping", "binding duplicate negative")
  , ("VALIDATION_LEGACY_PROBLEM_BINDING_DUPLICATE_SUBJECT_MUTANT", "binding duplicate problem subject mapping", "binding duplicate negative")
  , ("VALIDATION_LEGACY_PROBLEM_BINDING_DUPLICATE_DETAIL_MUTANT", "binding duplicate problem detail mapping", "binding duplicate negative")
  , ("VALIDATION_LEGACY_PROBLEM_BINDING_UNKNOWN_CODE_MUTANT", "binding unknown problem code mapping", "binding unknown negative")
  , ("VALIDATION_LEGACY_PROBLEM_BINDING_UNKNOWN_SUBJECT_MUTANT", "binding unknown problem subject mapping", "binding unknown negative")
  , ("VALIDATION_LEGACY_PROBLEM_BINDING_UNKNOWN_DETAIL_MUTANT", "binding unknown problem detail mapping", "binding unknown negative")
  , ("VALIDATION_LEGACY_PROBLEM_BINDING_ORDER_CODE_MUTANT", "binding order problem code mapping", "binding order negative")
  , ("VALIDATION_LEGACY_PROBLEM_BINDING_ORDER_SUBJECT_MUTANT", "binding order problem subject mapping", "binding order negative")
  , ("VALIDATION_LEGACY_PROBLEM_BINDING_ORDER_DETAIL_MUTANT", "binding order problem detail mapping", "binding order negative")
  , ("VALIDATION_LEGACY_PROBLEM_BINDING_FIELD_CODE_MUTANT", "binding field problem code mapping", "binding disposition negative")
  , ("VALIDATION_LEGACY_PROBLEM_BINDING_FIELD_SUBJECT_MUTANT", "binding field problem subject mapping", "binding disposition negative")
  , ("VALIDATION_LEGACY_PROBLEM_BINDING_FIELD_DETAIL_MUTANT", "binding field problem detail mapping", "binding disposition negative")
  , ("VALIDATION_LEGACY_PROBLEM_JOIN_CARDINALITY_CODE_MUTANT", "join cardinality problem code mapping", "join cardinality negative")
  , ("VALIDATION_LEGACY_PROBLEM_JOIN_CARDINALITY_SUBJECT_MUTANT", "join cardinality problem subject mapping", "join cardinality negative")
  , ("VALIDATION_LEGACY_PROBLEM_JOIN_CARDINALITY_DETAIL_MUTANT", "join cardinality problem detail mapping", "join cardinality negative")
  , ("VALIDATION_LEGACY_PROBLEM_JOIN_DUPLICATE_CODE_MUTANT", "join duplicate problem code mapping", "join duplicate negative")
  , ("VALIDATION_LEGACY_PROBLEM_JOIN_DUPLICATE_SUBJECT_MUTANT", "join duplicate problem subject mapping", "join duplicate negative")
  , ("VALIDATION_LEGACY_PROBLEM_JOIN_DUPLICATE_DETAIL_MUTANT", "join duplicate problem detail mapping", "join duplicate negative")
  , ("VALIDATION_LEGACY_PROBLEM_JOIN_UNKNOWN_CODE_MUTANT", "join unknown problem code mapping", "join unknown negative")
  , ("VALIDATION_LEGACY_PROBLEM_JOIN_UNKNOWN_SUBJECT_MUTANT", "join unknown problem subject mapping", "join unknown negative")
  , ("VALIDATION_LEGACY_PROBLEM_JOIN_UNKNOWN_DETAIL_MUTANT", "join unknown problem detail mapping", "join unknown negative")
  , ("VALIDATION_LEGACY_PROBLEM_JOIN_ORDER_CODE_MUTANT", "join order problem code mapping", "join order negative")
  , ("VALIDATION_LEGACY_PROBLEM_JOIN_ORDER_SUBJECT_MUTANT", "join order problem subject mapping", "join order negative")
  , ("VALIDATION_LEGACY_PROBLEM_JOIN_ORDER_DETAIL_MUTANT", "join order problem detail mapping", "join order negative")
  , ("VALIDATION_LEGACY_PROBLEM_JOIN_TARGET_CODE_MUTANT", "join target problem code mapping", "join target negative")
  , ("VALIDATION_LEGACY_PROBLEM_JOIN_TARGET_SUBJECT_MUTANT", "join target problem subject mapping", "join target negative")
  , ("VALIDATION_LEGACY_PROBLEM_JOIN_TARGET_DETAIL_MUTANT", "join target problem detail mapping", "join target negative")
  , ("VALIDATION_LEGACY_AGGREGATE_BINDING_ANALYZER_DROP_MUTANT", "Legacy Aggregate binding analyzer drop locus", "aggregate bytes maximum plus one")
  , ("VALIDATION_LEGACY_AGGREGATE_BINDING_CLOSURE_DROP_MUTANT", "Legacy Aggregate binding closure drop locus", "aggregate bytes maximum plus one")
  , ("VALIDATION_LEGACY_AGGREGATE_BINDING_DISPOSITION_DROP_MUTANT", "Legacy Aggregate binding disposition drop locus", "aggregate bytes maximum plus one")
  , ("VALIDATION_LEGACY_AGGREGATE_BINDING_ID_DROP_MUTANT", "Legacy Aggregate binding ID drop locus", "aggregate bytes maximum plus one")
  , ("VALIDATION_LEGACY_AGGREGATE_BINDING_OBSERVATION_DROP_MUTANT", "Legacy Aggregate binding observation drop locus", "aggregate bytes maximum plus one")
  , ("VALIDATION_LEGACY_AGGREGATE_BINDING_OWNER_DROP_MUTANT", "Legacy Aggregate binding owner drop locus", "aggregate bytes maximum plus one")
  , ("VALIDATION_LEGACY_AGGREGATE_BINDING_REINTRODUCTION_DROP_MUTANT", "Legacy Aggregate binding reintroduction drop locus", "aggregate bytes maximum plus one")
  , ("VALIDATION_LEGACY_AGGREGATE_JOIN_SOURCE_DROP_MUTANT", "Legacy Aggregate join source drop locus", "aggregate bytes maximum plus one")
  , ("VALIDATION_LEGACY_AGGREGATE_JOIN_TARGET_DROP_MUTANT", "Legacy Aggregate join target drop locus", "aggregate bytes maximum plus one")
  , ("VALIDATION_LEGACY_ANALYSIS_COMPLETE_BINDING_COUNT_MUTANT", "Legacy Analysis complete binding count locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_ANALYSIS_COMPLETE_DIGEST_MUTANT", "Legacy Analysis complete digest locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_ANALYSIS_COMPLETE_JOIN_COUNT_MUTANT", "Legacy Analysis complete join count locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_ANALYSIS_COMPLETE_KIND_MUTANT", "Legacy Analysis complete kind locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_ANALYSIS_COMPLETE_PHASE_MUTANT", "Legacy Analysis complete phase locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_ANALYSIS_COMPLETE_PROBLEM_DROP_MUTANT", "Legacy Analysis complete problem drop locus", "phase width negative")
  , ("VALIDATION_LEGACY_ANALYSIS_RESOURCE_BINDING_COUNT_MUTANT", "Legacy Analysis resource binding count locus", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_ANALYSIS_RESOURCE_DIGEST_MUTANT", "Legacy Analysis resource digest locus", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_ANALYSIS_RESOURCE_JOIN_COUNT_MUTANT", "Legacy Analysis resource join count locus", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_ANALYSIS_RESOURCE_KIND_MUTANT", "Legacy Analysis resource kind locus", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_ANALYSIS_RESOURCE_PHASE_MUTANT", "Legacy Analysis resource phase locus", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_ANALYSIS_RESOURCE_PROBLEM_DROP_MUTANT", "Legacy Analysis resource problem drop locus", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_ANALYZER_LABEL_MUTANT", "Legacy Binding execution analyzer label locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_ANALYZER_MUTANT", "Legacy Binding execution analyzer locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_CLOSURE_LABEL_MUTANT", "Legacy Binding execution closure label locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_CLOSURE_MUTANT", "Legacy Binding execution closure locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_CODE_MUTANT", "Legacy Binding execution code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_OBSERVATION_LABEL_MUTANT", "Legacy Binding execution observation label locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_OBSERVATION_MUTANT", "Legacy Binding execution observation locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_OWNER_MUTANT", "Legacy Binding execution owner locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_PREFIX_MUTANT", "Legacy Binding execution prefix locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_SUBJECT_MUTANT", "Legacy Binding execution subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_OBSERVATION_KEY_MUTANT", "Legacy Binding observation key locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_OBSERVATION_VALUE_MUTANT", "Legacy Binding observation value locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_RENDER_ANALYZER_MUTANT", "Legacy Binding render analyzer locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_RENDER_CLOSURE_MUTANT", "Legacy Binding render closure locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_RENDER_DISPOSITION_MUTANT", "Legacy Binding render disposition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_RENDER_FIELD_SEPARATOR_MUTANT", "Legacy Binding render field separator locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_RENDER_ID_MUTANT", "Legacy Binding render ID locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_RENDER_OBSERVATION_MUTANT", "Legacy Binding render observation locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_RENDER_OWNER_MUTANT", "Legacy Binding render owner locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_RENDER_REINTRODUCTION_MUTANT", "Legacy Binding render reintroduction locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_SUBJECT_PREFIX_MUTANT", "Legacy Binding subject prefix locus", "stable ID bytes maximum plus one")
  , ("VALIDATION_LEGACY_BOUNDED_DIGEST_BINDING_ANALYZER_DROP_MUTANT", "Legacy Bounded digest binding analyzer drop locus", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_BOUNDED_DIGEST_BINDING_CLOSURE_DROP_MUTANT", "Legacy Bounded digest binding closure drop locus", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_BOUNDED_DIGEST_BINDING_DISPOSITION_DROP_MUTANT", "Legacy Bounded digest binding disposition drop locus", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_BOUNDED_DIGEST_BINDING_ID_DROP_MUTANT", "Legacy Bounded digest binding ID drop locus", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_BOUNDED_DIGEST_BINDING_OBSERVATION_DROP_MUTANT", "Legacy Bounded digest binding observation drop locus", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_BOUNDED_DIGEST_BINDING_ORDER_MUTANT", "Legacy Bounded digest binding order locus", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_BOUNDED_DIGEST_BINDING_OWNER_DROP_MUTANT", "Legacy Bounded digest binding owner drop locus", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_BOUNDED_DIGEST_BINDING_STATE_DROP_MUTANT", "Legacy Bounded digest binding state drop locus", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_BOUNDED_DIGEST_DOMAIN_MUTANT", "Legacy Bounded digest domain locus", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_BOUNDED_DIGEST_JOIN_ORDER_MUTANT", "Legacy Bounded digest join order locus", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_BOUNDED_DIGEST_JOIN_SOURCE_DROP_MUTANT", "Legacy Bounded digest join source drop locus", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_BOUNDED_DIGEST_JOIN_STATE_DROP_MUTANT", "Legacy Bounded digest join state drop locus", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_BOUNDED_DIGEST_JOIN_TARGET_DROP_MUTANT", "Legacy Bounded digest join target drop locus", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_BOUNDED_DIGEST_PHASE_DROP_MUTANT", "Legacy Bounded digest phase drop locus", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_BOUNDED_DIGEST_PROBLEM_TAG_DROP_MUTANT", "Legacy Bounded digest problem tag drop locus", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_BOUNDED_COMMITMENT_DIGEST_LABEL_MUTANT", "Legacy bounded-refusal prefix commitment detail label", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_BOUNDED_DIGEST_REINTRODUCTION_STATE_DROP_MUTANT", "Legacy Bounded digest reintroduction state drop locus", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_BOUNDED_DIGEST_REINTRODUCTION_VALUE_DROP_MUTANT", "Legacy Bounded digest reintroduction value drop locus", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_BOUNDED_STATE_EXCEEDED_MUTANT", "Legacy Bounded state exceeded locus", "binding count maximum plus one")
  , ("VALIDATION_LEGACY_BOUNDED_STATE_WITHIN_MUTANT", "Legacy Bounded state within locus", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_BOUNDED_TEXT_EXCEEDED_LABEL_MUTANT", "Legacy Bounded text exceeded label locus", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_BOUNDED_TEXT_OBSERVED_MUTANT", "Legacy Bounded text observed locus", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_BOUNDED_TEXT_RETAINED_DROP_MUTANT", "Legacy Bounded text retained drop locus", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_BOUNDED_TEXT_SEPARATOR_MUTANT", "Legacy Bounded text separator locus", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_BOUNDED_TEXT_WITHIN_LABEL_MUTANT", "Legacy Bounded text within label locus", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_BOUND_AGGREGATE_BYTES_MUTANT", "Legacy Bound aggregate bytes locus", "aggregate bytes maximum plus one")
  , ("VALIDATION_LEGACY_BOUND_ANALYZER_BYTES_MUTANT", "Legacy Bound analyzer bytes locus", "analyzer bytes maximum")
  , ("VALIDATION_LEGACY_BOUND_BINDINGS_MUTANT", "Legacy Bound bindings locus", "binding count maximum")
  , ("VALIDATION_LEGACY_BOUND_CLOSURE_BYTES_MUTANT", "Legacy Bound closure bytes locus", "closure bytes maximum")
  , ("VALIDATION_LEGACY_BOUND_DISPOSITION_BYTES_MUTANT", "Legacy Bound disposition bytes locus", "disposition bytes maximum")
  , ("VALIDATION_LEGACY_BOUND_ID_BYTES_MUTANT", "Legacy Bound ID bytes locus", "stable ID bytes maximum")
  , ("VALIDATION_LEGACY_BOUND_JOINS_MUTANT", "Legacy Bound joins locus", "join count maximum")
  , ("VALIDATION_LEGACY_BOUND_JOIN_SOURCE_BYTES_MUTANT", "Legacy Bound join source bytes locus", "join source bytes maximum")
  , ("VALIDATION_LEGACY_BOUND_JOIN_TARGET_BYTES_MUTANT", "Legacy Bound join target bytes locus", "join target bytes maximum")
  , ("VALIDATION_LEGACY_BOUND_OBSERVATION_BYTES_MUTANT", "Legacy Bound observation bytes locus", "observation bytes maximum")
  , ("VALIDATION_LEGACY_BOUND_OWNER_BYTES_MUTANT", "Legacy Bound owner bytes locus", "owner bytes maximum")
  , ("VALIDATION_LEGACY_BOUND_PHASE_BYTES_MUTANT", "Legacy Bound phase bytes locus", "phase bytes maximum")
  , ("VALIDATION_LEGACY_BOUND_REINTRODUCTION_BYTES_MUTANT", "Legacy Bound reintroduction bytes locus", "reintroduction bytes maximum")
  , ("VALIDATION_LEGACY_BOUND_REINTRODUCTION_VALUES_MUTANT", "Legacy Bound reintroduction values locus", "reintroduction count maximum")
  , ("VALIDATION_LEGACY_COMMITMENT_DIGEST_LABEL_MUTANT", "Legacy Commitment digest label locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_COMMITMENT_DIGEST_VALUE_MUTANT", "Legacy Commitment digest value locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_COMMITMENT_KIND_LABEL_MUTANT", "Legacy Commitment kind label locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_COMMITMENT_KIND_VALUE_MUTANT", "Legacy Commitment kind value locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_GRAMMAR_BINDING_DUPLICATE_SEARCH_ORDER_MUTANT", "Legacy Grammar binding duplicate search order locus", "binding duplicate search precedence")
  , ("VALIDATION_LEGACY_GRAMMAR_BINDING_FIELD_ORDER_MUTANT", "Legacy Grammar binding field order locus", "binding field precedence")
  , ("VALIDATION_LEGACY_GRAMMAR_BINDING_PROBLEM_ORDER_MUTANT", "Legacy Grammar binding problem order locus", "binding duplicate negative")
  , ("VALIDATION_LEGACY_GRAMMAR_BINDING_ROW_ORDER_MUTANT", "Legacy Grammar binding row order locus", "binding row precedence")
  , ("VALIDATION_LEGACY_GRAMMAR_BINDING_UNKNOWN_SEARCH_ORDER_MUTANT", "Legacy Grammar binding unknown search order locus", "binding unknown search precedence")
  , ("VALIDATION_LEGACY_GRAMMAR_CLASS_ORDER_MUTANT", "Legacy Grammar class order locus", "grammar class precedence")
  , ("VALIDATION_LEGACY_GRAMMAR_JOIN_DUPLICATE_SEARCH_ORDER_MUTANT", "Legacy Grammar join duplicate search order locus", "join duplicate search precedence")
  , ("VALIDATION_LEGACY_GRAMMAR_JOIN_PROBLEM_ORDER_MUTANT", "Legacy Grammar join problem order locus", "join duplicate negative")
  , ("VALIDATION_LEGACY_GRAMMAR_JOIN_ROW_ORDER_MUTANT", "Legacy Grammar join row order locus", "join row precedence")
  , ("VALIDATION_LEGACY_GRAMMAR_JOIN_UNKNOWN_SEARCH_ORDER_MUTANT", "Legacy Grammar join unknown search order locus", "join unknown search precedence")
  , ("VALIDATION_LEGACY_GRAMMAR_PHASE_ORDER_MUTANT", "Legacy Grammar phase order locus", "grammar phase precedence")
  , ("VALIDATION_LEGACY_INTERNAL_ACCEPTED_ENCODINGS_DROP_MUTANT", "Legacy Internal accepted encodings drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ACCEPTED_ENCODINGS_ORDER_MUTANT", "accepted legacy encoding order", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ACCEPTED_REGISTER_PATH_MUTANT", "Legacy Internal accepted register path locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ACTIVE_MISSING_CODE_MUTANT", "Legacy Internal active missing code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ACTIVE_MISSING_DETAIL_MUTANT", "Legacy Internal active missing detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ACTIVE_MISSING_SUBJECT_MUTANT", "Legacy Internal active missing subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ALIAS_PATH_BYPASS_MUTANT", "Legacy Internal alias path bypass locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ALIAS_CANONICAL_EXCLUSION_BYPASS_MUTANT", "Amoebius.Validation.Legacy.Internal.legacyAliasCanonicalExcluded canonical-path exclusion conjunct", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ALIAS_BASENAME_MATCH_BYPASS_MUTANT", "Amoebius.Validation.Legacy.Internal.legacyAliasBasenameMatches basename-match conjunct", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ALL_IDS_INTEGRITY_BYPASS_MUTANT", "Legacy Internal all IDS integrity bypass locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ALL_IDS_ROUTE_DROP_MUTANT", "Legacy Internal all IDS route drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ALL_IDS_ROUTE_ORDER_MUTANT", "all legacy identifiers route order", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ANALYZER_BINDING_MATCH_BYPASS_MUTANT", "Legacy Internal analyzer binding match bypass locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ANALYZER_BINDING_MISMATCH_CODE_MUTANT", "Legacy Internal analyzer binding mismatch code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ANALYZER_BINDING_MISMATCH_DETAIL_MUTANT", "Legacy Internal analyzer binding mismatch detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ANALYZER_BINDING_MISMATCH_SUBJECT_MUTANT", "Legacy Internal analyzer binding mismatch subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ANALYZER_IDENTITY_MATCH_BYPASS_MUTANT", "Legacy Internal analyzer identity match bypass locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ANALYZER_INVENTORY_CODE_MUTANT", "Legacy Internal analyzer inventory code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ANALYZER_INVENTORY_DETAIL_MUTANT", "Legacy Internal analyzer inventory detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ANALYZER_INVENTORY_SUBJECT_MUTANT", "Legacy Internal analyzer inventory subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ANALYZER_MISMATCH_CODE_MUTANT", "Legacy Internal analyzer mismatch code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ANALYZER_MISMATCH_DETAIL_MUTANT", "Legacy Internal analyzer mismatch detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ANALYZER_MISMATCH_SUBJECT_MUTANT", "Legacy Internal analyzer mismatch subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ANALYZER_MISSING_CODE_MUTANT", "Legacy Internal analyzer missing code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ANALYZER_MISSING_DETAIL_MUTANT", "Legacy Internal analyzer missing detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ANALYZER_MISSING_SUBJECT_MUTANT", "Legacy Internal analyzer missing subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ANALYZER_SLOT_MISSING_MUTANT", "Legacy Internal analyzer slot missing locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ANALYZER_UNAVAILABLE_CODE_MUTANT", "Legacy Internal analyzer unavailable code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ANALYZER_UNAVAILABLE_DETAIL_MUTANT", "Legacy Internal analyzer unavailable detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ANALYZER_UNAVAILABLE_SUBJECT_MUTANT", "Legacy Internal analyzer unavailable subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ARCHIVE_PATH_BYPASS_MUTANT", "Legacy Internal archive path bypass locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_BINDING_ANALYZER_ROUTE_MUTANT", "Legacy Internal binding analyzer route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_BINDING_CLOSURE_ROUTE_MUTANT", "Legacy Internal binding closure route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_BINDING_CONTRACTS_OBSERVATION_DROP_MUTANT", "Legacy Internal binding contracts observation drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_BINDING_CONTRACTS_OBSERVATION_KEY_MUTANT", "Legacy Internal binding contracts observation key locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_BINDING_CONTRACTS_OBSERVATION_VALUE_MUTANT", "Legacy Internal binding contracts observation value locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_BINDING_ID_CODE_MUTANT", "Legacy Internal binding ID code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_BINDING_ID_DETAIL_MUTANT", "Legacy Internal binding ID detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_BINDING_ID_INTEGRITY_BYPASS_MUTANT", "Legacy Internal binding ID integrity bypass locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_BINDING_ID_ROUTE_MUTANT", "Legacy Internal binding ID route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_BINDING_ID_SUBJECT_MUTANT", "Legacy Internal binding ID subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_BINDING_OBSERVATION_KEY_MUTANT", "Legacy Internal binding observation key locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_BINDING_OBSERVATION_ROUTE_MUTANT", "Legacy Internal binding observation route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_BINDING_OBSERVATION_VALUE_MUTANT", "Legacy Internal binding observation value locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_BINDING_OWNER_ROUTE_MUTANT", "Legacy Internal binding owner route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_BINDING_REINTRODUCTION_ROUTE_MUTANT", "Legacy Internal binding reintroduction route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_BINDING_RESULT_NAME_MUTANT", "Legacy Internal binding result name locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CALLER_SOURCE_STATE_MUTANT", "Legacy Internal caller source state locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CANDIDATE_PHASE_OBSERVATION_DROP_MUTANT", "Legacy Internal candidate phase observation drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CANDIDATE_PHASE_OBSERVATION_KEY_MUTANT", "Legacy Internal candidate phase observation key locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CANDIDATE_PHASE_OBSERVATION_VALUE_MUTANT", "Legacy Internal candidate phase observation value locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CANONICAL_ENTRY_FILTER_BYPASS_MUTANT", "Legacy Internal canonical entry filter bypass locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CANONICAL_ENTRY_DUPLICATE_COLLAPSE_MUTANT", "canonical register duplicate retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_ANALYZER_BYPASS_MUTANT", "Legacy Internal closed evidence analyzer bypass locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_ANALYZER_CODE_MUTANT", "Legacy Internal closed evidence analyzer code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_ANALYZER_DETAIL_MUTANT", "Legacy Internal closed evidence analyzer detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_ANALYZER_ROUTE_MUTANT", "Legacy Internal closed evidence analyzer route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_ANALYZER_SUBJECT_MUTANT", "Legacy Internal closed evidence analyzer subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_ID_BYPASS_MUTANT", "Legacy Internal closed evidence ID bypass locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_ID_CODE_MUTANT", "Legacy Internal closed evidence ID code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_ID_DETAIL_MUTANT", "Legacy Internal closed evidence ID detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_ID_ROUTE_MUTANT", "Legacy Internal closed evidence ID route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_ID_SUBJECT_MUTANT", "Legacy Internal closed evidence ID subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_OBSERVATION_BYPASS_MUTANT", "Legacy Internal closed evidence observation bypass locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_OBSERVATION_CODE_MUTANT", "Legacy Internal closed evidence observation code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_OBSERVATION_DETAIL_MUTANT", "Legacy Internal closed evidence observation detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_OBSERVATION_ROUTE_MUTANT", "Legacy Internal closed evidence observation route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_OBSERVATION_SUBJECT_MUTANT", "Legacy Internal closed evidence observation subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_SNAPSHOT_BYPASS_MUTANT", "Legacy Internal closed evidence snapshot bypass locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_SNAPSHOT_CODE_MUTANT", "Legacy Internal closed evidence snapshot code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_SNAPSHOT_DETAIL_MUTANT", "Legacy Internal closed evidence snapshot detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_SNAPSHOT_ROUTE_MUTANT", "Legacy Internal closed evidence snapshot route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_SNAPSHOT_SUBJECT_MUTANT", "Legacy Internal closed evidence snapshot subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_SOURCE_DEBT_BYPASS_MUTANT", "Legacy Internal closed evidence source debt bypass locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_SOURCE_DEBT_CODE_MUTANT", "Legacy Internal closed evidence source debt code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_SOURCE_DEBT_DETAIL_MUTANT", "Legacy Internal closed evidence source debt detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_SOURCE_DEBT_ROUTE_MUTANT", "Legacy Internal closed evidence source debt route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_SOURCE_DEBT_SUBJECT_MUTANT", "Legacy Internal closed evidence source debt subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_REGISTRY_CODE_MUTANT", "Legacy Internal closed registry code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_REGISTRY_DETAIL_MUTANT", "Legacy Internal closed registry detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_REGISTRY_KEYS_BYPASS_MUTANT", "Legacy Internal closed registry keys bypass locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_REGISTRY_SUBJECT_MUTANT", "Legacy Internal closed registry subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_UNIVERSE_INTEGRITY_BYPASS_MUTANT", "Legacy Internal closed universe integrity bypass locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_UNIVERSE_EQUALITY_BYPASS_MUTANT", "Amoebius.Validation.Legacy.Internal.closedUniverseEqualityInvalid equality predicate", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_UNIVERSE_DUPLICATE_BYPASS_MUTANT", "Amoebius.Validation.Legacy.Internal.closedUniverseDuplicateInvalid duplicate predicate", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSURE_BINDING_MATCH_BYPASS_MUTANT", "Legacy Internal closure binding match bypass locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSURE_INVENTORY_CODE_MUTANT", "Legacy Internal closure inventory code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSURE_INVENTORY_DETAIL_MUTANT", "Legacy Internal closure inventory detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSURE_INVENTORY_SUBJECT_MUTANT", "Legacy Internal closure inventory subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSURE_MISMATCH_CODE_MUTANT", "Legacy Internal closure mismatch code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSURE_MISMATCH_DETAIL_MUTANT", "Legacy Internal closure mismatch detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSURE_MISMATCH_SUBJECT_MUTANT", "Legacy Internal closure mismatch subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSURE_MISSING_CODE_MUTANT", "Legacy Internal closure missing code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSURE_MISSING_DETAIL_MUTANT", "Legacy Internal closure missing detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSURE_MISSING_SUBJECT_MUTANT", "Legacy Internal closure missing subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSURE_SLOT_MISSING_MUTANT", "Legacy Internal closure slot missing locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_COMPARE_OWNER_EQ_MUTANT", "Legacy Internal compare owner eq locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_COMPARE_OWNER_GT_MUTANT", "Legacy Internal compare owner gt locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_COMPARE_OWNER_LT_MUTANT", "Legacy Internal compare owner lt locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_COMPARE_OWNER_MISSING_MUTANT", "Legacy Internal compare owner missing locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_COMPILER_SNAPSHOT_CODE_MUTANT", "Legacy Internal compiler snapshot code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_COMPILER_SNAPSHOT_DETAIL_MUTANT", "Legacy Internal compiler snapshot detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_COMPILER_SNAPSHOT_MATCH_BYPASS_MUTANT", "Legacy Internal compiler snapshot match bypass locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_COMPILER_SNAPSHOT_SUBJECT_MUTANT", "Legacy Internal compiler snapshot subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_COMPLETE_CLOSURE_CONTRIBUTION_DROP_MUTANT", "Legacy Internal complete closure contribution drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_COMPLETE_CONSUMER_CONTRIBUTION_DROP_MUTANT", "Legacy Internal complete consumer contribution drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_COMPLETE_DEBT_CONTRIBUTION_DROP_MUTANT", "Legacy Internal complete debt contribution drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_COMPLETE_EVIDENCE_DROP_MUTANT", "Legacy Internal complete evidence drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_COMPLETE_FINDING_CODE_MUTANT", "Legacy Internal complete finding code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_COMPLETE_FINDING_DETAIL_MUTANT", "Amoebius.Validation.Legacy.Internal.legacyCompleteFindingDetail dependency-finding detail contribution", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_COMPLETE_FINDING_FRAME_LENGTH_MUTANT", "Amoebius.Validation.Legacy.Internal.legacyCompleteFindingFrameLength dependency-finding byte-length frame", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_COMPLETE_FINDING_FRAME_SEPARATOR_MUTANT", "Amoebius.Validation.Legacy.Internal.legacyCompleteFindingFrameSeparator dependency-finding frame separator", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_COMPLETE_FINDING_ORDER_MUTANT", "Legacy Internal complete finding order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_COMPLETE_FINDING_SUBJECT_MUTANT", "Amoebius.Validation.Legacy.Internal.legacyCompleteFindingSubject role-labelled dependency subject contribution", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_COMPLETE_REFUSAL_PREFIX_MUTANT", "Legacy Internal complete refusal prefix locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_COMPLETE_REFUSAL_SEPARATOR_MUTANT", "Legacy Internal complete refusal separator locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_COMPLETE_REFUSAL_STATE_MUTANT", "Legacy Internal complete refusal state locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_COMPLETE_ZERO_STATE_MUTANT", "Legacy Internal complete zero state locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CORE_FINDING_COMPOSITION_MUTANT", "Legacy Internal core finding composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CORE_OBSERVATION_COMPOSITION_MUTANT", "Legacy Internal core observation composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CORE_RESULT_NAME_ROUTE_MUTANT", "Legacy Internal core result name route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DECODER_ALIAS_MUTANT", "Legacy Internal decoder alias locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DECODER_KEY_DROP_MUTANT", "canonical decoder key retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DECODER_LTD_DOC001_TARGET_MUTANT", "Legacy Internal decoder LTD doc001 target locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DECODER_LTD_HOST001_TARGET_MUTANT", "Legacy Internal decoder LTD host001 target locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DECODER_LTD_HOST002_TARGET_MUTANT", "Legacy Internal decoder LTD host002 target locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DECODER_LTD_IMG001_TARGET_MUTANT", "Legacy Internal decoder LTD img001 target locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DECODER_LTD_META001_TARGET_MUTANT", "Legacy Internal decoder LTD meta001 target locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DECODER_LTD_NAME001_TARGET_MUTANT", "Legacy Internal decoder LTD name001 target locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DECODER_LTD_RUN001_TARGET_MUTANT", "Legacy Internal decoder LTD run001 target locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DECODER_LTD_SEED001_TARGET_MUTANT", "Legacy Internal decoder LTD seed001 target locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DECODER_LTD_SEED002_TARGET_MUTANT", "Legacy Internal decoder LTD seed002 target locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DECODER_LTD_SRC000_TARGET_MUTANT", "Legacy Internal decoder LTD src000 target locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DECODER_LTD_SRC001_TARGET_MUTANT", "Legacy Internal decoder LTD src001 target locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DECODER_LTD_SRC002_TARGET_MUTANT", "Legacy Internal decoder LTD src002 target locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DECODER_LTD_SRC003_TARGET_MUTANT", "Legacy Internal decoder LTD src003 target locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DECODER_LTD_SRC004_TARGET_MUTANT", "Legacy Internal decoder LTD src004 target locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DECODER_LTD_SRC005_TARGET_MUTANT", "Legacy Internal decoder LTD src005 target locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DECODER_LTD_SRC006_TARGET_MUTANT", "Legacy Internal decoder LTD src006 target locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DECODER_LTD_SRC007_TARGET_MUTANT", "Legacy Internal decoder LTD src007 target locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DECODER_LTD_SRC008_TARGET_MUTANT", "Legacy Internal decoder LTD src008 target locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DECODER_LTD_SRC009_TARGET_MUTANT", "Legacy Internal decoder LTD src009 target locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DECODER_LTD_VAL001_TARGET_MUTANT", "Legacy Internal decoder LTD val001 target locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DECODER_LTD_VAL002_TARGET_MUTANT", "Legacy Internal decoder LTD val002 target locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DECODER_LTD_VAL003_TARGET_MUTANT", "Legacy Internal decoder LTD val003 target locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DECODER_LTD_VAL004_TARGET_MUTANT", "Legacy Internal decoder LTD val004 target locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DECODER_LTD_VAL005_TARGET_MUTANT", "Legacy Internal decoder LTD val005 target locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DECODER_LTD_VAL006_TARGET_MUTANT", "Legacy Internal decoder LTD val006 target locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DIAGNOSTIC_REFUSAL_CODE_MUTANT", "Legacy Internal diagnostic refusal code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DIAGNOSTIC_REFUSAL_DETAIL_MUTANT", "Legacy Internal diagnostic refusal detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DIAGNOSTIC_REFUSAL_DROP_MUTANT", "Legacy Internal diagnostic refusal drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DIAGNOSTIC_REFUSAL_SUBJECT_MUTANT", "Legacy Internal diagnostic refusal subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DIGEST_ALPHA_RANGE_BYPASS_MUTANT", "Legacy Internal digest alpha range bypass locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DIGEST_CHARACTER_QUANTIFIER_MUTANT", "Amoebius.Validation.Legacy.Internal.legacyDigestCharactersValid all-character quantifier", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DIGEST_COMPONENT_COMPOSITION_MUTANT", "Amoebius.Validation.Legacy.Internal.isLowerHexDigest length-and-character-set composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DIGEST_DIGIT_RANGE_BYPASS_MUTANT", "Legacy Internal digest digit range bypass locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DIGIT_LOWER_BOUND_BYPASS_MUTANT", "Amoebius.Validation.Legacy.Internal.legacyLowerHexDigitLowerBound lower digit conjunct", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DIGIT_UPPER_BOUND_BYPASS_MUTANT", "Amoebius.Validation.Legacy.Internal.legacyLowerHexDigitUpperBound upper digit conjunct", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ALPHA_LOWER_BOUND_BYPASS_MUTANT", "Amoebius.Validation.Legacy.Internal.legacyLowerHexAlphaLowerBound lower alpha conjunct", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ALPHA_UPPER_BOUND_BYPASS_MUTANT", "Amoebius.Validation.Legacy.Internal.legacyLowerHexAlphaUpperBound upper alpha conjunct", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DIGEST_LENGTH_BYPASS_MUTANT", "Legacy Internal digest length bypass locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DUE_COMPARISON_MUTANT", "Legacy Internal due comparison locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DUE_MISSING_OWNER_BYPASS_MUTANT", "Legacy Internal due missing owner bypass locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_EVIDENCE_SNAPSHOT_OBSERVATION_DROP_MUTANT", "Legacy Internal evidence snapshot observation drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_EVIDENCE_SNAPSHOT_OBSERVATION_KEY_MUTANT", "Legacy Internal evidence snapshot observation key locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_EVIDENCE_SNAPSHOT_OBSERVATION_VALUE_MUTANT", "Legacy Internal evidence snapshot observation value locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_HEX_ALTERNATIVE_COMPOSITION_MUTANT", "Amoebius.Validation.Legacy.Internal.legacyLowerHexCharacter digit-or-alpha grammar composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ID_ENCODING_CODE_MUTANT", "Legacy Internal ID encoding code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ID_ENCODING_DETAIL_MUTANT", "Legacy Internal ID encoding detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ID_ENCODING_SUBJECT_MUTANT", "Legacy Internal ID encoding subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ID_INVENTORY_CODE_MUTANT", "Legacy Internal ID inventory code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ID_INVENTORY_DETAIL_MUTANT", "Legacy Internal ID inventory detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ID_INVENTORY_SUBJECT_MUTANT", "Legacy Internal ID inventory subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_INTEGRITY_GATE_BYPASS_MUTANT", "Legacy Internal integrity gate bypass locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_INVENTORY_EVALUATION_ORDER_MUTANT", "Legacy Internal inventory evaluation order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_INVENTORY_FINDING_COMPOSITION_DROP_MUTANT", "Legacy Internal inventory finding composition drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_INVENTORY_OBSERVATION_COMPOSITION_DROP_MUTANT", "Legacy Internal inventory observation composition drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_INVENTORY_RESULT_NAME_MUTANT", "Legacy Internal inventory result name locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_INVERSE_NON_SOURCE_MUTANT", "Legacy Internal inverse non source locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_INVERSE_SOURCE_DHALL_MUTANT", "Legacy Internal inverse source dhall locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_INVERSE_SOURCE_PB_MUTANT", "Legacy Internal inverse source pb locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_INVERSE_SOURCE_PROBE_MUTANT", "Legacy Internal inverse source probe locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_INVERSE_SOURCE_PROTO_MUTANT", "Legacy Internal inverse source proto locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_INVERSE_SOURCE_PULUMI_MUTANT", "Legacy Internal inverse source pulumi locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_INVERSE_SOURCE_TEST_MUTANT", "Legacy Internal inverse source test locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_INVERSE_SOURCE_TOOLS_MUTANT", "Legacy Internal inverse source tools locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_INVERSE_SOURCE_UI_MUTANT", "Legacy Internal inverse source ui locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_INVERSE_SOURCE_VENDOR_MUTANT", "Legacy Internal inverse source vendor locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_LOOKUP_OBSERVATION_ROUTE_MUTANT", "Legacy Internal lookup observation route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_MALFORMED_OBSERVATION_CODE_MUTANT", "Legacy Internal malformed observation code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_MALFORMED_OBSERVATION_DETAIL_MUTANT", "Legacy Internal malformed observation detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_MALFORMED_OBSERVATION_SUBJECT_MUTANT", "Legacy Internal malformed observation subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_NON_SOURCE_LTD_DOC001_DROP_MUTANT", "Legacy Internal non source LTD doc001 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_NON_SOURCE_LTD_HOST001_DROP_MUTANT", "Legacy Internal non source LTD host001 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_NON_SOURCE_LTD_HOST002_DROP_MUTANT", "Legacy Internal non source LTD host002 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_NON_SOURCE_LTD_IMG001_DROP_MUTANT", "Legacy Internal non source LTD img001 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_NON_SOURCE_LTD_META001_DROP_MUTANT", "Legacy Internal non source LTD meta001 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_NON_SOURCE_LTD_NAME001_DROP_MUTANT", "Legacy Internal non source LTD name001 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_NON_SOURCE_LTD_RUN001_DROP_MUTANT", "Legacy Internal non source LTD run001 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_NON_SOURCE_LTD_SEED001_DROP_MUTANT", "Legacy Internal non source LTD seed001 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_NON_SOURCE_LTD_SEED002_DROP_MUTANT", "Legacy Internal non source LTD seed002 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_NON_SOURCE_LTD_VAL001_DROP_MUTANT", "Legacy Internal non source LTD val001 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_NON_SOURCE_LTD_VAL002_DROP_MUTANT", "Legacy Internal non source LTD val002 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_NON_SOURCE_LTD_VAL003_DROP_MUTANT", "Legacy Internal non source LTD val003 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_NON_SOURCE_LTD_VAL004_DROP_MUTANT", "Legacy Internal non source LTD val004 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_NON_SOURCE_LTD_VAL005_DROP_MUTANT", "Legacy Internal non source LTD val005 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_NON_SOURCE_LTD_VAL006_DROP_MUTANT", "Legacy Internal non source LTD val006 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_NON_SOURCE_UNIVERSE_ORDER_MUTANT", "Legacy Internal non source universe order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OBSERVATION_BINDING_MATCH_BYPASS_MUTANT", "Legacy Internal observation binding match bypass locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OBSERVATION_INVENTORY_CODE_MUTANT", "Legacy Internal observation inventory code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OBSERVATION_INVENTORY_DETAIL_MUTANT", "Legacy Internal observation inventory detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OBSERVATION_INVENTORY_SUBJECT_MUTANT", "Legacy Internal observation inventory subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OBSERVATION_MISMATCH_CODE_MUTANT", "Legacy Internal observation mismatch code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OBSERVATION_MISMATCH_DETAIL_MUTANT", "Legacy Internal observation mismatch detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OBSERVATION_MISMATCH_SUBJECT_MUTANT", "Legacy Internal observation mismatch subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OBSERVATION_MISSING_CODE_MUTANT", "Legacy Internal observation missing code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OBSERVATION_MISSING_DETAIL_MUTANT", "Legacy Internal observation missing detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OBSERVATION_MISSING_SUBJECT_MUTANT", "Legacy Internal observation missing subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OBSERVATION_REFUSED_CODE_MUTANT", "Legacy Internal observation refused code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OBSERVATION_REFUSED_DETAIL_MUTANT", "Legacy Internal observation refused detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OBSERVATION_REFUSED_SUBJECT_MUTANT", "Legacy Internal observation refused subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OBSERVATION_SLOT_MISSING_MUTANT", "Legacy Internal observation slot missing locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OPEN_COUNT_PREDICATE_BYPASS_MUTANT", "Legacy Internal open count predicate bypass locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OPEN_OBSERVATION_COMPOSITION_MUTANT", "Amoebius.Validation.Legacy.Internal.legacyOpenObservationMalformed count-or-digest refusal composition", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OWNER_BINDINGS_OBSERVATION_DROP_MUTANT", "Legacy Internal owner bindings observation drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OWNER_BINDINGS_OBSERVATION_KEY_MUTANT", "Legacy Internal owner bindings observation key locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OWNER_BINDINGS_OBSERVATION_VALUE_MUTANT", "Legacy Internal owner bindings observation value locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OWNER_BINDING_MATCH_BYPASS_MUTANT", "Legacy Internal owner binding match bypass locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OWNER_DUE_CODE_MUTANT", "Legacy Internal owner due code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OWNER_DUE_DETAIL_MUTANT", "Legacy Internal owner due detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OWNER_DUE_SUBJECT_MUTANT", "Legacy Internal owner due subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OWNER_MISMATCH_CODE_MUTANT", "Legacy Internal owner mismatch code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OWNER_MISMATCH_DETAIL_MUTANT", "Legacy Internal owner mismatch detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OWNER_MISMATCH_SUBJECT_MUTANT", "Legacy Internal owner mismatch subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OWNER_MISSING_CODE_MUTANT", "Legacy Internal owner missing code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OWNER_MISSING_DETAIL_MUTANT", "Legacy Internal owner missing detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OWNER_MISSING_SUBJECT_MUTANT", "Legacy Internal owner missing subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OWNER_SLOT_MISSING_MUTANT", "Legacy Internal owner slot missing locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PARSER_GRAMMAR_BYPASS_MUTANT", "Legacy Internal parser grammar bypass locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PARSER_MAP_COMPARISON_BYPASS_MUTANT", "Amoebius.Validation.Legacy.Internal.legacyParserMapInvalid exact-map predicate", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PARSER_CARDINALITY_BYPASS_MUTANT", "Amoebius.Validation.Legacy.Internal.legacyParserCardinalityInvalid closed-cardinality predicate", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PARSER_GRAMMAR_CODE_MUTANT", "Legacy Internal parser grammar code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PARSER_GRAMMAR_DETAIL_MUTANT", "Legacy Internal parser grammar detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PARSER_GRAMMAR_SUBJECT_MUTANT", "Legacy Internal parser grammar subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PARSE_UNKNOWN_ACCEPT_MUTANT", "Legacy Internal parse unknown accept locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PARSE_CANONICAL_REJECT_MUTANT", "canonical identifier parser acceptance", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PATH_UTF8_ASCII_WIDTH_MUTANT", "Legacy Internal path UTF8 ascii width locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PATH_UTF8_FOUR_WIDTH_MUTANT", "Legacy Internal path UTF8 four width locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PATH_UTF8_THREE_WIDTH_MUTANT", "Legacy Internal path UTF8 three width locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PATH_UTF8_TWO_WIDTH_MUTANT", "Legacy Internal path UTF8 two width locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PREFIX_OBSERVED_COUNT_MUTANT", "Legacy Internal prefix observed count locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PREFIX_THRESHOLD_MUTANT", "Legacy Internal prefix threshold locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTED_CHECK_NAME_MUTANT", "Legacy Internal projected check name locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTED_FINDING_CODE_MUTANT", "Legacy Internal projected finding code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTED_FINDING_COUNT_MUTANT", "Legacy Internal projected finding count locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTED_FINDING_DETAIL_MUTANT", "Legacy Internal projected finding detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTED_FINDING_ORDER_MUTANT", "Legacy Internal projected finding order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTED_FINDING_SUBJECT_MUTANT", "Legacy Internal projected finding subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTED_OBSERVATION_COUNT_MUTANT", "Legacy Internal projected observation count locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTED_OBSERVATION_KEY_MUTANT", "Legacy Internal projected observation key locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTED_OBSERVATION_ORDER_MUTANT", "Legacy Internal projected observation order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTED_OBSERVATION_VALUE_MUTANT", "Legacy Internal projected observation value locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTION_GATE_MAPPING_DROP_MUTANT", "Legacy Internal projection gate mapping drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTION_GATE_MAPPING_KEY_MUTANT", "Legacy Internal projection gate mapping key locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTION_BINDING_INTEGRITY_DROP_MUTANT", "Legacy Internal projection binding integrity drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTION_BINDING_INTEGRITY_KEY_MUTANT", "Legacy Internal projection binding integrity key locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTION_CLOSED_EVIDENCE_INTEGRITY_DROP_MUTANT", "Legacy Internal projection closed evidence integrity drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTION_CLOSED_EVIDENCE_INTEGRITY_KEY_MUTANT", "Legacy Internal projection closed evidence integrity key locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTION_DIGEST_DOMAIN_MUTANT", "Legacy Internal projection digest domain locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTION_DIGEST_KEY_DROP_MUTANT", "Legacy Internal projection digest key drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTION_DIGEST_VALUE_DROP_MUTANT", "Legacy Internal projection digest value drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTION_FRAME_LENGTH_MUTANT", "Legacy Internal projection frame length locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTION_FRAME_SEPARATOR_MUTANT", "Legacy Internal projection frame separator locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTION_FRAME_VALUE_DROP_MUTANT", "Legacy Internal projection frame value drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTION_INTEGRITY_MAPPING_DROP_MUTANT", "Legacy Internal projection integrity mapping drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTION_INTEGRITY_MAPPING_KEY_MUTANT", "Legacy Internal projection integrity mapping key locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTION_INVENTORY_DROP_MUTANT", "Legacy Internal projection inventory drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTION_INVENTORY_KEY_MUTANT", "Legacy Internal projection inventory key locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTION_INVERSE_SOURCE_DEBT_DROP_MUTANT", "Legacy Internal projection inverse source debt drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTION_INVERSE_SOURCE_DEBT_KEY_MUTANT", "Legacy Internal projection inverse source debt key locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTION_LIFECYCLE_DROP_MUTANT", "Legacy Internal projection lifecycle drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTION_LIFECYCLE_KEY_MUTANT", "Legacy Internal projection lifecycle key locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTION_ORDER_MUTANT", "Legacy Internal projection order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTION_PARSER_DROP_MUTANT", "Legacy Internal projection parser drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTION_PARSER_KEY_MUTANT", "Legacy Internal projection parser key locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTION_RAW_CHECK_DROP_MUTANT", "Legacy Internal projection RAW check drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTION_RAW_CHECK_KEY_MUTANT", "Legacy Internal projection RAW check key locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTION_REGISTER_DROP_MUTANT", "Legacy Internal projection register drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTION_REGISTER_FINDING_DROP_MUTANT", "Legacy Internal projection register finding drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTION_REGISTER_FINDING_KEY_MUTANT", "Legacy Internal projection register finding key locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTION_REGISTER_KEY_MUTANT", "Legacy Internal projection register key locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTION_ROUTE_UNIVERSES_DROP_MUTANT", "Legacy Internal projection route universes drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTION_ROUTE_UNIVERSES_KEY_MUTANT", "Legacy Internal projection route universes key locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RAW_BINDING_ANALYZER_ROUTE_MUTANT", "Legacy Internal RAW binding analyzer route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RAW_BINDING_CLOSURE_ROUTE_MUTANT", "Legacy Internal RAW binding closure route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RAW_BINDING_DISPOSITION_ROUTE_MUTANT", "Legacy Internal RAW binding disposition route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RAW_BINDING_ID_ROUTE_MUTANT", "Legacy Internal RAW binding ID route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RAW_BINDING_OBSERVATION_ROUTE_MUTANT", "Legacy Internal RAW binding observation route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RAW_BINDING_ORDER_MUTANT", "Legacy Internal RAW binding order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RAW_BINDING_OWNER_ROUTE_MUTANT", "Legacy Internal RAW binding owner route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RAW_BINDING_REINTRODUCTION_ROUTE_MUTANT", "Legacy Internal RAW binding reintroduction route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RAW_CAPTURE_CODE_MUTANT", "Amoebius.Validation.Legacy.Internal.legacyRawCaptureCode refusal code", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RAW_CAPTURE_DETAIL_MUTANT", "Amoebius.Validation.Legacy.Internal.legacyRawCaptureDetail role-bound refusal detail", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RAW_CAPTURE_FINDING_DROP_MUTANT", "Amoebius.Validation.Legacy.Internal.legacyRawCaptureFindings mandatory raw-capture refusal retention", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RAW_CAPTURE_SUBJECT_MUTANT", "Amoebius.Validation.Legacy.Internal.legacyRawCaptureSubject role-bound refusal subject", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RAW_CLOSURE_ROUTE_MUTANT", "Legacy Internal RAW closure route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RAW_CONSUMER_ROUTE_MUTANT", "Legacy Internal RAW consumer route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RAW_DEBT_ROUTE_MUTANT", "Legacy Internal RAW debt route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RAW_JOIN_ORDER_MUTANT", "Legacy Internal RAW join order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RAW_JOIN_SOURCE_ROUTE_MUTANT", "Legacy Internal RAW join source route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RAW_JOIN_TARGET_ROUTE_MUTANT", "Legacy Internal RAW join target route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REFUSAL_DETAIL_PREDICATE_BYPASS_MUTANT", "Legacy Internal refusal detail predicate bypass locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_ADDITIONAL_DETAIL_MUTANT", "Legacy Internal register additional detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_ADDITIONAL_SUBJECT_MUTANT", "Legacy Internal register additional subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_ARCHIVE_DETAIL_MUTANT", "Legacy Internal register archive detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_ARCHIVE_SUBJECT_MUTANT", "Legacy Internal register archive subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_BYTE_DETAIL_MUTANT", "Legacy Internal register byte detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_BYTE_LIMIT_BYPASS_MUTANT", "Legacy Internal register byte limit bypass locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_BYTE_LIMIT_LITERAL_MUTANT", "Legacy Internal register byte limit literal locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_BYTE_SUBJECT_MUTANT", "Legacy Internal register byte subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_CARDINALITY_OBSERVATION_DROP_MUTANT", "Legacy Internal register cardinality observation drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_CARDINALITY_OBSERVATION_KEY_MUTANT", "Legacy Internal register cardinality observation key locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_CARDINALITY_OBSERVATION_VALUE_MUTANT", "Legacy Internal register cardinality observation value locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_ENCODING_OBSERVATION_DROP_MUTANT", "Legacy Internal register encoding observation drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_ENCODING_OBSERVATION_KEY_MUTANT", "Legacy Internal register encoding observation key locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_ENCODING_OBSERVATION_VALUE_MUTANT", "Legacy Internal register encoding observation value locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_ENTRY_DETAIL_MUTANT", "Legacy Internal register entry detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_ENTRY_LIMIT_BYPASS_MUTANT", "Legacy Internal register entry limit bypass locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_ENTRY_LIMIT_LITERAL_MUTANT", "Legacy Internal register entry limit literal locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_ENTRY_SUBJECT_MUTANT", "Legacy Internal register entry subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_FINDING_CODE_MUTANT", "Legacy Internal register finding code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_FINDING_DETAIL_ROUTE_MUTANT", "Legacy Internal register finding detail route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_FINDING_SUBJECT_ROUTE_MUTANT", "Legacy Internal register finding subject route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_GUARD_DETAIL_MUTANT", "Legacy Internal register guard detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_GUARD_SUBJECT_MUTANT", "Legacy Internal register guard subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_MISSING_DETAIL_MUTANT", "Legacy Internal register missing detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_MISSING_SUBJECT_MUTANT", "Legacy Internal register missing subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_MODE_DETAIL_MUTANT", "Legacy Internal register mode detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_MODE_OBSERVATION_DROP_MUTANT", "Legacy Internal register mode observation drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_MODE_OBSERVATION_KEY_MUTANT", "Legacy Internal register mode observation key locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_MODE_OBSERVATION_VALUE_MUTANT", "Legacy Internal register mode observation value locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_MODE_SUBJECT_MUTANT", "Legacy Internal register mode subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_MULTIPLE_DETAIL_MUTANT", "Legacy Internal register multiple detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_MULTIPLE_SUBJECT_MUTANT", "Legacy Internal register multiple subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_PATH_DETAIL_MUTANT", "Legacy Internal register path detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_PATH_LIMIT_BYPASS_MUTANT", "Legacy Internal register path limit bypass locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_PATH_LIMIT_LITERAL_MUTANT", "Legacy Internal register path limit literal locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_PATH_OBSERVATION_DROP_MUTANT", "Legacy Internal register path observation drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_PATH_OBSERVATION_KEY_MUTANT", "Legacy Internal register path observation key locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_PATH_OBSERVATION_VALUE_MUTANT", "Legacy Internal register path observation value locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_PATH_SUBJECT_MUTANT", "Legacy Internal register path subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_PROBLEMS_CLEAR_BYPASS_MUTANT", "Legacy Internal register problems clear bypass locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_PROBLEM_ORDER_MUTANT", "Legacy Internal register problem order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_SNAPSHOT_OBSERVATION_DROP_MUTANT", "Legacy Internal register snapshot observation drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_SNAPSHOT_OBSERVATION_KEY_MUTANT", "Legacy Internal register snapshot observation key locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_SNAPSHOT_OBSERVATION_VALUE_MUTANT", "Legacy Internal register snapshot observation value locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_UTF8_BYPASS_MUTANT", "Legacy Internal register UTF8 bypass locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_UTF8_DETAIL_MUTANT", "Legacy Internal register UTF8 detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_UTF8_SUBJECT_MUTANT", "Legacy Internal register UTF8 subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTRY_KEY_ROUTE_MUTANT", "Legacy Internal registry key route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REINTRODUCTION_BINDING_MATCH_BYPASS_MUTANT", "Legacy Internal reintroduction binding match bypass locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REINTRODUCTION_INVENTORY_CODE_MUTANT", "Legacy Internal reintroduction inventory code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REINTRODUCTION_INVENTORY_DETAIL_MUTANT", "Legacy Internal reintroduction inventory detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REINTRODUCTION_INVENTORY_SUBJECT_MUTANT", "Legacy Internal reintroduction inventory subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REINTRODUCTION_MISMATCH_CODE_MUTANT", "Legacy Internal reintroduction mismatch code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REINTRODUCTION_MISMATCH_DETAIL_MUTANT", "Legacy Internal reintroduction mismatch detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REINTRODUCTION_MISMATCH_SUBJECT_MUTANT", "Legacy Internal reintroduction mismatch subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REINTRODUCTION_MISSING_CODE_MUTANT", "Legacy Internal reintroduction missing code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REINTRODUCTION_MISSING_DETAIL_MUTANT", "Legacy Internal reintroduction missing detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REINTRODUCTION_MISSING_SUBJECT_MUTANT", "Legacy Internal reintroduction missing subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REINTRODUCTION_SLOT_MISSING_MUTANT", "Legacy Internal reintroduction slot missing locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDERING_UNIQUENESS_BYPASS_MUTANT", "Legacy Internal rendering uniqueness bypass locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_DISPOSITION_ACTIVE_MUTANT", "Legacy Internal render disposition active locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_DOC001_ANALYZER_MUTANT", "Legacy Internal render LTD doc001 analyzer locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_DOC001_CLOSURE_MUTANT", "Legacy Internal render LTD doc001 closure locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_DOC001_OBSERVATION_MUTANT", "Legacy Internal render LTD doc001 observation locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_DOC001_REINTRODUCTION_MUTANT", "Legacy Internal render LTD doc001 reintroduction locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_HOST001_ANALYZER_MUTANT", "Legacy Internal render LTD host001 analyzer locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_HOST001_CLOSURE_MUTANT", "Legacy Internal render LTD host001 closure locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_HOST001_OBSERVATION_MUTANT", "Legacy Internal render LTD host001 observation locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_HOST001_REINTRODUCTION_MUTANT", "Legacy Internal render LTD host001 reintroduction locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_HOST002_ANALYZER_MUTANT", "Legacy Internal render LTD host002 analyzer locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_HOST002_CLOSURE_MUTANT", "Legacy Internal render LTD host002 closure locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_HOST002_OBSERVATION_MUTANT", "Legacy Internal render LTD host002 observation locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_HOST002_REINTRODUCTION_MUTANT", "Legacy Internal render LTD host002 reintroduction locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_IMG001_ANALYZER_MUTANT", "Legacy Internal render LTD img001 analyzer locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_IMG001_CLOSURE_MUTANT", "Legacy Internal render LTD img001 closure locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_IMG001_OBSERVATION_MUTANT", "Legacy Internal render LTD img001 observation locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_IMG001_REINTRODUCTION_MUTANT", "Legacy Internal render LTD img001 reintroduction locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_META001_ANALYZER_MUTANT", "Legacy Internal render LTD meta001 analyzer locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_META001_CLOSURE_MUTANT", "Legacy Internal render LTD meta001 closure locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_META001_OBSERVATION_MUTANT", "Legacy Internal render LTD meta001 observation locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_META001_REINTRODUCTION_MUTANT", "Legacy Internal render LTD meta001 reintroduction locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_NAME001_ANALYZER_MUTANT", "Legacy Internal render LTD name001 analyzer locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_NAME001_CLOSURE_MUTANT", "Legacy Internal render LTD name001 closure locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_NAME001_OBSERVATION_MUTANT", "Legacy Internal render LTD name001 observation locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_NAME001_REINTRODUCTION_MUTANT", "Legacy Internal render LTD name001 reintroduction locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_RUN001_ANALYZER_MUTANT", "Legacy Internal render LTD run001 analyzer locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_RUN001_CLOSURE_MUTANT", "Legacy Internal render LTD run001 closure locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_RUN001_OBSERVATION_MUTANT", "Legacy Internal render LTD run001 observation locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_RUN001_REINTRODUCTION_MUTANT", "Legacy Internal render LTD run001 reintroduction locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SEED001_ANALYZER_MUTANT", "Legacy Internal render LTD seed001 analyzer locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SEED001_CLOSURE_MUTANT", "Legacy Internal render LTD seed001 closure locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SEED001_OBSERVATION_MUTANT", "Legacy Internal render LTD seed001 observation locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SEED001_REINTRODUCTION_MUTANT", "Legacy Internal render LTD seed001 reintroduction locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SEED002_ANALYZER_MUTANT", "Legacy Internal render LTD seed002 analyzer locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SEED002_CLOSURE_MUTANT", "Legacy Internal render LTD seed002 closure locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SEED002_OBSERVATION_MUTANT", "Legacy Internal render LTD seed002 observation locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SEED002_REINTRODUCTION_MUTANT", "Legacy Internal render LTD seed002 reintroduction locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC000_ANALYZER_MUTANT", "Legacy Internal render LTD src000 analyzer locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC000_CLOSURE_MUTANT", "Legacy Internal render LTD src000 closure locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC000_OBSERVATION_MUTANT", "Legacy Internal render LTD src000 observation locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC000_REINTRODUCTION_MUTANT", "Legacy Internal render LTD src000 reintroduction locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC001_ANALYZER_MUTANT", "Legacy Internal render LTD src001 analyzer locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC001_CLOSURE_MUTANT", "Legacy Internal render LTD src001 closure locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC001_OBSERVATION_MUTANT", "Legacy Internal render LTD src001 observation locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC001_REINTRODUCTION_MUTANT", "Legacy Internal render LTD src001 reintroduction locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC002_ANALYZER_MUTANT", "Legacy Internal render LTD src002 analyzer locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC002_CLOSURE_MUTANT", "Legacy Internal render LTD src002 closure locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC002_OBSERVATION_MUTANT", "Legacy Internal render LTD src002 observation locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC002_REINTRODUCTION_MUTANT", "Legacy Internal render LTD src002 reintroduction locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC003_ANALYZER_MUTANT", "Legacy Internal render LTD src003 analyzer locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC003_CLOSURE_MUTANT", "Legacy Internal render LTD src003 closure locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC003_OBSERVATION_MUTANT", "Legacy Internal render LTD src003 observation locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC003_REINTRODUCTION_MUTANT", "Legacy Internal render LTD src003 reintroduction locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC004_ANALYZER_MUTANT", "Legacy Internal render LTD src004 analyzer locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC004_CLOSURE_MUTANT", "Legacy Internal render LTD src004 closure locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC004_OBSERVATION_MUTANT", "Legacy Internal render LTD src004 observation locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC004_REINTRODUCTION_MUTANT", "Legacy Internal render LTD src004 reintroduction locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC005_ANALYZER_MUTANT", "Legacy Internal render LTD src005 analyzer locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC005_CLOSURE_MUTANT", "Legacy Internal render LTD src005 closure locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC005_OBSERVATION_MUTANT", "Legacy Internal render LTD src005 observation locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC005_REINTRODUCTION_MUTANT", "Legacy Internal render LTD src005 reintroduction locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC006_ANALYZER_MUTANT", "Legacy Internal render LTD src006 analyzer locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC006_CLOSURE_MUTANT", "Legacy Internal render LTD src006 closure locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC006_OBSERVATION_MUTANT", "Legacy Internal render LTD src006 observation locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC006_REINTRODUCTION_MUTANT", "Legacy Internal render LTD src006 reintroduction locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC007_ANALYZER_MUTANT", "Legacy Internal render LTD src007 analyzer locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC007_CLOSURE_MUTANT", "Legacy Internal render LTD src007 closure locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC007_OBSERVATION_MUTANT", "Legacy Internal render LTD src007 observation locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC007_REINTRODUCTION_MUTANT", "Legacy Internal render LTD src007 reintroduction locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC008_ANALYZER_MUTANT", "Legacy Internal render LTD src008 analyzer locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC008_CLOSURE_MUTANT", "Legacy Internal render LTD src008 closure locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC008_OBSERVATION_MUTANT", "Legacy Internal render LTD src008 observation locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC008_REINTRODUCTION_MUTANT", "Legacy Internal render LTD src008 reintroduction locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC009_ANALYZER_MUTANT", "Legacy Internal render LTD src009 analyzer locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC009_CLOSURE_MUTANT", "Legacy Internal render LTD src009 closure locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC009_OBSERVATION_MUTANT", "Legacy Internal render LTD src009 observation locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_SRC009_REINTRODUCTION_MUTANT", "Legacy Internal render LTD src009 reintroduction locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL001_ANALYZER_MUTANT", "Legacy Internal render LTD val001 analyzer locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL001_CLOSURE_MUTANT", "Legacy Internal render LTD val001 closure locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL001_OBSERVATION_MUTANT", "Legacy Internal render LTD val001 observation locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL001_REINTRODUCTION_MUTANT", "Legacy Internal render LTD val001 reintroduction locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL002_ANALYZER_MUTANT", "Legacy Internal render LTD val002 analyzer locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL002_CLOSURE_MUTANT", "Legacy Internal render LTD val002 closure locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL002_OBSERVATION_MUTANT", "Legacy Internal render LTD val002 observation locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL002_REINTRODUCTION_MUTANT", "Legacy Internal render LTD val002 reintroduction locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL003_ANALYZER_MUTANT", "Legacy Internal render LTD val003 analyzer locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL003_CLOSURE_MUTANT", "Legacy Internal render LTD val003 closure locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL003_OBSERVATION_MUTANT", "Legacy Internal render LTD val003 observation locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL003_REINTRODUCTION_MUTANT", "Legacy Internal render LTD val003 reintroduction locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL004_ANALYZER_MUTANT", "Legacy Internal render LTD val004 analyzer locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL004_CLOSURE_MUTANT", "Legacy Internal render LTD val004 closure locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL004_OBSERVATION_MUTANT", "Legacy Internal render LTD val004 observation locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL004_REINTRODUCTION_MUTANT", "Legacy Internal render LTD val004 reintroduction locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL005_ANALYZER_MUTANT", "Legacy Internal render LTD val005 analyzer locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL005_CLOSURE_MUTANT", "Legacy Internal render LTD val005 closure locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL005_OBSERVATION_MUTANT", "Legacy Internal render LTD val005 observation locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL005_REINTRODUCTION_MUTANT", "Legacy Internal render LTD val005 reintroduction locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL006_ANALYZER_MUTANT", "Legacy Internal render LTD val006 analyzer locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL006_CLOSURE_MUTANT", "Legacy Internal render LTD val006 closure locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL006_OBSERVATION_MUTANT", "Legacy Internal render LTD val006 observation locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_LTD_VAL006_REINTRODUCTION_MUTANT", "Legacy Internal render LTD val006 reintroduction locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_OWNER_PLAIN_MUTANT", "Legacy Internal render owner plain locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_OWNER_PREFIX_MUTANT", "Legacy Internal render owner prefix locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_SNAPSHOT_REFUSAL_CODE_MUTANT", "Legacy Internal snapshot refusal code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_SNAPSHOT_REFUSAL_DETAIL_MUTANT", "Legacy Internal snapshot refusal detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_SNAPSHOT_REFUSAL_DROP_MUTANT", "Legacy Internal snapshot refusal drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_SNAPSHOT_REFUSAL_SUBJECT_MUTANT", "Legacy Internal snapshot refusal subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_STATIC_PHASE_FALLBACK_MUTANT", "Legacy.Internal static phase fallback value", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_SOURCE_DEBT_DHALL_DROP_MUTANT", "Legacy Internal source debt dhall drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_SOURCE_DEBT_PB_DROP_MUTANT", "Legacy Internal source debt pb drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_SOURCE_DEBT_PROBE_DROP_MUTANT", "Legacy Internal source debt probe drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_SOURCE_DEBT_PROTO_DROP_MUTANT", "Legacy Internal source debt proto drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_SOURCE_DEBT_PULUMI_DROP_MUTANT", "Legacy Internal source debt pulumi drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_SOURCE_DEBT_TEST_DROP_MUTANT", "Legacy Internal source debt test drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_SOURCE_DEBT_TOOLS_DROP_MUTANT", "Legacy Internal source debt tools drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_SOURCE_DEBT_UI_DROP_MUTANT", "Legacy Internal source debt ui drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_SOURCE_DEBT_UNIVERSE_ORDER_MUTANT", "Legacy Internal source debt universe order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_SOURCE_DEBT_VENDOR_DROP_MUTANT", "Legacy Internal source debt vendor drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_TRANSITION_UNRECORDED_CODE_MUTANT", "Legacy Internal transition unrecorded code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_TRANSITION_UNRECORDED_DETAIL_MUTANT", "Legacy Internal transition unrecorded detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_TRANSITION_UNRECORDED_SUBJECT_MUTANT", "Legacy Internal transition unrecorded subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIMPLEMENTED_LATER_UNAVAILABLE_MUTANT", "Legacy Internal unimplemented later unavailable locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIMPLEMENTED_OWNER_PREDICATE_BYPASS_MUTANT", "Legacy Internal unimplemented owner predicate bypass locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIMPLEMENTED_REFUSAL_DETAIL_MUTANT", "Legacy Internal unimplemented refusal detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_DOC001_DROP_MUTANT", "Legacy Internal universe LTD doc001 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_HOST001_DROP_MUTANT", "Legacy Internal universe LTD host001 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_HOST002_DROP_MUTANT", "Legacy Internal universe LTD host002 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_IMG001_DROP_MUTANT", "Legacy Internal universe LTD img001 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_META001_DROP_MUTANT", "Legacy Internal universe LTD meta001 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_NAME001_DROP_MUTANT", "Legacy Internal universe LTD name001 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_RUN001_DROP_MUTANT", "Legacy Internal universe LTD run001 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_SEED001_DROP_MUTANT", "Legacy Internal universe LTD seed001 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_SEED002_DROP_MUTANT", "Legacy Internal universe LTD seed002 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_SRC000_DROP_MUTANT", "Legacy Internal universe LTD src000 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_SRC001_DROP_MUTANT", "Legacy Internal universe LTD src001 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_SRC002_DROP_MUTANT", "Legacy Internal universe LTD src002 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_SRC003_DROP_MUTANT", "Legacy Internal universe LTD src003 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_SRC004_DROP_MUTANT", "Legacy Internal universe LTD src004 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_SRC005_DROP_MUTANT", "Legacy Internal universe LTD src005 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_SRC006_DROP_MUTANT", "Legacy Internal universe LTD src006 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_SRC007_DROP_MUTANT", "Legacy Internal universe LTD src007 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_SRC008_DROP_MUTANT", "Legacy Internal universe LTD src008 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_SRC009_DROP_MUTANT", "Legacy Internal universe LTD src009 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_VAL001_DROP_MUTANT", "Legacy Internal universe LTD val001 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_VAL002_DROP_MUTANT", "Legacy Internal universe LTD val002 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_VAL003_DROP_MUTANT", "Legacy Internal universe LTD val003 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_VAL004_DROP_MUTANT", "Legacy Internal universe LTD val004 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_VAL005_DROP_MUTANT", "Legacy Internal universe LTD val005 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIVERSE_LTD_VAL006_DROP_MUTANT", "Legacy Internal universe LTD val006 drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIVERSE_ORDER_MUTANT", "Legacy Internal universe order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ZERO_OWNER_ROUTE_MUTANT", "Legacy Internal zero owner route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_EXECUTION_CODE_MUTANT", "Legacy Join execution code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_EXECUTION_PREFIX_MUTANT", "Legacy Join execution prefix locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_EXECUTION_SUBJECT_MUTANT", "Legacy Join execution subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_EXECUTION_SUFFIX_MUTANT", "Legacy Join execution suffix locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_EXECUTION_TARGET_MUTANT", "Legacy Join execution target locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_OBSERVATION_KEY_MUTANT", "Legacy Join observation key locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_OBSERVATION_SEPARATOR_MUTANT", "Legacy Join observation separator locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_OBSERVATION_SOURCE_MUTANT", "Legacy Join observation source locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_OBSERVATION_TARGET_MUTANT", "Legacy Join observation target locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_SUBJECT_PREFIX_MUTANT", "Legacy Join subject prefix locus", "join source bytes maximum plus one")
  , ("VALIDATION_LEGACY_LENGTH_FRAME_MUTANT", "Legacy Length frame locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_MANDATORY_ANALYZER_EVIDENCE_CODE_MUTANT", "Legacy Mandatory analyzer evidence code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_MANDATORY_ANALYZER_EVIDENCE_DETAIL_MUTANT", "Legacy Mandatory analyzer evidence detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_MANDATORY_ANALYZER_EVIDENCE_SUBJECT_MUTANT", "Legacy Mandatory analyzer evidence subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_MANDATORY_DIAGNOSTIC_ONLY_CODE_MUTANT", "Legacy Mandatory diagnostic only code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_MANDATORY_DIAGNOSTIC_ONLY_DETAIL_MUTANT", "Legacy Mandatory diagnostic only detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_MANDATORY_DIAGNOSTIC_ONLY_SUBJECT_MUTANT", "Legacy Mandatory diagnostic only subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_MANDATORY_DOCUMENTATION_CORRESPONDENCE_CODE_MUTANT", "Legacy Mandatory documentation correspondence check code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_MANDATORY_DOCUMENTATION_CORRESPONDENCE_DETAIL_MUTANT", "Legacy Mandatory documentation correspondence check detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_MANDATORY_DOCUMENTATION_CORRESPONDENCE_SUBJECT_MUTANT", "Legacy Mandatory documentation correspondence check subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_MANDATORY_QUALIFICATION_CODE_MUTANT", "Legacy Mandatory qualification code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_MANDATORY_QUALIFICATION_DETAIL_MUTANT", "Legacy Mandatory qualification detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_MANDATORY_QUALIFICATION_SUBJECT_MUTANT", "Legacy Mandatory qualification subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_MANDATORY_REINTRODUCTION_EXECUTION_CODE_MUTANT", "Legacy Mandatory reintroduction execution code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_MANDATORY_REINTRODUCTION_EXECUTION_DETAIL_MUTANT", "Legacy Mandatory reintroduction execution detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_MANDATORY_REINTRODUCTION_EXECUTION_SUBJECT_MUTANT", "Legacy Mandatory reintroduction execution subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_MANDATORY_SOURCE_BINDING_CODE_MUTANT", "Legacy Mandatory source binding code locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_MANDATORY_SOURCE_BINDING_DETAIL_MUTANT", "Legacy Mandatory source binding detail locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_MANDATORY_SOURCE_BINDING_SUBJECT_MUTANT", "Legacy Mandatory source binding subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_OBSERVATION_BINDING_COUNT_KEY_MUTANT", "Legacy Observation binding count key locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_OBSERVATION_BINDING_COUNT_VALUE_MUTANT", "Legacy Observation binding count value locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_OBSERVATION_COMMITMENT_DIGEST_KEY_MUTANT", "Legacy Observation commitment digest key locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_OBSERVATION_COMMITMENT_DIGEST_VALUE_MUTANT", "Legacy Observation commitment digest value locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_OBSERVATION_COMMITMENT_KIND_KEY_MUTANT", "Legacy Observation commitment kind key locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_OBSERVATION_COMMITMENT_KIND_VALUE_MUTANT", "Legacy Observation commitment kind value locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_OBSERVATION_JOIN_COUNT_KEY_MUTANT", "Legacy Observation join count key locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_OBSERVATION_JOIN_COUNT_VALUE_MUTANT", "Legacy Observation join count value locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_OBSERVATION_PHASE_KEY_MUTANT", "Legacy Observation phase key locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_OBSERVATION_PHASE_VALUE_MUTANT", "Legacy Observation phase value locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_OBSERVATION_SELECTED_BINDING_COUNT_KEY_MUTANT", "Legacy Observation selected binding count key locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_OBSERVATION_SELECTED_BINDING_COUNT_VALUE_MUTANT", "Legacy Observation selected binding count value locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_OBSERVATION_SELECTED_JOIN_COUNT_KEY_MUTANT", "Legacy Observation selected join count key locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_OBSERVATION_SELECTED_JOIN_COUNT_VALUE_MUTANT", "Legacy Observation selected join count value locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_OBSERVATION_STATUS_KEY_MUTANT", "Legacy Observation status key locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_OBSERVATION_STATUS_VALUE_MUTANT", "Legacy Observation status value locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_PHASE_BLOCKED_CODE_MUTANT", "Legacy Phase blocked code locus", "later phase route")
  , ("VALIDATION_LEGACY_PHASE_BLOCKED_DETAIL_MUTANT", "Legacy Phase blocked detail locus", "later phase route")
  , ("VALIDATION_LEGACY_PHASE_BLOCKED_SUBJECT_MUTANT", "Legacy Phase blocked subject locus", "later phase route")
  , ("VALIDATION_LEGACY_PHASE_GENESIS_ROUTE_MUTANT", "Legacy Phase genesis route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_PROBLEM_TAG_AGGREGATE_BYTE_MUTANT", "Legacy Problem tag aggregate byte locus", "aggregate bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_TAG_ANALYZER_BYTE_MUTANT", "Legacy Problem tag analyzer byte locus", "analyzer bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_TAG_BINDING_LIMIT_MUTANT", "Legacy Problem tag binding limit locus", "binding count maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_TAG_CLOSURE_BYTE_MUTANT", "Legacy Problem tag closure byte locus", "closure bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_TAG_DISPOSITION_BYTE_MUTANT", "Legacy Problem tag disposition byte locus", "disposition bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_TAG_ID_BYTE_MUTANT", "Legacy Problem tag ID byte locus", "stable ID bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_TAG_JOIN_LIMIT_MUTANT", "Legacy Problem tag join limit locus", "join count maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_TAG_JOIN_SOURCE_BYTE_MUTANT", "Legacy Problem tag join source byte locus", "join source bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_TAG_JOIN_TARGET_BYTE_MUTANT", "Legacy Problem tag join target byte locus", "join target bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_TAG_OBSERVATION_BYTE_MUTANT", "Legacy Problem tag observation byte locus", "observation bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_TAG_OWNER_BYTE_MUTANT", "Legacy Problem tag owner byte locus", "owner bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_TAG_PHASE_BYTE_MUTANT", "Legacy Problem tag phase byte locus", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_TAG_REINTRODUCTION_BYTE_MUTANT", "Legacy Problem tag reintroduction byte locus", "reintroduction bytes maximum plus one")
  , ("VALIDATION_LEGACY_PROBLEM_TAG_REINTRODUCTION_COUNT_MUTANT", "Legacy Problem tag reintroduction count locus", "reintroduction count maximum plus one")
  , ("VALIDATION_LEGACY_RAW_BINDING_ID_PROJECTION_MUTANT", "Legacy RAW binding ID projection locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_RESOURCE_BINDING_FIELD_ORDER_MUTANT", "Legacy Resource binding field order locus", "resource binding field precedence")
  , ("VALIDATION_LEGACY_RESOURCE_BINDING_ROW_ORDER_MUTANT", "Legacy Resource binding row order locus", "resource binding row precedence")
  , ("VALIDATION_LEGACY_RESOURCE_CLASS_ORDER_MUTANT", "Legacy Resource class order locus", "resource class precedence")
  , ("VALIDATION_LEGACY_RESOURCE_JOIN_FIELD_ORDER_MUTANT", "Legacy Resource join field order locus", "resource join field precedence")
  , ("VALIDATION_LEGACY_RESOURCE_JOIN_ROW_ORDER_MUTANT", "Legacy Resource join row order locus", "resource join row precedence")
  , ("VALIDATION_LEGACY_RESOURCE_MAXIMUM_LABEL_MUTANT", "Legacy Resource maximum label locus", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_RESOURCE_OBSERVED_LABEL_MUTANT", "Legacy Resource observed label locus", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_RESULT_BINDING_EXECUTION_ORDER_MUTANT", "Legacy Result binding execution order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_RESULT_BINDING_OBSERVATION_ORDER_MUTANT", "Legacy Result binding observation order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_RESULT_FIXED_OBSERVATION_BLOCK_DROP_MUTANT", "Legacy Result fixed observation block drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_RESULT_INTERNAL_PROJECTION_DROP_MUTANT", "Legacy Result internal projection drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_RESULT_JOIN_EXECUTION_ORDER_MUTANT", "Legacy Result join execution order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_RESULT_JOIN_OBSERVATION_ORDER_MUTANT", "Legacy Result join observation order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_RESULT_PROBLEM_FINDING_BLOCK_DROP_MUTANT", "Legacy Result problem finding block drop locus", "phase width negative")
  , ("VALIDATION_LEGACY_SUBJECT_SUFFIX_MUTANT", "Legacy Subject suffix locus", "stable ID bytes maximum plus one")
  , ("VALIDATION_LEGACY_UTF8_WIDTH_FOUR_MUTANT", "Legacy UTF8 width four locus", "stable ID four-byte maximum plus one")
  , ("VALIDATION_LEGACY_UTF8_WIDTH_ONE_MUTANT", "Legacy UTF8 width one locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_UTF8_WIDTH_THREE_MUTANT", "Legacy UTF8 width three locus", "stable ID three-byte maximum plus one")
  , ("VALIDATION_LEGACY_UTF8_WIDTH_TWO_MUTANT", "Legacy UTF8 width two locus", "stable ID two-byte maximum plus one")
  , ("VALIDATION_LEGACY_AGGREGATE_TEXT_BYTE_MEASUREMENT_MUTANT", "Legacy Aggregate text byte measurement locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_ANALYSIS_BINDING_PREFLIGHT_ROUTE_MUTANT", "Legacy Analysis binding preflight route locus", "binding count maximum plus one")
  , ("VALIDATION_LEGACY_ANALYSIS_BINDING_ROUTE_MUTANT", "Legacy Analysis binding route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_ANALYSIS_JOIN_PREFLIGHT_ROUTE_MUTANT", "Legacy Analysis join preflight route locus", "join count maximum plus one")
  , ("VALIDATION_LEGACY_ANALYSIS_JOIN_ROUTE_MUTANT", "Legacy Analysis join route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_ANALYSIS_PHASE_PREFLIGHT_ROUTE_MUTANT", "Legacy Analysis phase preflight route locus", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_ANALYSIS_PHASE_ROUTE_MUTANT", "Legacy Analysis phase route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_ANALYSIS_RESOURCE_PROBLEM_ROUTE_MUTANT", "Legacy Analysis resource problem route locus", "stable ID bytes maximum plus one")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_DETAIL_ORDER_MUTANT", "Legacy Binding execution detail order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_EXECUTION_FINDING_COMPOSITION_MUTANT", "Legacy Binding execution finding composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_OBSERVATION_COMPOSITION_MUTANT", "Legacy Binding observation composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_RENDER_COMPONENT_ORDER_MUTANT", "Legacy Binding render component order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_BINDING_SUBJECT_COMPOSITION_MUTANT", "Legacy Binding subject composition locus", "stable ID bytes maximum plus one")
  , ("VALIDATION_LEGACY_BOUNDED_BINDING_COMPONENT_ORDER_MUTANT", "Legacy Bounded binding component order locus", "stable ID bytes maximum plus one")
  , ("VALIDATION_LEGACY_BOUNDED_DIGEST_COMPONENT_ORDER_MUTANT", "Legacy Bounded digest component order locus", "phase bytes maximum plus one")
  , ("VALIDATION_LEGACY_BOUNDED_JOIN_COMPONENT_ORDER_MUTANT", "Legacy Bounded join component order locus", "join source bytes maximum plus one")
  , ("VALIDATION_LEGACY_BOUNDED_TEXT_COMPONENT_ORDER_MUTANT", "Legacy Bounded text component order locus", "stable ID bytes maximum plus one")
  , ("VALIDATION_LEGACY_CANONICAL_BINDING_COMPOSITION_MUTANT", "Legacy Canonical binding composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_CANONICAL_BINDING_LIST_COMPOSITION_MUTANT", "Legacy Canonical binding list composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_CANONICAL_JOIN_COMPOSITION_MUTANT", "Legacy Canonical join composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_CANONICAL_JOIN_LIST_COMPOSITION_MUTANT", "Legacy Canonical join list composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_COMMITMENT_DETAIL_ORDER_MUTANT", "Legacy Commitment detail order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_COMMITMENT_DIGEST_LABEL_ROUTE_MUTANT", "Legacy Commitment digest label route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_COMPLETE_ANALYSIS_FIELD_ORDER_MUTANT", "Legacy Complete analysis field order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_COMPLETE_DIGEST_COMPONENT_ORDER_MUTANT", "Legacy Complete digest component order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_DIGEST_BINDING_COMPONENT_ORDER_MUTANT", "Legacy Digest binding component order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_DIGEST_JOIN_COMPONENT_ORDER_MUTANT", "Legacy Digest join component order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_FIRST_PRESENT_RETENTION_MUTANT", "Legacy First present retention locus", "resource binding field precedence")
  , ("VALIDATION_LEGACY_FIXED_OBSERVATION_COMPONENT_ORDER_MUTANT", "Legacy Fixed observation component order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_GRAMMAR_BINDING_CLASS_DROP_MUTANT", "Legacy Grammar binding class drop locus", "binding disposition negative")
  , ("VALIDATION_LEGACY_GRAMMAR_JOIN_CLASS_DROP_MUTANT", "Legacy Grammar join class drop locus", "join target negative")
  , ("VALIDATION_LEGACY_GRAMMAR_PHASE_CLASS_DROP_MUTANT", "Legacy Grammar phase class drop locus", "phase width negative")
  , ("VALIDATION_LEGACY_INTERNAL_ARCHIVE_REGISTER_NAME_ROUTE_MUTANT", "Legacy Internal archive register name route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_GATE_MAPPING_PROJECTION_COMPOSITION_MUTANT", "Legacy Internal gate mapping projection composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_BINDING_CONTRACTS_RENDER_COMPONENT_ORDER_MUTANT", "Legacy Internal binding contracts render component order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_BINDING_CONTRACTS_RENDER_ORDER_MUTANT", "Legacy Internal binding contracts render order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_BINDING_CONTRACTS_RENDER_SEPARATOR_MUTANT", "Legacy Internal binding contracts render separator locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_BINDING_FINDING_COMPOSITION_MUTANT", "Legacy Internal binding finding composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_BINDING_INTEGRITY_FINDING_ORDER_MUTANT", "Legacy Internal binding integrity finding order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_BINDING_INTEGRITY_PROJECTION_COMPONENT_ORDER_MUTANT", "Legacy Internal binding integrity projection component order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_BINDING_INTEGRITY_PROJECTION_ORDER_MUTANT", "Legacy Internal binding integrity projection order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CANDIDATE_FINDING_ORDER_MUTANT", "Legacy Internal candidate finding order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CANDIDATE_OBSERVATION_ORDER_MUTANT", "Legacy Internal candidate observation order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CANONICAL_DECODER_COMPOSITION_MUTANT", "Legacy Internal canonical decoder composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CANONICAL_REGISTER_PATH_ROUTE_MUTANT", "Legacy Internal canonical register path route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CANONICAL_UNIVERSE_COMPOSITION_MUTANT", "Legacy Internal canonical universe composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_ENTRY_ORDER_MUTANT", "Legacy Internal closed evidence entry order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_FINDING_COMPOSITION_MUTANT", "Legacy Internal closed evidence finding composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_FINDING_ORDER_MUTANT", "Legacy Internal closed evidence finding order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_PROJECTION_COMPONENT_ORDER_MUTANT", "Legacy Internal closed evidence projection component order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_PROJECTION_FIELD_ORDER_MUTANT", "Legacy Internal closed evidence projection field order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_CLOSED_EVIDENCE_PROJECTION_ORDER_MUTANT", "Legacy Internal closed evidence projection order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_COMPILER_SNAPSHOT_FINDING_COMPOSITION_MUTANT", "Legacy Internal compiler snapshot finding composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_COMPILER_SNAPSHOT_FINDING_ORDER_MUTANT", "Legacy Internal compiler snapshot finding order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_COMPILER_SNAPSHOT_FINDING_RETENTION_MUTANT", "Legacy Internal compiler snapshot finding retention locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_COMPLETE_CONTRIBUTION_ORDER_MUTANT", "Legacy Internal complete contribution order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_COMPLETE_FINDING_FRAME_COMPONENT_ORDER_MUTANT", "Legacy Internal complete finding frame component order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_COMPLETE_FINDING_PROJECTION_ORDER_MUTANT", "Legacy Internal complete finding projection order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DIAGNOSTIC_REFUSAL_FINDING_COMPOSITION_MUTANT", "Legacy Internal diagnostic refusal finding composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_DIAGNOSTIC_REFUSAL_ORDER_MUTANT", "Legacy Internal diagnostic refusal order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_EVALUATE_DIAGNOSTIC_REFUSAL_COMPOSITION_MUTANT", "Legacy Internal evaluate diagnostic refusal composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_EVALUATION_FINDING_ORDER_MUTANT", "Legacy Internal evaluation finding order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_INTEGRITY_FINDING_COMPOSITION_MUTANT", "Legacy Internal integrity finding composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_INTEGRITY_MAPPING_PROJECTION_COMPOSITION_MUTANT", "Legacy Internal integrity mapping projection composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_INVENTORY_DIAGNOSTIC_REFUSAL_COMPOSITION_MUTANT", "Legacy Internal inventory diagnostic refusal composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_INVENTORY_FINDING_ORDER_MUTANT", "Legacy Internal inventory finding order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_INVENTORY_FIXED_OBSERVATION_ORDER_MUTANT", "Legacy Internal inventory fixed observation order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_INVENTORY_OBSERVATION_ORDER_MUTANT", "Legacy Internal inventory observation order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_INVENTORY_PROJECTION_ORDER_MUTANT", "Legacy Internal inventory projection order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_INVERSE_SOURCE_DEBT_PROJECTION_COMPONENT_ORDER_MUTANT", "Legacy Internal inverse source debt projection component order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_LEGACY_SUBJECT_COMPOSITION_MUTANT", "Legacy Internal legacy subject composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_LIFECYCLE_FINDING_COMPOSITION_MUTANT", "Legacy Internal lifecycle finding composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_LIFECYCLE_PROJECTION_COMPONENT_ORDER_MUTANT", "Legacy Internal lifecycle projection component order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_LIFECYCLE_PROJECTION_ORDER_MUTANT", "Legacy Internal lifecycle projection order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_MALFORMED_OBSERVATION_FINDING_COMPOSITION_MUTANT", "Legacy Internal malformed observation finding composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OBSERVED_OPEN_ROUTE_MUTANT", "Legacy Internal observed open route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OBSERVED_REFUSAL_ROUTE_MUTANT", "Legacy Internal observed refusal route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OWNER_BINDINGS_RENDER_COMPONENT_ORDER_MUTANT", "Legacy Internal owner bindings render component order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OWNER_BINDINGS_RENDER_ORDER_MUTANT", "Legacy Internal owner bindings render order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_OWNER_BINDINGS_RENDER_SEPARATOR_MUTANT", "Legacy Internal owner bindings render separator locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PARSER_PROJECTION_COMPONENT_ORDER_MUTANT", "Legacy Internal parser projection component order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PARSER_PROJECTION_ORDER_MUTANT", "Legacy Internal parser projection order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PATH_PREFIX_THRESHOLD_MUTANT", "Legacy Internal path prefix threshold locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PHASE_ORDINAL_FALLBACK_ROUTE_MUTANT", "Legacy Internal phase ordinal fallback route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PREFIX_RETENTION_ORDER_MUTANT", "Legacy Internal prefix retention order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTED_CHECK_COMPONENT_ORDER_MUTANT", "Legacy Internal projected check component order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTION_DIGEST_COMPONENT_ORDER_MUTANT", "Legacy Internal projection digest component order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTION_FRAME_COMPONENT_ORDER_MUTANT", "Legacy Internal projection frame component order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_PROJECTION_OBSERVATION_COMPOSITION_MUTANT", "Legacy Internal projection observation composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RAW_CAPTURE_FINDING_COMPOSITION_MUTANT", "Legacy Internal RAW capture finding composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RAW_CAPTURE_RESULT_NAME_MUTANT", "Legacy Internal RAW capture result name locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RAW_BINDING_LIST_COMPOSITION_MUTANT", "Legacy Internal RAW binding list composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RAW_BINDING_TUPLE_COMPOSITION_MUTANT", "Legacy Internal RAW binding tuple composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RAW_CHECK_PROJECTION_COMPOSITION_MUTANT", "Legacy Internal RAW check projection composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RAW_CHECK_REFUSAL_COMPOSITION_MUTANT", "Legacy Internal RAW check refusal composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RAW_JOIN_LIST_COMPOSITION_MUTANT", "Legacy Internal RAW join list composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_ACCEPTED_ROUTE_MUTANT", "Legacy Internal register accepted route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_BYTE_PREFLIGHT_THRESHOLD_MUTANT", "Legacy Internal register byte preflight threshold locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_DUPLICATE_ROUTE_MUTANT", "Legacy Internal register duplicate route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_ENTRY_LIMIT_RETENTION_MUTANT", "Legacy Internal register entry limit retention locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_ENTRY_PREFLIGHT_ROUTE_MUTANT", "Legacy Internal register entry preflight route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_FINDING_COMPOSITION_MUTANT", "Legacy Internal register finding composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_FINDING_PROJECTION_FIELD_ORDER_MUTANT", "Legacy Internal register finding projection field order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_GUARD_ROUTE_MUTANT", "Legacy Internal register guard route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_MAPPING_ENTRY_DROP_MUTANT", "Legacy Internal register mapping entry drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_MAPPING_ORDER_MUTANT", "Legacy Internal register mapping order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_MISSING_ROUTE_MUTANT", "Legacy Internal register missing route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_MODE_ROUTE_MUTANT", "Legacy Internal register mode route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_OUTCOME_ROUTE_MUTANT", "Legacy Internal register outcome route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_PATH_PREFLIGHT_ROUTE_MUTANT", "Legacy Internal register path preflight route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_PATH_PROBLEM_RETENTION_MUTANT", "Legacy Internal register path problem retention locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_PROJECTION_COMPONENT_ORDER_MUTANT", "Legacy Internal register projection component order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_REGISTER_PROJECTION_ORDER_MUTANT", "Legacy Internal register projection order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_OBSERVATION_SUPPLIED_ORDER_MUTANT", "Legacy Internal render observation supplied order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_OBSERVATION_UNAVAILABLE_ROUTE_MUTANT", "Legacy Internal render observation unavailable route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_OWNER_MISSING_MUTANT", "Legacy Internal render owner missing locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_OWNER_PRESENT_MUTANT", "Legacy Internal render owner present locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_STATE_OPEN_ORDER_MUTANT", "Legacy Internal render state open order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_STATE_REFUSED_MUTANT", "Legacy Internal render state refused locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_RENDER_STATE_ZERO_MUTANT", "Legacy Internal render state zero locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_ROUTE_UNIVERSES_PROJECTION_ORDER_MUTANT", "Legacy Internal route universes projection order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_SEMANTIC_SUBJECT_MUTANT", "Legacy Internal semantic subject locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_SLOT_PRESENT_ROUTE_MUTANT", "Legacy Internal slot present route locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_SNAPSHOT_REFUSAL_FINDING_COMPOSITION_MUTANT", "Legacy Internal snapshot refusal finding composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_SNAPSHOT_REFUSAL_ORDER_MUTANT", "Legacy Internal snapshot refusal order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_STRUCTURAL_OBSERVATION_ORDER_MUTANT", "Legacy Internal structural observation order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIVERSE_BINDING_FINDING_DROP_MUTANT", "Legacy Internal universe binding finding drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIVERSE_CLOSED_FINDING_DROP_MUTANT", "Legacy Internal universe closed finding drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIVERSE_INTEGRITY_FINDING_ORDER_MUTANT", "Legacy Internal universe integrity finding order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIVERSE_INVENTORY_FINDING_DROP_MUTANT", "Legacy Internal universe inventory finding drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIVERSE_PARSER_FINDING_DROP_MUTANT", "Legacy Internal universe parser finding drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_INTERNAL_UNIVERSE_RENDERING_FINDING_DROP_MUTANT", "Legacy Internal universe rendering finding drop locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_EXECUTION_DETAIL_ORDER_MUTANT", "Legacy Join execution detail order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_EXECUTION_FINDING_COMPOSITION_MUTANT", "Legacy Join execution finding composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_OBSERVATION_COMPOSITION_MUTANT", "Legacy Join observation composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_OBSERVATION_VALUE_ORDER_MUTANT", "Legacy Join observation value order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_JOIN_SUBJECT_COMPOSITION_MUTANT", "Legacy Join subject composition locus", "join source bytes maximum plus one")
  , ("VALIDATION_LEGACY_LENGTH_FRAME_COMPONENT_ORDER_MUTANT", "Legacy Length frame component order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_MANDATORY_FINDING_COMPOSITION_MUTANT", "Legacy Mandatory finding composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_MANDATORY_FINDING_ORDER_MUTANT", "Legacy Mandatory finding order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_PHASE_BLOCKED_FINDING_COMPOSITION_MUTANT", "Legacy Phase blocked finding composition locus", "later phase route")
  , ("VALIDATION_LEGACY_PHASE_PROBLEM_GATE_MUTANT", "Legacy Phase problem gate locus", "later phase route")
  , ("VALIDATION_LEGACY_PREFIX_RETENTION_ORDER_MUTANT", "Legacy Prefix retention order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_PREFIX_THRESHOLD_MUTANT", "Legacy Prefix threshold locus", "binding count maximum plus one")
  , ("VALIDATION_LEGACY_RAW_PROBLEM_FINDING_COMPOSITION_MUTANT", "Legacy RAW problem finding composition locus", "phase width negative")
  , ("VALIDATION_LEGACY_RESOURCE_AGGREGATE_CLASS_DROP_MUTANT", "Legacy Resource aggregate class drop locus", "aggregate bytes maximum plus one")
  , ("VALIDATION_LEGACY_RESOURCE_ANALYSIS_FIELD_ORDER_MUTANT", "Legacy Resource analysis field order locus", "stable ID bytes maximum plus one")
  , ("VALIDATION_LEGACY_RESOURCE_BINDING_CLASS_DROP_MUTANT", "Legacy Resource binding class drop locus", "stable ID bytes maximum plus one")
  , ("VALIDATION_LEGACY_RESOURCE_GUARD_ROUTE_MUTANT", "Legacy Resource guard route locus", "stable ID bytes maximum plus one")
  , ("VALIDATION_LEGACY_RESOURCE_JOIN_CLASS_DROP_MUTANT", "Legacy Resource join class drop locus", "join source bytes maximum plus one")
  , ("VALIDATION_LEGACY_RESULT_BINDING_EXECUTION_BLOCK_COMPOSITION_MUTANT", "Legacy Result binding execution block composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_RESULT_BINDING_OBSERVATION_BLOCK_COMPOSITION_MUTANT", "Legacy Result binding observation block composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_RESULT_FINDING_BLOCK_ORDER_MUTANT", "Legacy Result finding block order locus", "phase width negative")
  , ("VALIDATION_LEGACY_RESULT_JOIN_EXECUTION_BLOCK_COMPOSITION_MUTANT", "Legacy Result join execution block composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_RESULT_JOIN_OBSERVATION_BLOCK_COMPOSITION_MUTANT", "Legacy Result join observation block composition locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_RESULT_OBSERVATION_BLOCK_ORDER_MUTANT", "Legacy Result observation block order locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_SHA256_ALGORITHM_MUTANT", "Legacy SHA256 algorithm locus", "canonical legacy wire")
  , ("VALIDATION_LEGACY_TEXT_LIMIT_ROUTE_MUTANT", "Legacy Text limit route locus", "stable ID bytes maximum plus one")
  , ("VALIDATION_LEGACY_TEXT_PREFIX_RETENTION_ORDER_MUTANT", "Legacy Text prefix retention order locus", "stable ID bytes maximum plus one")
  , ("VALIDATION_LEGACY_TEXT_PREFIX_THRESHOLD_MUTANT", "Legacy Text prefix threshold locus", "stable ID bytes maximum")
  ]

legacySelectorNames :: [String]
legacySelectorNames = [selector | (selector, _, _) <- legacySelectorIntents]

legacySelectorAssignments :: [(String, String)]
legacySelectorAssignments =
  [(selector, target) | (selector, _, target) <- legacySelectorIntents]

runLegacyOracle :: IO ()
runLegacyOracle = do
  caseProblems <- case literalIntegrityProblems of
    [] -> firstFailingCase exactCases
    _ -> pure []
  let problems = literalIntegrityProblems <> caseProblems
  unless (null problems)
    (fail (unlines ("LegacyOracle component diagnostics failed:" : map ("  " <>) problems)))

runLegacySelectorOracle :: String -> IO ()
runLegacySelectorOracle selector = do
  caseProblems <- case literalIntegrityProblems of
    [] | null unaffectedControlProblems && null (selectorProductControlProblems selector) -> case selectorIntentCases selector of
      [(requirement, candidate)] -> runAssignedExactCase selector requirement candidate
      candidates -> pure
        [ "selector intent is not exactly resolvable: selector="
            <> selector <> "; exact-case-count=" <> show (length candidates)
        ]
    _ -> pure []
  let problems = literalIntegrityProblems <> unaffectedControlProblems
        <> selectorProductControlProblems selector <> caseProblems
  unless (null problems)
    (fail (unlines ("LegacyOracle selector diagnostics failed:" : map ("  " <>) problems)))

runLegacyUnaffectedControl :: IO ()
runLegacyUnaffectedControl =
  unless (null unaffectedControlProblems)
    (fail (unlines ("LegacyOracle unaffected controls failed:" : map ("  " <>) unaffectedControlProblems)))

unaffectedControlProblems :: [String]
unaffectedControlProblems =
  [ "independent SHA-256 vector changed"
  | sha256Hex "legacy-oracle-independent-control-v1"
      /= "8ae15a7eb31f0c3c503c12500133d7e494c656093ca05462a6d37954d7aa6562"
  ]
    <> [ "independent UTF-8 length frame changed"
       | lengthText "é" /= ByteString.pack [50, 58, 195, 169]
       ]

-- Every changed-production row has a product observation that must remain
-- exact.  The result-name selector uses the entire remaining carrier as its
-- control; every other atomic selector must preserve the exact public result
-- identity.  This keeps an assigned-case rejection from concealing a compound
-- mutation at a second public locus.
selectorProductControlProblems :: String -> [String]
selectorProductControlProblems selector
  | selector == "VALIDATION_LEGACY_RESULT_NAME_MUTANT" =
      [ "paired product control changed: canonical observation/finding carrier"
      | checkObservations actual /= checkObservations expected
          || checkFindings actual /= checkFindings expected
      ]
  | otherwise =
      [ "paired product control changed: canonical result identity; actual="
          <> show (checkName actual)
      | checkName actual /= "legacy-diagnostic"
      ]
 where
  actual = legacyDiagnostic "00" canonicalBindings canonicalJoins
  expected = exactExpected canonicalCase
  canonicalCase = completeCase "paired product control" "00" canonicalBindings canonicalJoins Nothing False

selectorIntentCases :: String -> [(String, ExactCase)]
selectorIntentCases selector =
  [ (requirement, candidate)
  | (candidateSelector, requirement, target) <- legacySelectorIntents
  , candidateSelector == selector
  , candidate <- exactCases
  , exactLabel candidate == target
  ]

runAssignedExactCase :: String -> String -> ExactCase -> IO [String]
runAssignedExactCase selector requirement candidate =
  pure
    [ "selector=" <> selector <> "; assigned-production-locus=" <> requirement
        <> "; assigned-exact-case=" <> exactLabel candidate <> " changed:\nexpected="
        <> show (exactExpected candidate) <> "\nactual=" <> show actual
    | actual /= exactExpected candidate
    ]
 where
  actual = legacyDiagnostic (exactPhase candidate) (exactBindings candidate) (exactJoins candidate)

firstFailingCase :: [ExactCase] -> IO [String]
firstFailingCase cases = case cases of
  [] -> pure []
  candidate : rest -> do
    problems <- runExactCase candidate
    if null problems then firstFailingCase rest else pure problems

runExactCase :: ExactCase -> IO [String]
runExactCase candidate =
  pure
    [ exactLabel candidate <> " changed:\n"
        <> unlines (checkResultDifferences (exactExpected candidate) actual)
    | actual /= exactExpected candidate
    ]
 where
  actual = legacyDiagnostic (exactPhase candidate) (exactBindings candidate) (exactJoins candidate)

checkResultDifferences :: CheckResult -> CheckResult -> [String]
checkResultDifferences expected actual =
  ["checkName: expected=" <> show (checkName expected) <> "; actual=" <> show (checkName actual) | checkName expected /= checkName actual]
    <> sequenceDifferences "observation" (checkObservations expected) (checkObservations actual)
    <> sequenceDifferences "finding" (checkFindings expected) (checkFindings actual)

sequenceDifferences :: (Eq value, Show value) => String -> [value] -> [value] -> [String]
sequenceDifferences label expected actual =
  [ label <> " count: expected=" <> show (length expected) <> "; actual=" <> show (length actual)
  | length expected /= length actual
  ]
    <> [ label <> " " <> show index <> ": expected=" <> show expectedValue <> "; actual=" <> show actualValue
       | (index, (expectedValue, actualValue)) <- zip [(1 :: Int) ..] (zip expected actual)
       , expectedValue /= actualValue
       ]

literalIntegrityProblems :: [String]
literalIntegrityProblems =
  [ "selector intent cardinality changed: expected=1306; observed=" <> show (length legacySelectorIntents)
  | length legacySelectorIntents /= 1306
  ]
    <> ["duplicate selector intent: " <> value | value <- duplicateStrings legacySelectorNames]
    <> ["duplicate atomic requirement: " <> value | value <- duplicateStrings requirements]
    <> ["duplicate exact-case label: " <> value | value <- duplicateStrings labels]
    <> [ "selector target must occur exactly once: selector=" <> selector
           <> "; target=" <> target <> "; observed=" <> show (occurrenceCount target labels)
       | (selector, _, target) <- legacySelectorIntents
       , occurrenceCount target labels /= 1
       ]
    <> [ "internal projection wire cardinality changed: expected=12; observed="
           <> show (length literalInternalProjectionWires)
       | length literalInternalProjectionWires /= 12
       ]
    <> [ "duplicate internal projection wire key: " <> value
       | value <- duplicateStrings
           [Text.unpack key | (key, _, _) <- literalInternalProjectionWires]
       ]
    <> [ "internal projection wire commitment changed: key=" <> Text.unpack key
           <> "; expected=" <> Text.unpack expectedDigest
           <> "; observed=" <> Text.unpack (literalInternalProjectionDigest key wire)
       | (key, wire, expectedDigest) <- literalInternalProjectionWires
       , literalInternalProjectionDigest key wire /= expectedDigest
       ]
    <> ["canonical binding cardinality changed" | length canonicalBindings /= maximumBindings]
    <> ["canonical join cardinality changed" | length canonicalJoins /= maximumJoins]
    <> ["canonical aggregate byte count changed" | aggregateBytes canonicalBindings canonicalJoins /= maximumAggregateBytes]
    <> ["aggregate maximum fixture changed" | aggregateBytes canonicalBindings canonicalJoins /= maximumAggregateBytes]
    <> ["aggregate maximum-plus-one fixture changed" | aggregateBytes canonicalBindings aggregateExcessJoins /= maximumAggregateBytes + 1]
    <> ["stable ID maximum fixture changed" | textBytes maximumId /= maximumIdBytes]
    <> ["stable ID maximum-plus-one fixture changed" | textBytes excessiveId /= maximumIdBytes + 1]
    <> ["disposition maximum fixture changed" | textBytes maximumDisposition /= maximumDispositionBytes]
    <> ["disposition maximum-plus-one fixture changed" | textBytes excessiveDisposition /= maximumDispositionBytes + 1]
    <> ["owner maximum fixture changed" | textBytes "00" /= maximumOwnerBytes]
    <> ["owner maximum-plus-one fixture changed" | textBytes excessiveOwner /= maximumOwnerBytes + 1]
    <> ["analyzer maximum fixture changed" | textBytes maximumAnalyzer /= maximumAnalyzerBytes]
    <> ["observation maximum fixture changed" | textBytes maximumObservation /= maximumObservationBytes]
    <> ["closure maximum fixture changed" | textBytes maximumClosure /= maximumClosureBytes]
    <> ["reintroduction maximum fixture changed" | textBytes maximumReintroduction /= maximumReintroductionBytes]
    <> ["join source maximum fixture changed" | textBytes maximumJoinSource /= maximumJoinSourceBytes]
    <> ["join target maximum fixture changed" | textBytes maximumJoinTarget /= maximumJoinTargetBytes]
    <> ["two-byte maximum fixture changed" | textBytes (Text.replicate 6 "é") /= maximumIdBytes]
    <> ["two-byte maximum-plus-one fixture changed" | textBytes (Text.replicate 6 "é" <> "a") /= maximumIdBytes + 1]
    <> ["three-byte maximum fixture changed" | textBytes (Text.replicate 4 "€") /= maximumIdBytes]
    <> ["three-byte maximum-plus-one fixture changed" | textBytes (Text.replicate 4 "€" <> "a") /= maximumIdBytes + 1]
    <> ["four-byte maximum fixture changed" | textBytes (Text.replicate 3 "😀") /= maximumIdBytes]
    <> ["four-byte maximum-plus-one fixture changed" | textBytes (Text.replicate 3 "😀" <> "a") /= maximumIdBytes + 1]
 where
  requirements = [requirement | (_, requirement, _) <- legacySelectorIntents]
  labels = map exactLabel exactCases

duplicateStrings :: [String] -> [String]
duplicateStrings = Set.toAscList . snd . foldl remember (Set.empty, Set.empty)
 where
  remember :: (Set String, Set String) -> String -> (Set String, Set String)
  remember (seen, repeated) value
    | Set.member value seen = (seen, Set.insert value repeated)
    | otherwise = (Set.insert value seen, repeated)

occurrenceCount :: String -> [String] -> Int
occurrenceCount expected = go 0
 where
  go count values = case values of
    [] -> count
    value : rest -> go (if value == expected then count + 1 else count) rest

exactCases :: [ExactCase]
exactCases =
  [ completeCase "canonical legacy wire" "00" canonicalBindings canonicalJoins Nothing False
  , completeCase "later phase route" "01" canonicalBindings canonicalJoins Nothing True
  , completeCase "phase bytes maximum" "00" canonicalBindings canonicalJoins Nothing False
  , resourceCase "phase bytes maximum plus one" "000" canonicalBindings canonicalJoins
      "<over-limit>" "unavailable" "unavailable" "phase-byte-limit:2:3"
      (literalResource "LEGACY-PHASE-BYTE-LIMIT" "<candidate-phase>" 2 3)
  , completeCase "binding count maximum" "00" canonicalBindings canonicalJoins Nothing False
  , resourceCase "binding count maximum plus one" "00" (canonicalBindings <> [extraBinding]) canonicalJoins
      "00" "26+" "unavailable" "binding-limit:25:26"
      (literalResource "LEGACY-BINDING-LIMIT" "<bindings>" 25 26)
  , completeCase "join count maximum" "00" canonicalBindings canonicalJoins Nothing False
  , resourceCase "join count maximum plus one" "00" canonicalBindings (canonicalJoins <> [("source-extra", "LTD-SRC-999")])
      "00" "25" "10+" "join-limit:9:10"
      (literalResource "LEGACY-JOIN-LIMIT" "<joins>" 9 10)
  , aggregateFailureCase "stable ID bytes maximum" (mapFirstBinding (setBindingId maximumId) canonicalBindings) canonicalJoins
  , resourceCase "stable ID bytes maximum plus one" "00" (mapFirstBinding (setBindingId excessiveId) canonicalBindings) canonicalJoins
      "00" "25" "9" "id-byte-limit:1:12:13"
      (literalResource "LEGACY-ID-BYTE-LIMIT" "<binding-1>" 12 13)
  , aggregateFailureCase "disposition bytes maximum" (mapFirstBinding (setBindingDisposition maximumDisposition) canonicalBindings) canonicalJoins
  , resourceCase "disposition bytes maximum plus one" "00" (mapFirstBinding (setBindingDisposition excessiveDisposition) canonicalBindings) canonicalJoins
      "00" "25" "9" "disposition-byte-limit:1:8:9"
      (literalResource "LEGACY-DISPOSITION-BYTE-LIMIT" "<binding-1>" 8 9)
  , completeCase "owner bytes maximum" "00" canonicalBindings canonicalJoins Nothing False
  , resourceCase "owner bytes maximum plus one" "00" (mapFirstBinding (setBindingOwner excessiveOwner) canonicalBindings) canonicalJoins
      "00" "25" "9" "owner-byte-limit:1:2:3"
      (literalResource "LEGACY-OWNER-BYTE-LIMIT" "<binding-1>" 2 3)
  , aggregateFailureCase "analyzer bytes maximum" (mapFirstBinding (setBindingAnalyzer maximumAnalyzer) canonicalBindings) canonicalJoins
  , resourceCase "analyzer bytes maximum plus one" "00" (mapFirstBinding (setBindingAnalyzer excessiveAnalyzer) canonicalBindings) canonicalJoins
      "00" "25" "9" "analyzer-byte-limit:1:64:65"
      (literalResource "LEGACY-ANALYZER-BYTE-LIMIT" "<binding-1>" 64 65)
  , aggregateFailureCase "observation bytes maximum" (mapFirstBinding (setBindingObservation maximumObservation) canonicalBindings) canonicalJoins
  , resourceCase "observation bytes maximum plus one" "00" (mapFirstBinding (setBindingObservation excessiveObservation) canonicalBindings) canonicalJoins
      "00" "25" "9" "observation-byte-limit:1:64:65"
      (literalResource "LEGACY-OBSERVATION-BYTE-LIMIT" "<binding-1>" 64 65)
  , aggregateFailureCase "closure bytes maximum" (mapFirstBinding (setBindingClosure maximumClosure) canonicalBindings) canonicalJoins
  , resourceCase "closure bytes maximum plus one" "00" (mapFirstBinding (setBindingClosure excessiveClosure) canonicalBindings) canonicalJoins
      "00" "25" "9" "closure-byte-limit:1:64:65"
      (literalResource "LEGACY-CLOSURE-BYTE-LIMIT" "<binding-1>" 64 65)
  , completeCase "reintroduction count maximum" "00"
      (mapFirstBinding (setBindingReintroduction ["r", "s", "t", "u"]) canonicalBindings) canonicalJoins
      (Just (literalGrammar "LEGACY-BINDING-FIELD" "<binding-1>"
        ("field=reintroduction; expected=" <> Text.pack (show [canonicalFirstReintroduction])
          <> "; observed=" <> Text.pack (show (["r", "s", "t", "u"] :: [Text]))))) False
  , resourceCase "reintroduction count maximum plus one" "00"
      (mapFirstBinding (setBindingReintroduction ["r", "s", "t", "u", "v"]) canonicalBindings) canonicalJoins
      "00" "25" "9" "reintroduction-count-limit:1:4:5"
      (literalResource "LEGACY-REINTRODUCTION-COUNT-LIMIT" "<binding-1>" 4 5)
  , aggregateFailureCase "reintroduction bytes maximum"
      (mapFirstBinding (setBindingReintroduction [maximumReintroduction]) canonicalBindings) canonicalJoins
  , resourceCase "reintroduction bytes maximum plus one" "00"
      (mapFirstBinding (setBindingReintroduction [excessiveReintroduction]) canonicalBindings) canonicalJoins
      "00" "25" "9" "reintroduction-byte-limit:1:1:64:65"
      (literalResource "LEGACY-REINTRODUCTION-BYTE-LIMIT" "<binding-1>-reintroduction-1" 64 65)
  , aggregateFailureCase "join source bytes maximum" canonicalBindings (mapFirstJoin (setJoinSource maximumJoinSource) canonicalJoins)
  , resourceCase "join source bytes maximum plus one" "00" canonicalBindings (mapFirstJoin (setJoinSource excessiveJoinSource) canonicalJoins)
      "00" "25" "9" "join-source-byte-limit:1:32:33"
      (literalResource "LEGACY-JOIN-SOURCE-BYTE-LIMIT" "<join-1>" 32 33)
  , aggregateFailureCase "join target bytes maximum" canonicalBindings (mapFirstJoin (setJoinTarget maximumJoinTarget) canonicalJoins)
  , resourceCase "join target bytes maximum plus one" "00" canonicalBindings (mapFirstJoin (setJoinTarget excessiveJoinTarget) canonicalJoins)
      "00" "25" "9" "join-target-byte-limit:1:12:13"
      (literalResource "LEGACY-JOIN-TARGET-BYTE-LIMIT" "<join-1>" 12 13)
  , completeCase "aggregate bytes maximum" "00" canonicalBindings canonicalJoins Nothing False
  , aggregateFailureCase "aggregate bytes maximum plus one" canonicalBindings aggregateExcessJoins
  , completeCase "phase width negative" "0" canonicalBindings canonicalJoins
      (Just (literalGrammar "LEGACY-PHASE-WIDTH" "<candidate-phase>" "expected exactly two ASCII decimal characters")) False
  , completeCase "phase alphabet negative" "0a" canonicalBindings canonicalJoins
      (Just (literalGrammar "LEGACY-PHASE-ALPHABET" "<candidate-phase>" "expected ASCII decimal characters only")) False
  , completeCase "phase alphabet lower negative" "0/" canonicalBindings canonicalJoins
      (Just (literalGrammar "LEGACY-PHASE-ALPHABET" "<candidate-phase>" "expected ASCII decimal characters only")) False
  , completeCase "phase range maximum plus one" "96" canonicalBindings canonicalJoins
      (Just (literalGrammar "LEGACY-PHASE-RANGE" "<candidate-phase>" "expected a phase in the closed range 00 through 95")) False
  , completeCase "binding cardinality negative" "00" (take 24 canonicalBindings) canonicalJoins
      (Just (literalGrammar "LEGACY-BINDING-CARDINALITY" "<bindings>" "expected=25; observed=24")) False
  , completeCase "binding duplicate negative" "00" duplicateBindings canonicalJoins
      (Just (literalGrammar "LEGACY-BINDING-DUPLICATE" "LTD-SEED-001" "stable ID occurs more than once")) False
  , completeCase "binding unknown negative" "00" unknownBindings canonicalJoins
      (Just (literalGrammar "LEGACY-BINDING-UNKNOWN" "LTD-SEED-999" "stable ID is outside the closed binding universe")) False
  , completeCase "binding order negative" "00" outOfOrderBindings canonicalJoins
      (Just (literalGrammar "LEGACY-BINDING-ORDER" "<bindings>" ("observed=" <> Text.pack (show (map bindingId outOfOrderBindings))))) False
  , completeCase "binding disposition negative" "00" (mapFirstBinding (setBindingDisposition "Activx") canonicalBindings) canonicalJoins
      (Just (literalField "disposition" "Active" "Activx")) False
  , completeCase "binding owner negative" "00" (mapFirstBinding (setBindingOwner "0x") canonicalBindings) canonicalJoins
      (Just (literalField "owner" "00" "0x")) False
  , completeCase "binding analyzer negative" "00" (mapFirstBinding (setBindingAnalyzer "complete-source-grammax") canonicalBindings) canonicalJoins
      (Just (literalField "analyzer" "complete-source-grammar" "complete-source-grammax")) False
  , completeCase "binding observation negative" "00" (mapFirstBinding (setBindingObservation "complete-source-snapshox") canonicalBindings) canonicalJoins
      (Just (literalField "observation" "complete-source-snapshot" "complete-source-snapshox")) False
  , completeCase "binding closure negative" "00" (mapFirstBinding (setBindingClosure "complete-source-grammax") canonicalBindings) canonicalJoins
      (Just (literalField "closure" "complete-source-grammar" "complete-source-grammax")) False
  , completeCase "binding reintroduction negative" "00"
      (mapFirstBinding (setBindingReintroduction ["reject-disguised-or-concealed-sourcx"]) canonicalBindings) canonicalJoins
      (Just (literalGrammar "LEGACY-BINDING-FIELD" "<binding-1>"
        ("field=reintroduction; expected=" <> Text.pack (show [canonicalFirstReintroduction])
          <> "; observed=" <> Text.pack (show (["reject-disguised-or-concealed-sourcx"] :: [Text]))))) False
  , completeCase "join cardinality negative" "00" canonicalBindings (take 8 canonicalJoins)
      (Just (literalGrammar "LEGACY-JOIN-CARDINALITY" "<joins>" "expected=9; observed=8")) False
  , completeCase "join duplicate negative" "00" canonicalBindings duplicateJoins
      (Just (literalGrammar "LEGACY-JOIN-DUPLICATE" "source-test" "source family occurs more than once")) False
  , completeCase "join unknown negative" "00" canonicalBindings unknownJoins
      (Just (literalGrammar "LEGACY-JOIN-UNKNOWN" "source-vendox" "source family is outside the closed source-debt universe")) False
  , completeCase "join order negative" "00" canonicalBindings outOfOrderJoins
      (Just (literalGrammar "LEGACY-JOIN-ORDER" "<joins>" ("observed=" <> Text.pack (show (map fst outOfOrderJoins))))) False
  , completeCase "join target negative" "00" canonicalBindings (mapFirstJoin (setJoinTarget "LTD-SRC-00x") canonicalJoins)
      (Just (literalGrammar "LEGACY-JOIN-TARGET" "<join-1>"
        "source=source-tools; expected=LTD-SRC-001; observed=LTD-SRC-00x")) False
  , completeCase "phase range maximum" "95" canonicalBindings canonicalJoins Nothing True
  , aggregateFailureCase "stable ID two-byte maximum"
      (mapFirstBinding (setBindingId (Text.replicate 6 "é")) canonicalBindings) canonicalJoins
  , resourceCase "stable ID two-byte maximum plus one" "00"
      (mapFirstBinding (setBindingId (Text.replicate 6 "é" <> "a")) canonicalBindings) canonicalJoins
      "00" "25" "9" "id-byte-limit:1:12:13"
      (literalResource "LEGACY-ID-BYTE-LIMIT" "<binding-1>" 12 13)
  , aggregateFailureCase "stable ID three-byte maximum"
      (mapFirstBinding (setBindingId (Text.replicate 4 "€")) canonicalBindings) canonicalJoins
  , resourceCase "stable ID three-byte maximum plus one" "00"
      (mapFirstBinding (setBindingId (Text.replicate 4 "€" <> "a")) canonicalBindings) canonicalJoins
      "00" "25" "9" "id-byte-limit:1:12:13"
      (literalResource "LEGACY-ID-BYTE-LIMIT" "<binding-1>" 12 13)
  , aggregateFailureCase "stable ID four-byte maximum"
      (mapFirstBinding (setBindingId (Text.replicate 3 "😀")) canonicalBindings) canonicalJoins
  , resourceCase "stable ID four-byte maximum plus one" "00"
      (mapFirstBinding (setBindingId (Text.replicate 3 "😀" <> "a")) canonicalBindings) canonicalJoins
      "00" "25" "9" "id-byte-limit:1:12:13"
      (literalResource "LEGACY-ID-BYTE-LIMIT" "<binding-1>" 12 13)
  , resourceCase "resource binding row precedence" "00" resourceBindingRowPrecedence canonicalJoins
      "00" "25" "9" "id-byte-limit:1:12:13"
      (literalResource "LEGACY-ID-BYTE-LIMIT" "<binding-1>" 12 13)
  , resourceCase "resource join row precedence" "00" canonicalBindings resourceJoinRowPrecedence
      "00" "25" "9" "join-source-byte-limit:1:32:33"
      (literalResource "LEGACY-JOIN-SOURCE-BYTE-LIMIT" "<join-1>" 32 33)
  , resourceCase "resource class precedence" "00" resourceBindingClassPrecedence resourceJoinClassPrecedence
      "00" "25" "9" "id-byte-limit:1:12:13"
      (literalResource "LEGACY-ID-BYTE-LIMIT" "<binding-1>" 12 13)
  , resourceCase "resource binding field precedence" "00" resourceBindingFieldPrecedence canonicalJoins
      "00" "25" "9" "id-byte-limit:1:12:13"
      (literalResource "LEGACY-ID-BYTE-LIMIT" "<binding-1>" 12 13)
  , resourceCase "resource join field precedence" "00" canonicalBindings resourceJoinFieldPrecedence
      "00" "25" "9" "join-source-byte-limit:1:32:33"
      (literalResource "LEGACY-JOIN-SOURCE-BYTE-LIMIT" "<join-1>" 32 33)
  , completeCase "grammar phase precedence" "a" canonicalBindings canonicalJoins
      (Just (literalGrammar "LEGACY-PHASE-WIDTH" "<candidate-phase>" "expected exactly two ASCII decimal characters")) False
  , completeCase "grammar class precedence" "a" (take 24 canonicalBindings) canonicalJoins
      (Just (literalGrammar "LEGACY-PHASE-WIDTH" "<candidate-phase>" "expected exactly two ASCII decimal characters")) False
  , completeCase "binding field precedence" "00" bindingFieldPrecedence canonicalJoins
      (Just (literalField "disposition" "Active" "Activx")) False
  , completeCase "binding row precedence" "00" bindingRowPrecedence canonicalJoins
      (Just (literalField "disposition" "Active" "Activx")) False
  , completeCase "binding duplicate search precedence" "00" bindingDuplicateSearchPrecedence canonicalJoins
      (Just (literalGrammar "LEGACY-BINDING-DUPLICATE" "LTD-SRC-000" "stable ID occurs more than once")) False
  , completeCase "binding unknown search precedence" "00" bindingUnknownSearchPrecedence canonicalJoins
      (Just (literalGrammar "LEGACY-BINDING-UNKNOWN" "UNKNOWN-A" "stable ID is outside the closed binding universe")) False
  , completeCase "join row precedence" "00" canonicalBindings joinRowPrecedence
      (Just (literalGrammar "LEGACY-JOIN-TARGET" "<join-1>"
        "source=source-tools; expected=LTD-SRC-001; observed=LTD-SRC-00x")) False
  , completeCase "join duplicate search precedence" "00" canonicalBindings joinDuplicateSearchPrecedence
      (Just (literalGrammar "LEGACY-JOIN-DUPLICATE" "source-tools" "source family occurs more than once")) False
  , completeCase "join unknown search precedence" "00" canonicalBindings joinUnknownSearchPrecedence
      (Just (literalGrammar "LEGACY-JOIN-UNKNOWN" "unknown-one1" "source family is outside the closed source-debt universe")) False
  ]

completeCase :: String -> Text -> [RawBinding] -> [RawJoin] -> Maybe LiteralProblem -> Bool -> ExactCase
completeCase label phase bindings joins problem phaseBlocked =
  ExactCase label phase bindings joins
    (expectedResult phase bindings joins phase (Text.pack (show (length bindings)))
      (Text.pack (show (length joins))) CompleteCommitment problem phaseBlocked)

resourceCase
  :: String -> Text -> [RawBinding] -> [RawJoin] -> Text -> Text -> Text
  -> Text -> LiteralProblem -> ExactCase
resourceCase label phase bindings joins safePhase bindingCount joinCount problemTag problem =
  ExactCase label phase bindings joins
    (expectedResult phase bindings joins safePhase bindingCount joinCount
      (BoundedCommitment problemTag) (Just problem) False)

aggregateFailureCase :: String -> [RawBinding] -> [RawJoin] -> ExactCase
aggregateFailureCase label bindings joins =
  resourceCase label "00" bindings joins "00" "25" "9"
    ("aggregate-byte-limit:2706:" <> Text.pack (show actual))
    (literalResource "LEGACY-AGGREGATE-BYTE-LIMIT" "<legacy-input>" 2706 actual)
 where
  actual = aggregateBytes bindings joins

expectedResult
  :: Text -> [RawBinding] -> [RawJoin] -> Text -> Text -> Text
  -> LiteralCommitment -> Maybe LiteralProblem -> Bool -> CheckResult
expectedResult phase bindings joins safePhase bindingCount joinCount commitment problem phaseBlocked =
  CheckResult
    { checkName = "legacy-diagnostic"
    , checkObservations =
        [ Observation "legacy.input-commitment.kind" commitmentKind
        , Observation "legacy.input-commitment.sha256" commitmentDigest
        , Observation "legacy.input.candidate-phase" safePhase
        , Observation "legacy.input.binding-count" bindingCount
        , Observation "legacy.input.join-count" joinCount
        , Observation "legacy.derived.selected-binding-count" "25"
        , Observation "legacy.derived.selected-join-count" "9"
        , Observation "legacy.diagnostic-status" "refused"
        ]
          <> literalInternalProjection
          <> [Observation ("legacy.binding." <> Text.pack (show ordinal)) (renderBinding binding)
             | (ordinal, binding) <- zip [(1 :: Int) ..] canonicalBindings]
          <> [Observation ("legacy.join." <> Text.pack (show ordinal)) (source <> "->" <> target)
             | (ordinal, (source, target)) <- zip [(1 :: Int) ..] canonicalJoins]
    , checkFindings =
        mandatoryFindings commitmentDetail
          <> maybe [] (pure . renderProblem commitmentDetail) problem
          <> [ Finding "LEGACY-BINDING-EXECUTION-UNAVAILABLE" (Text.unpack identifier)
                 ("the package-hidden analyzer has not produced snapshot-bound evidence for owner="
                   <> owner <> "; analyzer=" <> analyzer <> "; observation=" <> observed
                   <> "; closure=" <> closed <> commitmentDetail)
             | (identifier, _, owner, analyzer, observed, closed, _) <- canonicalBindings]
          <> [ Finding "LEGACY-SOURCE-JOIN-UNAVAILABLE" (Text.unpack source)
                 ("the package-hidden source-debt evidence join to " <> target
                   <> " has not executed" <> commitmentDetail)
             | (source, target) <- canonicalJoins]
          <> [Finding "LEGACY-PHASE-BLOCKED" ("phase-" <> Text.unpack safePhase)
                ("every later phase requires its predecessor's gate pass" <> commitmentDetail)
             | phaseBlocked]
    }
 where
  (commitmentKind, commitmentDigest) = case commitment of
    CompleteCommitment -> ("complete-input", completeDigest phase bindings joins)
    BoundedCommitment tag -> ("bounded-preflight-refusal", boundedDigest phase bindings joins tag)
  commitmentDetail =
    "; input-commitment-kind=" <> commitmentKind
      <> case commitment of
        CompleteCommitment -> "; input-sha256=" <> commitmentDigest
        BoundedCommitment _ -> "; bounded-prefix-sha256=" <> commitmentDigest

-- These oracle-owned literals restate the complete standard-value wires of
-- the package-hidden parser, lifecycle, register, dispatch, and gate
-- seams.  Their independently recomputed commitments are the only opaque
-- observations admitted at the refusal-only public boundary.
literalInternalProjection :: [Observation]
literalInternalProjection =
  [ Observation key expectedDigest
  | (key, _, expectedDigest) <- literalInternalProjectionWires
  ]

literalInternalProjectionWires :: [(Text, Text, Text)]
literalInternalProjectionWires =
  [ ("legacy.internal.parser-wire.sha256", "11:LTD-DOC-00111:LTD-DOC-00112:LTD-HOST-00112:LTD-HOST-00112:LTD-HOST-00212:LTD-HOST-00211:LTD-IMG-00111:LTD-IMG-00112:LTD-META-00112:LTD-META-00112:LTD-NAME-00112:LTD-NAME-00111:LTD-RUN-00111:LTD-RUN-00112:LTD-SEED-00112:LTD-SEED-00112:LTD-SEED-00212:LTD-SEED-00211:LTD-SRC-00011:LTD-SRC-00011:LTD-SRC-00111:LTD-SRC-00111:LTD-SRC-00211:LTD-SRC-00211:LTD-SRC-00311:LTD-SRC-00311:LTD-SRC-00411:LTD-SRC-00411:LTD-SRC-00511:LTD-SRC-00511:LTD-SRC-00611:LTD-SRC-00611:LTD-SRC-00711:LTD-SRC-00711:LTD-SRC-00811:LTD-SRC-00811:LTD-SRC-00911:LTD-SRC-00911:LTD-VAL-00111:LTD-VAL-00111:LTD-VAL-00211:LTD-VAL-00211:LTD-VAL-00311:LTD-VAL-00311:LTD-VAL-00411:LTD-VAL-00411:LTD-VAL-00511:LTD-VAL-00511:LTD-VAL-00611:LTD-VAL-00611:LTD-SRC-00x8:rejected", "d5befad1cf63cb3a2a253d3a886f4b6e57509019d8716ff70103d0052f652e76")
  , ("legacy.internal.inverse-source-debt-wire.sha256", "11:LTD-SRC-0004:none11:LTD-SRC-00112:source-tools11:LTD-SRC-00212:source-dhall11:LTD-SRC-00312:source-proto11:LTD-SRC-0049:source-ui11:LTD-SRC-00513:source-pulumi11:LTD-SRC-00611:source-test11:LTD-SRC-00712:source-probe11:LTD-SRC-0089:source-pb11:LTD-SRC-00913:source-vendor12:LTD-META-0014:none11:LTD-VAL-0014:none11:LTD-VAL-0024:none11:LTD-VAL-0034:none11:LTD-VAL-0044:none11:LTD-VAL-0054:none11:LTD-VAL-0064:none11:LTD-DOC-0014:none12:LTD-NAME-0014:none12:LTD-HOST-0014:none12:LTD-HOST-0024:none11:LTD-IMG-0014:none11:LTD-RUN-0014:none12:LTD-SEED-0014:none12:LTD-SEED-0024:none", "d8e149f5b72000bcfe793e5df77f32a0f13857c843ed0d5ef8a9ed7996f04274")
  , ("legacy.internal.route-universes-wire.sha256", "111:source-tools,source-dhall,source-proto,source-ui,source-pulumi,source-test,source-probe,source-pb,source-vendor185:LTD-META-001,LTD-VAL-001,LTD-VAL-002,LTD-VAL-003,LTD-VAL-004,LTD-VAL-005,LTD-VAL-006,LTD-DOC-001,LTD-NAME-001,LTD-HOST-001,LTD-HOST-002,LTD-IMG-001,LTD-RUN-001,LTD-SEED-001,LTD-SEED-00231:invalid-static-phase-fallback=0", "37a120793b574c0dd20a5a641d4a26850f8f1a0ed451e615d1e54d6a518b31cc")
  , ("legacy.internal.lifecycle-wire.sha256", "18:before-unavailable239:14:legacy-binding1:126:legacy.binding.LTD-SRC-00130:unavailable:AnalyzeSourceTools1:131:LEGACY-DIAGNOSTIC-NOT-CANDIDATE26:Amoebius.Validation.Legacy88:caller-supplied legacy observations are diagnostic model inputs, never analyzer evidence14:at-unavailable409:14:legacy-binding1:126:legacy.binding.LTD-SRC-00130:unavailable:AnalyzeSourceTools1:227:LEGACY-ANALYZER-UNAVAILABLE38:Amoebius.Validation.Legacy/LTD-SRC-00196:LTD-SRC-001 requires AnalyzeSourceTools at owner Phase 47; no typed raw observation was supplied31:LEGACY-DIAGNOSTIC-NOT-CANDIDATE26:Amoebius.Validation.Legacy88:caller-supplied legacy observations are diagnostic model inputs, never analyzer evidence17:after-unavailable409:14:legacy-binding1:126:legacy.binding.LTD-SRC-00130:unavailable:AnalyzeSourceTools1:227:LEGACY-ANALYZER-UNAVAILABLE38:Amoebius.Validation.Legacy/LTD-SRC-00196:LTD-SRC-001 requires AnalyzeSourceTools at owner Phase 47; no typed raw observation was supplied31:LEGACY-DIAGNOSTIC-NOT-CANDIDATE26:Amoebius.Validation.Legacy88:caller-supplied legacy observations are diagnostic model inputs, never analyzer evidence11:before-zero442:14:legacy-binding1:126:legacy.binding.LTD-SRC-00132:analyzer=AnalyzeSourceTools:zero1:229:LEGACY-ACTIVE-FINDING-MISSING38:Amoebius.Validation.Legacy/LTD-SRC-001124:LTD-SRC-001 is Active before owner Phase 47 but its observer reports zero; the exact later-owned finding is stale or missing31:LEGACY-DIAGNOSTIC-NOT-CANDIDATE26:Amoebius.Validation.Legacy88:caller-supplied legacy observations are diagnostic model inputs, never analyzer evidence7:at-zero241:14:legacy-binding1:126:legacy.binding.LTD-SRC-00132:analyzer=AnalyzeSourceTools:zero1:131:LEGACY-DIAGNOSTIC-NOT-CANDIDATE26:Amoebius.Validation.Legacy88:caller-supplied legacy observations are diagnostic model inputs, never analyzer evidence10:after-zero472:14:legacy-binding1:126:legacy.binding.LTD-SRC-00132:analyzer=AnalyzeSourceTools:zero1:235:LEGACY-ACTIVE-TRANSITION-UNRECORDED38:Amoebius.Validation.Legacy/LTD-SRC-001148:LTD-SRC-001 is still Active after owner Phase 47; the owning candidate's zero observation did not receive a compiled post-pass retirement transition31:LEGACY-DIAGNOSTIC-NOT-CANDIDATE26:Amoebius.Validation.Legacy88:caller-supplied legacy observations are diagnostic model inputs, never analyzer evidence11:before-open308:14:legacy-binding1:126:legacy.binding.LTD-SRC-00199:analyzer=AnalyzeSourceTools:open:1:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa1:131:LEGACY-DIAGNOSTIC-NOT-CANDIDATE26:Amoebius.Validation.Legacy88:caller-supplied legacy observations are diagnostic model inputs, never analyzer evidence7:at-open495:14:legacy-binding1:126:legacy.binding.LTD-SRC-00199:analyzer=AnalyzeSourceTools:open:1:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa1:216:LEGACY-OWNER-DUE38:Amoebius.Validation.Legacy/LTD-SRC-001123:LTD-SRC-001 remains open at owner Phase 47; count=1 digest=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa31:LEGACY-DIAGNOSTIC-NOT-CANDIDATE26:Amoebius.Validation.Legacy88:caller-supplied legacy observations are diagnostic model inputs, never analyzer evidence7:refused357:14:legacy-binding1:126:legacy.binding.LTD-SRC-00149:analyzer=AnalyzeSourceTools:refused:owner refused1:226:LEGACY-OBSERVATION-REFUSED38:Amoebius.Validation.Legacy/LTD-SRC-00126:LTD-SRC-001: owner refused31:LEGACY-DIAGNOSTIC-NOT-CANDIDATE26:Amoebius.Validation.Legacy88:caller-supplied legacy observations are diagnostic model inputs, never analyzer evidence17:analyzer-mismatch417:14:legacy-binding1:126:legacy.binding.LTD-SRC-00132:analyzer=AnalyzeSourceDhall:zero1:236:LEGACY-OBSERVATION-ANALYZER-MISMATCH38:Amoebius.Validation.Legacy/LTD-SRC-00193:LTD-SRC-001 requires AnalyzeSourceTools but the supplied observation names AnalyzeSourceDhall31:LEGACY-DIAGNOSTIC-NOT-CANDIDATE26:Amoebius.Validation.Legacy88:caller-supplied legacy observations are diagnostic model inputs, never analyzer evidence15:open-zero-count486:14:legacy-binding1:126:legacy.binding.LTD-SRC-00199:analyzer=AnalyzeSourceTools:open:0:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa1:228:LEGACY-OBSERVATION-MALFORMED38:Amoebius.Validation.Legacy/LTD-SRC-001102:LTD-SRC-001 open observation requires a positive count and a 64-character lowercase hexadecimal digest31:LEGACY-DIAGNOSTIC-NOT-CANDIDATE26:Amoebius.Validation.Legacy88:caller-supplied legacy observations are diagnostic model inputs, never analyzer evidence17:open-short-digest425:14:legacy-binding1:126:legacy.binding.LTD-SRC-00138:analyzer=AnalyzeSourceTools:open:1:abc1:228:LEGACY-OBSERVATION-MALFORMED38:Amoebius.Validation.Legacy/LTD-SRC-001102:LTD-SRC-001 open observation requires a positive count and a 64-character lowercase hexadecimal digest31:LEGACY-DIAGNOSTIC-NOT-CANDIDATE26:Amoebius.Validation.Legacy88:caller-supplied legacy observations are diagnostic model inputs, never analyzer evidence21:open-uppercase-digest486:14:legacy-binding1:126:legacy.binding.LTD-SRC-00199:analyzer=AnalyzeSourceTools:open:1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA1:228:LEGACY-OBSERVATION-MALFORMED38:Amoebius.Validation.Legacy/LTD-SRC-001102:LTD-SRC-001 open observation requires a positive count and a 64-character lowercase hexadecimal digest31:LEGACY-DIAGNOSTIC-NOT-CANDIDATE26:Amoebius.Validation.Legacy88:caller-supplied legacy observations are diagnostic model inputs, never analyzer evidence17:open-mixed-digest486:14:legacy-binding1:126:legacy.binding.LTD-SRC-00199:analyzer=AnalyzeSourceTools:open:1:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaag1:228:LEGACY-OBSERVATION-MALFORMED38:Amoebius.Validation.Legacy/LTD-SRC-001102:LTD-SRC-001 open observation requires a positive count and a 64-character lowercase hexadecimal digest31:LEGACY-DIAGNOSTIC-NOT-CANDIDATE26:Amoebius.Validation.Legacy88:caller-supplied legacy observations are diagnostic model inputs, never analyzer evidence23:open-digit-lower-digest486:14:legacy-binding1:126:legacy.binding.LTD-SRC-00199:analyzer=AnalyzeSourceTools:open:1:////////////////////////////////////////////////////////////////1:228:LEGACY-OBSERVATION-MALFORMED38:Amoebius.Validation.Legacy/LTD-SRC-001102:LTD-SRC-001 open observation requires a positive count and a 64-character lowercase hexadecimal digest31:LEGACY-DIAGNOSTIC-NOT-CANDIDATE26:Amoebius.Validation.Legacy88:caller-supplied legacy observations are diagnostic model inputs, never analyzer evidence23:open-digit-upper-digest486:14:legacy-binding1:126:legacy.binding.LTD-SRC-00199:analyzer=AnalyzeSourceTools:open:1:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::1:228:LEGACY-OBSERVATION-MALFORMED38:Amoebius.Validation.Legacy/LTD-SRC-001102:LTD-SRC-001 open observation requires a positive count and a 64-character lowercase hexadecimal digest31:LEGACY-DIAGNOSTIC-NOT-CANDIDATE26:Amoebius.Validation.Legacy88:caller-supplied legacy observations are diagnostic model inputs, never analyzer evidence23:open-alpha-lower-digest486:14:legacy-binding1:126:legacy.binding.LTD-SRC-00199:analyzer=AnalyzeSourceTools:open:1:````````````````````````````````````````````````````````````````1:228:LEGACY-OBSERVATION-MALFORMED38:Amoebius.Validation.Legacy/LTD-SRC-001102:LTD-SRC-001 open observation requires a positive count and a 64-character lowercase hexadecimal digest31:LEGACY-DIAGNOSTIC-NOT-CANDIDATE26:Amoebius.Validation.Legacy88:caller-supplied legacy observations are diagnostic model inputs, never analyzer evidence23:open-alpha-upper-digest486:14:legacy-binding1:126:legacy.binding.LTD-SRC-00199:analyzer=AnalyzeSourceTools:open:1:gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg1:228:LEGACY-OBSERVATION-MALFORMED38:Amoebius.Validation.Legacy/LTD-SRC-001102:LTD-SRC-001 open observation requires a positive count and a 64-character lowercase hexadecimal digest31:LEGACY-DIAGNOSTIC-NOT-CANDIDATE26:Amoebius.Validation.Legacy88:caller-supplied legacy observations are diagnostic model inputs, never analyzer evidence13:refused-empty377:14:legacy-binding1:126:legacy.binding.LTD-SRC-00136:analyzer=AnalyzeSourceTools:refused:1:228:LEGACY-OBSERVATION-MALFORMED38:Amoebius.Validation.Legacy/LTD-SRC-00157:LTD-SRC-001 refused observation requires non-empty detail31:LEGACY-DIAGNOSTIC-NOT-CANDIDATE26:Amoebius.Validation.Legacy88:caller-supplied legacy observations are diagnostic model inputs, never analyzer evidence", "8ef94300888f5e216a146747f6e1a2577b18f27a3ec52b1df64faa3c9c177b16")
  , ("legacy.internal.inventory-wire.sha256", "5:empty6587:16:legacy-inventory2:2829:legacy.haskell-owner-bindings370:LTD-DOC-001@27,LTD-HOST-001@51,LTD-HOST-002@51,LTD-IMG-001@56,LTD-META-001@2,LTD-NAME-001@2,LTD-RUN-001@55,LTD-SEED-001@91,LTD-SEED-002@93,LTD-SRC-000@0,LTD-SRC-001@47,LTD-SRC-002@25,LTD-SRC-003@26,LTD-SRC-004@46,LTD-SRC-005@47,LTD-SRC-006@47,LTD-SRC-007@1,LTD-SRC-008@0,LTD-SRC-009@1,LTD-VAL-001@0,LTD-VAL-002@0,LTD-VAL-003@0,LTD-VAL-004@0,LTD-VAL-005@49,LTD-VAL-006@4724:legacy.binding-contracts3244:LTD-SRC-000@0:LegacyActive:AnalyzeCompleteSourceGrammar:ObserveCompleteSourceSnapshot:CloseCompleteSourceGrammar:RejectDisguisedOrConcealedSource :| [],LTD-SRC-001@47:LegacyActive:AnalyzeSourceTools:ObserveSourceTools:CloseSourceTools:RejectTrackedToolsSource :| [],LTD-SRC-002@25:LegacyActive:AnalyzeSourceDhall:ObserveSourceDhall:CloseSourceDhall:RejectTrackedDhallOrTsv :| [],LTD-SRC-003@26:LegacyActive:AnalyzeSourceProto:ObserveSourceProto:CloseSourceProto:RejectTrackedProto :| [],LTD-SRC-004@46:LegacyActive:AnalyzeSourceUi:ObserveSourceUi:CloseSourceUi:RejectTrackedUiSource :| [],LTD-SRC-005@47:LegacyActive:AnalyzeSourcePulumi:ObserveSourcePulumi:CloseSourcePulumi:RejectTrackedPulumiSource :| [],LTD-SRC-006@47:LegacyActive:AnalyzeSourceTest:ObserveSourceTest:CloseSourceTest:RejectTrackedBehavioralTestInput :| [],LTD-SRC-007@1:LegacyActive:AnalyzeSourceProbe:ObserveSourceProbe:CloseSourceProbe:RejectTrackedProbeDebt :| [],LTD-SRC-008@0:LegacyActive:AnalyzeSourcePb:ObserveSourcePb:CloseSourcePb:RejectWidenedPbBehavior :| [],LTD-SRC-009@1:LegacyActive:AnalyzeSourceVendor:ObserveSourceVendor:CloseSourceVendor:RejectTopLevelVendorDebt :| [],LTD-META-001@2:LegacyActive:AnalyzeRetiredIgnoreRules:ObserveParsedIgnoreGrammars:CloseRetiredIgnoreRules:RejectRetiredIgnoreRule :| [],LTD-VAL-001@0:LegacyActive:AnalyzeValidationProtocol:ObserveValidationGateGraph:CloseValidationProtocol:RejectNonHaskellValidationVerdict :| [],LTD-VAL-002@0:LegacyActive:AnalyzePhaseContracts:ObserveTypedPhaseContractBinding:ClosePhaseContracts:RejectUnboundPhaseContract :| [],LTD-VAL-003@0:LegacyActive:AnalyzeStatusEvidence:ObserveStatusEvidenceProjection:CloseStatusEvidence:RejectForgedStatusEvidence :| [],LTD-VAL-004@0:LegacyActive:AnalyzeGateCompletion:ObserveGateCompletionResult:CloseGateCompletion:RejectIncompleteGate :| [],LTD-VAL-005@49:LegacyActive:AnalyzeHardwareFreeDsl:ObserveHardwareFreeDslTrace:CloseHardwareFreeDsl:RejectHardwareBeforeDslGatePass :| [],LTD-VAL-006@47:LegacyActive:AnalyzeRunInputClosure:ObserveRunInputProvenance:CloseRunInputClosure:RejectAmbientOrStaleRunInput :| [],LTD-DOC-001@27:LegacyActive:AnalyzeBehavioralDocumentConsumers:ObserveDocumentConsumerGraph:CloseBehavioralDocumentConsumers:RejectBehavioralMarkdownConsumer :| [],LTD-NAME-001@2:LegacyActive:AnalyzePhaseOrdinalNames:ObserveRuntimeIdentityGraph:ClosePhaseOrdinalNames:RejectRuntimePhaseOrdinal :| [],LTD-HOST-001@51:LegacyActive:AnalyzeHostEnsure:ObserveHostEnsureCallGraph:CloseHostEnsure:RejectBypassedHostEnsure :| [],LTD-HOST-002@51:LegacyActive:AnalyzeAmbientHostPaths:ObserveHostPathEffectGraph:CloseAmbientHostPaths:RejectAmbientHostPath :| [],LTD-IMG-001@56:LegacyActive:AnalyzeNaturalArchitectureImages:ObserveImagePlanAndBinfmt:CloseNaturalArchitectureImages:RejectCrossArchitectureImagePlan :| [],LTD-RUN-001@55:LegacyActive:AnalyzeExecutableIdentity:ObserveCabalExecutableGraph:CloseExecutableIdentity:RejectSecondExecutableIdentity :| [],LTD-SEED-001@91:LegacyActive:AnalyzeInfernixSeedDependency:ObserveInfernixDependencyGraph:CloseInfernixSeedDependency:RejectInfernixSeedDependency :| [],LTD-SEED-002@93:LegacyActive:AnalyzeJitMlSeedDependency:ObserveJitMlDependencyGraph:CloseJitMlSeedDependency:RejectJitMlSeedDependency :| []22:legacy.candidate-phase1:026:legacy.binding.LTD-SRC-00040:unavailable:AnalyzeCompleteSourceGrammar26:legacy.binding.LTD-SRC-00130:unavailable:AnalyzeSourceTools26:legacy.binding.LTD-SRC-00230:unavailable:AnalyzeSourceDhall26:legacy.binding.LTD-SRC-00330:unavailable:AnalyzeSourceProto26:legacy.binding.LTD-SRC-00427:unavailable:AnalyzeSourceUi26:legacy.binding.LTD-SRC-00531:unavailable:AnalyzeSourcePulumi26:legacy.binding.LTD-SRC-00629:unavailable:AnalyzeSourceTest26:legacy.binding.LTD-SRC-00730:unavailable:AnalyzeSourceProbe26:legacy.binding.LTD-SRC-00827:unavailable:AnalyzeSourcePb26:legacy.binding.LTD-SRC-00931:unavailable:AnalyzeSourceVendor27:legacy.binding.LTD-META-00137:unavailable:AnalyzeRetiredIgnoreRules26:legacy.binding.LTD-VAL-00137:unavailable:AnalyzeValidationProtocol26:legacy.binding.LTD-VAL-00233:unavailable:AnalyzePhaseContracts26:legacy.binding.LTD-VAL-00333:unavailable:AnalyzeStatusEvidence26:legacy.binding.LTD-VAL-00433:unavailable:AnalyzeGateCompletion26:legacy.binding.LTD-VAL-00534:unavailable:AnalyzeHardwareFreeDsl26:legacy.binding.LTD-VAL-00634:unavailable:AnalyzeRunInputClosure26:legacy.binding.LTD-DOC-00146:unavailable:AnalyzeBehavioralDocumentConsumers27:legacy.binding.LTD-NAME-00136:unavailable:AnalyzePhaseOrdinalNames27:legacy.binding.LTD-HOST-00129:unavailable:AnalyzeHostEnsure27:legacy.binding.LTD-HOST-00235:unavailable:AnalyzeAmbientHostPaths26:legacy.binding.LTD-IMG-00144:unavailable:AnalyzeNaturalArchitectureImages26:legacy.binding.LTD-RUN-00137:unavailable:AnalyzeExecutableIdentity27:legacy.binding.LTD-SEED-00141:unavailable:AnalyzeInfernixSeedDependency27:legacy.binding.LTD-SEED-00238:unavailable:AnalyzeJitMlSeedDependency1:727:LEGACY-ANALYZER-UNAVAILABLE38:Amoebius.Validation.Legacy/LTD-SRC-000105:LTD-SRC-000 requires AnalyzeCompleteSourceGrammar at owner Phase 0; no typed raw observation was supplied27:LEGACY-ANALYZER-UNAVAILABLE38:Amoebius.Validation.Legacy/LTD-SRC-00892:LTD-SRC-008 requires AnalyzeSourcePb at owner Phase 0; no typed raw observation was supplied27:LEGACY-ANALYZER-UNAVAILABLE38:Amoebius.Validation.Legacy/LTD-VAL-001102:LTD-VAL-001 requires AnalyzeValidationProtocol at owner Phase 0; no typed raw observation was supplied27:LEGACY-ANALYZER-UNAVAILABLE38:Amoebius.Validation.Legacy/LTD-VAL-00298:LTD-VAL-002 requires AnalyzePhaseContracts at owner Phase 0; no typed raw observation was supplied27:LEGACY-ANALYZER-UNAVAILABLE38:Amoebius.Validation.Legacy/LTD-VAL-00398:LTD-VAL-003 requires AnalyzeStatusEvidence at owner Phase 0; no typed raw observation was supplied27:LEGACY-ANALYZER-UNAVAILABLE38:Amoebius.Validation.Legacy/LTD-VAL-00498:LTD-VAL-004 requires AnalyzeGateCompletion at owner Phase 0; no typed raw observation was supplied31:LEGACY-DIAGNOSTIC-NOT-CANDIDATE26:Amoebius.Validation.Legacy88:caller-supplied legacy observations are diagnostic model inputs, never analyzer evidence8:one-zero8496:16:legacy-inventory2:2829:legacy.haskell-owner-bindings370:LTD-DOC-001@27,LTD-HOST-001@51,LTD-HOST-002@51,LTD-IMG-001@56,LTD-META-001@2,LTD-NAME-001@2,LTD-RUN-001@55,LTD-SEED-001@91,LTD-SEED-002@93,LTD-SRC-000@0,LTD-SRC-001@47,LTD-SRC-002@25,LTD-SRC-003@26,LTD-SRC-004@46,LTD-SRC-005@47,LTD-SRC-006@47,LTD-SRC-007@1,LTD-SRC-008@0,LTD-SRC-009@1,LTD-VAL-001@0,LTD-VAL-002@0,LTD-VAL-003@0,LTD-VAL-004@0,LTD-VAL-005@49,LTD-VAL-006@4724:legacy.binding-contracts3244:LTD-SRC-000@0:LegacyActive:AnalyzeCompleteSourceGrammar:ObserveCompleteSourceSnapshot:CloseCompleteSourceGrammar:RejectDisguisedOrConcealedSource :| [],LTD-SRC-001@47:LegacyActive:AnalyzeSourceTools:ObserveSourceTools:CloseSourceTools:RejectTrackedToolsSource :| [],LTD-SRC-002@25:LegacyActive:AnalyzeSourceDhall:ObserveSourceDhall:CloseSourceDhall:RejectTrackedDhallOrTsv :| [],LTD-SRC-003@26:LegacyActive:AnalyzeSourceProto:ObserveSourceProto:CloseSourceProto:RejectTrackedProto :| [],LTD-SRC-004@46:LegacyActive:AnalyzeSourceUi:ObserveSourceUi:CloseSourceUi:RejectTrackedUiSource :| [],LTD-SRC-005@47:LegacyActive:AnalyzeSourcePulumi:ObserveSourcePulumi:CloseSourcePulumi:RejectTrackedPulumiSource :| [],LTD-SRC-006@47:LegacyActive:AnalyzeSourceTest:ObserveSourceTest:CloseSourceTest:RejectTrackedBehavioralTestInput :| [],LTD-SRC-007@1:LegacyActive:AnalyzeSourceProbe:ObserveSourceProbe:CloseSourceProbe:RejectTrackedProbeDebt :| [],LTD-SRC-008@0:LegacyActive:AnalyzeSourcePb:ObserveSourcePb:CloseSourcePb:RejectWidenedPbBehavior :| [],LTD-SRC-009@1:LegacyActive:AnalyzeSourceVendor:ObserveSourceVendor:CloseSourceVendor:RejectTopLevelVendorDebt :| [],LTD-META-001@2:LegacyActive:AnalyzeRetiredIgnoreRules:ObserveParsedIgnoreGrammars:CloseRetiredIgnoreRules:RejectRetiredIgnoreRule :| [],LTD-VAL-001@0:LegacyActive:AnalyzeValidationProtocol:ObserveValidationGateGraph:CloseValidationProtocol:RejectNonHaskellValidationVerdict :| [],LTD-VAL-002@0:LegacyActive:AnalyzePhaseContracts:ObserveTypedPhaseContractBinding:ClosePhaseContracts:RejectUnboundPhaseContract :| [],LTD-VAL-003@0:LegacyActive:AnalyzeStatusEvidence:ObserveStatusEvidenceProjection:CloseStatusEvidence:RejectForgedStatusEvidence :| [],LTD-VAL-004@0:LegacyActive:AnalyzeGateCompletion:ObserveGateCompletionResult:CloseGateCompletion:RejectIncompleteGate :| [],LTD-VAL-005@49:LegacyActive:AnalyzeHardwareFreeDsl:ObserveHardwareFreeDslTrace:CloseHardwareFreeDsl:RejectHardwareBeforeDslGatePass :| [],LTD-VAL-006@47:LegacyActive:AnalyzeRunInputClosure:ObserveRunInputProvenance:CloseRunInputClosure:RejectAmbientOrStaleRunInput :| [],LTD-DOC-001@27:LegacyActive:AnalyzeBehavioralDocumentConsumers:ObserveDocumentConsumerGraph:CloseBehavioralDocumentConsumers:RejectBehavioralMarkdownConsumer :| [],LTD-NAME-001@2:LegacyActive:AnalyzePhaseOrdinalNames:ObserveRuntimeIdentityGraph:ClosePhaseOrdinalNames:RejectRuntimePhaseOrdinal :| [],LTD-HOST-001@51:LegacyActive:AnalyzeHostEnsure:ObserveHostEnsureCallGraph:CloseHostEnsure:RejectBypassedHostEnsure :| [],LTD-HOST-002@51:LegacyActive:AnalyzeAmbientHostPaths:ObserveHostPathEffectGraph:CloseAmbientHostPaths:RejectAmbientHostPath :| [],LTD-IMG-001@56:LegacyActive:AnalyzeNaturalArchitectureImages:ObserveImagePlanAndBinfmt:CloseNaturalArchitectureImages:RejectCrossArchitectureImagePlan :| [],LTD-RUN-001@55:LegacyActive:AnalyzeExecutableIdentity:ObserveCabalExecutableGraph:CloseExecutableIdentity:RejectSecondExecutableIdentity :| [],LTD-SEED-001@91:LegacyActive:AnalyzeInfernixSeedDependency:ObserveInfernixDependencyGraph:CloseInfernixSeedDependency:RejectInfernixSeedDependency :| [],LTD-SEED-002@93:LegacyActive:AnalyzeJitMlSeedDependency:ObserveJitMlDependencyGraph:CloseJitMlSeedDependency:RejectJitMlSeedDependency :| []22:legacy.candidate-phase2:4726:legacy.binding.LTD-SRC-00040:unavailable:AnalyzeCompleteSourceGrammar26:legacy.binding.LTD-SRC-00132:analyzer=AnalyzeSourceTools:zero26:legacy.binding.LTD-SRC-00230:unavailable:AnalyzeSourceDhall26:legacy.binding.LTD-SRC-00330:unavailable:AnalyzeSourceProto26:legacy.binding.LTD-SRC-00427:unavailable:AnalyzeSourceUi26:legacy.binding.LTD-SRC-00531:unavailable:AnalyzeSourcePulumi26:legacy.binding.LTD-SRC-00629:unavailable:AnalyzeSourceTest26:legacy.binding.LTD-SRC-00730:unavailable:AnalyzeSourceProbe26:legacy.binding.LTD-SRC-00827:unavailable:AnalyzeSourcePb26:legacy.binding.LTD-SRC-00931:unavailable:AnalyzeSourceVendor27:legacy.binding.LTD-META-00137:unavailable:AnalyzeRetiredIgnoreRules26:legacy.binding.LTD-VAL-00137:unavailable:AnalyzeValidationProtocol26:legacy.binding.LTD-VAL-00233:unavailable:AnalyzePhaseContracts26:legacy.binding.LTD-VAL-00333:unavailable:AnalyzeStatusEvidence26:legacy.binding.LTD-VAL-00433:unavailable:AnalyzeGateCompletion26:legacy.binding.LTD-VAL-00534:unavailable:AnalyzeHardwareFreeDsl26:legacy.binding.LTD-VAL-00634:unavailable:AnalyzeRunInputClosure26:legacy.binding.LTD-DOC-00146:unavailable:AnalyzeBehavioralDocumentConsumers27:legacy.binding.LTD-NAME-00136:unavailable:AnalyzePhaseOrdinalNames27:legacy.binding.LTD-HOST-00129:unavailable:AnalyzeHostEnsure27:legacy.binding.LTD-HOST-00235:unavailable:AnalyzeAmbientHostPaths26:legacy.binding.LTD-IMG-00144:unavailable:AnalyzeNaturalArchitectureImages26:legacy.binding.LTD-RUN-00137:unavailable:AnalyzeExecutableIdentity27:legacy.binding.LTD-SEED-00141:unavailable:AnalyzeInfernixSeedDependency27:legacy.binding.LTD-SEED-00238:unavailable:AnalyzeJitMlSeedDependency2:1827:LEGACY-ANALYZER-UNAVAILABLE38:Amoebius.Validation.Legacy/LTD-SRC-000105:LTD-SRC-000 requires AnalyzeCompleteSourceGrammar at owner Phase 0; no typed raw observation was supplied27:LEGACY-ANALYZER-UNAVAILABLE38:Amoebius.Validation.Legacy/LTD-SRC-00296:LTD-SRC-002 requires AnalyzeSourceDhall at owner Phase 25; no typed raw observation was supplied27:LEGACY-ANALYZER-UNAVAILABLE38:Amoebius.Validation.Legacy/LTD-SRC-00396:LTD-SRC-003 requires AnalyzeSourceProto at owner Phase 26; no typed raw observation was supplied27:LEGACY-ANALYZER-UNAVAILABLE38:Amoebius.Validation.Legacy/LTD-SRC-00493:LTD-SRC-004 requires AnalyzeSourceUi at owner Phase 46; no typed raw observation was supplied27:LEGACY-ANALYZER-UNAVAILABLE38:Amoebius.Validation.Legacy/LTD-SRC-00597:LTD-SRC-005 requires AnalyzeSourcePulumi at owner Phase 47; no typed raw observation was supplied27:LEGACY-ANALYZER-UNAVAILABLE38:Amoebius.Validation.Legacy/LTD-SRC-00695:LTD-SRC-006 requires AnalyzeSourceTest at owner Phase 47; no typed raw observation was supplied27:LEGACY-ANALYZER-UNAVAILABLE38:Amoebius.Validation.Legacy/LTD-SRC-00795:LTD-SRC-007 requires AnalyzeSourceProbe at owner Phase 1; no typed raw observation was supplied27:LEGACY-ANALYZER-UNAVAILABLE38:Amoebius.Validation.Legacy/LTD-SRC-00892:LTD-SRC-008 requires AnalyzeSourcePb at owner Phase 0; no typed raw observation was supplied27:LEGACY-ANALYZER-UNAVAILABLE38:Amoebius.Validation.Legacy/LTD-SRC-00996:LTD-SRC-009 requires AnalyzeSourceVendor at owner Phase 1; no typed raw observation was supplied27:LEGACY-ANALYZER-UNAVAILABLE39:Amoebius.Validation.Legacy/LTD-META-001103:LTD-META-001 requires AnalyzeRetiredIgnoreRules at owner Phase 2; no typed raw observation was supplied27:LEGACY-ANALYZER-UNAVAILABLE38:Amoebius.Validation.Legacy/LTD-VAL-001102:LTD-VAL-001 requires AnalyzeValidationProtocol at owner Phase 0; no typed raw observation was supplied27:LEGACY-ANALYZER-UNAVAILABLE38:Amoebius.Validation.Legacy/LTD-VAL-00298:LTD-VAL-002 requires AnalyzePhaseContracts at owner Phase 0; no typed raw observation was supplied27:LEGACY-ANALYZER-UNAVAILABLE38:Amoebius.Validation.Legacy/LTD-VAL-00398:LTD-VAL-003 requires AnalyzeStatusEvidence at owner Phase 0; no typed raw observation was supplied27:LEGACY-ANALYZER-UNAVAILABLE38:Amoebius.Validation.Legacy/LTD-VAL-00498:LTD-VAL-004 requires AnalyzeGateCompletion at owner Phase 0; no typed raw observation was supplied27:LEGACY-ANALYZER-UNAVAILABLE38:Amoebius.Validation.Legacy/LTD-VAL-006100:LTD-VAL-006 requires AnalyzeRunInputClosure at owner Phase 47; no typed raw observation was supplied27:LEGACY-ANALYZER-UNAVAILABLE38:Amoebius.Validation.Legacy/LTD-DOC-001112:LTD-DOC-001 requires AnalyzeBehavioralDocumentConsumers at owner Phase 27; no typed raw observation was supplied27:LEGACY-ANALYZER-UNAVAILABLE39:Amoebius.Validation.Legacy/LTD-NAME-001102:LTD-NAME-001 requires AnalyzePhaseOrdinalNames at owner Phase 2; no typed raw observation was supplied31:LEGACY-DIAGNOSTIC-NOT-CANDIDATE26:Amoebius.Validation.Legacy88:caller-supplied legacy observations are diagnostic model inputs, never analyzer evidence", "35a16e747c8322e1233a0fa21e98f886bf1e992de0855ce4aa51f1a0be1f78cf")
  , ("legacy.internal.binding-integrity-wire.sha256", "13:owner-missing190:14:legacy-binding1:126:legacy.binding.LTD-SRC-00130:unavailable:AnalyzeSourceTools1:128:LEGACY-OWNER-BINDING-MISSING38:Amoebius.Validation.Legacy/LTD-SRC-00130:typed owner binding is missing14:owner-mismatch225:14:legacy-binding1:126:legacy.binding.LTD-SRC-00130:unavailable:AnalyzeSourceTools1:129:LEGACY-OWNER-BINDING-MISMATCH38:Amoebius.Validation.Legacy/LTD-SRC-00164:typed owner binding does not match the exhaustive owner dispatch16:analyzer-missing205:14:legacy-binding1:126:legacy.binding.LTD-SRC-00130:unavailable:AnalyzeSourceTools1:131:LEGACY-ANALYZER-BINDING-MISSING38:Amoebius.Validation.Legacy/LTD-SRC-00142:typed required-analyzer binding is missing17:analyzer-mismatch205:14:legacy-binding1:126:legacy.binding.LTD-SRC-00130:unavailable:AnalyzeSourceTools1:132:LEGACY-ANALYZER-BINDING-MISMATCH38:Amoebius.Validation.Legacy/LTD-SRC-00141:required-analyzer dispatch was redirected19:observation-missing207:14:legacy-binding1:126:legacy.binding.LTD-SRC-00130:unavailable:AnalyzeSourceTools1:134:LEGACY-OBSERVATION-BINDING-MISSING38:Amoebius.Validation.Legacy/LTD-SRC-00141:typed observation-rule binding is missing20:observation-mismatch212:14:legacy-binding1:126:legacy.binding.LTD-SRC-00130:unavailable:AnalyzeSourceTools1:135:LEGACY-OBSERVATION-BINDING-MISMATCH38:Amoebius.Validation.Legacy/LTD-SRC-00145:typed observation-rule binding was redirected15:closure-missing199:14:legacy-binding1:126:legacy.binding.LTD-SRC-00130:unavailable:AnalyzeSourceTools1:130:LEGACY-CLOSURE-BINDING-MISSING38:Amoebius.Validation.Legacy/LTD-SRC-00137:typed closure-rule binding is missing16:closure-mismatch204:14:legacy-binding1:126:legacy.binding.LTD-SRC-00130:unavailable:AnalyzeSourceTools1:131:LEGACY-CLOSURE-BINDING-MISMATCH38:Amoebius.Validation.Legacy/LTD-SRC-00141:typed closure-rule binding was redirected22:reintroduction-missing213:14:legacy-binding1:126:legacy.binding.LTD-SRC-00130:unavailable:AnalyzeSourceTools1:137:LEGACY-REINTRODUCTION-BINDING-MISSING38:Amoebius.Validation.Legacy/LTD-SRC-00144:typed reintroduction-case binding is missing23:reintroduction-mismatch218:14:legacy-binding1:126:legacy.binding.LTD-SRC-00130:unavailable:AnalyzeSourceTools1:138:LEGACY-REINTRODUCTION-BINDING-MISMATCH38:Amoebius.Validation.Legacy/LTD-SRC-00148:typed reintroduction-case binding was redirected20:all-bindings-missing674:14:legacy-binding1:126:legacy.binding.LTD-SRC-00130:unavailable:AnalyzeSourceTools1:528:LEGACY-OWNER-BINDING-MISSING38:Amoebius.Validation.Legacy/LTD-SRC-00130:typed owner binding is missing31:LEGACY-ANALYZER-BINDING-MISSING38:Amoebius.Validation.Legacy/LTD-SRC-00142:typed required-analyzer binding is missing34:LEGACY-OBSERVATION-BINDING-MISSING38:Amoebius.Validation.Legacy/LTD-SRC-00141:typed observation-rule binding is missing30:LEGACY-CLOSURE-BINDING-MISSING38:Amoebius.Validation.Legacy/LTD-SRC-00137:typed closure-rule binding is missing37:LEGACY-REINTRODUCTION-BINDING-MISSING38:Amoebius.Validation.Legacy/LTD-SRC-00144:typed reintroduction-case binding is missing", "6b87ff206c3236e726fedc5e215a67c5e4b95761b6f0a684356878011370e0f0")
  , ("legacy.internal.integrity-mapping-wire.sha256", "24:all-ids-negative-control7:refused27:binding-id-negative-control7:refused37:rendering-uniqueness-negative-control7:refused31:parser-grammar-negative-control7:refused35:parser-cardinality-negative-control7:refused32:closed-universe-negative-control7:refused42:closed-universe-duplicate-negative-control7:refused38:universe-integrity-composition-control192:45:legacy-universe-integrity-composition-control1:01:58:UNIVERSE8:universe8:universe9:RENDERING9:rendering9:rendering6:PARSER6:parser6:parser7:BINDING7:binding7:binding6:CLOSED6:closed6:closed38:evaluation-finding-composition-control117:45:legacy-evaluation-finding-composition-control1:01:29:INTEGRITY9:integrity9:integrity8:SEMANTIC8:semantic8:semantic37:inventory-finding-composition-control119:44:legacy-inventory-finding-composition-control1:01:29:INTEGRITY9:integrity9:integrity9:EVALUATED9:evaluated9:evaluated37:candidate-finding-composition-control146:44:legacy-candidate-finding-composition-control1:01:38:UNIVERSE8:universe8:universe8:EVIDENCE8:evidence8:evidence9:EVALUATED9:evaluated9:evaluated19:LEGACY-ID-INVENTORY26:Amoebius.Validation.Legacy12:id inventory18:LEGACY-ID-ENCODING26:Amoebius.Validation.Legacy11:id encoding24:LEGACY-ID-PARSER-GRAMMAR26:Amoebius.Validation.Legacy14:parser grammar26:LEGACY-BINDING-ID-MISMATCH7:binding10:binding id25:LEGACY-ANALYZER-INVENTORY26:Amoebius.Validation.Legacy18:analyzer inventory28:LEGACY-OBSERVATION-INVENTORY26:Amoebius.Validation.Legacy21:observation inventory24:LEGACY-CLOSURE-INVENTORY26:Amoebius.Validation.Legacy17:closure inventory31:LEGACY-REINTRODUCTION-INVENTORY26:Amoebius.Validation.Legacy24:reintroduction inventory", "b7c70ac7b266f0b2bc9d45c051d58e3ac8999c50bd1d87a429b83a0687fe4033")
  , ("legacy.internal.register-wire.sha256", "7:missing93:refused83:active legacy register is missing: DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md19:entry-count-maximum93:refused83:active legacy register is missing: DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md28:entry-count-maximum-plus-one78:refused68:tracked entry limit exceeded: maximum=16384; observed-at-least=1638518:path-bytes-maximum93:refused83:active legacy register is missing: DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md27:path-bytes-maximum-plus-one91:refused81:tracked path byte limit exceeded: ordinal=1; maximum=1024; observed-at-least=102521:path-two-byte-maximum93:refused83:active legacy register is missing: DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md30:path-two-byte-maximum-plus-one91:refused81:tracked path byte limit exceeded: ordinal=1; maximum=1024; observed-at-least=102523:path-three-byte-maximum93:refused83:active legacy register is missing: DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md32:path-three-byte-maximum-plus-one91:refused81:tracked path byte limit exceeded: ordinal=1; maximum=1024; observed-at-least=102522:path-four-byte-maximum93:refused83:active legacy register is missing: DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md31:path-four-byte-maximum-plus-one91:refused81:tracked path byte limit exceeded: ordinal=1; maximum=1024; observed-at-least=10257:regular59:accepted48:DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md22:register-bytes-maximum59:accepted48:DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md31:register-bytes-maximum-plus-one87:refused77:active legacy register byte limit exceeded: maximum=1048576; observed=10485779:duplicate97:refused87:active legacy register occurs 2 times: DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md5:alias93:refused83:additional active legacy register is tracked: alias/legacy_tracking_for_deletion.md21:entry-retention-order273:refused87:additional active legacy register is tracked: alias-one/legacy_tracking_for_deletion.md87:additional active legacy register is tracked: alias-two/legacy_tracking_for_deletion.md83:active legacy register is missing: DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md14:unrelated-path59:accepted48:DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md7:archive93:refused83:archive legacy register is tracked: archive/legacy_tracking_for_deletion_archive.md13:problem-order321:refused83:additional active legacy register is tracked: alias/legacy_tracking_for_deletion.md83:archive legacy register is tracked: archive/legacy_tracking_for_deletion_archive.md138:active legacy register must be a non-executable regular file: DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md (index mode ExecutableFile)10:executable149:refused138:active legacy register must be a non-executable regular file: DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md (index mode ExecutableFile)7:symlink147:refused136:active legacy register must be a non-executable regular file: DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md (index mode SymbolicLink)12:invalid-utf895:refused85:active legacy register is not UTF-8: DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md", "d2d5506e5e445aaa9007cff9c099845b48aa4ea116676434ba5351320fd86349")
  , ("legacy.internal.register-finding-wire.sha256", "15:LEGACY-REGISTER17:<tracked-entries>68:tracked entry limit exceeded: maximum=16384; observed-at-least=1638515:LEGACY-REGISTER16:<tracked-path-1>81:tracked path byte limit exceeded: ordinal=1; maximum=1024; observed-at-least=102515:LEGACY-REGISTER48:DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md77:active legacy register byte limit exceeded: maximum=1048576; observed=104857715:LEGACY-REGISTER23:<legacy-register-input>64:register resource guard unavailable after bounded refusal: guard15:LEGACY-REGISTER7:missing42:active legacy register is missing: missing15:LEGACY-REGISTER8:multiple47:active legacy register occurs 2 times: multiple15:LEGACY-REGISTER10:additional56:additional active legacy register is tracked: additional15:LEGACY-REGISTER7:archive43:archive legacy register is tracked: archive15:LEGACY-REGISTER4:mode94:active legacy register must be a non-executable regular file: mode (index mode ExecutableFile)15:LEGACY-REGISTER4:utf841:active legacy register is not UTF-8: utf8", "7e7f7d4d9857639661c27bbd3c9a5b78f32922a416cb289c7b016435cfe4210c")
  , ("legacy.internal.raw-check-wire.sha256", "16:legacy-inventory2:3429:legacy.haskell-owner-bindings370:LTD-DOC-001@27,LTD-HOST-001@51,LTD-HOST-002@51,LTD-IMG-001@56,LTD-META-001@2,LTD-NAME-001@2,LTD-RUN-001@55,LTD-SEED-001@91,LTD-SEED-002@93,LTD-SRC-000@0,LTD-SRC-001@47,LTD-SRC-002@25,LTD-SRC-003@26,LTD-SRC-004@46,LTD-SRC-005@47,LTD-SRC-006@47,LTD-SRC-007@1,LTD-SRC-008@0,LTD-SRC-009@1,LTD-VAL-001@0,LTD-VAL-002@0,LTD-VAL-003@0,LTD-VAL-004@0,LTD-VAL-005@49,LTD-VAL-006@4724:legacy.binding-contracts3244:LTD-SRC-000@0:LegacyActive:AnalyzeCompleteSourceGrammar:ObserveCompleteSourceSnapshot:CloseCompleteSourceGrammar:RejectDisguisedOrConcealedSource :| [],LTD-SRC-001@47:LegacyActive:AnalyzeSourceTools:ObserveSourceTools:CloseSourceTools:RejectTrackedToolsSource :| [],LTD-SRC-002@25:LegacyActive:AnalyzeSourceDhall:ObserveSourceDhall:CloseSourceDhall:RejectTrackedDhallOrTsv :| [],LTD-SRC-003@26:LegacyActive:AnalyzeSourceProto:ObserveSourceProto:CloseSourceProto:RejectTrackedProto :| [],LTD-SRC-004@46:LegacyActive:AnalyzeSourceUi:ObserveSourceUi:CloseSourceUi:RejectTrackedUiSource :| [],LTD-SRC-005@47:LegacyActive:AnalyzeSourcePulumi:ObserveSourcePulumi:CloseSourcePulumi:RejectTrackedPulumiSource :| [],LTD-SRC-006@47:LegacyActive:AnalyzeSourceTest:ObserveSourceTest:CloseSourceTest:RejectTrackedBehavioralTestInput :| [],LTD-SRC-007@1:LegacyActive:AnalyzeSourceProbe:ObserveSourceProbe:CloseSourceProbe:RejectTrackedProbeDebt :| [],LTD-SRC-008@0:LegacyActive:AnalyzeSourcePb:ObserveSourcePb:CloseSourcePb:RejectWidenedPbBehavior :| [],LTD-SRC-009@1:LegacyActive:AnalyzeSourceVendor:ObserveSourceVendor:CloseSourceVendor:RejectTopLevelVendorDebt :| [],LTD-META-001@2:LegacyActive:AnalyzeRetiredIgnoreRules:ObserveParsedIgnoreGrammars:CloseRetiredIgnoreRules:RejectRetiredIgnoreRule :| [],LTD-VAL-001@0:LegacyActive:AnalyzeValidationProtocol:ObserveValidationGateGraph:CloseValidationProtocol:RejectNonHaskellValidationVerdict :| [],LTD-VAL-002@0:LegacyActive:AnalyzePhaseContracts:ObserveTypedPhaseContractBinding:ClosePhaseContracts:RejectUnboundPhaseContract :| [],LTD-VAL-003@0:LegacyActive:AnalyzeStatusEvidence:ObserveStatusEvidenceProjection:CloseStatusEvidence:RejectForgedStatusEvidence :| [],LTD-VAL-004@0:LegacyActive:AnalyzeGateCompletion:ObserveGateCompletionResult:CloseGateCompletion:RejectIncompleteGate :| [],LTD-VAL-005@49:LegacyActive:AnalyzeHardwareFreeDsl:ObserveHardwareFreeDslTrace:CloseHardwareFreeDsl:RejectHardwareBeforeDslGatePass :| [],LTD-VAL-006@47:LegacyActive:AnalyzeRunInputClosure:ObserveRunInputProvenance:CloseRunInputClosure:RejectAmbientOrStaleRunInput :| [],LTD-DOC-001@27:LegacyActive:AnalyzeBehavioralDocumentConsumers:ObserveDocumentConsumerGraph:CloseBehavioralDocumentConsumers:RejectBehavioralMarkdownConsumer :| [],LTD-NAME-001@2:LegacyActive:AnalyzePhaseOrdinalNames:ObserveRuntimeIdentityGraph:ClosePhaseOrdinalNames:RejectRuntimePhaseOrdinal :| [],LTD-HOST-001@51:LegacyActive:AnalyzeHostEnsure:ObserveHostEnsureCallGraph:CloseHostEnsure:RejectBypassedHostEnsure :| [],LTD-HOST-002@51:LegacyActive:AnalyzeAmbientHostPaths:ObserveHostPathEffectGraph:CloseAmbientHostPaths:RejectAmbientHostPath :| [],LTD-IMG-001@56:LegacyActive:AnalyzeNaturalArchitectureImages:ObserveImagePlanAndBinfmt:CloseNaturalArchitectureImages:RejectCrossArchitectureImagePlan :| [],LTD-RUN-001@55:LegacyActive:AnalyzeExecutableIdentity:ObserveCabalExecutableGraph:CloseExecutableIdentity:RejectSecondExecutableIdentity :| [],LTD-SEED-001@91:LegacyActive:AnalyzeInfernixSeedDependency:ObserveInfernixDependencyGraph:CloseInfernixSeedDependency:RejectInfernixSeedDependency :| [],LTD-SEED-002@93:LegacyActive:AnalyzeJitMlSeedDependency:ObserveJitMlDependencyGraph:CloseJitMlSeedDependency:RejectJitMlSeedDependency :| []22:legacy.candidate-phase1:024:legacy.evidence.snapshot26:legacy-projection-snapshot26:legacy.binding.LTD-SRC-000608:analyzer=AnalyzeCompleteSourceGrammar:refused:source closure is incomplete at: 30:LEGACY-RAW-CAPTURE-UNAVAILABLE50:Amoebius.Validation.Legacy.Internal/source-closure88:caller-authored snapshots cannot invoke the captured analyzer route; role=source-closure,30:LEGACY-RAW-CAPTURE-UNAVAILABLE47:Amoebius.Validation.Legacy.Internal/source-debt85:caller-authored snapshots cannot invoke the captured analyzer route; role=source-debt,30:LEGACY-RAW-CAPTURE-UNAVAILABLE51:Amoebius.Validation.Legacy.Internal/source-consumer89:caller-authored snapshots cannot invoke the captured analyzer route; role=source-consumer26:legacy.binding.LTD-SRC-001116:analyzer=AnalyzeSourceTools:refused:caller-authored snapshots cannot supply candidate source-debt lifecycle evidence26:legacy.binding.LTD-SRC-002116:analyzer=AnalyzeSourceDhall:refused:caller-authored snapshots cannot supply candidate source-debt lifecycle evidence26:legacy.binding.LTD-SRC-003116:analyzer=AnalyzeSourceProto:refused:caller-authored snapshots cannot supply candidate source-debt lifecycle evidence26:legacy.binding.LTD-SRC-004113:analyzer=AnalyzeSourceUi:refused:caller-authored snapshots cannot supply candidate source-debt lifecycle evidence26:legacy.binding.LTD-SRC-005117:analyzer=AnalyzeSourcePulumi:refused:caller-authored snapshots cannot supply candidate source-debt lifecycle evidence26:legacy.binding.LTD-SRC-006115:analyzer=AnalyzeSourceTest:refused:caller-authored snapshots cannot supply candidate source-debt lifecycle evidence26:legacy.binding.LTD-SRC-007116:analyzer=AnalyzeSourceProbe:refused:caller-authored snapshots cannot supply candidate source-debt lifecycle evidence26:legacy.binding.LTD-SRC-008113:analyzer=AnalyzeSourcePb:refused:caller-authored snapshots cannot supply candidate source-debt lifecycle evidence26:legacy.binding.LTD-SRC-009117:analyzer=AnalyzeSourceVendor:refused:caller-authored snapshots cannot supply candidate source-debt lifecycle evidence27:legacy.binding.LTD-META-00137:unavailable:AnalyzeRetiredIgnoreRules26:legacy.binding.LTD-VAL-001100:analyzer=AnalyzeValidationProtocol:refused:the closed owner-domain analyzer has not been implemented26:legacy.binding.LTD-VAL-00296:analyzer=AnalyzePhaseContracts:refused:the closed owner-domain analyzer has not been implemented26:legacy.binding.LTD-VAL-00396:analyzer=AnalyzeStatusEvidence:refused:the closed owner-domain analyzer has not been implemented26:legacy.binding.LTD-VAL-00496:analyzer=AnalyzeGateCompletion:refused:the closed owner-domain analyzer has not been implemented26:legacy.binding.LTD-VAL-00534:unavailable:AnalyzeHardwareFreeDsl26:legacy.binding.LTD-VAL-00634:unavailable:AnalyzeRunInputClosure26:legacy.binding.LTD-DOC-00146:unavailable:AnalyzeBehavioralDocumentConsumers27:legacy.binding.LTD-NAME-00136:unavailable:AnalyzePhaseOrdinalNames27:legacy.binding.LTD-HOST-00129:unavailable:AnalyzeHostEnsure27:legacy.binding.LTD-HOST-00235:unavailable:AnalyzeAmbientHostPaths26:legacy.binding.LTD-IMG-00144:unavailable:AnalyzeNaturalArchitectureImages26:legacy.binding.LTD-RUN-00137:unavailable:AnalyzeExecutableIdentity27:legacy.binding.LTD-SEED-00141:unavailable:AnalyzeInfernixSeedDependency27:legacy.binding.LTD-SEED-00238:unavailable:AnalyzeJitMlSeedDependency20:legacy.register.path48:DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md27:legacy.register.cardinality1:126:legacy.register.index-mode6:10064424:legacy.register.encoding5:UTF-824:legacy.register.snapshot26:legacy-projection-snapshot2:1526:LEGACY-OBSERVATION-REFUSED38:Amoebius.Validation.Legacy/LTD-SRC-000575:LTD-SRC-000: source closure is incomplete at: 30:LEGACY-RAW-CAPTURE-UNAVAILABLE50:Amoebius.Validation.Legacy.Internal/source-closure88:caller-authored snapshots cannot invoke the captured analyzer route; role=source-closure,30:LEGACY-RAW-CAPTURE-UNAVAILABLE47:Amoebius.Validation.Legacy.Internal/source-debt85:caller-authored snapshots cannot invoke the captured analyzer route; role=source-debt,30:LEGACY-RAW-CAPTURE-UNAVAILABLE51:Amoebius.Validation.Legacy.Internal/source-consumer89:caller-authored snapshots cannot invoke the captured analyzer route; role=source-consumer26:LEGACY-OBSERVATION-REFUSED38:Amoebius.Validation.Legacy/LTD-SRC-00193:LTD-SRC-001: caller-authored snapshots cannot supply candidate source-debt lifecycle evidence26:LEGACY-OBSERVATION-REFUSED38:Amoebius.Validation.Legacy/LTD-SRC-00293:LTD-SRC-002: caller-authored snapshots cannot supply candidate source-debt lifecycle evidence26:LEGACY-OBSERVATION-REFUSED38:Amoebius.Validation.Legacy/LTD-SRC-00393:LTD-SRC-003: caller-authored snapshots cannot supply candidate source-debt lifecycle evidence26:LEGACY-OBSERVATION-REFUSED38:Amoebius.Validation.Legacy/LTD-SRC-00493:LTD-SRC-004: caller-authored snapshots cannot supply candidate source-debt lifecycle evidence26:LEGACY-OBSERVATION-REFUSED38:Amoebius.Validation.Legacy/LTD-SRC-00593:LTD-SRC-005: caller-authored snapshots cannot supply candidate source-debt lifecycle evidence26:LEGACY-OBSERVATION-REFUSED38:Amoebius.Validation.Legacy/LTD-SRC-00693:LTD-SRC-006: caller-authored snapshots cannot supply candidate source-debt lifecycle evidence26:LEGACY-OBSERVATION-REFUSED38:Amoebius.Validation.Legacy/LTD-SRC-00793:LTD-SRC-007: caller-authored snapshots cannot supply candidate source-debt lifecycle evidence26:LEGACY-OBSERVATION-REFUSED38:Amoebius.Validation.Legacy/LTD-SRC-00893:LTD-SRC-008: caller-authored snapshots cannot supply candidate source-debt lifecycle evidence26:LEGACY-OBSERVATION-REFUSED38:Amoebius.Validation.Legacy/LTD-SRC-00993:LTD-SRC-009: caller-authored snapshots cannot supply candidate source-debt lifecycle evidence26:LEGACY-OBSERVATION-REFUSED38:Amoebius.Validation.Legacy/LTD-VAL-00170:LTD-VAL-001: the closed owner-domain analyzer has not been implemented26:LEGACY-OBSERVATION-REFUSED38:Amoebius.Validation.Legacy/LTD-VAL-00270:LTD-VAL-002: the closed owner-domain analyzer has not been implemented26:LEGACY-OBSERVATION-REFUSED38:Amoebius.Validation.Legacy/LTD-VAL-00370:LTD-VAL-003: the closed owner-domain analyzer has not been implemented26:LEGACY-OBSERVATION-REFUSED38:Amoebius.Validation.Legacy/LTD-VAL-00470:LTD-VAL-004: the closed owner-domain analyzer has not been implemented31:LEGACY-SNAPSHOT-DIAGNOSTIC-ONLY26:Amoebius.Validation.Legacy97:a caller-authored SourceSnapshot and its derived legacy observations cannot be candidate evidence", "91b1ca509feda7a3067909536cd0a02a40fb5e1a5c1b49ad258d9c8ea2a8580c")
  , ("legacy.internal.gate-mapping-wire.sha256", "4:zero84:refused:source closure is incomplete at: 12:PROJECTION-A1:a1:a,12:PROJECTION-B1:b1:b194:22:legacy-gate-projection1:01:131:LEGACY-SNAPSHOT-DIAGNOSTIC-ONLY26:Amoebius.Validation.Legacy97:a caller-authored SourceSnapshot and its derived legacy observations cannot be candidate evidence34:missing-owner-due-negative-control3:due39:missing-owner-relation-negative-control5:after100:22:legacy-gate-projection1:01:28:SEMANTIC8:semantic8:semantic10:STRUCTURAL10:structural10:structural169:22:legacy-gate-projection1:01:133:LEGACY-COMPILER-SNAPSHOT-MISMATCH26:Amoebius.Validation.Legacy70:the captured compiler evidence is bound to a different source snapshot45:compiler-snapshot-finding-composition-control199:22:legacy-gate-projection1:01:28:EXISTING8:existing8:existing33:LEGACY-COMPILER-SNAPSHOT-MISMATCH26:Amoebius.Validation.Legacy70:the captured compiler evidence is bound to a different source snapshot28:missing-owner-render-control9:<missing>26:raw-capture-result-control208:30:legacy-raw-capture-unavailable1:01:130:LEGACY-RAW-CAPTURE-UNAVAILABLE46:Amoebius.Validation.Legacy.Internal/projection84:caller-authored snapshots cannot invoke the captured analyzer route; role=projection", "3d1df5af14e787b219f0870422c720b5e050d0f2ff9704a89db6e0f7136096b2")
  , ("legacy.internal.closed-evidence-integrity-wire.sha256", "14:empty-registry485:34:LEGACY-ANALYZER-REGISTRY-INVENTORY26:Amoebius.Validation.Legacy415:closed analyzer registry keys differ: expected=[\"LTD-SRC-000\",\"LTD-SRC-001\",\"LTD-SRC-002\",\"LTD-SRC-003\",\"LTD-SRC-004\",\"LTD-SRC-005\",\"LTD-SRC-006\",\"LTD-SRC-007\",\"LTD-SRC-008\",\"LTD-SRC-009\",\"LTD-META-001\",\"LTD-VAL-001\",\"LTD-VAL-002\",\"LTD-VAL-003\",\"LTD-VAL-004\",\"LTD-VAL-005\",\"LTD-VAL-006\",\"LTD-DOC-001\",\"LTD-NAME-001\",\"LTD-HOST-001\",\"LTD-HOST-002\",\"LTD-IMG-001\",\"LTD-RUN-001\",\"LTD-SEED-001\",\"LTD-SEED-002\"], actual=[]11:id-mismatch631:34:LEGACY-ANALYZER-REGISTRY-INVENTORY26:Amoebius.Validation.Legacy428:closed analyzer registry keys differ: expected=[\"LTD-SRC-000\",\"LTD-SRC-001\",\"LTD-SRC-002\",\"LTD-SRC-003\",\"LTD-SRC-004\",\"LTD-SRC-005\",\"LTD-SRC-006\",\"LTD-SRC-007\",\"LTD-SRC-008\",\"LTD-SRC-009\",\"LTD-META-001\",\"LTD-VAL-001\",\"LTD-VAL-002\",\"LTD-VAL-003\",\"LTD-VAL-004\",\"LTD-VAL-005\",\"LTD-VAL-006\",\"LTD-DOC-001\",\"LTD-NAME-001\",\"LTD-HOST-001\",\"LTD-HOST-002\",\"LTD-IMG-001\",\"LTD-RUN-001\",\"LTD-SEED-001\",\"LTD-SEED-002\"], actual=[\"LTD-SRC-001\"]27:LEGACY-ANALYZER-EVIDENCE-ID38:Amoebius.Validation.Legacy/LTD-SRC-00159:closed analyzer evidence is bound to a different legacy row20:source-debt-mismatch646:34:LEGACY-ANALYZER-REGISTRY-INVENTORY26:Amoebius.Validation.Legacy428:closed analyzer registry keys differ: expected=[\"LTD-SRC-000\",\"LTD-SRC-001\",\"LTD-SRC-002\",\"LTD-SRC-003\",\"LTD-SRC-004\",\"LTD-SRC-005\",\"LTD-SRC-006\",\"LTD-SRC-007\",\"LTD-SRC-008\",\"LTD-SRC-009\",\"LTD-META-001\",\"LTD-VAL-001\",\"LTD-VAL-002\",\"LTD-VAL-003\",\"LTD-VAL-004\",\"LTD-VAL-005\",\"LTD-VAL-006\",\"LTD-DOC-001\",\"LTD-NAME-001\",\"LTD-HOST-001\",\"LTD-HOST-002\",\"LTD-IMG-001\",\"LTD-RUN-001\",\"LTD-SEED-001\",\"LTD-SEED-002\"], actual=[\"LTD-SRC-001\"]36:LEGACY-ANALYZER-EVIDENCE-SOURCE-DEBT38:Amoebius.Validation.Legacy/LTD-SRC-00165:closed analyzer evidence is bound to the wrong source-debt family17:analyzer-mismatch777:34:LEGACY-ANALYZER-REGISTRY-INVENTORY26:Amoebius.Validation.Legacy428:closed analyzer registry keys differ: expected=[\"LTD-SRC-000\",\"LTD-SRC-001\",\"LTD-SRC-002\",\"LTD-SRC-003\",\"LTD-SRC-004\",\"LTD-SRC-005\",\"LTD-SRC-006\",\"LTD-SRC-007\",\"LTD-SRC-008\",\"LTD-SRC-009\",\"LTD-META-001\",\"LTD-VAL-001\",\"LTD-VAL-002\",\"LTD-VAL-003\",\"LTD-VAL-004\",\"LTD-VAL-005\",\"LTD-VAL-006\",\"LTD-DOC-001\",\"LTD-NAME-001\",\"LTD-HOST-001\",\"LTD-HOST-002\",\"LTD-IMG-001\",\"LTD-RUN-001\",\"LTD-SEED-001\",\"LTD-SEED-002\"], actual=[\"LTD-SRC-001\"]28:LEGACY-ANALYZER-EVIDENCE-KEY38:Amoebius.Validation.Legacy/LTD-SRC-00161:closed analyzer evidence is bound to a non-canonical analyzer36:LEGACY-ANALYZER-EVIDENCE-OBSERVATION38:Amoebius.Validation.Legacy/LTD-SRC-00160:closed evidence and its observation name different analyzers17:snapshot-mismatch647:34:LEGACY-ANALYZER-REGISTRY-INVENTORY26:Amoebius.Validation.Legacy428:closed analyzer registry keys differ: expected=[\"LTD-SRC-000\",\"LTD-SRC-001\",\"LTD-SRC-002\",\"LTD-SRC-003\",\"LTD-SRC-004\",\"LTD-SRC-005\",\"LTD-SRC-006\",\"LTD-SRC-007\",\"LTD-SRC-008\",\"LTD-SRC-009\",\"LTD-META-001\",\"LTD-VAL-001\",\"LTD-VAL-002\",\"LTD-VAL-003\",\"LTD-VAL-004\",\"LTD-VAL-005\",\"LTD-VAL-006\",\"LTD-DOC-001\",\"LTD-NAME-001\",\"LTD-HOST-001\",\"LTD-HOST-002\",\"LTD-IMG-001\",\"LTD-RUN-001\",\"LTD-SEED-001\",\"LTD-SEED-002\"], actual=[\"LTD-SRC-001\"]33:LEGACY-ANALYZER-EVIDENCE-SNAPSHOT38:Amoebius.Validation.Legacy/LTD-SRC-00169:closed analyzer evidence was produced for a different source snapshot20:observation-mismatch641:34:LEGACY-ANALYZER-REGISTRY-INVENTORY26:Amoebius.Validation.Legacy428:closed analyzer registry keys differ: expected=[\"LTD-SRC-000\",\"LTD-SRC-001\",\"LTD-SRC-002\",\"LTD-SRC-003\",\"LTD-SRC-004\",\"LTD-SRC-005\",\"LTD-SRC-006\",\"LTD-SRC-007\",\"LTD-SRC-008\",\"LTD-SRC-009\",\"LTD-META-001\",\"LTD-VAL-001\",\"LTD-VAL-002\",\"LTD-VAL-003\",\"LTD-VAL-004\",\"LTD-VAL-005\",\"LTD-VAL-006\",\"LTD-DOC-001\",\"LTD-NAME-001\",\"LTD-HOST-001\",\"LTD-HOST-002\",\"LTD-IMG-001\",\"LTD-RUN-001\",\"LTD-SEED-001\",\"LTD-SEED-002\"], actual=[\"LTD-SRC-001\"]36:LEGACY-ANALYZER-EVIDENCE-OBSERVATION38:Amoebius.Validation.Legacy/LTD-SRC-00160:closed evidence and its observation name different analyzers23:all-evidence-mismatches1207:34:LEGACY-ANALYZER-REGISTRY-INVENTORY26:Amoebius.Validation.Legacy428:closed analyzer registry keys differ: expected=[\"LTD-SRC-000\",\"LTD-SRC-001\",\"LTD-SRC-002\",\"LTD-SRC-003\",\"LTD-SRC-004\",\"LTD-SRC-005\",\"LTD-SRC-006\",\"LTD-SRC-007\",\"LTD-SRC-008\",\"LTD-SRC-009\",\"LTD-META-001\",\"LTD-VAL-001\",\"LTD-VAL-002\",\"LTD-VAL-003\",\"LTD-VAL-004\",\"LTD-VAL-005\",\"LTD-VAL-006\",\"LTD-DOC-001\",\"LTD-NAME-001\",\"LTD-HOST-001\",\"LTD-HOST-002\",\"LTD-IMG-001\",\"LTD-RUN-001\",\"LTD-SEED-001\",\"LTD-SEED-002\"], actual=[\"LTD-SRC-001\"]27:LEGACY-ANALYZER-EVIDENCE-ID38:Amoebius.Validation.Legacy/LTD-SRC-00159:closed analyzer evidence is bound to a different legacy row36:LEGACY-ANALYZER-EVIDENCE-SOURCE-DEBT38:Amoebius.Validation.Legacy/LTD-SRC-00165:closed analyzer evidence is bound to the wrong source-debt family28:LEGACY-ANALYZER-EVIDENCE-KEY38:Amoebius.Validation.Legacy/LTD-SRC-00161:closed analyzer evidence is bound to a non-canonical analyzer33:LEGACY-ANALYZER-EVIDENCE-SNAPSHOT38:Amoebius.Validation.Legacy/LTD-SRC-00169:closed analyzer evidence was produced for a different source snapshot36:LEGACY-ANALYZER-EVIDENCE-OBSERVATION38:Amoebius.Validation.Legacy/LTD-SRC-00160:closed evidence and its observation name different analyzers", "5f04e42eec3d9c59fda0a01151554a95ac759c9c73df6cc123f995bfb8e984cf")
  ]

mandatoryFindings :: Text -> [Finding]
mandatoryFindings detail =
  [ Finding "LEGACY-DIAGNOSTIC-ONLY" "Amoebius.Validation.Legacy.legacyDiagnostic"
      ("caller-declared legacy wire cannot mint candidate evidence" <> detail)
  , Finding "LEGACY-SOURCE-BINDING-UNAVAILABLE" "<caller-supplied-legacy-input>"
      ("no exact local source snapshot is attached" <> detail)
  , Finding "LEGACY-ANALYZER-EVIDENCE-UNAVAILABLE" "Amoebius.Validation.Legacy.Internal"
      ("package-hidden owner analyzers have not produced snapshot-bound observations" <> detail)
  , Finding "LEGACY-REINTRODUCTION-EXECUTION-UNAVAILABLE" "legacy-reintroduction-corpus"
      ("declared case identities do not establish execution of the owning negative corpus" <> detail)
  , Finding "LEGACY-QUALIFICATION-UNAVAILABLE" "legacy-changed-subject-matrix"
      ("the fixed changed-production corpus has not executed against this exact subject" <> detail)
  , Finding "LEGACY-DOCUMENTATION-CORRESPONDENCE-UNAVAILABLE" "DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md"
      ("reader-facing prose correspondence has not received independent documentation correspondence check" <> detail)
  ]

renderProblem :: Text -> LiteralProblem -> Finding
renderProblem commitmentDetail problem =
  Finding (problemCode problem) (problemSubject problem) (problemDetail problem <> commitmentDetail)

literalResource :: Text -> FilePath -> Int -> Int -> LiteralProblem
literalResource code subject maximumValue actual =
  LiteralProblem code subject
    ("maximum=" <> Text.pack (show maximumValue) <> "; observed-at-least=" <> Text.pack (show actual))

literalGrammar :: Text -> FilePath -> Text -> LiteralProblem
literalGrammar = LiteralProblem

literalField :: Text -> Text -> Text -> LiteralProblem
literalField field expected actual =
  literalGrammar "LEGACY-BINDING-FIELD" "<binding-1>"
    ("field=" <> field <> "; expected=" <> expected <> "; observed=" <> actual)

canonicalBindings :: [RawBinding]
canonicalBindings =
  [ ("LTD-SRC-000", "Active", "00", "complete-source-grammar", "complete-source-snapshot", "complete-source-grammar", ["reject-disguised-or-concealed-source"])
  , ("LTD-SRC-001", "Active", "47", "source-tools", "source-tools", "source-tools", ["reject-tracked-tools-source"])
  , ("LTD-SRC-002", "Active", "25", "source-dhall", "source-dhall", "source-dhall", ["reject-tracked-dhall-or-tsv"])
  , ("LTD-SRC-003", "Active", "26", "source-proto", "source-proto", "source-proto", ["reject-tracked-proto"])
  , ("LTD-SRC-004", "Active", "46", "source-ui", "source-ui", "source-ui", ["reject-tracked-ui-source"])
  , ("LTD-SRC-005", "Active", "47", "source-pulumi", "source-pulumi", "source-pulumi", ["reject-tracked-pulumi-source"])
  , ("LTD-SRC-006", "Active", "47", "source-test", "source-test", "source-test", ["reject-tracked-behavioral-test-input"])
  , ("LTD-SRC-007", "Active", "01", "source-probe", "source-probe", "source-probe", ["reject-tracked-probe-debt"])
  , ("LTD-SRC-008", "Active", "00", "source-pb", "source-pb", "source-pb", ["reject-widened-pb-behavior"])
  , ("LTD-SRC-009", "Active", "01", "source-vendor", "source-vendor", "source-vendor", ["reject-top-level-vendor-debt"])
  , ("LTD-META-001", "Active", "02", "retired-ignore-rules", "parsed-ignore-grammars", "retired-ignore-rules", ["reject-retired-ignore-rule"])
  , ("LTD-VAL-001", "Active", "00", "validation-protocol", "validation-gate-graph", "validation-protocol", ["reject-non-haskell-validation-verdict"])
  , ("LTD-VAL-002", "Active", "00", "phase-contracts", "typed-phase-contract-binding", "phase-contracts", ["reject-unbound-phase-contract"])
  , ("LTD-VAL-003", "Active", "00", "status-evidence", "status-evidence-projection", "status-evidence", ["reject-forged-status-evidence"])
  , ("LTD-VAL-004", "Active", "00", "gate-completion", "gate-completion-result", "gate-completion", ["reject-incomplete-gate"])
  , ("LTD-VAL-005", "Active", "49", "hardware-free-dsl", "hardware-free-dsl-trace", "hardware-free-dsl", ["reject-hardware-before-dsl-gate-pass"])
  , ("LTD-VAL-006", "Active", "47", "run-input-closure", "run-input-provenance", "run-input-closure", ["reject-ambient-or-stale-run-input"])
  , ("LTD-DOC-001", "Active", "27", "behavioral-document-consumers", "document-consumer-graph", "behavioral-document-consumers", ["reject-behavioral-markdown-consumer"])
  , ("LTD-NAME-001", "Active", "02", "phase-ordinal-names", "runtime-identity-graph", "phase-ordinal-names", ["reject-runtime-phase-ordinal"])
  , ("LTD-HOST-001", "Active", "51", "host-ensure", "host-ensure-call-graph", "host-ensure", ["reject-bypassed-host-ensure"])
  , ("LTD-HOST-002", "Active", "51", "ambient-host-paths", "host-path-effect-graph", "ambient-host-paths", ["reject-ambient-host-path"])
  , ("LTD-IMG-001", "Active", "56", "natural-architecture-images", "image-plan-and-binfmt", "natural-architecture-images", ["reject-cross-architecture-image-plan"])
  , ("LTD-RUN-001", "Active", "55", "executable-identity", "cabal-executable-graph", "executable-identity", ["reject-second-executable-identity"])
  , ("LTD-SEED-001", "Active", "91", "infernix-seed-dependency", "infernix-dependency-graph", "infernix-seed-dependency", ["reject-infernix-seed-dependency"])
  , ("LTD-SEED-002", "Active", "93", "jitml-seed-dependency", "jitml-dependency-graph", "jitml-seed-dependency", ["reject-jitml-seed-dependency"])
  ]

canonicalJoins :: [RawJoin]
canonicalJoins =
  [ ("source-tools", "LTD-SRC-001")
  , ("source-dhall", "LTD-SRC-002")
  , ("source-proto", "LTD-SRC-003")
  , ("source-ui", "LTD-SRC-004")
  , ("source-pulumi", "LTD-SRC-005")
  , ("source-test", "LTD-SRC-006")
  , ("source-probe", "LTD-SRC-007")
  , ("source-pb", "LTD-SRC-008")
  , ("source-vendor", "LTD-SRC-009")
  ]

canonicalFirstReintroduction :: Text
canonicalFirstReintroduction = "reject-disguised-or-concealed-source"

extraBinding :: RawBinding
extraBinding = ("LTD-EXTRA-00", "Active", "00", "extra", "extra", "extra", ["extra"])

maximumId, excessiveId, maximumDisposition, excessiveDisposition, excessiveOwner :: Text
maximumId = Text.replicate 12 "i"
excessiveId = Text.replicate 13 "i"
maximumDisposition = Text.replicate 8 "d"
excessiveDisposition = Text.replicate 9 "d"
excessiveOwner = Text.replicate 3 "0"

maximumAnalyzer, excessiveAnalyzer, maximumObservation, excessiveObservation :: Text
maximumAnalyzer = Text.replicate 64 "a"
excessiveAnalyzer = Text.replicate 65 "a"
maximumObservation = Text.replicate 64 "o"
excessiveObservation = Text.replicate 65 "o"

maximumClosure, excessiveClosure, maximumReintroduction, excessiveReintroduction :: Text
maximumClosure = Text.replicate 64 "c"
excessiveClosure = Text.replicate 65 "c"
maximumReintroduction = Text.replicate 64 "r"
excessiveReintroduction = Text.replicate 65 "r"

maximumJoinSource, excessiveJoinSource, maximumJoinTarget, excessiveJoinTarget :: Text
maximumJoinSource = Text.replicate 32 "s"
excessiveJoinSource = Text.replicate 33 "s"
maximumJoinTarget = Text.replicate 12 "t"
excessiveJoinTarget = Text.replicate 13 "t"

aggregateExcessJoins :: [RawJoin]
aggregateExcessJoins = mapLastJoin (\(source, target) -> (source <> "x", target)) canonicalJoins

duplicateBindings, unknownBindings, outOfOrderBindings :: [RawBinding]
duplicateBindings = take 24 canonicalBindings
  <> [("LTD-SEED-001", "Active", "93", "jitml-seed-dependency", "jitml-dependency-graph",
       "jitml-seed-dependency", ["reject-jitml-seed-dependency"])]
unknownBindings = take 24 canonicalBindings
  <> [("LTD-SEED-999", "Active", "93", "jitml-seed-dependency", "jitml-dependency-graph",
       "jitml-seed-dependency", ["reject-jitml-seed-dependency"])]
outOfOrderBindings = swapFirstTwo canonicalBindings

resourceBindingRowPrecedence, resourceBindingClassPrecedence, resourceBindingFieldPrecedence :: [RawBinding]
resourceBindingRowPrecedence =
  mapBindingAt 2 (setBindingDisposition excessiveDisposition)
    (mapBindingAt 1 (setBindingId excessiveId) canonicalBindings)
resourceBindingClassPrecedence = mapBindingAt 1 (setBindingId excessiveId) canonicalBindings
resourceBindingFieldPrecedence =
  mapBindingAt 1 (setBindingDisposition excessiveDisposition . setBindingId excessiveId) canonicalBindings

bindingFieldPrecedence, bindingRowPrecedence :: [RawBinding]
bindingFieldPrecedence =
  mapBindingAt 1 (setBindingOwner "0x" . setBindingDisposition "Activx") canonicalBindings
bindingRowPrecedence =
  mapBindingAt 2 (setBindingOwner "0x")
    (mapBindingAt 1 (setBindingDisposition "Activx") canonicalBindings)

bindingDuplicateSearchPrecedence, bindingUnknownSearchPrecedence :: [RawBinding]
bindingDuplicateSearchPrecedence =
  mapBindingAt 4 (setBindingId "LTD-SRC-001")
    (mapBindingAt 3 (setBindingId "LTD-SRC-000") canonicalBindings)
bindingUnknownSearchPrecedence =
  mapBindingAt 25 (setBindingId "UNKNOWN-B")
    (mapBindingAt 1 (setBindingId "UNKNOWN-A") canonicalBindings)

duplicateJoins, unknownJoins, outOfOrderJoins :: [RawJoin]
duplicateJoins = take 8 canonicalJoins <> [("source-test", "LTD-SRC-009")]
unknownJoins = take 8 canonicalJoins <> [("source-vendox", "LTD-SRC-009")]
outOfOrderJoins = swapFirstTwo canonicalJoins

resourceJoinRowPrecedence, resourceJoinClassPrecedence, resourceJoinFieldPrecedence :: [RawJoin]
resourceJoinRowPrecedence =
  mapJoinAt 2 (setJoinTarget excessiveJoinTarget)
    (mapJoinAt 1 (setJoinSource excessiveJoinSource) canonicalJoins)
resourceJoinClassPrecedence = mapJoinAt 1 (setJoinSource excessiveJoinSource) canonicalJoins
resourceJoinFieldPrecedence =
  mapJoinAt 1 (setJoinTarget excessiveJoinTarget . setJoinSource excessiveJoinSource) canonicalJoins

joinRowPrecedence, joinDuplicateSearchPrecedence, joinUnknownSearchPrecedence :: [RawJoin]
joinRowPrecedence =
  mapJoinAt 2 (setJoinTarget "LTD-SRC-00y")
    (mapJoinAt 1 (setJoinTarget "LTD-SRC-00x") canonicalJoins)
joinDuplicateSearchPrecedence =
  mapJoinAt 7 (setJoinSource "source-dhall")
    (mapJoinAt 3 (setJoinSource "source-tools") canonicalJoins)
joinUnknownSearchPrecedence =
  mapJoinAt 9 (setJoinSource "unknown-two22")
    (mapJoinAt 1 (setJoinSource "unknown-one1") canonicalJoins)

swapFirstTwo :: [value] -> [value]
swapFirstTwo values = case values of
  first : second : rest -> second : first : rest
  _ -> values

mapFirstBinding :: (RawBinding -> RawBinding) -> [RawBinding] -> [RawBinding]
mapFirstBinding transform values = case values of
  [] -> []
  first : rest -> transform first : rest

mapFirstJoin :: (RawJoin -> RawJoin) -> [RawJoin] -> [RawJoin]
mapFirstJoin transform values = case values of
  [] -> []
  first : rest -> transform first : rest

mapBindingAt :: Int -> (RawBinding -> RawBinding) -> [RawBinding] -> [RawBinding]
mapBindingAt target transform = go 1
 where
  go _ [] = []
  go ordinal (value : rest)
    | ordinal == target = transform value : rest
    | otherwise = value : go (ordinal + 1) rest

mapJoinAt :: Int -> (RawJoin -> RawJoin) -> [RawJoin] -> [RawJoin]
mapJoinAt target transform = go 1
 where
  go _ [] = []
  go ordinal (value : rest)
    | ordinal == target = transform value : rest
    | otherwise = value : go (ordinal + 1) rest

mapLastJoin :: (RawJoin -> RawJoin) -> [RawJoin] -> [RawJoin]
mapLastJoin transform values = case values of
  [] -> []
  first : rest -> case rest of
    [] -> [transform first]
    _ -> first : mapLastJoin transform rest

setBindingId, setBindingDisposition, setBindingOwner, setBindingAnalyzer :: Text -> RawBinding -> RawBinding
setBindingId value (_, disposition, owner, analyzer, observed, closed, reintroduced) =
  (value, disposition, owner, analyzer, observed, closed, reintroduced)
setBindingDisposition value (identifier, _, owner, analyzer, observed, closed, reintroduced) =
  (identifier, value, owner, analyzer, observed, closed, reintroduced)
setBindingOwner value (identifier, disposition, _, analyzer, observed, closed, reintroduced) =
  (identifier, disposition, value, analyzer, observed, closed, reintroduced)
setBindingAnalyzer value (identifier, disposition, owner, _, observed, closed, reintroduced) =
  (identifier, disposition, owner, value, observed, closed, reintroduced)

setBindingObservation, setBindingClosure :: Text -> RawBinding -> RawBinding
setBindingObservation value (identifier, disposition, owner, analyzer, _, closed, reintroduced) =
  (identifier, disposition, owner, analyzer, value, closed, reintroduced)
setBindingClosure value (identifier, disposition, owner, analyzer, observed, _, reintroduced) =
  (identifier, disposition, owner, analyzer, observed, value, reintroduced)

setBindingReintroduction :: [Text] -> RawBinding -> RawBinding
setBindingReintroduction value (identifier, disposition, owner, analyzer, observed, closed, _) =
  (identifier, disposition, owner, analyzer, observed, closed, value)

setJoinSource, setJoinTarget :: Text -> RawJoin -> RawJoin
setJoinSource value (_, target) = (value, target)
setJoinTarget value (source, _) = (source, value)

bindingId :: RawBinding -> Text
bindingId (identifier, _, _, _, _, _, _) = identifier

renderBinding :: RawBinding -> Text
renderBinding (identifier, disposition, owner, analyzer, observed, closed, reintroduced) =
  Text.intercalate "|" [identifier, disposition, owner, analyzer, observed, closed, Text.intercalate "," reintroduced]

aggregateBytes :: [RawBinding] -> [RawJoin] -> Int
aggregateBytes bindings joins =
  sum [sum (map textBytes [identifier, disposition, owner, analyzer, observed, closed])
         + sum (map textBytes reintroduced)
      | (identifier, disposition, owner, analyzer, observed, closed, reintroduced) <- bindings]
    + sum [textBytes source + textBytes target | (source, target) <- joins]

textBytes :: Text -> Int
textBytes = ByteString.length . TextEncoding.encodeUtf8

completeDigest :: Text -> [RawBinding] -> [RawJoin] -> Text
completeDigest phase bindings joins =
  sha256Hex (ByteString.concat
    ( ["amoebius-legacy-input-v1\0", lengthText phase, lengthText (Text.pack (show (length bindings)))]
        <> concatMap digestBinding bindings
        <> [lengthText (Text.pack (show (length joins)))]
        <> concatMap digestJoin joins
    ))

digestBinding :: RawBinding -> [ByteString]
digestBinding (identifier, disposition, owner, analyzer, observed, closed, reintroduced) =
  map lengthText [identifier, disposition, owner, analyzer, observed, closed]
    <> (lengthText (Text.pack (show (length reintroduced))) : map lengthText reintroduced)

digestJoin :: RawJoin -> [ByteString]
digestJoin (source, target) = [lengthText source, lengthText target]

boundedDigest :: Text -> [RawBinding] -> [RawJoin] -> Text -> Text
boundedDigest phase bindings joins problemTag =
  sha256Hex (ByteString.concat
    ( "amoebius-legacy-bounded-refusal-v1\0"
        : boundedText maximumPhaseBytes phase
        : lengthText bindingState
        : concatMap boundedBinding boundedBindings
        <> [lengthText joinState]
        <> concatMap boundedJoin boundedJoins
        <> [lengthText problemTag]
    ))
 where
  (bindingState, boundedBindings) = boundedState maximumBindings bindings
  (joinState, boundedJoins) = boundedState maximumJoins joins

boundedState :: Int -> [value] -> (Text, [value])
boundedState limit = go 0 []
 where
  go count reversed values = case values of
    [] -> ("within:" <> Text.pack (show count), reverse reversed)
    value : rest
      | count == limit -> ("exceeded-at-least:" <> Text.pack (show (limit + 1)), reverse reversed)
      | otherwise -> go (count + 1) (value : reversed) rest

boundedBinding :: RawBinding -> [ByteString]
boundedBinding (identifier, disposition, owner, analyzer, observed, closed, reintroduced) =
  [ boundedText maximumIdBytes identifier
  , boundedText maximumDispositionBytes disposition
  , boundedText maximumOwnerBytes owner
  , boundedText maximumAnalyzerBytes analyzer
  , boundedText maximumObservationBytes observed
  , boundedText maximumClosureBytes closed
  , lengthText reintroductionState
  ]
    <> map (boundedText maximumReintroductionBytes) boundedReintroduced
 where
  (reintroductionState, boundedReintroduced) = boundedState maximumReintroductionValues reintroduced

boundedJoin :: RawJoin -> [ByteString]
boundedJoin (source, target) = [boundedText maximumJoinSourceBytes source, boundedText maximumJoinTargetBytes target]

boundedText :: Int -> Text -> ByteString
boundedText limit value = lengthText (go 0 "" value)
 where
  go count prefix remaining = case Text.uncons remaining of
    Nothing -> "within:" <> prefix
    Just (character, rest) ->
      let next = count + textBytes (Text.singleton character)
       in if next > limit
            then "exceeded-at-least:" <> Text.pack (show next) <> ":" <> prefix
            else go next (Text.snoc prefix character) rest

lengthText :: Text -> ByteString
lengthText value =
  let bytes = TextEncoding.encodeUtf8 value
   in ByteString8.pack (show (ByteString.length bytes)) <> ":" <> bytes

sha256Hex :: ByteString -> Text
sha256Hex = Text.pack . show . Crypto.hashWith Crypto.SHA256

literalInternalProjectionDigest :: Text -> Text -> Text
literalInternalProjectionDigest key wire =
  sha256Hex
    ( ByteString.concat
        [ "amoebius-legacy-internal-projection-v1\0"
        , TextEncoding.encodeUtf8 key
        , "\0"
        , TextEncoding.encodeUtf8 wire
        ]
    )
