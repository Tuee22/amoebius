{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.CompilerBuildInfo.Internal
  ( compilerBuildInfoDiagnostic
  ) where

-- Cabal build-info bytes are useful only as a diagnostic join.  Every public
-- result from this module is converted immediately to an always-refusing
-- CheckResult.  The parser, snapshot, refusal, observations, and their folds are
-- private: callers cannot project an accepted-looking value or convert one to
-- evidence.

import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding (..)
  , Observation (..)
  , finding
  , observation
  )
import Data.Aeson (Object, Value (..), eitherDecodeStrict')
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Char (ord)
import Data.List (group, sort, sortOn)
import Data.List.NonEmpty (NonEmpty (..))
import Data.List.NonEmpty qualified as NonEmpty
import Data.Map.Strict qualified as Map
import Data.Maybe (mapMaybe)
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Word (Word8)

supportedCompilerBuildInfoCabalLibraryVersion :: Text
#ifdef VALIDATION_COMPILER_BUILDINFO_CABAL_VERSION_MUTANT
supportedCompilerBuildInfoCabalLibraryVersion = "3.16.1.1"
#else
supportedCompilerBuildInfoCabalLibraryVersion = "3.16.1.0"
#endif

maximumBuildInfoBytes, maximumJsonStructuralTokens :: Int
#ifdef VALIDATION_COMPILER_BUILDINFO_INPUT_LIMIT_WIDEN_MUTANT
maximumBuildInfoBytes = 1048577
#else
maximumBuildInfoBytes = 1048576
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_STRUCTURAL_TOKEN_LIMIT_WIDEN_MUTANT
maximumJsonStructuralTokens = 65537
#else
maximumJsonStructuralTokens = 65536
#endif

maximumJsonDepth, maximumJsonStringBytes, maximumJsonScalarBytes :: Int
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_DEPTH_LIMIT_WIDEN_MUTANT
maximumJsonDepth = 17
#else
maximumJsonDepth = 16
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_STRING_LIMIT_WIDEN_MUTANT
maximumJsonStringBytes = 4097
#else
maximumJsonStringBytes = 4096
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_SCALAR_LIMIT_WIDEN_MUTANT
maximumJsonScalarBytes = 4097
#else
maximumJsonScalarBytes = 4096
#endif

maximumJsonObjectMembers, maximumJsonArrayElements :: Int
#ifdef VALIDATION_COMPILER_BUILDINFO_OBJECT_MEMBER_LIMIT_WIDEN_MUTANT
maximumJsonObjectMembers = 65
#else
maximumJsonObjectMembers = 64
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_GENERIC_ARRAY_LIMIT_WIDEN_MUTANT
maximumJsonArrayElements = 8193
#else
maximumJsonArrayElements = 8192
#endif

maximumBuildInfoComponents :: Int
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPONENT_LIMIT_WIDEN_MUTANT
maximumBuildInfoComponents = 513
#else
maximumBuildInfoComponents = 512
#endif

maximumCompilerArgumentArrayElements, maximumModuleArrayElements :: Int
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_ARRAY_LIMIT_WIDEN_MUTANT
maximumCompilerArgumentArrayElements = 4097
#else
maximumCompilerArgumentArrayElements = 4096
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_MODULE_ARRAY_LIMIT_WIDEN_MUTANT
maximumModuleArrayElements = 4097
#else
maximumModuleArrayElements = 4096
#endif

maximumSourceFileArrayElements, maximumSourceDirectoryArrayElements :: Int
#ifdef VALIDATION_COMPILER_BUILDINFO_SOURCE_FILE_ARRAY_LIMIT_WIDEN_MUTANT
maximumSourceFileArrayElements = 4097
#else
maximumSourceFileArrayElements = 4096
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_SOURCE_DIR_ARRAY_LIMIT_WIDEN_MUTANT
maximumSourceDirectoryArrayElements = 4097
#else
maximumSourceDirectoryArrayElements = 4096
#endif

maximumExpectedIdentities, maximumDiagnosticProblems :: Int
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_IDENTITY_LIMIT_WIDEN_MUTANT
maximumExpectedIdentities = 513
#else
maximumExpectedIdentities = 512
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_LIMIT_WIDEN_MUTANT
maximumDiagnosticProblems = 257
#else
maximumDiagnosticProblems = 256
#endif

maximumPathDepth, maximumPathSegmentBytes, maximumIdentityBytes :: Int
#ifdef VALIDATION_COMPILER_BUILDINFO_PATH_DEPTH_LIMIT_WIDEN_MUTANT
maximumPathDepth = 65
#else
maximumPathDepth = 64
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_PATH_SEGMENT_LIMIT_WIDEN_MUTANT
maximumPathSegmentBytes = 256
#else
maximumPathSegmentBytes = 255
#endif
maximumIdentityBytes = 512

maximumCallerCompilerFlavourBytes, maximumCallerCompilerIdBytes,
  maximumExpectedIdentityTypeBytes, maximumExpectedIdentityNameBytes,
  maximumExpectedIdentityUnitBytes, maximumObservedCompilerIdBytes,
  maximumObservedComponentNameBytes, maximumObservedComponentUnitBytes,
  maximumCompilerArgumentUnitBytes, maximumObservedModuleNameBytes :: Int
#ifdef VALIDATION_COMPILER_BUILDINFO_CALLER_COMPILER_FLAVOUR_LIMIT_WIDEN_MUTANT
maximumCallerCompilerFlavourBytes = 513
#else
maximumCallerCompilerFlavourBytes = maximumIdentityBytes
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_CALLER_COMPILER_ID_LIMIT_WIDEN_MUTANT
maximumCallerCompilerIdBytes = 513
#else
maximumCallerCompilerIdBytes = maximumIdentityBytes
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_IDENTITY_TYPE_LIMIT_WIDEN_MUTANT
maximumExpectedIdentityTypeBytes = 513
#else
maximumExpectedIdentityTypeBytes = maximumIdentityBytes
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_IDENTITY_NAME_LIMIT_WIDEN_MUTANT
maximumExpectedIdentityNameBytes = 513
#else
maximumExpectedIdentityNameBytes = maximumIdentityBytes
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_IDENTITY_LIMIT_WIDEN_MUTANT
maximumExpectedIdentityUnitBytes = 513
#else
maximumExpectedIdentityUnitBytes = maximumIdentityBytes
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_OBSERVED_COMPILER_ID_LIMIT_WIDEN_MUTANT
maximumObservedCompilerIdBytes = 513
#else
maximumObservedCompilerIdBytes = maximumIdentityBytes
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_OBSERVED_COMPONENT_NAME_LIMIT_WIDEN_MUTANT
maximumObservedComponentNameBytes = 513
#else
maximumObservedComponentNameBytes = maximumIdentityBytes
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_OBSERVED_COMPONENT_UNIT_LIMIT_WIDEN_MUTANT
maximumObservedComponentUnitBytes = 513
#else
maximumObservedComponentUnitBytes = maximumIdentityBytes
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_UNIT_LIMIT_WIDEN_MUTANT
maximumCompilerArgumentUnitBytes = 513
#else
maximumCompilerArgumentUnitBytes = maximumIdentityBytes
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_OBSERVED_MODULE_NAME_LIMIT_WIDEN_MUTANT
maximumObservedModuleNameBytes = 513
#else
maximumObservedModuleNameBytes = maximumIdentityBytes
#endif

maximumExpectedCompilerPathBytes :: Int
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_COMPILER_PATH_LIMIT_WIDEN_MUTANT
maximumExpectedCompilerPathBytes = 4097
#else
maximumExpectedCompilerPathBytes = 4096
#endif

maximumResultEntries, maximumResultPayloadBytes :: Int
#ifdef VALIDATION_COMPILER_BUILDINFO_RESULT_ENTRY_LIMIT_WIDEN_MUTANT
maximumResultEntries = 14878
#else
maximumResultEntries = 14877
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_RESULT_BYTE_LIMIT_WIDEN_MUTANT
maximumResultPayloadBytes = 2097153
#else
maximumResultPayloadBytes = 2097152
#endif

data DiagnosticCompilerBuildInfoExpectedCompiler
  = DiagnosticCompilerBuildInfoExpectedCompiler Text Text FilePath
  deriving (Eq, Ord, Show)

data DiagnosticCompilerBuildInfoExpectedIdentity
  = DiagnosticCompilerBuildInfoExpectedIdentity Text Text Text
  deriving (Eq, Ord, Show)

data DiagnosticCompilerBuildInfoExpectations
  = DiagnosticCompilerBuildInfoExpectations
      DiagnosticCompilerBuildInfoExpectedCompiler
      [DiagnosticCompilerBuildInfoExpectedIdentity]
  deriving (Eq, Ord, Show)

data DiagnosticCompilerBuildInfoComponentIdentity
  = DiagnosticCompilerBuildInfoComponentIdentity Text Text Text
  deriving (Eq, Ord, Show)

data DiagnosticCompilerBuildInfoArgumentObservation
  = DiagnosticCompilerBuildInfoBoundaryArgument Int Text
  | DiagnosticCompilerBuildInfoThisUnitArgument Int Text Int Text
  | DiagnosticCompilerBuildInfoPackageArgument Int Text Int Text
  | DiagnosticCompilerBuildInfoPathArgument Int Text (Maybe Int) Text FilePath
  | DiagnosticCompilerBuildInfoGeneratedInputArgument Int Text Int Text FilePath
  | DiagnosticCompilerBuildInfoStandaloneArgument Int Text
  | DiagnosticCompilerBuildInfoBypassedArgument Int Text
  deriving (Eq, Ord, Show)

data DiagnosticCompilerBuildInfoPathObservation
  = DiagnosticCompilerBuildInfoPathObservation Int Text (Maybe Int) FilePath
  deriving (Eq, Ord, Show)

data DiagnosticCompilerBuildInfoGeneratedInputObservation
  = DiagnosticCompilerBuildInfoGeneratedInputObservation Int Text Int Text FilePath
  deriving (Eq, Ord, Show)

data DiagnosticCompilerBuildInfoPackageObservation
  = DiagnosticCompilerBuildInfoPackageObservation Int Text Int Text
  deriving (Eq, Ord, Show)

data DiagnosticCompilerBuildInfoComponentObservation
  = DiagnosticCompilerBuildInfoComponentObservation
      DiagnosticCompilerBuildInfoComponentIdentity
      [DiagnosticCompilerBuildInfoArgumentObservation]
      [Text]
      [FilePath]
      [FilePath]
      FilePath
      (Maybe FilePath)
      [DiagnosticCompilerBuildInfoPathObservation]
      [DiagnosticCompilerBuildInfoGeneratedInputObservation]
      [DiagnosticCompilerBuildInfoPackageObservation]
  deriving (Eq, Ord, Show)

data DiagnosticCompilerBuildInfoSnapshot
  = DiagnosticCompilerBuildInfoSnapshot
      DiagnosticCompilerBuildInfoExpectations
      Text Text Text FilePath [DiagnosticCompilerBuildInfoComponentObservation]

data DiagnosticCompilerBuildInfoRefusal
  = DiagnosticCompilerBuildInfoRefusal
      (NonEmpty DiagnosticCompilerBuildInfoProblem)
      (Maybe DiagnosticCompilerBuildInfoSnapshot)

data DiagnosticCompilerBuildInfoProblem
  = BuildInfoResourceLimitExceeded Text Int Int
  | BuildInfoJsonDuplicateKey Text Text
  | BuildInfoDuplicateKeyScanFailed Text
  | BuildInfoRootNotObject
  | BuildInfoFieldMissing Text Text
  | BuildInfoFieldUnknown Text Text
  | BuildInfoFieldWrongType Text Text Text
  | BuildInfoArrayElementWrongType Text Text Int Text
  | BuildInfoTextEmpty Text Text
  | BuildInfoArrayTextEmpty Text Text Int
  | BuildInfoCabalLibraryVersionUnsupported Text Text
  | BuildInfoCompilerFlavourUnsupported Text
  | BuildInfoCompilerIdMalformed Text
  | BuildInfoComponentsEmpty
  | BuildInfoComponentTypeUnsupported Int Text
  | BuildInfoComponentNameMalformed Text Text
  | BuildInfoComponentSourceDiscoveryEmpty Text
  | BuildInfoHaskellSourceDirectoriesEmpty Text
  | BuildInfoUnitIdMalformed Text
  | BuildInfoModuleNameMalformed Text Text
  | BuildInfoModuleNameDuplicate Text Text
  | BuildInfoSourceFileDuplicate Text FilePath
  | BuildInfoHaskellSourceDirectoryDuplicate Text FilePath
  | BuildInfoPathUnsafe Text Text FilePath
  | BuildInfoPathEscapesSourceDirectory Text Text FilePath FilePath
  | BuildInfoSourceDirectoryNotAbsolute Text FilePath
  | BuildInfoSourceDirectoryMissingTrailingSeparator Text FilePath
  | BuildInfoCabalFileExtensionInvalid Text FilePath
  | BuildInfoSourceFileExtensionUnsupported Text FilePath
  | BuildInfoCompilerArgumentHazardous Text Int Text Text
  | BuildInfoCompilerArgumentUnclassified Text Int Text
  | BuildInfoCompilerArgumentValueMissing Text Int Text
  | BuildInfoCompilerArgumentValueMalformed Text Int Text Text
  | BuildInfoCompilerArgumentPathUnsafe Text Int Text FilePath
  | BuildInfoCompilerGeneratedInputArgumentMalformed Text Int Text (Maybe Text)
  | BuildInfoCompilerPackageBoundaryMissing Text Text
  | BuildInfoCompilerPackageBoundaryDuplicate Text Text
  | BuildInfoCompilerThisUnitIdMissing Text
  | BuildInfoCompilerThisUnitIdDuplicate Text [Text]
  | BuildInfoCompilerThisUnitIdMismatch Text Text
  | BuildInfoObservedUnitIdDuplicate Text
  | BuildInfoObservedComponentIdentityDuplicate Text Text
  | BuildInfoExpectedCompilerFlavourUnsupported Text
  | BuildInfoExpectedCompilerIdMalformed Text
  | BuildInfoExpectedCompilerPathUnsafe FilePath
  | BuildInfoExpectedCompilerIdMismatch Text Text
  | BuildInfoExpectedCompilerPathMismatch FilePath FilePath
  | BuildInfoExpectedIdentityTypeUnsupported Text Text Text
  | BuildInfoExpectedIdentityTextMalformed Text Text Text Text
  | BuildInfoExpectedIdentityUniverseEmpty
  | BuildInfoExpectedUnitIdDuplicate Text
  | BuildInfoExpectedComponentIdentityDuplicate Text Text
  | BuildInfoExpectedIdentityMissing Text Text Text
  | BuildInfoUnexpectedIdentity Text Text Text
  | BuildInfoExpectedUnitIdentityMismatch Text Text Text Text
  | BuildInfoExpectedComponentIdentityMismatch Text Text Text Text Text
  | BuildInfoGeneratorBytesUnauthenticated Text
  | BuildInfoCompilerIdentityUnauthenticated Text Text FilePath
  | BuildInfoIndependentExpectedCompilerUnavailable
  | BuildInfoMachinePathStateUnauthenticated
  | BuildInfoCompilerArgumentsUnauthenticated
      [(DiagnosticCompilerBuildInfoComponentIdentity,
        [DiagnosticCompilerBuildInfoArgumentObservation])]
  | BuildInfoDuplicateKeyDetectionDiagnosticOnly
  | BuildInfoIndependentExpectedUniverseUnavailable
      [DiagnosticCompilerBuildInfoComponentIdentity]
  | BuildInfoExactModuleSourceOwnershipUnresolved
  | BuildInfoCabalFileSourceJoinUnavailable
      [(DiagnosticCompilerBuildInfoComponentIdentity, Maybe FilePath)]
  | BuildInfoGeneratedCompilerInputsUnauthenticated
      [(DiagnosticCompilerBuildInfoComponentIdentity,
        [DiagnosticCompilerBuildInfoGeneratedInputObservation])]
  | BuildInfoPackageDependencyJoinUnavailable
      [(DiagnosticCompilerBuildInfoComponentIdentity,
        [DiagnosticCompilerBuildInfoPackageObservation])]
  | BuildInfoConfigurationJoinUnavailable
      [DiagnosticCompilerBuildInfoComponentIdentity]
  | BuildInfoSourcePragmaSemanticsUnavailable
      [DiagnosticCompilerBuildInfoComponentIdentity]
  | BuildInfoPhysicalPathContainmentUnavailable
  | BuildInfoPathPlatformSemanticsUnavailable Text
  | BuildInfoElaboratedPlanJoinUnavailable
      [DiagnosticCompilerBuildInfoComponentIdentity]
  | BuildInfoCompilerInvocationUnavailable Text Text FilePath
  | BuildInfoOracleQualificationUnavailable
  | BuildInfoResultEnvelopeExceeded Text Int Int
  deriving (Eq, Ord, Show)

data CompilerIdentity = CompilerIdentity Text Text FilePath
data Parsed value = Parsed [DiagnosticCompilerBuildInfoProblem] (Maybe value)

data DiagnosticProblemAccumulator
  = DiagnosticProblemAccumulator !Int !Bool [DiagnosticCompilerBuildInfoProblem]

data ArgumentInspection = ArgumentInspection
  { argumentInspectionProblems :: [DiagnosticCompilerBuildInfoProblem]
  , argumentInspectionArguments :: [DiagnosticCompilerBuildInfoArgumentObservation]
  , argumentInspectionPaths :: [DiagnosticCompilerBuildInfoPathObservation]
  , argumentInspectionGeneratedInputs :: [DiagnosticCompilerBuildInfoGeneratedInputObservation]
  , argumentInspectionPackageIds :: [DiagnosticCompilerBuildInfoPackageObservation]
  }

emptyProblemAccumulator :: DiagnosticProblemAccumulator
#ifdef VALIDATION_COMPILER_BUILDINFO_ACCUMULATOR_EMPTY_COUNT_SEED_MUTANT
emptyProblemAccumulator = DiagnosticProblemAccumulator 1 False []
#elif defined(VALIDATION_COMPILER_BUILDINFO_ACCUMULATOR_EMPTY_OVERFLOW_SEED_MUTANT)
emptyProblemAccumulator = DiagnosticProblemAccumulator 0 True []
#else
emptyProblemAccumulator = DiagnosticProblemAccumulator 0 False []
#endif

addProblemToAccumulator
  :: DiagnosticCompilerBuildInfoProblem
  -> DiagnosticProblemAccumulator
  -> DiagnosticProblemAccumulator
addProblemToAccumulator problem accumulator@(DiagnosticProblemAccumulator count overflow problems)
  | overflow = accumulator
  |
#ifdef VALIDATION_COMPILER_BUILDINFO_ACCUMULATOR_BOUNDARY_PREDICATE_MUTANT
      count <= maximumDiagnosticProblems =
#else
      count < maximumDiagnosticProblems =
#endif
      DiagnosticProblemAccumulator
#ifdef VALIDATION_COMPILER_BUILDINFO_ACCUMULATOR_COUNT_PROJECTION_MUTANT
        (count + 2)
#else
        (count + 1)
#endif
        False
        (problem : problems)
  | otherwise = DiagnosticProblemAccumulator count True problems

addProblemsToAccumulator
  :: [DiagnosticCompilerBuildInfoProblem]
  -> DiagnosticProblemAccumulator
  -> DiagnosticProblemAccumulator
addProblemsToAccumulator [] accumulator =
#ifdef VALIDATION_COMPILER_BUILDINFO_ACCUMULATOR_EMPTY_LIST_ROUTE_MUTANT
  addProblemToAccumulator
    (BuildInfoDuplicateKeyScanFailed "empty problem-list route mutated") accumulator
#else
  accumulator
#endif
addProblemsToAccumulator (problem : problems) accumulator =
  case addProblemToAccumulator problem accumulator of
    next@(DiagnosticProblemAccumulator _ True _) -> next
    next -> addProblemsToAccumulator problems next

finishProblemAccumulator
  :: DiagnosticProblemAccumulator
  -> [DiagnosticCompilerBuildInfoProblem]
finishProblemAccumulator (DiagnosticProblemAccumulator _ True _) =
  [BuildInfoResourceLimitExceeded "problem-count" maximumDiagnosticProblems
#ifdef VALIDATION_COMPILER_BUILDINFO_ACCUMULATOR_OVERFLOW_OBSERVED_PROJECTION_MUTANT
    (maximumDiagnosticProblems + 2)]
#else
    (maximumDiagnosticProblems + 1)]
#endif
finishProblemAccumulator (DiagnosticProblemAccumulator _ False problems) =
  reverse problems

makeDiagnosticCompilerBuildInfoExpectations
  :: Text
  -> Text
  -> FilePath
  -> [(Text, Text, Text)]
  -> Either Text DiagnosticCompilerBuildInfoExpectations
makeDiagnosticCompilerBuildInfoExpectations flavour compilerId compilerPath rawIdentities
  | identityCount > maximumExpectedIdentities =
      Left "expected-identities exceeds the 512-entry diagnostic bound"
  | not (boundedTextBytes maximumCallerCompilerFlavourBytes flavour) =
      Left "expected compiler flavour exceeds the 512-byte diagnostic bound"
  | not (boundedTextBytes maximumCallerCompilerIdBytes compilerId) =
      Left "expected compiler id exceeds the 512-byte diagnostic bound"
  | not (boundedFilePathBytes maximumExpectedCompilerPathBytes compilerPath) =
      Left "expected compiler path exceeds the 4096-byte diagnostic bound"
  | not (all boundedExpectedIdentity rawIdentities) =
      Left "an expected component identity exceeds the 512-byte per-field diagnostic bound"
  | otherwise =
      case boundedProblems
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTATION_VALIDATION_COMPILER_DROP_MUTANT
        (validateExpectedCompiler expectedCompiler `seq`
          validateExpectedIdentities expectedIdentities) of
#elif defined(VALIDATION_COMPILER_BUILDINFO_EXPECTATION_VALIDATION_IDENTITIES_DROP_MUTANT)
        (validateExpectedIdentities expectedIdentities `seq`
          validateExpectedCompiler expectedCompiler) of
#elif defined(VALIDATION_COMPILER_BUILDINFO_EXPECTATION_VALIDATION_ORDER_REVERSE_MUTANT)
        (reverse
          (validateExpectedCompiler expectedCompiler
            <> validateExpectedIdentities expectedIdentities)) of
#else
        (validateExpectedCompiler expectedCompiler
          <> validateExpectedIdentities expectedIdentities) of
#endif
        [] -> Right
          (DiagnosticCompilerBuildInfoExpectations expectedCompiler expectedIdentities)
        problem : _ -> Left (Text.pack (show problem))
 where
  identityCount = boundedLength (maximumExpectedIdentities + 1) rawIdentities
  expectedCompiler =
    DiagnosticCompilerBuildInfoExpectedCompiler flavour compilerId compilerPath
  expectedIdentities =
    [DiagnosticCompilerBuildInfoExpectedIdentity componentType componentName unitId
    | (componentType, componentName, unitId) <- rawIdentities]
  boundedExpectedIdentity (componentType, componentName, unitId) =
    boundedTextBytes maximumExpectedIdentityTypeBytes componentType
      && boundedTextBytes maximumExpectedIdentityNameBytes componentName
      && boundedTextBytes maximumExpectedIdentityUnitBytes unitId

compilerBuildInfoDiagnostic
  :: Text
  -> Text
  -> FilePath
  -> [(Text, Text, Text)]
  -> ByteString
  -> CheckResult
compilerBuildInfoDiagnostic flavour compilerId compilerPath rawIdentities bytes =
  case makeDiagnosticCompilerBuildInfoExpectations
    flavour compilerId compilerPath rawIdentities of
    Left expectationProblem -> expectationRefusalCheckResult expectationProblem
    Right expectations@(DiagnosticCompilerBuildInfoExpectations
      expectedCompiler expectedIdentities) ->
        refusalCheckResult expectations bytes
          (parseCompilerBuildInfoDiagnostic expectedCompiler expectedIdentities bytes)

diagnosticCheckName, diagnosticSubject :: Text
#ifdef VALIDATION_COMPILER_BUILDINFO_DIAGNOSTIC_CHECK_NAME_PROJECTION_MUTANT
diagnosticCheckName = "compiler-build-info-diagnostic-mutant"
#else
diagnosticCheckName = "compiler-build-info-diagnostic"
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_DIAGNOSTIC_SUBJECT_PROJECTION_MUTANT
diagnosticSubject =
  "Amoebius.Validation.CompilerBuildInfo.compilerBuildInfoDiagnostic.mutant"
#else
diagnosticSubject =
  "Amoebius.Validation.CompilerBuildInfo.compilerBuildInfoDiagnostic"
#endif

diagnosticOnlyFinding :: Finding
diagnosticOnlyFinding =
  finding
#ifdef VALIDATION_COMPILER_BUILDINFO_DIAGNOSTIC_ONLY_CODE_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-DIAGNOSTIC-ONLY-MUTANT"
#else
    "COMPILER-BUILDINFO-DIAGNOSTIC-ONLY"
#endif
    (Text.unpack diagnosticSubject)
#ifdef VALIDATION_COMPILER_BUILDINFO_DIAGNOSTIC_ONLY_DETAIL_PROJECTION_MUTANT
    "Cabal build-info diagnostics were mutated"
#else
    "Cabal build-info and caller expectations are unauthenticated diagnostics and cannot establish compiler or source closure"
#endif

expectationRefusalCheckResult :: Text -> CheckResult
expectationRefusalCheckResult detail =
  CheckResult
    { checkName = diagnosticCheckName
    , checkObservations = []
    , checkFindings =
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTATION_REFUSAL_DIAGNOSTIC_COMPOSITION_DROP_MUTANT
        diagnosticOnlyFindings `seq`
          [finding expectationRefusalCode
            (Text.unpack diagnosticSubject) expectationRefusalDetail]
#else
        diagnosticOnlyFindings
          <> [finding expectationRefusalCode
                (Text.unpack diagnosticSubject) expectationRefusalDetail]
#endif
    }
 where
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTATION_REFUSAL_CODE_PROJECTION_MUTANT
  expectationRefusalCode = "COMPILER-BUILDINFO-EXPECTATION-REFUSED-MUTANT"
#else
  expectationRefusalCode = "COMPILER-BUILDINFO-EXPECTATION-REFUSED"
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTATION_REFUSAL_DETAIL_PROJECTION_MUTANT
  expectationRefusalDetail = detail <> "-mutant"
#else
  expectationRefusalDetail = detail
#endif

refusalCheckResult
  :: DiagnosticCompilerBuildInfoExpectations
  -> ByteString
  -> DiagnosticCompilerBuildInfoRefusal
  -> CheckResult
refusalCheckResult expectations bytes =
  foldDiagnosticCompilerBuildInfoRefusal hardResult observedResult
 where
  hardResult problems =
#ifdef VALIDATION_COMPILER_BUILDINFO_REFUSAL_HARD_FOLD_ROUTE_MUTANT
    result False (NonEmpty.head problems :| NonEmpty.toList problems) []
#else
    result False problems []
#endif
  observedResult problems snapshot =
#ifdef VALIDATION_COMPILER_BUILDINFO_REFUSAL_OBSERVED_FOLD_ROUTE_MUTANT
    result True problems (reverse (snapshotObservations snapshot))
#elif defined(VALIDATION_COMPILER_BUILDINFO_REFUSAL_OBSERVED_ENVELOPE_RETENTION_ROUTE_MUTANT)
    result False problems (snapshotObservations snapshot)
#else
    result True problems (snapshotObservations snapshot)
#endif
  result retainProblemsOnEnvelope problems observed =
    case resultEnvelopeProblem proposedObservations proposedFindings of
      Nothing ->
        CheckResult
          { checkName = diagnosticCheckName
          , checkObservations = proposedObservations
          , checkFindings = proposedFindings
          }
      Just envelopeProblem ->
        resultEnvelopeRefusal
          (if retainProblemsOnEnvelope then proposedFindings else diagnosticOnlyFindings)
          envelopeProblem
   where
    proposedObservations =
#ifdef VALIDATION_COMPILER_BUILDINFO_RESULT_OBSERVATION_COMPOSITION_ORDER_MUTANT
      observed
        <> retainedObservations retainInputBytesObservation
          [observation "input.bytes" (decimal (ByteString.length bytes))]
        <> expectationObservations expectations
#else
      expectationObservations expectations
        <> retainedObservations retainInputBytesObservation
          [observation "input.bytes" (decimal (ByteString.length bytes))]
        <> observed
#endif
    proposedFindings =
#ifdef VALIDATION_COMPILER_BUILDINFO_RESULT_FINDING_COMPOSITION_ORDER_MUTANT
      map problemFinding (NonEmpty.toList problems) <> diagnosticOnlyFindings
#else
      diagnosticOnlyFindings <> map problemFinding (NonEmpty.toList problems)
#endif

resultEnvelopeRefusal :: [Finding] -> DiagnosticCompilerBuildInfoProblem -> CheckResult
resultEnvelopeRefusal retainedFindings envelopeProblem =
  CheckResult
    { checkName = diagnosticCheckName
    , checkObservations =
#ifdef VALIDATION_COMPILER_BUILDINFO_RESULT_ENVELOPE_OBSERVATION_ORDER_MUTANT
        reverse
#endif
        [ observation "result-envelope.status"
#ifdef VALIDATION_COMPILER_BUILDINFO_RESULT_ENVELOPE_STATUS_PROJECTION_MUTANT
            "refused-after-result-materialization"
#else
            "refused-before-result-materialization"
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_RESULT_ENVELOPE_EXCEEDED_PROJECTION_MUTANT
        , observation "result-envelope.exceeded" (exceededDimension <> "-mutant")
#else
        , observation "result-envelope.exceeded" exceededDimension
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_RESULT_ENVELOPE_LIMIT_PROJECTION_MUTANT
        , observation "result-envelope.limit" (decimal (limitValue + 1))
#else
        , observation "result-envelope.limit" (decimal limitValue)
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_RESULT_ENVELOPE_OBSERVED_PROJECTION_MUTANT
        , observation "result-envelope.observed" (decimal (observedValue - 1))
#else
        , observation "result-envelope.observed" (decimal observedValue)
#endif
        ]
#ifdef VALIDATION_COMPILER_BUILDINFO_RESULT_ENVELOPE_FINDING_COMPOSITION_DROP_MUTANT
    , checkFindings = problemFinding envelopeProblem `seq` retainedFindings
#else
    , checkFindings = retainedFindings <> [problemFinding envelopeProblem]
#endif
    }
 where
  (exceededDimension, limitValue, observedValue) = case envelopeProblem of
    BuildInfoResultEnvelopeExceeded dimension limit observed ->
      (dimension, limit, observed)
    _ -> ("internal-envelope-invariant", 0, 0)

resultEnvelopeProblem :: [Observation] -> [Finding] -> Maybe DiagnosticCompilerBuildInfoProblem
resultEnvelopeProblem observations findings =
#ifdef VALIDATION_COMPILER_BUILDINFO_RESULT_ENVELOPE_OBSERVATION_FOLD_ROUTE_MUTANT
  case observations of
    [] -> measureFindings 0 (textByteLength diagnosticCheckName) findings
    (_ : remaining) ->
      measureObservations 0 (textByteLength diagnosticCheckName) remaining
#elif defined(VALIDATION_COMPILER_BUILDINFO_RESULT_ENVELOPE_ENTRY_COUNT_SEED_MUTANT)
  measureObservations 1 (textByteLength diagnosticCheckName) observations
#elif defined(VALIDATION_COMPILER_BUILDINFO_RESULT_ENVELOPE_PAYLOAD_SEED_MUTANT)
  measureObservations 0 0 observations
#else
  measureObservations 0 (textByteLength diagnosticCheckName) observations
#endif
 where
  measureObservations !entryCount !payloadBytes [] =
#ifdef VALIDATION_COMPILER_BUILDINFO_RESULT_ENVELOPE_FINDING_FOLD_ROUTE_MUTANT
    measureFindings entryCount (payloadBytes + 1) findings
#else
    measureFindings entryCount payloadBytes findings
#endif
  measureObservations !entryCount !payloadBytes (item : remaining) =
    addEntry entryCount payloadBytes (observationPayloadBytes item)
      (\nextCount nextBytes -> measureObservations nextCount nextBytes remaining)
  measureFindings !_entryCount !_payloadBytes [] = Nothing
  measureFindings !entryCount !payloadBytes (item : remaining) =
    addEntry entryCount payloadBytes (findingPayloadBytes item)
      (\nextCount nextBytes -> measureFindings nextCount nextBytes remaining)
  addEntry !entryCount !payloadBytes !entryBytes continue =
    let nextCount = entryCount + 1
     in if nextCount > maximumResultEntries
          then Just
            (BuildInfoResultEnvelopeExceeded
#ifdef VALIDATION_COMPILER_BUILDINFO_RESULT_ENVELOPE_ENTRY_COUNT_PROJECTION_MUTANT
              "entries" maximumResultEntries entryCount)
#else
              "entries" maximumResultEntries nextCount)
#endif
          else
            let nextBytes = payloadBytes + entryBytes
             in if nextBytes > maximumResultPayloadBytes
                  then Just
                    (BuildInfoResultEnvelopeExceeded
#ifdef VALIDATION_COMPILER_BUILDINFO_RESULT_ENVELOPE_PAYLOAD_PROJECTION_MUTANT
                      "payload-bytes" maximumResultPayloadBytes payloadBytes)
#else
                      "payload-bytes" maximumResultPayloadBytes nextBytes)
#endif
                  else continue nextCount nextBytes

observationPayloadBytes :: Observation -> Int
observationPayloadBytes (Observation key value) =
#ifdef VALIDATION_COMPILER_BUILDINFO_OBSERVATION_PAYLOAD_KEY_PROJECTION_MUTANT
  value `seq` textByteLength key
#elif defined(VALIDATION_COMPILER_BUILDINFO_OBSERVATION_PAYLOAD_VALUE_PROJECTION_MUTANT)
  key `seq` textByteLength value
#else
  textByteLength key + textByteLength value
#endif

findingPayloadBytes :: Finding -> Int
findingPayloadBytes (Finding code subject detail) =
#ifdef VALIDATION_COMPILER_BUILDINFO_FINDING_PAYLOAD_CODE_PROJECTION_MUTANT
  subject `seq` detail `seq` textByteLength code
#elif defined(VALIDATION_COMPILER_BUILDINFO_FINDING_PAYLOAD_SUBJECT_PROJECTION_MUTANT)
  code `seq` detail `seq` textByteLength (Text.pack subject)
#elif defined(VALIDATION_COMPILER_BUILDINFO_FINDING_PAYLOAD_DETAIL_PROJECTION_MUTANT)
  code `seq` subject `seq` textByteLength detail
#else
  textByteLength code + textByteLength (Text.pack subject) + textByteLength detail
#endif

foldDiagnosticCompilerBuildInfoRefusal
  :: (NonEmpty DiagnosticCompilerBuildInfoProblem -> result)
  -> (NonEmpty DiagnosticCompilerBuildInfoProblem
        -> DiagnosticCompilerBuildInfoSnapshot -> result)
  -> DiagnosticCompilerBuildInfoRefusal
  -> result
foldDiagnosticCompilerBuildInfoRefusal hardResult _
  (DiagnosticCompilerBuildInfoRefusal problems Nothing) = hardResult problems
foldDiagnosticCompilerBuildInfoRefusal _ observedResult
  (DiagnosticCompilerBuildInfoRefusal problems (Just snapshot)) =
    observedResult problems snapshot

diagnosticOnlyFindings :: [Finding]
diagnosticOnlyFindings =
#ifdef VALIDATION_COMPILER_BUILDINFO_DIAGNOSTIC_ONLY_BYPASS_MUTANT
  diagnosticOnlyFinding `seq` []
#else
  [diagnosticOnlyFinding]
#endif

problemFinding :: DiagnosticCompilerBuildInfoProblem -> Finding
problemFinding problem =
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_FINDING_CODE_PROJECTION_MUTANT
  problemCode problem `seq`
    finding "COMPILER-BUILDINFO-PROBLEM-MUTANT"
      (Text.unpack diagnosticSubject) (problemDetail problem)
#elif defined(VALIDATION_COMPILER_BUILDINFO_PROBLEM_FINDING_SUBJECT_PROJECTION_MUTANT)
  finding (problemCode problem) "compiler-build-info-mutant" (problemDetail problem)
#elif defined(VALIDATION_COMPILER_BUILDINFO_PROBLEM_FINDING_DETAIL_PROJECTION_MUTANT)
  problemDetail problem `seq`
    finding (problemCode problem) (Text.unpack diagnosticSubject) "mutated problem detail"
#else
  finding (problemCode problem) (Text.unpack diagnosticSubject) (problemDetail problem)
#endif

problemCode :: DiagnosticCompilerBuildInfoProblem -> Text
problemCode problem = case problem of
  BuildInfoResourceLimitExceeded {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_RESOURCE_LIMIT_EXCEEDED_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-RESOURCE-LIMIT-MUTANT"
#else
    "COMPILER-BUILDINFO-RESOURCE-LIMIT"
#endif
  BuildInfoJsonDuplicateKey {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_JSON_DUPLICATE_KEY_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-JSON-DUPLICATE-KEY-MUTANT"
#else
    "COMPILER-BUILDINFO-JSON-DUPLICATE-KEY"
#endif
  BuildInfoDuplicateKeyScanFailed {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_DUPLICATE_KEY_SCAN_FAILED_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-JSON-SCAN-FAILED-MUTANT"
#else
    "COMPILER-BUILDINFO-JSON-SCAN-FAILED"
#endif
  BuildInfoRootNotObject ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_ROOT_NOT_OBJECT_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-ROOT-NOT-OBJECT-MUTANT"
#else
    "COMPILER-BUILDINFO-ROOT-NOT-OBJECT"
#endif
  BuildInfoFieldMissing {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_FIELD_MISSING_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-FIELD-MISSING-MUTANT"
#else
    "COMPILER-BUILDINFO-FIELD-MISSING"
#endif
  BuildInfoFieldUnknown {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_FIELD_UNKNOWN_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-FIELD-UNKNOWN-MUTANT"
#else
    "COMPILER-BUILDINFO-FIELD-UNKNOWN"
#endif
  BuildInfoFieldWrongType {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_FIELD_WRONG_TYPE_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-FIELD-WRONG-TYPE-MUTANT"
#else
    "COMPILER-BUILDINFO-FIELD-WRONG-TYPE"
#endif
  BuildInfoArrayElementWrongType {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_ARRAY_ELEMENT_WRONG_TYPE_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-ARRAY-ELEMENT-WRONG-TYPE-MUTANT"
#else
    "COMPILER-BUILDINFO-ARRAY-ELEMENT-WRONG-TYPE"
#endif
  BuildInfoTextEmpty {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_TEXT_EMPTY_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-TEXT-EMPTY-MUTANT"
#else
    "COMPILER-BUILDINFO-TEXT-EMPTY"
#endif
  BuildInfoArrayTextEmpty {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_ARRAY_TEXT_EMPTY_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-ARRAY-TEXT-EMPTY-MUTANT"
#else
    "COMPILER-BUILDINFO-ARRAY-TEXT-EMPTY"
#endif
  BuildInfoCabalLibraryVersionUnsupported {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_CABAL_LIBRARY_VERSION_UNSUPPORTED_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-CABAL-VERSION-MUTANT"
#else
    "COMPILER-BUILDINFO-CABAL-VERSION"
#endif
  BuildInfoCompilerFlavourUnsupported {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_COMPILER_FLAVOUR_UNSUPPORTED_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-COMPILER-FLAVOUR-MUTANT"
#else
    "COMPILER-BUILDINFO-COMPILER-FLAVOUR"
#endif
  BuildInfoCompilerIdMalformed {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_COMPILER_ID_MALFORMED_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-COMPILER-ID-MUTANT"
#else
    "COMPILER-BUILDINFO-COMPILER-ID"
#endif
  BuildInfoComponentsEmpty ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_COMPONENTS_EMPTY_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-COMPONENTS-EMPTY-MUTANT"
#else
    "COMPILER-BUILDINFO-COMPONENTS-EMPTY"
#endif
  BuildInfoComponentTypeUnsupported {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_COMPONENT_TYPE_UNSUPPORTED_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-COMPONENT-TYPE-MUTANT"
#else
    "COMPILER-BUILDINFO-COMPONENT-TYPE"
#endif
  BuildInfoComponentNameMalformed {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_COMPONENT_NAME_MALFORMED_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-COMPONENT-NAME-MUTANT"
#else
    "COMPILER-BUILDINFO-COMPONENT-NAME"
#endif
  BuildInfoComponentSourceDiscoveryEmpty {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_COMPONENT_SOURCE_DISCOVERY_EMPTY_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-SOURCE-DISCOVERY-EMPTY-MUTANT"
#else
    "COMPILER-BUILDINFO-SOURCE-DISCOVERY-EMPTY"
#endif
  BuildInfoHaskellSourceDirectoriesEmpty {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_HASKELL_SOURCE_DIRECTORIES_EMPTY_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-HS-SOURCE-DIRS-EMPTY-MUTANT"
#else
    "COMPILER-BUILDINFO-HS-SOURCE-DIRS-EMPTY"
#endif
  BuildInfoUnitIdMalformed {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_UNIT_ID_MALFORMED_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-UNIT-ID-MUTANT"
#else
    "COMPILER-BUILDINFO-UNIT-ID"
#endif
  BuildInfoModuleNameMalformed {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_MODULE_NAME_MALFORMED_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-MODULE-NAME-MUTANT"
#else
    "COMPILER-BUILDINFO-MODULE-NAME"
#endif
  BuildInfoModuleNameDuplicate {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_MODULE_NAME_DUPLICATE_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-MODULE-DUPLICATE-MUTANT"
#else
    "COMPILER-BUILDINFO-MODULE-DUPLICATE"
#endif
  BuildInfoSourceFileDuplicate {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_SOURCE_FILE_DUPLICATE_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-SOURCE-FILE-DUPLICATE-MUTANT"
#else
    "COMPILER-BUILDINFO-SOURCE-FILE-DUPLICATE"
#endif
  BuildInfoHaskellSourceDirectoryDuplicate {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_HASKELL_SOURCE_DIRECTORY_DUPLICATE_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-HS-SOURCE-DIR-DUPLICATE-MUTANT"
#else
    "COMPILER-BUILDINFO-HS-SOURCE-DIR-DUPLICATE"
#endif
  BuildInfoPathUnsafe {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_PATH_UNSAFE_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-PATH-UNSAFE-MUTANT"
#else
    "COMPILER-BUILDINFO-PATH-UNSAFE"
#endif
  BuildInfoPathEscapesSourceDirectory {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_PATH_ESCAPES_SOURCE_DIRECTORY_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-PATH-ESCAPES-SOURCE-MUTANT"
#else
    "COMPILER-BUILDINFO-PATH-ESCAPES-SOURCE"
#endif
  BuildInfoSourceDirectoryNotAbsolute {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_SOURCE_DIRECTORY_NOT_ABSOLUTE_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-SOURCE-DIR-NOT-ABSOLUTE-MUTANT"
#else
    "COMPILER-BUILDINFO-SOURCE-DIR-NOT-ABSOLUTE"
#endif
  BuildInfoSourceDirectoryMissingTrailingSeparator {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_SOURCE_DIRECTORY_MISSING_TRAILING_SEPARATOR_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-SOURCE-DIR-SEPARATOR-MUTANT"
#else
    "COMPILER-BUILDINFO-SOURCE-DIR-SEPARATOR"
#endif
  BuildInfoCabalFileExtensionInvalid {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_CABAL_FILE_EXTENSION_INVALID_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-CABAL-EXTENSION-MUTANT"
#else
    "COMPILER-BUILDINFO-CABAL-EXTENSION"
#endif
  BuildInfoSourceFileExtensionUnsupported {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_SOURCE_FILE_EXTENSION_UNSUPPORTED_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-SOURCE-EXTENSION-MUTANT"
#else
    "COMPILER-BUILDINFO-SOURCE-EXTENSION"
#endif
  BuildInfoCompilerArgumentHazardous {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_COMPILER_ARGUMENT_HAZARDOUS_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-ARGUMENT-HAZARDOUS-MUTANT"
#else
    "COMPILER-BUILDINFO-ARGUMENT-HAZARDOUS"
#endif
  BuildInfoCompilerArgumentUnclassified {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_COMPILER_ARGUMENT_UNCLASSIFIED_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-ARGUMENT-UNCLASSIFIED-MUTANT"
#else
    "COMPILER-BUILDINFO-ARGUMENT-UNCLASSIFIED"
#endif
  BuildInfoCompilerArgumentValueMissing {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_COMPILER_ARGUMENT_VALUE_MISSING_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-ARGUMENT-VALUE-MISSING-MUTANT"
#else
    "COMPILER-BUILDINFO-ARGUMENT-VALUE-MISSING"
#endif
  BuildInfoCompilerArgumentValueMalformed {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_COMPILER_ARGUMENT_VALUE_MALFORMED_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-ARGUMENT-VALUE-MALFORMED-MUTANT"
#else
    "COMPILER-BUILDINFO-ARGUMENT-VALUE-MALFORMED"
#endif
  BuildInfoCompilerArgumentPathUnsafe {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_COMPILER_ARGUMENT_PATH_UNSAFE_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-ARGUMENT-PATH-UNSAFE-MUTANT"
#else
    "COMPILER-BUILDINFO-ARGUMENT-PATH-UNSAFE"
#endif
  BuildInfoCompilerGeneratedInputArgumentMalformed {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_COMPILER_GENERATED_INPUT_ARGUMENT_MALFORMED_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-GENERATED-INPUT-ARGUMENT-MUTANT"
#else
    "COMPILER-BUILDINFO-GENERATED-INPUT-ARGUMENT"
#endif
  BuildInfoCompilerPackageBoundaryMissing {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_COMPILER_PACKAGE_BOUNDARY_MISSING_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-PACKAGE-BOUNDARY-MISSING-MUTANT"
#else
    "COMPILER-BUILDINFO-PACKAGE-BOUNDARY-MISSING"
#endif
  BuildInfoCompilerPackageBoundaryDuplicate {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_COMPILER_PACKAGE_BOUNDARY_DUPLICATE_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-PACKAGE-BOUNDARY-DUPLICATE-MUTANT"
#else
    "COMPILER-BUILDINFO-PACKAGE-BOUNDARY-DUPLICATE"
#endif
  BuildInfoCompilerThisUnitIdMissing {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_COMPILER_THIS_UNIT_ID_MISSING_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-THIS-UNIT-MISSING-MUTANT"
#else
    "COMPILER-BUILDINFO-THIS-UNIT-MISSING"
#endif
  BuildInfoCompilerThisUnitIdDuplicate {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_COMPILER_THIS_UNIT_ID_DUPLICATE_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-THIS-UNIT-DUPLICATE-MUTANT"
#else
    "COMPILER-BUILDINFO-THIS-UNIT-DUPLICATE"
#endif
  BuildInfoCompilerThisUnitIdMismatch {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_COMPILER_THIS_UNIT_ID_MISMATCH_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-THIS-UNIT-MISMATCH-MUTANT"
#else
    "COMPILER-BUILDINFO-THIS-UNIT-MISMATCH"
#endif
  BuildInfoObservedUnitIdDuplicate {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_OBSERVED_UNIT_ID_DUPLICATE_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-OBSERVED-UNIT-DUPLICATE-MUTANT"
#else
    "COMPILER-BUILDINFO-OBSERVED-UNIT-DUPLICATE"
#endif
  BuildInfoObservedComponentIdentityDuplicate {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_OBSERVED_COMPONENT_IDENTITY_DUPLICATE_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-OBSERVED-COMPONENT-DUPLICATE-MUTANT"
#else
    "COMPILER-BUILDINFO-OBSERVED-COMPONENT-DUPLICATE"
#endif
  BuildInfoExpectedCompilerFlavourUnsupported {} ->
    "COMPILER-BUILDINFO-EXPECTED-COMPILER-FLAVOUR"
  BuildInfoExpectedCompilerIdMalformed {} ->
    "COMPILER-BUILDINFO-EXPECTED-COMPILER-ID"
  BuildInfoExpectedCompilerPathUnsafe {} ->
    "COMPILER-BUILDINFO-EXPECTED-COMPILER-PATH"
  BuildInfoExpectedCompilerIdMismatch {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_EXPECTED_COMPILER_ID_MISMATCH_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-COMPILER-ID-MISMATCH-MUTANT"
#else
    "COMPILER-BUILDINFO-COMPILER-ID-MISMATCH"
#endif
  BuildInfoExpectedCompilerPathMismatch {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_EXPECTED_COMPILER_PATH_MISMATCH_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-COMPILER-PATH-MISMATCH-MUTANT"
#else
    "COMPILER-BUILDINFO-COMPILER-PATH-MISMATCH"
#endif
  BuildInfoExpectedIdentityTypeUnsupported {} ->
    "COMPILER-BUILDINFO-EXPECTED-IDENTITY-TYPE"
  BuildInfoExpectedIdentityTextMalformed {} ->
    "COMPILER-BUILDINFO-EXPECTED-IDENTITY-TEXT"
  BuildInfoExpectedIdentityUniverseEmpty ->
    "COMPILER-BUILDINFO-EXPECTED-UNIVERSE-EMPTY"
  BuildInfoExpectedUnitIdDuplicate {} ->
    "COMPILER-BUILDINFO-EXPECTED-UNIT-DUPLICATE"
  BuildInfoExpectedComponentIdentityDuplicate {} ->
    "COMPILER-BUILDINFO-EXPECTED-COMPONENT-DUPLICATE"
  BuildInfoExpectedIdentityMissing {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_EXPECTED_IDENTITY_MISSING_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-EXPECTED-IDENTITY-MISSING-MUTANT"
#else
    "COMPILER-BUILDINFO-EXPECTED-IDENTITY-MISSING"
#endif
  BuildInfoUnexpectedIdentity {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_UNEXPECTED_IDENTITY_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-UNEXPECTED-IDENTITY-MUTANT"
#else
    "COMPILER-BUILDINFO-UNEXPECTED-IDENTITY"
#endif
  BuildInfoExpectedUnitIdentityMismatch {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_EXPECTED_UNIT_IDENTITY_MISMATCH_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-EXPECTED-UNIT-MISMATCH-MUTANT"
#else
    "COMPILER-BUILDINFO-EXPECTED-UNIT-MISMATCH"
#endif
  BuildInfoExpectedComponentIdentityMismatch {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_EXPECTED_COMPONENT_IDENTITY_MISMATCH_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-EXPECTED-COMPONENT-MISMATCH-MUTANT"
#else
    "COMPILER-BUILDINFO-EXPECTED-COMPONENT-MISMATCH"
#endif
  BuildInfoGeneratorBytesUnauthenticated {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_GENERATOR_BYTES_UNAUTHENTICATED_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-GENERATOR-BYTES-UNAUTHENTICATED-MUTANT"
#else
    "COMPILER-BUILDINFO-GENERATOR-BYTES-UNAUTHENTICATED"
#endif
  BuildInfoCompilerIdentityUnauthenticated {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_COMPILER_IDENTITY_UNAUTHENTICATED_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-COMPILER-UNAUTHENTICATED-MUTANT"
#else
    "COMPILER-BUILDINFO-COMPILER-UNAUTHENTICATED"
#endif
  BuildInfoIndependentExpectedCompilerUnavailable {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_INDEPENDENT_EXPECTED_COMPILER_UNAVAILABLE_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-INDEPENDENT-COMPILER-UNAVAILABLE-MUTANT"
#else
    "COMPILER-BUILDINFO-INDEPENDENT-COMPILER-UNAVAILABLE"
#endif
  BuildInfoMachinePathStateUnauthenticated {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_MACHINE_PATH_STATE_UNAUTHENTICATED_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-MACHINE-PATHS-UNAUTHENTICATED-MUTANT"
#else
    "COMPILER-BUILDINFO-MACHINE-PATHS-UNAUTHENTICATED"
#endif
  BuildInfoCompilerArgumentsUnauthenticated {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_COMPILER_ARGUMENTS_UNAUTHENTICATED_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-ARGUMENTS-UNAUTHENTICATED-MUTANT"
#else
    "COMPILER-BUILDINFO-ARGUMENTS-UNAUTHENTICATED"
#endif
  BuildInfoDuplicateKeyDetectionDiagnosticOnly ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_DUPLICATE_KEY_DETECTION_DIAGNOSTIC_ONLY_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-DUPLICATE-DETECTION-DIAGNOSTIC-MUTANT"
#else
    "COMPILER-BUILDINFO-DUPLICATE-DETECTION-DIAGNOSTIC"
#endif
  BuildInfoIndependentExpectedUniverseUnavailable {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_INDEPENDENT_EXPECTED_UNIVERSE_UNAVAILABLE_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-INDEPENDENT-UNIVERSE-UNAVAILABLE-MUTANT"
#else
    "COMPILER-BUILDINFO-INDEPENDENT-UNIVERSE-UNAVAILABLE"
#endif
  BuildInfoExactModuleSourceOwnershipUnresolved {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_EXACT_MODULE_SOURCE_OWNERSHIP_UNRESOLVED_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-SOURCE-OWNERSHIP-UNRESOLVED-MUTANT"
#else
    "COMPILER-BUILDINFO-SOURCE-OWNERSHIP-UNRESOLVED"
#endif
  BuildInfoCabalFileSourceJoinUnavailable {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_CABAL_FILE_SOURCE_JOIN_UNAVAILABLE_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-CABAL-SOURCE-JOIN-UNAVAILABLE-MUTANT"
#else
    "COMPILER-BUILDINFO-CABAL-SOURCE-JOIN-UNAVAILABLE"
#endif
  BuildInfoGeneratedCompilerInputsUnauthenticated {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_GENERATED_COMPILER_INPUTS_UNAUTHENTICATED_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-GENERATED-INPUTS-UNAUTHENTICATED-MUTANT"
#else
    "COMPILER-BUILDINFO-GENERATED-INPUTS-UNAUTHENTICATED"
#endif
  BuildInfoPackageDependencyJoinUnavailable {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_PACKAGE_DEPENDENCY_JOIN_UNAVAILABLE_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-PACKAGE-JOIN-UNAVAILABLE-MUTANT"
#else
    "COMPILER-BUILDINFO-PACKAGE-JOIN-UNAVAILABLE"
#endif
  BuildInfoConfigurationJoinUnavailable {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_CONFIGURATION_JOIN_UNAVAILABLE_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-CONFIGURATION-JOIN-UNAVAILABLE-MUTANT"
#else
    "COMPILER-BUILDINFO-CONFIGURATION-JOIN-UNAVAILABLE"
#endif
  BuildInfoSourcePragmaSemanticsUnavailable {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_SOURCE_PRAGMA_SEMANTICS_UNAVAILABLE_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-PRAGMA-SEMANTICS-UNAVAILABLE-MUTANT"
#else
    "COMPILER-BUILDINFO-PRAGMA-SEMANTICS-UNAVAILABLE"
#endif
  BuildInfoPhysicalPathContainmentUnavailable {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_PHYSICAL_PATH_CONTAINMENT_UNAVAILABLE_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-PHYSICAL-PATHS-UNAVAILABLE-MUTANT"
#else
    "COMPILER-BUILDINFO-PHYSICAL-PATHS-UNAVAILABLE"
#endif
  BuildInfoPathPlatformSemanticsUnavailable {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_PATH_PLATFORM_SEMANTICS_UNAVAILABLE_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-PATH-PLATFORM-UNAVAILABLE-MUTANT"
#else
    "COMPILER-BUILDINFO-PATH-PLATFORM-UNAVAILABLE"
#endif
  BuildInfoElaboratedPlanJoinUnavailable {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_ELABORATED_PLAN_JOIN_UNAVAILABLE_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-PLAN-JOIN-UNAVAILABLE-MUTANT"
#else
    "COMPILER-BUILDINFO-PLAN-JOIN-UNAVAILABLE"
#endif
  BuildInfoCompilerInvocationUnavailable {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_COMPILER_INVOCATION_UNAVAILABLE_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-COMPILER-INVOCATION-UNAVAILABLE-MUTANT"
#else
    "COMPILER-BUILDINFO-COMPILER-INVOCATION-UNAVAILABLE"
#endif
  BuildInfoOracleQualificationUnavailable ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_ORACLE_QUALIFICATION_UNAVAILABLE_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-ORACLE-QUALIFICATION-UNAVAILABLE-MUTANT"
#else
    "COMPILER-BUILDINFO-ORACLE-QUALIFICATION-UNAVAILABLE"
#endif
  BuildInfoResultEnvelopeExceeded {} ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_CODE_RESULT_ENVELOPE_EXCEEDED_PROJECTION_MUTANT
    "COMPILER-BUILDINFO-RESULT-ENVELOPE-MUTANT"
#else
    "COMPILER-BUILDINFO-RESULT-ENVELOPE"
#endif

problemDetail :: DiagnosticCompilerBuildInfoProblem -> Text
problemDetail problem =
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_DETAIL_GENERATOR_BYTES_UNAUTHENTICATED_PROJECTION_MUTANT
  mutateProblemDetail
    (\candidate -> case candidate of
      BuildInfoGeneratorBytesUnauthenticated {} -> True
      _ -> False)
    problem
#elif defined(VALIDATION_COMPILER_BUILDINFO_PROBLEM_DETAIL_COMPILER_IDENTITY_UNAUTHENTICATED_PROJECTION_MUTANT)
  mutateProblemDetail
    (\candidate -> case candidate of
      BuildInfoCompilerIdentityUnauthenticated {} -> True
      _ -> False)
    problem
#elif defined(VALIDATION_COMPILER_BUILDINFO_PROBLEM_DETAIL_INDEPENDENT_EXPECTED_COMPILER_UNAVAILABLE_PROJECTION_MUTANT)
  mutateProblemDetail
    (\candidate -> case candidate of
      BuildInfoIndependentExpectedCompilerUnavailable {} -> True
      _ -> False)
    problem
#elif defined(VALIDATION_COMPILER_BUILDINFO_PROBLEM_DETAIL_MACHINE_PATH_STATE_UNAUTHENTICATED_PROJECTION_MUTANT)
  mutateProblemDetail
    (\candidate -> case candidate of
      BuildInfoMachinePathStateUnauthenticated {} -> True
      _ -> False)
    problem
#elif defined(VALIDATION_COMPILER_BUILDINFO_PROBLEM_DETAIL_COMPILER_ARGUMENTS_UNAUTHENTICATED_PROJECTION_MUTANT)
  mutateProblemDetail
    (\candidate -> case candidate of
      BuildInfoCompilerArgumentsUnauthenticated {} -> True
      _ -> False)
    problem
#elif defined(VALIDATION_COMPILER_BUILDINFO_PROBLEM_DETAIL_DUPLICATE_KEY_DETECTION_DIAGNOSTIC_ONLY_PROJECTION_MUTANT)
  mutateProblemDetail
    (\candidate -> case candidate of
      BuildInfoDuplicateKeyDetectionDiagnosticOnly -> True
      _ -> False)
    problem
#elif defined(VALIDATION_COMPILER_BUILDINFO_PROBLEM_DETAIL_INDEPENDENT_EXPECTED_UNIVERSE_UNAVAILABLE_PROJECTION_MUTANT)
  mutateProblemDetail
    (\candidate -> case candidate of
      BuildInfoIndependentExpectedUniverseUnavailable {} -> True
      _ -> False)
    problem
#elif defined(VALIDATION_COMPILER_BUILDINFO_PROBLEM_DETAIL_EXACT_MODULE_SOURCE_OWNERSHIP_UNRESOLVED_PROJECTION_MUTANT)
  mutateProblemDetail
    (\candidate -> case candidate of
      BuildInfoExactModuleSourceOwnershipUnresolved {} -> True
      _ -> False)
    problem
#elif defined(VALIDATION_COMPILER_BUILDINFO_PROBLEM_DETAIL_CABAL_FILE_SOURCE_JOIN_UNAVAILABLE_PROJECTION_MUTANT)
  mutateProblemDetail
    (\candidate -> case candidate of
      BuildInfoCabalFileSourceJoinUnavailable {} -> True
      _ -> False)
    problem
#elif defined(VALIDATION_COMPILER_BUILDINFO_PROBLEM_DETAIL_GENERATED_COMPILER_INPUTS_UNAUTHENTICATED_PROJECTION_MUTANT)
  mutateProblemDetail
    (\candidate -> case candidate of
      BuildInfoGeneratedCompilerInputsUnauthenticated {} -> True
      _ -> False)
    problem
#elif defined(VALIDATION_COMPILER_BUILDINFO_PROBLEM_DETAIL_PACKAGE_DEPENDENCY_JOIN_UNAVAILABLE_PROJECTION_MUTANT)
  mutateProblemDetail
    (\candidate -> case candidate of
      BuildInfoPackageDependencyJoinUnavailable {} -> True
      _ -> False)
    problem
#elif defined(VALIDATION_COMPILER_BUILDINFO_PROBLEM_DETAIL_CONFIGURATION_JOIN_UNAVAILABLE_PROJECTION_MUTANT)
  mutateProblemDetail
    (\candidate -> case candidate of
      BuildInfoConfigurationJoinUnavailable {} -> True
      _ -> False)
    problem
#elif defined(VALIDATION_COMPILER_BUILDINFO_PROBLEM_DETAIL_SOURCE_PRAGMA_SEMANTICS_UNAVAILABLE_PROJECTION_MUTANT)
  mutateProblemDetail
    (\candidate -> case candidate of
      BuildInfoSourcePragmaSemanticsUnavailable {} -> True
      _ -> False)
    problem
#elif defined(VALIDATION_COMPILER_BUILDINFO_PROBLEM_DETAIL_PHYSICAL_PATH_CONTAINMENT_UNAVAILABLE_PROJECTION_MUTANT)
  mutateProblemDetail
    (\candidate -> case candidate of
      BuildInfoPhysicalPathContainmentUnavailable {} -> True
      _ -> False)
    problem
#elif defined(VALIDATION_COMPILER_BUILDINFO_PROBLEM_DETAIL_PATH_PLATFORM_SEMANTICS_UNAVAILABLE_PROJECTION_MUTANT)
  mutateProblemDetail
    (\candidate -> case candidate of
      BuildInfoPathPlatformSemanticsUnavailable {} -> True
      _ -> False)
    problem
#elif defined(VALIDATION_COMPILER_BUILDINFO_PROBLEM_DETAIL_ELABORATED_PLAN_JOIN_UNAVAILABLE_PROJECTION_MUTANT)
  mutateProblemDetail
    (\candidate -> case candidate of
      BuildInfoElaboratedPlanJoinUnavailable {} -> True
      _ -> False)
    problem
#elif defined(VALIDATION_COMPILER_BUILDINFO_PROBLEM_DETAIL_COMPILER_INVOCATION_UNAVAILABLE_PROJECTION_MUTANT)
  mutateProblemDetail
    (\candidate -> case candidate of
      BuildInfoCompilerInvocationUnavailable {} -> True
      _ -> False)
    problem
#elif defined(VALIDATION_COMPILER_BUILDINFO_PROBLEM_DETAIL_ORACLE_QUALIFICATION_UNAVAILABLE_PROJECTION_MUTANT)
  mutateProblemDetail
    (\candidate -> case candidate of
      BuildInfoOracleQualificationUnavailable -> True
      _ -> False)
    problem
#elif defined(VALIDATION_COMPILER_BUILDINFO_PROBLEM_DETAIL_GENERIC_SHOW_PROJECTION_MUTANT)
  mutateProblemDetail
    (\candidate -> case candidate of
      BuildInfoGeneratorBytesUnauthenticated {} -> False
      BuildInfoCompilerIdentityUnauthenticated {} -> False
      BuildInfoIndependentExpectedCompilerUnavailable {} -> False
      BuildInfoMachinePathStateUnauthenticated {} -> False
      BuildInfoCompilerArgumentsUnauthenticated {} -> False
      BuildInfoDuplicateKeyDetectionDiagnosticOnly -> False
      BuildInfoIndependentExpectedUniverseUnavailable {} -> False
      BuildInfoExactModuleSourceOwnershipUnresolved {} -> False
      BuildInfoCabalFileSourceJoinUnavailable {} -> False
      BuildInfoGeneratedCompilerInputsUnauthenticated {} -> False
      BuildInfoPackageDependencyJoinUnavailable {} -> False
      BuildInfoConfigurationJoinUnavailable {} -> False
      BuildInfoSourcePragmaSemanticsUnavailable {} -> False
      BuildInfoPhysicalPathContainmentUnavailable {} -> False
      BuildInfoPathPlatformSemanticsUnavailable {} -> False
      BuildInfoElaboratedPlanJoinUnavailable {} -> False
      BuildInfoCompilerInvocationUnavailable {} -> False
      BuildInfoOracleQualificationUnavailable -> False
      _ -> True)
    problem
#else
  mutateProblemDetail (const False) problem
#endif

mutateProblemDetail
  :: (DiagnosticCompilerBuildInfoProblem -> Bool)
  -> DiagnosticCompilerBuildInfoProblem
  -> Text
mutateProblemDetail selected problem =
  originalProblemDetail problem
    <> if selected problem then "-MUTANT" else ""

originalProblemDetail :: DiagnosticCompilerBuildInfoProblem -> Text
originalProblemDetail problem = case problem of
  BuildInfoGeneratorBytesUnauthenticated _ ->
    "generated build-info bytes have no authenticated generator or custody"
  BuildInfoCompilerIdentityUnauthenticated {} ->
    "the observed compiler identity has no independent toolchain authority"
  BuildInfoIndependentExpectedCompilerUnavailable {} ->
    "the expected compiler is caller-constructed rather than independently acquired"
  BuildInfoMachinePathStateUnauthenticated {} ->
    "machine paths are lexical observations without authenticated filesystem identity"
  BuildInfoCompilerArgumentsUnauthenticated {} ->
    "compiler arguments are generated observations without invocation custody"
  BuildInfoDuplicateKeyDetectionDiagnosticOnly ->
    "duplicate-key detection is production-local and lacks an independent observer"
  BuildInfoIndependentExpectedUniverseUnavailable {} ->
    "the component universe is caller-constructed rather than independently acquired"
  BuildInfoExactModuleSourceOwnershipUnresolved {} ->
    "module and source-file names are not joined to exact acquired source bytes"
  BuildInfoCabalFileSourceJoinUnavailable {} ->
    "every observed optional Cabal-file path lacks an authenticated exact-source join"
  BuildInfoGeneratedCompilerInputsUnauthenticated {} ->
    "generated compiler inputs are not authenticated against exact generated bytes"
  BuildInfoPackageDependencyJoinUnavailable {} ->
    "package arguments are not joined to an authenticated elaborated dependency graph"
  BuildInfoConfigurationJoinUnavailable {} ->
    "component configuration is not joined to independently acquired Cabal semantics"
  BuildInfoSourcePragmaSemanticsUnavailable {} ->
    "source pragmas and compile-time language semantics remain unresolved"
  BuildInfoPhysicalPathContainmentUnavailable {} ->
    "lexical paths are not resolved through physical filesystem identity"
  BuildInfoPathPlatformSemanticsUnavailable platform ->
    "path grammar is explicitly limited to " <> platform
  BuildInfoElaboratedPlanJoinUnavailable {} ->
    "component identities are not joined to an authenticated elaborated plan"
  BuildInfoCompilerInvocationUnavailable {} ->
    "the exact compiler has not been invoked under an external observer"
  BuildInfoOracleQualificationUnavailable ->
    "the independently reviewed oracle and mutation harness are not qualified"
  _ -> Text.pack (show problem)

expectationObservations
  :: DiagnosticCompilerBuildInfoExpectations
  -> [Observation]
expectationObservations (DiagnosticCompilerBuildInfoExpectations
  (DiagnosticCompilerBuildInfoExpectedCompiler flavour compilerId compilerPath)
  identities) =
    retainedObservations retainExpectedCompilerFlavourObservation
      [observation
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_COMPILER_FLAVOUR_KEY_PROJECTION_MUTANT
        "expected.compiler.flavour.mutant"
#else
        "expected.compiler.flavour"
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_COMPILER_FLAVOUR_VALUE_PROJECTION_MUTANT
        (flavour <> "-mutant")]
#else
        flavour]
#endif
      <> retainedObservations retainExpectedCompilerIdObservation
        [observation
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_COMPILER_ID_KEY_PROJECTION_MUTANT
          "expected.compiler.id.mutant"
#else
          "expected.compiler.id"
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_COMPILER_ID_VALUE_PROJECTION_MUTANT
          (compilerId <> "-mutant")]
#else
          compilerId]
#endif
      <> retainedObservations retainExpectedCompilerPathObservation
        [observation
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_COMPILER_PATH_KEY_PROJECTION_MUTANT
          "expected.compiler.path.mutant"
#else
          "expected.compiler.path"
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_COMPILER_PATH_VALUE_PROJECTION_MUTANT
          (Text.pack compilerPath <> "/mutant")]
#else
          (Text.pack compilerPath)]
#endif
      <> retainedObservations retainExpectedComponentCountObservation
        [observation
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_COMPONENT_COUNT_KEY_PROJECTION_MUTANT
          "expected.component.count.mutant"
#else
          "expected.component.count"
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_COMPONENT_COUNT_VALUE_PROJECTION_MUTANT
          (decimal (length identities + 1))]
#else
          (decimal (length identities))]
#endif
      <> concat
        [ expectedIdentityObservations
            ("expected.component." <>
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_COMPONENT_PREFIX_INDEX_PROJECTION_MUTANT
              decimal (index + 1))
#else
              decimal index)
#endif
            (expectedIdentityComponent identity)
        | (index, identity) <- zip [0 :: Int ..] identities
        ]

snapshotObservations :: DiagnosticCompilerBuildInfoSnapshot -> [Observation]
snapshotObservations
  (DiagnosticCompilerBuildInfoSnapshot _ version flavour compilerId compilerPath components) =
    retainedObservations retainObservedCabalVersionObservation
      [observation
#ifdef VALIDATION_COMPILER_BUILDINFO_OBSERVED_CABAL_VERSION_KEY_PROJECTION_MUTANT
        "observed.cabal-library-version.mutant"
#else
        "observed.cabal-library-version"
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_OBSERVED_CABAL_VERSION_VALUE_PROJECTION_MUTANT
        (version <> "-mutant")]
#else
        version]
#endif
      <> retainedObservations retainObservedCompilerFlavourObservation
        [observation
#ifdef VALIDATION_COMPILER_BUILDINFO_OBSERVED_COMPILER_FLAVOUR_KEY_PROJECTION_MUTANT
          "observed.compiler.flavour.mutant"
#else
          "observed.compiler.flavour"
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_OBSERVED_COMPILER_FLAVOUR_VALUE_PROJECTION_MUTANT
          (flavour <> "-mutant")]
#else
          flavour]
#endif
      <> retainedObservations retainObservedCompilerIdObservation
        [observation
#ifdef VALIDATION_COMPILER_BUILDINFO_OBSERVED_COMPILER_ID_KEY_PROJECTION_MUTANT
          "observed.compiler.id.mutant"
#else
          "observed.compiler.id"
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_OBSERVED_COMPILER_ID_VALUE_PROJECTION_MUTANT
          (compilerId <> "-mutant")]
#else
          compilerId]
#endif
      <> retainedObservations retainObservedCompilerPathObservation
        [observation
#ifdef VALIDATION_COMPILER_BUILDINFO_OBSERVED_COMPILER_PATH_KEY_PROJECTION_MUTANT
          "observed.compiler.path.mutant"
#else
          "observed.compiler.path"
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_OBSERVED_COMPILER_PATH_VALUE_PROJECTION_MUTANT
          (Text.pack compilerPath <> "/mutant")]
#else
          (Text.pack compilerPath)]
#endif
      <> retainedObservations retainObservedComponentCountObservation
        [observation
#ifdef VALIDATION_COMPILER_BUILDINFO_OBSERVED_COMPONENT_COUNT_KEY_PROJECTION_MUTANT
          "observed.component.count.mutant"
#else
          "observed.component.count"
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_OBSERVED_COMPONENT_COUNT_VALUE_PROJECTION_MUTANT
          (decimal (length components + 1))]
#else
          (decimal (length components))]
#endif
      <> concat
        [ componentObservations
            ("observed.component." <>
#ifdef VALIDATION_COMPILER_BUILDINFO_OBSERVED_COMPONENT_PREFIX_INDEX_PROJECTION_MUTANT
              decimal (index + 1))
#else
              decimal index)
#endif
            component
        | (index, component) <- zip [0 :: Int ..] components
        ]

identityObservations
  :: Bool
  -> Bool
  -> Bool
  -> Text
  -> DiagnosticCompilerBuildInfoComponentIdentity
  -> [Observation]
identityObservations retainType retainName retainUnit prefix
  (DiagnosticCompilerBuildInfoComponentIdentity componentType componentName unitId) =
    retainedObservations retainType
      [observation
#ifdef VALIDATION_COMPILER_BUILDINFO_IDENTITY_TYPE_KEY_PROJECTION_MUTANT
        (prefix <> ".type.mutant")
#else
        (prefix <> ".type")
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_IDENTITY_TYPE_VALUE_PROJECTION_MUTANT
        (componentType <> "-mutant")]
#else
        componentType]
#endif
      <> retainedObservations retainName
        [observation
#ifdef VALIDATION_COMPILER_BUILDINFO_IDENTITY_NAME_KEY_PROJECTION_MUTANT
          (prefix <> ".name.mutant")
#else
          (prefix <> ".name")
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_IDENTITY_NAME_VALUE_PROJECTION_MUTANT
          (componentName <> "-mutant")]
#else
          componentName]
#endif
      <> retainedObservations retainUnit
        [observation
#ifdef VALIDATION_COMPILER_BUILDINFO_IDENTITY_UNIT_KEY_PROJECTION_MUTANT
          (prefix <> ".unit-id.mutant")
#else
          (prefix <> ".unit-id")
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_IDENTITY_UNIT_VALUE_PROJECTION_MUTANT
          (unitId <> "-mutant")]
#else
          unitId]
#endif

expectedIdentityObservations
  :: Text
  -> DiagnosticCompilerBuildInfoComponentIdentity
  -> [Observation]
expectedIdentityObservations =
  identityObservations retainExpectedIdentityTypeObservation
    retainExpectedIdentityNameObservation retainExpectedIdentityUnitObservation

observedIdentityObservations
  :: Text
  -> DiagnosticCompilerBuildInfoComponentIdentity
  -> [Observation]
observedIdentityObservations =
  identityObservations retainObservedIdentityTypeObservation
    retainObservedIdentityNameObservation retainObservedIdentityUnitObservation

componentObservations
  :: Text
  -> DiagnosticCompilerBuildInfoComponentObservation
  -> [Observation]
componentObservations prefix component =
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPONENT_OBSERVATION_FAMILY_ORDER_MUTANT
  reverse
#endif
  (
  observedIdentityObservations
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPONENT_IDENTITY_PREFIX_PROJECTION_MUTANT
      (prefix <> ".identity.mutant")
#else
      (prefix <> ".identity")
#endif
      (componentObservationIdentity component)
    <> retainedObservations retainCompilerArgumentObservations
      (indexedArgumentObservations prefix (componentObservationCompilerArguments component))
    <> retainedObservations retainModuleObservations
      (indexedTextObservations
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPONENT_MODULE_PREFIX_PROJECTION_MUTANT
        (prefix <> ".module.mutant")
#else
        (prefix <> ".module")
#endif
        (componentObservationModules component))
    <> retainedObservations retainSourceFileObservations
      (indexedFilePathObservations
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPONENT_SOURCE_FILE_PREFIX_PROJECTION_MUTANT
        (prefix <> ".source-file.mutant")
#else
        (prefix <> ".source-file")
#endif
        (componentObservationSourceFiles component))
    <> retainedObservations retainHaskellSourceDirectoryObservations
      (indexedFilePathObservations
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPONENT_SOURCE_DIRECTORY_PREFIX_PROJECTION_MUTANT
        (prefix <> ".haskell-source-directory.mutant")
#else
        (prefix <> ".haskell-source-directory")
#endif
        (componentObservationSourceDirectories component))
    <> retainedObservations retainSourceDirectoryObservation
      [observation
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPONENT_SOURCE_ROOT_KEY_PROJECTION_MUTANT
        (prefix <> ".source-directory.mutant")
#else
        (prefix <> ".source-directory")
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPONENT_SOURCE_ROOT_VALUE_PROJECTION_MUTANT
        (Text.pack (componentObservationSourceDirectory component) <> "-mutant")]
#else
        (Text.pack (componentObservationSourceDirectory component))]
#endif
    <> retainedObservations retainCabalFileObservations
      (cabalFileObservations prefix (componentObservationCabalFile component))
    <> retainedObservations retainArgumentPathObservations
      (indexedPathObservations prefix (componentObservationArgumentPaths component))
    <> retainedObservations retainGeneratedInputObservations
      (indexedGeneratedInputObservations prefix
        (componentObservationGeneratedInputs component))
    <> retainedObservations retainPackageObservations
      (indexedPackageObservations prefix (componentObservationPackageIds component))
  )

retainedObservations :: Bool -> [value] -> [value]
retainedObservations True values =
#ifdef VALIDATION_COMPILER_BUILDINFO_RETAINED_OBSERVATIONS_TRUE_ROUTE_DROP_MUTANT
  values `seq` []
#else
  values
#endif
retainedObservations False _ = []

retainInputBytesObservation, retainExpectedCompilerFlavourObservation,
  retainExpectedCompilerIdObservation, retainExpectedCompilerPathObservation,
  retainExpectedComponentCountObservation, retainExpectedIdentityTypeObservation,
  retainExpectedIdentityNameObservation, retainExpectedIdentityUnitObservation,
  retainObservedCabalVersionObservation, retainObservedCompilerFlavourObservation,
  retainObservedCompilerIdObservation, retainObservedCompilerPathObservation,
  retainObservedComponentCountObservation, retainObservedIdentityTypeObservation,
  retainObservedIdentityNameObservation, retainObservedIdentityUnitObservation,
  retainCompilerArgumentObservations, retainModuleObservations,
  retainSourceFileObservations, retainHaskellSourceDirectoryObservations,
  retainSourceDirectoryObservation, retainCabalFileObservations,
  retainArgumentPathObservations, retainGeneratedInputObservations,
  retainPackageObservations :: Bool
#ifdef VALIDATION_COMPILER_BUILDINFO_INPUT_BYTES_OBSERVATION_DROP_MUTANT
retainInputBytesObservation = False
#else
retainInputBytesObservation = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_COMPILER_FLAVOUR_OBSERVATION_DROP_MUTANT
retainExpectedCompilerFlavourObservation = False
#else
retainExpectedCompilerFlavourObservation = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_COMPILER_ID_OBSERVATION_DROP_MUTANT
retainExpectedCompilerIdObservation = False
#else
retainExpectedCompilerIdObservation = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_COMPILER_PATH_OBSERVATION_DROP_MUTANT
retainExpectedCompilerPathObservation = False
#else
retainExpectedCompilerPathObservation = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_COMPONENT_COUNT_OBSERVATION_DROP_MUTANT
retainExpectedComponentCountObservation = False
#else
retainExpectedComponentCountObservation = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_IDENTITY_TYPE_OBSERVATION_DROP_MUTANT
retainExpectedIdentityTypeObservation = False
#else
retainExpectedIdentityTypeObservation = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_IDENTITY_NAME_OBSERVATION_DROP_MUTANT
retainExpectedIdentityNameObservation = False
#else
retainExpectedIdentityNameObservation = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_IDENTITY_UNIT_OBSERVATION_DROP_MUTANT
retainExpectedIdentityUnitObservation = False
#else
retainExpectedIdentityUnitObservation = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_OBSERVED_CABAL_VERSION_OBSERVATION_DROP_MUTANT
retainObservedCabalVersionObservation = False
#else
retainObservedCabalVersionObservation = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_OBSERVED_COMPILER_FLAVOUR_OBSERVATION_DROP_MUTANT
retainObservedCompilerFlavourObservation = False
#else
retainObservedCompilerFlavourObservation = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_OBSERVED_COMPILER_ID_OBSERVATION_DROP_MUTANT
retainObservedCompilerIdObservation = False
#else
retainObservedCompilerIdObservation = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_OBSERVED_COMPILER_PATH_OBSERVATION_DROP_MUTANT
retainObservedCompilerPathObservation = False
#else
retainObservedCompilerPathObservation = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_OBSERVED_COMPONENT_COUNT_OBSERVATION_DROP_MUTANT
retainObservedComponentCountObservation = False
#else
retainObservedComponentCountObservation = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_OBSERVED_IDENTITY_TYPE_OBSERVATION_DROP_MUTANT
retainObservedIdentityTypeObservation = False
#else
retainObservedIdentityTypeObservation = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_OBSERVED_IDENTITY_NAME_OBSERVATION_DROP_MUTANT
retainObservedIdentityNameObservation = False
#else
retainObservedIdentityNameObservation = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_OBSERVED_IDENTITY_UNIT_OBSERVATION_DROP_MUTANT
retainObservedIdentityUnitObservation = False
#else
retainObservedIdentityUnitObservation = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPILER_ARGUMENT_OBSERVATION_DROP_MUTANT
retainCompilerArgumentObservations = False
#else
retainCompilerArgumentObservations = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_MODULE_OBSERVATION_DROP_MUTANT
retainModuleObservations = False
#else
retainModuleObservations = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_RETENTION_DROP_MUTANT
retainSourceFileObservations = False
#else
retainSourceFileObservations = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_HS_SOURCE_DIR_OBSERVATION_DROP_MUTANT
retainHaskellSourceDirectoryObservations = False
#else
retainHaskellSourceDirectoryObservations = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_SOURCE_DIR_OBSERVATION_DROP_MUTANT
retainSourceDirectoryObservation = False
#else
retainSourceDirectoryObservation = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_CABAL_FILE_OBSERVATION_DROP_MUTANT
retainCabalFileObservations = False
#else
retainCabalFileObservations = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_PATH_OBSERVATION_DROP_MUTANT
retainArgumentPathObservations = False
#else
retainArgumentPathObservations = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_GENERATED_INPUT_OBSERVATION_DROP_MUTANT
retainGeneratedInputObservations = False
#else
retainGeneratedInputObservations = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_PACKAGE_OBSERVATION_DROP_MUTANT
retainPackageObservations = False
#else
retainPackageObservations = True
#endif

indexedTextObservations :: Text -> [Text] -> [Observation]
indexedTextObservations prefix values =
  observation
#ifdef VALIDATION_COMPILER_BUILDINFO_INDEXED_TEXT_COUNT_KEY_PROJECTION_MUTANT
    (prefix <> ".count.mutant")
#else
    (prefix <> ".count")
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_INDEXED_TEXT_COUNT_VALUE_PROJECTION_MUTANT
    (decimal (length values + 1))
#else
    (decimal (length values))
#endif
    : [observation
#ifdef VALIDATION_COMPILER_BUILDINFO_INDEXED_TEXT_INDEX_KEY_PROJECTION_MUTANT
        (prefix <> "." <> decimal (index + 1))
#else
        (prefix <> "." <> decimal index)
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_INDEXED_TEXT_INDEX_VALUE_PROJECTION_MUTANT
        (value <> "-mutant")
#else
        value
#endif
      | (index, value) <- zip [0 :: Int ..] values]

indexedFilePathObservations :: Text -> [FilePath] -> [Observation]
indexedFilePathObservations prefix paths =
  indexedTextObservations prefix
#ifdef VALIDATION_COMPILER_BUILDINFO_INDEXED_FILE_PATH_TEXT_MAPPING_MUTANT
    [Text.pack path <> "-mutant" | path <- paths]
#else
    (map Text.pack paths)
#endif

cabalFileObservations :: Text -> Maybe FilePath -> [Observation]
cabalFileObservations prefix Nothing =
  [observation
#ifdef VALIDATION_COMPILER_BUILDINFO_CABAL_FILE_ABSENT_KEY_PROJECTION_MUTANT
    (prefix <> ".cabal-file.present.mutant")
#else
    (prefix <> ".cabal-file.present")
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_CABAL_FILE_ABSENT_VALUE_PROJECTION_MUTANT
    "false-mutant"]
#else
    "false"]
#endif
cabalFileObservations prefix (Just path) =
  [ observation
#ifdef VALIDATION_COMPILER_BUILDINFO_CABAL_FILE_PRESENT_KEY_PROJECTION_MUTANT
      (prefix <> ".cabal-file.present.mutant")
#else
      (prefix <> ".cabal-file.present")
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_CABAL_FILE_PRESENT_VALUE_PROJECTION_MUTANT
      "true-mutant"
#else
      "true"
#endif
  , observation
#ifdef VALIDATION_COMPILER_BUILDINFO_CABAL_FILE_PATH_KEY_PROJECTION_MUTANT
      (prefix <> ".cabal-file.path.mutant")
#else
      (prefix <> ".cabal-file.path")
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_CABAL_FILE_PATH_VALUE_PROJECTION_MUTANT
      (Text.pack path <> "/mutant")
#else
      (Text.pack path)
#endif
  ]

indexedArgumentObservations
  :: Text
  -> [DiagnosticCompilerBuildInfoArgumentObservation]
  -> [Observation]
indexedArgumentObservations componentPrefix values =
  observation
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_COUNT_KEY_PROJECTION_MUTANT
    (componentPrefix <> ".compiler-argument.count.mutant")
#else
    (componentPrefix <> ".compiler-argument.count")
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_COUNT_VALUE_PROJECTION_MUTANT
    (decimal (length values + 1))
#else
    (decimal (length values))
#endif
    : concat
      [argumentObservations
        (componentPrefix <> ".compiler-argument." <>
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_ORDINAL_PROJECTION_MUTANT
          decimal (ordinal + 1))
#else
          decimal ordinal)
#endif
        value
      | (ordinal, value) <- zip [0 :: Int ..] values]

argumentObservations :: Text -> DiagnosticCompilerBuildInfoArgumentObservation -> [Observation]
argumentObservations prefix argument = case argument of
  DiagnosticCompilerBuildInfoBoundaryArgument optionIndex option ->
    optionOnly
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_BOUNDARY_KIND_VALUE_PROJECTION_MUTANT
      "package-boundary-mutant"
#else
      "package-boundary"
#endif
      optionIndex option
  DiagnosticCompilerBuildInfoThisUnitArgument optionIndex option valueIndex value ->
    optionValue
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_THIS_UNIT_KIND_VALUE_PROJECTION_MUTANT
      "this-unit-mutant"
#else
      "this-unit"
#endif
      optionIndex option valueIndex value
  DiagnosticCompilerBuildInfoPackageArgument optionIndex option valueIndex value ->
    optionValue
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_PACKAGE_KIND_VALUE_PROJECTION_MUTANT
      "package-mutant"
#else
      "package"
#endif
      optionIndex option valueIndex value
  DiagnosticCompilerBuildInfoPathArgument optionIndex option valueIndex raw path ->
    optionOnly
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_PATH_KIND_VALUE_PROJECTION_MUTANT
      "path-mutant"
#else
      "path"
#endif
      optionIndex option
      <> maybe [] (\index -> [observation
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_PATH_VALUE_INDEX_KEY_PROJECTION_MUTANT
            (prefix <> ".value-index.mutant")
#else
            (prefix <> ".value-index")
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_PATH_VALUE_INDEX_VALUE_PROJECTION_MUTANT
            (decimal (index + 1))])
#else
            (decimal index)])
#endif
        valueIndex
      <> [ observation
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_RAW_KEY_PROJECTION_MUTANT
            (prefix <> ".raw.mutant")
#else
            (prefix <> ".raw")
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_RAW_VALUE_PROJECTION_MUTANT
            (raw <> "-mutant")
#else
            raw
#endif
         , observation
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_PATH_KEY_PROJECTION_MUTANT
            (prefix <> ".path.mutant")
#else
            (prefix <> ".path")
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_PATH_VALUE_PROJECTION_MUTANT
            (Text.pack path <> "/mutant")
#else
            (Text.pack path)
#endif
         ]
  DiagnosticCompilerBuildInfoGeneratedInputArgument optionIndex option valueIndex raw path ->
    optionValue
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_GENERATED_KIND_VALUE_PROJECTION_MUTANT
      "generated-input-mutant"
#else
      "generated-input"
#endif
      optionIndex option valueIndex raw
      <> [observation
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_GENERATED_PATH_KEY_PROJECTION_MUTANT
            (prefix <> ".path.mutant")
#else
            (prefix <> ".path")
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_GENERATED_PATH_VALUE_PROJECTION_MUTANT
            (Text.pack path <> "/mutant")]
#else
            (Text.pack path)]
#endif
  DiagnosticCompilerBuildInfoStandaloneArgument optionIndex option ->
    optionOnly
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_STANDALONE_KIND_VALUE_PROJECTION_MUTANT
      "standalone-mutant"
#else
      "standalone"
#endif
      optionIndex option
  DiagnosticCompilerBuildInfoBypassedArgument optionIndex option ->
    optionOnly "bypassed" optionIndex option
 where
  optionOnly kind optionIndex option =
    [ observation
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_KIND_KEY_PROJECTION_MUTANT
        (prefix <> ".kind.mutant")
#else
        (prefix <> ".kind")
#endif
        kind
    , observation
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_OPTION_INDEX_KEY_PROJECTION_MUTANT
        (prefix <> ".option-index.mutant")
#else
        (prefix <> ".option-index")
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_OPTION_INDEX_VALUE_PROJECTION_MUTANT
        (decimal (optionIndex + 1))
#else
        (decimal optionIndex)
#endif
    , observation
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_OPTION_KEY_PROJECTION_MUTANT
        (prefix <> ".option.mutant")
#else
        (prefix <> ".option")
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_OPTION_VALUE_PROJECTION_MUTANT
        (option <> "-mutant")
#else
        option
#endif
    ]
  optionValue kind optionIndex option valueIndex value =
    optionOnly kind optionIndex option
      <> [ observation
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_VALUE_INDEX_KEY_PROJECTION_MUTANT
            (prefix <> ".value-index.mutant")
#else
            (prefix <> ".value-index")
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_VALUE_INDEX_VALUE_PROJECTION_MUTANT
            (decimal (valueIndex + 1))
#else
            (decimal valueIndex)
#endif
         , observation
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_VALUE_KEY_PROJECTION_MUTANT
            (prefix <> ".value.mutant")
#else
            (prefix <> ".value")
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_VALUE_VALUE_PROJECTION_MUTANT
            (value <> "-mutant")
#else
            value
#endif
         ]

indexedPathObservations
  :: Text
  -> [DiagnosticCompilerBuildInfoPathObservation]
  -> [Observation]
indexedPathObservations componentPrefix values =
  observation
#ifdef VALIDATION_COMPILER_BUILDINFO_PATH_OBSERVATION_COUNT_KEY_PROJECTION_MUTANT
    (componentPrefix <> ".argument-path.count.mutant")
#else
    (componentPrefix <> ".argument-path.count")
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_PATH_OBSERVATION_COUNT_VALUE_PROJECTION_MUTANT
    (decimal (length values + 1))
#else
    (decimal (length values))
#endif
    : concat
      [ case value of
          DiagnosticCompilerBuildInfoPathObservation optionIndex option valueIndex path ->
            [ observation
#ifdef VALIDATION_COMPILER_BUILDINFO_PATH_OBSERVATION_OPTION_INDEX_KEY_PROJECTION_MUTANT
                (prefix <> ".option-index.mutant")
#else
                (prefix <> ".option-index")
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_PATH_OBSERVATION_OPTION_INDEX_VALUE_PROJECTION_MUTANT
                (decimal (optionIndex + 1))
#else
                (decimal optionIndex)
#endif
            , observation
#ifdef VALIDATION_COMPILER_BUILDINFO_PATH_OBSERVATION_OPTION_KEY_PROJECTION_MUTANT
                (prefix <> ".option.mutant")
#else
                (prefix <> ".option")
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_PATH_OBSERVATION_OPTION_VALUE_PROJECTION_MUTANT
                (option <> "-mutant")
#else
                option
#endif
            ]
              <> maybe [] (\index ->
                [observation
#ifdef VALIDATION_COMPILER_BUILDINFO_PATH_OBSERVATION_VALUE_INDEX_KEY_PROJECTION_MUTANT
                  (prefix <> ".value-index.mutant")
#else
                  (prefix <> ".value-index")
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_PATH_OBSERVATION_VALUE_INDEX_VALUE_PROJECTION_MUTANT
                  (decimal (index + 1))])
#else
                  (decimal index)])
#endif
                valueIndex
              <> [observation
#ifdef VALIDATION_COMPILER_BUILDINFO_PATH_OBSERVATION_PATH_KEY_PROJECTION_MUTANT
                    (prefix <> ".path.mutant")
#else
                    (prefix <> ".path")
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_PATH_OBSERVATION_PATH_VALUE_PROJECTION_MUTANT
                    (Text.pack path <> "/mutant")]
#else
                    (Text.pack path)]
#endif
      | (ordinal, value) <- zip [0 :: Int ..] values
      , let prefix = componentPrefix <> ".argument-path." <>
#ifdef VALIDATION_COMPILER_BUILDINFO_PATH_OBSERVATION_ORDINAL_PROJECTION_MUTANT
              decimal (ordinal + 1)
#else
              decimal ordinal
#endif
      ]

indexedGeneratedInputObservations
  :: Text
  -> [DiagnosticCompilerBuildInfoGeneratedInputObservation]
  -> [Observation]
indexedGeneratedInputObservations componentPrefix values =
  observation
#ifdef VALIDATION_COMPILER_BUILDINFO_GENERATED_OBSERVATION_COUNT_KEY_PROJECTION_MUTANT
    (componentPrefix <> ".generated-input.count.mutant")
#else
    (componentPrefix <> ".generated-input.count")
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_GENERATED_OBSERVATION_COUNT_VALUE_PROJECTION_MUTANT
    (decimal (length values + 1))
#else
    (decimal (length values))
#endif
    : concat
      [ case value of
          DiagnosticCompilerBuildInfoGeneratedInputObservation
            optionIndex option valueIndex raw path ->
              [ observation
#ifdef VALIDATION_COMPILER_BUILDINFO_GENERATED_OBSERVATION_OPTION_INDEX_KEY_PROJECTION_MUTANT
                  (prefix <> ".option-index.mutant")
#else
                  (prefix <> ".option-index")
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_GENERATED_OBSERVATION_OPTION_INDEX_VALUE_PROJECTION_MUTANT
                  (decimal (optionIndex + 1))
#else
                  (decimal optionIndex)
#endif
              , observation
#ifdef VALIDATION_COMPILER_BUILDINFO_GENERATED_OBSERVATION_OPTION_KEY_PROJECTION_MUTANT
                  (prefix <> ".option.mutant")
#else
                  (prefix <> ".option")
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_GENERATED_OBSERVATION_OPTION_VALUE_PROJECTION_MUTANT
                  (option <> "-mutant")
#else
                  option
#endif
              , observation
#ifdef VALIDATION_COMPILER_BUILDINFO_GENERATED_OBSERVATION_VALUE_INDEX_KEY_PROJECTION_MUTANT
                  (prefix <> ".value-index.mutant")
#else
                  (prefix <> ".value-index")
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_GENERATED_OBSERVATION_VALUE_INDEX_VALUE_PROJECTION_MUTANT
                  (decimal (valueIndex + 1))
#else
                  (decimal valueIndex)
#endif
              , observation
#ifdef VALIDATION_COMPILER_BUILDINFO_GENERATED_OBSERVATION_RAW_KEY_PROJECTION_MUTANT
                  (prefix <> ".raw.mutant")
#else
                  (prefix <> ".raw")
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_GENERATED_OBSERVATION_RAW_VALUE_PROJECTION_MUTANT
                  (raw <> "-mutant")
#else
                  raw
#endif
              , observation
#ifdef VALIDATION_COMPILER_BUILDINFO_GENERATED_OBSERVATION_PATH_KEY_PROJECTION_MUTANT
                  (prefix <> ".path.mutant")
#else
                  (prefix <> ".path")
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_GENERATED_OBSERVATION_PATH_VALUE_PROJECTION_MUTANT
                  (Text.pack path <> "/mutant")
#else
                  (Text.pack path)
#endif
              ]
      | (ordinal, value) <- zip [0 :: Int ..] values
      , let prefix = componentPrefix <> ".generated-input." <>
#ifdef VALIDATION_COMPILER_BUILDINFO_GENERATED_OBSERVATION_ORDINAL_PROJECTION_MUTANT
              decimal (ordinal + 1)
#else
              decimal ordinal
#endif
      ]

indexedPackageObservations
  :: Text
  -> [DiagnosticCompilerBuildInfoPackageObservation]
  -> [Observation]
indexedPackageObservations componentPrefix values =
  observation
#ifdef VALIDATION_COMPILER_BUILDINFO_PACKAGE_OBSERVATION_COUNT_KEY_PROJECTION_MUTANT
    (componentPrefix <> ".package.count.mutant")
#else
    (componentPrefix <> ".package.count")
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_PACKAGE_OBSERVATION_COUNT_VALUE_PROJECTION_MUTANT
    (decimal (length values + 1))
#else
    (decimal (length values))
#endif
    : concat
      [ case value of
          DiagnosticCompilerBuildInfoPackageObservation optionIndex option valueIndex valueText ->
            [ observation
#ifdef VALIDATION_COMPILER_BUILDINFO_PACKAGE_OBSERVATION_OPTION_INDEX_KEY_PROJECTION_MUTANT
                (prefix <> ".option-index.mutant")
#else
                (prefix <> ".option-index")
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_PACKAGE_OBSERVATION_OPTION_INDEX_VALUE_PROJECTION_MUTANT
                (decimal (optionIndex + 1))
#else
                (decimal optionIndex)
#endif
            , observation
#ifdef VALIDATION_COMPILER_BUILDINFO_PACKAGE_OBSERVATION_OPTION_KEY_PROJECTION_MUTANT
                (prefix <> ".option.mutant")
#else
                (prefix <> ".option")
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_PACKAGE_OBSERVATION_OPTION_VALUE_PROJECTION_MUTANT
                (option <> "-mutant")
#else
                option
#endif
            , observation
#ifdef VALIDATION_COMPILER_BUILDINFO_PACKAGE_OBSERVATION_VALUE_INDEX_KEY_PROJECTION_MUTANT
                (prefix <> ".value-index.mutant")
#else
                (prefix <> ".value-index")
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_PACKAGE_OBSERVATION_VALUE_INDEX_VALUE_PROJECTION_MUTANT
                (decimal (valueIndex + 1))
#else
                (decimal valueIndex)
#endif
            , observation
#ifdef VALIDATION_COMPILER_BUILDINFO_PACKAGE_OBSERVATION_VALUE_KEY_PROJECTION_MUTANT
                (prefix <> ".value.mutant")
#else
                (prefix <> ".value")
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_PACKAGE_OBSERVATION_VALUE_VALUE_PROJECTION_MUTANT
                (valueText <> "-mutant")
#else
                valueText
#endif
            ]
      | (ordinal, value) <- zip [0 :: Int ..] values
      , let prefix = componentPrefix <> ".package." <>
#ifdef VALIDATION_COMPILER_BUILDINFO_PACKAGE_OBSERVATION_ORDINAL_PROJECTION_MUTANT
              decimal (ordinal + 1)
#else
              decimal ordinal
#endif
      ]

decimal :: Int -> Text
decimal value = Text.pack (show
#ifdef VALIDATION_COMPILER_BUILDINFO_DECIMAL_TEXT_MAPPING_MUTANT
  (value + 1)
#else
  value
#endif
  )

parseCompilerBuildInfoDiagnostic
  :: DiagnosticCompilerBuildInfoExpectedCompiler
  -> [DiagnosticCompilerBuildInfoExpectedIdentity]
  -> ByteString
  -> DiagnosticCompilerBuildInfoRefusal
parseCompilerBuildInfoDiagnostic expectedCompiler expectedIdentities bytes
  | inputLength > maximumBuildInfoBytes =
      singleProblemRefusal
        (BuildInfoResourceLimitExceeded "input-bytes" maximumBuildInfoBytes inputLength)
  | otherwise =
      case scanDuplicateJsonKeys bytes of
        Left problem ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PARSE_DUPLICATE_SCAN_LEFT_ROUTE_MUTANT
          hardRefusal [problem, problem]
#else
          singleProblemRefusal problem
#endif
        Right () ->
              case eitherDecodeStrict' bytes of
                Left message ->
                  singleProblemRefusal
                    (BuildInfoDuplicateKeyScanFailed
                      ("bounded JSON scanner and Aeson decoder disagreed: "
                        <> Text.pack message))
                Right (Object root) ->
#ifdef VALIDATION_COMPILER_BUILDINFO_PARSE_OBJECT_ROUTE_MUTANT
                  parseBuildInfoRoot expectedCompiler expectedIdentities root `seq`
                    hardRefusal
                      [BuildInfoDuplicateKeyScanFailed "object decode route mutated"]
#else
                  parseBuildInfoRoot expectedCompiler expectedIdentities root
#endif
                Right _
                  | enforceRootObject -> singleProblemRefusal BuildInfoRootNotObject
                  | otherwise -> hardRefusal []
 where
  inputLength = ByteString.length bytes
#ifdef VALIDATION_COMPILER_BUILDINFO_PARSE_INPUT_LENGTH_INCREMENT_MUTANT
    + 1
#endif
parseBuildInfoRoot
  :: DiagnosticCompilerBuildInfoExpectedCompiler
  -> [DiagnosticCompilerBuildInfoExpectedIdentity]
  -> Object
  -> DiagnosticCompilerBuildInfoRefusal
parseBuildInfoRoot expectedCompiler expectedIdentities root =
  case (parsedValue cabalVersion, parsedValue compilerObject, parsedValue componentValues) of
    (Just observedVersion, Just encodedCompiler, Just encodedComponents)
      | not (null rootProblems) -> hardRefusal rootProblems
      | componentCount > maximumBuildInfoComponents ->
          singleProblemRefusal
            (BuildInfoResourceLimitExceeded "components" maximumBuildInfoComponents componentCount)
      | otherwise ->
#ifdef VALIDATION_COMPILER_BUILDINFO_ROOT_SUCCESS_TUPLE_ROUTE_MUTANT
          parseBuildInfoBody expectedCompiler expectedIdentities observedVersion
            encodedCompiler encodedComponents `seq`
              hardRefusal
                [BuildInfoDuplicateKeyScanFailed "root success tuple route mutated"]
#else
          parseBuildInfoBody expectedCompiler expectedIdentities observedVersion
            encodedCompiler encodedComponents
#endif
    _ -> hardRefusal rootProblems
 where
  scope = "build-info"
  allowed = Set.fromList ["cabal-lib-version", "compiler", "components"]
  cabalVersion = requiredText scope root "cabal-lib-version"
  compilerObject = requiredObject scope root "compiler"
  componentValues = requiredArray scope root "components"
  componentCount =
    maybe 0 (boundedLength (maximumBuildInfoComponents + 1)) (parsedValue componentValues)
  versionProblems = case parsedValue cabalVersion of
    Just observed
      | observed /= supportedCompilerBuildInfoCabalLibraryVersion ->
          [BuildInfoCabalLibraryVersionUnsupported
            supportedCompilerBuildInfoCabalLibraryVersion observed]
    _ -> []
  rootProblems =
    unknownFields scope allowed root <> parsedProblems cabalVersion
      <> parsedProblems compilerObject <> parsedProblems componentValues <> versionProblems

parseBuildInfoBody
  :: DiagnosticCompilerBuildInfoExpectedCompiler
  -> [DiagnosticCompilerBuildInfoExpectedIdentity]
  -> Text
  -> Object
  -> [Value]
  -> DiagnosticCompilerBuildInfoRefusal
parseBuildInfoBody expectedCompiler expectedIdentities cabalVersion compilerObject encodedComponents =
  case (parsedValue parsedCompiler, partitionedComponents) of
    (Just compilerIdentity, (_, Just parsedComponentValues))
      | not (null syntaxAndSemanticProblems) ->
#ifdef VALIDATION_COMPILER_BUILDINFO_BODY_SYNTAX_REFUSAL_ROUTE_MUTANT
          hardRefusal (syntaxAndSemanticProblems <> syntaxAndSemanticProblems)
#else
          hardRefusal syntaxAndSemanticProblems
#endif
      | not (null identityProblems) ->
#ifdef VALIDATION_COMPILER_BUILDINFO_BODY_IDENTITY_REFUSAL_ROUTE_MUTANT
          hardRefusal (identityProblems <> identityProblems)
#else
          hardRefusal identityProblems
#endif
      | otherwise ->
#ifdef VALIDATION_COMPILER_BUILDINFO_BODY_OBSERVED_REFUSAL_ROUTE_MUTANT
          let permanent =
                permanentProblems expectedCompiler expectedIdentities cabalVersion
                  compilerIdentity parsedComponentValues
              snapshot =
                makeSnapshot expectedCompiler expectedIdentities cabalVersion
                  compilerIdentity parsedComponentValues
           in observedRefusal permanent snapshot `seq` hardRefusal permanent
#else
          observedRefusal
            (permanentProblems expectedCompiler expectedIdentities cabalVersion
              compilerIdentity parsedComponentValues)
            (makeSnapshot expectedCompiler expectedIdentities cabalVersion
              compilerIdentity parsedComponentValues)
#endif
    _ ->
#ifdef VALIDATION_COMPILER_BUILDINFO_BODY_PARSE_FALLBACK_ROUTE_MUTANT
      hardRefusal (syntaxAndSemanticProblems <> syntaxAndSemanticProblems)
#else
      hardRefusal syntaxAndSemanticProblems
#endif
 where
  parsedCompiler = parseCompilerIdentity compilerObject
  parsedComponents = zipWith parseBuildInfoComponent [0 ..] encodedComponents
  partitionedComponents = partitionParsed parsedComponents
  emptyProblems =
    [BuildInfoComponentsEmpty | enforceComponentsNonEmpty, null encodedComponents]
  syntaxAndSemanticProblems =
    emptyProblems <> parsedProblems parsedCompiler <> fst partitionedComponents
  components = maybe [] id (snd partitionedComponents)
  identityProblems =
    componentIdentityProblems components
      <> compilerExpectationProblems expectedCompiler parsedCompiler
      <> expectedIdentityProblems expectedIdentities components

enforceRootObject, enforceComponentsNonEmpty :: Bool
#ifdef VALIDATION_COMPILER_BUILDINFO_ROOT_OBJECT_BYPASS_MUTANT
enforceRootObject = False
#else
enforceRootObject = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPONENTS_EMPTY_BYPASS_MUTANT
enforceComponentsNonEmpty = False
#else
enforceComponentsNonEmpty = True
#endif

makeSnapshot
  :: DiagnosticCompilerBuildInfoExpectedCompiler
  -> [DiagnosticCompilerBuildInfoExpectedIdentity]
  -> Text
  -> CompilerIdentity
  -> [DiagnosticCompilerBuildInfoComponentObservation]
  -> DiagnosticCompilerBuildInfoSnapshot
makeSnapshot expectedCompiler expectedIdentities cabalVersion
  (CompilerIdentity flavour compilerId compilerPath) components =
    DiagnosticCompilerBuildInfoSnapshot
      (DiagnosticCompilerBuildInfoExpectations expectedCompiler expectedIdentities)
      cabalVersion flavour compilerId compilerPath
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPONENT_ORDER_BYPASS_MUTANT
      (sortOn (const ()) components)
#else
      (sortOn componentObservationIdentity components)
#endif

permanentProblems
  :: DiagnosticCompilerBuildInfoExpectedCompiler
  -> [DiagnosticCompilerBuildInfoExpectedIdentity]
  -> Text
  -> CompilerIdentity
  -> [DiagnosticCompilerBuildInfoComponentObservation]
  -> [DiagnosticCompilerBuildInfoProblem]
permanentProblems _expectedCompiler expectedIdentities cabalVersion
  (CompilerIdentity flavour compilerId compilerPath) components =
    (concat
      [ retainedProblem retainGeneratorBytesResidue
          (BuildInfoGeneratorBytesUnauthenticated cabalVersion)
      , retainedProblem retainCompilerIdentityResidue
          (BuildInfoCompilerIdentityUnauthenticated flavour compilerId compilerPath)
      , retainedProblem retainIndependentCompilerResidue
          BuildInfoIndependentExpectedCompilerUnavailable
      , retainedProblem retainMachinePathStateResidue
          BuildInfoMachinePathStateUnauthenticated
      , retainedProblem retainCompilerArgumentsResidue
          (BuildInfoCompilerArgumentsUnauthenticated
            [(componentObservationIdentity component,
              componentObservationCompilerArguments component)
            | component <- components])
      , retainedProblem retainDuplicateKeyObserverResidue
          BuildInfoDuplicateKeyDetectionDiagnosticOnly
      , retainedProblem retainIndependentUniverseResidue
          (BuildInfoIndependentExpectedUniverseUnavailable
            (sort (map expectedIdentityComponent expectedIdentities)))
      , retainedProblem retainSourceOwnershipResidue
          BuildInfoExactModuleSourceOwnershipUnresolved
      , retainedProblem retainCabalJoinResidue
          (BuildInfoCabalFileSourceJoinUnavailable
            (sort
              [(componentObservationIdentity component,
                componentObservationCabalFile component)
              | component <- components]))
      , retainedProblem retainGeneratedInputResidue
          (BuildInfoGeneratedCompilerInputsUnauthenticated
            [(componentObservationIdentity component,
              componentObservationGeneratedInputs component)
            | component <- components])
      , retainedProblem retainPackageDependencyResidue
          (BuildInfoPackageDependencyJoinUnavailable
            [(componentObservationIdentity component,
              componentObservationPackageIds component)
            | component <- components])
      , retainedProblem retainConfigurationJoinResidue
          (BuildInfoConfigurationJoinUnavailable
            (sort (map componentObservationIdentity components)))
      , retainedProblem retainPragmaSemanticsResidue
          (BuildInfoSourcePragmaSemanticsUnavailable
            (sort (map componentObservationIdentity components)))
      , retainedProblem retainPhysicalPathContainmentResidue
          BuildInfoPhysicalPathContainmentUnavailable
      , retainedProblem retainPlatformResidue
          (BuildInfoPathPlatformSemanticsUnavailable "posix-lexical-only")
      , retainedProblem retainElaboratedPlanJoinResidue
          (BuildInfoElaboratedPlanJoinUnavailable
            (sort (map componentObservationIdentity components)))
      , retainedProblem retainCompilerInvocationResidue
          (BuildInfoCompilerInvocationUnavailable flavour compilerId compilerPath)
      , retainedProblem retainOracleResidue BuildInfoOracleQualificationUnavailable
      ])
retainedProblem :: Bool -> problem -> [problem]
retainedProblem True problem =
#ifdef VALIDATION_COMPILER_BUILDINFO_RETAINED_PROBLEM_TRUE_ROUTE_DUPLICATE_MUTANT
  [problem, problem]
#else
  [problem]
#endif
retainedProblem False _ = []

retainGeneratorBytesResidue, retainCompilerIdentityResidue,
  retainIndependentCompilerResidue, retainMachinePathStateResidue,
  retainCompilerArgumentsResidue, retainDuplicateKeyObserverResidue,
  retainIndependentUniverseResidue, retainSourceOwnershipResidue,
  retainCabalJoinResidue, retainGeneratedInputResidue,
  retainPackageDependencyResidue, retainConfigurationJoinResidue,
  retainPragmaSemanticsResidue, retainPhysicalPathContainmentResidue,
  retainPlatformResidue, retainElaboratedPlanJoinResidue,
  retainCompilerInvocationResidue, retainOracleResidue :: Bool
#ifdef VALIDATION_COMPILER_BUILDINFO_GENERATOR_BYTES_RESIDUE_DROP_MUTANT
retainGeneratorBytesResidue = False
#else
retainGeneratorBytesResidue = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPILER_IDENTITY_RESIDUE_DROP_MUTANT
retainCompilerIdentityResidue = False
#else
retainCompilerIdentityResidue = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_INDEPENDENT_COMPILER_RESIDUE_DROP_MUTANT
retainIndependentCompilerResidue = False
#else
retainIndependentCompilerResidue = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_MACHINE_PATH_STATE_RESIDUE_DROP_MUTANT
retainMachinePathStateResidue = False
#else
retainMachinePathStateResidue = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPILER_ARGUMENTS_RESIDUE_DROP_MUTANT
retainCompilerArgumentsResidue = False
#else
retainCompilerArgumentsResidue = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_DUPLICATE_KEY_OBSERVER_RESIDUE_DROP_MUTANT
retainDuplicateKeyObserverResidue = False
#else
retainDuplicateKeyObserverResidue = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_INDEPENDENT_UNIVERSE_RESIDUE_DROP_MUTANT
retainIndependentUniverseResidue = False
#else
retainIndependentUniverseResidue = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_SOURCE_OWNERSHIP_RESIDUE_DROP_MUTANT
retainSourceOwnershipResidue = False
#else
retainSourceOwnershipResidue = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_CABAL_JOIN_RESIDUE_BYPASS_MUTANT
retainCabalJoinResidue = False
#else
retainCabalJoinResidue = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_GENERATED_INPUT_RESIDUE_BYPASS_MUTANT
retainGeneratedInputResidue = False
#else
retainGeneratedInputResidue = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_PACKAGE_DEPENDENCY_RESIDUE_DROP_MUTANT
retainPackageDependencyResidue = False
#else
retainPackageDependencyResidue = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_CONFIGURATION_JOIN_RESIDUE_DROP_MUTANT
retainConfigurationJoinResidue = False
#else
retainConfigurationJoinResidue = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_PRAGMA_SEMANTICS_RESIDUE_DROP_MUTANT
retainPragmaSemanticsResidue = False
#else
retainPragmaSemanticsResidue = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_PHYSICAL_PATH_CONTAINMENT_RESIDUE_DROP_MUTANT
retainPhysicalPathContainmentResidue = False
#else
retainPhysicalPathContainmentResidue = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_PLATFORM_RESIDUE_BYPASS_MUTANT
retainPlatformResidue = False
#else
retainPlatformResidue = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_ELABORATED_PLAN_JOIN_RESIDUE_DROP_MUTANT
retainElaboratedPlanJoinResidue = False
#else
retainElaboratedPlanJoinResidue = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPILER_INVOCATION_RESIDUE_DROP_MUTANT
retainCompilerInvocationResidue = False
#else
retainCompilerInvocationResidue = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_ORACLE_RESIDUE_BYPASS_MUTANT
retainOracleResidue = False
#else
retainOracleResidue = True
#endif

parseCompilerIdentity :: Object -> Parsed CompilerIdentity
parseCompilerIdentity object =
  case (parsedValue flavourField, parsedValue compilerIdField, parsedValue pathField) of
    (Just flavour, Just compilerId, Just path) ->
      Parsed (problems <> compilerIdentityProblems flavour compilerId path)
        (Just (CompilerIdentity flavour compilerId path))
    _ -> Parsed problems Nothing
 where
  scope = "build-info.compiler"
  allowed = Set.fromList ["flavour", "compiler-id", "path"]
  flavourField = requiredText scope object "flavour"
  compilerIdField = requiredText scope object "compiler-id"
  pathField = requiredFilePath scope object "path"
  problems =
    unknownFields scope allowed object <> parsedProblems flavourField
      <> parsedProblems compilerIdField <> parsedProblems pathField

compilerIdentityProblems :: Text -> Text -> FilePath -> [DiagnosticCompilerBuildInfoProblem]
compilerIdentityProblems flavour compilerId compilerPath =
  [BuildInfoCompilerFlavourUnsupported flavour
  | enforceObservedCompilerFlavour,
    flavour /= "ghc"]
    <> [BuildInfoCompilerIdMalformed compilerId
       | enforceObservedCompilerId,
         not (validCompilerId maximumObservedCompilerIdBytes compilerId)]
    <> [BuildInfoPathUnsafe "build-info.compiler" "path" compilerPath
       | enforceObservedCompilerPath,
         not (safeAbsolutePath compilerPath)]

parseBuildInfoComponent :: Int -> Value -> Parsed DiagnosticCompilerBuildInfoComponentObservation
parseBuildInfoComponent index (Object object) =
  case (parsedValue typeField, parsedValue nameField, parsedValue unitIdField,
        parsedValue compilerArgumentsField, parsedValue modulesField,
        parsedValue sourceFilesField, parsedValue sourceDirectoriesField,
        parsedValue sourceDirectoryField, parsedValue cabalFileField) of
    (Just componentType, Just componentName, Just unitId, Just compilerArguments,
     Just modules, Just sourceFiles, Just sourceDirectories, Just sourceDirectory,
     Just cabalFile) ->
      let argumentInspection = inspectCompilerArguments unitId compilerArguments
          identity =
            DiagnosticCompilerBuildInfoComponentIdentity componentType componentName unitId
          component =
            DiagnosticCompilerBuildInfoComponentObservation identity
              (argumentInspectionArguments argumentInspection)
              modules sourceFiles sourceDirectories sourceDirectory cabalFile
              (argumentInspectionPaths argumentInspection)
              (argumentInspectionGeneratedInputs argumentInspection)
              (argumentInspectionPackageIds argumentInspection)
       in Parsed
            (problems <> validateComponent index component
              <> argumentInspectionProblems argumentInspection)
            (Just component)
    _ -> Parsed problems Nothing
 where
  scope = componentScope index
  allowed = Set.fromList
    ["type", "name", "unit-id", "compiler-args", "modules", "src-files",
     "hs-src-dirs", "src-dir", "cabal-file"]
  typeField = requiredText scope object "type"
  nameField = requiredText scope object "name"
  unitIdField = requiredText scope object "unit-id"
  compilerArgumentsField =
    requiredTextArray maximumCompilerArgumentArrayElements scope object "compiler-args"
  modulesField = requiredTextArray maximumModuleArrayElements scope object "modules"
  sourceFilesField =
    requiredFilePathArray maximumSourceFileArrayElements scope object "src-files"
  sourceDirectoriesField =
    requiredFilePathArray
      maximumSourceDirectoryArrayElements scope object "hs-src-dirs"
  sourceDirectoryField = requiredFilePath scope object "src-dir"
  cabalFileField = optionalFilePath scope object "cabal-file"
  problems =
    unknownFields scope allowed object <> parsedProblems typeField <> parsedProblems nameField
      <> parsedProblems unitIdField <> parsedProblems compilerArgumentsField
      <> parsedProblems modulesField <> parsedProblems sourceFilesField
      <> parsedProblems sourceDirectoriesField <> parsedProblems sourceDirectoryField
      <> parsedProblems cabalFileField
parseBuildInfoComponent index _ =
  Parsed
    [BuildInfoFieldWrongType (componentScope index) "<component>" "object"
    | enforceComponentObject]
    Nothing

validateComponent
  :: Int
  -> DiagnosticCompilerBuildInfoComponentObservation
  -> [DiagnosticCompilerBuildInfoProblem]
validateComponent index component =
  typeProblems <> nameProblems <> unitProblems <> discoveryProblems <> moduleProblems
    <> duplicatePathProblems <> sourceDirectoryProblems
    <> concatMap (sourceChildPathProblems unitId "src-files" False sourceDirectory) sourceFiles
    <> concatMap (sourceChildPathProblems unitId "hs-src-dirs" True sourceDirectory) sourceDirectories
    <> maybe [] (sourceChildPathProblems unitId "cabal-file" False sourceDirectory) cabalFile
    <> [BuildInfoCabalFileExtensionInvalid unitId path
       | enforceCabalFileExtension,
         path <- maybeToList cabalFile,
        not (Text.isSuffixOf ".cabal" (Text.pack path))]
    <> [BuildInfoSourceFileExtensionUnsupported unitId path
       | enforceSourceFileExtension,
         path <- sourceFiles,
        not (Text.isSuffixOf ".hs" (Text.pack path))]
 where
  componentType = componentObservationType component
  componentName = componentObservationName component
  unitId = componentObservationUnitId component
  modules = componentObservationModules component
  sourceFiles = componentObservationSourceFiles component
  sourceDirectories = componentObservationSourceDirectories component
  sourceDirectory = componentObservationSourceDirectory component
  cabalFile = componentObservationCabalFile component
  typeProblems =
    [BuildInfoComponentTypeUnsupported index componentType
    | enforceComponentType,
      Set.notMember componentType observedSupportedComponentTypes]
  nameProblems =
    [BuildInfoComponentNameMalformed componentType componentName
    | enforceComponentName,
      Set.member componentType observedSupportedComponentTypes,
      not (validComponentName maximumObservedComponentNameBytes
        componentType componentName)]
  unitProblems =
    [BuildInfoUnitIdMalformed unitId
    | enforceComponentUnit,
      not (validUnitId maximumObservedComponentUnitBytes unitId)]
  discoveryProblems =
    [BuildInfoComponentSourceDiscoveryEmpty unitId
    | enforceSourceDiscovery,
      null modules && null sourceFiles]
      <> [BuildInfoHaskellSourceDirectoriesEmpty unitId
         | enforceHaskellSourceDirectories,
           null sourceDirectories]
  moduleProblems =
    [BuildInfoModuleNameMalformed unitId moduleName | moduleName <- modules,
      enforceModuleName,
      not (validModuleName maximumObservedModuleNameBytes moduleName)]
      <> [BuildInfoModuleNameDuplicate unitId moduleName
         | enforceModuleUnique,
           moduleName <- duplicates modules]
  duplicatePathProblems =
    [BuildInfoSourceFileDuplicate unitId path
    | enforceSourceFileUnique,
      path <- duplicates sourceFiles]
      <> [BuildInfoHaskellSourceDirectoryDuplicate unitId path
         | enforceHaskellSourceDirectoryUnique,
           path <- duplicates sourceDirectories]
  sourceDirectoryProblems =
    [BuildInfoSourceDirectoryNotAbsolute unitId sourceDirectory
    | enforceSourceDirectoryAbsolute,
      not (isAbsolutePath sourceDirectory)]
      <> [BuildInfoSourceDirectoryMissingTrailingSeparator unitId sourceDirectory
         | enforceSourceDirectoryTrailingSeparator,
           not (hasTrailingSeparator sourceDirectory)]
      <> [BuildInfoPathUnsafe unitId "src-dir" sourceDirectory
         | enforceSourceDirectorySafe,
           isAbsolutePath sourceDirectory,
           not (safeAbsolutePathAllowDirectory sourceDirectory)]

sourceChildPathProblems
  :: Text -> Text -> Bool -> FilePath -> FilePath
  -> [DiagnosticCompilerBuildInfoProblem]
sourceChildPathProblems unitId field allowDot sourceDirectory path
  | isAbsolutePath path =
      [BuildInfoPathUnsafe unitId field path
      | enforceAbsoluteSourceChildSafe,
        not (safeAbsolutePathAllowDirectory path)]
        <> [BuildInfoPathEscapesSourceDirectory unitId field sourceDirectory path
           | enforceSourceChildContainment,
             safeAbsolutePathAllowDirectory path,
             not (absolutePathWithin sourceDirectory path)]
  | not (safeRelativePath allowDot path) =
      [BuildInfoPathUnsafe unitId field path | enforceRelativeSourceChildSafe]
  | otherwise = []

enforceObservedCompilerFlavour, enforceObservedCompilerId,
  enforceObservedCompilerPath, enforceComponentType, enforceComponentName,
  enforceComponentUnit, enforceSourceDiscovery,
  enforceHaskellSourceDirectories, enforceModuleName, enforceModuleUnique,
  enforceSourceFileUnique, enforceHaskellSourceDirectoryUnique,
  enforceSourceDirectoryAbsolute, enforceSourceDirectoryTrailingSeparator,
  enforceSourceDirectorySafe, enforceAbsoluteSourceChildSafe,
  enforceSourceChildContainment, enforceRelativeSourceChildSafe,
  enforceCabalFileExtension, enforceSourceFileExtension :: Bool
#ifdef VALIDATION_COMPILER_BUILDINFO_OBSERVED_COMPILER_FLAVOUR_BYPASS_MUTANT
enforceObservedCompilerFlavour = False
#else
enforceObservedCompilerFlavour = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_OBSERVED_COMPILER_ID_BYPASS_MUTANT
enforceObservedCompilerId = False
#else
enforceObservedCompilerId = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_OBSERVED_COMPILER_PATH_BYPASS_MUTANT
enforceObservedCompilerPath = False
#else
enforceObservedCompilerPath = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPONENT_TYPE_BYPASS_MUTANT
enforceComponentType = False
#else
enforceComponentType = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPONENT_NAME_BYPASS_MUTANT
enforceComponentName = False
#else
enforceComponentName = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPONENT_UNIT_BYPASS_MUTANT
enforceComponentUnit = False
#else
enforceComponentUnit = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_SOURCE_DISCOVERY_BYPASS_MUTANT
enforceSourceDiscovery = False
#else
enforceSourceDiscovery = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_HS_SOURCE_DIRS_BYPASS_MUTANT
enforceHaskellSourceDirectories = False
#else
enforceHaskellSourceDirectories = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_MODULE_NAME_BYPASS_MUTANT
enforceModuleName = False
#else
enforceModuleName = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_MODULE_DUPLICATE_BYPASS_MUTANT
enforceModuleUnique = False
#else
enforceModuleUnique = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_SOURCE_FILE_DUPLICATE_BYPASS_MUTANT
enforceSourceFileUnique = False
#else
enforceSourceFileUnique = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_HS_SOURCE_DIR_DUPLICATE_BYPASS_MUTANT
enforceHaskellSourceDirectoryUnique = False
#else
enforceHaskellSourceDirectoryUnique = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_SOURCE_DIR_ABSOLUTE_BYPASS_MUTANT
enforceSourceDirectoryAbsolute = False
#else
enforceSourceDirectoryAbsolute = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_SOURCE_DIR_SEPARATOR_BYPASS_MUTANT
enforceSourceDirectoryTrailingSeparator = False
#else
enforceSourceDirectoryTrailingSeparator = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_SOURCE_DIR_SAFETY_BYPASS_MUTANT
enforceSourceDirectorySafe = False
#else
enforceSourceDirectorySafe = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_ABSOLUTE_SOURCE_CHILD_SAFETY_BYPASS_MUTANT
enforceAbsoluteSourceChildSafe = False
#else
enforceAbsoluteSourceChildSafe = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_SOURCE_CONTAINMENT_BYPASS_MUTANT
enforceSourceChildContainment = False
#else
enforceSourceChildContainment = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_RELATIVE_SOURCE_CHILD_SAFETY_BYPASS_MUTANT
enforceRelativeSourceChildSafe = False
#else
enforceRelativeSourceChildSafe = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_CABAL_EXTENSION_BYPASS_MUTANT
enforceCabalFileExtension = False
#else
enforceCabalFileExtension = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_SOURCE_EXTENSION_BYPASS_MUTANT
enforceSourceFileExtension = False
#else
enforceSourceFileExtension = True
#endif

inspectCompilerArguments :: Text -> [Text] -> ArgumentInspection
inspectCompilerArguments unitId arguments =
  ArgumentInspection
    (finishProblemAccumulator
      (addProblemsToAccumulator
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_BOUNDARY_PROBLEM_COMPOSITION_MUTANT
        (boundaryProblems `seq` thisUnitProblems)
#elif defined(VALIDATION_COMPILER_BUILDINFO_ARGUMENT_THIS_UNIT_PROBLEM_COMPOSITION_MUTANT)
        (thisUnitProblems `seq` boundaryProblems)
#else
        (boundaryProblems <> thisUnitProblems)
#endif
        accumulatedProblems))
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_RESULT_ARGUMENT_ORDER_MUTANT
    parsedArguments
#else
    (reverse parsedArguments)
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_RESULT_PATH_ORDER_MUTANT
    parsedPaths
#else
    (reverse parsedPaths)
#endif
    (reverse generatedInputs)
    (reverse packageIds)
 where
  (!accumulatedProblems, !parsedArguments, !parsedPaths, !generatedInputs, !packageIds,
   !hideCount, !noUserCount, !thisUnits) =
    go
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_INDEX_SEED_MUTANT
      (1 :: Int)
#else
      (0 :: Int)
#endif
      arguments emptyProblemAccumulator [] [] [] []
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_HIDE_COUNT_SEED_MUTANT
      (1 :: Int)
#else
      (0 :: Int)
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_NO_USER_COUNT_SEED_MUTANT
      (1 :: Int)
#else
      (0 :: Int)
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_ARGUMENT_THIS_UNIT_SEED_MUTANT
      [unitId]
#else
      []
#endif

  go !_index [] !problems !parsed !paths !generated !packages !hideAll !noUser !units =
    (problems, parsed, paths, generated, packages, hideAll, noUser, units)
  go !index (argument : rest) !problems !parsed !paths !generated !packages
    !hideAll !noUser !units
    | recognizeHideAllPackages && argument == "-hide-all-packages" =
        go (index + 1) rest problems
          (DiagnosticCompilerBuildInfoBoundaryArgument index argument : parsed)
          paths generated packages (hideAll + 1) noUser units
    | recognizeNoUserPackageDb && argument == "-no-user-package-db" =
        go (index + 1) rest problems
          (DiagnosticCompilerBuildInfoBoundaryArgument index argument : parsed)
          paths generated packages hideAll (noUser + 1) units
    | recognizeThisUnitId && argument == "-this-unit-id" =
        consumeIdentityValue index argument rest problems parsed paths generated packages
          hideAll noUser units True
    | recognizePackageId && argument == "-package-id" =
        consumeIdentityValue index argument rest problems parsed paths generated packages
          hideAll noUser units False
    | Set.member argument allowedPathTakingArguments =
        consumePathValue index argument rest problems parsed paths generated packages
          hideAll noUser units
    | recognizeGeneratedInput && argument == "-optP-include" =
        consumeGeneratedInput index rest problems parsed paths generated packages
          hideAll noUser units
    | Set.member argument allowedStandaloneArguments =
        go (index + 1) rest problems
          (DiagnosticCompilerBuildInfoStandaloneArgument index argument : parsed)
          paths generated packages hideAll noUser units
    | Just (option, path) <- attachedAllowedPath argument =
        let filePath = Text.unpack path
            pathObservation =
              DiagnosticCompilerBuildInfoPathObservation index option Nothing filePath
            argumentObservation =
              DiagnosticCompilerBuildInfoPathArgument index option Nothing argument filePath
            nextProblems =
#ifdef VALIDATION_COMPILER_BUILDINFO_ATTACHED_PATH_SAFETY_BYPASS_MUTANT
              problems
#else
              addProblemsToAccumulator
                [BuildInfoCompilerArgumentPathUnsafe unitId index option filePath
                | not (safeMachineArgumentPath filePath)]
                problems
#endif
         in go (index + 1) rest nextProblems (argumentObservation : parsed)
              (pathObservation : paths) generated packages hideAll noUser units
    | Just reason <- argumentHazard argument =
      go (index + 1) rest
          (addProblemToAccumulator
            (BuildInfoCompilerArgumentHazardous unitId index argument reason) problems)
          parsed paths generated packages hideAll noUser units
    | otherwise =
#ifdef VALIDATION_COMPILER_BUILDINFO_UNKNOWN_ARGUMENT_BYPASS_MUTANT
        go (index + 1) rest problems
          (DiagnosticCompilerBuildInfoBypassedArgument index argument : parsed)
          paths generated packages hideAll noUser units
#else
        go (index + 1) rest
          (addProblemToAccumulator
            (BuildInfoCompilerArgumentUnclassified unitId index argument) problems)
          parsed paths generated packages hideAll noUser units
#endif

  consumeIdentityValue !index option rest !problems !parsed !paths !generated !packages
    !hideAll !noUser !units isThisUnit =
      case rest of
        [] ->
          go (index + 1) []
            (addProblemsToAccumulator
              [BuildInfoCompilerArgumentValueMissing unitId index option
              | enforceIdentityArgumentValuePresence]
              problems)
            parsed paths generated packages hideAll noUser units
        value : remaining ->
          let nextProblems = addProblemsToAccumulator
                [BuildInfoCompilerArgumentValueMalformed unitId index option value
                | enforceIdentityArgumentValueGrammar,
                  not (validUnitId maximumCompilerArgumentUnitBytes value)] problems
              nextUnits = if isThisUnit then value : units else units
              packageObservation =
                DiagnosticCompilerBuildInfoPackageObservation index option (index + 1) value
              nextPackages = if isThisUnit then packages else packageObservation : packages
              argumentObservation =
                if isThisUnit
                  then DiagnosticCompilerBuildInfoThisUnitArgument
                    index option (index + 1) value
                  else DiagnosticCompilerBuildInfoPackageArgument
                    index option (index + 1) value
           in go (index + 2) remaining nextProblems (argumentObservation : parsed)
                paths generated nextPackages hideAll noUser nextUnits

  consumePathValue !index option rest !problems !parsed !paths !generated !packages
    !hideAll !noUser !units =
      case rest of
        [] ->
          go (index + 1) []
            (addProblemsToAccumulator
              [BuildInfoCompilerArgumentValueMissing unitId index option
              | enforcePathArgumentValuePresence]
              problems)
            parsed paths generated packages hideAll noUser units
        value : remaining ->
          let path = Text.unpack value
              pathObservation =
                DiagnosticCompilerBuildInfoPathObservation index option (Just (index + 1)) path
              argumentObservation =
                DiagnosticCompilerBuildInfoPathArgument
                  index option (Just (index + 1)) value path
              nextProblems =
#ifdef VALIDATION_COMPILER_BUILDINFO_SEPARATED_PATH_SAFETY_BYPASS_MUTANT
                problems
#else
                addProblemsToAccumulator
                  [BuildInfoCompilerArgumentPathUnsafe unitId index option path
                  | not (safeMachineArgumentPath path)] problems
#endif
           in go (index + 2) remaining nextProblems (argumentObservation : parsed)
                (pathObservation : paths) generated packages hideAll noUser units

  consumeGeneratedInput !index rest !problems !parsed !paths !generated !packages
    !hideAll !noUser !units =
      case rest of
        candidate : remaining
          | Just encodedPath <- Text.stripPrefix "-optP" candidate,
            admitGeneratedInputPrefix,
            Text.isSuffixOf "/cabal_macros.h" encodedPath,
            admitGeneratedInputSuffix,
            safeAbsolutePath (Text.unpack encodedPath),
            admitGeneratedInputPath ->
              let path = Text.unpack encodedPath
                  pathObservation =
                    DiagnosticCompilerBuildInfoPathObservation
                      index "-optP-include" (Just (index + 1)) path
                  generatedObservation =
                    DiagnosticCompilerBuildInfoGeneratedInputObservation
                      index "-optP-include" (index + 1) candidate path
                  argumentObservation =
                    DiagnosticCompilerBuildInfoGeneratedInputArgument
                      index "-optP-include" (index + 1) candidate path
               in go (index + 2) remaining problems (argumentObservation : parsed)
                    (pathObservation : paths) (generatedObservation : generated)
                    packages hideAll noUser units
        candidate : remaining ->
          go (index + 2) remaining
            (addProblemsToAccumulator
              [BuildInfoCompilerGeneratedInputArgumentMalformed
                unitId index "-optP-include" (Just candidate)
              | enforceGeneratedInputShape]
              problems)
            parsed paths generated packages hideAll noUser units
        [] ->
          go (index + 1) []
            (addProblemsToAccumulator
              [BuildInfoCompilerGeneratedInputArgumentMalformed
                unitId index "-optP-include" Nothing
              | enforceGeneratedInputPresence]
              problems)
            parsed paths generated packages hideAll noUser units

  boundaryProblems =
    exactCountProblems enforceHideAllBoundary "-hide-all-packages" hideCount
      <> exactCountProblems enforceNoUserBoundary "-no-user-package-db" noUserCount
  exactCountProblems False _ _ = []
  exactCountProblems True boundary count = case count of
    0 ->
#ifdef VALIDATION_COMPILER_BUILDINFO_EXACT_COUNT_MISSING_RESULT_ROUTE_MUTANT
      [ BuildInfoCompilerPackageBoundaryMissing unitId boundary
      , BuildInfoCompilerPackageBoundaryMissing unitId boundary
      ]
#else
      [BuildInfoCompilerPackageBoundaryMissing unitId boundary]
#endif
    1 ->
#ifdef VALIDATION_COMPILER_BUILDINFO_EXACT_COUNT_MATCH_RESULT_ROUTE_MUTANT
      [BuildInfoCompilerPackageBoundaryMissing unitId boundary]
#else
      []
#endif
    _ ->
#ifdef VALIDATION_COMPILER_BUILDINFO_EXACT_COUNT_DUPLICATE_RESULT_ROUTE_MUTANT
      [ BuildInfoCompilerPackageBoundaryDuplicate unitId boundary
      , BuildInfoCompilerPackageBoundaryDuplicate unitId boundary
      ]
#else
      [BuildInfoCompilerPackageBoundaryDuplicate unitId boundary]
#endif
  thisUnitProblems = case reverse thisUnits of
    [] ->
      (
#ifdef VALIDATION_COMPILER_BUILDINFO_THIS_UNIT_MISSING_RESULT_ROUTE_MUTANT
      [BuildInfoCompilerThisUnitIdMissing unitId | enforceThisUnitMissing]
        <> [BuildInfoCompilerThisUnitIdMissing unitId | enforceThisUnitMissing]
#else
      [BuildInfoCompilerThisUnitIdMissing unitId | enforceThisUnitMissing]
#endif
      )
    [observed]
      | observed == unitId ->
#ifdef VALIDATION_COMPILER_BUILDINFO_THIS_UNIT_MATCH_RESULT_ROUTE_MUTANT
          [BuildInfoCompilerThisUnitIdMismatch unitId observed]
#else
          []
#endif
      | otherwise ->
          (
#ifdef VALIDATION_COMPILER_BUILDINFO_THIS_UNIT_MISMATCH_RESULT_ROUTE_MUTANT
          [BuildInfoCompilerThisUnitIdMismatch unitId observed
          | enforceThisUnitMismatch]
            <> [BuildInfoCompilerThisUnitIdMismatch unitId observed
               | enforceThisUnitMismatch]
#else
          [BuildInfoCompilerThisUnitIdMismatch unitId observed
          | enforceThisUnitMismatch]
#endif
          )
    observed ->
      (
#ifdef VALIDATION_COMPILER_BUILDINFO_THIS_UNIT_DUPLICATE_RESULT_ROUTE_MUTANT
      [BuildInfoCompilerThisUnitIdDuplicate unitId observed
      | enforceThisUnitDuplicate]
        <> [BuildInfoCompilerThisUnitIdDuplicate unitId observed
           | enforceThisUnitDuplicate]
#else
      [BuildInfoCompilerThisUnitIdDuplicate unitId observed
      | enforceThisUnitDuplicate]
#endif
      )

enforceHideAllBoundary, enforceNoUserBoundary, enforceThisUnitMissing,
  enforceThisUnitDuplicate, enforceThisUnitMismatch :: Bool
#ifdef VALIDATION_COMPILER_BUILDINFO_PACKAGE_BOUNDARY_BYPASS_MUTANT
enforceHideAllBoundary = False
#else
enforceHideAllBoundary = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_NO_USER_BOUNDARY_BYPASS_MUTANT
enforceNoUserBoundary = False
#else
enforceNoUserBoundary = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_THIS_UNIT_MISSING_BYPASS_MUTANT
enforceThisUnitMissing = False
#else
enforceThisUnitMissing = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_THIS_UNIT_DUPLICATE_BYPASS_MUTANT
enforceThisUnitDuplicate = False
#else
enforceThisUnitDuplicate = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_THIS_UNIT_BYPASS_MUTANT
enforceThisUnitMismatch = False
#else
enforceThisUnitMismatch = True
#endif

recognizeHideAllPackages, recognizeNoUserPackageDb, recognizeThisUnitId,
  recognizePackageId, recognizeGeneratedInput, admitGeneratedInputPrefix,
  admitGeneratedInputSuffix, admitGeneratedInputPath,
  enforceIdentityArgumentValuePresence, enforceIdentityArgumentValueGrammar,
  enforcePathArgumentValuePresence, enforceGeneratedInputShape,
  enforceGeneratedInputPresence, allowEmptyAttachedPath :: Bool
#ifdef VALIDATION_COMPILER_BUILDINFO_HIDE_ALL_RECOGNITION_DROP_MUTANT
recognizeHideAllPackages = False
#else
recognizeHideAllPackages = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_NO_USER_RECOGNITION_DROP_MUTANT
recognizeNoUserPackageDb = False
#else
recognizeNoUserPackageDb = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_THIS_UNIT_RECOGNITION_DROP_MUTANT
recognizeThisUnitId = False
#else
recognizeThisUnitId = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_PACKAGE_ID_RECOGNITION_DROP_MUTANT
recognizePackageId = False
#else
recognizePackageId = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_GENERATED_INPUT_RECOGNITION_DROP_MUTANT
recognizeGeneratedInput = False
#else
recognizeGeneratedInput = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_GENERATED_INPUT_PREFIX_RECOGNITION_DROP_MUTANT
admitGeneratedInputPrefix = False
#else
admitGeneratedInputPrefix = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_GENERATED_INPUT_SUFFIX_RECOGNITION_DROP_MUTANT
admitGeneratedInputSuffix = False
#else
admitGeneratedInputSuffix = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_GENERATED_INPUT_PATH_RECOGNITION_DROP_MUTANT
admitGeneratedInputPath = False
#else
admitGeneratedInputPath = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_IDENTITY_ARGUMENT_VALUE_MISSING_BYPASS_MUTANT
enforceIdentityArgumentValuePresence = False
#else
enforceIdentityArgumentValuePresence = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_IDENTITY_ARGUMENT_VALUE_GRAMMAR_BYPASS_MUTANT
enforceIdentityArgumentValueGrammar = False
#else
enforceIdentityArgumentValueGrammar = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_PATH_ARGUMENT_VALUE_MISSING_BYPASS_MUTANT
enforcePathArgumentValuePresence = False
#else
enforcePathArgumentValuePresence = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_GENERATED_INPUT_SHAPE_BYPASS_MUTANT
enforceGeneratedInputShape = False
#else
enforceGeneratedInputShape = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_GENERATED_INPUT_MISSING_BYPASS_MUTANT
enforceGeneratedInputPresence = False
#else
enforceGeneratedInputPresence = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_ATTACHED_EMPTY_PATH_BYPASS_MUTANT
allowEmptyAttachedPath = True
#else
allowEmptyAttachedPath = False
#endif

allowedStandaloneArguments :: Set Text
allowedStandaloneArguments =
  Set.fromList
    (retainedAlternative retainStandaloneO "-O"
      <> retainedAlternative retainStandaloneO0 "-O0"
      <> retainedAlternative retainStandaloneO1 "-O1"
      <> retainedAlternative retainStandaloneO2 "-O2"
      <> retainedAlternative retainStandaloneWall "-Wall"
      <> retainedAlternative retainStandaloneWerror "-Werror"
      <> retainedAlternative retainStandaloneFnoCode "-fno-code")

allowedPathTakingArguments :: Set Text
allowedPathTakingArguments =
  Set.fromList
    (retainedAlternative retainSeparatedPackageDb "-package-db"
      <> retainedAlternative retainSeparatedOutputDir "-outputdir"
      <> retainedAlternative retainSeparatedODir "-odir"
      <> retainedAlternative retainSeparatedHiDir "-hidir"
      <> retainedAlternative retainSeparatedStubDir "-stubdir"
      <> retainedAlternative retainSeparatedTmpDir "-tmpdir")

attachedAllowedPath :: Text -> Maybe (Text, Text)
attachedAllowedPath argument =
  firstAttached
    (retainedAlternative retainAttachedPackageDb "-package-db="
      <> retainedAlternative retainAttachedOutputDir "-outputdir="
      <> retainedAlternative retainAttachedODir "-odir="
      <> retainedAlternative retainAttachedHiDir "-hidir="
      <> retainedAlternative retainAttachedStubDir "-stubdir="
      <> retainedAlternative retainAttachedTmpDir "-tmpdir=")
 where
  firstAttached [] = Nothing
  firstAttached (prefix : prefixes)
    | Just value <- Text.stripPrefix prefix argument,
      allowEmptyAttachedPath || not (Text.null value) =
        Just
          (
#ifdef VALIDATION_COMPILER_BUILDINFO_ATTACHED_OPTION_PROJECTION_MUTANT
            Text.dropEnd 1 prefix <> "-mutant"
#else
            Text.dropEnd 1 prefix
#endif
          ,
#ifdef VALIDATION_COMPILER_BUILDINFO_ATTACHED_VALUE_PROJECTION_MUTANT
            value <> "-mutant"
#else
            value
#endif
          )
    | otherwise = firstAttached prefixes

retainedAlternative :: Bool -> value -> [value]
retainedAlternative True value =
#ifdef VALIDATION_COMPILER_BUILDINFO_RETAINED_ALTERNATIVE_TRUE_ROUTE_DROP_MUTANT
  value `seq` []
#else
  [value]
#endif
retainedAlternative False _ = []

retainStandaloneO, retainStandaloneO0, retainStandaloneO1,
  retainStandaloneO2, retainStandaloneWall, retainStandaloneWerror,
  retainStandaloneFnoCode, retainSeparatedPackageDb,
  retainSeparatedOutputDir, retainSeparatedODir, retainSeparatedHiDir,
  retainSeparatedStubDir, retainSeparatedTmpDir, retainAttachedPackageDb,
  retainAttachedOutputDir, retainAttachedODir, retainAttachedHiDir,
  retainAttachedStubDir, retainAttachedTmpDir :: Bool
#ifdef VALIDATION_COMPILER_BUILDINFO_STANDALONE_O_DROP_MUTANT
retainStandaloneO = False
#else
retainStandaloneO = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_STANDALONE_O0_DROP_MUTANT
retainStandaloneO0 = False
#else
retainStandaloneO0 = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_STANDALONE_O1_DROP_MUTANT
retainStandaloneO1 = False
#else
retainStandaloneO1 = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_STANDALONE_O2_DROP_MUTANT
retainStandaloneO2 = False
#else
retainStandaloneO2 = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_STANDALONE_WALL_DROP_MUTANT
retainStandaloneWall = False
#else
retainStandaloneWall = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_STANDALONE_WERROR_DROP_MUTANT
retainStandaloneWerror = False
#else
retainStandaloneWerror = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_STANDALONE_FNO_CODE_DROP_MUTANT
retainStandaloneFnoCode = False
#else
retainStandaloneFnoCode = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_SEPARATED_PACKAGE_DB_DROP_MUTANT
retainSeparatedPackageDb = False
#else
retainSeparatedPackageDb = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_SEPARATED_OUTPUTDIR_DROP_MUTANT
retainSeparatedOutputDir = False
#else
retainSeparatedOutputDir = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_SEPARATED_ODIR_DROP_MUTANT
retainSeparatedODir = False
#else
retainSeparatedODir = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_SEPARATED_HIDIR_DROP_MUTANT
retainSeparatedHiDir = False
#else
retainSeparatedHiDir = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_SEPARATED_STUBDIR_DROP_MUTANT
retainSeparatedStubDir = False
#else
retainSeparatedStubDir = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_SEPARATED_TMPDIR_DROP_MUTANT
retainSeparatedTmpDir = False
#else
retainSeparatedTmpDir = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_ATTACHED_PACKAGE_DB_DROP_MUTANT
retainAttachedPackageDb = False
#else
retainAttachedPackageDb = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_ATTACHED_OUTPUTDIR_DROP_MUTANT
retainAttachedOutputDir = False
#else
retainAttachedOutputDir = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_ATTACHED_ODIR_DROP_MUTANT
retainAttachedODir = False
#else
retainAttachedODir = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_ATTACHED_HIDIR_DROP_MUTANT
retainAttachedHiDir = False
#else
retainAttachedHiDir = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_ATTACHED_STUBDIR_DROP_MUTANT
retainAttachedStubDir = False
#else
retainAttachedStubDir = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_ATTACHED_TMPDIR_DROP_MUTANT
retainAttachedTmpDir = False
#else
retainAttachedTmpDir = True
#endif

argumentHazard :: Text -> Maybe Text
argumentHazard argument
  | enforceResponseFileHazard && Text.isPrefixOf "@" argument =
#ifdef VALIDATION_COMPILER_BUILDINFO_HAZARD_RESPONSE_REASON_PROJECTION_MUTANT
      Just "response files can hide unenumerated compiler arguments-mutant"
#else
      Just "response files can hide unenumerated compiler arguments"
#endif
  | enforceCompilerPluginHazard && Text.isPrefixOf "-fplugin" argument =
#ifdef VALIDATION_COMPILER_BUILDINFO_HAZARD_COMPILER_PLUGIN_REASON_PROJECTION_MUTANT
      Just "compiler plugin execution is not admitted-mutant"
#else
      Just "compiler plugin execution is not admitted"
#endif
  | enforcePluginPackageHazard && Text.isPrefixOf "-plugin-package" argument =
#ifdef VALIDATION_COMPILER_BUILDINFO_HAZARD_PLUGIN_PACKAGE_REASON_PROJECTION_MUTANT
      Just "compiler plugin packages are not admitted-mutant"
#else
      Just "compiler plugin packages are not admitted"
#endif
  | enforceTemplateHaskellHazard
      && elem argument ["-XTemplateHaskell", "-XTemplateHaskellQuotes", "-XQuasiQuotes"] =
#ifdef VALIDATION_COMPILER_BUILDINFO_HAZARD_TEMPLATE_HASKELL_REASON_PROJECTION_MUTANT
      Just "compile-time Haskell execution is not admitted-mutant"
#else
      Just "compile-time Haskell execution is not admitted"
#endif
  | enforceInterpreterHazard
      && elem argument ["-fexternal-interpreter", "-fprefer-byte-code", "-fbyte-code-and-object-code"] =
#ifdef VALIDATION_COMPILER_BUILDINFO_HAZARD_INTERPRETER_REASON_PROJECTION_MUTANT
      Just "compile-time interpreter execution is not admitted-mutant"
#else
      Just "compile-time interpreter execution is not admitted"
#endif
  | enforcePreprocessorHazard && elem argument ["-F", "-cpp", "-XCPP"] =
#ifdef VALIDATION_COMPILER_BUILDINFO_HAZARD_PREPROCESSOR_REASON_PROJECTION_MUTANT
      Just "unbound preprocessing is not admitted-mutant"
#else
      Just "unbound preprocessing is not admitted"
#endif
  | enforceCustomPreprocessorHazard
      && any (\prefix -> Text.isPrefixOf prefix argument) ["-pgmF", "-optF", "-pgmP", "-pgmL"] =
#ifdef VALIDATION_COMPILER_BUILDINFO_HAZARD_CUSTOM_PREPROCESSOR_REASON_PROJECTION_MUTANT
      Just "custom preprocessing tools are not admitted-mutant"
#else
      Just "custom preprocessing tools are not admitted"
#endif
  | enforceForeignCallHazard && elem argument
      ["-XForeignFunctionInterface", "-XCApiFFI", "-XGHCForeignImportPrim",
       "-XInterruptibleFFI", "-XUnliftedFFITypes", "-XJavaScriptFFI"] =
#ifdef VALIDATION_COMPILER_BUILDINFO_HAZARD_FOREIGN_CALL_REASON_PROJECTION_MUTANT
      Just "foreign-call compilation is not admitted-mutant"
#else
      Just "foreign-call compilation is not admitted"
#endif
  | enforceLinkerHazard && any (\prefix -> Text.isPrefixOf prefix argument)
      ["-optl", "-pgml", "-framework", "-L", "-l"] =
#ifdef VALIDATION_COMPILER_BUILDINFO_HAZARD_LINKER_REASON_PROJECTION_MUTANT
      Just "linker or foreign-library arguments are not admitted-mutant"
#else
      Just "linker or foreign-library arguments are not admitted"
#endif
  | enforceForeignToolHazard && any (\prefix -> Text.isPrefixOf prefix argument)
      ["-pgmc", "-pgma", "-optc", "-opta", "-optlo"] =
#ifdef VALIDATION_COMPILER_BUILDINFO_HAZARD_FOREIGN_TOOL_REASON_PROJECTION_MUTANT
      Just "custom foreign compiler tools are not admitted-mutant"
#else
      Just "custom foreign compiler tools are not admitted"
#endif
  | enforcePackageEnvironmentHazard
      && elem argument ["-package", "-package-env", "-user-package-db"] =
#ifdef VALIDATION_COMPILER_BUILDINFO_HAZARD_PACKAGE_ENVIRONMENT_REASON_PROJECTION_MUTANT
      Just "unbounded package or user environment selection is not admitted-mutant"
#else
      Just "unbounded package or user environment selection is not admitted"
#endif
  | enforceAttachedPackageEnvironmentHazard
      && any (\prefix -> Text.isPrefixOf prefix argument)
      ["-package=", "-package-env=", "-user-package-db="] =
#ifdef VALIDATION_COMPILER_BUILDINFO_HAZARD_ATTACHED_PACKAGE_ENVIRONMENT_REASON_PROJECTION_MUTANT
      Just "unbounded package or user environment selection is not admitted-mutant"
#else
      Just "unbounded package or user environment selection is not admitted"
#endif
  | enforceInteractiveHazard && elem argument ["-e", "-interactive", "-ghci-script"] =
#ifdef VALIDATION_COMPILER_BUILDINFO_HAZARD_INTERACTIVE_REASON_PROJECTION_MUTANT
      Just "interactive compiler execution is not admitted-mutant"
#else
      Just "interactive compiler execution is not admitted"
#endif
  | otherwise = Nothing

enforceResponseFileHazard, enforceCompilerPluginHazard,
  enforcePluginPackageHazard, enforceTemplateHaskellHazard,
  enforceInterpreterHazard, enforcePreprocessorHazard,
  enforceCustomPreprocessorHazard, enforceForeignCallHazard,
  enforceLinkerHazard, enforceForeignToolHazard,
  enforcePackageEnvironmentHazard, enforceAttachedPackageEnvironmentHazard,
  enforceInteractiveHazard :: Bool
#ifdef VALIDATION_COMPILER_BUILDINFO_RESPONSE_FILE_HAZARD_BYPASS_MUTANT
enforceResponseFileHazard = False
#else
enforceResponseFileHazard = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPILER_PLUGIN_HAZARD_BYPASS_MUTANT
enforceCompilerPluginHazard = False
#else
enforceCompilerPluginHazard = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_PLUGIN_PACKAGE_HAZARD_BYPASS_MUTANT
enforcePluginPackageHazard = False
#else
enforcePluginPackageHazard = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_TEMPLATE_HASKELL_HAZARD_BYPASS_MUTANT
enforceTemplateHaskellHazard = False
#else
enforceTemplateHaskellHazard = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_INTERPRETER_HAZARD_BYPASS_MUTANT
enforceInterpreterHazard = False
#else
enforceInterpreterHazard = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_PREPROCESSOR_HAZARD_BYPASS_MUTANT
enforcePreprocessorHazard = False
#else
enforcePreprocessorHazard = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_CUSTOM_PREPROCESSOR_HAZARD_BYPASS_MUTANT
enforceCustomPreprocessorHazard = False
#else
enforceCustomPreprocessorHazard = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_FOREIGN_CALL_HAZARD_BYPASS_MUTANT
enforceForeignCallHazard = False
#else
enforceForeignCallHazard = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_LINKER_HAZARD_BYPASS_MUTANT
enforceLinkerHazard = False
#else
enforceLinkerHazard = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_FOREIGN_TOOL_HAZARD_BYPASS_MUTANT
enforceForeignToolHazard = False
#else
enforceForeignToolHazard = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_PACKAGE_ENVIRONMENT_HAZARD_BYPASS_MUTANT
enforcePackageEnvironmentHazard = False
#else
enforcePackageEnvironmentHazard = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_ATTACHED_PACKAGE_ENVIRONMENT_HAZARD_BYPASS_MUTANT
enforceAttachedPackageEnvironmentHazard = False
#else
enforceAttachedPackageEnvironmentHazard = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_INTERACTIVE_HAZARD_BYPASS_MUTANT
enforceInteractiveHazard = False
#else
enforceInteractiveHazard = True
#endif

componentIdentityProblems
  :: [DiagnosticCompilerBuildInfoComponentObservation]
  -> [DiagnosticCompilerBuildInfoProblem]
componentIdentityProblems components =
  [BuildInfoObservedUnitIdDuplicate unitId
  | enforceObservedUnitUnique,
    unitId <- duplicates (map componentObservationUnitId components)]
    <> [BuildInfoObservedComponentIdentityDuplicate componentType componentName
       | enforceObservedComponentUnique,
         (componentType, componentName) <-
           duplicates (map componentObservationComponentKey components)]

compilerExpectationProblems
  :: DiagnosticCompilerBuildInfoExpectedCompiler
  -> Parsed CompilerIdentity
  -> [DiagnosticCompilerBuildInfoProblem]
compilerExpectationProblems
  (DiagnosticCompilerBuildInfoExpectedCompiler _ expectedId expectedPath)
  (Parsed _ (Just (CompilerIdentity _ observedId observedPath))) =
    [BuildInfoExpectedCompilerIdMismatch expectedId observedId
         | enforceExpectedCompilerId,
           expectedId /= observedId]
      <> [BuildInfoExpectedCompilerPathMismatch expectedPath observedPath
         | enforceExpectedCompilerPath,
           expectedPath /= observedPath]
compilerExpectationProblems _ _ = []

expectedIdentityProblems
  :: [DiagnosticCompilerBuildInfoExpectedIdentity]
  -> [DiagnosticCompilerBuildInfoComponentObservation]
  -> [DiagnosticCompilerBuildInfoProblem]
expectedIdentityProblems
  expected components =
  concatMap bindExpected expected <> concatMap unexpectedObserved components
 where
  byComponent =
    Map.fromList
      [(componentObservationComponentKey component, component) | component <- components]
  byUnit =
    Map.fromList
      [(componentObservationUnitId component, component) | component <- components]
  bindExpected identity@(DiagnosticCompilerBuildInfoExpectedIdentity
    expectedType expectedName expectedUnit) =
      case Map.lookup (expectedType, expectedName) byComponent of
        Just observed
          | componentObservationUnitId observed == expectedUnit -> []
          | otherwise ->
              [BuildInfoExpectedUnitIdentityMismatch expectedType expectedName expectedUnit
                (componentObservationUnitId observed)
              | enforceExpectedUnitIdentity]
        Nothing -> case Map.lookup expectedUnit byUnit of
          Just observed ->
            [BuildInfoExpectedComponentIdentityMismatch expectedUnit expectedType expectedName
              (componentObservationType observed) (componentObservationName observed)
            | enforceExpectedComponentIdentity]
          Nothing ->
            [uncurryExpected BuildInfoExpectedIdentityMissing identity
            | enforceExpectedIdentityPresence]
  expectedComponents = Set.fromList (map expectedComponentIdentity expected)
  expectedUnits = Set.fromList (map expectedUnitIdentity expected)
  unexpectedObserved component
    | Set.member (componentObservationComponentKey component) expectedComponents = []
    | Set.member (componentObservationUnitId component) expectedUnits = []
    | otherwise =
        [BuildInfoUnexpectedIdentity (componentObservationType component)
          (componentObservationName component) (componentObservationUnitId component)
        | enforceNoUnexpectedIdentity]

enforceObservedUnitUnique, enforceObservedComponentUnique,
  enforceExpectedCompilerId,
  enforceExpectedCompilerPath, enforceExpectedUnitIdentity,
  enforceExpectedComponentIdentity, enforceExpectedIdentityPresence,
  enforceNoUnexpectedIdentity :: Bool
#ifdef VALIDATION_COMPILER_BUILDINFO_OBSERVED_UNIT_DUPLICATE_BYPASS_MUTANT
enforceObservedUnitUnique = False
#else
enforceObservedUnitUnique = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_OBSERVED_COMPONENT_DUPLICATE_BYPASS_MUTANT
enforceObservedComponentUnique = False
#else
enforceObservedComponentUnique = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_COMPILER_BYPASS_MUTANT
enforceExpectedCompilerId = False
#else
enforceExpectedCompilerId = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_COMPILER_PATH_BYPASS_MUTANT
enforceExpectedCompilerPath = False
#else
enforceExpectedCompilerPath = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_IDENTITY_BYPASS_MUTANT
enforceExpectedUnitIdentity = False
#else
enforceExpectedUnitIdentity = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_COMPONENT_IDENTITY_BYPASS_MUTANT
enforceExpectedComponentIdentity = False
#else
enforceExpectedComponentIdentity = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_IDENTITY_MISSING_BYPASS_MUTANT
enforceExpectedIdentityPresence = False
#else
enforceExpectedIdentityPresence = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_UNEXPECTED_IDENTITY_BYPASS_MUTANT
enforceNoUnexpectedIdentity = False
#else
enforceNoUnexpectedIdentity = True
#endif

validateExpectedCompiler
  :: DiagnosticCompilerBuildInfoExpectedCompiler
  -> [DiagnosticCompilerBuildInfoProblem]
validateExpectedCompiler
  (DiagnosticCompilerBuildInfoExpectedCompiler flavour compilerId compilerPath) =
    [BuildInfoExpectedCompilerFlavourUnsupported flavour
    | enforceExpectedCompilerFlavourGrammar,
      flavour /= "ghc"]
      <> [BuildInfoExpectedCompilerIdMalformed compilerId
         | enforceExpectedCompilerIdGrammar,
           not (validCompilerId maximumCallerCompilerIdBytes compilerId)]
      <> [BuildInfoExpectedCompilerPathUnsafe compilerPath
         | enforceExpectedCompilerPathGrammar,
           not (safeAbsolutePath compilerPath)]

validateExpectedIdentities
  :: [DiagnosticCompilerBuildInfoExpectedIdentity]
  -> [DiagnosticCompilerBuildInfoProblem]
validateExpectedIdentities expected =
  [BuildInfoExpectedIdentityUniverseEmpty
  | enforceExpectedUniverseNonEmpty,
    null expected]
    <> concatMap expectedShapeProblems expected
    <> [BuildInfoExpectedUnitIdDuplicate unitId
       | enforceExpectedUnitUnique,
         unitId <- duplicates (map expectedUnitIdentity expected)]
    <> [BuildInfoExpectedComponentIdentityDuplicate componentType componentName
       | enforceExpectedComponentUnique,
         (componentType, componentName) <-
           duplicates (map expectedComponentIdentity expected)]
 where
  expectedShapeProblems
    (DiagnosticCompilerBuildInfoExpectedIdentity componentType componentName unitId) =
      [BuildInfoExpectedIdentityTypeUnsupported componentType componentName unitId
      | enforceExpectedIdentityType,
        Set.notMember componentType expectedSupportedComponentTypes]
        <> [BuildInfoExpectedIdentityTextMalformed "name" componentType componentName unitId
           | enforceExpectedIdentityName,
             Set.member componentType expectedSupportedComponentTypes,
             not (validComponentName maximumExpectedIdentityNameBytes
               componentType componentName)]
        <> [BuildInfoExpectedIdentityTextMalformed "unit-id" componentType componentName unitId
           | enforceExpectedIdentityUnit,
             not (validUnitId maximumExpectedIdentityUnitBytes unitId)]

enforceExpectedCompilerFlavourGrammar, enforceExpectedCompilerIdGrammar,
  enforceExpectedCompilerPathGrammar, enforceExpectedUniverseNonEmpty,
  enforceExpectedUnitUnique, enforceExpectedComponentUnique,
  enforceExpectedIdentityType, enforceExpectedIdentityName,
  enforceExpectedIdentityUnit :: Bool
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_COMPILER_FLAVOUR_GRAMMAR_BYPASS_MUTANT
enforceExpectedCompilerFlavourGrammar = False
#else
enforceExpectedCompilerFlavourGrammar = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_COMPILER_ID_GRAMMAR_BYPASS_MUTANT
enforceExpectedCompilerIdGrammar = False
#else
enforceExpectedCompilerIdGrammar = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_COMPILER_PATH_GRAMMAR_BYPASS_MUTANT
enforceExpectedCompilerPathGrammar = False
#else
enforceExpectedCompilerPathGrammar = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_UNIVERSE_EMPTY_BYPASS_MUTANT
enforceExpectedUniverseNonEmpty = False
#else
enforceExpectedUniverseNonEmpty = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_UNIT_DUPLICATE_BYPASS_MUTANT
enforceExpectedUnitUnique = False
#else
enforceExpectedUnitUnique = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_COMPONENT_DUPLICATE_BYPASS_MUTANT
enforceExpectedComponentUnique = False
#else
enforceExpectedComponentUnique = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_IDENTITY_TYPE_BYPASS_MUTANT
enforceExpectedIdentityType = False
#else
enforceExpectedIdentityType = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_IDENTITY_NAME_BYPASS_MUTANT
enforceExpectedIdentityName = False
#else
enforceExpectedIdentityName = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_IDENTITY_UNIT_BYPASS_MUTANT
enforceExpectedIdentityUnit = False
#else
enforceExpectedIdentityUnit = True
#endif

observedSupportedComponentTypes, expectedSupportedComponentTypes :: Set Text
observedSupportedComponentTypes = Set.fromList
  (retainedAlternative retainObservedLibType "lib"
    <> retainedAlternative retainObservedExeType "exe"
    <> retainedAlternative retainObservedTestType "test"
    <> retainedAlternative retainObservedBenchType "bench"
    <> retainedAlternative retainObservedFlibType "flib")
expectedSupportedComponentTypes = Set.fromList
  (retainedAlternative retainExpectedLibType "lib"
    <> retainedAlternative retainExpectedExeType "exe"
    <> retainedAlternative retainExpectedTestType "test"
    <> retainedAlternative retainExpectedBenchType "bench"
    <> retainedAlternative retainExpectedFlibType "flib")

retainObservedLibType, retainObservedExeType, retainObservedTestType,
  retainObservedBenchType, retainObservedFlibType, retainExpectedLibType,
  retainExpectedExeType, retainExpectedTestType, retainExpectedBenchType,
  retainExpectedFlibType :: Bool
#ifdef VALIDATION_COMPILER_BUILDINFO_OBSERVED_LIB_TYPE_DROP_MUTANT
retainObservedLibType = False
#else
retainObservedLibType = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_OBSERVED_EXE_TYPE_DROP_MUTANT
retainObservedExeType = False
#else
retainObservedExeType = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_OBSERVED_TEST_TYPE_DROP_MUTANT
retainObservedTestType = False
#else
retainObservedTestType = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_OBSERVED_BENCH_TYPE_DROP_MUTANT
retainObservedBenchType = False
#else
retainObservedBenchType = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_OBSERVED_FLIB_TYPE_DROP_MUTANT
retainObservedFlibType = False
#else
retainObservedFlibType = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_LIB_TYPE_DROP_MUTANT
retainExpectedLibType = False
#else
retainExpectedLibType = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_EXE_TYPE_DROP_MUTANT
retainExpectedExeType = False
#else
retainExpectedExeType = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_TEST_TYPE_DROP_MUTANT
retainExpectedTestType = False
#else
retainExpectedTestType = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_BENCH_TYPE_DROP_MUTANT
retainExpectedBenchType = False
#else
retainExpectedBenchType = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_FLIB_TYPE_DROP_MUTANT
retainExpectedFlibType = False
#else
retainExpectedFlibType = True
#endif

validComponentName :: Int -> Text -> Text -> Bool
validComponentName limit componentType componentName
  | textByteLength componentName > limit = False
  | componentType == "lib" && componentName == "lib" = retainLibraryNameAlternative
  | otherwise =
      case Text.stripPrefix (componentType <> ":") componentName of
        Just suffix -> validUnqualifiedComponentName limit suffix
        Nothing ->
          allowMissingComponentNamePrefix
            && validUnqualifiedComponentName limit componentName

validUnqualifiedComponentName :: Int -> Text -> Bool
validUnqualifiedComponentName limit name =
  textByteLength name <= limit
    && all validChunk (Text.splitOn "-" name)
 where
  validChunk chunk =
    (allowEmptyComponentNameChunk || not (Text.null chunk))
      && Text.all
        (\character -> allowComponentNameCharacter || isAsciiAlphaNumeric character)
        chunk

validUnitId :: Int -> Text -> Bool
validUnitId limit unitId =
  not (Text.null unitId)
    && textByteLength unitId <= limit
    && (allowUnitLeadingCharacter || isAsciiAlphaNumeric (Text.head unitId))
    && (allowUnitTrailingCharacter || isAsciiAlphaNumeric (Text.last unitId))
    && Text.all validCharacter unitId
 where
  validCharacter character =
    allowUnitCharacter
      || isAsciiAlphaNumeric character || elem character ['-', '_', '.', '+', ':']

validCompilerId :: Int -> Text -> Bool
validCompilerId limit compilerId =
  boundedTextBytes limit compilerId
    && case
      if allowCompilerIdPrefixBypass
        then Just (maybe compilerId id (Text.stripPrefix "ghc-" compilerId))
        else Text.stripPrefix "ghc-" compilerId of
    Nothing -> False
    Just version ->
      let segments = Text.splitOn "." version
       in all validSegment segments
 where
  validSegment segment =
    (allowEmptyCompilerIdSegment || not (Text.null segment))
      && Text.all (\character -> allowCompilerIdCharacter || isAsciiDigit character) segment

validModuleName :: Int -> Text -> Bool
validModuleName limit moduleName =
  textByteLength moduleName <= limit
    && all validSegment segments
 where
  segments = Text.splitOn "." moduleName
  validSegment segment = case Text.uncons segment of
    Just (first, rest) ->
      (allowModuleLeadingCharacter || isAsciiUpper first)
        && Text.all validTail rest
    Nothing -> allowEmptyModuleSegment
  validTail character =
    allowModuleTailCharacter
      || isAsciiAlphaNumeric character || character == '_' || character == '\''

retainLibraryNameAlternative, allowMissingComponentNamePrefix,
  allowEmptyComponentNameChunk, allowComponentNameCharacter,
  allowUnitLeadingCharacter, allowUnitTrailingCharacter, allowUnitCharacter,
  allowCompilerIdPrefixBypass, allowEmptyCompilerIdSegment,
  allowCompilerIdCharacter, allowModuleLeadingCharacter,
  allowEmptyModuleSegment, allowModuleTailCharacter :: Bool
#ifdef VALIDATION_COMPILER_BUILDINFO_LIBRARY_NAME_ALTERNATIVE_DROP_MUTANT
retainLibraryNameAlternative = False
#else
retainLibraryNameAlternative = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPONENT_NAME_PREFIX_BYPASS_MUTANT
allowMissingComponentNamePrefix = True
#else
allowMissingComponentNamePrefix = False
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPONENT_NAME_EMPTY_CHUNK_BYPASS_MUTANT
allowEmptyComponentNameChunk = True
#else
allowEmptyComponentNameChunk = False
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPONENT_NAME_CHARACTER_BYPASS_MUTANT
allowComponentNameCharacter = True
#else
allowComponentNameCharacter = False
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_UNIT_LEADING_CHARACTER_BYPASS_MUTANT
allowUnitLeadingCharacter = True
#else
allowUnitLeadingCharacter = False
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_UNIT_TRAILING_CHARACTER_BYPASS_MUTANT
allowUnitTrailingCharacter = True
#else
allowUnitTrailingCharacter = False
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_UNIT_CHARACTER_BYPASS_MUTANT
allowUnitCharacter = True
#else
allowUnitCharacter = False
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPILER_ID_PREFIX_BYPASS_MUTANT
allowCompilerIdPrefixBypass = True
#else
allowCompilerIdPrefixBypass = False
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPILER_ID_EMPTY_SEGMENT_BYPASS_MUTANT
allowEmptyCompilerIdSegment = True
#else
allowEmptyCompilerIdSegment = False
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPILER_ID_CHARACTER_BYPASS_MUTANT
allowCompilerIdCharacter = True
#else
allowCompilerIdCharacter = False
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_MODULE_LEADING_CHARACTER_BYPASS_MUTANT
allowModuleLeadingCharacter = True
#else
allowModuleLeadingCharacter = False
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_MODULE_EMPTY_SEGMENT_BYPASS_MUTANT
allowEmptyModuleSegment = True
#else
allowEmptyModuleSegment = False
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_MODULE_TAIL_CHARACTER_BYPASS_MUTANT
allowModuleTailCharacter = True
#else
allowModuleTailCharacter = False
#endif

isAsciiAlphaNumeric, isAsciiDigit, isAsciiUpper, isAsciiLower :: Char -> Bool
isAsciiAlphaNumeric character =
#ifdef VALIDATION_COMPILER_BUILDINFO_ASCII_ALPHANUMERIC_DIGIT_BRANCH_DROP_MUTANT
  isAsciiUpper character || isAsciiLower character
#elif defined(VALIDATION_COMPILER_BUILDINFO_ASCII_ALPHANUMERIC_LOWER_BRANCH_DROP_MUTANT)
  isAsciiLower character `seq` (isAsciiDigit character || isAsciiUpper character)
#else
  isAsciiDigit character || isAsciiUpper character || isAsciiLower character
#endif
isAsciiDigit character =
#ifdef VALIDATION_COMPILER_BUILDINFO_ASCII_DIGIT_UPPER_BOUND_DROP_MUTANT
  character >= '0'
#else
  character >= '0' && character <= '9'
#endif
isAsciiUpper character =
#ifdef VALIDATION_COMPILER_BUILDINFO_ASCII_UPPER_UPPER_BOUND_DROP_MUTANT
  character >= 'A'
#else
  character >= 'A' && character <= 'Z'
#endif
isAsciiLower character =
#ifdef VALIDATION_COMPILER_BUILDINFO_ASCII_LOWER_LOWER_BOUND_DROP_MUTANT
  character <= 'z'
#else
  character >= 'a' && character <= 'z'
#endif

expectedComponentIdentity :: DiagnosticCompilerBuildInfoExpectedIdentity -> (Text, Text)
expectedComponentIdentity
  (DiagnosticCompilerBuildInfoExpectedIdentity componentType componentName _) =
    (
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_COMPONENT_KEY_TYPE_PROJECTION_MUTANT
      componentType <> "-mutant"
#else
      componentType
#endif
    ,
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_COMPONENT_KEY_NAME_PROJECTION_MUTANT
      componentName <> "-mutant"
#else
      componentName
#endif
    )

expectedUnitIdentity :: DiagnosticCompilerBuildInfoExpectedIdentity -> Text
expectedUnitIdentity (DiagnosticCompilerBuildInfoExpectedIdentity _ _ unitId) =
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_UNIT_PROJECTION_MUTANT
  unitId <> "-mutant"
#else
  unitId
#endif

expectedIdentityComponent
  :: DiagnosticCompilerBuildInfoExpectedIdentity
  -> DiagnosticCompilerBuildInfoComponentIdentity
expectedIdentityComponent
  (DiagnosticCompilerBuildInfoExpectedIdentity componentType componentName unitId) =
    DiagnosticCompilerBuildInfoComponentIdentity
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_IDENTITY_COMPONENT_TYPE_PROJECTION_MUTANT
      (componentType <> "-mutant")
#else
      componentType
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_IDENTITY_COMPONENT_NAME_PROJECTION_MUTANT
      (componentName <> "-mutant")
#else
      componentName
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EXPECTED_IDENTITY_COMPONENT_UNIT_PROJECTION_MUTANT
      (unitId <> "-mutant")
#else
      unitId
#endif

uncurryExpected
  :: (Text -> Text -> Text -> problem)
  -> DiagnosticCompilerBuildInfoExpectedIdentity
  -> problem
uncurryExpected constructor
  (DiagnosticCompilerBuildInfoExpectedIdentity componentType componentName unitId) =
    constructor
#ifdef VALIDATION_COMPILER_BUILDINFO_UNCURRY_EXPECTED_TYPE_PROJECTION_MUTANT
      (componentType <> "-mutant")
#else
      componentType
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_UNCURRY_EXPECTED_NAME_PROJECTION_MUTANT
      (componentName <> "-mutant")
#else
      componentName
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_UNCURRY_EXPECTED_UNIT_PROJECTION_MUTANT
      (unitId <> "-mutant")
#else
      unitId
#endif

componentObservationType :: DiagnosticCompilerBuildInfoComponentObservation -> Text
componentObservationType component =
  case componentObservationIdentity component of
    DiagnosticCompilerBuildInfoComponentIdentity value _ _ ->
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPONENT_OBSERVATION_TYPE_ACCESSOR_MUTANT
      value <> "-mutant"
#else
      value
#endif
componentObservationName :: DiagnosticCompilerBuildInfoComponentObservation -> Text
componentObservationName component =
  case componentObservationIdentity component of
    DiagnosticCompilerBuildInfoComponentIdentity _ value _ ->
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPONENT_OBSERVATION_NAME_ACCESSOR_MUTANT
      value <> "-mutant"
#else
      value
#endif
componentObservationUnitId :: DiagnosticCompilerBuildInfoComponentObservation -> Text
componentObservationUnitId component =
  case componentObservationIdentity component of
    DiagnosticCompilerBuildInfoComponentIdentity _ _ value ->
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPONENT_OBSERVATION_UNIT_ACCESSOR_MUTANT
      value <> "-mutant"
#else
      value
#endif
componentObservationCompilerArguments
  :: DiagnosticCompilerBuildInfoComponentObservation
  -> [DiagnosticCompilerBuildInfoArgumentObservation]
componentObservationCompilerArguments
  (DiagnosticCompilerBuildInfoComponentObservation _ value _ _ _ _ _ _ _ _) =
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPONENT_COMPILER_ARGUMENTS_ACCESSOR_MUTANT
    value <> take 1 value
#else
    value
#endif
componentObservationModules :: DiagnosticCompilerBuildInfoComponentObservation -> [Text]
componentObservationModules
  (DiagnosticCompilerBuildInfoComponentObservation _ _ value _ _ _ _ _ _ _) =
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPONENT_MODULES_ACCESSOR_MUTANT
    value <> take 1 value
#else
    value
#endif
componentObservationSourceFiles
  :: DiagnosticCompilerBuildInfoComponentObservation -> [FilePath]
componentObservationSourceFiles
  (DiagnosticCompilerBuildInfoComponentObservation _ _ _ value _ _ _ _ _ _) =
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPONENT_SOURCE_FILES_ACCESSOR_MUTANT
    value <> take 1 value
#else
    value
#endif
componentObservationSourceDirectories
  :: DiagnosticCompilerBuildInfoComponentObservation -> [FilePath]
componentObservationSourceDirectories
  (DiagnosticCompilerBuildInfoComponentObservation _ _ _ _ value _ _ _ _ _) =
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPONENT_SOURCE_DIRECTORIES_ACCESSOR_MUTANT
    value <> take 1 value
#else
    value
#endif
componentObservationSourceDirectory
  :: DiagnosticCompilerBuildInfoComponentObservation -> FilePath
componentObservationSourceDirectory
  (DiagnosticCompilerBuildInfoComponentObservation _ _ _ _ _ value _ _ _ _) =
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPONENT_SOURCE_ROOT_ACCESSOR_MUTANT
    value <> "-mutant"
#else
    value
#endif
componentObservationCabalFile
  :: DiagnosticCompilerBuildInfoComponentObservation -> Maybe FilePath
componentObservationCabalFile
  (DiagnosticCompilerBuildInfoComponentObservation _ _ _ _ _ _ value _ _ _) =
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPONENT_CABAL_FILE_ACCESSOR_MUTANT
    (<> "-mutant") <$> value
#else
    value
#endif
componentObservationArgumentPaths
  :: DiagnosticCompilerBuildInfoComponentObservation
  -> [DiagnosticCompilerBuildInfoPathObservation]
componentObservationArgumentPaths
  (DiagnosticCompilerBuildInfoComponentObservation _ _ _ _ _ _ _ value _ _) =
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPONENT_ARGUMENT_PATHS_ACCESSOR_MUTANT
    value <> take 1 value
#else
    value
#endif
componentObservationGeneratedInputs
  :: DiagnosticCompilerBuildInfoComponentObservation
  -> [DiagnosticCompilerBuildInfoGeneratedInputObservation]
componentObservationGeneratedInputs
  (DiagnosticCompilerBuildInfoComponentObservation _ _ _ _ _ _ _ _ value _) =
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPONENT_GENERATED_INPUTS_ACCESSOR_MUTANT
    value <> take 1 value
#else
    value
#endif
componentObservationPackageIds
  :: DiagnosticCompilerBuildInfoComponentObservation
  -> [DiagnosticCompilerBuildInfoPackageObservation]
componentObservationPackageIds
  (DiagnosticCompilerBuildInfoComponentObservation _ _ _ _ _ _ _ _ _ value) =
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPONENT_PACKAGE_IDS_ACCESSOR_MUTANT
    value <> take 1 value
#else
    value
#endif

componentObservationIdentity
  :: DiagnosticCompilerBuildInfoComponentObservation
  -> DiagnosticCompilerBuildInfoComponentIdentity
componentObservationIdentity
  (DiagnosticCompilerBuildInfoComponentObservation value _ _ _ _ _ _ _ _ _) =
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPONENT_IDENTITY_ACCESSOR_MUTANT
    case value of
      DiagnosticCompilerBuildInfoComponentIdentity componentType componentName unitId ->
        DiagnosticCompilerBuildInfoComponentIdentity componentType componentName
          (unitId <> "-mutant")
#else
    value
#endif

componentObservationComponentKey
  :: DiagnosticCompilerBuildInfoComponentObservation -> (Text, Text)
componentObservationComponentKey component =
  (
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPONENT_KEY_TYPE_PROJECTION_MUTANT
    componentObservationType component <> "-mutant"
#else
    componentObservationType component
#endif
  ,
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPONENT_KEY_NAME_PROJECTION_MUTANT
    componentObservationName component <> "-mutant"
#else
    componentObservationName component
#endif
  )

parsedProblems :: Parsed value -> [DiagnosticCompilerBuildInfoProblem]
parsedProblems (Parsed problems _) =
#ifdef VALIDATION_COMPILER_BUILDINFO_PARSED_PROBLEMS_ACCESSOR_MUTANT
  problems <> problems
#else
  problems
#endif
parsedValue :: Parsed value -> Maybe value
#ifdef VALIDATION_COMPILER_BUILDINFO_PARSED_VALUE_ACCESSOR_MUTANT
parsedValue (Parsed _ _) = Nothing
#else
parsedValue (Parsed _ value) = value
#endif

partitionParsed :: [Parsed value] -> ([DiagnosticCompilerBuildInfoProblem], Maybe [value])
partitionParsed = go emptyProblemAccumulator
#ifdef VALIDATION_COMPILER_BUILDINFO_PARTITION_COMPLETE_SEED_MUTANT
  False
#else
  True
#endif
  []
 where
  go accumulator complete values [] =
    (finishProblemAccumulator accumulator,
      if complete then Just
#ifdef VALIDATION_COMPILER_BUILDINFO_PARTITION_FINAL_VALUE_ORDER_MUTANT
        values
#else
        (reverse values)
#endif
      else Nothing)
  go accumulator complete values (Parsed problems value : remaining) =
    let nextAccumulator =
#ifdef VALIDATION_COMPILER_BUILDINFO_PARTITION_PROBLEM_ACCUMULATION_ROUTE_MUTANT
          problems `seq` accumulator
#else
          addProblemsToAccumulator problems accumulator
#endif
        nextComplete =
#ifdef VALIDATION_COMPILER_BUILDINFO_PARTITION_COMPLETENESS_ROUTE_MUTANT
          value `seq` complete
#else
          complete && maybe False (const True) value
#endif
        nextValues =
#ifdef VALIDATION_COMPILER_BUILDINFO_PARTITION_VALUE_ACCUMULATION_ROUTE_MUTANT
          value `seq` values
#else
          maybe values (: values) value
#endif
     in case nextAccumulator of
          DiagnosticProblemAccumulator _ True _ ->
            (finishProblemAccumulator nextAccumulator, Nothing)
          _ -> go nextAccumulator nextComplete nextValues remaining

requiredText :: Text -> Object -> Text -> Parsed Text
requiredText scope object field = case KeyMap.lookup (Key.fromText field) object of
  Nothing -> Parsed
#ifdef VALIDATION_COMPILER_BUILDINFO_REQUIRED_TEXT_MISSING_RESULT_ROUTE_MUTANT
    ([BuildInfoFieldMissing scope field | enforceRequiredTextPresence]
      <> [BuildInfoFieldMissing scope field | enforceRequiredTextPresence])
#else
    [BuildInfoFieldMissing scope field | enforceRequiredTextPresence]
#endif
    Nothing
  Just (String value)
    | Text.null value ->
        Parsed
#ifdef VALIDATION_COMPILER_BUILDINFO_REQUIRED_TEXT_EMPTY_RESULT_ROUTE_MUTANT
          ([BuildInfoTextEmpty scope field | enforceRequiredTextNonEmpty]
            <> [BuildInfoTextEmpty scope field | enforceRequiredTextNonEmpty])
#else
          [BuildInfoTextEmpty scope field | enforceRequiredTextNonEmpty]
#endif
          Nothing
    | otherwise -> Parsed [] (Just
#ifdef VALIDATION_COMPILER_BUILDINFO_REQUIRED_TEXT_SUCCESS_RESULT_ROUTE_MUTANT
        (value <> "-mutant")
#else
        value
#endif
        )
  Just _ ->
    Parsed
#ifdef VALIDATION_COMPILER_BUILDINFO_REQUIRED_TEXT_TYPE_RESULT_ROUTE_MUTANT
      ([BuildInfoFieldWrongType scope field "text" | enforceRequiredTextType]
        <> [BuildInfoFieldWrongType scope field "text" | enforceRequiredTextType])
#else
      [BuildInfoFieldWrongType scope field "text" | enforceRequiredTextType]
#endif
      Nothing

requiredFilePath :: Text -> Object -> Text -> Parsed FilePath
requiredFilePath scope object field = fmapParsed
#ifdef VALIDATION_COMPILER_BUILDINFO_REQUIRED_FILE_PATH_TRANSFORM_MUTANT
  ((<> "-mutant") . Text.unpack)
#else
  Text.unpack
#endif
  (requiredText scope object field)

optionalFilePath :: Text -> Object -> Text -> Parsed (Maybe FilePath)
optionalFilePath scope object field = case KeyMap.lookup (Key.fromText field) object of
  Nothing -> Parsed []
#ifdef VALIDATION_COMPILER_BUILDINFO_OPTIONAL_FILE_ABSENT_RESULT_ROUTE_MUTANT
    Nothing
#else
    (Just Nothing)
#endif
  Just (String value)
    | Text.null value ->
        Parsed
#ifdef VALIDATION_COMPILER_BUILDINFO_OPTIONAL_FILE_EMPTY_RESULT_ROUTE_MUTANT
          ([BuildInfoTextEmpty scope field | enforceOptionalTextNonEmpty]
            <> [BuildInfoTextEmpty scope field | enforceOptionalTextNonEmpty])
#else
          [BuildInfoTextEmpty scope field | enforceOptionalTextNonEmpty]
#endif
          Nothing
    | otherwise -> Parsed [] (Just (Just
#ifdef VALIDATION_COMPILER_BUILDINFO_OPTIONAL_FILE_SUCCESS_RESULT_ROUTE_MUTANT
        (Text.unpack value <> "-mutant")
#else
        (Text.unpack value)
#endif
        ))
  Just _ ->
    Parsed
#ifdef VALIDATION_COMPILER_BUILDINFO_OPTIONAL_FILE_TYPE_RESULT_ROUTE_MUTANT
      ([BuildInfoFieldWrongType scope field "text" | enforceOptionalTextType]
        <> [BuildInfoFieldWrongType scope field "text" | enforceOptionalTextType])
#else
      [BuildInfoFieldWrongType scope field "text" | enforceOptionalTextType]
#endif
      Nothing

requiredObject :: Text -> Object -> Text -> Parsed Object
requiredObject scope object field = case KeyMap.lookup (Key.fromText field) object of
  Nothing ->
    Parsed
#ifdef VALIDATION_COMPILER_BUILDINFO_REQUIRED_OBJECT_MISSING_RESULT_ROUTE_MUTANT
      ([BuildInfoFieldMissing scope field | enforceRequiredObjectPresence]
        <> [BuildInfoFieldMissing scope field | enforceRequiredObjectPresence])
#else
      [BuildInfoFieldMissing scope field | enforceRequiredObjectPresence]
#endif
      Nothing
  Just (Object value) -> Parsed [] (Just
#ifdef VALIDATION_COMPILER_BUILDINFO_REQUIRED_OBJECT_SUCCESS_RESULT_ROUTE_MUTANT
    (value `seq` KeyMap.empty)
#else
    value
#endif
    )
  Just _ ->
    Parsed
#ifdef VALIDATION_COMPILER_BUILDINFO_REQUIRED_OBJECT_TYPE_RESULT_ROUTE_MUTANT
      ([BuildInfoFieldWrongType scope field "object" | enforceRequiredObjectType]
        <> [BuildInfoFieldWrongType scope field "object" | enforceRequiredObjectType])
#else
      [BuildInfoFieldWrongType scope field "object" | enforceRequiredObjectType]
#endif
      Nothing

requiredArray :: Text -> Object -> Text -> Parsed [Value]
requiredArray scope object field = case KeyMap.lookup (Key.fromText field) object of
  Nothing ->
    Parsed
#ifdef VALIDATION_COMPILER_BUILDINFO_REQUIRED_ARRAY_MISSING_RESULT_ROUTE_MUTANT
      ([BuildInfoFieldMissing scope field | enforceRequiredArrayPresence]
        <> [BuildInfoFieldMissing scope field | enforceRequiredArrayPresence])
#else
      [BuildInfoFieldMissing scope field | enforceRequiredArrayPresence]
#endif
      Nothing
  Just (Array values) -> Parsed [] (Just
#ifdef VALIDATION_COMPILER_BUILDINFO_REQUIRED_ARRAY_SUCCESS_RESULT_ROUTE_MUTANT
    (drop 1 (foldr (:) [] values))
#else
    (foldr (:) [] values)
#endif
    )
  Just _ ->
    Parsed
#ifdef VALIDATION_COMPILER_BUILDINFO_REQUIRED_ARRAY_TYPE_RESULT_ROUTE_MUTANT
      ([BuildInfoFieldWrongType scope field "array" | enforceRequiredArrayType]
        <> [BuildInfoFieldWrongType scope field "array" | enforceRequiredArrayType])
#else
      [BuildInfoFieldWrongType scope field "array" | enforceRequiredArrayType]
#endif
      Nothing

requiredTextArray :: Int -> Text -> Object -> Text -> Parsed [Text]
requiredTextArray maximumEntries scope object field =
  case rawArray of
    Parsed problems Nothing -> Parsed problems Nothing
    Parsed problems (Just values)
      | entryCount > maximumEntries ->
          Parsed [BuildInfoResourceLimitExceeded (scope <> "." <> field)
            maximumEntries
#ifdef VALIDATION_COMPILER_BUILDINFO_TEXT_ARRAY_LIMIT_COUNT_PROJECTION_MUTANT
            (entryCount + 1)
#else
            entryCount
#endif
            ] Nothing
      | otherwise ->
          let entries = zipWith parseTextArrayEntry [0 ..]
#ifdef VALIDATION_COMPILER_BUILDINFO_TEXT_ARRAY_PARTITION_COMPOSITION_MUTANT
                (reverse values)
#else
                values
#endif
              (entryProblems, parsedEntries) = partitionParsed entries
           in Parsed (problems <> entryProblems) parsedEntries
 where
  rawArray = requiredArray scope object field
  entryCount =
    maybe 0 (boundedLength (maximumEntries + 1)) (parsedValue rawArray)
  parseTextArrayEntry index (String value)
    | Text.null value =
        Parsed
#ifdef VALIDATION_COMPILER_BUILDINFO_ARRAY_TEXT_EMPTY_RESULT_ROUTE_MUTANT
          ([BuildInfoArrayTextEmpty scope field index | enforceArrayTextNonEmpty]
            <> [BuildInfoArrayTextEmpty scope field index | enforceArrayTextNonEmpty])
#else
          [BuildInfoArrayTextEmpty scope field index | enforceArrayTextNonEmpty]
#endif
          Nothing
    | otherwise = Parsed [] (Just value)
  parseTextArrayEntry index _ =
    Parsed
#ifdef VALIDATION_COMPILER_BUILDINFO_ARRAY_TEXT_TYPE_RESULT_ROUTE_MUTANT
      ([BuildInfoArrayElementWrongType scope field index "text" | enforceArrayTextType]
        <> [BuildInfoArrayElementWrongType scope field index "text" | enforceArrayTextType])
#else
      [BuildInfoArrayElementWrongType scope field index "text" | enforceArrayTextType]
#endif
      Nothing

requiredFilePathArray :: Int -> Text -> Object -> Text -> Parsed [FilePath]
requiredFilePathArray maximumEntries scope object field =
  fmapParsed
#ifdef VALIDATION_COMPILER_BUILDINFO_REQUIRED_FILE_PATH_ARRAY_TRANSFORM_MUTANT
    (map ((<> "-mutant") . Text.unpack))
#else
    (map Text.unpack)
#endif
    (requiredTextArray maximumEntries scope object field)

fmapParsed :: (left -> right) -> Parsed left -> Parsed right
fmapParsed transform (Parsed problems value) = Parsed
#ifdef VALIDATION_COMPILER_BUILDINFO_FMAP_PARSED_PROBLEM_PROJECTION_MUTANT
  (problems <> problems)
#else
  problems
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_FMAP_PARSED_VALUE_ROUTE_MUTANT
  (transform `seq` value `seq` Nothing)
#else
  (transform <$> value)
#endif

unknownFields :: Text -> Set Text -> Object -> [DiagnosticCompilerBuildInfoProblem]
unknownFields scope allowed object =
  [BuildInfoFieldUnknown
#ifdef VALIDATION_COMPILER_BUILDINFO_UNKNOWN_FIELD_SCOPE_PROJECTION_MUTANT
    (scope <> "-mutant")
#else
    scope
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_UNKNOWN_FIELD_NAME_PROJECTION_MUTANT
    (field <> "-mutant")
#else
    field
#endif
  | enforceUnknownFields,
    field <- sort (map Key.toText (KeyMap.keys object))
  , Set.notMember field allowed]

enforceComponentObject, enforceRequiredTextPresence, enforceRequiredTextNonEmpty,
  enforceRequiredTextType, enforceOptionalTextNonEmpty, enforceOptionalTextType,
  enforceRequiredObjectPresence, enforceRequiredObjectType,
  enforceRequiredArrayPresence, enforceRequiredArrayType,
  enforceArrayTextNonEmpty, enforceArrayTextType, enforceUnknownFields :: Bool
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPONENT_OBJECT_BYPASS_MUTANT
enforceComponentObject = False
#else
enforceComponentObject = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_REQUIRED_TEXT_MISSING_BYPASS_MUTANT
enforceRequiredTextPresence = False
#else
enforceRequiredTextPresence = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_REQUIRED_TEXT_EMPTY_BYPASS_MUTANT
enforceRequiredTextNonEmpty = False
#else
enforceRequiredTextNonEmpty = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_REQUIRED_TEXT_TYPE_BYPASS_MUTANT
enforceRequiredTextType = False
#else
enforceRequiredTextType = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_OPTIONAL_TEXT_EMPTY_BYPASS_MUTANT
enforceOptionalTextNonEmpty = False
#else
enforceOptionalTextNonEmpty = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_OPTIONAL_TEXT_TYPE_BYPASS_MUTANT
enforceOptionalTextType = False
#else
enforceOptionalTextType = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_REQUIRED_OBJECT_MISSING_BYPASS_MUTANT
enforceRequiredObjectPresence = False
#else
enforceRequiredObjectPresence = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_REQUIRED_OBJECT_TYPE_BYPASS_MUTANT
enforceRequiredObjectType = False
#else
enforceRequiredObjectType = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_REQUIRED_ARRAY_MISSING_BYPASS_MUTANT
enforceRequiredArrayPresence = False
#else
enforceRequiredArrayPresence = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_REQUIRED_ARRAY_TYPE_BYPASS_MUTANT
enforceRequiredArrayType = False
#else
enforceRequiredArrayType = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_ARRAY_TEXT_EMPTY_BYPASS_MUTANT
enforceArrayTextNonEmpty = False
#else
enforceArrayTextNonEmpty = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_ARRAY_TEXT_TYPE_BYPASS_MUTANT
enforceArrayTextType = False
#else
enforceArrayTextType = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_UNKNOWN_FIELD_BYPASS_MUTANT
enforceUnknownFields = False
#else
enforceUnknownFields = True
#endif

componentScope :: Int -> Text
componentScope index = "build-info.components[" <> Text.pack (show
#ifdef VALIDATION_COMPILER_BUILDINFO_COMPONENT_SCOPE_INDEX_INCREMENT_MUTANT
  (index + 1)
#else
  index
#endif
  ) <> "]"

duplicates :: Ord value => [value] -> [value]
duplicates = mapMaybe duplicateHead . group . sort
 where
#ifdef VALIDATION_COMPILER_BUILDINFO_DUPLICATES_PAIR_THRESHOLD_MUTANT
  duplicateHead (value : _ : _ : _) = Just value
#else
  duplicateHead (value : _ : _) = Just value
#endif
  duplicateHead _ = Nothing

safeAbsolutePath :: FilePath -> Bool
safeAbsolutePath path =
  isAbsolutePath path
    && (allowAbsoluteFileTrailingSeparator || not (hasTrailingSeparator path))
    &&
#ifdef VALIDATION_COMPILER_BUILDINFO_SAFE_ABSOLUTE_PATH_SEGMENT_COMPOSITION_DROP_MUTANT
      (safeAbsoluteSegments path `seq` True)
#else
      safeAbsoluteSegments path
#endif

safeAbsolutePathAllowDirectory :: FilePath -> Bool
safeAbsolutePathAllowDirectory path =
  isAbsolutePath path &&
#ifdef VALIDATION_COMPILER_BUILDINFO_SAFE_ABSOLUTE_DIRECTORY_SEGMENT_COMPOSITION_DROP_MUTANT
    (safeAbsoluteSegments path `seq` True)
#else
    safeAbsoluteSegments path
#endif

safeAbsoluteSegments :: FilePath -> Bool
safeAbsoluteSegments path =
  not (unsafePathCharacters path)
    &&
#ifdef VALIDATION_COMPILER_BUILDINFO_SAFE_ABSOLUTE_DEPTH_INCREMENT_MUTANT
      length segments + 1 <= maximumPathDepth
#else
      length segments <= maximumPathDepth
#endif
    && all validSegment segments
 where
  withoutEdges = Text.dropWhileEnd (== '/') (Text.dropWhile (== '/') (Text.pack path))
  segments = Text.splitOn "/" withoutEdges
  validSegment segment =
    (allowEmptyPathSegment || not (Text.null segment))
      && (allowDotPathSegment || segment /= ".")
      && (allowParentPathSegment || segment /= "..")
      && textByteLength segment <= maximumPathSegmentBytes

safeRelativePath :: Bool -> FilePath -> Bool
safeRelativePath allowDot path =
  not (unsafePathCharacters path) &&
#ifdef VALIDATION_COMPILER_BUILDINFO_SAFE_RELATIVE_DEPTH_INCREMENT_MUTANT
    length segments + 1 <= maximumPathDepth
#else
    length segments <= maximumPathDepth
#endif
    && ((allowDot && retainRelativeDotAlternative && path == ".")
      || all validSegment segments)
 where
  segments = Text.splitOn "/" (Text.pack path)
  validSegment segment =
    (allowEmptyPathSegment || not (Text.null segment))
      && (allowDotPathSegment || segment /= ".")
      && (allowParentPathSegment || segment /= "..")
      && textByteLength segment <= maximumPathSegmentBytes

safeMachineArgumentPath :: FilePath -> Bool
safeMachineArgumentPath path
  | isAbsolutePath path =
#ifdef VALIDATION_COMPILER_BUILDINFO_SAFE_MACHINE_ARGUMENT_ABSOLUTE_ROUTE_MUTANT
      safeAbsolutePathAllowDirectory path `seq` safeRelativePath True path
#else
      safeAbsolutePathAllowDirectory path
#endif
  | otherwise =
#ifdef VALIDATION_COMPILER_BUILDINFO_SAFE_MACHINE_ARGUMENT_RELATIVE_ROUTE_MUTANT
      safeRelativePath True path `seq` safeAbsolutePathAllowDirectory path
#else
      safeRelativePath True path
#endif

isAbsolutePath :: FilePath -> Bool
#ifdef VALIDATION_COMPILER_BUILDINFO_IS_ABSOLUTE_PATH_PREFIX_DROP_MUTANT
isAbsolutePath = Text.isPrefixOf "//" . Text.pack
#else
isAbsolutePath = Text.isPrefixOf "/" . Text.pack
#endif

hasTrailingSeparator :: FilePath -> Bool
#ifdef VALIDATION_COMPILER_BUILDINFO_TRAILING_SEPARATOR_SUFFIX_DROP_MUTANT
hasTrailingSeparator = Text.isSuffixOf "//" . Text.pack
#else
hasTrailingSeparator = Text.isSuffixOf "/" . Text.pack
#endif

unsafePathCharacters :: FilePath -> Bool
unsafePathCharacters path =
#ifdef VALIDATION_COMPILER_BUILDINFO_UNSAFE_PATH_TEXT_PREDICATE_DROP_MUTANT
  unsafeCharacter 'x' `seq` False
#else
  Text.any unsafeCharacter text
#endif
    ||
#ifdef VALIDATION_COMPILER_BUILDINFO_UNSAFE_PATH_BACKSLASH_PREDICATE_DROP_MUTANT
      allowPathBackslash `seq` False
#else
      (not allowPathBackslash && Text.isInfixOf "\\" text)
#endif
 where
  text = Text.pack path
  unsafeCharacter character =
    (not allowPathControl && (ord character < 32 || ord character == 127))
      || (not allowPathColon && character == ':')

allowAbsoluteFileTrailingSeparator, allowEmptyPathSegment, allowDotPathSegment,
  allowParentPathSegment, retainRelativeDotAlternative, allowPathBackslash,
  allowPathControl, allowPathColon :: Bool
#ifdef VALIDATION_COMPILER_BUILDINFO_ABSOLUTE_FILE_TRAILING_BYPASS_MUTANT
allowAbsoluteFileTrailingSeparator = True
#else
allowAbsoluteFileTrailingSeparator = False
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_EMPTY_PATH_SEGMENT_BYPASS_MUTANT
allowEmptyPathSegment = True
#else
allowEmptyPathSegment = False
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_DOT_PATH_SEGMENT_BYPASS_MUTANT
allowDotPathSegment = True
#else
allowDotPathSegment = False
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_PARENT_PATH_SEGMENT_BYPASS_MUTANT
allowParentPathSegment = True
#else
allowParentPathSegment = False
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_RELATIVE_DOT_ALTERNATIVE_DROP_MUTANT
retainRelativeDotAlternative = False
#else
retainRelativeDotAlternative = True
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_PATH_BACKSLASH_BYPASS_MUTANT
allowPathBackslash = True
#else
allowPathBackslash = False
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_PATH_CONTROL_BYPASS_MUTANT
allowPathControl = True
#else
allowPathControl = False
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_PATH_COLON_BYPASS_MUTANT
allowPathColon = True
#else
allowPathColon = False
#endif

absolutePathWithin :: FilePath -> FilePath -> Bool
absolutePathWithin sourceDirectory path =
  let root = Text.pack sourceDirectory
      candidate = Text.pack path
   in
#ifdef VALIDATION_COMPILER_BUILDINFO_ABSOLUTE_PATH_WITHIN_NORMALIZED_EQUALITY_DROP_MUTANT
      False
#else
      candidate == Text.dropWhileEnd (== '/') root
#endif
        ||
#ifdef VALIDATION_COMPILER_BUILDINFO_ABSOLUTE_PATH_WITHIN_PREFIX_DROP_MUTANT
          False
#else
          Text.isPrefixOf root candidate
#endif

textByteLength :: Text -> Int
#ifdef VALIDATION_COMPILER_BUILDINFO_TEXT_BYTE_LENGTH_ASCII_WIDTH_MUTANT
textByteLength = Text.length
#else
textByteLength = ByteString.length . TextEncoding.encodeUtf8
#endif

boundedTextBytes :: Int -> Text -> Bool
boundedTextBytes limit value =
  let measured = ByteString.length (TextEncoding.encodeUtf8 (Text.take (limit + 1) value))
   in
#ifdef VALIDATION_COMPILER_BUILDINFO_BOUNDED_TEXT_EXACT_BOUNDARY_NARROW_MUTANT
      measured < limit
#elif defined(VALIDATION_COMPILER_BUILDINFO_BOUNDED_TEXT_ONE_OVER_WIDEN_MUTANT)
      measured <= limit + 1
#else
      measured <= limit
#endif

boundedFilePathBytes :: Int -> FilePath -> Bool
boundedFilePathBytes limit value =
  let prefix = take
#ifdef VALIDATION_COMPILER_BUILDINFO_BOUNDED_FILE_PATH_PREFIX_THRESHOLD_DROP_MUTANT
        limit
#else
        (limit + 1)
#endif
        value
   in boundedLength (limit + 1) prefix <= limit
        && boundedTextBytes limit (Text.pack prefix)

maybeToList :: Maybe value -> [value]
maybeToList Nothing = []
#ifdef VALIDATION_COMPILER_BUILDINFO_MAYBE_TO_LIST_JUST_DROP_MUTANT
maybeToList (Just _) = []
#else
maybeToList (Just value) = [value]
#endif

boundedLength :: Int -> [value] -> Int
boundedLength limit = go 0
 where
  go !count _
#ifdef VALIDATION_COMPILER_BUILDINFO_BOUNDED_LENGTH_THRESHOLD_NARROW_MUTANT
    | count >= limit - 1 = count
#else
    | count >= limit = count
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_BOUNDED_LENGTH_EMPTY_INCREMENT_MUTANT
  go !count [] = count + 1
#else
  go !count [] = count
#endif
  go !count (_ : rest) = go
#ifdef VALIDATION_COMPILER_BUILDINFO_BOUNDED_LENGTH_STEP_DOUBLE_MUTANT
    (count + 2)
#else
    (count + 1)
#endif
    rest

boundedProblems
  :: [DiagnosticCompilerBuildInfoProblem]
  -> [DiagnosticCompilerBuildInfoProblem]
boundedProblems problems =
  finishProblemAccumulator (addProblemsToAccumulator problems emptyProblemAccumulator)

singleProblemRefusal :: DiagnosticCompilerBuildInfoProblem -> DiagnosticCompilerBuildInfoRefusal
singleProblemRefusal problem =
#ifdef VALIDATION_COMPILER_BUILDINFO_SINGLE_PROBLEM_REFUSAL_DUPLICATE_ROUTE_MUTANT
  DiagnosticCompilerBuildInfoRefusal (problem :| [problem]) Nothing
#else
  DiagnosticCompilerBuildInfoRefusal (problem :| []) Nothing
#endif

hardRefusal :: [DiagnosticCompilerBuildInfoProblem] -> DiagnosticCompilerBuildInfoRefusal
hardRefusal problems =
  DiagnosticCompilerBuildInfoRefusal (boundedProblemSet "hard-refusal" problems) Nothing

observedRefusal
  :: [DiagnosticCompilerBuildInfoProblem]
  -> DiagnosticCompilerBuildInfoSnapshot
  -> DiagnosticCompilerBuildInfoRefusal
observedRefusal problems snapshot =
  DiagnosticCompilerBuildInfoRefusal
    (boundedProblemSet "observed-refusal" problems) (Just snapshot)

boundedProblemSet
  :: Text
  -> [DiagnosticCompilerBuildInfoProblem]
  -> NonEmpty DiagnosticCompilerBuildInfoProblem
boundedProblemSet label problems =
  case NonEmpty.nonEmpty canonicalProblems of
    Just nonEmpty ->
#ifdef VALIDATION_COMPILER_BUILDINFO_BOUNDED_PROBLEM_NONEMPTY_ROUTE_MUTANT
      NonEmpty.head nonEmpty :| NonEmpty.toList nonEmpty
#else
      nonEmpty
#endif
    Nothing ->
      BuildInfoDuplicateKeyScanFailed
        ("empty diagnostic problem set at " <> label) :| []
 where
#ifdef VALIDATION_COMPILER_BUILDINFO_PROBLEM_ORDER_BYPASS_MUTANT
  canonicalProblems = boundedProblems problems
#else
  canonicalProblems = sort (boundedProblems problems)
#endif

-- Duplicate-aware, resource-bounded JSON scan.  A structural token is one
-- JSON value or one object key.  The scan refuses before Aeson can normalize
-- duplicate keys or traverse unbounded attacker-selected structure.

data JsonScanState
  = JsonScanState !Int

scanDuplicateJsonKeys
  :: ByteString
  -> Either DiagnosticCompilerBuildInfoProblem ()
scanDuplicateJsonKeys bytes = do
  (afterValue, _) <-
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_SCAN_STATE_SEED_MUTANT
    scanJsonValue "build-info" bytes 1 (JsonScanState 1)
#else
    scanJsonValue "build-info" bytes 1 (JsonScanState 0)
#endif
      0
  let afterWhitespace =
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_FINAL_WHITESPACE_ROUTE_DROP_MUTANT
        afterValue
#else
        skipWhitespace bytes afterValue
#endif
  if afterWhitespace == ByteString.length bytes
    then Right ()
    else if allowTrailingJsonBytes
      then Right ()
    else malformed
      ("unexpected bytes after JSON value at offset " <> Text.pack (show afterWhitespace))

scanJsonValue
  :: Text -> ByteString -> Int -> JsonScanState -> Int
  -> Either DiagnosticCompilerBuildInfoProblem (Int, JsonScanState)
scanJsonValue scope bytes depth state offset
  | depth > maximumJsonDepth =
      Left (BuildInfoResourceLimitExceeded "json-depth" maximumJsonDepth depth)
  | otherwise = do
      nextState <- consumeJsonToken state
      case byteAt bytes start of
        Nothing -> malformed ("unexpected end of JSON at " <> scope)
        Just 123 ->
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_OBJECT_DISPATCH_ROUTE_MUTANT
          do
            (afterObject, finalState) <-
              scanJsonObject scope bytes depth nextState start
            Right (afterObject + 1, finalState)
#else
          scanJsonObject scope bytes depth nextState start
#endif
        Just 91 ->
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_ARRAY_DISPATCH_ROUTE_MUTANT
          do
            (afterArray, finalState) <- scanJsonArray scope bytes depth nextState start
            Right (afterArray + 1, finalState)
#else
          scanJsonArray scope bytes depth nextState start
#endif
        Just 34 -> do
          (afterString, _) <- scanJsonString scope bytes start
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_STRING_DISPATCH_ROUTE_MUTANT
          Right (afterString + 1, nextState)
#else
          Right (afterString, nextState)
#endif
        Just _ -> do
          afterScalar <- scanJsonScalar scope bytes start
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_SCALAR_DISPATCH_ROUTE_MUTANT
          Right (afterScalar + 1, nextState)
#else
          Right (afterScalar, nextState)
#endif
 where
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_VALUE_START_WHITESPACE_DROP_MUTANT
  start = offset
#else
  start = skipWhitespace bytes offset
#endif

scanJsonObject
  :: Text -> ByteString -> Int -> JsonScanState -> Int
  -> Either DiagnosticCompilerBuildInfoProblem (Int, JsonScanState)
scanJsonObject scope bytes depth state opening =
  loop Set.empty 0 state
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_OBJECT_OPENING_WHITESPACE_DROP_MUTANT
    (opening + 1)
#else
    (skipWhitespace bytes (opening + 1))
#endif
 where
  loop seen memberCount currentState offset = case byteAt bytes offset of
    Just 125 -> Right (offset + 1, currentState)
    Just 34
      | memberCount >= maximumJsonObjectMembers ->
          Left (BuildInfoResourceLimitExceeded "json-object-members"
            maximumJsonObjectMembers (memberCount + 1))
      | otherwise -> do
          stateAfterKey <- consumeJsonToken currentState
          (afterKey, key) <- scanJsonString (scope <> ".<key>") bytes offset
          stateAfterDuplicate <-
#ifdef VALIDATION_COMPILER_BUILDINFO_DUPLICATE_KEY_BYPASS_MUTANT
            Right stateAfterKey
#else
            if Set.member key seen
              then Left (BuildInfoJsonDuplicateKey scope key)
              else Right stateAfterKey
#endif
          afterColon <-
            expectByte bytes 58
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_OBJECT_AFTER_KEY_WHITESPACE_DROP_MUTANT
              afterKey
#else
              (skipWhitespace bytes afterKey)
#endif
              ("':' after key in " <> scope)
          (afterValue, stateAfterValue) <-
            scanJsonValue
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_OBJECT_VALUE_SCOPE_DROP_MUTANT
              (escapedScopeToken key `seq` scope)
#else
              (scope <> "." <> escapedScopeToken key)
#endif
              bytes (depth + 1) stateAfterDuplicate
              afterColon
          let next =
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_OBJECT_AFTER_VALUE_WHITESPACE_DROP_MUTANT
                afterValue
#else
                skipWhitespace bytes afterValue
#endif
              nextSeen =
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_OBJECT_SEEN_INSERT_DROP_MUTANT
                seen
#else
                Set.insert key seen
#endif
          case byteAt bytes next of
            Just 44 ->
              loop nextSeen
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_OBJECT_MEMBER_INCREMENT_DOUBLE_MUTANT
                (memberCount + 2)
#else
                (memberCount + 1)
#endif
                stateAfterValue
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_OBJECT_COMMA_WHITESPACE_DROP_MUTANT
                (next + 1)
#else
                (skipWhitespace bytes (next + 1))
#endif
            Just 125 -> Right (next + 1, stateAfterValue)
            _ | allowMissingObjectSeparator ->
              loop nextSeen (memberCount + 1) stateAfterValue next
            _ -> malformed
              ("expected ',' or '}' in " <> scope <> " at offset " <> Text.pack (show next))
    _ -> malformed
      ("expected object key or '}' in " <> scope <> " at offset " <> Text.pack (show offset))

scanJsonArray
  :: Text -> ByteString -> Int -> JsonScanState -> Int
  -> Either DiagnosticCompilerBuildInfoProblem (Int, JsonScanState)
scanJsonArray scope bytes depth state opening =
  loop 0 state
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_ARRAY_OPENING_WHITESPACE_DROP_MUTANT
    (opening + 1)
#else
    (skipWhitespace bytes (opening + 1))
#endif
 where
  loop index currentState offset = case byteAt bytes offset of
    Just 93 -> Right (offset + 1, currentState)
    _
      | index >= maximumJsonArrayElements ->
          Left (BuildInfoResourceLimitExceeded "json-array-elements"
            maximumJsonArrayElements (index + 1))
      | otherwise -> do
          (afterValue, nextState) <-
            scanJsonValue
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_ARRAY_VALUE_SCOPE_DROP_MUTANT
              scope
#else
              (scope <> "[" <> Text.pack (show index) <> "]")
#endif
              bytes (depth + 1) currentState offset
          let next =
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_ARRAY_AFTER_VALUE_WHITESPACE_DROP_MUTANT
                afterValue
#else
                skipWhitespace bytes afterValue
#endif
          case byteAt bytes next of
            Just 44 ->
              loop (index + 1) nextState
                (next + 1)
            Just 93 -> Right (next + 1, nextState)
            _ | allowMissingArraySeparator ->
              loop (index + 1) nextState next
            _ -> malformed
              ("expected ',' or ']' in " <> scope <> " at offset " <> Text.pack (show next))

scanJsonString
  :: Text -> ByteString -> Int
  -> Either DiagnosticCompilerBuildInfoProblem (Int, Text)
scanJsonString scope bytes opening = seek (opening + 1) False
 where
  seek offset escaped
    | offset - opening - 1 > maximumJsonStringBytes =
        Left (BuildInfoResourceLimitExceeded ("json-string-bytes:" <> scope)
          maximumJsonStringBytes (maximumJsonStringBytes + 1))
    | otherwise = case byteAt bytes offset of
        Nothing -> malformed
          ("unterminated JSON string at offset " <> Text.pack (show opening))
        Just byte
          | escaped ->
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_STRING_ESCAPED_STATE_EARLY_RETURN_MUTANT
              Right (offset + 1, "")
#else
              seek (offset + 1) False
#endif
          | byte == 92 -> seek (offset + 1)
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_STRING_BACKSLASH_STATE_DROP_MUTANT
              False
#else
              True
#endif
          | byte == 34 ->
              let encoded =
                    ByteString.take (offset - opening + 1)
                      (ByteString.drop opening bytes)
               in case (eitherDecodeStrict' encoded :: Either String Text) of
                    Left message
                      | allowInvalidJsonString -> Right (offset + 1, "")
                      | otherwise -> malformed
                          ("invalid JSON string at offset " <> Text.pack (show opening)
                            <> ": " <> Text.pack message)
                    Right decoded -> Right (offset + 1,
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_STRING_DECODED_PROJECTION_MUTANT
                      decoded <> "-mutant")
#else
                      decoded)
#endif
          | otherwise -> seek (offset + 1) False

scanJsonScalar
  :: Text -> ByteString -> Int -> Either DiagnosticCompilerBuildInfoProblem Int
scanJsonScalar scope bytes start = do
  end <- findScalarEnd scope bytes start
  let encoded = ByteString.take (end - start) (ByteString.drop start bytes)
  if
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_SCALAR_EMPTY_PREDICATE_MUTANT
    not (ByteString.null encoded)
#else
    ByteString.null encoded
#endif
    then malformed
      ("empty JSON scalar in " <> scope <> " at offset " <> Text.pack (show start))
    else case (eitherDecodeStrict' encoded :: Either String Value) of
      Left message
        | allowInvalidJsonScalar -> Right end
        | otherwise -> malformed
            ("invalid JSON scalar in " <> scope <> ": " <> Text.pack message)
      Right _ -> Right end

findScalarEnd
  :: Text -> ByteString -> Int -> Either DiagnosticCompilerBuildInfoProblem Int
findScalarEnd scope bytes start = go start
 where
  go offset
    | offset - start > maximumJsonScalarBytes =
        Left (BuildInfoResourceLimitExceeded ("json-scalar-bytes:" <> scope)
          maximumJsonScalarBytes (maximumJsonScalarBytes + 1))
    | otherwise = case byteAt bytes offset of
        Just byte | not (isJsonDelimiter byte) -> go (offset + 1)
        _ -> Right offset

consumeJsonToken
  :: JsonScanState -> Either DiagnosticCompilerBuildInfoProblem JsonScanState
consumeJsonToken (JsonScanState tokenCount)
  | tokenCount >= maximumJsonStructuralTokens =
      Left (BuildInfoResourceLimitExceeded "json-structural-tokens"
        maximumJsonStructuralTokens (tokenCount + 1))
  | otherwise =
      Right (JsonScanState
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_TOKEN_INCREMENT_DOUBLE_MUTANT
        (tokenCount + 2))
#else
        (tokenCount + 1))
#endif

escapedScopeToken :: Text -> Text
escapedScopeToken =
  Text.concatMap
    (\character ->
      if
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_SCOPE_ASCII_RETENTION_DROP_MUTANT
        isAsciiAlphaNumeric character `seq` elem character ['-', '_']
#else
        isAsciiAlphaNumeric character || elem character ['-', '_']
#endif
        then Text.singleton character
        else "\\u{" <> Text.pack (show
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_SCOPE_ORDINAL_INCREMENT_MUTANT
          (ord character + 1)
#else
          (ord character)
#endif
          ) <> "}")

malformed :: Text -> Either DiagnosticCompilerBuildInfoProblem value
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_MALFORMED_DETAIL_SUFFIX_MUTANT
malformed detail = Left (BuildInfoDuplicateKeyScanFailed (detail <> "-mutant"))
#else
malformed = Left . BuildInfoDuplicateKeyScanFailed
#endif

expectByte
  :: ByteString -> Word8 -> Int -> Text
  -> Either DiagnosticCompilerBuildInfoProblem Int
expectByte bytes expected offset label = case byteAt bytes offset of
  Just observed | observed == expected -> Right
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_EXPECT_BYTE_SUCCESS_INCREMENT_DOUBLE_MUTANT
    (offset + 2)
#else
    (offset + 1)
#endif
  _ | allowMissingObjectColon -> Right offset
  _ -> malformed ("expected " <> label <> " at offset " <> Text.pack (show offset))

allowTrailingJsonBytes, allowMissingObjectColon, allowMissingObjectSeparator,
  allowMissingArraySeparator, allowInvalidJsonString,
  allowInvalidJsonScalar :: Bool
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_TRAILING_BYTES_BYPASS_MUTANT
allowTrailingJsonBytes = True
#else
allowTrailingJsonBytes = False
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_COLON_BYPASS_MUTANT
allowMissingObjectColon = True
#else
allowMissingObjectColon = False
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_OBJECT_SEPARATOR_BYPASS_MUTANT
allowMissingObjectSeparator = True
#else
allowMissingObjectSeparator = False
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_ARRAY_SEPARATOR_BYPASS_MUTANT
allowMissingArraySeparator = True
#else
allowMissingArraySeparator = False
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_STRING_DECODE_BYPASS_MUTANT
allowInvalidJsonString = True
#else
allowInvalidJsonString = False
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_SCALAR_DECODE_BYPASS_MUTANT
allowInvalidJsonScalar = True
#else
allowInvalidJsonScalar = False
#endif

isJsonDelimiter :: Word8 -> Bool
isJsonDelimiter byte =
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_SCALAR_WHITESPACE_DELIMITER_DROP_MUTANT
  False
#else
  isJsonWhitespace byte
#endif
    ||
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_SCALAR_COMMA_DELIMITER_DROP_MUTANT
      False
#else
      byte == 44
#endif
    ||
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_SCALAR_ARRAY_END_DELIMITER_DROP_MUTANT
      False
#else
      byte == 93
#endif
    ||
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_SCALAR_OBJECT_END_DELIMITER_DROP_MUTANT
      False
#else
      byte == 125
#endif

skipWhitespace :: ByteString -> Int -> Int
skipWhitespace bytes = go
 where
  go offset = case byteAt bytes offset of
    Just byte | isJsonWhitespace byte -> go
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_WHITESPACE_ADVANCE_DOUBLE_MUTANT
      (offset + 2)
#else
      (offset + 1)
#endif
    _ -> offset

isJsonWhitespace :: Word8 -> Bool
isJsonWhitespace byte =
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_WHITESPACE_TAB_DROP_MUTANT
  byte /= 9 &&
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_WHITESPACE_LINE_FEED_DROP_MUTANT
  byte /= 10 &&
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_WHITESPACE_CARRIAGE_RETURN_DROP_MUTANT
  byte /= 13 &&
#endif
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_WHITESPACE_SPACE_DROP_MUTANT
  byte /= 32 &&
#endif
  elem byte [9, 10, 13, 32]

byteAt :: ByteString -> Int -> Maybe Word8
byteAt bytes offset
  | offset < 0 || offset >= ByteString.length bytes =
#ifdef VALIDATION_COMPILER_BUILDINFO_JSON_BYTE_AT_UPPER_BOUND_SENTINEL_MUTANT
      Just 0
#else
      Nothing
#endif
  | otherwise = Just (ByteString.index bytes offset)
