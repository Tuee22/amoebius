{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Package-hidden bounded transport for source-acquisition inputs.
--
-- This module establishes only resource bounds and byte preservation. It does
-- not authenticate a trust root, issue a challenge, reserve a replay identity,
-- verify a signature, or mint an acquired snapshot. The package-hidden
-- supervisor must compose all of those authorities before these bytes can
-- reach the package-hidden verifier.
module Amoebius.Validation.SourceAcquisitionIngress.Internal
  ( SourceAcquisitionIngress
  , ingressBundleBytes
  , ingressExpectedManifestBytes
  , ingressWireBytes
  , readSourceAcquisitionIngress
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_TEST_HOOKS)
  , sourceAcquisitionIngressTestReadBounded
  , sourceAcquisitionIngressTestRoutedLimits
#endif
  ) where

import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding
  , Observation
  , finding
  , observation
  )
import Control.Exception (IOException, displayException, try)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Text (Text)
import Data.Text qualified as Text
import System.IO (Handle)

data SourceAcquisitionIngress = SourceAcquisitionIngress
  { sourceAcquisitionIngressExpectedManifest :: ByteString
  , sourceAcquisitionIngressWire :: ByteString
  , sourceAcquisitionIngressBundle :: ByteString
  }
  deriving (Eq, Show)

data IngressStream
  = ExpectedManifestIngress
  | SignedEnvelopeIngress
  | ImmutableBundleIngress
  deriving (Eq, Ord, Show)

data BoundedReadFailure
  = BoundedReadLimit IngressStream Int Int
  | BoundedReadIo IngressStream Text
  deriving (Eq, Show)

maximumExpectedManifestIngressBytes :: Int
maximumExpectedManifestIngressBytes = 16 * 1024 * 1024

maximumSignedEnvelopeIngressBytes :: Int
maximumSignedEnvelopeIngressBytes =
  40 -- exact @amoebius-source-acquisition-envelope-v2\n@ prefix
    + length (show maximumExpectedManifestIngressBytes)
    + 1
    + maximumExpectedManifestIngressBytes
    + 64

maximumImmutableBundleIngressBytes :: Int
maximumImmutableBundleIngressBytes = 32 * 1024 * 1024

ingressChunkBytes :: Int
ingressChunkBytes = 32 * 1024

maximumIngressIoDetailCharacters :: Int
maximumIngressIoDetailCharacters = 256

-- | Read the three independent transport streams in contract order. Each
-- stream is bounded while it is consumed; no unbounded lazy bytestring or
-- caller-selected size is used. A refusal stops before any later stream is
-- read.
readSourceAcquisitionIngress
  :: Handle
  -> Handle
  -> Handle
  -> IO (Either CheckResult SourceAcquisitionIngress)
readSourceAcquisitionIngress expectedManifestHandle wireHandle bundleHandle = do
  preserveIngressReadOrder ExpectedManifestIngress wireHandle
  expectedManifestResult <-
    readBoundedIngressStream
      ExpectedManifestIngress
      (routedIngressLimit ExpectedManifestIngress maximumExpectedManifestIngressBytes)
      (routedIngressHandle ExpectedManifestIngress expectedManifestHandle wireHandle bundleHandle)
  case routedIngressReadResult ExpectedManifestIngress expectedManifestResult of
    Left problem -> pure (ingressFailure problem)
    Right expectedManifest -> do
      preserveIngressReadOrder SignedEnvelopeIngress bundleHandle
      wireResult <-
        readBoundedIngressStream
          SignedEnvelopeIngress
          (routedIngressLimit SignedEnvelopeIngress maximumSignedEnvelopeIngressBytes)
          (routedIngressHandle SignedEnvelopeIngress expectedManifestHandle wireHandle bundleHandle)
      case routedIngressReadResult SignedEnvelopeIngress wireResult of
        Left problem -> pure (ingressFailure problem)
        Right wire -> do
          bundleResult <-
            readBoundedIngressStream
              ImmutableBundleIngress
              (routedIngressLimit ImmutableBundleIngress maximumImmutableBundleIngressBytes)
              (routedIngressHandle ImmutableBundleIngress expectedManifestHandle wireHandle bundleHandle)
          pure $ case routedIngressReadResult ImmutableBundleIngress bundleResult of
            Left problem -> ingressFailure problem
            Right bundle ->
              Right
                SourceAcquisitionIngress
                  { sourceAcquisitionIngressExpectedManifest =
                      ingressConstructedBytes ExpectedManifestIngress expectedManifest
                  , sourceAcquisitionIngressWire =
                      ingressConstructedBytes SignedEnvelopeIngress wire
                  , sourceAcquisitionIngressBundle =
                      ingressConstructedBytes ImmutableBundleIngress bundle
                  }

readBoundedIngressStream
  :: IngressStream
  -> Int
  -> Handle
  -> IO (Either BoundedReadFailure ByteString)
readBoundedIngressStream stream limit handle = go 0 []
 where
  go observed chunks = do
    nextResult <-
      try (ByteString.hGetSome handle ingressChunkBytes)
        :: IO (Either IOException ByteString)
    case nextResult of
      Left problem ->
        pure
          ( ingressReadFailure
              ( BoundedReadIo
                  stream
                  (boundedIngressIoDetail (Text.pack (displayException problem)))
              )
          )
      Right next
        | ingressEndOfStream next ->
            pure
              ( Right
                  ( ByteString.concat
                      (ingressChunkOrder (reverse chunks))
                  )
              )
        | ingressChunkWouldExceed limit observed (ByteString.length next) ->
            pure
              ( ingressLimitFailure
                  (BoundedReadLimit stream limit (ingressLimitObservedAtLeast limit))
                  (ByteString.concat (reverse chunks))
              )
        | otherwise ->
            go
              (ingressObservedBytes observed (ByteString.length next))
              (next : chunks)

ingressEndOfStream :: ByteString -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_EOF_CLASSIFICATION_MUTANT)
ingressEndOfStream bytes = ByteString.length bytes <= 1
#else
ingressEndOfStream = ByteString.null
#endif

ingressChunkWouldExceed :: Int -> Int -> Int -> Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_LIMIT_PREDICATE_BYPASS_MUTANT)
ingressChunkWouldExceed _ _ _ = False
#else
ingressChunkWouldExceed limit observed next = next > limit - observed
#endif

ingressObservedBytes :: Int -> Int -> Int
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_OBSERVED_ACCUMULATION_MUTANT)
ingressObservedBytes observed next = observed + next + 1
#else
ingressObservedBytes observed next = observed + next
#endif

ingressChunkOrder :: [ByteString] -> [ByteString]
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_CHUNK_ORDER_MUTANT)
ingressChunkOrder = reverse
#else
ingressChunkOrder = id
#endif

boundedIngressIoDetail :: Text -> Text
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_IO_DETAIL_BOUND_MUTANT)
boundedIngressIoDetail value =
  Text.take maximumIngressIoDetailCharacters value
    <> Text.replicate maximumIngressIoDetailCharacters "x"
#else
boundedIngressIoDetail = Text.take maximumIngressIoDetailCharacters
#endif

ingressLimitObservedAtLeast :: Int -> Int
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_LIMIT_OBSERVED_AT_LEAST_MAPPING_MUTANT)
ingressLimitObservedAtLeast limit = limit + 2
#else
ingressLimitObservedAtLeast limit = limit + 1
#endif

routedIngressReadResult
  :: IngressStream
  -> Either BoundedReadFailure ByteString
  -> Either BoundedReadFailure ByteString
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_EXPECTED_MANIFEST_FAILURE_ROUTE_BYPASS_MUTANT)
routedIngressReadResult stream result
  | stream == ExpectedManifestIngress = case result of
      Left problem -> problem `seq` Right ByteString.empty
      Right bytes -> Right bytes
  | otherwise = result
#elif defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_SIGNED_ENVELOPE_FAILURE_ROUTE_BYPASS_MUTANT)
routedIngressReadResult stream result
  | stream == SignedEnvelopeIngress = case result of
      Left problem -> problem `seq` Right ByteString.empty
      Right bytes -> Right bytes
  | otherwise = result
#elif defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_IMMUTABLE_BUNDLE_FAILURE_ROUTE_BYPASS_MUTANT)
routedIngressReadResult stream result
  | stream == ImmutableBundleIngress = case result of
      Left problem -> problem `seq` Right ByteString.empty
      Right bytes -> Right bytes
  | otherwise = result
#elif defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_EXPECTED_MANIFEST_SUCCESS_ROUTE_MUTANT)
routedIngressReadResult stream result
  | stream == ExpectedManifestIngress = fmap (ByteString.drop 1) result
  | otherwise = result
#elif defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_SIGNED_ENVELOPE_SUCCESS_ROUTE_MUTANT)
routedIngressReadResult stream result
  | stream == SignedEnvelopeIngress = fmap (ByteString.drop 1) result
  | otherwise = result
#elif defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_IMMUTABLE_BUNDLE_SUCCESS_ROUTE_MUTANT)
routedIngressReadResult stream result
  | stream == ImmutableBundleIngress = fmap (ByteString.drop 1) result
  | otherwise = result
#else
routedIngressReadResult stream result = stream `seq` result
#endif

routedIngressHandle
  :: IngressStream
  -> Handle
  -> Handle
  -> Handle
  -> Handle
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_EXPECTED_MANIFEST_HANDLE_ROUTE_MUTANT)
routedIngressHandle stream expectedManifestHandle wireHandle bundleHandle = case stream of
  ExpectedManifestIngress -> expectedManifestHandle `seq` wireHandle
  SignedEnvelopeIngress -> expectedManifestHandle `seq` wireHandle
  ImmutableBundleIngress -> expectedManifestHandle `seq` bundleHandle
#elif defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_SIGNED_ENVELOPE_HANDLE_ROUTE_MUTANT)
routedIngressHandle stream expectedManifestHandle wireHandle bundleHandle = case stream of
  ExpectedManifestIngress -> wireHandle `seq` expectedManifestHandle
  SignedEnvelopeIngress -> wireHandle `seq` bundleHandle
  ImmutableBundleIngress -> wireHandle `seq` bundleHandle
#elif defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_IMMUTABLE_BUNDLE_HANDLE_ROUTE_MUTANT)
routedIngressHandle stream expectedManifestHandle wireHandle bundleHandle = case stream of
  ExpectedManifestIngress -> bundleHandle `seq` expectedManifestHandle
  SignedEnvelopeIngress -> bundleHandle `seq` wireHandle
  ImmutableBundleIngress -> bundleHandle `seq` expectedManifestHandle
#else
routedIngressHandle stream expectedManifestHandle wireHandle bundleHandle = case stream of
  ExpectedManifestIngress -> expectedManifestHandle
  SignedEnvelopeIngress -> wireHandle
  ImmutableBundleIngress -> bundleHandle
#endif

preserveIngressReadOrder :: IngressStream -> Handle -> IO ()
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_EXPECTED_MANIFEST_READ_ORDER_MUTANT)
preserveIngressReadOrder stream laterHandle
  | stream == ExpectedManifestIngress = do
      _ <- ByteString.hGetSome laterHandle 1
      pure ()
  | otherwise = pure ()
#elif defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_SIGNED_ENVELOPE_READ_ORDER_MUTANT)
preserveIngressReadOrder stream laterHandle
  | stream == SignedEnvelopeIngress = do
      _ <- ByteString.hGetSome laterHandle 1
      pure ()
  | otherwise = pure ()
#else
preserveIngressReadOrder stream laterHandle = stream `seq` laterHandle `seq` pure ()
#endif

routedIngressLimit :: IngressStream -> Int -> Int
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_EXPECTED_MANIFEST_LIMIT_BYPASS_MUTANT)
routedIngressLimit stream limit
  | stream == ExpectedManifestIngress = limit + 1
  | otherwise = limit
#elif defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_SIGNED_ENVELOPE_LIMIT_BYPASS_MUTANT)
routedIngressLimit stream limit
  | stream == SignedEnvelopeIngress = limit + 1
  | otherwise = limit
#elif defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_IMMUTABLE_BUNDLE_LIMIT_BYPASS_MUTANT)
routedIngressLimit stream limit
  | stream == ImmutableBundleIngress = limit + 1
  | otherwise = limit
#else
routedIngressLimit stream limit = stream `seq` limit
#endif

ingressConstructedBytes :: IngressStream -> ByteString -> ByteString
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_EXPECTED_MANIFEST_MAPPING_MUTANT)
ingressConstructedBytes stream bytes
  | stream == ExpectedManifestIngress = ByteString.drop 1 bytes
  | otherwise = bytes
#elif defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_SIGNED_ENVELOPE_MAPPING_MUTANT)
ingressConstructedBytes stream bytes
  | stream == SignedEnvelopeIngress = ByteString.drop 1 bytes
  | otherwise = bytes
#elif defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_IMMUTABLE_BUNDLE_MAPPING_MUTANT)
ingressConstructedBytes stream bytes
  | stream == ImmutableBundleIngress = ByteString.drop 1 bytes
  | otherwise = bytes
#else
ingressConstructedBytes stream bytes = stream `seq` bytes
#endif

ingressReadFailure
  :: BoundedReadFailure
  -> Either BoundedReadFailure ByteString
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_READ_FAILURE_BYPASS_MUTANT)
ingressReadFailure problem = problem `seq` Right ByteString.empty
#else
ingressReadFailure = Left
#endif

ingressLimitFailure
  :: BoundedReadFailure
  -> ByteString
  -> Either BoundedReadFailure ByteString
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_LIMIT_FAILURE_BYPASS_MUTANT)
ingressLimitFailure problem prefix = problem `seq` Right prefix
#else
ingressLimitFailure problem prefix = prefix `seq` Left problem
#endif

ingressFailure
  :: BoundedReadFailure
  -> Either CheckResult SourceAcquisitionIngress
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_FAILURE_ROUTE_BYPASS_MUTANT)
ingressFailure problem =
  problem `seq`
    Right
      SourceAcquisitionIngress
        { sourceAcquisitionIngressExpectedManifest = ByteString.empty
        , sourceAcquisitionIngressWire = ByteString.empty
        , sourceAcquisitionIngressBundle = ByteString.empty
        }
#else
ingressFailure problem = Left (boundedReadFailureResult problem)
#endif

boundedReadFailureResult :: BoundedReadFailure -> CheckResult
boundedReadFailureResult problem =
  CheckResult
    { checkName = ingressFailureCheckName
    , checkObservations =
        ingressFailureObservationOrder
          ( [ ingressStreamObservation stream
            | retainIngressStreamObservation
            ]
              <> [ ingressStatusObservation
                 | retainIngressStatusObservation
                 ]
              <> failureObservations problem
          )
    , checkFindings =
        [ ingressFailureFinding problem
        | retainIngressFailureFinding
        ]
    }
 where
  stream = case problem of
    BoundedReadLimit value _ _ -> value
    BoundedReadIo value _ -> value

failureObservations :: BoundedReadFailure -> [Observation]
failureObservations problem = case problem of
  BoundedReadLimit _ limit observedAtLeast ->
    [ ingressLimitObservation limit
    | retainIngressLimitObservation
    ]
      <> [ ingressObservedAtLeastObservation observedAtLeast
         | retainIngressObservedAtLeastObservation
         ]
  BoundedReadIo {}
    | retainIngressIoEmptyObservations -> []
    | otherwise -> [observation "source-acquisition.ingress.io-mutated" "mutated"]

ingressFailureCheckName :: Text
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_FAILURE_CHECK_NAME_MUTANT)
ingressFailureCheckName = "source-acquisition-ingress-mutated"
#else
ingressFailureCheckName = "source-acquisition-ingress"
#endif

ingressStreamLabel :: IngressStream -> Text
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_EXPECTED_MANIFEST_STREAM_LABEL_MUTANT)
ingressStreamLabel ExpectedManifestIngress = "expected-manifest-mutated"
ingressStreamLabel SignedEnvelopeIngress = "signed-envelope"
ingressStreamLabel ImmutableBundleIngress = "immutable-bundle"
#elif defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_SIGNED_ENVELOPE_STREAM_LABEL_MUTANT)
ingressStreamLabel ExpectedManifestIngress = "expected-manifest"
ingressStreamLabel SignedEnvelopeIngress = "signed-envelope-mutated"
ingressStreamLabel ImmutableBundleIngress = "immutable-bundle"
#elif defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_IMMUTABLE_BUNDLE_STREAM_LABEL_MUTANT)
ingressStreamLabel ExpectedManifestIngress = "expected-manifest"
ingressStreamLabel SignedEnvelopeIngress = "signed-envelope"
ingressStreamLabel ImmutableBundleIngress = "immutable-bundle-mutated"
#else
ingressStreamLabel stream = case stream of
  ExpectedManifestIngress -> "expected-manifest"
  SignedEnvelopeIngress -> "signed-envelope"
  ImmutableBundleIngress -> "immutable-bundle"
#endif

ingressFailureCode :: BoundedReadFailure -> Text
ingressFailureCode problem = case problem of
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_LIMIT_FAILURE_CODE_MUTANT)
  BoundedReadLimit {} -> "SOURCE-ACQUISITION-INGRESS-LIMIT-MUTATED"
#else
  BoundedReadLimit {} -> "SOURCE-ACQUISITION-INGRESS-LIMIT"
#endif
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_IO_FAILURE_CODE_MUTANT)
  BoundedReadIo {} -> "SOURCE-ACQUISITION-INGRESS-IO-MUTATED"
#else
  BoundedReadIo {} -> "SOURCE-ACQUISITION-INGRESS-IO"
#endif

ingressFailureSubject :: BoundedReadFailure -> Text
ingressFailureSubject problem = case problem of
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_LIMIT_FAILURE_SUBJECT_MUTANT)
  BoundedReadLimit stream _ _ -> "source-acquisition/ingress-mutated/" <> ingressStreamLabel stream
#else
  BoundedReadLimit stream _ _ -> "source-acquisition/ingress/" <> ingressStreamLabel stream
#endif
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_IO_FAILURE_SUBJECT_MUTANT)
  BoundedReadIo stream _ -> "source-acquisition/ingress-mutated/" <> ingressStreamLabel stream
#else
  BoundedReadIo stream _ -> "source-acquisition/ingress/" <> ingressStreamLabel stream
#endif

ingressFailureDetail :: BoundedReadFailure -> Text
ingressFailureDetail problem = case problem of
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_LIMIT_FAILURE_DETAIL_MUTANT)
  BoundedReadLimit _ _ _ -> "mutated ingress limit failure detail"
#else
  BoundedReadLimit _ limit observedAtLeast ->
    "bounded streaming input exceeded "
      <> Text.pack (show limit)
      <> " bytes; observed at least "
      <> Text.pack (show observedAtLeast)
#endif
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_IO_FAILURE_DETAIL_MUTANT)
  BoundedReadIo _ _ -> "mutated ingress IO failure detail"
#else
  BoundedReadIo _ detail -> "bounded streaming read failed: " <> detail
#endif

ingressStreamObservation :: IngressStream -> Observation
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_STREAM_OBSERVATION_MAPPING_MUTANT)
ingressStreamObservation stream = observation "source-acquisition.ingress.stream-mutated" (ingressStreamLabel stream)
#else
ingressStreamObservation stream = observation "source-acquisition.ingress.stream" (ingressStreamLabel stream)
#endif

ingressStatusObservation :: Observation
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_STATUS_OBSERVATION_MAPPING_MUTANT)
ingressStatusObservation = observation "source-acquisition.ingress.status" "accepted"
#else
ingressStatusObservation = observation "source-acquisition.ingress.status" "refused"
#endif

ingressLimitObservation :: Int -> Observation
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_LIMIT_OBSERVATION_MAPPING_MUTANT)
ingressLimitObservation limit = observation "source-acquisition.ingress.limit" (Text.pack (show (limit + 1)))
#else
ingressLimitObservation limit = observation "source-acquisition.ingress.limit" (Text.pack (show limit))
#endif

ingressObservedAtLeastObservation :: Int -> Observation
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_OBSERVED_AT_LEAST_OBSERVATION_MAPPING_MUTANT)
ingressObservedAtLeastObservation observed =
  observation "source-acquisition.ingress.observed-at-least" (Text.pack (show (observed + 1)))
#else
ingressObservedAtLeastObservation observed =
  observation "source-acquisition.ingress.observed-at-least" (Text.pack (show observed))
#endif

retainIngressStreamObservation :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_STREAM_OBSERVATION_OMISSION_MUTANT)
retainIngressStreamObservation = False
#else
retainIngressStreamObservation = True
#endif

retainIngressStatusObservation :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_STATUS_OBSERVATION_OMISSION_MUTANT)
retainIngressStatusObservation = False
#else
retainIngressStatusObservation = True
#endif

retainIngressLimitObservation :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_LIMIT_OBSERVATION_OMISSION_MUTANT)
retainIngressLimitObservation = False
#else
retainIngressLimitObservation = True
#endif

retainIngressObservedAtLeastObservation :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_OBSERVED_AT_LEAST_OBSERVATION_OMISSION_MUTANT)
retainIngressObservedAtLeastObservation = False
#else
retainIngressObservedAtLeastObservation = True
#endif

retainIngressIoEmptyObservations :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_IO_OBSERVATION_INSERTION_MUTANT)
retainIngressIoEmptyObservations = False
#else
retainIngressIoEmptyObservations = True
#endif

ingressFailureObservationOrder :: [Observation] -> [Observation]
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_OBSERVATION_ORDER_MUTANT)
ingressFailureObservationOrder = reverse
#else
ingressFailureObservationOrder = id
#endif

ingressFailureFinding :: BoundedReadFailure -> Finding
ingressFailureFinding problem =
  finding
    (ingressFailureCode problem)
    (Text.unpack (ingressFailureSubject problem))
    (ingressFailureDetail problem)

retainIngressFailureFinding :: Bool
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_FAILURE_FINDING_OMISSION_MUTANT)
retainIngressFailureFinding = False
#else
retainIngressFailureFinding = True
#endif

ingressExpectedManifestBytes :: SourceAcquisitionIngress -> ByteString
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_EXPECTED_MANIFEST_ACCESSOR_MUTANT)
ingressExpectedManifestBytes = ByteString.drop 1 . sourceAcquisitionIngressExpectedManifest
#else
ingressExpectedManifestBytes = sourceAcquisitionIngressExpectedManifest
#endif

ingressWireBytes :: SourceAcquisitionIngress -> ByteString
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_SIGNED_ENVELOPE_ACCESSOR_MUTANT)
ingressWireBytes = ByteString.drop 1 . sourceAcquisitionIngressWire
#else
ingressWireBytes = sourceAcquisitionIngressWire
#endif

ingressBundleBytes :: SourceAcquisitionIngress -> ByteString
#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_IMMUTABLE_BUNDLE_ACCESSOR_MUTANT)
ingressBundleBytes = ByteString.drop 1 . sourceAcquisitionIngressBundle
#else
ingressBundleBytes = sourceAcquisitionIngressBundle
#endif

#if defined(VALIDATION_SOURCE_ACQUISITION_INGRESS_TEST_HOOKS)
sourceAcquisitionIngressTestReadBounded
  :: Int
  -> Handle
  -> IO (Either CheckResult ByteString)
sourceAcquisitionIngressTestReadBounded limit handle = do
  result <- readBoundedIngressStream ExpectedManifestIngress limit handle
  pure $ case result of
    Left problem -> Left (boundedReadFailureResult problem)
    Right bytes -> Right bytes

sourceAcquisitionIngressTestRoutedLimits :: (Int, Int, Int)
sourceAcquisitionIngressTestRoutedLimits =
  ( routedIngressLimit ExpectedManifestIngress maximumExpectedManifestIngressBytes
  , routedIngressLimit SignedEnvelopeIngress maximumSignedEnvelopeIngressBytes
  , routedIngressLimit ImmutableBundleIngress maximumImmutableBundleIngressBytes
  )
#endif
