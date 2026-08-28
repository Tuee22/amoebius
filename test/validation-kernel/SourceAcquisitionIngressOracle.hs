{-# LANGUAGE OverloadedStrings #-}

module SourceAcquisitionIngressOracle
  ( runSourceAcquisitionIngressControl
  , runSourceAcquisitionIngressOracle
  , runSourceAcquisitionIngressSelectorOracle
  , sourceAcquisitionIngressSelectorIntents
  , sourceAcquisitionIngressSelectorNames
  ) where

import Amoebius.Validation.SourceAcquisitionIngress.Internal
  ( SourceAcquisitionIngress
  , ingressBundleBytes
  , ingressExpectedManifestBytes
  , ingressWireBytes
  , readSourceAcquisitionIngress
  , sourceAcquisitionIngressTestReadBounded
  , sourceAcquisitionIngressTestRoutedLimits
  )
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding (..)
  , Observation (..)
  )
import Control.Exception (IOException, bracket, try)
import Control.Monad (unless)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.List (group, sort)
import Data.Text qualified as Text
import System.Directory (getTemporaryDirectory, removeFile)
import System.IO
  ( Handle
  , IOMode (ReadMode)
  , hClose
  , hTell
  , openBinaryFile
  , openBinaryTempFile
  )

data OracleIngressStream
  = OracleExpectedManifestIngress
  | OracleSignedEnvelopeIngress
  | OracleImmutableBundleIngress
  deriving (Eq, Show)

runSourceAcquisitionIngressOracle :: IO ()
runSourceAcquisitionIngressOracle = do
  cases <- sourceAcquisitionIngressExactCases
  let problems = selectorRegistryProblems cases <> concatMap snd cases
  unless
    (null problems)
    (fail ("SourceAcquisitionIngressOracle component diagnostic failures:\n  " <> unlinesWith "\n  " problems))

runSourceAcquisitionIngressSelectorOracle :: String -> IO ()
runSourceAcquisitionIngressSelectorOracle selector = do
  cases <- sourceAcquisitionIngressExactCases
  let matching =
        [ caseProblems
        | target <- selectorTargets selector
        , (label, caseProblems) <- cases
        , target == label
        ]
      problems =
        selectorRegistryProblems cases
          <> case matching of
            [targetProblems] -> targetProblems
            values ->
              [ "ingress selector intent is not exactly resolvable: selector="
                  <> selector
                  <> "; count="
                  <> show (length values)
              ]
  runSourceAcquisitionIngressControl
  unless
    (null problems)
    (fail ("SourceAcquisitionIngressOracle selector diagnostic failures:\n  " <> unlinesWith "\n  " problems))

runSourceAcquisitionIngressControl :: IO ()
runSourceAcquisitionIngressControl =
  withInput "independent-ingress-control" $ \handle -> do
    result <- sourceAcquisitionIngressTestReadBounded 128 handle
    unless (result == Right "independent-ingress-control")
      (fail "source-acquisition ingress independent control changed")

sourceAcquisitionIngressSelectorIntents :: [(String, String)]
sourceAcquisitionIngressSelectorIntents =
  [ ("VALIDATION_SOURCE_ACQUISITION_INGRESS_EOF_CLASSIFICATION_MUTANT", "single-byte input is retained")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_LIMIT_PREDICATE_BYPASS_MUTANT", "one-over input refuses exactly")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_OBSERVED_ACCUMULATION_MUTANT", "multi-chunk byte order is exact")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_CHUNK_ORDER_MUTANT", "multi-chunk byte order is exact")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_EXPECTED_MANIFEST_FAILURE_ROUTE_BYPASS_MUTANT", "expected-manifest stream failure is retained")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_SIGNED_ENVELOPE_FAILURE_ROUTE_BYPASS_MUTANT", "signed-envelope stream failure is retained")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_IMMUTABLE_BUNDLE_FAILURE_ROUTE_BYPASS_MUTANT", "immutable-bundle stream failure is retained")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_EXPECTED_MANIFEST_SUCCESS_ROUTE_MUTANT", "three ingress byte mappings are exact")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_SIGNED_ENVELOPE_SUCCESS_ROUTE_MUTANT", "three ingress byte mappings are exact")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_IMMUTABLE_BUNDLE_SUCCESS_ROUTE_MUTANT", "three ingress byte mappings are exact")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_EXPECTED_MANIFEST_HANDLE_ROUTE_MUTANT", "three ingress byte mappings are exact")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_SIGNED_ENVELOPE_HANDLE_ROUTE_MUTANT", "three ingress byte mappings are exact")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_IMMUTABLE_BUNDLE_HANDLE_ROUTE_MUTANT", "three ingress byte mappings are exact")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_EXPECTED_MANIFEST_READ_ORDER_MUTANT", "expected-manifest refusal leaves later streams unread")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_SIGNED_ENVELOPE_READ_ORDER_MUTANT", "signed-envelope refusal leaves the bundle unread")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_EXPECTED_MANIFEST_LIMIT_BYPASS_MUTANT", "three stream limits are exact")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_SIGNED_ENVELOPE_LIMIT_BYPASS_MUTANT", "three stream limits are exact")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_IMMUTABLE_BUNDLE_LIMIT_BYPASS_MUTANT", "three stream limits are exact")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_EXPECTED_MANIFEST_MAPPING_MUTANT", "three ingress byte mappings are exact")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_SIGNED_ENVELOPE_MAPPING_MUTANT", "three ingress byte mappings are exact")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_IMMUTABLE_BUNDLE_MAPPING_MUTANT", "three ingress byte mappings are exact")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_EXPECTED_MANIFEST_ACCESSOR_MUTANT", "three ingress byte mappings are exact")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_SIGNED_ENVELOPE_ACCESSOR_MUTANT", "three ingress byte mappings are exact")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_IMMUTABLE_BUNDLE_ACCESSOR_MUTANT", "three ingress byte mappings are exact")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_READ_FAILURE_BYPASS_MUTANT", "expected-manifest stream failure is retained")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_LIMIT_FAILURE_BYPASS_MUTANT", "one-over input refuses exactly")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_FAILURE_ROUTE_BYPASS_MUTANT", "expected-manifest stream failure is retained")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_FAILURE_CHECK_NAME_MUTANT", "one-over input refuses exactly")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_EXPECTED_MANIFEST_STREAM_LABEL_MUTANT", "expected-manifest stream failure is retained")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_SIGNED_ENVELOPE_STREAM_LABEL_MUTANT", "signed-envelope stream failure is retained")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_IMMUTABLE_BUNDLE_STREAM_LABEL_MUTANT", "immutable-bundle stream failure is retained")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_LIMIT_FAILURE_CODE_MUTANT", "one-over input refuses exactly")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_IO_FAILURE_CODE_MUTANT", "expected-manifest stream failure is retained")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_LIMIT_FAILURE_SUBJECT_MUTANT", "one-over input refuses exactly")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_IO_FAILURE_SUBJECT_MUTANT", "expected-manifest stream failure is retained")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_LIMIT_FAILURE_DETAIL_MUTANT", "one-over input refuses exactly")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_IO_FAILURE_DETAIL_MUTANT", "expected-manifest stream failure is retained")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_IO_DETAIL_BOUND_MUTANT", "expected-manifest stream failure is retained")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_STREAM_OBSERVATION_MAPPING_MUTANT", "one-over input refuses exactly")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_STATUS_OBSERVATION_MAPPING_MUTANT", "one-over input refuses exactly")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_LIMIT_OBSERVATION_MAPPING_MUTANT", "one-over input refuses exactly")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_OBSERVED_AT_LEAST_OBSERVATION_MAPPING_MUTANT", "one-over input refuses exactly")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_STREAM_OBSERVATION_OMISSION_MUTANT", "one-over input refuses exactly")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_STATUS_OBSERVATION_OMISSION_MUTANT", "one-over input refuses exactly")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_LIMIT_OBSERVATION_OMISSION_MUTANT", "one-over input refuses exactly")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_OBSERVED_AT_LEAST_OBSERVATION_OMISSION_MUTANT", "one-over input refuses exactly")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_IO_OBSERVATION_INSERTION_MUTANT", "expected-manifest stream failure is retained")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_OBSERVATION_ORDER_MUTANT", "one-over input refuses exactly")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_FAILURE_FINDING_OMISSION_MUTANT", "one-over input refuses exactly")
  , ("VALIDATION_SOURCE_ACQUISITION_INGRESS_LIMIT_OBSERVED_AT_LEAST_MAPPING_MUTANT", "one-over input refuses exactly")
  ]

sourceAcquisitionIngressSelectorNames :: [String]
sourceAcquisitionIngressSelectorNames = map fst sourceAcquisitionIngressSelectorIntents

sourceAcquisitionIngressExactCases :: IO [(String, [String])]
sourceAcquisitionIngressExactCases = do
  singleByte <- boundedResult 8 "x"
  oneOver <- boundedResult 3 "abcd"
  let firstChunk = ByteString.replicate (32 * 1024) 97
      secondChunk = ByteString.replicate 91 98
      orderedBytes = firstChunk <> secondChunk
  multiChunk <- boundedResult (ByteString.length orderedBytes) orderedBytes
  ingress <- threeStreamResult "manifest" "signed-envelope" "immutable-bundle"
  (expectedManifestFailure, expectedWirePosition, expectedBundlePosition) <-
    closedStreamIngressResult OracleExpectedManifestIngress
  (signedEnvelopeFailure, _, signedBundlePosition) <-
    closedStreamIngressResult OracleSignedEnvelopeIngress
  (immutableBundleFailure, _, _) <-
    closedStreamIngressResult OracleImmutableBundleIngress
  pure
    [ ( "single-byte input is retained"
      , expectEqual "single-byte result" (Right "x") singleByte
      )
    , ( "one-over input refuses exactly"
      , exactLimitFailureProblems 3 4 oneOver
      )
    , ( "multi-chunk byte order is exact"
      , expectEqual "multi-chunk result" (Right orderedBytes) multiChunk
      )
    , ( "three stream limits are exact"
      , expectEqual
          "routed ingress limits"
          (16 * 1024 * 1024, 40 + 8 + 1 + 16 * 1024 * 1024 + 64, 32 * 1024 * 1024)
          sourceAcquisitionIngressTestRoutedLimits
      )
    , ( "three ingress byte mappings are exact"
      , case ingress of
          Left result -> ["three-stream canonical ingress refused: " <> show result]
          Right acquired ->
            expectEqual "expected-manifest bytes" "manifest" (ingressExpectedManifestBytes acquired)
              <> expectEqual "signed-envelope bytes" "signed-envelope" (ingressWireBytes acquired)
              <> expectEqual "immutable-bundle bytes" "immutable-bundle" (ingressBundleBytes acquired)
      )
    , ( "expected-manifest stream failure is retained"
      , exactIngressIoFailureProblems "expected-manifest" expectedManifestFailure
      )
    , ( "signed-envelope stream failure is retained"
      , exactIngressIoFailureProblems "signed-envelope" signedEnvelopeFailure
      )
    , ( "immutable-bundle stream failure is retained"
      , exactIngressIoFailureProblems "immutable-bundle" immutableBundleFailure
      )
    , ( "expected-manifest refusal leaves later streams unread"
      , expectEqual "wire position after expected-manifest refusal" (Just 0) expectedWirePosition
          <> expectEqual "bundle position after expected-manifest refusal" (Just 0) expectedBundlePosition
      )
    , ( "signed-envelope refusal leaves the bundle unread"
      , expectEqual "bundle position after signed-envelope refusal" (Just 0) signedBundlePosition
      )
    ]

boundedResult :: Int -> ByteString -> IO (Either CheckResult ByteString)
boundedResult limit bytes =
  withInput bytes (sourceAcquisitionIngressTestReadBounded limit)

threeStreamResult
  :: ByteString
  -> ByteString
  -> ByteString
  -> IO (Either CheckResult SourceAcquisitionIngress)
threeStreamResult expectedManifest wire bundle =
  withInput expectedManifest $ \expectedManifestHandle ->
    withInput wire $ \wireHandle ->
      withInput bundle $ \bundleHandle ->
        readSourceAcquisitionIngress expectedManifestHandle wireHandle bundleHandle

closedStreamIngressResult
  :: OracleIngressStream
  -> IO (Either CheckResult SourceAcquisitionIngress, Maybe Integer, Maybe Integer)
closedStreamIngressResult closedStream =
  withInput "manifest" $ \expectedManifestHandle ->
    withInput "signed-envelope" $ \wireHandle ->
      withInput "immutable-bundle" $ \bundleHandle -> do
        case closedStream of
          OracleExpectedManifestIngress -> hClose expectedManifestHandle
          OracleSignedEnvelopeIngress -> hClose wireHandle
          OracleImmutableBundleIngress -> hClose bundleHandle
        result <- readSourceAcquisitionIngress expectedManifestHandle wireHandle bundleHandle
        wirePosition <- safeHandlePosition wireHandle
        bundlePosition <- safeHandlePosition bundleHandle
        pure (result, wirePosition, bundlePosition)

safeHandlePosition :: Handle -> IO (Maybe Integer)
safeHandlePosition handle = do
  result <- try (hTell handle) :: IO (Either IOException Integer)
  pure (either (const Nothing) Just result)

withInput :: ByteString -> (Handle -> IO value) -> IO value
withInput bytes action = bracket acquire release (action . snd)
 where
  acquire = do
    temporary <- getTemporaryDirectory
    (path, writer) <- openBinaryTempFile temporary "amoebius-source-acquisition-ingress"
    ByteString.hPut writer bytes
    hClose writer
    reader <- openBinaryFile path ReadMode
    pure (path, reader)
  release (path, handle) = do
    _ <- try (hClose handle) :: IO (Either IOException ())
    removeFile path

exactLimitFailureProblems :: Int -> Int -> Either CheckResult ByteString -> [String]
exactLimitFailureProblems limit observed result = case result of
  Right bytes -> ["one-over input was accepted: retained=" <> show bytes]
  Left check ->
    expectEqual "limit check name" "source-acquisition-ingress" (checkName check)
      <> expectEqual
        "limit observations"
        [ ("source-acquisition.ingress.stream", "expected-manifest")
        , ("source-acquisition.ingress.status", "refused")
        , ("source-acquisition.ingress.limit", Text.pack (show limit))
        , ("source-acquisition.ingress.observed-at-least", Text.pack (show observed))
        ]
        [(observationKey item, observationValue item) | item <- checkObservations check]
      <> expectEqual
        "limit findings"
        [ ( "SOURCE-ACQUISITION-INGRESS-LIMIT"
          , "source-acquisition/ingress/expected-manifest"
          , "bounded streaming input exceeded "
              <> Text.pack (show limit)
              <> " bytes; observed at least "
              <> Text.pack (show observed)
          )
        ]
        [ (findingCode item, findingSubject item, findingDetail item)
        | item <- checkFindings check
        ]

exactIngressIoFailureProblems
  :: Text.Text
  -> Either CheckResult SourceAcquisitionIngress
  -> [String]
exactIngressIoFailureProblems streamLabel result = case result of
  Right ingress -> ["closed-handle read was accepted: retained=" <> show ingress]
  Left check ->
    expectEqual "IO check name" "source-acquisition-ingress" (checkName check)
      <> expectEqual
        "IO observations"
        [ ("source-acquisition.ingress.stream", streamLabel)
        , ("source-acquisition.ingress.status", "refused")
        ]
        [(observationKey item, observationValue item) | item <- checkObservations check]
      <> case checkFindings check of
        [item] ->
          expectEqual "IO finding code" "SOURCE-ACQUISITION-INGRESS-IO" (findingCode item)
            <> expectEqual
              "IO finding subject"
              ("source-acquisition/ingress/" <> Text.unpack streamLabel)
              (findingSubject item)
            <> [ "IO finding detail has the wrong stable prefix: " <> Text.unpack (findingDetail item)
               | not ("bounded streaming read failed: " `Text.isPrefixOf` findingDetail item)
               ]
            <> [ "IO finding detail exceeded its independent bound"
               | Text.length (findingDetail item) > 256 + Text.length "bounded streaming read failed: "
               ]
        items -> ["IO finding cardinality mismatch: " <> show items]

selectorTargets :: String -> [String]
selectorTargets selector =
  [ target
  | (candidate, target) <- sourceAcquisitionIngressSelectorIntents
  , candidate == selector
  ]

selectorRegistryProblems :: [(String, [String])] -> [String]
selectorRegistryProblems cases =
  ["duplicate selector intent: " <> value | value <- duplicates (map fst sourceAcquisitionIngressSelectorIntents)]
    <> ["duplicate exact-case label: " <> value | value <- duplicates (map fst cases)]
    <> [ "selector target is absent from exact cases: " <> target
       | (_, target) <- sourceAcquisitionIngressSelectorIntents
       , target `notElem` map fst cases
       ]
    <> [ "exact case has no selector assignment: " <> label
       | (label, _) <- cases
       , label `notElem` map snd sourceAcquisitionIngressSelectorIntents
       ]

duplicates :: Ord value => [value] -> [value]
duplicates = foldr repeated [] . group . sort
 where
  repeated (value : _ : _) rest = value : rest
  repeated _ rest = rest

expectEqual :: (Eq value, Show value) => String -> value -> value -> [String]
expectEqual label expected actual =
  [label <> " mismatch; expected=" <> show expected <> "; actual=" <> show actual | expected /= actual]

unlinesWith :: String -> [String] -> String
unlinesWith _ [] = ""
unlinesWith separator (first : rest) = first <> concatMap (separator <>) rest
