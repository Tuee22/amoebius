-- | Observations from the parked refinement checker, never a verdict.
module Main (main) where

import Amoebius.Checker.Refinement
import Control.Monad (forM)
import Data.Map.Strict qualified as Map
import System.Directory (copyFile, createDirectoryIfMissing, doesDirectoryExist, makeAbsolute)
import System.Environment (getArgs)
import System.Exit (die)
import System.FilePath ((</>), takeExtension)

main :: IO ()
main = do
  arguments <- getArgs
  (solverPath, output) <- case arguments of
    [path, root] -> pure (path, root)
    _ -> die "expected exact argv: SOLVER OUTPUT_ROOT"
  relative <- mkRefinementSolver "relative-solver"
  invariant <- either (die . show) pure (parseRefinementExpr "result >= 0")
  let invariants = Map.fromList [(("Counter", "NonNegative"), invariant), (("Pair", "NonNegativeSum"), invariant)]
      paths = ["Increment", "Decrement", "Sum", "Broken", "Mismatch", "Unknown"]
  observations <- forM paths $ \name -> do
    solver <- fixtureSolver solverPath output "refinement" name
    let path = "test/fixture/refinement_checker/" <> name <> ".hs"
    contents <- readFile path
    source <- either (die . show) pure (parseRefinementSource path contents)
    result <- checkRefinement solver invariants source
    pure $ case result of
      Left problem -> ["refinement", name, "error", show problem]
      Right observed -> ["refinement", name, show (refinementResultStatus observed),
        refinementResultReason observed, refinementResultFunction observed,
        show (refinementResultLine observed), refinementResultSourceDigest observed,
        show (refinementResultSolverModel observed)]
  negatives <- forM [("unbound-expression", "missing >= 0"), ("ill-sorted-expression", "x && true")] $ \(name, expression) -> do
    solver <- fixtureSolver solverPath output "refinement-negative" name
    source <- either (die . show) pure (parseRefinementSource "synthetic.hs" (unlines
      [ "module Synthetic where", "", "{-@ amoebius-refinement"
      , "model: Counter", "invariant: NonNegative", "function: synthetic", "arguments: x"
      , "pre: " <> expression, "post: result >= 0", "@-}", ""
      , "synthetic :: Integer -> Integer", "synthetic x = x"
      ]))
    result <- checkRefinement solver invariants source
    pure ["refinement-negative", name, either show (show . refinementResultStatus) result]
  createDirectoryIfMissing True output
  writeFile (output </> "refinement.tsv") (unlines (map tsv
    (["solver", "refinement-relative", show relative] : observations <> negatives)))
  putStrLn ("refinement observations written: " <> (output </> "refinement.tsv"))
 where
  tsv = foldr1 (\left right -> left <> "\t" <> right)

fixtureSolver :: FilePath -> FilePath -> FilePath -> FilePath -> IO RefinementSolver
fixtureSolver original output family name = do
  let caseRoot = output </> family </> name
  exists <- doesDirectoryExist caseRoot
  if exists then die ("fixture root already exists: " <> caseRoot) else pure ()
  createDirectoryIfMissing True caseRoot
  copied <- makeAbsolute (caseRoot </> "fake-smt-solver" <> takeExtension original)
  copyFile original copied
  mkRefinementSolver copied >>= either (die . show) pure
