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
      | Pulsar
      >

in  { Type = Capability
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
    }
