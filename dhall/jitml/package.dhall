{ extension = "jitml"
, substrate = "linux-cuda"
, capabilities = [ "JitBuild", "Coordination", "InferenceEngine" ]
, training =
  { optimizerSteps = 200
  , parameterCount = 10000000
  , catalogIdentity = "catalog/jitml-cuda-sm52@sha256:5a11311732855c9565790816da79c798becb0b15df6471bc4438e120094359eb"
  }
, acceleratorOwner =
  { resource = "nvidia.com/gpu", request = 1, limit = 1, profile = "sm_52" }
, cpuFallback = False
, publicInfrastructureFields = [] : List Text
, universalLinuxCpu =
  { availableOnEveryHardwareSubstrate = True
  , pristineLinux =
    { linux = "Incus", linux-cuda = "Incus", apple = "Lima", windows = "WSL2" }
  }
}
