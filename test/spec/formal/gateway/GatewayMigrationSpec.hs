module Main (main) where

import Amoebius.Formal.EmitTLA
import Amoebius.Formal.Explore
import Amoebius.Formal.GatewayMigration
import Amoebius.Formal.Interpret
import Amoebius.Formal.Model
import Amoebius.Multicluster.StructuralFit
import Control.Concurrent.Class.MonadSTM
  ( atomically
  , modifyTVar'
  , newTVarIO
  , readTVarIO
  )
import Control.Monad (forM, forM_, unless)
import Control.Monad.Class.MonadAsync (async, wait)
import Control.Monad.Class.MonadTest (exploreRaces)
import Control.Monad.IOSim
  ( IOSim
  , exploreSimTrace
  , traceResult
  , withBranching
  , withScheduleBound
  )
import Data.Char (isDigit, isSpace)
import Data.List (find, intercalate, isInfixOf, isPrefixOf, nub, sort, tails)
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
  , counterexample
  , cover
  , elements
  , isSuccess
  , property
  , quickCheckWithResult
  , stdArgs
  )
import Test.QuickCheck.Random (mkQCGen)
import qualified Test.QuickCheck as QC

iosimporScheduleBound :: Int
iosimporScheduleBound = 20

data TlcResult = TlcResult
  { tlcExit :: ExitCode
  , tlcOutput :: String
  , tlcFingerprints :: Set String
  , tlcDistinctCount :: Maybe Int
  }

data CutoffCase = CutoffCase
  { cutoffName :: String
  , cutoffAccept :: Bool
  , cutoffClause :: Maybe FitClause
  , cutoffEdges :: [MigrationEdge]
  }
  deriving stock (Show)

newtype GeneratedGraph = GeneratedGraph [MigrationEdge]
  deriving stock (Show)

instance Arbitrary GeneratedGraph where
  arbitrary = GeneratedGraph <$> elements scenarioGraphs
  shrink _ = []

main :: IO ()
main = do
  root <- getCurrentDirectory >>= canonicalizePath
  java <- resolveTool root "AMOEBIUS_JAVA" ".build/toolchain/runtime/java/bin/java"
  jar <- resolveTool root "AMOEBIUS_TLA2TOOLS" ".build/toolchain/runtime/tla/tla2tools.jar"
  let output = root </> ".build/tla/gateway-migration-model-spec"
  createDirectoryIfMissing True output

  putStrLn "gateway-migration-model-spec: pinned contract and reachability"
  assertEqual "GatewayMigration structural well-formedness" [] (modelProblems gatewayMigrationModel)
  checkContract root
  explorer <- requireRight "GatewayMigration explorer" (explore gatewayMigrationModel)
  assertEqual "GatewayMigration distinct-state oracle" 53 (Map.size (exploreStates explorer))
  assertEqual "GatewayMigration explorer safety" Nothing (exploreViolation explorer)
  checkReachability explorer
  checkGolden root

  putStrLn "gateway-migration-model-spec: TLC safety and liveness"
  safetyTlc <- runTlc java jar output "safety" True safetyModel
  assertTlcGreen "GatewayMigration safety" safetyTlc
  assertEqual "GatewayMigration TLC distinct states" (Just 53) (tlcDistinctCount safetyTlc)
  assertEqual "GatewayMigration explorer/TLC fingerprints"
    (Map.keysSet (exploreStates explorer)) (tlcFingerprints safetyTlc)
  livenessTlc <- runTlc java jar output "liveness" False livenessModel
  assertTlcGreen "GatewayMigration liveness" livenessTlc
  fairnessDrops <- checkFairnessSensitivity java jar output

  putStrLn "gateway-migration-model-spec: per-invariant and mechanical mutants"
  let invariantMutants = seededInvariantMutants
  checkMutantOracle root invariantMutants
  forM_ invariantMutants $ \(name, expected, mutant) -> do
    violations <- requireRight (name <> " explorer violations") (allViolations mutant)
    assertEqual (name <> " exact invariant") (Set.singleton expected) violations
    mutantTlc <- runTlc java jar output ("mutant-" <> name) False (safetyOnly mutant)
    assertTlcRed (name <> " TLC") mutantTlc
  forM_ mechanicalSafetyMutants $ \(name, mutant) -> do
    violations <- requireRight (name <> " explorer violations") (allViolations mutant)
    assert (not (Set.null violations)) (name <> " survived explorer")
    mutantTlc <- runTlc java jar output ("operator-" <> name) False (safetyOnly mutant)
    assertTlcRed (name <> " TLC") mutantTlc
  checkInvariantDelete root

  putStrLn "gateway-migration-model-spec: IOSimPOR bounded schedule agreement"
  iosimAgreement <- checkIOSimPOR explorer invariantMutants

  putStrLn "gateway-migration-model-spec: StructuralFit cutoff"
  cutoffCases <- readCutoffCases root
  checkCutoffCorpus cutoffCases
  cutoffMutants <- checkCutoffMutants root cutoffCases
  checkCutoffQuickCheck
  checkCutoffTotality

  putStrLn "gateway-migration-model-spec: scope-3 shared-resource stress"
  stressExplorer <- requireRight "shared-resource stress explorer" (explore sharedResourceModel)
  assertEqual "shared-resource correct safety" Nothing (exploreViolation stressExplorer)
  checkAllActionsLive sharedResourceModel stressExplorer
  stressTlc <- runTlc java jar output "scope3-shared-resource" False sharedResourceModel
  assertTlcGreen "shared-resource correct TLC" stressTlc
  stressMutantExplorer <- requireRight "shared-resource mutant explorer" (explore sharedResourceMutant)
  assert (exploreViolation stressMutantExplorer /= Nothing) "shared-resource mutant survived explorer"
  stressMutantTlc <- runTlc java jar output "scope3-shared-resource-mutant" False sharedResourceMutant
  assertTlcRed "shared-resource mutant TLC" stressMutantTlc

  writeResults output safetyTlc fairnessDrops iosimAgreement cutoffMutants
  putStrLn "gateway-migration-model-spec: PASS"

safetyModel :: Model
safetyModel = gatewayMigrationModel {modelFairness = [], modelProperties = []}

livenessModel :: Model
livenessModel = gatewayMigrationModel {modelConstraint = Nothing}

safetyOnly :: Model -> Model
safetyOnly model = model {modelFairness = [], modelProperties = []}

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

checkContract :: FilePath -> IO ()
checkContract root = do
  rows <- readTsv (root </> "test/oracle/formal/gateway/model_contract.tsv")
  let constants = [(name, value) | ["constant", name, value] <- rows]
      actions = [name | ["action", name, _] <- rows]
      invariants = [name | ["invariant", name, _] <- rows]
      properties = [name | ["property", name, _] <- rows]
      actualConstants = [(name, contractValue value) | (name, value) <- modelConstants gatewayMigrationModel]
  assertEqual "contract constants" constants actualConstants
  assertEqual "contract actions" actions (map actionName (modelActions gatewayMigrationModel))
  assertEqual "contract invariants" invariants (map namedExprName (modelInvariants gatewayMigrationModel))
  assertEqual "contract properties" properties (map propertyName (modelProperties gatewayMigrationModel))
  where
    contractValue value = case value of
      SetValue values -> "{" <> intercalate "," (map renderContractAtom (sort values)) <> "}"
      IntValue integer -> show integer
      other -> show other
    renderContractAtom (AtomValue value) = show value
    renderContractAtom other = show other

checkReachability :: ExploreResult -> IO ()
checkReachability explorer = do
  let states = Map.elems (exploreStates explorer)
      enabled = Set.fromList [eventAction event | state <- states, event <- enabledEvents gatewayMigrationModel state]
      branch value = any ((== Just (AtomValue value)) . Map.lookup "branch") states
      plannedPromoted state = atomAt "branch" state == Just "planned" && boolAt "targetOwns" state
      failoverPromoted state = atomAt "branch" state == Just "failover" && boolAt "targetOwns" state
      coldSeedTake state = failoverPromoted state && boolAt "coldSeeded" state && boolAt "freshnessWitness" state
  assert (branch "planned") "planned branch is unreachable"
  assert (branch "failover") "failover branch is unreachable"
  assertEqual "no dead action" (Set.fromList gatewayActionNames) enabled
  assert (any plannedPromoted states) "PlannedIsLossless antecedent is unreachable"
  assert (any failoverPromoted states) "NoWriteAfterStaleFailover antecedent is unreachable"
  assert (any coldSeedTake states) "NoTakeWithoutProvenFreshness cold-seed antecedent is unreachable"

checkAllActionsLive :: Model -> ExploreResult -> IO ()
checkAllActionsLive model explorer =
  assertEqual (modelName model <> " no dead action")
    (Set.fromList (map actionName (modelActions model)))
    (Set.fromList [eventAction event | state <- Map.elems (exploreStates explorer), event <- enabledEvents model state])

atomAt :: Name -> State -> Maybe String
atomAt name state = case Map.lookup name state of
  Just (AtomValue value) -> Just value
  _ -> Nothing

boolAt :: Name -> State -> Bool
boolAt name state = Map.lookup name state == Just (BoolValue True)

checkGolden :: FilePath -> IO ()
checkGolden root = do
  expectedTla <- readFile (root </> "test/golden/formal/gateway/GatewayMigration.tla.golden")
  expectedCfg <- readFile (root </> "test/golden/formal/gateway/GatewayMigration.cfg.golden")
  let (Tla actualTla, Cfg actualCfg) = emitTLA gatewayMigrationModel
  assertEqual "GatewayMigration TLA byte golden" expectedTla actualTla
  assertEqual "GatewayMigration CFG byte golden" expectedCfg actualCfg

runTlc :: FilePath -> FilePath -> FilePath -> String -> Bool -> Model -> IO TlcResult
runTlc java jar output suffix dumpStates model = do
  let directory = output </> suffix
      tlaPath = directory </> modelName model <> ".tla"
      cfgPath = directory </> modelName model <> ".cfg"
      dotPath = directory </> modelName model <> ".dot"
      (Tla tla, Cfg cfg) = emitTLA model
      dumpArgs = if dumpStates then ["-dump", "dot,actionlabels", dotPath] else []
  createDirectoryIfMissing True directory
  writeFile tlaPath tla
  writeFile cfgPath cfg
  (exitCode, stdoutText, stderrText) <- readProcessWithExitCode java
    ([ "-XX:+UseParallelGC", "-jar", jar, "-workers", "1", "-cleanup", "-nowarning"
     , "-fp", "0", "-seed", "1"
     ] <> dumpArgs <> ["-config", cfgPath, tlaPath]) ""
  let outputText = stdoutText <> stderrText
  writeFile (directory </> modelName model <> ".tlc.log") outputText
  dot <- if dumpStates then readFileIfPresent dotPath else pure ""
  pure TlcResult
    { tlcExit = exitCode
    , tlcOutput = outputText
    , tlcFingerprints = parseDotFingerprints model dot
    , tlcDistinctCount = parseDistinctCount outputText
    }

assertTlcGreen :: String -> TlcResult -> IO ()
assertTlcGreen label result =
  assert (tlcExit result == ExitSuccess) (label <> " failed:\n" <> tlcOutput result)

assertTlcRed :: String -> TlcResult -> IO ()
assertTlcRed label result =
  assert (tlcExit result /= ExitSuccess) (label <> " unexpectedly passed")

checkFairnessSensitivity :: FilePath -> FilePath -> FilePath -> IO Int
checkFairnessSensitivity java jar output = do
  results <- forM (modelProperties gatewayMigrationModel) $ \namedProperty -> do
    let mutant = gatewayMigrationModel
          { modelConstraint = Nothing
          , modelFairness = []
          , modelProperties = [namedProperty]
          }
    result <- runTlc java jar output ("fairness-drop-" <> propertyName namedProperty) False mutant
    assertTlcRed (propertyName namedProperty <> " without fairness") result
    pure True
  pure (length (filter id results))

seededInvariantMutants :: [(String, Name, Model)]
seededInvariantMutants =
  [ ("dual-owner-promote", "UniqueGatewayOwner", mapNamedAction "PromotePlanned" dropSourceFence gatewayMigrationModel)
  , ("drop-last-endpoint", "SessionAlwaysRebindable", mapNamedAction "ActiveCrash" dropEndpoint gatewayMigrationModel)
  , ("verify-while-offsets-lag", "PlannedIsLossless", laggingVerification gatewayMigrationModel)
  , ("over-budget-divergence", "NoWriteAfterStaleFailover", mapNamedAction "PromoteSurvivor" overBudget gatewayMigrationModel)
  , ("take-without-witness", "NoTakeWithoutProvenFreshness", takeWithoutWitness gatewayMigrationModel)
  ]
  where
    dropSourceFence action = action {actionEffects = filter ((/= "sourceOwns") . fst) (actionEffects action)}
    dropEndpoint action = action {actionEffects = replaceEffect "targetUp" (Literal (BoolValue False)) (actionEffects action)}
    overBudget action = action {actionEffects = replaceEffect "divergence" (Literal (IntValue 2)) (actionEffects action)}

mechanicalSafetyMutants :: [(String, Model)]
mechanicalSafetyMutants =
  [ ("guard-negation", mapNamedAction "PromoteSurvivor" (\action -> action {actionGuard = Not (actionGuard action)}) gatewayMigrationModel)
  , ("guard-weakening", mapNamedAction "PromotePlanned" (\action -> action {actionGuard = Literal (BoolValue True)}) gatewayMigrationModel)
  , ("effect-swap", swapInitial "targetOwns" "targetUp" gatewayMigrationModel)
  , ("drop-effect", mapNamedAction "PromotePlanned" (\action -> action {actionEffects = filter ((/= "sourceOwns") . fst) (actionEffects action)}) gatewayMigrationModel)
  , ("quantifier-flip", mapNamedAction "PromotePlanned" (\action -> action {actionGuard = flipQuantifiers (actionGuard action)}) gatewayMigrationModel)
  ]

mapNamedAction :: Name -> (Action -> Action) -> Model -> Model
mapNamedAction name mutate model = model
  {modelActions = [if actionName action == name then mutate action else action | action <- modelActions model]}

replaceEffect :: Name -> Expr -> [(Name, Expr)] -> [(Name, Expr)]
replaceEffect name expression effects = (name, expression) : filter ((/= name) . fst) effects

removeConjunct :: Expr -> Expr -> Expr
removeConjunct target expression = case expression of
  And expressions -> And (filter (/= target) expressions)
  other -> other

laggingVerification :: Model -> Model
laggingVerification =
  mapNamedAction "VerifyCaughtUp" dropEquality . mapNamedAction "StartPlanned" dropEquality
  where
    equality = Equal (Ref "targetLog") (Ref "committed")
    dropEquality action = action {actionGuard = removeConjunct equality (actionGuard action)}

takeWithoutWitness :: Model -> Model
takeWithoutWitness =
  mapNamedAction "PromoteSurvivor" dropGuard . mapNamedAction "ColdSeed" dropWitness
  where
    dropWitness action = action {actionEffects = filter ((/= "freshnessWitness") . fst) (actionEffects action)}
    dropGuard action = action {actionGuard = removeConjunct (Ref "freshnessWitness") (actionGuard action)}

swapInitial :: Name -> Name -> Model -> Model
swapInitial left right model = model {modelInit = map swap (modelInit model)}
  where
    leftValue = lookup left (modelInit model)
    rightValue = lookup right (modelInit model)
    swap (name, expression)
      | name == left = (name, fromMaybe expression rightValue)
      | name == right = (name, fromMaybe expression leftValue)
      | otherwise = (name, expression)

flipQuantifiers :: Expr -> Expr
flipQuantifiers expression = case expression of
  FiniteQuantifier ForAll binder domain predicate ->
    FiniteQuantifier Exists binder (flipQuantifiers domain) (flipQuantifiers predicate)
  FiniteQuantifier Exists binder domain predicate ->
    FiniteQuantifier ForAll binder (flipQuantifiers domain) (flipQuantifiers predicate)
  Not expr -> Not (flipQuantifiers expr)
  And exprs -> And (map flipQuantifiers exprs)
  Or exprs -> Or (map flipQuantifiers exprs)
  Implies left right -> Implies (flipQuantifiers left) (flipQuantifiers right)
  Equal left right -> Equal (flipQuantifiers left) (flipQuantifiers right)
  NotEqual left right -> NotEqual (flipQuantifiers left) (flipQuantifiers right)
  ArithmeticComparison comparison left right -> ArithmeticComparison comparison (flipQuantifiers left) (flipQuantifiers right)
  Add left right -> Add (flipQuantifiers left) (flipQuantifiers right)
  Subtract left right -> Subtract (flipQuantifiers left) (flipQuantifiers right)
  FiniteSet exprs -> FiniteSet (map flipQuantifiers exprs)
  SetUnion left right -> SetUnion (flipQuantifiers left) (flipQuantifiers right)
  SetDifference left right -> SetDifference (flipQuantifiers left) (flipQuantifiers right)
  Cardinality expr -> Cardinality (flipQuantifiers expr)
  FiniteSetMembership left right -> FiniteSetMembership (flipQuantifiers left) (flipQuantifiers right)
  FunctionLiteral binder domain body -> FunctionLiteral binder (flipQuantifiers domain) (flipQuantifiers body)
  FunctionUpdate function key value -> FunctionUpdate (flipQuantifiers function) (flipQuantifiers key) (flipQuantifiers value)
  FunctionApplication function key -> FunctionApplication (flipQuantifiers function) (flipQuantifiers key)
  IfThenElse condition yes no -> IfThenElse (flipQuantifiers condition) (flipQuantifiers yes) (flipQuantifiers no)
  other -> other

allViolations :: Model -> Either String (Set Name)
allViolations model = do
  result <- explore model
  Set.fromList . concat <$> traverse violatedInState (Map.elems (exploreStates result))
  where
    violatedInState state = fmap concat . forM (modelInvariants model) $ \invariant -> do
      valid <- evalExpr model Map.empty state (namedExprBody invariant) >>= valueAsBool
      pure [namedExprName invariant | not valid]

checkMutantOracle :: FilePath -> [(String, Name, Model)] -> IO ()
checkMutantOracle root mutants = do
  rows <- readTsv (root </> "test/oracle/formal/gateway/invariant_mutants.tsv")
  let expected = [(name, invariant) | [name, invariant, "green"] <- rows]
  assertEqual "per-invariant mutant oracle" expected [(name, invariant) | (name, invariant, _) <- mutants]

checkInvariantDelete :: FilePath -> IO ()
checkInvariantDelete root = do
  rows <- readTsv (root </> "test/oracle/formal/gateway/model_contract.tsv")
  let required = Set.fromList [name | ["invariant", name, _] <- rows]
      mutant = gatewayMigrationModel {modelInvariants = drop 1 (modelInvariants gatewayMigrationModel)}
      actual = Set.fromList (map namedExprName (modelInvariants mutant))
      (Tla correctTla, Cfg correctCfg) = emitTLA gatewayMigrationModel
      (Tla mutantTla, Cfg mutantCfg) = emitTLA mutant
  assert (required /= actual) "invariant-delete mutant survived obligation oracle"
  assert (correctTla /= mutantTla && correctCfg /= mutantCfg) "invariant-delete mutant survived byte golden"

checkIOSimPOR :: ExploreResult -> [(String, Name, Model)] -> IO Bool
checkIOSimPOR correctExplorer mutants = do
  mutantExplorers <- forM mutants $ \(name, _, model) -> do
    result <- requireRight (name <> " IOSimPOR state source") (explore model)
    pure (name, model, Map.elems (exploreStates result), False)
  let subjects = ("correct", gatewayMigrationModel, Map.elems (exploreStates correctExplorer), True) : mutantExplorers
      callback _ trace = case traceResult False trace of
        Left failure -> counterexample (show failure) False
        Right outcomes -> counterexample (show outcomes) (property (and outcomes))
      options = withBranching 4 . withScheduleBound iosimporScheduleBound
      args = stdArgs {maxSuccess = 1, replay = Just (mkQCGen 20260809, 0), chatty = True}
  result <- quickCheckWithResult args (exploreSimTrace options (simulateSubjects subjects) callback)
  assert (isSuccess result) "IOSimPOR agreement failed"
  pure True

simulateSubjects :: [(String, Model, [State], Bool)] -> IOSim s [Bool]
simulateSubjects subjects = forM subjects $ \(_, model, states, expectedSafe) -> do
  outcomes <- forM states (simulateState model)
  pure (and outcomes == expectedSafe)

simulateState :: Model -> State -> IOSim s Bool
simulateState model initial = do
  cell <- newTVarIO initial
  exploreRaces
  workers <- forM (enabledEvents model initial) $ \event -> async $ atomically $
    modifyTVar' cell (\state -> fromMaybe state (interpret model event state))
  mapM_ wait workers
  final <- readTVarIO cell
  pure (stateSafe model initial && stateSafe model final)

stateSafe :: Model -> State -> Bool
stateSafe model state = all invariantHolds (modelInvariants model)
  where
    invariantHolds invariant =
      (evalExpr model Map.empty state (namedExprBody invariant) >>= valueAsBool) == Right True

readCutoffCases :: FilePath -> IO [CutoffCase]
readCutoffCases root = do
  rows <- readTsv (root </> "test/oracle/formal/gateway/cutoff_cases.tsv")
  forM rows $ \row -> case row of
    [name, expected, clause, active, standby, dns, budget, ttl, freshness, offset] -> do
      let columns = map (splitOn ':') [active, standby, dns, budget, ttl, freshness, offset]
      case columns of
        [actives, standbys, records, budgets, ttls, fresh, offsets]
          | all ((== length actives) . length) [standbys, records, budgets, ttls, fresh, offsets] ->
              pure CutoffCase
                { cutoffName = name
                , cutoffAccept = expected == "accept"
                , cutoffClause = clauseFromText clause
                , cutoffEdges = zipWith7 edgeFromText actives standbys records budgets ttls fresh offsets
                }
        _ -> fail ("malformed cutoff row " <> show row)
    _ -> fail ("malformed cutoff row " <> show row)
  where
    edgeFromText active standby dns budget ttl freshness offset = MigrationEdge
      active standby dns (read budget) (read ttl) (read freshness) (read offset)

checkCutoffCorpus :: [CutoffCase] -> IO ()
checkCutoffCorpus cases = forM_ cases $ \cutoffCase -> do
  let actual = structuralFit (cutoffEdges cutoffCase)
  if cutoffAccept cutoffCase
    then assertEqual (cutoffName cutoffCase) (Right ()) actual
    else case (cutoffClause cutoffCase, actual) of
      (Just expectedClause, Left clauses) ->
        assert (expectedClause `elem` clauses) (cutoffName cutoffCase <> " missing expected clause " <> show expectedClause)
      _ -> assert False (cutoffName cutoffCase <> " unexpectedly accepted")
  assertEqual (cutoffName cutoffCase <> " independent reference") (referenceFit (cutoffEdges cutoffCase)) actual

checkCutoffMutants :: FilePath -> [CutoffCase] -> IO Int
checkCutoffMutants root cases = do
  rows <- readTsv (root </> "test/oracle/formal/gateway/cutoff_mutants.tsv")
  let oracle = [(name, clauseFromText clause) | [name, clause, "red"] <- rows]
  assertEqual "cutoff mutant catalogue size" 8 (length oracle)
  forM_ oracle $ \(name, maybeClause) -> case maybeClause of
    Nothing -> assert False ("unknown cutoff mutant clause " <> name)
    Just clause -> assert
      (any (\cutoffCase -> structuralFitWith (DeleteClause clause) (cutoffEdges cutoffCase)
          /= referenceFit (cutoffEdges cutoffCase)) cases)
      (name <> " survived diagnostic equivalence")
  pure (length oracle)

checkCutoffQuickCheck :: IO ()
checkCutoffQuickCheck = do
  let args = stdArgs {maxSuccess = 500, replay = Just (mkQCGen 20260809, 0), chatty = True}
  result <- quickCheckWithResult args cutoffProperty
  assert (isSuccess result) "StructuralFit equivalence QuickCheck failed"

cutoffProperty :: GeneratedGraph -> QC.Property
cutoffProperty (GeneratedGraph edges) =
  checkCoverage
  . cover 5 (Pairwise `elem` failures) "multi-active"
  . cover 5 (GraphIndependent `elem` failures) "shared-dns"
  . cover 5 (ResourceIndependent `elem` failures) "cluster-reuse"
  . cover 5 (Acyclic `elem` failures) "cyclic"
  . cover 5 (BudgetWithinCap `elem` failures) "over-budget"
  . cover 5 (TtlInRegime `elem` failures) "ttl-out-of-regime"
  . cover 5 (FreshnessInRegime `elem` failures) "freshness-out-of-regime"
  . cover 5 (OffsetDomainWithinConstants `elem` failures) "offset-out-of-regime"
  . cover 5 (length edges > 1) "over-scope-2"
  $ counterexample (show edges) (structuralFit edges == referenceFit edges)
  where
    failures = either id (const []) (referenceFit edges)

checkCutoffTotality :: IO ()
checkCutoffTotality = do
  let args = stdArgs {maxSuccess = 500, replay = Just (mkQCGen 20260810, 0), chatty = False}
      total (GeneratedGraph edges) = property (length (show (structuralFit edges)) >= 2)
  result <- quickCheckWithResult args total
  assert (isSuccess result) "StructuralFit totality property failed"

referenceFit :: [MigrationEdge] -> Either [FitClause] ()
referenceFit edges = case failures of
  [] -> Right ()
  _ -> Left failures
  where
    failures =
      [ clause
      | (clause, holds) <-
          [ (Pairwise, unique (map edgeActive edges))
          , (GraphIndependent, unique (map edgeDnsRecord edges))
          , (ResourceIndependent, independentResources)
          , (Acyclic, acyclic)
          , (BudgetWithinCap, all ((<= 1) . edgeDataLossBudget) edges)
          , (TtlInRegime, all (\edge -> edgeTtl edge >= 1 && edgeTtl edge <= 60) edges)
          , (FreshnessInRegime, all ((<= 1) . edgeFreshnessBound) edges)
          , (OffsetDomainWithinConstants, all ((<= 2) . edgeMaxOffset) edges)
          ]
      , not holds
      ]
    unique values = length values == length (nub values)
    endpoints = concat [[edgeActive edge, edgeStandby edge] | edge <- edges]
    independentResources = all (\edge -> edgeActive edge /= edgeStandby edge) edges && unique endpoints
    vertices = nub endpoints
    edgesFrom vertex = [edgeStandby edge | edge <- edges, edgeActive edge == vertex]
    acyclic = all (not . reachesSelf Set.empty) vertices
    reachesSelf visited origin
      | origin `Set.member` visited = True
      | otherwise = any (reachesSelf (Set.insert origin visited)) (edgesFrom origin)

scenarioGraphs :: [[MigrationEdge]]
scenarioGraphs =
  [ [edge "a" "b" "a.example" 1 30 1 2]
  , [edge "a" "b" "a.example" 1 30 1 2, edge "c" "d" "b.example" 1 30 1 2]
  , [edge "a" "b" "a.example" 1 30 1 2, edge "a" "c" "b.example" 1 30 1 2]
  , [edge "a" "b" "a.example" 1 30 1 2, edge "b" "a" "b.example" 1 30 1 2]
  , [edge "a" "b" "a.example" 1 30 1 2, edge "c" "d" "a.example" 1 30 1 2]
  , [edge "a" "b" "a.example" 1 30 1 2, edge "b" "c" "b.example" 1 30 1 2]
  , [edge "a" "b" "a.example" 2 30 1 2]
  , [edge "a" "b" "a.example" 1 0 1 2]
  , [edge "a" "b" "a.example" 1 30 2 2]
  , [edge "a" "b" "a.example" 1 30 1 3]
  ]
  where
    edge = MigrationEdge

clauseFromText :: String -> Maybe FitClause
clauseFromText text = lookup text
  [ ("pairwise", Pairwise)
  , ("graph-independent", GraphIndependent)
  , ("resource-independent", ResourceIndependent)
  , ("acyclic", Acyclic)
  , ("budget", BudgetWithinCap)
  , ("ttl", TtlInRegime)
  , ("freshness", FreshnessInRegime)
  , ("offset-domain", OffsetDomainWithinConstants)
  , ("none", Pairwise)
  ] >>= \clause -> if text == "none" then Nothing else Just clause

sharedResourceModel :: Model
sharedResourceModel = Model
  { modelName = "SharedResourceStress"
  , modelConstants = []
  , modelVariables = ["ownerA", "ownerB", "zoneBusy", "sharedLog", "repointedA", "repointedB"]
  , modelInit =
      [ ("ownerA", bool False), ("ownerB", bool False), ("zoneBusy", bool False)
      , ("sharedLog", int 0), ("repointedA", bool False), ("repointedB", bool False)
      ]
  , modelActions = stressActions False
  , modelInvariants =
      [ NamedExpr "SharedSurvivorUnique" (ArithmeticComparison LessThanOrEqual ownerCount (int 1))
      , NamedExpr "ZoneRepointDurable" (Implies (Ref "repointedB") (Ref "repointedA"))
      ]
  , modelConstraint = Just (NamedExpr "StressBound" (FiniteSetMembership (Ref "sharedLog") (FiniteSet [int 0, int 1, int 2])))
  , modelExpansionLimit = Nothing
  , modelFairness = []
  , modelProperties = []
  , modelCheckDeadlock = False
  }
  where
    ownerCount = Add (IfThenElse (Ref "ownerA") (int 1) (int 0)) (IfThenElse (Ref "ownerB") (int 1) (int 0))

sharedResourceMutant :: Model
sharedResourceMutant = sharedResourceModel {modelActions = stressActions True}

stressActions :: Bool -> [Action]
stressActions mutant =
  [ Action "AcquireA" [] (And [Not (Ref "ownerA"), Not (Ref "ownerB")]) [("ownerA", bool True)]
  , Action "CommitShared" [] (And [Ref "ownerA", ArithmeticComparison LessThan (Ref "sharedLog") (int 2)])
      [("sharedLog", Add (Ref "sharedLog") (int 1))]
  , Action "RepointA" [] (And [Ref "ownerA", Not (Ref "zoneBusy")])
      [("zoneBusy", bool True), ("repointedA", bool True)]
  , Action "ReleaseAAndZone" [] (And [Ref "ownerA", Ref "zoneBusy", Ref "repointedA"])
      [("ownerA", bool False), ("zoneBusy", bool False)]
  , Action "AcquireB" [] acquireB [("ownerB", bool True)]
  , Action "RepointB" [] (And [Ref "ownerB", Ref "repointedA", Not (Ref "zoneBusy")])
      [("zoneBusy", bool True), ("repointedB", bool True)]
  ]
  where
    acquireB
      | mutant = And [Ref "ownerA", Ref "repointedA"]
      | otherwise = And [Ref "repointedA", Not (Ref "ownerA"), Not (Ref "ownerB")]

bool :: Bool -> Expr
bool = Literal . BoolValue

int :: Integer -> Expr
int = Literal . IntValue

writeResults :: FilePath -> TlcResult -> Int -> Bool -> Int -> IO ()
writeResults output safetyTlc fairnessDrops iosimAgreement cutoffMutants =
  writeFile (output </> "phase-results.tsv") . unlines $
    [ "metric\tvalue"
    , "gateway-distinct-state-count\t" <> show (fromMaybe 0 (tlcDistinctCount safetyTlc))
    , "explorer-tlc-fingerprints\tequal"
    , "safety-invariants\t5/5-green"
    , "liveness-properties\t3/3-green-under-fairness"
    , "fairness-drop-mutants\t" <> show fairnessDrops <> "/3-red"
    , "per-invariant-mutants\t5/5-red-exactly"
    , "mechanical-safety-mutants\t5/5-red"
    , "iosimpor-schedule-bound\t" <> show iosimporScheduleBound
    , "iosimpor-agreement\t" <> if iosimAgreement then "green" else "red"
    , "cutoff-clause-delete-mutants\t" <> show cutoffMutants <> "/8-red"
    , "scope3-shared-resource-mutant\tred"
    , "decomposition-lemma\tOPEN"
    ]

readTsv :: FilePath -> IO [[String]]
readTsv path = do
  contents <- readFile path
  pure [splitOn '\t' line | line <- drop 1 (lines contents), not (null line)]

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
  pure (unescapeDot (takeUntilLabelEnd rest))

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
         in (trim name, trim (drop 3 valueWithEquals))
      | line <- lines label
      , " = " `isInfixOf` line
      ]
    dropConjunct line = fromMaybe line (stripAfter "/\\ " line)

stripAfter :: String -> String -> Maybe String
stripAfter needle haystack = case find (needle `isPrefixOf`) (tails haystack) of
  Nothing -> Nothing
  Just match -> Just (drop (length needle) match)

breakOn :: String -> String -> (String, String)
breakOn needle haystack = case findIndexPrefix needle haystack of
  Nothing -> (haystack, "")
  Just index -> splitAt index haystack

findIndexPrefix :: String -> String -> Maybe Int
findIndexPrefix needle = go 0
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

zipWith7 :: (a -> b -> c -> d -> e -> f -> g -> h) -> [a] -> [b] -> [c] -> [d] -> [e] -> [f] -> [g] -> [h]
zipWith7 function as bs cs ds es fs gs =
  [function a b c d e f g | (a, b, c, d, e, f, g) <- zip7 as bs cs ds es fs gs]

zip7 :: [a] -> [b] -> [c] -> [d] -> [e] -> [f] -> [g] -> [(a, b, c, d, e, f, g)]
zip7 (a : as) (b : bs) (c : cs) (d : ds) (e : es) (f : fs) (g : gs) =
  (a, b, c, d, e, f, g) : zip7 as bs cs ds es fs gs
zip7 _ _ _ _ _ _ _ = []
