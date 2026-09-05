module Main (main) where

import Amoebius.Checker.ExplicitState qualified as Explicit
import Amoebius.Checker.Symbolic
import Amoebius.Formal.Model
import Control.Monad (forM, forM_, unless)
import Data.Char (isHexDigit)
import Data.List (isInfixOf)
import System.Directory (createDirectoryIfMissing)
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.FilePath ((</>))
import System.IO (hPutStrLn, stderr)

data Expected = Expected
  { expectedModel :: String
  , expectedBound :: Int
  , expectedSymbolic :: String
  , expectedInvariant :: String
  , expectedAction :: String
  , expectedExplicit :: String
  , expectedRelation :: String
  , expectedObligations :: Int
  }
  deriving stock (Eq, Show)

data Observation = Observation
  { observedExpected :: Expected
  , observedSymbolic :: SymbolicVerdict
  }

main :: IO ()
main = do
  arguments <- getArgs
  (solverPath, output) <- case arguments of
    [path, root] -> pure (path, root)
    _ -> failTest "expected exact argv: SOLVER OUTPUT_ROOT" >> pure ("", "")
  solver <- mkSolver solverPath >>= requireRight "absolute solver"
  relative <- mkSolver "z3"
  assertEqual "ambient solver path rejected" (Left (SolverPathNotAbsolute "z3")) relative
  rows <- readOracle
  assertEqual "fixture names" (map fst fixtureModels) (map expectedModel rows)
  observations <- forM rows (checkRow solver)
  let agreementCount = length
        [ () | observation <- observations, expectedRelation (observedExpected observation) == "agree" ]
      conservativeCount = length
        [ () | observation <- observations, expectedRelation (observedExpected observation) == "conservative" ]
      sharedDigests = length
        [ ()
        | observation <- observations
        , let model = lookupModel (expectedModel (observedExpected observation))
        , verdictModelDigest (observedSymbolic observation) == Explicit.modelDigest model
        ]
  assertEqual "shared model digests" 7 sharedDigests
  writeResults output observations agreementCount conservativeCount sharedDigests
  putStrLn "symbolic-checker-spec: PASS (7 fixtures, 5 explicit agreements, 3 induction witnesses)"

checkRow :: Solver -> Expected -> IO Observation
checkRow solver row = do
  let model = lookupModel (expectedModel row)
  symbolic <- checkInductive solver model >>= requireRight (expectedModel row <> " symbolic")
  bound <- requireRight "explicit bound" (Explicit.mkSearchBound (expectedBound row))
  explicit <- requireRight (expectedModel row <> " explicit") (Explicit.checkModel bound model)
  assertEqual (expectedModel row <> " symbolic status")
    (expectedSymbolic row) (symbolicStatus (verdictResult symbolic))
  assertEqual (expectedModel row <> " failing invariant")
    (expectedInvariant row) (failingInvariant (verdictResult symbolic))
  assertEqual (expectedModel row <> " failing action")
    (expectedAction row) (failingAction (verdictResult symbolic))
  assertEqual (expectedModel row <> " obligation count")
    (expectedObligations row) (verdictObligationCount symbolic)
  assertEqual (expectedModel row <> " explicit status")
    (expectedExplicit row) (explicitStatus (Explicit.verdictResult explicit))
  assertEqual (expectedModel row <> " symbolic digest")
    (symbolicModelDigest model) (verdictModelDigest symbolic)
  assert (length (verdictModelDigest symbolic) == 64
      && all isHexDigit (verdictModelDigest symbolic))
    (expectedModel row <> " digest is not 64 hexadecimal characters")
  validateEvidence row (verdictResult symbolic)
  validateRelation row symbolic explicit
  pure (Observation row symbolic)

validateEvidence :: Expected -> SymbolicResult -> IO ()
validateEvidence row result = case result of
  Inductive witness -> do
    assertEqual (expectedModel row <> " witness length")
      (expectedObligations row) (length (witnessObligations witness))
    forM_ (witnessObligations witness) $ \(_, queryHash) ->
      assert (length queryHash == 64 && all isHexDigit queryHash)
        (expectedModel row <> " witness query digest malformed")
  NotInductive counterexample -> do
    assert (length (counterexampleQueryDigest counterexample) == 64)
      (expectedModel row <> " counterexample query digest malformed")
    assert ("sat" `isInfixOf` counterexampleSolverModel counterexample)
      (expectedModel row <> " counterexample carries no solver model")
  Unsupported features -> assert (not (null features))
    (expectedModel row <> " unsupported verdict has no feature")
  Inconclusive _ reason -> failTest (expectedModel row <> " solver was inconclusive: " <> reason)

validateRelation :: Expected -> SymbolicVerdict -> Explicit.Verdict -> IO ()
validateRelation row symbolic explicit = case expectedRelation row of
  "agree" -> case (verdictResult symbolic, Explicit.verdictResult explicit) of
    (Inductive _, Explicit.Safe) -> pure ()
    (NotInductive _, Explicit.Unsafe _) -> pure ()
    outcomes -> failTest (expectedModel row <> " agreement mismatch: " <> show outcomes)
  "conservative" -> case (verdictResult symbolic, Explicit.verdictResult explicit) of
    (NotInductive counterexample, Explicit.Safe) -> case counterexampleObligation counterexample of
      StepCase _ _ _ -> pure ()
      kind -> failTest (expectedModel row <> " conservative result was not a step case: " <> show kind)
    outcomes -> failTest (expectedModel row <> " conservative mismatch: " <> show outcomes)
  "unsupported" -> case (verdictResult symbolic, Explicit.verdictResult explicit) of
    (Unsupported _, Explicit.Safe) -> pure ()
    outcomes -> failTest (expectedModel row <> " unsupported mismatch: " <> show outcomes)
  relation -> failTest ("unknown relation " <> relation)

symbolicStatus :: SymbolicResult -> String
symbolicStatus result = case result of
  Inductive _ -> "inductive"
  NotInductive InductionCounterexample {counterexampleObligation = BaseCase _} -> "base-failure"
  NotInductive InductionCounterexample {counterexampleObligation = StepCase _ _ _} -> "step-failure"
  Unsupported _ -> "unsupported"
  Inconclusive _ _ -> "inconclusive"

failingInvariant :: SymbolicResult -> String
failingInvariant result = case result of
  NotInductive InductionCounterexample {counterexampleObligation = BaseCase name} -> name
  NotInductive InductionCounterexample {counterexampleObligation = StepCase name _ _} -> name
  _ -> "-"

failingAction :: SymbolicResult -> String
failingAction result = case result of
  NotInductive InductionCounterexample {counterexampleObligation = StepCase _ action _} -> action
  _ -> "-"

explicitStatus :: Explicit.CheckResult -> String
explicitStatus result = case result of
  Explicit.Safe -> "safe"
  Explicit.Unsafe Explicit.Counterexample {Explicit.counterexampleViolation = Explicit.InvariantViolation _} ->
    "unsafe-invariant"
  Explicit.Unsafe Explicit.Counterexample {Explicit.counterexampleViolation = Explicit.DeadlockViolation} ->
    "unsafe-deadlock"
  Explicit.BoundExceeded _ -> "bound-exceeded"

writeResults :: FilePath -> [Observation] -> Int -> Int -> Int -> IO ()
writeResults output observations agreements conservative sharedDigests = do
  let results = map (verdictResult . observedSymbolic) observations
      count predicate = length (filter predicate results)
  createDirectoryIfMissing True output
  writeFile (output </> "results.tsv") . unlines $
    [ "metric\tvalue"
    , "fixture-count\t" <> show (length observations)
    , "inductive-count\t" <> show (count isInductive)
    , "base-counterexample-count\t" <> show (count isBaseFailure)
    , "step-counterexample-count\t" <> show (count isStepFailure)
    , "unsupported-count\t" <> show (count isUnsupported)
    , "explicit-agreement-count\t" <> show agreements
    , "conservative-noninductive-count\t" <> show conservative
    , "shared-digest-count\t" <> show sharedDigests
    , "proof-obligation-total\t" <> show
        (sum (map (verdictObligationCount . observedSymbolic) observations))
    , "induction-witness-count\t" <> show (count isInductive)
    ]
 where
  isInductive (Inductive _) = True
  isInductive _ = False
  isBaseFailure (NotInductive InductionCounterexample {counterexampleObligation = BaseCase _}) = True
  isBaseFailure _ = False
  isStepFailure (NotInductive InductionCounterexample {counterexampleObligation = StepCase _ _ _}) = True
  isStepFailure _ = False
  isUnsupported (Unsupported _) = True
  isUnsupported _ = False

readOracle :: IO [Expected]
readOracle = pure oracleRows

oracleRows :: [Expected]
oracleRows =
  [ Expected "inductive-counter" 3 "inductive" "-" "-" "safe" "agree" 2
  , Expected "base-failure" 1 "base-failure" "NonNegative" "-" "unsafe-invariant" "agree" 1
  , Expected "step-failure" 3 "step-failure" "BelowTwo" "Advance" "unsafe-invariant" "agree" 2
  , Expected "safe-noninductive" 2 "step-failure" "NotOne" "PoisonUnreachable" "safe" "conservative" 3
  , Expected "coupled-invariants" 1 "inductive" "-" "-" "safe" "agree" 4
  , Expected "guarded-boolean" 1 "inductive" "-" "-" "safe" "agree" 2
  , Expected "unsupported-set" 1 "unsupported" "-" "-" "safe" "unsupported" 0
  ]

fixtureModels :: [(String, Model)]
fixtureModels =
  [ ("inductive-counter", counterModel "InductiveCounter" "AtMostTwo"
      (ArithmeticComparison LessThanOrEqual (Ref "x") (int 2)))
  , ("base-failure", baseModel
      { modelName = "BaseFailure"
      , modelVariables = ["x"]
      , modelInit = [("x", int (-1))]
      , modelInvariants = [NamedExpr "NonNegative"
          (ArithmeticComparison GreaterThanOrEqual (Ref "x") (int 0))]
      })
  , ("step-failure", counterModel "StepFailure" "BelowTwo"
      (ArithmeticComparison LessThan (Ref "x") (int 2)))
  , ("safe-noninductive", safeNonInductive)
  , ("coupled-invariants", coupledInvariants)
  , ("guarded-boolean", guardedBoolean)
  , ("unsupported-set", unsupportedSet)
  ]

lookupModel :: String -> Model
lookupModel name = case lookup name fixtureModels of
  Just model -> model
  Nothing -> error ("unknown symbolic fixture " <> name)

counterModel :: Name -> Name -> Expr -> Model
counterModel modelName invariantName invariant = baseModel
  { modelName = modelName
  , modelVariables = ["x"]
  , modelInit = [("x", int 0)]
  , modelActions =
      [ Action "Advance" [] (ArithmeticComparison LessThan (Ref "x") (int 2))
          [("x", Add (Ref "x") (int 1))]
      ]
  , modelInvariants = [NamedExpr invariantName invariant]
  }

safeNonInductive :: Model
safeNonInductive = baseModel
  { modelName = "SafeNonInductive"
  , modelVariables = ["x"]
  , modelInit = [("x", int 0)]
  , modelActions =
      [ Action "ReachTwo" [] (Equal (Ref "x") (int 0)) [("x", int 2)]
      , Action "PoisonUnreachable" [] (Equal (Ref "x") (int 3)) [("x", int 1)]
      ]
  , modelInvariants = [NamedExpr "NotOne" (NotEqual (Ref "x") (int 1))]
  }

coupledInvariants :: Model
coupledInvariants = baseModel
  { modelName = "CoupledInvariants"
  , modelVariables = ["x", "y"]
  , modelInit = [("x", int 0), ("y", int 0)]
  , modelActions = [Action "Accumulate" [] (Literal (BoolValue True))
      [("y", Add (Ref "y") (Ref "x"))]]
  , modelInvariants =
      [ NamedExpr "NonNegativeX" (ArithmeticComparison GreaterThanOrEqual (Ref "x") (int 0))
      , NamedExpr "NonNegativeY" (ArithmeticComparison GreaterThanOrEqual (Ref "y") (int 0))
      ]
  }

guardedBoolean :: Model
guardedBoolean = baseModel
  { modelName = "GuardedBoolean"
  , modelVariables = ["b"]
  , modelInit = [("b", Literal (BoolValue True))]
  , modelActions = [Action "FlipOnlyWhenFalse" [] (Not (Ref "b")) [("b", Not (Ref "b"))]]
  , modelInvariants = [NamedExpr "StaysTrue" (Equal (Ref "b") (Literal (BoolValue True)))]
  }

unsupportedSet :: Model
unsupportedSet = baseModel
  { modelName = "UnsupportedSet"
  , modelVariables = ["s"]
  , modelInit = [("s", Literal (SetValue [IntValue 1]))]
  , modelInvariants = [NamedExpr "ContainsOne" (FiniteSetMembership (int 1) (Ref "s"))]
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
failTest message = hPutStrLn stderr ("FAIL: " <> message) >> exitFailure
