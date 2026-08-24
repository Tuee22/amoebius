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
        diagnosticCheckResult
          digest
          inputBytes
          "observed-refusal"
          problems
          ( observation
              "compiler-elaborated-plan.root"
              ( Text.pack
                  ( show
                      ( digest
                      , ( cabalVersion
                        , cabalLibraryVersion
                        , compilerId
                        , compilerAbi
                        , operatingSystem
                        , architecture
                        )
                      )
                  )
              )
              : zipWith (unitObservation digest) [0 :: Int ..] units
          )
    )

diagnosticCheckResult
  :: Maybe Text
  -> Int
  -> Text
  -> NonEmpty CompilerElaboratedPlanProblem
  -> [Observation]
  -> CheckResult
diagnosticCheckResult digest inputBytes status problems subjectObservations =
  CheckResult
    { checkName = "compiler-elaborated-plan-diagnostic-refusal"
    , checkObservations =
        [ observation
            "compiler-elaborated-plan.input-sha256"
            (maybe "unavailable-over-input-limit" id digest)
        , observation
            "compiler-elaborated-plan.input-bytes"
            (Text.pack (show inputBytes))
        , observation "compiler-elaborated-plan.status" status
        ]
          <> subjectObservations
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_PUBLIC_REFUSAL_BYPASS_MUTANT
    , checkFindings = problemFinding (NonEmpty.head problems) `seq` []
#else
    , checkFindings = map problemFinding (NonEmpty.toList problems)
#endif
    }

problemFinding :: CompilerElaboratedPlanProblem -> Finding
problemFinding problem =
  finding
    "COMPILER-ELABORATED-PLAN-DIAGNOSTIC-REFUSAL"
    "compiler-elaborated-plan.json"
    (Text.pack (show problem))

unitObservation :: Maybe Text -> Int -> DiagnosticElaboratedUnit -> Observation
unitObservation digest index unit =
  observation
    ("compiler-elaborated-plan.unit." <> Text.pack (show index))
    (Text.pack (show (digest, index, diagnosticUnitObservationWire unit)))

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
            singleProblemRefusal inputDigest inputBytes (PlanJsonInvalid "aeson-decode-invalid")
          Right decoded
            | not (null duplicateProblems) ->
                hardRefusal inputDigest inputBytes duplicateProblems
            | otherwise -> case decoded of
                Object root -> case parseRoot root of
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
                _ -> singleProblemRefusal inputDigest inputBytes PlanRootNotObject
 where
  inputBytes = ByteString.length bytes
  inputSha256 = sha256Text bytes
  inputDigest = Just inputSha256

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
    TkLit _ continuation -> Right ([], continuation, nextBudget)
    TkText value continuation -> do
      checkJsonStringLength (Text.length value)
      Right ([], continuation, nextBudget)
    TkNumber _ continuation -> Right ([], continuation, nextBudget)
    TkArrayOpen values -> do
      nextDepth <- enterJsonContainer depth
      scanJsonArray path nextDepth 0 nextBudget values
    TkRecordOpen fields -> do
      nextDepth <- enterJsonContainer depth
      scanJsonRecord path nextDepth 0 Set.empty nextBudget fields
    TkErr message -> Left (JsonScanInvalid (Text.pack message))

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
    itemBudget <- consumeJsonToken budget
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
    finalBudget <- consumeJsonToken budget
    Right ([], continuation, finalBudget)
  TkArrayErr message -> Left (JsonScanInvalid (Text.pack message))

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
    pairBudget <- consumeJsonToken budget
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
    finalBudget <- consumeJsonToken budget
    Right ([], continuation, finalBudget)
  TkRecordErr message -> Left (JsonScanInvalid (Text.pack message))

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
  JsonScanInvalid _ -> PlanJsonInvalid "token-scan-invalid"
  JsonScanResourceLimit label limit observed ->
    PlanResourceLimitExceeded label limit observed

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
appendJsonField (JsonPath segments) name =
  JsonPath (segments <> [JsonObjectField name])

appendJsonIndex :: JsonPath -> Int -> JsonPath
appendJsonIndex (JsonPath segments) index =
  JsonPath (segments <> [JsonArrayIndex index])

renderJsonPath :: JsonPath -> Text
renderJsonPath (JsonPath segments) = "plan" <> foldMap renderSegment segments
 where
  renderSegment segment = case segment of
    JsonObjectField name -> "[" <> Text.pack (show (Text.unpack name)) <> "]"
    JsonArrayIndex index -> "[" <> Text.pack (show index) <> "]"

jsonFieldScope :: Text -> Text -> Text
jsonFieldScope scope name =
  scope <> "[" <> Text.pack (show (Text.unpack name)) <> "]"

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
      let units = sortOn diagnosticElaboratedUnitId (map parsedUnitValue decodedUnits)
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

parseInstallUnit :: Int -> Value -> Parsed ParsedUnit
parseInstallUnit index (Object object) =
  case parsedValue unitType of
    Just "pre-existing" -> parsePreExistingUnit index object
    Just "configured" -> parseConfiguredUnit index object
    Just "foreign"
      | unsupportedInstallUnitTypeAccepted -> parsePreExistingUnit index object
    Just observed -> Parsed (baseProblems <> [UnsupportedInstallUnitType index observed]) Nothing
    Nothing -> Parsed baseProblems Nothing
 where
  scope = unitScope index
  unitType = requiredSemanticText scope object "type"
  baseProblems = parsedProblems unitType
parseInstallUnit index _ =
  Parsed
    [PlanJsonFieldTypeMismatch (unitScope index) "<entry>" "object"]
    Nothing

unsupportedInstallUnitTypeAccepted :: Bool
#ifdef VALIDATION_COMPILER_ELABORATED_PLAN_INSTALL_UNIT_TYPE_BYPASS_MUTANT
unsupportedInstallUnitTypeAccepted = True
#else
unsupportedInstallUnitTypeAccepted = False
#endif

schemaVersionAccepted :: Text -> Text -> Text -> Bool
schemaVersionAccepted field expected actual = case field of
  "cabal-version" -> cabalSchemaVersionAccepted expected actual
  "cabal-lib-version" -> cabalLibrarySchemaVersionAccepted expected actual
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
    any (`Text.isPrefixOf` name) ["exe:", "test:", "bench:"]
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
    (Just _, Nothing) -> parseDirectComponent index unitId object
    (Nothing, Just (Object components)) -> parseComponentMap index unitId components
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
  if KeyMap.null componentMap
    then Parsed [ConfiguredUnitComponentDiscoveryEmpty unitId] Nothing
    else case partitionParsed parsedComponents of
      (problems, _)
        | not (null problems) -> Parsed problems Nothing
      (_, components) ->
        let ordered = sortOn diagnosticElaboratedComponentName components
            declaredNames = sort (map Key.toText (KeyMap.keys componentMap))
         in Parsed [] (Just (ordered, declaredNames, ComponentMapShape))
 where
  parsedComponents =
    [ parseNestedComponent index unitId (Key.toText name) value
    | (name, value) <- sortOn (Key.toText . fst) (KeyMap.toList componentMap)
    ]

parseNestedComponent :: Int -> Text -> Text -> Value -> Parsed DiagnosticElaboratedComponent
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
parseNestedComponent index _ name _ =
  Parsed
    [ PlanJsonFieldTypeMismatch
        (jsonFieldScope (unitScope index) "components")
        name
        "object"
    ]
    Nothing

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
            Just "local" -> parseLocalSource scope object
            Just "repo-tar" -> parseRepositoryTarSource scope object
            Just "source-repo" -> parseSourceRepositorySource scope object
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
  ("local", LocalPackageSource _) -> Parsed [] (Just (LocalUnit, LocalBuildStyle))
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
    | observed == "global" -> Parsed [] (Just (RemoteUnit, GlobalBuildStyle))
    | observed == "inplace" -> Parsed [] (Just (RemoteUnit, InplaceBuildStyle))
  (observed, SourceRepositoryPackageSource _ _ _)
    | observed == "global" -> Parsed [] (Just (RemoteUnit, GlobalBuildStyle))
    | observed == "inplace" -> Parsed [] (Just (RemoteUnit, InplaceBuildStyle))
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
  duplicateUnitProblems
    <> duplicateLocalComponentProblems
    <> dependencyProblems
    <> dependencyCycleProblems
    <> localDiscoveryProblems
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
    emptyUnitProblems
      <> [LocalComponentDiscoveryEmpty | null declaredLocal]

unitDependencyProblems :: Set Text -> DiagnosticElaboratedUnit -> [CompilerElaboratedPlanProblem]
unitDependencyProblems knownUnitIds unit =
  preExistingProblems <> concatMap componentProblems (diagnosticElaboratedUnitComponents unit)
 where
  unitId = diagnosticElaboratedUnitId unit
  preExistingProblems =
    dependencyListProblems knownUnitIds unitId "<unit>.depends" (diagnosticElaboratedUnitDependencyUnitIds unit)
  componentProblems component =
    dependencyListProblems
      knownUnitIds
      unitId
      (diagnosticElaboratedComponentName component <> ".depends")
      (diagnosticElaboratedComponentDependencyUnitIds component)
      <> dependencyListProblems
        knownUnitIds
        unitId
        (diagnosticElaboratedComponentName component <> ".exe-depends")
        (diagnosticElaboratedComponentExecutableDependencyUnitIds component)

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
    sort
      [ (diagnosticElaboratedUnitId unit, diagnosticElaboratedComponentName component)
      | unit <- units
      , diagnosticElaboratedUnitBuildStyle unit `elem` [LocalBuildStyle, InplaceBuildStyle]
      , component <- diagnosticElaboratedUnitComponents unit
      ]
  configurationSubject =
    sort
      [ ( diagnosticElaboratedUnitId unit
        , diagnosticElaboratedUnitBuildStyle unit
        , diagnosticElaboratedUnitComponentShape unit
        , diagnosticElaboratedUnitFlags unit
        , sort (map diagnosticElaboratedComponentName (diagnosticElaboratedUnitComponents unit))
        )
      | unit <- units
      , diagnosticElaboratedUnitBuildStyle unit /= PreExistingBuildStyle
      ]
  dependencySubject = sort (concatMap unitDependencySubject units)
  packageSourceSubject =
    sort
      [ ( diagnosticElaboratedUnitId unit
        , diagnosticElaboratedUnitPackageSourceKind unit
        , diagnosticElaboratedUnitPackageSourceRoot unit
        , diagnosticElaboratedUnitPackageSourceLocation unit
        , diagnosticElaboratedUnitPackageSourceTag unit
        , diagnosticElaboratedUnitPackageCabalSha256 unit
        , diagnosticElaboratedUnitPackageSourceSha256 unit
        )
      | unit <- units
      , diagnosticElaboratedUnitOrigin unit /= PreExistingUnit
      ]
  buildArtifactSubject =
    sort
      [ ( diagnosticElaboratedUnitId unit
        , diagnosticElaboratedUnitBuildInfoPath unit
        , diagnosticElaboratedUnitDistDirectoryPath unit
        , diagnosticElaboratedUnitBinaryPath unit
        )
      | unit <- units
      , diagnosticElaboratedUnitOrigin unit /= PreExistingUnit
      ]
  localSourceRoots =
    sort
      [ (diagnosticElaboratedUnitId unit, root)
      | unit <- units
      , diagnosticElaboratedUnitOrigin unit == LocalUnit
      , Just root <- [diagnosticElaboratedUnitPackageSourceRoot unit]
      ]

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
  [ (unitId, "<unit>.depends", dependency)
  | dependency <- diagnosticElaboratedUnitDependencyUnitIds unit
  ]
    <> concatMap componentSubject (diagnosticElaboratedUnitComponents unit)
 where
  unitId = diagnosticElaboratedUnitId unit
  componentSubject component =
    [ (unitId, diagnosticElaboratedComponentName component <> ".depends", dependency)
    | dependency <- diagnosticElaboratedComponentDependencyUnitIds component
    ]
      <> [ ( unitId
           , diagnosticElaboratedComponentName component <> ".exe-depends"
           , dependency
           )
         | dependency <- diagnosticElaboratedComponentExecutableDependencyUnitIds component
         ]

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
  LocalPackageSource _ ->
    [PlanJsonFieldUnexpected scope "pkg-cabal-sha256" | localCabalHashForbidden cabalPresent]
      <> [PlanJsonFieldUnexpected scope "pkg-src-sha256" | localSourceHashForbidden sourcePresent]
  RepositoryTarPackageSource _ _ ->
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
  SourceRepositoryPackageSource _ _ tag ->
    [PlanJsonFieldUnexpected scope "pkg-cabal-sha256" | sourceRepositoryCabalHashForbidden cabalPresent]
      <> [RemotePackageSourceHashMissing unitId | sourceRepositoryHashMissing sourcePresent]
      <> [ RemotePackageSourceHashMalformed unitId observed
         | Just observed <- [sourceSha]
         , not (sha256DigestText observed)
         ]
      <> [SourceRepositoryTagMutable unitId tag | not (immutableGitObjectText tag)]
  PreExistingPackageSource -> []

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
  (character >= '0' && character <= '9')
    || (character >= 'a' && character <= 'f')

requiredText :: Text -> Object -> Text -> Parsed Text
requiredText scope object name = case KeyMap.lookup (Key.fromText name) object of
  Nothing -> Parsed [PlanJsonFieldMissing scope name] Nothing
  Just (String value)
    | Text.null value -> Parsed [PlanJsonTextEmpty scope name] Nothing
    | otherwise -> Parsed [] (Just value)
  Just value -> Parsed [PlanJsonFieldTypeMismatch scope name (jsonType value)] Nothing

optionalText :: Text -> Object -> Text -> Parsed Text
optionalText scope object name = case KeyMap.lookup (Key.fromText name) object of
  Nothing -> Parsed [] Nothing
  Just (String value)
    | Text.null value -> Parsed [PlanJsonTextEmpty scope name] Nothing
    | otherwise -> Parsed [] (Just value)
  Just value -> Parsed [PlanJsonFieldTypeMismatch scope name (jsonType value)] Nothing

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
            , not (semanticTextAccepted predicate value)
            ]
       in if null malformed
            then Parsed problems (Just values)
            else Parsed (problems <> malformed) Nothing

constrainParsedText
  :: Text
  -> Text
  -> (Text -> Bool)
  -> Parsed Text
  -> Parsed Text
constrainParsedText scope name predicate (Parsed problems parsed) = case parsed of
  Just value
    | not (semanticTextAccepted predicate value) ->
        Parsed (problems <> [PlanJsonTextMalformed scope name value]) Nothing
  _ -> Parsed problems parsed

requiredSafeFilePath :: Text -> Object -> Text -> Parsed FilePath
requiredSafeFilePath scope object name =
  constrainParsedPath scope name (requiredText scope object name)

optionalSafeFilePath :: Text -> Object -> Text -> Parsed FilePath
optionalSafeFilePath scope object name =
  constrainParsedPath scope name (optionalText scope object name)

constrainParsedPath :: Text -> Text -> Parsed Text -> Parsed FilePath
constrainParsedPath scope name (Parsed problems parsed) = case parsed of
  Just value
    | not (pathTextAccepted value) ->
        Parsed
          (problems <> [PlanJsonPathUnsafe scope name (Text.unpack value)])
          Nothing
    | otherwise -> Parsed problems (Just (Text.unpack value))
  Nothing -> Parsed problems Nothing

requiredObject :: Text -> Object -> Text -> Parsed Object
requiredObject scope object name = case KeyMap.lookup (Key.fromText name) object of
  Nothing -> Parsed [PlanJsonFieldMissing scope name] Nothing
  Just (Object value) -> Parsed [] (Just value)
  Just value -> Parsed [PlanJsonFieldTypeMismatch scope name (jsonType value)] Nothing

requiredUnitArray :: Text -> Object -> Text -> Parsed [Value]
requiredUnitArray scope object name = case KeyMap.lookup (Key.fromText name) object of
  Nothing -> Parsed [PlanJsonFieldMissing scope name] Nothing
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
  Just value -> Parsed [PlanJsonFieldTypeMismatch scope name (jsonType value)] Nothing

requiredDependencyTextArray :: Text -> Object -> Text -> Parsed [Text]
requiredDependencyTextArray scope object name = case KeyMap.lookup (Key.fromText name) object of
  Nothing -> Parsed [PlanJsonFieldMissing scope name] Nothing
  Just (Array values) -> decodeTextValues (toList values)
  Just value -> Parsed [PlanJsonFieldTypeMismatch scope name (jsonType value)] Nothing
 where
  decodeTextValues values =
    let typed = map asText (zip [0 :: Int ..] values)
        typeProblems = [problem | Left problem <- typed]
        texts = [value | Right value <- typed]
     in if null typeProblems
          then Parsed [] (Just texts)
          else Parsed typeProblems Nothing
  asText (position, String value)
    | Text.null value = Left (PlanJsonTextEmpty scope (name <> "[" <> Text.pack (show position) <> "]"))
    | otherwise = Right value
  asText (position, value) =
    Left
      ( PlanJsonFieldTypeMismatch
          scope
          (name <> "[" <> Text.pack (show position) <> "]")
          (jsonType value)
      )

requiredBooleanMap :: Text -> Object -> Text -> Parsed [(Text, Bool)]
requiredBooleanMap scope object name = case requiredObject scope object name of
  Parsed problems Nothing -> Parsed problems Nothing
  Parsed problems (Just values) ->
    let orderedEntries = sortOn (Key.toText . fst) (KeyMap.toList values)
        typed = map asBoolean orderedEntries
        typeProblems = [problem | Left problem <- typed]
        flags = sort [value | Right value <- typed]
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
  asBoolean (key, value) =
    Left
      ( PlanJsonFieldTypeMismatch
          (jsonFieldScope scope name)
          (Key.toText key)
          (jsonType value)
      )

unknownFields :: Text -> Set Text -> Object -> [CompilerElaboratedPlanProblem]
unknownFields scope allowed object =
  [ PlanJsonFieldUnknown scope observed
  | observed <- sort (map Key.toText (KeyMap.keys object))
  , Set.notMember observed allowed
  ]

jsonType :: Value -> Text
jsonType value = case value of
  Object _ -> "object"
  Array _ -> "array"
  String _ -> "string"
  Number _ -> "number"
  Bool _ -> "boolean"
  Null -> "null"

unitScope :: Int -> Text
unitScope index =
  renderJsonPath
    (appendJsonIndex (appendJsonField (JsonPath []) "install-plan") index)

observedTextOr :: Text -> Parsed Text -> Text
observedTextOr fallback parsed = maybe fallback id (parsedValue parsed)

parsedProblems :: Parsed value -> [CompilerElaboratedPlanProblem]
parsedProblems (Parsed problems _) = problems

parsedValue :: Parsed value -> Maybe value
parsedValue (Parsed _ value) = value

partitionParsed :: [Parsed value] -> ([CompilerElaboratedPlanProblem], [value])
partitionParsed values =
  (concatMap parsedProblems values, catMaybes (map parsedValue values))

parsedUnitValue :: ParsedUnit -> DiagnosticElaboratedUnit
parsedUnitValue (ParsedUnit unit _) = unit

duplicates :: Ord value => [value] -> [value]
duplicates = mapMaybe duplicateValue . group . sort
 where
  duplicateValue (value : _ : _) = Just value
  duplicateValue _ = Nothing

groupedValues :: (Ord key, Ord value) => [(key, value)] -> [(key, [value])]
groupedValues values = mapMaybe renderGroup (groupByKey (sortOn fst values))
 where
  renderGroup ((key, value) : remaining) =
    Just (key, sort (value : map snd remaining))
  renderGroup [] = Nothing
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
  DirectComponentShape _ -> DirectElaboratedComponentShape
  ComponentMapShape -> AggregateElaboratedComponentShape
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
componentBuiltinAccepted value = value `elem` ["lib", "setup", "foreign"]
#else
componentBuiltinAccepted value = value `elem` ["lib", "setup"]
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
componentPrefixes = ["lib:", "exe:", "test:", "bench:", "foreign:"]
#else
componentPrefixes = ["lib:", "exe:", "test:", "bench:"]
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
  asciiAlphaNumeric character || character `elem` ['.', '_', '-', '@']
#else
componentCharacterAccepted character =
  asciiAlphaNumeric character || character `elem` ['.', '_', '-']
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
  asciiAlphaNumeric character || character `elem` ['-', '_', '.', '+', ':', '@']
#else
portableIdentityCharacterAccepted character =
  asciiAlphaNumeric character || character `elem` ['-', '_', '.', '+', ':']
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
platformCharacterAccepted character = asciiAlphaNumeric character || character `elem` ['-', '_', '.']
#else
platformCharacterAccepted character = asciiAlphaNumeric character || character `elem` ['-', '_']
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
flagCharacterAccepted character = asciiAlphaNumeric character || character `elem` ['-', '_', '.']
#else
flagCharacterAccepted character = asciiAlphaNumeric character || character `elem` ['-', '_']
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
  (character >= 'a' && character <= 'z')
    || (character >= 'A' && character <= 'Z')
    || (character >= '0' && character <= '9')

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
  PreExistingPackageSource -> "pre-existing"
  LocalPackageSource _ -> "local"
  RepositoryTarPackageSource _ _ -> "repo-tar"
  SourceRepositoryPackageSource _ _ _ -> "source-repo"

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
  _ = onMalformed digest inputBytes problems
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
      digest
      inputBytes
      problems
      cabalVersion
      cabalLibraryVersion
      compilerId
      compilerAbi
      operatingSystem
      architecture
      units

singleProblemRefusal
  :: Maybe Text
  -> Int
  -> CompilerElaboratedPlanProblem
  -> DiagnosticCompilerElaboratedPlanRefusal
singleProblemRefusal digest inputBytes problem =
  DiagnosticCompilerElaboratedPlanRefusal digest inputBytes (problem :| []) Nothing

hardRefusal
  :: Maybe Text
  -> Int
  -> [CompilerElaboratedPlanProblem]
  -> DiagnosticCompilerElaboratedPlanRefusal
hardRefusal digest inputBytes problems =
  DiagnosticCompilerElaboratedPlanRefusal
    digest
    inputBytes
    (boundedProblemSet "hard-refusal" problems)
    Nothing

observedRefusal
  :: Maybe Text
  -> Int
  -> [CompilerElaboratedPlanProblem]
  -> [CompilerElaboratedPlanProblem]
  -> DiagnosticCompilerElaboratedPlanSnapshot
  -> DiagnosticCompilerElaboratedPlanRefusal
observedRefusal digest inputBytes mandatoryProblems variableProblems snapshot =
  DiagnosticCompilerElaboratedPlanRefusal
    digest
    inputBytes
    (boundedObservedProblemSet mandatoryProblems variableProblems)
    (Just snapshot)

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
    (bounded, []) -> bounded
    (_, _ : _) ->
      [ PlanResourceLimitExceeded
          "problems"
          compilerElaboratedPlanMaximumSemanticProblems
          (semanticProblemLimit + 1)
      ]

sha256Text :: ByteString -> Text
sha256Text = Text.pack . concatMap renderOctet . ByteString.unpack . SHA256.hash
 where
  renderOctet octet =
    [ hexDigit (fromIntegral octet `div` 16)
    , hexDigit (fromIntegral octet `mod` 16)
    ]
  hexDigit :: Int -> Char
  hexDigit value
    | value < 10 = toEnum (fromEnum '0' + value)
    | otherwise = toEnum (fromEnum 'a' + value - 10)

diagnosticElaboratedUnitOrigin :: DiagnosticElaboratedUnit -> DiagnosticElaboratedUnitOrigin
diagnosticElaboratedUnitOrigin (DiagnosticElaboratedUnit value _ _ _ _ _ _ _ _ _ _ _ _ _ _) = value

diagnosticElaboratedUnitBuildStyle :: DiagnosticElaboratedUnit -> DiagnosticElaboratedUnitBuildStyle
diagnosticElaboratedUnitBuildStyle (DiagnosticElaboratedUnit _ value _ _ _ _ _ _ _ _ _ _ _ _ _) = value

diagnosticElaboratedUnitId :: DiagnosticElaboratedUnit -> Text
diagnosticElaboratedUnitId (DiagnosticElaboratedUnit _ _ value _ _ _ _ _ _ _ _ _ _ _ _) = value

diagnosticElaboratedUnitPackageName :: DiagnosticElaboratedUnit -> Text
diagnosticElaboratedUnitPackageName (DiagnosticElaboratedUnit _ _ _ value _ _ _ _ _ _ _ _ _ _ _) = value

diagnosticElaboratedUnitPackageVersion :: DiagnosticElaboratedUnit -> Text
diagnosticElaboratedUnitPackageVersion (DiagnosticElaboratedUnit _ _ _ _ value _ _ _ _ _ _ _ _ _ _) = value

diagnosticElaboratedUnitPackageSourceKind :: DiagnosticElaboratedUnit -> Text
diagnosticElaboratedUnitPackageSourceKind (DiagnosticElaboratedUnit _ _ _ _ _ source _ _ _ _ _ _ _ _ _) = packageSourceKind source

diagnosticElaboratedUnitPackageSourceRoot :: DiagnosticElaboratedUnit -> Maybe FilePath
diagnosticElaboratedUnitPackageSourceRoot (DiagnosticElaboratedUnit _ _ _ _ _ source _ _ _ _ _ _ _ _ _) = case source of
  LocalPackageSource root -> Just root
  _ -> Nothing

diagnosticElaboratedUnitPackageSourceLocation :: DiagnosticElaboratedUnit -> Maybe Text
diagnosticElaboratedUnitPackageSourceLocation (DiagnosticElaboratedUnit _ _ _ _ _ source _ _ _ _ _ _ _ _ _) = case source of
  RepositoryTarPackageSource _ uri -> Just uri
  SourceRepositoryPackageSource _ location _ -> Just location
  _ -> Nothing

diagnosticElaboratedUnitPackageSourceTag :: DiagnosticElaboratedUnit -> Maybe Text
diagnosticElaboratedUnitPackageSourceTag (DiagnosticElaboratedUnit _ _ _ _ _ source _ _ _ _ _ _ _ _ _) = case source of
  SourceRepositoryPackageSource _ _ tag -> Just tag
  _ -> Nothing

diagnosticElaboratedUnitFlags :: DiagnosticElaboratedUnit -> [(Text, Bool)]
diagnosticElaboratedUnitFlags (DiagnosticElaboratedUnit _ _ _ _ _ _ flags _ _ _ _ _ _ _ _) = flags

diagnosticElaboratedUnitComponents :: DiagnosticElaboratedUnit -> [DiagnosticElaboratedComponent]
diagnosticElaboratedUnitComponents (DiagnosticElaboratedUnit _ _ _ _ _ _ _ components _ _ _ _ _ _ _) = components

diagnosticElaboratedUnitComponentShape
  :: DiagnosticElaboratedUnit
  -> Maybe DiagnosticElaboratedComponentShape
diagnosticElaboratedUnitComponentShape
  (DiagnosticElaboratedUnit _ _ _ _ _ _ _ _ shape _ _ _ _ _ _) = shape

diagnosticElaboratedUnitDependencyUnitIds :: DiagnosticElaboratedUnit -> [Text]
diagnosticElaboratedUnitDependencyUnitIds (DiagnosticElaboratedUnit _ _ _ _ _ _ _ _ _ dependencies _ _ _ _ _) = dependencies

diagnosticElaboratedUnitPackageCabalSha256 :: DiagnosticElaboratedUnit -> Maybe Text
diagnosticElaboratedUnitPackageCabalSha256 (DiagnosticElaboratedUnit _ _ _ _ _ _ _ _ _ _ value _ _ _ _) = value

diagnosticElaboratedUnitPackageSourceSha256 :: DiagnosticElaboratedUnit -> Maybe Text
diagnosticElaboratedUnitPackageSourceSha256 (DiagnosticElaboratedUnit _ _ _ _ _ _ _ _ _ _ _ value _ _ _) = value

diagnosticElaboratedUnitBuildInfoPath :: DiagnosticElaboratedUnit -> Maybe FilePath
diagnosticElaboratedUnitBuildInfoPath (DiagnosticElaboratedUnit _ _ _ _ _ _ _ _ _ _ _ _ value _ _) = value

diagnosticElaboratedUnitDistDirectoryPath :: DiagnosticElaboratedUnit -> Maybe FilePath
diagnosticElaboratedUnitDistDirectoryPath (DiagnosticElaboratedUnit _ _ _ _ _ _ _ _ _ _ _ _ _ value _) = value

diagnosticElaboratedUnitBinaryPath :: DiagnosticElaboratedUnit -> Maybe FilePath
diagnosticElaboratedUnitBinaryPath (DiagnosticElaboratedUnit _ _ _ _ _ _ _ _ _ _ _ _ _ _ value) = value

diagnosticElaboratedUnitRepositoryType :: DiagnosticElaboratedUnit -> Maybe Text
diagnosticElaboratedUnitRepositoryType (DiagnosticElaboratedUnit _ _ _ _ _ source _ _ _ _ _ _ _ _ _) =
  case source of
    RepositoryTarPackageSource repositoryType _ -> Just repositoryType
    SourceRepositoryPackageSource repositoryType _ _ -> Just repositoryType
    _ -> Nothing

diagnosticElaboratedComponentUnitId :: DiagnosticElaboratedComponent -> Text
diagnosticElaboratedComponentUnitId (DiagnosticElaboratedComponent value _ _ _ _) = value

diagnosticElaboratedComponentName :: DiagnosticElaboratedComponent -> Text
diagnosticElaboratedComponentName (DiagnosticElaboratedComponent _ value _ _ _) = value

diagnosticElaboratedComponentDependencyUnitIds :: DiagnosticElaboratedComponent -> [Text]
diagnosticElaboratedComponentDependencyUnitIds (DiagnosticElaboratedComponent _ _ value _ _) = value

diagnosticElaboratedComponentExecutableDependencyUnitIds :: DiagnosticElaboratedComponent -> [Text]
diagnosticElaboratedComponentExecutableDependencyUnitIds (DiagnosticElaboratedComponent _ _ _ value _) = value

diagnosticElaboratedComponentSourcePaths :: DiagnosticElaboratedComponent -> Maybe [FilePath]
diagnosticElaboratedComponentSourcePaths (DiagnosticElaboratedComponent _ _ _ _ value) = value
