module Main (main) where

import Amoebius.Vault.Audit
import Control.Concurrent (forkFinally, killThread, threadDelay)
import Control.Exception (finally)
import Control.Monad (forM, unless)
import Data.ByteString qualified as Bytes
import Data.Time.Clock (addUTCTime, getCurrentTime)
import System.Directory (createDirectory, doesFileExist, getFileSize, listDirectory, setModificationTime)
import System.Environment (getEnv)
import System.FilePath ((</>))
import System.IO (IOMode (WriteMode), withBinaryFile)
import System.IO.Error (tryIOError)
import System.Posix.Files (createSymbolicLink)

main :: IO ()
main = do
  root <- getEnv "AMOEBIUS_VAULT_AUDIT_TEST_ROOT"
  policy <- either fail pure (provisionAuditPolicy 64 2 10)
  let disk = root </> "rotation"
      input = Bytes.pack [0 .. 255]
  createDirectory disk
  writeAuditChunk policy disk input
  names <- listDirectory disk
  sizes <- traverse (getFileSize . (disk </>)) names
  assert "audit byte ceiling" (length names == 3 && all (<= 64) sizes && sum sizes == 192)
  retained <- Bytes.concat <$> traverse Bytes.readFile [disk </> "audit.log.2", disk </> "audit.log.1", disk </> "audit.log"]
  assert "audit rotation retains the newest bounded stream" (retained == Bytes.drop 64 input)
  writeAuditChunk policy disk (Bytes.pack [1, 2, 3])
  size <- getFileSize (disk </> "audit.log")
  assert "restart observes the existing active byte count" (size == 3)

  -- Supply an aged file, then cross the real clock's expiration boundary.
  now <- getCurrentTime
  setModificationTime (disk </> "audit.log.2") (addUTCTime (-9.5) now)
  expireAuditBackups policy disk now
  assert "unexpired audit backup retained" =<< doesFileExist (disk </> "audit.log.2")
  threadDelay 750000
  getCurrentTime >>= expireAuditBackups policy disk
  assert "audit retention boundary" . not =<< doesFileExist (disk </> "audit.log.2")
  assert "current audit backup retained" =<< doesFileExist (disk </> "audit.log.1")

  let invalid = root </> "oversized"
  createDirectory invalid
  Bytes.writeFile (invalid </> "audit.log") (Bytes.replicate 65 1)
  refused <- tryIOError (writeAuditChunk policy invalid (Bytes.singleton 2))
  assert "oversized preexisting active refuses" (isLeft refused)
  assert "oversized active is not changed" . (== 65) =<< getFileSize (invalid </> "audit.log")

  let links = root </> "links"
      foreignFile = root </> "foreign"
  createDirectory links
  Bytes.writeFile foreignFile (Bytes.pack [11, 12])
  createSymbolicLink foreignFile (links </> "audit.log")
  denied <- tryIOError (writeAuditChunk policy links (Bytes.singleton 1))
  assert "symlink output refuses" (isLeft denied)
  assert "symlink target is unchanged" . (== Bytes.pack [11, 12]) =<< Bytes.readFile foreignFile

  let pipeRoot = root </> "fifo"
      pipeInput = Bytes.replicate 1024 7
  createDirectory pipeRoot
  writer <- forkFinally (runAuditSink policy pipeRoot) (const (pure ()))
  (do
      awaitFile (pipeRoot </> "audit.fifo")
      withBinaryFile (pipeRoot </> "audit.fifo") WriteMode $ \handle -> Bytes.hPut handle pipeInput
      awaitSize (pipeRoot </> "audit.log.2") 64
      threadDelay 100000
      observed <- forM ["audit.log", "audit.log.1", "audit.log.2"] $ \name -> getFileSize (pipeRoot </> name)
      assert "real FIFO audit byte ceiling" (observed == [64, 64, 64])
    ) `finally` killThread writer
  putStrLn "vault-audit-spec: PASS (byte ceiling, bounded rotation, real-clock retention, restart, symlink refusal, FIFO)"

assert :: String -> Bool -> IO ()
assert label condition = unless condition (fail label)

isLeft :: Either problem value -> Bool
isLeft (Left _) = True
isLeft (Right _) = False

awaitFile :: FilePath -> IO ()
awaitFile path = loop (100 :: Int)
 where
  loop 0 = fail "audit FIFO startup timeout"
  loop count = do
    present <- doesFileExist path
    if present then pure () else threadDelay 10000 >> loop (count - 1)

awaitSize :: FilePath -> Integer -> IO ()
awaitSize path expected = loop (100 :: Int)
 where
  loop 0 = fail "audit FIFO delivery timeout"
  loop count = do
    observed <- tryIOError (getFileSize path)
    if observed == Right expected then pure () else threadDelay 10000 >> loop (count - 1)
