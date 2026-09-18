{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

module Amoebius.Storage.Rebind
  ( ClusterAbsenceObservation (..)
  , RecreatedClusterObservation (..)
  , MarkerPathObservation (..)
  , RebindError (..)
  , validateClusterAbsence
  , validateFreshCluster
  , validateMarkerPath
  ) where

import Control.DeepSeq (NFData)
import Data.Text (Text)
import GHC.Generics (Generic)

data ClusterAbsenceObservation = ClusterAbsenceObservation
  { observedKindClusterAbsent :: Bool
  , observedNodeContainerAbsent :: Bool
  , observedApiServerUnreachable :: Bool
  , observedBackingPresent :: Bool
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data RecreatedClusterObservation = RecreatedClusterObservation
  { oldServerCaDigest :: Text
  , newServerCaDigest :: Text
  , oldClusterUid :: Text
  , newClusterUid :: Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data MarkerPathObservation = MarkerPathObservation
  { markerAbsentBeforeWrite :: Bool
  , markerWrittenBeforeDelete :: Bool
  , markerReadAfterRecreate :: Bool
  , postRecreateWriteOperations :: Int
  , witnessSeedCommands :: [Text]
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data RebindError
  = ClusterStillPresent
  | BackingMissingWhileClusterAbsent
  | RecreatedClusterNotFresh
  | MarkerWasPreseeded
  | MarkerNotRoundTripped
  | PostRecreateWritePathObserved
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

validateClusterAbsence :: ClusterAbsenceObservation -> Either RebindError ()
validateClusterAbsence observation
  | not (observedKindClusterAbsent observation && observedNodeContainerAbsent observation && observedApiServerUnreachable observation) = Left ClusterStillPresent
  | not (observedBackingPresent observation) = Left BackingMissingWhileClusterAbsent
  | otherwise = Right ()

validateFreshCluster :: RecreatedClusterObservation -> Either RebindError ()
validateFreshCluster observation
  | oldServerCaDigest observation == newServerCaDigest observation = Left RecreatedClusterNotFresh
  | oldClusterUid observation == newClusterUid observation = Left RecreatedClusterNotFresh
  | otherwise = Right ()

validateMarkerPath :: MarkerPathObservation -> Either RebindError ()
validateMarkerPath observation
  | not (markerAbsentBeforeWrite observation) || not (null (witnessSeedCommands observation)) = Left MarkerWasPreseeded
  | not (markerWrittenBeforeDelete observation && markerReadAfterRecreate observation) = Left MarkerNotRoundTripped
  | postRecreateWriteOperations observation /= 0 = Left PostRecreateWritePathObserved
  | otherwise = Right ()
