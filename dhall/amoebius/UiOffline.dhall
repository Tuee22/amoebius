let QueueContract =
      { maxCount : Natural
      , maxBytes : Natural
      , maxAgeSeconds : Natural
      , idempotency : Text
      , conflict : Text
      , ordering : Text
      , dependency : Text
      , authoritativeValidation : Text
      }

let QueuedPort = { port : Text, contract : QueueContract }

let OfflineSource =
      { projections : List Text
      , queuedPorts : List QueuedPort
      , localBlobs : List Text
      }

let Continuity = < OnlineOnly | Offline : OfflineSource >

in  { QueueContract = QueueContract
    , QueuedPort = QueuedPort
    , OfflineSource = OfflineSource
    , Continuity = Continuity
    }
