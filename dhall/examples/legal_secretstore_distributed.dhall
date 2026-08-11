let C = ../amoebius/Capability.dhall

in    { app = C.secretStoreNeed "secrets"
      , binding = { provider = C.canonical, shape = C.distributed 3 }
      }
    : C.Composed
