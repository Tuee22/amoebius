module LinuxEngineBringupOracle
  ( expectedFirstPass
  , expectedSecondPass
  , expectedDaemonProbe
  , expectedFutureSession
  , expectedUnelevatedPrefix
  , expectedDockerBuildClient
  , expectedImageReference
  , architectureCases
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

-- The identity a Docker client call carries.  Authored here so a production
-- spelling that quietly drops the credential change has nothing to agree with.
expectedUnelevatedPrefix :: [String]
expectedUnelevatedPrefix =
  ["/usr/bin/setpriv", "--reuid=ubuntu", "--regid=ubuntu", "--init-groups"]

expectedDockerBuildClient :: [String]
expectedDockerBuildClient =
  [ "/usr/bin/setpriv"
  , "--reuid=ubuntu"
  , "--regid=ubuntu"
  , "--init-groups"
  , "/usr/bin/docker"
  , "build"
  ]

expectedImageReference :: String
expectedImageReference = "amoebius-phase52-cpu-amd64:local"

-- Every three-way architecture read the admission rule can be given, with the
-- verdict written out rather than recomputed, so a production rule that admits
-- one extra disagreeing triple has nothing here to agree with.
architectureCases :: [((String, String, String), Bool)]
architectureCases =
  [ (("Amd64", "Amd64", "Amd64"), True)
  , (("Amd64", "Amd64", "Arm64"), False)
  , (("Amd64", "Arm64", "Amd64"), False)
  , (("Amd64", "Arm64", "Arm64"), False)
  , (("Arm64", "Amd64", "Amd64"), False)
  , (("Arm64", "Amd64", "Arm64"), False)
  , (("Arm64", "Arm64", "Amd64"), False)
  , (("Arm64", "Arm64", "Arm64"), True)
  ]
