{-# LANGUAGE CPP #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Refusal-only, primitive-input diagnostic for the source-consumer seam.
-- Package code which owns acquired source and compiler evidence uses the
-- package-hidden @SourceConsumerGraph.Internal@ module instead.  Nothing from
-- that typed graph, its constructors, or its projections crosses this facade.
module Amoebius.Validation.SourceConsumerGraph
  ( sourceConsumerGraphDiagnostic
  ) where

import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding
  , Observation
  , finding
  , observation
  )
import Data.Char qualified as Char
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text

-- | Raw diagnostic input only.
--
-- Inventory fields are @(POSIX path, class tag, Git mode, Git object id)@.
-- Effect fields are @(module path, module name, binding name, target tag,
-- target value, use tag)@.  The only target tags are @exact@, @dynamic@, and
-- @unresolved@.  Supplying effects is negative evidence only; neither an empty
-- list nor an apparently safe list can remove source-binding or compiler
-- residue.
sourceConsumerGraphDiagnostic
  :: Text
  -> [(FilePath, Text, Text, Text)]
  -> [(FilePath, Text, Text, Text, Text, Text)]
  -> CheckResult
sourceConsumerGraphDiagnostic snapshotIdentity rawInventory rawEffects =
  case boundedProblems cardinalityProblems of
    Left problemLimitFinding ->
      diagnosticResult
        (preflightObservations snapshotIdentity rawInventory rawEffects)
        [problemLimitFinding]
    Right cardinality
      | routeCardinalityProblems cardinality ->
          diagnosticResult
            (preflightObservations snapshotIdentity rawInventory rawEffects)
            cardinality
      | otherwise ->
          case boundedProblems fieldProblemsFound of
            Left problemLimitFinding ->
              diagnosticResult
                (preflightObservations snapshotIdentity rawInventory rawEffects)
                [problemLimitFinding]
            Right fieldProblemsRetained
              | routeFieldProblems fieldProblemsRetained ->
                  diagnosticResult
                    (preflightObservations snapshotIdentity rawInventory rawEffects)
                    fieldProblemsRetained
              | otherwise ->
                  let entries = map rawEntry rawInventory
                      effects = map rawEffect rawEffects
                      structuralProblems =
                        orderedStructuralProblems
                          ( duplicateProblems entries
                              <> orderProblems entries
                              <> bindingCountProblems entries
                              <> haskellCountProblems entries
                              <> emptyInventoryProblems entries
                              <> emptyHaskellTagProblems entries
                          )
                   in case boundedProblems structuralProblems of
                        Left problemLimitFinding ->
                          diagnosticResult
                            (preflightObservations snapshotIdentity rawInventory rawEffects)
                            [problemLimitFinding]
                        Right structuralProblemsRetained
                          | routeStructuralProblems structuralProblemsRetained ->
                              diagnosticResult
                                (preflightObservations snapshotIdentity rawInventory rawEffects)
                                structuralProblemsRetained
                          | otherwise ->
                              let (bindings, subjects, semanticProblems) = classifyEntries entries
                                  graphProblems = orderedGraphProblems (semanticProblems <> auditEffects bindings effects)
                               in case boundedProblems graphProblems of
                                    Left problemLimitFinding ->
                                      diagnosticResult
                                        (preflightObservations snapshotIdentity rawInventory rawEffects)
                                        [problemLimitFinding]
                                    Right retainedProblems ->
                                      let observations =
                                            completeObservations
                                              snapshotIdentity
                                              entries
                                              effects
                                              bindings
                                              subjects
                                       in if observationLimitExceeded observations
                                            then
                                              diagnosticResult
                                                (preflightObservations snapshotIdentity rawInventory rawEffects)
                                                [resourceFinding "result-observations" maximumObservations (maximumObservations + 1)]
                                            else diagnosticResult observations retainedProblems
 where
  cardinalityProblems =
    orderedCardinalityProblems
      (inventoryResourceProblems rawInventory <> effectResourceProblems rawEffects)
  fieldProblemsFound =
    orderedFieldProblems
      ( snapshotIdentityProblems snapshotIdentity
          <> concatMap rawEntryPreflight rawInventory
          <> concatMap rawEffectPreflight rawEffects
      )

orderedCardinalityProblems, orderedFieldProblems, orderedStructuralProblems, orderedGraphProblems :: [Finding] -> [Finding]
#if defined(VALIDATION_SOURCE_CONSUMER_CARDINALITY_PROBLEM_ORDER_MUTANT)
orderedCardinalityProblems = reverse
#else
orderedCardinalityProblems = id
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_FIELD_PROBLEM_ORDER_MUTANT)
orderedFieldProblems = reverse
#else
orderedFieldProblems = id
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_STRUCTURAL_PROBLEM_ORDER_MUTANT)
orderedStructuralProblems = reverse
#else
orderedStructuralProblems = id
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_GRAPH_PROBLEM_ORDER_MUTANT)
orderedGraphProblems = reverse
#else
orderedGraphProblems = id
#endif

routeCardinalityProblems, routeFieldProblems, routeStructuralProblems :: [Finding] -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_CARDINALITY_PROBLEM_ROUTE_BYPASS_MUTANT)
routeCardinalityProblems _ = False
#else
routeCardinalityProblems = not . null
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_FIELD_PROBLEM_ROUTE_BYPASS_MUTANT)
routeFieldProblems _ = False
#else
routeFieldProblems = not . null
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_STRUCTURAL_PROBLEM_ROUTE_BYPASS_MUTANT)
routeStructuralProblems _ = False
#else
routeStructuralProblems = not . null
#endif

observationLimitExceeded :: [Observation] -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_OBSERVATION_LIMIT_ROUTE_BYPASS_MUTANT)
observationLimitExceeded _ = False
#else
observationLimitExceeded observations =
  boundedLength (maximumObservations + 1) observations > maximumObservations
#endif

diagnosticResult :: [Observation] -> [Finding] -> CheckResult
diagnosticResult observations problems =
  let permanent = retainedPermanentFindings permanentFindings
      variable = retainedVariableFindings problems
      findings = orderedResultFindings permanent variable
      retainedFindings
        | boundedLength (maximumFindings + 1) findings > maximumFindings =
            permanent
              <> [resourceFinding "result-findings" maximumFindings (maximumFindings + 1)]
        | otherwise = findings
   in CheckResult
        { checkName = resultCheckName
        , checkObservations = retainedResultObservations observations
        , checkFindings = retainedFindings
        }

resultCheckName :: Text
#if defined(VALIDATION_SOURCE_CONSUMER_RESULT_NAME_MAPPING_MUTANT)
resultCheckName = "source-consumer-graph-diagnostic<"
#else
resultCheckName = "source-consumer-graph-diagnostic"
#endif

retainedResultObservations :: [Observation] -> [Observation]
#if defined(VALIDATION_SOURCE_CONSUMER_RESULT_OBSERVATION_CARRIER_DROP_MUTANT)
retainedResultObservations _ = []
#elif defined(VALIDATION_SOURCE_CONSUMER_RESULT_OBSERVATION_ORDER_MUTANT)
retainedResultObservations = reverse
#else
retainedResultObservations = id
#endif

retainedPermanentFindings :: [Finding] -> [Finding]
#if defined(VALIDATION_SOURCE_CONSUMER_RESULT_PERMANENT_CARRIER_DROP_MUTANT)
retainedPermanentFindings _ = []
#else
retainedPermanentFindings = id
#endif

retainedVariableFindings :: [Finding] -> [Finding]
#if defined(VALIDATION_SOURCE_CONSUMER_RESULT_PROBLEM_CARRIER_DROP_MUTANT)
retainedVariableFindings _ = []
#else
retainedVariableFindings = id
#endif

orderedResultFindings :: [Finding] -> [Finding] -> [Finding]
#if defined(VALIDATION_SOURCE_CONSUMER_RESULT_FINDING_ORDER_MUTANT)
orderedResultFindings permanent variable = variable <> permanent
#else
orderedResultFindings permanent variable = permanent <> variable
#endif

data RawEntry = RawEntry
  { rawEntryPath :: FilePath
  , rawEntryClassTag :: Text
  , rawEntryMode :: Text
  , rawEntryObjectId :: Text
  }
  deriving (Eq, Ord, Show)

rawEntry :: (FilePath, Text, Text, Text) -> RawEntry
rawEntry (path, classTag, mode, objectId) =
  RawEntry
    (mutateRawEntryPath path)
    (mutateRawEntryClassTag classTag)
    (mutateRawEntryMode mode)
    (mutateRawEntryObjectId objectId)

mutateRawEntryPath :: FilePath -> FilePath
#if defined(VALIDATION_SOURCE_CONSUMER_RAW_ENTRY_PATH_MAPPING_MUTANT)
mutateRawEntryPath value = value <> "<"
#else
mutateRawEntryPath value = value
#endif

mutateRawEntryClassTag :: Text -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_RAW_ENTRY_CLASS_MAPPING_MUTANT)
mutateRawEntryClassTag _ = "other"
#else
mutateRawEntryClassTag value = value
#endif

mutateRawEntryMode :: Text -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_RAW_ENTRY_MODE_MAPPING_MUTANT)
mutateRawEntryMode value = value <> "<"
#else
mutateRawEntryMode value = value
#endif

mutateRawEntryObjectId :: Text -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_RAW_ENTRY_OBJECT_MAPPING_MUTANT)
mutateRawEntryObjectId value = value <> "0"
#else
mutateRawEntryObjectId value = value
#endif

data RawEffect = RawEffect
  { rawEffectModulePath :: FilePath
  , rawEffectModuleName :: Text
  , rawEffectBindingName :: Text
  , rawEffectTargetTag :: Text
  , rawEffectTargetValue :: Text
  , rawEffectUseTag :: Text
  }
  deriving (Eq, Ord, Show)

rawEffect :: (FilePath, Text, Text, Text, Text, Text) -> RawEffect
rawEffect (modulePath, moduleName, bindingName, targetTag, targetValue, useTag) =
  RawEffect
    (mutateRawEffectModulePath modulePath)
    (mutateRawEffectModuleName moduleName)
    (mutateRawEffectBindingName bindingName)
    (mutateRawEffectTargetTag targetTag)
    (mutateRawEffectTargetValue targetValue)
    (mutateRawEffectUseTag useTag)

mutateRawEffectModulePath :: FilePath -> FilePath
#if defined(VALIDATION_SOURCE_CONSUMER_RAW_EFFECT_MODULE_PATH_MAPPING_MUTANT)
mutateRawEffectModulePath value = value <> "<"
#else
mutateRawEffectModulePath value = value
#endif

mutateRawEffectModuleName, mutateRawEffectBindingName, mutateRawEffectTargetValue :: Text -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_RAW_EFFECT_MODULE_NAME_MAPPING_MUTANT)
mutateRawEffectModuleName value = value <> "<"
#else
mutateRawEffectModuleName value = value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_RAW_EFFECT_BINDING_NAME_MAPPING_MUTANT)
mutateRawEffectBindingName value = value <> "<"
#else
mutateRawEffectBindingName value = value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_RAW_EFFECT_TARGET_VALUE_MAPPING_MUTANT)
mutateRawEffectTargetValue value = value <> "<"
#else
mutateRawEffectTargetValue value = value
#endif

mutateRawEffectTargetTag :: Text -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_RAW_EFFECT_TARGET_TAG_MAPPING_MUTANT)
mutateRawEffectTargetTag _ = "dynamic"
#else
mutateRawEffectTargetTag value = value
#endif

mutateRawEffectUseTag :: Text -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_RAW_EFFECT_USE_TAG_MAPPING_MUTANT)
mutateRawEffectUseTag _ = "product-behaviour"
#else
mutateRawEffectUseTag value = value
#endif

data EntryClass
  = HaskellEntry
  | DocumentationEntry
  | ProjectDeclarationEntry
  | OtherTrackedEntry
  deriving (Eq, Ord, Show)

data ContentRole
  = GovernanceDocumentation
  | CabalPackageDescription
  | CabalProjectDescription
  | GitIgnoreContract
  | DockerIgnoreContract
  | GitAttributesContract
  | EditorConfiguration
  deriving (Eq, Ord, Show)

data AuthorizedConsumer
  = HumanReader
  | HaskellSourceBoundaryStructureChecker
  | HaskellDocumentationStructureChecker
  | HaskellRepositoryRootLocator
  | CabalBuildTool
  | GitClient
  | ContainerContextBuilder
  | EditorTool
  | HaskellProductRuntime
  deriving (Eq, Ord, Show)

data AuthorizedConsumerLocus
  = GovernanceHumanConsumer
  | GovernanceSourceConsumer
  | GovernanceDocumentationConsumer
  | AmoebiusCabalSourceConsumer
  | AmoebiusCabalRootConsumer
  | AmoebiusCabalBuildConsumer
  | ProbeCabalSourceConsumer
  | ProbeCabalBuildConsumer
  | CabalProjectSourceConsumer
  | CabalProjectRootConsumer
  | CabalProjectBuildConsumer
  | GitIgnoreSourceConsumer
  | GitIgnoreClientConsumer
  | DockerIgnoreSourceConsumer
  | DockerIgnoreBuilderConsumer
  | GitAttributesSourceConsumer
  | GitAttributesClientConsumer
  | EditorConfigSourceConsumer
  | EditorConfigToolConsumer
  deriving (Eq, Ord, Show)

data ContentBinding = ContentBinding
  { bindingPath :: FilePath
  , bindingRole :: ContentRole
  , bindingConsumers :: [AuthorizedConsumer]
  }
  deriving (Eq, Ord, Show)

data HaskellSubject = HaskellSubject
  { subjectPath :: FilePath
  , subjectMode :: Text
  , subjectObjectId :: Text
  }
  deriving (Eq, Ord, Show)

data EffectTarget
  = ExactTarget FilePath
  | DynamicTarget Text
  | UnresolvedTarget Text
  deriving (Eq, Ord, Show)

data ContentUse
  = SourceBoundaryStructureInspection
  | StructuralDocumentationInspection
  | RepositoryRootSentinel
  | ProductBehaviourInput
  deriving (Eq, Ord, Show)

data ParsedEffect = ParsedEffect
  { parsedEffectModulePath :: FilePath
  , parsedEffectModuleName :: Text
  , parsedEffectBindingName :: Text
  , parsedEffectTarget :: EffectTarget
  , parsedEffectUse :: ContentUse
  }
  deriving (Eq, Ord, Show)

data RequiredCompilerFact
  = CompilerParseSucceeded
  | ConditionalPreprocessingClosed
  | CompileTimeExecutionFeaturesAbsent
  | ImportsRenamed
  | CallsResolved
  | IndirectCallsClosed
  | ControlFlowClosed
  | FilesystemEffectsClassified
  | ExternalProcessAndFfiEffectsClassified
  | TrackedContentProvenanceFlowsClosed
  | ProductBehaviourSinksClassified
  | DynamicCodeAndPluginLoadingAbsent
  deriving (Eq, Ord, Show)

-- The refusal facade keeps the semantic problem family separate from its
-- rendered fields so every reachable code, subject, and detail projection can
-- be changed and qualified independently.
data DiagnosticProblemKind
  = SnapshotIdentityProblem
  | EffectModuleNameProblem
  | EffectBindingNameProblem
  | PosixPathProblem
  | ExactTargetPathProblem
  | ClassTagProblem
  | ModeTagProblem
  | ObjectIdProblem
  | TargetTagProblem
  | TargetValueProblem
  | UseTagProblem
  | HaskellModeProblem
  | ContentModeProblem
  | LegalNameProblem
  | RoleUnboundProblem
  | DuplicateProblem
  | InventoryOrderProblem
  | EmptyInventoryProblem
  | EmptyHaskellProblem
  | DynamicTargetProblem
  | UnresolvedEffectProblem
  | EffectTargetProblem
  | DirectBehaviourProblem
  | UnauthorizedEffectProblem
  | DiagnosticOnlyProblem
  | SourceBindingProblem
  | CompilerResidueProblem
  | ResourceProblem
  deriving (Eq, Ord, Show)

-- Observation families are independently tagged so every emitted key, value,
-- and carrier can be qualified without relying on a production-derived list.
data DiagnosticObservationKind
  = LimitInventoryObservation
  | LimitEffectsObservation
  | LimitPathBytesObservation
  | LimitPathDepthObservation
  | LimitSegmentBytesObservation
  | LimitFieldBytesObservation
  | LimitBindingsObservation
  | LimitHaskellObservation
  | LimitProblemsObservation
  | LimitFindingsObservation
  | LimitResultObservationsObservation
  | PreflightSnapshotObservation
  | PreflightInventoryObservation
  | PreflightEffectsObservation
  | CompleteSnapshotObservation
  | CompleteInventoryObservation
  | CompleteEffectsObservation
  | CompleteBindingsObservation
  | CompleteHaskellObservation
  | EntryObservation
  | EffectObservation
  | BindingObservation
  | SubjectObservation
  | CompilerFactObservation
  deriving (Eq, Ord, Show)

maximumInventoryEntries, maximumEffects, maximumBindings :: Int
#if defined(VALIDATION_SOURCE_CONSUMER_INVENTORY_LIMIT_WIDEN_MUTANT)
maximumInventoryEntries = 65
#else
maximumInventoryEntries = 64
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EFFECT_LIMIT_WIDEN_MUTANT)
maximumEffects = 65
#else
maximumEffects = 64
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_BINDING_LIMIT_WIDEN_MUTANT)
maximumBindings = 33
#else
maximumBindings = 32
#endif

maximumHaskellSubjects, maximumProblems, maximumFindings, maximumObservations :: Int
#if defined(VALIDATION_SOURCE_CONSUMER_HASKELL_LIMIT_WIDEN_MUTANT)
maximumHaskellSubjects = 33
#else
maximumHaskellSubjects = 32
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_PROBLEM_LIMIT_WIDEN_MUTANT)
maximumProblems = 33
#else
maximumProblems = 32
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_FINDING_LIMIT_NARROW_MUTANT)
maximumFindings = 45
#else
maximumFindings = 46
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_OBSERVATION_LIMIT_WIDEN_MUTANT)
maximumObservations = 219
#else
maximumObservations = 218
#endif

maximumPathBytes, maximumPathDepth, maximumSegmentBytes :: Int
#if defined(VALIDATION_SOURCE_CONSUMER_PATH_LIMIT_WIDEN_MUTANT)
maximumPathBytes = 1025
#else
maximumPathBytes = 1024
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_PATH_DEPTH_LIMIT_WIDEN_MUTANT)
maximumPathDepth = 65
#else
maximumPathDepth = 64
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_SEGMENT_LIMIT_WIDEN_MUTANT)
maximumSegmentBytes = 256
#else
maximumSegmentBytes = 255
#endif

maximumFieldBytes :: Int
#if defined(VALIDATION_SOURCE_CONSUMER_FIELD_LIMIT_WIDEN_MUTANT)
maximumFieldBytes = 257
#else
maximumFieldBytes = 256
#endif

snapshotIdentityProblems :: Text -> [Finding]
snapshotIdentityProblems identity = widthProblems <> alphabetProblems
 where
  widthProblems =
#if defined(VALIDATION_SOURCE_CONSUMER_SNAPSHOT_WIDTH_BYPASS_MUTANT)
    []
#else
    [ diagnosticFinding
        SnapshotIdentityProblem
        "SRC-CONSUMER-SNAPSHOT-IDENTITY"
        "snapshot-identity"
        "snapshot identity must be exactly 64 lowercase ASCII hexadecimal characters"
    | boundedTextLength 65 identity /= 64
    ]
#endif

  alphabetProblems =
#if defined(VALIDATION_SOURCE_CONSUMER_SNAPSHOT_ALPHABET_BYPASS_MUTANT)
    [ diagnosticFinding
        SnapshotIdentityProblem
        "SRC-CONSUMER-SNAPSHOT-IDENTITY"
        "snapshot-identity"
        "snapshot identity must be exactly 64 lowercase ASCII hexadecimal characters"
    | boundedTextLength 65 identity == 64
    , not (Text.all snapshotLowerHex identity)
    , False
    ]
#else
    [ diagnosticFinding
        SnapshotIdentityProblem
        "SRC-CONSUMER-SNAPSHOT-IDENTITY"
        "snapshot-identity"
        "snapshot identity must be exactly 64 lowercase ASCII hexadecimal characters"
    | boundedTextLength 65 identity == 64
    , not (Text.all snapshotLowerHex identity)
    ]
#endif

inventoryResourceProblems :: [value] -> [Finding]
inventoryResourceProblems values =
  [ resourceFinding "inventory-entries" maximumInventoryEntries observed
  | let observed = boundedLength (maximumInventoryEntries + 1) values
  , inventoryCardinalityExceeded observed
  ]

inventoryCardinalityExceeded :: Int -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_INVENTORY_CARDINALITY_PREDICATE_BYPASS_MUTANT)
inventoryCardinalityExceeded _ = False
#else
inventoryCardinalityExceeded observed = observed > maximumInventoryEntries
#endif

effectResourceProblems :: [value] -> [Finding]
effectResourceProblems values =
  [ resourceFinding "resolved-effects" maximumEffects observed
  | let observed = boundedLength (maximumEffects + 1) values
  , effectCardinalityExceeded observed
  ]

effectCardinalityExceeded :: Int -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_EFFECT_CARDINALITY_PREDICATE_BYPASS_MUTANT)
effectCardinalityExceeded _ = False
#else
effectCardinalityExceeded observed = observed > maximumEffects
#endif

rawEntryPreflight :: (FilePath, Text, Text, Text) -> [Finding]
rawEntryPreflight (path, classTag, mode, objectId) =
  orderedRawEntryPreflightProblems
    ( if entryPreflightSemanticsAdmitted resourceAndPathProblems
        then
          classTagProblems path classTag
            <> modeTagProblems path mode
            <> objectIdProblems path objectId
        else resourceAndPathProblems
    )
 where
  resourceAndPathProblems =
    inventoryPathProblems path
      <> fieldProblems "class-tag" classTag
      <> fieldProblems "mode-tag" mode
      <> fieldProblems "object-id" objectId

entryPreflightSemanticsAdmitted :: [Finding] -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_ENTRY_PREFLIGHT_ROUTE_BYPASS_MUTANT)
entryPreflightSemanticsAdmitted _ = False
#else
entryPreflightSemanticsAdmitted = null
#endif

rawEffectPreflight :: (FilePath, Text, Text, Text, Text, Text) -> [Finding]
rawEffectPreflight (modulePath, moduleName, bindingName, targetTag, targetValue, useTag) =
  orderedRawEffectPreflightProblems
    ( if effectPreflightSemanticsAdmitted resourceAndPathProblems
        then
          effectIdentityProblems modulePath moduleName bindingName
            <> targetTagProblems modulePath targetTag targetValue
            <> useTagProblems modulePath useTag
        else resourceAndPathProblems
    )
 where
  resourceAndPathProblems =
    effectModulePathProblems modulePath
      <> fieldProblems "effect-module-name" moduleName
      <> fieldProblems "effect-binding-name" bindingName
      <> fieldProblems "effect-target-tag" targetTag
      <> fieldProblems "effect-target-value" targetValue
      <> fieldProblems "effect-use-tag" useTag

effectPreflightSemanticsAdmitted :: [Finding] -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_EFFECT_PREFLIGHT_ROUTE_BYPASS_MUTANT)
effectPreflightSemanticsAdmitted _ = False
#else
effectPreflightSemanticsAdmitted = null
#endif

orderedRawEntryPreflightProblems, orderedRawEffectPreflightProblems :: [Finding] -> [Finding]
#if defined(VALIDATION_SOURCE_CONSUMER_ENTRY_PREFLIGHT_PROBLEM_ORDER_MUTANT)
orderedRawEntryPreflightProblems = reverse
#else
orderedRawEntryPreflightProblems = id
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EFFECT_PREFLIGHT_PROBLEM_ORDER_MUTANT)
orderedRawEffectPreflightProblems = reverse
#else
orderedRawEffectPreflightProblems = id
#endif

inventoryPathProblems :: FilePath -> [Finding]
#if defined(VALIDATION_SOURCE_CONSUMER_INVENTORY_PATH_BYPASS_MUTANT)
inventoryPathProblems _ = []
#else
inventoryPathProblems = pathProblems "inventory-path"
#endif

effectModulePathProblems :: FilePath -> [Finding]
#if defined(VALIDATION_SOURCE_CONSUMER_EFFECT_MODULE_PATH_BYPASS_MUTANT)
effectModulePathProblems _ = []
#else
effectModulePathProblems = pathProblems "effect-module-path"
#endif

effectIdentityProblems :: FilePath -> Text -> Text -> [Finding]
effectIdentityProblems modulePath moduleName bindingName =
  moduleNameProblems <> bindingNameProblems
 where
  moduleNameProblems =
#if defined(VALIDATION_SOURCE_CONSUMER_EFFECT_MODULE_NAME_BYPASS_MUTANT)
    [ diagnosticFinding
        EffectModuleNameProblem
        "SRC-CONSUMER-EFFECT-MODULE"
        modulePath
        "effect module name must be nonempty"
    | Text.null moduleName
    , False
    ]
#else
    [ diagnosticFinding
        EffectModuleNameProblem
        "SRC-CONSUMER-EFFECT-MODULE"
        modulePath
        "effect module name must be nonempty"
    | Text.null moduleName
    ]
#endif
  bindingNameProblems =
#if defined(VALIDATION_SOURCE_CONSUMER_EFFECT_BINDING_NAME_BYPASS_MUTANT)
    [ diagnosticFinding
        EffectBindingNameProblem
        "SRC-CONSUMER-EFFECT-MODULE"
        modulePath
        "effect binding name must be nonempty"
    | Text.null bindingName
    , False
    ]
#else
    [ diagnosticFinding
        EffectBindingNameProblem
        "SRC-CONSUMER-EFFECT-MODULE"
        modulePath
        "effect binding name must be nonempty"
    | Text.null bindingName
    ]
#endif

pathProblems :: Text -> FilePath -> [Finding]
pathProblems field path =
  resourceProblems <> shapeProblems
 where
  observedLength = boundedStringUtf8Bytes (maximumPathBytes + 1) path
  resourceProblems =
    [resourceFinding (field <> "-bytes") maximumPathBytes observedLength | pathByteLimitExceeded observedLength]
  shapeProblems
    | not (pathShapeSemanticsAdmitted resourceProblems) = []
    | otherwise =
        let segments = Text.splitOn "/" (Text.pack path)
            depth = boundedLength (maximumPathDepth + 1) segments
            overSegments =
              [ segment
              | segment <- segments
              , pathSegmentLimitExceeded segment
              ]
         in orderedPathShapeProblems
              ( [resourceFinding (field <> "-depth") maximumPathDepth depth | pathDepthLimitExceeded depth]
                  <> [ resourceFinding
                        (field <> "-segment-bytes")
                        maximumSegmentBytes
                        (boundedTextUtf8Bytes (maximumSegmentBytes + 1) segment)
                     | segment <- take 1 overSegments
                     ]
                  <> [ diagnosticFinding
                        PosixPathProblem
                        "SRC-CONSUMER-POSIX-PATH"
                        (Text.unpack field)
                        "path must be a nonempty safe relative POSIX path"
                     | null overSegments
                     , not (safePosixPath segments path)
                     ]
              )

pathByteLimitExceeded :: Int -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_PATH_BYTE_PREDICATE_BYPASS_MUTANT)
pathByteLimitExceeded _ = False
#else
pathByteLimitExceeded observed = observed > maximumPathBytes
#endif

pathShapeSemanticsAdmitted :: [Finding] -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_PATH_SHAPE_ROUTE_BYPASS_MUTANT)
pathShapeSemanticsAdmitted _ = False
#else
pathShapeSemanticsAdmitted = null
#endif

pathDepthLimitExceeded :: Int -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_PATH_DEPTH_PREDICATE_BYPASS_MUTANT)
pathDepthLimitExceeded _ = False
#else
pathDepthLimitExceeded observed = observed > maximumPathDepth
#endif

pathSegmentLimitExceeded :: Text -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_PATH_SEGMENT_PREDICATE_BYPASS_MUTANT)
pathSegmentLimitExceeded _ = False
#else
pathSegmentLimitExceeded segment =
  boundedTextUtf8Bytes (maximumSegmentBytes + 1) segment > maximumSegmentBytes
#endif

orderedPathShapeProblems :: [Finding] -> [Finding]
#if defined(VALIDATION_SOURCE_CONSUMER_PATH_SHAPE_PROBLEM_ORDER_MUTANT)
orderedPathShapeProblems = reverse
#else
orderedPathShapeProblems = id
#endif

fieldProblems :: Text -> Text -> [Finding]
fieldProblems field value =
  [ resourceFinding (field <> "-bytes") maximumFieldBytes observed
  | let observed = boundedTextUtf8Bytes (maximumFieldBytes + 1) value
  , fieldLimitExceeded observed
  ]

fieldLimitExceeded :: Int -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_FIELD_PREDICATE_BYPASS_MUTANT)
fieldLimitExceeded _ = False
#else
fieldLimitExceeded observed = observed > maximumFieldBytes
#endif

classTagProblems :: FilePath -> Text -> [Finding]
classTagProblems path classTag =
  [ diagnosticFinding
      ClassTagProblem
      "SRC-CONSUMER-CLASS-TAG"
      path
      "class tag must be haskell, documentation, project-declaration, or other"
  | not (classTagAdmitted classTag)
#if defined(VALIDATION_SOURCE_CONSUMER_CLASS_TAG_BYPASS_MUTANT)
  , False
#endif
  ]

classTagAdmitted :: Text -> Bool
classTagAdmitted value =
  haskellClassTag value
    || documentationClassTag value
    || projectClassTag value
    || otherClassTag value

haskellClassTag, documentationClassTag, projectClassTag, otherClassTag :: Text -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_HASKELL_CLASS_ALTERNATIVE_DROP_MUTANT)
haskellClassTag _ = False
#else
haskellClassTag value = value == "haskell"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_DOCUMENTATION_CLASS_ALTERNATIVE_DROP_MUTANT)
documentationClassTag _ = False
#else
documentationClassTag value = value == "documentation"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_PROJECT_CLASS_ALTERNATIVE_DROP_MUTANT)
projectClassTag _ = False
#else
projectClassTag value = value == "project-declaration"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_OTHER_CLASS_ALTERNATIVE_DROP_MUTANT)
otherClassTag _ = False
#else
otherClassTag value = value == "other"
#endif

modeTagProblems :: FilePath -> Text -> [Finding]
modeTagProblems path mode =
  [ diagnosticFinding
      ModeTagProblem
      "SRC-CONSUMER-MODE-TAG"
      path
      "Git mode must be exactly 100644, 100755, or 120000"
  | not (modeTagAdmitted mode)
#if defined(VALIDATION_SOURCE_CONSUMER_MODE_TAG_BYPASS_MUTANT)
  , False
#endif
  ]

modeTagAdmitted :: Text -> Bool
modeTagAdmitted value = regularMode value || executableMode value || symlinkMode value

regularMode, executableMode, symlinkMode :: Text -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_REGULAR_MODE_ALTERNATIVE_DROP_MUTANT)
regularMode _ = False
#else
regularMode value = value == "100644"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EXECUTABLE_MODE_ALTERNATIVE_DROP_MUTANT)
executableMode _ = False
#else
executableMode value = value == "100755"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_SYMLINK_MODE_ALTERNATIVE_DROP_MUTANT)
symlinkMode _ = False
#else
symlinkMode value = value == "120000"
#endif

objectIdProblems :: FilePath -> Text -> [Finding]
objectIdProblems path objectId = widthProblems <> alphabetProblems
 where
  width = boundedTextLength 65 objectId
  widthProblems =
#if defined(VALIDATION_SOURCE_CONSUMER_OBJECT_ID_WIDTH_BYPASS_MUTANT)
    []
#else
    [ diagnosticFinding
        ObjectIdProblem
        "SRC-CONSUMER-OBJECT-ID"
        path
        "Git object id must be exactly 40 or 64 lowercase ASCII hexadecimal characters"
    | not (objectWidthAdmitted width)
    ]
#endif

  alphabetProblems =
#if defined(VALIDATION_SOURCE_CONSUMER_OBJECT_ID_ALPHABET_BYPASS_MUTANT)
    [ diagnosticFinding
        ObjectIdProblem
        "SRC-CONSUMER-OBJECT-ID"
        path
        "Git object id must be exactly 40 or 64 lowercase ASCII hexadecimal characters"
    | objectWidthAdmitted width
    , not (Text.all objectLowerHex objectId)
    , False
    ]
#else
    [ diagnosticFinding
        ObjectIdProblem
        "SRC-CONSUMER-OBJECT-ID"
        path
        "Git object id must be exactly 40 or 64 lowercase ASCII hexadecimal characters"
    | objectWidthAdmitted width
    , not (Text.all objectLowerHex objectId)
    ]
#endif

objectWidthAdmitted :: Int -> Bool
objectWidthAdmitted width = objectSha1Width width || objectSha256Width width

objectSha1Width, objectSha256Width :: Int -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_OBJECT_SHA1_WIDTH_ALTERNATIVE_DROP_MUTANT)
objectSha1Width _ = False
#else
objectSha1Width width = width == 40
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_OBJECT_SHA256_WIDTH_ALTERNATIVE_DROP_MUTANT)
objectSha256Width _ = False
#else
objectSha256Width width = width == 64
#endif

targetTagProblems :: FilePath -> Text -> Text -> [Finding]
targetTagProblems modulePath targetTag targetValue =
  orderedTargetProblems
    ( targetVocabularyProblems
        <> targetValueProblems modulePath targetValue
        <> exactTargetPathProblems
    )
 where
  targetVocabularyProblems =
#if defined(VALIDATION_SOURCE_CONSUMER_TARGET_TAG_BYPASS_MUTANT)
    [ diagnosticFinding
        TargetTagProblem
        "SRC-CONSUMER-TARGET-TAG"
        modulePath
        "effect target tag must be exact, dynamic, or unresolved"
    | not (targetTagAdmitted targetTag)
    , False
    ]
#else
    [ diagnosticFinding
        TargetTagProblem
        "SRC-CONSUMER-TARGET-TAG"
        modulePath
        "effect target tag must be exact, dynamic, or unresolved"
    | not (targetTagAdmitted targetTag)
    ]
#endif

  exactTargetPathProblems =
#if defined(VALIDATION_SOURCE_CONSUMER_EFFECT_TARGET_PATH_BYPASS_MUTANT)
    [ diagnosticFinding
        ExactTargetPathProblem
        "SRC-CONSUMER-POSIX-PATH"
        "effect-target-path"
        "exact effect target must be a safe relative POSIX path"
    | exactTargetPathTagApplies targetTag
    , exactTargetValuePresent targetValue
    , not (safeBoundedPosixPath (Text.unpack targetValue))
    , False
    ]
#else
    [ diagnosticFinding
        ExactTargetPathProblem
        "SRC-CONSUMER-POSIX-PATH"
        "effect-target-path"
        "exact effect target must be a safe relative POSIX path"
    | exactTargetPathTagApplies targetTag
    , exactTargetValuePresent targetValue
    , not (safeBoundedPosixPath (Text.unpack targetValue))
    ]
#endif

exactTargetPathTagApplies :: Text -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_EXACT_TARGET_PATH_TAG_CONJUNCT_BYPASS_MUTANT)
exactTargetPathTagApplies _ = True
#else
exactTargetPathTagApplies value = value == "exact"
#endif

exactTargetValuePresent :: Text -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_EXACT_TARGET_VALUE_PRESENT_CONJUNCT_BYPASS_MUTANT)
exactTargetValuePresent _ = True
#else
exactTargetValuePresent = not . Text.null
#endif

orderedTargetProblems :: [Finding] -> [Finding]
#if defined(VALIDATION_SOURCE_CONSUMER_TARGET_PROBLEM_ORDER_MUTANT)
orderedTargetProblems = reverse
#else
orderedTargetProblems = id
#endif

targetTagAdmitted :: Text -> Bool
targetTagAdmitted value = exactTargetTag value || dynamicTargetTag value || unresolvedTargetTag value

exactTargetTag, dynamicTargetTag, unresolvedTargetTag :: Text -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_EXACT_TARGET_ALTERNATIVE_DROP_MUTANT)
exactTargetTag _ = False
#else
exactTargetTag value = value == "exact"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_DYNAMIC_TARGET_ALTERNATIVE_DROP_MUTANT)
dynamicTargetTag _ = False
#else
dynamicTargetTag value = value == "dynamic"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_UNRESOLVED_TARGET_ALTERNATIVE_DROP_MUTANT)
unresolvedTargetTag _ = False
#else
unresolvedTargetTag value = value == "unresolved"
#endif

targetValueProblems :: FilePath -> Text -> [Finding]
#if defined(VALIDATION_SOURCE_CONSUMER_TARGET_VALUE_BYPASS_MUTANT)
targetValueProblems _ _ = []
#else
targetValueProblems modulePath targetValue =
  [ diagnosticFinding
      TargetValueProblem
      "SRC-CONSUMER-TARGET-VALUE"
      modulePath
      "effect target value must be nonempty"
  | Text.null targetValue
  ]
#endif

useTagProblems :: FilePath -> Text -> [Finding]
useTagProblems modulePath useTag =
  [ diagnosticFinding
      UseTagProblem
      "SRC-CONSUMER-USE-TAG"
      modulePath
      "effect use tag is outside the closed diagnostic vocabulary"
  | not (useTagAdmitted useTag)
#if defined(VALIDATION_SOURCE_CONSUMER_USE_TAG_BYPASS_MUTANT)
  , False
#endif
  ]

useTagAdmitted :: Text -> Bool
useTagAdmitted value =
  sourceUseTag value
    || documentationUseTag value
    || rootUseTag value
    || productUseTag value

sourceUseTag, documentationUseTag, rootUseTag, productUseTag :: Text -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_SOURCE_USE_ALTERNATIVE_DROP_MUTANT)
sourceUseTag _ = False
#else
sourceUseTag value = value == "source-boundary-structure"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_DOCUMENTATION_USE_ALTERNATIVE_DROP_MUTANT)
documentationUseTag _ = False
#else
documentationUseTag value = value == "documentation-structure"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_ROOT_USE_ALTERNATIVE_DROP_MUTANT)
rootUseTag _ = False
#else
rootUseTag value = value == "repository-root-sentinel"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_PRODUCT_USE_ALTERNATIVE_DROP_MUTANT)
productUseTag _ = False
#else
productUseTag value = value == "product-behaviour"
#endif

safeBoundedPosixPath :: FilePath -> Bool
safeBoundedPosixPath path =
  boundedStringUtf8Bytes (maximumPathBytes + 1) path <= maximumPathBytes
    && let segments = Text.splitOn "/" (Text.pack path)
        in boundedLength (maximumPathDepth + 1) segments <= maximumPathDepth
            && all ((<= maximumSegmentBytes) . boundedTextUtf8Bytes (maximumSegmentBytes + 1)) segments
            && safePosixPath segments path

safePosixPath :: [Text] -> FilePath -> Bool
safePosixPath segments path =
  headCharacterIsRelative path
    && all validSegment (segmentsForValidation segments path)
 where
  segmentsForValidation (first : rest) ('/' : _)
    | Text.null first = rest
  segmentsForValidation values _ = values
  headCharacterIsRelative [] = True
  headCharacterIsRelative (_first : _) =
#if defined(VALIDATION_SOURCE_CONSUMER_ABSOLUTE_PATH_BYPASS_MUTANT)
    True
#else
    _first /= '/'
#endif
  validSegment segment =
    nonemptySegment segment
      && currentDirectorySegmentAbsent segment
      && parentDirectorySegmentAbsent segment
      && portableSegment segment
  nonemptySegment _segment =
#if defined(VALIDATION_SOURCE_CONSUMER_EMPTY_PATH_SEGMENT_BYPASS_MUTANT)
    True
#else
    not (Text.null _segment)
#endif
  currentDirectorySegmentAbsent _segment =
#if defined(VALIDATION_SOURCE_CONSUMER_DOT_PATH_SEGMENT_BYPASS_MUTANT)
    True
#else
    _segment /= "."
#endif
  parentDirectorySegmentAbsent _segment =
#if defined(VALIDATION_SOURCE_CONSUMER_DOTDOT_PATH_SEGMENT_BYPASS_MUTANT)
    True
#else
    _segment /= ".."
#endif
  portableSegment _segment =
#if defined(VALIDATION_SOURCE_CONSUMER_PATH_ALPHABET_BYPASS_MUTANT)
    Text.all portablePathCharacter _segment || not (Text.null _segment)
#else
    Text.all portablePathCharacter _segment
#endif

portablePathCharacter :: Char -> Bool
portablePathCharacter character =
  lowerPathCharacter character
    || upperPathCharacter character
    || digitPathCharacter character
    || dotPathCharacter character
    || underscorePathCharacter character
    || hyphenPathCharacter character

lowerPathCharacter, upperPathCharacter, digitPathCharacter :: Char -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_PATH_LOWER_ALTERNATIVE_DROP_MUTANT)
lowerPathCharacter _ = False
#else
lowerPathCharacter = Char.isAsciiLower
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_PATH_UPPER_ALTERNATIVE_DROP_MUTANT)
upperPathCharacter _ = False
#else
upperPathCharacter = Char.isAsciiUpper
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_PATH_DIGIT_ALTERNATIVE_DROP_MUTANT)
digitPathCharacter _ = False
#else
digitPathCharacter = Char.isDigit
#endif

dotPathCharacter, underscorePathCharacter, hyphenPathCharacter :: Char -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_PATH_DOT_ALTERNATIVE_DROP_MUTANT)
dotPathCharacter _ = False
#else
dotPathCharacter character = character == '.'
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_PATH_UNDERSCORE_ALTERNATIVE_DROP_MUTANT)
underscorePathCharacter _ = False
#else
underscorePathCharacter character = character == '_'
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_PATH_HYPHEN_ALTERNATIVE_DROP_MUTANT)
hyphenPathCharacter _ = False
#else
hyphenPathCharacter character = character == '-'
#endif

snapshotLowerHex :: Char -> Bool
snapshotLowerHex character = snapshotHexDigit character || snapshotHexLetter character

snapshotHexDigit, snapshotHexLetter :: Char -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_SNAPSHOT_HEX_DIGIT_ALTERNATIVE_DROP_MUTANT)
snapshotHexDigit _ = False
#else
snapshotHexDigit = Char.isDigit
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_SNAPSHOT_HEX_LETTER_ALTERNATIVE_DROP_MUTANT)
snapshotHexLetter _ = False
#else
snapshotHexLetter character = character `elem` ("abcdef" :: String)
#endif

objectLowerHex :: Char -> Bool
objectLowerHex character = objectHexDigit character || objectHexLetter character

objectHexDigit, objectHexLetter :: Char -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_OBJECT_HEX_DIGIT_ALTERNATIVE_DROP_MUTANT)
objectHexDigit _ = False
#else
objectHexDigit = Char.isDigit
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_OBJECT_HEX_LETTER_ALTERNATIVE_DROP_MUTANT)
objectHexLetter _ = False
#else
objectHexLetter character = character `elem` ("abcdef" :: String)
#endif

classifyEntries
  :: [RawEntry]
  -> ([ContentBinding], [HaskellSubject], [Finding])
classifyEntries = go [] [] []
 where
  go bindings subjects problems [] =
    ( orderedClassifiedBindings (reverse bindings)
    , orderedClassifiedSubjects (reverse subjects)
    , orderedClassifiedProblems (reverse problems)
    )
  go bindings subjects problems (entry : rest) =
    case parseEntryClass (rawEntryClassTag entry) of
      Nothing -> go bindings subjects problems rest
      Just HaskellEntry ->
        let subject =
              HaskellSubject
                (mutateSubjectPath (rawEntryPath entry))
                (mutateSubjectMode (rawEntryMode entry))
                (mutateSubjectObjectId (rawEntryObjectId entry))
            modeProblems =
#if defined(VALIDATION_SOURCE_CONSUMER_HASKELL_MODE_BYPASS_MUTANT)
              []
#else
              [ diagnosticFinding
                  HaskellModeProblem
                  "SRC-CONSUMER-HASKELL-MODE"
                  (rawEntryPath entry)
                  "every Haskell compiler subject must be a regular non-executable blob"
              | rawEntryMode entry /= "100644"
              ]
#endif
         in go bindings (subject : subjects) (reverse modeProblems <> problems) rest
      Just DocumentationEntry ->
#if defined(VALIDATION_SOURCE_CONSUMER_DOCUMENTATION_ROLE_BYPASS_MUTANT)
        unbound entry bindings subjects problems rest
#else
        bindOne GovernanceDocumentation entry bindings subjects problems rest
#endif
      Just ProjectDeclarationEntry ->
        case projectRole (rawEntryPath entry) of
          Nothing -> unbound entry bindings subjects problems rest
          Just role -> bindOne role entry bindings subjects problems rest
      Just OtherTrackedEntry -> go bindings subjects problems rest

  bindOne role entry bindings subjects problems rest
    | not (contentModeAdmitted entry) =
        go
          bindings
          subjects
          ( diagnosticFinding
              ContentModeProblem
              "SRC-CONSUMER-CONTENT-MODE"
              (rawEntryPath entry)
              "admitted non-source content must be a regular non-executable blob"
              : problems
          )
          rest
    | role == GovernanceDocumentation && ambiguousLegalName (rawEntryPath entry) =
#if defined(VALIDATION_SOURCE_CONSUMER_LEGAL_NAME_BYPASS_MUTANT)
        addBinding role entry bindings subjects problems rest
#else
        go
          bindings
          subjects
          ( diagnosticFinding
              LegalNameProblem
              "SRC-CONSUMER-LEGAL-NAME"
              (rawEntryPath entry)
              "LICENSE, LICENCE, COPYING, and NOTICE stems have no machine-owned semantic role"
              : problems
          )
          rest
#endif
    | role == GovernanceDocumentation && not (documentationSuffixAdmitted (rawEntryPath entry)) =
        unbound entry bindings subjects problems rest
    | otherwise = addBinding role entry bindings subjects problems rest

  addBinding role entry bindings subjects problems rest =
    let binding =
          ContentBinding
            (mutateBindingPath (rawEntryPath entry))
            (mutateBindingRole role)
            (mutateBindingConsumers (authorizedConsumers (rawEntryPath entry) role))
     in go (binding : bindings) subjects problems rest

  unbound entry bindings subjects problems rest =
#if defined(VALIDATION_SOURCE_CONSUMER_ROLE_UNBOUND_BYPASS_MUTANT)
    rawEntryPath entry `seq` go bindings subjects problems rest
#else
    go
      bindings
      subjects
      ( diagnosticFinding
          RoleUnboundProblem
          "SRC-CONSUMER-ROLE-UNBOUND"
          (rawEntryPath entry)
          "no exact closed content role exists for this admitted class and path"
          : problems
      )
      rest
#endif

orderedClassifiedBindings :: [ContentBinding] -> [ContentBinding]
#if defined(VALIDATION_SOURCE_CONSUMER_CLASSIFIED_BINDING_ORDER_MUTANT)
orderedClassifiedBindings = reverse
#else
orderedClassifiedBindings = id
#endif

orderedClassifiedSubjects :: [HaskellSubject] -> [HaskellSubject]
#if defined(VALIDATION_SOURCE_CONSUMER_CLASSIFIED_SUBJECT_ORDER_MUTANT)
orderedClassifiedSubjects = reverse
#else
orderedClassifiedSubjects = id
#endif

orderedClassifiedProblems :: [Finding] -> [Finding]
#if defined(VALIDATION_SOURCE_CONSUMER_CLASSIFIED_PROBLEM_ORDER_MUTANT)
orderedClassifiedProblems = reverse
#else
orderedClassifiedProblems = id
#endif

mutateSubjectPath :: FilePath -> FilePath
#if defined(VALIDATION_SOURCE_CONSUMER_SUBJECT_PATH_MAPPING_MUTANT)
mutateSubjectPath value = value <> "<"
#else
mutateSubjectPath value = value
#endif

mutateSubjectMode, mutateSubjectObjectId :: Text -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_SUBJECT_MODE_MAPPING_MUTANT)
mutateSubjectMode value = value <> "<"
#else
mutateSubjectMode value = value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_SUBJECT_OBJECT_MAPPING_MUTANT)
mutateSubjectObjectId value = value <> "0"
#else
mutateSubjectObjectId value = value
#endif

mutateBindingPath :: FilePath -> FilePath
#if defined(VALIDATION_SOURCE_CONSUMER_BINDING_PATH_MAPPING_MUTANT)
mutateBindingPath value = value <> "<"
#else
mutateBindingPath value = value
#endif

mutateBindingRole :: ContentRole -> ContentRole
#if defined(VALIDATION_SOURCE_CONSUMER_BINDING_ROLE_MAPPING_MUTANT)
mutateBindingRole GovernanceDocumentation = CabalPackageDescription
mutateBindingRole _ = GovernanceDocumentation
#else
mutateBindingRole value = value
#endif

mutateBindingConsumers :: [AuthorizedConsumer] -> [AuthorizedConsumer]
#if defined(VALIDATION_SOURCE_CONSUMER_BINDING_CONSUMERS_MAPPING_MUTANT)
mutateBindingConsumers = drop 1
#else
mutateBindingConsumers = id
#endif

contentModeAdmitted :: RawEntry -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_CONTENT_MODE_BYPASS_MUTANT)
contentModeAdmitted _ = True
#else
contentModeAdmitted entry = rawEntryMode entry == "100644"
#endif

documentationSuffixAdmitted :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_DOCUMENTATION_SUFFIX_BYPASS_MUTANT)
documentationSuffixAdmitted _ = True
#else
documentationSuffixAdmitted path = ".md" `Text.isSuffixOf` Text.pack path
#endif

parseEntryClass :: Text -> Maybe EntryClass
parseEntryClass = \case
  "haskell" ->
#if defined(VALIDATION_SOURCE_CONSUMER_PARSE_HASKELL_CLASS_DROP_MUTANT)
    Nothing
#else
    Just HaskellEntry
#endif
  "documentation" ->
#if defined(VALIDATION_SOURCE_CONSUMER_PARSE_DOCUMENTATION_CLASS_DROP_MUTANT)
    Nothing
#else
    Just DocumentationEntry
#endif
  "project-declaration" ->
#if defined(VALIDATION_SOURCE_CONSUMER_PARSE_PROJECT_CLASS_DROP_MUTANT)
    Nothing
#else
    Just ProjectDeclarationEntry
#endif
  "other" ->
#if defined(VALIDATION_SOURCE_CONSUMER_PARSE_OTHER_CLASS_DROP_MUTANT)
    Nothing
#else
    Just OtherTrackedEntry
#endif
  _ -> Nothing

projectRole :: FilePath -> Maybe ContentRole
projectRole path
  | path == "amoebius.cabal" =
#if defined(VALIDATION_SOURCE_CONSUMER_AMOEBIUS_CABAL_ROLE_BYPASS_MUTANT)
      Nothing
#else
      Just CabalPackageDescription
#endif
  | path == "probe/probe.cabal" =
#if defined(VALIDATION_SOURCE_CONSUMER_PROBE_CABAL_ROLE_BYPASS_MUTANT)
      Nothing
#else
      Just CabalPackageDescription
#endif
  | path == "cabal.project" =
#if defined(VALIDATION_SOURCE_CONSUMER_CABAL_PROJECT_ROLE_BYPASS_MUTANT)
      Nothing
#else
      Just CabalProjectDescription
#endif
  | path == ".gitignore" =
#if defined(VALIDATION_SOURCE_CONSUMER_GITIGNORE_ROLE_BYPASS_MUTANT)
      Nothing
#else
      Just GitIgnoreContract
#endif
  | path == ".dockerignore" =
#if defined(VALIDATION_SOURCE_CONSUMER_DOCKERIGNORE_ROLE_BYPASS_MUTANT)
      Nothing
#else
      Just DockerIgnoreContract
#endif
  | path == ".gitattributes" =
#if defined(VALIDATION_SOURCE_CONSUMER_GITATTRIBUTES_ROLE_BYPASS_MUTANT)
      Nothing
#else
      Just GitAttributesContract
#endif
  | path == ".editorconfig" =
#if defined(VALIDATION_SOURCE_CONSUMER_EDITORCONFIG_ROLE_BYPASS_MUTANT)
      Nothing
#else
      Just EditorConfiguration
#endif
  | otherwise = Nothing

ambiguousLegalName :: FilePath -> Bool
ambiguousLegalName path =
  licenseStem name
    || licenceStem name
    || copyingStem name
    || noticeStem name
 where
  name = normalizedLegalName (legalLastSegment (Text.splitOn "/" (Text.pack path)))

normalizedLegalName :: Text -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_LEGAL_CASE_NORMALIZATION_DROP_MUTANT)
normalizedLegalName = id
#else
normalizedLegalName = Text.toUpper
#endif

legalLastSegment :: [Text] -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_LEGAL_LAST_SEGMENT_DROP_MUTANT)
legalLastSegment = Text.intercalate "/"
#else
legalLastSegment = foldl (\_ segment -> segment) ""
#endif

licenseStem, licenceStem, copyingStem, noticeStem :: Text -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_LICENSE_STEM_ALTERNATIVE_DROP_MUTANT)
licenseStem _ = False
#else
licenseStem = legalStemMatches "LICENSE"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LICENCE_STEM_ALTERNATIVE_DROP_MUTANT)
licenceStem _ = False
#else
licenceStem = legalStemMatches "LICENCE"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_COPYING_STEM_ALTERNATIVE_DROP_MUTANT)
copyingStem _ = False
#else
copyingStem = legalStemMatches "COPYING"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_NOTICE_STEM_ALTERNATIVE_DROP_MUTANT)
noticeStem _ = False
#else
noticeStem = legalStemMatches "NOTICE"
#endif

legalStemMatches :: Text -> Text -> Bool
legalStemMatches stem name = legalExactMatch stem name || legalSuffixMatch stem name

legalExactMatch, legalSuffixMatch :: Text -> Text -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_LEGAL_EXACT_MATCH_ALTERNATIVE_DROP_MUTANT)
legalExactMatch _ _ = False
#else
legalExactMatch stem name = name == stem
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LEGAL_SUFFIX_MATCH_ALTERNATIVE_DROP_MUTANT)
legalSuffixMatch _ _ = False
#else
legalSuffixMatch stem name = (stem <> ".") `Text.isPrefixOf` name
#endif

authorizedConsumers :: FilePath -> ContentRole -> [AuthorizedConsumer]
authorizedConsumers path role = orderedAuthorizedConsumers (mutateAuthorizedConsumers path role base)
 where
  base = case role of
#if defined(VALIDATION_SOURCE_CONSUMER_FACADE_ROLE_BEHAVIORAL_AUTHORIZATION_MUTANT)
    GovernanceDocumentation ->
      [HumanReader, HaskellSourceBoundaryStructureChecker, HaskellDocumentationStructureChecker, HaskellProductRuntime]
#else
    GovernanceDocumentation ->
      retainedAuthorizedConsumers
        [ (GovernanceHumanConsumer, HumanReader)
        , (GovernanceSourceConsumer, HaskellSourceBoundaryStructureChecker)
        , (GovernanceDocumentationConsumer, HaskellDocumentationStructureChecker)
        ]
#endif
    CabalPackageDescription
      | path == "amoebius.cabal" ->
          retainedAuthorizedConsumers
            [ (AmoebiusCabalSourceConsumer, HaskellSourceBoundaryStructureChecker)
            , (AmoebiusCabalRootConsumer, HaskellRepositoryRootLocator)
            , (AmoebiusCabalBuildConsumer, CabalBuildTool)
            ]
      | otherwise ->
          retainedAuthorizedConsumers
            [ (ProbeCabalSourceConsumer, HaskellSourceBoundaryStructureChecker)
            , (ProbeCabalBuildConsumer, CabalBuildTool)
            ]
    CabalProjectDescription ->
      retainedAuthorizedConsumers
        [ (CabalProjectSourceConsumer, HaskellSourceBoundaryStructureChecker)
        , (CabalProjectRootConsumer, HaskellRepositoryRootLocator)
        , (CabalProjectBuildConsumer, CabalBuildTool)
        ]
    GitIgnoreContract ->
      retainedAuthorizedConsumers
        [ (GitIgnoreSourceConsumer, HaskellSourceBoundaryStructureChecker)
        , (GitIgnoreClientConsumer, GitClient)
        ]
    DockerIgnoreContract ->
      retainedAuthorizedConsumers
        [ (DockerIgnoreSourceConsumer, HaskellSourceBoundaryStructureChecker)
        , (DockerIgnoreBuilderConsumer, ContainerContextBuilder)
        ]
    GitAttributesContract ->
      retainedAuthorizedConsumers
        [ (GitAttributesSourceConsumer, HaskellSourceBoundaryStructureChecker)
        , (GitAttributesClientConsumer, GitClient)
        ]
    EditorConfiguration ->
      retainedAuthorizedConsumers
        [ (EditorConfigSourceConsumer, HaskellSourceBoundaryStructureChecker)
        , (EditorConfigToolConsumer, EditorTool)
        ]

orderedAuthorizedConsumers :: [AuthorizedConsumer] -> [AuthorizedConsumer]
#if defined(VALIDATION_SOURCE_CONSUMER_AUTHORIZED_CONSUMER_ORDER_MUTANT)
orderedAuthorizedConsumers = reverse
#else
orderedAuthorizedConsumers = id
#endif

retainedAuthorizedConsumers :: [(AuthorizedConsumerLocus, AuthorizedConsumer)] -> [AuthorizedConsumer]
retainedAuthorizedConsumers = concatMap (uncurry retainedAuthorizedConsumer)

retainedAuthorizedConsumer :: AuthorizedConsumerLocus -> AuthorizedConsumer -> [AuthorizedConsumer]
retainedAuthorizedConsumer locus consumer = case locus of
#if defined(VALIDATION_SOURCE_CONSUMER_GOVERNANCE_HUMAN_CONSUMER_DROP_MUTANT)
  GovernanceHumanConsumer -> []
#else
  GovernanceHumanConsumer -> [consumer]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_GOVERNANCE_SOURCE_CONSUMER_DROP_MUTANT)
  GovernanceSourceConsumer -> []
#else
  GovernanceSourceConsumer -> [consumer]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_GOVERNANCE_DOCUMENTATION_CONSUMER_DROP_MUTANT)
  GovernanceDocumentationConsumer -> []
#else
  GovernanceDocumentationConsumer -> [consumer]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_AMOEBIUS_CABAL_SOURCE_CONSUMER_DROP_MUTANT)
  AmoebiusCabalSourceConsumer -> []
#else
  AmoebiusCabalSourceConsumer -> [consumer]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_AMOEBIUS_CABAL_ROOT_CONSUMER_DROP_MUTANT)
  AmoebiusCabalRootConsumer -> []
#else
  AmoebiusCabalRootConsumer -> [consumer]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_AMOEBIUS_CABAL_BUILD_CONSUMER_DROP_MUTANT)
  AmoebiusCabalBuildConsumer -> []
#else
  AmoebiusCabalBuildConsumer -> [consumer]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_PROBE_CABAL_SOURCE_CONSUMER_DROP_MUTANT)
  ProbeCabalSourceConsumer -> []
#else
  ProbeCabalSourceConsumer -> [consumer]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_PROBE_CABAL_BUILD_CONSUMER_DROP_MUTANT)
  ProbeCabalBuildConsumer -> []
#else
  ProbeCabalBuildConsumer -> [consumer]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_CABAL_PROJECT_SOURCE_CONSUMER_DROP_MUTANT)
  CabalProjectSourceConsumer -> []
#else
  CabalProjectSourceConsumer -> [consumer]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_CABAL_PROJECT_ROOT_CONSUMER_DROP_MUTANT)
  CabalProjectRootConsumer -> []
#else
  CabalProjectRootConsumer -> [consumer]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_CABAL_PROJECT_BUILD_CONSUMER_DROP_MUTANT)
  CabalProjectBuildConsumer -> []
#else
  CabalProjectBuildConsumer -> [consumer]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_GITIGNORE_SOURCE_CONSUMER_DROP_MUTANT)
  GitIgnoreSourceConsumer -> []
#else
  GitIgnoreSourceConsumer -> [consumer]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_GITIGNORE_CLIENT_CONSUMER_DROP_MUTANT)
  GitIgnoreClientConsumer -> []
#else
  GitIgnoreClientConsumer -> [consumer]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_DOCKERIGNORE_SOURCE_CONSUMER_DROP_MUTANT)
  DockerIgnoreSourceConsumer -> []
#else
  DockerIgnoreSourceConsumer -> [consumer]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_DOCKERIGNORE_BUILDER_CONSUMER_DROP_MUTANT)
  DockerIgnoreBuilderConsumer -> []
#else
  DockerIgnoreBuilderConsumer -> [consumer]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_GITATTRIBUTES_SOURCE_CONSUMER_DROP_MUTANT)
  GitAttributesSourceConsumer -> []
#else
  GitAttributesSourceConsumer -> [consumer]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_GITATTRIBUTES_CLIENT_CONSUMER_DROP_MUTANT)
  GitAttributesClientConsumer -> []
#else
  GitAttributesClientConsumer -> [consumer]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EDITORCONFIG_SOURCE_CONSUMER_DROP_MUTANT)
  EditorConfigSourceConsumer -> []
#else
  EditorConfigSourceConsumer -> [consumer]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EDITORCONFIG_TOOL_CONSUMER_DROP_MUTANT)
  EditorConfigToolConsumer -> []
#else
  EditorConfigToolConsumer -> [consumer]
#endif


mutateAuthorizedConsumers
  :: FilePath
  -> ContentRole
  -> [AuthorizedConsumer]
  -> [AuthorizedConsumer]
mutateAuthorizedConsumers path role consumers = case role of
  GovernanceDocumentation ->
#if defined(VALIDATION_SOURCE_CONSUMER_DOCUMENTATION_CONSUMERS_DROP_MUTANT)
    take 2 consumers
#else
    consumers
#endif
  CabalPackageDescription
    | path == "amoebius.cabal" ->
#if defined(VALIDATION_SOURCE_CONSUMER_AMOEBIUS_CABAL_CONSUMERS_DROP_MUTANT)
        take 2 consumers
#else
        consumers
#endif
    | otherwise ->
#if defined(VALIDATION_SOURCE_CONSUMER_PROBE_CABAL_CONSUMERS_DROP_MUTANT)
        take 1 consumers
#else
        consumers
#endif
  CabalProjectDescription ->
#if defined(VALIDATION_SOURCE_CONSUMER_CABAL_PROJECT_CONSUMERS_DROP_MUTANT)
    take 2 consumers
#else
    consumers
#endif
  GitIgnoreContract ->
#if defined(VALIDATION_SOURCE_CONSUMER_GITIGNORE_CONSUMERS_DROP_MUTANT)
    take 1 consumers
#else
    consumers
#endif
  DockerIgnoreContract ->
#if defined(VALIDATION_SOURCE_CONSUMER_DOCKERIGNORE_CONSUMERS_DROP_MUTANT)
    take 1 consumers
#else
    consumers
#endif
  GitAttributesContract ->
#if defined(VALIDATION_SOURCE_CONSUMER_GITATTRIBUTES_CONSUMERS_DROP_MUTANT)
    take 1 consumers
#else
    consumers
#endif
  EditorConfiguration ->
#if defined(VALIDATION_SOURCE_CONSUMER_EDITORCONFIG_CONSUMERS_DROP_MUTANT)
    take 1 consumers
#else
    consumers
#endif

duplicateProblems :: [RawEntry] -> [Finding]
duplicateProblems = go Set.empty Set.empty
 where
  go _ _ [] = []
  go seen reported (entry : rest)
    | rawEntryPath entry `Set.member` seen
        && rawEntryPath entry `Set.notMember` reported =
#if defined(VALIDATION_SOURCE_CONSUMER_DUPLICATE_BYPASS_MUTANT)
        go seen (Set.insert (rawEntryPath entry) reported) rest
#else
        diagnosticFinding
          DuplicateProblem
          "SRC-CONSUMER-DUPLICATE"
          (rawEntryPath entry)
          "tracked inventory path occurs more than once"
          : go seen (Set.insert (rawEntryPath entry) reported) rest
#endif
    | otherwise = go (Set.insert (rawEntryPath entry) seen) reported rest

orderProblems :: [RawEntry] -> [Finding]
orderProblems entries =
  [ diagnosticFinding
      InventoryOrderProblem
      "SRC-CONSUMER-INVENTORY-ORDER"
      "inventory"
      "tracked inventory paths must be strictly increasing before semantic analysis"
  | not (strictlyIncreasing (map rawEntryPath entries))
#if defined(VALIDATION_SOURCE_CONSUMER_ORDER_BYPASS_MUTANT)
  , False
#endif
  ]

strictlyIncreasing :: Ord value => [value] -> Bool
strictlyIncreasing [] = True
strictlyIncreasing [_] = True
strictlyIncreasing (first : second : rest) = strictlyOrderedPair first second && strictlyIncreasing (second : rest)

strictlyOrderedPair :: Ord value => value -> value -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_INVENTORY_ORDER_COMPARATOR_MUTANT)
strictlyOrderedPair first second = first <= second
#else
strictlyOrderedPair first second = first < second
#endif

bindingCountProblems :: [RawEntry] -> [Finding]
bindingCountProblems entries =
  [ resourceFinding "content-bindings" maximumBindings count
  | let count = boundedLength (maximumBindings + 1) [() | entry <- entries, bindingCountTag (rawEntryClassTag entry)]
  , bindingCountLimitExceeded count
  ]

bindingCountLimitExceeded :: Int -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_BINDING_COUNT_PREDICATE_BYPASS_MUTANT)
bindingCountLimitExceeded _ = False
#else
bindingCountLimitExceeded count = count > maximumBindings
#endif

haskellCountProblems :: [RawEntry] -> [Finding]
haskellCountProblems entries =
  [ resourceFinding "haskell-subjects" maximumHaskellSubjects count
  | let count = boundedLength (maximumHaskellSubjects + 1) [() | entry <- entries, haskellCountTag (rawEntryClassTag entry)]
  , haskellCountLimitExceeded count
  ]

haskellCountLimitExceeded :: Int -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_HASKELL_COUNT_PREDICATE_BYPASS_MUTANT)
haskellCountLimitExceeded _ = False
#else
haskellCountLimitExceeded count = count > maximumHaskellSubjects
#endif

emptyInventoryProblems :: [RawEntry] -> [Finding]
#if defined(VALIDATION_SOURCE_CONSUMER_EMPTY_INVENTORY_BYPASS_MUTANT)
emptyInventoryProblems _ = []
#else
emptyInventoryProblems entries =
  [ diagnosticFinding EmptyInventoryProblem "SRC-CONSUMER-EMPTY-INVENTORY" "inventory" "tracked inventory must be nonempty"
  | null entries
  ]
#endif

emptyHaskellTagProblems :: [RawEntry] -> [Finding]
emptyHaskellTagProblems entries =
  [ diagnosticFinding
      EmptyHaskellProblem
      "SRC-CONSUMER-EMPTY-HASKELL"
      "inventory"
      "compiler residue cannot close over an empty Haskell subject inventory"
  | not (any (haskellPresenceTag . rawEntryClassTag) entries)
#if defined(VALIDATION_SOURCE_CONSUMER_EMPTY_HASKELL_BYPASS_MUTANT)
  , False
#endif
  ]

bindingCountTag :: Text -> Bool
bindingCountTag value = documentationBindingCountTag value || projectBindingCountTag value

documentationBindingCountTag, projectBindingCountTag :: Text -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_DOCUMENTATION_BINDING_COUNT_ALTERNATIVE_DROP_MUTANT)
documentationBindingCountTag _ = False
#else
documentationBindingCountTag value = value == "documentation"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_PROJECT_BINDING_COUNT_ALTERNATIVE_DROP_MUTANT)
projectBindingCountTag _ = False
#else
projectBindingCountTag value = value == "project-declaration"
#endif

haskellCountTag :: Text -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_HASKELL_COUNT_TAG_DROP_MUTANT)
haskellCountTag _ = False
#else
haskellCountTag value = value == "haskell"
#endif

haskellPresenceTag :: Text -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_HASKELL_PRESENCE_TAG_DROP_MUTANT)
haskellPresenceTag _ = False
#else
haskellPresenceTag value = value == "haskell"
#endif

parseEffect :: RawEffect -> Maybe ParsedEffect
parseEffect effect = do
  target <- case rawEffectTargetTag effect of
    "exact" ->
#if defined(VALIDATION_SOURCE_CONSUMER_PARSE_EXACT_TARGET_DROP_MUTANT)
      Nothing
#else
      Just (ExactTarget (Text.unpack (rawEffectTargetValue effect)))
#endif
    "dynamic" ->
#if defined(VALIDATION_SOURCE_CONSUMER_PARSE_DYNAMIC_TARGET_DROP_MUTANT)
      Nothing
#else
      Just (DynamicTarget (rawEffectTargetValue effect))
#endif
    "unresolved" ->
#if defined(VALIDATION_SOURCE_CONSUMER_PARSE_UNRESOLVED_TARGET_DROP_MUTANT)
      Nothing
#else
      Just (UnresolvedTarget (rawEffectTargetValue effect))
#endif
    _ -> Nothing
  use <- case rawEffectUseTag effect of
    "source-boundary-structure" ->
#if defined(VALIDATION_SOURCE_CONSUMER_PARSE_SOURCE_USE_DROP_MUTANT)
      Nothing
#else
      Just SourceBoundaryStructureInspection
#endif
    "documentation-structure" ->
#if defined(VALIDATION_SOURCE_CONSUMER_PARSE_DOCUMENTATION_USE_DROP_MUTANT)
      Nothing
#else
      Just StructuralDocumentationInspection
#endif
    "repository-root-sentinel" ->
#if defined(VALIDATION_SOURCE_CONSUMER_PARSE_ROOT_USE_DROP_MUTANT)
      Nothing
#else
      Just RepositoryRootSentinel
#endif
    "product-behaviour" ->
#if defined(VALIDATION_SOURCE_CONSUMER_PARSE_PRODUCT_USE_DROP_MUTANT)
      Nothing
#else
      Just ProductBehaviourInput
#endif
    _ -> Nothing
  pure
    ParsedEffect
      { parsedEffectModulePath = mutateParsedEffectModulePath (rawEffectModulePath effect)
      , parsedEffectModuleName = mutateParsedEffectModuleName (rawEffectModuleName effect)
      , parsedEffectBindingName = mutateParsedEffectBindingName (rawEffectBindingName effect)
      , parsedEffectTarget = mutateParsedEffectTarget target
      , parsedEffectUse = mutateParsedEffectUse use
      }

mutateParsedEffectModulePath :: FilePath -> FilePath
#if defined(VALIDATION_SOURCE_CONSUMER_PARSED_EFFECT_MODULE_PATH_MAPPING_MUTANT)
mutateParsedEffectModulePath value = value <> "<"
#else
mutateParsedEffectModulePath value = value
#endif

mutateParsedEffectModuleName, mutateParsedEffectBindingName :: Text -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_PARSED_EFFECT_MODULE_NAME_MAPPING_MUTANT)
mutateParsedEffectModuleName value = value <> "<"
#else
mutateParsedEffectModuleName value = value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_PARSED_EFFECT_BINDING_NAME_MAPPING_MUTANT)
mutateParsedEffectBindingName value = value <> "<"
#else
mutateParsedEffectBindingName value = value
#endif

mutateParsedEffectTarget :: EffectTarget -> EffectTarget
#if defined(VALIDATION_SOURCE_CONSUMER_PARSED_EFFECT_TARGET_MAPPING_MUTANT)
mutateParsedEffectTarget _ = DynamicTarget "mutated"
#else
mutateParsedEffectTarget value = value
#endif

mutateParsedEffectUse :: ContentUse -> ContentUse
#if defined(VALIDATION_SOURCE_CONSUMER_PARSED_EFFECT_USE_MAPPING_MUTANT)
mutateParsedEffectUse _ = ProductBehaviourInput
#else
mutateParsedEffectUse value = value
#endif

auditEffects :: [ContentBinding] -> [RawEffect] -> [Finding]
auditEffects bindings = orderedAuditEffects . concatMap (maybe [] (auditOne bindings) . parseEffect)

orderedAuditEffects :: [Finding] -> [Finding]
#if defined(VALIDATION_SOURCE_CONSUMER_AUDIT_EFFECT_ORDER_MUTANT)
orderedAuditEffects = reverse
#else
orderedAuditEffects = id
#endif

auditOne :: [ContentBinding] -> ParsedEffect -> [Finding]
auditOne bindings effect = case parsedEffectTarget effect of
  DynamicTarget detail ->
#if defined(VALIDATION_SOURCE_CONSUMER_FACADE_DYNAMIC_TARGET_BYPASS_MUTANT)
    dynamicTargetProblemDetail detail `seq` []
#else
    [ diagnosticFinding
        DynamicTargetProblem
        "SRC-CONSUMER-DYNAMIC-TARGET"
        (parsedEffectModulePath effect)
        (dynamicTargetProblemDetail detail)
    ]
#endif
  UnresolvedTarget detail ->
#if defined(VALIDATION_SOURCE_CONSUMER_UNRESOLVED_TARGET_BYPASS_MUTANT)
    unresolvedTargetProblemDetail detail `seq` []
#else
    [ diagnosticFinding
        UnresolvedEffectProblem
        "SRC-CONSUMER-UNRESOLVED-EFFECT"
        (parsedEffectModulePath effect)
        (unresolvedTargetProblemDetail detail)
    ]
#endif
  ExactTarget path -> case findBinding path bindings of
    Nothing ->
#if defined(VALIDATION_SOURCE_CONSUMER_EXACT_TARGET_BYPASS_MUTANT)
      []
#else
      [ diagnosticFinding
          EffectTargetProblem
          "SRC-CONSUMER-EFFECT-TARGET"
          path
          "resolved effect target has no admitted non-source content binding"
      ]
#endif
    Just binding -> auditExact binding effect

findBinding :: FilePath -> [ContentBinding] -> Maybe ContentBinding
findBinding _ [] = Nothing
findBinding path (binding : rest)
  | bindingPathMatches path binding = Just binding
  | otherwise = findBinding path rest

bindingPathMatches :: FilePath -> ContentBinding -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_BINDING_LOOKUP_MATCH_DROP_MUTANT)
bindingPathMatches _ _ = False
#else
bindingPathMatches path binding = bindingPath binding == path
#endif

auditExact :: ContentBinding -> ParsedEffect -> [Finding]
auditExact binding effect = case parsedEffectUse effect of
  ProductBehaviourInput ->
#if defined(VALIDATION_SOURCE_CONSUMER_FACADE_DIRECT_BEHAVIORAL_EFFECT_BYPASS_MUTANT)
    directProblemBindingPath binding `seq` []
#else
    [ diagnosticFinding
        DirectBehaviourProblem
        "SRC-CONSUMER-DIRECT-BEHAVIOUR"
        (parsedEffectModulePath effect)
        ( "resolved consumer "
            <> parsedEffectName effect
            <> " treats "
            <> directProblemBindingPath binding
            <> " as product behaviour"
        )
    ]
#endif
  SourceBoundaryStructureInspection
    | exactSourceBoundaryReader effect -> []
    | otherwise -> unauthorized binding effect
  StructuralDocumentationInspection
    | documentationBindingRoleAdmitted binding
        && exactDocumentationReader effect -> []
    | otherwise -> unauthorized binding effect
  RepositoryRootSentinel
    | repositoryRootBindingPathAdmitted binding
        && exactRepositoryRootReader effect -> []
    | otherwise -> unauthorized binding effect

exactSourceBoundaryReader :: ParsedEffect -> Bool
exactSourceBoundaryReader effect =
  sourceReaderPathMatches effect
    && sourceReaderModuleMatches effect
    && sourceReaderBindingMatches effect

sourceReaderPathMatches, sourceReaderModuleMatches, sourceReaderBindingMatches :: ParsedEffect -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_SOURCE_READER_PATH_CONJUNCT_BYPASS_MUTANT)
sourceReaderPathMatches _ = True
#else
sourceReaderPathMatches effect = parsedEffectModulePath effect == "src/validation-kernel/Amoebius/Validation/SourceClosure/Internal.hs"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_SOURCE_READER_MODULE_CONJUNCT_BYPASS_MUTANT)
sourceReaderModuleMatches _ = True
#else
sourceReaderModuleMatches effect = parsedEffectModuleName effect == "Amoebius.Validation.SourceClosure.Internal"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_SOURCE_READER_BINDING_CONJUNCT_BYPASS_MUTANT)
sourceReaderBindingMatches _ = True
#else
sourceReaderBindingMatches effect = parsedEffectBindingName effect == "classifyEntry"
#endif

exactDocumentationReader :: ParsedEffect -> Bool
exactDocumentationReader effect =
  documentationReaderPathMatches effect
    && documentationReaderModuleMatches effect
    && documentationReaderBindingMatches effect

documentationReaderPathMatches, documentationReaderModuleMatches, documentationReaderBindingMatches :: ParsedEffect -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_DOCUMENTATION_READER_PATH_CONJUNCT_BYPASS_MUTANT)
documentationReaderPathMatches _ = True
#else
documentationReaderPathMatches effect = parsedEffectModulePath effect == "src/validation-kernel/Amoebius/Validation/Documentation.hs"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_DOCUMENTATION_READER_MODULE_CONJUNCT_BYPASS_MUTANT)
documentationReaderModuleMatches _ = True
#else
documentationReaderModuleMatches effect = parsedEffectModuleName effect == "Amoebius.Validation.Documentation"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_DOCUMENTATION_READER_BINDING_CONJUNCT_BYPASS_MUTANT)
documentationReaderBindingMatches _ = True
#else
documentationReaderBindingMatches effect = parsedEffectBindingName effect == "readDocument"
#endif

exactRepositoryRootReader :: ParsedEffect -> Bool
exactRepositoryRootReader effect =
  rootReaderPathMatches effect
    && rootReaderModuleMatches effect
    && rootReaderBindingMatches effect

rootReaderPathMatches, rootReaderModuleMatches, rootReaderBindingMatches :: ParsedEffect -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_ROOT_READER_PATH_CONJUNCT_BYPASS_MUTANT)
rootReaderPathMatches _ = True
#else
rootReaderPathMatches effect = parsedEffectModulePath effect == "src/validation-kernel/Amoebius/Validation/Dispatch.hs"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_ROOT_READER_MODULE_CONJUNCT_BYPASS_MUTANT)
rootReaderModuleMatches _ = True
#else
rootReaderModuleMatches effect = parsedEffectModuleName effect == "Amoebius.Validation.Dispatch"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_ROOT_READER_BINDING_CONJUNCT_BYPASS_MUTANT)
rootReaderBindingMatches _ = True
#else
rootReaderBindingMatches effect = parsedEffectBindingName effect == "discoverRepositoryRoot"
#endif

documentationBindingRoleAdmitted :: ContentBinding -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_DOCUMENTATION_BINDING_ROLE_CONJUNCT_BYPASS_MUTANT)
documentationBindingRoleAdmitted _ = True
#else
documentationBindingRoleAdmitted binding = bindingRole binding == GovernanceDocumentation
#endif

repositoryRootBindingPathAdmitted :: ContentBinding -> Bool
repositoryRootBindingPathAdmitted binding =
  amoebiusRootBindingPath binding || cabalProjectRootBindingPath binding

amoebiusRootBindingPath, cabalProjectRootBindingPath :: ContentBinding -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_AMOEBIUS_ROOT_PATH_ALTERNATIVE_DROP_MUTANT)
amoebiusRootBindingPath _ = False
#else
amoebiusRootBindingPath binding = bindingPath binding == "amoebius.cabal"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_CABAL_PROJECT_ROOT_PATH_ALTERNATIVE_DROP_MUTANT)
cabalProjectRootBindingPath _ = False
#else
cabalProjectRootBindingPath binding = bindingPath binding == "cabal.project"
#endif

unauthorized :: ContentBinding -> ParsedEffect -> [Finding]
#if defined(VALIDATION_SOURCE_CONSUMER_UNAUTHORIZED_EFFECT_BYPASS_MUTANT)
unauthorized binding effect =
  unauthorizedProblemBindingPath binding `seq` unauthorizedProblemUse effect `seq` []
#else
unauthorized binding effect =
  [ diagnosticFinding
      UnauthorizedEffectProblem
      "SRC-CONSUMER-EFFECT-UNAUTHORIZED"
      (parsedEffectModulePath effect)
      ( "resolved consumer "
          <> parsedEffectName effect
          <> " is not authorized for "
          <> unauthorizedProblemBindingPath binding
          <> " as "
          <> unauthorizedProblemUse effect
      )
  ]
#endif

parsedEffectName :: ParsedEffect -> Text
parsedEffectName effect =
  parsedEffectNameModule effect
    <> parsedEffectNameSeparator
    <> parsedEffectNameBinding effect

parsedEffectNameModule, parsedEffectNameBinding :: ParsedEffect -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_PARSED_EFFECT_NAME_MODULE_MAPPING_MUTANT)
parsedEffectNameModule effect = parsedEffectModuleName effect <> "<"
#else
parsedEffectNameModule = parsedEffectModuleName
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_PARSED_EFFECT_NAME_BINDING_MAPPING_MUTANT)
parsedEffectNameBinding effect = parsedEffectBindingName effect <> "<"
#else
parsedEffectNameBinding = parsedEffectBindingName
#endif

parsedEffectNameSeparator :: Text
#if defined(VALIDATION_SOURCE_CONSUMER_PARSED_EFFECT_NAME_SEPARATOR_MAPPING_MUTANT)
parsedEffectNameSeparator = "<"
#else
parsedEffectNameSeparator = "."
#endif

dynamicTargetProblemDetail :: Text -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_DYNAMIC_TARGET_DETAIL_VALUE_MAPPING_MUTANT)
dynamicTargetProblemDetail value = "dynamic effect target may alias tracked content: " <> value <> "<"
#else
dynamicTargetProblemDetail value = "dynamic effect target may alias tracked content: " <> value
#endif

unresolvedTargetProblemDetail :: Text -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_UNRESOLVED_TARGET_DETAIL_VALUE_MAPPING_MUTANT)
unresolvedTargetProblemDetail value = "compiler effect target did not resolve: " <> value <> "<"
#else
unresolvedTargetProblemDetail value = "compiler effect target did not resolve: " <> value
#endif

directProblemBindingPath :: ContentBinding -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_DIRECT_PROBLEM_BINDING_PATH_MAPPING_MUTANT)
directProblemBindingPath binding = Text.pack (bindingPath binding) <> "<"
#else
directProblemBindingPath = Text.pack . bindingPath
#endif

unauthorizedProblemBindingPath :: ContentBinding -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_UNAUTHORIZED_PROBLEM_BINDING_PATH_MAPPING_MUTANT)
unauthorizedProblemBindingPath binding = Text.pack (bindingPath binding) <> "<"
#else
unauthorizedProblemBindingPath = Text.pack . bindingPath
#endif

unauthorizedProblemUse :: ParsedEffect -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_UNAUTHORIZED_PROBLEM_USE_MAPPING_MUTANT)
unauthorizedProblemUse effect = renderContentUse (parsedEffectUse effect) <> "<"
#else
unauthorizedProblemUse = renderContentUse . parsedEffectUse
#endif

preflightObservations
  :: Text
  -> [(FilePath, Text, Text, Text)]
  -> [(FilePath, Text, Text, Text, Text, Text)]
  -> [Observation]
preflightObservations identity inventory effects =
  orderedPreflightObservations
    ( limitObservations
        <> diagnosticObservation PreflightSnapshotObservation "input.snapshot-identity-characters" (decimal (preflightSnapshotWidth identity))
        <> diagnosticObservation PreflightInventoryObservation "input.inventory-count" (decimal (preflightInventoryCount inventory))
        <> diagnosticObservation PreflightEffectsObservation "input.effect-count" (decimal (preflightEffectCount effects))
    )

completeObservations
  :: Text
  -> [RawEntry]
  -> [RawEffect]
  -> [ContentBinding]
  -> [HaskellSubject]
  -> [Observation]
completeObservations identity entries effects bindings subjects =
  orderedCompleteObservations
    ( limitObservations
        <> diagnosticObservation CompleteSnapshotObservation "source-consumer.snapshot" (completeSnapshotValue identity)
        <> diagnosticObservation CompleteInventoryObservation "source-consumer.inventory-count" (decimal (completeInventoryCount entries))
        <> diagnosticObservation CompleteEffectsObservation "source-consumer.effect-count" (decimal (completeEffectCount effects))
        <> diagnosticObservation CompleteBindingsObservation "source-consumer.binding-count" (decimal (completeBindingCount bindings))
        <> diagnosticObservation CompleteHaskellObservation "source-consumer.haskell-count" (decimal (completeHaskellCount subjects))
        <> concat (zipWith entryObservation [0 :: Int ..] entries)
        <> concat (zipWith effectObservation [0 :: Int ..] effects)
        <> concatMap bindingObservation bindings
        <> concatMap subjectObservation subjects
        <> concat (zipWith compilerFactObservation [0 :: Int ..] requiredCompilerFacts)
    )

limitObservations :: [Observation]
limitObservations =
  orderedLimitObservations
    ( diagnosticObservation LimitInventoryObservation "limit.inventory-entries" (decimal maximumInventoryEntries)
        <> diagnosticObservation LimitEffectsObservation "limit.resolved-effects" (decimal maximumEffects)
        <> diagnosticObservation LimitPathBytesObservation "limit.path-bytes" (decimal maximumPathBytes)
        <> diagnosticObservation LimitPathDepthObservation "limit.path-depth" (decimal maximumPathDepth)
        <> diagnosticObservation LimitSegmentBytesObservation "limit.segment-bytes" (decimal maximumSegmentBytes)
        <> diagnosticObservation LimitFieldBytesObservation "limit.field-bytes" (decimal maximumFieldBytes)
        <> diagnosticObservation LimitBindingsObservation "limit.content-bindings" (decimal maximumBindings)
        <> diagnosticObservation LimitHaskellObservation "limit.haskell-subjects" (decimal maximumHaskellSubjects)
        <> diagnosticObservation LimitProblemsObservation "limit.problems" (decimal maximumProblems)
        <> diagnosticObservation LimitFindingsObservation "limit.result-findings" (decimal maximumFindings)
        <> diagnosticObservation LimitResultObservationsObservation "limit.result-observations" (decimal maximumObservations)
    )

orderedPreflightObservations, orderedCompleteObservations, orderedLimitObservations :: [Observation] -> [Observation]
#if defined(VALIDATION_SOURCE_CONSUMER_PREFLIGHT_OBSERVATION_ORDER_MUTANT)
orderedPreflightObservations = reverse
#else
orderedPreflightObservations = id
#endif

preflightSnapshotWidth :: Text -> Int
#if defined(VALIDATION_SOURCE_CONSUMER_PREFLIGHT_SNAPSHOT_WIDTH_MAPPING_MUTANT)
preflightSnapshotWidth value = boundedTextLength 65 value + 1
#else
preflightSnapshotWidth = boundedTextLength 65
#endif

preflightInventoryCount :: [value] -> Int
#if defined(VALIDATION_SOURCE_CONSUMER_PREFLIGHT_INVENTORY_COUNT_MAPPING_MUTANT)
preflightInventoryCount value = boundedLength 65 value + 1
#else
preflightInventoryCount = boundedLength 65
#endif

preflightEffectCount :: [value] -> Int
#if defined(VALIDATION_SOURCE_CONSUMER_PREFLIGHT_EFFECT_COUNT_MAPPING_MUTANT)
preflightEffectCount value = boundedLength 65 value + 1
#else
preflightEffectCount = boundedLength 65
#endif

completeSnapshotValue :: Text -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_COMPLETE_SNAPSHOT_VALUE_MAPPING_MUTANT)
completeSnapshotValue value = value <> "[snapshot-value-mapping-mutant]"
#else
completeSnapshotValue value = value
#endif

completeInventoryCount :: [RawEntry] -> Int
#if defined(VALIDATION_SOURCE_CONSUMER_COMPLETE_INVENTORY_COUNT_MAPPING_MUTANT)
completeInventoryCount value = length value + 1
#else
completeInventoryCount = length
#endif

completeEffectCount :: [RawEffect] -> Int
#if defined(VALIDATION_SOURCE_CONSUMER_COMPLETE_EFFECT_COUNT_MAPPING_MUTANT)
completeEffectCount value = length value + 1
#else
completeEffectCount = length
#endif

completeBindingCount :: [ContentBinding] -> Int
#if defined(VALIDATION_SOURCE_CONSUMER_COMPLETE_BINDING_COUNT_MAPPING_MUTANT)
completeBindingCount value = length value + 1
#else
completeBindingCount = length
#endif

completeHaskellCount :: [HaskellSubject] -> Int
#if defined(VALIDATION_SOURCE_CONSUMER_COMPLETE_HASKELL_COUNT_MAPPING_MUTANT)
completeHaskellCount value = length value + 1
#else
completeHaskellCount = length
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_COMPLETE_OBSERVATION_ORDER_MUTANT)
orderedCompleteObservations = reverse
#else
orderedCompleteObservations = id
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LIMIT_OBSERVATION_ORDER_MUTANT)
orderedLimitObservations = reverse
#else
orderedLimitObservations = id
#endif

entryObservation :: Int -> RawEntry -> [Observation]
entryObservation index entry =
  diagnosticObservation EntryObservation
    (entryObservationPrefix <> entryObservationIndex index)
    ( entryObservationPath entry
        <> entryObservationSeparatorOne
        <> entryObservationClass entry
        <> entryObservationSeparatorTwo
        <> entryObservationMode entry
        <> entryObservationSeparatorThree
        <> entryObservationObject entry
    )

entryObservationPrefix :: Text
#if defined(VALIDATION_SOURCE_CONSUMER_ENTRY_OBSERVATION_PREFIX_MAPPING_MUTANT)
entryObservationPrefix = "input.entry.<"
#else
entryObservationPrefix = "input.entry."
#endif

entryObservationIndex :: Int -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_ENTRY_OBSERVATION_INDEX_MAPPING_MUTANT)
entryObservationIndex value = decimal (value + 1)
#else
entryObservationIndex = decimal
#endif

entryObservationPath :: RawEntry -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_ENTRY_OBSERVATION_PATH_MAPPING_MUTANT)
entryObservationPath entry = Text.pack (rawEntryPath entry) <> "<"
#else
entryObservationPath = Text.pack . rawEntryPath
#endif

entryObservationClass, entryObservationMode, entryObservationObject :: RawEntry -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_ENTRY_OBSERVATION_CLASS_MAPPING_MUTANT)
entryObservationClass entry = rawEntryClassTag entry <> "<"
#else
entryObservationClass = rawEntryClassTag
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_ENTRY_OBSERVATION_MODE_MAPPING_MUTANT)
entryObservationMode entry = rawEntryMode entry <> "<"
#else
entryObservationMode = rawEntryMode
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_ENTRY_OBSERVATION_OBJECT_MAPPING_MUTANT)
entryObservationObject entry = rawEntryObjectId entry <> "<"
#else
entryObservationObject = rawEntryObjectId
#endif

entryObservationSeparatorOne, entryObservationSeparatorTwo, entryObservationSeparatorThree :: Text
#if defined(VALIDATION_SOURCE_CONSUMER_ENTRY_OBSERVATION_SEPARATOR_ONE_MAPPING_MUTANT)
entryObservationSeparatorOne = "|"
#else
entryObservationSeparatorOne = "\t"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_ENTRY_OBSERVATION_SEPARATOR_TWO_MAPPING_MUTANT)
entryObservationSeparatorTwo = "|"
#else
entryObservationSeparatorTwo = "\t"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_ENTRY_OBSERVATION_SEPARATOR_THREE_MAPPING_MUTANT)
entryObservationSeparatorThree = "|"
#else
entryObservationSeparatorThree = "\t"
#endif

effectObservation :: Int -> RawEffect -> [Observation]
effectObservation index effect =
  diagnosticObservation EffectObservation
    (effectObservationPrefix <> effectObservationIndex index)
    ( effectObservationModulePath effect
        <> effectObservationSeparatorOne
        <> effectObservationModuleName effect
        <> effectObservationSeparatorTwo
        <> effectObservationBindingName effect
        <> effectObservationSeparatorThree
        <> effectObservationTargetTag effect
        <> effectObservationSeparatorFour
        <> effectObservationTargetValue effect
        <> effectObservationSeparatorFive
        <> effectObservationUseTag effect
    )

effectObservationPrefix :: Text
#if defined(VALIDATION_SOURCE_CONSUMER_EFFECT_OBSERVATION_PREFIX_MAPPING_MUTANT)
effectObservationPrefix = "input.effect.<"
#else
effectObservationPrefix = "input.effect."
#endif

effectObservationIndex :: Int -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_EFFECT_OBSERVATION_INDEX_MAPPING_MUTANT)
effectObservationIndex value = decimal (value + 1)
#else
effectObservationIndex = decimal
#endif

effectObservationModulePath :: RawEffect -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_EFFECT_OBSERVATION_MODULE_PATH_MAPPING_MUTANT)
effectObservationModulePath effect = Text.pack (rawEffectModulePath effect) <> "<"
#else
effectObservationModulePath = Text.pack . rawEffectModulePath
#endif

effectObservationModuleName, effectObservationBindingName, effectObservationTargetTag :: RawEffect -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_EFFECT_OBSERVATION_MODULE_NAME_MAPPING_MUTANT)
effectObservationModuleName effect = rawEffectModuleName effect <> "<"
#else
effectObservationModuleName = rawEffectModuleName
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EFFECT_OBSERVATION_BINDING_NAME_MAPPING_MUTANT)
effectObservationBindingName effect = rawEffectBindingName effect <> "<"
#else
effectObservationBindingName = rawEffectBindingName
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EFFECT_OBSERVATION_TARGET_TAG_MAPPING_MUTANT)
effectObservationTargetTag effect = rawEffectTargetTag effect <> "<"
#else
effectObservationTargetTag = rawEffectTargetTag
#endif

effectObservationTargetValue, effectObservationUseTag :: RawEffect -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_EFFECT_OBSERVATION_TARGET_VALUE_MAPPING_MUTANT)
effectObservationTargetValue effect = rawEffectTargetValue effect <> "<"
#else
effectObservationTargetValue = rawEffectTargetValue
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EFFECT_OBSERVATION_USE_TAG_MAPPING_MUTANT)
effectObservationUseTag effect = rawEffectUseTag effect <> "<"
#else
effectObservationUseTag = rawEffectUseTag
#endif

effectObservationSeparatorOne, effectObservationSeparatorTwo, effectObservationSeparatorThree :: Text
effectObservationSeparatorOne = effectSeparatorOne
effectObservationSeparatorTwo = effectSeparatorTwo
effectObservationSeparatorThree = effectSeparatorThree

effectObservationSeparatorFour, effectObservationSeparatorFive :: Text
effectObservationSeparatorFour = effectSeparatorFour
effectObservationSeparatorFive = effectSeparatorFive

effectSeparatorOne, effectSeparatorTwo, effectSeparatorThree, effectSeparatorFour, effectSeparatorFive :: Text
#if defined(VALIDATION_SOURCE_CONSUMER_EFFECT_OBSERVATION_SEPARATOR_ONE_MAPPING_MUTANT)
effectSeparatorOne = "|"
#else
effectSeparatorOne = "\t"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EFFECT_OBSERVATION_SEPARATOR_TWO_MAPPING_MUTANT)
effectSeparatorTwo = "|"
#else
effectSeparatorTwo = "\t"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EFFECT_OBSERVATION_SEPARATOR_THREE_MAPPING_MUTANT)
effectSeparatorThree = "|"
#else
effectSeparatorThree = "\t"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EFFECT_OBSERVATION_SEPARATOR_FOUR_MAPPING_MUTANT)
effectSeparatorFour = "|"
#else
effectSeparatorFour = "\t"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EFFECT_OBSERVATION_SEPARATOR_FIVE_MAPPING_MUTANT)
effectSeparatorFive = "|"
#else
effectSeparatorFive = "\t"
#endif

bindingObservation :: ContentBinding -> [Observation]
bindingObservation binding =
  diagnosticObservation BindingObservation
    (bindingObservationPrefix <> bindingObservationPath binding)
    ( bindingObservationRole binding
        <> bindingObservationSeparator
        <> Text.intercalate bindingConsumerSeparator (map renderAuthorizedConsumer (bindingConsumers binding))
    )

bindingObservationPrefix :: Text
#if defined(VALIDATION_SOURCE_CONSUMER_BINDING_OBSERVATION_PREFIX_MAPPING_MUTANT)
bindingObservationPrefix = "source-consumer.binding.<"
#else
bindingObservationPrefix = "source-consumer.binding."
#endif

bindingObservationPath :: ContentBinding -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_BINDING_OBSERVATION_PATH_MAPPING_MUTANT)
bindingObservationPath binding = Text.pack (bindingPath binding) <> "<"
#else
bindingObservationPath = Text.pack . bindingPath
#endif

bindingObservationRole :: ContentBinding -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_BINDING_OBSERVATION_ROLE_MAPPING_MUTANT)
bindingObservationRole binding = renderContentRole (bindingRole binding) <> "<"
#else
bindingObservationRole = renderContentRole . bindingRole
#endif

bindingObservationSeparator, bindingConsumerSeparator :: Text
#if defined(VALIDATION_SOURCE_CONSUMER_BINDING_OBSERVATION_SEPARATOR_MAPPING_MUTANT)
bindingObservationSeparator = "|"
#else
bindingObservationSeparator = "\t"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_BINDING_CONSUMER_SEPARATOR_MAPPING_MUTANT)
bindingConsumerSeparator = "|"
#else
bindingConsumerSeparator = ","
#endif

subjectObservation :: HaskellSubject -> [Observation]
subjectObservation subject =
  diagnosticObservation SubjectObservation
    (subjectObservationPrefix <> subjectObservationPath subject)
    (subjectObservationMode subject <> subjectObservationSeparator <> subjectObservationObject subject)

subjectObservationPrefix :: Text
#if defined(VALIDATION_SOURCE_CONSUMER_SUBJECT_OBSERVATION_PREFIX_MAPPING_MUTANT)
subjectObservationPrefix = "source-consumer.haskell.<"
#else
subjectObservationPrefix = "source-consumer.haskell."
#endif

subjectObservationPath :: HaskellSubject -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_SUBJECT_OBSERVATION_PATH_MAPPING_MUTANT)
subjectObservationPath subject = Text.pack (subjectPath subject) <> "<"
#else
subjectObservationPath = Text.pack . subjectPath
#endif

subjectObservationMode, subjectObservationObject :: HaskellSubject -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_SUBJECT_OBSERVATION_MODE_MAPPING_MUTANT)
subjectObservationMode subject = subjectMode subject <> "<"
#else
subjectObservationMode = subjectMode
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_SUBJECT_OBSERVATION_OBJECT_MAPPING_MUTANT)
subjectObservationObject subject = subjectObjectId subject <> "<"
#else
subjectObservationObject = subjectObjectId
#endif

subjectObservationSeparator :: Text
#if defined(VALIDATION_SOURCE_CONSUMER_SUBJECT_OBSERVATION_SEPARATOR_MAPPING_MUTANT)
subjectObservationSeparator = "|"
#else
subjectObservationSeparator = "\t"
#endif

compilerFactObservation :: Int -> RequiredCompilerFact -> [Observation]
compilerFactObservation index fact =
  diagnosticObservation
    CompilerFactObservation
    (compilerFactObservationPrefix <> compilerFactObservationIndex index)
    (renderRequiredCompilerFact fact)

compilerFactObservationPrefix :: Text
#if defined(VALIDATION_SOURCE_CONSUMER_COMPILER_FACT_OBSERVATION_PREFIX_MAPPING_MUTANT)
compilerFactObservationPrefix = "source-consumer.required-fact.<"
#else
compilerFactObservationPrefix = "source-consumer.required-fact."
#endif

compilerFactObservationIndex :: Int -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_COMPILER_FACT_OBSERVATION_INDEX_MAPPING_MUTANT)
compilerFactObservationIndex value = decimal (value + 1)
#else
compilerFactObservationIndex = decimal
#endif

renderContentRole :: ContentRole -> Text
renderContentRole role = case role of
#if defined(VALIDATION_SOURCE_CONSUMER_GOVERNANCE_DOCUMENTATION_ROLE_RENDER_MAPPING_MUTANT)
  GovernanceDocumentation -> "GovernanceDocumentation<"
#else
  GovernanceDocumentation -> "GovernanceDocumentation"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_CABAL_PACKAGE_DESCRIPTION_ROLE_RENDER_MAPPING_MUTANT)
  CabalPackageDescription -> "CabalPackageDescription<"
#else
  CabalPackageDescription -> "CabalPackageDescription"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_CABAL_PROJECT_DESCRIPTION_ROLE_RENDER_MAPPING_MUTANT)
  CabalProjectDescription -> "CabalProjectDescription<"
#else
  CabalProjectDescription -> "CabalProjectDescription"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_GITIGNORE_CONTRACT_ROLE_RENDER_MAPPING_MUTANT)
  GitIgnoreContract -> "GitIgnoreContract<"
#else
  GitIgnoreContract -> "GitIgnoreContract"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_DOCKERIGNORE_CONTRACT_ROLE_RENDER_MAPPING_MUTANT)
  DockerIgnoreContract -> "DockerIgnoreContract<"
#else
  DockerIgnoreContract -> "DockerIgnoreContract"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_GITATTRIBUTES_CONTRACT_ROLE_RENDER_MAPPING_MUTANT)
  GitAttributesContract -> "GitAttributesContract<"
#else
  GitAttributesContract -> "GitAttributesContract"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EDITOR_CONFIGURATION_ROLE_RENDER_MAPPING_MUTANT)
  EditorConfiguration -> "EditorConfiguration<"
#else
  EditorConfiguration -> "EditorConfiguration"
#endif

renderAuthorizedConsumer :: AuthorizedConsumer -> Text
renderAuthorizedConsumer consumer = case consumer of
#if defined(VALIDATION_SOURCE_CONSUMER_HUMAN_READER_CONSUMER_RENDER_MAPPING_MUTANT)
  HumanReader -> "HumanReader<"
#else
  HumanReader -> "HumanReader"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_SOURCE_BOUNDARY_CHECKER_CONSUMER_RENDER_MAPPING_MUTANT)
  HaskellSourceBoundaryStructureChecker -> "HaskellSourceBoundaryStructureChecker<"
#else
  HaskellSourceBoundaryStructureChecker -> "HaskellSourceBoundaryStructureChecker"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_DOCUMENTATION_STRUCTURE_CHECKER_CONSUMER_RENDER_MAPPING_MUTANT)
  HaskellDocumentationStructureChecker -> "HaskellDocumentationStructureChecker<"
#else
  HaskellDocumentationStructureChecker -> "HaskellDocumentationStructureChecker"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_REPOSITORY_ROOT_LOCATOR_CONSUMER_RENDER_MAPPING_MUTANT)
  HaskellRepositoryRootLocator -> "HaskellRepositoryRootLocator<"
#else
  HaskellRepositoryRootLocator -> "HaskellRepositoryRootLocator"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_CABAL_BUILD_TOOL_CONSUMER_RENDER_MAPPING_MUTANT)
  CabalBuildTool -> "CabalBuildTool<"
#else
  CabalBuildTool -> "CabalBuildTool"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_GIT_CLIENT_CONSUMER_RENDER_MAPPING_MUTANT)
  GitClient -> "GitClient<"
#else
  GitClient -> "GitClient"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_CONTAINER_CONTEXT_BUILDER_CONSUMER_RENDER_MAPPING_MUTANT)
  ContainerContextBuilder -> "ContainerContextBuilder<"
#else
  ContainerContextBuilder -> "ContainerContextBuilder"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EDITOR_TOOL_CONSUMER_RENDER_MAPPING_MUTANT)
  EditorTool -> "EditorTool<"
#else
  EditorTool -> "EditorTool"
#endif
  HaskellProductRuntime -> "HaskellProductRuntime"

renderContentUse :: ContentUse -> Text
renderContentUse use = case use of
#if defined(VALIDATION_SOURCE_CONSUMER_SOURCE_BOUNDARY_USE_USE_RENDER_MAPPING_MUTANT)
  SourceBoundaryStructureInspection -> "SourceBoundaryStructureInspection<"
#else
  SourceBoundaryStructureInspection -> "SourceBoundaryStructureInspection"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_DOCUMENTATION_USE_USE_RENDER_MAPPING_MUTANT)
  StructuralDocumentationInspection -> "StructuralDocumentationInspection<"
#else
  StructuralDocumentationInspection -> "StructuralDocumentationInspection"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_ROOT_SENTINEL_USE_USE_RENDER_MAPPING_MUTANT)
  RepositoryRootSentinel -> "RepositoryRootSentinel<"
#else
  RepositoryRootSentinel -> "RepositoryRootSentinel"
#endif
  ProductBehaviourInput -> "ProductBehaviourInput"

renderRequiredCompilerFact :: RequiredCompilerFact -> Text
renderRequiredCompilerFact fact = case fact of
#if defined(VALIDATION_SOURCE_CONSUMER_COMPILER_PARSE_FACT_RENDER_MAPPING_MUTANT)
  CompilerParseSucceeded -> "CompilerParseSucceeded<"
#else
  CompilerParseSucceeded -> "CompilerParseSucceeded"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_CONDITIONAL_PREPROCESSING_FACT_RENDER_MAPPING_MUTANT)
  ConditionalPreprocessingClosed -> "ConditionalPreprocessingClosed<"
#else
  ConditionalPreprocessingClosed -> "ConditionalPreprocessingClosed"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_COMPILE_TIME_EXECUTION_FACT_RENDER_MAPPING_MUTANT)
  CompileTimeExecutionFeaturesAbsent -> "CompileTimeExecutionFeaturesAbsent<"
#else
  CompileTimeExecutionFeaturesAbsent -> "CompileTimeExecutionFeaturesAbsent"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_IMPORTS_RENAMED_FACT_RENDER_MAPPING_MUTANT)
  ImportsRenamed -> "ImportsRenamed<"
#else
  ImportsRenamed -> "ImportsRenamed"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_CALLS_RESOLVED_FACT_RENDER_MAPPING_MUTANT)
  CallsResolved -> "CallsResolved<"
#else
  CallsResolved -> "CallsResolved"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INDIRECT_CALLS_FACT_RENDER_MAPPING_MUTANT)
  IndirectCallsClosed -> "IndirectCallsClosed<"
#else
  IndirectCallsClosed -> "IndirectCallsClosed"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_CONTROL_FLOW_FACT_RENDER_MAPPING_MUTANT)
  ControlFlowClosed -> "ControlFlowClosed<"
#else
  ControlFlowClosed -> "ControlFlowClosed"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_FILESYSTEM_EFFECTS_FACT_RENDER_MAPPING_MUTANT)
  FilesystemEffectsClassified -> "FilesystemEffectsClassified<"
#else
  FilesystemEffectsClassified -> "FilesystemEffectsClassified"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EXTERNAL_EFFECTS_FACT_RENDER_MAPPING_MUTANT)
  ExternalProcessAndFfiEffectsClassified -> "ExternalProcessAndFfiEffectsClassified<"
#else
  ExternalProcessAndFfiEffectsClassified -> "ExternalProcessAndFfiEffectsClassified"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_PROVENANCE_FLOWS_FACT_RENDER_MAPPING_MUTANT)
  TrackedContentProvenanceFlowsClosed -> "TrackedContentProvenanceFlowsClosed<"
#else
  TrackedContentProvenanceFlowsClosed -> "TrackedContentProvenanceFlowsClosed"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_PRODUCT_SINKS_FACT_RENDER_MAPPING_MUTANT)
  ProductBehaviourSinksClassified -> "ProductBehaviourSinksClassified<"
#else
  ProductBehaviourSinksClassified -> "ProductBehaviourSinksClassified"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_DYNAMIC_LOADING_FACT_RENDER_MAPPING_MUTANT)
  DynamicCodeAndPluginLoadingAbsent -> "DynamicCodeAndPluginLoadingAbsent<"
#else
  DynamicCodeAndPluginLoadingAbsent -> "DynamicCodeAndPluginLoadingAbsent"
#endif

diagnosticObservation :: DiagnosticObservationKind -> Text -> Text -> [Observation]
diagnosticObservation kind key value
  | observationDropped kind = []
  | otherwise = [observation (mutateObservationKey kind key) (mutateObservationValue kind value)]

mutateObservationKey :: DiagnosticObservationKind -> Text -> Text
mutateObservationKey kind value = case kind of
#if defined(VALIDATION_SOURCE_CONSUMER_LIMIT_INVENTORY_OBSERVATION_KEY_MUTANT)
  LimitInventoryObservation -> value <> "<"
#else
  LimitInventoryObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LIMIT_EFFECTS_OBSERVATION_KEY_MUTANT)
  LimitEffectsObservation -> value <> "<"
#else
  LimitEffectsObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LIMIT_PATH_BYTES_OBSERVATION_KEY_MUTANT)
  LimitPathBytesObservation -> value <> "<"
#else
  LimitPathBytesObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LIMIT_PATH_DEPTH_OBSERVATION_KEY_MUTANT)
  LimitPathDepthObservation -> value <> "<"
#else
  LimitPathDepthObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LIMIT_SEGMENT_BYTES_OBSERVATION_KEY_MUTANT)
  LimitSegmentBytesObservation -> value <> "<"
#else
  LimitSegmentBytesObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LIMIT_FIELD_BYTES_OBSERVATION_KEY_MUTANT)
  LimitFieldBytesObservation -> value <> "<"
#else
  LimitFieldBytesObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LIMIT_BINDINGS_OBSERVATION_KEY_MUTANT)
  LimitBindingsObservation -> value <> "<"
#else
  LimitBindingsObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LIMIT_HASKELL_OBSERVATION_KEY_MUTANT)
  LimitHaskellObservation -> value <> "<"
#else
  LimitHaskellObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LIMIT_PROBLEMS_OBSERVATION_KEY_MUTANT)
  LimitProblemsObservation -> value <> "<"
#else
  LimitProblemsObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LIMIT_FINDINGS_OBSERVATION_KEY_MUTANT)
  LimitFindingsObservation -> value <> "<"
#else
  LimitFindingsObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LIMIT_RESULT_OBSERVATIONS_OBSERVATION_KEY_MUTANT)
  LimitResultObservationsObservation -> value <> "<"
#else
  LimitResultObservationsObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_PREFLIGHT_SNAPSHOT_OBSERVATION_KEY_MUTANT)
  PreflightSnapshotObservation -> value <> "<"
#else
  PreflightSnapshotObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_PREFLIGHT_INVENTORY_OBSERVATION_KEY_MUTANT)
  PreflightInventoryObservation -> value <> "<"
#else
  PreflightInventoryObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_PREFLIGHT_EFFECTS_OBSERVATION_KEY_MUTANT)
  PreflightEffectsObservation -> value <> "<"
#else
  PreflightEffectsObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_COMPLETE_SNAPSHOT_OBSERVATION_KEY_MUTANT)
  CompleteSnapshotObservation -> value <> "<"
#else
  CompleteSnapshotObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_COMPLETE_INVENTORY_OBSERVATION_KEY_MUTANT)
  CompleteInventoryObservation -> value <> "<"
#else
  CompleteInventoryObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_COMPLETE_EFFECTS_OBSERVATION_KEY_MUTANT)
  CompleteEffectsObservation -> value <> "<"
#else
  CompleteEffectsObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_COMPLETE_BINDINGS_OBSERVATION_KEY_MUTANT)
  CompleteBindingsObservation -> value <> "<"
#else
  CompleteBindingsObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_COMPLETE_HASKELL_OBSERVATION_KEY_MUTANT)
  CompleteHaskellObservation -> value <> "<"
#else
  CompleteHaskellObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_ENTRY_OBSERVATION_KEY_MUTANT)
  EntryObservation -> value <> "<"
#else
  EntryObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EFFECT_OBSERVATION_KEY_MUTANT)
  EffectObservation -> value <> "<"
#else
  EffectObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_BINDING_OBSERVATION_KEY_MUTANT)
  BindingObservation -> value <> "<"
#else
  BindingObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_SUBJECT_OBSERVATION_KEY_MUTANT)
  SubjectObservation -> value <> "<"
#else
  SubjectObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_COMPILER_FACT_OBSERVATION_KEY_MUTANT)
  CompilerFactObservation -> value <> "<"
#else
  CompilerFactObservation -> value
#endif

mutateObservationValue :: DiagnosticObservationKind -> Text -> Text
mutateObservationValue kind value = case kind of
#if defined(VALIDATION_SOURCE_CONSUMER_LIMIT_INVENTORY_OBSERVATION_VALUE_MUTANT)
  LimitInventoryObservation -> value <> "<"
#else
  LimitInventoryObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LIMIT_EFFECTS_OBSERVATION_VALUE_MUTANT)
  LimitEffectsObservation -> value <> "<"
#else
  LimitEffectsObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LIMIT_PATH_BYTES_OBSERVATION_VALUE_MUTANT)
  LimitPathBytesObservation -> value <> "<"
#else
  LimitPathBytesObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LIMIT_PATH_DEPTH_OBSERVATION_VALUE_MUTANT)
  LimitPathDepthObservation -> value <> "<"
#else
  LimitPathDepthObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LIMIT_SEGMENT_BYTES_OBSERVATION_VALUE_MUTANT)
  LimitSegmentBytesObservation -> value <> "<"
#else
  LimitSegmentBytesObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LIMIT_FIELD_BYTES_OBSERVATION_VALUE_MUTANT)
  LimitFieldBytesObservation -> value <> "<"
#else
  LimitFieldBytesObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LIMIT_BINDINGS_OBSERVATION_VALUE_MUTANT)
  LimitBindingsObservation -> value <> "<"
#else
  LimitBindingsObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LIMIT_HASKELL_OBSERVATION_VALUE_MUTANT)
  LimitHaskellObservation -> value <> "<"
#else
  LimitHaskellObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LIMIT_PROBLEMS_OBSERVATION_VALUE_MUTANT)
  LimitProblemsObservation -> value <> "<"
#else
  LimitProblemsObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LIMIT_FINDINGS_OBSERVATION_VALUE_MUTANT)
  LimitFindingsObservation -> value <> "<"
#else
  LimitFindingsObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LIMIT_RESULT_OBSERVATIONS_OBSERVATION_VALUE_MUTANT)
  LimitResultObservationsObservation -> value <> "<"
#else
  LimitResultObservationsObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_PREFLIGHT_SNAPSHOT_OBSERVATION_VALUE_MUTANT)
  PreflightSnapshotObservation -> value <> "<"
#else
  PreflightSnapshotObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_PREFLIGHT_INVENTORY_OBSERVATION_VALUE_MUTANT)
  PreflightInventoryObservation -> value <> "<"
#else
  PreflightInventoryObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_PREFLIGHT_EFFECTS_OBSERVATION_VALUE_MUTANT)
  PreflightEffectsObservation -> value <> "<"
#else
  PreflightEffectsObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_COMPLETE_SNAPSHOT_OBSERVATION_VALUE_MUTANT)
  CompleteSnapshotObservation -> value <> "<"
#else
  CompleteSnapshotObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_COMPLETE_INVENTORY_OBSERVATION_VALUE_MUTANT)
  CompleteInventoryObservation -> value <> "<"
#else
  CompleteInventoryObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_COMPLETE_EFFECTS_OBSERVATION_VALUE_MUTANT)
  CompleteEffectsObservation -> value <> "<"
#else
  CompleteEffectsObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_COMPLETE_BINDINGS_OBSERVATION_VALUE_MUTANT)
  CompleteBindingsObservation -> value <> "<"
#else
  CompleteBindingsObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_COMPLETE_HASKELL_OBSERVATION_VALUE_MUTANT)
  CompleteHaskellObservation -> value <> "<"
#else
  CompleteHaskellObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_ENTRY_OBSERVATION_VALUE_MUTANT)
  EntryObservation -> value <> "<"
#else
  EntryObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EFFECT_OBSERVATION_VALUE_MUTANT)
  EffectObservation -> value <> "<"
#else
  EffectObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_BINDING_OBSERVATION_VALUE_MUTANT)
  BindingObservation -> value <> "<"
#else
  BindingObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_SUBJECT_OBSERVATION_VALUE_MUTANT)
  SubjectObservation -> value <> "<"
#else
  SubjectObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_COMPILER_FACT_OBSERVATION_VALUE_MUTANT)
  CompilerFactObservation -> value <> "<"
#else
  CompilerFactObservation -> value
#endif

observationDropped :: DiagnosticObservationKind -> Bool
observationDropped kind = case kind of
#if defined(VALIDATION_SOURCE_CONSUMER_LIMIT_INVENTORY_OBSERVATION_DROP_MUTANT)
  LimitInventoryObservation -> True
#else
  LimitInventoryObservation -> False
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LIMIT_EFFECTS_OBSERVATION_DROP_MUTANT)
  LimitEffectsObservation -> True
#else
  LimitEffectsObservation -> False
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LIMIT_PATH_BYTES_OBSERVATION_DROP_MUTANT)
  LimitPathBytesObservation -> True
#else
  LimitPathBytesObservation -> False
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LIMIT_PATH_DEPTH_OBSERVATION_DROP_MUTANT)
  LimitPathDepthObservation -> True
#else
  LimitPathDepthObservation -> False
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LIMIT_SEGMENT_BYTES_OBSERVATION_DROP_MUTANT)
  LimitSegmentBytesObservation -> True
#else
  LimitSegmentBytesObservation -> False
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LIMIT_FIELD_BYTES_OBSERVATION_DROP_MUTANT)
  LimitFieldBytesObservation -> True
#else
  LimitFieldBytesObservation -> False
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LIMIT_BINDINGS_OBSERVATION_DROP_MUTANT)
  LimitBindingsObservation -> True
#else
  LimitBindingsObservation -> False
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LIMIT_HASKELL_OBSERVATION_DROP_MUTANT)
  LimitHaskellObservation -> True
#else
  LimitHaskellObservation -> False
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LIMIT_PROBLEMS_OBSERVATION_DROP_MUTANT)
  LimitProblemsObservation -> True
#else
  LimitProblemsObservation -> False
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LIMIT_FINDINGS_OBSERVATION_DROP_MUTANT)
  LimitFindingsObservation -> True
#else
  LimitFindingsObservation -> False
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LIMIT_RESULT_OBSERVATIONS_OBSERVATION_DROP_MUTANT)
  LimitResultObservationsObservation -> True
#else
  LimitResultObservationsObservation -> False
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_PREFLIGHT_SNAPSHOT_OBSERVATION_DROP_MUTANT)
  PreflightSnapshotObservation -> True
#else
  PreflightSnapshotObservation -> False
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_PREFLIGHT_INVENTORY_OBSERVATION_DROP_MUTANT)
  PreflightInventoryObservation -> True
#else
  PreflightInventoryObservation -> False
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_PREFLIGHT_EFFECTS_OBSERVATION_DROP_MUTANT)
  PreflightEffectsObservation -> True
#else
  PreflightEffectsObservation -> False
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_COMPLETE_SNAPSHOT_OBSERVATION_DROP_MUTANT)
  CompleteSnapshotObservation -> True
#else
  CompleteSnapshotObservation -> False
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_COMPLETE_INVENTORY_OBSERVATION_DROP_MUTANT)
  CompleteInventoryObservation -> True
#else
  CompleteInventoryObservation -> False
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_COMPLETE_EFFECTS_OBSERVATION_DROP_MUTANT)
  CompleteEffectsObservation -> True
#else
  CompleteEffectsObservation -> False
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_COMPLETE_BINDINGS_OBSERVATION_DROP_MUTANT)
  CompleteBindingsObservation -> True
#else
  CompleteBindingsObservation -> False
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_COMPLETE_HASKELL_OBSERVATION_DROP_MUTANT)
  CompleteHaskellObservation -> True
#else
  CompleteHaskellObservation -> False
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_ENTRY_OBSERVATION_DROP_MUTANT)
  EntryObservation -> True
#else
  EntryObservation -> False
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EFFECT_OBSERVATION_DROP_MUTANT)
  EffectObservation -> True
#else
  EffectObservation -> False
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_BINDING_OBSERVATION_DROP_MUTANT)
  BindingObservation -> True
#else
  BindingObservation -> False
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_SUBJECT_OBSERVATION_DROP_MUTANT)
  SubjectObservation -> True
#else
  SubjectObservation -> False
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_COMPILER_FACT_OBSERVATION_DROP_MUTANT)
  CompilerFactObservation -> True
#else
  CompilerFactObservation -> False
#endif


permanentFindings :: [Finding]
permanentFindings =
  orderedPermanentFindings
    ( diagnosticOnlyFindings
        <> sourceBindingFindings
        <> map compilerResidueFinding requiredCompilerFacts
    )

orderedPermanentFindings :: [Finding] -> [Finding]
#if defined(VALIDATION_SOURCE_CONSUMER_PERMANENT_FINDING_ORDER_MUTANT)
orderedPermanentFindings = reverse
#else
orderedPermanentFindings = id
#endif

diagnosticOnlyFindings :: [Finding]
#if defined(VALIDATION_SOURCE_CONSUMER_DIAGNOSTIC_ONLY_BYPASS_MUTANT)
diagnosticOnlyFindings = []
#else
diagnosticOnlyFindings =
  [ diagnosticFinding
      DiagnosticOnlyProblem
      "SRC-CONSUMER-DIAGNOSTIC-ONLY"
      "Amoebius.Validation.SourceConsumerGraph.sourceConsumerGraphDiagnostic"
      "caller-supplied inventory and effect rows cannot establish source-consumer closure"
  ]
#endif

sourceBindingFindings :: [Finding]
#if defined(VALIDATION_SOURCE_CONSUMER_LOCAL_CAPTURE_RESIDUE_BYPASS_MUTANT)
sourceBindingFindings = []
#else
sourceBindingFindings =
  [ diagnosticFinding
      SourceBindingProblem
      "SRC-CONSUMER-SOURCE-BINDING-RESIDUE"
      "source-snapshot"
      "an independently authenticated immutable source snapshot is absent"
  ]
#endif

requiredCompilerFacts :: [RequiredCompilerFact]
requiredCompilerFacts =
  orderedRequiredCompilerFacts
    ( concat
        [ retainedFact retainParseFact (mappedRequiredCompilerFact CompilerParseSucceeded)
        , retainedFact retainCppFact (mappedRequiredCompilerFact ConditionalPreprocessingClosed)
        , retainedFact retainCompileTimeFact (mappedRequiredCompilerFact CompileTimeExecutionFeaturesAbsent)
        , retainedFact retainImportsFact (mappedRequiredCompilerFact ImportsRenamed)
        , retainedFact retainCallsFact (mappedRequiredCompilerFact CallsResolved)
        , retainedFact retainIndirectFact (mappedRequiredCompilerFact IndirectCallsClosed)
        , retainedFact retainControlFlowFact (mappedRequiredCompilerFact ControlFlowClosed)
        , retainedFact retainFilesystemFact (mappedRequiredCompilerFact FilesystemEffectsClassified)
        , retainedFact retainExternalFact (mappedRequiredCompilerFact ExternalProcessAndFfiEffectsClassified)
        , retainedFact retainProvenanceFact (mappedRequiredCompilerFact TrackedContentProvenanceFlowsClosed)
        , retainedFact retainSinksFact (mappedRequiredCompilerFact ProductBehaviourSinksClassified)
        , retainedFact retainDynamicLoadingFact (mappedRequiredCompilerFact DynamicCodeAndPluginLoadingAbsent)
        ]
    )

orderedRequiredCompilerFacts :: [RequiredCompilerFact] -> [RequiredCompilerFact]
#if defined(VALIDATION_SOURCE_CONSUMER_REQUIRED_FACT_ORDER_MUTANT)
orderedRequiredCompilerFacts = reverse
#else
orderedRequiredCompilerFacts = id
#endif

mappedRequiredCompilerFact :: RequiredCompilerFact -> RequiredCompilerFact
mappedRequiredCompilerFact fact = case fact of
#if defined(VALIDATION_SOURCE_CONSUMER_COMPILER_PARSE_FACT_IDENTITY_MAPPING_MUTANT)
  CompilerParseSucceeded -> CallsResolved
#else
  CompilerParseSucceeded -> CompilerParseSucceeded
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_CONDITIONAL_PREPROCESSING_FACT_IDENTITY_MAPPING_MUTANT)
  ConditionalPreprocessingClosed -> CallsResolved
#else
  ConditionalPreprocessingClosed -> ConditionalPreprocessingClosed
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_COMPILE_TIME_EXECUTION_FACT_IDENTITY_MAPPING_MUTANT)
  CompileTimeExecutionFeaturesAbsent -> CallsResolved
#else
  CompileTimeExecutionFeaturesAbsent -> CompileTimeExecutionFeaturesAbsent
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_IMPORTS_RENAMED_FACT_IDENTITY_MAPPING_MUTANT)
  ImportsRenamed -> CallsResolved
#else
  ImportsRenamed -> ImportsRenamed
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_CALLS_RESOLVED_FACT_IDENTITY_MAPPING_MUTANT)
  CallsResolved -> CompilerParseSucceeded
#else
  CallsResolved -> CallsResolved
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INDIRECT_CALLS_FACT_IDENTITY_MAPPING_MUTANT)
  IndirectCallsClosed -> CallsResolved
#else
  IndirectCallsClosed -> IndirectCallsClosed
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_CONTROL_FLOW_FACT_IDENTITY_MAPPING_MUTANT)
  ControlFlowClosed -> CallsResolved
#else
  ControlFlowClosed -> ControlFlowClosed
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_FILESYSTEM_EFFECTS_FACT_IDENTITY_MAPPING_MUTANT)
  FilesystemEffectsClassified -> CallsResolved
#else
  FilesystemEffectsClassified -> FilesystemEffectsClassified
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EXTERNAL_EFFECTS_FACT_IDENTITY_MAPPING_MUTANT)
  ExternalProcessAndFfiEffectsClassified -> CallsResolved
#else
  ExternalProcessAndFfiEffectsClassified -> ExternalProcessAndFfiEffectsClassified
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_PROVENANCE_FLOWS_FACT_IDENTITY_MAPPING_MUTANT)
  TrackedContentProvenanceFlowsClosed -> CallsResolved
#else
  TrackedContentProvenanceFlowsClosed -> TrackedContentProvenanceFlowsClosed
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_PRODUCT_SINKS_FACT_IDENTITY_MAPPING_MUTANT)
  ProductBehaviourSinksClassified -> CallsResolved
#else
  ProductBehaviourSinksClassified -> ProductBehaviourSinksClassified
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_DYNAMIC_LOADING_FACT_IDENTITY_MAPPING_MUTANT)
  DynamicCodeAndPluginLoadingAbsent -> CallsResolved
#else
  DynamicCodeAndPluginLoadingAbsent -> DynamicCodeAndPluginLoadingAbsent
#endif

retainedFact :: Bool -> RequiredCompilerFact -> [RequiredCompilerFact]
retainedFact True fact = [fact]
retainedFact False _ = []

retainParseFact, retainCppFact, retainCompileTimeFact, retainImportsFact :: Bool
#if defined(VALIDATION_SOURCE_CONSUMER_PARSE_FACT_DROP_MUTANT)
retainParseFact = False
#else
retainParseFact = True
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_CPP_FACT_DROP_MUTANT)
retainCppFact = False
#else
retainCppFact = True
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_COMPILE_TIME_FACT_DROP_MUTANT)
retainCompileTimeFact = False
#else
retainCompileTimeFact = True
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_IMPORTS_FACT_DROP_MUTANT)
retainImportsFact = False
#else
retainImportsFact = True
#endif

retainCallsFact, retainIndirectFact, retainControlFlowFact, retainFilesystemFact :: Bool
#if defined(VALIDATION_SOURCE_CONSUMER_CALLS_FACT_DROP_MUTANT)
retainCallsFact = False
#else
retainCallsFact = True
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INDIRECT_FACT_DROP_MUTANT)
retainIndirectFact = False
#else
retainIndirectFact = True
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_CONTROL_FLOW_FACT_DROP_MUTANT)
retainControlFlowFact = False
#else
retainControlFlowFact = True
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_FILESYSTEM_FACT_DROP_MUTANT)
retainFilesystemFact = False
#else
retainFilesystemFact = True
#endif

retainExternalFact, retainProvenanceFact, retainSinksFact, retainDynamicLoadingFact :: Bool
#if defined(VALIDATION_SOURCE_CONSUMER_EXTERNAL_FACT_DROP_MUTANT)
retainExternalFact = False
#else
retainExternalFact = True
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_PROVENANCE_FACT_DROP_MUTANT)
retainProvenanceFact = False
#else
retainProvenanceFact = True
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_SINKS_FACT_DROP_MUTANT)
retainSinksFact = False
#else
retainSinksFact = True
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_DYNAMIC_LOADING_FACT_DROP_MUTANT)
retainDynamicLoadingFact = False
#else
retainDynamicLoadingFact = True
#endif

compilerResidueFinding :: RequiredCompilerFact -> Finding
compilerResidueFinding fact =
  diagnosticFinding
    CompilerResidueProblem
    "SRC-CONSUMER-COMPILER-RESIDUE"
    (Text.unpack (renderRequiredCompilerFact fact))
    "this mandatory fact requires an exact source-bound compiler graph and cannot be supplied by a caller effect list"

boundedProblems :: [Finding] -> Either Finding [Finding]
boundedProblems problems
  | problemLimitExceeded observed =
      Left (resourceFinding "diagnostic-problems" maximumProblems observed)
  | otherwise = Right problems
 where
  observed = boundedLength (maximumProblems + 1) problems

problemLimitExceeded :: Int -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_PROBLEM_LIMIT_ROUTE_BYPASS_MUTANT)
problemLimitExceeded _ = False
#else
problemLimitExceeded observed = observed > maximumProblems
#endif

resourceFinding :: Text -> Int -> Int -> Finding
resourceFinding resource limit observed =
  diagnosticFinding
    ResourceProblem
    "SRC-CONSUMER-RESOURCE-LIMIT"
    (Text.unpack resource)
    ( resourceDetailName resource
        <> " exceeds the "
        <> resourceDetailLimit limit
        <> " bound; observed "
        <> resourceDetailObserved observed
    )

resourceDetailName :: Text -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_RESOURCE_DETAIL_NAME_MAPPING_MUTANT)
resourceDetailName value = value <> "<"
#else
resourceDetailName value = value
#endif

resourceDetailLimit, resourceDetailObserved :: Int -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_RESOURCE_DETAIL_LIMIT_MAPPING_MUTANT)
resourceDetailLimit value = decimal (value + 1)
#else
resourceDetailLimit = decimal
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_RESOURCE_DETAIL_OBSERVED_MAPPING_MUTANT)
resourceDetailObserved value = decimal (value + 1)
#else
resourceDetailObserved = decimal
#endif

diagnosticFinding :: DiagnosticProblemKind -> Text -> FilePath -> Text -> Finding
diagnosticFinding kind code subject detail =
  finding
    (mutateProblemCode kind code)
    (mutateProblemSubject kind subject)
    (mutateProblemDetail kind detail)

mutateProblemCode :: DiagnosticProblemKind -> Text -> Text
mutateProblemCode kind value = case kind of
#if defined(VALIDATION_SOURCE_CONSUMER_SNAPSHOT_IDENTITY_CODE_MAPPING_MUTANT)
  SnapshotIdentityProblem -> value <> "-MUTATED"
#else
  SnapshotIdentityProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EFFECT_MODULE_NAME_CODE_MAPPING_MUTANT)
  EffectModuleNameProblem -> value <> "-MUTATED"
#else
  EffectModuleNameProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EFFECT_BINDING_NAME_CODE_MAPPING_MUTANT)
  EffectBindingNameProblem -> value <> "-MUTATED"
#else
  EffectBindingNameProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_POSIX_PATH_CODE_MAPPING_MUTANT)
  PosixPathProblem -> value <> "-MUTATED"
#else
  PosixPathProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EXACT_TARGET_PATH_CODE_MAPPING_MUTANT)
  ExactTargetPathProblem -> value <> "-MUTATED"
#else
  ExactTargetPathProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_CLASS_TAG_CODE_MAPPING_MUTANT)
  ClassTagProblem -> value <> "-MUTATED"
#else
  ClassTagProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_MODE_TAG_CODE_MAPPING_MUTANT)
  ModeTagProblem -> value <> "-MUTATED"
#else
  ModeTagProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_OBJECT_ID_CODE_MAPPING_MUTANT)
  ObjectIdProblem -> value <> "-MUTATED"
#else
  ObjectIdProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_TARGET_TAG_CODE_MAPPING_MUTANT)
  TargetTagProblem -> value <> "-MUTATED"
#else
  TargetTagProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_TARGET_VALUE_CODE_MAPPING_MUTANT)
  TargetValueProblem -> value <> "-MUTATED"
#else
  TargetValueProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_USE_TAG_CODE_MAPPING_MUTANT)
  UseTagProblem -> value <> "-MUTATED"
#else
  UseTagProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_HASKELL_MODE_CODE_MAPPING_MUTANT)
  HaskellModeProblem -> value <> "-MUTATED"
#else
  HaskellModeProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_CONTENT_MODE_CODE_MAPPING_MUTANT)
  ContentModeProblem -> value <> "-MUTATED"
#else
  ContentModeProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LEGAL_NAME_CODE_MAPPING_MUTANT)
  LegalNameProblem -> value <> "-MUTATED"
#else
  LegalNameProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_ROLE_UNBOUND_CODE_MAPPING_MUTANT)
  RoleUnboundProblem -> value <> "-MUTATED"
#else
  RoleUnboundProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_DUPLICATE_CODE_MAPPING_MUTANT)
  DuplicateProblem -> value <> "-MUTATED"
#else
  DuplicateProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INVENTORY_ORDER_CODE_MAPPING_MUTANT)
  InventoryOrderProblem -> value <> "-MUTATED"
#else
  InventoryOrderProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EMPTY_INVENTORY_CODE_MAPPING_MUTANT)
  EmptyInventoryProblem -> value <> "-MUTATED"
#else
  EmptyInventoryProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EMPTY_HASKELL_CODE_MAPPING_MUTANT)
  EmptyHaskellProblem -> value <> "-MUTATED"
#else
  EmptyHaskellProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_DYNAMIC_TARGET_CODE_MAPPING_MUTANT)
  DynamicTargetProblem -> value <> "-MUTATED"
#else
  DynamicTargetProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_UNRESOLVED_EFFECT_CODE_MAPPING_MUTANT)
  UnresolvedEffectProblem -> value <> "-MUTATED"
#else
  UnresolvedEffectProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EFFECT_TARGET_CODE_MAPPING_MUTANT)
  EffectTargetProblem -> value <> "-MUTATED"
#else
  EffectTargetProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_DIRECT_BEHAVIOUR_CODE_MAPPING_MUTANT)
  DirectBehaviourProblem -> value <> "-MUTATED"
#else
  DirectBehaviourProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_UNAUTHORIZED_EFFECT_CODE_MAPPING_MUTANT)
  UnauthorizedEffectProblem -> value <> "-MUTATED"
#else
  UnauthorizedEffectProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_DIAGNOSTIC_ONLY_CODE_MAPPING_MUTANT)
  DiagnosticOnlyProblem -> value <> "-MUTATED"
#else
  DiagnosticOnlyProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_SOURCE_BINDING_CODE_MAPPING_MUTANT)
  SourceBindingProblem -> value <> "-MUTATED"
#else
  SourceBindingProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_COMPILER_RESIDUE_CODE_MAPPING_MUTANT)
  CompilerResidueProblem -> value <> "-MUTATED"
#else
  CompilerResidueProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_RESOURCE_CODE_MAPPING_MUTANT)
  ResourceProblem -> value <> "-MUTATED"
#else
  ResourceProblem -> value
#endif

mutateProblemSubject :: DiagnosticProblemKind -> FilePath -> FilePath
mutateProblemSubject kind value = case kind of
#if defined(VALIDATION_SOURCE_CONSUMER_SNAPSHOT_IDENTITY_SUBJECT_MAPPING_MUTANT)
  SnapshotIdentityProblem -> value <> "<"
#else
  SnapshotIdentityProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EFFECT_MODULE_NAME_SUBJECT_MAPPING_MUTANT)
  EffectModuleNameProblem -> value <> "<"
#else
  EffectModuleNameProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EFFECT_BINDING_NAME_SUBJECT_MAPPING_MUTANT)
  EffectBindingNameProblem -> value <> "<"
#else
  EffectBindingNameProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_POSIX_PATH_SUBJECT_MAPPING_MUTANT)
  PosixPathProblem -> value <> "<"
#else
  PosixPathProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EXACT_TARGET_PATH_SUBJECT_MAPPING_MUTANT)
  ExactTargetPathProblem -> value <> "<"
#else
  ExactTargetPathProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_CLASS_TAG_SUBJECT_MAPPING_MUTANT)
  ClassTagProblem -> value <> "<"
#else
  ClassTagProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_MODE_TAG_SUBJECT_MAPPING_MUTANT)
  ModeTagProblem -> value <> "<"
#else
  ModeTagProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_OBJECT_ID_SUBJECT_MAPPING_MUTANT)
  ObjectIdProblem -> value <> "<"
#else
  ObjectIdProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_TARGET_TAG_SUBJECT_MAPPING_MUTANT)
  TargetTagProblem -> value <> "<"
#else
  TargetTagProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_TARGET_VALUE_SUBJECT_MAPPING_MUTANT)
  TargetValueProblem -> value <> "<"
#else
  TargetValueProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_USE_TAG_SUBJECT_MAPPING_MUTANT)
  UseTagProblem -> value <> "<"
#else
  UseTagProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_HASKELL_MODE_SUBJECT_MAPPING_MUTANT)
  HaskellModeProblem -> value <> "<"
#else
  HaskellModeProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_CONTENT_MODE_SUBJECT_MAPPING_MUTANT)
  ContentModeProblem -> value <> "<"
#else
  ContentModeProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LEGAL_NAME_SUBJECT_MAPPING_MUTANT)
  LegalNameProblem -> value <> "<"
#else
  LegalNameProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_ROLE_UNBOUND_SUBJECT_MAPPING_MUTANT)
  RoleUnboundProblem -> value <> "<"
#else
  RoleUnboundProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_DUPLICATE_SUBJECT_MAPPING_MUTANT)
  DuplicateProblem -> value <> "<"
#else
  DuplicateProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INVENTORY_ORDER_SUBJECT_MAPPING_MUTANT)
  InventoryOrderProblem -> value <> "<"
#else
  InventoryOrderProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EMPTY_INVENTORY_SUBJECT_MAPPING_MUTANT)
  EmptyInventoryProblem -> value <> "<"
#else
  EmptyInventoryProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EMPTY_HASKELL_SUBJECT_MAPPING_MUTANT)
  EmptyHaskellProblem -> value <> "<"
#else
  EmptyHaskellProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_DYNAMIC_TARGET_SUBJECT_MAPPING_MUTANT)
  DynamicTargetProblem -> value <> "<"
#else
  DynamicTargetProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_UNRESOLVED_EFFECT_SUBJECT_MAPPING_MUTANT)
  UnresolvedEffectProblem -> value <> "<"
#else
  UnresolvedEffectProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EFFECT_TARGET_SUBJECT_MAPPING_MUTANT)
  EffectTargetProblem -> value <> "<"
#else
  EffectTargetProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_DIRECT_BEHAVIOUR_SUBJECT_MAPPING_MUTANT)
  DirectBehaviourProblem -> value <> "<"
#else
  DirectBehaviourProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_UNAUTHORIZED_EFFECT_SUBJECT_MAPPING_MUTANT)
  UnauthorizedEffectProblem -> value <> "<"
#else
  UnauthorizedEffectProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_DIAGNOSTIC_ONLY_SUBJECT_MAPPING_MUTANT)
  DiagnosticOnlyProblem -> value <> "<"
#else
  DiagnosticOnlyProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_SOURCE_BINDING_SUBJECT_MAPPING_MUTANT)
  SourceBindingProblem -> value <> "<"
#else
  SourceBindingProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_COMPILER_RESIDUE_SUBJECT_MAPPING_MUTANT)
  CompilerResidueProblem -> value <> "<"
#else
  CompilerResidueProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_RESOURCE_SUBJECT_MAPPING_MUTANT)
  ResourceProblem -> value <> "<"
#else
  ResourceProblem -> value
#endif

mutateProblemDetail :: DiagnosticProblemKind -> Text -> Text
mutateProblemDetail kind value = case kind of
#if defined(VALIDATION_SOURCE_CONSUMER_SNAPSHOT_IDENTITY_DETAIL_MAPPING_MUTANT)
  SnapshotIdentityProblem -> value <> "<"
#else
  SnapshotIdentityProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EFFECT_MODULE_NAME_DETAIL_MAPPING_MUTANT)
  EffectModuleNameProblem -> value <> "<"
#else
  EffectModuleNameProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EFFECT_BINDING_NAME_DETAIL_MAPPING_MUTANT)
  EffectBindingNameProblem -> value <> "<"
#else
  EffectBindingNameProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_POSIX_PATH_DETAIL_MAPPING_MUTANT)
  PosixPathProblem -> value <> "<"
#else
  PosixPathProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EXACT_TARGET_PATH_DETAIL_MAPPING_MUTANT)
  ExactTargetPathProblem -> value <> "<"
#else
  ExactTargetPathProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_CLASS_TAG_DETAIL_MAPPING_MUTANT)
  ClassTagProblem -> value <> "<"
#else
  ClassTagProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_MODE_TAG_DETAIL_MAPPING_MUTANT)
  ModeTagProblem -> value <> "<"
#else
  ModeTagProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_OBJECT_ID_DETAIL_MAPPING_MUTANT)
  ObjectIdProblem -> value <> "<"
#else
  ObjectIdProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_TARGET_TAG_DETAIL_MAPPING_MUTANT)
  TargetTagProblem -> value <> "<"
#else
  TargetTagProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_TARGET_VALUE_DETAIL_MAPPING_MUTANT)
  TargetValueProblem -> value <> "<"
#else
  TargetValueProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_USE_TAG_DETAIL_MAPPING_MUTANT)
  UseTagProblem -> value <> "<"
#else
  UseTagProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_HASKELL_MODE_DETAIL_MAPPING_MUTANT)
  HaskellModeProblem -> value <> "<"
#else
  HaskellModeProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_CONTENT_MODE_DETAIL_MAPPING_MUTANT)
  ContentModeProblem -> value <> "<"
#else
  ContentModeProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_LEGAL_NAME_DETAIL_MAPPING_MUTANT)
  LegalNameProblem -> value <> "<"
#else
  LegalNameProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_ROLE_UNBOUND_DETAIL_MAPPING_MUTANT)
  RoleUnboundProblem -> value <> "<"
#else
  RoleUnboundProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_DUPLICATE_DETAIL_MAPPING_MUTANT)
  DuplicateProblem -> value <> "<"
#else
  DuplicateProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INVENTORY_ORDER_DETAIL_MAPPING_MUTANT)
  InventoryOrderProblem -> value <> "<"
#else
  InventoryOrderProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EMPTY_INVENTORY_DETAIL_MAPPING_MUTANT)
  EmptyInventoryProblem -> value <> "<"
#else
  EmptyInventoryProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EMPTY_HASKELL_DETAIL_MAPPING_MUTANT)
  EmptyHaskellProblem -> value <> "<"
#else
  EmptyHaskellProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_DYNAMIC_TARGET_DETAIL_MAPPING_MUTANT)
  DynamicTargetProblem -> value <> "<"
#else
  DynamicTargetProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_UNRESOLVED_EFFECT_DETAIL_MAPPING_MUTANT)
  UnresolvedEffectProblem -> value <> "<"
#else
  UnresolvedEffectProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_EFFECT_TARGET_DETAIL_MAPPING_MUTANT)
  EffectTargetProblem -> value <> "<"
#else
  EffectTargetProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_DIRECT_BEHAVIOUR_DETAIL_MAPPING_MUTANT)
  DirectBehaviourProblem -> value <> "<"
#else
  DirectBehaviourProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_UNAUTHORIZED_EFFECT_DETAIL_MAPPING_MUTANT)
  UnauthorizedEffectProblem -> value <> "<"
#else
  UnauthorizedEffectProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_DIAGNOSTIC_ONLY_DETAIL_MAPPING_MUTANT)
  DiagnosticOnlyProblem -> value <> "<"
#else
  DiagnosticOnlyProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_SOURCE_BINDING_DETAIL_MAPPING_MUTANT)
  SourceBindingProblem -> value <> "<"
#else
  SourceBindingProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_COMPILER_RESIDUE_DETAIL_MAPPING_MUTANT)
  CompilerResidueProblem -> value <> "<"
#else
  CompilerResidueProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_RESOURCE_DETAIL_MAPPING_MUTANT)
  ResourceProblem -> value <> "<"
#else
  ResourceProblem -> value
#endif


boundedLength :: Int -> [value] -> Int
boundedLength limit = go 0
 where
  go count _ | count >= limit = count
  go count [] = count
  go count (_ : rest) = go (count + 1) rest

boundedTextLength :: Int -> Text -> Int
boundedTextLength limit = Text.length . Text.take limit

boundedStringUtf8Bytes :: Int -> String -> Int
boundedStringUtf8Bytes limit = go 0
 where
  go count _ | count >= limit = count
  go count [] = count
  go count (character : rest) = go (min limit (count + utf8Width character)) rest

boundedTextUtf8Bytes :: Int -> Text -> Int
boundedTextUtf8Bytes limit = go 0
 where
  go count _ | count >= limit = count
  go count value = case Text.uncons value of
    Nothing -> count
    Just (character, rest) -> go (min limit (count + utf8Width character)) rest

utf8Width :: Char -> Int
utf8Width character
  | scalar <= 0x7F = asciiUtf8Width
  | scalar <= 0x7FF = twoByteUtf8Width
  | scalar <= 0xFFFF = threeByteUtf8Width
  | otherwise = fourByteUtf8Width
 where
  scalar = Char.ord character

asciiUtf8Width, twoByteUtf8Width, threeByteUtf8Width, fourByteUtf8Width :: Int
#if defined(VALIDATION_SOURCE_CONSUMER_UTF8_ASCII_WIDTH_MUTANT)
asciiUtf8Width = 2
#else
asciiUtf8Width = 1
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_UTF8_TWO_BYTE_WIDTH_MUTANT)
twoByteUtf8Width = 1
#else
twoByteUtf8Width = 2
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_UTF8_THREE_BYTE_WIDTH_MUTANT)
threeByteUtf8Width = 2
#else
threeByteUtf8Width = 3
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_UTF8_FOUR_BYTE_WIDTH_MUTANT)
fourByteUtf8Width = 3
#else
fourByteUtf8Width = 4
#endif

decimal :: Int -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_DECIMAL_SERIALIZER_MAPPING_MUTANT)
decimal value = Text.pack (show value) <> "<"
#else
decimal = Text.pack . show
#endif
