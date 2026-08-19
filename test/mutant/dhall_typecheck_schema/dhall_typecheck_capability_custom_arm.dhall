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
      | Custom : Text
      >

in  { Type = Capability }
