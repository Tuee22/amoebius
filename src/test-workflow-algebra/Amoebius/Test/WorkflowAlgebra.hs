{-# LANGUAGE CPP #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Test.WorkflowAlgebra
  ( Branch (..)
  , CarriesTeardown
  , EvidenceRow (..)
  , EvidenceStrength (..)
  , MissingTeardown
  , ResourceAxis (..)
  , ResourceVector (..)
  , SealedWorkflow
  , SuggestionError (..)
  , TestCredential (..)
  , TestSubstrate (..)
  , Teardown (..)
  , Workflow
  , WorkflowDeclaration (..)
  , attachTeardown
  , beginWorkflow
  , deriveEvidence
  , renderSuggestedWorkflow
  , sealWorkflow
  , sealedWorkflowName
  , suggestWorkflow
  , workflowDemand
  , workflowSubscription
  ) where

import Data.Text (Text)
import Data.Text qualified as Text
import Data.Word (Word64)

data MissingTeardown
data CarriesTeardown

data TestSubstrate = LinuxCpu | LinuxCuda | Apple | Windows
  deriving stock (Eq, Ord, Show, Enum, Bounded)

data Branch = CoreBranch | RegistryBranch | ProviderBranch | MigrationBranch
  deriving stock (Eq, Ord, Show, Enum, Bounded)

data ResourceAxis = Cpu | Memory | Ephemeral | Durable | Cache | Pods | Ips | Csi | Quota
  deriving stock (Eq, Ord, Show, Enum, Bounded)

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

data TestCredential = TestCredential
  { credentialSecretRef :: Text
  , credentialFlagged :: Bool
  }
  deriving stock (Eq, Show)

data WorkflowDeclaration = WorkflowDeclaration
  { declarationName :: Text
  , declarationSubstrate :: TestSubstrate
  , declarationBranch :: Branch
  , declarationCredential :: TestCredential
  , declarationSupply :: ResourceVector
  }
  deriving stock (Eq, Show)

newtype Teardown = Teardown Text
  deriving stock (Eq, Show)

data WorkflowBody = WorkflowBody
  { bodyDeclaration :: WorkflowDeclaration
  , bodyDemand :: ResourceVector
  , bodySubscription :: Text
  , bodyTeardown :: Maybe Teardown
  }
  deriving stock (Eq, Show)

newtype Workflow state = Workflow WorkflowBody
  deriving stock (Eq, Show)

newtype SealedWorkflow = SealedWorkflow WorkflowBody
  deriving stock (Eq, Show)

data SuggestionError
  = FlaggedCredentialRequired
  | NamedSecretRequired
  | Insufficient ResourceAxis
  deriving stock (Eq, Show)

data EvidenceStrength = Tested | Unverified
  deriving stock (Eq, Ord, Show)

data EvidenceRow = EvidenceRow Text EvidenceStrength
  deriving stock (Eq, Ord, Show)

beginWorkflow :: WorkflowDeclaration -> Workflow MissingTeardown
beginWorkflow declaration = Workflow WorkflowBody
  { bodyDeclaration = declaration
  , bodyDemand = requiredDemand (declarationBranch declaration)
  , bodySubscription = delegatedSubscription
  , bodyTeardown = Nothing
  }

attachTeardown :: Teardown -> Workflow MissingTeardown -> Workflow CarriesTeardown
attachTeardown teardown (Workflow body) = Workflow body {bodyTeardown = Just teardown}

sealWorkflow ::
#ifdef PHASE54_SKIP_TEARDOWN_MUTANT
  Workflow state -> SealedWorkflow
#else
  Workflow CarriesTeardown -> SealedWorkflow
#endif
sealWorkflow (Workflow body) = SealedWorkflow body

suggestWorkflow :: WorkflowDeclaration -> Either SuggestionError (Workflow MissingTeardown)
suggestWorkflow declaration = do
  let credential = declarationCredential declaration
      demand = requiredDemand (declarationBranch declaration)
  if credentialFlagged credential then Right () else Left FlaggedCredentialRequired
  if credentialSecretRef credential == "" then Left NamedSecretRequired else Right ()
  checkSupply (declarationSupply declaration) demand
  Right (beginWorkflow declaration)

workflowDemand :: Workflow state -> ResourceVector
workflowDemand (Workflow body) = bodyDemand body

workflowSubscription :: Workflow state -> Text
workflowSubscription (Workflow body) = bodySubscription body

sealedWorkflowName :: SealedWorkflow -> Text
sealedWorkflowName (SealedWorkflow body) = declarationName (bodyDeclaration body)

deriveEvidence :: SealedWorkflow -> [EvidenceRow]
deriveEvidence (SealedWorkflow body) =
#ifdef PHASE54_ALL_TESTED_MUTANT
  [ EvidenceRow "StandbyTakesOver" Tested
  , EvidenceRow "CrossZoneContinuity" Tested
  ]
#else
  [ EvidenceRow "StandbyTakesOver" standbyStrength
  , EvidenceRow "CrossZoneContinuity" Unverified
  ]
 where
  standbyStrength
    | bodySubscription body == "test-workflow-failover" = Tested
    | otherwise = Unverified
#endif

renderSuggestedWorkflow :: Workflow state -> Text
renderSuggestedWorkflow (Workflow body) = Text.intercalate "\n"
  [ "name=" <> declarationName declaration
  , "substrate=" <> Text.pack (show (declarationSubstrate declaration))
  , "branch=" <> Text.pack (show (declarationBranch declaration))
  , "secret-ref=" <> credentialSecretRef (declarationCredential declaration)
  , "subscription=" <> bodySubscription body
  , "demand=" <> renderVector (bodyDemand body)
  ]
 where
  declaration = bodyDeclaration body

requiredDemand :: Branch -> ResourceVector
requiredDemand branch = case branch of
  CoreBranch -> ResourceVector 3000 3221225472 8589934592 1073741824 536870912 4 4 1 1
  RegistryBranch -> ResourceVector 3500 4294967296 12884901888 3221225472 536870912 5 5 2 2
  ProviderBranch -> ResourceVector 4000 5368709120 12884901888 2147483648 1073741824 6 6 3 8
  MigrationBranch -> ResourceVector 4500 6442450944 17179869184 4294967296 536870912 7 7 4 4

delegatedSubscription :: Text
#ifdef PHASE54_WRONG_SUBSCRIPTION_MUTANT
delegatedSubscription = "wrong-subscription"
#else
delegatedSubscription = "test-workflow-failover"
#endif

checkSupply :: ResourceVector -> ResourceVector -> Either SuggestionError ()
checkSupply supply demand = checkAxes [minBound .. maxBound]
 where
  checkAxes [] = Right ()
  checkAxes (axis : rest)
#ifdef PHASE54_TAG_QUERY_MUTANT
    | axis == Cpu = checkAxes rest
#endif
    | at axis demand <= at axis supply = checkAxes rest
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
renderVector vector = Text.intercalate "," (fmap (Text.pack . show)
  [ resourceCpu vector
  , resourceMemory vector
  , resourceEphemeral vector
  , resourceDurable vector
  , resourceCache vector
  , resourcePods vector
  , resourceIps vector
  , resourceCsi vector
  , resourceQuota vector
  ])
