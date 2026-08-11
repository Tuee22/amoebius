let C = ../amoebius/Capability.dhall

in    { app = C.edgeNeed "public-edge"
      , binding = { provider = C.canonical, shape = C.singleNode }
      }
    : C.Composed
