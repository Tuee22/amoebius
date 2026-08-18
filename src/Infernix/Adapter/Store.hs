{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Infernix.Adapter.Store
  ( StagedArtifact
  , ReadyArtifactHandle
  , ArtifactError (..)
  , stageArtifact
  , commitReadyPointer
  , authorizeReadyArtifact
  , rejectForgedWireReference
  , readyArtifactScope
  , readyArtifactCatalog
  , readyArtifactPayload
  , readyArtifactBlobDigest
  , readyArtifactManifestDigest
  , readyArtifactPointerKey
  ) where

import Amoebius.Store.ContentAddress (ContentDigest, contentDigest, digestHex)
import Amoebius.Store.Manifest (Component (..), manifest, manifestContentDigest)
import Amoebius.Store.Pointer (PointerName (..), pointerKey)
import Data.ByteString (ByteString)
import Data.Text (Text)
import Infernix.Adapter.Engine (CatalogIdentity, catalogIdentityText)
import Infernix.Adapter.Secrets (ServiceCredential, TenantScope, credentialScope, tenantScopeText)

data StagedArtifact = StagedArtifact
  { stagedScope :: TenantScope
  , stagedCatalog :: CatalogIdentity
  , stagedPayload :: ByteString
  , stagedBlobDigest :: ContentDigest
  , stagedManifestDigest :: ContentDigest
  }
  deriving stock (Eq, Show)

data ReadyArtifactHandle = ReadyArtifactHandle StagedArtifact Text
  deriving stock (Eq, Show)

data ArtifactError
  = ArtifactManifestInvalid Text
  | ArtifactNotReady
  | ArtifactUnavailable
  deriving stock (Eq, Show)

stageArtifact :: TenantScope -> CatalogIdentity -> ByteString -> Either ArtifactError StagedArtifact
stageArtifact scope catalog payload = do
  let blobDigest = contentDigest payload
  value <- either (Left . ArtifactManifestInvalid) Right (manifest [Component "model" blobDigest])
  pure
    StagedArtifact
      { stagedScope = scope
      , stagedCatalog = catalog
      , stagedPayload = payload
      , stagedBlobDigest = blobDigest
      , stagedManifestDigest = manifestContentDigest value
      }

commitReadyPointer :: Bool -> StagedArtifact -> Either ArtifactError ReadyArtifactHandle
#ifdef INFERNIX_LIFT_MINT_READY_BEFORE_POINTER_COMMIT_MUTANT
commitReadyPointer _ staged = Right (ready staged)
#else
commitReadyPointer committed staged
  | committed = Right (ready staged)
  | otherwise = Left ArtifactNotReady
#endif
 where
  ready value = ReadyArtifactHandle value (pointerFor value)

authorizeReadyArtifact :: ServiceCredential -> ReadyArtifactHandle -> Either ArtifactError ReadyArtifactHandle
authorizeReadyArtifact credential handle@(ReadyArtifactHandle staged _)
#ifdef INFERNIX_LIFT_DROP_ARTIFACT_SCOPE_MUTANT
  | credentialScope credential /= stagedScope staged = Right handle
#else
  | credentialScope credential /= stagedScope staged = Left ArtifactUnavailable
#endif
  | otherwise = Right handle

rejectForgedWireReference :: TenantScope -> CatalogIdentity -> Text -> Either ArtifactError ReadyArtifactHandle
rejectForgedWireReference _ _ _ = Left ArtifactNotReady

readyArtifactScope :: ReadyArtifactHandle -> TenantScope
readyArtifactScope (ReadyArtifactHandle staged _) = stagedScope staged

readyArtifactCatalog :: ReadyArtifactHandle -> CatalogIdentity
readyArtifactCatalog (ReadyArtifactHandle staged _) = stagedCatalog staged

readyArtifactPayload :: ReadyArtifactHandle -> ByteString
readyArtifactPayload (ReadyArtifactHandle staged _) = stagedPayload staged

readyArtifactBlobDigest :: ReadyArtifactHandle -> Text
readyArtifactBlobDigest (ReadyArtifactHandle staged _) = digestHex (stagedBlobDigest staged)

readyArtifactManifestDigest :: ReadyArtifactHandle -> Text
readyArtifactManifestDigest (ReadyArtifactHandle staged _) = digestHex (stagedManifestDigest staged)

readyArtifactPointerKey :: ReadyArtifactHandle -> Text
readyArtifactPointerKey (ReadyArtifactHandle _ key) = key

pointerFor :: StagedArtifact -> Text
pointerFor staged =
  pointerKey
    ("infernix/" <> tenantScopeText (stagedScope staged))
    (PointerName (catalogIdentityText (stagedCatalog staged)))
