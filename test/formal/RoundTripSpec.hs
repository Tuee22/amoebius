module Main (main) where

import Amoebius.Formal.EmitTLA
import Amoebius.Formal.Explore
import Amoebius.Formal.Interpret
import Amoebius.Formal.Model
import Amoebius.Formal.ToyModel
import Control.Monad (forM, forM_, unless, when)
import Data.Char (isDigit, isSpace)
import Data.IORef
import Data.List (find, intercalate, isInfixOf, isPrefixOf, isSuffixOf, tails)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe)
import Data.Set (Set)
import qualified Data.Set as Set
import System.Directory (canonicalizePath, createDirectoryIfMissing, doesFileExist, getCurrentDirectory)
import System.Environment (lookupEnv)
import System.Exit (ExitCode (..), exitFailure)
import System.FilePath ((</>))
import System.Process (readProcessWithExitCode)
import Test.QuickCheck
  ( Arbitrary (..)
  , Args (..)
  , checkCoverage
  , chooseInt
  , counterexample
  , cover
  , ioProperty
  , isSuccess
  , quickCheckWithResult
  , stdArgs
  )
import qualified Test.QuickCheck as QC
import Test.QuickCheck.Random (mkQCGen)

data TlcResult = TlcResult
  { tlcExit :: ExitCode
  , tlcOutput :: String
  , tlcFingerprints :: Set String
  , tlcDistinctCount :: Maybe Int
  }
  deriving stock (Show)

data DifferentialRecord = DifferentialRecord
  { recordCases :: Int
  , recordViolating :: Int
  , recordBoundary :: Int
  , recordCoverage :: Map String Int
  }
  deriving stock (Eq, Show)

emptyRecord :: DifferentialRecord
emptyRecord = DifferentialRecord 0 0 0 Map.empty

newtype GeneratedSeed = GeneratedSeed Int
  deriving stock (Eq, Show)

instance Arbitrary GeneratedSeed where
  arbitrary = GeneratedSeed <$> chooseInt (0, 1000000)
  shrink _ = []

main :: IO ()
main = do
  root <- getCurrentDirectory >>= canonicalizePath
  java <- resolveTool root "AMOEBIUS_JAVA" "toolchain/runtime/java/bin/java"
  jar <- resolveTool root "AMOEBIUS_TLA2TOOLS" "toolchain/runtime/tla/tla2tools.jar"
  let output = root </> "gen/tla/formal-model-spec"
  createDirectoryIfMissing True output

  putStrLn "formal-model-spec: structural fragment and hand oracle"
  assertEqual "ToyModel structural well-formedness" [] (modelProblems toyModel)
  checkRequiredConstructors root
  checkHandTransitions root
  toyExplorer <- requireRight "ToyModel explorer" (explore toyModel)
  assertEqual "ToyModel distinct states" 8 (Map.size (exploreStates toyExplorer))
  assertEqual "ToyModel safety" Nothing (exploreViolation toyExplorer)

  putStrLn "formal-model-spec: byte golden and renderer mutants"
  checkGolden root
  rendererGoldenCaught <- checkRendererGoldenMutants root
  checkNeverCommitted root

  putStrLn "formal-model-spec: TLC round-trip and liveness sensitivity"
  toyTlc <- runTlc java jar output Correct toyModel
  assert (tlcExit toyTlc == ExitSuccess) ("ToyModel TLC failed:\n" <> tlcOutput toyTlc)
  assertEqual "ToyModel TLC distinct count" (Just 8) (tlcDistinctCount toyTlc)
  assertEqual "ToyModel explorer/TLC fingerprints"
    (Map.keysSet (exploreStates toyExplorer)) (tlcFingerprints toyTlc)
  checkObligationSet root toyModel
  fairnessSensitivity <- checkFairnessSensitivity java jar output

  putStrLn "formal-model-spec: mechanical model mutation family"
  modelMutantsCaught <- checkModelMutants java jar output
  specWeakeningCaught <- checkSpecWeakening root

  putStrLn "formal-model-spec: seeded renderer differential mutants"
  rendererDifferentialCaught <- checkRendererDifferentialMutants java jar output

  putStrLn "formal-model-spec: QuickCheck differential (200 models)"
  recordRef <- newIORef emptyRecord
  let args = stdArgs
        { maxSuccess = 200
        , maxDiscardRatio = 10
        , replay = Just (mkQCGen 20260808, 0)
        , chatty = True
        }
  result <- quickCheckWithResult args (generatedDifferentialProperty java jar output recordRef)
  unless (isSuccess result) exitFailure
  record <- readIORef recordRef
  assertEqual "differential case count" 200 (recordCases record)
  assert (recordViolating record * 5 >= recordCases record) "safety-violating coverage below 20%"
  assert (recordBoundary record * 5 >= recordCases record) "constraint-boundary coverage below 20%"
  forM_ requiredCoverage $ \label ->
    assert (Map.findWithDefault 0 label (recordCoverage record) * 5 >= recordCases record)
      ("constructor coverage below 20%: " <> label)
  writePhaseResults output toyExplorer toyTlc fairnessSensitivity modelMutantsCaught
    specWeakeningCaught rendererGoldenCaught rendererDifferentialCaught record
  putStrLn ("formal-model-spec: PASS (" <> show (recordCases record) <> " differential models)")

resolveTool :: FilePath -> String -> FilePath -> IO FilePath
resolveTool root variable relative = do
  configured <- lookupEnv variable
  canonicalizePath (fromMaybe (root </> relative) configured)

assert :: Bool -> String -> IO ()
assert condition message = unless condition (putStrLn ("FAIL: " <> message) >> exitFailure)

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual =
  assert (expected == actual) (label <> ": expected " <> show expected <> ", got " <> show actual)

requireRight :: String -> Either String value -> IO value
requireRight label result = case result of
  Left problem -> putStrLn ("FAIL: " <> label <> ": " <> problem) >> exitFailure
  Right value -> pure value

checkRequiredConstructors :: FilePath -> IO ()
checkRequiredConstructors root = do
  expected <- Set.fromList . filter (not . null) . lines <$> readFile (root </> "test/formal/oracle/ToyModel.required_constructors.txt")
  let actual = constructorSet toyModel
  assertEqual "ToyModel required constructors" expected (Set.intersection expected actual)

constructorSet :: Model -> Set String
constructorSet model = Set.unions
  [ Set.unions [exprConstructors expr | (_, expr) <- modelInit model]
  , Set.unions
      [ Set.unions
          ( exprConstructors (actionGuard action)
          : [exprConstructors (parameterDomain parameter) | parameter <- actionParameters action]
          <> [exprConstructors expr | (_, expr) <- actionEffects action]
          )
      | action <- modelActions model
      ]
  , Set.unions [exprConstructors (namedExprBody invariant) | invariant <- modelInvariants model]
  , maybe Set.empty (exprConstructors . namedExprBody) (modelConstraint model)
  , maybe Set.empty exprConstructors (modelExpansionLimit model)
  , Set.fromList [show (fairnessKind fairness) | fairness <- modelFairness model]
  , Set.unions [temporalConstructors (propertyTemporal property) | property <- modelProperties model]
  ]

exprConstructors :: Expr -> Set String
exprConstructors expression = Set.insert label children
  where
    (label, children) = case expression of
      Literal (BoolValue _) -> ("BoolLiteral", Set.empty)
      Literal _ -> ("Literal", Set.empty)
      Ref _ -> ("Reference", Set.empty)
      Not expr -> ("Boolean", exprConstructors expr)
      And exprs -> ("Boolean", Set.unions (map exprConstructors exprs))
      Or exprs -> ("Boolean", Set.unions (map exprConstructors exprs))
      Implies left right -> ("Implication", both left right)
      Equal left right -> ("Boolean", both left right)
      NotEqual left right -> ("Boolean", both left right)
      ArithmeticComparison _ left right -> ("ArithmeticComparison", both left right)
      Add left right -> ("Arithmetic", both left right)
      Subtract left right -> ("Subtraction", both left right)
      FiniteSet exprs -> ("FiniteSet", Set.unions (map exprConstructors exprs))
      SetUnion left right -> ("SetUnion", both left right)
      SetDifference left right -> ("SetDifference", both left right)
      Cardinality expr -> ("Cardinality", exprConstructors expr)
      FiniteSetMembership left right -> ("FiniteSetMembership", both left right)
      FiniteQuantifier _ _ domain predicate -> ("FiniteQuantifier", both domain predicate)
      FunctionLiteral _ domain body -> ("FunctionLiteral", both domain body)
      FunctionUpdate function key value ->
        ("FunctionUpdate", Set.unions (map exprConstructors [function, key, value]))
      FunctionApplication function key -> ("FunctionApplication", both function key)
      IfThenElse condition whenTrue whenFalse ->
        ("Conditional", Set.unions (map exprConstructors [condition, whenTrue, whenFalse]))
    both left right = Set.union (exprConstructors left) (exprConstructors right)

temporalConstructors :: Temporal -> Set String
temporalConstructors temporal = case temporal of
  Always expr -> Set.insert "Always" (exprConstructors expr)
  Eventually expr -> Set.insert "Eventually" (exprConstructors expr)
  LeadsTo left right -> Set.insert "LeadsTo" (Set.union (exprConstructors left) (exprConstructors right))

checkHandTransitions :: FilePath -> IO ()
checkHandTransitions root = do
  contents <- readFile (root </> "test/formal/oracle/ToyModel.transitions.tsv")
  forM_ (drop 1 (lines contents)) $ \row -> case splitOn '\t' row of
    [fromText, eventText, toText, "true", "MutualExclusion"] -> do
      fromState <- stateFromPair fromText
      let event = eventFromText eventText
      actual <- maybe (putStrLn ("FAIL: disabled hand transition " <> eventText) >> exitFailure) pure
        (interpret toyModel event fromState)
      assertEqual ("hand transition " <> eventText <> " from " <> fromText) toText (statePair actual)
      invariant <- case modelInvariants toyModel of
        firstInvariant : _ -> pure firstInvariant
        [] -> putStrLn "FAIL: ToyModel has no invariant" >> exitFailure
      valid <- requireRight "hand transition invariant"
        (evalExpr toyModel Map.empty actual (namedExprBody invariant) >>= valueAsBool)
      assert valid ("hand transition violates MutualExclusion: " <> row)
    fields -> assert False ("malformed hand transition row: " <> show fields)

stateFromPair :: String -> IO State
stateFromPair encoded = case splitOn ',' encoded of
  [p0, p1] -> pure (Map.fromList
    [ ("pc", function p0 p1)
    , ("mirror", function p0 p1)
    , ("criticalCount", IntValue (if "critical" `elem` [p0, p1] then 1 else 0))
    ])
  _ -> putStrLn ("FAIL: malformed state pair " <> encoded) >> exitFailure
  where
    function p0 p1 = FunctionValue
      [(AtomValue "p0", AtomValue p0), (AtomValue "p1", AtomValue p1)]

statePair :: State -> String
statePair state = case Map.lookup "pc" state of
  Just (FunctionValue pairs) -> intercalate ","
    [atomAt (AtomValue "p0") pairs, atomAt (AtomValue "p1") pairs]
  value -> "<invalid-pc:" <> show value <> ">"
  where
    atomAt key pairs = case lookup key pairs of
      Just (AtomValue value) -> value
      value -> "<invalid:" <> show value <> ">"

eventFromText :: String -> Event
eventFromText text = case splitOn '-' text of
  [action, process] -> Event (capitalize action) [AtomValue process]
  _ -> Event "<invalid>" []
  where
    capitalize [] = []
    capitalize (first : rest) = toEnum (fromEnum first - 32) : rest

checkGolden :: FilePath -> IO ()
checkGolden root = do
  expectedTla <- readFile (root </> "test/formal/golden/ToyModel.tla.golden")
  expectedCfg <- readFile (root </> "test/formal/golden/ToyModel.cfg.golden")
  let (Tla actualTla, Cfg actualCfg) = emitTLA toyModel
  assertEqual "ToyModel TLA byte golden" expectedTla actualTla
  assertEqual "ToyModel CFG byte golden" expectedCfg actualCfg
  assert ("WF_vars" `isInfixOf` actualTla) "golden does not exercise WeakFair"
  assert ("SF_vars" `isInfixOf` actualTla) "golden does not exercise StrongFair"
  assert ("[](" `isInfixOf` actualTla) "golden does not exercise Always"
  assert ("<>(" `isInfixOf` actualTla) "golden does not exercise Eventually"
  assert (" ~> " `isInfixOf` actualTla) "golden does not exercise LeadsTo"

checkRendererGoldenMutants :: FilePath -> IO Int
checkRendererGoldenMutants root = do
  golden <- readFile (root </> "test/formal/golden/ToyModel.tla.golden")
  caught <- forM [(StrongAsWeak, "emitTLA-mut-03"), (AlwaysAsEventually, "emitTLA-mut-04")] $ \(mode, name) -> do
    let (Tla mutant, _) = emitTLAWith mode toyModel
    assert (mutant /= golden) (name <> " survived byte golden")
    pure True
  pure (length (filter id caught))

checkNeverCommitted :: FilePath -> IO ()
checkNeverCommitted root = do
  (exitCode, stdoutText, stderrText) <- readProcessWithExitCode "git" ["ls-files", "--", "gen/*", "*.tla", "*.cfg"] ""
  assert (exitCode == ExitSuccess) ("git ls-files failed: " <> stderrText)
  assert (null stdoutText) ("generated TLA artifacts are tracked:\n" <> stdoutText)
  assert (root `isPrefixOf` root) "repository root resolution failed"

checkObligationSet :: FilePath -> Model -> IO ()
checkObligationSet root model = do
  expectedRows <- lines <$> readFile (root </> "test/formal/oracle/ToyModel.expected.tsv")
  let expectedInvariants = Set.fromList [value | row <- expectedRows, ["invariant", value] <- [splitOn '\t' row]]
      expectedProperties = Set.fromList [value | row <- expectedRows, ["property", value] <- [splitOn '\t' row]]
      (_, Cfg cfg) = emitTLA model
      actualInvariants = cfgNames "INVARIANT " cfg
      actualProperties = cfgNames "PROPERTY " cfg
  assertEqual "CFG invariant obligation set" expectedInvariants actualInvariants
  assertEqual "CFG property obligation set" expectedProperties actualProperties

cfgNames :: String -> String -> Set String
cfgNames prefix = Set.fromList . map (drop (length prefix)) . filter (prefix `isPrefixOf`) . lines

checkFairnessSensitivity :: FilePath -> FilePath -> FilePath -> IO Bool
checkFairnessSensitivity java jar output = do
  let mutant = toyModel {modelName = "ToyModelFairnessDrop", modelFairness = []}
  result <- runTlc java jar output Correct mutant
  assert (tlcExit result /= ExitSuccess) "fairness-drop mutant did not make TLC liveness red"
  assert ("Temporal properties were violated" `isInfixOf` tlcOutput result
       || "temporal property" `isInfixOf` tlcOutput result)
    ("fairness-drop failed for the wrong reason:\n" <> tlcOutput result)
  let (Tla correct, _) = emitTLA toyModel
      (Tla renderedMutant, _) = emitTLA mutant
  assert (correct /= renderedMutant) "fairness-drop mutant survived byte golden"
  pure (tlcExit result /= ExitSuccess)

checkModelMutants :: FilePath -> FilePath -> FilePath -> IO Int
checkModelMutants java jar output = do
  caught <- forM safetyModelMutants $ \(name, mutant) -> do
    explorer <- requireRight name (explore mutant)
    assert (exploreViolation explorer /= Nothing) (name <> " stayed green in explorer")
    result <- runTlc java jar output Correct mutant
    assert (tlcExit result /= ExitSuccess) (name <> " stayed green in TLC")
    assert ("Invariant" `isInfixOf` tlcOutput result || "invariant" `isInfixOf` tlcOutput result)
      (name <> " failed TLC for the wrong reason:\n" <> tlcOutput result)
    pure True
  pure (length (filter id caught))

safetyModelMutants :: [(String, Model)]
safetyModelMutants =
  [ named "ModelMutGuardNegation" (mapAction "Enter" (\action -> action {actionGuard = Not (actionGuard action)}))
  , named "ModelMutGuardWeakening" (mapAction "Enter" (\action -> action
      {actionGuard = Equal (FunctionApplication (Ref "pc") (Ref "p")) (Literal (AtomValue "want"))}))
  , named "ModelMutEffectSwap" (mapAction "Request" (\action -> action {actionEffects =
      [ ("pc", FunctionUpdate (Ref "pc") (Ref "p") (Literal (AtomValue "critical")))
      , ("mirror", FunctionUpdate (Ref "mirror") (Ref "p") (Literal (AtomValue "critical")))
      ]}))
  , named "ModelMutDropEffect" (mapAction "Enter" (\action -> action
      {actionEffects = filter ((/= "criticalCount") . fst) (actionEffects action)}))
  , named "ModelMutQuantifierFlip" (mapAction "Enter" (\action -> action
      {actionGuard = flipForAll (actionGuard action)}))
  ]
  where
    named name transform = (name, (transform toyModel) {modelName = name, modelProperties = []})

mapAction :: Name -> (Action -> Action) -> Model -> Model
mapAction name transform model = model
  {modelActions = [if actionName action == name then transform action else action | action <- modelActions model]}

flipForAll :: Expr -> Expr
flipForAll expression = case expression of
  FiniteQuantifier ForAll binder domain predicate -> FiniteQuantifier Exists binder domain predicate
  And exprs -> And (map flipForAll exprs)
  Or exprs -> Or (map flipForAll exprs)
  Not expr -> Not (flipForAll expr)
  other -> other

checkSpecWeakening :: FilePath -> IO Bool
checkSpecWeakening root = do
  golden <- readFile (root </> "test/formal/golden/ToyModel.tla.golden")
  let weaken named = named {namedExprBody = case namedExprBody named of
        And (_ : rest) -> And rest
        _ -> Literal (BoolValue True)}
      mutant = toyModel {modelName = "ToyModel", modelInvariants = map weaken (modelInvariants toyModel)}
      (Tla rendered, Cfg cfg) = emitTLA mutant
      (_, Cfg correctCfg) = emitTLA toyModel
  assert (rendered /= golden) "invariant-clause-delete mutant survived byte golden"
  assertEqual "invariant-clause-delete retains named obligation set"
    (cfgNames "INVARIANT " correctCfg) (cfgNames "INVARIANT " cfg)
  pure (rendered /= golden)

checkRendererDifferentialMutants :: FilePath -> FilePath -> FilePath -> IO Int
checkRendererDifferentialMutants java jar output = do
  let witness = generatedModel 42
  explorer <- requireRight "renderer mutant witness" (explore witness)
  caught <- forM [(DropUnchanged, "emitTLA-mut-01"), (ForAllAsExists, "emitTLA-mut-02")] $ \(mode, name) -> do
    result <- runTlc java jar output mode witness
    let sameVerdict = (tlcExit result == ExitSuccess) == (exploreViolation explorer == Nothing)
        sameStates = tlcFingerprints result == Map.keysSet (exploreStates explorer)
    assert (not sameVerdict || not sameStates) (name <> " survived generated differential witness")
    pure True
  pure (length (filter id caught))

generatedDifferentialProperty
  :: FilePath -> FilePath -> FilePath -> IORef DifferentialRecord -> GeneratedSeed -> QC.Property
generatedDifferentialProperty java jar output recordRef (GeneratedSeed seed) =
  checkCoverage
    . cover 20 violating "safety-violating"
    . cover 20 True "constraint-boundary"
    . foldr (.) id [cover 20 (label `Set.member` labels) label | label <- requiredCoverage]
    . ioProperty $ do
      outcome <- differentialCase java jar output model
      modifyIORef' recordRef (recordCase labels violating outcome)
      when (seed `mod` 25 == 0) (putStrLn ("differential seed " <> show seed))
      pure (counterexample outcome (null outcome))
  where
    model = generatedModel seed
    labels = constructorSet model
    violating = odd seed

requiredCoverage :: [String]
requiredCoverage =
  [ "BoolLiteral"
  , "ArithmeticComparison"
  , "Implication"
  , "Subtraction"
  , "FiniteSetMembership"
  , "SetUnion"
  , "SetDifference"
  , "Cardinality"
  , "FiniteQuantifier"
  , "FunctionLiteral"
  , "FunctionUpdate"
  , "FunctionApplication"
  , "Conditional"
  , "WeakFair"
  , "StrongFair"
  , "Always"
  , "Eventually"
  , "LeadsTo"
  ]

recordCase :: Set String -> Bool -> String -> DifferentialRecord -> DifferentialRecord
recordCase labels violating outcome record
  | not (null outcome) = record
  | otherwise = record
      { recordCases = recordCases record + 1
      , recordViolating = recordViolating record + fromEnum violating
      , recordBoundary = recordBoundary record + 1
      , recordCoverage = foldr (\label -> Map.insertWith (+) label 1) (recordCoverage record) (Set.toList labels)
      }

differentialCase :: FilePath -> FilePath -> FilePath -> Model -> IO String
differentialCase java jar output annotatedModel = do
  let model = annotatedModel {modelFairness = [], modelProperties = []}
  case modelProblems model of
    problems@(_ : _) -> pure ("model is structurally malformed: " <> show problems)
    [] -> case explore model of
      Left problem -> pure ("explorer failed: " <> problem)
      Right explorer -> do
        tlc <- runTlc java jar output Correct model
        let explorerGreen = exploreViolation explorer == Nothing
            tlcGreen = tlcExit tlc == ExitSuccess
        stateRun <- if tlcGreen
          then pure tlc
          else runTlc java jar output Correct (model {modelName = modelName model <> "StateSpace", modelInvariants = []})
        let expectedStates = Map.keysSet (exploreStates explorer)
        pure . intercalate "; " . filter (not . null) $
          [ if explorerGreen == tlcGreen then "" else "safety verdict differs"
          , if tlcExit stateRun == ExitSuccess then "" else "state-space TLC run failed: " <> take 300 (tlcOutput stateRun)
          , if expectedStates == tlcFingerprints stateRun
              then ""
              else "fingerprints differ expected=" <> show expectedStates <> " actual=" <> show (tlcFingerprints stateRun)
          , if Map.size (exploreStates explorer) >= 2 then "" else "model has fewer than two states"
          , case Map.elems (exploreStates explorer) of
              initial : _ | null (enabledEvents model initial) -> "model has no enabled action"
              [] -> "model has no reachable state"
              _ -> ""
          , if Set.null (exploreBoundaryStates explorer) then "model reaches no expansion boundary" else ""
          ]

generatedModel :: Int -> Model
generatedModel rawSeed = Model
  { modelName = "Generated" <> show (abs rawSeed)
  , modelConstants = []
  , modelVariables = ["x", "y", "q"]
  , modelInit = [("x", int 0), ("y", bool False), ("q", bool False)]
  , modelActions = [advance, flipAction, quantifierWitness]
  , modelInvariants = [NamedExpr "Safe" invariant]
  , modelConstraint = Just (NamedExpr "StateBound" stateBound)
  , modelExpansionLimit = Just (ArithmeticComparison LessThan (Ref "x") (int limit))
  , modelFairness = [Fairness WeakFair "Advance", Fairness StrongFair "Flip"]
  , modelProperties =
      [ Property "AlwaysSafe" (Always (Ref "Safe"))
      , Property "EventuallyY" (Eventually (Equal (Ref "y") (bool True)))
      , Property "ZeroLeadsToBoundary" (LeadsTo (Equal (Ref "x") (int 0)) (Equal (Ref "x") (int limit)))
      ]
  , modelCheckDeadlock = False
  }
  where
    limit = 2 + abs rawSeed `mod` 2
    domain = FiniteSet [int value | value <- [0 .. limit]]
    binaryDomain = FiniteSet [int 0, int 1]
    functionExercise = Equal
      (FunctionApplication
        (FunctionUpdate (FunctionLiteral "k" binaryDomain (Ref "k")) (int 0) (int 1))
        (int 0))
      (int 1)
    advance = Action
      { actionName = "Advance"
      , actionParameters = []
      , actionGuard = And
          [ bool True
          , Implies (bool True) (bool True)
          , ArithmeticComparison LessThan (Ref "x") (int limit)
          , Equal (Subtract (int 1) (int 1)) (int 0)
          , FiniteSetMembership (Ref "x") domain
          , Equal (SetUnion (FiniteSet [int 0]) (FiniteSet [int 1])) binaryDomain
          , Equal (SetDifference binaryDomain (FiniteSet [int 1])) (FiniteSet [int 0])
          , Equal (Cardinality binaryDomain) (int 2)
          , FiniteQuantifier Exists "i" binaryDomain (Equal (Ref "i") (int 0))
          , functionExercise
          , Equal (IfThenElse (bool True) (int 1) (int 0)) (int 1)
          ]
      , actionEffects = [("x", Add (Ref "x") (int 1))]
      }
    flipAction = Action
      { actionName = "Flip"
      , actionParameters = []
      , actionGuard = bool True
      , actionEffects = [("y", Not (Ref "y"))]
      }
    quantifierWitness = Action
      { actionName = "QuantifierWitness"
      , actionParameters = []
      , actionGuard = FiniteQuantifier ForAll "i" binaryDomain (Equal (Ref "i") (int 0))
      , actionEffects = [("q", bool True)]
      }
    stateBound = And
      [ FiniteSetMembership (Ref "x") domain
      , FiniteSetMembership (Ref "y") (FiniteSet [bool False, bool True])
      , FiniteSetMembership (Ref "q") (FiniteSet [bool False, bool True])
      ]
    invariant = And
      [ if odd rawSeed
          then ArithmeticComparison LessThan (Ref "x") (int limit)
          else ArithmeticComparison LessThanOrEqual (Ref "x") (int limit)
      , Equal (Ref "q") (bool False)
      ]
    int = Literal . IntValue . fromIntegral
    bool = Literal . BoolValue

runTlc :: FilePath -> FilePath -> FilePath -> RenderMode -> Model -> IO TlcResult
runTlc java jar output mode model = do
  let directory = output </> modelName model <> "-" <> modeSuffix mode
      tlaPath = directory </> modelName model <> ".tla"
      cfgPath = directory </> modelName model <> ".cfg"
      dotPath = directory </> modelName model <> ".dot"
      (Tla tla, Cfg cfg) = emitTLAWith mode model
  createDirectoryIfMissing True directory
  writeFile tlaPath tla
  writeFile cfgPath cfg
  (exitCode, stdoutText, stderrText) <- readProcessWithExitCode java
    [ "-XX:+UseParallelGC"
    , "-jar", jar
    , "-workers", "1"
    , "-cleanup"
    , "-nowarning"
    , "-fp", "0"
    , "-seed", "1"
    , "-dump", "dot,actionlabels", dotPath
    , "-config", cfgPath
    , tlaPath
    ] ""
  writeFile (directory </> modelName model <> ".tlc.log") (stdoutText <> stderrText)
  dot <- readFileIfPresent dotPath
  pure TlcResult
    { tlcExit = exitCode
    , tlcOutput = stdoutText <> stderrText
    , tlcFingerprints = parseDotFingerprints model dot
    , tlcDistinctCount = parseDistinctCount (stdoutText <> stderrText)
    }

modeSuffix :: RenderMode -> String
modeSuffix mode = case mode of
  Correct -> "correct"
  DropUnchanged -> "drop-unchanged"
  ForAllAsExists -> "forall-as-exists"
  StrongAsWeak -> "strong-as-weak"
  AlwaysAsEventually -> "always-as-eventually"

readFileIfPresent :: FilePath -> IO String
readFileIfPresent path = do
  present <- doesFileExist path
  if present then readFile path else pure ""

parseDistinctCount :: String -> Maybe Int
parseDistinctCount output = do
  line <- find (" distinct states found" `isInfixOf`) (reverse (lines output))
  preceding <- wordBefore "distinct" (words line)
  readMaybeInt (filter isDigit preceding)

wordBefore :: Eq value => value -> [value] -> Maybe value
wordBefore target = go Nothing
  where
    go _ [] = Nothing
    go previous (value : rest)
      | value == target = previous
      | otherwise = go (Just value) rest

readMaybeInt :: String -> Maybe Int
readMaybeInt text = case reads (takeWhile isDigit text) of
  [(value, "")] -> Just value
  _ -> Nothing

parseDotFingerprints :: Model -> String -> Set String
parseDotFingerprints model dot = Set.fromList
  [ fingerprintFromLabel model label
  | line <- lines dot
  , " -> " `notElemIn` line
  , Just label <- [extractLabel line]
  , " = " `isInfixOf` label
  ]
  where
    needle `notElemIn` haystack = not (needle `isInfixOf` haystack)

extractLabel :: String -> Maybe String
extractLabel line = do
  rest <- stripAfter "[label=\"" line
  let encoded = takeUntilLabelEnd rest
  pure (unescapeDot encoded)

takeUntilLabelEnd :: String -> String
takeUntilLabelEnd = go False
  where
    go _ [] = []
    go escaped ('"' : rest)
      | not escaped && labelEnded rest = []
    go escaped (character : rest) = character : go (character == '\\' && not escaped) rest
    labelEnded [] = True
    labelEnded (next : _) = next == ']' || next == ','

unescapeDot :: String -> String
unescapeDot [] = []
unescapeDot ('\\' : 'n' : rest) = '\n' : unescapeDot rest
unescapeDot ('\\' : '"' : rest) = '"' : unescapeDot rest
unescapeDot ('\\' : '\\' : rest) = '\\' : unescapeDot rest
unescapeDot (character : rest) = character : unescapeDot rest

fingerprintFromLabel :: Model -> String -> String
fingerprintFromLabel model label = intercalate "|"
  [ name <> "=" <> Map.findWithDefault "<missing>" name assignments
  | name <- modelVariables model
  ]
  where
    assignments = Map.fromList
      [ let (name, valueWithEquals) = breakOn " = " (trim (dropConjunct line))
         in (trim name, normalizeTlcValue (drop 3 valueWithEquals))
      | line <- lines label
      , " = " `isInfixOf` line
      ]
    dropConjunct line = fromMaybe line (stripAfter "/\\ " line)

normalizeTlcValue :: String -> String
normalizeTlcValue raw
  | "[" `isPrefixOf` value && "]" `isSuffixOf` value =
      "[" <> intercalate "," (map normalizePair (splitOnComma (take (length value - 2) (drop 1 value)))) <> "]"
  | otherwise = value
  where
    value = trim raw
    normalizePair pair =
      let (key, arrowValue) = breakOn " |-> " pair
       in normalizeAtom (trim key) <> "|->" <> normalizeTlcValue (drop 5 arrowValue)
    normalizeAtom atom
      | "\"" `isPrefixOf` atom = atom
      | all (\character -> not (isSpace character)) atom = show atom
      | otherwise = atom

splitOnComma :: String -> [String]
splitOnComma text = case break (== ',') text of
  (piece, []) -> [piece]
  (piece, _ : rest) -> piece : splitOnComma rest

stripAfter :: String -> String -> Maybe String
stripAfter needle haystack = case find (needle `isPrefixOf`) (tails haystack) of
  Nothing -> Nothing
  Just match -> Just (drop (length needle) match)

breakOn :: String -> String -> (String, String)
breakOn needle haystack = case findIndexPrefix needle haystack of
  Nothing -> (haystack, "")
  Just index -> splitAt index haystack

findIndexPrefix :: String -> String -> Maybe Int
findIndexPrefix needle haystack = go 0 haystack
  where
    go _ [] = Nothing
    go index rest@(_ : remaining)
      | needle `isPrefixOf` rest = Just index
      | otherwise = go (index + 1) remaining

trim :: String -> String
trim = reverse . dropWhile isSpace . reverse . dropWhile isSpace

splitOn :: Char -> String -> [String]
splitOn delimiter text = case break (== delimiter) text of
  (piece, []) -> [piece]
  (piece, _ : rest) -> piece : splitOn delimiter rest

writePhaseResults
  :: FilePath -> ExploreResult -> TlcResult -> Bool -> Int -> Bool -> Int -> Int -> DifferentialRecord -> IO ()
writePhaseResults output explorer tlc fairnessSensitivity modelMutants specWeakening
    rendererGolden rendererDifferential record = writeFile (output </> "phase-results.tsv") . unlines $
  [ "metric\tvalue"
  , "toy-distinct-state-count\t" <> show (Map.size (exploreStates explorer))
  , "toy-safety-explorer\t" <> green (exploreViolation explorer == Nothing)
  , "toy-safety-tlc\t" <> green (tlcExit tlc == ExitSuccess)
  , "toy-state-fingerprints-equal\t" <> yes (Map.keysSet (exploreStates explorer) == tlcFingerprints tlc)
  , "toy-liveness-under-fairness\t" <> green (tlcExit tlc == ExitSuccess)
  , "fairness-drop-liveness\t" <> if fairnessSensitivity then "red" else "green"
  , "model-safety-mutants-caught\t" <> show modelMutants <> "/5"
  , "spec-weakening-mutants-caught\t" <> if specWeakening then "1/1" else "0/1"
  , "renderer-golden-mutants-caught\t" <> show rendererGolden <> "/2"
  , "renderer-differential-mutants-caught\t" <> show rendererDifferential <> "/2"
  , "case-count\t" <> show (recordCases record)
  , "safety-violating-count\t" <> show (recordViolating record)
  , "constraint-boundary-count\t" <> show (recordBoundary record)
  ] <> ["coverage-" <> label <> "\t" <> percentage (Map.findWithDefault 0 label (recordCoverage record)) | label <- requiredCoverage]
  where
    percentage count = show ((100 * count) `div` max 1 (recordCases record)) <> "%"
    green True = "green"
    green False = "red"
    yes True = "yes"
    yes False = "no"
