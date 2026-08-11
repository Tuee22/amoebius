let legal = ./legal_multisubstrate_cluster.dhall
let Capacity = ../amoebius/Capacity.dhall
let Topology = ../amoebius/Topology.dhall
let V = ./legal_values.dhall
let reused = V.rke2Node with host = "linux-server"
in  legal with agents =
      Topology.Rke2AgentPool.Fixed
        { nodes = { head = reused, tail = [] : List Capacity.Rke2NodeDemand } }
