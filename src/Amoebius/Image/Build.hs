{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Image.Build (
    runRenderBakeDockerfile,
    runAdmittedBuildxOci,
    runBakeInventory,
) where

import Amoebius.Image.BakeInventory (
    BakeCatalog (..),
    BakeStep,
    catalogBuildEnvelope,
    catalogSteps,
    stepLastResortReason,
    stepName,
    stepRung,
    stepSourceImage,
    validateBakeCatalog,
 )
import Amoebius.Image.BuildAdmission (
    ObservedBuildHost (..),
    admitBuildTarget,
 )
import Amoebius.Image.BuildRuntime (
    BuildEnactmentResult (..),
    BuildRequest (..),
    enactBuildAction,
    prepareBuildAction,
 )
import Amoebius.Image.CanonicalBakeCatalog (canonicalBakeCatalog)
import Amoebius.Image.RenderDockerfile (dockerfileText, renderDockerfile)
import Data.Aeson ((.=))
import Data.Aeson qualified as Aeson
import Data.ByteString.Lazy.Char8 qualified as LazyChar8
import Data.Map.Strict qualified as Map
import Data.Maybe (catMaybes)
import Data.Set qualified as Set
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import Numeric.Natural (Natural)
import System.Exit (ExitCode (..), die, exitWith)
import System.Process.Typed qualified as Process
import Text.Read (readMaybe)

-- | Report the acquisition rung carried by each typed Haskell catalog step.
runBakeInventory :: [String] -> IO ()
runBakeInventory arguments = case arguments of
    ["--json"] -> emit
    _ -> die "bake-inventory requires --json"
  where
    emit = do
        either (die . show) pure (validateBakeCatalog canonicalBakeCatalog)
        LazyChar8.putStrLn . Aeson.encode $
            Aeson.object
                [ "baseImage" .= canonicalBakeCatalog.baseImage
                , "steps" .= fmap describeStep (catalogSteps canonicalBakeCatalog)
                ]

describeStep :: BakeStep -> Aeson.Value
describeStep step =
    Aeson.object $
        [ "name" .= stepName step
        , "rung" .= stepRung step
        ]
            <> catMaybes
                [ ("lastResortReason" .=) <$> stepLastResortReason step
                , ("sourceImage" .=) <$> stepSourceImage step
                ]

runRenderBakeDockerfile :: [String] -> IO ()
runRenderBakeDockerfile arguments = case arguments of
    [] -> do
        rendered <- either (die . show) pure (renderDockerfile canonicalBakeCatalog)
        Text.putStr rendered.dockerfileText
    _ -> die "render-bake-dockerfile takes no arguments"

{- | Live Phase-25.1 entry point.  The fixed positional surface is deliberate:
every observed capacity and every process path is explicit, the admitted
action fixes the two-platform OCI export, and the subprocess receives no
ambient environment.
-}
runAdmittedBuildxOci :: [String] -> IO ()
runAdmittedBuildxOci arguments = case arguments of
    [ fingerprint
        , residualCpuText
        , residualMemoryText
        , scratchBytesText
        , cacheBytesText
        , cacheResidentText
        , dockerExecutable
        , dockerHost
        , testRoot
        , dockerConfig
        , builderName
        , dockerfile
        , context
        , ociOutput
        , cacheRoot
        , scratchRoot
        , buildkitConfig
        , buildkitImage
        , buildkitContainer
        , stateVolume
        ] -> do
            residualCpu <- parseNatural "residual CPU" residualCpuText
            residualMemory <- parseNatural "residual memory" residualMemoryText
            scratchBytes <- parseNatural "scratch bytes" scratchBytesText
            cacheBytes <- parseNatural "cache bytes" cacheBytesText
            cacheResident <- parseNatural "cache resident bytes" cacheResidentText
            either (die . show) pure (validateBakeCatalog canonicalBakeCatalog)
            let observed = observedHost canonicalBakeCatalog fingerprint residualCpu residualMemory scratchBytes cacheBytes cacheResident
            target <- admitBuildTarget (catalogBuildEnvelope canonicalBakeCatalog) observed >>= either (die . show) pure
            action <-
                prepareBuildAction
                    target
                    observed
                    BuildRequest
                        { buildDockerExecutable = dockerExecutable
                        , buildDockerHost = Text.pack dockerHost
                        , buildTestRoot = testRoot
                        , buildDockerConfig = dockerConfig
                        , buildBuilderName = Text.pack builderName
                        , buildDockerfile = dockerfile
                        , buildContext = context
                        , buildOciOutput = ociOutput
                        , buildCacheRoot = cacheRoot
                        , buildScratchRoot = scratchRoot
                        , buildBuildkitConfig = buildkitConfig
                        , buildBuildkitImage = Text.pack buildkitImage
                        , buildBuildkitContainer = Text.pack buildkitContainer
                        , buildStateVolume = Text.pack stateVolume
                        }
                    >>= either (die . show) pure
            result <- enactBuildAction action observed runWithoutEnvironment >>= either (die . show) pure
            case result of
                BuildSucceeded -> putStrLn "admitted-buildx-oci: PASS"
                BuildFailed status -> exitWith (ExitFailure status)
    _ ->
        die
            "admitted-buildx-oci requires FINGERPRINT CPU_MILLIS MEMORY_BYTES SCRATCH_BYTES CACHE_BYTES CACHE_RESIDENT_BYTES DOCKER DOCKER_HOST TEST_ROOT DOCKER_CONFIG BUILDER DOCKERFILE CONTEXT OCI_OUTPUT CACHE_ROOT SCRATCH_ROOT BUILDKIT_CONFIG BUILDKIT_IMAGE BUILDKIT_CONTAINER STATE_VOLUME"

observedHost ::
    BakeCatalog ->
    String ->
    Natural ->
    Natural ->
    Natural ->
    Natural ->
    Natural ->
    ObservedBuildHost
observedHost catalog fingerprint cpu memory scratch cache resident =
    ObservedBuildHost
        { observedBuildFingerprint = Text.pack fingerprint
        , observedResidualCpuMillis = cpu
        , observedResidualMemoryBytes = memory
        , observedBackingCapacities =
            Map.fromList
                [ (catalog.scratchBacking, scratch)
                , (catalog.cacheBacking, cache)
                ]
        , observedCacheResidents = Map.singleton catalog.cacheBacking resident
        , observedArchitectureConcurrency = catalog.architectureConcurrency
        , observedStageConcurrency = catalog.stageConcurrency
        , observedUnknownCommitments = Set.empty
        }

runWithoutEnvironment :: FilePath -> [String] -> IO ExitCode
runWithoutEnvironment executable arguments =
    Process.runProcess (Process.setEnv [] (Process.proc executable arguments))

parseNatural :: String -> String -> IO Natural
parseNatural label value = case readMaybe value of
    Just parsed -> pure parsed
    Nothing -> die ("invalid " <> label <> ": " <> value)
