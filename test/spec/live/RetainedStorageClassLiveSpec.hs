{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Data.Aeson (FromJSON (parseJSON), eitherDecodeFileStrict', withObject, (.:))
import Data.Text (Text)
import System.Environment (getArgs)
import System.Exit (die)

data Evidence = Evidence Int Text Inventory Pending Positive Negative Cleanup Universal
data Inventory = Inventory Int Text Text Text Bool Bool
data Pending = Pending Text Text Bool
data Positive = Positive Text Text Bool
data Negative = Negative Bool Text Text
data Cleanup = Cleanup Bool Bool Bool
data Universal = Universal Bool Pristine
data Pristine = Pristine Text Text Text Text

instance FromJSON Evidence where
  parseJSON = withObject "RetainedStorageClassEvidence" $ \value ->
    Evidence <$> value .: "register" <*> value .: "substrate" <*> value .: "inventory"
      <*> value .: "pendingClaim" <*> value .: "explicitBind" <*> value .: "negative"
      <*> value .: "cleanup" <*> value .: "universalLinuxCpu"

instance FromJSON Inventory where
  parseJSON = withObject "Inventory" $ \value ->
    Inventory <$> value .: "count" <*> value .: "provisioner" <*> value .: "reclaimPolicy"
      <*> value .: "volumeBindingMode" <*> value .: "defaultAnnotationAbsent" <*> value .: "oracleEqual"

instance FromJSON Pending where
  parseJSON = withObject "Pending" $ \value ->
    Pending <$> value .: "phase" <*> value .: "eventReason" <*> value .: "noProvisionerAttempted"

instance FromJSON Positive where
  parseJSON = withObject "ExplicitBind" $ \value ->
    Positive <$> value .: "pvcPhase" <*> value .: "pvPhase" <*> value .: "sameStorageClass"

instance FromJSON Negative where
  parseJSON = withObject "Negative" $ \value ->
    Negative <$> value .: "red" <*> value .: "countReason" <*> value .: "defaultReason"

instance FromJSON Cleanup where
  parseJSON = withObject "Cleanup" $ \value ->
    Cleanup <$> value .: "namespaceAbsent" <*> value .: "testPvAbsent" <*> value .: "retainedClassPresent"

instance FromJSON Universal where
  parseJSON = withObject "Universal" $ \value -> Universal <$> value .: "availableOnEveryHardwareSubstrate" <*> value .: "pristineLinuxHost"

instance FromJSON Pristine where
  parseJSON = withObject "Pristine" $ \value -> Pristine <$> value .: "linux" <*> value .: "linux-cuda" <*> value .: "apple" <*> value .: "windows"

main :: IO ()
main = do
  arguments <- getArgs
  evidencePath <- case arguments of
    [path] -> pure path
    _ -> die "usage: retained-storage-class-live <evidence.json>"
  decoded <- eitherDecodeFileStrict' evidencePath
  case decoded of
    Left problem -> die problem
    Right evidence -> verify evidence
  putStrLn "retained-storage-class-live: PASS (live inert class, wait reason, explicit bind, negative, cleanup)"

verify :: Evidence -> IO ()
verify (Evidence register substrate (Inventory count provisioner reclaim binding noDefault oracle) (Pending pending reason noAttempt) (Positive pvc pv same) (Negative red countReason defaultReason) (Cleanup namespaceAbsent pvAbsent classPresent) (Universal universal (Pristine linux linuxCuda apple windows)))
  | register /= 3 || substrate /= "linux-cpu" = die "wrong Register/substrate"
  | count /= 1 || provisioner /= "kubernetes.io/no-provisioner" || reclaim /= "Retain" || binding /= "WaitForFirstConsumer" || not noDefault || not oracle = die "live StorageClass inventory mismatch"
  | pending /= "Pending" || reason /= "WaitForFirstConsumer" || not noAttempt = die "unmatched claim did not wait without a provisioner"
  | pvc /= "Bound" || pv /= "Bound" || not same = die "explicit static PV did not bind"
  | not red || countReason /= "count != 1" || defaultReason /= "default-class annotation present" = die "two-class negative returned wrong reason"
  | not (namespaceAbsent && pvAbsent && classPresent) = die "Sprint 28.1 cleanup drifted"
  | not universal || linux /= "Incus" || linuxCuda /= "Incus" || apple /= "Lima" || windows /= "WSL2" = die "universal linux-cpu route drifted"
  | otherwise = pure ()
