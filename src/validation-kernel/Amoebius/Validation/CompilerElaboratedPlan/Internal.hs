{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.CompilerElaboratedPlan.Internal
  ( checkCompilerElaboratedPlanDiagnostic
  ) where

-- This is a byte parser for a deliberately small, versioned subset of Cabal's
-- diagnostic plan JSON.  It does not read a build directory, follow a
-- build-info path, invoke Cabal, or authenticate the supplied bytes.  The
-- diagnostic values use private positional constructors so callers cannot
-- mint them or replace an identity with record-update syntax.  The sole public
-- checker always returns a CheckResult with at least one refusal finding; no
-- public parser, subject value, success constructor, or evidence conversion is
-- exposed.  Parsing arbitrary bytes never creates an acquired plan or
-- qualification input.

import Amoebius.Validation.Types
import Data.Aeson (Object, Value (..), eitherDecodeStrict')
import Data.Aeson.Decoding.ByteString (bsToTokens)
import Data.Aeson.Decoding.Tokens
  ( TkArray (..)
  , TkRecord (..)
  , Tokens (..)
  )
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Crypto.Hash.SHA256 qualified as SHA256
import Data.Char (ord)
import Data.Foldable (toList)
import Data.Foldable qualified as Foldable
import Data.Graph (SCC (..), stronglyConnComp)
import Data.List (group, sort, sortOn)
import Data.List.NonEmpty (NonEmpty (..))
import Data.List.NonEmpty qualified as NonEmpty
import Data.Maybe (catMaybes, mapMaybe)
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding

compilerElaboratedPlanSchemaVersion :: (Text, Text)
compilerElaboratedPlanSchemaVersion = ("3.16.1.0", "3.16.1.0")

compilerElaboratedPlanMaximumInputBytes :: Int
compilerElaboratedPlanMaximumInputBytes = 8 * 1024 * 1024

compilerElaboratedPlanMaximumJsonDepth :: Int
compilerElaboratedPlanMaximumJsonDepth = 64

compilerElaboratedPlanMaximumJsonTokens :: Int
compilerElaboratedPlanMaximumJsonTokens = 1000000

compilerElaboratedPlanMaximumTextLength :: Int
compilerElaboratedPlanMaximumTextLength = 1024 * 1024

compilerElaboratedPlanMaximumObjectMembers :: Int
compilerElaboratedPlanMaximumObjectMembers = 65536

compilerElaboratedPlanMaximumArrayEntries :: Int
compilerElaboratedPlanMaximumArrayEntries = 65536

compilerElaboratedPlanMaximumSemanticBytes :: Int
compilerElaboratedPlanMaximumSemanticBytes = 512

compilerElaboratedPlanMaximumSourceBytes :: Int
compilerElaboratedPlanMaximumSourceBytes = 4096

compilerElaboratedPlanMaximumPathBytes :: Int
compilerElaboratedPlanMaximumPathBytes = 4096

compilerElaboratedPlanMaximumPathSegments :: Int
compilerElaboratedPlanMaximumPathSegments = 64

compilerElaboratedPlanMaximumPathSegmentBytes :: Int
compilerElaboratedPlanMaximumPathSegmentBytes = 255

compilerElaboratedPlanMaximumUnits :: Int
compilerElaboratedPlanMaximumUnits = 256

compilerElaboratedPlanMaximumComponents :: Int
compilerElaboratedPlanMaximumComponents = 128

compilerElaboratedPlanMaximumDependencies :: Int
compilerElaboratedPlanMaximumDependencies = 256

compilerElaboratedPlanMaximumFlags :: Int
compilerElaboratedPlanMaximumFlags = 128

compilerElaboratedPlanMaximumSourceMembers :: Int
compilerElaboratedPlanMaximumSourceMembers = 3

compilerElaboratedPlanMaximumProblems :: Int
compilerElaboratedPlanMaximumProblems = 128

compilerElaboratedPlanMaximumSemanticProblems :: Int
compilerElaboratedPlanMaximumSemanticProblems = 128

-- An observed diagnostic always retains fifteen independently necessary
-- refusal rows.  At most 113 data-dependent rows may accompany them, so a
-- public CheckResult never renders more than 128 findings.  If the variable
-- tail is larger, the complete mandatory prefix is followed by one exact
-- result-limit refusal rather than being replaced by it.
compilerElaboratedPlanMandatoryProblemCount :: Int
compilerElaboratedPlanMandatoryProblemCount = 15

compilerElaboratedPlanMaximumResultProblems :: Int
compilerElaboratedPlanMaximumResultProblems = 128

compilerElaboratedPlanMaximumObservedVariableProblems :: Int
compilerElaboratedPlanMaximumObservedVariableProblems =
  compilerElaboratedPlanMaximumResultProblems
    - compilerElaboratedPlanMandatoryProblemCount

data DiagnosticElaboratedUnitOrigin
  = PreExistingUnit
  | RemoteUnit
  | LocalUnit
  deriving (Eq, Ord, Enum, Bounded, Read, Show)

data DiagnosticElaboratedUnitBuildStyle
  = PreExistingBuildStyle
  | LocalBuildStyle
  | GlobalBuildStyle
  | InplaceBuildStyle
  deriving (Eq, Ord, Enum, Bounded, Read, Show)

data DiagnosticElaboratedComponentShape
  = DirectElaboratedComponentShape
  | AggregateElaboratedComponentShape
  deriving (Eq, Ord, Enum, Bounded, Read, Show)

data PackageSource
  = PreExistingPackageSource
  | LocalPackageSource FilePath
  | RepositoryTarPackageSource Text Text
  | SourceRepositoryPackageSource Text Text Text
  deriving (Eq, Ord, Read, Show)

data DiagnosticElaboratedComponent
  = DiagnosticElaboratedComponent
      Text
      Text
      [Text]
      [Text]
      (Maybe [FilePath])
  deriving (Eq, Ord, Show)

data DiagnosticElaboratedUnit
  = DiagnosticElaboratedUnit
      DiagnosticElaboratedUnitOrigin
      DiagnosticElaboratedUnitBuildStyle
      Text
      Text
      Text
      PackageSource
      [(Text, Bool)]
      [DiagnosticElaboratedComponent]
      (Maybe DiagnosticElaboratedComponentShape)
      [Text]
      (Maybe Text)
      (Maybe Text)
      (Maybe FilePath)
      (Maybe FilePath)
      (Maybe FilePath)
  deriving (Eq, Ord, Show)

data DiagnosticCompilerElaboratedPlanSnapshot
  = DiagnosticCompilerElaboratedPlanSnapshot
      Text
      Text
      Text
      Text
      Text
      Text
      [DiagnosticElaboratedUnit]
  deriving (Eq, Show)

data DiagnosticCompilerElaboratedPlanRefusal
  = DiagnosticCompilerElaboratedPlanRefusal
      (Maybe Text)
      Int
      (NonEmpty CompilerElaboratedPlanProblem)
      (Maybe DiagnosticCompilerElaboratedPlanSnapshot)

data CompilerElaboratedPlanProblem
  = PlanJsonInvalid Text
  | PlanRootNotObject
  | PlanJsonFieldMissing Text Text
  | PlanJsonFieldDuplicate Text Text
  | PlanJsonFieldUnknown Text Text
  | PlanJsonFieldUnexpected Text Text
  | PlanJsonFieldTypeMismatch Text Text Text
  | PlanJsonTextEmpty Text Text
  | PlanJsonTextMalformed Text Text Text
  | PlanJsonPathUnsafe Text Text FilePath
  | PlanResourceLimitExceeded Text Int Int
  | UnsupportedPlanSchemaVersion Text Text Text
  | UnsupportedInstallUnitType Int Text
  | UnsupportedConfiguredUnitStyle Text Text
  | UnsupportedPackageSourceType Text Text
  | UnsupportedRepositoryType Text Text
  | UnsupportedSourceRepositoryType Text Text
  | ConfiguredUnitComponentShapeMissing Text
  | ConfiguredUnitComponentShapeAmbiguous Text
  | ConfiguredUnitComponentDiscoveryEmpty Text
  | ConfiguredComponentNameMalformed Text Text
  | ConfiguredUnitOriginMismatch Text Text Text
  | PlanInputUnauthenticated Text Int
  | PlanArtifactGenerationUnavailable Text Int
  | ExpectedCompilerIdentityUnavailable Text Text
  | ExpectedPlatformIdentityUnavailable Text Text
  | IndependentDuplicateKeyObservationUnavailable Text Int
  | IndependentComponentUniverseUnavailable [(Text, Text)]
  | ConfigurationBranchClosureUnavailable
      [(Text, DiagnosticElaboratedUnitBuildStyle, Maybe DiagnosticElaboratedComponentShape, [(Text, Bool)], [Text])]
  | CppBranchClosureUnavailable
      [(Text, DiagnosticElaboratedUnitBuildStyle, Maybe DiagnosticElaboratedComponentShape, [(Text, Bool)], [Text])]
  | IndependentDependencySemanticsUnavailable [(Text, Text, Text)]
  | PackageSourceBytesIdentityUnavailable
      [(Text, Text, Maybe FilePath, Maybe Text, Maybe Text, Maybe Text, Maybe Text)]
  | BuildArtifactPathIdentityUnavailable
      [(Text, Maybe FilePath, Maybe FilePath, Maybe FilePath)]
  | LocalSourceRootIdentityLimitedToLexical [(Text, FilePath)]
  | LocalSourceRootFilesystemIdentityUnavailable [(Text, FilePath)]
  | CompilerElaboratedPlanSnapshotBindingUnavailable
      Text
      Int
      (Text, Text, Text, Text, Text, Text)
      [DiagnosticUnitObservationWire]
      [(Text, Text, Text)]
      [(Text, DiagnosticElaboratedUnitBuildStyle, Maybe DiagnosticElaboratedComponentShape, [(Text, Bool)], [Text])]
      [(Text, Text, Maybe FilePath, Maybe Text, Maybe Text, Maybe Text, Maybe Text)]
  | RemotePackageSourceHashMissing Text
  | RemotePackageSourceHashMalformed Text Text
  | RepositoryCabalHashMissing Text
  | RepositoryCabalHashMalformed Text Text
  | SourceRepositoryTagMutable Text Text
  | DuplicateElaboratedUnitId Text
  | DuplicateLocalComponent FilePath Text [Text]
  | DuplicateComponentDependency Text Text Text
  | SelfComponentDependency Text Text Text
  | UnknownComponentDependencyUnit Text Text Text
  | CyclicUnitDependencies [Text]
  | LocalUnitComponentDiscoveryEmpty Text
  | LocalComponentDiscoveryEmpty
  | LocalComponentSourcePathsUnavailable Text Text FilePath
  | CompilerElaboratedPlanOracleQualificationUnavailable
  | CompilerElaboratedPlanDiagnosticInvariantRefused Text
  deriving (Eq, Ord, Read, Show)

data Parsed value = Parsed [CompilerElaboratedPlanProblem] (Maybe value)

data ParsedUnit = ParsedUnit DiagnosticElaboratedUnit [Text]

data ConfiguredComponentShape
  = DirectComponentShape Text
  | ComponentMapShape
  deriving (Eq, Ord, Show)

data JsonPathSegment
  = JsonObjectField Text
  | JsonArrayIndex Int
  deriving (Eq, Ord, Show)

newtype JsonPath = JsonPath [JsonPathSegment]
  deriving (Eq, Ord, Show)

data JsonScanBudget = JsonScanBudget Int Int

data JsonScanFailure
  = JsonScanInvalid Text
  | JsonScanResourceLimit Text Int Int

type DiagnosticComponentObservationWire =
  (Text, Text, [Text], [Text], Maybe [FilePath])

type DiagnosticUnitObservationWire =
  ( (DiagnosticElaboratedUnitOrigin, DiagnosticElaboratedUnitBuildStyle, Text, Text, Text)
  , (Text, Maybe FilePath, Maybe Text, Maybe Text, Maybe Text)
  , ([(Text, Bool)], Maybe DiagnosticElaboratedComponentShape, [Text], Maybe Text, Maybe Text)
  , (Maybe FilePath, Maybe FilePath, Maybe FilePath)
  , [DiagnosticComponentObservationWire]
  )

checkCompilerElaboratedPlanDiagnostic :: ByteString -> CheckResult
checkCompilerElaboratedPlanDiagnostic bytes =
  foldDiagnosticCompilerElaboratedPlanRefusal
    (parseCompilerElaboratedPlanDiagnostic bytes)
    (\digest inputBytes problems ->
      diagnosticCheckResult digest inputBytes "malformed-refusal" problems [])
    ( \digest inputBytes problems cabalVersion cabalLibraryVersion compilerId compilerAbi
        operatingSystem architecture units ->
        observedDiagnosticCheckResult
          digest
          inputBytes
          "observed-refusal"
          problems
          ( observation
              rootObservationKey
              (rootObservationValue digest cabalVersion cabalLibraryVersion compilerId compilerAbi operatingSystem architecture)
              : projectUnitObservationOrder (zipWith (unitObservation digest) [0 :: Int ..] units)
          )
    )

rootObservationKey :: Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_ROOT_OBSERVATION_KEY_MAPPING_MUTANT)
rootObservationKey = "compiler-elaborated-plan.mutated-root"
#else
rootObservationKey = "compiler-elaborated-plan.root"
#endif

rootObservationValue :: Maybe Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text
rootObservationValue digest cabalVersion cabalLibraryVersion compilerId compilerAbi operatingSystem architecture =
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_ROOT_OBSERVATION_VALUE_MAPPING_MUTANT)
  digest `seq` cabalVersion `seq` cabalLibraryVersion `seq` compilerId `seq` compilerAbi `seq` operatingSystem `seq` architecture `seq` "mutated-root"
#else
  Text.pack
    ( show
        ( digest
        , (cabalVersion, cabalLibraryVersion, compilerId, compilerAbi, operatingSystem, architecture)
        )
    )
#endif

projectUnitObservationOrder :: [Observation] -> [Observation]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_OBSERVATION_ORDER_MUTANT)
projectUnitObservationOrder = reverse
#else
projectUnitObservationOrder = id
#endif

diagnosticCheckResult
  :: Maybe Text
  -> Int
  -> Text
  -> NonEmpty CompilerElaboratedPlanProblem
  -> [Observation]
  -> CheckResult
diagnosticCheckResult digest inputBytes status problems subjectObservations =
  CheckResult
    { checkName = diagnosticCheckName
    , checkObservations =
        [ observation
            diagnosticInputDigestObservationKey
            (diagnosticInputDigestObservationValue digest)
        , observation
            diagnosticInputBytesObservationKey
            (diagnosticInputBytesObservationValue inputBytes)
        , observation diagnosticStatusObservationKey (diagnosticStatusObservationValue status)
        ]
          <> projectSubjectObservationContribution subjectObservations
    , checkFindings = projectFindingOrder (map problemFinding (NonEmpty.toList problems))
    }

diagnosticCheckName :: Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_CHECK_NAME_MAPPING_MUTANT)
diagnosticCheckName = "compiler-elaborated-plan-mutated"
#else
diagnosticCheckName = "compiler-elaborated-plan-diagnostic-refusal"
#endif

diagnosticInputDigestObservationKey :: Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_INPUT_DIGEST_OBSERVATION_KEY_MAPPING_MUTANT)
diagnosticInputDigestObservationKey = "compiler-elaborated-plan.mutated-sha256"
#else
diagnosticInputDigestObservationKey = "compiler-elaborated-plan.input-sha256"
#endif

diagnosticInputDigestObservationValue :: Maybe Text -> Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_INPUT_DIGEST_OBSERVATION_VALUE_MAPPING_MUTANT)
diagnosticInputDigestObservationValue _ = "mutated-digest"
#else
diagnosticInputDigestObservationValue = maybe "unavailable-over-input-limit" id
#endif

diagnosticInputBytesObservationKey :: Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_INPUT_BYTES_OBSERVATION_KEY_MAPPING_MUTANT)
diagnosticInputBytesObservationKey = "compiler-elaborated-plan.mutated-bytes"
#else
diagnosticInputBytesObservationKey = "compiler-elaborated-plan.input-bytes"
#endif

diagnosticInputBytesObservationValue :: Int -> Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_INPUT_BYTES_OBSERVATION_VALUE_MAPPING_MUTANT)
diagnosticInputBytesObservationValue _ = "0"
#else
diagnosticInputBytesObservationValue = Text.pack . show
#endif

diagnosticStatusObservationKey :: Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_STATUS_OBSERVATION_KEY_MAPPING_MUTANT)
diagnosticStatusObservationKey = "compiler-elaborated-plan.mutated-status"
#else
diagnosticStatusObservationKey = "compiler-elaborated-plan.status"
#endif

diagnosticStatusObservationValue :: Text -> Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_STATUS_OBSERVATION_VALUE_MAPPING_MUTANT)
diagnosticStatusObservationValue _ = "mutated-status"
#else
diagnosticStatusObservationValue = id
#endif

projectSubjectObservationContribution :: [Observation] -> [Observation]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_SUBJECT_OBSERVATION_CONTRIBUTION_DROP_MUTANT)
projectSubjectObservationContribution _ = []
#else
projectSubjectObservationContribution = id
#endif

projectFindingOrder :: [Finding] -> [Finding]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_FINDING_ORDER_MUTANT)
projectFindingOrder = reverse
#else
projectFindingOrder = id
#endif

-- The public-refusal changed subject belongs specifically to the successfully
-- decoded observation route.  Malformed-plan diagnostics are independent
-- controls and must not be erased by the same selector.
observedDiagnosticCheckResult
  :: Maybe Text
  -> Int
  -> Text
  -> NonEmpty CompilerElaboratedPlanProblem
  -> [Observation]
  -> CheckResult
observedDiagnosticCheckResult digest inputBytes status problems subjectObservations =
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_PUBLIC_REFUSAL_BYPASS_MUTANT
  let result = diagnosticCheckResult digest inputBytes status problems subjectObservations
   in problemFinding (NonEmpty.head problems) `seq` result {checkFindings = []}
#else
  diagnosticCheckResult digest inputBytes status problems subjectObservations
#endif

problemFinding :: CompilerElaboratedPlanProblem -> Finding
problemFinding problem =
  finding
    (problemFindingCode problem)
    (problemFindingSubject problem)
    (problemFindingDetail problem)

problemFindingCode :: CompilerElaboratedPlanProblem -> Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_FINDING_CODE_MAPPING_MUTANT)
problemFindingCode problem = problem `seq` "MUTATED-CODE"
#else
problemFindingCode _ = "COMPILER-ELABORATED-PLAN-DIAGNOSTIC-REFUSAL"
#endif

problemFindingSubject :: CompilerElaboratedPlanProblem -> FilePath
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_FINDING_SUBJECT_MAPPING_MUTANT)
problemFindingSubject problem = problem `seq` "mutated.json"
#else
problemFindingSubject _ = "compiler-elaborated-plan.json"
#endif

problemFindingDetail :: CompilerElaboratedPlanProblem -> Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_FINDING_DETAIL_MAPPING_MUTANT)
problemFindingDetail problem = problem `seq` "mutated-detail"
#else
problemFindingDetail = Text.pack . show
#endif

unitObservation :: Maybe Text -> Int -> DiagnosticElaboratedUnit -> Observation
unitObservation digest index unit =
  observation
    (unitObservationKey index)
    (unitObservationValue digest index unit)

unitObservationKey :: Int -> Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_OBSERVATION_KEY_MAPPING_MUTANT)
unitObservationKey index = index `seq` "compiler-elaborated-plan.unit.mutated"
#else
unitObservationKey index = "compiler-elaborated-plan.unit." <> Text.pack (show index)
#endif

unitObservationValue :: Maybe Text -> Int -> DiagnosticElaboratedUnit -> Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_OBSERVATION_VALUE_MAPPING_MUTANT)
unitObservationValue digest index unit = digest `seq` index `seq` unit `seq` "mutated-unit"
#else
unitObservationValue digest index unit =
  Text.pack (show (digest, index, diagnosticUnitObservationWire unit))
#endif

diagnosticUnitObservationWire
  :: DiagnosticElaboratedUnit
  -> DiagnosticUnitObservationWire
diagnosticUnitObservationWire unit =
  ( ( diagnosticElaboratedUnitOrigin unit
    , diagnosticElaboratedUnitBuildStyle unit
    , diagnosticElaboratedUnitId unit
    , diagnosticElaboratedUnitPackageName unit
    , diagnosticElaboratedUnitPackageVersion unit
    )
  , ( diagnosticElaboratedUnitPackageSourceKind unit
    , diagnosticElaboratedUnitPackageSourceRoot unit
    , diagnosticElaboratedUnitPackageSourceLocation unit
    , diagnosticElaboratedUnitPackageSourceTag unit
    , diagnosticElaboratedUnitRepositoryType unit
    )
  , ( diagnosticElaboratedUnitFlags unit
    , diagnosticElaboratedUnitComponentShape unit
    , diagnosticElaboratedUnitDependencyUnitIds unit
    , diagnosticElaboratedUnitPackageCabalSha256 unit
    , diagnosticElaboratedUnitPackageSourceSha256 unit
    )
  , ( diagnosticElaboratedUnitBuildInfoPath unit
    , diagnosticElaboratedUnitDistDirectoryPath unit
    , diagnosticElaboratedUnitBinaryPath unit
    )
  , map diagnosticComponentObservationWire (diagnosticElaboratedUnitComponents unit)
  )

diagnosticComponentObservationWire
  :: DiagnosticElaboratedComponent
  -> DiagnosticComponentObservationWire
diagnosticComponentObservationWire component =
  ( diagnosticElaboratedComponentUnitId component
  , diagnosticElaboratedComponentName component
  , diagnosticElaboratedComponentDependencyUnitIds component
  , diagnosticElaboratedComponentExecutableDependencyUnitIds component
  , diagnosticElaboratedComponentSourcePaths component
  )

parseCompilerElaboratedPlanDiagnostic
  :: ByteString
  -> DiagnosticCompilerElaboratedPlanRefusal
parseCompilerElaboratedPlanDiagnostic bytes =
  if inputByteLimitExceeded inputBytes
    then
      singleProblemRefusal
        Nothing
        inputBytes
        ( PlanResourceLimitExceeded
            "input-bytes"
            compilerElaboratedPlanMaximumInputBytes
            inputBytes
        )
    else case duplicateJsonKeyProblems bytes of
      Left failure -> singleProblemRefusal inputDigest inputBytes (jsonScanFailureProblem failure)
      Right duplicateProblems ->
        case eitherDecodeStrict' bytes of
          Left _ ->
            singleProblemRefusal inputDigest inputBytes aesonDecodeFailureProblem
          Right decoded
            | not (null duplicateProblems) ->
                hardRefusal inputDigest inputBytes duplicateProblems
            | otherwise -> case decoded of
                Object root -> case projectRootObjectRoute root of
                  Nothing -> singleProblemRefusal inputDigest inputBytes PlanRootNotObject
                  Just admittedRoot -> case parseRoot admittedRoot of
                    Left problems -> hardRefusal inputDigest inputBytes problems
                    Right snapshot ->
                      let (mandatoryProblems, variableProblems) =
                            diagnosticPlanResidue inputSha256 inputBytes snapshot
                       in observedRefusal
                            inputDigest
                            inputBytes
                            mandatoryProblems
                            variableProblems
                            snapshot
                value -> singleProblemRefusal inputDigest inputBytes (rootNonObjectProblem value)
 where
  inputBytes = ByteString.length bytes
  inputSha256 = sha256Text bytes
  inputDigest = Just inputSha256

aesonDecodeFailureProblem :: CompilerElaboratedPlanProblem
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_AESON_DECODE_FAILURE_MAPPING_MUTANT)
aesonDecodeFailureProblem = PlanRootNotObject
#else
aesonDecodeFailureProblem = PlanJsonInvalid "aeson-decode-invalid"
#endif

projectRootObjectRoute :: Object -> Maybe Object
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_ROOT_OBJECT_ROUTE_DROP_MUTANT)
projectRootObjectRoute root = root `seq` Nothing
#else
projectRootObjectRoute = Just
#endif

rootNonObjectProblem :: Value -> CompilerElaboratedPlanProblem
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_ROOT_NON_OBJECT_MAPPING_MUTANT)
rootNonObjectProblem value = value `seq` PlanJsonInvalid "mutated-root-type"
#else
rootNonObjectProblem _ = PlanRootNotObject
#endif

duplicateJsonKeyProblems
  :: ByteString
  -> Either JsonScanFailure [CompilerElaboratedPlanProblem]
duplicateJsonKeyProblems bytes = do
  (problems, _, _) <-
    scanJsonTokens
      (JsonPath [])
      0
      (JsonScanBudget 0 0)
      (bsToTokens bytes)
  pure problems

scanJsonTokens
  :: JsonPath
  -> Int
  -> JsonScanBudget
  -> Tokens continuation String
  -> Either
      JsonScanFailure
      ([CompilerElaboratedPlanProblem], continuation, JsonScanBudget)
scanJsonTokens path depth budget tokens = do
  nextBudget <- consumeJsonToken budget
  case tokens of
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_JSON_LITERAL_TOKEN_ROUTE_MUTANT)
    TkLit _ continuation -> continuation `seq` Left (JsonScanInvalid "mutated-literal-route")
#else
    TkLit _ continuation -> Right ([], continuation, nextBudget)
#endif
    TkText value continuation -> do
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_JSON_TEXT_TOKEN_ROUTE_MUTANT)
      checkJsonStringLength (min 0 (Text.length value))
#else
      checkJsonStringLength (Text.length value)
#endif
      Right ([], continuation, nextBudget)
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_JSON_NUMBER_TOKEN_ROUTE_MUTANT)
    TkNumber _ continuation -> continuation `seq` Left (JsonScanInvalid "mutated-number-route")
#else
    TkNumber _ continuation -> Right ([], continuation, nextBudget)
#endif
    TkArrayOpen values -> do
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_JSON_ARRAY_DEPTH_ROUTE_MUTANT)
      let nextDepth = depth
#else
      nextDepth <- enterJsonContainer depth
#endif
      scanJsonArray path nextDepth 0 nextBudget values
    TkRecordOpen fields -> do
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RECORD_DEPTH_ROUTE_MUTANT)
      let nextDepth = depth
#else
      nextDepth <- enterJsonContainer depth
#endif
      scanJsonRecord path nextDepth 0 Set.empty nextBudget fields
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_JSON_TOKEN_ERROR_ROUTE_MUTANT)
    TkErr message -> Text.length (Text.pack message) `seq` Left (JsonScanResourceLimit "mutated-token-error" 0 1)
#else
    TkErr message -> Left (JsonScanInvalid (Text.pack message))
#endif

scanJsonArray
  :: JsonPath
  -> Int
  -> Int
  -> JsonScanBudget
  -> TkArray continuation String
  -> Either
      JsonScanFailure
      ([CompilerElaboratedPlanProblem], continuation, JsonScanBudget)
scanJsonArray path depth index budget values = case values of
  TkItem tokens -> do
    checkJsonArraySize (index + 1)
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_JSON_ARRAY_ITEM_TOKEN_COUNT_DROP_MUTANT)
    let itemBudget = budget
#else
    itemBudget <- consumeJsonToken budget
#endif
    (itemProblems, remaining, afterItem) <-
      scanJsonTokens
        (appendJsonIndex path index)
        depth
        itemBudget
        tokens
    (remainingProblems, continuation, finalBudget) <-
      scanJsonArray path depth (index + 1) afterItem remaining
    pure (itemProblems <> remainingProblems, continuation, finalBudget)
  TkArrayEnd continuation -> do
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_JSON_ARRAY_END_TOKEN_COUNT_DROP_MUTANT)
    let finalBudget = budget
#else
    finalBudget <- consumeJsonToken budget
#endif
    Right ([], continuation, finalBudget)
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_JSON_ARRAY_ERROR_ROUTE_MUTANT)
  TkArrayErr message -> Text.length (Text.pack message) `seq` Left (JsonScanResourceLimit "mutated-array-error" 0 1)
#else
  TkArrayErr message -> Left (JsonScanInvalid (Text.pack message))
#endif

scanJsonRecord
  :: JsonPath
  -> Int
  -> Int
  -> Set Text
  -> JsonScanBudget
  -> TkRecord continuation String
  -> Either
      JsonScanFailure
      ([CompilerElaboratedPlanProblem], continuation, JsonScanBudget)
scanJsonRecord path depth fieldCount seen budget fields = case fields of
  TkPair key tokens -> do
    let name = Key.toText key
        duplicateObserved = duplicateJsonKeyObserved name seen
    checkJsonObjectSize (fieldCount + 1)
    checkJsonKeyLength (Text.length name)
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RECORD_PAIR_TOKEN_COUNT_DROP_MUTANT)
    let pairBudget = budget
#else
    pairBudget <- consumeJsonToken budget
#endif
    afterDuplicate <-
      if duplicateObserved
        then recordJsonProblem pairBudget
        else Right pairBudget
    let duplicateProblems =
          [ PlanJsonFieldDuplicate (renderJsonPath path) name
          | duplicateObserved
          ]
    (valueProblems, remaining, afterValue) <-
      scanJsonTokens (appendJsonField path name) depth afterDuplicate tokens
    (remainingProblems, continuation, finalBudget) <-
      scanJsonRecord
        path
        depth
        (fieldCount + 1)
        (Set.insert name seen)
        afterValue
        remaining
    pure
      ( duplicateProblems <> valueProblems <> remainingProblems
      , continuation
      , finalBudget
      )
  TkRecordEnd continuation -> do
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RECORD_END_TOKEN_COUNT_DROP_MUTANT)
    let finalBudget = budget
#else
    finalBudget <- consumeJsonToken budget
#endif
    Right ([], continuation, finalBudget)
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RECORD_ERROR_ROUTE_MUTANT)
  TkRecordErr message -> Text.length (Text.pack message) `seq` Left (JsonScanResourceLimit "mutated-record-error" 0 1)
#else
  TkRecordErr message -> Left (JsonScanInvalid (Text.pack message))
#endif

duplicateJsonKeyObserved :: Text -> Set Text -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_KEY_BYPASS_MUTANT
duplicateJsonKeyObserved _ _ = False
#else
duplicateJsonKeyObserved = Set.member
#endif

consumeJsonToken :: JsonScanBudget -> Either JsonScanFailure JsonScanBudget
consumeJsonToken (JsonScanBudget tokens problems)
  | jsonTokenLimitExceeded observed =
      Left
        ( JsonScanResourceLimit
            "json-tokens"
            compilerElaboratedPlanMaximumJsonTokens
            observed
        )
  | otherwise = Right (JsonScanBudget observed problems)
 where
  observed = tokens + 1

recordJsonProblem :: JsonScanBudget -> Either JsonScanFailure JsonScanBudget
recordJsonProblem (JsonScanBudget tokens problems)
  | duplicateProblemLimitExceeded observed =
      Left
        ( JsonScanResourceLimit
            "duplicate-key-problems"
            compilerElaboratedPlanMaximumProblems
            observed
        )
  | otherwise = Right (JsonScanBudget tokens observed)
 where
  observed = problems + 1

enterJsonContainer :: Int -> Either JsonScanFailure Int
enterJsonContainer depth
  | jsonDepthLimitExceeded observed =
      Left
        ( JsonScanResourceLimit
            "json-depth"
            compilerElaboratedPlanMaximumJsonDepth
            observed
        )
  | otherwise = Right observed
 where
  observed = depth + 1

checkJsonStringLength :: Int -> Either JsonScanFailure ()
checkJsonStringLength observed
  | jsonStringLimitExceeded observed =
      Left
        ( JsonScanResourceLimit
            "json-string-code-points"
            compilerElaboratedPlanMaximumTextLength
            observed
        )
  | otherwise = Right ()

checkJsonKeyLength :: Int -> Either JsonScanFailure ()
checkJsonKeyLength observed
  | jsonKeyLimitExceeded observed =
      Left
        ( JsonScanResourceLimit
            "json-key-code-points"
            compilerElaboratedPlanMaximumTextLength
            observed
        )
  | otherwise = Right ()

checkJsonArraySize :: Int -> Either JsonScanFailure ()
checkJsonArraySize observed
  | jsonArrayLimitExceeded observed =
      Left
        ( JsonScanResourceLimit
            "json-array-entries"
            compilerElaboratedPlanMaximumArrayEntries
            observed
        )
  | otherwise = Right ()

checkJsonObjectSize :: Int -> Either JsonScanFailure ()
checkJsonObjectSize observed
  | jsonObjectLimitExceeded observed =
      Left
        ( JsonScanResourceLimit
            "json-object-members"
            compilerElaboratedPlanMaximumObjectMembers
            observed
        )
  | otherwise = Right ()

jsonScanFailureProblem :: JsonScanFailure -> CompilerElaboratedPlanProblem
jsonScanFailureProblem failure = case failure of
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_JSON_INVALID_FAILURE_MAPPING_MUTANT)
  JsonScanInvalid message -> message `seq` PlanRootNotObject
#else
  JsonScanInvalid _ -> PlanJsonInvalid "token-scan-invalid"
#endif
  JsonScanResourceLimit label limit observed ->
    PlanResourceLimitExceeded
      (jsonResourceFailureLabel label)
      (jsonResourceFailureLimit limit)
      (jsonResourceFailureObserved observed)

jsonResourceFailureLabel :: Text -> Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RESOURCE_FAILURE_LABEL_MAPPING_MUTANT)
jsonResourceFailureLabel _ = "mutated-resource"
#else
jsonResourceFailureLabel = id
#endif

jsonResourceFailureLimit :: Int -> Int
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RESOURCE_FAILURE_LIMIT_MAPPING_MUTANT)
jsonResourceFailureLimit = const 0
#else
jsonResourceFailureLimit = id
#endif

jsonResourceFailureObserved :: Int -> Int
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RESOURCE_FAILURE_OBSERVED_MAPPING_MUTANT)
jsonResourceFailureObserved = const 0
#else
jsonResourceFailureObserved = id
#endif

limitExceeded :: Int -> Int -> Bool
limitExceeded limit observed = observed > limit

inputByteLimitExceeded :: Int -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_INPUT_BYTE_LIMIT_BYPASS_MUTANT
inputByteLimitExceeded observed = limitExceeded (compilerElaboratedPlanMaximumInputBytes + 1) observed
#else
inputByteLimitExceeded observed = limitExceeded compilerElaboratedPlanMaximumInputBytes observed
#endif

jsonTokenLimitExceeded :: Int -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_JSON_TOKEN_LIMIT_BYPASS_MUTANT
jsonTokenLimitExceeded observed = limitExceeded (compilerElaboratedPlanMaximumJsonTokens + 1) observed
#else
jsonTokenLimitExceeded observed = limitExceeded compilerElaboratedPlanMaximumJsonTokens observed
#endif

duplicateProblemLimitExceeded :: Int -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_PROBLEM_LIMIT_BYPASS_MUTANT
duplicateProblemLimitExceeded observed = limitExceeded (compilerElaboratedPlanMaximumProblems + 1) observed
#else
duplicateProblemLimitExceeded observed = limitExceeded compilerElaboratedPlanMaximumProblems observed
#endif

jsonDepthLimitExceeded :: Int -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_JSON_DEPTH_LIMIT_BYPASS_MUTANT
jsonDepthLimitExceeded observed = limitExceeded (compilerElaboratedPlanMaximumJsonDepth + 1) observed
#else
jsonDepthLimitExceeded observed = limitExceeded compilerElaboratedPlanMaximumJsonDepth observed
#endif

jsonStringLimitExceeded :: Int -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_JSON_STRING_LIMIT_BYPASS_MUTANT
jsonStringLimitExceeded observed = limitExceeded (compilerElaboratedPlanMaximumTextLength + 1) observed
#else
jsonStringLimitExceeded observed = limitExceeded compilerElaboratedPlanMaximumTextLength observed
#endif

jsonKeyLimitExceeded :: Int -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_JSON_KEY_LIMIT_BYPASS_MUTANT
jsonKeyLimitExceeded observed = limitExceeded (compilerElaboratedPlanMaximumTextLength + 1) observed
#else
jsonKeyLimitExceeded observed = limitExceeded compilerElaboratedPlanMaximumTextLength observed
#endif

jsonArrayLimitExceeded :: Int -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_JSON_ARRAY_LIMIT_BYPASS_MUTANT
jsonArrayLimitExceeded observed = limitExceeded (compilerElaboratedPlanMaximumArrayEntries + 1) observed
#else
jsonArrayLimitExceeded observed = limitExceeded compilerElaboratedPlanMaximumArrayEntries observed
#endif

jsonObjectLimitExceeded :: Int -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_JSON_OBJECT_LIMIT_BYPASS_MUTANT
jsonObjectLimitExceeded observed = limitExceeded (compilerElaboratedPlanMaximumObjectMembers + 1) observed
#else
jsonObjectLimitExceeded observed = limitExceeded compilerElaboratedPlanMaximumObjectMembers observed
#endif

unitLimitExceeded :: Int -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_LIMIT_BYPASS_MUTANT
unitLimitExceeded observed = limitExceeded (compilerElaboratedPlanMaximumUnits + 1) observed
#else
unitLimitExceeded observed = limitExceeded compilerElaboratedPlanMaximumUnits observed
#endif

componentLimitExceeded :: Int -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_LIMIT_BYPASS_MUTANT
componentLimitExceeded observed = limitExceeded (compilerElaboratedPlanMaximumComponents + 1) observed
#else
componentLimitExceeded observed = limitExceeded compilerElaboratedPlanMaximumComponents observed
#endif

dependencyLimitExceeded :: Int -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_LIMIT_BYPASS_MUTANT
dependencyLimitExceeded observed = limitExceeded (compilerElaboratedPlanMaximumDependencies + 1) observed
#else
dependencyLimitExceeded observed = limitExceeded compilerElaboratedPlanMaximumDependencies observed
#endif

flagLimitExceeded :: Int -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_FLAG_LIMIT_BYPASS_MUTANT
flagLimitExceeded observed = limitExceeded (compilerElaboratedPlanMaximumFlags + 1) observed
#else
flagLimitExceeded observed = limitExceeded compilerElaboratedPlanMaximumFlags observed
#endif

sourceMemberLimitExceeded :: Int -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_MEMBER_LIMIT_BYPASS_MUTANT
sourceMemberLimitExceeded observed = limitExceeded (compilerElaboratedPlanMaximumSourceMembers + 1) observed
#else
sourceMemberLimitExceeded observed = limitExceeded compilerElaboratedPlanMaximumSourceMembers observed
#endif

semanticProblemLimit :: Int
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_SEMANTIC_PROBLEM_LIMIT_BYPASS_MUTANT
semanticProblemLimit = compilerElaboratedPlanMaximumSemanticProblems + 1
#else
semanticProblemLimit = compilerElaboratedPlanMaximumSemanticProblems
#endif

semanticByteLimitExceeded :: Int -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_SEMANTIC_BYTE_LIMIT_BYPASS_MUTANT
semanticByteLimitExceeded observed = limitExceeded (compilerElaboratedPlanMaximumSemanticBytes + 1) observed
#else
semanticByteLimitExceeded observed = limitExceeded compilerElaboratedPlanMaximumSemanticBytes observed
#endif

sourceByteLimitExceeded :: Int -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_BYTE_LIMIT_BYPASS_MUTANT
sourceByteLimitExceeded observed = limitExceeded (compilerElaboratedPlanMaximumSourceBytes + 1) observed
#else
sourceByteLimitExceeded observed = limitExceeded compilerElaboratedPlanMaximumSourceBytes observed
#endif

pathByteLimitExceeded :: Int -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_PATH_BYTE_LIMIT_BYPASS_MUTANT
pathByteLimitExceeded observed = limitExceeded (compilerElaboratedPlanMaximumPathBytes + 1) observed
#else
pathByteLimitExceeded observed = limitExceeded compilerElaboratedPlanMaximumPathBytes observed
#endif

pathSegmentLimitExceeded :: Int -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_PATH_SEGMENT_LIMIT_BYPASS_MUTANT
pathSegmentLimitExceeded observed = limitExceeded (compilerElaboratedPlanMaximumPathSegments + 1) observed
#else
pathSegmentLimitExceeded observed = limitExceeded compilerElaboratedPlanMaximumPathSegments observed
#endif

pathSegmentByteLimitExceeded :: Int -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_PATH_SEGMENT_BYTE_LIMIT_BYPASS_MUTANT
pathSegmentByteLimitExceeded observed = limitExceeded (compilerElaboratedPlanMaximumPathSegmentBytes + 1) observed
#else
pathSegmentByteLimitExceeded observed = limitExceeded compilerElaboratedPlanMaximumPathSegmentBytes observed
#endif

appendJsonField :: JsonPath -> Text -> JsonPath
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_JSON_FIELD_PATH_APPEND_DROP_MUTANT)
appendJsonField path name = name `seq` path
#else
appendJsonField (JsonPath segments) name =
  JsonPath (segments <> [JsonObjectField name])
#endif

appendJsonIndex :: JsonPath -> Int -> JsonPath
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_JSON_INDEX_PATH_APPEND_DROP_MUTANT)
appendJsonIndex path index = index `seq` path
#else
appendJsonIndex (JsonPath segments) index =
  JsonPath (segments <> [JsonArrayIndex index])
#endif

renderJsonPath :: JsonPath -> Text
renderJsonPath (JsonPath segments) = "plan" <> foldMap renderSegment segments
 where
  renderSegment segment = case segment of
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_JSON_FIELD_PATH_RENDER_MUTANT)
    JsonObjectField name -> name `seq` "[\"mutated\"]"
#else
    JsonObjectField name -> "[" <> Text.pack (show (Text.unpack name)) <> "]"
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_JSON_INDEX_PATH_RENDER_MUTANT)
    JsonArrayIndex index -> index `seq` "[999]"
#else
    JsonArrayIndex index -> "[" <> Text.pack (show index) <> "]"
#endif

jsonFieldScope :: Text -> Text -> Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_JSON_FIELD_SCOPE_MAPPING_MUTANT)
jsonFieldScope scope name = scope `seq` name `seq` "plan[\"mutated\"]"
#else
jsonFieldScope scope name =
  scope <> "[" <> Text.pack (show (Text.unpack name)) <> "]"
#endif

parseRoot
  :: Object
  -> Either [CompilerElaboratedPlanProblem] DiagnosticCompilerElaboratedPlanSnapshot
parseRoot root =
  case
      ( parsedValue cabalVersion
      , parsedValue cabalLibraryVersion
      , parsedValue compilerId
      , parsedValue compilerAbi
      , parsedValue operatingSystem
      , parsedValue architecture
      , parsedValue installPlan
      )
    of
      ( Just observedCabalVersion
        , Just observedCabalLibraryVersion
        , Just observedCompilerId
        , Just observedCompilerAbi
        , Just observedOperatingSystem
        , Just observedArchitecture
        , Just encodedUnits
        )
          | null rootProblems ->
              case diagnosticSubjectResourceProblems encodedUnits of
                [] ->
                  parseUnits
                    observedCabalVersion
                    observedCabalLibraryVersion
                    observedCompilerId
                    observedCompilerAbi
                    observedOperatingSystem
                    observedArchitecture
                    encodedUnits
                resourceProblems -> Left resourceProblems
          | otherwise -> Left rootProblems
      _ -> Left rootProblems
 where
  scope = "plan"
  allowedFields =
    Set.fromList
      [ "cabal-version"
      , "cabal-lib-version"
      , "compiler-id"
      , "compiler-abi"
      , "os"
      , "arch"
      , "install-plan"
      ]
  cabalVersion = requiredSemanticText scope root "cabal-version"
  cabalLibraryVersion = requiredSemanticText scope root "cabal-lib-version"
  compilerId = requiredConstrainedText scope root "compiler-id" compilerIdText
  compilerAbi = requiredConstrainedText scope root "compiler-abi" portableIdentityText
  operatingSystem = requiredConstrainedText scope root "os" platformTokenText
  architecture = requiredConstrainedText scope root "arch" platformTokenText
  installPlan = requiredUnitArray scope root "install-plan"
  versionProblems =
    [ UnsupportedPlanSchemaVersion field expected actual
    | (field, expected, observed) <-
        [ ("cabal-version", fst compilerElaboratedPlanSchemaVersion, parsedValue cabalVersion)
        , ("cabal-lib-version", snd compilerElaboratedPlanSchemaVersion, parsedValue cabalLibraryVersion)
        ]
    , Just actual <- [observed]
    , not (schemaVersionAccepted field expected actual)
    ]
  rootProblems =
    unknownFields scope allowedFields root
      <> concatMap
        parsedProblems
        [ cabalVersion
        , cabalLibraryVersion
        , compilerId
        , compilerAbi
        , operatingSystem
        , architecture
        ]
      <> parsedProblems installPlan
      <> versionProblems

-- These aggregate counts are taken from the already token-bounded JSON tree
-- before any unit/component sorting, dependency graph construction, snapshot
-- projection, observation rendering, or finding rendering.  Together with
-- the scalar byte ceilings and the 256-unit ceiling they are the finite
-- pre-render envelope for every list embedded in the public diagnostic wire.
diagnosticSubjectResourceProblems :: [Value] -> [CompilerElaboratedPlanProblem]
diagnosticSubjectResourceProblems encodedUnits =
  [ PlanResourceLimitExceeded
      "components"
      compilerElaboratedPlanMaximumComponents
      componentCount
  | componentLimitExceeded componentCount
  ]
    <> [ PlanResourceLimitExceeded
          "dependencies"
          compilerElaboratedPlanMaximumDependencies
          dependencyCount
       | dependencyLimitExceeded dependencyCount
       ]
    <> [ PlanResourceLimitExceeded
          "flags"
          compilerElaboratedPlanMaximumFlags
          flagCount
       | flagLimitExceeded flagCount
       ]
 where
  componentCount = sum (map encodedUnitComponentCount encodedUnits)
  dependencyCount = sum (map encodedUnitDependencyCount encodedUnits)
  flagCount = sum (map encodedUnitFlagCount encodedUnits)

encodedUnitComponentCount :: Value -> Int
encodedUnitComponentCount (Object object) =
  directComponentCount + aggregateComponentCount
 where
  directComponentCount = encodedDirectComponentCount object
  aggregateComponentCount = encodedComponentMapCount object
encodedUnitComponentCount _ = 0

encodedDirectComponentCount :: Object -> Int
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_DIRECT_COMPONENT_COUNT_DROP_MUTANT
encodedDirectComponentCount _ = 0
#else
encodedDirectComponentCount object = case KeyMap.lookup "component-name" object of
  Nothing -> 0
  Just _ -> 1
#endif

encodedComponentMapCount :: Object -> Int
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_MAP_COUNT_DROP_MUTANT
encodedComponentMapCount _ = 0
#else
encodedComponentMapCount object = case KeyMap.lookup "components" object of
  Just (Object components) -> KeyMap.size components
  _ -> 0
#endif

encodedUnitDependencyCount :: Value -> Int
encodedUnitDependencyCount (Object object) =
  encodedRootDependsCount object
    + encodedRootExecutableDependsCount object
    + case KeyMap.lookup "components" object of
      Just (Object components) ->
        sum
          [ encodedNestedDependsCount component
              + encodedNestedExecutableDependsCount component
          | Object component <- KeyMap.elems components
          ]
      _ -> 0
encodedUnitDependencyCount _ = 0

encodedRootDependsCount :: Object -> Int
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_ROOT_DEPENDS_COUNT_DROP_MUTANT
encodedRootDependsCount _ = 0
#else
encodedRootDependsCount = encodedArrayFieldCount "depends"
#endif

encodedRootExecutableDependsCount :: Object -> Int
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_ROOT_EXECUTABLE_DEPENDS_COUNT_DROP_MUTANT
encodedRootExecutableDependsCount _ = 0
#else
encodedRootExecutableDependsCount = encodedArrayFieldCount "exe-depends"
#endif

encodedNestedDependsCount :: Object -> Int
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_NESTED_DEPENDS_COUNT_DROP_MUTANT
encodedNestedDependsCount _ = 0
#else
encodedNestedDependsCount = encodedArrayFieldCount "depends"
#endif

encodedNestedExecutableDependsCount :: Object -> Int
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_NESTED_EXECUTABLE_DEPENDS_COUNT_DROP_MUTANT
encodedNestedExecutableDependsCount _ = 0
#else
encodedNestedExecutableDependsCount = encodedArrayFieldCount "exe-depends"
#endif

encodedArrayFieldCount :: Key.Key -> Object -> Int
encodedArrayFieldCount name object = case KeyMap.lookup name object of
  Just (Array values) -> Foldable.length values
  _ -> 0

encodedUnitFlagCount :: Value -> Int
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_FLAG_COUNT_DROP_MUTANT
encodedUnitFlagCount _ = 0
#else
encodedUnitFlagCount (Object object) = case KeyMap.lookup "flags" object of
  Just (Object flags) -> KeyMap.size flags
  _ -> 0
encodedUnitFlagCount _ = 0
#endif

parseUnits
  :: Text
  -> Text
  -> Text
  -> Text
  -> Text
  -> Text
  -> [Value]
  -> Either [CompilerElaboratedPlanProblem] DiagnosticCompilerElaboratedPlanSnapshot
parseUnits cabalVersion cabalLibraryVersion compilerId compilerAbi operatingSystem architecture encodedUnits =
  case partitionParsed parsedUnits of
    (unitProblems, _)
      | not (null unitProblems) -> Left (boundedProblemList unitProblems)
    (_, decodedUnits) ->
      let units = projectUnitOrder (sortOn diagnosticElaboratedUnitId (map parsedUnitValue decodedUnits))
          invariantProblems = planInvariantProblems decodedUnits units
       in if null invariantProblems
            then
              Right
                ( DiagnosticCompilerElaboratedPlanSnapshot
                    cabalVersion
                    cabalLibraryVersion
                    compilerId
                    compilerAbi
                    operatingSystem
                    architecture
                    units
                )
            else Left invariantProblems
 where
  parsedUnits = zipWith parseInstallUnit [0 ..] encodedUnits

projectUnitOrder :: [DiagnosticElaboratedUnit] -> [DiagnosticElaboratedUnit]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_ORDER_MUTANT)
projectUnitOrder = reverse
#else
projectUnitOrder = id
#endif

parseInstallUnit :: Int -> Value -> Parsed ParsedUnit
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_INSTALL_UNIT_OBJECT_ROUTE_DROP_MUTANT)
parseInstallUnit index (Object object) =
  parsedObject `seq` Parsed [PlanJsonFieldTypeMismatch (unitScope index) "<entry>" "mutated-object"] Nothing
 where
  parsedObject =
    case parsedValue unitType of
      Just "pre-existing" -> parsePreExistingUnit index object
      Just "configured" -> parseConfiguredUnit index object
      Just "foreign"
        | unsupportedInstallUnitTypeAccepted -> parsePreExistingUnit index object
      Just observed -> Parsed (baseProblems <> [UnsupportedInstallUnitType index observed]) Nothing
      Nothing -> Parsed baseProblems Nothing
  scope = unitScope index
  unitType = requiredSemanticText scope object "type"
  baseProblems = parsedProblems unitType
#else
parseInstallUnit index (Object object) =
  case parsedValue unitType of
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_INSTALL_UNIT_PRE_EXISTING_ROUTE_DROP_MUTANT)
    Just "pre-existing" ->
      parsePreExistingUnit index object `seq`
        Parsed [UnsupportedInstallUnitType index "pre-existing"] Nothing
#else
    Just "pre-existing" -> parsePreExistingUnit index object
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_INSTALL_UNIT_CONFIGURED_ROUTE_DROP_MUTANT)
    Just "configured" ->
      parseConfiguredUnit index object `seq`
        Parsed [UnsupportedInstallUnitType index "configured"] Nothing
#else
    Just "configured" -> parseConfiguredUnit index object
#endif
    Just "foreign"
      | unsupportedInstallUnitTypeAccepted -> parsePreExistingUnit index object
    Just observed -> Parsed (baseProblems <> [UnsupportedInstallUnitType index observed]) Nothing
    Nothing -> Parsed baseProblems Nothing
 where
  scope = unitScope index
  unitType = requiredSemanticText scope object "type"
  baseProblems = parsedProblems unitType
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_INSTALL_UNIT_NON_OBJECT_MAPPING_MUTANT)
parseInstallUnit index value =
  value `seq` Parsed [PlanJsonFieldTypeMismatch (unitScope index) "<entry>" "mutated-non-object"] Nothing
#else
parseInstallUnit index _ =
  Parsed
    [PlanJsonFieldTypeMismatch (unitScope index) "<entry>" "object"]
    Nothing
#endif

unsupportedInstallUnitTypeAccepted :: Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_INSTALL_UNIT_TYPE_BYPASS_MUTANT
unsupportedInstallUnitTypeAccepted = True
#else
unsupportedInstallUnitTypeAccepted = False
#endif

schemaVersionAccepted :: Text -> Text -> Text -> Bool
schemaVersionAccepted field expected actual = case field of
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_CABAL_SCHEMA_FIELD_ROUTE_DROP_MUTANT)
  "cabal-version" -> cabalSchemaVersionAccepted expected actual `seq` False
#else
  "cabal-version" -> cabalSchemaVersionAccepted expected actual
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_CABAL_LIBRARY_SCHEMA_FIELD_ROUTE_DROP_MUTANT)
  "cabal-lib-version" -> cabalLibrarySchemaVersionAccepted expected actual `seq` False
#else
  "cabal-lib-version" -> cabalLibrarySchemaVersionAccepted expected actual
#endif
  _ -> False

cabalSchemaVersionAccepted :: Text -> Text -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_CABAL_SCHEMA_VERSION_BYPASS_MUTANT
cabalSchemaVersionAccepted expected actual = actual == expected || actual == "3.16.1.1"
#else
cabalSchemaVersionAccepted = (==)
#endif

cabalLibrarySchemaVersionAccepted :: Text -> Text -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_CABAL_LIBRARY_SCHEMA_VERSION_BYPASS_MUTANT
cabalLibrarySchemaVersionAccepted expected actual = actual == expected || actual == "3.16.1.1"
#else
cabalLibrarySchemaVersionAccepted = (==)
#endif

parsePreExistingUnit :: Int -> Object -> Parsed ParsedUnit
parsePreExistingUnit index object =
  case
      ( parsedValue unitIdField
      , parsedValue packageName
      , parsedValue packageVersion
      , parsedValue dependencies
      )
    of
      (Just unitId, Just name, Just version, Just dependencyIds)
        | null problems ->
            Parsed
              []
              ( Just
                  ( ParsedUnit
                      ( DiagnosticElaboratedUnit
                          PreExistingUnit
                          PreExistingBuildStyle
                          unitId
                          name
                          version
                          PreExistingPackageSource
                          []
                          []
                          Nothing
                          dependencyIds
                          Nothing
                          Nothing
                          Nothing
                          Nothing
                          Nothing
                      )
                      []
                  )
              )
      _ -> Parsed problems Nothing
 where
  scope = unitScope index
  allowed = Set.fromList ["type", "id", "pkg-name", "pkg-version", "depends"]
  unitIdField = requiredConstrainedText scope object "id" portableIdentityText
  packageName = requiredConstrainedText scope object "pkg-name" packageNameText
  packageVersion = requiredConstrainedText scope object "pkg-version" packageVersionText
  dependencies = requiredConstrainedTextArray scope object "depends" portableIdentityText
  problems =
    unknownFields scope allowed object
      <> concatMap parsedProblems [unitIdField, packageName, packageVersion]
      <> parsedProblems dependencies

parseConfiguredUnit :: Int -> Object -> Parsed ParsedUnit
parseConfiguredUnit index object =
  case
      ( parsedValue unitIdField
      , parsedValue packageName
      , parsedValue packageVersion
      , parsedValue flags
      , parsedValue style
      , parsedValue packageSource
      )
    of
      (Just unitId, Just name, Just version, Just selectedFlags, Just observedStyle, Just source) ->
        let originResult = configuredOrigin unitId observedStyle source
            componentResult = configuredComponents index unitId object
            componentShapeProblems = case parsedValue componentResult of
              Just (_, _, shape) -> configuredShapeFieldProblems scope object shape
              Nothing -> []
            fieldCombinationProblems = case parsedValue componentResult of
              Just (_, _, shape) ->
                configuredFieldCombinationProblems
                  scope
                  unitId
                  object
                  observedStyle
                  source
                  shape
                  (parsedValue packageCabalSha256)
                  (parsedValue packageSourceSha256)
              Nothing -> []
            allProblems =
              problems
                <> parsedProblems originResult
                <> parsedProblems componentResult
                <> componentShapeProblems
                <> fieldCombinationProblems
         in case (parsedValue originResult, parsedValue componentResult) of
              (Just (origin, buildStyle), Just (components, declaredNames, componentShape))
                | null allProblems ->
                    Parsed
                      []
                      ( Just
                          ( ParsedUnit
                              ( DiagnosticElaboratedUnit
                                  origin
                                  buildStyle
                                  unitId
                                  name
                                  version
                                  source
                                  selectedFlags
                                  components
                                  (Just (diagnosticComponentShape componentShape))
                                  []
                                  (parsedValue packageCabalSha256)
                                  (parsedValue packageSourceSha256)
                                  (parsedValue buildInfoPath)
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_ACCEPTED_FIELD_BINDING_MUTANT
                                  Nothing
#else
                                  (parsedValue distDir)
#endif
                                  (parsedValue binFile)
                              )
                              declaredNames
                          )
                      )
              _ -> Parsed allProblems Nothing
      _ -> Parsed problems Nothing
 where
  scope = unitScope index
  allowed =
    Set.fromList
      [ "type"
      , "id"
      , "pkg-name"
      , "pkg-version"
      , "flags"
      , "style"
      , "pkg-src"
      , "component-name"
      , "depends"
      , "exe-depends"
      , "components"
      , "pkg-cabal-sha256"
      , "pkg-src-sha256"
      , "build-info"
      , "dist-dir"
      , "bin-file"
      ]
  unitIdField = requiredConstrainedText scope object "id" portableIdentityText
  packageName = requiredConstrainedText scope object "pkg-name" packageNameText
  packageVersion = requiredConstrainedText scope object "pkg-version" packageVersionText
  flags = requiredBooleanMap scope object "flags"
  style = requiredSemanticText scope object "style"
  packageSource = parsePackageSource index object
  packageCabalSha256 = optionalSemanticText scope object "pkg-cabal-sha256"
  packageSourceSha256 = optionalSemanticText scope object "pkg-src-sha256"
  buildInfoPath = optionalSafeFilePath scope object "build-info"
  distDir = optionalSafeFilePath scope object "dist-dir"
  binFile = optionalSafeFilePath scope object "bin-file"
  problems =
    unknownFields scope allowed object
      <> concatMap parsedProblems [unitIdField, packageName, packageVersion, style]
      <> parsedProblems flags
      <> parsedProblems packageSource
      <> concatMap parsedProblems [packageCabalSha256, packageSourceSha256]
      <> concatMap parsedProblems [buildInfoPath, distDir, binFile]

configuredShapeFieldProblems
  :: Text
  -> Object
  -> ConfiguredComponentShape
  -> [CompilerElaboratedPlanProblem]
configuredShapeFieldProblems scope object shape = case shape of
  DirectComponentShape _ -> []
  ComponentMapShape ->
    [ PlanJsonFieldUnexpected scope "depends"
    | aggregateDependsForbidden object
    ]
      <> [ PlanJsonFieldUnexpected scope "exe-depends"
         | aggregateExecutableDependsForbidden object
         ]

aggregateDependsForbidden :: Object -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_AGGREGATE_DEPENDS_GUARD_BYPASS_MUTANT
aggregateDependsForbidden _ = False
#else
aggregateDependsForbidden = KeyMap.member "depends"
#endif

aggregateExecutableDependsForbidden :: Object -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_AGGREGATE_EXECUTABLE_DEPENDS_GUARD_BYPASS_MUTANT
aggregateExecutableDependsForbidden _ = False
#else
aggregateExecutableDependsForbidden = KeyMap.member "exe-depends"
#endif

configuredFieldCombinationProblems
  :: Text
  -> Text
  -> Object
  -> Text
  -> PackageSource
  -> ConfiguredComponentShape
  -> Maybe Text
  -> Maybe Text
  -> [CompilerElaboratedPlanProblem]
configuredFieldCombinationProblems scope unitId object style source shape cabalSha sourceSha =
  buildPathProblems
    <> binaryPathProblems
    <> sourceIdentityProblemsForHashes
      scope
      unitId
      source
      (KeyMap.member "pkg-cabal-sha256" object)
      (KeyMap.member "pkg-src-sha256" object)
      cabalSha
      sourceSha
 where
  buildPathProblems =
    [ PlanJsonFieldMissing scope "build-info"
    | localBuildInfoMissing style object
    ]
      <> [ PlanJsonFieldMissing scope "dist-dir"
         | localDistDirectoryMissing style object
         ]
      <> [ PlanJsonFieldUnexpected scope "build-info"
         | globalBuildInfoForbidden style object
         ]
      <> [ PlanJsonFieldUnexpected scope "dist-dir"
         | globalDistDirectoryForbidden style object
         ]
  binaryPathProblems =
    [ PlanJsonFieldMissing scope "bin-file"
    | binaryPathMissing shape object
    ]
      <> [ PlanJsonFieldUnexpected scope "bin-file"
         | nonBinaryPathForbidden shape object
         ]

localBuildInfoMissing :: Text -> Object -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_BUILD_INFO_PRESENCE_BYPASS_MUTANT
localBuildInfoMissing _ _ = False
#else
localBuildInfoMissing style object =
  style `elem` ["local", "inplace"] && not (KeyMap.member "build-info" object)
#endif

localDistDirectoryMissing :: Text -> Object -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_DIST_DIRECTORY_PRESENCE_BYPASS_MUTANT
localDistDirectoryMissing _ _ = False
#else
localDistDirectoryMissing style object =
  style `elem` ["local", "inplace"] && not (KeyMap.member "dist-dir" object)
#endif

globalBuildInfoForbidden :: Text -> Object -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_GLOBAL_BUILD_INFO_GUARD_BYPASS_MUTANT
globalBuildInfoForbidden _ _ = False
#else
globalBuildInfoForbidden style object =
  style == "global" && KeyMap.member "build-info" object
#endif

globalDistDirectoryForbidden :: Text -> Object -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_GLOBAL_DIST_DIRECTORY_GUARD_BYPASS_MUTANT
globalDistDirectoryForbidden _ _ = False
#else
globalDistDirectoryForbidden style object =
  style == "global" && KeyMap.member "dist-dir" object
#endif

binaryPathMissing :: ConfiguredComponentShape -> Object -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_BINARY_PATH_PRESENCE_BYPASS_MUTANT
binaryPathMissing _ _ = False
#else
binaryPathMissing shape object =
  componentProducesBinary shape && not (KeyMap.member "bin-file" object)
#endif

nonBinaryPathForbidden :: ConfiguredComponentShape -> Object -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_NON_BINARY_PATH_GUARD_BYPASS_MUTANT
nonBinaryPathForbidden _ _ = False
#else
nonBinaryPathForbidden shape object =
  not (componentProducesBinary shape) && KeyMap.member "bin-file" object
#endif

componentProducesBinary :: ConfiguredComponentShape -> Bool
componentProducesBinary shape = case shape of
  DirectComponentShape name ->
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_BINARY_EXECUTABLE_CLASSIFICATION_DROP_MUTANT)
    any (`Text.isPrefixOf` name) ["test:", "bench:"]
#elif defined(VALIDATION_COMPILER_ELABORATED_PLAN_BINARY_TEST_CLASSIFICATION_DROP_MUTANT)
    any (`Text.isPrefixOf` name) ["exe:", "bench:"]
#elif defined(VALIDATION_COMPILER_ELABORATED_PLAN_BINARY_BENCHMARK_CLASSIFICATION_DROP_MUTANT)
    any (`Text.isPrefixOf` name) ["exe:", "test:"]
#elif defined(VALIDATION_COMPILER_ELABORATED_PLAN_BINARY_LIBRARY_CLASSIFICATION_WIDEN_MUTANT)
    any (`Text.isPrefixOf` name) ["lib", "exe:", "test:", "bench:"]
#else
    any (`Text.isPrefixOf` name) ["exe:", "test:", "bench:"]
#endif
  ComponentMapShape -> False

configuredComponents
  :: Int
  -> Text
  -> Object
  -> Parsed ([DiagnosticElaboratedComponent], [Text], ConfiguredComponentShape)
configuredComponents index unitId object =
  case (KeyMap.lookup "component-name" object, KeyMap.lookup "components" object) of
    (Nothing, Nothing) -> missingComponentShape index unitId object
    (Just _, Just _) -> ambiguousComponentShape index unitId object
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_DIRECT_COMPONENT_ROUTE_DROP_MUTANT)
    (Just _, Nothing) ->
      parseDirectComponent index unitId object `seq`
        Parsed [ConfiguredUnitComponentShapeMissing unitId] Nothing
#else
    (Just _, Nothing) -> parseDirectComponent index unitId object
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_MAP_ROUTE_DROP_MUTANT)
    (Nothing, Just (Object components)) ->
      parseComponentMap index unitId components `seq`
        Parsed [ConfiguredUnitComponentShapeMissing unitId] Nothing
#else
    (Nothing, Just (Object components)) -> parseComponentMap index unitId components
#endif
    (Nothing, Just _) ->
      Parsed
        [PlanJsonFieldTypeMismatch (unitScope index) "components" "object"]
        Nothing

missingComponentShape
  :: Int
  -> Text
  -> Object
  -> Parsed ([DiagnosticElaboratedComponent], [Text], ConfiguredComponentShape)
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_SHAPE_PRESENCE_BYPASS_MUTANT
missingComponentShape index unitId object =
  parseDirectComponent index unitId (KeyMap.insert "component-name" (String "lib") object)
#else
missingComponentShape _ unitId _ = Parsed [ConfiguredUnitComponentShapeMissing unitId] Nothing
#endif

ambiguousComponentShape
  :: Int
  -> Text
  -> Object
  -> Parsed ([DiagnosticElaboratedComponent], [Text], ConfiguredComponentShape)
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_SHAPE_AMBIGUITY_BYPASS_MUTANT
ambiguousComponentShape index unitId object =
  parseDirectComponent index unitId (KeyMap.delete "components" object)
#else
ambiguousComponentShape _ unitId _ = Parsed [ConfiguredUnitComponentShapeAmbiguous unitId] Nothing
#endif

parseDirectComponent
  :: Int
  -> Text
  -> Object
  -> Parsed ([DiagnosticElaboratedComponent], [Text], ConfiguredComponentShape)
parseDirectComponent index unitId object =
  case
      ( parsedValue componentName
      , parsedValue dependencies
      , parsedValue executableDependencies
      )
    of
      (Just name, Just dependencyIds, Just executableDependencyIds)
        | null problems ->
            Parsed
              []
              ( Just
                  ( [DiagnosticElaboratedComponent unitId name dependencyIds executableDependencyIds Nothing]
                  , [name]
                  , DirectComponentShape name
                  )
              )
      _ -> Parsed problems Nothing
 where
  scope = unitScope index
  componentName = requiredText scope object "component-name"
  dependencies = requiredConstrainedTextArray scope object "depends" portableIdentityText
  executableDependencies = requiredConstrainedTextArray scope object "exe-depends" portableIdentityText
  problems =
    concatMap parsedProblems [componentName]
      <> concatMap parsedProblems [dependencies, executableDependencies]
      <> [ ConfiguredComponentNameMalformed unitId name
         | Just name <- [parsedValue componentName]
         , not (componentNameText name)
         ]

parseComponentMap
  :: Int
  -> Text
  -> Object
  -> Parsed ([DiagnosticElaboratedComponent], [Text], ConfiguredComponentShape)
parseComponentMap index unitId componentMap =
  if emptyComponentMapRejected componentMap
    then Parsed [ConfiguredUnitComponentDiscoveryEmpty unitId] Nothing
    else case partitionParsed parsedComponents of
      (problems, _)
        | not (null problems) -> Parsed problems Nothing
      (_, components) ->
        let ordered = projectComponentOrder (sortOn diagnosticElaboratedComponentName components)
            declaredNames = projectDeclaredComponentNameOrder (sort (map Key.toText (KeyMap.keys componentMap)))
         in Parsed [] (Just (ordered, declaredNames, ComponentMapShape))
 where
  parsedComponents =
    [ parseNestedComponent index unitId (Key.toText name) value
    | (name, value) <- sortOn (Key.toText . fst) (KeyMap.toList componentMap)
    ]

emptyComponentMapRejected :: Object -> Bool
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_EMPTY_COMPONENT_MAP_GUARD_BYPASS_MUTANT)
emptyComponentMapRejected componentMap = KeyMap.null componentMap `seq` False
#else
emptyComponentMapRejected = KeyMap.null
#endif

projectComponentOrder :: [DiagnosticElaboratedComponent] -> [DiagnosticElaboratedComponent]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_ORDER_MUTANT)
projectComponentOrder = reverse
#else
projectComponentOrder = id
#endif

projectDeclaredComponentNameOrder :: [Text] -> [Text]
projectDeclaredComponentNameOrder = id

parseNestedComponent :: Int -> Text -> Text -> Value -> Parsed DiagnosticElaboratedComponent
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_NESTED_COMPONENT_OBJECT_ROUTE_DROP_MUTANT)
parseNestedComponent index unitId name (Object object) =
  unitId `seq` object `seq`
    Parsed [PlanJsonFieldTypeMismatch (jsonFieldScope (unitScope index) "components") name "mutated-object"] Nothing
#else
parseNestedComponent index unitId name (Object object) =
  case (parsedValue dependencies, parsedValue executableDependencies) of
    (Just dependencyIds, Just executableDependencyIds)
      | null problems ->
          Parsed
            []
            (Just (DiagnosticElaboratedComponent unitId name dependencyIds executableDependencyIds Nothing))
    _ -> Parsed problems Nothing
 where
  scope = jsonFieldScope (jsonFieldScope (unitScope index) "components") name
  allowed = Set.fromList ["depends", "exe-depends"]
  dependencies = requiredConstrainedTextArray scope object "depends" portableIdentityText
  executableDependencies = requiredConstrainedTextArray scope object "exe-depends" portableIdentityText
  problems =
    unknownFields scope allowed object
      <> concatMap parsedProblems [dependencies, executableDependencies]
      <> [ConfiguredComponentNameMalformed unitId name | not (componentNameText name)]
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_NESTED_COMPONENT_NON_OBJECT_MAPPING_MUTANT)
parseNestedComponent index unitId name value =
  unitId `seq` value `seq`
    Parsed [PlanJsonFieldTypeMismatch (jsonFieldScope (unitScope index) "components") name "mutated-non-object"] Nothing
#else
parseNestedComponent index _ name _ =
  Parsed
    [ PlanJsonFieldTypeMismatch
        (jsonFieldScope (unitScope index) "components")
        name
        "object"
    ]
    Nothing
#endif

parsePackageSource :: Int -> Object -> Parsed PackageSource
parsePackageSource index unitObject =
  case parsedValue sourceObject of
    Nothing -> Parsed (parsedProblems sourceObject) Nothing
    Just object
      | sourceMemberLimitExceeded (KeyMap.size object) ->
          Parsed
            [ PlanResourceLimitExceeded
                "source-object-members"
                compilerElaboratedPlanMaximumSourceMembers
                (KeyMap.size object)
            ]
            Nothing
      | otherwise ->
          case parsedValue sourceType of
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_PACKAGE_SOURCE_ROUTE_DROP_MUTANT)
            Just "local" ->
              parseLocalSource scope object `seq`
                Parsed [UnsupportedPackageSourceType label "local"] Nothing
#else
            Just "local" -> parseLocalSource scope object
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TAR_PACKAGE_SOURCE_ROUTE_DROP_MUTANT)
            Just "repo-tar" ->
              parseRepositoryTarSource scope object `seq`
                Parsed [UnsupportedPackageSourceType label "repo-tar"] Nothing
#else
            Just "repo-tar" -> parseRepositoryTarSource scope object
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_REPOSITORY_PACKAGE_SOURCE_ROUTE_DROP_MUTANT)
            Just "source-repo" ->
              parseSourceRepositorySource scope object `seq`
                Parsed [UnsupportedPackageSourceType label "source-repo"] Nothing
#else
            Just "source-repo" -> parseSourceRepositorySource scope object
#endif
            Just "foreign"
              | unsupportedPackageSourceTypeAccepted -> parseLocalSource scope object
            Just observed ->
              Parsed
                ( parsedProblems sourceObject
                    <> parsedProblems sourceType
                    <> [UnsupportedPackageSourceType label observed]
                )
                Nothing
            Nothing -> Parsed (parsedProblems sourceObject <> parsedProblems sourceType) Nothing
     where
      scope = jsonFieldScope (unitScope index) "pkg-src"
      label = observedTextOr (unitScope index) (optionalText (unitScope index) unitObject "id")
      sourceType = requiredSemanticText scope object "type"
 where
  sourceObject = requiredObject (unitScope index) unitObject "pkg-src"

parseLocalSource :: Text -> Object -> Parsed PackageSource
parseLocalSource scope object =
  case parsedValue path of
    Just value
      | null problems -> Parsed [] (Just (LocalPackageSource value))
    _ -> Parsed problems Nothing
 where
  path = requiredSafeFilePath scope object "path"
  problems =
    unknownFields scope (Set.fromList ["type", "path"]) object
      <> parsedProblems path

parseRepositoryTarSource :: Text -> Object -> Parsed PackageSource
parseRepositoryTarSource scope object =
  case parsedValue repository of
    Just repositoryObject
      | sourceMemberLimitExceeded (KeyMap.size repositoryObject) ->
          Parsed
            [ PlanResourceLimitExceeded
                "source-object-members"
                compilerElaboratedPlanMaximumSourceMembers
                (KeyMap.size repositoryObject)
            ]
            Nothing
      | otherwise ->
          case (parsedValue repositoryType, parsedValue repositoryUri) of
            (Just observedType, Just uri)
              | secureRepositoryTypeAccepted observedType && null problems ->
                  Parsed [] (Just (RepositoryTarPackageSource observedType uri))
            _ -> Parsed problems Nothing
     where
      repositoryScope = jsonFieldScope scope "repo"
      repositoryType = requiredSemanticText repositoryScope repositoryObject "type"
      repositoryUri = requiredConstrainedText repositoryScope repositoryObject "uri" secureLocatorText
      problems =
        unknownFields scope (Set.fromList ["type", "repo"]) object
          <> unknownFields repositoryScope (Set.fromList ["type", "uri"]) repositoryObject
          <> parsedProblems repository
          <> concatMap parsedProblems [repositoryType, repositoryUri]
          <> [ UnsupportedRepositoryType repositoryScope observedType
             | Just observedType <- [parsedValue repositoryType]
             , not (secureRepositoryTypeAccepted observedType)
             ]
    Nothing -> Parsed (outerProblems <> parsedProblems repository) Nothing
 where
  repository = requiredObject scope object "repo"
  outerProblems = unknownFields scope (Set.fromList ["type", "repo"]) object

parseSourceRepositorySource :: Text -> Object -> Parsed PackageSource
parseSourceRepositorySource scope object =
  case parsedValue repository of
    Just repositoryObject
      | sourceMemberLimitExceeded (KeyMap.size repositoryObject) ->
          Parsed
            [ PlanResourceLimitExceeded
                "source-object-members"
                compilerElaboratedPlanMaximumSourceMembers
                (KeyMap.size repositoryObject)
            ]
            Nothing
      | otherwise ->
          case (parsedValue repositoryType, parsedValue location, parsedValue tag) of
            (Just observedType, Just observedLocation, Just observedTag)
              | sourceRepositoryTypeAccepted observedType && null problems ->
                  Parsed
                    []
                    (Just (SourceRepositoryPackageSource observedType observedLocation observedTag))
            _ -> Parsed problems Nothing
     where
      repositoryScope = jsonFieldScope scope "source-repo"
      repositoryType = requiredSemanticText repositoryScope repositoryObject "type"
      location = requiredConstrainedText repositoryScope repositoryObject "location" secureLocatorText
      tag = requiredSemanticText repositoryScope repositoryObject "tag"
      problems =
        unknownFields scope (Set.fromList ["type", "source-repo"]) object
          <> unknownFields repositoryScope (Set.fromList ["type", "location", "tag"]) repositoryObject
          <> parsedProblems repository
          <> concatMap parsedProblems [repositoryType, location, tag]
          <> [ UnsupportedSourceRepositoryType repositoryScope observedType
             | Just observedType <- [parsedValue repositoryType]
             , not (sourceRepositoryTypeAccepted observedType)
             ]
    Nothing -> Parsed (outerProblems <> parsedProblems repository) Nothing
 where
  repository = requiredObject scope object "source-repo"
  outerProblems = unknownFields scope (Set.fromList ["type", "source-repo"]) object

unsupportedPackageSourceTypeAccepted :: Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_SOURCE_TYPE_BYPASS_MUTANT
unsupportedPackageSourceTypeAccepted = True
#else
unsupportedPackageSourceTypeAccepted = False
#endif

secureRepositoryTypeAccepted :: Text -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TYPE_BYPASS_MUTANT
secureRepositoryTypeAccepted value = value `elem` ["secure-repo", "forged-repo"]
#else
secureRepositoryTypeAccepted value = value == "secure-repo"
#endif

sourceRepositoryTypeAccepted :: Text -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_REPOSITORY_TYPE_BYPASS_MUTANT
sourceRepositoryTypeAccepted value = value `elem` ["git", "hg"]
#else
sourceRepositoryTypeAccepted value = value == "git"
#endif

configuredOrigin
  :: Text
  -> Text
  -> PackageSource
  -> Parsed (DiagnosticElaboratedUnitOrigin, DiagnosticElaboratedUnitBuildStyle)
configuredOrigin unitId style source = case (style, source) of
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_LOCAL_STYLE_ROUTE_DROP_MUTANT)
  ("local", LocalPackageSource _) -> Parsed [UnsupportedConfiguredUnitStyle unitId "local"] Nothing
#else
  ("local", LocalPackageSource _) -> Parsed [] (Just (LocalUnit, LocalBuildStyle))
#endif
  (observed, LocalPackageSource _)
    | observed `elem` ["global", "inplace"] && localOriginMismatchAccepted ->
        Parsed
          []
          ( Just
              ( LocalUnit
              , if observed == "global" then GlobalBuildStyle else InplaceBuildStyle
              )
          )
    | observed `elem` ["global", "inplace"] ->
        Parsed [ConfiguredUnitOriginMismatch unitId observed "local"] Nothing
  (observed, RepositoryTarPackageSource _ _)
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TAR_GLOBAL_STYLE_ROUTE_DROP_MUTANT)
    | observed == "global" -> Parsed [UnsupportedConfiguredUnitStyle unitId observed] Nothing
#else
    | observed == "global" -> Parsed [] (Just (RemoteUnit, GlobalBuildStyle))
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TAR_INPLACE_STYLE_ROUTE_DROP_MUTANT)
    | observed == "inplace" -> Parsed [UnsupportedConfiguredUnitStyle unitId observed] Nothing
#else
    | observed == "inplace" -> Parsed [] (Just (RemoteUnit, InplaceBuildStyle))
#endif
  (observed, SourceRepositoryPackageSource _ _ _)
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_REPOSITORY_GLOBAL_STYLE_ROUTE_DROP_MUTANT)
    | observed == "global" -> Parsed [UnsupportedConfiguredUnitStyle unitId observed] Nothing
#else
    | observed == "global" -> Parsed [] (Just (RemoteUnit, GlobalBuildStyle))
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_REPOSITORY_INPLACE_STYLE_ROUTE_DROP_MUTANT)
    | observed == "inplace" -> Parsed [UnsupportedConfiguredUnitStyle unitId observed] Nothing
#else
    | observed == "inplace" -> Parsed [] (Just (RemoteUnit, InplaceBuildStyle))
#endif
  (observed, remoteSource)
    | observed == "local" && remoteOriginMismatchAccepted ->
        Parsed [] (Just (RemoteUnit, LocalBuildStyle))
    | observed == "local" ->
        Parsed
          [ConfiguredUnitOriginMismatch unitId observed (packageSourceKind remoteSource)]
          Nothing
  ("foreign", _) | unsupportedConfiguredStyleAccepted ->
    Parsed [] (Just (RemoteUnit, GlobalBuildStyle))
  (observed, _) -> Parsed [UnsupportedConfiguredUnitStyle unitId observed] Nothing

localOriginMismatchAccepted :: Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_ORIGIN_MISMATCH_BYPASS_MUTANT
localOriginMismatchAccepted = True
#else
localOriginMismatchAccepted = False
#endif

remoteOriginMismatchAccepted :: Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_REMOTE_ORIGIN_MISMATCH_BYPASS_MUTANT
remoteOriginMismatchAccepted = True
#else
remoteOriginMismatchAccepted = False
#endif

unsupportedConfiguredStyleAccepted :: Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_CONFIGURED_STYLE_BYPASS_MUTANT
unsupportedConfiguredStyleAccepted = True
#else
unsupportedConfiguredStyleAccepted = False
#endif

planInvariantProblems :: [ParsedUnit] -> [DiagnosticElaboratedUnit] -> [CompilerElaboratedPlanProblem]
planInvariantProblems parsedUnits units =
  projectDuplicateUnitProblemContribution duplicateUnitProblems
    <> projectDuplicateLocalComponentProblemContribution duplicateLocalComponentProblems
    <> projectDependencyProblemContribution dependencyProblems
    <> projectDependencyCycleProblemContribution dependencyCycleProblems
    <> projectLocalDiscoveryProblemContribution localDiscoveryProblems
 where
  unitIds = map diagnosticElaboratedUnitId units
  duplicateUnitProblems = map DuplicateElaboratedUnitId (duplicates unitIds)
  localComponents =
    [ (root, diagnosticElaboratedComponentName component, diagnosticElaboratedUnitId unit)
    | unit <- units
    , diagnosticElaboratedUnitOrigin unit == LocalUnit
    , Just root <- [diagnosticElaboratedUnitPackageSourceRoot unit]
    , component <- diagnosticElaboratedUnitComponents unit
    ]
  byLocalComponent =
    [ ((root, component), unitId)
    | (root, component, unitId) <- localComponents
    ]
  duplicateLocalComponentProblems =
    [ DuplicateLocalComponent root component (sort unitIdsForComponent)
    | ((root, component), unitIdsForComponent) <- groupedValues byLocalComponent
    , length unitIdsForComponent > 1
    ]
  knownUnitIds = Set.fromList unitIds
  dependencyProblems = concatMap (unitDependencyProblems knownUnitIds) units
  dependencyCycleProblems =
    [ CyclicUnitDependencies (sort cyclicUnits)
    | CyclicSCC cyclicUnits <- stronglyConnComp unitDependencyGraph
    ]
  unitDependencyGraph :: [(Text, Text, [Text])]
  unitDependencyGraph =
    [ (diagnosticElaboratedUnitId unit, diagnosticElaboratedUnitId unit, cycleDependencyIds unit)
    | unit <- units
    ]
  declaredLocal =
    [ (diagnosticElaboratedUnitId unit, name)
    | ParsedUnit unit declaredNames <- parsedUnits
    , diagnosticElaboratedUnitBuildStyle unit == LocalBuildStyle
    , name <- declaredNames
    ]
  emptyUnitProblems =
    [ LocalUnitComponentDiscoveryEmpty (diagnosticElaboratedUnitId unit)
    | unit <- units
    , diagnosticElaboratedUnitOrigin unit == LocalUnit
    , null (diagnosticElaboratedUnitComponents unit)
    ]
  localDiscoveryProblems =
    projectEmptyUnitProblemContribution emptyUnitProblems
      <> [LocalComponentDiscoveryEmpty | localComponentDiscoveryEmpty declaredLocal]

projectDuplicateUnitProblemContribution :: [CompilerElaboratedPlanProblem] -> [CompilerElaboratedPlanProblem]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_UNIT_PROBLEM_CONTRIBUTION_DROP_MUTANT)
projectDuplicateUnitProblemContribution _ = []
#else
projectDuplicateUnitProblemContribution = id
#endif

projectDuplicateLocalComponentProblemContribution :: [CompilerElaboratedPlanProblem] -> [CompilerElaboratedPlanProblem]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_LOCAL_COMPONENT_PROBLEM_CONTRIBUTION_DROP_MUTANT)
projectDuplicateLocalComponentProblemContribution _ = []
#else
projectDuplicateLocalComponentProblemContribution = id
#endif

projectDependencyProblemContribution :: [CompilerElaboratedPlanProblem] -> [CompilerElaboratedPlanProblem]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_PROBLEM_CONTRIBUTION_DROP_MUTANT)
projectDependencyProblemContribution _ = []
#else
projectDependencyProblemContribution = id
#endif

projectDependencyCycleProblemContribution :: [CompilerElaboratedPlanProblem] -> [CompilerElaboratedPlanProblem]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_CYCLE_PROBLEM_CONTRIBUTION_DROP_MUTANT)
projectDependencyCycleProblemContribution _ = []
#else
projectDependencyCycleProblemContribution = id
#endif

projectLocalDiscoveryProblemContribution :: [CompilerElaboratedPlanProblem] -> [CompilerElaboratedPlanProblem]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_DISCOVERY_PROBLEM_CONTRIBUTION_DROP_MUTANT)
projectLocalDiscoveryProblemContribution _ = []
#else
projectLocalDiscoveryProblemContribution = id
#endif

projectEmptyUnitProblemContribution :: [CompilerElaboratedPlanProblem] -> [CompilerElaboratedPlanProblem]
projectEmptyUnitProblemContribution = id

localComponentDiscoveryEmpty :: [(Text, Text)] -> Bool
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_GLOBAL_LOCAL_DISCOVERY_GUARD_BYPASS_MUTANT)
localComponentDiscoveryEmpty declared = null declared `seq` False
#else
localComponentDiscoveryEmpty = null
#endif

unitDependencyProblems :: Set Text -> DiagnosticElaboratedUnit -> [CompilerElaboratedPlanProblem]
unitDependencyProblems knownUnitIds unit =
  projectUnitDependencyContribution preExistingProblems
    <> concatMap componentProblems (diagnosticElaboratedUnitComponents unit)
 where
  unitId = diagnosticElaboratedUnitId unit
  preExistingProblems =
    dependencyListProblems knownUnitIds unitId "<unit>.depends" (diagnosticElaboratedUnitDependencyUnitIds unit)
  componentProblems component =
    projectComponentDependencyContribution
      ( dependencyListProblems
          knownUnitIds
          unitId
          (diagnosticElaboratedComponentName component <> ".depends")
          (diagnosticElaboratedComponentDependencyUnitIds component)
      )
      <> projectComponentExecutableDependencyContribution
        ( dependencyListProblems
            knownUnitIds
            unitId
            (diagnosticElaboratedComponentName component <> ".exe-depends")
            (diagnosticElaboratedComponentExecutableDependencyUnitIds component)
        )

projectUnitDependencyContribution :: [CompilerElaboratedPlanProblem] -> [CompilerElaboratedPlanProblem]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_DEPENDENCY_PROBLEM_CONTRIBUTION_DROP_MUTANT)
projectUnitDependencyContribution _ = []
#else
projectUnitDependencyContribution = id
#endif

projectComponentDependencyContribution :: [CompilerElaboratedPlanProblem] -> [CompilerElaboratedPlanProblem]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_DEPENDENCY_PROBLEM_CONTRIBUTION_DROP_MUTANT)
projectComponentDependencyContribution _ = []
#else
projectComponentDependencyContribution = id
#endif

projectComponentExecutableDependencyContribution :: [CompilerElaboratedPlanProblem] -> [CompilerElaboratedPlanProblem]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_EXECUTABLE_DEPENDENCY_PROBLEM_CONTRIBUTION_DROP_MUTANT)
projectComponentExecutableDependencyContribution _ = []
#else
projectComponentExecutableDependencyContribution = id
#endif

dependencyListProblems
  :: Set Text
  -> Text
  -> Text
  -> [Text]
  -> [CompilerElaboratedPlanProblem]
dependencyListProblems known unitId component dependencies =
  [ DuplicateComponentDependency unitId component dependency
  | dependency <- duplicates dependencies
  , duplicateDependencyForbidden
  ]
    <> [ SelfComponentDependency unitId component dependency
       | dependency <- dependencies
       , dependency == unitId
       , selfDependencyForbidden
       ]
    <> [ UnknownComponentDependencyUnit unitId component dependency
       | dependency <- dependencies
       , Set.notMember dependency known
       , unknownDependencyForbidden
       ]

duplicateDependencyForbidden :: Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_DEPENDENCY_GUARD_BYPASS_MUTANT
duplicateDependencyForbidden = False
#else
duplicateDependencyForbidden = True
#endif

selfDependencyForbidden :: Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_SELF_DEPENDENCY_GUARD_BYPASS_MUTANT
selfDependencyForbidden = False
#else
selfDependencyForbidden = True
#endif

unknownDependencyForbidden :: Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_UNKNOWN_DEPENDENCY_GUARD_BYPASS_MUTANT
unknownDependencyForbidden = False
#else
unknownDependencyForbidden = True
#endif

allUnitDependencyIds :: DiagnosticElaboratedUnit -> [Text]
allUnitDependencyIds unit =
  diagnosticElaboratedUnitDependencyUnitIds unit
    <> concat
      [ diagnosticElaboratedComponentDependencyUnitIds component
          <> diagnosticElaboratedComponentExecutableDependencyUnitIds component
      | component <- diagnosticElaboratedUnitComponents unit
      ]

cycleDependencyIds :: DiagnosticElaboratedUnit -> [Text]
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_CYCLE_GUARD_BYPASS_MUTANT
cycleDependencyIds = filter (const False) . allUnitDependencyIds
#else
cycleDependencyIds = allUnitDependencyIds
#endif

sourcePathResidue :: [DiagnosticElaboratedUnit] -> [CompilerElaboratedPlanProblem]
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_PATH_RESIDUE_DROP_MUTANT
sourcePathResidue _ = []
#else
sourcePathResidue units =
  [ LocalComponentSourcePathsUnavailable
      (diagnosticElaboratedUnitId unit)
      (diagnosticElaboratedComponentName component)
      buildInfoPath
  | unit <- units
  , diagnosticElaboratedUnitBuildStyle unit `elem` [LocalBuildStyle, InplaceBuildStyle]
  , Just buildInfoPath <- [diagnosticElaboratedUnitBuildInfoPath unit]
  , component <- diagnosticElaboratedUnitComponents unit
  , diagnosticElaboratedComponentSourcePaths component == Nothing
  ]
#endif

diagnosticPlanResidue
  :: Text
  -> Int
  -> DiagnosticCompilerElaboratedPlanSnapshot
  -> ( [CompilerElaboratedPlanProblem]
     , [CompilerElaboratedPlanProblem]
     )
diagnosticPlanResidue inputDigest inputBytes
  ( DiagnosticCompilerElaboratedPlanSnapshot
      cabalVersion
      cabalLibraryVersion
      compilerId
      compilerAbi
      operatingSystem
      architecture
      units
    ) =
  ( inputAuthenticationResidue inputDigest inputBytes
      <> artifactGenerationResidue inputDigest inputBytes
      <> expectedCompilerIdentityResidue compilerId compilerAbi
      <> expectedPlatformIdentityResidue architecture operatingSystem
      <> duplicateKeyObservationResidue inputDigest inputBytes
      <> componentUniverseResidue compiledComponents
      <> configurationBranchClosureResidue configurationSubject
      <> cppBranchClosureResidue configurationSubject
      <> dependencySemanticsResidue dependencySubject
      <> packageSourceBytesIdentityResidue packageSourceSubject
      <> buildArtifactPathIdentityResidue buildArtifactSubject
      <> localSourceRootLexicalResidue localSourceRoots
      <> localSourceRootFilesystemResidue localSourceRoots
      <> snapshotBindingResidue
        inputDigest
        inputBytes
        ( cabalVersion
        , cabalLibraryVersion
        , compilerId
        , compilerAbi
        , operatingSystem
        , architecture
        )
        (map diagnosticUnitObservationWire units)
        dependencySubject
        configurationSubject
        packageSourceSubject
      <> oracleQualificationResidue
  , sourcePathResidue units
  )
 where
  compiledComponents =
    projectComponentUniverseSubject
      ( projectComponentUniverseSubjectOrder
          ( sort
              [ (diagnosticElaboratedUnitId unit, diagnosticElaboratedComponentName component)
              | unit <- units
              , componentUniverseBuildStyleIncluded (diagnosticElaboratedUnitBuildStyle unit)
              , component <- diagnosticElaboratedUnitComponents unit
              ]
          )
      )
  configurationSubject =
    projectConfigurationSubject
      ( projectConfigurationSubjectOrder
          ( sort
              [ ( diagnosticElaboratedUnitId unit
                , diagnosticElaboratedUnitBuildStyle unit
                , diagnosticElaboratedUnitComponentShape unit
                , diagnosticElaboratedUnitFlags unit
                , sort (map diagnosticElaboratedComponentName (diagnosticElaboratedUnitComponents unit))
                )
              | unit <- units
              , configurationBuildStyleIncluded (diagnosticElaboratedUnitBuildStyle unit)
              ]
          )
      )
  dependencySubject =
    projectDependencySubject
      (projectDependencySubjectOrder (sort (concatMap unitDependencySubject units)))
  packageSourceSubject =
    projectPackageSourceSubject
      ( projectPackageSourceSubjectOrder
          ( sort
              [ ( diagnosticElaboratedUnitId unit
                , diagnosticElaboratedUnitPackageSourceKind unit
                , diagnosticElaboratedUnitPackageSourceRoot unit
                , diagnosticElaboratedUnitPackageSourceLocation unit
                , diagnosticElaboratedUnitPackageSourceTag unit
                , diagnosticElaboratedUnitPackageCabalSha256 unit
                , diagnosticElaboratedUnitPackageSourceSha256 unit
                )
              | unit <- units
              , packageSourceOriginIncluded (diagnosticElaboratedUnitOrigin unit)
              ]
          )
      )
  buildArtifactSubject =
    projectBuildArtifactSubject
      ( projectBuildArtifactSubjectOrder
          ( sort
              [ ( diagnosticElaboratedUnitId unit
                , diagnosticElaboratedUnitBuildInfoPath unit
                , diagnosticElaboratedUnitDistDirectoryPath unit
                , diagnosticElaboratedUnitBinaryPath unit
                )
              | unit <- units
              , buildArtifactOriginIncluded (diagnosticElaboratedUnitOrigin unit)
              ]
          )
      )
  localSourceRoots =
    projectLocalSourceRootSubject
      ( projectLocalSourceRootSubjectOrder
          ( sort
              [ (diagnosticElaboratedUnitId unit, root)
              | unit <- units
              , localSourceRootOriginIncluded (diagnosticElaboratedUnitOrigin unit)
              , Just root <- [diagnosticElaboratedUnitPackageSourceRoot unit]
              ]
          )
      )

componentUniverseBuildStyleIncluded :: DiagnosticElaboratedUnitBuildStyle -> Bool
componentUniverseBuildStyleIncluded style = case style of
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNIVERSE_LOCAL_STYLE_ALTERNATIVE_DROP_MUTANT)
  LocalBuildStyle -> False
#else
  LocalBuildStyle -> True
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNIVERSE_INPLACE_STYLE_ALTERNATIVE_DROP_MUTANT)
  InplaceBuildStyle -> False
#else
  InplaceBuildStyle -> True
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNIVERSE_GLOBAL_STYLE_EXCLUSION_BYPASS_MUTANT)
  GlobalBuildStyle -> True
#else
  GlobalBuildStyle -> False
#endif
  PreExistingBuildStyle -> False

configurationBuildStyleIncluded :: DiagnosticElaboratedUnitBuildStyle -> Bool
configurationBuildStyleIncluded style = case style of
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_CONFIGURATION_LOCAL_STYLE_ALTERNATIVE_DROP_MUTANT)
  LocalBuildStyle -> False
#else
  LocalBuildStyle -> True
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_CONFIGURATION_GLOBAL_STYLE_ALTERNATIVE_DROP_MUTANT)
  GlobalBuildStyle -> False
#else
  GlobalBuildStyle -> True
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_CONFIGURATION_INPLACE_STYLE_ALTERNATIVE_DROP_MUTANT)
  InplaceBuildStyle -> False
#else
  InplaceBuildStyle -> True
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_CONFIGURATION_PRE_EXISTING_STYLE_EXCLUSION_BYPASS_MUTANT)
  PreExistingBuildStyle -> True
#else
  PreExistingBuildStyle -> False
#endif

packageSourceOriginIncluded :: DiagnosticElaboratedUnitOrigin -> Bool
packageSourceOriginIncluded origin = case origin of
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_SOURCE_LOCAL_ORIGIN_ALTERNATIVE_DROP_MUTANT)
  LocalUnit -> False
#else
  LocalUnit -> True
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_SOURCE_REMOTE_ORIGIN_ALTERNATIVE_DROP_MUTANT)
  RemoteUnit -> False
#else
  RemoteUnit -> True
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_SOURCE_PRE_EXISTING_ORIGIN_EXCLUSION_BYPASS_MUTANT)
  PreExistingUnit -> True
#else
  PreExistingUnit -> False
#endif

buildArtifactOriginIncluded :: DiagnosticElaboratedUnitOrigin -> Bool
buildArtifactOriginIncluded origin = case origin of
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_BUILD_ARTIFACT_LOCAL_ORIGIN_ALTERNATIVE_DROP_MUTANT)
  LocalUnit -> False
#else
  LocalUnit -> True
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_BUILD_ARTIFACT_REMOTE_ORIGIN_ALTERNATIVE_DROP_MUTANT)
  RemoteUnit -> False
#else
  RemoteUnit -> True
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_BUILD_ARTIFACT_PRE_EXISTING_ORIGIN_EXCLUSION_BYPASS_MUTANT)
  PreExistingUnit -> True
#else
  PreExistingUnit -> False
#endif

localSourceRootOriginIncluded :: DiagnosticElaboratedUnitOrigin -> Bool
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_ROOT_LOCAL_ORIGIN_ALTERNATIVE_DROP_MUTANT)
localSourceRootOriginIncluded origin = origin `seq` False
#else
localSourceRootOriginIncluded origin = origin == LocalUnit
#endif

projectComponentUniverseSubject :: [(Text, Text)] -> [(Text, Text)]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNIVERSE_SUBJECT_PROJECTION_DROP_MUTANT)
projectComponentUniverseSubject subject = subject `seq` []
#else
projectComponentUniverseSubject = id
#endif

projectComponentUniverseSubjectOrder :: [(Text, Text)] -> [(Text, Text)]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNIVERSE_SUBJECT_ORDER_MUTANT)
projectComponentUniverseSubjectOrder = reverse
#else
projectComponentUniverseSubjectOrder = id
#endif

projectConfigurationSubject
  :: [(Text, DiagnosticElaboratedUnitBuildStyle, Maybe DiagnosticElaboratedComponentShape, [(Text, Bool)], [Text])]
  -> [(Text, DiagnosticElaboratedUnitBuildStyle, Maybe DiagnosticElaboratedComponentShape, [(Text, Bool)], [Text])]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_CONFIGURATION_SUBJECT_PROJECTION_DROP_MUTANT)
projectConfigurationSubject subject = subject `seq` []
#else
projectConfigurationSubject = id
#endif

projectConfigurationSubjectOrder
  :: [(Text, DiagnosticElaboratedUnitBuildStyle, Maybe DiagnosticElaboratedComponentShape, [(Text, Bool)], [Text])]
  -> [(Text, DiagnosticElaboratedUnitBuildStyle, Maybe DiagnosticElaboratedComponentShape, [(Text, Bool)], [Text])]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_CONFIGURATION_SUBJECT_ORDER_MUTANT)
projectConfigurationSubjectOrder = reverse
#else
projectConfigurationSubjectOrder = id
#endif

projectDependencySubject :: [(Text, Text, Text)] -> [(Text, Text, Text)]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_SUBJECT_PROJECTION_DROP_MUTANT)
projectDependencySubject subject = subject `seq` []
#else
projectDependencySubject = id
#endif

projectDependencySubjectOrder :: [(Text, Text, Text)] -> [(Text, Text, Text)]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_SUBJECT_ORDER_MUTANT)
projectDependencySubjectOrder = reverse
#else
projectDependencySubjectOrder = id
#endif

projectPackageSourceSubject
  :: [(Text, Text, Maybe FilePath, Maybe Text, Maybe Text, Maybe Text, Maybe Text)]
  -> [(Text, Text, Maybe FilePath, Maybe Text, Maybe Text, Maybe Text, Maybe Text)]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_SOURCE_SUBJECT_PROJECTION_DROP_MUTANT)
projectPackageSourceSubject subject = subject `seq` []
#else
projectPackageSourceSubject = id
#endif

projectPackageSourceSubjectOrder
  :: [(Text, Text, Maybe FilePath, Maybe Text, Maybe Text, Maybe Text, Maybe Text)]
  -> [(Text, Text, Maybe FilePath, Maybe Text, Maybe Text, Maybe Text, Maybe Text)]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_SOURCE_SUBJECT_ORDER_MUTANT)
projectPackageSourceSubjectOrder = reverse
#else
projectPackageSourceSubjectOrder = id
#endif

projectBuildArtifactSubject
  :: [(Text, Maybe FilePath, Maybe FilePath, Maybe FilePath)]
  -> [(Text, Maybe FilePath, Maybe FilePath, Maybe FilePath)]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_BUILD_ARTIFACT_SUBJECT_PROJECTION_DROP_MUTANT)
projectBuildArtifactSubject subject = subject `seq` []
#else
projectBuildArtifactSubject = id
#endif

projectBuildArtifactSubjectOrder
  :: [(Text, Maybe FilePath, Maybe FilePath, Maybe FilePath)]
  -> [(Text, Maybe FilePath, Maybe FilePath, Maybe FilePath)]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_BUILD_ARTIFACT_SUBJECT_ORDER_MUTANT)
projectBuildArtifactSubjectOrder = reverse
#else
projectBuildArtifactSubjectOrder = id
#endif

projectLocalSourceRootSubject :: [(Text, FilePath)] -> [(Text, FilePath)]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_ROOT_SUBJECT_PROJECTION_DROP_MUTANT)
projectLocalSourceRootSubject subject = subject `seq` []
#else
projectLocalSourceRootSubject = id
#endif

projectLocalSourceRootSubjectOrder :: [(Text, FilePath)] -> [(Text, FilePath)]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_ROOT_SUBJECT_ORDER_MUTANT)
projectLocalSourceRootSubjectOrder = reverse
#else
projectLocalSourceRootSubjectOrder = id
#endif

inputAuthenticationResidue :: Text -> Int -> [CompilerElaboratedPlanProblem]
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_INPUT_AUTHENTICATION_RESIDUE_BYPASS_MUTANT
inputAuthenticationResidue _ _ = []
#else
inputAuthenticationResidue digest inputBytes = [PlanInputUnauthenticated digest inputBytes]
#endif

artifactGenerationResidue :: Text -> Int -> [CompilerElaboratedPlanProblem]
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_ARTIFACT_GENERATION_RESIDUE_BYPASS_MUTANT
artifactGenerationResidue _ _ = []
#else
artifactGenerationResidue digest inputBytes = [PlanArtifactGenerationUnavailable digest inputBytes]
#endif

expectedCompilerIdentityResidue :: Text -> Text -> [CompilerElaboratedPlanProblem]
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_EXPECTED_COMPILER_IDENTITY_RESIDUE_BYPASS_MUTANT
expectedCompilerIdentityResidue _ _ = []
#else
expectedCompilerIdentityResidue compilerId compilerAbi =
  [ExpectedCompilerIdentityUnavailable compilerId compilerAbi]
#endif

expectedPlatformIdentityResidue :: Text -> Text -> [CompilerElaboratedPlanProblem]
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_EXPECTED_PLATFORM_IDENTITY_RESIDUE_BYPASS_MUTANT
expectedPlatformIdentityResidue _ _ = []
#else
expectedPlatformIdentityResidue architecture operatingSystem =
  [ExpectedPlatformIdentityUnavailable architecture operatingSystem]
#endif

duplicateKeyObservationResidue :: Text -> Int -> [CompilerElaboratedPlanProblem]
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_KEY_OBSERVATION_RESIDUE_BYPASS_MUTANT
duplicateKeyObservationResidue _ _ = []
#else
duplicateKeyObservationResidue digest inputBytes =
  [IndependentDuplicateKeyObservationUnavailable digest inputBytes]
#endif

componentUniverseResidue :: [(Text, Text)] -> [CompilerElaboratedPlanProblem]
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNIVERSE_RESIDUE_BYPASS_MUTANT
componentUniverseResidue _ = []
#else
componentUniverseResidue subject = [IndependentComponentUniverseUnavailable subject]
#endif

configurationBranchClosureResidue
  :: [(Text, DiagnosticElaboratedUnitBuildStyle, Maybe DiagnosticElaboratedComponentShape, [(Text, Bool)], [Text])]
  -> [CompilerElaboratedPlanProblem]
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_CONFIGURATION_BRANCH_CLOSURE_RESIDUE_BYPASS_MUTANT
configurationBranchClosureResidue _ = []
#else
configurationBranchClosureResidue subject = [ConfigurationBranchClosureUnavailable subject]
#endif

cppBranchClosureResidue
  :: [(Text, DiagnosticElaboratedUnitBuildStyle, Maybe DiagnosticElaboratedComponentShape, [(Text, Bool)], [Text])]
  -> [CompilerElaboratedPlanProblem]
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_CPP_BRANCH_CLOSURE_RESIDUE_BYPASS_MUTANT
cppBranchClosureResidue _ = []
#else
cppBranchClosureResidue subject = [CppBranchClosureUnavailable subject]
#endif

dependencySemanticsResidue :: [(Text, Text, Text)] -> [CompilerElaboratedPlanProblem]
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_SEMANTICS_RESIDUE_BYPASS_MUTANT
dependencySemanticsResidue _ = []
#else
dependencySemanticsResidue subject = [IndependentDependencySemanticsUnavailable subject]
#endif

packageSourceBytesIdentityResidue
  :: [(Text, Text, Maybe FilePath, Maybe Text, Maybe Text, Maybe Text, Maybe Text)]
  -> [CompilerElaboratedPlanProblem]
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_SOURCE_BYTES_IDENTITY_RESIDUE_BYPASS_MUTANT
packageSourceBytesIdentityResidue _ = []
#else
packageSourceBytesIdentityResidue subject = [PackageSourceBytesIdentityUnavailable subject]
#endif

buildArtifactPathIdentityResidue
  :: [(Text, Maybe FilePath, Maybe FilePath, Maybe FilePath)]
  -> [CompilerElaboratedPlanProblem]
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_BUILD_ARTIFACT_PATH_IDENTITY_RESIDUE_BYPASS_MUTANT
buildArtifactPathIdentityResidue _ = []
#else
buildArtifactPathIdentityResidue subject = [BuildArtifactPathIdentityUnavailable subject]
#endif

localSourceRootLexicalResidue :: [(Text, FilePath)] -> [CompilerElaboratedPlanProblem]
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_ROOT_LEXICAL_RESIDUE_BYPASS_MUTANT
localSourceRootLexicalResidue _ = []
#else
localSourceRootLexicalResidue subject = [LocalSourceRootIdentityLimitedToLexical subject]
#endif

localSourceRootFilesystemResidue :: [(Text, FilePath)] -> [CompilerElaboratedPlanProblem]
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_ROOT_FILESYSTEM_RESIDUE_BYPASS_MUTANT
localSourceRootFilesystemResidue _ = []
#else
localSourceRootFilesystemResidue subject = [LocalSourceRootFilesystemIdentityUnavailable subject]
#endif

snapshotBindingResidue
  :: Text
  -> Int
  -> (Text, Text, Text, Text, Text, Text)
  -> [DiagnosticUnitObservationWire]
  -> [(Text, Text, Text)]
  -> [(Text, DiagnosticElaboratedUnitBuildStyle, Maybe DiagnosticElaboratedComponentShape, [(Text, Bool)], [Text])]
  -> [(Text, Text, Maybe FilePath, Maybe Text, Maybe Text, Maybe Text, Maybe Text)]
  -> [CompilerElaboratedPlanProblem]
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_SNAPSHOT_BINDING_RESIDUE_BYPASS_MUTANT
snapshotBindingResidue _ _ _ _ _ _ _ = []
#else
snapshotBindingResidue digest inputBytes identity units dependencies configuration sources =
  [ CompilerElaboratedPlanSnapshotBindingUnavailable
      digest
      inputBytes
      identity
      units
      dependencies
      configuration
      sources
  ]
#endif

oracleQualificationResidue :: [CompilerElaboratedPlanProblem]
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_DIAGNOSTIC_RESIDUE_BYPASS_MUTANT
oracleQualificationResidue = []
#else
oracleQualificationResidue = [CompilerElaboratedPlanOracleQualificationUnavailable]
#endif

unitDependencySubject :: DiagnosticElaboratedUnit -> [(Text, Text, Text)]
unitDependencySubject unit =
  projectUnitDependencySubjectRoute
    [ (unitId, unitDependencySubjectLabel, dependency)
    | dependency <- diagnosticElaboratedUnitDependencyUnitIds unit
    ]
    <> concatMap componentSubject (diagnosticElaboratedUnitComponents unit)
 where
  unitId = diagnosticElaboratedUnitId unit
  componentSubject component =
    projectComponentDependencySubjectRoute
      [ (unitId, diagnosticElaboratedComponentName component <> componentDependencySubjectSuffix, dependency)
      | dependency <- diagnosticElaboratedComponentDependencyUnitIds component
      ]
      <> projectComponentExecutableDependencySubjectRoute
        [ ( unitId
          , diagnosticElaboratedComponentName component <> componentExecutableDependencySubjectSuffix
          , dependency
          )
        | dependency <- diagnosticElaboratedComponentExecutableDependencyUnitIds component
        ]

projectUnitDependencySubjectRoute :: [(Text, Text, Text)] -> [(Text, Text, Text)]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_DEPENDENCY_SUBJECT_ROUTE_DROP_MUTANT)
projectUnitDependencySubjectRoute subject = subject `seq` []
#else
projectUnitDependencySubjectRoute = id
#endif

projectComponentDependencySubjectRoute :: [(Text, Text, Text)] -> [(Text, Text, Text)]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_DEPENDENCY_SUBJECT_ROUTE_DROP_MUTANT)
projectComponentDependencySubjectRoute subject = subject `seq` []
#else
projectComponentDependencySubjectRoute = id
#endif

projectComponentExecutableDependencySubjectRoute :: [(Text, Text, Text)] -> [(Text, Text, Text)]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_EXECUTABLE_DEPENDENCY_SUBJECT_ROUTE_DROP_MUTANT)
projectComponentExecutableDependencySubjectRoute subject = subject `seq` []
#else
projectComponentExecutableDependencySubjectRoute = id
#endif

unitDependencySubjectLabel :: Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_DEPENDENCY_SUBJECT_LABEL_MAPPING_MUTANT)
unitDependencySubjectLabel = "<unit>.mutated-depends"
#else
unitDependencySubjectLabel = "<unit>.depends"
#endif

componentDependencySubjectSuffix :: Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_DEPENDENCY_SUBJECT_LABEL_MAPPING_MUTANT)
componentDependencySubjectSuffix = ".mutated-depends"
#else
componentDependencySubjectSuffix = ".depends"
#endif

componentExecutableDependencySubjectSuffix :: Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_EXECUTABLE_DEPENDENCY_SUBJECT_LABEL_MAPPING_MUTANT)
componentExecutableDependencySubjectSuffix = ".mutated-exe-depends"
#else
componentExecutableDependencySubjectSuffix = ".exe-depends"
#endif

sourceIdentityProblemsForHashes
  :: Text
  -> Text
  -> PackageSource
  -> Bool
  -> Bool
  -> Maybe Text
  -> Maybe Text
  -> [CompilerElaboratedPlanProblem]
sourceIdentityProblemsForHashes scope unitId source cabalPresent sourcePresent cabalSha sourceSha = case source of
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_IDENTITY_ROUTE_DROP_MUTANT)
  LocalPackageSource _ ->
    localSourceIdentityProblems scope cabalPresent sourcePresent `seq` []
#else
  LocalPackageSource _ ->
    localSourceIdentityProblems scope cabalPresent sourcePresent
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TAR_SOURCE_IDENTITY_ROUTE_DROP_MUTANT)
  RepositoryTarPackageSource _ _ ->
    repositoryTarSourceIdentityProblems unitId cabalPresent sourcePresent cabalSha sourceSha `seq` []
#else
  RepositoryTarPackageSource _ _ ->
    repositoryTarSourceIdentityProblems unitId cabalPresent sourcePresent cabalSha sourceSha
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_REPOSITORY_IDENTITY_ROUTE_DROP_MUTANT)
  SourceRepositoryPackageSource _ _ tag ->
    sourceRepositoryIdentityProblems scope unitId cabalPresent sourcePresent sourceSha tag `seq` []
#else
  SourceRepositoryPackageSource _ _ tag ->
    sourceRepositoryIdentityProblems scope unitId cabalPresent sourcePresent sourceSha tag
#endif
  PreExistingPackageSource -> []

localSourceIdentityProblems :: Text -> Bool -> Bool -> [CompilerElaboratedPlanProblem]
localSourceIdentityProblems scope cabalPresent sourcePresent =
  [PlanJsonFieldUnexpected scope "pkg-cabal-sha256" | localCabalHashForbidden cabalPresent]
    <> [PlanJsonFieldUnexpected scope "pkg-src-sha256" | localSourceHashForbidden sourcePresent]

repositoryTarSourceIdentityProblems
  :: Text
  -> Bool
  -> Bool
  -> Maybe Text
  -> Maybe Text
  -> [CompilerElaboratedPlanProblem]
repositoryTarSourceIdentityProblems unitId cabalPresent sourcePresent cabalSha sourceSha =
  [RemotePackageSourceHashMissing unitId | repositorySourceHashMissing sourcePresent]
    <> [ RemotePackageSourceHashMalformed unitId observed
       | Just observed <- [sourceSha]
       , not (sha256DigestText observed)
       ]
    <> [RepositoryCabalHashMissing unitId | repositoryCabalHashMissing cabalPresent]
    <> [ RepositoryCabalHashMalformed unitId observed
       | Just observed <- [cabalSha]
       , not (sha256DigestText observed)
       ]

sourceRepositoryIdentityProblems
  :: Text
  -> Text
  -> Bool
  -> Bool
  -> Maybe Text
  -> Text
  -> [CompilerElaboratedPlanProblem]
sourceRepositoryIdentityProblems scope unitId cabalPresent sourcePresent sourceSha tag =
  [PlanJsonFieldUnexpected scope "pkg-cabal-sha256" | sourceRepositoryCabalHashForbidden cabalPresent]
    <> [RemotePackageSourceHashMissing unitId | sourceRepositoryHashMissing sourcePresent]
    <> [ RemotePackageSourceHashMalformed unitId observed
       | Just observed <- [sourceSha]
       , not (sha256DigestText observed)
       ]
    <> [SourceRepositoryTagMutable unitId tag | not (immutableGitObjectText tag)]

localCabalHashForbidden :: Bool -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_CABAL_HASH_GUARD_BYPASS_MUTANT
localCabalHashForbidden _ = False
#else
localCabalHashForbidden = id
#endif

localSourceHashForbidden :: Bool -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_HASH_GUARD_BYPASS_MUTANT
localSourceHashForbidden _ = False
#else
localSourceHashForbidden = id
#endif

repositorySourceHashMissing :: Bool -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_SOURCE_HASH_PRESENCE_BYPASS_MUTANT
repositorySourceHashMissing _ = False
#else
repositorySourceHashMissing = not
#endif

repositoryCabalHashMissing :: Bool -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_CABAL_HASH_PRESENCE_BYPASS_MUTANT
repositoryCabalHashMissing _ = False
#else
repositoryCabalHashMissing = not
#endif

sourceRepositoryCabalHashForbidden :: Bool -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_REPOSITORY_CABAL_HASH_GUARD_BYPASS_MUTANT
sourceRepositoryCabalHashForbidden _ = False
#else
sourceRepositoryCabalHashForbidden = id
#endif

sourceRepositoryHashMissing :: Bool -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_REPOSITORY_HASH_PRESENCE_BYPASS_MUTANT
sourceRepositoryHashMissing _ = False
#else
sourceRepositoryHashMissing = not
#endif

sha256DigestText :: Text -> Bool
sha256DigestText value = sha256WidthAccepted value && sha256CharactersAccepted value

sha256WidthAccepted :: Text -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_SHA256_WIDTH_BYPASS_MUTANT
sha256WidthAccepted value = Text.length value `elem` [63, 64]
#else
sha256WidthAccepted value = Text.length value == 64
#endif

sha256CharactersAccepted :: Text -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_SHA256_CHARACTER_BYPASS_MUTANT
sha256CharactersAccepted value = Text.all (\character -> lowerHexCharacter character || character == 'g') value
#else
sha256CharactersAccepted value = Text.all lowerHexCharacter value
#endif

immutableGitObjectText :: Text -> Bool
immutableGitObjectText value =
  immutableGitWidthAccepted value && immutableGitCharactersAccepted value

immutableGitWidthAccepted :: Text -> Bool
immutableGitWidthAccepted value =
  immutableGitSha1WidthAccepted value || immutableGitSha256WidthAccepted value

immutableGitSha1WidthAccepted :: Text -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_GIT_SHA1_WIDTH_BYPASS_MUTANT
immutableGitSha1WidthAccepted value = Text.length value `elem` [39, 40]
#else
immutableGitSha1WidthAccepted value = Text.length value == 40
#endif

immutableGitSha256WidthAccepted :: Text -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_GIT_SHA256_WIDTH_BYPASS_MUTANT
immutableGitSha256WidthAccepted value = Text.length value `elem` [63, 64]
#else
immutableGitSha256WidthAccepted value = Text.length value == 64
#endif

immutableGitCharactersAccepted :: Text -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_GIT_OBJECT_CHARACTER_BYPASS_MUTANT
immutableGitCharactersAccepted value = Text.all (\character -> lowerHexCharacter character || character == 'g') value
#else
immutableGitCharactersAccepted value = Text.all lowerHexCharacter value
#endif

lowerHexCharacter :: Char -> Bool
lowerHexCharacter character =
  lowerHexDigitAccepted character || lowerHexAlphaAccepted character

lowerHexDigitAccepted :: Char -> Bool
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_LOWER_HEX_DIGIT_ALTERNATIVE_DROP_MUTANT)
lowerHexDigitAccepted character = character `seq` False
#else
lowerHexDigitAccepted character = character >= '0' && character <= '9'
#endif

lowerHexAlphaAccepted :: Char -> Bool
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_LOWER_HEX_ALPHA_ALTERNATIVE_DROP_MUTANT)
lowerHexAlphaAccepted character = character `seq` False
#else
lowerHexAlphaAccepted character = character >= 'a' && character <= 'f'
#endif

requiredText :: Text -> Object -> Text -> Parsed Text
requiredText scope object name = case KeyMap.lookup (Key.fromText name) object of
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_TEXT_MISSING_ROUTE_MUTANT)
  Nothing -> Parsed [] (Just "mutated-missing")
#else
  Nothing -> Parsed [PlanJsonFieldMissing scope name] Nothing
#endif
  Just (String value)
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_TEXT_EMPTY_ROUTE_MUTANT)
    | Text.null value -> Parsed [] (Just "mutated-empty")
#else
    | Text.null value -> Parsed [PlanJsonTextEmpty scope name] Nothing
#endif
    | otherwise -> Parsed [] (Just value)
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_TEXT_TYPE_ROUTE_MUTANT)
  Just value -> jsonType value `seq` Parsed [] (Just "mutated-type")
#else
  Just value -> Parsed [PlanJsonFieldTypeMismatch scope name (jsonType value)] Nothing
#endif

optionalText :: Text -> Object -> Text -> Parsed Text
optionalText scope object name = case KeyMap.lookup (Key.fromText name) object of
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_OPTIONAL_TEXT_MISSING_ROUTE_MUTANT)
  Nothing -> Parsed [] (Just "mutated-missing")
#else
  Nothing -> Parsed [] Nothing
#endif
  Just (String value)
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_OPTIONAL_TEXT_EMPTY_ROUTE_MUTANT)
    | Text.null value -> Parsed [] Nothing
#else
    | Text.null value -> Parsed [PlanJsonTextEmpty scope name] Nothing
#endif
    | otherwise -> Parsed [] (Just value)
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_OPTIONAL_TEXT_TYPE_ROUTE_MUTANT)
  Just value -> jsonType value `seq` Parsed [] Nothing
#else
  Just value -> Parsed [PlanJsonFieldTypeMismatch scope name (jsonType value)] Nothing
#endif

requiredSemanticText :: Text -> Object -> Text -> Parsed Text
requiredSemanticText scope object name =
  constrainParsedText
    scope
    name
    boundedSemanticText
    (requiredText scope object name)

optionalSemanticText :: Text -> Object -> Text -> Parsed Text
optionalSemanticText scope object name =
  constrainParsedText
    scope
    name
    boundedSemanticText
    (optionalText scope object name)

requiredConstrainedText
  :: Text
  -> Object
  -> Text
  -> (Text -> Bool)
  -> Parsed Text
requiredConstrainedText scope object name predicate =
  constrainParsedText scope name predicate (requiredText scope object name)

requiredConstrainedTextArray
  :: Text
  -> Object
  -> Text
  -> (Text -> Bool)
  -> Parsed [Text]
requiredConstrainedTextArray scope object name predicate =
  case requiredDependencyTextArray scope object name of
    Parsed problems Nothing -> Parsed problems Nothing
    Parsed problems (Just values) ->
      let malformed =
            [ PlanJsonTextMalformed
                scope
                (name <> "[" <> Text.pack (show index) <> "]")
                value
            | (index, value) <- zip [0 :: Int ..] values
            , constrainedArrayValueRejected predicate value
            ]
       in if null malformed
            then Parsed problems (Just values)
            else Parsed (problems <> malformed) Nothing

constrainedArrayValueRejected :: (Text -> Bool) -> Text -> Bool
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_CONSTRAINED_ARRAY_VALUE_GATE_BYPASS_MUTANT)
constrainedArrayValueRejected predicate value = predicate value `seq` False
#else
constrainedArrayValueRejected predicate value = not (semanticTextAccepted predicate value)
#endif

constrainParsedText
  :: Text
  -> Text
  -> (Text -> Bool)
  -> Parsed Text
  -> Parsed Text
constrainParsedText scope name predicate (Parsed problems parsed) = case parsed of
  Just value
    | constrainedTextValueRejected predicate value ->
        Parsed (problems <> [PlanJsonTextMalformed scope name value]) Nothing
  _ -> Parsed problems parsed

constrainedTextValueRejected :: (Text -> Bool) -> Text -> Bool
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_CONSTRAINED_TEXT_VALUE_GATE_BYPASS_MUTANT)
constrainedTextValueRejected predicate value = predicate value `seq` False
#else
constrainedTextValueRejected predicate value = not (semanticTextAccepted predicate value)
#endif

requiredSafeFilePath :: Text -> Object -> Text -> Parsed FilePath
requiredSafeFilePath scope object name =
  constrainParsedPath scope name (requiredText scope object name)

optionalSafeFilePath :: Text -> Object -> Text -> Parsed FilePath
optionalSafeFilePath scope object name =
  constrainParsedPath scope name (optionalText scope object name)

constrainParsedPath :: Text -> Text -> Parsed Text -> Parsed FilePath
constrainParsedPath scope name (Parsed problems parsed) = case parsed of
  Just value
    | constrainedPathValueRejected value ->
        Parsed
          (problems <> [PlanJsonPathUnsafe scope name (Text.unpack value)])
          Nothing
    | otherwise -> Parsed problems (Just (Text.unpack value))
  Nothing -> Parsed problems Nothing

constrainedPathValueRejected :: Text -> Bool
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_CONSTRAINED_PATH_VALUE_GATE_BYPASS_MUTANT)
constrainedPathValueRejected value = pathTextAccepted value `seq` False
#else
constrainedPathValueRejected = not . pathTextAccepted
#endif

requiredObject :: Text -> Object -> Text -> Parsed Object
requiredObject scope object name = case KeyMap.lookup (Key.fromText name) object of
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_OBJECT_MISSING_ROUTE_MUTANT)
  Nothing -> Parsed [] (Just KeyMap.empty)
#else
  Nothing -> Parsed [PlanJsonFieldMissing scope name] Nothing
#endif
  Just (Object value) -> Parsed [] (Just value)
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_OBJECT_TYPE_ROUTE_MUTANT)
  Just value -> jsonType value `seq` Parsed [] (Just KeyMap.empty)
#else
  Just value -> Parsed [PlanJsonFieldTypeMismatch scope name (jsonType value)] Nothing
#endif

requiredUnitArray :: Text -> Object -> Text -> Parsed [Value]
requiredUnitArray scope object name = case KeyMap.lookup (Key.fromText name) object of
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_UNIT_ARRAY_MISSING_ROUTE_MUTANT)
  Nothing -> Parsed [] (Just [])
#else
  Nothing -> Parsed [PlanJsonFieldMissing scope name] Nothing
#endif
  Just (Array values)
    | unitLimitExceeded (Foldable.length values) ->
        Parsed
          [ PlanResourceLimitExceeded
              "units"
              compilerElaboratedPlanMaximumUnits
              (Foldable.length values)
          ]
          Nothing
    | otherwise -> Parsed [] (Just (toList values))
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_UNIT_ARRAY_TYPE_ROUTE_MUTANT)
  Just value -> jsonType value `seq` Parsed [] (Just [])
#else
  Just value -> Parsed [PlanJsonFieldTypeMismatch scope name (jsonType value)] Nothing
#endif

requiredDependencyTextArray :: Text -> Object -> Text -> Parsed [Text]
requiredDependencyTextArray scope object name = case KeyMap.lookup (Key.fromText name) object of
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_ARRAY_MISSING_ROUTE_MUTANT)
  Nothing -> Parsed [] (Just [])
#else
  Nothing -> Parsed [PlanJsonFieldMissing scope name] Nothing
#endif
  Just (Array values) -> decodeTextValues (toList values)
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_ARRAY_TYPE_ROUTE_MUTANT)
  Just value -> jsonType value `seq` Parsed [] (Just [])
#else
  Just value -> Parsed [PlanJsonFieldTypeMismatch scope name (jsonType value)] Nothing
#endif
 where
  decodeTextValues values =
    let typed = map asText (zip [0 :: Int ..] values)
        typeProblems = [problem | Left problem <- typed]
        texts = [value | Right value <- typed]
     in if null typeProblems
          then Parsed [] (Just texts)
          else Parsed typeProblems Nothing
  asText (position, String value)
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_ARRAY_EMPTY_TEXT_ROUTE_MUTANT)
    | Text.null value = position `seq` Right "mutated-empty"
#else
    | Text.null value = Left (PlanJsonTextEmpty scope (name <> "[" <> Text.pack (show position) <> "]"))
#endif
    | otherwise = Right value
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_ARRAY_ELEMENT_TYPE_ROUTE_MUTANT)
  asText (position, value) = position `seq` jsonType value `seq` Right "mutated-type"
#else
  asText (position, value) =
    Left
      ( PlanJsonFieldTypeMismatch
          scope
          (name <> "[" <> Text.pack (show position) <> "]")
          (jsonType value)
      )
#endif

requiredBooleanMap :: Text -> Object -> Text -> Parsed [(Text, Bool)]
requiredBooleanMap scope object name = case requiredObject scope object name of
  Parsed problems Nothing -> Parsed problems Nothing
  Parsed problems (Just values) ->
    let orderedEntries = sortOn (Key.toText . fst) (KeyMap.toList values)
        typed = map asBoolean orderedEntries
        typeProblems = [problem | Left problem <- typed]
        flags = projectFlagOrder (sort [value | Right value <- typed])
        nameProblems =
          [ PlanJsonTextMalformed (jsonFieldScope scope name) key key
          | key <- map (Key.toText . fst) orderedEntries
          , not (semanticTextAccepted flagNameText key)
          ]
     in if null typeProblems && null nameProblems
          then Parsed problems (Just flags)
          else Parsed (problems <> typeProblems <> nameProblems) Nothing
 where
  asBoolean (key, Bool value) = Right (Key.toText key, value)
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_BOOLEAN_MAP_VALUE_TYPE_ROUTE_MUTANT)
  asBoolean (key, value) = jsonType value `seq` Right (Key.toText key, False)
#else
  asBoolean (key, value) =
    Left
      ( PlanJsonFieldTypeMismatch
          (jsonFieldScope scope name)
          (Key.toText key)
          (jsonType value)
      )
#endif

projectFlagOrder :: [(Text, Bool)] -> [(Text, Bool)]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_FLAG_ORDER_MUTANT)
projectFlagOrder = reverse
#else
projectFlagOrder = id
#endif

unknownFields :: Text -> Set Text -> Object -> [CompilerElaboratedPlanProblem]
unknownFields scope allowed object =
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_UNKNOWN_FIELD_DETECTION_BYPASS_MUTANT)
  [ PlanJsonFieldUnknown scope observed
  | observed <- projectUnknownFieldOrder (sort (map Key.toText (KeyMap.keys object)))
  , Set.notMember observed allowed
  , Text.null observed && not (Text.null observed)
  ]
#else
  [ PlanJsonFieldUnknown scope observed
  | observed <- projectUnknownFieldOrder (sort (map Key.toText (KeyMap.keys object)))
  , Set.notMember observed allowed
  ]
#endif

projectUnknownFieldOrder :: [Text] -> [Text]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_UNKNOWN_FIELD_ORDER_MUTANT)
projectUnknownFieldOrder = reverse
#else
projectUnknownFieldOrder = id
#endif

jsonType :: Value -> Text
jsonType value = case value of
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_JSON_OBJECT_TYPE_MAPPING_MUTANT)
  Object _ -> "mutated-object"
#else
  Object _ -> "object"
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_JSON_ARRAY_TYPE_MAPPING_MUTANT)
  Array _ -> "mutated-array"
#else
  Array _ -> "array"
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_JSON_STRING_TYPE_MAPPING_MUTANT)
  String _ -> "mutated-string"
#else
  String _ -> "string"
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_JSON_NUMBER_TYPE_MAPPING_MUTANT)
  Number _ -> "mutated-number"
#else
  Number _ -> "number"
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_JSON_BOOLEAN_TYPE_MAPPING_MUTANT)
  Bool _ -> "mutated-boolean"
#else
  Bool _ -> "boolean"
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_JSON_NULL_TYPE_MAPPING_MUTANT)
  Null -> "mutated-null"
#else
  Null -> "null"
#endif

unitScope :: Int -> Text
unitScope index =
  renderJsonPath
    (appendJsonIndex (appendJsonField (JsonPath []) "install-plan") index)

observedTextOr :: Text -> Parsed Text -> Text
observedTextOr fallback parsed = maybe fallback id (parsedValue parsed)

parsedProblems :: Parsed value -> [CompilerElaboratedPlanProblem]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_PARSED_PROBLEMS_PROJECTION_DROP_MUTANT)
parsedProblems (Parsed problems value) = value `seq` problems `seq` []
#else
parsedProblems (Parsed problems _) = problems
#endif

parsedValue :: Parsed value -> Maybe value
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_PARSED_VALUE_PROJECTION_DROP_MUTANT)
parsedValue (Parsed problems value) = problems `seq` value `seq` Nothing
#else
parsedValue (Parsed _ value) = value
#endif

partitionParsed :: [Parsed value] -> ([CompilerElaboratedPlanProblem], [value])
partitionParsed values =
  ( projectPartitionProblemContribution (concatMap parsedProblems values)
  , projectPartitionValueContribution (catMaybes (map parsedValue values))
  )

projectPartitionProblemContribution :: [CompilerElaboratedPlanProblem] -> [CompilerElaboratedPlanProblem]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_PARTITION_PROBLEM_CONTRIBUTION_DROP_MUTANT)
projectPartitionProblemContribution _ = []
#else
projectPartitionProblemContribution = id
#endif

projectPartitionValueContribution :: [value] -> [value]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_PARTITION_VALUE_CONTRIBUTION_DROP_MUTANT)
projectPartitionValueContribution _ = []
#else
projectPartitionValueContribution = id
#endif

parsedUnitValue :: ParsedUnit -> DiagnosticElaboratedUnit
parsedUnitValue (ParsedUnit unit _) = unit

duplicates :: Ord value => [value] -> [value]
duplicates = mapMaybe duplicateValue . group . sort
 where
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_GROUPING_BYPASS_MUTANT)
  duplicateValue values = values `seq` Nothing
#else
  duplicateValue (value : _ : _) = Just value
  duplicateValue _ = Nothing
#endif

groupedValues :: (Ord key, Ord value) => [(key, value)] -> [(key, [value])]
groupedValues values = mapMaybe renderGroup (groupByKey (sortOn fst values))
 where
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_GROUPED_VALUE_RENDER_DROP_MUTANT)
  renderGroup groupValues = groupValues `seq` Nothing
#else
  renderGroup ((key, value) : remaining) =
    Just (key, sort (value : map snd remaining))
  renderGroup [] = Nothing
#endif
  groupByKey [] = []
  groupByKey (first : remaining) =
    let (same, rest) = span ((== fst first) . fst) remaining
     in (first : same) : groupByKey rest

diagnosticComponentShape
  :: ConfiguredComponentShape
  -> DiagnosticElaboratedComponentShape
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_SHAPE_COLLAPSE_MUTANT
diagnosticComponentShape _ = DirectElaboratedComponentShape
#else
diagnosticComponentShape shape = case shape of
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_DIRECT_COMPONENT_SHAPE_MAPPING_MUTANT)
  DirectComponentShape _ -> AggregateElaboratedComponentShape
#else
  DirectComponentShape _ -> DirectElaboratedComponentShape
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_AGGREGATE_COMPONENT_SHAPE_MAPPING_MUTANT)
  ComponentMapShape -> DirectElaboratedComponentShape
#else
  ComponentMapShape -> AggregateElaboratedComponentShape
#endif
#endif

componentNameText :: Text -> Bool
componentNameText value =
  componentBuiltinAccepted value
    || case qualifiedComponentSuffix value of
      Just suffix ->
        boundedSemanticText suffix
          && componentBoundaryAccepted suffix
          && Text.all componentCharacterAccepted suffix
      Nothing -> False

componentBuiltinAccepted :: Text -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_BUILTIN_BYPASS_MUTANT
componentBuiltinAccepted value =
  componentLibBuiltinAccepted value
    || componentSetupBuiltinAccepted value
    || value == "foreign"
#else
componentBuiltinAccepted value =
  componentLibBuiltinAccepted value || componentSetupBuiltinAccepted value
#endif

componentLibBuiltinAccepted :: Text -> Bool
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_LIB_BUILTIN_ALTERNATIVE_DROP_MUTANT)
componentLibBuiltinAccepted value = value `seq` False
#else
componentLibBuiltinAccepted value = value == "lib"
#endif

componentSetupBuiltinAccepted :: Text -> Bool
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_SETUP_BUILTIN_ALTERNATIVE_DROP_MUTANT)
componentSetupBuiltinAccepted value = value `seq` False
#else
componentSetupBuiltinAccepted value = value == "setup"
#endif

qualifiedComponentSuffix :: Text -> Maybe Text
qualifiedComponentSuffix value = firstPrefix componentPrefixes
 where
  firstPrefix [] = Nothing
  firstPrefix (prefix : remaining) = case Text.stripPrefix prefix value of
    Just suffix -> Just suffix
    Nothing -> firstPrefix remaining

componentPrefixes :: [Text]
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_PREFIX_BYPASS_MUTANT
componentPrefixes =
  componentLibPrefix
    <> componentExecutablePrefix
    <> componentTestPrefix
    <> componentBenchmarkPrefix
    <> ["foreign:"]
#else
componentPrefixes =
  componentLibPrefix <> componentExecutablePrefix <> componentTestPrefix <> componentBenchmarkPrefix
#endif

componentLibPrefix :: [Text]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_LIB_PREFIX_ALTERNATIVE_DROP_MUTANT)
componentLibPrefix = []
#else
componentLibPrefix = ["lib:"]
#endif

componentExecutablePrefix :: [Text]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_EXECUTABLE_PREFIX_ALTERNATIVE_DROP_MUTANT)
componentExecutablePrefix = []
#else
componentExecutablePrefix = ["exe:"]
#endif

componentTestPrefix :: [Text]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_TEST_PREFIX_ALTERNATIVE_DROP_MUTANT)
componentTestPrefix = []
#else
componentTestPrefix = ["test:"]
#endif

componentBenchmarkPrefix :: [Text]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_BENCHMARK_PREFIX_ALTERNATIVE_DROP_MUTANT)
componentBenchmarkPrefix = []
#else
componentBenchmarkPrefix = ["bench:"]
#endif

componentBoundaryAccepted :: Text -> Bool
componentBoundaryAccepted value =
  componentLeadingBoundaryAccepted value && componentTrailingBoundaryAccepted value

componentLeadingBoundaryAccepted :: Text -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_LEADING_BOUNDARY_BYPASS_MUTANT
componentLeadingBoundaryAccepted = not . Text.null
#else
componentLeadingBoundaryAccepted value = maybe False (asciiAlphaNumeric . fst) (Text.uncons value)
#endif

componentTrailingBoundaryAccepted :: Text -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_TRAILING_BOUNDARY_BYPASS_MUTANT
componentTrailingBoundaryAccepted = not . Text.null
#else
componentTrailingBoundaryAccepted value = maybe False (asciiAlphaNumeric . snd) (Text.unsnoc value)
#endif

componentCharacterAccepted :: Char -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_CHARACTER_BYPASS_MUTANT
componentCharacterAccepted character =
  asciiAlphaNumeric character
    || componentDotAccepted character
    || componentUnderscoreAccepted character
    || componentHyphenAccepted character
    || character == '@'
#else
componentCharacterAccepted character =
  asciiAlphaNumeric character
    || componentDotAccepted character
    || componentUnderscoreAccepted character
    || componentHyphenAccepted character
#endif

componentDotAccepted :: Char -> Bool
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_DOT_ALTERNATIVE_DROP_MUTANT)
componentDotAccepted character = character `seq` False
#else
componentDotAccepted character = character == '.'
#endif

componentUnderscoreAccepted :: Char -> Bool
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNDERSCORE_ALTERNATIVE_DROP_MUTANT)
componentUnderscoreAccepted character = character `seq` False
#else
componentUnderscoreAccepted character = character == '_'
#endif

componentHyphenAccepted :: Char -> Bool
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_HYPHEN_ALTERNATIVE_DROP_MUTANT)
componentHyphenAccepted character = character `seq` False
#else
componentHyphenAccepted character = character == '-'
#endif

semanticTextAccepted :: (Text -> Bool) -> Text -> Bool
semanticTextAccepted predicate value = predicate value

compilerIdText :: Text -> Bool
compilerIdText value =
  boundedSemanticText value
    && case compilerVersionSuffix value of
      Just version -> packageVersionText version
      Nothing -> False

compilerVersionSuffix :: Text -> Maybe Text
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_COMPILER_PREFIX_BYPASS_MUTANT
compilerVersionSuffix value = case Text.stripPrefix "ghc-" value of
  Just version -> Just version
  Nothing -> Text.stripPrefix "gch-" value
#else
compilerVersionSuffix = Text.stripPrefix "ghc-"
#endif

portableIdentityText :: Text -> Bool
portableIdentityText value =
  boundedSemanticText value
    && portableIdentityBoundaryAccepted value
    && Text.all portableIdentityCharacterAccepted value

portableIdentityBoundaryAccepted :: Text -> Bool
portableIdentityBoundaryAccepted value =
  portableIdentityLeadingBoundaryAccepted value
    && portableIdentityTrailingBoundaryAccepted value

portableIdentityLeadingBoundaryAccepted :: Text -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_PORTABLE_IDENTITY_LEADING_BOUNDARY_BYPASS_MUTANT
portableIdentityLeadingBoundaryAccepted = not . Text.null
#else
portableIdentityLeadingBoundaryAccepted value =
  maybe False (asciiAlphaNumeric . fst) (Text.uncons value)
#endif

portableIdentityTrailingBoundaryAccepted :: Text -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_PORTABLE_IDENTITY_TRAILING_BOUNDARY_BYPASS_MUTANT
portableIdentityTrailingBoundaryAccepted = not . Text.null
#else
portableIdentityTrailingBoundaryAccepted value =
  maybe False (asciiAlphaNumeric . snd) (Text.unsnoc value)
#endif

portableIdentityCharacterAccepted :: Char -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_PORTABLE_IDENTITY_CHARACTER_BYPASS_MUTANT
portableIdentityCharacterAccepted character =
  asciiAlphaNumeric character
    || portableIdentityHyphenAccepted character
    || portableIdentityUnderscoreAccepted character
    || portableIdentityDotAccepted character
    || portableIdentityPlusAccepted character
    || portableIdentityColonAccepted character
    || character == '@'
#else
portableIdentityCharacterAccepted character =
  asciiAlphaNumeric character
    || portableIdentityHyphenAccepted character
    || portableIdentityUnderscoreAccepted character
    || portableIdentityDotAccepted character
    || portableIdentityPlusAccepted character
    || portableIdentityColonAccepted character
#endif

portableIdentityHyphenAccepted :: Char -> Bool
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_PORTABLE_IDENTITY_HYPHEN_ALTERNATIVE_DROP_MUTANT)
portableIdentityHyphenAccepted character = character `seq` False
#else
portableIdentityHyphenAccepted character = character == '-'
#endif

portableIdentityUnderscoreAccepted :: Char -> Bool
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_PORTABLE_IDENTITY_UNDERSCORE_ALTERNATIVE_DROP_MUTANT)
portableIdentityUnderscoreAccepted character = character `seq` False
#else
portableIdentityUnderscoreAccepted character = character == '_'
#endif

portableIdentityDotAccepted :: Char -> Bool
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_PORTABLE_IDENTITY_DOT_ALTERNATIVE_DROP_MUTANT)
portableIdentityDotAccepted character = character `seq` False
#else
portableIdentityDotAccepted character = character == '.'
#endif

portableIdentityPlusAccepted :: Char -> Bool
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_PORTABLE_IDENTITY_PLUS_ALTERNATIVE_DROP_MUTANT)
portableIdentityPlusAccepted character = character `seq` False
#else
portableIdentityPlusAccepted character = character == '+'
#endif

portableIdentityColonAccepted :: Char -> Bool
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_PORTABLE_IDENTITY_COLON_ALTERNATIVE_DROP_MUTANT)
portableIdentityColonAccepted character = character `seq` False
#else
portableIdentityColonAccepted character = character == ':'
#endif

platformTokenText :: Text -> Bool
platformTokenText value =
  boundedSemanticText value
    && platformBoundaryAccepted value
    && Text.all platformCharacterAccepted value

platformBoundaryAccepted :: Text -> Bool
platformBoundaryAccepted value =
  platformLeadingBoundaryAccepted value && platformTrailingBoundaryAccepted value

platformLeadingBoundaryAccepted :: Text -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_PLATFORM_LEADING_BOUNDARY_BYPASS_MUTANT
platformLeadingBoundaryAccepted = not . Text.null
#else
platformLeadingBoundaryAccepted value = maybe False (asciiAlphaNumeric . fst) (Text.uncons value)
#endif

platformTrailingBoundaryAccepted :: Text -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_PLATFORM_TRAILING_BOUNDARY_BYPASS_MUTANT
platformTrailingBoundaryAccepted = not . Text.null
#else
platformTrailingBoundaryAccepted value = maybe False (asciiAlphaNumeric . snd) (Text.unsnoc value)
#endif

platformCharacterAccepted :: Char -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_PLATFORM_CHARACTER_BYPASS_MUTANT
platformCharacterAccepted character =
  asciiAlphaNumeric character
    || platformHyphenAccepted character
    || platformUnderscoreAccepted character
    || character == '.'
#else
platformCharacterAccepted character =
  asciiAlphaNumeric character
    || platformHyphenAccepted character
    || platformUnderscoreAccepted character
#endif

platformHyphenAccepted :: Char -> Bool
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_PLATFORM_HYPHEN_ALTERNATIVE_DROP_MUTANT)
platformHyphenAccepted character = character `seq` False
#else
platformHyphenAccepted character = character == '-'
#endif

platformUnderscoreAccepted :: Char -> Bool
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_PLATFORM_UNDERSCORE_ALTERNATIVE_DROP_MUTANT)
platformUnderscoreAccepted character = character `seq` False
#else
platformUnderscoreAccepted character = character == '_'
#endif

packageNameText :: Text -> Bool
packageNameText value =
  boundedSemanticText value
    && all packageNameSegmentAccepted (Text.splitOn "-" value)

packageNameSegmentAccepted :: Text -> Bool
packageNameSegmentAccepted segment =
  packageNameSegmentNonEmpty segment && Text.all packageNameCharacterAccepted segment

packageNameSegmentNonEmpty :: Text -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_NAME_SEGMENT_BYPASS_MUTANT
packageNameSegmentNonEmpty _ = True
#else
packageNameSegmentNonEmpty = not . Text.null
#endif

packageNameCharacterAccepted :: Char -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_NAME_CHARACTER_BYPASS_MUTANT
packageNameCharacterAccepted character = asciiAlphaNumeric character || character == '_'
#else
packageNameCharacterAccepted = asciiAlphaNumeric
#endif

packageVersionText :: Text -> Bool
packageVersionText value =
  boundedSemanticText value
    && all packageVersionSegmentAccepted (Text.splitOn "." value)

packageVersionSegmentAccepted :: Text -> Bool
packageVersionSegmentAccepted segment =
  packageVersionSegmentNonEmpty segment && Text.all packageVersionDigitAccepted segment

packageVersionSegmentNonEmpty :: Text -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_VERSION_SEGMENT_BYPASS_MUTANT
packageVersionSegmentNonEmpty _ = True
#else
packageVersionSegmentNonEmpty = not . Text.null
#endif

packageVersionDigitAccepted :: Char -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_VERSION_DIGIT_BYPASS_MUTANT
packageVersionDigitAccepted character =
  (character >= '0' && character <= '9') || character == 'x'
#else
packageVersionDigitAccepted character = character >= '0' && character <= '9'
#endif

flagNameText :: Text -> Bool
flagNameText value =
  boundedSemanticText value
    && flagBoundaryAccepted value
    && Text.all flagCharacterAccepted value

flagBoundaryAccepted :: Text -> Bool
flagBoundaryAccepted value =
  flagLeadingBoundaryAccepted value && flagTrailingBoundaryAccepted value

flagLeadingBoundaryAccepted :: Text -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_FLAG_LEADING_BOUNDARY_BYPASS_MUTANT
flagLeadingBoundaryAccepted = not . Text.null
#else
flagLeadingBoundaryAccepted value = maybe False (asciiAlphaNumeric . fst) (Text.uncons value)
#endif

flagTrailingBoundaryAccepted :: Text -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_FLAG_TRAILING_BOUNDARY_BYPASS_MUTANT
flagTrailingBoundaryAccepted = not . Text.null
#else
flagTrailingBoundaryAccepted value = maybe False (asciiAlphaNumeric . snd) (Text.unsnoc value)
#endif

flagCharacterAccepted :: Char -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_FLAG_CHARACTER_BYPASS_MUTANT
flagCharacterAccepted character =
  asciiAlphaNumeric character
    || flagHyphenAccepted character
    || flagUnderscoreAccepted character
    || character == '.'
#else
flagCharacterAccepted character =
  asciiAlphaNumeric character
    || flagHyphenAccepted character
    || flagUnderscoreAccepted character
#endif

flagHyphenAccepted :: Char -> Bool
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_FLAG_HYPHEN_ALTERNATIVE_DROP_MUTANT)
flagHyphenAccepted character = character `seq` False
#else
flagHyphenAccepted character = character == '-'
#endif

flagUnderscoreAccepted :: Char -> Bool
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_FLAG_UNDERSCORE_ALTERNATIVE_DROP_MUTANT)
flagUnderscoreAccepted character = character `seq` False
#else
flagUnderscoreAccepted character = character == '_'
#endif

secureLocatorText :: Text -> Bool
secureLocatorText value =
  not (sourceByteLimitExceeded (textByteLength value))
    && secureLocatorSchemeAccepted value
    && secureLocatorPayloadAccepted value
    && Text.all secureLocatorLowerBoundAccepted value
    && Text.all secureLocatorUpperBoundAccepted value
    && Text.all secureLocatorBackslashAccepted value

secureLocatorSchemeAccepted :: Text -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_SCHEME_BYPASS_MUTANT
secureLocatorSchemeAccepted value =
  Text.isPrefixOf "https://" value || Text.isPrefixOf "http://" value
#else
secureLocatorSchemeAccepted = Text.isPrefixOf "https://"
#endif

secureLocatorPayloadAccepted :: Text -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_PAYLOAD_BYPASS_MUTANT
secureLocatorPayloadAccepted _ = True
#else
secureLocatorPayloadAccepted value = Text.length value > Text.length "https://"
#endif

secureLocatorLowerBoundAccepted :: Char -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_LOWER_BOUND_BYPASS_MUTANT
secureLocatorLowerBoundAccepted character = ord character >= 32
#else
secureLocatorLowerBoundAccepted character = ord character >= 33
#endif

secureLocatorUpperBoundAccepted :: Char -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_UPPER_BOUND_BYPASS_MUTANT
secureLocatorUpperBoundAccepted character = ord character <= 255
#else
secureLocatorUpperBoundAccepted character = ord character <= 126
#endif

secureLocatorBackslashAccepted :: Char -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_BACKSLASH_BYPASS_MUTANT
secureLocatorBackslashAccepted _ = True
#else
secureLocatorBackslashAccepted character = character /= '\\'
#endif

boundedSemanticText :: Text -> Bool
boundedSemanticText value =
  not (semanticByteLimitExceeded (textByteLength value))

asciiAlphaNumeric :: Char -> Bool
asciiAlphaNumeric character =
  asciiLowercaseAccepted character
    || asciiUppercaseAccepted character
    || asciiDigitAccepted character

asciiLowercaseAccepted :: Char -> Bool
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_ASCII_LOWERCASE_ALTERNATIVE_DROP_MUTANT)
asciiLowercaseAccepted character = character `seq` False
#else
asciiLowercaseAccepted character = character >= 'a' && character <= 'z'
#endif

asciiUppercaseAccepted :: Char -> Bool
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_ASCII_UPPERCASE_ALTERNATIVE_DROP_MUTANT)
asciiUppercaseAccepted character = character `seq` False
#else
asciiUppercaseAccepted character = character >= 'A' && character <= 'Z'
#endif

asciiDigitAccepted :: Char -> Bool
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_ASCII_DIGIT_ALTERNATIVE_DROP_MUTANT)
asciiDigitAccepted character = character `seq` False
#else
asciiDigitAccepted character = character >= '0' && character <= '9'
#endif

pathTextAccepted :: Text -> Bool
pathTextAccepted value =
  not (pathByteLimitExceeded (textByteLength value))
    && pathAbsoluteAccepted value
    && Text.all pathLowerBoundAccepted value
    && Text.all pathUpperBoundAccepted value
    && Text.all pathBackslashAccepted value
    && Text.all pathColonAccepted value
    && validSegments
 where
  segments = Text.splitOn "/" (Text.drop 1 value)
  nonRootSegments = if segments == [""] then [] else segments
  validSegments =
    not (pathSegmentLimitExceeded (length nonRootSegments))
      && and
        [ pathSegmentNonEmpty segment
            && not (pathSegmentByteLimitExceeded (textByteLength segment))
            && pathParentSegmentAccepted segment
            && pathDotSegmentAccepted index (length nonRootSegments) segment
        | (index, segment) <- zip [0 :: Int ..] nonRootSegments
        ]

pathAbsoluteAccepted :: Text -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_PATH_ABSOLUTE_BYPASS_MUTANT
pathAbsoluteAccepted _ = True
#else
pathAbsoluteAccepted = Text.isPrefixOf "/"
#endif

pathLowerBoundAccepted :: Char -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_PATH_LOWER_BOUND_BYPASS_MUTANT
pathLowerBoundAccepted character = ord character >= 32
#else
pathLowerBoundAccepted character = ord character >= 33
#endif

pathUpperBoundAccepted :: Char -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_PATH_UPPER_BOUND_BYPASS_MUTANT
pathUpperBoundAccepted character = ord character <= 255
#else
pathUpperBoundAccepted character = ord character <= 126
#endif

pathBackslashAccepted :: Char -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_PATH_BACKSLASH_BYPASS_MUTANT
pathBackslashAccepted _ = True
#else
pathBackslashAccepted character = character /= '\\'
#endif

pathColonAccepted :: Char -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_PATH_COLON_BYPASS_MUTANT
pathColonAccepted _ = True
#else
pathColonAccepted character = character /= ':'
#endif

pathSegmentNonEmpty :: Text -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_PATH_EMPTY_SEGMENT_BYPASS_MUTANT
pathSegmentNonEmpty _ = True
#else
pathSegmentNonEmpty = not . Text.null
#endif

pathParentSegmentAccepted :: Text -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_PATH_PARENT_SEGMENT_BYPASS_MUTANT
pathParentSegmentAccepted _ = True
#else
pathParentSegmentAccepted segment = segment /= ".."
#endif

pathDotSegmentAccepted :: Int -> Int -> Text -> Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_PATH_DOT_POSITION_BYPASS_MUTANT
pathDotSegmentAccepted _ _ _ = True
#else
pathDotSegmentAccepted index segmentCount segment =
  segment /= "." || index == segmentCount - 1
#endif

textByteLength :: Text -> Int
textByteLength = ByteString.length . TextEncoding.encodeUtf8

packageSourceKind :: PackageSource -> Text
packageSourceKind source = case source of
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_PRE_EXISTING_SOURCE_KIND_MAPPING_MUTANT)
  PreExistingPackageSource -> "mutated-pre-existing"
#else
  PreExistingPackageSource -> "pre-existing"
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_KIND_MAPPING_MUTANT)
  LocalPackageSource _ -> "mutated-local"
#else
  LocalPackageSource _ -> "local"
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TAR_SOURCE_KIND_MAPPING_MUTANT)
  RepositoryTarPackageSource _ _ -> "mutated-repo-tar"
#else
  RepositoryTarPackageSource _ _ -> "repo-tar"
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_REPOSITORY_SOURCE_KIND_MAPPING_MUTANT)
  SourceRepositoryPackageSource _ _ _ -> "mutated-source-repo"
#else
  SourceRepositoryPackageSource _ _ _ -> "source-repo"
#endif

foldDiagnosticCompilerElaboratedPlanRefusal
  :: DiagnosticCompilerElaboratedPlanRefusal
  -> (Maybe Text -> Int -> NonEmpty CompilerElaboratedPlanProblem -> result)
  -> ( Maybe Text
       -> Int
       -> NonEmpty CompilerElaboratedPlanProblem
       -> Text
       -> Text
       -> Text
       -> Text
       -> Text
       -> Text
       -> [DiagnosticElaboratedUnit]
       -> result
     )
  -> result
foldDiagnosticCompilerElaboratedPlanRefusal
  (DiagnosticCompilerElaboratedPlanRefusal digest inputBytes problems Nothing)
  onMalformed
  _ =
    onMalformed
      (projectMalformedFoldDigest digest)
      (projectMalformedFoldInputBytes inputBytes)
      (projectMalformedFoldProblems problems)
foldDiagnosticCompilerElaboratedPlanRefusal
  ( DiagnosticCompilerElaboratedPlanRefusal
      digest
      inputBytes
      problems
      ( Just
          ( DiagnosticCompilerElaboratedPlanSnapshot
              cabalVersion
              cabalLibraryVersion
              compilerId
              compilerAbi
              operatingSystem
              architecture
              units
            )
        )
    )
  _
  onObserved =
    onObserved
      (projectObservedFoldDigest digest)
      (projectObservedFoldInputBytes inputBytes)
      (projectObservedFoldProblems problems)
      (projectObservedFoldCabalVersion cabalVersion)
      (projectObservedFoldCabalLibraryVersion cabalLibraryVersion)
      (projectObservedFoldCompilerId compilerId)
      (projectObservedFoldCompilerAbi compilerAbi)
      (projectObservedFoldOperatingSystem operatingSystem)
      (projectObservedFoldArchitecture architecture)
      (projectObservedFoldUnits units)

projectMalformedFoldDigest :: Maybe Text -> Maybe Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_MALFORMED_FOLD_DIGEST_PROJECTION_MUTANT)
projectMalformedFoldDigest digest = digest `seq` Nothing
#else
projectMalformedFoldDigest = id
#endif

projectMalformedFoldInputBytes :: Int -> Int
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_MALFORMED_FOLD_INPUT_BYTES_PROJECTION_MUTANT)
projectMalformedFoldInputBytes inputBytes = inputBytes `seq` (-1)
#else
projectMalformedFoldInputBytes = id
#endif

projectMalformedFoldProblems
  :: NonEmpty CompilerElaboratedPlanProblem
  -> NonEmpty CompilerElaboratedPlanProblem
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_MALFORMED_FOLD_PROBLEMS_PROJECTION_MUTANT)
projectMalformedFoldProblems = NonEmpty.fromList . reverse . NonEmpty.toList
#else
projectMalformedFoldProblems = id
#endif

projectObservedFoldDigest :: Maybe Text -> Maybe Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_DIGEST_PROJECTION_MUTANT)
projectObservedFoldDigest digest = digest `seq` Nothing
#else
projectObservedFoldDigest = id
#endif

projectObservedFoldInputBytes :: Int -> Int
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_INPUT_BYTES_PROJECTION_MUTANT)
projectObservedFoldInputBytes inputBytes = inputBytes `seq` (-2)
#else
projectObservedFoldInputBytes = id
#endif

projectObservedFoldProblems
  :: NonEmpty CompilerElaboratedPlanProblem
  -> NonEmpty CompilerElaboratedPlanProblem
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_PROBLEMS_PROJECTION_MUTANT)
projectObservedFoldProblems = NonEmpty.fromList . reverse . NonEmpty.toList
#else
projectObservedFoldProblems = id
#endif

projectObservedFoldCabalVersion :: Text -> Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_CABAL_VERSION_PROJECTION_MUTANT)
projectObservedFoldCabalVersion value = value `seq` "mutated-fold-cabal-version"
#else
projectObservedFoldCabalVersion = id
#endif

projectObservedFoldCabalLibraryVersion :: Text -> Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_CABAL_LIBRARY_VERSION_PROJECTION_MUTANT)
projectObservedFoldCabalLibraryVersion value = value `seq` "mutated-fold-cabal-library-version"
#else
projectObservedFoldCabalLibraryVersion = id
#endif

projectObservedFoldCompilerId :: Text -> Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_COMPILER_ID_PROJECTION_MUTANT)
projectObservedFoldCompilerId value = value `seq` "mutated-fold-compiler-id"
#else
projectObservedFoldCompilerId = id
#endif

projectObservedFoldCompilerAbi :: Text -> Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_COMPILER_ABI_PROJECTION_MUTANT)
projectObservedFoldCompilerAbi value = value `seq` "mutated-fold-compiler-abi"
#else
projectObservedFoldCompilerAbi = id
#endif

projectObservedFoldOperatingSystem :: Text -> Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_OPERATING_SYSTEM_PROJECTION_MUTANT)
projectObservedFoldOperatingSystem value = value `seq` "mutated-fold-operating-system"
#else
projectObservedFoldOperatingSystem = id
#endif

projectObservedFoldArchitecture :: Text -> Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_ARCHITECTURE_PROJECTION_MUTANT)
projectObservedFoldArchitecture value = value `seq` "mutated-fold-architecture"
#else
projectObservedFoldArchitecture = id
#endif

projectObservedFoldUnits :: [DiagnosticElaboratedUnit] -> [DiagnosticElaboratedUnit]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_UNIT_ORDER_MUTANT)
projectObservedFoldUnits = reverse
#else
projectObservedFoldUnits = id
#endif

singleProblemRefusal
  :: Maybe Text
  -> Int
  -> CompilerElaboratedPlanProblem
  -> DiagnosticCompilerElaboratedPlanRefusal
singleProblemRefusal digest inputBytes problem =
  DiagnosticCompilerElaboratedPlanRefusal
    (projectRefusalDigest digest)
    (projectRefusalInputBytes inputBytes)
    (projectRefusalProblems (problem :| []))
    (projectRefusalSnapshot Nothing)

hardRefusal
  :: Maybe Text
  -> Int
  -> [CompilerElaboratedPlanProblem]
  -> DiagnosticCompilerElaboratedPlanRefusal
hardRefusal digest inputBytes problems =
  DiagnosticCompilerElaboratedPlanRefusal
    (projectRefusalDigest digest)
    (projectRefusalInputBytes inputBytes)
    (projectRefusalProblems (boundedProblemSet "hard-refusal" problems))
    (projectRefusalSnapshot Nothing)

observedRefusal
  :: Maybe Text
  -> Int
  -> [CompilerElaboratedPlanProblem]
  -> [CompilerElaboratedPlanProblem]
  -> DiagnosticCompilerElaboratedPlanSnapshot
  -> DiagnosticCompilerElaboratedPlanRefusal
observedRefusal digest inputBytes mandatoryProblems variableProblems snapshot =
  DiagnosticCompilerElaboratedPlanRefusal
    (projectRefusalDigest digest)
    (projectRefusalInputBytes inputBytes)
    (projectRefusalProblems (boundedObservedProblemSet mandatoryProblems variableProblems))
    (projectRefusalSnapshot (Just snapshot))

projectRefusalDigest :: Maybe Text -> Maybe Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_REFUSAL_DIGEST_PROJECTION_MUTANT)
projectRefusalDigest digest = digest `seq` Nothing
#else
projectRefusalDigest = id
#endif

projectRefusalInputBytes :: Int -> Int
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_REFUSAL_INPUT_BYTES_PROJECTION_MUTANT)
projectRefusalInputBytes = const 0
#else
projectRefusalInputBytes = id
#endif

projectRefusalProblems :: NonEmpty CompilerElaboratedPlanProblem -> NonEmpty CompilerElaboratedPlanProblem
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_REFUSAL_PROBLEM_ORDER_MUTANT)
projectRefusalProblems = NonEmpty.fromList . reverse . NonEmpty.toList
#else
projectRefusalProblems = id
#endif

projectRefusalSnapshot :: Maybe DiagnosticCompilerElaboratedPlanSnapshot -> Maybe DiagnosticCompilerElaboratedPlanSnapshot
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_REFUSAL_SNAPSHOT_PROJECTION_DROP_MUTANT)
projectRefusalSnapshot snapshot = snapshot `seq` Nothing
#else
projectRefusalSnapshot = id
#endif

boundedObservedProblemSet
  :: [CompilerElaboratedPlanProblem]
  -> [CompilerElaboratedPlanProblem]
  -> NonEmpty CompilerElaboratedPlanProblem
boundedObservedProblemSet mandatoryProblems variableProblems =
  case NonEmpty.nonEmpty (retainedMandatoryProblems mandatoryProblems <> boundedObservedVariableProblems variableProblems) of
    Just nonEmpty -> nonEmpty
    Nothing -> CompilerElaboratedPlanDiagnosticInvariantRefused "observed-refusal" :| []

retainedMandatoryProblems
  :: [CompilerElaboratedPlanProblem]
  -> [CompilerElaboratedPlanProblem]
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_MANDATORY_PREFIX_DROP_MUTANT
retainedMandatoryProblems _ = []
#else
retainedMandatoryProblems = id
#endif

boundedObservedVariableProblems
  :: [CompilerElaboratedPlanProblem]
  -> [CompilerElaboratedPlanProblem]
boundedObservedVariableProblems problems =
  case splitAt observedVariableProblemLimit problems of
    (bounded, []) -> bounded
    (_, _ : _) ->
      [ PlanResourceLimitExceeded
          "observed-variable-problems"
          compilerElaboratedPlanMaximumObservedVariableProblems
          (observedVariableProblemLimit + 1)
      ]

observedVariableProblemLimit :: Int
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_RESULT_PROBLEM_LIMIT_BYPASS_MUTANT
observedVariableProblemLimit = compilerElaboratedPlanMaximumObservedVariableProblems + 1
#else
observedVariableProblemLimit = compilerElaboratedPlanMaximumObservedVariableProblems
#endif

boundedProblemSet
  :: Text
  -> [CompilerElaboratedPlanProblem]
  -> NonEmpty CompilerElaboratedPlanProblem
boundedProblemSet label problems =
  case NonEmpty.nonEmpty (boundedProblemList problems) of
    Just nonEmpty -> nonEmpty
    Nothing -> CompilerElaboratedPlanDiagnosticInvariantRefused label :| []

boundedProblemList
  :: [CompilerElaboratedPlanProblem]
  -> [CompilerElaboratedPlanProblem]
boundedProblemList problems =
  case splitAt semanticProblemLimit problems of
    (bounded, []) -> projectBoundedProblemOrder bounded
    (_, _ : _) ->
      [ PlanResourceLimitExceeded
          "problems"
          compilerElaboratedPlanMaximumSemanticProblems
          (semanticProblemLimit + 1)
      ]

projectBoundedProblemOrder :: [CompilerElaboratedPlanProblem] -> [CompilerElaboratedPlanProblem]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_BOUNDED_PROBLEM_ORDER_MUTANT)
projectBoundedProblemOrder = reverse
#else
projectBoundedProblemOrder = id
#endif

sha256Text :: ByteString -> Text
sha256Text bytes =
  Text.pack
    ( concatMap renderOctet
        (ByteString.unpack (SHA256.hash (projectSha256Input bytes)))
    )
 where
  renderOctet octet =
    [ hexDigit (sha256HighNibble (fromIntegral octet))
    , hexDigit (sha256LowNibble (fromIntegral octet))
    ]

  sha256HighNibble :: Int -> Int
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_SHA256_HIGH_NIBBLE_MAPPING_MUTANT)
  sha256HighNibble value = value `seq` 0
#else
  sha256HighNibble value = value `div` 16
#endif

  sha256LowNibble :: Int -> Int
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_SHA256_LOW_NIBBLE_MAPPING_MUTANT)
  sha256LowNibble value = value `seq` 0
#else
  sha256LowNibble value = value `mod` 16
#endif

  hexDigit :: Int -> Char
  hexDigit value
    | value < 10 = toEnum (fromEnum '0' + value)
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_SHA256_HEX_ALPHA_MAPPING_MUTANT)
    | otherwise = toEnum (fromEnum 'f' - value + 10)
#else
    | otherwise = toEnum (fromEnum 'a' + value - 10)
#endif

projectSha256Input :: ByteString -> ByteString
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_SHA256_INPUT_ROUTE_MUTANT)
projectSha256Input bytes = bytes `seq` ByteString.empty
#else
projectSha256Input = id
#endif

diagnosticElaboratedUnitOrigin :: DiagnosticElaboratedUnit -> DiagnosticElaboratedUnitOrigin
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_ORIGIN_PROJECTION_MUTANT)
diagnosticElaboratedUnitOrigin unit = unit `seq` RemoteUnit
#else
diagnosticElaboratedUnitOrigin (DiagnosticElaboratedUnit value _ _ _ _ _ _ _ _ _ _ _ _ _ _) = value
#endif

diagnosticElaboratedUnitBuildStyle :: DiagnosticElaboratedUnit -> DiagnosticElaboratedUnitBuildStyle
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_BUILD_STYLE_PROJECTION_MUTANT)
diagnosticElaboratedUnitBuildStyle unit = unit `seq` GlobalBuildStyle
#else
diagnosticElaboratedUnitBuildStyle (DiagnosticElaboratedUnit _ value _ _ _ _ _ _ _ _ _ _ _ _ _) = value
#endif

diagnosticElaboratedUnitId :: DiagnosticElaboratedUnit -> Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_ID_PROJECTION_MUTANT)
diagnosticElaboratedUnitId unit = unit `seq` "mutated-unit-id"
#else
diagnosticElaboratedUnitId (DiagnosticElaboratedUnit _ _ value _ _ _ _ _ _ _ _ _ _ _ _) = value
#endif

diagnosticElaboratedUnitPackageName :: DiagnosticElaboratedUnit -> Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_PACKAGE_NAME_PROJECTION_MUTANT)
diagnosticElaboratedUnitPackageName unit = unit `seq` "mutated-package"
#else
diagnosticElaboratedUnitPackageName (DiagnosticElaboratedUnit _ _ _ value _ _ _ _ _ _ _ _ _ _ _) = value
#endif

diagnosticElaboratedUnitPackageVersion :: DiagnosticElaboratedUnit -> Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_PACKAGE_VERSION_PROJECTION_MUTANT)
diagnosticElaboratedUnitPackageVersion unit = unit `seq` "0"
#else
diagnosticElaboratedUnitPackageVersion (DiagnosticElaboratedUnit _ _ _ _ value _ _ _ _ _ _ _ _ _ _) = value
#endif

diagnosticElaboratedUnitPackageSourceKind :: DiagnosticElaboratedUnit -> Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_SOURCE_KIND_PROJECTION_MUTANT)
diagnosticElaboratedUnitPackageSourceKind unit = unit `seq` "mutated-source-kind"
#else
diagnosticElaboratedUnitPackageSourceKind (DiagnosticElaboratedUnit _ _ _ _ _ source _ _ _ _ _ _ _ _ _) = packageSourceKind source
#endif

diagnosticElaboratedUnitPackageSourceRoot :: DiagnosticElaboratedUnit -> Maybe FilePath
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_SOURCE_ROOT_PROJECTION_MUTANT)
diagnosticElaboratedUnitPackageSourceRoot unit = unit `seq` Just "/mutated/root"
#else
diagnosticElaboratedUnitPackageSourceRoot (DiagnosticElaboratedUnit _ _ _ _ _ source _ _ _ _ _ _ _ _ _) = case source of
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_ROOT_LOCAL_MAPPING_MUTANT)
  LocalPackageSource root -> root `seq` Nothing
#else
  LocalPackageSource root -> Just root
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_ROOT_ABSENT_MAPPING_MUTANT)
  _ -> Just "/mutated/absent-root"
#else
  _ -> Nothing
#endif
#endif

diagnosticElaboratedUnitPackageSourceLocation :: DiagnosticElaboratedUnit -> Maybe Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_SOURCE_LOCATION_PROJECTION_MUTANT)
diagnosticElaboratedUnitPackageSourceLocation unit = unit `seq` Just "https://mutated.invalid"
#else
diagnosticElaboratedUnitPackageSourceLocation (DiagnosticElaboratedUnit _ _ _ _ _ source _ _ _ _ _ _ _ _ _) = case source of
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_LOCATION_REPOSITORY_TAR_MAPPING_MUTANT)
  RepositoryTarPackageSource _ uri -> uri `seq` Just "https://mutated.invalid/repo-tar"
#else
  RepositoryTarPackageSource _ uri -> Just uri
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_LOCATION_SOURCE_REPOSITORY_MAPPING_MUTANT)
  SourceRepositoryPackageSource _ location _ -> location `seq` Just "https://mutated.invalid/source-repo"
#else
  SourceRepositoryPackageSource _ location _ -> Just location
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_LOCATION_ABSENT_MAPPING_MUTANT)
  _ -> Just "https://mutated.invalid/absent-location"
#else
  _ -> Nothing
#endif
#endif

diagnosticElaboratedUnitPackageSourceTag :: DiagnosticElaboratedUnit -> Maybe Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_SOURCE_TAG_PROJECTION_MUTANT)
diagnosticElaboratedUnitPackageSourceTag unit = unit `seq` Just "mutated-tag"
#else
diagnosticElaboratedUnitPackageSourceTag (DiagnosticElaboratedUnit _ _ _ _ _ source _ _ _ _ _ _ _ _ _) = case source of
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_TAG_SOURCE_REPOSITORY_MAPPING_MUTANT)
  SourceRepositoryPackageSource _ _ tag -> tag `seq` Just "mutated-tag"
#else
  SourceRepositoryPackageSource _ _ tag -> Just tag
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_TAG_ABSENT_MAPPING_MUTANT)
  _ -> Just "mutated-absent-tag"
#else
  _ -> Nothing
#endif
#endif

diagnosticElaboratedUnitFlags :: DiagnosticElaboratedUnit -> [(Text, Bool)]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_FLAGS_PROJECTION_MUTANT)
diagnosticElaboratedUnitFlags unit = unit `seq` [("mutated", True)]
#else
diagnosticElaboratedUnitFlags (DiagnosticElaboratedUnit _ _ _ _ _ _ flags _ _ _ _ _ _ _ _) = flags
#endif

diagnosticElaboratedUnitComponents :: DiagnosticElaboratedUnit -> [DiagnosticElaboratedComponent]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_COMPONENTS_PROJECTION_DROP_MUTANT)
diagnosticElaboratedUnitComponents unit = unit `seq` []
#else
diagnosticElaboratedUnitComponents (DiagnosticElaboratedUnit _ _ _ _ _ _ _ components _ _ _ _ _ _ _) = components
#endif

diagnosticElaboratedUnitComponentShape
  :: DiagnosticElaboratedUnit
  -> Maybe DiagnosticElaboratedComponentShape
diagnosticElaboratedUnitComponentShape
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_COMPONENT_SHAPE_PROJECTION_MUTANT)
  unit = unit `seq` Just AggregateElaboratedComponentShape
#else
  (DiagnosticElaboratedUnit _ _ _ _ _ _ _ _ shape _ _ _ _ _ _) = shape
#endif

diagnosticElaboratedUnitDependencyUnitIds :: DiagnosticElaboratedUnit -> [Text]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_DEPENDENCIES_PROJECTION_DROP_MUTANT)
diagnosticElaboratedUnitDependencyUnitIds unit = unit `seq` []
#else
diagnosticElaboratedUnitDependencyUnitIds (DiagnosticElaboratedUnit _ _ _ _ _ _ _ _ _ dependencies _ _ _ _ _) = dependencies
#endif

diagnosticElaboratedUnitPackageCabalSha256 :: DiagnosticElaboratedUnit -> Maybe Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_CABAL_SHA256_PROJECTION_MUTANT)
diagnosticElaboratedUnitPackageCabalSha256 unit = unit `seq` Just "mutated-cabal-sha256"
#else
diagnosticElaboratedUnitPackageCabalSha256 (DiagnosticElaboratedUnit _ _ _ _ _ _ _ _ _ _ value _ _ _ _) = value
#endif

diagnosticElaboratedUnitPackageSourceSha256 :: DiagnosticElaboratedUnit -> Maybe Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_SOURCE_SHA256_PROJECTION_MUTANT)
diagnosticElaboratedUnitPackageSourceSha256 unit = unit `seq` Just "mutated-source-sha256"
#else
diagnosticElaboratedUnitPackageSourceSha256 (DiagnosticElaboratedUnit _ _ _ _ _ _ _ _ _ _ _ value _ _ _) = value
#endif

diagnosticElaboratedUnitBuildInfoPath :: DiagnosticElaboratedUnit -> Maybe FilePath
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_BUILD_INFO_PATH_PROJECTION_MUTANT)
diagnosticElaboratedUnitBuildInfoPath unit = unit `seq` Just "/mutated/build-info"
#else
diagnosticElaboratedUnitBuildInfoPath (DiagnosticElaboratedUnit _ _ _ _ _ _ _ _ _ _ _ _ value _ _) = value
#endif

diagnosticElaboratedUnitDistDirectoryPath :: DiagnosticElaboratedUnit -> Maybe FilePath
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_DIST_DIRECTORY_PATH_PROJECTION_MUTANT)
diagnosticElaboratedUnitDistDirectoryPath unit = unit `seq` Just "/mutated/dist"
#else
diagnosticElaboratedUnitDistDirectoryPath (DiagnosticElaboratedUnit _ _ _ _ _ _ _ _ _ _ _ _ _ value _) = value
#endif

diagnosticElaboratedUnitBinaryPath :: DiagnosticElaboratedUnit -> Maybe FilePath
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_BINARY_PATH_PROJECTION_MUTANT)
diagnosticElaboratedUnitBinaryPath unit = unit `seq` Just "/mutated/binary"
#else
diagnosticElaboratedUnitBinaryPath (DiagnosticElaboratedUnit _ _ _ _ _ _ _ _ _ _ _ _ _ _ value) = value
#endif

diagnosticElaboratedUnitRepositoryType :: DiagnosticElaboratedUnit -> Maybe Text
diagnosticElaboratedUnitRepositoryType (DiagnosticElaboratedUnit _ _ _ _ _ source _ _ _ _ _ _ _ _ _) =
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_REPOSITORY_TYPE_PROJECTION_MUTANT)
  source `seq` Just "mutated-repository-type"
#else
  case source of
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TYPE_REPOSITORY_TAR_MAPPING_MUTANT)
    RepositoryTarPackageSource repositoryType _ -> repositoryType `seq` Just "mutated-repo-tar-type"
#else
    RepositoryTarPackageSource repositoryType _ -> Just repositoryType
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TYPE_SOURCE_REPOSITORY_MAPPING_MUTANT)
    SourceRepositoryPackageSource repositoryType _ _ -> repositoryType `seq` Just "mutated-source-repo-type"
#else
    SourceRepositoryPackageSource repositoryType _ _ -> Just repositoryType
#endif
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TYPE_ABSENT_MAPPING_MUTANT)
    _ -> Just "mutated-absent-repository-type"
#else
    _ -> Nothing
#endif
#endif

diagnosticElaboratedComponentUnitId :: DiagnosticElaboratedComponent -> Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNIT_ID_PROJECTION_MUTANT)
diagnosticElaboratedComponentUnitId component = component `seq` "mutated-component-unit"
#else
diagnosticElaboratedComponentUnitId (DiagnosticElaboratedComponent value _ _ _ _) = value
#endif

diagnosticElaboratedComponentName :: DiagnosticElaboratedComponent -> Text
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_NAME_PROJECTION_MUTANT)
diagnosticElaboratedComponentName component = component `seq` "mutated-component"
#else
diagnosticElaboratedComponentName (DiagnosticElaboratedComponent _ value _ _ _) = value
#endif

diagnosticElaboratedComponentDependencyUnitIds :: DiagnosticElaboratedComponent -> [Text]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_DEPENDENCIES_PROJECTION_DROP_MUTANT)
diagnosticElaboratedComponentDependencyUnitIds component = component `seq` []
#else
diagnosticElaboratedComponentDependencyUnitIds (DiagnosticElaboratedComponent _ _ value _ _) = value
#endif

diagnosticElaboratedComponentExecutableDependencyUnitIds :: DiagnosticElaboratedComponent -> [Text]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_EXECUTABLE_DEPENDENCIES_PROJECTION_MUTANT)
diagnosticElaboratedComponentExecutableDependencyUnitIds component = component `seq` ["mutated-executable-dependency"]
#else
diagnosticElaboratedComponentExecutableDependencyUnitIds (DiagnosticElaboratedComponent _ _ _ value _) = value
#endif

diagnosticElaboratedComponentSourcePaths :: DiagnosticElaboratedComponent -> Maybe [FilePath]
#if defined(VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_SOURCE_PATHS_PROJECTION_MUTANT)
diagnosticElaboratedComponentSourcePaths component = component `seq` Just ["/mutated/source.hs"]
#else
diagnosticElaboratedComponentSourcePaths (DiagnosticElaboratedComponent _ _ _ _ value) = value
#endif
