let Operation =
      < InfernixStart
      | JitmlTrainingStart
      | WorkflowProgress
      | MlSignal
      | WorkflowCancel
      | ModelInvocation
      >

let Projection = { projectionId : Text }

let BlobClass = { blobClassId : Text }

let QueueContract =
      { maxCount : Natural
      , maxBytes : Natural
      , maxAgeSeconds : Natural
      , localValidation : Text
      , idempotency : Text
      , conflict : Text
      , ordering : Text
      , dependency : Text
      , authoritativeValidation : Text
      }

let QueuedPort = { operation : Operation, contract : QueueContract }

let OfflineSource =
      { projections : List Projection
      , queuedPorts : List QueuedPort
      , localBlobs : List BlobClass
      , offlineView : Text
      }

let Continuity = < OnlineOnly | Offline : OfflineSource >

in  { Operation, Projection, BlobClass, QueueContract, QueuedPort, OfflineSource, Continuity }
