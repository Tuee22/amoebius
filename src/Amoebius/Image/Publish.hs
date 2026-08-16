{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Snapshot-bound, single-use final manifest-list advertisement.  Blobs and
-- digest-addressed child manifests are staged first; only this final buildx
-- invocation makes the immutable tag visible.
module Amoebius.Image.Publish
  ( PublicationPlan (..)
  , ObservedPublicationTarget (..)
  , ProvisionedPublication
  , provisionedPublicationRef
  , PublicationDecision (..)
  , PublicationAction
  , PublicationReceipt (..)
  , PublicationResult (..)
  , PublicationError (..)
  , provisionPublication
  , validatePublicationTarget
  , enactPublication
  , renderPublicationError
  ) where

import Amoebius.Image.Ref
  ( ImmutableImageRef
  , immutableImageDigestReference
  , immutableImageIndexDigest
  , immutableImageRepository
  , immutableImageTaggedReference
  )
import Amoebius.Image.Registry
  ( ProvisionedRegistryStorageDemand
  , provisionedRegistryObjects
  )
import Control.DeepSeq (NFData)
import Data.IORef (IORef, atomicModifyIORef', newIORef)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import System.Exit (ExitCode (..))
import System.FilePath (isAbsolute)

data PublicationPlan = PublicationPlan
  { publicationDockerExecutable :: FilePath
  , publicationDockerConfigDirectory :: FilePath
  , publicationRef :: ImmutableImageRef
  , publicationChildManifestDigests :: [Text]
  , publicationPublisherCapabilityDigest :: Text
  , publicationSourceDigest :: Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ObservedPublicationTarget = ObservedPublicationTarget
  { observedPublicationFingerprint :: Text
  , observedPublicationSourceDigest :: Text
  , observedPublishedIndexDigest :: Maybe Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ProvisionedPublication = ProvisionedPublication
  { provisionedPublicationStorage :: ProvisionedRegistryStorageDemand
  , provisionedPublicationPlan :: PublicationPlan
  , provisionedPublicationRef :: ImmutableImageRef
  }

data PublicationDecision
  = PublicationRequired PublicationAction
  | PublicationNoOp PublicationReceipt

data PublicationAction = PublicationAction
  { publicationActionFingerprint :: Text
  , publicationActionPlan :: PublicationPlan
  , publicationActionConsumed :: IORef Bool
  }

data PublicationReceipt = PublicationReceipt
  { publicationReceiptFingerprint :: Text
  , publicationReceiptTaggedReference :: Text
  , publicationReceiptDigestReference :: Text
  , publicationReceiptAdvertised :: Bool
  , publicationReceiptMutatingRequests :: Int
  , publicationReceiptConsumed :: Bool
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data PublicationResult
  = PublicationApplied PublicationReceipt
  | PublicationFailed PublicationReceipt Int
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data PublicationError
  = PublicationDockerExecutableInvalid FilePath
  | PublicationDockerConfigInvalid FilePath
  | PublicationCapabilityInvalid Text
  | PublicationSourceDigestInvalid Text
  | PublicationIndexNotProvisioned Text
  | PublicationChildManifestNotProvisioned Text
  | PublicationChildManifestSetInvalid
  | PublicationSourceDigestMismatch Text Text
  | PublicationObservedDigestConflict Text Text
  | PublicationSnapshotChanged Text Text
  | PublicationActionAlreadyConsumed
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

provisionPublication
  :: ProvisionedRegistryStorageDemand
  -> PublicationPlan
  -> Either PublicationError ProvisionedPublication
provisionPublication storage plan = do
  if publicationDockerExecutable plan == "/usr/bin/docker"
    then Right ()
    else Left (PublicationDockerExecutableInvalid (publicationDockerExecutable plan))
  if isAbsolute (publicationDockerConfigDirectory plan)
    then Right ()
    else Left (PublicationDockerConfigInvalid (publicationDockerConfigDirectory plan))
  validateDigest PublicationCapabilityInvalid (publicationPublisherCapabilityDigest plan)
  validateDigest PublicationSourceDigestInvalid (publicationSourceDigest plan)
  let objects = provisionedRegistryObjects storage
      indexDigest = immutableImageIndexDigest (publicationRef plan)
      children = publicationChildManifestDigests plan
  if Map.member indexDigest objects
    then Right ()
    else Left (PublicationIndexNotProvisioned indexDigest)
  if length children == 2 && length (unique children) == 2
    then Right ()
    else Left PublicationChildManifestSetInvalid
  mapM_
    (\digest -> if Map.member digest objects then Right () else Left (PublicationChildManifestNotProvisioned digest))
    children
  pure
    ProvisionedPublication
      { provisionedPublicationStorage = storage
      , provisionedPublicationPlan = plan
      , provisionedPublicationRef = publicationRef plan
      }

validatePublicationTarget
  :: ProvisionedPublication
  -> ObservedPublicationTarget
  -> IO (Either PublicationError PublicationDecision)
validatePublicationTarget provision observed
  | publicationSourceDigest plan /= observedPublicationSourceDigest observed =
      pure (Left (PublicationSourceDigestMismatch (publicationSourceDigest plan) (observedPublicationSourceDigest observed)))
  | otherwise = case observedPublishedIndexDigest observed of
      Nothing -> do
        consumed <- newIORef False
        pure
          ( Right
              ( PublicationRequired
                  PublicationAction
                    { publicationActionFingerprint = observedPublicationFingerprint observed
                    , publicationActionPlan = plan
                    , publicationActionConsumed = consumed
                    }
              )
          )
      Just digest
        | digest == immutableImageIndexDigest (publicationRef plan) ->
            pure (Right (PublicationNoOp (receipt observed plan True 0 False)))
        | otherwise ->
            pure (Left (PublicationObservedDigestConflict (immutableImageIndexDigest (publicationRef plan)) digest))
 where
  plan = provisionedPublicationPlan provision

enactPublication
  :: PublicationAction
  -> ObservedPublicationTarget
  -> (FilePath -> [String] -> IO ExitCode)
  -> IO (Either PublicationError PublicationResult)
enactPublication action observed runProcess
  | publicationActionFingerprint action /= observedPublicationFingerprint observed =
      pure (Left (PublicationSnapshotChanged (publicationActionFingerprint action) (observedPublicationFingerprint observed)))
  | otherwise = do
      won <- atomicModifyIORef' (publicationActionConsumed action) (\consumed -> (True, not consumed))
      if not won
        then pure (Left PublicationActionAlreadyConsumed)
        else do
          let plan = publicationActionPlan action
              (executable, arguments) = publicationInvocation plan
          status <- runProcess executable arguments
          pure
            ( case status of
                ExitSuccess -> Right (PublicationApplied (receipt observed plan True 1 True))
                ExitFailure code -> Right (PublicationFailed (receipt observed plan advertisedOnFailure 1 True) code)
            )

renderPublicationError :: PublicationError -> Text
renderPublicationError problem = case problem of
  PublicationDockerExecutableInvalid _ -> "PublicationDockerExecutableInvalid"
  PublicationDockerConfigInvalid _ -> "PublicationDockerConfigInvalid"
  PublicationCapabilityInvalid _ -> "PublicationCapabilityInvalid"
  PublicationSourceDigestInvalid _ -> "PublicationSourceDigestInvalid"
  PublicationIndexNotProvisioned _ -> "PublicationIndexNotProvisioned"
  PublicationChildManifestNotProvisioned _ -> "PublicationChildManifestNotProvisioned"
  PublicationChildManifestSetInvalid -> "PublicationChildManifestSetInvalid"
  PublicationSourceDigestMismatch _ _ -> "PublicationSourceDigestMismatch"
  PublicationObservedDigestConflict _ _ -> "PublicationObservedDigestConflict"
  PublicationSnapshotChanged _ _ -> "PublicationSnapshotChanged"
  PublicationActionAlreadyConsumed -> "PublicationActionAlreadyConsumed"

publicationInvocation :: PublicationPlan -> (FilePath, [String])
publicationInvocation plan =
  ( publicationDockerExecutable plan
  , [ "--config", publicationDockerConfigDirectory plan
    , "buildx", "imagetools", "create"
    , "--tag", Text.unpack (immutableImageTaggedReference (publicationRef plan))
    ]
      <> fmap
        (\digest -> Text.unpack (immutableImageRepository (publicationRef plan) <> "@" <> digest))
        (publicationChildManifestDigests plan)
  )

receipt :: ObservedPublicationTarget -> PublicationPlan -> Bool -> Int -> Bool -> PublicationReceipt
receipt observed plan advertised mutations consumed =
  PublicationReceipt
    { publicationReceiptFingerprint = observedPublicationFingerprint observed
    , publicationReceiptTaggedReference = immutableImageTaggedReference (publicationRef plan)
    , publicationReceiptDigestReference = immutableImageDigestReference (publicationRef plan)
    , publicationReceiptAdvertised = advertised
    , publicationReceiptMutatingRequests = mutations
    , publicationReceiptConsumed = consumed
    }

validateDigest :: (Text -> PublicationError) -> Text -> Either PublicationError ()
validateDigest constructor digest =
  if Text.length digest == 71
      && "sha256:" `Text.isPrefixOf` digest
      && Text.all (`elem` ("0123456789abcdef" :: String)) (Text.drop 7 digest)
    then Right ()
    else Left (constructor digest)

unique :: Eq value => [value] -> [value]
unique values = case values of
  [] -> []
  value : rest -> value : unique (filter (/= value) rest)

advertisedOnFailure :: Bool
#ifdef BASE_IMAGE_REGISTRY_RECORD_BEFORE_PUSH_MUTANT
advertisedOnFailure = True
#else
advertisedOnFailure = False
#endif
