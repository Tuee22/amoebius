let C = ../amoebius/Capability.dhall

in    { app = C.registryNeed "images"
      , binding = { provider = C.canonical, shape = C.singleNode }
      }
    : C.Composed
