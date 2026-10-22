{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

-- | The section that judges what the witnesses add: the total @fits@ over every pair of
-- three-valued vectors, the names and refusals of a volume witness, and the render of a
-- StatefulSet and of a source that carries a volume it has no right to. Each writes the bytes
-- it observed; none decides anything.
module SpineCapacity
  ( capacitySection
  ) where

import Amoebius.Capacity.Fits (fits)
import Amoebius.Capacity.RenderSource
  ( K8sObjectIdentity (K8sObjectIdentity)
  , ProvisionedDeploymentParts (..)
  , ProvisionedPartWitness (CapacitySchedulerPart, ManagedCapacityAdmissionPart, NamespacePart, ServiceWorkloadPart)
  , ReconcileMode (ServerSideApply)
  , RenderActivation (AfterBootstrapAddonCutover, AfterManagedCapacityReady, BootstrapSchedulerStage, Immediate)
  , RenderSourceCandidate (..)
  , RenderSourceOwner (CapabilityServiceOwner, DeploymentGlobalOwner)
  , provisionRenderSources
  )
import Amoebius.Capacity.Types
  ( CpuOvercommitPolicy (NoCpuOvercommit)
  , Demand (..)
  , Headroom (..)
  , HostEnvironment (NativeLinux)
  , Node (..)
  , NodeRole (..)
  , NodeCapacity (..)
  , Overcommit (..)
  , Workload (..)
  , emptyStorageDemand
  , exactResourceEnvelope
  )
import Amoebius.Capacity.Vector (ResourceVector (..), addResources, zeroResources)
import Amoebius.Dsl.Topology (ComputeEngine (KindEngine), NodeSupply (FixedSupply), mkTopology)
import Amoebius.Manifest.K8sObject (K8sObject (..), ObjectMetadata (..), ObjectSpec (..), PodTemplate (..))
import Amoebius.Manifest.Render (RenderRefusal (..), renderCandidates, renderRefusalTag)
import Amoebius.Scope.Attested (attest, principalAttestation, scopeStamp)
import Amoebius.Test.ScopeFixture (fixtureIdentityText)
import Amoebius.Manifest.Types (K8sObjectKind (..))
import Amoebius.Placement.Witness (epochNamed, place)
import Amoebius.Storage.Witness
  ( VolumeRefusal
  , mkVolumeWitness
  , volumeClaimName
  , volumePvName
  , volumeRefusalTag
  )
import Amoebius.Vocabulary (Architecture (Amd64), linuxCpuDetected, Quantity (..), quantityValue)
import Data.Aeson (encode)
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy qualified as Lazy
import Data.List.NonEmpty (NonEmpty (..))
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import Numeric.Natural (Natural)
import System.Directory (createDirectoryIfMissing)
import System.FilePath ((</>))

capacitySection :: FilePath -> IO ()
capacitySection suite = do
  createDirectoryIfMissing True suite
  write (suite </> "fits.tsv") fitsRows
  write (suite </> "volumes.tsv") volumeRows
  write (suite </> "claims.tsv") claimRows

write :: FilePath -> [Text] -> IO ()
write path rows = ByteString.writeFile path (Encoding.encodeUtf8 (Text.unlines rows))

tabs :: [Text] -> Text
tabs = Text.intercalate "\t"

natText :: Natural -> Text
natText = Text.pack . show

-- | Every demand and every capacity whose four axes each take one of three values: sixty-five
-- hundred and sixty-one pairs, each with what @fits@ answered, the sum of the two vectors, and
-- the demand added to the zero vector.
fitsRows :: [Text]
fitsRows =
  [ tabs (map natText [dc, dm, de, dp, cc, cm, ce, cp] <> [outcome (fits (Demand demand) capacity), vectorText (addResources demand capacity), vectorText (addResources zeroResources demand)])
  | dc <- values, dm <- values, de <- values, dp <- values
  , cc <- values, cm <- values, ce <- values, cp <- values
  , let demand = vector dc dm de dp
  , let capacity = vector cc cm ce cp
  ]
 where
  values = [0, 1, 2]
  vector cpu memory ephemeral pods = ResourceVector (Quantity cpu) (Quantity memory) (Quantity ephemeral) (Quantity pods)
  vectorText left = Text.intercalate "," [natText (quantityValue (resourceCpu left)), natText (quantityValue (resourceMemory left)), natText (quantityValue (resourceEphemeralStorage left)), natText (quantityValue (resourcePodSlots left))]
  outcome result = case result of
    Right (Headroom left) -> "ok:" <> vectorText left
    Left excess -> "over:" <> Text.pack (show (overcommitAxis excess)) <> ":" <> natText (overcommitRequired excess) <> ":" <> natText (overcommitAvailable excess)

-- | The names a volume witness computes and the identities it refuses.
volumeRows :: [Text]
volumeRows =
  [ volume "amoebius-minio" "member-0" 0 10737418240
  , volume "amoebius-postgres" "member-2" 2 8589934592
  , volume "a-b" "c" 0 1
  , volume "a" "b-c" 0 1
  , volume "amoebius-minio" "member-0" 0 0
  , volume "amoebius.minio" "member-0" 0 1
  , volume "amoebius-minio" "member_0" 0 1
  , volume "" "member-0" 0 1
  ]
 where
  volume namespace statefulSet ordinal size =
    tabs [namespace, statefulSet, natText ordinal, natText size, either refusal named (mkVolumeWitness namespace statefulSet ordinal (Quantity size))]
  named witness = "ok:" <> volumeClaimName witness <> ":" <> volumePvName witness
  refusal :: VolumeRefusal -> Text
  refusal problem = "refused:" <> volumeRefusalTag problem

-- | The render of three sources: a StatefulSet that owns a volume, a StatefulSet that does
-- not, and a Deployment that claims one.
claimRows :: [Text]
claimRows = concat [scenario name candidates | (name, candidates) <- scenarios]
 where
  scenarios =
    [ ("statefulset-with-volume", [member (Map.fromList [("kind", "StatefulSet"), ("volume-bytes", "4096")])])
    , ("statefulset-without-volume", [member (Map.fromList [("kind", "StatefulSet")])])
    , ("deployment-with-volume", [member (Map.fromList [("kind", "Deployment"), ("volume-bytes", "4096")])])
    ]
  identity = K8sObjectIdentity "objectstore/assets/member-0"
  member fields =
    RenderSourceCandidate
      { candidateMapKey = identity
      , candidateIdentity = identity
      , candidateOwner = CapabilityServiceOwner "assets"
      , candidateFields = fields
      , candidateReconcileMode = ServerSideApply
      , candidateActivation = AfterBootstrapAddonCutover
      , candidateWitness = ServiceWorkloadPart "assets"
      }
  scenario name candidates = case outcomeOf candidates of
    Left problem -> [tabs [name, "refused", renderRefusalTag problem, refusedIdentity problem]]
    Right objects -> [tabs [name, natText index, kindText (objectKind object), identityText (objectIdentity object), metadataName (objectMetadata object), nodeOf object, claimOf object] | (index, object) <- zip [0 ..] [object | object <- objects, "objectstore/" `Text.isPrefixOf` identityText (objectIdentity object)]]
  refusedIdentity problem = case problem of
    PvcWithoutStatefulSet source -> source
    VolumeRefused source _ -> source
    InvalidEngineRuntime source -> source
    UnattestedScope source -> source
  identityText (K8sObjectIdentity text) = text
  kindText kind = Text.pack (show kind)
  nodeOf object = case objectSpec object of
    WorkloadSpec _ pod -> maybe "none" id (podNodeName pod)
    _ -> "none"
  claimOf object = case objectKind object of
    PersistentVolumeClaimKind -> Encoding.decodeUtf8 (Lazy.toStrict (encode (objectSpec object)))
    _ -> "none"

-- | Render a source set through the placement of its one workload on one node.
outcomeOf :: [RenderSourceCandidate] -> Either RenderRefusal [K8sObject]
outcomeOf candidates = case (placed, sources) of
  (Right witness, Right set) -> do
    identity <- either (const (Left (UnattestedScope "fixture identity"))) Right (fixtureIdentityText "fixture" "renderer")
    nested <- either (const (Left (UnattestedScope "fixture scope"))) Right $ attest (principalAttestation identity) $ \scope ->
      renderCandidates (Map.fromList [(owner, scopeStamp scope) | owner <- [DeploymentGlobalOwner, CapabilityServiceOwner "assets"]]) witness (epochNamed "generation-1") set
    nested
  _ -> Left (PvcWithoutStatefulSet "the fixture did not build")
 where
  node =
    Node
      { nodeId = "kind-host-1"
      , nodeHostId = "kind-host"
      , nodeEnvironment = NativeLinux
      , nodeCapacity = NodeCapacity (ResourceVector 16 64 500 110) NoCpuOvercommit Map.empty
      , nodeTaints = Set.empty
      , nodeDetected = linuxCpuDetected Amd64
      , nodeRole = KindWorker
      }
  workload =
    Workload
      { workloadId = "objectstore/assets/member-0"
      , workloadEnvelope = exactResourceEnvelope (ResourceVector 1 1 1 1)
      , workloadStorage = emptyStorageDemand
      , workloadAttachments = []
      , workloadTolerations = Set.empty
      , workloadAntiAffinity = Nothing
      }
  placed = either (const (Left ())) (\topology -> either (const (Left ())) Right (place topology [workload])) (mkTopology KindEngine (FixedSupply (node :| [])))
  everything = candidates <> globals
  sources = provisionRenderSources (ProvisionedDeploymentParts (Set.fromList (map candidateMapKey everything)) everything)
  -- Every activation stage carries a source, so the sealed set needs one global object at each of the others.
  globals =
    [ global "global/namespace" NamespacePart Immediate
    , global "global/capacity-scheduler" CapacitySchedulerPart BootstrapSchedulerStage
    , global "global/managed-capacity-admission" ManagedCapacityAdmissionPart AfterManagedCapacityReady
    ]
  global name witness activation =
    RenderSourceCandidate
      { candidateMapKey = K8sObjectIdentity name
      , candidateIdentity = K8sObjectIdentity name
      , candidateOwner = DeploymentGlobalOwner
      , candidateFields = Map.empty
      , candidateReconcileMode = ServerSideApply
      , candidateActivation = activation
      , candidateWitness = witness
      }
