{-# LANGUAGE OverloadedStrings #-}

-- | Receipt-bound provider node-group materialization and join admission.
module Amoebius.Pulumi.NodeGroup
  ( NodeGroupRequest (..)
  , NodeGroupReceipt (..)
  , NodeJoinReadback (..)
  , NodeGroupError (..)
  , ValidatedNodeGroupAction
  , ManagedNode
  , validateNodeGroupAction
  , materializeManagedNode
  , managedNodeInstanceId
  , managedNodeUid
  ) where

import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)

data NodeGroupRequest = NodeGroupRequest
  { nodeRequestFingerprint :: Text
  , nodeRequestClass :: Text
  , nodeRequestOrdinal :: Natural
  , nodeRequestSchedulerGeneration :: Text
  }
  deriving stock (Eq, Show)

data NodeGroupReceipt = NodeGroupReceipt
  { nodeReceiptFingerprint :: Text
  , nodeReceiptClass :: Text
  , nodeReceiptOrdinal :: Natural
  , nodeReceiptInstanceId :: Text
  }
  deriving stock (Eq, Show)

data NodeJoinReadback = NodeJoinReadback
  { joinInstanceId :: Text
  , joinNodeUid :: Text
  , joinManagedCapacityTaint :: Bool
  , joinSupplyComplete :: Bool
  , joinLayoutComplete :: Bool
  , joinDevicesComplete :: Bool
  , joinSchedulerGeneration :: Text
  , joinIdentityAdmission :: Bool
  , joinExclusiveBinding :: Bool
  , joinForeignPods :: Natural
  }
  deriving stock (Eq, Show)

data NodeGroupError
  = EmptyNodeGroupIdentity
  | NodeReceiptMismatch
  | NodeJoinNotQuarantined
  | NodeSupplyIncomplete
  | NodeSchedulerGenerationStale
  | NodeAuthorityIncomplete
  | ForeignPodBeforeAdmission
  deriving stock (Eq, Show)

data ValidatedNodeGroupAction = ValidatedNodeGroupAction NodeGroupRequest
  deriving stock (Eq, Show)

data ManagedNode = ManagedNode Text Text
  deriving stock (Eq, Show)

validateNodeGroupAction :: NodeGroupRequest -> Either NodeGroupError ValidatedNodeGroupAction
validateNodeGroupAction request
  | any Text.null [nodeRequestFingerprint request, nodeRequestClass request, nodeRequestSchedulerGeneration request] = Left EmptyNodeGroupIdentity
  | otherwise = Right (ValidatedNodeGroupAction request)

materializeManagedNode
  :: ValidatedNodeGroupAction
  -> NodeGroupReceipt
  -> NodeJoinReadback
  -> Either NodeGroupError ManagedNode
materializeManagedNode (ValidatedNodeGroupAction request) receipt readback
  | nodeReceiptFingerprint receipt /= nodeRequestFingerprint request = Left NodeReceiptMismatch
  | nodeReceiptClass receipt /= nodeRequestClass request = Left NodeReceiptMismatch
  | nodeReceiptOrdinal receipt /= nodeRequestOrdinal request = Left NodeReceiptMismatch
  | Text.null (nodeReceiptInstanceId receipt) || joinInstanceId readback /= nodeReceiptInstanceId receipt = Left NodeReceiptMismatch
  | Text.null (joinNodeUid readback) = Left NodeReceiptMismatch
  | not (joinManagedCapacityTaint readback) = Left NodeJoinNotQuarantined
  | not (and [joinSupplyComplete readback, joinLayoutComplete readback, joinDevicesComplete readback]) = Left NodeSupplyIncomplete
  | joinSchedulerGeneration readback /= nodeRequestSchedulerGeneration request = Left NodeSchedulerGenerationStale
  | not (joinIdentityAdmission readback && joinExclusiveBinding readback) = Left NodeAuthorityIncomplete
  | joinForeignPods readback /= 0 = Left ForeignPodBeforeAdmission
  | otherwise = Right (ManagedNode (nodeReceiptInstanceId receipt) (joinNodeUid readback))

managedNodeInstanceId :: ManagedNode -> Text
managedNodeInstanceId (ManagedNode instanceId _) = instanceId

managedNodeUid :: ManagedNode -> Text
managedNodeUid (ManagedNode _ uid) = uid
