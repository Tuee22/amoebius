{ substrate = "linux-cpu"
, targetClass = "provider:aws-eks"
, universalLinuxCpu =
    { availableOnEveryHardwareSubstrate = True
    , pristineLinuxHost =
        { linux = "Incus", linuxCuda = "Incus", apple = "Lima", windows = "WSL2" }
    }
, cluster = "amoebius-p47"
, signals = [ "workflow-completion", "load" ]
, selectedClass =
    { name = "cpu-balanced"
    , sku = "m7i.large"
    , allocatableCpuMillis = 1800
    , memoryBytes = 7516192768
    , podEphemeralBytes = 21474836480
    , podSlots = 29
    , cniSlots = 29
    , ebsCsiAttachSlots = 25
    , rootKind = "EphemeralRootEbs"
    , rootProvisionedBytes = 21474836480
    , accelerator = None Text
    , baseCount = 1
    , maximumCount = 2
    , zones = [ "us-east-1a" ]
    }
, fallbackClass =
    { name = "cpu-fallback", sku = "m7i.xlarge", accelerator = None Text }
, providerQuota =
    { instances = 2, vcpu = 4, rootEbsBytes = 42949672960, rootEbsCount = 2
    , durableEbsBytes = 6442450944, durableEbsCount = 1, accelerators = 0
    }
, demand =
    { cpuMillis = 1000, memoryBytes = 1073741824, podEphemeralBytes = 2147483648
    , pods = 2, csiClaims = [ "data/sts0/pv_0", "scratch/job0/pv_0" ]
    , capability = "Cpu"
    }
, sweepOwnership =
    { runTag = "amoebius:test-run=phase47", vpcId = "vpc-phase47"
    , clusterName = "amoebius-p47"
    , clusterTagKeys = [ "eks:cluster-name", "kubernetes.io/cluster/amoebius-p47" ]
    }
}
