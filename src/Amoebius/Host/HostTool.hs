module Amoebius.Host.HostTool
  ( HostTool (..)
  , renderHostTool
  ) where

data HostTool
  = PackageManagerRoot
  | Ghcup
  | Cabal
  | Kubectl
  | Kind
  deriving stock (Eq, Ord, Show, Enum, Bounded)

renderHostTool :: HostTool -> String
renderHostTool tool = case tool of
  PackageManagerRoot -> "package-manager-root"
  Ghcup -> "ghcup"
  Cabal -> "cabal"
  Kubectl -> "kubectl"
  Kind -> "kind"
