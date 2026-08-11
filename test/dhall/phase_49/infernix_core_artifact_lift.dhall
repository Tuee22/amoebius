{ substrate = "linux-cpu"
, register = 3
, tenant = "tenant-a"
, catalogIdentity = "catalog/tinyllama-1.1b-cpu@sha256:88dd6c952aba749884eb842494177646d0f77be0ae2d6998f5c69fe3d22551fa"
, seed = 1
, normalizedInput = "explain content addressing"
, modelBytes = 87
, modelDigest = "sha256:88dd6c952aba749884eb842494177646d0f77be0ae2d6998f5c69fe3d22551fa"
, commandId = "phase0-command-49"
, nonce = "phase0-nonce-49"
, cpuBudget =
  { threads = 2
  , concurrency = 1
  , maxInputTokens = 64
  , maxOutputTokens = 16
  , retries = 1
  , bufferBytes = 4096
  , cpuMilli = 500
  , memoryMiB = 256
  , ephemeralMiB = 64
  , cacheMiB = 96
  , accelerator = None Text
  }
, universalLinuxCpu =
  { availableOnEveryHardwareSubstrate = True
  , pristineLinux =
    { linux = "Incus", linux-cuda = "Incus", apple = "Lima", windows = "WSL2" }
  }
}
