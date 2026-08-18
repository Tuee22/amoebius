{ substrate = "linux-cpu"
, targetClass = "provider:aws-eks"
, universalLinuxCpu =
    { availableOnEveryHardwareSubstrate = True
    , pristineLinuxHost =
        { linux = "Incus"
        , linuxCuda = "Incus"
        , apple = "Lima"
        , windows = "WSL2"
        }
    }
, cluster =
    { name = "amoebius-p44"
    , region = "ca-central-1"
    , kubernetesVersion = "1.36"
    , controlPlaneCount = 1
    }
, baseNodeClass =
    { name = "cpu-base-ca-central-1-v1"
    , provider = "AwsEc2"
    , machineType = "m7i.large"
    , catalogVersion = "aws-ec2-2026-08-01"
    , accelerator = None Text
    , allocatableCpuMilli = 1800
    , allocatableMemoryBytes = 6442450944
    , podSlots = 29
    , cniSlots = 29
    , attachableEbsVolumes = 25
    , backing = "EphemeralRootEbs"
    , rootSizeGiB = 32
    , filesystemLayout = "Unified"
    , baseCount = 1
    , maximumCount = 1
    }
, execution =
    { concurrency = "BoundedParallel 2"
    , deployUnits = [ "eks-control-plane", "base-managed-node-group" ]
    , each =
        { cpuMilli = 250
        , memoryBytes = 268435456
        , podEphemeralBytes = 134217728
        , pluginCacheBytes = 33554432
        , workspaceBytes = 67108864
        }
    }
, checkpoint =
    { storageBudgetId = "provider-deploy-checkpoint-pulumi-checkpoint"
    , mutationAdmission = "exclusive"
    , maximumObjectBytes = 65536
    , maximumRetainedRevisions = 2
    , failedPartialObjects = 1
    , gcHorizonSeconds = 300
    }
}
