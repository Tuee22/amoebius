{-# LANGUAGE OverloadedStrings #-}

module ZooKeeperHistoryStoreSpec (verifyZooKeeperHistoryStore) where

import Amoebius.Platform.ZooKeeperHistory
import Amoebius.Platform.ZooKeeperHistoryStore
import Amoebius.Platform.HistoryStoreProvision
import Amoebius.Platform.S3Signing (sha256Hex)
import Control.Concurrent (forkIO, newEmptyMVar, putMVar, takeMVar)
import Control.Exception
import Control.Monad (forM_, unless, when, void)
import Data.Aeson
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (parseEither)
import Data.Bits ((.&.))
import Data.ByteString qualified as BS
import Data.List (sort)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text
import Numeric (readHex)
import Numeric.Natural (Natural)
import System.Directory
import System.Exit (ExitCode (..), die)
import System.FilePath ((</>))
import System.IO.Temp (withTempDirectory)
import System.Posix.Files qualified as Files
import System.Posix.Process qualified as Process
import System.Posix.Signals (sigKILL, signalProcess)
import System.Posix.Types (ProcessID)
import System.Timeout (timeout)

verifyZooKeeperHistoryStore :: IO ()
verifyZooKeeperHistoryStore = do
  bytes <- BS.readFile "test/oracle/platform_backbone_zookeeper_history_store.json"
  check "independent-store-corpus-digest" (sha256Hex bytes == "806c20f1cfb37431f783768eb53f34e203751acf2d60b5f615f5d4f5ddf89fb4")
  corpus <- right (eitherDecodeStrict' bytes)
  original <- BS.readFile "test/oracle/platform_backbone_zookeeper_history.json"
  field corpus "originalHistoryCorpusSha256" >>= \digest -> check "original-history-input" (sha256Hex original == Text.encodeUtf8 digest)
  policyValue <- field corpus "policy"
  policy <- parsePolicy policyValue
  encodingBound <- field corpus "nativeEncodingUpperBound" :: IO Value
  forM_ (Map.toList (historyStateEncodingBounds policy)) $ \(axis,actual) ->
    field encodingBound axis >>= check ("native-encoding-bound-" <> axis) . (==actual)
  states <- field corpus "states" :: IO (Map.Map Text Value)
  commands <- field corpus "commands" :: IO (Map.Map Text Value)
  maximumBytes <- field corpus "storeMaximumBytes"
  check "store-total-file-limit" (historyStoreMaximumBytes == maximumBytes)
  cases <- field corpus "cases" :: IO [Value]
  faults <- field corpus "faultCases" :: IO [Value]
  invalid <- field corpus "invalidWireCases" :: IO [Value]
  let frozen key = maybe (die "unknown independent store state") pure (Map.lookup key states)
      wire key = frozen key >>= \row -> field row "wireHex" >>= decodeHex
      command key = maybe (die "unknown independent store command") (right . historyCommandFromValue) (Map.lookup key commands)
      summary key actual = do
        row <- frozen key
        unique <- field row "expectedGlobalUniqueFramedBytes"
        physical <- field row "expectedPhysicalFramedBytesMember0"
        checkSummary key unique physical actual
      prepare sandbox row = do
        let root = sandbox </> "store"
        initializeHistoryStore policy root
        setup <- optional row "setup" :: IO (Maybe Text)
        current <- optional row "current" :: IO (Maybe Text)
        selected <- case (setup,current) of
          (Just key,_) -> pure (Just key)
          (_,Just key) -> pure (Just key)
          _ -> pure Nothing
        case selected of
          Just "bad-checksum" -> BS.writeFile (root </> "state") ("AHST1\n" <> BS.replicate 64 48 <> "\nbad")
          Just key -> wire key >>= BS.writeFile (root </> "state")
          Nothing -> removeFile (root </> "state")
        candidate <- optional row "candidate" :: IO (Maybe Text)
        forM_ candidate (\key -> wire key >>= writePrivate (root </> "state.next"))
        raw <- optional row "candidateRawHex" :: IO (Maybe Text)
        forM_ raw (\hex -> decodeHex hex >>= writePrivate (root </> "state.next"))
        repeated <- optional row "candidateRepeat" :: IO (Maybe Value)
        forM_ repeated (\spec -> repeatedBytes spec >>= writePrivate (root </> "state.next"))
        extras <- optional row "extraFiles" :: IO (Maybe [FilePath])
        forM_ (maybe [] id extras) (\name -> writePrivate (root </> name) "unexpected")
        pure root
      reopen root key = do
        withHistoryStore policy root $ \store -> readHistoryStoreSummary store >>= right >>= summary key
        expected <- wire key
        actual <- BS.readFile (root </> "state")
        check key (expected == actual)
  -- Four encodings are literal independent input, then are reproduced by
  -- actual acknowledged transitions rather than copied back as expectations.
  withSandbox "phase30-history-wire-" $ \sandbox -> do
    let root = sandbox </> "store"
    initializeHistoryStore policy root
    reopen root "empty"
    appendValue <- maybe (die "missing original command") pure (Map.lookup "append-session-present-digest" commands)
    reserve <- right (historyCommandFromValue (setField appendValue "operation" (String "reserve")))
    append <- command "append-session-present-digest"
    withHistoryStore policy root $ \store -> do
      forM_ [(reserve,"reserved"),(append,"acknowledged"),(append,"next-unacknowledged")] $ \(op,key) -> do
        submitHistoryCommand store op >>= right >>= summary key
        actual <- BS.readFile (root </> "state")
        expected <- wire key
        check key (actual == expected)
  forM_ cases $ \row -> withSandbox "phase30-history-case-" $ \sandbox -> do
    name <- field row "id"
    operation <- field row "operation" :: IO Text
    expected <- field row "expectedAdmission" :: IO Text
    case operation of
      "initialize" -> do
        rootKind <- field row "root" :: IO Text
        let root = sandbox </> "store"; external = sandbox </> "external"
        case rootKind of
          "missing" -> pure ()
          "existing-empty-directory" -> createDirectory root
          "existing-initialized-directory" -> initializeHistoryStore policy root
          "existing-file" -> writePrivate root "original"
          "symlink-root" -> createDirectory external >> Files.createSymbolicLink external root
          _ -> die "unknown initialization input"
        before <- if rootKind == "existing-initialized-directory" then BS.readFile (root </> "state") else pure BS.empty
        result <- try @SomeException (initializeHistoryStore policy root)
        checkAdmission name expected result
        if expected == "allow" then do
          reopen root "empty"
          directory <- Files.getSymbolicLinkStatus root
          check name (Files.fileMode directory .&. 0o777 == 0o700)
          names <- sort <$> listDirectory root
          check name (names == ["owner.lock","state"])
          forM_ names $ \file -> Files.getSymbolicLinkStatus (root </> file) >>= \status ->
            check name (Files.fileMode status .&. 0o777 == 0o600)
        else do
          when (rootKind == "existing-file") (BS.readFile root >>= check name . (=="original"))
          when (rootKind == "existing-initialized-directory") (BS.readFile (root </> "state") >>= check name . (==before))
          when (rootKind == "existing-empty-directory" || rootKind == "symlink-root")
            (listDirectory root >>= check name . null)
      "resume" -> do
        rootKind <- optional row "root" :: IO (Maybe Text)
        if rootKind == Just "missing" then do
          checkAdmission name expected =<< try @SomeException (withHistoryStore policy (sandbox </> "missing") (const (pure ())))
          doesPathExist (sandbox </> "missing") >>= check name . not
        else do
          root <- prepare sandbox row
          mutation <- optional row "mutation" :: IO (Maybe Text)
          externalCheck <- maybe (pure (pure ())) (mutateIdentity sandbox root) mutation
          before <- snapshotFiles root
          edits <- optional row "policyEdits" :: IO (Maybe Value)
          selectedPolicy <- maybe (pure policy) (parsePolicy . mergeValue policyValue) edits
          result <- try @SomeException $ withHistoryStore selectedPolicy root $ \store ->
            readHistoryStoreSummary store >>= right
          checkAdmission name expected result
          externalCheck
          if expected == "deny" then snapshotFiles root >>= check name . (==before)
          else do
            key <- field row "expectedState"
            either throwIO (summary key) result
            reopen root key
            doesPathExist (root </> "state.next") >>= check name . not
      "lock-same-process" -> do
        root <- prepare sandbox row
        withHistoryStore policy root $ \owner -> do
          checkAdmission name expected =<< bounded (withHistoryStore policy root (const (pure ())))
          readHistoryStoreSummary owner >>= right >>= summary "acknowledged"
      "lock-child" -> do
        root <- prepare sandbox row
        withHistoryStore policy root $ \owner -> do
          child <- Process.forkProcess $ do
            result <- try @SomeException (withHistoryStore policy root (const (pure ())))
            Process.exitImmediately (case result of Left _ -> ExitSuccess; Right _ -> ExitFailure 91)
          waitChild name child
          readHistoryStoreSummary owner >>= right >>= summary "acknowledged"
      "lock-after-exit" -> do
        root <- prepare sandbox row
        -- Parent has no store/lock descriptor to inherit in this child.
        child <- Process.forkProcess $ withHistoryStore policy root $ \store -> do
          readHistoryStoreSummary store >>= right >>= summary "acknowledged"
          Process.exitImmediately ExitSuccess
        waitChild name child
        reopen root "acknowledged"
      "submit" -> do
        root <- prepare sandbox row
        stages <- newEmptyMVar
        putMVar stages ([] :: [Text])
        key <- field row "command"
        op <- command key
        withObservedHistoryStore policy root (\stage -> do
          old <- takeMVar stages
          -- At every observed frontier there are at most current+candidate.
          names <- listDirectory root
          check name (length (filter (`elem` ["state","state.next"]) names) <= 2)
          putMVar stages (old <> [Text.pack (show stage)])) $ \store -> do
            result <- submitHistoryCommand store op
            check name (either (const (expected == "deny")) (const (expected == "allow")) result)
            expectedStages <- if expected == "allow" then field row "expectedStageOrder" else field row "expectedPersistenceStages"
            takeMVar stages >>= check name . (==expectedStages)
            final <- field row "expectedState"
            readHistoryStoreSummary store >>= right >>= summary final
        final <- field row "expectedState"
        reopen root final
      "concurrent-submit" -> do
        root <- prepare sandbox row
        keys <- field row "commands" :: IO [Text]
        withHistoryStore policy root $ \store -> do
          replies <- mapM (\key -> do
            op <- command key
            reply <- newEmptyMVar
            void (forkIO (try @SomeException (submitHistoryCommand store op >>= right) >>= putMVar reply))
            pure reply) keys
          actual <- mapM (\reply -> takeMVar reply >>= either throwIO pure >>= physicalDebit) replies
          expectedDebits <- field row "expectedReturnedPhysicalDebitsUnordered"
          check name (sort actual == sort expectedDebits)
          unique <- field row "expectedGlobalUniqueFramedBytes"
          physical <- field row "expectedFinalPhysicalFramedBytesMember0"
          readHistoryStoreSummary store >>= right >>= checkSummary name unique physical
        unique <- field row "expectedGlobalUniqueFramedBytes"
        physical <- field row "expectedFinalPhysicalFramedBytesMember0"
        withHistoryStore policy root $ \store -> readHistoryStoreSummary store >>= right >>= checkSummary name unique physical
      "closed-handle" -> do
        root <- prepare sandbox row
        closed <- withHistoryStore policy root pure
        op <- command "append-session-present-digest"
        readHistoryStoreSummary closed >>= checkDenied name "store-closed"
        submitHistoryCommand closed op >>= checkDenied name "store-closed"
      _ -> die ("unknown frozen store operation: " <> Text.unpack operation)
  forM_ faults $ \row -> forM_ [False,True] $ \killProcess ->
    withSandbox "phase30-history-fault-" $ \sandbox -> do
      name <- field row "id"
      stageName <- field row "stage"
      stage <- maybe (die "unknown frozen fault stage") pure (lookup stageName [(Text.pack (show s),s) | s <- allStages])
      root <- prepare sandbox row
      key <- field row "command"
      op <- command key
      if killProcess then do
        -- No parent store is open: child's lock disappears on actual exit.
        child <- Process.forkProcess $ withObservedHistoryStore policy root
          (\seen -> when (seen == stage) (Process.exitImmediately ExitSuccess)) $ \store -> do
            void (submitHistoryCommand store op)
            Process.exitImmediately (ExitFailure 92)
        waitChild name child
      else withObservedHistoryStore policy root
        (\seen -> when (seen == stage) (throwIO (userError "independent-persistence-fault"))) $ \store -> do
          attempted <- try @SomeException (submitHistoryCommand store op)
          checkAdmission name "deny" attempted
          readHistoryStoreSummary store >>= checkDenied name "store-poisoned"
          submitHistoryCommand store op >>= checkDenied name "store-poisoned"
      expectedState <- field row "expectedVisibleStateOnProcessReopen"
      reopen root expectedState
      doesPathExist (root </> "state.next") >>= check name . not
  forM_ invalid $ \row -> withSandbox "phase30-history-invalid-" $ \sandbox -> do
    let root = sandbox </> "store"
    initializeHistoryStore policy root
    name <- field row "id"
    hex <- optional row "wireHex"
    encoded <- case hex of Just text -> decodeHex text; Nothing -> field row "repeat" >>= repeatedBytes
    BS.writeFile (root </> "state") encoded
    checkAdmission name "deny" =<< try @SomeException (withHistoryStore policy root (const (pure ())))
    BS.readFile (root </> "state") >>= check name . (==encoded)
  verifyAdditiveStorage policy bytes
  putStrLn "ZooKeeper durable history store:32API +10exception/process faults +12wire +4literal encodings PASS"

verifyAdditiveStorage :: HistoryPolicy -> BS.ByteString -> IO ()
verifyAdditiveStorage policy storeCorpus = do
  bytes <- BS.readFile "test/oracle/platform_backbone_history_store_storage.json"
  check "independent-additive-storage-digest" (sha256Hex bytes == "2e82dfb999777eaa707abe5bf4d396ceb8f35e86e55256ca5a2e9a63905fc61e")
  amendment <- right (eitherDecodeStrict' bytes)
  digest <- field amendment "historyStoreCorpusSha256"
  check "additive-original-store-corpus" (sha256Hex storeCorpus == Text.encodeUtf8 digest)
  gateway <- BS.readFile "test/oracle/platform_backbone_gateway.json"
  gatewayDigest <- field amendment "originalGatewayOracleSha256"
  check "original-gateway-oracle-unchanged" (sha256Hex gateway == Text.encodeUtf8 gatewayDigest)
  operands <- field amendment "operands"
  literalDemand <- parseStorageDemand operands
  check "native-default-retains-all-independent-operands"
    (nativeHistoryStoreStorageDemand policy (parentRawSupplyBytes literalDemand) == literalDemand)
  expected <- field amendment "expected"
  totals <- field expected "unchangedRawTotals"
  parentRequired <- field totals "pool_raw_bytes"
  cases <- field amendment "boundaries" :: IO [Value]
  coordinatedBytes <- BS.readFile "test/oracle/platform_backbone_history_store_storage_coordinated.json"
  check "independent-coordinated-storage-digest" (sha256Hex coordinatedBytes == "1eeb51725e5bcd54c2ee3f1ebc88ca81ccbfe65d51c9d1daf333cd26dc298397")
  coordinated <- right (eitherDecodeStrict' coordinatedBytes)
  field coordinated "baseAmendmentSha256" >>= \base -> check "coordinated-original-additive-input" (sha256Hex bytes == Text.encodeUtf8 base)
  extra <- field coordinated "cases"
  forM_ (fmap (\row -> setField row "parentRequiredRawBytes" (toJSON (parentRequired :: Natural))) cases <> extra) $ \row -> do
    name <- field row "id"
    edits <- field row "edits"
    required <- field row "parentRequiredRawBytes"
    demand <- parseStorageDemand (mergeValue operands edits)
    admission <- field row "expectedAdmission" :: IO Text
    let actual = provisionHistoryStoreStorage policy required demand
    case actual of
      Left problem -> do
        locus <- field row "expectedLocus"
        check name (admission == "deny" && locus == problem)
      Right witness -> do
        check name (admission == "allow")
        let projection = historyStoreStorageProjection witness
        original <- field projection "originalGateway"
        field original "dedicatedUsableBytes" >>= \amount ->
          field expected "unchangedOriginalGatewayUsableBytes" >>= check name . (== (amount :: Natural))
        history <- field projection "metadataHistory"
        field history "dedicatedUsableBytes" >>= \amount ->
          field expected "additionalHistoryStoreUsableBytes" >>= check name . (== (amount :: Natural))
        forM_ [("combinedFilesystemUsableBytes","combinedGatewayFilesystemUsableBytes"),
          ("presentedBytes","presentedBytesAfter500BasisPoints"),("requiredRawBytes","rawFilesystemBytes")] $ \(key,reference) -> do
            actualBytes <- field projection key :: IO Natural
            field expected reference >>= check name . (==actualBytes)

parseStorageDemand :: Value -> IO HistoryStoreStorageDemand
parseStorageDemand value = HistoryStoreStorageDemand
  <$> field value "gatewayCurrentBytes" <*> field value "gatewayCandidateBytes"
  <*> field value "gatewayFailedBytes" <*> field value "gatewayControlReserveBytes"
  <*> field value "gatewayDedicatedUsableBytes" <*> field value "historyCurrentSlotBytes"
  <*> field value "historyCandidateSlotBytes" <*> field value "historyExtraReaderSlotBytes"
  <*> field value "historyMaximumExtraReaders" <*> field value "historyEnforcedFileMaximumBytes"
  <*> field value "historyNativeEncodingUpperBoundBytes" <*> field value "historyDedicatedUsableBytes"
  <*> field value "combinedFilesystemUsableSupplyBytes" <*> field value "rawFilesystemSupplyBytes"
  <*> field value "filesystemOverheadBasisPoints" <*> field value "minimumRawBytes"
  <*> field value "rawQuantumBytes" <*> field value "parentRawSupplyBytes"

withSandbox :: String -> (FilePath -> IO value) -> IO value
withSandbox prefix action = withTempDirectory ".build/tmp" prefix (\path -> makeAbsolute path >>= action)

allStages :: [HistoryStoreStage]
allStages = [BeforeCandidateWrite,AfterCandidateWrite,AfterCandidateSync,AfterStateRename,AfterDirectorySync]

mutateIdentity :: FilePath -> FilePath -> Text -> IO (IO ())
mutateIdentity sandbox root mutation = do
  let external = sandbox </> "external"
      current = root </> "state"
      candidate = root </> "state.next"
      lock = root </> "owner.lock"
  original <- BS.readFile current
  writePrivate external original
  case mutation of
    "current-symlink" -> removeFile current >> Files.createSymbolicLink external current
    "candidate-symlink" -> Files.createSymbolicLink external candidate
    "lock-symlink" -> removeFile lock >> Files.createSymbolicLink external lock
    "current-hardlink" -> removeFile current >> Files.createLink external current
    "candidate-hardlink-current" -> Files.createLink current candidate
    "lock-hardlink" -> removeFile lock >> BS.writeFile external BS.empty >> Files.createLink external lock
    "current-directory" -> removeFile current >> createDirectory current
    "candidate-fifo" -> Files.createNamedPipe candidate 0o600
    "shared-root-mode" -> Files.setFileMode root 0o770
    "shared-file-mode" -> Files.setFileMode current 0o640
    "nonempty-owner-lock" -> BS.writeFile lock "not-empty"
    _ -> die "unknown frozen identity mutation"
  before <- BS.readFile external
  pure (BS.readFile external >>= check mutation . (==before))

-- Do not read FIFOs or follow a rejected link while checking zero effect.
snapshotFiles :: FilePath -> IO [(FilePath, Integer, Integer, Integer, Maybe BS.ByteString)]
snapshotFiles root = do
  names <- sort <$> listDirectory root
  mapM (\name -> do
    let path = root </> name
    status <- Files.getSymbolicLinkStatus path
    bytes <- if Files.isRegularFile status then Just <$> BS.readFile path else pure Nothing
    pure (name,fromIntegral (Files.fileID status),fromIntegral (Files.fileMode status),fromIntegral (Files.fileSize status),bytes)) names

bounded :: IO value -> IO (Either SomeException value)
bounded action = do
  result <- try @SomeException (timeout 5000000 action)
  case result of
    Left problem -> pure (Left problem)
    Right Nothing -> die "store lock unexpectedly blocked"
    Right (Just value) -> pure (Right value)

waitChild :: Text -> ProcessID -> IO ()
waitChild name child = do
  result <- timeout 5000000 (Process.getProcessStatus True False child)
  case result of
    Just (Just (Process.Exited ExitSuccess)) -> pure ()
    Nothing -> do
      void (try @SomeException (signalProcess sigKILL child))
      void (Process.getProcessStatus True False child)
      die ("store child failed/blocked: " <> Text.unpack name)
    _ -> die ("store child failed: " <> Text.unpack name)

writePrivate :: FilePath -> BS.ByteString -> IO ()
writePrivate path bytes = BS.writeFile path bytes >> Files.setFileMode path 0o600

physicalDebit :: Value -> IO Natural
physicalDebit value = field value "members" >>= \members -> field members "0" >>= \member -> field member "physicalFramedBytes"

checkSummary :: Text -> Natural -> Natural -> Value -> IO ()
checkSummary name unique physical actual = do
  field actual "globalUniqueFramedBytes" >>= check name . (==unique)
  physicalDebit actual >>= check name . (==physical)

parsePolicy :: Value -> IO HistoryPolicy
parsePolicy value = do
  members <- field value "members"; snapshot <- field value "snapshotBytes"; bootstrap <- field value "bootstrapBytes"
  physical <- field value "physicalBytesPerMember"; logs <- field value "logGenerationsPerMember"; snapshots <- field value "snapshotGenerationsPerMember"
  right (historyPolicy members snapshot bootstrap physical logs snapshots)

field :: FromJSON value => Value -> Text -> IO value
field value name = right (parseEither (withObject "independent store case" (.: Key.fromText name)) value)
optional :: FromJSON value => Value -> Text -> IO (Maybe value)
optional value name = right (parseEither (withObject "independent optional operand" (.:? Key.fromText name)) value)
setField :: Value -> Text -> Value -> Value
setField (Object fields) key value = Object (KeyMap.insert (Key.fromText key) value fields)
setField _ _ _ = error "independent object expected"
mergeValue :: Value -> Value -> Value
mergeValue (Object original) (Object edits) = Object (KeyMap.union edits original)
mergeValue _ _ = error "independent policy objects expected"
repeatedBytes :: Value -> IO BS.ByteString
repeatedBytes spec = BS.replicate <$> field spec "count" <*> field spec "byte"
decodeHex :: Text -> IO BS.ByteString
decodeHex text = BS.pack <$> go (Text.unpack text)
 where
  go [] = pure []
  go (a:b:rest) = case readHex [a,b] of [(byte,"")] -> (byte:) <$> go rest; _ -> die "invalid independent hex"
  go _ = die "odd independent hex"
checkAdmission :: Text -> Text -> Either SomeException value -> IO ()
checkAdmission name expected result = check name (either (const (expected == "deny")) (const (expected == "allow")) result)
checkDenied :: Text -> Text -> Either Text value -> IO ()
checkDenied name tag result = check name (either (Text.isInfixOf tag) (const False) result)
check :: Text -> Bool -> IO ()
check name condition = unless condition (die ("independent durable history store: " <> Text.unpack name))
right :: Show problem => Either problem value -> IO value
right = either (die . show) pure
