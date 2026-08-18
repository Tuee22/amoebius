{ substrate = "linux-cpu"
, targetClass = "provider:aws-eks"
, universalLinuxCpu =
    { availableOnEveryHardwareSubstrate = True
    , pristineLinuxHost =
        { linux = "Incus", linuxCuda = "Incus", apple = "Lima", windows = "WSL2" }
    }
, volume =
    { account = "account-observation-fingerprint"
    , cluster = "amoebius-p46"
    , claim = "data/sts0/pv_0"
    , volumeType = "gp3"
    , availabilityZone = "us-east-1a"
    , requiredUsableBytes = 5368709121
    , allocationMinimumBytes = 1073741824
    , allocationQuantumBytes = 1073741824
    , sizeGiB = 6
    , provisionedBytes = 6442450944
    , stateClass = "durable-per-pv"
    , protect = True
    , retain = True
    }
, staticCsi =
    { driver = "ebs.csi.aws.com"
    , storageClass = "amoebius-retained"
    , provisioner = "kubernetes.io/no-provisioner"
    , externalProvisionerContainers = 0
    , attachSlots = 2
    }
, migration =
    { oldProvisionedBytes = 6442450944
    , newProvisionedBytes = 7516192768
    , workspaceBytes = 1073741824
    , copyCpuMillis = 500
    , copyMemoryBytes = 536870912
    , copyPodEphemeralBytes = 1073741824
    , providerVolumeCount = 2
    , csiAttachments = 2
    }
}
