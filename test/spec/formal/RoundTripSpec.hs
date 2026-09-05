{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

module Main (main) where

import Amoebius.Calculus.Artifact.Recipe (RecipeId (..))
import Amoebius.Calculus.Budget.Grant (Bytes (..), Slots (..), allowance)
import Amoebius.Calculus.Composition
  ( Composition, append, artifactComponent, budgetComponent, calculusTag, compose
  , compositionKinds, compositionResource, evidenceComponent, liftComponent
  , singleton, workflowComponent
  )
import Amoebius.Calculus.Evidence.Register (Register (PureRegister))
import Amoebius.Calculus.Lift.Layer (Layer (OnHost))
import Amoebius.Calculus.Workflow.Ledger (emptyLedger)
import Amoebius.Capacity.Types (ResourceVector (..))
import Amoebius.Formal.CalculusComposition (compositionModel)
import Amoebius.Formal.EmitTLA (Cfg (..), Tla (..), emitTLA)
import Amoebius.Formal.Explore (ExploreResult (..), canonicalFingerprint, explore)
import Amoebius.Formal.Interpret (evalExpr, interpret, valueAsBool)
import Amoebius.Formal.Model
import Amoebius.Formal.ToyModel (toyModel)
import Amoebius.Scope.Index
  ( RequestScope, activeMembership, trustedSubject, trustedTenant, withRequestScope )
import Control.Monad (forM_, unless)
import Data.List (find, intercalate, isInfixOf, isPrefixOf, isSuffixOf, tails)
import Data.Map.Strict qualified as Map
import Data.Maybe (fromMaybe)
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text qualified as Text
import System.Directory (createDirectoryIfMissing)
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.FilePath ((</>))
import System.IO (hPutStrLn, stderr)

data TransitionRow = TransitionRow String Event String deriving stock (Eq, Show)
data InvariantRow = InvariantRow String String String String Integer Bool deriving stock (Eq, Show)
type RendererFact = (String, String, String)

main :: IO ()
main = do
  output <- getArgs >>= \case
    [] -> pure ".build/tla/formal-model-spec"
    [path] -> pure path
    arguments -> failWith "argv" ("expected one output root, got " <> show arguments)
  createDirectoryIfMissing True output
  assertEqual "model-problems" [] (modelProblems toyModel)
  assertEqual "required-constructors" requiredConstructors
    (Set.intersection requiredConstructors (constructorSet toyModel))
  checkStructuralPair
  putStrLn "formal-model-spec: paired structural model control PASS"
  checkTransitions
  checkInvariantRows
  explored <- requireRight "toy-explorer" (explore toyModel)
  assertEqual "toy-state-count" 8 (Map.size (exploreStates explored))
  assertEqual "toy-safety" Nothing (exploreViolation explored)
  assertEqual "toy-fingerprints" expectedToyFingerprints (Map.keysSet (exploreStates explored))
  let rendered@(Tla tla, Cfg cfg) = emitTLA toyModel
  assertEqual "renderer-facts" expectedRendererFacts (renderedSemanticFacts rendered)
  assert ("UNCHANGED <<criticalCount>>" `isInfixOf` tla) "renderer-unchanged"
  assertEqual "cfg-invariants" (Set.singleton "MutualExclusion") (cfgNames "INVARIANT " cfg)
  assertEqual "cfg-properties" expectedProperties (cfgNames "PROPERTY " cfg)
  writeFile (output </> "ToyModel.tla") tla
  writeFile (output </> "ToyModel.cfg") cfg
  checkComposition output
  putStrLn "formal-model-spec: generated artifact projection PASS"
  checkGeneratedCorpus
  putStrLn "formal-model-spec: PASS (8 states, 8 transitions, 25 renderer facts, 200 generated models)"

assert :: Bool -> String -> IO ()
assert condition label = unless condition (failWith label "expectation failed")

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual =
  unless (expected == actual) (failWith label ("expected " <> show expected <> ", got " <> show actual))

failWith :: String -> String -> IO value
failWith label detail = hPutStrLn stderr ("FAIL[" <> label <> "]: " <> detail) >> exitFailure

requireRight :: String -> Either String value -> IO value
requireRight label = either (failWith label) pure

checkStructuralPair :: IO ()
checkStructuralPair = do
  assertEqual "well-formed-positive" [] (modelProblems toyModel)
  let malformed = toyModel {modelVariables = "pc" : modelVariables toyModel}
  assertEqual "duplicate-variable-negative" ["duplicate variable pc"]
    (filter (== "duplicate variable pc") (modelProblems malformed))

transitionRows :: [TransitionRow]
transitionRows =
  [ row "idle,idle" "Request" "p0" "want,idle"
  , row "idle,idle" "Request" "p1" "idle,want"
  , row "want,idle" "Enter" "p0" "critical,idle"
  , row "idle,want" "Enter" "p1" "idle,critical"
  , row "critical,idle" "Exit" "p0" "idle,idle"
  , row "idle,critical" "Exit" "p1" "idle,idle"
  , row "want,want" "Enter" "p0" "critical,want"
  , row "want,want" "Enter" "p1" "want,critical"
  ]
 where
  row from action process to = TransitionRow from (Event action [AtomValue process]) to

checkTransitions :: IO ()
checkTransitions = do
  forM_ transitionRows $ \(TransitionRow from event expected) -> do
    state <- stateFromPair from
    actual <- maybe (failWith "hand-transition" (show event <> " disabled")) pure
      (interpret toyModel event state)
    assertEqual "hand-transition" expected (statePair actual)
  idle <- stateFromPair "idle,idle"
  assertEqual "disabled-transition" Nothing
    (interpret toyModel (Event "Enter" [AtomValue "p0"]) idle)

invariantRows :: [InvariantRow]
invariantRows =
  [ InvariantRow "idle" "idle" "idle" "idle" 0 True
  , InvariantRow "want" "idle" "want" "idle" 0 True
  , InvariantRow "critical" "idle" "critical" "idle" 1 True
  , InvariantRow "critical" "critical" "critical" "critical" 1 False
  , InvariantRow "want" "idle" "idle" "idle" 0 False
  , InvariantRow "idle" "idle" "idle" "idle" (-1) False
  , InvariantRow "idle" "idle" "idle" "idle" 2 False
  , InvariantRow "critical" "idle" "critical" "idle" 0 False
  ]

checkInvariantRows :: IO ()
checkInvariantRows = forM_ invariantRows $ \fixture@(InvariantRow _ _ _ _ _ expected) -> do
  actual <- invariantOutcome toyModel fixture
  assertEqual "invariant-truth-table" expected actual

invariantOutcome :: Model -> InvariantRow -> IO Bool
invariantOutcome model fixture = case modelInvariants model of
  invariant : _ -> requireRight "invariant-evaluation"
    (evalExpr model Map.empty (invariantState fixture) (namedExprBody invariant) >>= valueAsBool)
  [] -> failWith "invariant-evaluation" "model has no invariant"

invariantState :: InvariantRow -> State
invariantState (InvariantRow pc0 pc1 mirror0 mirror1 count _) = Map.fromList
  [("pc", function pc0 pc1), ("mirror", function mirror0 mirror1), ("criticalCount", IntValue count)]

stateFromPair :: String -> IO State
stateFromPair encoded = case splitOn ',' encoded of
  [left, right] -> pure (Map.fromList
    [ ("pc", function left right), ("mirror", function left right)
    , ("criticalCount", IntValue (if "critical" `elem` [left, right] then 1 else 0)) ])
  _ -> failWith "state-pair" encoded

function :: String -> String -> Value
function left right = FunctionValue
  [(AtomValue "p0", AtomValue left), (AtomValue "p1", AtomValue right)]

statePair :: State -> String
statePair state = case Map.lookup "pc" state of
  Just (FunctionValue pairs) -> intercalate "," [atomAt "p0" pairs, atomAt "p1" pairs]
  value -> "<invalid:" <> show value <> ">"
 where
  atomAt name pairs = case lookup (AtomValue name) pairs of
    Just (AtomValue value) -> value
    value -> "<invalid:" <> show value <> ">"

expectedToyFingerprints :: Set String
expectedToyFingerprints = Set.fromList (map fingerprint states)
 where
  states =
    [ ("idle", "idle"), ("want", "idle"), ("idle", "want"), ("want", "want")
    , ("critical", "idle"), ("idle", "critical"), ("critical", "want"), ("want", "critical") ]
  fingerprint (left, right) = canonicalFingerprint toyModel (Map.fromList
    [ ("pc", function left right), ("mirror", function left right)
    , ("criticalCount", IntValue (if "critical" `elem` [left, right] then 1 else 0)) ])

requiredConstructors :: Set String
requiredConstructors = Set.fromList
  [ "BoolLiteral", "ArithmeticComparison", "FiniteSetMembership", "FiniteQuantifier"
  , "FunctionLiteral", "FunctionUpdate", "FunctionApplication", "WeakFair", "StrongFair"
  , "Always", "Eventually", "LeadsTo" ]

constructorSet :: Model -> Set String
constructorSet model = Set.unions
  [ Set.unions [exprConstructors expression | (_, expression) <- modelInit model]
  , Set.unions
      [ Set.unions (exprConstructors (actionGuard action)
          : [exprConstructors (parameterDomain parameter) | parameter <- actionParameters action]
          <> [exprConstructors expression | (_, expression) <- actionEffects action])
      | action <- modelActions model ]
  , Set.unions [exprConstructors (namedExprBody item) | item <- modelInvariants model]
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
    Not value -> ("Boolean", exprConstructors value)
    And values -> ("Boolean", Set.unions (map exprConstructors values))
    Or values -> ("Boolean", Set.unions (map exprConstructors values))
    Implies left right -> ("Implication", both left right)
    Equal left right -> ("Boolean", both left right)
    NotEqual left right -> ("Boolean", both left right)
    ArithmeticComparison _ left right -> ("ArithmeticComparison", both left right)
    Add left right -> ("Arithmetic", both left right)
    Subtract left right -> ("Subtraction", both left right)
    FiniteSet values -> ("FiniteSet", Set.unions (map exprConstructors values))
    SetUnion left right -> ("SetUnion", both left right)
    SetDifference left right -> ("SetDifference", both left right)
    Cardinality value -> ("Cardinality", exprConstructors value)
    FiniteSetMembership left right -> ("FiniteSetMembership", both left right)
    FiniteQuantifier _ _ domain predicate -> ("FiniteQuantifier", both domain predicate)
    FunctionLiteral _ domain body -> ("FunctionLiteral", both domain body)
    FunctionUpdate target key value -> ("FunctionUpdate", Set.unions (map exprConstructors [target, key, value]))
    FunctionApplication target key -> ("FunctionApplication", both target key)
    IfThenElse condition yes no -> ("Conditional", Set.unions (map exprConstructors [condition, yes, no]))
  both left right = Set.union (exprConstructors left) (exprConstructors right)

temporalConstructors :: Temporal -> Set String
temporalConstructors temporal = case temporal of
  Always expression -> Set.insert "Always" (exprConstructors expression)
  Eventually expression -> Set.insert "Eventually" (exprConstructors expression)
  LeadsTo left right -> Set.insert "LeadsTo" (Set.union (exprConstructors left) (exprConstructors right))

expectedRendererFacts :: Set RendererFact
expectedRendererFacts = Set.fromList
  [ ("module", "ToyModel", "present"), ("generated-stamp", "amoebius-dev-model", "stable")
  , ("extension", "Integers", "present"), ("extension", "FiniteSets", "present"), ("extension", "TLC", "present")
  , ("constant", "Proc", "present"), ("variable", "pc", "present"), ("variable", "mirror", "present")
  , ("variable", "criticalCount", "present"), ("initial-assignment", "pc", "present")
  , ("initial-assignment", "mirror", "present"), ("initial-assignment", "criticalCount", "present")
  , ("action", "Request", "present"), ("action", "Enter", "present"), ("action", "Exit", "present")
  , ("fairness", "Request", "weak"), ("fairness", "Enter", "strong"), ("fairness", "Exit", "weak")
  , ("invariant", "MutualExclusion", "present"), ("constraint", "StateBound", "present")
  , ("property", "EveryRequestEventuallyExits", "leads-to")
  , ("property", "AlwaysMutualExclusion", "always"), ("property", "SomeProcessEventuallyCritical", "eventually")
  , ("specification", "Spec", "present"), ("check-deadlock", "value", "false") ]

expectedProperties :: Set String
expectedProperties = Set.fromList
  ["EveryRequestEventuallyExits", "AlwaysMutualExclusion", "SomeProcessEventuallyCritical"]

renderedSemanticFacts :: (Tla, Cfg) -> Set RendererFact
renderedSemanticFacts (Tla tla, Cfg cfg) = Set.fromList . concat $
  [ maybe [] (\name -> [("module", name, "present")]) (moduleName tla)
  , [("generated-stamp", "amoebius-dev-model", "stable") | any ("\\* GENERATED by amoebius dev model" `isPrefixOf`) (lines tla)]
  , namedList "extension" "EXTENDS " tla, namedList "constant" "CONSTANTS " tla
  , namedList "variable" "VARIABLES " tla
  , [("initial-assignment", name, "present") | name <- initAssignments tla]
  , [("action", name, "present") | name <- actionDefinitions tla]
  , fairnessFacts "WF_vars(" "weak" tla, fairnessFacts "SF_vars(" "strong" tla
  , [("invariant", name, "present") | name <- Set.toList (cfgNames "INVARIANT " cfg)]
  , [("constraint", name, "present") | name <- Set.toList (cfgNames "CONSTRAINT " cfg)]
  , propertyFacts tla
  , [("specification", name, "present") | name <- Set.toList (cfgNames "SPECIFICATION " cfg)]
  , [("check-deadlock", "value", asciiLower value) | value <- Set.toList (cfgNames "CHECK_DEADLOCK " cfg)] ]
 where
  moduleName contents = do
    line <- find ("---- MODULE " `isPrefixOf`) (lines contents)
    pure (takeWhile (/= ' ') (drop 12 line))
  namedList kind prefix contents =
    [(kind, trim name, "present") | line <- lines contents, prefix `isPrefixOf` line, name <- splitOn ',' (drop (length prefix) line)]
  initAssignments contents =
    [ trim name
    | line <- takeWhile (not . null) (drop 1 (dropWhile (/= "Init ==") (lines contents)))
    , let body = fromMaybe line (stripAfter "/\\ " line)
    , let (name, separator) = breakOn " = " body
    , not (null separator) ]
  actionDefinitions contents = [takeWhile (/= '(') line | line <- lines contents, ") ==" `isSuffixOf` line]
  fairnessFacts marker kind contents =
    [("fairness", takeWhile (/= '(') rest, kind) | line <- lines contents, Just rest <- [stripAfter marker line]]
  propertyFacts contents =
    [("property", trim name, temporalKind rhs)
    | line <- lines contents
    , let (name, separator) = breakOn " == " line
    , not (null separator)
    , let rhs = trim (drop 4 separator)
    , " ~> " `isInfixOf` rhs || "[](" `isPrefixOf` rhs || "<>" `isPrefixOf` rhs ]
  temporalKind rhs | " ~> " `isInfixOf` rhs = "leads-to"
                   | "[](" `isPrefixOf` rhs = "always"
                   | otherwise = "eventually"

cfgNames :: String -> String -> Set String
cfgNames prefix = Set.fromList . map (drop (length prefix)) . filter (prefix `isPrefixOf`) . lines

checkComposition :: FilePath -> IO ()
checkComposition output = do
  result <- withReferenceComposition $ \composition -> do
    let model = compositionModel composition
        resources = compositionResource composition
        kinds = intercalate "," (map (Text.unpack . calculusTag) (compositionKinds composition))
        expected = Map.fromList
          [ ("calculus-kinds", "artifact,budget,lift,workflow,evidence"), ("component-count", "5")
          , ("cpu", "15"), ("memory", "150"), ("ephemeral", "1500"), ("pods", "15")
          , ("formal-distinct-state-count", "1"), ("formal-safety", "green") ]
    explored <- requireRight "composition-explorer" (explore model)
    let actual = Map.fromList
          [ ("calculus-kinds", kinds), ("component-count", show (length (compositionKinds composition)))
          , ("cpu", show (resourceCpu resources)), ("memory", show (resourceMemory resources))
          , ("ephemeral", show (resourceEphemeralStorage resources)), ("pods", show (resourcePodSlots resources))
          , ("formal-distinct-state-count", show (Map.size (exploreStates explored)))
          , ("formal-safety", if exploreViolation explored == Nothing then "green" else "red") ]
        (Tla tla, Cfg cfg) = emitTLA model
    assertEqual "composition-projection" expected actual
    writeFile (output </> "CalculusComposition.tla") tla
    writeFile (output </> "CalculusComposition.cfg") cfg
  case result of
    Left problem -> failWith "composition-scope" problem
    Right () -> pure ()

withReferenceComposition :: (forall scope. Composition scope -> IO result) -> IO (Either String result)
withReferenceComposition continuation = case trustedTenant "phase-11-tenant" of
  Left problem -> pure (Left (show problem))
  Right tenant -> case trustedSubject tenant "phase-11-subject" of
    Left problem -> pure (Left (show problem))
    Right subject -> case activeMembership tenant subject of
      Left problem -> pure (Left (show problem))
      Right membership -> case withRequestScope tenant subject membership (continuation . referenceComposition) of
        Left problem -> pure (Left (show problem))
        Right action -> Right <$> action

referenceComposition :: RequestScope scope -> Composition scope
referenceComposition scope = append (append (compose artifact budget) (compose lift workflow)) (singleton evidence)
 where
  artifact = artifactComponent scope "artifact" (resource 1 10 100 1) (RecipeId "formal-artifact" 1)
  budget = budgetComponent scope "budget" (resource 2 20 200 2) (allowance (Bytes 4096) (Slots 4) (Bytes 1024))
  lift = liftComponent scope "lift" (resource 3 30 300 3) OnHost
  workflow = workflowComponent scope "workflow" (resource 4 40 400 4) emptyLedger
  evidence = evidenceComponent scope "evidence" (resource 5 50 500 5) PureRegister
  resource = ResourceVector

checkGeneratedCorpus :: IO ()
checkGeneratedCorpus = forM_ [0 .. 199] $ \seed -> do
  let model = generatedModel seed
      expectedStates = 2 * (limitFor seed + 1)
      expectedViolation = odd seed
      (Tla tla, Cfg cfg) = emitTLA model
  assertEqual "generated-model-problems" [] (modelProblems model)
  result <- requireRight "generated-explorer" (explore model)
  assertEqual "generated-state-count" expectedStates (Map.size (exploreStates result))
  assertEqual "generated-boundary-count" 2 (Set.size (exploreBoundaryStates result))
  assertEqual "generated-safety" expectedViolation (exploreViolation result /= Nothing)
  assert ("Advance ==" `isInfixOf` tla && "INVARIANT Safe" `isInfixOf` cfg) "generated-renderer"

limitFor :: Int -> Int
limitFor seed = 2 + abs seed `mod` 2

generatedModel :: Int -> Model
generatedModel seed = Model
  { modelName = "Generated" <> show seed, modelConstants = [], modelVariables = ["x", "y"]
  , modelInit = [("x", int 0), ("y", bool False)]
  , modelActions =
      [ Action "Advance" [] (ArithmeticComparison LessThan (Ref "x") (int limit)) [("x", Add (Ref "x") (int 1))]
      , Action "Flip" [] (bool True) [("y", Not (Ref "y"))] ]
  , modelInvariants = [NamedExpr "Safe" comparison]
  , modelConstraint = Just (NamedExpr "StateBound" (And
      [ FiniteSetMembership (Ref "x") (FiniteSet [int value | value <- [0 .. limit]])
      , FiniteSetMembership (Ref "y") (FiniteSet [bool False, bool True]) ]))
  , modelExpansionLimit = Just (ArithmeticComparison LessThan (Ref "x") (int limit))
  , modelFairness = [Fairness WeakFair "Advance", Fairness StrongFair "Flip"]
  , modelProperties = [Property "EventuallyDone" (Eventually (Equal (Ref "x") (int limit)))]
  , modelCheckDeadlock = False }
 where
  limit = limitFor seed
  comparison = ArithmeticComparison (if odd seed then LessThan else LessThanOrEqual) (Ref "x") (int limit)
  int = Literal . IntValue . fromIntegral
  bool = Literal . BoolValue

stripAfter :: String -> String -> Maybe String
stripAfter needle haystack = case find (needle `isPrefixOf`) (tails haystack) of
  Nothing -> Nothing
  Just match -> Just (drop (length needle) match)

breakOn :: String -> String -> (String, String)
breakOn needle haystack = case go 0 haystack of
  Nothing -> (haystack, "")
  Just index -> splitAt index haystack
 where
  go _ [] = Nothing
  go index rest@(_ : remaining)
    | needle `isPrefixOf` rest = Just index
    | otherwise = go (index + 1) remaining

trim :: String -> String
trim = reverse . dropWhile (== ' ') . reverse . dropWhile (== ' ')

splitOn :: Char -> String -> [String]
splitOn delimiter text = case break (== delimiter) text of
  (piece, []) -> [piece]
  (piece, _ : rest) -> piece : splitOn delimiter rest

asciiLower :: String -> String
asciiLower = map lower
 where
  lower character | character >= 'A' && character <= 'Z' = toEnum (fromEnum character + 32)
                  | otherwise = character
