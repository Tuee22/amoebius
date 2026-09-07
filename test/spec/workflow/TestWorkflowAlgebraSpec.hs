{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Calculus.Artifact.Recipe (RecipeId (RecipeId))
import Amoebius.Calculus.Budget.Grant (Bytes (Bytes), Slots (Slots), allowance)
import Amoebius.Calculus.Composition
  ( append, artifactComponent, budgetComponent, calculusTag, compose
  , compositionKinds, compositionNames, compositionResource, evidenceComponent
  , everyCalculus, liftComponent, singleton, workflowComponent
  )
import Amoebius.Calculus.Evidence.Register (Register (PureRegister))
import Amoebius.Calculus.Lift.Layer (Layer (OnHost))
import Amoebius.Calculus.Workflow.Ledger (emptyLedger)
import Amoebius.Capacity.Types qualified as Capacity
import Amoebius.Scope.Index qualified as CalculusScope
import Amoebius.Test.WorkflowAlgebra qualified as Algebra
import Control.Monad (forM_, unless)
import Data.Maybe (fromJust)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (createDirectoryIfMissing, doesFileExist, getCurrentDirectory, makeAbsolute, setCurrentDirectory)
import System.Environment (getArgs)
import System.Exit (die)
import System.FilePath (makeRelative, normalise, splitDirectories, takeDirectory, (</>))
import TestWorkflowAlgebraOracle qualified as Oracle

main :: IO ()
main = do
  root <- projectRoot
  setCurrentDirectory root
  arguments <- getArgs
  (outputArgument, runIdentity) <- case arguments of
    ["--output", output, "--run-id", runId] -> pure (output, Text.pack runId)
    _ -> die "usage: test-workflow-algebra --output DIRECTORY --run-id ID"
  output <- makeAbsolute outputArgument
  assertEqual "exact output root" (normalise (root </> ".build")) (normalise output)
  assert (validRunIdentity runIdentity) "run identity must be a bounded leaf"
  checkMutantLoci
  checkConstructorDiscovery
  checkSuggestions
  checkTerminalFold
  checkInventory
  checkEvidence
  checkProjection root output runIdentity
  checkCalculus
  putStrLn "test-workflow-algebra-calculus: PASS (5 kinds, 31 projected units)"
  putStrLn "test-workflow-algebra-spec: PASS (5 branches, 9 axes, 6 terminal outcomes, 5 inventory domains, 4 evidence moves, 7 mutants)"

checkMutantLoci :: IO ()
checkMutantLoci = do
  topology <- requireRight "mutant topology" (Algebra.suggestTest (model "mutant" Algebra.ProviderBranch ample [Algebra.DelegatedFailover]))
  unless (Algebra.topologyTeardownRequired topology) $
    die "test-workflow-algebra-mutant: RED optional-teardown teardown-obligation"
  let cleanup = Algebra.terminalResult (Algebra.observeTeardown Algebra.WorkflowSucceeded (Algebra.TeardownFailed (Algebra.Failure "cleanup")) topology)
  unless (cleanup == Algebra.TerminalTeardownFailure (Algebra.Failure "cleanup")) $
    die "test-workflow-algebra-mutant: RED cleanup-success terminal-result"
  let primary = Algebra.terminalResult (Algebra.observeTeardown (Algebra.WorkflowFailed (Algebra.Failure "primary")) (Algebra.TeardownFailed (Algebra.Failure "cleanup")) topology)
  unless (primary == Algebra.TerminalWorkflowFailure (Algebra.Failure "primary")) $
    die "test-workflow-algebra-mutant: RED replace-primary primary-failure"
  unless (vectorList (Algebra.topologyDemand topology) == Oracle.oracleDemand (Oracle.expectedBranchDemands !! 2)) $
    die "test-workflow-algebra-mutant: RED drop-provider-debit quota-demand"
  unless (Algebra.authorityRef "secret:plaintext" == Nothing) $
    die "test-workflow-algebra-mutant: RED allow-secret authority-reference"
  let incomplete = Algebra.InventoryModel (init allDomains) []
  unless (Algebra.classifyResidue incomplete incomplete == Algebra.IncompleteInventoryDomains [Algebra.AcceleratorInventory]) $
    die "test-workflow-algebra-mutant: RED drop-inventory-domain completeness"
  unless (Algebra.deriveEvidence topology ==
    [ Algebra.EvidenceRow Algebra.ExtractMove Algebra.PureProven
    , Algebra.EvidenceRow Algebra.ModelMove Algebra.ModelChecked
    , Algebra.EvidenceRow (Algebra.InjectMove Algebra.DelegatedFailover) Algebra.RuntimeUnverified
    ]) $
    die "test-workflow-algebra-mutant: RED upgrade-runtime evidence-strength"

checkConstructorDiscovery :: IO ()
checkConstructorDiscovery = do
  assertEqual "branch discovery" [minBound .. maxBound] allBranches
  assertEqual "axis discovery" [minBound .. maxBound] allAxes
  assertEqual "inventory discovery" [minBound .. maxBound] allDomains
  assertEqual "fault discovery" [minBound .. maxBound] allFaults
  assert (not (null allBranches) && not (null allAxes) && not (null allDomains) && not (null allFaults)) "empty constructor discovery"

checkSuggestions :: IO ()
checkSuggestions = do
  assertEqual "independent branch count" 5 (length Oracle.expectedBranchDemands)
  forM_ (zip allBranches Oracle.expectedBranchDemands) $ \(branch, expected) -> do
    topology <- requireRight "exact-fit suggestion" (Algebra.suggestTest (model (Oracle.oracleBranchName expected) branch (vectorFromList (Oracle.oracleDemand expected)) []))
    assertEqual "branch demand" (Oracle.oracleDemand expected) (vectorList (Algebra.topologyDemand topology))
    assertEqual "test-owned result" Algebra.TestOwnedIntent (Algebra.topologyOwnership topology)
  let coreDemand = vectorFromList coreOracleDemand
  forM_ allAxes $ \axis ->
    assertEqual ("one-short " <> show axis) (Left (Algebra.Insufficient axis))
      (Algebra.suggestTest (model "one-short" Algebra.CoreBranch (shorten axis coreDemand) []))
  reference <- requireJust "ordinary authority reference" (Algebra.authorityRef "authority/ordinary")
  assertEqual "ordinary authority refused" (Left Algebra.FlaggedTestAuthorityRequired)
    (Algebra.suggestTest ((model "ordinary" Algebra.CoreBranch ample []) {Algebra.suppliedAuthority = Algebra.OrdinaryAuthority reference}))
  assertEqual "missing ownership refused" (Left Algebra.TestOwnershipRequired)
    (Algebra.suggestTest ((model "missing-owner" Algebra.CoreBranch ample []) {Algebra.suppliedOwnership = Nothing}))
  assertEqual "ordinary ownership refused" (Left Algebra.TestOwnershipRequired)
    (Algebra.suggestTest ((model "ordinary-owner" Algebra.CoreBranch ample []) {Algebra.suppliedOwnership = Just Algebra.OrdinaryOwnedIntent}))
  assertEqual "empty authority refused" Nothing (Algebra.authorityRef "")
  assertEqual "token authority refused" Nothing (Algebra.authorityRef "token:plaintext")
  assertEqual "password authority refused" Nothing (Algebra.authorityRef "password:plaintext")

checkTerminalFold :: IO ()
checkTerminalFold = do
  topology <- requireRight "terminal topology" (Algebra.suggestTest (model "terminal" Algebra.CoreBranch ample []))
  let actual =
        [ Oracle.OracleTerminal workflow teardown (renderTerminal (Algebra.terminalResult (Algebra.observeTeardown workflowValue teardownValue topology)))
        | (workflow, workflowValue) <- workflowCases
        , (teardown, teardownValue) <- teardownCases
        ]
      selected = [row | row <- actual, (Oracle.oracleWorkflow row, Oracle.oracleTeardown row) `elem` [(Oracle.oracleWorkflow wanted, Oracle.oracleTeardown wanted) | wanted <- Oracle.expectedTerminalCases]]
  assertEqual "independent terminal cases" Oracle.expectedTerminalCases selected

checkInventory :: IO ()
checkInventory = do
  assertEqual "independent inventory domain names" Oracle.expectedInventoryDomains (map renderDomain allDomains)
  let retained = Algebra.ModeledResource Algebra.StorageInventory "retained"
      postOnly = Algebra.ModeledResource Algebra.RegistryInventory "post-only"
      before = Algebra.InventoryModel allDomains [retained]
  assertEqual "clean modeled inventory" Algebra.CleanModeledInventory (Algebra.classifyResidue before before)
  assertEqual "post-only residue" (Algebra.PostOnlyModeledResidue [postOnly])
    (Algebra.classifyResidue before (Algebra.InventoryModel allDomains [retained, postOnly]))
  assertEqual "retained is not residue" Algebra.CleanModeledInventory
    (Algebra.classifyResidue before (Algebra.InventoryModel allDomains [retained]))
  assertEqual "missing domain" (Algebra.IncompleteInventoryDomains [Algebra.AcceleratorInventory])
    (Algebra.classifyResidue (Algebra.InventoryModel (init allDomains) []) (Algebra.InventoryModel (init allDomains) []))

checkEvidence :: IO ()
checkEvidence = do
  topology <- requireRight "evidence topology" (Algebra.suggestTest (model "evidence" Algebra.CoreBranch ample allFaults))
  assertEqual "derived applicable evidence"
    [ Algebra.EvidenceRow Algebra.ExtractMove Algebra.PureProven
    , Algebra.EvidenceRow Algebra.ModelMove Algebra.ModelChecked
    , Algebra.EvidenceRow (Algebra.InjectMove Algebra.DelegatedFailover) Algebra.RuntimeUnverified
    , Algebra.EvidenceRow (Algebra.InjectMove Algebra.StorageInterruption) Algebra.RuntimeUnverified
    ]
    (Algebra.deriveEvidence topology)

checkProjection :: FilePath -> FilePath -> Text -> IO ()
checkProjection root output runIdentity = do
  topology <- requireRight "projection topology" (Algebra.suggestTest (model "oracle-projection" Algebra.CoreBranch ample [Algebra.DelegatedFailover]))
  let bytes = Algebra.renderSuggestedTopology topology
  assertEqual "independent projection lines" Oracle.expectedProjectionLines (Text.lines bytes)
  first <- materialize output (runIdentity <> "-first") topology
  second <- materialize output (runIdentity <> "-second") topology
  firstBytes <- TextIO.readFile first
  secondBytes <- TextIO.readFile second
  assertEqual "cache-bypassed projection bytes" firstBytes secondBytes
  assertEqual "projection bytes" bytes firstBytes
  assert (belowBuild root first && belowBuild root second) "projection escaped .build"

materialize :: FilePath -> Text -> Algebra.TestTopology state -> IO FilePath
materialize output runIdentity topology = do
  let destination = output </> Algebra.projectionRelativePath runIdentity topology
  createDirectoryIfMissing True (takeDirectory destination)
  TextIO.writeFile destination (Algebra.renderSuggestedTopology topology)
  present <- doesFileExist destination
  assert present ("projection absent: " <> destination)
  pure destination

checkCalculus :: IO ()
checkCalculus = do
  tenant <- requireRight "calculus tenant" (CalculusScope.trustedTenant "test-workflow-calculus-tenant")
  subject <- requireRight "calculus subject" (CalculusScope.trustedSubject tenant "test-workflow-calculus-subject")
  membership <- requireRight "calculus membership" (CalculusScope.activeMembership tenant subject)
  action <- requireRight "calculus request scope" $
    CalculusScope.withRequestScope tenant subject membership $ \scope -> do
      let resources count = Capacity.ResourceVector 1 count 0 0
          artifact = artifactComponent scope "test-topology-projection" (resources 5) (RecipeId "test-workflow-algebra" 5)
          budget = budgetComponent scope "supplied-model-budget" (resources 9) (allowance (Bytes 1) (Slots 1) (Bytes 1))
          lift = liftComponent scope "pure-suggestion" (resources 5) OnHost
          workflow = workflowComponent scope "teardown-obligation" (resources 6) emptyLedger
          evidence = evidenceComponent scope "honest-ledger" (resources 6) PureRegister
          composition = append (compose artifact budget) (append (compose lift workflow) (singleton evidence))
          Capacity.ResourceVector cpu memory ephemeral pods = compositionResource composition
      assertEqual "five calculus kinds" everyCalculus (compositionKinds composition)
      assertEqual "calculus tags" ["artifact", "budget", "lift", "workflow", "evidence"] (map calculusTag (compositionKinds composition))
      assertEqual "calculus names" ["test-topology-projection", "supplied-model-budget", "pure-suggestion", "teardown-obligation", "honest-ledger"] (compositionNames composition)
      assertEqual "calculus resource" (Capacity.ResourceVector 5 31 0 0) (Capacity.ResourceVector cpu memory ephemeral pods)
  action

model :: Text -> Algebra.Branch -> Algebra.ResourceVector -> [Algebra.FaultIntent] -> Algebra.SuppliedTestModel
model name branch capacity faults = Algebra.SuppliedTestModel
  name Algebra.LinuxCpu branch (Algebra.FlaggedTestAuthority validAuthority) (Just Algebra.TestOwnedIntent)
  capacity faults [Algebra.WorkflowCompletes, Algebra.CleanupObserved, Algebra.NoModeledResidue]

validAuthority :: Algebra.AuthorityRef
validAuthority = fromJust (Algebra.authorityRef "authority/test-workflow")

ample :: Algebra.ResourceVector
ample = Algebra.ResourceVector 10000 20000000000 70000000000 10000000000 5000000000 32 32 8 100

allBranches :: [Algebra.Branch]
allBranches = [minBound .. maxBound]
allAxes :: [Algebra.ResourceAxis]
allAxes = [minBound .. maxBound]
allDomains :: [Algebra.InventoryDomain]
allDomains = [minBound .. maxBound]
allFaults :: [Algebra.FaultIntent]
allFaults = [minBound .. maxBound]

coreOracleDemand :: [Integer]
coreOracleDemand = case Oracle.expectedBranchDemands of
  first : _ -> Oracle.oracleDemand first
  [] -> error "independent branch oracle is empty"

vectorList :: Algebra.ResourceVector -> [Integer]
vectorList vector = map fromIntegral
  [ Algebra.resourceCpu vector, Algebra.resourceMemory vector, Algebra.resourceEphemeral vector
  , Algebra.resourceDurable vector, Algebra.resourceCache vector, Algebra.resourcePods vector
  , Algebra.resourceIps vector, Algebra.resourceCsi vector, Algebra.resourceQuota vector
  ]

vectorFromList :: [Integer] -> Algebra.ResourceVector
vectorFromList values = case map fromIntegral values of
  [cpu, memory, ephemeral, durable, cache, pods, ips, csi, quota] -> Algebra.ResourceVector cpu memory ephemeral durable cache pods ips csi quota
  _ -> error "independent oracle supplied a non-nine-axis vector"

shorten :: Algebra.ResourceAxis -> Algebra.ResourceVector -> Algebra.ResourceVector
shorten axis vector = case axis of
  Algebra.Cpu -> vector {Algebra.resourceCpu = Algebra.resourceCpu vector - 1}
  Algebra.Memory -> vector {Algebra.resourceMemory = Algebra.resourceMemory vector - 1}
  Algebra.Ephemeral -> vector {Algebra.resourceEphemeral = Algebra.resourceEphemeral vector - 1}
  Algebra.Durable -> vector {Algebra.resourceDurable = Algebra.resourceDurable vector - 1}
  Algebra.Cache -> vector {Algebra.resourceCache = Algebra.resourceCache vector - 1}
  Algebra.Pods -> vector {Algebra.resourcePods = Algebra.resourcePods vector - 1}
  Algebra.Ips -> vector {Algebra.resourceIps = Algebra.resourceIps vector - 1}
  Algebra.Csi -> vector {Algebra.resourceCsi = Algebra.resourceCsi vector - 1}
  Algebra.Quota -> vector {Algebra.resourceQuota = Algebra.resourceQuota vector - 1}

workflowCases :: [(Text, Algebra.WorkflowOutcome)]
workflowCases = [("success", Algebra.WorkflowSucceeded), ("failure:primary", Algebra.WorkflowFailed (Algebra.Failure "primary"))]
teardownCases :: [(Text, Algebra.TeardownOutcome)]
teardownCases = [("success", Algebra.TeardownSucceeded), ("failure:cleanup", Algebra.TeardownFailed (Algebra.Failure "cleanup")), ("repeated", Algebra.TeardownRepeated)]

renderTerminal :: Algebra.TerminalResult -> Text
renderTerminal value = case value of
  Algebra.TerminalSuccess -> "success"
  Algebra.TerminalWorkflowFailure (Algebra.Failure reason) -> "workflow-failure:" <> reason
  Algebra.TerminalTeardownFailure (Algebra.Failure reason) -> "teardown-failure:" <> reason
  Algebra.TerminalRepeatedTeardown -> "repeated-teardown"

renderDomain :: Algebra.InventoryDomain -> Text
renderDomain value = case value of
  Algebra.RegistryInventory -> "registry"
  Algebra.ProviderInventory -> "provider"
  Algebra.StorageInventory -> "storage"
  Algebra.RuntimeMetadataInventory -> "runtime-metadata"
  Algebra.AcceleratorInventory -> "accelerator"

validRunIdentity :: Text -> Bool
validRunIdentity value = not (Text.null value) && Text.length value <= 128 && Text.all (\c -> c == '-' || c == '_' || c == '.' || c >= '0' && c <= '9' || c >= 'A' && c <= 'Z' || c >= 'a' && c <= 'z') value

belowBuild :: FilePath -> FilePath -> Bool
belowBuild root path = case splitDirectories (makeRelative root path) of
  ".build" : _ -> True
  _ -> False

requireRight :: Show problem => String -> Either problem value -> IO value
requireRight label = either (die . ((label <> ": ") <>) . show) pure

requireJust :: String -> Maybe value -> IO value
requireJust label = maybe (die label) pure

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual = unless (expected == actual) (die (label <> ": expected " <> show expected <> ", got " <> show actual))

projectRoot :: IO FilePath
projectRoot = getCurrentDirectory >>= go
 where
  go path = do
    found <- doesFileExist (path </> "cabal.project")
    if found then makeAbsolute path else let parent = takeDirectory path in if parent == path then die "test-workflow-algebra-root" else go parent
