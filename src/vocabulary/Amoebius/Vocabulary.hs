{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE OverloadedStrings #-}

-- | The closed vocabularies of the platform, each defined exactly once. Every other
-- module imports these types; none restates them.
module Amoebius.Vocabulary
  ( Substrate (..)
  , Architecture (..)
  , Gpu (..)
  , OsName (..)
  , RawArch (..)
  , Detected
  , detectedSubstrate
  , detectedArchitecture
  , mkDetected
  , hostEnvironment
  , HostRefusal (..)
  , hostRefusalTag
  , Lane (..)
  , lanesOf
  , ComputeEngine (..)
  , EngineRuntime (..)
  , CapabilityArm (..)
  , ExtensionId
  , mkExtensionId
  , extensionIdText
  , Unit (..)
  , Quantity (..)
  , quantityValue
  , quantityText
  , isLabel
  , substrateName
  , architectureName
  , laneName
  ) where

import Control.DeepSeq (NFData)
import Data.Char (isAsciiLower, isDigit)
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

-- | A host platform the control plane can run on. Every substrate reaches a Linux
-- frame; the catalog is closed.
data Substrate = LinuxCpu | LinuxCuda | Apple | Windows
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data Architecture = Amd64 | Arm64
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data Gpu = GpuPresent | GpuAbsent
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Show)

newtype OsName = OsName String
  deriving stock (Eq, Ord, Show)

newtype RawArch = RawArch String
  deriving stock (Eq, Ord, Show)

-- | A substrate observed together with its architecture. The constructor is private:
-- a pair that no real host reports cannot be written down.
data Detected = Detected Substrate Architecture
  deriving stock (Eq, Ord, Show)

detectedSubstrate :: Detected -> Substrate
detectedSubstrate (Detected substrate _) = substrate

detectedArchitecture :: Detected -> Architecture
detectedArchitecture (Detected _ architecture) = architecture

data HostRefusal
  = UnknownOs
  | UnknownArch
  | NotNaturalArchitecture Substrate
  deriving stock (Eq, Ord, Show)

hostRefusalTag :: HostRefusal -> String
hostRefusalTag refusal = case refusal of
  UnknownOs -> "unknown-os"
  UnknownArch -> "unknown-arch"
  NotNaturalArchitecture Apple -> "apple-arm64-only"
  NotNaturalArchitecture substrate -> substrateName substrate <> "-natural-architecture-only"

-- | Apple hosts are arm64 only and Windows hosts are amd64 only.
mkDetected :: Substrate -> Architecture -> Either HostRefusal Detected
mkDetected substrate architecture = case (substrate, architecture) of
  (Apple, Amd64) -> Left (NotNaturalArchitecture Apple)
  (Windows, Arm64) -> Left (NotNaturalArchitecture Windows)
  _ -> Right (Detected substrate architecture)

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

-- | A place a workload can run on a host.
data Lane = LinuxCpuAt Architecture | LinuxCudaAt Architecture | AppleMetalOnHost
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

-- | The lanes a detected host offers. Every host offers a Linux CPU lane at its own
-- architecture; a CUDA lane exists only where a CUDA device was detected, and the
-- Apple Metal lane only on the Apple substrate.
lanesOf :: Detected -> [Lane]
lanesOf (Detected substrate architecture) = case substrate of
  LinuxCpu -> [LinuxCpuAt architecture]
  LinuxCuda -> [LinuxCpuAt architecture, LinuxCudaAt architecture]
  Apple -> [LinuxCpuAt Arm64, AppleMetalOnHost]
  Windows -> [LinuxCpuAt Amd64]

data ComputeEngine = KindEngine | Rke2Engine | ManagedEksEngine
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

-- | A named catalog lane of an inference engine. There is intentionally no URL or
-- download arm.
data EngineRuntime
  = AppleMetal Text
  | Cuda Text
  | CpuRuntime Text
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

-- | The capabilities an application can need.
data CapabilityArm
  = ObjectStore
  | SecretStore
  | MessageBus
  | Sql
  | Identity
  | Observability
  | Registry
  | Edge
  | InferenceEngine
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

-- | The identity of an extension: a DNS-1123 label.
newtype ExtensionId = ExtensionId Text
  deriving stock (Eq, Ord, Show)

mkExtensionId :: Text -> Maybe ExtensionId
mkExtensionId name = if isLabel name then Just (ExtensionId name) else Nothing

extensionIdText :: ExtensionId -> Text
extensionIdText (ExtensionId name) = name

-- | The unit a capacity quantity is measured in.
data Unit = CpuUnit | MemoryUnit | EphemeralUnit | SlotUnit | DurableUnit

-- | A capacity quantity tagged with its unit, so quantities of different units do
-- not mix.
newtype Quantity (unit :: Unit) = Quantity Natural
  deriving stock (Eq, Generic, Ord, Show)
  deriving newtype (Num, NFData)

-- | The magnitude with its unit erased, for the one place a bare number is the
-- point: a rendering, a refusal's magnitudes, or the wire.
quantityValue :: Quantity unit -> Natural
quantityValue (Quantity magnitude) = magnitude

-- | The magnitude as decimal text, for the object fields and dumps that carry it.
quantityText :: Quantity unit -> Text
quantityText (Quantity magnitude) = Text.pack (show magnitude)

-- | A DNS-1123 label: one to sixty-three lowercase alphanumerics or hyphens, starting
-- and ending alphanumeric.
isLabel :: Text -> Bool
isLabel name =
  not (Text.null name)
    && Text.length name <= 63
    && Text.all (\character -> isAsciiLower character || isDigit character || character == '-') name
    && Text.all alphanumeric (Text.take 1 name)
    && Text.all alphanumeric (Text.takeEnd 1 name)
 where
  alphanumeric character = isAsciiLower character || isDigit character

substrateName :: Substrate -> String
substrateName substrate = case substrate of
  LinuxCpu -> "linux-cpu"
  LinuxCuda -> "linux-cuda"
  Apple -> "apple"
  Windows -> "windows"

architectureName :: Architecture -> String
architectureName architecture = case architecture of
  Amd64 -> "amd64"
  Arm64 -> "arm64"

laneName :: Lane -> String
laneName lane = case lane of
  LinuxCpuAt architecture -> "linux-cpu-" <> architectureName architecture
  LinuxCudaAt architecture -> "linux-cuda-" <> architectureName architecture
  AppleMetalOnHost -> "apple-metal"
