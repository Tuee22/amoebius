-- | Classification of supplied observations. Reading a host is a separate,
-- later boundary; this function has no IO and makes no ambient discovery.
module Amoebius.Substrate.Classify (Reads (..), classify, hostEnvironment) where

import Amoebius.Vocabulary
  ( Architecture (..), Detected, Gpu (..), HostRefusal (..)
  , OsName (..), RawArch (..), Substrate (..), mkDetected )

data Reads = Reads OsName RawArch Gpu
  deriving stock (Eq, Ord, Show)

classify :: Reads -> Either HostRefusal Detected
classify (Reads operatingSystem architecture gpu) = hostEnvironment operatingSystem architecture gpu

-- | The three reads a host is classified from: operating system, architecture, and
-- whether a GPU device is present. Total: every input is a detection or a refusal.
hostEnvironment :: OsName -> RawArch -> Gpu -> Either HostRefusal Detected
hostEnvironment (OsName rawOs) (RawArch rawArch) gpu = do
  architecture <- case rawArch of
    "x86_64" -> Right Amd64
    "amd64" -> Right Amd64
    "aarch64" -> Right Arm64
    "arm64" -> Right Arm64
    _ -> Left UnknownArch
  substrate <- case rawOs of
    "linux" -> Right (if gpu == GpuPresent then LinuxCuda else LinuxCpu)
    "darwin" -> Right Apple
    "mingw32" -> Right Windows
    "windows" -> Right Windows
    _ -> Left UnknownOs
  mkDetected substrate architecture

