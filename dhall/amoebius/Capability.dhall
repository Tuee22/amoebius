let EngineRuntime =
      < AppleMetal : { identity : Text }
      | Cuda : { identity : Text }
      | LinuxCpu : { identity : Text }
      >

let EngineFamily = < Llama | Vllm | Diffusion | Onnx >

let Capability =
      < ObjectStore
      | SecretStore
      | MessageBus
      | Sql
      | Identity
      | Observability
      | Registry
      | Edge
      | InferenceEngine : { profile : Text }
      >

let Need =
      < ObjectStore : { resourceName : Text }
      | SecretStore : { resourceName : Text }
      | MessageBus : { resourceName : Text }
      | Sql : { resourceName : Text }
      | Identity : { resourceName : Text }
      | Observability : { resourceName : Text }
      | Registry : { resourceName : Text }
      | Edge : { resourceName : Text }
      | InferenceEngine :
          { resourceName : Text, profile : Text, runtime : EngineRuntime }
      >

let Provider = < Canonical >

let Shape = < SingleNode | Distributed : { nodes : Natural } >

let Binding = { provider : Provider, shape : Shape }

let Composed = { app : Need, binding : Binding }

in  { Type = Capability
    , Need
    , EngineRuntime
    , EngineFamily
    , Provider
    , Shape
    , Binding
    , Composed
    , objectStore = Capability.ObjectStore
    , secretStore = Capability.SecretStore
    , messageBus = Capability.MessageBus
    , sql = Capability.Sql
    , identity = Capability.Identity
    , observability = Capability.Observability
    , registry = Capability.Registry
    , edge = Capability.Edge
    , inferenceEngine =
        \(profile : Text) -> Capability.InferenceEngine { profile }
    , objectStoreNeed =
        \(resourceName : Text) -> Need.ObjectStore { resourceName }
    , secretStoreNeed =
        \(resourceName : Text) -> Need.SecretStore { resourceName }
    , messageBusNeed =
        \(resourceName : Text) -> Need.MessageBus { resourceName }
    , sqlNeed = \(resourceName : Text) -> Need.Sql { resourceName }
    , identityNeed = \(resourceName : Text) -> Need.Identity { resourceName }
    , observabilityNeed =
        \(resourceName : Text) -> Need.Observability { resourceName }
    , registryNeed = \(resourceName : Text) -> Need.Registry { resourceName }
    , edgeNeed = \(resourceName : Text) -> Need.Edge { resourceName }
    , inferenceEngineNeed =
        \(resourceName : Text) ->
        \(profile : Text) ->
        \(runtime : EngineRuntime) ->
          Need.InferenceEngine { resourceName, profile, runtime }
    , appleMetal = \(identity : Text) -> EngineRuntime.AppleMetal { identity }
    , cuda = \(identity : Text) -> EngineRuntime.Cuda { identity }
    , linuxCpu = \(identity : Text) -> EngineRuntime.LinuxCpu { identity }
    , llamaFamily = EngineFamily.Llama
    , vllmFamily = EngineFamily.Vllm
    , diffusionFamily = EngineFamily.Diffusion
    , onnxFamily = EngineFamily.Onnx
    , canonical = Provider.Canonical
    , singleNode = Shape.SingleNode
    , distributed = \(nodes : Natural) -> Shape.Distributed { nodes }
    }
