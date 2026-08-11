let C = ../amoebius/Capability.dhall

in    { app = C.messageBusNeed "events"
      , binding = { provider = C.canonical, shape = C.distributed 3 }
      }
    : C.Composed
