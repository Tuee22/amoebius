{ schema = "amoebius.infernix.lift.v1"
, substrate = "linux-cpu"
, register = 3
, catalogIdentity = "catalog/tinyllama-1.1b-cpu@sha256:88dd6c952aba749884eb842494177646d0f77be0ae2d6998f5c69fe3d22551fa"
, transport = "native-cbor-pulsar"
, store = "amoebius-three-tier-content-store"
, credential = "Vault.SecretRef"
, engine = "EngineRuntime.LlamaCppCpu"
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
