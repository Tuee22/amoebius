{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

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
import Amoebius.Scope.Index qualified as CalculusScope
import Amoebius.Test.WorkflowAlgebra qualified as Algebra
import Control.Monad (forM_, unless)
import Data.Text qualified as Text
import System.Directory (doesFileExist, getCurrentDirectory, setCurrentDirectory)
import System.Exit (die)
import System.FilePath ((</>), takeDirectory)
import Text.Read (readMaybe)

main :: IO ()
main = do
  root <- projectRoot
  setCurrentDirectory root
  verifyCustody root
  rows <- loadTable (root </> "test/oracle/test_workflow_algebra/suggest_projection.tsv")
  assertEqual "suggestion row count" 15 (length rows)
  outcomes <- traverse verifyProjection rows
  assertEqual "accepted suggestion count" 4 (length [() | True <- outcomes])
  assertEqual "rejected suggestion count" 11 (length [() | False <- outcomes])
  verifyEvidence
  verifyCalculus root
  putStrLn "test-workflow-algebra-calculus: PASS (5 kinds, 26 projected units)"
  putStrLn "test-workflow-algebra-spec: PASS (15 suggestions, 9 resource axes, 2 teardown states, 2 evidence rows, 4 mutants)"

verifyProjection :: [String] -> IO Bool
verifyProjection fields = case fields of
  [caseName, branchText, flaggedText, secretText, supplyText, expected, reason, demandText] -> do
    branch <- parseBranch branchText
    flagged <- parseBool flaggedText
    supply <- parseVector supplyText
    wantedDemand <- parseVector demandText
    let secret = if secretText == "—" then "" else Text.pack secretText
        declaration = Algebra.WorkflowDeclaration
          (Text.pack caseName) Algebra.LinuxCpu branch (Algebra.TestCredential secret flagged) supply
        actual = Algebra.suggestWorkflow declaration
    case (expected, actual) of
      ("PASS", Right workflow) -> do
        assertEqual (caseName <> " demand") wantedDemand (Algebra.workflowDemand workflow)
        assertEqual "test-workflow-algebra-mutant: RED wrong-subscription delegated-subscription"
          "test-workflow-failover" (Algebra.workflowSubscription workflow)
        let first = Algebra.renderSuggestedWorkflow workflow
            second = Algebra.renderSuggestedWorkflow workflow
        assertEqual (caseName <> " deterministic render") first second
        pure True
      ("RED", Left observed) -> do
        assertEqual (caseName <> " rejection") reason (renderError observed)
        pure False
      ("RED", Right _) | caseName == "short-cpu" ->
        die "test-workflow-algebra-mutant: RED tag-query supply-cpu-short"
      ("PASS", Left observed) -> die (caseName <> ": unexpected rejection " <> renderError observed)
      ("RED", Right _) -> die (caseName <> ": expected rejection " <> reason)
      _ -> die (caseName <> ": invalid expected verdict " <> expected)
  _ -> die ("invalid suggestion projection row: " <> show fields)

verifyEvidence :: IO ()
verifyEvidence = do
  supply <- parseVector "10000,20000000000,70000000000,10000000000,5000000000,32,32,8,100"
  workflow <- either (die . show) pure $ Algebra.suggestWorkflow $ Algebra.WorkflowDeclaration
    "evidence" Algebra.LinuxCpu Algebra.CoreBranch (Algebra.TestCredential "vault/test/workflow" True) supply
  let sealed = Algebra.sealWorkflow (Algebra.attachTeardown (Algebra.Teardown "inventory-diff") workflow)
  assertEqual "sealed workflow name" "evidence" (Algebra.sealedWorkflowName sealed)
  assertEqual "test-workflow-algebra-mutant: RED all-tested evidence-overclaim"
    [ Algebra.EvidenceRow "StandbyTakesOver" Algebra.Tested
    , Algebra.EvidenceRow "CrossZoneContinuity" Algebra.Unverified
    ]
    (Algebra.deriveEvidence sealed)

verifyCalculus :: FilePath -> IO ()
verifyCalculus root = do
  expected <- loadTable (root </> "test/oracle/test_workflow_algebra/calculus_projection.tsv")
  tenant <- requireRight "calculus tenant" (CalculusScope.trustedTenant "test-workflow-calculus-tenant")
  subject <- requireRight "calculus subject" (CalculusScope.trustedSubject tenant "test-workflow-calculus-subject")
  membership <- requireRight "calculus membership" (CalculusScope.activeMembership tenant subject)
  action <- requireRight "calculus request scope" $
    CalculusScope.withRequestScope tenant subject membership $ \scope -> do
      let resources :: Int -> ResourceVector
          resources count = ResourceVector 1 (fromIntegral count) 0 0
          counts :: [Int]
          counts = [15, 2, 4, 3, 2]
          artifact = artifactComponent scope "test-workflow-algebra" (resources 15)
            (RecipeId "test-workflow-algebra" 15)
          budget = budgetComponent scope "closed-test-budget" (resources 2)
            (allowance (Bytes 1) (Slots 1) (Bytes 1))
          lift = liftComponent scope "suggest-test-projections" (resources 4) OnHost
          workflow = workflowComponent scope "teardown-workflow" (resources 3) emptyLedger
          evidence = evidenceComponent scope "evidence-ledger" (resources 2) PureRegister
          composition = append (compose artifact budget) (append (compose lift workflow) (singleton evidence))
          ResourceVector cpu memory ephemeral pods = compositionResource composition
          render = Text.unpack . Text.intercalate ","
          actual =
            [ ["calculus-kinds", render (fmap calculusTag (compositionKinds composition))]
            , ["component-names", render (compositionNames composition)]
            , ["projection-counts", render (fmap (Text.pack . show) counts)]
            , ["resource-vector", render (fmap (Text.pack . show) [cpu, memory, ephemeral, pods])]
            ]
      assertEqual "five calculus kinds" everyCalculus (compositionKinds composition)
      assertEqual "test workflow calculus projection" expected actual
  action

verifyCustody :: FilePath -> IO ()
verifyCustody root = do
  rows <- loadTable (root </> "test/oracle/preimplementation_artifacts.tsv")
  let phaseRows = [fields | fields@(phase : _) <- rows, phase == "56"]
  assertEqual "Phase-0 custody" 23 (length phaseRows)
  forM_ phaseRows $ \row -> case row of
    (_phase : _kind : path : _) -> do
      present <- doesFileExist (root </> path)
      assert present ("missing custody artifact: " <> path)
    _ -> die "invalid Phase-56 custody row"

parseBranch :: String -> IO Algebra.Branch
parseBranch value = case value of
  "core" -> pure Algebra.CoreBranch
  "registry" -> pure Algebra.RegistryBranch
  "provider" -> pure Algebra.ProviderBranch
  "migration" -> pure Algebra.MigrationBranch
  _ -> die ("unknown branch " <> value)

parseBool :: String -> IO Bool
parseBool value = case value of
  "true" -> pure True
  "false" -> pure False
  _ -> die ("invalid boolean " <> value)

parseVector :: String -> IO Algebra.ResourceVector
parseVector value = case traverse readMaybe (splitComma value) of
  Just [cpu, memory, ephemeral, durable, cache, pods, ips, csi, quota] ->
    pure (Algebra.ResourceVector cpu memory ephemeral durable cache pods ips csi quota)
  _ -> die ("invalid resource vector " <> value)

renderError :: Algebra.SuggestionError -> String
renderError problem = case problem of
  Algebra.FlaggedCredentialRequired -> "flagged-credential-required"
  Algebra.NamedSecretRequired -> "named-secret-required"
  Algebra.Insufficient axis -> "insufficient-" <> case axis of
    Algebra.Cpu -> "cpu"
    Algebra.Memory -> "memory"
    Algebra.Ephemeral -> "ephemeral"
    Algebra.Durable -> "durable"
    Algebra.Cache -> "cache"
    Algebra.Pods -> "pods"
    Algebra.Ips -> "ips"
    Algebra.Csi -> "csi"
    Algebra.Quota -> "quota"

loadTable :: FilePath -> IO [[String]]
loadTable path = do
  rows <- lines <$> readFile path
  case rows of
    [] -> die ("empty table: " <> path)
    _header : body -> pure (fmap splitTabs body)

splitTabs :: String -> [String]
splitTabs value = case break (== '\t') value of
  (field, []) -> [field]
  (field, _ : rest) -> field : splitTabs rest

splitComma :: String -> [String]
splitComma value = case break (== ',') value of
  (field, []) -> [field]
  (field, _ : rest) -> field : splitComma rest

requireRight :: Show problem => String -> Either problem value -> IO value
requireRight label = either (die . ((label <> ": ") <>) . show) pure

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label wanted actual = unless (wanted == actual) $
  die (label <> ": expected " <> show wanted <> ", got " <> show actual)

projectRoot :: IO FilePath
projectRoot = getCurrentDirectory >>= ascend
 where
  ascend path = do
    present <- doesFileExist (path </> "cabal.project")
    if present then pure path else
      let parent = takeDirectory path
      in if parent == path then die "test-workflow-algebra-root" else ascend parent
