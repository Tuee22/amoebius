{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

-- | Explicit test authority. Fixtures sign an envelope with their own known
-- key and pass it through the product verifier; they cannot construct a scope.
module Amoebius.Test.ScopeFixture (fixtureIdentity, fixtureIdentityText, withFixtureScope) where

import Amoebius.Scope.Attested
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString qualified as ByteString
import Data.ByteString.Builder qualified as Builder
import Data.ByteString.Lazy qualified as Lazy
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import Numeric (showHex)

fixtureIdentity :: Tenant -> Subject -> Either ScopeError (Identity 'Attested)
fixtureIdentity tenant subject
  | subjectTenant subject /= tenant = Left MembershipMismatch
  | otherwise = fixtureIdentityText (tenantText tenant) (subjectText subject)

fixtureIdentityText :: Text -> Text -> Either ScopeError (Identity 'Attested)
fixtureIdentityText tenant subject = case verificationKey authority of
  Nothing -> Left MembershipMismatch
  Just key -> either (const (Left MembershipMismatch)) Right
    (verifyIdentity key (SignedIdentityEnvelope tenant subject signature))
 where
  authority = "amoebius-unit-fixture-authority"
  fields = map Encoding.encodeUtf8 [authority, tenant, subject]
  framed = Lazy.toStrict (Builder.toLazyByteString (foldMap
    (\bytes -> Builder.word64BE (fromIntegral (ByteString.length bytes)) <> Builder.byteString bytes) fields))
  signature = Text.pack (concatMap hexByte (ByteString.unpack (SHA256.hash framed)))
  hexByte byte = case showHex byte "" of [single] -> ['0', single]; digits -> digits

withFixtureScope
  :: Tenant -> Subject -> Membership
  -> (forall scope. RequestScope scope -> result)
  -> Either ScopeError result
withFixtureScope tenant subject membership continuation
  | activeMembership tenant subject /= Right membership = Left MembershipMismatch
  | otherwise = do
      identity <- fixtureIdentity tenant subject
      attest (principalAttestation identity) continuation
