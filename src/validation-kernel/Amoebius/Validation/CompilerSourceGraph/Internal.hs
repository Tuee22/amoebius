{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.CompilerSourceGraph.Internal
  ( AcquiredCompilerFacts
  , AcquiredCompilerRunPlan
  , AcquiredCompilerSourceGraph
  , CompilerAcquisitionProblem
  , CompilerFailureStage
  , CompilerObservedOutcome
  , CompilerOutputStream
  , CompilerProcessTranscript
  , CompilerProcessTermination
  , CompilerResourceLimit
  , CompilerRunKey
  , CompilerRunExpectation
  , CompilerRunWitness
  , CompilerSourceAttempt
  , acquireCompilerSourceGraph
  , acquiredCompilerSnapshotIdentity
  , acquiredCompilerSourceCheck
  , analyzeAcquiredCompilerSourceGraph
  , compilerAcquisitionProblemCode
  , compilerAcquisitionProblemSnapshotIdentity
  , compilerSourceAttemptDiagnostic
  , compilerSourceAttemptCheck
  , compilerSourceAttemptProblems
  , foldAcquiredCompilerFacts
  , foldAcquiredCompilerRunPlan
  , foldCompilerProcessTranscript
  , foldCompilerRunKey
  , foldCompilerRunWitness
  , foldCompilerSourceAttempt
  , rawCompilerSourceGraphDiagnostic
#if defined(VALIDATION_SOURCE_CLOSURE_INTERNAL_TEST_ACQUIRE)
  , compilerSourceInternalTestAcquiredBranchProblems
  , compilerSourceInternalTestClosedGraphProblems
  , compilerSourceInternalTestTypedBindingProjection
#endif
  ) where

import Amoebius.Validation.SourceClosure.Internal
  ( AcquiredSourceSnapshot
  , SourceSnapshot (snapshotEntries, snapshotIdentity)
  , acquiredSourceSnapshot
  )
import Amoebius.Validation.CompilerSubjectRegistry.Internal
  ( CompilerSubjectContractProblem
  , acquireCompilerSubjectContract
  , compilerSubjectContractDigest
  , compilerSubjectRegistryCheck
  , deriveCompilerSubjectRegistry
  )
import Amoebius.Validation.SourceConsumerGraph.Internal
  ( RequiredCompilerFact (..)
  , analyzeSourceConsumerGraph
  , sourceConsumerGraphCheck
  )
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding
  , Observation (..)
  , finding
  , findingCode
  , observation
  )
import Crypto.Hash qualified as Crypto
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteString8
import Data.Char (isAsciiLower, isAsciiUpper, ord, toLower)
import Data.List (group, isPrefixOf, sort)
import Data.List qualified as List
import Data.List.NonEmpty (NonEmpty (..))
import Data.List.NonEmpty qualified as NonEmpty
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import System.FilePath (isAbsolute, takeExtension)

-- These are diagnostic-fixture ceilings, not acquired-repository ceilings.
-- Every applicable bound is checked before splitting, sorting, hashing, or
-- constructing maps and semantic values.
maximumRawIdentityBytes, maximumRawEntries, maximumRawPathBytes :: Int
#if defined(VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_LIMIT_WIDEN_MUTANT)
maximumRawIdentityBytes = 65
#else
maximumRawIdentityBytes = 64
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_ENTRY_LIMIT_WIDEN_MUTANT)
maximumRawEntries = 129
#else
maximumRawEntries = 128
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_LIMIT_WIDEN_MUTANT)
maximumRawPathBytes = 1025
#else
maximumRawPathBytes = 1024
#endif

maximumRawPathDepth, maximumRawPathSegmentBytes, maximumRawModeBytes :: Int
#if defined(VALIDATION_COMPILER_GRAPH_RAW_DEPTH_LIMIT_WIDEN_MUTANT)
maximumRawPathDepth = 65
#else
maximumRawPathDepth = 64
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_SEGMENT_LIMIT_WIDEN_MUTANT)
maximumRawPathSegmentBytes = 256
#else
maximumRawPathSegmentBytes = 255
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_MODE_LIMIT_WIDEN_MUTANT)
maximumRawModeBytes = 7
#else
maximumRawModeBytes = 6
#endif

maximumRawObjectIdentityBytes, maximumRawBlobBytes, maximumRawAggregateBlobBytes :: Int
#if defined(VALIDATION_COMPILER_GRAPH_RAW_OBJECT_LIMIT_WIDEN_MUTANT)
maximumRawObjectIdentityBytes = 65
#else
maximumRawObjectIdentityBytes = 64
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_BLOB_LIMIT_WIDEN_MUTANT)
maximumRawBlobBytes = 65537
#else
maximumRawBlobBytes = 65536
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_AGGREGATE_LIMIT_WIDEN_MUTANT)
maximumRawAggregateBlobBytes = 262145
#else
maximumRawAggregateBlobBytes = 262144
#endif

maximumRawHaskellSubjects, maximumRawCabalEntries :: Int
#if defined(VALIDATION_COMPILER_GRAPH_RAW_HASKELL_LIMIT_WIDEN_MUTANT)
maximumRawHaskellSubjects = 65
#else
maximumRawHaskellSubjects = 64
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_CABAL_LIMIT_WIDEN_MUTANT)
maximumRawCabalEntries = 5
#else
maximumRawCabalEntries = 4
#endif

-- This is a separate repository-scale ceiling for the opaque acquired path;
-- it is not the 128-row caller-fixture ceiling.  SourceClosure must establish
-- its own path/blob/aggregate invariants before it can mint the opaque input.
maximumAcquiredCompilerEntries :: Int
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_ENTRY_LIMIT_WIDEN_MUTANT)
maximumAcquiredCompilerEntries = 16385
#else
maximumAcquiredCompilerEntries = 16384
#endif

-- | The stage at which a compile-negative row is expected to be rejected.
-- A non-zero process exit is not evidence of a compiler refusal unless the
-- independently planned stage and diagnostic identity are also observed.
data CompilerFailureStage
  = CompilerParseFailure
  | CompilerRenameFailure
  | CompilerTypecheckFailure
  deriving (Eq, Ord, Show)

-- | Branch-specific authority attached to a planned compiler row.  Success
-- has no diagnostic payload.  Refusal is bound to an exact compiler stage and
-- diagnostic digest.  A fixture is bound to its harness, case, expected result
-- digest, and exact expected exit status.
data CompilerRunExpectation
  = CompilerSuccessExpectation
  | CompilerRefusalExpectation CompilerFailureStage Text
  | CompilerFixtureExpectation Text Text Text Int
  deriving (Eq, Ord, Show)

-- | The immutable identity of one required compiler run.  A row is not merely
-- a source path: the same blob can participate in multiple Cabal components
-- and flag configurations; generated inputs and exact compiler argv can also
-- change the compiled program; and each outcome branch has different required
-- evidence.  Keeping every dimension in one opaque key prevents later
-- evidence from being replayed across any of those boundaries.
data CompilerRunKey
  = CompilerRunKey
      Text
      FilePath
      Text
      Text
      Text
      Text
      Text
      CompilerRunExpectation
  deriving (Eq, Ord, Show)

-- | The outcome observed by the compiler supervisor.  It is deliberately
-- distinct from the outcome required by the registry key: the verifier must
-- compare the two instead of treating an expectation as an observation.
data CompilerObservedOutcome
  = CompilerObservedSuccess
  | CompilerObservedRefusal
  | CompilerObservedFixture
  deriving (Eq, Ord, Show)

-- | A process can terminate normally, by signal, or because the supervisor
-- stopped it at one of its independent boundaries.  These cases must never be
-- collapsed into the non-zero exit required by an intentional compiler
-- refusal.
data CompilerResourceLimit
  = CompilerCpuLimit
  | CompilerMemoryLimit
  | CompilerFilesystemLimit
  | CompilerProcessLimit
  deriving (Eq, Ord, Show)

data CompilerOutputStream
  = CompilerStdout
  | CompilerStderr
  deriving (Eq, Ord, Show)

data CompilerProcessTermination
  = CompilerExited Int
  | CompilerSignalled Int
  | CompilerTimedOut
  | CompilerResourceLimited CompilerResourceLimit
  | CompilerOutputLimited CompilerOutputStream
  | CompilerSpawnFailed
  deriving (Eq, Ord, Show)

-- | Bounded process evidence for one exact compiler row.  Output bytes are
-- retained by length and digest rather than as unbounded text.  A successful
-- compile must name the resulting object or executable identity; a refusal or
-- fixture observation must not.  The final digest binds the independently
-- observed time, memory, filesystem, and process-identity limits.
data CompilerProcessTranscript
  = CompilerProcessTranscript
      CompilerProcessTermination
      Int
      Text
      Int
      Text
      (Maybe Text)
      Text
  deriving (Eq, Show)

-- | Compiler observations are separate constructors because the three
-- branches have different evidence obligations.  Only a success may carry
-- the complete semantic-fact universe.  Refusal must carry the observed
-- compiler stage and diagnostic digest.  A fixture carries the observed
-- harness, case, and result digest.
data CompilerRunWitness
  = CompilerSuccessWitness
      CompilerRunKey
      Text
      Text
      Text
      CompilerProcessTranscript
      [RequiredCompilerFact]
  | CompilerRefusalWitness
      CompilerRunKey
      Text
      Text
      Text
      CompilerProcessTranscript
      CompilerFailureStage
      Text
  | CompilerFixtureWitness
      CompilerRunKey
      Text
      Text
      Text
      CompilerProcessTranscript
      Text
      Text
      Text
  deriving (Eq, Show)

-- | The expected run inventory belongs to the independently acquired
-- elaborated-plan authority, not to the execution producer.  The plan identity
-- is rebound into every witness below, so a producer cannot declare its own
-- witness list to be complete merely by repeating the same keys twice.
data AcquiredCompilerRunPlan
  = AcquiredCompilerRunPlan Text Text [CompilerRunKey]
  deriving (Eq, Show)

-- | Complete compiler facts are a separate opaque execution product.  Source
-- acquisition and diagnostic caller input cannot construct this value, and
-- its inventory is supplied by 'AcquiredCompilerRunPlan'.
data AcquiredCompilerFacts
  = AcquiredCompilerFacts AcquiredCompilerRunPlan [CompilerRunWitness]
  deriving (Eq, Show)

-- | Typed reasons why the acquisition boundary refused to mint compiler
-- facts.  Every problem remains bound to the exact source snapshot.  The
-- toolchain case intentionally names an absent verified authority root rather
-- than blessing locally observed checksums.
data CompilerAcquisitionProblem
  = CompilerGraphFactsUnavailable Text
  | CompilerSubjectOutcomeRegistryUnavailable Text
  | CompilerSubjectContractRejected Text Text FilePath Text
  | CompilerElaboratedMultiRunUnavailable Text
  | CompilerToolchainAuthorityUnavailable Text
  | CompilerExecutionSupervisionUnavailable Text
  | CompilerSemanticClosureUnavailable Text
  deriving (Eq, Ord, Show)

-- | A refusal retains the diagnostic refusal graph.  An acquired attempt uses
-- a different closed type, minted only after the exact acquired check name and
-- an empty finding set have been verified.  This prevents the acquired branch
-- from inheriting the SourceConsumer/refusal residue which production still
-- reports while no compiler producer exists.
data CompilerSourceAttempt
  = CompilerSourceRefused
      AcquiredCompilerSourceGraph
      (NonEmpty CompilerAcquisitionProblem)
  | CompilerSourceAcquired
      ClosedCompilerSourceGraph
      AcquiredCompilerFacts
  deriving (Eq, Show)

data AcquiredCompilerSourceGraph
  = AcquiredCompilerSourceGraph Text CheckResult
  deriving (Eq, Show)

data ClosedCompilerSourceGraph
  = ClosedCompilerSourceGraph Text CheckResult
  deriving (Eq, Show)

closedCompilerSourceCheckName :: Text
closedCompilerSourceCheckName = "acquired-compiler-source-graph"

closeCompilerSourceGraph
  :: AcquiredCompilerSourceGraph
  -> Either Finding ClosedCompilerSourceGraph
closeCompilerSourceGraph (AcquiredCompilerSourceGraph identity result)
  | checkName result /= closedCompilerSourceCheckName =
      Left
        ( acquiredCompilerFinding
            "SRC-COMPILER-ACQUIRED-DIAGNOSTIC-NOT-CLOSED"
            "the acquired branch diagnostic does not have the exact closed-graph check name"
        )
  | not (null (checkFindings result)) =
      Left
        ( acquiredCompilerFinding
            "SRC-COMPILER-ACQUIRED-DIAGNOSTIC-NOT-CLOSED"
            "the acquired branch diagnostic retains refusal or other findings"
        )
  | otherwise = Right (ClosedCompilerSourceGraph identity result)

projectClosedCompilerSourceGraph
  :: ClosedCompilerSourceGraph
  -> AcquiredCompilerSourceGraph
projectClosedCompilerSourceGraph (ClosedCompilerSourceGraph identity result) =
  AcquiredCompilerSourceGraph identity result

-- | Eliminate an attempt without exposing either constructor.  Package
-- consumers may render or route a refusal, but cannot turn it into acquired
-- facts.
foldCompilerSourceAttempt
  :: (AcquiredCompilerSourceGraph -> NonEmpty CompilerAcquisitionProblem -> result)
  -> (AcquiredCompilerSourceGraph -> AcquiredCompilerFacts -> result)
  -> CompilerSourceAttempt
  -> result
foldCompilerSourceAttempt onRefused onAcquired attempt =
  case attempt of
    CompilerSourceRefused diagnostic problems -> onRefused diagnostic problems
    CompilerSourceAcquired closed facts ->
      onAcquired (projectClosedCompilerSourceGraph closed) facts

compilerSourceAttemptDiagnostic :: CompilerSourceAttempt -> AcquiredCompilerSourceGraph
compilerSourceAttemptDiagnostic =
  foldCompilerSourceAttempt (\diagnostic _ -> diagnostic) (\diagnostic _ -> diagnostic)

-- | Branch-sensitive gate projection.  Consumers which decide a candidate
-- must use this projection rather than detaching the diagnostic graph: a
-- refused attempt remains red even if a future diagnostic regression drops
-- one of its ordinary findings, and the acquired branch must retain a
-- non-empty fact set bound to the same snapshot as the diagnostic.
compilerSourceAttemptCheck :: CompilerSourceAttempt -> CheckResult
compilerSourceAttemptCheck =
  foldCompilerSourceAttempt refused acquired
 where
  refused diagnostic problems =
    let result = acquiredCompilerSourceCheck diagnostic
        existingCodes = map findingCode (checkFindings result)
        retainedProblems =
          [ finding
              (compilerAcquisitionProblemCode problem)
              "compiler-source-acquisition"
              (compilerAcquisitionProblemDetail problem)
          | problem <- NonEmpty.toList problems
          , compilerAcquisitionProblemCode problem `notElem` existingCodes
          ]
     in result
          { checkObservations =
              checkObservations result
                <> [observation "compiler-source-attempt" "refused"]
          , checkFindings = checkFindings result <> retainedProblems
          }
  acquired diagnostic facts =
    let result = acquiredCompilerSourceCheck diagnostic
        diagnosticIdentity = acquiredCompilerSnapshotIdentity diagnostic
        (plan, witnesses) = foldAcquiredCompilerFacts (,) facts
        (planSnapshot, planIdentity, expectedKeys) =
          foldAcquiredCompilerRunPlan (,,) plan
        witnessedKeys = map compilerRunWitnessKey witnesses
        factProblems =
          [ finding
              "SRC-COMPILER-ACQUIRED-PLAN-SNAPSHOT"
              "compiler-source-acquisition"
              "the acquired compiler run plan does not name the diagnostic source snapshot"
          | planSnapshot /= diagnosticIdentity
          ]
            <> [ finding
                   "SRC-COMPILER-ACQUIRED-PLAN-IDENTITY"
                   "compiler-source-acquisition"
                   "the independent acquired compiler run-plan identity is not lowercase SHA-256"
               | not (compilerHexIdentity 64 planIdentity)
               ]
            <> acquiredCompilerInventoryProblems expectedKeys witnessedKeys
            <> concatMap
              (acquiredCompilerRunProblems diagnosticIdentity planIdentity)
              (zip [(1 :: Int) ..] witnesses)
     in result
          { checkObservations =
              checkObservations result
                <> [observation "compiler-source-attempt" "acquired"]
          , checkFindings = checkFindings result <> factProblems
          }

acquiredCompilerInventoryProblems :: [CompilerRunKey] -> [CompilerRunKey] -> [Finding]
acquiredCompilerInventoryProblems expectedKeys witnessedKeys =
  [ acquiredCompilerFinding
      "SRC-COMPILER-ACQUIRED-RUN-UNIVERSE-EMPTY"
      "the acquired compiler run-key universe is empty"
  | null expectedKeys
  ]
    <> [ acquiredCompilerFinding
           "SRC-COMPILER-ACQUIRED-RUN-KEY-DUPLICATE"
           "the acquired compiler run-key universe contains a duplicate"
       | hasDuplicates expectedKeys
       ]
    <> [ acquiredCompilerFinding
           "SRC-COMPILER-ACQUIRED-WITNESS-KEY-DUPLICATE"
           "the acquired compiler witness inventory contains a duplicate run key"
       | hasDuplicates witnessedKeys
       ]
    <> [ acquiredCompilerFinding
           "SRC-COMPILER-ACQUIRED-RUN-INVENTORY-MISMATCH"
           "the ordered supervised witness keys do not exactly equal the acquired run-key universe"
       | expectedKeys /= witnessedKeys
       ]

compilerRunWitnessKey :: CompilerRunWitness -> CompilerRunKey
compilerRunWitnessKey witness =
  foldCompilerRunWitness
    (\key _ _ _ _ _ -> key)
    (\key _ _ _ _ _ _ -> key)
    (\key _ _ _ _ _ _ _ -> key)
    witness

acquiredCompilerRunProblems :: Text -> Text -> (Int, CompilerRunWitness) -> [Finding]
acquiredCompilerRunProblems expectedSnapshot expectedPlanIdentity (ordinal, witness) =
  foldCompilerRunWitness inspectSuccess inspectRefusal inspectFixture witness
 where
  inspectSuccess key elaboration toolchainAuthority supervisor transcript facts =
    foldCompilerRunKey (inspectKey elaboration toolchainAuthority supervisor) key
      <> successEvidenceProblems key transcript facts
  inspectRefusal key elaboration toolchainAuthority supervisor transcript observedStage observedDiagnostic =
    foldCompilerRunKey (inspectKey elaboration toolchainAuthority supervisor) key
      <> refusalEvidenceProblems key transcript observedStage observedDiagnostic
  inspectFixture key elaboration toolchainAuthority supervisor transcript observedHarness observedCase observedResult =
    foldCompilerRunKey (inspectKey elaboration toolchainAuthority supervisor) key
      <> fixtureEvidenceProblems key transcript observedHarness observedCase observedResult
  inspectKey elaboration toolchainAuthority supervisor snapshot path objectId component configuration generatedInputs compilerArgv expected =
    [ runFinding "SNAPSHOT" "the compiler run key names a different source snapshot"
    | snapshot /= expectedSnapshot
    ]
      <> [ runFinding "PATH" "the compiler run key path is empty, absolute, or contains a parent/backslash segment"
         | not (compilerRunPathValid path)
         ]
      <> [ runFinding "OBJECT-IDENTITY" "the compiler run key source object identity is not lowercase SHA-1"
         | not (compilerHexIdentity 40 objectId)
         ]
      <> [ runFinding "COMPONENT" "the compiler run key component identity is empty"
         | Text.null component
         ]
      <> identityProblem "CONFIGURATION" configuration
      <> identityProblem "GENERATED-INPUTS" generatedInputs
      <> identityProblem "ARGV" compilerArgv
      <> [ runFinding "ELABORATION" "the compiler witness is not bound to the independent run-plan identity"
         | elaboration /= expectedPlanIdentity
         ]
      <> identityProblem "TOOLCHAIN" toolchainAuthority
      <> identityProblem "SUPERVISOR" supervisor
      <> compilerExpectationProblems expected
  identityProblem suffix value =
    [ runFinding suffix "a compiler authority identity is not lowercase SHA-256"
    | not (compilerHexIdentity 64 value)
    ]
  runFinding suffix detail =
    acquiredCompilerFinding
      ("SRC-COMPILER-ACQUIRED-RUN-" <> suffix)
      (detail <> "; run-ordinal=" <> Text.pack (show ordinal))
  compilerExpectationProblems expected = case expected of
    CompilerSuccessExpectation -> []
    CompilerRefusalExpectation _ diagnosticDigest ->
      [ runFinding "EXPECTED-DIAGNOSTIC" "the planned refusal diagnostic identity is not lowercase SHA-256"
      | not (compilerHexIdentity 64 diagnosticDigest)
      ]
    CompilerFixtureExpectation harness caseLabel resultDigest expectedExit ->
      [ runFinding "EXPECTED-FIXTURE-HARNESS" "the planned fixture harness identity is empty"
      | Text.null harness
      ]
        <> [ runFinding "EXPECTED-FIXTURE-CASE" "the planned fixture case identity is empty"
           | Text.null caseLabel
           ]
        <> [ runFinding "EXPECTED-FIXTURE-RESULT" "the planned fixture result identity is not lowercase SHA-256"
           | not (compilerHexIdentity 64 resultDigest)
           ]
        <> [ runFinding "EXPECTED-FIXTURE-EXIT" "the planned fixture exit status is outside the portable exit-status range"
           | not (compilerExitCodeValid expectedExit)
           ]
  successEvidenceProblems key transcript facts =
    [ runFinding "EVIDENCE-BRANCH" "success evidence is attached to a non-success run key"
    | compilerRunKeyExpectedOutcome key /= CompilerObservedSuccess
    ]
      <> compilerTranscriptProblems ordinal (\termination -> termination == CompilerExited 0) True transcript
      <> [ runFinding "SEMANTIC-FACTS" "the successful compiler witness does not contain the exact complete semantic-fact universe"
         | facts /= requiredCompilerFactUniverse
         ]
  refusalEvidenceProblems key transcript observedStage observedDiagnostic =
    [ runFinding "EVIDENCE-BRANCH" "refusal evidence is attached to a non-refusal run key"
    | compilerRunKeyExpectedOutcome key /= CompilerObservedRefusal
    ]
      <> case compilerRunExpectationDetails key of
        Just (Left (expectedStage, expectedDiagnostic)) ->
          [ runFinding "REFUSAL-STAGE" "the observed compiler refusal stage does not match the independent run plan"
          | observedStage /= expectedStage
          ]
            <> [ runFinding "REFUSAL-DIAGNOSTIC" "the observed compiler diagnostic identity does not match the independent run plan"
               | observedDiagnostic /= expectedDiagnostic
               ]
        _ -> []
      <> [ runFinding "REFUSAL-DIAGNOSTIC" "the observed compiler diagnostic identity is not lowercase SHA-256"
         | not (compilerHexIdentity 64 observedDiagnostic)
         ]
      <> compilerTranscriptProblems ordinal compilerRefusalTermination False transcript
  fixtureEvidenceProblems key transcript observedHarness observedCase observedResult =
    [ runFinding "EVIDENCE-BRANCH" "fixture evidence is attached to a non-fixture run key"
    | compilerRunKeyExpectedOutcome key /= CompilerObservedFixture
    ]
      <> case compilerRunExpectationDetails key of
        Just (Right (expectedHarness, expectedCase, expectedResult, expectedExit)) ->
          [ runFinding "FIXTURE-HARNESS" "the observed fixture harness does not match the independent run plan"
          | observedHarness /= expectedHarness
          ]
            <> [ runFinding "FIXTURE-CASE" "the observed fixture case does not match the independent run plan"
               | observedCase /= expectedCase
               ]
            <> [ runFinding "FIXTURE-RESULT" "the observed fixture result identity does not match the independent run plan"
               | observedResult /= expectedResult
               ]
            <> compilerTranscriptProblems ordinal (\termination -> termination == CompilerExited expectedExit) False transcript
        _ -> compilerTranscriptProblems ordinal (const False) False transcript
      <> [ runFinding "FIXTURE-RESULT" "the observed fixture result identity is not lowercase SHA-256"
         | not (compilerHexIdentity 64 observedResult)
         ]

compilerRunKeyExpectedOutcome :: CompilerRunKey -> CompilerObservedOutcome
compilerRunKeyExpectedOutcome =
  foldCompilerRunKey $ \_ _ _ _ _ _ _ expected -> case expected of
    CompilerSuccessExpectation -> CompilerObservedSuccess
    CompilerRefusalExpectation {} -> CompilerObservedRefusal
    CompilerFixtureExpectation {} -> CompilerObservedFixture

compilerRunExpectationDetails
  :: CompilerRunKey
  -> Maybe
       ( Either
           (CompilerFailureStage, Text)
           (Text, Text, Text, Int)
       )
compilerRunExpectationDetails =
  foldCompilerRunKey $ \_ _ _ _ _ _ _ expected -> case expected of
    CompilerSuccessExpectation -> Nothing
    CompilerRefusalExpectation stage diagnostic -> Just (Left (stage, diagnostic))
    CompilerFixtureExpectation harness caseLabel result expectedExit ->
      Just (Right (harness, caseLabel, result, expectedExit))

compilerRefusalTermination :: CompilerProcessTermination -> Bool
compilerRefusalTermination termination = case termination of
  CompilerExited code -> compilerExitCodeValid code && code /= 0
  _ -> False

compilerExitCodeValid :: Int -> Bool
compilerExitCodeValid code = code >= 0 && code <= 255

compilerTranscriptProblems
  :: Int
  -> (CompilerProcessTermination -> Bool)
  -> Bool
  -> CompilerProcessTranscript
  -> [Finding]
compilerTranscriptProblems ordinal terminationMatches productRequired transcript =
  foldCompilerProcessTranscript inspect transcript
 where
  inspect termination stdoutBytes stdoutDigest stderrBytes stderrDigest productDigest resourceDigest =
    compilerTerminationProblems termination
      <> transcriptStreamProblems "STDOUT" stdoutBytes stdoutDigest
      <> transcriptStreamProblems "STDERR" stderrBytes stderrDigest
      <> [ transcriptFinding "PRODUCT" "the product identity is inconsistent with the evidence branch"
         | not (compilerProductMatches productRequired productDigest)
         ]
      <> [ transcriptFinding "RESOURCE-OBSERVATION" "the compiler resource-limit observation identity is not lowercase SHA-256"
         | not (compilerHexIdentity 64 resourceDigest)
         ]
  compilerTerminationProblems termination
    | terminationMatches termination = []
    | otherwise =
        [ case termination of
            CompilerExited _ -> transcriptFinding "EXIT" "the normal process exit status is inconsistent with the evidence branch"
            CompilerSignalled _ -> transcriptFinding "SIGNAL" "the compiler process was terminated by a signal"
            CompilerTimedOut -> transcriptFinding "TIMEOUT" "the compiler process exceeded its time limit"
            CompilerResourceLimited _ -> transcriptFinding "RESOURCE-LIMIT" "the compiler process exceeded an independently supervised resource limit"
            CompilerOutputLimited _ -> transcriptFinding "OUTPUT-LIMIT" "the compiler process exceeded a bounded output limit"
            CompilerSpawnFailed -> transcriptFinding "SPAWN" "the compiler process could not be started"
        ]
  transcriptStreamProblems label byteCount digest =
    [ transcriptFinding (label <> "-LENGTH") "a compiler transcript stream has a negative or over-limit byte count"
    | byteCount < 0 || byteCount > maximumCompilerTranscriptBytes
    ]
      <> [ transcriptFinding (label <> "-DIGEST") "a compiler transcript stream identity is not lowercase SHA-256"
         | not (compilerHexIdentity 64 digest)
         ]
  transcriptFinding suffix detail =
    acquiredCompilerFinding
      ("SRC-COMPILER-ACQUIRED-TRANSCRIPT-" <> suffix)
      (detail <> "; run-ordinal=" <> Text.pack (show ordinal))

maximumCompilerTranscriptBytes :: Int
maximumCompilerTranscriptBytes = 1024 * 1024

requiredCompilerFactUniverse :: [RequiredCompilerFact]
requiredCompilerFactUniverse =
  [ CompilerParseSucceeded
  , ConditionalPreprocessingClosed
  , CompileTimeExecutionFeaturesAbsent
  , ImportsRenamed
  , CallsResolved
  , IndirectCallsClosed
  , ControlFlowClosed
  , FilesystemEffectsClassified
  , ExternalProcessAndFfiEffectsClassified
  , TrackedContentProvenanceFlowsClosed
  , ProductBehaviourSinksClassified
  , DynamicCodeAndPluginLoadingAbsent
  ]

compilerProductMatches :: Bool -> Maybe Text -> Bool
compilerProductMatches productRequired productDigest = case (productRequired, productDigest) of
  (True, Just digest) -> compilerHexIdentity 64 digest
  (False, Nothing) -> True
  _ -> False

compilerRunPathValid :: FilePath -> Bool
compilerRunPathValid path =
  not (null path)
    && not (isAbsolute path)
    && '\\' `notElem` path
    && all (`notElem` ["", ".", ".."]) (splitCompilerRunPath path)

splitCompilerRunPath :: String -> [String]
splitCompilerRunPath value = case break (== '/') value of
  (segment, []) -> [segment]
  (segment, _ : remaining) -> segment : splitCompilerRunPath remaining

compilerHexIdentity :: Int -> Text -> Bool
compilerHexIdentity width value =
  Text.length value == width
    && Text.all (\character -> (character >= '0' && character <= '9') || (character >= 'a' && character <= 'f')) value

hasDuplicates :: Eq value => [value] -> Bool
hasDuplicates values = length values /= length (List.nub values)

acquiredCompilerFinding :: Text -> Text -> Finding
acquiredCompilerFinding code detail =
  finding code "compiler-source-acquisition" detail

compilerAcquisitionProblemDetail :: CompilerAcquisitionProblem -> Text
compilerAcquisitionProblemDetail problem =
  case problem of
    CompilerGraphFactsUnavailable _ ->
      "the exact compiler-derived source graph facts were not acquired"
    CompilerSubjectOutcomeRegistryUnavailable _ ->
      "the closed subject/outcome registry was not acquired"
    CompilerSubjectContractRejected _ code subject detail ->
      "subject-contract-code="
        <> code
        <> "; subject="
        <> Text.pack subject
        <> "; "
        <> detail
    CompilerElaboratedMultiRunUnavailable _ ->
      "the authenticated elaborated multi-run plan was not acquired"
    CompilerToolchainAuthorityUnavailable _ ->
      "verified toolchain-root authority was not acquired"
    CompilerExecutionSupervisionUnavailable _ ->
      "supervised compiler execution was not acquired"
    CompilerSemanticClosureUnavailable _ ->
      "compiler-derived semantic closure was not acquired"

compilerSourceAttemptProblems :: CompilerSourceAttempt -> [CompilerAcquisitionProblem]
compilerSourceAttemptProblems =
  foldCompilerSourceAttempt
    (\_ problems -> NonEmpty.toList problems)
    (\_ _ -> [])

compilerAcquisitionProblemCode :: CompilerAcquisitionProblem -> Text
compilerAcquisitionProblemCode problem =
  case problem of
    CompilerGraphFactsUnavailable _ -> "SRC-CONSUMER-COMPILER-GRAPH-UNAVAILABLE"
    CompilerSubjectOutcomeRegistryUnavailable _ -> "SRC-COMPILER-SUBJECT-OUTCOME-REGISTRY-UNAVAILABLE"
    CompilerSubjectContractRejected _ code _ _ -> code
    CompilerElaboratedMultiRunUnavailable _ -> "SRC-COMPILER-ELABORATED-MULTI-RUN-UNAVAILABLE"
    CompilerToolchainAuthorityUnavailable _ -> "SRC-COMPILER-TOOLCHAIN-UNAUTHENTICATED"
    CompilerExecutionSupervisionUnavailable _ -> "SRC-COMPILER-EXECUTION-UNSUPERVISED"
    CompilerSemanticClosureUnavailable _ -> "SRC-COMPILER-SEMANTIC-CLOSURE-UNAVAILABLE"

compilerAcquisitionProblemSnapshotIdentity :: CompilerAcquisitionProblem -> Text
compilerAcquisitionProblemSnapshotIdentity problem =
  case problem of
    CompilerGraphFactsUnavailable identity -> identity
    CompilerSubjectOutcomeRegistryUnavailable identity -> identity
    CompilerSubjectContractRejected identity _ _ _ -> identity
    CompilerElaboratedMultiRunUnavailable identity -> identity
    CompilerToolchainAuthorityUnavailable identity -> identity
    CompilerExecutionSupervisionUnavailable identity -> identity
    CompilerSemanticClosureUnavailable identity -> identity

-- | Project a run key only through an eliminator.  In particular there is no
-- constructor or record-update surface which can change a row's expected
-- outcome while retaining its other identities.
foldCompilerRunKey
  :: ( Text
       -> FilePath
       -> Text
       -> Text
       -> Text
       -> Text
       -> Text
       -> CompilerRunExpectation
       -> result
     )
  -> CompilerRunKey
  -> result
foldCompilerRunKey project (CompilerRunKey snapshot path objectId component configuration generatedInputs compilerArgv expected) =
  project snapshot path objectId component configuration generatedInputs compilerArgv expected

foldCompilerRunWitness
  :: ( CompilerRunKey
       -> Text
       -> Text
       -> Text
       -> CompilerProcessTranscript
       -> [RequiredCompilerFact]
       -> result
     )
  -> ( CompilerRunKey
       -> Text
       -> Text
       -> Text
       -> CompilerProcessTranscript
       -> CompilerFailureStage
       -> Text
       -> result
     )
  -> ( CompilerRunKey
       -> Text
       -> Text
       -> Text
       -> CompilerProcessTranscript
       -> Text
       -> Text
       -> Text
       -> result
     )
  -> CompilerRunWitness
  -> result
foldCompilerRunWitness onSuccess onRefusal onFixture witness =
  case witness of
    CompilerSuccessWitness key elaboration toolchainAuthority supervisor transcript facts ->
      onSuccess key elaboration toolchainAuthority supervisor transcript facts
    CompilerRefusalWitness key elaboration toolchainAuthority supervisor transcript stage diagnostic ->
      onRefusal key elaboration toolchainAuthority supervisor transcript stage diagnostic
    CompilerFixtureWitness key elaboration toolchainAuthority supervisor transcript harness caseLabel result ->
      onFixture key elaboration toolchainAuthority supervisor transcript harness caseLabel result

foldCompilerProcessTranscript
  :: ( CompilerProcessTermination
       -> Int
       -> Text
       -> Int
       -> Text
       -> Maybe Text
       -> Text
       -> result
     )
  -> CompilerProcessTranscript
  -> result
foldCompilerProcessTranscript project (CompilerProcessTranscript termination stdoutBytes stdoutDigest stderrBytes stderrDigest productDigest resourceDigest) =
  project termination stdoutBytes stdoutDigest stderrBytes stderrDigest productDigest resourceDigest

foldAcquiredCompilerRunPlan
  :: (Text -> Text -> [CompilerRunKey] -> result)
  -> AcquiredCompilerRunPlan
  -> result
foldAcquiredCompilerRunPlan project (AcquiredCompilerRunPlan snapshot planIdentity expectedKeys) =
  project snapshot planIdentity expectedKeys

foldAcquiredCompilerFacts
  :: (AcquiredCompilerRunPlan -> [CompilerRunWitness] -> result)
  -> AcquiredCompilerFacts
  -> result
foldAcquiredCompilerFacts project (AcquiredCompilerFacts plan witnesses) =
  project plan witnesses

#if defined(VALIDATION_SOURCE_CLOSURE_INTERNAL_TEST_ACQUIRE)
-- Direct-source acquired-branch fixtures.  They are compiled only into the
-- package-hidden oracle and prevent a future producer from relying on a weak
-- "non-empty witness" check while the real acquisition path remains red.
compilerSourceInternalTestAcquiredBranchProblems :: [(Text, [Text])]
compilerSourceInternalTestAcquiredBranchProblems =
  [ ("valid-mixed", codes (acquiredAttempt validPlan validWitnesses))
  , ("empty", codes (acquiredAttempt (testPlan []) []))
  , ("duplicate-plan", codes (acquiredAttempt (testPlan [successKey, successKey]) [successWitness, successWitness]))
  , ("inventory-mismatch", codes (acquiredAttempt (testPlan [successKey]) []))
  , ("run-bindings", codes (acquiredAttempt (testPlan [invalidKey]) [invalidSuccessWitness]))
  , ("success-facts", codes (acquiredAttempt (testPlan [successKey]) [successWitnessWithFacts []]))
  , ("success-product", codes (acquiredAttempt (testPlan [successKey]) [successWitnessWithTranscript (successTranscript Nothing)]))
  , ("refusal-stage", codes (acquiredAttempt (testPlan [refusalKey]) [refusalWitnessWithStage CompilerParseFailure]))
  , ("refusal-diagnostic", codes (acquiredAttempt (testPlan [refusalKey]) [refusalWitnessWithDiagnostic (testDigest '9')]))
  , ("refusal-signal", codes (acquiredAttempt (testPlan [refusalKey]) [refusalWitnessWithTranscript (refusalTranscript (CompilerSignalled 9))]))
  , ("refusal-timeout", codes (acquiredAttempt (testPlan [refusalKey]) [refusalWitnessWithTranscript (refusalTranscript CompilerTimedOut)]))
  , ("refusal-output-limit", codes (acquiredAttempt (testPlan [refusalKey]) [refusalWitnessWithTranscript (refusalTranscript (CompilerOutputLimited CompilerStderr))]))
  , ("fixture-result", codes (acquiredAttempt (testPlan [fixtureKey]) [fixtureWitnessWithResult (testDigest '8')]))
  , ("fixture-exit", codes (acquiredAttempt (testPlan [fixtureKey]) [fixtureWitnessWithTranscript (fixtureTranscript (CompilerExited 1))]))
  , ("wrong-branch", codes (acquiredAttempt (testPlan [refusalKey]) [successWitnessFor refusalKey]))
  ]
 where
  snapshot = Text.replicate 64 "a"
  planIdentity = testDigest 'b'
  diagnostic =
    AcquiredCompilerSourceGraph
      snapshot
      CheckResult
        { checkName = closedCompilerSourceCheckName
        , checkObservations = [observation "compiler-acquired-test" "observed"]
        , checkFindings = []
        }
  closed = case closeCompilerSourceGraph diagnostic of
    Left problem -> error ("compiler internal fixture could not close its clean diagnostic: " <> show problem)
    Right value -> value
  acquiredAttempt plan witnesses =
    CompilerSourceAcquired closed (AcquiredCompilerFacts plan witnesses)
  testPlan keys = AcquiredCompilerRunPlan snapshot planIdentity keys
  validPlan = testPlan [successKey, refusalKey, fixtureKey]
  validWitnesses = [successWitness, refusalWitness, fixtureWitness]
  successKey =
    CompilerRunKey
      snapshot
      "src/validation-kernel/Amoebius/Validation/Types.hs"
      (Text.replicate 40 "1")
      "lib:validation-kernel"
      (testDigest '2')
      (testDigest '3')
      (testDigest '4')
      CompilerSuccessExpectation
  refusalKey =
    CompilerRunKey
      snapshot
      "test/compile-negative/Example.hs"
      (Text.replicate 40 "5")
      "test:compile-negative-example"
      (testDigest '6')
      (testDigest '7')
      (testDigest '8')
      (CompilerRefusalExpectation CompilerTypecheckFailure refusalDiagnostic)
  fixtureKey =
    CompilerRunKey
      snapshot
      "test/validation-kernel/ExampleFixture.hs"
      (Text.replicate 40 "9")
      "test:validation-example-fixture"
      (testDigest 'c')
      (testDigest 'd')
      (testDigest 'e')
      (CompilerFixtureExpectation fixtureHarness fixtureCase fixtureResult 0)
  invalidKey =
    CompilerRunKey
      (testDigest 'f')
      "../Example.hs"
      "not-an-object"
      ""
      "configuration"
      "generated-inputs"
      "argv"
      CompilerSuccessExpectation
  successTranscript productDigest =
    CompilerProcessTranscript
      (CompilerExited 0)
      0
      (testDigest '0')
      0
      (testDigest '1')
      productDigest
      (testDigest '2')
  refusalTranscript termination =
    CompilerProcessTranscript
      termination
      0
      (testDigest '3')
      1
      (testDigest '4')
      Nothing
      (testDigest '5')
  fixtureTranscript termination =
    CompilerProcessTranscript
      termination
      1
      (testDigest '6')
      0
      (testDigest '7')
      Nothing
      (testDigest '8')
  successWitness = successWitnessWithFacts requiredCompilerFactUniverse
  successWitnessWithFacts facts =
    CompilerSuccessWitness
      successKey
      planIdentity
      (testDigest '9')
      (testDigest 'a')
      (successTranscript (Just (testDigest 'b')))
      facts
  successWitnessWithTranscript transcript =
    CompilerSuccessWitness
      successKey
      planIdentity
      (testDigest '9')
      (testDigest 'a')
      transcript
      requiredCompilerFactUniverse
  successWitnessFor key =
    CompilerSuccessWitness
      key
      planIdentity
      (testDigest '9')
      (testDigest 'a')
      (successTranscript (Just (testDigest 'b')))
      requiredCompilerFactUniverse
  invalidSuccessWitness =
    CompilerSuccessWitness
      invalidKey
      "elaboration"
      "toolchain"
      "supervisor"
      (successTranscript (Just (testDigest 'b')))
      requiredCompilerFactUniverse
  refusalDiagnostic = testDigest 'f'
  refusalWitness =
    CompilerRefusalWitness
      refusalKey
      planIdentity
      (testDigest '9')
      (testDigest 'a')
      (refusalTranscript (CompilerExited 1))
      CompilerTypecheckFailure
      refusalDiagnostic
  refusalWitnessWithStage stage =
    CompilerRefusalWitness refusalKey planIdentity (testDigest '9') (testDigest 'a') (refusalTranscript (CompilerExited 1)) stage refusalDiagnostic
  refusalWitnessWithDiagnostic digest =
    CompilerRefusalWitness refusalKey planIdentity (testDigest '9') (testDigest 'a') (refusalTranscript (CompilerExited 1)) CompilerTypecheckFailure digest
  refusalWitnessWithTranscript transcript =
    CompilerRefusalWitness refusalKey planIdentity (testDigest '9') (testDigest 'a') transcript CompilerTypecheckFailure refusalDiagnostic
  fixtureHarness = "validation-example-fixture-harness"
  fixtureCase = "example-fixture-case"
  fixtureResult = testDigest '0'
  fixtureWitness =
    CompilerFixtureWitness
      fixtureKey
      planIdentity
      (testDigest '9')
      (testDigest 'a')
      (fixtureTranscript (CompilerExited 0))
      fixtureHarness
      fixtureCase
      fixtureResult
  fixtureWitnessWithResult result =
    CompilerFixtureWitness fixtureKey planIdentity (testDigest '9') (testDigest 'a') (fixtureTranscript (CompilerExited 0)) fixtureHarness fixtureCase result
  fixtureWitnessWithTranscript transcript =
    CompilerFixtureWitness fixtureKey planIdentity (testDigest '9') (testDigest 'a') transcript fixtureHarness fixtureCase fixtureResult
  codes = map findingCode . checkFindings . compilerSourceAttemptCheck

compilerSourceInternalTestClosedGraphProblems :: [(Text, [Text])]
compilerSourceInternalTestClosedGraphProblems =
  [ ("valid", closeCodes cleanDiagnostic)
  , ("wrong-name", closeCodes (AcquiredCompilerSourceGraph snapshot (cleanResult {checkName = "compiler-source-graph-diagnostic"})))
  , ("retained-finding", closeCodes (AcquiredCompilerSourceGraph snapshot (cleanResult {checkFindings = [finding "REFUSAL" "compiler-source-acquisition" "retained"]})))
  ]
 where
  snapshot = testDigest 'a'
  cleanResult =
    CheckResult
      { checkName = closedCompilerSourceCheckName
      , checkObservations = [observation "compiler-acquired-test" "observed"]
      , checkFindings = []
      }
  cleanDiagnostic = AcquiredCompilerSourceGraph snapshot cleanResult
  closeCodes diagnostic = case closeCompilerSourceGraph diagnostic of
    Left problem -> [findingCode problem]
    Right _ -> []

-- Direct-source test projection.  Constructors stay absent from the package
-- facade and from the packaged internal module; the oracle can nevertheless
-- prove that every authority dimension survives all three opaque layers.
compilerSourceInternalTestTypedBindingProjection :: [(Text, Text)]
compilerSourceInternalTestTypedBindingProjection =
  [ ("success-key", renderKey successKey)
  , ("refusal-key", renderKey refusalKey)
  , ("fixture-key", renderKey fixtureKey)
  , ("success-witness", renderWitness successWitness)
  , ("refusal-witness", renderWitness refusalWitness)
  , ("fixture-witness", renderWitness fixtureWitness)
  , ("acquired-facts", renderFacts facts)
  ]
 where
  snapshot = "snapshot-identity"
  planIdentity = "plan-identity"
  successKey =
    CompilerRunKey
      snapshot
      "src/Example.hs"
      "source-object-identity"
      "lib:example"
      "configuration-identity"
      "generated-input-set-identity"
      "exact-compiler-argv-identity"
      CompilerSuccessExpectation
  refusalKey =
    CompilerRunKey
      snapshot
      "test/compile-negative/Example.hs"
      "source-object-identity"
      "test:compile-negative-example"
      "configuration-identity"
      "generated-input-set-identity"
      "exact-compiler-argv-identity"
      (CompilerRefusalExpectation CompilerTypecheckFailure "expected-diagnostic-identity")
  fixtureKey =
    CompilerRunKey
      snapshot
      "test/ExampleFixture.hs"
      "source-object-identity"
      "test:example-fixture"
      "configuration-identity"
      "generated-input-set-identity"
      "exact-compiler-argv-identity"
      (CompilerFixtureExpectation "fixture-harness" "fixture-case" "expected-result-identity" 0)
  transcript termination productDigest =
    CompilerProcessTranscript
      termination
      1
      "stdout-identity"
      2
      "stderr-identity"
      productDigest
      "resource-observation-identity"
  successWitness =
    CompilerSuccessWitness
      successKey
      planIdentity
      "verified-toolchain-root-identity"
      "supervisor-observation-identity"
      (transcript (CompilerExited 0) (Just "product-identity"))
      [CompilerParseSucceeded, ConditionalPreprocessingClosed]
  refusalWitness =
    CompilerRefusalWitness
      refusalKey
      planIdentity
      "verified-toolchain-root-identity"
      "supervisor-observation-identity"
      (transcript (CompilerExited 1) Nothing)
      CompilerTypecheckFailure
      "expected-diagnostic-identity"
  fixtureWitness =
    CompilerFixtureWitness
      fixtureKey
      planIdentity
      "verified-toolchain-root-identity"
      "supervisor-observation-identity"
      (transcript (CompilerExited 0) Nothing)
      "fixture-harness"
      "fixture-case"
      "expected-result-identity"
  facts =
    AcquiredCompilerFacts
      (AcquiredCompilerRunPlan snapshot planIdentity [successKey, refusalKey, fixtureKey])
      [successWitness, refusalWitness, fixtureWitness]
  renderExpectation expected = case expected of
    CompilerSuccessExpectation -> "success"
    CompilerRefusalExpectation stage diagnostic ->
      Text.intercalate ":" ["refusal", Text.pack (show stage), diagnostic]
    CompilerFixtureExpectation harness caseLabel result exitCode ->
      Text.intercalate ":" ["fixture", harness, caseLabel, result, Text.pack (show exitCode)]
  renderKey =
    foldCompilerRunKey $ \snapshotIdentity path objectId component configuration generatedInputs compilerArgv expected ->
      Text.intercalate
        "\t"
        [ snapshotIdentity
        , Text.pack path
        , objectId
        , component
        , configuration
        , generatedInputs
        , compilerArgv
        , renderExpectation expected
        ]
  renderWitness =
    foldCompilerRunWitness
      (\runKey elaboration toolchainAuthority supervisor processTranscript compilerFacts ->
        Text.intercalate "\t" ["success", renderKey runKey, elaboration, toolchainAuthority, supervisor, renderTranscript processTranscript, Text.intercalate "," (map (Text.pack . show) compilerFacts)]
      )
      (\runKey elaboration toolchainAuthority supervisor processTranscript stage diagnostic ->
        Text.intercalate "\t" ["refusal", renderKey runKey, elaboration, toolchainAuthority, supervisor, renderTranscript processTranscript, Text.pack (show stage), diagnostic]
      )
      (\runKey elaboration toolchainAuthority supervisor processTranscript harness caseLabel result ->
        Text.intercalate "\t" ["fixture", renderKey runKey, elaboration, toolchainAuthority, supervisor, renderTranscript processTranscript, harness, caseLabel, result]
      )
  renderTranscript =
    foldCompilerProcessTranscript $ \termination stdoutBytes stdoutDigest stderrBytes stderrDigest productDigest resourceDigest ->
      Text.intercalate
        ":"
        [ Text.pack (show termination)
        , Text.pack (show stdoutBytes)
        , stdoutDigest
        , Text.pack (show stderrBytes)
        , stderrDigest
        , maybe "none" id productDigest
        , resourceDigest
        ]
  renderFacts =
    foldAcquiredCompilerFacts $ \plan witnesses ->
      foldAcquiredCompilerRunPlan
        (\snapshotIdentity acquiredPlanIdentity expectedKeys ->
          Text.intercalate
            "\t"
            [ snapshotIdentity
            , acquiredPlanIdentity
            , Text.intercalate ";" (map renderKey expectedKeys)
            , Text.intercalate ";" (map renderWitness witnesses)
            ]
        )
        plan

testDigest :: Char -> Text
testDigest character = Text.replicate 64 (Text.singleton character)
#endif

acquiredCompilerSnapshotIdentity :: AcquiredCompilerSourceGraph -> Text
acquiredCompilerSnapshotIdentity (AcquiredCompilerSourceGraph identity _) =
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_SNAPSHOT_IDENTITY_PROJECTION_MUTANT)
  identity <> "-mutant"
#else
  identity
#endif

acquiredCompilerSourceCheck :: AcquiredCompilerSourceGraph -> CheckResult
acquiredCompilerSourceCheck (AcquiredCompilerSourceGraph _ result) =
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_SOURCE_CHECK_PROJECTION_MUTANT)
  result {checkObservations = []}
#else
  result
#endif

-- | Acquired source binding alone is insufficient. This path deliberately does
-- not invoke GHC until opaque authenticated elaboration, toolchain, subject-role
-- and supervisor inputs exist.
acquireCompilerSourceGraph
  :: AcquiredSourceSnapshot
  -> IO CompilerSourceAttempt
acquireCompilerSourceGraph acquired =
  pure
    ( CompilerSourceRefused
        diagnostic
        (compilerAcquisitionProblems identity registryReady)
    )
 where
  (diagnostic, identity, registryReady, _) = prepareAcquiredCompilerSourceGraph acquired

analyzeAcquiredCompilerSourceGraph
  :: AcquiredSourceSnapshot
  -> IO AcquiredCompilerSourceGraph
analyzeAcquiredCompilerSourceGraph acquired =
 pure diagnostic
 where
  (diagnostic, _, _, _) = prepareAcquiredCompilerSourceGraph acquired

prepareAcquiredCompilerSourceGraph
  :: AcquiredSourceSnapshot
  -> (AcquiredCompilerSourceGraph, Text, Bool, [CompilerSubjectContractProblem])
prepareAcquiredCompilerSourceGraph acquired =
  (assembleAcquiredCompilerSourceGraph identity result, identity, registryReady, contractProblems)
 where
  snapshot = acquiredSourceSnapshot acquired
  identity = mapAcquiredSnapshotIdentity (snapshotIdentity snapshot)
  ( entryCount
    , consumerComposition
    , registryObservation
    , registryReady
    , contractProblems
    , consumerObservations
    , consumerFindings
    , contractFindings
    , envelopeFindings
    ) =
    case boundedPrefix maximumAcquiredCompilerEntries (snapshotEntries snapshot) of
      PrefixExceeded observed ->
        ( renderAcquiredExceededEntryCount observed
        , acquiredExceededComposition
        , "refused"
        , False
        , []
        , []
        , []
        , []
        , acquiredEnvelopeFindings observed
        )
      PrefixWithin boundedEntries ->
        let consumerCheck = sourceConsumerGraphCheck (analyzeSourceConsumerGraph snapshot)
            registryCheck = compilerSubjectRegistryCheck (deriveCompilerSubjectRegistry snapshot)
            registryFindings = checkFindings registryCheck
            contractAttempt = acquireCompilerSubjectContract acquired
            acquiredContract = either (const Nothing) Just contractAttempt
            exactContractProblems = either NonEmpty.toList (const []) contractAttempt
            registryDigest = maybe "refused" compilerSubjectContractDigest acquiredContract
            projectedEntries = projectAcquiredBoundedEntries boundedEntries
         in ( renderAcquiredWithinEntryCount (length projectedEntries)
            , acquiredWithinComposition
            , registryDigest
            , maybe False (const (null registryFindings)) acquiredContract
            , exactContractProblems
            , retainAcquiredConsumerObservations (checkObservations consumerCheck)
            , retainAcquiredConsumerFindings (checkFindings consumerCheck)
            , registryFindings
            , []
            )
  result =
    CheckResult
      { checkName = acquiredDiagnosticCheckName
      , checkObservations =
          assembleAcquiredObservations
            consumerObservations
            (acquiredLocalObservations identity entryCount consumerComposition registryObservation)
      , checkFindings =
          assembleAcquiredFindings
            consumerFindings
            (contractFindings <> envelopeFindings)
            (acquiredRefusalFindings registryReady)
      }

-- This producer has no success branch until all four external authority
-- products and the semantic graph exist.  The leading graph problem records
-- the still-open SourceConsumerGraph obligation; the optional registry problem
-- is retained only when the repository-scale two-way assignment itself fails.
compilerAcquisitionProblems
  :: Text
  -> Bool
  -> NonEmpty CompilerAcquisitionProblem
compilerAcquisitionProblems identity registryReady =
  CompilerGraphFactsUnavailable identity
    :| ( [CompilerSubjectOutcomeRegistryUnavailable identity | not registryReady]
           <> [ CompilerElaboratedMultiRunUnavailable identity
              , CompilerToolchainAuthorityUnavailable identity
              , CompilerExecutionSupervisionUnavailable identity
              , CompilerSemanticClosureUnavailable identity
              ]
       )

assembleAcquiredCompilerSourceGraph :: Text -> CheckResult -> AcquiredCompilerSourceGraph
assembleAcquiredCompilerSourceGraph identity result =
  AcquiredCompilerSourceGraph
    (assembleAcquiredIdentity identity)
    (assembleAcquiredResult result)

assembleAcquiredIdentity :: Text -> Text
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_STATE_IDENTITY_ASSEMBLY_MUTANT)
assembleAcquiredIdentity value = value <> "-mutant"
#else
assembleAcquiredIdentity = id
#endif

assembleAcquiredResult :: CheckResult -> CheckResult
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_STATE_RESULT_ASSEMBLY_MUTANT)
assembleAcquiredResult result = result {checkFindings = []}
#else
assembleAcquiredResult = id
#endif

mapAcquiredSnapshotIdentity :: Text -> Text
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_SNAPSHOT_IDENTITY_MAPPING_MUTANT)
mapAcquiredSnapshotIdentity value = value <> "-mutant"
#else
mapAcquiredSnapshotIdentity = id
#endif

renderAcquiredExceededEntryCount :: Int -> Text
renderAcquiredExceededEntryCount observed =
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_ENTRY_COUNT_EXCEEDED_MAPPING_MUTANT)
  decimalText (observed + 1) <> acquiredExceededSuffix
#else
  decimalText observed <> acquiredExceededSuffix
#endif

acquiredExceededSuffix :: Text
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_ENTRY_COUNT_SUFFIX_MAPPING_MUTANT)
acquiredExceededSuffix = "!"
#else
acquiredExceededSuffix = "+"
#endif

renderAcquiredWithinEntryCount :: Int -> Text
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_WITHIN_ENTRY_COUNT_MAPPING_MUTANT)
renderAcquiredWithinEntryCount observed = decimalText (observed + 1)
#else
renderAcquiredWithinEntryCount = decimalText
#endif

acquiredExceededComposition, acquiredWithinComposition :: Text
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_EXCEEDED_COMPOSITION_MAPPING_MUTANT)
acquiredExceededComposition = "refused-after-source-consumer-diagnostic"
#else
acquiredExceededComposition = "refused-before-source-consumer-diagnostic"
#endif
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_WITHIN_COMPOSITION_MAPPING_MUTANT)
acquiredWithinComposition = "source-consumer-diagnostic-mutant"
#else
acquiredWithinComposition = "source-consumer-diagnostic-only"
#endif

projectAcquiredBoundedEntries :: [value] -> [value]
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_BOUNDED_ENTRIES_PROJECTION_MUTANT)
projectAcquiredBoundedEntries values = drop 1 values
#else
projectAcquiredBoundedEntries = id
#endif

retainAcquiredConsumerObservations :: [Observation] -> [Observation]
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_CONSUMER_OBSERVATIONS_RETENTION_DROP_MUTANT)
retainAcquiredConsumerObservations _ = []
#else
retainAcquiredConsumerObservations = id
#endif

retainAcquiredConsumerFindings :: [Finding] -> [Finding]
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_CONSUMER_FINDINGS_RETENTION_DROP_MUTANT)
retainAcquiredConsumerFindings _ = []
#else
retainAcquiredConsumerFindings = id
#endif

acquiredEnvelopeFindings :: Int -> [Finding]
acquiredEnvelopeFindings observed =
  [ acquiredEnvelopeFinding observed
  | retainAcquiredEnvelopeFinding
  ]

retainAcquiredEnvelopeFinding :: Bool
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_ENVELOPE_FINDING_RETENTION_DROP_MUTANT)
retainAcquiredEnvelopeFinding = False
#else
retainAcquiredEnvelopeFinding = True
#endif

acquiredEnvelopeFinding :: Int -> Finding
acquiredEnvelopeFinding observed =
  finding
    acquiredEnvelopeFindingCode
    acquiredEnvelopeFindingSubject
    (acquiredEnvelopeFindingDetail observed)

acquiredEnvelopeFindingCode :: Text
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_ENVELOPE_FINDING_CODE_MUTANT)
acquiredEnvelopeFindingCode = "SRC-COMPILER-ACQUIRED-ENTRY-LIMIT-MUTANT"
#else
acquiredEnvelopeFindingCode = "SRC-COMPILER-ACQUIRED-ENTRY-LIMIT"
#endif

acquiredEnvelopeFindingSubject :: FilePath
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_ENVELOPE_FINDING_SUBJECT_MUTANT)
acquiredEnvelopeFindingSubject = "compiler-source-graph-mutant"
#else
acquiredEnvelopeFindingSubject = "compiler-source-graph"
#endif

acquiredEnvelopeFindingDetail :: Int -> Text
acquiredEnvelopeFindingDetail observed =
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_ENVELOPE_FINDING_DETAIL_MUTANT)
  "limit-mutant="
#else
  "limit="
#endif
    <> decimalText maximumAcquiredCompilerEntries
    <> "; observed-at-least="
    <> decimalText observed

acquiredDiagnosticCheckName :: Text
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_CHECK_NAME_MAPPING_MUTANT)
acquiredDiagnosticCheckName = "acquired-compiler-source-graph-refusal-mutant"
#else
acquiredDiagnosticCheckName = "acquired-compiler-source-graph-refusal"
#endif

acquiredLocalObservations :: Text -> Text -> Text -> Text -> [Observation]
acquiredLocalObservations identity entryCount consumerComposition registryObservation =
  orderAcquiredLocalObservations
    ( concat
        [ acquiredLocalObservation 1 "source-compiler.snapshot" identity
        , acquiredLocalObservation 2 "source-compiler.inventory-entry-count" entryCount
        , acquiredLocalObservation 3 "source-compiler.consumer-graph-composition" consumerComposition
        , acquiredLocalObservation 4 "source-compiler.subject-role-registry" registryObservation
        , acquiredLocalObservation 5 "source-compiler.elaborated-multi-run-plan" "absent"
        , acquiredLocalObservation 6 "source-compiler.toolchain-authentication" "absent"
        , acquiredLocalObservation 7 "source-compiler.execution" "not-attempted"
        , acquiredLocalObservation 8 "source-compiler.semantic-closure" "absent"
        ]
    )

acquiredLocalObservation :: Int -> Text -> Text -> [Observation]
acquiredLocalObservation ordinal name value =
  [ observation
      (mapAcquiredObservationName ordinal name)
      (mapAcquiredObservationValue ordinal value)
  | retainAcquiredObservation ordinal
  ]

retainAcquiredObservation :: Int -> Bool
retainAcquiredObservation ordinal =
  ordinal `seq`
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_SNAPSHOT_OBSERVATION_DROP_MUTANT)
  ordinal /= 1
#elif defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_ENTRY_COUNT_OBSERVATION_DROP_MUTANT)
  ordinal /= 2
#elif defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_COMPOSITION_OBSERVATION_DROP_MUTANT)
  ordinal /= 3
#elif defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_SUBJECT_REGISTRY_OBSERVATION_DROP_MUTANT)
  ordinal /= 4
#elif defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_ELABORATION_OBSERVATION_DROP_MUTANT)
  ordinal /= 5
#elif defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_TOOLCHAIN_OBSERVATION_DROP_MUTANT)
  ordinal /= 6
#elif defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_EXECUTION_OBSERVATION_DROP_MUTANT)
  ordinal /= 7
#elif defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_SEMANTIC_OBSERVATION_DROP_MUTANT)
  ordinal /= 8
#else
  True
#endif

mapAcquiredObservationName :: Int -> Text -> Text
mapAcquiredObservationName ordinal value =
  ordinal `seq`
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_SNAPSHOT_OBSERVATION_NAME_MUTANT)
  if ordinal == 1 then value <> ".mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_ENTRY_COUNT_OBSERVATION_NAME_MUTANT)
  if ordinal == 2 then value <> ".mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_COMPOSITION_OBSERVATION_NAME_MUTANT)
  if ordinal == 3 then value <> ".mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_SUBJECT_REGISTRY_OBSERVATION_NAME_MUTANT)
  if ordinal == 4 then value <> ".mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_ELABORATION_OBSERVATION_NAME_MUTANT)
  if ordinal == 5 then value <> ".mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_TOOLCHAIN_OBSERVATION_NAME_MUTANT)
  if ordinal == 6 then value <> ".mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_EXECUTION_OBSERVATION_NAME_MUTANT)
  if ordinal == 7 then value <> ".mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_SEMANTIC_OBSERVATION_NAME_MUTANT)
  if ordinal == 8 then value <> ".mutant" else value
#else
  value
#endif

mapAcquiredObservationValue :: Int -> Text -> Text
mapAcquiredObservationValue ordinal value =
  ordinal `seq`
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_SNAPSHOT_OBSERVATION_VALUE_MUTANT)
  if ordinal == 1 then value <> "-mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_ENTRY_COUNT_OBSERVATION_VALUE_MUTANT)
  if ordinal == 2 then value <> "-mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_COMPOSITION_OBSERVATION_VALUE_MUTANT)
  if ordinal == 3 then value <> "-mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_SUBJECT_REGISTRY_OBSERVATION_VALUE_MUTANT)
  if ordinal == 4 then value <> "-mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_ELABORATION_OBSERVATION_VALUE_MUTANT)
  if ordinal == 5 then value <> "-mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_TOOLCHAIN_OBSERVATION_VALUE_MUTANT)
  if ordinal == 6 then value <> "-mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_EXECUTION_OBSERVATION_VALUE_MUTANT)
  if ordinal == 7 then value <> "-mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_SEMANTIC_OBSERVATION_VALUE_MUTANT)
  if ordinal == 8 then value <> "-mutant" else value
#else
  value
#endif

orderAcquiredLocalObservations :: [Observation] -> [Observation]
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_LOCAL_OBSERVATION_ORDER_MUTANT)
orderAcquiredLocalObservations = reverse
#else
orderAcquiredLocalObservations = id
#endif

assembleAcquiredObservations :: [Observation] -> [Observation] -> [Observation]
assembleAcquiredObservations consumerObservations localObservations =
  orderAcquiredResultObservations
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_OBSERVATION_COMPOSITION_ORDER_MUTANT)
    (localObservations <> consumerObservations)
#else
    (consumerObservations <> localObservations)
#endif

orderAcquiredResultObservations :: [Observation] -> [Observation]
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_RESULT_OBSERVATION_ORDER_MUTANT)
orderAcquiredResultObservations = reverse
#else
orderAcquiredResultObservations = id
#endif

assembleAcquiredFindings :: [Finding] -> [Finding] -> [Finding] -> [Finding]
assembleAcquiredFindings consumerFindings envelopeFindings refusalFindings =
  orderAcquiredResultFindings
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_FINDING_COMPOSITION_ORDER_MUTANT)
    (refusalFindings <> envelopeFindings <> consumerFindings)
#else
    (consumerFindings <> envelopeFindings <> refusalFindings)
#endif

orderAcquiredResultFindings :: [Finding] -> [Finding]
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_RESULT_FINDING_ORDER_MUTANT)
orderAcquiredResultFindings = reverse
#else
orderAcquiredResultFindings = id
#endif

acquiredRefusalFindings :: Bool -> [Finding]
-- The current production producer still has no discharge branch.  The opaque
-- acquired constructor exists for the eventual supervised producer and is
-- independently checked above; this refusal list remains the only branch
-- reachable from 'acquireCompilerSourceGraph' today.  Each mandatory residue
-- is independently retained so a selective omission is an atomic
-- changed-production subject.
acquiredRefusalFindings registryReady =
  [ findingValue
  | retainAcquiredRefusalFindings
  , findingValue <-
  orderAcquiredMandatoryFindings $
    ( [ acquiredMandatoryFinding 1
          "SRC-COMPILER-SUBJECT-OUTCOME-REGISTRY-UNAVAILABLE"
          "compiler-source-graph"
          "no closed Haskell SubjectRole/ExpectedCompilerOutcome registry is two-way complete against the acquired .hs inventory"
      | not registryReady
      , retainAcquiredSubjectRegistryResidue
      ]
        <> [ acquiredMandatoryFinding 2
            "SRC-COMPILER-ELABORATED-MULTI-RUN-UNAVAILABLE"
            "compiler-source-graph"
            "no authenticated Cabal elaboration binds every component, flag vector, generated input, compiler argument, and expected compile-refusal run"
           | retainAcquiredElaborationResidue
           ]
        <> [ acquiredMandatoryFinding 3
            "SRC-COMPILER-TOOLCHAIN-UNAUTHENTICATED"
            "compiler-source-graph"
            "the compiler executable, libdir, package databases, dependencies, and build-info inputs have no independent authenticated network-independent observation"
           | retainAcquiredToolchainResidue
           ]
        <> [ acquiredMandatoryFinding 4
            "SRC-COMPILER-EXECUTION-UNSUPERVISED"
            "compiler-source-graph"
            "no challenged source-bound Haskell supervisor has bounded compiler time, memory, output, filesystem inputs, and process identity"
           | retainAcquiredExecutionResidue
           ]
        <> [ acquiredMandatoryFinding 5
            "SRC-COMPILER-SEMANTIC-CLOSURE-UNAVAILABLE"
            "compiler-source-graph"
            "resolved calls, indirect calls, control flow, effects, tracked-content provenance, behaviour sinks, and dynamic loading are not completely established"
           | retainAcquiredSemanticResidue
           ]
    )
  ]

retainAcquiredRefusalFindings :: Bool
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_REFUSAL_FINDINGS_RETENTION_DROP_MUTANT)
retainAcquiredRefusalFindings = False
#else
retainAcquiredRefusalFindings = True
#endif

orderAcquiredMandatoryFindings :: [Finding] -> [Finding]
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_MANDATORY_FINDING_ORDER_MUTANT)
orderAcquiredMandatoryFindings = reverse
#else
orderAcquiredMandatoryFindings = id
#endif

acquiredMandatoryFinding :: Int -> Text -> FilePath -> Text -> Finding
acquiredMandatoryFinding ordinal code subject detail =
  finding
    (mapAcquiredMandatoryCode ordinal code)
    (mapAcquiredMandatorySubject ordinal subject)
    (mapAcquiredMandatoryDetail ordinal detail)

mapAcquiredMandatoryCode :: Int -> Text -> Text
mapAcquiredMandatoryCode ordinal value =
  ordinal `seq`
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_SUBJECT_REGISTRY_RESIDUE_CODE_MUTANT)
  if ordinal == 1 then value <> "-MUTANT" else value
#elif defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_ELABORATION_RESIDUE_CODE_MUTANT)
  if ordinal == 2 then value <> "-MUTANT" else value
#elif defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_TOOLCHAIN_RESIDUE_CODE_MUTANT)
  if ordinal == 3 then value <> "-MUTANT" else value
#elif defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_EXECUTION_RESIDUE_CODE_MUTANT)
  if ordinal == 4 then value <> "-MUTANT" else value
#elif defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_SEMANTIC_RESIDUE_CODE_MUTANT)
  if ordinal == 5 then value <> "-MUTANT" else value
#else
  value
#endif

mapAcquiredMandatorySubject :: Int -> FilePath -> FilePath
mapAcquiredMandatorySubject ordinal value =
  ordinal `seq`
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_SUBJECT_REGISTRY_RESIDUE_SUBJECT_MUTANT)
  if ordinal == 1 then value <> "-mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_ELABORATION_RESIDUE_SUBJECT_MUTANT)
  if ordinal == 2 then value <> "-mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_TOOLCHAIN_RESIDUE_SUBJECT_MUTANT)
  if ordinal == 3 then value <> "-mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_EXECUTION_RESIDUE_SUBJECT_MUTANT)
  if ordinal == 4 then value <> "-mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_SEMANTIC_RESIDUE_SUBJECT_MUTANT)
  if ordinal == 5 then value <> "-mutant" else value
#else
  value
#endif

mapAcquiredMandatoryDetail :: Int -> Text -> Text
mapAcquiredMandatoryDetail ordinal value =
  ordinal `seq`
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_SUBJECT_REGISTRY_RESIDUE_DETAIL_MUTANT)
  if ordinal == 1 then value <> " (mutant)" else value
#elif defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_ELABORATION_RESIDUE_DETAIL_MUTANT)
  if ordinal == 2 then value <> " (mutant)" else value
#elif defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_TOOLCHAIN_RESIDUE_DETAIL_MUTANT)
  if ordinal == 3 then value <> " (mutant)" else value
#elif defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_EXECUTION_RESIDUE_DETAIL_MUTANT)
  if ordinal == 4 then value <> " (mutant)" else value
#elif defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_SEMANTIC_RESIDUE_DETAIL_MUTANT)
  if ordinal == 5 then value <> " (mutant)" else value
#else
  value
#endif

retainAcquiredSubjectRegistryResidue, retainAcquiredElaborationResidue,
  retainAcquiredToolchainResidue, retainAcquiredExecutionResidue,
  retainAcquiredSemanticResidue :: Bool
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_SUBJECT_REGISTRY_RESIDUE_DROP_MUTANT)
retainAcquiredSubjectRegistryResidue = False
#else
retainAcquiredSubjectRegistryResidue = True
#endif
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_ELABORATION_RESIDUE_DROP_MUTANT)
retainAcquiredElaborationResidue = False
#else
retainAcquiredElaborationResidue = True
#endif
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_TOOLCHAIN_RESIDUE_DROP_MUTANT)
retainAcquiredToolchainResidue = False
#else
retainAcquiredToolchainResidue = True
#endif
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_EXECUTION_RESIDUE_DROP_MUTANT)
retainAcquiredExecutionResidue = False
#else
retainAcquiredExecutionResidue = True
#endif
#if defined(VALIDATION_COMPILER_GRAPH_ACQUIRED_SEMANTIC_RESIDUE_DROP_MUTANT)
retainAcquiredSemanticResidue = False
#else
retainAcquiredSemanticResidue = True
#endif

data RawEntry = RawEntry FilePath Text Text ByteString

rawPath :: RawEntry -> FilePath
rawPath (RawEntry value _ _ _) = value

rawMode :: RawEntry -> Text
rawMode (RawEntry _ value _ _) = value

rawObjectIdentity :: RawEntry -> Text
rawObjectIdentity (RawEntry _ _ value _) = value

rawBytes :: RawEntry -> ByteString
rawBytes (RawEntry _ _ _ value) = value

data RawSummary = RawSummary Text Text Text Text Text (Maybe RawProblem)

data RawProblem
  = RawIdentityByteLimit Int Int
  | RawEntryLimit Int Int
  | RawPathByteLimit Int Int Int
  | RawPathDepthLimit Int Int Int
  | RawPathSegmentLimit Int Int Int
  | RawModeByteLimit Int Int Int
  | RawObjectIdentityByteLimit Int Int Int
  | RawBlobByteLimit Int Int Int
  | RawAggregateBlobByteLimit Int Int
  | RawHaskellSubjectLimit Int Int
  | RawCabalEntryLimit Int Int
  | RawIdentityMalformed
  | RawIdentityMismatch Text Text
  | RawPathEmpty Int
  | RawPathAbsolute Int
  | RawPathNul Int
  | RawPathBackslash Int
  | RawPathEmptySegment Int
  | RawPathDotSegment Int
  | RawPathParentSegment Int
  | RawPathCharacterUnsafe Int
  | RawPathDuplicate FilePath
  | RawPathPortableCaseCollision FilePath FilePath
  | RawPathPrefixConflict FilePath FilePath
  | RawEntryOrderInvalid
  | RawModeMalformed Int
  | RawObjectIdentityMalformed Int
  | RawObjectIdentityMismatch Int Text Text
  | RawObjectFormatsMixed
  | RawHaskellSubjectModeRejected Int
  | RawCabalEntryModeRejected Int
  | RawHaskellSubjectInventoryEmpty
  | RawCabalEntryInventoryEmpty
  deriving (Eq, Show)

data BoundedPrefix value
  = PrefixWithin [value]
  | PrefixExceeded Int

boundedPrefix :: Int -> [value] -> BoundedPrefix value
boundedPrefix limit = go 0 []
 where
  go count reversed remaining = case remaining of
    [] -> PrefixWithin (mapBoundedPrefixWithin reversed)
    value : rest
      | boundedPrefixExceeded count limit -> PrefixExceeded (mapBoundedPrefixObserved limit)
#if defined(VALIDATION_COMPILER_GRAPH_RAW_BOUNDED_PREFIX_RECURSION_ROUTE_MUTANT)
      | otherwise -> rest `seq` PrefixWithin (mapBoundedPrefixWithin (value : reversed))
#else
      | otherwise -> go (count + 1) (value : reversed) rest
#endif

boundedPrefixExceeded :: Int -> Int -> Bool
#if defined(VALIDATION_COMPILER_GRAPH_RAW_BOUNDED_PREFIX_PREDICATE_MUTANT)
boundedPrefixExceeded count limit = count + 1 == limit
#else
boundedPrefixExceeded count limit = count == limit
#endif

mapBoundedPrefixObserved :: Int -> Int
#if defined(VALIDATION_COMPILER_GRAPH_RAW_BOUNDED_PREFIX_OBSERVED_PROJECTION_MUTANT)
mapBoundedPrefixObserved limit = limit + 2
#else
mapBoundedPrefixObserved limit = limit + 1
#endif

mapBoundedPrefixWithin :: [value] -> [value]
#if defined(VALIDATION_COMPILER_GRAPH_RAW_BOUNDED_PREFIX_WITHIN_ORDER_MUTANT)
mapBoundedPrefixWithin = id
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_BOUNDED_PREFIX_WITHIN_RETENTION_MUTANT)
mapBoundedPrefixWithin = drop 1 . reverse
#else
mapBoundedPrefixWithin = reverse
#endif

rawCompilerSourceGraphDiagnostic
  :: Text
  -> [(FilePath, Text, Text, ByteString)]
  -> CheckResult
rawCompilerSourceGraphDiagnostic claimedIdentity tuples =
  CheckResult
    { checkName = rawDiagnosticCheckName
    , checkObservations = rawObservations summary
    , checkFindings = rawResultFindings summary
    }
 where
  summary = analyzeRawInput claimedIdentity tuples

rawDiagnosticCheckName :: Text
#if defined(VALIDATION_COMPILER_GRAPH_RAW_CHECK_NAME_MAPPING_MUTANT)
rawDiagnosticCheckName = "compiler-source-graph-diagnostic-mutant"
#else
rawDiagnosticCheckName = "compiler-source-graph-diagnostic"
#endif

rawObservations :: RawSummary -> [Observation]
rawObservations (RawSummary entryCount aggregate identity haskellCount cabalCount problem) =
  orderRawObservations
    ( concat
        [ rawObservation 1 "compiler-graph.input.entry-count" entryCount
        , rawObservation 2 "compiler-graph.input.aggregate-blob-bytes" aggregate
        , rawObservation 3 "compiler-graph.input.inventory-sha256" identity
        , rawObservation 4 "compiler-graph.input.haskell-subject-count" haskellCount
        , rawObservation 5 "compiler-graph.input.cabal-entry-count" cabalCount
        , rawObservation 6 "compiler-graph.input.problem-count" (maybe "0" (const "1") problem)
        , rawObservation 7 "compiler-graph.compiler-execution" "not-attempted"
        , rawObservation 8 "compiler-graph.semantic-closure" "absent"
        , rawObservation 9 "compiler-graph.diagnostic-status" "refused"
        ]
    )

rawObservation :: Int -> Text -> Text -> [Observation]
rawObservation ordinal name value =
  [ observation
      (mapRawObservationName ordinal name)
      (mapRawObservationValue ordinal value)
  | retainRawObservation ordinal
  ]

orderRawObservations :: [Observation] -> [Observation]
#if defined(VALIDATION_COMPILER_GRAPH_RAW_OBSERVATION_ORDER_MUTANT)
orderRawObservations = reverse
#else
orderRawObservations = id
#endif

retainRawObservation :: Int -> Bool
retainRawObservation ordinal =
  ordinal `seq`
#if defined(VALIDATION_COMPILER_GRAPH_RAW_ENTRY_COUNT_OBSERVATION_DROP_MUTANT)
  ordinal /= 1
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_AGGREGATE_OBSERVATION_DROP_MUTANT)
  ordinal /= 2
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_OBSERVATION_DROP_MUTANT)
  ordinal /= 3
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_HASKELL_COUNT_OBSERVATION_DROP_MUTANT)
  ordinal /= 4
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_CABAL_COUNT_OBSERVATION_DROP_MUTANT)
  ordinal /= 5
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_PROBLEM_COUNT_OBSERVATION_DROP_MUTANT)
  ordinal /= 6
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_EXECUTION_OBSERVATION_DROP_MUTANT)
  ordinal /= 7
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_SEMANTIC_OBSERVATION_DROP_MUTANT)
  ordinal /= 8
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_STATUS_OBSERVATION_DROP_MUTANT)
  ordinal /= 9
#else
  True
#endif

mapRawObservationName :: Int -> Text -> Text
mapRawObservationName ordinal value =
  ordinal `seq`
#if defined(VALIDATION_COMPILER_GRAPH_RAW_ENTRY_COUNT_OBSERVATION_NAME_MUTANT)
  if ordinal == 1 then value <> ".mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_AGGREGATE_OBSERVATION_NAME_MUTANT)
  if ordinal == 2 then value <> ".mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_OBSERVATION_NAME_MUTANT)
  if ordinal == 3 then value <> ".mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_HASKELL_COUNT_OBSERVATION_NAME_MUTANT)
  if ordinal == 4 then value <> ".mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_CABAL_COUNT_OBSERVATION_NAME_MUTANT)
  if ordinal == 5 then value <> ".mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_PROBLEM_COUNT_OBSERVATION_NAME_MUTANT)
  if ordinal == 6 then value <> ".mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_EXECUTION_OBSERVATION_NAME_MUTANT)
  if ordinal == 7 then value <> ".mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_SEMANTIC_OBSERVATION_NAME_MUTANT)
  if ordinal == 8 then value <> ".mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_STATUS_OBSERVATION_NAME_MUTANT)
  if ordinal == 9 then value <> ".mutant" else value
#else
  value
#endif

mapRawObservationValue :: Int -> Text -> Text
mapRawObservationValue ordinal value =
  ordinal `seq`
#if defined(VALIDATION_COMPILER_GRAPH_RAW_ENTRY_COUNT_OBSERVATION_VALUE_MUTANT)
  if ordinal == 1 then value <> "-mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_AGGREGATE_OBSERVATION_VALUE_MUTANT)
  if ordinal == 2 then value <> "-mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_OBSERVATION_VALUE_MUTANT)
  if ordinal == 3 then value <> "-mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_HASKELL_COUNT_OBSERVATION_VALUE_MUTANT)
  if ordinal == 4 then value <> "-mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_CABAL_COUNT_OBSERVATION_VALUE_MUTANT)
  if ordinal == 5 then value <> "-mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_PROBLEM_COUNT_OBSERVATION_VALUE_MUTANT)
  if ordinal == 6 then value <> "-mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_EXECUTION_OBSERVATION_VALUE_MUTANT)
  if ordinal == 7 then value <> "-mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_SEMANTIC_OBSERVATION_VALUE_MUTANT)
  if ordinal == 8 then value <> "-mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_STATUS_OBSERVATION_VALUE_MUTANT)
  if ordinal == 9 then value <> "-mutant" else value
#else
  value
#endif

rawProblemFindings :: RawSummary -> [Finding]
rawProblemFindings (RawSummary _ _ _ _ _ problem) =
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PROBLEM_FINDING_RETENTION_DROP_MUTANT)
  maybe [] (\problemValue -> rawProblemFinding problemValue `seq` []) problem
#else
  maybe [] (pure . rawProblemFinding) problem
#endif

rawResultFindings :: RawSummary -> [Finding]
rawResultFindings summary =
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PROBLEM_FINDING_ORDER_MUTANT)
  orderRawMandatoryFindings rawMandatoryFindings <> rawProblemFindings summary
#else
  rawProblemFindings summary <> orderRawMandatoryFindings rawMandatoryFindings
#endif

orderRawMandatoryFindings :: [Finding] -> [Finding]
#if defined(VALIDATION_COMPILER_GRAPH_RAW_MANDATORY_FINDING_ORDER_MUTANT)
orderRawMandatoryFindings = reverse
#else
orderRawMandatoryFindings = id
#endif

rawMandatoryFindings :: [Finding]
rawMandatoryFindings =
  concat
    [
#if !defined(VALIDATION_COMPILER_GRAPH_RAW_DIAGNOSTIC_RESIDUE_DROP_MUTANT)
      [rawMandatoryFinding 1 "COMPILER-GRAPH-DIAGNOSTIC-ONLY" "compiler-source-graph" "raw caller input can produce diagnostics only; it cannot mint compiler-source-graph evidence"]
#else
      []
#endif
    ,
#if !defined(VALIDATION_COMPILER_GRAPH_RAW_SOURCE_BINDING_RESIDUE_DROP_MUTANT)
      [rawMandatoryFinding 2 "COMPILER-GRAPH-SOURCE-BINDING-UNAVAILABLE" "compiler-source-graph" "the raw inventory has no authenticated immutable source-binding token"]
#else
      []
#endif
    ,
#if !defined(VALIDATION_COMPILER_GRAPH_RAW_SUBJECT_REGISTRY_RESIDUE_DROP_MUTANT)
      [rawMandatoryFinding 3 "COMPILER-GRAPH-SUBJECT-OUTCOME-REGISTRY-UNAVAILABLE" "compiler-source-graph" "no closed Haskell SubjectRole/ExpectedCompilerOutcome registry is attached"]
#else
      []
#endif
    ,
#if !defined(VALIDATION_COMPILER_GRAPH_RAW_ELABORATION_RESIDUE_DROP_MUTANT)
      [rawMandatoryFinding 4 "COMPILER-GRAPH-ELABORATION-BINDING-UNAVAILABLE" "compiler-source-graph" "no exact elaborated multi-component configuration-run plan is attached"]
#else
      []
#endif
    ,
#if !defined(VALIDATION_COMPILER_GRAPH_RAW_TOOLCHAIN_RESIDUE_DROP_MUTANT)
      [rawMandatoryFinding 5 "COMPILER-GRAPH-TOOLCHAIN-BINDING-UNAVAILABLE" "compiler-source-graph" "no exactly observed compiler, libdir, package-database, dependency, or build-info identity is attached"]
#else
      []
#endif
    ,
#if !defined(VALIDATION_COMPILER_GRAPH_RAW_EXECUTION_RESIDUE_DROP_MUTANT)
      [rawMandatoryFinding 6 "COMPILER-GRAPH-EXECUTION-SUPERVISION-UNAVAILABLE" "compiler-source-graph" "the compiler was not invoked by a challenged source-bound Haskell supervisor with closed resource and filesystem observation"]
#else
      []
#endif
    ,
#if !defined(VALIDATION_COMPILER_GRAPH_RAW_SEMANTIC_RESIDUE_DROP_MUTANT)
      [rawMandatoryFinding 7 "COMPILER-GRAPH-SEMANTIC-CLOSURE-UNAVAILABLE" "compiler-source-graph" "complete calls, control flow, effect, provenance, sink, and dynamic-loading facts are absent"]
#else
      []
#endif
    ,
#if !defined(VALIDATION_COMPILER_GRAPH_RAW_QUALIFICATION_RESIDUE_DROP_MUTANT)
      [rawMandatoryFinding 8 "COMPILER-GRAPH-ORACLE-QUALIFICATION-UNAVAILABLE" "compiler-source-graph" "the component diagnostic is not an independently qualified phase-gate observation"]
#else
      []
#endif
    ]

rawMandatoryFinding :: Int -> Text -> FilePath -> Text -> Finding
rawMandatoryFinding ordinal code subject detail =
  finding
    (mapRawMandatoryCode ordinal code)
    (mapRawMandatorySubject ordinal subject)
    (mapRawMandatoryDetail ordinal detail)

mapRawMandatoryCode :: Int -> Text -> Text
mapRawMandatoryCode ordinal value =
  ordinal `seq`
#if defined(VALIDATION_COMPILER_GRAPH_RAW_DIAGNOSTIC_RESIDUE_CODE_MUTANT)
  if ordinal == 1 then value <> "-MUTANT" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_SOURCE_BINDING_RESIDUE_CODE_MUTANT)
  if ordinal == 2 then value <> "-MUTANT" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_SUBJECT_REGISTRY_RESIDUE_CODE_MUTANT)
  if ordinal == 3 then value <> "-MUTANT" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_ELABORATION_RESIDUE_CODE_MUTANT)
  if ordinal == 4 then value <> "-MUTANT" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_TOOLCHAIN_RESIDUE_CODE_MUTANT)
  if ordinal == 5 then value <> "-MUTANT" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_EXECUTION_RESIDUE_CODE_MUTANT)
  if ordinal == 6 then value <> "-MUTANT" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_SEMANTIC_RESIDUE_CODE_MUTANT)
  if ordinal == 7 then value <> "-MUTANT" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_QUALIFICATION_RESIDUE_CODE_MUTANT)
  if ordinal == 8 then value <> "-MUTANT" else value
#else
  value
#endif

mapRawMandatorySubject :: Int -> FilePath -> FilePath
mapRawMandatorySubject ordinal value =
  ordinal `seq`
#if defined(VALIDATION_COMPILER_GRAPH_RAW_DIAGNOSTIC_RESIDUE_SUBJECT_MUTANT)
  if ordinal == 1 then value <> "-mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_SOURCE_BINDING_RESIDUE_SUBJECT_MUTANT)
  if ordinal == 2 then value <> "-mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_SUBJECT_REGISTRY_RESIDUE_SUBJECT_MUTANT)
  if ordinal == 3 then value <> "-mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_ELABORATION_RESIDUE_SUBJECT_MUTANT)
  if ordinal == 4 then value <> "-mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_TOOLCHAIN_RESIDUE_SUBJECT_MUTANT)
  if ordinal == 5 then value <> "-mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_EXECUTION_RESIDUE_SUBJECT_MUTANT)
  if ordinal == 6 then value <> "-mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_SEMANTIC_RESIDUE_SUBJECT_MUTANT)
  if ordinal == 7 then value <> "-mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_QUALIFICATION_RESIDUE_SUBJECT_MUTANT)
  if ordinal == 8 then value <> "-mutant" else value
#else
  value
#endif

mapRawMandatoryDetail :: Int -> Text -> Text
mapRawMandatoryDetail ordinal value =
  ordinal `seq`
#if defined(VALIDATION_COMPILER_GRAPH_RAW_DIAGNOSTIC_RESIDUE_DETAIL_MUTANT)
  if ordinal == 1 then value <> " (mutant)" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_SOURCE_BINDING_RESIDUE_DETAIL_MUTANT)
  if ordinal == 2 then value <> " (mutant)" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_SUBJECT_REGISTRY_RESIDUE_DETAIL_MUTANT)
  if ordinal == 3 then value <> " (mutant)" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_ELABORATION_RESIDUE_DETAIL_MUTANT)
  if ordinal == 4 then value <> " (mutant)" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_TOOLCHAIN_RESIDUE_DETAIL_MUTANT)
  if ordinal == 5 then value <> " (mutant)" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_EXECUTION_RESIDUE_DETAIL_MUTANT)
  if ordinal == 6 then value <> " (mutant)" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_SEMANTIC_RESIDUE_DETAIL_MUTANT)
  if ordinal == 7 then value <> " (mutant)" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_QUALIFICATION_RESIDUE_DETAIL_MUTANT)
  if ordinal == 8 then value <> " (mutant)" else value
#else
  value
#endif

analyzeRawInput
  :: Text
  -> [(FilePath, Text, Text, ByteString)]
  -> RawSummary
analyzeRawInput claimedIdentity tuples =
  case boundedTextUtf8Length maximumRawIdentityBytes claimedIdentity of
    PrefixExceeded observed -> rawIdentityBoundExceeded maximumRawIdentityBytes observed
    PrefixWithin _
      | not retainRawIdentityBoundWithinRoute -> rawFailure RawIdentityMalformed
      | otherwise -> case boundedPrefix maximumRawEntries tuples of
          PrefixExceeded observed -> rawEntryBoundExceeded maximumRawEntries observed
          PrefixWithin boundedTuples
            | not retainRawEntryBoundWithinRoute -> rawFailure RawIdentityMalformed
            | otherwise ->
                analyzeBounded claimedIdentity
                  [ RawEntry
                      (mapRawTuplePath path)
                      (mapRawTupleMode mode)
                      (mapRawTupleObjectIdentity objectIdentity)
                      (mapRawTupleBytes bytes)
                  | (path, mode, objectIdentity, bytes) <- boundedTuples
                  ]

rawIdentityBoundExceeded :: Int -> Int -> RawSummary
#if defined(VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_BOUND_EXCEEDED_ROUTE_MUTANT)
rawIdentityBoundExceeded _ _ = rawFailure RawIdentityMalformed
#else
rawIdentityBoundExceeded limit observed = rawFailure (RawIdentityByteLimit limit observed)
#endif

rawEntryBoundExceeded :: Int -> Int -> RawSummary
#if defined(VALIDATION_COMPILER_GRAPH_RAW_ENTRY_BOUND_EXCEEDED_ROUTE_MUTANT)
rawEntryBoundExceeded _ _ = rawFailure RawIdentityMalformed
#else
rawEntryBoundExceeded limit observed = rawFailure (RawEntryLimit limit observed)
#endif

retainRawIdentityBoundWithinRoute, retainRawEntryBoundWithinRoute :: Bool
#if defined(VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_BOUND_WITHIN_ROUTE_MUTANT)
retainRawIdentityBoundWithinRoute = False
#else
retainRawIdentityBoundWithinRoute = True
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_ENTRY_BOUND_WITHIN_ROUTE_MUTANT)
retainRawEntryBoundWithinRoute = False
#else
retainRawEntryBoundWithinRoute = True
#endif

mapRawTuplePath :: FilePath -> FilePath
#if defined(VALIDATION_COMPILER_GRAPH_RAW_TUPLE_PATH_PROJECTION_MUTANT)
mapRawTuplePath value = value <> ":mutant"
#else
mapRawTuplePath = id
#endif

mapRawTupleMode :: Text -> Text
#if defined(VALIDATION_COMPILER_GRAPH_RAW_TUPLE_MODE_PROJECTION_MUTANT)
mapRawTupleMode value = value <> "x"
#else
mapRawTupleMode = id
#endif

mapRawTupleObjectIdentity :: Text -> Text
#if defined(VALIDATION_COMPILER_GRAPH_RAW_TUPLE_OBJECT_IDENTITY_PROJECTION_MUTANT)
mapRawTupleObjectIdentity value = value <> "a"
#else
mapRawTupleObjectIdentity = id
#endif

mapRawTupleBytes :: ByteString -> ByteString
#if defined(VALIDATION_COMPILER_GRAPH_RAW_TUPLE_BLOB_PROJECTION_MUTANT)
mapRawTupleBytes value = value <> "mutant"
#else
mapRawTupleBytes = id
#endif

analyzeBounded :: Text -> [RawEntry] -> RawSummary
analyzeBounded claimedIdentity entries =
#if defined(VALIDATION_COMPILER_GRAPH_RAW_RESOURCE_GRAMMAR_PRECEDENCE_MUTANT)
  case firstGrammarProblem claimedIdentity entries of
    Just problem -> rawFailure problem
    Nothing -> case firstResourceProblem entries of
#else
  case firstResourceProblem entries of
    Just problem -> rawFailure problem
    Nothing -> case firstGrammarProblem claimedIdentity entries of
#endif
      Just problem -> rawFailure problem
      Nothing ->
        RawSummary
          (mapRawSuccessField 1 (decimalText (length entries)))
          (mapRawSuccessField 2 (decimalText (sum (map (ByteString.length . rawBytes) entries))))
          (mapRawSuccessField 3 (inventoryIdentity entries))
          (mapRawSuccessField 4 (decimalText (length (filter isHaskellEntry entries))))
          (mapRawSuccessField 5 (decimalText (length (filter isCabalEntry entries))))
          rawSuccessProblem

mapRawSuccessField :: Int -> Text -> Text
mapRawSuccessField ordinal value =
  ordinal `seq`
#if defined(VALIDATION_COMPILER_GRAPH_RAW_SUCCESS_ENTRY_COUNT_ASSEMBLY_MUTANT)
  if ordinal == 1 then value <> "-mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_SUCCESS_AGGREGATE_ASSEMBLY_MUTANT)
  if ordinal == 2 then value <> "-mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_SUCCESS_IDENTITY_ASSEMBLY_MUTANT)
  if ordinal == 3 then value <> "-mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_SUCCESS_HASKELL_COUNT_ASSEMBLY_MUTANT)
  if ordinal == 4 then value <> "-mutant" else value
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_SUCCESS_CABAL_COUNT_ASSEMBLY_MUTANT)
  if ordinal == 5 then value <> "-mutant" else value
#else
  value
#endif

rawSuccessProblem :: Maybe RawProblem
#if defined(VALIDATION_COMPILER_GRAPH_RAW_SUCCESS_PROBLEM_ASSEMBLY_MUTANT)
rawSuccessProblem = Just RawIdentityMalformed
#else
rawSuccessProblem = Nothing
#endif

rawFailure :: RawProblem -> RawSummary
rawFailure problem =
  RawSummary
    (rawUnavailableField 1)
    (rawUnavailableField 2)
    (rawUnavailableField 3)
    (rawUnavailableField 4)
    (rawUnavailableField 5)
    (retainRawFailureProblem problem)

rawUnavailableField :: Int -> Text
rawUnavailableField ordinal =
  ordinal `seq`
#if defined(VALIDATION_COMPILER_GRAPH_RAW_FAILURE_ENTRY_COUNT_MAPPING_MUTANT)
  if ordinal == 1 then "unavailable-mutant" else "unavailable"
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_FAILURE_AGGREGATE_MAPPING_MUTANT)
  if ordinal == 2 then "unavailable-mutant" else "unavailable"
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_FAILURE_IDENTITY_MAPPING_MUTANT)
  if ordinal == 3 then "unavailable-mutant" else "unavailable"
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_FAILURE_HASKELL_COUNT_MAPPING_MUTANT)
  if ordinal == 4 then "unavailable-mutant" else "unavailable"
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_FAILURE_CABAL_COUNT_MAPPING_MUTANT)
  if ordinal == 5 then "unavailable-mutant" else "unavailable"
#else
  "unavailable"
#endif

retainRawFailureProblem :: RawProblem -> Maybe RawProblem
#if defined(VALIDATION_COMPILER_GRAPH_RAW_FAILURE_PROBLEM_RETENTION_DROP_MUTANT)
retainRawFailureProblem _ = Nothing
#else
retainRawFailureProblem = Just
#endif

firstResourceProblem :: [RawEntry] -> Maybe RawProblem
firstResourceProblem entries =
  combineRawResourceProblems
    (firstJust (orderRawEntryResourceTraversal (zipWith entryResourceProblem [1 ..] entries)))
    (aggregateProblem entries)
    (countProblem maximumRawHaskellSubjects RawHaskellSubjectLimit (filter isHaskellEntry entries))
    (countProblem maximumRawCabalEntries RawCabalEntryLimit (filter isCabalEntry entries))

orderRawEntryResourceTraversal :: [Maybe RawProblem] -> [Maybe RawProblem]
#if defined(VALIDATION_COMPILER_GRAPH_RAW_ENTRY_RESOURCE_TRAVERSAL_ORDER_MUTANT)
orderRawEntryResourceTraversal = reverse
#else
orderRawEntryResourceTraversal = id
#endif

combineRawResourceProblems
  :: Maybe RawProblem
  -> Maybe RawProblem
  -> Maybe RawProblem
  -> Maybe RawProblem
  -> Maybe RawProblem
combineRawResourceProblems entryProblems aggregateProblems haskellProblems cabalProblems =
#if defined(VALIDATION_COMPILER_GRAPH_RAW_ENTRY_AGGREGATE_RESOURCE_ORDER_MUTANT)
  aggregateProblems `orElse` entryProblems `orElse` haskellProblems `orElse` cabalProblems
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_AGGREGATE_HASKELL_RESOURCE_ORDER_MUTANT)
  entryProblems `orElse` haskellProblems `orElse` aggregateProblems `orElse` cabalProblems
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_HASKELL_CABAL_RESOURCE_ORDER_MUTANT)
  entryProblems `orElse` aggregateProblems `orElse` cabalProblems `orElse` haskellProblems
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_CABAL_RESOURCE_ROUTE_DROP_MUTANT)
  cabalProblems `seq` (entryProblems `orElse` aggregateProblems `orElse` haskellProblems)
#else
  entryProblems `orElse` aggregateProblems `orElse` haskellProblems `orElse` cabalProblems
#endif

entryResourceProblem :: Int -> RawEntry -> Maybe RawProblem
entryResourceProblem ordinal entry =
  combineRawEntryResourceProblems
    pathByteProblem
    (pathDepthProblem ordinal (rawPath entry))
    (pathSegmentProblem ordinal (rawPath entry))
    modeByteProblem
    objectByteProblem
    blobProblem
 where
  pathByteProblem =
    exceeded
      (boundedFilePathUtf8Length maximumRawPathBytes (rawPath entry))
      (RawPathByteLimit ordinal maximumRawPathBytes)
  modeByteProblem =
    exceeded
      (boundedTextUtf8Length maximumRawModeBytes (rawMode entry))
      (RawModeByteLimit ordinal maximumRawModeBytes)
  objectByteProblem =
    exceeded
      (boundedTextUtf8Length maximumRawObjectIdentityBytes (rawObjectIdentity entry))
      (RawObjectIdentityByteLimit ordinal maximumRawObjectIdentityBytes)
  observedBlobBytes = ByteString.length (rawBytes entry)
  blobProblem =
    [RawBlobByteLimit ordinal maximumRawBlobBytes observedBlobBytes | rawBlobLimitExceeded observedBlobBytes]
      `listHead` Nothing

rawBlobLimitExceeded :: Int -> Bool
#if defined(VALIDATION_COMPILER_GRAPH_RAW_BLOB_RESOURCE_PREDICATE_MUTANT)
rawBlobLimitExceeded observed = observed >= maximumRawBlobBytes
#else
rawBlobLimitExceeded observed = observed > maximumRawBlobBytes
#endif

combineRawEntryResourceProblems
  :: Maybe RawProblem
  -> Maybe RawProblem
  -> Maybe RawProblem
  -> Maybe RawProblem
  -> Maybe RawProblem
  -> Maybe RawProblem
  -> Maybe RawProblem
combineRawEntryResourceProblems pathByte depth segment mode object blob =
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_BYTE_DEPTH_RESOURCE_ORDER_MUTANT)
  depth `orElse` pathByte `orElse` segment `orElse` mode `orElse` object `orElse` blob
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_DEPTH_SEGMENT_RESOURCE_ORDER_MUTANT)
  pathByte `orElse` segment `orElse` depth `orElse` mode `orElse` object `orElse` blob
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_SEGMENT_MODE_RESOURCE_ORDER_MUTANT)
  pathByte `orElse` depth `orElse` mode `orElse` segment `orElse` object `orElse` blob
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_MODE_OBJECT_RESOURCE_ORDER_MUTANT)
  pathByte `orElse` depth `orElse` segment `orElse` object `orElse` mode `orElse` blob
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_OBJECT_BLOB_RESOURCE_ORDER_MUTANT)
  pathByte `orElse` depth `orElse` segment `orElse` mode `orElse` blob `orElse` object
#else
  pathByte `orElse` depth `orElse` segment `orElse` mode `orElse` object `orElse` blob
#endif

aggregateProblem :: [RawEntry] -> Maybe RawProblem
aggregateProblem = go 0
 where
  go total remaining = case remaining of
    [] -> Nothing
    entry : rest ->
      let blobBytes = mapAggregateBlobLength (ByteString.length (rawBytes entry))
          accumulated = mapAggregateAccumulator total blobBytes
          next = mapAggregateSaturation (min (maximumRawAggregateBlobBytes + 1) accumulated)
       in if aggregateOverflowed next
            then
              Just
                ( RawAggregateBlobByteLimit
                    (mapAggregateOverflowLimit maximumRawAggregateBlobBytes)
                    (mapAggregateOverflowObserved next)
                )
            else continueAggregateFold next rest

mapAggregateBlobLength :: Int -> Int
#if defined(VALIDATION_COMPILER_GRAPH_RAW_AGGREGATE_BLOB_LENGTH_PROJECTION_MUTANT)
mapAggregateBlobLength value = value + 1
#else
mapAggregateBlobLength = id
#endif

mapAggregateAccumulator :: Int -> Int -> Int
#if defined(VALIDATION_COMPILER_GRAPH_RAW_AGGREGATE_ACCUMULATOR_PROJECTION_MUTANT)
mapAggregateAccumulator _ blobBytes = blobBytes
#else
mapAggregateAccumulator total blobBytes = total + blobBytes
#endif

mapAggregateSaturation :: Int -> Int
#if defined(VALIDATION_COMPILER_GRAPH_RAW_AGGREGATE_SATURATION_PROJECTION_MUTANT)
mapAggregateSaturation value = value + 1
#else
mapAggregateSaturation = id
#endif

aggregateOverflowed :: Int -> Bool
#if defined(VALIDATION_COMPILER_GRAPH_RAW_AGGREGATE_OVERFLOW_PREDICATE_MUTANT)
aggregateOverflowed value = value >= maximumRawAggregateBlobBytes
#else
aggregateOverflowed value = value > maximumRawAggregateBlobBytes
#endif

mapAggregateOverflowLimit, mapAggregateOverflowObserved :: Int -> Int
#if defined(VALIDATION_COMPILER_GRAPH_RAW_AGGREGATE_OVERFLOW_LIMIT_PROJECTION_MUTANT)
mapAggregateOverflowLimit value = value + 1
#else
mapAggregateOverflowLimit = id
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_AGGREGATE_OVERFLOW_OBSERVED_PROJECTION_MUTANT)
mapAggregateOverflowObserved value = value + 1
#else
mapAggregateOverflowObserved = id
#endif

continueAggregateFold :: Int -> [RawEntry] -> Maybe RawProblem
#if defined(VALIDATION_COMPILER_GRAPH_RAW_AGGREGATE_RECURSION_ROUTE_MUTANT)
continueAggregateFold next _ = aggregateProblemFrom next []
#else
continueAggregateFold next rest = aggregateProblemFrom next rest
#endif

aggregateProblemFrom :: Int -> [RawEntry] -> Maybe RawProblem
aggregateProblemFrom initial entries = go initial entries
 where
  go total remaining = case remaining of
    [] -> Nothing
    entry : rest ->
      let blobBytes = mapAggregateBlobLength (ByteString.length (rawBytes entry))
          accumulated = mapAggregateAccumulator total blobBytes
          next = mapAggregateSaturation (min (maximumRawAggregateBlobBytes + 1) accumulated)
       in if aggregateOverflowed next
            then Just (RawAggregateBlobByteLimit (mapAggregateOverflowLimit maximumRawAggregateBlobBytes) (mapAggregateOverflowObserved next))
            else go next rest

countProblem :: Int -> (Int -> Int -> RawProblem) -> [value] -> Maybe RawProblem
countProblem limit constructor values = case boundedPrefix limit values of
  PrefixExceeded observed -> Just (constructor limit observed)
  PrefixWithin _ -> Nothing

pathDepthProblem :: Int -> FilePath -> Maybe RawProblem
pathDepthProblem ordinal path = case boundedPrefix maximumRawPathDepth (splitSlash path) of
  PrefixExceeded observed -> Just (RawPathDepthLimit ordinal maximumRawPathDepth observed)
  PrefixWithin _ -> Nothing

pathSegmentProblem :: Int -> FilePath -> Maybe RawProblem
pathSegmentProblem ordinal path =
  firstJust
    ( orderRawPathSegmentTraversal
        [ exceeded
            (boundedFilePathUtf8Length maximumRawPathSegmentBytes segment)
            (RawPathSegmentLimit ordinal maximumRawPathSegmentBytes)
        | segment <- splitSlash path
        ]
    )

orderRawPathSegmentTraversal :: [Maybe RawProblem] -> [Maybe RawProblem]
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_SEGMENT_TRAVERSAL_ORDER_MUTANT)
orderRawPathSegmentTraversal = reverse
#else
orderRawPathSegmentTraversal = id
#endif

firstGrammarProblem :: Text -> [RawEntry] -> Maybe RawProblem
firstGrammarProblem claimedIdentity entries =
  combineRawGrammarProblems
    (firstJust (orderRawEntryGrammarTraversal (zipWith entryGrammarProblem [1 ..] entries)))
    (duplicateProblem paths)
    (portableCaseProblem paths)
    (prefixProblem paths)
    (orderProblem paths)
    (mixedFormatProblem entries)
    (inventoryCountGrammarProblem entries)
    (identityGrammarProblem claimedIdentity entries)
 where
  paths = map rawPath entries

orderRawEntryGrammarTraversal :: [Maybe RawProblem] -> [Maybe RawProblem]
#if defined(VALIDATION_COMPILER_GRAPH_RAW_ENTRY_GRAMMAR_TRAVERSAL_ORDER_MUTANT)
orderRawEntryGrammarTraversal = reverse
#else
orderRawEntryGrammarTraversal = id
#endif

combineRawGrammarProblems
  :: Maybe RawProblem
  -> Maybe RawProblem
  -> Maybe RawProblem
  -> Maybe RawProblem
  -> Maybe RawProblem
  -> Maybe RawProblem
  -> Maybe RawProblem
  -> Maybe RawProblem
  -> Maybe RawProblem
combineRawGrammarProblems entry duplicate portable prefix order mixed inventory identity =
#if defined(VALIDATION_COMPILER_GRAPH_RAW_ENTRY_DUPLICATE_GRAMMAR_ORDER_MUTANT)
  duplicate `orElse` entry `orElse` portable `orElse` prefix `orElse` order `orElse` mixed `orElse` inventory `orElse` identity
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_DUPLICATE_PORTABLE_GRAMMAR_ORDER_MUTANT)
  entry `orElse` portable `orElse` duplicate `orElse` prefix `orElse` order `orElse` mixed `orElse` inventory `orElse` identity
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_PORTABLE_PREFIX_GRAMMAR_ORDER_MUTANT)
  entry `orElse` duplicate `orElse` prefix `orElse` portable `orElse` order `orElse` mixed `orElse` inventory `orElse` identity
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_PREFIX_ORDER_GRAMMAR_ORDER_MUTANT)
  entry `orElse` duplicate `orElse` portable `orElse` order `orElse` prefix `orElse` mixed `orElse` inventory `orElse` identity
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_ORDER_MIXED_GRAMMAR_ORDER_MUTANT)
  entry `orElse` duplicate `orElse` portable `orElse` prefix `orElse` mixed `orElse` order `orElse` inventory `orElse` identity
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_MIXED_INVENTORY_GRAMMAR_ORDER_MUTANT)
  entry `orElse` duplicate `orElse` portable `orElse` prefix `orElse` order `orElse` inventory `orElse` mixed `orElse` identity
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_INVENTORY_IDENTITY_GRAMMAR_ORDER_MUTANT)
  entry `orElse` duplicate `orElse` portable `orElse` prefix `orElse` order `orElse` mixed `orElse` identity `orElse` inventory
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_GRAMMAR_ROUTE_DROP_MUTANT)
  identity `seq` (entry `orElse` duplicate `orElse` portable `orElse` prefix `orElse` order `orElse` mixed `orElse` inventory)
#else
  entry `orElse` duplicate `orElse` portable `orElse` prefix `orElse` order `orElse` mixed `orElse` inventory `orElse` identity
#endif

entryGrammarProblem :: Int -> RawEntry -> Maybe RawProblem
entryGrammarProblem ordinal entry =
  combineRawEntryGrammarProblems
    (pathGrammarProblem ordinal (rawPath entry))
    (modeGrammarProblem ordinal (rawMode entry))
    (objectGrammarProblem ordinal (rawObjectIdentity entry) (rawBytes entry))
    haskellModeProblem
    cabalModeProblem
 where
  haskellModeProblem =
    [ RawHaskellSubjectModeRejected ordinal
    | isHaskellEntry entry
    , rawMode entry /= "100644"
    , not haskellModeBypassed
    ] `listHead` Nothing
  cabalModeProblem =
    [ RawCabalEntryModeRejected ordinal
    | isCabalEntry entry
    , rawMode entry /= "100644"
    , not cabalModeBypassed
    ] `listHead` Nothing

combineRawEntryGrammarProblems
  :: Maybe RawProblem
  -> Maybe RawProblem
  -> Maybe RawProblem
  -> Maybe RawProblem
  -> Maybe RawProblem
  -> Maybe RawProblem
combineRawEntryGrammarProblems path mode object haskell cabal =
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_MODE_GRAMMAR_ORDER_MUTANT)
  mode `orElse` path `orElse` object `orElse` haskell `orElse` cabal
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_MODE_OBJECT_GRAMMAR_ORDER_MUTANT)
  path `orElse` object `orElse` mode `orElse` haskell `orElse` cabal
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_OBJECT_HASKELL_GRAMMAR_ORDER_MUTANT)
  path `orElse` mode `orElse` haskell `orElse` object `orElse` cabal
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_CABAL_GRAMMAR_ROUTE_DROP_MUTANT)
  cabal `seq` (path `orElse` mode `orElse` object `orElse` haskell)
#else
  path `orElse` mode `orElse` object `orElse` haskell `orElse` cabal
#endif

pathGrammarProblem :: Int -> FilePath -> Maybe RawProblem
pathGrammarProblem ordinal path
  | null path && not pathEmptyBypassed = Just (RawPathEmpty ordinal)
  | isAbsolute path && not pathAbsoluteBypassed = Just (RawPathAbsolute ordinal)
  | '\0' `elem` path && not pathNulBypassed = Just (RawPathNul ordinal)
  | '\\' `elem` path && not pathBackslashBypassed = Just (RawPathBackslash ordinal)
  | any null parts && not pathEmptySegmentBypassed = Just (RawPathEmptySegment ordinal)
  | "." `elem` parts && not pathDotBypassed = Just (RawPathDotSegment ordinal)
  | ".." `elem` parts && not pathParentBypassed = Just (RawPathParentSegment ordinal)
  | any (not . safePathCharacter) path && not pathCharacterBypassed = Just (RawPathCharacterUnsafe ordinal)
  | otherwise = Nothing
 where
  parts = splitSlash path

modeGrammarProblem :: Int -> Text -> Maybe RawProblem
modeGrammarProblem ordinal mode
  | (mode == "100644" && admitRegularMode)
      || (mode == "100755" && admitExecutableMode)
      || (mode == "120000" && admitSymbolicLinkMode) = Nothing
#if defined(VALIDATION_COMPILER_GRAPH_RAW_MODE_GRAMMAR_WIDEN_MUTANT)
  | mode == "100664" = Nothing
#endif
  | otherwise = Just (RawModeMalformed ordinal)

objectGrammarProblem :: Int -> Text -> ByteString -> Maybe RawProblem
objectGrammarProblem ordinal objectIdentity bytes
  | not (validObjectIdentity objectIdentity) = Just (RawObjectIdentityMalformed ordinal)
  | objectIdentity /= expected && not objectContentBypassed =
      Just (RawObjectIdentityMismatch ordinal expected objectIdentity)
  | otherwise = Nothing
 where
  expected = gitBlobIdentity objectIdentity bytes

validObjectIdentity :: Text -> Bool
validObjectIdentity value =
  ((Text.length value == 40 && admitSha1ObjectIdentity)
    || (Text.length value == 64 && admitSha256ObjectIdentity))
    && Text.all objectIdentityHex value
 where
  objectIdentityHex character =
#if defined(VALIDATION_COMPILER_GRAPH_RAW_OBJECT_HEX_WIDEN_MUTANT)
    (admitObjectIdentityDigit && asciiDigit character)
      || (admitObjectIdentityLetter && character >= 'a' && character <= 'g')
#else
    (admitObjectIdentityDigit && asciiDigit character)
      || (admitObjectIdentityLetter && character >= 'a' && character <= 'f')
#endif

duplicateProblem :: [FilePath] -> Maybe RawProblem
duplicateProblem paths
  | duplicatePathBypassed = Nothing
  | repeated : _ <-
      orderRawDuplicateSelection
        [ path
        | groupedPaths <- group (sort paths)
        , rawDuplicateGroup groupedPaths
        , path : _ <- [groupedPaths]
        ] =
      Just (RawPathDuplicate repeated)
  | otherwise = Nothing

rawDuplicateGroup :: [value] -> Bool
#if defined(VALIDATION_COMPILER_GRAPH_RAW_DUPLICATE_GROUP_PREDICATE_MUTANT)
rawDuplicateGroup values = length values > 2
#else
rawDuplicateGroup values = length values > 1
#endif

orderRawDuplicateSelection :: [FilePath] -> [FilePath]
#if defined(VALIDATION_COMPILER_GRAPH_RAW_DUPLICATE_SELECTION_ORDER_MUTANT)
orderRawDuplicateSelection = reverse
#else
orderRawDuplicateSelection = id
#endif

portableCaseProblem :: [FilePath] -> Maybe RawProblem
portableCaseProblem paths
  | portableCaseBypassed = Nothing
  | colliding : _ <-
      orderRawPortableCollisionSelection
        [orderRawPortableMembers originals | originals <- grouped, rawPortableCollisionGroup originals]
  , first : second : _ <- colliding =
      Just (RawPathPortableCaseCollision first second)
  | otherwise = Nothing
 where
  grouped = map (map snd) (groupByKey (sort [(map toLower path, path) | path <- paths]))

rawPortableCollisionGroup :: [FilePath] -> Bool
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PORTABLE_COLLISION_PREDICATE_MUTANT)
rawPortableCollisionGroup originals = length originals > 2
#else
rawPortableCollisionGroup originals = length originals > 1
#endif

orderRawPortableCollisionSelection :: [[FilePath]] -> [[FilePath]]
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PORTABLE_COLLISION_SELECTION_ORDER_MUTANT)
orderRawPortableCollisionSelection = reverse
#else
orderRawPortableCollisionSelection = id
#endif

orderRawPortableMembers :: [FilePath] -> [FilePath]
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PORTABLE_MEMBER_SELECTION_ORDER_MUTANT)
orderRawPortableMembers = reverse . sort
#else
orderRawPortableMembers = sort
#endif

prefixProblem :: [FilePath] -> Maybe RawProblem
prefixProblem paths
  | prefixBypassed = Nothing
  | (parent, child) : _ <-
      orderRawPrefixSelection
        [ (parent, child)
        | parent <- ordered
        , child <- ordered
        , parent /= child
        , rawPathPrefix parent child
        ] = Just (RawPathPrefixConflict parent child)
  | otherwise = Nothing
 where
  ordered = sort paths

rawPathPrefix :: FilePath -> FilePath -> Bool
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PREFIX_PREDICATE_MUTANT)
rawPathPrefix parent child = (parent <> "/mutant/") `isPrefixOf` child
#else
rawPathPrefix parent child = (parent <> "/") `isPrefixOf` child
#endif

orderRawPrefixSelection :: [(FilePath, FilePath)] -> [(FilePath, FilePath)]
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PREFIX_SELECTION_ORDER_MUTANT)
orderRawPrefixSelection = reverse
#else
orderRawPrefixSelection = id
#endif

orderProblem :: [FilePath] -> Maybe RawProblem
orderProblem paths
  | orderBypassed || paths == sort paths = Nothing
  | otherwise = Just RawEntryOrderInvalid

mixedFormatProblem :: [RawEntry] -> Maybe RawProblem
mixedFormatProblem entries
  | mixedFormatBypassed || allSame (map (Text.length . rawObjectIdentity) entries) = Nothing
  | otherwise = Just RawObjectFormatsMixed

inventoryCountGrammarProblem :: [RawEntry] -> Maybe RawProblem
inventoryCountGrammarProblem entries
#if defined(VALIDATION_COMPILER_GRAPH_RAW_HASKELL_CABAL_EMPTY_GRAMMAR_ORDER_MUTANT)
  | null (filter isCabalEntry entries) && not cabalEmptyBypassed = Just RawCabalEntryInventoryEmpty
  | null (filter isHaskellEntry entries) && not haskellEmptyBypassed = Just RawHaskellSubjectInventoryEmpty
#else
  | null (filter isHaskellEntry entries) && not haskellEmptyBypassed = Just RawHaskellSubjectInventoryEmpty
  | null (filter isCabalEntry entries) && not cabalEmptyBypassed = Just RawCabalEntryInventoryEmpty
#endif
  | otherwise = Nothing

identityGrammarProblem :: Text -> [RawEntry] -> Maybe RawProblem
identityGrammarProblem claimedIdentity entries
  | not (validRawIdentity claimedIdentity) = Just RawIdentityMalformed
  | claimedIdentity /= expected && not identityMatchBypassed = Just (RawIdentityMismatch expected claimedIdentity)
  | otherwise = Nothing
 where
  expected = inventoryIdentity entries

validRawIdentity :: Text -> Bool
validRawIdentity value = Text.length value == 64 && Text.all rawIdentityHex value
 where
  rawIdentityHex character =
#if defined(VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_HEX_WIDEN_MUTANT)
    (admitRawIdentityDigit && asciiDigit character)
      || (admitRawIdentityLetter && character >= 'a' && character <= 'g')
#else
    (admitRawIdentityDigit && asciiDigit character)
      || (admitRawIdentityLetter && character >= 'a' && character <= 'f')
#endif

inventoryIdentity :: [RawEntry] -> Text
inventoryIdentity entries =
  digestChunks
    (Crypto.hashInit :: Crypto.Context Crypto.SHA256)
    ( orderInventoryChunks
        inventoryDomain
        (concatMap entryChunks (orderSerializedEntries entries))
    )

orderInventoryChunks :: ByteString -> [ByteString] -> [ByteString]
#if defined(VALIDATION_COMPILER_GRAPH_RAW_SERIALIZATION_DOMAIN_ORDER_MUTANT)
orderInventoryChunks domain chunks = chunks <> [domain]
#else
orderInventoryChunks domain chunks = domain : chunks
#endif

inventoryDomain :: ByteString
#if defined(VALIDATION_COMPILER_GRAPH_RAW_SERIALIZATION_DOMAIN_MUTANT)
inventoryDomain = "amoebius.compiler-source-graph.raw.v1-mutant\0"
#else
inventoryDomain = "amoebius.compiler-source-graph.raw.v1\0"
#endif

orderSerializedEntries :: [RawEntry] -> [RawEntry]
#if defined(VALIDATION_COMPILER_GRAPH_RAW_SERIALIZATION_ENTRY_ORDER_MUTANT)
orderSerializedEntries = reverse
#else
orderSerializedEntries = id
#endif

entryChunks :: RawEntry -> [ByteString]
entryChunks entry =
  concat (orderSerializedFields fields)
    <> [entrySeparator]
 where
  fields =
    [ serializedField retainSerializedMode (TextEncoding.encodeUtf8 (rawMode entry))
    , serializedField retainSerializedObjectIdentity (TextEncoding.encodeUtf8 (rawObjectIdentity entry))
    , serializedField retainSerializedPath (TextEncoding.encodeUtf8 (Text.pack (rawPath entry)))
    , serializedField
        retainSerializedLength
        (ByteString8.pack (renderSerializedLength (ByteString.length (rawBytes entry))))
    , serializedTerminalField retainSerializedBlob (rawBytes entry)
    ]

orderSerializedFields :: [[ByteString]] -> [[ByteString]]
#if defined(VALIDATION_COMPILER_GRAPH_RAW_SERIALIZATION_FIELD_ORDER_MUTANT)
orderSerializedFields = reverse
#else
orderSerializedFields = id
#endif

renderSerializedLength :: Int -> String
#if defined(VALIDATION_COMPILER_GRAPH_RAW_SERIALIZATION_LENGTH_MAPPING_MUTANT)
renderSerializedLength value = show value <> "0"
#else
renderSerializedLength = show
#endif

serializedField :: Bool -> ByteString -> [ByteString]
serializedField retainedField value =
  [value | retainedField] <> [fieldSeparator]

serializedTerminalField :: Bool -> ByteString -> [ByteString]
serializedTerminalField retainedField value = [value | retainedField]

fieldSeparator :: ByteString
#if defined(VALIDATION_COMPILER_GRAPH_RAW_SERIALIZATION_FIELD_SEPARATOR_MUTANT)
fieldSeparator = "|"
#else
fieldSeparator = "\0"
#endif

entrySeparator :: ByteString
#if defined(VALIDATION_COMPILER_GRAPH_RAW_SERIALIZATION_ENTRY_SEPARATOR_MUTANT)
entrySeparator = "|"
#else
entrySeparator = "\0"
#endif

retainSerializedMode, retainSerializedObjectIdentity, retainSerializedPath,
  retainSerializedLength, retainSerializedBlob :: Bool
#if defined(VALIDATION_COMPILER_GRAPH_RAW_SERIALIZATION_MODE_DROP_MUTANT)
retainSerializedMode = False
#else
retainSerializedMode = True
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_SERIALIZATION_OBJECT_IDENTITY_DROP_MUTANT)
retainSerializedObjectIdentity = False
#else
retainSerializedObjectIdentity = True
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_SERIALIZATION_PATH_DROP_MUTANT)
retainSerializedPath = False
#else
retainSerializedPath = True
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_SERIALIZATION_LENGTH_DROP_MUTANT)
retainSerializedLength = False
#else
retainSerializedLength = True
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_SERIALIZATION_BLOB_DROP_MUTANT)
retainSerializedBlob = False
#else
retainSerializedBlob = True
#endif

gitBlobIdentity :: Text -> ByteString -> Text
gitBlobIdentity shape bytes
  | Text.length shape == 40 && retainSha1DigestRoute =
      digestChunks
        (Crypto.hashInit :: Crypto.Context Crypto.SHA1)
        (sha1BlobChunks bytes)
  | Text.length shape == 40 =
      digestChunks
        (Crypto.hashInit :: Crypto.Context Crypto.SHA256)
        (sha256BlobChunks bytes)
  | useSha1ForSha256Route =
      digestChunks
        (Crypto.hashInit :: Crypto.Context Crypto.SHA1)
        (sha1BlobChunks bytes)
  | otherwise =
      digestChunks
        (Crypto.hashInit :: Crypto.Context Crypto.SHA256)
        (sha256BlobChunks bytes)

retainSha1DigestRoute, useSha1ForSha256Route :: Bool
#if defined(VALIDATION_COMPILER_GRAPH_RAW_SHA1_DIGEST_ROUTE_MUTANT)
retainSha1DigestRoute = False
#else
retainSha1DigestRoute = True
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_SHA256_DIGEST_ROUTE_MUTANT)
useSha1ForSha256Route = True
#else
useSha1ForSha256Route = False
#endif

sha1BlobChunks, sha256BlobChunks :: ByteString -> [ByteString]
#if defined(VALIDATION_COMPILER_GRAPH_RAW_SHA1_BLOB_MAPPING_MUTANT)
sha1BlobChunks bytes = orderSha1BlobChunks [gitBlobHeader bytes, bytes, "mutant"]
#else
sha1BlobChunks bytes = orderSha1BlobChunks [gitBlobHeader bytes, bytes]
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_SHA256_BLOB_MAPPING_MUTANT)
sha256BlobChunks bytes = orderSha256BlobChunks [gitBlobHeader bytes, bytes, "mutant"]
#else
sha256BlobChunks bytes = orderSha256BlobChunks [gitBlobHeader bytes, bytes]
#endif

orderSha1BlobChunks, orderSha256BlobChunks :: [ByteString] -> [ByteString]
#if defined(VALIDATION_COMPILER_GRAPH_RAW_SHA1_BLOB_CHUNK_ORDER_MUTANT)
orderSha1BlobChunks = reverse
#else
orderSha1BlobChunks = id
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_SHA256_BLOB_CHUNK_ORDER_MUTANT)
orderSha256BlobChunks = reverse
#else
orderSha256BlobChunks = id
#endif

gitBlobHeader :: ByteString -> ByteString
gitBlobHeader bytes =
  assembleBlobHeader
    blobHeaderTag
    (ByteString8.pack (renderBlobLength (ByteString.length bytes)))
    blobHeaderSeparator

assembleBlobHeader :: ByteString -> ByteString -> ByteString -> ByteString
#if defined(VALIDATION_COMPILER_GRAPH_RAW_BLOB_HEADER_ORDER_MUTANT)
assembleBlobHeader tag lengthBytes separator = lengthBytes <> tag <> separator
#else
assembleBlobHeader tag lengthBytes separator = tag <> lengthBytes <> separator
#endif

blobHeaderTag, blobHeaderSeparator :: ByteString
#if defined(VALIDATION_COMPILER_GRAPH_RAW_BLOB_HEADER_TAG_MUTANT)
blobHeaderTag = "blob-mutant "
#else
blobHeaderTag = "blob "
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_BLOB_HEADER_SEPARATOR_MUTANT)
blobHeaderSeparator = "|"
#else
blobHeaderSeparator = "\0"
#endif

renderBlobLength :: Int -> String
#if defined(VALIDATION_COMPILER_GRAPH_RAW_BLOB_HEADER_LENGTH_MUTANT)
renderBlobLength value = show value <> "0"
#else
renderBlobLength = show
#endif

digestChunks
  :: Crypto.HashAlgorithm algorithm
  => Crypto.Context algorithm
  -> [ByteString]
  -> Text
digestChunks initial chunks =
  Text.pack
    ( mapDigestRendering
        ( show
        ( Crypto.hashFinalize
            (List.foldl' Crypto.hashUpdate (mapDigestInitial initial) (mapDigestChunks chunks))
        )
        )
    )

mapDigestRendering :: String -> String
#if defined(VALIDATION_COMPILER_GRAPH_RAW_DIGEST_RENDER_MAPPING_MUTANT)
mapDigestRendering value = value <> "0"
#else
mapDigestRendering = id
#endif

mapDigestInitial :: Crypto.HashAlgorithm algorithm => Crypto.Context algorithm -> Crypto.Context algorithm
#if defined(VALIDATION_COMPILER_GRAPH_RAW_DIGEST_INITIAL_MAPPING_MUTANT)
mapDigestInitial initial = Crypto.hashUpdate initial (ByteString8.pack "mutant")
#else
mapDigestInitial = id
#endif

mapDigestChunks :: [ByteString] -> [ByteString]
#if defined(VALIDATION_COMPILER_GRAPH_RAW_DIGEST_CHUNK_ORDER_MUTANT)
mapDigestChunks = reverse
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_DIGEST_CHUNK_RETENTION_MUTANT)
mapDigestChunks = drop 1
#else
mapDigestChunks = id
#endif

rawProblemFinding :: RawProblem -> Finding
rawProblemFinding problem = case problem of
  RawIdentityByteLimit limit observed -> resource "IDENTITY-BYTE-LIMIT" "claimed-identity" limit observed
  RawEntryLimit limit observed -> resource "ENTRY-LIMIT" "inventory" limit observed
  RawPathByteLimit ordinal limit observed -> resource "PATH-BYTE-LIMIT" (entrySubject ordinal) limit observed
  RawPathDepthLimit ordinal limit observed -> resource "PATH-DEPTH-LIMIT" (entrySubject ordinal) limit observed
  RawPathSegmentLimit ordinal limit observed -> resource "PATH-SEGMENT-BYTE-LIMIT" (entrySubject ordinal) limit observed
  RawModeByteLimit ordinal limit observed -> resource "MODE-BYTE-LIMIT" (entrySubject ordinal) limit observed
  RawObjectIdentityByteLimit ordinal limit observed -> resource "OBJECT-IDENTITY-BYTE-LIMIT" (entrySubject ordinal) limit observed
  RawBlobByteLimit ordinal limit observed -> resource "BLOB-BYTE-LIMIT" (entrySubject ordinal) limit observed
  RawAggregateBlobByteLimit limit observed -> resource "AGGREGATE-BLOB-BYTE-LIMIT" "inventory" limit observed
  RawHaskellSubjectLimit limit observed -> resource "HASKELL-SUBJECT-LIMIT" "inventory" limit observed
  RawCabalEntryLimit limit observed -> resource "CABAL-ENTRY-LIMIT" "inventory" limit observed
  RawIdentityMalformed -> grammar "IDENTITY-MALFORMED" "claimed-identity" "expected exactly 64 lowercase hexadecimal characters"
  RawIdentityMismatch expected observed -> grammar "IDENTITY-MISMATCH" "claimed-identity" (renderRawIdentityMismatch expected observed)
  RawPathEmpty ordinal -> entryGrammar "PATH-EMPTY" ordinal "path must be nonempty"
  RawPathAbsolute ordinal -> entryGrammar "PATH-ABSOLUTE" ordinal "path must be relative"
  RawPathNul ordinal -> entryGrammar "PATH-NUL" ordinal "path must not contain NUL"
  RawPathBackslash ordinal -> entryGrammar "PATH-BACKSLASH" ordinal "path must use POSIX separators"
  RawPathEmptySegment ordinal -> entryGrammar "PATH-EMPTY-SEGMENT" ordinal "path segments must be nonempty"
  RawPathDotSegment ordinal -> entryGrammar "PATH-DOT-SEGMENT" ordinal "dot segments are forbidden"
  RawPathParentSegment ordinal -> entryGrammar "PATH-PARENT-SEGMENT" ordinal "parent segments are forbidden"
  RawPathCharacterUnsafe ordinal -> entryGrammar "PATH-CHARACTER-UNSAFE" ordinal "path contains a character outside the portable compiler-input alphabet"
  RawPathDuplicate path -> grammar "PATH-DUPLICATE" "inventory" ("duplicate path=" <> Text.pack (mapRawDuplicatePath path))
  RawPathPortableCaseCollision first second -> grammar "PATH-PORTABLE-CASE-COLLISION" "inventory" (renderRawPortableCollision first second)
  RawPathPrefixConflict first second -> grammar "PATH-PREFIX-CONFLICT" "inventory" (renderRawPrefixConflict first second)
  RawEntryOrderInvalid -> grammar "ENTRY-ORDER-INVALID" "inventory" "paths must be in strict canonical ascending order"
  RawModeMalformed ordinal -> entryGrammar "MODE-MALFORMED" ordinal "expected one of 100644, 100755, or 120000"
  RawObjectIdentityMalformed ordinal -> entryGrammar "OBJECT-IDENTITY-MALFORMED" ordinal "expected 40 or 64 lowercase hexadecimal characters"
  RawObjectIdentityMismatch ordinal expected observed -> entryGrammar "OBJECT-IDENTITY-MISMATCH" ordinal (renderRawObjectMismatch expected observed)
  RawObjectFormatsMixed -> grammar "OBJECT-FORMATS-MIXED" "inventory" "all Git object identities must use one storage format"
  RawHaskellSubjectModeRejected ordinal -> entryGrammar "HASKELL-SUBJECT-MODE-REJECTED" ordinal "tracked .hs compiler subjects must use mode 100644"
  RawCabalEntryModeRejected ordinal -> entryGrammar "CABAL-ENTRY-MODE-REJECTED" ordinal "tracked .cabal compiler declarations must use mode 100644"
  RawHaskellSubjectInventoryEmpty -> grammar "HASKELL-SUBJECT-INVENTORY-EMPTY" "inventory" "at least one exact .hs subject is required"
  RawCabalEntryInventoryEmpty -> grammar "CABAL-ENTRY-INVENTORY-EMPTY" "inventory" "at least one exact .cabal declaration is required"
 where
  resource suffix subject limit observed =
    finding
      ("COMPILER-GRAPH-RAW-" <> mapRawProblemCode problem suffix)
      (mapRawProblemSubject subject)
      ( mapRawProblemDetail
          ( "limit="
              <> Text.pack (show (mapRawResourceLimit limit))
              <> "; observed-at-least="
              <> Text.pack (show (mapRawResourceObserved observed))
          )
      )
  grammar suffix subject detail =
    finding
      ("COMPILER-GRAPH-RAW-" <> mapRawProblemCode problem suffix)
      (mapRawProblemSubject subject)
      (mapRawProblemDetail detail)
  entryGrammar suffix ordinal detail = grammar suffix (entrySubject ordinal) detail

mapRawResourceLimit, mapRawResourceObserved :: Int -> Int
#if defined(VALIDATION_COMPILER_GRAPH_RAW_RESOURCE_FINDING_LIMIT_PROJECTION_MUTANT)
mapRawResourceLimit value = value + 1
#else
mapRawResourceLimit = id
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_RESOURCE_FINDING_OBSERVED_PROJECTION_MUTANT)
mapRawResourceObserved value = value + 1
#else
mapRawResourceObserved = id
#endif

renderRawIdentityMismatch :: Text -> Text -> Text
renderRawIdentityMismatch expected observed =
  "expected="
    <> mapRawIdentityMismatchExpected expected
    <> "; observed="
    <> mapRawIdentityMismatchObserved observed

mapRawIdentityMismatchExpected, mapRawIdentityMismatchObserved :: Text -> Text
#if defined(VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_MISMATCH_EXPECTED_PROJECTION_MUTANT)
mapRawIdentityMismatchExpected value = value <> "-mutant"
#else
mapRawIdentityMismatchExpected = id
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_MISMATCH_OBSERVED_PROJECTION_MUTANT)
mapRawIdentityMismatchObserved value = value <> "-mutant"
#else
mapRawIdentityMismatchObserved = id
#endif

renderRawObjectMismatch :: Text -> Text -> Text
renderRawObjectMismatch expected observed =
  "expected="
    <> mapRawObjectMismatchExpected expected
    <> "; observed="
    <> mapRawObjectMismatchObserved observed

mapRawObjectMismatchExpected, mapRawObjectMismatchObserved :: Text -> Text
#if defined(VALIDATION_COMPILER_GRAPH_RAW_OBJECT_MISMATCH_EXPECTED_PROJECTION_MUTANT)
mapRawObjectMismatchExpected value = value <> "-mutant"
#else
mapRawObjectMismatchExpected = id
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_OBJECT_MISMATCH_OBSERVED_PROJECTION_MUTANT)
mapRawObjectMismatchObserved value = value <> "-mutant"
#else
mapRawObjectMismatchObserved = id
#endif

mapRawDuplicatePath :: FilePath -> FilePath
#if defined(VALIDATION_COMPILER_GRAPH_RAW_DUPLICATE_PATH_PROJECTION_MUTANT)
mapRawDuplicatePath value = value <> "-mutant"
#else
mapRawDuplicatePath = id
#endif

renderRawPortableCollision :: FilePath -> FilePath -> Text
renderRawPortableCollision first second =
  Text.pack (mapRawPortableFirst first)
    <> " collides with "
    <> Text.pack (mapRawPortableSecond second)

mapRawPortableFirst, mapRawPortableSecond :: FilePath -> FilePath
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PORTABLE_FIRST_PROJECTION_MUTANT)
mapRawPortableFirst value = value <> "-mutant"
#else
mapRawPortableFirst = id
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PORTABLE_SECOND_PROJECTION_MUTANT)
mapRawPortableSecond value = value <> "-mutant"
#else
mapRawPortableSecond = id
#endif

renderRawPrefixConflict :: FilePath -> FilePath -> Text
renderRawPrefixConflict first second =
  Text.pack (mapRawPrefixFirst first)
    <> " conflicts with "
    <> Text.pack (mapRawPrefixSecond second)

mapRawPrefixFirst, mapRawPrefixSecond :: FilePath -> FilePath
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PREFIX_FIRST_PROJECTION_MUTANT)
mapRawPrefixFirst value = value <> "-mutant"
#else
mapRawPrefixFirst = id
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PREFIX_SECOND_PROJECTION_MUTANT)
mapRawPrefixSecond value = value <> "-mutant"
#else
mapRawPrefixSecond = id
#endif

mapRawProblemCode :: RawProblem -> Text -> Text
mapRawProblemCode problem value =
#if defined(VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_BYTE_LIMIT_FINDING_CODE_MUTANT)
  changeCode (\case RawIdentityByteLimit {} -> True; _ -> False)
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_ENTRY_LIMIT_FINDING_CODE_MUTANT)
  changeCode (\case RawEntryLimit {} -> True; _ -> False)
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_BYTE_LIMIT_FINDING_CODE_MUTANT)
  changeCode (\case RawPathByteLimit {} -> True; _ -> False)
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_DEPTH_LIMIT_FINDING_CODE_MUTANT)
  changeCode (\case RawPathDepthLimit {} -> True; _ -> False)
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_SEGMENT_LIMIT_FINDING_CODE_MUTANT)
  changeCode (\case RawPathSegmentLimit {} -> True; _ -> False)
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_MODE_BYTE_LIMIT_FINDING_CODE_MUTANT)
  changeCode (\case RawModeByteLimit {} -> True; _ -> False)
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_OBJECT_IDENTITY_BYTE_LIMIT_FINDING_CODE_MUTANT)
  changeCode (\case RawObjectIdentityByteLimit {} -> True; _ -> False)
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_BLOB_BYTE_LIMIT_FINDING_CODE_MUTANT)
  changeCode (\case RawBlobByteLimit {} -> True; _ -> False)
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_AGGREGATE_BLOB_LIMIT_FINDING_CODE_MUTANT)
  changeCode (\case RawAggregateBlobByteLimit {} -> True; _ -> False)
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_HASKELL_LIMIT_FINDING_CODE_MUTANT)
  changeCode (\case RawHaskellSubjectLimit {} -> True; _ -> False)
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_CABAL_LIMIT_FINDING_CODE_MUTANT)
  changeCode (\case RawCabalEntryLimit {} -> True; _ -> False)
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_MALFORMED_FINDING_CODE_MUTANT)
  changeCode (== RawIdentityMalformed)
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_MISMATCH_FINDING_CODE_MUTANT)
  changeCode (\case RawIdentityMismatch {} -> True; _ -> False)
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_EMPTY_FINDING_CODE_MUTANT)
  changeCode (\case RawPathEmpty {} -> True; _ -> False)
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_ABSOLUTE_FINDING_CODE_MUTANT)
  changeCode (\case RawPathAbsolute {} -> True; _ -> False)
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_NUL_FINDING_CODE_MUTANT)
  changeCode (\case RawPathNul {} -> True; _ -> False)
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_BACKSLASH_FINDING_CODE_MUTANT)
  changeCode (\case RawPathBackslash {} -> True; _ -> False)
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_EMPTY_SEGMENT_FINDING_CODE_MUTANT)
  changeCode (\case RawPathEmptySegment {} -> True; _ -> False)
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_DOT_FINDING_CODE_MUTANT)
  changeCode (\case RawPathDotSegment {} -> True; _ -> False)
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_PARENT_FINDING_CODE_MUTANT)
  changeCode (\case RawPathParentSegment {} -> True; _ -> False)
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_CHARACTER_FINDING_CODE_MUTANT)
  changeCode (\case RawPathCharacterUnsafe {} -> True; _ -> False)
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_DUPLICATE_FINDING_CODE_MUTANT)
  changeCode (\case RawPathDuplicate {} -> True; _ -> False)
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_PORTABLE_CASE_FINDING_CODE_MUTANT)
  changeCode (\case RawPathPortableCaseCollision {} -> True; _ -> False)
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_PREFIX_FINDING_CODE_MUTANT)
  changeCode (\case RawPathPrefixConflict {} -> True; _ -> False)
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_ENTRY_ORDER_FINDING_CODE_MUTANT)
  changeCode (== RawEntryOrderInvalid)
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_MODE_MALFORMED_FINDING_CODE_MUTANT)
  changeCode (\case RawModeMalformed {} -> True; _ -> False)
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_OBJECT_MALFORMED_FINDING_CODE_MUTANT)
  changeCode (\case RawObjectIdentityMalformed {} -> True; _ -> False)
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_OBJECT_MISMATCH_FINDING_CODE_MUTANT)
  changeCode (\case RawObjectIdentityMismatch {} -> True; _ -> False)
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_MIXED_FORMAT_FINDING_CODE_MUTANT)
  changeCode (== RawObjectFormatsMixed)
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_HASKELL_MODE_FINDING_CODE_MUTANT)
  changeCode (\case RawHaskellSubjectModeRejected {} -> True; _ -> False)
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_CABAL_MODE_FINDING_CODE_MUTANT)
  changeCode (\case RawCabalEntryModeRejected {} -> True; _ -> False)
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_HASKELL_EMPTY_FINDING_CODE_MUTANT)
  changeCode (== RawHaskellSubjectInventoryEmpty)
#elif defined(VALIDATION_COMPILER_GRAPH_RAW_CABAL_EMPTY_FINDING_CODE_MUTANT)
  changeCode (== RawCabalEntryInventoryEmpty)
#else
  changeCode (const False)
#endif
 where
  changeCode selected = if selected problem then value <> "-MUTANT" else value

mapRawProblemSubject :: FilePath -> FilePath
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PROBLEM_FINDING_SUBJECT_MUTANT)
mapRawProblemSubject value = value <> "-mutant"
#else
mapRawProblemSubject = id
#endif

mapRawProblemDetail :: Text -> Text
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PROBLEM_FINDING_DETAIL_MUTANT)
mapRawProblemDetail value = value <> " (mutant)"
#else
mapRawProblemDetail = id
#endif

entrySubject :: Int -> FilePath
entrySubject ordinal = "entry-" <> show (mapRawEntrySubjectOrdinal ordinal)

mapRawEntrySubjectOrdinal :: Int -> Int
#if defined(VALIDATION_COMPILER_GRAPH_RAW_ENTRY_SUBJECT_ORDINAL_PROJECTION_MUTANT)
mapRawEntrySubjectOrdinal value = value + 1
#else
mapRawEntrySubjectOrdinal = id
#endif

isHaskellEntry :: RawEntry -> Bool
isHaskellEntry entry =
  admitHaskellSuffix && takeExtension (rawPath entry) == ".hs"

isCabalEntry :: RawEntry -> Bool
isCabalEntry entry =
  admitCabalSuffix && takeExtension (rawPath entry) == ".cabal"

safePathCharacter :: Char -> Bool
safePathCharacter character =
  (admitPathLower && isAsciiLower character)
    || (admitPathUpper && isAsciiUpper character)
    || (admitPathDigit && asciiDigit character)
    || (admitPathPunctuation && character `elem` ("._+-/" :: String))

asciiDigit :: Char -> Bool
asciiDigit character = character >= '0' && character <= '9'

admitRegularMode, admitExecutableMode, admitSymbolicLinkMode,
  admitSha1ObjectIdentity, admitSha256ObjectIdentity,
  admitRawIdentityDigit, admitRawIdentityLetter,
  admitObjectIdentityDigit, admitObjectIdentityLetter,
  admitHaskellSuffix, admitCabalSuffix,
  admitPathLower, admitPathUpper, admitPathDigit, admitPathPunctuation :: Bool
#if defined(VALIDATION_COMPILER_GRAPH_RAW_MODE_REGULAR_ALTERNATIVE_MUTANT)
admitRegularMode = False
#else
admitRegularMode = True
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_MODE_EXECUTABLE_ALTERNATIVE_MUTANT)
admitExecutableMode = False
#else
admitExecutableMode = True
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_MODE_SYMLINK_ALTERNATIVE_MUTANT)
admitSymbolicLinkMode = False
#else
admitSymbolicLinkMode = True
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_OBJECT_SHA1_ALTERNATIVE_MUTANT)
admitSha1ObjectIdentity = False
#else
admitSha1ObjectIdentity = True
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_OBJECT_SHA256_ALTERNATIVE_MUTANT)
admitSha256ObjectIdentity = False
#else
admitSha256ObjectIdentity = True
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_DIGIT_ALTERNATIVE_MUTANT)
admitRawIdentityDigit = False
#else
admitRawIdentityDigit = True
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_LETTER_ALTERNATIVE_MUTANT)
admitRawIdentityLetter = False
#else
admitRawIdentityLetter = True
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_OBJECT_DIGIT_ALTERNATIVE_MUTANT)
admitObjectIdentityDigit = False
#else
admitObjectIdentityDigit = True
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_OBJECT_LETTER_ALTERNATIVE_MUTANT)
admitObjectIdentityLetter = False
#else
admitObjectIdentityLetter = True
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_HASKELL_SUFFIX_ALTERNATIVE_MUTANT)
admitHaskellSuffix = False
#else
admitHaskellSuffix = True
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_CABAL_SUFFIX_ALTERNATIVE_MUTANT)
admitCabalSuffix = False
#else
admitCabalSuffix = True
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_LOWER_ALTERNATIVE_MUTANT)
admitPathLower = False
#else
admitPathLower = True
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_UPPER_ALTERNATIVE_MUTANT)
admitPathUpper = False
#else
admitPathUpper = True
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_DIGIT_ALTERNATIVE_MUTANT)
admitPathDigit = False
#else
admitPathDigit = True
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_PUNCTUATION_ALTERNATIVE_MUTANT)
admitPathPunctuation = False
#else
admitPathPunctuation = True
#endif

splitSlash :: FilePath -> [FilePath]
splitSlash value = case break splitSlashSeparator value of
  (part, []) -> splitSlashTerminal part
  (part, _ : rest) -> splitSlashHead part <> splitSlashRest rest

splitSlashSeparator :: Char -> Bool
#if defined(VALIDATION_COMPILER_GRAPH_RAW_SPLIT_SEPARATOR_PREDICATE_MUTANT)
splitSlashSeparator = (== '-')
#else
splitSlashSeparator = (== '/')
#endif

splitSlashTerminal :: FilePath -> [FilePath]
#if defined(VALIDATION_COMPILER_GRAPH_RAW_SPLIT_TERMINAL_PROJECTION_MUTANT)
splitSlashTerminal _ = []
#else
splitSlashTerminal value = [value]
#endif

splitSlashHead :: FilePath -> [FilePath]
#if defined(VALIDATION_COMPILER_GRAPH_RAW_SPLIT_HEAD_PROJECTION_MUTANT)
splitSlashHead _ = []
#else
splitSlashHead value = [value]
#endif

splitSlashRest :: FilePath -> [FilePath]
#if defined(VALIDATION_COMPILER_GRAPH_RAW_SPLIT_REST_PROJECTION_MUTANT)
splitSlashRest _ = []
#else
splitSlashRest = splitSlash
#endif

boundedFilePathUtf8Length :: Int -> FilePath -> BoundedPrefix ()
boundedFilePathUtf8Length limit = boundedUtf8Length limit

boundedTextUtf8Length :: Int -> Text -> BoundedPrefix ()
boundedTextUtf8Length limit = boundedUtf8Length limit . Text.unpack

boundedUtf8Length :: Int -> String -> BoundedPrefix ()
boundedUtf8Length limit = go 0
 where
  go count remaining = case remaining of
    [] -> PrefixWithin []
    character : rest ->
      let next = count + utf8Width character
       in if utf8LengthExceeded next limit
            then PrefixExceeded (mapUtf8ExceededObserved next)
#if defined(VALIDATION_COMPILER_GRAPH_RAW_UTF8_RECURSION_ROUTE_MUTANT)
            else rest `seq` PrefixWithin []
#else
            else go next rest
#endif

utf8LengthExceeded :: Int -> Int -> Bool
#if defined(VALIDATION_COMPILER_GRAPH_RAW_UTF8_BOUND_PREDICATE_MUTANT)
utf8LengthExceeded next limit = next >= limit
#else
utf8LengthExceeded next limit = next > limit
#endif

mapUtf8ExceededObserved :: Int -> Int
#if defined(VALIDATION_COMPILER_GRAPH_RAW_UTF8_OBSERVED_PROJECTION_MUTANT)
mapUtf8ExceededObserved value = value + 1
#else
mapUtf8ExceededObserved = id
#endif

utf8Width :: Char -> Int
utf8Width character
  | code <= 0x7f = asciiUtf8Width
  | code <= 0x7ff = twoByteUtf8Width
  | code <= 0xffff = threeByteUtf8Width
  | otherwise = fourByteUtf8Width
 where
  code = ord character

asciiUtf8Width, twoByteUtf8Width, threeByteUtf8Width, fourByteUtf8Width :: Int
#if defined(VALIDATION_COMPILER_GRAPH_RAW_UTF8_ASCII_WIDTH_MUTANT)
asciiUtf8Width = 2
#else
asciiUtf8Width = 1
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_UTF8_TWO_BYTE_WIDTH_MUTANT)
twoByteUtf8Width = 3
#else
twoByteUtf8Width = 2
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_UTF8_THREE_BYTE_WIDTH_MUTANT)
threeByteUtf8Width = 4
#else
threeByteUtf8Width = 3
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_UTF8_FOUR_BYTE_WIDTH_MUTANT)
fourByteUtf8Width = 5
#else
fourByteUtf8Width = 4
#endif

exceeded :: BoundedPrefix () -> (Int -> RawProblem) -> Maybe RawProblem
exceeded bounded constructor = case bounded of
  PrefixExceeded observed ->
#if defined(VALIDATION_COMPILER_GRAPH_RAW_EXCEEDED_PROBLEM_ROUTE_DROP_MUTANT)
    constructor observed `seq` Nothing
#else
    Just (constructor observed)
#endif
  PrefixWithin _ ->
#if defined(VALIDATION_COMPILER_GRAPH_RAW_EXCEEDED_WITHIN_ROUTE_MUTANT)
    Just (constructor 0)
#else
    Nothing
#endif

firstJust :: [Maybe value] -> Maybe value
firstJust values = case values of
  [] -> Nothing
  Just value : rest ->
#if defined(VALIDATION_COMPILER_GRAPH_RAW_FIRST_JUST_VALUE_ROUTE_DROP_MUTANT)
    value `seq` firstJust rest
#else
    rest `seq` Just value
#endif
  Nothing : rest ->
#if defined(VALIDATION_COMPILER_GRAPH_RAW_FIRST_JUST_NOTHING_ROUTE_DROP_MUTANT)
    rest `seq` Nothing
#else
    firstJust rest
#endif

orElse :: Maybe value -> Maybe value -> Maybe value
orElse first second = case first of
  Just _ ->
#if defined(VALIDATION_COMPILER_GRAPH_RAW_OR_ELSE_FIRST_ROUTE_DROP_MUTANT)
    second
#else
    first
#endif
  Nothing ->
#if defined(VALIDATION_COMPILER_GRAPH_RAW_OR_ELSE_SECOND_ROUTE_DROP_MUTANT)
    second `seq` Nothing
#else
    second
#endif

listHead :: [value] -> Maybe value -> Maybe value
listHead values fallback = case values of
#if defined(VALIDATION_COMPILER_GRAPH_RAW_LIST_HEAD_VALUE_ROUTE_DROP_MUTANT)
  value : _ -> value `seq` fallback
#else
  value : _ -> Just value
#endif
  [] -> fallback

decimalText :: Int -> Text
#if defined(VALIDATION_COMPILER_GRAPH_RAW_DECIMAL_TEXT_MAPPING_MUTANT)
decimalText value = Text.pack (show value) <> "-mutant"
#else
decimalText = Text.pack . show
#endif

allSame :: Eq value => [value] -> Bool
allSame values = case values of
  [] ->
#if defined(VALIDATION_COMPILER_GRAPH_RAW_ALL_SAME_EMPTY_ALTERNATIVE_MUTANT)
    False
#else
    True
#endif
  first : rest ->
#if defined(VALIDATION_COMPILER_GRAPH_RAW_ALL_SAME_NONEMPTY_PREDICATE_MUTANT)
    first `seq` rest `seq` False
#else
    all (== first) rest
#endif

groupByKey :: Eq key => [(key, value)] -> [[(key, value)]]
groupByKey values = case values of
  [] -> []
  first@(key, _) : rest ->
    let (same, remaining) = span (groupByKeyMatch key . fst) rest
        retained = retainGroupByKeyHead first same
     in retained : continueGroupByKey remaining

groupByKeyMatch :: Eq key => key -> key -> Bool
#if defined(VALIDATION_COMPILER_GRAPH_RAW_GROUP_KEY_PREDICATE_MUTANT)
groupByKeyMatch _ _ = False
#else
groupByKeyMatch = (==)
#endif

retainGroupByKeyHead :: (key, value) -> [(key, value)] -> [(key, value)]
#if defined(VALIDATION_COMPILER_GRAPH_RAW_GROUP_HEAD_RETENTION_MUTANT)
retainGroupByKeyHead _ same = same
#else
retainGroupByKeyHead first same = first : same
#endif

continueGroupByKey :: Eq key => [(key, value)] -> [[(key, value)]]
#if defined(VALIDATION_COMPILER_GRAPH_RAW_GROUP_RECURSION_ROUTE_MUTANT)
continueGroupByKey _ = []
#else
continueGroupByKey = groupByKey
#endif

pathEmptyBypassed, pathAbsoluteBypassed, pathNulBypassed, pathBackslashBypassed :: Bool
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_EMPTY_BYPASS_MUTANT)
pathEmptyBypassed = True
#else
pathEmptyBypassed = False
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_ABSOLUTE_BYPASS_MUTANT)
pathAbsoluteBypassed = True
#else
pathAbsoluteBypassed = False
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_NUL_BYPASS_MUTANT)
pathNulBypassed = True
#else
pathNulBypassed = False
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_BACKSLASH_BYPASS_MUTANT)
pathBackslashBypassed = True
#else
pathBackslashBypassed = False
#endif

pathEmptySegmentBypassed, pathDotBypassed, pathParentBypassed, pathCharacterBypassed :: Bool
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_EMPTY_SEGMENT_BYPASS_MUTANT)
pathEmptySegmentBypassed = True
#else
pathEmptySegmentBypassed = False
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_DOT_BYPASS_MUTANT)
pathDotBypassed = True
#else
pathDotBypassed = False
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_PARENT_BYPASS_MUTANT)
pathParentBypassed = True
#else
pathParentBypassed = False
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PATH_CHARACTER_BYPASS_MUTANT)
pathCharacterBypassed = True
#else
pathCharacterBypassed = False
#endif

duplicatePathBypassed, portableCaseBypassed, prefixBypassed, orderBypassed :: Bool
#if defined(VALIDATION_COMPILER_GRAPH_RAW_DUPLICATE_BYPASS_MUTANT)
duplicatePathBypassed = True
#else
duplicatePathBypassed = False
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PORTABLE_CASE_BYPASS_MUTANT)
portableCaseBypassed = True
#else
portableCaseBypassed = False
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_PREFIX_BYPASS_MUTANT)
prefixBypassed = True
#else
prefixBypassed = False
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_ORDER_BYPASS_MUTANT)
orderBypassed = True
#else
orderBypassed = False
#endif

objectContentBypassed, mixedFormatBypassed, identityMatchBypassed :: Bool
#if defined(VALIDATION_COMPILER_GRAPH_RAW_OBJECT_CONTENT_BYPASS_MUTANT)
objectContentBypassed = True
#else
objectContentBypassed = False
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_MIXED_FORMAT_BYPASS_MUTANT)
mixedFormatBypassed = True
#else
mixedFormatBypassed = False
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_IDENTITY_MATCH_BYPASS_MUTANT)
identityMatchBypassed = True
#else
identityMatchBypassed = False
#endif

haskellModeBypassed, cabalModeBypassed, haskellEmptyBypassed, cabalEmptyBypassed :: Bool
#if defined(VALIDATION_COMPILER_GRAPH_RAW_HASKELL_MODE_BYPASS_MUTANT)
haskellModeBypassed = True
#else
haskellModeBypassed = False
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_CABAL_MODE_BYPASS_MUTANT)
cabalModeBypassed = True
#else
cabalModeBypassed = False
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_HASKELL_EMPTY_BYPASS_MUTANT)
haskellEmptyBypassed = True
#else
haskellEmptyBypassed = False
#endif
#if defined(VALIDATION_COMPILER_GRAPH_RAW_CABAL_EMPTY_BYPASS_MUTANT)
cabalEmptyBypassed = True
#else
cabalEmptyBypassed = False
#endif
