{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PackageImports #-}

module SourceAcquisitionInternalOracle
  ( runSourceAcquisitionInternalOracle
  , runSourceAcquisitionInternalSelectorOracle
  , sourceAcquisitionInternalSelectorIntents
  , sourceAcquisitionInternalSelectorNames
  ) where

-- Direct-source oracle for the package-hidden authority-to-snapshot handoff.
-- The signed fixture grammar remains oracle-local in SourceAcquisitionOracle;
-- production contributes only its bounded session adapter and verifier.

import Amoebius.Validation.SourceAcquisition.Internal
  ( AnchoredSourceAcquisitionSession
  , acquireExternallyVerifiedSourceSnapshot
  , acquireExternallyVerifiedSourceSnapshotFromIngress
  , acquireExternallyVerifiedSourceSnapshotFromReservedIngress
  , anchorSourceAcquisitionSession
  , sourceAcquisitionInternalTestFinalize
  , sourceAcquisitionInternalTestTrackedEntries
  )
import Amoebius.Validation.SourceClosure.Internal
  ( AcquiredSourceSnapshot
  , GitObjectFormat (GitObjectSha1)
  , IndexEntry (indexPath)
  , IndexMode (..)
  , SourceSnapshot (..)
  , TrackedEntry (..)
  , acquiredSourceSnapshot
  )
import Amoebius.Validation.Types (CheckResult (..), Finding (..), Observation (..))
import Control.Monad (unless)
import "crypton" Crypto.Hash qualified as Crypto
import Data.Bits (xor)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteString8
import Data.List (group, sort)
import Data.Set qualified as Set
import Data.Text qualified as Text
import Data.Word (Word64, Word8)
import SourceAcquisitionOracle
  ( CanonicalAcquisitionEntry (..)
  , CanonicalAcquisitionInputs (..)
  , canonicalAcquisitionInputs
  , runSourceAcquisitionCanonicalControl
  )

runSourceAcquisitionInternalOracle :: IO ()
runSourceAcquisitionInternalOracle = do
  inputs <- canonicalAcquisitionInputs
  let cases = sourceAcquisitionInternalExactCases inputs
      problems =
        selectorRegistryProblems cases
          <> concatMap snd cases
  unless
    (null problems)
    ( fail
        ( "SourceAcquisitionInternalOracle component diagnostic failures:\n  "
            <> unlinesWith "\n  " problems
        )
    )

runSourceAcquisitionInternalSelectorOracle :: String -> IO ()
runSourceAcquisitionInternalSelectorOracle selector = do
  inputs <- canonicalAcquisitionInputs
  let cases = sourceAcquisitionInternalExactCases inputs
      matching =
        [ caseProblems
        | target <- selectorTargets selector
        , (label, caseProblems) <- cases
        , label == target
        ]
      problems =
        selectorRegistryProblems cases
          <> case matching of
            [targetProblems] -> targetProblems
            targets ->
              [ "internal selector intent is not exactly resolvable: selector="
                  <> selector
                  <> "; count="
                  <> show (length targets)
              ]
  runSourceAcquisitionCanonicalControl
  unless
    (null problems)
    ( fail
        ( "SourceAcquisitionInternalOracle selector diagnostic failures:\n  "
            <> unlinesWith "\n  " problems
        )
    )

sourceAcquisitionInternalSelectorIntents :: [(String, String)]
sourceAcquisitionInternalSelectorIntents =
  [ ("VALIDATION_SOURCE_ACQUISITION_ANCHORED_PHASE_MAPPING_MUTANT", "anchored session phase mapping is exact")
  , ("VALIDATION_SOURCE_ACQUISITION_ANCHORED_AUTHORITY_MAPPING_MUTANT", "anchored session authority mapping is exact")
  , ("VALIDATION_SOURCE_ACQUISITION_ANCHORED_OBSERVER_TOOL_MAPPING_MUTANT", "anchored session observer mapping is exact")
  , ("VALIDATION_SOURCE_ACQUISITION_ANCHORED_CHALLENGE_MAPPING_MUTANT", "anchored session challenge mapping is exact")
  , ("VALIDATION_SOURCE_ACQUISITION_ANCHORED_REPLAY_SET_MAPPING_MUTANT", "anchored session replay-set mapping is exact")
  , ("VALIDATION_SOURCE_ACQUISITION_ANCHORED_REPOSITORY_MAPPING_MUTANT", "anchored session repository mapping is exact")
  , ("VALIDATION_SOURCE_ACQUISITION_ANCHORED_REQUESTED_REVISION_MAPPING_MUTANT", "anchored session revision mapping is exact")
  , ("VALIDATION_SOURCE_ACQUISITION_ANCHORED_HEAD_MAPPING_MUTANT", "anchored session HEAD mapping is exact")
  , ("VALIDATION_SOURCE_ACQUISITION_ANCHORED_SOURCE_SNAPSHOT_MAPPING_MUTANT", "anchored session source identity mapping is exact")
  , ("VALIDATION_SOURCE_ACQUISITION_ANCHORED_AUTHORED_ROOT_MAPPING_MUTANT", "anchored session authored-root mapping is exact")
  , ("VALIDATION_SOURCE_ACQUISITION_ANCHORED_EXPECTED_MANIFEST_MAPPING_MUTANT", "anchored expected-manifest mapping is exact")
  , ("VALIDATION_SOURCE_ACQUISITION_ANCHORED_EXPECTED_MANIFEST_TRANSPORT_JOIN_BYPASS_MUTANT", "streamed expected-manifest bytes join the anchored session")
  , ("VALIDATION_SOURCE_ACQUISITION_ANCHORED_RESERVED_REPLAY_IDENTITY_JOIN_BYPASS_MUTANT", "reserved replay identity joins the signed manifest")
  , ("VALIDATION_SOURCE_ACQUISITION_ANCHORED_PUBLIC_KEY_MAPPING_MUTANT", "anchored public-key mapping is exact")
  , ("VALIDATION_SOURCE_ACQUISITION_ANCHORED_WIRE_ROUTE_MUTANT", "anchored signed-wire route is exact")
  , ("VALIDATION_SOURCE_ACQUISITION_ANCHORED_BUNDLE_ROUTE_MUTANT", "anchored immutable-bundle route is exact")
  , ("VALIDATION_SOURCE_ACQUISITION_ANCHORED_VERIFICATION_REFUSAL_BYPASS_MUTANT", "verification refusal cannot mint an acquired snapshot")
  , ("VALIDATION_SOURCE_ACQUISITION_ANCHORED_VERIFICATION_SUCCESS_ROUTE_MUTANT", "verified success reaches the handoff")
  , ("VALIDATION_SOURCE_ACQUISITION_HANDOFF_OBJECT_FORMAT_MAPPING_MUTANT", "handoff object-format mapping is exact")
  , ("VALIDATION_SOURCE_ACQUISITION_HANDOFF_CONTENT_ASSOCIATION_MUTANT", "handoff content association is exact")
  , ("VALIDATION_SOURCE_ACQUISITION_HANDOFF_CONSTRUCTION_ORDER_MUTANT", "handoff construction order is exact")
  , ("VALIDATION_SOURCE_ACQUISITION_HANDOFF_SPLIT_FAILURE_BYPASS_MUTANT", "handoff split failure is retained")
  , ("VALIDATION_SOURCE_ACQUISITION_HANDOFF_SPLIT_SUCCESS_ROUTE_MUTANT", "handoff split success is retained")
  , ("VALIDATION_SOURCE_ACQUISITION_HANDOFF_CONTENT_PROBLEM_BYPASS_MUTANT", "handoff content problems are retained")
  , ("VALIDATION_SOURCE_ACQUISITION_HANDOFF_ENTRY_ORDER_MUTANT", "handoff entry order is exact")
  , ("VALIDATION_SOURCE_ACQUISITION_HANDOFF_ENTRY_PATH_MAPPING_MUTANT", "handoff entry path mapping is exact")
  , ("VALIDATION_SOURCE_ACQUISITION_HANDOFF_ENTRY_MODE_MAPPING_MUTANT", "handoff entry mode mapping is exact")
  , ("VALIDATION_SOURCE_ACQUISITION_HANDOFF_ENTRY_OBJECT_MAPPING_MUTANT", "handoff entry object mapping is exact")
  , ("VALIDATION_SOURCE_ACQUISITION_HANDOFF_ENTRY_BYTES_MAPPING_MUTANT", "handoff entry bytes mapping is exact")
  , ("VALIDATION_SOURCE_ACQUISITION_HANDOFF_IDENTITY_JOIN_BYPASS_MUTANT", "handoff identity mismatch refuses construction")
  , ("VALIDATION_SOURCE_ACQUISITION_HANDOFF_SNAPSHOT_ROOT_MAPPING_MUTANT", "handoff snapshot root mapping is exact")
  , ("VALIDATION_SOURCE_ACQUISITION_HANDOFF_SNAPSHOT_IDENTITY_MAPPING_MUTANT", "handoff snapshot identity mapping is exact")
  , ("VALIDATION_SOURCE_ACQUISITION_HANDOFF_SNAPSHOT_ENTRIES_MAPPING_MUTANT", "handoff snapshot entries mapping is exact")
  ]

sourceAcquisitionInternalSelectorNames :: [String]
sourceAcquisitionInternalSelectorNames = map fst sourceAcquisitionInternalSelectorIntents

sourceAcquisitionInternalExactCases
  :: CanonicalAcquisitionInputs
  -> [(String, [String])]
sourceAcquisitionInternalExactCases inputs =
  [ (label, acquiredSnapshotProblems inputs)
  | label <- canonicalHandoffLabels
  ]
    <> [ ("anchored session replay-set mapping is exact", replayReservationProblems inputs)
       , ("verification refusal cannot mint an acquired snapshot", corruptSignatureProblems inputs)
       , ("streamed expected-manifest bytes join the anchored session", expectedManifestTransportJoinProblems inputs)
       , ("reserved replay identity joins the signed manifest", reservedReplayIdentityJoinProblems inputs)
       , ("handoff identity mismatch refuses construction", handoffIdentityJoinProblems inputs)
       , ("handoff split failure is retained", handoffSplitFailureProblems inputs)
       , ("handoff content problems are retained", handoffContentProblemRetentionProblems inputs)
       , ("anchored challenge mismatch remains an exact paired negative", challengeBindingProblems inputs)
       ]

canonicalHandoffLabels :: [String]
canonicalHandoffLabels =
  [ "anchored session phase mapping is exact"
  , "anchored session authority mapping is exact"
  , "anchored session observer mapping is exact"
  , "anchored session challenge mapping is exact"
  , "anchored session repository mapping is exact"
  , "anchored session revision mapping is exact"
  , "anchored session HEAD mapping is exact"
  , "anchored session source identity mapping is exact"
  , "anchored session authored-root mapping is exact"
  , "anchored expected-manifest mapping is exact"
  , "anchored public-key mapping is exact"
  , "anchored signed-wire route is exact"
  , "anchored immutable-bundle route is exact"
  , "handoff object-format mapping is exact"
  , "verified success reaches the handoff"
  , "handoff content association is exact"
  , "handoff construction order is exact"
  , "handoff split success is retained"
  , "handoff entry order is exact"
  , "handoff entry path mapping is exact"
  , "handoff entry mode mapping is exact"
  , "handoff entry object mapping is exact"
  , "handoff entry bytes mapping is exact"
  , "handoff snapshot root mapping is exact"
  , "handoff snapshot identity mapping is exact"
  , "handoff snapshot entries mapping is exact"
  ]

selectorTargets :: String -> [String]
selectorTargets selector =
  [ target
  | (candidate, target) <- sourceAcquisitionInternalSelectorIntents
  , candidate == selector
  ]

selectorRegistryProblems :: [(String, [String])] -> [String]
selectorRegistryProblems cases =
  [ "internal selector registry cardinality changed: expected=33; observed="
      <> show (length sourceAcquisitionInternalSelectorIntents)
  | length sourceAcquisitionInternalSelectorIntents /= 33
  ]
    <> duplicateProblems "internal selector" sourceAcquisitionInternalSelectorNames
    <> duplicateProblems "internal selector target" (map snd sourceAcquisitionInternalSelectorIntents)
    <> duplicateProblems "internal exact-case label" (map fst cases)
    <> [ "internal selector target is absent: " <> target
       | target <- map snd sourceAcquisitionInternalSelectorIntents
       , target `notElem` map fst cases
       ]

duplicateProblems :: String -> [String] -> [String]
duplicateProblems kind values =
  [ kind <> " is duplicated: " <> value
  | valuesAtGroup <- group (sort values)
  , value : _ <- [valuesAtGroup]
  , length valuesAtGroup > 1
  ]

acquiredSnapshotProblems :: CanonicalAcquisitionInputs -> [String]
acquiredSnapshotProblems inputs =
  case acquireExternallyVerifiedSourceSnapshot (canonicalSession inputs Set.empty) (canonicalInputWireBytes inputs) (canonicalInputBundleBytes inputs) of
    Left result -> ["canonical anchored bundle was refused: " <> show result]
    Right acquired ->
      let snapshot = acquiredSourceSnapshot acquired
       in expectEqual "acquired snapshot identity" (canonicalInputSourceSnapshotIdentity inputs) (snapshotIdentity snapshot)
            <> expectEqual "acquired snapshot path order" (canonicalInputExpectedPaths inputs) (map (indexPath . trackedIndex) (snapshotEntries snapshot))
            <> expectEqual "acquired snapshot exact bundle bytes" (canonicalInputBundleBytes inputs) (ByteString.concat (map trackedBytes (snapshotEntries snapshot)))
            <> expectEqual
              "acquired snapshot synthetic immutable root"
              ( "<externally-frozen-source-bundle:"
                  <> Text.unpack (canonicalInputRepositoryIdentity inputs)
                  <> ">"
              )
              (snapshotRoot snapshot)

corruptSignatureProblems :: CanonicalAcquisitionInputs -> [String]
corruptSignatureProblems inputs =
  expectEqual
    "changed signature is refused before acquired construction"
    signatureRefusal
    ( acquireExternallyVerifiedSourceSnapshot
        (canonicalSession inputs Set.empty)
        (corruptLastByte (canonicalInputWireBytes inputs))
        (canonicalInputBundleBytes inputs)
    )

expectedManifestTransportJoinProblems :: CanonicalAcquisitionInputs -> [String]
expectedManifestTransportJoinProblems inputs =
  expectEqual
    "streamed expected-manifest bytes must equal the anchored bytes"
    ( Left
        CheckResult
          { checkName = "source-acquisition"
          , checkObservations = [Observation "source-acquisition.integrity" "refused with 1 integrity finding(s)"]
          , checkFindings =
              [ Finding
                  "SOURCE-ACQUISITION-EXPECTED-MANIFEST-WIRE"
                  "source-acquisition-envelope"
                  ( "SourceAcquisitionExpectedManifestMalformed "
                      <> Text.pack
                        ( show
                            ( "streamed expected-manifest bytes differ from the externally anchored session"
                                :: String
                            )
                        )
                  )
              ]
          }
    )
    ( acquireExternallyVerifiedSourceSnapshotFromIngress
        (canonicalSession inputs Set.empty)
        (ByteString.drop 1 (canonicalInputExpectedManifestBytes inputs))
        (canonicalInputWireBytes inputs)
        (canonicalInputBundleBytes inputs)
    )

reservedReplayIdentityJoinProblems :: CanonicalAcquisitionInputs -> [String]
reservedReplayIdentityJoinProblems inputs =
  expectEqual
    "reserved replay identity must equal the authenticated identity"
    ( Left
        CheckResult
          { checkName = "source-acquisition"
          , checkObservations = [Observation "source-acquisition.integrity" "refused with 1 integrity finding(s)"]
          , checkFindings =
              [ Finding
                  "SOURCE-ACQUISITION-REPLAY"
                  "source-acquisition-envelope"
                  ( "SourceAcquisitionReplayIdentityMalformed "
                      <> Text.pack
                        ( show
                            ( "reserved replay identity differs from the signed replay identity"
                                :: String
                            )
                        )
                  )
              ]
          }
    )
    ( acquireExternallyVerifiedSourceSnapshotFromReservedIngress
        (canonicalSession inputs Set.empty)
        (replaceFirstHex (canonicalInputReplayIdentity inputs))
        (canonicalInputExpectedManifestBytes inputs)
        (canonicalInputWireBytes inputs)
        (canonicalInputBundleBytes inputs)
    )

challengeBindingProblems :: CanonicalAcquisitionInputs -> [String]
challengeBindingProblems inputs =
  expectEqual
    "anchored challenge must join the signed challenge"
    ( Left
        CheckResult
          { checkName = "source-acquisition"
          , checkObservations = [Observation "source-acquisition.integrity" "refused with 1 integrity finding(s)"]
          , checkFindings =
              [ Finding
                  "SOURCE-ACQUISITION-CHALLENGE"
                  "source-acquisition-envelope"
                  ( "SourceAcquisitionChallengeMismatch "
                      <> Text.pack (show changedChallenge)
                      <> " "
                      <> Text.pack (show (canonicalInputChallenge inputs))
                  )
              ]
          }
    )
    ( acquireExternallyVerifiedSourceSnapshot
        (canonicalSessionWithChallenge inputs changedChallenge Set.empty)
        (canonicalInputWireBytes inputs)
        (canonicalInputBundleBytes inputs)
    )
 where
  changedChallenge = replaceFirstHex (canonicalInputChallenge inputs)

replayReservationProblems :: CanonicalAcquisitionInputs -> [String]
replayReservationProblems inputs =
  expectEqual
    "durably consumed replay identity refuses acquired construction"
    ( Left
        CheckResult
          { checkName = "source-acquisition"
          , checkObservations = [Observation "source-acquisition.integrity" "refused with 1 integrity finding(s)"]
          , checkFindings =
              [ Finding
                  "SOURCE-ACQUISITION-REPLAY"
                  "source-acquisition-envelope"
                  ( "SourceAcquisitionReplayDetected "
                      <> Text.pack (show (canonicalInputReplayIdentity inputs))
                  )
              ]
          }
    )
    ( acquireExternallyVerifiedSourceSnapshot
        (canonicalSession inputs (Set.singleton (canonicalInputReplayIdentity inputs)))
        (canonicalInputWireBytes inputs)
        (canonicalInputBundleBytes inputs)
    )

handoffIdentityJoinProblems :: CanonicalAcquisitionInputs -> [String]
handoffIdentityJoinProblems inputs =
  case acquireExternallyVerifiedSourceSnapshot (canonicalSession inputs Set.empty) (canonicalInputWireBytes inputs) (canonicalInputBundleBytes inputs) of
    Left result -> ["canonical setup for handoff identity negative was refused: " <> show result]
    Right acquired ->
      let snapshot = acquiredSourceSnapshot acquired
          changedIdentity = replaceFirstHex (snapshotIdentity snapshot)
       in expectEqual
            "changed handoff identity"
            ( Left
                CheckResult
                  { checkName = "source-acquisition"
                  , checkObservations = [Observation "source-acquisition.integrity" "refused with 1 integrity finding(s)"]
                  , checkFindings =
                      [ Finding
                          "SOURCE-ACQUISITION-SOURCE-SNAPSHOT"
                          "source-acquisition-envelope"
                          ( "SourceAcquisitionSourceSnapshotIdentityMismatch "
                              <> Text.pack (show changedIdentity)
                              <> " "
                              <> Text.pack (show (snapshotIdentity snapshot))
                          )
                      ]
                  }
            )
            ( sourceAcquisitionInternalTestFinalize
                GitObjectSha1
                (canonicalInputRepositoryIdentity inputs)
                changedIdentity
                (snapshotEntries snapshot)
            )

handoffSplitFailureProblems :: CanonicalAcquisitionInputs -> [String]
handoffSplitFailureProblems inputs =
  let bundle = canonicalInputBundleBytes inputs
      shortened = ByteString.dropEnd 1 bundle
      expectedLength = ByteString.length bundle
      actualLength = ByteString.length shortened
   in expectEqual
        "handoff split length refusal"
        ( Left
            CheckResult
              { checkName = "source-acquisition"
              , checkObservations = [Observation "source-acquisition.integrity" "refused with 1 integrity finding(s)"]
              , checkFindings =
                  [ Finding
                      "SOURCE-ACQUISITION-LENGTH"
                      "source-acquisition-envelope"
                      ( "SourceAcquisitionBundleLengthMismatch "
                          <> Text.pack (show expectedLength)
                          <> " "
                          <> Text.pack (show actualLength)
                      )
                  ]
              }
        )
        (sourceAcquisitionInternalTestTrackedEntries (canonicalEntryTuples inputs) shortened)

handoffContentProblemRetentionProblems :: CanonicalAcquisitionInputs -> [String]
handoffContentProblemRetentionProblems inputs =
  case canonicalInputEntries inputs of
    [] -> ["canonical content-retention fixture is empty"]
    firstEntry : _ ->
      let bundle = canonicalInputBundleBytes inputs
          changedBundle = replaceByteAt 0 (ByteString.head bundle `xor` 1) bundle
          firstLength = fromIntegral (canonicalEntryByteLength firstEntry)
          changedFirstBytes = ByteString.take firstLength changedBundle
          expectedObject = canonicalEntryGitObjectId firstEntry
          actualObject = sha1 ("blob " <> ByteString8.pack (show firstLength) <> "\0" <> changedFirstBytes)
          expectedBlob = canonicalEntryBlobSha256 firstEntry
          actualBlob = sha256 changedFirstBytes
          path = canonicalEntryPath firstEntry
       in expectEqual
            "handoff content refusals"
            ( Left
                CheckResult
                  { checkName = "source-acquisition"
                  , checkObservations = [Observation "source-acquisition.integrity" "refused with 2 integrity finding(s)"]
                  , checkFindings =
                      [ Finding
                          "SOURCE-ACQUISITION-GIT-OID"
                          path
                          ( "SourceAcquisitionEntryGitObjectMismatch "
                              <> Text.pack (show path)
                              <> " (LoadedBlobObjectIdMismatch "
                              <> Text.pack (show expectedObject)
                              <> " "
                              <> Text.pack (show actualObject)
                              <> ")"
                          )
                      , Finding
                          "SOURCE-ACQUISITION-BLOB-SHA256"
                          path
                          ( "SourceAcquisitionEntryBlobSha256Mismatch "
                              <> Text.pack (show path)
                              <> " "
                              <> Text.pack (show expectedBlob)
                              <> " "
                              <> Text.pack (show actualBlob)
                          )
                      ]
                  }
            )
            (sourceAcquisitionInternalTestTrackedEntries (canonicalEntryTuples inputs) changedBundle)

canonicalEntryTuples
  :: CanonicalAcquisitionInputs
  -> [(FilePath, IndexMode, Text.Text, Word64, Text.Text)]
canonicalEntryTuples inputs = map canonicalEntryTuple (canonicalInputEntries inputs)

canonicalEntryTuple
  :: CanonicalAcquisitionEntry
  -> (FilePath, IndexMode, Text.Text, Word64, Text.Text)
canonicalEntryTuple entry =
  ( canonicalEntryPath entry
  , case canonicalEntryMode entry of
      "100644" -> RegularFile
      "100755" -> ExecutableFile
      "120000" -> SymbolicLink
      value -> error ("oracle fixture has an unknown mode: " <> Text.unpack value)
  , canonicalEntryGitObjectId entry
  , canonicalEntryByteLength entry
  , canonicalEntryBlobSha256 entry
  )

sha1 :: ByteString -> Text.Text
sha1 bytes = Text.pack (show (Crypto.hash bytes :: Crypto.Digest Crypto.SHA1))

sha256 :: ByteString -> Text.Text
sha256 bytes = Text.pack (show (Crypto.hash bytes :: Crypto.Digest Crypto.SHA256))

replaceByteAt :: Int -> Word8 -> ByteString -> ByteString
replaceByteAt offset replacement bytes =
  ByteString.take offset bytes
    <> ByteString.singleton replacement
    <> ByteString.drop (offset + 1) bytes

canonicalSession
  :: CanonicalAcquisitionInputs
  -> Set.Set Text.Text
  -> AnchoredSourceAcquisitionSession
canonicalSession inputs consumed =
  canonicalSessionWithChallenge inputs (canonicalInputChallenge inputs) consumed

canonicalSessionWithChallenge
  :: CanonicalAcquisitionInputs
  -> Text.Text
  -> Set.Set Text.Text
  -> AnchoredSourceAcquisitionSession
canonicalSessionWithChallenge inputs challenge consumed =
  anchorSourceAcquisitionSession
    (canonicalInputPhase inputs)
    (canonicalInputAuthority inputs)
    (canonicalInputObserverToolDigest inputs)
    challenge
    consumed
    (canonicalInputRepositoryIdentity inputs)
    (canonicalInputRequestedRevision inputs)
    (canonicalInputHeadIdentity inputs)
    (canonicalInputSourceSnapshotIdentity inputs)
    (canonicalInputAuthoredRootIdentity inputs)
    (canonicalInputExpectedManifestBytes inputs)
    (canonicalInputPublicKeyBytes inputs)

signatureRefusal :: Either CheckResult AcquiredSourceSnapshot
signatureRefusal =
  Left
    CheckResult
      { checkName = "source-acquisition"
      , checkObservations = [Observation "source-acquisition.integrity" "refused with 1 integrity finding(s)"]
      , checkFindings =
          [ Finding
              "SOURCE-ACQUISITION-SIGNATURE"
              "source-acquisition-envelope"
              "SourceAcquisitionSignatureInvalid"
          ]
      }

corruptLastByte :: ByteString -> ByteString
corruptLastByte bytes
  | ByteString.null bytes = bytes
  | otherwise =
      ByteString.init bytes
        <> ByteString.singleton (ByteString.last bytes `xor` 1)

replaceFirstHex :: Text.Text -> Text.Text
replaceFirstHex value =
  case Text.uncons value of
    Nothing -> "0"
    Just (first, rest) -> (if first == '0' then "1" else "0") <> rest

expectEqual :: (Eq value, Show value) => String -> value -> value -> [String]
expectEqual label expected actual =
  [ label <> ": expected " <> show expected <> ", observed " <> show actual
  | expected /= actual
  ]

unlinesWith :: String -> [String] -> String
unlinesWith _ [] = ""
unlinesWith separator (first : rest) = first <> concatMap (separator <>) rest
