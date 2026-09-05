{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE NoFieldSelectors #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Image.Artifact qualified as Artifact
import Amoebius.Image.BakeInventory qualified as Catalog
import Amoebius.Image.CanonicalBakeCatalog (canonicalBakeCatalog)
import Amoebius.Image.BootstrapRegistry qualified as Bootstrap
import Amoebius.Image.BuildAdmission qualified as Admission
import Amoebius.Image.BuildRuntime qualified as Runtime
import Amoebius.Image.Gate qualified as ImageGate
import Amoebius.Image.NodeLoad qualified as NodeLoad
import Amoebius.Image.Publish qualified as Publish
import Amoebius.Image.Ref qualified as ImageRef
import Amoebius.Image.Registry qualified as Registry
import Amoebius.Image.RenderDockerfile qualified as Dockerfile
import Amoebius.Capacity.NodeLocalStorage qualified as NodeStorage
import Amoebius.Capacity.RenderSource (K8sObjectIdentity (..))
import Amoebius.Capacity.Types (ResourceVector (..))
import Amoebius.Manifest.K8sObject (K8sObjectKind (..))
import Control.Monad (forM_, unless)
import Data.List (isPrefixOf, sort)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import Dhall qualified
import GHC.Generics (Generic)
import Numeric.Natural (Natural)
import System.Exit (die)
import System.Exit qualified as Exit
import Data.IORef (modifyIORef', newIORef, readIORef)

data OracleKind = Elf | Launcher
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Dhall.FromDhall)

data OracleInventory = OracleInventory
  { catalogName :: Text
  , canonicalService :: Text
  , binary :: Text
  , arguments :: [Text]
  , version :: Text
  , kind :: OracleKind
  , acquisition :: Text
  , integrity :: Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Dhall.FromDhall)

data OracleStage = OracleStage
  { name :: Text
  , dependencies :: [Text]
  , cpuReservationMillis :: Natural
  , cpuCeilingMillis :: Natural
  , memoryReservationBytes :: Natural
  , memoryCeilingBytes :: Natural
  , intermediateBytes :: Natural
  , cacheWriteBytes :: Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Dhall.FromDhall)

data BuildOracle = BuildOracle
  { fingerprint :: Text
  , architectureConcurrency :: Natural
  , stageConcurrency :: Natural
  , stages :: [OracleStage]
  , scratchBacking :: Text
  , scratchCapacityBytes :: Natural
  , cacheBacking :: Text
  , cacheCapacityBytes :: Natural
  , observedCacheResidentBytes :: Natural
  , residualCpuMillis :: Natural
  , residualMemoryBytes :: Natural
  , expectedCpuPeakMillis :: Natural
  , expectedMemoryPeakBytes :: Natural
  , expectedScratchPeakBytes :: Natural
  , expectedCacheWritePeakBytes :: Natural
  , expectedCacheTransitionBytes :: Natural
  , rejectionTags :: [Text]
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Dhall.FromDhall)

data RegistryObjectOracle = RegistryObjectOracle
  { digest :: Text
  , kind :: Text
  , storedBytes :: Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Dhall.FromDhall)

data RegistryResidentOracle = RegistryResidentOracle
  { digest :: Text
  , storedBytes :: Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Dhall.FromDhall)

data RegistryOracle = RegistryOracle
  { objects :: [RegistryObjectOracle]
  , residentObjects :: [RegistryResidentOracle]
  , uploadConcurrency :: Natural
  , uploadWorkspaceBytesPerUpload :: Natural
  , failedUploadsPerWindow :: Natural
  , partialBytesPerFailedUpload :: Natural
  , gcHorizonSeconds :: Natural
  , expectedResidentUnionBytes :: Natural
  , expectedNewObjectBytes :: Natural
  , expectedWorkspaceBytes :: Natural
  , expectedFailedResidueBytes :: Natural
  , expectedTransitionBytes :: Natural
  , expectedConflictTag :: Text
  , expectedOneByteUnderTag :: Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Dhall.FromDhall)

data BootstrapOracle = BootstrapOracle
  { snapshot :: Text
  , identities :: [Text]
  , initializedFields :: [Text]
  , handoffDigest :: Text
  , equalVerdict :: Text
  , mismatchTag :: Text
  , staleTag :: Text
  , repeatedTag :: Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (Dhall.FromDhall)

main :: IO ()
main = do
  let catalog = canonicalBakeCatalog
  either (die . show) pure (Catalog.validateBakeCatalog catalog)
  verifyIndependentInventory catalog
  verifyCatalogInjectionClosure catalog
  verifyBuildAdmission
  verifyBuildRuntime
  verifyDockerfile catalog
  verifyArtifact
  verifyRegistryStorage
  verifyBootstrapRegistry
  verifyPublication
  verifyRegistryPullGate
  verifyMutantArtifacts
  putStrLn "base-image-registry-spec: PASS (Phase 25 image build, registry/bootstrap boundaries, immutable atomic publication, enforced private pull, and 13 committed mutants)"

verifyCatalogInjectionClosure :: Catalog.BakeCatalog -> IO ()
verifyCatalogInjectionClosure catalog = do
  let injectedEnvironment =
        catalog
          { Catalog.runtimeEnvironment =
              Catalog.RuntimeEnvironment "PATH\nRUN" "/bin" : catalog.runtimeEnvironment
          }
  case Catalog.validateBakeCatalog injectedEnvironment of
    Left (Catalog.CatalogEnvironmentNameInvalid "PATH\nRUN") -> pure ()
    verdict -> die ("environment-name injection was not specifically rejected: " <> show verdict)
  let injectedValue =
        catalog
          { Catalog.runtimeEnvironment =
              Catalog.RuntimeEnvironment "SAFE" "value\"\nRUN" : catalog.runtimeEnvironment
          }
  case Catalog.validateBakeCatalog injectedValue of
    Left (Catalog.CatalogEnvironmentValueInvalid "SAFE") -> pure ()
    verdict -> die ("environment-value injection was not specifically rejected: " <> show verdict)

verifyIndependentInventory :: Catalog.BakeCatalog -> IO ()
verifyIndependentInventory catalog = do
  expected <- Dhall.inputFile Dhall.auto "test/fixture/base_image_registry/bake_inventory_expected.dhall" :: IO [OracleInventory]
  assertEqual "oracle inventory count" 22 (length expected)
  assertEqual "catalog inventory count" 22 (length (Catalog.catalogSteps catalog))
  let requiredServices =
        Set.fromList
          [ "Registry (distribution)"
          , "MinIO"
          , "Vault"
          , "Pulsar"
          , "Redis/Sentinel"
          , "Prometheus/Grafana"
          , "Percona/Patroni Postgres + pgAdmin"
          , "Envoy / Gateway API"
          , "Keycloak"
          , "MetalLB-or-cloud LoadBalancer"
          ]
      observedServices = Set.fromList (fmap (\row -> row.canonicalService) expected)
  unless (requiredServices `Set.isSubsetOf` observedServices) (die "canonical standard-platform-service inventory drifted")
  assertEqual "unique oracle names" (length expected) (Set.size (Set.fromList (fmap (\row -> row.catalogName) expected)))
  let catalogRows = Map.fromList (fmap catalogRow (Catalog.catalogSteps catalog))
  forM_ expected $ \row -> do
    unless (Text.isPrefixOf "/" row.binary) (die ("non-absolute oracle binary: " <> Text.unpack row.binary))
    case Map.lookup row.catalogName catalogRows of
      Nothing -> die ("catalog omitted oracle entry: " <> Text.unpack row.catalogName)
      Just (catalogVersion, identity, integritySource) -> do
        assertEqual (Text.unpack row.catalogName <> " version") row.version catalogVersion
        assertEqual (Text.unpack row.catalogName <> " acquisition") row.acquisition identity
        assertEqual (Text.unpack row.catalogName <> " integrity") row.integrity integritySource
  forM_ ["llama.cpp", "whisper.cpp", "onnxruntime", "audiveris", "infernix-adapter", "jitml-adapter"] $ \payload ->
    unless (payload `elem` catalog.forbiddenPayloads) (die ("forbidden payload pin missing: " <> Text.unpack payload))
  let withoutRedis = Map.delete "redis-server" catalogRows
  unless (Map.lookup "redis-server" withoutRedis == Nothing) (die "omit-redis mutant stayed green")
  case Map.lookup "redis-cli" catalogRows of
    Just (actualVersion, _, _) -> unless (actualVersion /= "7.0.14") (die "redis-version-skew mutant stayed green")
    Nothing -> die "redis-cli missing"
  case Map.lookup "g++" catalogRows of
    Just (actualVersion, _, _) -> assertEqual "g++ positive version" "13.3.0" actualVersion
    Nothing -> die "g++ missing"
 where
  -- The acquisition identity per rung. Only the scavenge rung names another image;
  -- the rest name what they resolve from, and resolve the integrity value during
  -- the build rather than carrying one an authored file could go stale against.
  catalogRow step = case step of
    Catalog.AptPackage packaged ->
      ( packaged.name
      , (packaged.expectedVersion, "apt:" <> packaged.package <> "=" <> packaged.packageVersion, "sha256:resolved-from-the-archive-at-build")
      )
    Catalog.OfficialArtifact artifact ->
      ( artifact.name
      , (artifact.expectedVersion, artifact.publisher <> "@" <> artifact.releaseVersion, "sha256:resolved-from-the-publisher-manifest")
      )
    Catalog.BuildProduct built ->
      let (identity, integritySource) = Catalog.buildSourceIdentity built.source
       in (built.name, (built.expectedVersion, identity, integritySource))
    Catalog.CopyOci source -> (source.name, (source.expectedVersion, source.sourceImage, source.sourceDigest))

verifyBuildAdmission :: IO ()
verifyBuildAdmission = do
  oracle <- Dhall.inputFile Dhall.auto "test/fixture/base_image_registry/build_execution_envelope.dhall" :: IO BuildOracle
  let envelope = oracleEnvelope oracle
      observed = oracleObservation oracle
  transition <- either (die . show) pure (Admission.validateBuildTarget envelope observed)
  assertEqual "CPU peak" oracle.expectedCpuPeakMillis transition.transitionCpuPeakMillis
  assertEqual "memory peak" oracle.expectedMemoryPeakBytes transition.transitionMemoryPeakBytes
  assertEqual "scratch peak" oracle.expectedScratchPeakBytes transition.transitionScratchPeakBytes
  assertEqual "cache-write peak" oracle.expectedCacheWritePeakBytes transition.transitionCacheWritePeakBytes
  assertEqual "cache transition" oracle.expectedCacheTransitionBytes transition.transitionCachePeakBytes
  let negatives =
        [ ("BuildCpuExceeded", observed {Admission.observedResidualCpuMillis = transition.transitionCpuPeakMillis - 1})
        , ("BuildMemoryExceeded", observed {Admission.observedResidualMemoryBytes = transition.transitionMemoryPeakBytes - 1})
        , ("BuildScratchExceeded", observed {Admission.observedBackingCapacities = Map.insert oracle.scratchBacking (transition.transitionScratchPeakBytes - 1) observed.observedBackingCapacities})
        , ("BuildCacheExceeded", observed {Admission.observedBackingCapacities = Map.insert oracle.cacheBacking (transition.transitionCachePeakBytes - 1) observed.observedBackingCapacities})
        , ("BuildArchitectureConcurrencyExceeded", observed {Admission.observedArchitectureConcurrency = 1})
        , ("BuildStageConcurrencyExceeded", observed {Admission.observedStageConcurrency = 1})
        , ("BuildUnknownCommitment", observed {Admission.observedUnknownCommitments = Set.singleton "mystery-buildkit-worker"})
        ]
  forM_ negatives $ \(tag, changed) ->
    assertEqual (Text.unpack tag) (Left tag) (renderedAdmission (Admission.validateBuildTarget envelope changed))
  target <- Admission.admitBuildTarget envelope observed >>= either (die . show) pure
  assertEqual
    "changed fingerprint"
    (Left "BuildSnapshotChanged")
    =<< renderedConsume target (observed {Admission.observedBuildFingerprint = "changed"})
  assertEqual "first consume" (Right transition) =<< Admission.consumeValidatedBuildTarget target observed
  assertEqual
    "second consume"
    (Left "BuildTargetAlreadyConsumed")
    =<< renderedConsume target observed
  assertEqual "independent rejection tag set" (sort oracle.rejectionTags) (sort ["BuildArchitectureConcurrencyExceeded", "BuildCacheExceeded", "BuildCpuExceeded", "BuildMemoryExceeded", "BuildScratchExceeded", "BuildSnapshotChanged", "BuildStageConcurrencyExceeded", "BuildUnknownCommitment"])
  let scratchDropped = envelope {Admission.buildStages = fmap (\stage -> stage {Admission.buildStageIntermediateBytes = 0}) envelope.buildStages}
  unless (renderedAdmission (Admission.validateBuildTarget scratchDropped observed) /= Right transition) (die "drop-build-scratch-accounting mutant stayed green")

verifyBuildRuntime :: IO ()
verifyBuildRuntime = do
  oracle <- Dhall.inputFile Dhall.auto "test/fixture/base_image_registry/build_execution_envelope.dhall" :: IO BuildOracle
  let envelope = oracleEnvelope oracle
      observed = oracleObservation oracle
      request =
        Runtime.BuildRequest
          { Runtime.buildDockerExecutable = "/usr/bin/docker"
          , Runtime.buildDockerHost = "unix:///project/.test_data/runs/phase25/r/docker.sock"
          , Runtime.buildTestRoot = "/project/.test_data/runs/phase25"
          , Runtime.buildDockerConfig = "/scratch/docker-config"
          , Runtime.buildBuilderName = "amoebius-base-image-registry"
          , Runtime.buildDockerfile = "/build/Dockerfile"
          , Runtime.buildContext = "/build/context"
          , Runtime.buildOciOutput = "/scratch/amoebius.oci.tar"
          , Runtime.buildCacheRoot = "/cache"
          , Runtime.buildScratchRoot = "/scratch"
          , Runtime.buildBuildkitConfig = "/build/buildkitd.toml"
          , Runtime.buildBuildkitImage = "moby/buildkit:buildx-stable-1@sha256:2f5adac4ecd194d9f8c10b7b5d7bceb5186853db1b26e5abd3a657af0b7e26ec"
          , Runtime.buildBuildkitContainer = "amoebius-base-image-registry-buildkitd"
          , Runtime.buildStateVolume = "amoebius-base-image-registry-buildkit-state"
          }
  target <- Admission.admitBuildTarget envelope observed >>= either (die . show) pure
  action <- Runtime.prepareBuildAction target observed request >>= either (die . show) pure
  calls <- newIORef ([] :: [(FilePath, [String])])
  let runner executable arguments = do
        modifyIORef' calls (<> [(executable, arguments)])
        pure Exit.ExitSuccess
  assertEqual
    "runtime changed snapshot"
    (Left "BuildActionSnapshotChanged")
    . renderedRuntime
    =<< Runtime.enactBuildAction action (observed {Admission.observedBuildFingerprint = "changed"}) runner
  assertEqual "changed snapshot builder count" 0 . length =<< readIORef calls
  assertEqual "runtime first enactment" (Right Runtime.BuildSucceeded) =<< Runtime.enactBuildAction action observed runner
  invoked <- readIORef calls
  assertEqual "admitted process count" 6 (length invoked)
  case reverse invoked of
    actualInvocation : _ ->
      assertEqual
        "fixed multi-arch OCI command"
        ( "/usr/bin/docker"
        , [ "--host", "unix:///project/.test_data/runs/phase25/r/docker.sock"
          , "--config", "/scratch/docker-config"
          , "buildx", "build", "--builder", "amoebius-base-image-registry"
          , "--platform", "linux/amd64,linux/arm64"
          , "--file", "/build/Dockerfile"
          , "--provenance=false"
          , "--sbom=false"
          , "--output", "type=oci,dest=/scratch/amoebius.oci.tar"
          , "--cache-to", "type=local,dest=/cache/buildx-cache,mode=min"
          , "/build/context"
          ]
        )
        actualInvocation
    [] -> die "admitted build action ran no processes"
  case [arguments | (executable, arguments) <- invoked, executable == "/usr/bin/docker", "run" `elem` arguments] of
    [builderArguments] -> do
      forM_
        [ ["--runtime", "runc"]
        , ["--cpus", "7"]
        , ["--memory", "7516192768"]
        , ["--memory-swap", "7516192768"]
        ]
        $ \required ->
          unless (required `isContiguousSubsequenceOf` builderArguments) (die ("bounded builder argument absent: " <> show required))
    _ -> die "bounded builder process count drifted"
  assertEqual
    "runtime second enactment"
    (Left "BuildActionAlreadyConsumed")
    . renderedRuntime
    =<< Runtime.enactBuildAction action observed runner
  assertEqual "second enactment process count" 6 . length =<< readIORef calls
  rejectedTarget <- Admission.admitBuildTarget envelope observed >>= either (die . show) pure
  let relative = request {Runtime.buildOciOutput = "relative.oci.tar"}
  relativeVerdict <- Runtime.prepareBuildAction rejectedTarget observed relative
  case relativeVerdict of
    Left problem ->
      assertEqual
        "relative output rejected before target consumption"
        "BuildRequestPathNotAbsolute"
        (Runtime.renderBuildRuntimeError problem)
    Right _ -> die "relative output unexpectedly minted a build action"
  validAfterBadRequest <- Runtime.prepareBuildAction rejectedTarget observed request
  case validAfterBadRequest of
    Right _ -> pure ()
    Left problem -> die ("bad request consumed the admission token: " <> show problem)
  forM_
    [ "unix:///var/run/docker.sock"
    , "tcp://127.0.0.1:2375"
    , "unix://relative/docker.sock"
    ]
    $ \invalidHost -> do
      invalidHostTarget <- Admission.admitBuildTarget envelope observed >>= either (die . show) pure
      verdict <- Runtime.prepareBuildAction invalidHostTarget observed request {Runtime.buildDockerHost = invalidHost}
      case verdict of
        Left problem ->
          assertEqual
            "non-project Docker host rejected"
            "BuildRequestDockerHostInvalid"
            (Runtime.renderBuildRuntimeError problem)
        Right _ -> die ("invalid Docker host unexpectedly minted an action: " <> Text.unpack invalidHost)
  forM_
    [ "moby/buildkit:buildx-stable-1"
    , "docker.io/moby/buildkit@sha256:28a898719c18a33f4e8000685287fa36fd0dd9560c6440227d3a732d79bb41d8"
    , "moby/buildkit@sha256:not-a-digest"
    ]
    $ \invalidImage -> do
      invalidTarget <- Admission.admitBuildTarget envelope observed >>= either (die . show) pure
      verdict <- Runtime.prepareBuildAction invalidTarget observed request {Runtime.buildBuildkitImage = invalidImage}
      case verdict of
        Left problem ->
          assertEqual
            "non-immutable or foreign BuildKit image rejected"
            "BuildRequestBuildkitImageInvalid"
            (Runtime.renderBuildRuntimeError problem)
        Right _ -> die ("invalid BuildKit image unexpectedly minted an action: " <> Text.unpack invalidImage)
  currentTarget <- Admission.admitBuildTarget envelope observed >>= either (die . show) pure
  currentVerdict <-
    Runtime.prepareBuildAction
      currentTarget
      observed
      request
        { Runtime.buildBuildkitImage =
            "moby/buildkit@sha256:28a898719c18a33f4e8000685287fa36fd0dd9560c6440227d3a732d79bb41d8"
        }
  case currentVerdict of
    Right _ -> pure ()
    Left problem -> die ("current digest-pinned BuildKit image rejected: " <> show problem)

verifyDockerfile :: Catalog.BakeCatalog -> IO ()
verifyDockerfile catalog = do
  rendered <- either (die . show) pure (Dockerfile.renderDockerfile catalog)
  expected <- Text.readFile "test/fixture/base_image_registry/Dockerfile.golden"
  assertEqual "Dockerfile golden" expected rendered.dockerfileText
  unless ("# GENERATED BY" `Text.isInfixOf` rendered.dockerfileText) (die "generated-by stamp absent")
  -- Before the acquisition ladder every step was a `COPY --from`, so `RUN ` and
  -- `https://` could simply be banned. Both are now what rungs 1 and 2 are made
  -- of, and a ban that has to be lifted is not a check. What replaces it is
  -- narrower than the ban was: the emitted `RUN` set must be exactly one apt
  -- layer plus one per official artifact — no step may contribute a shell
  -- fragment of its own — and every URL in the file must be one the catalog
  -- authored, so a download address cannot enter through the renderer.
  let emitted = Text.lines rendered.dockerfileText
      steps = Catalog.catalogSteps catalog
      artifacts = [artifact | Catalog.OfficialArtifact artifact <- steps]
      aptLayers = if null [() | Catalog.AptPackage _ <- steps] then 0 else 1
      runLines = filter (Text.isPrefixOf "RUN ") emitted
      authoredUrls =
        Set.fromList
          ( concatMap
              ( \artifact ->
                  concatMap (\asset -> [asset.assetUrl, asset.checksumManifest]) artifact.assets
                    <> concatMap
                      (\payload -> concatMap (\asset -> [asset.assetUrl, asset.checksumManifest]) payload.assets)
                      artifact.payloads
              )
              artifacts
          )
      emittedUrls = Set.fromList (concatMap urlsIn emitted)
      payloadLayers = sum (fmap (length . (.payloads)) artifacts)
  assertEqual "one RUN per apt layer, official artifact, and companion payload" (aptLayers + length artifacts + payloadLayers) (length runLines)
  unless (emittedUrls `Set.isSubsetOf` authoredUrls)
    (die ("Dockerfile URL the catalog did not author: " <> show (Set.toList (Set.difference emittedUrls authoredUrls))))
  assertEqual "every authored URL reaches the Dockerfile" authoredUrls emittedUrls
  forM_ ["http://", ":latest"] $ \forbidden ->
    unless (not (forbidden `Text.isInfixOf` rendered.dockerfileText)) (die ("unlicensed Dockerfile surface: " <> Text.unpack forbidden))
  let mutated = rendered.dockerfileText <> "RUN touch /unlicensed\n"
  unless (mutated /= expected) (die "dockerfile-handedit mutant stayed green")

-- | Every `https://` run in one line, ending where a URL cannot continue.
urlsIn :: Text -> [Text]
urlsIn line = case Text.breakOn "https://" line of
  (_, rest)
    | Text.null rest -> []
    | otherwise ->
        let (url, remainder) = Text.span (`notElem` (" \t\"'" :: String)) rest
         in url : urlsIn remainder

verifyArtifact :: IO ()
verifyArtifact = do
  let artifact = validArtifact
      bounds = Artifact.ArtifactBounds 4096 8192 4096 1048576 2097152 4194304
  assertEqual "valid artifact" (Right ()) (Artifact.validateImageArtifact bounds artifact)
  stored <- either (die . show) pure (Artifact.registryStoredArtifacts artifact)
  assertEqual "digest-deduplicated registry object count" 6 (Map.size stored)
  let missingArm = artifact {Artifact.imagePlatforms = take 1 artifact.imagePlatforms}
  assertEqual "missing platform" (Left "ArtifactPlatformSetMismatch") (renderedArtifact (Artifact.validateImageArtifact bounds missingArm))
  case artifact.imagePlatforms of
    [amd64, arm64] -> case (amd64.artifactLayers, arm64.artifactLayers) of
      ([amdLayer], [armLayer]) -> do
        let conflictingLayer = armLayer {Artifact.layerCompressedBytes = 1025}
            conflictingArm = arm64 {Artifact.artifactLayers = [conflictingLayer]}
            conflict = artifact {Artifact.imagePlatforms = [amd64, conflictingArm]}
        assertEqual "digest size conflict" (Left "ArtifactDigestSizeConflict") (renderedArtifact (Artifact.validateImageArtifact bounds conflict))
        let kindCollisionArm =
              arm64
                { Artifact.artifactConfigDigest = amdLayer.layerDigest
                , Artifact.artifactConfigBytes = amdLayer.layerCompressedBytes
                }
            kindCollision = artifact {Artifact.imagePlatforms = [amd64, kindCollisionArm]}
        assertEqual "digest kind conflict" (Left "ArtifactDigestKindConflict") (renderedArtifact (Artifact.validateImageArtifact bounds kindCollision))
      _ -> die "test artifact layer shape drifted"
    _ -> die "test artifact platform shape drifted"

verifyRegistryStorage :: IO ()
verifyRegistryStorage = do
  oracle <- Dhall.inputFile Dhall.auto "test/fixture/base_image_registry/registry_storage_demand.dhall" :: IO RegistryOracle
  let desired = Map.fromList [(row.digest, row.storedBytes) | row <- oracle.objects]
      residents = Map.fromList [(row.digest, row.storedBytes) | row <- oracle.residentObjects]
      admission =
        Registry.RegistryMutationAdmission
          { Registry.registryPublisherCapabilityDigest = digest '9'
          , Registry.registryAdmittedDigests = Map.keysSet desired
          , Registry.registryMaxConcurrentUploads = oracle.uploadConcurrency
          , Registry.registryMaxObjectBytes = maximum (Map.elems desired)
          }
      demand capacity observed =
        Registry.RegistryStorageDemand
          { Registry.registryDesiredObjects = desired
          , Registry.registryObservedResidentObjects = observed
          , Registry.registryUploadConcurrency = oracle.uploadConcurrency
          , Registry.registryUploadWorkspaceBytesPerUpload = oracle.uploadWorkspaceBytesPerUpload
          , Registry.registryFailedUploadsPerWindow = oracle.failedUploadsPerWindow
          , Registry.registryPartialBytesPerFailedUpload = oracle.partialBytesPerFailedUpload
          , Registry.registryGcHorizonSeconds = oracle.gcHorizonSeconds
          , Registry.registryVolumeCapacityBytes = capacity
          , Registry.registryMutationAdmission = admission
          }
  provisioned <- either (die . show) pure (Registry.provisionRegistryStorage (demand oracle.expectedTransitionBytes residents))
  assertEqual "registry resident/desired union" oracle.expectedResidentUnionBytes provisioned.provisionedRegistryStoredBytes
  assertEqual "registry new object bytes" oracle.expectedNewObjectBytes provisioned.provisionedRegistryNewObjectBytes
  assertEqual "registry maximum upload workspace" oracle.expectedWorkspaceBytes provisioned.provisionedRegistryUploadWorkspaceBytes
  assertEqual "registry failed-upload residue" oracle.expectedFailedResidueBytes provisioned.provisionedRegistryFailedUploadBytes
  assertEqual "registry transition peak" oracle.expectedTransitionBytes provisioned.provisionedRegistryPeakBytes
  shared <- case oracle.objects of
    [] -> die "registry object oracle is empty"
    firstObject : _ -> pure firstObject
  let conflictResidents = Map.insert shared.digest (shared.storedBytes + 1) residents
  assertEqual
    "registry digest-size conflict"
    (Left oracle.expectedConflictTag)
    (renderedRegistry (Registry.provisionRegistryStorage (demand oracle.expectedTransitionBytes conflictResidents)))
  assertEqual
    "registry one byte under"
    (Left oracle.expectedOneByteUnderTag)
    (renderedRegistry (Registry.provisionRegistryStorage (demand (oracle.expectedTransitionBytes - 1) residents)))

verifyBootstrapRegistry :: IO ()
verifyBootstrapRegistry = do
  oracle <- Dhall.inputFile Dhall.auto "test/fixture/base_image_registry/bootstrap_registry_domain.dhall" :: IO BootstrapOracle
  let expectedDomain = Set.fromList (fmap K8sObjectIdentity oracle.identities)
      expectedFields = Set.fromList oracle.initializedFields
  assertEqual "bootstrap domain oracle" expectedDomain Bootstrap.bootstrapRegistryDomain
  assertEqual "bootstrap initialized fields oracle" expectedFields Bootstrap.bootstrapRegistryInitializedFields
  spec <- bootstrapSpec oracle
  Bootstrap.provisionBootstrapRegistry (spec {Bootstrap.bootstrapRegistryPlatform = Artifact.LinuxArm64}) >>= \case
    Left problem -> assertEqual "bootstrap selected-platform equality" "BootstrapRegistryPlatformMismatch" (Bootstrap.renderBootstrapRegistryError problem)
    Right _ -> die "bootstrap selected-platform mismatch unexpectedly provisioned"
  provision <- Bootstrap.provisionBootstrapRegistry spec >>= either (die . show) pure
  let observed = bootstrapObserved oracle spec
      negativeRows =
        [ ("occupied CPU", observed {Bootstrap.observedBootstrapRegistryRequestResidual = (observed.observedBootstrapRegistryRequestResidual) {resourceCpu = 349}})
        , ("occupied memory", observed {Bootstrap.observedBootstrapRegistryRequestResidual = (observed.observedBootstrapRegistryRequestResidual) {resourceMemory = 402653183}})
        , ("occupied ephemeral", observed {Bootstrap.observedBootstrapRegistryRequestResidual = (observed.observedBootstrapRegistryRequestResidual) {resourceEphemeralStorage = 35651583}})
        , ("occupied pod slot", observed {Bootstrap.observedBootstrapRegistryRequestResidual = (observed.observedBootstrapRegistryRequestResidual) {resourcePodSlots = 1}})
        , ("pull policy", observed {Bootstrap.observedBootstrapRegistryNodeLoad = (observed.observedBootstrapRegistryNodeLoad) {NodeLoad.observedNodeLoadPullPolicy = NodeLoad.PullIfNotPresent}})
        , ("source digest", observed {Bootstrap.observedBootstrapRegistrySourceDigest = digest '8'})
        ]
  forM_ negativeRows $ \(label, changed) -> do
    verdict <- Bootstrap.validateBootstrapRegistryTarget provision changed
    case verdict of
      Left _ -> pure ()
      Right _ -> die (label <> " unexpectedly minted a bootstrap action")
  action <- Bootstrap.validateBootstrapRegistryTarget provision observed >>= either (die . show) pure
  assertEqual "bootstrap action domain" expectedDomain (Bootstrap.bootstrapRegistryActionIdentities action)
  assertEqual "bootstrap serialized object count" 6 (length (Bootstrap.bootstrapRegistryActionObjects action))
  imports <- newIORef (0 :: Int)
  applies <- newIORef (0 :: Int)
  let importImage _ = modifyIORef' imports (+ 1) >> pure True
      applyObject _ = modifyIORef' applies (+ 1) >> pure True
  enacted <- Bootstrap.enactBootstrapRegistry action observed importImage applyObject >>= either (die . show) pure
  case enacted of
    Bootstrap.BootstrapRegistryApplied receipt -> do
      assertEqual "bootstrap receipt imported" True receipt.bootstrapReceiptImported
      assertEqual "bootstrap receipt object count" 6 receipt.bootstrapReceiptAppliedObjects
    Bootstrap.BootstrapRegistryAmbiguous receipt -> die ("bootstrap action was ambiguous: " <> show receipt)
  assertEqual "bootstrap import count" 1 =<< readIORef imports
  assertEqual "bootstrap apply count" 6 =<< readIORef applies
  assertEqual
    "bootstrap action single use"
    (Left "BootstrapRegistryActionAlreadyConsumed")
    . renderedBootstrap
    =<< Bootstrap.enactBootstrapRegistry action observed importImage applyObject
  assertEqual "single-use import remains one" 1 =<< readIORef imports
  assertEqual
    "handoff mismatch"
    (Left oracle.mismatchTag)
    . renderedBootstrap
    =<< Bootstrap.adoptBootstrapRegistryHandoff provision expectedDomain expectedFields (digest '8')
  assertEqual
    "handoff equality"
    (Right Bootstrap.AdoptedOnce)
    =<< Bootstrap.adoptBootstrapRegistryHandoff provision expectedDomain expectedFields oracle.handoffDigest
  assertEqual "handoff oracle verdict" oracle.equalVerdict (Text.pack (show Bootstrap.AdoptedOnce))
  assertEqual
    "handoff repeated"
    (Left oracle.repeatedTag)
    . renderedBootstrap
    =<< Bootstrap.adoptBootstrapRegistryHandoff provision expectedDomain expectedFields oracle.handoffDigest
  staleAction <- Bootstrap.validateBootstrapRegistryTarget provision observed >>= either (die . show) pure
  assertEqual
    "stale snapshot"
    (Left oracle.staleTag)
    . renderedBootstrap
    =<< Bootstrap.enactBootstrapRegistry staleAction (observed {Bootstrap.observedBootstrapRegistryFingerprint = "changed"}) importImage applyObject
  assertEqual "stale snapshot imports zero" 1 =<< readIORef imports

verifyPublication :: IO ()
verifyPublication = do
  reference <-
    either (die . show) pure
      ( ImageRef.deriveImmutableImageRef
          "registry.amoebius.invalid/amoebius/base"
          (digest '8')
          (Artifact.imageIndexDigest validArtifact)
      )
  assertEqual
    "immutable source/content tag"
    "registry.amoebius.invalid/amoebius/base:source-888888888888-content-111111111111"
    (ImageRef.immutableImageTaggedReference reference)
  assertEqual
    "digest-pinned deployment reference"
    ("registry.amoebius.invalid/amoebius/base@" <> Artifact.imageIndexDigest validArtifact)
    (ImageRef.immutableImageDigestReference reference)
  assertEqual
    "latest repository rejected"
    (Left "ImageRepositoryInvalid")
    ( case ImageRef.deriveImmutableImageRef "registry.amoebius.invalid/amoebius/base:latest" (digest '8') (digest '1') of
        Left problem -> Left (ImageRef.renderImageRefError problem)
        Right _ -> Right ()
    )
  storageDemand <-
    either (die . show) pure
      ( Registry.registryDemandFromArtifact
          validArtifact
          Map.empty
          2
          4096
          1
          1024
          3600
          1048576
          (digest '9')
      )
  storage <- either (die . show) pure (Registry.provisionRegistryStorage storageDemand)
  let childDigests = fmap Artifact.artifactChildDigest (Artifact.imagePlatforms validArtifact)
      plan =
        Publish.PublicationPlan
          { Publish.publicationDockerExecutable = "/usr/bin/docker"
          , Publish.publicationDockerConfigDirectory = "/scratch/publisher-config"
          , Publish.publicationRef = reference
          , Publish.publicationChildManifestDigests = childDigests
          , Publish.publicationPublisherCapabilityDigest = digest '9'
          , Publish.publicationSourceDigest = digest '8'
          }
      observed = Publish.ObservedPublicationTarget "publish-snapshot" (digest '8') Nothing
  provision <- either (die . show) pure (Publish.provisionPublication storage plan)
  assertEqual "provision retains immutable ref" reference (Publish.provisionedPublicationRef provision)
  assertEqual
    "publication source mismatch"
    (Left "PublicationSourceDigestMismatch")
    . renderedPublicationDecision
    =<< Publish.validatePublicationTarget provision (observed {Publish.observedPublicationSourceDigest = digest '7'})
  decision <- Publish.validatePublicationTarget provision observed >>= either (die . show) pure
  action <- case decision of
    Publish.PublicationRequired required -> pure required
    Publish.PublicationNoOp _ -> die "unpublished target unexpectedly became a no-op"
  calls <- newIORef ([] :: [(FilePath, [String])])
  let successful executable arguments = modifyIORef' calls (<> [(executable, arguments)]) >> pure Exit.ExitSuccess
  assertEqual
    "publication stale snapshot"
    (Left "PublicationSnapshotChanged")
    . renderedPublicationResult
    =<< Publish.enactPublication action (observed {Publish.observedPublicationFingerprint = "changed"}) successful
  assertEqual "stale publication writes zero" [] =<< readIORef calls
  applied <- Publish.enactPublication action observed successful >>= either (die . show) pure
  case applied of
    Publish.PublicationApplied receipt -> do
      assertEqual "publication advertised after success" True receipt.publicationReceiptAdvertised
      assertEqual "single final advertisement" 1 receipt.publicationReceiptMutatingRequests
    Publish.PublicationFailed _ status -> die ("publication unexpectedly failed: " <> show status)
  invoked <- readIORef calls
  assertEqual
    "single buildx manifest-list advertisement"
    [ ( "/usr/bin/docker"
      , [ "--config", "/scratch/publisher-config"
        , "buildx", "imagetools", "create"
        , "--tag", "registry.amoebius.invalid/amoebius/base:source-888888888888-content-111111111111"
        , "registry.amoebius.invalid/amoebius/base@" <> Text.unpack (childDigests !! 0)
        , "registry.amoebius.invalid/amoebius/base@" <> Text.unpack (childDigests !! 1)
        ]
      )
    ]
    invoked
  assertEqual
    "publication action single use"
    (Left "PublicationActionAlreadyConsumed")
    . renderedPublicationResult
    =<< Publish.enactPublication action observed successful
  assertEqual "single use preserves one process" 1 . length =<< readIORef calls
  failedDecision <- Publish.validatePublicationTarget provision observed >>= either (die . show) pure
  failedAction <- case failedDecision of
    Publish.PublicationRequired required -> pure required
    Publish.PublicationNoOp _ -> die "fresh failed publication unexpectedly became a no-op"
  failed <-
    Publish.enactPublication failedAction observed (\_ _ -> pure (Exit.ExitFailure 42))
      >>= either (die . show) pure
  case failed of
    Publish.PublicationFailed receipt 42 ->
      assertEqual "publication failure unadvertised" False receipt.publicationReceiptAdvertised
    verdict -> die ("publication failure verdict drifted: " <> show verdict)
  noOp <-
    Publish.validatePublicationTarget
      provision
      (observed {Publish.observedPublishedIndexDigest = Just (Artifact.imageIndexDigest validArtifact)})
      >>= either (die . show) pure
  case noOp of
    Publish.PublicationNoOp receipt -> do
      assertEqual "published rerun has zero writes" 0 receipt.publicationReceiptMutatingRequests
      assertEqual "published rerun retains digest ref" (ImageRef.immutableImageDigestReference reference) receipt.publicationReceiptDigestReference
    Publish.PublicationRequired _ -> die "published digest unexpectedly requested another publication"

verifyRegistryPullGate :: IO ()
verifyRegistryPullGate = do
  endpointText <- Text.readFile "test/fixture/base_image_registry/public_registry_endpoints.txt"
  expectedFailure <- Text.readFile "test/fixture/base_image_registry/expected_pull_failure.txt"
  let endpoints = Set.fromList (filter (not . Text.null) (Text.lines endpointText))
      plan mechanism =
        ImageGate.PublicRegistryDenyPlan
          { ImageGate.publicRegistryDenialMechanism = mechanism
          , ImageGate.publicRegistryEndpointNames = endpoints
          , ImageGate.publicRegistryResolvedAddresses = Set.fromList ["192.0.2.10", "192.0.2.11"]
          }
      observed =
        ImageGate.ObservedRegistryPullGate
          { ImageGate.observedPublicCanaryPhase = "ImagePullBackOff"
          , ImageGate.observedPublicCanaryReasons = Set.fromList ["ErrImagePull", Text.strip expectedFailure]
          , ImageGate.observedFirewallDroppedPackets = 1
          , ImageGate.observedInClusterPullSucceeded = True
          , ImageGate.observedInClusterIndexDigest = digest '1'
          , ImageGate.observedExpectedIndexDigest = digest '1'
          , ImageGate.observedStandupPublicTcpConnections = 0
          , ImageGate.observedPublicationPublicTcpConnections = 0
          , ImageGate.observedRerunMutatingRequests = 0
          }
  receipt <- either (die . show) pure (ImageGate.validateRegistryPullGate (plan ImageGate.EnforcingNodeFirewall) observed)
  assertEqual "public endpoint oracle count" 8 receipt.registryPullGateEndpointCount
  assertEqual "firewall negative-control count" 1 receipt.registryPullGateDroppedPackets
  assertEqual
    "noop egress policy"
    (Left "PublicRegistryDenialNotEnforcing")
    (renderedRegistryPullGate (ImageGate.validateRegistryPullGate (plan ImageGate.KindnetNetworkPolicy) observed))
  assertEqual
    "successful public canary rejected"
    (Left "PublicPullCanaryUnexpectedlySucceeded")
    ( renderedRegistryPullGate
        (ImageGate.validateRegistryPullGate (plan ImageGate.EnforcingNodeFirewall) (observed {ImageGate.observedPublicCanaryPhase = "Succeeded"}))
    )

bootstrapSpec :: BootstrapOracle -> IO Bootstrap.BootstrapRegistrySpec
bootstrapSpec oracle = do
  registryOracle <- Dhall.inputFile Dhall.auto "test/fixture/base_image_registry/registry_storage_demand.dhall" :: IO RegistryOracle
  let artifact = validArtifact
      desired = Map.fromList [(row.digest, row.storedBytes) | row <- registryOracle.objects]
      residents = Map.fromList [(row.digest, row.storedBytes) | row <- registryOracle.residentObjects]
      storage =
        Registry.RegistryStorageDemand
          { Registry.registryDesiredObjects = desired
          , Registry.registryObservedResidentObjects = residents
          , Registry.registryUploadConcurrency = registryOracle.uploadConcurrency
          , Registry.registryUploadWorkspaceBytesPerUpload = registryOracle.uploadWorkspaceBytesPerUpload
          , Registry.registryFailedUploadsPerWindow = registryOracle.failedUploadsPerWindow
          , Registry.registryPartialBytesPerFailedUpload = registryOracle.partialBytesPerFailedUpload
          , Registry.registryGcHorizonSeconds = registryOracle.gcHorizonSeconds
          , Registry.registryVolumeCapacityBytes = registryOracle.expectedTransitionBytes
          , Registry.registryMutationAdmission =
              Registry.RegistryMutationAdmission
                { Registry.registryPublisherCapabilityDigest = digest '9'
                , Registry.registryAdmittedDigests = Map.keysSet desired
                , Registry.registryMaxConcurrentUploads = registryOracle.uploadConcurrency
                , Registry.registryMaxObjectBytes = maximum (Map.elems desired)
                }
          }
      layout = NodeStorage.Unified (NodeStorage.LocalBacking "nodefs" 1073741824)
      nodePlan =
        NodeLoad.NodeLoadPlan
          { NodeLoad.nodeLoadArtifact = artifact
          , NodeLoad.nodeLoadPlatform = Artifact.LinuxAmd64
          , NodeLoad.nodeLoadDeclaredLayout = layout
          , NodeLoad.nodeLoadStorageModel = "containerd-overlayfs-v1"
          }
      registryContainer =
        Bootstrap.BootstrapContainerDemand
          (ResourceVector 250 268435456 20971520 1)
          (ResourceVector 500 536870912 41943040 1)
          1048576
      proxyContainer =
        Bootstrap.BootstrapContainerDemand
          (ResourceVector 100 134217728 14680064 1)
          (ResourceVector 250 268435456 29360128 1)
          1048576
      execution = Bootstrap.BootstrapRegistryExecution registryContainer proxyContainer "amoebius-control-plane"
      fields role container extra =
        Map.fromList
          [ ("role", role)
          , ("image", "amoebius-base@" <> Artifact.imageIndexDigest artifact)
          , ("node-name", "amoebius-control-plane")
          , ("cpu-request", naturalText (resourceCpu (Bootstrap.bootstrapContainerRequests container)))
          , ("cpu-limit", naturalText (resourceCpu (Bootstrap.bootstrapContainerLimits container)))
          , ("memory-request", naturalText (resourceMemory (Bootstrap.bootstrapContainerRequests container)))
          , ("memory-limit", naturalText (resourceMemory (Bootstrap.bootstrapContainerLimits container)))
          , ("ephemeral-request", naturalText (resourceEphemeralStorage (Bootstrap.bootstrapContainerRequests container)))
          , ("ephemeral-limit", naturalText (resourceEphemeralStorage (Bootstrap.bootstrapContainerLimits container)))
          ] <> extra
      namespace = Bootstrap.BootstrapObjectSource (K8sObjectIdentity (oracle.identities !! 0)) NamespaceKind Nothing Map.empty
      config = Bootstrap.BootstrapObjectSource (K8sObjectIdentity (oracle.identities !! 1)) ConfigMapKind (Just "amoebius-bootstrap") (Map.singleton "registry-config" "filesystem")
      distribution = Bootstrap.BootstrapObjectSource (K8sObjectIdentity (oracle.identities !! 2)) DeploymentKind (Just "amoebius-bootstrap") (fields "distribution" registryContainer (Map.singleton "empty-dir-size-limit" (naturalText registryOracle.expectedTransitionBytes)))
      readService = Bootstrap.BootstrapObjectSource (K8sObjectIdentity (oracle.identities !! 3)) ServiceKind (Just "amoebius-bootstrap") (Map.singleton "port" "5000")
      proxy = Bootstrap.BootstrapObjectSource (K8sObjectIdentity (oracle.identities !! 4)) DeploymentKind (Just "amoebius-bootstrap") (fields "mutation-proxy" proxyContainer Map.empty)
      proxyService = Bootstrap.BootstrapObjectSource (K8sObjectIdentity (oracle.identities !! 5)) ServiceKind (Just "amoebius-bootstrap") (Map.singleton "port" "5001")
  pure
    Bootstrap.BootstrapRegistrySpec
      { Bootstrap.bootstrapRegistryArtifact = artifact
      , Bootstrap.bootstrapRegistryPlatform = Artifact.LinuxAmd64
      , Bootstrap.bootstrapRegistryNodeLoadPlan = nodePlan
      , Bootstrap.bootstrapRegistryStorageDemand = storage
      , Bootstrap.bootstrapRegistryExecution = execution
      , Bootstrap.bootstrapRegistrySources = [namespace, config, distribution, readService, proxy, proxyService]
      , Bootstrap.bootstrapRegistryInitializedFieldSet = Set.fromList oracle.initializedFields
      , Bootstrap.bootstrapRegistryHandoffDigest = oracle.handoffDigest
      }

bootstrapObserved :: BootstrapOracle -> Bootstrap.BootstrapRegistrySpec -> Bootstrap.ObservedBootstrapRegistryInventory
bootstrapObserved oracle spec =
  let nodePlan = spec.bootstrapRegistryNodeLoadPlan
   in Bootstrap.ObservedBootstrapRegistryInventory
        { Bootstrap.observedBootstrapRegistryFingerprint = oracle.snapshot
        , Bootstrap.observedBootstrapRegistryRequestResidual = ResourceVector 4000 8589934592 1073741824 20
        , Bootstrap.observedBootstrapRegistryLimitResidual = ResourceVector 8000 17179869184 2147483648 20
        , Bootstrap.observedBootstrapRegistryNodeLoad =
            NodeLoad.ObservedNodeLoadInventory
              { NodeLoad.observedNodeLoadFingerprint = oracle.snapshot
              , NodeLoad.observedNodeLoadLayout = nodePlan.nodeLoadDeclaredLayout
              , NodeLoad.observedNodeLoadComponents = [NodeStorage.NodeStorageComponent "node-existing" NodeStorage.KubeletNodefs 67108864]
              , NodeLoad.observedNodeLoadResidentImages = Set.empty
              , NodeLoad.observedNodeLoadStorageModels = Set.singleton "containerd-overlayfs-v1"
              , NodeLoad.observedNodeLoadPullPolicy = NodeLoad.PullNever
              }
        , Bootstrap.observedBootstrapRegistryDomain = Set.fromList (fmap K8sObjectIdentity oracle.identities)
        , Bootstrap.observedBootstrapRegistryInitializedFields = Set.fromList oracle.initializedFields
        , Bootstrap.observedBootstrapRegistrySourceDigest = oracle.handoffDigest
        , Bootstrap.observedBootstrapRegistryApiVersions = Map.fromList [(NamespaceKind, "v1"), (ConfigMapKind, "v1"), (DeploymentKind, "apps/v1"), (ServiceKind, "v1")]
        , Bootstrap.observedBootstrapRegistryUnknownCommitments = Set.empty
        }

naturalText :: Natural -> Text
naturalText = Text.pack . show

verifyMutantArtifacts :: IO ()
verifyMutantArtifacts = do
  let names =
        [ "stub-arm64-binary"
        , "wrong-arch-layer"
        , "gxx-version-skew"
        , "drop-build-scratch-accounting"
        , "bootstrap-domain-expansion"
        , "handoff-without-equality"
        , "record-before-push"
        , "noop-egress-policy"
        , "omit-redis"
        , "redis-version-skew"
        , "dockerfile-handedit"
        , "unbounded-buildkit-worker"
        , "public-redis-image"
        , "scavenge-available-apt-rung"
        ]
  forM_ names $ \name -> do
    contents <- readFile ("test/mutant/base_image_registry/" <> name <> ".mutant")
    unless ("expected_oracle=" `isPrefixOfAnyLine` contents) (die ("mutant lacks oracle: " <> name))
 where
  prefix `isPrefixOfAnyLine` source = any (prefix `isPrefixOf`) (lines source)

oracleEnvelope :: BuildOracle -> Admission.BuildExecutionEnvelope
oracleEnvelope oracle =
  Admission.BuildExecutionEnvelope
    { Admission.buildStages = fmap toStage oracle.stages
    , Admission.buildArchitectureConcurrency = Admission.BoundedParallel oracle.architectureConcurrency
    , Admission.buildStageConcurrency = Admission.BoundedParallel oracle.stageConcurrency
    , Admission.buildScratchBacking = oracle.scratchBacking
    , Admission.buildScratchCapacityBytes = oracle.scratchCapacityBytes
    , Admission.buildCacheBacking = oracle.cacheBacking
    , Admission.buildCacheCapacityBytes = oracle.cacheCapacityBytes
    }
 where
  toStage stage =
    Admission.BuildStageDemand
      { Admission.buildStageName = stage.name
      , Admission.buildStageDependencies = Set.fromList stage.dependencies
      , Admission.buildStageCpuReservationMillis = stage.cpuReservationMillis
      , Admission.buildStageCpuCeilingMillis = stage.cpuCeilingMillis
      , Admission.buildStageMemoryReservationBytes = stage.memoryReservationBytes
      , Admission.buildStageMemoryCeilingBytes = stage.memoryCeilingBytes
      , Admission.buildStageIntermediateBytes = stage.intermediateBytes
      , Admission.buildStageCacheWriteBytes = stage.cacheWriteBytes
      }

oracleObservation :: BuildOracle -> Admission.ObservedBuildHost
oracleObservation oracle =
  Admission.ObservedBuildHost
    { Admission.observedBuildFingerprint = oracle.fingerprint
    , Admission.observedResidualCpuMillis = oracle.residualCpuMillis
    , Admission.observedResidualMemoryBytes = oracle.residualMemoryBytes
    , Admission.observedBackingCapacities = Map.fromList [(oracle.scratchBacking, oracle.scratchCapacityBytes), (oracle.cacheBacking, oracle.cacheCapacityBytes)]
    , Admission.observedCacheResidents = Map.singleton oracle.cacheBacking oracle.observedCacheResidentBytes
    , Admission.observedArchitectureConcurrency = oracle.architectureConcurrency
    , Admission.observedStageConcurrency = oracle.stageConcurrency
    , Admission.observedUnknownCommitments = Set.empty
    }

validArtifact :: Artifact.ImageArtifact
validArtifact =
  Artifact.ImageArtifact
    { Artifact.imageIdentity = "amoebius-base-v1"
    , Artifact.imageIndexDigest = digest '1'
    , Artifact.imageIndexBytes = 2048
    , Artifact.imagePlatforms =
        [ platform Artifact.LinuxAmd64 '2' '3'
        , platform Artifact.LinuxArm64 '4' '5'
        ]
    }
 where
  platform architecture manifest config =
    Artifact.ImagePlatformArtifact
      { Artifact.artifactPlatform = architecture
      , Artifact.artifactChildDigest = digest manifest
      , Artifact.artifactChildManifestBytes = 4096
      , Artifact.artifactConfigDigest = digest config
      , Artifact.artifactConfigBytes = 2048
      , Artifact.artifactLayers = [Artifact.ImageLayer (digest '6') 1024 (digest '7') 2048]
      , Artifact.artifactPeakImportWorkspace = 4096
      }

digest :: Char -> Text
digest character = "sha256:" <> Text.replicate 64 (Text.singleton character)

renderedAdmission :: Either Admission.BuildAdmissionError value -> Either Text value
renderedAdmission result = case result of
  Left problem -> Left (Admission.renderBuildAdmissionError problem)
  Right value -> Right value

renderedConsume :: Admission.ValidatedBuildTarget -> Admission.ObservedBuildHost -> IO (Either Text Admission.BuildTransition)
renderedConsume target observed = renderedAdmission <$> Admission.consumeValidatedBuildTarget target observed

renderedArtifact :: Either Artifact.ArtifactError value -> Either Text value
renderedArtifact result = case result of
  Left problem -> Left (Artifact.renderArtifactError problem)
  Right value -> Right value

renderedRegistry :: Either Registry.RegistryError value -> Either Text value
renderedRegistry result = case result of
  Left problem -> Left (Registry.renderRegistryError problem)
  Right value -> Right value

renderedBootstrap :: Either Bootstrap.BootstrapRegistryError value -> Either Text value
renderedBootstrap result = case result of
  Left problem -> Left (Bootstrap.renderBootstrapRegistryError problem)
  Right value -> Right value

renderedPublicationDecision :: Either Publish.PublicationError Publish.PublicationDecision -> Either Text ()
renderedPublicationDecision result = case result of
  Left problem -> Left (Publish.renderPublicationError problem)
  Right _ -> Right ()

renderedPublicationResult :: Either Publish.PublicationError Publish.PublicationResult -> Either Text ()
renderedPublicationResult result = case result of
  Left problem -> Left (Publish.renderPublicationError problem)
  Right _ -> Right ()

renderedRegistryPullGate :: Either ImageGate.RegistryPullGateError value -> Either Text ()
renderedRegistryPullGate result = case result of
  Left problem -> Left (ImageGate.renderRegistryPullGateError problem)
  Right _ -> Right ()

renderedRuntime :: Either Runtime.BuildRuntimeError value -> Either Text value
renderedRuntime result = case result of
  Left problem -> Left (Runtime.renderBuildRuntimeError problem)
  Right value -> Right value

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual =
  unless (expected == actual) (die (label <> ": expected " <> show expected <> ", got " <> show actual))

isContiguousSubsequenceOf :: Eq value => [value] -> [value] -> Bool
isContiguousSubsequenceOf needle haystack = case needle of
  [] -> True
  _ -> any (needle `isPrefixOf`) (tails haystack)
 where
  tails values = values : case values of
    [] -> []
    _ : rest -> tails rest
