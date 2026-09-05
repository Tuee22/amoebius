{-# LANGUAGE CPP #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Dsl.IllegalStateCovering
  ( ForeclosureLayer (..)
  , ValidationLocus (..)
  , CaseFamily (..)
  , CatalogRow (..)
  , catalogRows
  , catalogProjection
  , isReached
  , disposition
  , StructuralCase (..)
  , structuralCases
  , DecodeError (..)
  , DecodeInput (..)
  , DecodeCase (..)
  , decodeCases
  , validateDecode
  , Tenant (..)
  , Ref (..)
  , acceptTenantRef
  , VolumeName (..)
  , Pv (..)
  , Pvc (..)
  , bindVolume
  , EndpointKind (..)
  , Endpoint (..)
  , acceptTlsEndpoint
  , ServiceState (..)
  , ServiceHandle (..)
  , buildRoute
  , Encoding (..)
  , Payload (..)
  , producePayload
  , SmartFamily (..)
  , smartConstructorClosed
  , roundTrip
  , totalFold
  , composeFragments
  , rke2ServerCounts
  ) where

import Data.List (nub)
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)

data ForeclosureLayer = TypeForeclosed | DecodeForeclosed | RuntimeChecked
  deriving stock (Eq, Ord, Show)

data ValidationLocus
  = DhallTypecheck
  | GadtDecode
  | ProvisionSeal
  | RenderedArtifactOracle
  | LiveEffect
  | ExtensionAstcheck
  deriving stock (Eq, Ord, Show)

data CaseFamily
  = Storage | Security | Topology | Capacity | CapabilityProvision | Messaging
  | MlAsset | Lifecycle | Accelerator | Multicluster | Backup | Image | Ui
  deriving stock (Eq, Ord, Show)

data CatalogRow = CatalogRow
  { catalogEntry :: Text
  , catalogSubcase :: Text
  , catalogLayer :: ForeclosureLayer
  , catalogLocus :: ValidationLocus
  , catalogOwnerPhase :: Int
  , catalogFamily :: CaseFamily
  }
  deriving stock (Eq, Ord, Show)

row :: Text -> Text -> ForeclosureLayer -> ValidationLocus -> Int -> CaseFamily -> CatalogRow
row = CatalogRow

catalogRows :: [CatalogRow]
catalogRows =
  [ row "3.1" "default" TypeForeclosed DhallTypecheck 60 Storage
  , row "3.2" "pv-pvc-index" TypeForeclosed GadtDecode 27 Storage
  , row "3.3" "live-service-route-index" TypeForeclosed GadtDecode 27 Security
  , row "3.4" "service-derived-address" TypeForeclosed GadtDecode 33 Security
  , row "3.5" "schedulability" DecodeForeclosed ProvisionSeal 9 Topology
  , row "3.6" "dependency-policy" TypeForeclosed GadtDecode 33 Security
  , row "3.7" "closed-ingress-shape" TypeForeclosed DhallTypecheck 27 Security
  , row "3.7" "endpoint-kind-index" TypeForeclosed GadtDecode 27 Security
  , row "3.8" "tenant-index" TypeForeclosed GadtDecode 27 Security
  , row "3.9" "envelope-handle" TypeForeclosed GadtDecode 61 Security
  , row "3.10" "owner-index" TypeForeclosed GadtDecode 27 Security
  , row "3.11" "resource-envelope" TypeForeclosed DhallTypecheck 25 Security
  , row "3.12" "capability-union" TypeForeclosed DhallTypecheck 25 CapabilityProvision
  , row "3.13" "engine-union" TypeForeclosed DhallTypecheck 9 Topology
  , row "3.14" "unsupported-bare-substrate" TypeForeclosed DhallTypecheck 27 Topology
  , row "3.15" "kind-host-cardinality" TypeForeclosed DhallTypecheck 25 Topology
  , row "3.16" "fixed-node-cardinality" TypeForeclosed DhallTypecheck 27 Topology
  , row "3.16" "distinct-hosts" DecodeForeclosed GadtDecode 27 Topology
  , row "3.17" "rolling-progress" DecodeForeclosed GadtDecode 27 Capacity
  , row "3.17" "deployment-host-resource" DecodeForeclosed GadtDecode 27 Capacity
  , row "3.17" "statefulset-once" DecodeForeclosed GadtDecode 27 Capacity
  , row "3.17" "statefulset-host-resource" DecodeForeclosed GadtDecode 27 Capacity
  , row "3.17" "daemonset-host-resource" DecodeForeclosed GadtDecode 27 Capacity
  , row "3.17" "job-host-resource" DecodeForeclosed GadtDecode 27 Capacity
  , row "3.17" "hostprocess-pod-resource" DecodeForeclosed GadtDecode 27 Capacity
  , row "3.17" "cuda-rolling" DecodeForeclosed GadtDecode 27 Capacity
  , row "3.17" "metal-deployment-policy" DecodeForeclosed GadtDecode 27 Capacity
  , row "3.17" "daemonset-both-positive" TypeForeclosed DhallTypecheck 27 Capacity
  , row "3.17" "statefulset-unsupported-feature" TypeForeclosed DhallTypecheck 27 Capacity
  , row "3.17" "statefulset-nonzero-partition" TypeForeclosed DhallTypecheck 27 Capacity
  , row "3.17" "job-missing-terminal-retention" TypeForeclosed DhallTypecheck 27 Capacity
  , row "3.18" "bounded-storage-arm" TypeForeclosed DhallTypecheck 25 Storage
  , row "3.19" "logical-physical-fit" DecodeForeclosed ProvisionSeal 28 Storage
  , row "3.20" "retention-policy" TypeForeclosed DhallTypecheck 25 Storage
  , row "3.21" "scaling-policy" TypeForeclosed DhallTypecheck 25 Storage
  , row "3.22" "derived-toleration" TypeForeclosed DhallTypecheck 33 Topology
  , row "3.23" "produce-codec" TypeForeclosed GadtDecode 27 Messaging
  , row "3.23" "consume-codec" DecodeForeclosed GadtDecode 27 Messaging
  , row "3.24" "rke2-server-cardinality" TypeForeclosed DhallTypecheck 25 Topology
  , row "3.25" "artifact-identity" TypeForeclosed DhallTypecheck 32 MlAsset
  , row "3.26" "promotion-evidence" TypeForeclosed GadtDecode 71 Lifecycle
  , row "3.27" "placement-witness" DecodeForeclosed ProvisionSeal 9 Capacity
  , row "3.28" "accelerator-owner" TypeForeclosed DhallTypecheck 29 Accelerator
  , row "3.29" "host-demand-fit" DecodeForeclosed ProvisionSeal 9 Capacity
  , row "3.30" "accelerator-memory-fit" DecodeForeclosed ProvisionSeal 29 Accelerator
  , row "3.31" "single-topology-index" TypeForeclosed GadtDecode 9 Topology
  , row "3.32" "bounded-training-retention" TypeForeclosed DhallTypecheck 28 Storage
  , row "3.33" "merge-order" TypeForeclosed DhallTypecheck 67 Messaging
  , row "3.34" "app-model-owner" DecodeForeclosed GadtDecode 69 MlAsset
  , row "3.35" "remote-networking-field" TypeForeclosed DhallTypecheck 9 Topology
  , row "3.36" "control-plane-reach" DecodeForeclosed GadtDecode 9 Topology
  , row "3.37" "managed-hybrid-arm" TypeForeclosed DhallTypecheck 9 Topology
  , row "3.38" "host-worker-reach" TypeForeclosed GadtDecode 9 Topology
  , row "3.39" "site-index" TypeForeclosed GadtDecode 9 Topology
  , row "3.40" "ingress-reach-index" TypeForeclosed GadtDecode 33 Security
  , row "3.41" "readiness-order" DecodeForeclosed GadtDecode 34 Lifecycle
  , row "3.42" "admin-capability" TypeForeclosed GadtDecode 61 Security
  , row "3.43" "monitoring-shape" TypeForeclosed DhallTypecheck 31 Capacity
  , row "3.44" "migration-drain-index" TypeForeclosed GadtDecode 75 Multicluster
  , row "3.45" "policy-owner" TypeForeclosed GadtDecode 31 CapabilityProvision
  , row "3.46" "declared-fault-target" TypeForeclosed GadtDecode 34 Lifecycle
  , row "3.47" "derived-rpo" TypeForeclosed DhallTypecheck 74 Multicluster
  , row "3.48" "distinct-clusters" DecodeForeclosed GadtDecode 74 Multicluster
  , row "3.49" "parent-scope-index" TypeForeclosed GadtDecode 74 Multicluster
  , row "3.50" "derived-failover-mode" TypeForeclosed DhallTypecheck 74 Multicluster
  , row "3.51" "closed-disposition" TypeForeclosed DhallTypecheck 74 Multicluster
  , row "3.52" "unique-dns-cluster" DecodeForeclosed GadtDecode 74 Multicluster
  , row "3.53" "backup-medium-fit" DecodeForeclosed ProvisionSeal 28 Storage
  , row "3.54" "append-only-mutation" TypeForeclosed DhallTypecheck 34 Backup
  , row "3.55" "put-only-credential" DecodeForeclosed GadtDecode 34 Backup
  , row "3.56" "manual-media-witness" TypeForeclosed GadtDecode 34 Backup
  , row "3.57" "fresh-restore-target" TypeForeclosed GadtDecode 34 Backup
  , row "3.58" "bounded-retention" TypeForeclosed DhallTypecheck 34 Backup
  , row "3.59" "failure-domain-distinctness" DecodeForeclosed GadtDecode 34 Backup
  , row "3.60" "disjoint-capacity-pool" DecodeForeclosed ProvisionSeal 28 Storage
  , row "3.61" "encrypted-backup-output" DecodeForeclosed RenderedArtifactOracle 33 Backup
  , row "3.62" "key-domain-independence" DecodeForeclosed GadtDecode 34 Backup
  , row "3.63" "verified-artifact-index" TypeForeclosed GadtDecode 34 Backup
  , row "3.64" "tenant-index" TypeForeclosed GadtDecode 34 Backup
  , row "3.65" "airgap-union" TypeForeclosed DhallTypecheck 34 Backup
  , row "3.66" "retention-floor" DecodeForeclosed GadtDecode 34 Backup
  , row "3.67" "restore-target-fit" DecodeForeclosed ProvisionSeal 28 Storage
  , row "3.68" "policy-coordinate-owner" DecodeForeclosed GadtDecode 34 Backup
  , row "3.69" "freshness-witness" RuntimeChecked LiveEffect 74 Multicluster
  , row "3.70" "cadence-bound" DecodeForeclosed GadtDecode 74 Multicluster
  , row "3.71" "derived-watermark" DecodeForeclosed GadtDecode 74 Multicluster
  , row "3.72" "headroom-over-limit" DecodeForeclosed GadtDecode 27 Capacity
  , row "3.72" "headroom-all-zero" DecodeForeclosed GadtDecode 27 Capacity
  , row "3.73" "padded-reservation-fit" DecodeForeclosed ProvisionSeal 9 Capacity
  , row "3.74" "image-catalog-union" TypeForeclosed DhallTypecheck 56 Image
  , row "3.75" "process-role" TypeForeclosed DhallTypecheck 56 Image
  , row "3.76" "build-content-union" TypeForeclosed DhallTypecheck 56 Image
  , row "3.77" "linked-extension" DecodeForeclosed GadtDecode 56 Image
  , row "3.78" "extension-source" TypeForeclosed ExtensionAstcheck 34 Lifecycle
  , row "3.79" "authorization-reference" TypeForeclosed DhallTypecheck 38 Ui
  , row "3.80" "subject-scope" TypeForeclosed GadtDecode 8 Ui
  , row "3.81" "flow-label" DecodeForeclosed GadtDecode 8 Ui
  , row "3.82" "browser-effect-union" TypeForeclosed DhallTypecheck 39 Ui
  , row "3.83" "plan-source-identity" DecodeForeclosed ProvisionSeal 40 Ui
  , row "3.84" "untrusted-model-output" TypeForeclosed DhallTypecheck 38 Ui
  , row "3.85" "non-destructive-verb" TypeForeclosed DhallTypecheck 34 Storage
  , row "3.86" "retained-coordinate" DecodeForeclosed GadtDecode 71 Storage
  , row "3.87" "monitoring-obligation" TypeForeclosed DhallTypecheck 31 Capacity
  , row "3.88" "migration-owner" TypeForeclosed DhallTypecheck 75 Multicluster
  , row "3.89" "context-role-cell" TypeForeclosed DhallTypecheck 55 Topology
  , row "3.90" "role-indexed-cardinality" TypeForeclosed DhallTypecheck 55 Topology
  , row "3.91" "public-route-scope" TypeForeclosed GadtDecode 43 Security
  , row "3.91" "route-mode-parity" DecodeForeclosed ProvisionSeal 43 Security
  , row "3.91" "anonymous-probe" RuntimeChecked LiveEffect 43 Security
  , row "3.92" "absent-scope-filter" TypeForeclosed GadtDecode 36 Security
  , row "3.92" "emitted-row-policy" DecodeForeclosed RenderedArtifactOracle 36 Security
  , row "3.93" "offline-session-forgery" TypeForeclosed GadtDecode 41 Security
  , row "3.93" "attestation-introduction" DecodeForeclosed ProvisionSeal 41 Security
  , row "3.93" "tampered-envelope-probe" RuntimeChecked LiveEffect 41 Security
  , row "3.94" "adjacent-id-transposition" TypeForeclosed GadtDecode 8 Security
  , row "3.95" "replay-key-scope" TypeForeclosed GadtDecode 41 Security
  , row "3.95" "replay-namespace-probe" RuntimeChecked LiveEffect 41 Security
  , row "3.96" "nullable-scope-column" DecodeForeclosed RenderedArtifactOracle 66 Security
  , row "3.96" "orphan-row-probe" RuntimeChecked LiveEffect 66 Security
  , row "3.97" "key-injectivity" DecodeForeclosed GadtDecode 36 Security
  , row "3.97" "emitted-keyspace" DecodeForeclosed RenderedArtifactOracle 36 Security
  ]

catalogProjection :: CatalogRow -> Text
catalogProjection value = Text.intercalate "|"
  [ catalogEntry value, catalogSubcase value, showText (catalogLayer value)
  , showText (catalogLocus value), Text.pack (show (catalogOwnerPhase value)), showText (catalogFamily value)
  ]

isReached :: CatalogRow -> Bool
isReached value = catalogOwnerPhase value <= 27 && catalogLocus value `elem` [DhallTypecheck, GadtDecode]

disposition :: CatalogRow -> Text
disposition value | isReached value = "discharged-here"
disposition value = "deferred:Phase-" <> Text.pack (show (catalogOwnerPhase value))

showText :: Show value => value -> Text
showText = Text.pack . show

data StructuralCase = StructuralCase Text Text Text Text Text
  deriving stock (Eq, Ord, Show)

structuralCases :: [StructuralCase]
structuralCases =
  [ structural "3.7" "closed-ingress-shape" "Backdoor" "let I = < Disabled | Tls > in I.Tls" "let I = < Disabled | Tls > in I.Backdoor"
  , structural "3.14" "unsupported-bare-substrate" "WindowsBare" "let S = < Linux | Managed > in S.Linux" "let S = < Linux | Managed > in S.WindowsBare"
  , structural "3.16" "fixed-node-cardinality" "host" "{ count = 1, host = \"h0\" }" "({ count = 1 } : { count : Natural, host : Text })"
  , structural "3.17" "daemonset-both-positive" "maxSurge" "let D = < Surge : Natural | Unavailable : Natural > in D.Surge 1" "let D = < Unavailable : Natural > in D.maxSurge 1"
  , structural "3.17" "statefulset-unsupported-feature" "PodManagementPolicy" "let P = < NativeOrdered | NativeParallel > in P.NativeOrdered" "let P = < NativeOrdered | NativeParallel > in P.PodManagementPolicy"
  , structural "3.17" "statefulset-nonzero-partition" "NativeSerialPartitionZero" "({ NativeSerialPartitionZero = 0 } : { NativeSerialPartitionZero : Natural })" "({ NativeSerialPartitionZero = 1 } : { NativeSerialPartitionZero : Text })"
  , structural "3.17" "job-missing-terminal-retention" "terminalRetention" "{ terminalRetention = 60 }" "({} : { terminalRetention : Natural })"
  ]
 where
  structural entry subcase token legal illegal =
#ifdef ILLEGAL_STATE_UNION_MUTANT
    if subcase == "closed-ingress-shape" then StructuralCase entry subcase token legal legal else StructuralCase entry subcase token legal illegal
#else
    StructuralCase entry subcase token legal illegal
#endif

data DecodeError
  = DistinctHosts | UnspellableCombination | ControllerResourceMismatch | StatefulSetRequiresRolling
  | CudaRequiresOnce | MetalRequiresHostProcess | MalformedCbor | HeadroomOverLimit | HeadroomAllZero
  deriving stock (Eq, Ord, Show)

data DecodeInput = DecodeInput
  { inputHosts :: [Text]
  , inputController :: Text
  , inputResource :: Text
  , inputProgress :: Text
  , inputAccelerator :: Text
  , inputCbor :: Bool
  , inputRequest :: Natural
  , inputLimit :: Natural
  , inputHeadroom :: Natural
  }
  deriving stock (Eq, Ord, Show)

data DecodeCase = DecodeCase Text Text DecodeError DecodeInput DecodeInput
  deriving stock (Eq, Ord, Show)

decodeCases :: [DecodeCase]
decodeCases =
  [ decode "3.16" "distinct-hosts" DistinctHosts legal {inputHosts=["h0","h0"]}
  , decode "3.17" "rolling-progress" UnspellableCombination legal {inputProgress="zero-zero"}
  , decode "3.17" "deployment-host-resource" ControllerResourceMismatch legal {inputResource="Host"}
  , decode "3.17" "statefulset-once" StatefulSetRequiresRolling legal {inputController="StatefulSet",inputProgress="Once"}
  , decode "3.17" "statefulset-host-resource" ControllerResourceMismatch legal {inputController="StatefulSet",inputResource="Host"}
  , decode "3.17" "daemonset-host-resource" ControllerResourceMismatch legal {inputController="DaemonSet",inputResource="Host"}
  , decode "3.17" "job-host-resource" ControllerResourceMismatch legal {inputController="Job",inputResource="Host"}
  , decode "3.17" "hostprocess-pod-resource" ControllerResourceMismatch legal {inputController="HostProcess",inputResource="Pod"}
  , decode "3.17" "cuda-rolling" CudaRequiresOnce legal {inputAccelerator="Cuda",inputProgress="Rolling"}
  , decode "3.17" "metal-deployment-policy" MetalRequiresHostProcess legal {inputAccelerator="Metal"}
  , decode "3.23" "consume-codec" MalformedCbor legal {inputCbor=False}
  , decode "3.72" "headroom-over-limit" HeadroomOverLimit legal {inputRequest=8,inputLimit=10,inputHeadroom=3}
  , decode "3.72" "headroom-all-zero" HeadroomAllZero legal {inputHeadroom=0}
  ]
 where
  decode entry subcase expected illegal = DecodeCase entry subcase expected legal illegal
  legal = DecodeInput ["h0","h1"] "Deployment" "Pod" "Rolling" "Cpu" True 8 10 1

validateDecode :: DecodeInput -> Either DecodeError DecodeInput
validateDecode value
  | length (inputHosts value) /= length (nub (inputHosts value)) = Left DistinctHosts
#ifndef ILLEGAL_STATE_DECODE_MUTANT
  | inputProgress value == "zero-zero" = Left UnspellableCombination
#endif
  | inputController value /= "HostProcess" && inputResource value == "Host" = Left ControllerResourceMismatch
  | inputController value == "HostProcess" && inputResource value /= "Host" = Left ControllerResourceMismatch
  | inputController value == "StatefulSet" && inputProgress value == "Once" = Left StatefulSetRequiresRolling
  | inputAccelerator value == "Cuda" && inputProgress value == "Rolling" = Left CudaRequiresOnce
  | inputAccelerator value == "Metal" && inputController value /= "HostProcess" = Left MetalRequiresHostProcess
  | not (inputCbor value) = Left MalformedCbor
  | inputHeadroom value == 0 = Left HeadroomAllZero
  | inputRequest value + inputHeadroom value > inputLimit value = Left HeadroomOverLimit
  | otherwise = Right value

data Tenant = TenantA | TenantB
data Ref (from :: Tenant) (to :: Tenant) = Ref
acceptTenantRef ::
#ifdef ILLEGAL_STATE_GADT_MUTANT
  Ref from to -> ()
#else
  Ref tenant tenant -> ()
#endif
acceptTenantRef _ = ()

data VolumeName = DataVolume | OtherVolume
data Pv (name :: VolumeName) = Pv
data Pvc (name :: VolumeName) = Pvc
bindVolume :: Pv name -> Pvc name -> ()
bindVolume _ _ = ()

data EndpointKind = TlsEndpoint | PlainEndpoint
data Endpoint (kind :: EndpointKind) = Endpoint
acceptTlsEndpoint :: Endpoint 'TlsEndpoint -> ()
acceptTlsEndpoint _ = ()

data ServiceState = LiveService | MissingService
data ServiceHandle (state :: ServiceState) = ServiceHandle
buildRoute :: ServiceHandle 'LiveService -> ()
buildRoute _ = ()

data Encoding = Cbor | Raw
data Payload (encoding :: Encoding) = Payload
producePayload :: Payload 'Cbor -> ()
producePayload _ = ()

data SmartFamily = ReplicaFamily | RolloutFamily | HeadroomFamily
  deriving stock (Eq, Ord, Show, Enum, Bounded)

smartConstructorClosed :: SmartFamily -> Natural -> Natural -> Natural -> Bool
#ifdef ILLEGAL_STATE_PROPERTY_MUTANT
smartConstructorClosed _ _ _ _ = False
#else
smartConstructorClosed ReplicaFamily count _ _ = count > 0
smartConstructorClosed RolloutFamily surge unavailable _ = surge > 0 || unavailable > 0
smartConstructorClosed HeadroomFamily request limitAmount pad = pad > 0 && request + pad <= limitAmount
#endif

roundTrip :: ([Text], [Text], [Natural]) -> ([Text], [Text], [Natural])
#ifdef ILLEGAL_STATE_PROPERTY_MUTANT
roundTrip _ = ([], [], [])
#else
roundTrip = id
#endif

totalFold :: [Natural] -> Natural
#ifdef ILLEGAL_STATE_PROPERTY_MUTANT
totalFold _ = 0
#else
totalFold = sum
#endif

composeFragments :: ([Text], [Text], [Natural]) -> ([Text], [Text], [Natural]) -> ([Text], [Text], [Natural])
#ifdef ILLEGAL_STATE_PROPERTY_MUTANT
composeFragments _ _ = ([], [], [])
#else
composeFragments (as, av, ar) (bs, bv, br) = (as <> bs, av <> bv, ar <> br)
#endif

rke2ServerCounts :: [Natural]
rke2ServerCounts = [1, 3, 5]
