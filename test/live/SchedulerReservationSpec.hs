{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Data.Aeson (FromJSON (parseJSON), eitherDecodeFileStrict', withObject, (.:))
import Data.List (nub)
import Data.Text (Text)
import Data.Text qualified as Text
import System.Environment (getArgs)
import System.Exit (die)
import Text.Read (readMaybe)

data Evidence = Evidence Int Text Bindings AggregateRace Rerun Universal Postflight
data Bindings = Bindings [Text] Int Bool Bool Bool Int Double [Reservation]
data Reservation = Reservation Text Text Text Text Text Int Bool Bool Bool
data AggregateRace = AggregateRace Int Int Int Int Int Bool
data Rerun = Rerun Text Text Bool Int Int Bool Bool
data Universal = Universal Bool Pristine
data Pristine = Pristine Text Text Text Text
data Postflight = Postflight Bool Bool Bool Bool Bool Bool Bool Bool Bool Bool

instance FromJSON Evidence where
  parseJSON = withObject "Phase27LiveEvidence" $ \value ->
    Evidence <$> value .: "register" <*> value .: "substrate" <*> value .: "bindings"
      <*> value .: "aggregateRace" <*> value .: "rerun" <*> value .: "universalLinuxCpu" <*> value .: "postflight"

instance FromJSON Bindings where
  parseJSON = withObject "Bindings" $ \value ->
    Bindings <$> value .: "protocol" <*> value .: "requests" <*> value .: "everyBindingAfterCas"
      <*> value .: "everyUidDebitedOnce" <*> value .: "noDoubleBind"
      <*> value .: "guardedReadinessInitialDelaySeconds" <*> value .: "guardedReadyElapsedSeconds"
      <*> value .: "records"

instance FromJSON Reservation where
  parseJSON = withObject "Reservation" $ \value ->
    Reservation <$> value .: "reservation" <*> value .: "podUid"
      <*> value .: "reservedResourceVersion" <*> value .: "bindingInFlightResourceVersion"
      <*> value .: "boundPodResourceVersion" <*> value .: "debitCount"
      <*> value .: "bindingAfterCas" <*> value .: "restartAfterReserveObserved"
      <*> value .: "restartAfterBindingObserved"

instance FromJSON AggregateRace where
  parseJSON = withObject "AggregateRace" $ \value ->
    AggregateRace <$> value .: "simultaneousCandidates" <*> value .: "successfulCas"
      <*> value .: "resourceVersionConflicts" <*> value .: "residualSlots"
      <*> value .: "overAllocation" <*> value .: "loserRefusedAfterRefold"

instance FromJSON Rerun where
  parseJSON = withObject "Rerun" $ \value ->
    Rerun <$> value .: "beforeHash" <*> value .: "afterHash" <*> value .: "byteStable"
      <*> value .: "plannedMutations" <*> value .: "newBindingRequests"
      <*> value .: "sameLeaseHolder" <*> value .: "sameLeaseResourceVersion"

instance FromJSON Universal where
  parseJSON = withObject "UniversalLinuxCpu" $ \value ->
    Universal <$> value .: "availableOnEveryHardwareSubstrate" <*> value .: "pristineLinuxHost"

instance FromJSON Pristine where
  parseJSON = withObject "PristineLinuxHost" $ \value ->
    Pristine <$> value .: "linux" <*> value .: "linux-cuda" <*> value .: "apple" <*> value .: "windows"

instance FromJSON Postflight where
  parseJSON = withObject "Postflight" $ \value ->
    Postflight <$> value .: "namespaceAbsent" <*> value .: "raceNamespaceAbsent"
      <*> value .: "systemNamespaceAbsent" <*> value .: "crdAbsent"
      <*> value .: "policyAbsent" <*> value .: "policyBindingAbsent"
      <*> value .: "bootstrapPolicyAbsent" <*> value .: "bootstrapPolicyBindingAbsent"
      <*> value .: "bindingRbacAbsent" <*> value .: "managedTaintAbsent"

-- The evidence path is the sole argument, supplied by the gate through
-- `--test-options`. A constant here named a plan-tree directory that no longer exists, and
-- a suite reading a fixed location decides on whatever a previous run left behind.
main :: IO ()
main = do
  arguments <- getArgs
  evidence <- case arguments of
    [path] -> pure path
    _ -> die "usage: <suite> <live-scheduler.json>; the gate supplies this run's bundle path"
  decoded <- eitherDecodeFileStrict' evidence
  case decoded of
    Left problem -> die problem
    Right evidence -> verify evidence
  putStrLn "scheduler-reservation: PASS (live CAS-before-Binding, single debit, aggregate race, no-op, and cleanup)"

verify :: Evidence -> IO ()
verify (Evidence register substrate bindings race rerun universal postflight) = do
  if register == 3 && substrate == "linux-cpu" then pure () else die "wrong live register or substrate"
  verifyBindings bindings
  verifyRace race
  verifyRerun rerun
  verifyUniversal universal
  verifyPostflight postflight

verifyBindings :: Bindings -> IO ()
verifyBindings (Bindings protocol requests afterCas once noDoubleBind delay elapsed records)
  | protocol /= ["Reserved", "BindingInFlight", "Binding", "ConfirmedBound", "Bound"] = die "wrong reservation protocol"
  | requests /= 2 || length records /= 2 || not afterCas || not once || not noDoubleBind = die "live Binding domain was not exact"
  | delay <= 0 || elapsed < fromIntegral delay = die "guarded readiness was not observed after its non-zero delay"
  | length (nub [uid | Reservation _ uid _ _ _ _ _ _ _ <- records]) /= length records = die "a Pod UID was debited more than once"
  | otherwise = mapM_ verifyRecord records

verifyRecord :: Reservation -> IO ()
verifyRecord (Reservation name uid reserved inFlight boundPod debit afterCas restartReserved restartBound)
  | Text.null name || Text.null uid = die "reservation identity is empty"
  | debit /= 1 || not afterCas || not restartBound = die "reservation debit/recovery evidence is incomplete"
  | name == "bootstrap-addon" && not restartReserved = die "crash-after-reserve did not retain the debit"
  | otherwise = do
      reservedVersion <- parseVersion reserved
      inFlightVersion <- parseVersion inFlight
      boundPodVersion <- parseVersion boundPod
      if reservedVersion < inFlightVersion && inFlightVersion < boundPodVersion
        then pure ()
        else die "Kubernetes Binding did not follow the successful BindingInFlight CAS"

verifyRace :: AggregateRace -> IO ()
verifyRace (AggregateRace candidates successful conflicts residual over refused)
  | candidates == 2 && successful == 1 && conflicts == 1 && residual == 0 && over == 0 && refused = pure ()
  | otherwise = die "two-candidate whole-ledger CAS race over-allocated"

verifyRerun :: Rerun -> IO ()
verifyRerun (Rerun before after stable mutations bindings sameHolder sameLeaseVersion)
  | before == after && stable && mutations == 0 && bindings == 0 && sameHolder && sameLeaseVersion = pure ()
  | otherwise = die "immediate scheduler rerun was not byte-stable and Binding-free"

verifyUniversal :: Universal -> IO ()
verifyUniversal (Universal available (Pristine linux linuxCuda apple windows))
  | available && linux == "Incus" && linuxCuda == "Incus" && apple == "Lima" && windows == "WSL2" = pure ()
  | otherwise = die "universal linux-cpu or pristine-host mapping drifted"

verifyPostflight :: Postflight -> IO ()
verifyPostflight (Postflight namespaceAbsent raceAbsent systemAbsent crdAbsent policyAbsent bindingAbsent bootstrapPolicyAbsent bootstrapBindingAbsent rbacAbsent taintAbsent)
  | and [namespaceAbsent, raceAbsent, systemAbsent, crdAbsent, policyAbsent, bindingAbsent, bootstrapPolicyAbsent, bootstrapBindingAbsent, rbacAbsent, taintAbsent] = pure ()
  | otherwise = die "live scheduler postflight leaked a resource"

parseVersion :: Text -> IO Integer
parseVersion value = maybe (die ("invalid Kubernetes resourceVersion: " <> Text.unpack value)) pure (readMaybe (Text.unpack value))
