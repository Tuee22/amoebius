{-# LANGUAGE OverloadedStrings #-}

module SourceAcquisitionDispatchOracle
  ( runSourceAcquisitionDispatchControl
  , runSourceAcquisitionDispatchOracle
  , runSourceAcquisitionDispatchSelectorOracle
  , sourceAcquisitionDispatchSelectorIntents
  , sourceAcquisitionDispatchSelectorNames
  ) where

import Amoebius.Validation.SourceAcquisition.Internal
  ( AnchoredSourceAcquisitionSession
  , anchorSourceAcquisitionSession
  )
import Amoebius.Validation.SourceAcquisitionDispatch.Internal
  ( runSourceAcquisitionDispatch
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
import Data.Text qualified as Text
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

runSourceAcquisitionDispatchOracle :: IO ()
runSourceAcquisitionDispatchOracle = do
  inputs <- canonicalAcquisitionInputs
  cases <- sourceAcquisitionDispatchExactCases inputs
  let problems = selectorRegistryProblems cases <> concatMap snd cases
  unless
    (null problems)
    (fail ("SourceAcquisitionDispatchOracle component diagnostic failures:\n  " <> unlinesWith "\n  " problems))

runSourceAcquisitionDispatchSelectorOracle :: String -> IO ()
runSourceAcquisitionDispatchSelectorOracle selector = do
  inputs <- canonicalAcquisitionInputs
  cases <- sourceAcquisitionDispatchExactCases inputs
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
              [ "source-acquisition dispatch selector is not exactly resolvable: selector="
                  <> selector
                  <> "; count="
                  <> show (length values)
              ]
  runSourceAcquisitionDispatchControl
  unless
    (null problems)
    (fail ("SourceAcquisitionDispatchOracle selector diagnostic failures:\n  " <> unlinesWith "\n  " problems))

runSourceAcquisitionDispatchControl :: IO ()
runSourceAcquisitionDispatchControl = runSourceAcquisitionCanonicalControl

sourceAcquisitionDispatchSelectorIntents :: [(String, String)]
sourceAcquisitionDispatchSelectorIntents =
  [ ("VALIDATION_SOURCE_ACQUISITION_DISPATCH_PIPELINE_FAILURE_MAPPING_MUTANT", "pipeline refusal reaches dispatch unchanged")
  , ("VALIDATION_SOURCE_ACQUISITION_DISPATCH_PIPELINE_SUCCESS_ROUTE_MUTANT", "pipeline success invokes the acquired checker")
  ]

sourceAcquisitionDispatchSelectorNames :: [String]
sourceAcquisitionDispatchSelectorNames = map fst sourceAcquisitionDispatchSelectorIntents

sourceAcquisitionDispatchExactCases
  :: CanonicalAcquisitionInputs
  -> IO [(String, [String])]
sourceAcquisitionDispatchExactCases inputs = do
  success <-
    runDispatch
      inputs
      (canonicalInputWireBytes inputs)
  failure <-
    runDispatch
      inputs
      (corruptLastByte (canonicalInputWireBytes inputs))
  pure
    [ ( "pipeline success invokes the acquired checker"
      , expectEqual "acquired checker projection" (expectedAcquiredCheck inputs) success
      )
    , ( "pipeline refusal reaches dispatch unchanged"
      , expectEqual "signature refusal projection" signatureRefusal failure
      )
    ]

runDispatch
  :: CanonicalAcquisitionInputs
  -> ByteString
  -> IO CheckResult
runDispatch inputs wire =
  withInput (canonicalInputExpectedManifestBytes inputs) $ \expectedManifestHandle ->
    withInput wire $ \wireHandle ->
      withInput (canonicalInputBundleBytes inputs) $ \bundleHandle ->
        runSourceAcquisitionDispatch
          acquiredCheck
          (canonicalSession inputs)
          (canonicalInputReplayIdentity inputs)
          expectedManifestHandle
          wireHandle
          bundleHandle

acquiredCheck :: AcquiredSourceSnapshot -> IO CheckResult
acquiredCheck acquired =
  pure
    CheckResult
      { checkName = "independent-acquired-dispatch-control"
      , checkObservations =
          [ Observation "dispatch.snapshot.identity" (snapshotIdentity snapshot)
          , Observation
              "dispatch.snapshot.paths"
              (Text.intercalate "," (map (Text.pack . indexPath . trackedIndex) (snapshotEntries snapshot)))
          , Observation
              "dispatch.snapshot.bundle-bytes"
              (Text.pack (show bundleLength))
          ]
      , checkFindings = []
      }
 where
  snapshot = acquiredSourceSnapshot acquired
  bundleLength = ByteString.length (ByteString.concat (map trackedBytes (snapshotEntries snapshot)))

expectedAcquiredCheck :: CanonicalAcquisitionInputs -> CheckResult
expectedAcquiredCheck inputs =
  CheckResult
    { checkName = "independent-acquired-dispatch-control"
    , checkObservations =
        [ Observation "dispatch.snapshot.identity" (canonicalInputSourceSnapshotIdentity inputs)
        , Observation
            "dispatch.snapshot.paths"
            (Text.intercalate "," (map Text.pack (canonicalInputExpectedPaths inputs)))
        , Observation
            "dispatch.snapshot.bundle-bytes"
            (Text.pack (show (ByteString.length (canonicalInputBundleBytes inputs))))
        ]
    , checkFindings = []
    }

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
    (path, writer) <- openBinaryTempFile temporary "amoebius-source-acquisition-dispatch"
    ByteString.hPut writer bytes
    hClose writer
    reader <- openBinaryFile path ReadMode
    pure (path, reader)
  release (path, handle) = do
    _ <- try (hClose handle) :: IO (Either IOException ())
    removeFile path

corruptLastByte :: ByteString -> ByteString
corruptLastByte bytes = case ByteString.unsnoc bytes of
  Nothing -> ByteString.singleton 1
  Just (prefix, value) -> prefix <> ByteString.singleton (value `xor` 1)

signatureRefusal :: CheckResult
signatureRefusal =
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
  | (candidate, target) <- sourceAcquisitionDispatchSelectorIntents
  , candidate == selector
  ]

selectorRegistryProblems :: [(String, [String])] -> [String]
selectorRegistryProblems cases =
  [ "source-acquisition dispatch selector registry cardinality changed: expected=2; observed="
      <> show (length sourceAcquisitionDispatchSelectorIntents)
  | length sourceAcquisitionDispatchSelectorIntents /= 2
  ]
    <> duplicateProblems "source-acquisition dispatch selector" sourceAcquisitionDispatchSelectorNames
    <> duplicateProblems "source-acquisition dispatch exact-case label" (map fst cases)
    <> [ "source-acquisition dispatch selector target is absent: " <> target
       | target <- map snd sourceAcquisitionDispatchSelectorIntents
       , target `notElem` map fst cases
       ]
    <> [ "source-acquisition dispatch exact case has no selector: " <> label
       | label <- map fst cases
       , label `notElem` map snd sourceAcquisitionDispatchSelectorIntents
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
