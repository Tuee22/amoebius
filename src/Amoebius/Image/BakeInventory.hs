{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Image.BakeInventory
  ( Platform (..)
  , BinaryKind (..)
  , SupportCopy (..)
  , RuntimeEnvironment (..)
  , OciCopy (..)
  , BuiltProduct (..)
  , AptPackaged (..)
  , ArtifactAsset (..)
  , ChecksumAlgorithm (..)
  , ChecksumShape (..)
  , ArchiveFormat (..)
  , PublishedPayload (..)
  , PublishedArtifact (..)
  , AcquisitionTool (..)
  , GoBuild (..)
  , PythonDistribution (..)
  , AmoebiusBinary (..)
  , BuildSource (..)
  , buildSourceIdentity
  , BakeStep (..)
  , NonEmptyBakeSteps (..)
  , BakeStage (..)
  , BakeCatalog (..)
  , CatalogError (..)
  , decodeBakeCatalog
  , validateBakeCatalog
  , catalogSteps
  , catalogInventory
  , catalogBuildEnvelope
  , stepRung
  , stepName
  , stepLastResortReason
  , stepSourceImage
  ) where

import Amoebius.Image.BuildAdmission
import Amoebius.Image.BaseChannel (mkBaseChannel)
import Control.DeepSeq (NFData)
import Control.Exception (SomeException, displayException, try)
import Data.Char (isAlpha, isAlphaNum, isSpace)
import Data.List (isInfixOf)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Dhall qualified
import GHC.Generics (Generic)
import Numeric.Natural (Natural)
import System.FilePath (isAbsolute)

data Platform = Amd64 | Arm64
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Show)
  deriving anyclass (Dhall.FromDhall, NFData)

data BinaryKind = Elf | Launcher
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Show)
  deriving anyclass (Dhall.FromDhall, NFData)

data SupportCopy = SupportCopy
  { sourcePath :: Text
  , targetPath :: Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Dhall.FromDhall, NFData)

data RuntimeEnvironment = RuntimeEnvironment
  { name :: Text
  , value :: Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Dhall.FromDhall, NFData)

-- | The last rung, and the only one that takes a binary out of somebody else's
-- image. `lastResortReason` is a required field rather than an optional note:
-- image-build doctrine section 7 admits this arm only where the rungs above it do
-- not apply, and a reason nobody has to write is a reason nobody has to have.
data OciCopy = OciCopy
  { name :: Text
  , sourceImage :: Text
  , sourceDigest :: Text
  , sourcePath :: Text
  , targetPath :: Text
  , arguments :: [Text]
  , expectedVersion :: Text
  , kind :: BinaryKind
  , supportCopies :: [SupportCopy]
  , lastResortReason :: Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Dhall.FromDhall, NFData)

-- | Rung 1. The distribution ships the binary for both architectures, so the
-- acquisition is a package name and an exact version, and the archive suite is
-- recorded so a reviewer can check the same claim the author checked.
data AptPackaged = AptPackaged
  { name :: Text
  , package :: Text
  , packageVersion :: Text
  , archiveSuite :: Text
  , targetPath :: Text
  , arguments :: [Text]
  , expectedVersion :: Text
  , kind :: BinaryKind
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Dhall.FromDhall, NFData)

-- | One platform's asset and the manifest covering it. The manifest belongs to the
-- asset rather than to the release because publishers split both ways: MinIO and
-- Grafana ship a manifest per asset, Prometheus and HashiCorp ship one per release.
-- A single release-level field would have forced the per-asset publishers into a
-- shape they do not have.
data ArtifactAsset = ArtifactAsset
  { platform :: Platform
  , assetUrl :: Text
  , checksumManifest :: Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Dhall.FromDhall, NFData)

-- | Publishers do not agree on how they publish an integrity value, and the
-- disagreement is load-bearing: the nine artifacts this catalog acquires use three
-- digest algorithms and two manifest shapes between them. A single hard-coded
-- `sha256sum -c` would verify seven of them and quietly do nothing for the other
-- two, so the shape is data the catalog carries and the renderer reads.
data ChecksumAlgorithm = Sha1 | Sha256 | Sha512
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Show)
  deriving anyclass (Dhall.FromDhall, NFData)

-- | `DigestOnly` is a manifest whose entire body is the digest — Grafana and
-- Keycloak publish one file per asset that way. `DigestNamed` is a line-oriented
-- manifest naming what each digest covers; the name may be bare, `./`-prefixed, or
-- the publisher's own build path, so verification matches the trailing basename
-- rather than the whole field.
data ChecksumShape = DigestOnly | DigestNamed
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Show)
  deriving anyclass (Dhall.FromDhall, NFData)

-- | `Bare` is the executable itself, `TarGz` and `Zip` are archives it sits inside.
-- The third axis the publishers disagree on, and the one that decides whether the
-- rendered step is an `install`, a `tar`, or an `unzip`.
data ArchiveFormat = Bare | TarGz | Zip
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Show)
  deriving anyclass (Dhall.FromDhall, NFData)

-- | A publisher-signed companion archive required by an executable distribution.
-- It is acquired and verified on the same rung as its owning artifact, but is not
-- itself an executable inventory row. Pulsar's separately published offloader NARs
-- are the first instance: the broker binary is unusable for the Phase-31 S3
-- contract unless that payload is present beside it.
data PublishedPayload = PublishedPayload
  { name :: Text
  , assets :: [ArtifactAsset]
  , checksumAlgorithm :: ChecksumAlgorithm
  , checksumShape :: ChecksumShape
  , archiveFormat :: ArchiveFormat
  , archiveMember :: Text
  , targetPath :: Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Dhall.FromDhall, NFData)

-- | Rung 2. The publisher releases a multi-architecture artifact and a checksum
-- manifest covering it. The manifest is named; the checksum is not, and
-- `validateStep` refuses one that is — repository-layout doctrine section 4 makes
-- an integrity value resolver output, so it is resolved during the build and
-- recorded in the run bundle rather than frozen into an authored catalog.
data PublishedArtifact = PublishedArtifact
  { name :: Text
  , publisher :: Text
  , releaseVersion :: Text
  , assets :: [ArtifactAsset]
  , checksumAlgorithm :: ChecksumAlgorithm
  , checksumShape :: ChecksumShape
  , archiveFormat :: ArchiveFormat
  , archiveMember :: Text
  , targetPath :: Text
  , payloads :: [PublishedPayload]
  , arguments :: [Text]
  , expectedVersion :: Text
  , kind :: BinaryKind
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Dhall.FromDhall, NFData)

-- | Build-time acquisition tooling, and deliberately not a 'BakeStep'. Rung 2
-- fetches an asset and its publisher's manifest, which needs a TLS trust store,
-- an HTTP client, and an unzipper; none of the three is a platform-service
-- binary, so none belongs in the inventory the gate reconciles against the
-- standard-services oracle, and none has a rung the acquisition table ranks. The
-- alternative was a fixed list inside the renderer — the same dependency with
-- nowhere to review it.
data AcquisitionTool = AcquisitionTool
  { package :: Text
  , packageVersion :: Text
  , archiveSuite :: Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Dhall.FromDhall, NFData)

-- | An upstream Go module and the package inside it that becomes one binary.
-- @versionSymbol@ is empty where the project carries its own version in source;
-- where it does not, the linker stamp is catalog data rather than a flag
-- remembered by whatever ran the build.
data GoBuild = GoBuild
  { repository :: Text
  , reference :: Text
  , packagePath :: Text
  , versionSymbol :: Text
  , versionValue :: Text
  , requiresCgo :: Bool
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Dhall.FromDhall, NFData)

data PythonDistribution = PythonDistribution
  { distribution :: Text
  , distributionVersion :: Text
  , interpreterVersion :: Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Dhall.FromDhall, NFData)

newtype AmoebiusBinary = AmoebiusBinary {cabalTarget :: Text}
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Dhall.FromDhall, NFData)

-- | What rung 3 builds *from*. A step that named only what it produces would
-- leave five third-party source coordinates living in whichever script happened
-- to build them. No arm carries an integrity value: Go resolves one from the
-- module checksum database and pip from the index, both during the build.
data BuildSource
  = AmoebiusSource AmoebiusBinary
  | GoModule GoBuild
  | PythonPackage PythonDistribution
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Dhall.FromDhall, NFData)

-- | The identity a rung-3 step acquires from, in the same shape the other rungs
-- report: what it came from, and where its integrity value is resolved.
buildSourceIdentity :: BuildSource -> (Text, Text)
buildSourceIdentity source = case source of
  AmoebiusSource _ -> ("amoebius-source", "sha256:source-bound-at-build")
  GoModule go ->
    (go.repository <> "@" <> go.reference, "sha256:resolved-from-the-module-checksum-database-at-build")
  PythonPackage python ->
    ( "pypi:" <> python.distribution <> "==" <> python.distributionVersion
    , "sha256:resolved-from-the-package-index-at-build"
    )

data BuiltProduct = BuiltProduct
  { name :: Text
  , source :: BuildSource
  , targetPath :: Text
  , arguments :: [Text]
  , expectedVersion :: Text
  , kind :: BinaryKind
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Dhall.FromDhall, NFData)

-- | The acquisition ladder as a closed union, highest rung first. The ordering is
-- not decided here — `image_build_doctrine.md` section 7 orders it, and the gate
-- compares each step against an independently authored table — but making the
-- rungs *arms* is what lets the gate ask which one a binary sits on at all. A
-- preference expressed in prose cannot be read back out of a catalog.
data BakeStep
  = AptPackage AptPackaged
  | OfficialArtifact PublishedArtifact
  | BuildProduct BuiltProduct
  | CopyOci OciCopy
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Dhall.FromDhall, NFData)

stepRung :: BakeStep -> Text
stepRung step = case step of
  AptPackage _ -> "AptPackage"
  OfficialArtifact _ -> "OfficialArtifact"
  BuildProduct _ -> "BuildProduct"
  CopyOci _ -> "CopyOci"

-- | The scavenge reason, and Nothing for every rung that needs none.
stepLastResortReason :: BakeStep -> Maybe Text
stepLastResortReason step = case step of
  CopyOci source -> Just source.lastResortReason
  _ -> Nothing

stepSourceImage :: BakeStep -> Maybe Text
stepSourceImage step = case step of
  CopyOci source -> Just source.sourceImage
  _ -> Nothing

data NonEmptyBakeSteps = NonEmptyBakeSteps
  { head :: BakeStep
  , tail :: [BakeStep]
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Dhall.FromDhall, NFData)

data BakeStage = BakeStage
  { name :: Text
  , dependencies :: [Text]
  , platforms :: [Platform]
  , cpuReservationMillis :: Natural
  , cpuCeilingMillis :: Natural
  , memoryReservationBytes :: Natural
  , memoryCeilingBytes :: Natural
  , intermediateBytes :: Natural
  , cacheWriteBytes :: Natural
  , content :: NonEmptyBakeSteps
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Dhall.FromDhall, NFData)

data BakeCatalog = BakeCatalog
  { architectureConcurrency :: Natural
  , stageConcurrency :: Natural
  , scratchBacking :: Text
  , scratchCapacityBytes :: Natural
  , cacheBacking :: Text
  , cacheCapacityBytes :: Natural
  , baseImage :: Text
  , acquisitionTools :: [AcquisitionTool]
  , runtimeEnvironment :: [RuntimeEnvironment]
  , stages :: [BakeStage]
  , forbiddenPayloads :: [Text]
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Dhall.FromDhall, NFData)

data CatalogError
  = CatalogDecodeFailed Text
  | CatalogStageSetEmpty
  | CatalogStageNameDuplicate Text
  | CatalogPlatformSetIncomplete Text
  | CatalogBinaryNameDuplicate Text
  | CatalogPathNotAbsolute Text
  | CatalogSourceDigestInvalid Text
  | CatalogBaseChannelInvalid Text
  | CatalogVersionProbeEmpty Text
  | CatalogDockerTokenInvalid Text
  | CatalogEnvironmentNameInvalid Text
  | CatalogEnvironmentNameDuplicate Text
  | CatalogEnvironmentValueInvalid Text
  | CatalogForbiddenPayloadPresent Text
  | CatalogAptPackageIncomplete Text
  | CatalogArtifactReleaseIncomplete Text
  | CatalogArtifactAssetsIncomplete Text
  | CatalogArtifactIntegrityPinned Text
  | CatalogLastResortUnjustified Text
  | CatalogAcquisitionToolIncomplete Text
  | CatalogAcquisitionToolDuplicate Text
  | CatalogBuildSourceIncomplete Text
  | CatalogBuildEnvelopeInvalid BuildAdmissionError
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

decodeBakeCatalog :: FilePath -> IO (Either CatalogError BakeCatalog)
decodeBakeCatalog path = do
  decoded <- try (Dhall.inputFile Dhall.auto path)
  pure $ case decoded of
    Left problem -> Left (CatalogDecodeFailed (Text.pack (displayException (problem :: SomeException))))
    Right catalog -> Right catalog

validateBakeCatalog :: BakeCatalog -> Either CatalogError ()
validateBakeCatalog catalog = do
  case mkBaseChannel catalog.baseImage of
    Left _ -> Left (CatalogBaseChannelInvalid catalog.baseImage)
    Right _ -> Right ()
  if null (stages catalog) then Left CatalogStageSetEmpty else Right ()
  case duplicate (fmap (\stage -> stage.name) catalog.stages) of
    Just value -> Left (CatalogStageNameDuplicate value)
    Nothing -> Right ()
  mapM_ validatePlatforms catalog.stages
  let steps = catalogSteps catalog
      names = fmap stepName steps
  case duplicate names of
    Just value -> Left (CatalogBinaryNameDuplicate value)
    Nothing -> Right ()
  mapM_ validateStep steps
  case duplicate (fmap (\environment -> environment.name) catalog.runtimeEnvironment) of
    Just value -> Left (CatalogEnvironmentNameDuplicate value)
    Nothing -> Right ()
  mapM_ validateEnvironment catalog.runtimeEnvironment
  case duplicate (fmap (\tool -> tool.package) catalog.acquisitionTools) of
    Just value -> Left (CatalogAcquisitionToolDuplicate value)
    Nothing -> Right ()
  mapM_ validateAcquisitionTool catalog.acquisitionTools
  mapM_ (rejectForbidden steps) catalog.forbiddenPayloads
  case deriveBuildTransition (catalogBuildEnvelope catalog) 0 of
    Left problem -> Left (CatalogBuildEnvelopeInvalid problem)
    Right _ -> Right ()
 where
  validatePlatforms stage =
    if Set.fromList stage.platforms == Set.fromList [Amd64, Arm64]
      then Right ()
      else Left (CatalogPlatformSetIncomplete stage.name)

catalogSteps :: BakeCatalog -> [BakeStep]
catalogSteps catalog = concatMap stageSteps catalog.stages
 where
  stageSteps stage = let rows = stage.content in rows.head : rows.tail

catalogInventory :: BakeCatalog -> [(Text, FilePath, [Text], Text, BinaryKind)]
catalogInventory = fmap row . catalogSteps
 where
  row step = case step of
    AptPackage packaged -> (packaged.name, Text.unpack packaged.targetPath, packaged.arguments, packaged.expectedVersion, packaged.kind)
    OfficialArtifact artifact -> (artifact.name, Text.unpack artifact.targetPath, artifact.arguments, artifact.expectedVersion, artifact.kind)
    BuildProduct built -> (built.name, Text.unpack built.targetPath, built.arguments, built.expectedVersion, built.kind)
    CopyOci source -> (source.name, Text.unpack source.targetPath, source.arguments, source.expectedVersion, source.kind)

catalogBuildEnvelope :: BakeCatalog -> BuildExecutionEnvelope
catalogBuildEnvelope catalog =
  BuildExecutionEnvelope
    { buildStages = fmap toStage catalog.stages
    , buildArchitectureConcurrency = parallel catalog.architectureConcurrency
    , buildStageConcurrency = parallel catalog.stageConcurrency
    , buildScratchBacking = catalog.scratchBacking
    , buildScratchCapacityBytes = catalog.scratchCapacityBytes
    , buildCacheBacking = catalog.cacheBacking
    , buildCacheCapacityBytes = catalog.cacheCapacityBytes
    }
 where
  parallel 1 = Serial
  parallel value = BoundedParallel value
  toStage stage =
    BuildStageDemand
      { buildStageName = stage.name
      , buildStageDependencies = Set.fromList stage.dependencies
      , buildStageCpuReservationMillis = stage.cpuReservationMillis
      , buildStageCpuCeilingMillis = stage.cpuCeilingMillis
      , buildStageMemoryReservationBytes = stage.memoryReservationBytes
      , buildStageMemoryCeilingBytes = stage.memoryCeilingBytes
      , buildStageIntermediateBytes = stage.intermediateBytes
      , buildStageCacheWriteBytes = stage.cacheWriteBytes
      }

validateStep :: BakeStep -> Either CatalogError ()
validateStep step = do
  let (binaryName, destination, versionArguments, version) = case step of
        AptPackage packaged -> (packaged.name, packaged.targetPath, packaged.arguments, packaged.expectedVersion)
        OfficialArtifact artifact -> (artifact.name, artifact.targetPath, artifact.arguments, artifact.expectedVersion)
        BuildProduct built -> (built.name, built.targetPath, built.arguments, built.expectedVersion)
        CopyOci source -> (source.name, source.targetPath, source.arguments, source.expectedVersion)
  if isAbsolute (Text.unpack destination)
    then Right ()
    else Left (CatalogPathNotAbsolute destination)
  if null versionArguments || Text.null version
    then Left (CatalogVersionProbeEmpty binaryName)
    else Right ()
  case step of
    AptPackage packaged -> do
      validateDockerToken packaged.name
      validateDockerToken packaged.targetPath
      if Text.null (Text.strip packaged.package)
        || Text.null (Text.strip packaged.packageVersion)
        || Text.null (Text.strip packaged.archiveSuite)
        then Left (CatalogAptPackageIncomplete packaged.name)
        else Right ()
      validateDockerToken packaged.package
      validateDockerToken packaged.packageVersion
    OfficialArtifact artifact -> do
      validateDockerToken artifact.name
      validateDockerToken artifact.targetPath
      if Text.null (Text.strip artifact.publisher)
        || Text.null (Text.strip artifact.releaseVersion)
        || any (\asset -> Text.null (Text.strip asset.assetUrl) || Text.null (Text.strip asset.checksumManifest)) artifact.assets
        then Left (CatalogArtifactReleaseIncomplete artifact.name)
        else Right ()
      if Set.fromList (fmap (\asset -> asset.platform) artifact.assets) == Set.fromList [Amd64, Arm64]
        && length artifact.assets == 2
        then Right ()
        else Left (CatalogArtifactAssetsIncomplete artifact.name)
      -- The publisher's manifest is named; its contents are resolved during the
      -- build. A digest frozen here would be resolver output in an authored file.
      if any containsDigestLiteral
        ( artifact.publisher
            : artifact.releaseVersion
            : artifact.archiveMember
            : concatMap (\asset -> [asset.assetUrl, asset.checksumManifest]) artifact.assets
        )
        then Left (CatalogArtifactIntegrityPinned artifact.name)
        else Right ()
      mapM_ (validatePublishedPayload artifact.name) artifact.payloads
    BuildProduct produced -> do
      validateDockerToken produced.name
      validateDockerToken produced.targetPath
      case produced.source of
        AmoebiusSource target ->
          if Text.null (Text.strip target.cabalTarget)
            then Left (CatalogBuildSourceIncomplete produced.name)
            else Right ()
        GoModule go -> do
          if Text.null (Text.strip go.repository)
            || Text.null (Text.strip go.reference)
            || Text.null (Text.strip go.packagePath)
            then Left (CatalogBuildSourceIncomplete produced.name)
            else Right ()
          -- A value with nowhere to put it, or a symbol with nothing to put
          -- there, is a stamp that silently does nothing.
          if Text.null (Text.strip go.versionSymbol) /= Text.null (Text.strip go.versionValue)
            then Left (CatalogBuildSourceIncomplete produced.name)
            else Right ()
          if any containsDigestLiteral [go.repository, go.reference, go.packagePath]
            then Left (CatalogArtifactIntegrityPinned produced.name)
            else Right ()
        PythonPackage python ->
          if Text.null (Text.strip python.distribution)
            || Text.null (Text.strip python.distributionVersion)
            || Text.null (Text.strip python.interpreterVersion)
            then Left (CatalogBuildSourceIncomplete produced.name)
            else Right ()
    CopyOci source -> do
      validateDockerToken source.name
      validateDockerToken source.sourceImage
      validateDockerToken source.sourcePath
      validateDockerToken source.targetPath
      if validDigest source.sourceDigest
        then Right ()
        else Left (CatalogSourceDigestInvalid source.sourceDigest)
      if Text.null (Text.strip source.lastResortReason)
        then Left (CatalogLastResortUnjustified source.name)
        else Right ()
      mapM_ validateSupportCopy source.supportCopies
 where
  validateSupportCopy support =
    if isAbsolute (Text.unpack support.sourcePath)
        && isAbsolute (Text.unpack support.targetPath)
      then validateDockerToken support.sourcePath >> validateDockerToken support.targetPath
      else Left (CatalogPathNotAbsolute support.targetPath)

-- | An acquisition tool is pinned exactly like a rung-1 step, minus the parts a
-- rung-1 step has because it is a service binary: no target path, no probe, no
-- expected version. It installs or the layer fails.
validateAcquisitionTool :: AcquisitionTool -> Either CatalogError ()
validateAcquisitionTool tool = do
  if Text.null (Text.strip tool.package)
    || Text.null (Text.strip tool.packageVersion)
    || Text.null (Text.strip tool.archiveSuite)
    then Left (CatalogAcquisitionToolIncomplete tool.package)
    else Right ()
  validateDockerToken tool.package
  validateDockerToken tool.packageVersion

validateDockerToken :: Text -> Either CatalogError ()
validateDockerToken value =
  if Text.null value || Text.any (\character -> isSpace character || character `elem` ['"', '\\']) value
    then Left (CatalogDockerTokenInvalid value)
    else Right ()

validateEnvironment :: RuntimeEnvironment -> Either CatalogError ()
validateEnvironment environment = do
  let environmentName = Text.unpack environment.name
  case environmentName of
    first : rest
      | (isAlpha first || first == '_') && all (\character -> isAlphaNum character || character == '_') rest -> Right ()
    _ -> Left (CatalogEnvironmentNameInvalid environment.name)
  if Text.any (`elem` ['"', '\r', '\n']) environment.value
    then Left (CatalogEnvironmentValueInvalid environment.name)
    else Right ()

rejectForbidden :: [BakeStep] -> Text -> Either CatalogError ()
rejectForbidden steps forbidden =
  if any (containsForbidden forbidden) steps
    then Left (CatalogForbiddenPayloadPresent forbidden)
    else Right ()

containsForbidden :: Text -> BakeStep -> Bool
containsForbidden forbidden step =
  let lowered = Text.unpack (Text.toLower forbidden)
      fields = case step of
        AptPackage packaged -> [packaged.name, packaged.package, packaged.targetPath]
        OfficialArtifact artifact ->
          [artifact.name, artifact.publisher, artifact.targetPath]
            <> concatMap (\payload -> [payload.name, payload.targetPath]) artifact.payloads
        BuildProduct built -> [built.name, built.targetPath, fst (buildSourceIdentity built.source)]
        CopyOci source -> [source.name, source.sourcePath, source.targetPath]
   in any (isInfixOf lowered . Text.unpack . Text.toLower) fields

validatePublishedPayload :: Text -> PublishedPayload -> Either CatalogError ()
validatePublishedPayload owner payload = do
  validateDockerToken payload.name
  validateDockerToken payload.targetPath
  if isAbsolute (Text.unpack payload.targetPath)
    then Right ()
    else Left (CatalogPathNotAbsolute payload.targetPath)
  if Set.fromList (fmap (\asset -> asset.platform) payload.assets) == Set.fromList [Amd64, Arm64]
    && length payload.assets == 2
    then Right ()
    else Left (CatalogArtifactAssetsIncomplete (owner <> ":" <> payload.name))
  if any (\asset -> Text.null (Text.strip asset.assetUrl) || Text.null (Text.strip asset.checksumManifest)) payload.assets
    then Left (CatalogArtifactReleaseIncomplete (owner <> ":" <> payload.name))
    else Right ()
  if any containsDigestLiteral
    (payload.name : payload.archiveMember : concatMap (\asset -> [asset.assetUrl, asset.checksumManifest]) payload.assets)
    then Left (CatalogArtifactIntegrityPinned (owner <> ":" <> payload.name))
    else Right ()

-- | A 64-character hex run is an integrity value wherever it appears.
containsDigestLiteral :: Text -> Bool
containsDigestLiteral value =
  any (\window -> Text.length window == 64 && Text.all (`elem` ("0123456789abcdef" :: String)) window)
    (fmap (Text.take 64) (Text.tails (Text.toLower value)))

validDigest :: Text -> Bool
validDigest value =
  Text.length value == 71
    && "sha256:" `Text.isPrefixOf` value
    && Text.all (`elem` ("0123456789abcdef" :: String)) (Text.drop 7 value)

stepName :: BakeStep -> Text
stepName step = case step of
  AptPackage packaged -> packaged.name
  OfficialArtifact artifact -> artifact.name
  BuildProduct built -> built.name
  CopyOci source -> source.name

duplicate :: Ord value => [value] -> Maybe value
duplicate = go Set.empty
 where
  go _ [] = Nothing
  go seen (value : rest)
    | value `Set.member` seen = Just value
    | otherwise = go (Set.insert value seen) rest
