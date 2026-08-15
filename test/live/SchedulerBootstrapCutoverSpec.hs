{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Data.Aeson (FromJSON (parseJSON), eitherDecodeFileStrict', withObject, (.:))
import Data.Text (Text)
import System.Environment (getArgs)
import System.Exit (die)

data Evidence = Evidence Int Text [Step] Bootstrap Managed Admission Postflight
data Step = Step Int Text
data Bootstrap = Bootstrap Text Bool Text Text Bool Bool Bool Bool Text Int Int
data Managed = Managed Text Bool Bool Bool Bool Bool Bool Bool Bool Bool Bool Text Text
data Admission = Admission Bool Bool Bool Text Bool Bool Bool
data Postflight = Postflight Bool Bool Bool Bool Bool Bool Bool Bool Bool Bool

instance FromJSON Evidence where
  parseJSON = withObject "Phase27LiveEvidence" $ \value ->
    Evidence <$> value .: "register" <*> value .: "substrate" <*> value .: "sequence"
      <*> value .: "bootstrap" <*> value .: "managed" <*> value .: "admission" <*> value .: "postflight"

instance FromJSON Step where
  parseJSON = withObject "Step" $ \value -> Step <$> value .: "ordinal" <*> value .: "event"

instance FromJSON Bootstrap where
  parseJSON = withObject "Bootstrap" $ \value ->
    Bootstrap <$> value .: "witness" <*> value .: "schedulerAvailable"
      <*> value .: "generation" <*> value .: "configDigest"
      <*> value .: "managedTaintAbsent" <*> value .: "bootstrapAdmissionGuardPresent"
      <*> value .: "generalAdmissionAbsent" <*> value .: "fullBindingAuthorityAbsent"
      <*> value .: "leaseHolder" <*> value .: "quotaHardPods" <*> value .: "quotaUsedPods"

instance FromJSON Managed where
  parseJSON = withObject "Managed" $ \value ->
    Managed <$> value .: "witness" <*> value .: "managedTaintPresent"
      <*> value .: "identityAdmissionPresent" <*> value .: "policyBindingPresent"
      <*> value .: "exclusiveBindingRbacPresent" <*> value .: "cutoverAuthorityRevoked"
      <*> value .: "writerDomainExact" <*> value .: "oldUidAbsent"
      <*> value .: "oldResourcesReleased" <*> value .: "replacementReservationJoined"
      <*> value .: "replacementBound" <*> value .: "oldDefaultScheduledUid"
      <*> value .: "replacementUid"

instance FromJSON Admission where
  parseJSON = withObject "Admission" $ \value ->
    Admission <$> value .: "prematureGuardedRejected" <*> value .: "prematureDryRunRejected"
      <*> value .: "prematureZeroWrites" <*> value .: "prematureReason"
      <*> value .: "defaultSchedulerBypassRejected" <*> value .: "defaultSchedulerBypassZeroWrites"
      <*> value .: "positiveAdmittedAfterManaged"

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
  putStrLn "scheduler-bootstrap-cutover: PASS (ordered bootstrap/managed witnesses and zero-write admission)"

verify :: Evidence -> IO ()
verify (Evidence register substrate steps bootstrap managed admission postflight)
  | register /= 3 || substrate /= "linux-cpu" = die "wrong live register or substrate"
  | map (\(Step ordinal event) -> (ordinal, event)) steps /= zip [1 .. 6] expectedEvents = die "bootstrap/managed/general action order drifted"
  | otherwise = verifyBootstrap bootstrap >> verifyManaged managed >> verifyAdmission admission >> verifyPostflight postflight
 where
  expectedEvents =
    [ "BootstrapCapacitySchedulerReady", "BootstrapAddonCutover", "BootstrapReplacementBoundReady"
    , "ManagedCapacityReady", "GeneralGuardedPodAdmitted", "GeneralGuardedPodBoundReady"
    ]

verifyBootstrap :: Bootstrap -> IO ()
verifyBootstrap (Bootstrap witness available generation config taintAbsent bootstrapGuard generalAbsent fullRbacAbsent holder hard used)
  | witness == "BootstrapCapacitySchedulerReady" && available && generation == "phase27-generation-1"
      && config == "sha256:fd5c9e99104e9baee88947825f0658d19ef43d62219fdfc692174fcaa71acc12"
      && taintAbsent && bootstrapGuard && generalAbsent && fullRbacAbsent
      && holder == "phase26-bootstrap-host" && hard == 1 && used == 1 = pure ()
  | otherwise = die "BootstrapCapacitySchedulerReady was not independently observed"

verifyManaged :: Managed -> IO ()
verifyManaged (Managed witness taint admission policyBinding rbac revoked exactWriter oldAbsent released joined bound oldUid replacementUid)
  | witness == "ManagedCapacityReady" && and [taint, admission, policyBinding, rbac, revoked, exactWriter, oldAbsent, released, joined, bound]
      && oldUid /= replacementUid = pure ()
  | otherwise = die "ManagedCapacityReady was minted without complete cutover/readback"

verifyAdmission :: Admission -> IO ()
verifyAdmission (Admission premature dryRun zeroWrites reason bypass bypassZero positive)
  | premature && dryRun && zeroWrites && reason == "ManagedCapacityReady is required" && bypass && bypassZero && positive = pure ()
  | otherwise = die "execution identity admission boundary failed"

verifyPostflight :: Postflight -> IO ()
verifyPostflight (Postflight namespaceAbsent raceAbsent systemAbsent crdAbsent policyAbsent bindingAbsent bootstrapPolicyAbsent bootstrapBindingAbsent rbacAbsent taintAbsent)
  | and [namespaceAbsent, raceAbsent, systemAbsent, crdAbsent, policyAbsent, bindingAbsent, bootstrapPolicyAbsent, bootstrapBindingAbsent, rbacAbsent, taintAbsent] = pure ()
  | otherwise = die "live scheduler postflight leaked a resource"
