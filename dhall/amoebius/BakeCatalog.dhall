-- Typed Phase-25 source.  OCI sources are immutable catalog identities, never
-- caller-authored URLs; each stage is non-empty and there is no RunShell arm.
let Platform = < Amd64 | Arm64 >

let BinaryKind = < Elf | Launcher >

let SupportCopy = { sourcePath : Text, targetPath : Text }

let RuntimeEnvironment = { name : Text, value : Text }

let OciCopy =
      { name : Text
      , sourceImage : Text
      , sourceDigest : Text
      , sourcePath : Text
      , targetPath : Text
      , arguments : List Text
      , expectedVersion : Text
      , kind : BinaryKind
      , supportCopies : List SupportCopy
      }

let BuiltProduct =
      { name : Text
      , targetPath : Text
      , arguments : List Text
      , expectedVersion : Text
      , kind : BinaryKind
      }

let BakeStep = < CopyOci : OciCopy | BuildProduct : BuiltProduct >

let NonEmpty = \(a : Type) -> { head : a, tail : List a }

let Stage =
      { name : Text
      , dependencies : List Text
      , platforms : List Platform
      , cpuReservationMillis : Natural
      , cpuCeilingMillis : Natural
      , memoryReservationBytes : Natural
      , memoryCeilingBytes : Natural
      , intermediateBytes : Natural
      , cacheWriteBytes : Natural
      , content : NonEmpty BakeStep
      }

let both = [ Platform.Amd64, Platform.Arm64 ]

let copyWithSupport =
      \(name : Text) ->
      \(sourceImage : Text) ->
      \(sourceDigest : Text) ->
      \(sourcePath : Text) ->
      \(targetPath : Text) ->
      \(arguments : List Text) ->
      \(expectedVersion : Text) ->
      \(kind : BinaryKind) ->
      \(supportCopies : List SupportCopy) ->
        BakeStep.CopyOci
          { name
          , sourceImage
          , sourceDigest
          , sourcePath
          , targetPath
          , arguments
          , expectedVersion
          , kind
          , supportCopies
          }

let copy =
      \(name : Text) ->
      \(sourceImage : Text) ->
      \(sourceDigest : Text) ->
      \(sourcePath : Text) ->
      \(targetPath : Text) ->
      \(arguments : List Text) ->
      \(expectedVersion : Text) ->
      \(kind : BinaryKind) ->
        copyWithSupport
          name
          sourceImage
          sourceDigest
          sourcePath
          targetPath
          arguments
          expectedVersion
          kind
          ([] : List SupportCopy)

in  { architectureConcurrency = 2
    , stageConcurrency = 2
    , scratchBacking = "phase25-build-scratch"
    , scratchCapacityBytes = 103079215104
    , cacheBacking = "phase25-build-cache"
    , cacheCapacityBytes = 68719476736
    , baseImage = "nvidia/cuda:13.0.0-devel-ubuntu24.04"
    , baseDigest =
        "sha256:1e8ac7a54c184a1af8ef2167f28fa98281892a835c981ebcddb1fad04bdd452d"
    , runtimeEnvironment =
          [ { name = "JAVA_HOME", value = "/opt/java/openjdk" }
          , { name = "PATH"
            , value =
                "/opt/java/openjdk/bin:/usr/local/nvidia/bin:/usr/local/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
            }
          , { name = "LD_LIBRARY_PATH"
            , value =
                "/opt/amoebius/postgres/lib:/opt/amoebius/patroni/lib:/usr/local/nvidia/lib:/usr/local/nvidia/lib64:/usr/local/cuda/lib64"
            }
          , { name = "PULSAR_LOG_DIR", value = "/tmp" }
          ]
        : List RuntimeEnvironment
    , stages =
      [   { name = "platform-services"
          , dependencies = [] : List Text
          , platforms = both
          , cpuReservationMillis = 1000
          , cpuCeilingMillis = 1500
          , memoryReservationBytes = 1073741824
          , memoryCeilingBytes = 1610612736
          , intermediateBytes = 17179869184
          , cacheWriteBytes = 4294967296
          , content =
            { head =
                copy
                  "distribution"
                  "registry:2.8.3"
                  "sha256:a3d8aaa63ed8681a604f1dea0aa03f100d5895b6a58ace528858a7b332415373"
                  "/bin/registry"
                  "/usr/bin/registry"
                  [ "--version" ]
                  "2.8.3"
                  BinaryKind.Elf
            , tail =
              [ copy
                  "minio"
                  "minio/minio:RELEASE.2025-07-23T15-54-02Z"
                  "sha256:d249d1fb6966de4d8ad26c04754b545205ff15a62e4fd19ebd0f26fa5baacbc0"
                  "/usr/bin/minio"
                  "/usr/bin/minio"
                  [ "--version" ]
                  "RELEASE.2025-07-23T15-54-02Z"
                  BinaryKind.Elf
              , copy
                  "vault"
                  "hashicorp/vault:1.20.2"
                  "sha256:5cd2003247e0a574a66c66aee1916b1e9e7f99640298f2e61271a8842d2d2a19"
                  "/bin/vault"
                  "/usr/bin/vault"
                  [ "--version" ]
                  "1.20.2"
                  BinaryKind.Elf
              , copy
                  "redis-server"
                  "redis:7.4.5-bookworm"
                  "sha256:90e7a336d044f1abc9e9dbc05d65566850896d11453bbd1dd0fb7e5059f0e8fb"
                  "/usr/local/bin/redis-server"
                  "/usr/bin/redis-server"
                  [ "--version" ]
                  "7.4.5"
                  BinaryKind.Elf
              , copy
                  "redis-cli"
                  "redis:7.4.5-bookworm"
                  "sha256:90e7a336d044f1abc9e9dbc05d65566850896d11453bbd1dd0fb7e5059f0e8fb"
                  "/usr/local/bin/redis-cli"
                  "/usr/bin/redis-cli"
                  [ "--version" ]
                  "7.4.5"
                  BinaryKind.Elf
              , copy
                  "prometheus"
                  "prom/prometheus:v3.5.0"
                  "sha256:63805ebb8d2b3920190daf1cb14a60871b16fd38bed42b857a3182bc621f4996"
                  "/bin/prometheus"
                  "/usr/bin/prometheus"
                  [ "--version" ]
                  "3.5.0"
                  BinaryKind.Elf
              , copy
                  "alertmanager"
                  "prom/alertmanager:v0.28.1"
                  "sha256:27c475db5fb156cab31d5c18a4251ac7ed567746a2483ff264516437a39b15ba"
                  "/bin/alertmanager"
                  "/usr/bin/alertmanager"
                  [ "--version" ]
                  "0.28.1"
                  BinaryKind.Elf
              , copy
                  "thanos"
                  "quay.io/thanos/thanos:v0.39.2"
                  "sha256:1d022ef4b8eff056a0e3b7822f953d931c5704d068413f2d7ce5266aa96c9e80"
                  "/bin/thanos"
                  "/usr/bin/thanos"
                  [ "--version" ]
                  "0.39.2"
                  BinaryKind.Elf
              , copy
                  "envoy"
                  "envoyproxy/envoy:v1.35.1"
                  "sha256:522f4f88bdd741fe87b813bdca678a11c13e42e630cc4304a9e18193813c935d"
                  "/usr/local/bin/envoy"
                  "/usr/bin/envoy"
                  [ "--version" ]
                  "1.35.1"
                  BinaryKind.Elf
              , copy
                  "envoy-gateway"
                  "envoyproxy/gateway:v1.4.2"
                  "sha256:8b0f00e3be81e4b3d4531bc100a4378bc436e2d2fcbb23856d0d8ec5b56dfba6"
                  "/usr/local/bin/envoy-gateway"
                  "/usr/bin/envoy-gateway"
                  [ "version" ]
                  "1.4.2"
                  BinaryKind.Elf
              , copy
                  "metallb-controller"
                  "quay.io/metallb/controller:v0.15.2"
                  "sha256:417cdb6d6f9f2c410cceb84047d3a4da3bfb78b5ddfa30f4cf35ea5c667e8c2e"
                  "/controller"
                  "/usr/bin/metallb-controller"
                  [ "-h" ]
                  "0.15.2"
                  BinaryKind.Elf
              , copy
                  "metallb-speaker"
                  "quay.io/metallb/speaker:v0.15.2"
                  "sha256:260c9406f957c0830d4e6cd2e9ac8c05e51ac959dd2462c4c2269ac43076665a"
                  "/speaker"
                  "/usr/bin/metallb-speaker"
                  [ "-h" ]
                  "0.15.2"
                  BinaryKind.Elf
              , copy
                  "percona-postgresql-operator"
                  "percona/percona-postgresql-operator:2.6.0"
                  "sha256:6b7bf435ce89de3e2f1ec5fceeb4c27ae989eb24fec25a65e47dd337f3a31a17"
                  "/usr/local/bin/postgres-operator"
                  "/usr/bin/percona-postgresql-operator"
                  [ "--version" ]
                  "2.6.0"
                  BinaryKind.Elf
              , copy
                  "nvcc"
                  "nvidia/cuda:13.0.0-devel-ubuntu24.04"
                  "sha256:1e8ac7a54c184a1af8ef2167f28fa98281892a835c981ebcddb1fad04bdd452d"
                  "/usr/local/cuda/bin/nvcc"
                  "/usr/local/cuda/bin/nvcc"
                  [ "--version" ]
                  "13.0"
                  BinaryKind.Launcher
              , copy
                  "g++"
                  "nvidia/cuda:13.0.0-devel-ubuntu24.04"
                  "sha256:1e8ac7a54c184a1af8ef2167f28fa98281892a835c981ebcddb1fad04bdd452d"
                  "/usr/bin/g++"
                  "/usr/bin/g++"
                  [ "--version" ]
                  "13.3.0"
                  BinaryKind.Elf
              ]
            }
          }
        : Stage
      , { name = "service-bundles"
        , dependencies = [] : List Text
        , platforms = both
        , cpuReservationMillis = 1500
        , cpuCeilingMillis = 2000
        , memoryReservationBytes = 1073741824
        , memoryCeilingBytes = 2147483648
        , intermediateBytes = 17179869184
        , cacheWriteBytes = 2147483648
        , content =
          { head =
              copy
                "pulsar"
                "apachepulsar/pulsar-all:4.0.6"
                "sha256:d217884eef29768c50e2b05687971cebf28c56a47c7dc2c4b9b3327229c14629"
                "/pulsar"
                "/pulsar"
                [ "version" ]
                "4.0.6"
                BinaryKind.Launcher
          , tail =
            [ copy
                "grafana"
                "grafana/grafana:12.1.1"
                "sha256:a1701c2180249361737a99a01bc770db39381640e4d631825d38ff4535efa47d"
                "/usr/share/grafana"
                "/usr/share/grafana"
                [ "--version" ]
                "12.1.1"
                BinaryKind.Elf
            , copyWithSupport
                "postgres"
                "postgres:17.6-bookworm"
                "sha256:f3bd19c606e442c3d7bdfa8002e03fe260a1023351e0ea4598032022b68dd6e3"
                "/usr/lib/postgresql/17"
                "/usr/lib/postgresql/17"
                [ "--version" ]
                "17.6"
                BinaryKind.Elf
                [ { sourcePath = "/lib/*-linux-gnu/libxml2.so.2*"
                  , targetPath = "/opt/amoebius/postgres/lib/"
                  }
                , { sourcePath = "/lib/*-linux-gnu/libgssapi_krb5.so.2*"
                  , targetPath = "/opt/amoebius/postgres/lib/"
                  }
                , { sourcePath = "/lib/*-linux-gnu/libldap-2.5.so.0*"
                  , targetPath = "/opt/amoebius/postgres/lib/"
                  }
                , { sourcePath = "/lib/*-linux-gnu/liblber-2.5.so.0*"
                  , targetPath = "/opt/amoebius/postgres/lib/"
                  }
                , { sourcePath = "/lib/*-linux-gnu/libicui18n.so.72*"
                  , targetPath = "/opt/amoebius/postgres/lib/"
                  }
                , { sourcePath = "/lib/*-linux-gnu/libicuuc.so.72*"
                  , targetPath = "/opt/amoebius/postgres/lib/"
                  }
                , { sourcePath = "/lib/*-linux-gnu/libicudata.so.72*"
                  , targetPath = "/opt/amoebius/postgres/lib/"
                  }
                , { sourcePath = "/lib/*-linux-gnu/libkrb5.so.3*"
                  , targetPath = "/opt/amoebius/postgres/lib/"
                  }
                , { sourcePath = "/lib/*-linux-gnu/libk5crypto.so.3*"
                  , targetPath = "/opt/amoebius/postgres/lib/"
                  }
                , { sourcePath = "/lib/*-linux-gnu/libkrb5support.so.0*"
                  , targetPath = "/opt/amoebius/postgres/lib/"
                  }
                , { sourcePath = "/lib/*-linux-gnu/libkeyutils.so.1*"
                  , targetPath = "/opt/amoebius/postgres/lib/"
                  }
                , { sourcePath = "/lib/*-linux-gnu/libsasl2.so.2*"
                  , targetPath = "/opt/amoebius/postgres/lib/"
                  }
                , { sourcePath = "/lib/*-linux-gnu/libgnutls.so.30*"
                  , targetPath = "/opt/amoebius/postgres/lib/"
                  }
                , { sourcePath = "/lib/*-linux-gnu/libp11-kit.so.0*"
                  , targetPath = "/opt/amoebius/postgres/lib/"
                  }
                , { sourcePath = "/lib/*-linux-gnu/libidn2.so.0*"
                  , targetPath = "/opt/amoebius/postgres/lib/"
                  }
                , { sourcePath = "/lib/*-linux-gnu/libunistring.so.2*"
                  , targetPath = "/opt/amoebius/postgres/lib/"
                  }
                , { sourcePath = "/lib/*-linux-gnu/libtasn1.so.6*"
                  , targetPath = "/opt/amoebius/postgres/lib/"
                  }
                , { sourcePath = "/lib/*-linux-gnu/libnettle.so.8*"
                  , targetPath = "/opt/amoebius/postgres/lib/"
                  }
                , { sourcePath = "/lib/*-linux-gnu/libhogweed.so.6*"
                  , targetPath = "/opt/amoebius/postgres/lib/"
                  }
                , { sourcePath = "/lib/*-linux-gnu/libgmp.so.10*"
                  , targetPath = "/opt/amoebius/postgres/lib/"
                  }
                , { sourcePath = "/lib/*-linux-gnu/libffi.so.8*"
                  , targetPath = "/opt/amoebius/postgres/lib/"
                  }
                ]
            , copyWithSupport
                "patroni"
                "ghcr.io/zalando/spilo-17:4.0-p2"
                "sha256:23861da069941ff5345e6a97455e60a63fc2f16c97857da8f85560370726cbe7"
                "/usr/local/bin/patroni"
                "/usr/local/bin/patroni"
                [ "--version" ]
                "4.0.4"
                BinaryKind.Launcher
                [ { sourcePath = "/usr/bin/python3"
                  , targetPath = "/usr/bin/python3"
                  }
                , { sourcePath = "/usr/bin/python3.10"
                  , targetPath = "/usr/bin/python3.10"
                  }
                , { sourcePath = "/usr/lib/python3.10"
                  , targetPath = "/usr/lib/python3.10"
                  }
                , { sourcePath = "/usr/lib/python3"
                  , targetPath = "/usr/lib/python3"
                  }
                , { sourcePath = "/usr/lib/python3/dist-packages"
                  , targetPath = "/usr/lib/python3/dist-packages"
                  }
                , { sourcePath = "/usr/local/lib/python3.10"
                  , targetPath = "/usr/local/lib/python3.10"
                  }
                , { sourcePath = "/lib/*-linux-gnu/libexpat.so.1*"
                  , targetPath = "/opt/amoebius/patroni/lib/"
                  }
                , { sourcePath = "/lib/*-linux-gnu/libpq.so.5*"
                  , targetPath = "/opt/amoebius/patroni/lib/"
                  }
                ]
            , copyWithSupport
                "pgadmin"
                "dpage/pgadmin4:9.6"
                "sha256:2c7d73e13bd6c30b1d53e4c25d0d6d81adbd0799c4f4d6a09efc5d68fca5d16d"
                "/pgadmin4"
                "/pgadmin4"
                [ "-c"
                , "import sys; sys.path.insert(0, '/venv/lib/python3.12/site-packages'); sys.path.insert(0, '/pgadmin4'); import config; print(config.APP_VERSION)"
                ]
                "9.6"
                BinaryKind.Elf
                [ { sourcePath = "/venv", targetPath = "/venv" }
                , { sourcePath = "/usr/bin/python3.12"
                  , targetPath = "/usr/bin/pgadmin-python3.12"
                  }
                , { sourcePath = "/usr/lib/python3.12"
                  , targetPath = "/usr/lib/python3.12"
                  }
                , { sourcePath = "/lib/ld-musl-*.so.1", targetPath = "/lib/" }
                , { sourcePath = "/usr/lib/*.so*", targetPath = "/usr/lib/" }
                , { sourcePath = "/usr/lib/libpython3.12.so.1.0"
                  , targetPath = "/usr/lib/libpython3.12.so.1.0"
                  }
                ]
            , copy
                "keycloak"
                "quay.io/keycloak/keycloak:26.3.2"
                "sha256:98fab020a3a490aba0978f237e2a06cd0ea42bf149c6cf10f11c0aaf27728ff2"
                "/opt/keycloak"
                "/opt/keycloak"
                [ "--version" ]
                "26.3.2"
                BinaryKind.Launcher
            , copy
                "temurin"
                "eclipse-temurin:21.0.8_9-jre-jammy"
                "sha256:db1689535962d757a5adabf57387584ed543d38c0b9d1fe870123ea362ad73b0"
                "/opt/java/openjdk"
                "/opt/java/openjdk"
                [ "--version" ]
                "21.0.8"
                BinaryKind.Elf
            ]
          }
        }
      , { name = "amoebius-runtime"
        , dependencies = [ "platform-services", "service-bundles" ]
        , platforms = both
        , cpuReservationMillis = 1000
        , cpuCeilingMillis = 1500
        , memoryReservationBytes = 1073741824
        , memoryCeilingBytes = 1610612736
        , intermediateBytes = 34359738368
        , cacheWriteBytes = 12884901888
        , content =
          { head =
              BakeStep.BuildProduct
                { name = "amoebius-jit-build-resolver"
                , targetPath = "/usr/bin/amoebius"
                , arguments = [ "jit-build-resolver", "--version" ]
                , expectedVersion = "0.1.0.0"
                , kind = BinaryKind.Elf
                }
          , tail = [] : List BakeStep
          }
        }
      ]
    , forbiddenPayloads =
      [ "llama.cpp"
      , "whisper.cpp"
      , "onnxruntime"
      , "audiveris"
      , "infernix-adapter"
      , "jitml-adapter"
      ]
    }
