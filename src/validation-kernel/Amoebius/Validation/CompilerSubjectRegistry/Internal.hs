{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Package-hidden, repository-scale compiler-subject assignment.
--
-- The bounded 'CompilerComponentPlan' diagnostic deliberately refuses the
-- real package: its small ceilings and single-component model exist for exact
-- caller-fixture tests.  The acquired compiler path instead needs a two-way
-- join between every exact Haskell blob and every declaration in every Cabal
-- conditional branch.  This module performs only that declaration join.  It
-- does not claim that Cabal elaboration ran or that GHC produced an outcome.
module Amoebius.Validation.CompilerSubjectRegistry.Internal
  ( AcquiredCompilerSubjectContract
  , CompilerSubjectContractProblem
  , CompilerSubjectContractRow
  , CompilerSubjectRegistry
  , ExpectedCompilerOutcome (..)
  , SubjectRole (..)
  , acquireCompilerSubjectContract
  , compilerSubjectAssignments
  , compilerSubjectBindingAssignments
  , compilerSubjectContractDigest
  , compilerSubjectRegistryCheck
  , compilerSubjectRegistryProblems
  , deriveCompilerSubjectRegistry
  , foldAcquiredCompilerSubjectContract
  , foldCompilerSubjectContractProblem
  , foldCompilerSubjectContractRow
  ) where

import Amoebius.Validation.SourceClosure.Internal
  ( AcquiredSourceSnapshot
  , IndexEntry (..)
  , SourceSnapshot (..)
  , TrackedEntry (..)
  , acquiredSourceSnapshot
  )
import Amoebius.Validation.CompilerExpectationAuthority.Internal
  ( CompilerExpectationOutcome
  , compilerExpectationAuthority
  , compilerExpectationAuthorityProblems
  , foldCompilerExpectationAuthority
  , foldCompilerExpectationOutcome
  , lookupCompilerExpectation
  )
import Amoebius.Validation.Types
  ( CheckResult (..)
  , finding
  , observation
  )
import Crypto.Hash qualified as Crypto
import Data.ByteString (ByteString)
import Data.ByteString.Char8 qualified as ByteString8
import Data.List (sort)
import Data.List.NonEmpty (NonEmpty)
import Data.List.NonEmpty qualified as NonEmpty
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Distribution.ModuleName qualified as CabalModule
import Distribution.PackageDescription
  ( Benchmark (..)
  , BenchmarkInterface (..)
  , BuildInfo (..)
  , Executable (..)
  , GenericPackageDescription (..)
  , Library (..)
  , TestSuite (..)
  , TestSuiteInterface (..)
  , benchmarkBuildInfo
  , buildInfo
  , libBuildInfo
  , testBuildInfo
  )
import Distribution.Fields.ParseResult (runParseResult)
import Distribution.PackageDescription.Parsec (parseGenericPackageDescription)
import Distribution.Types.CondTree (CondBranch (..), CondTree (..))
import Distribution.Types.Dependency (Dependency)
import Distribution.Types.UnqualComponentName (UnqualComponentName, unUnqualComponentName)
import Distribution.Utils.Path (getSymbolicPath)
import Distribution.Utils.Path qualified as CabalPath
import System.FilePath.Posix
  ( (</>)
  , normalise
  , takeDirectory
  , takeExtension
  )

data SubjectRole
  = ProductSubject
  | ValidationSubject
  | TestSubject
  | MutantSubject
  | CompileNegativeSubject
  | FixtureSubject
  | ProbeSubject
  | VendorSubject
  deriving (Eq, Ord, Enum, Bounded, Show)

data ExpectedCompilerOutcome
  = ExpectedCompileSuccess
  | ExpectedCompileRefusal
  | ExpectedFixtureObservation
  | ExpectedCompilerOutcomeUnavailable
  deriving (Eq, Ord, Enum, Bounded, Show)

data SubjectAssignment = SubjectAssignment
  { assignmentPath :: FilePath
  , assignmentObjectIdentity :: Text
  , assignmentRole :: SubjectRole
  , assignmentExpectedOutcome :: ExpectedCompilerOutcome
  , assignmentBindings :: [ComponentBinding]
  }
  deriving (Eq, Ord, Show)

-- | One concrete buildable Cabal configuration which consumes a source.
-- Component identity alone is insufficient: conditional branches can change
-- options, generated inputs, or even whether the component exists.  The
-- branch identity is retained here so later elaboration must join every exact
-- configuration rather than collapsing them into one path/component pair.
data ComponentBinding = ComponentBinding Text Text
  deriving (Eq, Ord, Show)

data RegistryProblem
  = RegistryResourceLimit Text Int Int
  | RegistryCabalParseFailure FilePath
  | RegistryCabalParseWarning FilePath Int
  | RegistryDeclarationMissing Text Text [FilePath]
  | RegistryDeclarationAmbiguous Text Text [FilePath]
  | RegistrySubjectUnassigned FilePath
  | RegistrySubjectInventoryEmpty
  | RegistrySubjectRoleUnclassified FilePath
  | RegistryFixtureDeclaredAsComponent FilePath [Text]
  | RegistryExpectedRefusalUnassigned FilePath
  | RegistryExpectationAuthorityInvalid Text
  | RegistryExpectedOutcomeMissing FilePath Text
  | RegistryExpectedOutcomeConflict FilePath [(Text, ExpectedCompilerOutcome)]
  | RegistryExpectationBranchMismatch FilePath Text Text Text
  | RegistryExpectationBindingMissing FilePath Text
  deriving (Eq, Ord, Show)

data CompilerSubjectRegistry = CompilerSubjectRegistry
  { registrySnapshotIdentity :: Text
  , registryAssignments :: [SubjectAssignment]
  , registryProblems :: [RegistryProblem]
  }
  deriving (Eq, Show)

-- | An exact source/object/component/branch row in the acquired compiler
-- subject contract.  The constructor is package-hidden; consumers can only
-- inspect rows through the total fold below.
data CompilerSubjectContractRow
  = CompilerSubjectContractRow
      FilePath
      Text
      SubjectRole
      ExpectedCompilerOutcome
      Text
      Text
  deriving (Eq, Ord, Show)

-- | The only subject inventory admitted to compiler planning.  It can be
-- minted only from an acquired source snapshot after the complete registry
-- join succeeds.
data AcquiredCompilerSubjectContract
  = AcquiredCompilerSubjectContract Text Text [CompilerSubjectContractRow]
  deriving (Eq, Show)

-- | A structured refusal retains the exact registry code, locus, and detail;
-- callers do not receive a lossy Boolean "registry ready" projection.
data CompilerSubjectContractProblem
  = CompilerSubjectContractProblem Text FilePath Text
  deriving (Eq, Ord, Show)

data ComponentDeclaration = ComponentDeclaration
  { declarationName :: Text
  , declarationBranchIdentity :: Text
  , declarationBuildable :: Bool
  , declarationSourceDirectories :: [FilePath]
  , declarationModules :: [Text]
  , declarationMainPaths :: [FilePath]
  , declarationAutogenModules :: Set Text
  }
  deriving (Eq, Ord, Show)

maximumCabalFiles, maximumComponentConfigurations, maximumSubjects,
  maximumProblems :: Int
maximumCabalFiles = 16
maximumComponentConfigurations = 4096
maximumSubjects = 4096
maximumProblems = 4096

deriveCompilerSubjectRegistry :: SourceSnapshot -> CompilerSubjectRegistry
deriveCompilerSubjectRegistry snapshot =
  CompilerSubjectRegistry
    { registrySnapshotIdentity = snapshotIdentity snapshot
    , registryAssignments = assignments
    , registryProblems = boundedProblems
    }
 where
  entriesByPath =
    Map.fromList
      [ (indexPath (trackedIndex entry), entry)
      | entry <- snapshotEntries snapshot
      ]
  haskellEntries =
    [ entry
    | entry <- snapshotEntries snapshot
    , takeExtension (indexPath (trackedIndex entry)) == ".hs"
    ]
  cabalEntries =
    [ entry
    | entry <- snapshotEntries snapshot
    , takeExtension (indexPath (trackedIndex entry)) == ".cabal"
    ]
  (rawDeclarations, parseProblems) = parseCabalEntries cabalEntries
  parsedDeclarations = Set.toAscList (Set.fromList rawDeclarations)
  (componentPaths, declarationProblems) =
    assignDeclarations entriesByPath parsedDeclarations
  assignments =
    sort
      [ makeSubjectAssignment entry (Map.findWithDefault Set.empty path componentPaths)
      | entry <- haskellEntries
      , let path = indexPath (trackedIndex entry)
      ]
  subjectProblems =
    [RegistrySubjectInventoryEmpty | null haskellEntries]
      <> concatMap assignmentProblems assignments
  resourceProblems =
    countProblem "cabal-files" maximumCabalFiles cabalEntries
      <> countProblem "component-configurations" maximumComponentConfigurations parsedDeclarations
      <> countProblem "haskell-subjects" maximumSubjects haskellEntries
  allProblems =
    resourceProblems
      <> map (RegistryExpectationAuthorityInvalid . Text.pack . show)
        (compilerExpectationAuthorityProblems compilerExpectationAuthority)
      <> parseProblems
      <> declarationProblems
      <> subjectProblems
  boundedProblems = case take (maximumProblems + 1) allProblems of
    values | length values <= maximumProblems -> values
    values -> [RegistryResourceLimit "registry-problems" maximumProblems (length values)]

acquireCompilerSubjectContract
  :: AcquiredSourceSnapshot
  -> Either (NonEmpty CompilerSubjectContractProblem) AcquiredCompilerSubjectContract
acquireCompilerSubjectContract acquired =
  case NonEmpty.nonEmpty problems of
    Just refused -> Left refused
    Nothing ->
      Right
        ( AcquiredCompilerSubjectContract
            (registrySnapshotIdentity registry)
            digest
            rows
        )
 where
  registry = deriveCompilerSubjectRegistry (acquiredSourceSnapshot acquired)
  problems =
    map contractProblemFromRegistry
      (registryProblems registry <> missingExpectationBindingProblems registry)
  digest = registryDigest (registryAssignments registry)
  rows =
    sort
      [ CompilerSubjectContractRow path objectIdentity role outcome component branchIdentity
      | (path, objectIdentity, role, outcome, component, branchIdentity) <-
          compilerSubjectBindingAssignments registry
      ]

compilerSubjectContractDigest :: AcquiredCompilerSubjectContract -> Text
compilerSubjectContractDigest (AcquiredCompilerSubjectContract _ digest _) = digest

foldAcquiredCompilerSubjectContract
  :: (Text -> Text -> [CompilerSubjectContractRow] -> result)
  -> AcquiredCompilerSubjectContract
  -> result
foldAcquiredCompilerSubjectContract project (AcquiredCompilerSubjectContract snapshot digest rows) =
  project snapshot digest rows

foldCompilerSubjectContractRow
  :: (FilePath -> Text -> SubjectRole -> ExpectedCompilerOutcome -> Text -> Text -> result)
  -> CompilerSubjectContractRow
  -> result
foldCompilerSubjectContractRow project (CompilerSubjectContractRow path objectIdentity role outcome component branchIdentity) =
  project path objectIdentity role outcome component branchIdentity

foldCompilerSubjectContractProblem
  :: (Text -> FilePath -> Text -> result)
  -> CompilerSubjectContractProblem
  -> result
foldCompilerSubjectContractProblem project (CompilerSubjectContractProblem code subject detail) =
  project code subject detail

contractProblemFromRegistry :: RegistryProblem -> CompilerSubjectContractProblem
contractProblemFromRegistry problem =
  CompilerSubjectContractProblem
    (registryProblemCode problem)
    (problemSubject problem)
    (renderRegistryProblem problem)

compilerSubjectAssignments :: CompilerSubjectRegistry -> [(FilePath, Text, SubjectRole, ExpectedCompilerOutcome, [Text])]
compilerSubjectAssignments registry =
  [ ( assignmentPath item
    , assignmentObjectIdentity item
    , assignmentRole item
    , assignmentExpectedOutcome item
    , assignmentComponentNames item
    )
  | item <- registryAssignments registry
  ]

-- | Branch-sensitive projection used by the acquired compiler contract.  A
-- later run-plan producer must account for every row in this projection.
compilerSubjectBindingAssignments
  :: CompilerSubjectRegistry
  -> [(FilePath, Text, SubjectRole, ExpectedCompilerOutcome, Text, Text)]
compilerSubjectBindingAssignments registry =
  [ ( assignmentPath item
    , assignmentObjectIdentity item
    , assignmentRole item
    , assignmentExpectedOutcome item
    , component
    , branchIdentity
    )
  | item <- registryAssignments registry
  , ComponentBinding component branchIdentity <- assignmentBindings item
  ]

compilerSubjectRegistryProblems :: CompilerSubjectRegistry -> [Text]
compilerSubjectRegistryProblems = map renderRegistryProblem . registryProblems

compilerSubjectRegistryCheck :: CompilerSubjectRegistry -> CheckResult
compilerSubjectRegistryCheck registry =
  CheckResult
    { checkName = "compiler-subject-registry"
    , checkObservations =
        [ observation "compiler-subject-registry.snapshot" (registrySnapshotIdentity registry)
        , observation "compiler-subject-registry.subject-count" (decimalText (length assignments))
        , observation "compiler-subject-registry.component-binding-count" (decimalText componentBindings)
        , observation "compiler-subject-registry.compile-success-count" (outcomeCount ExpectedCompileSuccess)
        , observation "compiler-subject-registry.compile-refusal-count" (outcomeCount ExpectedCompileRefusal)
        , observation "compiler-subject-registry.fixture-count" (outcomeCount ExpectedFixtureObservation)
        , observation "compiler-subject-registry.unavailable-outcome-count" (outcomeCount ExpectedCompilerOutcomeUnavailable)
        , observation "compiler-subject-registry.sha256" (registryDigest assignments)
        ]
    , checkFindings =
        [ finding "SRC-COMPILER-SUBJECT-REGISTRY" (problemSubject problem) (renderRegistryProblem problem)
        | problem <- registryProblems registry
        ]
    }
 where
  assignments = registryAssignments registry
  componentBindings = sum (map (length . assignmentBindings) assignments)
  outcomeCount outcome = decimalText (length (filter ((== outcome) . assignmentExpectedOutcome) assignments))

parseCabalEntries :: [TrackedEntry] -> ([ComponentDeclaration], [RegistryProblem])
parseCabalEntries entries = foldr parseOne ([], []) entries
 where
  parseOne entry (declarations, problems) =
    case runParseResult (parseGenericPackageDescription (trackedBytes entry)) of
      (_, Left _) -> (declarations, RegistryCabalParseFailure path : problems)
      (warnings, Right description) ->
        let (declared, declarationLimits) = declarationsFor path description
         in ( declared <> declarations
            , declarationLimits
                <> [RegistryCabalParseWarning path (length warnings) | not (null warnings)]
                <> problems
            )
   where
    path = indexPath (trackedIndex entry)

declarationsFor
  :: FilePath
  -> GenericPackageDescription
  -> ([ComponentDeclaration], [RegistryProblem])
declarationsFor cabalPath description =
  (concat declaredPerComponent, concat problemsPerComponent)
 where
  (declaredPerComponent, problemsPerComponent) = unzip components
  components =
    concat
      [ maybe [] (pure . declarationsFromTree (libraryDeclaration "lib")) (condLibrary description)
      , [ declarationsFromTree (libraryDeclaration ("lib:" <> componentText name)) tree
        | (name, tree) <- condSubLibraries description
        ]
      , [ declarationsFromTree (executableDeclaration ("exe:" <> componentText name)) tree
        | (name, tree) <- condExecutables description
        ]
      , [ declarationsFromTree (testDeclaration ("test:" <> componentText name)) tree
        | (name, tree) <- condTestSuites description
        ]
      , [ declarationsFromTree (benchmarkDeclaration ("bench:" <> componentText name)) tree
        | (name, tree) <- condBenchmarks description
        ]
      ]

  root = packageRoot cabalPath
  qualify name = Text.pack cabalPath <> ":" <> name
  libraryDeclaration name branchIdentity library =
    componentDeclaration root (qualify name) branchIdentity (libBuildInfo library)
      (map moduleText (exposedModules library)) []
  executableDeclaration name branchIdentity executable =
    componentDeclaration root (qualify name) branchIdentity (buildInfo executable) []
      [getSymbolicPath (modulePath executable)]
  testDeclaration name branchIdentity testSuite =
    componentDeclaration root (qualify name) branchIdentity (testBuildInfo testSuite)
      (case testInterface testSuite of
        TestSuiteLibV09 _ moduleName -> [moduleText moduleName]
        _ -> [])
      (case testInterface testSuite of
        TestSuiteExeV10 _ path -> [getSymbolicPath path]
        _ -> [])
  benchmarkDeclaration name branchIdentity benchmark =
    componentDeclaration root (qualify name) branchIdentity (benchmarkBuildInfo benchmark) []
      (case benchmarkInterface benchmark of
        BenchmarkExeV10 _ path -> [getSymbolicPath path]
        _ -> [])

declarationsFromTree
  :: (Monoid component, Show variable)
  => (Text -> component -> ComponentDeclaration)
  -> CondTree variable [Dependency] component
  -> ([ComponentDeclaration], [RegistryProblem])
declarationsFromTree project tree
  | configurations > maximumComponentConfigurations =
      ( []
      , [RegistryResourceLimit
           "component-configurations"
           maximumComponentConfigurations
           configurations
        ]
      )
  | otherwise =
      ( [ project (renderBranchIdentity decisions) component
        | (decisions, component) <- conditionalLeaves projectionOf mempty [] tree
        ]
      , []
      )
 where
  projectionOf component = declarationProjection (project "" component)
  configurations = configurationCount projectionOf mempty tree

-- | Saturating count of the configurations a component tree describes, over
-- exactly the branches 'conditionalLeaves' folds.
--
-- Addition and multiplication saturate one past the admitted maximum, so the
-- count is decided before any leaf, decision path, rendered branch identity, or
-- 'Set' is constructed.  A ceiling applied after construction is a diagnostic
-- about allocation that already happened, not an admission bound.
configurationCount
  :: (Monoid component, Eq projection)
  => (component -> projection)
  -> component
  -> CondTree variable constraints component
  -> Int
configurationCount projectionOf inherited (CondNode datum _ branches) =
  foldl' multiplySaturating 1 (map branchFactor projectedBranches)
 where
  base = inherited <> datum
  baseProjection = projectionOf base
  projectedBranches =
    filter (branchChangesProjection projectionOf base baseProjection) branches
  branchFactor (CondBranch _ trueBranch falseBranch) =
    addSaturating
      (configurationCount projectionOf base trueBranch)
      (maybe 1 (configurationCount projectionOf base) falseBranch)

-- | One past the admitted configuration maximum; every saturating operation
-- stops here, so an observed count never exceeds it and never overflows.
configurationCeiling :: Int
configurationCeiling = maximumComponentConfigurations + 1

addSaturating :: Int -> Int -> Int
addSaturating left right = min configurationCeiling (left + right)

multiplySaturating :: Int -> Int -> Int
multiplySaturating left right
  | left >= configurationCeiling = configurationCeiling
  | right >= configurationCeiling = configurationCeiling
  | left == 0 || right == 0 = 0
  | right > configurationCeiling `div` left = configurationCeiling
  | otherwise = min configurationCeiling (left * right)

-- | The fields a 'ComponentDeclaration' actually records, excluding the
-- rendered branch identity.
--
-- Two leaves with the same projection describe the same subject assignment, so
-- a branch that cannot change this value is invisible to the registry.
declarationProjection
  :: ComponentDeclaration
  -> (Bool, [FilePath], [Text], [FilePath], Set Text)
declarationProjection declaration =
  ( declarationBuildable declaration
  , declarationSourceDirectories declaration
  , declarationModules declaration
  , declarationMainPaths declaration
  , declarationAutogenModules declaration
  )

-- Cabal condition trees describe configurations, not an inventory of every
-- intermediate node.  Enumerate complete leaves and retain each predicate
-- decision.  For an @if@ without @else@, the false branch inherits the
-- current component unchanged.
--
-- Only a branch that can change the projected declaration is folded.  A branch
-- whose every reachable component projects exactly like the surrounding one
-- records no subject, no module, and no buildability difference, so folding it
-- would multiply the configuration count without changing any declaration the
-- registry can observe.  That is what produced the sibling product: a stanza
-- carrying thousands of @cpp-options@-only conditionals described 2^n complete
-- leaves that were byte-identical apart from a rendered branch identity no
-- consumer can accept, because 'expectationBranchIdentity' admits only an
-- unconditional identity or a single decision.
conditionalLeaves
  :: (Monoid component, Show variable, Eq projection)
  => (component -> projection)
  -> component
  -> [(Text, Bool)]
  -> CondTree variable constraints component
  -> [([(Text, Bool)], component)]
conditionalLeaves projectionOf inherited inheritedDecisions (CondNode datum _ branches) =
  foldl expandBranch [(inheritedDecisions, base)] projectedBranches
 where
  base = inherited <> datum
  baseProjection = projectionOf base
  projectedBranches =
    filter (branchChangesProjection projectionOf base baseProjection) branches
  expandBranch configurations (CondBranch condition trueBranch falseBranch) =
    concatMap (expandConfiguration condition trueBranch falseBranch) configurations
  expandConfiguration condition trueBranch falseBranch (decisions, component) =
    conditionalLeaves
      projectionOf
      component
      (decisions <> [(conditionText, True)])
      trueBranch
      <> case falseBranch of
        Nothing -> [(decisions <> [(conditionText, False)], component)]
        Just branch ->
          conditionalLeaves
            projectionOf
            component
            (decisions <> [(conditionText, False)])
            branch
   where
    conditionText = Text.pack (show condition)

-- | Whether any component reachable through a branch projects differently from
-- the component surrounding it.
--
-- The walk is additive over the subtree rather than a product across siblings,
-- so deciding visibility is linear in condition nodes and can never reproduce
-- the expansion it exists to prevent.
branchChangesProjection
  :: (Monoid component, Eq projection)
  => (component -> projection)
  -> component
  -> projection
  -> CondBranch variable constraints component
  -> Bool
branchChangesProjection projectionOf base baseProjection (CondBranch _ trueBranch falseBranch) =
  differs trueBranch || maybe False differs falseBranch
 where
  differs subtree =
    any ((/= baseProjection) . projectionOf) (subtreeComponents base subtree)

-- | Every component a subtree can contribute, accumulated additively.
subtreeComponents
  :: Monoid component
  => component
  -> CondTree variable constraints component
  -> [component]
subtreeComponents inherited (CondNode datum _ branches) =
  base : concatMap fromBranch branches
 where
  base = inherited <> datum
  fromBranch (CondBranch _ trueBranch falseBranch) =
    subtreeComponents base trueBranch
      <> maybe [] (subtreeComponents base) falseBranch

renderBranchIdentity :: [(Text, Bool)] -> Text
renderBranchIdentity [] = "unconditional"
renderBranchIdentity decisions =
  Text.intercalate
    "/"
    [ (if selected then "true:" else "false:") <> condition
    | (condition, selected) <- decisions
    ]

componentDeclaration
  :: FilePath
  -> Text
  -> Text
  -> BuildInfo
  -> [Text]
  -> [FilePath]
  -> ComponentDeclaration
componentDeclaration root name branchIdentity info interfaceModules mains =
  ComponentDeclaration
    { declarationName = name
    , declarationBranchIdentity = branchIdentity
    , declarationBuildable = buildable info
    , declarationSourceDirectories =
        map (joinRoot root . getSymbolicPath) (nonemptySourceDirectories info)
    , declarationModules =
        sort
          ( interfaceModules
              <> map moduleText (otherModules info)
          )
    , declarationMainPaths = sort mains
    , declarationAutogenModules = Set.fromList (map moduleText (autogenModules info))
    }

nonemptySourceDirectories
  :: BuildInfo
  -> [CabalPath.SymbolicPath CabalPath.Pkg ('CabalPath.Dir CabalPath.Source)]
nonemptySourceDirectories info = case hsSourceDirs info of
  [] -> [CabalPath.makeSymbolicPath "."]
  values -> values

assignDeclarations
  :: Map FilePath TrackedEntry
  -> [ComponentDeclaration]
  -> (Map FilePath (Set ComponentBinding), [RegistryProblem])
assignDeclarations entries declarations =
  foldl assignOne (Map.empty, []) declarations
 where
  assignOne state declaration
    | not (declarationBuildable declaration) = state
  assignOne (assigned, problems) declaration =
    foldl (assignModule declaration) (assigned, problems) (declarationModules declaration)
      `assignMains` declaration
  assignModule declaration (assigned, problems) moduleName
    | Set.member moduleName (declarationAutogenModules declaration) = (assigned, problems)
    | otherwise =
        assignCandidate
          (ComponentBinding (declarationName declaration) (declarationBranchIdentity declaration))
          moduleName
          [ normalisePosix (sourceDirectory </> Text.unpack moduleName <> ".hs")
          | sourceDirectory <- declarationSourceDirectories declaration
          ]
          assigned
          problems
  assignMains (assigned, problems) declaration =
    foldl
      (\state mainPath ->
        assignCandidate
          (ComponentBinding (declarationName declaration) (declarationBranchIdentity declaration))
          (Text.pack mainPath)
          [normalisePosix (sourceDirectory </> mainPath) | sourceDirectory <- declarationSourceDirectories declaration]
          (fst state)
          (snd state))
      (assigned, problems)
      (declarationMainPaths declaration)
  assignCandidate binding@(ComponentBinding component _) declared candidates assigned problems =
    case take 1 (filter (`Map.member` entries) (orderedNub candidates)) of
      [] -> (assigned, RegistryDeclarationMissing component declared candidates : problems)
      [path] -> (Map.insertWith Set.union path (Set.singleton binding) assigned, problems)
      _ -> error "take 1 returned more than one source candidate"

  -- Cabal searches @hs-source-dirs@ in declaration order.  A later source with
  -- the same module name is shadowed, not an ambiguity in the configured
  -- component.  Preserve that order while suppressing repeated directories.
  orderedNub = go Set.empty
   where
    go _ [] = []
    go seen (value : values)
      | Set.member value seen = go seen values
      | otherwise = value : go (Set.insert value seen) values

makeSubjectAssignment :: TrackedEntry -> Set ComponentBinding -> SubjectAssignment
makeSubjectAssignment entry cabalBindings =
  SubjectAssignment
    { assignmentPath = path
    , assignmentObjectIdentity = indexObjectId (trackedIndex entry)
    , assignmentRole = roleForPath path
    , assignmentExpectedOutcome = expectedOutcome
    , assignmentBindings = Set.toAscList bindings
    }
 where
  path = indexPath (trackedIndex entry)
  harnessAssignment = Map.lookup path harnessSubjectAssignments
  bindings = case harnessAssignment of
    Nothing -> cabalBindings
    Just (harness, _) -> Set.insert (ComponentBinding harness "harness") cabalBindings
  expectedOutcome = case harnessAssignment of
    Just (_, outcome) -> outcome
    Nothing -> outcomeForComponentBindings path (Set.toAscList cabalBindings)

assignmentProblems :: SubjectAssignment -> [RegistryProblem]
assignmentProblems assignment =
  roleProblems
    <> componentProblems
    <> expectationProblems
    <> branchProblems
    <> refusalProblems
 where
  path = assignmentPath assignment
  components = assignmentComponentNames assignment
  roleProblems =
    [RegistrySubjectRoleUnclassified path | not (rolePathRecognized path)]
  componentProblems =
    [ RegistrySubjectUnassigned path
    | null components
    ]
  expectationProblems
    | not (pathPrefix "test/compile-negative/" path) = []
    | otherwise =
        let outcomes =
              [ (component, authorityOutcome <$> lookupCompilerExpectation compilerExpectationAuthority path component)
              | ComponentBinding component _ <- assignmentBindings assignment
              ]
            observed = [(component, outcome) | (component, Just outcome) <- outcomes]
         in [ RegistryExpectedOutcomeMissing path component
            | (component, Nothing) <- outcomes
            ]
              <> [ RegistryExpectedOutcomeConflict path observed
                 | not (null observed)
                 , hasConflictingOutcomes (map snd observed)
                 ]
  branchProblems
    | not (pathPrefix "test/compile-negative/" path) = []
    | otherwise =
        [ RegistryExpectationBranchMismatch path component expectedBranch branchIdentity
        | ComponentBinding component branchIdentity <- assignmentBindings assignment
        , Just authority <- [lookupCompilerExpectation compilerExpectationAuthority path component]
        , let expectedBranch = expectationBranchIdentity component authority
        , branchIdentity /= expectedBranch
        ]
  refusalProblems =
    [ RegistryExpectedRefusalUnassigned path
      | assignmentExpectedOutcome assignment == ExpectedCompileRefusal
    , null components
    ]

assignmentComponentNames :: SubjectAssignment -> [Text]
assignmentComponentNames assignment =
  Set.toAscList
    ( Set.fromList
        [ component
        | ComponentBinding component _ <- assignmentBindings assignment
        ]
    )

-- The ordinary diagnostic can operate on intentionally small synthetic
-- snapshots.  The acquired contract is stronger: every row in the closed
-- compile-negative authority must be present in the exact repository
-- snapshot and bound to its exact Cabal component.
missingExpectationBindingProblems :: CompilerSubjectRegistry -> [RegistryProblem]
missingExpectationBindingProblems registry =
  [ RegistryExpectationBindingMissing path component
  | (path, component) <-
      Set.toAscList (authorityBindingKeys `Set.difference` observedBindingKeys)
  ]
 where
  observedBindingKeys =
    Set.fromList
      [ (assignmentPath assignment, component)
      | assignment <- registryAssignments registry
      , pathPrefix "test/compile-negative/" (assignmentPath assignment)
      , ComponentBinding component _ <- assignmentBindings assignment
      ]

authorityBindingKeys :: Set (FilePath, Text)
authorityBindingKeys =
  foldCompilerExpectationAuthority
    (\keys path component _ -> Set.insert (path, component) keys)
    Set.empty
    compilerExpectationAuthority

roleForPath :: FilePath -> SubjectRole
roleForPath path
  | pathPrefix "src/validation-kernel/" path = ValidationSubject
  | pathPrefix "test/validation-kernel/" path = ValidationSubject
  | pathPrefix "test/compile-negative/" path = CompileNegativeSubject
  | pathPrefix "test/negative/compile_fail/" path = CompileNegativeSubject
  | pathPrefix "test/mutant/" path = MutantSubject
  | pathPrefix "test/fixture/" path = FixtureSubject
  | pathPrefix "test/" path = TestSubject
  | pathPrefix "probe/" path = ProbeSubject
  | pathPrefix "vendor/" path = VendorSubject
  | pathPrefix "src/" path || pathPrefix "app/" path = ProductSubject
  | otherwise = FixtureSubject

rolePathRecognized :: FilePath -> Bool
rolePathRecognized path =
  any (`pathPrefix` path) ["src/", "app/", "test/", "probe/", "vendor/"]

outcomeForComponentBindings :: FilePath -> [ComponentBinding] -> ExpectedCompilerOutcome
outcomeForComponentBindings path bindings
  | not (pathPrefix "test/compile-negative/" path) = ExpectedCompileSuccess
  | otherwise =
      case
        [ authorityOutcome outcome
        | ComponentBinding component _ <- bindings
        , Just outcome <- [lookupCompilerExpectation compilerExpectationAuthority path component]
        ] of
        [] -> ExpectedCompilerOutcomeUnavailable
        outcome : outcomes
          | all (== outcome) outcomes
          , length outcomes + 1 == length bindings -> outcome
        _ -> ExpectedCompilerOutcomeUnavailable

authorityOutcome :: CompilerExpectationOutcome -> ExpectedCompilerOutcome
authorityOutcome =
  foldCompilerExpectationOutcome
    ExpectedCompileSuccess
    ExpectedCompileRefusal
    ExpectedFixtureObservation

hasConflictingOutcomes :: [ExpectedCompilerOutcome] -> Bool
hasConflictingOutcomes [] = False
hasConflictingOutcomes (outcome : outcomes) = any (/= outcome) outcomes

expectationBranchIdentity :: Text -> CompilerExpectationOutcome -> Text
expectationBranchIdentity component =
  foldCompilerExpectationOutcome
    "unconditional"
    ( "false:CNot (Var (PackageFlag (FlagName \""
        <> componentFlagName component
        <> "\")))"
    )
    "unconditional"

componentFlagName :: Text -> Text
componentFlagName component =
  case Text.stripPrefix "amoebius.cabal:test:" component of
    Just flagName -> flagName
    Nothing -> component

-- These exact files are compiler inputs owned by Haskell harnesses rather
-- than Cabal component modules.  The registry is intentionally literal: a
-- newly tracked subject cannot acquire a verdict from its directory or file
-- name.  Later phases replace the transitional harness owners with their
-- compiled execution plans; Phase 0 merely keeps every exact source assigned
-- without fabricating an execution result.
harnessSubjectAssignments :: Map FilePath (Text, ExpectedCompilerOutcome)
harnessSubjectAssignments = Map.fromList
  ( harness "tool-and-mutant-generation" ExpectedFixtureObservation
      [ "test/mutant/determinism_jitcache/cache/prune_noop.hs"
      , "test/mutant/determinism_jitcache/cache/resolve_fixed_marker.hs"
      , "test/mutant/determinism_jitcache/cache/store_one_byte_short.hs"
      , "test/mutant/determinism_jitcache/const_fingerprint.hs"
      , "test/mutant/determinism_jitcache/const_output.hs"
      , "test/mutant/determinism_jitcache/content_order_leak.hs"
      , "test/mutant/determinism_jitcache/rng_workerid.hs"
      ]
      <> harness "compile-fail-harness" ExpectedCompileSuccess
        [ "test/negative/compile_fail/ChildInForceSpec/Positive.hs"
        , "test/negative/compile_fail/artifact_calculus/handle_stays_in_region.hs"
        , "test/negative/compile_fail/budget_calculus/grant_comes_from_the_issuer.hs"
        , "test/negative/compile_fail/budget_calculus/retention_names_its_reaper.hs"
        , "test/negative/compile_fail/calculus_composition/same_scope_composes.hs"
        , "test/negative/compile_fail/determinism_jitcache/content_address_positive.hs"
        , "test/negative/compile_fail/evidence_calculus/claim_names_its_fixture.hs"
        , "test/negative/compile_fail/evidence_calculus/gate_declares_its_register.hs"
        , "test/negative/compile_fail/infernix_lift/catalog_positive.hs"
        , "test/negative/compile_fail/lift_calculus/paths_meet_at_a_layer.hs"
        , "test/negative/compile_fail/lift_calculus/witness_comes_from_an_observation.hs"
        , "test/negative/compile_fail/workflow_calculus/teardown_discharges_what_was_provisioned.hs"
        , "test/negative/compile_fail/workflow_calculus/transfer_names_its_condition.hs"
        , "test/negative/compile_fail/workflow_calculus/workflow_discharges_its_obligation.hs"
        ]
      <> harness "compile-fail-harness" ExpectedCompileRefusal
        [ "test/negative/compile_fail/ChildInForceSpec/NegativeAncestor.hs"
        , "test/negative/compile_fail/ChildInForceSpec/NegativeSibling.hs"
        , "test/negative/compile_fail/artifact_calculus/handle_escapes_region.hs"
        , "test/negative/compile_fail/budget_calculus/grant_forged_unbounded.hs"
        , "test/negative/compile_fail/budget_calculus/retention_omits_its_reaper.hs"
        , "test/negative/compile_fail/calculus_composition/different_scopes_do_not_compose.hs"
        , "test/negative/compile_fail/determinism_jitcache/forge_blobsha.hs"
        , "test/negative/compile_fail/evidence_calculus/claim_without_a_fixture.hs"
        , "test/negative/compile_fail/evidence_calculus/gate_without_a_register.hs"
        , "test/negative/compile_fail/infernix_lift/forge_ready_handle.hs"
        , "test/negative/compile_fail/infernix_lift/url_engine_arm.hs"
        , "test/negative/compile_fail/lift_calculus/paths_do_not_meet.hs"
        , "test/negative/compile_fail/lift_calculus/witness_asserted.hs"
        , "test/negative/compile_fail/workflow_calculus/teardown_of_an_unheld_obligation.hs"
        , "test/negative/compile_fail/workflow_calculus/transfer_without_a_condition.hs"
        , "test/negative/compile_fail/workflow_calculus/workflow_ends_owing_a_teardown.hs"
        ]
      <> harness "determinism-jitcache" ExpectedCompileSuccess
        ["test/negative/determinism_jitcache/catalog_identity_positive.hs"]
      <> harness "determinism-jitcache" ExpectedCompileRefusal
        [ "test/negative/determinism_jitcache/freestring_key.hs"
        , "test/negative/determinism_jitcache/url_arm.hs"
        ]
      <> harness "pulsar-client" ExpectedCompileRefusal
        [ "test/negative/pulsar_client/LiteralTopic.hs"
        , "test/negative/pulsar_client/RawPayload.hs"
        ]
      <> harness "release-lifecycle" ExpectedCompileRefusal
        ["test/negative/reject/fourth_environment.hs"]
      <> harness "self-referential-gates" ExpectedCompileSuccess
        ["test/negative/self_referential_gates/legal_gate.hs"]
      <> harness "self-referential-gates" ExpectedCompileRefusal
        ["test/negative/self_referential_gates/leaked_gate.hs"]
      <> harness "test-workflow-algebra" ExpectedCompileSuccess
        ["test/negative/test_workflow_algebra/legal_teardown.hs"]
      <> harness "test-workflow-algebra" ExpectedCompileRefusal
        ["test/negative/test_workflow_algebra/missing_teardown.hs"]
      <> legalIllegalPairs "capacity-topology"
        [ "test/spec/dsl/capacity_topology_compile_fail/bare_apple"
        , "test/spec/dsl/capacity_topology_compile_fail/bare_windows"
        , "test/spec/dsl/capacity_topology_compile_fail/control_plane_reach"
        , "test/spec/dsl/capacity_topology_compile_fail/host_worker_reach"
        , "test/spec/dsl/capacity_topology_compile_fail/quorum"
        , "test/spec/dsl/capacity_topology_compile_fail/single_topology"
        , "test/spec/dsl/capacity_topology_compile_fail/site_quorum"
        ]
      <> legalIllegalPairs "gadt-decode-ir"
        [ "test/spec/dsl/compile/owner"
        , "test/spec/dsl/compile/tenant"
        , "test/spec/dsl/compile/transition"
        ]
      <> legalIllegalPairs "illegal-state-corpus"
        [ "test/spec/dsl/compilefail/cbor"
        , "test/spec/dsl/compilefail/endpoint"
        , "test/spec/dsl/compilefail/route"
        , "test/spec/dsl/compilefail/tenant"
        , "test/spec/dsl/compilefail/volume"
        ]
      <> harness "refinement-checker" ExpectedCompileSuccess
        ["test/spec/formal/refinement/RefinementModelProjection.hs"]
      <> harness "cabal-custom-setup" ExpectedCompileSuccess
        [ "vendor/supernova/lib/Setup.hs"
        , "vendor/supernova/proto/Setup.hs"
        ]
      <> harness "release-lifecycle" ExpectedCompileSuccess
        ["test/fixture/accept/release_lifecycle/environment.hs"]
      <> harness "chain-kernel-ast-check" ExpectedFixtureObservation
        [ "test/fixture/chain_boundary/astcheck/negative_foreign.hs"
        , "test/fixture/chain_boundary/astcheck/negative_import.hs"
        , "test/fixture/chain_boundary/astcheck/negative_orphan.hs"
        , "test/fixture/chain_boundary/astcheck/negative_raw_io.hs"
        , "test/fixture/chain_boundary/astcheck/negative_template_haskell.hs"
        , "test/fixture/chain_boundary/astcheck/negative_unsafe.hs"
        , "test/fixture/chain_boundary/astcheck/positive_basic.hs"
        , "test/fixture/chain_boundary/astcheck/positive_manifest.hs"
        ]
      <> harness "chain-kernel-boundary" ExpectedCompileSuccess
        ["test/fixture/chain_boundary/compilefail/checked_ctor_legal.hs"]
      <> harness "chain-kernel-boundary" ExpectedCompileRefusal
        ["test/fixture/chain_boundary/compilefail/checked_ctor_illegal.hs"]
      <> harness "refinement-checker" ExpectedCompileSuccess
        [ "test/fixture/refinement_checker/Broken.hs"
        , "test/fixture/refinement_checker/Decrement.hs"
        , "test/fixture/refinement_checker/Increment.hs"
        , "test/fixture/refinement_checker/Mismatch.hs"
        , "test/fixture/refinement_checker/Sum.hs"
        , "test/fixture/refinement_checker/Unknown.hs"
        ]
      <> harness "ui-program-schema" ExpectedCompileSuccess
        ["test/negative/compile_fail/ui_program_schema/checked_ui_legal.hs"]
      <> harness "ui-program-schema" ExpectedCompileRefusal
        ["test/negative/compile_fail/ui_program_schema/checked_ui_illegal.hs"]
      <> harness "ui-scope" ExpectedCompileSuccess
        [ "test/fixture/ui_scope/compile_pass/declassify.hs"
        , "test/fixture/ui_scope/compile_pass/forge_request_scope.hs"
        , "test/fixture/ui_scope/compile_pass/handle_escape.hs"
        , "test/fixture/ui_scope/compile_pass/raw_resource_id.hs"
        , "test/fixture/ui_scope/compile_pass/scope_retag.hs"
        ]
  )
 where
  harness owner outcome = map (\path -> (path, ("harness:" <> owner, outcome)))
  legalIllegalPairs owner stems =
    harness owner ExpectedCompileSuccess (map (<> "_legal.hs") stems)
      <> harness owner ExpectedCompileRefusal (map (<> "_illegal.hs") stems)

countProblem :: Text -> Int -> [value] -> [RegistryProblem]
countProblem name limit values =
  [RegistryResourceLimit name limit observed | observed > limit]
 where
  observed = length (take (limit + 1) values)

renderRegistryProblem :: RegistryProblem -> Text
renderRegistryProblem problem = case problem of
  RegistryResourceLimit name limit observed ->
    name <> " limit=" <> decimalText limit <> "; observed-at-least=" <> decimalText observed
  RegistryCabalParseFailure path -> "Cabal parser refused " <> Text.pack path
  RegistryCabalParseWarning path count ->
    "Cabal parser emitted " <> decimalText count <> " warning(s) for " <> Text.pack path
  RegistryDeclarationMissing component declared candidates ->
    "component=" <> component <> " declaration=" <> declared <> " has no exact source among " <> Text.pack (show candidates)
  RegistryDeclarationAmbiguous component declared candidates ->
    "component=" <> component <> " declaration=" <> declared <> " resolves ambiguously to " <> Text.pack (show candidates)
  RegistrySubjectUnassigned path -> "exact Haskell subject has no Cabal component assignment: " <> Text.pack path
  RegistrySubjectInventoryEmpty -> "exact Haskell subject inventory is empty"
  RegistrySubjectRoleUnclassified path -> "exact Haskell subject has no closed role: " <> Text.pack path
  RegistryFixtureDeclaredAsComponent path components ->
    "fixture-only subject is unexpectedly a component source: " <> Text.pack path <> " via " <> Text.pack (show components)
  RegistryExpectedRefusalUnassigned path ->
    "compile-refusal subject has no conditional Cabal component: " <> Text.pack path
  RegistryExpectationAuthorityInvalid detail ->
    "compiled compiler-expectation authority is internally invalid: " <> detail
  RegistryExpectedOutcomeMissing path component ->
    "compile-negative subject has no exact expectation: path="
      <> Text.pack path
      <> "; component="
      <> component
  RegistryExpectedOutcomeConflict path outcomes ->
    "compile-negative subject has conflicting component expectations: path="
      <> Text.pack path
      <> "; outcomes="
      <> Text.pack (show outcomes)
  RegistryExpectationBranchMismatch path component expected observed ->
    "compiler expectation branch mismatch: path="
      <> Text.pack path
      <> "; component="
      <> component
      <> "; expected="
      <> expected
      <> "; observed="
      <> observed
  RegistryExpectationBindingMissing path component ->
    "compiled compiler expectation has no exact acquired source/component binding: path="
      <> Text.pack path
      <> "; component="
      <> component

registryProblemCode :: RegistryProblem -> Text
registryProblemCode problem = case problem of
  RegistryResourceLimit {} -> "SRC-COMPILER-SUBJECT-CONTRACT-RESOURCE-LIMIT"
  RegistryCabalParseFailure {} -> "SRC-COMPILER-SUBJECT-CONTRACT-CABAL-PARSE"
  RegistryCabalParseWarning {} -> "SRC-COMPILER-SUBJECT-CONTRACT-CABAL-WARNING"
  RegistryDeclarationMissing {} -> "SRC-COMPILER-SUBJECT-CONTRACT-DECLARATION-MISSING"
  RegistryDeclarationAmbiguous {} -> "SRC-COMPILER-SUBJECT-CONTRACT-DECLARATION-AMBIGUOUS"
  RegistrySubjectUnassigned {} -> "SRC-COMPILER-SUBJECT-CONTRACT-SUBJECT-UNASSIGNED"
  RegistrySubjectInventoryEmpty -> "SRC-COMPILER-SUBJECT-CONTRACT-INVENTORY-EMPTY"
  RegistrySubjectRoleUnclassified {} -> "SRC-COMPILER-SUBJECT-CONTRACT-ROLE-UNCLASSIFIED"
  RegistryFixtureDeclaredAsComponent {} -> "SRC-COMPILER-SUBJECT-CONTRACT-FIXTURE-COMPONENT"
  RegistryExpectedRefusalUnassigned {} -> "SRC-COMPILER-SUBJECT-CONTRACT-REFUSAL-UNASSIGNED"
  RegistryExpectationAuthorityInvalid {} -> "SRC-COMPILER-SUBJECT-CONTRACT-AUTHORITY-INVALID"
  RegistryExpectedOutcomeMissing {} -> "SRC-COMPILER-SUBJECT-CONTRACT-EXPECTATION-MISSING"
  RegistryExpectedOutcomeConflict {} -> "SRC-COMPILER-SUBJECT-CONTRACT-EXPECTATION-CONFLICT"
  RegistryExpectationBranchMismatch {} -> "SRC-COMPILER-SUBJECT-CONTRACT-BRANCH-MISMATCH"
  RegistryExpectationBindingMissing {} -> "SRC-COMPILER-SUBJECT-CONTRACT-BINDING-MISSING"

problemSubject :: RegistryProblem -> FilePath
problemSubject problem = case problem of
  RegistryCabalParseFailure path -> path
  RegistryCabalParseWarning path _ -> path
  RegistryDeclarationMissing component _ _ -> Text.unpack component
  RegistryDeclarationAmbiguous component _ _ -> Text.unpack component
  RegistrySubjectUnassigned path -> path
  RegistrySubjectInventoryEmpty -> "<haskell-subject-inventory>"
  RegistrySubjectRoleUnclassified path -> path
  RegistryFixtureDeclaredAsComponent path _ -> path
  RegistryExpectedRefusalUnassigned path -> path
  RegistryExpectationAuthorityInvalid _ -> "<compiler-expectation-authority>"
  RegistryExpectedOutcomeMissing path _ -> path
  RegistryExpectedOutcomeConflict path _ -> path
  RegistryExpectationBranchMismatch path _ _ _ -> path
  RegistryExpectationBindingMissing path _ -> path
  RegistryResourceLimit name _ _ -> Text.unpack name

registryDigest :: [SubjectAssignment] -> Text
registryDigest assignments =
  Text.pack (show (Crypto.hashFinalize context :: Crypto.Digest Crypto.SHA256))
 where
  context = foldl Crypto.hashUpdate initial (concatMap assignmentChunks assignments)
  initial = Crypto.hashUpdate (Crypto.hashInit :: Crypto.Context Crypto.SHA256) registryDomain

assignmentChunks :: SubjectAssignment -> [ByteString]
assignmentChunks assignment =
  map framed
    ( [ TextEncoding.encodeUtf8 (Text.pack (assignmentPath assignment))
      , TextEncoding.encodeUtf8 (assignmentObjectIdentity assignment)
      , ByteString8.pack (show (assignmentRole assignment))
      , ByteString8.pack (show (assignmentExpectedOutcome assignment))
      ]
        <> concat
          [ [TextEncoding.encodeUtf8 component, TextEncoding.encodeUtf8 branchIdentity]
          | ComponentBinding component branchIdentity <- assignmentBindings assignment
          ]
    )
    <> ["\0"]

framed :: ByteString -> ByteString
framed bytes = ByteString8.pack (show (ByteString8.length bytes)) <> ":" <> bytes

registryDomain :: ByteString
registryDomain = "amoebius.compiler-subject-registry.v2\0"

componentText :: UnqualComponentName -> Text
componentText = Text.pack . unUnqualComponentName

moduleText :: CabalModule.ModuleName -> Text
moduleText = Text.pack . CabalModule.toFilePath

packageRoot :: FilePath -> FilePath
packageRoot path = case takeDirectory path of
  "." -> ""
  root -> normalisePosix root

joinRoot :: FilePath -> FilePath -> FilePath
joinRoot "" path = normalisePosix path
joinRoot root path = normalisePosix (root </> path)

normalisePosix :: FilePath -> FilePath
normalisePosix path = case normalise path of
  "." -> ""
  value | "./" `prefixOf` value -> drop 2 value
  value -> value

pathPrefix :: FilePath -> FilePath -> Bool
pathPrefix = prefixOf

prefixOf :: Eq value => [value] -> [value] -> Bool
prefixOf [] _ = True
prefixOf _ [] = False
prefixOf (left : lefts) (right : rights) = left == right && prefixOf lefts rights

decimalText :: Int -> Text
decimalText = Text.pack . show
