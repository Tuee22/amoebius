{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Storage.Rebind
import System.Exit (die)

main :: IO ()
main = do
  assertEqual "real cluster absence" (Right ()) (validateClusterAbsence (ClusterAbsenceObservation True True True True))
  assertEqual "soft delete rejected" (Left ClusterStillPresent) (validateClusterAbsence (ClusterAbsenceObservation False False False True))
  assertEqual "missing backing rejected" (Left BackingMissingWhileClusterAbsent) (validateClusterAbsence (ClusterAbsenceObservation True True True False))
  assertEqual "fresh CA and UID" (Right ()) (validateFreshCluster (RecreatedClusterObservation "ca-old" "ca-new" "uid-old" "uid-new"))
  assertEqual "same CA rejected" (Left RecreatedClusterNotFresh) (validateFreshCluster (RecreatedClusterObservation "ca" "ca" "uid-old" "uid-new"))
  let clean = MarkerPathObservation True True True 0 []
  assertEqual "clean marker path" (Right ()) (validateMarkerPath clean)
  assertEqual "seed marker rejected" (Left MarkerWasPreseeded) (validateMarkerPath clean {markerAbsentBeforeWrite = False, witnessSeedCommands = ["seed-marker"]})
  assertEqual "post recreate write rejected" (Left PostRecreateWritePathObserved) (validateMarkerPath clean {postRecreateWriteOperations = 1})
  putStrLn "phase28-rebind-spec: PASS (real absence, fresh cluster, no seed, no post-recreate write)"

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual
  | expected == actual = pure ()
  | otherwise = die (label <> ": expected " <> show expected <> ", got " <> show actual)
