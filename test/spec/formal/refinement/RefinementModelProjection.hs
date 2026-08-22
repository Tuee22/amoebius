module Main (main) where

import Amoebius.Formal.Explore (ExploreResult (..), explore)
import Amoebius.Formal.Model
import qualified Data.Map.Strict as Map
import System.Directory (createDirectoryIfMissing)
import System.Environment (getArgs)
import System.Exit (die)
import System.FilePath (takeDirectory)

main :: IO ()
main = do
  output <- requireOutput =<< getArgs
  rows <- traverse checkedInvariant [counterModel, pairModel]
  createDirectoryIfMissing True (takeDirectory output)
  writeFile output (unlines ("model\tinvariant\tpost" : map fst rows))
  putStrLn
    ( "refinement-model-projection: PASS (2 models, "
        <> show (sum (map snd rows))
        <> " reachable states, 2 invariants)"
    )

requireOutput :: [String] -> IO FilePath
requireOutput [output] = pure output
requireOutput _ = die "usage: refinement-model-projection OUTPUT.tsv"

checkedInvariant :: Model -> IO (String, Int)
checkedInvariant model = do
  case modelProblems model of
    [] -> pure ()
    problems -> die (modelName model <> " is malformed: " <> show problems)
  explored <- either (die . ((modelName model <> " explorer failed: ") <>)) pure (explore model)
  case exploreViolation explored of
    Just violation -> die (modelName model <> " violates its invariant: " <> show violation)
    Nothing -> pure ()
  named <- case modelInvariants model of
    [onlyInvariant] -> pure onlyInvariant
    rows -> die (modelName model <> " must expose one invariant, got " <> show (length rows))
  predicate <- either die pure (renderRefinementExpr (namedExprBody named))
  pure
    ( modelName model <> "\t" <> namedExprName named <> "\t" <> predicate
    , Map.size (exploreStates explored)
    )

renderRefinementExpr :: Expr -> Either String String
renderRefinementExpr expression = case expression of
  Literal (IntValue value) -> Right (show value)
  Literal (BoolValue True) -> Right "true"
  Literal (BoolValue False) -> Right "false"
  Ref name -> Right name
  Not value -> unary "not " value
  And values -> variadic " && " values
  Or values -> variadic " || " values
  Equal left right -> binary " == " left right
  NotEqual left right -> binary " /= " left right
  ArithmeticComparison comparison left right -> binary (comparisonOperator comparison) left right
  Add left right -> binary " + " left right
  Subtract left right -> binary " - " left right
  IfThenElse condition whenTrue whenFalse -> do
    renderedCondition <- renderRefinementExpr condition
    renderedTrue <- renderRefinementExpr whenTrue
    renderedFalse <- renderRefinementExpr whenFalse
    pure ("if " <> renderedCondition <> " then " <> renderedTrue <> " else " <> renderedFalse)
  unsupported -> Left ("model invariant is outside the refinement fragment: " <> show unsupported)
  where
    unary operator value = (operator <>) <$> renderRefinementExpr value
    binary operator left right = do
      renderedLeft <- renderRefinementExpr left
      renderedRight <- renderRefinementExpr right
      pure ("(" <> renderedLeft <> operator <> renderedRight <> ")")
    variadic _ [] = Left "empty boolean connective is outside the refinement fragment"
    variadic operator values = do
      rendered <- traverse renderRefinementExpr values
      pure ("(" <> foldr1 (\left right -> left <> operator <> right) rendered <> ")")

comparisonOperator :: Comparison -> String
comparisonOperator comparison = case comparison of
  LessThan -> " < "
  LessThanOrEqual -> " <= "
  GreaterThan -> " > "
  GreaterThanOrEqual -> " >= "

counterModel :: Model
counterModel =
  baseModel
    { modelName = "Counter"
    , modelActions =
        [ Action "Increment" [] trueExpr [("result", Add resultExpr one)]
        , Action "Decrement" [] (ArithmeticComparison GreaterThan resultExpr zero)
            [("result", Subtract resultExpr one)]
        ]
    , modelInvariants = [NamedExpr "NonNegative" nonNegative]
    }

pairModel :: Model
pairModel =
  baseModel
    { modelName = "Pair"
    , modelActions = [Action "AddPair" [] trueExpr [("result", Add resultExpr two)]]
    , modelInvariants = [NamedExpr "NonNegativeSum" nonNegative]
    }

baseModel :: Model
baseModel = Model
  { modelName = "Base"
  , modelConstants = []
  , modelVariables = ["result"]
  , modelInit = [("result", zero)]
  , modelActions = []
  , modelInvariants = []
  , modelConstraint = Nothing
  , modelExpansionLimit = Just (ArithmeticComparison LessThanOrEqual resultExpr three)
  , modelFairness = []
  , modelProperties = []
  , modelCheckDeadlock = False
  }

resultExpr, zero, one, two, three, trueExpr, nonNegative :: Expr
resultExpr = Ref "result"
zero = Literal (IntValue 0)
one = Literal (IntValue 1)
two = Literal (IntValue 2)
three = Literal (IntValue 3)
trueExpr = Literal (BoolValue True)
nonNegative = ArithmeticComparison GreaterThanOrEqual resultExpr zero
