let C = ../amoebius/Capability.dhall

in    { app = C.objectStoreNeed "assets"
      , binding = { provider = C.canonical, shape = C.singleNode }
      }
    : C.Composed
