{-# LANGUAGE OverloadedStrings #-}

module SourceDebtBaselineOracle
  ( runSourceDebtBaselineOracle
  ) where

-- This oracle intentionally uses only the permanently refusing raw diagnostic
-- front. Its fixtures, frozen digests, limits, finding text, and complete
-- ordered CheckResults are literal and independent of production baselines or
-- private comparison values.

import Amoebius.Validation.SourceDebtBaseline (sourceDebtBaselineCheck)
import Amoebius.Validation.Types (CheckResult (..), Finding (..), Observation (..))
import Control.Monad (unless)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.List (group, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding

runSourceDebtBaselineOracle :: IO ()
runSourceDebtBaselineOracle =
  finishDiagnostics
    "SourceDebtBaselineOracle"
    ( mutationIntentProblems
        <> fixtureIntegrityProblems
        <> expectExact "empty diagnostic result" emptyExpected (diagnose [])
        <> expectExact "invalid raw mode refuses exactly" invalidModeExpected (diagnose [invalidModeEntry])
        <> expectExact "all-family exact result and result-bound maxima" centralExpected (diagnose centralEntries)
        <> expectExact "pb debt is an exact semantic refusal" pbExpected (diagnose [pbEntry])
        <> expectExact "preallocation maximum is admitted exactly" preallocationMaximumExpected (diagnose preallocationMaximumEntries)
        <> expectExact "preallocation maximum-plus-one refuses before hashing" preallocationExceededExpected (diagnose preallocationExceededEntries)
        <> expectExact "traversal maximum is admitted exactly" traversalMaximumExpected (diagnose traversalMaximumEntries)
        <> expectExact "traversal maximum-plus-one refuses before observation" traversalExceededExpected (diagnose traversalExceededEntries)
        <> expectExact "UTF-8 path maximum is admitted exactly" pathMaximumExpected (diagnose [pathMaximumEntry])
        <> expectExact "UTF-8 path maximum-plus-one refuses before hashing" pathExceededExpected (diagnose [pathExceededEntry])
        <> expectExact "object-id maximum is admitted exactly" objectIdMaximumExpected (diagnose [objectIdMaximumEntry])
        <> expectExact "object-id maximum-plus-one refuses before hashing" objectIdExceededExpected (diagnose [objectIdExceededEntry])
        <> expectExact "blob maximum is admitted exactly" blobMaximumExpected (diagnose [blobMaximumEntry])
        <> expectExact "blob maximum-plus-one refuses before hashing" blobExceededExpected (diagnose [blobExceededEntry])
        <> expectExact "aggregate blob maximum is admitted exactly" aggregateBlobMaximumExpected (diagnose aggregateBlobMaximumEntries)
        <> expectExact "aggregate blob maximum-plus-one refuses before hashing" aggregateBlobExceededExpected (diagnose aggregateBlobExceededEntries)
        <> expectExact "problem and observation first-excess bounds refuse exactly" resultBoundsExceededExpected (diagnose (centralEntries <> [pbEntry]))
    )

-- The intent registry is independent of production CPP and Cabal. Static
-- repository diagnostics reconcile these names two ways; this oracle only
-- guarantees that every selector names one exact full-result case.
mutationIntent :: [(String, String)]
mutationIntent =
  [ ("VALIDATION_SOURCE_DEBT_AGGREGATE_BLOB_LIMIT_WIDEN_MUTANT", "aggregate blob maximum-plus-one refuses before hashing")
  , ("VALIDATION_SOURCE_DEBT_BASELINE_BYTE_COMMITMENT_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_DHALL_COUNT_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_DHALL_FINGERPRINT_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_DHALL_OMISSION_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_DHALL_PATH_INVENTORY_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_FAMILY_SET_INVERSION_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_FINGERPRINT_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_PATH_INVENTORY_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_PROBE_COUNT_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_PROBE_FINGERPRINT_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_PROBE_OMISSION_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_PROBE_PATH_INVENTORY_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_PROTO_COUNT_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_PROTO_FINGERPRINT_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_PROTO_OMISSION_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_PROTO_PATH_INVENTORY_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_PULUMI_COUNT_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_PULUMI_FINGERPRINT_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_PULUMI_OMISSION_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_PULUMI_PATH_INVENTORY_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_TEST_COUNT_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_TEST_FINGERPRINT_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_TEST_OMISSION_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_TEST_PATH_INVENTORY_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_TOOLS_OMISSION_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_UI_COUNT_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_UI_FINGERPRINT_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_UI_OMISSION_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_UI_PATH_INVENTORY_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_VENDOR_COUNT_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_VENDOR_FINGERPRINT_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_BASELINE_VENDOR_PATH_INVENTORY_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_BLOB_LIMIT_WIDEN_MUTANT", "blob maximum-plus-one refuses before hashing")
  , ("VALIDATION_SOURCE_DEBT_COUNT_COMPARISON_BYPASS_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_COUNT_OBSERVER_FABRICATION_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_DIAGNOSTIC_BYPASS_MUTANT", "empty diagnostic result")
  , ("VALIDATION_SOURCE_DEBT_FINGERPRINT_COMPARISON_BYPASS_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_FINGERPRINT_OBSERVER_FABRICATION_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_MISSING_OBSERVATION_ZERO_MUTANT", "empty diagnostic result")
  , ("VALIDATION_SOURCE_DEBT_OBJECT_ID_LIMIT_WIDEN_MUTANT", "object-id maximum-plus-one refuses before hashing")
  , ("VALIDATION_SOURCE_DEBT_OBSERVATION_LIMIT_WIDEN_MUTANT", resultBoundCase)
  , ("VALIDATION_SOURCE_DEBT_OBSERVED_FAMILY_SET_BYPASS_MUTANT", "empty diagnostic result")
  , ("VALIDATION_SOURCE_DEBT_OBSERVER_FABRICATION_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_OMISSION_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_PATH_INVENTORY_BYPASS_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_PATH_INVENTORY_COMPARISON_BYPASS_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_PATH_OBSERVER_FABRICATION_MUTANT", centralCase)
  , ("VALIDATION_SOURCE_DEBT_PATH_UTF8_LIMIT_WIDEN_MUTANT", "UTF-8 path maximum-plus-one refuses before hashing")
  , ("VALIDATION_SOURCE_DEBT_PB_ZERO_BYPASS_MUTANT", "pb debt is an exact semantic refusal")
  , ("VALIDATION_SOURCE_DEBT_PREALLOCATION_LIMIT_WIDEN_MUTANT", "preallocation maximum-plus-one refuses before hashing")
  , ("VALIDATION_SOURCE_DEBT_PROBLEM_LIMIT_WIDEN_MUTANT", resultBoundCase)
  , ("VALIDATION_SOURCE_DEBT_RAW_MODE_BYPASS_MUTANT", "invalid raw mode refuses exactly")
  , ("VALIDATION_SOURCE_DEBT_TRAVERSAL_LIMIT_WIDEN_MUTANT", "traversal maximum-plus-one refuses before observation")
  ]
 where
  centralCase = "all-family exact result and result-bound maxima"
  resultBoundCase = "problem and observation first-excess bounds refuse exactly"

mutationIntentProblems :: [String]
mutationIntentProblems =
  ["expected 55 mutation-intent rows, observed " <> show (length mutationIntent)
  | length mutationIntent /= 55]
    <> ["duplicate mutation-intent selector " <> selector
       | selector : _ : _ <- group (sort (map fst mutationIntent))]
    <> ["mutation-intent target must name exactly one case: " <> selector <> " -> " <> target
       | (selector, target) <- mutationIntent
       , length (filter (== target) exactCaseLabels) /= 1]

exactCaseLabels :: [String]
exactCaseLabels =
  [ "empty diagnostic result"
  , "invalid raw mode refuses exactly"
  , "all-family exact result and result-bound maxima"
  , "pb debt is an exact semantic refusal"
  , "preallocation maximum is admitted exactly"
  , "preallocation maximum-plus-one refuses before hashing"
  , "traversal maximum is admitted exactly"
  , "traversal maximum-plus-one refuses before observation"
  , "UTF-8 path maximum is admitted exactly"
  , "UTF-8 path maximum-plus-one refuses before hashing"
  , "object-id maximum is admitted exactly"
  , "object-id maximum-plus-one refuses before hashing"
  , "blob maximum is admitted exactly"
  , "blob maximum-plus-one refuses before hashing"
  , "aggregate blob maximum is admitted exactly"
  , "aggregate blob maximum-plus-one refuses before hashing"
  , "problem and observation first-excess bounds refuse exactly"
  ]

diagnose :: [LiteralTrackedEntry] -> CheckResult
diagnose = sourceDebtBaselineCheck . map renderLiteralEntry

fixtureIntegrityProblems :: [String]
fixtureIntegrityProblems =
  concat
    [ expectLiteral "central fixture entry count" 10 (length centralEntries)
    , expectLiteral "preallocation exact fixture count" 1468 (length preallocationMaximumEntries)
    , expectLiteral "preallocation first-excess fixture count" 1469 (length preallocationExceededEntries)
    , expectLiteral "traversal exact fixture count" 16384 (length traversalMaximumEntries)
    , expectLiteral "traversal first-excess fixture count" 16385 (length traversalExceededEntries)
    , expectLiteral "central expected observation count" 26 (length (checkObservations centralExpected))
    , expectLiteral "central expected finding count" 25 (length (checkFindings centralExpected))
    , expectLiteral "UTF-8 path exact byte count" 1024 (utf8PathBytes pathMaximumValue)
    , expectLiteral "UTF-8 path first-excess byte count" 1025 (utf8PathBytes pathExceededValue)
    , expectLiteral "object-id exact UTF-8 byte count" 64 (utf8TextBytes objectIdMaximumValue)
    , expectLiteral "object-id first-excess UTF-8 byte count" 65 (utf8TextBytes objectIdExceededValue)
    , expectLiteral "blob exact byte count" 16777216 (ByteString.length blobMaximumPayload)
    , expectLiteral "blob first-excess byte count" 16777217 (ByteString.length blobExceededPayload)
    , expectLiteral "aggregate blob exact byte count" 33554432 (sum (map (ByteString.length . literalBytes) aggregateBlobMaximumEntries))
    , expectLiteral "aggregate blob first-excess byte count" 33554433 (sum (map (ByteString.length . literalBytes) aggregateBlobExceededEntries))
    ]

emptyExpected :: CheckResult
emptyExpected =
  CheckResult
    { checkName = "source-debt-baseline"
    , checkObservations =
        [ Observation "source-debt.expected-family-count" "8"
        , Observation "source-debt.actual-family-count" "0"
        ]
    , checkFindings =
        [ diagnosticFinding
        , familySetFinding ""
        ]
    }

invalidModeExpected :: CheckResult
invalidModeExpected =
  CheckResult
    { checkName = "source-debt-baseline"
    , checkObservations = []
    , checkFindings =
        [ diagnosticFinding
        , Finding
            "SOURCE-DEBT-RAW-MODE-INVALID"
            "source-debt-baseline"
            "raw mode must be exactly one of 100644,100755,120000"
        ]
    }

centralExpected :: CheckResult
centralExpected =
  CheckResult
    { checkName = "source-debt-baseline"
    , checkObservations =
        [ Observation "source-debt.expected-family-count" "8"
        , Observation "source-debt.actual-family-count" "8"
        ]
          <> familyObservations "LTD-SRC-001" "1" toolsActualFingerprint toolsActualPathDigest
          <> familyObservations "LTD-SRC-002" "1" dhallActualFingerprint dhallActualPathDigest
          <> familyObservations "LTD-SRC-003" "2" protoActualFingerprint protoActualPathDigest
          <> familyObservations "LTD-SRC-004" "1" uiActualFingerprint uiActualPathDigest
          <> familyObservations "LTD-SRC-005" "2" pulumiActualFingerprint pulumiActualPathDigest
          <> familyObservations "LTD-SRC-006" "1" testActualFingerprint testActualPathDigest
          <> familyObservations "LTD-SRC-007" "1" probeActualFingerprint probeActualPathDigest
          <> familyObservations "LTD-SRC-009" "1" vendorActualFingerprint vendorActualPathDigest
    , checkFindings =
        [diagnosticFinding]
          <> threeMismatchFindings
            "LTD-SRC-001"
            "237"
            "1"
            "6a370eba5fefa423d19fe03b62a4bb0d1a42f081276c92edef9b8799b6202bdc"
            toolsActualFingerprint
            "a3e7165733971922668b4c283f2a4f5fe9001f143fd621a9091455c23df01504"
            toolsActualPathDigest
          <> threeMismatchFindings
            "LTD-SRC-002"
            "279"
            "1"
            "1b6ec412272fc7a9894e0e6aed604eb1ea45e5adb059ae8a85a9b0988231ddfb"
            dhallActualFingerprint
            "9360f0c7a1065e8aba3e8c241668703f65075dcf3dfe7e91f7923939291f17e2"
            dhallActualPathDigest
          <> threeMismatchFindings
            "LTD-SRC-003"
            "1"
            "2"
            "829974a9fe5d21a566f7b9fe6a6311e2b9cc0d3ce6bd61c6db7c3b8e89e30d0f"
            protoActualFingerprint
            "398ee861ab5e554a723bcc0cf94b943cf89b033bc62571fcb4387ab350e5e716"
            protoActualPathDigest
          <> threeMismatchFindings
            "LTD-SRC-004"
            "16"
            "1"
            "7e7d4b91e6b2d0b410bfab949a5aa56d7437c498282bee93640fde14d01897da"
            uiActualFingerprint
            "3992d81deb5b947f633846cb62279a3fe0f4ff03701bfd27ca382855177b6223"
            uiActualPathDigest
          <> threeMismatchFindings
            "LTD-SRC-005"
            "1"
            "2"
            "1cb177d7a74486fcc58159ecc05f43eb929f9c4e5d2d31c8762f282b04ef4697"
            pulumiActualFingerprint
            "e55482b85a31758b72c112284c741f16766f6d1ffaf030ea0d7773d88b0f3022"
            pulumiActualPathDigest
          <> threeMismatchFindings
            "LTD-SRC-006"
            "890"
            "1"
            "28947c7c6000818cc08d4bd347efde7ba8d1d27e3318fe66566ffca6db7bcfd6"
            testActualFingerprint
            "80fc42c24a9de83a8d7cbfd4232417058b7c8a72a9a8f4dec529aab5e5d96542"
            testActualPathDigest
          <> threeMismatchFindings
            "LTD-SRC-007"
            "7"
            "1"
            "904fda09d0d0932c7e58f5fe2b134da8fc97c3ab7b48e19092df1ae97709d75e"
            probeActualFingerprint
            "78e3bbf2977c0e3f8a8f3dab020a8e504a0d11a453529bd12bda559b32367e14"
            probeActualPathDigest
          <> threeMismatchFindings
            "LTD-SRC-009"
            "28"
            "1"
            "845e295527ccfeb1cea5434a488124890b680f5dd17baed6dfe9881bcdba07f6"
            vendorActualFingerprint
            "1cac8ad1d2f7115323fb503d56ce04463338a94dbb98a8c313adfe67c0e66764"
            vendorActualPathDigest
    }

pbExpected :: CheckResult
pbExpected =
  CheckResult
    { checkName = "source-debt-baseline"
    , checkObservations =
        [ Observation "source-debt.expected-family-count" "8"
        , Observation "source-debt.actual-family-count" "1"
        ]
          <> familyObservations "LTD-SRC-008" "1" pbActualFingerprint pbActualPathDigest
    , checkFindings =
        [ diagnosticFinding
        , familySetFinding ""
        , Finding
            "SOURCE-DEBT-PB-NOT-ZERO"
            "LTD-SRC-008"
            ("expected absent/zero, actual count=1, fingerprint=" <> pbActualFingerprint)
        ]
    }

preallocationMaximumExpected :: CheckResult
preallocationMaximumExpected =
  toolsOnlyExpected "1468" preallocationFingerprint preallocationPathDigest

preallocationExceededExpected :: CheckResult
preallocationExceededExpected =
  CheckResult
    { checkName = "source-debt-baseline"
    , checkObservations =
        [ Observation "source-debt.preallocation-limit.maximum" "1468"
        , Observation "source-debt.preallocation-limit.observed-at-least" "1469"
        ]
    , checkFindings =
        [ diagnosticFinding
        , Finding
            "SOURCE-DEBT-PREALLOCATION-LIMIT"
            "source-debt-baseline"
            "maximum=1468, observed-at-least=1469"
        ]
    }

traversalMaximumExpected :: CheckResult
traversalMaximumExpected = emptyExpected

traversalExceededExpected :: CheckResult
traversalExceededExpected =
  CheckResult
    { checkName = "source-debt-baseline"
    , checkObservations =
        [ Observation "source-debt.traversal-limit.maximum" "16384"
        , Observation "source-debt.traversal-limit.observed-at-least" "16385"
        ]
    , checkFindings =
        [ diagnosticFinding
        , Finding
            "SOURCE-DEBT-TRAVERSAL-LIMIT"
            "source-debt-baseline"
            "maximum=16384, observed-at-least=16385"
        ]
    }

pathMaximumExpected :: CheckResult
pathMaximumExpected =
  toolsOnlyExpected "1" pathMaximumFingerprint pathMaximumPathDigest

pathExceededExpected :: CheckResult
pathExceededExpected =
  resourceLimitExpected
    "path-utf8"
    "SOURCE-DEBT-PATH-UTF8-LIMIT"
    "1024"
    "1025"

objectIdMaximumExpected :: CheckResult
objectIdMaximumExpected =
  toolsOnlyExpected "1" objectIdMaximumFingerprint objectIdMaximumPathDigest

objectIdExceededExpected :: CheckResult
objectIdExceededExpected =
  resourceLimitExpected
    "object-id"
    "SOURCE-DEBT-OBJECT-ID-LIMIT"
    "64"
    "65"

blobMaximumExpected :: CheckResult
blobMaximumExpected =
  toolsOnlyExpected "1" blobMaximumFingerprint blobMaximumPathDigest

blobExceededExpected :: CheckResult
blobExceededExpected =
  resourceLimitExpected
    "blob"
    "SOURCE-DEBT-BLOB-LIMIT"
    "16777216"
    "16777217"

aggregateBlobMaximumExpected :: CheckResult
aggregateBlobMaximumExpected =
  toolsOnlyExpected "2" aggregateBlobMaximumFingerprint aggregateBlobMaximumPathDigest

aggregateBlobExceededExpected :: CheckResult
aggregateBlobExceededExpected =
  resourceLimitExpected
    "aggregate-blob"
    "SOURCE-DEBT-AGGREGATE-BLOB-LIMIT"
    "33554432"
    "33554433"

resultBoundsExceededExpected :: CheckResult
resultBoundsExceededExpected =
  CheckResult
    { checkName = "source-debt-baseline"
    , checkObservations =
        [ Observation "source-debt.observation-limit.maximum" "26"
        , Observation "source-debt.observation-limit.observed-at-least" "27"
        ]
    , checkFindings =
        [ diagnosticFinding
        , Finding
            "SOURCE-DEBT-OBSERVATION-LIMIT"
            "source-debt-baseline"
            "maximum=26, observed-at-least=27"
        , Finding
            "SOURCE-DEBT-PROBLEM-LIMIT"
            "source-debt-baseline"
            "maximum=24, observed-at-least=25"
        ]
    }

toolsOnlyExpected :: Text -> Text -> Text -> CheckResult
toolsOnlyExpected actualCount actualFingerprint actualPathDigest =
  CheckResult
    { checkName = "source-debt-baseline"
    , checkObservations =
        [ Observation "source-debt.expected-family-count" "8"
        , Observation "source-debt.actual-family-count" "1"
        ]
          <> familyObservations "LTD-SRC-001" actualCount actualFingerprint actualPathDigest
    , checkFindings =
        [ diagnosticFinding
        , familySetFinding "LTD-SRC-001"
        ]
          <> threeMismatchFindings
            "LTD-SRC-001"
            "237"
            actualCount
            "6a370eba5fefa423d19fe03b62a4bb0d1a42f081276c92edef9b8799b6202bdc"
            actualFingerprint
            "a3e7165733971922668b4c283f2a4f5fe9001f143fd621a9091455c23df01504"
            actualPathDigest
    }

resourceLimitExpected :: Text -> Text -> Text -> Text -> CheckResult
resourceLimitExpected dimension code maximumValue observedAtLeast =
  CheckResult
    { checkName = "source-debt-baseline"
    , checkObservations =
        [ Observation ("source-debt." <> dimension <> "-limit.maximum") maximumValue
        , Observation ("source-debt." <> dimension <> "-limit.observed-at-least") observedAtLeast
        ]
    , checkFindings =
        [ diagnosticFinding
        , Finding
            code
            "source-debt-baseline"
            ("maximum=" <> maximumValue <> ", observed-at-least=" <> observedAtLeast)
        ]
    }

diagnosticFinding :: Finding
diagnosticFinding =
  Finding
    "SOURCE-DEBT-DIAGNOSTIC-ONLY"
    "<caller-supplied-source-closure>"
    "caller-supplied source-debt observations are diagnostic input, not candidate acquisition authority"

familySetFinding :: Text -> Finding
familySetFinding actual =
  Finding
    "SOURCE-DEBT-FAMILY-SET-MISMATCH"
    "source-debt-baseline"
    ( "expected=LTD-SRC-001,LTD-SRC-002,LTD-SRC-003,LTD-SRC-004,LTD-SRC-005,LTD-SRC-006,LTD-SRC-007,LTD-SRC-009, actual="
        <> actual
    )

familyObservations :: Text -> Text -> Text -> Text -> [Observation]
familyObservations identifier count fingerprint pathDigest =
  [ Observation ("source-debt.count." <> identifier) count
  , Observation ("source-debt.fingerprint." <> identifier) fingerprint
  , Observation ("source-debt.path-inventory." <> identifier) pathDigest
  ]

threeMismatchFindings
  :: Text
  -> Text
  -> Text
  -> Text
  -> Text
  -> Text
  -> Text
  -> [Finding]
threeMismatchFindings identifier expectedCount actualCount expectedFingerprint actualFingerprint expectedPathDigest actualPathDigest =
  [ Finding
      "SOURCE-DEBT-COUNT-MISMATCH"
      (textPath identifier)
      ("expected=" <> expectedCount <> ", actual=" <> actualCount)
  , Finding
      "SOURCE-DEBT-FINGERPRINT-MISMATCH"
      (textPath identifier)
      ("expected=" <> expectedFingerprint <> ", actual=" <> actualFingerprint)
  , Finding
      "SOURCE-DEBT-PATH-INVENTORY-MISMATCH"
      (textPath identifier)
      ("expected=" <> expectedPathDigest <> ", actual=" <> actualPathDigest)
  ]

textPath :: Text -> FilePath
textPath = Text.unpack

data LiteralIndexMode
  = LiteralRegularFile
  | LiteralInvalidMode Text

data LiteralTrackedEntry = LiteralTrackedEntry
  { literalPath :: FilePath
  , literalMode :: LiteralIndexMode
  , literalObjectId :: Text
  , literalBytes :: ByteString
  }

renderLiteralEntry :: LiteralTrackedEntry -> (FilePath, Text, Text, ByteString)
renderLiteralEntry entry =
  ( literalPath entry
  , case literalMode entry of
      LiteralRegularFile -> "100644"
      LiteralInvalidMode mode -> mode
  , literalObjectId entry
  , literalBytes entry
  )

centralEntries :: [LiteralTrackedEntry]
centralEntries =
  [ toolsEntry
  , dhallEntry
  , protoAEntry
  , protoBEntry
  , uiEntry
  , pulumiAEntry
  , pulumiBEntry
  , testEntry
  , probeEntry
  , vendorEntry
  ]

invalidModeEntry :: LiteralTrackedEntry
invalidModeEntry =
  (literalEntry "tools/invalid-mode.py" "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" "invalid mode\n")
    { literalMode = LiteralInvalidMode "100600"
    }

toolsEntry, dhallEntry, protoAEntry, protoBEntry, uiEntry :: LiteralTrackedEntry
toolsEntry = literalEntry "tools/a.py" "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" "tools literal\n"
dhallEntry = literalEntry "dhall/a.dhall" "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" "dhall literal\n"
protoAEntry = literalEntry "proto/a.proto" "cccccccccccccccccccccccccccccccccccccccc" "proto a literal\n"
protoBEntry = literalEntry "proto/b.proto" "dddddddddddddddddddddddddddddddddddddddd" "proto b literal\n"
uiEntry = literalEntry "ui/a.js" "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee" "ui literal\n"

pulumiAEntry, pulumiBEntry, testEntry, probeEntry, vendorEntry, pbEntry :: LiteralTrackedEntry
pulumiAEntry = literalEntry "pulumi/a.py" "ffffffffffffffffffffffffffffffffffffffff" "pulumi a literal\n"
pulumiBEntry = literalEntry "pulumi/b.py" "1111111111111111111111111111111111111111" "pulumi b literal\n"
testEntry = literalEntry "test/a.py" "2222222222222222222222222222222222222222" "test literal\n"
probeEntry = literalEntry "probe/a.py" "3333333333333333333333333333333333333333" "probe literal\n"
vendorEntry = literalEntry "vendor/a.py" "4444444444444444444444444444444444444444" "vendor literal\n"
pbEntry = literalEntry "pb/a.py" "5555555555555555555555555555555555555555" "pb literal\n"

pathMaximumEntry, pathExceededEntry :: LiteralTrackedEntry
pathMaximumEntry =
  literalEntry pathMaximumValue "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" "path literal\n"
pathExceededEntry =
  literalEntry pathExceededValue "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" "path literal\n"

pathMaximumValue, pathExceededValue :: FilePath
pathMaximumValue = "tools/a" <> replicate 507 '\233' <> ".py"
pathExceededValue = "tools/" <> replicate 508 '\233' <> ".py"

objectIdMaximumEntry, objectIdExceededEntry :: LiteralTrackedEntry
objectIdMaximumEntry =
  literalEntry "tools/object-max.py" objectIdMaximumValue "object literal\n"
objectIdExceededEntry =
  literalEntry "tools/object-max.py" objectIdExceededValue "object literal\n"

objectIdMaximumValue, objectIdExceededValue :: Text
objectIdMaximumValue = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
objectIdExceededValue = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

blobMaximumEntry, blobExceededEntry :: LiteralTrackedEntry
blobMaximumEntry =
  literalEntry "tools/blob-max.py" "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" blobMaximumPayload
blobExceededEntry =
  literalEntry "tools/blob-max.py" "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" blobExceededPayload

blobMaximumPayload, blobExceededPayload :: ByteString
blobMaximumPayload = ByteString.replicate 16777216 120
blobExceededPayload = ByteString.replicate 16777217 120

aggregateBlobMaximumEntries, aggregateBlobExceededEntries :: [LiteralTrackedEntry]
aggregateBlobMaximumEntries =
  [ literalEntry "tools/aggregate-a.py" "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" blobMaximumPayload
  , literalEntry "tools/aggregate-b.py" "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" blobMaximumPayload
  ]
aggregateBlobExceededEntries =
  aggregateBlobMaximumEntries
    <> [literalEntry "tools/aggregate-c.py" "cccccccccccccccccccccccccccccccccccccccc" "z"]

literalEntry :: FilePath -> Text -> ByteString -> LiteralTrackedEntry
literalEntry path objectId bytes =
  LiteralTrackedEntry
    { literalPath = path
    , literalMode = LiteralRegularFile
    , literalObjectId = objectId
    , literalBytes = bytes
    }

preallocationMaximumEntries :: [LiteralTrackedEntry]
preallocationMaximumEntries = map preallocationEntry [0 .. 1467]

preallocationExceededEntries :: [LiteralTrackedEntry]
preallocationExceededEntries = map preallocationEntry [0 .. 1468]

preallocationEntry :: Int -> LiteralTrackedEntry
preallocationEntry index =
  literalEntry
    ("tools/bound-" <> padDecimal 4 index <> ".py")
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    "bound literal\n"

traversalMaximumEntries :: [LiteralTrackedEntry]
traversalMaximumEntries = map traversalEntry [0 .. 16383]

traversalExceededEntries :: [LiteralTrackedEntry]
traversalExceededEntries = map traversalEntry [0 .. 16384]

traversalEntry :: Int -> LiteralTrackedEntry
traversalEntry index =
  literalEntry
    ("src/Bound/Module" <> padDecimal 5 index <> ".hs")
    "6666666666666666666666666666666666666666"
    "module Bound where\n"

padDecimal :: Int -> Int -> String
padDecimal width value =
  replicate (max 0 (width - length rendered)) '0' <> rendered
 where
  rendered = show value

utf8PathBytes :: FilePath -> Int
utf8PathBytes = ByteString.length . TextEncoding.encodeUtf8 . Text.pack

utf8TextBytes :: Text -> Int
utf8TextBytes = ByteString.length . TextEncoding.encodeUtf8

toolsActualFingerprint, toolsActualPathDigest :: Text
toolsActualFingerprint = "7ca539ca424cca0c606a181084881dc4467ad64761b8fd5910d0386ccb7be5e0"
toolsActualPathDigest = "3714bf054ea604d1f23b78f7911592a6985c3b975910827b3181f4e5b19a8d7d"

dhallActualFingerprint, dhallActualPathDigest :: Text
dhallActualFingerprint = "abc352822eba8477396c904b8565003b80a23d8b28a7da4fa5c1d6fd94aca991"
dhallActualPathDigest = "12d1c8b50a961d7b6ff7cf184b6114b0a3aae6d101fbb4159c42be529ded1207"

protoActualFingerprint, protoActualPathDigest :: Text
protoActualFingerprint = "b8d44ebdfa72bbedbd1d9a21ac8ac39268ca60a00127bb2edac8cc1287562739"
protoActualPathDigest = "8fcff8446cfdb63bed9f3b19353d7f41cdda9d7ec8b727a7cbcd68f38b70dc16"

uiActualFingerprint, uiActualPathDigest :: Text
uiActualFingerprint = "f323b64c8642d031bae63ef280f2ba57dd37648389eeebaf87f16428eeddcf5d"
uiActualPathDigest = "439c61547b88d4e7f046751884ccedc35d4603762eca2b27390de81068197f4f"

pulumiActualFingerprint, pulumiActualPathDigest :: Text
pulumiActualFingerprint = "8a2b6fa221885fb749dc14830d15b1e125c7d23340c42b2835d70fe9b072c499"
pulumiActualPathDigest = "e1d411af063fa0dc2a0db6f46a5acfad0efc7b58a3a122eb46d887ac593d7c6a"

testActualFingerprint, testActualPathDigest :: Text
testActualFingerprint = "db180378fd7a4da92651443f8064d9140bfc812c2479f4b5d131b06d0937d0f9"
testActualPathDigest = "06abc90ed2cac5d47efc76ff046659a0c7d97c028166fb40abb5e36f0679d819"

probeActualFingerprint, probeActualPathDigest :: Text
probeActualFingerprint = "f5c2e80c8cfca2d3574c1259659240be2cb0e6ed6725ca06fb3b0e4f3f736212"
probeActualPathDigest = "3764577ea9469927dfe9dcd95f8eaa4dc64a64a13440cab4d49eecb8ba7313fe"

vendorActualFingerprint, vendorActualPathDigest :: Text
vendorActualFingerprint = "f72557e65e55c82e12ba5a3af572e1dbb1bc92333e20cbaae44fe00a015bb0a4"
vendorActualPathDigest = "9cc45f4a8b14953638dd849f99931a236cf009f57226114d0030f1b8b6d3abba"

pbActualFingerprint, pbActualPathDigest :: Text
pbActualFingerprint = "b22cc82735de5818245664810b3a2f3fad84644d58b9e7d77ad11719b298a460"
pbActualPathDigest = "795796f54fcfe0d165d790dcb2b6faf8dcaad8e9ff84bd4e029ef1a5205431d7"

preallocationFingerprint, preallocationPathDigest :: Text
preallocationFingerprint = "a9604c5dcb9dc3c590dfe70a20359d58a0b928c9b2b74185638ccd1b2bec162a"
preallocationPathDigest = "fc1e70d6676a100b058a94686301904cab08f4f53cc00068a431dce385efdd32"

pathMaximumFingerprint, pathMaximumPathDigest :: Text
pathMaximumFingerprint = "21cba7b3ecef548e69497cada841590ed5c46eee790fecb231ad8ce97848cfb2"
pathMaximumPathDigest = "0f64e2aa751528591bd4c306d0bd4d5462f127da1c44a8b34a52c3bfafe10bb3"

objectIdMaximumFingerprint, objectIdMaximumPathDigest :: Text
objectIdMaximumFingerprint = "db6a039b24d92a33db0574ebba453ce7ac3cade7c3fb779dc08f27b00b0cb8f2"
objectIdMaximumPathDigest = "e1453e0822a90bf02d13f360c18eafd45e9b191264ad0feeefa244378cf4362f"

blobMaximumFingerprint, blobMaximumPathDigest :: Text
blobMaximumFingerprint = "9b140bc0d994888ca80cb3b019594824c30e35daec56214dc77a27dfa02ee6e2"
blobMaximumPathDigest = "149b92fdf0e2813dfaa56f6458bf1e7d7458d1e298432e5c16808db0f8ecb2cd"

aggregateBlobMaximumFingerprint, aggregateBlobMaximumPathDigest :: Text
aggregateBlobMaximumFingerprint = "f4eba1b494585eff64549b7fd66febe2a91613907c216ce2227c5e6141d90bde"
aggregateBlobMaximumPathDigest = "16c4a5b43c3320cca6b7f63e500bc565d20d9c898d744bda4ad086c5ff640e89"

expectExact :: String -> CheckResult -> CheckResult -> [String]
expectExact label expected actual
  | expected == actual = []
  | otherwise =
      [ label
          <> ": expected complete ordered result "
          <> show expected
          <> ", got "
          <> show actual
      ]

expectLiteral :: (Eq value, Show value) => String -> value -> value -> [String]
expectLiteral label expected actual
  | expected == actual = []
  | otherwise = [label <> ": expected " <> show expected <> ", got " <> show actual]

finishDiagnostics :: String -> [String] -> IO ()
finishDiagnostics name problems =
  unless
    (null problems)
    (ioError (userError (unlines ((name <> " failed:") : map ("- " <>) problems))))
