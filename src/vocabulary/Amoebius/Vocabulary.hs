{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE OverloadedStrings #-}

-- | The closed vocabularies of the platform, each defined exactly once. Every other
-- module imports these types; none restates them.
module Amoebius.Vocabulary
  ( Substrate (..)
  , SubstrateProfile
  , substrateProfile
  , profileRequiredArchitecture
  , profileFrame
  , Architecture (..)
  , Gpu (..)
  , OsName (..)
  , RawArch (..)
  , Detected
  , detectedSubstrate
  , detectedArchitecture
  , mkDetected
  , linuxCpuDetected
  , HostRefusal (..)
  , hostRefusalTag
  , Lane (..)
  , lanesOf
  , ComputeEngine (..)
  , EngineRuntime (..)
  , engineRuntimeName
  , InferenceFamily (..)
  , inferenceFamilyName
  , CapabilityArm (..)
  , ExtensionId
  , mkExtensionId
  , extensionIdText
  , Unit (..)
  , MetricQuantity
  , mkMetricQuantity
  , metricQuantityValue
  , Duration
  , mkDuration
  , durationSeconds
  , Quantity (..)
  , quantityValue
  , quantityText
  , isLabel
  , substrateName
  , architectureName
  , laneName
  ) where

import Control.DeepSeq (NFData (..))
import Amoebius.Vocabulary.Frame (Frame (..))
import Data.Char (isAsciiLower, isDigit)
import Data.Ratio ((%))
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

instance NFData Detected where
  rnf (Detected substrate architecture) = rnf substrate `seq` rnf architecture

-- | A Linux CPU node at either admitted architecture is always a legal pair.
linuxCpuDetected :: Architecture -> Detected
linuxCpuDetected = Detected LinuxCpu

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
mkDetected substrate architecture = case profileRequiredArchitecture (substrateProfile substrate) of
  Just required | architecture /= required -> Left (NotNaturalArchitecture substrate)
  _ -> Right (Detected substrate architecture)

-- | A place a workload can run on a host.
data Lane = LinuxCpuAt Architecture | LinuxCudaAt Architecture | AppleMetalOnHost
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

-- | One catalog site owns natural-architecture policy, lane offers, and frame.
-- Nothing means the supplied native architecture; no host read occurs here.
data SubstrateProfile = SubstrateProfile (Maybe Architecture) Frame Bool Bool
  deriving stock (Eq, Ord, Show)

instance NFData SubstrateProfile where
  rnf (SubstrateProfile architecture frame cuda metal) = rnf architecture `seq` rnf frame `seq` rnf cuda `seq` rnf metal

-- These are functions, not exported record labels: record updates cannot forge a profile.
profileRequiredArchitecture :: SubstrateProfile -> Maybe Architecture
profileRequiredArchitecture (SubstrateProfile architecture _ _ _) = architecture
profileFrame :: SubstrateProfile -> Frame
profileFrame (SubstrateProfile _ frame _ _) = frame
profileOffersCuda :: SubstrateProfile -> Bool
profileOffersCuda (SubstrateProfile _ _ cuda _) = cuda
profileOffersMetal :: SubstrateProfile -> Bool
profileOffersMetal (SubstrateProfile _ _ _ metal) = metal

substrateProfile :: Substrate -> SubstrateProfile
substrateProfile substrate = case substrate of
  LinuxCpu -> SubstrateProfile Nothing NativeLinux False False
  LinuxCuda -> SubstrateProfile Nothing NativeLinux True False
  Apple -> SubstrateProfile (Just Arm64) LimaGuest False True
  Windows -> SubstrateProfile (Just Amd64) Wsl2Guest False False

-- | Project offers only from a legally constructed observation.
lanesOf :: Detected -> [Lane]
lanesOf (Detected substrate architecture) =
  [LinuxCpuAt architecture]
    <> [LinuxCudaAt architecture | profileOffersCuda profile]
    <> [AppleMetalOnHost | profileOffersMetal profile]
 where
  profile = substrateProfile substrate

data ComputeEngine = KindEngine | Rke2Engine | ManagedEksEngine
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

-- | A named catalog lane of an inference engine. There is intentionally no URL or
-- download arm.
data EngineRuntime = AppleMetal | Cuda | CpuRuntime
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

engineRuntimeName :: EngineRuntime -> Text
engineRuntimeName runtime = case runtime of
  AppleMetal -> "AppleMetal"
  Cuda -> "Cuda"
  CpuRuntime -> "LinuxCpu"

-- Family is independent of lane. Neither catalog dimension contains an
-- authored address, build expression, or unchecked text identity.
data InferenceFamily
  = LlamaCpp | WhisperCpp | Onnx | Vllm | Pytorch | Diffusers | Transformers | Audiveris
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

inferenceFamilyName :: InferenceFamily -> Text
inferenceFamilyName family = case family of
  LlamaCpp -> "llama.cpp"
  WhisperCpp -> "whisper.cpp"
  Onnx -> "ONNX"
  Vllm -> "vLLM"
  Pytorch -> "pytorch"
  Diffusers -> "diffusers"
  Transformers -> "transformers"
  Audiveris -> "Audiveris"

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

-- | Positive, exact dimensionless metric magnitude. Resource magnitudes stay
-- natural-number quantities; monitoring ratios retain their rational precision.
newtype MetricQuantity = MetricQuantity Rational
  deriving stock (Eq, Ord, Show)

mkMetricQuantity :: Integer -> Integer -> Maybe MetricQuantity
mkMetricQuantity numerator denominator
  | numerator > 0 && denominator > 0 = Just (MetricQuantity (numerator % denominator))
  | otherwise = Nothing

metricQuantityValue :: MetricQuantity -> Rational
metricQuantityValue (MetricQuantity value) = value

newtype Duration = Duration Natural
  deriving stock (Eq, Ord, Show)

mkDuration :: Natural -> Maybe Duration
mkDuration seconds = if seconds > 0 then Just (Duration seconds) else Nothing

durationSeconds :: Duration -> Natural
durationSeconds (Duration seconds) = seconds

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
