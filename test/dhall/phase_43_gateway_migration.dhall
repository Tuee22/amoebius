let PristineLinuxHost =
      { linux : Text, `linux-cuda` : Text, apple : Text, windows : Text }

in  { lagBoundSeconds = 5
    , rtoSeconds = 60
    , dnsTtlSeconds = 2
    , minimumAckedUnreplicatedAtCut = 8
    , plannedWriteCount = 24
    , failoverWriteCount = 24
    , substrate = "linux-cpu"
    , linuxCpuAvailableOnEveryHardwareSubstrate = True
    , pristineLinuxHost =
        { linux = "Incus", `linux-cuda` = "Incus", apple = "Lima", windows = "WSL2" }
        : PristineLinuxHost
    }
