let Topology = ../amoebius/Topology.dhall

in  Topology.ManagedAttachment.HostWorker
      { host = "worker-a"
      , site = "site-b"
      , networking = Topology.Networking.Gateway { endpoint = "gateway-a" }
      }
