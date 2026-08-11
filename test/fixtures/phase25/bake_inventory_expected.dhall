-- Phase-25 independent oracle.  This file deliberately imports neither
-- BakeCatalog.dhall nor generated image metadata.
let ProbeKind = < Elf | Launcher >

let Entry =
      { catalogName : Text
      , canonicalService : Text
      , binary : Text
      , arguments : List Text
      , version : Text
      , kind : ProbeKind
      , sourceImage : Text
      , sourceDigest : Text
      }

in    [ { catalogName = "distribution"
        , canonicalService = "Registry (distribution)"
        , binary = "/usr/bin/registry"
        , arguments = [ "--version" ]
        , version = "2.8.3"
        , kind = ProbeKind.Elf
        , sourceImage = "registry:2.8.3"
        , sourceDigest =
            "sha256:a3d8aaa63ed8681a604f1dea0aa03f100d5895b6a58ace528858a7b332415373"
        }
      , { catalogName = "minio"
        , canonicalService = "MinIO"
        , binary = "/usr/bin/minio"
        , arguments = [ "--version" ]
        , version = "RELEASE.2025-07-23T15-54-02Z"
        , kind = ProbeKind.Elf
        , sourceImage = "minio/minio:RELEASE.2025-07-23T15-54-02Z"
        , sourceDigest =
            "sha256:d249d1fb6966de4d8ad26c04754b545205ff15a62e4fd19ebd0f26fa5baacbc0"
        }
      , { catalogName = "vault"
        , canonicalService = "Vault"
        , binary = "/usr/bin/vault"
        , arguments = [ "--version" ]
        , version = "1.20.2"
        , kind = ProbeKind.Elf
        , sourceImage = "hashicorp/vault:1.20.2"
        , sourceDigest =
            "sha256:5cd2003247e0a574a66c66aee1916b1e9e7f99640298f2e61271a8842d2d2a19"
        }
      , { catalogName = "pulsar"
        , canonicalService = "Pulsar"
        , binary = "/pulsar/bin/pulsar"
        , arguments = [ "version" ]
        , version = "4.0.6"
        , kind = ProbeKind.Launcher
        , sourceImage = "apachepulsar/pulsar-all:4.0.6"
        , sourceDigest =
            "sha256:d217884eef29768c50e2b05687971cebf28c56a47c7dc2c4b9b3327229c14629"
        }
      , { catalogName = "redis-server"
        , canonicalService = "Redis/Sentinel"
        , binary = "/usr/bin/redis-server"
        , arguments = [ "--version" ]
        , version = "7.4.5"
        , kind = ProbeKind.Elf
        , sourceImage = "redis:7.4.5-bookworm"
        , sourceDigest =
            "sha256:90e7a336d044f1abc9e9dbc05d65566850896d11453bbd1dd0fb7e5059f0e8fb"
        }
      , { catalogName = "redis-cli"
        , canonicalService = "Redis/Sentinel"
        , binary = "/usr/bin/redis-cli"
        , arguments = [ "--version" ]
        , version = "7.4.5"
        , kind = ProbeKind.Elf
        , sourceImage = "redis:7.4.5-bookworm"
        , sourceDigest =
            "sha256:90e7a336d044f1abc9e9dbc05d65566850896d11453bbd1dd0fb7e5059f0e8fb"
        }
      , { catalogName = "prometheus"
        , canonicalService = "Prometheus/Grafana"
        , binary = "/usr/bin/prometheus"
        , arguments = [ "--version" ]
        , version = "3.5.0"
        , kind = ProbeKind.Elf
        , sourceImage = "prom/prometheus:v3.5.0"
        , sourceDigest =
            "sha256:63805ebb8d2b3920190daf1cb14a60871b16fd38bed42b857a3182bc621f4996"
        }
      , { catalogName = "alertmanager"
        , canonicalService = "Prometheus/Grafana"
        , binary = "/usr/bin/alertmanager"
        , arguments = [ "--version" ]
        , version = "0.28.1"
        , kind = ProbeKind.Elf
        , sourceImage = "prom/alertmanager:v0.28.1"
        , sourceDigest =
            "sha256:27c475db5fb156cab31d5c18a4251ac7ed567746a2483ff264516437a39b15ba"
        }
      , { catalogName = "thanos"
        , canonicalService = "Prometheus/Grafana"
        , binary = "/usr/bin/thanos"
        , arguments = [ "--version" ]
        , version = "0.39.2"
        , kind = ProbeKind.Elf
        , sourceImage = "quay.io/thanos/thanos:v0.39.2"
        , sourceDigest =
            "sha256:1d022ef4b8eff056a0e3b7822f953d931c5704d068413f2d7ce5266aa96c9e80"
        }
      , { catalogName = "grafana"
        , canonicalService = "Prometheus/Grafana"
        , binary = "/usr/share/grafana/bin/grafana"
        , arguments = [ "--version" ]
        , version = "12.1.1"
        , kind = ProbeKind.Elf
        , sourceImage = "grafana/grafana:12.1.1"
        , sourceDigest =
            "sha256:a1701c2180249361737a99a01bc770db39381640e4d631825d38ff4535efa47d"
        }
      , { catalogName = "postgres"
        , canonicalService = "Percona/Patroni Postgres + pgAdmin"
        , binary = "/usr/lib/postgresql/17/bin/postgres"
        , arguments = [ "--version" ]
        , version = "17.6"
        , kind = ProbeKind.Elf
        , sourceImage = "postgres:17.6-bookworm"
        , sourceDigest =
            "sha256:f3bd19c606e442c3d7bdfa8002e03fe260a1023351e0ea4598032022b68dd6e3"
        }
      , { catalogName = "patroni"
        , canonicalService = "Percona/Patroni Postgres + pgAdmin"
        , binary = "/usr/local/bin/patroni"
        , arguments = [ "--version" ]
        , version = "4.0.4"
        , kind = ProbeKind.Launcher
        , sourceImage = "ghcr.io/zalando/spilo-17:4.0-p2"
        , sourceDigest =
            "sha256:23861da069941ff5345e6a97455e60a63fc2f16c97857da8f85560370726cbe7"
        }
      , { catalogName = "percona-postgresql-operator"
        , canonicalService = "Percona/Patroni Postgres + pgAdmin"
        , binary = "/usr/bin/percona-postgresql-operator"
        , arguments = [ "--version" ]
        , version = "2.6.0"
        , kind = ProbeKind.Elf
        , sourceImage = "percona/percona-postgresql-operator:2.6.0"
        , sourceDigest =
            "sha256:6b7bf435ce89de3e2f1ec5fceeb4c27ae989eb24fec25a65e47dd337f3a31a17"
        }
      , { catalogName = "pgadmin"
        , canonicalService = "Percona/Patroni Postgres + pgAdmin"
        , binary = "/usr/bin/pgadmin-python3.12"
        , arguments =
          [ "-c"
          , "import sys; sys.path.insert(0, '/venv/lib/python3.12/site-packages'); sys.path.insert(0, '/pgadmin4'); import config; print(config.APP_VERSION)"
          ]
        , version = "9.6"
        , kind = ProbeKind.Elf
        , sourceImage = "dpage/pgadmin4:9.6"
        , sourceDigest =
            "sha256:2c7d73e13bd6c30b1d53e4c25d0d6d81adbd0799c4f4d6a09efc5d68fca5d16d"
        }
      , { catalogName = "envoy"
        , canonicalService = "Envoy / Gateway API"
        , binary = "/usr/bin/envoy"
        , arguments = [ "--version" ]
        , version = "1.35.1"
        , kind = ProbeKind.Elf
        , sourceImage = "envoyproxy/envoy:v1.35.1"
        , sourceDigest =
            "sha256:522f4f88bdd741fe87b813bdca678a11c13e42e630cc4304a9e18193813c935d"
        }
      , { catalogName = "envoy-gateway"
        , canonicalService = "Envoy / Gateway API"
        , binary = "/usr/bin/envoy-gateway"
        , arguments = [ "version" ]
        , version = "1.4.2"
        , kind = ProbeKind.Elf
        , sourceImage = "envoyproxy/gateway:v1.4.2"
        , sourceDigest =
            "sha256:8b0f00e3be81e4b3d4531bc100a4378bc436e2d2fcbb23856d0d8ec5b56dfba6"
        }
      , { catalogName = "keycloak"
        , canonicalService = "Keycloak"
        , binary = "/opt/keycloak/bin/kc.sh"
        , arguments = [ "--version" ]
        , version = "26.3.2"
        , kind = ProbeKind.Launcher
        , sourceImage = "quay.io/keycloak/keycloak:26.3.2"
        , sourceDigest =
            "sha256:98fab020a3a490aba0978f237e2a06cd0ea42bf149c6cf10f11c0aaf27728ff2"
        }
      , { catalogName = "metallb-controller"
        , canonicalService = "MetalLB-or-cloud LoadBalancer"
        , binary = "/usr/bin/metallb-controller"
        , arguments = [ "-h" ]
        , version = "0.15.2"
        , kind = ProbeKind.Elf
        , sourceImage = "quay.io/metallb/controller:v0.15.2"
        , sourceDigest =
            "sha256:417cdb6d6f9f2c410cceb84047d3a4da3bfb78b5ddfa30f4cf35ea5c667e8c2e"
        }
      , { catalogName = "metallb-speaker"
        , canonicalService = "MetalLB-or-cloud LoadBalancer"
        , binary = "/usr/bin/metallb-speaker"
        , arguments = [ "-h" ]
        , version = "0.15.2"
        , kind = ProbeKind.Elf
        , sourceImage = "quay.io/metallb/speaker:v0.15.2"
        , sourceDigest =
            "sha256:260c9406f957c0830d4e6cd2e9ac8c05e51ac959dd2462c4c2269ac43076665a"
        }
      , { catalogName = "temurin"
        , canonicalService = "JVM service runtime"
        , binary = "/opt/java/openjdk/bin/java"
        , arguments = [ "--version" ]
        , version = "21.0.8"
        , kind = ProbeKind.Elf
        , sourceImage = "eclipse-temurin:21.0.8_9-jre-jammy"
        , sourceDigest =
            "sha256:db1689535962d757a5adabf57387584ed543d38c0b9d1fe870123ea362ad73b0"
        }
      , { catalogName = "nvcc"
        , canonicalService = "jit-build toolchain"
        , binary = "/usr/local/cuda/bin/nvcc"
        , arguments = [ "--version" ]
        , version = "13.0"
        , kind = ProbeKind.Launcher
        , sourceImage = "nvidia/cuda:13.0.0-devel-ubuntu24.04"
        , sourceDigest =
            "sha256:1e8ac7a54c184a1af8ef2167f28fa98281892a835c981ebcddb1fad04bdd452d"
        }
      , { catalogName = "g++"
        , canonicalService = "jit-build toolchain"
        , binary = "/usr/bin/g++"
        , arguments = [ "--version" ]
        , version = "13.3.0"
        , kind = ProbeKind.Elf
        , sourceImage = "nvidia/cuda:13.0.0-devel-ubuntu24.04"
        , sourceDigest =
            "sha256:1e8ac7a54c184a1af8ef2167f28fa98281892a835c981ebcddb1fad04bdd452d"
        }
      , { catalogName = "amoebius-jit-build-resolver"
        , canonicalService = "jit-build resolver"
        , binary = "/usr/bin/amoebius"
        , arguments = [ "jit-build-resolver", "--version" ]
        , version = "0.1.0.0"
        , kind = ProbeKind.Elf
        , sourceImage = "amoebius-source"
        , sourceDigest = "sha256:source-bound-at-build"
        }
      ]
    : List Entry
