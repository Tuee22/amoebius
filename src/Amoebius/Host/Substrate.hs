module Amoebius.Host.Substrate
  ( OsName (..)
  , RawArch (..)
  , Gpu (..)
  , Substrate (..)
  , PristineLinuxProvider (..)
  , classify
  , classifyMutantDropGpuPromotion
  , detect
  , pristineLinuxProvider
  , renderPristineLinuxProvider
  , renderClassification
  , renderSubstrate
  ) where

import System.Directory (doesPathExist)
import System.Info qualified as Info

newtype OsName = OsName String
  deriving stock (Eq, Ord, Show)

newtype RawArch = RawArch String
  deriving stock (Eq, Ord, Show)

data Gpu = GpuPresent | GpuAbsent
  deriving stock (Eq, Ord, Show, Enum, Bounded)

data Substrate = LinuxCpu | LinuxCuda | Apple | Windows
  deriving stock (Eq, Ord, Show, Enum, Bounded)

data PristineLinuxProvider = Incus | Lima | Wsl2
  deriving stock (Eq, Ord, Show, Enum, Bounded)

data NormalArch = X86_64 | Arm64

classify :: OsName -> RawArch -> Gpu -> Either String Substrate
classify = classifyWithGpuPromotion True

-- | Committed M1: the Linux GPU-promotion rule is deliberately dropped.
classifyMutantDropGpuPromotion :: OsName -> RawArch -> Gpu -> Either String Substrate
classifyMutantDropGpuPromotion = classifyWithGpuPromotion False

classifyWithGpuPromotion :: Bool -> OsName -> RawArch -> Gpu -> Either String Substrate
classifyWithGpuPromotion promote (OsName rawOs) rawArch gpu = do
  arch <- normalizeArch rawArch
  case rawOs of
    "linux"
      | promote && gpu == GpuPresent -> Right LinuxCuda
      | otherwise -> Right LinuxCpu
    "darwin" -> case arch of
      Arm64 -> Right Apple
      X86_64 -> Left "apple-arm64-only"
    "mingw32" -> Right Windows
    "windows" -> Right Windows
    _ -> Left "unknown-os"

normalizeArch :: RawArch -> Either String NormalArch
normalizeArch (RawArch raw) = case raw of
  "x86_64" -> Right X86_64
  "amd64" -> Right X86_64
  "aarch64" -> Right Arm64
  "arm64" -> Right Arm64
  _ -> Left "unknown-arch"

detect :: IO (Either String Substrate)
detect = do
  device <- doesPathExist "/dev/nvidiactl"
  let gpu = if device then GpuPresent else GpuAbsent
  pure (classify (OsName Info.os) (RawArch Info.arch) gpu)

pristineLinuxProvider :: Substrate -> PristineLinuxProvider
pristineLinuxProvider substrate = case substrate of
  LinuxCpu -> Incus
  LinuxCuda -> Incus
  Apple -> Lima
  Windows -> Wsl2

renderPristineLinuxProvider :: PristineLinuxProvider -> String
renderPristineLinuxProvider provider = case provider of
  Incus -> "incus"
  Lima -> "lima"
  Wsl2 -> "wsl2"

renderSubstrate :: Substrate -> String
renderSubstrate substrate = case substrate of
  LinuxCpu -> "linux-cpu"
  LinuxCuda -> "linux-cuda"
  Apple -> "apple"
  Windows -> "windows"

renderClassification :: Either String Substrate -> String
renderClassification result = case result of
  Left reason -> "left:" <> reason
  Right substrate -> "right:" <> renderSubstrate substrate
