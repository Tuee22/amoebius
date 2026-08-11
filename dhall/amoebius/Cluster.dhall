let Topology = ./Topology.dhall

let Capacity = ./Capacity.dhall

let Cluster =
      { name : Text
      , substrate : Topology.Substrate
      , servers : Topology.Rke2Servers
      , agents : Topology.Rke2AgentPool
      , ingress : Topology.Ingress
      , capacity : Capacity.Type
      }

in  { Type = Cluster }
