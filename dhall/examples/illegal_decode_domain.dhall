-- expected-tag: OutOfDomainArm
-- catalog: documents/illegal_state/illegal_state_catalog.md#3.38
-- minimal-pair: dhall/examples/legal_multisubstrate_cluster.dhall (ttlSeconds = 30)
let Topology = ../amoebius/Topology.dhall

let legal = ./legal_multisubstrate_cluster.dhall

in  legal
      with ingress =
        Topology.Ingress.KeycloakEnvoy
          { host = "apps.local", dnsRecord = "apps.local", ttlSeconds = 0 }
