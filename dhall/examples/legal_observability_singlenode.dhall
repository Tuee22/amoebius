let C = ../amoebius/Capability.dhall

in    { app = C.observabilityNeed "telemetry"
      , binding = { provider = C.canonical, shape = C.singleNode }
      }
    : C.Composed
