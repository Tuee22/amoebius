{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RoleAnnotations #-}
{-# LANGUAGE RankNTypes #-}

module Amoebius.Scope.Attested
  ( Tenant
  , Subject
  , Membership
  , Owner
  , Grant
  , RequestScope
  , Scoped
  , ScopedHandle
  , SomeScopedHandle
  , HandleKind (..)
  , ResourceId
  , ScopeError (..)
  , trustedTenant
  , trustedSubject
  , activeMembership
  , Trust (..)
  , Identity
  , SignedIdentityEnvelope (..)
  , VerificationKey
  , verificationKey
  , claimedIdentity
  , verifyIdentity
  , identityTenantText
  , identitySubjectText
  , Attestation
  , principalAttestation
  , bindingAttestation
  , attest
  , Persisted
  , persist
  , persistedKey
  , reenter
  , scopeIssuer
  , scopeApplication
  , scopeNeed
  , scopeLabel
  , ScopeStamp
  , scopeStamp
  , stampIssuer
  , stampApplication
  , stampNeed
  , stampLabel
  , subjectOwner
  , tenantOwner
  , grantOwner
  , activeGrant
  , revokedGrant
  , absentGrant
  , trustedResourceId
  , scoped
  , mapScoped
  , pairScoped
  , scopedValue
  , resolveOwned
  , handleKind
  , tenantText
  , subjectText
  , subjectTenant
  , scopeTenant
  , scopeSubject
  ) where

import Amoebius.Extension.AstCheck (CheckedExtensionSource)
import Amoebius.Extension.Graph (BindingProof, bindingIssuer, bindingApplication, bindingNeed)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Builder qualified as Builder
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Char (isAlphaNum)
import Data.Text.Encoding qualified as Encoding
import Numeric (showHex)
import Data.Text (Text)
import qualified Data.Text as Text

newtype Tenant = Tenant Text
  deriving stock (Eq, Ord, Show)

data Subject = Subject Tenant Text
  deriving stock (Eq, Ord, Show)

data Membership = Membership Tenant Subject
  deriving stock (Eq, Ord, Show)

data Grant = GrantIsActive | GrantIsRevoked | GrantIsAbsent
  deriving stock (Eq, Ord, Show)

data Owner
  = OwnedBySubject Tenant Subject
  | OwnedByTenant Tenant
  | OwnedByGrant Tenant Subject Grant
  deriving stock (Eq, Ord, Show)

-- The constructor is private. The only eliminator introduces a fresh, locally
-- quantified scope variable, so a value indexed by one request cannot be retagged as
-- another request's value or escape the continuation that minted it.
type role RequestScope nominal
data RequestScope scope = RequestScope !Tenant !Subject !Membership !Text !Text !Text !Text

type role Scoped nominal representational
data Scoped scope value = Scoped value

data SubjectHandle
data TenantHandle

type role ScopedHandle nominal nominal
data ScopedHandle scope kind = ScopedHandle ResourceId

type role SomeScopedHandle nominal
data SomeScopedHandle scope where
  SomeSubjectHandle :: ScopedHandle scope SubjectHandle -> SomeScopedHandle scope
  SomeTenantHandle :: ScopedHandle scope TenantHandle -> SomeScopedHandle scope

data HandleKind = SubjectHandleKind | TenantHandleKind
  deriving stock (Eq, Ord, Show)

newtype ResourceId = ResourceId Text
  deriving stock (Eq, Ord, Show)

data ScopeError
  = InvalidTenant Text
  | InvalidSubject Text
  | InvalidResourceId Text
  | MembershipMismatch
  | TenantMismatch
  | OwnerMismatch
  | GrantAbsent
  | GrantRevoked
  | ReentryTenantMismatch
  | ReentryScopeMismatch
  deriving stock (Eq, Ord, Show)

trustedTenant :: Text -> Either ScopeError Tenant
trustedTenant value
  | validIdentifier value = Right (Tenant value)
  | otherwise = Left (InvalidTenant value)

trustedSubject :: Tenant -> Text -> Either ScopeError Subject
trustedSubject tenant value
  | validIdentifier value = Right (Subject tenant value)
  | otherwise = Left (InvalidSubject value)

activeMembership :: Tenant -> Subject -> Either ScopeError Membership
activeMembership tenant subject
  | tenant == subjectTenant subject = Right (Membership tenant subject)
  | otherwise = Left MembershipMismatch

-- | Only this function introduces the fresh scope index. Syntactic tenant,
-- subject and membership values alone carry no authority to call it.
data Attestation
  = PrincipalAttestation (Identity 'Attested)
  | BindingAttestation (BindingProof CheckedExtensionSource)

principalAttestation :: Identity 'Attested -> Attestation
principalAttestation = PrincipalAttestation

bindingAttestation :: BindingProof CheckedExtensionSource -> Attestation
bindingAttestation = BindingAttestation

attest
  :: Attestation
  -> (forall scope. RequestScope scope -> result)
  -> Either ScopeError result
attest evidence continuation = do
  (tenant, subject, issuer, application, need) <- case evidence of
    PrincipalAttestation (Identity tenant subject) -> Right
      (tenant, subject, "principal/" <> tenantText tenant, subjectText subject, "request")
    BindingAttestation proof -> do
      tenant <- trustedTenant (bindingApplication proof)
      subject <- trustedSubject tenant (bindingNeed proof)
      Right (tenant, subject, bindingIssuer proof, bindingApplication proof, bindingNeed proof)
  membership <- activeMembership tenant subject
  let label = "s-" <> Text.take 60 (hexDigest (frame (map Encoding.encodeUtf8
        ["scope/v1", issuer, application, need])))
  Right (continuation (RequestScope tenant subject membership issuer application need label))

-- A persisted value retains its entire authority identity. Re-entry consumes an
-- already attested scope and never introduces or changes a scope index.
data Persisted value = Persisted !Tenant !Subject !Text !Text !Text !Text !Text value

persist :: RequestScope scope -> Text -> Scoped scope value -> Persisted value
persist request resource (Scoped value) = Persisted (scopeTenant request) (scopeSubject request)
  (scopeIssuer request) (scopeApplication request) (scopeNeed request) (scopeLabel request) resource value

persistedKey :: Persisted value -> Text
persistedKey (Persisted tenant subject issuer application need label resource _) =
  hexDigest (frame (map Encoding.encodeUtf8
    ["persisted-scope/v1", tenantText tenant, subjectText subject, issuer, application, need, label, resource]))

reenter :: RequestScope scope -> Persisted value -> Either ScopeError (Scoped scope value)
reenter request (Persisted tenant subject issuer application need label _ value)
  | scopeTenant request /= tenant = Left ReentryTenantMismatch
  | scopeSubject request /= subject || scopeIssuer request /= issuer
      || scopeApplication request /= application || scopeNeed request /= need
      || scopeLabel request /= label = Left ReentryScopeMismatch
  | otherwise = Right (Scoped value)

scopeIssuer :: RequestScope scope -> Text
scopeIssuer (RequestScope _ _ _ value _ _ _) = value

scopeApplication :: RequestScope scope -> Text
scopeApplication (RequestScope _ _ _ _ value _ _) = value

scopeNeed :: RequestScope scope -> Text
scopeNeed (RequestScope _ _ _ _ _ value _) = value

scopeLabel :: RequestScope scope -> Text
scopeLabel (RequestScope _ _ _ _ _ _ value) = value

-- A renderer retains this opaque projection, not a means to introduce or
-- retag a request scope. Full identity accompanies the bounded wire label.
data ScopeStamp = ScopeStamp !Text !Text !Text !Text
  deriving (Eq, Ord, Show)

scopeStamp :: RequestScope scope -> ScopeStamp
scopeStamp request = ScopeStamp (scopeIssuer request) (scopeApplication request) (scopeNeed request) (scopeLabel request)

stampIssuer :: ScopeStamp -> Text
stampIssuer (ScopeStamp value _ _ _) = value

stampApplication :: ScopeStamp -> Text
stampApplication (ScopeStamp _ value _ _) = value

stampNeed :: ScopeStamp -> Text
stampNeed (ScopeStamp _ _ value _) = value

stampLabel :: ScopeStamp -> Text
stampLabel (ScopeStamp _ _ _ value) = value

subjectOwner :: Tenant -> Subject -> Owner
subjectOwner = OwnedBySubject

tenantOwner :: Tenant -> Owner
tenantOwner = OwnedByTenant

grantOwner :: Tenant -> Subject -> Grant -> Owner
grantOwner = OwnedByGrant

activeGrant :: Grant
activeGrant = GrantIsActive

revokedGrant :: Grant
revokedGrant = GrantIsRevoked

absentGrant :: Grant
absentGrant = GrantIsAbsent

trustedResourceId :: Text -> Either ScopeError ResourceId
trustedResourceId value
  | validIdentifier value = Right (ResourceId value)
  | otherwise = Left (InvalidResourceId value)

scoped :: RequestScope scope -> value -> Scoped scope value
scoped request value = request `seq` Scoped value

mapScoped :: (left -> right) -> Scoped scope left -> Scoped scope right
mapScoped transform (Scoped value) = Scoped (transform value)

pairScoped :: Scoped scope left -> Scoped scope right -> Scoped scope (left, right)
pairScoped (Scoped left) (Scoped right) = Scoped (left, right)

scopedValue :: Scoped scope value -> value
scopedValue (Scoped value) = value

resolveOwned
  :: RequestScope scope
  -> Owner
  -> ResourceId
  -> Either ScopeError (SomeScopedHandle scope)
resolveOwned (RequestScope requestTenant requestSubject _ _ _ _ _) owner resource = case owner of
  OwnedBySubject ownerTenant ownerSubject
    | requestTenant /= ownerTenant -> Left TenantMismatch
    | requestSubject /= ownerSubject -> Left OwnerMismatch
    | otherwise -> Right (SomeSubjectHandle (ScopedHandle resource))
  OwnedByTenant ownerTenant
    | requestTenant /= ownerTenant -> Left TenantMismatch
    | otherwise -> Right (SomeTenantHandle (ScopedHandle resource))
  OwnedByGrant ownerTenant ownerSubject grant
    | requestTenant /= ownerTenant -> Left TenantMismatch
    | requestSubject == ownerSubject -> Left OwnerMismatch
    | grant == GrantIsAbsent -> Left GrantAbsent
    | grant == GrantIsRevoked -> Left GrantRevoked
    | otherwise -> Right (SomeSubjectHandle (ScopedHandle resource))

handleKind :: SomeScopedHandle scope -> HandleKind
handleKind handle = case handle of
  SomeSubjectHandle _ -> SubjectHandleKind
  SomeTenantHandle _ -> TenantHandleKind

tenantText :: Tenant -> Text
tenantText (Tenant value) = value

subjectText :: Subject -> Text
subjectText (Subject _ value) = value

subjectTenant :: Subject -> Tenant
subjectTenant (Subject tenant _) = tenant

scopeTenant :: RequestScope scope -> Tenant
scopeTenant (RequestScope tenant _ _ _ _ _ _) = tenant

scopeSubject :: RequestScope scope -> Subject
scopeSubject (RequestScope _ subject _ _ _ _ _) = subject

validIdentifier :: Text -> Bool
validIdentifier value =
  not (Text.null value)
    && Text.length value <= 128
    && Text.all (\character -> isAlphaNum character || character `elem` ("-_." :: String)) value

data Trust = Claimed | Attested

type role Identity nominal
data Identity (trust :: Trust) = Identity Tenant Subject
  deriving (Eq, Ord, Show)

data SignedIdentityEnvelope = SignedIdentityEnvelope
  { envelopeTenant :: Text
  , envelopeSubject :: Text
  , envelopeSignature :: Text
  }
  deriving stock (Eq, Ord, Show)

newtype VerificationKey = VerificationKey ByteString

verificationKey :: Text -> Maybe VerificationKey
verificationKey value
  | Text.null value = Nothing
  | otherwise = Just (VerificationKey (Encoding.encodeUtf8 value))

claimedIdentity :: Text -> Text -> Either ScopeError (Identity 'Claimed)
claimedIdentity tenantValue subjectValue = do
  tenant <- trustedTenant tenantValue
  subject <- trustedSubject tenant subjectValue
  pure (Identity tenant subject)

verifyIdentity
  :: VerificationKey
  -> SignedIdentityEnvelope
  -> Either Text (Identity 'Attested)
verifyIdentity key envelope
  | envelopeSignature envelope /= expectedSignature key envelope = Left "attestation-refused"
  | otherwise = do
      tenant <- firstText (trustedTenant (envelopeTenant envelope))
      subject <- firstText (trustedSubject tenant (envelopeSubject envelope))
      pure (Identity tenant subject)

identityTenantText :: Identity trust -> Text
identityTenantText (Identity tenant _) = tenantText tenant

identitySubjectText :: Identity trust -> Text
identitySubjectText (Identity _ subject) = subjectText subject


expectedSignature :: VerificationKey -> SignedIdentityEnvelope -> Text
expectedSignature (VerificationKey key) envelope =
  hexDigest (frame [key, Encoding.encodeUtf8 (envelopeTenant envelope), Encoding.encodeUtf8 (envelopeSubject envelope)])

firstText :: Show error => Either error value -> Either Text value
firstText value = case value of
  Left problem -> Left (Text.pack (show problem))
  Right result -> Right result

frame :: [ByteString] -> ByteString
frame = LazyByteString.toStrict . Builder.toLazyByteString . foldMap framed
 where
  framed bytes = Builder.word64BE (fromIntegral (ByteString.length bytes)) <> Builder.byteString bytes

hexDigest :: ByteString -> Text
hexDigest bytes = Text.pack (concatMap hexByte (ByteString.unpack (SHA256.hash bytes)))

hexByte :: (Integral byte, Show byte) => byte -> String
hexByte byte = case showHex byte "" of
  [single] -> ['0', single]
  digits -> digits
