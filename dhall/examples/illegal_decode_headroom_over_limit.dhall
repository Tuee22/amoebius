let app = ./trivial_app.dhall
let Resources = ../amoebius/Resources.dhall
let Storage = ../amoebius/Storage.dhall
let V = ./legal_values.dhall
let pod =
      V.podEnvelope with headroom = Some
        { reason = Resources.ComputeHeadroomReason.BurstAbsorption
        , pad =
          { cpu = < Zero | Remaining : { millis : Natural } >.Remaining { millis = 800 }
          , memory = < Zero | Remaining : Storage.ByteQuantity >.Zero
          , ephemeralStorage = < Zero | Remaining : Storage.ByteQuantity >.Zero
          }
        }
let invalid =
      V.workload with resource = Resources.ResourceEnvelope.Pod pod
in  app with workloads.head = invalid
