let app = ./legal_controller_statefulset.dhall
let C = ./legal_controller_values.dhall
let Resources = ../amoebius/Resources.dhall
let invalid =
      C.statefulSet with controller =
        Resources.Controller.StatefulSet
          { cardinality = Resources.Cardinality.Once
          , rollout = Resources.StatefulSetRollout.OnDelete
          }
in  app with workloads.head = invalid
