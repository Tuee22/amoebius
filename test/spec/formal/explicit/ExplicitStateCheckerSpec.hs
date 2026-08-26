module Main (main) where

import Amoebius.Checker.ExplicitState
import Amoebius.Formal.Explore qualified as Explorer
import Amoebius.Formal.Model
import Amoebius.Formal.ToyModel (toyModel)
import Control.Monad (forM, forM_, unless)
import Data.Char (isHexDigit)
import Data.List (find)
import Data.Map.Strict qualified as Map
import System.Directory (createDirectoryIfMissing)
import System.Exit (exitFailure)
import System.FilePath ((</>))

data Expected = Expected
  { expectedModel :: String
  , expectedBound :: Int
  , expectedStatus :: String
  , expectedStates :: Int
  , expectedViolation :: String
  , expectedTraceLength :: Int
  }
  deriving stock (Eq, Show)

main :: IO ()
main = do
  rows <- readOracle
  assertEqual "fixture names" (map fst fixtureModels) (map expectedModel rows)
  observations <- forM rows checkRow
  let verdicts = map fst observations
      parityPassed = length [() | (_, True) <- observations]
      replayed = length
        [ ()
        | verdict <- verdicts
        , Unsafe counterexample <- [verdictResult verdict]
        , Right _ <- [replayCounterexample (modelFor rows verdict) counterexample]
        ]
  assertEqual "invalid zero bound" (Left (InvalidSearchBound 0)) (mkSearchBound 0)
  assertDigestBinding verdicts
  assertTraceTamper rows verdicts
  writeResults verdicts parityPassed replayed
  putStrLn "explicit-state-checker-spec: PASS (7 fixtures, 5 explorer parity rows, 2 replayed counterexamples)"
 where
  modelFor rows verdict = case
      [ model
      | row <- rows
      , let model = lookupModel (expectedModel row)
      , modelDigest model == verdictModelDigest verdict
      ] of
    model : _ -> model
    [] -> error "verdict digest did not identify a fixture model"

checkRow :: Expected -> IO (Verdict, Bool)
checkRow row = do
  bound <- requireRight "search bound" (mkSearchBound (expectedBound row))
  let model = lookupModel (expectedModel row)
  verdict <- requireRight (expectedModel row) (checkModel bound model)
  assertEqual (expectedModel row <> " bound") (expectedBound row) (verdictBound verdict)
  assertEqual (expectedModel row <> " distinct states") (expectedStates row) (verdictDistinctStates verdict)
  assertEqual (expectedModel row <> " status") (expectedStatus row) (statusName (verdictResult verdict))
  assertEqual (expectedModel row <> " violation") (expectedViolation row) (violationName (verdictResult verdict))
  assertEqual (expectedModel row <> " trace length")
    (expectedTraceLength row) (traceLength (verdictResult verdict))
  replayIfUnsafe model verdict
  parity <- explorerParity row model verdict
  pure (verdict, parity)

replayIfUnsafe :: Model -> Verdict -> IO ()
replayIfUnsafe model verdict = case verdictResult verdict of
  Unsafe counterexample -> do
    terminal <- requireRight "counterexample replay" (replayCounterexample model counterexample)
    assertEqual "counterexample terminal fingerprint"
      (counterexampleState counterexample)
      (Explorer.canonicalFingerprint model terminal)
  _ -> pure ()

explorerParity :: Expected -> Model -> Verdict -> IO Bool
explorerParity row model verdict
  | expectedStatus row == "bound-exceeded" || expectedStatus row == "unsafe-deadlock" = pure False
  | otherwise = do
      explored <- requireRight "Phase-11 explorer parity" (Explorer.explore model)
      assertEqual (expectedModel row <> " explorer state parity")
        (Map.size (Explorer.exploreStates explored)) (verdictDistinctStates verdict)
      let explorerUnsafe = Explorer.exploreViolation explored /= Nothing
          checkerUnsafe = case verdictResult verdict of
            Unsafe Counterexample {counterexampleViolation = InvariantViolation _} -> True
            _ -> False
      assertEqual (expectedModel row <> " explorer verdict parity") explorerUnsafe checkerUnsafe
      pure True

statusName :: CheckResult -> String
statusName result = case result of
  Safe -> "safe"
  Unsafe Counterexample {counterexampleViolation = InvariantViolation _} -> "unsafe-invariant"
  Unsafe Counterexample {counterexampleViolation = DeadlockViolation} -> "unsafe-deadlock"
  BoundExceeded _ -> "bound-exceeded"

violationName :: CheckResult -> String
violationName result = case result of
  Unsafe Counterexample {counterexampleViolation = InvariantViolation name} -> name
  Unsafe Counterexample {counterexampleViolation = DeadlockViolation} -> "deadlock"
  _ -> "-"

traceLength :: CheckResult -> Int
traceLength (Unsafe counterexample) = length (counterexampleTrace counterexample)
traceLength _ = 0

assertDigestBinding :: [Verdict] -> IO ()
assertDigestBinding verdicts = do
  forM_ verdicts $ \verdict -> do
    assert (length (verdictModelDigest verdict) == 64) "model digest is not 64 hex characters"
    assert (all isHexDigit (verdictModelDigest verdict)) "model digest is not hexadecimal"
  assert (modelDigest safeCounter /= modelDigest (safeCounter {modelName = "RenamedCounter"}))
    "model digest did not bind the model name"

assertTraceTamper :: [Expected] -> [Verdict] -> IO ()
assertTraceTamper rows verdicts = case find ((== "unsafe-counter") . expectedModel) rows of
  Nothing -> failTest "unsafe-counter row missing"
  Just row -> case find ((== modelDigest (lookupModel (expectedModel row))) . verdictModelDigest) verdicts of
    Just Verdict {verdictResult = Unsafe counterexample} -> case reverse (counterexampleTrace counterexample) of
      [] -> failTest "unsafe-counter trace unexpectedly empty"
      lastStep : preceding -> do
        let forged = counterexample
              { counterexampleTrace = reverse (lastStep {traceTo = "forged"} : preceding)
              }
        case replayCounterexample (lookupModel (expectedModel row)) forged of
          Left (TraceReplayFailure _) -> pure ()
          outcome -> failTest ("forged trace failed at the wrong reason: " <> show outcome)
    _ -> failTest "unsafe-counter verdict missing"

writeResults :: [Verdict] -> Int -> Int -> IO ()
writeResults verdicts parityPassed replayed = do
  let output = ".build" </> "checkers" </> "explicit-state"
      count predicate = length (filter (predicate . verdictResult) verdicts)
  createDirectoryIfMissing True output
  writeFile (output </> "results.tsv") . unlines $
    [ "metric\tvalue"
    , "fixture-count\t" <> show (length verdicts)
    , "safe-count\t" <> show (count (== Safe))
    , "invariant-counterexample-count\t" <> show (count isInvariant)
    , "deadlock-counterexample-count\t" <> show (count isDeadlock)
    , "bound-exceeded-count\t" <> show (count isBoundExceeded)
    , "explorer-parity-count\t" <> show parityPassed
    , "replayed-counterexample-count\t" <> show replayed
    , "distinct-state-total\t" <> show (sum (map verdictDistinctStates verdicts))
    , "digest-binding\tyes"
    ]
 where
  isInvariant (Unsafe Counterexample {counterexampleViolation = InvariantViolation _}) = True
  isInvariant _ = False
  isDeadlock (Unsafe Counterexample {counterexampleViolation = DeadlockViolation}) = True
  isDeadlock _ = False
  isBoundExceeded (BoundExceeded _) = True
  isBoundExceeded _ = False

readOracle :: IO [Expected]
readOracle = do
  rows <- lines <$> readFile "test/oracle/explicit_state_checker/models.tsv"
  case rows of
    [] -> failTest "explicit-state oracle is empty" >> pure []
    header : body -> do
      assertEqual "oracle header"
        "model\tbound\tstatus\tdistinct_states\tviolation\ttrace_length" header
      mapM parseRow body

parseRow :: String -> IO Expected
parseRow row = case splitOn '\t' row of
  [name, boundText, status, statesText, violation, traceText] ->
    Expected name <$> parseInt boundText <*> pure status <*> parseInt statesText <*> pure violation <*> parseInt traceText
  fields -> failTest ("malformed oracle row: " <> show fields) >> pure (Expected "" 0 "" 0 "" 0)
 where
  parseInt text = case reads text of
    [(value, "")] -> pure value
    _ -> failTest ("invalid integer in oracle row: " <> text) >> pure 0

fixtureModels :: [(String, Model)]
fixtureModels =
  [ ("toy-safe", toyModel)
  , ("toy-too-small", toyModel)
  , ("safe-counter", safeCounter)
  , ("unsafe-counter", unsafeCounter)
  , ("deadlock", deadlockModel)
  , ("constraint", constraintModel)
  , ("branching", branchingModel)
  ]

lookupModel :: String -> Model
lookupModel name = case lookup name fixtureModels of
  Just model -> model
  Nothing -> error ("unknown fixture model " <> name)

safeCounter :: Model
safeCounter = counterModel "SafeCounter" (ArithmeticComparison LessThanOrEqual (Ref "x") (int 2))

unsafeCounter :: Model
unsafeCounter = counterModel "UnsafeCounter" (ArithmeticComparison LessThan (Ref "x") (int 2))

counterModel :: Name -> Expr -> Model
counterModel name invariant = baseModel
  { modelName = name
  , modelVariables = ["x"]
  , modelInit = [("x", int 0)]
  , modelActions =
      [ Action "Advance" [] (ArithmeticComparison LessThan (Ref "x") (int 2))
          [("x", Add (Ref "x") (int 1))]
      ]
  , modelInvariants = [NamedExpr (if name == "UnsafeCounter" then "BelowTwo" else "AtMostTwo") invariant]
  }

deadlockModel :: Model
deadlockModel = baseModel
  { modelName = "Deadlock"
  , modelVariables = ["x"]
  , modelInit = [("x", int 0)]
  , modelCheckDeadlock = True
  }

constraintModel :: Model
constraintModel = baseModel
  { modelName = "Constraint"
  , modelVariables = ["x"]
  , modelInit = [("x", int 0)]
  , modelActions =
      [ Action "Advance" [] (ArithmeticComparison LessThan (Ref "x") (int 3))
          [("x", Add (Ref "x") (int 1))]
      ]
  , modelInvariants = [NamedExpr "NonNegative" (ArithmeticComparison GreaterThanOrEqual (Ref "x") (int 0))]
  , modelConstraint = Just (NamedExpr "AtMostOne" (ArithmeticComparison LessThanOrEqual (Ref "x") (int 1)))
  }

branchingModel :: Model
branchingModel = baseModel
  { modelName = "Branching"
  , modelConstants = [("Choice", SetValue [AtomValue "a", AtomValue "b"])]
  , modelVariables = ["x"]
  , modelInit = [("x", atom "start")]
  , modelActions =
      [ Action "Choose" [Parameter "choice" (Ref "Choice")]
          (Equal (Ref "x") (atom "start")) [("x", Ref "choice")]
      ]
  , modelInvariants = [NamedExpr "KnownChoice" (FiniteSetMembership (Ref "x")
      (FiniteSet [atom "start", atom "a", atom "b"]))]
  }

baseModel :: Model
baseModel = Model
  { modelName = "Base"
  , modelConstants = []
  , modelVariables = []
  , modelInit = []
  , modelActions = []
  , modelInvariants = []
  , modelConstraint = Nothing
  , modelExpansionLimit = Nothing
  , modelFairness = []
  , modelProperties = []
  , modelCheckDeadlock = False
  }

int :: Integer -> Expr
int = Literal . IntValue

atom :: String -> Expr
atom = Literal . AtomValue

requireRight :: Show problem => String -> Either problem value -> IO value
requireRight label result = case result of
  Left problem -> failTest (label <> ": " <> show problem) >> error "unreachable"
  Right value -> pure value

assert :: Bool -> String -> IO ()
assert condition message = unless condition (failTest message)

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual =
  assert (expected == actual) (label <> ": expected " <> show expected <> ", got " <> show actual)

failTest :: String -> IO ()
failTest message = putStrLn ("FAIL: " <> message) >> exitFailure

splitOn :: Char -> String -> [String]
splitOn delimiter text = case break (== delimiter) text of
  (piece, []) -> [piece]
  (piece, _ : rest) -> piece : splitOn delimiter rest
