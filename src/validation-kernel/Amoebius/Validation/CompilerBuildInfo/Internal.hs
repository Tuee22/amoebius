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

data DiagnosticCompilerBuildInfoMachinePathObservation
  = DiagnosticCompilerBuildInfoCompilerPath FilePath
  | DiagnosticCompilerBuildInfoSourceDirectoryPath
      DiagnosticCompilerBuildInfoComponentIdentity FilePath
  | DiagnosticCompilerBuildInfoCabalFilePath
      DiagnosticCompilerBuildInfoComponentIdentity FilePath
  | DiagnosticCompilerBuildInfoSourceFilePath
      DiagnosticCompilerBuildInfoComponentIdentity FilePath
  | DiagnosticCompilerBuildInfoHaskellSourceDirectoryPath
      DiagnosticCompilerBuildInfoComponentIdentity FilePath
  | DiagnosticCompilerBuildInfoArgumentPath
      DiagnosticCompilerBuildInfoComponentIdentity
      DiagnosticCompilerBuildInfoPathObservation
  deriving (Eq, Ord, Show)

data DiagnosticCompilerBuildInfoSourceOwnershipObservation
  = DiagnosticCompilerBuildInfoModuleOwnership
      DiagnosticCompilerBuildInfoComponentIdentity Text
  | DiagnosticCompilerBuildInfoSourceFileOwnership
      DiagnosticCompilerBuildInfoComponentIdentity FilePath
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
  | BuildInfoIndependentExpectedCompilerUnavailable Text Text FilePath
  | BuildInfoMachinePathStateUnauthenticated
      [DiagnosticCompilerBuildInfoMachinePathObservation]
  | BuildInfoCompilerArgumentsUnauthenticated
      [(DiagnosticCompilerBuildInfoComponentIdentity,
        [DiagnosticCompilerBuildInfoArgumentObservation])]
  | BuildInfoDuplicateKeyDetectionDiagnosticOnly
  | BuildInfoIndependentExpectedUniverseUnavailable
      [DiagnosticCompilerBuildInfoComponentIdentity]
  | BuildInfoExactModuleSourceOwnershipUnresolved
      [DiagnosticCompilerBuildInfoSourceOwnershipObservation]
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
      [DiagnosticCompilerBuildInfoMachinePathObservation]
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
emptyProblemAccumulator = DiagnosticProblemAccumulator 0 False []

addProblemToAccumulator
  :: DiagnosticCompilerBuildInfoProblem
  -> DiagnosticProblemAccumulator
  -> DiagnosticProblemAccumulator
addProblemToAccumulator problem accumulator@(DiagnosticProblemAccumulator count overflow problems)
  | overflow = accumulator
  | count < maximumDiagnosticProblems =
      DiagnosticProblemAccumulator (count + 1) False (problem : problems)
  | otherwise = DiagnosticProblemAccumulator count True problems

addProblemsToAccumulator
  :: [DiagnosticCompilerBuildInfoProblem]
  -> DiagnosticProblemAccumulator
  -> DiagnosticProblemAccumulator
addProblemsToAccumulator [] accumulator = accumulator
addProblemsToAccumulator (problem : problems) accumulator =
  case addProblemToAccumulator problem accumulator of
    next@(DiagnosticProblemAccumulator _ True _) -> next
    next -> addProblemsToAccumulator problems next

finishProblemAccumulator
  :: DiagnosticProblemAccumulator
  -> [DiagnosticCompilerBuildInfoProblem]
finishProblemAccumulator (DiagnosticProblemAccumulator _ True _) =
  [BuildInfoResourceLimitExceeded "problem-count" maximumDiagnosticProblems
    (maximumDiagnosticProblems + 1)]
finishProblemAccumulator (DiagnosticProblemAccumulator _ False problems) = reverse problems

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
        (validateExpectedCompiler expectedCompiler
          <> validateExpectedIdentities expectedIdentities) of
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
diagnosticCheckName = "compiler-build-info-diagnostic"
diagnosticSubject =
  "Amoebius.Validation.CompilerBuildInfo.compilerBuildInfoDiagnostic"

diagnosticOnlyFinding :: Finding
diagnosticOnlyFinding =
  finding
    "COMPILER-BUILDINFO-DIAGNOSTIC-ONLY"
    (Text.unpack diagnosticSubject)
    "Cabal build-info and caller expectations are unauthenticated diagnostics and cannot establish compiler or source closure"

expectationRefusalCheckResult :: Text -> CheckResult
expectationRefusalCheckResult detail =
  CheckResult
    { checkName = diagnosticCheckName
    , checkObservations = []
    , checkFindings =
        diagnosticOnlyFindings
          <> [finding "COMPILER-BUILDINFO-EXPECTATION-REFUSED"
                (Text.unpack diagnosticSubject) detail]
    }

refusalCheckResult
  :: DiagnosticCompilerBuildInfoExpectations
  -> ByteString
  -> DiagnosticCompilerBuildInfoRefusal
  -> CheckResult
refusalCheckResult expectations bytes =
  foldDiagnosticCompilerBuildInfoRefusal hardResult observedResult
 where
  hardResult problems = result False problems []
  observedResult problems snapshot = result True problems (snapshotObservations snapshot)
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
      expectationObservations expectations
        <> retainedObservations retainInputBytesObservation
          [observation "input.bytes" (decimal (ByteString.length bytes))]
        <> observed
    proposedFindings =
      diagnosticOnlyFindings <> map problemFinding (NonEmpty.toList problems)

resultEnvelopeRefusal :: [Finding] -> DiagnosticCompilerBuildInfoProblem -> CheckResult
resultEnvelopeRefusal retainedFindings envelopeProblem =
  CheckResult
    { checkName = diagnosticCheckName
    , checkObservations =
        [ observation "result-envelope.status"
            "refused-before-result-materialization"
        , observation "result-envelope.exceeded" exceededDimension
        , observation "result-envelope.limit" (decimal limitValue)
        , observation "result-envelope.observed" (decimal observedValue)
        ]
    , checkFindings = retainedFindings <> [problemFinding envelopeProblem]
    }
 where
  (exceededDimension, limitValue, observedValue) = case envelopeProblem of
    BuildInfoResultEnvelopeExceeded dimension limit observed ->
      (dimension, limit, observed)
    _ -> ("internal-envelope-invariant", 0, 0)

resultEnvelopeProblem :: [Observation] -> [Finding] -> Maybe DiagnosticCompilerBuildInfoProblem
resultEnvelopeProblem observations findings =
  measureObservations 0 (textByteLength diagnosticCheckName) observations
 where
  measureObservations !entryCount !payloadBytes [] =
    measureFindings entryCount payloadBytes findings
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
              "entries" maximumResultEntries nextCount)
          else
            let nextBytes = payloadBytes + entryBytes
             in if nextBytes > maximumResultPayloadBytes
                  then Just
                    (BuildInfoResultEnvelopeExceeded
                      "payload-bytes" maximumResultPayloadBytes nextBytes)
                  else continue nextCount nextBytes

observationPayloadBytes :: Observation -> Int
observationPayloadBytes (Observation key value) =
  textByteLength key + textByteLength value

findingPayloadBytes :: Finding -> Int
findingPayloadBytes (Finding code subject detail) =
  textByteLength code + textByteLength (Text.pack subject) + textByteLength detail

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
  []
#else
  [diagnosticOnlyFinding]
#endif

problemFinding :: DiagnosticCompilerBuildInfoProblem -> Finding
problemFinding problem =
  finding (problemCode problem) (Text.unpack diagnosticSubject) (problemDetail problem)

problemCode :: DiagnosticCompilerBuildInfoProblem -> Text
problemCode problem = case problem of
  BuildInfoResourceLimitExceeded {} -> "COMPILER-BUILDINFO-RESOURCE-LIMIT"
  BuildInfoJsonDuplicateKey {} -> "COMPILER-BUILDINFO-JSON-DUPLICATE-KEY"
  BuildInfoDuplicateKeyScanFailed {} -> "COMPILER-BUILDINFO-JSON-SCAN-FAILED"
  BuildInfoRootNotObject -> "COMPILER-BUILDINFO-ROOT-NOT-OBJECT"
  BuildInfoFieldMissing {} -> "COMPILER-BUILDINFO-FIELD-MISSING"
  BuildInfoFieldUnknown {} -> "COMPILER-BUILDINFO-FIELD-UNKNOWN"
  BuildInfoFieldWrongType {} -> "COMPILER-BUILDINFO-FIELD-WRONG-TYPE"
  BuildInfoArrayElementWrongType {} -> "COMPILER-BUILDINFO-ARRAY-ELEMENT-WRONG-TYPE"
  BuildInfoTextEmpty {} -> "COMPILER-BUILDINFO-TEXT-EMPTY"
  BuildInfoArrayTextEmpty {} -> "COMPILER-BUILDINFO-ARRAY-TEXT-EMPTY"
  BuildInfoCabalLibraryVersionUnsupported {} -> "COMPILER-BUILDINFO-CABAL-VERSION"
  BuildInfoCompilerFlavourUnsupported {} -> "COMPILER-BUILDINFO-COMPILER-FLAVOUR"
  BuildInfoCompilerIdMalformed {} -> "COMPILER-BUILDINFO-COMPILER-ID"
  BuildInfoComponentsEmpty -> "COMPILER-BUILDINFO-COMPONENTS-EMPTY"
  BuildInfoComponentTypeUnsupported {} -> "COMPILER-BUILDINFO-COMPONENT-TYPE"
  BuildInfoComponentNameMalformed {} -> "COMPILER-BUILDINFO-COMPONENT-NAME"
  BuildInfoComponentSourceDiscoveryEmpty {} -> "COMPILER-BUILDINFO-SOURCE-DISCOVERY-EMPTY"
  BuildInfoHaskellSourceDirectoriesEmpty {} -> "COMPILER-BUILDINFO-HS-SOURCE-DIRS-EMPTY"
  BuildInfoUnitIdMalformed {} -> "COMPILER-BUILDINFO-UNIT-ID"
  BuildInfoModuleNameMalformed {} -> "COMPILER-BUILDINFO-MODULE-NAME"
  BuildInfoModuleNameDuplicate {} -> "COMPILER-BUILDINFO-MODULE-DUPLICATE"
  BuildInfoSourceFileDuplicate {} -> "COMPILER-BUILDINFO-SOURCE-FILE-DUPLICATE"
  BuildInfoHaskellSourceDirectoryDuplicate {} -> "COMPILER-BUILDINFO-HS-SOURCE-DIR-DUPLICATE"
  BuildInfoPathUnsafe {} -> "COMPILER-BUILDINFO-PATH-UNSAFE"
  BuildInfoPathEscapesSourceDirectory {} -> "COMPILER-BUILDINFO-PATH-ESCAPES-SOURCE"
  BuildInfoSourceDirectoryNotAbsolute {} -> "COMPILER-BUILDINFO-SOURCE-DIR-NOT-ABSOLUTE"
  BuildInfoSourceDirectoryMissingTrailingSeparator {} -> "COMPILER-BUILDINFO-SOURCE-DIR-SEPARATOR"
  BuildInfoCabalFileExtensionInvalid {} -> "COMPILER-BUILDINFO-CABAL-EXTENSION"
  BuildInfoSourceFileExtensionUnsupported {} -> "COMPILER-BUILDINFO-SOURCE-EXTENSION"
  BuildInfoCompilerArgumentHazardous {} -> "COMPILER-BUILDINFO-ARGUMENT-HAZARDOUS"
  BuildInfoCompilerArgumentUnclassified {} -> "COMPILER-BUILDINFO-ARGUMENT-UNCLASSIFIED"
  BuildInfoCompilerArgumentValueMissing {} -> "COMPILER-BUILDINFO-ARGUMENT-VALUE-MISSING"
  BuildInfoCompilerArgumentValueMalformed {} -> "COMPILER-BUILDINFO-ARGUMENT-VALUE-MALFORMED"
  BuildInfoCompilerArgumentPathUnsafe {} -> "COMPILER-BUILDINFO-ARGUMENT-PATH-UNSAFE"
  BuildInfoCompilerGeneratedInputArgumentMalformed {} -> "COMPILER-BUILDINFO-GENERATED-INPUT-ARGUMENT"
  BuildInfoCompilerPackageBoundaryMissing {} -> "COMPILER-BUILDINFO-PACKAGE-BOUNDARY-MISSING"
  BuildInfoCompilerPackageBoundaryDuplicate {} -> "COMPILER-BUILDINFO-PACKAGE-BOUNDARY-DUPLICATE"
  BuildInfoCompilerThisUnitIdMissing {} -> "COMPILER-BUILDINFO-THIS-UNIT-MISSING"
  BuildInfoCompilerThisUnitIdDuplicate {} -> "COMPILER-BUILDINFO-THIS-UNIT-DUPLICATE"
  BuildInfoCompilerThisUnitIdMismatch {} -> "COMPILER-BUILDINFO-THIS-UNIT-MISMATCH"
  BuildInfoObservedUnitIdDuplicate {} -> "COMPILER-BUILDINFO-OBSERVED-UNIT-DUPLICATE"
  BuildInfoObservedComponentIdentityDuplicate {} -> "COMPILER-BUILDINFO-OBSERVED-COMPONENT-DUPLICATE"
  BuildInfoExpectedCompilerFlavourUnsupported {} -> "COMPILER-BUILDINFO-EXPECTED-COMPILER-FLAVOUR"
  BuildInfoExpectedCompilerIdMalformed {} -> "COMPILER-BUILDINFO-EXPECTED-COMPILER-ID"
  BuildInfoExpectedCompilerPathUnsafe {} -> "COMPILER-BUILDINFO-EXPECTED-COMPILER-PATH"
  BuildInfoExpectedCompilerIdMismatch {} -> "COMPILER-BUILDINFO-COMPILER-ID-MISMATCH"
  BuildInfoExpectedCompilerPathMismatch {} -> "COMPILER-BUILDINFO-COMPILER-PATH-MISMATCH"
  BuildInfoExpectedIdentityTypeUnsupported {} -> "COMPILER-BUILDINFO-EXPECTED-IDENTITY-TYPE"
  BuildInfoExpectedIdentityTextMalformed {} -> "COMPILER-BUILDINFO-EXPECTED-IDENTITY-TEXT"
  BuildInfoExpectedIdentityUniverseEmpty -> "COMPILER-BUILDINFO-EXPECTED-UNIVERSE-EMPTY"
  BuildInfoExpectedUnitIdDuplicate {} -> "COMPILER-BUILDINFO-EXPECTED-UNIT-DUPLICATE"
  BuildInfoExpectedComponentIdentityDuplicate {} -> "COMPILER-BUILDINFO-EXPECTED-COMPONENT-DUPLICATE"
  BuildInfoExpectedIdentityMissing {} -> "COMPILER-BUILDINFO-EXPECTED-IDENTITY-MISSING"
  BuildInfoUnexpectedIdentity {} -> "COMPILER-BUILDINFO-UNEXPECTED-IDENTITY"
  BuildInfoExpectedUnitIdentityMismatch {} -> "COMPILER-BUILDINFO-EXPECTED-UNIT-MISMATCH"
  BuildInfoExpectedComponentIdentityMismatch {} -> "COMPILER-BUILDINFO-EXPECTED-COMPONENT-MISMATCH"
  BuildInfoGeneratorBytesUnauthenticated {} -> "COMPILER-BUILDINFO-GENERATOR-BYTES-UNAUTHENTICATED"
  BuildInfoCompilerIdentityUnauthenticated {} -> "COMPILER-BUILDINFO-COMPILER-UNAUTHENTICATED"
  BuildInfoIndependentExpectedCompilerUnavailable {} -> "COMPILER-BUILDINFO-INDEPENDENT-COMPILER-UNAVAILABLE"
  BuildInfoMachinePathStateUnauthenticated {} -> "COMPILER-BUILDINFO-MACHINE-PATHS-UNAUTHENTICATED"
  BuildInfoCompilerArgumentsUnauthenticated {} -> "COMPILER-BUILDINFO-ARGUMENTS-UNAUTHENTICATED"
  BuildInfoDuplicateKeyDetectionDiagnosticOnly -> "COMPILER-BUILDINFO-DUPLICATE-DETECTION-DIAGNOSTIC"
  BuildInfoIndependentExpectedUniverseUnavailable {} -> "COMPILER-BUILDINFO-INDEPENDENT-UNIVERSE-UNAVAILABLE"
  BuildInfoExactModuleSourceOwnershipUnresolved {} -> "COMPILER-BUILDINFO-SOURCE-OWNERSHIP-UNRESOLVED"
  BuildInfoCabalFileSourceJoinUnavailable {} -> "COMPILER-BUILDINFO-CABAL-SOURCE-JOIN-UNAVAILABLE"
  BuildInfoGeneratedCompilerInputsUnauthenticated {} -> "COMPILER-BUILDINFO-GENERATED-INPUTS-UNAUTHENTICATED"
  BuildInfoPackageDependencyJoinUnavailable {} -> "COMPILER-BUILDINFO-PACKAGE-JOIN-UNAVAILABLE"
  BuildInfoConfigurationJoinUnavailable {} -> "COMPILER-BUILDINFO-CONFIGURATION-JOIN-UNAVAILABLE"
  BuildInfoSourcePragmaSemanticsUnavailable {} -> "COMPILER-BUILDINFO-PRAGMA-SEMANTICS-UNAVAILABLE"
  BuildInfoPhysicalPathContainmentUnavailable {} -> "COMPILER-BUILDINFO-PHYSICAL-PATHS-UNAVAILABLE"
  BuildInfoPathPlatformSemanticsUnavailable {} -> "COMPILER-BUILDINFO-PATH-PLATFORM-UNAVAILABLE"
  BuildInfoElaboratedPlanJoinUnavailable {} -> "COMPILER-BUILDINFO-PLAN-JOIN-UNAVAILABLE"
  BuildInfoCompilerInvocationUnavailable {} -> "COMPILER-BUILDINFO-COMPILER-INVOCATION-UNAVAILABLE"
  BuildInfoOracleQualificationUnavailable -> "COMPILER-BUILDINFO-ORACLE-QUALIFICATION-UNAVAILABLE"
  BuildInfoResultEnvelopeExceeded {} -> "COMPILER-BUILDINFO-RESULT-ENVELOPE"

problemDetail :: DiagnosticCompilerBuildInfoProblem -> Text
problemDetail problem = case problem of
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
      [observation "expected.compiler.flavour" flavour]
      <> retainedObservations retainExpectedCompilerIdObservation
        [observation "expected.compiler.id" compilerId]
      <> retainedObservations retainExpectedCompilerPathObservation
        [observation "expected.compiler.path" (Text.pack compilerPath)]
      <> retainedObservations retainExpectedComponentCountObservation
        [observation "expected.component.count" (decimal (length identities))]
      <> concat
        [ expectedIdentityObservations
            ("expected.component." <> decimal index)
            (expectedIdentityComponent identity)
        | (index, identity) <- zip [0 :: Int ..] identities
        ]

snapshotObservations :: DiagnosticCompilerBuildInfoSnapshot -> [Observation]
snapshotObservations
  (DiagnosticCompilerBuildInfoSnapshot _ version flavour compilerId compilerPath components) =
    retainedObservations retainObservedCabalVersionObservation
      [observation "observed.cabal-library-version" version]
      <> retainedObservations retainObservedCompilerFlavourObservation
        [observation "observed.compiler.flavour" flavour]
      <> retainedObservations retainObservedCompilerIdObservation
        [observation "observed.compiler.id" compilerId]
      <> retainedObservations retainObservedCompilerPathObservation
        [observation "observed.compiler.path" (Text.pack compilerPath)]
      <> retainedObservations retainObservedComponentCountObservation
        [observation "observed.component.count" (decimal (length components))]
      <> concat
        [ componentObservations ("observed.component." <> decimal index) component
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
    retainedObservations retainType [observation (prefix <> ".type") componentType]
      <> retainedObservations retainName [observation (prefix <> ".name") componentName]
      <> retainedObservations retainUnit [observation (prefix <> ".unit-id") unitId]

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
  observedIdentityObservations (prefix <> ".identity")
      (componentObservationIdentity component)
    <> retainedObservations retainCompilerArgumentObservations
      (indexedArgumentObservations prefix (componentObservationCompilerArguments component))
    <> retainedObservations retainModuleObservations
      (indexedTextObservations (prefix <> ".module") (componentObservationModules component))
    <> retainedObservations retainSourceFileObservations
      (indexedFilePathObservations
        (prefix <> ".source-file") (componentObservationSourceFiles component))
    <> retainedObservations retainHaskellSourceDirectoryObservations
      (indexedFilePathObservations
        (prefix <> ".haskell-source-directory")
        (componentObservationSourceDirectories component))
    <> retainedObservations retainSourceDirectoryObservation
      [observation (prefix <> ".source-directory")
        (Text.pack (componentObservationSourceDirectory component))]
    <> retainedObservations retainCabalFileObservations
      (cabalFileObservations prefix (componentObservationCabalFile component))
    <> retainedObservations retainArgumentPathObservations
      (indexedPathObservations prefix (componentObservationArgumentPaths component))
    <> retainedObservations retainGeneratedInputObservations
      (indexedGeneratedInputObservations prefix
        (componentObservationGeneratedInputs component))
    <> retainedObservations retainPackageObservations
      (indexedPackageObservations prefix (componentObservationPackageIds component))

retainedObservations :: Bool -> [value] -> [value]
retainedObservations True values = values
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
  observation (prefix <> ".count") (decimal (length values))
    : [observation (prefix <> "." <> decimal index) value
      | (index, value) <- zip [0 :: Int ..] values]

indexedFilePathObservations :: Text -> [FilePath] -> [Observation]
indexedFilePathObservations prefix = indexedTextObservations prefix . map Text.pack

cabalFileObservations :: Text -> Maybe FilePath -> [Observation]
cabalFileObservations prefix Nothing =
  [observation (prefix <> ".cabal-file.present") "false"]
cabalFileObservations prefix (Just path) =
  [ observation (prefix <> ".cabal-file.present") "true"
  , observation (prefix <> ".cabal-file.path") (Text.pack path)
  ]

indexedArgumentObservations
  :: Text
  -> [DiagnosticCompilerBuildInfoArgumentObservation]
  -> [Observation]
indexedArgumentObservations componentPrefix values =
  observation (componentPrefix <> ".compiler-argument.count") (decimal (length values))
    : concat
      [argumentObservations
        (componentPrefix <> ".compiler-argument." <> decimal ordinal) value
      | (ordinal, value) <- zip [0 :: Int ..] values]

argumentObservations :: Text -> DiagnosticCompilerBuildInfoArgumentObservation -> [Observation]
argumentObservations prefix argument = case argument of
  DiagnosticCompilerBuildInfoBoundaryArgument optionIndex option ->
    optionOnly "package-boundary" optionIndex option
  DiagnosticCompilerBuildInfoThisUnitArgument optionIndex option valueIndex value ->
    optionValue "this-unit" optionIndex option valueIndex value
  DiagnosticCompilerBuildInfoPackageArgument optionIndex option valueIndex value ->
    optionValue "package" optionIndex option valueIndex value
  DiagnosticCompilerBuildInfoPathArgument optionIndex option valueIndex raw path ->
    optionOnly "path" optionIndex option
      <> maybe [] (\index -> [observation (prefix <> ".value-index") (decimal index)]) valueIndex
      <> [ observation (prefix <> ".raw") raw
         , observation (prefix <> ".path") (Text.pack path)
         ]
  DiagnosticCompilerBuildInfoGeneratedInputArgument optionIndex option valueIndex raw path ->
    optionValue "generated-input" optionIndex option valueIndex raw
      <> [observation (prefix <> ".path") (Text.pack path)]
  DiagnosticCompilerBuildInfoStandaloneArgument optionIndex option ->
    optionOnly "standalone" optionIndex option
  DiagnosticCompilerBuildInfoBypassedArgument optionIndex option ->
    optionOnly "bypassed" optionIndex option
 where
  optionOnly kind optionIndex option =
    [ observation (prefix <> ".kind") kind
    , observation (prefix <> ".option-index") (decimal optionIndex)
    , observation (prefix <> ".option") option
    ]
  optionValue kind optionIndex option valueIndex value =
    optionOnly kind optionIndex option
      <> [ observation (prefix <> ".value-index") (decimal valueIndex)
         , observation (prefix <> ".value") value
         ]

indexedPathObservations
  :: Text
  -> [DiagnosticCompilerBuildInfoPathObservation]
  -> [Observation]
indexedPathObservations componentPrefix values =
  observation (componentPrefix <> ".argument-path.count") (decimal (length values))
    : concat
      [ case value of
          DiagnosticCompilerBuildInfoPathObservation optionIndex option valueIndex path ->
            [ observation (prefix <> ".option-index") (decimal optionIndex)
            , observation (prefix <> ".option") option
            ]
              <> maybe [] (\index ->
                [observation (prefix <> ".value-index") (decimal index)]) valueIndex
              <> [observation (prefix <> ".path") (Text.pack path)]
      | (ordinal, value) <- zip [0 :: Int ..] values
      , let prefix = componentPrefix <> ".argument-path." <> decimal ordinal
      ]

indexedGeneratedInputObservations
  :: Text
  -> [DiagnosticCompilerBuildInfoGeneratedInputObservation]
  -> [Observation]
indexedGeneratedInputObservations componentPrefix values =
  observation (componentPrefix <> ".generated-input.count") (decimal (length values))
    : concat
      [ case value of
          DiagnosticCompilerBuildInfoGeneratedInputObservation
            optionIndex option valueIndex raw path ->
              [ observation (prefix <> ".option-index") (decimal optionIndex)
              , observation (prefix <> ".option") option
              , observation (prefix <> ".value-index") (decimal valueIndex)
              , observation (prefix <> ".raw") raw
              , observation (prefix <> ".path") (Text.pack path)
              ]
      | (ordinal, value) <- zip [0 :: Int ..] values
      , let prefix = componentPrefix <> ".generated-input." <> decimal ordinal
      ]

indexedPackageObservations
  :: Text
  -> [DiagnosticCompilerBuildInfoPackageObservation]
  -> [Observation]
indexedPackageObservations componentPrefix values =
  observation (componentPrefix <> ".package.count") (decimal (length values))
    : concat
      [ case value of
          DiagnosticCompilerBuildInfoPackageObservation optionIndex option valueIndex valueText ->
            [ observation (prefix <> ".option-index") (decimal optionIndex)
            , observation (prefix <> ".option") option
            , observation (prefix <> ".value-index") (decimal valueIndex)
            , observation (prefix <> ".value") valueText
            ]
      | (ordinal, value) <- zip [0 :: Int ..] values
      , let prefix = componentPrefix <> ".package." <> decimal ordinal
      ]

decimal :: Int -> Text
decimal = Text.pack . show

parseCompilerBuildInfoDiagnostic
  :: DiagnosticCompilerBuildInfoExpectedCompiler
  -> [DiagnosticCompilerBuildInfoExpectedIdentity]
  -> ByteString
  -> DiagnosticCompilerBuildInfoRefusal
parseCompilerBuildInfoDiagnostic expectedCompiler expectedIdentities bytes
  | ByteString.length bytes > maximumBuildInfoBytes =
      singleProblemRefusal
        (BuildInfoResourceLimitExceeded "input-bytes" maximumBuildInfoBytes (ByteString.length bytes))
  | expectedCount > maximumExpectedIdentities =
      singleProblemRefusal
        (BuildInfoResourceLimitExceeded "expected-identities" maximumExpectedIdentities expectedCount)
  | not (null expectationProblems) = hardRefusal expectationProblems
  | otherwise =
      case scanDuplicateJsonKeys bytes of
        Left problem -> singleProblemRefusal problem
        Right duplicateProblems
          | not (null duplicateProblems) -> hardRefusal duplicateProblems
          | otherwise ->
              case eitherDecodeStrict' bytes of
                Left message ->
                  singleProblemRefusal
                    (BuildInfoDuplicateKeyScanFailed
                      ("bounded JSON scanner and Aeson decoder disagreed: "
                        <> Text.pack message))
                Right (Object root) -> parseBuildInfoRoot expectedCompiler expectedIdentities root
                Right _
                  | enforceRootObject -> singleProblemRefusal BuildInfoRootNotObject
                  | otherwise -> hardRefusal []
 where
  expectedCount = boundedLength (maximumExpectedIdentities + 1) expectedIdentities
  expectationProblems =
    validateExpectedCompiler expectedCompiler <> validateExpectedIdentities expectedIdentities

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
          parseBuildInfoBody expectedCompiler expectedIdentities observedVersion
            encodedCompiler encodedComponents
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
      | not (null syntaxAndSemanticProblems) -> hardRefusal syntaxAndSemanticProblems
      | not (null identityProblems) -> hardRefusal identityProblems
      | otherwise ->
          observedRefusal
            (permanentProblems expectedCompiler expectedIdentities cabalVersion
              compilerIdentity parsedComponentValues)
            (makeSnapshot expectedCompiler expectedIdentities cabalVersion
              compilerIdentity parsedComponentValues)
    _ -> hardRefusal syntaxAndSemanticProblems
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
      components
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
permanentProblems expectedCompiler expectedIdentities cabalVersion
  (CompilerIdentity flavour compilerId compilerPath) components =
    concat
      [ retainedProblem retainGeneratorBytesResidue
          (BuildInfoGeneratorBytesUnauthenticated cabalVersion)
      , retainedProblem retainCompilerIdentityResidue
          (BuildInfoCompilerIdentityUnauthenticated flavour compilerId compilerPath)
      , retainedProblem retainIndependentCompilerResidue
          (uncurryExpectedCompiler BuildInfoIndependentExpectedCompilerUnavailable expectedCompiler)
      , retainedProblem retainMachinePathStateResidue
          (BuildInfoMachinePathStateUnauthenticated machinePaths)
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
          (BuildInfoExactModuleSourceOwnershipUnresolved
            (sort (concatMap unresolvedOwnershipObservations components)))
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
          (BuildInfoPhysicalPathContainmentUnavailable machinePaths)
      , retainedProblem retainPlatformResidue
          (BuildInfoPathPlatformSemanticsUnavailable "posix-lexical-only")
      , retainedProblem retainElaboratedPlanJoinResidue
          (BuildInfoElaboratedPlanJoinUnavailable
            (sort (map componentObservationIdentity components)))
      , retainedProblem retainCompilerInvocationResidue
          (BuildInfoCompilerInvocationUnavailable flavour compilerId compilerPath)
      , retainedProblem retainOracleResidue BuildInfoOracleQualificationUnavailable
      ]
 where
  machinePaths = Set.toAscList (explicitMachinePaths compilerPath components)

retainedProblem :: Bool -> problem -> [problem]
retainedProblem True problem = [problem]
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
      (addProblemsToAccumulator (boundaryProblems <> thisUnitProblems) accumulatedProblems))
    (reverse parsedArguments)
    (reverse parsedPaths)
    (reverse generatedInputs)
    (reverse packageIds)
 where
  (!accumulatedProblems, !parsedArguments, !parsedPaths, !generatedInputs, !packageIds,
   !hideCount, !noUserCount, !thisUnits) =
    go (0 :: Int) arguments emptyProblemAccumulator [] [] [] []
      (0 :: Int) (0 :: Int) []

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
    0 -> [BuildInfoCompilerPackageBoundaryMissing unitId boundary]
    1 -> []
    _ -> [BuildInfoCompilerPackageBoundaryDuplicate unitId boundary]
  thisUnitProblems = case reverse thisUnits of
    [] ->
      [BuildInfoCompilerThisUnitIdMissing unitId | enforceThisUnitMissing]
    [observed]
      | observed == unitId -> []
      | otherwise ->
          [BuildInfoCompilerThisUnitIdMismatch unitId observed
          | enforceThisUnitMismatch]
    observed ->
      [BuildInfoCompilerThisUnitIdDuplicate unitId observed
      | enforceThisUnitDuplicate]

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
        Just (Text.dropEnd 1 prefix, value)
    | otherwise = firstAttached prefixes

retainedAlternative :: Bool -> value -> [value]
retainedAlternative True value = [value]
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
      Just "response files can hide unenumerated compiler arguments"
  | enforceCompilerPluginHazard && Text.isPrefixOf "-fplugin" argument =
      Just "compiler plugin execution is not admitted"
  | enforcePluginPackageHazard && Text.isPrefixOf "-plugin-package" argument =
      Just "compiler plugin packages are not admitted"
  | enforceTemplateHaskellHazard
      && elem argument ["-XTemplateHaskell", "-XTemplateHaskellQuotes", "-XQuasiQuotes"] =
      Just "compile-time Haskell execution is not admitted"
  | enforceInterpreterHazard
      && elem argument ["-fexternal-interpreter", "-fprefer-byte-code", "-fbyte-code-and-object-code"] =
      Just "compile-time interpreter execution is not admitted"
  | enforcePreprocessorHazard && elem argument ["-F", "-cpp", "-XCPP"] =
      Just "unbound preprocessing is not admitted"
  | enforceCustomPreprocessorHazard
      && any (\prefix -> Text.isPrefixOf prefix argument) ["-pgmF", "-optF", "-pgmP", "-pgmL"] =
      Just "custom preprocessing tools are not admitted"
  | enforceForeignCallHazard && elem argument
      ["-XForeignFunctionInterface", "-XCApiFFI", "-XGHCForeignImportPrim",
       "-XInterruptibleFFI", "-XUnliftedFFITypes", "-XJavaScriptFFI"] =
      Just "foreign-call compilation is not admitted"
  | enforceLinkerHazard && any (\prefix -> Text.isPrefixOf prefix argument)
      ["-optl", "-pgml", "-framework", "-L", "-l"] =
      Just "linker or foreign-library arguments are not admitted"
  | enforceForeignToolHazard && any (\prefix -> Text.isPrefixOf prefix argument)
      ["-pgmc", "-pgma", "-optc", "-opta", "-optlo"] =
      Just "custom foreign compiler tools are not admitted"
  | enforcePackageEnvironmentHazard
      && elem argument ["-package", "-package-env", "-user-package-db"] =
      Just "unbounded package or user environment selection is not admitted"
  | enforceAttachedPackageEnvironmentHazard
      && any (\prefix -> Text.isPrefixOf prefix argument)
      ["-package=", "-package-env=", "-user-package-db="] =
      Just "unbounded package or user environment selection is not admitted"
  | enforceInteractiveHazard && elem argument ["-e", "-interactive", "-ghci-script"] =
      Just "interactive compiler execution is not admitted"
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
  isAsciiDigit character || isAsciiUpper character || isAsciiLower character
isAsciiDigit character = character >= '0' && character <= '9'
isAsciiUpper character = character >= 'A' && character <= 'Z'
isAsciiLower character = character >= 'a' && character <= 'z'

expectedComponentIdentity :: DiagnosticCompilerBuildInfoExpectedIdentity -> (Text, Text)
expectedComponentIdentity
  (DiagnosticCompilerBuildInfoExpectedIdentity componentType componentName _) =
    (componentType, componentName)

expectedUnitIdentity :: DiagnosticCompilerBuildInfoExpectedIdentity -> Text
expectedUnitIdentity (DiagnosticCompilerBuildInfoExpectedIdentity _ _ unitId) = unitId

expectedIdentityComponent
  :: DiagnosticCompilerBuildInfoExpectedIdentity
  -> DiagnosticCompilerBuildInfoComponentIdentity
expectedIdentityComponent
  (DiagnosticCompilerBuildInfoExpectedIdentity componentType componentName unitId) =
    DiagnosticCompilerBuildInfoComponentIdentity componentType componentName unitId

uncurryExpected
  :: (Text -> Text -> Text -> problem)
  -> DiagnosticCompilerBuildInfoExpectedIdentity
  -> problem
uncurryExpected constructor
  (DiagnosticCompilerBuildInfoExpectedIdentity componentType componentName unitId) =
    constructor componentType componentName unitId

uncurryExpectedCompiler
  :: (Text -> Text -> FilePath -> problem)
  -> DiagnosticCompilerBuildInfoExpectedCompiler
  -> problem
uncurryExpectedCompiler constructor
  (DiagnosticCompilerBuildInfoExpectedCompiler flavour compilerId compilerPath) =
    constructor flavour compilerId compilerPath

componentObservationType :: DiagnosticCompilerBuildInfoComponentObservation -> Text
componentObservationType component =
  case componentObservationIdentity component of
    DiagnosticCompilerBuildInfoComponentIdentity value _ _ -> value
componentObservationName :: DiagnosticCompilerBuildInfoComponentObservation -> Text
componentObservationName component =
  case componentObservationIdentity component of
    DiagnosticCompilerBuildInfoComponentIdentity _ value _ -> value
componentObservationUnitId :: DiagnosticCompilerBuildInfoComponentObservation -> Text
componentObservationUnitId component =
  case componentObservationIdentity component of
    DiagnosticCompilerBuildInfoComponentIdentity _ _ value -> value
componentObservationCompilerArguments
  :: DiagnosticCompilerBuildInfoComponentObservation
  -> [DiagnosticCompilerBuildInfoArgumentObservation]
componentObservationCompilerArguments
  (DiagnosticCompilerBuildInfoComponentObservation _ value _ _ _ _ _ _ _ _) = value
componentObservationModules :: DiagnosticCompilerBuildInfoComponentObservation -> [Text]
componentObservationModules
  (DiagnosticCompilerBuildInfoComponentObservation _ _ value _ _ _ _ _ _ _) = value
componentObservationSourceFiles
  :: DiagnosticCompilerBuildInfoComponentObservation -> [FilePath]
componentObservationSourceFiles
  (DiagnosticCompilerBuildInfoComponentObservation _ _ _ value _ _ _ _ _ _) = value
componentObservationSourceDirectories
  :: DiagnosticCompilerBuildInfoComponentObservation -> [FilePath]
componentObservationSourceDirectories
  (DiagnosticCompilerBuildInfoComponentObservation _ _ _ _ value _ _ _ _ _) = value
componentObservationSourceDirectory
  :: DiagnosticCompilerBuildInfoComponentObservation -> FilePath
componentObservationSourceDirectory
  (DiagnosticCompilerBuildInfoComponentObservation _ _ _ _ _ value _ _ _ _) = value
componentObservationCabalFile
  :: DiagnosticCompilerBuildInfoComponentObservation -> Maybe FilePath
componentObservationCabalFile
  (DiagnosticCompilerBuildInfoComponentObservation _ _ _ _ _ _ value _ _ _) = value
componentObservationArgumentPaths
  :: DiagnosticCompilerBuildInfoComponentObservation
  -> [DiagnosticCompilerBuildInfoPathObservation]
componentObservationArgumentPaths
  (DiagnosticCompilerBuildInfoComponentObservation _ _ _ _ _ _ _ value _ _) = value
componentObservationGeneratedInputs
  :: DiagnosticCompilerBuildInfoComponentObservation
  -> [DiagnosticCompilerBuildInfoGeneratedInputObservation]
componentObservationGeneratedInputs
  (DiagnosticCompilerBuildInfoComponentObservation _ _ _ _ _ _ _ _ value _) = value
componentObservationPackageIds
  :: DiagnosticCompilerBuildInfoComponentObservation
  -> [DiagnosticCompilerBuildInfoPackageObservation]
componentObservationPackageIds
  (DiagnosticCompilerBuildInfoComponentObservation _ _ _ _ _ _ _ _ _ value) = value

componentObservationIdentity
  :: DiagnosticCompilerBuildInfoComponentObservation
  -> DiagnosticCompilerBuildInfoComponentIdentity
componentObservationIdentity
  (DiagnosticCompilerBuildInfoComponentObservation value _ _ _ _ _ _ _ _ _) = value

componentObservationComponentKey
  :: DiagnosticCompilerBuildInfoComponentObservation -> (Text, Text)
componentObservationComponentKey component =
  (componentObservationType component, componentObservationName component)

explicitMachinePaths
  :: FilePath
  -> [DiagnosticCompilerBuildInfoComponentObservation]
  -> Set DiagnosticCompilerBuildInfoMachinePathObservation
explicitMachinePaths compilerPath components =
  Set.fromList
    (DiagnosticCompilerBuildInfoCompilerPath compilerPath
      : concatMap componentPaths components)
 where
  componentPaths component =
    [DiagnosticCompilerBuildInfoSourceDirectoryPath identity
      (componentObservationSourceDirectory component)]
      <> [DiagnosticCompilerBuildInfoCabalFilePath identity path
         | path <- maybeToList (componentObservationCabalFile component)]
      <> [DiagnosticCompilerBuildInfoSourceFilePath identity path
         | path <- componentObservationSourceFiles component]
      <> [DiagnosticCompilerBuildInfoHaskellSourceDirectoryPath identity path
         | path <- componentObservationSourceDirectories component]
      <> [DiagnosticCompilerBuildInfoArgumentPath identity path
         | path <- componentObservationArgumentPaths component]
   where
    identity = componentObservationIdentity component

unresolvedOwnershipObservations
  :: DiagnosticCompilerBuildInfoComponentObservation
  -> [DiagnosticCompilerBuildInfoSourceOwnershipObservation]
unresolvedOwnershipObservations component =
  [DiagnosticCompilerBuildInfoModuleOwnership identity moduleName
  | moduleName <- componentObservationModules component]
    <> [DiagnosticCompilerBuildInfoSourceFileOwnership identity sourceFile
       | sourceFile <- componentObservationSourceFiles component]
 where
  identity = componentObservationIdentity component

parsedProblems :: Parsed value -> [DiagnosticCompilerBuildInfoProblem]
parsedProblems (Parsed problems _) = problems
parsedValue :: Parsed value -> Maybe value
parsedValue (Parsed _ value) = value

partitionParsed :: [Parsed value] -> ([DiagnosticCompilerBuildInfoProblem], Maybe [value])
partitionParsed = go emptyProblemAccumulator True []
 where
  go accumulator complete values [] =
    (finishProblemAccumulator accumulator,
      if complete then Just (reverse values) else Nothing)
  go accumulator complete values (Parsed problems value : remaining) =
    let nextAccumulator = addProblemsToAccumulator problems accumulator
        nextComplete = complete && maybe False (const True) value
        nextValues = maybe values (: values) value
     in case nextAccumulator of
          DiagnosticProblemAccumulator _ True _ ->
            (finishProblemAccumulator nextAccumulator, Nothing)
          _ -> go nextAccumulator nextComplete nextValues remaining

requiredText :: Text -> Object -> Text -> Parsed Text
requiredText scope object field = case KeyMap.lookup (Key.fromText field) object of
  Nothing -> Parsed [BuildInfoFieldMissing scope field | enforceRequiredTextPresence] Nothing
  Just (String value)
    | Text.null value ->
        Parsed [BuildInfoTextEmpty scope field | enforceRequiredTextNonEmpty] Nothing
    | otherwise -> Parsed [] (Just value)
  Just _ ->
    Parsed [BuildInfoFieldWrongType scope field "text" | enforceRequiredTextType] Nothing

requiredFilePath :: Text -> Object -> Text -> Parsed FilePath
requiredFilePath scope object field = fmapParsed Text.unpack (requiredText scope object field)

optionalFilePath :: Text -> Object -> Text -> Parsed (Maybe FilePath)
optionalFilePath scope object field = case KeyMap.lookup (Key.fromText field) object of
  Nothing -> Parsed [] (Just Nothing)
  Just (String value)
    | Text.null value ->
        Parsed [BuildInfoTextEmpty scope field | enforceOptionalTextNonEmpty] Nothing
    | otherwise -> Parsed [] (Just (Just (Text.unpack value)))
  Just _ ->
    Parsed [BuildInfoFieldWrongType scope field "text" | enforceOptionalTextType] Nothing

requiredObject :: Text -> Object -> Text -> Parsed Object
requiredObject scope object field = case KeyMap.lookup (Key.fromText field) object of
  Nothing ->
    Parsed [BuildInfoFieldMissing scope field | enforceRequiredObjectPresence] Nothing
  Just (Object value) -> Parsed [] (Just value)
  Just _ ->
    Parsed [BuildInfoFieldWrongType scope field "object" | enforceRequiredObjectType] Nothing

requiredArray :: Text -> Object -> Text -> Parsed [Value]
requiredArray scope object field = case KeyMap.lookup (Key.fromText field) object of
  Nothing ->
    Parsed [BuildInfoFieldMissing scope field | enforceRequiredArrayPresence] Nothing
  Just (Array values) -> Parsed [] (Just (foldr (:) [] values))
  Just _ ->
    Parsed [BuildInfoFieldWrongType scope field "array" | enforceRequiredArrayType] Nothing

requiredTextArray :: Int -> Text -> Object -> Text -> Parsed [Text]
requiredTextArray maximumEntries scope object field =
  case rawArray of
    Parsed problems Nothing -> Parsed problems Nothing
    Parsed problems (Just values)
      | entryCount > maximumEntries ->
          Parsed [BuildInfoResourceLimitExceeded (scope <> "." <> field)
            maximumEntries entryCount] Nothing
      | otherwise ->
          let entries = zipWith parseTextArrayEntry [0 ..] values
              (entryProblems, parsedEntries) = partitionParsed entries
           in Parsed (problems <> entryProblems) parsedEntries
 where
  rawArray = requiredArray scope object field
  entryCount =
    maybe 0 (boundedLength (maximumEntries + 1)) (parsedValue rawArray)
  parseTextArrayEntry index (String value)
    | Text.null value =
        Parsed [BuildInfoArrayTextEmpty scope field index | enforceArrayTextNonEmpty] Nothing
    | otherwise = Parsed [] (Just value)
  parseTextArrayEntry index _ =
    Parsed
      [BuildInfoArrayElementWrongType scope field index "text" | enforceArrayTextType]
      Nothing

requiredFilePathArray :: Int -> Text -> Object -> Text -> Parsed [FilePath]
requiredFilePathArray maximumEntries scope object field =
  fmapParsed (map Text.unpack) (requiredTextArray maximumEntries scope object field)

fmapParsed :: (left -> right) -> Parsed left -> Parsed right
fmapParsed transform (Parsed problems value) = Parsed problems (transform <$> value)

unknownFields :: Text -> Set Text -> Object -> [DiagnosticCompilerBuildInfoProblem]
unknownFields scope allowed object =
  [BuildInfoFieldUnknown scope field
  | enforceUnknownFields,
    field <- sort (map Key.toText (KeyMap.keys object)), Set.notMember field allowed]

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
componentScope index = "build-info.components[" <> Text.pack (show index) <> "]"

duplicates :: Ord value => [value] -> [value]
duplicates = mapMaybe duplicateHead . group . sort
 where
  duplicateHead (value : _ : _) = Just value
  duplicateHead _ = Nothing

safeAbsolutePath :: FilePath -> Bool
safeAbsolutePath path =
  isAbsolutePath path
    && (allowAbsoluteFileTrailingSeparator || not (hasTrailingSeparator path))
    && safeAbsoluteSegments path

safeAbsolutePathAllowDirectory :: FilePath -> Bool
safeAbsolutePathAllowDirectory path = isAbsolutePath path && safeAbsoluteSegments path

safeAbsoluteSegments :: FilePath -> Bool
safeAbsoluteSegments path =
  not (unsafePathCharacters path)
    && length segments <= maximumPathDepth && all validSegment segments
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
  not (unsafePathCharacters path) && length segments <= maximumPathDepth
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
  | isAbsolutePath path = safeAbsolutePathAllowDirectory path
  | otherwise = safeRelativePath True path

isAbsolutePath :: FilePath -> Bool
isAbsolutePath = Text.isPrefixOf "/" . Text.pack

hasTrailingSeparator :: FilePath -> Bool
hasTrailingSeparator = Text.isSuffixOf "/" . Text.pack

unsafePathCharacters :: FilePath -> Bool
unsafePathCharacters path =
  Text.any unsafeCharacter text || (not allowPathBackslash && Text.isInfixOf "\\" text)
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
   in candidate == Text.dropWhileEnd (== '/') root || Text.isPrefixOf root candidate

textByteLength :: Text -> Int
textByteLength = ByteString.length . TextEncoding.encodeUtf8

boundedTextBytes :: Int -> Text -> Bool
boundedTextBytes limit value =
  ByteString.length (TextEncoding.encodeUtf8 (Text.take (limit + 1) value)) <= limit

boundedFilePathBytes :: Int -> FilePath -> Bool
boundedFilePathBytes limit value =
  let prefix = take (limit + 1) value
   in boundedLength (limit + 1) prefix <= limit
        && boundedTextBytes limit (Text.pack prefix)

maybeToList :: Maybe value -> [value]
maybeToList Nothing = []
maybeToList (Just value) = [value]

boundedLength :: Int -> [value] -> Int
boundedLength limit = go 0
 where
  go !count _ | count >= limit = count
  go !count [] = count
  go !count (_ : rest) = go (count + 1) rest

boundedProblems
  :: [DiagnosticCompilerBuildInfoProblem]
  -> [DiagnosticCompilerBuildInfoProblem]
boundedProblems problems =
  finishProblemAccumulator (addProblemsToAccumulator problems emptyProblemAccumulator)

singleProblemRefusal :: DiagnosticCompilerBuildInfoProblem -> DiagnosticCompilerBuildInfoRefusal
singleProblemRefusal problem =
  DiagnosticCompilerBuildInfoRefusal (problem :| []) Nothing

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
    Just nonEmpty -> nonEmpty
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
  -> Either DiagnosticCompilerBuildInfoProblem [DiagnosticCompilerBuildInfoProblem]
scanDuplicateJsonKeys bytes = do
  (afterValue, _) <-
    scanJsonValue "build-info" bytes 1 (JsonScanState 0)
      (skipWhitespace bytes 0)
  let afterWhitespace = skipWhitespace bytes afterValue
  if afterWhitespace == ByteString.length bytes
    then Right []
    else if allowTrailingJsonBytes
      then Right []
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
        Just 123 -> scanJsonObject scope bytes depth nextState start
        Just 91 -> scanJsonArray scope bytes depth nextState start
        Just 34 -> do
          (afterString, _) <- scanJsonString scope bytes start
          Right (afterString, nextState)
        Just _ -> do
          afterScalar <- scanJsonScalar scope bytes start
          Right (afterScalar, nextState)
 where
  start = skipWhitespace bytes offset

scanJsonObject
  :: Text -> ByteString -> Int -> JsonScanState -> Int
  -> Either DiagnosticCompilerBuildInfoProblem (Int, JsonScanState)
scanJsonObject scope bytes depth state opening =
  loop Set.empty 0 state (skipWhitespace bytes (opening + 1))
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
            expectByte bytes 58 (skipWhitespace bytes afterKey) ("':' after key in " <> scope)
          (afterValue, stateAfterValue) <-
            scanJsonValue (scope <> "." <> escapedScopeToken key) bytes (depth + 1)
              stateAfterDuplicate (skipWhitespace bytes afterColon)
          let next = skipWhitespace bytes afterValue
              nextSeen = Set.insert key seen
          case byteAt bytes next of
            Just 44 ->
              loop nextSeen (memberCount + 1) stateAfterValue
                (skipWhitespace bytes (next + 1))
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
  loop 0 state (skipWhitespace bytes (opening + 1))
 where
  loop index currentState offset = case byteAt bytes offset of
    Just 93 -> Right (offset + 1, currentState)
    _
      | index >= maximumJsonArrayElements ->
          Left (BuildInfoResourceLimitExceeded "json-array-elements"
            maximumJsonArrayElements (index + 1))
      | otherwise -> do
          (afterValue, nextState) <-
            scanJsonValue (scope <> "[" <> Text.pack (show index) <> "]")
              bytes (depth + 1) currentState offset
          let next = skipWhitespace bytes afterValue
          case byteAt bytes next of
            Just 44 ->
              loop (index + 1) nextState (skipWhitespace bytes (next + 1))
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
          | escaped -> seek (offset + 1) False
          | byte == 92 -> seek (offset + 1) True
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
                    Right decoded -> Right (offset + 1, decoded)
          | otherwise -> seek (offset + 1) False

scanJsonScalar
  :: Text -> ByteString -> Int -> Either DiagnosticCompilerBuildInfoProblem Int
scanJsonScalar scope bytes start = do
  end <- findScalarEnd scope bytes start
  let encoded = ByteString.take (end - start) (ByteString.drop start bytes)
  if ByteString.null encoded
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
      Right (JsonScanState (tokenCount + 1))

escapedScopeToken :: Text -> Text
escapedScopeToken =
  Text.concatMap
    (\character ->
      if isAsciiAlphaNumeric character || elem character ['-', '_']
        then Text.singleton character
        else "\\u{" <> Text.pack (show (ord character)) <> "}")

malformed :: Text -> Either DiagnosticCompilerBuildInfoProblem value
malformed = Left . BuildInfoDuplicateKeyScanFailed

expectByte
  :: ByteString -> Word8 -> Int -> Text
  -> Either DiagnosticCompilerBuildInfoProblem Int
expectByte bytes expected offset label = case byteAt bytes offset of
  Just observed | observed == expected -> Right (offset + 1)
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
isJsonDelimiter byte = isJsonWhitespace byte || elem byte [44, 93, 125]

skipWhitespace :: ByteString -> Int -> Int
skipWhitespace bytes = go
 where
  go offset = case byteAt bytes offset of
    Just byte | isJsonWhitespace byte -> go (offset + 1)
    _ -> offset

isJsonWhitespace :: Word8 -> Bool
isJsonWhitespace byte = elem byte [9, 10, 13, 32]

byteAt :: ByteString -> Int -> Maybe Word8
byteAt bytes offset
  | offset < 0 || offset >= ByteString.length bytes = Nothing
  | otherwise = Just (ByteString.index bytes offset)
