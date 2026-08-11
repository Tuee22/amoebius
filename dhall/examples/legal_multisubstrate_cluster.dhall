let Cluster = ../amoebius/Cluster.dhall

let Topology = ../amoebius/Topology.dhall

let Capacity = ../amoebius/Capacity.dhall

let V = ./legal_values.dhall

in    { name = "local-development"
      , substrate =
          Topology.Substrate.LinuxKind
            { host = "linux-host", engine = V.kindEngine }
      , servers = Topology.Rke2Servers.Single V.rke2Server
      , agents =
          Topology.Rke2AgentPool.Fixed
            { nodes =
              { head = V.rke2Node, tail = [] : List Capacity.Rke2NodeDemand }
            }
      , ingress =
          Topology.Ingress.KeycloakEnvoy
            { host = "apps.local", dnsRecord = "apps.local", ttlSeconds = 30 }
      , capacity =
          Capacity.Type.Materialized
            { hosts =
              { head = { id = "linux-host", capacity = V.physicalHost }
              , tail =
                  [] : List
                         { id : Text, capacity : Capacity.PhysicalHostCapacity }
              }
            , nodes =
              { head = { id = "kind-control-plane", capacity = V.nodeCapacity }
              , tail = [] : List { id : Text, capacity : Capacity.NodeCapacity }
              }
            , kindEngine = Some V.kindEngine
            , rke2Nodes = [ V.rke2Server, V.rke2Node ]
            }
      }
    : Cluster.Type
