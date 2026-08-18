{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Fabric.Keys
  ( PeerKeyRef
  , PeerKeyPair
  , peerKeyRef
  , peerPrivateRef
  , peerPublicRef
  , checkedPeerKeyPair
  , resolvePeerKeyPair
  , privateKeyBytes
  , publicKeyBytes
  ) where

import Amoebius.Vault.Client
import Amoebius.Vault.Error (VaultError (..))
import Amoebius.Vault.SecretRef
import Control.Monad (unless)
import Data.ByteString (ByteString)
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Base64 as Base64
import Data.Text (Text)

-- | Both fields must belong to one Vault KV object.  There is deliberately no
-- constructor accepting key bytes or a Transit reference.
data PeerKeyRef = PeerKeyRef
  { peerPrivateRef :: SecretRef
  , peerPublicRef :: SecretRef
  }
  deriving stock (Eq, Ord, Show)

-- | Secret key material has no Show instance and cannot enter rendered config.
data PeerKeyPair = PeerKeyPair ByteString ByteString
  deriving stock (Eq)

peerKeyRef :: Text -> Text -> Text -> Text -> Either Text PeerKeyRef
peerKeyRef mount path privateField publicField = do
  unless (privateField /= publicField) (Left "wireguard-key-fields-equal")
  privateRef <- vaultSecretRef mount path privateField
  publicRef <- vaultSecretRef mount path publicField
  pure (PeerKeyRef privateRef publicRef)

checkedPeerKeyPair :: ByteString -> ByteString -> Either Text PeerKeyPair
checkedPeerKeyPair privateBytes publicBytes = do
  validateCurve25519 "private" privateBytes
  validateCurve25519 "public" publicBytes
  pure (PeerKeyPair privateBytes publicBytes)

resolvePeerKeyPair
  :: Monad m
  => VaultTransport m
  -> KubernetesIdentity
  -> ByteString
  -> PeerKeyRef
  -> m (Either VaultError PeerKeyPair)
resolvePeerKeyPair transport identity jwt references = do
  privateResult <- resolveSecret transport identity jwt (peerPrivateRef references) Nothing
  publicResult <- resolveSecret transport identity jwt (peerPublicRef references) Nothing
  pure $ do
#ifdef NETWORK_FABRIC_WIREGUARD_MISSING_PEER_KEY_MUTANT
    privateBytes <- either (const (Right "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")) Right privateResult
    publicBytes <- either (const (Right "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")) Right publicResult
#else
    privateBytes <- privateResult
    publicBytes <- publicResult
#endif
    either (const (Left VaultSecretMissing)) Right (checkedPeerKeyPair privateBytes publicBytes)

privateKeyBytes :: PeerKeyPair -> ByteString
privateKeyBytes (PeerKeyPair privateBytes _) = privateBytes

publicKeyBytes :: PeerKeyPair -> ByteString
publicKeyBytes (PeerKeyPair _ publicBytes) = publicBytes

validateCurve25519 :: Text -> ByteString -> Either Text ()
validateCurve25519 label encoded =
  case Base64.decode encoded of
    Left _ -> Left ("wireguard-" <> label <> "-key-base64")
    Right raw
      | ByteString.length raw == 32 -> Right ()
      | otherwise -> Left ("wireguard-" <> label <> "-key-length")
