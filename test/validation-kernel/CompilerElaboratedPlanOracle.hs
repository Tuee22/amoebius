{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PackageImports #-}

module CompilerElaboratedPlanOracle
  ( compilerElaboratedPlanAffectedExactCaseLabels
  , compilerElaboratedPlanExactCaseLabels
  , compilerElaboratedPlanSelectorNames
  , runCompilerElaboratedPlanOracle
  , runCompilerElaboratedPlanSelectorImpactOracle
  , runCompilerElaboratedPlanSelectorIsolationOracle
  , runCompilerElaboratedPlanSelectorOracle
  ) where

import Amoebius.Validation.CompilerElaboratedPlan
  ( checkCompilerElaboratedPlanDiagnostic
  )
import Amoebius.Validation.Types
import Control.Monad (unless)
import "crypton" Crypto.Hash (Digest, SHA256, hash)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteString8
import Data.List (isPrefixOf)
import Data.Text (Text)
import Data.Text qualified as Text
import Text.Read (readMaybe)

-- This diagnostic vocabulary is intentionally restated in the oracle.  It is
-- decoded from the public CheckResult's text, not imported from the production
-- parser, so a changed constructor, field order, or omitted subject changes the
-- observed wire and must be listed here explicitly.
data DiagnosticElaboratedUnitOrigin
  = PreExistingUnit
  | RemoteUnit
  | LocalUnit
  deriving (Eq, Ord, Read, Show)

data DiagnosticElaboratedUnitBuildStyle
  = PreExistingBuildStyle
  | LocalBuildStyle
  | GlobalBuildStyle
  | InplaceBuildStyle
  deriving (Eq, Ord, Read, Show)

data DiagnosticElaboratedComponentShape
  = DirectElaboratedComponentShape
  | AggregateElaboratedComponentShape
  deriving (Eq, Ord, Read, Show)

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
      [UnitObservationWire]
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

data ObservedCompilerElaboratedPlan
  = ObservedCompilerElaboratedPlan
      (Maybe Text)
      Int
      [CompilerElaboratedPlanProblem]
      Text
      Text
      Text
      Text
      Text
      Text
      [UnitSnapshotView]
  deriving (Eq, Show)

data ComponentSnapshotView
  = ComponentSnapshotView Text Text [Text] [Text] (Maybe [FilePath])
  deriving (Eq, Read, Show)

data UnitSnapshotView
  = UnitSnapshotView
      DiagnosticElaboratedUnitOrigin
      DiagnosticElaboratedUnitBuildStyle
      Text
      Text
      Text
      Text
      (Maybe FilePath)
      (Maybe Text)
      (Maybe Text)
      (Maybe Text)
      [(Text, Bool)]
      (Maybe DiagnosticElaboratedComponentShape)
      [Text]
      (Maybe Text)
      (Maybe Text)
      (Maybe FilePath)
      (Maybe FilePath)
      (Maybe FilePath)
      [ComponentSnapshotView]
  deriving (Eq, Read, Show)

data PlanSnapshotView
  = PlanSnapshotView
      (Maybe Text)
      Int
      Text
      Text
      Text
      Text
      Text
      Text
      [UnitSnapshotView]
  deriving (Eq, Show)

type ComponentObservationWire =
  (Text, Text, [Text], [Text], Maybe [FilePath])

type UnitObservationWire =
  ( (DiagnosticElaboratedUnitOrigin, DiagnosticElaboratedUnitBuildStyle, Text, Text, Text)
  , (Text, Maybe FilePath, Maybe Text, Maybe Text, Maybe Text)
  , ([(Text, Bool)], Maybe DiagnosticElaboratedComponentShape, [Text], Maybe Text, Maybe Text)
  , (Maybe FilePath, Maybe FilePath, Maybe FilePath)
  , [ComponentObservationWire]
  )

unitSnapshotFromWire :: UnitObservationWire -> UnitSnapshotView
unitSnapshotFromWire
  ( (origin, buildStyle, unitId, packageName, packageVersion)
    , (sourceKind, sourceRoot, sourceLocation, sourceTag, repositoryType)
    , (flags, componentShape, dependencies, cabalSha256, sourceSha256)
    , (buildInfoPath, distDirectoryPath, binaryPath)
    , components
    ) =
    UnitSnapshotView
      origin
      buildStyle
      unitId
      packageName
      packageVersion
      sourceKind
      sourceRoot
      sourceLocation
      sourceTag
      repositoryType
      flags
      componentShape
      dependencies
      cabalSha256
      sourceSha256
      buildInfoPath
      distDirectoryPath
      binaryPath
      (map componentSnapshotFromWire components)

componentSnapshotFromWire :: ComponentObservationWire -> ComponentSnapshotView
componentSnapshotFromWire (unitId, name, dependencies, executableDependencies, sourcePaths) =
  ComponentSnapshotView unitId name dependencies executableDependencies sourcePaths

diagnosticElaboratedUnitOrigin :: UnitSnapshotView -> DiagnosticElaboratedUnitOrigin
diagnosticElaboratedUnitOrigin (UnitSnapshotView value _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _) = value

diagnosticElaboratedUnitBuildStyle :: UnitSnapshotView -> DiagnosticElaboratedUnitBuildStyle
diagnosticElaboratedUnitBuildStyle (UnitSnapshotView _ value _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _) = value

diagnosticElaboratedUnitId :: UnitSnapshotView -> Text
diagnosticElaboratedUnitId (UnitSnapshotView _ _ value _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _) = value

diagnosticElaboratedUnitPackageName :: UnitSnapshotView -> Text
diagnosticElaboratedUnitPackageName (UnitSnapshotView _ _ _ value _ _ _ _ _ _ _ _ _ _ _ _ _ _ _) = value

diagnosticElaboratedUnitPackageVersion :: UnitSnapshotView -> Text
diagnosticElaboratedUnitPackageVersion (UnitSnapshotView _ _ _ _ value _ _ _ _ _ _ _ _ _ _ _ _ _ _) = value

diagnosticElaboratedUnitPackageSourceKind :: UnitSnapshotView -> Text
diagnosticElaboratedUnitPackageSourceKind (UnitSnapshotView _ _ _ _ _ value _ _ _ _ _ _ _ _ _ _ _ _ _) = value

diagnosticElaboratedUnitPackageSourceRoot :: UnitSnapshotView -> Maybe FilePath
diagnosticElaboratedUnitPackageSourceRoot (UnitSnapshotView _ _ _ _ _ _ value _ _ _ _ _ _ _ _ _ _ _ _) = value

diagnosticElaboratedUnitPackageSourceLocation :: UnitSnapshotView -> Maybe Text
diagnosticElaboratedUnitPackageSourceLocation (UnitSnapshotView _ _ _ _ _ _ _ value _ _ _ _ _ _ _ _ _ _ _) = value

diagnosticElaboratedUnitPackageSourceTag :: UnitSnapshotView -> Maybe Text
diagnosticElaboratedUnitPackageSourceTag (UnitSnapshotView _ _ _ _ _ _ _ _ value _ _ _ _ _ _ _ _ _ _) = value

diagnosticElaboratedUnitRepositoryType :: UnitSnapshotView -> Maybe Text
diagnosticElaboratedUnitRepositoryType (UnitSnapshotView _ _ _ _ _ _ _ _ _ value _ _ _ _ _ _ _ _ _) = value

diagnosticElaboratedUnitFlags :: UnitSnapshotView -> [(Text, Bool)]
diagnosticElaboratedUnitFlags (UnitSnapshotView _ _ _ _ _ _ _ _ _ _ value _ _ _ _ _ _ _ _) = value

diagnosticElaboratedUnitComponentShape :: UnitSnapshotView -> Maybe DiagnosticElaboratedComponentShape
diagnosticElaboratedUnitComponentShape (UnitSnapshotView _ _ _ _ _ _ _ _ _ _ _ value _ _ _ _ _ _ _) = value

diagnosticElaboratedUnitDependencyUnitIds :: UnitSnapshotView -> [Text]
diagnosticElaboratedUnitDependencyUnitIds (UnitSnapshotView _ _ _ _ _ _ _ _ _ _ _ _ value _ _ _ _ _ _) = value

diagnosticElaboratedUnitPackageCabalSha256 :: UnitSnapshotView -> Maybe Text
diagnosticElaboratedUnitPackageCabalSha256 (UnitSnapshotView _ _ _ _ _ _ _ _ _ _ _ _ _ value _ _ _ _ _) = value

diagnosticElaboratedUnitPackageSourceSha256 :: UnitSnapshotView -> Maybe Text
diagnosticElaboratedUnitPackageSourceSha256 (UnitSnapshotView _ _ _ _ _ _ _ _ _ _ _ _ _ _ value _ _ _ _) = value

diagnosticElaboratedUnitBuildInfoPath :: UnitSnapshotView -> Maybe FilePath
diagnosticElaboratedUnitBuildInfoPath (UnitSnapshotView _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ value _ _ _) = value

diagnosticElaboratedUnitDistDirectoryPath :: UnitSnapshotView -> Maybe FilePath
diagnosticElaboratedUnitDistDirectoryPath (UnitSnapshotView _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ value _ _) = value

diagnosticElaboratedUnitBinaryPath :: UnitSnapshotView -> Maybe FilePath
diagnosticElaboratedUnitBinaryPath (UnitSnapshotView _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ value _) = value

diagnosticElaboratedUnitComponents :: UnitSnapshotView -> [ComponentSnapshotView]
diagnosticElaboratedUnitComponents (UnitSnapshotView _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ value) = value

diagnosticElaboratedComponentUnitId :: ComponentSnapshotView -> Text
diagnosticElaboratedComponentUnitId (ComponentSnapshotView value _ _ _ _) = value

diagnosticElaboratedComponentName :: ComponentSnapshotView -> Text
diagnosticElaboratedComponentName (ComponentSnapshotView _ value _ _ _) = value

diagnosticElaboratedComponentDependencyUnitIds :: ComponentSnapshotView -> [Text]
diagnosticElaboratedComponentDependencyUnitIds (ComponentSnapshotView _ _ value _ _) = value

diagnosticElaboratedComponentExecutableDependencyUnitIds :: ComponentSnapshotView -> [Text]
diagnosticElaboratedComponentExecutableDependencyUnitIds (ComponentSnapshotView _ _ _ value _) = value

diagnosticElaboratedComponentSourcePaths :: ComponentSnapshotView -> Maybe [FilePath]
diagnosticElaboratedComponentSourcePaths (ComponentSnapshotView _ _ _ _ value) = value

inspectCompilerElaboratedPlanDiagnostic
  :: ByteString
  -> Either [CompilerElaboratedPlanProblem] ObservedCompilerElaboratedPlan
inspectCompilerElaboratedPlanDiagnostic bytes =
  if not publicRefusalShape
    then Left [CompilerElaboratedPlanDiagnosticInvariantRefused "oracle-public-refusal-shape"]
    else case (parsedProblems, inputBytes, status) of
      (Just problems, Just _, Just "malformed-refusal")
        | malformedObservationShape -> Left problems
      (Just problems, Just observedBytes, Just "observed-refusal")
        | observedObservationShape ->
            case (rootWire, unitWires) of
              (Just (cabalVersion, cabalLibraryVersion, compilerId, compilerAbi,
                operatingSystem, architecture), Just units) ->
                  Right
                    ( ObservedCompilerElaboratedPlan
                        inputDigest
                        observedBytes
                        problems
                        cabalVersion
                        cabalLibraryVersion
                        compilerId
                        compilerAbi
                        operatingSystem
                        architecture
                        units
                    )
              _ -> Left [CompilerElaboratedPlanDiagnosticInvariantRefused "oracle-observation-wire"]
      _ -> Left [CompilerElaboratedPlanDiagnosticInvariantRefused "oracle-check-result-shape"]
 where
  result = checkCompilerElaboratedPlanDiagnostic bytes
  findings = checkFindings result
  findingTexts = map findingDetail findings
  publicRefusalShape =
    checkName result == "compiler-elaborated-plan-diagnostic-refusal"
      && not (checkPassed result)
      && inputLengthShape
      && inputDigestShape
      && all
        (\item ->
          findingCode item == "COMPILER-ELABORATED-PLAN-DIAGNOSTIC-REFUSAL"
            && findingSubject item == "compiler-elaborated-plan.json")
        findings
  parsedProblems = traverse (readMaybe . Text.unpack) findingTexts
  inputLengthShape = inputBytes == Just (ByteString.length bytes)
  inputDigestShape = case observationValues "compiler-elaborated-plan.input-sha256" result of
    ["unavailable-over-input-limit"] -> ByteString.length bytes > 8388608
    [digest] ->
      ByteString.length bytes <= 8388608
        && digest == Text.pack (show (hash bytes :: Digest SHA256))
    _ -> False
  inputDigest = case observationValues "compiler-elaborated-plan.input-sha256" result of
    ["unavailable-over-input-limit"] -> Nothing
    [digest] -> Just digest
    _ -> Nothing
  inputBytes = case observationValues "compiler-elaborated-plan.input-bytes" result of
    [value] -> readMaybe (Text.unpack value)
    _ -> Nothing
  status = case observationValues "compiler-elaborated-plan.status" result of
    [value] -> Just value
    _ -> Nothing
  rootWire = case observationValues "compiler-elaborated-plan.root" result of
    [value] -> do
      (boundDigest, wire) <- readMaybe (Text.unpack value)
      if boundDigest == inputDigest then Just wire else Nothing
    _ -> Nothing
  observations = checkObservations result
  observationKeys = map observationKey observations
  baseObservationKeys =
    [ "compiler-elaborated-plan.input-sha256"
    , "compiler-elaborated-plan.input-bytes"
    , "compiler-elaborated-plan.status"
    ]
  malformedObservationShape = observationKeys == baseObservationKeys
  observedObservationShape =
    observationKeys
      == baseObservationKeys
        <> ["compiler-elaborated-plan.root"]
        <> [ "compiler-elaborated-plan.unit." <> Text.pack (show index)
           | index <- [0 .. length unitObservationItems - 1]
           ]
  unitWires = do
    indexed <- traverse parseUnitObservation unitObservationItems
    let indices = map fst indexed
    if indices == [0 .. length indexed - 1]
      then Just (map snd indexed)
      else Nothing
  unitObservationItems =
    [ item
    | item <- observations
    , "compiler-elaborated-plan.unit." `Text.isPrefixOf` observationKey item
    ]
  parseUnitObservation item = do
    suffix <- Text.stripPrefix "compiler-elaborated-plan.unit." (observationKey item)
    index <- readMaybe (Text.unpack suffix)
    if index < (0 :: Int) || suffix /= Text.pack (show index)
      then Nothing
      else do
        (boundDigest, boundIndex, wire) <-
          readMaybe (Text.unpack (observationValue item))
            :: Maybe (Maybe Text, Int, UnitObservationWire)
        if boundDigest == inputDigest && boundIndex == index
          then pure (index, unitSnapshotFromWire wire)
          else Nothing

observationValues :: Text -> CheckResult -> [Text]
observationValues key result =
  [ observationValue item
  | item <- checkObservations result
  , observationKey item == key
  ]

diagnosticElaboratedPlanCabalVersion :: ObservedCompilerElaboratedPlan -> Text
diagnosticElaboratedPlanCabalVersion
  (ObservedCompilerElaboratedPlan _ _ _ value _ _ _ _ _ _) = value

diagnosticElaboratedPlanCabalLibraryVersion :: ObservedCompilerElaboratedPlan -> Text
diagnosticElaboratedPlanCabalLibraryVersion
  (ObservedCompilerElaboratedPlan _ _ _ _ value _ _ _ _ _) = value

diagnosticElaboratedPlanCompilerId :: ObservedCompilerElaboratedPlan -> Text
diagnosticElaboratedPlanCompilerId
  (ObservedCompilerElaboratedPlan _ _ _ _ _ value _ _ _ _) = value

diagnosticElaboratedPlanCompilerAbi :: ObservedCompilerElaboratedPlan -> Text
diagnosticElaboratedPlanCompilerAbi
  (ObservedCompilerElaboratedPlan _ _ _ _ _ _ value _ _ _) = value

diagnosticElaboratedPlanOperatingSystem :: ObservedCompilerElaboratedPlan -> Text
diagnosticElaboratedPlanOperatingSystem
  (ObservedCompilerElaboratedPlan _ _ _ _ _ _ _ value _ _) = value

diagnosticElaboratedPlanArchitecture :: ObservedCompilerElaboratedPlan -> Text
diagnosticElaboratedPlanArchitecture
  (ObservedCompilerElaboratedPlan _ _ _ _ _ _ _ _ value _) = value

diagnosticElaboratedPlanPlatform :: ObservedCompilerElaboratedPlan -> (Text, Text)
diagnosticElaboratedPlanPlatform plan =
  (diagnosticElaboratedPlanArchitecture plan, diagnosticElaboratedPlanOperatingSystem plan)

planSnapshotView :: ObservedCompilerElaboratedPlan -> PlanSnapshotView
planSnapshotView
  ( ObservedCompilerElaboratedPlan
      digest
      inputBytes
      _
      cabalVersion
      cabalLibraryVersion
      compilerId
      compilerAbi
      operatingSystem
      architecture
      units
    ) =
    PlanSnapshotView
      digest
      inputBytes
      cabalVersion
      cabalLibraryVersion
      compilerId
      compilerAbi
      operatingSystem
      architecture
      (map unitSnapshotView units)

unitSnapshotView :: UnitSnapshotView -> UnitSnapshotView
unitSnapshotView unit =
  UnitSnapshotView
    (diagnosticElaboratedUnitOrigin unit)
    (diagnosticElaboratedUnitBuildStyle unit)
    (diagnosticElaboratedUnitId unit)
    (diagnosticElaboratedUnitPackageName unit)
    (diagnosticElaboratedUnitPackageVersion unit)
    (diagnosticElaboratedUnitPackageSourceKind unit)
    (diagnosticElaboratedUnitPackageSourceRoot unit)
    (diagnosticElaboratedUnitPackageSourceLocation unit)
    (diagnosticElaboratedUnitPackageSourceTag unit)
    (diagnosticElaboratedUnitRepositoryType unit)
    (diagnosticElaboratedUnitFlags unit)
    (diagnosticElaboratedUnitComponentShape unit)
    (diagnosticElaboratedUnitDependencyUnitIds unit)
    (diagnosticElaboratedUnitPackageCabalSha256 unit)
    (diagnosticElaboratedUnitPackageSourceSha256 unit)
    (diagnosticElaboratedUnitBuildInfoPath unit)
    (diagnosticElaboratedUnitDistDirectoryPath unit)
    (diagnosticElaboratedUnitBinaryPath unit)
    (map componentSnapshotView (diagnosticElaboratedUnitComponents unit))

componentSnapshotView :: ComponentSnapshotView -> ComponentSnapshotView
componentSnapshotView component =
  ComponentSnapshotView
    (diagnosticElaboratedComponentUnitId component)
    (diagnosticElaboratedComponentName component)
    (diagnosticElaboratedComponentDependencyUnitIds component)
    (diagnosticElaboratedComponentExecutableDependencyUnitIds component)
    (diagnosticElaboratedComponentSourcePaths component)

expectedObservedCheckResult
  :: PlanSnapshotView
  -> [CompilerElaboratedPlanProblem]
  -> CheckResult
expectedObservedCheckResult
  ( PlanSnapshotView
      digest
      inputBytes
      cabalVersion
      cabalLibraryVersion
      compilerId
      compilerAbi
      operatingSystem
      architecture
      units
    )
  problems =
    CheckResult
      { checkName = "compiler-elaborated-plan-diagnostic-refusal"
      , checkObservations =
          [ observation
              "compiler-elaborated-plan.input-sha256"
              (maybe "unavailable-over-input-limit" id digest)
          , observation "compiler-elaborated-plan.input-bytes" (Text.pack (show inputBytes))
          , observation "compiler-elaborated-plan.status" "observed-refusal"
          , observation
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
          ]
            <> [ observation
                  ("compiler-elaborated-plan.unit." <> Text.pack (show index))
                  (Text.pack (show (digest, index, unitObservationWireFromSnapshot unit)))
               | (index, unit) <- zip [0 :: Int ..] units
               ]
      , checkFindings =
          [ finding
              "COMPILER-ELABORATED-PLAN-DIAGNOSTIC-REFUSAL"
              "compiler-elaborated-plan.json"
              (Text.pack (show problem))
          | problem <- problems
          ]
      }

unitObservationWireFromSnapshot :: UnitSnapshotView -> UnitObservationWire
unitObservationWireFromSnapshot
  ( UnitSnapshotView
      origin
      buildStyle
      unitId
      packageName
      packageVersion
      sourceKind
      sourceRoot
      sourceLocation
      sourceTag
      repositoryType
      flags
      componentShape
      dependencies
      cabalSha256
      sourceSha256
      buildInfoPath
      distDirectoryPath
      binaryPath
      components
    ) =
    ( (origin, buildStyle, unitId, packageName, packageVersion)
    , (sourceKind, sourceRoot, sourceLocation, sourceTag, repositoryType)
    , (flags, componentShape, dependencies, cabalSha256, sourceSha256)
    , (buildInfoPath, distDirectoryPath, binaryPath)
    , [ ( componentUnitId
        , componentName
        , componentDependencies
        , executableDependencies
        , sourcePaths
        )
      | ComponentSnapshotView
          componentUnitId
          componentName
          componentDependencies
          executableDependencies
          sourcePaths <- components
      ]
    )

-- These separately stated Haskell byte controls exercise only the bounded
-- diagnostic parser.  They neither acquire an independent component or
-- configuration universe nor read dist-newstyle or invoke Cabal, GHC, Git, or
-- a network.
data SelectorIntent = SelectorIntent String String
  deriving (Eq, Show)

-- This is the oracle-owned closed selector inventory.  The first field is the
-- literal production compile selector; the second is the literal label of the
-- exact oracle case that must turn red when that selector changes its subject.
-- A target may be shared, but the independently declared exact-case label must
-- itself occur exactly once below.
selectorIntentRegistry :: [SelectorIntent]
selectorIntentRegistry =
  [ SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PUBLIC_REFUSAL_BYPASS_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_KEY_BYPASS_MUTANT" "duplicate root keys are rejected before object normalization"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_INPUT_BYTE_LIMIT_BYPASS_MUTANT" "one byte beyond the input ceiling is refused before tokenization"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_JSON_TOKEN_LIMIT_BYPASS_MUTANT" "the first token beyond the token ceiling is refused exactly"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_PROBLEM_LIMIT_BYPASS_MUTANT" "one duplicate problem beyond the problem ceiling is refused exactly"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_JSON_DEPTH_LIMIT_BYPASS_MUTANT" "one container beyond the nesting ceiling is refused exactly"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_JSON_STRING_LIMIT_BYPASS_MUTANT" "one decoded character beyond the text ceiling is refused exactly"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_JSON_KEY_LIMIT_BYPASS_MUTANT" "one code point beyond the JSON key-text ceiling is refused before decoding"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_JSON_ARRAY_LIMIT_BYPASS_MUTANT" "one element beyond the collection ceiling is refused exactly"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_JSON_OBJECT_LIMIT_BYPASS_MUTANT" "one generic object member beyond the ceiling is refused before decoding"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_LIMIT_BYPASS_MUTANT" "one install unit beyond the unit ceiling is refused before unit traversal"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_LIMIT_BYPASS_MUTANT" "one component beyond the component ceiling is refused before member traversal"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_LIMIT_BYPASS_MUTANT" "one dependency beyond the dependency ceiling is refused before edge traversal"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_FLAG_LIMIT_BYPASS_MUTANT" "one flag beyond the flag ceiling is refused before flag traversal"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_MEMBER_LIMIT_BYPASS_MUTANT" "one source-object member beyond the ceiling is refused before source traversal"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_SEMANTIC_PROBLEM_LIMIT_BYPASS_MUTANT" "one semantic problem beyond the ceiling refuses before further traversal"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_SEMANTIC_BYTE_LIMIT_BYPASS_MUTANT" "one semantic-scalar byte beyond the ceiling is refused at the exact flag key"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_BYTE_LIMIT_BYPASS_MUTANT" "one source-locator byte beyond the ceiling is refused at the locator locus"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PATH_BYTE_LIMIT_BYPASS_MUTANT" "one path byte beyond the ceiling is refused at the path locus"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PATH_SEGMENT_LIMIT_BYPASS_MUTANT" "one path segment beyond the ceiling is refused at the path locus"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PATH_SEGMENT_BYTE_LIMIT_BYPASS_MUTANT" "one path-member byte beyond the ceiling is refused at the path locus"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_DIRECT_COMPONENT_COUNT_DROP_MUTANT" "the aggregate component ceiling counts direct components across unit boundaries before rendering"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_MAP_COUNT_DROP_MUTANT" "one component beyond the component ceiling is refused before member traversal"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_ROOT_DEPENDS_COUNT_DROP_MUTANT" "one dependency beyond the dependency ceiling is refused before edge traversal"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_ROOT_EXECUTABLE_DEPENDS_COUNT_DROP_MUTANT" "the aggregate dependency ceiling counts root executable edges before traversal"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_NESTED_DEPENDS_COUNT_DROP_MUTANT" "the aggregate dependency ceiling counts nested ordinary edges before traversal"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_NESTED_EXECUTABLE_DEPENDS_COUNT_DROP_MUTANT" "the aggregate dependency ceiling counts nested executable edges before traversal"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_FLAG_COUNT_DROP_MUTANT" "one flag beyond the flag ceiling is refused before flag traversal"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_INSTALL_UNIT_TYPE_BYPASS_MUTANT" "an unsupported install-unit discriminator is exact"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_CABAL_SCHEMA_VERSION_BYPASS_MUTANT" "the Cabal schema version is an exact closed alternative"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_CABAL_LIBRARY_SCHEMA_VERSION_BYPASS_MUTANT" "the Cabal library schema version is an independently exact closed alternative"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_ACCEPTED_FIELD_BINDING_MUTANT" "the local build-info and dist-directory paths remain exact diagnostic values"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_AGGREGATE_DEPENDS_GUARD_BYPASS_MUTANT" "aggregate units reject a top-level ordinary dependency instead of ignoring it"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_AGGREGATE_EXECUTABLE_DEPENDS_GUARD_BYPASS_MUTANT" "aggregate units reject a top-level executable dependency instead of ignoring it"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_BUILD_INFO_PRESENCE_BYPASS_MUTANT" "an inplace configured unit without its build-info path is refused"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_DIST_DIRECTORY_PRESENCE_BYPASS_MUTANT" "a local configured unit without its dist directory is refused"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_GLOBAL_BUILD_INFO_GUARD_BYPASS_MUTANT" "a global library rejects an impossible local build-info path"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_GLOBAL_DIST_DIRECTORY_GUARD_BYPASS_MUTANT" "a global unit independently forbids a dist-directory path"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_BINARY_PATH_PRESENCE_BYPASS_MUTANT" "an executable requires its retained binary path"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_NON_BINARY_PATH_GUARD_BYPASS_MUTANT" "a library rejects an unexpected binary path"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_SHAPE_PRESENCE_BYPASS_MUTANT" "a configured unit must state one component shape"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_SHAPE_AMBIGUITY_BYPASS_MUTANT" "configured units cannot present both direct and aggregate component shapes"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_SOURCE_TYPE_BYPASS_MUTANT" "an unsupported package-source discriminator is exact"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TYPE_BYPASS_MUTANT" "repository-tar accepts only the frozen secure-repo subtype"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_REPOSITORY_TYPE_BYPASS_MUTANT" "source-repo accepts only the frozen Git subtype"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_ORIGIN_MISMATCH_BYPASS_MUTANT" "a local source cannot claim the global build style"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_REMOTE_ORIGIN_MISMATCH_BYPASS_MUTANT" "changing a local source declaration to a remote package type cannot retain local style"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_CONFIGURED_STYLE_BYPASS_MUTANT" "an unsupported configured style is exact"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_CYCLE_GUARD_BYPASS_MUTANT" "a two-unit dependency cycle is refused as one closed identity set"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_DEPENDENCY_GUARD_BYPASS_MUTANT" "a duplicate ordinary dependency remains an exact edge-locus defect"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_SELF_DEPENDENCY_GUARD_BYPASS_MUTANT" "a self dependency is both the exact edge defect and a unit cycle"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_UNKNOWN_DEPENDENCY_GUARD_BYPASS_MUTANT" "a dependency swap to an absent unit id cannot remain a closed graph"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_PATH_RESIDUE_DROP_MUTANT" "the exact observed-result ceiling retains fifteen mandatory refusals and 113 exact source-path rows"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_INPUT_AUTHENTICATION_RESIDUE_BYPASS_MUTANT" "the exact observed-result ceiling retains fifteen mandatory refusals and 113 exact source-path rows"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_ARTIFACT_GENERATION_RESIDUE_BYPASS_MUTANT" "the exact observed-result ceiling retains fifteen mandatory refusals and 113 exact source-path rows"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_EXPECTED_COMPILER_IDENTITY_RESIDUE_BYPASS_MUTANT" "the exact observed-result ceiling retains fifteen mandatory refusals and 113 exact source-path rows"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_EXPECTED_PLATFORM_IDENTITY_RESIDUE_BYPASS_MUTANT" "the exact observed-result ceiling retains fifteen mandatory refusals and 113 exact source-path rows"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_KEY_OBSERVATION_RESIDUE_BYPASS_MUTANT" "the exact observed-result ceiling retains fifteen mandatory refusals and 113 exact source-path rows"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNIVERSE_RESIDUE_BYPASS_MUTANT" "the exact observed-result ceiling retains fifteen mandatory refusals and 113 exact source-path rows"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_CONFIGURATION_BRANCH_CLOSURE_RESIDUE_BYPASS_MUTANT" "the exact observed-result ceiling retains fifteen mandatory refusals and 113 exact source-path rows"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_CPP_BRANCH_CLOSURE_RESIDUE_BYPASS_MUTANT" "the exact observed-result ceiling retains fifteen mandatory refusals and 113 exact source-path rows"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_SEMANTICS_RESIDUE_BYPASS_MUTANT" "the exact observed-result ceiling retains fifteen mandatory refusals and 113 exact source-path rows"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_SOURCE_BYTES_IDENTITY_RESIDUE_BYPASS_MUTANT" "the exact observed-result ceiling retains fifteen mandatory refusals and 113 exact source-path rows"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_BUILD_ARTIFACT_PATH_IDENTITY_RESIDUE_BYPASS_MUTANT" "the exact observed-result ceiling retains fifteen mandatory refusals and 113 exact source-path rows"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_ROOT_LEXICAL_RESIDUE_BYPASS_MUTANT" "the exact observed-result ceiling retains fifteen mandatory refusals and 113 exact source-path rows"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_ROOT_FILESYSTEM_RESIDUE_BYPASS_MUTANT" "the exact observed-result ceiling retains fifteen mandatory refusals and 113 exact source-path rows"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_SNAPSHOT_BINDING_RESIDUE_BYPASS_MUTANT" "the exact observed-result ceiling retains fifteen mandatory refusals and 113 exact source-path rows"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_DIAGNOSTIC_RESIDUE_BYPASS_MUTANT" "the exact observed-result ceiling retains fifteen mandatory refusals and 113 exact source-path rows"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_CABAL_HASH_GUARD_BYPASS_MUTANT" "a local source independently forbids a claimed Cabal hash"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_HASH_GUARD_BYPASS_MUTANT" "local sources reject an unexpected claimed source hash"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_SOURCE_HASH_PRESENCE_BYPASS_MUTANT" "a missing remote source hash is explicit"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_CABAL_HASH_PRESENCE_BYPASS_MUTANT" "a missing repository Cabal hash is explicit"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_REPOSITORY_CABAL_HASH_GUARD_BYPASS_MUTANT" "source repositories reject an unexpected Cabal hash"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_REPOSITORY_HASH_PRESENCE_BYPASS_MUTANT" "a source repository independently requires its source hash"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_SHA256_WIDTH_BYPASS_MUTANT" "a SHA-256 identity rejects width 63 exactly"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_SHA256_CHARACTER_BYPASS_MUTANT" "a SHA-256 identity rejects a non-lower-hex symbol exactly"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_GIT_SHA1_WIDTH_BYPASS_MUTANT" "a Git SHA-1 identity rejects width 39 exactly"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_GIT_SHA256_WIDTH_BYPASS_MUTANT" "a Git SHA-256 identity rejects width 63 independently"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_GIT_OBJECT_CHARACTER_BYPASS_MUTANT" "a Git object identity rejects a non-lower-hex symbol exactly"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_SHAPE_COLLAPSE_MUTANT" "the aggregate component alternative has one exact ordered digest-bound public refusal"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_BUILTIN_BYPASS_MUTANT" "a component builtin is drawn from the exact closed set"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_PREFIX_BYPASS_MUTANT" "a qualified component prefix is drawn from the exact closed set"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_LEADING_BOUNDARY_BYPASS_MUTANT" "a qualified component suffix rejects a leading punctuation boundary"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_TRAILING_BOUNDARY_BYPASS_MUTANT" "a qualified component suffix rejects a trailing punctuation boundary"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_CHARACTER_BYPASS_MUTANT" "a qualified component suffix rejects an independently forbidden character"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPILER_PREFIX_BYPASS_MUTANT" "the compiler identifier prefix is exact"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PORTABLE_IDENTITY_LEADING_BOUNDARY_BYPASS_MUTANT" "a portable identity rejects a leading punctuation boundary independently"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PORTABLE_IDENTITY_TRAILING_BOUNDARY_BYPASS_MUTANT" "a portable identity rejects a trailing punctuation boundary independently"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PORTABLE_IDENTITY_CHARACTER_BYPASS_MUTANT" "a portable identity rejects an independently forbidden character"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PLATFORM_LEADING_BOUNDARY_BYPASS_MUTANT" "a platform token rejects a leading punctuation boundary independently"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PLATFORM_TRAILING_BOUNDARY_BYPASS_MUTANT" "a platform token rejects a trailing punctuation boundary independently"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PLATFORM_CHARACTER_BYPASS_MUTANT" "a platform token rejects an independently forbidden character"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_NAME_SEGMENT_BYPASS_MUTANT" "a package name rejects an empty hyphen-delimited segment"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_NAME_CHARACTER_BYPASS_MUTANT" "a package name rejects an independently forbidden segment character"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_VERSION_SEGMENT_BYPASS_MUTANT" "a package version rejects an empty decimal segment"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_VERSION_DIGIT_BYPASS_MUTANT" "a package version rejects an independently non-decimal symbol"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_FLAG_LEADING_BOUNDARY_BYPASS_MUTANT" "a flag name rejects a leading punctuation boundary independently"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_FLAG_TRAILING_BOUNDARY_BYPASS_MUTANT" "a flag name rejects a trailing punctuation boundary independently"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_FLAG_CHARACTER_BYPASS_MUTANT" "a flag name rejects an independently forbidden character"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_SCHEME_BYPASS_MUTANT" "source scheme"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_PAYLOAD_BYPASS_MUTANT" "source payload"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_LOWER_BOUND_BYPASS_MUTANT" "source lower visible-character bound"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_UPPER_BOUND_BYPASS_MUTANT" "source upper ASCII-character bound"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_BACKSLASH_BYPASS_MUTANT" "source backslash"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PATH_ABSOLUTE_BYPASS_MUTANT" "path absolute marker"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PATH_LOWER_BOUND_BYPASS_MUTANT" "path lower visible-character bound"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PATH_UPPER_BOUND_BYPASS_MUTANT" "path upper ASCII-character bound"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PATH_BACKSLASH_BYPASS_MUTANT" "path backslash"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PATH_COLON_BYPASS_MUTANT" "path colon"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PATH_EMPTY_SEGMENT_BYPASS_MUTANT" "path empty trailing segment"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PATH_PARENT_SEGMENT_BYPASS_MUTANT" "path parent segment"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PATH_DOT_POSITION_BYPASS_MUTANT" "path dot-segment position"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_MANDATORY_PREFIX_DROP_MUTANT" "the exact observed-result ceiling retains fifteen mandatory refusals and 113 exact source-path rows"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_RESULT_PROBLEM_LIMIT_BYPASS_MUTANT" "the first observed variable row beyond the result ceiling retains every mandatory refusal before one exact limit row"
  ]
    <> newSelectorIntents
    <> auditSelectorIntents
    <> routingAuditSelectorIntents

-- These are the independently declared executable exact-case labels referenced
signatureExactCaseLabels :: [String]
signatureExactCaseLabels =
  [ "the same-library public positive client observes the one exact always-refusing CheckResult"
  , "the aggregate component alternative has one exact ordered digest-bound public refusal"
  , "an install plan without a local component refuses empty discovery"
  , "a duplicate unit id is refused at the exact identity"
  , "the same source-root/component pair cannot be represented by two units"
  , "a missing compiler identity field is explicit"
  , "an unknown top-level identity field changes the closed schema"
  , "duplicate root keys are rejected before object normalization"
  , "three equal root keys retain both duplicate occurrences"
  , "duplicate flag keys are rejected at their exact nested scope"
  , "duplicate unit keys are rejected at their exact array-object scope"
  , "duplicate nested repository keys are rejected before nested object normalization"
  , "escaped-equivalent root keys are duplicate decoded identities"
  , "duplicate nested component keys retain an unambiguous quoted scope"
  , "trailing garbage cannot be hidden behind an earlier duplicate"
  , "an empty configured component map refuses discovery"
  , "component names follow the closed Cabal-plan grammar"
  , "compiler identities require the closed ghc numeric-version grammar"
  , "flag names cannot be empty or detach configuration subject identity"
  , "local source roots require the bounded absolute path grammar"
  , "aggregate units reject a top-level ordinary dependency instead of ignoring it"
  , "aggregate units reject a top-level executable dependency instead of ignoring it"
  , "configured units cannot present both direct and aggregate component shapes"
  , "aggregate nested dependencies reject duplicate edges at the component locus"
  , "aggregate nested dependencies reject unknown unit identities"
  , "aggregate nested self dependencies retain both edge and cycle defects"
  , "a duplicate ordinary dependency remains an exact edge-locus defect"
  , "a duplicate executable dependency remains distinct from an ordinary edge defect"
  , "an unknown executable dependency retains its executable-edge locus"
  , "a self dependency is both the exact edge defect and a unit cycle"
  , "a two-unit dependency cycle is refused as one closed identity set"
  , "a malformed remote source hash is one exact identity defect"
  , "a malformed repository Cabal hash is one exact identity defect"
  , "a missing remote source hash is explicit"
  , "a missing repository Cabal hash is explicit"
  , "repository-tar accepts only the frozen secure-repo subtype"
  , "source-repo accepts only the frozen Git subtype"
  , "local sources reject an unexpected claimed source hash"
  , "source repositories reject an unexpected Cabal hash"
  , "a mutable source-repository tag is not accepted as an immutable source identity"
  , "an inplace configured unit without its build-info path is refused"
  , "a local configured unit without its dist directory is refused"
  , "a global library rejects an impossible local build-info path"
  , "a library rejects an unexpected binary path"
  , "an executable requires its retained binary path"
  , "a dependency swap to an absent unit id cannot remain a closed graph"
  , "changing a local source declaration to a remote package type cannot retain local style"
  , "an unknown local compiler input is unsupported schema"
  , "an unterminated generic array retains the token-scan invalid mapping"
  , "an unterminated generic object retains the token-scan invalid mapping"
  , "an invalid root token retains the token-scan invalid mapping"
  , "a record closing token is counted at the exact global token boundary"
  , "all JSON value kinds retain their exact type names"
  , "an empty required text field is not accepted as a value"
  , "a configured unit requires its package-source object"
  , "a configured package-source field retains its object type"
  , "an empty optional path is refused before field-combination analysis"
  , "a mistyped optional path is refused before field-combination analysis"
  , "a pre-existing unit requires its dependency array"
  , "a dependency field retains its array type"
  , "an empty dependency identity retains its exact element locus"
  , "a dependency element retains its text type"
  , "a dependency identity is checked by the shared constrained-text grammar"
  , "uppercase ASCII remains an admitted portable-identity alternative"
  , "a test component independently requires its binary path"
  , "a benchmark component independently requires its binary path"
  , "multiple unknown fields retain deterministic lexical order"
  , "pre-existing unit dependencies remain projected into invariant checks"
  , "the Cabal schema version is an exact closed alternative"
  , "the Cabal library schema version is an independently exact closed alternative"
  , "the compiler identifier prefix is exact"
  , "the compiler numeric version rejects an empty segment independently"
  , "the compiler numeric version rejects a non-decimal symbol independently"
  , "a portable identity rejects a leading punctuation boundary independently"
  , "a portable identity rejects a trailing punctuation boundary independently"
  , "a portable identity rejects an independently forbidden character"
  , "a platform token rejects a leading punctuation boundary independently"
  , "a platform token rejects a trailing punctuation boundary independently"
  , "a platform token rejects an independently forbidden character"
  , "a package name rejects an empty hyphen-delimited segment"
  , "a package name rejects an independently forbidden segment character"
  , "a package version rejects an empty decimal segment"
  , "a package version rejects an independently non-decimal symbol"
  , "a flag name rejects a leading punctuation boundary independently"
  , "a flag name rejects a trailing punctuation boundary independently"
  , "a flag name rejects an independently forbidden character"
  , "a component builtin is drawn from the exact closed set"
  , "a qualified component prefix is drawn from the exact closed set"
  , "a qualified component suffix rejects a leading punctuation boundary"
  , "a qualified component suffix rejects a trailing punctuation boundary"
  , "a qualified component suffix rejects an independently forbidden character"
  , "the admitted component alternative remains exact: lib"
  , "the admitted component alternative remains exact: setup"
  , "the admitted component alternative remains exact: lib:core"
  , "the admitted component alternative remains exact: exe:tool"
  , "the admitted component alternative remains exact: test:spec"
  , "the admitted component alternative remains exact: bench:perf"
  , "an unsupported install-unit discriminator is exact"
  , "an unsupported package-source discriminator is exact"
  , "an unsupported configured style is exact"
  , "a configured unit must state one component shape"
  , "a local source cannot claim the global build style"
  , "a global unit independently forbids a dist-directory path"
  , "a local source independently forbids a claimed Cabal hash"
  , "a source repository independently requires its source hash"
  , "source scheme"
  , "source payload"
  , "source lower visible-character bound"
  , "source upper ASCII-character bound"
  , "source backslash"
  , "path absolute marker"
  , "path lower visible-character bound"
  , "path upper ASCII-character bound"
  , "path backslash"
  , "path colon"
  , "path empty trailing segment"
  , "path parent segment"
  , "path dot-segment position"
  , "the path root alternative is admitted before the independent probe refusal"
  , "the final dot-segment alternative is admitted before the independent probe refusal"
  , "a SHA-256 identity rejects width 63 exactly"
  , "a SHA-256 identity rejects a non-lower-hex symbol exactly"
  , "a Git SHA-1 identity rejects width 39 exactly"
  , "a Git SHA-256 identity rejects width 63 independently"
  , "a Git object identity rejects a non-lower-hex symbol exactly"
  , "the Git SHA-256 width alternative reaches semantic plan analysis"
  , "the exact input-byte ceiling reaches the exact decoded root refusal"
  , "one byte beyond the input ceiling is refused before tokenization"
  , "the exact nesting ceiling reaches the exact decoded root refusal"
  , "one container beyond the nesting ceiling is refused exactly"
  , "the exact decoded-text ceiling reaches the exact decoded root refusal"
  , "one decoded character beyond the text ceiling is refused exactly"
  , "the exact generic-array ceiling reaches the exact decoded root refusal"
  , "one element beyond the collection ceiling is refused exactly"
  , "the exact generic-object-member ceiling reaches the semantic problem cap"
  , "one generic object member beyond the ceiling is refused before decoding"
  , "the exact JSON key-text ceiling retains every closed-schema refusal"
  , "one code point beyond the JSON key-text ceiling is refused before decoding"
  , "exactly one million structural tokens reach the decoded root refusal"
  , "the first token beyond the token ceiling is refused exactly"
  , "the exact duplicate-problem ceiling retains every duplicate finding"
  , "one duplicate problem beyond the problem ceiling is refused exactly"
  , "the exact semantic-problem ceiling retains every exact entry locus"
  , "one semantic problem beyond the ceiling refuses before further traversal"
  , "the exact observed-result ceiling retains fifteen mandatory refusals and 113 exact source-path rows"
  , "the first observed variable row beyond the result ceiling retains every mandatory refusal before one exact limit row"
  , "the exact unit ceiling reaches the independently smaller problem ceiling"
  , "one install unit beyond the unit ceiling is refused before unit traversal"
  , "the exact component ceiling retains every exact member locus"
  , "one component beyond the component ceiling is refused before member traversal"
  , "the aggregate component ceiling counts direct components across unit boundaries before rendering"
  , "the exact dependency ceiling reaches the independently smaller problem ceiling"
  , "one dependency beyond the dependency ceiling is refused before edge traversal"
  , "the aggregate dependency ceiling counts root executable edges before traversal"
  , "the aggregate dependency ceiling counts nested ordinary edges before traversal"
  , "the aggregate dependency ceiling counts nested executable edges before traversal"
  , "the exact flag ceiling retains every exact flag-value locus"
  , "one flag beyond the flag ceiling is refused before flag traversal"
  , "the exact source-object member ceiling reaches closed-schema parsing"
  , "one source-object member beyond the ceiling is refused before source traversal"
  , "the exact semantic-scalar byte ceiling reaches the flag value-type refusal"
  , "one semantic-scalar byte beyond the ceiling is refused at the exact flag key"
  , "the exact source-locator byte ceiling reaches the independent repository-type refusal"
  , "one source-locator byte beyond the ceiling is refused at the locator locus"
  , "the exact path byte ceiling reaches the independent unknown-field refusal"
  , "one path byte beyond the ceiling is refused at the path locus"
  , "the exact path-segment ceiling reaches the independent unknown-field refusal"
  , "one path segment beyond the ceiling is refused at the path locus"
  , "the exact path-member byte ceiling reaches the independent unknown-field refusal"
  , "one path-member byte beyond the ceiling is refused at the path locus"
  ]

supplementalExactCaseLabels :: [String]
supplementalExactCaseLabels =
  [ "the local build-info and dist-directory paths remain exact diagnostic values"
  , "minimal closed-schema plan was rejected"
  , "the complete accepted semantic snapshot is independently literal and input-bound"
  , "the parser freezes both Cabal plan schema versions"
  , "compiler identity is read from the immutable plan bytes"
  , "platform retains the exact architecture and operating-system pair"
  , "missing local source ownership is precise typed residue, not an empty-path claim"
  , "the complete public diagnostic wire is exact, ordered, digest-bound, and permanently refusing"
  , "multiple flags retain deterministic lexical order"
  , "the local component and its exact dependency unit ids are retained"
  , "Cabal 3.16 plan JSON supplies no component source paths"
  , "pre-existing, remote, and local units remain distinct"
  , "every exact unit id is retained"
  , "package provenance and Cabal build style remain separate"
  , "direct component shape remains explicit instead of collapsing into an aggregate"
  , "selected local flags remain exact typed values"
  , "the remote repository location is bound separately from a local source root"
  , "the local package root is retained without normalization or invention"
  , "portable identity retains the colon character alternative"
  , "portable identity retains the dot character alternative"
  , "portable identity retains the plus character alternative"
  , "portable identity retains the hyphen character alternative"
  , "portable identity retains the underscore character alternative"
  , "platform tokens retain the hyphen character alternative"
  , "platform tokens retain the underscore character alternative"
  , "the admitted component alternative remains exact: lib:core.name"
  , "the admitted component alternative remains exact: lib:core-name"
  , "the admitted component alternative remains exact: lib:core_name"
  , "the admitted flag alternative remains exact: variant-name"
  , "the admitted flag alternative remains exact: variant_name"
  , "SHA-256 lower-hex alphabetic alternative remains admitted"
  , "SHA-256 lower-hex digit alternative remains admitted"
  , "source-repository global projection retains kind, repository type, location, and tag"
  , "source-repository inplace style remains distinct"
  , "multiple local roots retain deterministic subject order"
  ]

allExecutableExactCaseLabels :: [String]
allExecutableExactCaseLabels = signatureExactCaseLabels <> supplementalExactCaseLabels


newSelectorIntents :: [SelectorIntent]
newSelectorIntents =
  [ SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_AESON_DECODE_FAILURE_MAPPING_MUTANT" "trailing garbage cannot be hidden behind an earlier duplicate"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_ASCII_DIGIT_ALTERNATIVE_DROP_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_ASCII_LOWERCASE_ALTERNATIVE_DROP_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_ASCII_UPPERCASE_ALTERNATIVE_DROP_MUTANT" "uppercase ASCII remains an admitted portable-identity alternative"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_BINARY_BENCHMARK_CLASSIFICATION_DROP_MUTANT" "a benchmark component independently requires its binary path"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_BINARY_EXECUTABLE_CLASSIFICATION_DROP_MUTANT" "a duplicate executable dependency remains distinct from an ordinary edge defect"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_BINARY_LIBRARY_CLASSIFICATION_WIDEN_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_BINARY_TEST_CLASSIFICATION_DROP_MUTANT" "a test component independently requires its binary path"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_BOOLEAN_MAP_VALUE_TYPE_ROUTE_MUTANT" "one semantic-scalar byte beyond the ceiling is refused at the exact flag key"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_BOUNDED_PROBLEM_ORDER_MUTANT" "aggregate nested self dependencies retain both edge and cycle defects"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_CHECK_NAME_MAPPING_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_DEPENDENCIES_PROJECTION_DROP_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_DEPENDENCY_PROBLEM_CONTRIBUTION_DROP_MUTANT" "aggregate nested dependencies reject duplicate edges at the component locus"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_EXECUTABLE_DEPENDENCIES_PROJECTION_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_EXECUTABLE_DEPENDENCY_PROBLEM_CONTRIBUTION_DROP_MUTANT" "a duplicate executable dependency remains distinct from an ordinary edge defect"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_NAME_PROJECTION_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_ORDER_MUTANT" "the exact observed-result ceiling retains fifteen mandatory refusals and 113 exact source-path rows"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_SOURCE_PATHS_PROJECTION_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNIT_ID_PROJECTION_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_CONSTRAINED_ARRAY_VALUE_GATE_BYPASS_MUTANT" "a dependency identity is checked by the shared constrained-text grammar"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_CONSTRAINED_PATH_VALUE_GATE_BYPASS_MUTANT" "local source roots require the bounded absolute path grammar"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_CONSTRAINED_TEXT_VALUE_GATE_BYPASS_MUTANT" "compiler identities require the closed ghc numeric-version grammar"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_ARRAY_ELEMENT_TYPE_ROUTE_MUTANT" "a dependency element retains its text type"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_ARRAY_EMPTY_TEXT_ROUTE_MUTANT" "an empty dependency identity retains its exact element locus"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_ARRAY_MISSING_ROUTE_MUTANT" "a pre-existing unit requires its dependency array"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_ARRAY_TYPE_ROUTE_MUTANT" "a dependency field retains its array type"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_CYCLE_PROBLEM_CONTRIBUTION_DROP_MUTANT" "aggregate nested self dependencies retain both edge and cycle defects"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_PROBLEM_CONTRIBUTION_DROP_MUTANT" "aggregate nested dependencies reject duplicate edges at the component locus"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_GROUPING_BYPASS_MUTANT" "a duplicate unit id is refused at the exact identity"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_LOCAL_COMPONENT_PROBLEM_CONTRIBUTION_DROP_MUTANT" "the same source-root/component pair cannot be represented by two units"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_UNIT_PROBLEM_CONTRIBUTION_DROP_MUTANT" "a duplicate unit id is refused at the exact identity"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_EMPTY_COMPONENT_MAP_GUARD_BYPASS_MUTANT" "an empty configured component map refuses discovery"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_FINDING_CODE_MAPPING_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_FINDING_DETAIL_MAPPING_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_FINDING_ORDER_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_FINDING_SUBJECT_MAPPING_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_FLAG_ORDER_MUTANT" "multiple flags retain deterministic lexical order"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_GLOBAL_LOCAL_DISCOVERY_GUARD_BYPASS_MUTANT" "an install plan without a local component refuses empty discovery"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_GROUPED_VALUE_RENDER_DROP_MUTANT" "the same source-root/component pair cannot be represented by two units"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_INPUT_BYTES_OBSERVATION_KEY_MAPPING_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_INPUT_BYTES_OBSERVATION_VALUE_MAPPING_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_INPUT_DIGEST_OBSERVATION_KEY_MAPPING_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_INPUT_DIGEST_OBSERVATION_VALUE_MAPPING_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_INSTALL_UNIT_NON_OBJECT_MAPPING_MUTANT" "the exact semantic-problem ceiling retains every exact entry locus"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_INSTALL_UNIT_OBJECT_ROUTE_DROP_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_JSON_ARRAY_DEPTH_ROUTE_MUTANT" "one container beyond the nesting ceiling is refused exactly"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_JSON_ARRAY_END_TOKEN_COUNT_DROP_MUTANT" "a record closing token is counted at the exact global token boundary"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_JSON_ARRAY_ERROR_ROUTE_MUTANT" "an unterminated generic array retains the token-scan invalid mapping"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_JSON_ARRAY_ITEM_TOKEN_COUNT_DROP_MUTANT" "a record closing token is counted at the exact global token boundary"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_JSON_ARRAY_TYPE_MAPPING_MUTANT" "all JSON value kinds retain their exact type names"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_JSON_BOOLEAN_TYPE_MAPPING_MUTANT" "all JSON value kinds retain their exact type names"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_JSON_FIELD_PATH_APPEND_DROP_MUTANT" "duplicate flag keys are rejected at their exact nested scope"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_JSON_FIELD_PATH_RENDER_MUTANT" "duplicate flag keys are rejected at their exact nested scope"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_JSON_FIELD_SCOPE_MAPPING_MUTANT" "flag names cannot be empty or detach configuration subject identity"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_JSON_INDEX_PATH_APPEND_DROP_MUTANT" "duplicate flag keys are rejected at their exact nested scope"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_JSON_INDEX_PATH_RENDER_MUTANT" "duplicate flag keys are rejected at their exact nested scope"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_JSON_INVALID_FAILURE_MAPPING_MUTANT" "an unterminated generic array retains the token-scan invalid mapping"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_JSON_LITERAL_TOKEN_ROUTE_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_JSON_NULL_TYPE_MAPPING_MUTANT" "all JSON value kinds retain their exact type names"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_JSON_NUMBER_TOKEN_ROUTE_MUTANT" "all JSON value kinds retain their exact type names"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_JSON_NUMBER_TYPE_MAPPING_MUTANT" "all JSON value kinds retain their exact type names"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_JSON_OBJECT_TYPE_MAPPING_MUTANT" "all JSON value kinds retain their exact type names"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RECORD_DEPTH_ROUTE_MUTANT" "one container beyond the nesting ceiling is refused exactly"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RECORD_END_TOKEN_COUNT_DROP_MUTANT" "a record closing token is counted at the exact global token boundary"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RECORD_ERROR_ROUTE_MUTANT" "an unterminated generic object retains the token-scan invalid mapping"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RECORD_PAIR_TOKEN_COUNT_DROP_MUTANT" "a record closing token is counted at the exact global token boundary"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RESOURCE_FAILURE_LABEL_MAPPING_MUTANT" "a record closing token is counted at the exact global token boundary"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RESOURCE_FAILURE_LIMIT_MAPPING_MUTANT" "a record closing token is counted at the exact global token boundary"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RESOURCE_FAILURE_OBSERVED_MAPPING_MUTANT" "a record closing token is counted at the exact global token boundary"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_JSON_STRING_TYPE_MAPPING_MUTANT" "all JSON value kinds retain their exact type names"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_JSON_TEXT_TOKEN_ROUTE_MUTANT" "one decoded character beyond the text ceiling is refused exactly"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_JSON_TOKEN_ERROR_ROUTE_MUTANT" "an invalid root token retains the token-scan invalid mapping"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_DISCOVERY_PROBLEM_CONTRIBUTION_DROP_MUTANT" "an install plan without a local component refuses empty discovery"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_MALFORMED_FOLD_DIGEST_PROJECTION_MUTANT" "an install plan without a local component refuses empty discovery"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_NESTED_COMPONENT_NON_OBJECT_MAPPING_MUTANT" "the exact component ceiling retains every exact member locus"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_NESTED_COMPONENT_OBJECT_ROUTE_DROP_MUTANT" "the aggregate component alternative has one exact ordered digest-bound public refusal"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_UNIT_ORDER_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_OPTIONAL_TEXT_EMPTY_ROUTE_MUTANT" "an empty optional path is refused before field-combination analysis"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_OPTIONAL_TEXT_MISSING_ROUTE_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_OPTIONAL_TEXT_TYPE_ROUTE_MUTANT" "a mistyped optional path is refused before field-combination analysis"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PARSED_PROBLEMS_PROJECTION_DROP_MUTANT" "a missing compiler identity field is explicit"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PARSED_VALUE_PROJECTION_DROP_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PARTITION_PROBLEM_CONTRIBUTION_DROP_MUTANT" "an empty configured component map refuses discovery"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PARTITION_VALUE_CONTRIBUTION_DROP_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_REFUSAL_DIGEST_PROJECTION_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_REFUSAL_INPUT_BYTES_PROJECTION_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_REFUSAL_PROBLEM_ORDER_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_REFUSAL_SNAPSHOT_PROJECTION_DROP_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_OBJECT_MISSING_ROUTE_MUTANT" "a configured unit requires its package-source object"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_OBJECT_TYPE_ROUTE_MUTANT" "a configured package-source field retains its object type"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_TEXT_EMPTY_ROUTE_MUTANT" "an empty required text field is not accepted as a value"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_TEXT_MISSING_ROUTE_MUTANT" "a missing compiler identity field is explicit"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_TEXT_TYPE_ROUTE_MUTANT" "all JSON value kinds retain their exact type names"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_UNIT_ARRAY_MISSING_ROUTE_MUTANT" "the exact JSON key-text ceiling retains every closed-schema refusal"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_UNIT_ARRAY_TYPE_ROUTE_MUTANT" "all JSON value kinds retain their exact type names"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_ROOT_NON_OBJECT_MAPPING_MUTANT" "the exact input-byte ceiling reaches the exact decoded root refusal"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_ROOT_OBJECT_ROUTE_DROP_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_ROOT_OBSERVATION_KEY_MAPPING_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_ROOT_OBSERVATION_VALUE_MAPPING_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_SHA256_HEX_ALPHA_MAPPING_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_SHA256_HIGH_NIBBLE_MAPPING_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_SHA256_LOW_NIBBLE_MAPPING_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_STATUS_OBSERVATION_KEY_MAPPING_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_STATUS_OBSERVATION_VALUE_MAPPING_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_SUBJECT_OBSERVATION_CONTRIBUTION_DROP_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_BINARY_PATH_PROJECTION_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_BUILD_INFO_PATH_PROJECTION_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_BUILD_STYLE_PROJECTION_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_CABAL_SHA256_PROJECTION_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_COMPONENTS_PROJECTION_DROP_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_COMPONENT_SHAPE_PROJECTION_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_DEPENDENCIES_PROJECTION_DROP_MUTANT" "pre-existing unit dependencies remain projected into invariant checks"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_DEPENDENCY_PROBLEM_CONTRIBUTION_DROP_MUTANT" "pre-existing unit dependencies remain projected into invariant checks"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_DIST_DIRECTORY_PATH_PROJECTION_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_FLAGS_PROJECTION_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_ID_PROJECTION_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_OBSERVATION_KEY_MAPPING_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_OBSERVATION_ORDER_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_OBSERVATION_VALUE_MAPPING_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_ORDER_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_ORIGIN_PROJECTION_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_PACKAGE_NAME_PROJECTION_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_PACKAGE_VERSION_PROJECTION_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_REPOSITORY_TYPE_PROJECTION_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_SOURCE_KIND_PROJECTION_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_SOURCE_LOCATION_PROJECTION_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_SOURCE_ROOT_PROJECTION_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_SOURCE_SHA256_PROJECTION_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_SOURCE_TAG_PROJECTION_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_UNKNOWN_FIELD_DETECTION_BYPASS_MUTANT" "an unknown top-level identity field changes the closed schema"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_UNKNOWN_FIELD_ORDER_MUTANT" "multiple unknown fields retain deterministic lexical order"
  ]


newSelectorImpactSignatures :: [(String, String)]
newSelectorImpactSignatures =
  [ ("VALIDATION_COMPILER_ELABORATED_PLAN_AESON_DECODE_FAILURE_MAPPING_MUTANT", "00000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ASCII_DIGIT_ALTERNATIVE_DROP_MUTANT", "11111110000000011111111111111111111111111111111100001111111111111111111111111111111111111111111111111111111111111111111111111100000000000000001111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ASCII_LOWERCASE_ALTERNATIVE_DROP_MUTANT", "11111110000000011111111111111111111111111111111100001111111111111111111111111111111111111111111111111111111111111111111111111100000000000000001111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ASCII_UPPERCASE_ALTERNATIVE_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BINARY_BENCHMARK_CLASSIFICATION_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BINARY_EXECUTABLE_CLASSIFICATION_DROP_MUTANT", "00000000000000000000000000011000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BINARY_LIBRARY_CLASSIFICATION_WIDEN_MUTANT", "10111000000000000000000000100111111001111111011100000000110000000000000000000001111000000000000001010111100000000000001111111100000000000000000000000001000000000000101010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BINARY_TEST_CLASSIFICATION_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BOOLEAN_MAP_VALUE_TYPE_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111110000000000000000000000000000000000000000000000000000000000010001100000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BOUNDED_PROBLEM_ORDER_MUTANT", "00000000000000000000000001000100000000000000000000001000000000000011000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CHECK_NAME_MAPPING_MUTANT", "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_DEPENDENCIES_PROJECTION_DROP_MUTANT", "11000000000000000000000111100110000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_DEPENDENCY_PROBLEM_CONTRIBUTION_DROP_MUTANT", "00000000000000000000000111100100000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_EXECUTABLE_DEPENDENCIES_PROJECTION_MUTANT", "11111000000000000000000111111110000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_EXECUTABLE_DEPENDENCY_PROBLEM_CONTRIBUTION_DROP_MUTANT", "00000000000000000000000000011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_NAME_PROJECTION_MUTANT", "11001000000000000000000111111100000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_ORDER_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_SOURCE_PATHS_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNIT_ID_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CONSTRAINED_ARRAY_VALUE_GATE_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CONSTRAINED_PATH_VALUE_GATE_BYPASS_MUTANT", "00000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111111110000000000000000000000000000000000000000000000010101")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CONSTRAINED_TEXT_VALUE_GATE_BYPASS_MUTANT", "00000000000000000100000000000000000000000000000000000000000000000000001111111111111000000000000000000000011111000000000000000000000000000000000000000000000000000001000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_ARRAY_ELEMENT_TYPE_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_ARRAY_EMPTY_TEXT_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_ARRAY_MISSING_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_ARRAY_TYPE_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_CYCLE_PROBLEM_CONTRIBUTION_DROP_MUTANT", "00000000000000000000000001000110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_PROBLEM_CONTRIBUTION_DROP_MUTANT", "00000000000000000000000111111100000000000000010000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_GROUPING_BYPASS_MUTANT", "00010000000000000000000100110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_LOCAL_COMPONENT_PROBLEM_CONTRIBUTION_DROP_MUTANT", "00001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_UNIT_PROBLEM_CONTRIBUTION_DROP_MUTANT", "00010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_EMPTY_COMPONENT_MAP_GUARD_BYPASS_MUTANT", "00000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_FINDING_CODE_MAPPING_MUTANT", "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_FINDING_DETAIL_MAPPING_MUTANT", "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_FINDING_ORDER_MUTANT", "11000000000000000000000001000100000000000000000000001000110000000011000000000000000000000000000000000000011111000000000000000000000000001000001011001000000010000101010101")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_FINDING_SUBJECT_MAPPING_MUTANT", "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_FLAG_ORDER_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_GLOBAL_LOCAL_DISCOVERY_GUARD_BYPASS_MUTANT", "00100000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_GROUPED_VALUE_RENDER_DROP_MUTANT", "00001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_INPUT_BYTES_OBSERVATION_KEY_MAPPING_MUTANT", "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_INPUT_BYTES_OBSERVATION_VALUE_MAPPING_MUTANT", "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_INPUT_DIGEST_OBSERVATION_KEY_MAPPING_MUTANT", "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_INPUT_DIGEST_OBSERVATION_VALUE_MAPPING_MUTANT", "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_INSTALL_UNIT_NON_OBJECT_MAPPING_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_INSTALL_UNIT_OBJECT_ROUTE_DROP_MUTANT", "11111000000000011011111111111111111111111111111100000011111111111101000000000001111111111111111111111111111111111111111111111100000000000000000011001001000010111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_ARRAY_DEPTH_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_ARRAY_END_TOKEN_COUNT_DROP_MUTANT", "00000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_ARRAY_ERROR_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_ARRAY_ITEM_TOKEN_COUNT_DROP_MUTANT", "00000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_ARRAY_TYPE_MAPPING_MUTANT", "00000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_BOOLEAN_TYPE_MAPPING_MUTANT", "00000000000000000000000000000000000000000000000000001001010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_FIELD_PATH_APPEND_DROP_MUTANT", "00000000011101000011110000000000000111101111100100000011111111111100000000000001111111000001111110000011011111111111111100000000000000000000001000001000000010101111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_FIELD_PATH_RENDER_MUTANT", "00000000011101000011110000000000000111101111100100000011111111111100000000000001111111000001111110000011011111111111111100000000000000000000001000001000000010101111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_FIELD_SCOPE_MAPPING_MUTANT", "00000000000000000011000000000000000110000000000000000000000000000000000000000000000111000001111110000000011111111111110000000000000000000000000000001000000010101111010101")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_INDEX_PATH_APPEND_DROP_MUTANT", "00000000011101000011110000000000000111101111100100000011111111111100000000000001111111000001111110000011011111111111111100000000000000000000001000001000000010101111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_INDEX_PATH_RENDER_MUTANT", "00000000011101000011110000000000000111101111100100000011111111111100000000000001111111000001111110000011011111111111111100000000000000000000001000001000000010101111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_INVALID_FAILURE_MAPPING_MUTANT", "00000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_LITERAL_TOKEN_ROUTE_MUTANT", "11011111110010101111001000100110000001000001010100011001010101010010111111111111111111111111111111110001000000000000001100000010100011111011111100111101100011111100111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_NULL_TYPE_MAPPING_MUTANT", "00000000000000000000000000000000000000000000000000001000000000000000000000000000000000000001111110000000000000000000000000000000000000000000000000000000000010001100000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_NUMBER_TOKEN_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_NUMBER_TYPE_MAPPING_MUTANT", "00000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_OBJECT_TYPE_MAPPING_MUTANT", "00000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RECORD_DEPTH_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RECORD_END_TOKEN_COUNT_DROP_MUTANT", "00000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RECORD_ERROR_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RECORD_PAIR_TOKEN_COUNT_DROP_MUTANT", "00000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RESOURCE_FAILURE_LABEL_MAPPING_MUTANT", "00000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000010101010101010000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RESOURCE_FAILURE_LIMIT_MAPPING_MUTANT", "00000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000010101010101010000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RESOURCE_FAILURE_OBSERVED_MAPPING_MUTANT", "00000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000010101010101010000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_STRING_TYPE_MAPPING_MUTANT", "00000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_TEXT_TOKEN_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_TOKEN_ERROR_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_DISCOVERY_PROBLEM_CONTRIBUTION_DROP_MUTANT", "00100000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_MALFORMED_FOLD_DIGEST_PROJECTION_MUTANT", "00111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111110111111111111111100111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_NESTED_COMPONENT_NON_OBJECT_MAPPING_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_NESTED_COMPONENT_OBJECT_ROUTE_DROP_MUTANT", "01000000000000000000110111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_UNIT_ORDER_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_OPTIONAL_TEXT_EMPTY_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_OPTIONAL_TEXT_MISSING_ROUTE_MUTANT", "11111000000000011011111111100111111111111110111100000011110000001100000000000001111111111111110001111111111111111111111111111100000000000000000011001001000010111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_OPTIONAL_TEXT_TYPE_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PARSED_PROBLEMS_PROJECTION_DROP_MUTANT", "00000100000000011111111000000001111111111111101100001111111111111100001111111111111111111111111111111111111111111111111111111000000000001000001100111000000010111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PARSED_VALUE_PROJECTION_DROP_MUTANT", "11111000000000011011111111111111111111111111111100000011111111111101110000000001111111111111111111111111111111111111111111111100000000000000001111101111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PARTITION_PROBLEM_CONTRIBUTION_DROP_MUTANT", "00000000000000011011111000000001111111111111101100000011111111111100000000000001111111111111111111111111111111111111111111111000000000000000001100101000000010111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PARTITION_VALUE_CONTRIBUTION_DROP_MUTANT", "11011000000000000000000111111110000000000000010000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000011000001000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REFUSAL_DIGEST_PROJECTION_MUTANT", "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111110111111111111111111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REFUSAL_INPUT_BYTES_PROJECTION_MUTANT", "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REFUSAL_PROBLEM_ORDER_MUTANT", "11000000000000000000000001000100000000000000000000001000110000000011000000000000000000000000000000000000011111000000000000000000000000001000001011001000000010000101010101")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REFUSAL_SNAPSHOT_PROJECTION_DROP_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_OBJECT_MISSING_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_OBJECT_TYPE_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_TEXT_EMPTY_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_TEXT_MISSING_ROUTE_MUTANT", "00000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_TEXT_TYPE_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_UNIT_ARRAY_MISSING_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_UNIT_ARRAY_TYPE_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ROOT_NON_OBJECT_MAPPING_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010101010000010000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ROOT_OBJECT_ROUTE_DROP_MUTANT", "11111110000000011111111111111111111111111111111100001111111111111111111111111111111111111111111111111111111111111111111111111100000000101000001111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ROOT_OBSERVATION_KEY_MAPPING_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ROOT_OBSERVATION_VALUE_MAPPING_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SHA256_HEX_ALPHA_MAPPING_MUTANT", "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111110111111111111111111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SHA256_HIGH_NIBBLE_MAPPING_MUTANT", "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111110111111111111111111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SHA256_LOW_NIBBLE_MAPPING_MUTANT", "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111110111111111111111111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_STATUS_OBSERVATION_KEY_MAPPING_MUTANT", "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_STATUS_OBSERVATION_VALUE_MAPPING_MUTANT", "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SUBJECT_OBSERVATION_CONTRIBUTION_DROP_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_BINARY_PATH_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_BUILD_INFO_PATH_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_BUILD_STYLE_PROJECTION_MUTANT", "11011000000000000000000111111110000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_CABAL_SHA256_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_COMPONENTS_PROJECTION_DROP_MUTANT", "11011000000000000000000111111110000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000001000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_COMPONENT_SHAPE_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_DEPENDENCIES_PROJECTION_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_DEPENDENCY_PROBLEM_CONTRIBUTION_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_DIST_DIRECTORY_PATH_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_FLAGS_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_ID_PROJECTION_MUTANT", "11111000000000000000000111111110000000000000010000000000000000000001000000000000000000000000000000000000000000000000000000000100000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_OBSERVATION_KEY_MAPPING_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_OBSERVATION_ORDER_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_OBSERVATION_VALUE_MAPPING_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_ORDER_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_ORIGIN_PROJECTION_MUTANT", "11001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_PACKAGE_NAME_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_PACKAGE_VERSION_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_REPOSITORY_TYPE_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_SOURCE_KIND_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_SOURCE_LOCATION_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_SOURCE_ROOT_PROJECTION_MUTANT", "11001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_SOURCE_SHA256_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_SOURCE_TAG_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNKNOWN_FIELD_DETECTION_BYPASS_MUTANT", "00000010000000000000000000000000000000000000000100000000000000010010000000000000000000000000000000000000000000000000001100000000000000101000000000000000000000100000111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNKNOWN_FIELD_ORDER_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  ]


newSelectorSupplementalImpactSignatures :: [(String, String)]
newSelectorSupplementalImpactSignatures =
  [ ("VALIDATION_COMPILER_ELABORATED_PLAN_AESON_DECODE_FAILURE_MAPPING_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ASCII_DIGIT_ALTERNATIVE_DROP_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ASCII_LOWERCASE_ALTERNATIVE_DROP_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ASCII_UPPERCASE_ALTERNATIVE_DROP_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BINARY_BENCHMARK_CLASSIFICATION_DROP_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BINARY_EXECUTABLE_CLASSIFICATION_DROP_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BINARY_LIBRARY_CLASSIFICATION_WIDEN_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BINARY_TEST_CLASSIFICATION_DROP_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BOOLEAN_MAP_VALUE_TYPE_ROUTE_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BOUNDED_PROBLEM_ORDER_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CHECK_NAME_MAPPING_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_DEPENDENCIES_PROJECTION_DROP_MUTANT", "001110100000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_DEPENDENCY_PROBLEM_CONTRIBUTION_DROP_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_EXECUTABLE_DEPENDENCIES_PROJECTION_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_EXECUTABLE_DEPENDENCY_PROBLEM_CONTRIBUTION_DROP_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_NAME_PROJECTION_MUTANT", "001110100000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_ORDER_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_SOURCE_PATHS_PROJECTION_MUTANT", "001110010000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNIT_ID_PROJECTION_MUTANT", "001110100000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CONSTRAINED_ARRAY_VALUE_GATE_BYPASS_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CONSTRAINED_PATH_VALUE_GATE_BYPASS_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CONSTRAINED_TEXT_VALUE_GATE_BYPASS_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_ARRAY_ELEMENT_TYPE_ROUTE_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_ARRAY_EMPTY_TEXT_ROUTE_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_ARRAY_MISSING_ROUTE_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_ARRAY_TYPE_ROUTE_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_CYCLE_PROBLEM_CONTRIBUTION_DROP_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_PROBLEM_CONTRIBUTION_DROP_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_GROUPING_BYPASS_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_LOCAL_COMPONENT_PROBLEM_CONTRIBUTION_DROP_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_UNIT_PROBLEM_CONTRIBUTION_DROP_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_EMPTY_COMPONENT_MAP_GUARD_BYPASS_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_FINDING_CODE_MAPPING_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_FINDING_DETAIL_MAPPING_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_FINDING_ORDER_MUTANT", "000110000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_FINDING_SUBJECT_MAPPING_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_FLAG_ORDER_MUTANT", "000001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_GLOBAL_LOCAL_DISCOVERY_GUARD_BYPASS_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_GROUPED_VALUE_RENDER_DROP_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_INPUT_BYTES_OBSERVATION_KEY_MAPPING_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_INPUT_BYTES_OBSERVATION_VALUE_MAPPING_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_INPUT_DIGEST_OBSERVATION_KEY_MAPPING_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_INPUT_DIGEST_OBSERVATION_VALUE_MAPPING_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_INSTALL_UNIT_NON_OBJECT_MAPPING_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_INSTALL_UNIT_OBJECT_ROUTE_DROP_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_ARRAY_DEPTH_ROUTE_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_ARRAY_END_TOKEN_COUNT_DROP_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_ARRAY_ERROR_ROUTE_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_ARRAY_ITEM_TOKEN_COUNT_DROP_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_ARRAY_TYPE_MAPPING_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_BOOLEAN_TYPE_MAPPING_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_FIELD_PATH_APPEND_DROP_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_FIELD_PATH_RENDER_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_FIELD_SCOPE_MAPPING_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_INDEX_PATH_APPEND_DROP_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_INDEX_PATH_RENDER_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_INVALID_FAILURE_MAPPING_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_LITERAL_TOKEN_ROUTE_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_NULL_TYPE_MAPPING_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_NUMBER_TOKEN_ROUTE_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_NUMBER_TYPE_MAPPING_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_OBJECT_TYPE_MAPPING_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RECORD_DEPTH_ROUTE_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RECORD_END_TOKEN_COUNT_DROP_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RECORD_ERROR_ROUTE_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RECORD_PAIR_TOKEN_COUNT_DROP_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RESOURCE_FAILURE_LABEL_MAPPING_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RESOURCE_FAILURE_LIMIT_MAPPING_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RESOURCE_FAILURE_OBSERVED_MAPPING_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_STRING_TYPE_MAPPING_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_TEXT_TOKEN_ROUTE_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_TOKEN_ERROR_ROUTE_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_DISCOVERY_PROBLEM_CONTRIBUTION_DROP_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_MALFORMED_FOLD_DIGEST_PROJECTION_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_NESTED_COMPONENT_NON_OBJECT_MAPPING_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_NESTED_COMPONENT_OBJECT_ROUTE_DROP_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_UNIT_ORDER_MUTANT", "001010001111000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_OPTIONAL_TEXT_EMPTY_ROUTE_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_OPTIONAL_TEXT_MISSING_ROUTE_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_OPTIONAL_TEXT_TYPE_ROUTE_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PARSED_PROBLEMS_PROJECTION_DROP_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PARSED_VALUE_PROJECTION_DROP_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PARTITION_PROBLEM_CONTRIBUTION_DROP_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PARTITION_VALUE_CONTRIBUTION_DROP_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REFUSAL_DIGEST_PROJECTION_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REFUSAL_INPUT_BYTES_PROJECTION_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REFUSAL_PROBLEM_ORDER_MUTANT", "000110000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REFUSAL_SNAPSHOT_PROJECTION_DROP_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_OBJECT_MISSING_ROUTE_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_OBJECT_TYPE_ROUTE_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_TEXT_EMPTY_ROUTE_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_TEXT_MISSING_ROUTE_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_TEXT_TYPE_ROUTE_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_UNIT_ARRAY_MISSING_ROUTE_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_UNIT_ARRAY_TYPE_ROUTE_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ROOT_NON_OBJECT_MAPPING_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ROOT_OBJECT_ROUTE_DROP_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ROOT_OBSERVATION_KEY_MAPPING_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ROOT_OBSERVATION_VALUE_MAPPING_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SHA256_HEX_ALPHA_MAPPING_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SHA256_HIGH_NIBBLE_MAPPING_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SHA256_LOW_NIBBLE_MAPPING_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_STATUS_OBSERVATION_KEY_MAPPING_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_STATUS_OBSERVATION_VALUE_MAPPING_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SUBJECT_OBSERVATION_CONTRIBUTION_DROP_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_BINARY_PATH_PROJECTION_MUTANT", "101110000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_BUILD_INFO_PATH_PROJECTION_MUTANT", "101110000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_BUILD_STYLE_PROJECTION_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_CABAL_SHA256_PROJECTION_MUTANT", "001110000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_COMPONENTS_PROJECTION_DROP_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_COMPONENT_SHAPE_PROJECTION_MUTANT", "001110000001000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_DEPENDENCIES_PROJECTION_DROP_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_DEPENDENCY_PROBLEM_CONTRIBUTION_DROP_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_DIST_DIRECTORY_PATH_PROJECTION_MUTANT", "101110000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_FLAGS_PROJECTION_MUTANT", "001111000000100")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_ID_PROJECTION_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_OBSERVATION_KEY_MAPPING_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_OBSERVATION_ORDER_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_OBSERVATION_VALUE_MAPPING_MUTANT", "010001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_ORDER_MUTANT", "001110001111000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_ORIGIN_PROJECTION_MUTANT", "101111111000111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_PACKAGE_NAME_PROJECTION_MUTANT", "001110000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_PACKAGE_VERSION_PROJECTION_MUTANT", "001110000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_REPOSITORY_TYPE_PROJECTION_MUTANT", "001110000000010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_SOURCE_KIND_PROJECTION_MUTANT", "001110000000010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_SOURCE_LOCATION_PROJECTION_MUTANT", "001110000000010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_SOURCE_ROOT_PROJECTION_MUTANT", "001110000000011")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_SOURCE_SHA256_PROJECTION_MUTANT", "001110000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_SOURCE_TAG_PROJECTION_MUTANT", "001110000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNKNOWN_FIELD_DETECTION_BYPASS_MUTANT", "000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNKNOWN_FIELD_ORDER_MUTANT", "000000000000000")
  ]

legacySelectorImpactSignatures :: [(String, String)]
legacySelectorImpactSignatures =
  [ ("VALIDATION_COMPILER_ELABORATED_PLAN_PUBLIC_REFUSAL_BYPASS_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_KEY_BYPASS_MUTANT", "00000001111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000110000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_INPUT_BYTE_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_TOKEN_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_PROBLEM_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_DEPTH_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_STRING_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_KEY_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_ARRAY_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_OBJECT_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000110000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_FLAG_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_MEMBER_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SEMANTIC_PROBLEM_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000100100001000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SEMANTIC_BYTE_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_BYTE_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PATH_BYTE_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PATH_SEGMENT_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PATH_SEGMENT_BYTE_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DIRECT_COMPONENT_COUNT_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_MAP_COUNT_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ROOT_DEPENDS_COUNT_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000110000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ROOT_EXECUTABLE_DEPENDS_COUNT_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_NESTED_DEPENDS_COUNT_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_NESTED_EXECUTABLE_DEPENDS_COUNT_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_FLAG_COUNT_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_INSTALL_UNIT_TYPE_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CABAL_SCHEMA_VERSION_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CABAL_LIBRARY_SCHEMA_VERSION_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ACCEPTED_FIELD_BINDING_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_AGGREGATE_DEPENDS_GUARD_BYPASS_MUTANT", "00000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_AGGREGATE_EXECUTABLE_DEPENDS_GUARD_BYPASS_MUTANT", "00000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_BUILD_INFO_PRESENCE_BYPASS_MUTANT", "00000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_DIST_DIRECTORY_PRESENCE_BYPASS_MUTANT", "00000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_GLOBAL_BUILD_INFO_GUARD_BYPASS_MUTANT", "00000000000000000000000000000000000000000010000000000000110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_GLOBAL_DIST_DIRECTORY_GUARD_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BINARY_PATH_PRESENCE_BYPASS_MUTANT", "00000000000000000000000000000000000000000000100000000000000000001100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_NON_BINARY_PATH_GUARD_BYPASS_MUTANT", "00000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_SHAPE_PRESENCE_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_SHAPE_AMBIGUITY_BYPASS_MUTANT", "00000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_SOURCE_TYPE_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TYPE_BYPASS_MUTANT", "00000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000011111000000000000000000000000000000000000000000000000000011000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_REPOSITORY_TYPE_BYPASS_MUTANT", "00000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_ORIGIN_MISMATCH_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REMOTE_ORIGIN_MISMATCH_BYPASS_MUTANT", "00000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CONFIGURED_STYLE_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CYCLE_GUARD_BYPASS_MUTANT", "00000000000000000000000001000110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_DEPENDENCY_GUARD_BYPASS_MUTANT", "00000000000000000000000100110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SELF_DEPENDENCY_GUARD_BYPASS_MUTANT", "00000000000000000000000001000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNKNOWN_DEPENDENCY_GUARD_BYPASS_MUTANT", "00000000000000000000000010001000000000000000010000000000000000000001000000000000000000000001111110000000000000000000000000000000000000000000000000000001000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_PATH_RESIDUE_DROP_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_INPUT_AUTHENTICATION_RESIDUE_BYPASS_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ARTIFACT_GENERATION_RESIDUE_BYPASS_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_EXPECTED_COMPILER_IDENTITY_RESIDUE_BYPASS_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_EXPECTED_PLATFORM_IDENTITY_RESIDUE_BYPASS_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_KEY_OBSERVATION_RESIDUE_BYPASS_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNIVERSE_RESIDUE_BYPASS_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CONFIGURATION_BRANCH_CLOSURE_RESIDUE_BYPASS_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CPP_BRANCH_CLOSURE_RESIDUE_BYPASS_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_SEMANTICS_RESIDUE_BYPASS_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_SOURCE_BYTES_IDENTITY_RESIDUE_BYPASS_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BUILD_ARTIFACT_PATH_IDENTITY_RESIDUE_BYPASS_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_ROOT_LEXICAL_RESIDUE_BYPASS_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_ROOT_FILESYSTEM_RESIDUE_BYPASS_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SNAPSHOT_BINDING_RESIDUE_BYPASS_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DIAGNOSTIC_RESIDUE_BYPASS_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_CABAL_HASH_GUARD_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_HASH_GUARD_BYPASS_MUTANT", "00000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_SOURCE_HASH_PRESENCE_BYPASS_MUTANT", "00000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_CABAL_HASH_PRESENCE_BYPASS_MUTANT", "00000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_REPOSITORY_CABAL_HASH_GUARD_BYPASS_MUTANT", "00000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_REPOSITORY_HASH_PRESENCE_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SHA256_WIDTH_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SHA256_CHARACTER_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_GIT_SHA1_WIDTH_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_GIT_SHA256_WIDTH_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_GIT_OBJECT_CHARACTER_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_SHAPE_COLLAPSE_MUTANT", "01000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_BUILTIN_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_PREFIX_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_LEADING_BOUNDARY_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_TRAILING_BOUNDARY_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_CHARACTER_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPILER_PREFIX_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PORTABLE_IDENTITY_LEADING_BOUNDARY_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PORTABLE_IDENTITY_TRAILING_BOUNDARY_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PORTABLE_IDENTITY_CHARACTER_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000100000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PLATFORM_LEADING_BOUNDARY_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PLATFORM_TRAILING_BOUNDARY_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PLATFORM_CHARACTER_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_NAME_SEGMENT_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_NAME_CHARACTER_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_VERSION_SEGMENT_BYPASS_MUTANT", "00000000000000000100000000000000000000000000000000000000000000000000000100000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_VERSION_DIGIT_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000010000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_FLAG_LEADING_BOUNDARY_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_FLAG_TRAILING_BOUNDARY_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_FLAG_CHARACTER_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_SCHEME_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_PAYLOAD_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_LOWER_BOUND_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_UPPER_BOUND_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_BACKSLASH_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PATH_ABSOLUTE_BYPASS_MUTANT", "00000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PATH_LOWER_BOUND_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PATH_UPPER_BOUND_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PATH_BACKSLASH_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PATH_COLON_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PATH_EMPTY_SEGMENT_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PATH_PARENT_SEGMENT_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PATH_DOT_POSITION_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_MANDATORY_PREFIX_DROP_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_RESULT_PROBLEM_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000")
  ]

legacySelectorSupplementalImpactSignatures :: [(String, String)]
legacySelectorSupplementalImpactSignatures =
  [ ("VALIDATION_COMPILER_ELABORATED_PLAN_PUBLIC_REFUSAL_BYPASS_MUTANT", "01000000100000000000000000000000111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_KEY_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_INPUT_BYTE_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_TOKEN_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_PROBLEM_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_DEPTH_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_STRING_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_KEY_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_ARRAY_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_OBJECT_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_FLAG_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_MEMBER_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SEMANTIC_PROBLEM_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SEMANTIC_BYTE_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_BYTE_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PATH_BYTE_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PATH_SEGMENT_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PATH_SEGMENT_BYTE_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DIRECT_COMPONENT_COUNT_DROP_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_MAP_COUNT_DROP_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ROOT_DEPENDS_COUNT_DROP_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ROOT_EXECUTABLE_DEPENDS_COUNT_DROP_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_NESTED_DEPENDS_COUNT_DROP_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_NESTED_EXECUTABLE_DEPENDS_COUNT_DROP_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_FLAG_COUNT_DROP_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_INSTALL_UNIT_TYPE_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CABAL_SCHEMA_VERSION_BYPASS_MUTANT", "00000000000000000000000110000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CABAL_LIBRARY_SCHEMA_VERSION_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ACCEPTED_FIELD_BINDING_MUTANT", "10100011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_AGGREGATE_DEPENDS_GUARD_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_AGGREGATE_EXECUTABLE_DEPENDS_GUARD_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_BUILD_INFO_PRESENCE_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_DIST_DIRECTORY_PRESENCE_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_GLOBAL_BUILD_INFO_GUARD_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_GLOBAL_DIST_DIRECTORY_GUARD_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BINARY_PATH_PRESENCE_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_NON_BINARY_PATH_GUARD_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_SHAPE_PRESENCE_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_SHAPE_AMBIGUITY_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_SOURCE_TYPE_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TYPE_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_REPOSITORY_TYPE_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_ORIGIN_MISMATCH_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REMOTE_ORIGIN_MISMATCH_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CONFIGURED_STYLE_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CYCLE_GUARD_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_DEPENDENCY_GUARD_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SELF_DEPENDENCY_GUARD_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNKNOWN_DEPENDENCY_GUARD_BYPASS_MUTANT", "00000000000000000000000001110000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_PATH_RESIDUE_DROP_MUTANT", "00000011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_INPUT_AUTHENTICATION_RESIDUE_BYPASS_MUTANT", "00000011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ARTIFACT_GENERATION_RESIDUE_BYPASS_MUTANT", "00000011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_EXPECTED_COMPILER_IDENTITY_RESIDUE_BYPASS_MUTANT", "00000011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_EXPECTED_PLATFORM_IDENTITY_RESIDUE_BYPASS_MUTANT", "00000011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_KEY_OBSERVATION_RESIDUE_BYPASS_MUTANT", "00000011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNIVERSE_RESIDUE_BYPASS_MUTANT", "00000011000000000000000000000000010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CONFIGURATION_BRANCH_CLOSURE_RESIDUE_BYPASS_MUTANT", "00000011000000000000000000000000010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CPP_BRANCH_CLOSURE_RESIDUE_BYPASS_MUTANT", "00000011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_SEMANTICS_RESIDUE_BYPASS_MUTANT", "00000011000000000000000000000000010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_SOURCE_BYTES_IDENTITY_RESIDUE_BYPASS_MUTANT", "00000011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BUILD_ARTIFACT_PATH_IDENTITY_RESIDUE_BYPASS_MUTANT", "00000011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_ROOT_LEXICAL_RESIDUE_BYPASS_MUTANT", "00000011000000000000000000000000001")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_ROOT_FILESYSTEM_RESIDUE_BYPASS_MUTANT", "00000011000000000000000000000000001")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SNAPSHOT_BINDING_RESIDUE_BYPASS_MUTANT", "00000011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DIAGNOSTIC_RESIDUE_BYPASS_MUTANT", "00000011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_CABAL_HASH_GUARD_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_HASH_GUARD_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_SOURCE_HASH_PRESENCE_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_CABAL_HASH_PRESENCE_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_REPOSITORY_CABAL_HASH_GUARD_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_REPOSITORY_HASH_PRESENCE_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SHA256_WIDTH_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SHA256_CHARACTER_BYPASS_MUTANT", "00000000000000000000000000000011000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_GIT_SHA1_WIDTH_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_GIT_SHA256_WIDTH_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_GIT_OBJECT_CHARACTER_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_SHAPE_COLLAPSE_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_BUILTIN_BYPASS_MUTANT", "00000000000000000000000000001100000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_PREFIX_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_LEADING_BOUNDARY_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_TRAILING_BOUNDARY_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_CHARACTER_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPILER_PREFIX_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PORTABLE_IDENTITY_LEADING_BOUNDARY_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PORTABLE_IDENTITY_TRAILING_BOUNDARY_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PORTABLE_IDENTITY_CHARACTER_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PLATFORM_LEADING_BOUNDARY_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PLATFORM_TRAILING_BOUNDARY_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PLATFORM_CHARACTER_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_NAME_SEGMENT_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_NAME_CHARACTER_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_VERSION_SEGMENT_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_VERSION_DIGIT_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_FLAG_LEADING_BOUNDARY_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_FLAG_TRAILING_BOUNDARY_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_FLAG_CHARACTER_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_SCHEME_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_PAYLOAD_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_LOWER_BOUND_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_UPPER_BOUND_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_BACKSLASH_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PATH_ABSOLUTE_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PATH_LOWER_BOUND_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PATH_UPPER_BOUND_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PATH_BACKSLASH_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PATH_COLON_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PATH_EMPTY_SEGMENT_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PATH_PARENT_SEGMENT_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PATH_DOT_POSITION_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_MANDATORY_PREFIX_DROP_MUTANT", "00000011000000000000000000000000011")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_RESULT_PROBLEM_LIMIT_BYPASS_MUTANT", "00000000000000000000000000000000000")
  ]


updatedNewSelectorImpactSignatures :: [(String, String)]
updatedNewSelectorImpactSignatures =
  [ ("VALIDATION_COMPILER_ELABORATED_PLAN_AESON_DECODE_FAILURE_MAPPING_MUTANT", "00000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ASCII_DIGIT_ALTERNATIVE_DROP_MUTANT", "11111110000000011111111111111111111111111111111100001111111111111111111111111111111111111111111111111111111111111111111111111100000000000000001111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ASCII_LOWERCASE_ALTERNATIVE_DROP_MUTANT", "11111110000000011111111111111111111111111111111100001111111111111111111111111111111111111111111111111111111111111111111111111100000000000000001111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ASCII_UPPERCASE_ALTERNATIVE_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BINARY_BENCHMARK_CLASSIFICATION_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BINARY_EXECUTABLE_CLASSIFICATION_DROP_MUTANT", "00000000000000000000000000011000000000000000100000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BINARY_LIBRARY_CLASSIFICATION_WIDEN_MUTANT", "10111000000000000000000000100111111001111111011100000000110000000000000000000001111000000001010001010111100000000000001111111100000000000000000000000001000000000000101010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BINARY_TEST_CLASSIFICATION_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BOOLEAN_MAP_VALUE_TYPE_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010001100000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BOUNDED_PROBLEM_ORDER_MUTANT", "00000000000000000000000001000100000000000000000000001000000000000011000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CHECK_NAME_MAPPING_MUTANT", "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_DEPENDENCIES_PROJECTION_DROP_MUTANT", "11000000000000000000000111100110000000000000010000000000000000000000000000000000000000000001111110000000000000000000000000000000000000000000000000000001000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_DEPENDENCY_PROBLEM_CONTRIBUTION_DROP_MUTANT", "00000000000000000000000111100100000000000000010000000000000000000000000000000000000000000001111110000000000000000000000000000000000000000000000000000001000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_EXECUTABLE_DEPENDENCIES_PROJECTION_MUTANT", "11111000000000000000000111111110000000000000010000000000000000000000000000000000000000000001111110000000000000000000000000000100000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_EXECUTABLE_DEPENDENCY_PROBLEM_CONTRIBUTION_DROP_MUTANT", "00000000000000000000000000011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_NAME_PROJECTION_MUTANT", "11001000000000000000000111111100000000000000010000000000000000000000000000000000000000000001111110000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_ORDER_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_SOURCE_PATHS_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNIT_ID_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CONSTRAINED_ARRAY_VALUE_GATE_BYPASS_MUTANT", "00000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CONSTRAINED_PATH_VALUE_GATE_BYPASS_MUTANT", "00000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111111110000000000000000000000000000000000000000000000010101")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CONSTRAINED_TEXT_VALUE_GATE_BYPASS_MUTANT", "00000000000000000100000000000000000000000000000000000000000000000000001111111111111000000000000000000000011111000000000000000000000000000000000000000000000000000001000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_ARRAY_ELEMENT_TYPE_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_ARRAY_EMPTY_TEXT_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_ARRAY_MISSING_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_ARRAY_TYPE_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_CYCLE_PROBLEM_CONTRIBUTION_DROP_MUTANT", "00000000000000000000000001000110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_PROBLEM_CONTRIBUTION_DROP_MUTANT", "00000000000000000000000111111100000000000000010000000000000000000001000000000000000000000001111110000000000000000000000000000000000000000000000000000001000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_GROUPING_BYPASS_MUTANT", "00010000000000000000000100110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_LOCAL_COMPONENT_PROBLEM_CONTRIBUTION_DROP_MUTANT", "00001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_UNIT_PROBLEM_CONTRIBUTION_DROP_MUTANT", "00010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_EMPTY_COMPONENT_MAP_GUARD_BYPASS_MUTANT", "00000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_FINDING_CODE_MAPPING_MUTANT", "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_FINDING_DETAIL_MAPPING_MUTANT", "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_FINDING_ORDER_MUTANT", "11000000000000000000000001000100000000000000000000001000110000000011000000000000000000000000000000000000011111000000000000000000000000001000001011001000000010000101010101")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_FINDING_SUBJECT_MAPPING_MUTANT", "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_FLAG_ORDER_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_GLOBAL_LOCAL_DISCOVERY_GUARD_BYPASS_MUTANT", "00100000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_GROUPED_VALUE_RENDER_DROP_MUTANT", "00001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_INPUT_BYTES_OBSERVATION_KEY_MAPPING_MUTANT", "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_INPUT_BYTES_OBSERVATION_VALUE_MAPPING_MUTANT", "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_INPUT_DIGEST_OBSERVATION_KEY_MAPPING_MUTANT", "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_INPUT_DIGEST_OBSERVATION_VALUE_MAPPING_MUTANT", "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_INSTALL_UNIT_NON_OBJECT_MAPPING_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_INSTALL_UNIT_OBJECT_ROUTE_DROP_MUTANT", "11111000000000011011111111111111111111111111111100000011111111111101000000000001111111111111111111111111111111111111111111111100000000000000000011001001000010111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_ARRAY_DEPTH_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_ARRAY_END_TOKEN_COUNT_DROP_MUTANT", "00000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_ARRAY_ERROR_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_ARRAY_ITEM_TOKEN_COUNT_DROP_MUTANT", "00000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_ARRAY_TYPE_MAPPING_MUTANT", "00000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_BOOLEAN_TYPE_MAPPING_MUTANT", "00000000000000000000000000000000000000000000000000001001010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_FIELD_PATH_APPEND_DROP_MUTANT", "00000000011101000011110000000000000111101111100100000011111111111100000000000001111111000000000000000011011111111111111100000000000000000000001000001000000010101111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_FIELD_PATH_RENDER_MUTANT", "00000000011101000011110000000000000111101111100100000011111111111100000000000001111111000000000000000011011111111111111100000000000000000000001000001000000010101111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_FIELD_SCOPE_MAPPING_MUTANT", "00000000000000000011000000000000000110000000000000000000000000000000000000000000000111000000000000000000011111111111110000000000000000000000000000001000000010101111010101")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_INDEX_PATH_APPEND_DROP_MUTANT", "00000000011101000011110000000000000111101111100100000011111111111100000000000001111111000000000000000011011111111111111100000000000000000000001000001000000010101111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_INDEX_PATH_RENDER_MUTANT", "00000000011101000011110000000000000111101111100100000011111111111100000000000001111111000000000000000011011111111111111100000000000000000000001000001000000010101111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_INVALID_FAILURE_MAPPING_MUTANT", "00000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_LITERAL_TOKEN_ROUTE_MUTANT", "11011111110010101111001000100110000001000001010100011001010101010010111111111111111111111110000001110001000000000000001100000010100011111011111100111101100011111100111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_NULL_TYPE_MAPPING_MUTANT", "00000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010001100000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_NUMBER_TOKEN_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_NUMBER_TYPE_MAPPING_MUTANT", "00000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_OBJECT_TYPE_MAPPING_MUTANT", "00000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RECORD_DEPTH_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RECORD_END_TOKEN_COUNT_DROP_MUTANT", "00000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RECORD_ERROR_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RECORD_PAIR_TOKEN_COUNT_DROP_MUTANT", "00000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RESOURCE_FAILURE_LABEL_MAPPING_MUTANT", "00000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000010101010101010000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RESOURCE_FAILURE_LIMIT_MAPPING_MUTANT", "00000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000010101010101010000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RESOURCE_FAILURE_OBSERVED_MAPPING_MUTANT", "00000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000010101010101010000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_STRING_TYPE_MAPPING_MUTANT", "00000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_TEXT_TOKEN_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_TOKEN_ERROR_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_DISCOVERY_PROBLEM_CONTRIBUTION_DROP_MUTANT", "00100000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_MALFORMED_FOLD_DIGEST_PROJECTION_MUTANT", "00111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111110111111111111111100111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_NESTED_COMPONENT_NON_OBJECT_MAPPING_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_NESTED_COMPONENT_OBJECT_ROUTE_DROP_MUTANT", "01000000000000000000110111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_UNIT_ORDER_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_OPTIONAL_TEXT_EMPTY_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_OPTIONAL_TEXT_MISSING_ROUTE_MUTANT", "11111000000000011011111111100111111111111110111100000011110000001100000000000001111111111111110001111111111111111111111111111100000000000000000011001001000010111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_OPTIONAL_TEXT_TYPE_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PARSED_PROBLEMS_PROJECTION_DROP_MUTANT", "00000100000000011111111000000001111111111111101100001111111111111100001111111111111111111110000001111111111111111111111111111000000000001000001100111000000010111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PARSED_VALUE_PROJECTION_DROP_MUTANT", "11111000000000011011111111111111111111111111111100000011111111111101110000000001111111111111111111111111111111111111111111111100000000000000001111101111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PARTITION_PROBLEM_CONTRIBUTION_DROP_MUTANT", "00000000000000011011111000000001111111111111101100000011111111111100000000000001111111111110000001111111111111111111111111111000000000000000001100101000000010111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PARTITION_VALUE_CONTRIBUTION_DROP_MUTANT", "11011000000000000000000111111110000000000000010000000000000000000001000000000000000000000001111110000000000000000000000000000000000000000000000011000001000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REFUSAL_DIGEST_PROJECTION_MUTANT", "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111110111111111111111111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REFUSAL_INPUT_BYTES_PROJECTION_MUTANT", "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REFUSAL_PROBLEM_ORDER_MUTANT", "11000000000000000000000001000100000000000000000000001000110000000011000000000000000000000000000000000000011111000000000000000000000000001000001011001000000010000101010101")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REFUSAL_SNAPSHOT_PROJECTION_DROP_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_OBJECT_MISSING_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_OBJECT_TYPE_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_TEXT_EMPTY_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_TEXT_MISSING_ROUTE_MUTANT", "00000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_TEXT_TYPE_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_UNIT_ARRAY_MISSING_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_UNIT_ARRAY_TYPE_ROUTE_MUTANT", "00000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ROOT_NON_OBJECT_MAPPING_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010101010000010000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ROOT_OBJECT_ROUTE_DROP_MUTANT", "11111110000000011111111111111111111111111111111100001111111111111111111111111111111111111111111111111111111111111111111111111100000000101000001111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ROOT_OBSERVATION_KEY_MAPPING_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ROOT_OBSERVATION_VALUE_MAPPING_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SHA256_HEX_ALPHA_MAPPING_MUTANT", "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111110111111111111111111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SHA256_HIGH_NIBBLE_MAPPING_MUTANT", "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111110111111111111111111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SHA256_LOW_NIBBLE_MAPPING_MUTANT", "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111110111111111111111111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_STATUS_OBSERVATION_KEY_MAPPING_MUTANT", "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_STATUS_OBSERVATION_VALUE_MAPPING_MUTANT", "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SUBJECT_OBSERVATION_CONTRIBUTION_DROP_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_BINARY_PATH_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_BUILD_INFO_PATH_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_BUILD_STYLE_PROJECTION_MUTANT", "11011000000000000000000111111110000000000000010000000000000000000000000000000000000000000001111110000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_CABAL_SHA256_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_COMPONENTS_PROJECTION_DROP_MUTANT", "11011000000000000000000111111110000000000000010000000000000000000000000000000000000000000001111110000000000000000000000000000000000000000000000011000001000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_COMPONENT_SHAPE_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_DEPENDENCIES_PROJECTION_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_DEPENDENCY_PROBLEM_CONTRIBUTION_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_DIST_DIRECTORY_PATH_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_FLAGS_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_ID_PROJECTION_MUTANT", "11111000000000000000000111111110000000000000010000000000000000000001000000000000000000000001111110000000000000000000000000000100000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_OBSERVATION_KEY_MAPPING_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_OBSERVATION_ORDER_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_OBSERVATION_VALUE_MAPPING_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_ORDER_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_ORIGIN_PROJECTION_MUTANT", "11001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_PACKAGE_NAME_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_PACKAGE_VERSION_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_REPOSITORY_TYPE_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_SOURCE_KIND_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_SOURCE_LOCATION_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_SOURCE_ROOT_PROJECTION_MUTANT", "11001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_SOURCE_SHA256_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_SOURCE_TAG_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNKNOWN_FIELD_DETECTION_BYPASS_MUTANT", "00000010000000000000000000000000000000000000000100000000000000010010000000000000000000000000000000000000000000000000001100000000000000101000000000000000000000100000111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNKNOWN_FIELD_ORDER_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  ]


updatedNewSelectorSupplementalImpactSignatures :: [(String, String)]
updatedNewSelectorSupplementalImpactSignatures =
  [ ("VALIDATION_COMPILER_ELABORATED_PLAN_AESON_DECODE_FAILURE_MAPPING_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ASCII_DIGIT_ALTERNATIVE_DROP_MUTANT", "01000000100000000011111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ASCII_LOWERCASE_ALTERNATIVE_DROP_MUTANT", "01000000100000000011111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ASCII_UPPERCASE_ALTERNATIVE_DROP_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BINARY_BENCHMARK_CLASSIFICATION_DROP_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BINARY_EXECUTABLE_CLASSIFICATION_DROP_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BINARY_LIBRARY_CLASSIFICATION_WIDEN_MUTANT", "01000000100000000000000001110011111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BINARY_TEST_CLASSIFICATION_DROP_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BOOLEAN_MAP_VALUE_TYPE_ROUTE_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BOUNDED_PROBLEM_ORDER_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CHECK_NAME_MAPPING_MUTANT", "01000000100000000011111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_DEPENDENCIES_PROJECTION_DROP_MUTANT", "00100011010000000000000001110000010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_DEPENDENCY_PROBLEM_CONTRIBUTION_DROP_MUTANT", "00000000000000000000000001110000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_EXECUTABLE_DEPENDENCIES_PROJECTION_MUTANT", "01000000100000000000000001110000111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_EXECUTABLE_DEPENDENCY_PROBLEM_CONTRIBUTION_DROP_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_NAME_PROJECTION_MUTANT", "00100011010000000000000001110000010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_ORDER_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_SOURCE_PATHS_PROJECTION_MUTANT", "00100011001000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNIT_ID_PROJECTION_MUTANT", "00100011010000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CONSTRAINED_ARRAY_VALUE_GATE_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CONSTRAINED_PATH_VALUE_GATE_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CONSTRAINED_TEXT_VALUE_GATE_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_ARRAY_ELEMENT_TYPE_ROUTE_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_ARRAY_EMPTY_TEXT_ROUTE_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_ARRAY_MISSING_ROUTE_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_ARRAY_TYPE_ROUTE_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_CYCLE_PROBLEM_CONTRIBUTION_DROP_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_PROBLEM_CONTRIBUTION_DROP_MUTANT", "00000000000000000000000001110000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_GROUPING_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_LOCAL_COMPONENT_PROBLEM_CONTRIBUTION_DROP_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_UNIT_PROBLEM_CONTRIBUTION_DROP_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_EMPTY_COMPONENT_MAP_GUARD_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_FINDING_CODE_MAPPING_MUTANT", "01000000100000000011111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_FINDING_DETAIL_MAPPING_MUTANT", "01000000100000000011111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_FINDING_ORDER_MUTANT", "00000011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_FINDING_SUBJECT_MAPPING_MUTANT", "01000000100000000011111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_FLAG_ORDER_MUTANT", "00000000100000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_GLOBAL_LOCAL_DISCOVERY_GUARD_BYPASS_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_GROUPED_VALUE_RENDER_DROP_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_INPUT_BYTES_OBSERVATION_KEY_MAPPING_MUTANT", "01000000100000000011111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_INPUT_BYTES_OBSERVATION_VALUE_MAPPING_MUTANT", "01000000100000000011111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_INPUT_DIGEST_OBSERVATION_KEY_MAPPING_MUTANT", "01000000100000000011111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_INPUT_DIGEST_OBSERVATION_VALUE_MAPPING_MUTANT", "01000000100000000011111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_INSTALL_UNIT_NON_OBJECT_MAPPING_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_INSTALL_UNIT_OBJECT_ROUTE_DROP_MUTANT", "01000000100000000011111001111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_ARRAY_DEPTH_ROUTE_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_ARRAY_END_TOKEN_COUNT_DROP_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_ARRAY_ERROR_ROUTE_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_ARRAY_ITEM_TOKEN_COUNT_DROP_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_ARRAY_TYPE_MAPPING_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_BOOLEAN_TYPE_MAPPING_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_FIELD_PATH_APPEND_DROP_MUTANT", "00000000000000000011111000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_FIELD_PATH_RENDER_MUTANT", "00000000000000000011111000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_FIELD_SCOPE_MAPPING_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_INDEX_PATH_APPEND_DROP_MUTANT", "00000000000000000011111000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_INDEX_PATH_RENDER_MUTANT", "00000000000000000011111000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_INVALID_FAILURE_MAPPING_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_LITERAL_TOKEN_ROUTE_MUTANT", "01000000100000000011111110001100111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_NULL_TYPE_MAPPING_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_NUMBER_TOKEN_ROUTE_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_NUMBER_TYPE_MAPPING_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_OBJECT_TYPE_MAPPING_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RECORD_DEPTH_ROUTE_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RECORD_END_TOKEN_COUNT_DROP_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RECORD_ERROR_ROUTE_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RECORD_PAIR_TOKEN_COUNT_DROP_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RESOURCE_FAILURE_LABEL_MAPPING_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RESOURCE_FAILURE_LIMIT_MAPPING_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_RESOURCE_FAILURE_OBSERVED_MAPPING_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_STRING_TYPE_MAPPING_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_TEXT_TOKEN_ROUTE_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_JSON_TOKEN_ERROR_ROUTE_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_DISCOVERY_PROBLEM_CONTRIBUTION_DROP_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_MALFORMED_FOLD_DIGEST_PROJECTION_MUTANT", "00000000000000000011111111111111000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_NESTED_COMPONENT_NON_OBJECT_MAPPING_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_NESTED_COMPONENT_OBJECT_ROUTE_DROP_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_UNIT_ORDER_MUTANT", "00100001000111100000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_OPTIONAL_TEXT_EMPTY_ROUTE_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_OPTIONAL_TEXT_MISSING_ROUTE_MUTANT", "01000000100000000000000001111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_OPTIONAL_TEXT_TYPE_ROUTE_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PARSED_PROBLEMS_PROJECTION_DROP_MUTANT", "00000000000000000011111000001111000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PARSED_VALUE_PROJECTION_DROP_MUTANT", "01000000100000000011111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PARTITION_PROBLEM_CONTRIBUTION_DROP_MUTANT", "00000000000000000011111000001111000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PARTITION_VALUE_CONTRIBUTION_DROP_MUTANT", "01000000100000000000000001110000111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REFUSAL_DIGEST_PROJECTION_MUTANT", "01000000100000000011111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REFUSAL_INPUT_BYTES_PROJECTION_MUTANT", "01000000100000000011111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REFUSAL_PROBLEM_ORDER_MUTANT", "00000011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REFUSAL_SNAPSHOT_PROJECTION_DROP_MUTANT", "01000000100000000000000000000000111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_OBJECT_MISSING_ROUTE_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_OBJECT_TYPE_ROUTE_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_TEXT_EMPTY_ROUTE_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_TEXT_MISSING_ROUTE_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_TEXT_TYPE_ROUTE_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_UNIT_ARRAY_MISSING_ROUTE_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REQUIRED_UNIT_ARRAY_TYPE_ROUTE_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ROOT_NON_OBJECT_MAPPING_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ROOT_OBJECT_ROUTE_DROP_MUTANT", "01000000100000000011111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ROOT_OBSERVATION_KEY_MAPPING_MUTANT", "01000000100000000000000000000000111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_ROOT_OBSERVATION_VALUE_MAPPING_MUTANT", "01000000100000000000000000000000111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SHA256_HEX_ALPHA_MAPPING_MUTANT", "01000000100000000011111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SHA256_HIGH_NIBBLE_MAPPING_MUTANT", "01000000100000000011111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SHA256_LOW_NIBBLE_MAPPING_MUTANT", "01000000100000000011111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_STATUS_OBSERVATION_KEY_MAPPING_MUTANT", "01000000100000000011111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_STATUS_OBSERVATION_VALUE_MAPPING_MUTANT", "01000000100000000011111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SUBJECT_OBSERVATION_CONTRIBUTION_DROP_MUTANT", "01000000100000000000000000000000111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_BINARY_PATH_PROJECTION_MUTANT", "10100011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_BUILD_INFO_PATH_PROJECTION_MUTANT", "10100011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_BUILD_STYLE_PROJECTION_MUTANT", "01000000100000000000000001110000111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_CABAL_SHA256_PROJECTION_MUTANT", "00100011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_COMPONENTS_PROJECTION_DROP_MUTANT", "01000000100000000000000001110000111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_COMPONENT_SHAPE_PROJECTION_MUTANT", "00100011000000100000000000000000010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_DEPENDENCIES_PROJECTION_DROP_MUTANT", "00000000000000000000000000000000010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_DEPENDENCY_PROBLEM_CONTRIBUTION_DROP_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_DIST_DIRECTORY_PATH_PROJECTION_MUTANT", "10100011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_FLAGS_PROJECTION_MUTANT", "00100011100000010000000000000000010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_ID_PROJECTION_MUTANT", "01000000100000000000000001110000111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_OBSERVATION_KEY_MAPPING_MUTANT", "01000000100000000000000000000000111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_OBSERVATION_ORDER_MUTANT", "01000000100000000000000000000000111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_OBSERVATION_VALUE_MAPPING_MUTANT", "01000000100000000000000000000000111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_ORDER_MUTANT", "00100011000111100000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_ORIGIN_PROJECTION_MUTANT", "10100011111100011100000000000000001")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_PACKAGE_NAME_PROJECTION_MUTANT", "00100011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_PACKAGE_VERSION_PROJECTION_MUTANT", "00100011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_REPOSITORY_TYPE_PROJECTION_MUTANT", "00100011000000001000000000000000100")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_SOURCE_KIND_PROJECTION_MUTANT", "00100011000000001000000000000000100")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_SOURCE_LOCATION_PROJECTION_MUTANT", "00100011000000001000000000000000100")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_SOURCE_ROOT_PROJECTION_MUTANT", "00100011000000001100000000000000001")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_SOURCE_SHA256_PROJECTION_MUTANT", "00100011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_SOURCE_TAG_PROJECTION_MUTANT", "00100011000000000000000000000000100")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNKNOWN_FIELD_DETECTION_BYPASS_MUTANT", "00000000000000000011111000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNKNOWN_FIELD_ORDER_MUTANT", "00000000000000000000000000000000000")
  ]


auditSelectorIntents :: [SelectorIntent]
auditSelectorIntents =
  [ SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_AGGREGATE_COMPONENT_SHAPE_MAPPING_MUTANT" "the aggregate component alternative has one exact ordered digest-bound public refusal"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_CABAL_LIBRARY_SCHEMA_FIELD_ROUTE_DROP_MUTANT" "the Cabal schema version is an exact closed alternative"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_CABAL_SCHEMA_FIELD_ROUTE_DROP_MUTANT" "the Cabal library schema version is an independently exact closed alternative"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_BENCHMARK_PREFIX_ALTERNATIVE_DROP_MUTANT" "the admitted component alternative remains exact: bench:perf"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_DOT_ALTERNATIVE_DROP_MUTANT" "the admitted component alternative remains exact: lib:core.name"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_EXECUTABLE_PREFIX_ALTERNATIVE_DROP_MUTANT" "the admitted component alternative remains exact: exe:tool"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_HYPHEN_ALTERNATIVE_DROP_MUTANT" "the admitted component alternative remains exact: lib:core-name"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_LIB_BUILTIN_ALTERNATIVE_DROP_MUTANT" "the admitted component alternative remains exact: lib"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_LIB_PREFIX_ALTERNATIVE_DROP_MUTANT" "the admitted component alternative remains exact: lib:core"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_MAP_ROUTE_DROP_MUTANT" "the aggregate component alternative has one exact ordered digest-bound public refusal"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_SETUP_BUILTIN_ALTERNATIVE_DROP_MUTANT" "the admitted component alternative remains exact: setup"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_TEST_PREFIX_ALTERNATIVE_DROP_MUTANT" "the admitted component alternative remains exact: test:spec"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNDERSCORE_ALTERNATIVE_DROP_MUTANT" "the admitted component alternative remains exact: lib:core_name"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_DIRECT_COMPONENT_ROUTE_DROP_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_DIRECT_COMPONENT_SHAPE_MAPPING_MUTANT" "direct component shape remains explicit instead of collapsing into an aggregate"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_FLAG_HYPHEN_ALTERNATIVE_DROP_MUTANT" "the admitted flag alternative remains exact: variant-name"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_FLAG_UNDERSCORE_ALTERNATIVE_DROP_MUTANT" "the admitted flag alternative remains exact: variant_name"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_INSTALL_UNIT_CONFIGURED_ROUTE_DROP_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_INSTALL_UNIT_PRE_EXISTING_ROUTE_DROP_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_PACKAGE_SOURCE_ROUTE_DROP_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_IDENTITY_ROUTE_DROP_MUTANT" "local sources reject an unexpected claimed source hash"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_KIND_MAPPING_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_LOCAL_STYLE_ROUTE_DROP_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_LOWER_HEX_ALPHA_ALTERNATIVE_DROP_MUTANT" "SHA-256 lower-hex alphabetic alternative remains admitted"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_LOWER_HEX_DIGIT_ALTERNATIVE_DROP_MUTANT" "SHA-256 lower-hex digit alternative remains admitted"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PLATFORM_HYPHEN_ALTERNATIVE_DROP_MUTANT" "platform tokens retain the hyphen character alternative"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PLATFORM_UNDERSCORE_ALTERNATIVE_DROP_MUTANT" "platform tokens retain the underscore character alternative"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PORTABLE_IDENTITY_COLON_ALTERNATIVE_DROP_MUTANT" "portable identity retains the colon character alternative"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PORTABLE_IDENTITY_DOT_ALTERNATIVE_DROP_MUTANT" "portable identity retains the dot character alternative"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PORTABLE_IDENTITY_HYPHEN_ALTERNATIVE_DROP_MUTANT" "portable identity retains the hyphen character alternative"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PORTABLE_IDENTITY_PLUS_ALTERNATIVE_DROP_MUTANT" "portable identity retains the plus character alternative"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PORTABLE_IDENTITY_UNDERSCORE_ALTERNATIVE_DROP_MUTANT" "portable identity retains the underscore character alternative"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PRE_EXISTING_SOURCE_KIND_MAPPING_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TAR_GLOBAL_STYLE_ROUTE_DROP_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TAR_INPLACE_STYLE_ROUTE_DROP_MUTANT" "an inplace configured unit without its build-info path is refused"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TAR_PACKAGE_SOURCE_ROUTE_DROP_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TAR_SOURCE_IDENTITY_ROUTE_DROP_MUTANT" "a malformed remote source hash is one exact identity defect"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TAR_SOURCE_KIND_MAPPING_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TYPE_ABSENT_MAPPING_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TYPE_REPOSITORY_TAR_MAPPING_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TYPE_SOURCE_REPOSITORY_MAPPING_MUTANT" "source-repository global projection retains kind, repository type, location, and tag"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_LOCATION_ABSENT_MAPPING_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_LOCATION_REPOSITORY_TAR_MAPPING_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_LOCATION_SOURCE_REPOSITORY_MAPPING_MUTANT" "source-repository global projection retains kind, repository type, location, and tag"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_REPOSITORY_GLOBAL_STYLE_ROUTE_DROP_MUTANT" "source repositories reject an unexpected Cabal hash"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_REPOSITORY_IDENTITY_ROUTE_DROP_MUTANT" "source repositories reject an unexpected Cabal hash"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_REPOSITORY_INPLACE_STYLE_ROUTE_DROP_MUTANT" "source-repository inplace style remains distinct"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_REPOSITORY_PACKAGE_SOURCE_ROUTE_DROP_MUTANT" "source-repo accepts only the frozen Git subtype"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_REPOSITORY_SOURCE_KIND_MAPPING_MUTANT" "source-repository global projection retains kind, repository type, location, and tag"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_ROOT_ABSENT_MAPPING_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_ROOT_LOCAL_MAPPING_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_TAG_ABSENT_MAPPING_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_TAG_SOURCE_REPOSITORY_MAPPING_MUTANT" "source-repository global projection retains kind, repository type, location, and tag"
  ]

routingAuditSelectorIntents :: [SelectorIntent]
routingAuditSelectorIntents =
  [ SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_BUILD_ARTIFACT_LOCAL_ORIGIN_ALTERNATIVE_DROP_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_BUILD_ARTIFACT_PRE_EXISTING_ORIGIN_EXCLUSION_BYPASS_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_BUILD_ARTIFACT_REMOTE_ORIGIN_ALTERNATIVE_DROP_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_BUILD_ARTIFACT_SUBJECT_ORDER_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_BUILD_ARTIFACT_SUBJECT_PROJECTION_DROP_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_DEPENDENCY_SUBJECT_LABEL_MAPPING_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_DEPENDENCY_SUBJECT_ROUTE_DROP_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_EXECUTABLE_DEPENDENCY_SUBJECT_LABEL_MAPPING_MUTANT" "source-repository inplace style remains distinct"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_EXECUTABLE_DEPENDENCY_SUBJECT_ROUTE_DROP_MUTANT" "source-repository inplace style remains distinct"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNIVERSE_GLOBAL_STYLE_EXCLUSION_BYPASS_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNIVERSE_INPLACE_STYLE_ALTERNATIVE_DROP_MUTANT" "source-repository inplace style remains distinct"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNIVERSE_LOCAL_STYLE_ALTERNATIVE_DROP_MUTANT" "the exact observed-result ceiling retains fifteen mandatory refusals and 113 exact source-path rows"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNIVERSE_SUBJECT_ORDER_MUTANT" "the exact observed-result ceiling retains fifteen mandatory refusals and 113 exact source-path rows"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNIVERSE_SUBJECT_PROJECTION_DROP_MUTANT" "the exact observed-result ceiling retains fifteen mandatory refusals and 113 exact source-path rows"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_CONFIGURATION_GLOBAL_STYLE_ALTERNATIVE_DROP_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_CONFIGURATION_INPLACE_STYLE_ALTERNATIVE_DROP_MUTANT" "source-repository inplace style remains distinct"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_CONFIGURATION_LOCAL_STYLE_ALTERNATIVE_DROP_MUTANT" "the exact observed-result ceiling retains fifteen mandatory refusals and 113 exact source-path rows"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_CONFIGURATION_PRE_EXISTING_STYLE_EXCLUSION_BYPASS_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_CONFIGURATION_SUBJECT_ORDER_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_CONFIGURATION_SUBJECT_PROJECTION_DROP_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_SUBJECT_ORDER_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_SUBJECT_PROJECTION_DROP_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_ROOT_LOCAL_ORIGIN_ALTERNATIVE_DROP_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_ROOT_SUBJECT_ORDER_MUTANT" "multiple local roots retain deterministic subject order"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_ROOT_SUBJECT_PROJECTION_DROP_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_MALFORMED_FOLD_INPUT_BYTES_PROJECTION_MUTANT" "an install plan without a local component refuses empty discovery"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_MALFORMED_FOLD_PROBLEMS_PROJECTION_MUTANT" "multiple unknown fields retain deterministic lexical order"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_ARCHITECTURE_PROJECTION_MUTANT" "the complete accepted semantic snapshot is independently literal and input-bound"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_CABAL_LIBRARY_VERSION_PROJECTION_MUTANT" "the complete accepted semantic snapshot is independently literal and input-bound"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_CABAL_VERSION_PROJECTION_MUTANT" "the complete accepted semantic snapshot is independently literal and input-bound"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_COMPILER_ABI_PROJECTION_MUTANT" "the complete accepted semantic snapshot is independently literal and input-bound"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_COMPILER_ID_PROJECTION_MUTANT" "the complete accepted semantic snapshot is independently literal and input-bound"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_DIGEST_PROJECTION_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_INPUT_BYTES_PROJECTION_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_OPERATING_SYSTEM_PROJECTION_MUTANT" "the complete accepted semantic snapshot is independently literal and input-bound"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_PROBLEMS_PROJECTION_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_SOURCE_LOCAL_ORIGIN_ALTERNATIVE_DROP_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_SOURCE_PRE_EXISTING_ORIGIN_EXCLUSION_BYPASS_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_SOURCE_REMOTE_ORIGIN_ALTERNATIVE_DROP_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_SOURCE_SUBJECT_ORDER_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_SOURCE_SUBJECT_PROJECTION_DROP_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_SHA256_INPUT_ROUTE_MUTANT" "the same-library public positive client observes the one exact always-refusing CheckResult"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_DEPENDENCY_SUBJECT_LABEL_MAPPING_MUTANT" "source-repository inplace style remains distinct"
  , SelectorIntent "VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_DEPENDENCY_SUBJECT_ROUTE_DROP_MUTANT" "source-repository inplace style remains distinct"
  ]


auditSelectorImpactSignatures :: [(String, String)]
auditSelectorImpactSignatures =
  [ ("VALIDATION_COMPILER_ELABORATED_PLAN_AGGREGATE_COMPONENT_SHAPE_MAPPING_MUTANT", "01000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CABAL_LIBRARY_SCHEMA_FIELD_ROUTE_DROP_MUTANT", "11111110000000011111111111111111111111111111111100000111111111111111101111111111111111111111111111111111111111111111111111111100000000000000001111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CABAL_SCHEMA_FIELD_ROUTE_DROP_MUTANT", "11111110000000011111111111111111111111111111111100000011111111111111011111111111111111111111111111111111111111111111111111111100000000000000001111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_BENCHMARK_PREFIX_ALTERNATIVE_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_DOT_ALTERNATIVE_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_EXECUTABLE_PREFIX_ALTERNATIVE_DROP_MUTANT", "00000000000000000000000000011000000000000000100000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_HYPHEN_ALTERNATIVE_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_LIB_BUILTIN_ALTERNATIVE_DROP_MUTANT", "11111000000000000000110111000001111000111010011100000000110000000000000000000001111000000001000001010111100000000000001111111100000000000000000000000000000000000000101010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_LIB_PREFIX_ALTERNATIVE_DROP_MUTANT", "10011000000000000000000000100110000001000101011100000000000000000000000000000000000000000001010000000000000000000000000000000000000000000000000011000001000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_MAP_ROUTE_DROP_MUTANT", "01000000000000010000110111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011001000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_SETUP_BUILTIN_ALTERNATIVE_DROP_MUTANT", "00000000000000000000110111000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_TEST_PREFIX_ALTERNATIVE_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNDERSCORE_ALTERNATIVE_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DIRECT_COMPONENT_ROUTE_DROP_MUTANT", "10111000000000001000000000111111111001111111111100000000110000001100000000000001111000111111111111010111100000000000001111111100000000000000000000000001000000000000101010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DIRECT_COMPONENT_SHAPE_MAPPING_MUTANT", "10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_FLAG_HYPHEN_ALTERNATIVE_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_FLAG_UNDERSCORE_ALTERNATIVE_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_INSTALL_UNIT_CONFIGURED_ROUTE_DROP_MUTANT", "11111000000000011011111111111111111111111111111100000011110000001100000000000001111111111111111111111111111111111111111111111100000000000000000011001001000010111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_INSTALL_UNIT_PRE_EXISTING_ROUTE_DROP_MUTANT", "11111000000000011011111111111111111111111111111100000011111111111101000000000001111111111111111110111111111111111111111111111100000000000000000011001001000010111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_PACKAGE_SOURCE_ROUTE_DROP_MUTANT", "11011000000000001011111111111110000001000101110100000000000000001100000000000001111111111111111111011101000000111111111100000000000000000000000011001001000010101100111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_IDENTITY_ROUTE_DROP_MUTANT", "00000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_KIND_MAPPING_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_LOCAL_STYLE_ROUTE_DROP_MUTANT", "11011000000000001000111111111110000001000101110100000000000000001100000000000001111000111111111111001001000000000000001100000000000000000000000011001001000000000000101010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOWER_HEX_ALPHA_ALTERNATIVE_DROP_MUTANT", "10111000000000000000000000000001111000111010011100000000110000000000000000000000000000000000000000000010100000000000000011111100000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOWER_HEX_DIGIT_ALTERNATIVE_DROP_MUTANT", "00000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PLATFORM_HYPHEN_ALTERNATIVE_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PLATFORM_UNDERSCORE_ALTERNATIVE_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PORTABLE_IDENTITY_COLON_ALTERNATIVE_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PORTABLE_IDENTITY_DOT_ALTERNATIVE_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PORTABLE_IDENTITY_HYPHEN_ALTERNATIVE_DROP_MUTANT", "11111000000000011011111111111111111111111111111100000011111111111101000000000001111111111111111111111111111111111111111111111100000000000000000011001001000010111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PORTABLE_IDENTITY_PLUS_ALTERNATIVE_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PORTABLE_IDENTITY_UNDERSCORE_ALTERNATIVE_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PRE_EXISTING_SOURCE_KIND_MAPPING_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TAR_GLOBAL_STYLE_ROUTE_DROP_MUTANT", "10111000000000010000000000000001111000000010011100000000110000000000000000000000000000000000000000000010000000000000000011000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TAR_INPLACE_STYLE_ROUTE_DROP_MUTANT", "00000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TAR_PACKAGE_SOURCE_ROUTE_DROP_MUTANT", "10111000000000010000000000000001111100001010011100000000110000000000000000000000000000000000000000000010011111000000000011000000000000000000000000000000000000000011000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TAR_SOURCE_IDENTITY_ROUTE_DROP_MUTANT", "00000000000000000000000000000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TAR_SOURCE_KIND_MAPPING_MUTANT", "10000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TYPE_ABSENT_MAPPING_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TYPE_REPOSITORY_TAR_MAPPING_MUTANT", "10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TYPE_SOURCE_REPOSITORY_MAPPING_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_LOCATION_ABSENT_MAPPING_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_LOCATION_REPOSITORY_TAR_MAPPING_MUTANT", "10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_LOCATION_SOURCE_REPOSITORY_MAPPING_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_REPOSITORY_GLOBAL_STYLE_ROUTE_DROP_MUTANT", "00000000000000000000000000000000000000110000000000000000000000000000000000000000000000000000000000000000100000000000000000111100000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_REPOSITORY_IDENTITY_ROUTE_DROP_MUTANT", "00000000000000000000000000000000000000110000000000000000000000000000000000000000000000000000000000000000100000000000000000111000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_REPOSITORY_INPLACE_STYLE_ROUTE_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_REPOSITORY_PACKAGE_SOURCE_ROUTE_DROP_MUTANT", "00000000000000000000000000000000000010110000000000000000000000000000000000000000000000000000000000000000100000000000000000111100000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_REPOSITORY_SOURCE_KIND_MAPPING_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_ROOT_ABSENT_MAPPING_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_ROOT_LOCAL_MAPPING_MUTANT", "11001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_TAG_ABSENT_MAPPING_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_TAG_SOURCE_REPOSITORY_MAPPING_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  ]


auditSelectorSupplementalImpactSignatures :: [(String, String)]
auditSelectorSupplementalImpactSignatures =
  [ ("VALIDATION_COMPILER_ELABORATED_PLAN_AGGREGATE_COMPONENT_SHAPE_MAPPING_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CABAL_LIBRARY_SCHEMA_FIELD_ROUTE_DROP_MUTANT", "01000000100000000011111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CABAL_SCHEMA_FIELD_ROUTE_DROP_MUTANT", "01000000100000000011111001111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_BENCHMARK_PREFIX_ALTERNATIVE_DROP_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_DOT_ALTERNATIVE_DROP_MUTANT", "00000000000000000000000001000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_EXECUTABLE_PREFIX_ALTERNATIVE_DROP_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_HYPHEN_ALTERNATIVE_DROP_MUTANT", "00000000000000000000000000100000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_LIB_BUILTIN_ALTERNATIVE_DROP_MUTANT", "01000000100000000000000000000011110")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_LIB_PREFIX_ALTERNATIVE_DROP_MUTANT", "01000000000000000000000001110000111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_MAP_ROUTE_DROP_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_SETUP_BUILTIN_ALTERNATIVE_DROP_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_TEST_PREFIX_ALTERNATIVE_DROP_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNDERSCORE_ALTERNATIVE_DROP_MUTANT", "00000000000000000000000000010000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DIRECT_COMPONENT_ROUTE_DROP_MUTANT", "01000000100000000000000001111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DIRECT_COMPONENT_SHAPE_MAPPING_MUTANT", "00100011000000100000000000000000010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_FLAG_HYPHEN_ALTERNATIVE_DROP_MUTANT", "00000000000000000000000000001000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_FLAG_UNDERSCORE_ALTERNATIVE_DROP_MUTANT", "00000000000000000000000000000100000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_INSTALL_UNIT_CONFIGURED_ROUTE_DROP_MUTANT", "01000000100000000000000001111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_INSTALL_UNIT_PRE_EXISTING_ROUTE_DROP_MUTANT", "01000000100000000011111001111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_PACKAGE_SOURCE_ROUTE_DROP_MUTANT", "01000000100000000000000001111100111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_IDENTITY_ROUTE_DROP_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_KIND_MAPPING_MUTANT", "00100011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_LOCAL_STYLE_ROUTE_DROP_MUTANT", "01000000100000000000000001111100111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOWER_HEX_ALPHA_ALTERNATIVE_DROP_MUTANT", "01000000000000000000000000000010110")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOWER_HEX_DIGIT_ALTERNATIVE_DROP_MUTANT", "00000000000000000000000000000001000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PLATFORM_HYPHEN_ALTERNATIVE_DROP_MUTANT", "00000000000000000000000100000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PLATFORM_UNDERSCORE_ALTERNATIVE_DROP_MUTANT", "00000000000000000000000010000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PORTABLE_IDENTITY_COLON_ALTERNATIVE_DROP_MUTANT", "00000000000000000010000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PORTABLE_IDENTITY_DOT_ALTERNATIVE_DROP_MUTANT", "00000000000000000001000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PORTABLE_IDENTITY_HYPHEN_ALTERNATIVE_DROP_MUTANT", "01000000100000000000010001111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PORTABLE_IDENTITY_PLUS_ALTERNATIVE_DROP_MUTANT", "00000000000000000000100000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PORTABLE_IDENTITY_UNDERSCORE_ALTERNATIVE_DROP_MUTANT", "00000000000000000000001000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PRE_EXISTING_SOURCE_KIND_MAPPING_MUTANT", "00100011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TAR_GLOBAL_STYLE_ROUTE_DROP_MUTANT", "01000000000000000000000000000011000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TAR_INPLACE_STYLE_ROUTE_DROP_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TAR_PACKAGE_SOURCE_ROUTE_DROP_MUTANT", "01000000000000000000000000000011000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TAR_SOURCE_IDENTITY_ROUTE_DROP_MUTANT", "00000000000000000000000000000011000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TAR_SOURCE_KIND_MAPPING_MUTANT", "00100011000000001000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TYPE_ABSENT_MAPPING_MUTANT", "00100011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TYPE_REPOSITORY_TAR_MAPPING_MUTANT", "00100011000000001000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TYPE_SOURCE_REPOSITORY_MAPPING_MUTANT", "00000000000000000000000000000000100")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_LOCATION_ABSENT_MAPPING_MUTANT", "00100011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_LOCATION_REPOSITORY_TAR_MAPPING_MUTANT", "00100011000000001000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_LOCATION_SOURCE_REPOSITORY_MAPPING_MUTANT", "00000000000000000000000000000000100")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_REPOSITORY_GLOBAL_STYLE_ROUTE_DROP_MUTANT", "00000000000000000000000000000000100")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_REPOSITORY_IDENTITY_ROUTE_DROP_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_REPOSITORY_INPLACE_STYLE_ROUTE_DROP_MUTANT", "00000000000000000000000000000000010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_REPOSITORY_PACKAGE_SOURCE_ROUTE_DROP_MUTANT", "00000000000000000000000000000000110")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_REPOSITORY_SOURCE_KIND_MAPPING_MUTANT", "00000000000000000000000000000000100")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_ROOT_ABSENT_MAPPING_MUTANT", "00100011000000001000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_ROOT_LOCAL_MAPPING_MUTANT", "00100011000000000100000000000000001")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_TAG_ABSENT_MAPPING_MUTANT", "00100011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_TAG_SOURCE_REPOSITORY_MAPPING_MUTANT", "00000000000000000000000000000000100")
  ]


routingAuditSelectorImpactSignatures :: [(String, String)]
routingAuditSelectorImpactSignatures =
  [ ("VALIDATION_COMPILER_ELABORATED_PLAN_BUILD_ARTIFACT_LOCAL_ORIGIN_ALTERNATIVE_DROP_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BUILD_ARTIFACT_PRE_EXISTING_ORIGIN_EXCLUSION_BYPASS_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BUILD_ARTIFACT_REMOTE_ORIGIN_ALTERNATIVE_DROP_MUTANT", "10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BUILD_ARTIFACT_SUBJECT_ORDER_MUTANT", "10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BUILD_ARTIFACT_SUBJECT_PROJECTION_DROP_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_DEPENDENCY_SUBJECT_LABEL_MAPPING_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_DEPENDENCY_SUBJECT_ROUTE_DROP_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_EXECUTABLE_DEPENDENCY_SUBJECT_LABEL_MAPPING_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_EXECUTABLE_DEPENDENCY_SUBJECT_ROUTE_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNIVERSE_GLOBAL_STYLE_EXCLUSION_BYPASS_MUTANT", "10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNIVERSE_INPLACE_STYLE_ALTERNATIVE_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNIVERSE_LOCAL_STYLE_ALTERNATIVE_DROP_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNIVERSE_SUBJECT_ORDER_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNIVERSE_SUBJECT_PROJECTION_DROP_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CONFIGURATION_GLOBAL_STYLE_ALTERNATIVE_DROP_MUTANT", "10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CONFIGURATION_INPLACE_STYLE_ALTERNATIVE_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CONFIGURATION_LOCAL_STYLE_ALTERNATIVE_DROP_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CONFIGURATION_PRE_EXISTING_STYLE_EXCLUSION_BYPASS_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CONFIGURATION_SUBJECT_ORDER_MUTANT", "10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CONFIGURATION_SUBJECT_PROJECTION_DROP_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_SUBJECT_ORDER_MUTANT", "10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_SUBJECT_PROJECTION_DROP_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_ROOT_LOCAL_ORIGIN_ALTERNATIVE_DROP_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_ROOT_SUBJECT_PROJECTION_DROP_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_MALFORMED_FOLD_INPUT_BYTES_PROJECTION_MUTANT", "00111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111100111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_MALFORMED_FOLD_PROBLEMS_PROJECTION_MUTANT", "00000000000000000000000001000100000000000000000000001000110000000011000000000000000000000000000000000000011111000000000000000000000000001000001000001000000010000101010101")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_ARCHITECTURE_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_CABAL_LIBRARY_VERSION_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_CABAL_VERSION_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_COMPILER_ABI_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_COMPILER_ID_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_DIGEST_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_INPUT_BYTES_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_OPERATING_SYSTEM_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_PROBLEMS_PROJECTION_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_SOURCE_LOCAL_ORIGIN_ALTERNATIVE_DROP_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_SOURCE_PRE_EXISTING_ORIGIN_EXCLUSION_BYPASS_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_SOURCE_REMOTE_ORIGIN_ALTERNATIVE_DROP_MUTANT", "10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_SOURCE_SUBJECT_ORDER_MUTANT", "10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_SOURCE_SUBJECT_PROJECTION_DROP_MUTANT", "11000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SHA256_INPUT_ROUTE_MUTANT", "11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111110111111111111111111111111111111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_DEPENDENCY_SUBJECT_LABEL_MAPPING_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_DEPENDENCY_SUBJECT_ROUTE_DROP_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_ROOT_SUBJECT_ORDER_MUTANT", "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
  ]

routingAuditSelectorSupplementalImpactSignatures :: [(String, String)]
routingAuditSelectorSupplementalImpactSignatures =
  [ ("VALIDATION_COMPILER_ELABORATED_PLAN_BUILD_ARTIFACT_LOCAL_ORIGIN_ALTERNATIVE_DROP_MUTANT", "00000011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BUILD_ARTIFACT_PRE_EXISTING_ORIGIN_EXCLUSION_BYPASS_MUTANT", "00000011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BUILD_ARTIFACT_REMOTE_ORIGIN_ALTERNATIVE_DROP_MUTANT", "00000011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BUILD_ARTIFACT_SUBJECT_ORDER_MUTANT", "00000011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_BUILD_ARTIFACT_SUBJECT_PROJECTION_DROP_MUTANT", "00000011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_DEPENDENCY_SUBJECT_LABEL_MAPPING_MUTANT", "00000011000000000000000000000000010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_DEPENDENCY_SUBJECT_ROUTE_DROP_MUTANT", "00000011000000000000000000000000010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_EXECUTABLE_DEPENDENCY_SUBJECT_LABEL_MAPPING_MUTANT", "00000000000000000000000000000000010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_EXECUTABLE_DEPENDENCY_SUBJECT_ROUTE_DROP_MUTANT", "00000000000000000000000000000000010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNIVERSE_GLOBAL_STYLE_EXCLUSION_BYPASS_MUTANT", "00000011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNIVERSE_INPLACE_STYLE_ALTERNATIVE_DROP_MUTANT", "00000000000000000000000000000000010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNIVERSE_LOCAL_STYLE_ALTERNATIVE_DROP_MUTANT", "00000011000000000000000000000000010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNIVERSE_SUBJECT_ORDER_MUTANT", "00000000000000000000000000000000010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNIVERSE_SUBJECT_PROJECTION_DROP_MUTANT", "00000011000000000000000000000000010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CONFIGURATION_GLOBAL_STYLE_ALTERNATIVE_DROP_MUTANT", "00000011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CONFIGURATION_INPLACE_STYLE_ALTERNATIVE_DROP_MUTANT", "00000000000000000000000000000000010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CONFIGURATION_LOCAL_STYLE_ALTERNATIVE_DROP_MUTANT", "00000011000000000000000000000000010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CONFIGURATION_PRE_EXISTING_STYLE_EXCLUSION_BYPASS_MUTANT", "00000011000000000000000000000000010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CONFIGURATION_SUBJECT_ORDER_MUTANT", "00000011000000000000000000000000010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CONFIGURATION_SUBJECT_PROJECTION_DROP_MUTANT", "00000011000000000000000000000000010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_SUBJECT_ORDER_MUTANT", "00000011000000000000000000000000010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_SUBJECT_PROJECTION_DROP_MUTANT", "00000011000000000000000000000000010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_ROOT_LOCAL_ORIGIN_ALTERNATIVE_DROP_MUTANT", "00000011000000000000000000000000001")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_ROOT_SUBJECT_PROJECTION_DROP_MUTANT", "00000011000000000000000000000000001")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_MALFORMED_FOLD_INPUT_BYTES_PROJECTION_MUTANT", "00000000000000000011111111111111000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_MALFORMED_FOLD_PROBLEMS_PROJECTION_MUTANT", "00000000000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_ARCHITECTURE_PROJECTION_MUTANT", "00100101000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_CABAL_LIBRARY_VERSION_PROJECTION_MUTANT", "00110001000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_CABAL_VERSION_PROJECTION_MUTANT", "00110001000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_COMPILER_ABI_PROJECTION_MUTANT", "00101001000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_COMPILER_ID_PROJECTION_MUTANT", "00101001000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_DIGEST_PROJECTION_MUTANT", "01000000100000000000000000000000111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_INPUT_BYTES_PROJECTION_MUTANT", "01000000100000000000000000000000111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_OPERATING_SYSTEM_PROJECTION_MUTANT", "00100101000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_OBSERVED_FOLD_PROBLEMS_PROJECTION_MUTANT", "00000011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_SOURCE_LOCAL_ORIGIN_ALTERNATIVE_DROP_MUTANT", "00000011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_SOURCE_PRE_EXISTING_ORIGIN_EXCLUSION_BYPASS_MUTANT", "00000011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_SOURCE_REMOTE_ORIGIN_ALTERNATIVE_DROP_MUTANT", "00000011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_SOURCE_SUBJECT_ORDER_MUTANT", "00000011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_SOURCE_SUBJECT_PROJECTION_DROP_MUTANT", "00000011000000000000000000000000000")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SHA256_INPUT_ROUTE_MUTANT", "01000000100000000011111111111111111")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_DEPENDENCY_SUBJECT_LABEL_MAPPING_MUTANT", "00000000000000000000000000000000010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_UNIT_DEPENDENCY_SUBJECT_ROUTE_DROP_MUTANT", "00000000000000000000000000000000010")
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_ROOT_SUBJECT_ORDER_MUTANT", "00000000000000000000000000000000001")
  ]

legacyAuditImpactRegistry :: [(String, [String])]
legacyAuditImpactRegistry =
  [ ("VALIDATION_COMPILER_ELABORATED_PLAN_PUBLIC_REFUSAL_BYPASS_MUTANT", ["source-repository global projection retains kind, repository type, location, and tag","source-repository inplace style remains distinct"])
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_CABAL_SCHEMA_VERSION_BYPASS_MUTANT", ["platform tokens retain the hyphen character alternative","platform tokens retain the underscore character alternative"])
  , ( "VALIDATION_COMPILER_ELABORATED_PLAN_UNKNOWN_DEPENDENCY_GUARD_BYPASS_MUTANT"
    , [ "the admitted component alternative remains exact: lib"
      , "the admitted component alternative remains exact: setup"
      , "the admitted component alternative remains exact: lib:core"
      , "the admitted component alternative remains exact: exe:tool"
      , "the admitted component alternative remains exact: test:spec"
      , "the admitted component alternative remains exact: bench:perf"
      , "the admitted component alternative remains exact: lib:core.name"
      , "the admitted component alternative remains exact: lib:core-name"
      , "the admitted component alternative remains exact: lib:core_name"
      ]
    )
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_SHA256_CHARACTER_BYPASS_MUTANT", ["SHA-256 lower-hex alphabetic alternative remains admitted","SHA-256 lower-hex digit alternative remains admitted"])
  , ("VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_BUILTIN_BYPASS_MUTANT", ["the admitted flag alternative remains exact: variant-name","the admitted flag alternative remains exact: variant_name"])
  ]


-- These two literal inventories retain the original primary exact-case
-- declarations and independently name every later executable case.
selectorExactCaseLabels :: [String]
selectorExactCaseLabels =
  [ "the same-library public positive client observes the one exact always-refusing CheckResult"
  , "duplicate root keys are rejected before object normalization"
  , "one byte beyond the input ceiling is refused before tokenization"
  , "the first token beyond the token ceiling is refused exactly"
  , "one duplicate problem beyond the problem ceiling is refused exactly"
  , "one container beyond the nesting ceiling is refused exactly"
  , "one decoded character beyond the text ceiling is refused exactly"
  , "one code point beyond the JSON key-text ceiling is refused before decoding"
  , "one element beyond the collection ceiling is refused exactly"
  , "one generic object member beyond the ceiling is refused before decoding"
  , "one install unit beyond the unit ceiling is refused before unit traversal"
  , "one component beyond the component ceiling is refused before member traversal"
  , "one dependency beyond the dependency ceiling is refused before edge traversal"
  , "one flag beyond the flag ceiling is refused before flag traversal"
  , "one source-object member beyond the ceiling is refused before source traversal"
  , "one semantic problem beyond the ceiling refuses before further traversal"
  , "one semantic-scalar byte beyond the ceiling is refused at the exact flag key"
  , "one source-locator byte beyond the ceiling is refused at the locator locus"
  , "one path byte beyond the ceiling is refused at the path locus"
  , "one path segment beyond the ceiling is refused at the path locus"
  , "one path-member byte beyond the ceiling is refused at the path locus"
  , "the aggregate component ceiling counts direct components across unit boundaries before rendering"
  , "the aggregate dependency ceiling counts root executable edges before traversal"
  , "the aggregate dependency ceiling counts nested ordinary edges before traversal"
  , "the aggregate dependency ceiling counts nested executable edges before traversal"
  , "an unsupported install-unit discriminator is exact"
  , "the Cabal schema version is an exact closed alternative"
  , "the Cabal library schema version is an independently exact closed alternative"
  , "the local build-info and dist-directory paths remain exact diagnostic values"
  , "aggregate units reject a top-level ordinary dependency instead of ignoring it"
  , "aggregate units reject a top-level executable dependency instead of ignoring it"
  , "an inplace configured unit without its build-info path is refused"
  , "a local configured unit without its dist directory is refused"
  , "a global library rejects an impossible local build-info path"
  , "a global unit independently forbids a dist-directory path"
  , "an executable requires its retained binary path"
  , "a library rejects an unexpected binary path"
  , "a configured unit must state one component shape"
  , "configured units cannot present both direct and aggregate component shapes"
  , "an unsupported package-source discriminator is exact"
  , "repository-tar accepts only the frozen secure-repo subtype"
  , "source-repo accepts only the frozen Git subtype"
  , "a local source cannot claim the global build style"
  , "changing a local source declaration to a remote package type cannot retain local style"
  , "an unsupported configured style is exact"
  , "a two-unit dependency cycle is refused as one closed identity set"
  , "a duplicate ordinary dependency remains an exact edge-locus defect"
  , "a self dependency is both the exact edge defect and a unit cycle"
  , "a dependency swap to an absent unit id cannot remain a closed graph"
  , "the exact observed-result ceiling retains fifteen mandatory refusals and 113 exact source-path rows"
  , "the first observed variable row beyond the result ceiling retains every mandatory refusal before one exact limit row"
  , "a local source independently forbids a claimed Cabal hash"
  , "local sources reject an unexpected claimed source hash"
  , "a missing remote source hash is explicit"
  , "a missing repository Cabal hash is explicit"
  , "source repositories reject an unexpected Cabal hash"
  , "a source repository independently requires its source hash"
  , "a SHA-256 identity rejects width 63 exactly"
  , "a SHA-256 identity rejects a non-lower-hex symbol exactly"
  , "a Git SHA-1 identity rejects width 39 exactly"
  , "a Git SHA-256 identity rejects width 63 independently"
  , "a Git object identity rejects a non-lower-hex symbol exactly"
  , "the aggregate component alternative has one exact ordered digest-bound public refusal"
  , "a component builtin is drawn from the exact closed set"
  , "a qualified component prefix is drawn from the exact closed set"
  , "a qualified component suffix rejects a leading punctuation boundary"
  , "a qualified component suffix rejects a trailing punctuation boundary"
  , "a qualified component suffix rejects an independently forbidden character"
  , "the compiler identifier prefix is exact"
  , "a portable identity rejects a leading punctuation boundary independently"
  , "a portable identity rejects a trailing punctuation boundary independently"
  , "a portable identity rejects an independently forbidden character"
  , "a platform token rejects a leading punctuation boundary independently"
  , "a platform token rejects a trailing punctuation boundary independently"
  , "a platform token rejects an independently forbidden character"
  , "a package name rejects an empty hyphen-delimited segment"
  , "a package name rejects an independently forbidden segment character"
  , "a package version rejects an empty decimal segment"
  , "a package version rejects an independently non-decimal symbol"
  , "a flag name rejects a leading punctuation boundary independently"
  , "a flag name rejects a trailing punctuation boundary independently"
  , "a flag name rejects an independently forbidden character"
  , "source scheme"
  , "source payload"
  , "source lower visible-character bound"
  , "source upper ASCII-character bound"
  , "source backslash"
  , "path absolute marker"
  , "path lower visible-character bound"
  , "path upper ASCII-character bound"
  , "path backslash"
  , "path colon"
  , "path empty trailing segment"
  , "path parent segment"
  , "path dot-segment position"
  ]

selectorAdditionalExactCaseLabels :: [String]
selectorAdditionalExactCaseLabels =
  [ "three equal root keys retain both duplicate occurrences"
  , "duplicate unit keys are rejected at their exact array-object scope"
  , "duplicate nested repository keys are rejected before nested object normalization"
  , "escaped-equivalent root keys are duplicate decoded identities"
  , "duplicate nested component keys retain an unambiguous quoted scope"
  , "component names follow the closed Cabal-plan grammar"
  , "aggregate nested dependencies reject unknown unit identities"
  , "an unknown executable dependency retains its executable-edge locus"
  , "a malformed repository Cabal hash is one exact identity defect"
  , "a mutable source-repository tag is not accepted as an immutable source identity"
  , "an unknown local compiler input is unsupported schema"
  , "the compiler numeric version rejects an empty segment independently"
  , "the compiler numeric version rejects a non-decimal symbol independently"
  , "the path root alternative is admitted before the independent probe refusal"
  , "the final dot-segment alternative is admitted before the independent probe refusal"
  , "the Git SHA-256 width alternative reaches semantic plan analysis"
  , "the exact nesting ceiling reaches the exact decoded root refusal"
  , "the exact decoded-text ceiling reaches the exact decoded root refusal"
  , "the exact generic-array ceiling reaches the exact decoded root refusal"
  , "the exact generic-object-member ceiling reaches the semantic problem cap"
  , "exactly one million structural tokens reach the decoded root refusal"
  , "the exact duplicate-problem ceiling retains every duplicate finding"
  , "the exact unit ceiling reaches the independently smaller problem ceiling"
  , "the exact dependency ceiling reaches the independently smaller problem ceiling"
  , "the exact flag ceiling retains every exact flag-value locus"
  , "the exact source-object member ceiling reaches closed-schema parsing"
  , "the exact semantic-scalar byte ceiling reaches the flag value-type refusal"
  , "the exact source-locator byte ceiling reaches the independent repository-type refusal"
  , "the exact path byte ceiling reaches the independent unknown-field refusal"
  , "the exact path-segment ceiling reaches the independent unknown-field refusal"
  , "the exact path-member byte ceiling reaches the independent unknown-field refusal"
  , "minimal closed-schema plan was rejected"
  , "the complete accepted semantic snapshot is independently literal and input-bound"
  , "the parser freezes both Cabal plan schema versions"
  , "compiler identity is read from the immutable plan bytes"
  , "platform retains the exact architecture and operating-system pair"
  , "missing local source ownership is precise typed residue, not an empty-path claim"
  , "the complete public diagnostic wire is exact, ordered, digest-bound, and permanently refusing"
  , "the local component and its exact dependency unit ids are retained"
  , "Cabal 3.16 plan JSON supplies no component source paths"
  , "pre-existing, remote, and local units remain distinct"
  , "every exact unit id is retained"
  , "package provenance and Cabal build style remain separate"
  , "selected local flags remain exact typed values"
  , "the remote repository location is bound separately from a local source root"
  , "the local package root is retained without normalization or invention"
  , "multiple local roots retain deterministic subject order"
  ]

selectorImpactRegistry :: [(String, [String])]
selectorImpactRegistry =
  [ ( "VALIDATION_COMPILER_ELABORATED_PLAN_PUBLIC_REFUSAL_BYPASS_MUTANT"
    , [ "minimal closed-schema plan was rejected"
      , "the aggregate component alternative has one exact ordered digest-bound public refusal"
      , "the exact observed-result ceiling retains fifteen mandatory refusals and 113 exact source-path rows"
      , "the first observed variable row beyond the result ceiling retains every mandatory refusal before one exact limit row"
      , "multiple flags retain deterministic lexical order"
      ]
    )
  , ( "VALIDATION_COMPILER_ELABORATED_PLAN_JSON_TOKEN_LIMIT_BYPASS_MUTANT"
    , ["a record closing token is counted at the exact global token boundary"]
    )
  , ( "VALIDATION_COMPILER_ELABORATED_PLAN_GLOBAL_BUILD_INFO_GUARD_BYPASS_MUTANT"
    , [ "an empty optional path is refused before field-combination analysis"
      , "a mistyped optional path is refused before field-combination analysis"
      ]
    )
  , ( "VALIDATION_COMPILER_ELABORATED_PLAN_BINARY_PATH_PRESENCE_BYPASS_MUTANT"
    , [ "a test component independently requires its binary path"
      , "a benchmark component independently requires its binary path"
      ]
    )
  , ( "VALIDATION_COMPILER_ELABORATED_PLAN_PORTABLE_IDENTITY_CHARACTER_BYPASS_MUTANT"
    , ["a dependency identity is checked by the shared constrained-text grammar"]
    )
  , ( "VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_KEY_BYPASS_MUTANT"
    , [ "three equal root keys retain both duplicate occurrences"
      , "duplicate flag keys are rejected at their exact nested scope"
      , "duplicate unit keys are rejected at their exact array-object scope"
      , "duplicate nested repository keys are rejected before nested object normalization"
      , "escaped-equivalent root keys are duplicate decoded identities"
      , "duplicate nested component keys retain an unambiguous quoted scope"
      , "the exact duplicate-problem ceiling retains every duplicate finding"
      , "one duplicate problem beyond the problem ceiling is refused exactly"
      ]
    )
  , ( "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_LIMIT_BYPASS_MUTANT"
    , ["the aggregate component ceiling counts direct components across unit boundaries before rendering"]
    )
  , ( "VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_LIMIT_BYPASS_MUTANT"
    , [ "the aggregate dependency ceiling counts root executable edges before traversal"
      , "the aggregate dependency ceiling counts nested ordinary edges before traversal"
      , "the aggregate dependency ceiling counts nested executable edges before traversal"
      ]
    )
  , ( "VALIDATION_COMPILER_ELABORATED_PLAN_SEMANTIC_PROBLEM_LIMIT_BYPASS_MUTANT"
    , [ "the exact generic-object-member ceiling reaches the semantic problem cap"
      , "the exact unit ceiling reaches the independently smaller problem ceiling"
      , "the exact dependency ceiling reaches the independently smaller problem ceiling"
      ]
    )
  , ( "VALIDATION_COMPILER_ELABORATED_PLAN_ROOT_DEPENDS_COUNT_DROP_MUTANT"
    , ["the aggregate dependency ceiling counts root executable edges before traversal"]
    )
  , ( "VALIDATION_COMPILER_ELABORATED_PLAN_ACCEPTED_FIELD_BINDING_MUTANT"
    , [ "the same-library public positive client observes the one exact always-refusing CheckResult"
      , "the complete accepted semantic snapshot is independently literal and input-bound"
      , "missing local source ownership is precise typed residue, not an empty-path claim"
      , "the complete public diagnostic wire is exact, ordered, digest-bound, and permanently refusing"
      , "the aggregate component alternative has one exact ordered digest-bound public refusal"
      , "the exact observed-result ceiling retains fifteen mandatory refusals and 113 exact source-path rows"
      , "the first observed variable row beyond the result ceiling retains every mandatory refusal before one exact limit row"
      ]
    )
  , ( "VALIDATION_COMPILER_ELABORATED_PLAN_REPOSITORY_TYPE_BYPASS_MUTANT"
    , [ "source scheme"
      , "source payload"
      , "source lower visible-character bound"
      , "source upper ASCII-character bound"
      , "source backslash"
      , "the exact source-locator byte ceiling reaches the independent repository-type refusal"
      , "one source-locator byte beyond the ceiling is refused at the locator locus"
      ]
    )
  , ( "VALIDATION_COMPILER_ELABORATED_PLAN_CYCLE_GUARD_BYPASS_MUTANT"
    , [ "aggregate nested self dependencies retain both edge and cycle defects"
      , "a self dependency is both the exact edge defect and a unit cycle"
      ]
    )
  , ( "VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_DEPENDENCY_GUARD_BYPASS_MUTANT"
    , [ "aggregate nested dependencies reject duplicate edges at the component locus"
      , "a duplicate executable dependency remains distinct from an ordinary edge defect"
      ]
    )
  , ( "VALIDATION_COMPILER_ELABORATED_PLAN_SELF_DEPENDENCY_GUARD_BYPASS_MUTANT"
    , ["aggregate nested self dependencies retain both edge and cycle defects"]
    )
  , ( "VALIDATION_COMPILER_ELABORATED_PLAN_UNKNOWN_DEPENDENCY_GUARD_BYPASS_MUTANT"
    , [ "aggregate nested dependencies reject unknown unit identities"
      , "an unknown executable dependency retains its executable-edge locus"
      , "the exact dependency ceiling reaches the independently smaller problem ceiling"
      , "pre-existing unit dependencies remain projected into invariant checks"
      ]
    )
  , ( "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_SHAPE_COLLAPSE_MUTANT"
    , [ "the exact observed-result ceiling retains fifteen mandatory refusals and 113 exact source-path rows"
      , "the first observed variable row beyond the result ceiling retains every mandatory refusal before one exact limit row"
      ]
    )
  , ( "VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_VERSION_SEGMENT_BYPASS_MUTANT"
    , [ "compiler identities require the closed ghc numeric-version grammar"
      , "the compiler numeric version rejects an empty segment independently"
      ]
    )
  , ( "VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_VERSION_DIGIT_BYPASS_MUTANT"
    , ["the compiler numeric version rejects a non-decimal symbol independently"]
    )
  , ( "VALIDATION_COMPILER_ELABORATED_PLAN_PATH_ABSOLUTE_BYPASS_MUTANT"
    , ["local source roots require the bounded absolute path grammar"]
    )
  ]
    <> [ (selector, observedPermanentImpactLabels)
       | selector <- observedPermanentImpactSelectors
       ]
    <> legacyAuditImpactRegistry

observedPermanentImpactSelectors :: [String]
observedPermanentImpactSelectors =
  [ "VALIDATION_COMPILER_ELABORATED_PLAN_SOURCE_PATH_RESIDUE_DROP_MUTANT"
  , "VALIDATION_COMPILER_ELABORATED_PLAN_INPUT_AUTHENTICATION_RESIDUE_BYPASS_MUTANT"
  , "VALIDATION_COMPILER_ELABORATED_PLAN_ARTIFACT_GENERATION_RESIDUE_BYPASS_MUTANT"
  , "VALIDATION_COMPILER_ELABORATED_PLAN_EXPECTED_COMPILER_IDENTITY_RESIDUE_BYPASS_MUTANT"
  , "VALIDATION_COMPILER_ELABORATED_PLAN_EXPECTED_PLATFORM_IDENTITY_RESIDUE_BYPASS_MUTANT"
  , "VALIDATION_COMPILER_ELABORATED_PLAN_DUPLICATE_KEY_OBSERVATION_RESIDUE_BYPASS_MUTANT"
  , "VALIDATION_COMPILER_ELABORATED_PLAN_COMPONENT_UNIVERSE_RESIDUE_BYPASS_MUTANT"
  , "VALIDATION_COMPILER_ELABORATED_PLAN_CONFIGURATION_BRANCH_CLOSURE_RESIDUE_BYPASS_MUTANT"
  , "VALIDATION_COMPILER_ELABORATED_PLAN_CPP_BRANCH_CLOSURE_RESIDUE_BYPASS_MUTANT"
  , "VALIDATION_COMPILER_ELABORATED_PLAN_DEPENDENCY_SEMANTICS_RESIDUE_BYPASS_MUTANT"
  , "VALIDATION_COMPILER_ELABORATED_PLAN_PACKAGE_SOURCE_BYTES_IDENTITY_RESIDUE_BYPASS_MUTANT"
  , "VALIDATION_COMPILER_ELABORATED_PLAN_BUILD_ARTIFACT_PATH_IDENTITY_RESIDUE_BYPASS_MUTANT"
  , "VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_ROOT_LEXICAL_RESIDUE_BYPASS_MUTANT"
  , "VALIDATION_COMPILER_ELABORATED_PLAN_LOCAL_SOURCE_ROOT_FILESYSTEM_RESIDUE_BYPASS_MUTANT"
  , "VALIDATION_COMPILER_ELABORATED_PLAN_SNAPSHOT_BINDING_RESIDUE_BYPASS_MUTANT"
  , "VALIDATION_COMPILER_ELABORATED_PLAN_DIAGNOSTIC_RESIDUE_BYPASS_MUTANT"
  , "VALIDATION_COMPILER_ELABORATED_PLAN_MANDATORY_PREFIX_DROP_MUTANT"
  ]

observedPermanentImpactLabels :: [String]
observedPermanentImpactLabels =
  [ "the same-library public positive client observes the one exact always-refusing CheckResult"
  , "missing local source ownership is precise typed residue, not an empty-path claim"
  , "the complete public diagnostic wire is exact, ordered, digest-bound, and permanently refusing"
  , "the aggregate component alternative has one exact ordered digest-bound public refusal"
  , "the first observed variable row beyond the result ceiling retains every mandatory refusal before one exact limit row"
  , "source-repository inplace style remains distinct"
  ]

selectorIntentRegistryProblems :: [String]
selectorIntentRegistryProblems =
  concat
    [ expectEqual
        "the oracle owns exactly 342 CompilerElaboratedPlan selector intents"
        342
        (length selectorIntentRegistry)
    , expectEqual
        "the oracle selector-intent inventory contains no duplicate selector"
        []
        (duplicateStrings selectorNames)
    , expectEqual
        "the independently declared selector exact-case list contains no duplicate label"
        []
        (duplicateStrings selectorExactCaseLabels)
    , expectEqual
        "the oracle owns exactly 205 executable CompilerElaboratedPlan cases"
        205
        (length allExecutableExactCaseLabels)
    , expectEqual
        "the executable CompilerElaboratedPlan case inventory contains no duplicate label"
        []
        (duplicateStrings allExecutableExactCaseLabels)
    , expectEqual
        "the legacy group owns exactly 114 literal selector impact signatures"
        114
        (length legacySelectorImpactSignatures)
    , expectEqual
        "the legacy impact signatures have the exact first 114 selector identities"
        [selector | SelectorIntent selector _ <- take 114 selectorIntentRegistry]
        legacySignatureSelectors
    , expectEqual
        "the legacy selector impact signatures contain no duplicate selector"
        []
        (duplicateStrings legacySignatureSelectors)
    , expectEqual
        "the legacy group owns exactly 114 literal supplemental impact signatures"
        114
        (length legacySelectorSupplementalImpactSignatures)
    , expectEqual
        "the legacy supplemental impact signatures have the same selector inventory"
        legacySignatureSelectors
        (map fst legacySelectorSupplementalImpactSignatures)
    , expectEqual
        "the expansion owns exactly 131 literal selector impact signatures"
        131
        (length updatedNewSelectorImpactSignatures)
    , expectEqual
        "the expansion selector impact signatures contain no duplicate selector"
        []
        (duplicateStrings signatureSelectors)
    , expectEqual
        "the expansion owns exactly 131 updated literal supplemental impact signatures"
        131
        (length updatedNewSelectorSupplementalImpactSignatures)
    , expectEqual
        "the supplemental impact signatures have the same selector inventory"
        signatureSelectors
        (map fst updatedNewSelectorSupplementalImpactSignatures)
    , expectEqual
        "the post-matrix audit owns exactly 53 literal selector impact signatures"
        53
        (length auditSelectorImpactSignatures)
    , expectEqual
        "the post-matrix audit selector impact signatures contain no duplicate selector"
        []
        (duplicateStrings auditSignatureSelectors)
    , expectEqual
        "the post-matrix audit owns exactly 53 literal supplemental impact signatures"
        53
        (length auditSelectorSupplementalImpactSignatures)
    , expectEqual
        "the post-matrix audit supplemental signatures have the same selector inventory"
        auditSignatureSelectors
        (map fst auditSelectorSupplementalImpactSignatures)
    , expectEqual
        "the routing audit owns exactly 44 literal selector impact signatures"
        44
        (length routingAuditSelectorImpactSignatures)
    , expectEqual
        "the routing audit selector impact signatures contain no duplicate selector"
        []
        (duplicateStrings routingAuditSignatureSelectors)
    , expectEqual
        "the routing audit owns exactly 44 literal supplemental impact signatures"
        44
        (length routingAuditSelectorSupplementalImpactSignatures)
    , expectEqual
        "the routing audit supplemental signatures have the same selector inventory"
        routingAuditSignatureSelectors
        (map fst routingAuditSelectorSupplementalImpactSignatures)
    , expectEqual
        "the superseded 131-row main signature checkpoint remains a closed historical diagnostic"
        131
        (length newSelectorImpactSignatures)
    , expectEqual
        "the superseded 131-row supplemental signature checkpoint remains a closed historical diagnostic"
        131
        (length newSelectorSupplementalImpactSignatures)
    , [ "selector intent " <> selector <> " must reference exactly one independently declared exact case, but label " <> show target <> " occurs " <> show count <> " times"
      | SelectorIntent selector target <- selectorIntentRegistry
      , let count = occurrenceCount target allExecutableExactCaseLabels
      , count /= 1
      ]
    , [ "independently declared selector exact case is not referenced by any selector intent: " <> show target
      | target <- selectorExactCaseLabels
      , target `notElem` targetNames
      ]
    , [ "impact registry selector must occur exactly once in the primary selector registry: " <> selector
      | (selector, _) <- selectorImpactRegistry
      , occurrenceCount selector selectorNames /= 1
      ]
    , [ "selector impact registry contains a duplicate exact-case label: selector=" <> selector <> "; exact-case=" <> target
      | (selector, targets) <- selectorImpactRegistry
      , target <- duplicateStrings targets
      ]
    , [ "selector impact repeats its primary exact case: selector=" <> selector <> "; exact-case=" <> target
      | (selector, targets) <- selectorImpactRegistry
      , target <- targets
      , target `elem` [primary | SelectorIntent candidate primary <- selectorIntentRegistry, candidate == selector]
      ]
    , [ "selector impact references an undeclared executable exact case: selector=" <> selector <> "; exact-case=" <> target
      | (selector, targets) <- selectorImpactRegistry
      , target <- targets
      , occurrenceCount target allExecutableExactCaseLabels /= 1
      ]
    , [ "additional executable exact case is not referenced by a declared selector impact: " <> show target
      | target <- selectorAdditionalExactCaseLabels
      , target `notElem` allDeclaredSelectorImpactTargets
      ]
    , [ "declared legacy exact case is absent from the complete executable case inventory: " <> show target
      | target <- allDeclaredExactCaseLabels
      , occurrenceCount target allExecutableExactCaseLabels /= 1
      ]
    , [ "expansion selector impact signature must occur exactly once in the primary selector registry: " <> selector
      | selector <- signatureSelectors
      , occurrenceCount selector selectorNames /= 1
      ]
    , [ "expansion selector is missing its one literal impact signature: " <> selector
      | SelectorIntent selector _ <- newSelectorIntents
      , occurrenceCount selector signatureSelectors /= 1
      ]
    , [ "post-matrix audit selector is missing its one literal impact signature: " <> selector
      | SelectorIntent selector _ <- auditSelectorIntents
      , occurrenceCount selector auditSignatureSelectors /= 1
      ]
    , [ "routing audit selector is missing its one literal impact signature: " <> selector
      | SelectorIntent selector _ <- routingAuditSelectorIntents
      , occurrenceCount selector routingAuditSignatureSelectors /= 1
      ]
    , [ "legacy selector impact signature must contain exactly 170 binary digits: selector=" <> selector <> "; length=" <> show (length signature)
      | (selector, signature) <- legacySelectorImpactSignatures
      , length signature /= length signatureExactCaseLabels
          || any (`notElem` ['0', '1']) signature
      ]
    , [ "legacy supplemental selector impact signature must match the exact supplemental case inventory: selector=" <> selector <> "; length=" <> show (length signature)
      | (selector, signature) <- legacySelectorSupplementalImpactSignatures
      , length signature /= length supplementalExactCaseLabels
          || any (`notElem` ['0', '1']) signature
      ]
    , [ "selector impact signature must contain exactly 170 binary digits: selector=" <> selector <> "; length=" <> show (length signature)
      | (selector, signature) <- updatedNewSelectorImpactSignatures
      , length signature /= length signatureExactCaseLabels
          || any (`notElem` ['0', '1']) signature
      ]
    , [ "supplemental selector impact signature must match the exact supplemental case inventory: selector=" <> selector <> "; length=" <> show (length signature)
      | (selector, signature) <- updatedNewSelectorSupplementalImpactSignatures
      , length signature /= length supplementalExactCaseLabels
          || any (`notElem` ['0', '1']) signature
      ]
    , [ "post-matrix audit selector impact signature must contain exactly 170 binary digits: selector=" <> selector <> "; length=" <> show (length signature)
      | (selector, signature) <- auditSelectorImpactSignatures
      , length signature /= length signatureExactCaseLabels
          || any (`notElem` ['0', '1']) signature
      ]
    , [ "post-matrix audit supplemental selector impact signature must match the exact supplemental case inventory: selector=" <> selector <> "; length=" <> show (length signature)
      | (selector, signature) <- auditSelectorSupplementalImpactSignatures
      , length signature /= length supplementalExactCaseLabels
          || any (`notElem` ['0', '1']) signature
      ]
    , [ "routing audit selector impact signature must contain exactly 170 binary digits: selector=" <> selector <> "; length=" <> show (length signature)
      | (selector, signature) <- routingAuditSelectorImpactSignatures
      , length signature /= length signatureExactCaseLabels
          || any (`notElem` ['0', '1']) signature
      ]
    , [ "routing audit supplemental selector impact signature must match the exact supplemental case inventory: selector=" <> selector <> "; length=" <> show (length signature)
      | (selector, signature) <- routingAuditSelectorSupplementalImpactSignatures
      , length signature /= length supplementalExactCaseLabels
          || any (`notElem` ['0', '1']) signature
      ]
    , [ "selector impact signature omits its primary exact case: selector=" <> selector <> "; exact-case=" <> target
      | SelectorIntent selector target <- newSelectorIntents
      , target `notElem` decodedSelectorImpactTargets selector
      ]
    , [ "post-matrix audit selector impact signature omits its primary exact case: selector=" <> selector <> "; exact-case=" <> target
      | SelectorIntent selector target <- auditSelectorIntents
      , target `notElem` decodedSelectorImpactTargets selector
      ]
    , [ "routing audit selector impact signature omits its primary exact case: selector=" <> selector <> "; exact-case=" <> target
      | SelectorIntent selector target <- routingAuditSelectorIntents
      , target `notElem` decodedSelectorImpactTargets selector
      ]
    , [ "legacy selector impact signature omits its primary exact case: selector=" <> selector <> "; exact-case=" <> target
      | SelectorIntent selector target <- take 114 selectorIntentRegistry
      , target `notElem` decodedSelectorImpactTargets selector
      ]
    ]
 where
  selectorNames = [selector | SelectorIntent selector _ <- selectorIntentRegistry]
  targetNames = [target | SelectorIntent _ target <- selectorIntentRegistry]
  allDeclaredExactCaseLabels = selectorExactCaseLabels <> selectorAdditionalExactCaseLabels
  allDeclaredSelectorImpactTargets =
    concatMap snd selectorImpactRegistry
      <> concatMap decodedSelectorImpactTargets (legacySignatureSelectors <> signatureSelectors <> auditSignatureSelectors <> routingAuditSignatureSelectors)
  legacySignatureSelectors = map fst legacySelectorImpactSignatures
  signatureSelectors = map fst updatedNewSelectorImpactSignatures
  auditSignatureSelectors = map fst auditSelectorImpactSignatures
  routingAuditSignatureSelectors = map fst routingAuditSelectorImpactSignatures

duplicateStrings :: [String] -> [String]
duplicateStrings = go []
 where
  go _ [] = []
  go seen (value : remaining)
    | value `elem` seen = value : go seen remaining
    | otherwise = go (value : seen) remaining

occurrenceCount :: Eq value => value -> [value] -> Int
occurrenceCount needle = length . filter (== needle)

runCompilerElaboratedPlanOracle :: IO ()
runCompilerElaboratedPlanOracle =
  finishDiagnostics
    "CompilerElaboratedPlanOracle"
    (selectorIntentRegistryProblems <> compilerElaboratedPlanExactProblems)

compilerElaboratedPlanSelectorNames :: [String]
compilerElaboratedPlanSelectorNames =
  [selector | SelectorIntent selector _ <- selectorIntentRegistry]

compilerElaboratedPlanExactCaseLabels :: [String]
compilerElaboratedPlanExactCaseLabels = allExecutableExactCaseLabels

compilerElaboratedPlanAffectedExactCaseLabels :: [String]
compilerElaboratedPlanAffectedExactCaseLabels =
  [ label
  | label <- allExecutableExactCaseLabels
  , not (null (problemsForTarget label))
  ]

-- A selector run observes the complete oracle so every unassigned exact case
-- remains an executed same-harness control.  A changed subject is admissible
-- only when all emitted differences carry its independently literal target
-- label; the matrix driver separately requires that target to turn red.
runCompilerElaboratedPlanSelectorOracle :: String -> IO ()
runCompilerElaboratedPlanSelectorOracle selector =
  case selectorTargets selector of
    [target] -> do
      let affectedTargets = selectorAffectedTargets selector
          assignedProblems = problemsForTargets affectedTargets
          unaffectedProblems = problemsOutsideTargets affectedTargets
      unless (null selectorIntentRegistryProblems) $
        failDiagnostic "registry-control" selectorIntentRegistryProblems
      unless (null unaffectedProblems) $
        failDiagnostic "wrong-locus" (summarizeProblemLabels unaffectedProblems)
      unless (null assignedProblems) $
        failDiagnostic ("assigned-locus:" <> target) (summarizeProblemLabels assignedProblems)
    targets ->
      failDiagnostic
        "unresolvable-selector"
        ["selector=" <> selector, "targets=" <> show targets]

-- This inverse check is run only against the changed subject.  It proves that
-- the declared exact case itself turned red rather than accepting an exit from
-- an unrelated assertion or from the compiler.
runCompilerElaboratedPlanSelectorImpactOracle :: String -> IO ()
runCompilerElaboratedPlanSelectorImpactOracle selector =
  case selectorTargets selector of
    [_] -> do
      unless (null selectorIntentRegistryProblems) $
        failDiagnostic "registry-control" selectorIntentRegistryProblems
      let missingImpacts =
            [ "declared impacted exact case remained green: selector="
                <> selector
                <> "; exact-case="
                <> affectedTarget
            | affectedTarget <- selectorAffectedTargets selector
            , null (problemsForTarget affectedTarget)
            ]
      unless (null missingImpacts) (failDiagnostic "declared-impact" missingImpacts)
    targets ->
      failDiagnostic
        "unresolvable-selector"
        ["selector=" <> selector, "targets=" <> show targets]

runCompilerElaboratedPlanSelectorIsolationOracle :: String -> IO ()
runCompilerElaboratedPlanSelectorIsolationOracle selector =
  case selectorTargets selector of
    [_] -> do
      let problems =
            selectorIntentRegistryProblems
              <> problemsOutsideTargets (selectorAffectedTargets selector)
      unless (null problems) (failDiagnostic "unaffected-control" (summarizeProblemLabels problems))
    targets ->
      failDiagnostic
        "unresolvable-selector"
        ["selector=" <> selector, "targets=" <> show targets]

selectorTargets :: String -> [String]
selectorTargets selector =
  [target | SelectorIntent candidate target <- selectorIntentRegistry, candidate == selector]

selectorAffectedTargets :: String -> [String]
selectorAffectedTargets selector = case decodedSelectorImpactTargets selector of
  [] ->
    selectorTargets selector
      <> concat [targets | (candidate, targets) <- selectorImpactRegistry, candidate == selector]
  targets -> targets

decodedSelectorImpactTargets :: String -> [String]
decodedSelectorImpactTargets selector =
  concat
    [ [label | (label, bit) <- zip signatureExactCaseLabels signature, bit == '1']
    | (candidate, signature) <- legacySelectorImpactSignatures <> updatedNewSelectorImpactSignatures <> auditSelectorImpactSignatures <> routingAuditSelectorImpactSignatures
    , candidate == selector
    ]
    <> concat
      [ [label | (label, bit) <- zip supplementalExactCaseLabels signature, bit == '1']
      | (candidate, signature) <- legacySelectorSupplementalImpactSignatures <> updatedNewSelectorSupplementalImpactSignatures <> auditSelectorSupplementalImpactSignatures <> routingAuditSelectorSupplementalImpactSignatures
      , candidate == selector
      ]

problemsForTarget :: String -> [String]
problemsForTarget target =
  filter ((target <> ":") `isPrefixOf`) compilerElaboratedPlanExactProblems

problemsForTargets :: [String] -> [String]
problemsForTargets targets =
  filter
    (\problem -> any (\target -> (target <> ":") `isPrefixOf` problem) targets)
    compilerElaboratedPlanExactProblems

problemsOutsideTargets :: [String] -> [String]
problemsOutsideTargets targets =
  filter
    (\problem -> all (\target -> not ((target <> ":") `isPrefixOf` problem)) targets)
    compilerElaboratedPlanExactProblems

compilerElaboratedPlanExactProblems :: [String]
compilerElaboratedPlanExactProblems =
  publicBoundaryProblems
    <> positiveProblems
    <> aggregateShapeFullProblems
    <> negativeProblems
    <> expansionCoverageProblems
    <> grammarPredicateProblems
    <> resourceLimitProblems

summarizeProblemLabels :: [String] -> [String]
summarizeProblemLabels = go [] . map (takeWhile (/= ':'))
 where
  go _ [] = []
  go seen (label : remaining)
    | label `elem` seen = go seen remaining
    | otherwise = label : go (label : seen) remaining

failDiagnostic :: String -> [String] -> IO ()
failDiagnostic label problems =
  fail
    ( unlines
        ( ("CompilerElaboratedPlanOracle " <> label <> ":")
            : map ("  " <>) problems
        )
    )

publicBoundaryProblems :: [String]
publicBoundaryProblems =
  expectEqual
    "the same-library public positive client observes the one exact always-refusing CheckResult"
    (expectedObservedCheckResult positiveSnapshot positiveExpectedProblems)
    (checkCompilerElaboratedPlanDiagnostic positivePlanBytes)

positiveProblems :: [String]
positiveProblems = case inspectCompilerElaboratedPlanDiagnostic positivePlanBytes of
  Left problems -> ["minimal closed-schema plan was rejected: " <> show problems]
  Right plan ->
    concat
      [ expectEqual
          "the complete accepted semantic snapshot is independently literal and input-bound"
          positiveSnapshot
          (planSnapshotView plan)
      , expectEqual
          "the parser freezes both Cabal plan schema versions"
          ("3.16.1.0", "3.16.1.0")
          (diagnosticElaboratedPlanCabalVersion plan, diagnosticElaboratedPlanCabalLibraryVersion plan)
      , expectEqual
          "compiler identity is read from the immutable plan bytes"
          ("ghc-9.12.4", "6f4d")
          (diagnosticElaboratedPlanCompilerId plan, diagnosticElaboratedPlanCompilerAbi plan)
      , expectEqual
          "platform retains the exact architecture and operating-system pair"
          ("aarch64", "osx")
          (diagnosticElaboratedPlanPlatform plan)
      , expectEqual
          "pre-existing, remote, and local units remain distinct"
          [PreExistingUnit, LocalUnit, RemoteUnit]
          (map diagnosticElaboratedUnitOrigin (diagnosticUnits plan))
      , expectEqual
          "every exact unit id is retained"
          ["base-id", "local-id", "remote-id"]
          (map diagnosticElaboratedUnitId (diagnosticUnits plan))
      , expectEqual
          "package provenance and Cabal build style remain separate"
          [PreExistingBuildStyle, LocalBuildStyle, GlobalBuildStyle]
          (map diagnosticElaboratedUnitBuildStyle (diagnosticUnits plan))
      , expectEqual
          "direct component shape remains explicit instead of collapsing into an aggregate"
          [Nothing, Just DirectElaboratedComponentShape, Just DirectElaboratedComponentShape]
          (map diagnosticElaboratedUnitComponentShape (diagnosticUnits plan))
      , expectEqual
          "the local package root is retained without normalization or invention"
          [Just "/immutable/repository/."]
          (map diagnosticElaboratedUnitPackageSourceRoot (localUnits plan))
      , expectEqual
          "the local component and its exact dependency unit ids are retained"
          [("local-id", "lib:core", ["base-id", "remote-id"], [])]
          (componentProjection (localUnits plan))
      , expectEqual
          "selected local flags remain exact typed values"
          [[("variant", False)]]
          (map diagnosticElaboratedUnitFlags (localUnits plan))
      , expectEqual
          "the local build-info and dist-directory paths remain exact diagnostic values"
          [ ( Just "/immutable/build/local-id/build-info.json"
            , Just "/immutable/build/local-id"
            , Nothing
            )
          ]
          [ ( diagnosticElaboratedUnitBuildInfoPath unit
            , diagnosticElaboratedUnitDistDirectoryPath unit
            , diagnosticElaboratedUnitBinaryPath unit
            )
          | unit <- localUnits plan
          ]
      , expectEqual
          "the remote repository location is bound separately from a local source root"
          [("repo-tar", Just "secure-repo", Nothing, Just "https://example.invalid/index")]
          [ ( diagnosticElaboratedUnitPackageSourceKind unit
            , diagnosticElaboratedUnitRepositoryType unit
            , diagnosticElaboratedUnitPackageSourceRoot unit
            , diagnosticElaboratedUnitPackageSourceLocation unit
            )
          | unit <- diagnosticUnits plan
          , diagnosticElaboratedUnitOrigin unit == RemoteUnit
          ]
      , expectEqual
          "Cabal 3.16 plan JSON supplies no component source paths"
          [Nothing]
          [ diagnosticElaboratedComponentSourcePaths component
          | unit <- localUnits plan
          , component <- diagnosticElaboratedUnitComponents unit
          ]
      , expectEqual
          "missing local source ownership is precise typed residue, not an empty-path claim"
          positiveExpectedProblems
          (diagnosticProblems plan)
      , expectEqual
          "the complete public diagnostic wire is exact, ordered, digest-bound, and permanently refusing"
          (expectedObservedCheckResult positiveSnapshot positiveExpectedProblems)
          (checkCompilerElaboratedPlanDiagnostic positivePlanBytes)
      ]

positiveSnapshot :: PlanSnapshotView
positiveSnapshot =
  PlanSnapshotView
    (Just "7906dab016e59c39e9299e048af7e4c6cc6806d1e581ad86cad5da1b929e9043")
    1061
    "3.16.1.0"
    "3.16.1.0"
    "ghc-9.12.4"
    "6f4d"
    "osx"
    "aarch64"
    [ UnitSnapshotView
        PreExistingUnit
        PreExistingBuildStyle
        "base-id"
        "base"
        "4.21.2.0"
        "pre-existing"
        Nothing
        Nothing
        Nothing
        Nothing
        []
        Nothing
        []
        Nothing
        Nothing
        Nothing
        Nothing
        Nothing
        []
    , UnitSnapshotView
        LocalUnit
        LocalBuildStyle
        "local-id"
        "local-package"
        "0.1.0.0"
        "local"
        (Just "/immutable/repository/.")
        Nothing
        Nothing
        Nothing
        [("variant", False)]
        (Just DirectElaboratedComponentShape)
        []
        Nothing
        Nothing
        (Just "/immutable/build/local-id/build-info.json")
        (Just "/immutable/build/local-id")
        Nothing
        [ ComponentSnapshotView
            "local-id"
            "lib:core"
            ["base-id", "remote-id"]
            []
            Nothing
        ]
    , UnitSnapshotView
        RemoteUnit
        GlobalBuildStyle
        "remote-id"
        "remote-package"
        "1.0.0"
        "repo-tar"
        Nothing
        (Just "https://example.invalid/index")
        Nothing
        (Just "secure-repo")
        []
        (Just DirectElaboratedComponentShape)
        []
        (Just "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
        (Just "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
        Nothing
        Nothing
        Nothing
        [ComponentSnapshotView "remote-id" "lib" ["base-id"] [] Nothing]
    ]

positiveExpectedProblems :: [CompilerElaboratedPlanProblem]
positiveExpectedProblems =
  [ PlanInputUnauthenticated positiveDigest 1061
  , PlanArtifactGenerationUnavailable positiveDigest 1061
  , ExpectedCompilerIdentityUnavailable "ghc-9.12.4" "6f4d"
  , ExpectedPlatformIdentityUnavailable "aarch64" "osx"
  , IndependentDuplicateKeyObservationUnavailable positiveDigest 1061
  , IndependentComponentUniverseUnavailable [("local-id", "lib:core")]
  , ConfigurationBranchClosureUnavailable positiveConfigurationSubject
  , CppBranchClosureUnavailable positiveConfigurationSubject
  , IndependentDependencySemanticsUnavailable positiveDependencySubject
  , PackageSourceBytesIdentityUnavailable positiveSourceSubject
  , BuildArtifactPathIdentityUnavailable
      [ ( "local-id"
        , Just "/immutable/build/local-id/build-info.json"
        , Just "/immutable/build/local-id"
        , Nothing
        )
      , ("remote-id", Nothing, Nothing, Nothing)
      ]
  , LocalSourceRootIdentityLimitedToLexical [("local-id", "/immutable/repository/.")]
  , LocalSourceRootFilesystemIdentityUnavailable [("local-id", "/immutable/repository/.")]
  , CompilerElaboratedPlanSnapshotBindingUnavailable
      positiveDigest
      1061
      ("3.16.1.0", "3.16.1.0", "ghc-9.12.4", "6f4d", "osx", "aarch64")
      (map unitObservationWireFromSnapshot (planSnapshotUnits positiveSnapshot))
      positiveDependencySubject
      positiveConfigurationSubject
      positiveSourceSubject
  , CompilerElaboratedPlanOracleQualificationUnavailable
  , LocalComponentSourcePathsUnavailable
      "local-id"
      "lib:core"
      "/immutable/build/local-id/build-info.json"
  ]

positiveDigest :: Text
positiveDigest = "7906dab016e59c39e9299e048af7e4c6cc6806d1e581ad86cad5da1b929e9043"

positiveConfigurationSubject
  :: [(Text, DiagnosticElaboratedUnitBuildStyle, Maybe DiagnosticElaboratedComponentShape, [(Text, Bool)], [Text])]
positiveConfigurationSubject =
  [ ( "local-id"
    , LocalBuildStyle
    , Just DirectElaboratedComponentShape
    , [("variant", False)]
    , ["lib:core"]
    )
  , ("remote-id", GlobalBuildStyle, Just DirectElaboratedComponentShape, [], ["lib"])
  ]

positiveDependencySubject :: [(Text, Text, Text)]
positiveDependencySubject =
  [ ("local-id", "lib:core.depends", "base-id")
  , ("local-id", "lib:core.depends", "remote-id")
  , ("remote-id", "lib.depends", "base-id")
  ]

positiveSourceSubject
  :: [(Text, Text, Maybe FilePath, Maybe Text, Maybe Text, Maybe Text, Maybe Text)]
positiveSourceSubject =
  [ ("local-id", "local", Just "/immutable/repository/.", Nothing, Nothing, Nothing, Nothing)
  , ( "remote-id"
    , "repo-tar"
    , Nothing
    , Just "https://example.invalid/index"
    , Nothing
    , Just "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    , Just "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    )
  ]

planSnapshotUnits :: PlanSnapshotView -> [UnitSnapshotView]
planSnapshotUnits (PlanSnapshotView _ _ _ _ _ _ _ _ units) = units

aggregateShapeFullProblems :: [String]
aggregateShapeFullProblems =
  expectEqual
    "the aggregate component alternative has one exact ordered digest-bound public refusal"
    (expectedObservedCheckResult aggregateSingletonSnapshot aggregateSingletonExpectedProblems)
    (checkCompilerElaboratedPlanDiagnostic aggregateSingletonPlanBytes)

aggregateSingletonSnapshot :: PlanSnapshotView
aggregateSingletonSnapshot =
  PlanSnapshotView
    (Just aggregateSingletonDigest)
    aggregateSingletonInputBytes
    "3.16.1.0"
    "3.16.1.0"
    "ghc-9.12.4"
    "6f4d"
    "osx"
    "aarch64"
    [ UnitSnapshotView
        PreExistingUnit
        PreExistingBuildStyle
        "base-id"
        "base"
        "4.21.2.0"
        "pre-existing"
        Nothing
        Nothing
        Nothing
        Nothing
        []
        Nothing
        []
        Nothing
        Nothing
        Nothing
        Nothing
        Nothing
        []
    , UnitSnapshotView
        LocalUnit
        LocalBuildStyle
        "singleton-id"
        "local-package"
        "0.1.0.0"
        "local"
        (Just "/immutable/repository/.")
        Nothing
        Nothing
        Nothing
        [("variant", False)]
        (Just AggregateElaboratedComponentShape)
        []
        Nothing
        Nothing
        (Just "/immutable/build/singleton-id/build-info.json")
        (Just "/immutable/build/singleton-id")
        Nothing
        [ComponentSnapshotView "singleton-id" "lib" ["base-id"] [] Nothing]
    ]

aggregateSingletonExpectedProblems :: [CompilerElaboratedPlanProblem]
aggregateSingletonExpectedProblems =
  [ PlanInputUnauthenticated aggregateSingletonDigest aggregateSingletonInputBytes
  , PlanArtifactGenerationUnavailable aggregateSingletonDigest aggregateSingletonInputBytes
  , ExpectedCompilerIdentityUnavailable "ghc-9.12.4" "6f4d"
  , ExpectedPlatformIdentityUnavailable "aarch64" "osx"
  , IndependentDuplicateKeyObservationUnavailable aggregateSingletonDigest aggregateSingletonInputBytes
  , IndependentComponentUniverseUnavailable [("singleton-id", "lib")]
  , ConfigurationBranchClosureUnavailable aggregateSingletonConfigurationSubject
  , CppBranchClosureUnavailable aggregateSingletonConfigurationSubject
  , IndependentDependencySemanticsUnavailable [("singleton-id", "lib.depends", "base-id")]
  , PackageSourceBytesIdentityUnavailable
      [("singleton-id", "local", Just "/immutable/repository/.", Nothing, Nothing, Nothing, Nothing)]
  , BuildArtifactPathIdentityUnavailable
      [ ( "singleton-id"
        , Just "/immutable/build/singleton-id/build-info.json"
        , Just "/immutable/build/singleton-id"
        , Nothing
        )
      ]
  , LocalSourceRootIdentityLimitedToLexical [("singleton-id", "/immutable/repository/.")]
  , LocalSourceRootFilesystemIdentityUnavailable [("singleton-id", "/immutable/repository/.")]
  , CompilerElaboratedPlanSnapshotBindingUnavailable
      aggregateSingletonDigest
      aggregateSingletonInputBytes
      ("3.16.1.0", "3.16.1.0", "ghc-9.12.4", "6f4d", "osx", "aarch64")
      (map unitObservationWireFromSnapshot (planSnapshotUnits aggregateSingletonSnapshot))
      [("singleton-id", "lib.depends", "base-id")]
      aggregateSingletonConfigurationSubject
      [("singleton-id", "local", Just "/immutable/repository/.", Nothing, Nothing, Nothing, Nothing)]
  , CompilerElaboratedPlanOracleQualificationUnavailable
  , LocalComponentSourcePathsUnavailable
      "singleton-id"
      "lib"
      "/immutable/build/singleton-id/build-info.json"
  ]

aggregateSingletonConfigurationSubject
  :: [(Text, DiagnosticElaboratedUnitBuildStyle, Maybe DiagnosticElaboratedComponentShape, [(Text, Bool)], [Text])]
aggregateSingletonConfigurationSubject =
  [ ( "singleton-id"
    , LocalBuildStyle
    , Just AggregateElaboratedComponentShape
    , [("variant", False)]
    , ["lib"]
    )
  ]

aggregateSingletonDigest :: Text
aggregateSingletonDigest = "c9317d337d6d23f1808977c0096b5b58e4be84c961bdf47362baf827bd15697e"

aggregateSingletonInputBytes :: Int
aggregateSingletonInputBytes = 609

negativeProblems :: [String]
negativeProblems =
  concat
    [ expectExactLeftProblems
        "an install plan without a local component refuses empty discovery"
        [LocalComponentDiscoveryEmpty]
        emptyLocalPlanBytes
    , expectExactLeftProblems
        "a duplicate unit id is refused at the exact identity"
        [DuplicateElaboratedUnitId "local-id"]
        duplicateUnitPlanBytes
    , expectExactLeftProblems
        "the same source-root/component pair cannot be represented by two units"
        [ DuplicateLocalComponent
            "/immutable/repository/."
            "lib:core"
            ["local-a", "local-b"]
        ]
        duplicateComponentPlanBytes
    , expectExactLeftProblems
        "a missing compiler identity field is explicit"
        [PlanJsonFieldMissing "plan" "compiler-id"]
        missingCompilerIdentityPlanBytes
    , expectExactLeftProblems
        "an unknown top-level identity field changes the closed schema"
        [PlanJsonFieldUnknown "plan" "platform"]
        unknownIdentityPlanBytes
    , expectExactLeftProblems
        "duplicate root keys are rejected before object normalization"
        [PlanJsonFieldDuplicate "plan" "compiler-id"]
        duplicateCompilerIdentityPlanBytes
    , expectExactLeftProblems
        "three equal root keys retain both duplicate occurrences"
        [ PlanJsonFieldDuplicate "plan" "compiler-id"
        , PlanJsonFieldDuplicate "plan" "compiler-id"
        ]
        tripleCompilerIdentityPlanBytes
    , expectExactLeftProblems
        "duplicate flag keys are rejected at their exact nested scope"
        [ PlanJsonFieldDuplicate
            "plan[\"install-plan\"][1][\"flags\"]"
            "variant"
        ]
        duplicateFlagPlanBytes
    , expectExactLeftProblems
        "duplicate unit keys are rejected at their exact array-object scope"
        [PlanJsonFieldDuplicate "plan[\"install-plan\"][1]" "id"]
        duplicateUnitFieldPlanBytes
    , expectExactLeftProblems
        "duplicate nested repository keys are rejected before nested object normalization"
        [PlanJsonFieldDuplicate "plan[\"install-plan\"][1][\"pkg-src\"][\"repo\"]" "uri"]
        duplicateNestedRepositoryFieldPlanBytes
    , expectExactLeftProblems
        "escaped-equivalent root keys are duplicate decoded identities"
        [PlanJsonFieldDuplicate "plan" "compiler-id"]
        duplicateEscapedCompilerIdentityPlanBytes
    , expectExactLeftProblems
        "duplicate nested component keys retain an unambiguous quoted scope"
        [ PlanJsonFieldDuplicate
            "plan[\"install-plan\"][1][\"components\"][\"lib:with.dot\"]"
            "depends"
        ]
        duplicateNestedComponentFieldPlanBytes
    , expectExactLeftProblems
        "trailing garbage cannot be hidden behind an earlier duplicate"
        [PlanJsonInvalid "aeson-decode-invalid"]
        duplicateWithTrailingGarbagePlanBytes
    , expectExactLeftProblems
        "an empty configured component map refuses discovery"
        [ConfiguredUnitComponentDiscoveryEmpty "empty-components-id"]
        emptyConfiguredComponentMapPlanBytes
    , expectExactLeftProblems
        "component names follow the closed Cabal-plan grammar"
        [ConfiguredComponentNameMalformed "local-id" "invented"]
        malformedComponentNamePlanBytes
    , expectExactLeftProblems
        "compiler identities require the closed ghc numeric-version grammar"
        [PlanJsonTextMalformed "plan" "compiler-id" "ghc-9..12"]
        malformedCompilerGrammarPlanBytes
    , expectExactLeftProblems
        "flag names cannot be empty or detach configuration subject identity"
        [ PlanJsonTextMalformed
            "plan[\"install-plan\"][1][\"flags\"]"
            ""
            ""
        ]
        malformedFlagNamePlanBytes
    , expectExactLeftProblems
        "local source roots require the bounded absolute path grammar"
        [ PlanJsonPathUnsafe
            "plan[\"install-plan\"][1][\"pkg-src\"]"
            "path"
            "relative/source"
        ]
        relativeLocalSourcePlanBytes
    , expectExactLeftProblems
        "aggregate units reject a top-level ordinary dependency instead of ignoring it"
        [PlanJsonFieldUnexpected "plan[\"install-plan\"][1]" "depends"]
        aggregateTopLevelDependencyPlanBytes
    , expectExactLeftProblems
        "aggregate units reject a top-level executable dependency instead of ignoring it"
        [PlanJsonFieldUnexpected "plan[\"install-plan\"][1]" "exe-depends"]
        aggregateTopLevelExecutableDependencyPlanBytes
    , expectExactLeftProblems
        "configured units cannot present both direct and aggregate component shapes"
        [ConfiguredUnitComponentShapeAmbiguous "local-id"]
        ambiguousComponentShapePlanBytes
    , expectExactLeftProblems
        "aggregate nested dependencies reject duplicate edges at the component locus"
        [DuplicateComponentDependency "aggregate-id" "lib.depends" "base-id"]
        aggregateDuplicateDependencyPlanBytes
    , expectExactLeftProblems
        "aggregate nested dependencies reject unknown unit identities"
        [UnknownComponentDependencyUnit "aggregate-id" "lib.depends" "missing-id"]
        aggregateUnknownDependencyPlanBytes
    , expectExactLeftProblems
        "aggregate nested self dependencies retain both edge and cycle defects"
        [ SelfComponentDependency "aggregate-id" "lib.depends" "aggregate-id"
        , CyclicUnitDependencies ["aggregate-id"]
        ]
        aggregateSelfDependencyPlanBytes
    , expectExactLeftProblems
        "a duplicate ordinary dependency remains an exact edge-locus defect"
        [DuplicateComponentDependency "local-id" "lib:core.depends" "base-id"]
        duplicateDependencyPlanBytes
    , expectExactLeftProblems
        "a duplicate executable dependency remains distinct from an ordinary edge defect"
        [DuplicateComponentDependency "local-id" "exe:tool.exe-depends" "base-id"]
        duplicateExecutableDependencyPlanBytes
    , expectExactLeftProblems
        "an unknown executable dependency retains its executable-edge locus"
        [UnknownComponentDependencyUnit "local-id" "exe:tool.exe-depends" "missing-tool"]
        unknownExecutableDependencyPlanBytes
    , expectExactLeftProblems
        "a self dependency is both the exact edge defect and a unit cycle"
        [ SelfComponentDependency "local-id" "lib:core.depends" "local-id"
        , CyclicUnitDependencies ["local-id"]
        ]
        selfDependencyPlanBytes
    , expectExactLeftProblems
        "a two-unit dependency cycle is refused as one closed identity set"
        [CyclicUnitDependencies ["local-a", "local-b"]]
        cyclicDependencyPlanBytes
    , expectExactLeftProblems
        "a malformed remote source hash is one exact identity defect"
        [RemotePackageSourceHashMalformed "remote-bad-source-hash" "short-source"]
        malformedRemoteSourceHashPlanBytes
    , expectExactLeftProblems
        "a malformed repository Cabal hash is one exact identity defect"
        [RepositoryCabalHashMalformed "remote-bad-cabal-hash" "short-cabal"]
        malformedRepositoryCabalHashPlanBytes
    , expectExactLeftProblems
        "a missing remote source hash is explicit"
        [RemotePackageSourceHashMissing "remote-missing-source-hash"]
        missingRemoteSourceHashPlanBytes
    , expectExactLeftProblems
        "a missing repository Cabal hash is explicit"
        [RepositoryCabalHashMissing "remote-missing-cabal-hash"]
        missingRepositoryCabalHashPlanBytes
    , expectExactLeftProblems
        "repository-tar accepts only the frozen secure-repo subtype"
        [ UnsupportedRepositoryType
            "plan[\"install-plan\"][1][\"pkg-src\"][\"repo\"]"
            "forged-repo"
        ]
        unsupportedRepositoryTypePlanBytes
    , expectExactLeftProblems
        "source-repo accepts only the frozen Git subtype"
        [ UnsupportedSourceRepositoryType
            "plan[\"install-plan\"][1][\"pkg-src\"][\"source-repo\"]"
            "hg"
        ]
        unsupportedSourceRepositoryTypePlanBytes
    , expectExactLeftProblems
        "local sources reject an unexpected claimed source hash"
        [PlanJsonFieldUnexpected "plan[\"install-plan\"][1]" "pkg-src-sha256"]
        localUnexpectedSourceHashPlanBytes
    , expectExactLeftProblems
        "source repositories reject an unexpected Cabal hash"
        [PlanJsonFieldUnexpected "plan[\"install-plan\"][1]" "pkg-cabal-sha256"]
        sourceRepositoryUnexpectedCabalHashPlanBytes
    , expectExactLeftProblems
        "a mutable source-repository tag is not accepted as an immutable source identity"
        [SourceRepositoryTagMutable "source-repo-id" "master"]
        mutableSourceRepositoryPlanBytes
    , expectExactLeftProblems
        "an inplace configured unit without its build-info path is refused"
        [PlanJsonFieldMissing "plan[\"install-plan\"][1]" "build-info"]
        inplaceMissingBuildInfoPlanBytes
    , expectExactLeftProblems
        "a local configured unit without its dist directory is refused"
        [PlanJsonFieldMissing "plan[\"install-plan\"][1]" "dist-dir"]
        localMissingDistDirectoryPlanBytes
    , expectExactLeftProblems
        "a global library rejects an impossible local build-info path"
        [PlanJsonFieldUnexpected "plan[\"install-plan\"][1]" "build-info"]
        globalUnexpectedBuildInfoPlanBytes
    , expectExactLeftProblems
        "a library rejects an unexpected binary path"
        [PlanJsonFieldUnexpected "plan[\"install-plan\"][1]" "bin-file"]
        libraryUnexpectedBinaryPlanBytes
    , expectExactLeftProblems
        "an executable requires its retained binary path"
        [PlanJsonFieldMissing "plan[\"install-plan\"][1]" "bin-file"]
        executableMissingBinaryPlanBytes
    , expectExactLeftProblems
        "a dependency swap to an absent unit id cannot remain a closed graph"
        [UnknownComponentDependencyUnit "local-id" "lib:core.depends" "remote-other"]
        unknownDependencyPlanBytes
    , expectExactLeftProblems
        "changing a local source declaration to a remote package type cannot retain local style"
        [ConfiguredUnitOriginMismatch "local-id" "local" "repo-tar"]
        alteredPackageTypePlanBytes
    , expectExactLeftProblems
        "an unknown local compiler input is unsupported schema"
        [PlanJsonFieldUnknown "plan[\"install-plan\"][2]" "compiler-input"]
        unknownLocalFieldPlanBytes
    ]

expansionCoverageProblems :: [String]
expansionCoverageProblems =
  concat
    [ expectExactLeftProblems
        "an unterminated generic array retains the token-scan invalid mapping"
        [PlanJsonInvalid "token-scan-invalid"]
        "["
    , expectExactLeftProblems
        "an unterminated generic object retains the token-scan invalid mapping"
        [PlanJsonInvalid "token-scan-invalid"]
        "{"
    , expectExactLeftProblems
        "an invalid root token retains the token-scan invalid mapping"
        [PlanJsonInvalid "token-scan-invalid"]
        "?"
    , expectExactLeftProblems
        "a record closing token is counted at the exact global token boundary"
        [PlanResourceLimitExceeded "json-tokens" 1000000 1000001]
        jsonRecordEndTokenOneOverBytes
    , expectExactLeftProblems
        "all JSON value kinds retain their exact type names"
        [ PlanJsonFieldTypeMismatch "plan" "cabal-version" "object"
        , PlanJsonFieldTypeMismatch "plan" "cabal-lib-version" "array"
        , PlanJsonFieldTypeMismatch "plan" "compiler-id" "number"
        , PlanJsonFieldTypeMismatch "plan" "compiler-abi" "boolean"
        , PlanJsonFieldTypeMismatch "plan" "os" "null"
        , PlanJsonFieldTypeMismatch "plan" "install-plan" "string"
        ]
        allJsonValueKindsPlanBytes
    , expectExactLeftProblems
        "an empty required text field is not accepted as a value"
        [PlanJsonTextEmpty "plan" "cabal-version"]
        emptyRequiredTextPlanBytes
    , expectExactLeftProblems
        "a configured unit requires its package-source object"
        [PlanJsonFieldMissing unitOneScope "pkg-src"]
        missingRequiredObjectPlanBytes
    , expectExactLeftProblems
        "a configured package-source field retains its object type"
        [PlanJsonFieldTypeMismatch unitOneScope "pkg-src" "boolean"]
        mistypedRequiredObjectPlanBytes
    , expectExactLeftProblems
        "an empty optional path is refused before field-combination analysis"
        [ PlanJsonTextEmpty unitOneScope "build-info"
        , PlanJsonFieldUnexpected unitOneScope "build-info"
        ]
        emptyOptionalTextPlanBytes
    , expectExactLeftProblems
        "a mistyped optional path is refused before field-combination analysis"
        [ PlanJsonFieldTypeMismatch unitOneScope "build-info" "boolean"
        , PlanJsonFieldUnexpected unitOneScope "build-info"
        ]
        mistypedOptionalTextPlanBytes
    , expectExactLeftProblems
        "a pre-existing unit requires its dependency array"
        [PlanJsonFieldMissing unitZeroScope "depends"]
        missingDependencyArrayPlanBytes
    , expectExactLeftProblems
        "a dependency field retains its array type"
        [PlanJsonFieldTypeMismatch unitZeroScope "depends" "boolean"]
        mistypedDependencyArrayPlanBytes
    , expectExactLeftProblems
        "an empty dependency identity retains its exact element locus"
        [PlanJsonTextEmpty unitZeroScope "depends[0]"]
        emptyDependencyElementPlanBytes
    , expectExactLeftProblems
        "a dependency element retains its text type"
        [PlanJsonFieldTypeMismatch unitZeroScope "depends[0]" "boolean"]
        mistypedDependencyElementPlanBytes
    , expectExactLeftProblems
        "a dependency identity is checked by the shared constrained-text grammar"
        [PlanJsonTextMalformed unitZeroScope "depends[0]" "bad@identity"]
        malformedDependencyIdentityPlanBytes
    , expectExactLeftProblems
        "uppercase ASCII remains an admitted portable-identity alternative"
        [PlanJsonFieldUnknown unitZeroScope "probe"]
        uppercasePortableIdentityPlanBytes
    , expectExactLeftProblems
        "portable identity retains the colon character alternative"
        [PlanJsonFieldUnknown unitZeroScope "probe"]
        (portableIdentityAlternativePlanBytes "base:id")
    , expectExactLeftProblems
        "portable identity retains the dot character alternative"
        [PlanJsonFieldUnknown unitZeroScope "probe"]
        (portableIdentityAlternativePlanBytes "base.id")
    , expectExactLeftProblems
        "portable identity retains the plus character alternative"
        [PlanJsonFieldUnknown unitZeroScope "probe"]
        (portableIdentityAlternativePlanBytes "base+id")
    , expectExactLeftProblems
        "portable identity retains the hyphen character alternative"
        [PlanJsonFieldUnknown unitZeroScope "probe"]
        (portableIdentityAlternativePlanBytes "base-id")
    , expectExactLeftProblems
        "portable identity retains the underscore character alternative"
        [PlanJsonFieldUnknown unitZeroScope "probe"]
        (portableIdentityAlternativePlanBytes "base_id")
    , exactRootProblem
        "platform tokens retain the hyphen character alternative"
        (UnsupportedPlanSchemaVersion "cabal-version" "3.16.1.0" "3.16.1.1")
        (rootGrammarPlan "3.16.1.1" "3.16.1.0" "ghc-9.12.4" "6f4d" "darwin-kernel" "aarch64")
    , exactRootProblem
        "platform tokens retain the underscore character alternative"
        (UnsupportedPlanSchemaVersion "cabal-version" "3.16.1.0" "3.16.1.1")
        (rootGrammarPlan "3.16.1.1" "3.16.1.0" "ghc-9.12.4" "6f4d" "darwin_kernel" "aarch64")
    , componentAlternativeControlProblems "lib:core.name"
    , componentAlternativeControlProblems "lib:core-name"
    , componentAlternativeControlProblems "lib:core_name"
    , flagAlternativeControlProblems "variant-name"
    , flagAlternativeControlProblems "variant_name"
    , lowerHexAlternativeControlProblems
        "SHA-256 lower-hex alphabetic alternative remains admitted"
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    , lowerHexAlternativeControlProblems
        "SHA-256 lower-hex digit alternative remains admitted"
        "1111111111111111111111111111111111111111111111111111111111111111"
    , sourceRepositoryProjectionProblems
    , localSourceRootOrderProblems
    , expectExactLeftProblems
        "a test component independently requires its binary path"
        [PlanJsonFieldMissing unitOneScope "bin-file"]
        testComponentWithoutBinaryPlanBytes
    , expectExactLeftProblems
        "a benchmark component independently requires its binary path"
        [PlanJsonFieldMissing unitOneScope "bin-file"]
        benchmarkComponentWithoutBinaryPlanBytes
    , exactFlagOrderProblems
    , expectExactLeftProblems
        "multiple unknown fields retain deterministic lexical order"
        [ PlanJsonFieldUnknown "plan" "alpha-unknown"
        , PlanJsonFieldUnknown "plan" "zeta-unknown"
        ]
        multipleUnknownFieldsPlanBytes
    , expectExactLeftProblems
        "pre-existing unit dependencies remain projected into invariant checks"
        [ UnknownComponentDependencyUnit "base-id" "<unit>.depends" "missing-id"
        , LocalComponentDiscoveryEmpty
        ]
        preExistingUnknownDependencyPlanBytes
    ]

exactFlagOrderProblems :: [String]
exactFlagOrderProblems =
  case inspectCompilerElaboratedPlanDiagnostic twoFlagPlanBytes of
    Left problems -> ["multiple flags retain deterministic lexical order: plan was rejected with " <> show problems]
    Right plan ->
      expectEqual
        "multiple flags retain deterministic lexical order"
        [[("alpha", True), ("zeta", False)]]
        (map diagnosticElaboratedUnitFlags (localUnits plan))

grammarPredicateProblems :: [String]
grammarPredicateProblems =
  concat
    [ exactRootProblem
        "the Cabal schema version is an exact closed alternative"
        (UnsupportedPlanSchemaVersion "cabal-version" "3.16.1.0" "3.16.1.1")
        (rootGrammarPlan "3.16.1.1" "3.16.1.0" "ghc-9.12.4" "6f4d" "osx" "aarch64")
    , exactRootProblem
        "the Cabal library schema version is an independently exact closed alternative"
        (UnsupportedPlanSchemaVersion "cabal-lib-version" "3.16.1.0" "3.16.1.1")
        (rootGrammarPlan "3.16.1.0" "3.16.1.1" "ghc-9.12.4" "6f4d" "osx" "aarch64")
    , exactRootProblem
        "the compiler identifier prefix is exact"
        (PlanJsonTextMalformed "plan" "compiler-id" "gch-9.12.4")
        (rootGrammarPlan "3.16.1.0" "3.16.1.0" "gch-9.12.4" "6f4d" "osx" "aarch64")
    , exactRootProblem
        "the compiler numeric version rejects an empty segment independently"
        (PlanJsonTextMalformed "plan" "compiler-id" "ghc-9..12")
        (rootGrammarPlan "3.16.1.0" "3.16.1.0" "ghc-9..12" "6f4d" "osx" "aarch64")
    , exactRootProblem
        "the compiler numeric version rejects a non-decimal symbol independently"
        (PlanJsonTextMalformed "plan" "compiler-id" "ghc-9.x.12")
        (rootGrammarPlan "3.16.1.0" "3.16.1.0" "ghc-9.x.12" "6f4d" "osx" "aarch64")
    , exactRootProblem
        "a portable identity rejects a leading punctuation boundary independently"
        (PlanJsonTextMalformed "plan" "compiler-abi" "-6f4d")
        (rootGrammarPlan "3.16.1.0" "3.16.1.0" "ghc-9.12.4" "-6f4d" "osx" "aarch64")
    , exactRootProblem
        "a portable identity rejects a trailing punctuation boundary independently"
        (PlanJsonTextMalformed "plan" "compiler-abi" "6f4d-")
        (rootGrammarPlan "3.16.1.0" "3.16.1.0" "ghc-9.12.4" "6f4d-" "osx" "aarch64")
    , exactRootProblem
        "a portable identity rejects an independently forbidden character"
        (PlanJsonTextMalformed "plan" "compiler-abi" "6f@4d")
        (rootGrammarPlan "3.16.1.0" "3.16.1.0" "ghc-9.12.4" "6f@4d" "osx" "aarch64")
    , exactRootProblem
        "a platform token rejects a leading punctuation boundary independently"
        (PlanJsonTextMalformed "plan" "os" "-osx")
        (rootGrammarPlan "3.16.1.0" "3.16.1.0" "ghc-9.12.4" "6f4d" "-osx" "aarch64")
    , exactRootProblem
        "a platform token rejects a trailing punctuation boundary independently"
        (PlanJsonTextMalformed "plan" "os" "osx-")
        (rootGrammarPlan "3.16.1.0" "3.16.1.0" "ghc-9.12.4" "6f4d" "osx-" "aarch64")
    , exactRootProblem
        "a platform token rejects an independently forbidden character"
        (PlanJsonTextMalformed "plan" "os" "os.x")
        (rootGrammarPlan "3.16.1.0" "3.16.1.0" "ghc-9.12.4" "6f4d" "os.x" "aarch64")
    , expectExactLeftProblems
        "a package name rejects an empty hyphen-delimited segment"
        [PlanJsonTextMalformed unitZeroScope "pkg-name" "local--package"]
        (preExistingGrammarPlan "base-id" "local--package" "1.0.0")
    , expectExactLeftProblems
        "a package name rejects an independently forbidden segment character"
        [PlanJsonTextMalformed unitZeroScope "pkg-name" "local_package"]
        (preExistingGrammarPlan "base-id" "local_package" "1.0.0")
    , expectExactLeftProblems
        "a package version rejects an empty decimal segment"
        [PlanJsonTextMalformed unitZeroScope "pkg-version" "1..0"]
        (preExistingGrammarPlan "base-id" "local-package" "1..0")
    , expectExactLeftProblems
        "a package version rejects an independently non-decimal symbol"
        [PlanJsonTextMalformed unitZeroScope "pkg-version" "1.x.0"]
        (preExistingGrammarPlan "base-id" "local-package" "1.x.0")
    , expectExactLeftProblems
        "a flag name rejects a leading punctuation boundary independently"
        [PlanJsonTextMalformed flagsScope "-variant" "-variant"]
        (localGrammarPlan "configured" "local-id" "local-package" "0.1.0.0" "-variant" "local" "local" "/immutable/repository/." "lib")
    , expectExactLeftProblems
        "a flag name rejects a trailing punctuation boundary independently"
        [PlanJsonTextMalformed flagsScope "variant-" "variant-"]
        (localGrammarPlan "configured" "local-id" "local-package" "0.1.0.0" "variant-" "local" "local" "/immutable/repository/." "lib")
    , expectExactLeftProblems
        "a flag name rejects an independently forbidden character"
        [PlanJsonTextMalformed flagsScope "variant.dot" "variant.dot"]
        (localGrammarPlan "configured" "local-id" "local-package" "0.1.0.0" "variant.dot" "local" "local" "/immutable/repository/." "lib")
    , expectExactLeftProblems
        "a component builtin is drawn from the exact closed set"
        [ConfiguredComponentNameMalformed "local-id" "foreign"]
        (localGrammarPlan "configured" "local-id" "local-package" "0.1.0.0" "variant" "local" "local" "/immutable/repository/." "foreign")
    , expectExactLeftProblems
        "a qualified component prefix is drawn from the exact closed set"
        [ConfiguredComponentNameMalformed "local-id" "foreign:tool"]
        (localGrammarPlan "configured" "local-id" "local-package" "0.1.0.0" "variant" "local" "local" "/immutable/repository/." "foreign:tool")
    , expectExactLeftProblems
        "a qualified component suffix rejects a leading punctuation boundary"
        [ConfiguredComponentNameMalformed "local-id" "lib:-tool"]
        (localGrammarPlan "configured" "local-id" "local-package" "0.1.0.0" "variant" "local" "local" "/immutable/repository/." "lib:-tool")
    , expectExactLeftProblems
        "a qualified component suffix rejects a trailing punctuation boundary"
        [ConfiguredComponentNameMalformed "local-id" "lib:tool-"]
        (localGrammarPlan "configured" "local-id" "local-package" "0.1.0.0" "variant" "local" "local" "/immutable/repository/." "lib:tool-")
    , expectExactLeftProblems
        "a qualified component suffix rejects an independently forbidden character"
        [ConfiguredComponentNameMalformed "local-id" "lib:tool@x"]
        (localGrammarPlan "configured" "local-id" "local-package" "0.1.0.0" "variant" "local" "local" "/immutable/repository/." "lib:tool@x")
    , concatMap componentAlternativeControlProblems
        ["lib", "setup", "lib:core", "exe:tool", "test:spec", "bench:perf"]
    , expectExactLeftProblems
        "an unsupported install-unit discriminator is exact"
        [UnsupportedInstallUnitType 0 "foreign"]
        foreignInstallUnitPlanBytes
    , expectExactLeftProblems
        "an unsupported package-source discriminator is exact"
        [UnsupportedPackageSourceType "local-id" "foreign"]
        (localGrammarPlan "configured" "local-id" "local-package" "0.1.0.0" "variant" "local" "foreign" "/immutable/repository/." "lib")
    , expectExactLeftProblems
        "an unsupported configured style is exact"
        [UnsupportedConfiguredUnitStyle "local-id" "foreign"]
        (localGrammarPlan "configured" "local-id" "local-package" "0.1.0.0" "variant" "foreign" "local" "/immutable/repository/." "lib")
    , expectExactLeftProblems
        "a configured unit must state one component shape"
        [ConfiguredUnitComponentShapeMissing "shape-missing-id"]
        componentShapeMissingPlanBytes
    , expectExactLeftProblems
        "a local source cannot claim the global build style"
        [ConfiguredUnitOriginMismatch "local-origin-id" "global" "local"]
        localOriginMismatchPlanBytes
    , expectExactLeftProblems
        "a global unit independently forbids a dist-directory path"
        [PlanJsonFieldUnexpected unitOneScope "dist-dir"]
        globalUnexpectedDistDirectoryPlanBytes
    , expectExactLeftProblems
        "a local source independently forbids a claimed Cabal hash"
        [PlanJsonFieldUnexpected unitOneScope "pkg-cabal-sha256"]
        localUnexpectedCabalHashPlanBytes
    , expectExactLeftProblems
        "a source repository independently requires its source hash"
        [RemotePackageSourceHashMissing "source-repo-missing-hash-id"]
        sourceRepositoryMissingHashPlanBytes
    , expectLocatorProblems "http://example.invalid/index" "http://example.invalid/index" "source scheme"
    , expectLocatorProblems "https://" "https://" "source payload"
    , expectLocatorProblems "https://bad path" "https://bad path" "source lower visible-character bound"
    , expectLocatorProblems "https://bad\\u00e9" "https://badé" "source upper ASCII-character bound"
    , expectLocatorProblems "https://bad\\\\path" "https://bad\\path" "source backslash"
    , expectPathProblem "relative/source" "relative/source" "path absolute marker"
    , expectPathProblem "/bad path" "/bad path" "path lower visible-character bound"
    , expectPathProblem "/bad\\u00e9" "/badé" "path upper ASCII-character bound"
    , expectPathProblem "/bad\\\\path" "/bad\\path" "path backslash"
    , expectPathProblem "/a:b" "/a:b" "path colon"
    , expectPathProblem "/a/" "/a/" "path empty trailing segment"
    , expectPathProblem "/a/../b" "/a/../b" "path parent segment"
    , expectPathProblem "/a/./b" "/a/./b" "path dot-segment position"
    , expectExactLeftProblems
        "the path root alternative is admitted before the independent probe refusal"
        [PlanJsonFieldUnknown unitOneScope "probe"]
        (localLimitPlan "/" [] ["\"probe\":true"])
    , expectExactLeftProblems
        "the final dot-segment alternative is admitted before the independent probe refusal"
        [PlanJsonFieldUnknown unitOneScope "probe"]
        (localLimitPlan "/a/." [] ["\"probe\":true"])
    , expectRepositoryHashProblem
        "a SHA-256 identity rejects width 63 exactly"
        (ByteString8.replicate 63 'a')
        (RemotePackageSourceHashMalformed "hash-grammar-id" (Text.replicate 63 "a"))
    , expectRepositoryHashProblem
        "a SHA-256 identity rejects a non-lower-hex symbol exactly"
        (ByteString8.replicate 63 'a' <> "g")
        (RemotePackageSourceHashMalformed "hash-grammar-id" (Text.replicate 63 "a" <> "g"))
    , expectGitTagProblem
        "a Git SHA-1 identity rejects width 39 exactly"
        (ByteString8.replicate 39 'a')
    , expectGitTagProblem
        "a Git SHA-256 identity rejects width 63 independently"
        (ByteString8.replicate 63 'a')
    , expectGitTagProblem
        "a Git object identity rejects a non-lower-hex symbol exactly"
        (ByteString8.replicate 39 'a' <> "g")
    , expectExactLeftProblems
        "the Git SHA-256 width alternative reaches semantic plan analysis"
        [LocalComponentDiscoveryEmpty]
        ( renderPlan
            identityFields
            [ preExistingUnit
            , sourceRepositoryUnit
                "git-sha256-id"
                "git"
                (ByteString8.replicate 64 'a')
                Nothing
                (Just validSourceHashBytes)
            ]
        )
    ]

exactRootProblem :: String -> CompilerElaboratedPlanProblem -> ByteString -> [String]
exactRootProblem label problem = expectExactLeftProblems label [problem]

rootGrammarPlan
  :: ByteString
  -> ByteString
  -> ByteString
  -> ByteString
  -> ByteString
  -> ByteString
  -> ByteString
rootGrammarPlan cabalVersion cabalLibraryVersion compilerId compilerAbi operatingSystem architecture =
  renderPlan
    [ "\"cabal-version\":\"" <> cabalVersion <> "\""
    , "\"cabal-lib-version\":\"" <> cabalLibraryVersion <> "\""
    , "\"compiler-id\":\"" <> compilerId <> "\""
    , "\"compiler-abi\":\"" <> compilerAbi <> "\""
    , "\"os\":\"" <> operatingSystem <> "\""
    , "\"arch\":\"" <> architecture <> "\""
    ]
    [ preExistingUnit
    , localUnit "local-id" "/immutable/repository/." "lib" ["base-id"] ""
    ]

unitZeroScope, unitOneScope, flagsScope :: Text
unitZeroScope = "plan[\"install-plan\"][0]"
unitOneScope = "plan[\"install-plan\"][1]"
flagsScope = "plan[\"install-plan\"][1][\"flags\"]"

preExistingGrammarPlan :: ByteString -> ByteString -> ByteString -> ByteString
preExistingGrammarPlan unitId packageName packageVersion =
  renderPlan
    identityFields
    [ "{\"type\":\"pre-existing\",\"id\":\""
        <> unitId
        <> "\",\"pkg-name\":\""
        <> packageName
        <> "\",\"pkg-version\":\""
        <> packageVersion
        <> "\",\"depends\":[]}"
    , localUnit "local-id" "/immutable/repository/." "lib" [unitId] ""
    ]

foreignInstallUnitPlanBytes :: ByteString
foreignInstallUnitPlanBytes =
  renderPlan
    identityFields
    [ "{\"type\":\"foreign\",\"id\":\"base-id\",\"pkg-name\":\"base\",\"pkg-version\":\"4.21.2.0\",\"depends\":[]}"
    , localUnit "local-id" "/immutable/repository/." "lib" ["base-id"] ""
    ]

componentShapeMissingPlanBytes :: ByteString
componentShapeMissingPlanBytes =
  renderPlan
    identityFields
    [ preExistingUnit
    , "{\"type\":\"configured\",\"id\":\"shape-missing-id\",\"pkg-name\":\"local-package\",\"pkg-version\":\"0.1.0.0\",\"flags\":{},\"style\":\"local\",\"pkg-src\":{\"type\":\"local\",\"path\":\"/immutable/repository/.\"},\"depends\":[\"base-id\"],\"exe-depends\":[],\"build-info\":\"/immutable/build/shape-missing-id/build-info.json\",\"dist-dir\":\"/immutable/build/shape-missing-id\"}"
    ]

localOriginMismatchPlanBytes :: ByteString
localOriginMismatchPlanBytes =
  renderPlan
    identityFields
    [ preExistingUnit
    , "{\"type\":\"configured\",\"id\":\"local-origin-id\",\"pkg-name\":\"local-package\",\"pkg-version\":\"0.1.0.0\",\"flags\":{},\"style\":\"global\",\"pkg-src\":{\"type\":\"local\",\"path\":\"/immutable/repository/.\"},\"component-name\":\"lib\",\"depends\":[\"base-id\"],\"exe-depends\":[]}"
    ]

globalUnexpectedDistDirectoryPlanBytes :: ByteString
globalUnexpectedDistDirectoryPlanBytes =
  renderPlan
    identityFields
    [ preExistingUnit
    , repositoryTarUnit
        "global-dist-id"
        "secure-repo"
        (Just validCabalHashBytes)
        (Just validSourceHashBytes)
        "\"dist-dir\":\"/immutable/build/global-dist-id\""
    ]

localUnexpectedCabalHashPlanBytes :: ByteString
localUnexpectedCabalHashPlanBytes =
  renderPlan
    identityFields
    [ preExistingUnit
    , localUnit
        "local-cabal-hash-id"
        "/immutable/repository/."
        "lib"
        ["base-id"]
        "\"pkg-cabal-sha256\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\""
    ]

sourceRepositoryMissingHashPlanBytes :: ByteString
sourceRepositoryMissingHashPlanBytes =
  renderPlan
    identityFields
    [ preExistingUnit
    , sourceRepositoryUnit
        "source-repo-missing-hash-id"
        "git"
        "0123456789abcdef0123456789abcdef01234567"
        Nothing
        Nothing
    ]

localGrammarPlan
  :: ByteString
  -> ByteString
  -> ByteString
  -> ByteString
  -> ByteString
  -> ByteString
  -> ByteString
  -> ByteString
  -> ByteString
  -> ByteString
localGrammarPlan unitType unitId packageName packageVersion flagName style sourceType path componentName =
  renderPlan
    identityFields
    [ preExistingUnit
    , "{\"type\":\""
        <> unitType
        <> "\",\"id\":\""
        <> unitId
        <> "\",\"pkg-name\":\""
        <> packageName
        <> "\",\"pkg-version\":\""
        <> packageVersion
        <> "\",\"flags\":{\""
        <> flagName
        <> "\":false},\"style\":\""
        <> style
        <> "\",\"pkg-src\":{\"type\":\""
        <> sourceType
        <> "\",\"path\":\""
        <> path
        <> "\"},\"component-name\":\""
        <> componentName
        <> "\",\"depends\":[\"base-id\"],\"exe-depends\":[],\"build-info\":\"/immutable/build/"
        <> unitId
        <> "/build-info.json\",\"dist-dir\":\"/immutable/build/"
        <> unitId
        <> "\"}"
    ]

componentAlternativeControlProblems :: ByteString -> [String]
componentAlternativeControlProblems componentName =
  expectExactLeftProblems
    ("the admitted component alternative remains exact: " <> ByteString8.unpack componentName)
    [ UnknownComponentDependencyUnit
        "component-control-id"
        (Text.pack (ByteString8.unpack componentName) <> ".depends")
        "missing-id"
    ]
    ( renderPlan
        identityFields
        [ preExistingUnit
        , "{\"type\":\"configured\",\"id\":\"component-control-id\",\"pkg-name\":\"local-package\",\"pkg-version\":\"0.1.0.0\",\"flags\":{},\"style\":\"local\",\"pkg-src\":{\"type\":\"local\",\"path\":\"/immutable/repository/.\"},\"component-name\":\""
            <> componentName
            <> "\",\"depends\":[\"missing-id\"],\"exe-depends\":[],\"build-info\":\"/immutable/build/component-control-id/build-info.json\",\"dist-dir\":\"/immutable/build/component-control-id\""
            <> if any (`ByteString8.isPrefixOf` componentName) ["exe:", "test:", "bench:"]
              then ",\"bin-file\":\"/immutable/build/component-control-id/binary\"}"
              else "}"
        ]
    )

expectLocatorProblems :: ByteString -> Text -> String -> [String]
expectLocatorProblems encodedLocator decodedLocator label =
  expectExactLeftProblems
    label
    [ PlanJsonTextMalformed
        "plan[\"install-plan\"][1][\"pkg-src\"][\"repo\"]"
        "uri"
        decodedLocator
    , UnsupportedRepositoryType
        "plan[\"install-plan\"][1][\"pkg-src\"][\"repo\"]"
        "forged-repo"
    ]
    (repositoryLocatorGrammarPlan encodedLocator)

repositoryLocatorGrammarPlan :: ByteString -> ByteString
repositoryLocatorGrammarPlan locator =
  renderPlan
    identityFields
    [ preExistingUnit
    , "{\"type\":\"configured\",\"id\":\"locator-grammar-id\",\"pkg-name\":\"remote-package\",\"pkg-version\":\"1.0.0\",\"flags\":{},\"style\":\"global\",\"pkg-src\":{\"type\":\"repo-tar\",\"repo\":{\"type\":\"forged-repo\",\"uri\":\""
        <> locator
        <> "\"}},\"component-name\":\"lib\",\"depends\":[],\"exe-depends\":[],\"pkg-cabal-sha256\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"pkg-src-sha256\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"}"
    ]

expectPathProblem :: ByteString -> FilePath -> String -> [String]
expectPathProblem encodedPath decodedPath label =
  expectExactLeftProblems
    label
    [PlanJsonPathUnsafe "plan[\"install-plan\"][1][\"pkg-src\"]" "path" decodedPath]
    (localLimitPlan encodedPath [] [])

expectRepositoryHashProblem
  :: String
  -> ByteString
  -> CompilerElaboratedPlanProblem
  -> [String]
expectRepositoryHashProblem label sourceHash problem =
  expectExactLeftProblems
    label
    [problem]
    ( renderPlan
        identityFields
        [ preExistingUnit
        , repositoryTarUnit
            "hash-grammar-id"
            "secure-repo"
            (Just validCabalHashBytes)
            (Just sourceHash)
            ""
        ]
    )

expectGitTagProblem :: String -> ByteString -> [String]
expectGitTagProblem label tag =
  expectExactLeftProblems
    label
    [SourceRepositoryTagMutable "git-grammar-id" (Text.pack (ByteString8.unpack tag))]
    ( renderPlan
        identityFields
        [ preExistingUnit
        , sourceRepositoryUnit
            "git-grammar-id"
            "git"
            tag
            Nothing
            (Just validSourceHashBytes)
        ]
    )

resourceLimitProblems :: [String]
resourceLimitProblems =
  concat
    [ expectExactLeftProblems
        "the exact input-byte ceiling reaches the exact decoded root refusal"
        [PlanRootNotObject]
        inputByteBoundaryBytes
    , expectExactLeftProblems
        "one byte beyond the input ceiling is refused before tokenization"
        [ PlanResourceLimitExceeded
            "input-bytes"
            8388608
            8388609
        ]
        inputByteOneOverBytes
    , expectExactLeftProblems
        "the exact nesting ceiling reaches the exact decoded root refusal"
        [PlanRootNotObject]
        jsonDepthBoundaryBytes
    , expectExactLeftProblems
        "one container beyond the nesting ceiling is refused exactly"
        [ PlanResourceLimitExceeded
            "json-depth"
            64
            65
        ]
        jsonDepthOneOverBytes
    , expectExactLeftProblems
        "the exact decoded-text ceiling reaches the exact decoded root refusal"
        [PlanRootNotObject]
        jsonTextBoundaryBytes
    , expectExactLeftProblems
        "one decoded character beyond the text ceiling is refused exactly"
        [ PlanResourceLimitExceeded
            "json-string-code-points"
            1048576
            1048577
        ]
        jsonTextOneOverBytes
    , expectExactLeftProblems
        "the exact generic-array ceiling reaches the exact decoded root refusal"
        [PlanRootNotObject]
        jsonCollectionBoundaryBytes
    , expectExactLeftProblems
        "one element beyond the collection ceiling is refused exactly"
        [ PlanResourceLimitExceeded
            "json-array-entries"
            65536
            65537
        ]
        jsonCollectionOneOverBytes
    , expectExactLeftProblems
        "the exact generic-object-member ceiling reaches the semantic problem cap"
        [PlanResourceLimitExceeded "problems" 128 129]
        jsonObjectMemberBoundaryBytes
    , expectExactLeftProblems
        "one generic object member beyond the ceiling is refused before decoding"
        [PlanResourceLimitExceeded "json-object-members" 65536 65537]
        jsonObjectMemberOneOverBytes
    , expectExactLeftProblems
        "the exact JSON key-text ceiling retains every closed-schema refusal"
        (jsonKeyBoundaryProblems 1048576)
        jsonKeyBoundaryBytes
    , expectExactLeftProblems
        "one code point beyond the JSON key-text ceiling is refused before decoding"
        [PlanResourceLimitExceeded "json-key-code-points" 1048576 1048577]
        jsonKeyOneOverBytes
    , expectExactLeftProblems
        "exactly one million structural tokens reach the decoded root refusal"
        [PlanRootNotObject]
        jsonTokenBoundaryBytes
    , expectExactLeftProblems
        "the first token beyond the token ceiling is refused exactly"
        [ PlanResourceLimitExceeded
            "json-tokens"
            1000000
            1000001
        ]
        jsonTokenOneOverBytes
    , expectExactRepeatedLeftProblem
        "the exact duplicate-problem ceiling retains every duplicate finding"
        128
        (PlanJsonFieldDuplicate "plan" "duplicate")
        jsonProblemBoundaryBytes
    , expectExactLeftProblems
        "one duplicate problem beyond the problem ceiling is refused exactly"
        [ PlanResourceLimitExceeded
            "duplicate-key-problems"
            128
            129
        ]
        jsonProblemOneOverBytes
    , expectSemanticProblemBoundary
        "the exact semantic-problem ceiling retains every exact entry locus"
        128
        semanticProblemBoundaryBytes
    , expectExactLeftProblems
        "one semantic problem beyond the ceiling refuses before further traversal"
        [PlanResourceLimitExceeded "problems" 128 129]
        semanticProblemOneOverBytes
    , expectEqual
        "the exact observed-result ceiling retains fifteen mandatory refusals and 113 exact source-path rows"
        ( expectedObservedCheckResult
            observedResultBoundarySnapshot
            observedResultBoundaryExpectedProblems
        )
        (checkCompilerElaboratedPlanDiagnostic observedResultBoundaryBytes)
    , expectEqual
        "the first observed variable row beyond the result ceiling retains every mandatory refusal before one exact limit row"
        ( expectedObservedCheckResult
            observedResultOneOverSnapshot
            observedResultOneOverExpectedProblems
        )
        (checkCompilerElaboratedPlanDiagnostic observedResultOneOverBytes)
    , expectExactLeftProblems
        "the exact unit ceiling reaches the independently smaller problem ceiling"
        [PlanResourceLimitExceeded "problems" 128 129]
        unitBoundaryBytes
    , expectExactLeftProblems
        "one install unit beyond the unit ceiling is refused before unit traversal"
        [PlanResourceLimitExceeded "units" 256 257]
        unitOneOverBytes
    , expectExactLeftProblems
        "the exact component ceiling retains every exact member locus"
        componentBoundaryProblems
        componentBoundaryBytes
    , expectExactLeftProblems
        "one component beyond the component ceiling is refused before member traversal"
        [PlanResourceLimitExceeded "components" 128 129]
        componentOneOverBytes
    , expectExactLeftProblems
        "the aggregate component ceiling counts direct components across unit boundaries before rendering"
        [PlanResourceLimitExceeded "components" 128 129]
        directComponentCountOneOverBytes
    , expectExactLeftProblems
        "the exact dependency ceiling reaches the independently smaller problem ceiling"
        [PlanResourceLimitExceeded "problems" 128 129]
        dependencyBoundaryBytes
    , expectExactLeftProblems
        "one dependency beyond the dependency ceiling is refused before edge traversal"
        [PlanResourceLimitExceeded "dependencies" 256 257]
        dependencyOneOverBytes
    , expectExactLeftProblems
        "the aggregate dependency ceiling counts root executable edges before traversal"
        [PlanResourceLimitExceeded "dependencies" 256 257]
        rootExecutableDependencyCountOneOverBytes
    , expectExactLeftProblems
        "the aggregate dependency ceiling counts nested ordinary edges before traversal"
        [PlanResourceLimitExceeded "dependencies" 256 257]
        nestedDependencyCountOneOverBytes
    , expectExactLeftProblems
        "the aggregate dependency ceiling counts nested executable edges before traversal"
        [PlanResourceLimitExceeded "dependencies" 256 257]
        nestedExecutableDependencyCountOneOverBytes
    , expectExactLeftProblems
        "the exact flag ceiling retains every exact flag-value locus"
        flagBoundaryProblems
        flagBoundaryBytes
    , expectExactLeftProblems
        "one flag beyond the flag ceiling is refused before flag traversal"
        [PlanResourceLimitExceeded "flags" 128 129]
        flagOneOverBytes
    , expectExactLeftProblems
        "the exact source-object member ceiling reaches closed-schema parsing"
        [PlanJsonFieldUnknown "plan[\"install-plan\"][1][\"pkg-src\"]" "extra-0"]
        sourceMemberBoundaryBytes
    , expectExactLeftProblems
        "one source-object member beyond the ceiling is refused before source traversal"
        [PlanResourceLimitExceeded "source-object-members" 3 4]
        sourceMemberOneOverBytes
    , expectExactLeftProblems
        "the exact semantic-scalar byte ceiling reaches the flag value-type refusal"
        [ PlanJsonFieldTypeMismatch
            "plan[\"install-plan\"][1][\"flags\"]"
            (Text.replicate 512 "a")
            "null"
        ]
        semanticScalarBoundaryBytes
    , expectExactLeftProblems
        "one semantic-scalar byte beyond the ceiling is refused at the exact flag key"
        [ PlanJsonFieldTypeMismatch
            "plan[\"install-plan\"][1][\"flags\"]"
            (Text.replicate 513 "a")
            "null"
        , PlanJsonTextMalformed
            "plan[\"install-plan\"][1][\"flags\"]"
            (Text.replicate 513 "a")
            (Text.replicate 513 "a")
        ]
        semanticScalarOneOverBytes
    , expectExactLeftProblems
        "the exact source-locator byte ceiling reaches the independent repository-type refusal"
        [ UnsupportedRepositoryType
            "plan[\"install-plan\"][1][\"pkg-src\"][\"repo\"]"
            "forged-repo"
        ]
        sourceByteBoundaryBytes
    , expectExactLeftProblems
        "one source-locator byte beyond the ceiling is refused at the locator locus"
        [ PlanJsonTextMalformed
            "plan[\"install-plan\"][1][\"pkg-src\"][\"repo\"]"
            "uri"
            ("https://" <> Text.replicate 4089 "a")
        , UnsupportedRepositoryType
            "plan[\"install-plan\"][1][\"pkg-src\"][\"repo\"]"
            "forged-repo"
        ]
        sourceByteOneOverBytes
    , expectExactLeftProblems
        "the exact path byte ceiling reaches the independent unknown-field refusal"
        [PlanJsonFieldUnknown "plan[\"install-plan\"][1]" "probe"]
        pathByteBoundaryBytes
    , expectExactLeftProblems
        "one path byte beyond the ceiling is refused at the path locus"
        [ PlanJsonFieldUnknown "plan[\"install-plan\"][1]" "probe"
        , PlanJsonPathUnsafe
            "plan[\"install-plan\"][1][\"pkg-src\"]"
            "path"
            (ByteString8.unpack pathByteOneOverValue)
        ]
        pathByteOneOverBytes
    , expectExactLeftProblems
        "the exact path-segment ceiling reaches the independent unknown-field refusal"
        [PlanJsonFieldUnknown "plan[\"install-plan\"][1]" "probe"]
        pathSegmentBoundaryBytes
    , expectExactLeftProblems
        "one path segment beyond the ceiling is refused at the path locus"
        [ PlanJsonFieldUnknown "plan[\"install-plan\"][1]" "probe"
        , PlanJsonPathUnsafe
            "plan[\"install-plan\"][1][\"pkg-src\"]"
            "path"
            (ByteString8.unpack pathSegmentOneOverValue)
        ]
        pathSegmentOneOverBytes
    , expectExactLeftProblems
        "the exact path-member byte ceiling reaches the independent unknown-field refusal"
        [PlanJsonFieldUnknown "plan[\"install-plan\"][1]" "probe"]
        pathMemberBoundaryBytes
    , expectExactLeftProblems
        "one path-member byte beyond the ceiling is refused at the path locus"
        [ PlanJsonFieldUnknown "plan[\"install-plan\"][1]" "probe"
        , PlanJsonPathUnsafe
            "plan[\"install-plan\"][1][\"pkg-src\"]"
            "path"
            (ByteString8.unpack pathMemberOneOverValue)
        ]
        pathMemberOneOverBytes
    ]

inputByteBoundaryBytes :: ByteString
inputByteBoundaryBytes =
  "null" <> ByteString8.replicate 8388604 ' '

inputByteOneOverBytes :: ByteString
inputByteOneOverBytes =
  "null" <> ByteString8.replicate 8388605 ' '

jsonDepthBoundaryBytes :: ByteString
jsonDepthBoundaryBytes = nestedJsonContainers 64

jsonDepthOneOverBytes :: ByteString
jsonDepthOneOverBytes = nestedJsonContainers 65

jsonTextBoundaryBytes :: ByteString
jsonTextBoundaryBytes =
  jsonString (ByteString8.replicate 1048576 'a')

jsonTextOneOverBytes :: ByteString
jsonTextOneOverBytes =
  jsonString (ByteString8.replicate 1048577 'a')

jsonCollectionBoundaryBytes :: ByteString
jsonCollectionBoundaryBytes =
  jsonArrayOf 65536 "null"

jsonCollectionOneOverBytes :: ByteString
jsonCollectionOneOverBytes =
  jsonArrayOf 65537 "null"

jsonObjectMemberBoundaryBytes :: ByteString
jsonObjectMemberBoundaryBytes = uniqueJsonObjectOf 65536

jsonObjectMemberOneOverBytes :: ByteString
jsonObjectMemberOneOverBytes = uniqueJsonObjectOf 65537

jsonKeyBoundaryBytes :: ByteString
jsonKeyBoundaryBytes = "{\"" <> ByteString8.replicate 1048576 'k' <> "\":null}"

jsonKeyOneOverBytes :: ByteString
jsonKeyOneOverBytes = "{\"" <> ByteString8.replicate 1048577 'k' <> "\":null}"

jsonKeyBoundaryProblems :: Int -> [CompilerElaboratedPlanProblem]
jsonKeyBoundaryProblems count =
  [PlanJsonFieldUnknown "plan" (Text.replicate count "k")]
    <> [ PlanJsonFieldMissing "plan" field
       | field <-
          [ "cabal-version"
          , "cabal-lib-version"
          , "compiler-id"
          , "compiler-abi"
          , "os"
          , "arch"
          , "install-plan"
          ]
       ]

jsonTokenBoundaryBytes :: ByteString
jsonTokenBoundaryBytes =
  "["
    <> ByteString8.intercalate
      ","
      (jsonArrayOf 22 "null" : eightElementJsonObject : replicate 52628 eightElementJsonArray)
    <> "]"

jsonTokenOneOverBytes :: ByteString
jsonTokenOneOverBytes =
  "["
    <> ByteString8.intercalate
      ","
      (jsonArrayOf 23 "null" : eightElementJsonObject : replicate 52628 eightElementJsonArray)
    <> "]"

eightElementJsonArray :: ByteString
eightElementJsonArray = jsonArrayOf 8 "null"

eightElementJsonObject :: ByteString
eightElementJsonObject = uniqueJsonObjectOf 8

jsonRecordEndTokenOneOverBytes :: ByteString
jsonRecordEndTokenOneOverBytes =
  ByteString.take (ByteString.length jsonTokenOneOverBytes - 1) jsonTokenOneOverBytes

jsonProblemBoundaryBytes :: ByteString
jsonProblemBoundaryBytes =
  jsonObjectOf 129 "\"duplicate\":null"

jsonProblemOneOverBytes :: ByteString
jsonProblemOneOverBytes =
  jsonObjectOf 130 "\"duplicate\":null"

semanticProblemBoundaryBytes :: ByteString
semanticProblemBoundaryBytes =
  renderPlan identityFields (replicate 128 "null")

semanticProblemOneOverBytes :: ByteString
semanticProblemOneOverBytes =
  renderPlan identityFields (replicate 129 "null")

observedResultBoundaryBytes, observedResultOneOverBytes :: ByteString
observedResultBoundaryBytes = observedResultLimitPlan 113
observedResultOneOverBytes = observedResultLimitPlan 114

observedResultLimitPlan :: Int -> ByteString
observedResultLimitPlan componentCount =
  renderPlan
    identityFields
    [ preExistingUnit
    , ByteString8.concat
        [ "{\"type\":\"configured\",\"id\":\"result-limit-id\",\"pkg-name\":\"local-package\",\"pkg-version\":\"0.1.0.0\",\"flags\":{},\"style\":\"local\",\"pkg-src\":{\"type\":\"local\",\"path\":\"/immutable/result-limit/.\"},\"components\":{"
        , ByteString8.intercalate
            ","
            [ "\"lib:c" <> decimal3 index <> "\":{\"depends\":[],\"exe-depends\":[]}"
            | index <- [0 .. componentCount - 1]
            ]
        , "},\"build-info\":\"/immutable/build/result-limit-id/build-info.json\",\"dist-dir\":\"/immutable/build/result-limit-id\"}"
        ]
    ]

observedResultBoundarySnapshot, observedResultOneOverSnapshot :: PlanSnapshotView
observedResultBoundarySnapshot = observedResultLimitSnapshot observedResultBoundaryBytes 113
observedResultOneOverSnapshot = observedResultLimitSnapshot observedResultOneOverBytes 114

observedResultLimitSnapshot :: ByteString -> Int -> PlanSnapshotView
observedResultLimitSnapshot bytes componentCount =
  PlanSnapshotView
    (Just (independentInputDigest bytes))
    (ByteString.length bytes)
    "3.16.1.0"
    "3.16.1.0"
    "ghc-9.12.4"
    "6f4d"
    "osx"
    "aarch64"
    [ UnitSnapshotView
        PreExistingUnit
        PreExistingBuildStyle
        "base-id"
        "base"
        "4.21.2.0"
        "pre-existing"
        Nothing
        Nothing
        Nothing
        Nothing
        []
        Nothing
        []
        Nothing
        Nothing
        Nothing
        Nothing
        Nothing
        []
    , UnitSnapshotView
        LocalUnit
        LocalBuildStyle
        "result-limit-id"
        "local-package"
        "0.1.0.0"
        "local"
        (Just "/immutable/result-limit/.")
        Nothing
        Nothing
        Nothing
        []
        (Just AggregateElaboratedComponentShape)
        []
        Nothing
        Nothing
        (Just "/immutable/build/result-limit-id/build-info.json")
        (Just "/immutable/build/result-limit-id")
        Nothing
        [ ComponentSnapshotView
            "result-limit-id"
            ("lib:c" <> Text.pack (ByteString8.unpack (decimal3 index)))
            []
            []
            Nothing
        | index <- [0 .. componentCount - 1]
        ]
    ]

observedResultBoundaryExpectedProblems, observedResultOneOverExpectedProblems
  :: [CompilerElaboratedPlanProblem]
observedResultBoundaryExpectedProblems =
  observedResultMandatoryProblems observedResultBoundaryBytes observedResultBoundarySnapshot 113
    <> observedResultSourcePathProblems 113
observedResultOneOverExpectedProblems =
  observedResultMandatoryProblems observedResultOneOverBytes observedResultOneOverSnapshot 114
    <> [PlanResourceLimitExceeded "observed-variable-problems" 113 114]

observedResultMandatoryProblems
  :: ByteString
  -> PlanSnapshotView
  -> Int
  -> [CompilerElaboratedPlanProblem]
observedResultMandatoryProblems bytes snapshot componentCount =
  [ PlanInputUnauthenticated digest inputBytes
  , PlanArtifactGenerationUnavailable digest inputBytes
  , ExpectedCompilerIdentityUnavailable "ghc-9.12.4" "6f4d"
  , ExpectedPlatformIdentityUnavailable "aarch64" "osx"
  , IndependentDuplicateKeyObservationUnavailable digest inputBytes
  , IndependentComponentUniverseUnavailable componentUniverse
  , ConfigurationBranchClosureUnavailable configurationSubject
  , CppBranchClosureUnavailable configurationSubject
  , IndependentDependencySemanticsUnavailable []
  , PackageSourceBytesIdentityUnavailable sourceSubject
  , BuildArtifactPathIdentityUnavailable buildArtifactSubject
  , LocalSourceRootIdentityLimitedToLexical localRoots
  , LocalSourceRootFilesystemIdentityUnavailable localRoots
  , CompilerElaboratedPlanSnapshotBindingUnavailable
      digest
      inputBytes
      ("3.16.1.0", "3.16.1.0", "ghc-9.12.4", "6f4d", "osx", "aarch64")
      (map unitObservationWireFromSnapshot (planSnapshotUnits snapshot))
      []
      configurationSubject
      sourceSubject
  , CompilerElaboratedPlanOracleQualificationUnavailable
  ]
 where
  digest = independentInputDigest bytes
  inputBytes = ByteString.length bytes
  componentNames =
    [ "lib:c" <> Text.pack (ByteString8.unpack (decimal3 index))
    | index <- [0 .. componentCount - 1]
    ]
  componentUniverse = [("result-limit-id", name) | name <- componentNames]
  configurationSubject =
    [ ( "result-limit-id"
      , LocalBuildStyle
      , Just AggregateElaboratedComponentShape
      , []
      , componentNames
      )
    ]
  sourceSubject =
    [("result-limit-id", "local", Just "/immutable/result-limit/.", Nothing, Nothing, Nothing, Nothing)]
  buildArtifactSubject =
    [ ( "result-limit-id"
      , Just "/immutable/build/result-limit-id/build-info.json"
      , Just "/immutable/build/result-limit-id"
      , Nothing
      )
    ]
  localRoots = [("result-limit-id", "/immutable/result-limit/.")]

observedResultSourcePathProblems :: Int -> [CompilerElaboratedPlanProblem]
observedResultSourcePathProblems componentCount =
  [ LocalComponentSourcePathsUnavailable
      "result-limit-id"
      ("lib:c" <> Text.pack (ByteString8.unpack (decimal3 index)))
      "/immutable/build/result-limit-id/build-info.json"
  | index <- [0 .. componentCount - 1]
  ]

independentInputDigest :: ByteString -> Text
independentInputDigest bytes = Text.pack (show (hash bytes :: Digest SHA256))

unitBoundaryBytes, unitOneOverBytes :: ByteString
unitBoundaryBytes = renderPlan identityFields (replicate 256 "null")
unitOneOverBytes = renderPlan identityFields (replicate 257 "null")

componentBoundaryBytes, componentOneOverBytes :: ByteString
componentBoundaryBytes = componentLimitPlan 128
componentOneOverBytes = componentLimitPlan 129

directComponentCountOneOverBytes :: ByteString
directComponentCountOneOverBytes =
  renderPlan
    identityFields
    [ remoteUnit ("direct-count-" <> decimal3 index)
    | index <- [0 .. 128]
    ]

componentLimitPlan :: Int -> ByteString
componentLimitPlan count =
  renderPlan
    identityFields
    [ preExistingUnit
    , "{\"type\":\"configured\",\"id\":\"component-limit-id\",\"pkg-name\":\"local-package\",\"pkg-version\":\"0.1.0.0\",\"flags\":{},\"style\":\"local\",\"pkg-src\":{\"type\":\"local\",\"path\":\"/immutable/repository/.\"},\"components\":{"
        <> ByteString8.intercalate
          ","
          [ "\"lib:c" <> decimal3 index <> "\":null"
          | index <- [0 .. count - 1]
          ]
        <> "},\"build-info\":\"/immutable/build/component-limit-id/build-info.json\",\"dist-dir\":\"/immutable/build/component-limit-id\"}"
    ]

componentBoundaryProblems :: [CompilerElaboratedPlanProblem]
componentBoundaryProblems =
  [ PlanJsonFieldTypeMismatch
      "plan[\"install-plan\"][1][\"components\"]"
      ("lib:c" <> Text.pack (ByteString8.unpack (decimal3 index)))
      "object"
  | index <- [0 .. 127]
  ]

dependencyBoundaryBytes, dependencyOneOverBytes :: ByteString
dependencyBoundaryBytes = dependencyLimitPlan 256
dependencyOneOverBytes = dependencyLimitPlan 257

rootExecutableDependencyCountOneOverBytes :: ByteString
rootExecutableDependencyCountOneOverBytes =
  renderPlan
    identityFields
    [ preExistingUnit
    , localUnitWithExecutableDependencies
        "root-executable-limit-id"
        ["missing-" <> decimal3 index | index <- [0 .. 255]]
    ]

nestedDependencyCountOneOverBytes :: ByteString
nestedDependencyCountOneOverBytes =
  renderPlan
    identityFields
    [ preExistingUnit
    , aggregateLocalUnit
        ["missing-" <> decimal3 index | index <- [0 .. 256]]
        []
        ""
    ]

nestedExecutableDependencyCountOneOverBytes :: ByteString
nestedExecutableDependencyCountOneOverBytes =
  renderPlan
    identityFields
    [ preExistingUnit
    , ByteString8.concat
        [ "{\"type\":\"configured\",\"id\":\"nested-executable-limit-id\",\"pkg-name\":\"local-package\",\"pkg-version\":\"0.1.0.0\",\"flags\":{},\"style\":\"local\",\"pkg-src\":{\"type\":\"local\",\"path\":\"/immutable/nested-executable/.\"},\"components\":{\"exe:tool\":{\"depends\":[],\"exe-depends\":["
        , ByteString8.intercalate
            ","
            [jsonString ("missing-" <> decimal3 index) | index <- [0 .. 256]]
        , "]}},\"build-info\":\"/immutable/build/nested-executable-limit-id/build-info.json\",\"dist-dir\":\"/immutable/build/nested-executable-limit-id\",\"bin-file\":\"/immutable/build/nested-executable-limit-id/tool\"}"
        ]
    ]

dependencyLimitPlan :: Int -> ByteString
dependencyLimitPlan count =
  renderPlan
    identityFields
    [ preExistingUnit
    , localUnit
        "dependency-limit-id"
        "/immutable/repository/."
        "lib:core"
        ["missing-" <> decimal3 index | index <- [0 .. count - 1]]
        ""
    ]

flagBoundaryBytes, flagOneOverBytes :: ByteString
flagBoundaryBytes = flagLimitPlan 128
flagOneOverBytes = flagLimitPlan 129

flagLimitPlan :: Int -> ByteString
flagLimitPlan count =
  renderPlan
    identityFields
    [ preExistingUnit
    , "{\"type\":\"configured\",\"id\":\"flag-limit-id\",\"pkg-name\":\"local-package\",\"pkg-version\":\"0.1.0.0\",\"flags\":{"
        <> ByteString8.intercalate
          ","
          [ "\"flag" <> decimal3 index <> "\":null"
          | index <- [0 .. count - 1]
          ]
        <> "},\"style\":\"local\",\"pkg-src\":{\"type\":\"local\",\"path\":\"/immutable/repository/.\"},\"component-name\":\"lib\",\"depends\":[],\"exe-depends\":[],\"build-info\":\"/immutable/build/flag-limit-id/build-info.json\",\"dist-dir\":\"/immutable/build/flag-limit-id\"}"
    ]

flagBoundaryProblems :: [CompilerElaboratedPlanProblem]
flagBoundaryProblems =
  [ PlanJsonFieldTypeMismatch
      "plan[\"install-plan\"][1][\"flags\"]"
      ("flag" <> Text.pack (ByteString8.unpack (decimal3 index)))
      "null"
  | index <- [0 .. 127]
  ]

sourceMemberBoundaryBytes, sourceMemberOneOverBytes :: ByteString
sourceMemberBoundaryBytes = localLimitPlan "/immutable/repository/." ["\"extra-0\":null"] []
sourceMemberOneOverBytes =
  localLimitPlan "/immutable/repository/." ["\"extra-0\":null", "\"extra-1\":null"] []

semanticScalarBoundaryBytes, semanticScalarOneOverBytes :: ByteString
semanticScalarBoundaryBytes = flagScalarPlan 512
semanticScalarOneOverBytes = flagScalarPlan 513

sourceByteBoundaryBytes, sourceByteOneOverBytes :: ByteString
sourceByteBoundaryBytes = repositoryLocatorLimitPlan 4088
sourceByteOneOverBytes = repositoryLocatorLimitPlan 4089

repositoryLocatorLimitPlan :: Int -> ByteString
repositoryLocatorLimitPlan payloadLength =
  renderPlan
    identityFields
    [ preExistingUnit
    , "{\"type\":\"configured\",\"id\":\"source-limit-id\",\"pkg-name\":\"remote-package\",\"pkg-version\":\"1.0.0\",\"flags\":{},\"style\":\"global\",\"pkg-src\":{\"type\":\"repo-tar\",\"repo\":{\"type\":\"forged-repo\",\"uri\":\"https://"
        <> ByteString8.replicate payloadLength 'a'
        <> "\"}},\"component-name\":\"lib\",\"depends\":[],\"exe-depends\":[],\"pkg-cabal-sha256\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"pkg-src-sha256\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"}"
    ]

flagScalarPlan :: Int -> ByteString
flagScalarPlan count =
  renderPlan
    identityFields
    [ preExistingUnit
    , "{\"type\":\"configured\",\"id\":\"flag-scalar-id\",\"pkg-name\":\"local-package\",\"pkg-version\":\"0.1.0.0\",\"flags\":{\""
        <> ByteString8.replicate count 'a'
        <> "\":null},\"style\":\"local\",\"pkg-src\":{\"type\":\"local\",\"path\":\"/immutable/repository/.\"},\"component-name\":\"lib\",\"depends\":[],\"exe-depends\":[],\"build-info\":\"/immutable/build/flag-scalar-id/build-info.json\",\"dist-dir\":\"/immutable/build/flag-scalar-id\"}"
    ]

pathByteBoundaryValue, pathByteOneOverValue :: ByteString
pathByteBoundaryValue = boundedPath 127
pathByteOneOverValue = boundedPath 128

boundedPath :: Int -> ByteString
boundedPath finalLength =
  "/"
    <> ByteString8.intercalate
      "/"
      (replicate 15 (ByteString8.replicate 255 'a') <> [ByteString8.replicate 127 'b', ByteString8.replicate finalLength 'c'])

pathByteBoundaryBytes, pathByteOneOverBytes :: ByteString
pathByteBoundaryBytes = localLimitPlan pathByteBoundaryValue [] ["\"probe\":true"]
pathByteOneOverBytes = localLimitPlan pathByteOneOverValue [] ["\"probe\":true"]

pathSegmentBoundaryValue, pathSegmentOneOverValue :: ByteString
pathSegmentBoundaryValue = "/" <> ByteString8.intercalate "/" (replicate 64 "a")
pathSegmentOneOverValue = "/" <> ByteString8.intercalate "/" (replicate 65 "a")

pathSegmentBoundaryBytes, pathSegmentOneOverBytes :: ByteString
pathSegmentBoundaryBytes = localLimitPlan pathSegmentBoundaryValue [] ["\"probe\":true"]
pathSegmentOneOverBytes = localLimitPlan pathSegmentOneOverValue [] ["\"probe\":true"]

pathMemberBoundaryValue, pathMemberOneOverValue :: ByteString
pathMemberBoundaryValue = "/" <> ByteString8.replicate 255 'a'
pathMemberOneOverValue = "/" <> ByteString8.replicate 256 'a'

pathMemberBoundaryBytes, pathMemberOneOverBytes :: ByteString
pathMemberBoundaryBytes = localLimitPlan pathMemberBoundaryValue [] ["\"probe\":true"]
pathMemberOneOverBytes = localLimitPlan pathMemberOneOverValue [] ["\"probe\":true"]

localLimitPlan :: ByteString -> [ByteString] -> [ByteString] -> ByteString
localLimitPlan path sourceExtras unitExtras =
  renderPlan
    identityFields
    [ preExistingUnit
    , "{\"type\":\"configured\",\"id\":\"local-limit-id\",\"pkg-name\":\"local-package\",\"pkg-version\":\"0.1.0.0\",\"flags\":{},\"style\":\"local\",\"pkg-src\":{\"type\":\"local\",\"path\":\""
        <> path
        <> "\""
        <> foldMap ("," <>) sourceExtras
        <> "},\"component-name\":\"lib\",\"depends\":[],\"exe-depends\":[],\"build-info\":\"/immutable/build/local-limit-id/build-info.json\",\"dist-dir\":\"/immutable/build/local-limit-id\""
        <> foldMap ("," <>) unitExtras
        <> "}"
    ]

decimal3 :: Int -> ByteString
decimal3 value =
  let rendered = ByteString8.pack (show value)
   in ByteString8.replicate (3 - ByteString8.length rendered) '0' <> rendered

nestedJsonContainers :: Int -> ByteString
nestedJsonContainers count =
  foldr wrap "null" (take count (cycle [True, False]))
 where
  wrap isArray value
    | isArray = "[" <> value <> "]"
    | otherwise = "{\"nested\":" <> value <> "}"

jsonArrayOf :: Int -> ByteString -> ByteString
jsonArrayOf count value =
  "[" <> ByteString8.intercalate "," (replicate count value) <> "]"

jsonObjectOf :: Int -> ByteString -> ByteString
jsonObjectOf count field =
  "{" <> ByteString8.intercalate "," (replicate count field) <> "}"

uniqueJsonObjectOf :: Int -> ByteString
uniqueJsonObjectOf count =
  "{"
    <> ByteString8.intercalate
      ","
      [ "\"k" <> ByteString8.pack (show index) <> "\":null"
      | index <- [0 .. count - 1]
      ]
    <> "}"

positivePlanBytes :: ByteString
positivePlanBytes =
  renderPlan
    identityFields
    [preExistingUnit, remoteUnit "remote-id", localUnit "local-id" "/immutable/repository/." "lib:core" ["base-id", "remote-id"] ""]

aggregateSingletonPlanBytes :: ByteString
aggregateSingletonPlanBytes =
  renderPlan identityFields [preExistingUnit, aggregateSingletonLocalUnit]

aggregateSingletonLocalUnit :: ByteString
aggregateSingletonLocalUnit =
  "{\"type\":\"configured\",\"id\":\"singleton-id\",\"pkg-name\":\"local-package\",\"pkg-version\":\"0.1.0.0\",\"flags\":{\"variant\":false},\"style\":\"local\",\"pkg-src\":{\"type\":\"local\",\"path\":\"/immutable/repository/.\"},\"components\":{\"lib\":{\"depends\":[\"base-id\"],\"exe-depends\":[]}},\"build-info\":\"/immutable/build/singleton-id/build-info.json\",\"dist-dir\":\"/immutable/build/singleton-id\"}"

emptyLocalPlanBytes :: ByteString
emptyLocalPlanBytes = renderPlan identityFields [preExistingUnit, remoteUnit "remote-id"]

duplicateUnitPlanBytes :: ByteString
duplicateUnitPlanBytes =
  renderPlan
    identityFields
    [ preExistingUnit
    , remoteUnit "remote-id"
    , localUnit "local-id" "/immutable/repository/." "lib:core" ["base-id", "remote-id"] ""
    , localUnit "local-id" "/immutable/repository/second" "lib:second" ["base-id"] ""
    ]

duplicateComponentPlanBytes :: ByteString
duplicateComponentPlanBytes =
  renderPlan
    identityFields
    [ preExistingUnit
    , remoteUnit "remote-id"
    , localUnit "local-a" "/immutable/repository/." "lib:core" ["base-id"] ""
    , localUnit "local-b" "/immutable/repository/." "lib:core" ["base-id"] ""
    ]

missingCompilerIdentityPlanBytes :: ByteString
missingCompilerIdentityPlanBytes =
  renderPlan
    (filter (/= "\"compiler-id\":\"ghc-9.12.4\"") identityFields)
    [preExistingUnit, remoteUnit "remote-id", localUnit "local-id" "/immutable/repository/." "lib:core" ["base-id"] ""]

unknownIdentityPlanBytes :: ByteString
unknownIdentityPlanBytes =
  renderPlan
    (identityFields <> ["\"platform\":\"aarch64-osx\""])
    [preExistingUnit, remoteUnit "remote-id", localUnit "local-id" "/immutable/repository/." "lib:core" ["base-id"] ""]

duplicateCompilerIdentityPlanBytes :: ByteString
duplicateCompilerIdentityPlanBytes =
  renderPlan
    (identityFields <> ["\"compiler-id\":\"ghc-forged\""])
    [preExistingUnit, remoteUnit "remote-id", localUnit "local-id" "/immutable/repository/." "lib:core" ["base-id"] ""]

tripleCompilerIdentityPlanBytes :: ByteString
tripleCompilerIdentityPlanBytes =
  renderPlan
    (identityFields <> ["\"compiler-id\":\"ghc-forged\"", "\"compiler-id\":\"ghc-another\""])
    [preExistingUnit, localUnit "local-id" "/immutable/repository/." "lib" ["base-id"] ""]

duplicateFlagPlanBytes :: ByteString
duplicateFlagPlanBytes =
  renderPlan identityFields [preExistingUnit, duplicateFlagUnit]

duplicateFlagUnit :: ByteString
duplicateFlagUnit =
  "{\"type\":\"configured\",\"id\":\"local-id\",\"pkg-name\":\"local-package\",\"pkg-version\":\"0.1.0.0\",\"flags\":{\"variant\":false,\"variant\":true},\"style\":\"local\",\"pkg-src\":{\"type\":\"local\",\"path\":\"/immutable/repository/.\"},\"component-name\":\"lib\",\"depends\":[\"base-id\"],\"exe-depends\":[],\"build-info\":\"/immutable/build/local-id/build-info.json\",\"dist-dir\":\"/immutable/build/local-id\"}"

duplicateUnitFieldPlanBytes :: ByteString
duplicateUnitFieldPlanBytes =
  renderPlan identityFields [preExistingUnit, duplicateUnitFieldUnit]

duplicateUnitFieldUnit :: ByteString
duplicateUnitFieldUnit =
  "{\"type\":\"configured\",\"id\":\"remote-id\",\"id\":\"forged-id\",\"pkg-name\":\"remote-package\",\"pkg-version\":\"1.0.0\",\"flags\":{},\"style\":\"global\",\"pkg-src\":{\"type\":\"repo-tar\",\"repo\":{\"type\":\"secure-repo\",\"uri\":\"https://example.invalid/index\"}},\"component-name\":\"lib\",\"depends\":[\"base-id\"],\"exe-depends\":[],\"pkg-cabal-sha256\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"pkg-src-sha256\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"}"

duplicateNestedRepositoryFieldPlanBytes :: ByteString
duplicateNestedRepositoryFieldPlanBytes =
  renderPlan identityFields [preExistingUnit, duplicateNestedRepositoryFieldUnit]

duplicateNestedRepositoryFieldUnit :: ByteString
duplicateNestedRepositoryFieldUnit =
  "{\"type\":\"configured\",\"id\":\"remote-id\",\"pkg-name\":\"remote-package\",\"pkg-version\":\"1.0.0\",\"flags\":{},\"style\":\"global\",\"pkg-src\":{\"type\":\"repo-tar\",\"repo\":{\"type\":\"secure-repo\",\"uri\":\"https://example.invalid/index\",\"uri\":\"https://forged.invalid/index\"}},\"component-name\":\"lib\",\"depends\":[\"base-id\"],\"exe-depends\":[],\"pkg-cabal-sha256\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"pkg-src-sha256\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"}"

duplicateEscapedCompilerIdentityPlanBytes :: ByteString
duplicateEscapedCompilerIdentityPlanBytes =
  renderPlan
    (identityFields <> ["\"\\u0063ompiler-id\":\"ghc-forged\""])
    [preExistingUnit, localUnit "local-id" "/immutable/repository/." "lib:core" ["base-id"] ""]

duplicateNestedComponentFieldPlanBytes :: ByteString
duplicateNestedComponentFieldPlanBytes =
  renderPlan identityFields [preExistingUnit, duplicateNestedComponentFieldUnit]

duplicateNestedComponentFieldUnit :: ByteString
duplicateNestedComponentFieldUnit =
  "{\"type\":\"configured\",\"id\":\"aggregate-id\",\"pkg-name\":\"local-package\",\"pkg-version\":\"0.1.0.0\",\"flags\":{},\"style\":\"local\",\"pkg-src\":{\"type\":\"local\",\"path\":\"/immutable/repository/.\"},\"components\":{\"lib:with.dot\":{\"depends\":[\"base-id\"],\"depends\":[\"base-id\"],\"exe-depends\":[]}},\"build-info\":\"/immutable/build/aggregate-id/build-info.json\",\"dist-dir\":\"/immutable/build/aggregate-id\"}"

duplicateWithTrailingGarbagePlanBytes :: ByteString
duplicateWithTrailingGarbagePlanBytes =
  duplicateCompilerIdentityPlanBytes <> " trailing-garbage"

emptyConfiguredComponentMapPlanBytes :: ByteString
emptyConfiguredComponentMapPlanBytes =
  renderPlan identityFields [preExistingUnit, emptyConfiguredComponentMapUnit]

emptyConfiguredComponentMapUnit :: ByteString
emptyConfiguredComponentMapUnit =
  "{\"type\":\"configured\",\"id\":\"empty-components-id\",\"pkg-name\":\"remote-package\",\"pkg-version\":\"1.0.0\",\"flags\":{},\"style\":\"global\",\"pkg-src\":{\"type\":\"repo-tar\",\"repo\":{\"type\":\"secure-repo\",\"uri\":\"https://example.invalid/index\"}},\"components\":{},\"pkg-cabal-sha256\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"pkg-src-sha256\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"}"

malformedComponentNamePlanBytes :: ByteString
malformedComponentNamePlanBytes =
  renderPlan
    identityFields
    [preExistingUnit, localUnit "local-id" "/immutable/repository/." "invented" ["base-id"] ""]

malformedCompilerGrammarPlanBytes :: ByteString
malformedCompilerGrammarPlanBytes =
  renderPlan
    (map replaceCompiler identityFields)
    [preExistingUnit, localUnit "local-id" "/immutable/repository/." "lib" ["base-id"] ""]
 where
  replaceCompiler field
    | field == "\"compiler-id\":\"ghc-9.12.4\"" = "\"compiler-id\":\"ghc-9..12\""
    | otherwise = field

malformedFlagNamePlanBytes :: ByteString
malformedFlagNamePlanBytes =
  renderPlan identityFields [preExistingUnit, malformedFlagNameUnit]

malformedFlagNameUnit :: ByteString
malformedFlagNameUnit =
  "{\"type\":\"configured\",\"id\":\"local-id\",\"pkg-name\":\"local-package\",\"pkg-version\":\"0.1.0.0\",\"flags\":{\"\":false},\"style\":\"local\",\"pkg-src\":{\"type\":\"local\",\"path\":\"/immutable/repository/.\"},\"component-name\":\"lib\",\"depends\":[\"base-id\"],\"exe-depends\":[],\"build-info\":\"/immutable/build/local-id/build-info.json\",\"dist-dir\":\"/immutable/build/local-id\"}"

relativeLocalSourcePlanBytes :: ByteString
relativeLocalSourcePlanBytes =
  renderPlan
    identityFields
    [preExistingUnit, localUnit "local-id" "relative/source" "lib" ["base-id"] ""]

aggregateTopLevelDependencyPlanBytes :: ByteString
aggregateTopLevelDependencyPlanBytes =
  renderPlan
    identityFields
    [preExistingUnit, aggregateLocalUnit ["base-id"] [] "\"depends\":[\"base-id\"]"]

aggregateTopLevelExecutableDependencyPlanBytes :: ByteString
aggregateTopLevelExecutableDependencyPlanBytes =
  renderPlan
    identityFields
    [preExistingUnit, aggregateLocalUnit ["base-id"] [] "\"exe-depends\":[\"base-id\"]"]

ambiguousComponentShapePlanBytes :: ByteString
ambiguousComponentShapePlanBytes =
  renderPlan
    identityFields
    [ preExistingUnit
    , localUnit
        "local-id"
        "/immutable/repository/."
        "lib"
        ["base-id"]
        "\"components\":{\"lib\":{\"depends\":[\"base-id\"],\"exe-depends\":[]}}"
    ]

aggregateDuplicateDependencyPlanBytes :: ByteString
aggregateDuplicateDependencyPlanBytes =
  renderPlan identityFields [preExistingUnit, aggregateLocalUnit ["base-id", "base-id"] [] ""]

aggregateUnknownDependencyPlanBytes :: ByteString
aggregateUnknownDependencyPlanBytes =
  renderPlan identityFields [preExistingUnit, aggregateLocalUnit ["missing-id"] [] ""]

aggregateSelfDependencyPlanBytes :: ByteString
aggregateSelfDependencyPlanBytes =
  renderPlan identityFields [preExistingUnit, aggregateLocalUnit ["aggregate-id"] [] ""]

duplicateDependencyPlanBytes :: ByteString
duplicateDependencyPlanBytes =
  renderPlan
    identityFields
    [preExistingUnit, localUnit "local-id" "/immutable/repository/." "lib:core" ["base-id", "base-id"] ""]

duplicateExecutableDependencyPlanBytes :: ByteString
duplicateExecutableDependencyPlanBytes =
  renderPlan
    identityFields
    [preExistingUnit, localUnitWithExecutableDependencies "local-id" ["base-id", "base-id"]]

unknownExecutableDependencyPlanBytes :: ByteString
unknownExecutableDependencyPlanBytes =
  renderPlan
    identityFields
    [preExistingUnit, localUnitWithExecutableDependencies "local-id" ["missing-tool"]]

selfDependencyPlanBytes :: ByteString
selfDependencyPlanBytes =
  renderPlan
    identityFields
    [preExistingUnit, localUnit "local-id" "/immutable/repository/." "lib:core" ["base-id", "local-id"] ""]

cyclicDependencyPlanBytes :: ByteString
cyclicDependencyPlanBytes =
  renderPlan
    identityFields
    [ preExistingUnit
    , localUnit "local-a" "/immutable/repository/a" "lib:a" ["base-id", "local-b"] ""
    , localUnit "local-b" "/immutable/repository/b" "lib:b" ["base-id", "local-a"] ""
    ]

malformedRemoteSourceHashPlanBytes :: ByteString
malformedRemoteSourceHashPlanBytes =
  renderPlan
    identityFields
    [ preExistingUnit
    , repositoryTarUnit
        "remote-bad-source-hash"
        "secure-repo"
        (Just validCabalHashBytes)
        (Just "short-source")
        ""
    ]

malformedRepositoryCabalHashPlanBytes :: ByteString
malformedRepositoryCabalHashPlanBytes =
  renderPlan
    identityFields
    [ preExistingUnit
    , repositoryTarUnit
        "remote-bad-cabal-hash"
        "secure-repo"
        (Just "short-cabal")
        (Just validSourceHashBytes)
        ""
    ]

missingRemoteSourceHashPlanBytes :: ByteString
missingRemoteSourceHashPlanBytes =
  renderPlan
    identityFields
    [ preExistingUnit
    , repositoryTarUnit
        "remote-missing-source-hash"
        "secure-repo"
        (Just validCabalHashBytes)
        Nothing
        ""
    ]

missingRepositoryCabalHashPlanBytes :: ByteString
missingRepositoryCabalHashPlanBytes =
  renderPlan
    identityFields
    [ preExistingUnit
    , repositoryTarUnit
        "remote-missing-cabal-hash"
        "secure-repo"
        Nothing
        (Just validSourceHashBytes)
        ""
    ]

unsupportedRepositoryTypePlanBytes :: ByteString
unsupportedRepositoryTypePlanBytes =
  renderPlan
    identityFields
    [ preExistingUnit
    , repositoryTarUnit
        "remote-forged-repository-type"
        "forged-repo"
        (Just validCabalHashBytes)
        (Just validSourceHashBytes)
        ""
    ]

unsupportedSourceRepositoryTypePlanBytes :: ByteString
unsupportedSourceRepositoryTypePlanBytes =
  renderPlan
    identityFields
    [ preExistingUnit
    , sourceRepositoryUnit
        "source-repo-id"
        "hg"
        "0123456789abcdef0123456789abcdef01234567"
        Nothing
        (Just validSourceHashBytes)
    ]

localUnexpectedSourceHashPlanBytes :: ByteString
localUnexpectedSourceHashPlanBytes =
  renderPlan
    identityFields
    [ preExistingUnit
    , localUnit
        "local-id"
        "/immutable/repository/."
        "lib:core"
        ["base-id"]
        ("\"pkg-src-sha256\":\"" <> validSourceHashBytes <> "\"")
    ]

sourceRepositoryUnexpectedCabalHashPlanBytes :: ByteString
sourceRepositoryUnexpectedCabalHashPlanBytes =
  renderPlan
    identityFields
    [ preExistingUnit
    , sourceRepositoryUnit
        "source-repo-id"
        "git"
        "0123456789abcdef0123456789abcdef01234567"
        (Just validCabalHashBytes)
        (Just validSourceHashBytes)
    ]

mutableSourceRepositoryPlanBytes :: ByteString
mutableSourceRepositoryPlanBytes =
  renderPlan
    identityFields
    [ preExistingUnit
    , sourceRepositoryUnit
        "source-repo-id"
        "git"
        "master"
        Nothing
        (Just validSourceHashBytes)
    ]

inplaceMissingBuildInfoPlanBytes :: ByteString
inplaceMissingBuildInfoPlanBytes =
  renderPlan identityFields [preExistingUnit, inplaceRemoteUnit "inplace-no-build-info" False]

localMissingDistDirectoryPlanBytes :: ByteString
localMissingDistDirectoryPlanBytes =
  renderPlan identityFields [preExistingUnit, localUnitWithoutDistDirectory]

localUnitWithoutDistDirectory :: ByteString
localUnitWithoutDistDirectory =
  "{\"type\":\"configured\",\"id\":\"local-no-dist\",\"pkg-name\":\"local-package\",\"pkg-version\":\"0.1.0.0\",\"flags\":{},\"style\":\"local\",\"pkg-src\":{\"type\":\"local\",\"path\":\"/immutable/repository/.\"},\"component-name\":\"lib:core\",\"depends\":[\"base-id\"],\"exe-depends\":[],\"build-info\":\"/immutable/build/local-no-dist/build-info.json\"}"

globalUnexpectedBuildInfoPlanBytes :: ByteString
globalUnexpectedBuildInfoPlanBytes =
  renderPlan
    identityFields
    [ preExistingUnit
    , repositoryTarUnit
        "remote-unexpected-build-info"
        "secure-repo"
        (Just validCabalHashBytes)
        (Just validSourceHashBytes)
        "\"build-info\":\"/impossible/remote-build-info.json\""
    ]

libraryUnexpectedBinaryPlanBytes :: ByteString
libraryUnexpectedBinaryPlanBytes =
  renderPlan
    identityFields
    [ preExistingUnit
    , localUnit
        "local-library"
        "/immutable/repository/."
        "lib:core"
        ["base-id"]
        "\"bin-file\":\"/immutable/build/local-library/not-a-library-binary\""
    ]

executableMissingBinaryPlanBytes :: ByteString
executableMissingBinaryPlanBytes =
  renderPlan identityFields [preExistingUnit, executableUnitWithoutBinary]

executableUnitWithoutBinary :: ByteString
executableUnitWithoutBinary =
  "{\"type\":\"configured\",\"id\":\"tool-no-binary\",\"pkg-name\":\"local-package\",\"pkg-version\":\"0.1.0.0\",\"flags\":{},\"style\":\"local\",\"pkg-src\":{\"type\":\"local\",\"path\":\"/immutable/repository/.\"},\"component-name\":\"exe:tool\",\"depends\":[\"base-id\"],\"exe-depends\":[],\"build-info\":\"/immutable/build/tool-no-binary/build-info.json\",\"dist-dir\":\"/immutable/build/tool-no-binary\"}"

unknownDependencyPlanBytes :: ByteString
unknownDependencyPlanBytes =
  renderPlan
    identityFields
    [ preExistingUnit
    , remoteUnit "remote-id"
    , localUnit "local-id" "/immutable/repository/." "lib:core" ["base-id", "remote-other"] ""
    ]

alteredPackageTypePlanBytes :: ByteString
alteredPackageTypePlanBytes =
  renderPlan identityFields [preExistingUnit, remoteUnit "remote-id", alteredPackageTypeUnit]

unknownLocalFieldPlanBytes :: ByteString
unknownLocalFieldPlanBytes =
  renderPlan
    identityFields
    [ preExistingUnit
    , remoteUnit "remote-id"
    , localUnit "local-id" "/immutable/repository/." "lib:core" ["base-id"] "\"compiler-input\":true"
    ]

allJsonValueKindsPlanBytes :: ByteString
allJsonValueKindsPlanBytes =
  "{\"cabal-version\":{},\"cabal-lib-version\":[],\"compiler-id\":0,\"compiler-abi\":false,\"os\":null,\"arch\":\"aarch64\",\"install-plan\":\"not-an-array\"}"

emptyRequiredTextPlanBytes :: ByteString
emptyRequiredTextPlanBytes =
  renderPlan
    ("\"cabal-version\":\"\"" : drop 1 identityFields)
    [preExistingUnit]

missingRequiredObjectPlanBytes :: ByteString
missingRequiredObjectPlanBytes =
  renderPlan identityFields [preExistingUnit, configuredUnitWithPackageSource ""]

mistypedRequiredObjectPlanBytes :: ByteString
mistypedRequiredObjectPlanBytes =
  renderPlan identityFields [preExistingUnit, configuredUnitWithPackageSource "\"pkg-src\":false"]

configuredUnitWithPackageSource :: ByteString -> ByteString
configuredUnitWithPackageSource packageSourceField =
  ByteString8.concat
    [ "{\"type\":\"configured\",\"id\":\"local-id\",\"pkg-name\":\"local-package\",\"pkg-version\":\"0.1.0.0\",\"flags\":{},\"style\":\"local\""
    , if ByteString8.null packageSourceField then "" else "," <> packageSourceField
    , ",\"component-name\":\"lib\",\"depends\":[\"base-id\"],\"exe-depends\":[],\"build-info\":\"/immutable/build/local-id/build-info.json\",\"dist-dir\":\"/immutable/build/local-id\"}"
    ]

emptyOptionalTextPlanBytes :: ByteString
emptyOptionalTextPlanBytes =
  renderPlan
    identityFields
    [ preExistingUnit
    , repositoryTarUnit "remote-id" "secure-repo" (Just validCabalHashBytes) (Just validSourceHashBytes) "\"build-info\":\"\""
    ]

mistypedOptionalTextPlanBytes :: ByteString
mistypedOptionalTextPlanBytes =
  renderPlan
    identityFields
    [ preExistingUnit
    , repositoryTarUnit "remote-id" "secure-repo" (Just validCabalHashBytes) (Just validSourceHashBytes) "\"build-info\":false"
    ]

missingDependencyArrayPlanBytes :: ByteString
missingDependencyArrayPlanBytes =
  renderPlan identityFields ["{\"type\":\"pre-existing\",\"id\":\"base-id\",\"pkg-name\":\"base\",\"pkg-version\":\"4.21.2.0\"}"]

mistypedDependencyArrayPlanBytes :: ByteString
mistypedDependencyArrayPlanBytes =
  renderPlan identityFields [preExistingUnitWithDependencies "false"]

emptyDependencyElementPlanBytes :: ByteString
emptyDependencyElementPlanBytes =
  renderPlan identityFields [preExistingUnitWithDependencies "[\"\"]"]

mistypedDependencyElementPlanBytes :: ByteString
mistypedDependencyElementPlanBytes =
  renderPlan identityFields [preExistingUnitWithDependencies "[false]"]

malformedDependencyIdentityPlanBytes :: ByteString
malformedDependencyIdentityPlanBytes =
  renderPlan identityFields [preExistingUnitWithDependencies "[\"bad@identity\"]"]

preExistingUnknownDependencyPlanBytes :: ByteString
preExistingUnknownDependencyPlanBytes =
  renderPlan identityFields [preExistingUnitWithDependencies "[\"missing-id\"]"]

preExistingUnitWithDependencies :: ByteString -> ByteString
preExistingUnitWithDependencies dependencies =
  "{\"type\":\"pre-existing\",\"id\":\"base-id\",\"pkg-name\":\"base\",\"pkg-version\":\"4.21.2.0\",\"depends\":"
    <> dependencies
    <> "}"

uppercasePortableIdentityPlanBytes :: ByteString
uppercasePortableIdentityPlanBytes =
  renderPlan
    identityFields
    ["{\"type\":\"pre-existing\",\"id\":\"BASE-ID\",\"pkg-name\":\"base\",\"pkg-version\":\"4.21.2.0\",\"depends\":[],\"probe\":true}"]

portableIdentityAlternativePlanBytes :: ByteString -> ByteString
portableIdentityAlternativePlanBytes identity =
  renderPlan
    identityFields
    [ "{\"type\":\"pre-existing\",\"id\":\""
        <> identity
        <> "\",\"pkg-name\":\"base\",\"pkg-version\":\"4.21.2.0\",\"depends\":[],\"probe\":true}"
    ]

flagAlternativeControlProblems :: ByteString -> [String]
flagAlternativeControlProblems flagName =
  expectExactLeftProblems
    ("the admitted flag alternative remains exact: " <> ByteString8.unpack flagName)
    [ConfiguredComponentNameMalformed "flag-control-id" "foreign"]
    ( renderPlan
        identityFields
        [ preExistingUnit
        , "{\"type\":\"configured\",\"id\":\"flag-control-id\",\"pkg-name\":\"local-package\",\"pkg-version\":\"0.1.0.0\",\"flags\":{\""
            <> flagName
            <> "\":false},\"style\":\"local\",\"pkg-src\":{\"type\":\"local\",\"path\":\"/immutable/repository/.\"},\"component-name\":\"foreign\",\"depends\":[\"base-id\"],\"exe-depends\":[],\"build-info\":\"/immutable/build/flag-control-id/build-info.json\",\"dist-dir\":\"/immutable/build/flag-control-id\"}"
        ]
    )

lowerHexAlternativeControlProblems :: String -> ByteString -> [String]
lowerHexAlternativeControlProblems label sourceHash =
  expectExactLeftProblems
    label
    [ RepositoryCabalHashMalformed
        "hash-alternative-id"
        "gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg"
    ]
    ( renderPlan
        identityFields
        [ preExistingUnit
        , repositoryTarUnit
            "hash-alternative-id"
            "secure-repo"
            (Just "gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg")
            (Just sourceHash)
            ""
        ]
    )

sourceRepositoryProjectionProblems :: [String]
sourceRepositoryProjectionProblems =
  sourceRepositoryGlobalProjectionProblems <> sourceRepositoryInplaceProjectionProblems

localSourceRootOrderProblems :: [String]
localSourceRootOrderProblems =
  case inspectCompilerElaboratedPlanDiagnostic localSourceRootOrderPlanBytes of
    Left problems ->
      [ "multiple local roots retain deterministic subject order: plan was rejected with "
          <> show problems
      ]
    Right plan ->
      concat
        [ expectEqual
            "multiple local roots retain deterministic subject order"
            [[("local-a-id", "/immutable/repository/a"), ("local-z-id", "/immutable/repository/z")]]
            [subject | LocalSourceRootIdentityLimitedToLexical subject <- diagnosticProblems plan]
        , expectEqual
            "multiple local roots retain deterministic subject order"
            [[("local-a-id", "/immutable/repository/a"), ("local-z-id", "/immutable/repository/z")]]
            [subject | LocalSourceRootFilesystemIdentityUnavailable subject <- diagnosticProblems plan]
        ]

localSourceRootOrderPlanBytes :: ByteString
localSourceRootOrderPlanBytes =
  renderPlan
    identityFields
    [ preExistingUnit
    , localUnit "local-z-id" "/immutable/repository/z" "lib:z" ["base-id"] ""
    , localUnit "local-a-id" "/immutable/repository/a" "lib:a" ["base-id"] ""
    ]

sourceRepositoryGlobalProjectionProblems :: [String]
sourceRepositoryGlobalProjectionProblems =
  case inspectCompilerElaboratedPlanDiagnostic sourceRepositoryGlobalPlanBytes of
    Left problems ->
      [ "source-repository global projection retains kind, repository type, location, and tag: plan was rejected with "
          <> show problems
      ]
    Right plan ->
      expectEqual
        "source-repository global projection retains kind, repository type, location, and tag"
        [ ( "source-repo"
          , Just "git"
          , Just "https://example.invalid/source.git"
          , Just "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
          )
        ]
        [ ( diagnosticElaboratedUnitPackageSourceKind unit
          , diagnosticElaboratedUnitRepositoryType unit
          , diagnosticElaboratedUnitPackageSourceLocation unit
          , diagnosticElaboratedUnitPackageSourceTag unit
          )
        | unit <- diagnosticUnits plan
        , diagnosticElaboratedUnitId unit == "source-repo-global-id"
        ]

sourceRepositoryInplaceProjectionProblems :: [String]
sourceRepositoryInplaceProjectionProblems =
  case inspectCompilerElaboratedPlanDiagnostic sourceRepositoryInplacePlanBytes of
    Left problems ->
      [ "source-repository inplace style remains distinct: plan was rejected with "
          <> show problems
      ]
    Right plan ->
      concat
        [ expectEqual
            "source-repository inplace style remains distinct"
            [InplaceBuildStyle]
            [ diagnosticElaboratedUnitBuildStyle unit
            | unit <- diagnosticUnits plan
            , diagnosticElaboratedUnitId unit == "source-repo-inplace-id"
            ]
        , expectEqual
            "source-repository inplace style remains distinct"
            [ [ ("source-repo-inplace-id", "lib")
              , ("source-repo-inplace-local-control", "lib:control")
              ]
            ]
            [ subject
            | IndependentComponentUniverseUnavailable subject <- diagnosticProblems plan
            ]
        , expectEqual
            "source-repository inplace style remains distinct"
            [ [ ( "source-repo-inplace-id"
                , InplaceBuildStyle
                , Just DirectElaboratedComponentShape
                , []
                , ["lib"]
                )
              , ( "source-repo-inplace-local-control"
                , LocalBuildStyle
                , Just DirectElaboratedComponentShape
                , [("variant", False)]
                , ["lib:control"]
                )
              ]
            ]
            [ subject
            | ConfigurationBranchClosureUnavailable subject <- diagnosticProblems plan
            ]
        , expectEqual
            "source-repository inplace style remains distinct"
            [ [ ("dependent-pre-existing-id", "<unit>.depends", "base-id")
              , ("source-repo-inplace-id", "lib.depends", "base-id")
              , ("source-repo-inplace-id", "lib.exe-depends", "base-id")
              , ("source-repo-inplace-local-control", "lib:control.depends", "base-id")
              ]
            ]
            [ subject
            | IndependentDependencySemanticsUnavailable subject <- diagnosticProblems plan
            ]
        ]

sourceRepositoryGlobalPlanBytes :: ByteString
sourceRepositoryGlobalPlanBytes =
  renderPlan
    identityFields
    [ preExistingUnit
    , localUnit "source-repo-local-control" "/immutable/repository/source-repo-control" "lib:control" ["base-id"] ""
    , projectionSourceRepositoryUnit "source-repo-global-id" "global" ""
    ]

sourceRepositoryInplacePlanBytes :: ByteString
sourceRepositoryInplacePlanBytes =
  renderPlan
    identityFields
    [ preExistingUnit
    , dependentPreExistingUnit
    , localUnit "source-repo-inplace-local-control" "/immutable/repository/source-repo-inplace-control" "lib:control" ["base-id"] ""
    , projectionSourceRepositoryInplaceUnit
    ]

dependentPreExistingUnit :: ByteString
dependentPreExistingUnit =
  "{\"type\":\"pre-existing\",\"id\":\"dependent-pre-existing-id\",\"pkg-name\":\"dependent-pre-existing\",\"pkg-version\":\"1.0.0\",\"depends\":[\"base-id\"]}"

projectionSourceRepositoryInplaceUnit :: ByteString
projectionSourceRepositoryInplaceUnit =
  "{\"type\":\"configured\",\"id\":\"source-repo-inplace-id\",\"pkg-name\":\"source-repo-package\",\"pkg-version\":\"1.0.0\",\"flags\":{},\"style\":\"inplace\",\"pkg-src\":{\"type\":\"source-repo\",\"source-repo\":{\"type\":\"git\",\"location\":\"https://example.invalid/source.git\",\"tag\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"}},\"component-name\":\"lib\",\"depends\":[\"base-id\"],\"exe-depends\":[\"base-id\"],\"pkg-src-sha256\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\",\"build-info\":\"/immutable/build/source-repo-inplace-id/build-info.json\",\"dist-dir\":\"/immutable/build/source-repo-inplace-id\"}"

projectionSourceRepositoryUnit :: ByteString -> ByteString -> ByteString -> ByteString
projectionSourceRepositoryUnit unitId style pathFields =
  "{\"type\":\"configured\",\"id\":\""
    <> unitId
    <> "\",\"pkg-name\":\"source-repo-package\",\"pkg-version\":\"1.0.0\",\"flags\":{},\"style\":\""
    <> style
    <> "\",\"pkg-src\":{\"type\":\"source-repo\",\"source-repo\":{\"type\":\"git\",\"location\":\"https://example.invalid/source.git\",\"tag\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"}},\"component-name\":\"lib\",\"depends\":[\"base-id\"],\"exe-depends\":[],\"pkg-src-sha256\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\""
    <> pathFields
    <> "}"

testComponentWithoutBinaryPlanBytes :: ByteString
testComponentWithoutBinaryPlanBytes =
  renderPlan identityFields [preExistingUnit, binaryComponentWithoutBinary "test:spec"]

benchmarkComponentWithoutBinaryPlanBytes :: ByteString
benchmarkComponentWithoutBinaryPlanBytes =
  renderPlan identityFields [preExistingUnit, binaryComponentWithoutBinary "bench:perf"]

binaryComponentWithoutBinary :: ByteString -> ByteString
binaryComponentWithoutBinary component =
  "{\"type\":\"configured\",\"id\":\"binary-id\",\"pkg-name\":\"local-package\",\"pkg-version\":\"0.1.0.0\",\"flags\":{},\"style\":\"local\",\"pkg-src\":{\"type\":\"local\",\"path\":\"/immutable/repository/.\"},\"component-name\":\""
    <> component
    <> "\",\"depends\":[\"base-id\"],\"exe-depends\":[],\"build-info\":\"/immutable/build/binary-id/build-info.json\",\"dist-dir\":\"/immutable/build/binary-id\"}"

twoFlagPlanBytes :: ByteString
twoFlagPlanBytes =
  renderPlan identityFields [preExistingUnit, twoFlagLocalUnit]

twoFlagLocalUnit :: ByteString
twoFlagLocalUnit =
  "{\"type\":\"configured\",\"id\":\"local-id\",\"pkg-name\":\"local-package\",\"pkg-version\":\"0.1.0.0\",\"flags\":{\"zeta\":false,\"alpha\":true},\"style\":\"local\",\"pkg-src\":{\"type\":\"local\",\"path\":\"/immutable/repository/.\"},\"component-name\":\"lib\",\"depends\":[\"base-id\"],\"exe-depends\":[],\"build-info\":\"/immutable/build/local-id/build-info.json\",\"dist-dir\":\"/immutable/build/local-id\"}"

multipleUnknownFieldsPlanBytes :: ByteString
multipleUnknownFieldsPlanBytes =
  renderPlan
    (identityFields <> ["\"zeta-unknown\":null", "\"alpha-unknown\":null"])
    [preExistingUnit]

identityFields :: [ByteString]
identityFields =
  [ "\"cabal-version\":\"3.16.1.0\""
  , "\"cabal-lib-version\":\"3.16.1.0\""
  , "\"compiler-id\":\"ghc-9.12.4\""
  , "\"compiler-abi\":\"6f4d\""
  , "\"os\":\"osx\""
  , "\"arch\":\"aarch64\""
  ]

preExistingUnit :: ByteString
preExistingUnit =
  "{\"type\":\"pre-existing\",\"id\":\"base-id\",\"pkg-name\":\"base\",\"pkg-version\":\"4.21.2.0\",\"depends\":[]}"

validCabalHashBytes :: ByteString
validCabalHashBytes =
  "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

validSourceHashBytes :: ByteString
validSourceHashBytes =
  "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

remoteUnit :: ByteString -> ByteString
remoteUnit unitId =
  ByteString8.concat
    [ "{\"type\":\"configured\",\"id\":\""
    , unitId
    , "\",\"pkg-name\":\"remote-package\",\"pkg-version\":\"1.0.0\",\"flags\":{},\"style\":\"global\",\"pkg-src\":{\"type\":\"repo-tar\",\"repo\":{\"type\":\"secure-repo\",\"uri\":\"https://example.invalid/index\"}},\"component-name\":\"lib\",\"depends\":[\"base-id\"],\"exe-depends\":[],\"pkg-cabal-sha256\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"pkg-src-sha256\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"}"
    ]

repositoryTarUnit
  :: ByteString
  -> ByteString
  -> Maybe ByteString
  -> Maybe ByteString
  -> ByteString
  -> ByteString
repositoryTarUnit unitId repositoryType cabalHash sourceHash extraField =
  ByteString8.concat
    [ "{\"type\":\"configured\",\"id\":\""
    , unitId
    , "\",\"pkg-name\":\"remote-package\",\"pkg-version\":\"1.0.0\",\"flags\":{},\"style\":\"global\",\"pkg-src\":{\"type\":\"repo-tar\",\"repo\":{\"type\":\""
    , repositoryType
    , "\",\"uri\":\"https://example.invalid/index\"}},\"component-name\":\"lib\",\"depends\":[\"base-id\"],\"exe-depends\":[]"
    , maybe "" (jsonNamedText "pkg-cabal-sha256") cabalHash
    , maybe "" (jsonNamedText "pkg-src-sha256") sourceHash
    , if ByteString8.null extraField then "" else "," <> extraField
    , "}"
    ]

sourceRepositoryUnit
  :: ByteString
  -> ByteString
  -> ByteString
  -> Maybe ByteString
  -> Maybe ByteString
  -> ByteString
sourceRepositoryUnit unitId repositoryType tag cabalHash sourceHash =
  ByteString8.concat
    [ "{\"type\":\"configured\",\"id\":\""
    , unitId
    , "\",\"pkg-name\":\"source-repo-package\",\"pkg-version\":\"1.0.0\",\"flags\":{},\"style\":\"global\",\"pkg-src\":{\"type\":\"source-repo\",\"source-repo\":{\"type\":\""
    , repositoryType
    , "\",\"location\":\"https://example.invalid/repository.git\",\"tag\":\""
    , tag
    , "\"}},\"component-name\":\"lib\",\"depends\":[\"base-id\"],\"exe-depends\":[]"
    , maybe "" (jsonNamedText "pkg-cabal-sha256") cabalHash
    , maybe "" (jsonNamedText "pkg-src-sha256") sourceHash
    , "}"
    ]

aggregateLocalUnit :: [ByteString] -> [ByteString] -> ByteString -> ByteString
aggregateLocalUnit libraryDependencies setupDependencies extraField =
  ByteString8.concat
    [ "{\"type\":\"configured\",\"id\":\"aggregate-id\",\"pkg-name\":\"local-package\",\"pkg-version\":\"0.1.0.0\",\"flags\":{},\"style\":\"local\",\"pkg-src\":{\"type\":\"local\",\"path\":\"/immutable/repository/.\"},\"components\":{\"lib\":{\"depends\":["
    , ByteString8.intercalate "," (map jsonString libraryDependencies)
    , "],\"exe-depends\":[]},\"setup\":{\"depends\":["
    , ByteString8.intercalate "," (map jsonString setupDependencies)
    , "],\"exe-depends\":[]}},\"build-info\":\"/immutable/build/aggregate-id/build-info.json\",\"dist-dir\":\"/immutable/build/aggregate-id\""
    , if ByteString8.null extraField then "" else "," <> extraField
    , "}"
    ]

inplaceRemoteUnit :: ByteString -> Bool -> ByteString
inplaceRemoteUnit unitId includeBuildInfo =
  ByteString8.concat
    [ "{\"type\":\"configured\",\"id\":\""
    , unitId
    , "\",\"pkg-name\":\"inplace-package\",\"pkg-version\":\"1.0.0\",\"flags\":{},\"style\":\"inplace\",\"pkg-src\":{\"type\":\"repo-tar\",\"repo\":{\"type\":\"secure-repo\",\"uri\":\"https://example.invalid/index\"}},\"component-name\":\"lib\",\"depends\":[\"base-id\"],\"exe-depends\":[],\"pkg-cabal-sha256\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"pkg-src-sha256\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\""
    , if includeBuildInfo
        then ",\"build-info\":\"/immutable/build/" <> unitId <> "/build-info.json\""
        else ""
    , ",\"dist-dir\":\"/immutable/build/" <> unitId <> "\""
    , "}"
    ]

localUnit
  :: ByteString
  -> ByteString
  -> ByteString
  -> [ByteString]
  -> ByteString
  -> ByteString
localUnit unitId sourceRoot component dependencies extraField =
  ByteString8.concat
    [ "{\"type\":\"configured\",\"id\":\""
    , unitId
    , "\",\"pkg-name\":\"local-package\",\"pkg-version\":\"0.1.0.0\",\"flags\":{\"variant\":false},\"style\":\"local\",\"pkg-src\":{\"type\":\"local\",\"path\":\""
    , sourceRoot
    , "\"},\"component-name\":\""
    , component
    , "\",\"depends\":["
    , ByteString8.intercalate "," (map jsonString dependencies)
    , "],\"exe-depends\":[],\"build-info\":\"/immutable/build/"
    , unitId
    , "/build-info.json\",\"dist-dir\":\"/immutable/build/"
    , unitId
    , "\""
    , if any (`ByteString8.isPrefixOf` component) ["exe:", "test:", "bench:"]
        then ",\"bin-file\":\"/immutable/build/" <> unitId <> "/" <> componentBinaryName component <> "\""
        else ""
    , if ByteString8.null extraField then "" else "," <> extraField
    , "}"
    ]

localUnitWithExecutableDependencies :: ByteString -> [ByteString] -> ByteString
localUnitWithExecutableDependencies unitId executableDependencies =
  ByteString8.concat
    [ "{\"type\":\"configured\",\"id\":\""
    , unitId
    , "\",\"pkg-name\":\"local-package\",\"pkg-version\":\"0.1.0.0\",\"flags\":{},\"style\":\"local\",\"pkg-src\":{\"type\":\"local\",\"path\":\"/immutable/repository/.\"},\"component-name\":\"exe:tool\",\"depends\":[\"base-id\"],\"exe-depends\":["
    , ByteString8.intercalate "," (map jsonString executableDependencies)
    , "],\"build-info\":\"/immutable/build/"
    , unitId
    , "/build-info.json\",\"dist-dir\":\"/immutable/build/"
    , unitId
    , "\",\"bin-file\":\"/immutable/build/"
    , unitId
    , "/tool\"}"
    ]

alteredPackageTypeUnit :: ByteString
alteredPackageTypeUnit =
  "{\"type\":\"configured\",\"id\":\"local-id\",\"pkg-name\":\"local-package\",\"pkg-version\":\"0.1.0.0\",\"flags\":{},\"style\":\"local\",\"pkg-src\":{\"type\":\"repo-tar\",\"repo\":{\"type\":\"secure-repo\",\"uri\":\"https://example.invalid/index\"}},\"component-name\":\"lib:core\",\"depends\":[\"base-id\"],\"exe-depends\":[],\"pkg-cabal-sha256\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"pkg-src-sha256\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\",\"build-info\":\"/immutable/build/local-id/build-info.json\",\"dist-dir\":\"/immutable/build/local-id\"}"

componentBinaryName :: ByteString -> ByteString
componentBinaryName component =
  case ByteString8.break (== ':') component of
    (_, suffix)
      | ByteString8.null suffix -> "component"
      | otherwise -> ByteString8.drop 1 suffix

renderPlan :: [ByteString] -> [ByteString] -> ByteString
renderPlan fields units =
  ByteString8.concat
    [ "{"
    , ByteString8.intercalate "," (fields <> ["\"install-plan\":[" <> ByteString8.intercalate "," units <> "]"])
    , "}"
    ]

jsonString :: ByteString -> ByteString
jsonString value = "\"" <> value <> "\""

jsonNamedText :: ByteString -> ByteString -> ByteString
jsonNamedText name value = ",\"" <> name <> "\":\"" <> value <> "\""

diagnosticUnits :: ObservedCompilerElaboratedPlan -> [UnitSnapshotView]
diagnosticUnits
  (ObservedCompilerElaboratedPlan _ _ _ _ _ _ _ _ _ units) = units

diagnosticProblems
  :: ObservedCompilerElaboratedPlan
  -> [CompilerElaboratedPlanProblem]
diagnosticProblems
  (ObservedCompilerElaboratedPlan _ _ problems _ _ _ _ _ _ _) = problems

localUnits :: ObservedCompilerElaboratedPlan -> [UnitSnapshotView]
localUnits plan =
  [unit | unit <- diagnosticUnits plan, diagnosticElaboratedUnitOrigin unit == LocalUnit]

componentProjection
  :: [UnitSnapshotView]
  -> [(Text, Text, [Text], [Text])]
componentProjection units =
  [ ( diagnosticElaboratedComponentUnitId component
    , diagnosticElaboratedComponentName component
    , diagnosticElaboratedComponentDependencyUnitIds component
    , diagnosticElaboratedComponentExecutableDependencyUnitIds component
    )
  | unit <- units
  , component <- diagnosticElaboratedUnitComponents unit
  ]

expectExactLeftProblems
  :: String
  -> [CompilerElaboratedPlanProblem]
  -> ByteString
  -> [String]
expectExactLeftProblems label expected bytes =
  expectEqual label (expectedMalformedCheckResult bytes expected) (checkCompilerElaboratedPlanDiagnostic bytes)

expectedMalformedCheckResult
  :: ByteString
  -> [CompilerElaboratedPlanProblem]
  -> CheckResult
expectedMalformedCheckResult bytes problems =
  CheckResult
    { checkName = "compiler-elaborated-plan-diagnostic-refusal"
    , checkObservations =
        [ observation "compiler-elaborated-plan.input-sha256" digest
        , observation
            "compiler-elaborated-plan.input-bytes"
            (Text.pack (show (ByteString.length bytes)))
        , observation "compiler-elaborated-plan.status" "malformed-refusal"
        ]
    , checkFindings =
        [ finding
            "COMPILER-ELABORATED-PLAN-DIAGNOSTIC-REFUSAL"
            "compiler-elaborated-plan.json"
            (Text.pack (show problem))
        | problem <- problems
        ]
    }
 where
  digest
    | ByteString.length bytes > 8388608 = "unavailable-over-input-limit"
    | otherwise = Text.pack (show (hash bytes :: Digest SHA256))

expectExactRepeatedLeftProblem
  :: String
  -> Int
  -> CompilerElaboratedPlanProblem
  -> ByteString
  -> [String]
expectExactRepeatedLeftProblem label expectedCount expectedProblem bytes =
  expectExactLeftProblems label (replicate expectedCount expectedProblem) bytes

expectSemanticProblemBoundary :: String -> Int -> ByteString -> [String]
expectSemanticProblemBoundary label expectedCount bytes =
  expectExactLeftProblems
    label
    [ PlanJsonFieldTypeMismatch
        ("plan[\"install-plan\"][" <> Text.pack (show index) <> "]")
        "<entry>"
        "object"
    | index <- [0 .. expectedCount - 1]
    ]
    bytes

expectEqual :: (Eq value, Show value) => String -> value -> value -> [String]
expectEqual label expected actual
  | expected == actual = []
  | otherwise = [label <> ": expected " <> show expected <> ", observed " <> show actual]

finishDiagnostics :: String -> [String] -> IO ()
finishDiagnostics name problems = do
  unless (null problems) (fail (unlines (name : problems)))
  putStrLn
    ( name
        <> ": diagnostic refusal expectations matched; independent duplicate observation, component/dependency semantics, configuration/CPP branch closure, lexical/filesystem source-root identity, component source-path ownership, exact source bytes, candidate qualification, and phase-gate completion remain absent."
    )
