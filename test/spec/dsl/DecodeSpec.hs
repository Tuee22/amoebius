{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

#if !defined(GADT_DECODE_ONLY)
import CorpusSpec (CorpusSummary (..), runCorpusSpec)
import DecisionPropSpec (runDecisionPropSpec)
import ValidationLocusLedger (runValidationLocusLedger)
#endif
#if !defined(GADT_DECODE_ONLY) && !defined(ILLEGAL_STATE_CORPUS_ONLY)
import CapacityTopologyGate (runCapacityTopologyGate)
import ExecutionAcceleratorGate (runExecutionAcceleratorGate)
import StorageGeometryGate (runStorageGeometryGate)
import BindGate (runBindGate)
import ProvisionSealGate (runProvisionSealGate)
import EngineAcceleratorGate (runEngineAcceleratorGate)
import RenderGoldenGate (runRenderGoldenGate)
#endif
#if defined(GADT_DECODE_ONLY) || defined(ILLEGAL_STATE_CORPUS_ONLY)
import Amoebius.Calculus.Artifact.Recipe (RecipeId (RecipeId))
import Amoebius.Calculus.Budget.Grant (Bytes (Bytes), Slots (Slots), allowance)
import Amoebius.Calculus.Composition
  ( append
  , artifactComponent
  , budgetComponent
  , calculusTag
  , compose
  , compositionKinds
  , compositionNames
  , compositionResource
  , evidenceComponent
  , everyCalculus
  , liftComponent
  , singleton
  , workflowComponent
  )
import Amoebius.Calculus.Evidence.Register (Register (PureRegister))
import Amoebius.Calculus.Lift.Layer (Layer (OnHost))
import Amoebius.Calculus.Workflow.Ledger (emptyLedger)
import Amoebius.Capacity.Types (ResourceVector (ResourceVector))
import Amoebius.Scope.Index
  ( activeMembership
  , trustedSubject
  , trustedTenant
  , withRequestScope
  )
#endif
import Amoebius.Dsl.Decode (decodeCluster)
import Amoebius.Dsl.Error (decodeErrorTag)
import Amoebius.Dsl.Types
  ( ClusterIR (..)
  , StructuralNode (..)
  , Surface (..)
  )
import Control.Monad (forM, forM_, unless)
import Data.Bits (xor)
import Data.Char (ord)
import Data.List (isSuffixOf)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import System.Environment (lookupEnv)
import System.Exit (ExitCode (..), exitFailure)
import System.Process (proc, readCreateProcessWithExitCode)
import Data.Word (Word64)

data PositiveCase = PositiveCase
  { positiveFile :: FilePath
  , positiveSurface :: Surface
  , positiveHash :: Text
  , positiveNodeCount :: Int
  , positiveFingerprint :: Word64
  }

data NegativeCase = NegativeCase
  { negativeFile :: FilePath
  , negativeTag :: Text
  , negativeTwin :: FilePath
  }

-- The suite invokes ghc and dhall by absolute path on purpose: the Phase-27 argv observer
-- asserts that no tool is reached through an ambient PATH lookup. Which absolute path is a
-- run-local resolution, not a fact about the repository, so the resolver supplies it and
-- the suite fails closed rather than falling back to one developer's home directory.
resolvedTool :: String -> IO FilePath
resolvedTool name = do
  value <- lookupEnv name
  case value of
    Just path | not (null path) -> pure path
    _ ->
      fail
        ( name
            <> " is unset: run "
            <> suiteName
            <> " through "
            <> gateCommand
            <> ", which resolves the "
            <> "toolchain from tools/toolchain_requirements.json"
        )

main :: IO ()
main = do
  refresh <- lookupEnv "AMOEBIUS_PRINT_GADT_DECODE_ORACLE"
  case refresh of
    Just _ -> printGate2Oracle
    Nothing -> runSuite

runSuite :: IO ()
runSuite = do
  positiveCases <- loadPositiveCases "test/oracle/gadt_decode_ir/positive_trees.tsv"
  decoded <- forM positiveCases checkPositive
  checkStructuralCoverage decoded
  negativeCases <- loadNegativeCases "test/oracle/gadt_decode_ir/decode_cases.tsv"
  schemaOverride <- lookupEnv "AMOEBIUS_GADT_DECODE_SCHEMA_FIXTURE"
  forM_ negativeCases (checkNegative schemaOverride)
  checkImportPolicy
  checkCompilePairs "test/oracle/gadt_decode_ir/compile_pairs.tsv"
#ifdef GADT_DECODE_ONLY
  checkDecodedCalculusProjection decoded
#endif
#ifndef GADT_DECODE_ONLY
  corpus <- runCorpusSpec
  localCompilePairs <- checkPhase27CompileFail
  predecessorCompilePairs <- checkPhase9CompileFail
  runDecisionPropSpec
  (discharged, deferred, predecessorRows) <- runValidationLocusLedger (coveredKeys corpus)
#ifdef ILLEGAL_STATE_CORPUS_ONLY
  checkIllegalStateCalculusProjection corpus (localCompilePairs + predecessorCompilePairs) discharged deferred
#else
  runCapacityTopologyGate
  runStorageGeometryGate
  runExecutionAcceleratorGate
  runBindGate
  runProvisionSealGate
  runEngineAcceleratorGate
  runRenderGoldenGate
#endif
  putStrLn
    ( "illegal-state-predecessors: PASS ("
        <> show predecessorRows
        <> " joined gadt rows, "
        <> show predecessorCompilePairs
        <> " compile pairs)"
    )
#endif
  putStrLn
    ( suiteName
        <> ": PASS ("
        <> show (length positiveCases)
        <> " positives, "
        <> show (length negativeCases)
        <> " tagged negatives, 3 compile-fail pairs)"
    )
#ifndef GADT_DECODE_ONLY
  putStrLn
    ( "illegal-state-dsl-spec: PASS ("
        <> show (dhallTypecheckCount corpus)
        <> " Gate-1, "
        <> show (gadtDecodeCount corpus)
        <> " Gate-2, "
        <> show (positiveCount corpus)
        <> " positives, "
        <> show discharged
        <> " discharged, "
        <> show deferred
        <> " deferred)"
    )
#endif

suiteName :: String
#ifdef GADT_DECODE_ONLY
suiteName = "gadt-decode-spec"
#elif defined(ILLEGAL_STATE_CORPUS_ONLY)
suiteName = "illegal-state-corpus-spec"
#else
suiteName = "dsl-spec"
#endif

gateCommand :: String
#ifdef ILLEGAL_STATE_CORPUS_ONLY
gateCommand = "tools/illegal_state_corpus_gate.py"
#else
gateCommand = "tools/gadt_decode_ir_gate.py"
#endif

#ifdef GADT_DECODE_ONLY
checkDecodedCalculusProjection :: [ClusterIR] -> IO ()
checkDecodedCalculusProjection decoded = case decoded of
  [artifactIr, budgetIr, liftIr, workflowIr, evidenceIr] -> do
    expected <- loadMetricOracle "test/oracle/gadt_decode_ir/calculus_projection.tsv"
    tenant <- either (die . show) pure (trustedTenant "gadt-decode-tenant")
    subject <- either (die . show) pure (trustedSubject tenant "gadt-decode-subject")
    membership <- either (die . show) pure (activeMembership tenant subject)
    action <- either (die . show) pure $ withRequestScope tenant subject membership $ \scope -> do
      let resources ir = ResourceVector 1 (fromIntegral (length (clusterNodes ir))) 0 0
          artifact = artifactComponent scope "decoded-artifact" (resources artifactIr) (RecipeId (clusterSemanticHash artifactIr) 1)
          budgetRows = fromIntegral (length (clusterNodes budgetIr))
          budget = budgetComponent scope "decoded-budget" (resources budgetIr) (allowance (Bytes budgetRows) (Slots 1) (Bytes budgetRows))
          lift = liftComponent scope "decoded-lift" (resources liftIr) OnHost
          workflow = workflowComponent scope "decoded-workflow" (resources workflowIr) emptyLedger
          evidence = evidenceComponent scope "decoded-evidence" (resources evidenceIr) PureRegister
          composition = append (compose artifact budget) (append (compose lift workflow) (singleton evidence))
          ResourceVector cpu memory ephemeral pods = compositionResource composition
          actual =
            [ ("calculus-kinds", Text.intercalate "," (map calculusTag (compositionKinds composition)))
            , ("component-names", Text.intercalate "," (compositionNames composition))
            , ("resource-vector", Text.intercalate "," (map (Text.pack . show) [cpu, memory, ephemeral, pods]))
            ]
      assert (compositionKinds composition == everyCalculus) "decoded projection omitted or reordered a calculus"
      assert (actual == expected) ("decoded calculus projection changed: " <> show actual)
    action
    putStrLn "gadt-decode-calculus: PASS (5 kinds, 5527 retained rows)"
  _ -> die "decoded calculus projection requires exactly five authored positives"
#endif

#ifdef ILLEGAL_STATE_CORPUS_ONLY
checkIllegalStateCalculusProjection :: CorpusSummary -> Int -> Int -> Int -> IO ()
checkIllegalStateCalculusProjection corpus compilePairs discharged deferred = do
  expected <- loadMetricOracle "test/oracle/illegal_state_corpus/calculus_projection.tsv"
  tenant <- either (die . show) pure (trustedTenant "illegal-state-corpus-tenant")
  subject <- either (die . show) pure (trustedSubject tenant "illegal-state-corpus-subject")
  membership <- either (die . show) pure (activeMembership tenant subject)
  action <- either (die . show) pure $ withRequestScope tenant subject membership $ \scope -> do
    let negativeCount = dhallTypecheckCount corpus + gadtDecodeCount corpus
        positiveRows = positiveCount corpus
        resources count = ResourceVector 1 (fromIntegral count) 0 0
        artifact = artifactComponent scope "negative-corpus" (resources negativeCount) (RecipeId "illegal-state-corpus" 1)
        budget = budgetComponent scope "deferred-ledger" (resources deferred) (allowance (Bytes (fromIntegral deferred)) (Slots 1) (Bytes (fromIntegral deferred)))
        lift = liftComponent scope "positive-corpus" (resources positiveRows) OnHost
        workflow = workflowComponent scope "compile-pairs" (resources compilePairs) emptyLedger
        evidence = evidenceComponent scope "discharged-ledger" (resources discharged) PureRegister
        composition = append (compose artifact budget) (append (compose lift workflow) (singleton evidence))
        ResourceVector cpu memory ephemeral pods = compositionResource composition
        actual =
          [ ("calculus-kinds", Text.intercalate "," (map calculusTag (compositionKinds composition)))
          , ("component-names", Text.intercalate "," (compositionNames composition))
          , ("projection-counts", Text.intercalate "," (map (Text.pack . show) [negativeCount, deferred, positiveRows, compilePairs, discharged]))
          , ("resource-vector", Text.intercalate "," (map (Text.pack . show) [cpu, memory, ephemeral, pods]))
          ]
    assert (compositionKinds composition == everyCalculus) "illegal-state projection omitted or reordered a calculus"
    assert (actual == expected) ("illegal-state calculus projection changed: " <> show actual)
  action
  putStrLn "illegal-state-calculus: PASS (5 kinds, 172 projected units)"
#endif

#if defined(GADT_DECODE_ONLY) || defined(ILLEGAL_STATE_CORPUS_ONLY)
loadMetricOracle :: FilePath -> IO [(Text, Text)]
loadMetricOracle path = do
  contents <- Text.readFile path
  forM (dropHeader (Text.lines contents)) $ \row -> case Text.splitOn "\t" row of
    [metric, value] -> pure (metric, value)
    _ -> die ("malformed metric row: " <> Text.unpack row)
#endif

printGate2Oracle :: IO ()
printGate2Oracle = do
  rows <- loadPositiveCases "test/oracle/gadt_decode_ir/positive_trees.tsv"
  putStrLn "fixture\tsurface\tsemantic_hash\tnode_count\tstructural_fingerprint"
  forM_ rows $ \row -> do
    result <- decodeCluster (positiveFile row)
    case result of
      Left problem -> die (positiveFile row <> " rejected while printing oracle: " <> show problem)
      Right ir ->
        putStrLn
          ( positiveFile row
              <> "\t"
              <> surfaceText (clusterSurface ir)
              <> "\t"
              <> Text.unpack (clusterSemanticHash ir)
              <> "\t"
              <> show (length (clusterNodes ir))
              <> "\t"
              <> show (structuralFingerprint (clusterNodes ir))
          )
 where
 surfaceText surface = case surface of
    ClusterSurface -> "Cluster"
    AppSurface -> "App"
    DeploymentSurface -> "Deployment"

#ifndef GADT_DECODE_ONLY
checkPhase27CompileFail :: IO Int
checkPhase27CompileFail = do
  (exitCode, stdout, stderr) <- readCreateProcessWithExitCode (proc "sh" ["tools/compile_fail.sh"]) ""
  assert (exitCode == ExitSuccess) ("Phase-28 compile-fail harness failed:\n" <> stdout <> stderr)
  assert ("compile-fail: PASS (5 legal/illegal one-token pairs)" `contains` stdout) "Phase-28 compile-fail token missing"
  pure 5

checkPhase9CompileFail :: IO Int
checkPhase9CompileFail = do
  (exitCode, stdout, stderr) <- readCreateProcessWithExitCode (proc "python3" ["tools/capacity_topology_compile_fail.py"]) ""
  assert (exitCode == ExitSuccess) ("Phase-9 predecessor compile-fail harness failed:\n" <> stdout <> stderr)
  assert ("capacity-topology-compile-fail: PASS (7 legal/illegal minimal pairs)" `contains` stdout) "Phase-9 predecessor compile-fail token missing"
  pure 4
#endif

checkPositive :: PositiveCase -> IO ClusterIR
checkPositive PositiveCase {positiveFile, positiveSurface, positiveHash, positiveNodeCount, positiveFingerprint} = do
  result <- decodeCluster positiveFile
  case result of
    Left problem -> die (positiveFile <> " unexpectedly rejected: " <> show problem)
    Right ir -> do
      assert (clusterSurface ir == positiveSurface) (positiveFile <> " surface changed")
      assert (clusterSemanticHash ir == positiveHash) (positiveFile <> " semantic hash changed")
      assert (not (null (clusterNodes ir))) (positiveFile <> " retained no structural nodes")
      assert (length (clusterNodes ir) == positiveNodeCount) (positiveFile <> " structural node count changed")
      assert (structuralFingerprint (clusterNodes ir) == positiveFingerprint) (positiveFile <> " structural fingerprint changed")
      assert
        (all ((/= "NormalizedExpr") . nodeKind) (clusterNodes ir))
        (positiveFile <> " retained an unclassified normalized expression")
      checkStructuralMutants positiveFile positiveFingerprint (clusterNodes ir)
      pure ir

checkStructuralMutants :: FilePath -> Word64 -> [StructuralNode] -> IO ()
checkStructuralMutants fixture expectedFingerprint original = do
  let expectedCount = length original
      validates candidate =
        length candidate == expectedCount
          && structuralFingerprint candidate == expectedFingerprint
  forM_ (zip [0 :: Int ..] original) $ \(target, _) -> do
    let deleted = [node | (index, node) <- zip [0 :: Int ..] original, index /= target]
    assert (not (validates deleted)) (fixture <> " deletion mutant survived at row " <> show target)
  forM_ (uniqueMutationTargets original) $ \target -> do
    let substituted =
          [ if index == target
              then StructuralNode nodePath nodeKind (nodeValue <> "#gadt-decode-mutant")
              else node
          | (index, node@(StructuralNode nodePath nodeKind nodeValue)) <- zip [0 :: Int ..] original
          ]
    assert (not (validates substituted)) (fixture <> " substitution mutant survived at row " <> show target)

uniqueMutationTargets :: [StructuralNode] -> [Int]
uniqueMutationTargets = go Set.empty 0
 where
  go _ _ [] = []
  go seen index (StructuralNode nodePath _ _ : remaining) = case reverse nodePath of
    [] -> go seen (index + 1) remaining
    label : _
      | label `Set.member` mutationLabels && label `Set.notMember` seen ->
          index : go (Set.insert label seen) (index + 1) remaining
      | otherwise -> go seen (index + 1) remaining
  mutationLabels =
    Set.fromList
      [ "ephemeralStorage", "allocatableRawBytes", "kubeletMetadataModel"
      , "networkAttachments", "id", "revision", "maxSurge", "maxUnavailable"
      , "podSlots", "cniSlots", "attachableVolumes", "account", "quotaVcpu"
      , "maxInstances", "maxVcpu", "acceleratorCaps", "nodeRootStorage", "durable"
      , "monitoring", "manifestListDigest", "childDigest", "configDigest", "layers"
      , "chainId", "transition", "bookKeeperLogical", "pulsarMetadata", "pulumi"
      , "objectStoreProducers", "storageMigrations", "schemaMigrations"
      , "registryMigrations", "sql", "vault", "sources", "workloads"
      , "residency", "coexistence", "presentation"
      ]

checkStructuralCoverage :: [ClusterIR] -> IO ()
checkStructuralCoverage decoded = do
  let allNodes = concatMap clusterNodes decoded
      fieldNames = Set.fromList [field | StructuralNode nodePath _ _ <- allNodes, field <- nodePath]
      required =
        Set.fromList
          [ "id"
          , "revision"
          , "controller"
          , "cardinality"
          , "maxSurge"
          , "maxUnavailable"
          , "resources"
          , "ephemeralStorage"
          , "runtimeMetadata"
          , "networkAttachments"
          , "allocatableRawBytes"
          , "kubeletMetadataModel"
          , "podSlots"
          , "cniSlots"
          , "attachableVolumes"
          , "account"
          , "quotaVcpu"
          , "nodeRootStorage"
          , "maxInstances"
          , "maxVcpu"
          , "transition"
          , "monitoring"
          , "maxConcurrentQueries"
          , "presentation"
          , "manifestListDigest"
          , "childDigest"
          , "configDigest"
          , "layers"
          , "chainId"
          , "build"
          , "stages"
          , "bookKeeperLogical"
          , "pulsarMetadata"
          , "pulumi"
          , "objectStoreProducers"
          , "storageMigrations"
          , "schemaMigrations"
          , "registryMigrations"
          , "sql"
          , "vault"
          ]
      missing = required `Set.difference` fieldNames
  assert (Set.null missing) ("positive structural inventory missing: " <> show missing)
  assert (hasExactValue ["monitoring", "maxWorkflows"] "Natural" "250" allNodes) "monitoring maxWorkflows did not round-trip"
  assert (hasExactValue ["account"] "Text" "cloud-account-production" allNodes) "managed account did not round-trip"
  assert (hasExactValue ["quotaVcpu"] "Natural" "8" allNodes) "provider quotaVcpu did not round-trip"
  assert (hasExactValue ["workloads", "head", "revision"] "Natural" "1" allNodes) "execution revision did not round-trip"

hasExactValue :: [Text] -> Text -> Text -> [StructuralNode] -> Bool
hasExactValue suffix expectedKind expectedValue = any matches
 where
  matches (StructuralNode nodePath actualKind actualValue) =
    suffix `isSuffixOf` nodePath && actualKind == expectedKind && actualValue == expectedValue

checkNegative :: Maybe FilePath -> NegativeCase -> IO ()
checkNegative schemaOverride NegativeCase {negativeFile, negativeTag, negativeTwin} = do
  let selected = case (negativeTag, schemaOverride) of
        ("SchemaMismatch", Just replacement) -> replacement
        _ -> negativeFile
  dhall <- resolvedTool "AMOEBIUS_DHALL"
  (typeExit, _, typeError) <- readCreateProcessWithExitCode (proc dhall ["type", "--file", selected]) ""
  assert (typeExit == ExitSuccess) (selected <> " is not Gate-1 green:\n" <> typeError)
  result <- decodeCluster selected
  case result of
    Right _ -> die (selected <> " decoded but expected " <> Text.unpack negativeTag)
    Left problem ->
      assert
        (decodeErrorTag problem == negativeTag)
        (selected <> " returned " <> Text.unpack (decodeErrorTag problem) <> ", expected " <> Text.unpack negativeTag)
  -- Section M.8: the paired positive is only a control if it is run. Reverting the one
  -- tagged construct must decode, or the negative proves nothing about that construct.
  twinResult <- decodeCluster negativeTwin
  case twinResult of
    Left twinProblem ->
      die (negativeTwin <> " is the paired positive for " <> selected <> " but was rejected: " <> show twinProblem)
    Right _ -> pure ()

checkImportPolicy :: IO ()
checkImportPolicy = do
  forM_
    [ "dhall/examples/illegal_import_env.dhall"
    , "dhall/examples/illegal_import_remote.dhall"
    , "test/fixture/gadt_decode_ir/import/root_nested_env.dhall"
    , "test/fixture/gadt_decode_ir/import/root_nested_remote.dhall"
    ] $ \fixture -> do
    result <- decodeCluster fixture
    case result of
      Left problem -> assert (decodeErrorTag problem == "ForbiddenImport") (fixture <> " was not ForbiddenImport")
      Right _ -> die (fixture <> " bypassed the import policy")

checkCompilePairs :: FilePath -> IO ()
checkCompilePairs oracle = do
  contents <- Text.readFile oracle
  let rows = dropHeader (Text.lines contents)
  assert (length rows == 3) "compile-pair oracle must contain exactly three pairs"
  forM_ rows $ \row -> case Text.splitOn "\t" row of
    [_pair, legal, illegal, locus, _positive] -> do
      let arguments fixture = ["-fno-code", "-fforce-recomp", "-isrc", "-XGHC2024", Text.unpack fixture]
      ghc <- resolvedTool "AMOEBIUS_GHC"
      (legalExit, _, legalError) <- readCreateProcessWithExitCode (proc ghc (arguments legal)) ""
      assert (legalExit == ExitSuccess) (Text.unpack legal <> " failed to compile:\n" <> legalError)
      (illegalExit, _, illegalError) <- readCreateProcessWithExitCode (proc ghc (arguments illegal)) ""
      assert (illegalExit /= ExitSuccess) (Text.unpack illegal <> " unexpectedly compiled")
      assert (Text.unpack locus `contains` illegalError) (Text.unpack illegal <> " missed expected type-error locus " <> Text.unpack locus)
    _ -> die ("malformed compile-pair row: " <> Text.unpack row)

loadPositiveCases :: FilePath -> IO [PositiveCase]
loadPositiveCases oracle = do
  contents <- Text.readFile oracle
  forM (dropHeader (Text.lines contents)) $ \row -> case Text.splitOn "\t" row of
    [fixture, surfaceText, digest, countText, fingerprintText] -> do
      surfaceValue <- case surfaceText of
        "Cluster" -> pure ClusterSurface
        "App" -> pure AppSurface
        "Deployment" -> pure DeploymentSurface
        _ -> die ("unknown positive surface: " <> Text.unpack surfaceText)
      count <- case reads (Text.unpack countText) of
        [(value, "")] -> pure value
        _ -> die ("invalid positive node count: " <> Text.unpack countText)
      fingerprint <- case reads (Text.unpack fingerprintText) of
        [(value, "")] -> pure value
        _ -> die ("invalid positive fingerprint: " <> Text.unpack fingerprintText)
      pure (PositiveCase (Text.unpack fixture) surfaceValue digest count fingerprint)
    _ -> die ("malformed positive row: " <> Text.unpack row)

loadNegativeCases :: FilePath -> IO [NegativeCase]
loadNegativeCases oracle = do
  contents <- Text.readFile oracle
  forM (dropHeader (Text.lines contents)) $ \row -> case Text.splitOn "\t" row of
    [fixture, expected, _catalog, twin] ->
      pure (NegativeCase (Text.unpack fixture) expected (Text.unpack twin))
    _ -> die ("malformed negative row: " <> Text.unpack row)

dropHeader :: [Text] -> [Text]
dropHeader rows = case rows of
  [] -> []
  _header : body -> filter (not . Text.null) body

contains :: String -> String -> Bool
contains needle haystack = Text.pack needle `Text.isInfixOf` Text.pack haystack

structuralFingerprint :: [StructuralNode] -> Word64
structuralFingerprint = foldl' hashNode 14695981039346656037
 where
  hashNode accumulator (StructuralNode nodePath nodeKind nodeValue) =
    Text.foldl' hashCharacter accumulator (Text.intercalate "\x1f" nodePath <> "\x1e" <> nodeKind <> "\x1e" <> nodeValue <> "\x1d")
  hashCharacter accumulator character = (accumulator `xor` fromIntegral (ord character)) * 1099511628211

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

die :: String -> IO value
die message = do
  putStrLn (suiteName <> ": FAIL: " <> message)
  exitFailure
