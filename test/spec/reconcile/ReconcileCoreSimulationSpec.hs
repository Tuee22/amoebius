{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Capacity.Scheduler
  ( CompleteResourceReservation (..)
  , ProvisionedExecutionSchedulingGuard (..)
  , ReservationLedgerRow (..)
  , ReservationState (..)
  , beginBinding
  , confirmBound
  , ledgerOnlyAbsentRecovery
  )
import Amoebius.Capacity.Types (ResourceVector (..))
import Amoebius.Formal.Dsl.Models (dslModels)
import Amoebius.Formal.Model qualified as Formal
import Amoebius.Reconcile.Core
import Amoebius.Reconcile.Sim
import Control.Concurrent.Class.MonadSTM
  ( MonadSTM
  , TVar
  , atomically
  , newTVarIO
  , readTVar
  , readTVarIO
  , writeTVar
  )
import Control.Monad (forM, forM_, unless)
import Control.Monad.Class.MonadAsync (MonadAsync, async, wait)
import Control.Monad.Class.MonadTest (exploreRaces)
import Control.Monad.IOSim
  ( IOSim
  , exploreSimTrace
  , runSimOrThrow
  , traceResult
  , withBranching
  , withScheduleBound
  )
import Data.ByteString (ByteString)
import Data.List (sort)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import ReconcileCoreOracle
import ReferencePlanner (referencePlan)
import System.Directory (createDirectoryIfMissing)
import System.Environment (getEnv)
import System.Exit (exitFailure)
import System.FilePath (takeDirectory, (</>))
import Test.QuickCheck
  ( Args (..)
  , counterexample
  , isSuccess
  , property
  , quickCheckWithResult
  , stdArgs
  )
import Test.QuickCheck.Random (mkQCGen)

main :: IO ()
main = do
  assertEqual "production mutant catalog" 5 (length productionMutants)
  fixedPoints <- checkCoreCorpus
  schedules <- checkSchedules
  checkScheduleSensitivity schedules
  forM_ schedules checkIOSimPOR
  checkTokenProtocol
  checkReservationProtocol
  checkFormalLinks
  writeResults fixedPoints (length schedules)
  putStrLn "reconcile-core-simulation-spec: PASS (9 core cases, 4 schedules, 4 IOSimPOR, 2 protocols, 4 formal links)"

checkCoreCorpus :: IO Int
checkCoreCorpus = do
  assertEqual "core corpus cardinality" 9 (length coreCases)
  fixed <- forM coreCases $ \entry -> do
    desired <- either (die . Text.unpack) pure (parseDesired (coreDesiredSource entry))
    observed <- either (die . Text.unpack) pure (parseObserved (coreObservedSource entry))
    let actual = renderPlan (planReconcile observed desired)
        reference = renderReference (referencePlan (coreDesiredSource entry) (coreObservedSource entry))
        locus = if coreCaseName entry == "converged-single" then "FixedPoint/" else "CoreCase/"
    assertEqual (locus <> coreCaseName entry <> " actual") (coreExpected entry) actual
    assertEqual (coreCaseName entry <> " independent reference") (coreExpected entry) reference
    pure (actual == "actions:-")
  let count = length (filter id fixed)
  assertEqual "authored fixed-point cases" 2 count
  pure count

checkSchedules :: IO [ReconcileSchedule]
checkSchedules = do
  assertEqual "schedule cardinality" 4 (length scheduleContracts)
  forM scheduleContracts $ \contract -> do
    let schedule = scheduleFrom contract
        first = runSimulation schedule
        second = runSimulation schedule
        label = Text.unpack (oracleScheduleName contract)
    assertEqual (label <> " same-seed bytes") (encodeResult first) (encodeResult second)
    assertEqual ("Convergence/" <> label) SimulationConverged (simulationVerdict first)
    assertEqual (label <> " final inventory") expectedFinalInventory (simulationFinalInventory first)
    assertEqual (label <> " accepted writes") (oracleAcceptedWrites contract) (simulationAcceptedWrites first)
    assertEqual (label <> " reuse rejections") (oracleReuseRejections contract) (simulationRejectedReuses first)
    assertEqual (label <> " stale rejections") (oracleStaleRejections contract) (simulationRejectedStale first)
    assert (any (oracleRequiredEvent contract `Text.isInfixOf`) (simulationTrace first))
      (label <> " missed required event " <> Text.unpack (oracleRequiredEvent contract))
    pure schedule

scheduleFrom :: ScheduleContract -> ReconcileSchedule
scheduleFrom contract =
  ReconcileSchedule
    { scheduleName = oracleScheduleName contract
    , scheduleSeed = oracleScheduleSeed contract
    , scheduleBound = oracleScheduleBound contract
    , scheduleDuplicateDelivery = oracleDuplicateDelivery contract
    , scheduleCrashBeforeApply = oracleCrashBeforeApply contract
    , scheduleStaleSnapshot = oracleStaleSnapshot contract
    , scheduleDelayMicros = oracleDelayMicros contract
    }

checkScheduleSensitivity :: [ReconcileSchedule] -> IO ()
checkScheduleSensitivity schedules = do
  schedule <- findSchedule "baseline" schedules
  let perturbed = schedule {scheduleSeed = scheduleSeed schedule + 1}
  assert (simulationTrace (runSimulation schedule) /= simulationTrace (runSimulation perturbed))
    "SeedSensitivity/changed seed produced the same semantic trace"

checkIOSimPOR :: ReconcileSchedule -> IO ()
checkIOSimPOR schedule = do
  let callback _ trace = case traceResult False trace of
        Left failure -> counterexample (show failure) False
        Right result -> counterexample (show result) (property (simulationVerdict result == SimulationConverged))
      options = withBranching 3 . withScheduleBound 32
      args = stdArgs {maxSuccess = 1, replay = Just (mkQCGen (scheduleSeed schedule), 0), chatty = False}
  result <- quickCheckWithResult args (exploreSimTrace options (porSimulation schedule) callback)
  assert (isSuccess result) (Text.unpack (scheduleName schedule) <> " IOSimPOR replay failed")

porSimulation :: ReconcileSchedule -> IOSim s SimulationResult
porSimulation schedule = exploreRaces >> simulateReconcile schedule simulationDesired simulationObserved

runSimulation :: ReconcileSchedule -> SimulationResult
runSimulation schedule = runSimOrThrow (simulateReconcile schedule simulationDesired simulationObserved)

simulationDesired :: DesiredIndex
simulationDesired = desiredIndex
  [(ResourceId "a", DesiredRevision "v2"), (ResourceId "b", DesiredRevision "v1")]

simulationObserved :: ObservedInventory
simulationObserved = observedInventory
  [ (ResourceId "a", SomeObservation (PresentObservation "v1"))
  , (ResourceId "b", SomeObservation AbsentObservation)
  , (ResourceId "c", SomeObservation (PresentObservation "v7"))
  ]

checkTokenProtocol :: IO ()
checkTokenProtocol =
  assertEqual "NoTokenReuse/one token race accepted and one rejected"
    [TokenApplied, TokenRejectedReuse]
    (sort (runSimOrThrow tokenRace))

tokenRace :: (MonadAsync m, MonadSTM m) => m [TokenResult]
tokenRace = do
  store <- newSnapshotStore (observedInventory [(ResourceId "a", SomeObservation (PresentObservation "v1"))])
  action <- case planReconcile
      (observedInventory [(ResourceId "a", SomeObservation (PresentObservation "v1"))])
      (desiredIndex [(ResourceId "a", DesiredRevision "v2")]) of
    Right [value] -> pure value
    result -> error ("token race fixture did not produce one action: " <> show result)
  token <- mintSnapshotToken store
  left <- async (applyWithSnapshotToken store token action)
  right <- async (applyWithSnapshotToken store token action)
  mapM wait [left, right]

checkReservationProtocol :: IO ()
checkReservationProtocol = do
  let (created, duplicate, stored) = runSimOrThrow reservationRace
  assertEqual "reservation create result" True created
  assertEqual "reservation duplicate result" False duplicate
  row <- maybe (die "reservation disappeared after CAS") pure stored
  assertEqual "BoundRetainedAfterCrash/reservation debit remains exactly one" reservation (ledgerOnlyAbsentRecovery row)
  forM_ [Reserved, BindingInFlight, Bound] $ \cut -> do
    let crashed = reservationRow {ledgerReservationState = cut, ledgerPodPresent = False}
    assertEqual "BoundRetainedAfterCrash/reservation debit at crash cut" reservation (ledgerOnlyAbsentRecovery crashed)
    bound <- either (die . show) pure (recoverToBound cut)
    assertEqual ("reservation crash cut " <> show cut) Bound (ledgerReservationState bound)
    assertEqual "BoundRetainedAfterCrash/reservation debit after recovery" reservation (ledgerOnlyAbsentRecovery bound)

reservationRace :: (MonadAsync m, MonadSTM m) => m (Bool, Bool, Maybe ReservationLedgerRow)
reservationRace = do
  variable <- newTVarIO Nothing
  first <- async (reserveOnce variable reservationRow)
  second <- async (reserveOnce variable reservationRow)
  outcomes <- mapM wait [first, second]
  stored <- readTVarIO variable
  pure (or outcomes, and outcomes, stored)

reserveOnce :: MonadSTM m => TVar m (Maybe ReservationLedgerRow) -> ReservationLedgerRow -> m Bool
reserveOnce variable row = atomically $ do
  current <- readTVar variable
  case current of
    Nothing -> writeTVar variable (Just row) >> pure True
    Just _ -> pure False

recoverToBound :: ReservationState -> Either String ReservationLedgerRow
recoverToBound cut = case cut of
  Reserved -> do
    binding <- mapLeft show (beginBinding reservationGuard reservationRow)
    mapLeft show (confirmBound reservationGuard binding)
  BindingInFlight -> mapLeft show (confirmBound reservationGuard (reservationRow {ledgerReservationState = BindingInFlight}))
  Bound -> Right reservationRow {ledgerReservationState = Bound, ledgerPodPresent = True}
  other -> Left ("unsupported crash cut: " <> show other)

reservation :: CompleteResourceReservation
reservation =
  CompleteResourceReservation
    { reservationOwner = "work-a"
    , reservationRequired = ResourceVector 1 2 3 1
    , reservationPad = ResourceVector 0 0 0 0
    , reservationReserved = ResourceVector 1 2 3 1
    , reservationCsiVolumes = Set.empty
    , reservationContent = []
    , reservationAcceleratorDevices = Set.empty
    }

reservationRow :: ReservationLedgerRow
reservationRow = ReservationLedgerRow reservation Reserved False

reservationGuard :: ProvisionedExecutionSchedulingGuard
reservationGuard =
  ProvisionedExecutionSchedulingGuard
    { schedulingGuardFingerprint = "snapshot-1"
    , schedulingGuardRootVersion = 1
    , schedulingGuardCandidate = "work-a"
    , schedulingGuardAggregate = ResourceVector 1 2 3 1
    , schedulingGuardContent = Map.empty
    , schedulingGuardCsiVolumes = Set.empty
    , schedulingGuardDevices = Set.empty
    }

checkFormalLinks :: IO ()
checkFormalLinks = do
  assertEqual "formal correspondence cardinality" 4 (length formalCorrespondence)
  forM_ formalCorrespondence $ \row -> do
    assert (not (Text.null (correspondenceEvidence row))) "formal correspondence evidence is empty"
    model <- case filter ((== Text.unpack (correspondenceModel row)) . Formal.modelName) dslModels of
      [value] -> pure value
      _ -> die ("formal correspondence model is missing or duplicated: " <> Text.unpack (correspondenceModel row))
    assert (Text.unpack (correspondenceInvariant row) `elem` map Formal.namedExprName (Formal.modelInvariants model))
      ("formal correspondence invariant is absent: " <> Text.unpack (correspondenceProperty row))

writeResults :: Int -> Int -> IO ()
writeResults fixedPoints scheduleCount = do
  output <- getEnv "AMOEBIUS_RECONCILE_CORE_OUTPUT"
  let path = output </> "phase-results.tsv"
      metrics =
        [ ("core-corpus", "9/9-actual-reference")
        , ("fixed-points", Text.pack (show fixedPoints) <> "/2-green")
        , ("schedule-convergence", Text.pack (show scheduleCount) <> "/4-green")
        , ("same-seed-traces", "4/4-byte-identical")
        , ("seed-sensitivity", "1/1-distinct")
        , ("iosimpor", "4/4-green")
        , ("snapshot-token", "1-accepted/1-reuse-rejected")
        , ("reservation-protocol", "1-debit/3-crash-cuts-bound")
        , ("formal-correspondence", "4/4-linked")
        , ("modeled-environment-fidelity", "ASSUMED")
        , ("runtime-fidelity", "UNVERIFIED")
        ]
  createDirectoryIfMissing True (takeDirectory path)
  writeFile path ("metric\tresult\n" <> concat [Text.unpack key <> "\t" <> Text.unpack value <> "\n" | (key, value) <- metrics])

parseDesired :: Text -> Either Text DesiredIndex
parseDesired source = desiredIndex <$> mapM parse (entries source)
 where
  parse entry = do
    (identifier, value) <- keyValue entry
    pure (ResourceId identifier, DesiredRevision value)

parseObserved :: Text -> Either Text ObservedInventory
parseObserved source = observedInventory <$> mapM parse (entries source)
 where
  parse entry = do
    (identifier, value) <- keyValue entry
    observation <- case value of
      "absent" -> Right (SomeObservation AbsentObservation)
      _ | Just revision <- Text.stripPrefix "present:" value -> Right (SomeObservation (PresentObservation revision))
        | Just reason <- Text.stripPrefix "unreachable:" value -> Right (SomeObservation (UnreachableObservation reason))
        | otherwise -> Left ("invalid observation:" <> value)
    pure (ResourceId identifier, observation)

entries :: Text -> [Text]
entries "-" = []
entries source = Text.splitOn ";" source

keyValue :: Text -> Either Text (Text, Text)
keyValue entry = case Text.breakOn "=" entry of
  (key, value)
    | Text.null key || Text.null value -> Left ("invalid entry:" <> entry)
    | otherwise -> Right (key, Text.drop 1 value)

renderPlan :: Either Refusal ActionSet -> Text
renderPlan result = case result of
  Right [] -> "actions:-"
  Right actions -> "actions:" <> Text.intercalate ";" (sort (map renderAction actions))
  Left (ObservationUnreachable identifiers) -> "refusal:unreachable:" <> commaIds identifiers
  Left (ObservationMissing identifiers) -> "refusal:missing:" <> commaIds identifiers

renderReference :: Either Text [Text] -> Text
renderReference result = case result of
  Right [] -> "actions:-"
  Right actions -> "actions:" <> Text.intercalate ";" actions
  Left refusal -> "refusal:" <> refusal

commaIds :: [ResourceId] -> Text
commaIds = Text.intercalate "," . map unResourceId

encodeResult :: SimulationResult -> ByteString
encodeResult = TextEncoding.encodeUtf8 . Text.pack . show

findSchedule :: Text -> [ReconcileSchedule] -> IO ReconcileSchedule
findSchedule name schedules = case filter ((== name) . scheduleName) schedules of
  [schedule] -> pure schedule
  _ -> die ("missing or duplicate schedule: " <> Text.unpack name)

mapLeft :: (left -> other) -> Either left right -> Either other right
mapLeft transform value = case value of
  Left problem -> Left (transform problem)
  Right result -> Right result

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual =
  assert (expected == actual) (label <> ": expected " <> show expected <> ", got " <> show actual)

die :: String -> IO value
die message = putStrLn ("FAIL: " <> message) >> exitFailure
