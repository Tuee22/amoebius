{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}

-- | Two-way Cabal source map over the acquired path inventory. Cabal's parser
-- owns stanza syntax; the observed files, rather than authored counts, own the
-- source side of the comparison.
module Amoebius.Layout.PackageMap
  ( packageMapReport
  , SourceComponentMap
  , ComponentDependencyMap
  , ComponentPackageMap
  , ForwardOwnedModuleMap
  , PackageCatalog
  , emptyPackageCatalog
  , loadPackageCatalog
  , lookupExternalModule
  , lookupUnselectedModule
  , lookupImplicitPrelude
  , implicitAvailablePreludeUnit
  , lookupImplicitAvailablePrelude
  , implicitStandalonePreludeUnit
  , lookupImplicitStandalonePrelude
  , lookupStandaloneExternalModule
  , lookupStandaloneRegisteredOnlyModule
  , lookupStandaloneRegisteredOnlyExport
  , lookupStandaloneExternalExport
  , lookupStandaloneExternalMemberExport
  , packageCatalogMemberNames
  , lookupExternalExport
  , lookupAvailableExternalExport
  , lookupExternalMemberExport
  , lookupAvailableExternalMemberExport
  , lookupDeferredSeedModule
  , packageCatalogHasModuleInterface
  , implicitPreludeUnit
  , packageCatalogHasComponent
  , packageCatalogFromInputs
  , packageCatalogWithPrelude
  , packageCatalogWithModuleExports
  , packageCatalogWithModuleMembers
  , loadExternalInterfaces
  , maintainedForkPaths
  ) where

import Amoebius.Layout.Classify (LayoutFinding (..))
import Control.Exception (IOException, SomeException, displayException, try)
import Control.Monad (filterM)
import Control.Monad.IO.Class (liftIO)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.Aeson (FromJSON (..), eitherDecodeStrict', withObject, (.:), (.:?), (.!=))
import Data.ByteString qualified as ByteString
import Data.Char (isAlphaNum, isUpper)
import Data.List (nub, sort)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Distribution.Compat.NonEmptySet qualified as NonEmptySet
import Distribution.Fields.ParseResult (runParseResult)
import Distribution.PackageDescription
  ( Benchmark (..)
  , BuildInfo (..)
  , Executable (..)
  , GenericPackageDescription (..)
  , Library (..)
  , TestSuite (..)
  )
import Distribution.PackageDescription.Parsec (parseGenericPackageDescription)
import Distribution.Pretty (prettyShow)
import Distribution.Types.Dependency (Dependency (..))
import Distribution.Types.LibraryName (LibraryName (..))
import Distribution.Types.PackageName (unPackageName)
import Distribution.Types.UnqualComponentName (unUnqualComponentName)
import Distribution.Types.BenchmarkInterface (BenchmarkInterface (..))
import Distribution.Types.CondTree (CondBranch (..), CondTree (..))
import Distribution.Types.TestSuiteInterface (TestSuiteInterface (..))
import Distribution.Utils.Path (getSymbolicPath)
import GHC (getSession, getSessionDynFlags, runGhc)
import GHC.Driver.DynFlags (targetProfile)
import GHC.Driver.Env.Types (hsc_NC)
import GHC.Iface.Binary (CheckHiWay (..), TraceBinIFace (..), readBinIface)
import GHC.Types.Avail (AvailInfo (..), availNames)
import GHC.Types.Name (nameOccName)
import GHC.Types.Name.Occurrence (occNameString)
import GHC.Unit.Module (moduleName, moduleNameString, moduleUnitId)
import GHC.Unit.Module.ModIface (mi_exports, mi_module)
import GHC.Unit.Types (unitIdString)
import System.Directory (doesFileExist)
import System.Environment (getExecutablePath)
import System.Exit (ExitCode (..))
import System.FilePath ((</>), dropExtension, takeDirectory, takeExtension)
import System.Process (readProcessWithExitCode)

data SourceClaim = SourceClaim
  { claimComponent :: Text
  , claimDirectories :: [FilePath]
  , claimFile :: FilePath
  , claimDependencies :: [Text]
  , claimPackageDependencies :: [Text]
  , claimAutogen :: Bool
  }

-- A source may be compiled by several Cabal components. Preserve each owner;
-- a module name alone does not identify an import target in this package.
type SourceComponentMap = Map FilePath [Text]
type ComponentDependencyMap = Map Text [Text]
type ComponentPackageMap = Map Text [Text]
type ForwardOwnedModuleMap = Map (Text, Text) (FilePath, Text)

packageMapReport :: ByteString.ByteString -> ByteString.ByteString -> [FilePath] -> ([LayoutFinding], [Text], SourceComponentMap, ComponentDependencyMap, ComponentPackageMap, ForwardOwnedModuleMap)
packageMapReport mainBytes probeBytes present = case (parse "amoebius.cabal" mainBytes, parse "probe/probe.cabal" probeBytes) of
  (Left problem, _) -> ([problem], [], Map.empty, Map.empty, Map.empty, Map.empty)
  (_, Left problem) -> ([problem], [], Map.empty, Map.empty, Map.empty, Map.empty)
  (Right mainPackage, Right probePackage) ->
    ([ LayoutFinding "DeclaredModuleMissing" (Text.unpack (claimComponent claim) <> ":" <> claimFile claim)
    | claim <- claims, null (matchingPaths claim), not (forwardOwned claim)]
      <> [LayoutFinding "UnmappedHaskellSource" path
         | path <- haskellPaths, path `Set.notMember` mapped, standaloneSourceRole path == Nothing]
      <> [LayoutFinding "AmbiguousModuleSource" (Text.unpack (claimComponent claim) <> ":" <> claimFile claim)
         | claim <- claims, length (matchingPaths claim) > 1],
     [Text.intercalate "\t" ["package-owed", claimComponent claim <> ":" <> Text.pack (claimFile claim), "generated-proto"]
     | claim <- claims, null (matchingPaths claim), forwardOwned claim]
       <> [Text.intercalate "\t" ["package-standalone", Text.pack path, role]
          | path <- haskellPaths, path `Set.notMember` mapped
          , Just role <- [standaloneSourceRole path]]
       <> [Text.intercalate "\t" ["package-build-dependency", component, package]
          | (component, package) <- Set.toAscList (Set.fromList
              [(claimComponent claim, package)
              | claim <- claims, package <- claimPackageDependencies claim])],
     Map.map (nub . sort) (Map.fromListWith (<>)
       [(path, [claimComponent claim]) | claim <- claims, path <- matchingPaths claim]),
     Map.map (nub . sort) (Map.fromListWith (<>)
       [(claimComponent claim, claimDependencies claim) | claim <- claims]),
     Map.map (nub . sort) (Map.fromListWith (<>)
       [(claimComponent claim, claimPackageDependencies claim) | claim <- claims]),
     Map.fromList
       [((claimComponent claim, Text.replace "/" "." (Text.pack (dropExtension (claimFile claim)))),
         (claimFile claim, "generated-proto"))
       | claim <- claims, null (matchingPaths claim), forwardOwned claim])
   where
    claims = sourceClaims "" mainPackage <> sourceClaims "probe" probePackage
    presentSet = Set.fromList present
    matchingPaths claim =
      [directory </> claimFile claim | directory <- claimDirectories claim,
       (directory </> claimFile claim) `Set.member` presentSet]
    mapped = Set.fromList (concatMap matchingPaths claims)
    haskellPaths =
      sort [path | path <- present, takeExtension path == ".hs",
            any (`prefix` path) ["src/", "app/", "test/", "probe/"]]
    -- These generated Haskell bindings belong to the typed Proto handoff.
    -- Their absence is an explicit later-owned source, not an unseen file.
    forwardOwned claim = claimAutogen claim && claimComponent claim == "library:pulsar-client"
      && claimFile claim `elem`
      ["Proto/PulsarApi.hs", "Proto/PulsarApi_Fields.hs"]
    standaloneSourceRole :: FilePath -> Maybe Text
    standaloneSourceRole path
      | "test/negative/" `prefix` path = Just "compile-negative"
      | "test/fixture/" `prefix` path = Just "fixture"
      | "test/mutant/" `prefix` path = Just "mutant-source"
      | "test/spec/dsl/compile/" `prefix` path = Just "compile-positive"
      | "test/spec/dsl/compilefail/" `prefix` path = Just "compile-negative"
      | "test/spec/dsl/capacity_topology_compile_fail/" `prefix` path = Just "compile-negative"
      | path == "test/spec/formal/refinement/RefinementModelProjection.hs" = Just "model-projection"
      | path == "test/spec/formal/symbolic/FakeSmtSolver.hs" = Just "fake-boundary"
      | path `Set.member` Set.fromList maintainedForkPaths = Just "maintained-fork"
      | otherwise = Nothing
 where
  parse path bytes = case runParseResult (parseGenericPackageDescription bytes) of
    (_, Left _) -> Left (LayoutFinding "PackageDescriptionUnparsable" path)
    (_, Right description) -> Right description

-- This layout-owned list is cross-checked with the independently maintained
-- toolchain provenance declaration by the separate suite.
maintainedForkPaths :: [FilePath]
maintainedForkPaths = map ("src/vendor/" <>)
  [ "Pulsar.hs", "Pulsar/AppState.hs", "Pulsar/Connection.hs", "Pulsar/Consumer.hs"
  , "Pulsar/Core.hs", "Pulsar/Internal/Core.hs", "Pulsar/Internal/Logger.hs"
  , "Pulsar/Internal/TCPClient.hs", "Pulsar/Producer.hs", "Pulsar/Protocol/CheckSum.hs"
  , "Pulsar/Protocol/Commands.hs", "Pulsar/Protocol/Decoder.hs", "Pulsar/Protocol/Encoder.hs"
  , "Pulsar/Protocol/Frame.hs", "Pulsar/Types.hs", "Data/Bifunctor/Flip.hs"
  , "Control/Category/Dual.hs"
  ]

sourceClaims :: FilePath -> GenericPackageDescription -> [SourceClaim]
sourceClaims packageRoot description =
  concat . concat $
    [ [moduleClaims "library" (libBuildInfo library)
        (map prettyShow (exposedModules library <> otherModules (libBuildInfo library)))
      | tree <- maybe [] pure (condLibrary description), let library = flatten tree]
    , [moduleClaims (Text.pack ("library:" <> prettyShow name)) (libBuildInfo library)
        (map prettyShow (exposedModules library <> otherModules (libBuildInfo library)))
      | (name, tree) <- condSubLibraries description, let library = flatten tree]
    , [moduleClaims (Text.pack ("executable:" <> prettyShow name)) (buildInfo executable)
        (map prettyShow (otherModules (buildInfo executable)) <> [getSymbolicPath (modulePath executable)])
      | (name, tree) <- condExecutables description, let executable = flatten tree]
    , [moduleClaims (Text.pack ("test:" <> prettyShow name)) (testBuildInfo suite)
        (map prettyShow (otherModules (testBuildInfo suite)) <> testMain suite)
      | (name, tree) <- condTestSuites description, let suite = flatten tree]
    , [moduleClaims (Text.pack ("benchmark:" <> prettyShow name)) (benchmarkBuildInfo benchmark)
        (map prettyShow (otherModules (benchmarkBuildInfo benchmark)) <> benchmarkMain benchmark)
      | (name, tree) <- condBenchmarks description, let benchmark = flatten tree]
    ]
 where
  moduleClaims component info names =
    [SourceClaim component (map (packageRoot </>) (map getSymbolicPath (hsSourceDirs info)))
      (sourceName name) (localDependencies info) (packageDependencies info)
      (name `elem` map prettyShow (autogenModules info))
    | name <- nub names]
  packageDependencies info =
    [Text.pack (unPackageName packageName)
    | Dependency packageName _ _ <- targetBuildDepends info]
  localDependencies info =
    [case libraryName of
       LMainLibName -> "library"
       LSubLibName name -> Text.pack ("library:" <> unUnqualComponentName name)
    | Dependency packageName _ libraries <- targetBuildDepends info
    , unPackageName packageName == "amoebius"
    , libraryName <- NonEmptySet.toList libraries]
  sourceName name
    | ".hs" `suffix` name = name
    | otherwise = Text.unpack (Text.replace "." "/" (Text.pack name)) <> ".hs"
  testMain suite = case testInterface suite of
    TestSuiteExeV10 _ path -> [getSymbolicPath path]
    TestSuiteLibV09 _ name -> [prettyShow name]
    TestSuiteUnsupported _ -> []
  benchmarkMain benchmark = case benchmarkInterface benchmark of
    BenchmarkExeV10 _ path -> [getSymbolicPath path]
    BenchmarkUnsupported _ -> []

flatten :: Monoid a => CondTree v c a -> a
flatten tree =
  condTreeData tree
    <> mconcat
      [flatten (condBranchIfTrue branch) <> maybe mempty flatten (condBranchIfFalse branch)
      | branch <- condTreeComponents tree]

prefix :: String -> String -> Bool
prefix start value = take (length start) value == start

suffix :: String -> String -> Bool
suffix end value = reverse end `prefix` reverse value

-- | Selected direct units establish resolved imports. Plan units available to
-- an unplanned component only support candidate attribution.
data PackageCatalog = PackageCatalog
  { catalogSelected :: Map Text [(Text, Text, Set.Set Text)]
  , catalogDeclared :: ComponentPackageMap
  , catalogAvailable :: [(Text, Text, Set.Set Text)]
  , catalogPreludeExports :: Map Text (Set.Set Text)
  , catalogModuleExports :: Map (Text, Text) (Set.Set Text)
  , catalogModuleMembers :: Map (Text, Text, Text) (Set.Set Text)
  , catalogRegistered :: Map Text RegisteredUnit
  , catalogLibdir :: Maybe FilePath
  }

emptyPackageCatalog :: PackageCatalog
emptyPackageCatalog = PackageCatalog Map.empty Map.empty [] Map.empty Map.empty Map.empty Map.empty Nothing

lookupExternalModule :: PackageCatalog -> Text -> Text -> [(Text, Text)]
lookupExternalModule catalog component moduleName =
  [(package, unit) | (package, unit, modules) <- Map.findWithDefault [] component (catalogSelected catalog)
  , moduleName `Set.member` modules]

lookupUnselectedModule :: PackageCatalog -> Text -> Text -> [(Text, Text)]
lookupUnselectedModule catalog component moduleName =
  [(package, unit) | package <- Map.findWithDefault [] component (catalogDeclared catalog)
  , (availablePackage, unit, modules) <- catalogAvailable catalog
  , package == availablePackage, moduleName `Set.member` modules]

implicitPreludeUnit :: PackageCatalog -> Text -> [(Text, Text)]
implicitPreludeUnit catalog component =
  [(package, unit)
  | (package, unit, modules) <- Map.findWithDefault [] component (catalogSelected catalog)
  , package == "base", "Prelude" `Set.member` modules
  , Map.member unit (catalogPreludeExports catalog)]

lookupImplicitPrelude :: PackageCatalog -> Text -> Text -> [(Text, Text)]
lookupImplicitPrelude catalog component name =
  [(package, unit) | (package, unit) <- implicitPreludeUnit catalog component
  , name `Set.member` Map.findWithDefault Set.empty unit (catalogPreludeExports catalog)]

implicitAvailablePreludeUnit :: PackageCatalog -> Text -> [(Text, Text)]
implicitAvailablePreludeUnit catalog component
  | packageCatalogHasComponent catalog component = []
  | otherwise = case lookupUnselectedModule catalog component "Prelude" of
      [("base", unit)] | Map.member unit (catalogPreludeExports catalog) -> [("base", unit)]
      _ -> []

lookupImplicitAvailablePrelude :: PackageCatalog -> Text -> Text -> [(Text, Text)]
lookupImplicitAvailablePrelude catalog component name =
  [(package, unit) | (package, unit) <- implicitAvailablePreludeUnit catalog component
  , name `Set.member` Map.findWithDefault Set.empty unit (catalogPreludeExports catalog)]

-- | A standalone input has no Cabal component selection. The compiler's
-- digest-checked Prelude interface is still usable when exactly one available
-- base unit supplies it; ambiguity leaves the call unattributed.
implicitStandalonePreludeUnit :: PackageCatalog -> [(Text, Text)]
implicitStandalonePreludeUnit catalog = case Set.toAscList (Set.fromList
  [(package, unit) | (package, unit, modules) <- catalogAvailable catalog
  , package == "base", "Prelude" `Set.member` modules
  , Map.member unit (catalogPreludeExports catalog)]) of
    [provider] -> [provider]
    _ -> []

lookupImplicitStandalonePrelude :: PackageCatalog -> Text -> [(Text, Text)]
lookupImplicitStandalonePrelude catalog name =
  [(package, unit) | (package, unit) <- implicitStandalonePreludeUnit catalog
  , name `Set.member` Map.findWithDefault Set.empty unit (catalogPreludeExports catalog)]

lookupStandaloneExternalModule :: PackageCatalog -> Text -> [(Text, Text)]
lookupStandaloneExternalModule catalog moduleName = case Set.toAscList (Set.fromList
  [(package, unit) | (package, unit, modules) <- catalogAvailable catalog
  , moduleName `Set.member` modules]) of
    [provider] -> [provider]
    _ -> []

-- | Registered units outside the executable's plan are diagnostic candidates
-- only. Their interfaces can be inspected, but they establish no dependency.
lookupStandaloneRegisteredOnlyModule :: PackageCatalog -> Text -> [(Text, Text)]
lookupStandaloneRegisteredOnlyModule catalog moduleName = case Set.toAscList (Set.fromList
  [(registeredPackage record, unit)
  | (unit, record) <- Map.toAscList (catalogRegistered catalog)
  , moduleName `Set.member` registeredModules record
  , not (any (\(_, availableUnit, _) -> availableUnit == unit) (catalogAvailable catalog))]) of
    [provider] -> [provider]
    _ -> []

lookupStandaloneRegisteredOnlyExport :: PackageCatalog -> Text -> Text -> [(Text, Text)]
lookupStandaloneRegisteredOnlyExport catalog moduleName name =
  [(package, unit)
  | (package, unit) <- lookupStandaloneRegisteredOnlyModule catalog moduleName
  , name `Set.member` Map.findWithDefault Set.empty (unit, moduleName) (catalogModuleExports catalog)]

lookupStandaloneExternalExport :: PackageCatalog -> Text -> Text -> [(Text, Text)]
lookupStandaloneExternalExport catalog moduleName name =
  [(package, unit) | (package, unit) <- lookupStandaloneExternalModule catalog moduleName
  , name `Set.member` Map.findWithDefault Set.empty (unit, moduleName) (catalogModuleExports catalog)]

lookupStandaloneExternalMemberExport :: PackageCatalog -> Text -> Text -> Text -> [(Text, Text)]
lookupStandaloneExternalMemberExport catalog moduleName parent member =
  [(package, unit) | (package, unit) <- lookupStandaloneExternalModule catalog moduleName
  , member `Set.member` Map.findWithDefault Set.empty
      (unit, moduleName, parent) (catalogModuleMembers catalog)]

packageCatalogMemberNames :: PackageCatalog -> Text -> Text -> Text -> [Text]
packageCatalogMemberNames catalog unit moduleName parent =
  Set.toAscList (Map.findWithDefault Set.empty
    (unit, moduleName, parent) (catalogModuleMembers catalog))

lookupExternalExport :: PackageCatalog -> Text -> Text -> Text -> [(Text, Text)]
lookupExternalExport catalog component moduleName name =
  [(package, unit)
  | (package, unit) <- lookupExternalModule catalog component moduleName
  , name `Set.member` Map.findWithDefault Set.empty (unit, moduleName) (catalogModuleExports catalog)]

lookupAvailableExternalExport :: PackageCatalog -> Text -> Text -> Text -> [(Text, Text)]
lookupAvailableExternalExport catalog component moduleName name
  | packageCatalogHasComponent catalog component = []
  | otherwise = case lookupUnselectedModule catalog component moduleName of
      [(package, unit)]
        | name `Set.member` Map.findWithDefault Set.empty (unit, moduleName) (catalogModuleExports catalog) ->
            [(package, unit)]
      _ -> []

lookupExternalMemberExport :: PackageCatalog -> Text -> Text -> Text -> Text -> [(Text, Text)]
lookupExternalMemberExport catalog component moduleName parent member =
  [(package, unit) | (package, unit) <- lookupExternalModule catalog component moduleName
  , member `Set.member` Map.findWithDefault Set.empty (unit, moduleName, parent) (catalogModuleMembers catalog)]

lookupAvailableExternalMemberExport :: PackageCatalog -> Text -> Text -> Text -> Text -> [(Text, Text)]
lookupAvailableExternalMemberExport catalog component moduleName parent member
  | packageCatalogHasComponent catalog component = []
  | otherwise = case lookupUnselectedModule catalog component moduleName of
      [(package, unit)]
        | member `Set.member` Map.findWithDefault Set.empty
            (unit, moduleName, parent) (catalogModuleMembers catalog) -> [(package, unit)]
      _ -> []

lookupDeferredSeedModule :: ComponentDependencyMap -> PackageCatalog -> Text -> Text -> Maybe (Text, Text)
lookupDeferredSeedModule dependencies catalog component moduleName = do
  (package, owner) <- case (component, moduleName) of
    ("library:infernix", "Infernix.Topic.Metadata") ->
      Just ("infernix", "infernix-rederivation")
    ("test:jitml-cuda-artifact-lift-contract", "JitML.Codegen.RuntimeOperationsCuda") ->
      Just ("jitml", "jitml-rederivation")
    _ -> Nothing
  let declaringOwners = component : Map.findWithDefault [] component dependencies
  if any (\ownerComponent -> package `elem` Map.findWithDefault [] ownerComponent (catalogDeclared catalog)) declaringOwners
      && not (packageCatalogHasComponent catalog component)
      && null (lookupUnselectedModule catalog component moduleName)
    then Just (package, owner)
    else Nothing

packageCatalogHasModuleInterface :: PackageCatalog -> Text -> Text -> Bool
packageCatalogHasModuleInterface catalog unit moduleName =
  Map.member (unit, moduleName) (catalogModuleExports catalog)

packageCatalogWithPrelude :: Map Text (Set.Set Text) -> PackageCatalog -> PackageCatalog
packageCatalogWithPrelude exported catalog = catalog {catalogPreludeExports = exported}

packageCatalogWithModuleExports :: Map (Text, Text) (Set.Set Text) -> PackageCatalog -> PackageCatalog
packageCatalogWithModuleExports exported catalog = catalog {catalogModuleExports = exported}

packageCatalogWithModuleMembers :: Map (Text, Text, Text) (Set.Set Text) -> PackageCatalog -> PackageCatalog
packageCatalogWithModuleMembers members catalog = catalog {catalogModuleMembers = members}

packageCatalogHasComponent :: PackageCatalog -> Text -> Bool
packageCatalogHasComponent catalog component = Map.member component (catalogSelected catalog)

data BuildPlan = BuildPlan Text Text [PlanEntry]

data RegisteredUnit = RegisteredUnit
  { registeredPackage :: Text
  , registeredModules :: Set.Set Text
  , registeredDirs :: [FilePath]
  , registeredReexports :: Map Text (Text, Text)
  }

data PlanEntry = PlanEntry
  { planUnit :: Text
  , planPackage :: Text
  , planComponent :: Maybe Text
  , planDepends :: [Text]
  }

instance FromJSON BuildPlan where
  parseJSON = withObject "BuildPlan" $ \value ->
    BuildPlan <$> value .: "compiler-id" <*> value .: "compiler-abi" <*> value .: "install-plan"

instance FromJSON PlanEntry where
  parseJSON = withObject "PlanEntry" $ \value ->
    PlanEntry <$> value .: "id" <*> value .: "pkg-name"
      <*> value .:? "component-name" <*> (value .:? "depends" .!= [])

loadPackageCatalog :: ComponentPackageMap -> IO (Either LayoutFinding (PackageCatalog, [Text]))
loadPackageCatalog declared = do
  executable <- getExecutablePath
  planPath <- findPlan (takeDirectory executable)
  case planPath of
    Nothing -> pure (Left (LayoutFinding "PackagePlanMissing" executable))
    Just path -> do
      bytes <- try (ByteString.readFile path) :: IO (Either IOException ByteString.ByteString)
      case bytes of
        Left _ -> pure (Left (LayoutFinding "PackagePlanUnreadable" path))
        Right planBytes -> case eitherDecodeStrict' planBytes of
          Left _ -> pure (Left (LayoutFinding "PackagePlanUnparsable" path))
          Right plan@(BuildPlan compiler abi _) -> do
            pathResult <- runTool "cabal" ["path"]
            case pathResult >>= storeDirectory of
              Nothing -> pure (Left (LayoutFinding "CabalStoreUnavailable" path))
              Just storeRoot -> do
                let database = Text.unpack storeRoot </> Text.unpack (compiler <> "-" <> abi) </> "package.db"
                present <- doesFileExist (database </> "package.cache")
                if not present
                  then pure (Left (LayoutFinding "PackageDatabaseMissing" database))
                  else do
                    dump <- runTool "ghc-pkg" ["--global", "--package-db", database, "dump"]
                    case dump of
                      Nothing -> pure (Left (LayoutFinding "PackageDatabaseUnreadable" database))
                      Just dumped ->
                        let registered = parsePackageDump dumped
                        in case catalogue declared plan registered of
                          Left problem -> pure (Left problem)
                          Right selected -> do
                            libdir <- runTool "ghc" ["--print-libdir"]
                            case libdir of
                              Nothing -> pure (Left (LayoutFinding "CompilerLibraryDirectoryMissing" path))
                              Just directory -> do
                                prelude <- loadPreludeInterfaces (Text.unpack (Text.strip directory)) registered selected
                                pure $ case prelude of
                                  Left problem -> Left problem
                                  Right (catalog, interfaceRows) -> Right
                                    (catalog {catalogLibdir = Just (Text.unpack (Text.strip directory))},
                                     [Text.intercalate "\t" ["graph-package-plan", digest planBytes]
                                     ,Text.intercalate "\t" ["graph-package-db", digest (TextEncoding.encodeUtf8 dumped)]]
                                       <> interfaceRows)
 where
  findPlan directory = do
    let candidate = directory </> "cache/plan.json"
    found <- doesFileExist candidate
    if found then pure (Just candidate)
    else let parent = takeDirectory directory
         in if parent == directory then pure Nothing else findPlan parent
  runTool command args = do
    attempted <- try (readProcessWithExitCode command args "") :: IO (Either IOException (ExitCode, String, String))
    pure $ case attempted of
      Right (ExitSuccess, out, _) -> Just (Text.pack out)
      _ -> Nothing
  storeDirectory output = case [Text.strip value
    | line <- Text.lines output, Just value <- [Text.stripPrefix "store-dir:" line]] of
      [directory] | not (Text.null directory) -> Just directory
      _ -> Nothing

-- | A pure seam for paired package-plan and registered-module challenges.
packageCatalogFromInputs :: ComponentPackageMap -> ByteString.ByteString -> Text -> Either LayoutFinding PackageCatalog
packageCatalogFromInputs declared planBytes dumped = case eitherDecodeStrict' planBytes of
  Left _ -> Left (LayoutFinding "PackagePlanUnparsable" "plan")
  Right plan -> catalogue declared plan (parsePackageDump dumped)

catalogue :: ComponentPackageMap -> BuildPlan -> Map Text RegisteredUnit -> Either LayoutFinding PackageCatalog
catalogue declared (BuildPlan _ _ entries) registered = do
  let units = Map.fromList [(planUnit entry, planPackage entry) | entry <- entries]
      own = [entry | entry <- entries, planPackage entry `elem` ["amoebius", "probe"]
                 , Just _ <- [planComponent entry]]
      components = [(renderComponent name, entry)
        | entry <- own, Just name <- [planComponent entry]]
  if Map.size units /= length entries
    then Left (LayoutFinding "PackagePlanDuplicateUnit" "install-plan")
    else do
      selected <- mapM (selectComponent units) components
      let available = [(package, unit, modules)
            | (unit, package) <- Map.toAscList units
            , Just record <- [Map.lookup unit registered]
            , registeredPackage record == package
            , let modules = registeredModules record]
      pure (PackageCatalog (Map.fromList selected) declared available Map.empty Map.empty Map.empty registered Nothing)
 where
  selectComponent units (component, entry) = do
    packages <- mapM (\unit -> maybe (Left (LayoutFinding "PackagePlanDependencyMissing" (Text.unpack unit)))
                             (Right . (unit,)) (Map.lookup unit units)) (planDepends entry)
    let actual = Set.fromList (map snd packages)
        expected = Set.fromList (Map.findWithDefault [] component declared)
    if actual /= expected
      then Left (LayoutFinding "PackagePlanDependencyMismatch" (Text.unpack component))
      else do
        providers <- mapM (registeredProvider component)
          [(unit, package) | (unit, package) <- packages, package `notElem` ["amoebius", "probe"]]
        pure (component, providers)
  registeredProvider component (unit, package) = case Map.lookup unit registered of
    Just record | registeredPackage record == package ->
      Right (package, unit, registeredModules record)
    _ -> Left (LayoutFinding "PackageUnitMetadataMissing" (Text.unpack component <> ":" <> Text.unpack unit))
  renderComponent name
    | name == "lib" = "library"
    | Just suffixName <- Text.stripPrefix "lib:" name = "library:" <> suffixName
    | Just suffixName <- Text.stripPrefix "exe:" name = "executable:" <> suffixName
    | otherwise = name

parsePackageDump :: Text -> Map Text RegisteredUnit
parsePackageDump dumped = Map.fromList
  [(unit, RegisteredUnit package (Set.fromList modules) dirs reexports)
  | record <- Text.splitOn "\n---\n" dumped
  , [unit] <- [take 1 (Text.words (Text.unwords (field "id" record)))]
  , let packageField = case field "package-name" record of
          [] -> field "name" record
          named -> named
  , [package] <- [take 1 (Text.words (Text.unwords packageField))]
  , let modules = [token
          | raw <- Text.words (Text.unwords (field "exposed-modules" record))
          , let token = Text.dropWhileEnd (== ',') raw
          , validModuleName token]
  , let packageRoot = Text.dropAround (== '"')
          (Text.strip (Text.unwords (field "pkgroot" record)))
  , let dirs = [Text.unpack (if Text.null packageRoot then raw
                     else Text.replace "${pkgroot}" packageRoot raw)
          | raw <- Text.words (Text.unwords (field "import-dirs" record))]
  , let tokens = Text.words (Text.unwords (field "exposed-modules" record))
  , let reexports = Map.fromList
          [(Text.dropWhileEnd (== ',') exposed, (originUnit, originName))
          | (exposed, keyword, origin) <- zip3 tokens (drop 1 tokens) (drop 2 tokens)
          , keyword == "from"
          , let (originUnit, qualifiedName) = Text.breakOn ":" (Text.dropWhileEnd (== ',') origin)
          , let originName = Text.drop 1 qualifiedName
          , validModuleName (Text.dropWhileEnd (== ',') exposed)
          , not (Text.null originUnit), validModuleName originName]]
 where
  field name record = case dropWhile (not . Text.isPrefixOf (name <> ":")) (Text.lines record) of
    [] -> []
    (first : rest) -> Text.strip (Text.drop (Text.length name + 1) first)
      : [Text.strip line | line <- takeWhile (\line -> Text.null line || Text.head line == ' ') rest]
  validModuleName name = all validSegment (Text.splitOn "." name)
  validSegment segment = case Text.uncons segment of
    Just (first, rest) -> isUpper first && Text.all (\character -> isAlphaNum character || character `elem` ['_', '\'']) rest
    Nothing -> False

loadPreludeInterfaces :: FilePath -> Map Text RegisteredUnit -> PackageCatalog
  -> IO (Either LayoutFinding (PackageCatalog, [Text]))
loadPreludeInterfaces libdir registered catalog = do
  let baseUnits = Set.toAscList (Set.fromList
        [unit | providers <- Map.elems (catalogSelected catalog)
        , (package, unit, modules) <- providers
        , package == "base", "Prelude" `Set.member` modules])
  loaded <- mapM loadBase baseUnits
  pure $ do
    interfaces <- sequence loaded
    let namesByUnit = Map.fromList [(unit, names) | (unit, names, _) <- interfaces]
    Right (packageCatalogWithPrelude namesByUnit catalog,
      [row | (_, _, row) <- interfaces])
 where
  loadBase unit = case Map.lookup unit registered of
    Just record | registeredPackage record == "base"
      && "Prelude" `Set.member` registeredModules record -> do
        paths <- filterM doesFileExist [directory </> "Prelude.hi" | directory <- registeredDirs record]
        case nub paths of
          [path] -> do
            before <- try (ByteString.readFile path) :: IO (Either IOException ByteString.ByteString)
            parsed <- try (runGhc (Just libdir) $ do
              session <- getSession
              flags <- getSessionDynFlags
              iface <- liftIO (readBinIface (targetProfile flags) (hsc_NC session)
                CheckHiWay QuietBinIFace path)
              pure (Text.pack (moduleNameString (moduleName (mi_module iface))),
                Text.pack (unitIdString (moduleUnitId (mi_module iface))),
                Set.fromList [Text.pack (occNameString (nameOccName name))
                  | exported <- mi_exports iface, name <- availNames exported]))
              :: IO (Either SomeException (Text, Text, Set.Set Text))
            after <- try (ByteString.readFile path) :: IO (Either IOException ByteString.ByteString)
            pure $ case (before, parsed, after) of
              (Right first, Right ("Prelude", observedUnit, names), Right lastBytes)
                | first == lastBytes && observedUnit == unit && not (Set.null names) ->
                    Right (unit, names, Text.intercalate "\t"
                      ["graph-prelude-interface", unit, digest first, Text.pack (show (Set.size names))])
              _ -> Left (LayoutFinding "PreludeInterfaceInvalid" path)
          _ -> pure (Left (LayoutFinding "PreludeInterfaceMissing" (Text.unpack unit)))
    _ -> pure (Left (LayoutFinding "PreludeUnitMetadataMissing" (Text.unpack unit)))

-- | Resolve the external modules actually imported by parsed source against
-- the selected unit's compiler interface. A registered module name alone does
-- not prove that a particular value is exported.
loadExternalInterfaces :: PackageCatalog -> [(Text, Text)]
  -> IO (Either LayoutFinding (PackageCatalog, [Text]))
loadExternalInterfaces catalog requests = case catalogLibdir catalog of
  Nothing -> pure (Right (catalog, []))
  Just libdir -> do
    located <- mapM locate (Set.toAscList (Set.fromList requests))
    case sequence located of
      Left problem -> pure (Left problem)
      Right paths -> do
        loaded <- runGhc (Just libdir) $ do
          session <- getSession
          flags <- getSessionDynFlags
          liftIO $ mapM (readOne (targetProfile flags) (hsc_NC session)) paths
        pure $ do
          interfaces <- sequence loaded
          let exported = Map.fromList [(key, names) | (key, names, _, _) <- interfaces]
              members = Map.fromListWith Set.union
                [(key, names) | (_, _, entries, _) <- interfaces, (key, names) <- entries]
          Right (catalog {catalogModuleExports = exported, catalogModuleMembers = members},
            concat [rows | (_, _, _, rows) <- interfaces])
 where
  locate (unit, name) = do
    found <- locateFrom Set.empty (unit, name)
    pure (fmap (\(originUnit, originName, originPackage, path) ->
      (unit, name, originUnit, originName, originPackage, path)) found)
  locateFrom visited (unit, name)
    | (unit, name) `Set.member` visited =
        pure (Left (LayoutFinding "PackageModuleReexportCycle" (Text.unpack unit <> ":" <> Text.unpack name)))
    | otherwise = case Map.lookup unit (catalogRegistered catalog) of
        Nothing -> pure (Left (LayoutFinding "PackageModuleUnitMissing" (Text.unpack unit)))
        Just record -> case Map.lookup name (registeredReexports record) of
          Just origin -> locateFrom (Set.insert (unit, name) visited) origin
          Nothing -> do
            let relative = Text.unpack (Text.replace "." "/" name) <> ".hi"
            paths <- filterM doesFileExist [directory </> relative | directory <- registeredDirs record]
            pure $ case nub paths of
              [path] -> Right (unit, name, registeredPackage record, path)
              _ -> Left (LayoutFinding "PackageModuleInterfaceMissing" (Text.unpack unit <> ":" <> Text.unpack name))
  readOne profile nc (unit, name, originUnit, originName, originPackage, path) = do
    result <- try @SomeException $ do
      before <- ByteString.readFile path
      iface <- readBinIface profile nc CheckHiWay QuietBinIFace path
      after <- ByteString.readFile path
      pure (before, iface, after)
    pure $ case result of
      Right (before, iface, after)
        | before == after
        , Text.pack (moduleNameString (moduleName (mi_module iface))) == originName
        , Text.pack (unitIdString (moduleUnitId (mi_module iface))) `elem` [originUnit, originPackage] ->
            let names = Set.fromList
                  [Text.pack (occNameString (nameOccName exportedName))
                  | exported <- mi_exports iface, exportedName <- availNames exported]
                members = [((unit, name, Text.pack (occNameString (nameOccName parent))),
                    Set.fromList [Text.pack (occNameString (nameOccName child))
                      | child <- children, child /= parent])
                  | AvailTC parent children <- mi_exports iface]
                rows = Text.intercalate "\t"
                    ["graph-module-interface", unit, name, digest before,
                     Text.pack (show (Set.size names))]
                  : [Text.intercalate "\t" ["graph-module-interface-member", memberUnit,
                       memberModule, parent, child]
                    | ((memberUnit, memberModule, parent), children) <- members
                    , child <- Set.toAscList children]
            in Right ((unit, name), names, members, rows)
      Right (before, iface, after) -> Left (LayoutFinding "PackageModuleInterfaceInvalid"
        (path <> ":" <> show (before == after) <> ":"
          <> moduleNameString (moduleName (mi_module iface)) <> ":"
          <> unitIdString (moduleUnitId (mi_module iface))))
      Left problem -> Left (LayoutFinding "PackageModuleInterfaceUnreadable"
        (path <> ":" <> displayException problem))

digest :: ByteString.ByteString -> Text
digest bytes = Text.pack (concatMap hexByte (ByteString.unpack (SHA256.hash bytes)))
 where
  hexByte byte =
    let digits = "0123456789abcdef"
        value = fromIntegral byte :: Int
    in [digits !! (value `div` 16), digits !! (value `mod` 16)]
