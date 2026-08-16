{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | The resource-complete, snapshot-bound Phase-25 registry cycle-break.
-- Constructors for provisioned values and actions remain private; the only
-- effects are selected-image import plus serialization/application of the
-- fixed six-object bootstrap domain.
module Amoebius.Image.BootstrapRegistry
  ( BootstrapContainerDemand (..)
  , BootstrapRegistryExecution (..)
  , BootstrapObjectSource (..)
  , BootstrapRegistrySpec (..)
  , ProvisionedBootstrapRegistry
  , provisionedBootstrapRegistryStorage
  , provisionedBootstrapRegistryExecution
  , provisionedBootstrapRegistryIdentities
  , provisionedBootstrapRegistryHandoffDigest
  , ObservedBootstrapRegistryInventory (..)
  , BootstrapRegistryAction
  , bootstrapRegistryActionIdentities
  , bootstrapRegistryActionObjects
  , BootstrapRegistryReceipt (..)
  , BootstrapRegistryEnactmentResult (..)
  , BootstrapHandoffVerdict (..)
  , BootstrapRegistryError (..)
  , bootstrapRegistryDomain
  , bootstrapRegistryInitializedFields
  , provisionBootstrapRegistry
  , validateBootstrapRegistryTarget
  , enactBootstrapRegistry
  , adoptBootstrapRegistryHandoff
  , renderBootstrapRegistryError
  ) where

import Amoebius.Capacity.NodeLocalStorage
  ( NodeStorageComponent (..)
  , NodeStorageRole (KubeletNodefs)
  )
import Amoebius.Capacity.RenderSource (K8sObjectIdentity (..))
import Amoebius.Capacity.Types (ResourceVector (..), addResources)
import Amoebius.Image.Artifact (ImageArtifact (..), ImagePlatform)
import Amoebius.Image.NodeLoad
  ( NodeLoadError
  , NodeLoadPlan (..)
  , ObservedNodeLoadInventory (..)
  , ProvisionedNodeLoad
  , provisionNodeLoad
  )
import Amoebius.Image.Registry
  ( ProvisionedRegistryStorageDemand
  , RegistryError
  , RegistryStorageDemand
  , provisionRegistryStorage
  , provisionedRegistryPeakBytes
  )
import Amoebius.Manifest.K8sObject (K8sObject, K8sObjectKind (..))
import Amoebius.Manifest.Render
  ( BootstrapRenderSource (..)
  , renderBootstrapSourcePrivate
  )
import Control.DeepSeq (NFData)
import Control.Monad (foldM)
import Data.IORef (IORef, atomicModifyIORef', newIORef, readIORef, writeIORef)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data BootstrapContainerDemand = BootstrapContainerDemand
  { bootstrapContainerRequests :: ResourceVector
  , bootstrapContainerLimits :: ResourceVector
  , bootstrapContainerPrivateEphemeralBytes :: Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data BootstrapRegistryExecution = BootstrapRegistryExecution
  { bootstrapRegistryContainer :: BootstrapContainerDemand
  , bootstrapMutationProxyContainer :: BootstrapContainerDemand
  , bootstrapRegistryNodeName :: Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data BootstrapObjectSource = BootstrapObjectSource
  { bootstrapSourceIdentity :: K8sObjectIdentity
  , bootstrapSourceKind :: K8sObjectKind
  , bootstrapSourceNamespace :: Maybe Text
  , bootstrapSourceFields :: Map Text Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data BootstrapRegistrySpec = BootstrapRegistrySpec
  { bootstrapRegistryArtifact :: ImageArtifact
  , bootstrapRegistryPlatform :: ImagePlatform
  , bootstrapRegistryNodeLoadPlan :: NodeLoadPlan
  , bootstrapRegistryStorageDemand :: RegistryStorageDemand
  , bootstrapRegistryExecution :: BootstrapRegistryExecution
  , bootstrapRegistrySources :: [BootstrapObjectSource]
  , bootstrapRegistryInitializedFieldSet :: Set Text
  , bootstrapRegistryHandoffDigest :: Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data HandoffState = HandoffNotReady | HandoffReady | HandoffConsumed
  deriving stock (Eq, Show)

data ProvisionedBootstrapRegistry = ProvisionedBootstrapRegistry
  { provisionedBootstrapRegistryArtifact :: ImageArtifact
  , provisionedBootstrapRegistryStorage :: ProvisionedRegistryStorageDemand
  , provisionedBootstrapRegistryExecution :: BootstrapRegistryExecution
  , provisionedBootstrapRegistrySources :: Map K8sObjectIdentity BootstrapObjectSource
  , provisionedBootstrapRegistryIdentities :: Set K8sObjectIdentity
  , provisionedBootstrapRegistryInitializedFields :: Set Text
  , provisionedBootstrapRegistryHandoffDigest :: Text
  , provisionedBootstrapRegistryNodeLoadPlan :: NodeLoadPlan
  , provisionedBootstrapRegistryHandoffState :: IORef HandoffState
  }

data ObservedBootstrapRegistryInventory = ObservedBootstrapRegistryInventory
  { observedBootstrapRegistryFingerprint :: Text
  , observedBootstrapRegistryRequestResidual :: ResourceVector
  , observedBootstrapRegistryLimitResidual :: ResourceVector
  , observedBootstrapRegistryNodeLoad :: ObservedNodeLoadInventory
  , observedBootstrapRegistryDomain :: Set K8sObjectIdentity
  , observedBootstrapRegistryInitializedFields :: Set Text
  , observedBootstrapRegistrySourceDigest :: Text
  , observedBootstrapRegistryApiVersions :: Map K8sObjectKind Text
  , observedBootstrapRegistryUnknownCommitments :: Set Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data BootstrapRegistryAction = BootstrapRegistryAction
  { bootstrapRegistryActionFingerprint :: Text
  , bootstrapRegistryActionSourceDigest :: Text
  , bootstrapRegistryActionIdentities :: Set K8sObjectIdentity
  , bootstrapRegistryActionObjects :: [K8sObject]
  , bootstrapRegistryActionNodeLoad :: ProvisionedNodeLoad
  , bootstrapRegistryActionConsumed :: IORef Bool
  , bootstrapRegistryActionHandoffState :: IORef HandoffState
  }

data BootstrapRegistryReceipt = BootstrapRegistryReceipt
  { bootstrapReceiptFingerprint :: Text
  , bootstrapReceiptSourceDigest :: Text
  , bootstrapReceiptImported :: Bool
  , bootstrapReceiptAppliedObjects :: Natural
  , bootstrapReceiptConsumed :: Bool
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data BootstrapRegistryEnactmentResult
  = BootstrapRegistryApplied BootstrapRegistryReceipt
  | BootstrapRegistryAmbiguous BootstrapRegistryReceipt
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data BootstrapHandoffVerdict = AdoptedOnce
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data BootstrapRegistryError
  = BootstrapRegistryArtifactMismatch Text Text
  | BootstrapRegistryPlatformMismatch ImagePlatform ImagePlatform
  | BootstrapRegistryDomainMismatch (Set K8sObjectIdentity) (Set K8sObjectIdentity)
  | BootstrapRegistrySourceDuplicate K8sObjectIdentity
  | BootstrapRegistrySourceKindMismatch K8sObjectIdentity K8sObjectKind K8sObjectKind
  | BootstrapRegistryInitializedFieldsMismatch (Set Text) (Set Text)
  | BootstrapRegistryHandoffDigestInvalid Text
  | BootstrapRegistryStorageRejected RegistryError
  | BootstrapRegistryContainerEnvelopeInvalid Text
  | BootstrapRegistryVolumeUnderreserved Natural Natural
  | BootstrapRegistryUnknownCommitment (Set Text)
  | BootstrapRegistryRequestExceeded Text Natural Natural
  | BootstrapRegistryLimitExceeded Text Natural Natural
  | BootstrapRegistryApiVersionMissing K8sObjectKind
  | BootstrapRegistryNodeLoadRejected NodeLoadError
  | BootstrapRegistrySnapshotChanged Text Text
  | BootstrapRegistryObservedDomainMismatch (Set K8sObjectIdentity) (Set K8sObjectIdentity)
  | BootstrapRegistryObservedFieldsMismatch (Set Text) (Set Text)
  | BootstrapHandoffDigestMismatch Text Text
  | BootstrapRegistryActionAlreadyConsumed
  | BootstrapHandoffNotReady
  | BootstrapHandoffAlreadyConsumed
  deriving stock (Eq, Generic, Show)

bootstrapRegistryDomain :: Set K8sObjectIdentity
bootstrapRegistryDomain =
  Set.fromList
    ( [ K8sObjectIdentity "Namespace/amoebius-bootstrap"
      , K8sObjectIdentity "ConfigMap/amoebius-bootstrap/registry-config"
      , K8sObjectIdentity "Deployment/amoebius-bootstrap/distribution"
      , K8sObjectIdentity "Service/amoebius-bootstrap/distribution-read"
      , K8sObjectIdentity "Deployment/amoebius-bootstrap/registry-mutation-proxy"
      , K8sObjectIdentity "Service/amoebius-bootstrap/registry-mutation-proxy"
      ]
#ifdef BASE_IMAGE_REGISTRY_BOOTSTRAP_DOMAIN_EXPANSION_MUTANT
        <> [K8sObjectIdentity "Deployment/default/foreign"]
#endif
    )

bootstrapRegistryInitializedFields :: Set Text
bootstrapRegistryInitializedFields =
  Set.fromList
    [ "metadata.labels"
    , "metadata.annotations.amoebius.io/source-digest"
    , "spec.selector"
    , "spec.template"
    , "spec.ports"
    , "data.registry-config"
    ]

provisionBootstrapRegistry
  :: BootstrapRegistrySpec
  -> IO (Either BootstrapRegistryError ProvisionedBootstrapRegistry)
provisionBootstrapRegistry spec = case validateSpec spec of
  Left problem -> pure (Left problem)
  Right (storage, sources) -> do
    handoff <- newIORef HandoffNotReady
    pure
      ( Right
          ProvisionedBootstrapRegistry
            { provisionedBootstrapRegistryArtifact = bootstrapRegistryArtifact spec
            , provisionedBootstrapRegistryStorage = storage
            , provisionedBootstrapRegistryExecution = bootstrapRegistryExecution spec
            , provisionedBootstrapRegistrySources = sources
            , provisionedBootstrapRegistryIdentities = Map.keysSet sources
            , provisionedBootstrapRegistryInitializedFields = bootstrapRegistryInitializedFieldSet spec
            , provisionedBootstrapRegistryHandoffDigest = bootstrapRegistryHandoffDigest spec
            , provisionedBootstrapRegistryNodeLoadPlan = bootstrapRegistryNodeLoadPlan spec
            , provisionedBootstrapRegistryHandoffState = handoff
            }
      )

validateBootstrapRegistryTarget
  :: ProvisionedBootstrapRegistry
  -> ObservedBootstrapRegistryInventory
  -> IO (Either BootstrapRegistryError BootstrapRegistryAction)
validateBootstrapRegistryTarget provision observed = case validateTarget provision observed of
  Left problem -> pure (Left problem)
  Right nodeLoad -> do
    consumed <- newIORef False
    let sources = Map.elems (provisionedBootstrapRegistrySources provision)
        objects = fmap (renderBootstrap provision) sources
    pure
      ( Right
          BootstrapRegistryAction
            { bootstrapRegistryActionFingerprint = observedBootstrapRegistryFingerprint observed
            , bootstrapRegistryActionSourceDigest = provisionedBootstrapRegistryHandoffDigest provision
            , bootstrapRegistryActionIdentities = provisionedBootstrapRegistryIdentities provision
            , bootstrapRegistryActionObjects = objects
            , bootstrapRegistryActionNodeLoad = nodeLoad
            , bootstrapRegistryActionConsumed = consumed
            , bootstrapRegistryActionHandoffState = provisionedBootstrapRegistryHandoffState provision
            }
      )

enactBootstrapRegistry
  :: BootstrapRegistryAction
  -> ObservedBootstrapRegistryInventory
  -> (ProvisionedNodeLoad -> IO Bool)
  -> (K8sObject -> IO Bool)
  -> IO (Either BootstrapRegistryError BootstrapRegistryEnactmentResult)
enactBootstrapRegistry action observed importImage applyObject
  | bootstrapRegistryActionFingerprint action /= observedBootstrapRegistryFingerprint observed =
      pure
        ( Left
            ( BootstrapRegistrySnapshotChanged
                (bootstrapRegistryActionFingerprint action)
                (observedBootstrapRegistryFingerprint observed)
            )
        )
  | bootstrapRegistryActionSourceDigest action /= observedBootstrapRegistrySourceDigest observed =
      pure
        ( Left
            ( BootstrapHandoffDigestMismatch
                (bootstrapRegistryActionSourceDigest action)
                (observedBootstrapRegistrySourceDigest observed)
            )
        )
  | bootstrapRegistryActionIdentities action /= observedBootstrapRegistryDomain observed =
      pure
        ( Left
            ( BootstrapRegistryObservedDomainMismatch
                (bootstrapRegistryActionIdentities action)
                (observedBootstrapRegistryDomain observed)
            )
        )
  | otherwise = do
      won <- atomicModifyIORef' (bootstrapRegistryActionConsumed action) (\consumed -> (True, not consumed))
      if not won
        then pure (Left BootstrapRegistryActionAlreadyConsumed)
        else do
          imported <- importImage (bootstrapRegistryActionNodeLoad action)
          if not imported
            then pure (Right (BootstrapRegistryAmbiguous (receipt False 0)))
            else do
              applied <- applyUntilFailure applyObject (bootstrapRegistryActionObjects action)
              if applied == length (bootstrapRegistryActionObjects action)
                then do
                  writeIORef (bootstrapRegistryActionHandoffState action) HandoffReady
                  pure (Right (BootstrapRegistryApplied (receipt True (fromIntegral applied))))
                else pure (Right (BootstrapRegistryAmbiguous (receipt True (fromIntegral applied))))
 where
  receipt imported applied =
    BootstrapRegistryReceipt
      { bootstrapReceiptFingerprint = bootstrapRegistryActionFingerprint action
      , bootstrapReceiptSourceDigest = bootstrapRegistryActionSourceDigest action
      , bootstrapReceiptImported = imported
      , bootstrapReceiptAppliedObjects = applied
      , bootstrapReceiptConsumed = True
      }

adoptBootstrapRegistryHandoff
  :: ProvisionedBootstrapRegistry
  -> Set K8sObjectIdentity
  -> Set Text
  -> Text
  -> IO (Either BootstrapRegistryError BootstrapHandoffVerdict)
#ifdef BASE_IMAGE_REGISTRY_HANDOFF_WITHOUT_EQUALITY_MUTANT
adoptBootstrapRegistryHandoff provision _liveDomain _liveFields _liveDigest = adoptReady provision
#else
adoptBootstrapRegistryHandoff provision liveDomain liveFields liveDigest
  | liveDomain /= provisionedBootstrapRegistryIdentities provision =
      pure (Left (BootstrapRegistryObservedDomainMismatch (provisionedBootstrapRegistryIdentities provision) liveDomain))
  | liveFields /= provisionedBootstrapRegistryInitializedFields provision =
      pure (Left (BootstrapRegistryObservedFieldsMismatch (provisionedBootstrapRegistryInitializedFields provision) liveFields))
  | liveDigest /= provisionedBootstrapRegistryHandoffDigest provision =
      pure (Left (BootstrapHandoffDigestMismatch (provisionedBootstrapRegistryHandoffDigest provision) liveDigest))
  | otherwise = adoptReady provision
#endif

adoptReady :: ProvisionedBootstrapRegistry -> IO (Either BootstrapRegistryError BootstrapHandoffVerdict)
adoptReady provision = do
  state <- readIORef (provisionedBootstrapRegistryHandoffState provision)
  case state of
    HandoffNotReady -> pure (Left BootstrapHandoffNotReady)
    HandoffConsumed -> pure (Left BootstrapHandoffAlreadyConsumed)
    HandoffReady -> do
      won <- atomicModifyIORef' (provisionedBootstrapRegistryHandoffState provision) $ \current ->
        case current of
          HandoffReady -> (HandoffConsumed, True)
          _ -> (current, False)
      pure (if won then Right AdoptedOnce else Left BootstrapHandoffAlreadyConsumed)

renderBootstrapRegistryError :: BootstrapRegistryError -> Text
renderBootstrapRegistryError problem = case problem of
  BootstrapRegistryArtifactMismatch _ _ -> "BootstrapRegistryArtifactMismatch"
  BootstrapRegistryPlatformMismatch _ _ -> "BootstrapRegistryPlatformMismatch"
  BootstrapRegistryDomainMismatch _ _ -> "BootstrapRegistryDomainMismatch"
  BootstrapRegistrySourceDuplicate _ -> "BootstrapRegistrySourceDuplicate"
  BootstrapRegistrySourceKindMismatch _ _ _ -> "BootstrapRegistrySourceKindMismatch"
  BootstrapRegistryInitializedFieldsMismatch _ _ -> "BootstrapRegistryInitializedFieldsMismatch"
  BootstrapRegistryHandoffDigestInvalid _ -> "BootstrapRegistryHandoffDigestInvalid"
  BootstrapRegistryStorageRejected _ -> "BootstrapRegistryStorageRejected"
  BootstrapRegistryContainerEnvelopeInvalid _ -> "BootstrapRegistryContainerEnvelopeInvalid"
  BootstrapRegistryVolumeUnderreserved _ _ -> "BootstrapRegistryVolumeUnderreserved"
  BootstrapRegistryUnknownCommitment _ -> "BootstrapRegistryUnknownCommitment"
  BootstrapRegistryRequestExceeded axis _ _ -> "BootstrapRegistry" <> axis <> "RequestExceeded"
  BootstrapRegistryLimitExceeded axis _ _ -> "BootstrapRegistry" <> axis <> "LimitExceeded"
  BootstrapRegistryApiVersionMissing _ -> "BootstrapRegistryApiVersionMissing"
  BootstrapRegistryNodeLoadRejected _ -> "BootstrapRegistryNodeLoadRejected"
  BootstrapRegistrySnapshotChanged _ _ -> "BootstrapSnapshotChanged"
  BootstrapRegistryObservedDomainMismatch _ _ -> "BootstrapRegistryObservedDomainMismatch"
  BootstrapRegistryObservedFieldsMismatch _ _ -> "BootstrapRegistryObservedFieldsMismatch"
  BootstrapHandoffDigestMismatch _ _ -> "BootstrapHandoffDigestMismatch"
  BootstrapRegistryActionAlreadyConsumed -> "BootstrapRegistryActionAlreadyConsumed"
  BootstrapHandoffNotReady -> "BootstrapHandoffNotReady"
  BootstrapHandoffAlreadyConsumed -> "BootstrapHandoffAlreadyConsumed"

validateSpec
  :: BootstrapRegistrySpec
  -> Either BootstrapRegistryError (ProvisionedRegistryStorageDemand, Map K8sObjectIdentity BootstrapObjectSource)
validateSpec spec = do
  if imageIdentity (bootstrapRegistryArtifact spec) == imageIdentity (nodeLoadArtifact (bootstrapRegistryNodeLoadPlan spec))
    then Right ()
    else
      Left
        ( BootstrapRegistryArtifactMismatch
            (imageIdentity (bootstrapRegistryArtifact spec))
            (imageIdentity (nodeLoadArtifact (bootstrapRegistryNodeLoadPlan spec)))
        )
  if bootstrapRegistryPlatform spec == nodeLoadPlatform (bootstrapRegistryNodeLoadPlan spec)
    then Right ()
    else
      Left
        ( BootstrapRegistryPlatformMismatch
            (bootstrapRegistryPlatform spec)
            (nodeLoadPlatform (bootstrapRegistryNodeLoadPlan spec))
        )
  sources <- sourceMap (bootstrapRegistrySources spec)
  if Map.keysSet sources == bootstrapRegistryDomain
    then Right ()
    else Left (BootstrapRegistryDomainMismatch bootstrapRegistryDomain (Map.keysSet sources))
  validateSourceKinds sources
  if bootstrapRegistryInitializedFieldSet spec == bootstrapRegistryInitializedFields
    then Right ()
    else Left (BootstrapRegistryInitializedFieldsMismatch bootstrapRegistryInitializedFields (bootstrapRegistryInitializedFieldSet spec))
  validateDigest (bootstrapRegistryHandoffDigest spec)
  validateExecution (bootstrapRegistryExecution spec)
  storage <- either (Left . BootstrapRegistryStorageRejected) Right (provisionRegistryStorage (bootstrapRegistryStorageDemand spec))
  let registryEphemeral = resourceEphemeralStorage (bootstrapContainerRequests (bootstrapRegistryContainer (bootstrapRegistryExecution spec)))
      required = provisionedRegistryPeakBytes storage + bootstrapContainerPrivateEphemeralBytes (bootstrapRegistryContainer (bootstrapRegistryExecution spec))
  if required <= registryEphemeral
    then Right ()
    else Left (BootstrapRegistryVolumeUnderreserved required registryEphemeral)
  pure (storage, sources)

validateTarget
  :: ProvisionedBootstrapRegistry
  -> ObservedBootstrapRegistryInventory
  -> Either BootstrapRegistryError ProvisionedNodeLoad
validateTarget provision observed = do
  if Set.null (observedBootstrapRegistryUnknownCommitments observed)
    then Right ()
    else Left (BootstrapRegistryUnknownCommitment (observedBootstrapRegistryUnknownCommitments observed))
  if observedBootstrapRegistryDomain observed == provisionedBootstrapRegistryIdentities provision
    then Right ()
    else Left (BootstrapRegistryObservedDomainMismatch (provisionedBootstrapRegistryIdentities provision) (observedBootstrapRegistryDomain observed))
  if observedBootstrapRegistryInitializedFields observed == provisionedBootstrapRegistryInitializedFields provision
    then Right ()
    else Left (BootstrapRegistryObservedFieldsMismatch (provisionedBootstrapRegistryInitializedFields provision) (observedBootstrapRegistryInitializedFields observed))
  if observedBootstrapRegistrySourceDigest observed == provisionedBootstrapRegistryHandoffDigest provision
    then Right ()
    else Left (BootstrapHandoffDigestMismatch (provisionedBootstrapRegistryHandoffDigest provision) (observedBootstrapRegistrySourceDigest observed))
  mapM_ (requireApiVersion observed) (Set.toList (Set.fromList (fmap bootstrapSourceKind (Map.elems (provisionedBootstrapRegistrySources provision)))))
  let execution = provisionedBootstrapRegistryExecution provision
      requests = executionSum bootstrapContainerRequests execution
      limits = executionSum bootstrapContainerLimits execution
  requireResources BootstrapRegistryRequestExceeded requests (observedBootstrapRegistryRequestResidual observed)
  requireResources BootstrapRegistryLimitExceeded limits (observedBootstrapRegistryLimitResidual observed)
  let blobComponent =
        NodeStorageComponent
          "registry-blob-volume"
          KubeletNodefs
          (provisionedRegistryPeakBytes (provisionedBootstrapRegistryStorage provision))
      nodeObserved = observedBootstrapRegistryNodeLoad observed
      withRegistry =
        nodeObserved
          { observedNodeLoadComponents = observedNodeLoadComponents nodeObserved <> [blobComponent]
          }
  either (Left . BootstrapRegistryNodeLoadRejected) Right
    (provisionNodeLoad (provisionedBootstrapRegistryNodeLoadPlan provision) withRegistry)

renderBootstrap :: ProvisionedBootstrapRegistry -> BootstrapObjectSource -> K8sObject
renderBootstrap provision source =
  renderBootstrapSourcePrivate
    BootstrapRenderSource
      { bootstrapRenderIdentity = bootstrapSourceIdentity source
      , bootstrapRenderKind = bootstrapSourceKind source
      , bootstrapRenderNamespace = bootstrapSourceNamespace source
      , bootstrapRenderFields = bootstrapSourceFields source
      , bootstrapRenderSourceDigest = provisionedBootstrapRegistryHandoffDigest provision
      }

sourceMap :: [BootstrapObjectSource] -> Either BootstrapRegistryError (Map K8sObjectIdentity BootstrapObjectSource)
sourceMap = foldM insert Map.empty
 where
  insert accumulated source =
    if Map.member (bootstrapSourceIdentity source) accumulated
      then Left (BootstrapRegistrySourceDuplicate (bootstrapSourceIdentity source))
      else Right (Map.insert (bootstrapSourceIdentity source) source accumulated)

validateSourceKinds :: Map K8sObjectIdentity BootstrapObjectSource -> Either BootstrapRegistryError ()
validateSourceKinds sources = mapM_ validateOne (Map.toList expectedKinds)
 where
  expectedKinds =
    Map.fromList
      [ (K8sObjectIdentity "Namespace/amoebius-bootstrap", NamespaceKind)
      , (K8sObjectIdentity "ConfigMap/amoebius-bootstrap/registry-config", ConfigMapKind)
      , (K8sObjectIdentity "Deployment/amoebius-bootstrap/distribution", DeploymentKind)
      , (K8sObjectIdentity "Service/amoebius-bootstrap/distribution-read", ServiceKind)
      , (K8sObjectIdentity "Deployment/amoebius-bootstrap/registry-mutation-proxy", DeploymentKind)
      , (K8sObjectIdentity "Service/amoebius-bootstrap/registry-mutation-proxy", ServiceKind)
      ]
  validateOne (identity, expected) = case Map.lookup identity sources of
    Nothing -> Left (BootstrapRegistryDomainMismatch bootstrapRegistryDomain (Map.keysSet sources))
    Just source
      | bootstrapSourceKind source == expected -> Right ()
      | otherwise -> Left (BootstrapRegistrySourceKindMismatch identity expected (bootstrapSourceKind source))

validateExecution :: BootstrapRegistryExecution -> Either BootstrapRegistryError ()
validateExecution execution = do
  if Text.null (bootstrapRegistryNodeName execution)
    then Left (BootstrapRegistryContainerEnvelopeInvalid "node-name")
    else Right ()
  validateContainer "registry" (bootstrapRegistryContainer execution)
  validateContainer "mutation-proxy" (bootstrapMutationProxyContainer execution)

validateContainer :: Text -> BootstrapContainerDemand -> Either BootstrapRegistryError ()
validateContainer label container = do
  requireResources
    (\axis required available -> BootstrapRegistryContainerEnvelopeInvalid (label <> ":" <> axis <> ":" <> Text.pack (show required) <> ">" <> Text.pack (show available)))
    (bootstrapContainerRequests container)
    (bootstrapContainerLimits container)
  if resourcePodSlots (bootstrapContainerRequests container) == 1
      && resourcePodSlots (bootstrapContainerLimits container) == 1
    then Right ()
    else Left (BootstrapRegistryContainerEnvelopeInvalid (label <> ":pod-slots"))

executionSum
  :: (BootstrapContainerDemand -> ResourceVector)
  -> BootstrapRegistryExecution
  -> ResourceVector
executionSum projection execution =
  addResources
    (projection (bootstrapRegistryContainer execution))
    (projection (bootstrapMutationProxyContainer execution))

requireResources
  :: (Text -> Natural -> Natural -> BootstrapRegistryError)
  -> ResourceVector
  -> ResourceVector
  -> Either BootstrapRegistryError ()
requireResources constructor required available
  | resourceCpu required > resourceCpu available = Left (constructor "Cpu" (resourceCpu required) (resourceCpu available))
  | resourceMemory required > resourceMemory available = Left (constructor "Memory" (resourceMemory required) (resourceMemory available))
  | resourceEphemeralStorage required > resourceEphemeralStorage available = Left (constructor "Ephemeral" (resourceEphemeralStorage required) (resourceEphemeralStorage available))
  | resourcePodSlots required > resourcePodSlots available = Left (constructor "PodSlots" (resourcePodSlots required) (resourcePodSlots available))
  | otherwise = Right ()

requireApiVersion :: ObservedBootstrapRegistryInventory -> K8sObjectKind -> Either BootstrapRegistryError ()
requireApiVersion observed kind = case Map.lookup kind (observedBootstrapRegistryApiVersions observed) of
  Just version | not (Text.null version) -> Right ()
  _ -> Left (BootstrapRegistryApiVersionMissing kind)

validateDigest :: Text -> Either BootstrapRegistryError ()
validateDigest digest =
  if Text.length digest == 71
      && "sha256:" `Text.isPrefixOf` digest
      && Text.all (`elem` ("0123456789abcdef" :: String)) (Text.drop 7 digest)
    then Right ()
    else Left (BootstrapRegistryHandoffDigestInvalid digest)

applyUntilFailure :: (value -> IO Bool) -> [value] -> IO Int
applyUntilFailure applyOne = go 0
 where
  go count values = case values of
    [] -> pure count
    value : rest -> do
      applied <- applyOne value
      if applied then go (count + 1) rest else pure count
