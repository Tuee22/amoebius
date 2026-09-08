module LinuxEngineBringupOracle
  ( expectedFirstPass
  , expectedSecondPass
  , expectedDaemonProbe
  , expectedFutureSession
  ) where

-- This oracle deliberately imports no Amoebius module.  Constructor renderings
-- are compared at the public observation boundary.
expectedFirstPass :: [String]
expectedFirstPass =
  [ "Probe EnginePackage"
  , "Probe DockerGroup"
  , "Probe DaemonSocket"
  , "Probe NativeImage"
  , "Mutate InstallEngine"
  , "Mutate PersistDockerGroupMembership"
  , "Mutate StartDockerDaemon"
  , "Mutate RefreshCurrentCredentials"
  , "Mutate BuildNativeImage"
  ]

expectedSecondPass :: [String]
expectedSecondPass =
  [ "Probe EnginePackage"
  , "Probe DockerGroup"
  , "Probe DaemonSocket"
  , "Probe NativeImage"
  ]

expectedDaemonProbe :: [String]
expectedDaemonProbe = ["/usr/bin/docker", "info", "--format", "{{.ServerVersion}}"]

expectedFutureSession :: [String]
expectedFutureSession =
  [ "/usr/bin/su", "-", "amoebius", "-c"
  , "/usr/bin/docker info --format {{.ServerVersion}}"
  ]
