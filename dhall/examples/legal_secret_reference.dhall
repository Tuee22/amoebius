let SecretRef = ../amoebius/SecretRef.dhall

let registryPullCredential
    : SecretRef.Sensitive
    = SecretRef.sensitive (SecretRef.vault "kv" "amoebius/registry" "pullToken")

let envelopeKey
    : SecretRef.Sensitive
    = SecretRef.sensitive (SecretRef.transitKey "amoebius-checkpoint")

let providerAdminCredential
    : SecretRef.Sensitive
    = SecretRef.sensitive
        (SecretRef.prompt "provider-admin" "mint a least-privilege identity")

in  { registryPullCredential, envelopeKey, providerAdminCredential }
