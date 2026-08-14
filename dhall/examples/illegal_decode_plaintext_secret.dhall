-- Gate-1 green on purpose: the field is a plain `Text`, so the typechecker has nothing
-- to object to. That is precisely why Gate 2 must decide it independently — the author
-- who writes a secret inline is the author who did not reach for `SecretRef`.
let app = ./trivial_app.dhall

in  app // { secretRef = "s3cr3t-registry-pull-token" }
