{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Pure registry-object and transient-upload accounting.  Resident objects
-- remain charged until an observer reports them absent; equal digests debit
-- once and unequal byte metadata fails closed.
module Amoebius.Image.Registry
  ( RegistryMutationAdmission (..)
  , RegistryStorageDemand (..)
  , ProvisionedRegistryStorageDemand
  , provisionedRegistryObjects
  , provisionedRegistryNewObjects
  , provisionedRegistryStoredBytes
  , provisionedRegistryNewObjectBytes
  , provisionedRegistryUploadWorkspaceBytes
  , provisionedRegistryFailedUploadBytes
  , provisionedRegistryPeakBytes
  , provisionedRegistryGcHorizonSeconds
  , RegistryError (..)
  , registryDemandFromArtifact
  , provisionRegistryStorage
  , renderRegistryError
  ) where

import Amoebius.Image.Artifact
  ( ImageArtifact
  , RegistryStoredArtifact (..)
  , registryStoredArtifacts
  )
import Control.DeepSeq (NFData)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data RegistryMutationAdmission = RegistryMutationAdmission
  { registryPublisherCapabilityDigest :: Text
  , registryAdmittedDigests :: Set Text
  , registryMaxConcurrentUploads :: Natural
  , registryMaxObjectBytes :: Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data RegistryStorageDemand = RegistryStorageDemand
  { registryDesiredObjects :: Map Text Natural
  , registryObservedResidentObjects :: Map Text Natural
  , registryUploadConcurrency :: Natural
  , registryUploadWorkspaceBytesPerUpload :: Natural
  , registryFailedUploadsPerWindow :: Natural
  , registryPartialBytesPerFailedUpload :: Natural
  , registryGcHorizonSeconds :: Natural
  , registryVolumeCapacityBytes :: Natural
  , registryMutationAdmission :: RegistryMutationAdmission
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ProvisionedRegistryStorageDemand = ProvisionedRegistryStorageDemand
  { provisionedRegistryObjects :: Map Text Natural
  , provisionedRegistryNewObjects :: Map Text Natural
  , provisionedRegistryStoredBytes :: Natural
  , provisionedRegistryNewObjectBytes :: Natural
  , provisionedRegistryUploadWorkspaceBytes :: Natural
  , provisionedRegistryFailedUploadBytes :: Natural
  , provisionedRegistryPeakBytes :: Natural
  , provisionedRegistryGcHorizonSeconds :: Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data RegistryError
  = RegistryArtifactInvalid Text
  | RegistryDigestInvalid Text
  | RegistryObjectBytesZero Text
  | RegistryDigestSizeConflict Text Natural Natural
  | RegistryUploadConcurrencyInvalid
  | RegistryUploadWorkspaceInvalid
  | RegistryGcHorizonInvalid
  | RegistryMutationCapabilityInvalid
  | RegistryMutationDigestSetMismatch (Set Text) (Set Text)
  | RegistryMutationConcurrencyMismatch Natural Natural
  | RegistryMutationObjectLimitExceeded Text Natural Natural
  | RegistryStorageExceeded Natural Natural
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

registryDemandFromArtifact
  :: ImageArtifact
  -> Map Text Natural
  -> Natural
  -> Natural
  -> Natural
  -> Natural
  -> Natural
  -> Natural
  -> Text
  -> Either RegistryError RegistryStorageDemand
registryDemandFromArtifact artifact residents concurrency workspace failures partial horizon capacity capability = do
  stored <- either (Left . RegistryArtifactInvalid . Text.pack . show) Right (registryStoredArtifacts artifact)
  let desired = Map.map registryObjectStoredBytes stored
      largestObject = maximumNatural (Map.elems desired)
  pure
    RegistryStorageDemand
      { registryDesiredObjects = desired
      , registryObservedResidentObjects = residents
      , registryUploadConcurrency = concurrency
      , registryUploadWorkspaceBytesPerUpload = workspace
      , registryFailedUploadsPerWindow = failures
      , registryPartialBytesPerFailedUpload = partial
      , registryGcHorizonSeconds = horizon
      , registryVolumeCapacityBytes = capacity
      , registryMutationAdmission =
          RegistryMutationAdmission
            { registryPublisherCapabilityDigest = capability
            , registryAdmittedDigests = Map.keysSet desired
            , registryMaxConcurrentUploads = concurrency
            , registryMaxObjectBytes = largestObject
            }
      }

provisionRegistryStorage
  :: RegistryStorageDemand
  -> Either RegistryError ProvisionedRegistryStorageDemand
provisionRegistryStorage demand = do
  validateObjectMap (registryDesiredObjects demand)
  validateObjectMap (registryObservedResidentObjects demand)
  if registryUploadConcurrency demand == 0
    then Left RegistryUploadConcurrencyInvalid
    else Right ()
  if registryUploadWorkspaceBytesPerUpload demand == 0
    then Left RegistryUploadWorkspaceInvalid
    else Right ()
  if registryGcHorizonSeconds demand == 0
    then Left RegistryGcHorizonInvalid
    else Right ()
  validateMutation demand
  union <- exactUnion (registryObservedResidentObjects demand) (registryDesiredObjects demand)
  let newObjects = Map.difference (registryDesiredObjects demand) (registryObservedResidentObjects demand)
      storedBytes = sum (Map.elems union)
      newBytes = sum (Map.elems newObjects)
      workspace = registryUploadConcurrency demand * registryUploadWorkspaceBytesPerUpload demand
      failedResidue = registryFailedUploadsPerWindow demand * registryPartialBytesPerFailedUpload demand
      peak = storedBytes + workspace + failedResidue
      capacity = registryVolumeCapacityBytes demand
  if peak > capacity
    then Left (RegistryStorageExceeded peak capacity)
    else
      Right
        ProvisionedRegistryStorageDemand
          { provisionedRegistryObjects = union
          , provisionedRegistryNewObjects = newObjects
          , provisionedRegistryStoredBytes = storedBytes
          , provisionedRegistryNewObjectBytes = newBytes
          , provisionedRegistryUploadWorkspaceBytes = workspace
          , provisionedRegistryFailedUploadBytes = failedResidue
          , provisionedRegistryPeakBytes = peak
          , provisionedRegistryGcHorizonSeconds = registryGcHorizonSeconds demand
          }

renderRegistryError :: RegistryError -> Text
renderRegistryError problem = case problem of
  RegistryArtifactInvalid _ -> "RegistryArtifactInvalid"
  RegistryDigestInvalid _ -> "RegistryDigestInvalid"
  RegistryObjectBytesZero _ -> "RegistryObjectBytesZero"
  RegistryDigestSizeConflict _ _ _ -> "RegistryDigestSizeConflict"
  RegistryUploadConcurrencyInvalid -> "RegistryUploadConcurrencyInvalid"
  RegistryUploadWorkspaceInvalid -> "RegistryUploadWorkspaceInvalid"
  RegistryGcHorizonInvalid -> "RegistryGcHorizonInvalid"
  RegistryMutationCapabilityInvalid -> "RegistryMutationCapabilityInvalid"
  RegistryMutationDigestSetMismatch _ _ -> "RegistryMutationDigestSetMismatch"
  RegistryMutationConcurrencyMismatch _ _ -> "RegistryMutationConcurrencyMismatch"
  RegistryMutationObjectLimitExceeded _ _ _ -> "RegistryMutationObjectLimitExceeded"
  RegistryStorageExceeded _ _ -> "RegistryStorageExceeded"

validateMutation :: RegistryStorageDemand -> Either RegistryError ()
validateMutation demand = do
  let admission = registryMutationAdmission demand
      desired = registryDesiredObjects demand
      desiredDigests = Map.keysSet desired
  validateDigest (registryPublisherCapabilityDigest admission)
    `orElse` RegistryMutationCapabilityInvalid
  if registryAdmittedDigests admission == desiredDigests
    then Right ()
    else Left (RegistryMutationDigestSetMismatch desiredDigests (registryAdmittedDigests admission))
  if registryMaxConcurrentUploads admission == registryUploadConcurrency demand
    then Right ()
    else Left (RegistryMutationConcurrencyMismatch (registryUploadConcurrency demand) (registryMaxConcurrentUploads admission))
  case [(digest, bytes) | (digest, bytes) <- Map.toList desired, bytes > registryMaxObjectBytes admission] of
    [] -> Right ()
    (digest, bytes) : _ -> Left (RegistryMutationObjectLimitExceeded digest bytes (registryMaxObjectBytes admission))

validateObjectMap :: Map Text Natural -> Either RegistryError ()
validateObjectMap objects = mapM_ validateOne (Map.toList objects)
 where
  validateOne (digest, bytes) = do
    validateDigest digest
    if bytes == 0 then Left (RegistryObjectBytesZero digest) else Right ()

validateDigest :: Text -> Either RegistryError ()
validateDigest digest =
  if Text.length digest == 71
      && "sha256:" `Text.isPrefixOf` digest
      && Text.all (`elem` ("0123456789abcdef" :: String)) (Text.drop 7 digest)
    then Right ()
    else Left (RegistryDigestInvalid digest)

exactUnion :: Map Text Natural -> Map Text Natural -> Either RegistryError (Map Text Natural)
exactUnion = Map.foldlWithKey' insertOne . Right
 where
  insertOne outcome digest bytes = do
    accumulated <- outcome
    case Map.lookup digest accumulated of
      Nothing -> Right (Map.insert digest bytes accumulated)
      Just resident
        | resident == bytes -> Right accumulated
        | otherwise -> Left (RegistryDigestSizeConflict digest resident bytes)

orElse :: Either value () -> value -> Either value ()
orElse outcome replacement = case outcome of
  Left _ -> Left replacement
  Right () -> Right ()

maximumNatural :: [Natural] -> Natural
maximumNatural values = case values of
  [] -> 0
  _ -> maximum values
