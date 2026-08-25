{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Data.Aeson (FromJSON (parseJSON), eitherDecodeFileStrict', withObject, (.:))
import Data.Text (Text)
import Data.Text qualified as Text
import System.Environment (getArgs)
import System.Exit (die)

data Evidence = Evidence Int Text Representative Marker DeleteBoundary Fresh Rebind Artifact Observer NoDelete Text Universal
data Representative = Representative Int [Text] Text Text Text
data Marker = Marker Bool Bool Bool Bool Bool Int [Text]
data DeleteBoundary = DeleteBoundary Bool Bool Bool Bool MarkerBytes
data MarkerBytes = MarkerBytes Bool Bool
data Fresh = Fresh Bool Bool Identity Identity
data Identity = Identity Text Text
data Rebind = Rebind Bool Bool Bool Runs Runs
data Runs = Runs Bound Bound
data Bound = Bound Text Text Text
data Artifact = Artifact Text Int ImageIds
data ImageIds = ImageIds Text Text
data Observer = Observer Bool [Text] [Text]
data NoDelete = NoDelete Text Bool
data Universal = Universal Bool Pristine
data Pristine = Pristine Text Text Text Text

instance FromJSON Evidence where
  parseJSON = withObject "Evidence" $ \v -> Evidence <$> v .: "register" <*> v .: "substrate" <*> v .: "representativeSet" <*> v .: "marker" <*> v .: "deleteBoundary" <*> v .: "freshCluster" <*> v .: "rebind" <*> v .: "artifactSource" <*> v .: "observer" <*> v .: "noNormalDelete" <*> v .: "controlPlaneNoPvc" <*> v .: "universalLinuxCpu"
instance FromJSON Representative where
  parseJSON = withObject "Representative" $ \v -> Representative <$> v .: "count" <*> v .: "statefulSets" <*> v .: "postgresTable" <*> v .: "minioBucket" <*> v .: "minioObject"
instance FromJSON Marker where
  parseJSON = withObject "Marker" $ \v -> Marker <$> v .: "postgresAbsentBeforeWrite" <*> v .: "minioAbsentBeforeWrite" <*> v .: "writtenBeforeDelete" <*> v .: "postgresByteIdentical" <*> v .: "minioByteIdentical" <*> v .: "postRecreateWriteOperations" <*> v .: "seedCommands"
instance FromJSON DeleteBoundary where
  parseJSON = withObject "DeleteBoundary" $ \v -> DeleteBoundary <$> v .: "kindClusterAbsent" <*> v .: "nodeContainerAbsent" <*> v .: "apiServerUnreachable" <*> v .: "backingPresent" <*> v .: "externalMarkerBytesObserved"
instance FromJSON MarkerBytes where
  parseJSON = withObject "MarkerBytes" $ \v -> MarkerBytes <$> v .: "pg-witness" <*> v .: "minio-witness"
instance FromJSON Fresh where
  parseJSON = withObject "Fresh" $ \v -> Fresh <$> v .: "serverCaChanged" <*> v .: "clusterUidChanged" <*> v .: "run1" <*> v .: "run2"
instance FromJSON Identity where
  parseJSON = withObject "Identity" $ \v -> Identity <$> v .: "serverCaSha256" <*> v .: "clusterUid"
instance FromJSON Rebind where
  parseJSON = withObject "Rebind" $ \v -> Rebind <$> v .: "freshPvObjects" <*> v .: "freshClaimRefsOmittedUid" <*> v .: "sameBackingImages" <*> v .: "run1" <*> v .: "run2"
instance FromJSON Runs where
  parseJSON = withObject "Runs" $ \v -> Runs <$> v .: "pg-witness" <*> v .: "minio-witness"
instance FromJSON Bound where
  parseJSON = withObject "Bound" $ \v -> Bound <$> v .: "uid" <*> v .: "claimUid" <*> v .: "phase"
instance FromJSON Artifact where
  parseJSON = withObject "Artifact" $ \v -> Artifact <$> v .: "phase25BakedBinaryDigest" <*> v .: "publicRegistryPulls" <*> v .: "containerImageIds"
instance FromJSON ImageIds where
  parseJSON = withObject "ImageIds" $ \v -> ImageIds <$> v .: "pg-witness" <*> v .: "minio-witness"
instance FromJSON Observer where
  parseJSON = withObject "Observer" $ \v -> Observer <$> v .: "auditExecObserved" <*> v .: "postRecreateWriteTokens" <*> v .: "readOperations"
instance FromJSON NoDelete where
  parseJSON = withObject "NoDelete" $ \v -> NoDelete <$> v .: "staticCheck" <*> v .: "postCycleBackingPresent"
instance FromJSON Universal where
  parseJSON = withObject "Universal" $ \v -> Universal <$> v .: "availableOnEveryHardwareSubstrate" <*> v .: "pristineLinuxHost"
instance FromJSON Pristine where
  parseJSON = withObject "Pristine" $ \v -> Pristine <$> v .: "linux" <*> v .: "linux-cuda" <*> v .: "apple" <*> v .: "windows"

main :: IO ()
main = do
  arguments <- getArgs
  evidencePath <- case arguments of
    [path] -> pure path
    _ -> die "usage: retained-storage-rebind-live <evidence.json>"
  decoded <- eitherDecodeFileStrict' evidencePath
  either die verify decoded
  putStrLn "retained-storage-rebind-live-spec: PASS (real delete, fresh cluster, two byte-identical marker readbacks)"

verify :: Evidence -> IO ()
verify (Evidence register substrate (Representative count sets table bucket objectName) (Marker pgAbsent minioAbsent written pgSame minioSame writes seeds) (DeleteBoundary clusterAbsent nodeAbsent apiAbsent backingPresent (MarkerBytes pgBytes minioBytes)) (Fresh caChanged uidChanged (Identity ca1 cluster1) (Identity ca2 cluster2)) (Rebind freshPvs omittedUid sameBacking (Runs (Bound pgPv1 pgClaim1 pgPhase1) (Bound minioPv1 minioClaim1 minioPhase1)) (Runs (Bound pgPv2 pgClaim2 pgPhase2) (Bound minioPv2 minioClaim2 minioPhase2))) (Artifact digest publicPulls (ImageIds pgImage minioImage)) (Observer auditObserved writeTokens readOps) (NoDelete staticCheck postBacking) unverified (Universal universal (Pristine linux linuxCuda apple windows)))
  | register /= 3 || substrate /= "linux-cpu" = die "wrong Register/substrate"
  | count /= 2 || sets /= ["minio-witness", "pg-witness"] || table /= "rebind_witness" || bucket /= "rebind-witness" || objectName /= "rebind/nonce" = die "representative set drifted"
  | not (pgAbsent && minioAbsent && written && pgSame && minioSame) || writes /= 0 || not (null seeds) = die "marker path was seeded, rewritten, or lost"
  | not (clusterAbsent && nodeAbsent && apiAbsent && backingPresent && pgBytes && minioBytes) = die "cluster was not genuinely absent with backing bytes present"
  | not (caChanged && uidChanged) || ca1 == ca2 || cluster1 == cluster2 = die "recreated cluster was not fresh"
  | not (freshPvs && omittedUid && sameBacking) = die "fresh PV rebind metadata mismatch"
  | pgPv1 == pgPv2 || minioPv1 == minioPv2 || pgClaim1 == pgClaim2 || minioClaim1 == minioClaim2 || any (/= "Bound") [pgPhase1, minioPhase1, pgPhase2, minioPhase2] = die "fresh PV/claim UIDs or Bound phases mismatch"
  | not (validDigest digest) || publicPulls /= 0 || any (not . (digest `textIn`)) [pgImage, minioImage] = die "private image provenance drifted"
  | not auditObserved || not (null writeTokens) || readOps /= ["Postgres SELECT", "S3 GET"] = die "post-recreate observer saw a write or missed read"
  | staticCheck /= "tools/no_retained_delete_check.sh" || not postBacking = die "normal delete invariant drifted"
  | unverified /= "UNVERIFIED (Phase 34 subject absent)" = die "Phase-34 no-PVC claim was made early"
  | not universal || linux /= "Incus" || linuxCuda /= "Incus" || apple /= "Lima" || windows /= "WSL2" = die "universal linux-cpu route drifted"
  | otherwise = pure ()

textIn :: Text -> Text -> Bool
textIn = Text.isInfixOf

validDigest :: Text -> Bool
validDigest value = Text.length value == 71 && "sha256:" `Text.isPrefixOf` value
