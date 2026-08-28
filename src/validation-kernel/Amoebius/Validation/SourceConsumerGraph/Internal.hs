{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.SourceConsumerGraph.Internal
  ( AuthorizedConsumer (..)
  , CompilerGraphResidue
  , ConsumerGraphProblem (..)
  , ContentBinding (..)
  , ContentRole (..)
  , ContentUse (..)
  , HaskellSubject (..)
  , RequiredCompilerFact (..)
  , ResolvedContentEffect (..)
  , ResolvedEffectTarget (..)
  , SourceConsumerGraph
  , analyzeSourceConsumerGraph
  , analyzeSourceConsumerGraphWithResolvedEffects
  , auditResolvedEffects
  , bindingInvariantProblemsDiagnostic
  , consumerGraphBindings
  , consumerGraphProblems
  , consumerGraphResidue
  , consumerGraphSnapshotIdentity
  , contentModeProblemDiagnostic
  , legalNameRefusedDiagnostic
  , makeCompilerGraphResidueDiagnostic
  , makeSourceConsumerGraphDiagnostic
  , problemFindingDiagnostic
  , retainComposedGraphProblemsDiagnostic
  , retainConsumerGraphProblemsDiagnostic
  , residueHaskellSubjects
  , residueRequiredFacts
  , residueSnapshotIdentity
  , roleForAdmittedPath
  , sourceConsumerGraphCheck
  , unboundProblemDiagnostic
  ) where

-- This module intentionally does not scan for suspicious words.  Absence of a
-- token is not evidence that Haskell cannot consume an authored input.  The
-- immutable snapshot supplies the exact content inventory; a future compiler
-- adapter must supply a renamed call/control-flow/effect graph for every exact
-- Haskell blob.  Until then the graph is useful role and negative-effect
-- evidence, but its production check refuses rather than treating silence as
-- source closure.

import Amoebius.Validation.SourceClosure.Internal
  ( ClassifiedPath (..)
  , IndexEntry (..)
  , IndexMode (..)
  , SourceClass (..)
  , SourceSnapshot (..)
  , TrackedEntry (..)
  , classifySnapshot
  , closurePaths
  )
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding
  , Observation
  , finding
  , observation
  )
import Data.List (sort, sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import System.FilePath (takeExtension, takeFileName)

-- | Closed, non-behavioural roles for the inputs admitted by SourceClosure.
-- Registered legacy source and the bounded pb exception are deliberately not
-- members of this universe.
data ContentRole
  = GovernanceDocumentation
  | CabalPackageDescription
  | CabalProjectDescription
  | GitIgnoreContract
  | DockerIgnoreContract
  | GitAttributesContract
  | EditorConfiguration
  deriving (Eq, Ord, Enum, Bounded, Show)

-- | Consumers admitted to observe a non-source input.  This list describes a
-- capability, not evidence that the consumer was invoked.
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
  deriving (Eq, Ord, Enum, Bounded, Show)

data AuthorizedConsumerLocus
  = CommonSourceConsumer
  | GovernanceHumanConsumer
  | GovernanceDocumentationConsumer
  | AmoebiusCabalBuildConsumer
  | AmoebiusCabalRootConsumer
  | ProbeCabalBuildConsumer
  | CabalProjectBuildConsumer
  | CabalProjectRootConsumer
  | GitIgnoreClientConsumer
  | DockerIgnoreBuilderConsumer
  | GitAttributesClientConsumer
  | EditorConfigToolConsumer
  deriving (Eq, Ord, Show)

data ContentBinding = ContentBinding
  { contentPath :: FilePath
  , contentRole :: ContentRole
  , contentAuthorizedConsumers :: [AuthorizedConsumer]
  }
  deriving (Eq, Ord, Show)

-- | Facts which cannot be inferred from an unrenamed source-token stream.
-- Each one must come from the source-bound compiler and be tied to the exact
-- module blobs below.
data RequiredCompilerFact
  = CompilerParseSucceeded
  | ConditionalPreprocessingAbsent
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
  deriving (Eq, Ord, Enum, Bounded, Show)

data HaskellSubject = HaskellSubject
  { haskellSubjectPath :: FilePath
  , haskellSubjectMode :: IndexMode
  , haskellSubjectObjectId :: Text
  }
  deriving (Eq, Ord, Show)

data RequiredFactLocus
  = CompilerParseLocus
  | ConditionalPreprocessingLocus
  | CompileTimeExecutionLocus
  | ImportsRenamedLocus
  | CallsResolvedLocus
  | IndirectCallsLocus
  | ControlFlowLocus
  | FilesystemEffectsLocus
  | ExternalEffectsLocus
  | ProvenanceFlowsLocus
  | ProductSinksLocus
  | DynamicLoadingLocus
  deriving (Eq, Ord, Show)



-- | Precise fail-closed residue.  Snapshot identity binds the whole index;
-- subjects additionally expose every exact Haskell blob that the missing
-- compiler graph must cover.
data CompilerGraphResidue = CompilerGraphResidue
  Text
  [HaskellSubject]
  [RequiredCompilerFact]
  deriving (Eq, Show)

-- Ordinary accessors, not exported record labels.  External code can inspect
-- the residue but cannot use record update to forge different obligations.
residueSnapshotIdentity :: CompilerGraphResidue -> Text
residueSnapshotIdentity (CompilerGraphResidue identity _ _) = retainedResidueIdentity identity

residueHaskellSubjects :: CompilerGraphResidue -> [HaskellSubject]
residueHaskellSubjects (CompilerGraphResidue _ subjects _) = retainedResidueSubjects subjects

residueRequiredFacts :: CompilerGraphResidue -> [RequiredCompilerFact]
residueRequiredFacts (CompilerGraphResidue _ _ facts) = retainedResidueFacts facts

retainedResidueIdentity :: Text -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_RESIDUE_IDENTITY_PROJECTION_MAPPING_MUTANT)
retainedResidueIdentity value = value <> "<"
#else
retainedResidueIdentity value = value
#endif

retainedResidueSubjects :: [HaskellSubject] -> [HaskellSubject]
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_RESIDUE_SUBJECT_CARRIER_DROP_MUTANT)
retainedResidueSubjects _ = []
#else
retainedResidueSubjects value = value
#endif

retainedResidueFacts :: [RequiredCompilerFact] -> [RequiredCompilerFact]
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_RESIDUE_FACT_CARRIER_DROP_MUTANT)
retainedResidueFacts _ = []
#else
retainedResidueFacts value = value
#endif

-- | A negative-only representation of an effect already resolved by a
-- compiler adapter.  Supplying a list of these effects can reveal a defect,
-- but an empty caller-supplied list can never close the compiler residue.
data ResolvedEffectTarget
  = ExactTrackedContent FilePath
  | DynamicContentTarget Text
  | UnresolvedContentTarget Text
  deriving (Eq, Ord, Show)

data ContentUse
  = SourceBoundaryStructureInspection
  | StructuralDocumentationInspection
  | RepositoryRootSentinel
  | ProductBehaviourInput
  deriving (Eq, Ord, Enum, Bounded, Show)

data ResolvedContentEffect = ResolvedContentEffect
  { effectModulePath :: FilePath
  , effectModuleName :: Text
  , effectBindingName :: Text
  , effectTarget :: ResolvedEffectTarget
  , effectUse :: ContentUse
  }
  deriving (Eq, Ord, Show)

data ConsumerGraphProblem
  = DuplicateContentBinding FilePath
  | UnboundAdmittedContent FilePath SourceClass
  | NonRegularAdmittedContent FilePath IndexMode
  | BehaviouralConsumerAuthorized FilePath AuthorizedConsumer
  | EffectTargetIsNotAdmittedContent FilePath
  | DynamicEffectMayReachTrackedContent FilePath Text
  | UnresolvedContentEffect FilePath Text
  | UnauthorizedResolvedContentEffect FilePath FilePath ContentUse Text
  | DirectBehaviouralContentConsumption FilePath FilePath Text
  | EmptyHaskellSubjectInventory
  | CompilerDerivedSemanticGraphUnavailable Text Int [RequiredCompilerFact]
  | ConsumerGraphResourceLimit Text Int Int
  deriving (Eq, Ord, Show)

data DiagnosticProblemKind
  = DuplicateProblem
  | UnboundProblem
  | ContentModeProblem
  | BehaviouralAuthorizationProblem
  | EffectTargetProblem
  | DynamicTargetProblem
  | UnresolvedEffectProblem
  | UnauthorizedEffectProblem
  | DirectBehaviourProblem
  | EmptyHaskellProblem
  | CompilerGraphUnavailableProblem
  | ResourceProblem
  deriving (Eq, Ord, Show)

data DiagnosticObservationKind
  = LimitSnapshotObservation
  | LimitEffectsObservation
  | LimitProblemsObservation
  | LimitResultObservationsObservation
  | LimitResultFindingsObservation
  | SummarySnapshotObservation
  | SummaryBindingCountObservation
  | SummaryHaskellCountObservation
  | BindingObservation
  | SubjectObservation
  deriving (Eq, Ord, Show)

data SourceConsumerGraph = SourceConsumerGraph
  Text
  [ContentBinding]
  CompilerGraphResidue
  [ConsumerGraphProblem]
  deriving (Eq, Show)

makeSourceConsumerGraph
  :: Text
  -> [ContentBinding]
  -> CompilerGraphResidue
  -> [ConsumerGraphProblem]
  -> SourceConsumerGraph
makeSourceConsumerGraph identity bindings residue problems =
  SourceConsumerGraph
    (mappedGraphIdentity identity)
    (mappedGraphBindings bindings)
    (mappedGraphResidue residue)
    (mappedGraphProblems problems)

mappedGraphIdentity :: Text -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_GRAPH_IDENTITY_FIELD_MAPPING_MUTANT)
mappedGraphIdentity value = value <> "<"
#else
mappedGraphIdentity value = value
#endif

mappedGraphBindings :: [ContentBinding] -> [ContentBinding]
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_GRAPH_BINDINGS_FIELD_MAPPING_MUTANT)
mappedGraphBindings = drop 1
#else
mappedGraphBindings value = value
#endif

mappedGraphResidue :: CompilerGraphResidue -> CompilerGraphResidue
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_GRAPH_RESIDUE_FIELD_MAPPING_MUTANT)
mappedGraphResidue (CompilerGraphResidue identity _ facts) = CompilerGraphResidue identity [] facts
#else
mappedGraphResidue value = value
#endif

mappedGraphProblems :: [ConsumerGraphProblem] -> [ConsumerGraphProblem]
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_GRAPH_PROBLEMS_FIELD_MAPPING_MUTANT)
mappedGraphProblems = drop 1
#else
mappedGraphProblems value = value
#endif

makeCompilerGraphResidue
  :: Text
  -> [HaskellSubject]
  -> [RequiredCompilerFact]
  -> CompilerGraphResidue
makeCompilerGraphResidue identity subjects facts =
  CompilerGraphResidue
    (mappedResidueIdentity identity)
    (mappedResidueSubjects subjects)
    (mappedResidueFacts facts)

mappedResidueIdentity :: Text -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_RESIDUE_IDENTITY_FIELD_MAPPING_MUTANT)
mappedResidueIdentity value = value <> "<"
#else
mappedResidueIdentity value = value
#endif

mappedResidueSubjects :: [HaskellSubject] -> [HaskellSubject]
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_RESIDUE_SUBJECTS_FIELD_MAPPING_MUTANT)
mappedResidueSubjects = drop 1
#else
mappedResidueSubjects value = value
#endif

mappedResidueFacts :: [RequiredCompilerFact] -> [RequiredCompilerFact]
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_RESIDUE_FACTS_FIELD_MAPPING_MUTANT)
mappedResidueFacts = drop 1
#else
mappedResidueFacts value = value
#endif

makeHaskellSubject :: FilePath -> IndexMode -> Text -> HaskellSubject
makeHaskellSubject path mode objectId =
  HaskellSubject
    (mappedSubjectPath path)
    (mappedSubjectMode mode)
    (mappedSubjectObjectId objectId)

mappedSubjectPath :: FilePath -> FilePath
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_SUBJECT_PATH_FIELD_MAPPING_MUTANT)
mappedSubjectPath value = value <> "<"
#else
mappedSubjectPath value = value
#endif

mappedSubjectMode :: IndexMode -> IndexMode
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_SUBJECT_MODE_FIELD_MAPPING_MUTANT)
mappedSubjectMode _ = ExecutableFile
#else
mappedSubjectMode value = value
#endif

mappedSubjectObjectId :: Text -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_SUBJECT_OBJECT_FIELD_MAPPING_MUTANT)
mappedSubjectObjectId value = value <> "<"
#else
mappedSubjectObjectId value = value
#endif

makeContentBinding :: FilePath -> ContentRole -> [AuthorizedConsumer] -> ContentBinding
makeContentBinding path role consumers =
  ContentBinding
    (mappedBindingPath path)
    (mappedBindingRole role)
    (mappedBindingConsumers consumers)

mappedBindingPath :: FilePath -> FilePath
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_BINDING_PATH_FIELD_MAPPING_MUTANT)
mappedBindingPath value = value <> "<"
#else
mappedBindingPath value = value
#endif

mappedBindingRole :: ContentRole -> ContentRole
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_BINDING_ROLE_FIELD_MAPPING_MUTANT)
mappedBindingRole GovernanceDocumentation = CabalPackageDescription
mappedBindingRole _ = GovernanceDocumentation
#else
mappedBindingRole value = value
#endif

mappedBindingConsumers :: [AuthorizedConsumer] -> [AuthorizedConsumer]
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_BINDING_CONSUMERS_FIELD_MAPPING_MUTANT)
mappedBindingConsumers = drop 1
#else
mappedBindingConsumers value = value
#endif

maximumSnapshotEntries, maximumResolvedEffects, maximumVariableProblems :: Int
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_SNAPSHOT_LIMIT_WIDEN_MUTANT)
maximumSnapshotEntries = 16385
#else
maximumSnapshotEntries = 16384
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_EFFECT_LIMIT_WIDEN_MUTANT)
maximumResolvedEffects = 65
#else
maximumResolvedEffects = 64
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_PROBLEM_LIMIT_WIDEN_MUTANT)
maximumVariableProblems = 129
#else
maximumVariableProblems = 128
#endif

maximumCheckObservations, maximumCheckFindings :: Int
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_OBSERVATION_LIMIT_NARROW_MUTANT)
maximumCheckObservations = 16391
#else
maximumCheckObservations = 16392
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_FINDING_LIMIT_NARROW_MUTANT)
maximumCheckFindings = 128
#else
maximumCheckFindings = 129
#endif

data BoundedPrefix value
  = PrefixWithin [value]
  | PrefixExceeded Int

boundedPrefix :: Int -> [value] -> BoundedPrefix value
boundedPrefix limit = go 0 []
 where
  go count reversed remaining = case remaining of
    [] -> PrefixWithin (reverse reversed)
    value : rest
      | prefixLimitReached limit count -> PrefixExceeded (prefixExceededObservation limit)
      | otherwise -> go (count + 1) (value : reversed) rest

prefixLimitReached :: Int -> Int -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_BOUNDED_PREFIX_TRANSITION_MUTANT)
prefixLimitReached limit count = count > limit
#else
prefixLimitReached limit count = count == limit
#endif

prefixExceededObservation :: Int -> Int
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_BOUNDED_PREFIX_OBSERVED_MAPPING_MUTANT)
prefixExceededObservation limit = limit + 2
#else
prefixExceededObservation limit = limit + 1
#endif

-- These are deliberately ordinary functions rather than exported record
-- fields.  The abstract graph can be observed but not problem-erased through
-- safe Haskell record update syntax.
consumerGraphSnapshotIdentity :: SourceConsumerGraph -> Text
consumerGraphSnapshotIdentity (SourceConsumerGraph identity _ _ _) = retainedGraphIdentity identity

consumerGraphBindings :: SourceConsumerGraph -> [ContentBinding]
consumerGraphBindings (SourceConsumerGraph _ bindings _ _) = retainedGraphBindings bindings

consumerGraphResidue :: SourceConsumerGraph -> CompilerGraphResidue
consumerGraphResidue (SourceConsumerGraph _ _ residue _) = retainedGraphResidue residue

consumerGraphProblems :: SourceConsumerGraph -> [ConsumerGraphProblem]
consumerGraphProblems (SourceConsumerGraph _ _ _ problems) = retainedGraphProblems problems

retainedGraphIdentity :: Text -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_GRAPH_IDENTITY_PROJECTION_MAPPING_MUTANT)
retainedGraphIdentity value = value <> "<"
#else
retainedGraphIdentity value = value
#endif

retainedGraphBindings :: [ContentBinding] -> [ContentBinding]
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_GRAPH_BINDING_CARRIER_DROP_MUTANT)
retainedGraphBindings _ = []
#else
retainedGraphBindings value = value
#endif

retainedGraphResidue :: CompilerGraphResidue -> CompilerGraphResidue
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_GRAPH_RESIDUE_PROJECTION_MAPPING_MUTANT)
retainedGraphResidue (CompilerGraphResidue identity _ facts) =
  CompilerGraphResidue identity [] facts
#else
retainedGraphResidue value = value
#endif

retainedGraphProblems :: [ConsumerGraphProblem] -> [ConsumerGraphProblem]
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_GRAPH_PROBLEM_CARRIER_DROP_MUTANT)
retainedGraphProblems _ = []
#else
retainedGraphProblems value = value
#endif

-- | Package-hidden construction seam for the independent direct-source
-- diagnostic oracle.  It cannot create candidate authority: the public
-- facade exports neither this constructor nor any Internal module name.
makeCompilerGraphResidueDiagnostic
  :: Text
  -> [HaskellSubject]
  -> [RequiredCompilerFact]
  -> CompilerGraphResidue
makeCompilerGraphResidueDiagnostic = makeCompilerGraphResidue

-- | Package-hidden result-render seam used to exercise otherwise unreachable
-- defensive bounds and every closed problem rendering with one selected
-- production locus at a time.
makeSourceConsumerGraphDiagnostic
  :: Text
  -> [ContentBinding]
  -> CompilerGraphResidue
  -> [ConsumerGraphProblem]
  -> SourceConsumerGraph
makeSourceConsumerGraphDiagnostic = makeSourceConsumerGraph

-- | Assign every SourceClosure-admitted non-Haskell/non-pb path exactly one
-- role and consumer set.  This function never consumes the bytes as product
-- data.  It also emits the compiler-graph residue unconditionally: this module
-- has no GHC renamer/effect adapter and will not fabricate one.
analyzeSourceConsumerGraph :: SourceSnapshot -> SourceConsumerGraph
analyzeSourceConsumerGraph snapshot =
  case boundedPrefix maximumSnapshotEntries (snapshotEntries snapshot) of
    PrefixExceeded observed ->
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_SNAPSHOT_LIMIT_ROUTE_BYPASS_MUTANT)
      boundedSnapshotRefusal snapshot observed `seq` analyzeBoundedSourceConsumerGraph snapshot
#else
      boundedSnapshotRefusal snapshot observed
#endif
    PrefixWithin _ -> analyzeBoundedSourceConsumerGraph snapshot

boundedSnapshotRefusal :: SourceSnapshot -> Int -> SourceConsumerGraph
boundedSnapshotRefusal snapshot observed =
  let residue = makeCompilerGraphResidue (snapshotIdentity snapshot) [] requiredCompilerFacts
   in makeSourceConsumerGraph
        (snapshotIdentity snapshot)
        []
        residue
        ( retainConsumerGraphProblems
            ( makeResourceProblem "snapshot-entries" maximumSnapshotEntries observed
                : retainedSnapshotRefusalEmptyHaskell
            )
            (compilerResidueProblems residue)
        )

retainedSnapshotRefusalEmptyHaskell :: [ConsumerGraphProblem]
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_SNAPSHOT_REFUSAL_EMPTY_HASKELL_DROP_MUTANT)
retainedSnapshotRefusalEmptyHaskell = []
#else
retainedSnapshotRefusalEmptyHaskell = [EmptyHaskellSubjectInventory]
#endif

analyzeBoundedSourceConsumerGraph :: SourceSnapshot -> SourceConsumerGraph
analyzeBoundedSourceConsumerGraph snapshot =
  makeSourceConsumerGraph
    (snapshotIdentity snapshot)
    bindings
    residue
    ( retainConsumerGraphProblems
        ( orderedAnalysisProblems
            ( duplicateProblems
                <> roleProblems
                <> bindingInvariantProblems bindings
                <> subjectProblems subjects
            )
        )
        (compilerResidueProblems residue)
    )
 where
  classified = closurePaths (classifySnapshot snapshot)
  admitted = filter isAdmittedContent classified
  attempted = map bindAdmittedContent admitted
  bindings = orderedBindings (sortOn contentPath [binding | Right binding <- attempted])
  roleProblems = [problem | Left problem <- attempted]
  duplicateProblems =
    retainedDuplicateProblems
      (map makeDuplicateProblem (duplicates (map (entryPath . classifiedEntry) admitted)))
  subjects = orderedSubjects (sortOn haskellSubjectPath (map haskellSubject (filter isHaskellEntry classified)))
  residue =
    makeCompilerGraphResidue
      (snapshotIdentity snapshot)
      subjects
      requiredCompilerFacts

orderedAnalysisProblems :: [ConsumerGraphProblem] -> [ConsumerGraphProblem]
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_ANALYSIS_PROBLEM_ORDER_MUTANT)
orderedAnalysisProblems = reverse
#else
orderedAnalysisProblems value = value
#endif

orderedBindings :: [ContentBinding] -> [ContentBinding]
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_BINDING_ORDER_MUTANT)
orderedBindings = reverse
#else
orderedBindings value = value
#endif

orderedSubjects :: [HaskellSubject] -> [HaskellSubject]
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_SUBJECT_ORDER_MUTANT)
orderedSubjects = reverse
#else
orderedSubjects value = value
#endif

retainedDuplicateProblems :: [ConsumerGraphProblem] -> [ConsumerGraphProblem]
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DUPLICATE_PROBLEM_BYPASS_MUTANT)
retainedDuplicateProblems _ = []
#else
retainedDuplicateProblems value = value
#endif

-- This is deliberately a literal closed enumeration.  Adding, removing, or
-- reordering a compiler obligation requires a production and independent
-- oracle review; deriving the list from Enum/Bounded would let a constructor
-- change silently rewrite the claimed completeness universe.
requiredCompilerFacts :: [RequiredCompilerFact]
requiredCompilerFacts =
  orderedRequiredFacts
    ( concat
        [ retainedRequiredFact CompilerParseLocus (mappedRequiredFact CompilerParseSucceeded)
        , retainedRequiredFact ConditionalPreprocessingLocus (mappedRequiredFact ConditionalPreprocessingAbsent)
        , retainedRequiredFact CompileTimeExecutionLocus (mappedRequiredFact CompileTimeExecutionFeaturesAbsent)
        , retainedRequiredFact ImportsRenamedLocus (mappedRequiredFact ImportsRenamed)
        , retainedRequiredFact CallsResolvedLocus (mappedRequiredFact CallsResolved)
        , retainedRequiredFact IndirectCallsLocus (mappedRequiredFact IndirectCallsClosed)
        , retainedRequiredFact ControlFlowLocus (mappedRequiredFact ControlFlowClosed)
        , retainedRequiredFact FilesystemEffectsLocus (mappedRequiredFact FilesystemEffectsClassified)
        , retainedRequiredFact ExternalEffectsLocus (mappedRequiredFact ExternalProcessAndFfiEffectsClassified)
        , retainedRequiredFact ProvenanceFlowsLocus (mappedRequiredFact TrackedContentProvenanceFlowsClosed)
        , retainedRequiredFact ProductSinksLocus (mappedRequiredFact ProductBehaviourSinksClassified)
        , retainedRequiredFact DynamicLoadingLocus (mappedRequiredFact DynamicCodeAndPluginLoadingAbsent)
        ]
    )

orderedRequiredFacts :: [RequiredCompilerFact] -> [RequiredCompilerFact]
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_REQUIRED_FACT_ORDER_MUTANT)
orderedRequiredFacts = reverse
#else
orderedRequiredFacts value = value
#endif

retainedRequiredFact :: RequiredFactLocus -> RequiredCompilerFact -> [RequiredCompilerFact]
retainedRequiredFact locus fact = case locus of
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPILER_PARSE_FACT_DROP_MUTANT)
  CompilerParseLocus -> []
#else
  CompilerParseLocus -> [fact]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_CONDITIONAL_PREPROCESSING_FACT_DROP_MUTANT)
  ConditionalPreprocessingLocus -> []
#else
  ConditionalPreprocessingLocus -> [fact]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPILE_TIME_EXECUTION_FACT_DROP_MUTANT)
  CompileTimeExecutionLocus -> []
#else
  CompileTimeExecutionLocus -> [fact]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_IMPORTS_RENAMED_FACT_DROP_MUTANT)
  ImportsRenamedLocus -> []
#else
  ImportsRenamedLocus -> [fact]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_CALLS_RESOLVED_FACT_DROP_MUTANT)
  CallsResolvedLocus -> []
#else
  CallsResolvedLocus -> [fact]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_INDIRECT_CALLS_FACT_DROP_MUTANT)
  IndirectCallsLocus -> []
#else
  IndirectCallsLocus -> [fact]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_CONTROL_FLOW_FACT_DROP_MUTANT)
  ControlFlowLocus -> []
#else
  ControlFlowLocus -> [fact]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_FILESYSTEM_EFFECTS_FACT_DROP_MUTANT)
  FilesystemEffectsLocus -> []
#else
  FilesystemEffectsLocus -> [fact]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_EXTERNAL_EFFECTS_FACT_DROP_MUTANT)
  ExternalEffectsLocus -> []
#else
  ExternalEffectsLocus -> [fact]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_PROVENANCE_FLOWS_FACT_DROP_MUTANT)
  ProvenanceFlowsLocus -> []
#else
  ProvenanceFlowsLocus -> [fact]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_PRODUCT_SINKS_FACT_DROP_MUTANT)
  ProductSinksLocus -> []
#else
  ProductSinksLocus -> [fact]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DYNAMIC_LOADING_FACT_DROP_MUTANT)
  DynamicLoadingLocus -> []
#else
  DynamicLoadingLocus -> [fact]
#endif

mappedRequiredFact :: RequiredCompilerFact -> RequiredCompilerFact
mappedRequiredFact fact = case fact of
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPILER_PARSE_FACT_IDENTITY_MAPPING_MUTANT)
  CompilerParseSucceeded -> CallsResolved
#else
  CompilerParseSucceeded -> CompilerParseSucceeded
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_CONDITIONAL_PREPROCESSING_FACT_IDENTITY_MAPPING_MUTANT)
  ConditionalPreprocessingAbsent -> CallsResolved
#else
  ConditionalPreprocessingAbsent -> ConditionalPreprocessingAbsent
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPILE_TIME_EXECUTION_FACT_IDENTITY_MAPPING_MUTANT)
  CompileTimeExecutionFeaturesAbsent -> CallsResolved
#else
  CompileTimeExecutionFeaturesAbsent -> CompileTimeExecutionFeaturesAbsent
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_IMPORTS_RENAMED_FACT_IDENTITY_MAPPING_MUTANT)
  ImportsRenamed -> CallsResolved
#else
  ImportsRenamed -> ImportsRenamed
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_CALLS_RESOLVED_FACT_IDENTITY_MAPPING_MUTANT)
  CallsResolved -> CompilerParseSucceeded
#else
  CallsResolved -> CallsResolved
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_INDIRECT_CALLS_FACT_IDENTITY_MAPPING_MUTANT)
  IndirectCallsClosed -> CallsResolved
#else
  IndirectCallsClosed -> IndirectCallsClosed
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_CONTROL_FLOW_FACT_IDENTITY_MAPPING_MUTANT)
  ControlFlowClosed -> CallsResolved
#else
  ControlFlowClosed -> ControlFlowClosed
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_FILESYSTEM_EFFECTS_FACT_IDENTITY_MAPPING_MUTANT)
  FilesystemEffectsClassified -> CallsResolved
#else
  FilesystemEffectsClassified -> FilesystemEffectsClassified
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_EXTERNAL_EFFECTS_FACT_IDENTITY_MAPPING_MUTANT)
  ExternalProcessAndFfiEffectsClassified -> CallsResolved
#else
  ExternalProcessAndFfiEffectsClassified -> ExternalProcessAndFfiEffectsClassified
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_PROVENANCE_FLOWS_FACT_IDENTITY_MAPPING_MUTANT)
  TrackedContentProvenanceFlowsClosed -> CallsResolved
#else
  TrackedContentProvenanceFlowsClosed -> TrackedContentProvenanceFlowsClosed
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_PRODUCT_SINKS_FACT_IDENTITY_MAPPING_MUTANT)
  ProductBehaviourSinksClassified -> CallsResolved
#else
  ProductBehaviourSinksClassified -> ProductBehaviourSinksClassified
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DYNAMIC_LOADING_FACT_IDENTITY_MAPPING_MUTANT)
  DynamicCodeAndPluginLoadingAbsent -> CallsResolved
#else
  DynamicCodeAndPluginLoadingAbsent -> DynamicCodeAndPluginLoadingAbsent
#endif


-- | Compose already-resolved effects as additional negative evidence.  The
-- compiler residue remains present even when the supplied list is empty or all
-- supplied effects are authorized, so a caller cannot turn a partial report
-- into a closure claim.
analyzeSourceConsumerGraphWithResolvedEffects
  :: SourceSnapshot
  -> [ResolvedContentEffect]
  -> SourceConsumerGraph
analyzeSourceConsumerGraphWithResolvedEffects snapshot effects =
  case analyzeSourceConsumerGraph snapshot of
    SourceConsumerGraph identity bindings residue problems ->
      makeSourceConsumerGraph
        (retainedComposedIdentity identity)
        (retainedComposedBindings bindings)
        (retainedComposedResidue residue)
        ( retainComposedGraphProblems
            ( orderedComposedProblems
                ( retainedComposedBaseProblems problems
                    <> retainedComposedEffectProblems
                      (auditResolvedEffectsAgainstBindings bindings effects)
                )
            )
        )

retainedComposedIdentity :: Text -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPOSED_IDENTITY_MAPPING_MUTANT)
retainedComposedIdentity value = value <> "<"
#else
retainedComposedIdentity value = value
#endif

retainedComposedBindings :: [ContentBinding] -> [ContentBinding]
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPOSED_BINDING_CARRIER_DROP_MUTANT)
retainedComposedBindings _ = []
#else
retainedComposedBindings value = value
#endif

retainedComposedResidue :: CompilerGraphResidue -> CompilerGraphResidue
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPOSED_RESIDUE_MAPPING_MUTANT)
retainedComposedResidue (CompilerGraphResidue identity _ facts) =
  CompilerGraphResidue identity [] facts
#else
retainedComposedResidue value = value
#endif

retainedComposedBaseProblems :: [ConsumerGraphProblem] -> [ConsumerGraphProblem]
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPOSED_BASE_PROBLEM_CARRIER_DROP_MUTANT)
retainedComposedBaseProblems _ = []
#else
retainedComposedBaseProblems value = value
#endif

retainedComposedEffectProblems :: [ConsumerGraphProblem] -> [ConsumerGraphProblem]
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPOSED_EFFECT_PROBLEM_CARRIER_DROP_MUTANT)
retainedComposedEffectProblems _ = []
#else
retainedComposedEffectProblems value = value
#endif

orderedComposedProblems :: [ConsumerGraphProblem] -> [ConsumerGraphProblem]
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPOSED_PROBLEM_ORDER_MUTANT)
orderedComposedProblems = reverse
#else
orderedComposedProblems value = value
#endif

retainConsumerGraphProblems
  :: [ConsumerGraphProblem]
  -> [ConsumerGraphProblem]
  -> [ConsumerGraphProblem]
retainConsumerGraphProblems variable mandatory =
  case boundedPrefix maximumVariableProblems variable of
    PrefixWithin retained -> retained <> mandatory
    PrefixExceeded observed ->
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_PROBLEM_LIMIT_ROUTE_BYPASS_MUTANT)
      observed `seq` (take maximumVariableProblems variable <> mandatory)
#else
      makeResourceProblem "consumer-graph-problems" maximumVariableProblems observed
        : mandatory
#endif

retainConsumerGraphProblemsDiagnostic
  :: [ConsumerGraphProblem]
  -> [ConsumerGraphProblem]
  -> [ConsumerGraphProblem]
retainConsumerGraphProblemsDiagnostic = retainConsumerGraphProblems

retainComposedGraphProblems :: [ConsumerGraphProblem] -> [ConsumerGraphProblem]
retainComposedGraphProblems problems =
  retainConsumerGraphProblems variable mandatory
 where
  mandatory = filter isCompilerResidueProblem problems
  variable = filter (not . isCompilerResidueProblem) problems

retainComposedGraphProblemsDiagnostic
  :: [ConsumerGraphProblem]
  -> [ConsumerGraphProblem]
retainComposedGraphProblemsDiagnostic = retainComposedGraphProblems

isCompilerResidueProblem :: ConsumerGraphProblem -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_MANDATORY_RESIDUE_CLASSIFICATION_BYPASS_MUTANT)
isCompilerResidueProblem _ = False
#else
isCompilerResidueProblem CompilerDerivedSemanticGraphUnavailable {} = True
isCompilerResidueProblem _ = False
#endif

isAdmittedContent :: ClassifiedPath -> Bool
isAdmittedContent item =
  admittedContentRoute
    (admittedDocumentationClass item)
    (admittedProjectClass item)

admittedContentRoute :: Bool -> Bool -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_ADMITTED_CONTENT_ROUTE_BYPASS_MUTANT)
admittedContentRoute documentation project = documentation `seq` project `seq` False
#else
admittedContentRoute documentation project = documentation || project
#endif

admittedDocumentationClass, admittedProjectClass :: ClassifiedPath -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DOCUMENTATION_CLASS_ALTERNATIVE_DROP_MUTANT)
admittedDocumentationClass _ = False
#else
admittedDocumentationClass item = classifiedAs item == DocumentationInput
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_PROJECT_CLASS_ALTERNATIVE_DROP_MUTANT)
admittedProjectClass _ = False
#else
admittedProjectClass item = classifiedAs item == ProjectDeclaration
#endif

-- Do not let a primary legacy or rejection class conceal a tracked Haskell
-- blob from the compiler subject set.  SourceClosure separately rejects an
-- inadmissible .hs path; this graph still requires the compiler to cover it.
isHaskellEntry :: ClassifiedPath -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_HASKELL_EXTENSION_DROP_MUTANT)
isHaskellEntry _ = False
#else
isHaskellEntry item = takeExtension (entryPath (classifiedEntry item)) == ".hs"
#endif

haskellSubject :: ClassifiedPath -> HaskellSubject
haskellSubject item =
  makeHaskellSubject (indexPath entry) (indexMode entry) (indexObjectId entry)
 where
  entry = trackedIndex (classifiedEntry item)

bindAdmittedContent :: ClassifiedPath -> Either ConsumerGraphProblem ContentBinding
bindAdmittedContent item =
  case admittedContentRole sourceClass path of
    Nothing -> Left (makeUnboundProblem path sourceClass)
    Just role
      | not (regularContentMode mode) -> Left (makeContentModeProblem path mode)
      | otherwise ->
          Right
            (makeContentBinding path role (authorizedConsumers path role))
 where
  sourceClass = classifiedAs item
  entry = trackedIndex (classifiedEntry item)
  path = indexPath entry
  mode = indexMode entry

admittedContentRole :: SourceClass -> FilePath -> Maybe ContentRole
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_BIND_ADMITTED_ROLE_ROUTE_BYPASS_MUTANT)
admittedContentRole sourceClass path = roleForAdmittedPath sourceClass path `seq` Nothing
#else
admittedContentRole = roleForAdmittedPath
#endif

-- | Closed role grammar.  It is exported so an independently stated oracle can
-- exercise the deny-by-default boundary without having to forge a
-- ClassifiedPath value.
roleForAdmittedPath :: SourceClass -> FilePath -> Maybe ContentRole
roleForAdmittedPath DocumentationInput path
  | legalNameRefusedDiagnostic path = Nothing
  | documentationSuffixAdmitted path = Just GovernanceDocumentation
  | otherwise = Nothing
roleForAdmittedPath ProjectDeclaration path
  | amoebiusCabalRolePath path || probeCabalRolePath path = Just CabalPackageDescription
  | cabalProjectRolePath path = Just CabalProjectDescription
  | gitIgnoreRolePath path = Just GitIgnoreContract
  | dockerIgnoreRolePath path = Just DockerIgnoreContract
  | gitAttributesRolePath path = Just GitAttributesContract
  | editorConfigRolePath path = Just EditorConfiguration
  | otherwise = Nothing
roleForAdmittedPath _ _ =
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_ROLE_DEFAULT_AUTHORIZATION_MUTANT)
  Just GovernanceDocumentation
#else
  Nothing
#endif

regularContentMode :: IndexMode -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_REGULAR_MODE_BYPASS_MUTANT)
regularContentMode _ = True
#else
regularContentMode value = value == RegularFile
#endif

contentModeProblemDiagnostic
  :: FilePath
  -> IndexMode
  -> (Bool, ConsumerGraphProblem)
contentModeProblemDiagnostic path mode =
  (regularContentMode mode, makeContentModeProblem path mode)

documentationSuffixAdmitted :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DOCUMENTATION_SUFFIX_BYPASS_MUTANT)
documentationSuffixAdmitted _ = True
#else
documentationSuffixAdmitted path = takeExtension path == ".md"
#endif

-- | Package-hidden diagnostic projection of the exact legal-name deny
-- predicate used by 'roleForAdmittedPath'.
legalNameRefusedDiagnostic :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_LEGAL_NAME_REFUSAL_BYPASS_MUTANT)
legalNameRefusedDiagnostic path = ambiguousLegalName path `seq` False
#else
legalNameRefusedDiagnostic = ambiguousLegalName
#endif

amoebiusCabalRolePath, probeCabalRolePath, cabalProjectRolePath :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_AMOEBIUS_CABAL_ROLE_ALTERNATIVE_DROP_MUTANT)
amoebiusCabalRolePath _ = False
#else
amoebiusCabalRolePath path = path == "amoebius.cabal"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_PROBE_CABAL_ROLE_ALTERNATIVE_DROP_MUTANT)
probeCabalRolePath _ = False
#else
probeCabalRolePath path = path == "probe/probe.cabal"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_CABAL_PROJECT_ROLE_ALTERNATIVE_DROP_MUTANT)
cabalProjectRolePath _ = False
#else
cabalProjectRolePath path = path == "cabal.project"
#endif

gitIgnoreRolePath, dockerIgnoreRolePath, gitAttributesRolePath, editorConfigRolePath :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_GITIGNORE_ROLE_ALTERNATIVE_DROP_MUTANT)
gitIgnoreRolePath _ = False
#else
gitIgnoreRolePath path = path == ".gitignore"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DOCKERIGNORE_ROLE_ALTERNATIVE_DROP_MUTANT)
dockerIgnoreRolePath _ = False
#else
dockerIgnoreRolePath path = path == ".dockerignore"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_GITATTRIBUTES_ROLE_ALTERNATIVE_DROP_MUTANT)
gitAttributesRolePath _ = False
#else
gitAttributesRolePath path = path == ".gitattributes"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_EDITORCONFIG_ROLE_ALTERNATIVE_DROP_MUTANT)
editorConfigRolePath _ = False
#else
editorConfigRolePath path = path == ".editorconfig"
#endif

-- Licence/notice prose has no machine-owned semantic role in this graph.  A
-- matching stem is a deny rule only: it cannot become governed documentation
-- merely by changing or appending a suffix.
ambiguousLegalName :: FilePath -> Bool
ambiguousLegalName path =
  licenseStem name || licenceStem name || copyingStem name || noticeStem name
 where
  name = normalizedLegalName (legalFileName path)

legalFileName :: FilePath -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_LEGAL_FILENAME_MAPPING_MUTANT)
legalFileName path = takeFileName path `seq` Text.pack path
#else
legalFileName = Text.pack . takeFileName
#endif

normalizedLegalName :: Text -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_LEGAL_CASE_NORMALIZATION_DROP_MUTANT)
normalizedLegalName value = value
#else
normalizedLegalName = Text.toUpper
#endif

licenseStem, licenceStem, copyingStem, noticeStem :: Text -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_LICENSE_STEM_ALTERNATIVE_DROP_MUTANT)
licenseStem _ = False
#else
licenseStem = legalStemMatches "LICENSE"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_LICENCE_STEM_ALTERNATIVE_DROP_MUTANT)
licenceStem _ = False
#else
licenceStem = legalStemMatches "LICENCE"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_COPYING_STEM_ALTERNATIVE_DROP_MUTANT)
copyingStem _ = False
#else
copyingStem = legalStemMatches "COPYING"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_NOTICE_STEM_ALTERNATIVE_DROP_MUTANT)
noticeStem _ = False
#else
noticeStem = legalStemMatches "NOTICE"
#endif

legalStemMatches :: Text -> Text -> Bool
legalStemMatches stem name = legalExactMatch stem name || legalSuffixMatch stem name

legalExactMatch, legalSuffixMatch :: Text -> Text -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_LEGAL_EXACT_MATCH_ALTERNATIVE_DROP_MUTANT)
legalExactMatch _ _ = False
#else
legalExactMatch stem name = name == stem
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_LEGAL_SUFFIX_MATCH_ALTERNATIVE_DROP_MUTANT)
legalSuffixMatch _ _ = False
#else
legalSuffixMatch stem name = (stem <> ".") `Text.isPrefixOf` name
#endif

authorizedConsumers :: FilePath -> ContentRole -> [AuthorizedConsumer]
authorizedConsumers path role =
  orderedAuthorizedConsumers
    ( sort
        ( retainedAuthorizedConsumer CommonSourceConsumer HaskellSourceBoundaryStructureChecker
            <> roleConsumers
        )
    )
 where
  roleConsumers = case role of
#if defined(VALIDATION_SOURCE_ROLE_BEHAVIORAL_AUTHORIZATION_MUTANT)
    GovernanceDocumentation ->
      [HumanReader, HaskellDocumentationStructureChecker, HaskellProductRuntime]
#else
    GovernanceDocumentation ->
      retainedAuthorizedConsumer GovernanceHumanConsumer HumanReader
        <> retainedAuthorizedConsumer GovernanceDocumentationConsumer HaskellDocumentationStructureChecker
#endif
    CabalPackageDescription
      | amoebiusCabalConsumerPath path ->
          retainedAuthorizedConsumer AmoebiusCabalBuildConsumer CabalBuildTool
            <> retainedAuthorizedConsumer AmoebiusCabalRootConsumer HaskellRepositoryRootLocator
      | otherwise -> retainedAuthorizedConsumer ProbeCabalBuildConsumer CabalBuildTool
    CabalProjectDescription ->
      retainedAuthorizedConsumer CabalProjectBuildConsumer CabalBuildTool
        <> retainedAuthorizedConsumer CabalProjectRootConsumer HaskellRepositoryRootLocator
    GitIgnoreContract -> retainedAuthorizedConsumer GitIgnoreClientConsumer GitClient
    DockerIgnoreContract -> retainedAuthorizedConsumer DockerIgnoreBuilderConsumer ContainerContextBuilder
    GitAttributesContract -> retainedAuthorizedConsumer GitAttributesClientConsumer GitClient
    EditorConfiguration -> retainedAuthorizedConsumer EditorConfigToolConsumer EditorTool

amoebiusCabalConsumerPath :: FilePath -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_AMOEBIUS_CABAL_CONSUMER_ROUTE_MUTANT)
amoebiusCabalConsumerPath path = path == "probe/probe.cabal"
#else
amoebiusCabalConsumerPath path = path == "amoebius.cabal"
#endif

retainedAuthorizedConsumer :: AuthorizedConsumerLocus -> AuthorizedConsumer -> [AuthorizedConsumer]
retainedAuthorizedConsumer locus consumer = case locus of
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_COMMON_SOURCE_CONSUMER_DROP_MUTANT)
  CommonSourceConsumer -> []
#else
  CommonSourceConsumer -> [consumer]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_GOVERNANCE_HUMAN_CONSUMER_DROP_MUTANT)
  GovernanceHumanConsumer -> []
#else
  GovernanceHumanConsumer -> [consumer]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_GOVERNANCE_DOCUMENTATION_CONSUMER_DROP_MUTANT)
  GovernanceDocumentationConsumer -> []
#else
  GovernanceDocumentationConsumer -> [consumer]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_AMOEBIUS_CABAL_BUILD_CONSUMER_DROP_MUTANT)
  AmoebiusCabalBuildConsumer -> []
#else
  AmoebiusCabalBuildConsumer -> [consumer]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_AMOEBIUS_CABAL_ROOT_CONSUMER_DROP_MUTANT)
  AmoebiusCabalRootConsumer -> []
#else
  AmoebiusCabalRootConsumer -> [consumer]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_PROBE_CABAL_BUILD_CONSUMER_DROP_MUTANT)
  ProbeCabalBuildConsumer -> []
#else
  ProbeCabalBuildConsumer -> [consumer]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_CABAL_PROJECT_BUILD_CONSUMER_DROP_MUTANT)
  CabalProjectBuildConsumer -> []
#else
  CabalProjectBuildConsumer -> [consumer]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_CABAL_PROJECT_ROOT_CONSUMER_DROP_MUTANT)
  CabalProjectRootConsumer -> []
#else
  CabalProjectRootConsumer -> [consumer]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_GITIGNORE_CLIENT_CONSUMER_DROP_MUTANT)
  GitIgnoreClientConsumer -> []
#else
  GitIgnoreClientConsumer -> [consumer]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DOCKERIGNORE_BUILDER_CONSUMER_DROP_MUTANT)
  DockerIgnoreBuilderConsumer -> []
#else
  DockerIgnoreBuilderConsumer -> [consumer]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_GITATTRIBUTES_CLIENT_CONSUMER_DROP_MUTANT)
  GitAttributesClientConsumer -> []
#else
  GitAttributesClientConsumer -> [consumer]
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_EDITORCONFIG_TOOL_CONSUMER_DROP_MUTANT)
  EditorConfigToolConsumer -> []
#else
  EditorConfigToolConsumer -> [consumer]
#endif

orderedAuthorizedConsumers :: [AuthorizedConsumer] -> [AuthorizedConsumer]
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_AUTHORIZED_CONSUMER_ORDER_MUTANT)
orderedAuthorizedConsumers = reverse
#else
orderedAuthorizedConsumers value = value
#endif

bindingInvariantProblems :: [ContentBinding] -> [ConsumerGraphProblem]
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_BEHAVIOURAL_INVARIANT_BYPASS_MUTANT)
bindingInvariantProblems _ =
  makeBehaviouralAuthorizationProblem "" HaskellProductRuntime `seq` []
#else
bindingInvariantProblems bindings =
  [ makeBehaviouralAuthorizationProblem (contentPath binding) HaskellProductRuntime
  | binding <- bindings
  , HaskellProductRuntime `elem` contentAuthorizedConsumers binding
  ]
#endif

bindingInvariantProblemsDiagnostic :: [ContentBinding] -> [ConsumerGraphProblem]
bindingInvariantProblemsDiagnostic = bindingInvariantProblems

subjectProblems :: [HaskellSubject] -> [ConsumerGraphProblem]
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_EMPTY_HASKELL_BYPASS_MUTANT)
subjectProblems _ = []
#else
subjectProblems [] = [EmptyHaskellSubjectInventory]
subjectProblems _ = []
#endif

makeDuplicateProblem :: FilePath -> ConsumerGraphProblem
makeDuplicateProblem path = DuplicateContentBinding (mappedDuplicateProblemPath path)

mappedDuplicateProblemPath :: FilePath -> FilePath
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DUPLICATE_PATH_FIELD_MAPPING_MUTANT)
mappedDuplicateProblemPath value = value <> "<"
#else
mappedDuplicateProblemPath value = value
#endif

makeUnboundProblem :: FilePath -> SourceClass -> ConsumerGraphProblem
makeUnboundProblem path sourceClass =
  UnboundAdmittedContent
    (mappedUnboundProblemPath path)
    (mappedUnboundProblemClass sourceClass)

unboundProblemDiagnostic :: FilePath -> SourceClass -> ConsumerGraphProblem
unboundProblemDiagnostic = makeUnboundProblem

mappedUnboundProblemPath :: FilePath -> FilePath
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_UNBOUND_PATH_FIELD_MAPPING_MUTANT)
mappedUnboundProblemPath value = value <> "<"
#else
mappedUnboundProblemPath value = value
#endif

mappedUnboundProblemClass :: SourceClass -> SourceClass
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_UNBOUND_CLASS_FIELD_MAPPING_MUTANT)
mappedUnboundProblemClass DocumentationInput = ProjectDeclaration
mappedUnboundProblemClass _ = DocumentationInput
#else
mappedUnboundProblemClass value = value
#endif

makeContentModeProblem :: FilePath -> IndexMode -> ConsumerGraphProblem
makeContentModeProblem path mode =
  NonRegularAdmittedContent
    (mappedContentModeProblemPath path)
    (mappedContentModeProblemMode mode)

mappedContentModeProblemPath :: FilePath -> FilePath
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_CONTENT_MODE_PATH_FIELD_MAPPING_MUTANT)
mappedContentModeProblemPath value = value <> "<"
#else
mappedContentModeProblemPath value = value
#endif

mappedContentModeProblemMode :: IndexMode -> IndexMode
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_CONTENT_MODE_MODE_FIELD_MAPPING_MUTANT)
mappedContentModeProblemMode RegularFile = ExecutableFile
mappedContentModeProblemMode _ = RegularFile
#else
mappedContentModeProblemMode value = value
#endif

makeBehaviouralAuthorizationProblem
  :: FilePath
  -> AuthorizedConsumer
  -> ConsumerGraphProblem
makeBehaviouralAuthorizationProblem path consumer =
  BehaviouralConsumerAuthorized
    (mappedBehaviouralProblemPath path)
    (mappedBehaviouralProblemConsumer consumer)

mappedBehaviouralProblemPath :: FilePath -> FilePath
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_BEHAVIOURAL_PATH_FIELD_MAPPING_MUTANT)
mappedBehaviouralProblemPath value = value <> "<"
#else
mappedBehaviouralProblemPath value = value
#endif

mappedBehaviouralProblemConsumer :: AuthorizedConsumer -> AuthorizedConsumer
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_BEHAVIOURAL_CONSUMER_FIELD_MAPPING_MUTANT)
mappedBehaviouralProblemConsumer HaskellProductRuntime = HumanReader
mappedBehaviouralProblemConsumer _ = HaskellProductRuntime
#else
mappedBehaviouralProblemConsumer value = value
#endif

makeEffectTargetProblem :: FilePath -> ConsumerGraphProblem
makeEffectTargetProblem path =
  EffectTargetIsNotAdmittedContent (mappedEffectTargetProblemPath path)

mappedEffectTargetProblemPath :: FilePath -> FilePath
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_EFFECT_TARGET_PATH_FIELD_MAPPING_MUTANT)
mappedEffectTargetProblemPath value = value <> "<"
#else
mappedEffectTargetProblemPath value = value
#endif

makeDynamicProblem :: FilePath -> Text -> ConsumerGraphProblem
makeDynamicProblem modulePath detail =
  DynamicEffectMayReachTrackedContent
    (mappedDynamicProblemModulePath modulePath)
    (mappedDynamicProblemDetail detail)

mappedDynamicProblemModulePath :: FilePath -> FilePath
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DYNAMIC_MODULE_PATH_FIELD_MAPPING_MUTANT)
mappedDynamicProblemModulePath value = value <> "<"
#else
mappedDynamicProblemModulePath value = value
#endif

mappedDynamicProblemDetail :: Text -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DYNAMIC_DETAIL_FIELD_MAPPING_MUTANT)
mappedDynamicProblemDetail value = value <> "<"
#else
mappedDynamicProblemDetail value = value
#endif

makeUnresolvedProblem :: FilePath -> Text -> ConsumerGraphProblem
makeUnresolvedProblem modulePath detail =
  UnresolvedContentEffect
    (mappedUnresolvedProblemModulePath modulePath)
    (mappedUnresolvedProblemDetail detail)

mappedUnresolvedProblemModulePath :: FilePath -> FilePath
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_UNRESOLVED_MODULE_PATH_FIELD_MAPPING_MUTANT)
mappedUnresolvedProblemModulePath value = value <> "<"
#else
mappedUnresolvedProblemModulePath value = value
#endif

mappedUnresolvedProblemDetail :: Text -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_UNRESOLVED_DETAIL_FIELD_MAPPING_MUTANT)
mappedUnresolvedProblemDetail value = value <> "<"
#else
mappedUnresolvedProblemDetail value = value
#endif

makeUnauthorizedProblem
  :: FilePath
  -> FilePath
  -> ContentUse
  -> Text
  -> ConsumerGraphProblem
makeUnauthorizedProblem modulePath path use name =
  UnauthorizedResolvedContentEffect
    (mappedUnauthorizedProblemModulePath modulePath)
    (mappedUnauthorizedProblemPath path)
    (mappedUnauthorizedProblemUse use)
    (mappedUnauthorizedProblemName name)

mappedUnauthorizedProblemModulePath :: FilePath -> FilePath
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_UNAUTHORIZED_MODULE_PATH_FIELD_MAPPING_MUTANT)
mappedUnauthorizedProblemModulePath value = value <> "<"
#else
mappedUnauthorizedProblemModulePath value = value
#endif

mappedUnauthorizedProblemPath :: FilePath -> FilePath
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_UNAUTHORIZED_TARGET_PATH_FIELD_MAPPING_MUTANT)
mappedUnauthorizedProblemPath value = value <> "<"
#else
mappedUnauthorizedProblemPath value = value
#endif

mappedUnauthorizedProblemUse :: ContentUse -> ContentUse
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_UNAUTHORIZED_USE_FIELD_MAPPING_MUTANT)
mappedUnauthorizedProblemUse SourceBoundaryStructureInspection = StructuralDocumentationInspection
mappedUnauthorizedProblemUse _ = SourceBoundaryStructureInspection
#else
mappedUnauthorizedProblemUse value = value
#endif

mappedUnauthorizedProblemName :: Text -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_UNAUTHORIZED_NAME_FIELD_MAPPING_MUTANT)
mappedUnauthorizedProblemName value = value <> "<"
#else
mappedUnauthorizedProblemName value = value
#endif

makeDirectBehaviourProblem :: FilePath -> FilePath -> Text -> ConsumerGraphProblem
makeDirectBehaviourProblem modulePath path name =
  DirectBehaviouralContentConsumption
    (mappedDirectProblemModulePath modulePath)
    (mappedDirectProblemPath path)
    (mappedDirectProblemName name)

mappedDirectProblemModulePath :: FilePath -> FilePath
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DIRECT_MODULE_PATH_FIELD_MAPPING_MUTANT)
mappedDirectProblemModulePath value = value <> "<"
#else
mappedDirectProblemModulePath value = value
#endif

mappedDirectProblemPath :: FilePath -> FilePath
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DIRECT_PATH_FIELD_MAPPING_MUTANT)
mappedDirectProblemPath value = value <> "<"
#else
mappedDirectProblemPath value = value
#endif

mappedDirectProblemName :: Text -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DIRECT_NAME_FIELD_MAPPING_MUTANT)
mappedDirectProblemName value = value <> "<"
#else
mappedDirectProblemName value = value
#endif

makeCompilerGraphUnavailableProblem
  :: Text
  -> Int
  -> [RequiredCompilerFact]
  -> ConsumerGraphProblem
makeCompilerGraphUnavailableProblem identity count facts =
  CompilerDerivedSemanticGraphUnavailable
    (mappedCompilerProblemIdentityField identity)
    (mappedCompilerProblemCountField count)
    (mappedCompilerProblemFactsField facts)

mappedCompilerProblemIdentityField :: Text -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPILER_IDENTITY_FIELD_MAPPING_MUTANT)
mappedCompilerProblemIdentityField value = value <> "<"
#else
mappedCompilerProblemIdentityField value = value
#endif

mappedCompilerProblemCountField :: Int -> Int
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPILER_COUNT_FIELD_MAPPING_MUTANT)
mappedCompilerProblemCountField value = value + 1
#else
mappedCompilerProblemCountField value = value
#endif

mappedCompilerProblemFactsField :: [RequiredCompilerFact] -> [RequiredCompilerFact]
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPILER_FACTS_FIELD_MAPPING_MUTANT)
mappedCompilerProblemFactsField = drop 1
#else
mappedCompilerProblemFactsField value = value
#endif

makeResourceProblem :: Text -> Int -> Int -> ConsumerGraphProblem
makeResourceProblem resource limit observed =
  ConsumerGraphResourceLimit
    (mappedResourceProblemResourceField resource)
    (mappedResourceProblemLimitField limit)
    (mappedResourceProblemObservedField observed)

mappedResourceProblemResourceField :: Text -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_RESOURCE_NAME_FIELD_MAPPING_MUTANT)
mappedResourceProblemResourceField value = value <> "<"
#else
mappedResourceProblemResourceField value = value
#endif

mappedResourceProblemLimitField :: Int -> Int
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_RESOURCE_LIMIT_FIELD_MAPPING_MUTANT)
mappedResourceProblemLimitField value = value + 1
#else
mappedResourceProblemLimitField value = value
#endif

mappedResourceProblemObservedField :: Int -> Int
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_RESOURCE_OBSERVED_FIELD_MAPPING_MUTANT)
mappedResourceProblemObservedField value = value + 1
#else
mappedResourceProblemObservedField value = value
#endif

compilerResidueProblems :: CompilerGraphResidue -> [ConsumerGraphProblem]
#if defined(VALIDATION_SOURCE_CONSUMER_COMPILER_RESIDUE_BYPASS_MUTANT)
compilerResidueProblems residue =
  makeCompilerGraphUnavailableProblem
    (residueSnapshotIdentity residue)
    (length (residueHaskellSubjects residue))
    (residueRequiredFacts residue)
    `seq` []
#else
compilerResidueProblems residue =
  [ makeCompilerGraphUnavailableProblem
      (residueSnapshotIdentity residue)
      (length (residueHaskellSubjects residue))
      (residueRequiredFacts residue)
  ]
#endif

-- | Check effects which a future compiler adapter has already resolved.  This
-- is deliberately negative-only: it can reject a supplied effect, but its
-- result is never used to infer that omitted effects do not exist.
auditResolvedEffects
  :: SourceSnapshot
  -> [ResolvedContentEffect]
  -> [ConsumerGraphProblem]
auditResolvedEffects snapshot effects =
  case boundedPrefix maximumResolvedEffects effects of
    PrefixExceeded observed ->
      effectLimitRefusal observed
    PrefixWithin retained -> auditBoundedResolvedEffectsAgainstBindings bindings retained
 where
  graph = analyzeSourceConsumerGraph snapshot
  bindings = consumerGraphBindings graph

auditResolvedEffectsAgainstBindings
  :: [ContentBinding]
  -> [ResolvedContentEffect]
  -> [ConsumerGraphProblem]
auditResolvedEffectsAgainstBindings bindings effects =
  case boundedPrefix maximumResolvedEffects effects of
    PrefixExceeded observed ->
      effectLimitRefusal observed
    PrefixWithin retained -> auditBoundedResolvedEffectsAgainstBindings bindings retained

effectLimitRefusal :: Int -> [ConsumerGraphProblem]
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_EFFECT_LIMIT_ROUTE_BYPASS_MUTANT)
effectLimitRefusal _ = []
#else
effectLimitRefusal observed =
  [makeResourceProblem "resolved-effects" maximumResolvedEffects observed]
#endif

auditBoundedResolvedEffectsAgainstBindings
  :: [ContentBinding]
  -> [ResolvedContentEffect]
  -> [ConsumerGraphProblem]
auditBoundedResolvedEffectsAgainstBindings bindings effects =
  retainConsumerGraphProblems
    (orderedAuditProblems (concatMap (auditOne bindingsByPath) effects))
    []
 where
  bindingsByPath =
    Map.fromList [(contentPath binding, binding) | binding <- bindings]

orderedAuditProblems :: [ConsumerGraphProblem] -> [ConsumerGraphProblem]
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_AUDIT_PROBLEM_ORDER_MUTANT)
orderedAuditProblems = reverse
#else
orderedAuditProblems value = value
#endif

auditOne
  :: Map FilePath ContentBinding
  -> ResolvedContentEffect
  -> [ConsumerGraphProblem]
auditOne bindingsByPath effect = case effectTarget effect of
  ExactTrackedContent path -> case Map.lookup path bindingsByPath of
    Nothing ->
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_EXACT_TARGET_PROBLEM_BYPASS_MUTANT)
      makeEffectTargetProblem path `seq` []
#else
      [makeEffectTargetProblem path]
#endif
    Just binding -> auditExact binding effect
  DynamicContentTarget detail -> dynamicProblems detail
  UnresolvedContentTarget detail ->
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_UNRESOLVED_TARGET_BYPASS_MUTANT)
    makeUnresolvedProblem (effectModulePath effect) detail `seq` []
#else
    [makeUnresolvedProblem (effectModulePath effect) detail]
#endif
 where
#if defined(VALIDATION_SOURCE_CONSUMER_DYNAMIC_TARGET_BYPASS_MUTANT)
  dynamicProblems detail =
    makeDynamicProblem (effectModulePath effect) detail `seq` []
#else
  dynamicProblems detail =
    [makeDynamicProblem (effectModulePath effect) detail]
#endif

auditExact :: ContentBinding -> ResolvedContentEffect -> [ConsumerGraphProblem]
auditExact binding effect = case effectUse effect of
#if defined(VALIDATION_SOURCE_DIRECT_BEHAVIORAL_EFFECT_BYPASS_MUTANT)
  ProductBehaviourInput ->
    makeDirectBehaviourProblem
      (effectModulePath effect)
      (contentPath binding)
      (resolvedEffectName effect)
      `seq` []
#else
  ProductBehaviourInput ->
    [ makeDirectBehaviourProblem
        (effectModulePath effect)
        (contentPath binding)
        (resolvedEffectName effect)
    ]
#endif
  SourceBoundaryStructureInspection
    | isSourceBoundaryReader effect -> retainedSourceBoundaryAcceptance binding effect
    | otherwise -> [unauthorized binding effect]
  StructuralDocumentationInspection
    | documentationBindingRoleAdmitted binding
        && isDocumentationReader effect -> retainedDocumentationAcceptance binding effect
    | otherwise -> [unauthorized binding effect]
  RepositoryRootSentinel
    | repositoryRootBindingAdmitted binding
        && isRepositoryRootLocator effect -> retainedRootAcceptance binding effect
    | otherwise -> [unauthorized binding effect]

retainedSourceBoundaryAcceptance
  :: ContentBinding
  -> ResolvedContentEffect
  -> [ConsumerGraphProblem]
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_SOURCE_BOUNDARY_ACCEPTANCE_REFUSAL_MUTANT)
retainedSourceBoundaryAcceptance binding effect = [unauthorized binding effect]
#else
retainedSourceBoundaryAcceptance _ _ = []
#endif

retainedDocumentationAcceptance
  :: ContentBinding
  -> ResolvedContentEffect
  -> [ConsumerGraphProblem]
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DOCUMENTATION_ACCEPTANCE_REFUSAL_MUTANT)
retainedDocumentationAcceptance binding effect = [unauthorized binding effect]
#else
retainedDocumentationAcceptance _ _ = []
#endif

retainedRootAcceptance
  :: ContentBinding
  -> ResolvedContentEffect
  -> [ConsumerGraphProblem]
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_ROOT_ACCEPTANCE_REFUSAL_MUTANT)
retainedRootAcceptance binding effect = [unauthorized binding effect]
#else
retainedRootAcceptance _ _ = []
#endif

isDocumentationReader :: ResolvedContentEffect -> Bool
isDocumentationReader effect =
  documentationReaderPathMatches effect
    && documentationReaderModuleMatches effect
    && documentationReaderBindingMatches effect

isSourceBoundaryReader :: ResolvedContentEffect -> Bool
isSourceBoundaryReader effect =
  sourceReaderPathMatches effect
    && sourceReaderModuleMatches effect
    && sourceReaderBindingMatches effect

isRepositoryRootLocator :: ResolvedContentEffect -> Bool
isRepositoryRootLocator effect =
  rootReaderPathMatches effect
    && rootReaderModuleMatches effect
    && rootReaderBindingMatches effect

documentationReaderPathMatches, documentationReaderModuleMatches, documentationReaderBindingMatches :: ResolvedContentEffect -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DOCUMENTATION_READER_PATH_CONJUNCT_BYPASS_MUTANT)
documentationReaderPathMatches _ = True
#else
documentationReaderPathMatches effect = effectModulePath effect == "src/validation-kernel/Amoebius/Validation/Documentation.hs"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DOCUMENTATION_READER_MODULE_CONJUNCT_BYPASS_MUTANT)
documentationReaderModuleMatches _ = True
#else
documentationReaderModuleMatches effect = effectModuleName effect == "Amoebius.Validation.Documentation"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DOCUMENTATION_READER_BINDING_CONJUNCT_BYPASS_MUTANT)
documentationReaderBindingMatches _ = True
#else
documentationReaderBindingMatches effect = effectBindingName effect == "readDocument"
#endif

sourceReaderPathMatches, sourceReaderModuleMatches, sourceReaderBindingMatches :: ResolvedContentEffect -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_SOURCE_READER_PATH_CONJUNCT_BYPASS_MUTANT)
sourceReaderPathMatches _ = True
#else
sourceReaderPathMatches effect = effectModulePath effect == "src/validation-kernel/Amoebius/Validation/SourceClosure/Internal.hs"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_SOURCE_READER_MODULE_CONJUNCT_BYPASS_MUTANT)
sourceReaderModuleMatches _ = True
#else
sourceReaderModuleMatches effect = effectModuleName effect == "Amoebius.Validation.SourceClosure.Internal"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_SOURCE_READER_BINDING_CONJUNCT_BYPASS_MUTANT)
sourceReaderBindingMatches _ = True
#else
sourceReaderBindingMatches effect = effectBindingName effect == "classifyEntry"
#endif

rootReaderPathMatches, rootReaderModuleMatches, rootReaderBindingMatches :: ResolvedContentEffect -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_ROOT_READER_PATH_CONJUNCT_BYPASS_MUTANT)
rootReaderPathMatches _ = True
#else
rootReaderPathMatches effect = effectModulePath effect == "src/validation-kernel/Amoebius/Validation/Dispatch.hs"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_ROOT_READER_MODULE_CONJUNCT_BYPASS_MUTANT)
rootReaderModuleMatches _ = True
#else
rootReaderModuleMatches effect = effectModuleName effect == "Amoebius.Validation.Dispatch"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_ROOT_READER_BINDING_CONJUNCT_BYPASS_MUTANT)
rootReaderBindingMatches _ = True
#else
rootReaderBindingMatches effect = effectBindingName effect == "discoverRepositoryRoot"
#endif

documentationBindingRoleAdmitted :: ContentBinding -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DOCUMENTATION_BINDING_ROLE_CONJUNCT_BYPASS_MUTANT)
documentationBindingRoleAdmitted _ = True
#else
documentationBindingRoleAdmitted binding = contentRole binding == GovernanceDocumentation
#endif

repositoryRootBindingAdmitted :: ContentBinding -> Bool
repositoryRootBindingAdmitted binding =
  amoebiusRootBindingPath binding || cabalProjectRootBindingPath binding

amoebiusRootBindingPath, cabalProjectRootBindingPath :: ContentBinding -> Bool
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_AMOEBIUS_ROOT_PATH_ALTERNATIVE_DROP_MUTANT)
amoebiusRootBindingPath _ = False
#else
amoebiusRootBindingPath binding = contentPath binding == "amoebius.cabal"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_CABAL_PROJECT_ROOT_PATH_ALTERNATIVE_DROP_MUTANT)
cabalProjectRootBindingPath _ = False
#else
cabalProjectRootBindingPath binding = contentPath binding == "cabal.project"
#endif

unauthorized :: ContentBinding -> ResolvedContentEffect -> ConsumerGraphProblem
unauthorized binding effect =
  makeUnauthorizedProblem
    (effectModulePath effect)
    (contentPath binding)
    (effectUse effect)
    (resolvedEffectName effect)

resolvedEffectName :: ResolvedContentEffect -> Text
resolvedEffectName effect =
  resolvedEffectNameModule effect
    <> resolvedEffectNameSeparator
    <> resolvedEffectNameBinding effect

resolvedEffectNameModule, resolvedEffectNameBinding :: ResolvedContentEffect -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_RESOLVED_EFFECT_NAME_MODULE_MAPPING_MUTANT)
resolvedEffectNameModule effect = effectModuleName effect <> "<"
#else
resolvedEffectNameModule = effectModuleName
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_RESOLVED_EFFECT_NAME_BINDING_MAPPING_MUTANT)
resolvedEffectNameBinding effect = effectBindingName effect <> "<"
#else
resolvedEffectNameBinding = effectBindingName
#endif

resolvedEffectNameSeparator :: Text
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_RESOLVED_EFFECT_NAME_SEPARATOR_MAPPING_MUTANT)
resolvedEffectNameSeparator = "<"
#else
resolvedEffectNameSeparator = "."
#endif

sourceConsumerGraphCheck :: SourceConsumerGraph -> CheckResult
sourceConsumerGraphCheck graph =
  let summary = graphSummaryObservations graph
      candidateObservations =
        summary
          <> orderedDetailObservations
            (concatMap bindingObservation (consumerGraphBindings graph))
            (concatMap subjectObservation (residueHaskellSubjects (consumerGraphResidue graph)))
      observationProblems = case boundedPrefix maximumCheckObservations candidateObservations of
        PrefixWithin _ -> []
        PrefixExceeded observed ->
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_OBSERVATION_LIMIT_ROUTE_BYPASS_MUTANT)
          observed `seq` []
#else
          [makeResourceProblem "result-observations" maximumCheckObservations observed]
#endif
      retainedObservations
        | null observationProblems = candidateObservations
        | otherwise = summary
      candidateProblems =
        orderedResultProblemComposition
          (consumerGraphProblems graph <> observationProblems)
      retainedProblems = boundCheckProblems candidateProblems
   in CheckResult
        { checkName = internalCheckName
        , checkObservations = retainResultObservations retainedObservations
        , checkFindings = retainResultFindings (map problemFinding retainedProblems)
        }

orderedDetailObservations :: [Observation] -> [Observation] -> [Observation]
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DETAIL_OBSERVATION_COMPOSITION_ORDER_MUTANT)
orderedDetailObservations bindings subjects = subjects <> bindings
#else
orderedDetailObservations bindings subjects = bindings <> subjects
#endif

orderedResultProblemComposition :: [ConsumerGraphProblem] -> [ConsumerGraphProblem]
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_RESULT_PROBLEM_COMPOSITION_ORDER_MUTANT)
orderedResultProblemComposition = reverse
#else
orderedResultProblemComposition value = value
#endif

internalCheckName :: Text
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_RESULT_NAME_MAPPING_MUTANT)
internalCheckName = "source-consumer-graph<"
#else
internalCheckName = "source-consumer-graph"
#endif

retainResultObservations :: [Observation] -> [Observation]
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_RESULT_OBSERVATION_CARRIER_DROP_MUTANT)
retainResultObservations _ = []
#elif defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_RESULT_OBSERVATION_ORDER_MUTANT)
retainResultObservations = reverse
#else
retainResultObservations = id
#endif

retainResultFindings :: [Finding] -> [Finding]
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_RESULT_FINDING_CARRIER_DROP_MUTANT)
retainResultFindings _ = []
#elif defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_RESULT_FINDING_ORDER_MUTANT)
retainResultFindings = reverse
#else
retainResultFindings = id
#endif

graphSummaryObservations :: SourceConsumerGraph -> [Observation]
graphSummaryObservations graph =
  orderedSummaryObservations
    ( diagnosticObservation LimitSnapshotObservation "limit.snapshot-entries" (Text.pack (show maximumSnapshotEntries))
        <> diagnosticObservation LimitEffectsObservation "limit.resolved-effects" (Text.pack (show maximumResolvedEffects))
        <> diagnosticObservation LimitProblemsObservation "limit.consumer-graph-problems" (Text.pack (show maximumVariableProblems))
        <> diagnosticObservation LimitResultObservationsObservation "limit.result-observations" (Text.pack (show maximumCheckObservations))
        <> diagnosticObservation LimitResultFindingsObservation "limit.result-findings" (Text.pack (show maximumCheckFindings))
        <> diagnosticObservation SummarySnapshotObservation "source-consumer.snapshot" (consumerGraphSnapshotIdentity graph)
        <> diagnosticObservation SummaryBindingCountObservation "source-consumer.binding-count" (Text.pack (show (length (consumerGraphBindings graph))))
        <> diagnosticObservation SummaryHaskellCountObservation "source-consumer.pending-haskell-count" (Text.pack (show (length (residueHaskellSubjects (consumerGraphResidue graph)))))
    )

orderedSummaryObservations :: [Observation] -> [Observation]
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_SUMMARY_OBSERVATION_ORDER_MUTANT)
orderedSummaryObservations = reverse
#else
orderedSummaryObservations value = value
#endif

boundCheckProblems :: [ConsumerGraphProblem] -> [ConsumerGraphProblem]
boundCheckProblems problems = case boundedPrefix maximumCheckFindings problems of
  PrefixWithin retained -> retained
  PrefixExceeded observed ->
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_FINDING_LIMIT_ROUTE_BYPASS_MUTANT)
    observed `seq` take maximumCheckFindings problems
#else
    makeResourceProblem "result-findings" maximumCheckFindings observed
      : filter isCompilerResidueProblem problems
#endif

bindingObservation :: ContentBinding -> [Observation]
bindingObservation binding =
  diagnosticObservation BindingObservation
    (bindingObservationPrefix <> bindingObservationPath binding)
    ( bindingObservationRole binding
        <> bindingObservationSeparator
        <> Text.intercalate bindingConsumerSeparator (map renderConsumer (contentAuthorizedConsumers binding))
    )

subjectObservation :: HaskellSubject -> [Observation]
subjectObservation subject =
  diagnosticObservation SubjectObservation
    (subjectObservationPrefix <> subjectObservationPath subject)
    ( subjectObservationMode subject
        <> subjectObservationSeparator
        <> subjectObservationObject subject
    )

bindingObservationPrefix :: Text
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_BINDING_OBSERVATION_PREFIX_MAPPING_MUTANT)
bindingObservationPrefix = "source-consumer.binding.<"
#else
bindingObservationPrefix = "source-consumer.binding."
#endif

bindingObservationPath :: ContentBinding -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_BINDING_OBSERVATION_PATH_MAPPING_MUTANT)
bindingObservationPath binding = Text.pack (contentPath binding) <> "<"
#else
bindingObservationPath = Text.pack . contentPath
#endif

bindingObservationRole :: ContentBinding -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_BINDING_OBSERVATION_ROLE_MAPPING_MUTANT)
bindingObservationRole binding = renderRole (contentRole binding) <> "<"
#else
bindingObservationRole = renderRole . contentRole
#endif

bindingObservationSeparator, bindingConsumerSeparator :: Text
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_BINDING_OBSERVATION_SEPARATOR_MAPPING_MUTANT)
bindingObservationSeparator = "<"
#else
bindingObservationSeparator = "\t"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_BINDING_CONSUMER_SEPARATOR_MAPPING_MUTANT)
bindingConsumerSeparator = "<"
#else
bindingConsumerSeparator = ","
#endif

subjectObservationPrefix :: Text
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_SUBJECT_OBSERVATION_PREFIX_MAPPING_MUTANT)
subjectObservationPrefix = "source-consumer.pending-haskell.<"
#else
subjectObservationPrefix = "source-consumer.pending-haskell."
#endif

subjectObservationPath :: HaskellSubject -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_SUBJECT_OBSERVATION_PATH_MAPPING_MUTANT)
subjectObservationPath subject = Text.pack (haskellSubjectPath subject) <> "<"
#else
subjectObservationPath = Text.pack . haskellSubjectPath
#endif

subjectObservationMode :: HaskellSubject -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_SUBJECT_OBSERVATION_MODE_MAPPING_MUTANT)
subjectObservationMode subject = renderMode (haskellSubjectMode subject) <> "<"
#else
subjectObservationMode = renderMode . haskellSubjectMode
#endif

subjectObservationObject :: HaskellSubject -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_SUBJECT_OBSERVATION_OBJECT_MAPPING_MUTANT)
subjectObservationObject subject = haskellSubjectObjectId subject <> "<"
#else
subjectObservationObject = haskellSubjectObjectId
#endif

subjectObservationSeparator :: Text
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_SUBJECT_OBSERVATION_SEPARATOR_MAPPING_MUTANT)
subjectObservationSeparator = "<"
#else
subjectObservationSeparator = "\t"
#endif

diagnosticObservation :: DiagnosticObservationKind -> Text -> Text -> [Observation]
diagnosticObservation kind key value
  | observationDropped kind = []
  | otherwise = [observation (mutateObservationKey kind key) (mutateObservationValue kind value)]

mutateObservationKey :: DiagnosticObservationKind -> Text -> Text
mutateObservationKey kind value = case kind of
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_LIMIT_SNAPSHOT_OBSERVATION_KEY_MUTANT)
  LimitSnapshotObservation -> value <> "<"
#else
  LimitSnapshotObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_LIMIT_EFFECTS_OBSERVATION_KEY_MUTANT)
  LimitEffectsObservation -> value <> "<"
#else
  LimitEffectsObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_LIMIT_PROBLEMS_OBSERVATION_KEY_MUTANT)
  LimitProblemsObservation -> value <> "<"
#else
  LimitProblemsObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_LIMIT_RESULT_OBSERVATIONS_OBSERVATION_KEY_MUTANT)
  LimitResultObservationsObservation -> value <> "<"
#else
  LimitResultObservationsObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_LIMIT_RESULT_FINDINGS_OBSERVATION_KEY_MUTANT)
  LimitResultFindingsObservation -> value <> "<"
#else
  LimitResultFindingsObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_SUMMARY_SNAPSHOT_OBSERVATION_KEY_MUTANT)
  SummarySnapshotObservation -> value <> "<"
#else
  SummarySnapshotObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_SUMMARY_BINDING_COUNT_OBSERVATION_KEY_MUTANT)
  SummaryBindingCountObservation -> value <> "<"
#else
  SummaryBindingCountObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_SUMMARY_HASKELL_COUNT_OBSERVATION_KEY_MUTANT)
  SummaryHaskellCountObservation -> value <> "<"
#else
  SummaryHaskellCountObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_BINDING_OBSERVATION_KEY_MUTANT)
  BindingObservation -> value <> "<"
#else
  BindingObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_SUBJECT_OBSERVATION_KEY_MUTANT)
  SubjectObservation -> value <> "<"
#else
  SubjectObservation -> value
#endif

mutateObservationValue :: DiagnosticObservationKind -> Text -> Text
mutateObservationValue kind value = case kind of
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_LIMIT_SNAPSHOT_OBSERVATION_VALUE_MUTANT)
  LimitSnapshotObservation -> value <> "<"
#else
  LimitSnapshotObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_LIMIT_EFFECTS_OBSERVATION_VALUE_MUTANT)
  LimitEffectsObservation -> value <> "<"
#else
  LimitEffectsObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_LIMIT_PROBLEMS_OBSERVATION_VALUE_MUTANT)
  LimitProblemsObservation -> value <> "<"
#else
  LimitProblemsObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_LIMIT_RESULT_OBSERVATIONS_OBSERVATION_VALUE_MUTANT)
  LimitResultObservationsObservation -> value <> "<"
#else
  LimitResultObservationsObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_LIMIT_RESULT_FINDINGS_OBSERVATION_VALUE_MUTANT)
  LimitResultFindingsObservation -> value <> "<"
#else
  LimitResultFindingsObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_SUMMARY_SNAPSHOT_OBSERVATION_VALUE_MUTANT)
  SummarySnapshotObservation -> value <> "<"
#else
  SummarySnapshotObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_SUMMARY_BINDING_COUNT_OBSERVATION_VALUE_MUTANT)
  SummaryBindingCountObservation -> value <> "<"
#else
  SummaryBindingCountObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_SUMMARY_HASKELL_COUNT_OBSERVATION_VALUE_MUTANT)
  SummaryHaskellCountObservation -> value <> "<"
#else
  SummaryHaskellCountObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_BINDING_OBSERVATION_VALUE_MUTANT)
  BindingObservation -> value <> "<"
#else
  BindingObservation -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_SUBJECT_OBSERVATION_VALUE_MUTANT)
  SubjectObservation -> value <> "<"
#else
  SubjectObservation -> value
#endif

observationDropped :: DiagnosticObservationKind -> Bool
observationDropped kind = case kind of
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_LIMIT_SNAPSHOT_OBSERVATION_DROP_MUTANT)
  LimitSnapshotObservation -> True
#else
  LimitSnapshotObservation -> False
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_LIMIT_EFFECTS_OBSERVATION_DROP_MUTANT)
  LimitEffectsObservation -> True
#else
  LimitEffectsObservation -> False
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_LIMIT_PROBLEMS_OBSERVATION_DROP_MUTANT)
  LimitProblemsObservation -> True
#else
  LimitProblemsObservation -> False
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_LIMIT_RESULT_OBSERVATIONS_OBSERVATION_DROP_MUTANT)
  LimitResultObservationsObservation -> True
#else
  LimitResultObservationsObservation -> False
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_LIMIT_RESULT_FINDINGS_OBSERVATION_DROP_MUTANT)
  LimitResultFindingsObservation -> True
#else
  LimitResultFindingsObservation -> False
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_SUMMARY_SNAPSHOT_OBSERVATION_DROP_MUTANT)
  SummarySnapshotObservation -> True
#else
  SummarySnapshotObservation -> False
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_SUMMARY_BINDING_COUNT_OBSERVATION_DROP_MUTANT)
  SummaryBindingCountObservation -> True
#else
  SummaryBindingCountObservation -> False
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_SUMMARY_HASKELL_COUNT_OBSERVATION_DROP_MUTANT)
  SummaryHaskellCountObservation -> True
#else
  SummaryHaskellCountObservation -> False
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_BINDING_OBSERVATION_DROP_MUTANT)
  BindingObservation -> True
#else
  BindingObservation -> False
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_SUBJECT_OBSERVATION_DROP_MUTANT)
  SubjectObservation -> True
#else
  SubjectObservation -> False
#endif

problemFinding :: ConsumerGraphProblem -> Finding
problemFinding problem = case problem of
  DuplicateContentBinding path ->
    internalFinding DuplicateProblem "SRC-CONSUMER-DUPLICATE" path "admitted content received more than one binding"
  UnboundAdmittedContent path sourceClass ->
    internalFinding UnboundProblem
      "SRC-CONSUMER-ROLE-UNBOUND"
      path
      ("no closed content role exists for SourceClosure class " <> renderSourceClass sourceClass)
  NonRegularAdmittedContent path mode ->
    internalFinding ContentModeProblem
      "SRC-CONSUMER-CONTENT-MODE"
      path
      ("admitted non-source content is not a regular non-executable file: " <> renderMode mode)
  BehaviouralConsumerAuthorized path consumer ->
    internalFinding BehaviouralAuthorizationProblem
      "SRC-CONSUMER-BEHAVIOURAL-AUTHORIZATION"
      path
      ("closed role authorized a product-behaviour consumer: " <> renderConsumer consumer)
  EffectTargetIsNotAdmittedContent path ->
    internalFinding EffectTargetProblem
      "SRC-CONSUMER-EFFECT-TARGET"
      path
      "resolved effect target has no admitted non-source content binding"
  DynamicEffectMayReachTrackedContent modulePath detail ->
    internalFinding DynamicTargetProblem
      "SRC-CONSUMER-DYNAMIC-TARGET"
      modulePath
      ("dynamic effect target may alias tracked non-source content: " <> dynamicProblemDetail detail)
  UnresolvedContentEffect modulePath detail ->
    internalFinding UnresolvedEffectProblem
      "SRC-CONSUMER-UNRESOLVED-EFFECT"
      modulePath
      ("compiler effect target did not resolve: " <> unresolvedProblemDetail detail)
  UnauthorizedResolvedContentEffect modulePath path use name ->
    internalFinding UnauthorizedEffectProblem
      "SRC-CONSUMER-EFFECT-UNAUTHORIZED"
      modulePath
      ( "resolved consumer "
          <> unauthorizedProblemName name
          <> " is not authorized for "
          <> unauthorizedProblemPath path
          <> " as "
          <> renderContentUse use
      )
  DirectBehaviouralContentConsumption modulePath path name ->
    internalFinding DirectBehaviourProblem
      "SRC-CONSUMER-DIRECT-BEHAVIOUR"
      modulePath
      ("resolved consumer " <> directProblemName name <> " treats " <> directProblemPath path <> " as product behaviour")
  EmptyHaskellSubjectInventory ->
    internalFinding EmptyHaskellProblem
      "SRC-CONSUMER-EMPTY-HASKELL"
      "."
      "the compiler graph cannot be closed over an empty Haskell subject inventory"
  CompilerDerivedSemanticGraphUnavailable identity count facts ->
    internalFinding CompilerGraphUnavailableProblem
      "SRC-CONSUMER-COMPILER-GRAPH-UNAVAILABLE"
      "."
      ( "snapshot "
          <> compilerProblemIdentity identity
          <> " has "
          <> compilerProblemCount count
          <> " exact Haskell subjects but lacks compiler-derived facts: "
          <> Text.intercalate compilerProblemFactSeparator (map renderRequiredFact facts)
      )
  ConsumerGraphResourceLimit resource limit observed ->
    internalFinding ResourceProblem
      "SRC-CONSUMER-RESOURCE-LIMIT"
      (Text.unpack resource)
      ( resourceProblemName resource
          <> " exceeds the "
          <> resourceProblemLimit limit
          <> " bound; observed "
          <> resourceProblemObserved observed
      )

problemFindingDiagnostic :: ConsumerGraphProblem -> Finding
problemFindingDiagnostic = problemFinding

dynamicProblemDetail, unresolvedProblemDetail, unauthorizedProblemName, directProblemName :: Text -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DYNAMIC_PROBLEM_DETAIL_VALUE_MAPPING_MUTANT)
dynamicProblemDetail value = value <> "<"
#else
dynamicProblemDetail value = value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_UNRESOLVED_PROBLEM_DETAIL_VALUE_MAPPING_MUTANT)
unresolvedProblemDetail value = value <> "<"
#else
unresolvedProblemDetail value = value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_UNAUTHORIZED_PROBLEM_NAME_MAPPING_MUTANT)
unauthorizedProblemName value = value <> "<"
#else
unauthorizedProblemName value = value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DIRECT_PROBLEM_NAME_MAPPING_MUTANT)
directProblemName value = value <> "<"
#else
directProblemName value = value
#endif

unauthorizedProblemPath, directProblemPath :: FilePath -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_UNAUTHORIZED_PROBLEM_PATH_MAPPING_MUTANT)
unauthorizedProblemPath value = Text.pack value <> "<"
#else
unauthorizedProblemPath = Text.pack
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DIRECT_PROBLEM_PATH_MAPPING_MUTANT)
directProblemPath value = Text.pack value <> "<"
#else
directProblemPath = Text.pack
#endif

compilerProblemIdentity :: Text -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPILER_PROBLEM_IDENTITY_MAPPING_MUTANT)
compilerProblemIdentity value = value <> "<"
#else
compilerProblemIdentity value = value
#endif

compilerProblemCount :: Int -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPILER_PROBLEM_COUNT_MAPPING_MUTANT)
compilerProblemCount value = Text.pack (show (value + 1))
#else
compilerProblemCount = Text.pack . show
#endif

compilerProblemFactSeparator :: Text
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPILER_PROBLEM_FACT_SEPARATOR_MAPPING_MUTANT)
compilerProblemFactSeparator = "<"
#else
compilerProblemFactSeparator = ","
#endif

resourceProblemName :: Text -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_RESOURCE_PROBLEM_NAME_MAPPING_MUTANT)
resourceProblemName value = value <> "<"
#else
resourceProblemName value = value
#endif

resourceProblemLimit, resourceProblemObserved :: Int -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_RESOURCE_PROBLEM_LIMIT_MAPPING_MUTANT)
resourceProblemLimit value = Text.pack (show (value + 1))
#else
resourceProblemLimit = Text.pack . show
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_RESOURCE_PROBLEM_OBSERVED_MAPPING_MUTANT)
resourceProblemObserved value = Text.pack (show (value + 1))
#else
resourceProblemObserved = Text.pack . show
#endif

internalFinding :: DiagnosticProblemKind -> Text -> FilePath -> Text -> Finding
internalFinding kind code subject detail =
  finding
    (mutateProblemCode kind code)
    (mutateProblemSubject kind subject)
    (mutateProblemDetail kind detail)

mutateProblemCode :: DiagnosticProblemKind -> Text -> Text
mutateProblemCode kind value = case kind of
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DUPLICATE_CODE_MAPPING_MUTANT)
  DuplicateProblem -> value <> "<"
#else
  DuplicateProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_UNBOUND_CODE_MAPPING_MUTANT)
  UnboundProblem -> value <> "<"
#else
  UnboundProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_CONTENT_MODE_CODE_MAPPING_MUTANT)
  ContentModeProblem -> value <> "<"
#else
  ContentModeProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_BEHAVIOURAL_AUTHORIZATION_CODE_MAPPING_MUTANT)
  BehaviouralAuthorizationProblem -> value <> "<"
#else
  BehaviouralAuthorizationProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_EFFECT_TARGET_CODE_MAPPING_MUTANT)
  EffectTargetProblem -> value <> "<"
#else
  EffectTargetProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DYNAMIC_TARGET_CODE_MAPPING_MUTANT)
  DynamicTargetProblem -> value <> "<"
#else
  DynamicTargetProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_UNRESOLVED_EFFECT_CODE_MAPPING_MUTANT)
  UnresolvedEffectProblem -> value <> "<"
#else
  UnresolvedEffectProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_UNAUTHORIZED_EFFECT_CODE_MAPPING_MUTANT)
  UnauthorizedEffectProblem -> value <> "<"
#else
  UnauthorizedEffectProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DIRECT_BEHAVIOUR_CODE_MAPPING_MUTANT)
  DirectBehaviourProblem -> value <> "<"
#else
  DirectBehaviourProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_EMPTY_HASKELL_CODE_MAPPING_MUTANT)
  EmptyHaskellProblem -> value <> "<"
#else
  EmptyHaskellProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPILER_GRAPH_UNAVAILABLE_CODE_MAPPING_MUTANT)
  CompilerGraphUnavailableProblem -> value <> "<"
#else
  CompilerGraphUnavailableProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_RESOURCE_CODE_MAPPING_MUTANT)
  ResourceProblem -> value <> "<"
#else
  ResourceProblem -> value
#endif

mutateProblemSubject :: DiagnosticProblemKind -> FilePath -> FilePath
mutateProblemSubject kind value = case kind of
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DUPLICATE_SUBJECT_MAPPING_MUTANT)
  DuplicateProblem -> value <> "<"
#else
  DuplicateProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_UNBOUND_SUBJECT_MAPPING_MUTANT)
  UnboundProblem -> value <> "<"
#else
  UnboundProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_CONTENT_MODE_SUBJECT_MAPPING_MUTANT)
  ContentModeProblem -> value <> "<"
#else
  ContentModeProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_BEHAVIOURAL_AUTHORIZATION_SUBJECT_MAPPING_MUTANT)
  BehaviouralAuthorizationProblem -> value <> "<"
#else
  BehaviouralAuthorizationProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_EFFECT_TARGET_SUBJECT_MAPPING_MUTANT)
  EffectTargetProblem -> value <> "<"
#else
  EffectTargetProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DYNAMIC_TARGET_SUBJECT_MAPPING_MUTANT)
  DynamicTargetProblem -> value <> "<"
#else
  DynamicTargetProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_UNRESOLVED_EFFECT_SUBJECT_MAPPING_MUTANT)
  UnresolvedEffectProblem -> value <> "<"
#else
  UnresolvedEffectProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_UNAUTHORIZED_EFFECT_SUBJECT_MAPPING_MUTANT)
  UnauthorizedEffectProblem -> value <> "<"
#else
  UnauthorizedEffectProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DIRECT_BEHAVIOUR_SUBJECT_MAPPING_MUTANT)
  DirectBehaviourProblem -> value <> "<"
#else
  DirectBehaviourProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_EMPTY_HASKELL_SUBJECT_MAPPING_MUTANT)
  EmptyHaskellProblem -> value <> "<"
#else
  EmptyHaskellProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPILER_GRAPH_UNAVAILABLE_SUBJECT_MAPPING_MUTANT)
  CompilerGraphUnavailableProblem -> value <> "<"
#else
  CompilerGraphUnavailableProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_RESOURCE_SUBJECT_MAPPING_MUTANT)
  ResourceProblem -> value <> "<"
#else
  ResourceProblem -> value
#endif

mutateProblemDetail :: DiagnosticProblemKind -> Text -> Text
mutateProblemDetail kind value = case kind of
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DUPLICATE_DETAIL_MAPPING_MUTANT)
  DuplicateProblem -> value <> "<"
#else
  DuplicateProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_UNBOUND_DETAIL_MAPPING_MUTANT)
  UnboundProblem -> value <> "<"
#else
  UnboundProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_CONTENT_MODE_DETAIL_MAPPING_MUTANT)
  ContentModeProblem -> value <> "<"
#else
  ContentModeProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_BEHAVIOURAL_AUTHORIZATION_DETAIL_MAPPING_MUTANT)
  BehaviouralAuthorizationProblem -> value <> "<"
#else
  BehaviouralAuthorizationProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_EFFECT_TARGET_DETAIL_MAPPING_MUTANT)
  EffectTargetProblem -> value <> "<"
#else
  EffectTargetProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DYNAMIC_TARGET_DETAIL_MAPPING_MUTANT)
  DynamicTargetProblem -> value <> "<"
#else
  DynamicTargetProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_UNRESOLVED_EFFECT_DETAIL_MAPPING_MUTANT)
  UnresolvedEffectProblem -> value <> "<"
#else
  UnresolvedEffectProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_UNAUTHORIZED_EFFECT_DETAIL_MAPPING_MUTANT)
  UnauthorizedEffectProblem -> value <> "<"
#else
  UnauthorizedEffectProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DIRECT_BEHAVIOUR_DETAIL_MAPPING_MUTANT)
  DirectBehaviourProblem -> value <> "<"
#else
  DirectBehaviourProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_EMPTY_HASKELL_DETAIL_MAPPING_MUTANT)
  EmptyHaskellProblem -> value <> "<"
#else
  EmptyHaskellProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPILER_GRAPH_UNAVAILABLE_DETAIL_MAPPING_MUTANT)
  CompilerGraphUnavailableProblem -> value <> "<"
#else
  CompilerGraphUnavailableProblem -> value
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_RESOURCE_DETAIL_MAPPING_MUTANT)
  ResourceProblem -> value <> "<"
#else
  ResourceProblem -> value
#endif

renderContentUse :: ContentUse -> Text
renderContentUse use = case use of
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_SOURCE_BOUNDARY_USE_RENDER_MAPPING_MUTANT)
  SourceBoundaryStructureInspection -> "SourceBoundaryStructureInspection<"
#else
  SourceBoundaryStructureInspection -> "SourceBoundaryStructureInspection"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DOCUMENTATION_USE_RENDER_MAPPING_MUTANT)
  StructuralDocumentationInspection -> "StructuralDocumentationInspection<"
#else
  StructuralDocumentationInspection -> "StructuralDocumentationInspection"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_ROOT_SENTINEL_USE_RENDER_MAPPING_MUTANT)
  RepositoryRootSentinel -> "RepositoryRootSentinel<"
#else
  RepositoryRootSentinel -> "RepositoryRootSentinel"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_PRODUCT_BEHAVIOUR_USE_RENDER_MAPPING_MUTANT)
  ProductBehaviourInput -> "ProductBehaviourInput<"
#else
  ProductBehaviourInput -> "ProductBehaviourInput"
#endif

renderRequiredFact :: RequiredCompilerFact -> Text
renderRequiredFact fact = case fact of
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPILER_PARSE_FACT_RENDER_MAPPING_MUTANT)
  CompilerParseSucceeded -> "CompilerParseSucceeded<"
#else
  CompilerParseSucceeded -> "CompilerParseSucceeded"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_CONDITIONAL_PREPROCESSING_FACT_RENDER_MAPPING_MUTANT)
  ConditionalPreprocessingAbsent -> "ConditionalPreprocessingAbsent<"
#else
  ConditionalPreprocessingAbsent -> "ConditionalPreprocessingAbsent"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_COMPILE_TIME_EXECUTION_FACT_RENDER_MAPPING_MUTANT)
  CompileTimeExecutionFeaturesAbsent -> "CompileTimeExecutionFeaturesAbsent<"
#else
  CompileTimeExecutionFeaturesAbsent -> "CompileTimeExecutionFeaturesAbsent"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_IMPORTS_RENAMED_FACT_RENDER_MAPPING_MUTANT)
  ImportsRenamed -> "ImportsRenamed<"
#else
  ImportsRenamed -> "ImportsRenamed"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_CALLS_RESOLVED_FACT_RENDER_MAPPING_MUTANT)
  CallsResolved -> "CallsResolved<"
#else
  CallsResolved -> "CallsResolved"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_INDIRECT_CALLS_FACT_RENDER_MAPPING_MUTANT)
  IndirectCallsClosed -> "IndirectCallsClosed<"
#else
  IndirectCallsClosed -> "IndirectCallsClosed"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_CONTROL_FLOW_FACT_RENDER_MAPPING_MUTANT)
  ControlFlowClosed -> "ControlFlowClosed<"
#else
  ControlFlowClosed -> "ControlFlowClosed"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_FILESYSTEM_EFFECTS_FACT_RENDER_MAPPING_MUTANT)
  FilesystemEffectsClassified -> "FilesystemEffectsClassified<"
#else
  FilesystemEffectsClassified -> "FilesystemEffectsClassified"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_EXTERNAL_EFFECTS_FACT_RENDER_MAPPING_MUTANT)
  ExternalProcessAndFfiEffectsClassified -> "ExternalProcessAndFfiEffectsClassified<"
#else
  ExternalProcessAndFfiEffectsClassified -> "ExternalProcessAndFfiEffectsClassified"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_PROVENANCE_FLOWS_FACT_RENDER_MAPPING_MUTANT)
  TrackedContentProvenanceFlowsClosed -> "TrackedContentProvenanceFlowsClosed<"
#else
  TrackedContentProvenanceFlowsClosed -> "TrackedContentProvenanceFlowsClosed"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_PRODUCT_SINKS_FACT_RENDER_MAPPING_MUTANT)
  ProductBehaviourSinksClassified -> "ProductBehaviourSinksClassified<"
#else
  ProductBehaviourSinksClassified -> "ProductBehaviourSinksClassified"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DYNAMIC_LOADING_FACT_RENDER_MAPPING_MUTANT)
  DynamicCodeAndPluginLoadingAbsent -> "DynamicCodeAndPluginLoadingAbsent<"
#else
  DynamicCodeAndPluginLoadingAbsent -> "DynamicCodeAndPluginLoadingAbsent"
#endif

renderSourceClass :: SourceClass -> Text
renderSourceClass sourceClass = case sourceClass of
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DOCUMENTATION_SOURCE_CLASS_RENDER_MAPPING_MUTANT)
  DocumentationInput -> "DocumentationInput<"
#else
  DocumentationInput -> "DocumentationInput"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_PROJECT_SOURCE_CLASS_RENDER_MAPPING_MUTANT)
  ProjectDeclaration -> "ProjectDeclaration<"
#else
  ProjectDeclaration -> "ProjectDeclaration"
#endif
  other -> Text.pack (show other)

renderRole :: ContentRole -> Text
renderRole role = case role of
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_GOVERNANCE_DOCUMENTATION_ROLE_RENDER_MAPPING_MUTANT)
  GovernanceDocumentation -> "GovernanceDocumentation<"
#else
  GovernanceDocumentation -> "GovernanceDocumentation"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_CABAL_PACKAGE_DESCRIPTION_ROLE_RENDER_MAPPING_MUTANT)
  CabalPackageDescription -> "CabalPackageDescription<"
#else
  CabalPackageDescription -> "CabalPackageDescription"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_CABAL_PROJECT_DESCRIPTION_ROLE_RENDER_MAPPING_MUTANT)
  CabalProjectDescription -> "CabalProjectDescription<"
#else
  CabalProjectDescription -> "CabalProjectDescription"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_GITIGNORE_CONTRACT_ROLE_RENDER_MAPPING_MUTANT)
  GitIgnoreContract -> "GitIgnoreContract<"
#else
  GitIgnoreContract -> "GitIgnoreContract"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DOCKERIGNORE_CONTRACT_ROLE_RENDER_MAPPING_MUTANT)
  DockerIgnoreContract -> "DockerIgnoreContract<"
#else
  DockerIgnoreContract -> "DockerIgnoreContract"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_GITATTRIBUTES_CONTRACT_ROLE_RENDER_MAPPING_MUTANT)
  GitAttributesContract -> "GitAttributesContract<"
#else
  GitAttributesContract -> "GitAttributesContract"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_EDITOR_CONFIGURATION_ROLE_RENDER_MAPPING_MUTANT)
  EditorConfiguration -> "EditorConfiguration<"
#else
  EditorConfiguration -> "EditorConfiguration"
#endif

renderConsumer :: AuthorizedConsumer -> Text
renderConsumer consumer = case consumer of
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_HUMAN_READER_CONSUMER_RENDER_MAPPING_MUTANT)
  HumanReader -> "HumanReader<"
#else
  HumanReader -> "HumanReader"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_SOURCE_BOUNDARY_CHECKER_CONSUMER_RENDER_MAPPING_MUTANT)
  HaskellSourceBoundaryStructureChecker -> "HaskellSourceBoundaryStructureChecker<"
#else
  HaskellSourceBoundaryStructureChecker -> "HaskellSourceBoundaryStructureChecker"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_DOCUMENTATION_STRUCTURE_CHECKER_CONSUMER_RENDER_MAPPING_MUTANT)
  HaskellDocumentationStructureChecker -> "HaskellDocumentationStructureChecker<"
#else
  HaskellDocumentationStructureChecker -> "HaskellDocumentationStructureChecker"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_REPOSITORY_ROOT_LOCATOR_CONSUMER_RENDER_MAPPING_MUTANT)
  HaskellRepositoryRootLocator -> "HaskellRepositoryRootLocator<"
#else
  HaskellRepositoryRootLocator -> "HaskellRepositoryRootLocator"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_CABAL_BUILD_TOOL_CONSUMER_RENDER_MAPPING_MUTANT)
  CabalBuildTool -> "CabalBuildTool<"
#else
  CabalBuildTool -> "CabalBuildTool"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_GIT_CLIENT_CONSUMER_RENDER_MAPPING_MUTANT)
  GitClient -> "GitClient<"
#else
  GitClient -> "GitClient"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_CONTAINER_CONTEXT_BUILDER_CONSUMER_RENDER_MAPPING_MUTANT)
  ContainerContextBuilder -> "ContainerContextBuilder<"
#else
  ContainerContextBuilder -> "ContainerContextBuilder"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_EDITOR_TOOL_CONSUMER_RENDER_MAPPING_MUTANT)
  EditorTool -> "EditorTool<"
#else
  EditorTool -> "EditorTool"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_PRODUCT_RUNTIME_CONSUMER_RENDER_MAPPING_MUTANT)
  HaskellProductRuntime -> "HaskellProductRuntime<"
#else
  HaskellProductRuntime -> "HaskellProductRuntime"
#endif

renderMode :: IndexMode -> Text
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_REGULAR_MODE_RENDER_MAPPING_MUTANT)
renderMode RegularFile = "100644<"
#else
renderMode RegularFile = "100644"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_EXECUTABLE_MODE_RENDER_MAPPING_MUTANT)
renderMode ExecutableFile = "100755<"
#else
renderMode ExecutableFile = "100755"
#endif
#if defined(VALIDATION_SOURCE_CONSUMER_INTERNAL_SYMLINK_MODE_RENDER_MAPPING_MUTANT)
renderMode SymbolicLink = "120000<"
#else
renderMode SymbolicLink = "120000"
#endif

entryPath :: TrackedEntry -> FilePath
entryPath = indexPath . trackedIndex

duplicates :: Ord value => [value] -> [value]
duplicates values =
  Map.keys (Map.filter (> (1 :: Int)) (Map.fromListWith (+) [(value, 1 :: Int) | value <- values]))
