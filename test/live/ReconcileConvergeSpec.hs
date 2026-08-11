{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Data.Aeson (FromJSON (parseJSON), eitherDecodeFileStrict', withObject, (.:))
import Data.Text (Text)
import System.Exit (die)

data Evidence = Evidence Int Text PrivatePull CustomResource QuotaRace Rerun NegativeControls Postflight
data PrivatePull = PrivatePull Bool Int Int Double
data CustomResource = CustomResource Bool Child
data Child = Child Bool
data QuotaRace = QuotaRace Int Int Int Int Int
data Rerun = Rerun Text Text Bool Int Int Int
data NegativeControls = NegativeControls Int Text Text
data Postflight = Postflight Bool Bool Bool Bool

instance FromJSON Evidence where
  parseJSON = withObject "Phase26Evidence" $ \value ->
    Evidence <$> value .: "register" <*> value .: "substrate" <*> value .: "privatePullDeployment"
      <*> value .: "customResource" <*> value .: "quotaRace" <*> value .: "rerun" <*> value .: "negativeControls" <*> value .: "postflight"

instance FromJSON PrivatePull where
  parseJSON = withObject "PrivatePull" $ \value ->
    PrivatePull <$> value .: "available" <*> value .: "initialAvailableReplicas"
      <*> value .: "initialDelaySeconds" <*> value .: "readyElapsedSeconds"

instance FromJSON CustomResource where
  parseJSON = withObject "CustomResource" $ \value -> CustomResource <$> value .: "healthy" <*> value .: "child"

instance FromJSON Child where
  parseJSON = withObject "Child" $ \value -> Child <$> value .: "conforms"

instance FromJSON QuotaRace where
  parseJSON = withObject "QuotaRace" $ \value ->
    QuotaRace <$> value .: "simultaneousReservations" <*> value .: "admittedChildren"
      <*> value .: "hardPods" <*> value .: "usedPods" <*> value .: "overAllocation"

instance FromJSON Rerun where
  parseJSON = withObject "Rerun" $ \value ->
    Rerun <$> value .: "beforeHash" <*> value .: "afterHash" <*> value .: "byteStable"
      <*> value .: "objectCount" <*> value .: "plannedMutations" <*> value .: "terminalRetentionActions"

instance FromJSON NegativeControls where
  parseJSON = withObject "NegativeControls" $ \value ->
    NegativeControls <$> value .: "neverReadyExit" <*> value .: "neverReadyResult" <*> value .: "overboundResult"

instance FromJSON Postflight where
  parseJSON = withObject "Postflight" $ \value ->
    Postflight <$> value .: "namespaceAbsent" <*> value .: "raceNamespaceAbsent"
      <*> value .: "crdAbsent" <*> value .: "persistentVolumeAbsent"

main :: IO ()
main = do
  decoded <- eitherDecodeFileStrict' "DEVELOPMENT_PLAN/evidence/phase_26/live-reconcile.json"
  case decoded of
    Left problem -> die problem
    Right evidence -> verify evidence
  putStrLn "reconcile-converge: PASS (Register-3 live convergence and byte-stable no-op)"

verify :: Evidence -> IO ()
verify (Evidence register substrate (PrivatePull available initial delay elapsed) (CustomResource healthy (Child conforms)) (QuotaRace reservations admitted hard used over) (Rerun before after stable count mutations retention) (NegativeControls neverExit neverResult overResult) (Postflight namespaceAbsent raceNamespaceAbsent crdAbsent pvAbsent))
  | register /= 3 = die "wrong register"
  | substrate /= "linux-cpu" = die "wrong substrate"
  | not available || initial /= 0 || delay <= 0 || elapsed < fromIntegral delay = die "readiness was not live and non-instantaneous"
  | not healthy || not conforms = die "healthy custom resource child did not conform"
  | reservations /= 2 || admitted /= 1 || hard /= 1 || used /= 1 || over /= 0 = die "simultaneous controller-envelope quota race over-allocated"
  | not stable || before /= after || count < 12 || mutations /= 0 || retention /= 1 = die "rerun was not byte-stable and effect-free"
  | neverExit == 0 || neverResult /= "RED" || overResult /= "RED" = die "negative control did not turn red"
  | not (namespaceAbsent && raceNamespaceAbsent && crdAbsent && pvAbsent) = die "live postflight leaked resources"
  | otherwise = pure ()
