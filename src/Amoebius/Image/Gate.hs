{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Pure verdict for the Phase-26 no-public-registry-pull negative control.
module Amoebius.Image.Gate
  ( RegistryDenialMechanism (..)
  , PublicRegistryDenyPlan (..)
  , ObservedRegistryPullGate (..)
  , RegistryPullGateReceipt (..)
  , RegistryPullGateError (..)
  , validateRegistryPullGate
  , renderRegistryPullGateError
  ) where

import Control.DeepSeq (NFData)
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data RegistryDenialMechanism
  = EnforcingNodeFirewall
  | KindnetNetworkPolicy
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data PublicRegistryDenyPlan = PublicRegistryDenyPlan
  { publicRegistryDenialMechanism :: RegistryDenialMechanism
  , publicRegistryEndpointNames :: Set Text
  , publicRegistryResolvedAddresses :: Set Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ObservedRegistryPullGate = ObservedRegistryPullGate
  { observedPublicCanaryPhase :: Text
  , observedPublicCanaryReasons :: Set Text
  , observedFirewallDroppedPackets :: Natural
  , observedInClusterPullSucceeded :: Bool
  , observedInClusterIndexDigest :: Text
  , observedExpectedIndexDigest :: Text
  , observedStandupPublicTcpConnections :: Natural
  , observedPublicationPublicTcpConnections :: Natural
  , observedRerunMutatingRequests :: Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data RegistryPullGateReceipt = RegistryPullGateReceipt
  { registryPullGateEndpointCount :: Natural
  , registryPullGateAddressCount :: Natural
  , registryPullGateDroppedPackets :: Natural
  , registryPullGateIndexDigest :: Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data RegistryPullGateError
  = PublicRegistryEndpointSetEmpty
  | PublicRegistryAddressSetEmpty
  | PublicRegistryDenialNotEnforcing
  | PublicPullCanaryUnexpectedlySucceeded Text
  | PublicPullCanaryReasonMismatch (Set Text)
  | PublicRegistryFirewallUnexercised
  | InClusterRegistryPullFailed
  | InClusterRegistryDigestMismatch Text Text
  | PublicRegistryConnectionObserved Natural Natural
  | RegistryRerunMutated Natural
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

validateRegistryPullGate
  :: PublicRegistryDenyPlan
  -> ObservedRegistryPullGate
  -> Either RegistryPullGateError RegistryPullGateReceipt
validateRegistryPullGate plan observed = do
  if Set.null (publicRegistryEndpointNames plan)
    then Left PublicRegistryEndpointSetEmpty
    else Right ()
  if Set.null (publicRegistryResolvedAddresses plan)
    then Left PublicRegistryAddressSetEmpty
    else Right ()
  validateMechanism (publicRegistryDenialMechanism plan)
  if observedPublicCanaryPhase observed `elem` ["ErrImagePull", "ImagePullBackOff"]
    then Right ()
    else Left (PublicPullCanaryUnexpectedlySucceeded (observedPublicCanaryPhase observed))
  let reasons = observedPublicCanaryReasons observed
  if not (Set.null (Set.intersection reasons (Set.fromList ["ErrImagePull", "ImagePullBackOff"])))
      && any (Text.isInfixOf "timeout") reasons
    then Right ()
    else Left (PublicPullCanaryReasonMismatch reasons)
  if observedFirewallDroppedPackets observed > 0
    then Right ()
    else Left PublicRegistryFirewallUnexercised
  if observedInClusterPullSucceeded observed
    then Right ()
    else Left InClusterRegistryPullFailed
  if observedInClusterIndexDigest observed == observedExpectedIndexDigest observed
    then Right ()
    else Left (InClusterRegistryDigestMismatch (observedExpectedIndexDigest observed) (observedInClusterIndexDigest observed))
  if observedStandupPublicTcpConnections observed == 0
      && observedPublicationPublicTcpConnections observed == 0
    then Right ()
    else Left (PublicRegistryConnectionObserved (observedStandupPublicTcpConnections observed) (observedPublicationPublicTcpConnections observed))
  if observedRerunMutatingRequests observed == 0
    then Right ()
    else Left (RegistryRerunMutated (observedRerunMutatingRequests observed))
  pure
    RegistryPullGateReceipt
      { registryPullGateEndpointCount = fromIntegral (Set.size (publicRegistryEndpointNames plan))
      , registryPullGateAddressCount = fromIntegral (Set.size (publicRegistryResolvedAddresses plan))
      , registryPullGateDroppedPackets = observedFirewallDroppedPackets observed
      , registryPullGateIndexDigest = observedInClusterIndexDigest observed
      }

renderRegistryPullGateError :: RegistryPullGateError -> Text
renderRegistryPullGateError problem = case problem of
  PublicRegistryEndpointSetEmpty -> "PublicRegistryEndpointSetEmpty"
  PublicRegistryAddressSetEmpty -> "PublicRegistryAddressSetEmpty"
  PublicRegistryDenialNotEnforcing -> "PublicRegistryDenialNotEnforcing"
  PublicPullCanaryUnexpectedlySucceeded _ -> "PublicPullCanaryUnexpectedlySucceeded"
  PublicPullCanaryReasonMismatch _ -> "PublicPullCanaryReasonMismatch"
  PublicRegistryFirewallUnexercised -> "PublicRegistryFirewallUnexercised"
  InClusterRegistryPullFailed -> "InClusterRegistryPullFailed"
  InClusterRegistryDigestMismatch _ _ -> "InClusterRegistryDigestMismatch"
  PublicRegistryConnectionObserved _ _ -> "PublicRegistryConnectionObserved"
  RegistryRerunMutated _ -> "RegistryRerunMutated"

validateMechanism :: RegistryDenialMechanism -> Either RegistryPullGateError ()
#ifdef BASE_IMAGE_REGISTRY_NOOP_EGRESS_POLICY_MUTANT
validateMechanism _ = Right ()
#else
validateMechanism mechanism = case mechanism of
  EnforcingNodeFirewall -> Right ()
  KindnetNetworkPolicy -> Left PublicRegistryDenialNotEnforcing
#endif
