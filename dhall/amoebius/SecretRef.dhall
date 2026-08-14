let SecretRef =
      < Vault : { mount : Text, path : Text, field : Text }
      | TransitKey : { name : Text }
      | Prompt : { name : Text, purpose : Text }
      >

let Sensitive = { secretRef : SecretRef }

in  { Type = SecretRef
    , Sensitive
    , vault =
        \(mount : Text) ->
        \(path : Text) ->
        \(field : Text) ->
          SecretRef.Vault { mount, path, field }
    , transitKey = \(name : Text) -> SecretRef.TransitKey { name }
    , prompt =
        \(name : Text) ->
        \(purpose : Text) ->
          SecretRef.Prompt { name, purpose }
    , sensitive = \(secretRef : SecretRef) -> { secretRef }
    }
