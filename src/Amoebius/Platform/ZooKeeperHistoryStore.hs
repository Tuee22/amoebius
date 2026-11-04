{-# LANGUAGE ForeignFunctionInterface #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Durable serialization of cumulative reservations. This is not a JVM
-- interceptor: an adapter must obtain a successful grant before its effect.
-- The Linux store owns a new private directory and never initializes on resume.
module Amoebius.Platform.ZooKeeperHistoryStore
  ( HistoryStore, initializeHistoryStore, withHistoryStore, submitHistoryCommand
  , readHistoryStoreSummary, HistoryStoreStage (..), withObservedHistoryStore
  , historyStoreMaximumBytes
  , historyStorePolicy
  ) where

import Amoebius.Platform.S3Signing (sha256Hex)
import Amoebius.Platform.ZooKeeperHistory
import Control.Concurrent.MVar
import Control.Exception
import Control.Monad (unless)
import Data.Aeson (Value (..), ToJSON (toEncoding), eitherDecodeStrict')
import Data.Aeson.Encoding qualified as Encoding
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Bits ((.&.))
import Data.ByteString qualified as BS
import Data.ByteString.Lazy qualified as Lazy
import Data.Foldable (toList)
import Data.List (sort)
import Data.Text (Text)
import Foreign.C.Error (throwErrnoIfMinus1_)
import Foreign.C.Types (CInt (..))
import System.Directory (listDirectory, removeFile, renameFile)
import System.FilePath (takeDirectory, (</>))
import System.IO (hFlush, hClose)
import System.IO.Error (isDoesNotExistError)
import System.Posix.Files qualified as Files
import System.Posix.Directory qualified as Directory
import System.Posix.IO qualified as Posix
import System.Posix.Types (Fd (..))
import System.Posix.User (getEffectiveUserID)

foreign import ccall unsafe "fsync" c_fsync :: CInt -> IO CInt
foreign import ccall unsafe "flock" c_flock :: CInt -> CInt -> IO CInt

data HistoryStoreStage = BeforeCandidateWrite | AfterCandidateWrite | AfterCandidateSync
  | AfterStateRename | AfterDirectorySync
  deriving stock (Eq, Show)
data StoreAvailability = Available HistoryState | Poisoned | Closed
data HistoryStore = HistoryStore HistoryPolicy Fd (MVar StoreAvailability) (HistoryStoreStage -> IO ())

historyStorePolicy :: HistoryStore -> HistoryPolicy
historyStorePolicy (HistoryStore policy _ _ _) = policy

historyStoreMaximumBytes :: Int
historyStoreMaximumBytes = 1048576

-- A caller cannot turn a missing/corrupt resume into fresh counters. Even a
-- preexisting empty directory rejects; interrupted initialization fails closed.
initializeHistoryStore :: HistoryPolicy -> FilePath -> IO ()
initializeHistoryStore policy path = mask_ $ do
  Directory.createDirectory path 0o700
  syncDirectory (takeDirectory path)
  bracket (openDirectory path) Posix.closeFd $ \directory -> do
    bracket (openRegular directory "owner.lock" True) Posix.closeFd $ \lock -> do
      acquireLock lock
      syncFd lock
      encoded <- encodeState policy (emptyHistoryState policy)
      persist directory (const (pure ())) encoded

withHistoryStore :: HistoryPolicy -> FilePath -> (HistoryStore -> IO value) -> IO value
withHistoryStore policy path = withObservedHistoryStore policy path (const (pure ()))

-- The observer may interrupt a test at an actual persistence frontier. It
-- cannot replace a write/sync or manufacture a grant. Exceptions poison the
-- handle, including exceptions after the rename or final directory sync.
withObservedHistoryStore :: HistoryPolicy -> FilePath -> (HistoryStoreStage -> IO ())
  -> (HistoryStore -> IO value) -> IO value
withObservedHistoryStore policy path observer action =
  bracket (openDirectory path) Posix.closeFd $ \directory ->
    bracket (openRegular directory "owner.lock" False) Posix.closeFd $ \lock -> do
      acquireLock lock
      checkInventory directory
      previous <- loadState policy directory
      discardCandidate directory
      state <- newMVar (Available previous)
      let store = HistoryStore policy directory state observer
      action store `finally` modifyMVar_ state (const (pure Closed))

submitHistoryCommand :: HistoryStore -> HistoryCommand -> IO (Either Text Value)
submitHistoryCommand (HistoryStore policy directory state observer) command = do
  result <- modifyMVar state $ \availability -> mask_ $ case availability of
    Poisoned -> pure (Poisoned, Right (Left "zookeeper-history-store-poisoned"))
    Closed -> pure (Closed, Right (Left "zookeeper-history-store-closed"))
    Available old -> case applyHistoryCommand policy old command of
      Left problem -> pure (Available old, Right (Left problem))
      Right next -> do
        attempted <- try @SomeException $ do
          encoded <- encodeState policy next
          checkInventory directory
          persist directory observer encoded
          either (fail . show) pure (historyStateSummary policy next)
        case attempted of
          Left problem -> pure (Poisoned, Left problem)
          Right summary -> pure (Available next, Right (Right summary))
  either throwIO pure result

readHistoryStoreSummary :: HistoryStore -> IO (Either Text Value)
readHistoryStoreSummary (HistoryStore policy _ state _) = withMVar state $ \availability ->
  pure $ case availability of
    Available current -> historyStateSummary policy current
    Poisoned -> Left "zookeeper-history-store-poisoned"
    Closed -> Left "zookeeper-history-store-closed"

encodeState :: HistoryPolicy -> HistoryState -> IO BS.ByteString
encodeState policy state = do
  value <- either (fail . show) pure (historyStateValue policy state)
  let payload = Lazy.toStrict (Encoding.encodingToLazyByteString (canonicalEncoding value))
      encoded = "AHST1\n" <> sha256Hex payload <> "\n" <> payload
  unless (BS.length encoded <= historyStoreMaximumBytes) (fail "zookeeper-history-store-extent-limit")
  pure encoded

-- The admitted state has ASCII keys/identities and integral operands. Its
-- convention is UTF-8, recursively sorted object keys, compact punctuation,
-- ascending record/member/name rows from the model, and no trailing newline.
canonicalEncoding :: Value -> Encoding.Encoding
canonicalEncoding (Object fields) = Encoding.pairs
  (foldMap (\(key,value) -> Encoding.pair key (canonicalEncoding value)) (KeyMap.toAscList fields))
canonicalEncoding (Array values) = Encoding.list canonicalEncoding (toList values)
canonicalEncoding value = toEncoding value

loadState :: HistoryPolicy -> Fd -> IO HistoryState
loadState policy directory = do
  encoded <- bracket (openRegular directory "state" False) Posix.closeFd $ \descriptor -> do
    status <- Files.getFdStatus descriptor
    unless (Files.fileSize status <= fromIntegral historyStoreMaximumBytes)
      (fail "zookeeper-history-store-extent-limit")
    -- dup transfers only the duplicate's ownership to the Handle.
    bracket (Posix.dup descriptor >>= Posix.fdToHandle) hClose $ \stream -> do
      bytes <- BS.hGet stream (historyStoreMaximumBytes+1)
      after <- Files.getFdStatus descriptor
      unless (BS.length bytes == fromIntegral (Files.fileSize status)
        && Files.fileSize after == Files.fileSize status
        && Files.modificationTimeHiRes after == Files.modificationTimeHiRes status
        && Files.statusChangeTimeHiRes after == Files.statusChangeTimeHiRes status)
        (fail "zookeeper-history-store-short-or-changing-read")
      pure bytes
  unless (BS.take 6 encoded == "AHST1\n" && BS.take 1 (BS.drop 70 encoded) == "\n")
    (fail "zookeeper-history-store-envelope-invalid")
  let digest = BS.take 64 (BS.drop 6 encoded)
      payload = BS.drop 71 encoded
  unless (digest == sha256Hex payload) (fail "zookeeper-history-store-checksum-invalid")
  value <- either (const (fail "zookeeper-history-store-json-invalid")) pure (eitherDecodeStrict' payload)
  state <- either (fail . show) pure (decodeHistoryState policy value)
  canonical <- encodeState policy state
  unless (canonical == encoded) (fail "zookeeper-history-store-noncanonical-state")
  pure state

persist :: Fd -> (HistoryStoreStage -> IO ()) -> BS.ByteString -> IO ()
persist directory observer encoded = do
  observer BeforeCandidateWrite
  -- A failed candidate is never reused, appended, or selected as recovery.
  -- There is only one candidate name; resume removes it after checking state.
  bracket (openRegular directory "state.next" True) Posix.closeFd $ \descriptor -> do
    bracket (Posix.dup descriptor >>= Posix.fdToHandle) hClose $ \stream -> do
      BS.hPut stream encoded
      hFlush stream
    observer AfterCandidateWrite
    syncFd descriptor
    observer AfterCandidateSync
  renameFile (child directory "state.next") (child directory "state")
  observer AfterStateRename
  syncFd directory
  observer AfterDirectorySync

discardCandidate :: Fd -> IO ()
discardCandidate directory = do
  candidate <- try @IOError (openRegular directory "state.next" False)
  case candidate of
    Left problem | isDoesNotExistError problem -> pure ()
    Left problem -> throwIO problem
    Right descriptor -> do
      bracket (pure descriptor) Posix.closeFd $ \fd -> do
        status <- Files.getFdStatus fd
        unless (Files.fileSize status <= fromIntegral historyStoreMaximumBytes)
          (fail "zookeeper-history-store-candidate-extent-limit")
      removeFile (child directory "state.next")
      syncFd directory

checkInventory :: Fd -> IO ()
checkInventory directory = do
  names <- sort <$> listDirectory (child directory "")
  unless (names == ["owner.lock", "state"] || names == ["owner.lock", "state", "state.next"])
    (fail "zookeeper-history-store-file-domain")

-- Linux /proc keeps all child operations anchored to the opened directory,
-- even if its original pathname is subsequently renamed. O_NOFOLLOW rejects
-- symlinks; ownership/mode/link checks reject hard-link aliases and shared files.
child :: Fd -> FilePath -> FilePath
child (Fd descriptor) name = "/proc/self/fd/" <> show descriptor </> name

openDirectory :: FilePath -> IO Fd
openDirectory path = do
  descriptor <- Posix.openFd path Posix.ReadOnly Posix.defaultFileFlags
    {Posix.nofollow = True, Posix.directory = True, Posix.cloexec = True}
  check <- try @SomeException $ do
    status <- Files.getFdStatus descriptor
    owner <- getEffectiveUserID
    unless (Files.isDirectory status && Files.fileOwner status == owner && Files.fileMode status .&. 0o777 == 0o700)
      (fail "zookeeper-history-store-directory-identity")
  either (\problem -> Posix.closeFd descriptor >> throwIO problem) (const (pure descriptor)) check

openRegular :: Fd -> FilePath -> Bool -> IO Fd
openRegular directory name create = do
  descriptor <- Posix.openFd (child directory name) (if create then Posix.ReadWrite else Posix.ReadOnly)
    Posix.defaultFileFlags {Posix.nofollow = True, Posix.cloexec = True, Posix.nonBlock = True,
      Posix.creat = if create then Just 0o600 else Nothing, Posix.exclusive = create}
  check <- try @SomeException $ do
    status <- Files.getFdStatus descriptor
    root <- Files.getFdStatus directory
    owner <- getEffectiveUserID
    unless (Files.isRegularFile status && Files.fileOwner status == owner && Files.fileMode status .&. 0o777 == 0o600
      && Files.linkCount status == 1 && Files.deviceID status == Files.deviceID root
      && (name /= "owner.lock" || Files.fileSize status == 0))
      (fail "zookeeper-history-store-file-identity")
  either (\problem -> Posix.closeFd descriptor >> throwIO problem) (const (pure descriptor)) check

acquireLock :: Fd -> IO ()
acquireLock (Fd descriptor) = throwErrnoIfMinus1_ "zookeeper-history-store-already-owned" (c_flock descriptor 6)

syncFd :: Fd -> IO ()
syncFd (Fd descriptor) = throwErrnoIfMinus1_ "zookeeper-history-store-sync" (c_fsync descriptor)

syncDirectory :: FilePath -> IO ()
syncDirectory path = bracket
  (Posix.openFd path Posix.ReadOnly Posix.defaultFileFlags {Posix.directory = True, Posix.cloexec = True})
  Posix.closeFd syncFd
