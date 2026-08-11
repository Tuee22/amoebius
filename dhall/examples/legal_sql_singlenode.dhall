let C = ../amoebius/Capability.dhall

in    { app = C.sqlNeed "database"
      , binding = { provider = C.canonical, shape = C.singleNode }
      }
    : C.Composed
