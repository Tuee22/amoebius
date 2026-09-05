{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Capacity.Fold (fits)
import Amoebius.Capacity.Types (Demand (..), Headroom (..), ResourceVector (..))
import Amoebius.Cluster.NodeProvisioner
import Amoebius.Formal.Dsl.Models
import Amoebius.Formal.EmitTLA
import Amoebius.Formal.Explore
import Amoebius.Formal.Interpret (evalExpr, valueAsBool)
import Amoebius.Formal.Model
import Amoebius.Manifest.Authority
import Amoebius.Scheduler.Ledger
import Amoebius.Scheduler.Reservation
import CalculusProjection
  ( CalculusProjection (..)
  , referenceCalculusModel
  , referenceCalculusProjection
  )
import Control.Monad (forM, forM_, unless)
import Data.Char (isDigit, isSpace)
import Data.List (find, intercalate, isInfixOf, isPrefixOf, tails)
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe)
import Data.Set (Set)
import qualified Data.Set as Set
import qualified Data.Text as Text
import DslFormalModelOracle
import System.Directory (canonicalizePath, createDirectoryIfMissing, doesFileExist, getCurrentDirectory)
import System.Environment (lookupEnv)
import System.Exit (ExitCode (..), exitFailure)
import System.FilePath ((</>))
import System.Process (readProcessWithExitCode)

data TlcResult = TlcResult
  { tlcExit :: ExitCode
  , tlcOutput :: String
  , tlcFingerprints :: Set String
  , tlcDistinctCount :: Maybe Int
  }

main :: IO ()
main = do
  root <- getCurrentDirectory >>= canonicalizePath
  java <- resolveTool root "AMOEBIUS_JAVA" ".build/toolchain/runtime/java/bin/java"
  jar <- resolveTool root "AMOEBIUS_TLA2TOOLS" ".build/toolchain/runtime/tla/tla2tools.jar"
  configuredOutput <- lookupEnv "AMOEBIUS_DSL_FORMAL_MODEL_OUTPUT"
  let output = fromMaybe (root </> ".build/tla/dsl-formal-model-spec") configuredOutput
  createDirectoryIfMissing True output

  putStrLn "dsl-formal-model-spec: actual DSL projections"
  capacityCases <- checkCapacityProjection
  protocolFacts <- checkProtocolImplementations
  calculusModel <- checkCalculusComposition

  putStrLn "dsl-formal-model-spec: model contract and explorer/TLC agreement"
  let contracts = expectedModelContracts
  let models = dslModels <> [calculusModel]
  assertEqual "model contract names" (map contractName contracts) (map modelName models)
  explored <- forM models $ \model -> do
    contract <- requireJust ("contract for " <> modelName model) (find ((== modelName model) . contractName) contracts)
    checkModelContract contract model
    result <- requireRight (modelName model <> " explorer") (explore model)
    assertEqual (modelName model <> " state count") (contractStates contract) (Map.size (exploreStates result))
    assertEqual (modelName model <> " explorer safety") Nothing (exploreViolation result)
    pure (model, result)

  agreement <- forM [(model, result) | (model, result) <- explored, modelName model /= "CalculusComposition"] $
    \(model, result) -> do
      tlc <- runTlc java jar output ("correct-" <> modelName model) True model
      assertTlcGreen (modelName model) tlc
      assertEqual (modelName model <> " TLC state count") (Just (Map.size (exploreStates result))) (tlcDistinctCount tlc)
      assertEqual (modelName model <> " explorer/TLC fingerprints")
        (Map.keysSet (exploreStates result)) (tlcFingerprints tlc)
      pure True

  putStrLn "dsl-formal-model-spec: exact safety and fairness mutants"
  checkMutationCatalogue
  forM_ dslSafetyMutants $ \(name, expectedInvariant, mutant) -> do
    violations <- requireRight (name <> " violations") (allViolations mutant)
    assertEqual (name <> " exact invariant") (Set.singleton expectedInvariant) violations
    tlc <- runTlc java jar output ("mutant-" <> name) False (safetyOnly mutant)
    assertTlcRed name tlc
  fairnessDrops <- forM dslFairnessModels $ \model -> do
    let mutant = model {modelFairness = []}
    tlc <- runTlc java jar output ("fairness-drop-" <> modelName model) False mutant
    assertTlcRed (modelName model <> " without fairness") tlc
    pure True

  writeResults output
    (length models)
    (sum [Map.size (exploreStates result) | (_, result) <- explored])
    (length (filter id agreement))
    (sum (map (length . modelInvariants) dslModels))
    (sum (map (length . modelProperties) dslModels))
    (length dslSafetyMutants)
    (length (filter id fairnessDrops))
    capacityCases
    protocolFacts
  putStrLn "dsl-formal-model-spec: PASS (6 models, 18 states, 8 invariants, 4 properties, 6561 capacity cases)"

resolveTool :: FilePath -> String -> FilePath -> IO FilePath
resolveTool root variable relative = do
  configured <- lookupEnv variable
  canonicalizePath (fromMaybe (root </> relative) configured)

checkCapacityProjection :: IO Int
checkCapacityProjection = do
  let vectors =
        [ ResourceVector cpu memory ephemeral pods
        | cpu <- [0 .. 2], memory <- [0 .. 2], ephemeral <- [0 .. 2], pods <- [0 .. 2]
        ]
      capacityCases = [(demand, capacity) | demand <- vectors, capacity <- vectors]
  forM_ capacityCases $ \(demand, capacity) ->
    checkCapacityCase demand capacity
  assertEqual "capacity domain" expectedCapacityDomain "0..2x4-demand/capacity"
  assertEqual "capacity case count" expectedCapacityCaseCount (length capacityCases)
  pure (length capacityCases)

checkCapacityCase :: ResourceVector -> ResourceVector -> IO ()
checkCapacityCase demand capacity = case (referenceHeadroom demand capacity, fits (Demand demand) capacity) of
  (Just expected, Right (Headroom actual)) -> assertEqual "capacity headroom" expected actual
  (Nothing, Left _) -> pure ()
  (Just _, Left problem) -> failCheck ("capacity fit rejected an admitted vector: " <> show problem)
  (Nothing, Right actual) -> failCheck ("capacity fit admitted an overcommit: " <> show actual)

referenceHeadroom :: ResourceVector -> ResourceVector -> Maybe ResourceVector
referenceHeadroom demand capacity
  | and
      [ resourceCpu demand <= resourceCpu capacity
      , resourceMemory demand <= resourceMemory capacity
      , resourceEphemeralStorage demand <= resourceEphemeralStorage capacity
      , resourcePodSlots demand <= resourcePodSlots capacity
      ] = Just (ResourceVector
          (resourceCpu capacity - resourceCpu demand)
          (resourceMemory capacity - resourceMemory demand)
          (resourceEphemeralStorage capacity - resourceEphemeralStorage demand)
          (resourcePodSlots capacity - resourcePodSlots demand))
  | otherwise = Nothing

checkProtocolImplementations :: IO Int
checkProtocolImplementations = do
  checkLeaseToken
  checkReservation
  checkUnreachableReconcile
  pure 3

checkLeaseToken :: IO ()
checkLeaseToken = do
  planned <- planLeaseAction leaseIdentity holder (LeaseAbsent leaseIdentity)
  token <- requireRight "lease token mint" planned
  first <- consumeLeaseActionToken token
  assertEqual "first lease token consume" (Right (BootstrapAcquire leaseIdentity holder)) first
  second <- consumeLeaseActionToken token
  assertEqual "second lease token consume" (Left LeaseTokenAlreadyConsumed) second
  foreignResult <- planLeaseAction leaseIdentity holder (LeasePresent leaseIdentity "foreign" "uid" "7")
  case foreignResult of
    Left (LeaseHolderMismatch expected actual) -> assertEqual "foreign holder pair" (holder, "foreign") (expected, actual)
    _ -> failCheck "foreign lease holder was not rejected at its exact reason"
 where
  leaseIdentity = "Lease/ns/reconciler"
  holder = "holder"

checkReservation :: IO ()
checkReservation = do
  root <- newReservationRoot
  created <- reserveCandidate capacity [] 0 candidate root
  assert (isCreatedAt 1 created) "reservation was not created at version 1"
  reused <- reserveCandidate capacity [] 1 candidate root
  assert (isReusedAt 1 reused) "same UID reservation changed the version or debit"
  invalid <- transitionReservation 1 uid Reserved Bound root
  case invalid of
    Left (ReservationTransitionIllegal Reserved Bound) -> pure ()
    _ -> failCheck "illegal reservation transition missed its exact reason"
  prepared <- transitionReservation 1 uid Reserved BindingInFlight root
  assert (isTransitionedAt BindingInFlight 2 prepared) "reservation did not enter BindingInFlight"
  bound <- transitionReservation 2 uid BindingInFlight Bound root
  assert (isTransitionedAt Bound 3 bound) "reservation did not become Bound"
  snapshot <- readReservationRoot root
  assertEqual "one reservation record" 1 (Map.size (reservationRootRecords snapshot))
  assertEqual "reservation root version" 3 (reservationRootVersion snapshot)
  assertEqual "reservation final state" (Just Bound)
    (reservationState <$> Map.lookup uid (reservationRootRecords snapshot))
 where
  uid = SchedulerPodUid "pod-a"
  debit = SchedulerResourceVector 1 1 1 1 1 1
  capacity = SchedulerResourceVector 10 10 10 10 10 10
  candidate = ReservationCandidate uid "node" "generation" "digest" debit debit
  isCreatedAt version result = case result of
    Right (ReservationCreated _ actual) -> actual == version
    _ -> False
  isReusedAt version result = case result of
    Right (ReservationReused _ actual) -> actual == version
    _ -> False
  isTransitionedAt state version result = case result of
    Right (ReservationTransitioned record actual) -> reservationState record == state && actual == version
    _ -> False

checkUnreachableReconcile :: IO ()
checkUnreachableReconcile = do
  assertEqual "unreachable reconcile refusal" (Left RefuseOnUnreachable)
    (planNodeSet nodeClass observed quota demand (Load False) 2 Unreachable)
  assertEqual "present reconcile removal" (Right (RemoveNode 1))
    (planNodeSet nodeClass observed quota demand (Load False) 2 Present)
 where
  nodeClass = ProviderNodeClass "cpu" 4 4000 4096 4096 8 8 4 100  False 1 3
  observed = ObservedNodeLimits 8 8 4
  quota = ProviderQuota 3 12 300 3
  demand = NodeDemand 1000 1024 1024 1 ["claim"] Cpu

checkCalculusComposition :: IO Model
checkCalculusComposition = do
  projection <- either (failCheck . ("calculus projection: " <>)) pure referenceCalculusProjection
  model <- either (failCheck . ("calculus model: " <>)) pure referenceCalculusModel
  explored <- requireRight "calculus composition explorer" (explore model)
  let resources = map Text.unpack (Text.splitOn "," (projectionResources projection))
      actual = case resources of
        [cpu, memory, ephemeral, pods] -> Map.fromList
          [ ("calculus-kinds", intercalate "," (map Text.unpack (projectionOrder projection)))
          , ("component-count", show (length (projectionNames projection)))
          , ("cpu", cpu), ("memory", memory), ("ephemeral", ephemeral), ("pods", pods)
          , ("formal-distinct-state-count", show (Map.size (exploreStates explored)))
          , ("formal-safety", if exploreViolation explored == Nothing then "green" else "red")
          ]
        _ -> Map.empty
  assertEqual "five-calculus formal projection" expectedCalculusFacts actual
  pure model

checkModelContract :: ModelContract -> Model -> IO ()
checkModelContract contract model = do
  assertEqual (modelName model <> " structural problems") [] (modelProblems model)
  assertEqual (modelName model <> " invariants") (contractInvariants contract)
    (map namedExprName (modelInvariants model))
  assertEqual (modelName model <> " properties") (contractProperties contract)
    (map propertyName (modelProperties model))
  assertEqual (modelName model <> " actions") (contractActions contract)
    (map actionName (modelActions model))
  let (Tla tla, Cfg cfg) = emitTLA model
  assert (("---- MODULE " <> modelName model <> " ----") `isInfixOf` tla) (modelName model <> " module missing")
  forM_ (contractActions contract) $ \name -> assert ((name <> actionSuffix name model) `isInfixOf` tla) (name <> " action missing")
  forM_ (contractInvariants contract) $ \name -> do
    assert ((name <> " ==") `isInfixOf` tla) (name <> " invariant definition missing")
    assert (("INVARIANT " <> name) `elem` lines cfg) (name <> " invariant cfg entry missing")
  forM_ (contractProperties contract) $ \name -> do
    assert ((name <> " ==") `isInfixOf` tla) (name <> " property definition missing")
    assert (("PROPERTY " <> name) `elem` lines cfg) (name <> " property cfg entry missing")
 where
  actionSuffix name subject = case find ((== name) . actionName) (modelActions subject) of
    Just value | null (actionParameters value) -> " =="
    Just _ -> "("
    Nothing -> ""

checkMutationCatalogue :: IO ()
checkMutationCatalogue =
  assertEqual "DSL mutation catalogue" expectedMutationCatalogue
    [(name, invariant) | (name, invariant, _) <- dslSafetyMutants]

allViolations :: Model -> Either String (Set Name)
allViolations model = do
  result <- explore model
  Set.fromList . concat <$> traverse violationsAt (Map.elems (exploreStates result))
 where
  violationsAt state = fmap concat . forM (modelInvariants model) $ \invariant -> do
    valid <- evalExpr model Map.empty state (namedExprBody invariant) >>= valueAsBool
    pure [namedExprName invariant | not valid]

safetyOnly :: Model -> Model
safetyOnly model = model {modelFairness = [], modelProperties = []}

runTlc :: FilePath -> FilePath -> FilePath -> String -> Bool -> Model -> IO TlcResult
runTlc java jar output suffix dumpStates model = do
  let directory = output </> suffix
      tlaPath = directory </> modelName model <> ".tla"
      cfgPath = directory </> modelName model <> ".cfg"
      dotPath = directory </> modelName model <> ".dot"
      (Tla tla, Cfg cfg) = emitTLA model
      dumpArgs = if dumpStates then ["-dump", "dot,actionlabels", dotPath] else []
  createDirectoryIfMissing True directory
  writeFile tlaPath tla
  writeFile cfgPath cfg
  (exitCode, stdoutText, stderrText) <- readProcessWithExitCode java
    ([ "-XX:+UseParallelGC", "-jar", jar, "-workers", "1", "-cleanup", "-nowarning"
     , "-fp", "0", "-seed", "1"
     ] <> dumpArgs <> ["-config", cfgPath, tlaPath]) ""
  let outputText = stdoutText <> stderrText
  writeFile (directory </> modelName model <> ".tlc.log") outputText
  dot <- if dumpStates then readFileIfPresent dotPath else pure ""
  pure TlcResult
    { tlcExit = exitCode
    , tlcOutput = outputText
    , tlcFingerprints = parseDotFingerprints model dot
    , tlcDistinctCount = parseDistinctCount outputText
    }

assertTlcGreen :: String -> TlcResult -> IO ()
assertTlcGreen label result =
  assert (tlcExit result == ExitSuccess) (label <> " failed:\n" <> tlcOutput result)

assertTlcRed :: String -> TlcResult -> IO ()
assertTlcRed label result =
  assert (tlcExit result /= ExitSuccess) (label <> " unexpectedly passed")

writeResults :: FilePath -> Int -> Int -> Int -> Int -> Int -> Int -> Int -> Int -> Int -> IO ()
writeResults output modelCount stateTotal agreements invariants properties mutants fairnessDrops
    capacityCases protocolCases =
  writeFile (output </> "phase-results.tsv") . unlines $
    [ "metric\tvalue"
    , "formal-model-count\t" <> show modelCount
    , "explorer-state-total\t" <> show stateTotal
    , "explorer-tlc-fingerprints\t" <> show agreements <> "/5-equal"
    , "dsl-safety-invariants\t" <> show invariants <> "/8-green-explorer-tlc"
    , "liveness-properties\t" <> show properties <> "/4-green-under-fairness"
    , "fairness-drop-mutants\t" <> show fairnessDrops <> "/4-red"
    , "exact-safety-mutants\t" <> show mutants <> "/8-red-exactly"
    , "capacity-differential\t" <> show capacityCases <> "/6561"
    , "protocol-code-projection\t" <> show protocolCases <> "/3-green"
    , "calculus-composition-projection\tgreen"
    , "renderer-semantics\t" <> show modelCount <> "/6-green"
    , "runtime-fidelity\tUNVERIFIED"
    ]

parseDistinctCount :: String -> Maybe Int
parseDistinctCount output = do
  line <- find (" distinct states found" `isInfixOf`) (reverse (lines output))
  preceding <- wordBefore "distinct" (words line)
  readMaybeInt (filter isDigit preceding)

wordBefore :: Eq value => value -> [value] -> Maybe value
wordBefore target = go Nothing
 where
  go _ [] = Nothing
  go previous (value : rest)
    | value == target = previous
    | otherwise = go (Just value) rest

readMaybeInt :: String -> Maybe Int
readMaybeInt value = case reads (takeWhile isDigit value) of
  [(parsed, "")] -> Just parsed
  _ -> Nothing

parseDotFingerprints :: Model -> String -> Set String
parseDotFingerprints model dot = Set.fromList
  [ fingerprintFromLabel model label
  | line <- lines dot
  , " -> " `notElemIn` line
  , Just label <- [extractLabel line]
  , " = " `isInfixOf` label
  ]
 where
  needle `notElemIn` haystack = not (needle `isInfixOf` haystack)

extractLabel :: String -> Maybe String
extractLabel line = do
  rest <- stripAfter "[label=\"" line
  pure (unescapeDot (takeUntilLabelEnd rest))

takeUntilLabelEnd :: String -> String
takeUntilLabelEnd = go False
 where
  go _ [] = []
  go escaped ('"' : rest) | not escaped && labelEnded rest = []
  go escaped (character : rest) = character : go (character == '\\' && not escaped) rest
  labelEnded [] = True
  labelEnded (next : _) = next == ']' || next == ','

unescapeDot :: String -> String
unescapeDot [] = []
unescapeDot ('\\' : 'n' : rest) = '\n' : unescapeDot rest
unescapeDot ('\\' : '"' : rest) = '"' : unescapeDot rest
unescapeDot ('\\' : '\\' : rest) = '\\' : unescapeDot rest
unescapeDot (character : rest) = character : unescapeDot rest

fingerprintFromLabel :: Model -> String -> String
fingerprintFromLabel model label = intercalate "|"
  [ name <> "=" <> Map.findWithDefault "<missing>" name assignments
  | name <- modelVariables model
  ]
 where
  assignments = Map.fromList
    [ let (name, valueWithEquals) = breakOn " = " (trim (dropConjunct line))
       in (trim name, trim (drop 3 valueWithEquals))
    | line <- lines label
    , " = " `isInfixOf` line
    ]
  dropConjunct line = fromMaybe line (stripAfter "/\\ " line)

stripAfter :: String -> String -> Maybe String
stripAfter needle haystack = case find (needle `isPrefixOf`) (tails haystack) of
  Nothing -> Nothing
  Just match -> Just (drop (length needle) match)

breakOn :: String -> String -> (String, String)
breakOn needle haystack = case findIndexPrefix needle haystack of
  Nothing -> (haystack, "")
  Just index -> splitAt index haystack

findIndexPrefix :: String -> String -> Maybe Int
findIndexPrefix needle = go 0
 where
  go _ [] = Nothing
  go index rest@(_ : remaining)
    | needle `isPrefixOf` rest = Just index
    | otherwise = go (index + 1) remaining

trim :: String -> String
trim = reverse . dropWhile isSpace . reverse . dropWhile isSpace

readFileIfPresent :: FilePath -> IO String
readFileIfPresent path = do
  present <- doesFileExist path
  if present then readFile path else pure ""

assert :: Bool -> String -> IO ()
assert condition message = unless condition (failCheck message)

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual =
  assert (expected == actual) (label <> ": expected " <> show expected <> ", got " <> show actual)

requireRight :: String -> Either error value -> IO value
requireRight label value = case value of
  Left _ -> failCheck (label <> " returned Left")
  Right result -> pure result

requireJust :: String -> Maybe value -> IO value
requireJust label value = case value of
  Nothing -> failCheck (label <> " is missing")
  Just result -> pure result

failCheck :: String -> IO value
failCheck message = putStrLn ("FAIL: " <> message) >> exitFailure
