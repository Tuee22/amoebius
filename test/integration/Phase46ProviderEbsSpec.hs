{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Monad (unless)
import Data.Aeson (FromJSON (..), eitherDecodeStrict', withObject, (.:))
import Data.ByteString qualified as ByteString
import Data.Text (Text)
import Data.Vector (Vector)
import Data.Vector qualified as Vector
import System.Exit (die)

data Evidence = Evidence Int Text Text StorageClass StaticPv Marker Checkpoint Provider Baked Universal Cleanup
data StorageClass = StorageClass Text Text Text (Vector Text)
data StaticPv = StaticPv Text Text Text Text Text (Vector Text) Bool Text
data Marker = Marker Text Bool Bool Bool Text
data Checkpoint = Checkpoint (Vector Text) Bool Bool Bool Bool
data Provider = Provider Text Text Text Text Text Text Text Text
data Baked = Baked Text Text
data Universal = Universal Bool Pristine
data Pristine = Pristine Text Text Text Text
data Cleanup = Cleanup Bool (Vector Text) Bool Bool Bool Text

instance FromJSON Evidence where
  parseJSON = withObject "Evidence" $ \value ->
    Evidence <$> value .: "register" <*> value .: "substrate" <*> value .: "scopedBoundary"
      <*> value .: "storageClass" <*> value .: "staticEbsPvObject" <*> value .: "retainedMarker"
      <*> value .: "checkpointClasses" <*> value .: "providerMaterialization"
      <*> value .: "bakedCsiBinaryExecution" <*> value .: "universalLinuxCpu" <*> value .: "cleanup"

instance FromJSON StorageClass where
  parseJSON = withObject "StorageClass" $ \value ->
    StorageClass <$> value .: "name" <*> value .: "provisioner" <*> value .: "reclaimPolicy" <*> value .: "dynamicEbsStorageClasses"

instance FromJSON StaticPv where
  parseJSON = withObject "StaticPv" $ \value ->
    StaticPv <$> value .: "apiKind" <*> value .: "reclaimPolicy" <*> value .: "storageClass"
      <*> value .: "driver" <*> value .: "zoneKey" <*> value .: "zones"
      <*> value .: "bindingAttempted" <*> value .: "providerVolumeExists"

instance FromJSON Marker where
  parseJSON = withObject "Marker" $ \value ->
    Marker <$> value .: "backing" <*> value .: "backingPathStable" <*> value .: "byteExact"
      <*> value .: "pvIdentityChanged" <*> value .: "ebsVolumeHandleStable"

instance FromJSON Checkpoint where
  parseJSON = withObject "Checkpoint" $ \value ->
    Checkpoint <$> value .: "objectKeys" <*> value .: "distinctLogicalNamespaces" <*> value .: "objectsOpaque"
      <*> value .: "directTransitRecovery" <*> value .: "durableProtectRetainMetadataRecovered"

instance FromJSON Provider where
  parseJSON = withObject "Provider" $ \value ->
    Provider <$> value .: "realEbsVolume" <*> value .: "operationalEc2CreateVolume"
      <*> value .: "operationalEc2DeleteVolumeDenied" <*> value .: "awsEbsCsiReady"
      <*> value .: "providerAttachMount" <*> value .: "sameEbsHandleReattach"
      <*> value .: "providerRawAndUsableGeometry" <*> value .: "cloudAudit"

instance FromJSON Baked where
  parseJSON = withObject "Baked" $ \value -> Baked <$> value .: "amd64" <*> value .: "arm64"

instance FromJSON Universal where
  parseJSON = withObject "Universal" $ \value -> Universal <$> value .: "availableOnEveryHardwareSubstrate" <*> value .: "pristineLinuxHost"

instance FromJSON Pristine where
  parseJSON = withObject "Pristine" $ \value -> Pristine <$> value .: "linux" <*> value .: "linux-cuda" <*> value .: "apple" <*> value .: "windows"

instance FromJSON Cleanup where
  parseJSON = withObject "Cleanup" $ \value ->
    Cleanup <$> value .: "namespaceAbsent" <*> value .: "phase46PersistentVolumes" <*> value .: "hostPathRemoved"
      <*> value .: "checkpointBucketRemoved" <*> value .: "transitKeyRemoved" <*> value .: "providerResources"

main :: IO ()
main = do
  bytes <- ByteString.readFile "DEVELOPMENT_PLAN/evidence/phase_46/provider-ebs-live.json"
  evidence <- either die pure (eitherDecodeStrict' bytes)
  verify evidence
  putStrLn "provider-ebs-credential-live: PASS (scoped retained-storage/checkpoint boundary; AWS EBS/IAM UNVERIFIED)"

verify :: Evidence -> IO ()
verify (Evidence register substrate boundary storageClass staticPv retainedMarker checkpoint provider baked universal cleanup) = do
  assert (register == 3 && substrate == "linux-cpu") "register/substrate"
  assert (boundary == "retained kind storage and checkpoint-class analogue; not an AWS EBS or IAM result") "scoped-boundary"
  case storageClass of
    StorageClass name provisioner reclaim dynamic ->
      assert (name == "amoebius-retained" && provisioner == "kubernetes.io/no-provisioner" && reclaim == "Retain" && Vector.null dynamic) "storage-class"
  case staticPv of
    StaticPv kind reclaim storage driver zoneKey zones binding providerExists ->
      assert (kind == "PersistentVolume" && reclaim == "Retain" && storage == "amoebius-retained" && driver == "ebs.csi.aws.com" && zoneKey == "topology.ebs.csi.aws.com/zone" && zones == Vector.fromList ["us-east-1a"] && not binding && providerExists == "UNVERIFIED") "static-pv-object"
  case retainedMarker of
    Marker backing stable byteExact identityChanged handle ->
      assert (backing == "retained hostPath scoped analogue; not EBS" && stable && byteExact && identityChanged && handle == "UNVERIFIED") "retained-marker"
  case checkpoint of
    Checkpoint keys distinct opaque transit metadata ->
      assert (keys == Vector.fromList ["ephemeral/cluster/checkpoint.json", "durable/pv/data-sts0-pv_0/checkpoint.json"] && and [distinct, opaque, transit, metadata]) "checkpoint-classes"
  case provider of
    Provider volume create deleteDeny csi attach reattach geometry audit ->
      assert (all (== "UNVERIFIED") [volume, create, deleteDeny, csi, attach, reattach, geometry, audit]) "provider-honesty"
  case baked of
    Baked amd64 arm64 -> assert (amd64 == "UNVERIFIED" && arm64 == "UNVERIFIED") "baked-execution-honesty"
  case universal of
    Universal available (Pristine linux linuxCuda apple windows) ->
      assert (available && linux == "Incus" && linuxCuda == "Incus" && apple == "Lima" && windows == "WSL2") "universal-linux-cpu"
  case cleanup of
    Cleanup namespace pvs hostPath bucket transit providerResources ->
      assert (namespace && Vector.null pvs && hostPath && bucket && transit && providerResources == "none-created") "cleanup"
 where
  assert condition label = unless condition (die label)
