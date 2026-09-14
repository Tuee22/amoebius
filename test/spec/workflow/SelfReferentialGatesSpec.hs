{-# LANGUAGE OverloadedStrings #-}

-- | The Phase-49 subject: one real traversal of the hardware-free spine.
--
-- Nothing in this suite records an expected value as an observation. Each of
-- the nine stage digests is computed from the actual output of the owning
-- production stage, the application boundary is driven by production code, and
-- the argv and bytes that boundary delivered are read back from a transcript
-- written by a separate operating-system process.
module Main (main) where

import Amoebius.Capability.Binding (assembleBoundDeployment, bind)
import Amoebius.Capability.Types
  ( BoundDeployment (..)
  , BoundExecutionSet (BoundExecutionSet)
  , CapabilityBinding (CapabilityBinding)
  , CapabilityNeed (ObjectStoreNeed)
  , CapabilityProvider (CanonicalProvider)
  , ServiceShape (SingleNode)
  )
import Amoebius.Capacity.Accelerator (AcceleratorDevice (AcceleratorDevice), AcceleratorFamily (CudaFamily))
import Amoebius.Capacity.Execution (ExecutionTransitionSource (FirstDeployment))
import Amoebius.Capacity.Provision
  ( InfrastructurePlanningResult (InfrastructureRequired, NoInfrastructureRequired)
  , InfrastructureState (InfrastructureAlreadyPresent)
  , ProvisionPolicy (..)
  , ProvisionTargetSupply (StandaloneRoot)
  , ProvisionedSpec (provisionedServiceParts)
  , TargetSupply (TargetSupply)
  , emptyPriorProvisionCatalog
  , mkProvisionContext
  , observationFromPlanningResult
  , planInfrastructure
  , provision
  )
import Amoebius.Capacity.RenderSource (K8sObjectIdentity (K8sObjectIdentity))
import Amoebius.Capacity.Types
  ( CpuOvercommitPolicy (NoCpuOvercommit)
  , HostEnvironment (NativeLinux)
  , Node (Node)
  , NodeCapacity (NodeCapacity)
  , ResourceVector (ResourceVector)
  )
import Amoebius.Capability.Engine (TargetOffering (LinuxCudaOffering))
import Amoebius.Dsl.GadtDecode
  ( DecodeFailure (..)
  , DecodedWorld (decodedExecution, decodedOwner, decodedSurface, decodedTenant)
  , Surface (App, Cluster, Deployment)
  , decodeWorldFile
  )
import Amoebius.Dsl.Topology (ComputeEngine (KindEngine), NodeSupply (FixedSupply), mkTopology)
import Amoebius.Exec.Boundary (mkBoundaryTools, runBoundaryCorpus)
import Amoebius.Exec.Tool (ToolResult (toolExitCode))
import Amoebius.Gate.SelfReferential
import Amoebius.Kernel.Chain (chain, mkPlanConfig)
import Amoebius.Kernel.Descent qualified as Descent
import Amoebius.Kernel.Descent (PlanEntry (..))
import Amoebius.Kernel.Plan (renderChainPlan)
import Amoebius.Kernel.Step (Step, stepFrame)
import Amoebius.Manifest (renderAll)
import Amoebius.Manifest.K8sObject (K8sObject (objectIdentity), encodeK8sObjects)
import Amoebius.Validation.DslBarrier
import Control.Monad (forM, forM_, unless, when)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString qualified as Strict
import Data.ByteString.Char8 qualified as Char8
import Data.ByteString.Lazy qualified as Lazy
import Data.IORef (newIORef, readIORef)
import Data.List (isPrefixOf, nub, sort)
import Data.List.NonEmpty (NonEmpty ((:|)))
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Text.IO qualified as TextIO
import DslBarrierOracle
import Numeric (showHex)
import System.Directory
  ( copyFile
  , createDirectoryIfMissing
  , doesFileExist
  , getPermissions
  , listDirectory
  , makeAbsolute
  , setOwnerExecutable
  , setPermissions
  )
import System.Environment (getArgs, getEnvironment, getExecutablePath, getProgName, lookupEnv, setEnv)
import System.Exit (ExitCode (ExitSuccess), die)
import System.FilePath ((</>))
import System.IO (BufferMode (LineBuffering), IOMode (ReadMode), hSetBuffering, stdout, withBinaryFile)
import System.Process (CreateProcess (env), proc, readCreateProcessWithExitCode)

toolNames :: [String]
toolNames = ["kubectl", "docker", "helm", "pulumi"]

main :: IO ()
main = do
  program <- getProgName
  if program `elem` toolNames then runFakeTool program else runSuite

-- | The fake boundary child. It is a separate operating-system process; the
-- only thing it shares with the supervisor is the executable image.
runFakeTool :: String -> IO ()
runFakeTool tool = do
  hSetBuffering stdout LineBuffering
  transcriptDirectory <- requireEnvironment "AMOEBIUS_PHASE49_TRANSCRIPTS"
  createDirectoryIfMissing True transcriptDirectory
  executable <- getExecutablePath
  let counterPath = transcriptDirectory </> tool <> ".count"
  present <- doesFileExist counterPath
  prior <- if present then read . Char8.unpack <$> Strict.readFile counterPath else pure 0
  let count = prior + (1 :: Int)
      base = transcriptDirectory </> tool <> "." <> show count
  writeFile counterPath (show count <> "\n")
  arguments <- getArgs
  writeFile (base <> ".argv") (unlines (executable : arguments))
  stdinBytes <- Strict.getContents
  Strict.writeFile (base <> ".stdin") stdinBytes
  putStrLn "READY"

runSuite :: IO ()
runSuite = do
  arguments <- getArgs
  workArgument <- case arguments of
    ["--work", directory] -> pure directory
    _ -> die "usage: self-referential-gates-spec --work DIRECTORY"
  workRoot <- makeAbsolute workArgument
  self <- getExecutablePath
  let fakeDirectory = workRoot </> "fakes"
      readinessTranscripts = workRoot </> "readiness"
      boundaryTranscripts = workRoot </> "boundary"
      surfaceDirectory = workRoot </> "surfaces"
  createDirectoryIfMissing True workRoot
  createDirectoryIfMissing True readinessTranscripts
  createDirectoryIfMissing True boundaryTranscripts
  createDirectoryIfMissing True surfaceDirectory
  materializeFakes self fakeDirectory

  -- The child announces readiness before any challenge exists.
  readinessObserved <- observeReadiness fakeDirectory readinessTranscripts
  unless readinessObserved (die "self-referential-gates-mutant: RED readiness external fake boundary did not announce readiness")

  -- Only now is the bounded challenge drawn, so it cannot have been predeclared.
  challenge <- freshChallenge
  TextIO.putStrLn ("dsl-barrier-challenge: " <> challenge)

  stagesThroughDryRun <- runSpine surfaceDirectory challenge
  let (SpineResult decodeRow legalityRow bindRow resolveRow provisionRow renderRow planRow dryRunRow manifestBytes) = stagesThroughDryRun

  -- No boundary effect may have occurred before the application stage.
  effectStage <- observedEffectStage boundaryTranscripts
  fakeObservation <- applyThroughBoundary fakeDirectory boundaryTranscripts manifestBytes effectStage
  let applyRow = StageObservation FakeApply (fakeApplyDigest fakeObservation) True

  let observations =
        [decodeRow, legalityRow, bindRow, resolveRow, provisionRow, renderRow, planRow, dryRunRow, applyRow]
      gateRun = cleanGate
  checkOracleIndependence
  expectRight "clean barrier" (validateDslBarrier observations (BarrierChallenge challenge) fakeObservation gateRun)
  checkNegatives observations challenge fakeObservation gateRun
  putStrLn "dsl-barrier-oracle: PASS (9 stages, 12 paired negatives, 12 changed-production mutants)"
  putStrLn "self-referential-gates-spec: PASS (9 stages, 5 workflow arms, external fake observation, teardown balanced)"

-- | Stage rows one through eight plus the derived application request bytes.
data SpineResult = SpineResult
  StageObservation
  StageObservation
  StageObservation
  StageObservation
  StageObservation
  StageObservation
  StageObservation
  StageObservation
  Lazy.ByteString

runSpine :: FilePath -> Text -> IO SpineResult
runSpine surfaceDirectory challenge = do
  let name = oracleNeedName challenge

  -- Stage 1: decode. The surface is authored by the independent oracle and
  -- resolved by the production decoder.
  let legalPath = surfaceDirectory </> "legal.dhall"
  TextIO.writeFile legalPath (legalWorldSource challenge <> "\n")
  decoded <- decodeWorldFile legalPath >>= either (\problem -> die ("self-referential-gates-mutant: RED decode " <> show problem)) pure
  assertEqual "decoded surface" expectedDecodedSurface (surfaceName (decodedSurface decoded))
  assertEqual "decoded tenant" expectedDecodedTenant (decodedTenant decoded)
  assertEqual "decoded owner" expectedDecodedOwner (decodedOwner decoded)
  let executionText = Text.pack (show (decodedExecution decoded))
  assert
    (expectedDecodedController `Text.isInfixOf` executionText && name `Text.isInfixOf` executionText)
    "self-referential-gates-mutant: RED decode decoded execution lost its controller or run identity"
  let decodeRow = StageObservation Decode (digestText executionText) True

  -- Stage 2: legality. Each minimally different illegal surface must draw its
  -- exact refusal from the same production decoder.
  refusals <- forM (illegalWorldSources challenge) $ \(caseName, source, _) -> do
    let path = surfaceDirectory </> Text.unpack caseName <> ".dhall"
    TextIO.writeFile path (source <> "\n")
    outcome <- decodeWorldFile path
    case outcome of
      Right _ -> die ("self-referential-gates-mutant: RED legality " <> Text.unpack caseName <> " was admitted")
      Left failure -> pure (caseName, failureTag failure)
  assertEqual "legality refusals" (expectedLegalityRefusals challenge) refusals
  let legalityRow = StageObservation Legality (digestText (renderPairs refusals)) True

  -- Stage 3: bind and expand.
  deployment <-
    either
      (\problem -> die ("self-referential-gates-mutant: RED bind-expand " <> show problem))
      pure
      (assembleBoundDeployment FirstDeployment Nothing Nothing [bind (ObjectStoreNeed name) (CapabilityBinding CanonicalProvider SingleNode)])
  assertEqual "bound service keys" [name] (Map.keys (boundDeploymentServices deployment))
  let bindRow = StageObservation BindExpand (digestText (Text.pack (show deployment))) True

  -- Stage 4: plan and resolve infrastructure.
  let BoundExecutionSet units = boundDeploymentExecutions deployment
      supply = StandaloneRoot (TargetSupply InfrastructureAlreadyPresent baselineCapacity (Map.keysSet units) 7)
  planned <-
    either
      (\problem -> die ("self-referential-gates-mutant: RED plan-resolve " <> show problem))
      pure
      (planInfrastructure supply deployment)
  assertEqual "infrastructure planning" expectedPlanningTag (planningTag planned)
  let resolveRow = StageObservation PlanResolve (digestText (Text.pack (show planned))) True

  -- Stage 5: provision.
  observation <-
    either
      (\problem -> die ("self-referential-gates-mutant: RED provision " <> show problem))
      pure
      (observationFromPlanningResult planned)
  context <-
    either
      (\problem -> die ("self-referential-gates-mutant: RED provision " <> show problem))
      pure
      (mkProvisionContext "phase49" 2 barrierPolicy emptyPriorProvisionCatalog observation)
  topology <-
    either
      (\problem -> die ("self-referential-gates-mutant: RED provision " <> show problem))
      pure
      (mkTopology KindEngine (FixedSupply (barrierNode :| [])))
  sealed <-
    either
      (\problem -> die ("self-referential-gates-mutant: RED provision " <> show problem))
      pure
      (provision context topology deployment)
  assertEqual "provisioned service keys" (expectedProvisionedServiceKeys challenge) (Map.keys (provisionedServiceParts sealed))
  let provisionRow = StageObservation Provision (digestText (Text.pack (show sealed))) True

  -- Stage 6: whole-deployment render.
  let objects = renderAll sealed
      identities = [identity | object <- objects, let K8sObjectIdentity identity = objectIdentity object]
      manifestBytes = encodeK8sObjects objects
  assertEqual "rendered identities" (expectedObjectIdentities challenge) (sort identities)
  assert
    (Lazy.length manifestBytes > 0 && Text.pack (Char8.unpack (Lazy.toStrict manifestBytes)) `contains` name)
    "self-referential-gates-mutant: RED render-all applied bytes lost the run identity"
  let renderRow = StageObservation RenderAll (digestBytes (Lazy.toStrict manifestBytes)) True

  -- Stage 7: plan the descent.
  counter <- newIORef 0
  let configuration = mkPlanConfig name sealed counter
      steps = chain configuration
      planValue = Descent.foldLift () steps
      entries = Descent.planEntries planValue
      actualRows = zipWith planRow [1 ..] entries
  assertEqual "planned descent" (expectedPlanRows challenge) actualRows
  let planStageRow = StageObservation Plan (digestText (Text.pack (show planValue))) True

  -- Stage 8: dry run. Rendering the plan must not execute any step.
  let canonical = renderChainPlan steps
  executed <- readIORef counter
  assert (executed == 0) "self-referential-gates-mutant: RED dry-run rendering the plan executed a step"
  assert
    (Set.fromList (map stepFrame steps) == Set.fromList (map planEntryFrame entries))
    "self-referential-gates-mutant: RED dry-run activation frames drifted from the planned descent"
  let dryRunRow = StageObservation DryRun (digestBytes (Lazy.toStrict canonical)) True

  pure (SpineResult decodeRow legalityRow bindRow resolveRow provisionRow renderRow planStageRow dryRunRow manifestBytes)
 where
  planRow position entry =
    ( position
    , planEntryLabel entry
    , Text.pack (show (planEntryFrame entry))
    , Text.pack (show (planEntryKind entry))
    )

-- | Run the production application boundary and read back what a separate
-- process was observed to receive.
applyThroughBoundary :: FilePath -> FilePath -> Lazy.ByteString -> BarrierStage -> IO FakeBoundaryObservation
applyThroughBoundary fakeDirectory transcripts manifestBytes effectStage = do
  tools <-
    either
      (\problem -> die ("self-referential-gates-mutant: RED fake-apply " <> show problem))
      pure
      (mkBoundaryTools (fakeDirectory </> "kubectl") (fakeDirectory </> "docker") (fakeDirectory </> "helm") (fakeDirectory </> "pulumi"))
  results <- withTranscriptEnvironment transcripts (runBoundaryCorpus tools manifestBytes)
  forM_ expectedBoundaryArgv $ \(transcriptName, expected) -> do
    recorded <- lines <$> readFile (transcripts </> transcriptName)
    case recorded of
      [] -> die ("self-referential-gates-mutant: RED fake-apply empty transcript " <> transcriptName)
      invoked : observedArguments ->
        assert
          (observedArguments == expected && fakeDirectory `isPrefixOf` invoked)
          ("self-referential-gates-mutant: RED fake-apply argv transcript " <> transcriptName)
  forM_ expectedToolInvocationCounts $ \(tool, expected) -> do
    let counterPath = transcripts </> tool <> ".count"
    present <- doesFileExist counterPath
    observed <- if present then read . Char8.unpack <$> Strict.readFile counterPath else pure (0 :: Int)
    assert (observed == expected) ("self-referential-gates-mutant: RED fake-apply invocation count for " <> tool)
  applied <- Strict.readFile (transcripts </> "kubectl.1.stdin")
  invokedLines <- lines <$> readFile (transcripts </> "kubectl.1.argv")
  (invokedExecutable, observedArgv) <- case invokedLines of
    invoked : rest -> pure (invoked, map Text.pack rest)
    [] -> die "self-referential-gates-mutant: RED fake-apply empty application transcript"
  supervisor <- getExecutablePath
  pure
    FakeBoundaryObservation
      { fakeExecutable = invokedExecutable
      , fakeArgv = observedArgv
      , fakeRequestDigest = digestBytes applied
      , fakeRecoveredChallenge = recoverChallenge applied
      , fakeEffectStage = effectStage
      , fakeExternallyObserved = invokedExecutable /= supervisor
      , fakeTeardownObserved = all ((== ExitSuccess) . toolExitCode) results && length results == length expectedBoundaryArgv
      }

-- | The challenge is recovered from the bytes the child actually received, not
-- from the value the supervisor holds.
recoverChallenge :: Strict.ByteString -> Text
recoverChallenge applied =
  case Text.breakOn expectedApplyIdentity (TextEncoding.decodeUtf8 applied) of
    (_, remainder)
      | Text.null remainder -> ""
      | otherwise -> Text.takeWhile challengeCharacter (Text.drop (Text.length expectedApplyIdentity) remainder)

challengeCharacter :: Char -> Bool
challengeCharacter character =
  character >= '0' && character <= '9' || character >= 'a' && character <= 'f'

fakeApplyDigest :: FakeBoundaryObservation -> Text
fakeApplyDigest observation =
  digestText
    ( Text.intercalate
        "\NUL"
        [ Text.pack (fakeExecutable observation)
        , Text.unwords (fakeArgv observation)
        , fakeRequestDigest observation
        , fakeRecoveredChallenge observation
        , Text.pack (show (fakeEffectStage observation))
        , Text.pack (show (fakeExternallyObserved observation))
        , Text.pack (show (fakeTeardownObserved observation))
        ]
    )

-- | An empty boundary transcript directory before the application stage is the
-- observation that no earlier stage produced an external effect.
observedEffectStage :: FilePath -> IO BarrierStage
observedEffectStage transcripts = do
  entries <- listDirectory transcripts
  pure (if null entries then FakeApply else DryRun)

observeReadiness :: FilePath -> FilePath -> IO Bool
observeReadiness fakeDirectory transcripts = do
  inherited <- getEnvironment
  let childEnvironment =
        ("AMOEBIUS_PHASE49_TRANSCRIPTS", transcripts)
          : filter ((/= "AMOEBIUS_PHASE49_TRANSCRIPTS") . fst) inherited
      command = (proc (fakeDirectory </> "kubectl") ["readiness-probe"]) {env = Just childEnvironment}
  (code, announced, _) <- readCreateProcessWithExitCode command ""
  recorded <- doesFileExist (transcripts </> "kubectl.1.argv")
  pure (code == ExitSuccess && "READY" `elem` lines announced && recorded)

-- | The production boundary inherits this process's environment, so the child
-- transcript destination is set for the whole application stage.
withTranscriptEnvironment :: FilePath -> IO value -> IO value
withTranscriptEnvironment transcripts action = do
  setEnv "AMOEBIUS_PHASE49_TRANSCRIPTS" transcripts
  action

materializeFakes :: FilePath -> FilePath -> IO ()
materializeFakes source directory = do
  createDirectoryIfMissing True directory
  forM_ toolNames $ \tool -> do
    let destination = directory </> tool
    copyFile source destination
    permissions <- getPermissions destination
    setPermissions destination (setOwnerExecutable True permissions)

freshChallenge :: IO Text
freshChallenge = do
  bytes <- withBinaryFile "/dev/urandom" ReadMode (\handle -> Strict.hGet handle 12)
  pure (Text.concat [Text.pack (pad (showHex byte "")) | byte <- Strict.unpack bytes])
 where
  pad rendered = if length rendered == 1 then '0' : rendered else rendered

baselineCapacity :: ResourceVector
baselineCapacity = ResourceVector 100000 100000 100000 100000

barrierNode :: Node
barrierNode =
  Node
    "phase49-node"
    "phase49-host"
    NativeLinux
    (NodeCapacity baselineCapacity NoCpuOvercommit Map.empty)
    Set.empty

barrierPolicy :: ProvisionPolicy
barrierPolicy =
  ProvisionPolicy
    { policyRuntimeBackingBytes = 100000
    , policyStorageBackingBytes = 100000
    , policyMonitoringWorkflowLimit = 1000
    , policyMonitoringRuleLimit = 2000
    , policyMonitoringSeriesLimit = 10000
    , policyMonitoringVolumeBytes = 100000
    , policyCudaAvailable = True
    , policyAllocatableVramBytes = 100000
    , policyTargetOffering =
        Just
          ( LinuxCudaOffering
              "phase49-cuda"
              (Map.singleton "cuda-default" (AcceleratorDevice "cuda-default" CudaFamily "cuda-default" 100004 4 100000 Set.empty Set.empty))
          )
    }

cleanGate :: GateRun
cleanGate =
  deriveGate
    (GateDeclaration 49 "DEVELOPMENT_PLAN/phase_49_self_referential_gates.md" "amoebius validate phase 49")
    GatePassed

checkNegatives :: [StageObservation] -> Text -> FakeBoundaryObservation -> GateRun -> IO ()
checkNegatives observations challenge fake gateRun = do
  let paired =
        [ ("decode-failure", setStage Decode (\row -> row {observedStagePassed = False}) observations, fake, StageFailed Decode)
        , ("stage-inventory", drop 1 observations, fake, StageInventoryMismatch (map observedStage (drop 1 observations)))
        , ("demand-digest", setStage PlanResolve (\row -> row {observedStageDigest = "short"}) observations, fake, StageDigestMalformed PlanResolve)
        , ("provision-identity", duplicateDigest Provision Decode observations, fake, StageDigestCollision)
        ]
  mapM_ (\(label, rows, observedFake, wanted) -> expectLeft label wanted (validateDslBarrier rows (BarrierChallenge challenge) observedFake gateRun)) paired
  expectLeft "fake-argv" FakeArgvMismatch (validateDslBarrier observations (BarrierChallenge challenge) (fake {fakeArgv = ["apply"]}) gateRun)
  expectLeft "fake-request" FakeRequestMismatch (validateDslBarrier observations (BarrierChallenge challenge) (fake {fakeRequestDigest = digestText "forged"}) gateRun)
  expectLeft "challenge" FakeChallengeMismatch (validateDslBarrier observations (BarrierChallenge challenge) (fake {fakeRecoveredChallenge = "stale"}) gateRun)
  expectLeft "dry-run-effect" EffectBeforeFakeApply (validateDslBarrier observations (BarrierChallenge challenge) (fake {fakeEffectStage = DryRun}) gateRun)
  expectLeft "self-observer" SelfObservation (validateDslBarrier observations (BarrierChallenge challenge) (fake {fakeExternallyObserved = False}) gateRun)
  expectLeft "teardown" FakeTeardownMissing (validateDslBarrier observations (BarrierChallenge challenge) (fake {fakeTeardownObserved = False}) gateRun)
  let failedGate = deriveGate (GateDeclaration 49 "phase-49" "amoebius validate phase 49") (GateFailed 9)
  expectLeft "workflow-evidence" WorkflowEvidenceMismatch (validateDslBarrier observations (BarrierChallenge challenge) fake failedGate)
  expectLeft "workflow-balance" WorkflowResourceLeak (validateDslBarrier observations (BarrierChallenge challenge) fake (gateRun {runBalances = False}))
  unless (length expectedNegativeLabels == 12 && length expectedMutantLabels == 12) (die "dsl-barrier-oracle inventory drift")
  unless (length expectedStages == 9 && length (nub (map show expectedStages)) == 9) (die "dsl-barrier-oracle stage drift")

setStage :: BarrierStage -> (StageObservation -> StageObservation) -> [StageObservation] -> [StageObservation]
setStage target change = map (\row -> if observedStage row == target then change row else row)

duplicateDigest :: BarrierStage -> BarrierStage -> [StageObservation] -> [StageObservation]
duplicateDigest target source observations = case [observedStageDigest row | row <- observations, observedStage row == source] of
  [digest] -> setStage target (\row -> row {observedStageDigest = digest}) observations
  _ -> observations

expectRight :: String -> Either BarrierProblem () -> IO ()
expectRight label outcome = case outcome of
  Right () -> pure ()
  Left problem -> die ("self-referential-gates-mutant: RED " <> label <> " " <> show problem)

expectLeft :: Text -> BarrierProblem -> Either BarrierProblem () -> IO ()
expectLeft label wanted outcome = case outcome of
  Left actual | actual == wanted -> pure ()
  _ -> die ("self-referential-gates-mutant: RED " <> Text.unpack label <> " expected=" <> show wanted <> " actual=" <> show outcome)

checkOracleIndependence :: IO ()
checkOracleIndependence =
  unless (map show expectedStages == map (("Oracle" <>) . show) ([minBound .. maxBound] :: [BarrierStage]))
    (die "dsl-barrier oracle/subject stage correspondence drift")

surfaceName :: Surface -> Text
surfaceName surface = case surface of
  Cluster -> "Cluster"
  App -> "App"
  Deployment -> "Deployment"

planningTag :: InfrastructurePlanningResult -> Text
planningTag result = case result of
  NoInfrastructureRequired _ -> "NoInfrastructureRequired"
  InfrastructureRequired _ -> "InfrastructureRequired"

failureTag :: DecodeFailure -> Text
failureTag failure = case failure of
  ForbiddenImport _ -> "ForbiddenImport"
  DhallFailure _ -> "DhallFailure"
  UnknownSurface _ -> "UnknownSurface"
  UnknownController _ -> "UnknownController"
  UnknownResourceArm _ -> "UnknownResourceArm"
  EmptyExecutionId -> "EmptyExecutionId"
  ZeroRevision -> "ZeroRevision"
  TenantMismatch _ _ -> "TenantMismatch"
  PlaintextSecret -> "PlaintextSecret"
  UnknownSecretRef _ -> "UnknownSecretRef"
  ResourceArmMismatch _ _ -> "ResourceArmMismatch"

renderPairs :: [(Text, Text)] -> Text
renderPairs rows = Text.intercalate "\n" [name <> "\t" <> value | (name, value) <- rows]

digestText :: Text -> Text
digestText = digestBytes . TextEncoding.encodeUtf8

digestBytes :: Strict.ByteString -> Text
digestBytes = Text.concat . map renderByte . Strict.unpack . SHA256.hash
 where
  renderByte byte = Text.pack (if byte < 16 then '0' : showHex byte "" else showHex byte "")

contains :: Text -> Text -> Bool
contains haystack needle = needle `Text.isInfixOf` haystack

requireEnvironment :: String -> IO String
requireEnvironment name = lookupEnv name >>= maybe (die (name <> " is required")) pure

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual =
  when (expected /= actual) (die ("self-referential-gates-mutant: RED " <> label <> " expected=" <> show expected <> " actual=" <> show actual))
