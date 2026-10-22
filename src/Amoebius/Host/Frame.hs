-- | Where a host actually runs Linux, and what supplies the container engine there.
--
-- amoebius is Kubernetes-centric and the unit of compute it wants is a __Linux
-- host__. Native Linux supplies one directly; Apple and Windows synthesize one in a
-- guest ("substrate_doctrine.md" §4). The shared vocabulary profile owns the
-- substrate-to-frame table; this module adds the frame's engine policy.
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

import Amoebius.Host.Substrate (PristineLinuxProvider, Substrate, providerForFrame)
import Amoebius.Vocabulary (profileFrame, substrateProfile)
import Amoebius.Vocabulary.Frame (Frame (..), frameName)

-- | What supplies the container endpoint inside a frame.
data ContainerEngine
  = -- | The engine is installed into the frame by the ensure plan.
    DockerEngine
  | -- | The engine arrives with the frame's provider and is not separately ensured.
    ProviderSuppliedEngine
  deriving stock (Eq, Ord, Show, Enum, Bounded)

-- | Total, wildcard-free: every substrate names the frame it reaches Linux through.
frameFor :: Substrate -> Frame
frameFor = profileFrame . substrateProfile

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
frameProvider = providerForFrame

renderFrame :: Frame -> String
renderFrame = frameName

renderContainerEngine :: ContainerEngine -> String
renderContainerEngine engine = case engine of
  DockerEngine -> "docker-engine"
  ProviderSuppliedEngine -> "provider-supplied-engine"
