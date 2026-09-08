module AppleEngineBringupOracle
  ( expectedProviders
  , expectedLifecycles
  , expectedBrewEnsurePlans
  , expectedColimaStart
  , expectedColimaStop
  , expectedDockerArchitecture
  , expectedLiftedPlan
  , expectedColimaLiftedPlan
  , expectedLiftedStep
  , expectedColimaLiftedStep
  ) where

-- Independent observation vocabulary: this module imports no Amoebius module.
expectedProviders :: [String]
expectedProviders =
  [ "Right ColimaProvider"
  , "Right ColimaProvider"
  , "Right ColimaProvider"
  , "Right LimaProvider"
  ]

expectedLifecycles :: [String]
expectedLifecycles =
  [ "EphemeralFrame"
  , "EphemeralFrame"
  , "PersistentFrame"
  , "PersistentFrame"
  ]

expectedBrewEnsurePlans :: [String]
expectedBrewEnsurePlans =
  [ "Right (InstallThenResolve [\"/opt/homebrew/bin/brew\",\"install\",\"colima\"] \"/opt/homebrew/bin/colima\")"
  , "Right (InstallThenResolve [\"/opt/homebrew/bin/brew\",\"install\",\"lima\"] \"/opt/homebrew/bin/limactl\")"
  , "Right (InstallThenResolve [\"/opt/homebrew/bin/brew\",\"install\",\"docker\"] \"/opt/homebrew/bin/docker\")"
  ]

expectedColimaStart :: [String]
expectedColimaStart =
  [ "/opt/homebrew/bin/colima", "start", "--profile", "amoebius-phase53-oracle"
  , "--cpus", "4", "--memory", "8", "--disk", "40"
  , "--arch", "aarch64", "--runtime", "docker"
  , "--activate=false", "--binfmt=false", "--template=false", "--save-config=false"
  , "--kubernetes=false", "--ssh-agent=false", "--ssh-config=false"
  , "--mount", "none"
  ]

expectedColimaStop :: [String]
expectedColimaStop =
  [ "/opt/homebrew/bin/colima", "delete", "--force", "--data"
  , "--profile", "amoebius-phase53-oracle"
  ]

expectedDockerArchitecture :: [String]
expectedDockerArchitecture =
  [ "/opt/homebrew/bin/docker", "--context", "colima-amoebius-phase53-oracle"
  , "version", "--format", "{{.Server.Arch}}"
  ]

-- Phase 51's two verified-only floor rows issue no command.  These are all five
-- executable rows of its independently authored Linux-CPU plan, in plan order.
expectedLiftedPlan :: [[String]]
expectedLiftedPlan =
  [ ["/opt/homebrew/bin/colima", "--", "package-manager-root", "install", "-y", "ghcup"]
  , ["/opt/homebrew/bin/colima", "--", "ghcup", "install", "cabal", "3.16.1.0", "--set"]
  , ["/opt/homebrew/bin/colima", "--", "package-manager-root", "install", "-y", "docker.io"]
  , ["/opt/homebrew/bin/colima", "--", "package-manager-root", "install", "-y", "kubectl"]
  , ["/opt/homebrew/bin/colima", "--", "package-manager-root", "install", "-y", "kind"]
  ]

expectedColimaLiftedPlan :: [[String]]
expectedColimaLiftedPlan =
  [ ["/opt/homebrew/bin/colima", "ssh", "--profile", "amoebius-phase53-oracle", "--"] <> drop 2 row
  | row <- expectedLiftedPlan
  ]

-- The live challenge uses this non-mutating Phase-51-typed step to prove that the
-- structurally checked envelope really crosses the owned Colima boundary.
expectedLiftedStep :: [[String]]
expectedLiftedStep =
  [["/opt/homebrew/bin/colima", "--", "df", "-kP", "/"]]

expectedColimaLiftedStep :: [String]
expectedColimaLiftedStep =
  [ "/opt/homebrew/bin/colima", "ssh", "--profile", "amoebius-phase53-oracle"
  , "--", "df", "-kP", "/"
  ]
