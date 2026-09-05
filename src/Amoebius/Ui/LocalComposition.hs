{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Ui.LocalComposition
  ( CompositionMutant (..)
  , CompositionRequest (..)
  , CompositionResponse (..)
  , DomainEffect (..)
  , ReadyArtifactHandle (..)
  , compiledCompositionMutant
  , pairedPlanIdentity
  , runCompositionRequest
  ) where

import Data.Text (Text)

data CompositionMutant = CompositionClean | DropHandleTenant | DirectWorkflowFetch | MixClientServerPlan | ReadyBeforeReceipt | OwnerKeySwap
  deriving (Eq, Show)

data ReadyArtifactHandle = ReadyArtifactHandle
  { handleTenant :: Text
  , handleOwner :: Text
  , handleReceiptReady :: Bool
  , handleArtifactIdentity :: Text
  }
  deriving (Eq, Show)

data CompositionRequest = StartWorkflow Text | ObserveWorkflow Text ReadyArtifactHandle | UseArtifact ReadyArtifactHandle Text | DirectDomainRequest
  deriving (Eq, Show)

data CompositionResponse = CompositionResponse
  { compositionStatus :: Int
  , compositionTag :: Text
  , compositionVisible :: Text
  }
  deriving (Eq, Show)

data DomainEffect = DomainEffect
  { effectBoundary :: Text
  , effectValue :: Text
  , effectTenant :: Text
  , effectSubject :: Text
  }
  deriving (Eq, Show)

compiledCompositionMutant :: CompositionMutant
#if defined(UI_LOCAL_DROP_HANDLE_TENANT_MUTANT)
compiledCompositionMutant = DropHandleTenant
#elif defined(UI_LOCAL_DIRECT_WORKFLOW_FETCH_MUTANT)
compiledCompositionMutant = DirectWorkflowFetch
#elif defined(UI_LOCAL_MIX_CLIENT_SERVER_PLAN_MUTANT)
compiledCompositionMutant = MixClientServerPlan
#elif defined(UI_LOCAL_READY_BEFORE_RECEIPT_MUTANT)
compiledCompositionMutant = ReadyBeforeReceipt
#elif defined(UI_LOCAL_OWNER_KEY_SWAP_MUTANT)
compiledCompositionMutant = OwnerKeySwap
#else
compiledCompositionMutant = CompositionClean
#endif

pairedPlanIdentity :: CompositionMutant -> Text -> Text -> Bool
pairedPlanIdentity mutant clientDigest serverDigest = clientDigest == effectiveServerDigest
 where
  effectiveServerDigest
    | mutant == MixClientServerPlan = serverDigest <> "-mixed"
    | otherwise = serverDigest

runCompositionRequest :: CompositionMutant -> Text -> Text -> CompositionRequest -> (CompositionResponse, [DomainEffect])
runCompositionRequest mutant tenant subject request = case request of
  StartWorkflow challenge ->
    accepted 202 "WorkflowStarted" "Workflow running" [DomainEffect "ui-server" ("workflow-start:" <> challenge) tenant subject]
  ObserveWorkflow challenge handle
    | handleReady mutant handle ->
        accepted 200 "ArtifactReady" "Artifact ready" [DomainEffect "fake-workflow" ("workflow-ready:" <> challenge) tenant subject]
    | otherwise -> refused 409 "NotReady"
  UseArtifact handle challenge
    | not (handleReady mutant handle) -> refused 409 "NotReady"
    | not (tenantMatches mutant tenant handle) -> refused 404 "Unavailable"
    | not (ownerMatches mutant subject handle) -> refused 404 "Unavailable"
    | otherwise ->
        accepted 200 "ArtifactUsed" ("Result " <> challenge) [DomainEffect "ui-server" ("artifact-use:" <> challenge) tenant subject]
  DirectDomainRequest
    | mutant == DirectWorkflowFetch ->
        accepted 200 "BypassAccepted" "provider-bytes" [DomainEffect "browser" "direct-workflow-fetch" tenant subject]
    | otherwise -> refused 403 "BypassDenied"
 where
  accepted status tag visible effects = (CompositionResponse status tag visible, effects)
  refused status tag = (CompositionResponse status tag "Unavailable", [])

handleReady :: CompositionMutant -> ReadyArtifactHandle -> Bool
handleReady mutant handle = handleReceiptReady handle || mutant == ReadyBeforeReceipt

tenantMatches :: CompositionMutant -> Text -> ReadyArtifactHandle -> Bool
tenantMatches mutant tenant handle = tenant == handleTenant handle || mutant == DropHandleTenant

ownerMatches :: CompositionMutant -> Text -> ReadyArtifactHandle -> Bool
ownerMatches mutant subject handle = subject == handleOwner handle || mutant == OwnerKeySwap
