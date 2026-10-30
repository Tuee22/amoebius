{-# LANGUAGE OverloadedStrings #-}

-- | Dynamic resolution and pure ensure planning (phase_01, Sprints 1.5 and 1.6).
--
-- Compatibility requirements are Haskell values that name no resolved path,
-- package checksum, or solver graph. The resolver elaborates a plan for them
-- with an acquired package tool, offline and serially, and writes the selected
-- graph and any materialised tool only beneath @.build/**@. The ensure planner is
-- pure: it reads an injected inventory and catalogue, never a host, and refuses
-- an absent tool, an out-of-range version, or a platform without an asset
-- instead of substituting.
module Amoebius.Toolchain.Resolve
  ( Asset (..)
  , Catalogue (..)
  , Inventory (..)
  , Plan (..)
  , PlanRefusal (..)
  , PlanRemedy (..)
  , Requirement (..)
  , ResolveRefusal (..)
  , SourceKind (..)
  , Step (..)
  , Tool (..)
  , admitGeneratedRoot
  , authoredPaths
  , elaborate
  , elaborateProbe
  , floorTools
  , installTool
  , inspectTrackedArtefacts
  , planAgreement
  , planEnsure
  , planRefusalRemedy
  , probeCatalogue
  , probeRequirements
  , refuseTrackedArtefacts
  , refuseTrackedSources
  , renderPlanRefusal
  , renderPlanRemedy
  , renderRequirement
  , renderResolveRefusal
  , renderStep
  , renderVersion
  ) where

import Amoebius.Build.Serial (BuildObservation (..), copyToolExecutable, spawnCabal, spawnToolInstall)
import Amoebius.Toolchain.Acquire (Acquisition (..), ChildRecord (..), sha256Bytes)
import Amoebius.Toolchain.Versions (Platform (..), renderPlatform, examplePlatform)
import Amoebius.Toolchain.Probe (ProbeCase (..), probeCases, probeSourcePaths)
import Control.Monad (filterM)
import Data.Aeson (FromJSON (..), eitherDecodeStrict, withObject, (.:))
import Data.ByteString qualified as ByteString
import Data.Char (isAlphaNum, isSpace)
import Data.List (isPrefixOf, isSuffixOf, sort, sortOn)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Text.IO qualified as TextIO
import System.Directory (canonicalizePath, createDirectoryIfMissing, doesDirectoryExist, doesFileExist, doesPathExist, findExecutable, getCurrentDirectory, listDirectory)
import System.FilePath (isAbsolute, makeRelative, normalise, splitDirectories, takeExtension, takeFileName, (</>))

-- * Compatibility requirements and elaboration

-- | A package the probe set needs, with its authored version window. No
-- resolved version, checksum, or path appears here.
data Requirement = Requirement
  { requirementPackage :: Text
  , requirementLower :: Text
  , requirementUpper :: Text
  }
  deriving (Eq, Ord, Show)

renderRequirement :: Requirement -> Text
renderRequirement requirement = requirementPackage requirement <> " >=" <> requirementLower requirement <> " && <" <> requirementUpper requirement

-- | The retained probe set: the decoder, the simulator, the codegen runtime,
-- the browser-contract generator, and the archive libraries the jit-build
-- resolver uses.
probeRequirements :: [Requirement]
probeRequirements =
  [ Requirement "dhall" "1.42" "1.43"
  , Requirement "io-sim" "1.10" "1.11"
  , Requirement "io-classes" "1.10" "1.11"
  , Requirement "proto-lens" "0.7" "0.8"
  , Requirement "proto-lens-runtime" "0.7" "0.8"
  , Requirement "purescript-bridge" "0.15" "0.16"
  , Requirement "tar" "0.6" "0.8"
  , Requirement "zlib" "0.7" "0.8"
  ]

data ResolveRefusal
  = ElaborationFailed Text
  | MissingDependency Text
  | PlanAbsent FilePath
  | ToolInstallFailed Text Text
  | TrackedResolutionOutput FilePath
  | DeveloperHomePath FilePath
  | TrackedProbeInput FilePath
  | TrackedPackagePin FilePath
  | MissingCompatibilityAllowance Text
  | PlansDisagree Text
  | ResolutionRootOutsideBuild FilePath
  | ResolutionRootNotAbsent FilePath
  deriving (Eq, Ord, Show)

renderResolveRefusal :: ResolveRefusal -> Text
renderResolveRefusal refusal = case refusal of
  ElaborationFailed detail -> "ElaborationFailed: " <> detail
  MissingDependency package -> "MissingDependency: " <> package
  PlanAbsent path -> "PlanAbsent: " <> Text.pack path
  ToolInstallFailed tool detail -> "ToolInstallFailed: " <> tool <> " " <> detail
  TrackedResolutionOutput path -> "TrackedResolutionOutput: " <> Text.pack path
  DeveloperHomePath path -> "DeveloperHomePath: " <> Text.pack path
  TrackedProbeInput path -> "TrackedProbeInput: " <> Text.pack path
  TrackedPackagePin path -> "TrackedPackagePin: " <> Text.pack path
  MissingCompatibilityAllowance package -> "MissingCompatibilityAllowance: " <> package
  PlansDisagree field -> "PlansDisagree: " <> field
  ResolutionRootOutsideBuild path -> "ResolutionRootOutsideBuild: " <> Text.pack path
  ResolutionRootNotAbsent path -> "ResolutionRootNotAbsent: " <> Text.pack path

-- | The elaborated plan: every unit the solver selected, sorted, and one digest
-- over them. Two observations of the same compatible tools must elaborate the same plan.
data Plan = Plan
  { planUnits :: [Text]
  , planPackages :: [Text]
  , planDigest :: Text
  }
  deriving (Eq, Show)

data PlanUnit = PlanUnit
  { unitId :: Text
  , unitPackage :: Text
  }

instance FromJSON PlanUnit where
  parseJSON = withObject "unit" (\object -> PlanUnit <$> object .: "id" <*> object .: "pkg-name")

newtype PlanFile = PlanFile [PlanUnit]

instance FromJSON PlanFile where
  parseJSON = withObject "plan" (\object -> PlanFile <$> object .: "install-plan")

-- | Agreement is derived from complete actual solver observations, rather
-- than from a caller-supplied success flag or only one cached digest.
planAgreement :: Plan -> Plan -> [ResolveRefusal]
planAgreement first second =
  [PlansDisagree field | (field, same) <-
    [("units", planUnits first == planUnits second)
    ,("packages", planPackages first == planPackages second)
    ,("digest", planDigest first == planDigest second)], not same]

-- | Resolve the dependency closure of the probes the product actually runs.
-- Version windows remain authored solver inputs: this checks dependency
-- presence, not equality to a frozen compatibility declaration.
elaborateProbe :: Acquisition -> FilePath -> [Requirement] -> IO (Either ResolveRefusal (Plan, ChildRecord))
elaborateProbe acquisition root requirements = case missing of
  package : _ -> pure (Left (MissingCompatibilityAllowance package))
  [] -> elaborate acquisition root requirements
 where
  supplied = map requirementPackage requirements
  missing = [package | package <- concatMap dependencies probeCases <> ["tar", "zlib"], package `notElem` supplied]
  dependencies value = case value of
    PositiveDecode -> ["dhall"]
    MistypedDecode -> ["dhall"]
    CleanSimulation -> ["io-sim", "io-classes"]
    PerturbedSimulation -> ["io-sim", "io-classes"]
    RuntimeEncoding -> ["proto-lens", "proto-lens-runtime"]
    BrowserContract -> ["purescript-bridge"]

-- | Render the probe package the requirements describe beneath the directory.
renderProbePackage :: FilePath -> [Requirement] -> IO ()
renderProbePackage directory requirements = do
  createDirectoryIfMissing True directory
  TextIO.writeFile
    (directory </> "probe-plan.cabal")
    ( Text.unlines
        ( [ "cabal-version: 3.0"
          , "name: probe-plan"
          , "version: 0.1.0.0"
          , "build-type: Simple"
          , ""
          , "executable probe-plan"
          , "    main-is: Main.hs"
          , "    default-language: GHC2024"
          , "    build-depends:"
          , "        base >=4.21 && <4.22,"
          ]
            <> [ "        " <> renderRequirement requirement <> (if index == length requirements then "" else ",")
               | (index, requirement) <- zip [1 :: Int ..] requirements
               ]
        )
    )
  TextIO.writeFile (directory </> "Main.hs") "main :: IO ()\nmain = pure ()\n"
  -- The rendered package is its own project, so an enclosing project file never
  -- captures the elaboration.
  TextIO.writeFile (directory </> "cabal.project") "packages: .\n"

-- | Elaborate the plan for the requirements with the acquisition's package tool
-- and compiler, offline and serially, beneath the given root.
elaborate :: Acquisition -> FilePath -> [Requirement] -> IO (Either ResolveRefusal (Plan, ChildRecord))
elaborate acquisition root requirements = do
  admitted <- admitGeneratedRoot root
  case admitted of
    Left problem -> pure (Left problem)
    Right output -> elaborateAt acquisition output requirements

-- | Admit a fresh output beneath the physical source frame's @.build@. Existing
-- ancestor symlinks are resolved before any directory, generated byte, or child
-- is created, so an ignored spelling cannot redirect output into authored source.
admitGeneratedRoot :: FilePath -> IO (Either ResolveRefusal FilePath)
admitGeneratedRoot requested = do
  frame <- getCurrentDirectory >>= canonicalizePath
  build <- canonicalizePath (frame </> ".build")
  output <- canonicalizePath requested
  occupied <- doesPathExist output
  let relative = makeRelative build output
      contained = relative /= "." && not (isAbsolute relative)
        && case splitDirectories relative of ".." : _ -> False; [] -> False; _ -> True
  pure $ if build /= normalise (frame </> ".build") || not contained
    then Left (ResolutionRootOutsideBuild requested)
    else if occupied then Left (ResolutionRootNotAbsent requested)
    else Right output

elaborateAt :: Acquisition -> FilePath -> [Requirement] -> IO (Either ResolveRefusal (Plan, ChildRecord))
elaborateAt acquisition root requirements = do
  let package = root </> "probe-plan"
      builddir = root </> "dist"
  renderProbePackage package requirements
  (transport, _, err) <- spawnCabal package (acquisitionPackageTool acquisition) (acquisitionCompiler acquisition) ["build", "--dry-run", "--offline", "--jobs=1", "-v0", "--with-compiler=" <> acquisitionCompiler acquisition, "--builddir=" <> builddir]
  let child = buildEffectiveChild transport
  if childExit child /= 0
    then pure (Left (classify (Text.pack err)))
    else do
      let planPath = builddir </> "cache" </> "plan.json"
      present <- doesFileExist planPath
      if not present
        then pure (Left (PlanAbsent planPath))
        else do
          bytes <- ByteString.readFile planPath
          pure $ case eitherDecodeStrict bytes of
            Left problem -> Left (ElaborationFailed (Text.pack problem))
            Right (PlanFile units) ->
              let ids = sort (map unitId units)
               in Right (Plan {planUnits = ids, planPackages = sort (unique (map unitPackage units)), planDigest = sha256Bytes (TextEncoding.encodeUtf8 (Text.unlines ids))}, child)
 where
  classify err = case [Text.takeWhile (\c -> c /= ' ' && c /= '\n') (Text.drop (Text.length "unknown package: ") rest) | (_, rest) <- [Text.breakOn "unknown package: " err], not (Text.null rest)] of
    (package : _) | not (Text.null package) -> MissingDependency package
    _ -> ElaborationFailed (Text.strip (Text.take 200 err))
  unique = foldr (\item seen -> if item `elem` seen then seen else item : seen) []

-- | Materialise one executable package beneath the tools directory with the
-- acquisition's package tool, offline. Native repository and package-database
-- inputs are read only; configuration, compilation and installation are owned.
installTool :: Acquisition -> FilePath -> Text -> Text -> IO (Either ResolveRefusal (FilePath, Maybe ChildRecord))
installTool acquisition tools package executable = do
  admitted <- admitGeneratedRoot tools
  case admitted of
    Left problem -> pure (Left problem)
    Right output -> installToolAt acquisition output package executable

installToolAt :: Acquisition -> FilePath -> Text -> Text -> IO (Either ResolveRefusal (FilePath, Maybe ChildRecord))
installToolAt acquisition tools package executable = do
  createDirectoryIfMissing True tools
  available <- findExecutable (Text.unpack executable)
  let path = tools </> Text.unpack executable
  case available of
    Just source -> copyToolExecutable source path >> pure (Right (path, Nothing))
    Nothing -> do
      -- Cabal's no-project selector is package:executable. Force the target
      -- package to source so an installed library cannot satisfy this request
      -- without building its executable; other native dependencies stay reusable.
      installed <- spawnToolInstall tools (acquisitionPackageTool acquisition) (acquisitionCompiler acquisition) (acquisitionCompilerVersion acquisition) package executable ["install", "--ignore-project", Text.unpack (package <> ":" <> executable), "--constraint=" <> Text.unpack package <> " source", "--installdir=" <> tools, "--install-method=copy", "--overwrite-policy=always", "--offline", "--jobs=1", "-v0", "--with-compiler=" <> acquisitionCompiler acquisition]
      case installed of
        Left problem -> pure (Left (ToolInstallFailed package problem))
        Right (transport, _, err) -> do
          let child = buildEffectiveChild transport
          present <- doesFileExist path
          pure (if childExit child == 0 && present then Right (path, Just child) else Left (ToolInstallFailed package (Text.strip (Text.take 200 (Text.pack err)))))

-- * Tracked-artefact refusals

-- | The authored tree: every file beneath the root except the generated,
-- version-control, and contained-state roots.
authoredPaths :: FilePath -> IO [FilePath]
authoredPaths root = map (makeRelative root) <$> walk root
 where
  excluded = [".build", ".git", "dist-newstyle", ".data", ".test_data"]
  walk directory = do
    names <- listDirectory directory
    let kept = [name | name <- names, name `notElem` excluded]
    directories <- filterM (doesDirectoryExist . (directory </>)) kept
    nested <- concat <$> mapM (walk . (directory </>)) directories
    pure ([directory </> name | name <- kept, name `notElem` directories] <> nested)

-- | A resolution output, a developer-home path, or a foreign probe input in the
-- authored tree is refused by name.
refuseTrackedArtefacts :: [FilePath] -> [ResolveRefusal]
refuseTrackedArtefacts paths =
  concat
    [ [TrackedResolutionOutput path | any (`isSuffixOf` path) [".freeze", ".lock", "plan.json", "package-lock.json"] || "dist-newstyle/" `isPrefixOf` path]
        <> [DeveloperHomePath path | "/home/" `isPrefixOf` path || "/Users/" `isPrefixOf` path]
        <> [TrackedProbeInput path | any (`isSuffixOf` path) [".dhall", ".proto", ".purs"]
          || (path `elem` probeSourcePaths paths && takeExtension path /= ".hs" && path /= "probe/probe.cabal")]
        <> [TrackedPackagePin path | takeFileName path `elem` ["package.pin", "package.pins", "package-pins"]]
    | path <- paths
    ]

-- | Inspect authored resolution metadata, including references whose path is
-- contained in the file rather than its name. Ordinary component dependency
-- windows in @.cabal@ files are source requirements, not solver-output pins.
refuseTrackedSources :: [(FilePath, Text)] -> [ResolveRefusal]
refuseTrackedSources sources = refuseTrackedArtefacts (map fst sources) <>
  concat [ [TrackedPackagePin path | resolutionMetadata path, pinnedConstraints (Text.lines contents)]
    <> [DeveloperHomePath path | resolutionMetadata path, any (`Text.isInfixOf` contents) ["/home/", "/Users/", "~/"]]
    | (path, contents) <- sources]
 where
  pinnedConstraints = go False
  go _ [] = False
  go active (line : rest)
    | Text.null stripped = go active rest
    | constraintField = "==" `Text.isInfixOf` Text.drop 1 value || go True rest
    | active && indented && not anotherField = "==" `Text.isInfixOf` stripped || go True rest
    | otherwise = go False rest
   where
    stripped = Text.strip (fst (Text.breakOn "--" line))
    (field, value) = Text.breakOn ":" stripped
    fieldName = Text.toLower (Text.strip field)
    constraintField = not (Text.null value) && fieldName `elem` ["constraints", "constraint"]
    anotherField = not (Text.null value) && not (Text.null fieldName)
      && Text.all (\character -> isAlphaNum character || character == '-') fieldName
    indented = maybe False (isSpace . fst) (Text.uncons line)

resolutionMetadata :: FilePath -> Bool
resolutionMetadata path = "cabal.project" `isPrefixOf` takeFileName path
  || takeFileName path `elem` ["package.pin", "package.pins", "package-pins"]
  || any (`isSuffixOf` path) [".freeze", ".lock"]

inspectTrackedArtefacts :: FilePath -> IO [ResolveRefusal]
inspectTrackedArtefacts root = do
  paths <- authoredPaths root
  sources <- mapM (\path -> (path,) <$> TextIO.readFile (root </> path)) (filter resolutionMetadata paths)
  pure (refuseTrackedArtefacts [path | path <- paths, not (resolutionMetadata path)] <> refuseTrackedSources sources)

-- * The pure ensure planner

-- | Where a tool comes from: a versioned release, or another resolved tool. There
-- is no host source kind.
data SourceKind
  = Versioned
  | Managed
  deriving (Eq, Ord, Show)

-- | A required tool with its authored version window (inclusive lower bound,
-- exclusive upper bound).
data Tool = Tool
  { toolRequired :: Text
  , toolMinimum :: [Int]
  , toolBelow :: [Int]
  }
  deriving (Eq, Ord, Show)

-- | What an injected inventory already holds.
newtype Inventory = Inventory {inventoryTools :: [(Text, [Int])]}
  deriving (Eq, Show)

-- | One installable asset in the supplied provider catalogue.
data Asset = Asset
  { assetTool :: Text
  , assetVersion :: [Int]
  , assetPlatform :: Platform
  , assetKind :: SourceKind
  , assetInstaller :: Text
  }
  deriving (Eq, Ord, Show)

newtype Catalogue = Catalogue {catalogueAssets :: [Asset]}
  deriving (Eq, Show)

data Step
  = Present Text [Int]
  | Ensure Text [Int] SourceKind Text
  deriving (Eq, Ord, Show)

data PlanRemedy
  = SupplyCompatibleAsset Tool
  | ReplaceIncompatibleVersion Tool
  | SupplyPlatformAsset Tool Platform
  deriving (Eq, Ord, Show)

data PlanRefusal
  = AbsentTool Text PlanRemedy
  | OutOfRangeVersion Text [Int] PlanRemedy
  | NoPlatformAsset Text Platform PlanRemedy
  deriving (Eq, Ord, Show)

renderVersion :: [Int] -> Text
renderVersion = Text.intercalate "." . map (Text.pack . show)

renderStep :: Step -> Text
renderStep step = case step of
  Present tool version -> "present " <> tool <> " " <> renderVersion version
  Ensure tool version kind installer -> "ensure " <> tool <> " " <> renderVersion version <> " " <> renderKind kind <> " via " <> installer
 where
  renderKind kind = case kind of
    Versioned -> "versioned"
    Managed -> "managed"

renderPlanRefusal :: PlanRefusal -> Text
renderPlanRefusal refusal = reason <> "; remedy: " <> renderPlanRemedy (planRefusalRemedy refusal)
 where
  reason = case refusal of
    AbsentTool tool _ -> "AbsentTool: " <> tool
    OutOfRangeVersion tool version _ -> "OutOfRangeVersion: " <> tool <> " " <> renderVersion version
    NoPlatformAsset tool target _ -> "NoPlatformAsset: " <> tool <> " " <> renderPlatform target

planRefusalRemedy :: PlanRefusal -> PlanRemedy
planRefusalRemedy refusal = case refusal of
  AbsentTool _ remedy -> remedy
  OutOfRangeVersion _ _ remedy -> remedy
  NoPlatformAsset _ _ remedy -> remedy

renderPlanRemedy :: PlanRemedy -> Text
renderPlanRemedy remedy = case remedy of
  SupplyCompatibleAsset tool -> "supply catalogue asset for " <> toolRequired tool <> " " <> window tool
  ReplaceIncompatibleVersion tool -> "replace inventory version of " <> toolRequired tool <> " with " <> window tool
  SupplyPlatformAsset tool platform -> "supply catalogue asset for " <> toolRequired tool <> " " <> window tool <> " on " <> renderPlatform platform
 where
  window tool = ">=" <> renderVersion (toolMinimum tool) <> " && <" <> renderVersion (toolBelow tool)

-- | The floor the probe set needs.
floorTools :: [Tool]
floorTools =
  [ Tool "ghc" [9, 12, 4] [9, 13]
  , Tool "cabal-install" [3, 16] [3, 17]
  , Tool "proto-lens-protoc" [0, 9] [0, 10]
  , Tool "protoc" [3] [100]
  ]

-- | A supplied abstract planner fixture; it never reads or constrains the host.
probeCatalogue :: Catalogue
probeCatalogue = Catalogue
  [ Asset "ghc" [9, 12, 4] examplePlatform Versioned "ghcup"
  , Asset "cabal-install" [3, 16, 1, 0] examplePlatform Managed "ghcup"
  , Asset "proto-lens-protoc" [0, 9, 0, 1] examplePlatform Managed "cabal-install"
  , Asset "protoc" [3, 21, 12] examplePlatform Managed "package-manager"
  ]

inRange :: Tool -> [Int] -> Bool
inRange tool version = version >= toolMinimum tool && version < toolBelow tool

-- | Plan the floor over an injected inventory and catalogue. Every refusal is
-- reported; no foreign asset is ever selected in place of a missing one.
planEnsure :: Platform -> Inventory -> Catalogue -> [Tool] -> Either [PlanRefusal] [Step]
planEnsure target inventory catalogue tools = case concat [either pure (const []) (planOne tool) | tool <- tools] of
  [] -> Right [step | tool <- tools, Right step <- [planOne tool]]
  refusals -> Left refusals
 where
  planOne tool = case lookup (toolRequired tool) (inventoryTools inventory) of
    Just version
      | inRange tool version -> Right (Present (toolRequired tool) version)
      | otherwise -> Left (OutOfRangeVersion (toolRequired tool) version (ReplaceIncompatibleVersion tool))
    Nothing ->
      let candidates = [asset | asset <- catalogueAssets catalogue, assetTool asset == toolRequired tool, inRange tool (assetVersion asset)]
          here = [asset | asset <- candidates, assetPlatform asset == target]
       in case sortOn (negate . length . assetVersion) (sortOn assetVersion here) of
            [] | null candidates -> Left (AbsentTool (toolRequired tool) (SupplyCompatibleAsset tool))
            [] -> Left (NoPlatformAsset (toolRequired tool) target (SupplyPlatformAsset tool target))
            chosen -> let best = last (sortOn assetVersion chosen) in Right (Ensure (assetTool best) (assetVersion best) (assetKind best) (assetInstaller best))
