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
import Data.Aeson (eitherDecodeStrict', encode)
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy qualified as LazyByteString
import Data.List (isPrefixOf, sort)
import Data.Map.Strict qualified as Map
import Data.Maybe (isJust)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import ReconcileCoreMutants
import ReferencePlanner (referencePlan)
import System.Directory (canonicalizePath, createDirectoryIfMissing, getCurrentDirectory, listDirectory)
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.FilePath ((</>))
import Test.QuickCheck
  ( Args (..)
  , counterexample
  , isSuccess
  , property
  , quickCheckWithResult
  , stdArgs
  )
import Test.QuickCheck.Random (mkQCGen)

data CoreCase = CoreCase
  { coreCaseName :: String
  , coreDesiredSource :: Text
  , coreObservedSource :: Text
  , coreExpected :: Text
  }

data ScheduleExpectation = ScheduleExpectation
  { expectedSchedule :: Text
  , expectedAccepted :: Integer
  , expectedReuse :: Integer
  , expectedStale :: Integer
  , expectedEvent :: Text
  }

main :: IO ()
main = do
  root <- getCurrentDirectory >>= canonicalizePath
  arguments <- getArgs
  case arguments of
    [] -> runGreen root
    [argument] | "--mutant=" `isPrefixOf` argument -> runMutant (drop (length ("--mutant=" :: String)) argument)
    _ -> die ("unknown arguments: " <> show arguments)

runGreen :: FilePath -> IO ()
runGreen root = do
  cases <- loadCoreCases root
  fixedPoints <- checkCoreCorpus cases
  schedules <- loadSchedules root
  expectations <- loadScheduleExpectations root
  results <- checkSchedules schedules expectations
  checkScheduleSensitivity schedules
  forM_ schedules checkIOSimPOR
  checkTokenProtocol
  checkReservationProtocol
  checkFormalCorrespondence root
  writeResults root fixedPoints (length results)
  putStrLn "reconcile-core-simulation-spec: PASS (9 core cases, 4 schedules, 4 IOSimPOR, 2 protocols, 4 formal links)"

loadCoreCases :: FilePath -> IO [CoreCase]
loadCoreCases root = do
  rows <- rowsOf (root </> "test/oracle/reconcile_core/core_cases.tsv")
  case rows of
    (header : body) -> do
      assertEqual "core corpus header" ["case", "desired", "observed", "expected"] header
      forM body $ \row -> case row of
        [name, desired, observed, expected] -> pure (CoreCase name (Text.pack desired) (Text.pack observed) (Text.pack expected))
        _ -> die ("invalid core corpus row: " <> show row)
    [] -> die "empty core corpus"

checkCoreCorpus :: [CoreCase] -> IO Int
checkCoreCorpus cases = do
  assertEqual "core corpus cardinality" 9 (length cases)
  fixed <- forM cases $ \entry -> do
    desired <- either (die . Text.unpack) pure (parseDesired (coreDesiredSource entry))
    observed <- either (die . Text.unpack) pure (parseObserved (coreObservedSource entry))
    let actual = renderPlan (planReconcile observed desired)
        reference = renderReference (referencePlan (coreDesiredSource entry) (coreObservedSource entry))
    assertEqual (coreCaseName entry <> " actual") (coreExpected entry) actual
    assertEqual (coreCaseName entry <> " independent reference") (coreExpected entry) reference
    pure (actual == "actions:-")
  let count = length (filter id fixed)
  assertEqual "authored fixed-point cases" 2 count
  pure count

loadSchedules :: FilePath -> IO [ReconcileSchedule]
loadSchedules root = do
  let directory = root </> "test/fixture/reconcile_core/schedules"
  names <- sort . filter (".json" `isSuffixOf`) <$> listDirectory directory
  schedules <- forM names $ \name -> do
    bytes <- ByteString.readFile (directory </> name)
    either (die . ((name <> ": ") <>)) pure (eitherDecodeStrict' bytes)
  assertEqual "schedule names"
    ["baseline", "crash-before-apply", "duplicate-delivery", "stale-snapshot"]
    (sort (map scheduleName schedules))
  pure schedules

loadScheduleExpectations :: FilePath -> IO (Map.Map Text ScheduleExpectation)
loadScheduleExpectations root = do
  rows <- rowsOf (root </> "test/oracle/reconcile_core/schedule_outcomes.tsv")
  case rows of
    (header : body) -> do
      assertEqual "schedule oracle header"
        ["schedule", "verdict", "accepted", "reuse_rejected", "stale_rejected", "required_event"] header
      expectations <- forM body $ \row -> case row of
        [name, "converged", accepted, reuse, stale, event] ->
          pure (Text.pack name, ScheduleExpectation (Text.pack name) (read accepted) (read reuse) (read stale) (Text.pack event))
        _ -> die ("invalid schedule oracle row: " <> show row)
      pure (Map.fromList expectations)
    [] -> die "empty schedule oracle"

checkSchedules
  :: [ReconcileSchedule]
  -> Map.Map Text ScheduleExpectation
  -> IO [(ReconcileSchedule, SimulationResult)]
checkSchedules schedules expectations = do
  assertEqual "schedule/oracle domain" (Set.fromList (map scheduleName schedules)) (Map.keysSet expectations)
  forM schedules $ \schedule -> do
    let first = runSimulation schedule
        second = runSimulation schedule
        expected = expectations Map.! scheduleName schedule
    assertEqual (Text.unpack (scheduleName schedule) <> " same-seed bytes") (encodeResult first) (encodeResult second)
    assertEqual "expected schedule self-name" (scheduleName schedule) (expectedSchedule expected)
    assertEqual "schedule convergence" SimulationConverged (simulationVerdict first)
    assertEqual "schedule final inventory" expectedFinal (simulationFinalInventory first)
    assertEqual "schedule accepted writes" (fromInteger (expectedAccepted expected)) (simulationAcceptedWrites first)
    assertEqual "schedule reuse rejections" (fromInteger (expectedReuse expected)) (simulationRejectedReuses first)
    assertEqual "schedule stale rejections" (fromInteger (expectedStale expected)) (simulationRejectedStale first)
    assert (any (expectedEvent expected `Text.isInfixOf`) (simulationTrace first))
      (Text.unpack (scheduleName schedule) <> " missed required event " <> Text.unpack (expectedEvent expected))
    pure (schedule, first)

checkScheduleSensitivity :: [ReconcileSchedule] -> IO ()
checkScheduleSensitivity schedules = do
  schedule <- findSchedule "baseline" schedules
  let perturbed = schedule {scheduleSeed = scheduleSeed schedule + 1}
  assert (simulationTrace (runSimulation schedule) /= simulationTrace (runSimulation perturbed))
    "changed seed produced the same semantic trace"

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

expectedFinal :: [Text]
expectedFinal = ["a=present:v2", "b=present:v1", "c=absent"]

checkTokenProtocol :: IO ()
checkTokenProtocol = do
  let outcomes = runSimOrThrow tokenRace
  assertEqual "one token race accepted and one rejected"
    [TokenApplied, TokenRejectedReuse]
    (sort outcomes)

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
  assertEqual "reservation debit remains exactly one" reservation (ledgerOnlyAbsentRecovery row)
  forM_ [Reserved, BindingInFlight, Bound] $ \cut -> do
    bound <- either (die . show) pure (recoverToBound cut)
    assertEqual ("reservation crash cut " <> show cut) Bound (ledgerReservationState bound)
    assertEqual "reservation debit after recovery" reservation (ledgerOnlyAbsentRecovery bound)

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
  BindingInFlight -> mapLeft show (confirmBound reservationGuard reservationRow {ledgerReservationState = BindingInFlight})
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

checkFormalCorrespondence :: FilePath -> IO ()
checkFormalCorrespondence root = do
  rows <- rowsOf (root </> "test/oracle/reconcile_core/formal_correspondence.tsv")
  case rows of
    (header : body) -> do
      assertEqual "formal correspondence header" ["property", "model", "invariant", "evidence"] header
      assertEqual "formal correspondence cardinality" 4 (length body)
      forM_ body $ \row -> case row of
        [_propertyName, modelName, invariantName, evidence] -> do
          assert (not (null evidence)) "formal correspondence evidence is empty"
          model <- case filter ((== modelName) . Formal.modelName) dslModels of
            [value] -> pure value
            _ -> die ("formal correspondence model is missing or duplicated: " <> modelName)
          assert (invariantName `elem` map Formal.namedExprName (Formal.modelInvariants model))
            ("formal correspondence invariant is absent: " <> modelName <> "/" <> invariantName)
        _ -> die ("invalid formal correspondence row: " <> show row)
    [] -> die "empty formal correspondence oracle"

writeResults :: FilePath -> Int -> Int -> IO ()
writeResults root fixedPoints scheduleCount = do
  let output = root </> ".build/dsl/reconcile-core"
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
  createDirectoryIfMissing True output
  writeFile (output </> "phase-results.tsv")
    ("metric\tresult\n" <> concat [Text.unpack key <> "\t" <> Text.unpack value <> "\n" | (key, value) <- metrics])

runMutant :: String -> IO ()
runMutant name = case name of
  "fixed-point-reemit" -> do
    let inventory = observedInventory [(ResourceId "a", SomeObservation (PresentObservation "v1"))]
        wanted = desiredIndex [(ResourceId "a", DesiredRevision "v1")]
    case reemitAtFixedPoint inventory (planReconcile inventory wanted) of
      Right (_ : _) -> red name "FixedPoint"
      result -> die ("fixed-point mutant survived: " <> show result)
  "oscillating-apply" -> do
    let inventory = observedInventory [(ResourceId "a", SomeObservation (PresentObservation "v1"))]
        wanted = desiredIndex [(ResourceId "a", DesiredRevision "v2")]
        terminal = iterateMutant 5 inventory wanted
    if planReconcile terminal wanted /= Right []
      then red name "Convergence"
      else die "oscillating-apply mutant converged"
  "token-guard-removed" -> do
    let actual = runSimOrThrow tokenRace
    if sort actual == [TokenApplied, TokenRejectedReuse] && acceptTokenReuse == TokenApplied
      then red name "NoTokenReuse"
      else die "token guard mutant precondition failed"
  "reservation-crash-drop" -> do
    if not (isJust (dropReservationOnCrash reservationRow {ledgerReservationState = BindingInFlight}))
      then red name "BoundRetainedAfterCrash"
      else die "reservation crash mutant retained the row"
  _ -> die ("unknown mutant: " <> name)

iterateMutant :: Int -> ObservedInventory -> DesiredIndex -> ObservedInventory
iterateMutant remaining inventory wanted
  | remaining <= 0 = inventory
  | otherwise = case planReconcile inventory wanted of
      Right (action : _) -> iterateMutant (remaining - 1) (oscillatingApply action inventory) wanted
      _ -> inventory

red :: String -> String -> IO value
red mutant propertyName = do
  putStrLn ("reconcile-core-mutant: RED " <> mutant <> " " <> propertyName)
  exitFailure

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

encodeResult :: SimulationResult -> LazyByteString.ByteString
encodeResult result = encode
  ( show (simulationVerdict result)
  , simulationFinalInventory result
  , simulationAcceptedWrites result
  , simulationRejectedReuses result
  , simulationRejectedStale result
  , simulationTrace result
  )

findSchedule :: Text -> [ReconcileSchedule] -> IO ReconcileSchedule
findSchedule name schedules = case filter ((== name) . scheduleName) schedules of
  [schedule] -> pure schedule
  _ -> die ("missing or duplicate schedule: " <> Text.unpack name)

rowsOf :: FilePath -> IO [[String]]
rowsOf path = map splitTabs . filter (not . null) . lines <$> readFile path

splitTabs :: String -> [String]
splitTabs value = case break (== '\t') value of
  (field, []) -> [field]
  (field, _ : rest) -> field : splitTabs rest

isSuffixOf :: Eq value => [value] -> [value] -> Bool
isSuffixOf suffix value = reverse suffix `isPrefixOf` reverse value

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
