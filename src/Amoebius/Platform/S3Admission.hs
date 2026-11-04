{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Durable, bounded writer admission. A reservation is persisted before
-- backend mutation. Failed and interrupted writes retain debt until explicit
-- observed cleanup; a clock tick alone never releases their capacity.
module Amoebius.Platform.S3Admission
  ( Writer (..), GatewayPolicy, GatewayState, Reservation
  , gatewayPolicy, emptyGatewayState, beginWrite, finishWrite, recoverInterrupted
  , gatewayPolicyFromStorage
  , gatewayStateValue, decodeGatewayState, reservationBytes, reservationPath
  , admittedObject, stateObjectCount
  , beginMultipart, bindMultipart, beginPart, recordPart, beginComplete, completeMultipart
  , forgetTemporaryObject, ownsBucket, expectedObjectDigest
  , admitCopySource
  , forgetStoredObject, finishMultipartAbort
  , validateBackendInventory
  ) where

import Amoebius.Platform.S3Signing (sha256Hex)
import Amoebius.Capacity.ObjectStore qualified as Objects
import Amoebius.Capacity.Storage (BudgetId (..),StorageBudget (..),StorageAmount (..),fitStorageBudget)
import Data.Text.Encoding qualified as Text
import Control.Monad (unless)
import Data.Aeson
import Data.Aeson.Types (Parser, parseEither)
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data Writer = RegistryWriter | OffloadWriter | ApplicationWriter
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (FromJSON, ToJSON, FromJSONKey, ToJSONKey)

data ObjectClass = Canonical | RegistryBlob | RegistryLink | RegistryMetadata | OffloadData | OffloadIndex | ApplicationCanary
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (FromJSON, ToJSON)

data GatewayPolicy = GatewayPolicy (Map Text (Natural, Text)) Natural (Map Text Objects.ObjectWriterAdmission)
  deriving stock (Eq, Show)

data AdmittedObject = AdmittedObject
  { objectClass :: ObjectClass, objectExtent :: Natural, objectDigest :: Text }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (FromJSON, ToJSON)

data Reservation = Reservation
  { reservationWriter :: Writer, reservationPath :: Text, reservationClass :: ObjectClass
  , reservationBytes :: Natural, reservationDigest :: Text }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (FromJSON, ToJSON)

data GatewayState = GatewayState
  { stateObjects :: Map Text AdmittedObject, stateFailed :: Map Writer Natural
  , statePending :: Maybe Reservation, stateUploads :: Map Text Text
  , stateParts :: Map Text Natural }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (FromJSON, ToJSON)

gatewayPolicy :: Map Text (Natural, Text) -> Either Text GatewayPolicy
gatewayPolicy known = do
  unless (not (Map.null known) && Map.size known <= 1024
    && all (\(path, (bytes, digest)) -> Text.isPrefixOf "/registry/docker/registry/v2/" path
      && Text.length path <= 512 && bytes > 0 && bytes <= 512 * mib && validDigest digest) (Map.toList known))
    (Left "gateway-canonical-inventory-invalid")
  pure (GatewayPolicy known (maximum (fmap fst (Map.elems known))) Map.empty)

-- Interpret the private provision's serialized writer admissions at the IO
-- boundary. The selected finite key grammar cannot be installed against a
-- smaller/different physical population or a parallel caller-supplied budget.
gatewayPolicyFromStorage :: Value -> Either Text GatewayPolicy
gatewayPolicyFromStorage value = either (Left . ("gateway-installed-policy-binding-invalid:" <>) . Text.pack) Right
  (parseEither parsePolicy value)
 where
  parsePolicy = withObject "private backbone storage projection" $ \root -> do
    registry <- root .: "registry"
    records <- registry .: "driverObjects" >>= traverse (withObject "canonical driver object" $ \row ->
      (,) <$> (("/registry/" <>) <$> row .: "key") <*> ((,) <$> row .: "bytes" <*> row .: "sha256"))
    let known = Map.fromList records
    unless (Map.size known == length records) (fail "duplicate canonical identity")
    policy <- either (fail . Text.unpack) pure (gatewayPolicy known)
    peak <- root .: "objectStorePeak"
    writers <- peak .: "writerAdmissions"
    unless (setFromKeys writers == ["application-canary","pulsar-offload","registry"]) (fail "installed writer domain")
    modelInputs <- peak .: "sourceModels"
    unless (setFromKeys modelInputs == ["pulsar-offload"]) (fail "structured model domain mismatch")
    mergedResidents <- peak .: "residents" >>= traverse (withObject "merged physical resident" $ \row ->
      (,) <$> ((,,,) <$> row .: "store" <*> row .: "tenant" <*> row .: "bucket" <*> row .: "key") <*> row .: "bytes")
    let expectedResidents = Map.fromList [(("root-minio" :: Text,"platform" :: Text,"registry" :: Text,
          Text.drop (Text.length ("/registry/" :: Text)) path),bytes) | (path,(bytes,_)) <- Map.toList known]
    unless (length mergedResidents == Map.size (Map.fromList mergedResidents)
      && Map.fromList mergedResidents == expectedResidents) (fail "merged physical resident mismatch")
    global <- peak .: "populations" >>= traverse (withObject "merged population" $ \row ->
      (,) <$> row .: "source" <*> populationRow (Object row))
    checked <- traverse (checkWriter known writers modelInputs)
      [("registry","registry","RegistryObjects","registry",RegistryWriter),
       ("pulsar-offload","pulsar","PulsarOffloadObjects","pulsar-offload",OffloadWriter),
       ("application-canary","phase30-application","ApplicationObjects","phase30-canary",ApplicationWriter)]
    unless (sortRows global == sortRows (concatMap fst checked)) (fail "writer/merged population mismatch")
    let GatewayPolicy canonical largest _ = policy
    pure (GatewayPolicy canonical largest (Map.fromList [(Objects.writerAdmissionSource admission,admission) | (_,admission) <- checked]))
  setFromKeys = Map.keys . Map.fromList . fmap (\key -> (Key.toText key,())) . KeyMap.keys
  sortRows rows = Map.fromListWith (+) [(row,1 :: Natural) | row <- rows]
  populationRow :: Value -> Parser (Text,Text,Natural,Natural,Natural)
  populationRow = withObject "writer population" $ \row ->
    (,,,,) <$> row .: "kind" <*> row .: "name" <*> row .: "count" <*> row .: "maximumBytes" <*> row .: "windowSeconds"
  checkWriter :: Map Text (Natural,Text) -> Object -> Object -> (Text,Text,Text,Text,Writer)
    -> Parser ([(Text,(Text,Text,Natural,Natural,Natural))],Objects.ObjectWriterAdmission)
  checkWriter known writers models (name,owner,kind,bucket,writer) = do
    row <- maybe (fail "missing writer") (withObject "private writer" pure) (KeyMap.lookup (Key.fromText name) writers)
    source <- row .: "source"; actualOwner <- row .: "owner"; actualKind <- row .: "kind"; budget <- row .: "budget"
    scope <- row .: "scope"
    store <- scope .: "store"; tenant <- scope .: "tenant"; actualBucket <- scope .: "bucket"
    unless ((source,actualOwner,actualKind,budget,store,tenant,actualBucket)
      == (name,owner,kind,name,"root-minio" :: Text,"platform" :: Text,bucket)) (fail "writer ownership mismatch")
    populations' <- row .: "populations" >>= traverse populationRow
    unless (all (\(k,_,n,b,h) -> k `elem` ["FutureObjects","ConcurrentObjects","DeletionLagObjects","FailedOrphanObjects"]
      && n > 0 && b > 0 && (k `notElem` ["DeletionLagObjects","FailedOrphanObjects"] || h > 0)) populations')
      (fail "invalid writer population")
    residents <- row .: "residentObjects" >>= traverse (withObject "private resident" $ \resident ->
      (,) <$> resident .: "key" <*> resident .: "bytes")
    let expectedResidents = if writer == RegistryWriter
          then Map.fromList [(Text.drop (Text.length ("/registry/" :: Text)) path,bytes) | (path,(bytes,_)) <- Map.toList known]
          else Map.empty
    unless (Map.size (Map.fromList residents) == length residents && Map.fromList residents == expectedResidents)
      (fail "writer resident identity mismatch")
    quota <- row .: "quota"
    quotaKind <- quota .: "kind"; provider <- quota .: "provider"
    quotaBytes <- quota .: "bytes"; quotaObjects <- quota .: "objects"
    unless (quotaKind == ("ProviderObjectQuota" :: Text) && provider == store) (fail "writer quota type/provider mismatch")
    let admittedBudget = ProviderObjectQuota (BudgetId budget) provider quotaBytes quotaObjects
        amount = StorageAmount (sum (fmap snd residents)+sum [n*b | (_,_,n,b,_) <- populations'])
          (fromIntegral (length residents)+sum [n | (_,_,n,_,_) <- populations'])
    _ <- either (fail . show) pure (fitStorageBudget admittedBudget amount)
    model <- row .: "model"
    unless (if writer == OffloadWriter then model /= Null && KeyMap.lookup (Key.fromText name) models == Just model
      else model == Null) (fail "writer original model mismatch")
    let physicalResidents = Map.fromList [(Objects.PhysicalObjectId store tenant actualBucket key,bytes) | (key,bytes) <- residents]
        populationValues selected = [Objects.ObjectPopulation label n b h | (k,label,n,b,h) <- populations', k == selected]
        sourceDemand = Objects.ObjectSourceDemand source actualOwner (Objects.SourceScope store tenant actualBucket) admittedBudget
          physicalResidents (populationValues "FutureObjects") (populationValues "ConcurrentObjects")
          (populationValues "DeletionLagObjects") (populationValues "FailedOrphanObjects")
    privateSource <- case writer of
      OffloadWriter -> do
        input <- either (fail . show) pure (Objects.decodePulsarObjectDemandProjection model)
        derived <- either (fail . show) pure (Objects.derivePulsarObjects
          (Objects.ObjectSourceContext source actualOwner (Objects.SourceScope store tenant actualBucket) admittedBudget) input)
        admitted <- either (fail . show) pure (Objects.foldObjectStoreSources (Set.singleton source) [Objects.derivedObjectSource derived])
        let actualRows = [(Text.pack (show k),Objects.populationName p,Objects.populationCount p,
              Objects.populationMaximumBytes p,Objects.populationWindowSeconds p) | (_,k,p) <- Objects.objectStorePopulations admitted]
        unless (sortRows actualRows == sortRows populations'
          && Objects.objectStoreResidents admitted == physicalResidents) (fail "original offload model/resident/population mismatch")
        pure (Objects.derivedObjectSource derived)
      RegistryWriter -> pure (Objects.RegistrySource sourceDemand)
      ApplicationWriter -> pure (Objects.ApplicationSource sourceDemand)
    privatePeak <- either (fail . show) pure (Objects.foldObjectStoreSources (Set.singleton source) [privateSource])
    privateWriter <- maybe (fail "private writer reconstruction missing") pure
      (Map.lookup source (Objects.objectStoreWriterAdmissions privatePeak))
    let future label count bytes = unless
          ([(n,b) | (k,p,n,b,_) <- populations', k == "FutureObjects", p == label] == [(count,bytes)])
          (fail "writer future capacity mismatch")
        fundedSlots populationKind extent = sum [n | (k,_,n,b,_) <- populations', k == populationKind, b >= extent]
        registrySlots populationKind baseLabel requiredCount extent = do
          let typedKind = if populationKind == "ConcurrentObjects" then Objects.ConcurrentObjects else Objects.FailedOrphanObjects
          grouped <- either (fail . show) pure (Objects.registryPopulationSlots typedKind (populationValues populationKind))
          (count,bytes,horizon) <- case [(Objects.populationCount p,Objects.populationMaximumBytes p,Objects.populationWindowSeconds p)
            | p <- grouped, Objects.populationName p == baseLabel] of
              [entry] -> pure entry
              _ -> fail "missing/duplicate registry funding class"
          unless (count >= requiredCount && bytes >= extent
            && (populationKind /= "FailedOrphanObjects" || horizon > 0))
            (fail "registry object-slot funding mismatch")
        largest = maximum (65536:fmap (fst . snd) (Map.toList known))
        maximumWrite = case writer of RegistryWriter -> largest; OffloadWriter -> mib; ApplicationWriter -> 4096
    case writer of
      RegistryWriter -> do
        future "post-cutover-blob" 1 65536; future "post-cutover-link" 1 71; future "registry-driver-metadata" 16 4096
        registrySlots "ConcurrentObjects" "registry-upload-workspace" 1 maximumWrite
        registrySlots "FailedOrphanObjects" "registry-failed-upload-window" (failureLimit writer) maximumWrite
      OffloadWriter -> do
        future "phase30/drill/data" 128 mib; future "phase30/drill/index" 128 mib
        unless (fundedSlots "ConcurrentObjects" maximumWrite >= 1
          && fundedSlots "FailedOrphanObjects" maximumWrite >= failureLimit writer)
          (fail "offload object-slot funding mismatch")
      ApplicationWriter -> do
        future "admitted-canary" 1 4096
        unless (fundedSlots "ConcurrentObjects" maximumWrite >= 1
          && fundedSlots "FailedOrphanObjects" maximumWrite >= failureLimit writer)
          (fail "application object-slot funding mismatch")
    pure ([(name,population) | population <- populations'],privateWriter)

emptyGatewayState :: GatewayState
emptyGatewayState = GatewayState Map.empty Map.empty Nothing Map.empty Map.empty

-- | All content hash proofs are hex SHA-256 of the actual request extent.
-- Known immutable objects and new digest paths must match that commitment.
beginWrite :: GatewayPolicy -> GatewayState -> Writer -> Text -> Natural -> Text
  -> Either Text (GatewayState, Reservation)
beginWrite policy@(GatewayPolicy known _ _) state writer path bytes digest = do
  unless (statePending state == Nothing) (Left "gateway-write-already-active")
  unless (Map.findWithDefault 0 writer (stateFailed state) < failureLimit writer)
    (Left "gateway-failed-history-full")
  (kind, maximumBytes, expectedHash) <- classify policy writer path
  unless (bytes <= maximumBytes && (kind /= Canonical || bytes == maximumBytes)
    && (kind /= RegistryLink || bytes == 71) && (kind /= ApplicationCanary || bytes == 4096)
    && (kind == RegistryMetadata || bytes > 0)) (Left "gateway-object-extent-denied")
  unless (validDigest digest || digest == "UNSIGNED-PAYLOAD" && (writer == OffloadWriter || kind == RegistryMetadata))
    (Left "gateway-payload-proof-required")
  unless (maybe True (== digest) expectedHash) (Left "gateway-object-digest-denied")
  case Map.lookup path (stateObjects state) of
    Just previous | kind `notElem` [RegistryMetadata, ApplicationCanary] ->
      unless (objectExtent previous == bytes && objectDigest previous == digest) (Left "gateway-immutable-object-conflict")
    _ -> pure ()
  let others = Map.delete path (stateObjects state)
      sameClass = filter ((== kind) . objectClass) (Map.elems others)
  unless (kind == Canonical || fromIntegral (length sameClass) < classLimit kind)
    (Left "gateway-object-count-denied")
  -- Canonical residents are charged by the immutable inventory from startup,
  -- including objects not copied yet. Other classes reserve their maxima,
  -- rather than treating currently small extents as a reusable quota.
  let knownBytes = sum (fmap fst (Map.elems known))
      byteQuota = knownBytes + sum [classLimit cls * classBytes cls | cls <- [RegistryBlob, RegistryLink, RegistryMetadata]]
      registryActual = knownBytes + sum [classBytes (objectClass obj) | (key, obj) <- Map.toList others,
          Text.isPrefixOf "/registry/" key, objectClass obj /= Canonical]
        + (if kind == Canonical || writer /= RegistryWriter then 0 else classBytes kind)
  unless (writer /= RegistryWriter || registryActual <= byteQuota) (Left "gateway-source-byte-quota-denied")
  let reservation = Reservation writer path kind bytes digest
  pure (state {statePending = Just reservation}, reservation)

finishWrite :: GatewayState -> Reservation -> Bool -> Either Text GatewayState
finishWrite state reservation success = do
  unless (statePending state == Just reservation) (Left "gateway-reservation-mismatch")
  pure $ if success
    then state {statePending = Nothing, stateObjects = Map.insert (reservationPath reservation)
      (AdmittedObject (reservationClass reservation) (reservationBytes reservation) (reservationDigest reservation)) (stateObjects state)}
    else state {statePending = Nothing, stateFailed = Map.insertWith (+) (reservationWriter reservation) 1 (stateFailed state)}

beginMultipart :: GatewayPolicy -> GatewayState -> Writer -> Text -> Either Text (GatewayState, Reservation)
beginMultipart policy state writer path = do
  (kind, maximumBytes, _) <- classify policy writer path
  unless (kind `elem` [RegistryMetadata, OffloadData, OffloadIndex]
    && path `notElem` Map.elems (stateUploads state) && Map.notMember path (stateObjects state))
    (Left "gateway-multipart-scope-or-conflict")
  beginWrite policy state writer path maximumBytes
    (if writer == OffloadWriter then "UNSIGNED-PAYLOAD" else "sha256:" <> Text.replicate 64 "0")

bindMultipart :: GatewayState -> Reservation -> Text -> Either Text GatewayState
bindMultipart state reservation uploadId = do
  unless (not (Text.null uploadId) && Text.length uploadId <= 256 && Map.notMember uploadId (stateUploads state))
    (Left "gateway-multipart-identity-invalid")
  committed <- finishWrite state reservation True
  pure committed {stateUploads = Map.insert uploadId (reservationPath reservation) (stateUploads committed)}

beginPart :: GatewayPolicy -> GatewayState -> Writer -> Text -> Text -> Natural -> Natural
  -> Either Text (GatewayState, Reservation)
beginPart policy state writer path uploadId number bytes = do
  unless (Map.lookup uploadId (stateUploads state) == Just path && number == 1 && bytes > 0)
    (Left "gateway-multipart-part-denied")
  obj <- maybe (Left "gateway-multipart-reservation-absent") Right (Map.lookup path (stateObjects state))
  unless (bytes <= objectExtent obj) (Left "gateway-multipart-extent-denied")
  beginWrite policy state writer path (objectExtent obj) (objectDigest obj)

recordPart :: GatewayState -> Reservation -> Text -> Natural -> Either Text GatewayState
recordPart state reservation uploadId bytes = do
  committed <- finishWrite state reservation True
  pure committed {stateParts = Map.insert uploadId bytes (stateParts committed)}

beginComplete :: GatewayPolicy -> GatewayState -> Writer -> Text -> Text
  -> Either Text (GatewayState, Reservation)
beginComplete policy state writer path uploadId = do
  unless (Map.lookup uploadId (stateUploads state) == Just path && Map.member uploadId (stateParts state))
    (Left "gateway-multipart-completion-denied")
  obj <- maybe (Left "gateway-multipart-reservation-absent") Right (Map.lookup path (stateObjects state))
  beginWrite policy state writer path (objectExtent obj) (objectDigest obj)

completeMultipart :: GatewayState -> Reservation -> Text -> Either Text GatewayState
completeMultipart state reservation uploadId = do
  extent <- maybe (Left "gateway-multipart-part-absent") Right (Map.lookup uploadId (stateParts state))
  committed <- finishWrite state reservation True
  pure committed {stateObjects = Map.adjust (\obj -> obj {objectExtent = extent}) (reservationPath reservation) (stateObjects committed),
    stateUploads = Map.delete uploadId (stateUploads committed), stateParts = Map.delete uploadId (stateParts committed)}

-- | Called only after observing a successful backend DELETE of an owned
-- registry temporary key. Failed generations are deliberately not released.
forgetTemporaryObject :: GatewayPolicy -> GatewayState -> Writer -> Text -> Either Text GatewayState
forgetTemporaryObject policy state writer path = do
  (kind, _, _) <- classify policy writer path
  unless (kind == RegistryMetadata && path `notElem` Map.elems (stateUploads state))
    (Left "gateway-delete-scope-denied")
  pure state {stateObjects = Map.delete path (stateObjects state)}

-- Cleanup is scoped to the producer's real object classes. The IO adapter
-- calls this only after successful deletion and independent HEAD absence.
forgetStoredObject :: GatewayPolicy -> GatewayState -> Writer -> Text -> Either Text GatewayState
forgetStoredObject policy state writer path = do
  (kind,_,_) <- classify policy writer path
  unless ((writer == RegistryWriter && kind == RegistryMetadata
    || writer == OffloadWriter && kind `elem` [OffloadData,OffloadIndex])
    && path `notElem` Map.elems (stateUploads state)) (Left "gateway-delete-scope-denied")
  pure state {stateObjects = Map.delete path (stateObjects state)}

-- A known multipart target remains charged until the adapter has observed
-- both NoSuchUpload and target absence. Aborting does not erase failed debt.
finishMultipartAbort :: GatewayPolicy -> GatewayState -> Writer -> Text -> Text -> Either Text GatewayState
finishMultipartAbort policy state writer path uploadId = do
  (kind,_,_) <- classify policy writer path
  unless (kind `elem` [RegistryMetadata,OffloadData,OffloadIndex]
    && Map.lookup uploadId (stateUploads state) == Just path && statePending state == Nothing)
    (Left "gateway-multipart-abort-scope-denied")
  pure state {stateObjects = Map.delete path (stateObjects state),
    stateUploads = Map.delete uploadId (stateUploads state),stateParts = Map.delete uploadId (stateParts state)}

ownsBucket :: Writer -> Text -> Bool
ownsBucket RegistryWriter bucket = bucket == "registry"
ownsBucket OffloadWriter bucket = bucket == "pulsar-offload"
ownsBucket ApplicationWriter bucket = bucket == "phase30-canary"

admitCopySource :: GatewayPolicy -> GatewayState -> Writer -> Text -> Either Text ()
admitCopySource policy state writer path = do
  unless (writer == RegistryWriter) (Left "gateway-copy-source-scope-denied")
  (kind, _, _) <- classify policy writer path
  unless (kind == RegistryMetadata && Map.member path (stateObjects state)
    && path `notElem` Map.elems (stateUploads state)) (Left "gateway-copy-source-scope-denied")

recoverInterrupted :: GatewayState -> GatewayState
recoverInterrupted state = case statePending state of
  Nothing -> state
  Just reservation -> state {statePending = Nothing,
    stateFailed = Map.insertWith (+) (reservationWriter reservation) 1 (stateFailed state)}

gatewayStateValue :: GatewayState -> Value
gatewayStateValue = toJSON

decodeGatewayState :: Value -> Either Text GatewayState
decodeGatewayState value = case fromJSON value of
  Error _ -> Left "gateway-state-invalid"
  Success state -> do
    unless (Map.size (stateObjects state) <= 1300 && all (\(writer, count) -> count <= failureLimit writer)
      (Map.toList (stateFailed state))) (Left "gateway-state-bound-exceeded")
    pure state

admittedObject :: GatewayState -> Text -> Maybe (Natural, Text)
admittedObject state path = (\obj -> (objectExtent obj, objectDigest obj)) <$> Map.lookup path (stateObjects state)

stateObjectCount :: GatewayState -> Int
stateObjectCount = Map.size . stateObjects

-- A missing local state file is not evidence that a retained backend is
-- empty. Canonical image residents are charged from the immutable inventory;
-- every other backend key and upload must join a durable owned reservation.
-- Absent backend residents remain charged until explicit observed cleanup.
validateBackendInventory :: GatewayPolicy -> GatewayState -> [(Text,Natural)] -> [(Text,Text)] -> Either Text ()
validateBackendInventory policy@(GatewayPolicy known _ _) state objects uploads = do
  unless (length objects == Map.size (Map.fromList objects)
    && length uploads == Map.size (Map.fromList [(upload,path) | (path,upload) <- uploads]))
    (Left "gateway-backend-inventory-duplicate")
  mapM_ (\(path,bytes) -> case Map.lookup path known of
    Just (expected,_) -> unless (bytes == expected) (Left "gateway-backend-canonical-extent-mismatch")
    Nothing -> case Map.lookup path (stateObjects state) of
      Nothing -> Left "gateway-backend-unreserved-object"
      Just resident -> unless (bytes <= objectExtent resident) (Left "gateway-backend-object-extent-mismatch")) objects
  mapM_ (\(path,upload) -> unless (Map.lookup upload (stateUploads state) == Just path)
    (Left "gateway-backend-unreserved-upload")) uploads
  mapM_ (\(path,resident) -> do
    let writer = if Text.isPrefixOf "/registry/" path then RegistryWriter else
          if Text.isPrefixOf "/pulsar-offload/" path then OffloadWriter else ApplicationWriter
    (kind,maximumBytes,_) <- classify policy writer path
    unless (kind == objectClass resident && objectExtent resident <= maximumBytes)
      (Left "gateway-state-policy-mismatch")) (Map.toList (stateObjects state))
  mapM_ (\kind -> unless (fromIntegral (length (filter ((==kind) . objectClass) (Map.elems (stateObjects state)))) <= classLimit kind)
    (Left "gateway-state-class-count-exceeded")) [Canonical,RegistryBlob,RegistryLink,RegistryMetadata,OffloadData,OffloadIndex,ApplicationCanary]

classify :: GatewayPolicy -> Writer -> Text -> Either Text (ObjectClass, Natural, Maybe Text)
classify (GatewayPolicy known _ _) RegistryWriter path = case Map.lookup path known of
  Just (bytes, digest) -> Right (Canonical, bytes, Just digest)
  Nothing
    | Just raw <- Text.stripPrefix "/registry/docker/registry/v2/blobs/sha256/" path
    , [prefix, digest, "data"] <- Text.splitOn "/" raw
    , Text.take 2 digest == prefix && hexDigest digest -> Right (RegistryBlob, 65536, Just ("sha256:" <> digest))
    | Just raw <- Text.stripPrefix "/registry/docker/registry/v2/repositories/amoebius/phase30-new/_layers/sha256/" path
    , [digest, "link"] <- Text.splitOn "/" raw, hexDigest digest -> Right (RegistryLink, 71, Just (linkDigest digest))
    | Text.isPrefixOf "/registry/docker/registry/v2/repositories/amoebius/phase30-new/_uploads/" path
    , Text.length path <= 512, all validPart (Text.splitOn "/" (Text.drop 1 path)) ->
        Right (RegistryMetadata, 4096, Nothing)
    | otherwise -> Left "gateway-writer-scope-denied"
classify _ OffloadWriter path
  | Just key <- Text.stripPrefix "/pulsar-offload/" path
  , [uuid, ledger] <- Text.splitOn "-ledger-" key
  , fmap Text.length (Text.splitOn "-" uuid) == [8,4,4,4,12]
  , Text.all (\character -> character == '-' || character `elem` ("0123456789abcdef" :: String)) uuid
  , let number = maybe ledger id (Text.stripSuffix "-index" ledger)
  , not (Text.null number), Text.all (`elem` ("0123456789" :: String)) number =
      Right (if Text.isSuffixOf "-index" ledger then OffloadIndex else OffloadData, mib, Nothing)
  | otherwise = Left "gateway-writer-scope-denied"

classify _ ApplicationWriter path
  | path == "/phase30-canary/admitted-canary" = Right (ApplicationCanary, 4096, Nothing)
  | otherwise = Left "gateway-writer-scope-denied"

expectedObjectDigest :: GatewayPolicy -> Writer -> Text -> Either Text (Maybe Text)
expectedObjectDigest policy writer path = (\(_, _, digest) -> digest) <$> classify policy writer path

classLimit :: ObjectClass -> Natural
classLimit kind = case kind of
  Canonical -> 1024; RegistryBlob -> 1; RegistryLink -> 1; RegistryMetadata -> 16
  OffloadData -> 128; OffloadIndex -> 128; ApplicationCanary -> 1

classBytes :: ObjectClass -> Natural
classBytes kind = case kind of
  Canonical -> 0; RegistryBlob -> 65536; RegistryLink -> 71; RegistryMetadata -> 4096
  OffloadData -> mib; OffloadIndex -> mib; ApplicationCanary -> 4096

failureLimit :: Writer -> Natural
failureLimit RegistryWriter = 3
failureLimit OffloadWriter = 2
failureLimit ApplicationWriter = 1

linkDigest :: Text -> Text
linkDigest digest = Text.decodeUtf8 ("sha256:" <> sha256Hex (Text.encodeUtf8 ("sha256:" <> digest)))

validDigest :: Text -> Bool
validDigest digest = maybe False hexDigest (Text.stripPrefix "sha256:" digest)

hexDigest :: Text -> Bool
hexDigest digest = Text.length digest == 64 && Text.all (`elem` ("0123456789abcdef" :: String)) digest

validPart :: Text -> Bool
validPart part = not (Text.null part) && part `notElem` [".", ".."]
  && Text.all (`elem` ("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-" :: String)) part

mib :: Natural
mib = 1048576
