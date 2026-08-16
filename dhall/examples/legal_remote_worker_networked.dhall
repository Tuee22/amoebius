let Topology = ../amoebius/Topology.dhall

in  { host = "worker-a"
    , site = "site-b"
    , networking = Topology.Networking.Vpn { fabric = "fabric-a" }
    } : Topology.RemoteHostWorker
