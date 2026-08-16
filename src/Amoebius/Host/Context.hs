{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Host.Context
  ( BootstrapDistro (..)
  , BinaryContext (..)
  , HostObservation (..)
  , KindEngineDemand (..)
  , HostAdmissionError (..)
  , ValidatedKindCreate
  , mkBinaryContext
  , observePhysicalHost
  , admitKindCreate
  , consumeKindCreate
  , defaultKindEngineDemand
  , renderHostAdmissionError
  ) where

import Amoebius.Host.Ensure
import Amoebius.Host.HostTool
import Amoebius.Host.Substrate
import Control.Concurrent.MVar
import Data.ByteString.Lazy.Char8 qualified as ByteString
import Data.List (find)
import Data.Word (Word64)
import System.Directory
import System.Environment (lookupEnv)
import System.FilePath ((</>))
import Text.Read (readMaybe)

data BootstrapDistro = KindDistro | Rke2Distro
  deriving stock (Eq, Ord, Show)

data BinaryContext = BinaryContext
  { contextSubstrate :: Substrate
  , contextDistro :: BootstrapDistro
  , contextReplicas :: Int
  , contextKind :: AbsExe
  , contextKubectl :: AbsExe
  , contextDocker :: AbsExe
  , contextDf :: AbsExe
  , contextDockerSocket :: FilePath
  , contextStateDirectory :: FilePath
  , contextKubeconfig :: FilePath
  }
  deriving stock (Eq, Show)

data HostObservation = HostObservation
  { observedCpuMillis :: Word64
  , observedMemoryBytes :: Word64
  , observedDiskBytes :: Word64
  , observedFingerprint :: String
  }
  deriving stock (Eq, Show)

data KindEngineDemand = KindEngineDemand
  { demandedCpuMillis :: Word64
  , demandedMemoryBytes :: Word64
  , demandedDiskBytes :: Word64
  }
  deriving stock (Eq, Show)

data HostAdmissionError
  = HostCpuOvercommit Word64 Word64
  | HostMemoryOvercommit Word64 Word64
  | HostDiskOvercommit Word64 Word64
  | HostFingerprintChanged
  | KindCreateTokenAlreadyConsumed
  | HostObservationMalformed String
  deriving stock (Eq, Show)

data ValidatedKindCreate = ValidatedKindCreate String (MVar Bool)

defaultKindEngineDemand :: KindEngineDemand
defaultKindEngineDemand = KindEngineDemand 2000 (4 * 1024 * 1024 * 1024) (20 * 1024 * 1024 * 1024)

mkBinaryContext :: BootstrapDistro -> Int -> IO (Either String BinaryContext)
mkBinaryContext distro replicas
  | replicas /= 1 && distro == KindDistro = pure (Left "kind-replicas-must-equal-one")
  | replicas < 1 = pure (Left "replicas-must-be-positive")
  | otherwise = do
      detected <- detect
      case detected of
        Left problem -> pure (Left problem)
        Right substrate -> do
          stateRoot <- lookupEnv "AMOEBIUS_ROOT"
          case stateRoot of
            Nothing -> pure (Left "amoebius-root-not-declared")
            Just checkout -> do
              tools <- initialHostConfig substrate
              let stateDirectory = checkout </> ".data" </> "bootstrap-coordinator"
                  socket = "/var/run/docker.sock"
              socketPresent <- doesPathExist socket
              docker <- firstAbs ["/usr/bin/docker", "/usr/local/bin/docker"]
              df <- firstAbs ["/usr/bin/df", "/bin/df"]
              case (lookupTool Kind tools, lookupTool Kubectl tools, docker, df, socketPresent) of
                (Just kind, Just kubectl, Just dockerExe, Just dfExe, True) -> do
                  createDirectoryIfMissing True stateDirectory
                  pure (Right BinaryContext
                    { contextSubstrate = substrate
                    , contextDistro = distro
                    , contextReplicas = replicas
                    , contextKind = kind
                    , contextKubectl = kubectl
                    , contextDocker = dockerExe
                    , contextDf = dfExe
                    , contextDockerSocket = socket
                    , contextStateDirectory = stateDirectory
                    , contextKubeconfig = stateDirectory </> "kubeconfig"
                    })
                (Nothing, _, _, _, _) -> pure (Left "kind-not-ensured")
                (_, Nothing, _, _, _) -> pure (Left "kubectl-not-ensured")
                (_, _, Nothing, _, _) -> pure (Left "container-runtime-prerequisite-absent")
                (_, _, _, Nothing, _) -> pure (Left "disk-observer-absent")
                (_, _, _, _, False) -> pure (Left "docker-socket-witness-absent")
 where
  firstAbs [] = pure Nothing
  firstAbs (path : rest) = do
    present <- doesFileExist path
    if present then pure (either (const Nothing) Just (mkAbsExe path)) else firstAbs rest

observePhysicalHost :: BinaryContext -> IO (Either HostAdmissionError HostObservation)
observePhysicalHost context = do
  processors <- length . filter ((== "processor") . takeWhile (/= '\t')) . lines <$> readFile "/proc/cpuinfo"
  memory <- readMemAvailable
  memoryTotal <- readMemValue "MemTotal:"
  diskResult <- runTool (contextDf context) ["--block-size=1", "--output=source,size,avail", contextStateDirectory context]
  let diskLines = filter (not . null) (lines (ByteString.unpack (toolStdout diskResult)))
  pure $ do
    memoryBytes <- memory
    totalMemoryBytes <- memoryTotal
    (device, total, available) <- parseDisk diskLines
    let cpuMillis = fromIntegral processors * 1000
        fingerprint = show (processors, totalMemoryBytes, device, total)
    Right HostObservation
      { observedCpuMillis = cpuMillis
      , observedMemoryBytes = memoryBytes
      , observedDiskBytes = available
      , observedFingerprint = fingerprint
      }

readMemAvailable :: IO (Either HostAdmissionError Word64)
readMemAvailable = readMemValue "MemAvailable:"

readMemValue :: String -> IO (Either HostAdmissionError Word64)
readMemValue label = do
  source <- readFile "/proc/meminfo"
  pure $ case find ((== label) . takeWhile (/= ' ')) (lines source) of
    Nothing -> Left (HostObservationMalformed label)
    Just row -> case words row of
      [_label, kib, "kB"] -> maybe (Left (HostObservationMalformed label)) (Right . (* 1024)) (readMaybe kib)
      _ -> Left (HostObservationMalformed label)

parseDisk :: [String] -> Either HostAdmissionError (String, Word64, Word64)
parseDisk (_header : row : _) = case words row of
  [device, total, available] -> case (readMaybe total, readMaybe available) of
    (Just totalBytes, Just availableBytes) -> Right (device, totalBytes, availableBytes)
    _ -> Left (HostObservationMalformed "df-numeric")
  _ -> Left (HostObservationMalformed "df-fields")
parseDisk _ = Left (HostObservationMalformed "df-output")

admitKindCreate :: KindEngineDemand -> HostObservation -> IO (Either HostAdmissionError ValidatedKindCreate)
admitKindCreate demand observed
  | demandedCpuMillis demand > observedCpuMillis observed = pure (Left (HostCpuOvercommit (demandedCpuMillis demand) (observedCpuMillis observed)))
  | demandedMemoryBytes demand > observedMemoryBytes observed = pure (Left (HostMemoryOvercommit (demandedMemoryBytes demand) (observedMemoryBytes observed)))
  | demandedDiskBytes demand > observedDiskBytes observed = pure (Left (HostDiskOvercommit (demandedDiskBytes demand) (observedDiskBytes observed)))
  | otherwise = Right . ValidatedKindCreate (observedFingerprint observed) <$> newMVar False

consumeKindCreate :: ValidatedKindCreate -> HostObservation -> IO (Either HostAdmissionError ())
consumeKindCreate (ValidatedKindCreate fingerprint consumed) observed = modifyMVar consumed $ \wasConsumed ->
  if wasConsumed
    then pure (True, Left KindCreateTokenAlreadyConsumed)
    else if fingerprint /= observedFingerprint observed
      then pure (False, Left HostFingerprintChanged)
      else pure (True, Right ())

renderHostAdmissionError :: HostAdmissionError -> String
renderHostAdmissionError problem = case problem of
  HostCpuOvercommit {} -> "HostCpuOvercommit"
  HostMemoryOvercommit {} -> "HostMemoryOvercommit"
  HostDiskOvercommit {} -> "HostDiskOvercommit"
  HostFingerprintChanged -> "HostFingerprintChanged"
  KindCreateTokenAlreadyConsumed -> "KindCreateTokenAlreadyConsumed"
  HostObservationMalformed locus -> "HostObservationMalformed:" <> locus
