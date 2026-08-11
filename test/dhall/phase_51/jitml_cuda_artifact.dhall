{ substrate = "linux-cuda"
, register = 3
, tenant = "tenant-a"
, app = "jitml-training"
, commandId = "phase0-command-51"
, challenge = "phase0-challenge-51"
, catalogIdentity = "catalog/jitml-cuda-sm52@sha256:5a11311732855c9565790816da79c798becb0b15df6471bc4438e120094359eb"
, trainer =
  { optimizerSteps = 200
  , parameterCount = 10000000
  , batchAddress = "sha256:103902cddc61b7b8638c265aabf695c0945452b244ae5161750124b6a2c36845"
  }
, accelerator =
  { family = "nvidia-cuda"
  , profile = "sm_52"
  , wholeDevices = 1
  , totalVramBytes = 4294967296
  , mandatoryReserveBytes = 268435456
  , netAllocatableBytes = 4026531840
  , requiredVramBytes = 67108864
  }
, requiredCapabilities = [ "JitBuild", "Coordination", "InferenceEngine" ]
, cpuFallback = False
, universalLinuxCpu =
  { availableOnEveryHardwareSubstrate = True
  , pristineLinux =
    { linux = "Incus", linux-cuda = "Incus", apple = "Lima", windows = "WSL2" }
  }
}
