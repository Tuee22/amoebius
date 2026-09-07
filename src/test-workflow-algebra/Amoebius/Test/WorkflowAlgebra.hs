{-# LANGUAGE CPP #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Test.WorkflowAlgebra
  ( AuthorityIntent (..)
  , AuthorityRef
  , Branch (..)
  , EvidenceMove (..)
  , EvidenceRow (..)
  , EvidenceStrength (..)
  , Expectation (..)
  , Failure (..)
  , FaultIntent (..)
  , InventoryDomain (..)
  , InventoryModel (..)
  , ModeledResource (..)
  , OwnershipIntent (..)
  , ResourceAxis (..)
  , ResourceVector (..)
  , ResidueClassification (..)
  , SuggestionRefusal (..)
  , SuppliedTestModel (..)
  , TerminalResult (..)
  , TestSubstrate (..)
  , TestTopology
  , TeardownObserved
  , TeardownOutcome (..)
  , TeardownPending
  , WorkflowOutcome (..)
  , authorityRef
  , classifyResidue
  , deriveEvidence
  , observeTeardown
  , projectionRelativePath
  , renderSuggestedTopology
  , suggestTest
  , terminalResult
  , topologyDemand
  , topologyName
  , topologyOwnership
  , topologyTeardownRequired
  ) where

import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString qualified as ByteString
import Data.Char (intToDigit)
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Word (Word64)

data TeardownPending
data TeardownObserved

data TestSubstrate = LinuxCpu | LinuxCuda | Apple | Windows
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data Branch = CoreBranch | RegistryBranch | ProviderBranch | MigrationBranch | AcceleratorBranch
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data ResourceAxis = Cpu | Memory | Ephemeral | Durable | Cache | Pods | Ips | Csi | Quota
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data ResourceVector = ResourceVector
  { resourceCpu :: Word64
  , resourceMemory :: Word64
  , resourceEphemeral :: Word64
  , resourceDurable :: Word64
  , resourceCache :: Word64
  , resourcePods :: Word64
  , resourceIps :: Word64
  , resourceCsi :: Word64
  , resourceQuota :: Word64
  }
  deriving stock (Eq, Show)

newtype AuthorityRef = AuthorityRef Text
  deriving stock (Eq, Ord, Show)

data AuthorityIntent
  = OrdinaryAuthority AuthorityRef
  | FlaggedTestAuthority AuthorityRef
  deriving stock (Eq, Ord, Show)

data OwnershipIntent = OrdinaryOwnedIntent | TestOwnedIntent
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data FaultIntent = DelegatedFailover | StorageInterruption
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data Expectation = WorkflowCompletes | PrimaryFailurePreserved | CleanupObserved | NoModeledResidue
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data SuppliedTestModel = SuppliedTestModel
  { suppliedName :: Text
  , suppliedSubstrate :: TestSubstrate
  , suppliedBranch :: Branch
  , suppliedAuthority :: AuthorityIntent
  , suppliedOwnership :: Maybe OwnershipIntent
  , suppliedCapacity :: ResourceVector
  , suppliedFaults :: [FaultIntent]
  , suppliedExpectations :: [Expectation]
  }
  deriving stock (Eq, Show)

data SuggestionRefusal
  = InvalidAuthorityReference
  | FlaggedTestAuthorityRequired
  | TestOwnershipRequired
  | Insufficient ResourceAxis
  deriving stock (Eq, Show)

data WorkflowOutcome = WorkflowSucceeded | WorkflowFailed Failure
  deriving stock (Eq, Show)

data TeardownOutcome = TeardownSucceeded | TeardownFailed Failure | TeardownRepeated
  deriving stock (Eq, Show)

newtype Failure = Failure Text
  deriving stock (Eq, Ord, Show)

data TerminalResult
  = TerminalSuccess
  | TerminalWorkflowFailure Failure
  | TerminalTeardownFailure Failure
  | TerminalRepeatedTeardown
  deriving stock (Eq, Show)

data TopologyBody = TopologyBody
  { bodyModel :: SuppliedTestModel
  , bodyDemand :: ResourceVector
  , bodyWorkflowOutcome :: Maybe WorkflowOutcome
  , bodyTeardownOutcome :: Maybe TeardownOutcome
  }
  deriving stock (Eq, Show)

newtype TestTopology state = TestTopology TopologyBody
  deriving stock (Eq, Show)

authorityRef :: Text -> Maybe AuthorityRef
authorityRef value
  | Text.null value = Nothing
#ifdef TEST_WORKFLOW_ALLOW_SECRET_MUTANT
  | otherwise = Just (AuthorityRef value)
#else
  | Text.any (`elem` ['\n', '\r', '\NUL']) value = Nothing
  | any (`Text.isPrefixOf` Text.toLower value) ["secret:", "token:", "password:"] = Nothing
  | otherwise = Just (AuthorityRef value)
#endif

suggestTest :: SuppliedTestModel -> Either SuggestionRefusal (TestTopology TeardownPending)
suggestTest model = do
  case suppliedAuthority model of
    OrdinaryAuthority _ -> Left FlaggedTestAuthorityRequired
    FlaggedTestAuthority _ -> Right ()
  case suppliedOwnership model of
    Just TestOwnedIntent -> Right ()
    _ -> Left TestOwnershipRequired
  let demand = requiredDemand (suppliedBranch model)
  checkSupply (suppliedCapacity model) demand
  Right (TestTopology (TopologyBody model demand Nothing Nothing))

topologyName :: TestTopology state -> Text
topologyName (TestTopology body) = suppliedName (bodyModel body)

topologyDemand :: TestTopology state -> ResourceVector
topologyDemand (TestTopology body) = bodyDemand body

topologyOwnership :: TestTopology state -> OwnershipIntent
topologyOwnership _ = TestOwnedIntent

topologyTeardownRequired :: TestTopology state -> Bool
#ifdef TEST_WORKFLOW_OPTIONAL_TEARDOWN_MUTANT
topologyTeardownRequired _ = False
#else
topologyTeardownRequired _ = True
#endif

observeTeardown :: WorkflowOutcome -> TeardownOutcome -> TestTopology TeardownPending -> TestTopology TeardownObserved
observeTeardown workflow teardown (TestTopology body) =
  TestTopology body {bodyWorkflowOutcome = Just workflow, bodyTeardownOutcome = Just teardown}

terminalResult :: TestTopology TeardownObserved -> TerminalResult
terminalResult (TestTopology body) =
  case (bodyWorkflowOutcome body, bodyTeardownOutcome body) of
    (Just (WorkflowFailed primary), Just (TeardownFailed cleanup)) ->
#ifdef TEST_WORKFLOW_REPLACE_PRIMARY_MUTANT
      TerminalTeardownFailure cleanup
#else
      TerminalWorkflowFailure primary
#endif
    (Just (WorkflowFailed primary), Just _) -> TerminalWorkflowFailure primary
    (Just WorkflowSucceeded, Just (TeardownFailed cleanup)) ->
#ifdef TEST_WORKFLOW_CLEANUP_SUCCESS_MUTANT
      TerminalSuccess
#else
      TerminalTeardownFailure cleanup
#endif
    (Just WorkflowSucceeded, Just TeardownRepeated) -> TerminalRepeatedTeardown
    (Just WorkflowSucceeded, Just TeardownSucceeded) -> TerminalSuccess
    _ -> TerminalTeardownFailure (Failure "internal-unobserved-teardown")

data InventoryDomain = RegistryInventory | ProviderInventory | StorageInventory | RuntimeMetadataInventory | AcceleratorInventory
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data ModeledResource = ModeledResource
  { modeledDomain :: InventoryDomain
  , modeledIdentity :: Text
  }
  deriving stock (Eq, Ord, Show)

data InventoryModel = InventoryModel
  { inventoryDomains :: [InventoryDomain]
  , inventoryResources :: [ModeledResource]
  }
  deriving stock (Eq, Show)

data ResidueClassification
  = CleanModeledInventory
  | IncompleteInventoryDomains [InventoryDomain]
  | PostOnlyModeledResidue [ModeledResource]
  deriving stock (Eq, Show)

classifyResidue :: InventoryModel -> InventoryModel -> ResidueClassification
classifyResidue before after
  | not (null missing) = IncompleteInventoryDomains missing
  | not (null postOnly) = PostOnlyModeledResidue postOnly
  | otherwise = CleanModeledInventory
 where
#ifdef TEST_WORKFLOW_DROP_INVENTORY_DOMAIN_MUTANT
  requiredDomains = init [minBound .. maxBound]
#else
  requiredDomains = [minBound .. maxBound]
#endif
  declared = sort (inventoryDomains before) == requiredDomains && sort (inventoryDomains after) == requiredDomains
  missing = if declared then [] else [domain | domain <- requiredDomains, domain `notElem` inventoryDomains before || domain `notElem` inventoryDomains after]
  postOnly = sort [resource | resource <- inventoryResources after, resource `notElem` inventoryResources before]

data EvidenceMove = ExtractMove | ModelMove | InjectMove FaultIntent
  deriving stock (Eq, Ord, Show)

data EvidenceStrength = PureProven | ModelChecked | RuntimeUnverified
  deriving stock (Eq, Ord, Show)

data EvidenceRow = EvidenceRow EvidenceMove EvidenceStrength
  deriving stock (Eq, Ord, Show)

deriveEvidence :: TestTopology state -> [EvidenceRow]
deriveEvidence (TestTopology body) =
  [EvidenceRow ExtractMove PureProven, EvidenceRow ModelMove ModelChecked]
    <> [EvidenceRow (InjectMove fault) runtimeStrength | fault <- suppliedFaults (bodyModel body)]
 where
#ifdef TEST_WORKFLOW_UPGRADE_RUNTIME_MUTANT
  runtimeStrength = ModelChecked
#else
  runtimeStrength = RuntimeUnverified
#endif

renderSuggestedTopology :: TestTopology state -> Text
renderSuggestedTopology topology@(TestTopology body) = Text.intercalate "\n"
  [ "name=" <> suppliedName model
  , "substrate=" <> renderSubstrate (suppliedSubstrate model)
  , "branch=" <> renderBranch (suppliedBranch model)
  , "authority=" <> renderAuthority (suppliedAuthority model)
  , "ownership=test-owned"
  , "teardown=required"
  , "faults=" <> Text.intercalate "," (map renderFault (suppliedFaults model))
  , "expectations=" <> Text.intercalate "," (map renderExpectation (suppliedExpectations model))
  , "demand=" <> renderVector (topologyDemand topology)
  ] <> "\n"
 where
  model = bodyModel body

projectionRelativePath :: Text -> TestTopology state -> FilePath
projectionRelativePath runIdentity topology =
  "test-corpora/test-workflow-algebra/" <> Text.unpack runIdentity <> "/" <> Text.unpack digest <> "/suggested-topology.txt"
 where
  digest = hex (SHA256.hash (TextEncoding.encodeUtf8 (renderSuggestedTopology topology)))

requiredDemand :: Branch -> ResourceVector
requiredDemand branch = case branch of
  CoreBranch -> ResourceVector 3000 3221225472 8589934592 1073741824 536870912 4 4 1 1
  RegistryBranch -> ResourceVector 3500 4294967296 12884901888 3221225472 536870912 5 5 2 2
#ifdef TEST_WORKFLOW_DROP_PROVIDER_DEBIT_MUTANT
  ProviderBranch -> ResourceVector 4000 5368709120 12884901888 2147483648 1073741824 6 6 3 1
#else
  ProviderBranch -> ResourceVector 4000 5368709120 12884901888 2147483648 1073741824 6 6 3 8
#endif
  MigrationBranch -> ResourceVector 4500 6442450944 17179869184 4294967296 536870912 7 7 4 4
  AcceleratorBranch -> ResourceVector 5000 8589934592 21474836480 2147483648 2147483648 8 8 4 6

checkSupply :: ResourceVector -> ResourceVector -> Either SuggestionRefusal ()
checkSupply supply demand = go [minBound .. maxBound]
 where
  go [] = Right ()
  go (axis : rest)
    | at axis demand <= at axis supply = go rest
    | otherwise = Left (Insufficient axis)

at :: ResourceAxis -> ResourceVector -> Word64
at axis vector = case axis of
  Cpu -> resourceCpu vector
  Memory -> resourceMemory vector
  Ephemeral -> resourceEphemeral vector
  Durable -> resourceDurable vector
  Cache -> resourceCache vector
  Pods -> resourcePods vector
  Ips -> resourceIps vector
  Csi -> resourceCsi vector
  Quota -> resourceQuota vector

renderVector :: ResourceVector -> Text
renderVector vector = Text.intercalate "," (map (Text.pack . show)
  [ resourceCpu vector, resourceMemory vector, resourceEphemeral vector
  , resourceDurable vector, resourceCache vector, resourcePods vector
  , resourceIps vector, resourceCsi vector, resourceQuota vector
  ])

renderSubstrate :: TestSubstrate -> Text
renderSubstrate value = case value of
  LinuxCpu -> "linux-cpu"
  LinuxCuda -> "linux-cuda"
  Apple -> "apple"
  Windows -> "windows"

renderBranch :: Branch -> Text
renderBranch value = case value of
  CoreBranch -> "core"
  RegistryBranch -> "registry"
  ProviderBranch -> "provider"
  MigrationBranch -> "migration"
  AcceleratorBranch -> "accelerator"

renderAuthority :: AuthorityIntent -> Text
renderAuthority value = case value of
  OrdinaryAuthority (AuthorityRef name) -> "ordinary:" <> name
  FlaggedTestAuthority (AuthorityRef name) -> "flagged-test:" <> name

renderFault :: FaultIntent -> Text
renderFault value = case value of
  DelegatedFailover -> "delegated-failover"
  StorageInterruption -> "storage-interruption"

renderExpectation :: Expectation -> Text
renderExpectation value = case value of
  WorkflowCompletes -> "workflow-completes"
  PrimaryFailurePreserved -> "primary-failure-preserved"
  CleanupObserved -> "cleanup-observed"
  NoModeledResidue -> "no-modeled-residue"

hex :: ByteString.ByteString -> Text
hex = Text.pack . concatMap renderByte . ByteString.unpack
 where
  renderByte byte = [intToDigit (fromIntegral byte `div` 16), intToDigit (fromIntegral byte `mod` 16)]
