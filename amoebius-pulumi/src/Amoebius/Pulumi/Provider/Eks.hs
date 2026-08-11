module Amoebius.Pulumi.Provider.Eks
  ( AcceleratorOffering (..)
  , ProviderNodeClass (..)
  , ProviderSku (..)
  , ObservedProviderAccount (..)
  , ProviderDemand (..)
  , ProviderPlanError (..)
  , ValidatedInfrastructurePlan
  , validateInfrastructurePlan
  , validatedPlanFingerprint
  , ProviderReadback (..)
  , ProvisionContext
  , acceptProviderReadback
  , provisionedClusterName
  ) where

data AcceleratorOffering = NoAccelerator | NvidiaGpu Int | AppleMetal
  deriving stock (Eq, Show)

data ProviderNodeClass = ProviderNodeClass
  { nodeClassName :: String
  , nodeMachineType :: String
  , nodeCatalogVersion :: String
  , nodeAllocatableCpuMilli :: Integer
  , nodeAllocatableMemoryBytes :: Integer
  , nodePodSlots :: Int
  , nodeCniSlots :: Int
  , nodeAttachableVolumes :: Int
  , nodeRootSizeGiB :: Integer
  , nodeAccelerator :: AcceleratorOffering
  }
  deriving stock (Eq, Show)

data ProviderSku = ProviderSku
  { skuMachineType :: String
  , skuCatalogVersion :: String
  , skuRawVcpus :: Integer
  , skuMemoryBytes :: Integer
  , skuCniPodSlots :: Int
  , skuAttachableVolumes :: Int
  , skuMinimumRootGiB :: Integer
  , skuRootQuantumGiB :: Integer
  , skuAccelerator :: AcceleratorOffering
  }
  deriving stock (Eq, Show)

data ObservedProviderAccount = ObservedProviderAccount
  { accountFingerprint :: String
  , accountPaginationComplete :: Bool
  , accountPermissionsComplete :: Bool
  , accountCatalogVersion :: String
  , accountVcpuLimit :: Integer
  , accountVcpuUsed :: Integer
  , accountNodeGroupLimit :: Integer
  , accountNodeGroupsUsed :: Integer
  , accountEbsByteLimit :: Integer
  , accountEbsBytesUsed :: Integer
  }
  deriving stock (Eq, Show)

data ProviderDemand = ProviderDemand
  { providerClusterName :: String
  , providerBaseNodeCount :: Integer
  , providerNodeClass :: ProviderNodeClass
  , providerSku :: ProviderSku
  }
  deriving stock (Eq, Show)

data ProviderPlanError
  = ProviderObservationIncomplete
  | StaleSkuCatalog
  | SkuMachineTypeMismatch
  | AcceleratorMismatch
  | AcceleratorMustBeAbsent
  | NodeCpuShapeMismatch
  | NodeMemoryShapeMismatch
  | PodSlotShapeMismatch
  | AttachmentShapeMismatch
  | RootVolumeShapeMismatch
  | ProviderVcpuQuotaShort
  | ManagedNodeGroupQuotaShort
  | ProviderEbsQuotaShort
  | ProviderFingerprintChanged
  | ProviderReadbackMismatch
  deriving stock (Eq, Show)

data ValidatedInfrastructurePlan = ValidatedInfrastructurePlan
  { validatedDemand :: ProviderDemand
  , validatedPlanFingerprint :: String
  }
  deriving stock (Eq, Show)

validateInfrastructurePlan
  :: ObservedProviderAccount
  -> ProviderDemand
  -> Either ProviderPlanError ValidatedInfrastructurePlan
validateInfrastructurePlan account demand
  | not (accountPaginationComplete account && accountPermissionsComplete account) = Left ProviderObservationIncomplete
  | accountCatalogVersion account /= nodeCatalogVersion node || nodeCatalogVersion node /= skuCatalogVersion sku = Left StaleSkuCatalog
  | nodeMachineType node /= skuMachineType sku = Left SkuMachineTypeMismatch
  | nodeAccelerator node /= skuAccelerator sku = Left AcceleratorMismatch
  | nodeAccelerator node /= NoAccelerator = Left AcceleratorMustBeAbsent
  | nodeAllocatableCpuMilli node > skuRawVcpus sku * 1000 = Left NodeCpuShapeMismatch
  | nodeAllocatableMemoryBytes node > skuMemoryBytes sku = Left NodeMemoryShapeMismatch
  | nodePodSlots node > nodeCniSlots node || nodeCniSlots node > skuCniPodSlots sku = Left PodSlotShapeMismatch
  | nodeAttachableVolumes node > skuAttachableVolumes sku = Left AttachmentShapeMismatch
  | nodeRootSizeGiB node < skuMinimumRootGiB sku || nodeRootSizeGiB node `mod` skuRootQuantumGiB sku /= 0 = Left RootVolumeShapeMismatch
  | accountVcpuUsed account + baseVcpus > accountVcpuLimit account = Left ProviderVcpuQuotaShort
  | accountNodeGroupsUsed account + 1 > accountNodeGroupLimit account = Left ManagedNodeGroupQuotaShort
  | accountEbsBytesUsed account + rootBytes > accountEbsByteLimit account = Left ProviderEbsQuotaShort
  | otherwise = Right (ValidatedInfrastructurePlan demand (accountFingerprint account))
 where
  node = providerNodeClass demand
  sku = providerSku demand
  baseVcpus = providerBaseNodeCount demand * skuRawVcpus sku
  rootBytes = providerBaseNodeCount demand * nodeRootSizeGiB node * 1073741824

data ProviderReadback = ProviderReadback
  { readbackAccountFingerprint :: String
  , readbackClusterName :: String
  , readbackControlPlaneReady :: Bool
  , readbackManagedNodeCount :: Integer
  , readbackMachineType :: String
  , readbackAccelerator :: AcceleratorOffering
  }
  deriving stock (Eq, Show)

newtype ProvisionContext = ProvisionContext ProviderReadback
  deriving stock (Eq, Show)

acceptProviderReadback
  :: ValidatedInfrastructurePlan
  -> ProviderReadback
  -> Either ProviderPlanError ProvisionContext
acceptProviderReadback plan readback
  | readbackAccountFingerprint readback /= validatedPlanFingerprint plan = Left ProviderFingerprintChanged
  | not (readbackControlPlaneReady readback) = Left ProviderReadbackMismatch
  | readbackClusterName readback /= providerClusterName demand = Left ProviderReadbackMismatch
  | readbackManagedNodeCount readback /= providerBaseNodeCount demand = Left ProviderReadbackMismatch
  | readbackMachineType readback /= nodeMachineType node = Left ProviderReadbackMismatch
  | readbackAccelerator readback /= NoAccelerator = Left ProviderReadbackMismatch
  | otherwise = Right (ProvisionContext readback)
 where
  demand = validatedDemand plan
  node = providerNodeClass demand

provisionedClusterName :: ProvisionContext -> String
provisionedClusterName (ProvisionContext readback) = readbackClusterName readback
