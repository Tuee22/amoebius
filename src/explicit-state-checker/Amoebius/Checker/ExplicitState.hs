{-# LANGUAGE CPP #-}

-- | Amoebius-owned bounded explicit-state checking over the formal 'Model'.
--
-- This implementation deliberately does not import 'Amoebius.Formal.Explore'.  Both
-- algorithms consume the Phase-12 interpreter semantics, while frontier management,
-- bound handling, violation selection, trace construction, and verdict formation are
-- independently implemented here and checked for parity by Phase 13.
module Amoebius.Checker.ExplicitState
  ( SearchBound
  , mkSearchBound
  , searchBoundValue
  , ViolationKind (..)
  , TraceStep (..)
  , Counterexample (..)
  , CheckResult (..)
  , Verdict (..)
  , CheckerError (..)
  , checkModel
  , replayCounterexample
  , modelDigest
  ) where

import Amoebius.Formal.Interpret
  ( enabledEvents
  , evalExpr
  , initialState
  , interpret
  , valueAsBool
  )
import Amoebius.Formal.Model
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as Char8
import Data.List (intercalate, sortOn)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Numeric (showHex)

newtype SearchBound = SearchBound Int
  deriving stock (Eq, Ord, Show)

mkSearchBound :: Int -> Either CheckerError SearchBound
mkSearchBound value
  | value > 0 = Right (SearchBound value)
  | otherwise = Left (InvalidSearchBound value)

searchBoundValue :: SearchBound -> Int
searchBoundValue (SearchBound value) = value

data ViolationKind
  = InvariantViolation Name
  | DeadlockViolation
  deriving stock (Eq, Ord, Show)

data TraceStep = TraceStep
  { traceFrom :: String
  , traceEvent :: Event
  , traceTo :: String
  }
  deriving stock (Eq, Ord, Show)

data Counterexample = Counterexample
  { counterexampleViolation :: ViolationKind
  , counterexampleState :: String
  , counterexampleTrace :: [TraceStep]
  }
  deriving stock (Eq, Ord, Show)

data CheckResult
  = Safe
  | Unsafe Counterexample
  | BoundExceeded Int
  deriving stock (Eq, Ord, Show)

data Verdict = Verdict
  { verdictModelDigest :: String
  , verdictBound :: Int
  , verdictDistinctStates :: Int
  , verdictResult :: CheckResult
  }
  deriving stock (Eq, Ord, Show)

data CheckerError
  = InvalidSearchBound Int
  | MalformedModel [String]
  | EvaluationFailure String
  | TraceReplayFailure String
  deriving stock (Eq, Ord, Show)

data Node = Node
  { nodeState :: State
  , nodeTrace :: [TraceStep]
  }

checkModel :: SearchBound -> Model -> Either CheckerError Verdict
checkModel bound authoredModel = case modelProblems authoredModel of
  problems@(_ : _) -> Left (MalformedModel problems)
  [] -> do
    initial <- liftEvaluation (initialState semanticModel)
    initialAllowed <- satisfiesConstraint semanticModel initial
    if initialAllowed
      then walk Set.empty [Node initial []]
      else pure (verdict 0 Safe)
 where
  semanticModel = checkerSemantics authoredModel
  maximumStates = searchBoundValue bound
  verdict count result = Verdict
    { verdictModelDigest = modelDigest authoredModel
    , verdictBound = maximumStates
    , verdictDistinctStates = count
    , verdictResult = result
    }

  walk :: Set String -> [Node] -> Either CheckerError Verdict
  walk seen [] = pure (verdict (Set.size seen) Safe)
  walk seen (node : remaining) =
    let fingerprint = stateFingerprint semanticModel (nodeState node)
     in if Set.member fingerprint seen
          then walk seen remaining
          else if Set.size seen >= maximumStates
            then pure (verdict (Set.size seen) (BoundExceeded (Set.size seen + 1)))
            else do
              violation <- firstViolation semanticModel (nodeState node)
              let seen' = Set.insert fingerprint seen
              case violation of
                Just kind -> pure (verdict (Set.size seen') (Unsafe
                  (Counterexample kind fingerprint (nodeTrace node))))
                Nothing -> do
                  expandable <- satisfiesExpansionLimit semanticModel (nodeState node)
                  let events = if expandable then enabledEvents semanticModel (nodeState node) else []
                  candidates <- traverse (successorNode semanticModel node) events
                  let successors = [successor | Just successor <- candidates]
                  if modelCheckDeadlock semanticModel && null successors
                    then pure (verdict (Set.size seen') (Unsafe
                      (Counterexample DeadlockViolation fingerprint (nodeTrace node))))
                    else walk seen' (enqueue remaining successors)

successorNode :: Model -> Node -> Event -> Either CheckerError (Maybe Node)
successorNode model node event = case interpret model event (nodeState node) of
  Nothing -> Left (EvaluationFailure ("enabled event became disabled: " <> show event))
  Just successor -> do
    allowed <- satisfiesConstraint model successor
    let fromFingerprint = stateFingerprint model (nodeState node)
        toFingerprint = stateFingerprint model successor
        step = TraceStep fromFingerprint event toFingerprint
    pure (if allowed then Just (Node successor (nodeTrace node <> [step])) else Nothing)

enqueue :: [Node] -> [Node] -> [Node]
#ifdef EXPLICIT_STATE_TRUNCATES_FRONTIER_MUTANT
enqueue queue successors = queue <> take 1 successors
#else
enqueue queue successors = queue <> successors
#endif

checkerSemantics :: Model -> Model
#ifdef EXPLICIT_STATE_WIDENS_ACTION_GUARD_MUTANT
checkerSemantics model = model
  { modelActions =
      [ action {actionGuard = Literal (BoolValue True)}
      | action <- modelActions model
      ]
  }
#else
checkerSemantics = id
#endif

firstViolation :: Model -> State -> Either CheckerError (Maybe ViolationKind)
#ifdef EXPLICIT_STATE_SKIPS_INVARIANT_MUTANT
firstViolation _model _state = Right Nothing
#else
firstViolation model state = go (modelInvariants model)
 where
  go [] = Right Nothing
  go (named : rest) = do
    valid <- liftEvaluation
      (evalExpr model Map.empty state (namedExprBody named) >>= valueAsBool)
    if valid then go rest else Right (Just (InvariantViolation (namedExprName named)))
#endif

satisfiesConstraint :: Model -> State -> Either CheckerError Bool
satisfiesConstraint model state = case modelConstraint model of
  Nothing -> Right True
  Just named -> liftEvaluation
    (evalExpr model Map.empty state (namedExprBody named) >>= valueAsBool)

satisfiesExpansionLimit :: Model -> State -> Either CheckerError Bool
satisfiesExpansionLimit model state = case modelExpansionLimit model of
  Nothing -> Right True
  Just expression -> liftEvaluation
    (evalExpr model Map.empty state expression >>= valueAsBool)

liftEvaluation :: Either String value -> Either CheckerError value
liftEvaluation = either (Left . EvaluationFailure) Right

-- | Replay a reported trace through the same model decision function.  The fingerprints
-- on both sides of each step prevent a valid event sequence being attached to the wrong
-- starting state or to a forged terminal state.
replayCounterexample :: Model -> Counterexample -> Either CheckerError State
replayCounterexample model counterexample = do
  initial <- liftEvaluation (initialState model)
  terminal <- foldl replay (Right initial) (counterexampleTrace counterexample)
  let actual = stateFingerprint model terminal
  if actual == counterexampleState counterexample
    then Right terminal
    else Left (TraceReplayFailure
      ("terminal fingerprint " <> actual <> " /= " <> counterexampleState counterexample))
 where
  replay stateResult step = do
    state <- stateResult
    let actualFrom = stateFingerprint model state
    if actualFrom /= traceFrom step
      then Left (TraceReplayFailure
        ("step starts at " <> traceFrom step <> " but replay is at " <> actualFrom))
      else case interpret model (traceEvent step) state of
        Nothing -> Left (TraceReplayFailure ("disabled replay event: " <> show (traceEvent step)))
        Just successor ->
          let actualTo = stateFingerprint model successor
           in if actualTo == traceTo step
                then Right successor
                else Left (TraceReplayFailure
                  ("step ends at " <> traceTo step <> " but replay reached " <> actualTo))

-- | Checker-local identity of the complete reified model.  This binds a verdict to the
-- exact constructor tree it checked; it is not an artifact address or a protocol proof.
modelDigest :: Model -> String
modelDigest = concatMap twoHex . ByteString.unpack . SHA256.hash . Char8.pack . show
 where
  twoHex byte = case showHex byte "" of
    [digit] -> ['0', digit]
    digits -> digits

stateFingerprint :: Model -> State -> String
stateFingerprint model state = intercalate "|"
  [ name <> "=" <> maybe "<missing>" renderValue (Map.lookup name state)
  | name <- modelVariables model
  ]

renderValue :: Value -> String
renderValue value = case value of
  BoolValue True -> "TRUE"
  BoolValue False -> "FALSE"
  IntValue integer -> show integer
  AtomValue atom -> show atom
  SetValue values -> "{" <> intercalate "," (map renderValue (sortOn renderValue values)) <> "}"
  FunctionValue pairs -> "[" <> intercalate "," rendered <> "]"
   where
    rendered =
      [ renderValue key <> "|->" <> renderValue result
      | (key, result) <- sortOn (renderValue . fst) pairs
      ]
