{-# LANGUAGE CPP #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.CompilerComponentPlan.Internal
  ( ComponentAssignment (..)
  , ComponentCompilerConfig (..)
  , ComponentKind (..)
  , ComponentPlanProblem (..)
  , CompilerComponentPlan
  , componentPlanAssignments
  , componentPlanComponents
  , componentPlanProblems
  , componentPlanSnapshotIdentity
  , deriveCompilerComponentPlan
  , rawCompilerComponentPlanDiagnostic
  , renderComponentCompilerConfig
  , renderComponentPlanProblem
  ) where

-- Cabal is a build declaration, not product behaviour.  This module is a
-- conservative declaration inventory over immutable .cabal bytes.  It binds
-- paths and declarations exactly where implemented and emits typed residue for
-- project elaboration, conditional units, dependencies, and unsupported build
-- behavior.  It is not an elaborated Cabal install plan, and no caller can
-- provide or trim its Haskell subject inventory.

import Amoebius.Validation.SourceClosure.Internal
  ( IndexEntry (..)
  , IndexMode (..)
  , SourceSnapshot (..)
  , TrackedEntry (..)
  )
import Amoebius.Validation.SourceConsumerGraph.Internal (HaskellSubject (..))
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding
  , Observation
  , finding
  , observation
  )
import Crypto.Hash qualified as Crypto
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteString8
import Data.Char (isAsciiLower, isAsciiUpper, isDigit, ord)
import Data.List (group, sort, sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Distribution.Compiler (CompilerFlavor (GHC, GHCJS))
import Distribution.ModuleName qualified as CabalModule
import Distribution.PackageDescription
  ( Benchmark (..)
  , BenchmarkInterface (..)
  , BuildType (Simple)
  , BuildInfo (..)
  , Executable (..)
  , GenericPackageDescription (..)
  , Library (..)
  , PackageDescription
      ( buildTypeRaw
      , customFieldsPD
      , dataFiles
      , extraDocFiles
      , extraFiles
      , extraSrcFiles
      , extraTmpFiles
      , setupBuildInfo
      , sourceRepos
      )
  , TestSuite (..)
  , TestSuiteInterface (..)
  , benchmarkBuildInfo
  , buildInfo
  , hcProfOptions
  , hcProfSharedOptions
  , hcOptions
  , hcSharedOptions
  , libBuildInfo
  , testBuildInfo
  )
import Distribution.Fields.ParseResult (runParseResult)
import Distribution.PackageDescription.Parsec (parseGenericPackageDescription)
import Distribution.Pretty (prettyShow)
import Distribution.Types.CondTree
  ( CondBranch (..)
  , CondTree (..)
  )
import Distribution.Types.Dependency (Dependency)
import Distribution.Types.UnqualComponentName (UnqualComponentName, unUnqualComponentName)
import Distribution.Utils.Path (getSymbolicPath)
import Distribution.Utils.Path qualified as CabalPath

data ComponentKind
  = MainLibraryComponent
  | NamedLibraryComponent
  | ExecutableComponent
  | TestComponent
  | BenchmarkComponent
  deriving (Eq, Ord, Enum, Bounded, Show)

data ComponentCompilerConfig = ComponentCompilerConfig
  { componentConfigSourceDirs :: [FilePath]
  , componentConfigDefaultLanguage :: Maybe Text
  , componentConfigExtensions :: [Text]
  , componentConfigGhcOptions :: [Text]
  , componentConfigCppOptions :: [Text]
  , componentConfigDependencies :: [Text]
  }
  deriving (Eq, Ord, Show)

data ComponentAssignment = ComponentAssignment
  { componentAssignmentName :: Text
  , componentAssignmentKind :: ComponentKind
  , componentAssignmentSubject :: HaskellSubject
  , componentAssignmentDeclaredModules :: [Text]
  , componentAssignmentConfigs :: [ComponentCompilerConfig]
  }
  deriving (Eq, Ord, Show)

data ComponentPlanProblem
  = ComponentPlanSnapshotEntryLimitExceeded Int Int
  | ComponentPlanPathByteLimitExceeded Int Int Int
  | ComponentPlanModeByteLimitExceeded Int Int Int
  | ComponentPlanObjectIdentityByteLimitExceeded Int Int Int
  | ComponentPlanSnapshotIdentityByteLimitExceeded Int Int
  | ComponentPlanBlobByteLimitExceeded FilePath Int Int
  | ComponentPlanAggregateBlobByteLimitExceeded Int Int
  | ComponentPlanPathEmpty Int
  | ComponentPlanPathAbsolute FilePath
  | ComponentPlanPathNul FilePath
  | ComponentPlanPathBackslash FilePath
  | ComponentPlanPathEmptySegment FilePath
  | ComponentPlanPathDotSegment FilePath
  | ComponentPlanPathParentSegment FilePath
  | ComponentPlanPathCharacterUnsafe FilePath
  | ComponentPlanDuplicatePath FilePath
  | ComponentPlanEntryOrderInvalid [FilePath]
  | ComponentPlanModeMalformed FilePath Text
  | ComponentPlanObjectIdentityMalformed FilePath Text
  | ComponentPlanObjectIdentityMismatch FilePath Text Text
  | ComponentPlanSnapshotIdentityMalformed Text
  | ComponentPlanSnapshotIdentityMismatch Text Text
  | ComponentPlanCabalEntryLimitExceeded Int Int
  | ComponentPlanCabalByteLimitExceeded FilePath Int Int
  | ComponentPlanComponentLimitExceeded FilePath Int Int
  | ComponentPlanConditionalLimitExceeded FilePath Int Int
  | ComponentPlanModuleLimitExceeded FilePath Int Int
  | ComponentPlanSourceDirectoryLimitExceeded FilePath Int Int
  | ComponentPlanConfigurationLimitExceeded FilePath Int Int
  | ComponentPlanOptionLimitExceeded FilePath Int Int
  | ComponentPlanDependencyLimitExceeded FilePath Int Int
  | ComponentPlanAssignmentLimitExceeded Int Int
  | ComponentPlanProblemLimitExceeded Int Int
  | CabalDescriptionAbsent
  | CabalProjectElaborationUnavailable FilePath
  | CabalDescriptionParseFailed FilePath
  | CabalDescriptionParseWarning FilePath
  | CabalBuildTypeUnsupported FilePath Text
  | CabalCustomSetupUnsupported FilePath
  | CabalPackageFieldUnclosed FilePath Text
  | CabalConditionalConfigurationUnclosed Text Text
  | CabalForeignLibraryUnsupported FilePath Text
  | CabalSignatureModuleUnsupported Text Text
  | CabalAutogenModuleUnsupported Text Text
  | CabalDeclaredModuleMissing Text Text [FilePath]
  | CabalDeclaredModuleAmbiguous Text Text [FilePath]
  | CabalMainModuleMissing Text FilePath [FilePath]
  | CabalMainModuleAmbiguous Text FilePath [FilePath]
  | CabalDeclaredModuleExpectationConflict Text FilePath [Text]
  | CabalDeclaredPathUnsafe Text FilePath
  | CabalHaskellSubjectUnowned FilePath
  | CabalCompilerOptionUnclosed Text Text
  | CabalCompilerLanguageUnclosed Text (Maybe Text)
  | CabalCompilerExtensionsUnclosed Text [Text]
  | CabalCompilerDependenciesUnclosed Text [Text]
  | CabalBuildInfoFieldUnclosed Text Text
  | CabalModuleReexportUnsupported Text Text
  | CabalComponentConfigurationsDiffer Text [ComponentCompilerConfig]
  | CabalMultipleComponentsUnclosed [Text]
  deriving (Eq, Ord, Show)

-- All ceilings are literal, local, and deliberately small enough for exact
-- max/max+1 controls.  Entry/byte bounds run before ordering, hashing, Cabal
-- parsing, or construction of maps and sets.  Parsed-declaration ceilings run
-- before projection and the final problem/assignment ceilings run before
-- sorting their lazy streams.
maxSnapshotEntries, maxPathBytes, maxModeBytes, maxObjectIdentityBytes :: Int
maxSnapshotEntries = 128
maxPathBytes = 240
maxModeBytes = 6
maxObjectIdentityBytes = 64

maxSnapshotIdentityBytes :: Int
maxSnapshotIdentityBytes = 64

maxBlobBytes, maxAggregateBlobBytes, maxCabalEntries, maxCabalBytes :: Int
maxBlobBytes = 65536
maxAggregateBlobBytes = 262144
maxCabalEntries = 4
maxCabalBytes = 16384

maxComponents, maxConditionals, maxModules, maxSourceDirectories :: Int
maxComponents = 16
maxConditionals = 32
maxModules = 128
maxSourceDirectories = 32

maxConfigurations, maxOptions, maxDependencies, maxAssignments :: Int
maxConfigurations = 40
maxOptions = 128
maxDependencies = 128
maxAssignments = 64

maxProblems, maxResultFindings :: Int
maxProblems = 66
maxResultFindings = 69

data RawComponentEntry = RawComponentEntry
  { rawComponentPath :: FilePath
  , rawComponentMode :: Text
  , rawComponentObjectIdentity :: Text
  , rawComponentBytes :: ByteString
  }

-- Positional even inside the package-hidden module: selective exposure of a
-- record label must never turn a received plan into record-update authority.
data CompilerComponentPlan
  = CompilerComponentPlan Text [Text] [ComponentAssignment] [ComponentPlanProblem]
  deriving (Eq, Show)

componentPlanSnapshotIdentity :: CompilerComponentPlan -> Text
#if defined(VALIDATION_COMPILER_PLAN_PLAN_SNAPSHOT_IDENTITY_PROJECTION_MUTANT)
componentPlanSnapshotIdentity _ = "mutated-snapshot-identity"
#else
componentPlanSnapshotIdentity (CompilerComponentPlan value _ _ _) = value
#endif

componentPlanComponents :: CompilerComponentPlan -> [Text]
#if defined(VALIDATION_COMPILER_PLAN_PLAN_COMPONENTS_PROJECTION_MUTANT)
componentPlanComponents _ = []
#else
componentPlanComponents (CompilerComponentPlan _ value _ _) = value
#endif

componentPlanAssignments :: CompilerComponentPlan -> [ComponentAssignment]
#if defined(VALIDATION_COMPILER_PLAN_PLAN_ASSIGNMENTS_PROJECTION_MUTANT)
componentPlanAssignments _ = []
#else
componentPlanAssignments (CompilerComponentPlan _ _ value _) = value
#endif

componentPlanProblems :: CompilerComponentPlan -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_PLAN_PROBLEMS_PROJECTION_MUTANT)
componentPlanProblems _ = []
#else
componentPlanProblems (CompilerComponentPlan _ _ _ value) = value
#endif

data RawAnalysis = RawAnalysis
  { rawAnalysisPlan :: CompilerComponentPlan
  , rawAnalysisEntryCount :: Text
  , rawAnalysisAggregateBytes :: Text
  , rawAnalysisInventoryDigest :: Text
  }

-- | Package-internal implementation of the facade's sole primitive-input
-- diagnostic.  Raw modes and object identities are parsed here; neither a
-- SourceSnapshot nor any production fixture constructor crosses the facade.
rawCompilerComponentPlanDiagnostic
  :: Text
  -> [(FilePath, Text, Text, ByteString)]
  -> CheckResult
rawCompilerComponentPlanDiagnostic claimedIdentity tuples =
  boundedResult
 where
  analysis =
    analyzeRawInventory claimedIdentity
      (map rawComponentEntryFromTuple tuples)
  plan = projectRawAnalysisPlan analysis
  planFindings = projectPlanFindings (map componentPlanProblemFinding (componentPlanProblems plan))
  mandatoryFindings =
    projectMandatoryFindingsContribution
      ( projectMandatoryFindingOrder
          ( diagnosticOnlyFinding
              <> sourceCustodyFinding
              <> cabalElaborationFinding
              <> compilerExecutionFinding
          )
      )
  diagnosticOnlyFinding =
#if defined(VALIDATION_COMPILER_PLAN_DIAGNOSTIC_BYPASS_MUTANT)
    diagnosticOnlyFindingCode
      `seq` diagnosticOnlyFindingSubject
      `seq` diagnosticOnlyFindingDetail
      `seq` []
#else
    [ finding
        diagnosticOnlyFindingCode
        diagnosticOnlyFindingSubject
        diagnosticOnlyFindingDetail
    ]
#endif
  sourceCustodyFinding =
#if defined(VALIDATION_COMPILER_PLAN_SOURCE_CUSTODY_BYPASS_MUTANT)
    sourceCustodyFindingCode
      `seq` sourceCustodyFindingSubject
      `seq` sourceCustodyFindingDetail
      `seq` []
#else
    [ finding
        sourceCustodyFindingCode
        sourceCustodyFindingSubject
        sourceCustodyFindingDetail
    ]
#endif
  cabalElaborationFinding =
#if defined(VALIDATION_COMPILER_PLAN_CABAL_ELABORATION_BYPASS_MUTANT)
    cabalElaborationFindingCode
      `seq` cabalElaborationFindingSubject
      `seq` cabalElaborationFindingDetail
      `seq` []
#else
    [ finding
        cabalElaborationFindingCode
        cabalElaborationFindingSubject
        cabalElaborationFindingDetail
    ]
#endif
  compilerExecutionFinding =
#if defined(VALIDATION_COMPILER_PLAN_COMPILER_EXECUTION_BYPASS_MUTANT)
    compilerExecutionFindingCode
      `seq` compilerExecutionFindingSubject
      `seq` compilerExecutionFindingDetail
      `seq` []
#else
    [ finding
        compilerExecutionFindingCode
        compilerExecutionFindingSubject
        compilerExecutionFindingDetail
    ]
#endif
  candidateFindings = projectCandidateFindingOrder planFindings mandatoryFindings
  boundedFindings = case boundedPrefix maxResultFindings candidateFindings of
    Bounded values -> values
    Exceeded observed | resultFindingLimitExceeded observed ->
      projectResultLimitFindingOrder
        mandatoryFindings
        ( projectResultLimitFindingContribution
            ( finding
                resultFindingLimitCode
                resultFindingLimitSubject
                (resultFindingLimitDetail maxResultFindings observed)
            )
        )
    Exceeded _ -> take maxResultFindings (mandatoryFindings <> planFindings)
  boundedResult =
    CheckResult
      { checkName = resultCheckName
      , checkObservations =
          projectResultObservations
            ( projectObservationOrder
                ( concat
                    [ projectEntryCountObservationContribution
                        (observation observationEntryCountKey (projectEntryCountObservation (projectRawAnalysisEntryCount analysis)))
                    , projectAggregateBytesObservationContribution
                        (observation observationAggregateBytesKey (projectAggregateBytesObservation (projectRawAnalysisAggregateBytes analysis)))
                    , projectInventoryDigestObservationContribution
                        (observation observationInventoryDigestKey (projectInventoryDigestObservation (projectRawAnalysisInventoryDigest analysis)))
                    , projectComponentCountObservationContribution
                        (observation observationComponentCountKey (projectComponentCountObservation (decimalText (length (componentPlanComponents plan)))))
                    , projectAssignmentCountObservationContribution
                        (observation observationAssignmentCountKey (projectAssignmentCountObservation (decimalText (length (componentPlanAssignments plan)))))
                    , projectProblemCountObservationContribution
                        (observation observationProblemCountKey (projectProblemCountObservation (decimalText (length (componentPlanProblems plan)))))
                    , projectProjectionDigestObservationContribution
                        (observation observationProjectionDigestKey (projectProjectionDigestObservation (componentPlanProjectionSha256 plan)))
                    , projectDiagnosticStatusObservationContribution
                        ( observation
                            observationDiagnosticStatusKey
                            (projectDiagnosticStatusObservation (if null boundedFindings then "accepted" else "refused"))
                        )
                    ]
                )
            )
      , checkFindings = projectResultFindingOrder (projectResultFindings boundedFindings)
      }

projectRawAnalysisPlan :: RawAnalysis -> CompilerComponentPlan
#if defined(VALIDATION_COMPILER_PLAN_RAW_ANALYSIS_PLAN_FIELD_MAPPING_MUTANT)
projectRawAnalysisPlan _ = emptyComponentPlan "mutated-raw-analysis-plan" []
#else
projectRawAnalysisPlan = rawAnalysisPlan
#endif

projectRawAnalysisEntryCount :: RawAnalysis -> Text
#if defined(VALIDATION_COMPILER_PLAN_RAW_ANALYSIS_ENTRY_COUNT_FIELD_MAPPING_MUTANT)
projectRawAnalysisEntryCount _ = "mutated-entry-count"
#else
projectRawAnalysisEntryCount = rawAnalysisEntryCount
#endif

projectRawAnalysisAggregateBytes :: RawAnalysis -> Text
#if defined(VALIDATION_COMPILER_PLAN_RAW_ANALYSIS_AGGREGATE_BYTES_FIELD_MAPPING_MUTANT)
projectRawAnalysisAggregateBytes _ = "mutated-aggregate-bytes"
#else
projectRawAnalysisAggregateBytes = rawAnalysisAggregateBytes
#endif

projectRawAnalysisInventoryDigest :: RawAnalysis -> Text
#if defined(VALIDATION_COMPILER_PLAN_RAW_ANALYSIS_INVENTORY_DIGEST_FIELD_MAPPING_MUTANT)
projectRawAnalysisInventoryDigest _ = "mutated-inventory-digest"
#else
projectRawAnalysisInventoryDigest = rawAnalysisInventoryDigest
#endif

projectPlanFindings :: [Finding] -> [Finding]
#if defined(VALIDATION_COMPILER_PLAN_RESULT_PLAN_FINDINGS_CONTRIBUTION_MUTANT)
projectPlanFindings _ = []
#else
projectPlanFindings = id
#endif

diagnosticOnlyFindingCode, diagnosticOnlyFindingDetail :: Text
diagnosticOnlyFindingSubject :: FilePath
#if defined(VALIDATION_COMPILER_PLAN_DIAGNOSTIC_FINDING_CODE_MUTANT)
diagnosticOnlyFindingCode = "MUTATED-DIAGNOSTIC-ONLY"
#else
diagnosticOnlyFindingCode = "COMPONENT-PLAN-DIAGNOSTIC-ONLY"
#endif
#if defined(VALIDATION_COMPILER_PLAN_DIAGNOSTIC_FINDING_SUBJECT_MUTANT)
diagnosticOnlyFindingSubject = "mutated-diagnostic-subject"
#else
diagnosticOnlyFindingSubject = "compiler-component-plan"
#endif
#if defined(VALIDATION_COMPILER_PLAN_DIAGNOSTIC_FINDING_DETAIL_MUTANT)
diagnosticOnlyFindingDetail = "mutated diagnostic-only detail"
#else
diagnosticOnlyFindingDetail = "raw caller input can produce diagnostics only; it cannot mint component-plan evidence"
#endif

sourceCustodyFindingCode, sourceCustodyFindingDetail :: Text
sourceCustodyFindingSubject :: FilePath
#if defined(VALIDATION_COMPILER_PLAN_SOURCE_CUSTODY_FINDING_CODE_MUTANT)
sourceCustodyFindingCode = "MUTATED-SOURCE-CUSTODY"
#else
sourceCustodyFindingCode = "COMPONENT-PLAN-SOURCE-CUSTODY-UNAVAILABLE"
#endif
#if defined(VALIDATION_COMPILER_PLAN_SOURCE_CUSTODY_FINDING_SUBJECT_MUTANT)
sourceCustodyFindingSubject = "mutated-custody-subject"
#else
sourceCustodyFindingSubject = "compiler-component-plan"
#endif
#if defined(VALIDATION_COMPILER_PLAN_SOURCE_CUSTODY_FINDING_DETAIL_MUTANT)
sourceCustodyFindingDetail = "mutated source-custody detail"
#else
sourceCustodyFindingDetail = "an authenticated network-independent source-custody observation is not attached"
#endif

cabalElaborationFindingCode, cabalElaborationFindingDetail :: Text
cabalElaborationFindingSubject :: FilePath
#if defined(VALIDATION_COMPILER_PLAN_CABAL_ELABORATION_FINDING_CODE_MUTANT)
cabalElaborationFindingCode = "MUTATED-CABAL-ELABORATION"
#else
cabalElaborationFindingCode = "COMPONENT-PLAN-CABAL-ELABORATION-UNAVAILABLE"
#endif
#if defined(VALIDATION_COMPILER_PLAN_CABAL_ELABORATION_FINDING_SUBJECT_MUTANT)
cabalElaborationFindingSubject = "mutated-elaboration-subject"
#else
cabalElaborationFindingSubject = "compiler-component-plan"
#endif
#if defined(VALIDATION_COMPILER_PLAN_CABAL_ELABORATION_FINDING_DETAIL_MUTANT)
cabalElaborationFindingDetail = "mutated Cabal-elaboration detail"
#else
cabalElaborationFindingDetail = "Cabal project and conditional-unit elaboration remains outside this restricted parser"
#endif

compilerExecutionFindingCode, compilerExecutionFindingDetail :: Text
compilerExecutionFindingSubject :: FilePath
#if defined(VALIDATION_COMPILER_PLAN_COMPILER_EXECUTION_FINDING_CODE_MUTANT)
compilerExecutionFindingCode = "MUTATED-COMPILER-EXECUTION"
#else
compilerExecutionFindingCode = "COMPONENT-PLAN-COMPILER-EXECUTION-UNAVAILABLE"
#endif
#if defined(VALIDATION_COMPILER_PLAN_COMPILER_EXECUTION_FINDING_SUBJECT_MUTANT)
compilerExecutionFindingSubject = "mutated-compiler-subject"
#else
compilerExecutionFindingSubject = "compiler-component-plan"
#endif
#if defined(VALIDATION_COMPILER_PLAN_COMPILER_EXECUTION_FINDING_DETAIL_MUTANT)
compilerExecutionFindingDetail = "mutated compiler-execution detail"
#else
compilerExecutionFindingDetail = "the linked compiler has not parsed, renamed, and typechecked the exact assignments"
#endif

resultFindingLimitCode :: Text
resultFindingLimitSubject :: FilePath
#if defined(VALIDATION_COMPILER_PLAN_RESULT_FINDING_LIMIT_CODE_MUTANT)
resultFindingLimitCode = "MUTATED-RESULT-FINDING-LIMIT"
#else
resultFindingLimitCode = "COMPONENT-PLAN-RESULT-FINDING-LIMIT"
#endif
#if defined(VALIDATION_COMPILER_PLAN_RESULT_FINDING_LIMIT_SUBJECT_MUTANT)
resultFindingLimitSubject = "mutated-result-limit-subject"
#else
resultFindingLimitSubject = "compiler-component-plan"
#endif
resultFindingLimitDetail :: Int -> Int -> Text
#if defined(VALIDATION_COMPILER_PLAN_RESULT_FINDING_LIMIT_DETAIL_MUTANT)
resultFindingLimitDetail _ _ = "mutated result-finding limit detail"
#else
resultFindingLimitDetail limit observed =
  limitDetail limit observed
    <> "; the oversized result was replaced before rendering"
#endif

observationEntryCountKey :: Text
#if defined(VALIDATION_COMPILER_PLAN_OBSERVATION_ENTRY_COUNT_KEY_MUTANT)
observationEntryCountKey = "mutated.entry-count"
#else
observationEntryCountKey = "component-plan.input.entry-count"
#endif

observationAggregateBytesKey :: Text
#if defined(VALIDATION_COMPILER_PLAN_OBSERVATION_AGGREGATE_BYTES_KEY_MUTANT)
observationAggregateBytesKey = "mutated.aggregate-bytes"
#else
observationAggregateBytesKey = "component-plan.input.aggregate-blob-bytes"
#endif

observationInventoryDigestKey :: Text
#if defined(VALIDATION_COMPILER_PLAN_OBSERVATION_INVENTORY_DIGEST_KEY_MUTANT)
observationInventoryDigestKey = "mutated.inventory-digest"
#else
observationInventoryDigestKey = "component-plan.input.inventory-sha256"
#endif

observationComponentCountKey :: Text
#if defined(VALIDATION_COMPILER_PLAN_OBSERVATION_COMPONENT_COUNT_KEY_MUTANT)
observationComponentCountKey = "mutated.component-count"
#else
observationComponentCountKey = "component-plan.derived.component-count"
#endif

observationAssignmentCountKey :: Text
#if defined(VALIDATION_COMPILER_PLAN_OBSERVATION_ASSIGNMENT_COUNT_KEY_MUTANT)
observationAssignmentCountKey = "mutated.assignment-count"
#else
observationAssignmentCountKey = "component-plan.derived.assignment-count"
#endif

observationProblemCountKey :: Text
#if defined(VALIDATION_COMPILER_PLAN_OBSERVATION_PROBLEM_COUNT_KEY_MUTANT)
observationProblemCountKey = "mutated.problem-count"
#else
observationProblemCountKey = "component-plan.derived.problem-count"
#endif

observationProjectionDigestKey :: Text
#if defined(VALIDATION_COMPILER_PLAN_OBSERVATION_PROJECTION_DIGEST_KEY_MUTANT)
observationProjectionDigestKey = "mutated.projection-digest"
#else
observationProjectionDigestKey = "component-plan.derived.projection-sha256"
#endif

observationDiagnosticStatusKey :: Text
#if defined(VALIDATION_COMPILER_PLAN_OBSERVATION_DIAGNOSTIC_STATUS_KEY_MUTANT)
observationDiagnosticStatusKey = "mutated.diagnostic-status"
#else
observationDiagnosticStatusKey = "component-plan.diagnostic-status"
#endif

rawComponentEntryFromTuple :: (FilePath, Text, Text, ByteString) -> RawComponentEntry
rawComponentEntryFromTuple (path, mode, objectIdentity, bytes) =
  RawComponentEntry
    (projectRawTuplePath path)
    (projectRawTupleMode mode)
    (projectRawTupleObjectIdentity objectIdentity)
    (projectRawTupleBytes bytes)

projectRawTuplePath :: FilePath -> FilePath
#if defined(VALIDATION_COMPILER_PLAN_RAW_TUPLE_PATH_MAPPING_MUTANT)
projectRawTuplePath _ = "mutated/raw-tuple-path"
#else
projectRawTuplePath = id
#endif

projectRawTupleMode :: Text -> Text
#if defined(VALIDATION_COMPILER_PLAN_RAW_TUPLE_MODE_MAPPING_MUTANT)
projectRawTupleMode _ = "100755"
#else
projectRawTupleMode = id
#endif

projectRawTupleObjectIdentity :: Text -> Text
#if defined(VALIDATION_COMPILER_PLAN_RAW_TUPLE_OBJECT_IDENTITY_MAPPING_MUTANT)
projectRawTupleObjectIdentity _ = Text.replicate 40 "0"
#else
projectRawTupleObjectIdentity = id
#endif

projectRawTupleBytes :: ByteString -> ByteString
#if defined(VALIDATION_COMPILER_PLAN_RAW_TUPLE_BYTES_MAPPING_MUTANT)
projectRawTupleBytes _ = "mutated raw tuple bytes"
#else
projectRawTupleBytes = id
#endif

resultCheckName :: Text
#if defined(VALIDATION_COMPILER_PLAN_RESULT_CHECK_NAME_MUTANT)
resultCheckName = "mutated-component-plan-diagnostic"
#else
resultCheckName = "compiler-component-plan-diagnostic"
#endif

projectEntryCountObservation :: Text -> Text
#if defined(VALIDATION_COMPILER_PLAN_OBSERVATION_ENTRY_COUNT_MUTANT)
projectEntryCountObservation _ = "mutated-entry-count"
#else
projectEntryCountObservation = id
#endif

projectAggregateBytesObservation :: Text -> Text
#if defined(VALIDATION_COMPILER_PLAN_OBSERVATION_AGGREGATE_BYTES_MUTANT)
projectAggregateBytesObservation _ = "mutated-aggregate-bytes"
#else
projectAggregateBytesObservation = id
#endif

projectInventoryDigestObservation :: Text -> Text
#if defined(VALIDATION_COMPILER_PLAN_OBSERVATION_INVENTORY_DIGEST_MUTANT)
projectInventoryDigestObservation _ = "mutated-inventory-digest"
#else
projectInventoryDigestObservation = id
#endif

projectComponentCountObservation :: Text -> Text
#if defined(VALIDATION_COMPILER_PLAN_OBSERVATION_COMPONENT_COUNT_MUTANT)
projectComponentCountObservation _ = "mutated-component-count"
#else
projectComponentCountObservation = id
#endif

projectAssignmentCountObservation :: Text -> Text
#if defined(VALIDATION_COMPILER_PLAN_OBSERVATION_ASSIGNMENT_COUNT_MUTANT)
projectAssignmentCountObservation _ = "mutated-assignment-count"
#else
projectAssignmentCountObservation = id
#endif

projectProblemCountObservation :: Text -> Text
#if defined(VALIDATION_COMPILER_PLAN_OBSERVATION_PROBLEM_COUNT_MUTANT)
projectProblemCountObservation _ = "mutated-problem-count"
#else
projectProblemCountObservation = id
#endif

projectProjectionDigestObservation :: Text -> Text
#if defined(VALIDATION_COMPILER_PLAN_OBSERVATION_PROJECTION_DIGEST_MUTANT)
projectProjectionDigestObservation _ = "mutated-projection-digest"
#else
projectProjectionDigestObservation = id
#endif

projectDiagnosticStatusObservation :: Text -> Text
#if defined(VALIDATION_COMPILER_PLAN_OBSERVATION_DIAGNOSTIC_STATUS_MUTANT)
projectDiagnosticStatusObservation _ = "mutated-status"
#else
projectDiagnosticStatusObservation = id
#endif

projectEntryCountObservationContribution :: Observation -> [Observation]
#if defined(VALIDATION_COMPILER_PLAN_OBSERVATION_ENTRY_COUNT_CONTRIBUTION_DROP_MUTANT)
projectEntryCountObservationContribution _ = []
#else
projectEntryCountObservationContribution = pure
#endif

projectAggregateBytesObservationContribution :: Observation -> [Observation]
#if defined(VALIDATION_COMPILER_PLAN_OBSERVATION_AGGREGATE_BYTES_CONTRIBUTION_DROP_MUTANT)
projectAggregateBytesObservationContribution _ = []
#else
projectAggregateBytesObservationContribution = pure
#endif

projectInventoryDigestObservationContribution :: Observation -> [Observation]
#if defined(VALIDATION_COMPILER_PLAN_OBSERVATION_INVENTORY_DIGEST_CONTRIBUTION_DROP_MUTANT)
projectInventoryDigestObservationContribution _ = []
#else
projectInventoryDigestObservationContribution = pure
#endif

projectComponentCountObservationContribution :: Observation -> [Observation]
#if defined(VALIDATION_COMPILER_PLAN_OBSERVATION_COMPONENT_COUNT_CONTRIBUTION_DROP_MUTANT)
projectComponentCountObservationContribution _ = []
#else
projectComponentCountObservationContribution = pure
#endif

projectAssignmentCountObservationContribution :: Observation -> [Observation]
#if defined(VALIDATION_COMPILER_PLAN_OBSERVATION_ASSIGNMENT_COUNT_CONTRIBUTION_DROP_MUTANT)
projectAssignmentCountObservationContribution _ = []
#else
projectAssignmentCountObservationContribution = pure
#endif

projectProblemCountObservationContribution :: Observation -> [Observation]
#if defined(VALIDATION_COMPILER_PLAN_OBSERVATION_PROBLEM_COUNT_CONTRIBUTION_DROP_MUTANT)
projectProblemCountObservationContribution _ = []
#else
projectProblemCountObservationContribution = pure
#endif

projectProjectionDigestObservationContribution :: Observation -> [Observation]
#if defined(VALIDATION_COMPILER_PLAN_OBSERVATION_PROJECTION_DIGEST_CONTRIBUTION_DROP_MUTANT)
projectProjectionDigestObservationContribution _ = []
#else
projectProjectionDigestObservationContribution = pure
#endif

projectDiagnosticStatusObservationContribution :: Observation -> [Observation]
#if defined(VALIDATION_COMPILER_PLAN_OBSERVATION_DIAGNOSTIC_STATUS_CONTRIBUTION_DROP_MUTANT)
projectDiagnosticStatusObservationContribution _ = []
#else
projectDiagnosticStatusObservationContribution = pure
#endif

projectMandatoryFindingsContribution :: [Finding] -> [Finding]
#if defined(VALIDATION_COMPILER_PLAN_RESULT_MANDATORY_FINDINGS_CONTRIBUTION_DROP_MUTANT)
projectMandatoryFindingsContribution _ = []
#else
projectMandatoryFindingsContribution = id
#endif

projectMandatoryFindingOrder :: [Finding] -> [Finding]
#if defined(VALIDATION_COMPILER_PLAN_RESULT_MANDATORY_FINDING_ORDER_MUTANT)
projectMandatoryFindingOrder = reverse
#else
projectMandatoryFindingOrder = id
#endif

projectCandidateFindingOrder :: [Finding] -> [Finding] -> [Finding]
#if defined(VALIDATION_COMPILER_PLAN_RESULT_CANDIDATE_FINDING_ORDER_MUTANT)
projectCandidateFindingOrder planFindings mandatoryFindings = mandatoryFindings <> planFindings
#else
projectCandidateFindingOrder planFindings mandatoryFindings = planFindings <> mandatoryFindings
#endif

projectResultLimitFindingContribution :: Finding -> [Finding]
#if defined(VALIDATION_COMPILER_PLAN_RESULT_LIMIT_FINDING_CONTRIBUTION_DROP_MUTANT)
projectResultLimitFindingContribution _ = []
#else
projectResultLimitFindingContribution = pure
#endif

projectResultLimitFindingOrder :: [Finding] -> [Finding] -> [Finding]
#if defined(VALIDATION_COMPILER_PLAN_RESULT_LIMIT_FINDING_ORDER_MUTANT)
projectResultLimitFindingOrder mandatoryFindings limitFindings = limitFindings <> mandatoryFindings
#else
projectResultLimitFindingOrder mandatoryFindings limitFindings = mandatoryFindings <> limitFindings
#endif

projectObservationOrder :: [Observation] -> [Observation]
#if defined(VALIDATION_COMPILER_PLAN_OBSERVATION_ORDER_MUTANT)
projectObservationOrder = reverse
#else
projectObservationOrder = id
#endif

projectResultObservations :: [Observation] -> [Observation]
#if defined(VALIDATION_COMPILER_PLAN_RESULT_OBSERVATIONS_PROJECTION_MUTANT)
projectResultObservations _ = []
#else
projectResultObservations = id
#endif

projectResultFindings :: [Finding] -> [Finding]
#if defined(VALIDATION_COMPILER_PLAN_RESULT_FINDINGS_PROJECTION_MUTANT)
projectResultFindings _ = []
#else
projectResultFindings = id
#endif

projectResultFindingOrder :: [Finding] -> [Finding]
#if defined(VALIDATION_COMPILER_PLAN_RESULT_FINDING_ORDER_MUTANT)
projectResultFindingOrder = reverse
#else
projectResultFindingOrder = id
#endif

data BoundedPrefix value
  = Bounded [value]
  | Exceeded Int

boundedPrefix :: Int -> [value] -> BoundedPrefix value
boundedPrefix limit = go 0 []
 where
  go count reversed remaining = case remaining of
    [] -> Bounded (reverse reversed)
    value : rest
      | boundedPrefixLimitReached count limit -> Exceeded (limit + 1)
      | otherwise -> go (count + 1) (value : reversed) rest

boundedPrefixLimitReached :: Int -> Int -> Bool
#if defined(VALIDATION_COMPILER_PLAN_BOUNDED_PREFIX_THRESHOLD_WIDEN_MUTANT)
boundedPrefixLimitReached count limit = count > limit
#else
boundedPrefixLimitReached count limit = count == limit
#endif

analyzeRawInventory :: Text -> [RawComponentEntry] -> RawAnalysis
analyzeRawInventory claimedIdentity entries = case boundedTextUtf8Bytes maxSnapshotIdentityBytes claimedIdentity of
  Exceeded observed
    | snapshotIdentityByteLimitExceeded observed ->
        rawFailure
          "unavailable"
          "unavailable"
          "unavailable"
          [ComponentPlanSnapshotIdentityByteLimitExceeded maxSnapshotIdentityBytes observed]
    | otherwise -> analyzeBoundedRawEntries claimedIdentity entries
  Bounded _ -> analyzeBoundedRawEntries claimedIdentity entries

analyzeBoundedRawEntries :: Text -> [RawComponentEntry] -> RawAnalysis
analyzeBoundedRawEntries claimedIdentity entries = case boundedPrefix maxSnapshotEntries entries of
  Exceeded observed | snapshotEntryLimitExceeded observed ->
    rawFailure
      (decimalText observed <> "+")
      "unavailable"
      "unavailable"
      [ComponentPlanSnapshotEntryLimitExceeded maxSnapshotEntries observed]
  Exceeded _ -> analyzeBoundedRawEntries claimedIdentity (take maxSnapshotEntries entries)
  Bounded boundedEntries ->
    let entryCount = length boundedEntries
        resourceProblems = concat (zipWith rawEntryResourceProblems [1 ..] boundedEntries)
        aggregateResult = boundedAggregateBytes boundedEntries
        aggregateProblems = case aggregateResult of
          Left observed -> [ComponentPlanAggregateBlobByteLimitExceeded maxAggregateBlobBytes observed]
          Right _ -> []
        grammarProblems =
          if rawResourceGateAllowsGrammar resourceProblems
            then concat (zipWith rawEntryGrammarProblems [1 ..] boundedEntries)
            else []
        inventoryProblems =
          if rawGrammarGateAllowsInventory resourceProblems grammarProblems
            then rawInventoryOrderProblems boundedEntries
            else []
        digest =
          if rawPreflightGateAllowsDigest resourceProblems grammarProblems inventoryProblems aggregateProblems
            then rawInventorySha256 boundedEntries
            else "unavailable"
        identityProblems =
          if rawDigestGateSuppressesIdentity digest
            then []
            else rawClaimedIdentityProblems claimedIdentity digest
        problems =
          projectRawResourceProblemContribution resourceProblems
            <> projectRawAggregateProblemContribution aggregateProblems
            <> projectRawGrammarProblemContribution grammarProblems
            <> projectRawInventoryProblemContribution inventoryProblems
            <> projectRawIdentityProblemContribution identityProblems
        aggregateText = either (const "unavailable") decimalText aggregateResult
     in if rawProblemsAllowDerivation problems
          then
            let snapshot =
                  SourceSnapshot
                    { snapshotRoot = "."
                    , snapshotIdentity = digest
                    , snapshotEntries = map rawTrackedEntry boundedEntries
                    }
             in RawAnalysis
                  { rawAnalysisPlan = deriveCompilerComponentPlan (projectRawSourceSnapshot snapshot)
                  , rawAnalysisEntryCount = decimalText entryCount
                  , rawAnalysisAggregateBytes = aggregateText
                  , rawAnalysisInventoryDigest = digest
                  }
          else rawFailure (decimalText entryCount) aggregateText digest problems

rawResourceGateAllowsGrammar :: [ComponentPlanProblem] -> Bool
#if defined(VALIDATION_COMPILER_PLAN_RAW_RESOURCE_GRAMMAR_GATE_BYPASS_MUTANT)
rawResourceGateAllowsGrammar _ = True
#else
rawResourceGateAllowsGrammar = null
#endif

rawGrammarGateAllowsInventory :: [ComponentPlanProblem] -> [ComponentPlanProblem] -> Bool
#if defined(VALIDATION_COMPILER_PLAN_RAW_GRAMMAR_INVENTORY_GATE_BYPASS_MUTANT)
rawGrammarGateAllowsInventory _ _ = True
#else
rawGrammarGateAllowsInventory resourceProblems grammarProblems = null resourceProblems && null grammarProblems
#endif

rawPreflightGateAllowsDigest
  :: [ComponentPlanProblem]
  -> [ComponentPlanProblem]
  -> [ComponentPlanProblem]
  -> [ComponentPlanProblem]
  -> Bool
#if defined(VALIDATION_COMPILER_PLAN_RAW_PREFLIGHT_DIGEST_GATE_BYPASS_MUTANT)
rawPreflightGateAllowsDigest _ _ _ _ = True
#else
rawPreflightGateAllowsDigest resourceProblems grammarProblems inventoryProblems aggregateProblems =
  null resourceProblems && null grammarProblems && null inventoryProblems && null aggregateProblems
#endif

rawDigestGateSuppressesIdentity :: Text -> Bool
#if defined(VALIDATION_COMPILER_PLAN_RAW_DIGEST_IDENTITY_GATE_BYPASS_MUTANT)
rawDigestGateSuppressesIdentity _ = False
#else
rawDigestGateSuppressesIdentity digest = digest == "unavailable"
#endif

rawProblemsAllowDerivation :: [ComponentPlanProblem] -> Bool
#if defined(VALIDATION_COMPILER_PLAN_RAW_PROBLEM_DERIVATION_GATE_BYPASS_MUTANT)
rawProblemsAllowDerivation _ = True
#else
rawProblemsAllowDerivation = null
#endif

projectRawResourceProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_RAW_RESOURCE_PROBLEMS_DROP_MUTANT)
projectRawResourceProblemContribution _ = []
#else
projectRawResourceProblemContribution = id
#endif

projectRawAggregateProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_RAW_AGGREGATE_PROBLEMS_DROP_MUTANT)
projectRawAggregateProblemContribution _ = []
#else
projectRawAggregateProblemContribution = id
#endif

projectRawGrammarProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_RAW_GRAMMAR_PROBLEMS_DROP_MUTANT)
projectRawGrammarProblemContribution _ = []
#else
projectRawGrammarProblemContribution = id
#endif

projectRawInventoryProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_RAW_INVENTORY_PROBLEMS_DROP_MUTANT)
projectRawInventoryProblemContribution _ = []
#else
projectRawInventoryProblemContribution = id
#endif

projectRawIdentityProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_RAW_IDENTITY_PROBLEMS_DROP_MUTANT)
projectRawIdentityProblemContribution _ = []
#else
projectRawIdentityProblemContribution = id
#endif

rawClaimedIdentityProblems :: Text -> Text -> [ComponentPlanProblem]
rawClaimedIdentityProblems observed expected =
  [ComponentPlanSnapshotIdentityMalformed observed | not (validSnapshotIdentity observed)]
    <> [ ComponentPlanSnapshotIdentityMismatch expected observed
       | validSnapshotIdentity observed
       , snapshotIdentityMismatch observed expected
       ]

snapshotIdentityMismatch :: Text -> Text -> Bool
#if defined(VALIDATION_COMPILER_PLAN_SNAPSHOT_IDENTITY_MATCH_BYPASS_MUTANT)
snapshotIdentityMismatch _ _ = False
#else
snapshotIdentityMismatch observed expected = observed /= expected
#endif

rawFailure :: Text -> Text -> Text -> [ComponentPlanProblem] -> RawAnalysis
rawFailure entryCount aggregateBytes digest problems =
  RawAnalysis
    { rawAnalysisPlan = emptyComponentPlan "unavailable" (finalizeProblems problems)
    , rawAnalysisEntryCount = entryCount
    , rawAnalysisAggregateBytes = aggregateBytes
    , rawAnalysisInventoryDigest = digest
    }

emptyComponentPlan :: Text -> [ComponentPlanProblem] -> CompilerComponentPlan
emptyComponentPlan identity problems = CompilerComponentPlan identity [] [] problems

rawEntryResourceProblems :: Int -> RawComponentEntry -> [ComponentPlanProblem]
rawEntryResourceProblems ordinal entry =
  projectRawPathResourceProblemContribution pathProblems
    <> projectRawModeResourceProblemContribution modeProblems
    <> projectRawObjectResourceProblemContribution objectProblems
    <> projectRawBlobResourceProblemContribution blobProblems
 where
  pathProblems = case boundedFilePathUtf8Bytes maxPathBytes (rawComponentPath entry) of
    Exceeded observed
      | pathByteLimitExceeded observed -> [ComponentPlanPathByteLimitExceeded ordinal maxPathBytes observed]
      | otherwise -> []
    Bounded _ -> []
  modeProblems = case boundedTextUtf8Bytes maxModeBytes (rawComponentMode entry) of
    Exceeded observed
      | modeByteLimitExceeded observed -> [ComponentPlanModeByteLimitExceeded ordinal maxModeBytes observed]
      | otherwise -> []
    Bounded _ -> []
  objectProblems = case boundedTextUtf8Bytes maxObjectIdentityBytes (rawComponentObjectIdentity entry) of
    Exceeded observed
      | objectIdentityByteLimitExceeded observed -> [ComponentPlanObjectIdentityByteLimitExceeded ordinal maxObjectIdentityBytes observed]
      | otherwise -> []
    Bounded _ -> []
  blobLength = ByteString.length (rawComponentBytes entry)
  blobProblems =
    [ ComponentPlanBlobByteLimitExceeded (safeProblemPath ordinal (rawComponentPath entry)) maxBlobBytes blobLength
    | blobLimitExceeded blobLength
    ]

rawEntryGrammarProblems :: Int -> RawComponentEntry -> [ComponentPlanProblem]
rawEntryGrammarProblems ordinal entry =
  projectRawPathGrammarProblemContribution (safePathProblems ordinal path)
    <> projectRawModeGrammarProblemContribution
      [ ComponentPlanModeMalformed path mode
      | not (acceptedRawMode mode)
      ]
    <> projectRawObjectShapeProblemContribution objectShapeProblems
    <> projectRawObjectContentProblemContribution objectContentProblems
 where
  path = rawComponentPath entry
  mode = rawComponentMode entry
  objectIdentity = rawComponentObjectIdentity entry
  objectShapeProblems =
    [ComponentPlanObjectIdentityMalformed path objectIdentity | not (validObjectIdentity objectIdentity)]
  objectContentProblems =
    [ ComponentPlanObjectIdentityMismatch path objectIdentity expected
    | null objectShapeProblems
    , let expected = gitBlobIdentity objectIdentity (rawComponentBytes entry)
    , objectIdentityMismatch objectIdentity expected
    ]

projectRawSourceSnapshot :: SourceSnapshot -> SourceSnapshot
#if defined(VALIDATION_COMPILER_PLAN_RAW_SOURCE_SNAPSHOT_MAPPING_MUTANT)
projectRawSourceSnapshot snapshot = snapshot {snapshotIdentity = "mutated-source-snapshot"}
#else
projectRawSourceSnapshot = id
#endif

projectRawPathResourceProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_RAW_PATH_RESOURCE_PROBLEMS_DROP_MUTANT)
projectRawPathResourceProblemContribution _ = []
#else
projectRawPathResourceProblemContribution = id
#endif

projectRawModeResourceProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_RAW_MODE_RESOURCE_PROBLEMS_DROP_MUTANT)
projectRawModeResourceProblemContribution _ = []
#else
projectRawModeResourceProblemContribution = id
#endif

projectRawObjectResourceProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_RAW_OBJECT_RESOURCE_PROBLEMS_DROP_MUTANT)
projectRawObjectResourceProblemContribution _ = []
#else
projectRawObjectResourceProblemContribution = id
#endif

projectRawBlobResourceProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_RAW_BLOB_RESOURCE_PROBLEMS_DROP_MUTANT)
projectRawBlobResourceProblemContribution _ = []
#else
projectRawBlobResourceProblemContribution = id
#endif

projectRawPathGrammarProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_RAW_PATH_GRAMMAR_PROBLEMS_DROP_MUTANT)
projectRawPathGrammarProblemContribution _ = []
#else
projectRawPathGrammarProblemContribution = id
#endif

projectRawModeGrammarProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_RAW_MODE_GRAMMAR_PROBLEMS_DROP_MUTANT)
projectRawModeGrammarProblemContribution _ = []
#else
projectRawModeGrammarProblemContribution = id
#endif

projectRawObjectShapeProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_RAW_OBJECT_SHAPE_PROBLEMS_DROP_MUTANT)
projectRawObjectShapeProblemContribution _ = []
#else
projectRawObjectShapeProblemContribution = id
#endif

projectRawObjectContentProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_RAW_OBJECT_CONTENT_PROBLEMS_DROP_MUTANT)
projectRawObjectContentProblemContribution _ = []
#else
projectRawObjectContentProblemContribution = id
#endif

rawInventoryOrderProblems :: [RawComponentEntry] -> [ComponentPlanProblem]
rawInventoryOrderProblems entries = duplicateProblems <> orderProblems
 where
  paths = map rawComponentPath entries
  ordered = sort paths
  duplicateProblems =
    [ ComponentPlanDuplicatePath path
    | repeated <- group ordered
    , path : _ : _ <- [repeated]
    , duplicatePathRejected
    ]
  orderProblems =
    [ ComponentPlanEntryOrderInvalid paths
    | entryOrderInvalid paths ordered
    ]

rawTrackedEntry :: RawComponentEntry -> TrackedEntry
rawTrackedEntry entry =
  TrackedEntry
    { trackedIndex =
        IndexEntry
          { indexPath = projectTrackedEntryPath (rawComponentPath entry)
          , indexMode = projectTrackedEntryMode (parseAcceptedMode (rawComponentMode entry))
          , indexObjectId = projectTrackedEntryObjectIdentity (rawComponentObjectIdentity entry)
          }
    , trackedBytes = projectTrackedEntryBytes (rawComponentBytes entry)
    }

projectTrackedEntryPath :: FilePath -> FilePath
#if defined(VALIDATION_COMPILER_PLAN_TRACKED_ENTRY_PATH_MAPPING_MUTANT)
projectTrackedEntryPath _ = "mutated/Tracked.hs"
#else
projectTrackedEntryPath = id
#endif

projectTrackedEntryMode :: IndexMode -> IndexMode
#if defined(VALIDATION_COMPILER_PLAN_TRACKED_ENTRY_MODE_MAPPING_MUTANT)
projectTrackedEntryMode _ = ExecutableFile
#else
projectTrackedEntryMode = id
#endif

projectTrackedEntryObjectIdentity :: Text -> Text
#if defined(VALIDATION_COMPILER_PLAN_TRACKED_ENTRY_OBJECT_IDENTITY_MAPPING_MUTANT)
projectTrackedEntryObjectIdentity _ = "mutated-tracked-object-identity"
#else
projectTrackedEntryObjectIdentity = id
#endif

projectTrackedEntryBytes :: ByteString -> ByteString
#if defined(VALIDATION_COMPILER_PLAN_TRACKED_ENTRY_BYTES_MAPPING_MUTANT)
projectTrackedEntryBytes _ = "mutated tracked bytes"
#else
projectTrackedEntryBytes = id
#endif

parseAcceptedMode :: Text -> IndexMode
parseAcceptedMode "100644" =
#if defined(VALIDATION_COMPILER_PLAN_PARSE_REGULAR_MODE_MAPPING_MUTANT)
  ExecutableFile
#else
  RegularFile
#endif
parseAcceptedMode "100755" =
#if defined(VALIDATION_COMPILER_PLAN_PARSE_EXECUTABLE_MODE_MAPPING_MUTANT)
  RegularFile
#else
  ExecutableFile
#endif
parseAcceptedMode "120000" =
#if defined(VALIDATION_COMPILER_PLAN_PARSE_SYMLINK_MODE_MAPPING_MUTANT)
  RegularFile
#else
  SymbolicLink
#endif
parseAcceptedMode _ = RegularFile

acceptedRawMode :: Text -> Bool
acceptedRawMode value = regular || executable || symbolic || widened
 where
  regular =
#if defined(VALIDATION_COMPILER_PLAN_MODE_REGULAR_ALTERNATIVE_MUTANT)
    False
#else
    value == "100644"
#endif
  executable =
#if defined(VALIDATION_COMPILER_PLAN_MODE_EXECUTABLE_ALTERNATIVE_MUTANT)
    False
#else
    value == "100755"
#endif
  symbolic =
#if defined(VALIDATION_COMPILER_PLAN_MODE_SYMLINK_ALTERNATIVE_MUTANT)
    False
#else
    value == "120000"
#endif
  widened =
#if defined(VALIDATION_COMPILER_PLAN_MODE_GRAMMAR_WIDEN_MUTANT)
    value == "100664"
#else
    False
#endif

validObjectIdentity :: Text -> Bool
validObjectIdentity value = acceptedLength && Text.all acceptedHex value
 where
  valueLength = Text.length value
  acceptedLength =
    sha1Length
      || sha256Length
      || length39Alternative
      || length41Alternative
      || length63Alternative
  sha1Length =
#if defined(VALIDATION_COMPILER_PLAN_OBJECT_SHA1_ALTERNATIVE_MUTANT)
    False
#else
    valueLength == 40
#endif
  sha256Length =
#if defined(VALIDATION_COMPILER_PLAN_OBJECT_SHA256_ALTERNATIVE_MUTANT)
    False
#else
    valueLength == 64
#endif
  length39Alternative =
#if defined(VALIDATION_COMPILER_PLAN_OBJECT_LENGTH_39_WIDEN_MUTANT)
    valueLength == 39
#else
    False
#endif
  length41Alternative =
#if defined(VALIDATION_COMPILER_PLAN_OBJECT_LENGTH_41_WIDEN_MUTANT)
    valueLength == 41
#else
    False
#endif
  length63Alternative =
#if defined(VALIDATION_COMPILER_PLAN_OBJECT_LENGTH_63_WIDEN_MUTANT)
    valueLength == 63
#else
    False
#endif
  acceptedHex character = digitAlternative || lowercaseAlternative || uppercaseAlternative || widenedAlternative
   where
    digitAlternative =
#if defined(VALIDATION_COMPILER_PLAN_OBJECT_DIGIT_ALTERNATIVE_DROP_MUTANT)
      False
#else
      isDigit character
#endif
    lowercaseAlternative =
#if defined(VALIDATION_COMPILER_PLAN_OBJECT_LOWER_HEX_ALTERNATIVE_DROP_MUTANT)
      False
#else
      character >= 'a' && character <= 'f'
#endif
    uppercaseAlternative =
#if defined(VALIDATION_COMPILER_PLAN_OBJECT_UPPERCASE_HEX_WIDEN_MUTANT)
      character >= 'A' && character <= 'F'
#else
      False
#endif
    widenedAlternative =
#if defined(VALIDATION_COMPILER_PLAN_OBJECT_HEX_GRAMMAR_WIDEN_MUTANT)
      character == 'g'
#else
      False
#endif

objectIdentityMismatch :: Text -> Text -> Bool
#if defined(VALIDATION_COMPILER_PLAN_OBJECT_CONTENT_BYPASS_MUTANT)
objectIdentityMismatch _ _ = False
#else
objectIdentityMismatch observed expected = observed /= expected
#endif

gitBlobIdentity :: Text -> ByteString -> Text
gitBlobIdentity shape bytes
  | gitBlobUsesSha1 shape =
      digestChunks
        (Crypto.hashInit :: Crypto.Context Crypto.SHA1)
        [gitBlobHeader bytes, gitBlobContent bytes]
  | otherwise =
      digestChunks
        (Crypto.hashInit :: Crypto.Context Crypto.SHA256)
        [gitBlobHeader bytes, gitBlobContent bytes]

gitBlobUsesSha1 :: Text -> Bool
gitBlobUsesSha1 shape = sha1Alternative || sha256AsSha1Alternative
 where
  sha1Alternative =
#if defined(VALIDATION_COMPILER_PLAN_GIT_BLOB_SHA1_ALGORITHM_MAPPING_MUTANT)
    shape `seq` False
#else
    Text.length shape == 40
#endif
  sha256AsSha1Alternative =
#if defined(VALIDATION_COMPILER_PLAN_GIT_BLOB_SHA256_ALGORITHM_MAPPING_MUTANT)
    Text.length shape == 64
#else
    False
#endif

gitBlobHeader :: ByteString -> ByteString
gitBlobHeader bytes = gitBlobDomain <> gitBlobLength bytes <> gitBlobTerminator

gitBlobDomain :: ByteString
#if defined(VALIDATION_COMPILER_PLAN_GIT_BLOB_DOMAIN_MUTANT)
gitBlobDomain = "mutated-blob "
#else
gitBlobDomain = "blob "
#endif

gitBlobLength :: ByteString -> ByteString
#if defined(VALIDATION_COMPILER_PLAN_GIT_BLOB_LENGTH_MUTANT)
gitBlobLength _ = "0"
#else
gitBlobLength = ByteString8.pack . show . ByteString.length
#endif

gitBlobTerminator :: ByteString
#if defined(VALIDATION_COMPILER_PLAN_GIT_BLOB_TERMINATOR_MUTANT)
gitBlobTerminator = "!"
#else
gitBlobTerminator = "\0"
#endif

gitBlobContent :: ByteString -> ByteString
#if defined(VALIDATION_COMPILER_PLAN_GIT_BLOB_CONTENT_MUTANT)
gitBlobContent _ = ""
#else
gitBlobContent = id
#endif

rawInventorySha256 :: [RawComponentEntry] -> Text
rawInventorySha256 entries =
  digestChunks
    (Crypto.hashInit :: Crypto.Context Crypto.SHA256)
    (rawInventoryDigestDomain : concatMap rawEntryChunks entries)

rawInventoryDigestDomain :: ByteString
#if defined(VALIDATION_COMPILER_PLAN_RAW_DIGEST_DOMAIN_MUTANT)
rawInventoryDigestDomain = "amoebius.compiler-component-plan.raw.mutant\0"
#else
rawInventoryDigestDomain = "amoebius.compiler-component-plan.raw.v1\0"
#endif

rawEntryChunks :: RawComponentEntry -> [ByteString]
rawEntryChunks entry =
  [ rawDigestMode entry
  , rawDigestModeSeparator
  , rawDigestObjectIdentity entry
  , rawDigestObjectSeparator
  , rawDigestPath entry
  , rawDigestPathSeparator
  , rawDigestBlobLength entry
  , rawDigestBlobLengthSeparator
  , rawDigestBlobBytes entry
  , rawDigestEntryTerminator
  ]

rawDigestMode :: RawComponentEntry -> ByteString
#if defined(VALIDATION_COMPILER_PLAN_RAW_DIGEST_MODE_MUTANT)
rawDigestMode _ = "mutated-mode"
#else
rawDigestMode = TextEncoding.encodeUtf8 . rawComponentMode
#endif

rawDigestModeSeparator :: ByteString
#if defined(VALIDATION_COMPILER_PLAN_RAW_DIGEST_MODE_SEPARATOR_MUTANT)
rawDigestModeSeparator = "!"
#else
rawDigestModeSeparator = "\0"
#endif

rawDigestObjectIdentity :: RawComponentEntry -> ByteString
#if defined(VALIDATION_COMPILER_PLAN_RAW_DIGEST_OBJECT_IDENTITY_MUTANT)
rawDigestObjectIdentity _ = "mutated-object"
#else
rawDigestObjectIdentity = TextEncoding.encodeUtf8 . rawComponentObjectIdentity
#endif

rawDigestObjectSeparator :: ByteString
#if defined(VALIDATION_COMPILER_PLAN_RAW_DIGEST_OBJECT_SEPARATOR_MUTANT)
rawDigestObjectSeparator = "!"
#else
rawDigestObjectSeparator = "\0"
#endif

rawDigestPath :: RawComponentEntry -> ByteString
#if defined(VALIDATION_COMPILER_PLAN_RAW_DIGEST_PATH_MUTANT)
rawDigestPath _ = "mutated-path"
#else
rawDigestPath = TextEncoding.encodeUtf8 . Text.pack . rawComponentPath
#endif

rawDigestPathSeparator :: ByteString
#if defined(VALIDATION_COMPILER_PLAN_RAW_DIGEST_PATH_SEPARATOR_MUTANT)
rawDigestPathSeparator = "!"
#else
rawDigestPathSeparator = "\0"
#endif

rawDigestBlobLength :: RawComponentEntry -> ByteString
#if defined(VALIDATION_COMPILER_PLAN_RAW_DIGEST_BLOB_LENGTH_MUTANT)
rawDigestBlobLength _ = "0"
#else
rawDigestBlobLength = ByteString8.pack . show . ByteString.length . rawComponentBytes
#endif

rawDigestBlobLengthSeparator :: ByteString
#if defined(VALIDATION_COMPILER_PLAN_RAW_DIGEST_BLOB_LENGTH_SEPARATOR_MUTANT)
rawDigestBlobLengthSeparator = "!"
#else
rawDigestBlobLengthSeparator = "\0"
#endif

rawDigestBlobBytes :: RawComponentEntry -> ByteString
#if defined(VALIDATION_COMPILER_PLAN_RAW_DIGEST_BLOB_BYTES_MUTANT)
rawDigestBlobBytes _ = ""
#else
rawDigestBlobBytes = rawComponentBytes
#endif

rawDigestEntryTerminator :: ByteString
#if defined(VALIDATION_COMPILER_PLAN_RAW_DIGEST_ENTRY_TERMINATOR_MUTANT)
rawDigestEntryTerminator = "!"
#else
rawDigestEntryTerminator = "\0"
#endif

componentPlanProjectionSha256 :: CompilerComponentPlan -> Text
componentPlanProjectionSha256 plan =
  digestChunks
    (Crypto.hashInit :: Crypto.Context Crypto.SHA256)
    ( projectionDigestDomain
        : projectionSnapshotIdentityChunks plan
        <> projectionComponentChunks plan
        <> projectionAssignmentListChunks plan
        <> projectionProblemChunks plan
    )

projectionDigestDomain :: ByteString
#if defined(VALIDATION_COMPILER_PLAN_PROJECTION_DIGEST_DOMAIN_MUTANT)
projectionDigestDomain = "amoebius.compiler-component-plan.projection.mutant\0"
#else
projectionDigestDomain = "amoebius.compiler-component-plan.projection.v1\0"
#endif

projectionSnapshotIdentityChunks :: CompilerComponentPlan -> [ByteString]
#if defined(VALIDATION_COMPILER_PLAN_PROJECTION_SNAPSHOT_IDENTITY_CONTRIBUTION_MUTANT)
projectionSnapshotIdentityChunks _ = []
#else
projectionSnapshotIdentityChunks = fieldChunk . componentPlanSnapshotIdentity
#endif

projectionComponentChunks :: CompilerComponentPlan -> [ByteString]
#if defined(VALIDATION_COMPILER_PLAN_PROJECTION_COMPONENTS_CONTRIBUTION_MUTANT)
projectionComponentChunks _ = []
#else
projectionComponentChunks = concatMap fieldChunk . componentPlanComponents
#endif

projectionAssignmentListChunks :: CompilerComponentPlan -> [ByteString]
#if defined(VALIDATION_COMPILER_PLAN_PROJECTION_ASSIGNMENTS_CONTRIBUTION_MUTANT)
projectionAssignmentListChunks plan =
  let original = concatMap assignmentChunks (componentPlanAssignments plan)
   in original `seq` []
#else
projectionAssignmentListChunks = concatMap assignmentChunks . componentPlanAssignments
#endif

projectionProblemChunks :: CompilerComponentPlan -> [ByteString]
#if defined(VALIDATION_COMPILER_PLAN_PROJECTION_PROBLEMS_CONTRIBUTION_MUTANT)
projectionProblemChunks _ = []
#else
projectionProblemChunks = concatMap (fieldChunk . renderComponentPlanProblem) . componentPlanProblems
#endif

assignmentChunks :: ComponentAssignment -> [ByteString]
assignmentChunks assignment =
  projectionAssignmentNameChunks assignment
    <> projectionAssignmentKindChunks assignment
    <> projectionAssignmentSubjectPathChunks assignment
    <> projectionAssignmentSubjectModeChunks assignment
    <> projectionAssignmentSubjectObjectChunks assignment
    <> projectionAssignmentModuleChunks assignment
    <> projectionAssignmentConfigChunks assignment

projectionAssignmentNameChunks :: ComponentAssignment -> [ByteString]
#if defined(VALIDATION_COMPILER_PLAN_PROJECTION_ASSIGNMENT_NAME_CONTRIBUTION_MUTANT)
projectionAssignmentNameChunks _ = []
#else
projectionAssignmentNameChunks = fieldChunk . componentAssignmentName
#endif

projectionAssignmentKindChunks :: ComponentAssignment -> [ByteString]
#if defined(VALIDATION_COMPILER_PLAN_PROJECTION_ASSIGNMENT_KIND_CONTRIBUTION_MUTANT)
projectionAssignmentKindChunks assignment =
  let original = fieldChunk (renderComponentKind (componentAssignmentKind assignment))
   in original `seq` []
#else
projectionAssignmentKindChunks = fieldChunk . renderComponentKind . componentAssignmentKind
#endif

projectionAssignmentSubjectPathChunks :: ComponentAssignment -> [ByteString]
#if defined(VALIDATION_COMPILER_PLAN_PROJECTION_ASSIGNMENT_SUBJECT_PATH_CONTRIBUTION_MUTANT)
projectionAssignmentSubjectPathChunks _ = []
#else
projectionAssignmentSubjectPathChunks = fieldChunk . Text.pack . haskellSubjectPath . componentAssignmentSubject
#endif

projectionAssignmentSubjectModeChunks :: ComponentAssignment -> [ByteString]
#if defined(VALIDATION_COMPILER_PLAN_PROJECTION_ASSIGNMENT_SUBJECT_MODE_CONTRIBUTION_MUTANT)
projectionAssignmentSubjectModeChunks assignment =
  let original = fieldChunk (renderIndexMode (haskellSubjectMode (componentAssignmentSubject assignment)))
   in original `seq` []
#else
projectionAssignmentSubjectModeChunks = fieldChunk . renderIndexMode . haskellSubjectMode . componentAssignmentSubject
#endif

projectionAssignmentSubjectObjectChunks :: ComponentAssignment -> [ByteString]
#if defined(VALIDATION_COMPILER_PLAN_PROJECTION_ASSIGNMENT_SUBJECT_OBJECT_CONTRIBUTION_MUTANT)
projectionAssignmentSubjectObjectChunks _ = []
#else
projectionAssignmentSubjectObjectChunks = fieldChunk . haskellSubjectObjectId . componentAssignmentSubject
#endif

projectionAssignmentModuleChunks :: ComponentAssignment -> [ByteString]
#if defined(VALIDATION_COMPILER_PLAN_PROJECTION_ASSIGNMENT_MODULES_CONTRIBUTION_MUTANT)
projectionAssignmentModuleChunks _ = []
#else
projectionAssignmentModuleChunks = concatMap fieldChunk . componentAssignmentDeclaredModules
#endif

projectionAssignmentConfigChunks :: ComponentAssignment -> [ByteString]
#if defined(VALIDATION_COMPILER_PLAN_PROJECTION_ASSIGNMENT_CONFIGS_CONTRIBUTION_MUTANT)
projectionAssignmentConfigChunks assignment =
  let original = concatMap configChunks (componentAssignmentConfigs assignment)
   in original `seq` []
#else
projectionAssignmentConfigChunks = concatMap configChunks . componentAssignmentConfigs
#endif

configChunks :: ComponentCompilerConfig -> [ByteString]
configChunks config =
  projectionConfigSourceDirectoryChunks config
    <> projectionConfigLanguageChunks config
    <> projectionConfigExtensionChunks config
    <> projectionConfigGhcOptionChunks config
    <> projectionConfigCppOptionChunks config
    <> projectionConfigDependencyChunks config

projectionConfigSourceDirectoryChunks :: ComponentCompilerConfig -> [ByteString]
#if defined(VALIDATION_COMPILER_PLAN_PROJECTION_CONFIG_SOURCE_DIRECTORIES_CONTRIBUTION_MUTANT)
projectionConfigSourceDirectoryChunks _ = []
#else
projectionConfigSourceDirectoryChunks = concatMap (fieldChunk . Text.pack) . componentConfigSourceDirs
#endif

projectionConfigLanguageChunks :: ComponentCompilerConfig -> [ByteString]
#if defined(VALIDATION_COMPILER_PLAN_PROJECTION_CONFIG_LANGUAGE_CONTRIBUTION_MUTANT)
projectionConfigLanguageChunks _ = []
#else
projectionConfigLanguageChunks = maybe (fieldChunk "<none>") fieldChunk . componentConfigDefaultLanguage
#endif

projectionConfigExtensionChunks :: ComponentCompilerConfig -> [ByteString]
#if defined(VALIDATION_COMPILER_PLAN_PROJECTION_CONFIG_EXTENSIONS_CONTRIBUTION_MUTANT)
projectionConfigExtensionChunks _ = []
#else
projectionConfigExtensionChunks = concatMap fieldChunk . componentConfigExtensions
#endif

projectionConfigGhcOptionChunks :: ComponentCompilerConfig -> [ByteString]
#if defined(VALIDATION_COMPILER_PLAN_PROJECTION_CONFIG_GHC_OPTIONS_CONTRIBUTION_MUTANT)
projectionConfigGhcOptionChunks _ = []
#else
projectionConfigGhcOptionChunks = concatMap fieldChunk . componentConfigGhcOptions
#endif

projectionConfigCppOptionChunks :: ComponentCompilerConfig -> [ByteString]
#if defined(VALIDATION_COMPILER_PLAN_PROJECTION_CONFIG_CPP_OPTIONS_CONTRIBUTION_MUTANT)
projectionConfigCppOptionChunks _ = []
#else
projectionConfigCppOptionChunks = concatMap fieldChunk . componentConfigCppOptions
#endif

projectionConfigDependencyChunks :: ComponentCompilerConfig -> [ByteString]
#if defined(VALIDATION_COMPILER_PLAN_PROJECTION_CONFIG_DEPENDENCIES_CONTRIBUTION_MUTANT)
projectionConfigDependencyChunks _ = []
#else
projectionConfigDependencyChunks = concatMap fieldChunk . componentConfigDependencies
#endif

fieldChunk :: Text -> [ByteString]
fieldChunk value =
  [ fieldFrameLength encoded
  , fieldFrameColon
  , fieldFrameValue encoded
  , fieldFrameTerminator
  ]
 where
  encoded = TextEncoding.encodeUtf8 value

fieldFrameLength :: ByteString -> ByteString
#if defined(VALIDATION_COMPILER_PLAN_PROJECTION_FIELD_FRAME_LENGTH_MUTANT)
fieldFrameLength _ = "0"
#else
fieldFrameLength = ByteString8.pack . show . ByteString.length
#endif

fieldFrameColon :: ByteString
#if defined(VALIDATION_COMPILER_PLAN_PROJECTION_FIELD_FRAME_COLON_MUTANT)
fieldFrameColon = "!"
#else
fieldFrameColon = ":"
#endif

fieldFrameValue :: ByteString -> ByteString
#if defined(VALIDATION_COMPILER_PLAN_PROJECTION_FIELD_FRAME_VALUE_MUTANT)
fieldFrameValue _ = "mutated-field"
#else
fieldFrameValue = id
#endif

fieldFrameTerminator :: ByteString
#if defined(VALIDATION_COMPILER_PLAN_PROJECTION_FIELD_FRAME_TERMINATOR_MUTANT)
fieldFrameTerminator = "!"
#else
fieldFrameTerminator = "\0"
#endif

renderIndexMode :: IndexMode -> Text
renderIndexMode RegularFile =
#if defined(VALIDATION_COMPILER_PLAN_PROJECTION_MODE_REGULAR_RENDER_MUTANT)
  "mutated-regular"
#else
  "100644"
#endif
renderIndexMode ExecutableFile =
#if defined(VALIDATION_COMPILER_PLAN_PROJECTION_MODE_EXECUTABLE_RENDER_MUTANT)
  "mutated-executable"
#else
  "100755"
#endif
renderIndexMode SymbolicLink =
#if defined(VALIDATION_COMPILER_PLAN_PROJECTION_MODE_SYMLINK_RENDER_MUTANT)
  "mutated-symlink"
#else
  "120000"
#endif

renderComponentKind :: ComponentKind -> Text
renderComponentKind MainLibraryComponent =
#if defined(VALIDATION_COMPILER_PLAN_PROJECTION_KIND_MAIN_LIBRARY_RENDER_MUTANT)
  "mutated-main-library"
#else
  "main-library"
#endif
renderComponentKind NamedLibraryComponent =
#if defined(VALIDATION_COMPILER_PLAN_PROJECTION_KIND_NAMED_LIBRARY_RENDER_MUTANT)
  "mutated-named-library"
#else
  "named-library"
#endif
renderComponentKind ExecutableComponent =
#if defined(VALIDATION_COMPILER_PLAN_PROJECTION_KIND_EXECUTABLE_RENDER_MUTANT)
  "mutated-executable"
#else
  "executable"
#endif
renderComponentKind TestComponent =
#if defined(VALIDATION_COMPILER_PLAN_PROJECTION_KIND_TEST_RENDER_MUTANT)
  "mutated-test"
#else
  "test"
#endif
renderComponentKind BenchmarkComponent =
#if defined(VALIDATION_COMPILER_PLAN_PROJECTION_KIND_BENCHMARK_RENDER_MUTANT)
  "mutated-benchmark"
#else
  "benchmark"
#endif

renderComponentCompilerConfig :: ComponentCompilerConfig -> Text
renderComponentCompilerConfig config =
  "source-dirs=" <> renderConfigSourceDirectories config
    <> "; default-language=" <> renderConfigLanguage config
    <> "; extensions=" <> renderConfigExtensions config
    <> "; ghc-options=" <> renderConfigGhcOptions config
    <> "; cpp-options=" <> renderConfigCppOptions config
    <> "; dependencies=" <> renderConfigDependencies config

renderConfigSourceDirectories :: ComponentCompilerConfig -> Text
#if defined(VALIDATION_COMPILER_PLAN_RENDER_CONFIG_SOURCE_DIRECTORIES_MUTANT)
renderConfigSourceDirectories _ = "mutated-source-directories"
#else
renderConfigSourceDirectories = shown . componentConfigSourceDirs
#endif

renderConfigLanguage :: ComponentCompilerConfig -> Text
#if defined(VALIDATION_COMPILER_PLAN_RENDER_CONFIG_LANGUAGE_MUTANT)
renderConfigLanguage _ = "mutated-language"
#else
renderConfigLanguage = shown . componentConfigDefaultLanguage
#endif

renderConfigExtensions :: ComponentCompilerConfig -> Text
#if defined(VALIDATION_COMPILER_PLAN_RENDER_CONFIG_EXTENSIONS_MUTANT)
renderConfigExtensions _ = "mutated-extensions"
#else
renderConfigExtensions = shown . componentConfigExtensions
#endif

renderConfigGhcOptions :: ComponentCompilerConfig -> Text
#if defined(VALIDATION_COMPILER_PLAN_RENDER_CONFIG_GHC_OPTIONS_MUTANT)
renderConfigGhcOptions _ = "mutated-ghc-options"
#else
renderConfigGhcOptions = shown . componentConfigGhcOptions
#endif

renderConfigCppOptions :: ComponentCompilerConfig -> Text
#if defined(VALIDATION_COMPILER_PLAN_RENDER_CONFIG_CPP_OPTIONS_MUTANT)
renderConfigCppOptions _ = "mutated-cpp-options"
#else
renderConfigCppOptions = shown . componentConfigCppOptions
#endif

renderConfigDependencies :: ComponentCompilerConfig -> Text
#if defined(VALIDATION_COMPILER_PLAN_RENDER_CONFIG_DEPENDENCIES_MUTANT)
renderConfigDependencies _ = "mutated-dependencies"
#else
renderConfigDependencies = shown . componentConfigDependencies
#endif

digestChunks
  :: Crypto.HashAlgorithm algorithm
  => Crypto.Context algorithm
  -> [ByteString]
  -> Text
digestChunks initial chunks =
  Text.pack (show (Crypto.hashFinalize (foldl' Crypto.hashUpdate initial chunks)))

boundedAggregateBytes :: [RawComponentEntry] -> Either Int Int
boundedAggregateBytes = go 0
 where
  go total remaining = case remaining of
    [] -> Right total
    entry : rest ->
      let size = ByteString.length (rawComponentBytes entry)
       in if aggregateAdditionExceedsLimit total size
            then
              if aggregateBlobLimitExceeded (maxAggregateBlobBytes + 1)
                then Left (maxAggregateBlobBytes + 1)
                else go total rest
            else go (rawAggregateNextTotal total size) rest

rawAggregateNextTotal :: Int -> Int -> Int
#if defined(VALIDATION_COMPILER_PLAN_RAW_AGGREGATE_TOTAL_ACCUMULATION_MUTANT)
rawAggregateNextTotal total size = total + size + 1
#else
rawAggregateNextTotal total size = total + size
#endif

aggregateAdditionExceedsLimit :: Int -> Int -> Bool
#if defined(VALIDATION_COMPILER_PLAN_AGGREGATE_ADDITION_THRESHOLD_WIDEN_MUTANT)
aggregateAdditionExceedsLimit total size = size > maxAggregateBlobBytes - total + 1
#else
aggregateAdditionExceedsLimit total size = size > maxAggregateBlobBytes - total
#endif

boundedFilePathUtf8Bytes :: Int -> FilePath -> BoundedPrefix Char
boundedFilePathUtf8Bytes limit = boundedUtf8Chars limit

boundedTextUtf8Bytes :: Int -> Text -> BoundedPrefix Char
boundedTextUtf8Bytes limit = boundedUtf8Chars limit . Text.unpack

boundedUtf8Chars :: Int -> [Char] -> BoundedPrefix Char
boundedUtf8Chars limit = go 0 []
 where
  go count reversed remaining = case remaining of
    [] -> Bounded (reverse reversed)
    character : rest ->
      let next = utf8NextTotal count (utf8Width character)
       in if utf8LimitExceeded next limit
            then Exceeded next
            else go next (character : reversed) rest

utf8NextTotal :: Int -> Int -> Int
#if defined(VALIDATION_COMPILER_PLAN_UTF8_TOTAL_ACCUMULATION_MUTANT)
utf8NextTotal count width = count + width + 1
#else
utf8NextTotal count width = count + width
#endif

utf8LimitExceeded :: Int -> Int -> Bool
#if defined(VALIDATION_COMPILER_PLAN_UTF8_THRESHOLD_WIDEN_MUTANT)
utf8LimitExceeded next limit = next > limit + 1
#else
utf8LimitExceeded next limit = next > limit
#endif

utf8Width :: Char -> Int
utf8Width character
  | ord character <= 0x7f = utf8AsciiWidth
  | ord character <= 0x7ff = utf8TwoByteWidth
  | ord character <= 0xffff = utf8ThreeByteWidth
  | otherwise = utf8FourByteWidth

utf8AsciiWidth, utf8TwoByteWidth, utf8ThreeByteWidth, utf8FourByteWidth :: Int
#if defined(VALIDATION_COMPILER_PLAN_UTF8_ASCII_WIDTH_MUTANT)
utf8AsciiWidth = 0
#else
utf8AsciiWidth = 1
#endif
#if defined(VALIDATION_COMPILER_PLAN_UTF8_TWO_BYTE_WIDTH_MUTANT)
utf8TwoByteWidth = 1
#else
utf8TwoByteWidth = 2
#endif
#if defined(VALIDATION_COMPILER_PLAN_UTF8_THREE_BYTE_WIDTH_MUTANT)
utf8ThreeByteWidth = 2
#else
utf8ThreeByteWidth = 3
#endif
#if defined(VALIDATION_COMPILER_PLAN_UTF8_FOUR_BYTE_WIDTH_MUTANT)
utf8FourByteWidth = 3
#else
utf8FourByteWidth = 4
#endif

safeProblemPath :: Int -> FilePath -> FilePath
safeProblemPath ordinal path = case boundedFilePathUtf8Bytes maxPathBytes path of
  Bounded _ -> path
  Exceeded _ ->
#if defined(VALIDATION_COMPILER_PLAN_SAFE_PROBLEM_PATH_FALLBACK_MUTANT)
    ordinal `seq` "<mutated-over-limit-path>"
#else
    "<entry-" <> show ordinal <> "-path-over-limit>"
#endif

safePathProblems :: Int -> FilePath -> [ComponentPlanProblem]
safePathProblems ordinal path =
  [ComponentPlanPathEmpty ordinal | pathEmptyRejected path]
    <> [ComponentPlanPathAbsolute path | pathAbsoluteRejected path]
    <> [ComponentPlanPathNul path | pathNulRejected path]
    <> [ComponentPlanPathBackslash path | pathBackslashRejected path]
    <> [ComponentPlanPathEmptySegment path | pathEmptySegmentRejected path]
    <> [ComponentPlanPathDotSegment path | pathDotSegmentRejected path]
    <> [ComponentPlanPathParentSegment path | pathParentSegmentRejected path]
    <> [ComponentPlanPathCharacterUnsafe path | pathCharacterRejected path]

pathEmptyRejected, pathAbsoluteRejected, pathNulRejected, pathBackslashRejected :: FilePath -> Bool
#if defined(VALIDATION_COMPILER_PLAN_PATH_EMPTY_BYPASS_MUTANT)
pathEmptyRejected _ = False
#else
pathEmptyRejected = null
#endif
#if defined(VALIDATION_COMPILER_PLAN_PATH_ABSOLUTE_BYPASS_MUTANT)
pathAbsoluteRejected _ = False
#else
pathAbsoluteRejected path = take 1 path == "/"
#endif
#if defined(VALIDATION_COMPILER_PLAN_PATH_NUL_BYPASS_MUTANT)
pathNulRejected _ = False
#else
pathNulRejected = elem '\0'
#endif
#if defined(VALIDATION_COMPILER_PLAN_PATH_BACKSLASH_BYPASS_MUTANT)
pathBackslashRejected _ = False
#else
pathBackslashRejected = elem '\\'
#endif

pathEmptySegmentRejected, pathDotSegmentRejected, pathParentSegmentRejected :: FilePath -> Bool
#if defined(VALIDATION_COMPILER_PLAN_PATH_EMPTY_SEGMENT_BYPASS_MUTANT)
pathEmptySegmentRejected _ = False
#else
pathEmptySegmentRejected path = not (null path) && take 1 path /= "/" && any null (splitPosix path)
#endif
#if defined(VALIDATION_COMPILER_PLAN_PATH_DOT_SEGMENT_BYPASS_MUTANT)
pathDotSegmentRejected _ = False
#else
pathDotSegmentRejected path = "." `elem` splitPosix path
#endif
#if defined(VALIDATION_COMPILER_PLAN_PATH_PARENT_SEGMENT_BYPASS_MUTANT)
pathParentSegmentRejected _ = False
#else
pathParentSegmentRejected path = ".." `elem` splitPosix path
#endif

pathCharacterRejected :: FilePath -> Bool
#if defined(VALIDATION_COMPILER_PLAN_PATH_CHARACTER_WIDEN_MUTANT)
pathCharacterRejected path = '\0' `notElem` path && '\\' `notElem` path && any (not . accepted) path
 where
  accepted character = safePathCharacter character || character == ':'
#else
pathCharacterRejected path = '\0' `notElem` path && '\\' `notElem` path && any (not . safePathCharacter) path
#endif

safePathCharacter :: Char -> Bool
safePathCharacter character =
  lowercaseAlternative
    || uppercaseAlternative
    || digitAlternative
    || dotAlternative
    || underscoreAlternative
    || plusAlternative
    || atAlternative
    || slashAlternative
    || equalAlternative
    || hyphenAlternative
 where
  lowercaseAlternative =
    isAsciiLower character && pathLowercaseAlternativeRetained
  uppercaseAlternative =
#if defined(VALIDATION_COMPILER_PLAN_PATH_UPPERCASE_ALTERNATIVE_DROP_MUTANT)
    False
#else
    isAsciiUpper character
#endif
  digitAlternative =
#if defined(VALIDATION_COMPILER_PLAN_PATH_DIGIT_ALTERNATIVE_DROP_MUTANT)
    False
#else
    isDigit character
#endif
  dotAlternative =
#if defined(VALIDATION_COMPILER_PLAN_PATH_DOT_CHARACTER_ALTERNATIVE_DROP_MUTANT)
    False
#else
    character == '.'
#endif
  underscoreAlternative =
#if defined(VALIDATION_COMPILER_PLAN_PATH_UNDERSCORE_ALTERNATIVE_DROP_MUTANT)
    False
#else
    character == '_'
#endif
  plusAlternative =
#if defined(VALIDATION_COMPILER_PLAN_PATH_PLUS_ALTERNATIVE_DROP_MUTANT)
    False
#else
    character == '+'
#endif
  atAlternative =
#if defined(VALIDATION_COMPILER_PLAN_PATH_AT_ALTERNATIVE_DROP_MUTANT)
    False
#else
    character == '@'
#endif
  slashAlternative =
#if defined(VALIDATION_COMPILER_PLAN_PATH_SLASH_ALTERNATIVE_DROP_MUTANT)
    False
#else
    character == '/'
#endif
  equalAlternative =
#if defined(VALIDATION_COMPILER_PLAN_PATH_EQUAL_ALTERNATIVE_DROP_MUTANT)
    False
#else
    character == '='
#endif
  hyphenAlternative =
#if defined(VALIDATION_COMPILER_PLAN_PATH_HYPHEN_ALTERNATIVE_DROP_MUTANT)
    False
#else
    character == '-'
#endif

pathLowercaseAlternativeRetained :: Bool
#if defined(VALIDATION_COMPILER_PLAN_PATH_LOWERCASE_ALTERNATIVE_DROP_MUTANT)
pathLowercaseAlternativeRetained = False
#else
pathLowercaseAlternativeRetained = True
#endif

safeDeclarationPath :: FilePath -> Bool
safeDeclarationPath "." =
#if defined(VALIDATION_COMPILER_PLAN_DECLARATION_DOT_PATH_ALTERNATIVE_DROP_MUTANT)
  False
#else
  True
#endif
safeDeclarationPath path =
#if defined(VALIDATION_COMPILER_PLAN_DECLARATION_GRAMMAR_BYPASS_MUTANT)
  path `seq` True
#else
  not (pathEmptyRejected path)
    && not (pathAbsoluteRejected path)
    && not (pathNulRejected path)
    && not (pathBackslashRejected path)
    && not (pathEmptySegmentRejected path)
    && not (pathDotSegmentRejected path)
    && not (pathParentSegmentRejected path)
    && not (pathCharacterRejected path)
#endif

splitPosix :: FilePath -> [FilePath]
splitPosix value = case break (== '/') value of
  (part, []) -> [part]
  (part, _ : rest) -> part : splitPosix rest

blobLimitExceeded, aggregateBlobLimitExceeded :: Int -> Bool
#if defined(VALIDATION_COMPILER_PLAN_BLOB_LIMIT_BYPASS_MUTANT)
blobLimitExceeded _ = False
#else
blobLimitExceeded observed = observed > maxBlobBytes
#endif
#if defined(VALIDATION_COMPILER_PLAN_AGGREGATE_BLOB_LIMIT_BYPASS_MUTANT)
aggregateBlobLimitExceeded _ = False
#else
aggregateBlobLimitExceeded observed = observed > maxAggregateBlobBytes
#endif

snapshotEntryLimitExceeded, pathByteLimitExceeded, modeByteLimitExceeded, objectIdentityByteLimitExceeded :: Int -> Bool
#if defined(VALIDATION_COMPILER_PLAN_ENTRY_LIMIT_BYPASS_MUTANT)
snapshotEntryLimitExceeded _ = False
#else
snapshotEntryLimitExceeded observed = observed > maxSnapshotEntries
#endif
#if defined(VALIDATION_COMPILER_PLAN_PATH_BYTE_LIMIT_BYPASS_MUTANT)
pathByteLimitExceeded _ = False
#else
pathByteLimitExceeded observed = observed > maxPathBytes
#endif
#if defined(VALIDATION_COMPILER_PLAN_MODE_BYTE_LIMIT_BYPASS_MUTANT)
modeByteLimitExceeded _ = False
#else
modeByteLimitExceeded observed = observed > maxModeBytes
#endif
#if defined(VALIDATION_COMPILER_PLAN_OBJECT_IDENTITY_BYTE_LIMIT_BYPASS_MUTANT)
objectIdentityByteLimitExceeded _ = False
#else
objectIdentityByteLimitExceeded observed = observed > maxObjectIdentityBytes
#endif

snapshotIdentityByteLimitExceeded :: Int -> Bool
#if defined(VALIDATION_COMPILER_PLAN_SNAPSHOT_IDENTITY_BYTE_LIMIT_BYPASS_MUTANT)
snapshotIdentityByteLimitExceeded _ = False
#else
snapshotIdentityByteLimitExceeded observed = observed > maxSnapshotIdentityBytes
#endif

entryOrderInvalid :: [FilePath] -> [FilePath] -> Bool
#if defined(VALIDATION_COMPILER_PLAN_ENTRY_ORDER_BYPASS_MUTANT)
entryOrderInvalid _ _ = False
#else
entryOrderInvalid observed canonical = observed /= canonical
#endif

duplicatePathRejected :: Bool
#if defined(VALIDATION_COMPILER_PLAN_DUPLICATE_PATH_BYPASS_MUTANT)
duplicatePathRejected = False
#else
duplicatePathRejected = True
#endif

snapshotPreflightProblems :: SourceSnapshot -> [ComponentPlanProblem]
snapshotPreflightProblems snapshot = case boundedPrefix maxSnapshotEntries (snapshotEntries snapshot) of
  Exceeded observed
    | snapshotEntryLimitExceeded observed ->
        [ComponentPlanSnapshotEntryLimitExceeded maxSnapshotEntries observed]
    | otherwise -> snapshotPreflightProblems (snapshot {snapshotEntries = take maxSnapshotEntries (snapshotEntries snapshot)})
  Bounded entries ->
    finalizeProblems
      ( identityProblems
          <> entryResourceProblems
          <> aggregateProblems
          <> entryGrammarProblems
          <> orderProblems
          <> cabalCountProblems
          <> cabalByteProblems
          <> cabalStructureProblems
      )
   where
    identity = snapshotIdentity snapshot
    identityProblems = case boundedTextUtf8Bytes maxSnapshotIdentityBytes identity of
      Exceeded observed
        | snapshotIdentityByteLimitExceeded observed ->
            [ComponentPlanSnapshotIdentityByteLimitExceeded maxSnapshotIdentityBytes observed]
        | otherwise -> []
      Bounded _ -> [ComponentPlanSnapshotIdentityMalformed identity | not (validSnapshotIdentity identity)]
    entryResourceProblems = concat (zipWith typedEntryResourceProblems [1 ..] entries)
    aggregateProblems = case boundedTypedAggregateBytes entries of
      Left observed -> [ComponentPlanAggregateBlobByteLimitExceeded maxAggregateBlobBytes observed]
      Right _ -> []
    entryGrammarProblems =
      if null entryResourceProblems
        then concat (zipWith typedEntryGrammarProblems [1 ..] entries)
        else []
    paths = map (indexPath . trackedIndex) entries
    orderedPaths = sort paths
    orderProblems =
      if null entryResourceProblems && null entryGrammarProblems
        then
          [ ComponentPlanDuplicatePath path
          | repeated <- group orderedPaths
          , path : _ : _ <- [repeated]
          , duplicatePathRejected
          ]
            <> [ComponentPlanEntryOrderInvalid paths | entryOrderInvalid paths orderedPaths]
        else []
    cabalEntries =
      [entry | entry <- entries, posixExtension (indexPath (trackedIndex entry)) == ".cabal"]
    cabalInputs =
      [ entry
      | entry <- entries
      , let path = indexPath (trackedIndex entry)
      , posixExtension path == ".cabal" || path == "cabal.project"
      ]
    cabalCount = length cabalInputs
    cabalCountProblems =
      [ComponentPlanCabalEntryLimitExceeded maxCabalEntries cabalCount | cabalEntryLimitExceeded cabalCount]
    cabalByteProblems =
      [ ComponentPlanCabalByteLimitExceeded path maxCabalBytes observed
      | entry <- cabalInputs
      , let path = indexPath (trackedIndex entry)
      , let observed = ByteString.length (trackedBytes entry)
      , cabalByteLimitExceeded observed
      ]
    cabalStructureProblems =
      if null cabalCountProblems && null cabalByteProblems
        then
          let perDeclarationProblems = concatMap scannedCabalStructureProblems cabalEntries
           in perDeclarationProblems
                <> [ problem
                   | null perDeclarationProblems
                   , problem <- aggregateCabalStructureProblems cabalEntries
                   ]
        else []

typedEntryResourceProblems :: Int -> TrackedEntry -> [ComponentPlanProblem]
typedEntryResourceProblems ordinal tracked =
  pathProblems <> objectProblems <> blobProblems
 where
  index = trackedIndex tracked
  path = indexPath index
  pathProblems = case boundedFilePathUtf8Bytes maxPathBytes path of
    Exceeded observed
      | pathByteLimitExceeded observed -> [ComponentPlanPathByteLimitExceeded ordinal maxPathBytes observed]
      | otherwise -> []
    Bounded _ -> []
  objectIdentity = indexObjectId index
  objectProblems = case boundedTextUtf8Bytes maxObjectIdentityBytes objectIdentity of
    Exceeded observed
      | objectIdentityByteLimitExceeded observed -> [ComponentPlanObjectIdentityByteLimitExceeded ordinal maxObjectIdentityBytes observed]
      | otherwise -> []
    Bounded _ -> []
  blobLength = ByteString.length (trackedBytes tracked)
  blobProblems =
    [ComponentPlanBlobByteLimitExceeded (safeProblemPath ordinal path) maxBlobBytes blobLength | blobLimitExceeded blobLength]

typedEntryGrammarProblems :: Int -> TrackedEntry -> [ComponentPlanProblem]
typedEntryGrammarProblems ordinal tracked =
  safePathProblems ordinal path <> shapeProblems <> contentProblems
 where
  index = trackedIndex tracked
  path = indexPath index
  objectIdentity = indexObjectId index
  shapeProblems =
    [ComponentPlanObjectIdentityMalformed path objectIdentity | not (validObjectIdentity objectIdentity)]
  contentProblems =
    [ ComponentPlanObjectIdentityMismatch path objectIdentity expected
    | null shapeProblems
    , let expected = gitBlobIdentity objectIdentity (trackedBytes tracked)
    , objectIdentityMismatch objectIdentity expected
    ]

boundedTypedAggregateBytes :: [TrackedEntry] -> Either Int Int
boundedTypedAggregateBytes = go 0
 where
  go total remaining = case remaining of
    [] -> Right total
    tracked : rest ->
      let size = ByteString.length (trackedBytes tracked)
       in if aggregateAdditionExceedsLimit total size
            then
              if aggregateBlobLimitExceeded (maxAggregateBlobBytes + 1)
                then Left (maxAggregateBlobBytes + 1)
                else go total rest
            else go (typedAggregateNextTotal total size) rest

typedAggregateNextTotal :: Int -> Int -> Int
#if defined(VALIDATION_COMPILER_PLAN_TYPED_AGGREGATE_TOTAL_ACCUMULATION_MUTANT)
typedAggregateNextTotal total size = total + size + 1
#else
typedAggregateNextTotal total size = total + size
#endif

validSnapshotIdentity :: Text -> Bool
validSnapshotIdentity value =
  acceptedLength && Text.all acceptedCharacter value
 where
  acceptedLength = Text.length value == 64 || shortLengthAlternative
  shortLengthAlternative =
#if defined(VALIDATION_COMPILER_PLAN_SNAPSHOT_IDENTITY_LENGTH_WIDEN_MUTANT)
    Text.length value == 63
#else
    False
#endif
  acceptedCharacter character =
    digitAlternative
      || lowercaseAlternative
      || uppercaseAlternative
      || widenedAlternative
   where
    digitAlternative =
#if defined(VALIDATION_COMPILER_PLAN_SNAPSHOT_IDENTITY_DIGIT_ALTERNATIVE_DROP_MUTANT)
      False
#else
      isDigit character
#endif
    lowercaseAlternative =
#if defined(VALIDATION_COMPILER_PLAN_SNAPSHOT_IDENTITY_LOWER_HEX_ALTERNATIVE_DROP_MUTANT)
      False
#else
      character >= 'a' && character <= 'f'
#endif
    uppercaseAlternative =
#if defined(VALIDATION_COMPILER_PLAN_SNAPSHOT_IDENTITY_UPPERCASE_WIDEN_MUTANT)
      character >= 'A' && character <= 'F'
#else
      False
#endif
    widenedAlternative =
#if defined(VALIDATION_COMPILER_PLAN_SNAPSHOT_IDENTITY_GRAMMAR_WIDEN_MUTANT)
      character == 'g'
#else
      False
#endif

data CabalScanCounts = CabalScanCounts
  { scannedComponents :: Int
  , scannedConditionals :: Int
  , scannedModules :: Int
  , scannedSourceDirectories :: Int
  , scannedConfigurations :: Int
  , scannedOptions :: Int
  , scannedDependencies :: Int
  , scannedAssignments :: Int
  }

emptyCabalScanCounts :: CabalScanCounts
emptyCabalScanCounts = CabalScanCounts 0 0 0 0 0 0 0 0

scannedCabalStructureProblems :: TrackedEntry -> [ComponentPlanProblem]
scannedCabalStructureProblems tracked =
  [ComponentPlanComponentLimitExceeded path maxComponents components | componentLimitExceeded components]
    <> [ComponentPlanConditionalLimitExceeded path maxConditionals conditionals | conditionalLimitExceeded conditionals]
    <> [ComponentPlanModuleLimitExceeded path maxModules modules | moduleLimitExceeded modules]
    <> [ComponentPlanSourceDirectoryLimitExceeded path maxSourceDirectories sourceDirectories | sourceDirectoryLimitExceeded sourceDirectories]
    <> [ComponentPlanConfigurationLimitExceeded path maxConfigurations configurations | configurationLimitExceeded configurations]
    <> [ComponentPlanOptionLimitExceeded path maxOptions options | optionLimitExceeded options]
    <> [ComponentPlanDependencyLimitExceeded path maxDependencies dependencies | dependencyLimitExceeded dependencies]
    <> [ComponentPlanAssignmentLimitExceeded maxAssignments assignments | assignmentLimitExceeded assignments]
 where
  path = indexPath (trackedIndex tracked)
  counts = scanCabalBytes (trackedBytes tracked)
  components = scannedComponents counts
  conditionals = scannedConditionals counts
  modules = scannedModules counts
  sourceDirectories = scannedSourceDirectories counts
  configurations = scannedConfigurations counts
  options = scannedOptions counts
  dependencies = scannedDependencies counts
  assignments = scannedAssignments counts

aggregateCabalStructureProblems :: [TrackedEntry] -> [ComponentPlanProblem]
aggregateCabalStructureProblems entries =
  [ComponentPlanComponentLimitExceeded subject maxComponents components | componentLimitExceeded components]
    <> [ComponentPlanConditionalLimitExceeded subject maxConditionals conditionals | conditionalLimitExceeded conditionals]
    <> [ComponentPlanModuleLimitExceeded subject maxModules modules | moduleLimitExceeded modules]
    <> [ComponentPlanSourceDirectoryLimitExceeded subject maxSourceDirectories sourceDirectories | sourceDirectoryLimitExceeded sourceDirectories]
    <> [ComponentPlanConfigurationLimitExceeded subject maxConfigurations configurations | configurationLimitExceeded configurations]
    <> [ComponentPlanOptionLimitExceeded subject maxOptions options | optionLimitExceeded options]
    <> [ComponentPlanDependencyLimitExceeded subject maxDependencies dependencies | dependencyLimitExceeded dependencies]
    <> [ComponentPlanAssignmentLimitExceeded maxAssignments assignments | assignmentLimitExceeded assignments]
 where
  subject = "compiler-component-plan"
  counts = foldl' addCounts emptyCabalScanCounts (map (scanCabalBytes . trackedBytes) entries)
  components = scannedComponents counts
  conditionals = scannedConditionals counts
  modules = scannedModules counts
  sourceDirectories = scannedSourceDirectories counts
  configurations = scannedConfigurations counts
  options = scannedOptions counts
  dependencies = scannedDependencies counts
  assignments = scannedAssignments counts

addCounts :: CabalScanCounts -> CabalScanCounts -> CabalScanCounts
addCounts left right =
  CabalScanCounts
    { scannedComponents = aggregateScannedComponents (scannedComponents left) (scannedComponents right)
    , scannedConditionals = aggregateScannedConditionals (scannedConditionals left) (scannedConditionals right)
    , scannedModules = aggregateScannedModules (scannedModules left) (scannedModules right)
    , scannedSourceDirectories = aggregateScannedSourceDirectories (scannedSourceDirectories left) (scannedSourceDirectories right)
    , scannedConfigurations = aggregateScannedConfigurations (scannedConfigurations left) (scannedConfigurations right)
    , scannedOptions = aggregateScannedOptions (scannedOptions left) (scannedOptions right)
    , scannedDependencies = aggregateScannedDependencies (scannedDependencies left) (scannedDependencies right)
    , scannedAssignments = aggregateScannedAssignments (scannedAssignments left) (scannedAssignments right)
    }

aggregateScannedComponents :: Int -> Int -> Int
#if defined(VALIDATION_COMPILER_PLAN_AGGREGATE_SCAN_COMPONENT_CONTRIBUTION_DROP_MUTANT)
aggregateScannedComponents left right = right `seq` left
#else
aggregateScannedComponents left right = left + right
#endif

aggregateScannedConditionals :: Int -> Int -> Int
#if defined(VALIDATION_COMPILER_PLAN_AGGREGATE_SCAN_CONDITIONAL_CONTRIBUTION_DROP_MUTANT)
aggregateScannedConditionals left right = right `seq` left
#else
aggregateScannedConditionals left right = left + right
#endif

aggregateScannedModules :: Int -> Int -> Int
#if defined(VALIDATION_COMPILER_PLAN_AGGREGATE_SCAN_MODULE_CONTRIBUTION_DROP_MUTANT)
aggregateScannedModules left right = right `seq` left
#else
aggregateScannedModules left right = left + right
#endif

aggregateScannedSourceDirectories :: Int -> Int -> Int
#if defined(VALIDATION_COMPILER_PLAN_AGGREGATE_SCAN_SOURCE_DIRECTORY_CONTRIBUTION_DROP_MUTANT)
aggregateScannedSourceDirectories left right = right `seq` left
#else
aggregateScannedSourceDirectories left right = left + right
#endif

aggregateScannedConfigurations :: Int -> Int -> Int
#if defined(VALIDATION_COMPILER_PLAN_AGGREGATE_SCAN_CONFIGURATION_CONTRIBUTION_DROP_MUTANT)
aggregateScannedConfigurations left right = right `seq` left
#else
aggregateScannedConfigurations left right = left + right
#endif

aggregateScannedOptions :: Int -> Int -> Int
#if defined(VALIDATION_COMPILER_PLAN_AGGREGATE_SCAN_OPTION_CONTRIBUTION_DROP_MUTANT)
aggregateScannedOptions left right = right `seq` left
#else
aggregateScannedOptions left right = left + right
#endif

aggregateScannedDependencies :: Int -> Int -> Int
#if defined(VALIDATION_COMPILER_PLAN_AGGREGATE_SCAN_DEPENDENCY_CONTRIBUTION_DROP_MUTANT)
aggregateScannedDependencies left right = right `seq` left
#else
aggregateScannedDependencies left right = left + right
#endif

aggregateScannedAssignments :: Int -> Int -> Int
#if defined(VALIDATION_COMPILER_PLAN_AGGREGATE_SCAN_ASSIGNMENT_CONTRIBUTION_DROP_MUTANT)
aggregateScannedAssignments left right = right `seq` left
#else
aggregateScannedAssignments left right = left + right
#endif

scanCabalBytes :: ByteString -> CabalScanCounts
scanCabalBytes = foldl' scanLine emptyCabalScanCounts . ByteString8.lines
 where
  scanLine counts original =
    counts
      { scannedComponents = accumulateScannedComponents (scannedComponents counts) componentIncrement
      , scannedConditionals = accumulateScannedConditionals (scannedConditionals counts) conditionalIncrement
      , scannedModules = accumulateScannedModules (scannedModules counts) moduleIncrement
      , scannedSourceDirectories = accumulateScannedSourceDirectories (scannedSourceDirectories counts) sourceDirectoryIncrement
      , scannedConfigurations = accumulateScannedConfigurations (scannedConfigurations counts) (configurationComponentIncrement + configurationConditionalIncrement)
      , scannedOptions = accumulateScannedOptions (scannedOptions counts) optionIncrement
      , scannedDependencies = accumulateScannedDependencies (scannedDependencies counts) dependencyIncrement
      , scannedAssignments = accumulateScannedAssignments (scannedAssignments counts) (assignmentModuleIncrement + assignmentMainIncrement)
      }
   where
    line = ByteString8.map asciiLower (ByteString8.dropWhile isHorizontalSpace original)
    componentIncrement =
      fromEnum
        ( mainLibraryComponentPrefix
            || foreignLibraryComponentPrefix
            || executableComponentPrefix
            || testComponentPrefix
            || benchmarkComponentPrefix
        )
    mainLibraryComponentPrefix =
#if defined(VALIDATION_COMPILER_PLAN_SCAN_MAIN_LIBRARY_COMPONENT_PREFIX_DROP_MUTANT)
      False
#else
      "library" `ByteString.isPrefixOf` line
#endif
    foreignLibraryComponentPrefix =
#if defined(VALIDATION_COMPILER_PLAN_SCAN_FOREIGN_LIBRARY_COMPONENT_PREFIX_DROP_MUTANT)
      False
#else
      "foreign-library " `ByteString.isPrefixOf` line
#endif
    executableComponentPrefix =
#if defined(VALIDATION_COMPILER_PLAN_SCAN_EXECUTABLE_COMPONENT_PREFIX_DROP_MUTANT)
      False
#else
      "executable " `ByteString.isPrefixOf` line
#endif
    testComponentPrefix =
#if defined(VALIDATION_COMPILER_PLAN_SCAN_TEST_COMPONENT_PREFIX_DROP_MUTANT)
      False
#else
      "test-suite " `ByteString.isPrefixOf` line
#endif
    benchmarkComponentPrefix =
#if defined(VALIDATION_COMPILER_PLAN_SCAN_BENCHMARK_COMPONENT_PREFIX_DROP_MUTANT)
      False
#else
      "benchmark " `ByteString.isPrefixOf` line
#endif
    conditionalIncrement = fromEnum (ifConditionalPrefix || elseConditionalAlternative)
    ifConditionalPrefix =
#if defined(VALIDATION_COMPILER_PLAN_SCAN_IF_CONDITIONAL_PREFIX_DROP_MUTANT)
      False
#else
      "if " `ByteString.isPrefixOf` line
#endif
    elseConditionalAlternative =
#if defined(VALIDATION_COMPILER_PLAN_SCAN_ELSE_CONDITIONAL_ALTERNATIVE_DROP_MUTANT)
      False
#else
      line == "else"
#endif
    moduleIncrement = fieldValueCount moduleFieldPrefixes line
    sourceDirectoryIncrement = fieldValueCount sourceDirectoryFieldPrefixes line
    optionIncrement = fieldValueCount optionFieldPrefixes line
    dependencyIncrement = dependencyValueCount line
    mainIncrement = fieldValueCount mainFieldPrefixes line
    configurationComponentIncrement =
#if defined(VALIDATION_COMPILER_PLAN_SCAN_CONFIGURATION_COMPONENT_CONTRIBUTION_DROP_MUTANT)
      componentIncrement `seq` 0
#else
      componentIncrement
#endif
    configurationConditionalIncrement =
#if defined(VALIDATION_COMPILER_PLAN_SCAN_CONFIGURATION_CONDITIONAL_CONTRIBUTION_DROP_MUTANT)
      conditionalIncrement `seq` 0
#else
      conditionalIncrement
#endif
    assignmentModuleIncrement =
#if defined(VALIDATION_COMPILER_PLAN_SCAN_ASSIGNMENT_MODULE_CONTRIBUTION_DROP_MUTANT)
      moduleIncrement `seq` 0
#else
      moduleIncrement
#endif
    assignmentMainIncrement =
#if defined(VALIDATION_COMPILER_PLAN_SCAN_ASSIGNMENT_MAIN_CONTRIBUTION_DROP_MUTANT)
      mainIncrement `seq` 0
#else
      mainIncrement
#endif
  moduleFieldPrefixes =
    exposedModuleFieldPrefixes
      <> otherModuleFieldPrefixes
      <> signatureModuleFieldPrefixes
      <> autogenModuleFieldPrefixes
      <> reexportedModuleFieldPrefixes
  exposedModuleFieldPrefixes =
#if defined(VALIDATION_COMPILER_PLAN_SCAN_EXPOSED_MODULES_PREFIX_DROP_MUTANT)
    []
#else
    ["exposed-modules:"]
#endif
  otherModuleFieldPrefixes =
#if defined(VALIDATION_COMPILER_PLAN_SCAN_OTHER_MODULES_PREFIX_DROP_MUTANT)
    []
#else
    ["other-modules:"]
#endif
  signatureModuleFieldPrefixes =
#if defined(VALIDATION_COMPILER_PLAN_SCAN_SIGNATURES_PREFIX_DROP_MUTANT)
    []
#else
    ["signatures:"]
#endif
  autogenModuleFieldPrefixes =
#if defined(VALIDATION_COMPILER_PLAN_SCAN_AUTOGEN_MODULES_PREFIX_DROP_MUTANT)
    []
#else
    ["autogen-modules:"]
#endif
  reexportedModuleFieldPrefixes =
#if defined(VALIDATION_COMPILER_PLAN_SCAN_REEXPORTED_MODULES_PREFIX_DROP_MUTANT)
    []
#else
    ["reexported-modules:"]
#endif
  sourceDirectoryFieldPrefixes =
#if defined(VALIDATION_COMPILER_PLAN_SCAN_HS_SOURCE_DIRS_PREFIX_DROP_MUTANT)
    []
#else
    ["hs-source-dirs:"]
#endif
  optionFieldPrefixes =
    ghcOptionFieldPrefixes
      <> cppOptionFieldPrefixes
      <> defaultExtensionFieldPrefixes
      <> otherExtensionFieldPrefixes
      <> legacyExtensionFieldPrefixes
  ghcOptionFieldPrefixes =
#if defined(VALIDATION_COMPILER_PLAN_SCAN_GHC_OPTIONS_PREFIX_DROP_MUTANT)
    []
#else
    ["ghc-options:"]
#endif
  cppOptionFieldPrefixes =
#if defined(VALIDATION_COMPILER_PLAN_SCAN_CPP_OPTIONS_PREFIX_DROP_MUTANT)
    []
#else
    ["cpp-options:"]
#endif
  defaultExtensionFieldPrefixes =
#if defined(VALIDATION_COMPILER_PLAN_SCAN_DEFAULT_EXTENSIONS_PREFIX_DROP_MUTANT)
    []
#else
    ["default-extensions:"]
#endif
  otherExtensionFieldPrefixes =
#if defined(VALIDATION_COMPILER_PLAN_SCAN_OTHER_EXTENSIONS_PREFIX_DROP_MUTANT)
    []
#else
    ["other-extensions:"]
#endif
  legacyExtensionFieldPrefixes =
#if defined(VALIDATION_COMPILER_PLAN_SCAN_EXTENSIONS_PREFIX_DROP_MUTANT)
    []
#else
    ["extensions:"]
#endif
  mainFieldPrefixes =
#if defined(VALIDATION_COMPILER_PLAN_SCAN_MAIN_IS_PREFIX_DROP_MUTANT)
    []
#else
    ["main-is:"]
#endif

accumulateScannedComponents :: Int -> Int -> Int
#if defined(VALIDATION_COMPILER_PLAN_SCAN_COMPONENT_ACCUMULATION_MUTANT)
accumulateScannedComponents previous increment = previous `seq` increment
#else
accumulateScannedComponents previous increment = previous + increment
#endif

accumulateScannedConditionals :: Int -> Int -> Int
#if defined(VALIDATION_COMPILER_PLAN_SCAN_CONDITIONAL_ACCUMULATION_MUTANT)
accumulateScannedConditionals previous increment = previous `seq` increment
#else
accumulateScannedConditionals previous increment = previous + increment
#endif

accumulateScannedModules :: Int -> Int -> Int
#if defined(VALIDATION_COMPILER_PLAN_SCAN_MODULE_ACCUMULATION_MUTANT)
accumulateScannedModules previous increment = previous `seq` increment
#else
accumulateScannedModules previous increment = previous + increment
#endif

accumulateScannedSourceDirectories :: Int -> Int -> Int
#if defined(VALIDATION_COMPILER_PLAN_SCAN_SOURCE_DIRECTORY_ACCUMULATION_MUTANT)
accumulateScannedSourceDirectories previous increment = previous `seq` increment
#else
accumulateScannedSourceDirectories previous increment = previous + increment
#endif

accumulateScannedConfigurations :: Int -> Int -> Int
#if defined(VALIDATION_COMPILER_PLAN_SCAN_CONFIGURATION_ACCUMULATION_MUTANT)
accumulateScannedConfigurations previous increment = previous `seq` increment
#else
accumulateScannedConfigurations previous increment = previous + increment
#endif

accumulateScannedOptions :: Int -> Int -> Int
#if defined(VALIDATION_COMPILER_PLAN_SCAN_OPTION_ACCUMULATION_MUTANT)
accumulateScannedOptions previous increment = previous `seq` increment
#else
accumulateScannedOptions previous increment = previous + increment
#endif

accumulateScannedDependencies :: Int -> Int -> Int
#if defined(VALIDATION_COMPILER_PLAN_SCAN_DEPENDENCY_ACCUMULATION_MUTANT)
accumulateScannedDependencies previous increment = previous `seq` increment
#else
accumulateScannedDependencies previous increment = previous + increment
#endif

accumulateScannedAssignments :: Int -> Int -> Int
#if defined(VALIDATION_COMPILER_PLAN_SCAN_ASSIGNMENT_ACCUMULATION_MUTANT)
accumulateScannedAssignments previous increment = previous `seq` increment
#else
accumulateScannedAssignments previous increment = previous + increment
#endif

fieldValueCount :: [ByteString] -> ByteString -> Int
fieldValueCount prefixes line = case [rest | prefix <- prefixes, Just rest <- [ByteString.stripPrefix prefix line]] of
  [] -> 0
  rest : _ -> length (filter (not . ByteString.null) (splitFieldValues rest))

splitFieldValues :: ByteString -> [ByteString]
splitFieldValues = ByteString8.words . ByteString8.map commaToSpace
 where
#if defined(VALIDATION_COMPILER_PLAN_SCAN_FIELD_VALUE_COMMA_DELIMITER_DROP_MUTANT)
  commaToSpace ',' = ','
#else
  commaToSpace ',' = ' '
#endif
  commaToSpace character = character

dependencyValueCount :: ByteString -> Int
dependencyValueCount line = case dependencyFieldRest line of
  Nothing -> 0
  Just rest -> length (filter (not . ByteString.null) (map trimHorizontal (splitCommas rest)))

dependencyFieldRest :: ByteString -> Maybe ByteString
#if defined(VALIDATION_COMPILER_PLAN_SCAN_BUILD_DEPENDS_PREFIX_DROP_MUTANT)
dependencyFieldRest line = line `seq` Nothing
#else
dependencyFieldRest = ByteString.stripPrefix "build-depends:"
#endif

splitCommas :: ByteString -> [ByteString]
#if defined(VALIDATION_COMPILER_PLAN_SCAN_DEPENDENCY_COMMA_DELIMITER_DROP_MUTANT)
splitCommas value = [value]
#else
splitCommas value = case ByteString8.break (== ',') value of
  (part, remaining)
    | ByteString.null remaining -> [part]
    | otherwise -> part : splitCommas (ByteString.drop 1 remaining)
#endif

trimHorizontal :: ByteString -> ByteString
trimHorizontal =
  ByteString8.reverse
    . ByteString8.dropWhile isHorizontalSpace
    . ByteString8.reverse
    . ByteString8.dropWhile isHorizontalSpace

isHorizontalSpace :: Char -> Bool
isHorizontalSpace character = spaceAlternative || tabAlternative
 where
  spaceAlternative =
#if defined(VALIDATION_COMPILER_PLAN_SCAN_SPACE_ALTERNATIVE_DROP_MUTANT)
    False
#else
    character == ' '
#endif
  tabAlternative =
#if defined(VALIDATION_COMPILER_PLAN_SCAN_TAB_ALTERNATIVE_DROP_MUTANT)
    False
#else
    character == '\t'
#endif

asciiLower :: Char -> Char
asciiLower character
  | asciiUppercaseNormalizationSelected character = toEnum (ord character + 32)
  | otherwise = character

asciiUppercaseNormalizationSelected :: Char -> Bool
#if defined(VALIDATION_COMPILER_PLAN_SCAN_ASCII_UPPERCASE_NORMALIZATION_DROP_MUTANT)
asciiUppercaseNormalizationSelected _ = False
#else
asciiUppercaseNormalizationSelected = isAsciiUpper
#endif

cabalEntryLimitExceeded, cabalByteLimitExceeded, componentLimitExceeded, conditionalLimitExceeded :: Int -> Bool
#if defined(VALIDATION_COMPILER_PLAN_CABAL_ENTRY_LIMIT_BYPASS_MUTANT)
cabalEntryLimitExceeded _ = False
#else
cabalEntryLimitExceeded observed = observed > maxCabalEntries
#endif
#if defined(VALIDATION_COMPILER_PLAN_CABAL_BYTE_LIMIT_BYPASS_MUTANT)
cabalByteLimitExceeded _ = False
#else
cabalByteLimitExceeded observed = observed > maxCabalBytes
#endif
#if defined(VALIDATION_COMPILER_PLAN_COMPONENT_LIMIT_BYPASS_MUTANT)
componentLimitExceeded _ = False
#else
componentLimitExceeded observed = observed > maxComponents
#endif
#if defined(VALIDATION_COMPILER_PLAN_CONDITIONAL_LIMIT_BYPASS_MUTANT)
conditionalLimitExceeded _ = False
#else
conditionalLimitExceeded observed = observed > maxConditionals
#endif

moduleLimitExceeded, sourceDirectoryLimitExceeded, configurationLimitExceeded, optionLimitExceeded :: Int -> Bool
#if defined(VALIDATION_COMPILER_PLAN_MODULE_LIMIT_BYPASS_MUTANT)
moduleLimitExceeded _ = False
#else
moduleLimitExceeded observed = observed > maxModules
#endif
#if defined(VALIDATION_COMPILER_PLAN_SOURCE_DIRECTORY_LIMIT_BYPASS_MUTANT)
sourceDirectoryLimitExceeded _ = False
#else
sourceDirectoryLimitExceeded observed = observed > maxSourceDirectories
#endif
#if defined(VALIDATION_COMPILER_PLAN_CONFIGURATION_LIMIT_BYPASS_MUTANT)
configurationLimitExceeded _ = False
#else
configurationLimitExceeded observed = observed > maxConfigurations
#endif
#if defined(VALIDATION_COMPILER_PLAN_OPTION_LIMIT_BYPASS_MUTANT)
optionLimitExceeded _ = False
#else
optionLimitExceeded observed = observed > maxOptions
#endif

dependencyLimitExceeded, assignmentLimitExceeded, problemLimitExceeded :: Int -> Bool
#if defined(VALIDATION_COMPILER_PLAN_DEPENDENCY_LIMIT_BYPASS_MUTANT)
dependencyLimitExceeded _ = False
#else
dependencyLimitExceeded observed = observed > maxDependencies
#endif
#if defined(VALIDATION_COMPILER_PLAN_ASSIGNMENT_LIMIT_BYPASS_MUTANT)
assignmentLimitExceeded _ = False
#else
assignmentLimitExceeded observed = observed > maxAssignments
#endif
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_LIMIT_BYPASS_MUTANT)
problemLimitExceeded _ = False
#else
problemLimitExceeded observed = observed > maxProblems
#endif

resultFindingLimitExceeded :: Int -> Bool
#if defined(VALIDATION_COMPILER_PLAN_RESULT_FINDING_LIMIT_BYPASS_MUTANT)
resultFindingLimitExceeded _ = False
#else
resultFindingLimitExceeded observed = observed > maxResultFindings
#endif

-- assignViews owns the max+1 candidate-stream inspection before any Map is
-- allocated. This function accepts only that already-bounded result and must
-- not pretend to provide an unreachable second resource boundary.
finalizeAssignments :: [ComponentAssignment] -> [ComponentAssignment]
finalizeAssignments = canonicalAssignmentOrder
 where
  assignmentKey assignment =
    (componentAssignmentName assignment, haskellSubjectPath (componentAssignmentSubject assignment))
  canonicalAssignmentOrder =
#if defined(VALIDATION_COMPILER_PLAN_ASSIGNMENT_RESULT_ORDER_MUTANT)
    reverse . sortOn assignmentKey
#else
    sortOn assignmentKey
#endif

finalizeProblems :: [ComponentPlanProblem] -> [ComponentPlanProblem]
finalizeProblems problems = case boundedPrefix maxProblems problems of
  Bounded values -> canonicalProblemOrder values
  Exceeded observed
    | problemLimitExceeded observed -> [ComponentPlanProblemLimitExceeded maxProblems observed]
    | otherwise -> canonicalProblemOrder (take maxProblems problems)
 where
  canonicalProblemOrder =
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CANONICAL_ORDER_MUTANT)
    reverse . sort
#else
    sort
#endif

decimalText :: Int -> Text
decimalText = Text.pack . show

limitDetail :: Int -> Int -> Text
limitDetail limit observed =
  "limit"
    <> projectLimitDetailFirstSeparator
    <> projectLimitDetailLimit (decimalText limit)
    <> projectLimitDetailSecondSeparator
    <> projectLimitDetailObserved (decimalText observed)

projectLimitDetailFirstSeparator :: Text
#if defined(VALIDATION_COMPILER_PLAN_LIMIT_DETAIL_FIRST_SEPARATOR_MUTANT)
projectLimitDetailFirstSeparator = ":"
#else
projectLimitDetailFirstSeparator = "="
#endif

projectLimitDetailLimit :: Text -> Text
#if defined(VALIDATION_COMPILER_PLAN_LIMIT_DETAIL_LIMIT_FIELD_MUTANT)
projectLimitDetailLimit _ = "0"
#else
projectLimitDetailLimit = id
#endif

projectLimitDetailSecondSeparator :: Text
#if defined(VALIDATION_COMPILER_PLAN_LIMIT_DETAIL_SECOND_SEPARATOR_MUTANT)
projectLimitDetailSecondSeparator = "; observed="
#else
projectLimitDetailSecondSeparator = "; observed-at-least="
#endif

projectLimitDetailObserved :: Text -> Text
#if defined(VALIDATION_COMPILER_PLAN_LIMIT_DETAIL_OBSERVED_FIELD_MUTANT)
projectLimitDetailObserved _ = "0"
#else
projectLimitDetailObserved = id
#endif

data ComponentView = ComponentView
  { viewName :: Text
  , viewKind :: ComponentKind
  , viewModules :: [Text]
  , viewMainPaths :: [FilePath]
  , viewSourceDirs :: [FilePath]
  , viewConfig :: ComponentCompilerConfig
  , viewAutogenModules :: [Text]
  , viewSignatureModules :: [Text]
  , viewReexportedModules :: [Text]
  , viewUnsupportedBuildInfoFields :: [Text]
  , viewUnsafePaths :: [FilePath]
  , viewResourceBoundary :: Bool
  , viewResourceProblems :: [ComponentPlanProblem]
  }
  deriving (Eq, Ord, Show)

data PackageAnalysis = PackageAnalysis
  { packageComponents :: [Text]
  , packageViews :: [ComponentView]
  , packageProblems :: [ComponentPlanProblem]
  , packageParsedResourceBoundary :: Bool
  }

deriveCompilerComponentPlan :: SourceSnapshot -> CompilerComponentPlan
deriveCompilerComponentPlan snapshot = case snapshotPreflightProblems snapshot of
  [] -> deriveBoundedCompilerComponentPlan snapshot
  problems -> emptyComponentPlan (snapshotIdentity snapshot) (finalizeProblems problems)

deriveBoundedCompilerComponentPlan :: SourceSnapshot -> CompilerComponentPlan
deriveBoundedCompilerComponentPlan snapshot =
  CompilerComponentPlan
    (snapshotIdentity snapshot)
    allComponentNames
    assignments
    ( finalizeProblems
        ( projectAbsentProblemContribution absentProblems
            <> projectPackageProblemContribution (concatMap packageProblems analyses)
            <> projectProjectProblemContribution projectProblems
            <> projectAssignmentProblemContribution assignmentProblems
            <> projectAssignmentLimitProblemContribution assignmentLimitProblems
            <> projectExpectationProblemContribution (assignmentExpectationProblems assignments)
            <> projectUnownedProblemContribution unownedProblems
            <> projectConfigurationProblemContribution (configurationProblems assignments)
            <> projectMultipleComponentProblemContribution multiComponentProblems
        )
    )
 where
  projectEntries =
    [ tracked
    | tracked <- snapshotEntries snapshot
    , indexPath (trackedIndex tracked) == "cabal.project"
    ]
  projectProblems =
#if defined(VALIDATION_COMPILER_PLAN_PROJECT_BYPASS_MUTANT)
    projectEntries `seq` []
#else
    [ CabalProjectElaborationUnavailable (indexPath (trackedIndex tracked))
    | tracked <- projectEntries
    ]
#endif

  cabalEntries =
    [ tracked
    | tracked <- snapshotEntries snapshot
    , posixExtension (indexPath (trackedIndex tracked)) == ".cabal"
    ]
  absentProblems =
#if defined(VALIDATION_COMPILER_PLAN_DESCRIPTION_ABSENT_BYPASS_MUTANT)
    []
#else
    [CabalDescriptionAbsent | null cabalEntries]
#endif
  analyses = map analyzePackage cabalEntries
  -- A parse-refusal analysis contains exactly one boundary problem in its
  -- first cell. Successful analyses can carry a large, lazily bounded static
  -- problem stream, so boundary suppression must never traverse that stream.
  parseBoundaryPresent = any packageParseBoundaryPresent analyses
  allViews = concatMap packageViews analyses
  assignmentViews = filter viewResourceAllowsAssignment allViews
  parsedResourceBoundaryPresent = any packageParsedResourceBoundary analyses
  subjects =
    sortOn haskellSubjectPath
      [ HaskellSubject
          (indexPath index)
          (indexMode index)
          (indexObjectId index)
      | tracked <- snapshotEntries snapshot
      , let index = trackedIndex tracked
      , posixExtension (indexPath index) == ".hs"
      ]
  (rawAssignments, assignmentLimitProblems, assignmentProblems) = assignViews subjects assignmentViews
  assignments = finalizeAssignments rawAssignments
  assignedPaths = Set.fromList (map (haskellSubjectPath . componentAssignmentSubject) assignments)
  unownedProblems =
    projectUnownedProblems
      [ CabalHaskellSubjectUnowned (haskellSubjectPath subject)
      | not (null cabalEntries)
      , not (parseBoundarySuppressesUnowned parseBoundaryPresent)
      , not (parsedResourceBoundarySuppressesUnowned parsedResourceBoundaryPresent)
      , not (any isAssignmentLimitProblem assignmentLimitProblems)
      , subject <- subjects
      , Set.notMember (haskellSubjectPath subject) assignedPaths
      ]
  allComponentNames = Set.toAscList (Set.fromList (concatMap packageComponents analyses))
  multiComponentProblems =
#if defined(VALIDATION_COMPILER_PLAN_MULTIPLE_COMPONENT_BYPASS_MUTANT)
    []
#else
    [CabalMultipleComponentsUnclosed allComponentNames | length allComponentNames > 1]
#endif

packageParseBoundaryPresent :: PackageAnalysis -> Bool
packageParseBoundaryPresent analysis = case packageProblems analysis of
  problem : _ -> isPackageParseBoundaryProblem problem
  [] -> False

viewResourceAllowsAssignment :: ComponentView -> Bool
#if defined(VALIDATION_COMPILER_PLAN_VIEW_RESOURCE_ASSIGNMENT_GATE_BYPASS_MUTANT)
viewResourceAllowsAssignment _ = True
#else
viewResourceAllowsAssignment = not . viewResourceBoundary
#endif

parsedResourceBoundarySuppressesUnowned :: Bool -> Bool
#if defined(VALIDATION_COMPILER_PLAN_PARSED_RESOURCE_FALLOUT_BYPASS_MUTANT)
parsedResourceBoundarySuppressesUnowned _ = False
#else
parsedResourceBoundarySuppressesUnowned = id
#endif

projectAbsentProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_ABSENT_PROBLEMS_DROP_MUTANT)
projectAbsentProblemContribution _ = []
#else
projectAbsentProblemContribution = id
#endif

projectPackageProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_PACKAGE_PROBLEMS_DROP_MUTANT)
projectPackageProblemContribution _ = []
#else
projectPackageProblemContribution = id
#endif

projectProjectProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_PROJECT_PROBLEMS_DROP_MUTANT)
projectProjectProblemContribution _ = []
#else
projectProjectProblemContribution = id
#endif

projectAssignmentProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_ASSIGNMENT_PROBLEMS_DROP_MUTANT)
projectAssignmentProblemContribution _ = []
#else
projectAssignmentProblemContribution = id
#endif

projectAssignmentLimitProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_ASSIGNMENT_LIMIT_PROBLEMS_DROP_MUTANT)
projectAssignmentLimitProblemContribution _ = []
#else
projectAssignmentLimitProblemContribution = id
#endif

projectExpectationProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_EXPECTATION_PROBLEMS_DROP_MUTANT)
projectExpectationProblemContribution _ = []
#else
projectExpectationProblemContribution = id
#endif

projectUnownedProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_UNOWNED_PROBLEMS_DROP_MUTANT)
projectUnownedProblemContribution _ = []
#else
projectUnownedProblemContribution = id
#endif

projectConfigurationProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_CONFIGURATION_PROBLEMS_DROP_MUTANT)
projectConfigurationProblemContribution _ = []
#else
projectConfigurationProblemContribution = id
#endif

projectMultipleComponentProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_MULTIPLE_COMPONENT_PROBLEMS_DROP_MUTANT)
projectMultipleComponentProblemContribution _ = []
#else
projectMultipleComponentProblemContribution = id
#endif

projectUnownedProblems :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_UNOWNED_SUBJECT_BYPASS_MUTANT)
projectUnownedProblems _ = []
#else
projectUnownedProblems = id
#endif

isAssignmentLimitProblem :: ComponentPlanProblem -> Bool
isAssignmentLimitProblem problem = case problem of
  ComponentPlanAssignmentLimitExceeded _ _ ->
#if defined(VALIDATION_COMPILER_PLAN_ASSIGNMENT_LIMIT_PROBLEM_RECOGNITION_DROP_MUTANT)
    False
#else
    True
#endif
  _ -> False

isPackageParseBoundaryProblem :: ComponentPlanProblem -> Bool
isPackageParseBoundaryProblem problem = case problem of
  CabalDescriptionParseFailed _ ->
#if defined(VALIDATION_COMPILER_PLAN_PARSE_FAILURE_BOUNDARY_RECOGNITION_DROP_MUTANT)
    False
#else
    True
#endif
  CabalDescriptionParseWarning _ ->
#if defined(VALIDATION_COMPILER_PLAN_PARSE_WARNING_BOUNDARY_RECOGNITION_DROP_MUTANT)
    False
#else
    True
#endif
  _ -> False

parseBoundarySuppressesUnowned :: Bool -> Bool
#if defined(VALIDATION_COMPILER_PLAN_PARSE_BOUNDARY_FALLOUT_BYPASS_MUTANT)
parseBoundarySuppressesUnowned _ = False
#else
parseBoundarySuppressesUnowned = id
#endif

analyzePackage :: TrackedEntry -> PackageAnalysis
analyzePackage tracked = case runParseResult (parseGenericPackageDescription (trackedBytes tracked)) of
  (_, Left _) ->
    PackageAnalysis
      []
      []
#if defined(VALIDATION_COMPILER_PLAN_PARSE_FAILURE_BYPASS_MUTANT)
      []
#else
      [CabalDescriptionParseFailed cabalPath]
#endif
      False
  (warnings, Right description) ->
#if defined(VALIDATION_COMPILER_PLAN_PARSE_WARNING_BYPASS_MUTANT)
    warnings `seq` analyzeDescription description
#else
    case warnings of
      [] -> analyzeDescription description
      _ -> PackageAnalysis [] [] [CabalDescriptionParseWarning cabalPath] False
#endif
 where
  cabalPath = indexPath (trackedIndex tracked)
  analyzeDescription description =
    PackageAnalysis
      { packageComponents = boundedComponentNames
      , packageViews = views
      , packageProblems =
          projectConfigurationResourceProblemContribution configurationResourceProblems
            <> projectPackageDescriptionProblemContribution (packageDescriptionProblems cabalPath description)
            <> projectConditionalProblemContribution (conditionalProblems cabalPath description)
            <> projectForeignProblemContribution (foreignProblems cabalPath description)
            <> projectViewStaticProblemContribution (concatMap viewStaticProblems views)
      , packageParsedResourceBoundary =
          not (null configurationResourceProblems)
            || any viewResourceBoundary views
      }
   where
    rawViews = packageViewsFor cabalPath description
    (views, configurationResourceProblems) = case boundedPrefix maxConfigurations rawViews of
      Bounded values -> (values, [])
      Exceeded observed
        | configurationLimitExceeded observed ->
            ([], [ComponentPlanConfigurationLimitExceeded cabalPath maxConfigurations observed])
        | otherwise -> (take maxConfigurations rawViews, [])
    boundedComponentNames = Set.toAscList (Set.fromList (map viewName views))

projectConfigurationResourceProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_CONFIGURATION_RESOURCE_PROBLEMS_DROP_MUTANT)
projectConfigurationResourceProblemContribution _ = []
#else
projectConfigurationResourceProblemContribution = id
#endif

projectPackageDescriptionProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_PACKAGE_DESCRIPTION_PROBLEMS_DROP_MUTANT)
projectPackageDescriptionProblemContribution _ = []
#else
projectPackageDescriptionProblemContribution = id
#endif

projectConditionalProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_CONDITIONAL_PROBLEMS_DROP_MUTANT)
projectConditionalProblemContribution _ = []
#else
projectConditionalProblemContribution = id
#endif

projectForeignProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_FOREIGN_PROBLEMS_DROP_MUTANT)
projectForeignProblemContribution _ = []
#else
projectForeignProblemContribution = id
#endif

projectViewStaticProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_VIEW_STATIC_PROBLEMS_DROP_MUTANT)
projectViewStaticProblemContribution _ = []
#else
projectViewStaticProblemContribution = id
#endif

-- Package-level behavior participates in the build even when every component
-- BuildInfo looks simple.  The restricted linked-GHC diagnostic cannot execute
-- custom Setup code or project/package data hooks, so each such declaration is
-- explicit residue rather than silently discarded.
packageDescriptionProblems :: FilePath -> GenericPackageDescription -> [ComponentPlanProblem]
packageDescriptionProblems cabalPath description =
  projectBuildTypeProblemContribution buildTypeProblems
    <> projectSetupProblemContribution setupProblems
    <> projectPackageFieldProblemContribution fieldProblems
 where
  packageDescriptionValue = packageDescription description
  buildTypeProblems =
    projectBuildTypeProblems
      (case buildTypeRaw packageDescriptionValue of
        Nothing -> []
        Just Simple -> []
        Just buildType -> [CabalBuildTypeUnsupported cabalPath (Text.pack (show buildType))]
      )
  setupProblems =
    projectCustomSetupProblems
      [CabalCustomSetupUnsupported cabalPath | setupBuildInfo packageDescriptionValue /= Nothing]
  fieldProblems =
    [ CabalPackageFieldUnclosed cabalPath field
    | field <- projectPackageFields
        ( packageSourceRepositoryFields packageDescriptionValue
            <> packageDataFileFields packageDescriptionValue
            <> packageExtraSourceFileFields packageDescriptionValue
            <> packageExtraTemporaryFileFields packageDescriptionValue
            <> packageExtraDocumentationFileFields packageDescriptionValue
            <> packageExtraFileFields packageDescriptionValue
            <> packageCustomFieldFields packageDescriptionValue
        )
    ]

projectBuildTypeProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_BUILD_TYPE_PROBLEMS_DROP_MUTANT)
projectBuildTypeProblemContribution _ = []
#else
projectBuildTypeProblemContribution = id
#endif

projectSetupProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_SETUP_PROBLEMS_DROP_MUTANT)
projectSetupProblemContribution _ = []
#else
projectSetupProblemContribution = id
#endif

projectPackageFieldProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_PACKAGE_FIELD_PROBLEMS_DROP_MUTANT)
projectPackageFieldProblemContribution _ = []
#else
projectPackageFieldProblemContribution = id
#endif

packageSourceRepositoryFields :: PackageDescription -> [Text]
packageSourceRepositoryFields description =
  let present = not (null (sourceRepos description))
   in
#if defined(VALIDATION_COMPILER_PLAN_PACKAGE_SOURCE_REPOSITORIES_ALTERNATIVE_DROP_MUTANT)
      present `seq` []
#else
      ["source-repositories" | present]
#endif

packageDataFileFields :: PackageDescription -> [Text]
packageDataFileFields description =
  let present = not (null (dataFiles description))
   in
#if defined(VALIDATION_COMPILER_PLAN_PACKAGE_DATA_FILES_ALTERNATIVE_DROP_MUTANT)
      present `seq` []
#else
      ["data-files" | present]
#endif

packageExtraSourceFileFields :: PackageDescription -> [Text]
packageExtraSourceFileFields description =
  let present = not (null (extraSrcFiles description))
   in
#if defined(VALIDATION_COMPILER_PLAN_PACKAGE_EXTRA_SOURCE_FILES_ALTERNATIVE_DROP_MUTANT)
      present `seq` []
#else
      ["extra-source-files" | present]
#endif

packageExtraTemporaryFileFields :: PackageDescription -> [Text]
packageExtraTemporaryFileFields description =
  let present = not (null (extraTmpFiles description))
   in
#if defined(VALIDATION_COMPILER_PLAN_PACKAGE_EXTRA_TEMPORARY_FILES_ALTERNATIVE_DROP_MUTANT)
      present `seq` []
#else
      ["extra-temporary-files" | present]
#endif

packageExtraDocumentationFileFields :: PackageDescription -> [Text]
packageExtraDocumentationFileFields description =
  let present = not (null (extraDocFiles description))
   in
#if defined(VALIDATION_COMPILER_PLAN_PACKAGE_EXTRA_DOCUMENTATION_FILES_ALTERNATIVE_DROP_MUTANT)
      present `seq` []
#else
      ["extra-documentation-files" | present]
#endif

packageExtraFileFields :: PackageDescription -> [Text]
packageExtraFileFields description =
  let present = not (null (extraFiles description))
   in
#if defined(VALIDATION_COMPILER_PLAN_PACKAGE_EXTRA_FILES_ALTERNATIVE_DROP_MUTANT)
      present `seq` []
#else
      ["extra-files" | present]
#endif

packageCustomFieldFields :: PackageDescription -> [Text]
packageCustomFieldFields description =
  let present = not (null (customFieldsPD description))
   in
#if defined(VALIDATION_COMPILER_PLAN_PACKAGE_CUSTOM_FIELDS_ALTERNATIVE_DROP_MUTANT)
      present `seq` []
#else
      ["custom-package-fields" | present]
#endif

projectBuildTypeProblems :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_BUILD_TYPE_BYPASS_MUTANT)
projectBuildTypeProblems _ = []
#else
projectBuildTypeProblems = id
#endif

projectCustomSetupProblems :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_CUSTOM_SETUP_BYPASS_MUTANT)
projectCustomSetupProblems _ = []
#else
projectCustomSetupProblems = id
#endif

projectPackageFields :: [Text] -> [Text]
#if defined(VALIDATION_COMPILER_PLAN_PACKAGE_FIRST_FIELD_DROP_MUTANT)
projectPackageFields [] = []
projectPackageFields (_ : remaining) = remaining
#else
projectPackageFields = id
#endif

packageViewsFor :: FilePath -> GenericPackageDescription -> [ComponentView]
packageViewsFor cabalPath description =
  concat
    [ projectMainLibraryViewContribution (maybe [] (viewsForTree packageRoot mainLibraryView) (condLibrary description))
    , projectNamedLibraryViewContribution
        ( concat
            [ viewsForTree packageRoot (namedLibraryView name) tree
            | (name, tree) <- condSubLibraries description
            ]
        )
    , projectExecutableViewContribution
        ( concat
            [ viewsForTree packageRoot (executableView name) tree
            | (name, tree) <- condExecutables description
            ]
        )
    , projectTestViewContribution
        ( concat
            [ viewsForTree packageRoot (testView name) tree
            | (name, tree) <- condTestSuites description
            ]
        )
    , projectBenchmarkViewContribution
        ( concat
            [ viewsForTree packageRoot (benchmarkView name) tree
            | (name, tree) <- condBenchmarks description
            ]
        )
    ]
 where
  packageRoot = normalizeRoot (posixDirectory cabalPath)

projectMainLibraryViewContribution :: [ComponentView] -> [ComponentView]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_MAIN_LIBRARY_VIEWS_DROP_MUTANT)
projectMainLibraryViewContribution _ = []
#else
projectMainLibraryViewContribution = id
#endif

projectNamedLibraryViewContribution :: [ComponentView] -> [ComponentView]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_NAMED_LIBRARY_VIEWS_DROP_MUTANT)
projectNamedLibraryViewContribution _ = []
#else
projectNamedLibraryViewContribution = id
#endif

projectExecutableViewContribution :: [ComponentView] -> [ComponentView]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_EXECUTABLE_VIEWS_DROP_MUTANT)
projectExecutableViewContribution _ = []
#else
projectExecutableViewContribution = id
#endif

projectTestViewContribution :: [ComponentView] -> [ComponentView]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_TEST_VIEWS_DROP_MUTANT)
projectTestViewContribution _ = []
#else
projectTestViewContribution = id
#endif

projectBenchmarkViewContribution :: [ComponentView] -> [ComponentView]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_BENCHMARK_VIEWS_DROP_MUTANT)
projectBenchmarkViewContribution _ = []
#else
projectBenchmarkViewContribution = id
#endif

viewsForTree
  :: Monoid component
  => FilePath
  -> (FilePath -> component -> ComponentView)
  -> CondTree variable [Dependency] component
  -> [ComponentView]
viewsForTree packageRoot project = map (project packageRoot) . cumulativeNodes mempty

cumulativeNodes :: Monoid component => component -> CondTree variable constraints component -> [component]
cumulativeNodes inherited (CondNode datum _ branches) =
  projectCurrentConditionalNodeContribution [current]
    <> concatMap branchNodes branches
 where
  current = inherited <> datum
  branchNodes (CondBranch _ trueBranch falseBranch) =
    projectTrueConditionalNodeContribution (cumulativeNodes current trueBranch)
      <> projectFalseConditionalNodeContribution (maybe [] (cumulativeNodes current) falseBranch)

projectCurrentConditionalNodeContribution :: [component] -> [component]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_CURRENT_CONDITIONAL_NODE_DROP_MUTANT)
projectCurrentConditionalNodeContribution _ = []
#else
projectCurrentConditionalNodeContribution = id
#endif

projectTrueConditionalNodeContribution :: [component] -> [component]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_TRUE_CONDITIONAL_NODE_DROP_MUTANT)
projectTrueConditionalNodeContribution _ = []
#else
projectTrueConditionalNodeContribution = id
#endif

projectFalseConditionalNodeContribution :: [component] -> [component]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_FALSE_CONDITIONAL_NODE_DROP_MUTANT)
projectFalseConditionalNodeContribution _ = []
#else
projectFalseConditionalNodeContribution = id
#endif

mainLibraryView :: FilePath -> Library -> ComponentView
mainLibraryView root library =
  componentView
    root
    (projectComponentName (packageQualified root "lib"))
    projectedMainLibraryKind
    (libBuildInfo library)
    (map (Text.pack . CabalModule.toFilePath) (exposedModules library))
    []
    (map (Text.pack . CabalModule.toFilePath) (autogenModules (libBuildInfo library)))
    (map (Text.pack . CabalModule.toFilePath) (signatures library))
    (map (Text.pack . prettyShow) (reexportedModules library))

namedLibraryView
  :: UnqualComponentName
  -> FilePath
  -> Library
  -> ComponentView
namedLibraryView name root library =
  componentView
    root
    (projectComponentName (packageQualified root ("lib:" <> Text.pack (unUnqualComponentName name))))
    projectedNamedLibraryKind
    (libBuildInfo library)
    (map (Text.pack . CabalModule.toFilePath) (exposedModules library))
    []
    (map (Text.pack . CabalModule.toFilePath) (autogenModules (libBuildInfo library)))
    (map (Text.pack . CabalModule.toFilePath) (signatures library))
    (map (Text.pack . prettyShow) (reexportedModules library))

executableView
  :: UnqualComponentName
  -> FilePath
  -> Executable
  -> ComponentView
executableView name root executable =
  componentView
    root
    (projectComponentName (packageQualified root ("exe:" <> Text.pack (unUnqualComponentName name))))
    projectedExecutableKind
    (buildInfo executable)
    []
    [getSymbolicPath (modulePath executable)]
    (map (Text.pack . CabalModule.toFilePath) (autogenModules (buildInfo executable)))
    []
    []

testView
  :: UnqualComponentName
  -> FilePath
  -> TestSuite
  -> ComponentView
testView name root testSuite =
  baseView
    { viewUnsupportedBuildInfoFields =
        sort
          ( viewUnsupportedBuildInfoFields baseView
              <> testCodeGeneratorFields testSuite
          )
    }
 where
  baseView =
    componentView
      root
      (projectComponentName (packageQualified root ("test:" <> Text.pack (unUnqualComponentName name))))
      projectedTestKind
      (testBuildInfo testSuite)
      (testModules testSuite)
      (testMains testSuite)
      (map (Text.pack . CabalModule.toFilePath) (autogenModules (testBuildInfo testSuite)))
      []
      []

benchmarkView
  :: UnqualComponentName
  -> FilePath
  -> Benchmark
  -> ComponentView
benchmarkView name root benchmark =
  componentView
    root
    (projectComponentName (packageQualified root ("bench:" <> Text.pack (unUnqualComponentName name))))
    projectedBenchmarkKind
    (benchmarkBuildInfo benchmark)
    []
    (benchmarkMains benchmark)
    (map (Text.pack . CabalModule.toFilePath) (autogenModules (benchmarkBuildInfo benchmark)))
    []
    []

projectedMainLibraryKind :: ComponentKind
#if defined(VALIDATION_COMPILER_PLAN_VIEW_KIND_MAIN_LIBRARY_MAPPING_MUTANT)
projectedMainLibraryKind = ExecutableComponent
#else
projectedMainLibraryKind = MainLibraryComponent
#endif

projectedNamedLibraryKind :: ComponentKind
#if defined(VALIDATION_COMPILER_PLAN_VIEW_KIND_NAMED_LIBRARY_MAPPING_MUTANT)
projectedNamedLibraryKind = MainLibraryComponent
#else
projectedNamedLibraryKind = NamedLibraryComponent
#endif

projectedExecutableKind :: ComponentKind
#if defined(VALIDATION_COMPILER_PLAN_VIEW_KIND_EXECUTABLE_MAPPING_MUTANT)
projectedExecutableKind = MainLibraryComponent
#else
projectedExecutableKind = ExecutableComponent
#endif

projectedTestKind :: ComponentKind
#if defined(VALIDATION_COMPILER_PLAN_VIEW_KIND_TEST_MAPPING_MUTANT)
projectedTestKind = MainLibraryComponent
#else
projectedTestKind = TestComponent
#endif

projectedBenchmarkKind :: ComponentKind
#if defined(VALIDATION_COMPILER_PLAN_VIEW_KIND_BENCHMARK_MAPPING_MUTANT)
projectedBenchmarkKind = MainLibraryComponent
#else
projectedBenchmarkKind = BenchmarkComponent
#endif

componentView
  :: FilePath
  -> Text
  -> ComponentKind
  -> BuildInfo
  -> [Text]
  -> [FilePath]
  -> [Text]
  -> [Text]
  -> [Text]
  -> ComponentView
componentView packageRoot name kind info modules mains autogen signatures reexports =
  ComponentView
    { viewName = name
    , viewKind = kind
    , viewModules = projectModules boundedModules
    , viewMainPaths = projectMainPaths (projectMainPathSourceContribution (sort mains))
    , viewSourceDirs = projectSourceDirectories boundedSourceDirs
    , viewConfig = boundedConfig
    , viewAutogenModules = boundedAutogenModules
    , viewSignatureModules = boundedSignatureModules
    , viewReexportedModules = boundedReexportedModules
    , viewUnsupportedBuildInfoFields = unsupportedBuildInfoFields info
    , viewUnsafePaths =
        filter
          (not . safeDeclarationPath)
          ( projectUnsafeSourceDirectoryContribution boundedRawSourceDirs
              <> projectUnsafeMainPathContribution mains
          )
    , viewResourceBoundary =
        not
          ( null
              ( moduleResourceProblems
                  <> sourceDirectoryResourceProblems
                  <> optionResourceProblems
                  <> dependencyResourceProblems
              )
          )
    , viewResourceProblems =
        projectViewModuleResourceProblemContribution moduleResourceProblems
          <> projectViewSourceDirectoryResourceProblemContribution sourceDirectoryResourceProblems
          <> projectViewOptionResourceProblemContribution optionResourceProblems
          <> projectViewDependencyResourceProblemContribution dependencyResourceProblems
    }
 where
  rawExposedModules = projectExposedModuleSourceContribution modules
  rawOtherModules = projectOtherModuleSourceContribution (map (Text.pack . CabalModule.toFilePath) (otherModules info))
  rawAutogenModules = projectAutogenModuleSourceContribution autogen
  rawSignatureModules = projectSignatureModuleSourceContribution signatures
  rawReexportedModules = projectReexportedModuleSourceContribution reexports
  rawModules = rawExposedModules <> rawOtherModules
  rawModuleWitnesses =
    map (const ()) rawExposedModules
      <> map (const ()) rawOtherModules
      <> map (const ()) rawAutogenModules
      <> map (const ()) rawSignatureModules
      <> map (const ()) rawReexportedModules
  (boundedModules, boundedAutogenModules, boundedSignatureModules, boundedReexportedModules, moduleResourceProblems) =
    case boundedPrefix maxModules rawModuleWitnesses of
      Bounded _ -> (sort rawModules, sort rawAutogenModules, sort rawSignatureModules, sort rawReexportedModules, [])
      Exceeded observed
        | moduleLimitExceeded observed ->
            ([], [], [], [], [ComponentPlanModuleLimitExceeded (Text.unpack name) maxModules observed])
        | otherwise ->
            let (boundedExposed, boundedOther, boundedAutogen, boundedSignatures, boundedReexports) =
                  takeFiveLists maxModules rawExposedModules rawOtherModules rawAutogenModules rawSignatureModules rawReexportedModules
             in (sort (boundedExposed <> boundedOther), sort boundedAutogen, sort boundedSignatures, sort boundedReexports, [])
  rawSourceDirs = projectSourceDirectorySourceContribution (map getSymbolicPath (nonemptySourceDirs info))
  (boundedRawSourceDirs, sourceDirectoryResourceProblems) = case boundedPrefix maxSourceDirectories rawSourceDirs of
    Bounded values -> (values, [])
    Exceeded observed
      | sourceDirectoryLimitExceeded observed ->
          ([], [ComponentPlanSourceDirectoryLimitExceeded (Text.unpack name) maxSourceDirectories observed])
      | otherwise -> (take maxSourceDirectories rawSourceDirs, [])
  boundedSourceDirs = map (prefixPackageRoot packageRoot) boundedRawSourceDirs
  (boundedConfig, optionResourceProblems, dependencyResourceProblems) =
    boundedCompilerConfig name info boundedSourceDirs

projectViewModuleResourceProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_VIEW_MODULE_RESOURCE_PROBLEMS_DROP_MUTANT)
projectViewModuleResourceProblemContribution _ = []
#else
projectViewModuleResourceProblemContribution = id
#endif

projectViewSourceDirectoryResourceProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_VIEW_SOURCE_DIRECTORY_RESOURCE_PROBLEMS_DROP_MUTANT)
projectViewSourceDirectoryResourceProblemContribution _ = []
#else
projectViewSourceDirectoryResourceProblemContribution = id
#endif

projectViewOptionResourceProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_VIEW_OPTION_RESOURCE_PROBLEMS_DROP_MUTANT)
projectViewOptionResourceProblemContribution _ = []
#else
projectViewOptionResourceProblemContribution = id
#endif

projectViewDependencyResourceProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_VIEW_DEPENDENCY_RESOURCE_PROBLEMS_DROP_MUTANT)
projectViewDependencyResourceProblemContribution _ = []
#else
projectViewDependencyResourceProblemContribution = id
#endif

projectUnsafeSourceDirectoryContribution :: [FilePath] -> [FilePath]
#if defined(VALIDATION_COMPILER_PLAN_UNSAFE_SOURCE_DIRECTORY_CONTRIBUTION_DROP_MUTANT)
projectUnsafeSourceDirectoryContribution _ = []
#else
projectUnsafeSourceDirectoryContribution = id
#endif

projectUnsafeMainPathContribution :: [FilePath] -> [FilePath]
#if defined(VALIDATION_COMPILER_PLAN_UNSAFE_MAIN_PATH_CONTRIBUTION_DROP_MUTANT)
projectUnsafeMainPathContribution _ = []
#else
projectUnsafeMainPathContribution = id
#endif

projectMainPathSourceContribution :: [FilePath] -> [FilePath]
#if defined(VALIDATION_COMPILER_PLAN_SOURCE_MAIN_PATHS_CONTRIBUTION_DROP_MUTANT)
projectMainPathSourceContribution _ = []
#else
projectMainPathSourceContribution = id
#endif

projectAutogenModuleSourceContribution :: [Text] -> [Text]
#if defined(VALIDATION_COMPILER_PLAN_SOURCE_AUTOGEN_MODULES_CONTRIBUTION_DROP_MUTANT)
projectAutogenModuleSourceContribution _ = []
#else
projectAutogenModuleSourceContribution = id
#endif

projectSignatureModuleSourceContribution :: [Text] -> [Text]
#if defined(VALIDATION_COMPILER_PLAN_SOURCE_SIGNATURES_CONTRIBUTION_DROP_MUTANT)
projectSignatureModuleSourceContribution _ = []
#else
projectSignatureModuleSourceContribution = id
#endif

projectReexportedModuleSourceContribution :: [Text] -> [Text]
#if defined(VALIDATION_COMPILER_PLAN_SOURCE_REEXPORTED_MODULES_CONTRIBUTION_DROP_MUTANT)
projectReexportedModuleSourceContribution _ = []
#else
projectReexportedModuleSourceContribution = id
#endif

-- Cabal parsing is admitted only after the raw 16 KiB resource preflight.  A
-- successfully parsed BuildInfo can nevertheless contain more continuation
-- values than the line scanner observed.  Inspect at most max+1 projected
-- values before sorting or retaining any of those lists.  On overflow the
-- config is intentionally empty for that resource class and the exact
-- structured refusal is carried separately into ComponentView.
boundedCompilerConfig
  :: Text
  -> BuildInfo
  -> [FilePath]
  -> (ComponentCompilerConfig, [ComponentPlanProblem], [ComponentPlanProblem])
boundedCompilerConfig componentName info sourceDirs =
  ( ComponentCompilerConfig
      { componentConfigSourceDirs = projectConfigSourceDirectorySourceContribution sourceDirs
      , componentConfigDefaultLanguage = projectDefaultLanguage (projectDefaultLanguageSourceContribution (Text.pack . prettyShow <$> defaultLanguage info))
      , componentConfigExtensions = projectExtensions (sort (boundedDefaultExtensions <> boundedOtherExtensions <> boundedLegacyExtensions))
      , componentConfigGhcOptions = projectGhcOptions (sort boundedGhcOptions)
      , componentConfigCppOptions = projectCppOptions (sort boundedCppOptions)
      , componentConfigDependencies = projectDependencies (sort boundedDependencies)
      }
  , optionResourceProblems
  , dependencyResourceProblems
  )
 where
  rawDefaultExtensions = projectDefaultExtensionSourceContribution (map (Text.pack . prettyShow) (defaultExtensions info))
  rawOtherExtensions = projectOtherExtensionSourceContribution (map (Text.pack . prettyShow) (otherExtensions info))
  rawLegacyExtensions = projectLegacyExtensionSourceContribution (map (Text.pack . prettyShow) (oldExtensions info))
  rawGhcOptions = projectGhcOptionSourceContribution (map Text.pack (hcOptions GHC info))
  rawCppOptions = projectCppOptionSourceContribution (map Text.pack (cppOptions info))
  rawOptionWitnesses =
    map (const ()) rawDefaultExtensions
      <> map (const ()) rawOtherExtensions
      <> map (const ()) rawLegacyExtensions
      <> map (const ()) rawGhcOptions
      <> map (const ()) rawCppOptions
  (boundedDefaultExtensions, boundedOtherExtensions, boundedLegacyExtensions, boundedGhcOptions, boundedCppOptions, optionResourceProblems) =
    case boundedPrefix maxOptions rawOptionWitnesses of
      Bounded _ -> (rawDefaultExtensions, rawOtherExtensions, rawLegacyExtensions, rawGhcOptions, rawCppOptions, [])
      Exceeded observed
        | optionLimitExceeded observed ->
            ([], [], [], [], [], [ComponentPlanOptionLimitExceeded (Text.unpack componentName) maxOptions observed])
        | otherwise ->
            let (boundedDefault, boundedOther, boundedLegacy, boundedGhc, boundedCpp) =
                  takeFiveLists maxOptions rawDefaultExtensions rawOtherExtensions rawLegacyExtensions rawGhcOptions rawCppOptions
             in (boundedDefault, boundedOther, boundedLegacy, boundedGhc, boundedCpp, [])
  rawDependencies = projectDependencySourceContribution (map (Text.pack . prettyShow) (targetBuildDepends info))
  (boundedDependencies, dependencyResourceProblems) = case boundedPrefix maxDependencies rawDependencies of
    Bounded values -> (values, [])
    Exceeded observed
      | dependencyLimitExceeded observed ->
          ([], [ComponentPlanDependencyLimitExceeded (Text.unpack componentName) maxDependencies observed])
      | otherwise -> (take maxDependencies rawDependencies, [])

takeFourLists :: Int -> [value] -> [value] -> [value] -> [value] -> ([value], [value], [value], [value])
takeFourLists limit first second third fourth =
  (boundedFirst, boundedSecond, boundedThird, boundedFourth)
 where
  boundedFirst = take limit first
  afterFirst = limit - length boundedFirst
  boundedSecond = take afterFirst second
  afterSecond = afterFirst - length boundedSecond
  boundedThird = take afterSecond third
  afterThird = afterSecond - length boundedThird
  boundedFourth = take afterThird fourth

takeFiveLists
  :: Int
  -> [value]
  -> [value]
  -> [value]
  -> [value]
  -> [value]
  -> ([value], [value], [value], [value], [value])
takeFiveLists limit first second third fourth fifth =
  (boundedFirst, boundedSecond, boundedThird, boundedFourth, boundedFifth)
 where
  (boundedFirst, boundedSecond, boundedThird, boundedFourth) =
    takeFourLists limit first second third fourth
  afterFourth =
    limit
      - length boundedFirst
      - length boundedSecond
      - length boundedThird
      - length boundedFourth
  boundedFifth = take afterFourth fifth

projectExposedModuleSourceContribution :: [Text] -> [Text]
#if defined(VALIDATION_COMPILER_PLAN_SOURCE_EXPOSED_MODULES_CONTRIBUTION_DROP_MUTANT)
projectExposedModuleSourceContribution _ = []
#else
projectExposedModuleSourceContribution = id
#endif

projectOtherModuleSourceContribution :: [Text] -> [Text]
#if defined(VALIDATION_COMPILER_PLAN_SOURCE_OTHER_MODULES_CONTRIBUTION_DROP_MUTANT)
projectOtherModuleSourceContribution _ = []
#else
projectOtherModuleSourceContribution = id
#endif

projectSourceDirectorySourceContribution :: [FilePath] -> [FilePath]
#if defined(VALIDATION_COMPILER_PLAN_SOURCE_HS_SOURCE_DIRS_CONTRIBUTION_DROP_MUTANT)
projectSourceDirectorySourceContribution _ = []
#else
projectSourceDirectorySourceContribution = id
#endif

projectConfigSourceDirectorySourceContribution :: [FilePath] -> [FilePath]
#if defined(VALIDATION_COMPILER_PLAN_CONFIG_SOURCE_DIRECTORIES_CONTRIBUTION_DROP_MUTANT)
projectConfigSourceDirectorySourceContribution _ = []
#else
projectConfigSourceDirectorySourceContribution = id
#endif

projectDefaultLanguageSourceContribution :: Maybe Text -> Maybe Text
#if defined(VALIDATION_COMPILER_PLAN_SOURCE_DEFAULT_LANGUAGE_CONTRIBUTION_DROP_MUTANT)
projectDefaultLanguageSourceContribution _ = Nothing
#else
projectDefaultLanguageSourceContribution = id
#endif

projectDefaultExtensionSourceContribution :: [Text] -> [Text]
#if defined(VALIDATION_COMPILER_PLAN_SOURCE_DEFAULT_EXTENSIONS_CONTRIBUTION_DROP_MUTANT)
projectDefaultExtensionSourceContribution _ = []
#else
projectDefaultExtensionSourceContribution = id
#endif

projectOtherExtensionSourceContribution :: [Text] -> [Text]
#if defined(VALIDATION_COMPILER_PLAN_SOURCE_OTHER_EXTENSIONS_CONTRIBUTION_DROP_MUTANT)
projectOtherExtensionSourceContribution _ = []
#else
projectOtherExtensionSourceContribution = id
#endif

projectLegacyExtensionSourceContribution :: [Text] -> [Text]
#if defined(VALIDATION_COMPILER_PLAN_SOURCE_LEGACY_EXTENSIONS_CONTRIBUTION_DROP_MUTANT)
projectLegacyExtensionSourceContribution _ = []
#else
projectLegacyExtensionSourceContribution = id
#endif

projectGhcOptionSourceContribution :: [Text] -> [Text]
#if defined(VALIDATION_COMPILER_PLAN_SOURCE_GHC_OPTIONS_CONTRIBUTION_DROP_MUTANT)
projectGhcOptionSourceContribution _ = []
#else
projectGhcOptionSourceContribution = id
#endif

projectCppOptionSourceContribution :: [Text] -> [Text]
#if defined(VALIDATION_COMPILER_PLAN_SOURCE_CPP_OPTIONS_CONTRIBUTION_DROP_MUTANT)
projectCppOptionSourceContribution _ = []
#else
projectCppOptionSourceContribution = id
#endif

projectDependencySourceContribution :: [Text] -> [Text]
#if defined(VALIDATION_COMPILER_PLAN_SOURCE_BUILD_DEPENDS_CONTRIBUTION_DROP_MUTANT)
projectDependencySourceContribution _ = []
#else
projectDependencySourceContribution = id
#endif

projectComponentName :: Text -> Text
#if defined(VALIDATION_COMPILER_PLAN_COMPONENT_NAME_PROJECTION_MUTANT)
projectComponentName _ = "mutated-component"
#else
projectComponentName = id
#endif

projectModules :: [Text] -> [Text]
#if defined(VALIDATION_COMPILER_PLAN_MODULE_PROJECTION_MUTANT)
projectModules [] = []
projectModules (_ : remaining) = remaining
#else
projectModules = id
#endif

projectMainPaths :: [FilePath] -> [FilePath]
#if defined(VALIDATION_COMPILER_PLAN_MAIN_PATH_PROJECTION_MUTANT)
projectMainPaths _ = ["MutatedMain.hs"]
#else
projectMainPaths = id
#endif

projectSourceDirectories :: [FilePath] -> [FilePath]
#if defined(VALIDATION_COMPILER_PLAN_SOURCE_DIRECTORY_PROJECTION_MUTANT)
projectSourceDirectories _ = ["mutated-source-root"]
#else
projectSourceDirectories = id
#endif

projectDefaultLanguage :: Maybe Text -> Maybe Text
#if defined(VALIDATION_COMPILER_PLAN_LANGUAGE_PROJECTION_MUTANT)
projectDefaultLanguage _ = Just "Haskell2010"
#else
projectDefaultLanguage = id
#endif

projectExtensions, projectGhcOptions, projectCppOptions, projectDependencies :: [Text] -> [Text]
#if defined(VALIDATION_COMPILER_PLAN_EXTENSION_PROJECTION_MUTANT)
projectExtensions _ = ["CPP"]
#else
projectExtensions = id
#endif
#if defined(VALIDATION_COMPILER_PLAN_GHC_OPTION_PROJECTION_MUTANT)
projectGhcOptions _ = ["-Wmissing-signatures"]
#else
projectGhcOptions = id
#endif
#if defined(VALIDATION_COMPILER_PLAN_CPP_OPTION_PROJECTION_MUTANT)
projectCppOptions _ = ["-DMUTATED"]
#else
projectCppOptions = id
#endif
#if defined(VALIDATION_COMPILER_PLAN_DEPENDENCY_PROJECTION_MUTANT)
projectDependencies _ = ["mutated-dependency"]
#else
projectDependencies = id
#endif

nonemptySourceDirs
  :: BuildInfo
  -> [CabalPath.SymbolicPath CabalPath.Pkg ('CabalPath.Dir CabalPath.Source)]
nonemptySourceDirs info = case hsSourceDirs info of
  [] ->
#if defined(VALIDATION_COMPILER_PLAN_DEFAULT_SOURCE_DIRECTORY_FALLBACK_MUTANT)
    let fallback = CabalPath.makeSymbolicPath "."
     in fallback `seq` []
#else
    [CabalPath.makeSymbolicPath "."]
#endif
  values -> values

testModules :: TestSuite -> [Text]
testModules testSuite =
  projectTestOtherModuleDuplicateContribution
    (map (Text.pack . CabalModule.toFilePath) (otherModules (testBuildInfo testSuite)))
    <> case testInterface testSuite of
      TestSuiteLibV09 _ moduleName ->
#if defined(VALIDATION_COMPILER_PLAN_TEST_LIBRARY_INTERFACE_MODULE_CONTRIBUTION_DROP_MUTANT)
        moduleName `seq` []
#else
        [Text.pack (CabalModule.toFilePath moduleName)]
#endif
      _ -> []

-- componentView already projects BuildInfo.otherModules for every component.
-- Reintroducing them through the test-interface adapter double-counts the
-- parsed module resource before downstream assignment deduplication can hide
-- the defect.
projectTestOtherModuleDuplicateContribution :: [Text] -> [Text]
#if defined(VALIDATION_COMPILER_PLAN_TEST_OTHER_MODULE_DUPLICATION_MUTANT)
projectTestOtherModuleDuplicateContribution = id
#else
projectTestOtherModuleDuplicateContribution _ = []
#endif

testMains :: TestSuite -> [FilePath]
testMains testSuite = case testInterface testSuite of
  TestSuiteExeV10 _ path ->
#if defined(VALIDATION_COMPILER_PLAN_TEST_EXECUTABLE_INTERFACE_MAIN_CONTRIBUTION_DROP_MUTANT)
    path `seq` []
#else
    [getSymbolicPath path]
#endif
  _ -> []

benchmarkMains :: Benchmark -> [FilePath]
benchmarkMains benchmark = case benchmarkInterface benchmark of
  BenchmarkExeV10 _ path ->
#if defined(VALIDATION_COMPILER_PLAN_BENCHMARK_EXECUTABLE_INTERFACE_MAIN_CONTRIBUTION_DROP_MUTANT)
    path `seq` []
#else
    [getSymbolicPath path]
#endif
  _ -> []

testCodeGeneratorFields :: TestSuite -> [Text]
testCodeGeneratorFields testSuite =
#if defined(VALIDATION_COMPILER_PLAN_TEST_CODE_GENERATORS_ALTERNATIVE_DROP_MUTANT)
  testCodeGenerators testSuite `seq` []
#else
  ["code-generators" | not (null (testCodeGenerators testSuite))]
#endif

assignViews
  :: [HaskellSubject]
  -> [ComponentView]
  -> ([ComponentAssignment], [ComponentPlanProblem], [ComponentPlanProblem])
assignViews subjects views = case boundedPrefix maxAssignments rawAssignments of
  Exceeded observed
    | assignmentLimitExceeded observed -> ([], [ComponentPlanAssignmentLimitExceeded maxAssignments observed], [])
    | otherwise -> assignBounded (take maxAssignments rawAssignments)
  Bounded boundedAssignments ->
    assignBounded boundedAssignments
 where
  byPath = Map.fromList [(haskellSubjectPath subject, subject) | subject <- subjects]
  rawAssignments = concatMap (assignView byPath) views
  assignBounded boundedAssignments =
    ( Map.elems
        ( Map.fromListWith mergeAssignment
            [ ( (componentAssignmentName assignment, haskellSubjectPath (componentAssignmentSubject assignment))
              , assignment
              )
            | assignment <- boundedAssignments
            ]
        )
    , []
    , concatMap (viewAssignmentProblems byPath) views
    )

assignView :: Map FilePath HaskellSubject -> ComponentView -> [ComponentAssignment]
assignView byPath view =
  projectModuleAssignmentContribution moduleAssignments
    <> projectMainAssignmentContribution mainAssignments
 where
  moduleAssignments =
    [ assignment [Text.replace "/" "." moduleName] subject
    | moduleName <- viewModules view
    , path <- moduleCandidates byPath view moduleName
    , Just subject <- [Map.lookup path byPath]
    ]
  mainAssignments =
    [ assignment ["Main"] subject
    | mainPath <- viewMainPaths view
    , path <- mainCandidates byPath view mainPath
    , Just subject <- [Map.lookup path byPath]
    ]
  assignment expectedModules subject =
    ComponentAssignment
      { componentAssignmentName = viewName view
      , componentAssignmentKind = projectAssignmentKind (viewKind view)
      , componentAssignmentSubject = projectAssignmentSubject subject
      , componentAssignmentDeclaredModules = projectAssignmentModules expectedModules
      , componentAssignmentConfigs = projectAssignmentConfigs [viewConfig view]
      }

  projectAssignmentModules :: [Text] -> [Text]
  projectAssignmentModules =
#if defined(VALIDATION_COMPILER_PLAN_ASSIGNMENT_MODULE_PROJECTION_MUTANT)
    const ["Mutated.Module"]
#else
    id
#endif

projectModuleAssignmentContribution :: [ComponentAssignment] -> [ComponentAssignment]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_MODULE_ASSIGNMENTS_DROP_MUTANT)
projectModuleAssignmentContribution _ = []
#else
projectModuleAssignmentContribution = id
#endif

projectMainAssignmentContribution :: [ComponentAssignment] -> [ComponentAssignment]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_MAIN_ASSIGNMENTS_DROP_MUTANT)
projectMainAssignmentContribution _ = []
#else
projectMainAssignmentContribution = id
#endif

projectAssignmentKind :: ComponentKind -> ComponentKind
#if defined(VALIDATION_COMPILER_PLAN_ASSIGNMENT_KIND_PROJECTION_MUTANT)
projectAssignmentKind _ = ExecutableComponent
#else
projectAssignmentKind = id
#endif

projectAssignmentSubject :: HaskellSubject -> HaskellSubject
projectAssignmentSubject subject =
  HaskellSubject
    (projectAssignmentSubjectPath (haskellSubjectPath subject))
    (projectAssignmentSubjectMode (haskellSubjectMode subject))
    (projectAssignmentSubjectObjectIdentity (haskellSubjectObjectId subject))

projectAssignmentSubjectPath :: FilePath -> FilePath
#if defined(VALIDATION_COMPILER_PLAN_ASSIGNMENT_SUBJECT_PATH_PROJECTION_MUTANT)
projectAssignmentSubjectPath _ = "mutated/Subject.hs"
#else
projectAssignmentSubjectPath = id
#endif

projectAssignmentSubjectMode :: IndexMode -> IndexMode
#if defined(VALIDATION_COMPILER_PLAN_ASSIGNMENT_SUBJECT_MODE_PROJECTION_MUTANT)
projectAssignmentSubjectMode _ = ExecutableFile
#else
projectAssignmentSubjectMode = id
#endif

projectAssignmentSubjectObjectIdentity :: Text -> Text
#if defined(VALIDATION_COMPILER_PLAN_ASSIGNMENT_IDENTITY_SWAP_MUTANT)
projectAssignmentSubjectObjectIdentity _ = "compiler-plan-mutated-object-identity"
#else
projectAssignmentSubjectObjectIdentity = id
#endif

projectAssignmentConfigs :: [ComponentCompilerConfig] -> [ComponentCompilerConfig]
#if defined(VALIDATION_COMPILER_PLAN_ASSIGNMENT_CONFIG_PROJECTION_MUTANT)
projectAssignmentConfigs _ = []
#else
projectAssignmentConfigs = id
#endif

mergeAssignment :: ComponentAssignment -> ComponentAssignment -> ComponentAssignment
mergeAssignment left right =
  left
    { componentAssignmentDeclaredModules =
        sort
          ( Set.toList
              ( Set.fromList
                  ( projectMergeLeftModuleContribution (componentAssignmentDeclaredModules left)
                      <> projectMergeRightModuleContribution (componentAssignmentDeclaredModules right)
                  )
              )
          )
    , componentAssignmentConfigs =
        sort
          ( Set.toList
              ( Set.fromList
                  ( projectMergeLeftConfigContribution (componentAssignmentConfigs left)
                      <> projectMergeRightConfigContribution (componentAssignmentConfigs right)
                  )
              )
          )
    }

projectMergeLeftModuleContribution :: [Text] -> [Text]
#if defined(VALIDATION_COMPILER_PLAN_MERGE_LEFT_MODULE_CONTRIBUTION_DROP_MUTANT)
projectMergeLeftModuleContribution _ = []
#else
projectMergeLeftModuleContribution = id
#endif

projectMergeRightModuleContribution :: [Text] -> [Text]
#if defined(VALIDATION_COMPILER_PLAN_MERGE_RIGHT_MODULE_CONTRIBUTION_DROP_MUTANT)
projectMergeRightModuleContribution _ = []
#else
projectMergeRightModuleContribution = id
#endif

projectMergeLeftConfigContribution :: [ComponentCompilerConfig] -> [ComponentCompilerConfig]
#if defined(VALIDATION_COMPILER_PLAN_MERGE_LEFT_CONFIG_CONTRIBUTION_DROP_MUTANT)
projectMergeLeftConfigContribution _ = []
#else
projectMergeLeftConfigContribution = id
#endif

projectMergeRightConfigContribution :: [ComponentCompilerConfig] -> [ComponentCompilerConfig]
#if defined(VALIDATION_COMPILER_PLAN_MERGE_RIGHT_CONFIG_CONTRIBUTION_DROP_MUTANT)
projectMergeRightConfigContribution _ = []
#else
projectMergeRightConfigContribution = id
#endif

assignmentExpectationProblems :: [ComponentAssignment] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_EXPECTATION_CONFLICT_BYPASS_MUTANT)
assignmentExpectationProblems _ = []
#else
assignmentExpectationProblems assignments =
  [ CabalDeclaredModuleExpectationConflict
      (componentAssignmentName assignment)
      (haskellSubjectPath (componentAssignmentSubject assignment))
      expectations
  | assignment <- assignments
  , let expectations = componentAssignmentDeclaredModules assignment
  , length expectations /= 1
  ]
#endif

viewAssignmentProblems
  :: Map FilePath HaskellSubject
  -> ComponentView
  -> [ComponentPlanProblem]
viewAssignmentProblems byPath view =
  concatMap moduleProblems (viewModules view)
    <> concatMap mainProblems (viewMainPaths view)
 where
  moduleProblems moduleName = case moduleCandidates byPath view moduleName of
    [] ->
#if defined(VALIDATION_COMPILER_PLAN_DECLARED_MODULE_MISSING_BYPASS_MUTANT)
      []
#else
      [CabalDeclaredModuleMissing (viewName view) moduleName (candidateModulePaths view moduleName)]
#endif
    [_] -> []
    paths ->
      projectDeclaredModuleAmbiguousProblems
        [CabalDeclaredModuleAmbiguous (viewName view) moduleName (sort paths)]
  mainProblems mainPath = case mainCandidates byPath view mainPath of
    [] ->
#if defined(VALIDATION_COMPILER_PLAN_MAIN_MODULE_MISSING_BYPASS_MUTANT)
      []
#else
      [CabalMainModuleMissing (viewName view) mainPath (candidateMainPaths view mainPath)]
#endif
    [_] -> []
    paths ->
      projectMainModuleAmbiguousProblems
        [CabalMainModuleAmbiguous (viewName view) mainPath (sort paths)]

projectDeclaredModuleAmbiguousProblems :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_DECLARED_MODULE_AMBIGUOUS_BYPASS_MUTANT)
projectDeclaredModuleAmbiguousProblems _ = []
#else
projectDeclaredModuleAmbiguousProblems = id
#endif

projectMainModuleAmbiguousProblems :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_MAIN_MODULE_AMBIGUOUS_BYPASS_MUTANT)
projectMainModuleAmbiguousProblems _ = []
#else
projectMainModuleAmbiguousProblems = id
#endif

moduleCandidates :: Map FilePath HaskellSubject -> ComponentView -> Text -> [FilePath]
moduleCandidates byPath view moduleName = filter (`Map.member` byPath) (candidateModulePaths view moduleName)

candidateModulePaths :: ComponentView -> Text -> [FilePath]
candidateModulePaths view moduleName =
  [joinRepoPath directory (Text.unpack moduleName <> ".hs") | directory <- viewSourceDirs view]

mainCandidates :: Map FilePath HaskellSubject -> ComponentView -> FilePath -> [FilePath]
mainCandidates byPath view mainPath = filter (`Map.member` byPath) (candidateMainPaths view mainPath)

candidateMainPaths :: ComponentView -> FilePath -> [FilePath]
candidateMainPaths view mainPath =
  [joinRepoPath directory mainPath | directory <- viewSourceDirs view]

viewStaticProblems :: ComponentView -> [ComponentPlanProblem]
viewStaticProblems view =
  projectViewResourceProblemContribution (viewResourceProblems view)
    <> projectDeclaredPathProblemContribution pathProblems
    <> projectAutogenProblemContribution autogenProblems
    <> projectSignatureProblemContribution signatureProblems
    <> projectReexportProblemContribution reexportProblems
    <> projectBuildInfoProblemContribution buildInfoProblems
    <> projectGhcOptionProblemContribution ghcOptionProblems
    <> projectCppOptionProblemContribution cppOptionProblems
    <> projectHazardousExtensionProblemContribution hazardousExtensionProblems
    <> projectLanguageProblemContribution languageProblems
    <> projectExtensionProblemContribution extensionProblems
    <> projectDependencyProblemContribution dependencyProblems
 where
  config = viewConfig view
  unresolvedDependencies = componentConfigDependencies config
  pathProblems =
#if defined(VALIDATION_COMPILER_PLAN_DECLARED_PATH_BYPASS_MUTANT)
    []
#else
    [CabalDeclaredPathUnsafe (viewName view) path | path <- viewUnsafePaths view]
#endif
  autogenProblems =
#if defined(VALIDATION_COMPILER_PLAN_AUTOGEN_MODULE_BYPASS_MUTANT)
    []
#else
    [CabalAutogenModuleUnsupported (viewName view) name | name <- viewAutogenModules view]
#endif
  signatureProblems =
#if defined(VALIDATION_COMPILER_PLAN_SIGNATURE_MODULE_BYPASS_MUTANT)
    []
#else
    [CabalSignatureModuleUnsupported (viewName view) name | name <- viewSignatureModules view]
#endif
  reexportProblems =
#if defined(VALIDATION_COMPILER_PLAN_REEXPORT_MODULE_BYPASS_MUTANT)
    []
#else
    [CabalModuleReexportUnsupported (viewName view) name | name <- viewReexportedModules view]
#endif
  buildInfoProblems =
    [ CabalBuildInfoFieldUnclosed (viewName view) field
    | field <- projectUnsupportedBuildInfoFields (viewUnsupportedBuildInfoFields view)
    ]
  ghcOptionProblems =
#if defined(VALIDATION_COMPILER_PLAN_GHC_OPTION_BYPASS_MUTANT)
    []
#else
    [ CabalCompilerOptionUnclosed (viewName view) option
    | option <- componentConfigGhcOptions config
    ]
#endif
  cppOptionProblems =
#if defined(VALIDATION_COMPILER_PLAN_CPP_OPTION_BYPASS_MUTANT)
    []
#else
    [CabalCompilerOptionUnclosed (viewName view) option | option <- componentConfigCppOptions config]
#endif
  hazardousExtensionProblems =
    projectHazardousExtensionProblems
      [ CabalCompilerOptionUnclosed (viewName view) extension
      | extension <- componentConfigExtensions config
      , hazardousExtension extension
      ]
  languageProblems =
#if defined(VALIDATION_COMPILER_PLAN_LANGUAGE_RESIDUE_BYPASS_MUTANT)
    []
#else
    [ CabalCompilerLanguageUnclosed (viewName view) (componentConfigDefaultLanguage config)
    | componentConfigDefaultLanguage config /= Just "GHC2024"
    ]
#endif
  extensionProblems =
#if defined(VALIDATION_COMPILER_PLAN_EXTENSION_RESIDUE_BYPASS_MUTANT)
    []
#else
    [ CabalCompilerExtensionsUnclosed (viewName view) (componentConfigExtensions config)
    | not (null (componentConfigExtensions config))
    ]
#endif
  dependencyProblems =
    projectDependencyProblems
      [ CabalCompilerDependenciesUnclosed (viewName view) unresolvedDependencies
      | not (null unresolvedDependencies)
      ]

projectViewResourceProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_VIEW_RESOURCE_PROBLEMS_DROP_MUTANT)
projectViewResourceProblemContribution _ = []
#else
projectViewResourceProblemContribution = id
#endif

projectDeclaredPathProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_DECLARED_PATH_PROBLEMS_DROP_MUTANT)
projectDeclaredPathProblemContribution _ = []
#else
projectDeclaredPathProblemContribution = id
#endif

projectAutogenProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_AUTOGEN_PROBLEMS_DROP_MUTANT)
projectAutogenProblemContribution _ = []
#else
projectAutogenProblemContribution = id
#endif

projectSignatureProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_SIGNATURE_PROBLEMS_DROP_MUTANT)
projectSignatureProblemContribution _ = []
#else
projectSignatureProblemContribution = id
#endif

projectReexportProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_REEXPORT_PROBLEMS_DROP_MUTANT)
projectReexportProblemContribution _ = []
#else
projectReexportProblemContribution = id
#endif

projectBuildInfoProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_BUILDINFO_PROBLEMS_DROP_MUTANT)
projectBuildInfoProblemContribution _ = []
#else
projectBuildInfoProblemContribution = id
#endif

projectGhcOptionProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_GHC_OPTION_PROBLEMS_DROP_MUTANT)
projectGhcOptionProblemContribution _ = []
#else
projectGhcOptionProblemContribution = id
#endif

projectCppOptionProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_CPP_OPTION_PROBLEMS_DROP_MUTANT)
projectCppOptionProblemContribution _ = []
#else
projectCppOptionProblemContribution = id
#endif

projectHazardousExtensionProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_HAZARDOUS_EXTENSION_PROBLEMS_DROP_MUTANT)
projectHazardousExtensionProblemContribution _ = []
#else
projectHazardousExtensionProblemContribution = id
#endif

projectLanguageProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_LANGUAGE_PROBLEMS_DROP_MUTANT)
projectLanguageProblemContribution _ = []
#else
projectLanguageProblemContribution = id
#endif

projectExtensionProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_EXTENSION_PROBLEMS_DROP_MUTANT)
projectExtensionProblemContribution _ = []
#else
projectExtensionProblemContribution = id
#endif

projectDependencyProblemContribution :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_COMPOSITION_DEPENDENCY_PROBLEMS_DROP_MUTANT)
projectDependencyProblemContribution _ = []
#else
projectDependencyProblemContribution = id
#endif

projectHazardousExtensionProblems :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_HAZARDOUS_EXTENSION_OPTION_BYPASS_MUTANT)
projectHazardousExtensionProblems _ = []
#else
projectHazardousExtensionProblems = id
#endif

projectDependencyProblems :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_DEPENDENCY_BYPASS_MUTANT)
projectDependencyProblems _ = []
#else
projectDependencyProblems = id
#endif

-- Every BuildInfo field which the fixed linked-GHC session does not project is
-- explicit residue.  This list is derived from Cabal's parsed structure; it is
-- not a caller-authored declaration of completeness.
unsupportedBuildInfoFields :: BuildInfo -> [Text]
unsupportedBuildInfoFields info =
  sort
    ( buildableFields
        <> legacyBuildToolFields
        <> buildToolDependencyFields
        <> asmOptionFields
        <> cmmOptionFields
        <> ccOptionFields
        <> cxxOptionFields
        <> jsppOptionFields
        <> ldOptionFields
        <> hsc2hsOptionFields
        <> pkgconfigDependencyFields
        <> frameworkFields
        <> extraFrameworkDirectoryFields
        <> asmSourceFields
        <> cmmSourceFields
        <> cSourceFields
        <> cxxSourceFields
        <> jsSourceFields
        <> virtualModuleFields
        <> otherLanguageFields
        <> extraLibraryFields
        <> extraStaticLibraryFields
        <> extraGhciLibraryFields
        <> extraBundledLibraryFields
        <> extraLibraryFlavourFields
        <> extraDynamicLibraryFlavourFields
        <> extraLibraryDirectoryFields
        <> extraStaticLibraryDirectoryFields
        <> includeDirectoryFields
        <> includeFields
        <> autogenIncludeFields
        <> installIncludeFields
        <> profilingOptionFields
        <> ghcjsOptionFields
        <> ghcjsProfilingOptionFields
        <> sharedOptionFields
        <> ghcjsSharedOptionFields
        <> profilingSharedOptionFields
        <> ghcjsProfilingSharedOptionFields
        <> customBuildInfoFieldFields
        <> mixinFields
    )
 where
  flag :: Text -> Bool -> [Text]
  flag label present = [label | present]
  nonempty :: Foldable collection => Text -> collection value -> [Text]
  nonempty label values = flag label (not (null values))
  buildableFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_BUILDABLE_ALTERNATIVE_DROP_MUTANT)
    flag "buildable=false" (not (buildable info)) `seq` []
#else
    flag "buildable=false" (not (buildable info))
#endif
  legacyBuildToolFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_BUILD_TOOLS_ALTERNATIVE_DROP_MUTANT)
    nonempty "build-tools" (buildTools info) `seq` []
#else
    nonempty "build-tools" (buildTools info)
#endif
  buildToolDependencyFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_BUILD_TOOL_DEPENDS_ALTERNATIVE_DROP_MUTANT)
    nonempty "build-tool-depends" (buildToolDepends info) `seq` []
#else
    nonempty "build-tool-depends" (buildToolDepends info)
#endif
  asmOptionFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_ASM_OPTIONS_ALTERNATIVE_DROP_MUTANT)
    nonempty "asm-options" (asmOptions info) `seq` []
#else
    nonempty "asm-options" (asmOptions info)
#endif
  cmmOptionFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_CMM_OPTIONS_ALTERNATIVE_DROP_MUTANT)
    nonempty "cmm-options" (cmmOptions info) `seq` []
#else
    nonempty "cmm-options" (cmmOptions info)
#endif
  ccOptionFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_CC_OPTIONS_ALTERNATIVE_DROP_MUTANT)
    nonempty "cc-options" (ccOptions info) `seq` []
#else
    nonempty "cc-options" (ccOptions info)
#endif
  cxxOptionFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_CXX_OPTIONS_ALTERNATIVE_DROP_MUTANT)
    nonempty "cxx-options" (cxxOptions info) `seq` []
#else
    nonempty "cxx-options" (cxxOptions info)
#endif
  jsppOptionFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_JSPP_OPTIONS_ALTERNATIVE_DROP_MUTANT)
    nonempty "jspp-options" (jsppOptions info) `seq` []
#else
    nonempty "jspp-options" (jsppOptions info)
#endif
  ldOptionFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_LD_OPTIONS_ALTERNATIVE_DROP_MUTANT)
    nonempty "ld-options" (ldOptions info) `seq` []
#else
    nonempty "ld-options" (ldOptions info)
#endif
  hsc2hsOptionFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_HSC2HS_OPTIONS_ALTERNATIVE_DROP_MUTANT)
    nonempty "hsc2hs-options" (hsc2hsOptions info) `seq` []
#else
    nonempty "hsc2hs-options" (hsc2hsOptions info)
#endif
  pkgconfigDependencyFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_PKGCONFIG_DEPENDS_ALTERNATIVE_DROP_MUTANT)
    nonempty "pkgconfig-depends" (pkgconfigDepends info) `seq` []
#else
    nonempty "pkgconfig-depends" (pkgconfigDepends info)
#endif
  frameworkFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_FRAMEWORKS_ALTERNATIVE_DROP_MUTANT)
    nonempty "frameworks" (frameworks info) `seq` []
#else
    nonempty "frameworks" (frameworks info)
#endif
  extraFrameworkDirectoryFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_EXTRA_FRAMEWORK_DIRS_ALTERNATIVE_DROP_MUTANT)
    nonempty "extra-framework-dirs" (extraFrameworkDirs info) `seq` []
#else
    nonempty "extra-framework-dirs" (extraFrameworkDirs info)
#endif
  asmSourceFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_ASM_SOURCES_ALTERNATIVE_DROP_MUTANT)
    nonempty "asm-sources" (asmSources info) `seq` []
#else
    nonempty "asm-sources" (asmSources info)
#endif
  cmmSourceFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_CMM_SOURCES_ALTERNATIVE_DROP_MUTANT)
    nonempty "cmm-sources" (cmmSources info) `seq` []
#else
    nonempty "cmm-sources" (cmmSources info)
#endif
  cSourceFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_C_SOURCES_ALTERNATIVE_DROP_MUTANT)
    nonempty "c-sources" (cSources info) `seq` []
#else
    nonempty "c-sources" (cSources info)
#endif
  cxxSourceFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_CXX_SOURCES_ALTERNATIVE_DROP_MUTANT)
    nonempty "cxx-sources" (cxxSources info) `seq` []
#else
    nonempty "cxx-sources" (cxxSources info)
#endif
  jsSourceFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_JS_SOURCES_ALTERNATIVE_DROP_MUTANT)
    nonempty "js-sources" (jsSources info) `seq` []
#else
    nonempty "js-sources" (jsSources info)
#endif
  virtualModuleFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_VIRTUAL_MODULES_ALTERNATIVE_DROP_MUTANT)
    nonempty "virtual-modules" (virtualModules info) `seq` []
#else
    nonempty "virtual-modules" (virtualModules info)
#endif
  otherLanguageFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_OTHER_LANGUAGES_ALTERNATIVE_DROP_MUTANT)
    nonempty "other-languages" (otherLanguages info) `seq` []
#else
    nonempty "other-languages" (otherLanguages info)
#endif
  extraLibraryFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_EXTRA_LIBS_ALTERNATIVE_DROP_MUTANT)
    nonempty "extra-libs" (extraLibs info) `seq` []
#else
    nonempty "extra-libs" (extraLibs info)
#endif
  extraStaticLibraryFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_EXTRA_LIBS_STATIC_ALTERNATIVE_DROP_MUTANT)
    nonempty "extra-libs-static" (extraLibsStatic info) `seq` []
#else
    nonempty "extra-libs-static" (extraLibsStatic info)
#endif
  extraGhciLibraryFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_EXTRA_GHCI_LIBS_ALTERNATIVE_DROP_MUTANT)
    nonempty "extra-ghci-libs" (extraGHCiLibs info) `seq` []
#else
    nonempty "extra-ghci-libs" (extraGHCiLibs info)
#endif
  extraBundledLibraryFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_EXTRA_BUNDLED_LIBS_ALTERNATIVE_DROP_MUTANT)
    nonempty "extra-bundled-libs" (extraBundledLibs info) `seq` []
#else
    nonempty "extra-bundled-libs" (extraBundledLibs info)
#endif
  extraLibraryFlavourFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_EXTRA_LIB_FLAVOURS_ALTERNATIVE_DROP_MUTANT)
    nonempty "extra-lib-flavours" (extraLibFlavours info) `seq` []
#else
    nonempty "extra-lib-flavours" (extraLibFlavours info)
#endif
  extraDynamicLibraryFlavourFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_EXTRA_DYN_LIB_FLAVOURS_ALTERNATIVE_DROP_MUTANT)
    nonempty "extra-dyn-lib-flavours" (extraDynLibFlavours info) `seq` []
#else
    nonempty "extra-dyn-lib-flavours" (extraDynLibFlavours info)
#endif
  extraLibraryDirectoryFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_EXTRA_LIB_DIRS_ALTERNATIVE_DROP_MUTANT)
    nonempty "extra-lib-dirs" (extraLibDirs info) `seq` []
#else
    nonempty "extra-lib-dirs" (extraLibDirs info)
#endif
  extraStaticLibraryDirectoryFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_EXTRA_LIB_DIRS_STATIC_ALTERNATIVE_DROP_MUTANT)
    nonempty "extra-lib-dirs-static" (extraLibDirsStatic info) `seq` []
#else
    nonempty "extra-lib-dirs-static" (extraLibDirsStatic info)
#endif
  includeDirectoryFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_INCLUDE_DIRS_ALTERNATIVE_DROP_MUTANT)
    nonempty "include-dirs" (includeDirs info) `seq` []
#else
    nonempty "include-dirs" (includeDirs info)
#endif
  includeFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_INCLUDES_ALTERNATIVE_DROP_MUTANT)
    nonempty "includes" (includes info) `seq` []
#else
    nonempty "includes" (includes info)
#endif
  autogenIncludeFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_AUTOGEN_INCLUDES_ALTERNATIVE_DROP_MUTANT)
    nonempty "autogen-includes" (autogenIncludes info) `seq` []
#else
    nonempty "autogen-includes" (autogenIncludes info)
#endif
  installIncludeFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_INSTALL_INCLUDES_ALTERNATIVE_DROP_MUTANT)
    nonempty "install-includes" (installIncludes info) `seq` []
#else
    nonempty "install-includes" (installIncludes info)
#endif
  profilingOptionFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_PROF_OPTIONS_ALTERNATIVE_DROP_MUTANT)
    nonempty "prof-options" (hcProfOptions GHC info) `seq` []
#else
    nonempty "prof-options" (hcProfOptions GHC info)
#endif
  ghcjsOptionFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_GHCJS_OPTIONS_ALTERNATIVE_DROP_MUTANT)
    nonempty "ghcjs-options" (hcOptions GHCJS info) `seq` []
#else
    nonempty "ghcjs-options" (hcOptions GHCJS info)
#endif
  ghcjsProfilingOptionFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_GHCJS_PROF_OPTIONS_ALTERNATIVE_DROP_MUTANT)
    nonempty "ghcjs-prof-options" (hcProfOptions GHCJS info) `seq` []
#else
    nonempty "ghcjs-prof-options" (hcProfOptions GHCJS info)
#endif
  sharedOptionFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_SHARED_OPTIONS_ALTERNATIVE_DROP_MUTANT)
    nonempty "shared-options" (hcSharedOptions GHC info) `seq` []
#else
    nonempty "shared-options" (hcSharedOptions GHC info)
#endif
  ghcjsSharedOptionFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_GHCJS_SHARED_OPTIONS_ALTERNATIVE_DROP_MUTANT)
    nonempty "ghcjs-shared-options" (hcSharedOptions GHCJS info) `seq` []
#else
    nonempty "ghcjs-shared-options" (hcSharedOptions GHCJS info)
#endif
  profilingSharedOptionFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_PROF_SHARED_OPTIONS_ALTERNATIVE_DROP_MUTANT)
    nonempty "prof-shared-options" (hcProfSharedOptions GHC info) `seq` []
#else
    nonempty "prof-shared-options" (hcProfSharedOptions GHC info)
#endif
  ghcjsProfilingSharedOptionFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_GHCJS_PROF_SHARED_OPTIONS_ALTERNATIVE_DROP_MUTANT)
    nonempty "ghcjs-prof-shared-options" (hcProfSharedOptions GHCJS info) `seq` []
#else
    nonempty "ghcjs-prof-shared-options" (hcProfSharedOptions GHCJS info)
#endif
  customBuildInfoFieldFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_CUSTOM_FIELDS_ALTERNATIVE_DROP_MUTANT)
    nonempty "custom-fields" (customFieldsBI info) `seq` []
#else
    nonempty "custom-fields" (customFieldsBI info)
#endif
  mixinFields =
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_MIXINS_ALTERNATIVE_DROP_MUTANT)
    nonempty "mixins" (mixins info) `seq` []
#else
    nonempty "mixins" (mixins info)
#endif

hazardousExtension :: Text -> Bool
hazardousExtension extension =
  cppAlternative
    || templateHaskellAlternative
    || templateHaskellQuotesAlternative
    || quasiQuotesAlternative
    || foreignFunctionInterfaceAlternative
    || cApiFfiAlternative
    || unliftedFfiTypesAlternative
    || javaScriptFfiAlternative
 where
  cppAlternative =
#if defined(VALIDATION_COMPILER_PLAN_HAZARDOUS_EXTENSION_CPP_ALTERNATIVE_DROP_MUTANT)
    False
#else
    extension == "CPP"
#endif
  templateHaskellAlternative =
#if defined(VALIDATION_COMPILER_PLAN_HAZARDOUS_EXTENSION_TEMPLATE_HASKELL_ALTERNATIVE_DROP_MUTANT)
    False
#else
    extension == "TemplateHaskell"
#endif
  templateHaskellQuotesAlternative =
#if defined(VALIDATION_COMPILER_PLAN_HAZARDOUS_EXTENSION_TEMPLATE_HASKELL_QUOTES_ALTERNATIVE_DROP_MUTANT)
    False
#else
    extension == "TemplateHaskellQuotes"
#endif
  quasiQuotesAlternative =
#if defined(VALIDATION_COMPILER_PLAN_HAZARDOUS_EXTENSION_QUASI_QUOTES_ALTERNATIVE_DROP_MUTANT)
    False
#else
    extension == "QuasiQuotes"
#endif
  foreignFunctionInterfaceAlternative =
#if defined(VALIDATION_COMPILER_PLAN_HAZARDOUS_EXTENSION_FOREIGN_FUNCTION_INTERFACE_ALTERNATIVE_DROP_MUTANT)
    False
#else
    extension == "ForeignFunctionInterface"
#endif
  cApiFfiAlternative =
#if defined(VALIDATION_COMPILER_PLAN_HAZARDOUS_EXTENSION_C_API_FFI_ALTERNATIVE_DROP_MUTANT)
    False
#else
    extension == "CApiFFI"
#endif
  unliftedFfiTypesAlternative =
#if defined(VALIDATION_COMPILER_PLAN_HAZARDOUS_EXTENSION_UNLIFTED_FFI_TYPES_ALTERNATIVE_DROP_MUTANT)
    False
#else
    extension == "UnliftedFFITypes"
#endif
  javaScriptFfiAlternative =
#if defined(VALIDATION_COMPILER_PLAN_HAZARDOUS_EXTENSION_JAVA_SCRIPT_FFI_ALTERNATIVE_DROP_MUTANT)
    False
#else
    extension == "JavaScriptFFI"
#endif

projectUnsupportedBuildInfoFields :: [Text] -> [Text]
#if defined(VALIDATION_COMPILER_PLAN_BUILDINFO_FIRST_FIELD_DROP_MUTANT)
projectUnsupportedBuildInfoFields [] = []
projectUnsupportedBuildInfoFields (_ : remaining) = remaining
#else
projectUnsupportedBuildInfoFields = id
#endif

configurationProblems :: [ComponentAssignment] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_CONFIGURATION_DIFFERENCE_BYPASS_MUTANT)
configurationProblems assignments =
  assignments
    `seq` projectConfigurationComponentKey ""
    `seq` projectConfigurationConfigContribution []
    `seq` canonicalConfigurationSet []
    `seq` configurationDifferencePresent []
    `seq` []
#else
configurationProblems assignments =
  [ CabalComponentConfigurationsDiffer component configs
  | (component, configs) <- Map.toAscList byComponent
  , configurationDifferencePresent configs
  ]
 where
  byComponent =
    Map.map canonicalConfigurationSet
      ( Map.fromListWith (<>)
          [ ( projectConfigurationComponentKey (componentAssignmentName assignment)
            , projectConfigurationConfigContribution (componentAssignmentConfigs assignment)
            )
          | assignment <- assignments
          ]
      )
#endif

projectConfigurationComponentKey :: Text -> Text
#if defined(VALIDATION_COMPILER_PLAN_CONFIGURATION_COMPONENT_KEY_MAPPING_MUTANT)
projectConfigurationComponentKey _ = "mutated-component-key"
#else
projectConfigurationComponentKey = id
#endif

projectConfigurationConfigContribution :: [ComponentCompilerConfig] -> [ComponentCompilerConfig]
#if defined(VALIDATION_COMPILER_PLAN_CONFIGURATION_CONFIG_CONTRIBUTION_DROP_MUTANT)
projectConfigurationConfigContribution _ = []
#else
projectConfigurationConfigContribution = id
#endif

canonicalConfigurationSet :: [ComponentCompilerConfig] -> [ComponentCompilerConfig]
canonicalConfigurationSet = projectConfigurationOrder . projectConfigurationDeduplication

projectConfigurationDeduplication :: [ComponentCompilerConfig] -> [ComponentCompilerConfig]
#if defined(VALIDATION_COMPILER_PLAN_CONFIGURATION_DEDUPLICATION_BYPASS_MUTANT)
projectConfigurationDeduplication = id
#else
projectConfigurationDeduplication = Set.toList . Set.fromList
#endif

projectConfigurationOrder :: [ComponentCompilerConfig] -> [ComponentCompilerConfig]
#if defined(VALIDATION_COMPILER_PLAN_CONFIGURATION_ORDER_MUTANT)
projectConfigurationOrder = reverse . sort
#else
projectConfigurationOrder = sort
#endif

configurationDifferencePresent :: [ComponentCompilerConfig] -> Bool
#if defined(VALIDATION_COMPILER_PLAN_CONFIGURATION_THRESHOLD_WIDEN_MUTANT)
configurationDifferencePresent configs = length configs > 2
#else
configurationDifferencePresent configs = length configs > 1
#endif

conditionalProblems :: FilePath -> GenericPackageDescription -> [ComponentPlanProblem]
conditionalProblems cabalPath description =
  projectConditionalProblems
    ( concat
        [ maybe [] (conditionsFor "lib") (condLibrary description)
        , concat [conditionsFor ("lib:" <> Text.pack (unUnqualComponentName name)) tree | (name, tree) <- condSubLibraries description]
        , concat [conditionsFor ("exe:" <> Text.pack (unUnqualComponentName name)) tree | (name, tree) <- condExecutables description]
        , concat [conditionsFor ("test:" <> Text.pack (unUnqualComponentName name)) tree | (name, tree) <- condTestSuites description]
        , concat [conditionsFor ("bench:" <> Text.pack (unUnqualComponentName name)) tree | (name, tree) <- condBenchmarks description]
        ]
    )
 where
  packageRoot = normalizeRoot (posixDirectory cabalPath)
  conditionsFor
    :: Show variable
    => Text
    -> CondTree variable constraints component
    -> [ComponentPlanProblem]
  conditionsFor label =
    map
      (CabalConditionalConfigurationUnclosed (packageQualified packageRoot label) . Text.pack)
      . treeConditions

projectConditionalProblems :: [ComponentPlanProblem] -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_CONDITIONAL_BYPASS_MUTANT)
projectConditionalProblems _ = []
#else
projectConditionalProblems = id
#endif

treeConditions :: Show variable => CondTree variable constraints component -> [String]
treeConditions (CondNode _ _ branches) = concatMap branchConditions branches
 where
  branchConditions (CondBranch condition trueBranch falseBranch) =
    projectConditionalConditionContribution [show condition]
      <> projectConditionalTrueRecursionContribution (treeConditions trueBranch)
      <> projectConditionalFalseRecursionContribution (maybe [] treeConditions falseBranch)

projectConditionalConditionContribution :: [String] -> [String]
#if defined(VALIDATION_COMPILER_PLAN_CONDITIONAL_CONDITION_CONTRIBUTION_DROP_MUTANT)
projectConditionalConditionContribution _ = []
#else
projectConditionalConditionContribution = id
#endif

projectConditionalTrueRecursionContribution :: [String] -> [String]
#if defined(VALIDATION_COMPILER_PLAN_CONDITIONAL_TRUE_RECURSION_CONTRIBUTION_DROP_MUTANT)
projectConditionalTrueRecursionContribution _ = []
#else
projectConditionalTrueRecursionContribution = id
#endif

projectConditionalFalseRecursionContribution :: [String] -> [String]
#if defined(VALIDATION_COMPILER_PLAN_CONDITIONAL_FALSE_RECURSION_CONTRIBUTION_DROP_MUTANT)
projectConditionalFalseRecursionContribution _ = []
#else
projectConditionalFalseRecursionContribution = id
#endif

foreignProblems :: FilePath -> GenericPackageDescription -> [ComponentPlanProblem]
#if defined(VALIDATION_COMPILER_PLAN_FOREIGN_LIBRARY_BYPASS_MUTANT)
foreignProblems _ _ = []
#else
foreignProblems cabalPath description =
  [ CabalForeignLibraryUnsupported cabalPath (Text.pack (unUnqualComponentName name))
  | (name, _) <- condForeignLibs description
  ]
#endif

componentPlanProblemFinding :: ComponentPlanProblem -> Finding
componentPlanProblemFinding problem =
  finding
    (projectFindingCode code)
    (projectFindingSubject subject)
    (projectFindingDetail detail)
 where
  (code, subject, detail) = componentPlanProblemFields problem

projectFindingCode :: Text -> Text
#if defined(VALIDATION_COMPILER_PLAN_FINDING_CODE_FIELD_MAPPING_MUTANT)
projectFindingCode _ = "MUTATED-FINDING-CODE"
#else
projectFindingCode = id
#endif

projectFindingSubject :: FilePath -> FilePath
#if defined(VALIDATION_COMPILER_PLAN_FINDING_SUBJECT_FIELD_MAPPING_MUTANT)
projectFindingSubject _ = "mutated-finding-subject"
#else
projectFindingSubject = id
#endif

projectFindingDetail :: Text -> Text
#if defined(VALIDATION_COMPILER_PLAN_FINDING_DETAIL_FIELD_MAPPING_MUTANT)
projectFindingDetail _ = "mutated finding detail"
#else
projectFindingDetail = id
#endif

renderComponentPlanProblem :: ComponentPlanProblem -> Text
renderComponentPlanProblem problem =
  renderProblemCode code
    <> renderProblemFirstSeparator
    <> renderProblemSubject (Text.pack subject)
    <> renderProblemSecondSeparator
    <> renderProblemDetail detail
 where
  (code, subject, detail) = componentPlanProblemFields problem

renderProblemCode :: Text -> Text
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_RENDER_CODE_MUTANT)
renderProblemCode _ = "MUTATED-CODE"
#else
renderProblemCode = id
#endif

renderProblemFirstSeparator :: Text
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_RENDER_FIRST_SEPARATOR_MUTANT)
renderProblemFirstSeparator = "!"
#else
renderProblemFirstSeparator = "\t"
#endif

renderProblemSubject :: Text -> Text
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_RENDER_SUBJECT_MUTANT)
renderProblemSubject _ = "mutated-subject"
#else
renderProblemSubject = id
#endif

renderProblemSecondSeparator :: Text
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_RENDER_SECOND_SEPARATOR_MUTANT)
renderProblemSecondSeparator = "!"
#else
renderProblemSecondSeparator = "\t"
#endif

renderProblemDetail :: Text -> Text
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_RENDER_DETAIL_MUTANT)
renderProblemDetail _ = "mutated-detail"
#else
renderProblemDetail = id
#endif

componentPlanProblemFields :: ComponentPlanProblem -> (Text, FilePath, Text)
componentPlanProblemFields problem =
  applyProblemFieldMappingMutation problem (unmutatedComponentPlanProblemFields problem)

unmutatedComponentPlanProblemFields :: ComponentPlanProblem -> (Text, FilePath, Text)
unmutatedComponentPlanProblemFields problem = case problem of
  ComponentPlanSnapshotEntryLimitExceeded limit observed ->
    limitFields "COMPONENT-PLAN-SNAPSHOT-ENTRY-LIMIT" "compiler-component-plan" limit observed
  ComponentPlanPathByteLimitExceeded ordinal limit observed ->
    limitFields "COMPONENT-PLAN-PATH-BYTE-LIMIT" ("entry-" <> show ordinal) limit observed
  ComponentPlanModeByteLimitExceeded ordinal limit observed ->
    limitFields "COMPONENT-PLAN-MODE-BYTE-LIMIT" ("entry-" <> show ordinal) limit observed
  ComponentPlanObjectIdentityByteLimitExceeded ordinal limit observed ->
    limitFields "COMPONENT-PLAN-OBJECT-IDENTITY-BYTE-LIMIT" ("entry-" <> show ordinal) limit observed
  ComponentPlanSnapshotIdentityByteLimitExceeded limit observed ->
    limitFields "COMPONENT-PLAN-SNAPSHOT-IDENTITY-BYTE-LIMIT" "compiler-component-plan" limit observed
  ComponentPlanBlobByteLimitExceeded path limit observed ->
    limitFields "COMPONENT-PLAN-BLOB-BYTE-LIMIT" path limit observed
  ComponentPlanAggregateBlobByteLimitExceeded limit observed ->
    limitFields "COMPONENT-PLAN-AGGREGATE-BLOB-BYTE-LIMIT" "compiler-component-plan" limit observed
  ComponentPlanPathEmpty ordinal ->
    ("COMPONENT-PLAN-PATH-EMPTY", "entry-" <> show ordinal, "repository paths must contain at least one byte")
  ComponentPlanPathAbsolute path ->
    ("COMPONENT-PLAN-PATH-ABSOLUTE", path, "repository paths must be relative POSIX paths")
  ComponentPlanPathNul path ->
    ("COMPONENT-PLAN-PATH-NUL", path, "repository paths must not contain NUL")
  ComponentPlanPathBackslash path ->
    ("COMPONENT-PLAN-PATH-BACKSLASH", path, "backslash is not a POSIX repository-path separator")
  ComponentPlanPathEmptySegment path ->
    ("COMPONENT-PLAN-PATH-EMPTY-SEGMENT", path, "repository paths must not contain empty segments")
  ComponentPlanPathDotSegment path ->
    ("COMPONENT-PLAN-PATH-DOT-SEGMENT", path, "repository paths must not contain dot segments")
  ComponentPlanPathParentSegment path ->
    ("COMPONENT-PLAN-PATH-PARENT-SEGMENT", path, "repository paths must not contain parent segments")
  ComponentPlanPathCharacterUnsafe path ->
    ("COMPONENT-PLAN-PATH-CHARACTER-UNSAFE", path, "repository paths admit only ASCII alphanumeric and ._+@/=- characters")
  ComponentPlanDuplicatePath path ->
    ("COMPONENT-PLAN-DUPLICATE-PATH", path, "the raw inventory contains the path more than once")
  ComponentPlanEntryOrderInvalid paths ->
    ("COMPONENT-PLAN-ENTRY-ORDER", "compiler-component-plan", "observed=" <> shown paths <> "; required=ascending POSIX byte order")
  ComponentPlanModeMalformed path mode ->
    ("COMPONENT-PLAN-MODE-MALFORMED", path, "observed=" <> mode <> "; admitted=100644|100755|120000")
  ComponentPlanObjectIdentityMalformed path objectIdentity ->
    ("COMPONENT-PLAN-OBJECT-IDENTITY-MALFORMED", path, "observed=" <> objectIdentity <> "; admitted=40-or-64 lowercase hexadecimal")
  ComponentPlanObjectIdentityMismatch path observed expected ->
    ("COMPONENT-PLAN-OBJECT-IDENTITY-MISMATCH", path, "expected=" <> expected <> "; observed=" <> observed)
  ComponentPlanSnapshotIdentityMalformed identity ->
    ("COMPONENT-PLAN-SNAPSHOT-IDENTITY-MALFORMED", "compiler-component-plan", "observed=" <> identity <> "; required=64 lowercase hexadecimal")
  ComponentPlanSnapshotIdentityMismatch expected observed ->
    ("COMPONENT-PLAN-SNAPSHOT-IDENTITY-MISMATCH", "compiler-component-plan", "expected=" <> expected <> "; observed=" <> observed)
  ComponentPlanCabalEntryLimitExceeded limit observed ->
    limitFields "COMPONENT-PLAN-CABAL-ENTRY-LIMIT" "compiler-component-plan" limit observed
  ComponentPlanCabalByteLimitExceeded path limit observed ->
    limitFields "COMPONENT-PLAN-CABAL-BYTE-LIMIT" path limit observed
  ComponentPlanComponentLimitExceeded path limit observed ->
    limitFields "COMPONENT-PLAN-COMPONENT-LIMIT" path limit observed
  ComponentPlanConditionalLimitExceeded path limit observed ->
    limitFields "COMPONENT-PLAN-CONDITIONAL-LIMIT" path limit observed
  ComponentPlanModuleLimitExceeded path limit observed ->
    limitFields "COMPONENT-PLAN-MODULE-LIMIT" path limit observed
  ComponentPlanSourceDirectoryLimitExceeded path limit observed ->
    limitFields "COMPONENT-PLAN-SOURCE-DIRECTORY-LIMIT" path limit observed
  ComponentPlanConfigurationLimitExceeded path limit observed ->
    limitFields "COMPONENT-PLAN-CONFIGURATION-LIMIT" path limit observed
  ComponentPlanOptionLimitExceeded path limit observed ->
    limitFields "COMPONENT-PLAN-OPTION-LIMIT" path limit observed
  ComponentPlanDependencyLimitExceeded path limit observed ->
    limitFields "COMPONENT-PLAN-DEPENDENCY-LIMIT" path limit observed
  ComponentPlanAssignmentLimitExceeded limit observed ->
    limitFields "COMPONENT-PLAN-ASSIGNMENT-LIMIT" "compiler-component-plan" limit observed
  ComponentPlanProblemLimitExceeded limit observed ->
    limitFields "COMPONENT-PLAN-PROBLEM-LIMIT" "compiler-component-plan" limit observed
  CabalDescriptionAbsent ->
    ("CABAL-DESCRIPTION-ABSENT", "compiler-component-plan", "no bounded immutable .cabal declaration was present")
  CabalProjectElaborationUnavailable path ->
    ("CABAL-PROJECT-ELABORATION-UNAVAILABLE", path, "cabal.project requires an authenticated elaborated install plan")
  CabalDescriptionParseFailed path ->
    ("CABAL-DESCRIPTION-PARSE-FAILED", path, "the bounded immutable Cabal bytes did not parse")
  CabalDescriptionParseWarning path ->
    ("CABAL-DESCRIPTION-PARSE-WARNING", path, "the bounded immutable Cabal bytes produced at least one parser warning")
  CabalBuildTypeUnsupported path buildType ->
    ("CABAL-BUILD-TYPE-UNSUPPORTED", path, "observed=" <> buildType <> "; admitted=Simple")
  CabalCustomSetupUnsupported path ->
    ("CABAL-CUSTOM-SETUP-UNSUPPORTED", path, "custom Setup execution is outside the restricted component diagnostic")
  CabalPackageFieldUnclosed path field ->
    ("CABAL-PACKAGE-FIELD-UNCLOSED", path, "field=" <> field)
  CabalConditionalConfigurationUnclosed component condition ->
    ("CABAL-CONDITIONAL-CONFIGURATION-UNCLOSED", Text.unpack component, "condition=" <> condition)
  CabalForeignLibraryUnsupported path name ->
    ("CABAL-FOREIGN-LIBRARY-UNSUPPORTED", path, "name=" <> name)
  CabalSignatureModuleUnsupported component name ->
    ("CABAL-SIGNATURE-MODULE-UNSUPPORTED", Text.unpack component, "module=" <> name)
  CabalAutogenModuleUnsupported component name ->
    ("CABAL-AUTOGEN-MODULE-UNSUPPORTED", Text.unpack component, "module=" <> name)
  CabalDeclaredModuleMissing component name candidates ->
    ("CABAL-DECLARED-MODULE-MISSING", Text.unpack component, "module=" <> name <> "; candidates=" <> shown candidates)
  CabalDeclaredModuleAmbiguous component name candidates ->
    ("CABAL-DECLARED-MODULE-AMBIGUOUS", Text.unpack component, "module=" <> name <> "; candidates=" <> shown candidates)
  CabalMainModuleMissing component mainPath candidates ->
    ("CABAL-MAIN-MODULE-MISSING", Text.unpack component, "main=" <> Text.pack mainPath <> "; candidates=" <> shown candidates)
  CabalMainModuleAmbiguous component mainPath candidates ->
    ("CABAL-MAIN-MODULE-AMBIGUOUS", Text.unpack component, "main=" <> Text.pack mainPath <> "; candidates=" <> shown candidates)
  CabalDeclaredModuleExpectationConflict component path modules ->
    ("CABAL-DECLARED-MODULE-EXPECTATION-CONFLICT", path, "component=" <> component <> "; modules=" <> shown modules)
  CabalDeclaredPathUnsafe component path ->
    ("CABAL-DECLARED-PATH-UNSAFE", path, "component=" <> component <> "; required=safe relative POSIX repository path")
  CabalHaskellSubjectUnowned path ->
    ("CABAL-HASKELL-SUBJECT-UNOWNED", path, "the exact Haskell subject has no Cabal component assignment")
  CabalCompilerOptionUnclosed component option ->
    ("CABAL-COMPILER-OPTION-UNCLOSED", Text.unpack component, "option=" <> option)
  CabalCompilerLanguageUnclosed component languageValue ->
    ("CABAL-COMPILER-LANGUAGE-UNCLOSED", Text.unpack component, "language=" <> shown languageValue)
  CabalCompilerExtensionsUnclosed component extensions ->
    ("CABAL-COMPILER-EXTENSIONS-UNCLOSED", Text.unpack component, "extensions=" <> shown extensions)
  CabalCompilerDependenciesUnclosed component dependencies ->
    ("CABAL-COMPILER-DEPENDENCIES-UNCLOSED", Text.unpack component, "dependencies=" <> shown dependencies)
  CabalBuildInfoFieldUnclosed component field ->
    ("CABAL-BUILD-INFO-FIELD-UNCLOSED", Text.unpack component, "field=" <> field)
  CabalModuleReexportUnsupported component name ->
    ("CABAL-MODULE-REEXPORT-UNSUPPORTED", Text.unpack component, "module=" <> name)
  CabalComponentConfigurationsDiffer component configs ->
    ( "CABAL-COMPONENT-CONFIGURATIONS-DIFFER"
    , Text.unpack component
    , "configurations=["
        <> Text.intercalate "," ["{" <> renderComponentCompilerConfig config <> "}" | config <- configs]
        <> "]"
    )
  CabalMultipleComponentsUnclosed components ->
    ("CABAL-MULTIPLE-COMPONENTS-UNCLOSED", "compiler-component-plan", "components=" <> shown components)

applyProblemFieldMappingMutation
  :: ComponentPlanProblem
  -> (Text, FilePath, Text)
  -> (Text, FilePath, Text)
applyProblemFieldMappingMutation problem (code, subject, detail) =
  ( if problemCodeFieldMappingMutationSelected problem then code <> "-MUTATED" else code
  , if problemSubjectFieldMappingMutationSelected problem then "mutated-problem-subject" else subject
  , if problemDetailFieldMappingMutationSelected problem then "mutated problem detail" else detail
  )

problemCodeFieldMappingMutationSelected :: ComponentPlanProblem -> Bool
problemCodeFieldMappingMutationSelected problem = case problem of
  ComponentPlanSnapshotEntryLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_SNAPSHOT_ENTRY_LIMIT_EXCEEDED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanPathByteLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_PATH_BYTE_LIMIT_EXCEEDED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanModeByteLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_MODE_BYTE_LIMIT_EXCEEDED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanObjectIdentityByteLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_OBJECT_IDENTITY_BYTE_LIMIT_EXCEEDED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanSnapshotIdentityByteLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_SNAPSHOT_IDENTITY_BYTE_LIMIT_EXCEEDED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanBlobByteLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_BLOB_BYTE_LIMIT_EXCEEDED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanAggregateBlobByteLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_AGGREGATE_BLOB_BYTE_LIMIT_EXCEEDED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanPathEmpty {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_PATH_EMPTY_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanPathAbsolute {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_PATH_ABSOLUTE_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanPathNul {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_PATH_NUL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanPathBackslash {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_PATH_BACKSLASH_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanPathEmptySegment {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_PATH_EMPTY_SEGMENT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanPathDotSegment {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_PATH_DOT_SEGMENT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanPathParentSegment {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_PATH_PARENT_SEGMENT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanPathCharacterUnsafe {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_PATH_CHARACTER_UNSAFE_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanDuplicatePath {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_DUPLICATE_PATH_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanEntryOrderInvalid {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_ENTRY_ORDER_INVALID_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanModeMalformed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_MODE_MALFORMED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanObjectIdentityMalformed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_OBJECT_IDENTITY_MALFORMED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanObjectIdentityMismatch {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_OBJECT_IDENTITY_MISMATCH_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanSnapshotIdentityMalformed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_SNAPSHOT_IDENTITY_MALFORMED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanSnapshotIdentityMismatch {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_SNAPSHOT_IDENTITY_MISMATCH_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanCabalEntryLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_CABAL_ENTRY_LIMIT_EXCEEDED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanCabalByteLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_CABAL_BYTE_LIMIT_EXCEEDED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanComponentLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_COMPONENT_LIMIT_EXCEEDED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanConditionalLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_CONDITIONAL_LIMIT_EXCEEDED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanModuleLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_MODULE_LIMIT_EXCEEDED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanSourceDirectoryLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_SOURCE_DIRECTORY_LIMIT_EXCEEDED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanConfigurationLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_CONFIGURATION_LIMIT_EXCEEDED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanOptionLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_OPTION_LIMIT_EXCEEDED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanDependencyLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_DEPENDENCY_LIMIT_EXCEEDED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanAssignmentLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_ASSIGNMENT_LIMIT_EXCEEDED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanProblemLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_PROBLEM_LIMIT_EXCEEDED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalDescriptionAbsent {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_DESCRIPTION_ABSENT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalProjectElaborationUnavailable {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_PROJECT_ELABORATION_UNAVAILABLE_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalDescriptionParseFailed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_DESCRIPTION_PARSE_FAILED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalDescriptionParseWarning {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_DESCRIPTION_PARSE_WARNING_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalBuildTypeUnsupported {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_BUILD_TYPE_UNSUPPORTED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalCustomSetupUnsupported {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_CUSTOM_SETUP_UNSUPPORTED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalPackageFieldUnclosed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_PACKAGE_FIELD_UNCLOSED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalConditionalConfigurationUnclosed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_CONDITIONAL_CONFIGURATION_UNCLOSED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalForeignLibraryUnsupported {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_FOREIGN_LIBRARY_UNSUPPORTED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalSignatureModuleUnsupported {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_SIGNATURE_MODULE_UNSUPPORTED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalAutogenModuleUnsupported {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_AUTOGEN_MODULE_UNSUPPORTED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalDeclaredModuleMissing {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_DECLARED_MODULE_MISSING_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalDeclaredModuleAmbiguous {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_DECLARED_MODULE_AMBIGUOUS_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalMainModuleMissing {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_MAIN_MODULE_MISSING_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalMainModuleAmbiguous {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_MAIN_MODULE_AMBIGUOUS_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalDeclaredModuleExpectationConflict {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_DECLARED_MODULE_EXPECTATION_CONFLICT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalDeclaredPathUnsafe {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_DECLARED_PATH_UNSAFE_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalHaskellSubjectUnowned {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_HASKELL_SUBJECT_UNOWNED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalCompilerOptionUnclosed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_COMPILER_OPTION_UNCLOSED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalCompilerLanguageUnclosed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_COMPILER_LANGUAGE_UNCLOSED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalCompilerExtensionsUnclosed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_COMPILER_EXTENSIONS_UNCLOSED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalCompilerDependenciesUnclosed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_COMPILER_DEPENDENCIES_UNCLOSED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalBuildInfoFieldUnclosed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_BUILD_INFO_FIELD_UNCLOSED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalModuleReexportUnsupported {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_MODULE_REEXPORT_UNSUPPORTED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalComponentConfigurationsDiffer {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_COMPONENT_CONFIGURATIONS_DIFFER_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalMultipleComponentsUnclosed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_MULTIPLE_COMPONENTS_UNCLOSED_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif



problemSubjectFieldMappingMutationSelected :: ComponentPlanProblem -> Bool
problemSubjectFieldMappingMutationSelected problem = case problem of
  ComponentPlanSnapshotEntryLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_SNAPSHOT_ENTRY_LIMIT_EXCEEDED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanPathByteLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_PATH_BYTE_LIMIT_EXCEEDED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanModeByteLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_MODE_BYTE_LIMIT_EXCEEDED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanObjectIdentityByteLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_OBJECT_IDENTITY_BYTE_LIMIT_EXCEEDED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanSnapshotIdentityByteLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_SNAPSHOT_IDENTITY_BYTE_LIMIT_EXCEEDED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanBlobByteLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_BLOB_BYTE_LIMIT_EXCEEDED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanAggregateBlobByteLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_AGGREGATE_BLOB_BYTE_LIMIT_EXCEEDED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanPathEmpty {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_PATH_EMPTY_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanPathAbsolute {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_PATH_ABSOLUTE_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanPathNul {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_PATH_NUL_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanPathBackslash {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_PATH_BACKSLASH_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanPathEmptySegment {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_PATH_EMPTY_SEGMENT_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanPathDotSegment {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_PATH_DOT_SEGMENT_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanPathParentSegment {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_PATH_PARENT_SEGMENT_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanPathCharacterUnsafe {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_PATH_CHARACTER_UNSAFE_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanDuplicatePath {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_DUPLICATE_PATH_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanEntryOrderInvalid {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_ENTRY_ORDER_INVALID_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanModeMalformed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_MODE_MALFORMED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanObjectIdentityMalformed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_OBJECT_IDENTITY_MALFORMED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanObjectIdentityMismatch {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_OBJECT_IDENTITY_MISMATCH_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanSnapshotIdentityMalformed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_SNAPSHOT_IDENTITY_MALFORMED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanSnapshotIdentityMismatch {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_SNAPSHOT_IDENTITY_MISMATCH_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanCabalEntryLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_CABAL_ENTRY_LIMIT_EXCEEDED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanCabalByteLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_CABAL_BYTE_LIMIT_EXCEEDED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanComponentLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_COMPONENT_LIMIT_EXCEEDED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanConditionalLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_CONDITIONAL_LIMIT_EXCEEDED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanModuleLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_MODULE_LIMIT_EXCEEDED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanSourceDirectoryLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_SOURCE_DIRECTORY_LIMIT_EXCEEDED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanConfigurationLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_CONFIGURATION_LIMIT_EXCEEDED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanOptionLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_OPTION_LIMIT_EXCEEDED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanDependencyLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_DEPENDENCY_LIMIT_EXCEEDED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanAssignmentLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_ASSIGNMENT_LIMIT_EXCEEDED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanProblemLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_PROBLEM_LIMIT_EXCEEDED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalDescriptionAbsent {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_DESCRIPTION_ABSENT_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalProjectElaborationUnavailable {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_PROJECT_ELABORATION_UNAVAILABLE_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalDescriptionParseFailed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_DESCRIPTION_PARSE_FAILED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalDescriptionParseWarning {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_DESCRIPTION_PARSE_WARNING_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalBuildTypeUnsupported {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_BUILD_TYPE_UNSUPPORTED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalCustomSetupUnsupported {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_CUSTOM_SETUP_UNSUPPORTED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalPackageFieldUnclosed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_PACKAGE_FIELD_UNCLOSED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalConditionalConfigurationUnclosed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_CONDITIONAL_CONFIGURATION_UNCLOSED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalForeignLibraryUnsupported {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_FOREIGN_LIBRARY_UNSUPPORTED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalSignatureModuleUnsupported {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_SIGNATURE_MODULE_UNSUPPORTED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalAutogenModuleUnsupported {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_AUTOGEN_MODULE_UNSUPPORTED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalDeclaredModuleMissing {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_DECLARED_MODULE_MISSING_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalDeclaredModuleAmbiguous {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_DECLARED_MODULE_AMBIGUOUS_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalMainModuleMissing {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_MAIN_MODULE_MISSING_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalMainModuleAmbiguous {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_MAIN_MODULE_AMBIGUOUS_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalDeclaredModuleExpectationConflict {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_DECLARED_MODULE_EXPECTATION_CONFLICT_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalDeclaredPathUnsafe {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_DECLARED_PATH_UNSAFE_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalHaskellSubjectUnowned {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_HASKELL_SUBJECT_UNOWNED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalCompilerOptionUnclosed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_COMPILER_OPTION_UNCLOSED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalCompilerLanguageUnclosed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_COMPILER_LANGUAGE_UNCLOSED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalCompilerExtensionsUnclosed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_COMPILER_EXTENSIONS_UNCLOSED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalCompilerDependenciesUnclosed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_COMPILER_DEPENDENCIES_UNCLOSED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalBuildInfoFieldUnclosed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_BUILD_INFO_FIELD_UNCLOSED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalModuleReexportUnsupported {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_MODULE_REEXPORT_UNSUPPORTED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalComponentConfigurationsDiffer {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_COMPONENT_CONFIGURATIONS_DIFFER_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalMultipleComponentsUnclosed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_MULTIPLE_COMPONENTS_UNCLOSED_SUBJECT_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif



problemDetailFieldMappingMutationSelected :: ComponentPlanProblem -> Bool
problemDetailFieldMappingMutationSelected problem = case problem of
  ComponentPlanSnapshotEntryLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_SNAPSHOT_ENTRY_LIMIT_EXCEEDED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanPathByteLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_PATH_BYTE_LIMIT_EXCEEDED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanModeByteLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_MODE_BYTE_LIMIT_EXCEEDED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanObjectIdentityByteLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_OBJECT_IDENTITY_BYTE_LIMIT_EXCEEDED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanSnapshotIdentityByteLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_SNAPSHOT_IDENTITY_BYTE_LIMIT_EXCEEDED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanBlobByteLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_BLOB_BYTE_LIMIT_EXCEEDED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanAggregateBlobByteLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_AGGREGATE_BLOB_BYTE_LIMIT_EXCEEDED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanPathEmpty {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_PATH_EMPTY_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanPathAbsolute {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_PATH_ABSOLUTE_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanPathNul {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_PATH_NUL_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanPathBackslash {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_PATH_BACKSLASH_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanPathEmptySegment {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_PATH_EMPTY_SEGMENT_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanPathDotSegment {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_PATH_DOT_SEGMENT_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanPathParentSegment {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_PATH_PARENT_SEGMENT_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanPathCharacterUnsafe {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_PATH_CHARACTER_UNSAFE_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanDuplicatePath {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_DUPLICATE_PATH_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanEntryOrderInvalid {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_ENTRY_ORDER_INVALID_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanModeMalformed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_MODE_MALFORMED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanObjectIdentityMalformed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_OBJECT_IDENTITY_MALFORMED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanObjectIdentityMismatch {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_OBJECT_IDENTITY_MISMATCH_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanSnapshotIdentityMalformed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_SNAPSHOT_IDENTITY_MALFORMED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanSnapshotIdentityMismatch {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_SNAPSHOT_IDENTITY_MISMATCH_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanCabalEntryLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_CABAL_ENTRY_LIMIT_EXCEEDED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanCabalByteLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_CABAL_BYTE_LIMIT_EXCEEDED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanComponentLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_COMPONENT_LIMIT_EXCEEDED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanConditionalLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_CONDITIONAL_LIMIT_EXCEEDED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanModuleLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_MODULE_LIMIT_EXCEEDED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanSourceDirectoryLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_SOURCE_DIRECTORY_LIMIT_EXCEEDED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanConfigurationLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_CONFIGURATION_LIMIT_EXCEEDED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanOptionLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_OPTION_LIMIT_EXCEEDED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanDependencyLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_DEPENDENCY_LIMIT_EXCEEDED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanAssignmentLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_ASSIGNMENT_LIMIT_EXCEEDED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  ComponentPlanProblemLimitExceeded {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_COMPONENT_PLAN_PROBLEM_LIMIT_EXCEEDED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalDescriptionAbsent {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_DESCRIPTION_ABSENT_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalProjectElaborationUnavailable {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_PROJECT_ELABORATION_UNAVAILABLE_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalDescriptionParseFailed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_DESCRIPTION_PARSE_FAILED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalDescriptionParseWarning {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_DESCRIPTION_PARSE_WARNING_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalBuildTypeUnsupported {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_BUILD_TYPE_UNSUPPORTED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalCustomSetupUnsupported {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_CUSTOM_SETUP_UNSUPPORTED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalPackageFieldUnclosed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_PACKAGE_FIELD_UNCLOSED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalConditionalConfigurationUnclosed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_CONDITIONAL_CONFIGURATION_UNCLOSED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalForeignLibraryUnsupported {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_FOREIGN_LIBRARY_UNSUPPORTED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalSignatureModuleUnsupported {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_SIGNATURE_MODULE_UNSUPPORTED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalAutogenModuleUnsupported {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_AUTOGEN_MODULE_UNSUPPORTED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalDeclaredModuleMissing {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_DECLARED_MODULE_MISSING_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalDeclaredModuleAmbiguous {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_DECLARED_MODULE_AMBIGUOUS_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalMainModuleMissing {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_MAIN_MODULE_MISSING_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalMainModuleAmbiguous {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_MAIN_MODULE_AMBIGUOUS_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalDeclaredModuleExpectationConflict {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_DECLARED_MODULE_EXPECTATION_CONFLICT_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalDeclaredPathUnsafe {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_DECLARED_PATH_UNSAFE_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalHaskellSubjectUnowned {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_HASKELL_SUBJECT_UNOWNED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalCompilerOptionUnclosed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_COMPILER_OPTION_UNCLOSED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalCompilerLanguageUnclosed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_COMPILER_LANGUAGE_UNCLOSED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalCompilerExtensionsUnclosed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_COMPILER_EXTENSIONS_UNCLOSED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalCompilerDependenciesUnclosed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_COMPILER_DEPENDENCIES_UNCLOSED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalBuildInfoFieldUnclosed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_BUILD_INFO_FIELD_UNCLOSED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalModuleReexportUnsupported {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_MODULE_REEXPORT_UNSUPPORTED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalComponentConfigurationsDiffer {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_COMPONENT_CONFIGURATIONS_DIFFER_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif
  CabalMultipleComponentsUnclosed {} ->
#if defined(VALIDATION_COMPILER_PLAN_PROBLEM_CABAL_MULTIPLE_COMPONENTS_UNCLOSED_DETAIL_FIELD_MAPPING_MUTANT)
    True
#else
    False
#endif


limitFields :: Text -> FilePath -> Int -> Int -> (Text, FilePath, Text)
limitFields code subject limit observed = (code, subject, limitDetail limit observed)

shown :: Show value => value -> Text
shown = Text.pack . show

packageQualified :: FilePath -> Text -> Text
packageQualified "." component = component
packageQualified root component =
#if defined(VALIDATION_COMPILER_PLAN_PACKAGE_QUALIFIED_ROOT_JOIN_MUTANT)
  Text.pack root <> ":" <> component
#else
  Text.pack root <> "/" <> component
#endif

prefixPackageRoot :: FilePath -> FilePath -> FilePath
prefixPackageRoot "." path =
#if defined(VALIDATION_COMPILER_PLAN_PREFIX_PACKAGE_ROOT_DOT_ROOT_MAPPING_MUTANT)
  "mutated-root/" <> path
#else
  path
#endif
prefixPackageRoot root "." =
#if defined(VALIDATION_COMPILER_PLAN_PREFIX_PACKAGE_ROOT_DOT_CHILD_MAPPING_MUTANT)
  root <> "/mutated-child"
#else
  root
#endif
prefixPackageRoot root path =
#if defined(VALIDATION_COMPILER_PLAN_PREFIX_PACKAGE_ROOT_CHILD_JOIN_MUTANT)
  root <> ":" <> path
#else
  joinRepoPath root path
#endif

normalizeRoot :: FilePath -> FilePath
normalizeRoot value =
#if defined(VALIDATION_COMPILER_PLAN_NORMALIZE_ROOT_NONEMPTY_MAPPING_MUTANT)
  "mutated-root/" <> value
#else
  value
#endif

joinRepoPath :: FilePath -> FilePath -> FilePath
joinRepoPath "." child =
#if defined(VALIDATION_COMPILER_PLAN_JOIN_REPO_PATH_DOT_PARENT_MAPPING_MUTANT)
  "./" <> child
#else
  child
#endif
joinRepoPath parent child =
#if defined(VALIDATION_COMPILER_PLAN_JOIN_REPO_PATH_PARENT_CHILD_MAPPING_MUTANT)
  parent <> ":" <> child
#else
  parent <> "/" <> child
#endif

posixDirectory :: FilePath -> FilePath
posixDirectory path = case reverse (splitPosix path) of
  [] -> "."
  [_] ->
#if defined(VALIDATION_COMPILER_PLAN_POSIX_DIRECTORY_ROOT_MAPPING_MUTANT)
    "mutated-root"
#else
    "."
#endif
  _ : reversedParent ->
#if defined(VALIDATION_COMPILER_PLAN_POSIX_DIRECTORY_NESTED_MAPPING_MUTANT)
    joinSegments (reverse reversedParent) `seq` "mutated-nested-root"
#else
    joinSegments (reverse reversedParent)
#endif

posixExtension :: FilePath -> String
posixExtension path = case break (== '.') (reverse finalSegment) of
  (_, []) ->
#if defined(VALIDATION_COMPILER_PLAN_POSIX_EXTENSION_ABSENT_MAPPING_MUTANT)
    ".cabal"
#else
    ""
#endif
  (reversedExtension, _ : _) ->
#if defined(VALIDATION_COMPILER_PLAN_POSIX_EXTENSION_PRESENT_MAPPING_MUTANT)
    reversedExtension `seq` ".mutated"
#else
    '.' : reverse reversedExtension
#endif
 where
  finalSegment = case reverse (splitPosix path) of
    [] -> ""
    value : _ -> value

joinSegments :: [FilePath] -> FilePath
joinSegments [] = ""
joinSegments (first : rest) =
#if defined(VALIDATION_COMPILER_PLAN_JOIN_SEGMENTS_ORDER_MUTANT)
  foldl' (\parent child -> child <> "/" <> parent) first rest
#else
  foldl' (\parent child -> parent <> "/" <> child) first rest
#endif
