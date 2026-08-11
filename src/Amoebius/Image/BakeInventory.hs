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
  ) where

import Amoebius.Image.BuildAdmission
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
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Dhall.FromDhall, NFData)

data BuiltProduct = BuiltProduct
  { name :: Text
  , targetPath :: Text
  , arguments :: [Text]
  , expectedVersion :: Text
  , kind :: BinaryKind
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Dhall.FromDhall, NFData)

data BakeStep = CopyOci OciCopy | BuildProduct BuiltProduct
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Dhall.FromDhall, NFData)

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
  , baseDigest :: Text
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
  | CatalogVersionProbeEmpty Text
  | CatalogDockerTokenInvalid Text
  | CatalogEnvironmentNameInvalid Text
  | CatalogEnvironmentNameDuplicate Text
  | CatalogEnvironmentValueInvalid Text
  | CatalogForbiddenPayloadPresent Text
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
    CopyOci source -> (source.name, Text.unpack source.targetPath, source.arguments, source.expectedVersion, source.kind)
    BuildProduct built -> (built.name, Text.unpack built.targetPath, built.arguments, built.expectedVersion, built.kind)

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
        CopyOci source -> (source.name, source.targetPath, source.arguments, source.expectedVersion)
        BuildProduct built -> (built.name, built.targetPath, built.arguments, built.expectedVersion)
  if isAbsolute (Text.unpack destination)
    then Right ()
    else Left (CatalogPathNotAbsolute destination)
  if null versionArguments || Text.null version
    then Left (CatalogVersionProbeEmpty binaryName)
    else Right ()
  case step of
    CopyOci source -> do
      validateDockerToken source.name
      validateDockerToken source.sourceImage
      validateDockerToken source.sourcePath
      validateDockerToken source.targetPath
      if validDigest source.sourceDigest
        then Right ()
        else Left (CatalogSourceDigestInvalid source.sourceDigest)
      mapM_ validateSupportCopy source.supportCopies
    BuildProduct _ -> Right ()
 where
  validateSupportCopy support =
    if isAbsolute (Text.unpack support.sourcePath)
        && isAbsolute (Text.unpack support.targetPath)
      then validateDockerToken support.sourcePath >> validateDockerToken support.targetPath
      else Left (CatalogPathNotAbsolute support.targetPath)

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
        CopyOci source -> [source.name, source.sourcePath, source.targetPath]
        BuildProduct built -> [built.name, built.targetPath]
   in any (isInfixOf lowered . Text.unpack . Text.toLower) fields

validDigest :: Text -> Bool
validDigest value =
  Text.length value == 71
    && "sha256:" `Text.isPrefixOf` value
    && Text.all (`elem` ("0123456789abcdef" :: String)) (Text.drop 7 value)

stepName :: BakeStep -> Text
stepName step = case step of
  CopyOci source -> source.name
  BuildProduct built -> built.name

duplicate :: Ord value => [value] -> Maybe value
duplicate = go Set.empty
 where
  go _ [] = Nothing
  go seen (value : rest)
    | value `Set.member` seen = Just value
    | otherwise = go (Set.insert value seen) rest
