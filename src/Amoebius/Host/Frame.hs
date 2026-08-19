-- | Where a host actually runs Linux, and what supplies the container engine there.
--
-- amoebius is Kubernetes-centric and the unit of compute it wants is a __Linux
-- host__. Native Linux supplies one directly; Apple and Windows synthesize one in a
-- guest ("substrate_doctrine.md" §4). This module is the single table that answers
-- both questions for every catalogue member, so a substrate branch does not have to
-- be re-spelled at each site that needs one.
--
-- Two properties are deliberate.
--
-- * There are __three frames, not five__. The package manager and the host provider
--   are identical on @linux-cpu@ and @linux-cuda@, so a fourth and fifth tag would
--   only re-spell an accelerator distinction the ensure surface never reads. The
--   accelerator tag stays on the surfaces that do read it — capacity and device
--   exposure.
-- * Neither table carries a __default arm__. Under @-Werror=incomplete-patterns@ an
--   added 'Substrate' or 'Frame' constructor is a compile error at every site obliged
--   to answer for it, which is the whole reason the tables are worth having.
module Amoebius.Host.Frame
  ( Frame (..)
  , ContainerEngine (..)
  , frameFor
  , engineFor
  , engineForSubstrate
  , frameProvider
  , renderFrame
  , renderContainerEngine
  ) where

import Amoebius.Host.Substrate (PristineLinuxProvider (..), Substrate (..))

-- | The Linux frame a substrate reaches its workload through.
data Frame
  = -- | Linux running on the metal: the frame is the host.
    NativeLinux
  | -- | An Apple host's Linux guest, supplied by Lima or Colima.
    LimaGuest
  | -- | A Windows host's Linux distribution, supplied by WSL2.
    Wsl2Guest
  deriving stock (Eq, Ord, Show, Enum, Bounded)

-- | What supplies the container endpoint inside a frame.
data ContainerEngine
  = -- | The engine is installed into the frame by the ensure plan.
    DockerEngine
  | -- | The engine arrives with the frame's provider and is not separately ensured.
    ProviderSuppliedEngine
  deriving stock (Eq, Ord, Show, Enum, Bounded)

-- | Total, wildcard-free: every substrate names the frame it reaches Linux through.
frameFor :: Substrate -> Frame
frameFor substrate = case substrate of
  LinuxCpu -> NativeLinux
  LinuxCuda -> NativeLinux
  Apple -> LimaGuest
  Windows -> Wsl2Guest

-- | Total, wildcard-free: every frame names where its container engine comes from.
--
-- Only the native frame installs one. Colima publishes a Docker endpoint as part of
-- creating the guest, and the WSL2 distribution receives the engine the Linux plan
-- installs inside it — in both cases ensuring it again on the host would install a
-- second engine beside the one already answering.
engineFor :: Frame -> ContainerEngine
engineFor frame = case frame of
  NativeLinux -> DockerEngine
  LimaGuest -> ProviderSuppliedEngine
  Wsl2Guest -> ProviderSuppliedEngine

-- | The composition the ensure path actually asks for.
engineForSubstrate :: Substrate -> ContainerEngine
engineForSubstrate = engineFor . frameFor

-- | The provider that materializes a frame, drawn from the substrate registry rather
-- than restated here.
frameProvider :: Frame -> PristineLinuxProvider
frameProvider frame = case frame of
  NativeLinux -> Incus
  LimaGuest -> Lima
  Wsl2Guest -> Wsl2

renderFrame :: Frame -> String
renderFrame frame = case frame of
  NativeLinux -> "native-linux"
  LimaGuest -> "lima-guest"
  Wsl2Guest -> "wsl2-guest"

renderContainerEngine :: ContainerEngine -> String
renderContainerEngine engine = case engine of
  DockerEngine -> "docker-engine"
  ProviderSuppliedEngine -> "provider-supplied-engine"
