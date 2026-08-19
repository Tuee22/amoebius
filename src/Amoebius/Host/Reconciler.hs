{-# LANGUAGE CPP #-}

-- | Reconcilers as rows, so their three views cannot disagree.
--
-- A reconciler answers three questions: which substrates it applies to, what it says
-- when it is asked about one it does not, and what it installs on one it does. When
-- those live in three places they drift — the diagnostic is the one that drifts first,
-- because it is prose beside a set rather than a projection of it.
--
-- So a reconciler is __one row__. The applicability column is the only statement of
-- the set; the diagnostic is rendered /from/ that column; and the plan is a total
-- function whose domain the column fixes. A row change is a reviewable diff against
-- the golden under @test/fixture/host_ensure_kernel/@ rather than a behavioural
-- surprise at run time.
module Amoebius.Host.Reconciler
  ( Reconciler (..)
  , reconcilers
  , reconcilerNamed
  , appliesTo
  , diagnostic
  , decide
  , installPlan
  , renderInstallStep
  , renderPlan
  , renderTable
  ) where

import Amoebius.Host.Ensure
import Amoebius.Host.Frame
import Amoebius.Host.HostTool
import Amoebius.Host.Substrate
import Data.List (intercalate, sortOn)

-- | One reconciler, as a row.
data Reconciler = Reconciler
  { reconcilerName :: String
  , -- | The single statement of which substrates this row admits. Everything else
    -- about applicability is derived from it.
    reconcilerApplies :: [Substrate]
  , -- | The steps this reconciler installs on an admitted substrate.
    reconcilerSteps :: Substrate -> [InstallStep]
  }

-- | The authored table. Order is the order the driver runs them in.
reconcilers :: [Reconciler]
reconcilers =
  [ Reconciler
      { reconcilerName = "package-manager-root"
      , reconcilerApplies = everySubstrate
      , reconcilerSteps = \substrate ->
          [InstallStep PackageManagerRoot VerifiedOnly [Literal (rootName substrate)]]
      }
  , Reconciler
      { reconcilerName = "haskell-toolchain"
      , reconcilerApplies = everySubstrate
      , reconcilerSteps = \substrate ->
          [ InstallStep Ghcup (PerformedBy PackageManagerRoot) (rootInstall substrate "ghcup")
          , InstallStep Cabal (PerformedBy Ghcup)
              [Literal "install", Literal "cabal", RequirementVersion Cabal, Literal "--set"]
          ]
      }
  , Reconciler
      { reconcilerName = "container-engine"
      , -- Only the native frame installs an engine. Colima publishes a Docker
        -- endpoint as part of creating the guest and WSL2 receives the engine the
        -- Linux plan installs inside it, so ensuring one on the host would install a
        -- second engine beside the one already answering.
        reconcilerApplies = [s | s <- everySubstrate, engineForSubstrate s == DockerEngine]
      , reconcilerSteps = \substrate -> [InstallStep Docker (PerformedBy PackageManagerRoot) (rootInstall substrate "docker.io")]
      }
  , Reconciler
      { reconcilerName = "cluster-tools"
      , reconcilerApplies = everySubstrate
      , reconcilerSteps = \substrate ->
#ifdef HOST_ENSURE_APPLE_DOCKER_STEP_MUTANT
          -- Seeded: an engine installed on the one substrate whose frame supplies one.
          [InstallStep Docker (PerformedBy PackageManagerRoot) (rootInstall substrate "docker") | substrate == Apple]
            <>
#endif
          [ InstallStep Kubectl (PerformedBy PackageManagerRoot) (rootInstall substrate (kubectlPackage substrate))
          , InstallStep Kind (PerformedBy PackageManagerRoot) (rootInstall substrate "kind")
          ]
      }
  ]
 where
  everySubstrate = [minBound .. maxBound]

-- | The package-manager root's own name, per substrate.
rootName :: Substrate -> String
rootName substrate = case substrate of
  LinuxCpu -> "apt-get"
  LinuxCuda -> "apt-get"
  Apple -> "brew"
  Windows -> "winget"

-- | How each root is told to install a package. The verb differs; the shape does not.
rootInstall :: Substrate -> String -> [Argument]
rootInstall substrate package = case substrate of
  LinuxCpu -> [Literal "install", Literal "-y", Literal package]
  LinuxCuda -> [Literal "install", Literal "-y", Literal package]
  Apple -> [Literal "install", Literal package]
  Windows -> [Literal "install", Literal "--exact", Literal package]

kubectlPackage :: Substrate -> String
kubectlPackage substrate = case substrate of
  LinuxCpu -> "kubectl"
  LinuxCuda -> "kubectl"
  Apple -> "kubernetes-cli"
  Windows -> "Kubernetes.kubectl"

reconcilerNamed :: String -> Maybe Reconciler
reconcilerNamed name = case filter ((== name) . reconcilerName) reconcilers of
  (found : _) -> Just found
  [] -> Nothing

-- | Derived from the applicability column, never authored beside it.
appliesTo :: Reconciler -> Substrate -> Bool
appliesTo reconciler substrate = substrate `elem` reconcilerApplies reconciler

-- | Also derived from the applicability column. An authored phrase drifts from the
-- set it describes the first time that set changes; a rendered one cannot.
diagnostic :: Reconciler -> Substrate -> String
diagnostic reconciler substrate =
  reconcilerName reconciler
    <> " applies to "
#ifdef HOST_ENSURE_AUTHORED_DIAGNOSTIC_MUTANT
    <> "linux-cpu, linux-cuda, apple, windows"
#else
    <> intercalate ", " (map renderSubstrate (sortOn fromEnum (reconcilerApplies reconciler)))
#endif
    <> "; it was driven on "
    <> renderSubstrate substrate

-- | Refuse before any side effect when a reconciler is driven on an excluded
-- substrate. A misapplied reconciler should cost a message, not a half-installed host.
decide :: Reconciler -> Substrate -> Either EnsureError [InstallStep]
decide reconciler substrate
  | appliesTo reconciler substrate = Right (reconcilerSteps reconciler substrate)
  | otherwise = Left (NotApplicable (reconcilerName reconciler) substrate)

-- | Every step every applicable reconciler contributes, in table order.
installPlan :: Substrate -> [InstallStep]
installPlan substrate =
  concat [steps | reconciler <- reconcilers, Right steps <- [decide reconciler substrate]]

renderInstallStep :: Substrate -> Int -> InstallStep -> String
renderInstallStep substrate ordinal step =
  intercalate
    "\t"
    [ renderSubstrate substrate
    , show ordinal
    , renderHostTool (stepProvides step)
    , performer
    , unwords (map renderArgument (stepArguments step))
    ]
 where
  performer = case stepPerformer step of
    VerifiedOnly -> "verified-only"
    PerformedBy tool -> renderHostTool tool

renderPlan :: Substrate -> [String]
renderPlan substrate =
  [renderInstallStep substrate ordinal step | (ordinal, step) <- zip [1 ..] (installPlan substrate)]

-- | The whole table, for the golden. One line per substrate per step, plus one
-- applicability line per reconciler, so a row change is visible as a diff.
renderTable :: [String]
renderTable =
  [ "applies\t" <> reconcilerName reconciler <> "\t"
      <> intercalate "," (map renderSubstrate (sortOn fromEnum (reconcilerApplies reconciler)))
  | reconciler <- reconcilers
  ]
    <> ["step\t" <> line | substrate <- [minBound .. maxBound], line <- renderPlan substrate]
