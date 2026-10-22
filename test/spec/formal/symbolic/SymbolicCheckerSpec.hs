-- | Observations from the parked symbolic checker, never a verdict.
module Main (main) where

import Amoebius.Checker.Symbolic
import Amoebius.Formal.Model
import Control.Monad (forM)
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
  relative <- mkSolver "z3"
  rows <- forM fixtureModels $ \(name, model) -> do
    let caseRoot = output </> "symbolic" </> name
    exists <- doesDirectoryExist caseRoot
    if exists then die ("fixture root already exists: " <> caseRoot) else pure ()
    createDirectoryIfMissing True caseRoot
    copied <- makeAbsolute (caseRoot </> "fake-smt-solver" <> takeExtension solverPath)
    copyFile solverPath copied
    solver <- mkSolver copied >>= either (die . show) pure
    observed <- checkInductive solver model
    pure $ case observed of
      Left problem -> ["symbolic", name, "error", show problem]
      Right result -> ["symbolic", name, constructor (show (verdictResult result)),
        show (verdictResult result), verdictModelDigest result,
        show (verdictInvariantCount result), show (verdictObligationCount result)]
  createDirectoryIfMissing True output
  writeFile (output </> "symbolic.tsv") (unlines (map tsv
    (["solver", "symbolic-relative", show relative] : rows)))
  putStrLn ("symbolic observations written: " <> (output </> "symbolic.tsv"))
 where
  constructor = takeWhile (/= ' ')
  tsv = foldr1 (\left right -> left <> "\t" <> right)

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
