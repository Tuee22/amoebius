{ substrate = "linux-cpu"
, resolvedProgram = "metric=maximize;stage=seeded-sha256;input=sha256:base"
, masterSeed = 81985529216486895
, streamIndex = 37
, inputBytes = "determinism-jitcache-pinned-input-a"
, outputPrefix = "experimentHash/runId"
, universalLinuxCpu =
    { availableOnEveryHardwareSubstrate = True
    , pristineLinuxHost =
        { linux = "Incus", linuxCuda = "Incus", apple = "Lima", windows = "WSL2" }
    }
}
