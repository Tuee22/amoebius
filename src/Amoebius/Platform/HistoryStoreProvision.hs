{-# LANGUAGE OverloadedStrings #-}

-- | Separate retained components for the object gateway and metadata history.
-- A private witness checks every slot before combining them on one filesystem.
-- This supplies storage admission, not RPC/JVM execution or import authority.
module Amoebius.Platform.HistoryStoreProvision
  ( HistoryStoreStorageDemand (..), ProvisionedHistoryStoreStorage
  , nativeHistoryStoreStorageDemand
  , provisionHistoryStoreStorage, historyStoreStorageProjection
  , historyStoreFilesystemUsableBytes, historyStoreFilesystemRawBytes
  ) where

import Amoebius.Capacity.Storage
  (FilesystemPresentation (FilesystemPresentation), presentBytes,
   BackingAllocationPolicy (BackingAllocationPolicy), roundAllocation)
import Amoebius.Platform.ZooKeeperHistory
import Amoebius.Platform.ZooKeeperHistoryStore (historyStoreMaximumBytes)
import Control.Monad (unless)
import Data.Aeson (Value, object, (.=))
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Numeric.Natural (Natural)

data HistoryStoreStorageDemand = HistoryStoreStorageDemand
  { gatewayCurrentBytes :: Natural, gatewayCandidateBytes :: Natural
  , gatewayFailedBytes :: Natural, gatewayControlReserveBytes :: Natural
  , gatewayDedicatedUsableBytes :: Natural
  , historyCurrentSlotBytes :: Natural, historyCandidateSlotBytes :: Natural
  , historyExtraReaderSlotBytes :: Natural, historyMaximumExtraReaders :: Natural
  , historyEnforcedFileMaximumBytes :: Natural, historyNativeEncodingUpperBoundBytes :: Natural
  , historyDedicatedUsableBytes :: Natural, combinedFilesystemUsableSupplyBytes :: Natural
  , rawFilesystemSupplyBytes :: Natural, filesystemOverheadBasisPoints :: Natural
  , minimumRawBytes :: Natural, rawQuantumBytes :: Natural, parentRawSupplyBytes :: Natural
  } deriving stock (Eq, Show)

data ProvisionedHistoryStoreStorage = ProvisionedHistoryStoreStorage
  HistoryPolicy HistoryStoreStorageDemand Natural Natural Natural Natural
  deriving stock (Eq, Show)

nativeHistoryStoreStorageDemand :: HistoryPolicy -> Natural -> HistoryStoreStorageDemand
nativeHistoryStoreStorageDemand policy parentSupply = HistoryStoreStorageDemand
  { gatewayCurrentBytes = mib, gatewayCandidateBytes = mib, gatewayFailedBytes = mib
  , gatewayControlReserveBytes = 2*mib, gatewayDedicatedUsableBytes = 5*mib
  , historyCurrentSlotBytes = fileMaximum, historyCandidateSlotBytes = fileMaximum
  , historyExtraReaderSlotBytes = fileMaximum, historyMaximumExtraReaders = 1
  , historyEnforcedFileMaximumBytes = fileMaximum
  , historyNativeEncodingUpperBoundBytes = historyStateEncodingBounds policy Map.! "maximumTotalStateBytes"
  , historyDedicatedUsableBytes = 3*fileMaximum
  , combinedFilesystemUsableSupplyBytes = 5*mib+3*fileMaximum
  , rawFilesystemSupplyBytes = 64*mib, filesystemOverheadBasisPoints = 500
  , minimumRawBytes = 64*mib, rawQuantumBytes = 64*mib, parentRawSupplyBytes = parentSupply }
 where
  mib = 1048576
  fileMaximum = fromIntegral historyStoreMaximumBytes

provisionHistoryStoreStorage :: HistoryPolicy -> Natural -> HistoryStoreStorageDemand
  -> Either Text ProvisionedHistoryStoreStorage
provisionHistoryStoreStorage policy parentRequired demand = do
  let encodedBound = historyStateEncodingBounds policy Map.! "maximumTotalStateBytes"
      reportedBound = historyNativeEncodingUpperBoundBytes demand
      fileMaximum = historyEnforcedFileMaximumBytes demand
      slotChecks = [(historyCurrentSlotBytes demand,"history-current-slot"),
        (historyCandidateSlotBytes demand,"history-candidate-slot"),
        (historyExtraReaderSlotBytes demand,"history-reader-slot")]
  unless (reportedBound >= encodedBound && reportedBound <= fileMaximum)
    (Left "native-encoding-exceeds-enforced-bound")
  unless (historyMaximumExtraReaders demand == 1) (Left "history-reader-count")
  mapM_ (\(bytes,locus) -> unless (bytes >= fileMaximum) (Left locus)) slotChecks
  unless (fileMaximum == fromIntegral historyStoreMaximumBytes) (Left "history-store-file-bound-mismatch")
  unless (gatewayCurrentBytes demand >= mib && gatewayCandidateBytes demand >= mib
    && gatewayFailedBytes demand >= mib && gatewayControlReserveBytes demand >= 2*mib)
    (Left "original-gateway-slot-or-control")
  let gatewayRequired = gatewayCurrentBytes demand + gatewayCandidateBytes demand
        + gatewayFailedBytes demand + gatewayControlReserveBytes demand
      historyRequired = historyCurrentSlotBytes demand + historyCandidateSlotBytes demand
        + historyMaximumExtraReaders demand * historyExtraReaderSlotBytes demand
  unless (gatewayDedicatedUsableBytes demand >= gatewayRequired) (Left "original-gateway-component")
  unless (historyDedicatedUsableBytes demand >= historyRequired) (Left "history-component")
  let combined = gatewayDedicatedUsableBytes demand + historyDedicatedUsableBytes demand
  unless (combinedFilesystemUsableSupplyBytes demand >= combined) (Left "combined-filesystem-usable")
  unless ((filesystemOverheadBasisPoints demand,minimumRawBytes demand,rawQuantumBytes demand)
    == (500,64*mib,64*mib)) (Left "history-store-filesystem-profile")
  let presented = presentBytes (FilesystemPresentation "ext4-v1" (filesystemOverheadBasisPoints demand)) combined
      rawRequired = roundAllocation (BackingAllocationPolicy (minimumRawBytes demand) (rawQuantumBytes demand)) presented
  unless (rawFilesystemSupplyBytes demand >= rawRequired) (Left "gateway-raw-filesystem")
  unless (parentRequired >= rawRequired && parentRawSupplyBytes demand >= parentRequired) (Left "retained-parent")
  pure (ProvisionedHistoryStoreStorage policy demand parentRequired encodedBound presented rawRequired)
 where
  mib = 1048576

historyStoreFilesystemUsableBytes :: ProvisionedHistoryStoreStorage -> Natural
historyStoreFilesystemUsableBytes (ProvisionedHistoryStoreStorage _ demand _ _ _ _) =
  gatewayDedicatedUsableBytes demand + historyDedicatedUsableBytes demand

historyStoreFilesystemRawBytes :: ProvisionedHistoryStoreStorage -> Natural
historyStoreFilesystemRawBytes (ProvisionedHistoryStoreStorage _ _ _ _ _ raw) = raw

historyStoreStorageProjection :: ProvisionedHistoryStoreStorage -> Value
historyStoreStorageProjection witness@(ProvisionedHistoryStoreStorage policy demand parent encoded presented _) = object
  ["originalGateway" .= object ["currentBytes" .= gatewayCurrentBytes demand,
     "candidateBytes" .= gatewayCandidateBytes demand,"failedBytes" .= gatewayFailedBytes demand,
     "controlReserveBytes" .= gatewayControlReserveBytes demand,"dedicatedUsableBytes" .= gatewayDedicatedUsableBytes demand],
   "metadataHistory" .= object ["currentSlotBytes" .= historyCurrentSlotBytes demand,
     "candidateSlotBytes" .= historyCandidateSlotBytes demand,"extraReaderSlotBytes" .= historyExtraReaderSlotBytes demand,
     "maximumExtraReaders" .= historyMaximumExtraReaders demand,"enforcedFileMaximumBytes" .= historyEnforcedFileMaximumBytes demand,
     "derivedEncodingUpperBoundBytes" .= encoded,"reservedEncodingUpperBoundBytes" .= historyNativeEncodingUpperBoundBytes demand,
     "dedicatedUsableBytes" .= historyDedicatedUsableBytes demand,"policy" .= historyPolicyValue policy],
   "combinedFilesystemUsableBytes" .= historyStoreFilesystemUsableBytes witness,
   "presentedBytes" .= presented,"requiredRawBytes" .= historyStoreFilesystemRawBytes witness,
   "rawSupplyBytes" .= rawFilesystemSupplyBytes demand,"parentRequiredRawBytes" .= parent,
   "parentSupplyRawBytes" .= parentRawSupplyBytes demand]
