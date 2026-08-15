-- Typed Phase-25 source.  Every third-party binary enters on the highest rung of
-- the `image_build_doctrine.md` section 7 acquisition ladder that applies to it,
-- and there is no RunShell arm.
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
      , lastResortReason : Text
      }

-- What rung 3 builds *from*.  A `BuildProduct` that named only what it produces
-- would leave the source coordinate of five third-party projects living in
-- whichever script happened to build them — the same "advice the type cannot
-- express" the acquisition ladder exists to remove.  None of the three arms
-- carries an integrity value: Go resolves one from the module checksum database
-- and pip from the index, both during the build.
let GoBuild =
      { repository : Text
      , reference : Text
      , packagePath : Text
      , versionSymbol : Text
      , versionValue : Text
      , requiresCgo : Bool
      }

let PythonDistribution =
      { distribution : Text
      , distributionVersion : Text
      , interpreterVersion : Text
      }

let AmoebiusBinary = { cabalTarget : Text }

let BuildSource =
      < AmoebiusSource : AmoebiusBinary
      | GoModule : GoBuild
      | PythonPackage : PythonDistribution
      >

let BuiltProduct =
      { name : Text
      , source : BuildSource
      , targetPath : Text
      , arguments : List Text
      , expectedVersion : Text
      , kind : BinaryKind
      }

let AptPackaged =
      { name : Text
      , package : Text
      , packageVersion : Text
      , archiveSuite : Text
      , targetPath : Text
      , arguments : List Text
      , expectedVersion : Text
      , kind : BinaryKind
      }

let ArtifactAsset =
      { platform : Platform, assetUrl : Text, checksumManifest : Text }

-- Verified against each publisher on 2026-08-14, for both arches.  The nine
-- artifacts use three digest algorithms and two manifest shapes between them, so
-- a single hard-coded `sha256sum -c` would verify seven and silently skip two.
let ChecksumAlgorithm = < Sha1 | Sha256 | Sha512 >

let ChecksumShape = < DigestOnly | DigestNamed >

let ArchiveFormat = < Bare | TarGz | Zip >

let PublishedArtifact =
      { name : Text
      , publisher : Text
      , releaseVersion : Text
      , assets : List ArtifactAsset
      , checksumAlgorithm : ChecksumAlgorithm
      , checksumShape : ChecksumShape
      , archiveFormat : ArchiveFormat
      , archiveMember : Text
      , targetPath : Text
      , arguments : List Text
      , expectedVersion : Text
      , kind : BinaryKind
      }

-- The acquisition ladder of `image_build_doctrine.md` section 7, highest rung
-- first.  Making the rungs arms is what lets a gate ask which one a binary sits
-- on; a preference stated in prose cannot be read back out of a catalog.
let BakeStep =
      < AptPackage : AptPackaged
      | OfficialArtifact : PublishedArtifact
      | BuildProduct : BuiltProduct
      | CopyOci : OciCopy
      >

-- Build-time acquisition tooling, and deliberately not a `BakeStep`.  Rung 2
-- fetches an asset and its publisher's manifest, which needs a TLS trust store,
-- an HTTP client, and an unzipper; none of the three is a platform-service
-- binary, so none belongs in the inventory the gate reconciles against the
-- standard-services oracle or on a rung the acquisition table has to rank.  The
-- alternative was a fixed list inside the renderer, which is the same dependency
-- with nowhere to review it.
let AcquisitionTool =
      { package : Text, packageVersion : Text, archiveSuite : Text }

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

let noble = "noble/main"

let nobleUniverse = "noble/universe"

let nobleUpdatesMain = "noble-updates/main"

let nobleUpdatesUniverse = "noble-updates/universe"

let apt =
      \(name : Text) ->
      \(package : Text) ->
      \(packageVersion : Text) ->
      \(archiveSuite : Text) ->
      \(targetPath : Text) ->
      \(arguments : List Text) ->
      \(expectedVersion : Text) ->
      \(kind : BinaryKind) ->
        BakeStep.AptPackage
          { name
          , package
          , packageVersion
          , archiveSuite
          , targetPath
          , arguments
          , expectedVersion
          , kind
          }

-- Rung 2 in the two shapes the publishers actually ship: one manifest per asset
-- (MinIO, Grafana, Keycloak) and one per release covering every asset (HashiCorp,
-- the Prometheus family, Envoy, Apache).  A single release-level field would have
-- forced the first three into a shape they do not have.
let perAssetArtifact =
      \(name : Text) ->
      \(publisher : Text) ->
      \(releaseVersion : Text) ->
      \(amd64Url : Text) ->
      \(amd64Manifest : Text) ->
      \(arm64Url : Text) ->
      \(arm64Manifest : Text) ->
      \(checksumAlgorithm : ChecksumAlgorithm) ->
      \(checksumShape : ChecksumShape) ->
      \(archiveFormat : ArchiveFormat) ->
      \(archiveMember : Text) ->
      \(targetPath : Text) ->
      \(arguments : List Text) ->
      \(expectedVersion : Text) ->
      \(kind : BinaryKind) ->
        BakeStep.OfficialArtifact
          { name
          , publisher
          , releaseVersion
          , assets =
            [ { platform = Platform.Amd64
              , assetUrl = amd64Url
              , checksumManifest = amd64Manifest
              }
            , { platform = Platform.Arm64
              , assetUrl = arm64Url
              , checksumManifest = arm64Manifest
              }
            ]
          , checksumAlgorithm
          , checksumShape
          , archiveFormat
          , archiveMember
          , targetPath
          , arguments
          , expectedVersion
          , kind
          }

let perReleaseArtifact =
      \(name : Text) ->
      \(publisher : Text) ->
      \(releaseVersion : Text) ->
      \(amd64Url : Text) ->
      \(arm64Url : Text) ->
      \(manifest : Text) ->
      \(checksumAlgorithm : ChecksumAlgorithm) ->
      \(archiveFormat : ArchiveFormat) ->
      \(archiveMember : Text) ->
      \(targetPath : Text) ->
      \(arguments : List Text) ->
      \(expectedVersion : Text) ->
      \(kind : BinaryKind) ->
        perAssetArtifact
          name
          publisher
          releaseVersion
          amd64Url
          manifest
          arm64Url
          manifest
          checksumAlgorithm
          ChecksumShape.DigestNamed
          archiveFormat
          archiveMember
          targetPath
          arguments
          expectedVersion
          kind

let built =
      \(name : Text) ->
      \(source : BuildSource) ->
      \(targetPath : Text) ->
      \(arguments : List Text) ->
      \(expectedVersion : Text) ->
      \(kind : BinaryKind) ->
        BakeStep.BuildProduct
          { name, source, targetPath, arguments, expectedVersion, kind }

let goModule =
      \(repository : Text) ->
      \(reference : Text) ->
      \(packagePath : Text) ->
      \(versionSymbol : Text) ->
      \(versionValue : Text) ->
      \(requiresCgo : Bool) ->
        BuildSource.GoModule
          { repository
          , reference
          , packagePath
          , versionSymbol
          , versionValue
          , requiresCgo
          }

in  { architectureConcurrency = 2
    , stageConcurrency = 2
    , scratchBacking = "phase25-build-scratch"
    , scratchCapacityBytes = 34359738368
    , cacheBacking = "phase25-build-cache"
    , cacheCapacityBytes = 21474836480
    , baseImage = "ubuntu:24.04"
    , baseDigest =
        "sha256:561618e2c15bf2397621dd04f96926663a3b5616c189cf7e38db7e82f5c538ea"
    , acquisitionTools =
      [ { package = "ca-certificates"
        , packageVersion = "20260601~24.04.1"
        , archiveSuite = nobleUpdatesMain
        }
      , { package = "curl"
        , packageVersion = "8.5.0-2ubuntu10.11"
        , archiveSuite = nobleUpdatesMain
        }
      , { package = "unzip"
        , packageVersion = "6.0-28ubuntu4.1"
        , archiveSuite = nobleUpdatesMain
        }
      ]
      : List AcquisitionTool
    , runtimeEnvironment =
        -- Ubuntu names the JVM directory by architecture, and `TARGETARCH` is
        -- already declared, so one authored value covers both arches.  The
        -- LD_LIBRARY_PATH the pre-amendment catalog needed is gone with the
        -- scavenged library closures it existed to find.
          [ { name = "JAVA_HOME"
            , value = "/usr/lib/jvm/java-21-openjdk-\${TARGETARCH}"
            }
          , { name = "PATH"
            , value =
                "/usr/lib/jvm/java-21-openjdk-\${TARGETARCH}/bin:/usr/lib/postgresql/16/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
            }
          , { name = "PULSAR_LOG_DIR", value = "/tmp" }
          ]
        : List RuntimeEnvironment
    , stages =
      [   { name = "platform-services"
          , dependencies = [] : List Text
          , platforms = both
          , cpuReservationMillis = 750
          , cpuCeilingMillis = 1500
          , memoryReservationBytes = 805306368
          , memoryCeilingBytes = 1610612736
          , intermediateBytes = 2147483648
          , cacheWriteBytes = 1073741824
          , content =
            { head =
                apt
                  "distribution"
                  "docker-registry"
                  "2.8.2+ds1-1ubuntu0.24.04.3"
                  nobleUpdatesUniverse
                  "/usr/bin/docker-registry"
                  [ "--version" ]
                  "2.8.2"
                  BinaryKind.Elf
            , tail =
              [ apt
                  "redis-server"
                  "redis-server"
                  "5:7.0.15-1ubuntu0.24.04.4"
                  nobleUpdatesUniverse
                  "/usr/bin/redis-server"
                  [ "--version" ]
                  "7.0.15"
                  BinaryKind.Elf
              , apt
                  "redis-cli"
                  "redis-tools"
                  "5:7.0.15-1ubuntu0.24.04.4"
                  nobleUpdatesUniverse
                  "/usr/bin/redis-cli"
                  [ "--version" ]
                  "7.0.15"
                  BinaryKind.Elf
              , apt
                  "postgres"
                  "postgresql-16"
                  "16.14-0ubuntu0.24.04.1"
                  nobleUpdatesMain
                  "/usr/lib/postgresql/16/bin/postgres"
                  [ "--version" ]
                  "16.14"
                  BinaryKind.Elf
              , apt
                  "patroni"
                  "patroni"
                  "3.2.2-2"
                  nobleUniverse
                  "/usr/bin/patroni"
                  [ "--version" ]
                  "3.2.2"
                  BinaryKind.Launcher
              , -- The slot the doctrine names "a multi-arch Temurin JRE"; the
                -- archive supplies the same JVM requirement for both arches, so
                -- rung 1 applies and the vendor changes while the slot does not.
                apt
                  "temurin"
                  "openjdk-21-jre-headless"
                  "21.0.11+10-1~24.04.2"
                  nobleUpdatesMain
                  "/usr/bin/java"
                  [ "--version" ]
                  "21.0.11"
                  BinaryKind.Elf
              , -- The metapackage version and the compiler version differ: apt
                -- pins `4:13.2.0-7ubuntu1`, which installs g++-13 and makes
                -- `/usr/bin/g++ --version` report 13.3.0.  Both are recorded,
                -- because the gate checks the second and a reviewer checks the
                -- first.
                apt
                  "g++"
                  "g++"
                  "4:13.2.0-7ubuntu1"
                  noble
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
        , cpuReservationMillis = 1000
        , cpuCeilingMillis = 2000
        , memoryReservationBytes = 1073741824
        , memoryCeilingBytes = 2147483648
        , intermediateBytes = 4294967296
        , cacheWriteBytes = 1073741824
        , content =
          { head =
              perAssetArtifact
                "minio"
                "dl.min.io"
                "RELEASE.2025-07-23T15-54-02Z"
                "https://dl.min.io/server/minio/release/linux-amd64/archive/minio.RELEASE.2025-07-23T15-54-02Z"
                "https://dl.min.io/server/minio/release/linux-amd64/archive/minio.RELEASE.2025-07-23T15-54-02Z.sha256sum"
                "https://dl.min.io/server/minio/release/linux-arm64/archive/minio.RELEASE.2025-07-23T15-54-02Z"
                "https://dl.min.io/server/minio/release/linux-arm64/archive/minio.RELEASE.2025-07-23T15-54-02Z.sha256sum"
                ChecksumAlgorithm.Sha256
                ChecksumShape.DigestNamed
                ArchiveFormat.Bare
                ""
                "/usr/bin/minio"
                [ "--version" ]
                "RELEASE.2025-07-23T15-54-02Z"
                BinaryKind.Elf
          , tail =
            [ perReleaseArtifact
                "vault"
                "releases.hashicorp.com"
                "1.20.2"
                "https://releases.hashicorp.com/vault/1.20.2/vault_1.20.2_linux_amd64.zip"
                "https://releases.hashicorp.com/vault/1.20.2/vault_1.20.2_linux_arm64.zip"
                "https://releases.hashicorp.com/vault/1.20.2/vault_1.20.2_SHA256SUMS"
                ChecksumAlgorithm.Sha256
                ArchiveFormat.Zip
                "vault"
                "/usr/bin/vault"
                [ "--version" ]
                "1.20.2"
                BinaryKind.Elf
            , perReleaseArtifact
                "prometheus"
                "github.com/prometheus/prometheus"
                "3.5.0"
                "https://github.com/prometheus/prometheus/releases/download/v3.5.0/prometheus-3.5.0.linux-amd64.tar.gz"
                "https://github.com/prometheus/prometheus/releases/download/v3.5.0/prometheus-3.5.0.linux-arm64.tar.gz"
                "https://github.com/prometheus/prometheus/releases/download/v3.5.0/sha256sums.txt"
                ChecksumAlgorithm.Sha256
                ArchiveFormat.TarGz
                "prometheus"
                "/usr/bin/prometheus"
                [ "--version" ]
                "3.5.0"
                BinaryKind.Elf
            , perReleaseArtifact
                "alertmanager"
                "github.com/prometheus/alertmanager"
                "0.28.1"
                "https://github.com/prometheus/alertmanager/releases/download/v0.28.1/alertmanager-0.28.1.linux-amd64.tar.gz"
                "https://github.com/prometheus/alertmanager/releases/download/v0.28.1/alertmanager-0.28.1.linux-arm64.tar.gz"
                "https://github.com/prometheus/alertmanager/releases/download/v0.28.1/sha256sums.txt"
                ChecksumAlgorithm.Sha256
                ArchiveFormat.TarGz
                "alertmanager"
                "/usr/bin/alertmanager"
                [ "--version" ]
                "0.28.1"
                BinaryKind.Elf
            , perReleaseArtifact
                "thanos"
                "github.com/thanos-io/thanos"
                "0.39.2"
                "https://github.com/thanos-io/thanos/releases/download/v0.39.2/thanos-0.39.2.linux-amd64.tar.gz"
                "https://github.com/thanos-io/thanos/releases/download/v0.39.2/thanos-0.39.2.linux-arm64.tar.gz"
                "https://github.com/thanos-io/thanos/releases/download/v0.39.2/sha256sums.txt"
                ChecksumAlgorithm.Sha256
                ArchiveFormat.TarGz
                "thanos"
                "/usr/bin/thanos"
                [ "--version" ]
                "0.39.2"
                BinaryKind.Elf
            , -- The publisher spells the arches `x86_64`/`aarch_64` and signs one
              -- clearsigned list whose entries name its own build paths, so the
              -- match is on the trailing basename.  The armor is not itself
              -- verified: this is a digest claim, not a signature check.
              perReleaseArtifact
                "envoy"
                "github.com/envoyproxy/envoy"
                "1.35.1"
                "https://github.com/envoyproxy/envoy/releases/download/v1.35.1/envoy-1.35.1-linux-x86_64"
                "https://github.com/envoyproxy/envoy/releases/download/v1.35.1/envoy-1.35.1-linux-aarch_64"
                "https://github.com/envoyproxy/envoy/releases/download/v1.35.1/checksums.txt.asc"
                ChecksumAlgorithm.Sha256
                ArchiveFormat.Bare
                ""
                "/usr/bin/envoy"
                [ "--version" ]
                "1.35.1"
                BinaryKind.Elf
            , -- Grafana publishes one `.sha256` per asset whose whole body is the
              -- digest, so there is no filename to match on.
              perAssetArtifact
                "grafana"
                "dl.grafana.com"
                "12.1.1"
                "https://dl.grafana.com/oss/release/grafana-12.1.1.linux-amd64.tar.gz"
                "https://dl.grafana.com/oss/release/grafana-12.1.1.linux-amd64.tar.gz.sha256"
                "https://dl.grafana.com/oss/release/grafana-12.1.1.linux-arm64.tar.gz"
                "https://dl.grafana.com/oss/release/grafana-12.1.1.linux-arm64.tar.gz.sha256"
                ChecksumAlgorithm.Sha256
                ChecksumShape.DigestOnly
                ArchiveFormat.TarGz
                ""
                "/usr/share/grafana"
                [ "--version" ]
                "12.1.1"
                BinaryKind.Elf
            , -- An arch-independent JVM payload, so both arches name one asset.
              -- ANOMALY: Keycloak publishes `.md5`, `.sha1`, and `.asc` and no
              -- SHA-256, so the strongest digest manifest available is SHA-1,
              -- whose collision resistance is broken.  The stronger option is the
              -- PGP signature, which needs a trust anchor this phase does not yet
              -- author; the SHA-1 claim is recorded as what the publisher offers,
              -- not as adequate.
              perAssetArtifact
                "keycloak"
                "github.com/keycloak/keycloak"
                "26.3.2"
                "https://github.com/keycloak/keycloak/releases/download/26.3.2/keycloak-26.3.2.tar.gz"
                "https://github.com/keycloak/keycloak/releases/download/26.3.2/keycloak-26.3.2.tar.gz.sha1"
                "https://github.com/keycloak/keycloak/releases/download/26.3.2/keycloak-26.3.2.tar.gz"
                "https://github.com/keycloak/keycloak/releases/download/26.3.2/keycloak-26.3.2.tar.gz.sha1"
                ChecksumAlgorithm.Sha1
                ChecksumShape.DigestOnly
                ArchiveFormat.TarGz
                ""
                "/opt/keycloak"
                [ "--version" ]
                "26.3.2"
                BinaryKind.Launcher
            , -- Also an arch-independent JVM payload.  ANOMALY: the tarball has
              -- rolled off `downloads.apache.org` to `archive.apache.org` while
              -- its `.sha512` has not, so asset and manifest come from different
              -- Apache hosts.
              perReleaseArtifact
                "pulsar"
                "archive.apache.org"
                "4.0.6"
                "https://archive.apache.org/dist/pulsar/pulsar-4.0.6/apache-pulsar-4.0.6-bin.tar.gz"
                "https://archive.apache.org/dist/pulsar/pulsar-4.0.6/apache-pulsar-4.0.6-bin.tar.gz"
                "https://downloads.apache.org/pulsar/pulsar-4.0.6/apache-pulsar-4.0.6-bin.tar.gz.sha512"
                ChecksumAlgorithm.Sha512
                ArchiveFormat.TarGz
                ""
                "/pulsar"
                [ "version" ]
                "4.0.6"
                BinaryKind.Launcher
            ]
          }
        }
      , { name = "amoebius-runtime"
        , dependencies = [ "platform-services", "service-bundles" ]
        , platforms = both
        , cpuReservationMillis = 750
        , cpuCeilingMillis = 1500
        , memoryReservationBytes = 1073741824
        , memoryCeilingBytes = 1610612736
        , intermediateBytes = 4294967296
        , cacheWriteBytes = 2147483648
        , content =
          { head =
              built
                "amoebius-jit-build-resolver"
                (BuildSource.AmoebiusSource { cabalTarget = "exe:amoebius" })
                "/usr/bin/amoebius"
                [ "jit-build-resolver", "--version" ]
                "0.1.0.0"
                BinaryKind.Elf
          , tail =
            [ -- The publisher stamps the version through the linker, so the
              -- symbol and the value it takes are catalog data rather than a
              -- flag remembered by whatever ran the build.
              built
                "envoy-gateway"
                ( goModule
                    "https://github.com/envoyproxy/gateway"
                    "v1.4.2"
                    "./cmd/envoy-gateway"
                    "github.com/envoyproxy/gateway/internal/cmd/version.envoyGatewayVersion"
                    "v1.4.2"
                    False
                )
                "/usr/bin/envoy-gateway"
                [ "version" ]
                "1.4.2"
                BinaryKind.Elf
            , -- MetalLB carries its own version in source, so there is no symbol
              -- to stamp; both binaries come out of one checkout.
              built
                "metallb-controller"
                ( goModule
                    "https://github.com/metallb/metallb"
                    "v0.15.2"
                    "./controller"
                    ""
                    ""
                    False
                )
                "/usr/bin/metallb-controller"
                [ "-h" ]
                "0.15.2"
                BinaryKind.Elf
            , built
                "metallb-speaker"
                ( goModule
                    "https://github.com/metallb/metallb"
                    "v0.15.2"
                    "./speaker"
                    ""
                    ""
                    False
                )
                "/usr/bin/metallb-speaker"
                [ "-h" ]
                "0.15.2"
                BinaryKind.Elf
            , -- The only rung-3 product that needs cgo: its SQL parser is a C
              -- library, so the arm64 build needs a cross toolchain and the
              -- catalog says so rather than the builder discovering it.
              built
                "percona-postgresql-operator"
                ( goModule
                    "https://github.com/percona/percona-postgresql-operator"
                    "v2.6.0"
                    "./cmd/postgres-operator"
                    ""
                    ""
                    True
                )
                "/usr/bin/percona-postgresql-operator"
                [ "--version" ]
                "2.6.0"
                BinaryKind.Elf
            , -- Published for pip consumption rather than as a per-arch binary:
              -- the application wheel is architecture-independent and its
              -- dependency closure is not, so the tree is resolved once per arch.
              built
                "pgadmin"
                ( BuildSource.PythonPackage
                    { distribution = "pgadmin4"
                    , distributionVersion = "9.6"
                    , -- The dependency closure resolves compiled wheels, so the
                      -- interpreter that resolves them and the one in the image
                      -- have to be the same minor version or the tree it produces
                      -- cannot be imported.
                      interpreterVersion = "3.12"
                    }
                )
                "/pgadmin4"
                [ "-c"
                , "import sys; sys.path.insert(0, '/pgadmin4'); import config; print(config.APP_VERSION)"
                ]
                "9.6"
                BinaryKind.Launcher
            ]
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
