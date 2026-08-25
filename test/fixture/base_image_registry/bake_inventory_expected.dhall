-- Phase-26 independent oracle.  This file deliberately imports neither
-- BakeCatalog.dhall nor generated image metadata.
--
-- `acquisition` and `integrity` replace the pre-amendment `sourceImage` and
-- `sourceDigest`.  Those two fields could only describe the scavenge rung, and
-- once every binary sits on a rung above it there is no source image to name.
-- What each row names instead is the identity the rung acquires from -- an exact
-- archive package, a publisher's release, or amoebius's own source -- and where
-- the integrity value comes from.  It is never a digest: repository-layout
-- doctrine section 4 makes an integrity value resolver output, resolved during
-- the build against the archive or the publisher's own manifest, so an authored
-- file that carried one would be authoring a resolution.
let ProbeKind = < Elf | Launcher >

let Entry =
      { catalogName : Text
      , canonicalService : Text
      , binary : Text
      , arguments : List Text
      , version : Text
      , kind : ProbeKind
      , acquisition : Text
      , integrity : Text
      }

let fromArchive = "sha256:resolved-from-the-archive-at-build"

let fromPublisher = "sha256:resolved-from-the-publisher-manifest"

let fromSource = "sha256:source-bound-at-build"

let fromGoChecksums = "sha256:resolved-from-the-module-checksum-database-at-build"

let fromPackageIndex = "sha256:resolved-from-the-package-index-at-build"

in    [ { catalogName = "distribution"
        , canonicalService = "Registry (distribution)"
        , binary = "/usr/bin/docker-registry"
        , arguments = [ "--version" ]
        , version = "2.8.2"
        , kind = ProbeKind.Elf
        , acquisition = "apt:docker-registry=2.8.2+ds1-1ubuntu0.24.04.3"
        , integrity = fromArchive
        }
      , { catalogName = "minio"
        , canonicalService = "MinIO"
        , binary = "/usr/bin/minio"
        , arguments = [ "--version" ]
        , version = "RELEASE.2025-07-23T15-54-02Z"
        , kind = ProbeKind.Elf
        , acquisition = "dl.min.io@RELEASE.2025-07-23T15-54-02Z"
        , integrity = fromPublisher
        }
      , { catalogName = "vault"
        , canonicalService = "Vault"
        , binary = "/usr/bin/vault"
        , arguments = [ "--version" ]
        , version = "1.20.2"
        , kind = ProbeKind.Elf
        , acquisition = "releases.hashicorp.com@1.20.2"
        , integrity = fromPublisher
        }
      , { catalogName = "pulsar"
        , canonicalService = "Pulsar"
        , binary = "/pulsar/bin/pulsar"
        , arguments = [ "version" ]
        , version = "4.0.6"
        , kind = ProbeKind.Launcher
        , acquisition = "archive.apache.org@4.0.6"
        , integrity = fromPublisher
        }
      , -- Ubuntu ships `/usr/bin/redis-server` as a symlink onto the
        -- `redis-check-rdb` multi-call ELF, so the ELF check has to resolve it.
        { catalogName = "redis-server"
        , canonicalService = "Redis/Sentinel"
        , binary = "/usr/bin/redis-server"
        , arguments = [ "--version" ]
        , version = "7.0.15"
        , kind = ProbeKind.Elf
        , acquisition = "apt:redis-server=5:7.0.15-1ubuntu0.24.04.4"
        , integrity = fromArchive
        }
      , { catalogName = "redis-cli"
        , canonicalService = "Redis/Sentinel"
        , binary = "/usr/bin/redis-cli"
        , arguments = [ "--version" ]
        , version = "7.0.15"
        , kind = ProbeKind.Elf
        , acquisition = "apt:redis-tools=5:7.0.15-1ubuntu0.24.04.4"
        , integrity = fromArchive
        }
      , { catalogName = "prometheus"
        , canonicalService = "Prometheus/Grafana"
        , binary = "/usr/bin/prometheus"
        , arguments = [ "--version" ]
        , version = "3.5.0"
        , kind = ProbeKind.Elf
        , acquisition = "github.com/prometheus/prometheus@3.5.0"
        , integrity = fromPublisher
        }
      , { catalogName = "alertmanager"
        , canonicalService = "Prometheus/Grafana"
        , binary = "/usr/bin/alertmanager"
        , arguments = [ "--version" ]
        , version = "0.28.1"
        , kind = ProbeKind.Elf
        , acquisition = "github.com/prometheus/alertmanager@0.28.1"
        , integrity = fromPublisher
        }
      , { catalogName = "thanos"
        , canonicalService = "Prometheus/Grafana"
        , binary = "/usr/bin/thanos"
        , arguments = [ "--version" ]
        , version = "0.39.2"
        , kind = ProbeKind.Elf
        , acquisition = "github.com/thanos-io/thanos@0.39.2"
        , integrity = fromPublisher
        }
      , { catalogName = "grafana"
        , canonicalService = "Prometheus/Grafana"
        , binary = "/usr/share/grafana/bin/grafana"
        , arguments = [ "--version" ]
        , version = "12.1.1"
        , kind = ProbeKind.Elf
        , acquisition = "dl.grafana.com@12.1.1"
        , integrity = fromPublisher
        }
      , -- Rung 1 on noble means PostgreSQL 16, not the 17 the scavenge rung
        -- reached for, and it replaces the twenty-one-library closure that was
        -- hand-copied out of `postgres:17.6-bookworm`.
        { catalogName = "postgres"
        , canonicalService = "Percona/Patroni Postgres + pgAdmin"
        , binary = "/usr/lib/postgresql/16/bin/postgres"
        , arguments = [ "--version" ]
        , version = "16.14"
        , kind = ProbeKind.Elf
        , acquisition = "apt:postgresql-16=16.14-0ubuntu0.24.04.1"
        , integrity = fromArchive
        }
      , { catalogName = "patroni"
        , canonicalService = "Percona/Patroni Postgres + pgAdmin"
        , binary = "/usr/bin/patroni"
        , arguments = [ "--version" ]
        , version = "3.2.2"
        , kind = ProbeKind.Launcher
        , acquisition = "apt:patroni=3.2.2-2"
        , integrity = fromArchive
        }
      , { catalogName = "percona-postgresql-operator"
        , canonicalService = "Percona/Patroni Postgres + pgAdmin"
        , binary = "/usr/bin/percona-postgresql-operator"
        , arguments = [ "--version" ]
        , version = "2.6.0"
        , kind = ProbeKind.Elf
        , acquisition = "https://github.com/percona/percona-postgresql-operator@v2.6.0"
        , integrity = fromGoChecksums
        }
      , -- The application tree is the product; the interpreter that runs its
        -- version probe is the archive's `python3`, which patroni's rung-1
        -- dependency closure already puts in the image.
        { catalogName = "pgadmin"
        , canonicalService = "Percona/Patroni Postgres + pgAdmin"
        , binary = "/usr/bin/python3"
        , arguments =
          [ "-c"
          , "import sys; sys.path.insert(0, '/pgadmin4'); import config; print(config.APP_VERSION)"
          ]
        , version = "9.6"
        , kind = ProbeKind.Launcher
        , acquisition = "pypi:pgadmin4==9.6"
        , integrity = fromPackageIndex
        }
      , { catalogName = "envoy"
        , canonicalService = "Envoy / Gateway API"
        , binary = "/usr/bin/envoy"
        , arguments = [ "--version" ]
        , version = "1.35.1"
        , kind = ProbeKind.Elf
        , acquisition = "github.com/envoyproxy/envoy@1.35.1"
        , integrity = fromPublisher
        }
      , { catalogName = "envoy-gateway"
        , canonicalService = "Envoy / Gateway API"
        , binary = "/usr/bin/envoy-gateway"
        , arguments = [ "version" ]
        , version = "1.4.2"
        , kind = ProbeKind.Elf
        , acquisition = "https://github.com/envoyproxy/gateway@v1.4.2"
        , integrity = fromGoChecksums
        }
      , { catalogName = "keycloak"
        , canonicalService = "Keycloak"
        , binary = "/opt/keycloak/bin/kc.sh"
        , arguments = [ "--version" ]
        , version = "26.3.2"
        , kind = ProbeKind.Launcher
        , acquisition = "github.com/keycloak/keycloak@26.3.2"
        , integrity = fromPublisher
        }
      , { catalogName = "metallb-controller"
        , canonicalService = "MetalLB-or-cloud LoadBalancer"
        , binary = "/usr/bin/metallb-controller"
        , arguments = [ "-h" ]
        , version = "0.15.2"
        , kind = ProbeKind.Elf
        , acquisition = "https://github.com/metallb/metallb@v0.15.2"
        , integrity = fromGoChecksums
        }
      , { catalogName = "metallb-speaker"
        , canonicalService = "MetalLB-or-cloud LoadBalancer"
        , binary = "/usr/bin/metallb-speaker"
        , arguments = [ "-h" ]
        , version = "0.15.2"
        , kind = ProbeKind.Elf
        , acquisition = "https://github.com/metallb/metallb@v0.15.2"
        , integrity = fromGoChecksums
        }
      , -- The doctrine's requirement is a multi-arch JVM, not a vendor.  The
        -- archive satisfies it identically on both arches, so the slot keeps its
        -- name and the acquisition moves up a rung.
        { catalogName = "temurin"
        , canonicalService = "JVM service runtime"
        , binary = "/usr/bin/java"
        , arguments = [ "--version" ]
        , version = "21.0.11"
        , kind = ProbeKind.Elf
        , acquisition = "apt:openjdk-21-jre-headless=21.0.11+10-1~24.04.2"
        , integrity = fromArchive
        }
      , -- No `nvcc` row, and that is the answer rather than an omission: the
        -- accelerator toolchain is what made the pre-amendment base a CUDA devel
        -- image, and a linux-cpu gate cannot bake it under the one-substrate
        -- discipline.  It belongs to the linux-cuda lane at Phase 52.
        { catalogName = "g++"
        , canonicalService = "jit-build toolchain"
        , binary = "/usr/bin/g++"
        , arguments = [ "--version" ]
        , version = "13.3.0"
        , kind = ProbeKind.Elf
        , acquisition = "apt:g++=4:13.2.0-7ubuntu1"
        , integrity = fromArchive
        }
      , { catalogName = "amoebius-jit-build-resolver"
        , canonicalService = "jit-build resolver"
        , binary = "/usr/bin/amoebius"
        , arguments = [ "jit-build-resolver", "--version" ]
        , version = "0.1.0.0"
        , kind = ProbeKind.Elf
        , acquisition = "amoebius-source"
        , integrity = fromSource
        }
      ]
    : List Entry
