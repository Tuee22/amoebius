{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Data.Aeson (FromJSON (parseJSON), eitherDecodeFileStrict', withObject, (.:))
import Data.Text (Text)
import System.Exit (die)

data Evidence = Evidence Int Text Inventory Negative Host Ceiling Binding Rebind Migration Scaling Cleanup Universal
data Inventory = Inventory Integer Integer [Text] Bool Bool
data Negative = Negative Text Int Int
data Host = Host Integer Integer Integer Text Bool Text Text
data Ceiling = Ceiling Text Integer Integer Integer Integer Bool Bool Text
data Binding = Binding Text Text Text Text Text Text Text Text Text Bool
data Rebind = Rebind Bool Bool Bool Bool Bool Text Text Bool Text
data Migration = Migration Int Int Bool Bool
data Scaling = Scaling Bool Bool Bool
data Cleanup = Cleanup Bool Bool Bool
data Universal = Universal Bool Pristine
data Pristine = Pristine Text Text Text Text

instance FromJSON Evidence where
  parseJSON = withObject "Evidence" $ \v -> Evidence <$> v .: "register" <*> v .: "substrate" <*> v .: "inventory" <*> v .: "negativeBoundary" <*> v .: "hostVolume" <*> v .: "hardCeiling" <*> v .: "binding" <*> v .: "rebind" <*> v .: "migrationCorpus" <*> v .: "scalingAuthority" <*> v .: "cleanup" <*> v .: "universalLinuxCpu"

instance FromJSON Inventory where
  parseJSON = withObject "Inventory" $ \v -> Inventory <$> v .: "observedBackingBytes" <*> v .: "postReconcileDebitBytes" <*> v .: "deduplicatedStableIdentities" <*> v .: "cacheExcluded" <*> v .: "nodeEphemeralExcluded"

instance FromJSON Negative where
  parseJSON = withObject "Negative" $ \v -> Negative <$> v .: "reason" <*> v .: "storageWrites" <*> v .: "apiWrites"

instance FromJSON Host where
  parseJSON = withObject "Host" $ \v -> Host <$> v .: "rawBytes" <*> v .: "usableBytes" <*> v .: "requiredUsableBytes" <*> v .: "filesystemType" <*> v .: "fixedRawImage" <*> v .: "rawOneByteShortReason" <*> v .: "wrongFilesystemReason"

instance FromJSON Ceiling where
  parseJSON = withObject "Ceiling" $ \v -> Ceiling <$> v .: "overflowErrno" <*> v .: "rawBytesBefore" <*> v .: "rawBytesAfter" <*> v .: "siblingRawBytesBefore" <*> v .: "siblingRawBytesAfter" <*> v .: "spillToSibling" <*> v .: "spillToSharedParent" <*> v .: "filesystemType"

instance FromJSON Binding where
  parseJSON = withObject "Binding" $ \v -> Binding <$> v .: "pvName" <*> v .: "logicalIdentity" <*> v .: "rfc1123IdentityLabel" <*> v .: "claimNamespace" <*> v .: "claimName" <*> v .: "capacity" <*> v .: "expectedCapacity" <*> v .: "pvcPhase" <*> v .: "pvPhase" <*> v .: "pvcCreatedOnlyByStatefulSetTemplate"

instance FromJSON Rebind where
  parseJSON = withObject "Rebind" $ \v -> Rebind <$> v .: "releasedObserved" <*> v .: "staleUidCleared" <*> v .: "freshUidDiffers" <*> v .: "samePv" <*> v .: "sameBacking" <*> v .: "nonceSha256Before" <*> v .: "nonceSha256After" <*> v .: "byteIdentical" <*> v .: "finalPvcPhase"

instance FromJSON Migration where
  parseJSON = withObject "Migration" $ \v -> Migration <$> v .: "negativeCases" <*> v .: "positiveCases" <*> v .: "independentVerification" <*> v .: "completionOrderPinned"

instance FromJSON Scaling where
  parseJSON = withObject "Scaling" $ \v -> Scaling <$> v .: "freshSnapshotRequired" <*> v .: "singleUseToken" <*> v .: "providerCapabilityAbsent"

instance FromJSON Cleanup where
  parseJSON = withObject "Cleanup" $ \v -> Cleanup <$> v .: "namespaceAbsent" <*> v .: "pvAbsent" <*> v .: "storageClassPresent"

instance FromJSON Universal where
  parseJSON = withObject "Universal" $ \v -> Universal <$> v .: "availableOnEveryHardwareSubstrate" <*> v .: "pristineLinuxHost"

instance FromJSON Pristine where
  parseJSON = withObject "Pristine" $ \v -> Pristine <$> v .: "linux" <*> v .: "linux-cuda" <*> v .: "apple" <*> v .: "windows"

main :: IO ()
main = do
  decoded <- eitherDecodeFileStrict' "DEVELOPMENT_PLAN/evidence/phase_28/sprint-28.2-live.json"
  either die verify decoded
  putStrLn "phase28-retained-pv-live: PASS (backing fold, fixed image, ENOSPC, exact bind, rebind)"

verify :: Evidence -> IO ()
verify (Evidence register substrate (Inventory backing debit identities cacheExcluded ephemeralExcluded) (Negative reason storageWrites apiWrites) (Host raw usable required fs fixed shortReason wrongReason) (Ceiling errno rawBefore rawAfter siblingBefore siblingAfter siblingSpill parentSpill boundaryFs) (Binding pvName identity identityLabel claimNs claimName capacity expectedCapacity pvcPhase pvPhase templateOnly) (Rebind released uidCleared uidDiffers samePv sameBacking digestBefore digestAfter identical finalPhase) (Migration negatives positives independent ordered) (Scaling fresh singleUse providerAbsent) (Cleanup nsAbsent pvAbsent classPresent) (Universal universal (Pristine linux linuxCuda apple windows)))
  | register /= 3 || substrate /= "linux-cpu" = die "wrong Register/substrate"
  | backing /= 536870912 || debit /= 402653184 || identities /= ["retained-witness/pg-witness/pv_0", "retained-witness/minio-witness/pv_0"] || not cacheExcluded || not ephemeralExcluded = die "durable inventory mismatch"
  | reason /= "durable-demand-exceeds-backing" || storageWrites /= 0 || apiWrites /= 0 = die "over-backing negative crossed write boundary"
  | raw /= 268435456 || usable < required || fs /= "ext4" || not fixed || shortReason /= "raw capacity below witness" || wrongReason /= "observed fsType != presentation" = die "host image observation mismatch"
  | errno /= "ENOSPC" || rawBefore /= rawAfter || siblingBefore /= siblingAfter || siblingSpill || parentSpill || boundaryFs /= "ext4" = die "host hard ceiling not enforced"
  | pvName /= "retained-witness.pg-witness.pv-0" || identity /= "retained-witness/pg-witness/pv_0" || identityLabel /= pvName || claimNs /= "retained-witness" || claimName /= "pgdata-pg-witness-0" || capacity /= expectedCapacity || pvcPhase /= "Bound" || pvPhase /= "Bound" || not templateOnly = die "oracle-pinned bind mismatch"
  | not (released && uidCleared && uidDiffers && samePv && sameBacking && identical) || digestBefore /= digestAfter || finalPhase /= "Bound" = die "Released-to-Bound rebind mismatch"
  | negatives /= 3 || positives /= 1 || not independent || not ordered = die "migration corpus mismatch"
  | not (fresh && singleUse && providerAbsent) = die "storage scaling authority mismatch"
  | not (nsAbsent && pvAbsent && classPresent) = die "cleanup mismatch"
  | not universal || linux /= "Incus" || linuxCuda /= "Incus" || apple /= "Lima" || windows /= "WSL2" = die "universal linux-cpu route drifted"
  | otherwise = pure ()
