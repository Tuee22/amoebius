-- The Gate-2 paired positive for the plaintext-secret negative.
--
-- It is `trivial_app.dhall` with one sensitive field added, so the negative twin
-- differs from it in exactly one place: what that field holds. The field is added by
-- record update rather than by widening `App.Type`, because no production surface yet
-- names a secret — the rule the decoder enforces has to hold before the first surface
-- that needs it arrives, not after.
let SecretRef = ../amoebius/SecretRef.dhall

let app = ./trivial_app.dhall

in  app // { secretRef = SecretRef.vault "kv" "amoebius/registry" "pullToken" }
