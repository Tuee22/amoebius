let Topology = ../amoebius/Topology.dhall

in  Topology.ManagedAttachment.HybridNode
      { host = "worker-a", site = "site-b" }
