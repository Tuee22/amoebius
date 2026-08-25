{-# LANGUAGE DataKinds #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

-- | A pure, bounded kernel for the six extension security laws.
--
-- Cryptographic verification and wall-clock timing are represented only by explicit
-- observations.  The module does enforce the type distinctions, skolem request scope,
-- mandatory scoped operation shape, one public refusal, injective length framing, and
-- mandatory revocation-or-bound policy that Phase 24 can decide at Register 1.
module Amoebius.Extension.Laws.Security
  ( Trust (..)
  , Identity
  , SignedIdentityEnvelope (..)
  , VerificationKey
  , verificationKey
  , claimedIdentity
  , verifyIdentity
  , identityTenantText
  , identitySubjectText
  , withAttestedScope
  , SecurityOperation (..)
  , PublicRefusal (..)
  , renderPublicRefusal
  , SecurityStore
  , emptySecurityStore
  , insertResource
  , storeRows
  , OperationTrace (..)
  , runScopedOperation
  , Keyspace (..)
  , everyKeyspace
  , ScopedKey
  , renderScopedKey
  , scopedKeyText
  , useScopedKey
  , parseRenderedKey
  , StalenessBound
  , stalenessBound
  , AuthorityLayer
  , revocationLayer
  , boundedLayer
  , AuthorityPolicyView (..)
  , authorityLayerName
  , authorityPolicyView
  , SecurityLaw (..)
  , everySecurityLaw
  , securityLawTag
  , RefusalProbe (..)
  , NamespaceProbe (..)
  , RevocationProbe (..)
  , SecurityObservations (..)
  , SecurityFailure (..)
  , SecurityVerdict (..)
  , evaluateSecurityLaws
  , securityLawPassed
  ) where

import Amoebius.Scope.Index
  ( RequestScope
  , ScopeError
  , Tenant
  , Subject
  , activeMembership
  , scopeSubject
  , scopeTenant
  , subjectText
  , tenantText
  , trustedSubject
  , trustedTenant
  , withRequestScope
  )
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Builder qualified as Builder
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Char (isDigit)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import Numeric (showHex)
import Numeric.Natural (Natural)

data Trust = Claimed | Attested

data Identity (trust :: Trust) = Identity Tenant Subject

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

withAttestedScope
  :: Identity 'Attested
  -> (forall scope. RequestScope scope -> result)
  -> Either ScopeError result
withAttestedScope (Identity tenant subject) continuation = do
  membership <- activeMembership tenant subject
  withRequestScope tenant subject membership continuation

expectedSignature :: VerificationKey -> SignedIdentityEnvelope -> Text
expectedSignature (VerificationKey key) envelope =
  hexDigest (frame [key, Encoding.encodeUtf8 (envelopeTenant envelope), Encoding.encodeUtf8 (envelopeSubject envelope)])

data SecurityOperation = Read | Update | Delete | Replay | CacheLookup
  deriving stock (Eq, Ord, Show, Enum, Bounded)

data PublicRefusal = ResourceUnavailable
  deriving stock (Eq, Ord, Show)

renderPublicRefusal :: PublicRefusal -> ByteString
renderPublicRefusal ResourceUnavailable = "resource-unavailable"

newtype SecurityStore = SecurityStore (Map (Text, Text, Text) Text)
  deriving stock (Eq, Show)

emptySecurityStore :: SecurityStore
emptySecurityStore = SecurityStore Map.empty

insertResource :: Text -> Text -> Text -> Text -> SecurityStore -> SecurityStore
insertResource tenant subject resource value (SecurityStore rows) =
  SecurityStore (Map.insert (tenant, subject, resource) value rows)

storeRows :: SecurityStore -> [((Text, Text, Text), Text)]
storeRows (SecurityStore rows) = Map.toAscList rows

data OperationTrace = OperationTrace
  { operationResult :: Either PublicRefusal Text
  , operationSteps :: Natural
  , operationStore :: SecurityStore
  }
  deriving stock (Eq, Show)

runScopedOperation
  :: RequestScope scope
  -> SecurityOperation
  -> Text
  -> SecurityStore
  -> OperationTrace
runScopedOperation scope operation resource original@(SecurityStore rows) =
  case Map.lookup key rows of
    Nothing -> OperationTrace (Left ResourceUnavailable) 3 original
    Just value -> case operation of
      Read -> allowed value original
      Update -> allowed "updated" (SecurityStore (Map.insert key "updated" rows))
      Delete -> allowed "deleted" (SecurityStore (Map.delete key rows))
      Replay -> allowed ("replayed:" <> value) original
      CacheLookup -> allowed ("cached:" <> value) original
 where
  key = (tenantText (scopeTenant scope), subjectText (scopeSubject scope), resource)
  allowed value next = OperationTrace (Right value) 3 next

data Keyspace = RowKey | ObjectPrefix | TopicName | CacheKey | ReplayKey
  deriving stock (Eq, Ord, Show, Enum, Bounded)

everyKeyspace :: [Keyspace]
everyKeyspace = [minBound .. maxBound]

newtype ScopedKey scope = ScopedKey Text

renderScopedKey :: RequestScope scope -> Keyspace -> Text -> ScopedKey scope
renderScopedKey scope keyspace domain = ScopedKey (renderFields fields)
 where
  fields =
    [ tenantText (scopeTenant scope)
    , subjectText (scopeSubject scope)
    , keyspaceTag keyspace
    , domain
    ]

scopedKeyText :: ScopedKey scope -> Text
scopedKeyText (ScopedKey value) = value

useScopedKey :: RequestScope scope -> ScopedKey scope -> Text
useScopedKey _scope = scopedKeyText

parseRenderedKey :: Text -> Maybe (Text, Text, Text, Text)
parseRenderedKey rendered = do
  (tenant, afterTenant) <- takeField rendered
  (subject, afterSubject) <- takeField afterTenant
  (keyspace, afterKeyspace) <- takeField afterSubject
  (domain, remainder) <- takeField afterKeyspace
  if Text.null remainder then Just (tenant, subject, keyspace, domain) else Nothing

renderFields :: [Text] -> Text
renderFields = foldMap (\field -> Text.pack (show (Text.length field)) <> ":" <> field)

takeField :: Text -> Maybe (Text, Text)
takeField value = do
  let (lengthText, colonAndRest) = Text.breakOn ":" value
  if Text.null lengthText || Text.any (not . isDigit) lengthText || Text.null colonAndRest
    then Nothing
    else do
      wanted <- readNatural lengthText
      let (field, remainder) = Text.splitAt (fromIntegral wanted) (Text.drop 1 colonAndRest)
      if Text.length field == fromIntegral wanted then Just (field, remainder) else Nothing

readNatural :: Text -> Maybe Natural
readNatural value = case reads (Text.unpack value) of
  [(number, "")] -> Just number
  _results -> Nothing

keyspaceTag :: Keyspace -> Text
keyspaceTag keyspace = case keyspace of
  RowKey -> "row"
  ObjectPrefix -> "object"
  TopicName -> "topic"
  CacheKey -> "cache"
  ReplayKey -> "replay"

newtype StalenessBound = StalenessBound Natural
  deriving stock (Eq, Ord, Show)

stalenessBound :: Natural -> Maybe StalenessBound
stalenessBound value
  | value == 0 = Nothing
  | otherwise = Just (StalenessBound value)

data AuthorityLayer
  = RevocationLayer Text Text
  | BoundedLayer Text StalenessBound

revocationLayer :: Text -> Text -> Maybe AuthorityLayer
revocationLayer name edge
  | Text.null name || Text.null edge = Nothing
  | otherwise = Just (RevocationLayer name edge)

boundedLayer :: Text -> StalenessBound -> Maybe AuthorityLayer
boundedLayer name bound
  | Text.null name = Nothing
  | otherwise = Just (BoundedLayer name bound)

data AuthorityPolicyView
  = HasRevocationEdge Text
  | HasStalenessBound Natural
  deriving stock (Eq, Ord, Show)

authorityLayerName :: AuthorityLayer -> Text
authorityLayerName layer = case layer of
  RevocationLayer name _ -> name
  BoundedLayer name _ -> name

authorityPolicyView :: AuthorityLayer -> AuthorityPolicyView
authorityPolicyView layer = case layer of
  RevocationLayer _ edge -> HasRevocationEdge edge
  BoundedLayer _ (StalenessBound bound) -> HasStalenessBound bound

data SecurityLaw = S1 | S2 | S3 | S4 | S5 | S6
  deriving stock (Eq, Ord, Show, Enum, Bounded)

everySecurityLaw :: [SecurityLaw]
everySecurityLaw = [minBound .. maxBound]

securityLawTag :: SecurityLaw -> Text
securityLawTag law = case law of
  S1 -> "S1"
  S2 -> "S2"
  S3 -> "S3"
  S4 -> "S4"
  S5 -> "S5"
  S6 -> "S6"

data RefusalProbe = RefusalProbe
  { refusalOperation :: SecurityOperation
  , foreignRefusalBytes :: ByteString
  , absentRefusalBytes :: ByteString
  , foreignMutationCount :: Natural
  , absentMutationCount :: Natural
  , foreignSteps :: Natural
  , absentSteps :: Natural
  , declaredTimingBound :: Natural
  }
  deriving stock (Eq, Show)

data NamespaceProbe = NamespaceProbe
  { namespaceKeyspace :: Keyspace
  , namespaceLeft :: Text
  , namespaceRight :: Text
  , namespaceLeftParsed :: Bool
  , namespaceRightParsed :: Bool
  }
  deriving stock (Eq, Show)

data RevocationProbe = RevocationProbe
  { revocationLayerName :: Text
  , revocationPolicy :: Maybe AuthorityPolicyView
  , revocationEdgeObserved :: Bool
  , reconnectionBoundEnforced :: Bool
  }
  deriving stock (Eq, Show)

data SecurityObservations = SecurityObservations
  { verifiedIdentityAccepted :: Bool
  , tamperedIdentityRefused :: Bool
  , claimedIdentityRejected :: Bool
  , skolemCompilerBarriersPassed :: Bool
  , exportedUnscopedOperationArms :: Natural
  , scopedOperationKindsObserved :: [SecurityOperation]
  , refusalProbes :: [RefusalProbe]
  , namespaceProbes :: [NamespaceProbe]
  , revocationProbes :: [RevocationProbe]
  }
  deriving stock (Eq, Show)

data SecurityFailure
  = VerifiedIdentityWasRefused
  | TamperedIdentityWasAccepted
  | ClaimedIdentityReachedAttestedOperation
  | SkolemBarrierMissing
  | UnscopedOperationArmExported Natural
  | ScopedOperationCoverageMismatch
  | RefusalBytesDiffer SecurityOperation
  | RefusalMutatedState SecurityOperation
  | RefusalTimingExceeded SecurityOperation
  | NamespaceCollision Keyspace
  | NamespaceDidNotParse Keyspace
  | RevocationPolicyMissing Text
  | RevocationEdgeDidNotFire Text
  | ReconnectionBoundNotEnforced Text
  deriving stock (Eq, Ord, Show)

data SecurityVerdict = SecurityLawPassed | SecurityLawFailed [SecurityFailure]
  deriving stock (Eq, Ord, Show)

evaluateSecurityLaws :: SecurityObservations -> [(SecurityLaw, SecurityVerdict)]
evaluateSecurityLaws observations =
  [ (S1, verdict (s1Failures observations))
  , (S2, verdict [SkolemBarrierMissing | not (skolemCompilerBarriersPassed observations)])
  , (S3, verdict (s3Failures observations))
  , (S4, verdict (s4Failures observations))
  , (S5, verdict (s5Failures observations))
  , (S6, verdict (s6Failures observations))
  ]

securityLawPassed :: SecurityVerdict -> Bool
securityLawPassed lawVerdict = case lawVerdict of
  SecurityLawPassed -> True
  SecurityLawFailed _ -> False

verdict :: [SecurityFailure] -> SecurityVerdict
verdict failures = case failures of
  [] -> SecurityLawPassed
  _ -> SecurityLawFailed failures

s1Failures :: SecurityObservations -> [SecurityFailure]
s1Failures observations =
  [VerifiedIdentityWasRefused | not (verifiedIdentityAccepted observations)]
    <> [TamperedIdentityWasAccepted | not (tamperedIdentityRefused observations)]
    <> [ClaimedIdentityReachedAttestedOperation | not (claimedIdentityRejected observations)]

s3Failures :: SecurityObservations -> [SecurityFailure]
s3Failures observations =
  [UnscopedOperationArmExported (exportedUnscopedOperationArms observations) | exportedUnscopedOperationArms observations /= 0]
    <> [ ScopedOperationCoverageMismatch
       | scopedOperationKindsObserved observations /= [minBound .. maxBound]
       ]

s4Failures :: SecurityObservations -> [SecurityFailure]
s4Failures observations = concatMap check (refusalProbes observations)
 where
  check probe =
    [RefusalBytesDiffer (refusalOperation probe) | foreignRefusalBytes probe /= absentRefusalBytes probe]
      <> [ RefusalMutatedState (refusalOperation probe)
         | foreignMutationCount probe /= 0 || absentMutationCount probe /= 0
         ]
      <> [ RefusalTimingExceeded (refusalOperation probe)
         | distance (foreignSteps probe) (absentSteps probe) > declaredTimingBound probe
         ]
  distance left right = if left >= right then left - right else right - left

s5Failures :: SecurityObservations -> [SecurityFailure]
s5Failures observations = concatMap check (namespaceProbes observations)
 where
  check probe =
    [NamespaceCollision (namespaceKeyspace probe) | namespaceLeft probe == namespaceRight probe]
      <> [ NamespaceDidNotParse (namespaceKeyspace probe)
         | not (namespaceLeftParsed probe && namespaceRightParsed probe)
         ]

s6Failures :: SecurityObservations -> [SecurityFailure]
s6Failures observations = concatMap check (revocationProbes observations)
 where
  check probe = case revocationPolicy probe of
    Nothing -> [RevocationPolicyMissing (revocationLayerName probe)]
    Just (HasRevocationEdge _) ->
      [RevocationEdgeDidNotFire (revocationLayerName probe) | not (revocationEdgeObserved probe)]
    Just (HasStalenessBound _) ->
      [ReconnectionBoundNotEnforced (revocationLayerName probe) | not (reconnectionBoundEnforced probe)]

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
