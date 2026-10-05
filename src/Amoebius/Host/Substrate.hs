module Amoebius.Host.Substrate
  ( OsName (..)
  , RawArch (..)
  , Gpu (..)
  , Substrate (..)
  , PristineLinuxProvider (..)
  , classify
  , detect
  , pristineLinuxProvider
  , renderPristineLinuxProvider
  , renderClassification
  , renderSubstrate
  ) where

import Amoebius.Vocabulary
  ( Gpu (..)
  , OsName (..)
  , RawArch (..)
  , Substrate (..)
  , detectedSubstrate
  , hostEnvironment
  , hostRefusalTag
  , substrateName
  )
import System.Directory (doesPathExist)
import System.Info qualified as Info

data PristineLinuxProvider = Incus | Lima | Wsl2
  deriving stock (Eq, Ord, Show, Enum, Bounded)

-- | The substrate a host's three reads classify to, with the refusal's tag when they
-- classify to none. The classification itself is the vocabulary's total function.
classify :: OsName -> RawArch -> Gpu -> Either String Substrate
classify os arch gpu = either (Left . hostRefusalTag) (Right . detectedSubstrate) (hostEnvironment os arch gpu)

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
renderSubstrate = substrateName

renderClassification :: Either String Substrate -> String
renderClassification result = case result of
  Left reason -> "left:" <> reason
  Right substrate -> "right:" <> renderSubstrate substrate
