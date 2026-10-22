module Amoebius.Host.Substrate
  ( OsName (..)
  , RawArch (..)
  , Gpu (..)
  , Substrate (..)
  , PristineLinuxProvider (..)
  , classify
  , detect
  , pristineLinuxProvider
  , providerForFrame
  , renderPristineLinuxProvider
  , renderClassification
  , renderSubstrate
  ) where

import Amoebius.Substrate.Classify (hostEnvironment)
import Amoebius.Vocabulary
  ( Gpu (..)
  , OsName (..)
  , RawArch (..)
  , Substrate (..)
  , detectedSubstrate
  , hostRefusalTag
  , substrateName
  , substrateProfile
  , profileFrame
  )
import Amoebius.Vocabulary.Frame qualified as Frame
import System.Directory (doesPathExist)
import System.Info qualified as Info

data PristineLinuxProvider = Incus | Lima | Wsl2
  deriving stock (Eq, Ord, Show, Enum, Bounded)

-- | The substrate a host's three reads classify to, with the refusal's tag when they
-- classify to none. The shared classifier consumes only these supplied reads.
classify :: OsName -> RawArch -> Gpu -> Either String Substrate
classify os arch gpu = either (Left . hostRefusalTag) (Right . detectedSubstrate) (hostEnvironment os arch gpu)

detect :: IO (Either String Substrate)
detect = do
  device <- doesPathExist "/dev/nvidiactl"
  let gpu = if device then GpuPresent else GpuAbsent
  pure (classify (OsName Info.os) (RawArch Info.arch) gpu)

pristineLinuxProvider :: Substrate -> PristineLinuxProvider
pristineLinuxProvider = providerForFrame . profileFrame . substrateProfile

providerForFrame :: Frame.Frame -> PristineLinuxProvider
providerForFrame frame = case frame of
  Frame.NativeLinux -> Incus
  Frame.LimaGuest -> Lima
  Frame.Wsl2Guest -> Wsl2

renderPristineLinuxProvider :: PristineLinuxProvider -> String
renderPristineLinuxProvider provider = case provider of
  Incus -> "incus"
  Lima -> "lima"
  Wsl2 -> "wsl2"

renderSubstrate :: Substrate -> String
renderSubstrate = substrateName

renderClassification :: Either String Substrate -> String
renderClassification result = case result of
  Left reason -> "left:" <> reason
  Right substrate -> "right:" <> renderSubstrate substrate
