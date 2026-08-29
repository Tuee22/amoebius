{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PackageImports #-}

module Amoebius.Validation.SourceAcquisition.Internal
  ( AnchoredSourceAcquisitionSession
  , acquireExternallyVerifiedSourceSnapshot
  , acquireExternallyVerifiedSourceSnapshotFromIngress
  , acquireExternallyVerifiedSourceSnapshotFromReservedIngress
  , anchorSourceAcquisitionSession
#if defined(VALIDATION_SOURCE_ACQUISITION_INTERNAL_TEST_HOOKS)
  , sourceAcquisitionInternalTestFinalize
  , sourceAcquisitionInternalTestTrackedEntries
#endif
  , sourceAcquisitionDiagnostic
  ) where

-- The public facade remains diagnostic-only. This package-hidden module also
-- owns the sole ordinary-build conversion from an externally anchored signed
-- immutable bundle to AcquiredSourceSnapshot. A caller-supplied public key and
-- replay set can still exercise only the public diagnostic: authority requires
-- the separately qualified external supervisor and its opaque anchored session.

import Amoebius.Validation.SourceClosure.Internal
  ( GitObjectFormat (..)
  , IndexEntry (..)
  , IndexMode (..)
  , SnapshotProblem
  , TrackedEntry (..)
  , computeSourceSnapshotIdentity
  , verifyBlobObjectId
  )
import Amoebius.Validation.SourceSnapshot.Internal
  ( AcquiredSourceSnapshot (AcquiredSourceSnapshot)
  , SourceSnapshot (..)
  )
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding (..)
  , Observation (..)
  , finding
  , observation
  )
import Control.Monad (foldM)
import "crypton" Crypto.Error (CryptoFailable (..))
import "crypton" Crypto.Hash qualified as Crypto
import "crypton" Crypto.PubKey.Ed25519 qualified as Ed25519
import Data.Bits ((.|.), shiftL)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Builder
  ( Builder
  , byteString
  , toLazyByteString
  , word8
  , word32BE
  , word64BE
  )
import Data.ByteString.Char8 qualified as ByteString8
import Data.ByteString.Lazy qualified as LazyByteString
import Data.List (sortBy)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Word (Word32, Word64, Word8)

data SourceAcquisitionCustody
  = ExternallyFrozenReadOnlyBundle
  | SequentialMutableBundle
  deriving (Eq, Ord, Show)

data SourceAcquisitionEntry = SourceAcquisitionEntry
  { acquisitionEntryPath :: FilePath
  , acquisitionEntryMode :: IndexMode
  , acquisitionEntryGitObjectId :: Text
  , acquisitionEntryByteLength :: Word64
  , acquisitionEntryBlobSha256 :: Text
  }
  deriving (Eq, Ord, Show)

-- These values are diagnostic expectations supplied by a component oracle.
-- The future candidate seam must obtain their equivalents from an externally
-- anchored session rather than accepting this record from a caller.
data SourceAcquisitionExpectation = SourceAcquisitionExpectation
  { expectedAcquisitionPhase :: Text
  , expectedAcquisitionAuthority :: Text
  , expectedAcquisitionObserverToolDigest :: Text
  , expectedAcquisitionChallenge :: Text
  , consumedAcquisitionReplayIdentities :: Set Text
  , expectedAcquisitionRepositoryIdentity :: Text
  , expectedAcquisitionRequestedRevision :: Text
  , expectedAcquisitionHeadIdentity :: Text
  , expectedAcquisitionSourceSnapshotIdentity :: Text
  , expectedAcquisitionAuthoredRootIdentity :: Text
  }
  deriving (Eq, Show)

-- | Inputs established by the external acquisition supervisor before the
-- signed immutable bundle reaches the validation kernel. The supervisor must
-- obtain these values from its pre-anchored trust policy, issue the fresh
-- challenge, and reserve the replay identity durably and atomically. Merely
-- possessing caller-selected bytes is not sufficient to construct this value
-- in the public API; this constructor is package-hidden so its production call
-- graph can be kept closed and qualified with the supervisor.
data AnchoredSourceAcquisitionSession = AnchoredSourceAcquisitionSession
  { anchoredSourceAcquisitionExpectation :: SourceAcquisitionExpectation
  , anchoredSourceAcquisitionExpectedManifestBytes :: ByteString
  , anchoredSourceAcquisitionPublicKeyBytes :: ByteString
  }
  deriving (Eq, Show)

-- | Package-hidden adapter used only by the external acquisition supervisor
-- (and its direct-source oracle). The adapter does not establish authority by
-- itself; qualification must prove that its production caller obtains every
-- value from the pre-anchored session and durable replay boundary rather than
-- from validation argv, environment text, or mutable repository state.
anchorSourceAcquisitionSession
  :: Text
  -> Text
  -> Text
  -> Text
  -> Set Text
  -> Text
  -> Text
  -> Text
  -> Text
  -> Text
  -> ByteString
  -> ByteString
  -> AnchoredSourceAcquisitionSession
anchorSourceAcquisitionSession
  expectedPhase
  expectedAuthority
  expectedObserverToolDigest
  expectedChallenge
  consumedReplayIdentities
  expectedRepositoryIdentity
  expectedRequestedRevision
  expectedHeadIdentity
  expectedSourceSnapshotIdentity
  expectedAuthoredRootIdentity
  expectedManifestBytes
  publicKeyBytes =
    AnchoredSourceAcquisitionSession
      { anchoredSourceAcquisitionExpectation =
          SourceAcquisitionExpectation
            { expectedAcquisitionPhase = anchoredSessionText AnchoredPhase expectedPhase
            , expectedAcquisitionAuthority = anchoredSessionText AnchoredAuthority expectedAuthority
            , expectedAcquisitionObserverToolDigest = anchoredSessionText AnchoredObserverTool expectedObserverToolDigest
            , expectedAcquisitionChallenge = anchoredSessionText AnchoredChallenge expectedChallenge
            , consumedAcquisitionReplayIdentities = anchoredSessionReplaySet consumedReplayIdentities
            , expectedAcquisitionRepositoryIdentity = anchoredSessionText AnchoredRepository expectedRepositoryIdentity
            , expectedAcquisitionRequestedRevision = anchoredSessionText AnchoredRequestedRevision expectedRequestedRevision
            , expectedAcquisitionHeadIdentity = anchoredSessionText AnchoredHead expectedHeadIdentity
            , expectedAcquisitionSourceSnapshotIdentity = anchoredSessionText AnchoredSourceSnapshot expectedSourceSnapshotIdentity
            , expectedAcquisitionAuthoredRootIdentity = anchoredSessionText AnchoredAuthoredRoot expectedAuthoredRootIdentity
            }
      , anchoredSourceAcquisitionExpectedManifestBytes = anchoredSessionBytes AnchoredExpectedManifest expectedManifestBytes
      , anchoredSourceAcquisitionPublicKeyBytes = anchoredSessionBytes AnchoredPublicKey publicKeyBytes
      }

data AnchoredSessionTextSlot
  = AnchoredPhase
  | AnchoredAuthority
  | AnchoredObserverTool
  | AnchoredChallenge
  | AnchoredRepository
  | AnchoredRequestedRevision
  | AnchoredHead
  | AnchoredSourceSnapshot
  | AnchoredAuthoredRoot
  deriving (Eq, Ord, Show)

anchoredSessionText :: AnchoredSessionTextSlot -> Text -> Text
#if defined(VALIDATION_SOURCE_ACQUISITION_ANCHORED_PHASE_MAPPING_MUTANT)
anchoredSessionText slot value
  | slot == AnchoredPhase = value <> "mutated"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_ANCHORED_AUTHORITY_MAPPING_MUTANT)
anchoredSessionText slot value
  | slot == AnchoredAuthority = value <> "-mutated"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_ANCHORED_OBSERVER_TOOL_MAPPING_MUTANT)
anchoredSessionText slot value
  | slot == AnchoredObserverTool = value <> "0"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_ANCHORED_CHALLENGE_MAPPING_MUTANT)
anchoredSessionText slot value
  | slot == AnchoredChallenge = value <> "0"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_ANCHORED_REPOSITORY_MAPPING_MUTANT)
anchoredSessionText slot value
  | slot == AnchoredRepository = value <> "0"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_ANCHORED_REQUESTED_REVISION_MAPPING_MUTANT)
anchoredSessionText slot value
  | slot == AnchoredRequestedRevision = value <> ".lock"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_ANCHORED_HEAD_MAPPING_MUTANT)
anchoredSessionText slot value
  | slot == AnchoredHead = value <> "0"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_ANCHORED_SOURCE_SNAPSHOT_MAPPING_MUTANT)
anchoredSessionText slot value
  | slot == AnchoredSourceSnapshot = value <> "0"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_ANCHORED_AUTHORED_ROOT_MAPPING_MUTANT)
anchoredSessionText slot value
  | slot == AnchoredAuthoredRoot = value <> "0"
  | otherwise = value
#else
anchoredSessionText slot value = slot `seq` value
#endif

anchoredSessionReplaySet :: Set Text -> Set Text
#if defined(VALIDATION_SOURCE_ACQUISITION_ANCHORED_REPLAY_SET_MAPPING_MUTANT)
anchoredSessionReplaySet values = values `seq` Set.empty
#else
anchoredSessionReplaySet = id
#endif

data AnchoredSessionByteSlot
  = AnchoredExpectedManifest
  | AnchoredPublicKey
  deriving (Eq, Ord, Show)

anchoredSessionBytes :: AnchoredSessionByteSlot -> ByteString -> ByteString
#if defined(VALIDATION_SOURCE_ACQUISITION_ANCHORED_EXPECTED_MANIFEST_MAPPING_MUTANT)
anchoredSessionBytes slot value
  | slot == AnchoredExpectedManifest = ByteString.drop 1 value
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_ANCHORED_PUBLIC_KEY_MAPPING_MUTANT)
anchoredSessionBytes slot value
  | slot == AnchoredPublicKey = value <> "mutated"
  | otherwise = value
#else
anchoredSessionBytes slot value = slot `seq` value
#endif

data SourceAcquisitionManifest = SourceAcquisitionManifest
  { acquisitionPhase :: Text
  , acquisitionAuthority :: Text
  , acquisitionObserverToolDigest :: Text
  , acquisitionChallenge :: Text
  , acquisitionReplayIdentity :: Text
  , acquisitionRepositoryIdentity :: Text
  , acquisitionRequestedRevision :: Text
  , acquisitionCustody :: SourceAcquisitionCustody
  , acquisitionObjectFormat :: GitObjectFormat
  , acquisitionHeadIdentity :: Text
  , acquisitionTreeIdentity :: Text
  , acquisitionAuthoredRootIdentity :: Text
  , acquisitionFrozenSnapshotIdentity :: Text
  , acquisitionBundleIdentity :: Text
  , acquisitionSourceSnapshotIdentity :: Text
  , acquisitionCommitBytes :: ByteString
  , acquisitionEntries :: [SourceAcquisitionEntry]
  }
  deriving (Eq, Show)

data SourceAcquisitionExpectedManifest = SourceAcquisitionExpectedManifest
  { expectedManifestObjectFormat :: GitObjectFormat
  , expectedManifestEntries :: [SourceAcquisitionEntry]
  }
  deriving (Eq, Show)

data SourceAcquisitionProblem
  = SourceAcquisitionWireMalformed Text
  | SourceAcquisitionWireNonCanonical
  | SourceAcquisitionEnvelopeTooLarge Int
  | SourceAcquisitionPayloadTooLarge Word64
  | SourceAcquisitionBundleTooLarge Int
  | SourceAcquisitionFieldTooLarge Text Word32
  | SourceAcquisitionExpectationValueTooLarge Text Int Int
  | SourceAcquisitionReplaySetTooLarge Int Int
  | SourceAcquisitionReplaySetEntryTooLarge Int Int Int
  | SourceAcquisitionProblemLimitExceeded Int Int
  | SourceAcquisitionPhaseMalformed Text
  | SourceAcquisitionPhaseMismatch Text Text
  | SourceAcquisitionAuthorityMalformed Text
  | SourceAcquisitionAuthorityMismatch Text Text
  | SourceAcquisitionObserverToolDigestMalformed Text
  | SourceAcquisitionObserverToolMismatch Text Text
  | SourceAcquisitionChallengeMalformed Text
  | SourceAcquisitionChallengeMismatch Text Text
  | SourceAcquisitionReplayIdentityMalformed Text
  | SourceAcquisitionReplayDetected Text
  | SourceAcquisitionRepositoryIdentityMalformed Text
  | SourceAcquisitionRepositoryIdentityMismatch Text Text
  | SourceAcquisitionRequestedRevisionMalformed Text
  | SourceAcquisitionRequestedRevisionMismatch Text Text
  | SourceAcquisitionCustodyUnsupported Word8
  | SourceAcquisitionObjectFormatUnsupported Word8
  | SourceAcquisitionHeadIdentityMalformed GitObjectFormat Text
  | SourceAcquisitionExpectedHeadIdentityMismatch Text Text
  | SourceAcquisitionTreeIdentityMalformed GitObjectFormat Text
  | SourceAcquisitionTreeIdentityMismatch Text Text
  | SourceAcquisitionCommitTooLarge Word32
  | SourceAcquisitionCommitHeaderCountTooLarge Int Int
  | SourceAcquisitionCommitHeaderLineTooLong Int Int Int
  | SourceAcquisitionCommitMalformed Text
  | SourceAcquisitionCommitIdentityMismatch Text Text
  | SourceAcquisitionCommitTreeMismatch Text Text
  | SourceAcquisitionAuthoredRootIdentityMalformed Text
  | SourceAcquisitionAuthoredRootIdentityMismatch Text Text
  | SourceAcquisitionFrozenSnapshotIdentityMalformed Text
  | SourceAcquisitionFrozenSnapshotIdentityMismatch Text Text
  | SourceAcquisitionBundleIdentityMalformed Text
  | SourceAcquisitionBundleIdentityMismatch Text Text
  | SourceAcquisitionSourceSnapshotIdentityMalformed Text
  | SourceAcquisitionSourceSnapshotIdentityMismatch Text Text
  | SourceAcquisitionExpectedSourceSnapshotIdentityMismatch Text Text
  | SourceAcquisitionExpectedManifestTooLarge Int
  | SourceAcquisitionExpectedManifestEntryCountTooLarge Word32 Word32
  | SourceAcquisitionExpectedManifestMalformed Text
  | SourceAcquisitionExpectedManifestEmpty
  | SourceAcquisitionExpectedManifestNotStrictlyOrdered FilePath FilePath
  | SourceAcquisitionExpectedManifestDuplicatePath FilePath
  | SourceAcquisitionExpectedManifestPathInvalid FilePath
  | SourceAcquisitionExpectedManifestCaseFoldCollision FilePath FilePath
  | SourceAcquisitionExpectedManifestPathConflict FilePath
  | SourceAcquisitionExpectedManifestObjectFormatMismatch GitObjectFormat GitObjectFormat
  | SourceAcquisitionExpectedManifestEntryModeUnsupported FilePath Word8
  | SourceAcquisitionExpectedManifestEntryGitObjectFormatMismatch FilePath GitObjectFormat Text
  | SourceAcquisitionExpectedManifestEntryBlobSha256Malformed FilePath Text
  | SourceAcquisitionExpectedManifestEntryTooLarge FilePath Word64
  | SourceAcquisitionExpectedManifestEntryMissing FilePath
  | SourceAcquisitionExpectedManifestEntryUnexpected FilePath
  | SourceAcquisitionExpectedManifestEntryModeMismatch FilePath IndexMode IndexMode
  | SourceAcquisitionExpectedManifestEntryGitObjectMismatch FilePath Text Text
  | SourceAcquisitionExpectedManifestEntryByteLengthMismatch FilePath Word64 Word64
  | SourceAcquisitionExpectedManifestEntryBlobSha256Mismatch FilePath Text Text
  | SourceAcquisitionManifestEmpty
  | SourceAcquisitionManifestTooLarge Word32
  | SourceAcquisitionManifestNotStrictlyOrdered FilePath FilePath
  | SourceAcquisitionManifestDuplicatePath FilePath
  | SourceAcquisitionManifestPathInvalid FilePath
  | SourceAcquisitionManifestPathTooLong FilePath Int
  | SourceAcquisitionManifestPathTooDeep FilePath Int
  | SourceAcquisitionManifestPathSegmentTooLong FilePath Text Int
  | SourceAcquisitionManifestCaseFoldCollision FilePath FilePath
  | SourceAcquisitionManifestPathConflict FilePath
  | SourceAcquisitionEntryModeUnsupported FilePath Word8
  | SourceAcquisitionEntryGitObjectFormatMismatch FilePath GitObjectFormat Text
  | SourceAcquisitionEntryGitObjectMismatch FilePath SnapshotProblem
  | SourceAcquisitionEntryTooLarge FilePath Word64
  | SourceAcquisitionBundleLengthMismatch Integer Integer
  | SourceAcquisitionEntryBlobSha256Malformed FilePath Text
  | SourceAcquisitionEntryBlobSha256Mismatch FilePath Text Text
  | SourceAcquisitionPublicKeyInvalid
  | SourceAcquisitionSignatureInvalid
  deriving (Eq, Ord, Show)

payloadMagic :: ByteString
payloadMagic = "amoebius-source-acquisition-v2\0"

wireMagic :: ByteString
wireMagic = "amoebius-source-acquisition-envelope-v2\n"

expectedManifestMagic :: ByteString
expectedManifestMagic = "amoebius-source-acquisition-expected-manifest-v1\0"

maximumManifestEntries :: Word32
maximumManifestEntries = 16384

maximumPayloadBytes :: Int
maximumPayloadBytes = 16 * 1024 * 1024

maximumBundleBytes :: Int
maximumBundleBytes = 32 * 1024 * 1024

maximumFieldBytes :: Word32
maximumFieldBytes = 4096

maximumCommitBytes :: Word32
maximumCommitBytes = 1024 * 1024

maximumExpectedManifestBytes :: Int
maximumExpectedManifestBytes = maximumPayloadBytes

maximumExpectedPhaseBytes :: Int
maximumExpectedPhaseBytes = 2

maximumExpectedAuthorityBytes :: Int
maximumExpectedAuthorityBytes = 128

maximumExpectedObserverToolDigestBytes :: Int
maximumExpectedObserverToolDigestBytes = 64

maximumExpectedChallengeBytes :: Int
maximumExpectedChallengeBytes = 64

maximumConsumedReplayIdentities :: Int
maximumConsumedReplayIdentities = 16384

maximumConsumedReplayIdentityBytes :: Int
maximumConsumedReplayIdentityBytes = 64

maximumExpectedRepositoryIdentityBytes :: Int
maximumExpectedRepositoryIdentityBytes = 64

maximumExpectedRequestedRevisionBytes :: Int
maximumExpectedRequestedRevisionBytes = 256

maximumExpectedHeadIdentityBytes :: Int
maximumExpectedHeadIdentityBytes = 64

maximumExpectedSourceSnapshotIdentityBytes :: Int
maximumExpectedSourceSnapshotIdentityBytes = 64

maximumExpectedAuthoredRootIdentityBytes :: Int
maximumExpectedAuthoredRootIdentityBytes = 64

maximumCommitHeaderCount :: Int
maximumCommitHeaderCount = 67

maximumCommitHeaderLineBytes :: Int
maximumCommitHeaderLineBytes = 1024

maximumManifestPathBytes :: Int
maximumManifestPathBytes = 1024

maximumManifestPathDepth :: Int
maximumManifestPathDepth = 64

maximumManifestPathSegmentBytes :: Int
maximumManifestPathSegmentBytes = 255

maximumIntegrityProblems :: Int
#if defined(VALIDATION_SOURCE_ACQUISITION_INTEGRITY_PROBLEM_LIMIT_WIDEN_MUTANT)
maximumIntegrityProblems = 129
#else
maximumIntegrityProblems = 128
#endif

-- Show instances can expand one source character into several output bytes.
-- Taking at most 1,024 lazy Show characters before Text materialization keeps
-- every problem detail at no more than 4,107 UTF-8 bytes including the fixed
-- ASCII truncation marker.
maximumFindingDetailCharacters :: Int
#if defined(VALIDATION_SOURCE_ACQUISITION_FINDING_DETAIL_CHARACTER_LIMIT_WIDEN_MUTANT)
maximumFindingDetailCharacters = 1025
#else
maximumFindingDetailCharacters = 1024
#endif

maximumFindingDetailUtf8Bytes :: Int
maximumFindingDetailUtf8Bytes = 4 * maximumFindingDetailCharacters + 11

maximumFindingSubjectUtf8Bytes :: Int
maximumFindingSubjectUtf8Bytes = 4096

maximumObservationValueUtf8Bytes :: Int
maximumObservationValueUtf8Bytes = 256

maximumResultProblemFindings :: Int
#if defined(VALIDATION_SOURCE_ACQUISITION_RESULT_PROBLEM_LIMIT_TIGHTEN_MUTANT)
maximumResultProblemFindings = 127
#else
maximumResultProblemFindings = 128
#endif

maximumDiagnosticResidueFindings :: Int
maximumDiagnosticResidueFindings = 12

maximumResultFindings :: Int
maximumResultFindings =
  maximumResultProblemFindings + maximumDiagnosticResidueFindings

maximumResultObservations :: Int
maximumResultObservations = 19

maximumLengthDigits :: Int
maximumLengthDigits = length (show maximumPayloadBytes)

maximumEnvelopeBytes :: Int
maximumEnvelopeBytes =
  ByteString.length wireMagic
    + maximumLengthDigits
    + 1
    + maximumPayloadBytes
    + 64

envelopeWithinByteLimit :: Int -> Bool
envelopeWithinByteLimit observed =
  envelopeByteLimitBypassed || observed <= maximumEnvelopeBytes

envelopeByteLimitBypassed :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_ENVELOPE_BYTE_LIMIT_BYPASS_MUTANT)
envelopeByteLimitBypassed = True
#else
envelopeByteLimitBypassed = False
#endif

payloadWithinByteLimit :: Integer -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PAYLOAD_BYTE_LIMIT_BYPASS_MUTANT)
payloadWithinByteLimit _ = True
#else
payloadWithinByteLimit observed = observed <= toInteger maximumPayloadBytes
#endif

bundleWithinByteLimit :: Int -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_BUNDLE_BYTE_LIMIT_BYPASS_MUTANT)
bundleWithinByteLimit _ = True
#else
bundleWithinByteLimit observed = observed <= maximumBundleBytes
#endif

fieldWithinByteLimit :: Word32 -> Bool
fieldWithinByteLimit observed =
  fieldByteLimitBypassed || observed <= maximumFieldBytes

fieldByteLimitBypassed :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_FIELD_BYTE_LIMIT_BYPASS_MUTANT)
fieldByteLimitBypassed = True
#else
fieldByteLimitBypassed = False
#endif

commitWithinByteLimit :: Word64 -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_BYTE_LIMIT_BYPASS_MUTANT)
commitWithinByteLimit _ = True
#else
commitWithinByteLimit observed = observed <= fromIntegral maximumCommitBytes
#endif

manifestEntryCountWithinLimit :: Word32 -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_ENTRY_COUNT_LIMIT_BYPASS_MUTANT)
manifestEntryCountWithinLimit _ = True
#else
manifestEntryCountWithinLimit observed = observed <= maximumManifestEntries
#endif

expectedManifestWithinByteLimit :: Int -> Bool
expectedManifestWithinByteLimit observed =
  expectedManifestByteLimitBypassed || observed <= maximumExpectedManifestBytes

expectedManifestByteLimitBypassed :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_BYTE_LIMIT_BYPASS_MUTANT)
expectedManifestByteLimitBypassed = True
#else
expectedManifestByteLimitBypassed = False
#endif

expectedManifestEntryCountWithinLimit :: Word32 -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_COUNT_LIMIT_BYPASS_MUTANT)
expectedManifestEntryCountWithinLimit _ = True
#else
expectedManifestEntryCountWithinLimit observed = observed <= maximumManifestEntries
#endif

canonicalManifestBytes :: SourceAcquisitionManifest -> ByteString
canonicalManifestBytes manifest =
  LazyByteString.toStrict
    ( toLazyByteString
        ( manifestEncodingPart ManifestPayloadMagic (byteString payloadMagic)
            <> manifestEncodingPart ManifestPhase (sizedText (acquisitionPhase manifest))
            <> manifestEncodingPart ManifestAuthority (sizedText (acquisitionAuthority manifest))
            <> manifestEncodingPart ManifestObserverTool (sizedText (acquisitionObserverToolDigest manifest))
            <> manifestEncodingPart ManifestChallenge (sizedText (acquisitionChallenge manifest))
            <> manifestEncodingPart ManifestReplayIdentity (sizedText (acquisitionReplayIdentity manifest))
            <> manifestEncodingPart ManifestRepository (sizedText (acquisitionRepositoryIdentity manifest))
            <> manifestEncodingPart ManifestRequestedRevision (sizedText (acquisitionRequestedRevision manifest))
            <> manifestEncodingPart ManifestCustodyTag (word8 (custodyTag (acquisitionCustody manifest)))
            <> manifestEncodingPart ManifestObjectFormatTag (word8 (objectFormatTag (acquisitionObjectFormat manifest)))
            <> manifestEncodingPart ManifestHead (sizedText (acquisitionHeadIdentity manifest))
            <> manifestEncodingPart ManifestTree (sizedText (acquisitionTreeIdentity manifest))
            <> manifestEncodingPart ManifestAuthoredRoot (sizedText (acquisitionAuthoredRootIdentity manifest))
            <> manifestEncodingPart ManifestFrozenSnapshot (sizedText (acquisitionFrozenSnapshotIdentity manifest))
            <> manifestEncodingPart ManifestBundle (sizedText (acquisitionBundleIdentity manifest))
            <> manifestEncodingPart ManifestSourceSnapshot (sizedText (acquisitionSourceSnapshotIdentity manifest))
            <> manifestEncodingPart ManifestCommitBytes (sizedBytes (acquisitionCommitBytes manifest))
            <> manifestEncodingPart ManifestEntryCount (word32BE (fromIntegral (length (acquisitionEntries manifest))))
            <> manifestEncodingPart ManifestEntries (foldMap encodeEntry (acquisitionEntries manifest))
        )
    )

data ManifestEncodingSlot
  = ManifestPayloadMagic
  | ManifestPhase
  | ManifestAuthority
  | ManifestObserverTool
  | ManifestChallenge
  | ManifestReplayIdentity
  | ManifestRepository
  | ManifestRequestedRevision
  | ManifestCustodyTag
  | ManifestObjectFormatTag
  | ManifestHead
  | ManifestTree
  | ManifestAuthoredRoot
  | ManifestFrozenSnapshot
  | ManifestBundle
  | ManifestSourceSnapshot
  | ManifestCommitBytes
  | ManifestEntryCount
  | ManifestEntries
  deriving (Eq, Ord, Show)

manifestEncodingPart :: ManifestEncodingSlot -> Builder -> Builder
manifestEncodingPart slot builder
  | retainManifestEncodingPart slot = builder
  | otherwise = mempty

retainManifestEncodingPart :: ManifestEncodingSlot -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_PAYLOAD_MAGIC_DROP_MUTANT)
retainManifestEncodingPart slot = slot /= ManifestPayloadMagic
#elif defined(VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_PHASE_DROP_MUTANT)
retainManifestEncodingPart slot = slot /= ManifestPhase
#elif defined(VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_AUTHORITY_DROP_MUTANT)
retainManifestEncodingPart slot = slot /= ManifestAuthority
#elif defined(VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_OBSERVER_TOOL_DROP_MUTANT)
retainManifestEncodingPart slot = slot /= ManifestObserverTool
#elif defined(VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_CHALLENGE_DROP_MUTANT)
retainManifestEncodingPart slot = slot /= ManifestChallenge
#elif defined(VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_REPLAY_IDENTITY_DROP_MUTANT)
retainManifestEncodingPart slot = slot /= ManifestReplayIdentity
#elif defined(VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_REPOSITORY_DROP_MUTANT)
retainManifestEncodingPart slot = slot /= ManifestRepository
#elif defined(VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_REQUESTED_REVISION_DROP_MUTANT)
retainManifestEncodingPart slot = slot /= ManifestRequestedRevision
#elif defined(VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_CUSTODY_TAG_DROP_MUTANT)
retainManifestEncodingPart slot = slot /= ManifestCustodyTag
#elif defined(VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_OBJECT_FORMAT_TAG_DROP_MUTANT)
retainManifestEncodingPart slot = slot /= ManifestObjectFormatTag
#elif defined(VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_HEAD_DROP_MUTANT)
retainManifestEncodingPart slot = slot /= ManifestHead
#elif defined(VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_TREE_DROP_MUTANT)
retainManifestEncodingPart slot = slot /= ManifestTree
#elif defined(VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_AUTHORED_ROOT_DROP_MUTANT)
retainManifestEncodingPart slot = slot /= ManifestAuthoredRoot
#elif defined(VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_FROZEN_SNAPSHOT_DROP_MUTANT)
retainManifestEncodingPart slot = slot /= ManifestFrozenSnapshot
#elif defined(VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_BUNDLE_DROP_MUTANT)
retainManifestEncodingPart slot = slot /= ManifestBundle
#elif defined(VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_SOURCE_SNAPSHOT_DROP_MUTANT)
retainManifestEncodingPart slot = slot /= ManifestSourceSnapshot
#elif defined(VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_COMMIT_BYTES_DROP_MUTANT)
retainManifestEncodingPart slot = slot /= ManifestCommitBytes
#elif defined(VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_ENTRY_COUNT_DROP_MUTANT)
retainManifestEncodingPart slot = slot /= ManifestEntryCount
#elif defined(VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_ENTRIES_DROP_MUTANT)
retainManifestEncodingPart slot = slot /= ManifestEntries
#else
retainManifestEncodingPart slot = slot `seq` True
#endif

canonicalEnvelopePrefix :: SourceAcquisitionManifest -> ByteString
canonicalEnvelopePrefix manifest =
  envelopeEncodingPart EnvelopeWireMagic wireMagic
    <> envelopeEncodingPart EnvelopePayloadLength (ByteString8.pack (show (ByteString.length payload)))
    <> envelopeEncodingPart EnvelopeLengthTerminator "\n"
    <> envelopeEncodingPart EnvelopePayload payload
 where
  payload = canonicalManifestBytes manifest

canonicalEnvelopeBytes :: SourceAcquisitionManifest -> ByteString -> ByteString
canonicalEnvelopeBytes manifest signatureBytes =
  canonicalEnvelopePrefix manifest
    <> envelopeEncodingPart EnvelopeSignature signatureBytes

data EnvelopeEncodingSlot
  = EnvelopeWireMagic
  | EnvelopePayloadLength
  | EnvelopeLengthTerminator
  | EnvelopePayload
  | EnvelopeSignature
  deriving (Eq, Ord, Show)

envelopeEncodingPart :: EnvelopeEncodingSlot -> ByteString -> ByteString
envelopeEncodingPart slot bytes
  | retainEnvelopeEncodingPart slot = bytes
  | otherwise = ByteString.empty

retainEnvelopeEncodingPart :: EnvelopeEncodingSlot -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_CANONICAL_ENVELOPE_WIRE_MAGIC_DROP_MUTANT)
retainEnvelopeEncodingPart slot = slot /= EnvelopeWireMagic
#elif defined(VALIDATION_SOURCE_ACQUISITION_CANONICAL_ENVELOPE_PAYLOAD_LENGTH_DROP_MUTANT)
retainEnvelopeEncodingPart slot = slot /= EnvelopePayloadLength
#elif defined(VALIDATION_SOURCE_ACQUISITION_CANONICAL_ENVELOPE_LENGTH_TERMINATOR_DROP_MUTANT)
retainEnvelopeEncodingPart slot = slot /= EnvelopeLengthTerminator
#elif defined(VALIDATION_SOURCE_ACQUISITION_CANONICAL_ENVELOPE_PAYLOAD_DROP_MUTANT)
retainEnvelopeEncodingPart slot = slot /= EnvelopePayload
#elif defined(VALIDATION_SOURCE_ACQUISITION_CANONICAL_ENVELOPE_SIGNATURE_DROP_MUTANT)
retainEnvelopeEncodingPart slot = slot /= EnvelopeSignature
#else
retainEnvelopeEncodingPart slot = slot `seq` True
#endif

splitSignedSourceAcquisition
  :: ByteString
  -> Either SourceAcquisitionProblem (ByteString, ByteString, ByteString)
splitSignedSourceAcquisition wire = do
  if not (envelopeWithinByteLimit (ByteString.length wire))
    then Left (SourceAcquisitionEnvelopeTooLarge (ByteString.length wire))
    else pure ()
  afterMagic <-
#if defined(VALIDATION_SOURCE_ACQUISITION_WIRE_MAGIC_BYPASS_MUTANT)
    pure (ByteString.drop (ByteString.length wireMagic) wire)
#else
    maybe
      (Left (SourceAcquisitionWireMalformed "missing exact v2 envelope magic"))
      Right
      (ByteString.stripPrefix wireMagic wire)
#endif
  let (lengthBytes, afterLength) = ByteString.break (== 10) afterMagic
#if defined(VALIDATION_SOURCE_ACQUISITION_PAYLOAD_LENGTH_TERMINATOR_BYPASS_MUTANT)
  afterLength `seq` pure ()
#else
  if ByteString.null afterLength
    then Left (SourceAcquisitionWireMalformed "missing payload-length terminator")
    else pure ()
#endif
  payloadLength <- parsePayloadLength lengthBytes
  let body = ByteString.drop 1 afterLength
      (payload, signatureBytes) = ByteString.splitAt payloadLength body
  if not (payloadFitsAvailableEnvelope payloadLength (ByteString.length payload))
    then Left (SourceAcquisitionWireMalformed "declared payload exceeds envelope bytes")
    else pure ()
  if not (signatureLengthIsExact signatureBytes)
    then Left (SourceAcquisitionWireMalformed "Ed25519 signature must be exactly 64 bytes")
    else pure ()
  let signedPrefix = ByteString.take (ByteString.length wire - 64) wire
  pure (signedPrefix, payload, signatureBytes)

parsePayloadLength :: ByteString -> Either SourceAcquisitionProblem Int
parsePayloadLength raw
  | not (payloadLengthNonempty raw) = malformed
  | not (payloadLengthDigitCount raw) = malformed
  | not (payloadLengthAsciiDigits raw) = malformed
  | not (payloadWithinByteLimit value) =
      Left (SourceAcquisitionPayloadTooLarge (fromInteger value))
  | otherwise = Right (fromInteger value)
 where
  value = payloadLengthValue raw
  accumulate total byte = total * 10 + toInteger (byte - 48)
  malformed = Left (SourceAcquisitionWireMalformed "payload length is not a bounded unsigned decimal integer")

  payloadLengthValue bytes =
#if defined(VALIDATION_SOURCE_ACQUISITION_PAYLOAD_LENGTH_VALUE_FOLD_MUTANT)
    ByteString.foldl' accumulate 0 bytes + 1
#else
    ByteString.foldl' accumulate 0 bytes
#endif

payloadFitsAvailableEnvelope :: Int -> Int -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PAYLOAD_AVAILABILITY_BYPASS_MUTANT)
payloadFitsAvailableEnvelope _ _ = True
#else
payloadFitsAvailableEnvelope declared observed = observed == declared
#endif

signatureLengthIsExact :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_SIGNATURE_LENGTH_BYPASS_MUTANT)
signatureLengthIsExact _ = True
#else
signatureLengthIsExact bytes = ByteString.length bytes == 64
#endif

payloadLengthNonempty :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PAYLOAD_LENGTH_NONEMPTY_BYPASS_MUTANT)
payloadLengthNonempty _ = True
#else
payloadLengthNonempty = not . ByteString.null
#endif

payloadLengthDigitCount :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PAYLOAD_LENGTH_DIGIT_COUNT_BYPASS_MUTANT)
payloadLengthDigitCount _ = True
#else
payloadLengthDigitCount raw = ByteString.length raw <= maximumLengthDigits
#endif

payloadLengthAsciiDigits :: ByteString -> Bool
payloadLengthAsciiDigits value =
  payloadLengthAsciiDigitBypassed
    || ByteString.all payloadLengthAsciiDigit value

payloadLengthAsciiDigitBypassed :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PAYLOAD_LENGTH_ASCII_DIGIT_BYPASS_MUTANT)
payloadLengthAsciiDigitBypassed = True
#else
payloadLengthAsciiDigitBypassed = False
#endif

payloadLengthAsciiDigit :: Word8 -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PAYLOAD_LENGTH_ASCII_DIGIT_REMOVAL_MUTANT)
payloadLengthAsciiDigit _ = False
#else
payloadLengthAsciiDigit byte = byte >= 48 && byte <= 57
#endif

verifyRawEnvelopeSignature
  :: ByteString
  -> ByteString
  -> ByteString
  -> Either SourceAcquisitionProblem ()
verifyRawEnvelopeSignature publicKeyBytes signedPrefix signatureBytes
  | signatureVerificationBypassed = Right ()
#if defined(VALIDATION_SOURCE_ACQUISITION_PUBLIC_KEY_LENGTH_CLASSIFICATION_MUTANT)
  | ByteString.length publicKeyBytes /= 32 = Left SourceAcquisitionSignatureInvalid
#else
  | ByteString.length publicKeyBytes /= 32 = Left SourceAcquisitionPublicKeyInvalid
#endif
  | otherwise = case Ed25519.publicKey publicKeyBytes of
      CryptoFailed _ -> Left SourceAcquisitionPublicKeyInvalid
      CryptoPassed publicKey -> case Ed25519.signature signatureBytes of
        CryptoFailed _ -> Left SourceAcquisitionSignatureInvalid
        CryptoPassed signature
          | Ed25519.verify publicKey signedPrefix signature -> Right ()
          | otherwise -> Left SourceAcquisitionSignatureInvalid

signatureVerificationBypassed :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_SIGNATURE_BYPASS_MUTANT)
signatureVerificationBypassed = True
#else
signatureVerificationBypassed = False
#endif

decodeManifest :: ByteString -> Either SourceAcquisitionProblem SourceAcquisitionManifest
decodeManifest bytes = do
  cursor0 <-
#if defined(VALIDATION_SOURCE_ACQUISITION_PAYLOAD_MAGIC_BYPASS_MUTANT)
    pure (ByteString.drop (ByteString.length payloadMagic) bytes)
#else
    maybe
      (Left (SourceAcquisitionWireMalformed "missing exact v2 payload magic"))
      Right
      (ByteString.stripPrefix payloadMagic bytes)
#endif
  (phase, cursor1) <- takeText "phase" (routedManifestCursor ManifestCursorAfterMagic cursor0)
  (authority, cursor2) <- takeText "authority" (routedManifestCursor ManifestCursorAfterPhase cursor1)
  (observerDigest, cursor3) <- takeText "observer-tool-digest" (routedManifestCursor ManifestCursorAfterAuthority cursor2)
  (challenge, cursor4) <- takeText "challenge" (routedManifestCursor ManifestCursorAfterObserverTool cursor3)
  (replayIdentity, cursor5) <- takeText "replay-identity" (routedManifestCursor ManifestCursorAfterChallenge cursor4)
  (repositoryIdentity, cursor6) <- takeText "repository-identity" (routedManifestCursor ManifestCursorAfterReplayIdentity cursor5)
  (requestedRevision, cursor7) <- takeText "requested-revision" (routedManifestCursor ManifestCursorAfterRepository cursor6)
  (custodyByte, cursor8) <- takeWord8 "custody" (routedManifestCursor ManifestCursorAfterRequestedRevision cursor7)
  custody <- case custodyByte of
    1 | admitFrozenCustodyTag -> Right ExternallyFrozenReadOnlyBundle
    2 -> Right SequentialMutableBundle
#if defined(VALIDATION_SOURCE_ACQUISITION_CUSTODY_TAG_WIDEN_MUTANT)
    _ -> Right SequentialMutableBundle
#else
    value -> Left (SourceAcquisitionCustodyUnsupported value)
#endif
  (formatByte, cursor9) <- takeWord8 "object-format" (routedManifestCursor ManifestCursorAfterCustody cursor8)
  objectFormat <- case formatByte of
    1 | admitObjectFormatSha1Tag -> Right GitObjectSha1
    2 | admitObjectFormatSha256Tag -> Right GitObjectSha256
#if defined(VALIDATION_SOURCE_ACQUISITION_OBJECT_FORMAT_TAG_WIDEN_MUTANT)
    _ -> Right GitObjectSha1
#else
    value -> Left (SourceAcquisitionObjectFormatUnsupported value)
#endif
  (headIdentity, cursor10) <- takeText "head-identity" (routedManifestCursor ManifestCursorAfterObjectFormat cursor9)
  (treeIdentity, cursor11) <- takeText "tree-identity" (routedManifestCursor ManifestCursorAfterHead cursor10)
  (authoredRootIdentity, cursor12) <- takeText "authored-root-identity" (routedManifestCursor ManifestCursorAfterTree cursor11)
  (frozenSnapshotIdentity, cursor13) <- takeText "frozen-snapshot-identity" (routedManifestCursor ManifestCursorAfterAuthoredRoot cursor12)
  (bundleIdentity, cursor14) <- takeText "bundle-identity" (routedManifestCursor ManifestCursorAfterFrozenSnapshot cursor13)
  (sourceSnapshotIdentity, cursor15) <- takeText "source-snapshot-identity" (routedManifestCursor ManifestCursorAfterBundle cursor14)
  (commitBytes, cursor16) <- takeSizedBytesWithLimit "commit" maximumCommitBytes (routedManifestCursor ManifestCursorAfterSourceSnapshot cursor15)
  (entryCount, cursor17) <- takeWord32 "entry-count" (routedManifestCursor ManifestCursorAfterCommit cursor16)
  if not (manifestEntryCountWithinLimit entryCount)
    then Left (SourceAcquisitionManifestTooLarge entryCount)
    else pure ()
  (entries, remaining) <- takeEntries (fromIntegral entryCount) (routedManifestCursor ManifestCursorAfterEntryCount cursor17)
  if payloadHasNoTrailingBytes remaining
    then
      Right
        SourceAcquisitionManifest
          { acquisitionPhase = decodedManifestText DecodedManifestPhase phase
          , acquisitionAuthority = decodedManifestText DecodedManifestAuthority authority
          , acquisitionObserverToolDigest = decodedManifestText DecodedManifestObserverTool observerDigest
          , acquisitionChallenge = decodedManifestText DecodedManifestChallenge challenge
          , acquisitionReplayIdentity = decodedManifestText DecodedManifestReplayIdentity replayIdentity
          , acquisitionRepositoryIdentity = decodedManifestText DecodedManifestRepository repositoryIdentity
          , acquisitionRequestedRevision = decodedManifestText DecodedManifestRequestedRevision requestedRevision
          , acquisitionCustody = decodedManifestCustody custody
          , acquisitionObjectFormat = decodedManifestObjectFormat objectFormat
          , acquisitionHeadIdentity = decodedManifestText DecodedManifestHead headIdentity
          , acquisitionTreeIdentity = decodedManifestText DecodedManifestTree treeIdentity
          , acquisitionAuthoredRootIdentity = decodedManifestText DecodedManifestAuthoredRoot authoredRootIdentity
          , acquisitionFrozenSnapshotIdentity = decodedManifestText DecodedManifestFrozenSnapshot frozenSnapshotIdentity
          , acquisitionBundleIdentity = decodedManifestText DecodedManifestBundle bundleIdentity
          , acquisitionSourceSnapshotIdentity = decodedManifestText DecodedManifestSourceSnapshot sourceSnapshotIdentity
          , acquisitionCommitBytes = decodedManifestCommitBytes commitBytes
          , acquisitionEntries = decodedManifestEntries entries
          }
    else Left (SourceAcquisitionWireMalformed "payload has trailing bytes")

data ManifestDecodeCursorSlot
  = ManifestCursorAfterMagic
  | ManifestCursorAfterPhase
  | ManifestCursorAfterAuthority
  | ManifestCursorAfterObserverTool
  | ManifestCursorAfterChallenge
  | ManifestCursorAfterReplayIdentity
  | ManifestCursorAfterRepository
  | ManifestCursorAfterRequestedRevision
  | ManifestCursorAfterCustody
  | ManifestCursorAfterObjectFormat
  | ManifestCursorAfterHead
  | ManifestCursorAfterTree
  | ManifestCursorAfterAuthoredRoot
  | ManifestCursorAfterFrozenSnapshot
  | ManifestCursorAfterBundle
  | ManifestCursorAfterSourceSnapshot
  | ManifestCursorAfterCommit
  | ManifestCursorAfterEntryCount
  deriving (Eq, Ord, Show)

routedManifestCursor :: ManifestDecodeCursorSlot -> ByteString -> ByteString
#if defined(VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_MAGIC_ROUTE_MUTANT)
routedManifestCursor slot cursor
  | slot == ManifestCursorAfterMagic = ByteString.drop 1 cursor
  | otherwise = cursor
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_PHASE_ROUTE_MUTANT)
routedManifestCursor slot cursor
  | slot == ManifestCursorAfterPhase = ByteString.drop 1 cursor
  | otherwise = cursor
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_AUTHORITY_ROUTE_MUTANT)
routedManifestCursor slot cursor
  | slot == ManifestCursorAfterAuthority = ByteString.drop 1 cursor
  | otherwise = cursor
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_OBSERVER_TOOL_ROUTE_MUTANT)
routedManifestCursor slot cursor
  | slot == ManifestCursorAfterObserverTool = ByteString.drop 1 cursor
  | otherwise = cursor
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_CHALLENGE_ROUTE_MUTANT)
routedManifestCursor slot cursor
  | slot == ManifestCursorAfterChallenge = ByteString.drop 1 cursor
  | otherwise = cursor
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_REPLAY_IDENTITY_ROUTE_MUTANT)
routedManifestCursor slot cursor
  | slot == ManifestCursorAfterReplayIdentity = ByteString.drop 1 cursor
  | otherwise = cursor
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_REPOSITORY_ROUTE_MUTANT)
routedManifestCursor slot cursor
  | slot == ManifestCursorAfterRepository = ByteString.drop 1 cursor
  | otherwise = cursor
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_REQUESTED_REVISION_ROUTE_MUTANT)
routedManifestCursor slot cursor
  | slot == ManifestCursorAfterRequestedRevision = ByteString.drop 1 cursor
  | otherwise = cursor
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_CUSTODY_ROUTE_MUTANT)
routedManifestCursor slot cursor
  | slot == ManifestCursorAfterCustody = ByteString.drop 1 cursor
  | otherwise = cursor
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_OBJECT_FORMAT_ROUTE_MUTANT)
routedManifestCursor slot cursor
  | slot == ManifestCursorAfterObjectFormat = ByteString.drop 1 cursor
  | otherwise = cursor
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_HEAD_ROUTE_MUTANT)
routedManifestCursor slot cursor
  | slot == ManifestCursorAfterHead = ByteString.drop 1 cursor
  | otherwise = cursor
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_TREE_ROUTE_MUTANT)
routedManifestCursor slot cursor
  | slot == ManifestCursorAfterTree = ByteString.drop 1 cursor
  | otherwise = cursor
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_AUTHORED_ROOT_ROUTE_MUTANT)
routedManifestCursor slot cursor
  | slot == ManifestCursorAfterAuthoredRoot = ByteString.drop 1 cursor
  | otherwise = cursor
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_FROZEN_SNAPSHOT_ROUTE_MUTANT)
routedManifestCursor slot cursor
  | slot == ManifestCursorAfterFrozenSnapshot = ByteString.drop 1 cursor
  | otherwise = cursor
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_BUNDLE_ROUTE_MUTANT)
routedManifestCursor slot cursor
  | slot == ManifestCursorAfterBundle = ByteString.drop 1 cursor
  | otherwise = cursor
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_SOURCE_SNAPSHOT_ROUTE_MUTANT)
routedManifestCursor slot cursor
  | slot == ManifestCursorAfterSourceSnapshot = ByteString.drop 1 cursor
  | otherwise = cursor
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_COMMIT_ROUTE_MUTANT)
routedManifestCursor slot cursor
  | slot == ManifestCursorAfterCommit = ByteString.drop 1 cursor
  | otherwise = cursor
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_ENTRY_COUNT_ROUTE_MUTANT)
routedManifestCursor slot cursor
  | slot == ManifestCursorAfterEntryCount = ByteString.drop 1 cursor
  | otherwise = cursor
#else
routedManifestCursor slot cursor = slot `seq` cursor
#endif


data DecodedManifestTextSlot
  = DecodedManifestPhase
  | DecodedManifestAuthority
  | DecodedManifestObserverTool
  | DecodedManifestChallenge
  | DecodedManifestReplayIdentity
  | DecodedManifestRepository
  | DecodedManifestRequestedRevision
  | DecodedManifestHead
  | DecodedManifestTree
  | DecodedManifestAuthoredRoot
  | DecodedManifestFrozenSnapshot
  | DecodedManifestBundle
  | DecodedManifestSourceSnapshot
  deriving (Eq, Ord, Show)

decodedManifestText :: DecodedManifestTextSlot -> Text -> Text
decodedManifestText slot value
  | mutateDecodedManifestText slot = value <> "mutated"
  | otherwise = value

mutateDecodedManifestText :: DecodedManifestTextSlot -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_DECODED_MANIFEST_PHASE_MAPPING_MUTANT)
mutateDecodedManifestText slot = slot == DecodedManifestPhase
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODED_MANIFEST_AUTHORITY_MAPPING_MUTANT)
mutateDecodedManifestText slot = slot == DecodedManifestAuthority
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODED_MANIFEST_OBSERVER_TOOL_MAPPING_MUTANT)
mutateDecodedManifestText slot = slot == DecodedManifestObserverTool
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODED_MANIFEST_CHALLENGE_MAPPING_MUTANT)
mutateDecodedManifestText slot = slot == DecodedManifestChallenge
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODED_MANIFEST_REPLAY_IDENTITY_MAPPING_MUTANT)
mutateDecodedManifestText slot = slot == DecodedManifestReplayIdentity
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODED_MANIFEST_REPOSITORY_MAPPING_MUTANT)
mutateDecodedManifestText slot = slot == DecodedManifestRepository
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODED_MANIFEST_REQUESTED_REVISION_MAPPING_MUTANT)
mutateDecodedManifestText slot = slot == DecodedManifestRequestedRevision
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODED_MANIFEST_HEAD_MAPPING_MUTANT)
mutateDecodedManifestText slot = slot == DecodedManifestHead
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODED_MANIFEST_TREE_MAPPING_MUTANT)
mutateDecodedManifestText slot = slot == DecodedManifestTree
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODED_MANIFEST_AUTHORED_ROOT_MAPPING_MUTANT)
mutateDecodedManifestText slot = slot == DecodedManifestAuthoredRoot
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODED_MANIFEST_FROZEN_SNAPSHOT_MAPPING_MUTANT)
mutateDecodedManifestText slot = slot == DecodedManifestFrozenSnapshot
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODED_MANIFEST_BUNDLE_MAPPING_MUTANT)
mutateDecodedManifestText slot = slot == DecodedManifestBundle
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODED_MANIFEST_SOURCE_SNAPSHOT_MAPPING_MUTANT)
mutateDecodedManifestText slot = slot == DecodedManifestSourceSnapshot
#else
mutateDecodedManifestText slot = slot `seq` False
#endif

decodedManifestCustody :: SourceAcquisitionCustody -> SourceAcquisitionCustody
#if defined(VALIDATION_SOURCE_ACQUISITION_DECODED_MANIFEST_CUSTODY_MAPPING_MUTANT)
decodedManifestCustody custody = custody `seq` SequentialMutableBundle
#else
decodedManifestCustody = id
#endif

decodedManifestObjectFormat :: GitObjectFormat -> GitObjectFormat
#if defined(VALIDATION_SOURCE_ACQUISITION_DECODED_MANIFEST_OBJECT_FORMAT_MAPPING_MUTANT)
decodedManifestObjectFormat objectFormat = objectFormat `seq` GitObjectSha256
#else
decodedManifestObjectFormat = id
#endif

decodedManifestCommitBytes :: ByteString -> ByteString
#if defined(VALIDATION_SOURCE_ACQUISITION_DECODED_MANIFEST_COMMIT_BYTES_MAPPING_MUTANT)
decodedManifestCommitBytes bytes = bytes <> "mutated"
#else
decodedManifestCommitBytes = id
#endif

decodedManifestEntries :: [SourceAcquisitionEntry] -> [SourceAcquisitionEntry]
#if defined(VALIDATION_SOURCE_ACQUISITION_DECODED_MANIFEST_ENTRIES_MAPPING_MUTANT)
decodedManifestEntries entries = drop 1 entries
#else
decodedManifestEntries = id
#endif

payloadHasNoTrailingBytes :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PAYLOAD_TRAILING_BYTES_BYPASS_MUTANT)
payloadHasNoTrailingBytes _ = True
#else
payloadHasNoTrailingBytes = ByteString.null
#endif

takeEntries
  :: Int
  -> ByteString
  -> Either SourceAcquisitionProblem ([SourceAcquisitionEntry], ByteString)
takeEntries count = go count []
 where
#if defined(VALIDATION_SOURCE_ACQUISITION_DECODED_SIGNED_ENTRY_ORDER_MUTANT)
  go 0 reversed cursor = Right (reversed, cursor)
#else
  go 0 reversed cursor = Right (reverse reversed, cursor)
#endif
  go remaining reversed cursor = do
    (pathText, cursor1) <- takeText "entry-path" cursor
    let path = Text.unpack pathText
    (modeByte, cursor2) <-
      takeWord8
        "entry-mode"
        (routedEntryCursor DecodedSignedEntry EntryCursorAfterPath cursor1)
    mode <- case modeByte of
      1 | admitEntryModeRegularTag -> Right RegularFile
      2 | admitEntryModeExecutableTag -> Right ExecutableFile
      3 | admitEntryModeSymbolicLinkTag -> Right SymbolicLink
#if defined(VALIDATION_SOURCE_ACQUISITION_ENTRY_MODE_TAG_WIDEN_MUTANT)
      _ -> Right RegularFile
#else
      value -> Left (SourceAcquisitionEntryModeUnsupported path value)
#endif
    (gitObjectId, cursor3) <-
      takeText
        "entry-git-object-id"
        (routedEntryCursor DecodedSignedEntry EntryCursorAfterMode cursor2)
    (byteLength, cursor4) <-
      takeWord64
        "entry-byte-length"
        (routedEntryCursor DecodedSignedEntry EntryCursorAfterGitObject cursor3)
    (blobSha256, cursor5) <-
      takeText
        "entry-blob-sha256"
        (routedEntryCursor DecodedSignedEntry EntryCursorAfterByteLength cursor4)
    let entry =
          SourceAcquisitionEntry
            { acquisitionEntryPath = decodedEntryPath DecodedSignedEntry path
            , acquisitionEntryMode = decodedEntryMode DecodedSignedEntry mode
            , acquisitionEntryGitObjectId = decodedEntryText DecodedSignedEntry DecodedEntryGitObjectId gitObjectId
            , acquisitionEntryByteLength = decodedEntryByteLength DecodedSignedEntry byteLength
            , acquisitionEntryBlobSha256 = decodedEntryText DecodedSignedEntry DecodedEntryBlobSha256 blobSha256
            }
    go
      (remaining - 1)
      (entry : reversed)
      (routedEntryCursor DecodedSignedEntry EntryCursorAfterBlobSha256 cursor5)

admitFrozenCustodyTag :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_CUSTODY_FROZEN_TAG_REMOVAL_MUTANT)
admitFrozenCustodyTag = False
#else
admitFrozenCustodyTag = True
#endif

admitObjectFormatSha1Tag :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_OBJECT_FORMAT_SHA1_TAG_REMOVAL_MUTANT)
admitObjectFormatSha1Tag = False
#else
admitObjectFormatSha1Tag = True
#endif

admitObjectFormatSha256Tag :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_OBJECT_FORMAT_SHA256_TAG_REMOVAL_MUTANT)
admitObjectFormatSha256Tag = False
#else
admitObjectFormatSha256Tag = True
#endif

admitEntryModeRegularTag :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_ENTRY_MODE_REGULAR_TAG_REMOVAL_MUTANT)
admitEntryModeRegularTag = False
#else
admitEntryModeRegularTag = True
#endif

admitEntryModeExecutableTag :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_ENTRY_MODE_EXECUTABLE_TAG_REMOVAL_MUTANT)
admitEntryModeExecutableTag = False
#else
admitEntryModeExecutableTag = True
#endif

admitEntryModeSymbolicLinkTag :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_ENTRY_MODE_SYMBOLIC_LINK_TAG_REMOVAL_MUTANT)
admitEntryModeSymbolicLinkTag = False
#else
admitEntryModeSymbolicLinkTag = True
#endif

takeText
  :: Text
  -> ByteString
  -> Either SourceAcquisitionProblem (Text, ByteString)
takeText label cursor = do
  (raw, remaining) <- takeSizedText label cursor
  case TextEncoding.decodeUtf8' raw of
#if defined(VALIDATION_SOURCE_ACQUISITION_FIELD_UTF8_CLASSIFICATION_MUTANT)
    Left _ -> Left (SourceAcquisitionFieldTooLarge label 0)
#else
    Left _ -> Left (SourceAcquisitionWireMalformed (label <> " is not UTF-8"))
#endif
    Right value -> Right (value, remaining)

takeSizedText
  :: Text
  -> ByteString
  -> Either SourceAcquisitionProblem (ByteString, ByteString)
takeSizedText label cursor = do
  (lengthValue, afterLength) <- takeWord32 (label <> "-length") cursor
  if not (fieldWithinByteLimit lengthValue)
    then Left (SourceAcquisitionFieldTooLarge label lengthValue)
    else pure ()
  let wanted = fromIntegral lengthValue
      (value, remaining) = ByteString.splitAt wanted afterLength
  if fieldFitsAvailablePayload wanted (ByteString.length value)
    then Right (value, remaining)
    else Left (SourceAcquisitionWireMalformed (label <> " exceeds payload bytes"))

takeSizedBytesWithLimit
  :: Text
  -> Word32
  -> ByteString
  -> Either SourceAcquisitionProblem (ByteString, ByteString)
takeSizedBytesWithLimit label _limit cursor = do
  (lengthValue, afterLength) <- takeWord32 (label <> "-length") cursor
  if not (commitWithinByteLimit (fromIntegral lengthValue))
    then Left (SourceAcquisitionCommitTooLarge lengthValue)
    else pure ()
  let wanted = fromIntegral lengthValue
      (value, remaining) = ByteString.splitAt wanted afterLength
  if commitFieldFitsAvailablePayload wanted (ByteString.length value)
    then Right (value, remaining)
    else Left (SourceAcquisitionWireMalformed (label <> " exceeds payload bytes"))

commitFieldFitsAvailablePayload :: Int -> Int -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_FIELD_AVAILABILITY_BYPASS_MUTANT)
commitFieldFitsAvailablePayload _ _ = True
#else
commitFieldFitsAvailablePayload declared observed = observed == declared
#endif

fieldFitsAvailablePayload :: Int -> Int -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_FIELD_AVAILABILITY_CLASSIFICATION_MUTANT)
fieldFitsAvailablePayload declared observed = observed + 1 == declared
#else
fieldFitsAvailablePayload declared observed = observed == declared
#endif

takeWord8
  :: Text
  -> ByteString
  -> Either SourceAcquisitionProblem (Word8, ByteString)
takeWord8 label bytes =
  case ByteString.uncons bytes of
#if defined(VALIDATION_SOURCE_ACQUISITION_WORD8_MISSING_CLASSIFICATION_MUTANT)
    Nothing -> Left (SourceAcquisitionWireMalformed (label <> " is truncated"))
#else
    Nothing -> Left (SourceAcquisitionWireMalformed (label <> " is missing"))
#endif
    Just pair -> Right pair

takeWord32
  :: Text
  -> ByteString
  -> Either SourceAcquisitionProblem (Word32, ByteString)
takeWord32 label bytes =
  if ByteString.length prefix /= 4
#if defined(VALIDATION_SOURCE_ACQUISITION_WORD32_TRUNCATION_CLASSIFICATION_MUTANT)
    then Left (SourceAcquisitionWireMalformed (label <> " is missing"))
#else
    then Left (SourceAcquisitionWireMalformed (label <> " is truncated"))
#endif
    else Right (foldWord32 prefix, remaining)
 where
  (prefix, remaining) = ByteString.splitAt 4 bytes

takeWord64
  :: Text
  -> ByteString
  -> Either SourceAcquisitionProblem (Word64, ByteString)
takeWord64 label bytes =
  if ByteString.length prefix /= 8
#if defined(VALIDATION_SOURCE_ACQUISITION_WORD64_TRUNCATION_CLASSIFICATION_MUTANT)
    then Left (SourceAcquisitionWireMalformed (label <> " is missing"))
#else
    then Left (SourceAcquisitionWireMalformed (label <> " is truncated"))
#endif
    else Right (foldWord64 prefix, remaining)
 where
  (prefix, remaining) = ByteString.splitAt 8 bytes

foldWord32 :: ByteString -> Word32
#if defined(VALIDATION_SOURCE_ACQUISITION_WORD32_FOLD_MUTANT)
foldWord32 bytes = ByteString.foldl' (\value byte -> (value `shiftL` 8) .|. fromIntegral byte) 0 bytes + 1
#else
foldWord32 = ByteString.foldl' (\value byte -> (value `shiftL` 8) .|. fromIntegral byte) 0
#endif

foldWord64 :: ByteString -> Word64
#if defined(VALIDATION_SOURCE_ACQUISITION_WORD64_FOLD_MUTANT)
foldWord64 bytes = ByteString.foldl' (\value byte -> (value `shiftL` 8) .|. fromIntegral byte) 0 bytes + 1
#else
foldWord64 = ByteString.foldl' (\value byte -> (value `shiftL` 8) .|. fromIntegral byte) 0
#endif

sizedText :: Text -> Builder
sizedText = sizedBytes . encodedSizedText

encodedSizedText :: Text -> ByteString
#if defined(VALIDATION_SOURCE_ACQUISITION_SIZED_TEXT_UTF8_MAPPING_MUTANT)
encodedSizedText value = TextEncoding.encodeUtf8 value <> "mutated"
#else
encodedSizedText = TextEncoding.encodeUtf8
#endif

sizedBytes :: ByteString -> Builder
sizedBytes bytes =
#if defined(VALIDATION_SOURCE_ACQUISITION_SIZED_BYTES_LENGTH_PREFIX_DROP_MUTANT)
  byteString bytes
#elif defined(VALIDATION_SOURCE_ACQUISITION_SIZED_BYTES_VALUE_DROP_MUTANT)
  word32BE (fromIntegral (ByteString.length bytes))
#else
  word32BE (fromIntegral (ByteString.length bytes)) <> byteString bytes
#endif

encodeEntry :: SourceAcquisitionEntry -> Builder
encodeEntry entry =
  entryEncodingPart EntryPath (sizedText (Text.pack (acquisitionEntryPath entry)))
    <> entryEncodingPart EntryMode (word8 (modeTag (acquisitionEntryMode entry)))
    <> entryEncodingPart EntryGitObjectId (sizedText (acquisitionEntryGitObjectId entry))
    <> entryEncodingPart EntryByteLength (word64BE (acquisitionEntryByteLength entry))
    <> entryEncodingPart EntryBlobSha256 (sizedText (acquisitionEntryBlobSha256 entry))

data EntryEncodingSlot
  = EntryPath
  | EntryMode
  | EntryGitObjectId
  | EntryByteLength
  | EntryBlobSha256
  deriving (Eq, Ord, Show)

entryEncodingPart :: EntryEncodingSlot -> Builder -> Builder
entryEncodingPart slot builder
  | retainEntryEncodingPart slot = builder
  | otherwise = mempty

retainEntryEncodingPart :: EntryEncodingSlot -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_CANONICAL_ENTRY_PATH_DROP_MUTANT)
retainEntryEncodingPart slot = slot /= EntryPath
#elif defined(VALIDATION_SOURCE_ACQUISITION_CANONICAL_ENTRY_MODE_DROP_MUTANT)
retainEntryEncodingPart slot = slot /= EntryMode
#elif defined(VALIDATION_SOURCE_ACQUISITION_CANONICAL_ENTRY_GIT_OBJECT_ID_DROP_MUTANT)
retainEntryEncodingPart slot = slot /= EntryGitObjectId
#elif defined(VALIDATION_SOURCE_ACQUISITION_CANONICAL_ENTRY_BYTE_LENGTH_DROP_MUTANT)
retainEntryEncodingPart slot = slot /= EntryByteLength
#elif defined(VALIDATION_SOURCE_ACQUISITION_CANONICAL_ENTRY_BLOB_SHA256_DROP_MUTANT)
retainEntryEncodingPart slot = slot /= EntryBlobSha256
#else
retainEntryEncodingPart slot = slot `seq` True
#endif

decodeExpectedManifest
  :: ByteString
  -> Either SourceAcquisitionProblem SourceAcquisitionExpectedManifest
decodeExpectedManifest bytes
  | not (expectedManifestWithinByteLimit (ByteString.length bytes)) =
      Left (SourceAcquisitionExpectedManifestTooLarge (ByteString.length bytes))
  | otherwise = case decodeExpectedManifestRaw bytes of
      Left problem -> Left (classifyExpectedManifestDecodeProblem problem)
      Right expectedManifest -> Right expectedManifest

classifyExpectedManifestDecodeProblem
  :: SourceAcquisitionProblem
  -> SourceAcquisitionProblem
classifyExpectedManifestDecodeProblem problem = case problem of
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_COUNT_CLASSIFICATION_MUTANT)
  SourceAcquisitionExpectedManifestEntryCountTooLarge _ _ ->
    SourceAcquisitionExpectedManifestMalformed (boundedShowText problem)
#else
  SourceAcquisitionExpectedManifestEntryCountTooLarge _ _ -> problem
#endif
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_MODE_CLASSIFICATION_MUTANT)
  SourceAcquisitionExpectedManifestEntryModeUnsupported _ _ ->
    SourceAcquisitionExpectedManifestMalformed (boundedShowText problem)
#else
  SourceAcquisitionExpectedManifestEntryModeUnsupported _ _ -> problem
#endif
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_GENERIC_CLASSIFICATION_MUTANT)
  _ -> problem
#else
  _ -> SourceAcquisitionExpectedManifestMalformed (boundedShowText problem)
#endif

decodeExpectedManifestRaw
  :: ByteString
  -> Either SourceAcquisitionProblem SourceAcquisitionExpectedManifest
decodeExpectedManifestRaw bytes = do
  cursor0 <-
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_MAGIC_BYPASS_MUTANT)
    pure (ByteString.drop (ByteString.length expectedManifestMagic) bytes)
#else
    maybe
      (Left (SourceAcquisitionWireMalformed "missing exact expected-manifest magic"))
      Right
      (ByteString.stripPrefix expectedManifestMagic bytes)
#endif
  (formatByte, cursor1) <-
    takeWord8
      "expected-manifest-object-format"
      (routedExpectedManifestCursor ExpectedManifestCursorAfterMagic cursor0)
  objectFormat <- case formatByte of
    1 | admitExpectedObjectFormatSha1Tag -> Right GitObjectSha1
    2 | admitExpectedObjectFormatSha256Tag -> Right GitObjectSha256
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_OBJECT_FORMAT_TAG_WIDEN_MUTANT)
    _ -> Right GitObjectSha1
#else
    value -> Left (SourceAcquisitionWireMalformed ("unsupported expected-manifest object-format tag " <> showText value))
#endif
  (entryCount, cursor2) <-
    takeWord32
      "expected-manifest-entry-count"
      (routedExpectedManifestCursor ExpectedManifestCursorAfterObjectFormat cursor1)
  if not (expectedManifestEntryCountWithinLimit entryCount)
    then Left (SourceAcquisitionExpectedManifestEntryCountTooLarge entryCount maximumManifestEntries)
    else pure ()
  (entries, remaining) <-
    takeExpectedEntries
      (fromIntegral entryCount)
      (routedExpectedManifestCursor ExpectedManifestCursorAfterEntryCount cursor2)
  let decoded =
        SourceAcquisitionExpectedManifest
          { expectedManifestObjectFormat = decodedExpectedManifestObjectFormat objectFormat
          , expectedManifestEntries = decodedExpectedManifestEntries entries
          }
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_TRAILING_BYTES_BYPASS_MUTANT)
  remaining `seq` Right decoded
#else
  if ByteString.null remaining
    then Right decoded
    else Left (SourceAcquisitionWireMalformed "expected manifest has trailing bytes")
#endif

takeExpectedEntries
  :: Int
  -> ByteString
  -> Either SourceAcquisitionProblem ([SourceAcquisitionEntry], ByteString)

data ExpectedManifestDecodeCursorSlot
  = ExpectedManifestCursorAfterMagic
  | ExpectedManifestCursorAfterObjectFormat
  | ExpectedManifestCursorAfterEntryCount
  deriving (Eq, Ord, Show)

routedExpectedManifestCursor
  :: ExpectedManifestDecodeCursorSlot
  -> ByteString
  -> ByteString
#if defined(VALIDATION_SOURCE_ACQUISITION_DECODE_EXPECTED_MANIFEST_CURSOR_AFTER_MAGIC_ROUTE_MUTANT)
routedExpectedManifestCursor slot cursor
  | slot == ExpectedManifestCursorAfterMagic = ByteString.drop 1 cursor
  | otherwise = cursor
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODE_EXPECTED_MANIFEST_CURSOR_AFTER_OBJECT_FORMAT_ROUTE_MUTANT)
routedExpectedManifestCursor slot cursor
  | slot == ExpectedManifestCursorAfterObjectFormat = ByteString.drop 1 cursor
  | otherwise = cursor
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODE_EXPECTED_MANIFEST_CURSOR_AFTER_ENTRY_COUNT_ROUTE_MUTANT)
routedExpectedManifestCursor slot cursor
  | slot == ExpectedManifestCursorAfterEntryCount = ByteString.drop 1 cursor
  | otherwise = cursor
#else
routedExpectedManifestCursor slot cursor = slot `seq` cursor
#endif

takeExpectedEntries count = go count []
 where
#if defined(VALIDATION_SOURCE_ACQUISITION_DECODED_EXPECTED_ENTRY_ORDER_MUTANT)
  go 0 reversed cursor = Right (reversed, cursor)
#else
  go 0 reversed cursor = Right (reverse reversed, cursor)
#endif
  go remaining reversed cursor = do
    (pathText, cursor1) <- takeText "expected-entry-path" cursor
    let path = Text.unpack pathText
    (modeByte, cursor2) <-
      takeWord8
        "expected-entry-mode"
        (routedEntryCursor DecodedExpectedEntry EntryCursorAfterPath cursor1)
    mode <- case modeByte of
      1 | admitExpectedEntryModeRegularTag -> Right RegularFile
      2 | admitExpectedEntryModeExecutableTag -> Right ExecutableFile
      3 | admitExpectedEntryModeSymbolicLinkTag -> Right SymbolicLink
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_MODE_TAG_WIDEN_MUTANT)
      _ -> Right RegularFile
#else
      value -> Left (SourceAcquisitionExpectedManifestEntryModeUnsupported path value)
#endif
    (gitObjectId, cursor3) <-
      takeText
        "expected-entry-git-object-id"
        (routedEntryCursor DecodedExpectedEntry EntryCursorAfterMode cursor2)
    (byteLength, cursor4) <-
      takeWord64
        "expected-entry-byte-length"
        (routedEntryCursor DecodedExpectedEntry EntryCursorAfterGitObject cursor3)
    (blobSha256, cursor5) <-
      takeText
        "expected-entry-blob-sha256"
        (routedEntryCursor DecodedExpectedEntry EntryCursorAfterByteLength cursor4)
    let entry =
          SourceAcquisitionEntry
            { acquisitionEntryPath = decodedEntryPath DecodedExpectedEntry path
            , acquisitionEntryMode = decodedEntryMode DecodedExpectedEntry mode
            , acquisitionEntryGitObjectId = decodedEntryText DecodedExpectedEntry DecodedEntryGitObjectId gitObjectId
            , acquisitionEntryByteLength = decodedEntryByteLength DecodedExpectedEntry byteLength
            , acquisitionEntryBlobSha256 = decodedEntryText DecodedExpectedEntry DecodedEntryBlobSha256 blobSha256
            }
    go
      (remaining - 1)
      (entry : reversed)
      (routedEntryCursor DecodedExpectedEntry EntryCursorAfterBlobSha256 cursor5)

decodedExpectedManifestObjectFormat :: GitObjectFormat -> GitObjectFormat
#if defined(VALIDATION_SOURCE_ACQUISITION_DECODED_EXPECTED_MANIFEST_OBJECT_FORMAT_MAPPING_MUTANT)
decodedExpectedManifestObjectFormat objectFormat = objectFormat `seq` GitObjectSha256
#else
decodedExpectedManifestObjectFormat = id
#endif

decodedExpectedManifestEntries :: [SourceAcquisitionEntry] -> [SourceAcquisitionEntry]
#if defined(VALIDATION_SOURCE_ACQUISITION_DECODED_EXPECTED_MANIFEST_ENTRIES_MAPPING_MUTANT)
decodedExpectedManifestEntries entries = drop 1 entries
#else
decodedExpectedManifestEntries = id
#endif

data DecodedEntryFamily
  = DecodedSignedEntry
  | DecodedExpectedEntry
  deriving (Eq, Ord, Show)

data EntryDecodeCursorSlot
  = EntryCursorAfterPath
  | EntryCursorAfterMode
  | EntryCursorAfterGitObject
  | EntryCursorAfterByteLength
  | EntryCursorAfterBlobSha256
  deriving (Eq, Ord, Show)

routedEntryCursor
  :: DecodedEntryFamily
  -> EntryDecodeCursorSlot
  -> ByteString
  -> ByteString
#if defined(VALIDATION_SOURCE_ACQUISITION_DECODED_SIGNED_AFTER_PATH_CURSOR_ROUTE_MUTANT)
routedEntryCursor family slot cursor
  | family == DecodedSignedEntry && slot == EntryCursorAfterPath = ByteString.drop 1 cursor
  | otherwise = cursor
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODED_SIGNED_AFTER_MODE_CURSOR_ROUTE_MUTANT)
routedEntryCursor family slot cursor
  | family == DecodedSignedEntry && slot == EntryCursorAfterMode = ByteString.drop 1 cursor
  | otherwise = cursor
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODED_SIGNED_AFTER_GIT_OBJECT_CURSOR_ROUTE_MUTANT)
routedEntryCursor family slot cursor
  | family == DecodedSignedEntry && slot == EntryCursorAfterGitObject = ByteString.drop 1 cursor
  | otherwise = cursor
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODED_SIGNED_AFTER_BYTE_LENGTH_CURSOR_ROUTE_MUTANT)
routedEntryCursor family slot cursor
  | family == DecodedSignedEntry && slot == EntryCursorAfterByteLength = ByteString.drop 1 cursor
  | otherwise = cursor
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODED_SIGNED_AFTER_BLOB_SHA256_CURSOR_ROUTE_MUTANT)
routedEntryCursor family slot cursor
  | family == DecodedSignedEntry && slot == EntryCursorAfterBlobSha256 = ByteString.drop 1 cursor
  | otherwise = cursor
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODED_EXPECTED_AFTER_PATH_CURSOR_ROUTE_MUTANT)
routedEntryCursor family slot cursor
  | family == DecodedExpectedEntry && slot == EntryCursorAfterPath = ByteString.drop 1 cursor
  | otherwise = cursor
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODED_EXPECTED_AFTER_MODE_CURSOR_ROUTE_MUTANT)
routedEntryCursor family slot cursor
  | family == DecodedExpectedEntry && slot == EntryCursorAfterMode = ByteString.drop 1 cursor
  | otherwise = cursor
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODED_EXPECTED_AFTER_GIT_OBJECT_CURSOR_ROUTE_MUTANT)
routedEntryCursor family slot cursor
  | family == DecodedExpectedEntry && slot == EntryCursorAfterGitObject = ByteString.drop 1 cursor
  | otherwise = cursor
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODED_EXPECTED_AFTER_BYTE_LENGTH_CURSOR_ROUTE_MUTANT)
routedEntryCursor family slot cursor
  | family == DecodedExpectedEntry && slot == EntryCursorAfterByteLength = ByteString.drop 1 cursor
  | otherwise = cursor
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODED_EXPECTED_AFTER_BLOB_SHA256_CURSOR_ROUTE_MUTANT)
routedEntryCursor family slot cursor
  | family == DecodedExpectedEntry && slot == EntryCursorAfterBlobSha256 = ByteString.drop 1 cursor
  | otherwise = cursor
#else
routedEntryCursor family slot cursor = family `seq` slot `seq` cursor
#endif

data DecodedEntryTextSlot
  = DecodedEntryGitObjectId
  | DecodedEntryBlobSha256
  deriving (Eq, Ord, Show)

decodedEntryPath :: DecodedEntryFamily -> FilePath -> FilePath
decodedEntryPath family path
  | mutateDecodedEntryPath family = path <> ".mutated"
  | otherwise = path

mutateDecodedEntryPath :: DecodedEntryFamily -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_DECODED_SIGNED_ENTRY_PATH_MAPPING_MUTANT)
mutateDecodedEntryPath family = family == DecodedSignedEntry
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODED_EXPECTED_ENTRY_PATH_MAPPING_MUTANT)
mutateDecodedEntryPath family = family == DecodedExpectedEntry
#else
mutateDecodedEntryPath family = family `seq` False
#endif

decodedEntryMode :: DecodedEntryFamily -> IndexMode -> IndexMode
decodedEntryMode family mode
  | mutateDecodedEntryMode family = mode `seq` SymbolicLink
  | otherwise = mode

mutateDecodedEntryMode :: DecodedEntryFamily -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_DECODED_SIGNED_ENTRY_MODE_MAPPING_MUTANT)
mutateDecodedEntryMode family = family == DecodedSignedEntry
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODED_EXPECTED_ENTRY_MODE_MAPPING_MUTANT)
mutateDecodedEntryMode family = family == DecodedExpectedEntry
#else
mutateDecodedEntryMode family = family `seq` False
#endif

decodedEntryText :: DecodedEntryFamily -> DecodedEntryTextSlot -> Text -> Text
decodedEntryText family slot value
  | mutateDecodedEntryText family slot = value <> "mutated"
  | otherwise = value

mutateDecodedEntryText :: DecodedEntryFamily -> DecodedEntryTextSlot -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_DECODED_SIGNED_ENTRY_GIT_OBJECT_MAPPING_MUTANT)
mutateDecodedEntryText family slot = family == DecodedSignedEntry && slot == DecodedEntryGitObjectId
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODED_SIGNED_ENTRY_BLOB_SHA256_MAPPING_MUTANT)
mutateDecodedEntryText family slot = family == DecodedSignedEntry && slot == DecodedEntryBlobSha256
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODED_EXPECTED_ENTRY_GIT_OBJECT_MAPPING_MUTANT)
mutateDecodedEntryText family slot = family == DecodedExpectedEntry && slot == DecodedEntryGitObjectId
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODED_EXPECTED_ENTRY_BLOB_SHA256_MAPPING_MUTANT)
mutateDecodedEntryText family slot = family == DecodedExpectedEntry && slot == DecodedEntryBlobSha256
#else
mutateDecodedEntryText family slot = family `seq` slot `seq` False
#endif

decodedEntryByteLength :: DecodedEntryFamily -> Word64 -> Word64
decodedEntryByteLength family value
  | mutateDecodedEntryByteLength family = value + 1
  | otherwise = value

mutateDecodedEntryByteLength :: DecodedEntryFamily -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_DECODED_SIGNED_ENTRY_BYTE_LENGTH_MAPPING_MUTANT)
mutateDecodedEntryByteLength family = family == DecodedSignedEntry
#elif defined(VALIDATION_SOURCE_ACQUISITION_DECODED_EXPECTED_ENTRY_BYTE_LENGTH_MAPPING_MUTANT)
mutateDecodedEntryByteLength family = family == DecodedExpectedEntry
#else
mutateDecodedEntryByteLength family = family `seq` False
#endif

admitExpectedObjectFormatSha1Tag :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_OBJECT_FORMAT_SHA1_TAG_REMOVAL_MUTANT)
admitExpectedObjectFormatSha1Tag = False
#else
admitExpectedObjectFormatSha1Tag = True
#endif

admitExpectedObjectFormatSha256Tag :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_OBJECT_FORMAT_SHA256_TAG_REMOVAL_MUTANT)
admitExpectedObjectFormatSha256Tag = False
#else
admitExpectedObjectFormatSha256Tag = True
#endif

admitExpectedEntryModeRegularTag :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_MODE_REGULAR_TAG_REMOVAL_MUTANT)
admitExpectedEntryModeRegularTag = False
#else
admitExpectedEntryModeRegularTag = True
#endif

admitExpectedEntryModeExecutableTag :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_MODE_EXECUTABLE_TAG_REMOVAL_MUTANT)
admitExpectedEntryModeExecutableTag = False
#else
admitExpectedEntryModeExecutableTag = True
#endif

admitExpectedEntryModeSymbolicLinkTag :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_MODE_SYMBOLIC_LINK_TAG_REMOVAL_MUTANT)
admitExpectedEntryModeSymbolicLinkTag = False
#else
admitExpectedEntryModeSymbolicLinkTag = True
#endif

custodyTag :: SourceAcquisitionCustody -> Word8
#if defined(VALIDATION_SOURCE_ACQUISITION_CUSTODY_TAG_FROZEN_ENCODING_MUTANT)
custodyTag ExternallyFrozenReadOnlyBundle = 0
#else
custodyTag ExternallyFrozenReadOnlyBundle = 1
#endif
#if defined(VALIDATION_SOURCE_ACQUISITION_CUSTODY_TAG_MUTABLE_ENCODING_MUTANT)
custodyTag SequentialMutableBundle = 0
#else
custodyTag SequentialMutableBundle = 2
#endif

objectFormatTag :: GitObjectFormat -> Word8
#if defined(VALIDATION_SOURCE_ACQUISITION_OBJECT_FORMAT_TAG_SHA1_ENCODING_MUTANT)
objectFormatTag GitObjectSha1 = 0
#else
objectFormatTag GitObjectSha1 = 1
#endif
#if defined(VALIDATION_SOURCE_ACQUISITION_OBJECT_FORMAT_TAG_SHA256_ENCODING_MUTANT)
objectFormatTag GitObjectSha256 = 0
#else
objectFormatTag GitObjectSha256 = 2
#endif

modeTag :: IndexMode -> Word8
#if defined(VALIDATION_SOURCE_ACQUISITION_MODE_TAG_REGULAR_ENCODING_MUTANT)
modeTag RegularFile = 0
#else
modeTag RegularFile = 1
#endif
#if defined(VALIDATION_SOURCE_ACQUISITION_MODE_TAG_EXECUTABLE_ENCODING_MUTANT)
modeTag ExecutableFile = 0
#else
modeTag ExecutableFile = 2
#endif
#if defined(VALIDATION_SOURCE_ACQUISITION_MODE_TAG_SYMBOLIC_LINK_ENCODING_MUTANT)
modeTag SymbolicLink = 0
#else
modeTag SymbolicLink = 3
#endif

verifySourceAcquisitionDiagnostic
  :: SourceAcquisitionExpectation
  -> ByteString
  -> ByteString
  -> ByteString
  -> ByteString
  -> Either [SourceAcquisitionProblem] SourceAcquisitionManifest
verifySourceAcquisitionDiagnostic expected expectedManifestBytes publicKeyBytes wire bundle = do
  case boundedIntegrityProblems (expectationIngressProblems expected) of
    [] -> pure ()
    problems -> Left problems
  (signedPrefix, payload, signatureBytes) <- case splitSignedSourceAcquisition wire of
    Left problem -> Left [problem]
    Right value -> Right value
  if not (bundleWithinByteLimit (ByteString.length bundle))
    then Left [SourceAcquisitionBundleTooLarge (ByteString.length bundle)]
    else pure ()
  manifest <- case
      authenticateAndDecode
        publicKeyBytes
        wire
        (routedSignedPrefix signedPrefix)
        (routedPayload payload)
        (routedSignature signatureBytes) of
    Left problem -> Left [problem]
    Right value -> Right value
  expectedManifest <- case decodeExpectedManifest expectedManifestBytes of
    Left problem -> Left [problem]
    Right value -> Right value
  let problems =
        normalizeManifestProblems
          (manifestProblems expected expectedManifest manifest bundle)
  if manifestProblemsPermitSuccess problems then Right manifest else Left problems

-- | Verify an externally anchored session and mint the sole ordinary-build
-- acquired snapshot. This function confers no promotion authority: it only
-- converts a successfully authenticated, independently joined immutable
-- source bundle into the opaque input required by the closed dispatcher.
--
-- The conversion deliberately repeats the bundle split, every Git-blob and
-- SHA-256 content check, and the source-snapshot identity computation after
-- the protocol verifier succeeds. This keeps the constructor sink defensive
-- against a future verifier refactor that accidentally returns a manifest
-- without retaining its exact byte association.
acquireExternallyVerifiedSourceSnapshot
  :: AnchoredSourceAcquisitionSession
  -> ByteString
  -> ByteString
  -> Either CheckResult AcquiredSourceSnapshot
acquireExternallyVerifiedSourceSnapshot session wire bundle =
  acquireExternallyVerifiedSourceSnapshotFromIngress
    session
    (anchoredSourceAcquisitionExpectedManifestBytes session)
    wire
    bundle

-- | Verify the independently streamed expected-manifest bytes against the
-- exact bytes anchored in the session before they enter the verifier. This is
-- the production composition used by the bounded-ingress pipeline; the
-- retained three-argument wrapper above preserves the already-qualified
-- direct handoff without creating a second acceptance path.
acquireExternallyVerifiedSourceSnapshotFromIngress
  :: AnchoredSourceAcquisitionSession
  -> ByteString
  -> ByteString
  -> ByteString
  -> Either CheckResult AcquiredSourceSnapshot
acquireExternallyVerifiedSourceSnapshotFromIngress session expectedManifestBytes wire bundle =
  acquireExternallyVerifiedSourceSnapshotFromIngressCore
      session
      Nothing
      expectedManifestBytes
      wire
      bundle

-- | Production supervisor route. The supervisor atomically reserves the
-- declared replay identity before calling this function; the authenticated
-- manifest must carry that exact identity before acquired construction.
acquireExternallyVerifiedSourceSnapshotFromReservedIngress
  :: AnchoredSourceAcquisitionSession
  -> Text
  -> ByteString
  -> ByteString
  -> ByteString
  -> Either CheckResult AcquiredSourceSnapshot
acquireExternallyVerifiedSourceSnapshotFromReservedIngress session reservedReplayIdentity expectedManifestBytes wire bundle =
  acquireExternallyVerifiedSourceSnapshotFromIngressCore
    session
    (Just reservedReplayIdentity)
    expectedManifestBytes
    wire
    bundle

acquireExternallyVerifiedSourceSnapshotFromIngressCore
  :: AnchoredSourceAcquisitionSession
  -> Maybe Text
  -> ByteString
  -> ByteString
  -> ByteString
  -> Either CheckResult AcquiredSourceSnapshot
acquireExternallyVerifiedSourceSnapshotFromIngressCore session reservedReplayIdentity expectedManifestBytes wire bundle
  | not
      ( anchoredExpectedManifestTransportMatches
          (anchoredSourceAcquisitionExpectedManifestBytes session)
          expectedManifestBytes
      ) =
      Left
        ( sourceAcquisitionIntegrityFailure
            [ SourceAcquisitionExpectedManifestMalformed
                "streamed expected-manifest bytes differ from the externally anchored session"
            ]
        )
  | otherwise =
      case
          verifySourceAcquisitionDiagnostic
            (anchoredSourceAcquisitionExpectation session)
            expectedManifestBytes
            (anchoredSourceAcquisitionPublicKeyBytes session)
            (anchoredAcquisitionWireBytes wire)
            (anchoredAcquisitionBundleBytes bundle) of
        Left problems -> anchoredVerificationFailure problems
        Right manifest
          | not
              ( anchoredReservedReplayIdentityMatches
                  reservedReplayIdentity
                  (acquisitionReplayIdentity manifest)
              ) ->
              anchoredVerificationFailure
                [ SourceAcquisitionReplayIdentityMalformed
                    "reserved replay identity differs from the signed replay identity"
                ]
          | otherwise ->
              anchoredVerificationSuccess
                manifest
                (anchoredAcquisitionBundleBytes bundle)

anchoredExpectedManifestTransportMatches :: ByteString -> ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_ANCHORED_EXPECTED_MANIFEST_TRANSPORT_JOIN_BYPASS_MUTANT)
anchoredExpectedManifestTransportMatches _ _ = True
#else
anchoredExpectedManifestTransportMatches expected actual = expected == actual
#endif

anchoredReservedReplayIdentityMatches :: Maybe Text -> Text -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_ANCHORED_RESERVED_REPLAY_IDENTITY_JOIN_BYPASS_MUTANT)
anchoredReservedReplayIdentityMatches _ _ = True
#else
anchoredReservedReplayIdentityMatches reserved signedIdentity = case reserved of
  Nothing -> True
  Just expected -> expected == signedIdentity
#endif

anchoredVerificationSuccess
  :: SourceAcquisitionManifest
  -> ByteString
  -> Either CheckResult AcquiredSourceSnapshot
#if defined(VALIDATION_SOURCE_ACQUISITION_ANCHORED_VERIFICATION_SUCCESS_ROUTE_MUTANT)
anchoredVerificationSuccess manifest bundle =
  manifest `seq` bundle `seq`
    Left (sourceAcquisitionIntegrityFailure [SourceAcquisitionSignatureInvalid])
#else
anchoredVerificationSuccess manifest bundle =
  case acquiredTrackedEntries manifest bundle of
    Left problems -> Left (sourceAcquisitionIntegrityFailure problems)
    Right trackedEntries ->
      finalizeAcquiredSourceSnapshot
        (acquisitionObjectFormat manifest)
        (acquisitionRepositoryIdentity manifest)
        (acquisitionSourceSnapshotIdentity manifest)
        trackedEntries
#endif

anchoredAcquisitionWireBytes :: ByteString -> ByteString
#if defined(VALIDATION_SOURCE_ACQUISITION_ANCHORED_WIRE_ROUTE_MUTANT)
anchoredAcquisitionWireBytes = ByteString.drop 1
#else
anchoredAcquisitionWireBytes = id
#endif

anchoredAcquisitionBundleBytes :: ByteString -> ByteString
#if defined(VALIDATION_SOURCE_ACQUISITION_ANCHORED_BUNDLE_ROUTE_MUTANT)
anchoredAcquisitionBundleBytes bytes = bytes <> "mutated"
#else
anchoredAcquisitionBundleBytes = id
#endif

anchoredVerificationFailure
  :: [SourceAcquisitionProblem]
  -> Either CheckResult AcquiredSourceSnapshot
#if defined(VALIDATION_SOURCE_ACQUISITION_ANCHORED_VERIFICATION_REFUSAL_BYPASS_MUTANT)
anchoredVerificationFailure problems =
  problems `seq`
    Right
      ( AcquiredSourceSnapshot
          SourceSnapshot
            { snapshotRoot = "<unverified-source-acquisition-mutant>"
            , snapshotIdentity = Text.replicate 64 "0"
            , snapshotEntries = []
            }
      )
#else
anchoredVerificationFailure = Left . sourceAcquisitionIntegrityFailure
#endif

finalizeAcquiredSourceSnapshot
  :: GitObjectFormat
  -> Text
  -> Text
  -> [TrackedEntry]
  -> Either CheckResult AcquiredSourceSnapshot
finalizeAcquiredSourceSnapshot objectFormat repositoryIdentity expectedIdentity entries =
  let routedEntries = handoffTrackedEntryOrder entries
      computedIdentity =
        computeSourceSnapshotIdentity
          (handoffObjectFormat objectFormat)
          routedEntries
   in if not (handoffIdentityAccepted expectedIdentity computedIdentity)
        then
          Left
            ( sourceAcquisitionIntegrityFailure
                [ SourceAcquisitionSourceSnapshotIdentityMismatch
                    expectedIdentity
                    computedIdentity
                ]
            )
        else
          Right
            ( AcquiredSourceSnapshot
                SourceSnapshot
                  { snapshotRoot = handoffSnapshotRoot repositoryIdentity
                  , snapshotIdentity = handoffSnapshotIdentity computedIdentity
                  , snapshotEntries = handoffSnapshotEntries routedEntries
                  }
            )

#if defined(VALIDATION_SOURCE_ACQUISITION_INTERNAL_TEST_HOOKS)
-- Direct-source oracle hook. It is absent from the packaged library build and
-- cannot construct a session or bypass the final identity join.
sourceAcquisitionInternalTestFinalize
  :: GitObjectFormat
  -> Text
  -> Text
  -> [TrackedEntry]
  -> Either CheckResult AcquiredSourceSnapshot
sourceAcquisitionInternalTestFinalize = finalizeAcquiredSourceSnapshot

sourceAcquisitionInternalTestTrackedEntries
  :: [(FilePath, IndexMode, Text, Word64, Text)]
  -> ByteString
  -> Either CheckResult [TrackedEntry]
sourceAcquisitionInternalTestTrackedEntries tuples bundle =
  case acquiredTrackedEntriesFor (map testEntry tuples) bundle of
    Left problems -> Left (sourceAcquisitionIntegrityFailure problems)
    Right entries -> Right entries
 where
  testEntry (path, mode, objectId, byteLength, blobSha256) =
    SourceAcquisitionEntry
      { acquisitionEntryPath = path
      , acquisitionEntryMode = mode
      , acquisitionEntryGitObjectId = objectId
      , acquisitionEntryByteLength = byteLength
      , acquisitionEntryBlobSha256 = blobSha256
      }
#endif

handoffObjectFormat :: GitObjectFormat -> GitObjectFormat
#if defined(VALIDATION_SOURCE_ACQUISITION_HANDOFF_OBJECT_FORMAT_MAPPING_MUTANT)
handoffObjectFormat GitObjectSha1 = GitObjectSha256
handoffObjectFormat GitObjectSha256 = GitObjectSha1
#else
handoffObjectFormat = id
#endif

handoffTrackedEntryOrder :: [TrackedEntry] -> [TrackedEntry]
#if defined(VALIDATION_SOURCE_ACQUISITION_HANDOFF_ENTRY_ORDER_MUTANT)
handoffTrackedEntryOrder = reverse
#else
handoffTrackedEntryOrder = id
#endif

handoffIdentityAccepted :: Text -> Text -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_HANDOFF_IDENTITY_JOIN_BYPASS_MUTANT)
handoffIdentityAccepted _ _ = True
#else
handoffIdentityAccepted expected actual = expected == actual
#endif

handoffSnapshotRoot :: Text -> FilePath
#if defined(VALIDATION_SOURCE_ACQUISITION_HANDOFF_SNAPSHOT_ROOT_MAPPING_MUTANT)
handoffSnapshotRoot repositoryIdentity = repositoryIdentity `seq` "<mutated-source-root>"
#else
handoffSnapshotRoot repositoryIdentity =
  "<externally-frozen-source-bundle:"
    <> Text.unpack repositoryIdentity
    <> ">"
#endif

handoffSnapshotIdentity :: Text -> Text
#if defined(VALIDATION_SOURCE_ACQUISITION_HANDOFF_SNAPSHOT_IDENTITY_MAPPING_MUTANT)
handoffSnapshotIdentity value = value <> "mutated"
#else
handoffSnapshotIdentity = id
#endif

handoffSnapshotEntries :: [TrackedEntry] -> [TrackedEntry]
#if defined(VALIDATION_SOURCE_ACQUISITION_HANDOFF_SNAPSHOT_ENTRIES_MAPPING_MUTANT)
handoffSnapshotEntries = drop 1
#else
handoffSnapshotEntries = id
#endif

acquiredTrackedEntries
  :: SourceAcquisitionManifest
  -> ByteString
  -> Either [SourceAcquisitionProblem] [TrackedEntry]
acquiredTrackedEntries manifest = acquiredTrackedEntriesFor (acquisitionEntries manifest)

acquiredTrackedEntriesFor
  :: [SourceAcquisitionEntry]
  -> ByteString
  -> Either [SourceAcquisitionProblem] [TrackedEntry]
acquiredTrackedEntriesFor entries bundle = do
  members <- case splitBundle entries bundle of
    Left problem -> handoffSplitFailure problem
    Right values -> Right (handoffSplitMembers values)
  let associated = zip entries (handoffContentMembers members)
      contentProblems =
        concatMap
          (uncurry entryContentProblems)
          associated
  if handoffContentProblemsPermitSuccess contentProblems
    then Right (map (uncurry acquisitionTrackedEntry) (handoffConstructionAssociations associated))
    else Left (normalizeManifestProblems contentProblems)

handoffSplitFailure
  :: SourceAcquisitionProblem
  -> Either [SourceAcquisitionProblem] [ByteString]
#if defined(VALIDATION_SOURCE_ACQUISITION_HANDOFF_SPLIT_FAILURE_BYPASS_MUTANT)
handoffSplitFailure problem = problem `seq` Right []
#else
handoffSplitFailure problem = Left [problem]
#endif

handoffSplitMembers :: [ByteString] -> [ByteString]
#if defined(VALIDATION_SOURCE_ACQUISITION_HANDOFF_SPLIT_SUCCESS_ROUTE_MUTANT)
handoffSplitMembers = drop 1
#else
handoffSplitMembers = id
#endif

handoffContentProblemsPermitSuccess :: [SourceAcquisitionProblem] -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_HANDOFF_CONTENT_PROBLEM_BYPASS_MUTANT)
handoffContentProblemsPermitSuccess _ = True
#else
handoffContentProblemsPermitSuccess = null
#endif

handoffContentMembers :: [ByteString] -> [ByteString]
#if defined(VALIDATION_SOURCE_ACQUISITION_HANDOFF_CONTENT_ASSOCIATION_MUTANT)
handoffContentMembers = reverse
#else
handoffContentMembers = id
#endif

handoffConstructionAssociations
  :: [(SourceAcquisitionEntry, ByteString)]
  -> [(SourceAcquisitionEntry, ByteString)]
#if defined(VALIDATION_SOURCE_ACQUISITION_HANDOFF_CONSTRUCTION_ORDER_MUTANT)
handoffConstructionAssociations = reverse
#else
handoffConstructionAssociations = id
#endif

acquisitionTrackedEntry :: SourceAcquisitionEntry -> ByteString -> TrackedEntry
acquisitionTrackedEntry entry bytes =
  TrackedEntry
    { trackedIndex =
        IndexEntry
          { indexPath = handoffEntryPath (acquisitionEntryPath entry)
          , indexMode = handoffEntryMode (acquisitionEntryMode entry)
          , indexObjectId = handoffEntryObjectId (acquisitionEntryGitObjectId entry)
          }
    , trackedBytes = handoffEntryBytes bytes
    }

handoffEntryPath :: FilePath -> FilePath
#if defined(VALIDATION_SOURCE_ACQUISITION_HANDOFF_ENTRY_PATH_MAPPING_MUTANT)
handoffEntryPath value = value <> "-mutated"
#else
handoffEntryPath = id
#endif

handoffEntryMode :: IndexMode -> IndexMode
#if defined(VALIDATION_SOURCE_ACQUISITION_HANDOFF_ENTRY_MODE_MAPPING_MUTANT)
handoffEntryMode RegularFile = ExecutableFile
handoffEntryMode ExecutableFile = SymbolicLink
handoffEntryMode SymbolicLink = RegularFile
#else
handoffEntryMode = id
#endif

handoffEntryObjectId :: Text -> Text
#if defined(VALIDATION_SOURCE_ACQUISITION_HANDOFF_ENTRY_OBJECT_MAPPING_MUTANT)
handoffEntryObjectId value = value <> "0"
#else
handoffEntryObjectId = id
#endif

handoffEntryBytes :: ByteString -> ByteString
#if defined(VALIDATION_SOURCE_ACQUISITION_HANDOFF_ENTRY_BYTES_MAPPING_MUTANT)
handoffEntryBytes = ByteString.drop 1
#else
handoffEntryBytes = id
#endif

sourceAcquisitionIntegrityFailure :: [SourceAcquisitionProblem] -> CheckResult
sourceAcquisitionIntegrityFailure problems =
  CheckResult
    { checkName = "source-acquisition"
    , checkObservations =
        [ observation
            "source-acquisition.integrity"
            ( "refused with "
                <> showText (length boundedProblems)
                <> " integrity finding(s)"
            )
        ]
    , checkFindings = map problemFinding boundedProblems
    }
 where
  boundedProblems = boundedResultProblems (normalizeManifestProblems problems)

routedSignedPrefix :: ByteString -> ByteString
#if defined(VALIDATION_SOURCE_ACQUISITION_SIGNED_PREFIX_ROUTE_MUTANT)
routedSignedPrefix = ByteString.drop 1
#else
routedSignedPrefix = id
#endif

routedPayload :: ByteString -> ByteString
#if defined(VALIDATION_SOURCE_ACQUISITION_PAYLOAD_ROUTE_MUTANT)
routedPayload = ByteString.drop 1
#else
routedPayload = id
#endif

routedSignature :: ByteString -> ByteString
#if defined(VALIDATION_SOURCE_ACQUISITION_SIGNATURE_ROUTE_MUTANT)
routedSignature bytes = bytes <> "mutated"
#else
routedSignature = id
#endif

normalizeManifestProblems :: [SourceAcquisitionProblem] -> [SourceAcquisitionProblem]
#if defined(VALIDATION_SOURCE_ACQUISITION_PROBLEM_DEDUPLICATION_BYPASS_MUTANT)
normalizeManifestProblems problems = case boundedIntegrityProblems problems of
  limited@[SourceAcquisitionProblemLimitExceeded _ _] -> limited
  retained -> retained
#elif defined(VALIDATION_SOURCE_ACQUISITION_PROBLEM_SORT_ORDER_MUTANT)
normalizeManifestProblems problems = case boundedIntegrityProblems problems of
  limited@[SourceAcquisitionProblemLimitExceeded _ _] -> limited
  retained -> reverse (Set.toAscList (Set.fromList retained))
#else
normalizeManifestProblems problems = case boundedIntegrityProblems problems of
  limited@[SourceAcquisitionProblemLimitExceeded _ _] -> limited
  retained -> Set.toAscList (Set.fromList retained)
#endif

boundedIntegrityProblems
  :: [SourceAcquisitionProblem]
  -> [SourceAcquisitionProblem]
boundedIntegrityProblems problems
  | observedAtLeast > maximumIntegrityProblems =
      [SourceAcquisitionProblemLimitExceeded maximumIntegrityProblems observedAtLeast]
  | otherwise = prefix
 where
  prefix = take (maximumIntegrityProblems + 1) problems
  observedAtLeast = length prefix

manifestProblemsPermitSuccess :: [SourceAcquisitionProblem] -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_PROBLEM_ACCEPTANCE_BYPASS_MUTANT)
manifestProblemsPermitSuccess problems = problems `seq` True
#else
manifestProblemsPermitSuccess = null
#endif

expectationIngressProblems
  :: SourceAcquisitionExpectation
  -> [SourceAcquisitionProblem]
expectationIngressProblems expected =
  concatMap boundedTextProblem boundedValues
    <> replaySetProblems
 where
  boundedValues =
    [ ("phase", maximumExpectedPhaseBytes, expectedAcquisitionPhase expected)
    | retainExpectedPhaseLimit
    ]
      <> [ ("authority", maximumExpectedAuthorityBytes, expectedAcquisitionAuthority expected)
         | retainExpectedAuthorityLimit
         ]
      <> [ ("observer-tool-digest", maximumExpectedObserverToolDigestBytes, expectedAcquisitionObserverToolDigest expected)
         | retainExpectedObserverToolDigestLimit
         ]
      <> [ ("challenge", maximumExpectedChallengeBytes, expectedAcquisitionChallenge expected)
         | retainExpectedChallengeLimit
         ]
      <> [ ("repository-identity", maximumExpectedRepositoryIdentityBytes, expectedAcquisitionRepositoryIdentity expected)
         | retainExpectedRepositoryIdentityLimit
         ]
      <> [ ("requested-revision", maximumExpectedRequestedRevisionBytes, expectedAcquisitionRequestedRevision expected)
         | retainExpectedRequestedRevisionLimit
         ]
      <> [ ("head-identity", maximumExpectedHeadIdentityBytes, expectedAcquisitionHeadIdentity expected)
         | retainExpectedHeadIdentityLimit
         ]
      <> [ ("source-snapshot-identity", maximumExpectedSourceSnapshotIdentityBytes, expectedAcquisitionSourceSnapshotIdentity expected)
         | retainExpectedSourceSnapshotIdentityLimit
         ]
      <> [ ("authored-root-identity", maximumExpectedAuthoredRootIdentityBytes, expectedAcquisitionAuthoredRootIdentity expected)
         | retainExpectedAuthoredRootIdentityLimit
         ]
  boundedTextProblem (label, maximumBytes, value) =
    let observedPrefixBytes = boundedUtf8PrefixLength maximumBytes value
     in [ SourceAcquisitionExpectationValueTooLarge label observedPrefixBytes maximumBytes
        | observedPrefixBytes > maximumBytes
        ]
  replayValues = Set.toAscList (consumedAcquisitionReplayIdentities expected)
  replayCount = Set.size (consumedAcquisitionReplayIdentities expected)
  replaySetProblems
    | not (replaySetWithinCountLimit replayCount) =
        [SourceAcquisitionReplaySetTooLarge replayCount maximumConsumedReplayIdentities]
    | otherwise =
        [ SourceAcquisitionReplaySetEntryTooLarge index observedPrefixBytes maximumConsumedReplayIdentityBytes
        | (index, value) <- zip [0 :: Int ..] replayValues
        , let observedPrefixBytes = boundedUtf8PrefixLength maximumConsumedReplayIdentityBytes value
        , not (replayIdentityWithinByteLimit observedPrefixBytes)
        ]

retainExpectedPhaseLimit :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_PHASE_BYTE_LIMIT_BYPASS_MUTANT)
retainExpectedPhaseLimit = False
#else
retainExpectedPhaseLimit = True
#endif

retainExpectedAuthorityLimit :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_AUTHORITY_BYTE_LIMIT_BYPASS_MUTANT)
retainExpectedAuthorityLimit = False
#else
retainExpectedAuthorityLimit = True
#endif

retainExpectedObserverToolDigestLimit :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_OBSERVER_TOOL_DIGEST_BYTE_LIMIT_BYPASS_MUTANT)
retainExpectedObserverToolDigestLimit = False
#else
retainExpectedObserverToolDigestLimit = True
#endif

retainExpectedChallengeLimit :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_CHALLENGE_BYTE_LIMIT_BYPASS_MUTANT)
retainExpectedChallengeLimit = False
#else
retainExpectedChallengeLimit = True
#endif

retainExpectedRepositoryIdentityLimit :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_REPOSITORY_IDENTITY_BYTE_LIMIT_BYPASS_MUTANT)
retainExpectedRepositoryIdentityLimit = False
#else
retainExpectedRepositoryIdentityLimit = True
#endif

retainExpectedRequestedRevisionLimit :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_REQUESTED_REVISION_BYTE_LIMIT_BYPASS_MUTANT)
retainExpectedRequestedRevisionLimit = False
#else
retainExpectedRequestedRevisionLimit = True
#endif

retainExpectedHeadIdentityLimit :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_HEAD_IDENTITY_BYTE_LIMIT_BYPASS_MUTANT)
retainExpectedHeadIdentityLimit = False
#else
retainExpectedHeadIdentityLimit = True
#endif

retainExpectedSourceSnapshotIdentityLimit :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_SOURCE_SNAPSHOT_IDENTITY_BYTE_LIMIT_BYPASS_MUTANT)
retainExpectedSourceSnapshotIdentityLimit = False
#else
retainExpectedSourceSnapshotIdentityLimit = True
#endif

retainExpectedAuthoredRootIdentityLimit :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_AUTHORED_ROOT_IDENTITY_BYTE_LIMIT_BYPASS_MUTANT)
retainExpectedAuthoredRootIdentityLimit = False
#else
retainExpectedAuthoredRootIdentityLimit = True
#endif

replaySetWithinCountLimit :: Int -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_REPLAY_SET_COUNT_LIMIT_BYPASS_MUTANT)
replaySetWithinCountLimit _ = True
#else
replaySetWithinCountLimit observed = observed <= maximumConsumedReplayIdentities
#endif

replayIdentityWithinByteLimit :: Int -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_REPLAY_IDENTITY_BYTE_LIMIT_BYPASS_MUTANT)
replayIdentityWithinByteLimit _ = True
#else
replayIdentityWithinByteLimit observed = observed <= maximumConsumedReplayIdentityBytes
#endif

boundedUtf8PrefixLength :: Int -> Text -> Int
#if defined(VALIDATION_SOURCE_ACQUISITION_BOUNDED_UTF8_BYTE_MEASUREMENT_MUTANT)
boundedUtf8PrefixLength maximumBytes =
  Text.length . Text.take (maximumBytes + 1)
#else
boundedUtf8PrefixLength maximumBytes =
  ByteString.length
    . TextEncoding.encodeUtf8
    . Text.take (maximumBytes + 1)
#endif

-- This is the sole payload decoder entry point. Framing and strict ingress
-- limits have already been checked, but no payload field is interpreted until
-- the signature over those exact bytes succeeds. Re-encoding then establishes
-- that the authenticated bytes have exactly one admitted representation.
authenticateAndDecode
  :: ByteString
  -> ByteString
  -> ByteString
  -> ByteString
  -> ByteString
  -> Either SourceAcquisitionProblem SourceAcquisitionManifest
authenticateAndDecode publicKeyBytes wire signedPrefix payload signatureBytes = do
#if defined(VALIDATION_SOURCE_ACQUISITION_PREDECODE_MUTANT)
  manifest <- decodeManifest payload
  verifyRawEnvelopeSignature publicKeyBytes signedPrefix signatureBytes
#else
  verifyRawEnvelopeSignature publicKeyBytes signedPrefix signatureBytes
  manifest <- decodeManifest payload
#endif
#if defined(VALIDATION_SOURCE_ACQUISITION_CANONICALITY_BYPASS_MUTANT)
  if canonicalEnvelopeBytes manifest signatureBytes == wire
    then Right manifest
    else Right manifest
#else
  if canonicalEnvelopeBytes manifest signatureBytes == wire
    then Right manifest
    else Left SourceAcquisitionWireNonCanonical
#endif

manifestProblems
  :: SourceAcquisitionExpectation
  -> SourceAcquisitionExpectedManifest
  -> SourceAcquisitionManifest
  -> ByteString
  -> [SourceAcquisitionProblem]
manifestProblems expected expectedManifest manifest bundle =
  structuralProblems
  <> if structuralRouteAllowsContentChecks structuralProblems
      then bundleProblems <> treeProblems <> commitProblems <> expectedManifestJoinProblems <> derivedIdentityProblems
      else []
 where
  phase = acquisitionPhase manifest
  authority = acquisitionAuthority manifest
  observerDigest = acquisitionObserverToolDigest manifest
  challenge = acquisitionChallenge manifest
  replayIdentity = acquisitionReplayIdentity manifest
  repositoryIdentity = acquisitionRepositoryIdentity manifest
  requestedRevision = acquisitionRequestedRevision manifest
  objectFormat = acquisitionObjectFormat manifest
  entries = acquisitionEntries manifest
  paths = map acquisitionEntryPath entries
  expectationProblems =
    [SourceAcquisitionPhaseMalformed phase | not (phaseText phase)]
#if !defined(VALIDATION_SOURCE_ACQUISITION_PHASE_JOIN_BYPASS_MUTANT)
      <> [ SourceAcquisitionPhaseMismatch (expectedAcquisitionPhase expected) phase
         | phase /= expectedAcquisitionPhase expected
         ]
#endif
      <> [SourceAcquisitionAuthorityMalformed authority | not (authorityText authority)]
#if !defined(VALIDATION_SOURCE_ACQUISITION_AUTHORITY_JOIN_BYPASS_MUTANT)
      <> [ SourceAcquisitionAuthorityMismatch (expectedAcquisitionAuthority expected) authority
         | authority /= expectedAcquisitionAuthority expected
         ]
#endif
      <> [SourceAcquisitionObserverToolDigestMalformed observerDigest | not (sha256Text observerDigest)]
#if !defined(VALIDATION_SOURCE_ACQUISITION_OBSERVER_JOIN_BYPASS_MUTANT)
      <> [ SourceAcquisitionObserverToolMismatch (expectedAcquisitionObserverToolDigest expected) observerDigest
         | observerDigest /= expectedAcquisitionObserverToolDigest expected
         ]
#endif
      <> [SourceAcquisitionChallengeMalformed challenge | not (sha256Text challenge)]
#if !defined(VALIDATION_SOURCE_ACQUISITION_CHALLENGE_JOIN_BYPASS_MUTANT)
      <> [ SourceAcquisitionChallengeMismatch (expectedAcquisitionChallenge expected) challenge
         | challenge /= expectedAcquisitionChallenge expected
         ]
#endif
      <> [SourceAcquisitionReplayIdentityMalformed replayIdentity | not (sha256Text replayIdentity)]
#if !defined(VALIDATION_SOURCE_ACQUISITION_REPLAY_BYPASS_MUTANT)
      <> [ SourceAcquisitionReplayDetected replayIdentity
         | replayIdentity `Set.member` consumedAcquisitionReplayIdentities expected
         ]
#endif
      <> [SourceAcquisitionRepositoryIdentityMalformed repositoryIdentity | not (sha256Text repositoryIdentity)]
#if !defined(VALIDATION_SOURCE_ACQUISITION_REPOSITORY_JOIN_BYPASS_MUTANT)
      <> [ SourceAcquisitionRepositoryIdentityMismatch (expectedAcquisitionRepositoryIdentity expected) repositoryIdentity
         | repositoryIdentity /= expectedAcquisitionRepositoryIdentity expected
         ]
#endif
      <> [SourceAcquisitionRequestedRevisionMalformed requestedRevision | not (requestedRevisionText requestedRevision)]
#if !defined(VALIDATION_SOURCE_ACQUISITION_REVISION_JOIN_BYPASS_MUTANT)
      <> [ SourceAcquisitionRequestedRevisionMismatch (expectedAcquisitionRequestedRevision expected) requestedRevision
         | requestedRevision /= expectedAcquisitionRequestedRevision expected
         ]
#endif
#if !defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_HEAD_JOIN_BYPASS_MUTANT)
      <> [ SourceAcquisitionExpectedHeadIdentityMismatch (expectedAcquisitionHeadIdentity expected) (acquisitionHeadIdentity manifest)
         | acquisitionHeadIdentity manifest /= expectedAcquisitionHeadIdentity expected
         ]
#endif
#if !defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_SOURCE_SNAPSHOT_JOIN_BYPASS_MUTANT)
      <> [ SourceAcquisitionExpectedSourceSnapshotIdentityMismatch
             (expectedAcquisitionSourceSnapshotIdentity expected)
             (acquisitionSourceSnapshotIdentity manifest)
         | acquisitionSourceSnapshotIdentity manifest /= expectedAcquisitionSourceSnapshotIdentity expected
         ]
#endif
#if !defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_AUTHORED_ROOT_JOIN_BYPASS_MUTANT)
      <> [ SourceAcquisitionAuthoredRootIdentityMismatch
             (expectedAcquisitionAuthoredRootIdentity expected)
             (acquisitionAuthoredRootIdentity manifest)
         | acquisitionAuthoredRootIdentity manifest /= expectedAcquisitionAuthoredRootIdentity expected
         ]
#endif
  identityShapeProblems =
    [SourceAcquisitionHeadIdentityMalformed objectFormat (acquisitionHeadIdentity manifest) | not (gitObjectText objectFormat (acquisitionHeadIdentity manifest))]
      <> [SourceAcquisitionTreeIdentityMalformed objectFormat (acquisitionTreeIdentity manifest) | not (gitObjectText objectFormat (acquisitionTreeIdentity manifest))]
      <> [SourceAcquisitionAuthoredRootIdentityMalformed (acquisitionAuthoredRootIdentity manifest) | not (sha256Text (acquisitionAuthoredRootIdentity manifest))]
      <> [SourceAcquisitionFrozenSnapshotIdentityMalformed (acquisitionFrozenSnapshotIdentity manifest) | not (sha256Text (acquisitionFrozenSnapshotIdentity manifest))]
      <> [SourceAcquisitionBundleIdentityMalformed (acquisitionBundleIdentity manifest) | not (sha256Text (acquisitionBundleIdentity manifest))]
      <> [SourceAcquisitionSourceSnapshotIdentityMalformed (acquisitionSourceSnapshotIdentity manifest) | not (sha256Text (acquisitionSourceSnapshotIdentity manifest))]
  structuralProblems =
    expectationProblems
      <> identityShapeProblems
      <> inventoryProblems
      <> expectedManifestShapeProblems
      <> expectedManifestObjectFormatProblems
  inventoryProblems =
    custodyProblems
      <> [SourceAcquisitionManifestEmpty | not (manifestInventoryNonempty entries)]
      <> case manifestInventoryOrderViolation (zip pathBytes paths) of
        Nothing -> []
        Just (previous, current) ->
          [SourceAcquisitionManifestNotStrictlyOrdered previous current]
      <> [SourceAcquisitionManifestDuplicatePath path | path <- manifestInventoryDuplicatePaths paths]
      <> concatMap snd pathProblemPairs
      <> [ SourceAcquisitionManifestCaseFoldCollision first second
         | (first, second) <- manifestInventoryCaseFoldCollisions collisionEligiblePaths
         ]
      <> [SourceAcquisitionManifestPathConflict path | path <- manifestInventoryPrefixConflicts collisionEligiblePaths]
      <> concatMap (entryShapeProblems objectFormat) entries
  custodyProblems = case acquisitionCustody manifest of
    ExternallyFrozenReadOnlyBundle -> []
    SequentialMutableBundle ->
#if defined(VALIDATION_SOURCE_ACQUISITION_FROZEN_CUSTODY_BYPASS_MUTANT)
      []
#else
      [SourceAcquisitionCustodyUnsupported 2]
#endif
  pathBytes = map (TextEncoding.encodeUtf8 . Text.pack) paths
  pathProblemPairs = [(path, manifestPathProblems path) | path <- paths]
  collisionEligiblePaths = [path | (path, problems) <- pathProblemPairs, null problems]
  splitResult = splitBundle entries bundle
  bundleProblems =
    [ SourceAcquisitionBundleIdentityMismatch (acquisitionBundleIdentity manifest) actualBundleIdentity
    | retainBundleIdentityJoin
    , acquisitionBundleIdentity manifest /= actualBundleIdentity
    ]
      <> case splitResult of
        Left problem -> [problem]
        Right members -> concat (zipWith entryContentProblems entries (contentCheckMembers members))
  actualBundleIdentity = bundleSha256 bundle
  treeProblems =
#if defined(VALIDATION_SOURCE_ACQUISITION_TREE_IDENTITY_JOIN_BYPASS_MUTANT)
    case computeTreeIdentity objectFormat entries of
      Left problems -> problems
      Right _ -> []
#else
    case computeTreeIdentity objectFormat entries of
      Left problems -> problems
      Right actualTree ->
        [ SourceAcquisitionTreeIdentityMismatch (acquisitionTreeIdentity manifest) actualTree
        | acquisitionTreeIdentity manifest /= actualTree
        ]
#endif
  commitProblems = case parseCommitTree objectFormat (acquisitionCommitBytes manifest) of
    Left problem -> [problem]
    Right commitTree ->
      [ SourceAcquisitionCommitIdentityMismatch (acquisitionHeadIdentity manifest) actualCommitIdentity
      | retainCommitIdentityJoin
      , acquisitionHeadIdentity manifest /= actualCommitIdentity
      ]
        <> [ SourceAcquisitionCommitTreeMismatch (acquisitionTreeIdentity manifest) commitTree
           | retainCommitTreeJoin
           , acquisitionTreeIdentity manifest /= commitTree
           ]
  actualCommitIdentity = gitObjectIdentity objectFormat "commit" (acquisitionCommitBytes manifest)
  expectedManifestShapeProblems = validateExpectedManifest objectFormat expectedManifest
  expectedManifestObjectFormatProblems =
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_OBJECT_FORMAT_JOIN_BYPASS_MUTANT)
    []
#else
    [ SourceAcquisitionExpectedManifestObjectFormatMismatch
        (expectedManifestObjectFormat expectedManifest)
        objectFormat
    | expectedManifestObjectFormat expectedManifest /= objectFormat
    ]
#endif
  expectedManifestJoinProblems =
    compareExpectedManifestEntries
      (expectedManifestEntries expectedManifest)
      entries
  derivedIdentityProblems =
    [ SourceAcquisitionFrozenSnapshotIdentityMismatch
             (acquisitionFrozenSnapshotIdentity manifest)
             actualFrozenSnapshotIdentity
         | retainFrozenSnapshotIdentityJoin
         , acquisitionFrozenSnapshotIdentity manifest /= actualFrozenSnapshotIdentity
         ]
      <> case splitResult of
        Left _ -> []
        Right members ->
          let actualSourceIdentity =
                computeSourceSnapshotIdentity
                  objectFormat
                  (zipWith toTrackedEntry entries (sourceIdentityMembers members))
           in [ SourceAcquisitionSourceSnapshotIdentityMismatch
                  (acquisitionSourceSnapshotIdentity manifest)
                  actualSourceIdentity
              | retainSourceSnapshotIdentityJoin
              , acquisitionSourceSnapshotIdentity manifest /= actualSourceIdentity
              ]
  actualFrozenSnapshotIdentity = computeFrozenSnapshotIdentity manifest

retainBundleIdentityJoin :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_BUNDLE_IDENTITY_JOIN_BYPASS_MUTANT)
retainBundleIdentityJoin = False
#else
retainBundleIdentityJoin = True
#endif

retainCommitIdentityJoin :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_IDENTITY_JOIN_BYPASS_MUTANT)
retainCommitIdentityJoin = False
#else
retainCommitIdentityJoin = True
#endif

retainCommitTreeJoin :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_TREE_JOIN_BYPASS_MUTANT)
retainCommitTreeJoin = False
#else
retainCommitTreeJoin = True
#endif

retainFrozenSnapshotIdentityJoin :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_FROZEN_SNAPSHOT_IDENTITY_JOIN_BYPASS_MUTANT)
retainFrozenSnapshotIdentityJoin = False
#else
retainFrozenSnapshotIdentityJoin = True
#endif

retainSourceSnapshotIdentityJoin :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_SOURCE_SNAPSHOT_IDENTITY_JOIN_BYPASS_MUTANT)
retainSourceSnapshotIdentityJoin = False
#else
retainSourceSnapshotIdentityJoin = True
#endif

structuralRouteAllowsContentChecks :: [SourceAcquisitionProblem] -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_STRUCTURAL_ROUTING_BYPASS_MUTANT)
structuralRouteAllowsContentChecks _ = True
#else
structuralRouteAllowsContentChecks = null
#endif

manifestInventoryNonempty :: [SourceAcquisitionEntry] -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_EMPTY_BYPASS_MUTANT)
manifestInventoryNonempty _ = True
#else
manifestInventoryNonempty = not . null
#endif

manifestInventoryOrderViolation :: [(ByteString, FilePath)] -> Maybe (FilePath, FilePath)
#if defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_ORDER_BYPASS_MUTANT)
manifestInventoryOrderViolation _ = Nothing
#else
manifestInventoryOrderViolation = firstOrderViolation
#endif

manifestInventoryDuplicatePaths :: [FilePath] -> [FilePath]
#if defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_DUPLICATE_BYPASS_MUTANT)
manifestInventoryDuplicatePaths _ = []
#else
manifestInventoryDuplicatePaths = duplicateValues
#endif

manifestInventoryCaseFoldCollisions :: [FilePath] -> [(FilePath, FilePath)]
#if defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_CASE_COLLISION_BYPASS_MUTANT)
manifestInventoryCaseFoldCollisions _ = []
#else
manifestInventoryCaseFoldCollisions = caseFoldPathCollisions
#endif

manifestInventoryPrefixConflicts :: [FilePath] -> [FilePath]
#if defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_PREFIX_CONFLICT_BYPASS_MUTANT)
manifestInventoryPrefixConflicts _ = []
#else
manifestInventoryPrefixConflicts = prefixPathConflicts
#endif

entryShapeProblems :: GitObjectFormat -> SourceAcquisitionEntry -> [SourceAcquisitionProblem]
entryShapeProblems objectFormat entry =
  [ SourceAcquisitionEntryGitObjectFormatMismatch path objectFormat objectId
  | not (gitObjectText objectFormat objectId)
  ]
    <> [ SourceAcquisitionEntryBlobSha256Malformed path blobSha256
       | not (sha256Text blobSha256)
       ]
    <> [ SourceAcquisitionEntryTooLarge path (acquisitionEntryByteLength entry)
       | not (manifestEntryWithinByteLimit (acquisitionEntryByteLength entry))
       ]
 where
  path = acquisitionEntryPath entry
  objectId = acquisitionEntryGitObjectId entry
  blobSha256 = acquisitionEntryBlobSha256 entry

entryContentProblems :: SourceAcquisitionEntry -> ByteString -> [SourceAcquisitionProblem]
entryContentProblems entry bytes =
  ( case verifyBlobObjectId (acquisitionEntryGitObjectId entry) bytes of
      Left problem
        | retainBlobObjectIdentityJoin -> [SourceAcquisitionEntryGitObjectMismatch path problem]
        | otherwise -> []
      Right () -> []
  )
    <> [ SourceAcquisitionEntryBlobSha256Mismatch path (acquisitionEntryBlobSha256 entry) actualSha256
       | retainBlobSha256Join
       , acquisitionEntryBlobSha256 entry /= actualSha256
       ]
 where
  path = acquisitionEntryPath entry
  actualSha256 = computeBlobSha256 bytes

manifestEntryWithinByteLimit :: Word64 -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_ENTRY_BYTE_LIMIT_BYPASS_MUTANT)
manifestEntryWithinByteLimit _ = True
#else
manifestEntryWithinByteLimit observed = observed <= fromIntegral maximumBundleBytes
#endif

retainBlobObjectIdentityJoin :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_BLOB_OBJECT_IDENTITY_JOIN_BYPASS_MUTANT)
retainBlobObjectIdentityJoin = False
#else
retainBlobObjectIdentityJoin = True
#endif

retainBlobSha256Join :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_BLOB_SHA256_JOIN_BYPASS_MUTANT)
retainBlobSha256Join = False
#else
retainBlobSha256Join = True
#endif

validateExpectedManifest
  :: GitObjectFormat
  -> SourceAcquisitionExpectedManifest
  -> [SourceAcquisitionProblem]
validateExpectedManifest signedObjectFormat expectedManifest =
  [SourceAcquisitionExpectedManifestEmpty | not (expectedManifestInventoryNonempty entries)]
    <> case expectedManifestInventoryOrderViolation (zip pathBytes paths) of
      Nothing -> []
      Just (previous, current) ->
        [SourceAcquisitionExpectedManifestNotStrictlyOrdered previous current]
    <> [ SourceAcquisitionExpectedManifestDuplicatePath path
       | path <- expectedManifestInventoryDuplicatePaths paths
       ]
    <> concatMap expectedPathProblems paths
    <> [ SourceAcquisitionExpectedManifestCaseFoldCollision first second
       | (first, second) <- expectedManifestInventoryCaseFoldCollisions collisionEligiblePaths
       ]
    <> [ SourceAcquisitionExpectedManifestPathConflict path
       | path <- expectedManifestInventoryPrefixConflicts collisionEligiblePaths
       ]
    <> concatMap (expectedEntryShapeProblems signedObjectFormat) entries
 where
  entries = expectedManifestEntries expectedManifest
  paths = map acquisitionEntryPath entries
  pathBytes = map (TextEncoding.encodeUtf8 . Text.pack) paths
  collisionEligiblePaths = [path | path <- paths, null (manifestPathProblems path)]

expectedManifestInventoryNonempty :: [SourceAcquisitionEntry] -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_EMPTY_BYPASS_MUTANT)
expectedManifestInventoryNonempty _ = True
#else
expectedManifestInventoryNonempty = not . null
#endif

expectedManifestInventoryOrderViolation :: [(ByteString, FilePath)] -> Maybe (FilePath, FilePath)
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ORDER_BYPASS_MUTANT)
expectedManifestInventoryOrderViolation _ = Nothing
#else
expectedManifestInventoryOrderViolation = firstOrderViolation
#endif

expectedManifestInventoryDuplicatePaths :: [FilePath] -> [FilePath]
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_DUPLICATE_BYPASS_MUTANT)
expectedManifestInventoryDuplicatePaths _ = []
#else
expectedManifestInventoryDuplicatePaths = duplicateValues
#endif

expectedManifestInventoryCaseFoldCollisions :: [FilePath] -> [(FilePath, FilePath)]
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_CASE_COLLISION_BYPASS_MUTANT)
expectedManifestInventoryCaseFoldCollisions _ = []
#else
expectedManifestInventoryCaseFoldCollisions = caseFoldPathCollisions
#endif

expectedManifestInventoryPrefixConflicts :: [FilePath] -> [FilePath]
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_PREFIX_CONFLICT_BYPASS_MUTANT)
expectedManifestInventoryPrefixConflicts _ = []
#else
expectedManifestInventoryPrefixConflicts = prefixPathConflicts
#endif

expectedPathProblems :: FilePath -> [SourceAcquisitionProblem]
expectedPathProblems path =
  [ SourceAcquisitionExpectedManifestPathInvalid path
  | not (null (manifestPathProblems path))
  ]

expectedEntryShapeProblems
  :: GitObjectFormat
  -> SourceAcquisitionEntry
  -> [SourceAcquisitionProblem]
expectedEntryShapeProblems objectFormat entry =
  [ SourceAcquisitionExpectedManifestEntryGitObjectFormatMismatch path objectFormat objectId
  | not (gitObjectText objectFormat objectId)
  ]
    <> [ SourceAcquisitionExpectedManifestEntryBlobSha256Malformed path blobSha256
       | not (sha256Text blobSha256)
       ]
    <> [ SourceAcquisitionExpectedManifestEntryTooLarge path byteLength
       | not (expectedManifestEntryWithinByteLimit byteLength)
       ]
 where
  path = acquisitionEntryPath entry
  objectId = acquisitionEntryGitObjectId entry
  byteLength = acquisitionEntryByteLength entry
  blobSha256 = acquisitionEntryBlobSha256 entry

expectedManifestEntryWithinByteLimit :: Word64 -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_BYTE_LIMIT_BYPASS_MUTANT)
expectedManifestEntryWithinByteLimit _ = True
#else
expectedManifestEntryWithinByteLimit observed = observed <= fromIntegral maximumBundleBytes
#endif

compareExpectedManifestEntries
  :: [SourceAcquisitionEntry]
  -> [SourceAcquisitionEntry]
  -> [SourceAcquisitionProblem]
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_JOIN_BYPASS_MUTANT)
compareExpectedManifestEntries _ _ = []
#else
compareExpectedManifestEntries expectedEntries actualEntries =
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_MISSING_JOIN_BYPASS_MUTANT)
  []
#else
  [ SourceAcquisitionExpectedManifestEntryMissing path
  | path <- Map.keys (expectedByPath `Map.difference` actualByPath)
  ]
#endif
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_UNEXPECTED_JOIN_BYPASS_MUTANT)
    <> []
#else
    <> [ SourceAcquisitionExpectedManifestEntryUnexpected path
       | path <- Map.keys (actualByPath `Map.difference` expectedByPath)
       ]
#endif
    <> concatMap compareAtPath (Map.toAscList (Map.intersectionWith (,) expectedByPath actualByPath))
 where
  expectedByPath = Map.fromList [(acquisitionEntryPath entry, entry) | entry <- expectedEntries]
  actualByPath = Map.fromList [(acquisitionEntryPath entry, entry) | entry <- actualEntries]
  compareAtPath (path, (expectedEntry, actualEntry)) =
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_MODE_JOIN_BYPASS_MUTANT)
    []
#else
    [ SourceAcquisitionExpectedManifestEntryModeMismatch
        path
        (acquisitionEntryMode expectedEntry)
        (acquisitionEntryMode actualEntry)
    | acquisitionEntryMode expectedEntry /= acquisitionEntryMode actualEntry
    ]
#endif
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_GIT_OBJECT_JOIN_BYPASS_MUTANT)
      <> []
#else
      <> [ SourceAcquisitionExpectedManifestEntryGitObjectMismatch
             path
             (acquisitionEntryGitObjectId expectedEntry)
             (acquisitionEntryGitObjectId actualEntry)
         | acquisitionEntryGitObjectId expectedEntry /= acquisitionEntryGitObjectId actualEntry
         ]
#endif
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_BYTE_LENGTH_JOIN_BYPASS_MUTANT)
      <> []
#else
      <> [ SourceAcquisitionExpectedManifestEntryByteLengthMismatch
             path
             (acquisitionEntryByteLength expectedEntry)
             (acquisitionEntryByteLength actualEntry)
         | acquisitionEntryByteLength expectedEntry /= acquisitionEntryByteLength actualEntry
         ]
#endif
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_BLOB_SHA256_JOIN_BYPASS_MUTANT)
      <> []
#else
      <> [ SourceAcquisitionExpectedManifestEntryBlobSha256Mismatch
             path
             (acquisitionEntryBlobSha256 expectedEntry)
             (acquisitionEntryBlobSha256 actualEntry)
         | acquisitionEntryBlobSha256 expectedEntry /= acquisitionEntryBlobSha256 actualEntry
         ]
#endif
#endif

splitBundle
  :: [SourceAcquisitionEntry]
  -> ByteString
  -> Either SourceAcquisitionProblem [ByteString]
splitBundle entries bundle = do
  lengths <- traverse boundedLength entries
  let expected = declaredBundleLength lengths
      actual = observedBundleLength bundle
  if not (bundleLengthJoinAccepted expected actual)
    then Left (SourceAcquisitionBundleLengthMismatch expected actual)
    else Right (go lengths bundle)
 where
  boundedLength entry
    | not (manifestEntryWithinByteLimit (acquisitionEntryByteLength entry)) =
        Left (SourceAcquisitionEntryTooLarge (acquisitionEntryPath entry) (acquisitionEntryByteLength entry))
    | otherwise = Right (fromIntegral (acquisitionEntryByteLength entry))
  go [] _ = []
  go (size : rest) remaining =
    let (member, trailing) = ByteString.splitAt size remaining
     in routedBundleMember member : go rest trailing

declaredBundleLength :: [Int] -> Integer
#if defined(VALIDATION_SOURCE_ACQUISITION_BUNDLE_DECLARED_LENGTH_AGGREGATION_MUTANT)
declaredBundleLength lengths = foldl' (\total size -> total + toInteger size) 0 lengths + 1
#else
declaredBundleLength = foldl' (\total size -> total + toInteger size) 0
#endif

observedBundleLength :: ByteString -> Integer
#if defined(VALIDATION_SOURCE_ACQUISITION_BUNDLE_OBSERVED_LENGTH_MAPPING_MUTANT)
observedBundleLength bytes = toInteger (ByteString.length bytes) + 1
#else
observedBundleLength = toInteger . ByteString.length
#endif

routedBundleMember :: ByteString -> ByteString
#if defined(VALIDATION_SOURCE_ACQUISITION_BUNDLE_MEMBER_BYTES_ROUTE_MUTANT)
routedBundleMember = ByteString.drop 1
#else
routedBundleMember = id
#endif

contentCheckMembers :: [ByteString] -> [ByteString]
#if defined(VALIDATION_SOURCE_ACQUISITION_BUNDLE_CONTENT_ASSOCIATION_ROUTE_MUTANT)
contentCheckMembers = reverse
#else
contentCheckMembers = id
#endif

sourceIdentityMembers :: [ByteString] -> [ByteString]
#if defined(VALIDATION_SOURCE_ACQUISITION_SOURCE_IDENTITY_MEMBER_ASSOCIATION_ROUTE_MUTANT)
sourceIdentityMembers = reverse
#else
sourceIdentityMembers = id
#endif

bundleLengthJoinAccepted :: Integer -> Integer -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_BUNDLE_LENGTH_JOIN_BYPASS_MUTANT)
bundleLengthJoinAccepted _ _ = True
#else
bundleLengthJoinAccepted expected actual = expected == actual
#endif

computeFrozenSnapshotIdentity :: SourceAcquisitionManifest -> Text
computeFrozenSnapshotIdentity manifest =
  frozenSnapshotSha256
    ( TextEncoding.encodeUtf8
        ( frozenIdentityPart FrozenIdentityDomain "amoebius-frozen-source-bundle-v2\0"
            <> frozenIdentityPart FrozenIdentityCustody (renderCustody (acquisitionCustody manifest) <> "\0")
            <> frozenIdentityPart FrozenIdentityRepository (acquisitionRepositoryIdentity manifest <> "\0")
            <> frozenIdentityPart FrozenIdentityRevision (acquisitionRequestedRevision manifest <> "\0")
            <> frozenIdentityPart FrozenIdentityObjectFormat (renderObjectFormat (acquisitionObjectFormat manifest) <> "\0")
            <> frozenIdentityPart FrozenIdentityHead (acquisitionHeadIdentity manifest <> "\0")
            <> frozenIdentityPart FrozenIdentityTree (acquisitionTreeIdentity manifest <> "\0")
            <> frozenIdentityPart FrozenIdentityAuthoredRoot (acquisitionAuthoredRootIdentity manifest <> "\0")
            <> frozenIdentityPart FrozenIdentityBundle (acquisitionBundleIdentity manifest <> "\0")
            <> frozenIdentityPart FrozenIdentitySourceSnapshot (acquisitionSourceSnapshotIdentity manifest <> "\0")
        )
    )

data FrozenIdentitySlot
  = FrozenIdentityDomain
  | FrozenIdentityCustody
  | FrozenIdentityRepository
  | FrozenIdentityRevision
  | FrozenIdentityObjectFormat
  | FrozenIdentityHead
  | FrozenIdentityTree
  | FrozenIdentityAuthoredRoot
  | FrozenIdentityBundle
  | FrozenIdentitySourceSnapshot
  deriving (Eq, Ord, Show)

frozenIdentityPart :: FrozenIdentitySlot -> Text -> Text
frozenIdentityPart slot value
  | retainFrozenIdentityPart slot = value
  | otherwise = Text.empty

retainFrozenIdentityPart :: FrozenIdentitySlot -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_FROZEN_IDENTITY_DOMAIN_DROP_MUTANT)
retainFrozenIdentityPart slot = slot /= FrozenIdentityDomain
#elif defined(VALIDATION_SOURCE_ACQUISITION_FROZEN_IDENTITY_CUSTODY_DROP_MUTANT)
retainFrozenIdentityPart slot = slot /= FrozenIdentityCustody
#elif defined(VALIDATION_SOURCE_ACQUISITION_FROZEN_IDENTITY_REPOSITORY_DROP_MUTANT)
retainFrozenIdentityPart slot = slot /= FrozenIdentityRepository
#elif defined(VALIDATION_SOURCE_ACQUISITION_FROZEN_IDENTITY_REVISION_DROP_MUTANT)
retainFrozenIdentityPart slot = slot /= FrozenIdentityRevision
#elif defined(VALIDATION_SOURCE_ACQUISITION_FROZEN_IDENTITY_OBJECT_FORMAT_DROP_MUTANT)
retainFrozenIdentityPart slot = slot /= FrozenIdentityObjectFormat
#elif defined(VALIDATION_SOURCE_ACQUISITION_FROZEN_IDENTITY_HEAD_DROP_MUTANT)
retainFrozenIdentityPart slot = slot /= FrozenIdentityHead
#elif defined(VALIDATION_SOURCE_ACQUISITION_FROZEN_IDENTITY_TREE_DROP_MUTANT)
retainFrozenIdentityPart slot = slot /= FrozenIdentityTree
#elif defined(VALIDATION_SOURCE_ACQUISITION_FROZEN_IDENTITY_AUTHORED_ROOT_DROP_MUTANT)
retainFrozenIdentityPart slot = slot /= FrozenIdentityAuthoredRoot
#elif defined(VALIDATION_SOURCE_ACQUISITION_FROZEN_IDENTITY_BUNDLE_DROP_MUTANT)
retainFrozenIdentityPart slot = slot /= FrozenIdentityBundle
#elif defined(VALIDATION_SOURCE_ACQUISITION_FROZEN_IDENTITY_SOURCE_SNAPSHOT_DROP_MUTANT)
retainFrozenIdentityPart slot = slot /= FrozenIdentitySourceSnapshot
#else
retainFrozenIdentityPart slot = slot `seq` True
#endif

data TreeChild
  = TreeBlob IndexMode Text
  | TreeDirectory (Map ByteString TreeChild)
  deriving (Eq, Show)

computeTreeIdentity
  :: GitObjectFormat
  -> [SourceAcquisitionEntry]
  -> Either [SourceAcquisitionProblem] Text
computeTreeIdentity objectFormat entries = do
  tree <- foldTree entries
  hashTree objectFormat tree

foldTree
  :: [SourceAcquisitionEntry]
  -> Either [SourceAcquisitionProblem] (Map ByteString TreeChild)
foldTree = foldM insertOne Map.empty
 where
  insertOne tree entry =
    let path = acquisitionEntryPath entry
        parts = map TextEncoding.encodeUtf8 (Text.splitOn "/" (Text.pack path))
     in insertTreePath path parts (acquisitionEntryMode entry) (acquisitionEntryGitObjectId entry) tree

insertTreePath
  :: FilePath
  -> [ByteString]
  -> IndexMode
  -> Text
  -> Map ByteString TreeChild
  -> Either [SourceAcquisitionProblem] (Map ByteString TreeChild)
insertTreePath fullPath parts mode objectId tree = case parts of
  [] -> Left [SourceAcquisitionManifestPathInvalid fullPath]
  [leaf] -> case Map.lookup leaf tree of
    Nothing -> Right (Map.insert leaf (TreeBlob mode objectId) tree)
    Just _ -> Left [SourceAcquisitionManifestPathConflict fullPath]
  directory : rest -> case Map.lookup directory tree of
    Nothing -> do
      child <- insertTreePath fullPath rest mode objectId Map.empty
      Right (Map.insert directory (TreeDirectory child) tree)
    Just (TreeDirectory child) -> do
      updated <- insertTreePath fullPath rest mode objectId child
      Right (Map.insert directory (TreeDirectory updated) tree)
    Just (TreeBlob _ _) -> Left [SourceAcquisitionManifestPathConflict fullPath]

hashTree
  :: GitObjectFormat
  -> Map ByteString TreeChild
  -> Either [SourceAcquisitionProblem] Text
hashTree objectFormat tree = do
  rendered <- traverse renderChild ordered
  pure (gitObjectIdentity objectFormat "tree" (ByteString.concat rendered))
 where
  ordered = sortBy compareTreeChild (Map.toList tree)
  compareTreeChild left right = compare (sortKey left) (sortKey right)
#if defined(VALIDATION_SOURCE_ACQUISITION_TREE_SORT_MUTANT)
  sortKey (name, TreeDirectory _) = name
#else
  sortKey (name, TreeDirectory _) = name <> "/"
#endif
  sortKey (name, TreeBlob _ _) = name
  renderChild (name, child) = case child of
    TreeBlob mode objectId -> do
      rawObject <- maybe (Left [SourceAcquisitionEntryGitObjectFormatMismatch (ByteString8.unpack name) objectFormat objectId]) Right (decodeHex objectId)
      pure
        ( treeEncodingPart TreeBlobMode (modeBytes mode)
            <> treeEncodingPart TreeBlobSeparator " "
            <> treeEncodingPart TreeBlobName name
            <> treeEncodingPart TreeBlobNul "\0"
            <> treeEncodingPart TreeBlobObject rawObject
        )
    TreeDirectory descendants -> do
      objectId <- hashTree objectFormat descendants
      rawObject <- maybe (Left [SourceAcquisitionTreeIdentityMalformed objectFormat objectId]) Right (decodeHex objectId)
      pure
        ( treeEncodingPart TreeDirectoryMode "40000"
            <> treeEncodingPart TreeDirectorySeparator " "
            <> treeEncodingPart TreeDirectoryName name
            <> treeEncodingPart TreeDirectoryNul "\0"
            <> treeEncodingPart TreeDirectoryObject rawObject
        )

data TreeEncodingSlot
  = TreeBlobMode
  | TreeBlobSeparator
  | TreeBlobName
  | TreeBlobNul
  | TreeBlobObject
  | TreeDirectoryMode
  | TreeDirectorySeparator
  | TreeDirectoryName
  | TreeDirectoryNul
  | TreeDirectoryObject
  deriving (Eq, Ord, Show)

treeEncodingPart :: TreeEncodingSlot -> ByteString -> ByteString
treeEncodingPart slot value
  | retainTreeEncodingPart slot = value
  | otherwise = ByteString.empty

retainTreeEncodingPart :: TreeEncodingSlot -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_TREE_BLOB_MODE_DROP_MUTANT)
retainTreeEncodingPart slot = slot /= TreeBlobMode
#elif defined(VALIDATION_SOURCE_ACQUISITION_TREE_BLOB_SEPARATOR_DROP_MUTANT)
retainTreeEncodingPart slot = slot /= TreeBlobSeparator
#elif defined(VALIDATION_SOURCE_ACQUISITION_TREE_BLOB_NAME_DROP_MUTANT)
retainTreeEncodingPart slot = slot /= TreeBlobName
#elif defined(VALIDATION_SOURCE_ACQUISITION_TREE_BLOB_NUL_DROP_MUTANT)
retainTreeEncodingPart slot = slot /= TreeBlobNul
#elif defined(VALIDATION_SOURCE_ACQUISITION_TREE_BLOB_OBJECT_DROP_MUTANT)
retainTreeEncodingPart slot = slot /= TreeBlobObject
#elif defined(VALIDATION_SOURCE_ACQUISITION_TREE_DIRECTORY_MODE_DROP_MUTANT)
retainTreeEncodingPart slot = slot /= TreeDirectoryMode
#elif defined(VALIDATION_SOURCE_ACQUISITION_TREE_DIRECTORY_SEPARATOR_DROP_MUTANT)
retainTreeEncodingPart slot = slot /= TreeDirectorySeparator
#elif defined(VALIDATION_SOURCE_ACQUISITION_TREE_DIRECTORY_NAME_DROP_MUTANT)
retainTreeEncodingPart slot = slot /= TreeDirectoryName
#elif defined(VALIDATION_SOURCE_ACQUISITION_TREE_DIRECTORY_NUL_DROP_MUTANT)
retainTreeEncodingPart slot = slot /= TreeDirectoryNul
#elif defined(VALIDATION_SOURCE_ACQUISITION_TREE_DIRECTORY_OBJECT_DROP_MUTANT)
retainTreeEncodingPart slot = slot /= TreeDirectoryObject
#else
retainTreeEncodingPart slot = slot `seq` True
#endif

parseCommitTree
  :: GitObjectFormat
  -> ByteString
  -> Either SourceAcquisitionProblem Text
parseCommitTree objectFormat commitBytes
  | not (commitWithinByteLimit (fromIntegral (ByteString.length commitBytes))) =
      Left (SourceAcquisitionCommitTooLarge (fromIntegral (ByteString.length commitBytes)))
  | not (commitHasBytes commitBytes) = malformed "commit bytes are empty"
  | not (commitHasNoNul commitBytes) = malformed "commit bytes contain NUL"
  | otherwise = do
      headerBlock <- commitHeaderBlock commitBytes
      headerLines <- boundedCommitHeaderLines headerBlock
      parseCommitHeaders objectFormat headerLines
 where
  malformed = Left . SourceAcquisitionCommitMalformed

commitHasNoNul :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_NUL_MESSAGE_BYPASS_MUTANT)
commitHasNoNul _ = True
#else
commitHasNoNul = not . ByteString.elem 0
#endif

commitHasBytes :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_EMPTY_BYPASS_MUTANT)
commitHasBytes _ = True
#else
commitHasBytes = not . ByteString.null
#endif

-- Count newline delimiters without first allocating a list proportional to an
-- attacker-controlled header block. Only a header block already proven to have
-- at most 67 rows is split into individual slices.
boundedCommitHeaderLines
  :: ByteString
  -> Either SourceAcquisitionProblem [ByteString]
boundedCommitHeaderLines headerBlock
  | not (commitHeaderCountWithinLimit headerCount) =
      Left
        ( SourceAcquisitionCommitHeaderCountTooLarge
            headerCount
            maximumCommitHeaderCount
        )
  | Just (lineNumber, actualBytes) <- firstOverlongCommitHeader headerLines =
      Left
        ( SourceAcquisitionCommitHeaderLineTooLong
            lineNumber
            actualBytes
            maximumCommitHeaderLineBytes
        )
  | otherwise = Right headerLines
 where
  headerCount = 1 + ByteString.count 10 headerBlock
  -- ByteString.split returns [] for an empty input.  Retain that physical
  -- empty header row so the exact empty-header predicate is observable rather
  -- than being collapsed into the later missing-tree state.
  headerLines
    | ByteString.null headerBlock = [ByteString.empty]
    | otherwise = ByteString8.split '\n' headerBlock

commitHeaderCountWithinLimit :: Int -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_HEADER_COUNT_LIMIT_BYPASS_MUTANT)
commitHeaderCountWithinLimit _ = True
#else
commitHeaderCountWithinLimit observed = observed <= maximumCommitHeaderCount
#endif

commitHeaderBlock
  :: ByteString
  -> Either SourceAcquisitionProblem ByteString
commitHeaderBlock commitBytes
  | not (commitHeadersHaveNoCarriageReturn headerBlock) = malformed "commit headers contain carriage return"
  | ByteString.null separatorAndMessage =
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_SEPARATOR_BYPASS_MUTANT)
      Right headerBlock
#else
      malformed "commit lacks the canonical header/message separator"
#endif
  | otherwise = Right headerBlock
 where
  (headerBlock, separatorAndMessage) = ByteString.breakSubstring "\n\n" commitBytes
  malformed = Left . SourceAcquisitionCommitMalformed

commitHeadersHaveNoCarriageReturn :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_HEADER_CR_BYPASS_MUTANT)
commitHeadersHaveNoCarriageReturn _ = True
#else
commitHeadersHaveNoCarriageReturn = not . ByteString.elem 13
#endif

firstOverlongCommitHeader :: [ByteString] -> Maybe (Int, Int)
firstOverlongCommitHeader = go 1
 where
  go _ [] = Nothing
  go lineNumber (line : remaining)
    | not (commitHeaderLineWithinByteLimit actualBytes) = Just (lineNumber, actualBytes)
    | otherwise = go (lineNumber + 1) remaining
   where
    actualBytes = ByteString.length line

commitHeaderLineWithinByteLimit :: Int -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_HEADER_LINE_BYTE_LIMIT_BYPASS_MUTANT)
commitHeaderLineWithinByteLimit _ = True
#else
commitHeaderLineWithinByteLimit observed = observed <= maximumCommitHeaderLineBytes
#endif

data CommitHeaderState
  = CommitExpectTree
  | CommitExpectParentOrAuthor
  | CommitExpectCommitter
  | CommitExpectEnd
  deriving (Eq, Show)

parseCommitHeaders
  :: GitObjectFormat
  -> [ByteString]
  -> Either SourceAcquisitionProblem Text
parseCommitHeaders objectFormat headerLines = go CommitExpectTree Nothing normalizedHeaderLines
 where
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_TREE_FIRST_BYPASS_MUTANT)
  normalizedHeaderLines = case headerLines of
    authorLine : treeLine : remaining
      | "author " `ByteString.isPrefixOf` authorLine
          && "tree " `ByteString.isPrefixOf` treeLine ->
          treeLine : authorLine : remaining
    _ -> headerLines
#else
  normalizedHeaderLines = headerLines
#endif
  go CommitExpectTree _ [] = malformed "commit has no tree header"
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_MISSING_AUTHOR_BYPASS_MUTANT)
  go CommitExpectParentOrAuthor treeIdentity [] = maybe (Right Text.empty) Right treeIdentity
#else
  go CommitExpectParentOrAuthor _ [] = malformed "commit has no author header"
#endif
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_MISSING_COMMITTER_BYPASS_MUTANT)
  go CommitExpectCommitter treeIdentity [] =
    case treeIdentity of
      Just tree -> Right tree
      Nothing -> malformed "commit tree state was lost"
#else
  go CommitExpectCommitter _ [] = malformed "commit has no committer header"
#endif
  go CommitExpectEnd (Just treeIdentity) [] = Right treeIdentity
  go CommitExpectEnd Nothing [] = malformed "commit tree state was lost"
  go state treeIdentity (line : remaining)
    | ByteString.null line =
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_EMPTY_HEADER_LINE_BYPASS_MUTANT)
        go state treeIdentity remaining
#else
        malformed "commit header block contains an empty line"
#endif
    | ByteString.head line == 32 =
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_CONTINUATION_BYPASS_MUTANT)
        go state treeIdentity remaining
#else
        malformed "commit continuation headers are forbidden"
#endif
    | otherwise = do
        (rawName, rawValue) <- splitCommitHeader line
        let name = decodedCommitHeaderName rawName
            value = decodedCommitHeaderValue rawValue
        case state of
          CommitExpectTree -> case name of
            "tree" -> do
              if retainCommitTreeHeaderAlternative
                then do
                  tree <- parseObjectIdentity "commit tree identity is not canonical lowercase hexadecimal" value
                  go CommitExpectParentOrAuthor (Just tree) remaining
                else malformed "tree header alternative was removed"
            _ -> bypassUnknownOrMalformed state treeIdentity name remaining "tree must be the first commit header"
          CommitExpectParentOrAuthor -> case name of
            "parent" -> do
              if retainCommitParentHeaderAlternative
                then do
                  validateParentIdentity value
                  go CommitExpectParentOrAuthor treeIdentity remaining
                else malformed "parent header alternative was removed"
            "author" -> do
              if retainCommitAuthorHeaderAlternative
                then do
                  validateCommitIdentity "author" value
                  go CommitExpectCommitter treeIdentity remaining
                else malformed "author header alternative was removed"
            "tree"
              | duplicateTreeHeaderBypassed -> go CommitExpectParentOrAuthor treeIdentity remaining
              | otherwise -> malformed "commit tree header is duplicated"
            "committer"
              | committerBeforeAuthorBypassed -> do
                  validateCommitIdentity "committer" value
                  go CommitExpectEnd treeIdentity remaining
              | otherwise -> malformed "committer header appears before author"
            _ -> bypassUnknownOrMalformed state treeIdentity name remaining "unknown commit header is forbidden"
          CommitExpectCommitter -> case name of
            "committer" -> do
              if retainCommitCommitterHeaderAlternative
                then do
                  validateCommitIdentity "committer" value
                  go CommitExpectEnd treeIdentity remaining
                else malformed "committer header alternative was removed"
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_HEADER_ORDER_BYPASS_MUTANT)
            "parent" -> do
              validateParentIdentity value
              go CommitExpectCommitter treeIdentity remaining
#else
            "parent" -> malformed "parent headers must be contiguous before author"
#endif
            "author"
              | duplicateAuthorHeaderBypassed -> go CommitExpectCommitter treeIdentity remaining
              | otherwise -> malformed "commit author header is duplicated"
            "tree"
              | duplicateTreeHeaderBypassed -> go CommitExpectCommitter treeIdentity remaining
              | otherwise -> malformed "commit tree header is duplicated"
            _ -> bypassUnknownOrMalformed state treeIdentity name remaining "unknown commit header is forbidden"
          CommitExpectEnd -> case name of
            "tree"
              | duplicateTreeHeaderBypassed -> go CommitExpectEnd treeIdentity remaining
              | otherwise -> malformed "commit tree header is duplicated"
            "parent" ->
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_PARENT_AFTER_COMMITTER_BYPASS_MUTANT)
              do
                validateParentIdentity value
                go CommitExpectEnd treeIdentity remaining
#else
              malformed "parent header appears after committer"
#endif
            "author"
              | duplicateAuthorHeaderBypassed -> go CommitExpectEnd treeIdentity remaining
              | otherwise -> malformed "commit author header is duplicated"
            "committer"
              | duplicateCommitterHeaderBypassed -> go CommitExpectEnd treeIdentity remaining
              | otherwise -> malformed "commit committer header is duplicated"
            _ -> bypassUnknownOrMalformed state treeIdentity name remaining "unknown commit header is forbidden"

  parseObjectIdentity detail value
    | gitObjectBytes objectFormat value = Right (TextEncoding.decodeUtf8 value)
    | otherwise = malformed detail

#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_PARENT_IDENTITY_BYPASS_MUTANT)
  validateParentIdentity _ = pure ()
#else
  validateParentIdentity value =
    parseObjectIdentity "commit has a malformed parent identity" value >> pure ()
#endif

#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_UNKNOWN_HEADER_BYPASS_MUTANT)
  bypassUnknownOrMalformed state treeIdentity name remaining detail
    | name `notElem` ["tree", "parent", "author", "committer"] =
        go state treeIdentity remaining
    | otherwise = malformed detail
#else
  bypassUnknownOrMalformed _ _ _ _ detail = malformed detail
#endif

  malformed = Left . SourceAcquisitionCommitMalformed

retainCommitTreeHeaderAlternative :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_TREE_HEADER_REMOVAL_MUTANT)
retainCommitTreeHeaderAlternative = False
#else
retainCommitTreeHeaderAlternative = True
#endif

retainCommitParentHeaderAlternative :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_PARENT_HEADER_REMOVAL_MUTANT)
retainCommitParentHeaderAlternative = False
#else
retainCommitParentHeaderAlternative = True
#endif

retainCommitAuthorHeaderAlternative :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_AUTHOR_HEADER_REMOVAL_MUTANT)
retainCommitAuthorHeaderAlternative = False
#else
retainCommitAuthorHeaderAlternative = True
#endif

retainCommitCommitterHeaderAlternative :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_COMMITTER_HEADER_REMOVAL_MUTANT)
retainCommitCommitterHeaderAlternative = False
#else
retainCommitCommitterHeaderAlternative = True
#endif

duplicateTreeHeaderBypassed :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_DUPLICATE_TREE_BYPASS_MUTANT)
duplicateTreeHeaderBypassed = True
#else
duplicateTreeHeaderBypassed = False
#endif

duplicateAuthorHeaderBypassed :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_DUPLICATE_AUTHOR_BYPASS_MUTANT)
duplicateAuthorHeaderBypassed = True
#else
duplicateAuthorHeaderBypassed = False
#endif

duplicateCommitterHeaderBypassed :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_DUPLICATE_COMMITTER_BYPASS_MUTANT)
duplicateCommitterHeaderBypassed = True
#else
duplicateCommitterHeaderBypassed = False
#endif

committerBeforeAuthorBypassed :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_COMMITTER_BEFORE_AUTHOR_BYPASS_MUTANT)
committerBeforeAuthorBypassed = True
#else
committerBeforeAuthorBypassed = False
#endif

decodedCommitHeaderName :: ByteString -> ByteString
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_HEADER_NAME_MAPPING_MUTANT)
decodedCommitHeaderName name = name <> "mutated"
#else
decodedCommitHeaderName = id
#endif

decodedCommitHeaderValue :: ByteString -> ByteString
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_HEADER_VALUE_MAPPING_MUTANT)
decodedCommitHeaderValue value = value <> " mutated"
#else
decodedCommitHeaderValue = id
#endif

splitCommitHeader
  :: ByteString
  -> Either SourceAcquisitionProblem (ByteString, ByteString)
splitCommitHeader line = do
  let (name, rawValue) = ByteString.break (== 32) line
  if not (commitHeaderHasValueSeparator rawValue)
    then malformed "commit header lacks a value separator"
    else pure ()
  let value = ByteString.drop 1 rawValue
  if not (commitHeaderValueNonempty value)
    then malformed "commit header name or value is empty"
    else Right (name, value)
 where
  malformed = Left . SourceAcquisitionCommitMalformed

commitHeaderHasValueSeparator :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_VALUE_SEPARATOR_BYPASS_MUTANT)
commitHeaderHasValueSeparator _ = True
#else
commitHeaderHasValueSeparator = not . ByteString.null
#endif

commitHeaderValueNonempty :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_EMPTY_VALUE_BYPASS_MUTANT)
commitHeaderValueNonempty _ = True
#else
commitHeaderValueNonempty = not . ByteString.null
#endif

validateCommitIdentity
  :: Text
  -> ByteString
  -> Either SourceAcquisitionProblem ()
validateCommitIdentity role value
  | commitIdentityValueAccepted value = Right ()
  | otherwise =
      Left
        ( SourceAcquisitionCommitMalformed
            (role <> " identity is outside the canonical closed grammar")
        )

commitIdentityValueAccepted :: ByteString -> Bool
commitIdentityValueAccepted value = commitIdentityValueBypassed || canonicalCommitIdentity value

commitIdentityValueBypassed :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_IDENTITY_VALUE_BYPASS_MUTANT)
commitIdentityValueBypassed = True
#else
commitIdentityValueBypassed = False
#endif

canonicalCommitIdentity :: ByteString -> Bool
canonicalCommitIdentity value =
  canonicalDisplayName (decodedCommitDisplayName name)
    && canonicalEmail (decodedCommitEmail email)
    && canonicalTimestamp (decodedCommitTimestamp timestamp)
    && canonicalTimezone (decodedCommitTimezone timezone)
    && commitIdentityHasNoTrailingFields trailing
 where
  (name, emailAndTime) = ByteString.breakSubstring " <" value
  afterName = ByteString.drop 2 emailAndTime
  (email, closingAndTime) = ByteString.break (== 62) afterName
  afterClosing = ByteString.drop 2 closingAndTime
  timeParts = ByteString8.split ' ' afterClosing
  (timestamp, timezone, trailing) = case timeParts of
    parsedTimestamp : parsedTimezone : remaining
      | ByteString.isPrefixOf "> " closingAndTime ->
          (parsedTimestamp, parsedTimezone, ByteString8.unwords remaining)
    _ -> (ByteString.empty, ByteString.empty, "invalid")

decodedCommitDisplayName :: ByteString -> ByteString
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_IDENTITY_DISPLAY_NAME_MAPPING_MUTANT)
decodedCommitDisplayName value = value <> "<"
#else
decodedCommitDisplayName = id
#endif

decodedCommitEmail :: ByteString -> ByteString
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_IDENTITY_EMAIL_MAPPING_MUTANT)
decodedCommitEmail value = value <> "@mutated"
#else
decodedCommitEmail = id
#endif

decodedCommitTimestamp :: ByteString -> ByteString
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_IDENTITY_TIMESTAMP_MAPPING_MUTANT)
decodedCommitTimestamp value = value <> "x"
#else
decodedCommitTimestamp = id
#endif

decodedCommitTimezone :: ByteString -> ByteString
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_IDENTITY_TIMEZONE_MAPPING_MUTANT)
decodedCommitTimezone value = value <> "x"
#else
decodedCommitTimezone = id
#endif

commitIdentityHasNoTrailingFields :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_IDENTITY_TRAILING_FIELD_BYPASS_MUTANT)
commitIdentityHasNoTrailingFields _ = True
#else
commitIdentityHasNoTrailingFields = ByteString.null
#endif

canonicalDisplayName :: ByteString -> Bool
canonicalDisplayName name =
  displayNameNonempty name
    && displayNameNotLeadingSpace name
    && displayNameNotTrailingSpace name
    && displayNameNoDoubleSpace name
    && displayNameAsciiRange name
    && displayNameNoLessThan name
    && displayNameNoGreaterThan name

displayNameNonempty :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_DISPLAY_NONEMPTY_BYPASS_MUTANT)
displayNameNonempty _ = True
#else
displayNameNonempty = not . ByteString.null
#endif

displayNameNotLeadingSpace :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_DISPLAY_LEADING_SPACE_BYPASS_MUTANT)
displayNameNotLeadingSpace _ = True
#else
displayNameNotLeadingSpace name = maybe True ((/= 32) . fst) (ByteString.uncons name)
#endif

displayNameNotTrailingSpace :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_DISPLAY_TRAILING_SPACE_BYPASS_MUTANT)
displayNameNotTrailingSpace _ = True
#else
displayNameNotTrailingSpace name = maybe True ((/= 32) . snd) (ByteString.unsnoc name)
#endif

displayNameNoDoubleSpace :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_DISPLAY_DOUBLE_SPACE_BYPASS_MUTANT)
displayNameNoDoubleSpace _ = True
#else
displayNameNoDoubleSpace = not . ByteString.isInfixOf "  "
#endif

displayNameAsciiRange :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_DISPLAY_ASCII_RANGE_BYPASS_MUTANT)
displayNameAsciiRange _ = True
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_DISPLAY_ASCII_RANGE_REMOVAL_MUTANT)
displayNameAsciiRange _ = False
#else
displayNameAsciiRange = ByteString.all (\byte -> byte >= 32 && byte <= 126)
#endif

displayNameNoLessThan :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_DISPLAY_LESS_THAN_BYPASS_MUTANT)
displayNameNoLessThan _ = True
#else
displayNameNoLessThan = not . ByteString.elem 60
#endif

displayNameNoGreaterThan :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_DISPLAY_GREATER_THAN_BYPASS_MUTANT)
displayNameNoGreaterThan _ = True
#else
displayNameNoGreaterThan = not . ByteString.elem 62
#endif

canonicalEmail :: ByteString -> Bool
canonicalEmail email =
  emailHasExactlyOneAt parts
    && case parts of
      local : domain : _ ->
        let labels = ByteString8.split '.' domain
         in canonicalEmailLocal local
              && domainHasMultipleLabels labels
              && all canonicalDomainLabel labels
      _ -> False
 where
  parts = ByteString8.split '@' email

emailHasExactlyOneAt :: [ByteString] -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_EMAIL_EXACT_AT_BYPASS_MUTANT)
emailHasExactlyOneAt _ = True
#else
emailHasExactlyOneAt parts = length parts == 2
#endif

domainHasMultipleLabels :: [ByteString] -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_DOMAIN_MULTILABEL_BYPASS_MUTANT)
domainHasMultipleLabels _ = True
#else
domainHasMultipleLabels labels = length labels >= 2
#endif

canonicalEmailLocal :: ByteString -> Bool
canonicalEmailLocal local =
  emailLocalNonempty local
    && emailLocalNotLeadingDot local
    && emailLocalNotTrailingDot local
    && emailLocalNoDoubleDot local
    && emailLocalClosedCharacters local

emailLocalNonempty :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_NONEMPTY_BYPASS_MUTANT)
emailLocalNonempty _ = True
#else
emailLocalNonempty = not . ByteString.null
#endif

emailLocalNotLeadingDot :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_LEADING_DOT_BYPASS_MUTANT)
emailLocalNotLeadingDot _ = True
#else
emailLocalNotLeadingDot local = maybe True ((/= 46) . fst) (ByteString.uncons local)
#endif

emailLocalNotTrailingDot :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_TRAILING_DOT_BYPASS_MUTANT)
emailLocalNotTrailingDot _ = True
#else
emailLocalNotTrailingDot local = maybe True ((/= 46) . snd) (ByteString.unsnoc local)
#endif

emailLocalNoDoubleDot :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_DOUBLE_DOT_BYPASS_MUTANT)
emailLocalNoDoubleDot _ = True
#else
emailLocalNoDoubleDot = not . ByteString.isInfixOf ".."
#endif

emailLocalClosedCharacters :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_CHARACTER_BYPASS_MUTANT)
emailLocalClosedCharacters =
  ByteString.all
    ( \byte ->
        emailLocalLowerByte byte
          `seq` emailLocalDigitByte byte
          `seq` emailLocalPunctuationByte byte
          `seq` True
    )
#else
emailLocalClosedCharacters = ByteString.all admitted
 where
  admitted byte =
    emailLocalLowerByte byte
      || emailLocalDigitByte byte
      || emailLocalPunctuationByte byte
#endif

emailLocalLowerByte :: Word8 -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_LOWER_RANGE_REMOVAL_MUTANT)
emailLocalLowerByte _ = False
#else
emailLocalLowerByte = asciiLowerByte
#endif

emailLocalDigitByte :: Word8 -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_DIGIT_RANGE_REMOVAL_MUTANT)
emailLocalDigitByte _ = False
#else
emailLocalDigitByte = asciiDigitByte
#endif

emailLocalPunctuationByte :: Word8 -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_DOT_REMOVAL_MUTANT)
emailLocalPunctuationByte byte = byte /= 46 && byte `ByteString.elem` ".!#$%&'*+/=?^_`{|}~-"
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_EXCLAMATION_REMOVAL_MUTANT)
emailLocalPunctuationByte byte = byte /= 33 && byte `ByteString.elem` ".!#$%&'*+/=?^_`{|}~-"
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_HASH_REMOVAL_MUTANT)
emailLocalPunctuationByte byte = byte /= 35 && byte `ByteString.elem` ".!#$%&'*+/=?^_`{|}~-"
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_DOLLAR_REMOVAL_MUTANT)
emailLocalPunctuationByte byte = byte /= 36 && byte `ByteString.elem` ".!#$%&'*+/=?^_`{|}~-"
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_PERCENT_REMOVAL_MUTANT)
emailLocalPunctuationByte byte = byte /= 37 && byte `ByteString.elem` ".!#$%&'*+/=?^_`{|}~-"
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_AMPERSAND_REMOVAL_MUTANT)
emailLocalPunctuationByte byte = byte /= 38 && byte `ByteString.elem` ".!#$%&'*+/=?^_`{|}~-"
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_APOSTROPHE_REMOVAL_MUTANT)
emailLocalPunctuationByte byte = byte /= 39 && byte `ByteString.elem` ".!#$%&'*+/=?^_`{|}~-"
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_STAR_REMOVAL_MUTANT)
emailLocalPunctuationByte byte = byte /= 42 && byte `ByteString.elem` ".!#$%&'*+/=?^_`{|}~-"
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_PLUS_REMOVAL_MUTANT)
emailLocalPunctuationByte byte = byte /= 43 && byte `ByteString.elem` ".!#$%&'*+/=?^_`{|}~-"
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_SLASH_REMOVAL_MUTANT)
emailLocalPunctuationByte byte = byte /= 47 && byte `ByteString.elem` ".!#$%&'*+/=?^_`{|}~-"
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_EQUAL_REMOVAL_MUTANT)
emailLocalPunctuationByte byte = byte /= 61 && byte `ByteString.elem` ".!#$%&'*+/=?^_`{|}~-"
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_QUESTION_REMOVAL_MUTANT)
emailLocalPunctuationByte byte = byte /= 63 && byte `ByteString.elem` ".!#$%&'*+/=?^_`{|}~-"
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_CARET_REMOVAL_MUTANT)
emailLocalPunctuationByte byte = byte /= 94 && byte `ByteString.elem` ".!#$%&'*+/=?^_`{|}~-"
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_UNDERSCORE_REMOVAL_MUTANT)
emailLocalPunctuationByte byte = byte /= 95 && byte `ByteString.elem` ".!#$%&'*+/=?^_`{|}~-"
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_BACKTICK_REMOVAL_MUTANT)
emailLocalPunctuationByte byte = byte /= 96 && byte `ByteString.elem` ".!#$%&'*+/=?^_`{|}~-"
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_OPEN_BRACE_REMOVAL_MUTANT)
emailLocalPunctuationByte byte = byte /= 123 && byte `ByteString.elem` ".!#$%&'*+/=?^_`{|}~-"
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_PIPE_REMOVAL_MUTANT)
emailLocalPunctuationByte byte = byte /= 124 && byte `ByteString.elem` ".!#$%&'*+/=?^_`{|}~-"
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_CLOSE_BRACE_REMOVAL_MUTANT)
emailLocalPunctuationByte byte = byte /= 125 && byte `ByteString.elem` ".!#$%&'*+/=?^_`{|}~-"
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_TILDE_REMOVAL_MUTANT)
emailLocalPunctuationByte byte = byte /= 126 && byte `ByteString.elem` ".!#$%&'*+/=?^_`{|}~-"
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_HYPHEN_REMOVAL_MUTANT)
emailLocalPunctuationByte byte = byte /= 45 && byte `ByteString.elem` ".!#$%&'*+/=?^_`{|}~-"
#else
emailLocalPunctuationByte byte = byte `ByteString.elem` ".!#$%&'*+/=?^_`{|}~-"
#endif


canonicalDomainLabel :: ByteString -> Bool
canonicalDomainLabel label =
  domainLabelNonempty label
    && domainLabelNotLeadingHyphen label
    && domainLabelNotTrailingHyphen label
    && domainLabelClosedCharacters label

domainLabelNonempty :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_LABEL_NONEMPTY_BYPASS_MUTANT)
domainLabelNonempty _ = True
#else
domainLabelNonempty = not . ByteString.null
#endif

domainLabelNotLeadingHyphen :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_LABEL_LEADING_HYPHEN_BYPASS_MUTANT)
domainLabelNotLeadingHyphen _ = True
#else
domainLabelNotLeadingHyphen label = maybe True ((/= 45) . fst) (ByteString.uncons label)
#endif

domainLabelNotTrailingHyphen :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_LABEL_TRAILING_HYPHEN_BYPASS_MUTANT)
domainLabelNotTrailingHyphen _ = True
#else
domainLabelNotTrailingHyphen label = maybe True ((/= 45) . snd) (ByteString.unsnoc label)
#endif

domainLabelClosedCharacters :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_LABEL_CHARACTER_BYPASS_MUTANT)
domainLabelClosedCharacters =
  ByteString.all
    ( \byte ->
        domainLabelLowerByte byte
          `seq` domainLabelDigitByte byte
          `seq` domainLabelHyphenByte byte
          `seq` True
    )
#else
domainLabelClosedCharacters =
  ByteString.all
    (\byte -> domainLabelLowerByte byte || domainLabelDigitByte byte || domainLabelHyphenByte byte)
#endif

domainLabelLowerByte :: Word8 -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_LABEL_LOWER_RANGE_REMOVAL_MUTANT)
domainLabelLowerByte _ = False
#else
domainLabelLowerByte = asciiLowerByte
#endif

domainLabelDigitByte :: Word8 -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_LABEL_DIGIT_RANGE_REMOVAL_MUTANT)
domainLabelDigitByte _ = False
#else
domainLabelDigitByte = asciiDigitByte
#endif

domainLabelHyphenByte :: Word8 -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_LABEL_HYPHEN_REMOVAL_MUTANT)
domainLabelHyphenByte _ = False
#else
domainLabelHyphenByte byte = byte == 45
#endif

timestampZeroAlternative :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_TIMESTAMP_ZERO_REMOVAL_MUTANT)
timestampZeroAlternative _ = False
#else
timestampZeroAlternative value = value == "0"
#endif

canonicalTimestamp :: ByteString -> Bool
canonicalTimestamp timestamp =
  timestampZeroAlternative timestamp
    || ( timestampNonzeroLeadingDigit timestamp
          && timestampWithinWidth timestamp
          && timestampRemainingDigits timestamp
       )

timestampNonzeroLeadingDigit :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_TIMESTAMP_LEADING_BYPASS_MUTANT)
timestampNonzeroLeadingDigit _ = True
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_TIMESTAMP_NONZERO_DIGIT_RANGE_REMOVAL_MUTANT)
timestampNonzeroLeadingDigit _ = False
#else
timestampNonzeroLeadingDigit timestamp = case ByteString.uncons timestamp of
  Just (first, _) -> first >= 49 && first <= 57
  Nothing -> False
#endif

timestampWithinWidth :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_TIMESTAMP_WIDTH_BYPASS_MUTANT)
timestampWithinWidth _ = True
#else
timestampWithinWidth timestamp = ByteString.length timestamp <= 19
#endif

timestampRemainingDigits :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_TIMESTAMP_DIGIT_BYPASS_MUTANT)
timestampRemainingDigits timestamp =
  ByteString.all (\byte -> timestampDigitByte byte `seq` True) (ByteString.drop 1 timestamp)
#else
timestampRemainingDigits = ByteString.all timestampDigitByte . ByteString.drop 1
#endif

timestampDigitByte :: Word8 -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_TIMESTAMP_DIGIT_RANGE_REMOVAL_MUTANT)
timestampDigitByte _ = False
#else
timestampDigitByte = asciiDigitByte
#endif

canonicalTimezone :: ByteString -> Bool
canonicalTimezone timezone =
  timezoneExactLength timezone
    && timezoneSign sign
    && timezoneDigits digits
    && timezoneHour hour
    && timezoneMinute minute
    && timezoneFourteenCoupling hour minute
    && timezoneNotNegativeZero sign hour minute
 where
  sign = byteAtOrZero 0 timezone
  digits = ByteString.take 4 (ByteString.drop 1 timezone)
  hour = decimalPair (byteAtOrZero 1 timezone) (byteAtOrZero 2 timezone)
  minute = decimalPair (byteAtOrZero 3 timezone) (byteAtOrZero 4 timezone)
  byteAtOrZero index bytes = maybe 48 fst (ByteString.uncons (ByteString.drop index bytes))
  decimalPair high low
    | asciiDigitByte high && asciiDigitByte low =
        fromIntegral (high - 48) * 10 + fromIntegral (low - 48)
    | otherwise = 0

timezoneExactLength :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_TIMEZONE_LENGTH_BYPASS_MUTANT)
timezoneExactLength _ = True
#else
timezoneExactLength timezone = ByteString.length timezone == 5
#endif

timezoneSign :: Word8 -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_TIMEZONE_SIGN_BYPASS_MUTANT)
timezoneSign sign =
  timezonePlusSign sign
    `seq` timezoneMinusSign sign
    `seq` True
#else
timezoneSign sign = timezonePlusSign sign || timezoneMinusSign sign
#endif

timezonePlusSign :: Word8 -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_TIMEZONE_PLUS_SIGN_REMOVAL_MUTANT)
timezonePlusSign _ = False
#else
timezonePlusSign sign = sign == 43
#endif

timezoneMinusSign :: Word8 -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_TIMEZONE_MINUS_SIGN_REMOVAL_MUTANT)
timezoneMinusSign _ = False
#else
timezoneMinusSign sign = sign == 45
#endif

timezoneDigits :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_TIMEZONE_DIGIT_BYPASS_MUTANT)
timezoneDigits = ByteString.all (\byte -> timezoneDigitByte byte `seq` True)
#else
timezoneDigits = ByteString.all timezoneDigitByte
#endif

timezoneDigitByte :: Word8 -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_TIMEZONE_DIGIT_RANGE_REMOVAL_MUTANT)
timezoneDigitByte _ = False
#else
timezoneDigitByte = asciiDigitByte
#endif

timezoneHour :: Int -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_TIMEZONE_HOUR_BYPASS_MUTANT)
timezoneHour _ = True
#else
timezoneHour hour = hour <= 14
#endif

timezoneMinute :: Int -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_TIMEZONE_MINUTE_BYPASS_MUTANT)
timezoneMinute _ = True
#else
timezoneMinute minute = minute <= 59
#endif

timezoneFourteenCoupling :: Int -> Int -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_TIMEZONE_FOURTEEN_BYPASS_MUTANT)
timezoneFourteenCoupling _ _ = True
#else
timezoneFourteenCoupling hour minute = hour /= 14 || minute == 0
#endif

timezoneNotNegativeZero :: Word8 -> Int -> Int -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_TIMEZONE_NEGATIVE_ZERO_BYPASS_MUTANT)
timezoneNotNegativeZero _ _ _ = True
#else
timezoneNotNegativeZero sign hour minute = not (sign == 45 && hour == 0 && minute == 0)
#endif

asciiLowerByte :: Word8 -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_ASCII_LOWER_BYTE_REMOVAL_MUTANT)
asciiLowerByte _ = False
#else
asciiLowerByte byte = byte >= 97 && byte <= 122
#endif

asciiDigitByte :: Word8 -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_ASCII_DIGIT_BYTE_REMOVAL_MUTANT)
asciiDigitByte _ = False
#else
asciiDigitByte byte = byte >= 48 && byte <= 57
#endif

gitObjectBytes :: GitObjectFormat -> ByteString -> Bool
gitObjectBytes objectFormat value =
  gitObjectBytesWidth objectFormat value && gitObjectBytesLowerHex value

gitObjectBytesWidth :: GitObjectFormat -> ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_GIT_OBJECT_BYTES_WIDTH_BYPASS_MUTANT)
gitObjectBytesWidth _ _ = True
#else
gitObjectBytesWidth objectFormat value = ByteString.length value == expectedLength
 where
  expectedLength = case objectFormat of
    GitObjectSha1 -> 40
    GitObjectSha256 -> 64
#endif

gitObjectBytesLowerHex :: ByteString -> Bool
gitObjectBytesLowerHex value =
  gitObjectBytesLowerHexBypassed
    || ByteString.all gitObjectLowerHexByte value

gitObjectBytesLowerHexBypassed :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_GIT_OBJECT_BYTES_LOWER_HEX_BYPASS_MUTANT)
gitObjectBytesLowerHexBypassed = True
#else
gitObjectBytesLowerHexBypassed = False
#endif

gitObjectLowerHexByte :: Word8 -> Bool
gitObjectLowerHexByte byte = gitObjectHexDigitByte byte || gitObjectHexLowerByte byte

gitObjectHexDigitByte :: Word8 -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_GIT_OBJECT_BYTES_DIGIT_RANGE_REMOVAL_MUTANT)
gitObjectHexDigitByte _ = False
#else
gitObjectHexDigitByte byte = byte >= 48 && byte <= 57
#endif

gitObjectHexLowerByte :: Word8 -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_GIT_OBJECT_BYTES_LOWER_RANGE_REMOVAL_MUTANT)
gitObjectHexLowerByte _ = False
#else
gitObjectHexLowerByte byte = byte >= 97 && byte <= 102
#endif

gitObjectIdentity :: GitObjectFormat -> ByteString -> ByteString -> Text
gitObjectIdentity objectFormat kind payload = case objectFormat of
#if defined(VALIDATION_SOURCE_ACQUISITION_GIT_OBJECT_SHA1_ALGORITHM_MUTANT)
  GitObjectSha1 -> Text.pack (show (Crypto.hash framed :: Crypto.Digest Crypto.SHA256))
#else
  GitObjectSha1 -> Text.pack (show (Crypto.hash framed :: Crypto.Digest Crypto.SHA1))
#endif
#if defined(VALIDATION_SOURCE_ACQUISITION_GIT_OBJECT_SHA256_ALGORITHM_MUTANT)
  GitObjectSha256 -> Text.pack (show (Crypto.hash framed :: Crypto.Digest Crypto.SHA1))
#else
  GitObjectSha256 -> Text.pack (show (Crypto.hash framed :: Crypto.Digest Crypto.SHA256))
#endif
 where
  framed =
    gitObjectFramePart GitObjectFrameKind kind
      <> gitObjectFramePart GitObjectFrameSeparator " "
      <> gitObjectFramePart GitObjectFrameLength (ByteString8.pack (show (ByteString.length payload)))
      <> gitObjectFramePart GitObjectFrameNul "\0"
      <> gitObjectFramePart GitObjectFramePayload payload

data GitObjectFrameSlot
  = GitObjectFrameKind
  | GitObjectFrameSeparator
  | GitObjectFrameLength
  | GitObjectFrameNul
  | GitObjectFramePayload
  deriving (Eq, Ord, Show)

gitObjectFramePart :: GitObjectFrameSlot -> ByteString -> ByteString
gitObjectFramePart slot value
  | retainGitObjectFramePart slot = value
  | otherwise = ByteString.empty

retainGitObjectFramePart :: GitObjectFrameSlot -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_GIT_OBJECT_FRAME_KIND_DROP_MUTANT)
retainGitObjectFramePart slot = slot /= GitObjectFrameKind
#elif defined(VALIDATION_SOURCE_ACQUISITION_GIT_OBJECT_FRAME_SEPARATOR_DROP_MUTANT)
retainGitObjectFramePart slot = slot /= GitObjectFrameSeparator
#elif defined(VALIDATION_SOURCE_ACQUISITION_GIT_OBJECT_FRAME_LENGTH_DROP_MUTANT)
retainGitObjectFramePart slot = slot /= GitObjectFrameLength
#elif defined(VALIDATION_SOURCE_ACQUISITION_GIT_OBJECT_FRAME_NUL_DROP_MUTANT)
retainGitObjectFramePart slot = slot /= GitObjectFrameNul
#elif defined(VALIDATION_SOURCE_ACQUISITION_GIT_OBJECT_FRAME_PAYLOAD_DROP_MUTANT)
retainGitObjectFramePart slot = slot /= GitObjectFramePayload
#else
retainGitObjectFramePart slot = slot `seq` True
#endif

decodeHex :: Text -> Maybe ByteString
decodeHex value
  | odd (Text.length value) = Nothing
  | otherwise = ByteString.pack <$> go (Text.unpack value)
 where
  go [] = Just []
  go (high : low : rest) = do
    highValue <- hexValue high
    lowValue <- hexValue low
    remaining <- go rest
    pure (fromIntegral (highValue * 16 + lowValue) : remaining)
  go _ = Nothing
  hexValue character
    | decodeHexDigit character = Just (fromEnum character - fromEnum '0')
    | decodeHexLower character = Just (10 + fromEnum character - fromEnum 'a')
    | otherwise = Nothing

decodeHexDigit :: Char -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_DECODE_HEX_DIGIT_RANGE_REMOVAL_MUTANT)
decodeHexDigit _ = False
#else
decodeHexDigit character = character >= '0' && character <= '9'
#endif

decodeHexLower :: Char -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_DECODE_HEX_LOWER_RANGE_REMOVAL_MUTANT)
decodeHexLower _ = False
#else
decodeHexLower character = character >= 'a' && character <= 'f'
#endif

toTrackedEntry :: SourceAcquisitionEntry -> ByteString -> TrackedEntry
toTrackedEntry entry bytes =
  TrackedEntry
    { trackedIndex =
        IndexEntry
          { indexPath = trackedEntryPathContribution entry
          , indexMode = trackedEntryModeContribution entry
          , indexObjectId = trackedEntryObjectContribution entry
          }
    , trackedBytes = trackedEntryBytesContribution bytes
    }

trackedEntryPathContribution :: SourceAcquisitionEntry -> FilePath
#if defined(VALIDATION_SOURCE_ACQUISITION_SOURCE_IDENTITY_PATH_CONTRIBUTION_MUTANT)
trackedEntryPathContribution entry = acquisitionEntryPath entry <> ".mutated"
#else
trackedEntryPathContribution = acquisitionEntryPath
#endif

trackedEntryModeContribution :: SourceAcquisitionEntry -> IndexMode
#if defined(VALIDATION_SOURCE_ACQUISITION_SOURCE_IDENTITY_MODE_CONTRIBUTION_MUTANT)
trackedEntryModeContribution entry = acquisitionEntryMode entry `seq` RegularFile
#else
trackedEntryModeContribution = acquisitionEntryMode
#endif

trackedEntryObjectContribution :: SourceAcquisitionEntry -> Text
#if defined(VALIDATION_SOURCE_ACQUISITION_SOURCE_IDENTITY_OBJECT_CONTRIBUTION_MUTANT)
trackedEntryObjectContribution entry = acquisitionEntryGitObjectId entry `seq` Text.replicate 40 "0"
#else
trackedEntryObjectContribution = acquisitionEntryGitObjectId
#endif

trackedEntryBytesContribution :: ByteString -> ByteString
#if defined(VALIDATION_SOURCE_ACQUISITION_SOURCE_IDENTITY_BYTES_CONTRIBUTION_MUTANT)
trackedEntryBytesContribution bytes = bytes <> "mutated"
#else
trackedEntryBytesContribution = id
#endif

manifestPathProblems :: FilePath -> [SourceAcquisitionProblem]
manifestPathProblems path
  | not (all portablePathCharacter path) = invalid
  | any invalidPortableSegment parts = invalid
  | not (pathWithinTotalLimit pathByteLength) =
      [SourceAcquisitionManifestPathTooLong path pathByteLength]
  | not (pathWithinDepthLimit partCount) =
      [SourceAcquisitionManifestPathTooDeep path partCount]
  | Just segment <- firstOverlongSegment parts =
      [ SourceAcquisitionManifestPathSegmentTooLong
          path
          segment
          (ByteString.length (TextEncoding.encodeUtf8 segment))
      ]
  | otherwise = []
 where
  pathText = Text.pack path
  pathBytes = TextEncoding.encodeUtf8 pathText
  pathByteLength = ByteString.length pathBytes
  parts = Text.splitOn "/" pathText
  partCount = length parts
  invalid = [SourceAcquisitionManifestPathInvalid path]

portablePathCharacter :: Char -> Bool
portablePathCharacter character =
  portablePathCharacterBypassed
    || portableLower character
    || portableUpper character
    || portableDigit character
    || portablePunctuation character

portablePathCharacterBypassed :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PATH_CHARACTER_BYPASS_MUTANT)
portablePathCharacterBypassed = True
#else
portablePathCharacterBypassed = False
#endif

portableLower :: Char -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PATH_LOWER_RANGE_REMOVAL_MUTANT)
portableLower _ = False
#else
portableLower character = character >= 'a' && character <= 'z'
#endif

portableUpper :: Char -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PATH_UPPER_RANGE_REMOVAL_MUTANT)
portableUpper _ = False
#else
portableUpper character = character >= 'A' && character <= 'Z'
#endif

portableDigit :: Char -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PATH_DIGIT_RANGE_REMOVAL_MUTANT)
portableDigit _ = False
#else
portableDigit character = character >= '0' && character <= '9'
#endif

portablePunctuation :: Char -> Bool
portablePunctuation character =
  not removeAllPortablePunctuation
    && ( portableSlash character
          || portableDot character
          || portableUnderscore character
          || portableAt character
          || portablePlus character
          || portableComma character
          || portableHyphen character
       )

removeAllPortablePunctuation :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PATH_PUNCTUATION_REMOVAL_MUTANT)
removeAllPortablePunctuation = True
#else
removeAllPortablePunctuation = False
#endif

portableSlash :: Char -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PATH_SLASH_REMOVAL_MUTANT)
portableSlash _ = False
#else
portableSlash character = character == '/'
#endif

portableDot :: Char -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PATH_DOT_REMOVAL_MUTANT)
portableDot _ = False
#else
portableDot character = character == '.'
#endif

portableUnderscore :: Char -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PATH_UNDERSCORE_REMOVAL_MUTANT)
portableUnderscore _ = False
#else
portableUnderscore character = character == '_'
#endif

portableAt :: Char -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PATH_AT_REMOVAL_MUTANT)
portableAt _ = False
#else
portableAt character = character == '@'
#endif

portablePlus :: Char -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PATH_PLUS_REMOVAL_MUTANT)
portablePlus _ = False
#else
portablePlus character = character == '+'
#endif

portableComma :: Char -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PATH_COMMA_REMOVAL_MUTANT)
portableComma _ = False
#else
portableComma character = character == ','
#endif

portableHyphen :: Char -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PATH_HYPHEN_REMOVAL_MUTANT)
portableHyphen _ = False
#else
portableHyphen character = character == '-'
#endif

pathWithinTotalLimit :: Int -> Bool
pathWithinTotalLimit byteLength =
  pathTotalLimitBypassed || byteLength <= maximumManifestPathBytes

pathTotalLimitBypassed :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PATH_TOTAL_LIMIT_BYPASS_MUTANT)
pathTotalLimitBypassed = True
#else
pathTotalLimitBypassed = False
#endif

invalidPortableSegment :: Text -> Bool
invalidPortableSegment segment =
  invalidEmptySegment segment
    || invalidDotSegment segment
    || invalidDotDotSegment segment
    || invalidGitSegment segment
    || invalidTrailingDotSegment segment
    || windowsReservedBase segment

invalidEmptySegment :: Text -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PATH_EMPTY_SEGMENT_BYPASS_MUTANT)
invalidEmptySegment _ = False
#else
invalidEmptySegment = Text.null
#endif

invalidDotSegment :: Text -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PATH_DOT_SEGMENT_BYPASS_MUTANT)
invalidDotSegment _ = False
#else
invalidDotSegment segment = segment == "."
#endif

invalidDotDotSegment :: Text -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PATH_DOT_DOT_SEGMENT_BYPASS_MUTANT)
invalidDotDotSegment _ = False
#else
invalidDotDotSegment segment = segment == ".."
#endif

invalidGitSegment :: Text -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PATH_GIT_SEGMENT_BYPASS_MUTANT)
invalidGitSegment _ = False
#else
invalidGitSegment segment = Text.toLower segment == ".git"
#endif

invalidTrailingDotSegment :: Text -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PATH_TRAILING_DOT_SEGMENT_BYPASS_MUTANT)
invalidTrailingDotSegment _ = False
#else
invalidTrailingDotSegment segment =
  segment /= "." && segment /= ".." && Text.isSuffixOf "." segment
#endif

windowsReservedBase :: Text -> Bool
windowsReservedBase segment =
  reservedCoreName base
    || reservedComRange base
    || reservedCom9 base
    || reservedLptRange base
    || reservedLpt9 base
 where
  base = reservedCaseFold (reservedExtensionBase segment)

reservedCaseFold :: Text -> Text
#if defined(VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_CASEFOLD_BYPASS_MUTANT)
reservedCaseFold = id
#else
reservedCaseFold = Text.toUpper
#endif

reservedExtensionBase :: Text -> Text
#if defined(VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_EXTENSION_BYPASS_MUTANT)
reservedExtensionBase = id
#else
reservedExtensionBase = Text.takeWhile (/= '.')
#endif

reservedCoreName :: Text -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_CORE_BYPASS_MUTANT)
reservedCoreName _ = False
#else
#if defined(VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_CON_REMOVAL_MUTANT)
reservedCoreName base = base `elem` ["PRN", "AUX", "NUL"]
#elif defined(VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_PRN_REMOVAL_MUTANT)
reservedCoreName base = base `elem` ["CON", "AUX", "NUL"]
#elif defined(VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_AUX_REMOVAL_MUTANT)
reservedCoreName base = base `elem` ["CON", "PRN", "NUL"]
#elif defined(VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_NUL_REMOVAL_MUTANT)
reservedCoreName base = base `elem` ["CON", "PRN", "AUX"]
#else
reservedCoreName base = base `elem` ["CON", "PRN", "AUX", "NUL"]
#endif
#endif

reservedComRange :: Text -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_COM_RANGE_BYPASS_MUTANT)
reservedComRange _ = False
#elif defined(VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_COM1_REMOVAL_MUTANT)
reservedComRange base = base `elem` ["COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8"]
#elif defined(VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_COM2_REMOVAL_MUTANT)
reservedComRange base = base `elem` ["COM1", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8"]
#elif defined(VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_COM3_REMOVAL_MUTANT)
reservedComRange base = base `elem` ["COM1", "COM2", "COM4", "COM5", "COM6", "COM7", "COM8"]
#elif defined(VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_COM4_REMOVAL_MUTANT)
reservedComRange base = base `elem` ["COM1", "COM2", "COM3", "COM5", "COM6", "COM7", "COM8"]
#elif defined(VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_COM5_REMOVAL_MUTANT)
reservedComRange base = base `elem` ["COM1", "COM2", "COM3", "COM4", "COM6", "COM7", "COM8"]
#elif defined(VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_COM6_REMOVAL_MUTANT)
reservedComRange base = base `elem` ["COM1", "COM2", "COM3", "COM4", "COM5", "COM7", "COM8"]
#elif defined(VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_COM7_REMOVAL_MUTANT)
reservedComRange base = base `elem` ["COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM8"]
#elif defined(VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_COM8_REMOVAL_MUTANT)
reservedComRange base = base `elem` ["COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7"]
#else
reservedComRange base = base `elem` ["COM" <> Text.pack (show number) | number <- [(1 :: Int) .. 8]]
#endif

reservedCom9 :: Text -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_COM9_BYPASS_MUTANT)
reservedCom9 _ = False
#else
reservedCom9 base = base == "COM9"
#endif

reservedLptRange :: Text -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_LPT_RANGE_BYPASS_MUTANT)
reservedLptRange _ = False
#elif defined(VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_LPT1_REMOVAL_MUTANT)
reservedLptRange base = base `elem` ["LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8"]
#elif defined(VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_LPT2_REMOVAL_MUTANT)
reservedLptRange base = base `elem` ["LPT1", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8"]
#elif defined(VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_LPT3_REMOVAL_MUTANT)
reservedLptRange base = base `elem` ["LPT1", "LPT2", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8"]
#elif defined(VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_LPT4_REMOVAL_MUTANT)
reservedLptRange base = base `elem` ["LPT1", "LPT2", "LPT3", "LPT5", "LPT6", "LPT7", "LPT8"]
#elif defined(VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_LPT5_REMOVAL_MUTANT)
reservedLptRange base = base `elem` ["LPT1", "LPT2", "LPT3", "LPT4", "LPT6", "LPT7", "LPT8"]
#elif defined(VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_LPT6_REMOVAL_MUTANT)
reservedLptRange base = base `elem` ["LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT7", "LPT8"]
#elif defined(VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_LPT7_REMOVAL_MUTANT)
reservedLptRange base = base `elem` ["LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT8"]
#elif defined(VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_LPT8_REMOVAL_MUTANT)
reservedLptRange base = base `elem` ["LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7"]
#else
reservedLptRange base = base `elem` ["LPT" <> Text.pack (show number) | number <- [(1 :: Int) .. 8]]
#endif

reservedLpt9 :: Text -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_LPT9_BYPASS_MUTANT)
reservedLpt9 _ = False
#else
reservedLpt9 base = base == "LPT9"
#endif

firstOverlongSegment :: [Text] -> Maybe Text
firstOverlongSegment = go
 where
  go [] = Nothing
  go (segment : rest)
    | not (pathSegmentWithinByteLimit (ByteString.length (TextEncoding.encodeUtf8 segment))) = Just segment
    | otherwise = go rest

pathWithinDepthLimit :: Int -> Bool
pathWithinDepthLimit observed =
  pathDepthLimitBypassed || observed <= maximumManifestPathDepth

pathDepthLimitBypassed :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PATH_DEPTH_LIMIT_BYPASS_MUTANT)
pathDepthLimitBypassed = True
#else
pathDepthLimitBypassed = False
#endif

pathSegmentWithinByteLimit :: Int -> Bool
pathSegmentWithinByteLimit observed =
  pathSegmentByteLimitBypassed || observed <= maximumManifestPathSegmentBytes

pathSegmentByteLimitBypassed :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PATH_SEGMENT_BYTE_LIMIT_BYPASS_MUTANT)
pathSegmentByteLimitBypassed = True
#else
pathSegmentByteLimitBypassed = False
#endif

firstOrderViolation :: Ord key => [(key, value)] -> Maybe (value, value)
firstOrderViolation values = case values of
  [] -> Nothing
  first : rest -> go first rest
 where
  go _ [] = Nothing
  go previous (current : remaining) =
    if fst previous < fst current
      then go current remaining
      else Just (snd previous, snd current)

phaseText :: Text -> Bool
phaseText value =
  phaseWidth value && phaseAsciiDigits value

phaseWidth :: Text -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PHASE_WIDTH_BYPASS_MUTANT)
phaseWidth _ = True
#else
phaseWidth value = Text.length value == 2
#endif

phaseAsciiDigits :: Text -> Bool
phaseAsciiDigits value =
  phaseAsciiDigitBypassed || Text.all phaseAsciiDigit value

phaseAsciiDigitBypassed :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PHASE_ASCII_DIGIT_BYPASS_MUTANT)
phaseAsciiDigitBypassed = True
#else
phaseAsciiDigitBypassed = False
#endif

phaseAsciiDigit :: Char -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_PHASE_ASCII_DIGIT_REMOVAL_MUTANT)
phaseAsciiDigit _ = False
#else
phaseAsciiDigit character = character >= '0' && character <= '9'
#endif

authorityText :: Text -> Bool
authorityText value =
  authorityNonempty value
    && authorityLength value
    && authorityCharacters value
 where
  authorityCharacters = authorityCharacterPredicate

authorityNonempty :: Text -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_AUTHORITY_NONEMPTY_BYPASS_MUTANT)
authorityNonempty _ = True
#else
authorityNonempty = not . Text.null
#endif

authorityLength :: Text -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_AUTHORITY_LENGTH_BYPASS_MUTANT)
authorityLength _ = True
#else
authorityLength value = Text.length value <= 128
#endif

authorityCharacterPredicate :: Text -> Bool
authorityCharacterPredicate value = authorityCharacterBypassed || Text.all authorized value
 where
  authorized character =
    authorityLower character
      || authorityUpper character
      || authorityDigit character
      || authorityDot character
      || authorityUnderscore character
      || authorityColon character
      || authorityHyphen character

authorityCharacterBypassed :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_AUTHORITY_CHARACTER_BYPASS_MUTANT)
authorityCharacterBypassed = True
#else
authorityCharacterBypassed = False
#endif

authorityLower :: Char -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_AUTHORITY_LOWER_RANGE_REMOVAL_MUTANT)
authorityLower _ = False
#else
authorityLower character = character >= 'a' && character <= 'z'
#endif

authorityUpper :: Char -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_AUTHORITY_UPPER_RANGE_REMOVAL_MUTANT)
authorityUpper _ = False
#else
authorityUpper character = character >= 'A' && character <= 'Z'
#endif

authorityDigit :: Char -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_AUTHORITY_DIGIT_RANGE_REMOVAL_MUTANT)
authorityDigit _ = False
#else
authorityDigit character = character >= '0' && character <= '9'
#endif

authorityDot :: Char -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_AUTHORITY_DOT_REMOVAL_MUTANT)
authorityDot _ = False
#else
authorityDot character = character == '.'
#endif

authorityUnderscore :: Char -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_AUTHORITY_UNDERSCORE_REMOVAL_MUTANT)
authorityUnderscore _ = False
#else
authorityUnderscore character = character == '_'
#endif

authorityColon :: Char -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_AUTHORITY_COLON_REMOVAL_MUTANT)
authorityColon _ = False
#else
authorityColon character = character == ':'
#endif

authorityHyphen :: Char -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_AUTHORITY_HYPHEN_REMOVAL_MUTANT)
authorityHyphen _ = False
#else
authorityHyphen character = character == '-'
#endif

-- The requested revision is an opaque, bounded protocol identifier joined
-- byte-for-byte to independently acquired intent and to an exact expected
-- HEAD. It is deliberately not a Git refname/revision-expression parser; the
-- eventual external acquisition authority must own resolution before signing.
-- This diagnostic supplies no such authority and retains that residue.
requestedRevisionText :: Text -> Bool
requestedRevisionText value =
  revisionNonempty value
    && revisionLength value
    && revisionCharacters value
    && revisionNotLeadingSlash value
    && revisionNotLeadingDash value
    && revisionNotLeadingDot value
    && revisionNotTrailingSlash value
    && revisionNotTrailingDot value
    && revisionNotTrailingLock value
    && revisionNoDoubleSlash value
    && revisionNoDoubleDot value
    && revisionNoReflogSyntax value

revisionNonempty :: Text -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_REVISION_NONEMPTY_BYPASS_MUTANT)
revisionNonempty _ = True
#else
revisionNonempty = not . Text.null
#endif

revisionLength :: Text -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_REVISION_LENGTH_BYPASS_MUTANT)
revisionLength _ = True
#else
revisionLength value = Text.length value <= 256
#endif

revisionCharacters :: Text -> Bool
revisionCharacters value = revisionCharactersBypassed || Text.all admitted value
 where
  admitted character =
    revisionLower character
      || revisionUpper character
      || revisionDigit character
      || revisionSlash character
      || revisionDot character
      || revisionUnderscore character
      || revisionAt character
      || revisionPlus character
      || revisionHyphen character
      || revisionOpenBrace character

revisionCharactersBypassed :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_REVISION_CHARACTER_BYPASS_MUTANT)
revisionCharactersBypassed = True
#else
revisionCharactersBypassed = False
#endif

revisionLower :: Char -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_REVISION_LOWER_RANGE_REMOVAL_MUTANT)
revisionLower _ = False
#else
revisionLower character = character >= 'a' && character <= 'z'
#endif

revisionUpper :: Char -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_REVISION_UPPER_RANGE_REMOVAL_MUTANT)
revisionUpper _ = False
#else
revisionUpper character = character >= 'A' && character <= 'Z'
#endif

revisionDigit :: Char -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_REVISION_DIGIT_RANGE_REMOVAL_MUTANT)
revisionDigit _ = False
#else
revisionDigit character = character >= '0' && character <= '9'
#endif

revisionSlash :: Char -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_REVISION_SLASH_REMOVAL_MUTANT)
revisionSlash _ = False
#else
revisionSlash character = character == '/'
#endif

revisionDot :: Char -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_REVISION_DOT_REMOVAL_MUTANT)
revisionDot _ = False
#else
revisionDot character = character == '.'
#endif

revisionUnderscore :: Char -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_REVISION_UNDERSCORE_REMOVAL_MUTANT)
revisionUnderscore _ = False
#else
revisionUnderscore character = character == '_'
#endif

revisionAt :: Char -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_REVISION_AT_REMOVAL_MUTANT)
revisionAt _ = False
#else
revisionAt character = character == '@'
#endif

revisionPlus :: Char -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_REVISION_PLUS_REMOVAL_MUTANT)
revisionPlus _ = False
#else
revisionPlus character = character == '+'
#endif

revisionHyphen :: Char -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_REVISION_HYPHEN_REMOVAL_MUTANT)
revisionHyphen _ = False
#else
revisionHyphen character = character == '-'
#endif

revisionOpenBrace :: Char -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_REVISION_OPEN_BRACE_REMOVAL_MUTANT)
revisionOpenBrace _ = False
#else
revisionOpenBrace character = character == '{'
#endif

revisionNotLeadingSlash :: Text -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_REVISION_LEADING_SLASH_BYPASS_MUTANT)
revisionNotLeadingSlash _ = True
#else
revisionNotLeadingSlash = not . Text.isPrefixOf "/"
#endif

revisionNotLeadingDash :: Text -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_REVISION_LEADING_DASH_BYPASS_MUTANT)
revisionNotLeadingDash _ = True
#else
revisionNotLeadingDash = not . Text.isPrefixOf "-"
#endif

revisionNotLeadingDot :: Text -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_REVISION_LEADING_DOT_BYPASS_MUTANT)
revisionNotLeadingDot _ = True
#else
revisionNotLeadingDot = not . Text.isPrefixOf "."
#endif

revisionNotTrailingSlash :: Text -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_REVISION_TRAILING_SLASH_BYPASS_MUTANT)
revisionNotTrailingSlash _ = True
#else
revisionNotTrailingSlash = not . Text.isSuffixOf "/"
#endif

revisionNotTrailingDot :: Text -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_REVISION_TRAILING_DOT_BYPASS_MUTANT)
revisionNotTrailingDot _ = True
#else
revisionNotTrailingDot = not . Text.isSuffixOf "."
#endif

revisionNotTrailingLock :: Text -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_REVISION_TRAILING_LOCK_BYPASS_MUTANT)
revisionNotTrailingLock _ = True
#else
revisionNotTrailingLock = not . Text.isSuffixOf ".lock"
#endif

revisionNoDoubleSlash :: Text -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_REVISION_DOUBLE_SLASH_BYPASS_MUTANT)
revisionNoDoubleSlash _ = True
#else
revisionNoDoubleSlash = not . Text.isInfixOf "//"
#endif

revisionNoDoubleDot :: Text -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_REVISION_DOUBLE_DOT_BYPASS_MUTANT)
revisionNoDoubleDot _ = True
#else
revisionNoDoubleDot = not . Text.isInfixOf ".."
#endif

revisionNoReflogSyntax :: Text -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_REVISION_REFLOG_BYPASS_MUTANT)
revisionNoReflogSyntax _ = True
#else
revisionNoReflogSyntax = not . Text.isInfixOf "@{"
#endif

gitObjectText :: GitObjectFormat -> Text -> Bool
gitObjectText objectFormat value =
  gitObjectTextWidth objectFormat value && gitObjectTextLowerHex value

gitObjectTextWidth :: GitObjectFormat -> Text -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_GIT_OBJECT_TEXT_WIDTH_BYPASS_MUTANT)
gitObjectTextWidth _ _ = True
#else
gitObjectTextWidth objectFormat value = Text.length value == expectedLength
 where
  expectedLength = case objectFormat of
    GitObjectSha1 -> 40
    GitObjectSha256 -> 64
#endif

gitObjectTextLowerHex :: Text -> Bool
gitObjectTextLowerHex value =
  gitObjectTextLowerHexBypassed
    || Text.all gitObjectTextLowerHexCharacter value

gitObjectTextLowerHexBypassed :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_GIT_OBJECT_TEXT_LOWER_HEX_BYPASS_MUTANT)
gitObjectTextLowerHexBypassed = True
#else
gitObjectTextLowerHexBypassed = False
#endif

gitObjectTextLowerHexCharacter :: Char -> Bool
gitObjectTextLowerHexCharacter character =
  gitObjectTextHexDigit character || gitObjectTextHexLower character

gitObjectTextHexDigit :: Char -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_GIT_OBJECT_TEXT_DIGIT_RANGE_REMOVAL_MUTANT)
gitObjectTextHexDigit _ = False
#else
gitObjectTextHexDigit character = character >= '0' && character <= '9'
#endif

gitObjectTextHexLower :: Char -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_GIT_OBJECT_TEXT_LOWER_RANGE_REMOVAL_MUTANT)
gitObjectTextHexLower _ = False
#else
gitObjectTextHexLower character = character >= 'a' && character <= 'f'
#endif

sha256Text :: Text -> Bool
sha256Text value = sha256TextWidth value && sha256TextLowerHex value

sha256TextWidth :: Text -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_SHA256_TEXT_WIDTH_BYPASS_MUTANT)
sha256TextWidth _ = True
#else
sha256TextWidth value = Text.length value == 64
#endif

sha256TextLowerHex :: Text -> Bool
sha256TextLowerHex value =
  sha256TextLowerHexBypassed
    || Text.all sha256LowerHexCharacter value

sha256TextLowerHexBypassed :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_SHA256_TEXT_LOWER_HEX_BYPASS_MUTANT)
sha256TextLowerHexBypassed = True
#else
sha256TextLowerHexBypassed = False
#endif

sha256LowerHexCharacter :: Char -> Bool
sha256LowerHexCharacter character =
  sha256HexDigit character || sha256HexLower character

sha256HexDigit :: Char -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_SHA256_TEXT_DIGIT_RANGE_REMOVAL_MUTANT)
sha256HexDigit _ = False
#else
sha256HexDigit character = character >= '0' && character <= '9'
#endif

sha256HexLower :: Char -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_SHA256_TEXT_LOWER_RANGE_REMOVAL_MUTANT)
sha256HexLower _ = False
#else
sha256HexLower character = character >= 'a' && character <= 'f'
#endif

bundleSha256 :: ByteString -> Text
#if defined(VALIDATION_SOURCE_ACQUISITION_BUNDLE_SHA256_ALGORITHM_MUTANT)
bundleSha256 bytes = Text.pack (show (Crypto.hash bytes :: Crypto.Digest Crypto.SHA1))
#else
bundleSha256 bytes = Text.pack (show (Crypto.hash bytes :: Crypto.Digest Crypto.SHA256))
#endif

computeBlobSha256 :: ByteString -> Text
#if defined(VALIDATION_SOURCE_ACQUISITION_BLOB_SHA256_ALGORITHM_MUTANT)
computeBlobSha256 bytes = Text.pack (show (Crypto.hash bytes :: Crypto.Digest Crypto.SHA1))
#else
computeBlobSha256 bytes = Text.pack (show (Crypto.hash bytes :: Crypto.Digest Crypto.SHA256))
#endif

frozenSnapshotSha256 :: ByteString -> Text
#if defined(VALIDATION_SOURCE_ACQUISITION_FROZEN_SNAPSHOT_SHA256_ALGORITHM_MUTANT)
frozenSnapshotSha256 bytes = Text.pack (show (Crypto.hash bytes :: Crypto.Digest Crypto.SHA1))
#else
frozenSnapshotSha256 bytes = Text.pack (show (Crypto.hash bytes :: Crypto.Digest Crypto.SHA256))
#endif

renderMode :: IndexMode -> Text
#if defined(VALIDATION_SOURCE_ACQUISITION_RENDER_MODE_REGULAR_MUTANT)
renderMode RegularFile = "000000"
#else
renderMode RegularFile = "100644"
#endif
#if defined(VALIDATION_SOURCE_ACQUISITION_RENDER_MODE_EXECUTABLE_MUTANT)
renderMode ExecutableFile = "000000"
#else
renderMode ExecutableFile = "100755"
#endif
#if defined(VALIDATION_SOURCE_ACQUISITION_RENDER_MODE_SYMBOLIC_LINK_MUTANT)
renderMode SymbolicLink = "000000"
#else
renderMode SymbolicLink = "120000"
#endif

modeBytes :: IndexMode -> ByteString
modeBytes = TextEncoding.encodeUtf8 . renderMode

renderObjectFormat :: GitObjectFormat -> Text
#if defined(VALIDATION_SOURCE_ACQUISITION_RENDER_OBJECT_FORMAT_SHA1_MUTANT)
renderObjectFormat GitObjectSha1 = "mutated-sha1"
#else
renderObjectFormat GitObjectSha1 = "sha1"
#endif
#if defined(VALIDATION_SOURCE_ACQUISITION_RENDER_OBJECT_FORMAT_SHA256_MUTANT)
renderObjectFormat GitObjectSha256 = "mutated-sha256"
#else
renderObjectFormat GitObjectSha256 = "sha256"
#endif

renderCustody :: SourceAcquisitionCustody -> Text
#if defined(VALIDATION_SOURCE_ACQUISITION_RENDER_CUSTODY_FROZEN_MUTANT)
renderCustody ExternallyFrozenReadOnlyBundle = "mutated-frozen-bundle"
#else
renderCustody ExternallyFrozenReadOnlyBundle = "externally-frozen-read-only-bundle"
#endif
renderCustody SequentialMutableBundle = "sequential-mutable-bundle"

duplicateValues :: Ord value => [value] -> [value]
duplicateValues values =
  Map.keys (Map.filter (> (1 :: Int)) (Map.fromListWith (+) [(value, 1 :: Int) | value <- values]))

-- Equality and ancestry are checked in the narrow portable case-folded name
-- space as well as in Git's byte-oriented space. Otherwise a signed bundle
-- could name two distinct Git entries that alias when materialized by a
-- case-insensitive consumer, or a file that aliases a directory prefix.
caseFoldPathCollisions :: [FilePath] -> [(FilePath, FilePath)]
caseFoldPathCollisions paths = concatMap collisions (Map.elems grouped)
 where
  grouped =
    Map.fromListWith (<>)
      [(collisionCaseFold path, [path]) | path <- paths]
  collisions originals = case sortBy compare originals of
    [] -> []
    first : rest -> [(first, later) | later <- rest, later /= first]

data PortablePathTrie = PortablePathTrie
  { portableTrieTerminal :: Bool
  , portableTrieChildren :: Map Text PortablePathTrie
  }

emptyPortablePathTrie :: PortablePathTrie
emptyPortablePathTrie = PortablePathTrie False Map.empty

prefixPathConflicts :: [FilePath] -> [FilePath]
prefixPathConflicts paths = reverse conflicts
 where
  ordered =
    sortBy
      (\left right -> compare (prefixCaseFold left, left) (prefixCaseFold right, right))
      paths
  (_, conflicts) = foldl' insertOne (emptyPortablePathTrie, []) ordered
  insertOne (trie, found) path =
    let parts = Text.splitOn "/" (prefixCaseFold path)
        (updated, conflictsWithAncestor) = insertPortablePath parts trie
     in (updated, [path | conflictsWithAncestor] <> found)

insertPortablePath :: [Text] -> PortablePathTrie -> (PortablePathTrie, Bool)
insertPortablePath parts trie
  | portableTrieTerminal trie && not (null parts) = (trie, True)
  | otherwise = case parts of
      [] -> (trie {portableTrieTerminal = True}, False)
      part : rest ->
        let child = Map.findWithDefault emptyPortablePathTrie part (portableTrieChildren trie)
            (updatedChild, conflict) = insertPortablePath rest child
            updated =
              trie
                { portableTrieChildren =
                    Map.insert part updatedChild (portableTrieChildren trie)
                }
         in (updated, conflict)

portableCaseFold :: FilePath -> Text
portableCaseFold = Text.toLower . Text.pack

collisionCaseFold :: FilePath -> Text
#if defined(VALIDATION_SOURCE_ACQUISITION_PATH_COLLISION_CASE_FOLD_MAPPING_MUTANT)
collisionCaseFold = Text.pack
#else
collisionCaseFold = portableCaseFold
#endif

prefixCaseFold :: FilePath -> Text
#if defined(VALIDATION_SOURCE_ACQUISITION_PATH_PREFIX_CASE_FOLD_MAPPING_MUTANT)
prefixCaseFold = Text.pack
#else
prefixCaseFold = portableCaseFold
#endif

sourceAcquisitionDiagnostic
  :: Text
  -> Text
  -> Text
  -> Text
  -> Set Text
  -> Text
  -> Text
  -> Text
  -> Text
  -> Text
  -> ByteString
  -> ByteString
  -> ByteString
  -> ByteString
  -> CheckResult
sourceAcquisitionDiagnostic
  expectedPhase
  expectedAuthority
  expectedObserverToolDigest
  expectedChallenge
  consumedReplayIdentities
  expectedRepositoryIdentity
  expectedRequestedRevision
  expectedHeadIdentity
  expectedSourceSnapshotIdentity
  expectedAuthoredRootIdentity
  expectedManifestBytes
  publicKey
  wire
  bundle =
  CheckResult
    { checkName = sourceAcquisitionCheckName
    , checkObservations =
        orderResultObservations
          ( [ observation integrityObservationKey (renderIntegrityObservation verification)
            | retainIntegrityObservation
            ]
              <> retainedManifestObservations verification
          )
    , checkFindings =
        composeResultFindings
          (retainedProblemFindings verification)
          diagnosticResidue
    }
 where
  expected =
    SourceAcquisitionExpectation
      { expectedAcquisitionPhase = expectedInputText ExpectedInputPhase expectedPhase
      , expectedAcquisitionAuthority = expectedInputText ExpectedInputAuthority expectedAuthority
      , expectedAcquisitionObserverToolDigest = expectedInputText ExpectedInputObserverTool expectedObserverToolDigest
      , expectedAcquisitionChallenge = expectedInputText ExpectedInputChallenge expectedChallenge
      , consumedAcquisitionReplayIdentities = expectedInputReplaySet consumedReplayIdentities
      , expectedAcquisitionRepositoryIdentity = expectedInputText ExpectedInputRepository expectedRepositoryIdentity
      , expectedAcquisitionRequestedRevision = expectedInputText ExpectedInputRequestedRevision expectedRequestedRevision
      , expectedAcquisitionHeadIdentity = expectedInputText ExpectedInputHead expectedHeadIdentity
      , expectedAcquisitionSourceSnapshotIdentity = expectedInputText ExpectedInputSourceSnapshot expectedSourceSnapshotIdentity
      , expectedAcquisitionAuthoredRootIdentity = expectedInputText ExpectedInputAuthoredRoot expectedAuthoredRootIdentity
      }
  verification =
    verifySourceAcquisitionDiagnostic
      expected
      (routedExpectedManifestBytes expectedManifestBytes)
      (routedPublicKeyBytes publicKey)
      (routedWireBytes wire)
      (routedBundleBytes bundle)

data ExpectedInputTextSlot
  = ExpectedInputPhase
  | ExpectedInputAuthority
  | ExpectedInputObserverTool
  | ExpectedInputChallenge
  | ExpectedInputRepository
  | ExpectedInputRequestedRevision
  | ExpectedInputHead
  | ExpectedInputSourceSnapshot
  | ExpectedInputAuthoredRoot
  deriving (Eq, Ord, Show)

expectedInputText :: ExpectedInputTextSlot -> Text -> Text
expectedInputText slot value
  | mutateExpectedInputText slot = value <> "mutated"
  | otherwise = value

mutateExpectedInputText :: ExpectedInputTextSlot -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_INPUT_PHASE_MAPPING_MUTANT)
mutateExpectedInputText slot = slot == ExpectedInputPhase
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_INPUT_AUTHORITY_MAPPING_MUTANT)
mutateExpectedInputText slot = slot == ExpectedInputAuthority
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_INPUT_OBSERVER_TOOL_MAPPING_MUTANT)
mutateExpectedInputText slot = slot == ExpectedInputObserverTool
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_INPUT_CHALLENGE_MAPPING_MUTANT)
mutateExpectedInputText slot = slot == ExpectedInputChallenge
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_INPUT_REPOSITORY_MAPPING_MUTANT)
mutateExpectedInputText slot = slot == ExpectedInputRepository
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_INPUT_REQUESTED_REVISION_MAPPING_MUTANT)
mutateExpectedInputText slot = slot == ExpectedInputRequestedRevision
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_INPUT_HEAD_MAPPING_MUTANT)
mutateExpectedInputText slot = slot == ExpectedInputHead
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_INPUT_SOURCE_SNAPSHOT_MAPPING_MUTANT)
mutateExpectedInputText slot = slot == ExpectedInputSourceSnapshot
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_INPUT_AUTHORED_ROOT_MAPPING_MUTANT)
mutateExpectedInputText slot = slot == ExpectedInputAuthoredRoot
#else
mutateExpectedInputText slot = slot `seq` False
#endif

expectedInputReplaySet :: Set Text -> Set Text
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_INPUT_REPLAY_SET_MAPPING_MUTANT)
expectedInputReplaySet values = values `seq` Set.empty
#else
expectedInputReplaySet = id
#endif

routedExpectedManifestBytes :: ByteString -> ByteString
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_INPUT_ROUTE_MUTANT)
routedExpectedManifestBytes bytes = bytes <> "mutated"
#else
routedExpectedManifestBytes = id
#endif

routedPublicKeyBytes :: ByteString -> ByteString
#if defined(VALIDATION_SOURCE_ACQUISITION_PUBLIC_KEY_INPUT_ROUTE_MUTANT)
routedPublicKeyBytes bytes = bytes <> "mutated"
#else
routedPublicKeyBytes = id
#endif

routedWireBytes :: ByteString -> ByteString
#if defined(VALIDATION_SOURCE_ACQUISITION_WIRE_INPUT_ROUTE_MUTANT)
routedWireBytes = ByteString.drop 1
#else
routedWireBytes = id
#endif

routedBundleBytes :: ByteString -> ByteString
#if defined(VALIDATION_SOURCE_ACQUISITION_BUNDLE_INPUT_ROUTE_MUTANT)
routedBundleBytes bytes = bytes <> "mutated"
#else
routedBundleBytes = id
#endif

sourceAcquisitionCheckName :: Text
#if defined(VALIDATION_SOURCE_ACQUISITION_RESULT_CHECK_NAME_MUTANT)
sourceAcquisitionCheckName = "source-acquisition-mutated"
#else
sourceAcquisitionCheckName = "source-acquisition-diagnostic"
#endif

retainIntegrityObservation :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_INTEGRITY_OBSERVATION_DROP_MUTANT)
retainIntegrityObservation = False
#else
retainIntegrityObservation = True
#endif

integrityObservationKey :: Text
#if defined(VALIDATION_SOURCE_ACQUISITION_INTEGRITY_OBSERVATION_KEY_MAPPING_MUTANT)
integrityObservationKey = "source-acquisition.mutated-integrity"
#else
integrityObservationKey = "source-acquisition.integrity"
#endif

renderIntegrityObservation
  :: Either [SourceAcquisitionProblem] SourceAcquisitionManifest
  -> Text
renderIntegrityObservation verification = case verification of
#if defined(VALIDATION_SOURCE_ACQUISITION_INTEGRITY_SUCCESS_VALUE_MUTANT)
  Right _ -> "internally consistent diagnostic"
#else
  Right _ -> "internally consistent diagnostic; candidate authority absent"
#endif
#if defined(VALIDATION_SOURCE_ACQUISITION_INTEGRITY_FAILURE_VALUE_MUTANT)
  Left problems -> problems `seq` "refused"
#else
  Left problems ->
    "refused with "
      <> showText (length (boundedResultProblems problems))
      <> " integrity finding(s)"
#endif

retainedManifestObservations
  :: Either [SourceAcquisitionProblem] SourceAcquisitionManifest
  -> [Observation]
#if defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_OBSERVATION_ROUTE_DROP_MUTANT)
retainedManifestObservations verification =
  manifestObservations `seq` verification `seq` []
#else
retainedManifestObservations = either (const []) manifestObservations
#endif

retainedProblemFindings
  :: Either [SourceAcquisitionProblem] SourceAcquisitionManifest
  -> [Finding]
#if defined(VALIDATION_SOURCE_ACQUISITION_PROBLEM_FINDING_CARRIER_DROP_MUTANT)
retainedProblemFindings verification = problemFinding `seq` verification `seq` []
#elif defined(VALIDATION_SOURCE_ACQUISITION_PROBLEM_FINDING_ORDER_MUTANT)
retainedProblemFindings = either (reverse . map problemFinding . boundedResultProblems) (const [])
#else
retainedProblemFindings = either (map problemFinding . boundedResultProblems) (const [])
#endif

boundedResultProblems
  :: [SourceAcquisitionProblem]
  -> [SourceAcquisitionProblem]
boundedResultProblems problems
  | observedAtLeast > maximumResultProblemFindings =
      [SourceAcquisitionProblemLimitExceeded maximumResultProblemFindings observedAtLeast]
  | otherwise = prefix
 where
  prefix = take (maximumResultProblemFindings + 1) problems
  observedAtLeast = length prefix

composeResultFindings :: [Finding] -> [Finding] -> [Finding]
#if defined(VALIDATION_SOURCE_ACQUISITION_RESULT_FINDING_ORDER_MUTANT)
composeResultFindings problems residue =
  maximumResultFindings `seq` (residue <> problems)
#else
composeResultFindings problems residue =
  maximumResultFindings `seq` (problems <> residue)
#endif

orderResultObservations :: [Observation] -> [Observation]
#if defined(VALIDATION_SOURCE_ACQUISITION_RESULT_OBSERVATION_ORDER_MUTANT)
orderResultObservations values = maximumResultObservations `seq` reverse values
#else
orderResultObservations values = maximumResultObservations `seq` values
#endif

data ManifestObservationSlot
  = ManifestSchemaObservation
  | ManifestPhaseObservation
  | ManifestAuthorityObservation
  | ManifestObserverToolObservation
  | ManifestChallengeObservation
  | ManifestReplayIdentityObservation
  | ManifestRepositoryObservation
  | ManifestRequestedRevisionObservation
  | ManifestCustodyObservation
  | ManifestObjectFormatObservation
  | ManifestHeadObservation
  | ManifestTreeObservation
  | ManifestAuthoredRootObservation
  | ManifestFrozenSnapshotObservation
  | ManifestBundleObservation
  | ManifestSourceSnapshotObservation
  | ManifestCommitByteCountObservation
  | ManifestEntryCountObservation
  deriving (Eq, Ord, Show)

retainManifestObservation :: ManifestObservationSlot -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_SCHEMA_OBSERVATION_DROP_MUTANT)
retainManifestObservation slot = slot /= ManifestSchemaObservation
#elif defined(VALIDATION_SOURCE_ACQUISITION_PHASE_OBSERVATION_DROP_MUTANT)
retainManifestObservation slot = slot /= ManifestPhaseObservation
#elif defined(VALIDATION_SOURCE_ACQUISITION_AUTHORITY_OBSERVATION_DROP_MUTANT)
retainManifestObservation slot = slot /= ManifestAuthorityObservation
#elif defined(VALIDATION_SOURCE_ACQUISITION_OBSERVER_TOOL_OBSERVATION_DROP_MUTANT)
retainManifestObservation slot = slot /= ManifestObserverToolObservation
#elif defined(VALIDATION_SOURCE_ACQUISITION_CHALLENGE_OBSERVATION_DROP_MUTANT)
retainManifestObservation slot = slot /= ManifestChallengeObservation
#elif defined(VALIDATION_SOURCE_ACQUISITION_REPLAY_IDENTITY_OBSERVATION_DROP_MUTANT)
retainManifestObservation slot = slot /= ManifestReplayIdentityObservation
#elif defined(VALIDATION_SOURCE_ACQUISITION_REPOSITORY_OBSERVATION_DROP_MUTANT)
retainManifestObservation slot = slot /= ManifestRepositoryObservation
#elif defined(VALIDATION_SOURCE_ACQUISITION_REQUESTED_REVISION_OBSERVATION_DROP_MUTANT)
retainManifestObservation slot = slot /= ManifestRequestedRevisionObservation
#elif defined(VALIDATION_SOURCE_ACQUISITION_CUSTODY_OBSERVATION_DROP_MUTANT)
retainManifestObservation slot = slot /= ManifestCustodyObservation
#elif defined(VALIDATION_SOURCE_ACQUISITION_OBJECT_FORMAT_OBSERVATION_DROP_MUTANT)
retainManifestObservation slot = slot /= ManifestObjectFormatObservation
#elif defined(VALIDATION_SOURCE_ACQUISITION_HEAD_OBSERVATION_DROP_MUTANT)
retainManifestObservation slot = slot /= ManifestHeadObservation
#elif defined(VALIDATION_SOURCE_ACQUISITION_TREE_OBSERVATION_DROP_MUTANT)
retainManifestObservation slot = slot /= ManifestTreeObservation
#elif defined(VALIDATION_SOURCE_ACQUISITION_AUTHORED_ROOT_OBSERVATION_DROP_MUTANT)
retainManifestObservation slot = slot /= ManifestAuthoredRootObservation
#elif defined(VALIDATION_SOURCE_ACQUISITION_FROZEN_SNAPSHOT_OBSERVATION_DROP_MUTANT)
retainManifestObservation slot = slot /= ManifestFrozenSnapshotObservation
#elif defined(VALIDATION_SOURCE_ACQUISITION_BUNDLE_OBSERVATION_DROP_MUTANT)
retainManifestObservation slot = slot /= ManifestBundleObservation
#elif defined(VALIDATION_SOURCE_ACQUISITION_SOURCE_SNAPSHOT_OBSERVATION_DROP_MUTANT)
retainManifestObservation slot = slot /= ManifestSourceSnapshotObservation
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_BYTE_COUNT_OBSERVATION_DROP_MUTANT)
retainManifestObservation slot = slot /= ManifestCommitByteCountObservation
#elif defined(VALIDATION_SOURCE_ACQUISITION_ENTRY_COUNT_OBSERVATION_DROP_MUTANT)
retainManifestObservation slot = slot /= ManifestEntryCountObservation
#else
retainManifestObservation slot = slot `seq` True
#endif

manifestObservations :: SourceAcquisitionManifest -> [Observation]
manifestObservations manifest =
  [ mutateManifestObservation slot rendered
  | (slot, rendered) <- manifestObservationTable manifest
  , retainManifestObservation slot
  ]

mutateManifestObservation :: ManifestObservationSlot -> Observation -> Observation
mutateManifestObservation slot (Observation key value) =
  observation
    (manifestObservationKey slot key)
    ( maximumObservationValueUtf8Bytes
        `seq` manifestObservationValue slot value
    )

manifestObservationTable
  :: SourceAcquisitionManifest
  -> [(ManifestObservationSlot, Observation)]
manifestObservationKey :: ManifestObservationSlot -> Text -> Text
#if defined(VALIDATION_SOURCE_ACQUISITION_SCHEMA_OBSERVATION_KEY_MAPPING_MUTANT)
manifestObservationKey slot value
  | slot == ManifestSchemaObservation = "source-acquisition.mutated-key"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_PHASE_OBSERVATION_KEY_MAPPING_MUTANT)
manifestObservationKey slot value
  | slot == ManifestPhaseObservation = "source-acquisition.mutated-key"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_AUTHORITY_OBSERVATION_KEY_MAPPING_MUTANT)
manifestObservationKey slot value
  | slot == ManifestAuthorityObservation = "source-acquisition.mutated-key"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_OBSERVER_TOOL_OBSERVATION_KEY_MAPPING_MUTANT)
manifestObservationKey slot value
  | slot == ManifestObserverToolObservation = "source-acquisition.mutated-key"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_CHALLENGE_OBSERVATION_KEY_MAPPING_MUTANT)
manifestObservationKey slot value
  | slot == ManifestChallengeObservation = "source-acquisition.mutated-key"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_REPLAY_IDENTITY_OBSERVATION_KEY_MAPPING_MUTANT)
manifestObservationKey slot value
  | slot == ManifestReplayIdentityObservation = "source-acquisition.mutated-key"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_REPOSITORY_OBSERVATION_KEY_MAPPING_MUTANT)
manifestObservationKey slot value
  | slot == ManifestRepositoryObservation = "source-acquisition.mutated-key"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_REQUESTED_REVISION_OBSERVATION_KEY_MAPPING_MUTANT)
manifestObservationKey slot value
  | slot == ManifestRequestedRevisionObservation = "source-acquisition.mutated-key"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_CUSTODY_OBSERVATION_KEY_MAPPING_MUTANT)
manifestObservationKey slot value
  | slot == ManifestCustodyObservation = "source-acquisition.mutated-key"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_OBJECT_FORMAT_OBSERVATION_KEY_MAPPING_MUTANT)
manifestObservationKey slot value
  | slot == ManifestObjectFormatObservation = "source-acquisition.mutated-key"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_HEAD_OBSERVATION_KEY_MAPPING_MUTANT)
manifestObservationKey slot value
  | slot == ManifestHeadObservation = "source-acquisition.mutated-key"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_TREE_OBSERVATION_KEY_MAPPING_MUTANT)
manifestObservationKey slot value
  | slot == ManifestTreeObservation = "source-acquisition.mutated-key"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_AUTHORED_ROOT_OBSERVATION_KEY_MAPPING_MUTANT)
manifestObservationKey slot value
  | slot == ManifestAuthoredRootObservation = "source-acquisition.mutated-key"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_FROZEN_SNAPSHOT_OBSERVATION_KEY_MAPPING_MUTANT)
manifestObservationKey slot value
  | slot == ManifestFrozenSnapshotObservation = "source-acquisition.mutated-key"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_BUNDLE_OBSERVATION_KEY_MAPPING_MUTANT)
manifestObservationKey slot value
  | slot == ManifestBundleObservation = "source-acquisition.mutated-key"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_SOURCE_SNAPSHOT_OBSERVATION_KEY_MAPPING_MUTANT)
manifestObservationKey slot value
  | slot == ManifestSourceSnapshotObservation = "source-acquisition.mutated-key"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_BYTE_COUNT_OBSERVATION_KEY_MAPPING_MUTANT)
manifestObservationKey slot value
  | slot == ManifestCommitByteCountObservation = "source-acquisition.mutated-key"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_ENTRY_COUNT_OBSERVATION_KEY_MAPPING_MUTANT)
manifestObservationKey slot value
  | slot == ManifestEntryCountObservation = "source-acquisition.mutated-key"
  | otherwise = value
#else
manifestObservationKey slot value = slot `seq` value
#endif

manifestObservationValue :: ManifestObservationSlot -> Text -> Text
#if defined(VALIDATION_SOURCE_ACQUISITION_SCHEMA_OBSERVATION_VALUE_MAPPING_MUTANT)
manifestObservationValue slot value
  | slot == ManifestSchemaObservation = "mutated-observation-value"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_PHASE_OBSERVATION_VALUE_MAPPING_MUTANT)
manifestObservationValue slot value
  | slot == ManifestPhaseObservation = "mutated-observation-value"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_AUTHORITY_OBSERVATION_VALUE_MAPPING_MUTANT)
manifestObservationValue slot value
  | slot == ManifestAuthorityObservation = "mutated-observation-value"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_OBSERVER_TOOL_OBSERVATION_VALUE_MAPPING_MUTANT)
manifestObservationValue slot value
  | slot == ManifestObserverToolObservation = "mutated-observation-value"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_CHALLENGE_OBSERVATION_VALUE_MAPPING_MUTANT)
manifestObservationValue slot value
  | slot == ManifestChallengeObservation = "mutated-observation-value"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_REPLAY_IDENTITY_OBSERVATION_VALUE_MAPPING_MUTANT)
manifestObservationValue slot value
  | slot == ManifestReplayIdentityObservation = "mutated-observation-value"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_REPOSITORY_OBSERVATION_VALUE_MAPPING_MUTANT)
manifestObservationValue slot value
  | slot == ManifestRepositoryObservation = "mutated-observation-value"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_REQUESTED_REVISION_OBSERVATION_VALUE_MAPPING_MUTANT)
manifestObservationValue slot value
  | slot == ManifestRequestedRevisionObservation = "mutated-observation-value"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_CUSTODY_OBSERVATION_VALUE_MAPPING_MUTANT)
manifestObservationValue slot value
  | slot == ManifestCustodyObservation = "mutated-observation-value"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_OBJECT_FORMAT_OBSERVATION_VALUE_MAPPING_MUTANT)
manifestObservationValue slot value
  | slot == ManifestObjectFormatObservation = "mutated-observation-value"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_HEAD_OBSERVATION_VALUE_MAPPING_MUTANT)
manifestObservationValue slot value
  | slot == ManifestHeadObservation = "mutated-observation-value"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_TREE_OBSERVATION_VALUE_MAPPING_MUTANT)
manifestObservationValue slot value
  | slot == ManifestTreeObservation = "mutated-observation-value"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_AUTHORED_ROOT_OBSERVATION_VALUE_MAPPING_MUTANT)
manifestObservationValue slot value
  | slot == ManifestAuthoredRootObservation = "mutated-observation-value"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_FROZEN_SNAPSHOT_OBSERVATION_VALUE_MAPPING_MUTANT)
manifestObservationValue slot value
  | slot == ManifestFrozenSnapshotObservation = "mutated-observation-value"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_BUNDLE_OBSERVATION_VALUE_MAPPING_MUTANT)
manifestObservationValue slot value
  | slot == ManifestBundleObservation = "mutated-observation-value"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_SOURCE_SNAPSHOT_OBSERVATION_VALUE_MAPPING_MUTANT)
manifestObservationValue slot value
  | slot == ManifestSourceSnapshotObservation = "mutated-observation-value"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_BYTE_COUNT_OBSERVATION_VALUE_MAPPING_MUTANT)
manifestObservationValue slot value
  | slot == ManifestCommitByteCountObservation = "mutated-observation-value"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_ENTRY_COUNT_OBSERVATION_VALUE_MAPPING_MUTANT)
manifestObservationValue slot value
  | slot == ManifestEntryCountObservation = "mutated-observation-value"
  | otherwise = value
#else
manifestObservationValue slot value = slot `seq` value
#endif


manifestObservationTable manifest =
  [ (ManifestSchemaObservation, observation "source-acquisition.schema" "amoebius-source-acquisition-v2")
  , (ManifestPhaseObservation, observation "source-acquisition.phase" (acquisitionPhase manifest))
  , (ManifestAuthorityObservation, observation "source-acquisition.authority" (acquisitionAuthority manifest))
  , (ManifestObserverToolObservation, observation "source-acquisition.observer-tool" (acquisitionObserverToolDigest manifest))
  , (ManifestChallengeObservation, observation "source-acquisition.challenge" (acquisitionChallenge manifest))
  , (ManifestReplayIdentityObservation, observation "source-acquisition.replay-identity" (acquisitionReplayIdentity manifest))
  , (ManifestRepositoryObservation, observation "source-acquisition.repository" (acquisitionRepositoryIdentity manifest))
  , (ManifestRequestedRevisionObservation, observation "source-acquisition.requested-revision" (acquisitionRequestedRevision manifest))
  , (ManifestCustodyObservation, observation "source-acquisition.custody" (renderCustody (acquisitionCustody manifest)))
  , (ManifestObjectFormatObservation, observation "source-acquisition.object-format" (renderObjectFormat (acquisitionObjectFormat manifest)))
  , (ManifestHeadObservation, observation "source-acquisition.head" (acquisitionHeadIdentity manifest))
  , (ManifestTreeObservation, observation "source-acquisition.tree" (acquisitionTreeIdentity manifest))
  , (ManifestAuthoredRootObservation, observation "source-acquisition.authored-root" (acquisitionAuthoredRootIdentity manifest))
  , (ManifestFrozenSnapshotObservation, observation "source-acquisition.frozen-snapshot" (acquisitionFrozenSnapshotIdentity manifest))
  , (ManifestBundleObservation, observation "source-acquisition.bundle" (acquisitionBundleIdentity manifest))
  , (ManifestSourceSnapshotObservation, observation "source-acquisition.source-snapshot" (acquisitionSourceSnapshotIdentity manifest))
  , (ManifestCommitByteCountObservation, observation "source-acquisition.commit-byte-count" (showText (ByteString.length (acquisitionCommitBytes manifest))))
  , (ManifestEntryCountObservation, observation "source-acquisition.entry-count" (showText (length (acquisitionEntries manifest))))
  ]

diagnosticResidue :: [Finding]
diagnosticResidue
  -- This compound challenge deliberately makes an internally consistent
  -- diagnostic green.  The independent row selectors below prove that the
  -- oracle also observes omission of each refusal in isolation.
  | removeAllDiagnosticResidue = []
  | otherwise =
      orderDiagnosticResidue
        ( diagnosticAuthorityResidue
            <> [ mutateDiagnosticResidue slot residue
               | (keepResidue, slot, residue) <- diagnosticResidueRetentionTable
               , keepResidue
               ]
        )

data DiagnosticResidueSlot
  = ResidueDiagnosticAuthority
  | ResidueExpectedIntent
  | ResidueSessionCustody
  | ResidueObserverExecution
  | ResidueKeyRoleSeparation
  | ResidueStreamingIngress
  | ResidueDispatcherComposition
  | ResidueTrustAnchor
  | ResidueReplayState
  | ResidueAuthoredRootObservation
  | ResidueCustodyObservation
  | ResidueOracleQualification
  deriving (Eq, Ord, Show)

mutateDiagnosticResidue :: DiagnosticResidueSlot -> Finding -> Finding
mutateDiagnosticResidue slot (Finding code subject detail) =
  finding
    (diagnosticResidueCode slot code)
    (diagnosticResidueSubject slot subject)
    (diagnosticResidueDetail slot detail)

diagnosticResidueCode :: DiagnosticResidueSlot -> Text -> Text
#if defined(VALIDATION_SOURCE_ACQUISITION_DIAGNOSTIC_AUTHORITY_RESIDUE_CODE_MAPPING_MUTANT)
diagnosticResidueCode slot value
  | slot == ResidueDiagnosticAuthority = "SOURCE-ACQUISITION-MUTATED-RESIDUE-CODE"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_INTENT_RESIDUE_CODE_MAPPING_MUTANT)
diagnosticResidueCode slot value
  | slot == ResidueExpectedIntent = "SOURCE-ACQUISITION-MUTATED-RESIDUE-CODE"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_SESSION_CUSTODY_RESIDUE_CODE_MAPPING_MUTANT)
diagnosticResidueCode slot value
  | slot == ResidueSessionCustody = "SOURCE-ACQUISITION-MUTATED-RESIDUE-CODE"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_OBSERVER_EXECUTION_RESIDUE_CODE_MAPPING_MUTANT)
diagnosticResidueCode slot value
  | slot == ResidueObserverExecution = "SOURCE-ACQUISITION-MUTATED-RESIDUE-CODE"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_KEY_ROLE_SEPARATION_RESIDUE_CODE_MAPPING_MUTANT)
diagnosticResidueCode slot value
  | slot == ResidueKeyRoleSeparation = "SOURCE-ACQUISITION-MUTATED-RESIDUE-CODE"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_STREAMING_INGRESS_RESIDUE_CODE_MAPPING_MUTANT)
diagnosticResidueCode slot value
  | slot == ResidueStreamingIngress = "SOURCE-ACQUISITION-MUTATED-RESIDUE-CODE"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_DISPATCHER_COMPOSITION_RESIDUE_CODE_MAPPING_MUTANT)
diagnosticResidueCode slot value
  | slot == ResidueDispatcherComposition = "SOURCE-ACQUISITION-MUTATED-RESIDUE-CODE"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_TRUST_ANCHOR_RESIDUE_CODE_MAPPING_MUTANT)
diagnosticResidueCode slot value
  | slot == ResidueTrustAnchor = "SOURCE-ACQUISITION-MUTATED-RESIDUE-CODE"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_REPLAY_STATE_RESIDUE_CODE_MAPPING_MUTANT)
diagnosticResidueCode slot value
  | slot == ResidueReplayState = "SOURCE-ACQUISITION-MUTATED-RESIDUE-CODE"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_AUTHORED_ROOT_OBSERVATION_RESIDUE_CODE_MAPPING_MUTANT)
diagnosticResidueCode slot value
  | slot == ResidueAuthoredRootObservation = "SOURCE-ACQUISITION-MUTATED-RESIDUE-CODE"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_CUSTODY_OBSERVATION_RESIDUE_CODE_MAPPING_MUTANT)
diagnosticResidueCode slot value
  | slot == ResidueCustodyObservation = "SOURCE-ACQUISITION-MUTATED-RESIDUE-CODE"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_ORACLE_QUALIFICATION_RESIDUE_CODE_MAPPING_MUTANT)
diagnosticResidueCode slot value
  | slot == ResidueOracleQualification = "SOURCE-ACQUISITION-MUTATED-RESIDUE-CODE"
  | otherwise = value
#else
diagnosticResidueCode slot value = slot `seq` value
#endif

diagnosticResidueSubject :: DiagnosticResidueSlot -> FilePath -> FilePath
#if defined(VALIDATION_SOURCE_ACQUISITION_DIAGNOSTIC_AUTHORITY_RESIDUE_SUBJECT_MAPPING_MUTANT)
diagnosticResidueSubject slot value
  | slot == ResidueDiagnosticAuthority = "source-acquisition-mutated-residue-subject"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_INTENT_RESIDUE_SUBJECT_MAPPING_MUTANT)
diagnosticResidueSubject slot value
  | slot == ResidueExpectedIntent = "source-acquisition-mutated-residue-subject"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_SESSION_CUSTODY_RESIDUE_SUBJECT_MAPPING_MUTANT)
diagnosticResidueSubject slot value
  | slot == ResidueSessionCustody = "source-acquisition-mutated-residue-subject"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_OBSERVER_EXECUTION_RESIDUE_SUBJECT_MAPPING_MUTANT)
diagnosticResidueSubject slot value
  | slot == ResidueObserverExecution = "source-acquisition-mutated-residue-subject"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_KEY_ROLE_SEPARATION_RESIDUE_SUBJECT_MAPPING_MUTANT)
diagnosticResidueSubject slot value
  | slot == ResidueKeyRoleSeparation = "source-acquisition-mutated-residue-subject"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_STREAMING_INGRESS_RESIDUE_SUBJECT_MAPPING_MUTANT)
diagnosticResidueSubject slot value
  | slot == ResidueStreamingIngress = "source-acquisition-mutated-residue-subject"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_DISPATCHER_COMPOSITION_RESIDUE_SUBJECT_MAPPING_MUTANT)
diagnosticResidueSubject slot value
  | slot == ResidueDispatcherComposition = "source-acquisition-mutated-residue-subject"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_TRUST_ANCHOR_RESIDUE_SUBJECT_MAPPING_MUTANT)
diagnosticResidueSubject slot value
  | slot == ResidueTrustAnchor = "source-acquisition-mutated-residue-subject"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_REPLAY_STATE_RESIDUE_SUBJECT_MAPPING_MUTANT)
diagnosticResidueSubject slot value
  | slot == ResidueReplayState = "source-acquisition-mutated-residue-subject"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_AUTHORED_ROOT_OBSERVATION_RESIDUE_SUBJECT_MAPPING_MUTANT)
diagnosticResidueSubject slot value
  | slot == ResidueAuthoredRootObservation = "source-acquisition-mutated-residue-subject"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_CUSTODY_OBSERVATION_RESIDUE_SUBJECT_MAPPING_MUTANT)
diagnosticResidueSubject slot value
  | slot == ResidueCustodyObservation = "source-acquisition-mutated-residue-subject"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_ORACLE_QUALIFICATION_RESIDUE_SUBJECT_MAPPING_MUTANT)
diagnosticResidueSubject slot value
  | slot == ResidueOracleQualification = "source-acquisition-mutated-residue-subject"
  | otherwise = value
#else
diagnosticResidueSubject slot value = slot `seq` value
#endif

diagnosticResidueDetail :: DiagnosticResidueSlot -> Text -> Text
#if defined(VALIDATION_SOURCE_ACQUISITION_DIAGNOSTIC_AUTHORITY_RESIDUE_DETAIL_MAPPING_MUTANT)
diagnosticResidueDetail slot value
  | slot == ResidueDiagnosticAuthority = "mutated residue detail"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_INTENT_RESIDUE_DETAIL_MAPPING_MUTANT)
diagnosticResidueDetail slot value
  | slot == ResidueExpectedIntent = "mutated residue detail"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_SESSION_CUSTODY_RESIDUE_DETAIL_MAPPING_MUTANT)
diagnosticResidueDetail slot value
  | slot == ResidueSessionCustody = "mutated residue detail"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_OBSERVER_EXECUTION_RESIDUE_DETAIL_MAPPING_MUTANT)
diagnosticResidueDetail slot value
  | slot == ResidueObserverExecution = "mutated residue detail"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_KEY_ROLE_SEPARATION_RESIDUE_DETAIL_MAPPING_MUTANT)
diagnosticResidueDetail slot value
  | slot == ResidueKeyRoleSeparation = "mutated residue detail"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_STREAMING_INGRESS_RESIDUE_DETAIL_MAPPING_MUTANT)
diagnosticResidueDetail slot value
  | slot == ResidueStreamingIngress = "mutated residue detail"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_DISPATCHER_COMPOSITION_RESIDUE_DETAIL_MAPPING_MUTANT)
diagnosticResidueDetail slot value
  | slot == ResidueDispatcherComposition = "mutated residue detail"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_TRUST_ANCHOR_RESIDUE_DETAIL_MAPPING_MUTANT)
diagnosticResidueDetail slot value
  | slot == ResidueTrustAnchor = "mutated residue detail"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_REPLAY_STATE_RESIDUE_DETAIL_MAPPING_MUTANT)
diagnosticResidueDetail slot value
  | slot == ResidueReplayState = "mutated residue detail"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_AUTHORED_ROOT_OBSERVATION_RESIDUE_DETAIL_MAPPING_MUTANT)
diagnosticResidueDetail slot value
  | slot == ResidueAuthoredRootObservation = "mutated residue detail"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_CUSTODY_OBSERVATION_RESIDUE_DETAIL_MAPPING_MUTANT)
diagnosticResidueDetail slot value
  | slot == ResidueCustodyObservation = "mutated residue detail"
  | otherwise = value
#elif defined(VALIDATION_SOURCE_ACQUISITION_ORACLE_QUALIFICATION_RESIDUE_DETAIL_MAPPING_MUTANT)
diagnosticResidueDetail slot value
  | slot == ResidueOracleQualification = "mutated residue detail"
  | otherwise = value
#else
diagnosticResidueDetail slot value = slot `seq` value
#endif

orderDiagnosticResidue :: [Finding] -> [Finding]
#if defined(VALIDATION_SOURCE_ACQUISITION_DIAGNOSTIC_RESIDUE_ORDER_MUTANT)
orderDiagnosticResidue findings =
  maximumDiagnosticResidueFindings `seq` reverse findings
#else
orderDiagnosticResidue findings =
  maximumDiagnosticResidueFindings `seq` findings
#endif



diagnosticResidueRetentionTable :: [(Bool, DiagnosticResidueSlot, Finding)]
diagnosticResidueRetentionTable =
  [ ( retainExpectedIntentResidue
    , ResidueExpectedIntent
    , finding
      "SOURCE-ACQUISITION-EXPECTED-INTENT-CALLER-SUPPLIED"
      "source-acquisition-expected-intent"
      "repository, revision, HEAD, source-snapshot, authored-root, and exact expected-manifest intent are caller-supplied diagnostic inputs rather than independently acquired authority"
    )
  , ( retainSessionCustodyResidue
    , ResidueSessionCustody
    , finding
      "SOURCE-ACQUISITION-SESSION-CUSTODY-CALLER-SUPPLIED"
      "source-acquisition-session-custody"
      "verification key, challenge, replay state, signed session envelope, bundle bytes, and custody claim are caller-supplied rather than acquired and held by an external session authority"
    )
  , ( retainObserverExecutionResidue
    , ResidueObserverExecution
    , finding
      "SOURCE-ACQUISITION-OBSERVER-EXECUTION-ABSENT"
      "source-acquisition-observer"
      "no independently authenticated observer process is executed and no observed exit, stdout, stderr, or tool identity is bound"
    )
  , ( retainKeyRoleSeparationResidue
    , ResidueKeyRoleSeparation
    , finding
      "SOURCE-ACQUISITION-KEY-ROLE-SEPARATION-ABSENT"
      "source-acquisition-keys"
      "bundle signing, observer identity, trust-anchor custody, challenge issuance, and replay consumption are not separate externally controlled roles"
    )
  , ( retainStreamingIngressResidue
    , ResidueStreamingIngress
    , finding
      "SOURCE-ACQUISITION-STREAMING-INGRESS-ABSENT"
      "source-acquisition-ingress"
      "closed byte limits are checked only after strict envelope, expected-manifest, verification-key, and bundle ByteStrings plus caller-constructed expectation and replay values have already been materialized; bounded streaming ingress is absent"
    )
  , ( retainDispatcherCompositionResidue
    , ResidueDispatcherComposition
    , finding
      "SOURCE-ACQUISITION-DISPATCHER-COMPOSITION-ABSENT"
      "source-acquisition-dispatch"
      "the diagnostic is not composed into an authenticated source-bound dispatcher path and therefore cannot establish candidate acquisition"
    )
  , ( retainTrustAnchorResidue
    , ResidueTrustAnchor
    , finding
      "SOURCE-ACQUISITION-TRUST-ANCHOR-UNINTEGRATED"
      "source-acquisition-trust-root"
      "the verification key and expected authority are caller-supplied; no external pre-established trust anchor is integrated"
    )
  , ( retainReplayStateResidue
    , ResidueReplayState
    , finding
      "SOURCE-ACQUISITION-REPLAY-STATE-UNINTEGRATED"
      "source-acquisition-replay-state"
      "the challenge and consumed replay identities are caller-supplied; no external durable atomic freshness consumer is integrated"
    )
  , ( retainAuthoredRootObservationResidue
    , ResidueAuthoredRootObservation
    , finding
      "SOURCE-ACQUISITION-AUTHORED-ROOT-UNOBSERVED"
      "source-acquisition-authored-root"
      "the signed authored-root identity is joined to a caller-supplied external expectation, but no independently authenticated observer establishes ignored, untracked, generated, or special material"
    )
  , ( retainCustodyObservationResidue
    , ResidueCustodyObservation
    , finding
      "SOURCE-ACQUISITION-CUSTODY-UNOBSERVED"
      "source-acquisition-custody"
      "externally frozen read-only custody is a signed tag rather than an independently observed property"
    )
  , ( retainOracleQualificationResidue
    , ResidueOracleQualification
    , finding
      "SOURCE-ACQUISITION-ORACLE-QUALIFICATION-ABSENT"
      "SourceAcquisitionOracle"
      "pinned Ed25519 and envelope vectors do not supply changed-production-subject mutation qualification, external observer execution, or independent reviewer inspection"
    )
  ]

removeAllDiagnosticResidue :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_DIAGNOSTIC_RESIDUE_REMOVAL_MUTANT)
removeAllDiagnosticResidue = True
#else
removeAllDiagnosticResidue = False
#endif

retainExpectedIntentResidue :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_INTENT_RESIDUE_DROP_MUTANT)
retainExpectedIntentResidue = False
#else
retainExpectedIntentResidue = True
#endif

retainSessionCustodyResidue :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_SESSION_CUSTODY_RESIDUE_DROP_MUTANT)
retainSessionCustodyResidue = False
#else
retainSessionCustodyResidue = True
#endif

retainObserverExecutionResidue :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_OBSERVER_EXECUTION_RESIDUE_DROP_MUTANT)
retainObserverExecutionResidue = False
#else
retainObserverExecutionResidue = True
#endif

retainKeyRoleSeparationResidue :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_KEY_ROLE_SEPARATION_RESIDUE_DROP_MUTANT)
retainKeyRoleSeparationResidue = False
#else
retainKeyRoleSeparationResidue = True
#endif

retainStreamingIngressResidue :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_STREAMING_INGRESS_RESIDUE_DROP_MUTANT)
retainStreamingIngressResidue = False
#else
retainStreamingIngressResidue = True
#endif

retainDispatcherCompositionResidue :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_DISPATCHER_COMPOSITION_RESIDUE_DROP_MUTANT)
retainDispatcherCompositionResidue = False
#else
retainDispatcherCompositionResidue = True
#endif

retainTrustAnchorResidue :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_TRUST_ANCHOR_RESIDUE_DROP_MUTANT)
retainTrustAnchorResidue = False
#else
retainTrustAnchorResidue = True
#endif

retainReplayStateResidue :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_REPLAY_STATE_RESIDUE_DROP_MUTANT)
retainReplayStateResidue = False
#else
retainReplayStateResidue = True
#endif

retainAuthoredRootObservationResidue :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_AUTHORED_ROOT_OBSERVATION_RESIDUE_DROP_MUTANT)
retainAuthoredRootObservationResidue = False
#else
retainAuthoredRootObservationResidue = True
#endif

retainCustodyObservationResidue :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_CUSTODY_OBSERVATION_RESIDUE_DROP_MUTANT)
retainCustodyObservationResidue = False
#else
retainCustodyObservationResidue = True
#endif

retainOracleQualificationResidue :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_ORACLE_QUALIFICATION_RESIDUE_DROP_MUTANT)
retainOracleQualificationResidue = False
#else
retainOracleQualificationResidue = True
#endif

diagnosticAuthorityResidue :: [Finding]
#if defined(VALIDATION_SOURCE_ACQUISITION_DIAGNOSTIC_AUTHORITY_BYPASS_MUTANT)
diagnosticAuthorityResidue = []
#else
diagnosticAuthorityResidue =
  [ mutateDiagnosticResidue
      ResidueDiagnosticAuthority
      ( finding
          "SOURCE-ACQUISITION-DIAGNOSTIC-ONLY"
          "Amoebius.Validation.SourceAcquisition"
          "a caller-supplied signed bundle is a component diagnostic and cannot construct AcquiredSourceSnapshot"
      )
  ]
#endif

-- Every reachable problem constructor owns a separate code, subject, and detail
-- projection selector.  Keeping the selector at this shared renderer locus
-- prevents a constructor-producing predicate from also selecting its oracle.
data ProblemProjectionMutation
  = PreserveProblemProjection
  | MutateProblemCode
  | MutateProblemSubject
  | MutateProblemDetail
  deriving (Eq, Show)

problemProjectionMutation :: SourceAcquisitionProblem -> ProblemProjectionMutation
#if defined(NEVER_DEFINED_SOURCE_ACQUISITION_PROJECTION)
problemProjectionMutation _ = PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_WIRE_MALFORMED_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionWireMalformed {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_WIRE_MALFORMED_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionWireMalformed {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_WIRE_MALFORMED_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionWireMalformed {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_WIRE_NON_CANONICAL_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionWireNonCanonical {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_WIRE_NON_CANONICAL_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionWireNonCanonical {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_WIRE_NON_CANONICAL_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionWireNonCanonical {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_ENVELOPE_TOO_LARGE_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionEnvelopeTooLarge {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_ENVELOPE_TOO_LARGE_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionEnvelopeTooLarge {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_ENVELOPE_TOO_LARGE_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionEnvelopeTooLarge {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_PAYLOAD_TOO_LARGE_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionPayloadTooLarge {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_PAYLOAD_TOO_LARGE_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionPayloadTooLarge {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_PAYLOAD_TOO_LARGE_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionPayloadTooLarge {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_BUNDLE_TOO_LARGE_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionBundleTooLarge {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_BUNDLE_TOO_LARGE_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionBundleTooLarge {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_BUNDLE_TOO_LARGE_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionBundleTooLarge {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_FIELD_TOO_LARGE_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionFieldTooLarge {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_FIELD_TOO_LARGE_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionFieldTooLarge {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_FIELD_TOO_LARGE_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionFieldTooLarge {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTATION_VALUE_TOO_LARGE_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectationValueTooLarge {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTATION_VALUE_TOO_LARGE_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectationValueTooLarge {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTATION_VALUE_TOO_LARGE_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectationValueTooLarge {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_REPLAY_SET_TOO_LARGE_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionReplaySetTooLarge {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_REPLAY_SET_TOO_LARGE_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionReplaySetTooLarge {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_REPLAY_SET_TOO_LARGE_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionReplaySetTooLarge {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_REPLAY_SET_ENTRY_TOO_LARGE_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionReplaySetEntryTooLarge {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_REPLAY_SET_ENTRY_TOO_LARGE_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionReplaySetEntryTooLarge {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_REPLAY_SET_ENTRY_TOO_LARGE_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionReplaySetEntryTooLarge {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_PROBLEM_LIMIT_EXCEEDED_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionProblemLimitExceeded {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_PROBLEM_LIMIT_EXCEEDED_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionProblemLimitExceeded {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_PROBLEM_LIMIT_EXCEEDED_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionProblemLimitExceeded {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_PHASE_MALFORMED_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionPhaseMalformed {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_PHASE_MALFORMED_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionPhaseMalformed {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_PHASE_MALFORMED_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionPhaseMalformed {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_PHASE_MISMATCH_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionPhaseMismatch {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_PHASE_MISMATCH_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionPhaseMismatch {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_PHASE_MISMATCH_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionPhaseMismatch {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_AUTHORITY_MALFORMED_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionAuthorityMalformed {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_AUTHORITY_MALFORMED_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionAuthorityMalformed {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_AUTHORITY_MALFORMED_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionAuthorityMalformed {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_AUTHORITY_MISMATCH_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionAuthorityMismatch {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_AUTHORITY_MISMATCH_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionAuthorityMismatch {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_AUTHORITY_MISMATCH_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionAuthorityMismatch {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_OBSERVER_TOOL_DIGEST_MALFORMED_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionObserverToolDigestMalformed {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_OBSERVER_TOOL_DIGEST_MALFORMED_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionObserverToolDigestMalformed {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_OBSERVER_TOOL_DIGEST_MALFORMED_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionObserverToolDigestMalformed {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_OBSERVER_TOOL_MISMATCH_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionObserverToolMismatch {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_OBSERVER_TOOL_MISMATCH_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionObserverToolMismatch {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_OBSERVER_TOOL_MISMATCH_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionObserverToolMismatch {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_CHALLENGE_MALFORMED_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionChallengeMalformed {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_CHALLENGE_MALFORMED_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionChallengeMalformed {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_CHALLENGE_MALFORMED_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionChallengeMalformed {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_CHALLENGE_MISMATCH_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionChallengeMismatch {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_CHALLENGE_MISMATCH_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionChallengeMismatch {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_CHALLENGE_MISMATCH_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionChallengeMismatch {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_REPLAY_IDENTITY_MALFORMED_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionReplayIdentityMalformed {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_REPLAY_IDENTITY_MALFORMED_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionReplayIdentityMalformed {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_REPLAY_IDENTITY_MALFORMED_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionReplayIdentityMalformed {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_REPLAY_DETECTED_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionReplayDetected {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_REPLAY_DETECTED_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionReplayDetected {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_REPLAY_DETECTED_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionReplayDetected {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_REPOSITORY_IDENTITY_MALFORMED_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionRepositoryIdentityMalformed {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_REPOSITORY_IDENTITY_MALFORMED_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionRepositoryIdentityMalformed {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_REPOSITORY_IDENTITY_MALFORMED_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionRepositoryIdentityMalformed {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_REPOSITORY_IDENTITY_MISMATCH_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionRepositoryIdentityMismatch {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_REPOSITORY_IDENTITY_MISMATCH_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionRepositoryIdentityMismatch {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_REPOSITORY_IDENTITY_MISMATCH_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionRepositoryIdentityMismatch {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_REQUESTED_REVISION_MALFORMED_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionRequestedRevisionMalformed {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_REQUESTED_REVISION_MALFORMED_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionRequestedRevisionMalformed {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_REQUESTED_REVISION_MALFORMED_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionRequestedRevisionMalformed {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_REQUESTED_REVISION_MISMATCH_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionRequestedRevisionMismatch {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_REQUESTED_REVISION_MISMATCH_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionRequestedRevisionMismatch {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_REQUESTED_REVISION_MISMATCH_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionRequestedRevisionMismatch {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_CUSTODY_UNSUPPORTED_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionCustodyUnsupported {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_CUSTODY_UNSUPPORTED_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionCustodyUnsupported {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_CUSTODY_UNSUPPORTED_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionCustodyUnsupported {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_OBJECT_FORMAT_UNSUPPORTED_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionObjectFormatUnsupported {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_OBJECT_FORMAT_UNSUPPORTED_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionObjectFormatUnsupported {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_OBJECT_FORMAT_UNSUPPORTED_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionObjectFormatUnsupported {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_HEAD_IDENTITY_MALFORMED_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionHeadIdentityMalformed {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_HEAD_IDENTITY_MALFORMED_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionHeadIdentityMalformed {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_HEAD_IDENTITY_MALFORMED_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionHeadIdentityMalformed {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_HEAD_IDENTITY_MISMATCH_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedHeadIdentityMismatch {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_HEAD_IDENTITY_MISMATCH_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedHeadIdentityMismatch {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_HEAD_IDENTITY_MISMATCH_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedHeadIdentityMismatch {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_TREE_IDENTITY_MALFORMED_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionTreeIdentityMalformed {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_TREE_IDENTITY_MALFORMED_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionTreeIdentityMalformed {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_TREE_IDENTITY_MALFORMED_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionTreeIdentityMalformed {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_TREE_IDENTITY_MISMATCH_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionTreeIdentityMismatch {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_TREE_IDENTITY_MISMATCH_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionTreeIdentityMismatch {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_TREE_IDENTITY_MISMATCH_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionTreeIdentityMismatch {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_TOO_LARGE_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionCommitTooLarge {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_TOO_LARGE_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionCommitTooLarge {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_TOO_LARGE_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionCommitTooLarge {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_HEADER_COUNT_TOO_LARGE_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionCommitHeaderCountTooLarge {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_HEADER_COUNT_TOO_LARGE_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionCommitHeaderCountTooLarge {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_HEADER_COUNT_TOO_LARGE_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionCommitHeaderCountTooLarge {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_HEADER_LINE_TOO_LONG_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionCommitHeaderLineTooLong {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_HEADER_LINE_TOO_LONG_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionCommitHeaderLineTooLong {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_HEADER_LINE_TOO_LONG_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionCommitHeaderLineTooLong {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_MALFORMED_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionCommitMalformed {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_MALFORMED_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionCommitMalformed {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_MALFORMED_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionCommitMalformed {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_IDENTITY_MISMATCH_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionCommitIdentityMismatch {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_IDENTITY_MISMATCH_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionCommitIdentityMismatch {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_IDENTITY_MISMATCH_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionCommitIdentityMismatch {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_TREE_MISMATCH_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionCommitTreeMismatch {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_TREE_MISMATCH_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionCommitTreeMismatch {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_COMMIT_TREE_MISMATCH_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionCommitTreeMismatch {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_AUTHORED_ROOT_IDENTITY_MALFORMED_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionAuthoredRootIdentityMalformed {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_AUTHORED_ROOT_IDENTITY_MALFORMED_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionAuthoredRootIdentityMalformed {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_AUTHORED_ROOT_IDENTITY_MALFORMED_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionAuthoredRootIdentityMalformed {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_AUTHORED_ROOT_IDENTITY_MISMATCH_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionAuthoredRootIdentityMismatch {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_AUTHORED_ROOT_IDENTITY_MISMATCH_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionAuthoredRootIdentityMismatch {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_AUTHORED_ROOT_IDENTITY_MISMATCH_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionAuthoredRootIdentityMismatch {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_FROZEN_SNAPSHOT_IDENTITY_MALFORMED_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionFrozenSnapshotIdentityMalformed {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_FROZEN_SNAPSHOT_IDENTITY_MALFORMED_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionFrozenSnapshotIdentityMalformed {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_FROZEN_SNAPSHOT_IDENTITY_MALFORMED_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionFrozenSnapshotIdentityMalformed {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_FROZEN_SNAPSHOT_IDENTITY_MISMATCH_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionFrozenSnapshotIdentityMismatch {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_FROZEN_SNAPSHOT_IDENTITY_MISMATCH_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionFrozenSnapshotIdentityMismatch {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_FROZEN_SNAPSHOT_IDENTITY_MISMATCH_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionFrozenSnapshotIdentityMismatch {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_BUNDLE_IDENTITY_MALFORMED_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionBundleIdentityMalformed {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_BUNDLE_IDENTITY_MALFORMED_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionBundleIdentityMalformed {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_BUNDLE_IDENTITY_MALFORMED_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionBundleIdentityMalformed {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_BUNDLE_IDENTITY_MISMATCH_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionBundleIdentityMismatch {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_BUNDLE_IDENTITY_MISMATCH_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionBundleIdentityMismatch {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_BUNDLE_IDENTITY_MISMATCH_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionBundleIdentityMismatch {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_SOURCE_SNAPSHOT_IDENTITY_MALFORMED_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionSourceSnapshotIdentityMalformed {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_SOURCE_SNAPSHOT_IDENTITY_MALFORMED_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionSourceSnapshotIdentityMalformed {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_SOURCE_SNAPSHOT_IDENTITY_MALFORMED_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionSourceSnapshotIdentityMalformed {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_SOURCE_SNAPSHOT_IDENTITY_MISMATCH_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionSourceSnapshotIdentityMismatch {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_SOURCE_SNAPSHOT_IDENTITY_MISMATCH_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionSourceSnapshotIdentityMismatch {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_SOURCE_SNAPSHOT_IDENTITY_MISMATCH_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionSourceSnapshotIdentityMismatch {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_SOURCE_SNAPSHOT_IDENTITY_MISMATCH_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedSourceSnapshotIdentityMismatch {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_SOURCE_SNAPSHOT_IDENTITY_MISMATCH_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedSourceSnapshotIdentityMismatch {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_SOURCE_SNAPSHOT_IDENTITY_MISMATCH_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedSourceSnapshotIdentityMismatch {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_TOO_LARGE_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestTooLarge {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_TOO_LARGE_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestTooLarge {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_TOO_LARGE_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestTooLarge {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_COUNT_TOO_LARGE_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEntryCountTooLarge {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_COUNT_TOO_LARGE_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEntryCountTooLarge {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_COUNT_TOO_LARGE_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEntryCountTooLarge {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_MALFORMED_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestMalformed {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_MALFORMED_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestMalformed {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_MALFORMED_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestMalformed {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_EMPTY_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEmpty {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_EMPTY_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEmpty {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_EMPTY_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEmpty {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_NOT_STRICTLY_ORDERED_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestNotStrictlyOrdered {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_NOT_STRICTLY_ORDERED_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestNotStrictlyOrdered {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_NOT_STRICTLY_ORDERED_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestNotStrictlyOrdered {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_DUPLICATE_PATH_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestDuplicatePath {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_DUPLICATE_PATH_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestDuplicatePath {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_DUPLICATE_PATH_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestDuplicatePath {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_PATH_INVALID_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestPathInvalid {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_PATH_INVALID_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestPathInvalid {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_PATH_INVALID_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestPathInvalid {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_CASE_FOLD_COLLISION_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestCaseFoldCollision {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_CASE_FOLD_COLLISION_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestCaseFoldCollision {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_CASE_FOLD_COLLISION_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestCaseFoldCollision {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_PATH_CONFLICT_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestPathConflict {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_PATH_CONFLICT_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestPathConflict {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_PATH_CONFLICT_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestPathConflict {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_OBJECT_FORMAT_MISMATCH_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestObjectFormatMismatch {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_OBJECT_FORMAT_MISMATCH_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestObjectFormatMismatch {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_OBJECT_FORMAT_MISMATCH_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestObjectFormatMismatch {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_MODE_UNSUPPORTED_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEntryModeUnsupported {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_MODE_UNSUPPORTED_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEntryModeUnsupported {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_MODE_UNSUPPORTED_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEntryModeUnsupported {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_GIT_OBJECT_FORMAT_MISMATCH_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEntryGitObjectFormatMismatch {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_GIT_OBJECT_FORMAT_MISMATCH_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEntryGitObjectFormatMismatch {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_GIT_OBJECT_FORMAT_MISMATCH_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEntryGitObjectFormatMismatch {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_BLOB_SHA256_MALFORMED_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEntryBlobSha256Malformed {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_BLOB_SHA256_MALFORMED_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEntryBlobSha256Malformed {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_BLOB_SHA256_MALFORMED_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEntryBlobSha256Malformed {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_TOO_LARGE_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEntryTooLarge {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_TOO_LARGE_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEntryTooLarge {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_TOO_LARGE_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEntryTooLarge {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_MISSING_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEntryMissing {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_MISSING_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEntryMissing {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_MISSING_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEntryMissing {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_UNEXPECTED_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEntryUnexpected {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_UNEXPECTED_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEntryUnexpected {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_UNEXPECTED_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEntryUnexpected {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_MODE_MISMATCH_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEntryModeMismatch {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_MODE_MISMATCH_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEntryModeMismatch {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_MODE_MISMATCH_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEntryModeMismatch {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_GIT_OBJECT_MISMATCH_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEntryGitObjectMismatch {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_GIT_OBJECT_MISMATCH_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEntryGitObjectMismatch {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_GIT_OBJECT_MISMATCH_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEntryGitObjectMismatch {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_BYTE_LENGTH_MISMATCH_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEntryByteLengthMismatch {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_BYTE_LENGTH_MISMATCH_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEntryByteLengthMismatch {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_BYTE_LENGTH_MISMATCH_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEntryByteLengthMismatch {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_BLOB_SHA256_MISMATCH_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEntryBlobSha256Mismatch {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_BLOB_SHA256_MISMATCH_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEntryBlobSha256Mismatch {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_BLOB_SHA256_MISMATCH_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionExpectedManifestEntryBlobSha256Mismatch {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_EMPTY_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionManifestEmpty {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_EMPTY_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionManifestEmpty {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_EMPTY_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionManifestEmpty {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_TOO_LARGE_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionManifestTooLarge {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_TOO_LARGE_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionManifestTooLarge {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_TOO_LARGE_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionManifestTooLarge {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_NOT_STRICTLY_ORDERED_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionManifestNotStrictlyOrdered {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_NOT_STRICTLY_ORDERED_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionManifestNotStrictlyOrdered {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_NOT_STRICTLY_ORDERED_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionManifestNotStrictlyOrdered {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_DUPLICATE_PATH_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionManifestDuplicatePath {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_DUPLICATE_PATH_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionManifestDuplicatePath {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_DUPLICATE_PATH_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionManifestDuplicatePath {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_PATH_INVALID_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionManifestPathInvalid {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_PATH_INVALID_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionManifestPathInvalid {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_PATH_INVALID_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionManifestPathInvalid {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_PATH_TOO_LONG_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionManifestPathTooLong {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_PATH_TOO_LONG_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionManifestPathTooLong {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_PATH_TOO_LONG_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionManifestPathTooLong {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_PATH_TOO_DEEP_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionManifestPathTooDeep {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_PATH_TOO_DEEP_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionManifestPathTooDeep {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_PATH_TOO_DEEP_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionManifestPathTooDeep {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_PATH_SEGMENT_TOO_LONG_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionManifestPathSegmentTooLong {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_PATH_SEGMENT_TOO_LONG_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionManifestPathSegmentTooLong {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_PATH_SEGMENT_TOO_LONG_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionManifestPathSegmentTooLong {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_CASE_FOLD_COLLISION_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionManifestCaseFoldCollision {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_CASE_FOLD_COLLISION_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionManifestCaseFoldCollision {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_CASE_FOLD_COLLISION_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionManifestCaseFoldCollision {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_PATH_CONFLICT_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionManifestPathConflict {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_PATH_CONFLICT_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionManifestPathConflict {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_MANIFEST_PATH_CONFLICT_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionManifestPathConflict {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_ENTRY_MODE_UNSUPPORTED_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionEntryModeUnsupported {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_ENTRY_MODE_UNSUPPORTED_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionEntryModeUnsupported {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_ENTRY_MODE_UNSUPPORTED_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionEntryModeUnsupported {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_ENTRY_GIT_OBJECT_FORMAT_MISMATCH_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionEntryGitObjectFormatMismatch {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_ENTRY_GIT_OBJECT_FORMAT_MISMATCH_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionEntryGitObjectFormatMismatch {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_ENTRY_GIT_OBJECT_FORMAT_MISMATCH_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionEntryGitObjectFormatMismatch {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_ENTRY_GIT_OBJECT_MISMATCH_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionEntryGitObjectMismatch {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_ENTRY_GIT_OBJECT_MISMATCH_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionEntryGitObjectMismatch {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_ENTRY_GIT_OBJECT_MISMATCH_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionEntryGitObjectMismatch {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_ENTRY_TOO_LARGE_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionEntryTooLarge {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_ENTRY_TOO_LARGE_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionEntryTooLarge {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_ENTRY_TOO_LARGE_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionEntryTooLarge {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_BUNDLE_LENGTH_MISMATCH_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionBundleLengthMismatch {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_BUNDLE_LENGTH_MISMATCH_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionBundleLengthMismatch {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_BUNDLE_LENGTH_MISMATCH_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionBundleLengthMismatch {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_ENTRY_BLOB_SHA256_MALFORMED_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionEntryBlobSha256Malformed {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_ENTRY_BLOB_SHA256_MALFORMED_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionEntryBlobSha256Malformed {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_ENTRY_BLOB_SHA256_MALFORMED_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionEntryBlobSha256Malformed {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_ENTRY_BLOB_SHA256_MISMATCH_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionEntryBlobSha256Mismatch {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_ENTRY_BLOB_SHA256_MISMATCH_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionEntryBlobSha256Mismatch {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_ENTRY_BLOB_SHA256_MISMATCH_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionEntryBlobSha256Mismatch {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_PUBLIC_KEY_INVALID_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionPublicKeyInvalid {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_PUBLIC_KEY_INVALID_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionPublicKeyInvalid {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_PUBLIC_KEY_INVALID_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionPublicKeyInvalid {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_SIGNATURE_INVALID_CODE_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionSignatureInvalid {} -> MutateProblemCode
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_SIGNATURE_INVALID_SUBJECT_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionSignatureInvalid {} -> MutateProblemSubject
  _ -> PreserveProblemProjection
#elif defined(VALIDATION_SOURCE_ACQUISITION_SIGNATURE_INVALID_DETAIL_MAPPING_MUTANT)
problemProjectionMutation problem = case problem of
  SourceAcquisitionSignatureInvalid {} -> MutateProblemDetail
  _ -> PreserveProblemProjection
#else
problemProjectionMutation problem = seq problem PreserveProblemProjection
#endif

problemFinding :: SourceAcquisitionProblem -> Finding
problemFinding problem =
  maximumFindingSubjectUtf8Bytes `seq`
    finding
    (case problemProjectionMutation problem of
        MutateProblemCode -> "SOURCE-ACQUISITION-MUTATED-CODE"
        _ -> sourceAcquisitionProblemCode problem
    )
    (case problemProjectionMutation problem of
        MutateProblemSubject -> "source-acquisition-mutated-subject"
        _ -> sourceAcquisitionProblemSubject problem
    )
    (case problemProjectionMutation problem of
        MutateProblemDetail -> "SourceAcquisitionMutatedDetail"
        _ -> boundedShowText problem
    )

sourceAcquisitionProblemCode :: SourceAcquisitionProblem -> Text
sourceAcquisitionProblemCode problem = case problem of
#if defined(VALIDATION_SOURCE_ACQUISITION_PROBLEM_MAPPING_MUTANT)
  SourceAcquisitionWireMalformed _ -> "SOURCE-ACQUISITION-CANONICAL"
#else
  SourceAcquisitionWireMalformed _ -> "SOURCE-ACQUISITION-WIRE"
#endif
  SourceAcquisitionWireNonCanonical -> "SOURCE-ACQUISITION-CANONICAL"
  SourceAcquisitionEnvelopeTooLarge _ -> "SOURCE-ACQUISITION-ENVELOPE-LIMIT"
  SourceAcquisitionPayloadTooLarge _ -> "SOURCE-ACQUISITION-PAYLOAD-LIMIT"
  SourceAcquisitionBundleTooLarge _ -> "SOURCE-ACQUISITION-BUNDLE-LIMIT"
  SourceAcquisitionFieldTooLarge _ _ -> "SOURCE-ACQUISITION-FIELD-LIMIT"
  SourceAcquisitionExpectationValueTooLarge _ _ _ -> "SOURCE-ACQUISITION-EXPECTATION-LIMIT"
  SourceAcquisitionReplaySetTooLarge _ _ -> "SOURCE-ACQUISITION-REPLAY-SET-LIMIT"
  SourceAcquisitionReplaySetEntryTooLarge _ _ _ -> "SOURCE-ACQUISITION-REPLAY-SET-ENTRY-LIMIT"
  SourceAcquisitionProblemLimitExceeded _ _ -> "SOURCE-ACQUISITION-PROBLEM-LIMIT"
  SourceAcquisitionPhaseMalformed _ -> "SOURCE-ACQUISITION-PHASE"
  SourceAcquisitionPhaseMismatch _ _ -> "SOURCE-ACQUISITION-PHASE"
  SourceAcquisitionAuthorityMalformed _ -> "SOURCE-ACQUISITION-AUTHORITY"
  SourceAcquisitionAuthorityMismatch _ _ -> "SOURCE-ACQUISITION-AUTHORITY"
  SourceAcquisitionObserverToolDigestMalformed _ -> "SOURCE-ACQUISITION-OBSERVER-TOOL"
  SourceAcquisitionObserverToolMismatch _ _ -> "SOURCE-ACQUISITION-OBSERVER-TOOL"
  SourceAcquisitionChallengeMalformed _ -> "SOURCE-ACQUISITION-CHALLENGE"
  SourceAcquisitionChallengeMismatch _ _ -> "SOURCE-ACQUISITION-CHALLENGE"
  SourceAcquisitionReplayIdentityMalformed _ -> "SOURCE-ACQUISITION-REPLAY"
  SourceAcquisitionReplayDetected _ -> "SOURCE-ACQUISITION-REPLAY"
  SourceAcquisitionRepositoryIdentityMalformed _ -> "SOURCE-ACQUISITION-REPOSITORY"
  SourceAcquisitionRepositoryIdentityMismatch _ _ -> "SOURCE-ACQUISITION-REPOSITORY"
  SourceAcquisitionRequestedRevisionMalformed _ -> "SOURCE-ACQUISITION-REVISION"
  SourceAcquisitionRequestedRevisionMismatch _ _ -> "SOURCE-ACQUISITION-REVISION"
  SourceAcquisitionCustodyUnsupported _ -> "SOURCE-ACQUISITION-CUSTODY"
  SourceAcquisitionObjectFormatUnsupported _ -> "SOURCE-ACQUISITION-OBJECT-FORMAT"
  SourceAcquisitionHeadIdentityMalformed _ _ -> "SOURCE-ACQUISITION-HEAD"
  SourceAcquisitionExpectedHeadIdentityMismatch _ _ -> "SOURCE-ACQUISITION-EXPECTED-HEAD"
  SourceAcquisitionTreeIdentityMalformed _ _ -> "SOURCE-ACQUISITION-TREE"
  SourceAcquisitionTreeIdentityMismatch _ _ -> "SOURCE-ACQUISITION-TREE"
  SourceAcquisitionCommitTooLarge _ -> "SOURCE-ACQUISITION-COMMIT-LIMIT"
  SourceAcquisitionCommitHeaderCountTooLarge _ _ -> "SOURCE-ACQUISITION-COMMIT-HEADER-COUNT-LIMIT"
  SourceAcquisitionCommitHeaderLineTooLong _ _ _ -> "SOURCE-ACQUISITION-COMMIT-HEADER-LINE-LIMIT"
  SourceAcquisitionCommitMalformed _ -> "SOURCE-ACQUISITION-COMMIT"
  SourceAcquisitionCommitIdentityMismatch _ _ -> "SOURCE-ACQUISITION-COMMIT-IDENTITY"
  SourceAcquisitionCommitTreeMismatch _ _ -> "SOURCE-ACQUISITION-COMMIT-TREE"
  SourceAcquisitionAuthoredRootIdentityMalformed _ -> "SOURCE-ACQUISITION-AUTHORED-ROOT"
  SourceAcquisitionAuthoredRootIdentityMismatch _ _ -> "SOURCE-ACQUISITION-AUTHORED-ROOT"
  SourceAcquisitionFrozenSnapshotIdentityMalformed _ -> "SOURCE-ACQUISITION-FROZEN-SNAPSHOT"
  SourceAcquisitionFrozenSnapshotIdentityMismatch _ _ -> "SOURCE-ACQUISITION-FROZEN-SNAPSHOT"
  SourceAcquisitionBundleIdentityMalformed _ -> "SOURCE-ACQUISITION-BUNDLE"
  SourceAcquisitionBundleIdentityMismatch _ _ -> "SOURCE-ACQUISITION-BUNDLE"
  SourceAcquisitionSourceSnapshotIdentityMalformed _ -> "SOURCE-ACQUISITION-SOURCE-SNAPSHOT"
  SourceAcquisitionSourceSnapshotIdentityMismatch _ _ -> "SOURCE-ACQUISITION-SOURCE-SNAPSHOT"
  SourceAcquisitionExpectedSourceSnapshotIdentityMismatch _ _ -> "SOURCE-ACQUISITION-EXPECTED-SOURCE-SNAPSHOT"
  SourceAcquisitionExpectedManifestTooLarge _ -> "SOURCE-ACQUISITION-EXPECTED-MANIFEST-LIMIT"
  SourceAcquisitionExpectedManifestEntryCountTooLarge _ _ -> "SOURCE-ACQUISITION-EXPECTED-MANIFEST-ENTRY-COUNT-LIMIT"
  SourceAcquisitionExpectedManifestMalformed _ -> "SOURCE-ACQUISITION-EXPECTED-MANIFEST-WIRE"
  SourceAcquisitionExpectedManifestEmpty -> "SOURCE-ACQUISITION-EXPECTED-MANIFEST-EMPTY"
  SourceAcquisitionExpectedManifestNotStrictlyOrdered _ _ -> "SOURCE-ACQUISITION-EXPECTED-MANIFEST-ORDER"
  SourceAcquisitionExpectedManifestDuplicatePath _ -> "SOURCE-ACQUISITION-EXPECTED-MANIFEST-DUPLICATE"
  SourceAcquisitionExpectedManifestPathInvalid _ -> "SOURCE-ACQUISITION-EXPECTED-MANIFEST-PATH"
  SourceAcquisitionExpectedManifestCaseFoldCollision _ _ -> "SOURCE-ACQUISITION-EXPECTED-MANIFEST-CASE-COLLISION"
  SourceAcquisitionExpectedManifestPathConflict _ -> "SOURCE-ACQUISITION-EXPECTED-MANIFEST-PATH-CONFLICT"
  SourceAcquisitionExpectedManifestObjectFormatMismatch _ _ -> "SOURCE-ACQUISITION-EXPECTED-MANIFEST-OBJECT-FORMAT"
  SourceAcquisitionExpectedManifestEntryModeUnsupported _ _ -> "SOURCE-ACQUISITION-EXPECTED-MANIFEST-MODE"
  SourceAcquisitionExpectedManifestEntryGitObjectFormatMismatch _ _ _ -> "SOURCE-ACQUISITION-EXPECTED-MANIFEST-GIT-OID"
  SourceAcquisitionExpectedManifestEntryBlobSha256Malformed _ _ -> "SOURCE-ACQUISITION-EXPECTED-MANIFEST-BLOB-SHA256"
  SourceAcquisitionExpectedManifestEntryTooLarge _ _ -> "SOURCE-ACQUISITION-EXPECTED-MANIFEST-ENTRY-LIMIT"
  SourceAcquisitionExpectedManifestEntryMissing _ -> "SOURCE-ACQUISITION-EXPECTED-MANIFEST-MISSING"
  SourceAcquisitionExpectedManifestEntryUnexpected _ -> "SOURCE-ACQUISITION-EXPECTED-MANIFEST-UNEXPECTED"
  SourceAcquisitionExpectedManifestEntryModeMismatch _ _ _ -> "SOURCE-ACQUISITION-EXPECTED-MANIFEST-MODE"
  SourceAcquisitionExpectedManifestEntryGitObjectMismatch _ _ _ -> "SOURCE-ACQUISITION-EXPECTED-MANIFEST-GIT-OID"
  SourceAcquisitionExpectedManifestEntryByteLengthMismatch _ _ _ -> "SOURCE-ACQUISITION-EXPECTED-MANIFEST-LENGTH"
  SourceAcquisitionExpectedManifestEntryBlobSha256Mismatch _ _ _ -> "SOURCE-ACQUISITION-EXPECTED-MANIFEST-BLOB-SHA256"
  SourceAcquisitionManifestEmpty -> "SOURCE-ACQUISITION-MANIFEST-EMPTY"
  SourceAcquisitionManifestTooLarge _ -> "SOURCE-ACQUISITION-MANIFEST-SIZE"
  SourceAcquisitionManifestNotStrictlyOrdered _ _ -> "SOURCE-ACQUISITION-MANIFEST-ORDER"
  SourceAcquisitionManifestDuplicatePath _ -> "SOURCE-ACQUISITION-MANIFEST-DUPLICATE"
  SourceAcquisitionManifestPathInvalid _ -> "SOURCE-ACQUISITION-PATH"
  SourceAcquisitionManifestPathTooLong _ _ -> "SOURCE-ACQUISITION-PATH-LENGTH"
  SourceAcquisitionManifestPathTooDeep _ _ -> "SOURCE-ACQUISITION-PATH-DEPTH"
  SourceAcquisitionManifestPathSegmentTooLong _ _ _ -> "SOURCE-ACQUISITION-PATH-SEGMENT-LENGTH"
  SourceAcquisitionManifestCaseFoldCollision _ _ -> "SOURCE-ACQUISITION-PATH-CASE-COLLISION"
  SourceAcquisitionManifestPathConflict _ -> "SOURCE-ACQUISITION-PATH-CONFLICT"
  SourceAcquisitionEntryModeUnsupported _ _ -> "SOURCE-ACQUISITION-MODE"
  SourceAcquisitionEntryGitObjectFormatMismatch _ _ _ -> "SOURCE-ACQUISITION-GIT-OID"
  SourceAcquisitionEntryGitObjectMismatch _ _ -> "SOURCE-ACQUISITION-GIT-OID"
  SourceAcquisitionEntryTooLarge _ _ -> "SOURCE-ACQUISITION-ENTRY-LIMIT"
  SourceAcquisitionBundleLengthMismatch _ _ -> "SOURCE-ACQUISITION-LENGTH"
  SourceAcquisitionEntryBlobSha256Malformed _ _ -> "SOURCE-ACQUISITION-BLOB-SHA256"
  SourceAcquisitionEntryBlobSha256Mismatch _ _ _ -> "SOURCE-ACQUISITION-BLOB-SHA256"
  SourceAcquisitionPublicKeyInvalid -> "SOURCE-ACQUISITION-PUBLIC-KEY"
  SourceAcquisitionSignatureInvalid -> "SOURCE-ACQUISITION-SIGNATURE"

sourceAcquisitionProblemSubject :: SourceAcquisitionProblem -> FilePath
sourceAcquisitionProblemSubject problem = case problem of
  SourceAcquisitionExpectationValueTooLarge label _ _ ->
    "source-acquisition-expectation/" <> Text.unpack label
  SourceAcquisitionReplaySetTooLarge _ _ -> "source-acquisition-expectation/replay-set"
  SourceAcquisitionReplaySetEntryTooLarge index _ _ ->
    "source-acquisition-expectation/replay-set/" <> show index
  SourceAcquisitionProblemLimitExceeded _ _ -> "source-acquisition-result/problems"
  SourceAcquisitionManifestDuplicatePath path -> path
  SourceAcquisitionExpectedManifestDuplicatePath path -> path
  SourceAcquisitionExpectedManifestPathInvalid path -> path
  SourceAcquisitionExpectedManifestCaseFoldCollision _ second -> second
  SourceAcquisitionExpectedManifestPathConflict path -> path
  SourceAcquisitionExpectedManifestEntryModeUnsupported path _ -> path
  SourceAcquisitionExpectedManifestEntryGitObjectFormatMismatch path _ _ -> path
  SourceAcquisitionExpectedManifestEntryBlobSha256Malformed path _ -> path
  SourceAcquisitionExpectedManifestEntryTooLarge path _ -> path
  SourceAcquisitionExpectedManifestEntryMissing path -> path
  SourceAcquisitionExpectedManifestEntryUnexpected path -> path
  SourceAcquisitionExpectedManifestEntryModeMismatch path _ _ -> path
  SourceAcquisitionExpectedManifestEntryGitObjectMismatch path _ _ -> path
  SourceAcquisitionExpectedManifestEntryByteLengthMismatch path _ _ -> path
  SourceAcquisitionExpectedManifestEntryBlobSha256Mismatch path _ _ -> path
  SourceAcquisitionManifestPathInvalid path -> path
  SourceAcquisitionManifestPathTooLong path _ -> path
  SourceAcquisitionManifestPathTooDeep path _ -> path
  SourceAcquisitionManifestPathSegmentTooLong path _ _ -> path
  SourceAcquisitionManifestCaseFoldCollision _ second -> second
  SourceAcquisitionManifestPathConflict path -> path
  SourceAcquisitionEntryModeUnsupported path _ -> path
  SourceAcquisitionEntryGitObjectFormatMismatch path _ _ -> path
  SourceAcquisitionEntryGitObjectMismatch path _ -> path
  SourceAcquisitionEntryTooLarge path _ -> path
  SourceAcquisitionEntryBlobSha256Malformed path _ -> path
  SourceAcquisitionEntryBlobSha256Mismatch path _ _ -> path
  _ -> "source-acquisition-envelope"

showText :: Show value => value -> Text
showText = Text.pack . show

boundedShowText :: Show value => value -> Text
boundedShowText value =
  maximumFindingDetailUtf8Bytes `seq`
    if length observedPrefix > maximumFindingDetailCharacters
      then Text.pack (take maximumFindingDetailCharacters observedPrefix <> "[truncated]")
      else Text.pack observedPrefix
 where
  observedPrefix = take (maximumFindingDetailCharacters + 1) (show value)
