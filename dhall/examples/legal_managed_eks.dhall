let Cluster = ../amoebius/Cluster.dhall

let Topology = ../amoebius/Topology.dhall

let Capacity = ../amoebius/Capacity.dhall

let V = ./legal_values.dhall

let classes =
      { head = V.providerNodeClass
      , tail = [] : List Capacity.ProviderNodeClass
      }

let server1 = V.rke2Server with host = "linux-server-1"

let server2 = V.rke2Server with host = "linux-server-2"

in    { name = "managed-production"
      , substrate =
          Topology.Substrate.ManagedEks
            { account = "cloud-account-production"
            , nodeClasses = classes
            , quota = V.providerQuota
            }
      , servers =
          Topology.Rke2Servers.Ha3
            { s0 = V.rke2Server, s1 = server1, s2 = server2 }
      , agents =
          Topology.Rke2AgentPool.Autoscaled
            { floor =
              { head = V.rke2Node, tail = [] : List Capacity.Rke2NodeDemand }
            , candidates = classes
            , quota = V.providerQuota
            , policy.cooldownSeconds = 300
            }
      , ingress =
          Topology.Ingress.KeycloakEnvoy
            { host = "apps.example.com"
            , dnsRecord = "apps.example.com"
            , ttlSeconds = 30
            }
      , capacity =
          Capacity.Type.ProviderTemplate
            { account = "cloud-account-production"
            , nodeClasses = classes
            , quota = V.providerQuota
            }
      }
    : Cluster.Type
