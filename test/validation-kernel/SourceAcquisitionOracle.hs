{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PackageImports #-}

module SourceAcquisitionOracle
  ( CanonicalAcquisitionEntry (..)
  , CanonicalAcquisitionInputs (..)
  , canonicalAcquisitionInputs
  , runSourceAcquisitionCanonicalControl
  , runSourceAcquisitionOracle
  , runSourceAcquisitionSelectorOracle
  , sourceAcquisitionSelectorIntents
  , sourceAcquisitionSelectorNames
  ) where

-- Component diagnostics only. The fixture grammar below is deliberately
-- oracle-local: it shares no manifest, entry, custody, object-format, or mode
-- type with production. The only production result exercised here is the
-- always-refusing CheckResult front door.

import Amoebius.Validation.SourceAcquisition (sourceAcquisitionDiagnostic)
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding (..)
  , Observation (..)
  )
import Control.Monad (unless)
import "crypton" Crypto.Error (CryptoFailable (..))
import "crypton" Crypto.Hash qualified as Crypto
import "crypton" Crypto.PubKey.Ed25519 qualified as Ed25519
import Data.Bits (xor)
import Data.ByteArray (convert)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteString8
import Data.ByteString.Builder
  ( Builder
  , byteString
  , toLazyByteString
  , word8
  , word32BE
  , word64BE
  )
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Char (intToDigit)
import Data.List (intercalate, sortBy)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Word (Word32, Word64, Word8)

data OracleCustody
  = OracleFrozenReadOnlyBundle
  | OracleSequentialMutableBundle
  deriving (Eq, Show)

data OracleObjectFormat
  = OracleObjectSha1
  | OracleObjectSha256
  deriving (Eq, Show)

data OracleMode
  = OracleRegularFile
  | OracleExecutableFile
  | OracleSymbolicLink
  deriving (Eq, Show)

data OracleEntry = OracleEntry
  { oracleEntryPath :: FilePath
  , oracleEntryMode :: OracleMode
  , oracleEntryGitObjectId :: Text
  , oracleEntryByteLength :: Word64
  , oracleEntryBlobSha256 :: Text
  }
  deriving (Eq, Show)

data OracleManifest = OracleManifest
  { oraclePhase :: Text
  , oracleAuthority :: Text
  , oracleObserverToolDigest :: Text
  , oracleChallenge :: Text
  , oracleReplayIdentity :: Text
  , oracleRepositoryIdentity :: Text
  , oracleRequestedRevision :: Text
  , oracleCustody :: OracleCustody
  , oracleObjectFormat :: OracleObjectFormat
  , oracleHeadIdentity :: Text
  , oracleTreeIdentityField :: Text
  , oracleAuthoredRootIdentityField :: Text
  , oracleFrozenSnapshotIdentityField :: Text
  , oracleBundleIdentityField :: Text
  , oracleSourceSnapshotIdentityField :: Text
  , oracleCommitBytes :: ByteString
  , oracleEntries :: [OracleEntry]
  }
  deriving (Eq, Show)

data OracleExpectation = OracleExpectation
  { oracleExpectedPhase :: Text
  , oracleExpectedAuthority :: Text
  , oracleExpectedObserverToolDigest :: Text
  , oracleExpectedChallenge :: Text
  , oracleConsumedReplayIdentities :: Set.Set Text
  , oracleExpectedRepositoryIdentity :: Text
  , oracleExpectedRequestedRevision :: Text
  , oracleExpectedHeadIdentity :: Text
  , oracleExpectedSourceSnapshotIdentity :: Text
  , oracleExpectedAuthoredRootIdentity :: Text
  , oracleExpectedManifestBytes :: ByteString
  }
  deriving (Eq, Show)

data OracleFixture = OracleFixture
  { fixtureManifest :: OracleManifest
  , fixtureMembers :: [(OracleEntry, ByteString)]
  , fixtureBundle :: ByteString
  }

-- | Oracle-local primitive inputs for the package-hidden acquired-snapshot
-- handoff oracle. No production manifest, entry, custody, or expectation type
-- is shared across this boundary.
data CanonicalAcquisitionInputs = CanonicalAcquisitionInputs
  { canonicalInputPhase :: Text
  , canonicalInputAuthority :: Text
  , canonicalInputObserverToolDigest :: Text
  , canonicalInputChallenge :: Text
  , canonicalInputConsumedReplayIdentities :: Set.Set Text
  , canonicalInputRepositoryIdentity :: Text
  , canonicalInputRequestedRevision :: Text
  , canonicalInputReplayIdentity :: Text
  , canonicalInputHeadIdentity :: Text
  , canonicalInputSourceSnapshotIdentity :: Text
  , canonicalInputAuthoredRootIdentity :: Text
  , canonicalInputExpectedManifestBytes :: ByteString
  , canonicalInputPublicKeyBytes :: ByteString
  , canonicalInputWireBytes :: ByteString
  , canonicalInputBundleBytes :: ByteString
  , canonicalInputExpectedPaths :: [FilePath]
  , canonicalInputEntries :: [CanonicalAcquisitionEntry]
  }

data CanonicalAcquisitionEntry = CanonicalAcquisitionEntry
  { canonicalEntryPath :: FilePath
  , canonicalEntryMode :: Text
  , canonicalEntryGitObjectId :: Text
  , canonicalEntryByteLength :: Word64
  , canonicalEntryBlobSha256 :: Text
  }

canonicalAcquisitionInputs :: IO CanonicalAcquisitionInputs
canonicalAcquisitionInputs = do
  secret <- Ed25519.generateSecretKey
  let public = Ed25519.toPublic secret
      fixture = canonicalFixture OracleObjectSha1
      manifest = fixtureManifest fixture
      expected = alignFullExpectation manifest (canonicalExpectation fixture)
  pure
    CanonicalAcquisitionInputs
      { canonicalInputPhase = oracleExpectedPhase expected
      , canonicalInputAuthority = oracleExpectedAuthority expected
      , canonicalInputObserverToolDigest = oracleExpectedObserverToolDigest expected
      , canonicalInputChallenge = oracleExpectedChallenge expected
      , canonicalInputConsumedReplayIdentities = oracleConsumedReplayIdentities expected
      , canonicalInputRepositoryIdentity = oracleExpectedRepositoryIdentity expected
      , canonicalInputRequestedRevision = oracleExpectedRequestedRevision expected
      , canonicalInputReplayIdentity = oracleReplayIdentity manifest
      , canonicalInputHeadIdentity = oracleExpectedHeadIdentity expected
      , canonicalInputSourceSnapshotIdentity = oracleExpectedSourceSnapshotIdentity expected
      , canonicalInputAuthoredRootIdentity = oracleExpectedAuthoredRootIdentity expected
      , canonicalInputExpectedManifestBytes = oracleExpectedManifestBytes expected
      , canonicalInputPublicKeyBytes = convert public
      , canonicalInputWireBytes = signFixture secret public fixture
      , canonicalInputBundleBytes = fixtureBundle fixture
      , canonicalInputExpectedPaths = map oracleEntryPath (oracleEntries manifest)
      , canonicalInputEntries = map canonicalPrimitiveEntry (oracleEntries manifest)
      }

canonicalPrimitiveEntry :: OracleEntry -> CanonicalAcquisitionEntry
canonicalPrimitiveEntry entry =
  CanonicalAcquisitionEntry
    { canonicalEntryPath = oracleEntryPath entry
    , canonicalEntryMode = oracleRenderMode (oracleEntryMode entry)
    , canonicalEntryGitObjectId = oracleEntryGitObjectId entry
    , canonicalEntryByteLength = oracleEntryByteLength entry
    , canonicalEntryBlobSha256 = oracleEntryBlobSha256 entry
    }

data ExactCase = ExactCase String [String]

sourceAcquisitionSelectorIntents :: [(String, String)]
sourceAcquisitionSelectorIntents =
  sourceAcquisitionSelectorIntentRowsInitial
    <> sourceAcquisitionSelectorIntentRowsExpansion

sourceAcquisitionSelectorIntentRowsInitial :: [(String, String)]
sourceAcquisitionSelectorIntentRowsInitial =
  [ ( "VALIDATION_SOURCE_ACQUISITION_AUTHORED_ROOT_OBSERVATION_RESIDUE_DROP_MUTANT"
    , "canonical SHA-1 frozen source bundle"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_AUTHORITY_CHARACTER_BYPASS_MUTANT"
    , "malformed acquisition authority"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_AUTHORITY_COLON_REMOVAL_MUTANT"
    , "authority admits its complete closed character alphabet"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_AUTHORITY_DIGIT_RANGE_REMOVAL_MUTANT"
    , "authority admits its complete closed character alphabet"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_AUTHORITY_DOT_REMOVAL_MUTANT"
    , "authority admits its complete closed character alphabet"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_AUTHORITY_HYPHEN_REMOVAL_MUTANT"
    , "authority admits its complete closed character alphabet"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_AUTHORITY_JOIN_BYPASS_MUTANT"
    , "wrong acquisition authority"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_AUTHORITY_LENGTH_BYPASS_MUTANT"
    , "signed authority at 129 characters is rejected"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_AUTHORITY_LOWER_RANGE_REMOVAL_MUTANT"
    , "authority admits its complete closed character alphabet"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_AUTHORITY_NONEMPTY_BYPASS_MUTANT"
    , "empty signed authority is rejected"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_AUTHORITY_UNDERSCORE_REMOVAL_MUTANT"
    , "authority admits its complete closed character alphabet"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_AUTHORITY_UPPER_RANGE_REMOVAL_MUTANT"
    , "authority admits its complete closed character alphabet"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_BLOB_OBJECT_IDENTITY_JOIN_BYPASS_MUTANT"
    , "blob bytes do not match the Git object identity"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_BLOB_SHA256_JOIN_BYPASS_MUTANT"
    , "blob SHA-256 differs from the exact member bytes"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_BUNDLE_BYTE_LIMIT_BYPASS_MUTANT"
    , "bundle above the closed 32 MiB limit"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_BUNDLE_IDENTITY_JOIN_BYPASS_MUTANT"
    , "wrong immutable-bundle digest"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_BUNDLE_LENGTH_JOIN_BYPASS_MUTANT"
    , "declared member lengths differ from exact bundle length"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_CANONICALITY_BYPASS_MUTANT"
    , "authenticated leading-zero length is noncanonical"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_CHALLENGE_JOIN_BYPASS_MUTANT"
    , "wrong fresh challenge"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_BYTE_LIMIT_BYPASS_MUTANT"
    , "commit bytes exceed the closed one-MiB limit"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_CONTINUATION_BYPASS_MUTANT"
    , "commit continuation headers are forbidden"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_DISPLAY_ASCII_RANGE_BYPASS_MUTANT"
    , "display name rejects bytes below printable ASCII (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_DISPLAY_DOUBLE_SPACE_BYPASS_MUTANT"
    , "display name rejects double space (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_DISPLAY_GREATER_THAN_BYPASS_MUTANT"
    , "display name rejects greater-than (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_DISPLAY_LEADING_SPACE_BYPASS_MUTANT"
    , "display name rejects leading space (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_DISPLAY_LESS_THAN_BYPASS_MUTANT"
    , "display name rejects less-than (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_DISPLAY_NONEMPTY_BYPASS_MUTANT"
    , "display name must be nonempty (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_DISPLAY_TRAILING_SPACE_BYPASS_MUTANT"
    , "display name rejects trailing space (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_DOMAIN_MULTILABEL_BYPASS_MUTANT"
    , "email domain requires multiple labels (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_EMAIL_EXACT_AT_BYPASS_MUTANT"
    , "email requires exactly one at-sign (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_EMPTY_BYPASS_MUTANT"
    , "empty commit bytes are rejected (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_EMPTY_HEADER_LINE_BYPASS_MUTANT"
    , "empty commit header block is rejected (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_EMPTY_VALUE_BYPASS_MUTANT"
    , "commit header with an empty value is rejected (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_HEADER_COUNT_LIMIT_BYPASS_MUTANT"
    , "65 parent headers exceed the closed 67-header limit"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_HEADER_CR_BYPASS_MUTANT"
    , "carriage return is rejected in the commit header block (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_HEADER_LINE_BYTE_LIMIT_BYPASS_MUTANT"
    , "a 1025-byte identity header exceeds the closed line limit"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_HEADER_ORDER_BYPASS_MUTANT"
    , "parent headers must be contiguous before author"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_IDENTITY_JOIN_BYPASS_MUTANT"
    , "signed commit bytes must recompute to HEAD"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_IDENTITY_TRAILING_FIELD_BYPASS_MUTANT"
    , "commit identity rejects trailing fields (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_IDENTITY_VALUE_BYPASS_MUTANT"
    , "author identity values use the closed canonical grammar"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_LABEL_CHARACTER_BYPASS_MUTANT"
    , "domain label rejects characters outside its closed set (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_LABEL_LEADING_HYPHEN_BYPASS_MUTANT"
    , "domain label rejects leading hyphen (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_LABEL_NONEMPTY_BYPASS_MUTANT"
    , "domain rejects an empty middle label (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_LABEL_TRAILING_HYPHEN_BYPASS_MUTANT"
    , "domain label rejects trailing hyphen (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_CHARACTER_BYPASS_MUTANT"
    , "email local rejects characters outside its closed set (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_DOUBLE_DOT_BYPASS_MUTANT"
    , "email local rejects double dot (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_LEADING_DOT_BYPASS_MUTANT"
    , "email local rejects leading dot (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_NONEMPTY_BYPASS_MUTANT"
    , "email local must be nonempty (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_TRAILING_DOT_BYPASS_MUTANT"
    , "email local rejects trailing dot (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_MISSING_COMMITTER_BYPASS_MUTANT"
    , "commit requires a committer after its author"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_NUL_MESSAGE_BYPASS_MUTANT"
    , "NUL is rejected even when confined to an otherwise canonical commit message (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_PARENT_AFTER_COMMITTER_BYPASS_MUTANT"
    , "parent headers cannot appear after the committer"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_PARENT_IDENTITY_BYPASS_MUTANT"
    , "every parent identity uses the selected Git object format"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_SEPARATOR_BYPASS_MUTANT"
    , "commit requires the canonical header/message separator"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_TIMESTAMP_DIGIT_BYPASS_MUTANT"
    , "timestamp rejects a nondigit after its first digit (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_TIMESTAMP_LEADING_BYPASS_MUTANT"
    , "timestamp rejects leading zero before nonzero digit (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_TIMESTAMP_WIDTH_BYPASS_MUTANT"
    , "timestamp rejects 20 digits (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_TIMEZONE_DIGIT_BYPASS_MUTANT"
    , "timezone rejects a nondigit (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_TIMEZONE_FOURTEEN_BYPASS_MUTANT"
    , "timezone hour 14 couples to minute zero (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_TIMEZONE_HOUR_BYPASS_MUTANT"
    , "timezone rejects hour 15 (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_TIMEZONE_LENGTH_BYPASS_MUTANT"
    , "timezone rejects four-byte under-width value (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_TIMEZONE_MINUTE_BYPASS_MUTANT"
    , "timezone rejects minute 60 (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_TIMEZONE_NEGATIVE_ZERO_BYPASS_MUTANT"
    , "timezone rejects negative zero (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_TIMEZONE_SIGN_BYPASS_MUTANT"
    , "timezone rejects a non-sign prefix (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_TREE_FIRST_BYPASS_MUTANT"
    , "tree must be the first commit header (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_TREE_JOIN_BYPASS_MUTANT"
    , "canonical commit tree must join the signed tree identity"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_UNKNOWN_HEADER_BYPASS_MUTANT"
    , "unknown commit headers are forbidden"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_COMMIT_VALUE_SEPARATOR_BYPASS_MUTANT"
    , "commit header with no value separator is rejected (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_CUSTODY_FROZEN_TAG_REMOVAL_MUTANT"
    , "canonical SHA-1 frozen source bundle"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_CUSTODY_OBSERVATION_RESIDUE_DROP_MUTANT"
    , "canonical SHA-1 frozen source bundle"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_CUSTODY_TAG_WIDEN_MUTANT"
    , "unsupported custody tag"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_DIAGNOSTIC_AUTHORITY_BYPASS_MUTANT"
    , "canonical SHA-1 frozen source bundle"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_DIAGNOSTIC_RESIDUE_REMOVAL_MUTANT"
    , "canonical SHA-1 frozen source bundle"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_DISPATCHER_COMPOSITION_RESIDUE_DROP_MUTANT"
    , "canonical SHA-1 frozen source bundle"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_ENTRY_BYTE_LIMIT_BYPASS_MUTANT"
    , "entry above the closed bundle-member limit"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_ENTRY_MODE_EXECUTABLE_TAG_REMOVAL_MUTANT"
    , "canonical SHA-1 frozen source bundle"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_ENTRY_MODE_REGULAR_TAG_REMOVAL_MUTANT"
    , "canonical SHA-1 frozen source bundle"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_ENTRY_MODE_SYMBOLIC_LINK_TAG_REMOVAL_MUTANT"
    , "canonical SHA-1 frozen source bundle"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_ENTRY_MODE_TAG_WIDEN_MUTANT"
    , "unsupported entry-mode tag"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_ENVELOPE_BYTE_LIMIT_BYPASS_MUTANT"
    , "envelope above its closed derived limit"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_AUTHORED_ROOT_IDENTITY_BYTE_LIMIT_BYPASS_MUTANT"
    , "expected authored root is bounded before authentication or comparison"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_AUTHORED_ROOT_JOIN_BYPASS_MUTANT"
    , "external authored-root identity differs from signed observation"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_AUTHORITY_BYTE_LIMIT_BYPASS_MUTANT"
    , "expected authority is bounded before authentication or comparison"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_CHALLENGE_BYTE_LIMIT_BYPASS_MUTANT"
    , "expected challenge is bounded before authentication or comparison"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_HEAD_IDENTITY_BYTE_LIMIT_BYPASS_MUTANT"
    , "expected HEAD is bounded before authentication or comparison"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_HEAD_JOIN_BYPASS_MUTANT"
    , "external expected HEAD differs from signed HEAD"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_INTENT_RESIDUE_DROP_MUTANT"
    , "canonical SHA-1 frozen source bundle"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_BLOB_SHA256_JOIN_BYPASS_MUTANT"
    , "independent expected blob SHA-256 differs from signed value"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_BYTE_LENGTH_JOIN_BYPASS_MUTANT"
    , "independent expected byte length differs from signed length"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_BYTE_LIMIT_BYPASS_MUTANT"
    , "expected-manifest bytes exceed the closed 16-MiB limit"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_CASE_COLLISION_BYPASS_MUTANT"
    , "independent expected paths cannot alias under portable case folding"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_COUNT_CLASSIFICATION_MUTANT"
    , "expected-manifest entry count immediately above 16384 is typed before allocation"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_DUPLICATE_BYPASS_MUTANT"
    , "duplicate expected-manifest path"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_EMPTY_BYPASS_MUTANT"
    , "empty independently supplied expected manifest"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_BYTE_LIMIT_BYPASS_MUTANT"
    , "independent expected entry size has the same closed materialization bound"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_COUNT_LIMIT_BYPASS_MUTANT"
    , "expected-manifest entry count immediately above 16384 is typed before allocation"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_JOIN_BYPASS_MUTANT"
    , "independent universe omission exposes an unexpected signed entry"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_MODE_EXECUTABLE_TAG_REMOVAL_MUTANT"
    , "canonical SHA-1 frozen source bundle"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_MODE_REGULAR_TAG_REMOVAL_MUTANT"
    , "canonical SHA-1 frozen source bundle"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_MODE_SYMBOLIC_LINK_TAG_REMOVAL_MUTANT"
    , "canonical SHA-1 frozen source bundle"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_MODE_TAG_WIDEN_MUTANT"
    , "unsupported expected-manifest mode preserves its typed decode problem"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_GENERIC_CLASSIFICATION_MUTANT"
    , "expected-manifest magic is exact"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_GIT_OBJECT_JOIN_BYPASS_MUTANT"
    , "independent expected Git object differs from signed object"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_MAGIC_BYPASS_MUTANT"
    , "expected-manifest magic is exact"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_MISSING_JOIN_BYPASS_MUTANT"
    , "independent universe addition exposes a missing signed entry"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_MODE_CLASSIFICATION_MUTANT"
    , "unsupported expected-manifest mode preserves its typed decode problem"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_MODE_JOIN_BYPASS_MUTANT"
    , "independent expected mode differs from signed mode"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_OBJECT_FORMAT_JOIN_BYPASS_MUTANT"
    , "independent expected object format must join the signed format"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_OBJECT_FORMAT_SHA1_TAG_REMOVAL_MUTANT"
    , "canonical SHA-1 frozen source bundle"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_OBJECT_FORMAT_SHA256_TAG_REMOVAL_MUTANT"
    , "canonical SHA-256 frozen source bundle"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_OBJECT_FORMAT_TAG_WIDEN_MUTANT"
    , "unsupported expected-manifest object-format tag is a typed wire refusal"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ORDER_BYPASS_MUTANT"
    , "noncanonical expected-manifest order"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_PREFIX_CONFLICT_BYPASS_MUTANT"
    , "independent expected paths cannot alias by case-folded ancestry"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_TRAILING_BYTES_BYPASS_MUTANT"
    , "expected-manifest trailing bytes are noncanonical"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_UNEXPECTED_JOIN_BYPASS_MUTANT"
    , "independent universe omission exposes an unexpected signed entry"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_OBSERVER_TOOL_DIGEST_BYTE_LIMIT_BYPASS_MUTANT"
    , "expected observer digest is bounded before authentication or comparison"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_PHASE_BYTE_LIMIT_BYPASS_MUTANT"
    , "expected phase is bounded before authentication or comparison"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_REPOSITORY_IDENTITY_BYTE_LIMIT_BYPASS_MUTANT"
    , "expected repository identity is bounded before authentication or comparison"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_REQUESTED_REVISION_BYTE_LIMIT_BYPASS_MUTANT"
    , "expected revision is bounded before authentication or comparison"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_SOURCE_SNAPSHOT_IDENTITY_BYTE_LIMIT_BYPASS_MUTANT"
    , "expected source snapshot is bounded before authentication or comparison"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_EXPECTED_SOURCE_SNAPSHOT_JOIN_BYPASS_MUTANT"
    , "external expected source snapshot differs from signed snapshot"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_FIELD_AVAILABILITY_CLASSIFICATION_MUTANT"
    , "authenticated field value availability is exact"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_FIELD_BYTE_LIMIT_BYPASS_MUTANT"
    , "authenticated field above the closed 4096-byte limit"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_FIELD_UTF8_CLASSIFICATION_MUTANT"
    , "valid signature exposes exact malformed UTF-8"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_FROZEN_CUSTODY_BYPASS_MUTANT"
    , "sequential mutable custody cannot substitute for a frozen bundle"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_FROZEN_SNAPSHOT_IDENTITY_JOIN_BYPASS_MUTANT"
    , "wrong frozen-snapshot identity"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_GIT_OBJECT_BYTES_DIGIT_RANGE_REMOVAL_MUTANT"
    , "canonical SHA-1 frozen source bundle"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_GIT_OBJECT_BYTES_LOWER_HEX_BYPASS_MUTANT"
    , "commit tree identity uppercase is rejected (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_GIT_OBJECT_BYTES_LOWER_RANGE_REMOVAL_MUTANT"
    , "canonical SHA-1 frozen source bundle"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_GIT_OBJECT_BYTES_WIDTH_BYPASS_MUTANT"
    , "commit tree identity width under is rejected (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_GIT_OBJECT_TEXT_DIGIT_RANGE_REMOVAL_MUTANT"
    , "canonical SHA-1 frozen source bundle"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_GIT_OBJECT_TEXT_LOWER_HEX_BYPASS_MUTANT"
    , "correct-width uppercase hexadecimal identity is rejected (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_GIT_OBJECT_TEXT_LOWER_RANGE_REMOVAL_MUTANT"
    , "canonical SHA-1 frozen source bundle"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_GIT_OBJECT_TEXT_WIDTH_BYPASS_MUTANT"
    , "lowercase-hex identity one character under width is rejected (OracleObjectSha1)"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_KEY_ROLE_SEPARATION_RESIDUE_DROP_MUTANT"
    , "canonical SHA-1 frozen source bundle"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_MANIFEST_CASE_COLLISION_BYPASS_MUTANT"
    , "portable case-fold equality collision"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_MANIFEST_DUPLICATE_BYPASS_MUTANT"
    , "duplicate manifest path"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_MANIFEST_EMPTY_BYPASS_MUTANT"
    , "empty manifest"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_MANIFEST_ENTRY_COUNT_LIMIT_BYPASS_MUTANT"
    , "entry count immediately above 16384"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_MANIFEST_ORDER_BYPASS_MUTANT"
    , "noncanonical manifest order"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_MANIFEST_PREFIX_CONFLICT_BYPASS_MUTANT"
    , "same-case file/directory path conflict"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_OBJECT_FORMAT_SHA1_TAG_REMOVAL_MUTANT"
    , "canonical SHA-1 frozen source bundle"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_OBJECT_FORMAT_SHA256_TAG_REMOVAL_MUTANT"
    , "canonical SHA-256 frozen source bundle"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_OBJECT_FORMAT_TAG_WIDEN_MUTANT"
    , "unsupported object-format tag"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_OBSERVER_EXECUTION_RESIDUE_DROP_MUTANT"
    , "canonical SHA-1 frozen source bundle"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_OBSERVER_JOIN_BYPASS_MUTANT"
    , "wrong observer/tool digest"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_ORACLE_QUALIFICATION_RESIDUE_DROP_MUTANT"
    , "canonical SHA-1 frozen source bundle"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PATH_AT_REMOVAL_MUTANT"
    , "path admits lowercase, uppercase, digit, slash, and every closed punctuation"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PATH_COMMA_REMOVAL_MUTANT"
    , "path admits lowercase, uppercase, digit, slash, and every closed punctuation"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PATH_DEPTH_LIMIT_BYPASS_MUTANT"
    , "path above the closed 64-component limit"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PATH_DIGIT_RANGE_REMOVAL_MUTANT"
    , "path admits lowercase, uppercase, digit, slash, and every closed punctuation"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PATH_DOT_DOT_SEGMENT_BYPASS_MUTANT"
    , "double-dot path segment is rejected"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PATH_DOT_REMOVAL_MUTANT"
    , "path admits lowercase, uppercase, digit, slash, and every closed punctuation"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PATH_DOT_SEGMENT_BYPASS_MUTANT"
    , "single-dot path segment is rejected"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PATH_EMPTY_SEGMENT_BYPASS_MUTANT"
    , "middle empty path segment is rejected"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PATH_GIT_SEGMENT_BYPASS_MUTANT"
    , "case-folded dot-git segment is rejected"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PATH_HYPHEN_REMOVAL_MUTANT"
    , "path admits lowercase, uppercase, digit, slash, and every closed punctuation"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PATH_LOWER_RANGE_REMOVAL_MUTANT"
    , "path admits lowercase, uppercase, digit, slash, and every closed punctuation"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PATH_PLUS_REMOVAL_MUTANT"
    , "path admits lowercase, uppercase, digit, slash, and every closed punctuation"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PATH_PUNCTUATION_REMOVAL_MUTANT"
    , "path admits lowercase, uppercase, digit, slash, and every closed punctuation"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_CASEFOLD_BYPASS_MUTANT"
    , "Windows reserved basename matching is case-insensitive"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_COM9_BYPASS_MUTANT"
    , "Windows reserved basename COM9 is rejected"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_COM_RANGE_BYPASS_MUTANT"
    , "Windows reserved basename COM1 is rejected"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_CORE_BYPASS_MUTANT"
    , "Windows reserved basename CON is rejected"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_EXTENSION_BYPASS_MUTANT"
    , "Windows reserved basename matching ignores an extension"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_LPT9_BYPASS_MUTANT"
    , "Windows reserved basename LPT9 is rejected"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_LPT_RANGE_BYPASS_MUTANT"
    , "Windows reserved basename LPT1 is rejected"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PATH_SEGMENT_BYTE_LIMIT_BYPASS_MUTANT"
    , "path segment above the closed 255-byte limit"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PATH_SLASH_REMOVAL_MUTANT"
    , "path admits lowercase, uppercase, digit, slash, and every closed punctuation"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PATH_TOTAL_LIMIT_BYPASS_MUTANT"
    , "path above the closed 1024-byte limit"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PATH_TRAILING_DOT_SEGMENT_BYPASS_MUTANT"
    , "trailing-dot path segment is rejected"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PATH_UNDERSCORE_REMOVAL_MUTANT"
    , "path admits lowercase, uppercase, digit, slash, and every closed punctuation"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PATH_UPPER_RANGE_REMOVAL_MUTANT"
    , "path admits lowercase, uppercase, digit, slash, and every closed punctuation"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PAYLOAD_AVAILABILITY_BYPASS_MUTANT"
    , "declared payload beyond available envelope bytes is a framing refusal"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PAYLOAD_BYTE_LIMIT_BYPASS_MUTANT"
    , "declared payload above the closed 16 MiB limit"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PAYLOAD_LENGTH_ASCII_DIGIT_BYPASS_MUTANT"
    , "payload-length syntax rejects a plus sign before authentication"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PAYLOAD_LENGTH_ASCII_DIGIT_REMOVAL_MUTANT"
    , "canonical SHA-1 frozen source bundle"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PAYLOAD_LENGTH_DIGIT_COUNT_BYPASS_MUTANT"
    , "nine payload-length digits are rejected at the exact over-bound"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PAYLOAD_LENGTH_NONEMPTY_BYPASS_MUTANT"
    , "empty payload-length decimal is rejected by its own guard"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PAYLOAD_LENGTH_TERMINATOR_BYPASS_MUTANT"
    , "missing payload-length terminator precedes key inspection"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PAYLOAD_MAGIC_BYPASS_MUTANT"
    , "authenticated bad payload magic"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PAYLOAD_TRAILING_BYTES_BYPASS_MUTANT"
    , "authenticated main payload trailing byte is rejected by its own guard"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PHASE_ASCII_DIGIT_BYPASS_MUTANT"
    , "correct-width ASCII nondigit phase is rejected"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PHASE_ASCII_DIGIT_REMOVAL_MUTANT"
    , "canonical SHA-1 frozen source bundle"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PHASE_JOIN_BYPASS_MUTANT"
    , "wrong but canonical phase"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PHASE_WIDTH_BYPASS_MUTANT"
    , "phase width one is rejected"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PREDECODE_MUTANT"
    , "invalid signature precedes malformed UTF-8 decoding"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PROBLEM_MAPPING_MUTANT"
    , "authenticated bad payload magic"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_PUBLIC_KEY_LENGTH_CLASSIFICATION_MUTANT"
    , "31-byte Ed25519 public key is rejected before payload decoding"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_REPLAY_BYPASS_MUTANT"
    , "consumed replay identity"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_REPLAY_IDENTITY_BYTE_LIMIT_BYPASS_MUTANT"
    , "each consumed replay identity is bounded before authentication or comparison"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_REPLAY_SET_COUNT_LIMIT_BYPASS_MUTANT"
    , "consumed replay set count is bounded before authentication or comparison"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_REPLAY_STATE_RESIDUE_DROP_MUTANT"
    , "canonical SHA-1 frozen source bundle"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_REPOSITORY_JOIN_BYPASS_MUTANT"
    , "signed repository identity differs from external intent"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_REVISION_AT_REMOVAL_MUTANT"
    , "revision admits every documented identifier character"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_REVISION_CHARACTER_BYPASS_MUTANT"
    , "requested revision rejects a disallowed colon"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_REVISION_DIGIT_RANGE_REMOVAL_MUTANT"
    , "revision admits every documented identifier character"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_REVISION_DOT_REMOVAL_MUTANT"
    , "revision admits every documented identifier character"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_REVISION_DOUBLE_DOT_BYPASS_MUTANT"
    , "requested revision rejects double dot"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_REVISION_DOUBLE_SLASH_BYPASS_MUTANT"
    , "requested revision rejects double slash"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_REVISION_HYPHEN_REMOVAL_MUTANT"
    , "revision admits every documented identifier character"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_REVISION_JOIN_BYPASS_MUTANT"
    , "signed requested revision differs from external intent"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_REVISION_LEADING_DASH_BYPASS_MUTANT"
    , "requested revision rejects leading dash"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_REVISION_LEADING_DOT_BYPASS_MUTANT"
    , "requested revision rejects leading dot"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_REVISION_LEADING_SLASH_BYPASS_MUTANT"
    , "requested revision rejects leading slash"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_REVISION_LENGTH_BYPASS_MUTANT"
    , "signed requested revision at 257 characters is rejected"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_REVISION_LOWER_RANGE_REMOVAL_MUTANT"
    , "revision admits every documented identifier character"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_REVISION_NONEMPTY_BYPASS_MUTANT"
    , "empty requested revision is rejected"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_REVISION_OPEN_BRACE_REMOVAL_MUTANT"
    , "revision admits every documented identifier character"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_REVISION_PLUS_REMOVAL_MUTANT"
    , "revision admits every documented identifier character"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_REVISION_REFLOG_BYPASS_MUTANT"
    , "requested revision rejects reflog syntax"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_REVISION_SLASH_REMOVAL_MUTANT"
    , "revision admits every documented identifier character"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_REVISION_TRAILING_DOT_BYPASS_MUTANT"
    , "requested revision rejects trailing dot"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_REVISION_TRAILING_LOCK_BYPASS_MUTANT"
    , "requested revision rejects trailing dot-lock"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_REVISION_TRAILING_SLASH_BYPASS_MUTANT"
    , "requested revision rejects trailing slash"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_REVISION_UNDERSCORE_REMOVAL_MUTANT"
    , "revision admits every documented identifier character"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_REVISION_UPPER_RANGE_REMOVAL_MUTANT"
    , "revision admits every documented identifier character"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_SESSION_CUSTODY_RESIDUE_DROP_MUTANT"
    , "canonical SHA-1 frozen source bundle"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_SHA256_TEXT_DIGIT_RANGE_REMOVAL_MUTANT"
    , "canonical SHA-1 frozen source bundle"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_SHA256_TEXT_LOWER_HEX_BYPASS_MUTANT"
    , "correct-width uppercase hexadecimal identity is rejected"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_SHA256_TEXT_LOWER_RANGE_REMOVAL_MUTANT"
    , "canonical SHA-1 frozen source bundle"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_SHA256_TEXT_WIDTH_BYPASS_MUTANT"
    , "lowercase-hex identity one character under width is rejected"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_SIGNATURE_BYPASS_MUTANT"
    , "bit-flipped signature rejects the canonical envelope"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_SIGNATURE_LENGTH_BYPASS_MUTANT"
    , "65 signature bytes are rejected by the exact signature framing guard"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_SOURCE_SNAPSHOT_IDENTITY_JOIN_BYPASS_MUTANT"
    , "wrong source-snapshot identity"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_STREAMING_INGRESS_RESIDUE_DROP_MUTANT"
    , "canonical SHA-1 frozen source bundle"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_STRUCTURAL_ROUTING_BYPASS_MUTANT"
    , "structural refusal suppresses bundle content interpretation"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_TREE_IDENTITY_JOIN_BYPASS_MUTANT"
    , "valid-width but wrong tree identity"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_TREE_SORT_MUTANT"
    , "Git directory-sort hard case remains internally consistent"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_TRUST_ANCHOR_RESIDUE_DROP_MUTANT"
    , "canonical SHA-1 frozen source bundle"
    )
  , ( "VALIDATION_SOURCE_ACQUISITION_WIRE_MAGIC_BYPASS_MUTANT"
    , "bad envelope magic precedes public-key and payload interpretation"
    )
  ]

sourceAcquisitionSelectorIntentRowsExpansion :: [(String, String)]
sourceAcquisitionSelectorIntentRowsExpansion =
  [ ("VALIDATION_SOURCE_ACQUISITION_ASCII_DIGIT_BYTE_REMOVAL_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_ASCII_LOWER_BYTE_REMOVAL_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_AUTHORED_ROOT_IDENTITY_MALFORMED_CODE_MAPPING_MUTANT", "malformed authored-root identity")
  , ("VALIDATION_SOURCE_ACQUISITION_AUTHORED_ROOT_IDENTITY_MALFORMED_DETAIL_MAPPING_MUTANT", "malformed authored-root identity")
  , ("VALIDATION_SOURCE_ACQUISITION_AUTHORED_ROOT_IDENTITY_MALFORMED_SUBJECT_MAPPING_MUTANT", "malformed authored-root identity")
  , ("VALIDATION_SOURCE_ACQUISITION_AUTHORED_ROOT_IDENTITY_MISMATCH_CODE_MAPPING_MUTANT", "lowercase-hex identity one character over width is rejected")
  , ("VALIDATION_SOURCE_ACQUISITION_AUTHORED_ROOT_IDENTITY_MISMATCH_DETAIL_MAPPING_MUTANT", "lowercase-hex identity one character over width is rejected")
  , ("VALIDATION_SOURCE_ACQUISITION_AUTHORED_ROOT_IDENTITY_MISMATCH_SUBJECT_MAPPING_MUTANT", "lowercase-hex identity one character over width is rejected")
  , ("VALIDATION_SOURCE_ACQUISITION_AUTHORED_ROOT_OBSERVATION_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_AUTHORED_ROOT_OBSERVATION_KEY_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_AUTHORED_ROOT_OBSERVATION_RESIDUE_CODE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_AUTHORED_ROOT_OBSERVATION_RESIDUE_DETAIL_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_AUTHORED_ROOT_OBSERVATION_RESIDUE_SUBJECT_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_AUTHORED_ROOT_OBSERVATION_VALUE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_AUTHORITY_MALFORMED_CODE_MAPPING_MUTANT", "malformed acquisition authority")
  , ("VALIDATION_SOURCE_ACQUISITION_AUTHORITY_MALFORMED_DETAIL_MAPPING_MUTANT", "malformed acquisition authority")
  , ("VALIDATION_SOURCE_ACQUISITION_AUTHORITY_MALFORMED_SUBJECT_MAPPING_MUTANT", "malformed acquisition authority")
  , ("VALIDATION_SOURCE_ACQUISITION_AUTHORITY_MISMATCH_CODE_MAPPING_MUTANT", "wrong acquisition authority")
  , ("VALIDATION_SOURCE_ACQUISITION_AUTHORITY_MISMATCH_DETAIL_MAPPING_MUTANT", "wrong acquisition authority")
  , ("VALIDATION_SOURCE_ACQUISITION_AUTHORITY_MISMATCH_SUBJECT_MAPPING_MUTANT", "wrong acquisition authority")
  , ("VALIDATION_SOURCE_ACQUISITION_AUTHORITY_OBSERVATION_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_AUTHORITY_OBSERVATION_KEY_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_AUTHORITY_OBSERVATION_VALUE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_BLOB_SHA256_ALGORITHM_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_BOUNDED_UTF8_BYTE_MEASUREMENT_MUTANT", "expected phase bound measures UTF-8 bytes rather than characters")
  , ("VALIDATION_SOURCE_ACQUISITION_BUNDLE_CONTENT_ASSOCIATION_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_BUNDLE_DECLARED_LENGTH_AGGREGATION_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_BUNDLE_IDENTITY_MALFORMED_CODE_MAPPING_MUTANT", "malformed bundle identity")
  , ("VALIDATION_SOURCE_ACQUISITION_BUNDLE_IDENTITY_MALFORMED_DETAIL_MAPPING_MUTANT", "malformed bundle identity")
  , ("VALIDATION_SOURCE_ACQUISITION_BUNDLE_IDENTITY_MALFORMED_SUBJECT_MAPPING_MUTANT", "malformed bundle identity")
  , ("VALIDATION_SOURCE_ACQUISITION_BUNDLE_IDENTITY_MISMATCH_CODE_MAPPING_MUTANT", "wrong immutable-bundle digest")
  , ("VALIDATION_SOURCE_ACQUISITION_BUNDLE_IDENTITY_MISMATCH_DETAIL_MAPPING_MUTANT", "wrong immutable-bundle digest")
  , ("VALIDATION_SOURCE_ACQUISITION_BUNDLE_IDENTITY_MISMATCH_SUBJECT_MAPPING_MUTANT", "wrong immutable-bundle digest")
  , ("VALIDATION_SOURCE_ACQUISITION_BUNDLE_INPUT_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_BUNDLE_LENGTH_MISMATCH_CODE_MAPPING_MUTANT", "declared member lengths differ from exact bundle length")
  , ("VALIDATION_SOURCE_ACQUISITION_BUNDLE_LENGTH_MISMATCH_DETAIL_MAPPING_MUTANT", "declared member lengths differ from exact bundle length")
  , ("VALIDATION_SOURCE_ACQUISITION_BUNDLE_LENGTH_MISMATCH_SUBJECT_MAPPING_MUTANT", "declared member lengths differ from exact bundle length")
  , ("VALIDATION_SOURCE_ACQUISITION_BUNDLE_MEMBER_BYTES_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_BUNDLE_OBSERVATION_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_BUNDLE_OBSERVATION_KEY_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_BUNDLE_OBSERVATION_VALUE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_BUNDLE_OBSERVED_LENGTH_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_BUNDLE_SHA256_ALGORITHM_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_BUNDLE_TOO_LARGE_CODE_MAPPING_MUTANT", "bundle above the closed 32 MiB limit")
  , ("VALIDATION_SOURCE_ACQUISITION_BUNDLE_TOO_LARGE_DETAIL_MAPPING_MUTANT", "bundle above the closed 32 MiB limit")
  , ("VALIDATION_SOURCE_ACQUISITION_BUNDLE_TOO_LARGE_SUBJECT_MAPPING_MUTANT", "bundle above the closed 32 MiB limit")
  , ("VALIDATION_SOURCE_ACQUISITION_CANONICAL_ENTRY_BLOB_SHA256_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CANONICAL_ENTRY_BYTE_LENGTH_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CANONICAL_ENTRY_GIT_OBJECT_ID_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CANONICAL_ENTRY_MODE_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CANONICAL_ENTRY_PATH_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CANONICAL_ENVELOPE_LENGTH_TERMINATOR_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CANONICAL_ENVELOPE_PAYLOAD_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CANONICAL_ENVELOPE_PAYLOAD_LENGTH_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CANONICAL_ENVELOPE_SIGNATURE_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CANONICAL_ENVELOPE_WIRE_MAGIC_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_AUTHORED_ROOT_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_AUTHORITY_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_BUNDLE_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_CHALLENGE_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_COMMIT_BYTES_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_CUSTODY_TAG_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_ENTRIES_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_ENTRY_COUNT_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_FROZEN_SNAPSHOT_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_HEAD_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_OBJECT_FORMAT_TAG_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_OBSERVER_TOOL_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_PAYLOAD_MAGIC_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_PHASE_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_REPLAY_IDENTITY_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_REPOSITORY_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_REQUESTED_REVISION_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_SOURCE_SNAPSHOT_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CANONICAL_MANIFEST_TREE_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CHALLENGE_MALFORMED_CODE_MAPPING_MUTANT", "malformed fresh challenge")
  , ("VALIDATION_SOURCE_ACQUISITION_CHALLENGE_MALFORMED_DETAIL_MAPPING_MUTANT", "malformed fresh challenge")
  , ("VALIDATION_SOURCE_ACQUISITION_CHALLENGE_MALFORMED_SUBJECT_MAPPING_MUTANT", "malformed fresh challenge")
  , ("VALIDATION_SOURCE_ACQUISITION_CHALLENGE_MISMATCH_CODE_MAPPING_MUTANT", "wrong fresh challenge")
  , ("VALIDATION_SOURCE_ACQUISITION_CHALLENGE_MISMATCH_DETAIL_MAPPING_MUTANT", "wrong fresh challenge")
  , ("VALIDATION_SOURCE_ACQUISITION_CHALLENGE_MISMATCH_SUBJECT_MAPPING_MUTANT", "wrong fresh challenge")
  , ("VALIDATION_SOURCE_ACQUISITION_CHALLENGE_OBSERVATION_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CHALLENGE_OBSERVATION_KEY_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CHALLENGE_OBSERVATION_VALUE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_AUTHOR_HEADER_REMOVAL_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_BYTE_COUNT_OBSERVATION_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_BYTE_COUNT_OBSERVATION_KEY_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_BYTE_COUNT_OBSERVATION_VALUE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_COMMITTER_BEFORE_AUTHOR_BYPASS_MUTANT", "committer cannot appear before author")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_COMMITTER_HEADER_REMOVAL_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_DISPLAY_ASCII_RANGE_REMOVAL_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_DUPLICATE_AUTHOR_BYPASS_MUTANT", "author header cannot be duplicated")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_DUPLICATE_COMMITTER_BYPASS_MUTANT", "committer header cannot be duplicated")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_DUPLICATE_TREE_BYPASS_MUTANT", "tree header cannot be duplicated")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_FIELD_AVAILABILITY_BYPASS_MUTANT", "authenticated commit value availability is exact")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_HEADER_COUNT_TOO_LARGE_CODE_MAPPING_MUTANT", "65 parent headers exceed the closed 67-header limit")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_HEADER_COUNT_TOO_LARGE_DETAIL_MAPPING_MUTANT", "65 parent headers exceed the closed 67-header limit")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_HEADER_COUNT_TOO_LARGE_SUBJECT_MAPPING_MUTANT", "65 parent headers exceed the closed 67-header limit")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_HEADER_LINE_TOO_LONG_CODE_MAPPING_MUTANT", "a 1025-byte identity header exceeds the closed line limit")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_HEADER_LINE_TOO_LONG_DETAIL_MAPPING_MUTANT", "a 1025-byte identity header exceeds the closed line limit")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_HEADER_LINE_TOO_LONG_SUBJECT_MAPPING_MUTANT", "a 1025-byte identity header exceeds the closed line limit")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_HEADER_NAME_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_HEADER_VALUE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_IDENTITY_DISPLAY_NAME_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_IDENTITY_EMAIL_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_IDENTITY_MISMATCH_CODE_MAPPING_MUTANT", "signed commit bytes must recompute to HEAD")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_IDENTITY_MISMATCH_DETAIL_MAPPING_MUTANT", "signed commit bytes must recompute to HEAD")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_IDENTITY_MISMATCH_SUBJECT_MAPPING_MUTANT", "signed commit bytes must recompute to HEAD")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_IDENTITY_TIMESTAMP_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_IDENTITY_TIMEZONE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_LABEL_DIGIT_RANGE_REMOVAL_MUTANT", "domain label admits lowercase digits and interior hyphen (OracleObjectSha1)")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_LABEL_HYPHEN_REMOVAL_MUTANT", "domain label admits lowercase digits and interior hyphen (OracleObjectSha1)")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_LABEL_LOWER_RANGE_REMOVAL_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_AMPERSAND_REMOVAL_MUTANT", "email local admits every closed punctuation character (OracleObjectSha1)")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_APOSTROPHE_REMOVAL_MUTANT", "email local admits every closed punctuation character (OracleObjectSha1)")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_BACKTICK_REMOVAL_MUTANT", "email local admits every closed punctuation character (OracleObjectSha1)")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_CARET_REMOVAL_MUTANT", "email local admits every closed punctuation character (OracleObjectSha1)")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_CLOSE_BRACE_REMOVAL_MUTANT", "email local admits every closed punctuation character (OracleObjectSha1)")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_DIGIT_RANGE_REMOVAL_MUTANT", "email local admits lowercase digits (OracleObjectSha1)")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_DOLLAR_REMOVAL_MUTANT", "email local admits every closed punctuation character (OracleObjectSha1)")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_DOT_REMOVAL_MUTANT", "email local admits every closed punctuation character (OracleObjectSha1)")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_EQUAL_REMOVAL_MUTANT", "email local admits every closed punctuation character (OracleObjectSha1)")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_EXCLAMATION_REMOVAL_MUTANT", "email local admits every closed punctuation character (OracleObjectSha1)")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_HASH_REMOVAL_MUTANT", "email local admits every closed punctuation character (OracleObjectSha1)")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_HYPHEN_REMOVAL_MUTANT", "email local admits every closed punctuation character (OracleObjectSha1)")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_LOWER_RANGE_REMOVAL_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_OPEN_BRACE_REMOVAL_MUTANT", "email local admits every closed punctuation character (OracleObjectSha1)")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_PERCENT_REMOVAL_MUTANT", "email local admits every closed punctuation character (OracleObjectSha1)")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_PIPE_REMOVAL_MUTANT", "email local admits every closed punctuation character (OracleObjectSha1)")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_PLUS_REMOVAL_MUTANT", "email local admits every closed punctuation character (OracleObjectSha1)")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_QUESTION_REMOVAL_MUTANT", "email local admits every closed punctuation character (OracleObjectSha1)")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_SLASH_REMOVAL_MUTANT", "email local admits every closed punctuation character (OracleObjectSha1)")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_STAR_REMOVAL_MUTANT", "email local admits every closed punctuation character (OracleObjectSha1)")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_TILDE_REMOVAL_MUTANT", "email local admits every closed punctuation character (OracleObjectSha1)")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_LOCAL_UNDERSCORE_REMOVAL_MUTANT", "email local admits every closed punctuation character (OracleObjectSha1)")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_MALFORMED_CODE_MAPPING_MUTANT", "commit requires the canonical header/message separator")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_MALFORMED_DETAIL_MAPPING_MUTANT", "commit requires the canonical header/message separator")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_MALFORMED_SUBJECT_MAPPING_MUTANT", "commit requires the canonical header/message separator")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_MISSING_AUTHOR_BYPASS_MUTANT", "commit without author and committer is not canonical")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_PARENT_HEADER_REMOVAL_MUTANT", "every parent identity uses the selected Git object format")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_TIMESTAMP_DIGIT_RANGE_REMOVAL_MUTANT", "timestamp exact 19-digit ceiling is canonical (OracleObjectSha1)")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_TIMESTAMP_NONZERO_DIGIT_RANGE_REMOVAL_MUTANT", "timestamp one is canonical (OracleObjectSha1)")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_TIMESTAMP_ZERO_REMOVAL_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_TIMEZONE_DIGIT_RANGE_REMOVAL_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_TIMEZONE_MINUS_SIGN_REMOVAL_MUTANT", "timezone admits exact control -0001 (OracleObjectSha1)")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_TIMEZONE_PLUS_SIGN_REMOVAL_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_TOO_LARGE_CODE_MAPPING_MUTANT", "commit bytes exceed the closed one-MiB limit")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_TOO_LARGE_DETAIL_MAPPING_MUTANT", "commit bytes exceed the closed one-MiB limit")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_TOO_LARGE_SUBJECT_MAPPING_MUTANT", "commit bytes exceed the closed one-MiB limit")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_TREE_HEADER_REMOVAL_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_TREE_MISMATCH_CODE_MAPPING_MUTANT", "valid-width but wrong tree identity")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_TREE_MISMATCH_DETAIL_MAPPING_MUTANT", "valid-width but wrong tree identity")
  , ("VALIDATION_SOURCE_ACQUISITION_COMMIT_TREE_MISMATCH_SUBJECT_MAPPING_MUTANT", "valid-width but wrong tree identity")
  , ("VALIDATION_SOURCE_ACQUISITION_CUSTODY_OBSERVATION_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CUSTODY_OBSERVATION_KEY_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CUSTODY_OBSERVATION_RESIDUE_CODE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CUSTODY_OBSERVATION_RESIDUE_DETAIL_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CUSTODY_OBSERVATION_RESIDUE_SUBJECT_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CUSTODY_OBSERVATION_VALUE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CUSTODY_TAG_FROZEN_ENCODING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CUSTODY_TAG_MUTABLE_ENCODING_MUTANT", "sequential mutable custody cannot substitute for a frozen bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CUSTODY_UNSUPPORTED_CODE_MAPPING_MUTANT", "sequential mutable custody cannot substitute for a frozen bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CUSTODY_UNSUPPORTED_DETAIL_MAPPING_MUTANT", "sequential mutable custody cannot substitute for a frozen bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_CUSTODY_UNSUPPORTED_SUBJECT_MAPPING_MUTANT", "sequential mutable custody cannot substitute for a frozen bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_EXPECTED_AFTER_BLOB_SHA256_CURSOR_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_EXPECTED_AFTER_BYTE_LENGTH_CURSOR_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_EXPECTED_AFTER_GIT_OBJECT_CURSOR_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_EXPECTED_AFTER_MODE_CURSOR_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_EXPECTED_AFTER_PATH_CURSOR_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_EXPECTED_ENTRY_BLOB_SHA256_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_EXPECTED_ENTRY_BYTE_LENGTH_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_EXPECTED_ENTRY_GIT_OBJECT_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_EXPECTED_ENTRY_MODE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_EXPECTED_ENTRY_ORDER_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_EXPECTED_ENTRY_PATH_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_EXPECTED_MANIFEST_ENTRIES_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_EXPECTED_MANIFEST_OBJECT_FORMAT_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_MANIFEST_AUTHORED_ROOT_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_MANIFEST_AUTHORITY_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_MANIFEST_BUNDLE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_MANIFEST_CHALLENGE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_MANIFEST_COMMIT_BYTES_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_MANIFEST_CUSTODY_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_MANIFEST_ENTRIES_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_MANIFEST_FROZEN_SNAPSHOT_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_MANIFEST_HEAD_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_MANIFEST_OBJECT_FORMAT_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_MANIFEST_OBSERVER_TOOL_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_MANIFEST_PHASE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_MANIFEST_REPLAY_IDENTITY_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_MANIFEST_REPOSITORY_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_MANIFEST_REQUESTED_REVISION_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_MANIFEST_SOURCE_SNAPSHOT_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_MANIFEST_TREE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_SIGNED_AFTER_BLOB_SHA256_CURSOR_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_SIGNED_AFTER_BYTE_LENGTH_CURSOR_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_SIGNED_AFTER_GIT_OBJECT_CURSOR_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_SIGNED_AFTER_MODE_CURSOR_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_SIGNED_AFTER_PATH_CURSOR_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_SIGNED_ENTRY_BLOB_SHA256_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_SIGNED_ENTRY_BYTE_LENGTH_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_SIGNED_ENTRY_GIT_OBJECT_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_SIGNED_ENTRY_MODE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_SIGNED_ENTRY_ORDER_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODED_SIGNED_ENTRY_PATH_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODE_EXPECTED_MANIFEST_CURSOR_AFTER_ENTRY_COUNT_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODE_EXPECTED_MANIFEST_CURSOR_AFTER_MAGIC_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODE_EXPECTED_MANIFEST_CURSOR_AFTER_OBJECT_FORMAT_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODE_HEX_DIGIT_RANGE_REMOVAL_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODE_HEX_LOWER_RANGE_REMOVAL_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_AUTHORED_ROOT_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_AUTHORITY_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_BUNDLE_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_CHALLENGE_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_COMMIT_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_CUSTODY_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_ENTRY_COUNT_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_FROZEN_SNAPSHOT_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_HEAD_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_MAGIC_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_OBJECT_FORMAT_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_OBSERVER_TOOL_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_PHASE_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_REPLAY_IDENTITY_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_REPOSITORY_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_REQUESTED_REVISION_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_SOURCE_SNAPSHOT_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DECODE_MANIFEST_CURSOR_AFTER_TREE_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DIAGNOSTIC_AUTHORITY_RESIDUE_CODE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DIAGNOSTIC_AUTHORITY_RESIDUE_DETAIL_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DIAGNOSTIC_AUTHORITY_RESIDUE_SUBJECT_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DIAGNOSTIC_RESIDUE_ORDER_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DISPATCHER_COMPOSITION_RESIDUE_CODE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DISPATCHER_COMPOSITION_RESIDUE_DETAIL_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_DISPATCHER_COMPOSITION_RESIDUE_SUBJECT_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_ENTRY_BLOB_SHA256_MALFORMED_CODE_MAPPING_MUTANT", "entry blob SHA-256 has malformed shape")
  , ("VALIDATION_SOURCE_ACQUISITION_ENTRY_BLOB_SHA256_MALFORMED_DETAIL_MAPPING_MUTANT", "entry blob SHA-256 has malformed shape")
  , ("VALIDATION_SOURCE_ACQUISITION_ENTRY_BLOB_SHA256_MALFORMED_SUBJECT_MAPPING_MUTANT", "entry blob SHA-256 has malformed shape")
  , ("VALIDATION_SOURCE_ACQUISITION_ENTRY_BLOB_SHA256_MISMATCH_CODE_MAPPING_MUTANT", "blob SHA-256 differs from the exact member bytes")
  , ("VALIDATION_SOURCE_ACQUISITION_ENTRY_BLOB_SHA256_MISMATCH_DETAIL_MAPPING_MUTANT", "blob SHA-256 differs from the exact member bytes")
  , ("VALIDATION_SOURCE_ACQUISITION_ENTRY_BLOB_SHA256_MISMATCH_SUBJECT_MAPPING_MUTANT", "blob SHA-256 differs from the exact member bytes")
  , ("VALIDATION_SOURCE_ACQUISITION_ENTRY_COUNT_OBSERVATION_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_ENTRY_COUNT_OBSERVATION_KEY_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_ENTRY_COUNT_OBSERVATION_VALUE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_ENTRY_GIT_OBJECT_FORMAT_MISMATCH_CODE_MAPPING_MUTANT", "entry Git object identity has the wrong storage format")
  , ("VALIDATION_SOURCE_ACQUISITION_ENTRY_GIT_OBJECT_FORMAT_MISMATCH_DETAIL_MAPPING_MUTANT", "entry Git object identity has the wrong storage format")
  , ("VALIDATION_SOURCE_ACQUISITION_ENTRY_GIT_OBJECT_FORMAT_MISMATCH_SUBJECT_MAPPING_MUTANT", "entry Git object identity has the wrong storage format")
  , ("VALIDATION_SOURCE_ACQUISITION_ENTRY_GIT_OBJECT_MISMATCH_CODE_MAPPING_MUTANT", "blob bytes do not match the Git object identity")
  , ("VALIDATION_SOURCE_ACQUISITION_ENTRY_GIT_OBJECT_MISMATCH_DETAIL_MAPPING_MUTANT", "blob bytes do not match the Git object identity")
  , ("VALIDATION_SOURCE_ACQUISITION_ENTRY_GIT_OBJECT_MISMATCH_SUBJECT_MAPPING_MUTANT", "blob bytes do not match the Git object identity")
  , ("VALIDATION_SOURCE_ACQUISITION_ENTRY_MODE_UNSUPPORTED_CODE_MAPPING_MUTANT", "unsupported entry-mode tag")
  , ("VALIDATION_SOURCE_ACQUISITION_ENTRY_MODE_UNSUPPORTED_DETAIL_MAPPING_MUTANT", "unsupported entry-mode tag")
  , ("VALIDATION_SOURCE_ACQUISITION_ENTRY_MODE_UNSUPPORTED_SUBJECT_MAPPING_MUTANT", "unsupported entry-mode tag")
  , ("VALIDATION_SOURCE_ACQUISITION_ENTRY_TOO_LARGE_CODE_MAPPING_MUTANT", "entry above the closed bundle-member limit")
  , ("VALIDATION_SOURCE_ACQUISITION_ENTRY_TOO_LARGE_DETAIL_MAPPING_MUTANT", "entry above the closed bundle-member limit")
  , ("VALIDATION_SOURCE_ACQUISITION_ENTRY_TOO_LARGE_SUBJECT_MAPPING_MUTANT", "entry above the closed bundle-member limit")
  , ("VALIDATION_SOURCE_ACQUISITION_ENVELOPE_TOO_LARGE_CODE_MAPPING_MUTANT", "envelope above its closed derived limit")
  , ("VALIDATION_SOURCE_ACQUISITION_ENVELOPE_TOO_LARGE_DETAIL_MAPPING_MUTANT", "envelope above its closed derived limit")
  , ("VALIDATION_SOURCE_ACQUISITION_ENVELOPE_TOO_LARGE_SUBJECT_MAPPING_MUTANT", "envelope above its closed derived limit")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTATION_VALUE_TOO_LARGE_CODE_MAPPING_MUTANT", "expected phase is bounded before authentication or comparison")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTATION_VALUE_TOO_LARGE_DETAIL_MAPPING_MUTANT", "expected phase is bounded before authentication or comparison")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTATION_VALUE_TOO_LARGE_SUBJECT_MAPPING_MUTANT", "expected phase is bounded before authentication or comparison")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_HEAD_IDENTITY_MISMATCH_CODE_MAPPING_MUTANT", "lowercase-hex identity one character over width is rejected (OracleObjectSha256)")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_HEAD_IDENTITY_MISMATCH_DETAIL_MAPPING_MUTANT", "lowercase-hex identity one character over width is rejected (OracleObjectSha256)")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_HEAD_IDENTITY_MISMATCH_SUBJECT_MAPPING_MUTANT", "lowercase-hex identity one character over width is rejected (OracleObjectSha256)")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_INPUT_AUTHORED_ROOT_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_INPUT_AUTHORITY_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_INPUT_CHALLENGE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_INPUT_HEAD_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_INPUT_OBSERVER_TOOL_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_INPUT_PHASE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_INPUT_REPLAY_SET_MAPPING_MUTANT", "consumed replay identity")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_INPUT_REPOSITORY_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_INPUT_REQUESTED_REVISION_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_INPUT_SOURCE_SNAPSHOT_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_INTENT_RESIDUE_CODE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_INTENT_RESIDUE_DETAIL_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_INTENT_RESIDUE_SUBJECT_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_CASE_FOLD_COLLISION_CODE_MAPPING_MUTANT", "independent expected paths cannot alias under portable case folding")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_CASE_FOLD_COLLISION_DETAIL_MAPPING_MUTANT", "independent expected paths cannot alias under portable case folding")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_CASE_FOLD_COLLISION_SUBJECT_MAPPING_MUTANT", "independent expected paths cannot alias under portable case folding")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_DUPLICATE_PATH_CODE_MAPPING_MUTANT", "duplicate expected-manifest path")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_DUPLICATE_PATH_DETAIL_MAPPING_MUTANT", "duplicate expected-manifest path")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_DUPLICATE_PATH_SUBJECT_MAPPING_MUTANT", "duplicate expected-manifest path")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_EMPTY_CODE_MAPPING_MUTANT", "empty independently supplied expected manifest")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_EMPTY_DETAIL_MAPPING_MUTANT", "empty independently supplied expected manifest")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_EMPTY_SUBJECT_MAPPING_MUTANT", "empty independently supplied expected manifest")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_BLOB_SHA256_MALFORMED_CODE_MAPPING_MUTANT", "independent expected blob SHA-256 must be canonical")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_BLOB_SHA256_MALFORMED_DETAIL_MAPPING_MUTANT", "independent expected blob SHA-256 must be canonical")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_BLOB_SHA256_MALFORMED_SUBJECT_MAPPING_MUTANT", "independent expected blob SHA-256 must be canonical")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_BLOB_SHA256_MISMATCH_CODE_MAPPING_MUTANT", "independent expected blob SHA-256 differs from signed value")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_BLOB_SHA256_MISMATCH_DETAIL_MAPPING_MUTANT", "independent expected blob SHA-256 differs from signed value")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_BLOB_SHA256_MISMATCH_SUBJECT_MAPPING_MUTANT", "independent expected blob SHA-256 differs from signed value")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_BYTE_LENGTH_MISMATCH_CODE_MAPPING_MUTANT", "independent expected byte length differs from signed length")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_BYTE_LENGTH_MISMATCH_DETAIL_MAPPING_MUTANT", "independent expected byte length differs from signed length")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_BYTE_LENGTH_MISMATCH_SUBJECT_MAPPING_MUTANT", "independent expected byte length differs from signed length")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_COUNT_TOO_LARGE_CODE_MAPPING_MUTANT", "expected-manifest entry count immediately above 16384 is typed before allocation")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_COUNT_TOO_LARGE_DETAIL_MAPPING_MUTANT", "expected-manifest entry count immediately above 16384 is typed before allocation")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_COUNT_TOO_LARGE_SUBJECT_MAPPING_MUTANT", "expected-manifest entry count immediately above 16384 is typed before allocation")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_GIT_OBJECT_FORMAT_MISMATCH_CODE_MAPPING_MUTANT", "independent expected Git object identity must match the signed storage format")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_GIT_OBJECT_FORMAT_MISMATCH_DETAIL_MAPPING_MUTANT", "independent expected Git object identity must match the signed storage format")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_GIT_OBJECT_FORMAT_MISMATCH_SUBJECT_MAPPING_MUTANT", "independent expected Git object identity must match the signed storage format")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_GIT_OBJECT_MISMATCH_CODE_MAPPING_MUTANT", "independent expected Git object differs from signed object")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_GIT_OBJECT_MISMATCH_DETAIL_MAPPING_MUTANT", "independent expected Git object differs from signed object")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_GIT_OBJECT_MISMATCH_SUBJECT_MAPPING_MUTANT", "independent expected Git object differs from signed object")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_MISSING_CODE_MAPPING_MUTANT", "independent universe addition exposes a missing signed entry")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_MISSING_DETAIL_MAPPING_MUTANT", "independent universe addition exposes a missing signed entry")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_MISSING_SUBJECT_MAPPING_MUTANT", "independent universe addition exposes a missing signed entry")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_MODE_MISMATCH_CODE_MAPPING_MUTANT", "independent expected mode differs from signed mode")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_MODE_MISMATCH_DETAIL_MAPPING_MUTANT", "independent expected mode differs from signed mode")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_MODE_MISMATCH_SUBJECT_MAPPING_MUTANT", "independent expected mode differs from signed mode")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_MODE_UNSUPPORTED_CODE_MAPPING_MUTANT", "unsupported expected-manifest mode preserves its typed decode problem")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_MODE_UNSUPPORTED_DETAIL_MAPPING_MUTANT", "unsupported expected-manifest mode preserves its typed decode problem")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_MODE_UNSUPPORTED_SUBJECT_MAPPING_MUTANT", "unsupported expected-manifest mode preserves its typed decode problem")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_TOO_LARGE_CODE_MAPPING_MUTANT", "independent expected entry size has the same closed materialization bound")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_TOO_LARGE_DETAIL_MAPPING_MUTANT", "independent expected entry size has the same closed materialization bound")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_TOO_LARGE_SUBJECT_MAPPING_MUTANT", "independent expected entry size has the same closed materialization bound")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_UNEXPECTED_CODE_MAPPING_MUTANT", "independent universe omission exposes an unexpected signed entry")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_UNEXPECTED_DETAIL_MAPPING_MUTANT", "independent universe omission exposes an unexpected signed entry")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_ENTRY_UNEXPECTED_SUBJECT_MAPPING_MUTANT", "independent universe omission exposes an unexpected signed entry")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_INPUT_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_MALFORMED_CODE_MAPPING_MUTANT", "unsupported expected-manifest object-format tag is a typed wire refusal")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_MALFORMED_DETAIL_MAPPING_MUTANT", "unsupported expected-manifest object-format tag is a typed wire refusal")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_MALFORMED_SUBJECT_MAPPING_MUTANT", "unsupported expected-manifest object-format tag is a typed wire refusal")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_NOT_STRICTLY_ORDERED_CODE_MAPPING_MUTANT", "noncanonical expected-manifest order")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_NOT_STRICTLY_ORDERED_DETAIL_MAPPING_MUTANT", "noncanonical expected-manifest order")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_NOT_STRICTLY_ORDERED_SUBJECT_MAPPING_MUTANT", "noncanonical expected-manifest order")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_OBJECT_FORMAT_MISMATCH_CODE_MAPPING_MUTANT", "independent expected object format must join the signed format")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_OBJECT_FORMAT_MISMATCH_DETAIL_MAPPING_MUTANT", "independent expected object format must join the signed format")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_OBJECT_FORMAT_MISMATCH_SUBJECT_MAPPING_MUTANT", "independent expected object format must join the signed format")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_PATH_CONFLICT_CODE_MAPPING_MUTANT", "independent expected paths cannot alias by case-folded ancestry")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_PATH_CONFLICT_DETAIL_MAPPING_MUTANT", "independent expected paths cannot alias by case-folded ancestry")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_PATH_CONFLICT_SUBJECT_MAPPING_MUTANT", "independent expected paths cannot alias by case-folded ancestry")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_PATH_INVALID_CODE_MAPPING_MUTANT", "independent expected path must use the portable grammar")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_PATH_INVALID_DETAIL_MAPPING_MUTANT", "independent expected path must use the portable grammar")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_PATH_INVALID_SUBJECT_MAPPING_MUTANT", "independent expected path must use the portable grammar")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_TOO_LARGE_CODE_MAPPING_MUTANT", "expected-manifest bytes exceed the closed 16-MiB limit")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_TOO_LARGE_DETAIL_MAPPING_MUTANT", "expected-manifest bytes exceed the closed 16-MiB limit")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_MANIFEST_TOO_LARGE_SUBJECT_MAPPING_MUTANT", "expected-manifest bytes exceed the closed 16-MiB limit")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_SOURCE_SNAPSHOT_IDENTITY_MISMATCH_CODE_MAPPING_MUTANT", "external expected source snapshot differs from signed snapshot")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_SOURCE_SNAPSHOT_IDENTITY_MISMATCH_DETAIL_MAPPING_MUTANT", "external expected source snapshot differs from signed snapshot")
  , ("VALIDATION_SOURCE_ACQUISITION_EXPECTED_SOURCE_SNAPSHOT_IDENTITY_MISMATCH_SUBJECT_MAPPING_MUTANT", "external expected source snapshot differs from signed snapshot")
  , ("VALIDATION_SOURCE_ACQUISITION_FIELD_TOO_LARGE_CODE_MAPPING_MUTANT", "authenticated field above the closed 4096-byte limit")
  , ("VALIDATION_SOURCE_ACQUISITION_FIELD_TOO_LARGE_DETAIL_MAPPING_MUTANT", "authenticated field above the closed 4096-byte limit")
  , ("VALIDATION_SOURCE_ACQUISITION_FIELD_TOO_LARGE_SUBJECT_MAPPING_MUTANT", "authenticated field above the closed 4096-byte limit")
  , ("VALIDATION_SOURCE_ACQUISITION_FINDING_DETAIL_CHARACTER_LIMIT_WIDEN_MUTANT", "path above the closed 1024-byte limit")
  , ("VALIDATION_SOURCE_ACQUISITION_FROZEN_IDENTITY_AUTHORED_ROOT_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_FROZEN_IDENTITY_BUNDLE_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_FROZEN_IDENTITY_CUSTODY_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_FROZEN_IDENTITY_DOMAIN_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_FROZEN_IDENTITY_HEAD_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_FROZEN_IDENTITY_OBJECT_FORMAT_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_FROZEN_IDENTITY_REPOSITORY_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_FROZEN_IDENTITY_REVISION_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_FROZEN_IDENTITY_SOURCE_SNAPSHOT_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_FROZEN_IDENTITY_TREE_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_FROZEN_SNAPSHOT_IDENTITY_MALFORMED_CODE_MAPPING_MUTANT", "malformed frozen-snapshot identity")
  , ("VALIDATION_SOURCE_ACQUISITION_FROZEN_SNAPSHOT_IDENTITY_MALFORMED_DETAIL_MAPPING_MUTANT", "malformed frozen-snapshot identity")
  , ("VALIDATION_SOURCE_ACQUISITION_FROZEN_SNAPSHOT_IDENTITY_MALFORMED_SUBJECT_MAPPING_MUTANT", "malformed frozen-snapshot identity")
  , ("VALIDATION_SOURCE_ACQUISITION_FROZEN_SNAPSHOT_IDENTITY_MISMATCH_CODE_MAPPING_MUTANT", "wrong frozen-snapshot identity")
  , ("VALIDATION_SOURCE_ACQUISITION_FROZEN_SNAPSHOT_IDENTITY_MISMATCH_DETAIL_MAPPING_MUTANT", "wrong frozen-snapshot identity")
  , ("VALIDATION_SOURCE_ACQUISITION_FROZEN_SNAPSHOT_IDENTITY_MISMATCH_SUBJECT_MAPPING_MUTANT", "wrong frozen-snapshot identity")
  , ("VALIDATION_SOURCE_ACQUISITION_FROZEN_SNAPSHOT_OBSERVATION_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_FROZEN_SNAPSHOT_OBSERVATION_KEY_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_FROZEN_SNAPSHOT_OBSERVATION_VALUE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_FROZEN_SNAPSHOT_SHA256_ALGORITHM_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_GIT_OBJECT_FRAME_KIND_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_GIT_OBJECT_FRAME_LENGTH_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_GIT_OBJECT_FRAME_NUL_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_GIT_OBJECT_FRAME_PAYLOAD_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_GIT_OBJECT_FRAME_SEPARATOR_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_GIT_OBJECT_SHA1_ALGORITHM_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_GIT_OBJECT_SHA256_ALGORITHM_MUTANT", "canonical SHA-256 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_HEAD_IDENTITY_MALFORMED_CODE_MAPPING_MUTANT", "malformed HEAD identity")
  , ("VALIDATION_SOURCE_ACQUISITION_HEAD_IDENTITY_MALFORMED_DETAIL_MAPPING_MUTANT", "malformed HEAD identity")
  , ("VALIDATION_SOURCE_ACQUISITION_HEAD_IDENTITY_MALFORMED_SUBJECT_MAPPING_MUTANT", "malformed HEAD identity")
  , ("VALIDATION_SOURCE_ACQUISITION_HEAD_OBSERVATION_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_HEAD_OBSERVATION_KEY_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_HEAD_OBSERVATION_VALUE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_INTEGRITY_FAILURE_VALUE_MUTANT", "wrong but canonical phase")
  , ("VALIDATION_SOURCE_ACQUISITION_INTEGRITY_OBSERVATION_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_INTEGRITY_OBSERVATION_KEY_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_INTEGRITY_PROBLEM_LIMIT_WIDEN_MUTANT", "130 problems cannot traverse past the integrity guard")
  , ("VALIDATION_SOURCE_ACQUISITION_INTEGRITY_SUCCESS_VALUE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_KEY_ROLE_SEPARATION_RESIDUE_CODE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_KEY_ROLE_SEPARATION_RESIDUE_DETAIL_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_KEY_ROLE_SEPARATION_RESIDUE_SUBJECT_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_MANIFEST_CASE_FOLD_COLLISION_CODE_MAPPING_MUTANT", "portable case-fold equality collision")
  , ("VALIDATION_SOURCE_ACQUISITION_MANIFEST_CASE_FOLD_COLLISION_DETAIL_MAPPING_MUTANT", "portable case-fold equality collision")
  , ("VALIDATION_SOURCE_ACQUISITION_MANIFEST_CASE_FOLD_COLLISION_SUBJECT_MAPPING_MUTANT", "portable case-fold equality collision")
  , ("VALIDATION_SOURCE_ACQUISITION_MANIFEST_DUPLICATE_PATH_CODE_MAPPING_MUTANT", "duplicate manifest path")
  , ("VALIDATION_SOURCE_ACQUISITION_MANIFEST_DUPLICATE_PATH_DETAIL_MAPPING_MUTANT", "duplicate manifest path")
  , ("VALIDATION_SOURCE_ACQUISITION_MANIFEST_DUPLICATE_PATH_SUBJECT_MAPPING_MUTANT", "duplicate manifest path")
  , ("VALIDATION_SOURCE_ACQUISITION_MANIFEST_EMPTY_CODE_MAPPING_MUTANT", "empty manifest")
  , ("VALIDATION_SOURCE_ACQUISITION_MANIFEST_EMPTY_DETAIL_MAPPING_MUTANT", "empty manifest")
  , ("VALIDATION_SOURCE_ACQUISITION_MANIFEST_EMPTY_SUBJECT_MAPPING_MUTANT", "empty manifest")
  , ("VALIDATION_SOURCE_ACQUISITION_MANIFEST_NOT_STRICTLY_ORDERED_CODE_MAPPING_MUTANT", "noncanonical manifest order")
  , ("VALIDATION_SOURCE_ACQUISITION_MANIFEST_NOT_STRICTLY_ORDERED_DETAIL_MAPPING_MUTANT", "noncanonical manifest order")
  , ("VALIDATION_SOURCE_ACQUISITION_MANIFEST_NOT_STRICTLY_ORDERED_SUBJECT_MAPPING_MUTANT", "noncanonical manifest order")
  , ("VALIDATION_SOURCE_ACQUISITION_MANIFEST_OBSERVATION_ROUTE_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_MANIFEST_PATH_CONFLICT_CODE_MAPPING_MUTANT", "same-case file/directory path conflict")
  , ("VALIDATION_SOURCE_ACQUISITION_MANIFEST_PATH_CONFLICT_DETAIL_MAPPING_MUTANT", "same-case file/directory path conflict")
  , ("VALIDATION_SOURCE_ACQUISITION_MANIFEST_PATH_CONFLICT_SUBJECT_MAPPING_MUTANT", "same-case file/directory path conflict")
  , ("VALIDATION_SOURCE_ACQUISITION_MANIFEST_PATH_INVALID_CODE_MAPPING_MUTANT", "parent-traversing path")
  , ("VALIDATION_SOURCE_ACQUISITION_MANIFEST_PATH_INVALID_DETAIL_MAPPING_MUTANT", "parent-traversing path")
  , ("VALIDATION_SOURCE_ACQUISITION_MANIFEST_PATH_INVALID_SUBJECT_MAPPING_MUTANT", "parent-traversing path")
  , ("VALIDATION_SOURCE_ACQUISITION_MANIFEST_PATH_SEGMENT_TOO_LONG_CODE_MAPPING_MUTANT", "path segment above the closed 255-byte limit")
  , ("VALIDATION_SOURCE_ACQUISITION_MANIFEST_PATH_SEGMENT_TOO_LONG_DETAIL_MAPPING_MUTANT", "path segment above the closed 255-byte limit")
  , ("VALIDATION_SOURCE_ACQUISITION_MANIFEST_PATH_SEGMENT_TOO_LONG_SUBJECT_MAPPING_MUTANT", "path segment above the closed 255-byte limit")
  , ("VALIDATION_SOURCE_ACQUISITION_MANIFEST_PATH_TOO_DEEP_CODE_MAPPING_MUTANT", "path above the closed 64-component limit")
  , ("VALIDATION_SOURCE_ACQUISITION_MANIFEST_PATH_TOO_DEEP_DETAIL_MAPPING_MUTANT", "path above the closed 64-component limit")
  , ("VALIDATION_SOURCE_ACQUISITION_MANIFEST_PATH_TOO_DEEP_SUBJECT_MAPPING_MUTANT", "path above the closed 64-component limit")
  , ("VALIDATION_SOURCE_ACQUISITION_MANIFEST_PATH_TOO_LONG_CODE_MAPPING_MUTANT", "path above the closed 1024-byte limit")
  , ("VALIDATION_SOURCE_ACQUISITION_MANIFEST_PATH_TOO_LONG_DETAIL_MAPPING_MUTANT", "path above the closed 1024-byte limit")
  , ("VALIDATION_SOURCE_ACQUISITION_MANIFEST_PATH_TOO_LONG_SUBJECT_MAPPING_MUTANT", "path above the closed 1024-byte limit")
  , ("VALIDATION_SOURCE_ACQUISITION_MANIFEST_PROBLEM_ACCEPTANCE_BYPASS_MUTANT", "wrong but canonical phase")
  , ("VALIDATION_SOURCE_ACQUISITION_MANIFEST_TOO_LARGE_CODE_MAPPING_MUTANT", "entry count immediately above 16384")
  , ("VALIDATION_SOURCE_ACQUISITION_MANIFEST_TOO_LARGE_DETAIL_MAPPING_MUTANT", "entry count immediately above 16384")
  , ("VALIDATION_SOURCE_ACQUISITION_MANIFEST_TOO_LARGE_SUBJECT_MAPPING_MUTANT", "entry count immediately above 16384")
  , ("VALIDATION_SOURCE_ACQUISITION_MODE_TAG_EXECUTABLE_ENCODING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_MODE_TAG_REGULAR_ENCODING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_MODE_TAG_SYMBOLIC_LINK_ENCODING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_OBJECT_FORMAT_OBSERVATION_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_OBJECT_FORMAT_OBSERVATION_KEY_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_OBJECT_FORMAT_OBSERVATION_VALUE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_OBJECT_FORMAT_TAG_SHA1_ENCODING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_OBJECT_FORMAT_TAG_SHA256_ENCODING_MUTANT", "canonical SHA-256 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_OBJECT_FORMAT_UNSUPPORTED_CODE_MAPPING_MUTANT", "unsupported object-format tag")
  , ("VALIDATION_SOURCE_ACQUISITION_OBJECT_FORMAT_UNSUPPORTED_DETAIL_MAPPING_MUTANT", "unsupported object-format tag")
  , ("VALIDATION_SOURCE_ACQUISITION_OBJECT_FORMAT_UNSUPPORTED_SUBJECT_MAPPING_MUTANT", "unsupported object-format tag")
  , ("VALIDATION_SOURCE_ACQUISITION_OBSERVER_EXECUTION_RESIDUE_CODE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_OBSERVER_EXECUTION_RESIDUE_DETAIL_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_OBSERVER_EXECUTION_RESIDUE_SUBJECT_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_OBSERVER_TOOL_DIGEST_MALFORMED_CODE_MAPPING_MUTANT", "malformed observer/tool digest")
  , ("VALIDATION_SOURCE_ACQUISITION_OBSERVER_TOOL_DIGEST_MALFORMED_DETAIL_MAPPING_MUTANT", "malformed observer/tool digest")
  , ("VALIDATION_SOURCE_ACQUISITION_OBSERVER_TOOL_DIGEST_MALFORMED_SUBJECT_MAPPING_MUTANT", "malformed observer/tool digest")
  , ("VALIDATION_SOURCE_ACQUISITION_OBSERVER_TOOL_MISMATCH_CODE_MAPPING_MUTANT", "wrong observer/tool digest")
  , ("VALIDATION_SOURCE_ACQUISITION_OBSERVER_TOOL_MISMATCH_DETAIL_MAPPING_MUTANT", "wrong observer/tool digest")
  , ("VALIDATION_SOURCE_ACQUISITION_OBSERVER_TOOL_MISMATCH_SUBJECT_MAPPING_MUTANT", "wrong observer/tool digest")
  , ("VALIDATION_SOURCE_ACQUISITION_OBSERVER_TOOL_OBSERVATION_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_OBSERVER_TOOL_OBSERVATION_KEY_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_OBSERVER_TOOL_OBSERVATION_VALUE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_ORACLE_QUALIFICATION_RESIDUE_CODE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_ORACLE_QUALIFICATION_RESIDUE_DETAIL_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_ORACLE_QUALIFICATION_RESIDUE_SUBJECT_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_PATH_CHARACTER_BYPASS_MUTANT", "path rejects ASCII character '\\NUL'")
  , ("VALIDATION_SOURCE_ACQUISITION_PATH_COLLISION_CASE_FOLD_MAPPING_MUTANT", "independent expected paths cannot alias under portable case folding")
  , ("VALIDATION_SOURCE_ACQUISITION_PATH_PREFIX_CASE_FOLD_MAPPING_MUTANT", "independent expected paths cannot alias by case-folded ancestry")
  , ("VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_AUX_REMOVAL_MUTANT", "Windows reserved basename AUX is rejected")
  , ("VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_COM1_REMOVAL_MUTANT", "Windows reserved basename COM1 is rejected")
  , ("VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_COM2_REMOVAL_MUTANT", "Windows reserved basename COM2 is rejected")
  , ("VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_COM3_REMOVAL_MUTANT", "Windows reserved basename COM3 is rejected")
  , ("VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_COM4_REMOVAL_MUTANT", "Windows reserved basename COM4 is rejected")
  , ("VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_COM5_REMOVAL_MUTANT", "Windows reserved basename COM5 is rejected")
  , ("VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_COM6_REMOVAL_MUTANT", "Windows reserved basename COM6 is rejected")
  , ("VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_COM7_REMOVAL_MUTANT", "Windows reserved basename COM7 is rejected")
  , ("VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_COM8_REMOVAL_MUTANT", "Windows reserved basename COM8 is rejected")
  , ("VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_CON_REMOVAL_MUTANT", "Windows reserved basename CON is rejected")
  , ("VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_LPT1_REMOVAL_MUTANT", "Windows reserved basename LPT1 is rejected")
  , ("VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_LPT2_REMOVAL_MUTANT", "Windows reserved basename LPT2 is rejected")
  , ("VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_LPT3_REMOVAL_MUTANT", "Windows reserved basename LPT3 is rejected")
  , ("VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_LPT4_REMOVAL_MUTANT", "Windows reserved basename LPT4 is rejected")
  , ("VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_LPT5_REMOVAL_MUTANT", "Windows reserved basename LPT5 is rejected")
  , ("VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_LPT6_REMOVAL_MUTANT", "Windows reserved basename LPT6 is rejected")
  , ("VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_LPT7_REMOVAL_MUTANT", "Windows reserved basename LPT7 is rejected")
  , ("VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_LPT8_REMOVAL_MUTANT", "Windows reserved basename LPT8 is rejected")
  , ("VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_NUL_REMOVAL_MUTANT", "Windows reserved basename NUL is rejected")
  , ("VALIDATION_SOURCE_ACQUISITION_PATH_RESERVED_PRN_REMOVAL_MUTANT", "Windows reserved basename PRN is rejected")
  , ("VALIDATION_SOURCE_ACQUISITION_PAYLOAD_LENGTH_VALUE_FOLD_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_PAYLOAD_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_PAYLOAD_TOO_LARGE_CODE_MAPPING_MUTANT", "declared payload above the closed 16 MiB limit")
  , ("VALIDATION_SOURCE_ACQUISITION_PAYLOAD_TOO_LARGE_DETAIL_MAPPING_MUTANT", "declared payload above the closed 16 MiB limit")
  , ("VALIDATION_SOURCE_ACQUISITION_PAYLOAD_TOO_LARGE_SUBJECT_MAPPING_MUTANT", "declared payload above the closed 16 MiB limit")
  , ("VALIDATION_SOURCE_ACQUISITION_PHASE_MALFORMED_CODE_MAPPING_MUTANT", "malformed phase")
  , ("VALIDATION_SOURCE_ACQUISITION_PHASE_MALFORMED_DETAIL_MAPPING_MUTANT", "malformed phase")
  , ("VALIDATION_SOURCE_ACQUISITION_PHASE_MALFORMED_SUBJECT_MAPPING_MUTANT", "malformed phase")
  , ("VALIDATION_SOURCE_ACQUISITION_PHASE_MISMATCH_CODE_MAPPING_MUTANT", "wrong but canonical phase")
  , ("VALIDATION_SOURCE_ACQUISITION_PHASE_MISMATCH_DETAIL_MAPPING_MUTANT", "wrong but canonical phase")
  , ("VALIDATION_SOURCE_ACQUISITION_PHASE_MISMATCH_SUBJECT_MAPPING_MUTANT", "wrong but canonical phase")
  , ("VALIDATION_SOURCE_ACQUISITION_PHASE_OBSERVATION_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_PHASE_OBSERVATION_KEY_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_PHASE_OBSERVATION_VALUE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_PROBLEM_DEDUPLICATION_BYPASS_MUTANT", "lowercase-hex identity one character over width is rejected (OracleObjectSha256)")
  , ("VALIDATION_SOURCE_ACQUISITION_PROBLEM_FINDING_CARRIER_DROP_MUTANT", "wrong but canonical phase")
  , ("VALIDATION_SOURCE_ACQUISITION_PROBLEM_FINDING_ORDER_MUTANT", "malformed phase")
  , ("VALIDATION_SOURCE_ACQUISITION_PROBLEM_LIMIT_EXCEEDED_CODE_MAPPING_MUTANT", "129th integrity problem produces the bounded problem-limit refusal")
  , ("VALIDATION_SOURCE_ACQUISITION_PROBLEM_LIMIT_EXCEEDED_DETAIL_MAPPING_MUTANT", "129th integrity problem produces the bounded problem-limit refusal")
  , ("VALIDATION_SOURCE_ACQUISITION_PROBLEM_LIMIT_EXCEEDED_SUBJECT_MAPPING_MUTANT", "129th integrity problem produces the bounded problem-limit refusal")
  , ("VALIDATION_SOURCE_ACQUISITION_PROBLEM_SORT_ORDER_MUTANT", "malformed phase")
  , ("VALIDATION_SOURCE_ACQUISITION_PUBLIC_KEY_INPUT_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_PUBLIC_KEY_INVALID_CODE_MAPPING_MUTANT", "31-byte Ed25519 public key is rejected before payload decoding")
  , ("VALIDATION_SOURCE_ACQUISITION_PUBLIC_KEY_INVALID_DETAIL_MAPPING_MUTANT", "31-byte Ed25519 public key is rejected before payload decoding")
  , ("VALIDATION_SOURCE_ACQUISITION_PUBLIC_KEY_INVALID_SUBJECT_MAPPING_MUTANT", "31-byte Ed25519 public key is rejected before payload decoding")
  , ("VALIDATION_SOURCE_ACQUISITION_RENDER_CUSTODY_FROZEN_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_RENDER_MODE_EXECUTABLE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_RENDER_MODE_REGULAR_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_RENDER_MODE_SYMBOLIC_LINK_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_RENDER_OBJECT_FORMAT_SHA1_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_RENDER_OBJECT_FORMAT_SHA256_MUTANT", "canonical SHA-256 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_REPLAY_DETECTED_CODE_MAPPING_MUTANT", "consumed replay identity")
  , ("VALIDATION_SOURCE_ACQUISITION_REPLAY_DETECTED_DETAIL_MAPPING_MUTANT", "consumed replay identity")
  , ("VALIDATION_SOURCE_ACQUISITION_REPLAY_DETECTED_SUBJECT_MAPPING_MUTANT", "consumed replay identity")
  , ("VALIDATION_SOURCE_ACQUISITION_REPLAY_IDENTITY_MALFORMED_CODE_MAPPING_MUTANT", "malformed replay identity")
  , ("VALIDATION_SOURCE_ACQUISITION_REPLAY_IDENTITY_MALFORMED_DETAIL_MAPPING_MUTANT", "malformed replay identity")
  , ("VALIDATION_SOURCE_ACQUISITION_REPLAY_IDENTITY_MALFORMED_SUBJECT_MAPPING_MUTANT", "malformed replay identity")
  , ("VALIDATION_SOURCE_ACQUISITION_REPLAY_IDENTITY_OBSERVATION_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_REPLAY_IDENTITY_OBSERVATION_KEY_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_REPLAY_IDENTITY_OBSERVATION_VALUE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_REPLAY_SET_ENTRY_TOO_LARGE_CODE_MAPPING_MUTANT", "each consumed replay identity is bounded before authentication or comparison")
  , ("VALIDATION_SOURCE_ACQUISITION_REPLAY_SET_ENTRY_TOO_LARGE_DETAIL_MAPPING_MUTANT", "each consumed replay identity is bounded before authentication or comparison")
  , ("VALIDATION_SOURCE_ACQUISITION_REPLAY_SET_ENTRY_TOO_LARGE_SUBJECT_MAPPING_MUTANT", "each consumed replay identity is bounded before authentication or comparison")
  , ("VALIDATION_SOURCE_ACQUISITION_REPLAY_SET_TOO_LARGE_CODE_MAPPING_MUTANT", "consumed replay set count is bounded before authentication or comparison")
  , ("VALIDATION_SOURCE_ACQUISITION_REPLAY_SET_TOO_LARGE_DETAIL_MAPPING_MUTANT", "consumed replay set count is bounded before authentication or comparison")
  , ("VALIDATION_SOURCE_ACQUISITION_REPLAY_SET_TOO_LARGE_SUBJECT_MAPPING_MUTANT", "consumed replay set count is bounded before authentication or comparison")
  , ("VALIDATION_SOURCE_ACQUISITION_REPLAY_STATE_RESIDUE_CODE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_REPLAY_STATE_RESIDUE_DETAIL_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_REPLAY_STATE_RESIDUE_SUBJECT_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_REPOSITORY_IDENTITY_MALFORMED_CODE_MAPPING_MUTANT", "signed repository identity must be canonical SHA-256")
  , ("VALIDATION_SOURCE_ACQUISITION_REPOSITORY_IDENTITY_MALFORMED_DETAIL_MAPPING_MUTANT", "signed repository identity must be canonical SHA-256")
  , ("VALIDATION_SOURCE_ACQUISITION_REPOSITORY_IDENTITY_MALFORMED_SUBJECT_MAPPING_MUTANT", "signed repository identity must be canonical SHA-256")
  , ("VALIDATION_SOURCE_ACQUISITION_REPOSITORY_IDENTITY_MISMATCH_CODE_MAPPING_MUTANT", "signed repository identity differs from external intent")
  , ("VALIDATION_SOURCE_ACQUISITION_REPOSITORY_IDENTITY_MISMATCH_DETAIL_MAPPING_MUTANT", "signed repository identity differs from external intent")
  , ("VALIDATION_SOURCE_ACQUISITION_REPOSITORY_IDENTITY_MISMATCH_SUBJECT_MAPPING_MUTANT", "signed repository identity differs from external intent")
  , ("VALIDATION_SOURCE_ACQUISITION_REPOSITORY_OBSERVATION_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_REPOSITORY_OBSERVATION_KEY_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_REPOSITORY_OBSERVATION_VALUE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_REQUESTED_REVISION_MALFORMED_CODE_MAPPING_MUTANT", "empty requested revision is rejected")
  , ("VALIDATION_SOURCE_ACQUISITION_REQUESTED_REVISION_MALFORMED_DETAIL_MAPPING_MUTANT", "empty requested revision is rejected")
  , ("VALIDATION_SOURCE_ACQUISITION_REQUESTED_REVISION_MALFORMED_SUBJECT_MAPPING_MUTANT", "empty requested revision is rejected")
  , ("VALIDATION_SOURCE_ACQUISITION_REQUESTED_REVISION_MISMATCH_CODE_MAPPING_MUTANT", "empty requested revision is rejected")
  , ("VALIDATION_SOURCE_ACQUISITION_REQUESTED_REVISION_MISMATCH_DETAIL_MAPPING_MUTANT", "empty requested revision is rejected")
  , ("VALIDATION_SOURCE_ACQUISITION_REQUESTED_REVISION_MISMATCH_SUBJECT_MAPPING_MUTANT", "empty requested revision is rejected")
  , ("VALIDATION_SOURCE_ACQUISITION_REQUESTED_REVISION_OBSERVATION_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_REQUESTED_REVISION_OBSERVATION_KEY_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_REQUESTED_REVISION_OBSERVATION_VALUE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_RESULT_CHECK_NAME_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_RESULT_FINDING_ORDER_MUTANT", "wrong but canonical phase")
  , ("VALIDATION_SOURCE_ACQUISITION_RESULT_OBSERVATION_ORDER_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_RESULT_PROBLEM_LIMIT_TIGHTEN_MUTANT", "exact 128-problem diagnostic limit retains every integrity problem")
  , ("VALIDATION_SOURCE_ACQUISITION_SCHEMA_OBSERVATION_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_SCHEMA_OBSERVATION_KEY_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_SCHEMA_OBSERVATION_VALUE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_SESSION_CUSTODY_RESIDUE_CODE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_SESSION_CUSTODY_RESIDUE_DETAIL_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_SESSION_CUSTODY_RESIDUE_SUBJECT_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_SIGNATURE_INVALID_CODE_MAPPING_MUTANT", "exact 16384-entry consumed replay-set limit reaches authentication")
  , ("VALIDATION_SOURCE_ACQUISITION_SIGNATURE_INVALID_DETAIL_MAPPING_MUTANT", "exact 16384-entry consumed replay-set limit reaches authentication")
  , ("VALIDATION_SOURCE_ACQUISITION_SIGNATURE_INVALID_SUBJECT_MAPPING_MUTANT", "exact 16384-entry consumed replay-set limit reaches authentication")
  , ("VALIDATION_SOURCE_ACQUISITION_SIGNATURE_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_SIGNED_PREFIX_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_SIZED_BYTES_LENGTH_PREFIX_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_SIZED_BYTES_VALUE_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_SIZED_TEXT_UTF8_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_SOURCE_IDENTITY_BYTES_CONTRIBUTION_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_SOURCE_IDENTITY_MEMBER_ASSOCIATION_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_SOURCE_IDENTITY_MODE_CONTRIBUTION_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_SOURCE_IDENTITY_OBJECT_CONTRIBUTION_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_SOURCE_IDENTITY_PATH_CONTRIBUTION_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_SOURCE_SNAPSHOT_IDENTITY_MALFORMED_CODE_MAPPING_MUTANT", "malformed source-snapshot identity")
  , ("VALIDATION_SOURCE_ACQUISITION_SOURCE_SNAPSHOT_IDENTITY_MALFORMED_DETAIL_MAPPING_MUTANT", "malformed source-snapshot identity")
  , ("VALIDATION_SOURCE_ACQUISITION_SOURCE_SNAPSHOT_IDENTITY_MALFORMED_SUBJECT_MAPPING_MUTANT", "malformed source-snapshot identity")
  , ("VALIDATION_SOURCE_ACQUISITION_SOURCE_SNAPSHOT_IDENTITY_MISMATCH_CODE_MAPPING_MUTANT", "wrong source-snapshot identity")
  , ("VALIDATION_SOURCE_ACQUISITION_SOURCE_SNAPSHOT_IDENTITY_MISMATCH_DETAIL_MAPPING_MUTANT", "wrong source-snapshot identity")
  , ("VALIDATION_SOURCE_ACQUISITION_SOURCE_SNAPSHOT_IDENTITY_MISMATCH_SUBJECT_MAPPING_MUTANT", "wrong source-snapshot identity")
  , ("VALIDATION_SOURCE_ACQUISITION_SOURCE_SNAPSHOT_OBSERVATION_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_SOURCE_SNAPSHOT_OBSERVATION_KEY_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_SOURCE_SNAPSHOT_OBSERVATION_VALUE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_STREAMING_INGRESS_RESIDUE_CODE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_STREAMING_INGRESS_RESIDUE_DETAIL_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_STREAMING_INGRESS_RESIDUE_SUBJECT_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_TREE_BLOB_MODE_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_TREE_BLOB_NAME_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_TREE_BLOB_NUL_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_TREE_BLOB_OBJECT_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_TREE_BLOB_SEPARATOR_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_TREE_DIRECTORY_MODE_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_TREE_DIRECTORY_NAME_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_TREE_DIRECTORY_NUL_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_TREE_DIRECTORY_OBJECT_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_TREE_DIRECTORY_SEPARATOR_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_TREE_IDENTITY_MALFORMED_CODE_MAPPING_MUTANT", "malformed tree identity")
  , ("VALIDATION_SOURCE_ACQUISITION_TREE_IDENTITY_MALFORMED_DETAIL_MAPPING_MUTANT", "malformed tree identity")
  , ("VALIDATION_SOURCE_ACQUISITION_TREE_IDENTITY_MALFORMED_SUBJECT_MAPPING_MUTANT", "malformed tree identity")
  , ("VALIDATION_SOURCE_ACQUISITION_TREE_IDENTITY_MISMATCH_CODE_MAPPING_MUTANT", "valid-width but wrong tree identity")
  , ("VALIDATION_SOURCE_ACQUISITION_TREE_IDENTITY_MISMATCH_DETAIL_MAPPING_MUTANT", "valid-width but wrong tree identity")
  , ("VALIDATION_SOURCE_ACQUISITION_TREE_IDENTITY_MISMATCH_SUBJECT_MAPPING_MUTANT", "valid-width but wrong tree identity")
  , ("VALIDATION_SOURCE_ACQUISITION_TREE_OBSERVATION_DROP_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_TREE_OBSERVATION_KEY_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_TREE_OBSERVATION_VALUE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_TRUST_ANCHOR_RESIDUE_CODE_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_TRUST_ANCHOR_RESIDUE_DETAIL_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_TRUST_ANCHOR_RESIDUE_SUBJECT_MAPPING_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_WIRE_INPUT_ROUTE_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_WIRE_MALFORMED_CODE_MAPPING_MUTANT", "payload-length syntax rejects a plus sign before authentication")
  , ("VALIDATION_SOURCE_ACQUISITION_WIRE_MALFORMED_DETAIL_MAPPING_MUTANT", "payload-length syntax rejects a plus sign before authentication")
  , ("VALIDATION_SOURCE_ACQUISITION_WIRE_MALFORMED_SUBJECT_MAPPING_MUTANT", "payload-length syntax rejects a plus sign before authentication")
  , ("VALIDATION_SOURCE_ACQUISITION_WIRE_NON_CANONICAL_CODE_MAPPING_MUTANT", "authenticated leading-zero length is noncanonical")
  , ("VALIDATION_SOURCE_ACQUISITION_WIRE_NON_CANONICAL_DETAIL_MAPPING_MUTANT", "authenticated leading-zero length is noncanonical")
  , ("VALIDATION_SOURCE_ACQUISITION_WIRE_NON_CANONICAL_SUBJECT_MAPPING_MUTANT", "authenticated leading-zero length is noncanonical")
  , ("VALIDATION_SOURCE_ACQUISITION_WORD32_FOLD_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_WORD32_TRUNCATION_CLASSIFICATION_MUTANT", "exact 16384-entry expected-manifest limit reaches entry framing")
  , ("VALIDATION_SOURCE_ACQUISITION_WORD64_FOLD_MUTANT", "canonical SHA-1 frozen source bundle")
  , ("VALIDATION_SOURCE_ACQUISITION_WORD64_TRUNCATION_CLASSIFICATION_MUTANT", "authenticated eight-byte entry length framing is exact")
  , ("VALIDATION_SOURCE_ACQUISITION_WORD8_MISSING_CLASSIFICATION_MUTANT", "authenticated missing one-byte custody field is classified exactly")
  ]

sourceAcquisitionSelectorTargetLabels :: [String]
sourceAcquisitionSelectorTargetLabels =
  sourceAcquisitionSelectorTargetLabelsInitial
    <> sourceAcquisitionSelectorTargetLabelsExpansion

sourceAcquisitionSelectorTargetLabelsInitial :: [String]
sourceAcquisitionSelectorTargetLabelsInitial =
  [ "31-byte Ed25519 public key is rejected before payload decoding"
  , "65 parent headers exceed the closed 67-header limit"
  , "65 signature bytes are rejected by the exact signature framing guard"
  , "Git directory-sort hard case remains internally consistent"
  , "NUL is rejected even when confined to an otherwise canonical commit message (OracleObjectSha1)"
  , "Windows reserved basename COM1 is rejected"
  , "Windows reserved basename COM9 is rejected"
  , "Windows reserved basename CON is rejected"
  , "Windows reserved basename LPT1 is rejected"
  , "Windows reserved basename LPT9 is rejected"
  , "Windows reserved basename matching ignores an extension"
  , "Windows reserved basename matching is case-insensitive"
  , "a 1025-byte identity header exceeds the closed line limit"
  , "authenticated bad payload magic"
  , "authenticated field above the closed 4096-byte limit"
  , "authenticated leading-zero length is noncanonical"
  , "authenticated main payload trailing byte is rejected by its own guard"
  , "authenticated field value availability is exact"
  , "author identity values use the closed canonical grammar"
  , "authority admits its complete closed character alphabet"
  , "bad envelope magic precedes public-key and payload interpretation"
  , "bit-flipped signature rejects the canonical envelope"
  , "blob SHA-256 differs from the exact member bytes"
  , "blob bytes do not match the Git object identity"
  , "bundle above the closed 32 MiB limit"
  , "canonical SHA-1 frozen source bundle"
  , "canonical SHA-256 frozen source bundle"
  , "canonical commit tree must join the signed tree identity"
  , "carriage return is rejected in the commit header block (OracleObjectSha1)"
  , "case-folded dot-git segment is rejected"
  , "commit bytes exceed the closed one-MiB limit"
  , "commit continuation headers are forbidden"
  , "commit header with an empty value is rejected (OracleObjectSha1)"
  , "commit header with no value separator is rejected (OracleObjectSha1)"
  , "commit identity rejects trailing fields (OracleObjectSha1)"
  , "commit requires a committer after its author"
  , "commit requires the canonical header/message separator"
  , "commit tree identity uppercase is rejected (OracleObjectSha1)"
  , "commit tree identity width under is rejected (OracleObjectSha1)"
  , "consumed replay identity"
  , "consumed replay set count is bounded before authentication or comparison"
  , "correct-width ASCII nondigit phase is rejected"
  , "correct-width uppercase hexadecimal identity is rejected"
  , "correct-width uppercase hexadecimal identity is rejected (OracleObjectSha1)"
  , "declared member lengths differ from exact bundle length"
  , "declared payload above the closed 16 MiB limit"
  , "declared payload beyond available envelope bytes is a framing refusal"
  , "display name must be nonempty (OracleObjectSha1)"
  , "display name rejects bytes below printable ASCII (OracleObjectSha1)"
  , "display name rejects double space (OracleObjectSha1)"
  , "display name rejects greater-than (OracleObjectSha1)"
  , "display name rejects leading space (OracleObjectSha1)"
  , "display name rejects less-than (OracleObjectSha1)"
  , "display name rejects trailing space (OracleObjectSha1)"
  , "domain label rejects characters outside its closed set (OracleObjectSha1)"
  , "domain label rejects leading hyphen (OracleObjectSha1)"
  , "domain label rejects trailing hyphen (OracleObjectSha1)"
  , "domain rejects an empty middle label (OracleObjectSha1)"
  , "double-dot path segment is rejected"
  , "duplicate expected-manifest path"
  , "duplicate manifest path"
  , "each consumed replay identity is bounded before authentication or comparison"
  , "email domain requires multiple labels (OracleObjectSha1)"
  , "email local must be nonempty (OracleObjectSha1)"
  , "email local rejects characters outside its closed set (OracleObjectSha1)"
  , "email local rejects double dot (OracleObjectSha1)"
  , "email local rejects leading dot (OracleObjectSha1)"
  , "email local rejects trailing dot (OracleObjectSha1)"
  , "email requires exactly one at-sign (OracleObjectSha1)"
  , "empty commit bytes are rejected (OracleObjectSha1)"
  , "empty commit header block is rejected (OracleObjectSha1)"
  , "empty independently supplied expected manifest"
  , "empty manifest"
  , "empty payload-length decimal is rejected by its own guard"
  , "empty requested revision is rejected"
  , "empty signed authority is rejected"
  , "entry above the closed bundle-member limit"
  , "entry count immediately above 16384"
  , "envelope above its closed derived limit"
  , "every parent identity uses the selected Git object format"
  , "expected HEAD is bounded before authentication or comparison"
  , "expected authored root is bounded before authentication or comparison"
  , "expected authority is bounded before authentication or comparison"
  , "expected challenge is bounded before authentication or comparison"
  , "expected observer digest is bounded before authentication or comparison"
  , "expected phase is bounded before authentication or comparison"
  , "expected repository identity is bounded before authentication or comparison"
  , "expected revision is bounded before authentication or comparison"
  , "expected source snapshot is bounded before authentication or comparison"
  , "expected-manifest bytes exceed the closed 16-MiB limit"
  , "expected-manifest entry count immediately above 16384 is typed before allocation"
  , "expected-manifest magic is exact"
  , "expected-manifest trailing bytes are noncanonical"
  , "external authored-root identity differs from signed observation"
  , "external expected HEAD differs from signed HEAD"
  , "external expected source snapshot differs from signed snapshot"
  , "independent expected Git object differs from signed object"
  , "independent expected blob SHA-256 differs from signed value"
  , "independent expected byte length differs from signed length"
  , "independent expected entry size has the same closed materialization bound"
  , "independent expected mode differs from signed mode"
  , "independent expected object format must join the signed format"
  , "independent expected paths cannot alias by case-folded ancestry"
  , "independent expected paths cannot alias under portable case folding"
  , "independent universe addition exposes a missing signed entry"
  , "independent universe omission exposes an unexpected signed entry"
  , "invalid signature precedes malformed UTF-8 decoding"
  , "lowercase-hex identity one character under width is rejected"
  , "lowercase-hex identity one character under width is rejected (OracleObjectSha1)"
  , "malformed acquisition authority"
  , "middle empty path segment is rejected"
  , "missing payload-length terminator precedes key inspection"
  , "nine payload-length digits are rejected at the exact over-bound"
  , "noncanonical expected-manifest order"
  , "noncanonical manifest order"
  , "parent headers cannot appear after the committer"
  , "parent headers must be contiguous before author"
  , "path above the closed 1024-byte limit"
  , "path above the closed 64-component limit"
  , "path admits lowercase, uppercase, digit, slash, and every closed punctuation"
  , "path segment above the closed 255-byte limit"
  , "payload-length syntax rejects a plus sign before authentication"
  , "phase width one is rejected"
  , "portable case-fold equality collision"
  , "requested revision rejects a disallowed colon"
  , "requested revision rejects double dot"
  , "requested revision rejects double slash"
  , "requested revision rejects leading dash"
  , "requested revision rejects leading dot"
  , "requested revision rejects leading slash"
  , "requested revision rejects reflog syntax"
  , "requested revision rejects trailing dot"
  , "requested revision rejects trailing dot-lock"
  , "requested revision rejects trailing slash"
  , "revision admits every documented identifier character"
  , "same-case file/directory path conflict"
  , "sequential mutable custody cannot substitute for a frozen bundle"
  , "signed authority at 129 characters is rejected"
  , "signed commit bytes must recompute to HEAD"
  , "signed repository identity differs from external intent"
  , "signed requested revision at 257 characters is rejected"
  , "signed requested revision differs from external intent"
  , "single-dot path segment is rejected"
  , "structural refusal suppresses bundle content interpretation"
  , "timestamp rejects 20 digits (OracleObjectSha1)"
  , "timestamp rejects a nondigit after its first digit (OracleObjectSha1)"
  , "timestamp rejects leading zero before nonzero digit (OracleObjectSha1)"
  , "timezone hour 14 couples to minute zero (OracleObjectSha1)"
  , "timezone rejects a non-sign prefix (OracleObjectSha1)"
  , "timezone rejects a nondigit (OracleObjectSha1)"
  , "timezone rejects four-byte under-width value (OracleObjectSha1)"
  , "timezone rejects hour 15 (OracleObjectSha1)"
  , "timezone rejects minute 60 (OracleObjectSha1)"
  , "timezone rejects negative zero (OracleObjectSha1)"
  , "trailing-dot path segment is rejected"
  , "tree must be the first commit header (OracleObjectSha1)"
  , "unknown commit headers are forbidden"
  , "unsupported custody tag"
  , "unsupported entry-mode tag"
  , "unsupported expected-manifest mode preserves its typed decode problem"
  , "unsupported expected-manifest object-format tag is a typed wire refusal"
  , "unsupported object-format tag"
  , "valid signature exposes exact malformed UTF-8"
  , "valid-width but wrong tree identity"
  , "wrong acquisition authority"
  , "wrong but canonical phase"
  , "wrong fresh challenge"
  , "wrong frozen-snapshot identity"
  , "wrong immutable-bundle digest"
  , "wrong observer/tool digest"
  , "wrong source-snapshot identity"
  ]

sourceAcquisitionSelectorTargetLabelsExpansion :: [String]
sourceAcquisitionSelectorTargetLabelsExpansion =
  [ "129th integrity problem produces the bounded problem-limit refusal"
  , "130 problems cannot traverse past the integrity guard"
  , "Windows reserved basename AUX is rejected"
  , "Windows reserved basename COM2 is rejected"
  , "Windows reserved basename COM3 is rejected"
  , "Windows reserved basename COM4 is rejected"
  , "Windows reserved basename COM5 is rejected"
  , "Windows reserved basename COM6 is rejected"
  , "Windows reserved basename COM7 is rejected"
  , "Windows reserved basename COM8 is rejected"
  , "Windows reserved basename LPT2 is rejected"
  , "Windows reserved basename LPT3 is rejected"
  , "Windows reserved basename LPT4 is rejected"
  , "Windows reserved basename LPT5 is rejected"
  , "Windows reserved basename LPT6 is rejected"
  , "Windows reserved basename LPT7 is rejected"
  , "Windows reserved basename LPT8 is rejected"
  , "Windows reserved basename NUL is rejected"
  , "Windows reserved basename PRN is rejected"
  , "authenticated commit value availability is exact"
  , "authenticated eight-byte entry length framing is exact"
  , "authenticated missing one-byte custody field is classified exactly"
  , "author header cannot be duplicated"
  , "commit without author and committer is not canonical"
  , "committer cannot appear before author"
  , "committer header cannot be duplicated"
  , "domain label admits lowercase digits and interior hyphen (OracleObjectSha1)"
  , "email local admits every closed punctuation character (OracleObjectSha1)"
  , "email local admits lowercase digits (OracleObjectSha1)"
  , "entry Git object identity has the wrong storage format"
  , "entry blob SHA-256 has malformed shape"
  , "exact 128-problem diagnostic limit retains every integrity problem"
  , "exact 16384-entry consumed replay-set limit reaches authentication"
  , "exact 16384-entry expected-manifest limit reaches entry framing"
  , "expected phase bound measures UTF-8 bytes rather than characters"
  , "independent expected Git object identity must match the signed storage format"
  , "independent expected blob SHA-256 must be canonical"
  , "independent expected path must use the portable grammar"
  , "lowercase-hex identity one character over width is rejected"
  , "lowercase-hex identity one character over width is rejected (OracleObjectSha256)"
  , "malformed HEAD identity"
  , "malformed authored-root identity"
  , "malformed bundle identity"
  , "malformed fresh challenge"
  , "malformed frozen-snapshot identity"
  , "malformed observer/tool digest"
  , "malformed phase"
  , "malformed replay identity"
  , "malformed source-snapshot identity"
  , "malformed tree identity"
  , "parent-traversing path"
  , "path rejects ASCII character '\\NUL'"
  , "signed repository identity must be canonical SHA-256"
  , "timestamp exact 19-digit ceiling is canonical (OracleObjectSha1)"
  , "timestamp one is canonical (OracleObjectSha1)"
  , "timezone admits exact control -0001 (OracleObjectSha1)"
  , "tree header cannot be duplicated"
  ]

sourceAcquisitionSelectorNames :: [String]
sourceAcquisitionSelectorNames = map fst sourceAcquisitionSelectorIntents

sourceAcquisitionExactCases :: IO [ExactCase]
sourceAcquisitionExactCases = do
  secret <- Ed25519.generateSecretKey
  otherSecret <- Ed25519.generateSecretKey
  let public = Ed25519.toPublic secret
      otherPublic = Ed25519.toPublic otherSecret
      publicBytes = convert public
      otherPublicBytes = convert otherPublic
      sha1Fixture = canonicalFixture OracleObjectSha1
      sha256Fixture = canonicalFixture OracleObjectSha256
      sha1Expected = canonicalExpectation sha1Fixture
      sha256Expected = canonicalExpectation sha256Fixture
      sha1Wire = signFixture secret public sha1Fixture
      sha256Wire = signFixture secret public sha256Fixture
      cases =
        expectConsistent
          "canonical SHA-1 frozen source bundle"
          (fixtureManifest sha1Fixture)
          sha1Expected
          publicBytes
          sha1Wire
          (fixtureBundle sha1Fixture)
          <> expectConsistent
            "canonical SHA-256 frozen source bundle"
            (fixtureManifest sha256Fixture)
            sha256Expected
            publicBytes
            sha256Wire
            (fixtureBundle sha256Fixture)
          <> pinnedProtocolProblems
          <> directorySortProblems secret public publicBytes
          <> fieldProblems secret public publicBytes sha1Expected sha1Fixture
          <> closedFieldPredicateProblems
            secret
            public
            publicBytes
            sha1Expected
            sha1Fixture
            sha256Expected
            sha256Fixture
          <> expectationIngressProblems publicBytes sha1Expected sha1Fixture sha1Wire
          <> protocolIntentProblems secret public publicBytes sha1Expected sha1Fixture
          <> closedCommitPredicateProblems secret public publicBytes sha1Expected sha1Fixture
          <> closedCommitPredicateProblems secret public publicBytes sha256Expected sha256Fixture
          <> expectedManifestProblems secret public publicBytes sha1Expected sha1Fixture
          <> manifestProblems secret public publicBytes sha1Expected sha1Fixture
          <> closedPathPredicateProblems secret public publicBytes sha1Expected sha1Fixture
          <> ingressAndBoundaryProblems
            secret
            public
            publicBytes
            sha1Expected
            sha1Fixture
            sha1Wire
          <> wireAndAuthenticationProblems
            secret
            public
            publicBytes
            otherPublicBytes
            sha1Expected
            sha1Fixture
            sha1Wire
          <> closedWirePredicateProblems
            secret
            public
            publicBytes
            sha1Expected
            sha1Fixture
            sha1Wire
  pure cases

runSourceAcquisitionOracle :: IO ()
runSourceAcquisitionOracle = do
  cases <- sourceAcquisitionExactCases
  let problems = sourceAcquisitionSelectorRegistryProblems cases <> concatMap exactCaseProblems cases
  unless
    (null problems)
    ( fail
        ( "SourceAcquisitionOracle component diagnostic failures:\n  "
            <> unlinesWith "\n  " problems
        )
    )

runSourceAcquisitionCanonicalControl :: IO ()
runSourceAcquisitionCanonicalControl = do
  cases <- sourceAcquisitionExactCases
  let matching = exactCasesNamed "canonical SHA-1 frozen source bundle" cases
      problems = case matching of
        [candidate] -> exactCaseProblems candidate
        candidates ->
          [ "canonical SourceAcquisition control is not exactly resolvable; count="
              <> show (length candidates)
          ]
  unless
    (null problems)
    ( fail
        ( "SourceAcquisitionOracle canonical control failures:\n  "
            <> unlinesWith "\n  " problems
        )
    )

runSourceAcquisitionSelectorOracle :: String -> IO ()
runSourceAcquisitionSelectorOracle selector = do
  cases <- sourceAcquisitionExactCases
  let matching = selectorExactCases selector cases
      controls = exactCasesNamed selectorUnaffectedControlLabel cases
      problems =
        sourceAcquisitionSelectorRegistryProblems cases
          <> case matching of
            [candidate] -> exactCaseProblems candidate
            candidates ->
              [ "selector intent is not exactly resolvable: selector="
                  <> selector
                  <> "; exact-case-count="
                  <> show (length candidates)
              ]
          <> case controls of
            [control] -> exactCaseProblems control
            candidates ->
              [ "selector unaffected control is not exactly resolvable: label="
                  <> selectorUnaffectedControlLabel
                  <> "; exact-case-count="
                  <> show (length candidates)
              ]
  unless
    (null problems)
    ( fail
        ( "SourceAcquisitionOracle selector diagnostic failures:\n  "
            <> unlinesWith "\n  " problems
        )
    )

selectorExactCases :: String -> [ExactCase] -> [ExactCase]
selectorExactCases selector cases =
  [ candidate
  | target <- selectorTargets selector
  , candidate@(ExactCase label _) <- cases
  , label == target
  ]

selectorUnaffectedControlLabel :: String
selectorUnaffectedControlLabel = "RFC 8032 seed derives the published public key"

exactCasesNamed :: String -> [ExactCase] -> [ExactCase]
exactCasesNamed sought cases =
  [ candidate
  | candidate@(ExactCase label _) <- cases
  , label == sought
  ]

selectorTargets :: String -> [String]
selectorTargets selector =
  [ target
  | (candidate, target) <- sourceAcquisitionSelectorIntents
  , candidate == selector
  ]

exactCaseProblems :: ExactCase -> [String]
exactCaseProblems (ExactCase _ problems) = problems

sourceAcquisitionSelectorRegistryProblems :: [ExactCase] -> [String]
sourceAcquisitionSelectorRegistryProblems cases =
  [ "selector registry cardinality changed: expected=835; observed="
      <> show (length sourceAcquisitionSelectorIntents)
  | length sourceAcquisitionSelectorIntents /= 835
  ]
    <> duplicateProblems "selector registry identity" selectorNames
    <> duplicateProblems "declared selector target" sourceAcquisitionSelectorTargetLabels
    <> duplicateProblems "exact-case label" exactLabels
    <> [ "selector has target multiplicity other than one: selector="
           <> selector
           <> "; observed="
           <> show (occurrences selector selectorNames)
       | selector <- Set.toAscList (Set.fromList selectorNames)
       , occurrences selector selectorNames /= 1
       ]
    <> [ "selector registry references an unknown declared target: selector="
           <> selector
           <> "; target="
           <> target
       | (selector, target) <- sourceAcquisitionSelectorIntents
       , occurrences target sourceAcquisitionSelectorTargetLabels /= 1
       ]
    <> [ "declared selector target is unreferenced by the registry: target=" <> target
       | target <- sourceAcquisitionSelectorTargetLabels
       , occurrences target registryTargets == 0
       ]
    <> [ "declared selector target does not name exactly one exact case: target="
           <> target
           <> "; observed="
           <> show (occurrences target exactLabels)
       | target <- sourceAcquisitionSelectorTargetLabels
       , occurrences target exactLabels /= 1
       ]
 where
  selectorNames = map fst sourceAcquisitionSelectorIntents
  registryTargets = map snd sourceAcquisitionSelectorIntents
  exactLabels = [label | ExactCase label _ <- cases]

duplicateProblems :: String -> [String] -> [String]
duplicateProblems kind values =
  [ kind <> " is duplicated: " <> value
  | value <- Set.toAscList (Set.fromList values)
  , occurrences value values > 1
  ]

occurrences :: Eq value => value -> [value] -> Int
occurrences sought = length . filter (== sought)

canonicalExpectation :: OracleFixture -> OracleExpectation
canonicalExpectation fixture =
  OracleExpectation
    { oracleExpectedPhase = "00"
    , oracleExpectedAuthority = canonicalAuthority
    , oracleExpectedObserverToolDigest = canonicalObserverDigest
    , oracleExpectedChallenge = canonicalChallenge
    , oracleConsumedReplayIdentities = Set.empty
    , oracleExpectedRepositoryIdentity = oracleRepositoryIdentity manifest
    , oracleExpectedRequestedRevision = oracleRequestedRevision manifest
    , oracleExpectedHeadIdentity = oracleHeadIdentity manifest
    , oracleExpectedSourceSnapshotIdentity = oracleSourceSnapshotIdentityField manifest
    , oracleExpectedAuthoredRootIdentity = oracleAuthoredRootIdentityField manifest
    , oracleExpectedManifestBytes = oracleExpectedManifestEncoding manifest
    }
 where
  manifest = fixtureManifest fixture

canonicalAuthority :: Text
canonicalAuthority = "phase-00-source-observer"

canonicalObserverDigest :: Text
canonicalObserverDigest = oracleSha256 "independent-source-observer-v1"

canonicalChallenge :: Text
canonicalChallenge = oracleSha256 "fresh-phase-00-challenge"

canonicalReplayIdentity :: Text
canonicalReplayIdentity = oracleSha256 "fresh-phase-00-replay-identity"

canonicalRepositoryIdentity :: Text
canonicalRepositoryIdentity = oracleSha256 "amoebius-repository-identity-v1"

canonicalRequestedRevision :: Text
canonicalRequestedRevision = "refs/heads/main"

canonicalExternalAuthoredRootIdentity :: Text
canonicalExternalAuthoredRootIdentity = oracleSha256 "external-complete-authored-root-observation-v1"

canonicalFixture :: OracleObjectFormat -> OracleFixture
canonicalFixture objectFormat =
  deriveFixture
    template
    [ member objectFormat "README.md" OracleRegularFile "# signed source bundle\n"
    , member objectFormat "bin/tool" OracleExecutableFile "#!/bin/false\n"
    , member objectFormat "link" OracleSymbolicLink "README.md"
    , member objectFormat "src/Main.hs" OracleRegularFile "module Main where\n"
    ]
 where
  width = objectIdentityWidth objectFormat
  template =
    OracleManifest
      { oraclePhase = "00"
      , oracleAuthority = canonicalAuthority
      , oracleObserverToolDigest = canonicalObserverDigest
      , oracleChallenge = canonicalChallenge
      , oracleReplayIdentity = canonicalReplayIdentity
      , oracleRepositoryIdentity = canonicalRepositoryIdentity
      , oracleRequestedRevision = canonicalRequestedRevision
      , oracleCustody = OracleFrozenReadOnlyBundle
      , oracleObjectFormat = objectFormat
      , oracleHeadIdentity = Text.replicate width "0"
      , oracleTreeIdentityField = Text.replicate width "0"
      , oracleAuthoredRootIdentityField = canonicalExternalAuthoredRootIdentity
      , oracleFrozenSnapshotIdentityField = Text.replicate 64 "0"
      , oracleBundleIdentityField = Text.replicate 64 "0"
      , oracleSourceSnapshotIdentityField = Text.replicate 64 "0"
      , oracleCommitBytes = ByteString.empty
      , oracleEntries = []
      }

member
  :: OracleObjectFormat
  -> FilePath
  -> OracleMode
  -> ByteString
  -> (OracleEntry, ByteString)
member objectFormat path mode bytes =
  ( OracleEntry
      { oracleEntryPath = path
      , oracleEntryMode = mode
      , oracleEntryGitObjectId = oracleGitObjectIdentity objectFormat "blob" bytes
      , oracleEntryByteLength = fromIntegral (ByteString.length bytes)
      , oracleEntryBlobSha256 = oracleSha256 bytes
      }
  , bytes
  )

deriveFixture
  :: OracleManifest
  -> [(OracleEntry, ByteString)]
  -> OracleFixture
deriveFixture template members =
  OracleFixture finalManifest members bundle
 where
  entries = map fst members
  bundle = ByteString.concat (map snd members)
  treeIdentity = oracleTreeIdentity (oracleObjectFormat template) entries
  bundleIdentity = oracleSha256 bundle
  sourceIdentity = oracleSourceSnapshotIdentity (oracleObjectFormat template) members
  commitBytes = oracleCanonicalCommit treeIdentity
  headIdentity = oracleGitObjectIdentity (oracleObjectFormat template) "commit" commitBytes
  manifestWithoutFrozen =
    template
      { oracleHeadIdentity = headIdentity
      , oracleTreeIdentityField = treeIdentity
      , oracleBundleIdentityField = bundleIdentity
      , oracleSourceSnapshotIdentityField = sourceIdentity
      , oracleCommitBytes = commitBytes
      , oracleEntries = entries
      }
  finalManifest =
    manifestWithoutFrozen
      { oracleFrozenSnapshotIdentityField =
          oracleFrozenSnapshotIdentity manifestWithoutFrozen
      }

signFixture
  :: Ed25519.SecretKey
  -> Ed25519.PublicKey
  -> OracleFixture
  -> ByteString
signFixture secret public = signManifest secret public . fixtureManifest

signManifest
  :: Ed25519.SecretKey
  -> Ed25519.PublicKey
  -> OracleManifest
  -> ByteString
signManifest secret public manifest =
  signPrefix secret public (oracleEnvelopePrefix manifest)

signPayload
  :: Ed25519.SecretKey
  -> Ed25519.PublicKey
  -> ByteString
  -> ByteString
signPayload secret public payload =
  signPrefix secret public (wirePrefixWithPayload payload)

signPrefix
  :: Ed25519.SecretKey
  -> Ed25519.PublicKey
  -> ByteString
  -> ByteString
signPrefix secret public prefix =
  prefix <> convert (Ed25519.sign secret public prefix)

oracleEnvelopePrefix :: OracleManifest -> ByteString
oracleEnvelopePrefix = wirePrefixWithPayload . oracleManifestBytes

wirePrefixWithPayload :: ByteString -> ByteString
wirePrefixWithPayload payload =
  envelopeMagic
    <> ByteString8.pack (show (ByteString.length payload))
    <> "\n"
    <> payload

oracleManifestBytes :: OracleManifest -> ByteString
oracleManifestBytes manifest =
  LazyByteString.toStrict
    ( toLazyByteString
        ( byteString payloadMagic
            <> oracleSizedText (oraclePhase manifest)
            <> oracleSizedText (oracleAuthority manifest)
            <> oracleSizedText (oracleObserverToolDigest manifest)
            <> oracleSizedText (oracleChallenge manifest)
            <> oracleSizedText (oracleReplayIdentity manifest)
            <> oracleSizedText (oracleRepositoryIdentity manifest)
            <> oracleSizedText (oracleRequestedRevision manifest)
            <> word8 (oracleCustodyTag (oracleCustody manifest))
            <> word8 (oracleObjectFormatTag (oracleObjectFormat manifest))
            <> oracleSizedText (oracleHeadIdentity manifest)
            <> oracleSizedText (oracleTreeIdentityField manifest)
            <> oracleSizedText (oracleAuthoredRootIdentityField manifest)
            <> oracleSizedText (oracleFrozenSnapshotIdentityField manifest)
            <> oracleSizedText (oracleBundleIdentityField manifest)
            <> oracleSizedText (oracleSourceSnapshotIdentityField manifest)
            <> oracleSizedBytes (oracleCommitBytes manifest)
            <> word32BE (fromIntegral (length (oracleEntries manifest)))
            <> foldMap oracleEntryBytes (oracleEntries manifest)
        )
    )

oracleSizedText :: Text -> Builder
oracleSizedText value =
  let bytes = TextEncoding.encodeUtf8 value
   in word32BE (fromIntegral (ByteString.length bytes)) <> byteString bytes

oracleSizedBytes :: ByteString -> Builder
oracleSizedBytes bytes = word32BE (fromIntegral (ByteString.length bytes)) <> byteString bytes

oracleEntryBytes :: OracleEntry -> Builder
oracleEntryBytes entry =
  oracleSizedText (Text.pack (oracleEntryPath entry))
    <> word8 (oracleModeTag (oracleEntryMode entry))
    <> oracleSizedText (oracleEntryGitObjectId entry)
    <> word64BE (oracleEntryByteLength entry)
    <> oracleSizedText (oracleEntryBlobSha256 entry)

oracleCustodyTag :: OracleCustody -> Word8
oracleCustodyTag OracleFrozenReadOnlyBundle = 1
oracleCustodyTag OracleSequentialMutableBundle = 2

oracleObjectFormatTag :: OracleObjectFormat -> Word8
oracleObjectFormatTag OracleObjectSha1 = 1
oracleObjectFormatTag OracleObjectSha256 = 2

oracleModeTag :: OracleMode -> Word8
oracleModeTag OracleRegularFile = 1
oracleModeTag OracleExecutableFile = 2
oracleModeTag OracleSymbolicLink = 3

envelopeMagic :: ByteString
envelopeMagic = "amoebius-source-acquisition-envelope-v2\n"

payloadMagic :: ByteString
payloadMagic = "amoebius-source-acquisition-v2\0"

expectedManifestMagic :: ByteString
expectedManifestMagic = "amoebius-source-acquisition-expected-manifest-v1\0"

oracleExpectedManifestEncoding :: OracleManifest -> ByteString
oracleExpectedManifestEncoding manifest =
  LazyByteString.toStrict
    ( toLazyByteString
        ( byteString expectedManifestMagic
            <> word8 (oracleObjectFormatTag (oracleObjectFormat manifest))
            <> word32BE (fromIntegral (length (oracleEntries manifest)))
            <> foldMap oracleEntryBytes (oracleEntries manifest)
        )
    )

oracleExpectedManifestEncodingFor
  :: OracleObjectFormat
  -> [OracleEntry]
  -> ByteString
oracleExpectedManifestEncodingFor objectFormat entries =
  LazyByteString.toStrict
    ( toLazyByteString
        ( byteString expectedManifestMagic
            <> word8 (oracleObjectFormatTag objectFormat)
            <> word32BE (fromIntegral (length entries))
            <> foldMap oracleEntryBytes entries
        )
    )

oracleCanonicalCommit :: Text -> ByteString
oracleCanonicalCommit treeIdentity =
  TextEncoding.encodeUtf8
    ( "tree "
        <> treeIdentity
        <> "\nauthor Amoebius Oracle <oracle@example.invalid> 0 +0000"
        <> "\ncommitter Amoebius Oracle <oracle@example.invalid> 0 +0000"
        <> "\n\nsource acquisition fixture\n"
    )

oracleCanonicalIdentity :: ByteString
oracleCanonicalIdentity = "Amoebius Oracle <oracle@example.invalid> 0 +0000"

oracleCommitWithHeaders :: [ByteString] -> ByteString
oracleCommitWithHeaders headers =
  ByteString.intercalate "\n" headers <> "\n\nsource acquisition fixture\n"

oracleCommitWithoutSeparator :: [ByteString] -> ByteString
oracleCommitWithoutSeparator = ByteString.intercalate "\n"

oracleCommitAtExactLength :: Int -> [ByteString] -> ByteString
oracleCommitAtExactLength targetLength headers
  | ByteString.length prefix > targetLength =
      error "oracle commit prefix exceeds requested exact length"
  | otherwise =
      prefix <> ByteString.replicate (targetLength - ByteString.length prefix) 120
 where
  prefix = ByteString.intercalate "\n" headers <> "\n\n"

oracleTreeHeader :: OracleManifest -> ByteString
oracleTreeHeader manifest =
  "tree " <> TextEncoding.encodeUtf8 (oracleTreeIdentityField manifest)

expectConsistent
  :: String
  -> OracleManifest
  -> OracleExpectation
  -> ByteString
  -> ByteString
  -> ByteString
  -> [ExactCase]
expectConsistent label manifest expected publicKey wire bundle =
  expectEqual
    label
    (consistentDiagnostic manifest)
    (runDiagnostic (alignFullExpectation manifest expected) publicKey wire bundle)

alignIdentityExpectation :: OracleManifest -> OracleExpectation -> OracleExpectation
alignIdentityExpectation manifest expected =
  expected
    { oracleExpectedHeadIdentity = oracleHeadIdentity manifest
    , oracleExpectedSourceSnapshotIdentity = oracleSourceSnapshotIdentityField manifest
    , oracleExpectedAuthoredRootIdentity = oracleAuthoredRootIdentityField manifest
    }

alignFullExpectation :: OracleManifest -> OracleExpectation -> OracleExpectation
alignFullExpectation manifest expected =
  (alignIdentityExpectation manifest expected)
    { oracleExpectedManifestBytes = oracleExpectedManifestEncoding manifest
    }

expectRefused
  :: String
  -> [Finding]
  -> OracleExpectation
  -> ByteString
  -> ByteString
  -> ByteString
  -> [ExactCase]
expectRefused label expectedProblems expected publicKey wire bundle =
  expectEqual
    label
    (refusedDiagnostic expectedProblems)
    (runDiagnostic expected publicKey wire bundle)

runDiagnostic
  :: OracleExpectation
  -> ByteString
  -> ByteString
  -> ByteString
  -> CheckResult
runDiagnostic expected =
  sourceAcquisitionDiagnostic
    (oracleExpectedPhase expected)
    (oracleExpectedAuthority expected)
    (oracleExpectedObserverToolDigest expected)
    (oracleExpectedChallenge expected)
    (oracleConsumedReplayIdentities expected)
    (oracleExpectedRepositoryIdentity expected)
    (oracleExpectedRequestedRevision expected)
    (oracleExpectedHeadIdentity expected)
    (oracleExpectedSourceSnapshotIdentity expected)
    (oracleExpectedAuthoredRootIdentity expected)
    (oracleExpectedManifestBytes expected)

consistentDiagnostic :: OracleManifest -> CheckResult
consistentDiagnostic manifest =
  CheckResult
    { checkName = "source-acquisition-diagnostic"
    , checkObservations =
        Observation
          "source-acquisition.integrity"
          "internally consistent diagnostic; candidate authority absent"
          : manifestObservations manifest
    , checkFindings = expectedDiagnosticResidue
    }

refusedDiagnostic :: [Finding] -> CheckResult
refusedDiagnostic problems =
  CheckResult
    { checkName = "source-acquisition-diagnostic"
    , checkObservations =
        [ Observation
            "source-acquisition.integrity"
            ( "refused with "
                <> Text.pack (show (length problems))
                <> " integrity finding(s)"
            )
        ]
    , checkFindings = problems <> expectedDiagnosticResidue
    }

manifestObservations :: OracleManifest -> [Observation]
manifestObservations manifest =
  [ Observation "source-acquisition.schema" "amoebius-source-acquisition-v2"
  , Observation "source-acquisition.phase" (oraclePhase manifest)
  , Observation "source-acquisition.authority" (oracleAuthority manifest)
  , Observation "source-acquisition.observer-tool" (oracleObserverToolDigest manifest)
  , Observation "source-acquisition.challenge" (oracleChallenge manifest)
  , Observation "source-acquisition.replay-identity" (oracleReplayIdentity manifest)
  , Observation "source-acquisition.repository" (oracleRepositoryIdentity manifest)
  , Observation "source-acquisition.requested-revision" (oracleRequestedRevision manifest)
  , Observation "source-acquisition.custody" (oracleRenderCustody (oracleCustody manifest))
  , Observation "source-acquisition.object-format" (oracleRenderObjectFormat (oracleObjectFormat manifest))
  , Observation "source-acquisition.head" (oracleHeadIdentity manifest)
  , Observation "source-acquisition.tree" (oracleTreeIdentityField manifest)
  , Observation "source-acquisition.authored-root" (oracleAuthoredRootIdentityField manifest)
  , Observation "source-acquisition.frozen-snapshot" (oracleFrozenSnapshotIdentityField manifest)
  , Observation "source-acquisition.bundle" (oracleBundleIdentityField manifest)
  , Observation "source-acquisition.source-snapshot" (oracleSourceSnapshotIdentityField manifest)
  , Observation "source-acquisition.commit-byte-count" (Text.pack (show (ByteString.length (oracleCommitBytes manifest))))
  , Observation "source-acquisition.entry-count" (Text.pack (show (length (oracleEntries manifest))))
  ]

expectedDiagnosticResidue :: [Finding]
expectedDiagnosticResidue =
  [ Finding
      "SOURCE-ACQUISITION-DIAGNOSTIC-ONLY"
      "Amoebius.Validation.SourceAcquisition"
      "a caller-supplied signed bundle is a component diagnostic and cannot construct AcquiredSourceSnapshot"
  , Finding
      "SOURCE-ACQUISITION-EXPECTED-INTENT-CALLER-SUPPLIED"
      "source-acquisition-expected-intent"
      "repository, revision, HEAD, source-snapshot, authored-root, and exact expected-manifest intent are caller-supplied diagnostic inputs rather than independently acquired authority"
  , Finding
      "SOURCE-ACQUISITION-SESSION-CUSTODY-CALLER-SUPPLIED"
      "source-acquisition-session-custody"
      "verification key, challenge, replay state, signed session envelope, bundle bytes, and custody claim are caller-supplied rather than acquired and held by an external session authority"
  , Finding
      "SOURCE-ACQUISITION-OBSERVER-EXECUTION-ABSENT"
      "source-acquisition-observer"
      "no independently authenticated observer process is executed and no observed exit, stdout, stderr, or tool identity is bound"
  , Finding
      "SOURCE-ACQUISITION-KEY-ROLE-SEPARATION-ABSENT"
      "source-acquisition-keys"
      "bundle signing, observer identity, trust-anchor custody, challenge issuance, and replay consumption are not separate externally controlled roles"
  , Finding
      "SOURCE-ACQUISITION-STREAMING-INGRESS-ABSENT"
      "source-acquisition-ingress"
      "closed byte limits are checked only after strict envelope, expected-manifest, verification-key, and bundle ByteStrings plus caller-constructed expectation and replay values have already been materialized; bounded streaming ingress is absent"
  , Finding
      "SOURCE-ACQUISITION-DISPATCHER-COMPOSITION-ABSENT"
      "source-acquisition-dispatch"
      "the diagnostic is not composed into an authenticated source-bound dispatcher path and therefore cannot establish candidate acquisition"
  , Finding
      "SOURCE-ACQUISITION-TRUST-ANCHOR-UNINTEGRATED"
      "source-acquisition-trust-root"
      "the verification key and expected authority are caller-supplied; no external pre-established trust anchor is integrated"
  , Finding
      "SOURCE-ACQUISITION-REPLAY-STATE-UNINTEGRATED"
      "source-acquisition-replay-state"
      "the challenge and consumed replay identities are caller-supplied; no external durable atomic freshness consumer is integrated"
  , Finding
      "SOURCE-ACQUISITION-AUTHORED-ROOT-UNOBSERVED"
      "source-acquisition-authored-root"
      "the signed authored-root identity is joined to a caller-supplied external expectation, but no independently authenticated observer establishes ignored, untracked, generated, or special material"
  , Finding
      "SOURCE-ACQUISITION-CUSTODY-UNOBSERVED"
      "source-acquisition-custody"
      "externally frozen read-only custody is a signed tag rather than an independently observed property"
  , Finding
      "SOURCE-ACQUISITION-ORACLE-QUALIFICATION-ABSENT"
      "SourceAcquisitionOracle"
      "pinned Ed25519 and envelope vectors do not supply changed-production-subject mutation qualification, external observer execution, or independent human review"
  ]

problemFinding :: Text -> FilePath -> Text -> Finding
problemFinding code subject detail =
  Finding code subject (oracleBoundedProblemDetail detail)

oracleBoundedProblemDetail :: Text -> Text
oracleBoundedProblemDetail detail
  | Text.length observedPrefix > 1024 = Text.take 1024 observedPrefix <> "[truncated]"
  | otherwise = observedPrefix
 where
  observedPrefix = Text.take 1025 detail

envelopeProblem :: Text -> Text -> Finding
envelopeProblem code = problemFinding code "source-acquisition-envelope"

pathProblem :: Text -> FilePath -> Text -> Finding
pathProblem = problemFinding

shown0 :: Text -> Text
shown0 = id

shown1 :: Show value => Text -> value -> Text
shown1 name value = name <> " " <> Text.pack (show value)

shown2 :: (Show first, Show second) => Text -> first -> second -> Text
shown2 name first second =
  name <> " " <> Text.pack (show first) <> " " <> Text.pack (show second)

shown3
  :: (Show first, Show second, Show third)
  => Text
  -> first
  -> second
  -> third
  -> Text
shown3 name first second third =
  name
    <> " "
    <> Text.pack (show first)
    <> " "
    <> Text.pack (show second)
    <> " "
    <> Text.pack (show third)

oracleFirstOrderViolation :: [FilePath] -> (FilePath, FilePath)
oracleFirstOrderViolation paths = case paths of
  [] -> error "oracle expected an order violation in a nonempty path inventory"
  first : rest -> go first rest
 where
  go _ [] = error "oracle expected a strict-order violation"
  go previous (current : remaining)
    | encoded previous < encoded current = go current remaining
    | otherwise = (previous, current)
  encoded = TextEncoding.encodeUtf8 . Text.pack

productionObjectFormatName :: OracleObjectFormat -> Text
productionObjectFormatName OracleObjectSha1 = "GitObjectSha1"
productionObjectFormatName OracleObjectSha256 = "GitObjectSha256"

shownObjectFormatProblem :: Text -> OracleObjectFormat -> Text -> Text
shownObjectFormatProblem name objectFormat identity =
  name
    <> " "
    <> productionObjectFormatName objectFormat
    <> " "
    <> Text.pack (show identity)

shownPathObjectFormatProblem
  :: Text
  -> FilePath
  -> OracleObjectFormat
  -> Text
  -> Text
shownPathObjectFormatProblem name path objectFormat identity =
  name
    <> " "
    <> Text.pack (show path)
    <> " "
    <> productionObjectFormatName objectFormat
    <> " "
    <> Text.pack (show identity)

rfc8032Seed :: ByteString
rfc8032Seed =
  oracleDecodeHex "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60"

rfc8032PublicKey :: ByteString
rfc8032PublicKey =
  oracleDecodeHex "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"

rfc8032EmptySignature :: ByteString
rfc8032EmptySignature =
  oracleDecodeHex
    ( "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e06522490155"
        <> "5fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b"
    )

rfc8032Secret :: Ed25519.SecretKey
rfc8032Secret = case Ed25519.secretKey rfc8032Seed of
  CryptoFailed failure -> error ("invalid pinned RFC 8032 seed: " <> show failure)
  CryptoPassed secret -> secret

rfc8032Public :: Ed25519.PublicKey
rfc8032Public = Ed25519.toPublic rfc8032Secret

directorySortFixture :: OracleFixture
directorySortFixture =
  deriveFixture
    (fixtureManifest (canonicalFixture OracleObjectSha1))
    [ member OracleObjectSha1 "foo.bar" OracleRegularFile "flat\n"
    , member OracleObjectSha1 "foo/child" OracleRegularFile "nested\n"
    ]

pinnedDirectoryTreeIdentity :: Text
pinnedDirectoryTreeIdentity = "27b96ed5dbb9137e8d97cdf2d5201c916f0d9a46"

-- Frozen v2 canonical envelope prefix. The independent oracle encoder must
-- reproduce these exact bytes before the pinned signature is exercised.
pinnedEnvelopePrefix :: ByteString
pinnedEnvelopePrefix =
  oracleDecodeHex
    ( "616d6f65626975732d736f757263652d6163717569736974696f6e2d656e76656c6f70652d76320a313138310a616d6f6562"
        <> "6975732d736f757263652d6163717569736974696f6e2d7632000000000230300000001870686173652d30302d736f757263"
        <> "652d6f6273657276657200000040303937336338383630303530613039303034633831303537343031636161333933363039"
        <> "3733313239663665636339643831656539363534306364633236346500000040306235633938633633653431376634396136"
        <> "6332326138356339666565306236303739643461383330643961313935333438353261633436616635303230303000000040"
        <> "3832643032363235393133666330643531643037663064633733643133383764663634356538313736393461306135316232"
        <> "6631396533633163383861636237000000403437393532313962343763613563313865313862303837336434306330323430"
        <> "66613931616665383162316534363661616433303837646235346237343332660000000f726566732f68656164732f6d6169"
        <> "6e01010000002830393432336533356266643464646437656362653966613461346365623262386137313830333633000000"
        <> "2832376239366564356462623931333765386439376364663264353230316339313666306439613436000000406135646566"
        <> "6634663830653837666534333937353766616538353435313361633665306630376538363639336533303165643730653737"
        <> "3737323830343135610000004061353964663764626334623239383262646134343037396366333536326131666235633565"
        <> "3930666538393135333638333165396262666135636537643434660000004064333832653935393731663166633838656266"
        <> "6131353138346365356363626338316338346339336236366461336166326230313236373737393734343135650000004030"
        <> "6666613132666533613031316333373430633463306138333039383430323162363866363637656335653562653064306332"
        <> "65306430373932613938653437000000bd747265652032376239366564356462623931333765386439376364663264353230"
        <> "3163393136663064396134360a617574686f7220416d6f6562697573204f7261636c65203c6f7261636c65406578616d706c"
        <> "652e696e76616c69643e2030202b303030300a636f6d6d697474657220416d6f6562697573204f7261636c65203c6f726163"
        <> "6c65406578616d706c652e696e76616c69643e2030202b303030300a0a736f75726365206163717569736974696f6e206669"
        <> "78747572650a0000000200000007666f6f2e6261720100000028343262353039656435656435663234373166376161666562"
        <> "6135623362646333326464386236356300000000000000050000004036626336366138323766653836393235616636383062"
        <> "65356530306461326237613766323239343763386330323039623232353633383930323538343632663600000009666f6f2f"
        <> "6368696c64010000002837396335333935356566383536663136663231303734343662633732316338383739613162643265"
        <> "0000000000000007000000403337306138633034623861363562623434393432373565656332323766316236393464623034"
        <> "6337366461366230623861653838656431616231393739306133"
    )

-- Replaced after the canonical-envelope-prefix signing change using the
-- externally published RFC 8032 seed above. The runtime derivation below is a
-- control; this literal is the protocol vector.
pinnedEnvelopeSignature :: ByteString
pinnedEnvelopeSignature =
  oracleDecodeHex
    ( "1499f743c59d4f7a7b6b92588cc6dc73ff775d84a3ec35537b9e204ed64e256b"
        <> "d8cd283d27695a472043e5fd58655f6373655271f653a2d0a9203693bd2a9108"
    )

derivedPinnedEnvelopeSignature :: ByteString
derivedPinnedEnvelopeSignature =
  convert (Ed25519.sign rfc8032Secret rfc8032Public pinnedEnvelopePrefix)

pinnedProtocolProblems :: [ExactCase]
pinnedProtocolProblems =
  expectEqual
    "RFC 8032 seed derives the published public key"
    rfc8032PublicKey
    (convert rfc8032Public)
    <> expectEqual
      "RFC 8032 seed signs the published empty-message vector"
      rfc8032EmptySignature
      (convert (Ed25519.sign rfc8032Secret rfc8032Public ByteString.empty))
    <> expectEqual
      "Git directory-sort fixture has the independently pinned root tree"
      pinnedDirectoryTreeIdentity
      (oracleTreeIdentityField manifest)
    <> expectEqual
      "oracle-local encoder reproduces the pinned canonical envelope prefix"
      pinnedEnvelopePrefix
      prefix
    <> expectEqual
      "canonical envelope prefix has the pinned Ed25519 signature"
      (oracleEncodeHex pinnedEnvelopeSignature)
      (oracleEncodeHex actualSignature)
    <> expectConsistent
      "pinned literal public-key/canonical-envelope/signature vector"
      manifest
      expected
      rfc8032PublicKey
      (prefix <> pinnedEnvelopeSignature)
      (fixtureBundle directorySortFixture)
 where
  manifest = fixtureManifest directorySortFixture
  expected = canonicalExpectation directorySortFixture
  prefix = oracleEnvelopePrefix manifest
  actualSignature = derivedPinnedEnvelopeSignature

directorySortProblems
  :: Ed25519.SecretKey
  -> Ed25519.PublicKey
  -> ByteString
  -> [ExactCase]
directorySortProblems secret public publicBytes =
  expectEqual
    "Git tree ordering treats a directory as name slash"
    pinnedDirectoryTreeIdentity
    (oracleTreeIdentityField manifest)
    <> expectConsistent
      "Git directory-sort hard case remains internally consistent"
      manifest
      expected
      publicBytes
      (signFixture secret public directorySortFixture)
      (fixtureBundle directorySortFixture)
 where
  manifest = fixtureManifest directorySortFixture
  expected = canonicalExpectation directorySortFixture

fieldProblems
  :: Ed25519.SecretKey
  -> Ed25519.PublicKey
  -> ByteString
  -> OracleExpectation
  -> OracleFixture
  -> [ExactCase]
fieldProblems secret public publicBytes expected fixture =
  concat
    [ let maximumAuthority = Text.replicate 128 "a"
          changed = base {oracleAuthority = maximumAuthority}
       in expectConsistent
            "exact 128-byte acquisition authority limit is inclusive"
            changed
            (expected {oracleExpectedAuthority = maximumAuthority})
            publicBytes
            (signManifest secret public changed)
            bundle
    , signedProblem
        "wrong but canonical phase"
        [ envelopeProblem
            "SOURCE-ACQUISITION-PHASE"
            (shown2 "SourceAcquisitionPhaseMismatch" ("00" :: Text) ("01" :: Text))
        ]
        (base {oraclePhase = "01"})
        bundle
    , signedProblem
        "malformed phase"
        [ envelopeProblem
            "SOURCE-ACQUISITION-PHASE"
            (shown1 "SourceAcquisitionPhaseMalformed" ("0" :: Text))
        , envelopeProblem
            "SOURCE-ACQUISITION-PHASE"
            (shown2 "SourceAcquisitionPhaseMismatch" ("00" :: Text) ("0" :: Text))
        ]
        (base {oraclePhase = "0"})
        bundle
    , detailBoundPhaseProblem
        "exact 1024-character problem-detail limit is inclusive"
        1024
    , detailBoundPhaseProblem
        "1025th problem-detail character is bounded before Text materialization"
        1025
    , signedProblem
        "structural refusal suppresses bundle content interpretation"
        [ envelopeProblem
            "SOURCE-ACQUISITION-PHASE"
            (shown1 "SourceAcquisitionPhaseMalformed" ("0" :: Text))
        , envelopeProblem
            "SOURCE-ACQUISITION-PHASE"
            (shown2 "SourceAcquisitionPhaseMismatch" ("00" :: Text) ("0" :: Text))
        ]
        (base {oraclePhase = "0"})
        (bundle <> "uninterpreted")
    , signedProblem
        "wrong acquisition authority"
        [ envelopeProblem
            "SOURCE-ACQUISITION-AUTHORITY"
            ( shown2
                "SourceAcquisitionAuthorityMismatch"
                canonicalAuthority
                ("foreign-source-observer" :: Text)
            )
        ]
        (base {oracleAuthority = "foreign-source-observer"})
        bundle
    , signedProblem
        "malformed acquisition authority"
        [ envelopeProblem
            "SOURCE-ACQUISITION-AUTHORITY"
            (shown1 "SourceAcquisitionAuthorityMalformed" ("observer with spaces" :: Text))
        , envelopeProblem
            "SOURCE-ACQUISITION-AUTHORITY"
            ( shown2
                "SourceAcquisitionAuthorityMismatch"
                canonicalAuthority
                ("observer with spaces" :: Text)
            )
        ]
        (base {oracleAuthority = "observer with spaces"})
        bundle
    , signedProblem
        "wrong observer/tool digest"
        [ envelopeProblem
            "SOURCE-ACQUISITION-OBSERVER-TOOL"
            ( shown2
                "SourceAcquisitionObserverToolMismatch"
                canonicalObserverDigest
                differentSha
            )
        ]
        (base {oracleObserverToolDigest = differentSha})
        bundle
    , signedProblem
        "malformed observer/tool digest"
        [ envelopeProblem
            "SOURCE-ACQUISITION-OBSERVER-TOOL"
            (shown1 "SourceAcquisitionObserverToolDigestMalformed" ("not-a-digest" :: Text))
        , envelopeProblem
            "SOURCE-ACQUISITION-OBSERVER-TOOL"
            ( shown2
                "SourceAcquisitionObserverToolMismatch"
                canonicalObserverDigest
                ("not-a-digest" :: Text)
            )
        ]
        (base {oracleObserverToolDigest = "not-a-digest"})
        bundle
    , signedProblem
        "wrong fresh challenge"
        [ envelopeProblem
            "SOURCE-ACQUISITION-CHALLENGE"
            (shown2 "SourceAcquisitionChallengeMismatch" canonicalChallenge differentSha)
        ]
        (base {oracleChallenge = differentSha})
        bundle
    , signedProblem
        "malformed fresh challenge"
        [ envelopeProblem
            "SOURCE-ACQUISITION-CHALLENGE"
            (shown1 "SourceAcquisitionChallengeMalformed" ("short" :: Text))
        , envelopeProblem
            "SOURCE-ACQUISITION-CHALLENGE"
            (shown2 "SourceAcquisitionChallengeMismatch" canonicalChallenge ("short" :: Text))
        ]
        (base {oracleChallenge = "short"})
        bundle
    , expectRefused
        "consumed replay identity"
        [ envelopeProblem
            "SOURCE-ACQUISITION-REPLAY"
            (shown1 "SourceAcquisitionReplayDetected" (oracleReplayIdentity base))
        ]
        expected
          { oracleConsumedReplayIdentities =
              Set.singleton (oracleReplayIdentity base)
          }
        publicBytes
        (signManifest secret public base)
        bundle
    , signedProblem
        "malformed replay identity"
        [ envelopeProblem
            "SOURCE-ACQUISITION-REPLAY"
            (shown1 "SourceAcquisitionReplayIdentityMalformed" ("short" :: Text))
        ]
        (base {oracleReplayIdentity = "short"})
        bundle
    , signedProblem
        "malformed HEAD identity"
        [ envelopeProblem
            "SOURCE-ACQUISITION-HEAD"
            ( shownObjectFormatProblem
                "SourceAcquisitionHeadIdentityMalformed"
                OracleObjectSha1
                "bad-head"
            )
        ]
        (base {oracleHeadIdentity = "bad-head"})
        bundle
    , signedProblem
        "malformed tree identity"
        [ envelopeProblem
            "SOURCE-ACQUISITION-TREE"
            ( shownObjectFormatProblem
                "SourceAcquisitionTreeIdentityMalformed"
                OracleObjectSha1
                "bad-tree"
            )
        ]
        (base {oracleTreeIdentityField = "bad-tree"})
        bundle
    , signedProblem
        "malformed authored-root identity"
        [ envelopeProblem
            "SOURCE-ACQUISITION-AUTHORED-ROOT"
            (shown1 "SourceAcquisitionAuthoredRootIdentityMalformed" ("bad-authored" :: Text))
        ]
        (base {oracleAuthoredRootIdentityField = "bad-authored"})
        bundle
    , signedProblem
        "malformed frozen-snapshot identity"
        [ envelopeProblem
            "SOURCE-ACQUISITION-FROZEN-SNAPSHOT"
            (shown1 "SourceAcquisitionFrozenSnapshotIdentityMalformed" ("bad-frozen" :: Text))
        ]
        (base {oracleFrozenSnapshotIdentityField = "bad-frozen"})
        bundle
    , signedProblem
        "malformed bundle identity"
        [ envelopeProblem
            "SOURCE-ACQUISITION-BUNDLE"
            (shown1 "SourceAcquisitionBundleIdentityMalformed" ("bad-bundle" :: Text))
        ]
        (base {oracleBundleIdentityField = "bad-bundle"})
        bundle
    , signedProblem
        "malformed source-snapshot identity"
        [ envelopeProblem
            "SOURCE-ACQUISITION-SOURCE-SNAPSHOT"
            (shown1 "SourceAcquisitionSourceSnapshotIdentityMalformed" ("bad-source" :: Text))
        ]
        (base {oracleSourceSnapshotIdentityField = "bad-source"})
        bundle
    , let changed = withRecomputedFrozen (base {oracleTreeIdentityField = differentGitIdentity base})
       in signedProblem
            "valid-width but wrong tree identity"
            [ envelopeProblem
                "SOURCE-ACQUISITION-TREE"
                ( shown2
                    "SourceAcquisitionTreeIdentityMismatch"
                    (differentGitIdentity base)
                    (oracleTreeIdentityField base)
                )
            , envelopeProblem
                "SOURCE-ACQUISITION-COMMIT-TREE"
                ( shown2
                    "SourceAcquisitionCommitTreeMismatch"
                    (differentGitIdentity base)
                    (oracleTreeIdentityField base)
                )
            ]
            changed
            bundle
    , let changed = withRecomputedFrozen (base {oracleBundleIdentityField = differentSha})
       in signedProblem
            "wrong immutable-bundle digest"
            [ envelopeProblem
                "SOURCE-ACQUISITION-BUNDLE"
                ( shown2
                    "SourceAcquisitionBundleIdentityMismatch"
                    differentSha
                    (oracleBundleIdentityField base)
                )
            ]
            changed
            bundle
    , let changed = withRecomputedFrozen (base {oracleSourceSnapshotIdentityField = differentSha})
       in signedProblem
            "wrong source-snapshot identity"
            [ envelopeProblem
                "SOURCE-ACQUISITION-SOURCE-SNAPSHOT"
                ( shown2
                    "SourceAcquisitionSourceSnapshotIdentityMismatch"
                    differentSha
                    (oracleSourceSnapshotIdentityField base)
                )
            ]
            changed
            bundle
    , signedProblem
        "wrong frozen-snapshot identity"
        [ envelopeProblem
            "SOURCE-ACQUISITION-FROZEN-SNAPSHOT"
            ( shown2
                "SourceAcquisitionFrozenSnapshotIdentityMismatch"
                differentSha
                (oracleFrozenSnapshotIdentityField base)
            )
        ]
        (base {oracleFrozenSnapshotIdentityField = differentSha})
        bundle
    ]
 where
  base = fixtureManifest fixture
  bundle = fixtureBundle fixture
  differentSha = Text.replicate 64 "f"
  detailBoundPhaseProblem label detailLength =
    let constructorName = "SourceAcquisitionPhaseMalformed"
        valueLength = detailLength - Text.length constructorName - 3
        value = Text.replicate valueLength "x"
        manifest = base {oraclePhase = value}
     in signedProblem
          label
          [ envelopeProblem
              "SOURCE-ACQUISITION-PHASE"
              (shown1 constructorName value)
          , envelopeProblem
              "SOURCE-ACQUISITION-PHASE"
              (shown2 "SourceAcquisitionPhaseMismatch" ("00" :: Text) value)
          ]
          manifest
          bundle
  signedProblem label expectedProblems manifest testedBundle =
    expectRefused
      label
      expectedProblems
      (alignFullExpectation manifest expected)
      publicBytes
      (signManifest secret public manifest)
      testedBundle

-- Every clause below is paired with a single production predicate selector.
-- The oracle spells the complete CheckResult, including permanent diagnostic
-- residue, through expectConsistent/expectRefused rather than counting findings.
closedFieldPredicateProblems
  :: Ed25519.SecretKey
  -> Ed25519.PublicKey
  -> ByteString
  -> OracleExpectation
  -> OracleFixture
  -> OracleExpectation
  -> OracleFixture
  -> [ExactCase]
closedFieldPredicateProblems secret public publicBytes sha1Expected sha1Fixture sha256Expected sha256Fixture =
  concat
    [ phaseControl "phase lower endpoint 00 is admitted" "00"
    , phaseControl "phase upper endpoint 99 is admitted" "99"
    , phaseRefusal "phase width one is rejected" "0"
    , phaseRefusal "phase width three is rejected" "000"
    , phaseRefusal "correct-width ASCII nondigit phase is rejected" "0x"
    , phaseRefusal "Unicode digits do not substitute for ASCII phase digits" "\x0660\x0660"
    , authorityControl "authority admits its complete closed character alphabet" "aAzZ09._:-"
    , authorityRefusal "empty signed authority is rejected" ""
    , authorityRefusal "signed authority at 129 characters is rejected" (Text.replicate 129 "a")
    ]
      <> concatMap
        (\value -> authorityRefusal ("authority rejects disallowed character " <> show value) value)
        authorityDisallowedValues
      <> concatMap (uncurry revisionControl) revisionPositiveCases
      <> concatMap (uncurry revisionRefusal) revisionNegativeCases
      <> gitObjectTextCases sha1Expected sha1Fixture
      <> gitObjectTextCases sha256Expected sha256Fixture
      <> sha256TextCases
 where
  base = fixtureManifest sha1Fixture
  bundle = fixtureBundle sha1Fixture

  phaseControl label value =
    let changed = withRecomputedFrozen (base {oraclePhase = value})
     in expectConsistent
          label
          changed
          (sha1Expected {oracleExpectedPhase = value})
          publicBytes
          (signManifest secret public changed)
          bundle
  phaseRefusal label value =
    fieldRefusal
      label
      [ envelopeProblem "SOURCE-ACQUISITION-PHASE" (shown1 "SourceAcquisitionPhaseMalformed" value)
      , envelopeProblem "SOURCE-ACQUISITION-PHASE" (shown2 "SourceAcquisitionPhaseMismatch" ("00" :: Text) value)
      ]
      (base {oraclePhase = value})

  authorityControl label value =
    let changed = withRecomputedFrozen (base {oracleAuthority = value})
     in expectConsistent
          label
          changed
          (sha1Expected {oracleExpectedAuthority = value})
          publicBytes
          (signManifest secret public changed)
          bundle
  authorityRefusal label value =
    fieldRefusal
      label
      [ envelopeProblem "SOURCE-ACQUISITION-AUTHORITY" (shown1 "SourceAcquisitionAuthorityMalformed" value)
      , envelopeProblem
          "SOURCE-ACQUISITION-AUTHORITY"
          (shown2 "SourceAcquisitionAuthorityMismatch" canonicalAuthority value)
      ]
      (base {oracleAuthority = value})

  revisionControl label value =
    let changed = withRecomputedFrozen (base {oracleRequestedRevision = value})
     in expectConsistent
          label
          changed
          (sha1Expected {oracleExpectedRequestedRevision = value})
          publicBytes
          (signManifest secret public changed)
          bundle
  revisionRefusal label value =
    fieldRefusal
      label
      [ envelopeProblem "SOURCE-ACQUISITION-REVISION" (shown1 "SourceAcquisitionRequestedRevisionMalformed" value)
      , envelopeProblem
          "SOURCE-ACQUISITION-REVISION"
          (shown2 "SourceAcquisitionRequestedRevisionMismatch" canonicalRequestedRevision value)
      ]
      (withRecomputedFrozen (base {oracleRequestedRevision = value}))

  revisionPositiveCases =
    [ ("revision admits every documented identifier character", "A0/a.b_c@d+e-f{g")
    , ("single slash is an admitted near-miss for double slash", "a/b")
    , ("single dot is an admitted near-miss for double dot", "a.b")
    , ("bare at-sign is an admitted near-miss for reflog syntax", "a@b")
    , ("lock-like non-suffix is admitted", "a.locks")
    ]
  authorityDisallowedValues =
    [Text.singleton (toEnum code) | code <- [0 .. 44] <> [47] <> [59 .. 64] <> [91 .. 94] <> [96] <> [123 .. 127]]
      <> ["\x00e9", "\x03bb", "\x0660"]
  revisionNegativeCases =
    [ ("empty requested revision is rejected", "")
    , ("signed requested revision at 257 characters is rejected", Text.replicate 257 "r")
    , ("requested revision rejects a disallowed colon", "a:b")
    , ("requested revision rejects leading slash", "/a")
    , ("requested revision rejects leading dash", "-a")
    , ("requested revision rejects leading dot", ".a")
    , ("requested revision rejects trailing slash", "a/")
    , ("requested revision rejects trailing dot", "a.")
    , ("requested revision rejects trailing dot-lock", "a.lock")
    , ("requested revision rejects double slash", "a//b")
    , ("requested revision rejects double dot", "a..b")
    , ("requested revision rejects reflog syntax", "a@{b")
    ]

  fieldRefusal label problems changed =
    expectRefused
      label
      problems
      (alignFullExpectation changed sha1Expected)
      publicBytes
      (signManifest secret public changed)
      bundle

  gitObjectTextCases testedExpected testedFixture =
    concatMap
      (\(label, value) ->
        let testedBase = fixtureManifest testedFixture
            changed = testedBase {oracleHeadIdentity = value}
            expectationCannotMirror = ByteString.length (TextEncoding.encodeUtf8 value) > 64
            testedProblems =
              [ envelopeProblem
                  "SOURCE-ACQUISITION-HEAD"
                  (shownObjectFormatProblem "SourceAcquisitionHeadIdentityMalformed" (oracleObjectFormat testedBase) value)
              ]
                <> [ envelopeProblem
                       "SOURCE-ACQUISITION-EXPECTED-HEAD"
                       (shown2 "SourceAcquisitionExpectedHeadIdentityMismatch" (oracleExpectedHeadIdentity testedExpected) value)
                   | expectationCannotMirror
                   ]
            alignedExpected
              | expectationCannotMirror = testedExpected
              | otherwise = alignFullExpectation changed testedExpected
         in expectRefused
              (label <> " (" <> show (oracleObjectFormat testedBase) <> ")")
              testedProblems
              alignedExpected
              publicBytes
              (signManifest secret public changed)
              (fixtureBundle testedFixture)
      )
      (hashTextNegatives (objectIdentityWidth (oracleObjectFormat (fixtureManifest testedFixture))))

  sha256TextCases =
    concatMap
      (\(label, value) ->
        let changed = base {oracleAuthoredRootIdentityField = value}
            expectationCannotMirror = ByteString.length (TextEncoding.encodeUtf8 value) > 64
            testedProblems =
              [ envelopeProblem
                  "SOURCE-ACQUISITION-AUTHORED-ROOT"
                  (shown1 "SourceAcquisitionAuthoredRootIdentityMalformed" value)
              ]
                <> [ envelopeProblem
                       "SOURCE-ACQUISITION-AUTHORED-ROOT"
                       (shown2 "SourceAcquisitionAuthoredRootIdentityMismatch" (oracleExpectedAuthoredRootIdentity sha1Expected) value)
                   | expectationCannotMirror
                   ]
            alignedExpected
              | expectationCannotMirror = sha1Expected
              | otherwise = alignFullExpectation changed sha1Expected
         in expectRefused
              label
              testedProblems
              alignedExpected
              publicBytes
              (signManifest secret public changed)
              bundle
      )
      (hashTextNegatives 64)

  hashTextNegatives width =
    [ ("lowercase-hex identity one character under width is rejected", Text.replicate (width - 1) "a")
    , ("lowercase-hex identity one character over width is rejected", Text.replicate (width + 1) "a")
    , ("correct-width uppercase hexadecimal identity is rejected", "A" <> Text.replicate (width - 1) "a")
    , ("correct-width g-bearing identity is rejected", "g" <> Text.replicate (width - 1) "a")
    , ("correct-width Unicode identity is rejected", "\x00e9" <> Text.replicate (width - 1) "a")
    ]

expectationIngressProblems
  :: ByteString
  -> OracleExpectation
  -> OracleFixture
  -> ByteString
  -> [ExactCase]
expectationIngressProblems publicBytes expected fixture cleanWire =
  concat
    [ expectationLimit
        "expected phase is bounded before authentication or comparison"
        "phase"
        3
        2
        expected {oracleExpectedPhase = Text.replicate 3 "0"}
    , expectationLimit
        "expected phase bound measures UTF-8 bytes rather than characters"
        "phase"
        4
        2
        expected {oracleExpectedPhase = Text.replicate 2 "\x00e9"}
    , expectationLimit
        "expected authority is bounded before authentication or comparison"
        "authority"
        129
        128
        expected {oracleExpectedAuthority = Text.replicate 129 "a"}
    , expectationLimit
        "expected observer digest is bounded before authentication or comparison"
        "observer-tool-digest"
        65
        64
        expected {oracleExpectedObserverToolDigest = Text.replicate 65 "a"}
    , expectationLimit
        "expected challenge is bounded before authentication or comparison"
        "challenge"
        65
        64
        expected {oracleExpectedChallenge = Text.replicate 65 "a"}
    , expectationLimit
        "expected repository identity is bounded before authentication or comparison"
        "repository-identity"
        65
        64
        expected {oracleExpectedRepositoryIdentity = Text.replicate 65 "a"}
    , expectationLimit
        "expected revision is bounded before authentication or comparison"
        "requested-revision"
        257
        256
        expected {oracleExpectedRequestedRevision = Text.replicate 257 "a"}
    , expectationLimit
        "expected HEAD is bounded before authentication or comparison"
        "head-identity"
        65
        64
        expected {oracleExpectedHeadIdentity = Text.replicate 65 "a"}
    , expectationLimit
        "expected source snapshot is bounded before authentication or comparison"
        "source-snapshot-identity"
        65
        64
        expected {oracleExpectedSourceSnapshotIdentity = Text.replicate 65 "a"}
    , expectationLimit
        "expected authored root is bounded before authentication or comparison"
        "authored-root-identity"
        65
        64
        expected {oracleExpectedAuthoredRootIdentity = Text.replicate 65 "a"}
    , expectRefused
        "exact 16384-entry consumed replay-set limit reaches authentication"
        [ envelopeProblem
            "SOURCE-ACQUISITION-SIGNATURE"
            (shown0 "SourceAcquisitionSignatureInvalid")
        ]
        expected
          { oracleConsumedReplayIdentities =
              Set.fromList
                [ Text.pack (replicate (64 - length rendered) '0' <> rendered)
                | value <- [0 :: Int .. 16383]
                , let rendered = show value
                ]
          }
        publicBytes
        corruptedWire
        bundle
    , expectRefused
        "consumed replay set count is bounded before authentication or comparison"
        [ Finding
            "SOURCE-ACQUISITION-REPLAY-SET-LIMIT"
            "source-acquisition-expectation/replay-set"
            ( shown2
                "SourceAcquisitionReplaySetTooLarge"
                (16385 :: Int)
                (16384 :: Int)
            )
        ]
        expected
          { oracleConsumedReplayIdentities =
              Set.fromList
                [ Text.pack (replicate (64 - length rendered) '0' <> rendered)
                | value <- [0 :: Int .. 16384]
                , let rendered = show value
                ]
          }
        publicBytes
        corruptedWire
        bundle
    , expectRefused
        "each consumed replay identity is bounded before authentication or comparison"
        [ Finding
            "SOURCE-ACQUISITION-REPLAY-SET-ENTRY-LIMIT"
            "source-acquisition-expectation/replay-set/0"
            ( shown3
                "SourceAcquisitionReplaySetEntryTooLarge"
                (0 :: Int)
                (65 :: Int)
                (64 :: Int)
            )
        ]
        expected
          { oracleConsumedReplayIdentities = Set.singleton (Text.replicate 65 "a")
          }
        publicBytes
        corruptedWire
        bundle
    , expectRefused
        "exact 128-problem diagnostic limit retains every integrity problem"
        [ Finding
            "SOURCE-ACQUISITION-REPLAY-SET-ENTRY-LIMIT"
            ("source-acquisition-expectation/replay-set/" <> show index)
            ( shown3
                "SourceAcquisitionReplaySetEntryTooLarge"
                index
                (65 :: Int)
                (64 :: Int)
            )
        | index <- [0 :: Int .. 127]
        ]
        expected
          { oracleConsumedReplayIdentities = overlongReplayIdentities 128
          }
        publicBytes
        corruptedWire
        bundle
    , expectRefused
        "129th integrity problem produces the bounded problem-limit refusal"
        [ Finding
            "SOURCE-ACQUISITION-PROBLEM-LIMIT"
            "source-acquisition-result/problems"
            ( shown2
                "SourceAcquisitionProblemLimitExceeded"
                (128 :: Int)
                (129 :: Int)
            )
        ]
        expected
          { oracleConsumedReplayIdentities = overlongReplayIdentities 129
          }
        publicBytes
        corruptedWire
        bundle
    , expectRefused
        "130 problems cannot traverse past the integrity guard"
        [ Finding
            "SOURCE-ACQUISITION-PROBLEM-LIMIT"
            "source-acquisition-result/problems"
            ( shown2
                "SourceAcquisitionProblemLimitExceeded"
                (128 :: Int)
                (129 :: Int)
            )
        ]
        expected
          { oracleConsumedReplayIdentities = overlongReplayIdentities 130
          }
        publicBytes
        corruptedWire
        bundle
    ]
 where
  bundle = fixtureBundle fixture
  corruptedWire = corruptSignature cleanWire
  overlongReplayIdentities count =
    Set.fromList
      [ Text.replicate (65 - length rendered) "a" <> Text.pack rendered
      | value <- [0 :: Int .. count - 1]
      , let rendered = show value
      ]
  expectationLimit
    :: String
    -> Text
    -> Int
    -> Int
    -> OracleExpectation
    -> [ExactCase]
  expectationLimit label fieldName actual maximumBytes testedExpected =
    expectRefused
      label
      [ Finding
          "SOURCE-ACQUISITION-EXPECTATION-LIMIT"
          ("source-acquisition-expectation/" <> Text.unpack fieldName)
          ( shown3
              "SourceAcquisitionExpectationValueTooLarge"
              fieldName
              actual
              maximumBytes
          )
      ]
      testedExpected
      publicBytes
      corruptedWire
      bundle

protocolIntentProblems
  :: Ed25519.SecretKey
  -> Ed25519.PublicKey
  -> ByteString
  -> OracleExpectation
  -> OracleFixture
  -> [ExactCase]
protocolIntentProblems secret public publicBytes expected fixture =
  concat
    [ let protocolRevision = "snapshot@v1"
          changed = withRecomputedFrozen (base {oracleRequestedRevision = protocolRevision})
       in expectConsistent
            "requested revision is an opaque protocol identifier joined byte-for-byte"
            changed
            (expected {oracleExpectedRequestedRevision = protocolRevision})
            publicBytes
            (signManifest secret public changed)
            bundle
    , let maximumRevision = Text.replicate 256 "r"
          changed = withRecomputedFrozen (base {oracleRequestedRevision = maximumRevision})
       in expectConsistent
            "exact 256-byte requested-revision limit is inclusive"
            changed
            (expected {oracleExpectedRequestedRevision = maximumRevision})
            publicBytes
            (signManifest secret public changed)
            bundle
    , signedProblem
        "signed repository identity must be canonical SHA-256"
        expected {oracleExpectedRepositoryIdentity = "short"}
        [ envelopeProblem
            "SOURCE-ACQUISITION-REPOSITORY"
            (shown1 "SourceAcquisitionRepositoryIdentityMalformed" ("short" :: Text))
        ]
        (withRecomputedFrozen (base {oracleRepositoryIdentity = "short"}))
    , signedProblem
        "signed repository identity differs from external intent"
        expected
        [ envelopeProblem
            "SOURCE-ACQUISITION-REPOSITORY"
            ( shown2
                "SourceAcquisitionRepositoryIdentityMismatch"
                canonicalRepositoryIdentity
                differentSha
            )
        ]
        (withRecomputedFrozen (base {oracleRepositoryIdentity = differentSha}))
    , signedProblem
        "signed requested revision differs from external intent"
        expected
        [ envelopeProblem
            "SOURCE-ACQUISITION-REVISION"
            ( shown2
                "SourceAcquisitionRequestedRevisionMismatch"
                canonicalRequestedRevision
                ("refs/heads/other" :: Text)
            )
        ]
        (withRecomputedFrozen (base {oracleRequestedRevision = "refs/heads/other"}))
    , signedProblem
        "malformed signed requested revision"
        expected
        [ envelopeProblem
            "SOURCE-ACQUISITION-REVISION"
            (shown1 "SourceAcquisitionRequestedRevisionMalformed" ("refs//heads/main" :: Text))
        , envelopeProblem
            "SOURCE-ACQUISITION-REVISION"
            ( shown2
                "SourceAcquisitionRequestedRevisionMismatch"
                canonicalRequestedRevision
                ("refs//heads/main" :: Text)
            )
        ]
        (withRecomputedFrozen (base {oracleRequestedRevision = "refs//heads/main"}))
    , expectRefused
        "external expected HEAD differs from signed HEAD"
        [ envelopeProblem
            "SOURCE-ACQUISITION-EXPECTED-HEAD"
            ( shown2
                "SourceAcquisitionExpectedHeadIdentityMismatch"
                differentHead
                (oracleHeadIdentity base)
            )
        ]
        expected {oracleExpectedHeadIdentity = differentHead}
        publicBytes
        (signManifest secret public base)
        bundle
    , expectRefused
        "external expected source snapshot differs from signed snapshot"
        [ envelopeProblem
            "SOURCE-ACQUISITION-EXPECTED-SOURCE-SNAPSHOT"
            ( shown2
                "SourceAcquisitionExpectedSourceSnapshotIdentityMismatch"
                differentSha
                (oracleSourceSnapshotIdentityField base)
            )
        ]
        expected {oracleExpectedSourceSnapshotIdentity = differentSha}
        publicBytes
        (signManifest secret public base)
        bundle
    , expectRefused
        "external authored-root identity differs from signed observation"
        [ envelopeProblem
            "SOURCE-ACQUISITION-AUTHORED-ROOT"
            ( shown2
                "SourceAcquisitionAuthoredRootIdentityMismatch"
                differentSha
                (oracleAuthoredRootIdentityField base)
            )
        ]
        expected {oracleExpectedAuthoredRootIdentity = differentSha}
        publicBytes
        (signManifest secret public base)
        bundle
    , let changedCommit = oracleCommitBytes base <> "changed-message\n"
          actualHead = oracleGitObjectIdentity (oracleObjectFormat base) "commit" changedCommit
       in signedProblem
            "signed commit bytes must recompute to HEAD"
            expected
            [ envelopeProblem
                "SOURCE-ACQUISITION-COMMIT-IDENTITY"
                ( shown2
                    "SourceAcquisitionCommitIdentityMismatch"
                    (oracleHeadIdentity base)
                    actualHead
                )
            ]
            (base {oracleCommitBytes = changedCommit})
    , let differentTree = Text.replicate (objectIdentityWidth (oracleObjectFormat base)) "f"
          changedCommit = oracleCanonicalCommit differentTree
          changedHead = oracleGitObjectIdentity (oracleObjectFormat base) "commit" changedCommit
          changed = withRecomputedFrozen (base {oracleCommitBytes = changedCommit, oracleHeadIdentity = changedHead})
          changedExpected = expected {oracleExpectedHeadIdentity = changedHead}
       in signedProblem
            "canonical commit tree must join the signed tree identity"
            changedExpected
            [ envelopeProblem
                "SOURCE-ACQUISITION-COMMIT-TREE"
                ( shown2
                    "SourceAcquisitionCommitTreeMismatch"
                    (oracleTreeIdentityField base)
                    differentTree
                )
            ]
            changed
    , commitProblem
        "commit requires the canonical header/message separator"
        [ envelopeProblem
            "SOURCE-ACQUISITION-COMMIT"
            ( shown1
                "SourceAcquisitionCommitMalformed"
                ("commit lacks the canonical header/message separator" :: Text)
            )
        ]
        (oracleCommitWithoutSeparator [treeHeader, authorHeader, committerHeader])
    , commitProblem
        "commit requires a committer after its author"
        [ envelopeProblem
            "SOURCE-ACQUISITION-COMMIT"
            (shown1 "SourceAcquisitionCommitMalformed" ("commit has no committer header" :: Text))
        ]
        (oracleCommitWithHeaders [treeHeader, authorHeader])
    , commitProblem
        "every parent identity uses the selected Git object format"
        [ envelopeProblem
            "SOURCE-ACQUISITION-COMMIT"
            (shown1 "SourceAcquisitionCommitMalformed" ("commit has a malformed parent identity" :: Text))
        ]
        (oracleCommitWithHeaders [treeHeader, "parent bad-parent", authorHeader, committerHeader])
    , commitProblem
        "parent headers cannot appear after the committer"
        [ envelopeProblem
            "SOURCE-ACQUISITION-COMMIT"
            (shown1 "SourceAcquisitionCommitMalformed" ("parent header appears after committer" :: Text))
        ]
        (oracleCommitWithHeaders [treeHeader, authorHeader, committerHeader, parentHeader])
    , commitProblem
        "commit without author and committer is not canonical"
        [ envelopeProblem
            "SOURCE-ACQUISITION-COMMIT"
            (shown1 "SourceAcquisitionCommitMalformed" ("commit has no author header" :: Text))
        ]
        (oracleCommitWithHeaders [treeHeader])
    , commitProblem
        "tree header cannot be duplicated"
        [ envelopeProblem
            "SOURCE-ACQUISITION-COMMIT"
            (shown1 "SourceAcquisitionCommitMalformed" ("commit tree header is duplicated" :: Text))
        ]
        (oracleCommitWithHeaders [treeHeader, treeHeader, authorHeader, committerHeader])
    , commitProblem
        "author header cannot be duplicated"
        [ envelopeProblem
            "SOURCE-ACQUISITION-COMMIT"
            (shown1 "SourceAcquisitionCommitMalformed" ("commit author header is duplicated" :: Text))
        ]
        (oracleCommitWithHeaders [treeHeader, authorHeader, authorHeader, committerHeader])
    , commitProblem
        "committer header cannot be duplicated"
        [ envelopeProblem
            "SOURCE-ACQUISITION-COMMIT"
            (shown1 "SourceAcquisitionCommitMalformed" ("commit committer header is duplicated" :: Text))
        ]
        (oracleCommitWithHeaders [treeHeader, authorHeader, committerHeader, committerHeader])
    , commitProblem
        "committer cannot appear before author"
        [ envelopeProblem
            "SOURCE-ACQUISITION-COMMIT"
            (shown1 "SourceAcquisitionCommitMalformed" ("committer header appears before author" :: Text))
        ]
        (oracleCommitWithHeaders [treeHeader, committerHeader, authorHeader])
    , commitProblem
        "parent headers must be contiguous before author"
        [ envelopeProblem
            "SOURCE-ACQUISITION-COMMIT"
            (shown1 "SourceAcquisitionCommitMalformed" ("parent headers must be contiguous before author" :: Text))
        ]
        (oracleCommitWithHeaders [treeHeader, authorHeader, parentHeader, committerHeader])
    , commitProblem
        "commit continuation headers are forbidden"
        [ envelopeProblem
            "SOURCE-ACQUISITION-COMMIT"
            (shown1 "SourceAcquisitionCommitMalformed" ("commit continuation headers are forbidden" :: Text))
        ]
        (oracleCommitWithHeaders [treeHeader, " continuation", authorHeader, committerHeader])
    , commitProblem
        "unknown commit headers are forbidden"
        [ envelopeProblem
            "SOURCE-ACQUISITION-COMMIT"
            (shown1 "SourceAcquisitionCommitMalformed" ("unknown commit header is forbidden" :: Text))
        ]
        (oracleCommitWithHeaders [treeHeader, "encoding UTF-8", authorHeader, committerHeader])
    , commitProblem
        "author identity values use the closed canonical grammar"
        [ envelopeProblem
            "SOURCE-ACQUISITION-COMMIT"
            (shown1 "SourceAcquisitionCommitMalformed" ("author identity is outside the canonical closed grammar" :: Text))
        ]
        ( oracleCommitWithHeaders
            [ treeHeader
            , "author Amoebius Oracle <Oracle@example.invalid> 0 +0000"
            , committerHeader
            ]
        )
    , commitProblem
        "committer identity values use the closed canonical grammar"
        [ envelopeProblem
            "SOURCE-ACQUISITION-COMMIT"
            (shown1 "SourceAcquisitionCommitMalformed" ("committer identity is outside the canonical closed grammar" :: Text))
        ]
        ( oracleCommitWithHeaders
            [ treeHeader
            , authorHeader
            , "committer Amoebius Oracle <oracle@example.invalid> 00 +0000"
            ]
        )
    , commitControl
        "exactly 64 parent headers fit the closed 67-header limit"
        ( oracleCommitWithHeaders
            (treeHeader : replicate 64 parentHeader <> [authorHeader, committerHeader])
        )
    , commitProblem
        "65 parent headers exceed the closed 67-header limit"
        [ envelopeProblem
            "SOURCE-ACQUISITION-COMMIT-HEADER-COUNT-LIMIT"
            ( shown2
                "SourceAcquisitionCommitHeaderCountTooLarge"
                (68 :: Int)
                (67 :: Int)
            )
        ]
        ( oracleCommitWithHeaders
            (treeHeader : replicate 65 parentHeader <> [authorHeader, committerHeader])
        )
    , commitControl
        "a 1024-byte identity header fits the closed line limit"
        (oracleCommitWithHeaders [treeHeader, identityHeaderAtLength 1024, committerHeader])
    , commitProblem
        "a 1025-byte identity header exceeds the closed line limit"
        [ envelopeProblem
            "SOURCE-ACQUISITION-COMMIT-HEADER-LINE-LIMIT"
            ( shown3
                "SourceAcquisitionCommitHeaderLineTooLong"
                (2 :: Int)
                (1025 :: Int)
                (1024 :: Int)
            )
        ]
        (oracleCommitWithHeaders [treeHeader, identityHeaderAtLength 1025, committerHeader])
    , commitControl
        "exact one-MiB commit-byte limit is inclusive"
        (oracleCommitAtExactLength 1048576 [treeHeader, authorHeader, committerHeader])
    , let overlongCommit = ByteString.replicate 1048577 120
          changed = base {oracleCommitBytes = overlongCommit}
       in expectRefused
            "commit bytes exceed the closed one-MiB limit"
            [ envelopeProblem
                "SOURCE-ACQUISITION-COMMIT-LIMIT"
                (shown1 "SourceAcquisitionCommitTooLarge" (1048577 :: Word32))
            ]
            expected
            publicBytes
            (signManifest secret public changed)
            bundle
    ]
 where
  base = fixtureManifest fixture
  bundle = fixtureBundle fixture
  differentSha = Text.replicate 64 "f"
  differentHead = Text.replicate (objectIdentityWidth (oracleObjectFormat base)) "f"
  treeHeader = oracleTreeHeader base
  parentHeader = "parent " <> TextEncoding.encodeUtf8 (oracleHeadIdentity base)
  authorHeader = "author " <> oracleCanonicalIdentity
  committerHeader = "committer " <> oracleCanonicalIdentity
  identityHeaderAtLength targetLength =
    let prefix = "author "
        suffix = " <a@b.cd> 0 +0000"
        displayNameLength = targetLength - ByteString.length prefix - ByteString.length suffix
     in prefix <> ByteString.replicate displayNameLength 65 <> suffix
  commitManifest commitBytes =
    let headIdentity = oracleGitObjectIdentity (oracleObjectFormat base) "commit" commitBytes
     in withRecomputedFrozen
          (base {oracleCommitBytes = commitBytes, oracleHeadIdentity = headIdentity})
  commitExpectation manifest =
    expected {oracleExpectedHeadIdentity = oracleHeadIdentity manifest}
  commitProblem label expectedProblems commitBytes =
    let manifest = commitManifest commitBytes
     in signedProblem label (commitExpectation manifest) expectedProblems manifest
  commitControl label commitBytes =
    let manifest = commitManifest commitBytes
     in expectConsistent
          label
          manifest
          (commitExpectation manifest)
          publicBytes
          (signManifest secret public manifest)
          bundle
  signedProblem label testedExpected expectedProblems manifest =
    expectRefused
      label
      expectedProblems
      testedExpected
      publicBytes
      (signManifest secret public manifest)
      bundle

closedCommitPredicateProblems
  :: Ed25519.SecretKey
  -> Ed25519.PublicKey
  -> ByteString
  -> OracleExpectation
  -> OracleFixture
  -> [ExactCase]
closedCommitPredicateProblems secret public publicBytes expected fixture =
  concat
    [ commitProblem "empty commit bytes are rejected" (commitMalformed "commit bytes are empty") ByteString.empty
    , commitProblem
        "NUL is rejected even when confined to an otherwise canonical commit message"
        (commitMalformed "commit bytes contain NUL")
        (ByteString.intercalate "\n" [treeHeader, authorHeader, committerHeader] <> "\n\nmessage\0only\n")
    , commitProblem
        "carriage return is rejected in the commit header block"
        (commitMalformed "commit headers contain carriage return")
        (oracleCommitWithHeaders [treeHeader <> "\r", authorHeader, committerHeader])
    , commitProblem
        "tree must be the first commit header"
        (commitMalformed "tree must be the first commit header")
        (oracleCommitWithHeaders [authorHeader, treeHeader, committerHeader])
    , commitProblem
        "correct-width malformed tree identity is rejected as commit grammar"
        (commitMalformed "commit tree identity is not canonical lowercase hexadecimal")
        (oracleCommitWithHeaders ["tree " <> ByteString.replicate width 65, authorHeader, committerHeader])
    , commitProblem
        "commit with no header/message separator is rejected"
        (commitMalformed "commit lacks the canonical header/message separator")
        (oracleCommitWithoutSeparator [treeHeader, authorHeader, committerHeader])
    , commitProblem
        "commit header with no value separator is rejected"
        (commitMalformed "commit header lacks a value separator")
        (oracleCommitWithHeaders ["tree", authorHeader, committerHeader])
    , commitProblem
        "commit header with an empty value is rejected"
        (commitMalformed "commit header name or value is empty")
        (oracleCommitWithHeaders ["tree ", authorHeader, committerHeader])
    , commitProblem
        "empty commit header block is rejected"
        (commitMalformed "commit header block contains an empty line")
        (oracleCommitWithHeaders [])
    ]
      <> concatMap (uncurry identityControl) identityPositiveCases
      <> concatMap (uncurry identityRefusal) identityNegativeCases
      <> concatMap timezoneControl timezonePositiveCases
      <> concatMap timezoneRefusal timezoneNegativeCases
      <> concatMap commitHashCases hashByteNegatives
 where
  base = fixtureManifest fixture
  bundle = fixtureBundle fixture
  width = objectIdentityWidth (oracleObjectFormat base)
  treeHeader = oracleTreeHeader base
  authorHeader = "author " <> oracleCanonicalIdentity
  committerHeader = "committer " <> oracleCanonicalIdentity

  commitMalformed detail =
    [ envelopeProblem
        "SOURCE-ACQUISITION-COMMIT"
        (shown1 "SourceAcquisitionCommitMalformed" (detail :: Text))
    ]
  identityMalformed = commitMalformed "author identity is outside the canonical closed grammar"

  commitManifest commitBytes =
    let headIdentity = oracleGitObjectIdentity (oracleObjectFormat base) "commit" commitBytes
     in withRecomputedFrozen
          (base {oracleCommitBytes = commitBytes, oracleHeadIdentity = headIdentity})
  commitExpectation manifest = expected {oracleExpectedHeadIdentity = oracleHeadIdentity manifest}
  commitProblem label problems commitBytes =
    let manifest = commitManifest commitBytes
     in expectRefused
          (label <> " (" <> show (oracleObjectFormat base) <> ")")
          problems
          (commitExpectation manifest)
          publicBytes
          (signManifest secret public manifest)
          bundle
  commitControl label commitBytes =
    let manifest = commitManifest commitBytes
     in expectConsistent
          (label <> " (" <> show (oracleObjectFormat base) <> ")")
          manifest
          (commitExpectation manifest)
          publicBytes
          (signManifest secret public manifest)
          bundle

  identity display email timestamp timezone =
    display <> " <" <> email <> "> " <> timestamp <> " " <> timezone
  identityCommit testedIdentity =
    oracleCommitWithHeaders
      [ treeHeader
      , "author " <> testedIdentity
      , committerHeader
      ]
  identityControl label testedIdentity = commitControl label (identityCommit testedIdentity)
  identityRefusal label testedIdentity = commitProblem label identityMalformed (identityCommit testedIdentity)

  canonicalEmailBytes = "oracle@example.invalid"
  identityPositiveCases =
    [ ("display name closed printable endpoints control", identity "!~" canonicalEmailBytes "0" "+0000")
    , ("timestamp one is canonical", identity "Amoebius Oracle" canonicalEmailBytes "1" "+0000")
    , ("timestamp exact 19-digit ceiling is canonical", identity "Amoebius Oracle" canonicalEmailBytes "9999999999999999999" "+0000")
    , ("email local admits every closed punctuation character", identity "Amoebius Oracle" "a.!#$%&'*+/=?^_`{|}~-z@example.invalid" "0" "+0000")
    , ("email local admits lowercase digits", identity "Amoebius Oracle" "a1@example.invalid" "0" "+0000")
    , ("domain label admits lowercase digits and interior hyphen", identity "Amoebius Oracle" "a@a1-b.c2" "0" "+0000")
    ]
  identityNegativeCases =
    [ ("display name must be nonempty", identity "" canonicalEmailBytes "0" "+0000")
    , ("display name rejects leading space", identity " Amoebius" canonicalEmailBytes "0" "+0000")
    , ("display name rejects trailing space", identity "Amoebius " canonicalEmailBytes "0" "+0000")
    , ("display name rejects double space", identity "Amoebius  Oracle" canonicalEmailBytes "0" "+0000")
    , ("display name rejects bytes below printable ASCII", identity ("A" <> ByteString.singleton 31 <> "B") canonicalEmailBytes "0" "+0000")
    , ("display name rejects bytes above printable ASCII", identity ("A" <> ByteString.singleton 127 <> "B") canonicalEmailBytes "0" "+0000")
    , ("display name rejects less-than", identity "A<B" canonicalEmailBytes "0" "+0000")
    , ("display name rejects greater-than", identity "A>B" canonicalEmailBytes "0" "+0000")
    , ("email requires exactly one at-sign", identity "Amoebius" "a@b.cd@ignored" "0" "+0000")
    , ("email rejects absence of an at-sign", identity "Amoebius" "ab.cd" "0" "+0000")
    , ("email domain requires multiple labels", identity "Amoebius" "a@localhost" "0" "+0000")
    , ("email local must be nonempty", identity "Amoebius" "@a.bc" "0" "+0000")
    , ("email local rejects leading dot", identity "Amoebius" ".a@b.cd" "0" "+0000")
    , ("email local rejects trailing dot", identity "Amoebius" "a.@b.cd" "0" "+0000")
    , ("email local rejects double dot", identity "Amoebius" "a..b@c.de" "0" "+0000")
    , ("email local rejects characters outside its closed set", identity "Amoebius" "A@b.cd" "0" "+0000")
    , ("domain rejects an empty leading label", identity "Amoebius" "a@.bc" "0" "+0000")
    , ("domain rejects an empty middle label", identity "Amoebius" "a@b..cd" "0" "+0000")
    , ("domain rejects an empty trailing label", identity "Amoebius" "a@bc." "0" "+0000")
    , ("domain label rejects leading hyphen", identity "Amoebius" "a@-b.cd" "0" "+0000")
    , ("domain label rejects trailing hyphen", identity "Amoebius" "a@b-.cd" "0" "+0000")
    , ("domain label rejects characters outside its closed set", identity "Amoebius" "a@b_c.de" "0" "+0000")
    , ("timestamp rejects canonical-looking zero with two digits", identity "Amoebius" canonicalEmailBytes "00" "+0000")
    , ("timestamp rejects leading zero before nonzero digit", identity "Amoebius" canonicalEmailBytes "01" "+0000")
    , ("timestamp rejects a nondigit after its first digit", identity "Amoebius" canonicalEmailBytes "1x" "+0000")
    , ("timestamp rejects 20 digits", identity "Amoebius" canonicalEmailBytes "11111111111111111111" "+0000")
    , ("commit identity rejects trailing fields", identity "Amoebius" canonicalEmailBytes "0" "+0000 trailing")
    ]

  timezoneControl timezone =
    identityControl
      ("timezone admits exact control " <> ByteString8.unpack timezone)
      (identity "Amoebius" canonicalEmailBytes "0" timezone)
  timezoneRefusal (label, timezone) =
    identityRefusal label (identity "Amoebius" canonicalEmailBytes "0" timezone)
  timezonePositiveCases = ["+0000", "-0001", "+1359", "+1400"]
  timezoneNegativeCases =
    [ ("timezone rejects four-byte under-width value", "+000")
    , ("timezone rejects six-byte over-width value", "+00000")
    , ("timezone rejects a non-sign prefix", "x0000")
    , ("timezone rejects a nondigit", "+0x00")
    , ("timezone rejects hour 15", "+1500")
    , ("timezone rejects minute 60", "+1360")
    , ("timezone hour 14 couples to minute zero", "+1401")
    , ("timezone rejects negative zero", "-0000")
    ]

  hashByteNegatives =
    [ ("width under", ByteString.replicate (width - 1) 97)
    , ("width over", ByteString.replicate (width + 1) 97)
    , ("uppercase", ByteString.singleton 65 <> ByteString.replicate (width - 1) 97)
    , ("g-bearing", ByteString.singleton 103 <> ByteString.replicate (width - 1) 97)
    , ("Unicode", TextEncoding.encodeUtf8 ("\x00e9" <> Text.replicate (width - 2) "a"))
    ]
  commitHashCases (shape, value) =
    commitProblem
      ("commit tree identity " <> shape <> " is rejected")
      (commitMalformed "commit tree identity is not canonical lowercase hexadecimal")
      (oracleCommitWithHeaders ["tree " <> value, authorHeader, committerHeader])
      <> commitProblem
        ("commit parent identity " <> shape <> " is rejected")
        (commitMalformed "commit has a malformed parent identity")
        (oracleCommitWithHeaders [treeHeader, "parent " <> value, authorHeader, committerHeader])

expectedManifestProblems
  :: Ed25519.SecretKey
  -> Ed25519.PublicKey
  -> ByteString
  -> OracleExpectation
  -> OracleFixture
  -> [ExactCase]
expectedManifestProblems secret public publicBytes expected fixture =
  case entries of
    [] ->
      [ ExactCase
          "expected-manifest fixture is nonempty"
          ["canonical source-acquisition fixture unexpectedly has no expected entries"]
      ]
    firstEntry : remainingEntries ->
      concat
        [ expectedProblem
            "empty independently supplied expected manifest"
            [envelopeProblem "SOURCE-ACQUISITION-EXPECTED-MANIFEST-EMPTY" "SourceAcquisitionExpectedManifestEmpty"]
            []
        , let reordered = reverse entries
              (previous, current) = oracleFirstOrderViolation (map oracleEntryPath reordered)
           in expectedProblem
                "noncanonical expected-manifest order"
                [ envelopeProblem
                    "SOURCE-ACQUISITION-EXPECTED-MANIFEST-ORDER"
                    (shown2 "SourceAcquisitionExpectedManifestNotStrictlyOrdered" previous current)
                ]
                reordered
        , let duplicated = entries <> [firstEntry]
              (previous, current) = oracleFirstOrderViolation (map oracleEntryPath duplicated)
           in expectedProblem
                "duplicate expected-manifest path"
                [ envelopeProblem
                    "SOURCE-ACQUISITION-EXPECTED-MANIFEST-ORDER"
                    (shown2 "SourceAcquisitionExpectedManifestNotStrictlyOrdered" previous current)
                , pathProblem
                    "SOURCE-ACQUISITION-EXPECTED-MANIFEST-DUPLICATE"
                    (oracleEntryPath firstEntry)
                    (shown1 "SourceAcquisitionExpectedManifestDuplicatePath" (oracleEntryPath firstEntry))
                ]
                duplicated
        , expectRefused
            "independent expected object format must join the signed format"
            [ envelopeProblem
                "SOURCE-ACQUISITION-EXPECTED-MANIFEST-OBJECT-FORMAT"
                ( "SourceAcquisitionExpectedManifestObjectFormatMismatch "
                    <> productionObjectFormatName differentObjectFormat
                    <> " "
                    <> productionObjectFormatName (oracleObjectFormat base)
                )
            ]
            expected
              { oracleExpectedManifestBytes =
                  oracleExpectedManifestEncodingFor differentObjectFormat entries
              }
            publicBytes
            cleanWire
            bundle
        , let upper = firstEntry {oracleEntryPath = "Case.hs"}
              lower = firstEntry {oracleEntryPath = "case.hs"}
           in expectedProblem
                "independent expected paths cannot alias under portable case folding"
                [ pathProblem
                    "SOURCE-ACQUISITION-EXPECTED-MANIFEST-CASE-COLLISION"
                    "case.hs"
                    ( shown2
                        "SourceAcquisitionExpectedManifestCaseFoldCollision"
                        ("Case.hs" :: FilePath)
                        ("case.hs" :: FilePath)
                    )
                ]
                [upper, lower]
        , let ancestor = firstEntry {oracleEntryPath = "A"}
              descendant = firstEntry {oracleEntryPath = "a/b"}
           in expectedProblem
                "independent expected paths cannot alias by case-folded ancestry"
                [ pathProblem
                    "SOURCE-ACQUISITION-EXPECTED-MANIFEST-PATH-CONFLICT"
                    "a/b"
                    (shown1 "SourceAcquisitionExpectedManifestPathConflict" ("a/b" :: FilePath))
                ]
                [ancestor, descendant]
        , let changed = firstEntry {oracleEntryGitObjectId = "bad-object"} : remainingEntries
           in expectedProblem
                "independent expected Git object identity must match the signed storage format"
                [ pathProblem
                    "SOURCE-ACQUISITION-EXPECTED-MANIFEST-GIT-OID"
                    (oracleEntryPath firstEntry)
                    ( shownPathObjectFormatProblem
                        "SourceAcquisitionExpectedManifestEntryGitObjectFormatMismatch"
                        (oracleEntryPath firstEntry)
                        (oracleObjectFormat base)
                        "bad-object"
                    )
                ]
                changed
        , let changed = firstEntry {oracleEntryBlobSha256 = "bad-sha"} : remainingEntries
           in expectedProblem
                "independent expected blob SHA-256 must be canonical"
                [ pathProblem
                    "SOURCE-ACQUISITION-EXPECTED-MANIFEST-BLOB-SHA256"
                    (oracleEntryPath firstEntry)
                    ( shown2
                        "SourceAcquisitionExpectedManifestEntryBlobSha256Malformed"
                        (oracleEntryPath firstEntry)
                        ("bad-sha" :: Text)
                    )
                ]
                changed
        , let changed = firstEntry {oracleEntryByteLength = 33554433} : remainingEntries
           in expectedProblem
                "independent expected entry size has the same closed materialization bound"
                [ pathProblem
                    "SOURCE-ACQUISITION-EXPECTED-MANIFEST-ENTRY-LIMIT"
                    (oracleEntryPath firstEntry)
                    ( shown2
                        "SourceAcquisitionExpectedManifestEntryTooLarge"
                        (oracleEntryPath firstEntry)
                        (33554433 :: Word64)
                    )
                ]
                changed
        , let encoded = oracleExpectedManifestEncoding base
              modeOffset =
                ByteString.length expectedManifestMagic
                  + 1
                  + 4
                  + 4
                  + ByteString.length (TextEncoding.encodeUtf8 (Text.pack (oracleEntryPath firstEntry)))
           in expectRefused
                "unsupported expected-manifest mode preserves its typed decode problem"
                [ pathProblem
                    "SOURCE-ACQUISITION-EXPECTED-MANIFEST-MODE"
                    (oracleEntryPath firstEntry)
                    ( shown2
                        "SourceAcquisitionExpectedManifestEntryModeUnsupported"
                        (oracleEntryPath firstEntry)
                        (4 :: Word8)
                    )
                ]
                expected
                  { oracleExpectedManifestBytes = replaceByteAt modeOffset 4 encoded
                  }
                publicBytes
                cleanWire
                bundle
        , expectRefused
            "unsupported expected-manifest object-format tag is a typed wire refusal"
            [ envelopeProblem
                "SOURCE-ACQUISITION-EXPECTED-MANIFEST-WIRE"
                ( shown1
                    "SourceAcquisitionExpectedManifestMalformed"
                    ("SourceAcquisitionWireMalformed \"unsupported expected-manifest object-format tag 3\"" :: Text)
                )
            ]
            expected
              { oracleExpectedManifestBytes =
                  replaceByteAt (ByteString.length expectedManifestMagic) 3 (oracleExpectedManifestEncoding base)
              }
            publicBytes
            cleanWire
            bundle
        , expectRefused
            "expected-manifest trailing bytes are noncanonical"
            [ envelopeProblem
                "SOURCE-ACQUISITION-EXPECTED-MANIFEST-WIRE"
                ( shown1
                    "SourceAcquisitionExpectedManifestMalformed"
                    ("SourceAcquisitionWireMalformed \"expected manifest has trailing bytes\"" :: Text)
                )
            ]
            expected
              { oracleExpectedManifestBytes =
                  oracleExpectedManifestEncoding base <> "trailing"
              }
            publicBytes
            cleanWire
            bundle
        , expectRefused
            "exact 16384-entry expected-manifest limit reaches entry framing"
            [ envelopeProblem
                "SOURCE-ACQUISITION-EXPECTED-MANIFEST-WIRE"
                ( shown1
                    "SourceAcquisitionExpectedManifestMalformed"
                    ("SourceAcquisitionWireMalformed \"expected-entry-path-length is truncated\"" :: Text)
                )
            ]
            expected
              { oracleExpectedManifestBytes =
                  expectedManifestMagic
                    <> ByteString.singleton (oracleObjectFormatTag (oracleObjectFormat base))
                    <> word32Literal 16384
              }
            publicBytes
            cleanWire
            bundle
        , expectRefused
            "expected-manifest entry count immediately above 16384 is typed before allocation"
            [ envelopeProblem
                "SOURCE-ACQUISITION-EXPECTED-MANIFEST-ENTRY-COUNT-LIMIT"
                ( shown2
                    "SourceAcquisitionExpectedManifestEntryCountTooLarge"
                    (16385 :: Word32)
                    (16384 :: Word32)
                )
            ]
            expected
              { oracleExpectedManifestBytes =
                  expectedManifestMagic
                    <> ByteString.singleton (oracleObjectFormatTag (oracleObjectFormat base))
                    <> word32Literal 16385
              }
            publicBytes
            cleanWire
            bundle
        , expectRefused
            "exact 16-MiB expected-manifest byte limit reaches decoding"
            [ envelopeProblem
                "SOURCE-ACQUISITION-EXPECTED-MANIFEST-WIRE"
                ( shown1
                    "SourceAcquisitionExpectedManifestMalformed"
                    ("SourceAcquisitionWireMalformed \"missing exact expected-manifest magic\"" :: Text)
                )
            ]
            expected
              { oracleExpectedManifestBytes = ByteString.replicate 16777216 0
              }
            publicBytes
            cleanWire
            bundle
        , expectedProblem
            "independent universe omission exposes an unexpected signed entry"
            [ pathProblem
                "SOURCE-ACQUISITION-EXPECTED-MANIFEST-UNEXPECTED"
                (oracleEntryPath firstEntry)
                (shown1 "SourceAcquisitionExpectedManifestEntryUnexpected" (oracleEntryPath firstEntry))
            ]
            remainingEntries
        , let (extraEntry, _) = member (oracleObjectFormat base) "zz-extra.hs" OracleRegularFile "extra\n"
           in expectedProblem
                "independent universe addition exposes a missing signed entry"
                [ pathProblem
                    "SOURCE-ACQUISITION-EXPECTED-MANIFEST-MISSING"
                    "zz-extra.hs"
                    (shown1 "SourceAcquisitionExpectedManifestEntryMissing" ("zz-extra.hs" :: FilePath))
                ]
                (entries <> [extraEntry])
        , let changedMode = differentMode (oracleEntryMode firstEntry)
              changed = firstEntry {oracleEntryMode = changedMode} : remainingEntries
           in expectedProblem
                "independent expected mode differs from signed mode"
                [ pathProblem
                    "SOURCE-ACQUISITION-EXPECTED-MANIFEST-MODE"
                    (oracleEntryPath firstEntry)
                    ( shownModeMismatch
                        (oracleEntryPath firstEntry)
                        changedMode
                        (oracleEntryMode firstEntry)
                    )
                ]
                changed
        , let changed = firstEntry {oracleEntryGitObjectId = differentGitIdentity base} : remainingEntries
           in expectedProblem
                "independent expected Git object differs from signed object"
                [ pathProblem
                    "SOURCE-ACQUISITION-EXPECTED-MANIFEST-GIT-OID"
                    (oracleEntryPath firstEntry)
                    ( shown3
                        "SourceAcquisitionExpectedManifestEntryGitObjectMismatch"
                        (oracleEntryPath firstEntry)
                        (differentGitIdentity base)
                        (oracleEntryGitObjectId firstEntry)
                    )
                ]
                changed
        , let changedLength = oracleEntryByteLength firstEntry + 1
              changed = firstEntry {oracleEntryByteLength = changedLength} : remainingEntries
           in expectedProblem
                "independent expected byte length differs from signed length"
                [ pathProblem
                    "SOURCE-ACQUISITION-EXPECTED-MANIFEST-LENGTH"
                    (oracleEntryPath firstEntry)
                    ( shown3
                        "SourceAcquisitionExpectedManifestEntryByteLengthMismatch"
                        (oracleEntryPath firstEntry)
                        changedLength
                        (oracleEntryByteLength firstEntry)
                    )
                ]
                changed
        , let changed = firstEntry {oracleEntryBlobSha256 = differentSha} : remainingEntries
           in expectedProblem
                "independent expected blob SHA-256 differs from signed value"
                [ pathProblem
                    "SOURCE-ACQUISITION-EXPECTED-MANIFEST-BLOB-SHA256"
                    (oracleEntryPath firstEntry)
                    ( shown3
                        "SourceAcquisitionExpectedManifestEntryBlobSha256Mismatch"
                        (oracleEntryPath firstEntry)
                        differentSha
                        (oracleEntryBlobSha256 firstEntry)
                    )
                ]
                changed
        , let changed = firstEntry {oracleEntryPath = "../expected.hs"} : remainingEntries
           in expectedProblem
                "independent expected path must use the portable grammar"
                [ pathProblem
                    "SOURCE-ACQUISITION-EXPECTED-MANIFEST-PATH"
                    "../expected.hs"
                    (shown1 "SourceAcquisitionExpectedManifestPathInvalid" ("../expected.hs" :: FilePath))
                ]
                changed
        , expectRefused
            "expected-manifest magic is exact"
            [ envelopeProblem
                "SOURCE-ACQUISITION-EXPECTED-MANIFEST-WIRE"
                ( shown1
                    "SourceAcquisitionExpectedManifestMalformed"
                    ("SourceAcquisitionWireMalformed \"missing exact expected-manifest magic\"" :: Text)
                )
            ]
            expected {oracleExpectedManifestBytes = "wrong-magic"}
            publicBytes
            cleanWire
            bundle
        , expectRefused
            "expected-manifest bytes exceed the closed 16-MiB limit"
            [ envelopeProblem
                "SOURCE-ACQUISITION-EXPECTED-MANIFEST-LIMIT"
                (shown1 "SourceAcquisitionExpectedManifestTooLarge" (16777217 :: Int))
            ]
            expected {oracleExpectedManifestBytes = ByteString.replicate 16777217 0}
            publicBytes
            cleanWire
            bundle
        ]
 where
  base = fixtureManifest fixture
  entries = oracleEntries base
  bundle = fixtureBundle fixture
  cleanWire = signManifest secret public base
  differentSha = Text.replicate 64 "f"
  differentObjectFormat = case oracleObjectFormat base of
    OracleObjectSha1 -> OracleObjectSha256
    OracleObjectSha256 -> OracleObjectSha1
  expectedProblem label expectedProblems changedEntries =
    expectRefused
      label
      expectedProblems
      expected
        { oracleExpectedManifestBytes =
            oracleExpectedManifestEncodingFor (oracleObjectFormat base) changedEntries
        }
      publicBytes
      cleanWire
      bundle
  differentMode OracleRegularFile = OracleExecutableFile
  differentMode _ = OracleRegularFile

shownModeMismatch :: FilePath -> OracleMode -> OracleMode -> Text
shownModeMismatch path expectedMode actualMode =
  "SourceAcquisitionExpectedManifestEntryModeMismatch "
    <> Text.pack (show path)
    <> " "
    <> productionModeName expectedMode
    <> " "
    <> productionModeName actualMode

productionModeName :: OracleMode -> Text
productionModeName OracleRegularFile = "RegularFile"
productionModeName OracleExecutableFile = "ExecutableFile"
productionModeName OracleSymbolicLink = "SymbolicLink"

manifestProblems
  :: Ed25519.SecretKey
  -> Ed25519.PublicKey
  -> ByteString
  -> OracleExpectation
  -> OracleFixture
  -> [ExactCase]
manifestProblems secret public publicBytes expected fixture =
  case members of
    [] ->
      [ ExactCase
          "manifest fixture is nonempty"
          ["canonical source-acquisition fixture unexpectedly has no members"]
      ]
    firstPair : _ ->
      concat
        [ let emptyFixture = deriveFixture base []
           in fixtureProblem
                "empty manifest"
                [ envelopeProblem
                    "SOURCE-ACQUISITION-MANIFEST-EMPTY"
                    (shown0 "SourceAcquisitionManifestEmpty")
                ]
                emptyFixture
        , let reordered = reverse members
              reorderedFixture = deriveFixture base reordered
              paths = map (oracleEntryPath . fst) reordered
              (previous, current) = oracleFirstOrderViolation paths
           in fixtureProblem
                "noncanonical manifest order"
                [ envelopeProblem
                    "SOURCE-ACQUISITION-MANIFEST-ORDER"
                    (shown2 "SourceAcquisitionManifestNotStrictlyOrdered" previous current)
                ]
                reorderedFixture
        , let duplicated = members <> [firstPair]
              duplicatedFixture = deriveFixture base duplicated
              paths = map (oracleEntryPath . fst) duplicated
              duplicatePath = oracleEntryPath (fst firstPair)
              (previous, current) = oracleFirstOrderViolation paths
           in fixtureProblem
                "duplicate manifest path"
                [ envelopeProblem
                    "SOURCE-ACQUISITION-MANIFEST-ORDER"
                    (shown2 "SourceAcquisitionManifestNotStrictlyOrdered" previous current)
                , pathProblem
                    "SOURCE-ACQUISITION-MANIFEST-DUPLICATE"
                    duplicatePath
                    (shown1 "SourceAcquisitionManifestDuplicatePath" duplicatePath)
                ]
                duplicatedFixture
        , let duplicated = members <> [firstPair]
              validDuplicateFixture = deriveFixture base duplicated
              duplicatePath = oracleEntryPath (fst firstPair)
              invalidObject = "bad-object"
              invalidEntries =
                [ if oracleEntryPath entry == duplicatePath
                    then entry {oracleEntryGitObjectId = invalidObject}
                    else entry
                | entry <- oracleEntries (fixtureManifest validDuplicateFixture)
                ]
              invalidManifest =
                (fixtureManifest validDuplicateFixture)
                  { oracleEntries = invalidEntries
                  }
              changed = validDuplicateFixture {fixtureManifest = invalidManifest}
              paths = map oracleEntryPath invalidEntries
              (previous, current) = oracleFirstOrderViolation paths
           in fixtureProblem
                "duplicate identical integrity problems are normalized once"
                [ envelopeProblem
                    "SOURCE-ACQUISITION-MANIFEST-ORDER"
                    (shown2 "SourceAcquisitionManifestNotStrictlyOrdered" previous current)
                , pathProblem
                    "SOURCE-ACQUISITION-MANIFEST-DUPLICATE"
                    duplicatePath
                    (shown1 "SourceAcquisitionManifestDuplicatePath" duplicatePath)
                , pathProblem
                    "SOURCE-ACQUISITION-GIT-OID"
                    duplicatePath
                    ( shownPathObjectFormatProblem
                        "SourceAcquisitionEntryGitObjectFormatMismatch"
                        duplicatePath
                        (oracleObjectFormat base)
                        invalidObject
                    )
                ]
                changed
        , let changed = deriveFixture base (replaceFirstMemberPath "../escape.hs" members)
           in fixtureProblem
                "parent-traversing path"
                [ pathProblem
                    "SOURCE-ACQUISITION-PATH"
                    "../escape.hs"
                    (shown1 "SourceAcquisitionManifestPathInvalid" ("../escape.hs" :: FilePath))
                ]
                changed
        , let upper = (fst firstPair) {oracleEntryPath = "Case.hs"}
              lower = (fst firstPair) {oracleEntryPath = "case.hs"}
              changed = deriveFixture base [(upper, snd firstPair), (lower, snd firstPair)]
           in fixtureProblem
                "portable case-fold equality collision"
                [ pathProblem
                    "SOURCE-ACQUISITION-PATH-CASE-COLLISION"
                    "case.hs"
                    ( shown2
                        "SourceAcquisitionManifestCaseFoldCollision"
                        ("Case.hs" :: FilePath)
                        ("case.hs" :: FilePath)
                    )
                ]
                changed
        , let ancestor = (fst firstPair) {oracleEntryPath = "a"}
              child = (fst firstPair) {oracleEntryPath = "a/b"}
              changed = manualFixture base [(ancestor, snd firstPair), (child, snd firstPair)]
           in fixtureProblem
                "same-case file/directory path conflict"
                [ pathProblem
                    "SOURCE-ACQUISITION-PATH-CONFLICT"
                    "a/b"
                    (shown1 "SourceAcquisitionManifestPathConflict" ("a/b" :: FilePath))
                ]
                changed
        , let ancestor = (fst firstPair) {oracleEntryPath = "A"}
              child = (fst firstPair) {oracleEntryPath = "a/b"}
              changed = manualFixture base [(ancestor, snd firstPair), (child, snd firstPair)]
           in fixtureProblem
                "case-folded file/directory ancestry conflict"
                [ pathProblem
                    "SOURCE-ACQUISITION-PATH-CONFLICT"
                    "a/b"
                    (shown1 "SourceAcquisitionManifestPathConflict" ("a/b" :: FilePath))
                ]
                changed
        , let badObject = "bad-object"
              changedEntries =
                map fst
                  (modifyFirstEntry (\entry -> entry {oracleEntryGitObjectId = badObject}) members)
              changed = base {oracleEntries = changedEntries}
              path = oracleEntryPath (fst firstPair)
           in signedManifestProblem
                "entry Git object identity has the wrong storage format"
                [ pathProblem
                    "SOURCE-ACQUISITION-GIT-OID"
                    path
                    ( shownPathObjectFormatProblem
                        "SourceAcquisitionEntryGitObjectFormatMismatch"
                        path
                        (oracleObjectFormat base)
                        badObject
                    )
                ]
                changed
                bundle
        , let badSha = "bad-sha"
              changedEntries =
                map fst
                  (modifyFirstEntry (\entry -> entry {oracleEntryBlobSha256 = badSha}) members)
              changed = base {oracleEntries = changedEntries}
              path = oracleEntryPath (fst firstPair)
           in signedManifestProblem
                "entry blob SHA-256 has malformed shape"
                [ pathProblem
                    "SOURCE-ACQUISITION-BLOB-SHA256"
                    path
                    (shown2 "SourceAcquisitionEntryBlobSha256Malformed" path badSha)
                ]
                changed
                bundle
        , let changedMembers =
                modifyFirstEntry
                  (\entry -> entry {oracleEntryGitObjectId = differentGitIdentity base})
                  members
              changed = deriveFixture base changedMembers
              path = oracleEntryPath (fst firstPair)
              actualObject = oracleEntryGitObjectId (fst firstPair)
              declaredObject = differentGitIdentity base
              detail =
                "SourceAcquisitionEntryGitObjectMismatch "
                  <> Text.pack (show path)
                  <> " (LoadedBlobObjectIdMismatch "
                  <> Text.pack (show declaredObject)
                  <> " "
                  <> Text.pack (show actualObject)
                  <> ")"
           in fixtureContentProblem
                "blob bytes do not match the Git object identity"
                [pathProblem "SOURCE-ACQUISITION-GIT-OID" path detail]
                changed
        , let changedMembers =
                modifyFirstEntry
                  (\entry -> entry {oracleEntryByteLength = oracleEntryByteLength entry + 1})
                  members
              changed = deriveFixture base changedMembers
              expectedLength = toInteger (ByteString.length bundle) + 1
              actualLength = toInteger (ByteString.length bundle)
           in fixtureContentProblem
                "declared member lengths differ from exact bundle length"
                [ envelopeProblem
                    "SOURCE-ACQUISITION-LENGTH"
                    (shown2 "SourceAcquisitionBundleLengthMismatch" expectedLength actualLength)
                ]
                changed
        , let changedMembers =
                modifyFirstEntry
                  (\entry -> entry {oracleEntryBlobSha256 = differentSha})
                  members
              changed = deriveFixture base changedMembers
              path = oracleEntryPath (fst firstPair)
              actualSha = oracleEntryBlobSha256 (fst firstPair)
           in fixtureContentProblem
                "blob SHA-256 differs from the exact member bytes"
                [ pathProblem
                    "SOURCE-ACQUISITION-BLOB-SHA256"
                    path
                    ( shown3
                        "SourceAcquisitionEntryBlobSha256Mismatch"
                        path
                        differentSha
                        actualSha
                    )
                ]
                changed
        , let changedBundle = bundle <> "x"
              actualBundleIdentity = oracleSha256 changedBundle
           in expectRefused
                "extra byte changes immutable-bundle digest and aggregate length"
                [ envelopeProblem
                    "SOURCE-ACQUISITION-BUNDLE"
                    ( shown2
                        "SourceAcquisitionBundleIdentityMismatch"
                        (oracleBundleIdentityField base)
                        actualBundleIdentity
                    )
                , envelopeProblem
                    "SOURCE-ACQUISITION-LENGTH"
                    ( shown2
                        "SourceAcquisitionBundleLengthMismatch"
                        (toInteger (ByteString.length bundle))
                        (toInteger (ByteString.length changedBundle))
                    )
                ]
                expected
                publicBytes
                (signManifest secret public base)
                changedBundle
        , let changedBundle = ByteString.dropEnd 1 bundle
              actualBundleIdentity = oracleSha256 changedBundle
           in expectRefused
                "missing byte changes immutable-bundle digest and aggregate length"
                [ envelopeProblem
                    "SOURCE-ACQUISITION-BUNDLE"
                    ( shown2
                        "SourceAcquisitionBundleIdentityMismatch"
                        (oracleBundleIdentityField base)
                        actualBundleIdentity
                    )
                , envelopeProblem
                    "SOURCE-ACQUISITION-LENGTH"
                    ( shown2
                        "SourceAcquisitionBundleLengthMismatch"
                        (toInteger (ByteString.length bundle))
                        (toInteger (ByteString.length changedBundle))
                    )
                ]
                expected
                publicBytes
                (signManifest secret public base)
                changedBundle
        ]
 where
  base = fixtureManifest fixture
  members = fixtureMembers fixture
  bundle = fixtureBundle fixture
  differentSha = Text.replicate 64 "f"
  fixtureProblem label expectedProblems changed =
    expectRefused
      label
      expectedProblems
      (alignIdentityExpectation (fixtureManifest changed) expected)
      publicBytes
      (signFixture secret public changed)
      (fixtureBundle changed)
  fixtureContentProblem label expectedProblems changed =
    expectRefused
      label
      expectedProblems
      (alignFullExpectation (fixtureManifest changed) expected)
      publicBytes
      (signFixture secret public changed)
      (fixtureBundle changed)
  signedManifestProblem label expectedProblems manifest testedBundle =
    expectRefused
      label
      expectedProblems
      (alignIdentityExpectation manifest expected)
      publicBytes
      (signManifest secret public manifest)
      testedBundle

closedPathPredicateProblems
  :: Ed25519.SecretKey
  -> Ed25519.PublicKey
  -> ByteString
  -> OracleExpectation
  -> OracleFixture
  -> [ExactCase]
closedPathPredicateProblems secret public publicBytes expected fixture =
  case fixtureMembers fixture of
    [] ->
      [ ExactCase
          "path fixture is nonempty"
          ["canonical source-acquisition fixture unexpectedly has no members for path matrix"]
      ]
    firstMember : _ ->
      concatMap (uncurry (pathControl firstMember)) admittedPaths
        <> concatMap (uncurry (pathRefusal firstMember)) invalidPathCases
        <> concatMap
          (\name -> pathRefusal firstMember ("Windows reserved basename " <> name <> " is rejected") ("src/" <> name))
          reservedNames
        <> pathRefusal firstMember "Windows reserved basename matching is case-insensitive" "src/con"
        <> pathRefusal firstMember "Windows reserved basename matching ignores an extension" "src/CON.txt"
 where
  base = fixtureManifest fixture
  admittedPaths =
    [ ("path admits lowercase, uppercase, digit, slash, and every closed punctuation", "aAzZ09/._@+,-")
    , ("near-miss dot segment is admitted", "src/.gita/Main.hs")
    , ("near-miss parent segment is admitted", "src/..a/Main.hs")
    , ("near-miss embedded double dot is admitted", "src/a..b/Main.hs")
    , ("near-miss Git segment is admitted", "src/git/config")
    , ("near-miss trailing dot has a following character", "src/trailing.x")
    , ("adjacent CON name is admitted", "src/CON0")
    , ("adjacent COM lower boundary is admitted", "src/COM0")
    , ("adjacent COM upper boundary is admitted", "src/COM10")
    , ("adjacent LPT lower boundary is admitted", "src/LPT0")
    , ("adjacent LPT upper boundary is admitted", "src/LPT10")
    , ("adjacent NUL name is admitted", "src/NULx")
    ]
  invalidPathCases =
    [ ("empty path is rejected", "")
    , ("leading empty path segment is rejected", "/a")
    , ("middle empty path segment is rejected", "a//b")
    , ("trailing empty path segment is rejected", "a/")
    , ("single-dot path segment is rejected", "a/./b")
    , ("double-dot path segment is rejected", "a/../b")
    , ("case-folded dot-git segment is rejected", "a/.GiT/b")
    , ("trailing-dot path segment is rejected", "a/trailing.")
    ]
      <> [ ("path rejects ASCII character " <> show character, "a" <> [character] <> "b")
         | character <- invalidAsciiCharacters
         ]
      <> [ ("path rejects Unicode scalar " <> show scalar, "a" <> scalar <> "b")
         | scalar <- ["\x00e9", "\x03bb", "\x0660"]
         ]
  invalidAsciiCharacters =
    map toEnum ([0 .. 42] <> [58 .. 63] <> [91 .. 94] <> [96] <> [123 .. 127])
  reservedNames =
    ["CON", "PRN", "AUX", "NUL"]
      <> ["COM" <> show number | number <- [(1 :: Int) .. 9]]
      <> ["LPT" <> show number | number <- [(1 :: Int) .. 9]]

  pathControl memberPair label path =
    let tested = singlePathFixture base memberPair path
     in expectConsistent
          label
          (fixtureManifest tested)
          expected
          publicBytes
          (signFixture secret public tested)
          (fixtureBundle tested)
  pathRefusal memberPair label path =
    let tested = singlePathFixture base memberPair path
     in expectRefused
          label
          [ pathProblem
              "SOURCE-ACQUISITION-PATH"
              path
              (shown1 "SourceAcquisitionManifestPathInvalid" path)
          ]
          (alignIdentityExpectation (fixtureManifest tested) expected)
          publicBytes
          (signFixture secret public tested)
          (fixtureBundle tested)

ingressAndBoundaryProblems
  :: Ed25519.SecretKey
  -> Ed25519.PublicKey
  -> ByteString
  -> OracleExpectation
  -> OracleFixture
  -> ByteString
  -> [ExactCase]
ingressAndBoundaryProblems secret public publicBytes expected fixture cleanWire =
  case members of
    [] ->
      [ ExactCase
          "ingress fixture is nonempty"
          ["canonical source-acquisition fixture unexpectedly has no members"]
      ]
    firstMember : _ ->
      concat
        [ expectRefused
            "declared payload above the closed 16 MiB limit"
            [ envelopeProblem
                "SOURCE-ACQUISITION-PAYLOAD-LIMIT"
                (shown1 "SourceAcquisitionPayloadTooLarge" (16777217 :: Word64))
            ]
            expected
            publicBytes
            (envelopeMagic <> "16777217\n")
            bundle
        , expectRefused
            "envelope above its closed derived limit"
            [ envelopeProblem
                "SOURCE-ACQUISITION-ENVELOPE-LIMIT"
                (shown1 "SourceAcquisitionEnvelopeTooLarge" (maximumOracleEnvelopeBytes + 1))
            ]
            expected
            publicBytes
            (ByteString.replicate (maximumOracleEnvelopeBytes + 1) 0)
            bundle
        , expectRefused
            "bundle above the closed 32 MiB limit"
            [ envelopeProblem
                "SOURCE-ACQUISITION-BUNDLE-LIMIT"
                (shown1 "SourceAcquisitionBundleTooLarge" (33554433 :: Int))
            ]
            expected
            publicBytes
            cleanWire
            (ByteString.replicate 33554433 0)
        , let oversized = base {oraclePhase = Text.replicate 4097 "0"}
           in expectRefused
                "authenticated field above the closed 4096-byte limit"
                [ envelopeProblem
                    "SOURCE-ACQUISITION-FIELD-LIMIT"
                    (shown2 "SourceAcquisitionFieldTooLarge" ("phase" :: Text) (4097 :: Word32))
                ]
                expected
                publicBytes
                (signManifest secret public oversized)
                bundle
        , let deepPath = intercalate "/" (replicate 65 "a")
              tested = singlePathFixture base firstMember deepPath
           in fixtureRefusal
                "path above the closed 64-component limit"
                [ pathProblem
                    "SOURCE-ACQUISITION-PATH-DEPTH"
                    deepPath
                    (shown2 "SourceAcquisitionManifestPathTooDeep" deepPath (65 :: Int))
                ]
                tested
        , let segment = replicate 256 'a'
              tested = singlePathFixture base firstMember segment
           in fixtureRefusal
                "path segment above the closed 255-byte limit"
                [ pathProblem
                    "SOURCE-ACQUISITION-PATH-SEGMENT-LENGTH"
                    segment
                    ( shown3
                        "SourceAcquisitionManifestPathSegmentTooLong"
                        segment
                        (Text.pack segment)
                        (256 :: Int)
                    )
                ]
                tested
        , let path = intercalate "/" (replicate 205 'a' : replicate 4 (replicate 204 'a'))
              tested = singlePathFixture base firstMember path
           in fixtureRefusal
                "path above the closed 1024-byte limit"
                [ pathProblem
                    "SOURCE-ACQUISITION-PATH-LENGTH"
                    path
                    (shown2 "SourceAcquisitionManifestPathTooLong" path (1025 :: Int))
                ]
                tested
        , concatMap
            (\(label, path) ->
                let tested = singlePathFixture base firstMember path
                 in fixtureRefusal
                      label
                      [ pathProblem
                          "SOURCE-ACQUISITION-PATH"
                          path
                          (shown1 "SourceAcquisitionManifestPathInvalid" path)
                      ]
                      tested
            )
            [ ("drive-colon path is outside the portable grammar", "C:/Main.hs")
            , ("leading-slash path is outside the portable grammar", "/src/Main.hs")
            , ("backslash path is outside the portable grammar", "src\\Main.hs")
            , ("control-bearing path is outside the portable grammar", "src/\nMain.hs")
            , ("Unicode path is outside the narrow ASCII grammar", "src/caf\233.hs")
            , ("dot path segment is rejected", "src/./Main.hs")
            , ("parent path segment is rejected", "src/../Main.hs")
            , ("empty path segment is rejected", "src//Main.hs")
            , ("case-insensitive .git segment is rejected", ".GIT/config")
            , ("Windows device basename is rejected", "src/CON.hs")
            , ("trailing-dot segment is rejected", "src/trailing.")
            ]
        , boundaryPath
            "255-byte path segment is admitted diagnostically"
            (replicate 255 'a')
            firstMember
        , boundaryPath
            "64-component path is admitted diagnostically"
            (intercalate "/" (replicate 64 "a"))
            firstMember
        , boundaryPath
            "1024-byte path is admitted diagnostically"
            (intercalate "/" (replicate 5 (replicate 204 'a')))
            firstMember
        , let oversizedEntry =
                (fst firstMember) {oracleEntryByteLength = 33554433}
              oversizedManifest = base {oracleEntries = [oversizedEntry]}
              path = oracleEntryPath oversizedEntry
           in expectRefused
                "entry above the closed bundle-member limit"
                [ pathProblem
                    "SOURCE-ACQUISITION-ENTRY-LIMIT"
                    path
                    (shown2 "SourceAcquisitionEntryTooLarge" path (33554433 :: Word64))
                ]
                expected
                publicBytes
                (signManifest secret public oversizedManifest)
                bundle
        , let noncanonicalPrefix = leadingZeroLengthPrefix (oracleEnvelopePrefix base)
           in expectRefused
                "authenticated leading-zero length is noncanonical"
                [ envelopeProblem
                    "SOURCE-ACQUISITION-CANONICAL"
                    (shown0 "SourceAcquisitionWireNonCanonical")
                ]
                expected
                publicBytes
                (signPrefix secret public noncanonicalPrefix)
                bundle
        , expectRefused
            "payload-length syntax rejects a plus sign before authentication"
            [ envelopeProblem
                "SOURCE-ACQUISITION-WIRE"
                ( shown1
                    "SourceAcquisitionWireMalformed"
                    ("payload length is not a bounded unsigned decimal integer" :: Text)
                )
            ]
            expected
            publicBytes
            (plusPrefixedLength cleanWire)
            bundle
        , let sequential =
                withRecomputedFrozen
                  (base {oracleCustody = OracleSequentialMutableBundle})
           in expectRefused
                "sequential mutable custody cannot substitute for a frozen bundle"
                [ envelopeProblem
                    "SOURCE-ACQUISITION-CUSTODY"
                    (shown1 "SourceAcquisitionCustodyUnsupported" (2 :: Word8))
                ]
                expected
                publicBytes
                (signManifest secret public sequential)
                bundle
        , let oversizedCountPayload =
                ByteString.take (entryCountOffset base) (oracleManifestBytes base)
                  <> word32Literal 16385
           in expectRefused
                "entry count immediately above 16384"
                [ envelopeProblem
                    "SOURCE-ACQUISITION-MANIFEST-SIZE"
                    (shown1 "SourceAcquisitionManifestTooLarge" (16385 :: Word32))
                ]
                expected
                publicBytes
                (signPayload secret public oversizedCountPayload)
                bundle
        ]
 where
  base = fixtureManifest fixture
  members = fixtureMembers fixture
  bundle = fixtureBundle fixture
  fixtureRefusal label expectedProblems tested =
    expectRefused
      label
      expectedProblems
      (alignIdentityExpectation (fixtureManifest tested) expected)
      publicBytes
      (signFixture secret public tested)
      (fixtureBundle tested)
  boundaryPath label path memberPair =
    let tested = singlePathFixture base memberPair path
     in expectConsistent
          label
          (fixtureManifest tested)
          expected
          publicBytes
          (signFixture secret public tested)
          (fixtureBundle tested)

maximumOracleEnvelopeBytes :: Int
maximumOracleEnvelopeBytes =
  ByteString.length envelopeMagic + 8 + 1 + 16777216 + 64

closedWirePredicateProblems
  :: Ed25519.SecretKey
  -> Ed25519.PublicKey
  -> ByteString
  -> OracleExpectation
  -> OracleFixture
  -> ByteString
  -> [ExactCase]
closedWirePredicateProblems secret public publicBytes expected fixture cleanWire =
  concat
    [ expectRefused
        "empty payload-length decimal is rejected by its own guard"
        [wireMalformed "payload length is not a bounded unsigned decimal integer"]
        expected
        publicBytes
        (envelopeMagic <> "\n")
        bundle
    , let rawLength = ByteString8.pack (show (ByteString.length payload))
          nineDigitLength = ByteString.replicate (9 - ByteString.length rawLength) 48 <> rawLength
          prefix = envelopeMagic <> nineDigitLength <> "\n" <> payload
       in expectRefused
            "nine payload-length digits are rejected at the exact over-bound"
            [wireMalformed "payload length is not a bounded unsigned decimal integer"]
            expected
            publicBytes
            (signPrefix secret public prefix)
            bundle
    , expectRefused
        "65 signature bytes are rejected by the exact signature framing guard"
        [wireMalformed "Ed25519 signature must be exactly 64 bytes"]
        expected
        publicBytes
        (cleanWire <> "x")
        bundle
    , let payloadWithTrailingByte = payload <> "x"
       in expectRefused
            "authenticated main payload trailing byte is rejected by its own guard"
            [wireMalformed "payload has trailing bytes"]
            expected
            publicBytes
            (signPayload secret public payloadWithTrailingByte)
            bundle
    ]
 where
  payload = oracleManifestBytes (fixtureManifest fixture)
  bundle = fixtureBundle fixture
  wireMalformed detail =
    envelopeProblem
      "SOURCE-ACQUISITION-WIRE"
      (shown1 "SourceAcquisitionWireMalformed" (detail :: Text))

wireAndAuthenticationProblems
  :: Ed25519.SecretKey
  -> Ed25519.PublicKey
  -> ByteString
  -> ByteString
  -> OracleExpectation
  -> OracleFixture
  -> ByteString
  -> [ExactCase]
wireAndAuthenticationProblems secret public publicBytes otherPublicBytes expected fixture cleanWire =
  case members of
    [] ->
      [ ExactCase
          "authentication fixture is nonempty"
          ["canonical source-acquisition fixture unexpectedly has no members"]
      ]
    firstMember : _ ->
      concat
        [ expectRefused
            "bad envelope magic precedes public-key and payload interpretation"
            [wireMalformed "missing exact v2 envelope magic"]
            expected
            ByteString.empty
            (replaceByteAt 0 0 cleanWire)
            bundle
        , expectRefused
            "truncated signature is a framing refusal"
            [wireMalformed "Ed25519 signature must be exactly 64 bytes"]
            expected
            publicBytes
            (ByteString.dropEnd 1 cleanWire)
            bundle
        , expectRefused
            "declared payload beyond available envelope bytes is a framing refusal"
            [wireMalformed "declared payload exceeds envelope bytes"]
            expected
            publicBytes
            (envelopeMagic <> "10\nshort")
            bundle
        , expectRefused
            "missing payload-length terminator precedes key inspection"
            [wireMalformed "missing payload-length terminator"]
            expected
            ByteString.empty
            (envelopeMagic <> "123")
            bundle
        , expectRefused
            "31-byte Ed25519 public key is rejected before payload decoding"
            [publicKeyInvalid]
            expected
            (ByteString.replicate 31 0)
            cleanWire
            bundle
        , expectRefused
            "33-byte Ed25519 public key is rejected before payload decoding"
            [publicKeyInvalid]
            expected
            (ByteString.replicate 33 0)
            cleanWire
            bundle
        , expectRefused
            "wrong but well-formed public key rejects the canonical envelope"
            [signatureInvalid]
            expected
            otherPublicBytes
            cleanWire
            bundle
        , expectRefused
            "bit-flipped signature rejects the canonical envelope"
            [signatureInvalid]
            expected
            publicBytes
            (corruptSignature cleanWire)
            bundle
        , let changedWire = signManifest secret public (base {oracleAuthority = "phase-00-source-observer-x"})
              originalSignature = ByteString.drop (ByteString.length cleanWire - 64) cleanWire
           in expectRefused
                "signed envelope field changed without a matching signature"
                [signatureInvalid]
                expected
                publicBytes
                (replaceSignatureWith changedWire originalSignature)
                bundle
        , let invalidUtf8Payload =
                replaceByteAt (ByteString.length payloadMagic + 4) 255 payload
              validWire = signPayload secret public invalidUtf8Payload
           in expectRefused
                "invalid signature precedes malformed UTF-8 decoding"
                [signatureInvalid]
                expected
                publicBytes
                (corruptSignature validWire)
                bundle
                <> expectRefused
                  "valid signature exposes exact malformed UTF-8"
                  [wireMalformed "phase is not UTF-8"]
                  expected
                  publicBytes
                  validWire
                  bundle
        , let truncatedPayload = ByteString.take (ByteString.length payloadMagic + 2) payload
           in expectRefused
                "authenticated truncated field framing"
                [wireMalformed "phase-length is truncated"]
                expected
                publicBytes
                (signPayload secret public truncatedPayload)
                bundle
        , let truncatedValuePayload = payloadMagic <> word32Literal 1
           in expectRefused
                "authenticated field value availability is exact"
                [wireMalformed "phase exceeds payload bytes"]
                expected
                publicBytes
                (signPayload secret public truncatedValuePayload)
                bundle
        , let truncatedCustodyPayload = ByteString.take (custodyOffset base) payload
           in expectRefused
                "authenticated missing one-byte custody field is classified exactly"
                [wireMalformed "custody is missing"]
                expected
                publicBytes
                (signPayload secret public truncatedCustodyPayload)
                bundle
        , let commitLengthOffset =
                entryCountOffset base - sizedBytesLength (oracleCommitBytes base)
              truncatedCommitPayload =
                ByteString.take commitLengthOffset payload <> word32Literal 1
           in expectRefused
                "authenticated commit value availability is exact"
                [wireMalformed "commit exceeds payload bytes"]
                expected
                publicBytes
                (signPayload secret public truncatedCommitPayload)
                bundle
        , let firstEntry = fst firstMember
              byteLengthOffset =
                firstModeOffset base
                  + 1
                  + sizedTextLength (oracleEntryGitObjectId firstEntry)
              truncatedByteLengthPayload = ByteString.take (byteLengthOffset + 4) payload
           in expectRefused
                "authenticated eight-byte entry length framing is exact"
                [wireMalformed "entry-byte-length is truncated"]
                expected
                publicBytes
                (signPayload secret public truncatedByteLengthPayload)
                bundle
        , let badMagicPayload = replaceByteAt 0 0 payload
           in expectRefused
                "authenticated bad payload magic"
                [wireMalformed "missing exact v2 payload magic"]
                expected
                publicBytes
                (signPayload secret public badMagicPayload)
                bundle
        , let emptyWire = signPrefix rfc8032Secret rfc8032Public (wirePrefixWithPayload ByteString.empty)
           in expectRefused
                "authenticated empty payload reaches decoding only after signature verification"
                [wireMalformed "missing exact v2 payload magic"]
                expected
                rfc8032PublicKey
                emptyWire
                ByteString.empty
                <> expectRefused
                  "corrupted empty-payload signature refuses before decoding"
                  [signatureInvalid]
                  expected
                  rfc8032PublicKey
                  (corruptSignature emptyWire)
                  ByteString.empty
        , let rawCustodyNine = replaceByteAt (custodyOffset base) 9 payload
           in expectRefused
                "unsupported custody tag"
                [ envelopeProblem
                    "SOURCE-ACQUISITION-CUSTODY"
                    (shown1 "SourceAcquisitionCustodyUnsupported" (9 :: Word8))
                ]
                expected
                publicBytes
                (signPayload secret public rawCustodyNine)
                bundle
        , let rawFormatNine = replaceByteAt (objectFormatOffset base) 9 payload
           in expectRefused
                "unsupported object-format tag"
                [ envelopeProblem
                    "SOURCE-ACQUISITION-OBJECT-FORMAT"
                    (shown1 "SourceAcquisitionObjectFormatUnsupported" (9 :: Word8))
                ]
                expected
                publicBytes
                (signPayload secret public rawFormatNine)
                bundle
        , let rawModeNine = replaceByteAt (firstModeOffset base) 9 payload
              path = oracleEntryPath (fst firstMember)
           in expectRefused
                "unsupported entry-mode tag"
                [ pathProblem
                    "SOURCE-ACQUISITION-MODE"
                    path
                    (shown2 "SourceAcquisitionEntryModeUnsupported" path (9 :: Word8))
                ]
                expected
                publicBytes
                (signPayload secret public rawModeNine)
                bundle
        , let maximumSizedWire =
                envelopeMagic
                  <> "16777216\n"
                  <> ByteString.replicate 16777216 0
                  <> ByteString.replicate 64 0
           in expectRefused
                "inclusive 16 MiB payload and envelope limits reach key validation"
                [publicKeyInvalid]
                expected
                (ByteString.replicate 31 0)
                maximumSizedWire
                bundle
        , let maximumSizedBundle = ByteString.replicate 33554432 0
           in expectRefused
                "inclusive 32 MiB bundle limit reaches key validation"
                [publicKeyInvalid]
                expected
                (ByteString.replicate 31 0)
                cleanWire
                maximumSizedBundle
                <> expectRefused
                  "bundle overflow precedes signature and payload decoding"
                  [ envelopeProblem
                      "SOURCE-ACQUISITION-BUNDLE-LIMIT"
                      (shown1 "SourceAcquisitionBundleTooLarge" (33554433 :: Int))
                  ]
                  expected
                  publicBytes
                  (corruptSignature (signPayload secret public (replaceByteAt 0 0 payload)))
                  (maximumSizedBundle <> "x")
        , let maximumFieldPayload =
                payloadMagic
                  <> word32Literal 4096
                  <> ByteString.replicate 4096 97
           in expectRefused
                "inclusive 4096-byte field reaches following-field framing"
                [wireMalformed "authority-length is truncated"]
                expected
                publicBytes
                (signPayload secret public maximumFieldPayload)
                bundle
        , let maximumCountPayload =
                ByteString.take (entryCountOffset base) payload <> word32Literal 16384
           in expectRefused
                "inclusive 16384-entry count reaches first-entry framing"
                [wireMalformed "entry-path-length is truncated"]
                expected
                publicBytes
                (signPayload secret public maximumCountPayload)
                bundle
        , let (entry, bytes) = firstMember
              maximumEntry = entry {oracleEntryByteLength = 33554432}
              maximumEntryFixture = deriveFixture base [(maximumEntry, bytes)]
           in expectRefused
                "inclusive 32 MiB declared member reaches aggregate-length binding"
                [ envelopeProblem
                    "SOURCE-ACQUISITION-LENGTH"
                    ( shown2
                        "SourceAcquisitionBundleLengthMismatch"
                        (33554432 :: Integer)
                        (toInteger (ByteString.length bytes))
                    )
                ]
                (alignFullExpectation (fixtureManifest maximumEntryFixture) expected)
                publicBytes
                (signFixture secret public maximumEntryFixture)
                (fixtureBundle maximumEntryFixture)
        ]
 where
  base = fixtureManifest fixture
  members = fixtureMembers fixture
  bundle = fixtureBundle fixture
  payload = oracleManifestBytes base
  wireMalformed detail =
    envelopeProblem
      "SOURCE-ACQUISITION-WIRE"
      (shown1 "SourceAcquisitionWireMalformed" (detail :: Text))
  publicKeyInvalid =
    envelopeProblem
      "SOURCE-ACQUISITION-PUBLIC-KEY"
      (shown0 "SourceAcquisitionPublicKeyInvalid")
  signatureInvalid =
    envelopeProblem
      "SOURCE-ACQUISITION-SIGNATURE"
      (shown0 "SourceAcquisitionSignatureInvalid")

manualFixture
  :: OracleManifest
  -> [(OracleEntry, ByteString)]
  -> OracleFixture
manualFixture template members =
  OracleFixture
    (template {oracleEntries = map fst members})
    members
    (ByteString.concat (map snd members))

singlePathFixture
  :: OracleManifest
  -> (OracleEntry, ByteString)
  -> FilePath
  -> OracleFixture
singlePathFixture template (entry, bytes) path =
  deriveFixture template [(entry {oracleEntryPath = path}, bytes)]

modifyFirstEntry
  :: (OracleEntry -> OracleEntry)
  -> [(OracleEntry, ByteString)]
  -> [(OracleEntry, ByteString)]
modifyFirstEntry change members = case members of
  [] -> []
  (entry, bytes) : rest -> (change entry, bytes) : rest

replaceFirstMemberPath
  :: FilePath
  -> [(OracleEntry, ByteString)]
  -> [(OracleEntry, ByteString)]
replaceFirstMemberPath path =
  modifyFirstEntry (\entry -> entry {oracleEntryPath = path})

differentGitIdentity :: OracleManifest -> Text
differentGitIdentity manifest =
  Text.replicate (objectIdentityWidth (oracleObjectFormat manifest)) "f"

objectIdentityWidth :: OracleObjectFormat -> Int
objectIdentityWidth OracleObjectSha1 = 40
objectIdentityWidth OracleObjectSha256 = 64

withRecomputedFrozen :: OracleManifest -> OracleManifest
withRecomputedFrozen manifest =
  manifest
    { oracleFrozenSnapshotIdentityField =
        oracleFrozenSnapshotIdentity manifest
    }

leadingZeroLengthPrefix :: ByteString -> ByteString
leadingZeroLengthPrefix prefix =
  case ByteString.stripPrefix envelopeMagic prefix of
    Nothing -> prefix
    Just afterMagic ->
      let (lengthBytes, rest) = ByteString.break (== 10) afterMagic
       in envelopeMagic <> "0" <> lengthBytes <> rest

plusPrefixedLength :: ByteString -> ByteString
plusPrefixedLength wire =
  case ByteString.stripPrefix envelopeMagic wire of
    Nothing -> wire
    Just afterMagic -> envelopeMagic <> "+" <> afterMagic

corruptSignature :: ByteString -> ByteString
corruptSignature wire
  | ByteString.null wire = wire
  | otherwise =
      replaceByteAt
        (ByteString.length wire - 1)
        (ByteString.last wire `xor` 1)
        wire

replaceSignatureWith :: ByteString -> ByteString -> ByteString
replaceSignatureWith wire signatureBytes =
  ByteString.dropEnd 64 wire <> signatureBytes

replaceByteAt :: Int -> Word8 -> ByteString -> ByteString
replaceByteAt offset replacement bytes =
  ByteString.take offset bytes
    <> ByteString.singleton replacement
    <> ByteString.drop (offset + 1) bytes

word32Literal :: Word32 -> ByteString
word32Literal value =
  LazyByteString.toStrict (toLazyByteString (word32BE value))

payloadMagicLength :: Int
payloadMagicLength = ByteString.length payloadMagic

objectFormatOffset :: OracleManifest -> Int
objectFormatOffset manifest = custodyOffset manifest + 1

custodyOffset :: OracleManifest -> Int
custodyOffset manifest =
  payloadMagicLength + sum (map sizedTextLength firstFields)
 where
  firstFields =
    [ oraclePhase manifest
    , oracleAuthority manifest
    , oracleObserverToolDigest manifest
    , oracleChallenge manifest
    , oracleReplayIdentity manifest
    , oracleRepositoryIdentity manifest
    , oracleRequestedRevision manifest
    ]

firstModeOffset :: OracleManifest -> Int
firstModeOffset manifest =
  payloadMagicLength
    + sum (map sizedTextLength firstFields)
    + 2
    + sum (map sizedTextLength identityFields)
    + sizedBytesLength (oracleCommitBytes manifest)
    + 4
    + case oracleEntries manifest of
      [] -> 0
      firstEntry : _ -> sizedTextLength (Text.pack (oracleEntryPath firstEntry))
 where
  firstFields =
    [ oraclePhase manifest
    , oracleAuthority manifest
    , oracleObserverToolDigest manifest
    , oracleChallenge manifest
    , oracleReplayIdentity manifest
    , oracleRepositoryIdentity manifest
    , oracleRequestedRevision manifest
    ]
  identityFields =
    [ oracleHeadIdentity manifest
    , oracleTreeIdentityField manifest
    , oracleAuthoredRootIdentityField manifest
    , oracleFrozenSnapshotIdentityField manifest
    , oracleBundleIdentityField manifest
    , oracleSourceSnapshotIdentityField manifest
    ]

entryCountOffset :: OracleManifest -> Int
entryCountOffset manifest =
  payloadMagicLength
    + sum (map sizedTextLength firstFields)
    + 2
    + sum (map sizedTextLength identityFields)
    + sizedBytesLength (oracleCommitBytes manifest)
 where
  firstFields =
    [ oraclePhase manifest
    , oracleAuthority manifest
    , oracleObserverToolDigest manifest
    , oracleChallenge manifest
    , oracleReplayIdentity manifest
    , oracleRepositoryIdentity manifest
    , oracleRequestedRevision manifest
    ]
  identityFields =
    [ oracleHeadIdentity manifest
    , oracleTreeIdentityField manifest
    , oracleAuthoredRootIdentityField manifest
    , oracleFrozenSnapshotIdentityField manifest
    , oracleBundleIdentityField manifest
    , oracleSourceSnapshotIdentityField manifest
    ]

sizedTextLength :: Text -> Int
sizedTextLength value = 4 + ByteString.length (TextEncoding.encodeUtf8 value)

sizedBytesLength :: ByteString -> Int
sizedBytesLength bytes = 4 + ByteString.length bytes

oracleSourceSnapshotIdentity
  :: OracleObjectFormat
  -> [(OracleEntry, ByteString)]
  -> Text
oracleSourceSnapshotIdentity objectFormat members =
  oracleSha256
    ( "amoebius-source-snapshot-v2\0"
        <> TextEncoding.encodeUtf8 (oracleRenderObjectFormat objectFormat)
        <> "\0"
        <> ByteString.concat (map renderMember ordered)
    )
 where
  ordered =
    sortBy
      (\left right -> compare (oracleEntryPath (fst left)) (oracleEntryPath (fst right)))
      members
  renderMember (entry, bytes) =
    TextEncoding.encodeUtf8
      ( oracleRenderMode (oracleEntryMode entry)
          <> "\0"
          <> oracleEntryGitObjectId entry
          <> "\0"
          <> oracleSha256 bytes
          <> "\0"
          <> Text.pack (oracleEntryPath entry)
          <> "\0"
      )

oracleFrozenSnapshotIdentity :: OracleManifest -> Text
oracleFrozenSnapshotIdentity manifest =
  oracleSha256
    ( TextEncoding.encodeUtf8
        ( "amoebius-frozen-source-bundle-v2\0"
            <> oracleRenderCustody (oracleCustody manifest)
            <> "\0"
            <> oracleRepositoryIdentity manifest
            <> "\0"
            <> oracleRequestedRevision manifest
            <> "\0"
            <> oracleRenderObjectFormat (oracleObjectFormat manifest)
            <> "\0"
            <> oracleHeadIdentity manifest
            <> "\0"
            <> oracleTreeIdentityField manifest
            <> "\0"
            <> oracleAuthoredRootIdentityField manifest
            <> "\0"
            <> oracleBundleIdentityField manifest
            <> "\0"
            <> oracleSourceSnapshotIdentityField manifest
            <> "\0"
        )
    )

data OracleTreeChild
  = OracleBlob OracleMode Text
  | OracleDirectory (Map ByteString OracleTreeChild)

oracleTreeIdentity :: OracleObjectFormat -> [OracleEntry] -> Text
oracleTreeIdentity objectFormat entries =
  oracleHashTree objectFormat (foldl' insert Map.empty entries)
 where
  insert tree entry =
    oracleInsert
      (map TextEncoding.encodeUtf8 (Text.splitOn "/" (Text.pack (oracleEntryPath entry))))
      (OracleBlob (oracleEntryMode entry) (oracleEntryGitObjectId entry))
      tree

oracleInsert
  :: [ByteString]
  -> OracleTreeChild
  -> Map ByteString OracleTreeChild
  -> Map ByteString OracleTreeChild
oracleInsert parts leaf tree = case parts of
  [] -> tree
  [name] -> Map.insert name leaf tree
  name : rest ->
    let child = case Map.lookup name tree of
          Just (OracleDirectory found) -> found
          _ -> Map.empty
     in Map.insert name (OracleDirectory (oracleInsert rest leaf child)) tree

oracleHashTree :: OracleObjectFormat -> Map ByteString OracleTreeChild -> Text
oracleHashTree objectFormat tree =
  oracleGitObjectIdentity objectFormat "tree" (ByteString.concat (map render ordered))
 where
  ordered = sortBy (\left right -> compare (key left) (key right)) (Map.toList tree)
  key (name, OracleDirectory _) = name <> "/"
  key (name, OracleBlob _ _) = name
  render (name, child) = case child of
    OracleBlob mode objectId ->
      TextEncoding.encodeUtf8 (oracleRenderMode mode)
        <> " "
        <> name
        <> "\0"
        <> oracleDecodeHex objectId
    OracleDirectory descendants ->
      "40000 "
        <> name
        <> "\0"
        <> oracleDecodeHex (oracleHashTree objectFormat descendants)

oracleGitObjectIdentity
  :: OracleObjectFormat
  -> ByteString
  -> ByteString
  -> Text
oracleGitObjectIdentity objectFormat kind payload = case objectFormat of
  OracleObjectSha1 -> Text.pack (show (Crypto.hash framed :: Crypto.Digest Crypto.SHA1))
  OracleObjectSha256 -> Text.pack (show (Crypto.hash framed :: Crypto.Digest Crypto.SHA256))
 where
  framed = kind <> " " <> ByteString8.pack (show (ByteString.length payload)) <> "\0" <> payload

oracleSha256 :: ByteString -> Text
oracleSha256 bytes = Text.pack (show (Crypto.hash bytes :: Crypto.Digest Crypto.SHA256))

oracleDecodeHex :: Text -> ByteString
oracleDecodeHex = ByteString.pack . go . Text.unpack
 where
  go [] = []
  go (high : low : rest) = fromIntegral (value high * 16 + value low) : go rest
  go _ = error "oracle fixture contains an odd-length hexadecimal value"
  value character
    | character >= '0' && character <= '9' = fromEnum character - fromEnum '0'
    | character >= 'a' && character <= 'f' = 10 + fromEnum character - fromEnum 'a'
    | otherwise = error "oracle fixture contains a non-lowercase-hex value"

oracleEncodeHex :: ByteString -> Text
oracleEncodeHex = Text.pack . concatMap encodeByte . ByteString.unpack
 where
  encodeByte byte =
    [ intToDigit (fromIntegral byte `div` 16)
    , intToDigit (fromIntegral byte `mod` 16)
    ]

oracleRenderMode :: OracleMode -> Text
oracleRenderMode OracleRegularFile = "100644"
oracleRenderMode OracleExecutableFile = "100755"
oracleRenderMode OracleSymbolicLink = "120000"

oracleRenderObjectFormat :: OracleObjectFormat -> Text
oracleRenderObjectFormat OracleObjectSha1 = "sha1"
oracleRenderObjectFormat OracleObjectSha256 = "sha256"

oracleRenderCustody :: OracleCustody -> Text
oracleRenderCustody OracleFrozenReadOnlyBundle = "externally-frozen-read-only-bundle"
oracleRenderCustody OracleSequentialMutableBundle = "sequential-mutable-bundle"

expectEqual :: (Eq value, Show value) => String -> value -> value -> [ExactCase]
expectEqual label expected actual =
  [ ExactCase
      label
      [label <> ": expected " <> show expected <> ", observed " <> show actual | expected /= actual]
  ]

unlinesWith :: String -> [String] -> String
unlinesWith _ [] = ""
unlinesWith separator (first : rest) = first <> concatMap (separator <>) rest
