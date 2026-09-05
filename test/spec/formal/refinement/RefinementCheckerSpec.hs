module Main (main) where

import Amoebius.Checker.Refinement
import Control.Monad (forM, unless)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import System.Directory (createDirectoryIfMissing)
import System.Environment (getArgs)
import System.Exit (die)
import System.FilePath ((</>))

data Expected = Expected
  { expectedPath :: FilePath
  , expectedModel :: String
  , expectedInvariant :: String
  , expectedFunction :: String
  , expectedStatus :: RefinementStatus
  , expectedReason :: String
  , expectedRequired :: Bool
  , expectedLine :: Int
  , expectedDigest :: String
  }

main :: IO ()
main = do
  (solverPath, outputRoot) <- requireArguments =<< getArgs
  solver <- either (die . show) pure =<< mkRefinementSolver solverPath
  relativeRefusal <- mkRefinementSolver "relative-solver"
  assertEqual "relative solver refusal" (Left (SolverPathNotAbsolute "relative-solver")) relativeRefusal
  invariants <- invariantRegistry
  checkNegative solver invariants "unbound expression negative" "missing >= 0"
  checkNegative solver invariants "ill-sorted expression negative" "x && true"
  observations <- forM expectations (checkOne solver invariants)
  let requiredPairs = Map.fromList [((expectedModel row, expectedInvariant row), ()) | row <- expectations, expectedRequired row]
      coveredPairs = Map.fromList
        [ ((expectedModel row, expectedInvariant row), ())
        | (row, result) <- zip expectations observations
        , expectedRequired row
        , refinementResultStatus result == Proved
        ]
  assertEqual "required invariant registry" (Map.keys requiredPairs) (Map.keys invariants)
  assertEqual "covered required invariant registry" (Map.keys requiredPairs) (Map.keys coveredPairs)
  createDirectoryIfMissing True outputRoot
  writeFile (outputRoot </> "results.tsv") (renderResults observations (Map.size invariants) (Map.size coveredPairs))
  putStrLn "refinement-checker-spec: PASS (6 functions, 2 invariant correspondences, 3 specific negatives)"

requireArguments :: [String] -> IO (FilePath, FilePath)
requireArguments [solver, outputRoot] = pure (solver, outputRoot)
requireArguments _ = die "usage: refinement-checker-spec SOLVER OUTPUT_ROOT"

invariantRegistry :: IO (Map (String, String) RefinementExpr)
invariantRegistry = do
  nonNegative <- either (die . show) pure (parseRefinementExpr "result >= 0")
  pure (Map.fromList [("Counter", "NonNegative") `with` nonNegative, ("Pair", "NonNegativeSum") `with` nonNegative])
 where
  with key value = (key, value)

checkOne :: RefinementSolver -> Map (String, String) RefinementExpr -> Expected -> IO RefinementResult
checkOne solver invariants expected = do
  sourceText <- readFile (expectedPath expected)
  source <- either (die . show) pure (parseRefinementSource (expectedPath expected) sourceText)
  assertEqual (expectedFunction expected <> " model") (expectedModel expected) (refinementModel source)
  assertEqual (expectedFunction expected <> " invariant") (expectedInvariant expected) (refinementInvariant source)
  assertEqual (expectedFunction expected <> " function") (expectedFunction expected) (refinementFunction source)
  result <- either (die . show) pure =<< checkRefinement solver invariants source
  assertEqual (expectedFunction expected <> " status") (expectedStatus expected) (refinementResultStatus result)
  assertEqual (expectedFunction expected <> " reason") (expectedReason expected) (refinementResultReason result)
  assertEqual (expectedFunction expected <> " line") (expectedLine expected) (refinementResultLine result)
  assertEqual (expectedFunction expected <> " digest") (expectedDigest expected) (refinementResultSourceDigest result)
  let needsModel = expectedStatus expected `elem` [PostconditionCounterexample, CorrespondenceMismatch]
  assertEqual (expectedFunction expected <> " counterexample model presence") needsModel (not (null (refinementResultSolverModel result)))
  pure result

checkNegative :: RefinementSolver -> Map (String, String) RefinementExpr -> String -> String -> IO ()
checkNegative solver invariants label expression = do
  source <- either (die . show) pure (parseRefinementSource "synthetic.hs" (unlines
    [ "module Synthetic where"
    , ""
    , "{-@ amoebius-refinement"
    , "model: Counter"
    , "invariant: NonNegative"
    , "function: synthetic"
    , "arguments: x"
    , "pre: " <> expression
    , "post: result >= 0"
    , "@-}"
    , ""
    , "synthetic :: Integer -> Integer"
    , "synthetic x = x"
    ]))
  result <- checkRefinement solver invariants source
  assertLeft label result

renderResults :: [RefinementResult] -> Int -> Int -> String
renderResults observations invariantCount coveredCount = unlines
  [ "metric\tvalue"
  , metric "fixture-count" (length observations)
  , metric "proved-count" (count Proved)
  , metric "postcondition-counterexample-count" (count PostconditionCounterexample)
  , metric "correspondence-mismatch-count" (count CorrespondenceMismatch)
  , metric "unknown-invariant-count" (count UnknownInvariant)
  , metric "required-invariant-count" invariantCount
  , metric "covered-invariant-count" coveredCount
  , metric "ghc-compiled-count" (length observations)
  , metric "diagnostic-count" (length (filter ((/= Proved) . refinementResultStatus) observations))
  , metric "source-digest-count" (length (filter ((== 64) . length . refinementResultSourceDigest) observations))
  ]
 where
  count status = length (filter ((== status) . refinementResultStatus) observations)
  metric name value = name <> "\t" <> show value

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual = unless (expected == actual) (die ("FAIL: " <> label <> ": expected " <> show expected <> ", got " <> show actual))

assertLeft :: Show right => String -> Either left right -> IO ()
assertLeft _ (Left _) = pure ()
assertLeft label (Right value) = die ("FAIL: " <> label <> ": expected refusal, got " <> show value)

expectations :: [Expected]
expectations =
  [ Expected "test/fixture/refinement_checker/Increment.hs" "Counter" "NonNegative" "increment" Proved
      "postcondition preserved and correspondence established" True 13 "e6a45a39b182def55acb07935f89fe7320d585f22fd2e62333a12675aab6a875"
  , Expected "test/fixture/refinement_checker/Decrement.hs" "Counter" "NonNegative" "decrement" Proved
      "postcondition preserved and correspondence established" True 13 "9586a7905027e5aa0e4f0c70f48544e1e4751dc972323c726dc097eaef3ce0ac"
  , Expected "test/fixture/refinement_checker/Sum.hs" "Pair" "NonNegativeSum" "sumNonNegative" Proved
      "postcondition preserved and correspondence established" True 13 "295f1e448cfdb630e22923854a75404b631cb4f9cc8aac13202ba7923bff2246"
  , Expected "test/fixture/refinement_checker/Broken.hs" "Counter" "NonNegative" "brokenDecrement" PostconditionCounterexample
      "function body does not establish its postcondition" False 13 "1648f17f11b15efaac2e49617c1b494ff10434cd9e8d3ef901281a26ea48b9b3"
  , Expected "test/fixture/refinement_checker/Mismatch.hs" "Counter" "NonNegative" "negativeIdentity" CorrespondenceMismatch
      "postcondition does not imply the registered model invariant" False 13 "a465d0abf92906240933024d106d25592f8cfdc8aaaf2b015f06eb3f85c3f361"
  , Expected "test/fixture/refinement_checker/Unknown.hs" "Counter" "MissingInvariant" "unknownMapping" UnknownInvariant
      "annotation names no registered model invariant" False 13 "2046cfe0f35f3e840fac52a9be8f34d7bb9d9045807d89469def68d2d22191d0"
  ]
