let Storage = ./Storage.dhall

let NonEmpty = \(a : Type) -> { head : a, tail : List a }

let ImageIdentity =
      < KindNode
      | Base : { name : Text }
      | Runtime : { name : Text, linked : List Text }
      >

let BakeStep =
      < CopyArtifact : { digest : Text, destination : Text }
      | InstallPackage : { name : Text, version : Text }
      | Configure : { key : Text, value : Text }
      >

let OsArch = < LinuxAmd64 | LinuxArm64 | WindowsAmd64 | DarwinArm64 >

let ImageLayer =
      { blobDigest : Text
      , compressedBytes : Storage.ByteQuantity
      , chainId : Text
      , unpackedBytes : Storage.ByteQuantity
      }

let ImagePlatformArtifact =
      { platform : OsArch
      , childDigest : Text
      , childManifestBytes : Storage.ByteQuantity
      , configDigest : Text
      , configBytes : Storage.ByteQuantity
      , layers : NonEmpty ImageLayer
      , peakImportWorkspace : Storage.ByteQuantity
      }

let ImageArtifact =
      { identity : ImageIdentity
      , manifestListDigest : Text
      , manifestListBytes : Storage.ByteQuantity
      , platforms : NonEmpty ImagePlatformArtifact
      }

let ContainerProcess =
      < AmoebiusRole : < ControlPlaneDaemon | Scheduler | Worker | HostDaemon >
      | BakedService : { binary : Text, args : List Text }
      >

let CpuMemoryEnvelope =
      { cpuMillis : Natural, memoryBytes : Storage.ByteQuantity }

let HostResources =
      { reservations : CpuMemoryEnvelope
      , ceilings : CpuMemoryEnvelope
      , headroom :
          Optional
            { reason :
                < VerticalGrowth : { horizon : Storage.FiniteDuration }
                | BurstAbsorption
                | NeighbourIsolation
                | DefragmentationReserve
                >
            , cpuMillis : Natural
            , memoryBytes : Storage.ByteQuantity
            }
      }

let BuildStageDemand =
      { id : Text
      , platform : OsArch
      , dependsOn : List Text
      , runtime : HostResources
      , peakIntermediateBytes : Storage.ByteQuantity
      , peakCacheWriteBytes : Storage.ByteQuantity
      , steps : NonEmpty BakeStep
      }

let BuildExecutionEnvelope =
      { id : { sourceDigest : Text, output : Text }
      , stages : NonEmpty BuildStageDemand
      , scratchBacking : Text
      , cache : Storage.HostCacheDemand
      , archConcurrency : < Serial | BoundedParallel : Natural >
      , stageConcurrency : < Serial | BoundedParallel : Natural >
      }

in  { ImageIdentity
    , BakeStep
    , OsArch
    , ImageLayer
    , ImagePlatformArtifact
    , ImageArtifact
    , ContainerProcess
    , HostResources
    , BuildStageDemand
    , BuildExecutionEnvelope
    }
