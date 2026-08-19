-- | The closed set of external tools amoebius will shell out to.
--
-- An unlisted tool cannot be invoked, which is what makes "every host tool is
-- resolved and called by absolute path" a property of the type system rather than a
-- convention ("substrate_doctrine.md" §3). Note what is /not/ here: @helm@ is absent
-- because amoebius renders and applies its own typed manifests and never shells out
-- to Helm.
module Amoebius.Host.HostTool
  ( HostTool (..)
  , renderHostTool
  , toolCommandName
  ) where

data HostTool
  = -- | The substrate's package manager. Verified, never installed: it cannot be
    -- installed /through/ a resolved tool because there is no prior one.
    PackageManagerRoot
  | Ghcup
  | Cabal
  | -- | The container engine. It is ensured through this same closed enum rather
    -- than resolved outside it by a second helper, which is how one host came to
    -- have two answers for where @docker@ was.
    Docker
  | Kubectl
  | Kind
  deriving stock (Eq, Ord, Show, Enum, Bounded)

-- | The tool's name in this repository's vocabulary, used for records and diagnostics.
renderHostTool :: HostTool -> String
renderHostTool tool = case tool of
  PackageManagerRoot -> "package-manager-root"
  Ghcup -> "ghcup"
  Cabal -> "cabal"
  Docker -> "docker"
  Kubectl -> "kubectl"
  Kind -> "kind"

-- | The bare name the tool is published under.
--
-- This exists for /discovery/ and for a guest's own environment across a context
-- boundary. It is never an invocation target on the host: an 'Amoebius.Host.Ensure.AbsExe'
-- is the only thing that can be run, and it cannot be built from a bare name.
toolCommandName :: HostTool -> String
toolCommandName tool = case tool of
  PackageManagerRoot -> "package-manager-root"
  Ghcup -> "ghcup"
  Cabal -> "cabal"
  Docker -> "docker"
  Kubectl -> "kubectl"
  Kind -> "kind"
