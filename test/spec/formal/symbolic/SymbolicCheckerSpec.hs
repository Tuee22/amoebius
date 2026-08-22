module Main (main) where

import Amoebius.Checker.ExplicitState qualified as Explicit
import Amoebius.Checker.Symbolic
import Amoebius.Formal.Model
import Control.Monad (forM, forM_, unless)
import Data.Char (isHexDigit)
import Data.List (isInfixOf)
import System.Directory (createDirectoryIfMissing)
import System.Environment (lookupEnv)
import System.Exit (exitFailure)
import System.FilePath ((</>))

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
  solverPath <- lookupEnv "AMOEBIUS_Z3" >>= maybe
    (failTest "AMOEBIUS_Z3 was not injected" >> pure "") pure
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
  writeResults observations agreementCount conservativeCount sharedDigests
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

writeResults :: [Observation] -> Int -> Int -> Int -> IO ()
writeResults observations agreements conservative sharedDigests = do
  let output = ".build" </> "checkers" </> "symbolic"
      results = map (verdictResult . observedSymbolic) observations
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
readOracle = do
  rows <- lines <$> readFile "test/oracle/symbolic_checker/models.tsv"
  case rows of
    [] -> failTest "symbolic oracle is empty" >> pure []
    header : body -> do
      assertEqual "oracle header"
        "model\tbound\tsymbolic_status\tfailing_invariant\tfailing_action\texplicit_status\trelation\tobligations"
        header
      mapM parseRow body

parseRow :: String -> IO Expected
parseRow row = case splitOn '\t' row of
  [name, boundText, symbolic, invariant, action, explicit, relation, obligationText] ->
    Expected name <$> parseInt boundText <*> pure symbolic <*> pure invariant <*> pure action
      <*> pure explicit <*> pure relation <*> parseInt obligationText
  fields -> failTest ("malformed oracle row: " <> show fields)
    >> pure (Expected "" 0 "" "" "" "" "" 0)
 where
  parseInt text = case reads text of
    [(value, "")] -> pure value
    _ -> failTest ("invalid oracle integer " <> text) >> pure 0

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
failTest message = putStrLn ("FAIL: " <> message) >> exitFailure

splitOn :: Char -> String -> [String]
splitOn delimiter text = case break (== delimiter) text of
  (piece, []) -> [piece]
  (piece, _ : rest) -> piece : splitOn delimiter rest
