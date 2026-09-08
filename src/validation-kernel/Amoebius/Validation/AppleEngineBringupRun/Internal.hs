{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.AppleEngineBringupRun.Internal
  ( AcquiredAppleEngineBringupRun
  , acquireAppleEngineBringupRun
  , acquireAppleEngineBringupRefreshRun
  , acquiredAppleEngineBringupRunCheck
  , foldAcquiredAppleEngineBringupRun
  ) where

import Amoebius.Host.AppleEngine
  ( AppleFloorObservation (..), AppleProvider (ColimaProvider), AppleWorkload (ContainerImageBuild)
  , FrameDemand (..), FrameSupply (..)
  , admitAppleFloor, admitFrameDemand, admitNativeArm64
  , colimaSshArgv, colimaStartArgv, colimaStatusArgv, colimaStopArgv
  , dockerArchitectureArgv, liftLinuxSteps, providerBrewTool, providerFor )
import Amoebius.Host.Ensure
  ( AbsExe, Argument (..), InstallStep (..), Performer (..), absExePath, mkAbsExe )
import Amoebius.Host.HostTool (HostTool (DiskObserver), requirementVersion)
import Amoebius.Host.Reconciler (installPlan)
import Amoebius.Host.Substrate (Substrate (Apple, LinuxCpu))
import Amoebius.Substrate.Brew (BrewEnsurePlan (..), BrewTool (DockerClient), planBrewEnsure)
import Amoebius.Validation.BootstrapTrust.Internal
  ( GenesisTrust, genesisTrustCheck, genesisTrustCompilerExecutable, genesisTrustToolchainIdentity )
import Amoebius.Validation.PhaseContract.Internal
  ( AcquiredPhaseContractEvidence, acquirePhaseContractEvidenceFor
  , acquireRecordedPhaseContractEvidence, acquiredPhaseContractEvidenceCheck )
import Amoebius.Validation.SourceClosure.Internal
  ( AcquiredSourceSnapshot, IndexEntry (indexPath), SourceSnapshot (snapshotEntries, snapshotIdentity)
  , TrackedEntry (trackedIndex), acquiredSourceSnapshot )
import Amoebius.Validation.Types (CheckResult (..), Finding, finding, mergeChecks, observation)
import Data.Aeson (FromJSON (parseJSON), eitherDecodeStrict', withObject, (.:))
import Control.Exception (SomeException, displayException, mask, try)
import Control.Monad (forM, forM_, unless, when)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString qualified as ByteString
import Data.List (isPrefixOf, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Word (Word64)
import System.Directory
  ( copyFile, createDirectory, createDirectoryIfMissing, doesDirectoryExist
  , doesFileExist, getHomeDirectory, listDirectory, removeFile )
import System.Directory qualified as Directory
import System.Environment (getEnvironment)
import System.Exit (ExitCode (..))
import System.FilePath (isAbsolute, makeRelative, normalise, takeFileName, (</>))
import System.Info qualified as Info
import System.IO (hClose, openBinaryTempFile)
import System.Posix.Process (getProcessID)
import System.Process (CreateProcess (cwd, env), proc, readCreateProcessWithExitCode)
import Text.Read (readMaybe)

data Receipt = Receipt Text FilePath [String] ExitCode Text Text Text deriving (Eq, Show)
data Mutant = Mutant Text Text Text Receipt deriving (Eq, Show)
data Matrix = Matrix [Mutant] Receipt

data ColimaInstance = ColimaInstance
  { instanceName :: Text
  , instanceStatus :: Text
  , instanceArchitecture :: Text
  , instanceCpu :: Word64
  , instanceMemory :: Word64
  , instanceDisk :: Word64
  , instanceRuntime :: Text
  }
  deriving stock (Eq, Show)

instance FromJSON ColimaInstance where
  parseJSON = withObject "ColimaInstance" $ \value -> ColimaInstance
    <$> value .: "name"
    <*> value .: "status"
    <*> value .: "arch"
    <*> value .: "cpus"
    <*> value .: "memory"
    <*> value .: "disk"
    <*> value .: "runtime"

data LiveObservation = LiveObservation
  { liveProfile :: Text
  , livePreflight :: Text
  , liveProviderBefore :: Text
  , liveProviderAfter :: Text
  , liveEndpoint :: Text
  , liveFrameCarve :: Text
  , liveFrameArchitecture :: Text
  , liveEngineArchitecture :: Text
  , liveEmulationRegistrations :: Text
  , liveImageArchitecture :: Text
  , liveContainerOutput :: Text
  , liveLiftedPlanOutput :: [Text]
  , liveLiftedOutput :: Text
  , liveReceipts :: [Receipt]
  }

data AcquiredAppleEngineBringupRun
  = AcquiredAppleEngineBringupRun
      AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
      Text Text Text Text Text Text Text Text CheckResult

acquiredAppleEngineBringupRunCheck :: AcquiredAppleEngineBringupRun -> CheckResult
acquiredAppleEngineBringupRunCheck (AcquiredAppleEngineBringupRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredAppleEngineBringupRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredAppleEngineBringupRun
  -> value
foldAcquiredAppleEngineBringupRun consume (AcquiredAppleEngineBringupRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanupEvidence result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanupEvidence result

acquireAppleEngineBringupRun, acquireAppleEngineBringupRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredAppleEngineBringupRun
acquireAppleEngineBringupRun = acquire False
acquireAppleEngineBringupRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredAppleEngineBringupRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  home <- getHomeDirectory
  let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
      compiler = genesisTrustCompilerExecutable trust
      store = home </> ".cabal/store"
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 53 acquired
  cache <- prepareSourceRepositoryCache root runRoot
  matrix <- executeQualificationMatrix root runRoot cabal compiler store
  liveResult <- try (executeLive root runRoot) :: IO (Either SomeException LiveObservation)
  discipline <- sourceDisciplineCheck acquired
  let toolchain = toolchainCheck cabal compiler store matrix
      oracle = oracleCheck matrix liveResult
      positives = positiveCheck matrix liveResult
      negatives = negativeCheck matrix
      mutants = mutantCheck matrix
      discovery = discoveryCheck discipline liveResult
      challenge = challengeCheck liveResult
      observer = observerCheck liveResult
      authority = authorityCheck root runRoot cabal compiler store matrix liveResult
      freshness = freshnessCheck root runRoot liveResult
      qualification = mergeChecks "apple-engine-bringup-qualification" [toolchain, negatives, mutants]
      cleanroom = mergeChecks "apple-engine-bringup-cleanroom" [cache, cleanupCheck liveResult]
      legacy = mergeChecks "apple-engine-bringup-legacy-closure" [discipline, mutants]
      prerequisite = mergeChecks "apple-engine-bringup-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, toolchain, oracle, positives, negatives, mutants, discovery, challenge, observer, authority, freshness, qualification, cleanroom]
      rows = phaseRows prerequisite toolchain oracle positives negatives mutants discovery challenge observer authority freshness qualification cleanroom legacy
      result = mergeChecks "apple-engine-bringup" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "apple-engine-bringup-subject" [checkDigest discipline, liveDigest liveResult]
      oracleId = ids "apple-engine-bringup-oracle" [checkDigest oracle, checkDigest negatives]
      harnessId = ids "apple-engine-bringup-harness" (map receiptDigest (matrixReceipts matrix) <> [liveDigest liveResult])
      observerId = ids "apple-engine-bringup-observer" [checkDigest observer]
      qualificationId = ids "apple-engine-bringup-qualification" [checkDigest qualification]
      acquiredRunId = ids "apple-engine-bringup-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "apple-engine-bringup-toolchain" [genesisTrustToolchainIdentity trust, checkDigest toolchain]
      cleanupEvidence = case liveResult of
        Right live -> "profile=" <> liveProfile live <> ";deleted=true;provider-inventory-restored=" <> truth (liveProviderBefore live == liveProviderAfter live) <> ";external-residue=0"
        Left problem
          | "phase53-physical-apple-silicon-required" `Text.isInfixOf` renderedProblem ->
              "profile=not-acquired;deleted=not-required;external-residue=0;live-error=" <> renderedProblem
          | otherwise -> "profile=unknown;deleted=attempted;live-error=" <> renderedProblem
         where renderedProblem = Text.pack (displayException problem)
  pure (AcquiredAppleEngineBringupRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanupEvidence result)

executeQualificationMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> IO Matrix
executeQualificationMatrix root runRoot cabal compiler store = do
  clean <- runSpec "qualification-clean" Nothing
  mutants <- mapM runMutant mutantSpecifications
  pure (Matrix mutants clean)
 where
  common = ["--builddir=" <> runRoot </> "dist", "--store-dir=" <> store, "--with-compiler=" <> compiler, "--jobs=1", "--offline"]
  runMutant (name, flagName, locus, expected) = Mutant name locus expected <$> runSpec name (Just flagName)
  runSpec name selected = runProcess root name cabal
    (common <> ["test", "apple-engine-bringup-spec", "--offline", "--test-show-details=direct"]
      <> [if Just flagName == selected then "-f" <> flagName else "-f-" <> flagName | (_, flagName, _, _) <- mutantSpecifications])

mutantSpecifications :: [(Text, String, Text, Text)]
mutantSpecifications =
  [ row "installs-floor" "apple-engine-installs-floor-mutant" "floor.homebrew-refusal" "apple-engine-bringup-mutant: RED installs-floor homebrew-refusal"
  , row "wrong-provider" "apple-engine-wrong-provider-mutant" "provider.image-build" "apple-engine-bringup-mutant: RED wrong-provider image-build-selection"
  , row "leaks-ephemeral" "apple-engine-leaks-ephemeral-mutant" "lifecycle.ephemeral" "apple-engine-bringup-mutant: RED leaks-ephemeral lifecycle"
  , row "default-frame" "apple-engine-default-frame-mutant" "frame.checked-carve" "apple-engine-bringup-mutant: RED default-frame checked-carve"
  , row "reauthors-lift" "apple-engine-reauthors-lift-mutant" "lift.unchanged-linux-step" "apple-engine-bringup-mutant: RED reauthors-lift unchanged-linux-step"
  , row "allows-emulation" "apple-engine-allows-emulation-mutant" "architecture.no-emulation" "apple-engine-bringup-mutant: RED allows-emulation native-arm64"
  ]
 where row name flagName locus expected = (name, flagName, locus, expected)

executeLive :: FilePath -> FilePath -> IO LiveObservation
executeLive root runRoot = do
  unless (Info.os == "darwin" && Info.arch == "aarch64")
    (fail ("phase53-physical-apple-silicon-required:observed=" <> Info.os <> "/" <> Info.arch))
  home <- getHomeDirectory
  process <- show <$> getProcessID
  let profile = "amoebius-phase53-" <> process
      profileId = Text.pack profile
      imageRef = profile <> "-cpu-arm64:local"
      context = "colima-" <> profile
      dockerfile = runRoot </> "Dockerfile"
      demand = FrameDemand 4 (8 * gib) (40 * gib)
      boundaryShims = ["package-manager-root", "ghcup"]
  unless (all safeOwnerCharacter profile && "amoebius-phase53-" `isPrefixOf` profile)
    (fail "phase53-unsafe-profile-name")
  uname <- requireExecutable "/usr/bin/uname"
  xcode <- requireExecutable "/usr/bin/xcode-select"
  brew <- requireExecutable "/opt/homebrew/bin/brew"
  sysctl <- requireExecutable "/usr/sbin/sysctl"
  diskObserver <- requireExecutable "/bin/df"
  osReceipt <- require "host-os" =<< runProcess root "host-os" uname ["-s"]
  archReceipt <- require "host-architecture" =<< runProcess root "host-architecture" uname ["-m"]
  xcodeReceipt <- require "xcode-floor" =<< runProcess root "xcode-floor" xcode ["-p"]
  brewReceipt <- require "homebrew-floor" =<< runProcess root "homebrew-floor" brew ["--prefix"]
  unless (receiptStdout osReceipt == "Darwin\n" && receiptStdout archReceipt == "arm64\n") (fail "phase53-platform-preflight-mismatch")
  let brewPrefix = Text.unpack (Text.strip (receiptStdout brewReceipt))
      colimaPath = brewPrefix </> "bin/colima"
      dockerPath = brewPrefix </> "bin/docker"
      xcodePath = Text.unpack (Text.strip (receiptStdout xcodeReceipt))
  unless (brewPrefix == "/opt/homebrew") (fail ("phase53-noncanonical-homebrew-prefix:" <> brewPrefix))
  either (fail . ("phase53-floor-refused:" <>) . show) pure
    (admitAppleFloor (AppleFloorObservation "darwin" "arm64" (Just brew) (Just xcodePath)))
  cpuReceipt <- require "host-cpu-capacity" =<< runProcess root "host-cpu-capacity" sysctl ["-n", "hw.ncpu"]
  memoryReceipt <- require "host-memory-capacity" =<< runProcess root "host-memory-capacity" sysctl ["-n", "hw.memsize"]
  diskReceipt <- require "host-disk-capacity" =<< runProcess root "host-disk-capacity" diskObserver ["-kP", home]
  supply <- parseFrameSupply cpuReceipt memoryReceipt diskReceipt
  admitted <- either (fail . ("phase53-frame-demand-refused:" <>) . show) pure (admitFrameDemand supply demand)
  provider <- either (fail . ("phase53-provider-selection-refused:" <>) . show) pure (providerFor Apple ContainerImageBuild)
  unless (provider == ColimaProvider) (fail ("phase53-provider-selection-mismatch:" <> show provider))
  colimaInitially <- doesFileExist colimaPath
  colimaEnsure <- either (fail . ("phase53-colima-ensure-plan-refused:" <>)) pure
    (planBrewEnsure brew (if colimaInitially then Just colimaPath else Nothing) (providerBrewTool provider))
  (colimaInstall, colima) <- executeBrewEnsure root "colima" colimaEnsure
  dockerInitially <- doesFileExist dockerPath
  dockerEnsure <- either (fail . ("phase53-docker-ensure-plan-refused:" <>)) pure
    (planBrewEnsure brew (if dockerInitially then Just dockerPath else Nothing) DockerClient)
  (dockerInstall, docker) <- executeBrewEnsure root "docker-client" dockerEnsure
  beforeReceipt <- require "provider-inventory-before" =<< runProcess root "provider-inventory-before" (absExePath colima) ["list", "--json"]
  contextBefore <- require "docker-context-inventory-before" =<< runProcess root "docker-context-inventory-before" (absExePath docker) ["context", "ls", "--format", "{{.Name}}"]
  activeContextBefore <- require "docker-active-context-before" =<< runProcess root "docker-active-context-before" (absExePath docker) ["context", "show"]
  when (any (profileId `Text.isInfixOf`) [receiptStdout beforeReceipt, receiptStdout contextBefore]) (fail "phase53-owner-marker-already-present")
  writeFile dockerfile (unlines ["FROM ubuntu:24.04", "ENTRYPOINT [\"/usr/bin/uname\",\"-m\"]"])
  (bodyResult, cleanupReceipts) <- mask $ \restore -> do
    bodyResult <- try (restore (do
      start <- require "colima-start" =<< runArgv root "colima-start" (colimaStartArgv colima profile admitted)
      status <- require "colima-status" =<< runArgv root "colima-status" (colimaStatusArgv colima profile)
      frameCarve <- require "frame-carve-observation" =<< runProcess root "frame-carve-observation" (absExePath colima) ["list", "--json"]
      either (fail . ("phase53-frame-carve-observation-refused:" <>)) pure (verifyFrameCarve profile admitted frameCarve)
      endpoint <- require "docker-endpoint" =<< runArgv root "docker-endpoint" (dockerArchitectureArgv docker context)
      frameArch <- require "frame-architecture" =<< runProcess root "frame-architecture" (absExePath colima) ["ssh", "--profile", profile, "--", "/usr/bin/uname", "-m"]
      binfmtRoot <- runProcess root "emulation-root-probe" (absExePath colima)
        ["ssh", "--profile", profile, "--", "/usr/bin/test", "-d", "/proc/sys/fs/binfmt_misc"]
      (emulationReceipts, emulationOutput) <- case receiptExit binfmtRoot of
        ExitSuccess -> do
          inventory <- require "emulation-inventory" =<< runProcess root "emulation-inventory" (absExePath colima)
            ["ssh", "--profile", profile, "--", "/usr/bin/find", "/proc/sys/fs/binfmt_misc", "-mindepth", "1", "-maxdepth", "1", "-type", "f", "!", "-name", "status", "!", "-name", "register", "-print"]
          pure ([binfmtRoot, inventory], receiptStdout inventory)
        ExitFailure 1 -> pure ([binfmtRoot], "")
        exitStatus -> fail ("phase53-emulation-root-probe-failed:" <> show exitStatus <> ":" <> Text.unpack (receiptOutput binfmtRoot))
      either (fail . ("phase53-native-architecture-refused:" <>) . show) pure
        (admitNativeArm64 "arm64" (Text.unpack (Text.strip (receiptStdout frameArch))) (Text.unpack (Text.strip (receiptStdout endpoint))) (not (Text.null (Text.strip emulationOutput))))
      shimPreflights <- forM (zip [1 :: Int ..] boundaryShims) $ \(ordinal, shim) ->
        require ("lift-shim-preflight-" <> show ordinal) =<< runProcess root (Text.pack ("lift-shim-preflight-" <> show ordinal)) (absExePath colima)
          ["ssh", "--profile", profile, "--", "/bin/sh", "-c", "test ! -e \"$1\" && test ! -L \"$1\"", "phase53-shim-preflight", "/usr/local/bin/" <> shim]
      shimCreates <- forM (zip [1 :: Int ..] boundaryShims) $ \(ordinal, shim) ->
        require ("lift-shim-create-" <> show ordinal) =<< runProcess root (Text.pack ("lift-shim-create-" <> show ordinal)) (absExePath colima)
          ["ssh", "--profile", profile, "--", "/usr/bin/sudo", "/bin/ln", "--symbolic", "--", "/bin/echo", "/usr/local/bin/" <> shim]
      liftedPlan <- either (fail . ("phase53-lift-plan-refused:" <>)) pure
        (liftLinuxSteps colima requirementVersion (installPlan LinuxCpu))
      unless (length liftedPlan == length expectedLiftedPlanOutput)
        (fail ("phase53-lifted-plan-row-count:" <> show (length liftedPlan)))
      liftedPlanArgv <- traverse (either (fail . ("phase53-colima-plan-lift-refused:" <>) . show) pure . colimaSshArgv colima profile) liftedPlan
      liftedPlanReceipts <- forM (zip [1 :: Int ..] liftedPlanArgv) $ \(ordinal, argv) ->
        require ("lifted-linux-plan-" <> show ordinal) =<< runArgv root (Text.pack ("lifted-linux-plan-" <> show ordinal)) argv
      unless (map receiptStdout liftedPlanReceipts == expectedLiftedPlanOutput)
        (fail ("phase53-lifted-plan-observation-mismatch:" <> show (map receiptStdout liftedPlanReceipts)))
      lifted <- either (fail . ("phase53-lift-refused:" <>)) pure
        (liftLinuxSteps colima requirementVersion [InstallStep DiskObserver (PerformedBy DiskObserver) [Literal "-kP", Literal "/"]])
      liftedArgv <- case lifted of
        [row] -> either (fail . ("phase53-colima-lift-refused:" <>) . show) pure (colimaSshArgv colima profile row)
        rows -> fail ("phase53-lifted-row-count:" <> show (length rows))
      liftedReceipt <- require "lifted-linux-step" =<< runArgv root "lifted-linux-step" liftedArgv
      imageAbsent <- requireFailure "owned-image-preflight" =<< runProcess root "owned-image-preflight" (absExePath docker) ["--context", context, "image", "inspect", imageRef]
      build <- require "native-image-build" =<< runProcess root "native-image-build" (absExePath docker) ["--context", context, "build", "--pull", "--no-cache", "--tag", imageRef, "--file", dockerfile, runRoot]
      imageArch <- require "image-architecture" =<< runProcess root "image-architecture" (absExePath docker) ["--context", context, "image", "inspect", "--format", "{{.Architecture}}", imageRef]
      output <- require "native-image-run" =<< runProcess root "native-image-run" (absExePath docker) ["--context", context, "run", "--rm", imageRef]
      pure (start, status, frameCarve, endpoint, frameArch, emulationReceipts, emulationOutput, shimPreflights, shimCreates, liftedPlanReceipts, liftedReceipt, imageAbsent, build, imageArch, output)))
      :: IO (Either SomeException (Receipt, Receipt, Receipt, Receipt, Receipt, [Receipt], Text, [Receipt], [Receipt], [Receipt], Receipt, Receipt, Receipt, Receipt, Receipt))
    cleanupReceipts <- cleanup root colima docker profile context imageRef
    pure (bodyResult, cleanupReceipts)
  observations <- case bodyResult of
    Left problem -> fail ("phase53-live-body-failed:" <> displayException problem <> ";cleanup=" <> show (map receiptSummary cleanupReceipts))
    Right value -> do
      forM_ cleanupReceipts (require "owned-live-cleanup")
      pure value
  afterReceipt <- require "provider-inventory-after" =<< runProcess root "provider-inventory-after" (absExePath colima) ["list", "--json"]
  contextAfter <- require "docker-context-inventory-after" =<< runProcess root "docker-context-inventory-after" (absExePath docker) ["context", "ls", "--format", "{{.Name}}"]
  activeContextAfter <- require "docker-active-context-after" =<< runProcess root "docker-active-context-after" (absExePath docker) ["context", "show"]
  let (start, status, frameCarve, endpoint, frameArch, emulationReceipts, emulationOutput, shimPreflights, shimCreates, liftedPlanReceipts, liftedReceipt, imageAbsent, build, imageArch, output) = observations
      receipts = [osReceipt, archReceipt, xcodeReceipt, brewReceipt, cpuReceipt, memoryReceipt, diskReceipt]
        <> colimaInstall <> dockerInstall
        <> [beforeReceipt, contextBefore, activeContextBefore, start, status, frameCarve, endpoint, frameArch]
        <> emulationReceipts
        <> shimPreflights <> shimCreates <> liftedPlanReceipts
        <> [liftedReceipt, imageAbsent, build, imageArch, output]
        <> cleanupReceipts <> [afterReceipt, contextAfter, activeContextAfter]
  pure LiveObservation
    { liveProfile = profileId, livePreflight = Text.concat (map receiptStdout [osReceipt, archReceipt, xcodeReceipt, brewReceipt, cpuReceipt, memoryReceipt, diskReceipt])
    , liveProviderBefore = Text.intercalate "\NUL" (map receiptStdout [beforeReceipt, contextBefore, activeContextBefore])
    , liveProviderAfter = Text.intercalate "\NUL" (map receiptStdout [afterReceipt, contextAfter, activeContextAfter])
    , liveEndpoint = receiptStdout endpoint, liveFrameCarve = receiptStdout frameCarve
    , liveFrameArchitecture = receiptStdout frameArch
    , liveEngineArchitecture = receiptStdout endpoint, liveEmulationRegistrations = emulationOutput
    , liveImageArchitecture = receiptStdout imageArch
    , liveContainerOutput = receiptStdout output
    , liveLiftedPlanOutput = map receiptStdout liftedPlanReceipts
    , liveLiftedOutput = receiptStdout liftedReceipt
    , liveReceipts = receipts }

cleanup :: FilePath -> AbsExe -> AbsExe -> String -> String -> String -> IO [Receipt]
cleanup root colima docker profile context imageRef = do
  imageDelete <- captureCleanup root "owned-image-delete" (absExePath docker) ["--context", context, "image", "rm", "--force", imageRef]
  profileDelete <- case colimaStopArgv colima profile of
    executable : arguments -> captureCleanup root "owned-profile-delete" executable arguments
    [] -> pure (cleanupExceptionReceipt "owned-profile-delete" "<empty-argv>" [] "empty cleanup argv")
  pure [imageDelete, profileDelete]

-- Cleanup must be total enough to attempt the next exact owner even when launching
-- the preceding cleanup process fails.  The synthetic red receipt preserves the
-- failure as evidence; it can never be mistaken for successful teardown.
captureCleanup :: FilePath -> Text -> FilePath -> [String] -> IO Receipt
captureCleanup root name executable arguments = do
  result <- try (runProcess root name executable arguments) :: IO (Either SomeException Receipt)
  pure (either (cleanupExceptionReceipt name executable arguments . Text.pack . displayException) id result)

cleanupExceptionReceipt :: Text -> FilePath -> [String] -> Text -> Receipt
cleanupExceptionReceipt name executable arguments problem =
  Receipt name executable arguments (ExitFailure 125) "" problem
    (digestTexts [name, Text.pack executable, Text.pack (show arguments), "ExitFailure 125", problem])

executeBrewEnsure :: FilePath -> String -> BrewEnsurePlan -> IO ([Receipt], AbsExe)
executeBrewEnsure root label ensurePlan = case ensurePlan of
  AlreadyPresent path -> do
    resolved <- requireExecutable path >>= requireAbsExe
    pure ([], resolved)
  InstallThenResolve argv expectedPath -> do
    installReceipt <- require (label <> "-install") =<< runArgv root (Text.pack (label <> "-install")) argv
    resolved <- requireExecutable expectedPath >>= requireAbsExe
    pure ([installReceipt], resolved)

verifyFrameCarve :: String -> FrameDemand -> Receipt -> Either String ()
verifyFrameCarve profile demanded receipt = do
  instances <- traverse decodeLine (filter (not . Text.null . Text.strip) (Text.lines (receiptStdout receipt)))
  case filter ((== Text.pack profile) . instanceName) instances of
    [observed]
      | instanceStatus observed == "Running"
      , instanceArchitecture observed == "aarch64"
      , instanceCpu observed == demandedCpuCores demanded
      , instanceMemory observed == demandedMemoryBytes demanded
      , instanceDisk observed == demandedDiskBytes demanded
      , instanceRuntime observed == "docker" -> Right ()
      | otherwise -> Left ("expected=" <> show demanded <> ";observed=" <> show observed)
    matches -> Left ("owner-profile-count=" <> show (length matches) <> ";profiles=" <> show (map instanceName instances))
 where
  decodeLine line = eitherDecodeStrict' (TextEncoding.encodeUtf8 line)

parseFrameSupply :: Receipt -> Receipt -> Receipt -> IO FrameSupply
parseFrameSupply cpuReceipt memoryReceipt diskReceipt = do
  cpu <- parseNatural "cpu" (receiptStdout cpuReceipt)
  memory <- parseNatural "memory" (receiptStdout memoryReceipt)
  diskBlocks <- case reverse (filter (not . null) (lines (Text.unpack (receiptStdout diskReceipt)))) of
    row : _ | length (words row) >= 4 -> parseNatural "disk" (Text.pack (words row !! 3))
    _ -> fail "phase53-capacity-parse:disk:missing-df-row"
  pure (FrameSupply cpu memory (diskBlocks * 1024))

parseNatural :: String -> Text -> IO Word64
parseNatural label value = case readMaybe (Text.unpack (Text.strip value)) of
  Just parsed -> pure parsed
  Nothing -> fail ("phase53-capacity-parse:" <> label <> ":" <> Text.unpack value)

requireAbsExe :: FilePath -> IO AbsExe
requireAbsExe path = either (fail . ("phase53-non-absolute-executable:" <>) . show) pure (mkAbsExe path)

runArgv :: FilePath -> Text -> [String] -> IO Receipt
runArgv root name argv = case argv of
  executable : arguments -> runProcess root name executable arguments
  [] -> fail ("phase53-empty-argv:" <> Text.unpack name)

toolchainCheck :: FilePath -> FilePath -> FilePath -> Matrix -> CheckResult
toolchainCheck cabal compiler store matrix = CheckResult "apple-engine-bringup-toolchain"
  [observation "apple-engine.compiler" (Text.pack compiler), observation "apple-engine.cabal" (Text.pack cabal)]
  [finding "APPLE-ENGINE-TOOLCHAIN" (Text.unpack name) "qualification row did not use absolute pinned compiler/store, --jobs=1, and --offline" |
    Receipt name executable args _ _ _ _ <- matrixReceipts matrix,
    executable /= cabal || not (isAbsolute compiler) || not (isAbsolute store) || "--jobs=1" `notElem` args || "--offline" `notElem` args]

oracleCheck :: Matrix -> Either SomeException LiveObservation -> CheckResult
oracleCheck matrix liveResult = CheckResult "apple-engine-bringup-independent-oracle"
  [observation "apple-engine.oracle-independence" "AppleEngineBringupOracle imports no production module"]
  ([finding "APPLE-ENGINE-ORACLE" "test/spec/host/AppleEngineBringupOracle.hs" "independent qualification oracle did not accept clean production subject" |
      receiptExit (cleanReceipt matrix) /= ExitSuccess || notContains qualificationAcceptance (receiptOutput (cleanReceipt matrix))] <>
   case liveResult of Left problem -> [liveFinding "APPLE-ENGINE-LIVE" problem]; Right _ -> [])

positiveCheck :: Matrix -> Either SomeException LiveObservation -> CheckResult
positiveCheck matrix liveResult = CheckResult "apple-engine-bringup-positive-controls"
  [observation "apple-engine.qualification" (receiptSummary (cleanReceipt matrix))]
  (case liveResult of
    Left problem -> [liveFinding "APPLE-ENGINE-POSITIVE" problem]
    Right live ->
      [finding "APPLE-ENGINE-NATIVE" "phase-53-live" "frame, engine, image, or running container was not native arm64, or a foreign-architecture interpreter was registered" |
        not (arm64 (liveFrameArchitecture live) && arm64 (liveEngineArchitecture live) && arm64 (liveImageArchitecture live) && arm64 (liveContainerOutput live) && Text.null (Text.strip (liveEmulationRegistrations live)))] <>
      [finding "APPLE-ENGINE-LIFTED-PLAN" "phase-53-live" "complete lifted Linux plan did not cross the owned Colima boundary with exact observed arguments" |
        liveLiftedPlanOutput live /= expectedLiftedPlanOutput])

negativeCheck :: Matrix -> CheckResult
negativeCheck matrix = CheckResult "apple-engine-bringup-paired-negatives"
  [observation "apple-engine.negatives" "three floor, non-Apple, three fit, architecture, emulation, and lifecycle negatives"]
  [finding "APPLE-ENGINE-NEGATIVE" "apple-engine-bringup-spec" "clean qualification row did not pass every paired negative" |
    receiptExit (cleanReceipt matrix) /= ExitSuccess || notContains qualificationAcceptance (receiptOutput (cleanReceipt matrix))]

mutantCheck :: Matrix -> CheckResult
mutantCheck (Matrix mutants _) = CheckResult "apple-engine-bringup-mutants"
  [observation ("apple-engine.mutant." <> name) (receiptSummary receipt <> ";locus=" <> locus) | Mutant name locus _ receipt <- mutants]
  [finding "APPLE-ENGINE-MUTANT" (Text.unpack name) ("changed production subject did not turn red at " <> locus) |
    Mutant name locus expected receipt <- mutants, receiptExit receipt /= ExitFailure 1 || notContains expected (receiptOutput receipt)]

sourceDisciplineCheck :: AcquiredSourceSnapshot -> IO CheckResult
sourceDisciplineCheck acquired = pure (CheckResult "apple-engine-bringup-source-discipline"
  [observation "apple-engine.source-count" (Text.pack (show (length observed)))]
  [finding "APPLE-ENGINE-DISCOVERY" "<phase-53-source-set>" ("expected=" <> Text.pack (show expectedSources) <> ";observed=" <> Text.pack (show observed)) | observed /= expectedSources])
 where observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

discoveryCheck :: CheckResult -> Either SomeException LiveObservation -> CheckResult
discoveryCheck discipline liveResult = mergeChecks "apple-engine-bringup-discovery"
  [discipline, case liveResult of
    Left problem -> CheckResult "apple-engine-live-discovery" [] [liveFinding "APPLE-ENGINE-LIVE-DISCOVERY" problem]
    Right live -> CheckResult "apple-engine-live-discovery" [observation "apple-engine.live-artifacts" "floor;capacity;profile;endpoint;five lifted-linux-plan rows;lifted-linux-step;image-preflight;four architecture reads;emulation inventory;cleanup"]
      [finding "APPLE-ENGINE-LIVE-DISCOVERY" "phase-53-live" "mandatory live observation is empty" |
        any Text.null ([livePreflight live, liveFrameCarve live, liveEndpoint live, liveFrameArchitecture live, liveEngineArchitecture live, liveImageArchitecture live, liveContainerOutput live, liveLiftedOutput live] <> liveLiftedPlanOutput live) || length (liveLiftedPlanOutput live) /= length expectedLiftedPlanOutput]]

challengeCheck :: Either SomeException LiveObservation -> CheckResult
challengeCheck liveResult = CheckResult "apple-engine-bringup-challenge" [observation "apple-engine.challenge" "post-start endpoint, complete lifted-plan transport, and built-image execution"]
  (case liveResult of Left problem -> [liveFinding "APPLE-ENGINE-CHALLENGE" problem]; Right live -> [finding "APPLE-ENGINE-CHALLENGE" "phase-53-live" "post-start endpoint, lifted-plan transport, or container challenge disagreed" | not (arm64 (liveEndpoint live) && liveLiftedPlanOutput live == expectedLiftedPlanOutput && arm64 (liveContainerOutput live))])

observerCheck :: Either SomeException LiveObservation -> CheckResult
observerCheck liveResult = CheckResult "apple-engine-bringup-observer"
  (case liveResult of Right live -> [observation "apple-engine.external.sha256" (digestTexts [Text.unlines (map receiptOutput (liveReceipts live))])]; Left _ -> [])
  (case liveResult of Left problem -> [liveFinding "APPLE-ENGINE-OBSERVER" problem]; Right live -> [finding "APPLE-ENGINE-OBSERVER" "phase-53-live" "external architecture observer disagreed or found emulation registration" | not (all arm64 [liveFrameArchitecture live, liveEngineArchitecture live, liveImageArchitecture live, liveContainerOutput live]) || not (Text.null (Text.strip (liveEmulationRegistrations live)))])

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> Matrix -> Either SomeException LiveObservation -> CheckResult
authorityCheck root runRoot cabal compiler store matrix liveResult = CheckResult "apple-engine-bringup-authority"
  [observation "apple-engine.authority" "unique profile/image; canonical environment roots; no cluster, registry, published tag, cloud, or emulation effects"]
  ([finding "APPLE-ENGINE-RUN-ROOT" runRoot "run root escaped phase-53 work" | not (pathBelow (root </> ".build/runs/phase-53/work") runRoot)] <>
   [finding "APPLE-ENGINE-AUTHORITY" (Text.unpack name) "qualification process exceeded exact serialized compiler authority" |
     Receipt name executable args _ _ _ _ <- matrixReceipts matrix, executable /= cabal || ("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args] <>
   (case liveResult of
      Right live ->
        [ finding "APPLE-ENGINE-BYPASS" "phase-53-live" "forbidden cluster, registry, platform override, or emulation argv observed"
        | any receiptForbidden (liveReceipts live)
        ]
      Left _ -> []))
 where
  receiptForbidden receipt@(Receipt _ executable _ _ _ _ _) = takeFileName executable == "kind" || guestCommand receipt == Just "kind" || any forbidden (receiptArgs receipt)
  guestCommand receipt = case dropWhile (/= "--") (receiptArgs receipt) of
    "--" : command : _ -> Just command
    _ -> Nothing
  forbidden value = value `elem` ["registry:2", "--platform", "--arch=x86_64", "--binfmt=true", "--activate=true", "--kubernetes=true", "--ssh-agent=true", "--ssh-config=true", "--vz-rosetta=true"]
    || "--platform=" `isPrefixOf` value

freshnessCheck :: FilePath -> FilePath -> Either SomeException LiveObservation -> CheckResult
freshnessCheck root runRoot liveResult = CheckResult "apple-engine-bringup-freshness" [observation "apple-engine.fresh-root" (Text.pack (makeRelative root runRoot))]
  ([finding "APPLE-ENGINE-FRESHNESS" runRoot "run root escaped phase-owned work" | not (pathBelow (root </> ".build/runs/phase-53/work") runRoot)] <>
   case liveResult of Right live -> [finding "APPLE-ENGINE-FRESHNESS" (Text.unpack (liveProfile live)) "live profile identity is not unique and phase-owned" | not ("amoebius-phase53-" `Text.isPrefixOf` liveProfile live)]; Left _ -> [])

cleanupCheck :: Either SomeException LiveObservation -> CheckResult
cleanupCheck liveResult = CheckResult "apple-engine-bringup-cleanup" [observation "apple-engine.cleanup" "exact owned image and profile deleted on success and failure"]
  (case liveResult of Left problem -> [liveFinding "APPLE-ENGINE-CLEANUP-UNVERIFIED" problem]; Right live -> [finding "APPLE-ENGINE-RESIDUE" (Text.unpack (liveProfile live)) "provider inventory differs after exact-owner teardown" | liveProviderBefore live /= liveProviderAfter live])

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positives negatives mutants discovery challenge observer authority freshness qualification cleanroom legacy =
  [ named "phase-53-claim" [pre], named "phase-53-subject" [positives]
  , named "phase-53-command" [toolchain, authority], named "phase-53-oracle" [oracle]
  , named "phase-53-positive-controls" [positives], named "phase-53-paired-negatives" [negatives]
  , named "phase-53-mutants" [mutants], named "phase-53-discovery" [discovery]
  , named "phase-53-challenge" [challenge], named "phase-53-observer" [observer]
  , named "phase-53-authority-bypass" [authority], named "phase-53-freshness" [freshness]
  , named "phase-53-qualification" [qualification], named "phase-53-cleanroom" [cleanroom]
  , named "phase-53-legacy-closure" [legacy]
  , CheckResult "phase-53-predecessor" [observation "phase-53.predecessor" "deferred to durable receipt verifier"] []
  , CheckResult "phase-53-residue" [observation "phase-53.residue" "Windows, kind, registry, published images, accelerators, and services remain Phase-54+-owned"] []
  , named "phase-53-pass-criterion" [pre]
  ]

expectedSources :: [FilePath]
expectedSources = sort
  [ "amoebius.cabal"
  , "src/Amoebius/Host/AppleEngine.hs"
  , "src/Amoebius/Substrate/Brew.hs"
  , "src/validation-kernel/Amoebius/Validation/Dispatch/Internal.hs"
  , "src/validation-kernel/Amoebius/Validation/Evidence/Internal.hs"
  , "src/validation-kernel/Amoebius/Validation/PhaseRunner/Internal.hs"
  , "src/validation-kernel/Amoebius/Validation/AppleEngineBringupRun.hs"
  , "src/validation-kernel/Amoebius/Validation/AppleEngineBringupRun/Internal.hs"
  , "test/spec/host/AppleEngineBringupOracle.hs", "test/spec/host/AppleEngineBringupSpec.hs"
  ]

qualificationAcceptance :: Text
qualificationAcceptance = "apple-engine-bringup-spec: PASS (3 floor negatives, 3 brew ensure rows, 3 path negatives, 4 provider rows, 4 lifecycle rows, 3 fit negatives, complete unchanged lift, native arm64, ephemeral teardown)"

cleanReceipt :: Matrix -> Receipt
cleanReceipt (Matrix _ receipt) = receipt
matrixReceipts :: Matrix -> [Receipt]
matrixReceipts (Matrix mutants clean) = clean : [receipt | Mutant _ _ _ receipt <- mutants]

runProcess :: FilePath -> Text -> FilePath -> [String] -> IO Receipt
runProcess root name executable arguments = do
  processEnvironment <- filter (not . redirectedRoot . fst) <$> getEnvironment
  (status, stdout, stderr) <- readCreateProcessWithExitCode (proc executable arguments) {cwd = Just root, env = Just processEnvironment} ""
  let output = Text.pack stdout <> Text.pack stderr
  pure (Receipt name executable arguments status (Text.pack stdout) (Text.pack stderr) (digestTexts [name, Text.pack executable, Text.pack (show arguments), Text.pack (show status), output]))

require :: String -> Receipt -> IO Receipt
require label receipt | receiptExit receipt == ExitSuccess = pure receipt | otherwise = fail ("phase53-command-failed:" <> label <> ":" <> Text.unpack (receiptOutput receipt))
requireFailure :: String -> Receipt -> IO Receipt
requireFailure label receipt | receiptExit receipt /= ExitSuccess = pure receipt | otherwise = fail ("phase53-command-unexpectedly-succeeded:" <> label)
requireExecutable :: FilePath -> IO FilePath
requireExecutable path = do
  present <- doesFileExist path
  runnable <- if present then Directory.executable <$> Directory.getPermissions path else pure False
  if runnable then pure path else fail ("phase53-executable-absent-or-not-executable:" <> path)
receiptExit :: Receipt -> ExitCode
receiptExit (Receipt _ _ _ status _ _ _) = status
receiptStdout :: Receipt -> Text
receiptStdout (Receipt _ _ _ _ stdout _ _) = stdout
receiptDigest :: Receipt -> Text
receiptDigest (Receipt _ _ _ _ _ _ digest) = digest
receiptOutput :: Receipt -> Text
receiptOutput (Receipt _ _ _ _ stdout stderr _) = stdout <> stderr
receiptArgs :: Receipt -> [String]
receiptArgs (Receipt _ _ args _ _ _ _) = args
receiptSummary :: Receipt -> Text
receiptSummary receipt@(Receipt name executable args status _ _ _) = Text.intercalate "|" [name, Text.pack executable, "argv=" <> Text.pack (show args), "exit=" <> Text.pack (show status), "sha256=" <> receiptDigest receipt]

liveDigest :: Either SomeException LiveObservation -> Text
liveDigest liveResult = case liveResult of
  Left problem -> digestTexts ["live-error", Text.pack (displayException problem)]
  Right live -> digestTexts ([liveProfile live, livePreflight live, liveProviderBefore live, liveProviderAfter live, liveEndpoint live, liveFrameCarve live, liveFrameArchitecture live, liveEngineArchitecture live, liveEmulationRegistrations live, liveImageArchitecture live, liveContainerOutput live, liveLiftedOutput live] <> liveLiftedPlanOutput live <> map receiptDigest (liveReceipts live))

expectedLiftedPlanOutput :: [Text]
expectedLiftedPlanOutput =
  [ "install -y ghcup\n"
  , "install cabal 3.16.1.0 --set\n"
  , "install -y docker.io\n"
  , "install -y kubectl\n"
  , "install -y kind\n"
  ]

prepareSourceRepositoryCache :: FilePath -> FilePath -> IO CheckResult
prepareSourceRepositoryCache root runRoot = do
  let candidates = [root </> ".build/toolchain/darwin-arm64/dist-newstyle/src", root </> ".build/toolchain/linux-amd64/dist-newstyle/src"]
  available <- filterMDirectory candidates
  case available of
    [] -> pure (CheckResult "apple-engine-source-cache" [] [finding "APPLE-ENGINE-CACHE" ".build/toolchain/*/dist-newstyle/src" "authenticated source repository cache is absent"])
    source : _ -> do
      let target = runRoot </> "dist/src"
      copyDirectoryRecursive source target
      names <- sort <$> listDirectory target
      pure (CheckResult "apple-engine-source-cache" [observation "apple-engine.cache.entries" (Text.pack (show names))]
        [finding "APPLE-ENGINE-CACHE" (makeRelative root target) "source repository cache is incomplete" | not (any ("infernix-" `isPrefixOf`) names && any ("jitML-" `isPrefixOf`) names)])

filterMDirectory :: [FilePath] -> IO [FilePath]
filterMDirectory [] = pure []
filterMDirectory (path : remaining) = do
  present <- doesDirectoryExist path
  rest <- filterMDirectory remaining
  pure ([path | present] <> rest)

copyDirectoryRecursive :: FilePath -> FilePath -> IO ()
copyDirectoryRecursive source target = do
  createDirectoryIfMissing True target
  names <- listDirectory source
  forM_ names $ \name -> do
    let from = source </> name; to = target </> name
    directory <- doesDirectoryExist from
    if directory then copyDirectoryRecursive from to else copyFile from to

freshRunRoot :: FilePath -> IO FilePath
freshRunRoot root = do
  let parent = root </> ".build/runs/phase-53/work"
  createDirectoryIfMissing True parent
  (path, handle) <- openBinaryTempFile parent "candidate-"
  hClose handle
  removeFile path
  createDirectory path
  pure path

liveFinding :: Text -> SomeException -> Finding
liveFinding code problem = finding code "phase-53-live" (Text.pack (displayException problem))
named :: Text -> [CheckResult] -> CheckResult
named name checks = (mergeChecks name checks) {checkName = name}
checkDigest :: CheckResult -> Text
checkDigest result = digestTexts [checkName result, Text.pack (show (checkObservations result)), Text.pack (show (checkFindings result))]
digestTexts :: [Text] -> Text
digestTexts = hex . SHA256.hash . TextEncoding.encodeUtf8 . Text.intercalate "\NUL"
hex :: ByteString.ByteString -> Text
hex bytes = Text.pack (concatMap byteHex (ByteString.unpack bytes))
 where byteHex byte = let digits = "0123456789abcdef"; value = fromIntegral byte :: Int in [digits !! (value `div` 16), digits !! (value `mod` 16)]
notContains :: Text -> Text -> Bool
notContains needle value = not (needle `Text.isInfixOf` value)
pathBelow :: FilePath -> FilePath -> Bool
pathBelow parent child = let relative = normalise (makeRelative parent child) in relative /= ".." && not ("../" `isPrefixOf` relative) && not (isAbsolute relative)
safeOwnerCharacter :: Char -> Bool
safeOwnerCharacter character = character >= '0' && character <= '9' || character >= 'a' && character <= 'z' || character == '-'
arm64 :: Text -> Bool
arm64 value = Text.strip value `elem` ["arm64", "aarch64"]
truth :: Bool -> Text
truth True = "true"
truth False = "false"

redirectedRoot :: String -> Bool
redirectedRoot key = key `elem`
  [ "COLIMA_HOME", "COLIMA_CACHE_HOME", "COLIMA_PROFILE", "COLIMA_SAVE_CONFIG"
  , "LIMA_HOME", "DOCKER_CONFIG", "DOCKER_CONTEXT", "DOCKER_HOST", "XDG_CONFIG_HOME"
  ]

gib :: Word64
gib = 1024 * 1024 * 1024
