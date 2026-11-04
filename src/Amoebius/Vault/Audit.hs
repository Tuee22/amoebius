{-# LANGUAGE CPP #-}

-- | The file audit device writes a FIFO; this bounded writer owns its files.
-- A failed writer terminates Vault so an unavailable audit sink cannot fail open.
module Amoebius.Vault.Audit
  ( AuditPolicy
  , provisionAuditPolicy
  , standardAuditPolicy
  , writeAuditChunk
  , expireAuditBackups
  , runAuditSink
  , runVaultAuditSupervisor
  ) where

import Amoebius.Vault.Init (VaultAuditDemand (..), standardVaultAuditDemand)
import Amoebius.Vault.RuntimePath (VaultRuntimeUse (AuditDirectory, ServerConfiguration), runtimePath, vaultRuntimePath)
import Control.Concurrent (forkFinally, killThread)
import Control.Exception (bracket, finally)
import Control.Monad (forM_, unless, when)
import Data.ByteString qualified as Bytes
import Data.Time.Clock (NominalDiffTime, UTCTime, diffUTCTime, getCurrentTime)
import System.Directory (getModificationTime, removeFile, renameFile)
import System.Exit (ExitCode (..), exitWith)
import System.FilePath ((</>))
import System.IO (BufferMode (NoBuffering), IOMode (AppendMode), hClose, hSetBuffering, hWaitForInput, withBinaryFile)
import System.IO.Error (isDoesNotExistError, tryIOError)
import System.Posix.Files (FileStatus, createNamedPipe, fileSize, getSymbolicLinkStatus, isNamedPipe, isRegularFile, setFileMode)
import System.Posix.IO (OpenMode (ReadWrite), defaultFileFlags, fdToHandle, openFd)
import System.Process.Typed (proc, stopProcess, waitExitCode, withProcessTerm)

data AuditPolicy = AuditPolicy Integer Int NominalDiffTime
  deriving stock (Eq, Show)

provisionAuditPolicy :: Integer -> Int -> NominalDiffTime -> Either String AuditPolicy
provisionAuditPolicy maximumBytes backups retention
  | maximumBytes <= 0 || backups < 0 || retention <= 0 = Left "audit-policy-must-be-finite-and-positive"
  | otherwise = Right (AuditPolicy maximumBytes backups retention)

standardAuditPolicy :: AuditPolicy
standardAuditPolicy = AuditPolicy (auditActiveFileBytes standardVaultAuditDemand) (fromInteger (auditBackupCount standardVaultAuditDemand)) 86400

status :: FilePath -> IO (Maybe FileStatus)
status path = do
  result <- tryIOError (getSymbolicLinkStatus path)
  case result of
    Right value -> pure (Just value)
    Left problem | isDoesNotExistError problem -> pure Nothing
    Left problem -> ioError problem

regularSize :: FilePath -> IO Integer
regularSize path = do
  observed <- status path
  case observed of
    Nothing -> pure 0
    Just value
      | isRegularFile value -> pure (toInteger (fileSize value))
      | otherwise -> fail "audit-output-is-not-a-regular-file"

removeOwned :: FilePath -> IO ()
removeOwned path = do
  observed <- status path
  case observed of
    Nothing -> pure ()
    Just value | isRegularFile value -> removeFile path
    Just _ -> fail "audit-backup-is-not-a-regular-file"

backup :: FilePath -> Int -> FilePath
backup root index = root </> ("audit.log." <> show index)

expireAuditBackups :: AuditPolicy -> FilePath -> UTCTime -> IO ()
expireAuditBackups (AuditPolicy maximumBytes backups retention) root now =
  forM_ [1 .. backups] $ \index -> do
    let path = backup root index
    observed <- status path
    case observed of
      Nothing -> pure ()
      Just value -> do
        unless (isRegularFile value && toInteger (fileSize value) <= maximumBytes) (fail "audit-backup-bound-invalid")
        modified <- getModificationTime path
        when (diffUTCTime now modified >= retention) (removeFile path)

rotate :: AuditPolicy -> FilePath -> IO ()
rotate (AuditPolicy _ backups _) root = do
  let active = root </> "audit.log"
  if backups == 0
    then removeOwned active
    else do
      removeOwned (backup root backups)
      forM_ (reverse [1 .. backups - 1]) $ \index -> do
        let source = backup root index
        observed <- status source
        case observed of
          Nothing -> pure ()
          Just value | isRegularFile value -> renameFile source (backup root (index + 1))
          Just _ -> fail "audit-backup-is-not-a-regular-file"
      observed <- status active
      case observed of
        Nothing -> pure ()
        Just value | isRegularFile value -> renameFile active (backup root 1)
        Just _ -> fail "audit-output-is-not-a-regular-file"

writeAuditChunk :: AuditPolicy -> FilePath -> Bytes.ByteString -> IO ()
writeAuditChunk policy@(AuditPolicy maximumBytes _ _) root input = do
  getCurrentTime >>= expireAuditBackups policy root
  writeRemaining input
 where
  active = root </> "audit.log"
  writeRemaining remaining = unless (Bytes.null remaining) $ do
    used <- regularSize active
    when (used > maximumBytes) (fail "audit-active-bound-invalid")
    if used == maximumBytes
      then rotate policy root >> writeRemaining remaining
      else do
        let count =
#ifdef VAULT_PKI_AUDIT_CEILING_MUTANT
              Bytes.length remaining
#else
              fromInteger (min (maximumBytes - used) (toInteger (Bytes.length remaining)))
#endif
            (piece, rest) = Bytes.splitAt count remaining
        withBinaryFile active AppendMode $ \handle -> do
          setFileMode active 0o600
          hSetBuffering handle NoBuffering
          Bytes.hPut handle piece
        writeRemaining rest

runAuditSink :: AuditPolicy -> FilePath -> IO ()
runAuditSink policy root = do
  let pipe = root </> "audit.fifo"
  observed <- status pipe
  case observed of
    Nothing -> createNamedPipe pipe 0o600
    Just value -> unless (isNamedPipe value) (fail "audit-input-is-not-a-fifo")
  -- Holding both ends permits idle retention sweeps without EOF/reopen races.
  bracket (openFd pipe ReadWrite defaultFileFlags >>= fdToHandle) hClose $ \handle -> do
    hSetBuffering handle NoBuffering
    let loop = do
          getCurrentTime >>= expireAuditBackups policy root
          ready <- hWaitForInput handle 1000
          when ready (Bytes.hGetSome handle 16384 >>= writeAuditChunk policy root)
          loop
    loop

runVaultAuditSupervisor :: FilePath -> FilePath -> IO ()
runVaultAuditSupervisor configuration root = do
  configurationPath <- either fail pure (vaultRuntimePath ServerConfiguration configuration)
  auditPath <- either fail pure (vaultRuntimePath AuditDirectory root)
  withProcessTerm (proc "/usr/bin/vault" ["server", "-config=" <> runtimePath configurationPath]) $ \vault -> do
    writer <- forkFinally (runAuditSink standardAuditPolicy (runtimePath auditPath)) (const (stopProcess vault))
    result <- waitExitCode vault `finally` killThread writer
    case result of
      ExitSuccess -> exitWith ExitSuccess
      ExitFailure code -> exitWith (ExitFailure code)
