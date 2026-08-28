{-# LANGUAGE OverloadedStrings #-}

module SourceAcquisitionPipelineOracle
  ( runSourceAcquisitionPipelineControl
  , runSourceAcquisitionPipelineOracle
  , runSourceAcquisitionPipelineSelectorOracle
  , sourceAcquisitionPipelineSelectorIntents
  , sourceAcquisitionPipelineSelectorNames
  ) where

import Amoebius.Validation.SourceAcquisition.Internal
  ( AnchoredSourceAcquisitionSession
  , anchorSourceAcquisitionSession
  )
import Amoebius.Validation.SourceAcquisitionPipeline.Internal
  ( runSourceAcquisitionPipeline
  )
import Amoebius.Validation.SourceClosure.Internal
  ( AcquiredSourceSnapshot
  , IndexEntry (indexPath)
  , SourceSnapshot (..)
  , TrackedEntry (..)
  , acquiredSourceSnapshot
  )
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding (..)
  , Observation (..)
  )
import Control.Exception (IOException, bracket, try)
import Control.Monad (unless)
import Data.Bits (xor)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.List (group, sort)
import Data.Set qualified as Set
import Data.Word (Word8)
import SourceAcquisitionOracle
  ( CanonicalAcquisitionInputs (..)
  , canonicalAcquisitionInputs
  , runSourceAcquisitionCanonicalControl
  )
import System.Directory (getTemporaryDirectory, removeFile)
import System.IO
  ( Handle
  , IOMode (ReadMode)
  , hClose
  , openBinaryFile
  , openBinaryTempFile
  )

runSourceAcquisitionPipelineOracle :: IO ()
runSourceAcquisitionPipelineOracle = do
  inputs <- canonicalAcquisitionInputs
  cases <- sourceAcquisitionPipelineExactCases inputs
  let problems = selectorRegistryProblems cases <> concatMap snd cases
  unless
    (null problems)
    (fail ("SourceAcquisitionPipelineOracle component diagnostic failures:\n  " <> unlinesWith "\n  " problems))

runSourceAcquisitionPipelineSelectorOracle :: String -> IO ()
runSourceAcquisitionPipelineSelectorOracle selector = do
  inputs <- canonicalAcquisitionInputs
  cases <- sourceAcquisitionPipelineExactCases inputs
  let matching =
        [ caseProblems
        | target <- selectorTargets selector
        , (label, caseProblems) <- cases
        , label == target
        ]
      problems =
        selectorRegistryProblems cases
          <> case matching of
            [targetProblems] -> targetProblems
            values ->
              [ "pipeline selector intent is not exactly resolvable: selector="
                  <> selector
                  <> "; count="
                  <> show (length values)
              ]
  runSourceAcquisitionPipelineControl
  unless
    (null problems)
    (fail ("SourceAcquisitionPipelineOracle selector diagnostic failures:\n  " <> unlinesWith "\n  " problems))

runSourceAcquisitionPipelineControl :: IO ()
runSourceAcquisitionPipelineControl = runSourceAcquisitionCanonicalControl

sourceAcquisitionPipelineSelectorIntents :: [(String, String)]
sourceAcquisitionPipelineSelectorIntents =
  [ ("VALIDATION_SOURCE_ACQUISITION_PIPELINE_INGRESS_FAILURE_MAPPING_MUTANT", "ingress refusal is retained")
  , ("VALIDATION_SOURCE_ACQUISITION_PIPELINE_INGRESS_SUCCESS_ROUTE_MUTANT", "verified pipeline success is exact")
  , ("VALIDATION_SOURCE_ACQUISITION_PIPELINE_EXPECTED_MANIFEST_ROUTE_MUTANT", "verified pipeline success is exact")
  , ("VALIDATION_SOURCE_ACQUISITION_PIPELINE_SIGNED_ENVELOPE_ROUTE_MUTANT", "verified pipeline success is exact")
  , ("VALIDATION_SOURCE_ACQUISITION_PIPELINE_IMMUTABLE_BUNDLE_ROUTE_MUTANT", "verified pipeline success is exact")
  , ("VALIDATION_SOURCE_ACQUISITION_PIPELINE_VERIFICATION_FAILURE_MAPPING_MUTANT", "verifier refusal is retained")
  , ("VALIDATION_SOURCE_ACQUISITION_PIPELINE_VERIFICATION_SUCCESS_ROUTE_MUTANT", "verified pipeline success is exact")
  ]

sourceAcquisitionPipelineSelectorNames :: [String]
sourceAcquisitionPipelineSelectorNames = map fst sourceAcquisitionPipelineSelectorIntents

sourceAcquisitionPipelineExactCases
  :: CanonicalAcquisitionInputs
  -> IO [(String, [String])]
sourceAcquisitionPipelineExactCases inputs = do
  success <-
    runCanonicalPipeline
      inputs
      (canonicalInputExpectedManifestBytes inputs)
      (canonicalInputWireBytes inputs)
      (canonicalInputBundleBytes inputs)
  verifierFailure <-
    runCanonicalPipeline
      inputs
      (canonicalInputExpectedManifestBytes inputs)
      (corruptLastByte (canonicalInputWireBytes inputs))
      (canonicalInputBundleBytes inputs)
  ingressFailure <- runClosedExpectedManifestPipeline inputs
  pure
    [ ("verified pipeline success is exact", pipelineSuccessProblems inputs success)
    , ("verifier refusal is retained", expectEqual "signature refusal" signatureRefusal verifierFailure)
    , ("ingress refusal is retained", ingressFailureProblems ingressFailure)
    ]

pipelineSuccessProblems
  :: CanonicalAcquisitionInputs
  -> Either CheckResult AcquiredSourceSnapshot
  -> [String]
pipelineSuccessProblems inputs result = case result of
  Left refusal -> ["canonical pipeline refused: " <> show refusal]
  Right acquired ->
    let snapshot = acquiredSourceSnapshot acquired
     in expectEqual
          "pipeline snapshot identity"
          (canonicalInputSourceSnapshotIdentity inputs)
          (snapshotIdentity snapshot)
          <> expectEqual
            "pipeline path order"
            (canonicalInputExpectedPaths inputs)
            (map (indexPath . trackedIndex) (snapshotEntries snapshot))
          <> expectEqual
            "pipeline bundle bytes"
            (canonicalInputBundleBytes inputs)
            (ByteString.concat (map trackedBytes (snapshotEntries snapshot)))

ingressFailureProblems
  :: Either CheckResult AcquiredSourceSnapshot
  -> [String]
ingressFailureProblems result = case result of
  Right acquired -> ["closed expected-manifest stream minted an acquired snapshot: " <> show acquired]
  Left refusal ->
    expectEqual "ingress failure check name" "source-acquisition-ingress" (checkName refusal)
      <> expectEqual
        "ingress failure observations"
        [ Observation "source-acquisition.ingress.stream" "expected-manifest"
        , Observation "source-acquisition.ingress.status" "refused"
        ]
        (checkObservations refusal)
      <> case checkFindings refusal of
        [item] ->
          expectEqual "ingress failure code" "SOURCE-ACQUISITION-INGRESS-IO" (findingCode item)
            <> expectEqual
              "ingress failure subject"
              "source-acquisition/ingress/expected-manifest"
              (findingSubject item)
        items -> ["ingress failure finding cardinality mismatch: " <> show items]

runCanonicalPipeline
  :: CanonicalAcquisitionInputs
  -> ByteString
  -> ByteString
  -> ByteString
  -> IO (Either CheckResult AcquiredSourceSnapshot)
runCanonicalPipeline inputs expectedManifest wire bundle =
  withInput expectedManifest $ \expectedManifestHandle ->
    withInput wire $ \wireHandle ->
      withInput bundle $ \bundleHandle ->
        runSourceAcquisitionPipeline
          (canonicalSession inputs)
          (canonicalInputReplayIdentity inputs)
          expectedManifestHandle
          wireHandle
          bundleHandle

runClosedExpectedManifestPipeline
  :: CanonicalAcquisitionInputs
  -> IO (Either CheckResult AcquiredSourceSnapshot)
runClosedExpectedManifestPipeline inputs =
  withInput (canonicalInputExpectedManifestBytes inputs) $ \expectedManifestHandle ->
    withInput (canonicalInputWireBytes inputs) $ \wireHandle ->
      withInput (canonicalInputBundleBytes inputs) $ \bundleHandle -> do
        hClose expectedManifestHandle
        runSourceAcquisitionPipeline
          (canonicalSession inputs)
          (canonicalInputReplayIdentity inputs)
          expectedManifestHandle
          wireHandle
          bundleHandle

canonicalSession
  :: CanonicalAcquisitionInputs
  -> AnchoredSourceAcquisitionSession
canonicalSession inputs =
  anchorSourceAcquisitionSession
    (canonicalInputPhase inputs)
    (canonicalInputAuthority inputs)
    (canonicalInputObserverToolDigest inputs)
    (canonicalInputChallenge inputs)
    Set.empty
    (canonicalInputRepositoryIdentity inputs)
    (canonicalInputRequestedRevision inputs)
    (canonicalInputHeadIdentity inputs)
    (canonicalInputSourceSnapshotIdentity inputs)
    (canonicalInputAuthoredRootIdentity inputs)
    (canonicalInputExpectedManifestBytes inputs)
    (canonicalInputPublicKeyBytes inputs)

withInput :: ByteString -> (Handle -> IO value) -> IO value
withInput bytes action = bracket acquire release (action . snd)
 where
  acquire = do
    temporary <- getTemporaryDirectory
    (path, writer) <- openBinaryTempFile temporary "amoebius-source-acquisition-pipeline"
    ByteString.hPut writer bytes
    hClose writer
    reader <- openBinaryFile path ReadMode
    pure (path, reader)
  release (path, handle) = do
    _ <- try (hClose handle) :: IO (Either IOException ())
    removeFile path

corruptLastByte :: ByteString -> ByteString
corruptLastByte bytes =
  case ByteString.unsnoc bytes of
    Nothing -> ByteString.singleton 1
    Just (prefix, value) -> prefix <> ByteString.singleton (value `xorWord8` 1)

xorWord8 :: Word8 -> Word8 -> Word8
xorWord8 = xor

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

selectorTargets :: String -> [String]
selectorTargets selector =
  [ target
  | (candidate, target) <- sourceAcquisitionPipelineSelectorIntents
  , candidate == selector
  ]

selectorRegistryProblems :: [(String, [String])] -> [String]
selectorRegistryProblems cases =
  [ "pipeline selector registry cardinality changed: expected=7; observed="
      <> show (length sourceAcquisitionPipelineSelectorIntents)
  | length sourceAcquisitionPipelineSelectorIntents /= 7
  ]
    <> duplicateProblems "pipeline selector" sourceAcquisitionPipelineSelectorNames
    <> duplicateProblems "pipeline exact-case label" (map fst cases)
    <> [ "pipeline selector target is absent: " <> target
       | target <- map snd sourceAcquisitionPipelineSelectorIntents
       , target `notElem` map fst cases
       ]
    <> [ "pipeline exact case has no selector: " <> label
       | label <- map fst cases
       , label `notElem` map snd sourceAcquisitionPipelineSelectorIntents
       ]

duplicateProblems :: String -> [String] -> [String]
duplicateProblems kind values =
  [ kind <> " is duplicated: " <> value
  | valuesAtGroup <- group (sort values)
  , value : _ <- [valuesAtGroup]
  , length valuesAtGroup > 1
  ]

expectEqual :: (Eq value, Show value) => String -> value -> value -> [String]
expectEqual label expected actual =
  [label <> " mismatch; expected=" <> show expected <> "; actual=" <> show actual | expected /= actual]

unlinesWith :: String -> [String] -> String
unlinesWith _ [] = ""
unlinesWith separator (first : rest) = first <> concatMap (separator <>) rest
