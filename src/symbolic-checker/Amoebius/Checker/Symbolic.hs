{-# LANGUAGE CPP #-}

-- | Amoebius-owned inductive safety checking over the Phase-11 formal 'Model'.
--
-- The checker owns the translation and induction schema.  A resolved absolute Z3
-- path is injected by the caller; no executable is discovered through ambient PATH.
-- The supported proof fragment is quantifier-free linear integer arithmetic plus
-- booleans.  Every other Model constructor is classified explicitly as unsupported,
-- so totality does not turn a partial encoding into a proof.
module Amoebius.Checker.Symbolic
  ( Solver
  , mkSolver
  , UnsupportedFeature (..)
  , ObligationKind (..)
  , InductionWitness (..)
  , InductionCounterexample (..)
  , SymbolicResult (..)
  , SymbolicVerdict (..)
  , SymbolicError (..)
  , checkInductive
  , symbolicModelDigest
  ) where

import Amoebius.Formal.Interpret (evalExpr, initialState)
import Amoebius.Formal.Model
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as Char8
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Numeric (showHex)
import System.Directory (doesFileExist, executable, getPermissions)
import System.Exit (ExitCode (..))
import System.FilePath (isAbsolute)
import System.Process (readProcessWithExitCode)

newtype Solver = Solver FilePath
  deriving stock (Eq, Ord, Show)

data UnsupportedFeature
  = UnsupportedVariableSort Name Value
  | UnsupportedLiteral Value
  | UnsupportedExpression Expr
  | UnsupportedReference Name
  | UnsupportedParameterDomain Name String
  | UnsupportedStateConstraint Name
  | UnsupportedExpansionLimit
  | NoSafetyInvariants
  deriving stock (Eq, Ord, Show)

data ObligationKind
  = BaseCase Name
  | StepCase Name Name [Value]
  deriving stock (Eq, Ord, Show)

data InductionWitness = InductionWitness
  { witnessObligations :: [(ObligationKind, String)]
  }
  deriving stock (Eq, Ord, Show)

data InductionCounterexample = InductionCounterexample
  { counterexampleObligation :: ObligationKind
  , counterexampleQueryDigest :: String
  , counterexampleSolverModel :: String
  }
  deriving stock (Eq, Ord, Show)

data SymbolicResult
  = Inductive InductionWitness
  | NotInductive InductionCounterexample
  | Unsupported [UnsupportedFeature]
  | Inconclusive ObligationKind String
  deriving stock (Eq, Ord, Show)

data SymbolicVerdict = SymbolicVerdict
  { verdictModelDigest :: String
  , verdictInvariantCount :: Int
  , verdictObligationCount :: Int
  , verdictResult :: SymbolicResult
  }
  deriving stock (Eq, Ord, Show)

data SymbolicError
  = SolverPathNotAbsolute FilePath
  | SolverPathNotExecutable FilePath
  | MalformedModel [String]
  | InitialStateFailure String
  | SolverInvocationFailure ObligationKind String
  deriving stock (Eq, Ord, Show)

data Sort = BooleanSort | IntegerSort
  deriving stock (Eq, Ord, Show)

data Term = Term
  { termSort :: Sort
  , termText :: String
  }

data Obligation = Obligation
  { obligationKind :: ObligationKind
  , obligationQuery :: String
  }

data SolverStatus = SolverSat | SolverUnsat | SolverUnknown String

mkSolver :: FilePath -> IO (Either SymbolicError Solver)
mkSolver path
  | not (isAbsolute path) = pure (Left (SolverPathNotAbsolute path))
  | otherwise = do
      present <- doesFileExist path
      permissions <- if present then Just <$> getPermissions path else pure Nothing
      pure $ case permissions of
        Just mode | executable mode -> Right (Solver path)
        _ -> Left (SolverPathNotExecutable path)

checkInductive :: Solver -> Model -> IO (Either SymbolicError SymbolicVerdict)
checkInductive solver model = case modelProblems model of
  problems@(_ : _) -> pure (Left (MalformedModel problems))
  [] -> case prepareObligations model of
    Left (InitialProblem problem) -> pure (Left (InitialStateFailure problem))
    Left (UnsupportedProblems features) -> pure (Right (verdict 0 (Unsupported features)))
    Right obligations -> do
      result <- runObligations solver [] obligations
      pure (verdict (length obligations) <$> result)
 where
  verdict count result = SymbolicVerdict
    { verdictModelDigest = symbolicModelDigest model
    , verdictInvariantCount = length (modelInvariants model)
    , verdictObligationCount = count
    , verdictResult = result
    }

runObligations
  :: Solver
  -> [(ObligationKind, String)]
  -> [Obligation]
  -> IO (Either SymbolicError SymbolicResult)
runObligations _ passed [] = pure (Right (Inductive (InductionWitness (reverse passed))))
runObligations solver passed (obligation : rest) = do
  outcome <- runSolver solver obligation
  case outcome of
    Left problem -> pure (Left problem)
    Right (SolverUnknown reason, _) ->
      pure (Right (Inconclusive (obligationKind obligation) reason))
    Right (SolverUnsat, _) ->
      runObligations solver ((obligationKind obligation, digest query) : passed) rest
    Right (SolverSat, solverModel) ->
#ifdef SYMBOLIC_ACCEPTS_SAT_STEP_MUTANT
      case obligationKind obligation of
        StepCase _ _ _ ->
          runObligations solver ((obligationKind obligation, digest query) : passed) rest
        BaseCase _ -> pure (Right (counterexample solverModel))
#else
      pure (Right (counterexample solverModel))
#endif
 where
  query = obligationQuery obligation
  counterexample solverModel = NotInductive InductionCounterexample
    { counterexampleObligation = obligationKind obligation
    , counterexampleQueryDigest = digest query
    , counterexampleSolverModel = solverModel
    }

runSolver :: Solver -> Obligation -> IO (Either SymbolicError (SolverStatus, String))
runSolver (Solver path) obligation = do
  (exitCode, output, errors) <- readProcessWithExitCode path ["-in", "-smt2"] query
  case firstStatus (lines output) of
    Just SolverSat -> do
      (_, modelOutput, modelErrors) <-
        readProcessWithExitCode path ["-in", "-smt2"] (query <> "\n(get-model)\n")
      pure (Right (SolverSat, modelOutput <> modelErrors))
    Just status -> pure (Right (status, output <> errors))
    Nothing -> pure (Left (SolverInvocationFailure (obligationKind obligation)
      (renderExit exitCode <> ": " <> output <> errors)))
 where
  query = obligationQuery obligation
  renderExit ExitSuccess = "solver emitted no status"
  renderExit (ExitFailure code) = "solver exit " <> show code

firstStatus :: [String] -> Maybe SolverStatus
firstStatus [] = Nothing
firstStatus (line : rest) = case words line of
  "sat" : _ -> Just SolverSat
  "unsat" : _ -> Just SolverUnsat
  "unknown" : reason -> Just (SolverUnknown (unwords reason))
  _ -> firstStatus rest

data PreparationProblem
  = InitialProblem String
  | UnsupportedProblems [UnsupportedFeature]

prepareObligations :: Model -> Either PreparationProblem [Obligation]
prepareObligations model
  | null (modelInvariants model) = Left (UnsupportedProblems [NoSafetyInvariants])
  | Just constraint <- modelConstraint model =
      Left (UnsupportedProblems [UnsupportedStateConstraint (namedExprName constraint)])
  | Just _ <- modelExpansionLimit model = Left (UnsupportedProblems [UnsupportedExpansionLimit])
  | otherwise = do
      initial <- either (Left . InitialProblem) Right (initialState model)
      sorts <- mapUnsupported (variableSorts model initial)
      let current = variableTerms "v" model sorts
          next = variableTerms "v_next" model sorts
          declarations = variableDeclarations model sorts
      currentInvariants <- mapUnsupported
        (traverse (translateNamed model current Map.empty) (modelInvariants model))
      nextInvariants <- mapUnsupported
        (traverse (translateNamed model next Map.empty) (modelInvariants model))
      initialAssertions <- mapUnsupported (initialTerms model sorts current initial)
      bases <- mapUnsupported
        (traverse (baseObligation declarations initialAssertions) currentInvariants)
      steps <- mapUnsupported
        (stepObligations model declarations current next currentInvariants nextInvariants sorts)
      pure (bases <> steps)

mapUnsupported :: Either UnsupportedFeature value -> Either PreparationProblem value
mapUnsupported = either (Left . UnsupportedProblems . pure) Right

variableSorts :: Model -> State -> Either UnsupportedFeature (Map Name Sort)
variableSorts model initial = Map.fromList <$> traverse one (modelVariables model)
 where
  one name = case Map.lookup name initial of
    Nothing -> Left (UnsupportedReference name)
    Just value -> (name,) <$> valueSort name value

valueSort :: Name -> Value -> Either UnsupportedFeature Sort
valueSort _ (BoolValue _) = Right BooleanSort
valueSort _ (IntValue _) = Right IntegerSort
valueSort name value = Left (UnsupportedVariableSort name value)

variableTerms :: String -> Model -> Map Name Sort -> Map Name Term
variableTerms prefix model sorts = Map.fromList
  [ (name, Term sort (prefix <> show index))
  | (index, name) <- zip [(0 :: Int) ..] (modelVariables model)
  , Just sort <- [Map.lookup name sorts]
  ]

variableDeclarations :: Model -> Map Name Sort -> [String]
variableDeclarations model sorts = concat
  [ [declare ("v" <> show index) sort, declare ("v_next" <> show index) sort]
  | (index, name) <- zip [(0 :: Int) ..] (modelVariables model)
  , Just sort <- [Map.lookup name sorts]
  ]
 where
  declare name sort = "(declare-const " <> name <> " " <> renderSort sort <> ")"

renderSort :: Sort -> String
renderSort BooleanSort = "Bool"
renderSort IntegerSort = "Int"

initialTerms
  :: Model
  -> Map Name Sort
  -> Map Name Term
  -> State
  -> Either UnsupportedFeature [String]
initialTerms model sorts current initial = traverse one (modelVariables model)
 where
  one name = case (Map.lookup name sorts, Map.lookup name current, Map.lookup name initial) of
    (Just sort, Just variable, Just value) -> do
      literal <- valueTerm value
      requireSameSort sort literal (UnsupportedLiteral value)
      pure (equals variable literal)
    _ -> Left (UnsupportedReference name)

translateNamed
  :: Model
  -> Map Name Term
  -> Map Name Value
  -> NamedExpr
  -> Either UnsupportedFeature (Name, Term)
translateNamed model variables parameters named = do
  term <- translate model variables parameters (namedExprBody named)
  requireSameSort BooleanSort term (UnsupportedExpression (namedExprBody named))
  pure (namedExprName named, term)

baseObligation
  :: [String]
  -> [String]
  -> (Name, Term)
  -> Either UnsupportedFeature Obligation
baseObligation declarations initialAssertions (name, invariantTerm) = Right Obligation
  { obligationKind = BaseCase name
  , obligationQuery = renderQuery declarations
      (initialAssertions <> ["(not " <> termText invariantTerm <> ")"])
  }

stepObligations
  :: Model
  -> [String]
  -> Map Name Term
  -> Map Name Term
  -> [(Name, Term)]
  -> [(Name, Term)]
  -> Map Name Sort
  -> Either UnsupportedFeature [Obligation]
stepObligations model declarations current next currentInvariants nextInvariants sorts =
  concat <$> traverse forInvariant (zip currentInvariants nextInvariants)
 where
  forInvariant ((targetName, _), (nextName, targetNext))
    | targetName /= nextName = Left (UnsupportedReference targetName)
    | otherwise = concat <$> traverse (forAction targetName targetNext) (modelActions model)

  forAction targetName targetNext action = do
    bindings <- enumerateParameters model action
    traverse (forArguments targetName targetNext action) bindings

  forArguments targetName targetNext action parameters = do
    guardTerm <- translate model current parameters (actionGuard action)
    requireSameSort BooleanSort guardTerm (UnsupportedExpression (actionGuard action))
    transitions <- transitionTerms model sorts current next parameters action
    let hypotheses =
#ifdef SYMBOLIC_DROPS_CONJOINED_HYPOTHESIS_MUTANT
          [termText term | (name, term) <- currentInvariants, name == targetName]
#else
          [termText term | (_, term) <- currentInvariants]
#endif
        encodedGuard =
#ifdef SYMBOLIC_NEGATES_ACTION_GUARD_MUTANT
          "(not " <> termText guardTerm <> ")"
#else
          termText guardTerm
#endif
        arguments = [value | parameter <- actionParameters action
                           , Just value <- [Map.lookup (parameterName parameter) parameters]]
    pure Obligation
      { obligationKind = StepCase targetName (actionName action) arguments
      , obligationQuery = renderQuery declarations
          (hypotheses <> [encodedGuard] <> transitions <> ["(not " <> termText targetNext <> ")"])
      }

enumerateParameters :: Model -> Action -> Either UnsupportedFeature [Map Name Value]
enumerateParameters model action = go Map.empty (actionParameters action)
 where
  go bindings [] = Right [bindings]
  go bindings (parameter : rest) =
    case evalExpr model bindings Map.empty (parameterDomain parameter) of
      Right (SetValue values) -> concat <$> traverse
        (\value -> go (Map.insert (parameterName parameter) value bindings) rest) values
      Right value -> Left (UnsupportedParameterDomain (parameterName parameter)
        ("expected finite set, got " <> show value))
      Left problem -> Left (UnsupportedParameterDomain (parameterName parameter) problem)

transitionTerms
  :: Model
  -> Map Name Sort
  -> Map Name Term
  -> Map Name Term
  -> Map Name Value
  -> Action
  -> Either UnsupportedFeature [String]
transitionTerms model sorts current next parameters action = traverse one (modelVariables model)
 where
  effects = Map.fromList (actionEffects action)
  one name = case (Map.lookup name sorts, Map.lookup name current, Map.lookup name next) of
    (Just sort, Just old, Just new) -> do
      value <- case Map.lookup name effects of
        Nothing -> Right old
        Just expression -> translate model current parameters expression
      requireSameSort sort value (maybe (UnsupportedReference name) UnsupportedExpression
        (Map.lookup name effects))
      pure (equals new value)
    _ -> Left (UnsupportedReference name)

translate
  :: Model
  -> Map Name Term
  -> Map Name Value
  -> Expr
  -> Either UnsupportedFeature Term
translate model variables parameters expression = case expression of
  Literal value -> valueTerm value
  Ref name -> case Map.lookup name variables of
    Just term -> Right term
    Nothing -> case Map.lookup name parameters <|> lookup name (modelConstants model) of
      Just value -> valueTerm value
      Nothing -> Left (UnsupportedReference name)
  Not value -> unaryBoolean "not" value
  And values -> manyBoolean "and" "true" values
  Or values -> manyBoolean "or" "false" values
  Implies left right -> binaryBoolean "=>" left right
  Equal left right -> equality "=" left right
  NotEqual left right -> equality "distinct" left right
  ArithmeticComparison comparison left right -> comparisonTerm comparison left right
  Add left right -> binaryInteger "+" left right
  Subtract left right -> binaryInteger "-" left right
  IfThenElse condition whenTrue whenFalse -> do
    conditionTerm <- translateHere condition
    trueTerm <- translateHere whenTrue
    falseTerm <- translateHere whenFalse
    requireSameSort BooleanSort conditionTerm (UnsupportedExpression condition)
    requireSameSort (termSort trueTerm) falseTerm (UnsupportedExpression expression)
    pure (Term (termSort trueTerm)
      ("(ite " <> termText conditionTerm <> " " <> termText trueTerm <> " " <> termText falseTerm <> ")"))
  FiniteSet _ -> Left (UnsupportedExpression expression)
  SetUnion _ _ -> Left (UnsupportedExpression expression)
  SetDifference _ _ -> Left (UnsupportedExpression expression)
  Cardinality _ -> Left (UnsupportedExpression expression)
  FiniteSetMembership _ _ -> Left (UnsupportedExpression expression)
  FiniteQuantifier _ _ _ _ -> Left (UnsupportedExpression expression)
  FunctionLiteral _ _ _ -> Left (UnsupportedExpression expression)
  FunctionUpdate _ _ _ -> Left (UnsupportedExpression expression)
  FunctionApplication _ _ -> Left (UnsupportedExpression expression)
 where
  translateHere = translate model variables parameters
  unaryBoolean operator value = do
    term <- translateHere value
    requireSameSort BooleanSort term (UnsupportedExpression value)
    pure (Term BooleanSort ("(" <> operator <> " " <> termText term <> ")"))
  manyBoolean operator identity values = do
    terms <- traverse translateHere values
    traverseBoolean values terms
    pure (Term BooleanSort (case terms of
      [] -> identity
      _ -> "(" <> operator <> " " <> unwords (map termText terms) <> ")"))
  binaryBoolean operator left right = do
    leftTerm <- translateHere left
    rightTerm <- translateHere right
    requireSameSort BooleanSort leftTerm (UnsupportedExpression left)
    requireSameSort BooleanSort rightTerm (UnsupportedExpression right)
    pure (Term BooleanSort
      ("(" <> operator <> " " <> termText leftTerm <> " " <> termText rightTerm <> ")"))
  equality operator left right = do
    leftTerm <- translateHere left
    rightTerm <- translateHere right
    requireSameSort (termSort leftTerm) rightTerm (UnsupportedExpression expression)
    pure (Term BooleanSort
      ("(" <> operator <> " " <> termText leftTerm <> " " <> termText rightTerm <> ")"))
  binaryInteger operator left right = do
    leftTerm <- translateHere left
    rightTerm <- translateHere right
    requireSameSort IntegerSort leftTerm (UnsupportedExpression left)
    requireSameSort IntegerSort rightTerm (UnsupportedExpression right)
    pure (Term IntegerSort
      ("(" <> operator <> " " <> termText leftTerm <> " " <> termText rightTerm <> ")"))
  comparisonTerm comparison left right = do
    leftTerm <- translateHere left
    rightTerm <- translateHere right
    requireSameSort IntegerSort leftTerm (UnsupportedExpression left)
    requireSameSort IntegerSort rightTerm (UnsupportedExpression right)
    pure (Term BooleanSort
      ("(" <> comparisonOperator comparison <> " " <> termText leftTerm <> " " <> termText rightTerm <> ")"))

traverseBoolean :: [Expr] -> [Term] -> Either UnsupportedFeature ()
traverseBoolean [] [] = Right ()
traverseBoolean (expression : expressions) (term : terms) = do
  requireSameSort BooleanSort term (UnsupportedExpression expression)
  traverseBoolean expressions terms
traverseBoolean expressions _ = Left (UnsupportedExpression (And expressions))

comparisonOperator :: Comparison -> String
comparisonOperator LessThan = "<"
comparisonOperator LessThanOrEqual = "<="
comparisonOperator GreaterThan = ">"
comparisonOperator GreaterThanOrEqual = ">="

valueTerm :: Value -> Either UnsupportedFeature Term
valueTerm (BoolValue True) = Right (Term BooleanSort "true")
valueTerm (BoolValue False) = Right (Term BooleanSort "false")
valueTerm (IntValue value) = Right (Term IntegerSort (renderInteger value))
valueTerm value = Left (UnsupportedLiteral value)

renderInteger :: Integer -> String
renderInteger value
  | value < 0 = "(- " <> show (abs value) <> ")"
  | otherwise = show value

requireSameSort :: Sort -> Term -> UnsupportedFeature -> Either UnsupportedFeature ()
requireSameSort expected actual problem
  | expected == termSort actual = Right ()
  | otherwise = Left problem

equals :: Term -> Term -> String
equals left right = "(= " <> termText left <> " " <> termText right <> ")"

renderQuery :: [String] -> [String] -> String
renderQuery declarations assertions = unlines
  ([ "(set-option :produce-models true)"
   , "(set-option :timeout 10000)"
   , "(set-logic QF_LIA)"
   ] <> declarations <> map renderAssertion assertions <> ["(check-sat)"])
 where
  renderAssertion value = "(assert " <> value <> ")"

(<|>) :: Maybe value -> Maybe value -> Maybe value
(<|>) (Just value) _ = Just value
(<|>) Nothing other = other

symbolicModelDigest :: Model -> String
symbolicModelDigest = digest . show

digest :: String -> String
digest = concatMap twoHex . ByteString.unpack . SHA256.hash . Char8.pack
 where
  twoHex byte = case showHex byte "" of
    [digit] -> ['0', digit]
    digits -> digits
