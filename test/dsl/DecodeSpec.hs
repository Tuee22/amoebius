{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import CorpusSpec (CorpusSummary (..), runCorpusSpec)
import CapacityTopologyGate (runCapacityTopologyGate)
import DecisionPropSpec (runDecisionPropSpec)
import ExecutionAcceleratorGate (runExecutionAcceleratorGate)
import StorageGeometryGate (runStorageGeometryGate)
import BindGate (runBindGate)
import ProvisionSealGate (runProvisionSealGate)
import EngineAcceleratorGate (runEngineAcceleratorGate)
import RenderGoldenGate (runRenderGoldenGate)
import ValidationLocusLedger (runValidationLocusLedger)
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

-- The suite invokes ghc and dhall by absolute path on purpose: the Phase-5 argv observer
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
            <> " is unset: run dsl-spec through tools/phase5_gate.py, which resolves the "
            <> "toolchain from toolchain/requirements.json"
        )

main :: IO ()
main = do
  refresh <- lookupEnv "AMOEBIUS_PRINT_GATE2_ORACLE"
  case refresh of
    Just _ -> printGate2Oracle
    Nothing -> runSuite

runSuite :: IO ()
runSuite = do
  positiveCases <- loadPositiveCases "tests/oracle/gate2/positive_trees.tsv"
  decoded <- forM positiveCases checkPositive
  checkStructuralCoverage decoded
  negativeCases <- loadNegativeCases "tests/oracle/gate2/decode_cases.tsv"
  schemaOverride <- lookupEnv "AMOEBIUS_GATE2_SCHEMA_FIXTURE"
  forM_ negativeCases (checkNegative schemaOverride)
  checkImportPolicy
  checkCompilePairs "tests/oracle/gate2/compile_pairs.tsv"
  corpus <- runCorpusSpec
  checkPhase6CompileFail
  runDecisionPropSpec
  (discharged, deferred) <- runValidationLocusLedger (coveredKeys corpus)
  runCapacityTopologyGate
  runStorageGeometryGate
  runExecutionAcceleratorGate
  runBindGate
  runProvisionSealGate
  runEngineAcceleratorGate
  runRenderGoldenGate
  putStrLn
    ( "dsl-spec: PASS ("
        <> show (length positiveCases)
        <> " positives, "
        <> show (length negativeCases)
        <> " tagged negatives, 3 compile-fail pairs)"
    )
  putStrLn
    ( "phase6-dsl-spec: PASS ("
        <> show (gate1Count corpus)
        <> " Gate-1, "
        <> show (gate2Count corpus)
        <> " Gate-2, "
        <> show (positiveCount corpus)
        <> " positives, "
        <> show discharged
        <> " discharged, "
        <> show deferred
        <> " deferred)"
    )

printGate2Oracle :: IO ()
printGate2Oracle = do
  rows <- loadPositiveCases "tests/oracle/gate2/positive_trees.tsv"
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

checkPhase6CompileFail :: IO ()
checkPhase6CompileFail = do
  (exitCode, stdout, stderr) <- readCreateProcessWithExitCode (proc "sh" ["tools/compile_fail.sh"]) ""
  assert (exitCode == ExitSuccess) ("Phase-6 compile-fail harness failed:\n" <> stdout <> stderr)
  assert ("compile-fail: PASS (5 legal/illegal one-token pairs)" `contains` stdout) "Phase-6 compile-fail token missing"

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
              then StructuralNode nodePath nodeKind (nodeValue <> "#gate2-mutant")
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
    , "tests/gate2/import/root_nested_env.dhall"
    , "tests/gate2/import/root_nested_remote.dhall"
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
  putStrLn ("dsl-spec: FAIL: " <> message)
  exitFailure
