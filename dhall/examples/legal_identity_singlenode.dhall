let C = ../amoebius/Capability.dhall

in    { app = C.identityNeed "accounts"
      , binding = { provider = C.canonical, shape = C.singleNode }
      }
    : C.Composed
