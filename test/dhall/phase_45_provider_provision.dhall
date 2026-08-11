{ substrate = "linux-cpu"
, targetClass = "provider:aws-eks"
, universalLinuxCpu =
    { availableOnEveryHardwareSubstrate = True
    , pristineLinuxHost =
        { linux = "Incus", linuxCuda = "Incus", apple = "Lima", windows = "WSL2" }
    }
, child =
    { name = "amoebius-p45"
    , computeEngine = "Managed Eks"
    , hostSubstrate = None Text
    , singletonPods = 1
    , capacitySchedulerPods = 1
    , hostDaemonPods = 0
    , hostNodePortPeers = 0
    }
, bootstrap =
    { schedulerImage = "registry.amoebius.invalid:5000/amoebius/base@sha256:224ce702545f17825dd18eb7108c9a72ea914e1b5ae01218ad955ab624cd94d4"
    , readiness = [ "BootstrapCapacitySchedulerReady", "ManagedCapacityReady" ]
    , addOns = [ "coredns", "aws-node", "kube-proxy", "ebs-csi-controller" ]
    , defaultSchedulerExceptions = 1
    }
, lease =
    { name = "amoebius-control-plane"
    , parentHolder = "parent-bootstrap"
    , childHolder = "child-singleton-pod-uid"
    }
, standardServices =
    [ "registry", "minio", "vault", "zookeeper", "bookkeeper", "pulsar"
    , "redis", "sentinel", "prometheus", "grafana", "postgres", "pgadmin"
    , "envoy", "gateway-api", "keycloak", "cloud-load-balancer"
    ]
}
