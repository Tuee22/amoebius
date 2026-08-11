{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Data.Aeson (FromJSON (parseJSON), eitherDecodeFileStrict', withObject, (.:))
import Data.Text (Text)
import Data.Text qualified as Text
import System.Exit (die)

data Evidence = Evidence Int Text InitOnce Envelope Storage Rebuild Pki Client Manifest Deferred Universal
data InitOnce = InitOnce Bool Bool Bool Int Bool Bool Bool
data Envelope = Envelope Text Bool Bool Bool
data Storage = Storage Volume Volume Bounds
data Volume = Volume Integer Integer Text
data Bounds = Bounds Integer Integer Bool
data Rebuild = Rebuild Bool Bool Bool Bool Bool Prebind Prebind
data Prebind = Prebind Bool
data Pki = Pki PkiRun PkiRun Bool Int
data PkiRun = PkiRun Bool Bool Text
data Client = Client Binary Consumer Consumer Bool Bool Bool Bool Bool Int Int
data Binary = Binary Bool Text
data Consumer = Consumer [Text] [Text] Text
data Manifest = Manifest Int Int (Maybe Text)
data Deferred = Deferred Text Text Text
data Universal = Universal Bool Pristine
data Pristine = Pristine Text Text Text Text

instance FromJSON Evidence where
  parseJSON = withObject "Evidence" $ \v -> Evidence <$> v .: "register" <*> v .: "substrate" <*> v .: "initOnce" <*> v .: "unlockEnvelope" <*> v .: "storage" <*> v .: "clusterRebuild" <*> v .: "pki" <*> v .: "client" <*> v .: "manifestProjection" <*> v .: "deferred" <*> v .: "universalLinuxCpu"
instance FromJSON InitOnce where
  parseJSON = withObject "InitOnce" $ \v -> InitOnce <$> v .: "run1InitializedBefore" <*> v .: "run2InitializedBeforeUnseal" <*> v .: "run2SealedBeforeUnseal" <*> v .: "initCount" <*> v .: "vaultClusterIdStable" <*> v .: "run1Unsealed" <*> v .: "run2Unsealed"
instance FromJSON Envelope where
  parseJSON = withObject "Envelope" $ \v -> Envelope <$> v .: "format" <*> v .: "wrongPasswordRejected" <*> v .: "passwordPersisted" <*> v .: "observedSurfaceScanPassed"
instance FromJSON Storage where
  parseJSON = withObject "Storage" $ \v -> Storage <$> v .: "durable" <*> v .: "audit" <*> v .: "run1HighWater"
instance FromJSON Volume where
  parseJSON = withObject "Volume" $ \v -> Volume <$> v .: "rawBytes" <*> v .: "usableBytes" <*> v .: "filesystemType"
instance FromJSON Bounds where
  parseJSON = withObject "Bounds" $ \v -> Bounds <$> v .: "raftHighWaterBytes" <*> v .: "auditHighWaterBytes" <*> v .: "withinProvision"
instance FromJSON Rebuild where
  parseJSON = withObject "Rebuild" $ \v -> Rebuild <$> v .: "serverCaChanged" <*> v .: "clusterUidChanged" <*> v .: "kindClusterAbsent" <*> v .: "nodeContainerAbsent" <*> v .: "backingPresentWhileAbsent" <*> v .: "prebindRun1" <*> v .: "prebindRun2"
instance FromJSON Prebind where
  parseJSON = withObject "Prebind" $ \v -> Prebind <$> v .: "claimRefsOmitServerFields"
instance FromJSON Pki where
  parseJSON = withObject "Pki" $ \v -> Pki <$> v .: "run1" <*> v .: "run2" <*> v .: "sameRootAfterRecreate" <*> v .: "sealedIssuanceStatus"
instance FromJSON PkiRun where
  parseJSON = withObject "PkiRun" $ \v -> PkiRun <$> v .: "rootSelfSigned" <*> v .: "leafChainsToRoot" <*> v .: "rootSha256"
instance FromJSON Client where
  parseJSON = withObject "Client" $ \v -> Client <$> v .: "compiledBinary" <*> v .: "run1" <*> v .: "run2" <*> v .: "secretRefByteIdentical" <*> v .: "transitByteIdentical" <*> v .: "roleDeletionDenied" <*> v .: "auditKubernetesLoginObserved" <*> v .: "auditSecretReadObserved" <*> v .: "agentSidecars" <*> v .: "plainSecretMounts"
instance FromJSON Binary where
  parseJSON = withObject "Binary" $ \v -> Binary <$> v .: "compiledFromCurrentTree" <*> v .: "sha256"
instance FromJSON Consumer where
  parseJSON = withObject "Consumer" $ \v -> Consumer <$> v .: "containers" <*> v .: "plainSecretVolumes" <*> v .: "imageId"
instance FromJSON Manifest where
  parseJSON = withObject "Manifest" $ \v -> Manifest <$> v .: "vaultContainers" <*> v .: "storageClassCount" <*> v .: "storageClass"
instance FromJSON Deferred where
  parseJSON = withObject "Deferred" $ \v -> Deferred <$> v .: "parentChildUnseal" <*> v .: "crossClusterIntermediateCa" <*> v .: "parentSecretInjection"
instance FromJSON Universal where
  parseJSON = withObject "Universal" $ \v -> Universal <$> v .: "availableOnEveryHardwareSubstrate" <*> v .: "pristineLinuxHost"
instance FromJSON Pristine where
  parseJSON = withObject "Pristine" $ \v -> Pristine <$> v .: "linux" <*> v .: "linux-cuda" <*> v .: "apple" <*> v .: "windows"

main :: IO ()
main = do
  decoded <- eitherDecodeFileStrict' "DEVELOPMENT_PLAN/evidence/phase_29/vault-live.json"
  either die verify decoded
  putStrLn "phase29-vault-live-spec: PASS (retained init/unseal, PKI, direct Kubernetes-auth client, bounded storage)"

verify :: Evidence -> IO ()
verify (Evidence register substrate (InitOnce run1Before run2Initialized run2Sealed initCount stableId run1Unsealed run2Unsealed) (Envelope format wrongPassword passwordPersisted scanPassed) (Storage (Volume durableRaw durableUsable durableFs) (Volume auditRaw auditUsable auditFs) (Bounds raftHigh auditHigh within)) (Rebuild caChanged uidChanged clusterAbsent nodeAbsent backingPresent (Prebind prebind1) (Prebind prebind2)) (Pki (PkiRun rootSelf1 leafChain1 root1) (PkiRun rootSelf2 leafChain2 root2) sameRoot sealedStatus) (Client (Binary currentTree binaryHash) (Consumer containers1 secrets1 image1) (Consumer containers2 secrets2 image2) secretSame transitSame roleDenied auditLogin auditRead sidecars secretMounts) (Manifest vaultContainers storageClassCount storageClassName) (Deferred parentChild intermediate parentInjection) (Universal universal (Pristine linux linuxCuda apple windows)))
  | register /= 3 || substrate /= "linux-cpu" = die "wrong Register/substrate"
  | run1Before || not (run2Initialized && run2Sealed) || initCount /= 1 || not (stableId && run1Unsealed && run2Unsealed) = die "init-once/unseal-existing invariant failed"
  | format /= "Argon2id-v1.3+ChaCha20-Poly1305-IETF" || not wrongPassword || passwordPersisted || not scanPassed = die "unlock envelope invariant failed"
  | durableRaw /= 134217728 || auditRaw /= 67108864 || durableUsable < 2023424 || auditUsable < 4194304 || durableFs /= "ext4" || auditFs /= "ext4" = die "physical Vault provision drifted"
  | not within || raftHigh > durableUsable || auditHigh > auditUsable = die "Raft/audit high-water exceeded backing"
  | not (caChanged && uidChanged && clusterAbsent && nodeAbsent && backingPresent && prebind1 && prebind2) = die "real cluster rebuild boundary failed"
  | not (rootSelf1 && leafChain1 && rootSelf2 && leafChain2 && sameRoot) || root1 /= root2 || sealedStatus == 200 = die "PKI root/leaf/sealed invariant failed"
  | not currentTree || nullText binaryHash || containers1 /= ["consumer"] || containers2 /= ["consumer"] || not (null secrets1 && null secrets2) || not (digestImage image1 && digestImage image2) = die "built-in consumer projection drifted"
  | not (secretSame && transitSame && roleDenied && auditLogin && auditRead) || sidecars /= 0 || secretMounts /= 0 = die "direct client provenance or read invariant failed"
  | vaultContainers /= 1 || storageClassCount /= 1 || storageClassName /= Just "amoebius-retained" = die "Vault/StorageClass manifest projection drifted"
  | any (/= "UNVERIFIED") [parentChild, intermediate, parentInjection] = die "deferred federation surface was marked green"
  | not universal || linux /= "Incus" || linuxCuda /= "Incus" || apple /= "Lima" || windows /= "WSL2" = die "universal linux-cpu route drifted"
  | otherwise = pure ()

nullText :: Text -> Bool
nullText value = value == ""

digestImage :: Text -> Bool
digestImage value = "sha256:224ce702545f17825dd18eb7108c9a72ea914e1b5ae01218ad955ab624cd94d4" `Text.isInfixOf` value
