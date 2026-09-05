{-# LANGUAGE CPP #-}

module Amoebius.Formal.Interpret
  ( interpret
  , initialState
  , enabledEvents
  , evalExpr
  , valueAsBool
  ) where

import Amoebius.Formal.Model
import Control.Monad (foldM, guard)
import Data.List (find)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map

type Bindings = Map Name Value

valueAsBool :: Value -> Either String Bool
valueAsBool (BoolValue value) = Right value
valueAsBool value = Left ("expected boolean, got " <> show value)

valueAsInt :: Value -> Either String Integer
valueAsInt (IntValue value) = Right value
valueAsInt value = Left ("expected integer, got " <> show value)

valueAsFinite :: Value -> Either String [Value]
valueAsFinite (SetValue values) = Right values
valueAsFinite value = Left ("expected finite set, got " <> show value)

lookupRef :: Model -> Bindings -> State -> Name -> Either String Value
lookupRef model bindings state name =
  maybe (Left ("unbound reference " <> name)) Right
    (Map.lookup name bindings <|> Map.lookup name state <|> lookup name (modelConstants model))
  where
    (<|>) (Just value) _ = Just value
    (<|>) Nothing other = other

evalExpr :: Model -> Bindings -> State -> Expr -> Either String Value
evalExpr model bindings state expression = case expression of
  Literal value -> Right value
  Ref name -> lookupRef model bindings state name
  Not expr -> BoolValue . not <$> (evalExpr model bindings state expr >>= valueAsBool)
  And exprs -> BoolValue . and <$> traverse (evalBool model bindings state) exprs
  Or exprs -> BoolValue . or <$> traverse (evalBool model bindings state) exprs
  Implies left right -> do
    leftValue <- eval left >>= valueAsBool
    rightValue <- eval right >>= valueAsBool
    pure (BoolValue (not leftValue || rightValue))
  Equal left right -> BoolValue <$> (valueEqual <$> eval left <*> eval right)
  NotEqual left right -> BoolValue . not <$> (valueEqual <$> eval left <*> eval right)
  ArithmeticComparison comparison left right -> do
    leftValue <- eval left >>= valueAsInt
    rightValue <- eval right >>= valueAsInt
    pure . BoolValue $ case comparison of
      LessThan -> leftValue < rightValue
      LessThanOrEqual -> leftValue <= rightValue
      GreaterThan -> leftValue > rightValue
      GreaterThanOrEqual -> leftValue >= rightValue
  Add left right -> IntValue <$> ((+) <$> (eval left >>= valueAsInt) <*> (eval right >>= valueAsInt))
  Subtract left right -> IntValue <$> ((-) <$> (eval left >>= valueAsInt) <*> (eval right >>= valueAsInt))
  FiniteSet exprs -> SetValue . unique <$> traverse eval exprs
  SetUnion left right -> do
    leftValues <- eval left >>= valueAsFinite
    rightValues <- eval right >>= valueAsFinite
    pure (SetValue (unique (leftValues <> rightValues)))
  SetDifference left right -> do
    leftValues <- eval left >>= valueAsFinite
    rightValues <- eval right >>= valueAsFinite
    pure (SetValue [value | value <- leftValues, not (any (valueEqual value) rightValues)])
  Cardinality expr -> IntValue . fromIntegral . length <$> (eval expr >>= valueAsFinite)
  FiniteSetMembership element domain -> do
    elementValue <- eval element
    domainValues <- eval domain >>= valueAsFinite
    pure (BoolValue (elementValue `elem` domainValues))
  FiniteQuantifier quantifier binder domain predicate -> do
    domainValues <- eval domain >>= valueAsFinite
    values <- traverse (\value -> evalBool model (Map.insert binder value bindings) state predicate) domainValues
    pure . BoolValue $ case quantifier of
      ForAll -> and values
      Exists -> or values
  FunctionLiteral binder domain body -> do
    domainValues <- eval domain >>= valueAsFinite
    pairs <- traverse (\value -> (value,) <$> evalExpr model (Map.insert binder value bindings) state body) domainValues
    pure (FunctionValue pairs)
  FunctionUpdate function key value -> do
    pairs <- eval function >>= valueAsFunction
    keyValue <- eval key
    valueValue <- eval value
    pure (FunctionValue (replace keyValue valueValue pairs))
  FunctionApplication function key -> do
    pairs <- eval function >>= valueAsFunction
    keyValue <- eval key
    maybe (Left ("function has no key " <> show keyValue)) Right (lookup keyValue pairs)
  IfThenElse condition whenTrue whenFalse -> do
    predicate <- eval condition >>= valueAsBool
    eval (if predicate then whenTrue else whenFalse)
  where
    eval = evalExpr model bindings state

evalBool :: Model -> Bindings -> State -> Expr -> Either String Bool
evalBool model bindings state expr = evalExpr model bindings state expr >>= valueAsBool

valueAsFunction :: Value -> Either String [(Value, Value)]
valueAsFunction (FunctionValue pairs) = Right pairs
valueAsFunction value = Left ("expected function, got " <> show value)

replace :: Value -> Value -> [(Value, Value)] -> [(Value, Value)]
replace key value pairs = (key, value) : filter ((/= key) . fst) pairs

unique :: [Value] -> [Value]
unique = foldr (\value values -> if any (valueEqual value) values then values else value : values) []

valueEqual :: Value -> Value -> Bool
valueEqual (SetValue left) (SetValue right) =
  length (unique left) == length (unique right)
    && all (\value -> any (valueEqual value) right) left
valueEqual (FunctionValue left) (FunctionValue right) =
  length left == length right
    && all (\(key, value) -> maybe False (valueEqual value) (lookup key right)) left
valueEqual left right = left == right

initialState :: Model -> Either String State
initialState model = do
  state <- foldM assign Map.empty (modelInit model)
  let missing = filter (`Map.notMember` state) (modelVariables model)
  if null missing
    then Right state
    else Left ("missing initial assignments: " <> show missing)
  where
    assign state (name, expr) = do
      value <- evalExpr model Map.empty state expr
      pure (Map.insert name value state)

interpret :: Model -> Event -> State -> Maybe State
interpret model event state = do
  action <- find ((== eventAction event) . actionName) (modelActions model)
  guard (length (actionParameters action) == length (eventArguments event))
  let bindings = Map.fromList (zip (map parameterName (actionParameters action)) (eventArguments event))
  domainsOk <- either (const Nothing) Just $ traverse (argumentInDomain bindings) (zip (actionParameters action) (eventArguments event))
  guard (and domainsOk)
  enabled <- either (const Nothing) Just (evalBool model bindings state (actionGuard action))
#ifdef FORMAL_MODEL_IGNORES_GUARD_MUTANT
  guard (enabled || not enabled)
#else
  guard enabled
#endif
  effects <- either (const Nothing) Just (traverse (evaluateEffect bindings) (actionEffects action))
  pure (foldr (uncurry Map.insert) state effects)
  where
    argumentInDomain bindings (parameter, argument) = do
      values <- evalExpr model bindings state (parameterDomain parameter) >>= valueAsFinite
      pure (argument `elem` values)
    evaluateEffect bindings (name, expr) = (name,) <$> evalExpr model bindings state expr

enabledEvents :: Model -> State -> [Event]
enabledEvents model state =
  [ event
  | action <- modelActions model
  , arguments <- parameterProducts model state (actionParameters action)
  , let event = Event (actionName action) arguments
  , Just _ <- [interpret model event state]
  ]

parameterProducts :: Model -> State -> [Parameter] -> [[Value]]
parameterProducts model state = go Map.empty
  where
    go _ [] = [[]]
    go bindings (parameter : rest) =
      case evalExpr model bindings state (parameterDomain parameter) >>= valueAsFinite of
        Left _ -> []
        Right values ->
          [ value : suffix
          | value <- values
          , suffix <- go (Map.insert (parameterName parameter) value bindings) rest
          ]
